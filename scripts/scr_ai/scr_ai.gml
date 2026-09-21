/// scr_ai - opponent AI, stage 1: territory expansion.
///
/// Freeserf never wrote one. game.cc:660 is an #if 0 block containing two
/// `/* TODO */` comments, so there is nothing upstream to port and this is new
/// code rather than a translation.
///
/// Stage 1 only does one thing: claim ground. Once every AI_UPDATE_INTERVAL
/// ticks an AI player looks for somewhere to put a knight hut, puts one there,
/// and connects it to its road network. Economy and attacking come later; the
/// point of this stage is to prove the update hook, the placement scoring and
/// the road building all work before anything is layered on top.
///
/// Difficulty comes from the mission table, which already carries per-opponent
/// intelligence / supply / reproduction values.

/// Ticks between decisions for one player. The original spread AI work out over
/// time rather than acting every tick, and so does this: it keeps the cost off
/// the critical path and stops all the opponents moving in lockstep.
#macro AI_UPDATE_INTERVAL 400

/// How far out from an existing military building to look for a site.
/// The spiral pattern holds 295 entries; 1 + 6 + 12 + 18 + 24 covers the first
/// four rings, which is roughly the radius a hut claims.
#macro AI_SCAN_POSITIONS 61

/// The same for a HUT, where four rings is not enough. can_build_military
/// refuses anything within two rings of another military building, so as the
/// border fills the legal ground moves outward faster than the search does -
/// and the AI reports "hut site none in reach" while sitting on plenty of its
/// own land. Seven rings (1 + 6 + 12 + ... + 42) is still well inside the
/// 295-entry pattern.
#macro AI_HUT_SCAN_POSITIONS 169

/// Cap on military buildings. Stage 1 held this at 8 because the AI could only
/// spend the castle's opening stock; with an economy behind it there is more
/// room, though it is still bounded so huts do not crowd out the industry.
#macro AI_MAX_MILITARY 24

/// The least number of AI DECISIONS between two military buildings.
///
/// This used to be a const_tick interval, and at speed it silently stopped
/// working: the thinking interval scales with the speed but the per-player
/// stagger (index * 37) does not, so at 80x a decision came every 42 ticks
/// while the expansion interval had shrunk to 15. The clock was therefore
/// always already expired and the AI placed a hut on EVERY decision - the
/// seven in a row at the end of a mission-1 run, most of them never
/// garrisoned. Counting decisions instead is speed-proof by construction.
///
/// Expansion is the fallback branch: ai_build_economy returns false both when
/// the plan is complete AND when it is merely blocked - no site for the next
/// mine, not enough planks yet, a placement refused. Blocked is the common
/// case, so without a pace of its own every decision from then on put up
/// another hut, and the AI ran to AI_MAX_MILITARY in a burst while its
/// industry stood still. That is the ring of knight huts on screen.
///
#macro AI_EXPAND_DECISIONS 3

/// The count used instead when the economy is behind its plan. Expansion is
/// slowed, never stopped - see ai_expand_wait.
#macro AI_EXPAND_SLOW_DECISIONS 12

/// Military buildings allowed to be standing empty - built, finished, and
/// still short of knights - before expansion pauses.
///
/// A hut only helps if somebody is in it. The AI was building to the cap
/// regardless of whether it had knights to fill them, which is what makes a
/// row of empty huts on the border: they claim no ground they can hold and
/// the weapons that would have manned them went into buildings nobody
/// reached either. Waiting until the ones already up are manned ties
/// expansion to the actual output of the weapon smith, which is what limits
/// it in the original.
#macro AI_EXPAND_UNMANNED 2

/// Military buildings allowed per civilian one, once past the opening few.
/// The original's opponents grew their economy and their border together;
/// this keeps the ratio honest without freezing expansion early, when there
/// is nothing built yet and the castle has to push out to find room.
///
/// The ratio SLOWS expansion; it does not stop it. As a veto it deadlocked a
/// player whose plan contained something its ground could not support - no
/// mountain inside the border for a coal mine, say. The plan then stayed
/// incomplete for ever, so the ratio applied for ever, and the AI could
/// neither finish the economy nor expand to find the ground that would let
/// it: it stalled at around a dozen military buildings and stopped, which is
/// the enemy that quietly gives up partway through a mission.
///
/// The pace limiter is AI_EXPAND_DECISIONS, which is what actually prevents
/// the burst of huts this was first written for. The ratio now only chooses
/// between the normal interval and the slow one, so an AI that is behind on
/// industry keeps growing, just more slowly - and growing is how it reaches
/// the resources it was missing.
#macro AI_EXPAND_FREE 3
#macro AI_CIVILIAN_PER_MILITARY 2

/// How far around a candidate site to count trees, stone and minerals when
/// deciding whether it is worth putting a woodcutter or a mine there.
#macro AI_RESOURCE_SCAN 37

/// A site with less than this nearby is not worth building on for the trades
/// that need a resource under them.
#macro AI_MIN_RESOURCE 4

