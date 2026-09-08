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
    build_road = 7,       // dirs carries the road, one Direction per step
    player_setting = 8,   // a = NetSetting, b = value, dirs = small extra ints
    send_geologist = 9,   // a = the flag's position
    inv_res_mode = 10,    // a = building index, b = mode
    inv_serf_mode = 11    // a = building index, b = mode
}

/// The player settings. Every one of these changes how the simulation behaves -
/// what gets built, who gets fed, which serfs become knights - so every one of
/// them is a command, not a local click.
///
/// They are one NetCmd rather than thirty because the shape is identical: a
/// setting, a value, and occasionally a small index. b carries the value (a u32,
/// so a map position fits); dirs carries the indices, which are all tiny.
enum NetSetting {
    food_stonemine = 0,
    food_coalmine,
    food_ironmine,
    food_goldmine,
    planks_construction,
    planks_boatbuilder,
    planks_toolmaker,
    steel_toolmaker,
    steel_weaponsmith,
    coal_steelsmelter,
    coal_goldsmelter,
    coal_weaponsmith,
    wheat_pigfarm,
    wheat_mill,
    tool_prio,             // b = priority, dirs[0] = tool index
    serf_to_knight_rate,
    knight_occupation,     // dirs = [index, adjust_max, delta + 1]
    castle_knights_inc,
    castle_knights_dec,
    send_strongest_set,
    send_strongest_drop,
    cycle_knights,
    promote_knights,       // b = how many
    start_attack,          // b = target building index, dirs[0] = knights
    reset_food,
    reset_planks,
    reset_steel,
    reset_coal,
    reset_wheat,
    reset_tool,
    reset_flag_prio,
    reset_inventory_prio
}

// ---------------------------------------------------------------- logging

/// Everything the net layer says goes to the output log AND to a file beside
/// the saves, so a session can be read back after the fact instead of being
/// copied out of the console while it scrolls.
#macro NET_LOG_PATH "settlers_net.log"

function net_log(_line) {
    show_debug_message("net: " + string(_line));

    var _f = file_text_open_append(NET_LOG_PATH);
    if (_f < 0) {
        return;
    }
    file_text_write_string(_f, string(_line));
    file_text_writeln(_f);
    file_text_close(_f);
}

/// Start a fresh log. Called when a session begins, so the file is about this
/// game rather than every game since the exe was built.
function net_log_reset() {
    var _f = file_text_open_write(NET_LOG_PATH);
    if (_f < 0) {
        return;
    }
    file_text_write_string(_f, "SettlersGM net log - " +
                               date_datetime_string(date_current_datetime()));
    file_text_writeln(_f);
    file_text_close(_f);
    show_debug_message("net: logging to " + game_save_id + NET_LOG_PATH);
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

    /* Consecutive frames spent with no ticks to run. Lockstep waits a frame or
       two at almost every turn boundary, which is normal and invisible in the
       simulation but made the on-screen notice flicker. It is only worth saying
       when the wait is long enough to be a wait. */
    global.net_wait_frames = 0;

    /* Frames since the status line last changed. The status is worth reading
       when it has just changed and is clutter for the rest of the session, so
       it shows for NET_STATUS_SHOW_FRAMES and then gets out of the way. */
    global.net_status_frames = 0;

    /* Which slice of the map the next world hash covers. Set from the turn
       number so the two machines always hash the same tiles. */
    global.net_map_slice = 0;

    /* F7's host starts mission 1 the moment somebody joins; the lobby's host
       does not - there the host chooses and presses START. This says which
       kind of host we are, so leaving the lobby panel can never be mistaken
       for "go". It used to be inferred from the panel being closed, which is
       exactly what pressing EXIT does. */
    global.net_autostart = false;

    /* Who is on the other end, for the panel. */
    global.net_peer_ip = "";
}

#macro NET_STATUS_SHOW_FRAMES 600   // ten seconds at 60fps

/// How many turns it takes to hash the whole map - see part 14 of the world
/// hash. Sixteen turns is under two seconds, which is soon enough to be useful
/// and cheap enough to run every turn.
#macro NET_MAP_SLICES 16

/// The one place the status line is set, so its clock always restarts with it.
function net_set_status(_line) {
    global.net_status = _line;
    global.net_status_frames = 0;
}

/// Called once a frame, whether or not a game is running.
function net_age_status() {
    global.net_status_frames += 1;
}

/// The part of the notice that is about right now rather than about something
/// that happened: never aged out, because it stops being true on its own.
function net_live_notice(_game) {
    if (!net_is_running()) {
        return "";
    }

    var _out = net_placing_status(_game);
    if (net_is_waiting()) {
        _out += "  [waiting for the other player]";
    }
    return _out;
}

/// Whether the status line has anything left to say.
function net_status_visible() {
    if (global.net_status == "") {
        return false;
    }
    return (global.net_status_frames < NET_STATUS_SHOW_FRAMES);
}

#macro NET_WAIT_SHOW_FRAMES 15   // about a quarter of a second at 60fps

/// Called once a frame with the tick budget lockstep allowed.
function net_note_wait(_allowed) {
    if (_allowed > 0) {
        global.net_wait_frames = 0;
        return;
    }
    global.net_wait_frames += 1;
}

/// True when the game has been held up long enough to be worth saying so.
function net_is_waiting() {
    return (global.net_wait_frames >= NET_WAIT_SHOW_FRAMES);
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
        net_set_status("could not listen on port " + string(NET_PORT) +
                            " (already in use?)");
        show_debug_message("net: " + global.net_status);
        return false;
    }

    global.net_role  = NetRole.host;
    global.net_phase = NetPhase.listening;
    global.net_local_player = 0;
    global.net_autostart = true;
    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];
    net_set_status("hosting on port " + string(NET_PORT) +
                        " - on the OTHER pc press F8 and type THIS pc's IPv4" +
                        " (ipconfig) - waiting");
    net_log(global.net_status);
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
            net_set_status("could not open a socket");
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
        /* Said the way it needs fixing, with the codes after for the log and
           for anyone who wants them. The one cause that matters is the other
           machine not having its NET PLAY panel open - that is what closes its
           door - so that is what the line asks. */
        net_set_status(net_addr_label(string(_ip)) + " did not answer - is NET PLAY open on"
                       + " that pc? [port " + string(NET_PORT) + ": " + _tried
                       + "]");
        show_debug_message("net: " + global.net_status);
        net_log(global.net_status);
        return false;
    }

    /* We dialled a pc that said it was hosting, so we are player 2. Roles
       are DECLARED - HOST is a button, and only a host is joined - never
       worked out from who dialled whom. The two versions that tried that
       both ended with the same role on both machines, because two people
       testing a panel click on both of them. */
    global.net_role  = NetRole.client;
    global.net_phase = NetPhase.connecting;
    global.net_local_player = 1;
    global.net_autostart = false;
    global.net_peer_ip = string(_ip);
    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];
    net_set_status("JOINED " + net_addr_label(string(_ip)) + " - you are player 2. The host"
                   + " CLICKS START");
    show_debug_message("net: " + global.net_status);
    net_log(global.net_status);
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
    global.net_dialling = "";
    global.net_peer_ip = "";
    global.net_autostart = false;
    net_set_status(_why);

    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];

    show_debug_message("net: closed - " + string(_why));
    net_log("closed - " + string(_why));
}

/// Back to "nobody connected" WITHOUT leaving the lobby: the peer socket goes,
/// the role goes, and the reason goes on the panel - but the door stays open
/// so somebody can pick us again, and the list stays so we can pick them.
///
/// This is what a dropped connection means before a game has started. It used
/// to go through net_fail, which is for a game in progress: it marks the
/// session dead and leaves the role set, so the panel carried on saying
/// "connected, waiting for the host" about a connection that no longer
/// existed, and nothing on it could be clicked until the exe was restarted.
function net_drop_to_lobby(_why) {
    if (global.net_socket >= 0) {
        network_destroy(global.net_socket);
        global.net_socket = -1;
    }

    global.net_role  = NetRole.off;
    global.net_phase = NetPhase.idle;
    global.net_dialling = "";
    global.net_peer_ip = "";
    global.net_autostart = false;
    net_set_status(_why);

    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];

    /* The door only matters while the panel is open. */
    if (!net_lobby_is_open() && global.net_server >= 0) {
        network_destroy(global.net_server);
        global.net_server = -1;
    }

    show_debug_message("net: back to lobby - " + string(_why));
    net_log("back to lobby - " + string(_why));
}

/// Somebody dialled us and we are keeping them: they clicked, so they host,
/// and we are player 2 from here - waiting for the start they will send.
function net_become_client(_socket, _their_ip) {
    global.net_role  = NetRole.client;
    global.net_phase = NetPhase.connecting;
    global.net_local_player = 1;
    global.net_autostart = false;
    global.net_socket = _socket;
    global.net_peer_ip = string(_their_ip);
    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];
    net_set_status(net_addr_label(string(_their_ip)) + " connected to you - you are player 2."
                   + " They CLICK START");
    net_log(global.net_status);
}

