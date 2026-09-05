/// scr_net.gml - two-player networking, first cut.
///
/// DETERMINISTIC LOCKSTEP. Both machines run the whole simulation; the only
/// thing that crosses the wire is what the players DID. Nothing about the world
/// is ever sent, so the traffic is a few bytes a turn no matter how many serfs
/// are walking about - which is the only model that works for a game this size.
///
/// It is viable here because the simulation is deterministic: every random
/// number in it comes from game.random_int(), which is the 3-word RandomState
/// port, and nothing in the simulation reads the clock. The two places that do
/// use irandom - the "borntodie" effects and the panel's blink - are cosmetic by
/// deliberate design and must STAY that way. Anything that feeds a wall-clock
/// value or an unseeded random into the simulation breaks multiplayer, and the
/// symptom will be a desync a thousand ticks later, not a crash at the line that
/// did it.
///
/// The model:
///   - Time is divided into TURNS of NET_TICKS_PER_TURN simulation ticks.
///   - A command issued during turn T is scheduled to EXECUTE on turn
///     T + NET_TURN_DELAY, on both machines, in the same order.
///   - A machine may not simulate turn T until the other one's packet for turn
///     T has arrived. That is the lockstep: they cannot drift apart, because
///     neither can run ahead.
///   - The delay is what hides the latency. Two turns at 100ms is 200ms between
///     clicking and seeing it, which is what every RTS of this kind does.
///
/// Desync detection: every NET_CHECK_TURNS turns both sides hash the world and
/// compare. A mismatch means the simulations have diverged and everything after
/// it is fiction, so the game stops there and says so rather than letting the
/// two players play on in separate realities.
///
/// FIRST CUT - what is deliberately not here yet: a lobby (F7 hosts, F8 joins
/// 127.0.0.1, which is what makes two instances on one machine testable), any
/// command but build-flag, reconnection, and any handling of one side being
/// slower than the other beyond simply waiting for it.

#macro NET_PORT             6510
#macro NET_TICKS_PER_TURN   5      // 5 ticks at 50Hz = one turn every 100ms
#macro NET_TURN_DELAY       2      // commands land 2 turns later = 200ms
#macro NET_CHECK_TURNS      1      // compare every turn - see net_hash_parts
#macro NET_BUFFER_SIZE      1024

enum NetRole {
    off = 0,
    host = 1,
    client = 2
}

enum NetPhase {
    idle = 0,        // not networked
    listening = 1,   // hosting, nobody has joined
    connecting = 2,  // joining, no answer yet
    running = 3,     // in a game
    dead = 4         // dropped or desynced; see global.net_status
}

enum NetMsg {
    start = 1,       // host -> client: which mission, and the RNG seed
    turn = 2,        // both ways: the commands for one turn
    check = 3        // both ways: a world hash at a turn boundary
}

/// The commands that can cross the wire. Only build_flag is wired up in this
/// first cut - it is the smallest command that changes the world in a way both
/// machines must agree on, which is exactly what needs proving.
enum NetCmd {
    build_flag = 1,
    build_castle = 2,
    build_building = 3,   // b carries the BuildingType
    demolish_flag = 4,
    demolish_building = 5,
    demolish_road = 6,
    build_road = 7        // dirs carries the road, one Direction per step
}

// ---------------------------------------------------------------- state

function net_init() {
    global.net_role      = NetRole.off;
    global.net_phase     = NetPhase.idle;
    global.net_status    = "";
    global.net_server    = -1;
    global.net_socket    = -1;   // host: the client's socket. client: our own.
    global.net_send      = buffer_create(NET_BUFFER_SIZE, buffer_grow, 1);

    /* Which player index this machine drives. Host is 0, client is 1. */
    global.net_local_player = 0;

    /* Simulation ticks executed since the game started. Turn number is this
       divided by NET_TICKS_PER_TURN, so the two can never disagree about where
       a turn boundary is. */
    global.net_sim_tick = 0;

    /* Commands waiting to be sent, and everything received so far.
       net_turns is keyed by turn number as a string: a turn is present exactly
       when the peer's packet for it has arrived. */
    global.net_outbox   = [];
    global.net_turns    = ds_map_create();
    global.net_checks   = ds_map_create();
    global.net_desync   = false;

    /* The last turn whose commands have been run. Separate from what has
       ARRIVED, because a turn is five ticks long and stays the current turn for
       all five - see net_before_tick. */
    global.net_executed_turn = -1;
}