/// How many entries of the build plan to try in one decision before giving
/// up for this round. The plan is an order of PREFERENCE, not a queue: an
/// entry that cannot be built yet - no trees left in reach for the second
/// lumberjack, no mountain inside the border for a coal mine - used to stop
/// everything behind it, so an AI whose territory lacked one resource built
/// its first woodcutter and then nothing else at all, for the rest of the
/// game. Each decision now walks down the plan until something is placeable.
#macro AI_PLAN_TRIES 6

/// How many nearby flags to try joining a new one to before giving up for
/// now. One was not enough: the nearest flag can be unreachable - water or a
/// cliff between them, another flag sitting where the road would have to
/// pass - and the AI then left the building standing with no road at all,
/// which is why unconnected buildings appear on the map. The second-nearest
/// flag is usually a perfectly good join.
#macro AI_CONNECT_TRIES 5

/// After the first report that an AI decision did nothing, say so again only
/// every this many further decisions.
#macro AI_STUCK_REPEAT 25

/// A candidate this far from the target or worse is not worth the walk.
#macro AI_SCORE_REJECT 999999

/// Positions sampled when looking for a castle site. Every mission preset in
/// the table passes -1, -1 for the castle position, so GameInfo.instantiate
/// never calls build_castle for anyone - the human places theirs by hand and
/// the AI has to choose its own or it never appears on the map at all.
#macro AI_CASTLE_SAMPLES 2048

/// Keep an AI castle at least this far from one already placed, so opponents
/// do not spawn on top of each other or of the player.
#macro AI_CASTLE_MIN_SPACING 12


/// The order an AI settlement is built in, and how many of each. Planks come
/// first because everything else needs them, then stone, then food to keep
/// miners working, then the ore chain that ends in weapons.
function ai_init_tables() {
    if (variable_global_exists("ai_build_plan")) {
        return;
    }

    /* `needs` is a building type that must already exist - standing or under
       construction - before this entry is worth anything.

       Without it the plan is only an ORDER, and order is not enough once an
       entry can be skipped for want of a site: the AI put up a third
       woodcutter while it still had no sawmill, so the logs piled up at the
       flags with nothing able to turn them into planks. Same shape further
       down the chain - a steel smelter with no iron mine, a baker with no
       mill - each one a building whose input nothing produces.

       BuildingType.none means no prerequisite. The FIRST woodcutter has
       none, deliberately: wood comes before the sawmill that cuts it. */
    global.ai_build_plan = [
        { type: BuildingType.lumberjack,    want: 2, needs: BuildingType.none },
        { type: BuildingType.sawmill,       want: 1, needs: BuildingType.lumberjack },
        { type: BuildingType.forester,      want: 2, needs: BuildingType.lumberjack },
        { type: BuildingType.stonecutter,   want: 1, needs: BuildingType.none },
        { type: BuildingType.lumberjack,    want: 3, needs: BuildingType.sawmill },
        { type: BuildingType.sawmill,       want: 2, needs: BuildingType.lumberjack },
        { type: BuildingType.farm,          want: 2, needs: BuildingType.none },
        { type: BuildingType.mill,          want: 1, needs: BuildingType.farm },
        { type: BuildingType.baker,         want: 1, needs: BuildingType.mill },
        { type: BuildingType.coal_mine,     want: 2, needs: BuildingType.baker },
        { type: BuildingType.iron_mine,     want: 1, needs: BuildingType.baker },
        { type: BuildingType.steel_smelter, want: 1, needs: BuildingType.iron_mine },
        { type: BuildingType.tool_maker,    want: 1, needs: BuildingType.sawmill },
        { type: BuildingType.weapon_smith,  want: 1, needs: BuildingType.steel_smelter },
        { type: BuildingType.farm,          want: 4, needs: BuildingType.mill },
        { type: BuildingType.coal_mine,     want: 3, needs: BuildingType.steel_smelter },
        { type: BuildingType.gold_mine,     want: 1, needs: BuildingType.baker },
        { type: BuildingType.gold_smelter,  want: 1, needs: BuildingType.gold_mine },
    ];
}


/// Called from Game.update, where Freeserf's disabled AI block sat.
/// How long to wait before this player thinks again, in const_ticks.
///
/// const_tick counts simulation ticks and never changes with the speed
/// setting, while the world runs on `tick`, which advances by game_speed. So
/// the AI used to think a fixed number of times per tick while everything it
/// reasons about moved up to 25 times faster between one decision and the
/// next - it placed a building and only connected it a world-age later, and
/// its expansion branch fired against a stock that had refilled many times
/// over. Disconnected roads and a rash of knight huts are what that looks
/// like on screen.
///
/// Dividing the interval by the speed multiple puts the AI back on game
/// time, so fast-forward compresses time rather than changing how the
/// enemies play. At DEFAULT_GAME_SPEED the division is by 1 and the result
/// is exactly AI_UPDATE_INTERVAL - normal play is byte-identical to before,
/// which is the point: the missions are balanced around the original's pace.
///
/// A paused game (game_speed 0) keeps the normal interval; nothing is
/// updating anyway.
function ai_update_interval(_game) {
    return ai_scaled_interval(_game, AI_UPDATE_INTERVAL);
}

/// The same scaling for any AI interval measured in const_ticks.
function ai_scaled_interval(_game, _interval) {
    var _speed = _game.game_speed;
    if (_speed <= DEFAULT_GAME_SPEED) {
        return _interval;
    }
    return max(1, floor(_interval * DEFAULT_GAME_SPEED / _speed));
}