/// Stop dead, keeping the reason on screen. Used for a desync, where carrying
/// on would mean two players in two different worlds both believing they are
/// winning.
function net_fail(_why) {
    global.net_phase  = NetPhase.dead;
    net_set_status(_why);
    net_log("STOPPED - " + string(_why));
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

function net_write_u32_array(_b, _a) {
    buffer_write(_b, buffer_u16, array_length(_a));
    for (var _i = 0; _i < array_length(_a); _i++) {
        buffer_write(_b, buffer_u32, _a[_i]);
    }
}

function net_read_u32_array(_b) {
    var _n = buffer_read(_b, buffer_u16);
    var _a = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) {
        _a[_i] = buffer_read(_b, buffer_u32);
    }
    return _a;
}

function net_send_check(_turn, _snap) {
    var _b = global.net_send;
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8,  NetMsg.check);
    buffer_write(_b, buffer_u32, _turn);
    for (var _i = 0; _i < NET_HASH_PARTS; _i++) {
        buffer_write(_b, buffer_u32, _snap.parts[_i]);
    }

    net_write_u32_array(_b, _snap.serfs);
    net_write_u32_array(_b, _snap.buildings);
    net_write_u32_array(_b, _snap.flags);
    net_write_u32_array(_b, _snap.invs);

    network_send_packet(net_peer_socket(), _b, buffer_tell(_b));
}

// ---------------------------------------------------------------- receiving