function net_is_active() {
    return (global.net_role != NetRole.off);
}

function net_is_running() {
    return (global.net_phase == NetPhase.running);
}

function net_local_player() {
    return global.net_local_player;
}

function net_status_line() {
    return global.net_status;
}

// ---------------------------------------------------------- host address

/// The address to join, kept in the same ini as mission progress so it survives
/// a restart. Typing an IP once per session is enough of a tax.
#macro NET_INI_SECTION "net"

function net_load_host_ip() {
    ini_open(PROGRESS_PATH);
    /* Empty by default. The old default was a plausible-looking "192.168.1."
       which is a guess at somebody else's network, and pressing Enter on it
       fails instantly - which reads as the prompt having done nothing. */
    var _ip = ini_read_string(NET_INI_SECTION, "host", "");
    ini_close();
    return _ip;
}

function net_save_host_ip(_ip) {
    ini_open(PROGRESS_PATH);
    ini_write_string(NET_INI_SECTION, "host", _ip);
    ini_close();
}

// ---------------------------------------------------------------- connect

function net_host() {
    if (net_is_active()) {
        return false;
    }

    global.net_server = network_create_server(network_socket_tcp, NET_PORT, 1);
    show_debug_message("net: network_create_server -> " + string(global.net_server));
    if (global.net_server < 0) {
        global.net_status = "could not listen on port " + string(NET_PORT) +
                            " (already in use?)";
        show_debug_message("net: " + global.net_status);
        return false;
    }

    global.net_role  = NetRole.host;
    global.net_phase = NetPhase.listening;
    global.net_local_player = 0;
    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];
    global.net_status = "hosting on port " + string(NET_PORT) +
                        " - on the OTHER pc press F8 and type THIS pc's IPv4" +
                        " (ipconfig) - waiting";
    show_debug_message("net: " + global.net_status);
    return true;
}

/// Join a host. When _ip is the loopback name, more than one spelling of "this
/// machine" is tried before giving up.
///
/// 127.0.0.1 is IPv4 and localhost usually resolves to ::1 first. If the
/// runtime's listening socket ends up bound to only one family, the other
/// spelling is refused instantly while the host sits there apparently waiting -
/// which is exactly what "hosting on 6510" and "no answer from 127.0.0.1" look
/// like together. Trying both costs nothing and tells us which it was.
function net_join(_ip) {
    if (net_is_active()) {
        return false;
    }

    var _addresses = [_ip];
    if (_ip == "127.0.0.1" || _ip == "localhost") {
        /* Loopback only. Two instances on ONE machine reach each other this
           way; two machines never can, whichever spelling is used, because
           loopback is the joining machine talking to itself. */
        _addresses = ["127.0.0.1", "localhost", "::1"];
    }

    /* MUST come before the socket is created - the manual is explicit that the
       connect timeout is read when the socket is made, so setting it afterwards
       does nothing at all. */
    network_set_config(network_config_connect_timeout, 2000);

    var _tried = "";
    for (var _i = 0; _i < array_length(_addresses); _i++) {
        var _addr = _addresses[_i];
        show_debug_message("net: joining " + string(_addr) + ":" + string(NET_PORT));

        global.net_socket = network_create_socket(network_socket_tcp);
        show_debug_message("net: network_create_socket -> " + string(global.net_socket));
        if (global.net_socket < 0) {
            global.net_status = "could not open a socket";
            show_debug_message("net: " + global.net_status);
            return false;
        }

        var _r = network_connect(global.net_socket, _addr, NET_PORT);
        show_debug_message("net: network_connect(" + string(_addr) + ") -> " + string(_r));
        if (_r >= 0) {
            _ip = _addr;
            break;
        }

        network_destroy(global.net_socket);
        global.net_socket = -1;
        if (_tried != "") {
            _tried += ", ";
        }
        _tried += string(_addr) + "=" + string(_r);
    }

    if (global.net_socket < 0) {
        /* The return codes go on screen, not only in the log: which spelling
           failed and with what is the whole diagnosis. */
        global.net_status = "no answer on port " + string(NET_PORT) + " [" + _tried + "]";
        show_debug_message("net: " + global.net_status);
        return false;
    }

    global.net_role  = NetRole.client;
    global.net_phase = NetPhase.connecting;
    global.net_local_player = 1;
    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];
    global.net_status = "connected to " + string(_ip) + " - waiting for start";
    show_debug_message("net: " + global.net_status);
    return true;
}