function ai_update_players(_game) {
    var _players = _game.players.objects;
    var _n = array_length(_players);

    for (var _i = 0; _i < _n; _i++) {
        var _player = _players[_i];
        if (_player == undefined) {
            continue;
        }
        if (!_player.is_ai()) {
            continue;
        }
        if (_game.const_tick < _player.ai_next_tick) {
            continue;
        }

        // Stagger the players so they do not all think on the same tick.
        _player.ai_next_tick = _game.const_tick + ai_update_interval(_game) +
                               _player.get_index() * 37;

        // A building with no road is worth less than no building at all, so
        // reconnecting one comes before putting up another.
        if (ai_repair_roads(_game, _player)) {
            continue;
        }

        // Economy first: a settlement that cannot make planks cannot expand
        // anyway. Only push the border when there is nothing to build.
        if (!ai_build_economy(_game, _player)) {
            if (!ai_expand(_game, _player)) {
                ai_report_stuck(_game, _player);
            }
        }
    }
}


/// Say why a decision did nothing at all.
///
/// Three unrelated gates produce the same symptom - an AI that builds four
/// things and then stops - and from the outside they are indistinguishable:
/// the plan may have nothing it can site, the hut search may find nowhere
/// legal, or expansion may simply be waiting out its interval. Rather than
/// guess, the AI now states the case the first time it happens and then
/// every AI_STUCK_REPEAT decisions, so a long game does not fill the log.
///
/// Reported per player: what the plan wants next and how many of the wanted
/// types had nowhere to go, the military count against the cap, whether a
/// hut site exists at all, and how long until expansion is allowed again.
function ai_report_stuck(_game, _player) {
    _player.ai_stuck_count += 1;
    if (_player.ai_stuck_count != 1 &&
        (_player.ai_stuck_count mod AI_STUCK_REPEAT) != 0) {
        return;
    }

    var _wanted = ai_wanted_building_types(_game, _player);
    var _wanted_n = array_length(_wanted);
    var _first = -1;
    if (_wanted_n > 0) {
        _first = _wanted[0];
    }

    var _military = array_length(ai_military_buildings(_game, _player));
    var _civilian = ai_civilian_count(_game, _player);
    var _orphans = array_length(ai_orphan_flags(_game, _player));

    var _home = ai_home_position(_game, _player);
    var _hut_site = BAD_MAP_POS;
    if (_home != BAD_MAP_POS) {
        _hut_site = ai_find_hut_site(_game, _player,
                                     ai_enemy_target(_game, _player), _home);
    }
    var _hut_text = "none in reach";
    if (_hut_site != BAD_MAP_POS) {
        _hut_text = string(_hut_site);
    }

    var _wait = ai_expand_wait(_game, _player) - _player.ai_decisions_since_expand;
    if (_wait < 0) {
        _wait = 0;
    }

    var _unmanned = ai_unmanned_count(_game, _player);

    show_debug_message("ai: player " + string(_player.get_index()) +
                       " did nothing (" + string(_player.ai_stuck_count) +
                       " in a row)" +
                       " - wants " + string(_wanted_n) + " types, first=" +
                       string(_first) +
                       "; civilian=" + string(_civilian) +
                       " military=" + string(_military) + "/" +
                       string(AI_MAX_MILITARY) +
                       "; hut site " + _hut_text +
                       "; expand in " + string(_wait) + " decisions" +
                       "; unmanned " + string(_unmanned) +
                       "; orphan flags " + string(_orphans));
}


/// Every military building this player owns, castle included. These are both
/// the places worth expanding from and the things we count against the cap.
function ai_military_buildings(_game, _player) {
    var _out = [];
    var _buildings = _game.buildings.objects;
    var _n = array_length(_buildings);

    for (var _i = 0; _i < _n; _i++) {
        var _building = _buildings[_i];
        if (_building == undefined) {
            continue;
        }
        if (_building.get_owner() != _player.get_index()) {
            continue;
        }
        if (_building.is_military()) {
            array_push(_out, _building);
        }
    }

    return _out;
}


/// Somewhere to expand towards: the nearest rival castle. Without one (single
/// player, or the rival has not built yet) there is no sensible direction, so
/// the caller falls back to expanding evenly outwards.
function ai_enemy_target(_game, _player) {
    var _buildings = _game.buildings.objects;
    var _n = array_length(_buildings);
    var _best = BAD_MAP_POS;
    var _best_dist = AI_SCORE_REJECT;

    var _home = ai_home_position(_game, _player);
    if (_home == BAD_MAP_POS) {
        return BAD_MAP_POS;
    }

    var _map = _game.get_map();

    for (var _i = 0; _i < _n; _i++) {
        var _building = _buildings[_i];
        if (_building == undefined) {
            continue;
        }
        if (_building.get_owner() == _player.get_index()) {
            continue;
        }
        if (_building.get_type() != BuildingType.castle) {
            continue;
        }

        var _pos = _building.get_position();
        var _dist = abs(_map.dist_x(_home, _pos)) + abs(_map.dist_y(_home, _pos));
        if (_dist < _best_dist) {
            _best_dist = _dist;
            _best = _pos;
        }
    }

    return _best;
}