/// Called from obj_game's Async Networking event with async_load.
function net_handle_async(_async) {
    var _type = _async[? "type"];

    if (_type == network_type_connect) {
        var _their_ip     = _async[? "ip"];
        var _their_socket = _async[? "socket"];
        show_debug_message("net: connect event, socket " + string(_their_socket)
                           + " from " + string(_their_ip));

        /* Hosting and empty: this is player 2 arriving. Covers the panel's
           HOST button and F7 alike. */
        if (global.net_role == NetRole.host && global.net_phase == NetPhase.listening &&
            global.net_socket < 0) {
            global.net_socket = _their_socket;
            global.net_peer_ip = string(_their_ip);
            net_set_status(net_addr_label(string(_their_ip)) + " joined as player 2 - pick a"
                           + " mission and CLICK START");
            show_debug_message("net: " + global.net_status);
            net_log(global.net_status);
            return;
        }

        /* Not hosting, but somebody dialled us anyway - they clicked a row
           marked "?" because our beacon never reached them. Taking the game
           is friendlier than refusing it: they wanted to play us, and we are
           sitting at the panel with nothing else going on. */
        if (net_lobby_is_open() && global.net_role == NetRole.off) {
            net_become_client(_their_socket, _their_ip);
            return;
        }

        /* Anyone else knocking - a third machine, a host already full, or
           somebody dialling in the middle of a game - is turned away rather
           than left on a socket that nothing will ever read. */
        show_debug_message("net: refusing a connection from " + string(_their_ip)
                           + " - already engaged");
        network_destroy(_their_socket);
        return;
    }

    if (_type == network_type_disconnect) {
        /* Only the peer counts. The host refuses spare connections above by
           destroying them, and their going away must not be read as the real
           player leaving. A client has only ever had the one socket. */
        /* "socket" is the socket that went (on a server, the client that
           left); "id" is the socket the event arrived on (on a client, its
           own). The peer is whichever of those is our net_socket. Matching
           on role alone was wrong for a client: in the both-picked case the
           other machine hangs up the connection it made TO us, our server
           reports that, and the dial we are keeping must not be dropped for
           it. */
        var _gone = _async[? "socket"];
        var _on   = _async[? "id"];
        var _is_peer = (global.net_socket >= 0) &&
                       (_gone == global.net_socket || _on == global.net_socket);
        if (!_is_peer) {
            show_debug_message("net: disconnect of socket " + string(_gone)
                               + " - not the peer, ignored");
            return;
        }

        if (global.net_phase == NetPhase.dead) {
            /* Already stopped, and the reason on screen - a desync, say - is
               the one worth keeping. */
            return;
        }

        if (net_is_running()) {
            net_fail("the other player disconnected");
            return;
        }

        /* Before a game. A host stays a host - player 2 leaving is no
           reason to stop offering - and just goes back to waiting; a joiner
           goes back to the list. */
        if (global.net_role == NetRole.host) {
            network_destroy(global.net_socket);
            global.net_socket = -1;
            global.net_peer_ip = "";
            net_set_status("player 2 left - still hosting, waiting for another");
            net_log(global.net_status);
            return;
        }
        net_drop_to_lobby("the host dropped the connection - CLICK it to try"
                          + " again");
        return;
    }

    if (_type != network_type_data) {
        return;
    }

    var _b = _async[? "buffer"];
    buffer_seek(_b, buffer_seek_start, 0);
    var _msg = buffer_read(_b, buffer_u8);

    /* Discovery shares the async event with the game socket, so beacons are
       told apart by their tag and handled before anything else. They arrive on
       the UDP socket and carry the sender's address with them. */
    if (_msg == NetBeacon.hello) {
        net_receive_beacon(_b, _async[? "ip"]);
        return;
    }

    /* Anything else arriving on the discovery socket is worth counting too: a
       datagram that turns up and is not a beacon means the wire is fine and the
       fault is in here, which is the opposite conclusion from nothing at all. */

    switch (_msg) {
    case NetMsg.start:
        net_receive_start(_b, _async[? "id"]);
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

function net_receive_start(_b, _from_socket) {
    var _mission = buffer_read(_b, buffer_s16);
    var _s0 = buffer_read(_b, buffer_u16);
    var _s1 = buffer_read(_b, buffer_u16);
    var _s2 = buffer_read(_b, buffer_u16);

    show_debug_message("net: start, mission " + string(_mission + 1) +
                       " seed " + string(_s0) + "/" + string(_s1) + "/" + string(_s2)
                       + " on socket " + string(_from_socket));

    if (net_is_running()) {
        net_log("start from the peer ignored - already in a game");
        return;
    }

    /* obj_game picks this up on its next step - starting a game from inside the
       async event would rebuild the float list while the event that is walking
       it has not returned. */
    global.net_pending_start = { mission: _mission, s0: _s0, s1: _s1, s2: _s2,
                                 socket: _from_socket };
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

    /* Read into locals FIRST, in order.
       These four calls each advance the buffer, and GML does not evaluate a
       struct literal's fields in source order - written as a literal, the peer's
       serf digests came back holding the inventory array and vice versa, which
       made every object look different from its opposite number. Side effects
       do not belong inside a struct literal. */
    var _serfs = net_read_u32_array(_b);
    var _blds  = net_read_u32_array(_b);
    var _flgs  = net_read_u32_array(_b);
    var _invs  = net_read_u32_array(_b);

    ds_map_set(global.net_checks, string(_turn), {
        parts:     _parts,
        serfs:     _serfs,
        buildings: _blds,
        flags:     _flgs,
        invs:      _invs
    });
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
    /* Copy the directions. The caller's Road is still live and its dirs array
       is mutated in place by extend() and undo(); a command that holds the
       caller's array can have the road edited out from under it between being
       queued and being sent. */
    var _copy = [];
    for (var _i = 0; _i < array_length(_dirs); _i++) {
        array_push(_copy, _dirs[_i]);
    }
    array_push(global.net_outbox, { kind: _kind, a: _a, b: _b, dirs: _copy });
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
        case NetCmd.send_geologist: {
            var _gf = _game.get_flag_at_pos(_c.a);
            if (_gf != undefined) {
                _game.send_geologist(_gf);
            }
            break;
        }
        case NetCmd.inv_res_mode: {
            var _rb = _game.get_building(_c.a);
            if (_rb != undefined && _rb.get_inventory() != undefined) {
                _game.set_inventory_resource_mode(_rb.get_inventory(), _c.b);
            }
            break;
        }
        case NetCmd.inv_serf_mode: {
            var _sb = _game.get_building(_c.a);
            if (_sb != undefined && _sb.get_inventory() != undefined) {
                _game.set_inventory_serf_mode(_sb.get_inventory(), _c.b);
            }
            break;
        }
        case NetCmd.player_setting:
            net_apply_setting(_player, _c.a, _c.b, _c.dirs);
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

/// Apply a player setting, or send it if we are networked.
///
/// Every settings popup calls this instead of touching the player. The whole
/// family used to go straight into the local player, which is why a session
/// could run four thousand turns clean and then part company the moment someone
/// opened the knights menu: fifteen serfs became knights on one machine and
/// stayed generic on the other.
function net_player_setting(_player, _setting, _value = 0, _extra = []) {
    if (net_is_running()) {
        net_queue_command(NetCmd.player_setting, _setting, _value, _extra);
        return;
    }
    net_apply_setting(_player, _setting, _value, _extra);
}

/// The one place a setting is actually applied, so the local path and the
/// networked path cannot drift into meaning different things.
function net_apply_setting(_player, _setting, _value, _extra) {
    if (_player == undefined) {
        return;
    }

    switch (_setting) {
    case NetSetting.food_stonemine:      _player.set_food_stonemine(_value); break;
    case NetSetting.food_coalmine:       _player.set_food_coalmine(_value); break;
    case NetSetting.food_ironmine:       _player.set_food_ironmine(_value); break;
    case NetSetting.food_goldmine:       _player.set_food_goldmine(_value); break;
    case NetSetting.planks_construction: _player.set_planks_construction(_value); break;
    case NetSetting.planks_boatbuilder:  _player.set_planks_boatbuilder(_value); break;
    case NetSetting.planks_toolmaker:    _player.set_planks_toolmaker(_value); break;
    case NetSetting.steel_toolmaker:     _player.set_steel_toolmaker(_value); break;
    case NetSetting.steel_weaponsmith:   _player.set_steel_weaponsmith(_value); break;
    case NetSetting.coal_steelsmelter:   _player.set_coal_steelsmelter(_value); break;
    case NetSetting.coal_goldsmelter:    _player.set_coal_goldsmelter(_value); break;
    case NetSetting.coal_weaponsmith:    _player.set_coal_weaponsmith(_value); break;
    case NetSetting.wheat_pigfarm:       _player.set_wheat_pigfarm(_value); break;
    case NetSetting.wheat_mill:          _player.set_wheat_mill(_value); break;

    case NetSetting.tool_prio:
        _player.set_tool_prio(_extra[0], _value);
        break;

    case NetSetting.serf_to_knight_rate:
        _player.set_serf_to_knight_rate(_value);
        break;

    case NetSetting.knight_occupation:
        /* delta is -1 or +1 and dirs carries unsigned bytes, so it travels as
           delta + 1 and comes back the same way round on both machines. */
        _player.change_knight_occupation(_extra[0], _extra[1], _extra[2] - 1);
        break;

    case NetSetting.castle_knights_inc:  _player.increase_castle_knights_wanted(); break;
    case NetSetting.castle_knights_dec:  _player.decrease_castle_knights_wanted(); break;
    case NetSetting.send_strongest_set:  _player.set_send_strongest(); break;
    case NetSetting.send_strongest_drop: _player.drop_send_strongest(); break;
    case NetSetting.cycle_knights:       _player.cycle_knights(); break;

    case NetSetting.promote_knights:
        _player.promote_serfs_to_knights(_value);
        break;

    case NetSetting.start_attack:
        /* Rebuilt rather than trusted: knights_available_for_attack fills in the
           target and the list of buildings that can reach it, and it is what
           start_attack reads. Running it here means both machines work that list
           out themselves from the same world, and the only things that had to
           cross the wire are which building and how many knights.

           It also re-syncs those fields. The attack box sets them locally so it
           has something to draw, which leaves them adrift on the two machines
           until an attack actually happens - harmless, because nothing but
           start_attack reads them, and this puts them back in step. */
        var _target = _player.game.get_building(_value);
        if (_target != undefined) {
            _player.knights_available_for_attack(_target.get_position());
            _player.knights_attacking = min(_extra[0],
                                            _player.total_attacking_knights);
            if (_player.knights_attacking > 0 &&
                _player.attacking_building_count > 0) {
                _player.start_attack();
            }
        }
        break;

    case NetSetting.reset_food:           _player.reset_food_priority(); break;
    case NetSetting.reset_planks:         _player.reset_planks_priority(); break;
    case NetSetting.reset_steel:          _player.reset_steel_priority(); break;
    case NetSetting.reset_coal:           _player.reset_coal_priority(); break;
    case NetSetting.reset_wheat:          _player.reset_wheat_priority(); break;
    case NetSetting.reset_tool:           _player.reset_tool_priority(); break;
    case NetSetting.reset_flag_prio:      _player.reset_flag_priority(); break;
    case NetSetting.reset_inventory_prio: _player.reset_inventory_priority(); break;

    default:
        show_debug_message("net: unknown player setting " + string(_setting));
        break;
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
#macro NET_HASH_PARTS 15

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

    /* 2: buildings */
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
        _h = net_hash_fold(_h, _b.owner);
        _h = net_hash_fold(_h, _b.u);
        _h = net_hash_fold(_h, _b.first_knight);
        _h = net_hash_fold(_h, net_bit(_b.constructing));
        _h = net_hash_fold(_h, net_bit(_b.holder));
        _h = net_hash_fold(_h, net_bit(_b.active));
        _h = net_hash_fold(_h, net_bit(_b.burning));
        _h = net_hash_fold(_h, net_bit(_b.serf_requested));
        _h = net_hash_fold(_h, net_bit(_b.serf_request_failed));
        for (var _sl = 0; _sl < BUILDING_MAX_STOCK; _sl++) {
            var _st = _b.stock[_sl];
            _h = net_hash_fold(_h, _st.type);
            _h = net_hash_fold(_h, _st.prio);
            _h = net_hash_fold(_h, _st.available);
            _h = net_hash_fold(_h, _st.requested);
            _h = net_hash_fold(_h, _st.maximum);
        }
    }
    _out[2] = _h;

    /* 3: flags */
    _h = 0;
    var _flags = _game.flags.objects;
    for (var _k = 0; _k < array_length(_flags); _k++) {
        var _f = _flags[_k];
        if (_f == undefined) {
            continue;
        }
        _h = net_hash_fold(_h, _k);
        _h = net_hash_fold(_h, _f.pos);
        _h = net_hash_fold(_h, _f.owner);
        _h = net_hash_fold(_h, _f.path_con);
        _h = net_hash_fold(_h, _f.endpoint);
        _h = net_hash_fold(_h, _f.transporter);
        _h = net_hash_fold(_h, _f.bld_flags);
        _h = net_hash_fold(_h, _f.search_num);
        _h = net_hash_fold(_h, _f.search_dir);
        for (var _d = 0; _d < 6; _d++) {
            _h = net_hash_fold(_h, _f.length[_d]);
            _h = net_hash_fold(_h, _f.other_end_dir[_d]);
        }
        for (var _sl2 = 0; _sl2 < FLAG_MAX_RES_COUNT; _sl2++) {
            var _slot = _f.slot[_sl2];
            _h = net_hash_fold(_h, _slot.type);
            _h = net_hash_fold(_h, _slot.dir);
            _h = net_hash_fold(_h, _slot.dest);
        }
    }
    _out[3] = _h;

    /* 4: player bookkeeping */
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

        /* The settings themselves. These are what the popups change, and until
           they were commands nothing watched them - so a knights-menu click
           showed up much later as serfs in the wrong state, which reads like a
           simulation bug and is not one. Watch the thing that actually moved. */
        /* Bit 3 is "a message is waiting", and it is the one bit of player.flags
           that is SUPPOSED to differ: the simulation sets it on both machines,
           and each machine's own interface clears it when that player reads the
           message. Nothing in the simulation ever reads it. Hashing it would
           report a desync the first time somebody dismissed a notification. */
        _h = net_hash_fold(_h, _player.flags & ~(1 << 3));
        _h = net_hash_fold(_h, _player.build);
        _h = net_hash_fold(_h, _player.castle_knights_wanted);
        _h = net_hash_fold(_h, _player.serf_to_knight_rate);
        _h = net_hash_fold(_h, _player.serf_to_knight_counter);
        _h = net_hash_fold(_h, _player.knights_to_spawn);
        _h = net_hash_fold(_h, _player.reproduction_counter);
        _h = net_hash_fold(_h, _player.send_generic_delay);
        _h = net_hash_fold(_h, _player.food_stonemine);
        _h = net_hash_fold(_h, _player.food_coalmine);
        _h = net_hash_fold(_h, _player.food_ironmine);
        _h = net_hash_fold(_h, _player.food_goldmine);
        _h = net_hash_fold(_h, _player.planks_construction);
        _h = net_hash_fold(_h, _player.planks_boatbuilder);
        _h = net_hash_fold(_h, _player.planks_toolmaker);
        _h = net_hash_fold(_h, _player.steel_toolmaker);
        _h = net_hash_fold(_h, _player.steel_weaponsmith);
        _h = net_hash_fold(_h, _player.coal_steelsmelter);
        _h = net_hash_fold(_h, _player.coal_goldsmelter);
        _h = net_hash_fold(_h, _player.coal_weaponsmith);
        _h = net_hash_fold(_h, _player.wheat_pigfarm);
        _h = net_hash_fold(_h, _player.wheat_mill);
        for (var _ko = 0; _ko < array_length(_player.knight_occupation); _ko++) {
            _h = net_hash_fold(_h, _player.knight_occupation[_ko]);
        }
        for (var _tp = 0; _tp < array_length(_player.tool_prio); _tp++) {
            _h = net_hash_fold(_h, _player.tool_prio[_tp]);
        }
        for (var _fp = 0; _fp < array_length(_player.flag_prio); _fp++) {
            _h = net_hash_fold(_h, _player.flag_prio[_fp]);
        }
        for (var _ip = 0; _ip < array_length(_player.inventory_prio); _ip++) {
            _h = net_hash_fold(_h, _player.inventory_prio[_ip]);
        }
    }
    _out[4] = _h;

    /* 5..10: serfs, one hash per field.
       Splitting them is what turns "the serfs differ" into an answer. Which
       field parts company says what KIND of problem it is:
         count      - a serf exists on one machine and not the other
         pos/state  - the state machine took a different path: a logic problem
         anim       - the same, one step earlier
         counter    - the state machine agrees but the two are at different
                      points within a step: a TIMING problem, and counter is
                      driven by (game.tick - serf.tick), so
         tick       - names which half of that is adrift. */
    var _count = 0;
    var _h_pos = 0;
    var _h_state = 0;
    var _h_anim = 0;
    var _h_counter = 0;
    var _h_tick = 0;

    var _serfs = _game.serfs.objects;
    for (var _i = 0; _i < array_length(_serfs); _i++) {
        var _s = _serfs[_i];
        if (_s == undefined) {
            continue;
        }
        _count += 1;
        _h_pos     = net_hash_fold(net_hash_fold(_h_pos, _i), _s.pos);
        _h_state   = net_hash_fold(net_hash_fold(_h_state, _i), _s.state);
        _h_anim    = net_hash_fold(net_hash_fold(_h_anim, _i), _s.animation);
        _h_counter = net_hash_fold(net_hash_fold(_h_counter, _i), _s.counter);
        _h_tick    = net_hash_fold(net_hash_fold(_h_tick, _i), _s.tick);
    }

    _out[5]  = _count;
    _out[6]  = _h_pos;
    _out[7]  = _h_state;
    _out[8]  = _h_anim;
    _out[9]  = _h_counter;
    _out[10] = _h_tick;

    /* 11: the slot LAYOUT, contents ignored - which indexes are occupied, and
       how long the array is.

       Parts 6..10 fold the slot index in, so a serf sitting in a different slot
       on the two machines breaks all five at once while serf_count stays equal.
       That is exactly what the logs have been showing, and it looks identical to
       a state-machine divergence. This part tells the two apart: if serf_slots
       differs, the simulations agree about the serfs and disagree about where
       they are stored, and the fault is in Collection allocate/erase order, not
       in the serf logic. */
    _h = net_hash_fold(0, array_length(_serfs));
    for (var _q = 0; _q < array_length(_serfs); _q++) {
        if (_serfs[_q] == undefined) {
            continue;
        }
        _h = net_hash_fold(_h, _q);
    }

    /* The free list too, in order: two machines whose free lists have drifted
       will hand the next serf a different slot, so this catches the problem one
       allocation BEFORE it shows up in the serfs themselves. */
    var _free = _game.serfs.free_object_indexes;
    _h = net_hash_fold(_h, array_length(_free));
    for (var _r = 0; _r < array_length(_free); _r++) {
        _h = net_hash_fold(_h, _free[_r]);
    }
    _out[11] = _h;

    /* 12: serf TYPE.

       Left out of 6..10 and it should not have been: the first two-machine
       comparison showed one serf as generic on one side and a transporter on
       the other, a difference none of the other parts can see. A serf's type
       changes when an inventory specialises it, so this part watches the
       inventory's decisions from the outside. */
    _h = 0;
    for (var _t = 0; _t < array_length(_serfs); _t++) {
        var _st2 = _serfs[_t];
        if (_st2 == undefined) {
            continue;
        }
        _h = net_hash_fold(net_hash_fold(_h, _t), _st2.get_type());
    }
    _out[12] = _h;

    /* 13: inventories - what each stock holds, who is waiting to come out of
       it, and what it is holding back.

       Nothing was watching these at all, which is why a divergence in who gets
       called out of the castle only became visible turns later as two serfs in
       the wrong state. */
    _h = 0;
    var _invs = _game.inventories.objects;
    for (var _n2 = 0; _n2 < array_length(_invs); _n2++) {
        var _inv = _invs[_n2];
        if (_inv == undefined) {
            continue;
        }
        _h = net_hash_fold(_h, _n2);
        _h = net_hash_fold(_h, _inv.owner);
        _h = net_hash_fold(_h, _inv.flag);
        _h = net_hash_fold(_h, _inv.building);
        _h = net_hash_fold(_h, _inv.serfs_out);
        _h = net_hash_fold(_h, _inv.generic_count);
        _h = net_hash_fold(_h, _inv.res_dir);
        for (var _r2 = 0; _r2 < ResourceType.types_count; _r2++) {
            _h = net_hash_fold(_h, _inv.resources[_r2]);
        }
        for (var _q2 = 0; _q2 < 2; _q2++) {
            _h = net_hash_fold(_h, _inv.out_queue[_q2].type);
            _h = net_hash_fold(_h, _inv.out_queue[_q2].dest);
        }
        for (var _y2 = 0; _y2 < array_length(_inv.serfs); _y2++) {
            _h = net_hash_fold(_h, _inv.serfs[_y2]);
        }
    }
    _out[13] = _h;

    /* 14: the map, a slice at a time.

       Nothing has ever watched the map, which is the last big hole: ownership
       and borders, the paths a road actually laid down, tree growth, mineral
       amounts, fish, and which serf each tile thinks it is holding. A divergence
       in any of those has only ever surfaced later and indirectly, as serfs
       walking somewhere different.

       It cannot be hashed whole - tens of thousands of tiles, twelve times a
       second, in GML. So each turn hashes one slice of NET_MAP_SLICES, chosen by
       the turn number, and the whole map is covered every NET_MAP_SLICES turns.
       A divergence is then caught within a couple of seconds instead of never,
       for a sixteenth of the cost. Both machines pick the same slice because
       they agree about the turn. */
    _h = 0;
    var _map = _game.map;
    if (_map != undefined) {
        var _n_tiles = array_length(_map.owner);
        var _slice = global.net_map_slice;
        _h = net_hash_fold(_h, _slice);
        for (var _t2 = _slice; _t2 < _n_tiles; _t2 += NET_MAP_SLICES) {
            _h = net_hash_fold(_h, _map.paths[_t2]);
            _h = net_hash_fold(_h, _map.obj[_t2]);
            _h = net_hash_fold(_h, _map.obj_index[_t2]);
            _h = net_hash_fold(_h, _map.owner[_t2]);
            _h = net_hash_fold(_h, _map.serf[_t2]);
            /* The knight occupancy layer is simulation state like any other -
               see MAP_KNIGHTS_PHANTOM in scr_map.gml - so it is hashed with
               the rest. It is deterministic on both machines: which layer a
               serf lands on follows from his type, and nothing about it
               depends on what either player is looking at. */
            _h = net_hash_fold(_h, _map.knight[_t2]);
            _h = net_hash_fold(_h, _map.res_amount[_t2]);
        }
    }
    _out[14] = _h;

    return _out;
}

/// A GML bool folded to a number the hash can eat. Writing "true" into the fold
/// works by accident; this says so on purpose.
function net_bit(_v) {
    if (_v) {
        return 1;
    }
    return 0;
}

/// One digest per SLOT of the serf collection, holes included as zero so the
/// two machines' arrays line up index for index.
///
/// The component hashes say the serfs differ; this says WHICH serf, which is the
/// difference between a theory and a fact. Forty-odd serfs is a couple of
/// hundred bytes a turn - there is no reason to be frugal on a LAN.
function net_serf_digests(_game) {
    if (_game == undefined) {
        return [];
    }

    var _serfs = _game.serfs.objects;
    var _n = array_length(_serfs);
    var _out = array_create(_n, 0);

    for (var _i = 0; _i < _n; _i++) {
        var _s = _serfs[_i];
        if (_s == undefined) {
            continue;
        }
        var _h = net_hash_fold(0, _s.pos);
        _h = net_hash_fold(_h, _s.state);
        _h = net_hash_fold(_h, _s.animation);
        _h = net_hash_fold(_h, _s.counter);
        _out[_i] = net_hash_fold(_h, _s.tick);
    }

    return _out;
}

/// One digest per building slot: the same fields part 2 folds.
function net_building_digests(_game) {
    if (_game == undefined) {
        return [];
    }
    var _a = _game.buildings.objects;
    var _out = array_create(array_length(_a), 0);
    for (var _i = 0; _i < array_length(_a); _i++) {
        var _b = _a[_i];
        if (_b == undefined) {
            continue;
        }
        var _h = net_hash_fold(0, _b.pos);
        _h = net_hash_fold(_h, _b.get_type());
        _h = net_hash_fold(_h, _b.progress);
        _h = net_hash_fold(_h, _b.owner);
        _h = net_hash_fold(_h, _b.u);
        _h = net_hash_fold(_h, _b.first_knight);
        _h = net_hash_fold(_h, net_bit(_b.constructing));
        _h = net_hash_fold(_h, net_bit(_b.holder));
        _h = net_hash_fold(_h, net_bit(_b.active));
        _h = net_hash_fold(_h, net_bit(_b.burning));
        _h = net_hash_fold(_h, net_bit(_b.serf_requested));
        _h = net_hash_fold(_h, net_bit(_b.serf_request_failed));
        for (var _k = 0; _k < BUILDING_MAX_STOCK; _k++) {
            var _st = _b.stock[_k];
            _h = net_hash_fold(_h, _st.type);
            _h = net_hash_fold(_h, _st.prio);
            _h = net_hash_fold(_h, _st.available);
            _h = net_hash_fold(_h, _st.requested);
            _h = net_hash_fold(_h, _st.maximum);
        }
        _out[_i] = _h;
    }
    return _out;
}

/// One digest per flag slot: the same fields part 3 folds.
function net_flag_digests(_game) {
    if (_game == undefined) {
        return [];
    }
    var _a = _game.flags.objects;
    var _out = array_create(array_length(_a), 0);
    for (var _i = 0; _i < array_length(_a); _i++) {
        var _f = _a[_i];
        if (_f == undefined) {
            continue;
        }
        var _h = net_hash_fold(0, _f.pos);
        _h = net_hash_fold(_h, _f.owner);
        _h = net_hash_fold(_h, _f.path_con);
        _h = net_hash_fold(_h, _f.endpoint);
        _h = net_hash_fold(_h, _f.transporter);
        _h = net_hash_fold(_h, _f.bld_flags);
        _h = net_hash_fold(_h, _f.search_num);
        _h = net_hash_fold(_h, _f.search_dir);
        for (var _d = 0; _d < 6; _d++) {
            _h = net_hash_fold(_h, _f.length[_d]);
            _h = net_hash_fold(_h, _f.other_end_dir[_d]);
        }
        for (var _k = 0; _k < FLAG_MAX_RES_COUNT; _k++) {
            var _sl = _f.slot[_k];
            _h = net_hash_fold(_h, _sl.type);
            _h = net_hash_fold(_h, _sl.dir);
            _h = net_hash_fold(_h, _sl.dest);
        }
        _out[_i] = _h;
    }
    return _out;
}

/// One digest per inventory slot: the same fields part 13 folds.
function net_inventory_digests(_game) {
    if (_game == undefined) {
        return [];
    }
    var _a = _game.inventories.objects;
    var _out = array_create(array_length(_a), 0);
    for (var _i = 0; _i < array_length(_a); _i++) {
        var _v = _a[_i];
        if (_v == undefined) {
            continue;
        }
        var _h = net_hash_fold(0, _v.owner);
        _h = net_hash_fold(_h, _v.flag);
        _h = net_hash_fold(_h, _v.building);
        _h = net_hash_fold(_h, _v.serfs_out);
        _h = net_hash_fold(_h, _v.generic_count);
        _h = net_hash_fold(_h, _v.res_dir);
        for (var _r = 0; _r < ResourceType.types_count; _r++) {
            _h = net_hash_fold(_h, _v.resources[_r]);
        }
        for (var _q = 0; _q < 2; _q++) {
            _h = net_hash_fold(_h, _v.out_queue[_q].type);
            _h = net_hash_fold(_h, _v.out_queue[_q].dest);
        }
        for (var _y = 0; _y < array_length(_v.serfs); _y++) {
            _h = net_hash_fold(_h, _v.serfs[_y]);
        }
        _out[_i] = _h;
    }
    return _out;
}

/// Everything this machine knows about the world, hashed two ways: the coarse
/// parts that say WHETHER we agree, and the per-object digests that say WHICH
/// object we disagree about.
function net_world_snapshot(_game, _turn) {
    /* Which slice of the map this turn hashes. Both machines are hashing the
       same turn, so both pick the same slice. */
    global.net_map_slice = _turn mod NET_MAP_SLICES;

    return {
        parts:     net_hash_parts(_game),
        serfs:     net_serf_digests(_game),
        buildings: net_building_digests(_game),
        flags:     net_flag_digests(_game),
        invs:      net_inventory_digests(_game)
    };
}

/// Everything about one building, in a line, for the log.
function net_building_line(_game, _i) {
    var _a = _game.buildings.objects;
    if (_i < 0 || _i >= array_length(_a)) {
        return "building " + string(_i) + ": out of range";
    }
    var _b = _a[_i];
    if (_b == undefined) {
        return "building " + string(_i) + ": EMPTY SLOT";
    }
    var _line = "building " + string(_i) +
                ": type=" + string(_b.get_type()) +
                " owner=" + string(_b.owner) +
                " pos=" + string(_b.pos) +
                " progress=" + string(_b.progress) +
                " u=" + string(_b.u) +
                " constructing=" + string(net_bit(_b.constructing)) +
                " holder=" + string(net_bit(_b.holder)) +
                " active=" + string(net_bit(_b.active)) +
                " burning=" + string(net_bit(_b.burning)) +
                " serf_requested=" + string(net_bit(_b.serf_requested)) +
                " req_failed=" + string(net_bit(_b.serf_request_failed)) +
                " first_knight=#" + string(_b.first_knight);
    for (var _k = 0; _k < BUILDING_MAX_STOCK; _k++) {
        var _st = _b.stock[_k];
        _line += " | stock" + string(_k) + " type=" + string(_st.type) +
                 " avail=" + string(_st.available) +
                 " req=" + string(_st.requested) +
                 " max=" + string(_st.maximum) +
                 " prio=" + string(_st.prio);
    }
    return _line;
}

/// Everything about one flag, in a line, for the log.
function net_flag_line(_game, _i) {
    var _a = _game.flags.objects;
    if (_i < 0 || _i >= array_length(_a)) {
        return "flag " + string(_i) + ": out of range";
    }
    var _f = _a[_i];
    if (_f == undefined) {
        return "flag " + string(_i) + ": EMPTY SLOT";
    }
    var _line = "flag " + string(_i) +
                ": pos=" + string(_f.pos) +
                " owner=" + string(_f.owner) +
                " path_con=" + string(_f.path_con) +
                " endpoint=" + string(_f.endpoint) +
                " transporter=" + string(_f.transporter) +
                " bld_flags=" + string(_f.bld_flags) +
                " search_num=" + string(_f.search_num) +
                " search_dir=" + string(_f.search_dir);
    for (var _k = 0; _k < FLAG_MAX_RES_COUNT; _k++) {
        var _sl = _f.slot[_k];
        if (_sl.type == ResourceType.none) {
            continue;
        }
        _line += " | slot" + string(_k) + " res=" + string(_sl.type) +
                 " dir=" + string(_sl.dir) + " dest=" + string(_sl.dest);
    }
    return _line;
}

/// Everything about one inventory, in a line, for the log. The serfs-by-type
/// table is the interesting half: it is what call_out_serf reads.
function net_inventory_line(_game, _i) {
    var _a = _game.inventories.objects;
    if (_i < 0 || _i >= array_length(_a)) {
        return "inventory " + string(_i) + ": out of range";
    }
    var _v = _a[_i];
    if (_v == undefined) {
        return "inventory " + string(_i) + ": EMPTY SLOT";
    }
    var _line = "inventory " + string(_i) +
                ": owner=" + string(_v.owner) +
                " building=" + string(_v.building) +
                " flag=" + string(_v.flag) +
                " serfs_out=" + string(_v.serfs_out) +
                " generic=" + string(_v.generic_count) +
                " res_dir=" + string(_v.res_dir) +
                " out_queue=" + string(_v.out_queue[0].type) + "/" +
                string(_v.out_queue[0].dest) + "," +
                string(_v.out_queue[1].type) + "/" +
                string(_v.out_queue[1].dest);
    _line += " | serfs:";
    for (var _y = 0; _y < array_length(_v.serfs); _y++) {
        if (_v.serfs[_y] != 0) {
            _line += " t" + string(_y) + "=#" + string(_v.serfs[_y]);
        }
    }
    _line += " | res:";
    for (var _r = 0; _r < ResourceType.types_count; _r++) {
        if (_v.resources[_r] != 0) {
            _line += " r" + string(_r) + "=" + string(_v.resources[_r]);
        }
    }
    return _line;
}

/// Everything about one serf, in a line, for the log. Both machines write their
/// own; the two logs side by side are the whole answer.
function net_serf_line(_game, _i) {
    if (_game == undefined) {
        return "serf " + string(_i) + ": no game";
    }
    var _serfs = _game.serfs.objects;
    if (_i < 0 || _i >= array_length(_serfs)) {
        return "serf " + string(_i) + ": out of range";
    }
    var _s = _serfs[_i];
    if (_s == undefined) {
        return "serf " + string(_i) + ": EMPTY SLOT";
    }
    return "serf " + string(_i) +
           ": type=" + string(_s.get_type()) +
           " owner=" + string(_s.get_owner()) +
           " state=" + string(_s.state) +
           " pos=" + string(_s.pos) +
           " anim=" + string(_s.animation) +
           " counter=" + string(_s.counter) +
           " tick=" + string(_s.tick);
}

function net_hash_part_name(_i) {
    switch (_i) {
    case 0:  return "tick";
    case 1:  return "rnd";
    case 2:  return "buildings";
    case 3:  return "flags";
    case 4:  return "players";
    case 5:  return "serf_count";
    case 6:  return "serf_pos";
    case 7:  return "serf_state";
    case 8:  return "serf_anim";
    case 9:  return "serf_counter";
    case 10: return "serf_tick";
    case 11: return "serf_slots";
    case 12: return "serf_type";
    case 13: return "inventories";
    case 14: return "map";
    }
    return "?";
}

function net_hash_fold(_h, _v) {
    var _r = ((_h * 31) + _v) mod 2147483647;
    if (_r < 0) {
        _r += 2147483647;
    }
    return _r;
}

/// Compare this turn's component hashes with the peer's, and name the first
/// component that differs.
function net_compare_check(_game, _turn) {
    var _mine = net_world_snapshot(_game, _turn);
    net_send_check(_turn, _mine);

    var _key = string(_turn);
    if (!ds_map_exists(global.net_checks, _key)) {
        ds_map_set(global.net_checks, "M" + _key, _mine);
        return;
    }

    var _theirs = ds_map_find_value(global.net_checks, _key);
    ds_map_delete(global.net_checks, _key);
    net_report_check(_game, _turn, _mine, _theirs);
}

function net_report_check(_game, _turn, _mine, _theirs) {
    var _first = -1;
    for (var _i = 0; _i < NET_HASH_PARTS; _i++) {
        if (_mine.parts[_i] != _theirs.parts[_i]) {
            _first = _i;
            break;
        }
    }

    if (_first < 0) {
        return;   /* in step */
    }

    for (var _j = 0; _j < NET_HASH_PARTS; _j++) {
        var _mark = "  ";
        if (_mine.parts[_j] != _theirs.parts[_j]) {
            _mark = "**";
        }
        net_log(_mark + " turn " + string(_turn) + " " + net_hash_part_name(_j) +
                ": mine=" + string(_mine.parts[_j]) +
                " theirs=" + string(_theirs.parts[_j]));
    }

    net_log_obj_diff(_game, _turn, "building", _mine.buildings, _theirs.buildings,
                     net_building_line);
    net_log_obj_diff(_game, _turn, "flag", _mine.flags, _theirs.flags,
                     net_flag_line);
    net_log_obj_diff(_game, _turn, "inventory", _mine.invs, _theirs.invs,
                     net_inventory_line);
    net_log_obj_diff(_game, _turn, "serf", _mine.serfs, _theirs.serfs,
                     net_serf_line);

    net_fail("DESYNC turn " + string(_turn) + " in " + net_hash_part_name(_first) +
             " (" + string(_mine.parts[_first]) + " vs " +
             string(_theirs.parts[_first]) + ")" +
             net_parts_summary(_mine.parts, _theirs.parts));
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

/// Name every object of one kind whose digest differs, and write this machine's
/// full state for the first few.
///
/// _line_fn is the per-kind formatter, passed in so buildings, flags,
/// inventories and serfs all report the same way. Run the two machines' logs
/// side by side and the disagreement is right there in the numbers instead of
/// being reasoned about.
function net_log_obj_diff(_game, _turn, _kind, _mine, _theirs, _line_fn) {
    if (array_length(_mine) != array_length(_theirs)) {
        net_log("   turn " + string(_turn) + " " + _kind + " slots: mine=" +
                string(array_length(_mine)) + " theirs=" +
                string(array_length(_theirs)));
    }

    var _n = array_length(_mine);
    if (array_length(_theirs) < _n) {
        _n = array_length(_theirs);
    }

    var _found = 0;
    var _list = "";
    for (var _i = 0; _i < _n; _i++) {
        if (_mine[_i] == _theirs[_i]) {
            continue;
        }
        _found += 1;
        if (_found <= 12) {
            _list += string(_i) + " ";
        }
        if (_found <= 4) {
            /* The digests were taken at the check turn; this line is read off
               the game as it stands now, which on the late-check path is up to
               NET_TURN_DELAY turns later. Compare the two logs' lines with each
               other, not with the digest. */
            net_log("** " + _line_fn(_game, _i) + "   (state now)");
        }
    }

    /* Slots past the end of the shorter array are a difference too, and the
       walk above cannot see them. A flag that exists on one machine and not the
       other showed up only as "flag slots: mine=6 theirs=7" with nothing named,
       which is half an answer. */
    var _extra = array_length(_mine);
    for (var _e = _n; _e < _extra; _e++) {
        _found += 1;
        if (_found <= 12) {
            _list += string(_e) + "! ";
        }
        net_log("** " + _line_fn(_game, _e) + "   (ONLY ON THIS MACHINE)");
    }

    if (_found == 0) {
        return;
    }

    net_log("   " + string(_found) + " " + _kind + "(s) differ, first few: " + _list);
}

/// Compare any hashes whose partner arrived after we made ours.
///
/// The keys are collected before anything is deleted: ds_map_find_next after
/// deleting the key it was standing on is not defined, and this walk deletes as
/// it goes.
function net_late_checks(_game) {
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

        net_report_check(_game, real(_turn_key), _mine, _theirs);
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
    /* Only a client is ever sent a start. A host that receives one has a
       peer that believes it is host too, which the declared roles make
       impossible short of two builds disagreeing - so it is logged and
       refused rather than acted on. */
    if (global.net_role != NetRole.client) {
        net_log("start arrived but we are not a client - ignored");
        return;
    }

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
    net_log_reset();
    net_log("starting as player " + string(_local_player + 1) +
            ", mission " + string(_game.mission_index + 1));
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

    /* The lobby is over on BOTH machines. The host closed it before starting,
       but the client never did - it kept shouting beacons for the whole game,
       and kept its own door open on the TCP port. Nothing about a game in
       progress wants either. */
    net_lobby_close();
    if (global.net_role == NetRole.client && global.net_server >= 0) {
        network_destroy(global.net_server);
        global.net_server = -1;
    }

    /* Prime the pipeline: the first NET_TURN_DELAY turns can carry no commands
       because nobody has had a chance to issue any, but their packets still
       have to exist or neither machine could ever start. */
    for (var _t = 0; _t < NET_TURN_DELAY; _t++) {
        net_send_turn(_t, []);
        net_schedule_local(_t, []);
    }

    global.net_phase = NetPhase.running;
    net_set_status("in game as player " + string(_local_player + 1));
    net_log(global.net_status);
}

// ================================================================ the lobby
//
// Every instance with the NET PLAY panel open listens on NET_PORT the whole
// time and shouts on NET_DISCOVERY_PORT once a second so the others can list
// it. Roles are DECLARED: one pc clicks HOST, its beacon then carries a
// "hosting" byte, and the other pc sees it marked HOSTING and clicks it to
// join as player 2. This is the F7 / F8 model the keys had before the panel,
// with the typing taken out. Two earlier versions tried to settle the roles
// from who dialled whom; both ended with the same role on both machines,
// because two people testing a panel click on both of them.
//
// The one case that needs a rule is both players picking each other inside the
// same second. Then each machine has an outbound connection AND an inbound one,
// and if both kept the inbound they would both think they were host. The
// tie-break is the SESSION ID each machine made at startup and has been
// shouting ever since - not the IP address, because GameMaker has no call that
// says what this machine's own address is, and comparing a number we do not
// have to one we do is not a comparison. Lower session id hosts. Both machines
// compare the same pair of numbers and reach opposite answers, which is the
// whole requirement.

#macro NET_DISCOVERY_PORT   6511
#macro NET_BEACON_FRAMES    45     // shout about every 0.75s at 60fps
#macro NET_PEER_STALE_MS    4000   // gone from the list this long after it stops
#macro NET_PEER_MAX         16
#macro NET_INI_MANUAL       "manual"

enum NetBeacon {
    hello = 200        // u8 tag, u32 session id, name string, u8 hosting
}

/* The hosting byte in the beacon. */
#macro NET_HOSTING_NO     0
#macro NET_HOSTING_OPEN   1     // hosting, nobody has joined yet: CLICK me
#macro NET_HOSTING_FULL   2     // hosting, player 2 already in

/// What this machine's beacon should say about hosting.
function net_hosting_state() {
    if (global.net_role != NetRole.host || net_is_running()) {
        return NET_HOSTING_NO;
    }
    if (global.net_socket >= 0) {
        return NET_HOSTING_FULL;
    }
    return NET_HOSTING_OPEN;
}

/// The HOST button. Open the door if it is not already open, and say so in
/// every beacon from now on. Clicking it while already hosting does nothing;
/// clicking it while joined as player 2 is refused - EXIT first.
function net_lobby_host() {
    if (net_is_running()) {
        return false;
    }
    if (global.net_role == NetRole.host) {
        return true;
    }
    if (global.net_role == NetRole.client) {
        net_set_status("already joined - press EXIT first");
        return false;
    }

    if (global.net_server < 0) {
        global.net_server = network_create_server(network_socket_tcp, NET_PORT, 1);
        if (global.net_server < 0) {
            net_set_status("can't host: port " + string(NET_PORT)
                           + " is busy - is a second copy running?");
            return false;
        }
    }

    global.net_role  = NetRole.host;
    global.net_phase = NetPhase.listening;
    global.net_local_player = 0;
    global.net_autostart = false;
    global.net_dialling = "";
    global.net_peer_ip = "";
    if (global.net_socket >= 0) {
        network_destroy(global.net_socket);
        global.net_socket = -1;
    }
    ds_map_clear(global.net_turns);
    ds_map_clear(global.net_checks);
    global.net_outbox = [];
    net_set_status("HOSTING - on the other pc, CLICK this pc's name");
    net_log(global.net_status);

    /* Say it now rather than in up to three quarters of a second. */
    global.net_beacon_count = 0;
    return true;
}

function net_lobby_init() {
    global.net_lobby_open   = false;
    global.net_udp          = -1;
    global.net_udp_bound    = false;
    global.net_beacon_count = 0;

    /* Peers we have heard from or been told about:
       { ip, name, seen (ms), manual (bool) } */
    global.net_peers = [];

    /* Ours, so our own broadcast can be told apart from everyone else's - they
       all arrive back at us, since a broadcast reaches the sender too. */
    /* The id has to DIFFER between two machines, and irandom alone does not
       guarantee that: GameMaker's generator can start from the same seed every
       run, so two copies of the same build hand out the same "random" number.
       That is what stopped discovery working - each machine heard the other's
       beacon, saw its own id on it, and threw it away as an echo of itself.
       Four hundred packets in and nobody in the list.

       randomise() fixes the seed, and get_timer() - microseconds since this
       process started - is mixed in so the id still differs even if it does
       not. Two machines started by hand are never the same number of
       microseconds old. */
    randomise();
    global.net_session_id = (irandom(0x7FFFFFFF) ^ (get_timer() & 0x7FFFFFFF))
                            & 0x7FFFFFFF;
    show_debug_message("net: session id " + string(global.net_session_id));
    global.net_my_name = "";

    /* The address we are dialling, kept so the tie-break can compare it. */
    global.net_dialling = "";

    /* Discovery counters. "They cannot see each other" is three different
       faults wearing the same face - nothing sent, sent but nothing arrives,
       or arrives and is not understood - and they need completely different
       fixes. These say which one it is instead of leaving it to guesswork. */
    global.net_beacons_sent  = 0;
    global.net_send_fail     = 0;
    global.net_last_send     = 0;
    global.net_datagrams     = 0;
    global.net_beacons_heard = 0;
    global.net_self_echo     = 0;
    global.net_last_from     = "";

}

function net_lobby_is_open() {
    return global.net_lobby_open;
}

/// Open the lobby: listen for anyone who picks us, and start shouting.
function net_lobby_open() {
    if (global.net_lobby_open) {
        return true;
    }

    global.net_lobby_open = true;
    global.net_my_name = net_local_name();
    net_load_manual_peers();

    /* The TCP door. Opening it is not a claim to be the host - it is what makes
       being picked possible. The role is decided in the connect event. */
    if (global.net_server < 0 && !net_is_active()) {
        global.net_server = network_create_server(network_socket_tcp, NET_PORT, 1);
        if (global.net_server < 0) {
            net_set_status("port " + string(NET_PORT) + " is busy - is a second copy running?");
        }
    }

    /* The UDP one has to be BOUND to the discovery port, not just created:
       an unbound socket can send a broadcast but never hear one. */
    if (global.net_udp < 0) {
        global.net_udp = network_create_socket_ext(network_socket_udp,
                                                   NET_DISCOVERY_PORT);
        global.net_udp_bound = (global.net_udp >= 0);
        if (global.net_udp < 0) {
            /* The port is taken - a second copy on this machine has it. An
               unbound socket cannot hear anybody, but it can still SHOUT, so
               the other side lists us even though we cannot list them. That
               is enough: whoever can see the other one clicks. */
            global.net_udp = network_create_socket(network_socket_udp);
            show_debug_message("net: UDP " + string(NET_DISCOVERY_PORT)
                               + " refused - sending only, socket "
                               + string(global.net_udp));
        }
    }

    global.net_beacon_count = 0;
    return true;
}

function net_lobby_close() {
    if (!global.net_lobby_open) {
        return;
    }
    global.net_lobby_open = false;

    if (global.net_udp >= 0) {
        network_destroy(global.net_udp);
        global.net_udp = -1;
    }

    /* The TCP server stays if a game is running on it, and goes if we are just
       leaving the lobby without having connected to anybody. */
    if (!net_is_active() && global.net_server >= 0) {
        network_destroy(global.net_server);
        global.net_server = -1;
    }

    global.net_peers = [];
}

/// A name for this machine in other people's lists.
///
/// Empty for now, and the list shows the address instead. GameMaker has no call
/// that gives the machine's name, and inventing one from something else - the
/// last save file, say - would put a label in front of the only thing that
/// actually identifies the machine. The field stays in the beacon so a name can
/// be added later without changing the wire format.
function net_local_name() {
    return "";
}

// ------------------------------------------------- what the lobby may show

/// Is this address one of the private ranges - reachable only from inside
/// somebody's own network, and meaningless to anybody outside it?
///
///   10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16   RFC 1918 private
///   127.0.0.0/8                                 loopback, this machine
///   169.254.0.0/16                              link-local, no DHCP
///
/// Anything else is routable on the internet and belongs to a real household.
function net_addr_is_private(_ip) {
    var _parts = net_split_dots(_ip);
    if (array_length(_parts) != 4) {
        /* Not an IPv4 literal - a hostname, or something typed wrong. Treat it
           as public: guessing "private" here would put it on screen. */
        return false;
    }

    var _a = _parts[0];
    var _b = _parts[1];

    if (_a == 10)  { return true; }
    if (_a == 127) { return true; }
    if (_a == 192 && _b == 168) { return true; }
    if (_a == 172 && _b >= 16 && _b <= 31) { return true; }
    if (_a == 169 && _b == 254) { return true; }

    return false;
}

/// Split "192.168.1.24" into [192, 168, 1, 24]. Returns [] unless all four
/// parts are present and are numbers in 0..255.
function net_split_dots(_ip) {
    var _out = [];
    var _current = "";
    var _n = string_length(_ip);

    for (var _i = 1; _i <= _n + 1; _i++) {
        var _c = "";
        if (_i <= _n) {
            _c = string_char_at(_ip, _i);
        }

        if (_c == "." || _i > _n) {
            if (string_length(_current) == 0 || string_length(_current) > 3) {
                return [];
            }
            var _v = real(_current);
            if (_v < 0 || _v > 255) {
                return [];
            }
            array_push(_out, _v);
            _current = "";
        } else if (_c >= "0" && _c <= "9") {
            _current += _c;
        } else {
            return [];
        }
    }

    if (array_length(_out) != 4) {
        return [];
    }
    return _out;
}

/// A short, stable, meaningless label for an address we must not print.
///
/// Same address always gives the same tag, on every machine and across
/// restarts, so a regular opponent stays recognisable from one game to the
/// next. It is NOT a secret - the tag is derived from the address and an
/// attacker who already had the address could confirm a match - it exists so
/// that a routable address never reaches the screen, which is the way these
/// get spread: a screenshot, a bug report, a video.
///
/// h * 31 + c, masked to 31 bits. The mask matters: GML numbers are doubles,
/// so a wider hash would silently lose precision past 2^53 and stop being the
/// same on both machines.
function net_addr_tag(_ip) {
    var _h = 2166136261;
    var _n = string_length(_ip);

    for (var _i = 1; _i <= _n; _i++) {
        _h = (((_h << 5) - _h) + ord(string_char_at(_ip, _i))) & 0x7FFFFFFF;
    }

    var _hex = "0123456789ABCDEF";
    var _out = "";
    for (var _d = 7; _d >= 0; _d--) {
        var _nibble = (_h >> (_d * 4)) & 0xF;
        _out += string_char_at(_hex, _nibble + 1);
    }

    return _out;
}

/// What the lobby is allowed to print for this peer.
///
/// A private address is shown as it is: it identifies nothing outside the
/// house, everybody's looks the same, and it is the only way to tell two
/// machines on one network apart - which is the whole job of the list.
///
/// A public address is replaced by its tag. Somebody demonstrating net play to
/// an audience cannot be expected to notice, mid-take, that the row now holds
/// a friend's home address, and the friend never agreed to it being on screen.
function net_peer_label(_peer) {
    if (_peer == undefined) {
        return "?";
    }
    return net_addr_label(_peer.ip);
}

function net_addr_label(_ip) {
    if (net_addr_is_private(_ip)) {
        return _ip;
    }
    return "Player " + net_addr_tag(_ip);
}

// ------------------------------------------------------------- the beacon

/// Called once a frame while the lobby is open.
function net_lobby_step() {
    if (!global.net_lobby_open) {
        return;
    }

    net_expire_peers();

    if (global.net_udp < 0) {
        return;
    }

    global.net_beacon_count -= 1;
    if (global.net_beacon_count > 0) {
        return;
    }
    global.net_beacon_count = NET_BEACON_FRAMES;

    var _b = global.net_send;
    buffer_seek(_b, buffer_seek_start, 0);
    buffer_write(_b, buffer_u8,     NetBeacon.hello);
    buffer_write(_b, buffer_u32,    global.net_session_id);
    buffer_write(_b, buffer_string, global.net_my_name);
    buffer_write(_b, buffer_u8,     net_hosting_state());

    /* The return value matters. A broadcast that the machine refuses to send
       fails here, quietly, and looks from the panel exactly like a broadcast
       nobody answered. */
    var _r = network_send_broadcast(global.net_udp, NET_DISCOVERY_PORT, _b,
                                    buffer_tell(_b));
    global.net_last_send = _r;
    if (_r < 0) {
        global.net_send_fail += 1;
    } else {
        global.net_beacons_sent += 1;
    }

    /* And the same beacon straight at every machine we know of - typed in OR
       heard from - not only to the broadcast address.

       Broadcast is the half that firewalls and wireless access points quietly
       drop. A unicast datagram to a specific machine is ordinary traffic and
       usually gets through where a broadcast does not.

       Heard-from peers get one too, and that is the half that was missing.
       With only typed-in addresses answered, adding the host's address on the
       joining pc made the HOST hear the joiner - but the joiner still only had
       the host's broadcast to go on, which is the thing that was not
       arriving. So the host showed the joiner as online and the joiner showed
       the host as "no answer", for as long as they cared to look. Now hearing
       a machine means shouting back at it directly, so one typed-in address on
       either side is enough for both lists to fill. */
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        var _p = global.net_peers[_i];
        network_send_udp(global.net_udp, _p.ip, NET_DISCOVERY_PORT, _b,
                         buffer_tell(_b));
    }

    /* Once every roughly thirty seconds, into the log, so a session that did
       not work can be read back afterwards instead of described. */
    if ((global.net_beacons_sent + global.net_send_fail) mod 40 == 1) {
        net_log("discovery: sent=" + string(global.net_beacons_sent) +
                " failed=" + string(global.net_send_fail) +
                " last=" + string(global.net_last_send) +
                " datagrams_in=" + string(global.net_datagrams) +
                " beacons_in=" + string(global.net_beacons_heard) +
                " self_echo=" + string(global.net_self_echo) +
                " id=" + string(global.net_session_id) +
                " udp_socket=" + string(global.net_udp));
    }
}

/// A beacon arrived. Ours comes back to us too, hence the session id.
function net_receive_beacon(_b, _ip) {
    global.net_datagrams += 1;
    global.net_last_from = string(_ip);

    var _session = buffer_read(_b, buffer_u32);
    if (_session == global.net_session_id) {
        /* Our own broadcast, come back to us - or, when two machines have
           somehow ended up with the same id, the other machine's beacon
           mistaken for ours. Counted separately, because those two look
           identical from an empty list and the second one is a bug. */
        global.net_self_echo += 1;
        return;
    }

    global.net_beacons_heard += 1;
    net_log("discovery: heard " + string(_ip));

    var _name = buffer_read(_b, buffer_string);
    var _hosting = buffer_read(_b, buffer_u8);
    net_note_peer(_ip, _name, false);
    net_note_peer_session(_ip, _session);
    net_note_peer_hosting(_ip, _hosting);
}

/// Remember what a peer's beacon said about hosting.
function net_note_peer_hosting(_ip, _hosting) {
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        if (global.net_peers[_i].ip == _ip) {
            global.net_peers[_i].hosting = _hosting;
            return;
        }
    }
}

/// Record a peer, or refresh one we already have. A manual entry stays manual
/// even once it starts answering, so it survives going quiet.
function net_note_peer(_ip, _name, _manual) {
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        var _p = global.net_peers[_i];
        if (_p.ip == _ip) {
            _p.seen = current_time;
            if (_name != "") {
                _p.name = _name;
            }
            if (_manual) {
                _p.manual = true;
            }
            return;
        }
    }

    if (array_length(global.net_peers) >= NET_PEER_MAX) {
        return;
    }

    array_push(global.net_peers, {
        ip:      _ip,
        name:    _name,
        seen:    current_time,
        manual:  _manual,
        session: -1,         /* -1 until a beacon from it says otherwise */
        hosting: NET_HOSTING_NO
    });
}

