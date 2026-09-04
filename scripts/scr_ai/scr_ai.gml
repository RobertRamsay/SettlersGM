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

/// How far out from an existing military building to look for a hut site.
/// The spiral pattern holds 295 entries; 1 + 6 + 12 + 18 + 24 covers the first
/// four rings, which is roughly the radius a hut claims.
#macro AI_SCAN_POSITIONS 61

/// Never keep more huts than this in stage 1. Without an economy the AI would
/// otherwise spend the castle's whole stock of planks and stone on huts.
#macro AI_MAX_MILITARY 8

/// A candidate this far from the target or worse is not worth the walk.
#macro AI_SCORE_REJECT 999999


/// Called from Game.update, where Freeserf's disabled AI block sat.
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
        _player.ai_next_tick = _game.const_tick + AI_UPDATE_INTERVAL +
                               _player.get_index() * 37;

        ai_expand(_game, _player);
    }
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

        for (var _i = 1; _i < AI_SCAN_POSITIONS; _i++) {
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


/// Join a new building's flag to the existing network. Returns true on success.
function ai_connect_flag(_game, _player, _flag_pos) {
    var _map = _game.get_map();
    var _target = ai_nearest_flag(_game, _player, _flag_pos);

    if (_target == BAD_MAP_POS) {
        return false;
    }

    var _road = pathfinder_map(_map, _flag_pos, _target, undefined);
    if (_road.get_length() == 0) {
        return false;
    }

    return _game.build_road(_road, _player);
}


/// One expansion step: place a hut and wire it up.
function ai_expand(_game, _player) {
    var _map = _game.get_map();

    var _home = ai_home_position(_game, _player);
    if (_home == BAD_MAP_POS) {
        return;   // no castle yet, nothing to expand from
    }

    if (array_length(ai_military_buildings(_game, _player)) >= AI_MAX_MILITARY) {
        return;
    }

    var _target = ai_enemy_target(_game, _player);
    var _pos = ai_find_hut_site(_game, _player, _target, _home);
    if (_pos == BAD_MAP_POS) {
        return;
    }

    if (!_game.build_building(_pos, BuildingType.hut, _player)) {
        return;
    }

    // build_building does not place the building's flag, so do that and then
    // join it to the network. A hut with no road is never occupied.
    var _flag_pos = _map.move_down_right(_pos);
    if (!_map.has_flag(_flag_pos)) {
        _game.build_flag(_flag_pos, _player);
    }

    ai_connect_flag(_game, _player, _flag_pos);

    show_debug_message("ai: player " + string(_player.get_index()) +
                       " placed a hut at " + string(_pos));
}