/// The castle, or failing that the first military building we own.
function ai_home_position(_game, _player) {
    var _buildings = ai_military_buildings(_game, _player);
    var _n = array_length(_buildings);

    for (var _i = 0; _i < _n; _i++) {
        if (_buildings[_i].get_type() == BuildingType.castle) {
            return _buildings[_i].get_position();
        }
    }

    if (_n > 0) {
        return _buildings[0].get_position();
    }

    return BAD_MAP_POS;
}


/// Lower is better. Prefers ground that moves towards the enemy, and without an
/// enemy prefers ground furthest from home, which spreads the border outwards.
function ai_score_position(_game, _player, _pos, _target, _home) {
    var _map = _game.get_map();

    if (_target != BAD_MAP_POS) {
        return abs(_map.dist_x(_pos, _target)) + abs(_map.dist_y(_pos, _target));
    }

    return -(abs(_map.dist_x(_pos, _home)) + abs(_map.dist_y(_pos, _home)));
}


/// Look around each military building we own for the best legal hut site.
function ai_find_hut_site(_game, _player, _target, _home) {
    var _map = _game.get_map();
    var _sources = ai_military_buildings(_game, _player);
    var _source_count = array_length(_sources);

    var _best = BAD_MAP_POS;
    var _best_score = AI_SCORE_REJECT;

    for (var _s = 0; _s < _source_count; _s++) {
        var _origin = _sources[_s].get_position();

        for (var _i = 1; _i < AI_HUT_SCAN_POSITIONS; _i++) {
            var _pos = _map.pos_add_spirally(_origin, _i);

            // Must be ground we already hold, or the hut cannot be placed.
            if (_map.get_owner(_pos) != _player.get_index()) {
                continue;
            }
            if (!_game.can_build_military(_pos)) {
                continue;
            }
            if (!_game.can_build_building(_pos, BuildingType.hut, _player)) {
                continue;
            }

            var _score = ai_score_position(_game, _player, _pos, _target, _home);
            if (_score < _best_score) {
                _best_score = _score;
                _best = _pos;
            }
        }
    }

    return _best;
}


/// The closest flag this player owns, to connect a new building back to.
function ai_nearest_flag(_game, _player, _pos) {
    var _map = _game.get_map();
    var _flags = _game.flags.objects;
    var _n = array_length(_flags);

    var _best = BAD_MAP_POS;
    var _best_dist = AI_SCORE_REJECT;

    for (var _i = 0; _i < _n; _i++) {
        var _flag = _flags[_i];
        if (_flag == undefined) {
            continue;
        }
        if (_flag.get_owner() != _player.get_index()) {
            continue;
        }

        var _flag_pos = _flag.get_position();
        if (_flag_pos == _pos) {
            continue;
        }

        var _dist = abs(_map.dist_x(_pos, _flag_pos)) + abs(_map.dist_y(_pos, _flag_pos));
        if (_dist < _best_dist) {
            _best_dist = _dist;
            _best = _flag_pos;
        }
    }

    return _best;
}


/// Every flag of this player's that can be reached from one of its castles
/// or stocks by following roads. Returned as a struct of flag index -> true.
///
/// "Connected" has to mean connected TO THE NETWORK, not merely having a
/// road. ai_connect_flag joined each new flag to the nearest owned flag, and
/// the nearest owned flag is quite often another new one that is not itself
/// connected to anything - so two orphans join each other and form an island
/// of road serving nobody. Worse, both then report land_paths() != 0, so the
/// repair pass stopped seeing them and the island stayed on the map for the
/// rest of the game. Those are the stray roads.
///
/// A breadth-first walk from the inventory flags answers it properly, and
/// costs one pass over a few dozen flags. Returned as an array of bools
/// indexed by flag index, sized up front and read with ai_flag_on_network.
function ai_network_flags(_game, _player) {
    var _flags = _game.flags.objects;
    var _n = array_length(_flags);

    var _seen = array_create(_n + 1, false);
    var _queue = [];

    for (var _i = 0; _i < _n; _i++) {
        var _flag = _flags[_i];
        if (_flag == undefined) {
            continue;
        }
        if (_flag.get_owner() != _player.get_index()) {
            continue;
        }
        if (!_flag.has_inventory()) {
            continue;
        }
        var _root = _flag.get_index();
        if (_root <= _n) {
            _seen[_root] = true;
        }
        array_push(_queue, _flag);
    }

    var _head = 0;
    while (_head < array_length(_queue)) {
        var _at = _queue[_head];
        _head += 1;

        for (var _d = 0; _d < 6; _d++) {
            if (!_at.has_path(_d)) {
                continue;
            }
            if (_at.is_water_path(_d)) {
                continue;   // a carrier cannot walk a water path
            }
            /* get_other_end_flag hands back the Flag ITSELF, not its index -
               everywhere else in the port calls methods straight on it. Asking
               for its index is what the array is keyed by. Comparing the
               struct against a number does not throw in GML, it just answers
               false, so a guard written against the wrong type let a struct
               reference through as a subscript:

                   Variable Index [174334336] out of range [8]
                   in ai_network_flags, 21/09/2026 (crash report) */
            var _next = _at.get_other_end_flag(_d);
            if (_next == undefined) {
                continue;
            }
            var _next_index = _next.get_index();
            if (_next_index <= 0 || _next_index > _n) {
                continue;
            }
            if (_seen[_next_index]) {
                continue;
            }
            _seen[_next_index] = true;
            array_push(_queue, _next);
        }
    }

    return _seen;
}