/// Remember a peer's session id. It is what settles a simultaneous pick, so it
/// is worth keeping even for a peer that was typed in rather than heard.
function net_note_peer_session(_ip, _session) {
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        if (global.net_peers[_i].ip == _ip) {
            global.net_peers[_i].session = _session;
            return;
        }
    }
}

/// A peer's session id, or -1 if we have never heard it shout.
function net_peer_session(_ip) {
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        if (global.net_peers[_i].ip == _ip) {
            return global.net_peers[_i].session;
        }
    }
    return -1;
}

/// Drop anyone who has stopped shouting. Manual entries are never dropped -
/// they were typed in on purpose, and one that is switched off should read as
/// "no answer" rather than vanishing while you look at it.
function net_expire_peers() {
    var _keep = [];
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        var _p = global.net_peers[_i];
        if (_p.manual || (current_time - _p.seen) < NET_PEER_STALE_MS) {
            array_push(_keep, _p);
        }
    }
    global.net_peers = _keep;
}

/// One line saying what discovery has actually managed to do, for the panel.
function net_discovery_summary() {
    if (global.net_udp < 0) {
        return "discovery off - no UDP socket at all";
    }
    if (!global.net_udp_bound) {
        return "can't hear others (UDP " + string(NET_DISCOVERY_PORT)
               + " taken) - shouting only";
    }
    /* One line, forty characters. The last six digits of the id are enough to
       tell two machines apart at a glance, and the whole of it goes to the log
       anyway. */
    var _out = "id " + string(global.net_session_id mod 1000000)
               + "  out " + string(global.net_beacons_sent);
    if (global.net_send_fail > 0) {
        _out += "!" + string(global.net_last_send);
    }
    _out += "  in " + string(global.net_datagrams)
            + "/" + string(global.net_beacons_heard);
    if (global.net_self_echo > 0) {
        _out += "  own " + string(global.net_self_echo);
    }
    return _out;
}