function net_close(_why) {
    if (global.net_socket >= 0) {
        network_destroy(global.net_socket);
        global.net_socket = -1;
    }
    if (global.net_server >= 0) {
        network_destroy(global.net_server);
        global.net_server = -1;
    }

    global.net_role  = NetRole.off;
    global.net_phase = NetPhase.idle;
    global.net_status = _why;

    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];

    show_debug_message("net: closed - " + string(_why));
}

/// Stop dead, keeping the reason on screen. Used for a desync, where carrying
/// on would mean two players in two different worlds both believing they are
/// winning.
function net_fail(_why) {
    global.net_phase  = NetPhase.dead;
    global.net_status = _why;
    show_debug_message("net: STOPPED - " + string(_why));
}

// ---------------------------------------------------------------- sending

function net_peer_socket() {
    return global.net_socket;
}

function net_send_start(_mission_index, _rnd) {
    var _b = global.net_send;
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8,  NetMsg.start);
    buffer_write(_b, buffer_s16, _mission_index);
    buffer_write(_b, buffer_u16, _rnd.state[0]);
    buffer_write(_b, buffer_u16, _rnd.state[1]);
    buffer_write(_b, buffer_u16, _rnd.state[2]);
    network_send_packet(net_peer_socket(), _b, buffer_tell(_b));
}

/// Send this machine's commands for `_turn`. Sent EVERY turn even when empty:
/// the empty packet is what tells the other side it may proceed, so silence has
/// to mean "not yet", never "nothing to do".
function net_send_turn(_turn, _cmds) {
    var _b = global.net_send;
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8,  NetMsg.turn);
    buffer_write(_b, buffer_u32, _turn);
    buffer_write(_b, buffer_u8,  array_length(_cmds));
    for (var _i = 0; _i < array_length(_cmds); _i++) {
        var _c = _cmds[_i];
        buffer_write(_b, buffer_u8,  _c.kind);
        buffer_write(_b, buffer_u32, _c.a);
        buffer_write(_b, buffer_u32, _c.b);

        /* A road is a start position and a list of hex steps, so commands carry
           a variable-length tail. Every command writes the count, even the ones
           that never have one, so the reader never has to know which kinds do. */
        var _dirs = _c.dirs;
        buffer_write(_b, buffer_u16, array_length(_dirs));
        for (var _d = 0; _d < array_length(_dirs); _d++) {
            buffer_write(_b, buffer_u8, _dirs[_d]);
        }
    }
    network_send_packet(net_peer_socket(), _b, buffer_tell(_b));
}

function net_send_check(_turn, _parts) {
    var _b = global.net_send;
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8,  NetMsg.check);
    buffer_write(_b, buffer_u32, _turn);
    for (var _i = 0; _i < NET_HASH_PARTS; _i++) {
        buffer_write(_b, buffer_u32, _parts[_i]);
    }
    network_send_packet(net_peer_socket(), _b, buffer_tell(_b));
}

// ---------------------------------------------------------------- receiving

/// Called from obj_game's Async Networking event with async_load.
function net_handle_async(_async) {
    var _type = _async[? "type"];

    if (_type == network_type_connect) {
        show_debug_message("net: connect event, socket " + string(_async[? "socket"]));
        if (global.net_role == NetRole.host && global.net_phase == NetPhase.listening) {
            global.net_socket = _async[? "socket"];
            global.net_status = "player 2 joined";
            show_debug_message("net: " + global.net_status);
        }
        return;
    }

    if (_type == network_type_disconnect) {
        net_fail("the other player disconnected");
        return;
    }

    if (_type != network_type_data) {
        return;
    }

    var _b = _async[? "buffer"];
    buffer_seek(_b, buffer_seek_start, 0);
    var _msg = buffer_read(_b, buffer_u8);

    switch (_msg) {
    case NetMsg.start:
        net_receive_start(_b);
        break;
    case NetMsg.turn:
        net_receive_turn(_b);
        break;
    case NetMsg.check:
        net_receive_check(_b);
        break;
    default:
        show_debug_message("net: unknown message " + string(_msg));
        break;
    }
}