/// Read a network array built above. Out-of-range answers false, which is
/// the safe way round: an unknown flag is treated as not connected, so the
/// repair pass looks at it rather than skipping it.
function ai_flag_on_network(_network, _index) {
    if (_index < 0 || _index >= array_length(_network)) {
        return false;
    }
    return _network[_index];
}


/// The closest flags to a position that are ON the network, nearest first,
/// up to _max of them.
/// Selection rather than a sort: _max is small and this avoids allocating a
/// comparator per call.
function ai_nearest_flags(_game, _player, _pos, _max) {
    var _map = _game.get_map();
    var _flags = _game.flags.objects;
    var _n = array_length(_flags);
    var _network = ai_network_flags(_game, _player);

    var _cand = [];
    var _dists = [];
    for (var _i = 0; _i < _n; _i++) {
        var _flag = _flags[_i];
        if (_flag == undefined) {
            continue;
        }
        if (_flag.get_owner() != _player.get_index()) {
            continue;
        }
        if (!ai_flag_on_network(_network, _flag.get_index())) {
            continue;   // joining this would only grow an island
        }
        var _flag_pos = _flag.get_position();
        if (_flag_pos == _pos) {
            continue;
        }
        array_push(_cand, _flag_pos);
        array_push(_dists, abs(_map.dist_x(_pos, _flag_pos)) +
                           abs(_map.dist_y(_pos, _flag_pos)));
    }

    var _out = [];
    var _count = array_length(_cand);
    for (var _k = 0; _k < _max; _k++) {
        var _best = -1;
        var _best_dist = AI_SCORE_REJECT;
        for (var _j = 0; _j < _count; _j++) {
            if (_dists[_j] < _best_dist) {
                _best_dist = _dists[_j];
                _best = _j;
            }
        }
        if (_best < 0) {
            break;
        }
        array_push(_out, _cand[_best]);
        _dists[_best] = AI_SCORE_REJECT;   // taken
    }

    return _out;
}


/// Join a flag to the existing network. Returns true on success.
function ai_connect_flag(_game, _player, _flag_pos) {
    var _map = _game.get_map();
    var _targets = ai_nearest_flags(_game, _player, _flag_pos, AI_CONNECT_TRIES);
    var _n = array_length(_targets);

    for (var _i = 0; _i < _n; _i++) {
        var _road = pathfinder_map(_map, _flag_pos, _targets[_i], undefined);
        if (_road.get_length() == 0) {
            continue;
        }
        if (_game.build_road(_road, _player)) {
            return true;
        }
    }

    return false;
}


/// Every flag of this player's that cannot be reached from a castle or
/// stock. A building whose flag is in this list is standing idle: no carrier
/// can reach it, so it is never staffed and never delivers. They arise
/// whenever a road could not be built at the moment the building went up -
/// the ground was not ours yet, the only neighbour was across water - and
/// nothing used to go back for them.
///
/// Flags on an ISLAND of road are in here too, which the old "no path at
/// all" test missed entirely; a joined pair of orphans looked connected to
/// it and was left alone for good.
function ai_orphan_flags(_game, _player) {
    var _flags = _game.flags.objects;
    var _n = array_length(_flags);
    var _network = ai_network_flags(_game, _player);
    var _out = [];

    for (var _i = 0; _i < _n; _i++) {
        var _flag = _flags[_i];
        if (_flag == undefined) {
            continue;
        }
        if (_flag.get_owner() != _player.get_index()) {
            continue;
        }
        if (_flag.has_inventory()) {
            continue;   // the castle's own flag is the network's root
        }
        if (ai_flag_on_network(_network, _flag.get_index())) {
            continue;
        }
        array_push(_out, _flag.get_position());
    }

    return _out;
}


/// Try to rescue one orphaned flag. Runs before anything else the AI does,
/// because a building already standing and doing nothing is worth more than
/// a new one, and territory won since it was built often makes the road
/// possible now. One per decision keeps the cost flat.
function ai_repair_roads(_game, _player) {
    var _orphans = ai_orphan_flags(_game, _player);
    var _n = array_length(_orphans);

    for (var _i = 0; _i < _n; _i++) {
        if (ai_connect_flag(_game, _player, _orphans[_i])) {
            show_debug_message("ai: player " + string(_player.get_index()) +
                               " connected an orphaned flag at " +
                               string(_orphans[_i]));
            return true;
        }
    }

    return false;
}


/// Has any human player put a castle down yet?
function ai_human_has_castle(_game) {
    var _players = _game.players.objects;
    var _n = array_length(_players);
    var _human_exists = false;

    for (var _i = 0; _i < _n; _i++) {
        var _player = _players[_i];
        if (_player == undefined) {
            continue;
        }
        if (_player.is_ai()) {
            continue;
        }
        _human_exists = true;
        if (_player.has_castle()) {
            return true;
        }
    }

    // All-AI game: nobody is waiting on anybody.
    return !_human_exists;
}