function net_peer_count() {
    return array_length(global.net_peers);
}

function net_peer_at(_i) {
    if (_i < 0 || _i >= array_length(global.net_peers)) {
        return undefined;
    }
    return global.net_peers[_i];
}

/// Whether a peer has been heard from recently, whatever its origin.
function net_peer_is_live(_peer) {
    return ((current_time - _peer.seen) < NET_PEER_STALE_MS);
}

// ------------------------------------------------------- manual addresses

/// Split on commas. Hand-rolled to match the rest of the port, which does not
/// use string_split.
function net_split_commas(_str) {
    var _out = [];
    var _from = 1;
    var _n = string_length(_str);

    while (_from <= _n + 1) {
        var _to = _from;
        while (_to <= _n && string_char_at(_str, _to) != ",") {
            _to += 1;
        }
        array_push(_out, string_copy(_str, _from, _to - _from));
        _from = _to + 1;
    }

    return _out;
}

function net_load_manual_peers() {
    ini_open(PROGRESS_PATH);
    var _list = ini_read_string(NET_INI_SECTION, NET_INI_MANUAL, "");
    ini_close();

    if (_list == "") {
        return;
    }

    var _parts = net_split_commas(_list);
    for (var _i = 0; _i < array_length(_parts); _i++) {
        var _ip = string_trim(_parts[_i]);
        if (_ip != "") {
            /* seen is pushed into the past so it reads as "no answer" until it
               actually answers, rather than looking live because it was typed. */
            net_note_peer(_ip, "", true);
            global.net_peers[array_length(global.net_peers) - 1].seen =
                current_time - NET_PEER_STALE_MS;
        }
    }
}