function net_receive_start(_b) {
    var _mission = buffer_read(_b, buffer_s16);
    var _s0 = buffer_read(_b, buffer_u16);
    var _s1 = buffer_read(_b, buffer_u16);
    var _s2 = buffer_read(_b, buffer_u16);

    show_debug_message("net: start, mission " + string(_mission + 1) +
                       " seed " + string(_s0) + "/" + string(_s1) + "/" + string(_s2));

    /* obj_game picks this up on its next step - starting a game from inside the
       async event would rebuild the float list while the event that is walking
       it has not returned. */
    global.net_pending_start = { mission: _mission, s0: _s0, s1: _s1, s2: _s2 };
}

function net_receive_turn(_b) {
    var _turn  = buffer_read(_b, buffer_u32);
    var _count = buffer_read(_b, buffer_u8);

    var _cmds = [];
    for (var _i = 0; _i < _count; _i++) {
        var _kind = buffer_read(_b, buffer_u8);
        var _a    = buffer_read(_b, buffer_u32);
        var _c    = buffer_read(_b, buffer_u32);

        var _n_dirs = buffer_read(_b, buffer_u16);
        var _dirs = [];
        for (var _d = 0; _d < _n_dirs; _d++) {
            array_push(_dirs, buffer_read(_b, buffer_u8));
        }

        array_push(_cmds, { kind: _kind, a: _a, b: _c, dirs: _dirs });
    }

    ds_map_set(global.net_turns, string(_turn), _cmds);
}

function net_receive_check(_b) {
    var _turn = buffer_read(_b, buffer_u32);
    var _parts = array_create(NET_HASH_PARTS, 0);
    for (var _i = 0; _i < NET_HASH_PARTS; _i++) {
        _parts[_i] = buffer_read(_b, buffer_u32);
    }
    ds_map_set(global.net_checks, string(_turn), _parts);
}

// ---------------------------------------------------------------- lockstep

function net_current_turn() {
    return global.net_sim_tick div NET_TICKS_PER_TURN;
}

function net_have_turn(_turn) {
    return ds_map_exists(global.net_turns, string(_turn));
}

/// How many simulation ticks this machine is allowed to run right now.
///
/// Everything up to the end of the last turn we have the peer's commands for,
/// and not one tick further. When this returns 0 the game is waiting for the
/// other player, which is what lockstep looks like on a slow link.
function net_ticks_available() {
    if (!net_is_running()) {
        return 0;
    }

    var _turn = net_current_turn();
    if (!net_have_turn(_turn)) {
        return 0;
    }

    /* We can run to the end of this turn. The next boundary re-tests. */
    var _end_of_turn = (_turn + 1) * NET_TICKS_PER_TURN;
    return _end_of_turn - global.net_sim_tick;
}

/// Queue a command the local player just issued. It executes NET_TURN_DELAY
/// turns from now, on both machines.
function net_queue_command(_kind, _a, _b, _dirs = []) {
    array_push(global.net_outbox, { kind: _kind, a: _a, b: _b, dirs: _dirs });
}

/// Called immediately before each simulation tick while networked. Does the
/// turn-boundary work: run this turn's commands, ship ours for a later turn,
/// and compare hashes.
function net_before_tick(_game) {
    if (!net_is_running()) {
        return;
    }

    if ((global.net_sim_tick mod NET_TICKS_PER_TURN) != 0) {
        return;   /* mid-turn, nothing to do */
    }

    var _turn = net_current_turn();
    if (_turn <= global.net_executed_turn) {
        return;   /* this turn's commands have already run */
    }
    global.net_executed_turn = _turn;

    net_enforce_speed(_game);
    net_execute_turn(_game, _turn);

    /* Our own commands for a turn far enough ahead that they will have arrived
       by the time it comes round. The outbox is emptied whether or not it had
       anything in it, because the packet must go either way. */
    var _mine = global.net_outbox;
    global.net_outbox = [];
    net_send_turn(_turn + NET_TURN_DELAY, _mine);

    /* Our own commands are executed from the same schedule as the peer's, so
       both machines run them at the same turn and in the same order. */
    net_schedule_local(_turn + NET_TURN_DELAY, _mine);

    if ((_turn mod NET_CHECK_TURNS) == 0) {
        net_compare_check(_game, _turn);
    }
}