/// Distance from _pos to the closest castle already on the map, or a large
/// number when there are none.
function ai_castle_clearance(_game, _pos) {
    var _map = _game.get_map();
    var _buildings = _game.buildings.objects;
    var _n = array_length(_buildings);
    var _best = AI_SCORE_REJECT;

    for (var _i = 0; _i < _n; _i++) {
        var _building = _buildings[_i];
        if (_building == undefined) {
            continue;
        }
        if (_building.get_type() != BuildingType.castle) {
            continue;
        }

        var _other = _building.get_position();
        var _dist = abs(_map.dist_x(_pos, _other)) + abs(_map.dist_y(_pos, _other));
        if (_dist < _best) {
            _best = _dist;
        }
    }

    return _best;
}


/// Pick a castle site and build it. Sampling the map rather than walking every
/// tile: a good enough spot found quickly beats the best spot found slowly, and
/// this only runs until the castle exists.
function ai_place_castle(_game, _player) {
    var _map = _game.get_map();
    var _tile_count = _map.geom.tile_count;

    var _step = max(1, _tile_count div AI_CASTLE_SAMPLES);
    var _best = BAD_MAP_POS;
    var _best_clearance = -1;

    for (var _pos = 0; _pos < _tile_count; _pos += _step) {
        if (!_game.can_build_castle(_pos, _player)) {
            continue;
        }

        var _clearance = ai_castle_clearance(_game, _pos);
        if (_clearance < AI_CASTLE_MIN_SPACING) {
            continue;
        }
        if (_clearance > _best_clearance) {
            _best_clearance = _clearance;
            _best = _pos;
        }
    }

    if (_best == BAD_MAP_POS) {
        show_debug_message("ai: player " + string(_player.get_index()) +
                           " found nowhere to put a castle");
        return false;
    }

    if (!_game.build_castle(_best, _player)) {
        return false;
    }

    show_debug_message("ai: player " + string(_player.get_index()) +
                       " built its castle at " + string(_best));
    return true;
}


/// How many finished-or-building of a type this player has.
function ai_building_count(_game, _player, _type) {
    var _buildings = _game.buildings.objects;
    var _n = array_length(_buildings);
    var _count = 0;

    for (var _i = 0; _i < _n; _i++) {
        var _building = _buildings[_i];
        if (_building == undefined) {
            continue;
        }
        if (_building.get_owner() != _player.get_index()) {
            continue;
        }
        if (_building.get_type() == _type) {
            _count += 1;
        }
    }

    return _count;
}


/// The next thing the plan says is missing, or none when it is all built.
function ai_next_building_type(_game, _player) {
    var _wanted = ai_wanted_building_types(_game, _player);
    if (array_length(_wanted) == 0) {
        return BuildingType.none;
    }
    return _wanted[0];
}


/// Every building type the plan still wants, in plan order and without
/// repeats. The caller tries them in turn, so a type that cannot be sited
/// costs one decision's search rather than the rest of the game.
function ai_wanted_building_types(_game, _player) {
    ai_init_tables();

    var _plan = global.ai_build_plan;
    var _n = array_length(_plan);

    // One snapshot of counts per decision, including construction exactly
    // as ai_building_count does. No persistent state or cache invalidation.
    var _counts = array_create(32, 0);
    var _buildings = _game.buildings.objects;
    for (var _b = 0; _b < array_length(_buildings); _b++) {
        var _building = _buildings[_b];
        if (_building != undefined && _building.get_owner() == _player.get_index()) {
            _counts[_building.get_type()] += 1;
        }
    }

    // What the plan asks for, minus what is already standing or going up.
    // A type appears once however many plan entries mention it, because the
    // count is compared against the largest want for that type either way.
    var _out = [];
    var _added = array_create(32, false);
    for (var _i = 0; _i < _n; _i++) {
        var _entry = _plan[_i];
        if (_added[_entry.type]) {
            continue;
        }
        if (_counts[_entry.type] >= _entry.want) {
            continue;
        }
        /* Nothing produces this one's input yet. Skipped WITHOUT marking the
           type as added, so a later entry for the same type - with a
           prerequisite that is met - can still offer it. */
        if (_entry.needs != BuildingType.none && _counts[_entry.needs] <= 0) {
            continue;
        }
        _added[_entry.type] = true;
        array_push(_out, _entry.type);
    }

    return _out;
}


/// Trees near a position, for siting a woodcutter.
function ai_count_trees(_game, _pos) {
    var _map = _game.get_map();
    var _count = 0;

    for (var _i = 0; _i < AI_RESOURCE_SCAN; _i++) {
        var _obj = _map.get_obj(_map.pos_add_spirally(_pos, _i));
        if (_obj >= MapObject.tree0 && _obj <= MapObject.water_tree3) {
            _count += 1;
        }
    }

    return _count;
}


/// Stone near a position, for siting a quarry.
function ai_count_stone(_game, _pos) {
    var _map = _game.get_map();
    var _count = 0;

    for (var _i = 0; _i < AI_RESOURCE_SCAN; _i++) {
        var _obj = _map.get_obj(_map.pos_add_spirally(_pos, _i));
        if (_obj >= MapObject.stone0 && _obj <= MapObject.stone7) {
            _count += 1;
        }
    }

    return _count;
}


