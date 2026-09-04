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

/// Cap on military buildings. Stage 1 held this at 8 because the AI could only
/// spend the castle's opening stock; with an economy behind it there is more
/// room, though it is still bounded so huts do not crowd out the industry.
#macro AI_MAX_MILITARY 24

/// How far around a candidate site to count trees, stone and minerals when
/// deciding whether it is worth putting a woodcutter or a mine there.
#macro AI_RESOURCE_SCAN 37

/// A site with less than this nearby is not worth building on for the trades
/// that need a resource under them.
#macro AI_MIN_RESOURCE 4

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

    global.ai_build_plan = [
        { type: BuildingType.lumberjack,    want: 2 },
        { type: BuildingType.sawmill,       want: 1 },
        { type: BuildingType.forester,      want: 2 },
        { type: BuildingType.stonecutter,   want: 1 },
        { type: BuildingType.lumberjack,    want: 3 },
        { type: BuildingType.sawmill,       want: 2 },
        { type: BuildingType.farm,          want: 2 },
        { type: BuildingType.mill,          want: 1 },
        { type: BuildingType.baker,         want: 1 },
        { type: BuildingType.coal_mine,     want: 2 },
        { type: BuildingType.iron_mine,     want: 1 },
        { type: BuildingType.steel_smelter, want: 1 },
        { type: BuildingType.tool_maker,    want: 1 },
        { type: BuildingType.weapon_smith,  want: 1 },
        { type: BuildingType.farm,          want: 4 },
        { type: BuildingType.coal_mine,     want: 3 },
        { type: BuildingType.gold_mine,     want: 1 },
        { type: BuildingType.gold_smelter,  want: 1 },
    ];
}


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

        // Economy first: a settlement that cannot make planks cannot expand
        // anyway. Only push the border when there is nothing to build.
        if (!ai_build_economy(_game, _player)) {
            ai_expand(_game, _player);
        }
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
    ai_init_tables();

    var _plan = global.ai_build_plan;
    var _n = array_length(_plan);

    for (var _i = 0; _i < _n; _i++) {
        var _entry = _plan[_i];
        if (ai_building_count(_game, _player, _entry.type) < _entry.want) {
            return _entry.type;
        }
    }

    return BuildingType.none;
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
            var _trees = ai_count_trees(_game, _pos);
            if (_trees < AI_MIN_RESOURCE) {
                return 0;
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

    ai_connect_flag(_game, _player, _flag_pos);
    return true;
}


/// One economy step: build whatever the plan says is next. Returns true if it
/// managed to place something.
function ai_build_economy(_game, _player) {
    var _type = ai_next_building_type(_game, _player);
    if (_type == BuildingType.none) {
        return false;
    }

    var _pos = ai_find_site(_game, _player, _type);
    if (_pos == BAD_MAP_POS) {
        return false;   // nowhere suitable yet; expansion may open somewhere up
    }

    if (!ai_place_building(_game, _player, _pos, _type)) {
        return false;
    }

    show_debug_message("ai: player " + string(_player.get_index()) +
                       " built type " + string(_type) + " at " + string(_pos));
    return true;
}


/// One expansion step: place a hut and wire it up.
function ai_expand(_game, _player) {
    var _map = _game.get_map();

    if (!_player.has_castle()) {
        // Let the human choose their spot first, then settle away from it.
        if (ai_human_has_castle(_game)) {
            ai_place_castle(_game, _player);
        }
        return;
    }

    var _home = ai_home_position(_game, _player);
    if (_home == BAD_MAP_POS) {
        return;
    }

    if (array_length(ai_military_buildings(_game, _player)) >= AI_MAX_MILITARY) {
        return;
    }

    var _target = ai_enemy_target(_game, _player);
    var _pos = ai_find_hut_site(_game, _player, _target, _home);
    if (_pos == BAD_MAP_POS) {
        return;
    }

    if (!ai_place_building(_game, _player, _pos, BuildingType.hut)) {
        return;
    }

    show_debug_message("ai: player " + string(_player.get_index()) +
                       " placed a hut at " + string(_pos));
}