/// Called after each simulation tick.
function net_after_tick() {
    if (!net_is_running()) {
        return;
    }
    global.net_sim_tick += 1;
}

/// Local commands go into their own schedule, keyed the same way. Kept separate
/// from the peer's so that neither can be mistaken for the other, and so the
/// execution order is always ours-then-theirs on BOTH machines - the ordering
/// has to be a rule, not an accident of arrival time.
function net_schedule_local(_turn, _cmds) {
    ds_map_set(global.net_turns, "L" + string(_turn), _cmds);
}

/// Run a turn's commands, ALWAYS IN PLAYER INDEX ORDER.
///
/// This used to be local-then-peer, which is a different order on the two
/// machines: the host ran player 0 then player 1, the client ran player 1 then
/// player 0. For independent commands that does not matter, but the moment two
/// commands on the same turn compete for the same ground - both players placing
/// a castle on the same tile - each machine hands it to a different player, and
/// the worlds part company. A desync manufactured by the ordering rule itself,
/// which no amount of determinism elsewhere could save.
///
/// Player index is the one ordering both machines already agree on.
function net_execute_turn(_game, _turn) {
    var _local_key = "L" + string(_turn);
    var _peer_key  = string(_turn);

    for (var _p = 0; _p < GAME_MAX_PLAYER_COUNT; _p++) {
        var _cmds = undefined;

        if (_p == global.net_local_player) {
            _cmds = ds_map_find_value(global.net_turns, _local_key);
        } else if (_p == net_peer_player()) {
            _cmds = ds_map_find_value(global.net_turns, _peer_key);
        }

        if (is_array(_cmds)) {
            net_run_commands(_game, _cmds, _p);
        }
    }

    /* Drop the PREVIOUS turn, never this one. A turn is NET_TICKS_PER_TURN
       ticks long and stays the current turn for all of them, and
       net_ticks_available() asks whether the current turn has arrived on every
       one of those ticks. Deleting it the moment its commands ran meant that
       from the second tick onwards the machine was asking whether the turn it
       was already inside had arrived, being told no, and waiting for ever - a
       deadlock that only showed at normal frame rates, because running all five
       ticks in one go stepped over it. */
    ds_map_delete(global.net_turns, "L" + string(_turn - 1));
    ds_map_delete(global.net_turns, string(_turn - 1));
}

/// The other machine's player index. Two players for now, so it is simply the
/// one this machine is not.
function net_peer_player() {
    if (global.net_local_player == 0) {
        return 1;
    }
    return 0;
}

function net_run_commands(_game, _cmds, _player_index) {
    if (_game == undefined) {
        return;
    }

    var _player = _game.get_player(_player_index);
    if (_player == undefined) {
        return;
    }

    for (var _i = 0; _i < array_length(_cmds); _i++) {
        var _c = _cmds[_i];
        switch (_c.kind) {
        /* Every return value here is deliberately ignored. A command that fails
           must fail on BOTH machines - it will, because they are the same
           simulation reaching the same answer - and reacting to the failure
           locally is exactly what would pull them apart. Two players placing a
           castle on the same tile is the case that matters: the lower player
           index gets it and the other's command fails, identically on both. */
        case NetCmd.build_flag:
            _game.build_flag(_c.a, _player);
            break;
        case NetCmd.build_castle:
            /* Enforced HERE, not at the click, because this is the copy of the
               rule both machines run. The UI check is only a courtesy so the
               click does not feel dead; if it were the only check, a command
               that slipped through on one machine would build a castle there
               and nowhere else. */
            if (net_placing_player(_game) == _player_index) {
                _game.build_castle(_c.a, _player);
            }
            break;
        case NetCmd.build_building:
            _game.build_building(_c.a, _c.b, _player);
            break;
        case NetCmd.demolish_flag:
            _game.demolish_flag(_c.a, _player);
            break;
        case NetCmd.demolish_building:
            _game.demolish_building(_c.a, _player);
            break;
        case NetCmd.demolish_road:
            _game.demolish_road(_c.a, _player);
            break;
        case NetCmd.build_road: {
            /* Rebuilt from the wire rather than sent as an object: a Road is a
               start position and a list of hex steps, and that is all the far
               side needs to walk out the identical road. */
            var _road = new Road();
            _road.start(_c.a);
            for (var _d = 0; _d < array_length(_c.dirs); _d++) {
                _road.extend(_c.dirs[_d]);
            }
            _game.build_road(_road, _player);
            break;
        }
        default:
            show_debug_message("net: unknown command " + string(_c.kind));
            break;
        }
    }
}