/// Buried mineral of one kind near a position, for siting a mine.
function ai_count_mineral(_game, _pos, _mineral) {
    var _map = _game.get_map();
    var _total = 0;

    for (var _i = 0; _i < AI_RESOURCE_SCAN; _i++) {
        var _p = _map.pos_add_spirally(_pos, _i);
        if (_map.get_res_type(_p) == _mineral) {
            _total += _map.get_res_amount(_p);
        }
    }

    return _total;
}


/// What a given trade actually cares about being near. Higher is better, and
/// a return of 0 means "do not build here at all".
function ai_site_value(_game, _player, _pos, _type) {
    switch (_type) {
        case BuildingType.lumberjack: {
            // A thin wood still beats no wood at all. AI_MIN_RESOURCE used to
            // REJECT anything below it, and because the plan is tried in
            // order and skipped when it cannot be sited, an opening position
            // with no dense stand meant the lumberjack was passed over
            // entirely - the AI built a sawmill, two foresters, a stonecutter
            // and two farms before its first woodcutter, and ran out of
            // planks. The threshold now only decides the SCORE, so a dense
            // stand still wins wherever one exists.
            var _trees = ai_count_trees(_game, _pos);
            if (_trees <= 0) {
                return 0;
            }
            if (_trees < AI_MIN_RESOURCE) {
                return 1;
            }
            return _trees;
        }
        case BuildingType.forester: {
            // Wants room to plant, so the opposite: open ground.
            return AI_RESOURCE_SCAN - ai_count_trees(_game, _pos);
        }
        case BuildingType.stonecutter: {
            var _stone = ai_count_stone(_game, _pos);
            if (_stone < 1) {
                return 0;
            }
            return _stone;
        }
        case BuildingType.coal_mine:
            return ai_count_mineral(_game, _pos, Minerals.coal);
        case BuildingType.iron_mine:
            return ai_count_mineral(_game, _pos, Minerals.iron);
        case BuildingType.gold_mine:
            return ai_count_mineral(_game, _pos, Minerals.gold);
        case BuildingType.stone_mine:
            return ai_count_mineral(_game, _pos, Minerals.stone);
        case BuildingType.farm:
            // Fields need open flat ground, same test as the forester.
            return AI_RESOURCE_SCAN - ai_count_trees(_game, _pos);
        default:
            // Workshops just need to be somewhere legal and connected.
            return 1;
    }
}


/// Best legal site for a given building inside our own territory.
function ai_find_site(_game, _player, _type) {
    var _map = _game.get_map();
    var _sources = ai_military_buildings(_game, _player);
    var _source_count = array_length(_sources);

    var _best = BAD_MAP_POS;
    var _best_value = 0;

    for (var _s = 0; _s < _source_count; _s++) {
        var _origin = _sources[_s].get_position();

        for (var _i = 1; _i < AI_SCAN_POSITIONS; _i++) {
            var _pos = _map.pos_add_spirally(_origin, _i);

            if (_map.get_owner(_pos) != _player.get_index()) {
                continue;
            }
            if (!_game.can_build_building(_pos, _type, _player)) {
                continue;
            }

            var _value = ai_site_value(_game, _player, _pos, _type);
            if (_value > _best_value) {
                _best_value = _value;
                _best = _pos;
            }
        }
    }

    return _best;
}


/// Place a building and join it to the road network. Shared by the economy and
/// the military expansion, because a building with no road is never staffed.
function ai_place_building(_game, _player, _pos, _type) {
    var _map = _game.get_map();

    if (!_game.build_building(_pos, _type, _player)) {
        return false;
    }

    var _flag_pos = _map.move_down_right(_pos);
    if (!_map.has_flag(_flag_pos)) {
        _game.build_flag(_flag_pos, _player);
    }

    if (!ai_connect_flag(_game, _player, _flag_pos)) {
        /* The building stays: demolishing it would waste what it cost, and
           ai_repair_roads goes back for the flag on a later decision, by
           which time the border has usually moved. */
        show_debug_message("ai: player " + string(_player.get_index()) +
                           " could not connect " + string(_flag_pos) +
                           " yet - left for the road repair pass");
    }
    return true;
}


/// One economy step: build whatever the plan says is next. Returns true if it
/// managed to place something.
function ai_build_economy(_game, _player) {
    var _wanted = ai_wanted_building_types(_game, _player);
    var _n = array_length(_wanted);
    if (_n > AI_PLAN_TRIES) {
        _n = AI_PLAN_TRIES;
    }

    for (var _i = 0; _i < _n; _i++) {
        var _type = _wanted[_i];

        var _pos = ai_find_site(_game, _player, _type);
        if (_pos == BAD_MAP_POS) {
            continue;   // nowhere for this one yet; the next entry may fit
        }

        if (!ai_place_building(_game, _player, _pos, _type)) {
            continue;
        }

        _player.ai_stuck_count = 0;

        show_debug_message("ai: player " + string(_player.get_index()) +
                           " built type " + string(_type) + " at " + string(_pos));
        return true;
    }

    // Nothing in the plan could be placed. Either it is finished or the
    // territory is too tight for what is left, and both are answered the
    // same way: let the caller push the border out.
    return false;
}