function net_save_manual_peers() {
    var _list = "";
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        var _p = global.net_peers[_i];
        if (!_p.manual) {
            continue;
        }
        if (_list != "") {
            _list += ",";
        }
        _list += _p.ip;
    }

    ini_open(PROGRESS_PATH);
    ini_write_string(NET_INI_SECTION, NET_INI_MANUAL, _list);
    ini_close();
}

function net_add_manual_peer(_ip) {
    _ip = string_trim(_ip);
    if (_ip == "") {
        return false;
    }
    net_note_peer(_ip, "", true);
    net_save_manual_peers();
    return true;
}

function net_forget_peer(_ip) {
    var _keep = [];
    for (var _i = 0; _i < array_length(global.net_peers); _i++) {
        if (global.net_peers[_i].ip != _ip) {
            array_push(_keep, global.net_peers[_i]);
        }
    }
    global.net_peers = _keep;
    net_save_manual_peers();
}

// ------------------------------------------------------------ picking one

/// JOIN a peer: dial it. If it answers, it is the host and we are player 2.
function net_lobby_pick(_ip) {
    if (net_is_active()) {
        return false;
    }

    global.net_dialling = _ip;
    var _ok = net_join(_ip);
    if (!_ok) {
        global.net_dialling = "";
    }
    return _ok;
}