/// The speed button changes how much simulation one tick does, so the two
/// machines must agree on it. Until it is a command in its own right it is
/// simply pinned, and said out loud the first time it is touched.
/// Game.update advances the world by game_speed every tick, so two machines at
/// different speeds are simulating at different rates and have already parted.
///
/// This used to CORRECT the speed at the next turn boundary, which is up to five
/// ticks late - and five ticks at speed 20 against speed 2 is ninety tick-units
/// of divergence, more than enough to part the worlds for good. The control is
/// refused outright now (see net_speed_locked) and this is only a backstop for
/// anything that sets the speed without going through the button.
function net_enforce_speed(_game) {
    if (_game == undefined) {
        return;
    }
    if (_game.game_speed == DEFAULT_GAME_SPEED) {
        return;
    }
    _game.set_speed(DEFAULT_GAME_SPEED);
    show_debug_message("net: game speed was changed behind the lock - pinned back");
}

/// True while the speed control must not be touched.
function net_speed_locked() {
    return net_is_running();
}

// ---------------------------------------------------------------- desync

/// Component hashes of the world, one per kind of thing.
///
/// A single number over everything says only THAT the two have parted, which is
/// where the last few attempts ran out of information. Six numbers say WHERE,
/// and each answer points somewhere quite specific:
///
///   tick      - the two are simulating at different rates. Speed, or the tick
///               accounting in obj_game's Step.
///   rnd       - a different NUMBER of random draws has happened. Something is
///               calling game.random_int() a different number of times, which
///               is the worst kind because everything after it diverges too.
///   serfs     - the serf state machine, or a command that ran on one side.
///   buildings - building progress or a build/demolish that only landed once.
///   flags     - the transport network.
///   players   - bookkeeping: resource and serf counts, land area.
///
/// Kept to whole numbers and folded with a small multiplier on purpose: GML
/// numbers are doubles, exact only to 2^53, so a 32-bit FNV-style hash would
/// silently lose its low bits the moment it multiplied. 31 against a 31-bit
/// accumulator stays well inside what a double represents exactly.
#macro NET_HASH_PARTS 6

function net_hash_parts(_game) {
    var _out = array_create(NET_HASH_PARTS, 0);
    if (_game == undefined) {
        return _out;
    }

    /* 0: the clock */
    var _h = net_hash_fold(0, _game.tick);
    _out[0] = net_hash_fold(_h, _game.const_tick);

    /* 1: the random generator's own state */
    _h = net_hash_fold(0, _game.rnd.state[0]);
    _h = net_hash_fold(_h, _game.rnd.state[1]);
    _out[1] = net_hash_fold(_h, _game.rnd.state[2]);

    /* 2: serfs */
    _h = 0;
    var _serfs = _game.serfs.objects;
    for (var _i = 0; _i < array_length(_serfs); _i++) {
        var _s = _serfs[_i];
        if (_s == undefined) {
            continue;
        }
        _h = net_hash_fold(_h, _i);
        _h = net_hash_fold(_h, _s.pos);
        _h = net_hash_fold(_h, _s.state);
        _h = net_hash_fold(_h, _s.animation);
        _h = net_hash_fold(_h, _s.counter);
    }
    _out[2] = _h;

    /* 3: buildings */
    _h = 0;
    var _blds = _game.buildings.objects;
    for (var _j = 0; _j < array_length(_blds); _j++) {
        var _b = _blds[_j];
        if (_b == undefined) {
            continue;
        }
        _h = net_hash_fold(_h, _j);
        _h = net_hash_fold(_h, _b.pos);
        _h = net_hash_fold(_h, _b.get_type());
        _h = net_hash_fold(_h, _b.progress);
    }
    _out[3] = _h;

    /* 4: flags */
    _h = 0;
    var _flags = _game.flags.objects;
    for (var _k = 0; _k < array_length(_flags); _k++) {
        var _f = _flags[_k];
        if (_f == undefined) {
            continue;
        }
        _h = net_hash_fold(_h, _k);
        _h = net_hash_fold(_h, _f.pos);
    }
    _out[4] = _h;

    /* 5: player bookkeeping */
    _h = 0;
    for (var _p = 0; _p < GAME_MAX_PLAYER_COUNT; _p++) {
        if (!_game.players.exists(_p)) {
            continue;
        }
        var _player = _game.players.objects[_p];
        if (_player == undefined) {
            continue;
        }
        _h = net_hash_fold(_h, _p);
        _h = net_hash_fold(_h, _player.total_land_area);
        _h = net_hash_fold(_h, _player.total_building_score);
        _h = net_hash_fold(_h, _player.total_military_score);
    }
    _out[5] = _h;

    return _out;
}