/// Civilian buildings this player owns, construction included. The castle is
/// military and is not counted here, which is what makes AI_EXPAND_FREE the
/// allowance a player starts with rather than a number it already meets.
function ai_civilian_count(_game, _player) {
    var _buildings = _game.buildings.objects;
    var _n = array_length(_buildings);
    var _count = 0;

    for (var _i = 0; _i < _n; _i++) {
        var _building = _buildings[_i];
        if (_building == undefined) {
            continue;
        }
        if (_building.get_owner() != _player.get_index()) {
            continue;
        }
        if (_building.is_military()) {
            continue;
        }
        _count += 1;
    }

    return _count;
}


/// Whether another military building is allowed at all. The hard cap is the
/// only veto; how fast they go up is ai_expand_wait's business.
function ai_may_expand(_game, _player) {
    var _military = array_length(ai_military_buildings(_game, _player));

    if (_military >= AI_MAX_MILITARY) {
        return false;
    }

    return true;
}


/// How long to wait after placing a military building before placing the
/// next. Normal pace while the economy keeps up with its plan; the slow one
/// while it is behind, so industry gets the output without expansion ever
/// coming to a halt. See AI_EXPAND_FREE.
function ai_expand_wait(_game, _player) {
    // Plan finished: nothing else to spend on, so grow at full pace.
    if (array_length(ai_wanted_building_types(_game, _player)) == 0) {
        return AI_EXPAND_DECISIONS;
    }

    var _military = array_length(ai_military_buildings(_game, _player));
    var _allowed = AI_EXPAND_FREE +
                   floor(ai_civilian_count(_game, _player) / AI_CIVILIAN_PER_MILITARY);
    if (_military >= _allowed) {
        return AI_EXPAND_SLOW_DECISIONS;
    }

    return AI_EXPAND_DECISIONS;
}


/// Military buildings of this player's that are not yet holding the border:
/// still being built, or finished with NOBODY INSIDE.
///
/// Both halves were wrong in the first version, and between them they let the
/// brake off almost always:
///
///  - Buildings under construction were skipped, on the grounds that they had
///    not asked for anybody yet. But that is exactly the window the AI builds
///    in: at three decisions per hut it can put up half a dozen before the
///    first one is finished, and none of them counted.
///  - It asked wants_another_knight(), which is (requested + available) <
///    needed - so a hut with a knight merely BOOKED reads as manned. A
///    booking that never arrives, because there is no knight to send or he
///    cannot get there, leaves the hut empty for good while still counting as
///    satisfied.
///
/// Counting what is actually in the building answers the question the
/// screenshot asks: is anyone in these huts? get_knight_count() is the
/// occupancy (stock 0 holds planks while building and knights afterwards),
/// so it is only meaningful once the building is done - which is why the
/// unfinished ones are counted separately above it rather than measured.
function ai_unmanned_count(_game, _player) {
    var _military = ai_military_buildings(_game, _player);
    var _n = array_length(_military);
    var _count = 0;

    for (var _i = 0; _i < _n; _i++) {
        var _building = _military[_i];
        if (_building.is_burning()) {
            continue;
        }
        if (_building.get_type() == BuildingType.castle) {
            continue;
        }
        if (!_building.is_done()) {
            _count += 1;   // still going up, and already spoken for
            continue;
        }
        if (_building.get_knight_count() <= 0) {
            _count += 1;   // finished and empty
        }
    }

    return _count;
}


/// One expansion step: place a hut and wire it up. Returns true if it built
/// something, so the caller can tell a decision that acted from one that
/// found every door closed.
function ai_expand(_game, _player) {
    var _map = _game.get_map();

    if (!_player.has_castle()) {
        // Let the human choose their spot first, then settle away from it.
        if (ai_human_has_castle(_game)) {
            return ai_place_castle(_game, _player);
        }
        return false;
    }

    var _home = ai_home_position(_game, _player);
    if (_home == BAD_MAP_POS) {
        return false;
    }

    // Its own pace and its own ratio against the economy. Both are here
    // rather than in the caller so the placement below is the only thing that
    // spends either of them: a decision that finds nowhere to build must not
    // use up the wait, or a player hemmed in on one side would stop
    // expanding altogether.
    _player.ai_decisions_since_expand += 1;
    if (_player.ai_decisions_since_expand < ai_expand_wait(_game, _player)) {
        return false;
    }

    if (!ai_may_expand(_game, _player)) {
        return false;
    }

    // Man what is already built before building more.
    if (ai_unmanned_count(_game, _player) > AI_EXPAND_UNMANNED) {
        return false;
    }

    var _target = ai_enemy_target(_game, _player);
    var _pos = ai_find_hut_site(_game, _player, _target, _home);
    if (_pos == BAD_MAP_POS) {
        return false;
    }

    if (!ai_place_building(_game, _player, _pos, BuildingType.hut)) {
        return false;
    }

    _player.ai_decisions_since_expand = 0;
    _player.ai_stuck_count = 0;

    show_debug_message("ai: player " + string(_player.get_index()) +
                       " placed a hut at " + string(_pos));

    return true;
}