function net_hash_part_name(_i) {
    switch (_i) {
    case 0: return "tick";
    case 1: return "rnd";
    case 2: return "serfs";
    case 3: return "buildings";
    case 4: return "flags";
    case 5: return "players";
    }
    return "?";
}

function net_hash_fold(_h, _v) {
    return ((_h * 31) + _v) mod 2147483647;
}

/// Compare this turn's component hashes with the peer's, and name the first
/// component that differs.
function net_compare_check(_game, _turn) {
    var _mine = net_hash_parts(_game);
    net_send_check(_turn, _mine);

    var _key = string(_turn);
    if (!ds_map_exists(global.net_checks, _key)) {
        /* Theirs has not arrived yet - keep ours for net_late_checks. */
        ds_map_set(global.net_checks, "M" + _key, _mine);
        return;
    }

    var _theirs = ds_map_find_value(global.net_checks, _key);
    ds_map_delete(global.net_checks, _key);
    net_report_check(_turn, _mine, _theirs);
}

function net_report_check(_turn, _mine, _theirs) {
    for (var _i = 0; _i < NET_HASH_PARTS; _i++) {
        if (_mine[_i] != _theirs[_i]) {
            net_fail("DESYNC turn " + string(_turn) + " in " +
                     net_hash_part_name(_i) + " (" + string(_mine[_i]) +
                     " vs " + string(_theirs[_i]) + ")" +
                     net_parts_summary(_mine, _theirs));
            return;
        }
    }
}

/// Every component's verdict, so one screenshot says whether it is one thing or
/// everything - "rnd and serfs" reads very differently from "serfs alone".
function net_parts_summary(_mine, _theirs) {
    var _same = "";
    var _diff = "";
    for (var _i = 0; _i < NET_HASH_PARTS; _i++) {
        if (_mine[_i] == _theirs[_i]) {
            _same += net_hash_part_name(_i) + " ";
        } else {
            _diff += net_hash_part_name(_i) + " ";
        }
    }
    return "  [differ: " + _diff + "| same: " + _same + "]";
}

/// Compare any hashes whose partner arrived after we made ours.
///
/// The keys are collected before anything is deleted: ds_map_find_next after
/// deleting the key it was standing on is not defined, and this walk deletes as
/// it goes.
function net_late_checks() {
    if (!net_is_running()) {
        return;
    }

    var _pending = [];
    var _key = ds_map_find_first(global.net_checks);
    while (!is_undefined(_key)) {
        if (string_char_at(_key, 1) == "M") {
            array_push(_pending, _key);
        }
        _key = ds_map_find_next(global.net_checks, _key);
    }

    for (var _i = 0; _i < array_length(_pending); _i++) {
        var _mine_key = _pending[_i];
        var _turn_key = string_delete(_mine_key, 1, 1);
        if (!ds_map_exists(global.net_checks, _turn_key)) {
            continue;
        }

        var _mine   = ds_map_find_value(global.net_checks, _mine_key);
        var _theirs = ds_map_find_value(global.net_checks, _turn_key);
        ds_map_delete(global.net_checks, _mine_key);
        ds_map_delete(global.net_checks, _turn_key);

        net_report_check(real(_turn_key), _mine, _theirs);
        if (!net_is_running()) {
            return;   /* net_fail has stopped us */
        }
    }
}

// ---------------------------------------------------------------- starting

/// Host: build the game, tell the client what to build, and start the clock.
function net_host_start_game(_interface, _mission_index) {
    var _game = new Game();
    var _mission = game_info_get_mission(_mission_index);
    if (_mission.instantiate(_game) == undefined) {
        net_fail("could not build mission " + string(_mission_index + 1));
        return;
    }
    _game.mission_index = _mission_index;

    net_send_start(_mission_index, _game.rnd);
    net_begin(_interface, _game, 0);
}

/// Client: build the same game from what the host sent, and adopt its RNG
/// state so both machines draw the same numbers from the same point.
function net_client_start_game(_interface, _start) {
    var _game = new Game();
    var _mission = game_info_get_mission(_start.mission);
    if (_mission.instantiate(_game) == undefined) {
        net_fail("could not build mission " + string(_start.mission + 1));
        return;
    }
    _game.mission_index = _start.mission;

    _game.rnd.state[0] = _start.s0;
    _game.rnd.state[1] = _start.s1;
    _game.rnd.state[2] = _start.s2;

    net_begin(_interface, _game, 1);
}

/// Castle placement is sequenced: player 0 chooses, then player 1 - who can
/// then see where player 0 went and answer it. Play proper begins once both
/// have one.
///
/// This costs no traffic and needs no extra message. It is a rule read off the
/// simulation, and both machines are running the same simulation, so both reach
/// the same answer on the same tick without being told.
function net_placing_phase(_game) {
    if (_game == undefined) {
        return false;
    }

    for (var _p = 0; _p < 2; _p++) {
        var _player = _game.get_player(_p);
        if (_player != undefined && !_player.has_castle()) {
            return true;
        }
    }
    return false;
}

/// Whose castle it is to place, or -1 when placement is over.
function net_placing_player(_game) {
    if (_game == undefined) {
        return -1;
    }

    for (var _p = 0; _p < 2; _p++) {
        var _player = _game.get_player(_p);
        if (_player != undefined && !_player.has_castle()) {
            return _p;
        }
    }
    return -1;
}

/// May this machine's player place a castle right now?
function net_may_place_castle(_game) {
    return (net_placing_player(_game) == global.net_local_player);
}

/// What the status line should say about the placement phase.
function net_placing_status(_game) {
    var _who = net_placing_player(_game);
    if (_who < 0) {
        return "";
    }
    if (_who == global.net_local_player) {
        return "  YOUR TURN: place your castle";
    }
    return "  waiting for player " + string(_who + 1) + " to place their castle";
}

function net_begin(_interface, _game, _local_player) {
    global.net_local_player = _local_player;
    global.net_sim_tick = 0;
    global.net_executed_turn = -1;
    global.net_outbox = [];

    /* The turn maps are NOT cleared here. The host primes turns 0 and 1 and
       sends them in the same breath as the start message, so on a local
       connection they can easily arrive before the client has finished starting
       its own game - clearing at this point would throw them away and the
       client would then wait forever for a turn 0 that is never sent again.
       They are cleared where nothing can have arrived yet: net_host/net_join. */

    /* Take players 0 and 1 off the AI. A mission's second player is an AI
       opponent by default, and mission 1's is: it would place player 1's castle
       itself within moments of the start, so has_castle() went true and the
       human's own placement was refused for ever after - which is why placing a
       castle appeared to do nothing at all, wherever you clicked.
       Both machines do this identically before a single tick runs, so the
       simulations still match. */
    for (var _p = 0; _p < 2; _p++) {
        var _player = _game.get_player(_p);
        if (_player != undefined) {
            _player.flags &= ~(1 << 7);   /* the AI bit */
        }
    }

    _game.set_speed(DEFAULT_GAME_SPEED);
    _interface.set_game(_game);

    /* set_game has already selected player 0. Calling set_player again with the
       index it already has deletes the panel and then returns early on its
       "unchanged index" test, leaving no panel at all - the trap set_game's own
       comment describes. Only the client actually needs to switch. */
    if (_local_player != 0) {
        _interface.set_player(_local_player);
    }

    _interface.close_game_init();

    /* Prime the pipeline: the first NET_TURN_DELAY turns can carry no commands
       because nobody has had a chance to issue any, but their packets still
       have to exist or neither machine could ever start. */
    for (var _t = 0; _t < NET_TURN_DELAY; _t++) {
        net_send_turn(_t, []);
        net_schedule_local(_t, []);
    }

    global.net_phase = NetPhase.running;
    global.net_status = "in game as player " + string(_local_player + 1);
    show_debug_message("net: " + global.net_status);
}
