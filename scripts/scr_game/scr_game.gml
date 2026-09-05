// scr_game.gml - Port of Freeserf src/game.h / src/game.cc (GPL-3.0),
// original copyright (C) 2013-2017 Jon Lund Steffensen <jonlst@gmail.com>.
// Gameplay related functions: the Game state container that owns the map,
// the players, flags, inventories, buildings and serfs, and drives the
// per-tick update. Save/load (operator>>, operator<<, load_*) is skipped.
//
// Out-parameter conventions used in this file (see CONVENTIONS2.md):
//   can_build_road(road, player) -> { result, dest, water }
//       result: 0 = cannot, -1 = invalid segment, 1 = ok (C++ int return)
//   prepare_ground_analysis(pos, estimates) fills the 5-element array
//       `estimates` in place AND returns it.
//   remove_road_forwards uses map.remove_road_segment(pos, dir) -> {pos, dir}.
//   flag_fill_path_serf_info(game, pos, dir) (scr_flag.gml, static
//       Flag::fill_path_serf_info) returns a SerfPathInfo struct
//       { path_len, serf_count, flag_index, flag_dir, serfs }.
//   serf.path_splited(f1, d1, f2, d2) returns { result, select }.
//   FlagSearch callbacks are GML functions called as cb(flag, data).
//   A road is a struct { source, dirs } (dirs = array of Direction).

#macro DEFAULT_GAME_SPEED 2
// Freeserf src/freeserf.h: #define TICK_LENGTH 20 (ms) ->
// TICKS_PER_SEC = 1000/20 = 50 game updates per second.
#macro TICK_LENGTH_MS 20
#macro TICKS_PER_SEC 50
#macro GAME_MAX_PLAYER_COUNT 4
#macro GROUND_ANALYSIS_RADIUS 25

/// @function game_init_tables()
/// @desc Builds the static tables used by Game (update_inventories resource
///       orders and the land ownership influence/closeness tables) once.
function game_init_tables() {
    if (!variable_global_exists("game_update_inventories_arr_1")) {
        global.game_update_inventories_arr_1 = [
            ResourceType.plank,
            ResourceType.stone,
            ResourceType.steel,
            ResourceType.coal,
            ResourceType.lumber,
            ResourceType.iron_ore,
            ResourceType.group_food,
            ResourceType.pig,
            ResourceType.flour,
            ResourceType.wheat,
            ResourceType.gold_bar,
            ResourceType.gold_ore,
            ResourceType.none
        ];

        global.game_update_inventories_arr_2 = [
            ResourceType.stone,
            ResourceType.iron_ore,
            ResourceType.gold_ore,
            ResourceType.coal,
            ResourceType.steel,
            ResourceType.gold_bar,
            ResourceType.group_food,
            ResourceType.pig,
            ResourceType.flour,
            ResourceType.wheat,
            ResourceType.lumber,
            ResourceType.plank,
            ResourceType.none
        ];

        global.game_update_inventories_arr_3 = [
            ResourceType.group_food,
            ResourceType.wheat,
            ResourceType.pig,
            ResourceType.flour,
            ResourceType.gold_bar,
            ResourceType.stone,
            ResourceType.plank,
            ResourceType.steel,
            ResourceType.coal,
            ResourceType.lumber,
            ResourceType.gold_ore,
            ResourceType.iron_ore,
            ResourceType.none
        ];

        global.game_military_influence = [
            0, 1, 2, 4, 7, 12, 18, 29, -1, -1,   /* hut */
            0, 3, 5, 8, 11, 15, 22, 30, -1, -1,  /* tower */
            0, 6, 10, 14, 19, 23, 27, 31, -1, -1 /* fortress */
        ];

        global.game_map_closeness = [
            1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0,
            1, 2, 3, 3, 3, 3, 3, 3, 3, 2, 1, 0, 0, 0, 0, 0, 0,
            1, 2, 3, 4, 4, 4, 4, 4, 4, 3, 2, 1, 0, 0, 0, 0, 0,
            1, 2, 3, 4, 5, 5, 5, 5, 5, 4, 3, 2, 1, 0, 0, 0, 0,
            1, 2, 3, 4, 5, 6, 6, 6, 6, 5, 4, 3, 2, 1, 0, 0, 0,
            1, 2, 3, 4, 5, 6, 7, 7, 7, 6, 5, 4, 3, 2, 1, 0, 0,
            1, 2, 3, 4, 5, 6, 7, 8, 8, 7, 6, 5, 4, 3, 2, 1, 0,
            1, 2, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 1,
            0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 7, 6, 5, 4, 3, 2, 1,
            0, 0, 1, 2, 3, 4, 5, 6, 7, 7, 7, 6, 5, 4, 3, 2, 1,
            0, 0, 0, 1, 2, 3, 4, 5, 6, 6, 6, 6, 5, 4, 3, 2, 1,
            0, 0, 0, 0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 4, 3, 2, 1,
            0, 0, 0, 0, 0, 1, 2, 3, 4, 4, 4, 4, 4, 4, 3, 2, 1,
            0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 3, 3, 3, 2, 1,
            0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1,
            0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1
        ];
    }
}

/// @function Game()
/// @desc Port of class Game.
function Game() constructor {
    game_init_tables();

    map = undefined;

    map_gold_morale_factor = 0;
    gold_total = 0;

    players = new Collection(self, Player);
    flags = new Collection(self, Flag);
    inventories = new Collection(self, Inventory);
    buildings = new Collection(self, Building);
    serfs = new Collection(self, Serf);

    init_map_rnd = new RandomState(0, 0, 0);
    game_speed_save = 0;
    game_speed = DEFAULT_GAME_SPEED;
    tick = 0;
    last_tick = 0;
    const_tick = 0;
    game_stats_counter = 0;
    history_counter = 0;
    /* Random() default constructor: time-seeded, then one random() call. */
    rnd = new RandomState(irandom(0xFFFF), irandom(0xFFFF), irandom(0xFFFF));
    rnd.next_random();
    next_index = 0;
    flag_search_counter = 0;

    update_map_last_tick = 0;
    update_map_counter = 0;
    update_map_initial_pos = 0;
    tick_diff = 0;
    max_next_index = 0;
    update_map_16_loop = 0;
    player_history_index = array_create(4, 0);
    player_history_counter = array_create(3, 0);
    resource_history_index = 0;
    field_340 = 0;
    field_342 = 0;
    field_344 = undefined;
    game_type = 0;
    tutorial_level = 0;
    mission_level = 0;

    /* Win / loss. 0 = still playing, 1 = won, 2 = lost. The result is announced
       once through the notification system and play carries on, so this is only
       here to stop it being announced again every second. game_over_seen
       records which players have ever had anything, because at the start of a
       mission nobody has placed a castle yet and every player would otherwise
       read as already finished. */
    game_over = 0;
    game_over_counter = 0;
    game_over_seen = array_create(GAME_MAX_PLAYER_COUNT, false);
    /* Which mission this is, so a win can tick it off in the start screen's
       list. -1 for a custom game or a tutorial, which have nothing to tick.
       GameInitBox sets it when it starts a mission. It serialises with the rest
       of the Game, so finishing a mission resumed from a save still counts, and
       a save written before this field existed simply comes back as -1. */
    mission_index = -1;
    /* Set once the result has been put on screen, so the end box opens exactly
       once however long play carries on afterwards. */
    game_over_shown = false;
    /* Who the end box has to show: every opponent that was in the game, in
       player order. Captured when the game ends because players can be gone
       from the collection by the time anyone looks. */
    game_over_opponents = [];
    map_preserve_bugs = 0;
    player_score_leader = 0;

    knight_morale_counter = 0;
    inventory_schedule_counter = 0;

    /* Create NULL-serf */
    serfs.allocate();

    /* Create NULL-building (index 0 is undefined) */
    buildings.allocate();

    /* Create NULL-flag (index 0 is undefined) */
    flags.allocate();

    /* ---------------------------------------------------------------- */
    /* Simple accessors                                                  */
    /* ---------------------------------------------------------------- */

    static get_map = function() {
        return map;
    };

    static get_tick = function() {
        return tick;
    };

    static get_const_tick = function() {
        return const_tick;
    };

    static get_gold_morale_factor = function() {
        return map_gold_morale_factor;
    };

    static get_gold_total = function() {
        return gold_total;
    };

    static add_gold_total = function(_delta) {
        if (_delta < 0) {
            if (gold_total < -_delta) {
                throw ("Failed to decrease global gold counter.");
            }
        }
        gold_total += _delta;
    };

    static get_player_history_index = function(_scale) {
        return player_history_index[_scale];
    };

    static get_resource_history_index = function() {
        return resource_history_index;
    };

    static get_rnd = function() {
        return rnd;
    };

    static get_serf = function(_index) {
        return serfs.get(_index);
    };

    static get_flag = function(_index) {
        return flags.get(_index);
    };

    static get_inventory = function(_index) {
        return inventories.get(_index);
    };

    static get_building = function(_index) {
        return buildings.get(_index);
    };

    static get_player = function(_index) {
        return players.get(_index);
    };

    static get_building_at_pos = function(_pos) {
        var _map_obj = map.get_obj(_pos);
        if (_map_obj >= MapObject.small_building && _map_obj <= MapObject.castle) {
            return buildings.get(map.get_obj_index(_pos));
        }
        return undefined;
    };

    static get_flag_at_pos = function(_pos) {
        if (map.get_obj(_pos) != MapObject.flag) {
            return undefined;
        }

        return flags.get(map.get_obj_index(_pos));
    };

    static get_serf_at_pos = function(_pos) {
        var _index = map.get_serf_index(_pos);
        var _serf = serfs.get(_index);
        if (_serf == undefined && _index != 0) {
            /* The tile is pointing at a serf that no longer exists. Every known
               way of producing that is fixed, but callers all over the port -
               and the viewport's draw rows - go straight from has_serf() to
               this without a nil check, so heal the tile rather than hand back
               a hole that crashes the next reader. */
            show_debug_message("game: tile " + string(_pos) + " pointed at serf #" +
                               string(_index) + ", which is gone - cleared");
            map.set_serf_index(_pos, 0);
        }
        return _serf;
    };

    /* ---------------------------------------------------------------- */
    /* Update helpers                                                    */
    /* ---------------------------------------------------------------- */

    /* Clear the serf request bit of all flags and buildings.
       This allows the flag or building to try and request a
       serf again. */
    static clear_serf_request_failure = function() {
        for (var _i = 0; _i < array_length(buildings.objects); _i++) {
            var _building = buildings.objects[_i];
            if (_building != undefined) {
                _building.clear_serf_request_failure();
            }
        }

        for (var _i = 0; _i < array_length(flags.objects); _i++) {
            var _flag = flags.objects[_i];
            if (_flag != undefined) {
                _flag.serf_request_clear();
            }
        }
    };

    static update_knight_morale = function() {
        for (var _i = 0; _i < array_length(players.objects); _i++) {
            var _player = players.objects[_i];
            if (_player != undefined) {
                _player.update_knight_morale();
            }
        }
    };

    /* data: { resource, max_prio (array), flags (array) } */
    static update_inventories_cb = function(_flag, _data) {
        var _inv = _flag.get_search_dir();
        if (_data.max_prio[_inv] < 255 && _flag.has_building()) {
            var _building = _flag.get_building();

            var _bld_prio = _building.get_max_priority_for_resource(_data.resource, 16);
            if (_bld_prio > _data.max_prio[_inv]) {
                _data.max_prio[_inv] = _bld_prio;
                _data.flags[_inv] = _flag;
            }
        }

        return false;
    };

    /* Update inventories as part of the game progression. Moves the appropriate
       resources that are needed outside of the inventory into the out queue. */
    static update_inventories = function() {
        /* AI: TODO */

        var _arr = undefined;
        switch (random_int() & 7) {
            case 0: _arr = global.game_update_inventories_arr_2; break;
            case 1: _arr = global.game_update_inventories_arr_3; break;
            default: _arr = global.game_update_inventories_arr_1; break;
        }

        var _a = 0;
        while (_arr[_a] != ResourceType.none) {
            for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
                var _player = players.objects[_pi];
                if (_player == undefined) {
                    continue;
                }

                var _invs = array_create(256, undefined);
                var _n = 0;
                for (var _ii = 0; _ii < array_length(inventories.objects); _ii++) {
                    var _inventory = inventories.objects[_ii];
                    if (_inventory == undefined) {
                        continue;
                    }
                    if (_inventory.get_owner() == _player.get_index() &&
                        !_inventory.is_queue_full()) {
                        var _res_dir = _inventory.get_res_mode();
                        if (_res_dir == InventoryMode.mode_in || _res_dir == InventoryMode.mode_stop) {
                            if (_arr[_a] == ResourceType.group_food) {
                                if (_inventory.has_food()) {
                                    _invs[_n] = _inventory;
                                    _n += 1;
                                    if (_n == 256) {
                                        break;
                                    }
                                }
                            } else if (_inventory.get_count_of(_arr[_a]) != 0) {
                                _invs[_n] = _inventory;
                                _n += 1;
                                if (_n == 256) {
                                    break;
                                }
                            }
                        } else { /* Out mode */
                            var _prio = 0;
                            var _type = ResourceType.none;
                            for (var _i = 0; _i < 26; _i++) {
                                if (_inventory.get_count_of(_i) != 0 &&
                                    _player.get_inventory_prio(_i) >= _prio) {
                                    _prio = _player.get_inventory_prio(_i);
                                    _type = _i;
                                }
                            }

                            if (_type != ResourceType.none) {
                                _inventory.add_to_queue(_type, 0);
                            }
                        }
                    }
                }

                if (_n == 0) {
                    continue;
                }

                var _search = new FlagSearch(self);

                var _max_prio = array_create(256, 0);
                var _flags_ = array_create(256, undefined);

                for (var _i = 0; _i < _n; _i++) {
                    _max_prio[_i] = 0;
                    _flags_[_i] = undefined;
                    var _flag = flags.get(_invs[_i].get_flag_index());
                    _flag.set_search_dir(_i);
                    _search.add_source(_flag);
                }

                var _data = {
                    resource: _arr[_a],
                    max_prio: _max_prio,
                    flags: _flags_
                };
                _search.execute(update_inventories_cb, false, true, _data);

                for (var _i = 0; _i < _n; _i++) {
                    if (_max_prio[_i] > 0) {
                        show_debug_message("game:  dest for inventory " + string(_i) + "found");
                        var _res = _arr[_a];

                        var _dest_bld = _flags_[_i].get_building();
                        if (!_dest_bld.add_requested_resource(_res, false)) {
                            throw ("Failed to request resource.");
                        }

                        /* Put resource in out queue */
                        var _src_inv = _invs[_i];
                        _src_inv.add_to_queue(_res, _dest_bld.get_flag_index());
                    }
                }
            }
            _a += 1;
        }
    };

    /* Update flags as part of the game progression. */
    static update_flags = function() {
        for (var _i = 0; _i < array_length(flags.objects); _i++) {
            var _flag = flags.objects[_i];
            if (_flag != undefined) {
                _flag.update();
            }
        }
    };

    /* data: { inventory, building, serf_type, dest_index, res1, res2 } */
    static send_serf_to_flag_search_cb = function(_flag, _data) {
        if (!_flag.has_inventory()) {
            return false;
        }

        /* Inventory reached */
        var _building = _flag.get_building();
        if (_building == undefined) {
            return false;
        }
        var _inv = _building.get_inventory();
        if (_inv == undefined) {
            /* A castle or stock that is burning down has already handed its
               inventory back, so there is nothing here to call a serf out of.
               Report no match and let the search carry on to the next flag. */
            return false;
        }

        var _type = _data.serf_type;
        if (_type < 0) {
            var _knight_type = -1;
            for (var _i = 4; _i >= -_type - 1; _i--) {
                if (_inv.have_serf(SerfType.knight0 + _i)) {
                    _knight_type = _i;
                    break;
                }
            }

            if (_knight_type >= 0) {
                /* Knight of appropriate type was found. */
                var _serf = _inv.call_out_serf(SerfType.knight0 + _knight_type);

                _data.building.knight_request_granted();

                _serf.go_out_from_inventory(_inv.get_index(),
                                            _data.building.get_flag_index(), -1);

                return true;
            } else if (_type == -1) {
                /* See if a knight can be created here. */
                if (_inv.have_serf(SerfType.generic) &&
                    _inv.get_count_of(ResourceType.sword) > 0 &&
                    _inv.get_count_of(ResourceType.shield) > 0) {
                    _data.inventory = _inv;
                    return true;
                }
            }
        } else {
            if (_inv.have_serf(_type)) {
                if (_type != SerfType.generic || _inv.free_serf_count() > 4) {
                    var _serf = _inv.call_out_serf(_type);

                    var _mode = 0;

                    if (_type == SerfType.generic) {
                        _mode = -2;
                    } else if (_type == SerfType.geologist) {
                        _mode = 6;
                    } else {
                        var _dest_bld = _flag.get_game().flags.get(_data.dest_index).get_building();
                        _dest_bld.serf_request_granted();
                        _mode = -1;
                    }

                    _serf.go_out_from_inventory(_inv.get_index(), _data.dest_index, _mode);

                    return true;
                }
            } else {
                if (_data.inventory == undefined &&
                    _inv.have_serf(SerfType.generic) &&
                    (_data.res1 == -1 || _inv.get_count_of(_data.res1) > 0) &&
                    (_data.res2 == -1 || _inv.get_count_of(_data.res2) > 0)) {
                    _data.inventory = _inv;
                    /* player_t *player = globals->player[SERF_PLAYER(serf)]; */
                    /* game.field_340 = player->cont_search_after_non_optimal_find; */
                    return true;
                }
            }
        }

        return false;
    };

    /* Dispatch serf from (nearest?) inventory to flag. */
    static send_serf_to_flag = function(_dest, _type, _res1, _res2) {
        var _building = undefined;
        if (_dest.has_building()) {
            _building = _dest.get_building();
        }

        /* If type is negative, building is non-NULL. */
        if ((_type < 0) && (_building != undefined)) {
            var _player = players.get(_building.get_owner());
            _type = _player.get_cycling_serf_type(_type);
        }

        var _data = {
            inventory: undefined,
            building: _building,
            serf_type: _type,
            dest_index: _dest.get_index(),
            res1: _res1,
            res2: _res2
        };

        var _r = flag_search_single(_dest, send_serf_to_flag_search_cb, true, false, _data);
        if (!_r) {
            return false;
        } else if (_data.inventory != undefined) {
            var _inventory = _data.inventory;
            var _serf = _inventory.call_out_serf(SerfType.generic);

            if ((_type < 0) && (_building != undefined)) {
                /* Knight */
                _building.knight_request_granted();

                _serf.set_type(SerfType.knight0);
                _serf.go_out_from_inventory(_inventory.get_index(),
                                            _building.get_flag_index(), -1);

                _inventory.pop_resource(ResourceType.sword);
                _inventory.pop_resource(ResourceType.shield);
            } else {
                _serf.set_type(_type);

                var _mode = 0;

                if (_type == SerfType.geologist) {
                    _mode = 6;
                } else {
                    if (_building == undefined) {
                        return false;
                    }
                    _building.serf_request_granted();
                    _mode = -1;
                }

                _serf.go_out_from_inventory(_inventory.get_index(), _dest.get_index(),
                                            _mode);

                if (_res1 != ResourceType.none) {
                    _inventory.pop_resource(_res1);
                }
                if (_res2 != ResourceType.none) {
                    _inventory.pop_resource(_res2);
                }
            }

            return true;
        }

        return true;
    };

    /* Dispatch geologist to flag. */
    static send_geologist = function(_dest) {
        return send_serf_to_flag(_dest, SerfType.geologist, ResourceType.hammer,
                                 ResourceType.none);
    };

    /* Update buildings as part of the game progression. */
    static update_buildings = function() {
        /* C++ iterates over a copy of the collection. */
        var _blds = buildings.to_array();
        var _count = array_length(_blds);
        var _i = 0;
        while (_i < _count) {
            var _building = _blds[_i];
            _i += 1;
            _building.update(tick);
        }
    };

    /* Update serfs as part of the game progression. */
    static update_serfs = function() {
        var _i = 0;
        while (_i < array_length(serfs.objects)) {
            var _serf = serfs.objects[_i];
            _i += 1;
            if (_serf == undefined) {
                continue;
            }
            if (_serf.get_index() != 0) {
                _serf.update();
            }
        }
    };

    /* Update historical player statistics for one measure.
       values: array indexed by player index (undefined = no entry). */
    static record_player_history = function(_max_level, _aspect, _history_index, _values) {
        var _total = 0;
        for (var _p = 0; _p < array_length(_values); _p++) {
            if (_values[_p] != undefined) {
                _total += _values[_p];
            }
        }
        _total = max(1, _total);

        for (var _i = 0; _i < _max_level + 1; _i++) {
            var _mode = (_aspect << 2) | _i;
            var _index = _history_index[_i];
            for (var _p = 0; _p < array_length(_values); _p++) {
                if (_values[_p] != undefined) {
                    var _val = _values[_p];
                    players.get(_p).set_player_stat_history(_mode, _index,
                                                            (100 * _val) div _total);
                }
            }
        }
    };

    /* Calculate whether one player has enough advantage to be
       considered a clear winner regarding one aspect.
       Return -1 if there is no clear winner. */
    static calculate_clear_winner = function(_values) {
        var _total = 0;
        for (var _p = 0; _p < array_length(_values); _p++) {
            if (_values[_p] != undefined) {
                _total += _values[_p];
            }
        }
        _total = max(1, _total);

        for (var _p = 0; _p < array_length(_values); _p++) {
            if (_values[_p] != undefined) {
                var _val = _values[_p];
                if ((100 * _val) div _total >= 75) {
                    return _p;
                }
            }
        }

        return -1;
    };

    /* Update statistics of the game. */
    static update_game_stats = function() {
        if (game_stats_counter > tick_diff) {
            game_stats_counter -= tick_diff;
        } else {
            game_stats_counter += 1500 - tick_diff;

            player_score_leader = 0;

            var _update_level = 0;

            /* Update first level index */
            if (player_history_index[0] + 1 < 112) {
                player_history_index[0] = player_history_index[0] + 1;
            } else {
                player_history_index[0] = 0;
            }

            player_history_counter[0] -= 1;
            if (player_history_counter[0] < 0) {
                _update_level = 1;
                player_history_counter[0] = 3;

                /* Update second level index */
                if (player_history_index[1] + 1 < 112) {
                    player_history_index[1] = player_history_index[1] + 1;
                } else {
                    player_history_index[1] = 0;
                }

                player_history_counter[1] -= 1;
                if (player_history_counter[1] < 0) {
                    _update_level = 2;
                    player_history_counter[1] = 4;

                    /* Update third level index */
                    if (player_history_index[2] + 1 < 112) {
                        player_history_index[2] = player_history_index[2] + 1;
                    } else {
                        player_history_index[2] = 0;
                    }

                    player_history_counter[2] -= 1;
                    if (player_history_counter[2] < 0) {
                        _update_level = 3;

                        player_history_counter[2] = 4;

                        /* Update fourth level index */
                        if (player_history_index[3] + 1 < 112) {
                            player_history_index[3] = player_history_index[3] + 1;
                        } else {
                            player_history_index[3] = 0;
                        }
                    }
                }
            }

            var _values = array_create(array_length(players.objects), undefined);

            /* Store land area stats in history. */
            for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
                var _player = players.objects[_pi];
                if (_player != undefined) {
                    _values[_player.get_index()] = _player.get_land_area();
                }
            }
            record_player_history(_update_level, 1, player_history_index, _values);
            // ToDo (Digger): What is this? BIT(-1)?
            player_score_leader |= (1 << calculate_clear_winner(_values));

            /* Store building stats in history. */
            for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
                var _player = players.objects[_pi];
                if (_player != undefined) {
                    _values[_player.get_index()] = _player.get_building_score();
                }
            }
            record_player_history(_update_level, 2, player_history_index, _values);

            /* Store military stats in history. */
            for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
                var _player = players.objects[_pi];
                if (_player != undefined) {
                    _values[_player.get_index()] = _player.get_military_score();
                }
            }
            record_player_history(_update_level, 3, player_history_index, _values);
            player_score_leader |= (1 << calculate_clear_winner(_values)) << 4;

            /* Store condensed score of all aspects in history. */
            for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
                var _player = players.objects[_pi];
                if (_player != undefined) {
                    _values[_player.get_index()] = _player.get_score();
                }
            }
            record_player_history(_update_level, 0, player_history_index, _values);

            /* TODO Determine winner based on game.player_score_leader */
        }

        if (history_counter > tick_diff) {
            history_counter -= tick_diff;
        } else {
            history_counter += 6000 - tick_diff;

            var _index = resource_history_index;

            for (var _res = 0; _res < 26; _res++) {
                for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
                    var _player = players.objects[_pi];
                    if (_player != undefined) {
                        _player.update_stats(_res);
                    }
                }
            }

            if (_index + 1 < 120) {
                resource_history_index = _index + 1;
            } else {
                resource_history_index = 0;
            }
        }
    };

    /* Update game state after tick increment. */
    static update = function() {
        /* Increment tick counters */
        const_tick += 1;

        /* Update tick counters based on game speed */
        last_tick = tick;
        tick += game_speed;
        tick_diff = tick - last_tick;

        clear_serf_request_failure();
        map.update(tick, init_map_rnd);

        /* Update players */
        for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
            var _player = players.objects[_pi];
            if (_player != undefined) {
                _player.update();
            }
        }

        /* Update knight morale */
        knight_morale_counter -= tick_diff;
        if (knight_morale_counter < 0) {
            update_knight_morale();
            knight_morale_counter += 256;
        }

        /* Schedule resources to go out of inventories */
        inventory_schedule_counter -= tick_diff;
        if (inventory_schedule_counter < 0) {
            update_inventories();
            inventory_schedule_counter += 64;
        }

        /* Freeserf's block here is #if 0 around two TODOs, so this is new
           code rather than a port. See scr_ai. */
        ai_update_players(self);

        update_flags();
        update_buildings();
        update_serfs();
        update_game_stats();

        /* Win / loss, once a second. Not in Freeserf; see check_game_over. */
        game_over_counter -= tick_diff;
        if (game_over_counter < 0) {
            check_game_over();
            game_over_counter += TICKS_PER_SEC;
        }
    };

    /// Has anyone won or lost?
    ///
    /// A player is finished when they have neither a building that is still
    /// standing nor a knight left alive. Buildings under construction count, and
    /// so do knights sitting inside a hut; a building that is burning down does
    /// not, because it is already gone.
    ///
    /// The result is announced through the normal notification system and the
    /// game carries on - nothing is paused or closed - so this can never
    /// interrupt a session.
    ///
    /// game_over_seen is what stops it firing at t=0: at the start of a mission
    /// nobody has placed a castle, so every player would read as finished. A
    /// player only becomes eligible once they have actually had something, and
    /// an opponent who has not started yet holds the victory check off rather
    /// than counting as beaten.
    static check_game_over = function() {
        if (game_over != 0) {
            return;
        }

        var _bld = array_create(GAME_MAX_PLAYER_COUNT, 0);
        var _knights = array_create(GAME_MAX_PLAYER_COUNT, 0);
        var _castle_pos = array_create(GAME_MAX_PLAYER_COUNT, 0);

        var _bs = buildings.to_array();
        for (var _i = 0; _i < array_length(_bs); _i++) {
            var _b = _bs[_i];
            if (_b.is_burning()) {
                continue;
            }
            var _o = _b.get_owner();
            if (_o < 0 || _o >= GAME_MAX_PLAYER_COUNT) {
                continue;
            }
            _bld[_o] += 1;
            if (_b.get_type() == BuildingType.castle) {
                _castle_pos[_o] = _b.get_position();
            }
        }

        var _ss = serfs.to_array();
        for (var _j = 0; _j < array_length(_ss); _j++) {
            var _s = _ss[_j];
            var _t = _s.get_type();
            if (_t < SerfType.knight0 || _t > SerfType.knight4) {
                continue;
            }
            var _so = _s.get_owner();
            if (_so < 0 || _so >= GAME_MAX_PLAYER_COUNT) {
                continue;
            }
            _knights[_so] += 1;
        }

        for (var _p = 0; _p < GAME_MAX_PLAYER_COUNT; _p++) {
            if (_bld[_p] > 0 || _knights[_p] > 0) {
                game_over_seen[_p] = true;
            }
        }

        /* Player 0 is the human, the same assumption the mission setup and the
           panel already make. */
        var _me = 0;
        var _human = get_player(_me);
        if (_human == undefined) {
            return;
        }

        if (game_over_seen[_me] && _bld[_me] == 0 && _knights[_me] == 0) {
            var _victor = _me;
            for (var _v = 0; _v < GAME_MAX_PLAYER_COUNT; _v++) {
                if (_v != _me && (_bld[_v] > 0 || _knights[_v] > 0)) {
                    _victor = _v;
                    break;
                }
            }
            game_over = 2;
            game_over_opponents = collect_opponents(_me);
            _human.add_notification(MessageType.game_lost, _castle_pos[_me], _victor);
            show_debug_message("game: player 0 has nothing left - defeat");
            return;
        }

        var _beaten = -1;
        for (var _q = 0; _q < GAME_MAX_PLAYER_COUNT; _q++) {
            if (_q == _me || !players.exists(_q)) {
                continue;
            }
            if (!game_over_seen[_q]) {
                return;      /* this one has not started yet */
            }
            if (_bld[_q] > 0 || _knights[_q] > 0) {
                return;      /* still standing */
            }
            _beaten = _q;
        }

        if (_beaten < 0) {
            return;          /* no opponents at all, nothing to win */
        }

        game_over = 1;
        game_over_opponents = collect_opponents(_me);
        _human.add_notification(MessageType.game_won, _castle_pos[_me], _beaten);

        /* Tick the mission off in the start screen's list. Only a win counts,
           and only a real mission has an index to tick.

           A game can legitimately have no index: a custom game or a tutorial,
           or a save written before mission_index existed, which comes back as
           the constructor's -1. That last one is worth saying out loud, because
           from the player's seat it looks like winning simply failed to
           register. */
        var _tick = progress_index_for_game(self);
        if (_tick >= 0) {
            progress_mark_mission_done(_tick);
        } else {
            show_debug_message("game: won, but nothing identifies this as a " +
                               "numbered mission (custom game, tutorial, or a " +
                               "save from before the mission list was tracked) " +
                               "- nothing to mark complete");
        }

        show_debug_message("game: every opponent is finished - victory");
    };

    /// Every player except `_me`, in player order. Read once when the game ends
    /// because the end box may be looked at long afterwards, by which time the
    /// collection has moved on.
    static collect_opponents = function(_me) {
        var _list = [];
        for (var _i = 0; _i < GAME_MAX_PLAYER_COUNT; _i++) {
            if (_i == _me || !players.exists(_i)) {
                continue;
            }
            array_push(_list, _i);
        }
        return _list;
    };

    /* Pause or unpause the game. */
    static pause = function() {
        if (game_speed != 0) {
            game_speed_save = game_speed;
            game_speed = 0;
        } else {
            game_speed = game_speed_save;
        }

        show_debug_message("game: Game speed: " + string(game_speed));
    };

    static speed_increase = function() {
        if (game_speed < 40) {
            game_speed += 1;
            show_debug_message("game: Game speed: " + string(game_speed));
        }
    };

    static speed_decrease = function() {
        if (game_speed >= 1) {
            game_speed -= 1;
            show_debug_message("game: Game speed: " + string(game_speed));
        }
    };

    static set_speed = function(_speed) {
        game_speed = _speed;
        show_debug_message("game: Game speed: " + string(game_speed));
    };

    static speed_reset = function() {
        game_speed = DEFAULT_GAME_SPEED;
        show_debug_message("game: Game speed: " + string(game_speed));
    };

    /* ---------------------------------------------------------------- */
    /* Ground analysis                                                   */
    /* ---------------------------------------------------------------- */

    /* Generate an estimate of the amount of resources in the ground at map pos.*/
    static get_resource_estimate = function(_pos, _weight, _estimates) {
        if ((map.get_obj(_pos) == MapObject.none ||
             map.get_obj(_pos) >= MapObject.tree0) &&
            map.get_res_type(_pos) != Minerals.none) {
            var _value = _weight * map.get_res_amount(_pos);
            _estimates[map.get_res_type(_pos)] += _value;
        }
    };

    /* Prepare a ground analysis at position. Fills the 5-element array
       _estimates in place and returns it. */
    static prepare_ground_analysis = function(_pos, _estimates) {
        for (var _i = 0; _i < 5; _i++) {
            _estimates[_i] = 0;
        }

        /* Sample the cursor position with maximum weighting. */
        get_resource_estimate(_pos, GROUND_ANALYSIS_RADIUS, _estimates);

        /* Move outward in a spiral around the initial pos.
           The weighting of the samples attenuates linearly
           with the distance to the center. */
        for (var _i = 0; _i < GROUND_ANALYSIS_RADIUS - 1; _i++) {
            _pos = map.move_right(_pos);

            /* cycle_directions_cw(DirectionDown): down, left, up_left, up, right, down_right */
            for (var _k = 0; _k < 6; _k++) {
                var _d = (Direction.down + _k) mod 6;
                for (var _j = 0; _j < _i + 1; _j++) {
                    get_resource_estimate(_pos, GROUND_ANALYSIS_RADIUS - _i, _estimates);
                    _pos = map.move(_pos, _d);
                }
            }
        }

        /* Process the samples. */
        for (var _i = 0; _i < 5; _i++) {
            _estimates[_i] = _estimates[_i] >> 4;
            _estimates[_i] = min(_estimates[_i], 999);
        }

        return _estimates;
    };

    static road_segment_in_water = function(_pos, _dir) {
        if (_dir > Direction.down) {
            _pos = map.move(_pos, _dir);
            _dir = reverse_direction(_dir);
        }

        var _water = false;

        switch (_dir) {
            case Direction.right:
                if (map.get_type_down(_pos) <= Terrain.water3 &&
                    map.get_type_up(map.move_up(_pos)) <= Terrain.water3) {
                    _water = true;
                }
                break;
            case Direction.down_right:
                if (map.get_type_up(_pos) <= Terrain.water3 &&
                    map.get_type_down(_pos) <= Terrain.water3) {
                    _water = true;
                }
                break;
            case Direction.down:
                if (map.get_type_up(_pos) <= Terrain.water3 &&
                    map.get_type_down(map.move_left(_pos)) <= Terrain.water3) {
                    _water = true;
                }
                break;
            default:
                throw ("NOT_REACHED: road_segment_in_water");
                break;
        }

        return _water;
    };

    /* ---------------------------------------------------------------- */
    /* Roads                                                             */
    /* ---------------------------------------------------------------- */

    /* Test whether a given road can be constructed by player. The final
       destination will be returned in dest, and water will be set if the
       resulting path is a water path.
       This will return success even if the destination does _not_ contain
       a flag, and therefore partial paths can be validated with this function.
       Returns { result, dest, water } where result is the C++ int return
       (0 = cannot build, -1 = invalid segment, 1 = ok). */
    static can_build_road = function(_road, _player) {
        /* Follow along path to other flag. Test along the way
           whether the path is on ground or in water. */
        var _pos = _road.source;
        var _test = 0;

        if (!map.has_owner(_pos) || map.get_owner(_pos) != _player.get_index() ||
            !map.has_flag(_pos)) {
            return { result: 0, dest: BAD_MAP_POS, water: false };
        }

        var _dirs = _road.dirs;
        var _len = array_length(_dirs);
        for (var _it = 0; _it < _len; _it++) {
            var _dir = _dirs[_it];
            if (!map.is_road_segment_valid(_pos, _dir)) {
                return { result: -1, dest: BAD_MAP_POS, water: false };
            }

            if (map.road_segment_in_water(_pos, _dir)) {
                _test |= (1 << 1);
            } else {
                _test |= (1 << 0);
            }

            _pos = map.move(_pos, _dir);

            /* Check that owner is correct, and that only the destination has a flag. */
            if (!map.has_owner(_pos) || map.get_owner(_pos) != _player.get_index() ||
                (map.has_flag(_pos) && _it != _len - 1)) {
                return { result: 0, dest: BAD_MAP_POS, water: false };
            }
        }

        var _d = _pos;

        /* Bit 0 indicates a ground path, bit 1 indicates
           water path. Abort if path went through both
           ground and water. */
        var _w = false;
        if ((_test & (1 << 1)) != 0) {
            _w = true;
            if ((_test & (1 << 0)) != 0) {
                return { result: 0, dest: _d, water: _w };
            }
        }

        return { result: 1, dest: _d, water: _w };
    };

    /* Construct a road spefified by a source and a list of directions. */
    static build_road = function(_road, _player) {
        var _length = array_length(_road.dirs);
        if (_length == 0) {
            return false;
        }

        var _r = can_build_road(_road, _player);
        if (_r.result == 0) {
            return false;
        }
        var _dest = _r.dest;
        var _water_path = _r.water;
        if (!map.has_flag(_dest)) {
            return false;
        }

        var _dirs = _road.dirs;
        var _out_dir = _dirs[0];
        var _in_dir = reverse_direction(_dirs[_length - 1]);

        /* Actually place road segments */
        if (!map.place_road_segments(_road)) {
            return false;
        }

        /* Connect flags */
        var _src_flag = get_flag_at_pos(_road.source);
        var _dest_flag = get_flag_at_pos(_dest);

        _src_flag.link_with_flag(_dest_flag, _water_path, _length,
                                 _in_dir, _out_dir);

        return true;
    };

    static flag_reset_transport = function(_flag) {
        /* Clear destination for any serf with resources for this flag. */
        for (var _i = 0; _i < array_length(serfs.objects); _i++) {
            var _serf = serfs.objects[_i];
            if (_serf != undefined) {
                _serf.reset_transport(_flag);
            }
        }

        /* Flag. */
        for (var _i = 0; _i < array_length(flags.objects); _i++) {
            var _other_flag = flags.objects[_i];
            if (_other_flag != undefined) {
                _flag.reset_transport(_other_flag);
            }
        }

        /* Inventories. */
        for (var _i = 0; _i < array_length(inventories.objects); _i++) {
            var _inventory = inventories.objects[_i];
            if (_inventory != undefined) {
                _inventory.reset_queue_for_dest(_flag);
            }
        }
    };

    static building_remove_player_refs = function(_building) {
        for (var _i = 0; _i < array_length(players.objects); _i++) {
            var _player = players.objects[_i];
            if (_player != undefined) {
                if (_player.temp_index == _building.get_index()) {
                    _player.temp_index = 0;
                }
            }
        }
    };

    static path_serf_idle_to_wait_state = function(_pos) {
        /* Look through serf array for the corresponding serf. */
        for (var _i = 0; _i < array_length(serfs.objects); _i++) {
            var _serf = serfs.objects[_i];
            if (_serf != undefined) {
                if (_serf.idle_to_wait_state(_pos)) {
                    return true;
                }
            }
        }

        return false;
    };

    static remove_road_forwards = function(_pos, _dir) {
        var _in_dir = Direction.none;

        while (true) {
            if (map.get_idle_serf(_pos)) {
                path_serf_idle_to_wait_state(_pos);
            }

            if (map.has_serf(_pos)) {
                var _serf = get_serf_at_pos(_pos);
                if (_serf == undefined) {
                    /* tile pointed at a serf that is gone */
                } else if (!map.has_flag(_pos)) {
                    _serf.set_lost_state();
                } else {
                    /* Handle serf close to flag, where
                       it should only be lost if walking
                       in the wrong direction. */
                    var _d = _serf.get_walking_dir();
                    if (_d < 0) {
                        _d += 6;
                    }
                    if (_d == reverse_direction(_dir)) {
                        _serf.set_lost_state();
                    }
                }
            }

            if (map.has_flag(_pos)) {
                var _flag = flags.get(map.get_obj_index(_pos));
                _flag.del_path(reverse_direction(_in_dir));
                break;
            }

            _in_dir = _dir;
            var _r = map.remove_road_segment(_pos, _dir);
            _pos = _r.pos;
            _dir = _r.dir;
        }
    };

    static demolish_road_ = function(_pos) {
        /* TODO necessary?
        game.player[0]->flags |= BIT(4);
        game.player[1]->flags |= BIT(4);
        */

        if (!map.remove_road_backrefs(_pos)) {
            /* TODO */
            return false;
        }

        /* Find directions of path segments to be split. */
        var _path_1_dir = Direction.none;
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            if (map.has_path(_pos, _d)) {
                _path_1_dir = _d;
                break;
            }
        }

        var _path_2_dir = Direction.none;
        for (var _d = _path_1_dir + 1; _d <= Direction.up; _d++) {
            if (map.has_path(_pos, _d)) {
                _path_2_dir = _d;
                break;
            }
        }

        /* If last segment direction is UP LEFT it could
           be to a building and the real path is at UP. */
        if (_path_2_dir == Direction.up_left && map.has_path(_pos, Direction.up)) {
            _path_2_dir = Direction.up;
        }

        remove_road_forwards(_pos, _path_1_dir);
        remove_road_forwards(_pos, _path_2_dir);

        return true;
    };

    /* Demolish road at position. */
    static demolish_road = function(_pos, _player) {
        if (!can_demolish_road(_pos, _player)) {
            return false;
        }

        return demolish_road_(_pos);
    };

    /* ---------------------------------------------------------------- */
    /* Flags                                                             */
    /* ---------------------------------------------------------------- */

    /* Build flag on existing path. Path must be split in two segments. */
    static build_flag_split_path = function(_pos) {
        /* Find directions of path segments to be split. */
        var _path_1_dir = Direction.none;
        var _it = Direction.right;
        for (; _it <= Direction.up; _it++) {
            if (map.has_path(_pos, _it)) {
                _path_1_dir = _it;
                break;
            }
        }

        var _path_2_dir = Direction.none;
        _it += 1;
        for (; _it <= Direction.up; _it++) {
            if (map.has_path(_pos, _it)) {
                _path_2_dir = _it;
                break;
            }
        }

        /* If last segment direction is UP LEFT it could
           be to a building and the real path is at UP. */
        if (_path_2_dir == Direction.up_left && map.has_path(_pos, Direction.up)) {
            _path_2_dir = Direction.up;
        }

        var _path_1_data = flag_fill_path_serf_info(self, _pos, _path_1_dir, undefined);
        var _path_2_data = flag_fill_path_serf_info(self, _pos, _path_2_dir, undefined);

        var _flag_2 = flags.get(_path_2_data.flag_index);
        var _dir_2 = _path_2_data.flag_dir;

        var _select = -1;
        if (_flag_2.serf_requested(_dir_2)) {
            for (var _i = 0; _i < array_length(serfs.objects); _i++) {
                var _serf = serfs.objects[_i];
                if (_serf == undefined) {
                    continue;
                }
                var _r = _serf.path_splited(_path_1_data.flag_index, _path_1_data.flag_dir,
                                            _path_2_data.flag_index, _path_2_data.flag_dir,
                                            _select);
                if (_r.result) {
                    _select = _r.select;
                    break;
                }
            }

            var _path_data = _path_1_data;
            if (_select == 0) {
                _path_data = _path_2_data;
            }

            var _selected_flag = flags.get(_path_data.flag_index);
            _selected_flag.cancel_serf_request(_path_data.flag_dir);
        }

        var _flag = flags.get(map.get_obj_index(_pos));

        _flag.restore_path_serf_info(_path_1_dir, _path_1_data);
        _flag.restore_path_serf_info(_path_2_dir, _path_2_data);
    };

    /* Check whether player can build flag at pos. */
    static can_build_flag = function(_pos, _player) {
        /* Check owner of land */
        if (!map.has_owner(_pos) || map.get_owner(_pos) != _player.get_index()) {
            return false;
        }

        /* Check that land is clear */
        if (global.map_space_from_obj[map.get_obj(_pos)] != Space.open) {
            return false;
        }

        /* Check whether cursor is in water */
        if (map.get_type_up(_pos) <= Terrain.water3 &&
            map.get_type_down(_pos) <= Terrain.water3 &&
            map.get_type_down(map.move_left(_pos)) <= Terrain.water3 &&
            map.get_type_up(map.move_up_left(_pos)) <= Terrain.water3 &&
            map.get_type_down(map.move_up_left(_pos)) <= Terrain.water3 &&
            map.get_type_up(map.move_up(_pos)) <= Terrain.water3) {
            return false;
        }

        /* Check that no flags are nearby */
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            if (map.get_obj(map.move(_pos, _d)) == MapObject.flag) {
                return false;
            }
        }

        return true;
    };

    /* Build flag at pos. */
    static build_flag = function(_pos, _player) {
        if (!can_build_flag(_pos, _player)) {
            return false;
        }

        var _flag = flags.allocate();
        if (_flag == undefined) {
            return false;
        }

        _flag.set_owner(_player.get_index());
        _flag.set_position(_pos);
        map.set_object(_pos, MapObject.flag, _flag.get_index());

        if (map.get_paths(_pos) != 0) {
            build_flag_split_path(_pos);
        }

        return true;
    };

    /* ---------------------------------------------------------------- */
    /* Building placement checks                                         */
    /* ---------------------------------------------------------------- */

    /* Check whether military buildings are allowed at pos. */
    static can_build_military = function(_pos) {
        /* Check that no military buildings are nearby */
        for (var _i = 0; _i < 1 + 6 + 12; _i++) {
            var _p = map.pos_add_spirally(_pos, _i);
            if (map.get_obj(_p) >= MapObject.small_building &&
                map.get_obj(_p) <= MapObject.castle) {
                var _bld = buildings.get(map.get_obj_index(_p));
                if (_bld.is_military()) {
                    return false;
                }
            }
        }

        return true;
    };

    /* Return the height that is needed before a large building can be built.
       Returns negative if the needed height cannot be reached. */
    static get_leveling_height = function(_pos) {
        /* Find min and max height */
        var _h_min = 31;
        var _h_max = 0;
        for (var _i = 0; _i < 12; _i++) {
            var _p = map.pos_add_spirally(_pos, 7 + _i);
            var _h = map.get_height(_p);
            if (_h_min > _h) {
                _h_min = _h;
            }
            if (_h_max < _h) {
                _h_max = _h;
            }
        }

        /* Adjust for height of adjacent unleveled buildings */
        for (var _i = 0; _i < 18; _i++) {
            var _p = map.pos_add_spirally(_pos, 19 + _i);
            if (map.get_obj(_p) == MapObject.large_building) {
                var _bld = buildings.get(map.get_obj_index(_p));
                if (_bld.is_leveling()) { /* Leveling in progress */
                    var _h = _bld.get_level();
                    if (_h_min > _h) {
                        _h_min = _h;
                    }
                    if (_h_max < _h) {
                        _h_max = _h;
                    }
                }
            }
        }

        /* Return if height difference is too big */
        if (_h_max - _h_min >= 9) {
            return -1;
        }

        /* Calculate "mean" height. Height of center is added twice. */
        var _h_mean = map.get_height(_pos);
        for (var _i = 0; _i < 7; _i++) {
            var _p = map.pos_add_spirally(_pos, _i);
            _h_mean += map.get_height(_p);
        }
        _h_mean = _h_mean >> 3;

        /* Calcualte height after leveling */
        var _h_new_min_base = 1;
        if (_h_max > 4) {
            _h_new_min_base = _h_max - 4;
        }
        var _h_new_min = max(_h_new_min_base, 1);
        var _h_new_max = _h_min + 4;
        var _h_new = clamp(_h_mean, _h_new_min, _h_new_max);

        return _h_new;
    };

    static map_types_within = function(_pos, _low, _high) {
        if ((map.get_type_up(_pos) >= _low &&
             map.get_type_up(_pos) <= _high) &&
            (map.get_type_down(_pos) >= _low &&
             map.get_type_down(_pos) <= _high) &&
            (map.get_type_down(map.move_left(_pos)) >= _low &&
             map.get_type_down(map.move_left(_pos)) <= _high) &&
            (map.get_type_up(map.move_up_left(_pos)) >= _low &&
             map.get_type_up(map.move_up_left(_pos)) <= _high) &&
            (map.get_type_down(map.move_up_left(_pos)) >= _low &&
             map.get_type_down(map.move_up_left(_pos)) <= _high) &&
            (map.get_type_up(map.move_up(_pos)) >= _low &&
             map.get_type_up(map.move_up(_pos)) <= _high)) {
            return true;
        }

        return false;
    };

    /* Checks whether a small building is possible at position.*/
    static can_build_small = function(_pos) {
        return map_types_within(_pos, Terrain.grass0, Terrain.grass3);
    };

    /* Checks whether a mine is possible at position. */
    static can_build_mine = function(_pos) {
        var _can_build = false;

        var _types = [
            map.get_type_down(_pos),
            map.get_type_up(_pos),
            map.get_type_down(map.move_left(_pos)),
            map.get_type_up(map.move_up_left(_pos)),
            map.get_type_down(map.move_up_left(_pos)),
            map.get_type_up(map.move_up(_pos))
        ];

        for (var _i = 0; _i < 6; _i++) {
            if (_types[_i] >= Terrain.tundra0 && _types[_i] <= Terrain.snow0) {
                _can_build = true;
            } else if (!(_types[_i] >= Terrain.grass0 &&
                         _types[_i] <= Terrain.grass3)) {
                return false;
            }
        }

        return _can_build;
    };

    /* Checks whether a large building is possible at position. */
    static can_build_large = function(_pos) {
        /* Check that surroundings are passable by serfs. */
        for (var _i = 0; _i < 6; _i++) {
            var _p = map.pos_add_spirally(_pos, 1 + _i);
            var _s = global.map_space_from_obj[map.get_obj(_p)];
            if (_s >= Space.semipassable) {
                return false;
            }
        }

        /* Check that buildings in the second shell aren't large or castle. */
        for (var _i = 0; _i < 12; _i++) {
            var _p = map.pos_add_spirally(_pos, 7 + _i);
            if (map.get_obj(_p) >= MapObject.large_building &&
                map.get_obj(_p) <= MapObject.castle) {
                return false;
            }
        }

        /* Check if center hexagon is not type grass. */
        if (map.get_type_up(_pos) != Terrain.grass1 ||
            map.get_type_down(_pos) != Terrain.grass1 ||
            map.get_type_down(map.move_left(_pos)) != Terrain.grass1 ||
            map.get_type_up(map.move_up_left(_pos)) != Terrain.grass1 ||
            map.get_type_down(map.move_up_left(_pos)) != Terrain.grass1 ||
            map.get_type_up(map.move_up(_pos)) != Terrain.grass1) {
            return false;
        }

        /* Check that leveling is possible */
        var _r = get_leveling_height(_pos);
        if (_r < 0) {
            return false;
        }

        return true;
    };

    /* Checks whether a castle can be built by player at position. */
    static can_build_castle = function(_pos, _player) {
        if (_player.has_castle()) {
            return false;
        }

        /* Check owner of land around position */
        for (var _i = 0; _i < 7; _i++) {
            var _p = map.pos_add_spirally(_pos, _i);
            if (map.has_owner(_p)) {
                return false;
            }
        }

        /* Check that land is clear at position */
        if (global.map_space_from_obj[map.get_obj(_pos)] != Space.open ||
            map.get_paths(_pos) != 0) {
            return false;
        }

        var _flag_pos = map.move_down_right(_pos);

        /* Check that land is clear at position */
        if (global.map_space_from_obj[map.get_obj(_flag_pos)] != Space.open ||
            map.get_paths(_flag_pos) != 0) {
            return false;
        }

        if (!can_build_large(_pos)) {
            return false;
        }

        return true;
    };

    /* Check whether player is allowed to build anything
       at position. To determine if the initial castle can
       be built use can_build_castle() instead.

       TODO Existing buildings at position should be
       disregarded so this can be used to determine what
       can be built after the existing building has been
       demolished. */
    static can_player_build = function(_pos, _player) {
        if (!_player.has_castle()) {
            return false;
        }

        /* Check owner of land around position */
        for (var _i = 0; _i < 7; _i++) {
            var _p = map.pos_add_spirally(_pos, _i);
            if (!map.has_owner(_p) || map.get_owner(_p) != _player.get_index()) {
                return false;
            }
        }

        /* Check whether cursor is in water */
        if (map.get_type_up(_pos) <= Terrain.water3 &&
            map.get_type_down(_pos) <= Terrain.water3 &&
            map.get_type_down(map.move_left(_pos)) <= Terrain.water3 &&
            map.get_type_up(map.move_up_left(_pos)) <= Terrain.water3 &&
            map.get_type_down(map.move_up_left(_pos)) <= Terrain.water3 &&
            map.get_type_up(map.move_up(_pos)) <= Terrain.water3) {
            return false;
        }

        /* Check that no paths are blocking. */
        if (map.get_paths(_pos) != 0) {
            return false;
        }

        return true;
    };

    /* Checks whether a building of the specified type is possible at
       position. */
    static can_build_building = function(_pos, _type, _player) {
        if (!can_player_build(_pos, _player)) {
            return false;
        }

        /* Check that space is clear */
        if (global.map_space_from_obj[map.get_obj(_pos)] != Space.open) {
            return false;
        }

        /* Check that building flag is possible if it
           doesn't already exist. */
        var _flag_pos = map.move_down_right(_pos);
        if (!map.has_flag(_flag_pos) && !can_build_flag(_flag_pos, _player)) {
            return false;
        }

        /* Check if building size is possible. */
        switch (_type) {
            case BuildingType.fisher:
            case BuildingType.lumberjack:
            case BuildingType.boatbuilder:
            case BuildingType.stonecutter:
            case BuildingType.forester:
            case BuildingType.hut:
            case BuildingType.mill:
                if (!can_build_small(_pos)) {
                    return false;
                }
                break;
            case BuildingType.stone_mine:
            case BuildingType.coal_mine:
            case BuildingType.iron_mine:
            case BuildingType.gold_mine:
                if (!can_build_mine(_pos)) {
                    return false;
                }
                break;
            case BuildingType.stock:
            case BuildingType.farm:
            case BuildingType.butcher:
            case BuildingType.pig_farm:
            case BuildingType.baker:
            case BuildingType.sawmill:
            case BuildingType.steel_smelter:
            case BuildingType.tool_maker:
            case BuildingType.weapon_smith:
            case BuildingType.tower:
            case BuildingType.fortress:
            case BuildingType.gold_smelter:
                if (!can_build_large(_pos)) {
                    return false;
                }
                break;
            default:
                throw ("NOT_REACHED: can_build_building");
                break;
        }

        /* Check if military building is possible */
        if ((_type == BuildingType.hut ||
             _type == BuildingType.tower ||
             _type == BuildingType.fortress) &&
            !can_build_military(_pos)) {
            return false;
        }

        return true;
    };

    /* ---------------------------------------------------------------- */
    /* Building construction                                             */
    /* ---------------------------------------------------------------- */

    /* Build building at position. */
    static build_building = function(_pos, _type, _player) {
        if (!can_build_building(_pos, _type, _player)) {
            return false;
        }

        if (_type == BuildingType.stock) {
            /* TODO Check that more stocks are allowed to be built */
        }

        var _bld = buildings.allocate();
        if (_bld == undefined) {
            return false;
        }

        var _flag = get_flag_at_pos(map.move_down_right(_pos));
        if (_flag == undefined) {
            if (!build_flag(map.move_down_right(_pos), _player)) {
                buildings.erase(_bld.get_index());
                return false;
            }
            _flag = get_flag_at_pos(map.move_down_right(_pos));
        }
        var _flg_index = _flag.get_index();

        _bld.set_level(get_leveling_height(_pos));
        _bld.set_position(_pos);
        var _map_obj = _bld.start_building(_type);
        _player.building_founded(_bld);

        var _split_path = false;
        if (map.get_obj(map.move_down_right(_pos)) != MapObject.flag) {
            _flag.set_owner(_player.get_index());
            _split_path = (map.get_paths(map.move_down_right(_pos)) != 0);
        } else {
            _flg_index = map.get_obj_index(map.move_down_right(_pos));
            _flag = flags.get(_flg_index);
        }

        _flag.set_position(map.move_down_right(_pos));

        _bld.link_flag(_flg_index);
        _flag.link_building(_bld);

        _flag.clear_flags();

        map.clear_idle_serf(_pos);

        map.set_object(_pos, _map_obj, _bld.get_index());
        map.add_path(_pos, Direction.down_right);

        if (map.get_obj(map.move_down_right(_pos)) != MapObject.flag) {
            map.set_object(map.move_down_right(_pos), MapObject.flag, _flg_index);
            map.add_path(map.move_down_right(_pos), Direction.up_left);
        }

        if (_split_path) {
            build_flag_split_path(map.move_down_right(_pos));
        }

        return true;
    };

    /* Build castle at position. */
    static build_castle = function(_pos, _player) {
        if (!can_build_castle(_pos, _player)) {
            return false;
        }

        var _inventory = inventories.allocate();
        if (_inventory == undefined) {
            return false;
        }

        var _castle = buildings.allocate();
        if (_castle == undefined) {
            inventories.erase(_inventory.get_index());
            return false;
        }

        var _flag = flags.allocate();
        if (_flag == undefined) {
            buildings.erase(_castle.get_index());
            inventories.erase(_inventory.get_index());
            return false;
        }

        _castle.set_inventory(_inventory);

        _inventory.set_building_index(_castle.get_index());
        _inventory.set_flag_index(_flag.get_index());
        _inventory.set_owner(_player.get_index());
        _inventory.apply_supplies_preset(_player.get_initial_supplies());

        add_gold_total(_inventory.get_count_of(ResourceType.gold_bar));
        add_gold_total(_inventory.get_count_of(ResourceType.gold_ore));

        _castle.set_position(_pos);
        _flag.set_position(map.move_down_right(_pos));
        _castle.set_owner(_player.get_index());
        _castle.start_building(BuildingType.castle);

        _flag.set_owner(_player.get_index());
        _flag.set_accepts_serfs(true);
        _flag.set_has_inventory();
        _flag.set_accepts_resources(true);
        _castle.link_flag(_flag.get_index());
        _flag.link_building(_castle);

        map.set_object(_pos, MapObject.castle, _castle.get_index());
        map.add_path(_pos, Direction.down_right);

        map.set_object(map.move_down_right(_pos), MapObject.flag,
                       _flag.get_index());
        map.add_path(map.move_down_right(_pos), Direction.up_left);

        /* Level land in hexagon below castle */
        var _h = get_leveling_height(_pos);
        map.set_height(_pos, _h);
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            map.set_height(map.move(_pos, _d), _h);
        }

        update_land_ownership(_pos);

        _player.building_founded(_castle);

        _castle.update_military_flag_state();

        return true;
    };

    static flag_remove_player_refs = function(_flag) {
        for (var _i = 0; _i < array_length(players.objects); _i++) {
            var _player = players.objects[_i];
            if (_player != undefined) {
                if (_player.temp_index == _flag.get_index()) {
                    _player.temp_index = 0;
                }
            }
        }
    };

    /* ---------------------------------------------------------------- */
    /* Demolition                                                        */
    /* ---------------------------------------------------------------- */

    /* Check whether road can be demolished. */
    static can_demolish_road = function(_pos, _player) {
        if (!map.has_owner(_pos) || map.get_owner(_pos) != _player.get_index()) {
            return false;
        }

        if (map.get_paths(_pos) == 0 ||
            map.has_flag(_pos) ||
            map.has_building(_pos)) {
            return false;
        }

        return true;
    };

    /* Check whether flag can be demolished. */
    static can_demolish_flag = function(_pos, _player) {
        if (map.get_obj(_pos) != MapObject.flag) {
            return false;
        }

        var _flag = flags.get(map.get_obj_index(_pos));

        if (_flag.has_building()) {
            return false;
        }

        if (map.get_paths(_pos) == 0) {
            return true;
        }

        if (_flag.get_owner() != _player.get_index()) {
            return false;
        }

        return _flag.can_demolish();
    };

    static demolish_flag_ = function(_pos) {
        /* Handle any serf at pos. */
        if (map.has_serf(_pos)) {
            var _serf = get_serf_at_pos(_pos);
            if (_serf != undefined) {
                _serf.flag_deleted(_pos);
            }
        }

        var _flag = flags.get(map.get_obj_index(_pos));
        if (_flag.has_building()) {
            /* This should now be unreachable: surrender_land() demolishes the
               building at every one of the six neighbours before it gets here,
               and delete_building() detaches the flag when a burn finishes. If
               a link ever survives both, take the building down properly if it
               is still on the map, and failing that just detach the flag. A
               ported assert is not worth a crash to desktop mid-game. */
            var _bpos = map.move_up_left(_pos);
            if (map.get_obj(_bpos) >= MapObject.small_building &&
                map.get_obj(_bpos) <= MapObject.castle) {
                demolish_building_(_bpos);
            }
            if (_flag.has_building()) {
                show_debug_message("game: flag at " + string(_pos) +
                                   " claimed a building that is not on the map - detached");
                _flag.unlink_building();
            }
        }

        flag_remove_player_refs(_flag);

        /* Handle connected flag. */
        _flag.merge_paths(_pos);

        /* Update serfs with reference to this flag. */
        for (var _i = 0; _i < array_length(serfs.objects); _i++) {
            var _serf = serfs.objects[_i];
            if (_serf != undefined) {
                _serf.path_merged(_flag);
            }
        }

        map.set_object(_pos, MapObject.none, 0);

        /* Remove resources from flag. */
        _flag.remove_all_resources();

        flags.erase(_flag.get_index());

        return true;
    };

    /* Demolish flag at pos. */
    static demolish_flag = function(_pos, _player) {
        if (!can_demolish_flag(_pos, _player)) {
            return false;
        }

        return demolish_flag_(_pos);
    };

    static demolish_building_ = function(_pos) {
        var _building = buildings.get(map.get_obj_index(_pos));
        if (_building.burnup()) {
            building_remove_player_refs(_building);

            /* Remove path to building. */
            map.del_path(_pos, Direction.down_right);
            map.del_path(map.move_down_right(_pos), Direction.up_left);

            /* Disconnect flag. */
            var _flag_index = _building.get_flag_index();
            if (_flag_index > 0) {
                var _flag = flags.get(_flag_index);
                _flag.unlink_building();
                _building.unlink_flag();
                flag_reset_transport(_flag);
            }

            return true;
        }

        return false;
    };

    /* Demolish building at pos. */
    static demolish_building = function(_pos, _player) {
        var _building = buildings.get(map.get_obj_index(_pos));

        if (_building.get_owner() != _player.get_index()) {
            return false;
        }
        if (_building.is_burning()) {
            return false;
        }

        return demolish_building_(_pos);
    };

    /* Map pos is lost to the owner, demolish everything. */
    static surrender_land = function(_pos) {
        /* Remove building. */
        if (map.get_obj(_pos) >= MapObject.small_building &&
            map.get_obj(_pos) <= MapObject.castle) {
            demolish_building_(_pos);
        }

        if (!map.has_flag(_pos) && map.get_paths(_pos) != 0) {
            demolish_road_(_pos);
        }

        var _remove_roads = map.has_flag(_pos);

        /* Remove roads and building around pos. */
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            var _p = map.move(_pos, _d);

            if (map.get_obj(_p) >= MapObject.small_building &&
                map.get_obj(_p) <= MapObject.castle) {
                demolish_building_(_p);
            }

            if (_remove_roads &&
                (map.get_paths(_p) & (1 << reverse_direction(_d))) != 0) {
                demolish_road_(_p);
            }
        }

        /* Remove flag. */
        if (map.get_obj(_pos) == MapObject.flag) {
            demolish_flag_(_pos);
        }
    };

    /* ---------------------------------------------------------------- */
    /* Land ownership                                                    */
    /* ---------------------------------------------------------------- */

    /* Initialize land ownership for whole map. */
    static init_land_ownership = function() {
        for (var _i = 0; _i < array_length(buildings.objects); _i++) {
            var _building = buildings.objects[_i];
            if (_building != undefined) {
                if (_building.is_military()) {
                    update_land_ownership(_building.get_position());
                }
            }
        }
    };

    /* Update land ownership around map position. */
    static update_land_ownership = function(_init_pos) {
        /* Currently the below algorithm will only work when
           both influence_radius and calculate_radius are 8. */
        var _influence_radius = 8;
        var _influence_diameter = 1 + 2 * _influence_radius;

        var _calculate_radius = _influence_radius;
        var _calculate_diameter = 1 + 2 * _calculate_radius;

        var _temp_arr_size = _calculate_diameter * _calculate_diameter *
                             players.size();
        var _temp_arr = array_create(_temp_arr_size, 0);

        var _military_influence = global.game_military_influence;
        var _map_closeness = global.game_map_closeness;

        /* Find influence from buildings in 33*33 square
           around the center. */
        for (var _i = -(_influence_radius + _calculate_radius);
             _i <= _influence_radius + _calculate_radius; _i++) {
            for (var _j = -(_influence_radius + _calculate_radius);
                 _j <= _influence_radius + _calculate_radius; _j++) {
                var _pos = map.pos_add(_init_pos, _j, _i);

                if (map.get_obj(_pos) >= MapObject.small_building &&
                    map.get_obj(_pos) <= MapObject.castle &&
                    map.has_path(_pos, Direction.down_right)) {  // TODO(_): Why wouldn't this be set?
                    var _building = get_building_at_pos(_pos);
                    var _mil_type = -1;

                    if (_building.get_type() == BuildingType.castle) {
                        /* Castle has military influence even when not done. */
                        _mil_type = 2;
                    } else if (_building.is_done() && _building.is_active()) {
                        switch (_building.get_type()) {
                            case BuildingType.hut: _mil_type = 0; break;
                            case BuildingType.tower: _mil_type = 1; break;
                            case BuildingType.fortress: _mil_type = 2; break;
                            default: break;
                        }
                    }

                    if (_mil_type >= 0 && !_building.is_burning()) {
                        /* Pointer arithmetic from the C++ becomes explicit
                           offsets into the tables. */
                        var _influence = 10 * _mil_type;
                        var _closeness = _influence_diameter * max(-_i, 0) +
                                         max(-_j, 0);
                        var _arr = (_building.get_owner() * _calculate_diameter * _calculate_diameter) +
                                   _calculate_diameter * max(_i, 0) + max(_j, 0);

                        for (var _k = 0; _k < _influence_diameter - abs(_i); _k++) {
                            for (var _l = 0; _l < _influence_diameter - abs(_j); _l++) {
                                var _inf = _military_influence[_influence + _map_closeness[_closeness]];
                                if (_inf < 0) {
                                    _temp_arr[_arr] = 128;
                                } else if (_temp_arr[_arr] < 128) {
                                    _temp_arr[_arr] = min(_temp_arr[_arr] + _inf, 127);
                                }

                                _closeness += 1;
                                _arr += 1;
                            }
                            _closeness += abs(_j);
                            _arr += abs(_j);
                        }
                    }
                }
            }
        }

        /* Update owner of 17*17 square. */
        for (var _i = -_calculate_radius; _i <= _calculate_radius; _i++) {
            for (var _j = -_calculate_radius; _j <= _calculate_radius; _j++) {
                var _max_val = 0;
                var _player_index = -1;
                for (var _pi = 0; _pi < array_length(players.objects); _pi++) {
                    var _player = players.objects[_pi];
                    if (_player == undefined) {
                        continue;
                    }
                    var _arr = _player.get_index() * _calculate_diameter * _calculate_diameter +
                               _calculate_diameter * (_i + _calculate_radius) + (_j + _calculate_radius);
                    if (_temp_arr[_arr] > _max_val) {
                        _max_val = _temp_arr[_arr];
                        _player_index = _player.get_index();
                    }
                }

                var _pos = map.pos_add(_init_pos, _j, _i);
                var _old_player = -1;
                if (map.has_owner(_pos)) {
                    _old_player = map.get_owner(_pos);
                }

                if (_old_player >= 0 && _player_index != _old_player) {
                    players.get(_old_player).decrease_land_area();
                    surrender_land(_pos);
                }

                if (_player_index >= 0) {
                    if (_player_index != _old_player) {
                        players.get(_player_index).increase_land_area();
                        map.set_owner(_pos, _player_index);
                    }
                } else {
                    map.del_owner(_pos);
                }
            }
        }

        /* Update military building flag state. */
        for (var _i = -25; _i <= 25; _i++) {
            for (var _j = -25; _j <= 25; _j++) {
                var _pos = map.pos_add(_init_pos, _i, _j);

                if (map.get_obj(_pos) >= MapObject.small_building &&
                    map.get_obj(_pos) <= MapObject.castle &&
                    map.has_path(_pos, Direction.down_right)) {
                    var _building = buildings.get(map.get_obj_index(_pos));
                    if (_building.is_done() && _building.is_military()) {
                        _building.update_military_flag_state();
                    }
                }
            }
        }
    };

    static demolish_flag_and_roads = function(_pos) {
        if (map.has_flag(_pos)) {
            /* Remove roads around pos. */
            for (var _d = Direction.right; _d <= Direction.up; _d++) {
                var _p = map.move(_pos, _d);

                if ((map.get_paths(_p) & (1 << reverse_direction(_d))) != 0) {
                    demolish_road_(_p);
                }
            }

            if (map.get_obj(_pos) == MapObject.flag) {
                demolish_flag_(_pos);
            }
        } else if (map.get_paths(_pos) != 0) {
            demolish_road_(_pos);
        }
    };

    /* The given building has been defeated and is being
       occupied by player. */
    static occupy_enemy_building = function(_building, _player_num) {
        /* Take the building. */
        var _player = players.get(_player_num);

        _player.building_captured(_building);

        if (_building.get_type() == BuildingType.castle) {
            demolish_building_(_building.get_position());
        } else {
            var _flag = flags.get(_building.get_flag_index());
            flag_reset_transport(_flag);

            /* Demolish nearby buildings. */
            for (var _i = 0; _i < 12; _i++) {
                var _pos = map.pos_add_spirally(_building.get_position(), 7 + _i);
                if (map.get_obj(_pos) >= MapObject.small_building &&
                    map.get_obj(_pos) <= MapObject.castle) {
                    demolish_building_(_pos);
                }
            }

            /* Change owner of land and remove roads and flags
               except the flag associated with the building. */
            map.set_owner(_building.get_position(), _player_num);

            for (var _d = Direction.right; _d <= Direction.up; _d++) {
                var _pos = map.move(_building.get_position(), _d);
                map.set_owner(_pos, _player_num);
                if (_pos != _flag.get_position()) {
                    demolish_flag_and_roads(_pos);
                }
            }

            /* Change owner of flag. */
            _flag.set_owner(_player_num);

            /* Reset destination of stolen resources. */
            _flag.reset_destination_of_stolen_resources();

            /* Remove paths from flag. */
            for (var _d = Direction.right; _d <= Direction.up; _d++) {
                if (_flag.has_path(_d)) {
                    demolish_road_(map.move(_flag.get_position(), _d));
                }
            }

            update_land_ownership(_building.get_position());
        }
    };

    /* ---------------------------------------------------------------- */
    /* Inventory modes                                                   */
    /* ---------------------------------------------------------------- */

    /* mode: 0: IN, 1: STOP, 2: OUT */
    static set_inventory_resource_mode = function(_inventory, _mode) {
        var _flag = flags.get(_inventory.get_flag_index());

        if (_mode == 0) {
            _inventory.set_res_mode(InventoryMode.mode_in);
        } else if (_mode == 1) {
            _inventory.set_res_mode(InventoryMode.mode_stop);
        } else {
            _inventory.set_res_mode(InventoryMode.mode_out);
        }

        if (_mode > 0) {
            _flag.set_accepts_resources(false);

            /* Clear destination of serfs with resources destined
               for this inventory. */
            var _dest = _flag.get_index();
            for (var _i = 0; _i < array_length(serfs.objects); _i++) {
                var _serf = serfs.objects[_i];
                if (_serf != undefined) {
                    _serf.clear_destination2(_dest);
                }
            }
        } else {
            _flag.set_accepts_resources(true);
        }
    };

    /* mode: 0: IN, 1: STOP, 2: OUT */
    static set_inventory_serf_mode = function(_inventory, _mode) {
        var _flag = flags.get(_inventory.get_flag_index());

        if (_mode == 0) {
            _inventory.set_serf_mode(InventoryMode.mode_in);
        } else if (_mode == 1) {
            _inventory.set_serf_mode(InventoryMode.mode_stop);
        } else {
            _inventory.set_serf_mode(InventoryMode.mode_out);
        }

        if (_mode > 0) {
            _flag.set_accepts_serfs(false);

            /* Clear destination of serfs destined for this inventory. */
            var _dest = _flag.get_index();
            for (var _i = 0; _i < array_length(serfs.objects); _i++) {
                var _serf = serfs.objects[_i];
                if (_serf != undefined) {
                    _serf.clear_destination(_dest);
                }
            }
        } else {
            _flag.set_accepts_serfs(true);
        }
    };

    /* ---------------------------------------------------------------- */
    /* Players / init                                                    */
    /* ---------------------------------------------------------------- */

    // Add new player to the game. Returns the player number.
    static add_player = function(_intelligence, _supplies, _reproduction) {
        /* Allocate object */
        var _player = players.allocate();
        if (_player == undefined) {
            throw ("Failed to create new player.");
        }

        _player.init(_intelligence, _supplies, _reproduction);

        /* Update map values dependent on player count */
        map_gold_morale_factor = 10 * 1024 * players.size();

        return _player.get_index();
    };

    /// Game::init(map_size, random) — builds the map with the mission generator.
    static init = function(_map_size, _random) {
        init_map_rnd = random_state_copy(_random);

        var _geom = new MapGeometry(_map_size);
        map = new Map(_geom);
        var _generator = new ClassicMissionMapGenerator(map, random_state_copy(init_map_rnd));
        _generator.init();
        _generator.generate();
        map.init_tiles(_generator);
        gold_total = map.get_gold_deposit();

        return true;
    };

    /* Cancel a resource being transported to destination. This
       ensures that the destination can request a new resource. */
    static cancel_transported_resource = function(_res, _dest) {
        if (_dest == 0) {
            return;
        }

        var _flag = flags.get(_dest);
        if (!_flag.has_building()) {
            throw ("Failed to cancel transported resource.");
        }
        var _building = _flag.get_building();
        _building.cancel_transported_resource(_res);
    };

    /* Called when a resource is lost forever from the game. This will
       update any global state keeping track of that resource. */
    static lose_resource = function(_res) {
        if (_res == ResourceType.gold_ore || _res == ResourceType.gold_bar) {
            add_gold_total(-1);
        }
    };

    static random_int = function() {
        return rnd.next_random();
    };

    static next_search_id = function() {
        flag_search_counter = (flag_search_counter + 1) & 0xFFFF;

        /* If we're back at zero the counter has overflown,
         everything needs a reset to be safe. */
        if (flag_search_counter == 0) {
            flag_search_counter = (flag_search_counter + 1) & 0xFFFF;
            clear_search_id();
        }

        return flag_search_counter;
    };

    /* ---------------------------------------------------------------- */
    /* Object creation / deletion                                        */
    /* ---------------------------------------------------------------- */

    static create_serf = function(_index = -1) {
        if (_index == undefined) {
            _index = -1;
        }
        if (_index == -1) {
            return serfs.allocate();
        } else {
            return serfs.get_or_insert(_index);
        }
    };

    static delete_serf = function(_serf) {
        /* The map holds a raw serf index per tile and nothing else clears it,
           so it has to be cleared here or the tile goes on pointing at a serf
           that is gone: has_serf() keeps saying true while get_serf_at_pos()
           returns undefined, and the next knight to walk past dies on it.

           Three callers never cleared it - building_deleted(), which kills the
           serfs inside a burning castle or stock, and two of the duel paths -
           so burning a castle left a booby-trapped tile behind.

           Only cleared when the tile still points at THIS serf:
           knight_attacking_free_wait deliberately hands its tile to the
           survivor just before deleting the loser, and that must not be undone.
           A serf that was never placed has pos = -1, which is not a tile. */
        var _index = _serf.get_index();
        var _pos = _serf.pos;
        if (map != undefined && _pos >= 0) {
            if (map.get_serf_index(_pos) == _index) {
                map.set_serf_index(_pos, 0);
            }

            /* pos and the map do not always agree. start_walking(dir, slope,
               false) advances pos while deliberately leaving the map alone -
               leave_building() and the knight free-fight join both do it - so a
               serf can be listed on the tile he just stepped off. That is
               always exactly one step away, so sweeping the six neighbours
               catches it without walking the whole map. */
            for (var _d = Direction.right; _d <= Direction.up; _d++) {
                var _n = map.move(_pos, _d);
                if (map.get_serf_index(_n) == _index) {
                    map.set_serf_index(_n, 0);
                }
            }
        }
        serfs.erase(_index);
    };

    static create_flag = function(_index = -1) {
        if (_index == undefined) {
            _index = -1;
        }
        if (_index == -1) {
            return flags.allocate();
        } else {
            return flags.get_or_insert(_index);
        }
    };

    static create_inventory = function(_index = -1) {
        if (_index == undefined) {
            _index = -1;
        }
        if (_index == -1) {
            return inventories.allocate();
        } else {
            return inventories.get_or_insert(_index);
        }
    };

    static delete_inventory = function(_inventory) {
        _inventory.destroy();   // C++ ~Inventory()
        inventories.erase(_inventory.get_index());
    };

    static create_building = function(_index = -1) {
        if (_index == undefined) {
            _index = -1;
        }
        if (_index == -1) {
            return buildings.allocate();
        } else {
            return buildings.get_or_insert(_index);
        }
    };

    static delete_building = function(_building) {
        /* Detach the flag first, because nothing else does it on this path.
           demolish_building_() unlinks when IT burns a building down, but a
           building that simply reaches the end of its own burn arrives here
           still linked - and then the flag outlives it, holding a pointer to a
           building that no longer exists and answering has_building() == true.
           The map object is cleared just below, so surrender_land's neighbour
           sweep finds nothing to demolish there and demolish_flag_() throws
           "Failed to demolish flag with building.". Burning a building and
           waiting out its 2047-tick burn was enough to arm that. */
        var _flag_index = _building.get_flag_index();
        if (_flag_index > 0) {
            var _flag = flags.get(_flag_index);
            if (_flag != undefined && _flag.has_building()) {
                _flag.unlink_building();
                _building.unlink_flag();
                flag_reset_transport(_flag);
            }
        }

        map.set_object(_building.get_position(), MapObject.none, 0);
        buildings.erase(_building.get_index());
    };

    /* ---------------------------------------------------------------- */
    /* List queries (C++ ListSerfs etc. -> GML arrays)                   */
    /* ---------------------------------------------------------------- */

    static get_player_serfs = function(_player) {
        var _player_serfs = [];

        for (var _i = 0; _i < array_length(serfs.objects); _i++) {
            var _serf = serfs.objects[_i];
            if (_serf != undefined) {
                if (_serf.get_owner() == _player.get_index()) {
                    array_push(_player_serfs, _serf);
                }
            }
        }

        return _player_serfs;
    };

    static get_player_buildings = function(_player) {
        var _player_buildings = [];

        for (var _i = 0; _i < array_length(buildings.objects); _i++) {
            var _building = buildings.objects[_i];
            if (_building != undefined) {
                if (_building.get_owner() == _player.get_index()) {
                    array_push(_player_buildings, _building);
                }
            }
        }

        return _player_buildings;
    };

    static get_player_inventories = function(_player) {
        var _player_inventories = [];

        for (var _i = 0; _i < array_length(inventories.objects); _i++) {
            var _inventory = inventories.objects[_i];
            if (_inventory != undefined) {
                if (_inventory.get_owner() == _player.get_index()) {
                    array_push(_player_inventories, _inventory);
                }
            }
        }

        return _player_inventories;
    };

    static get_serfs_at_pos = function(_pos) {
        var _result = [];

        for (var _i = 0; _i < array_length(serfs.objects); _i++) {
            var _serf = serfs.objects[_i];
            if (_serf != undefined) {
                if (_serf.get_pos() == _pos) {
                    array_push(_result, _serf);
                }
            }
        }

        return _result;
    };

    static get_serfs_in_inventory = function(_inventory) {
        var _result = [];

        for (var _i = 0; _i < array_length(serfs.objects); _i++) {
            var _serf = serfs.objects[_i];
            if (_serf != undefined) {
                if (_serf.get_state() == SerfState.idle_in_stock &&
                    _inventory.get_index() == _serf.get_idle_in_stock_inv_index()) {
                    array_push(_result, _serf);
                }
            }
        }

        return _result;
    };

    static get_serfs_related_to = function(_dest, _dir) {
        var _result = [];

        for (var _i = 0; _i < array_length(serfs.objects); _i++) {
            var _serf = serfs.objects[_i];
            if (_serf != undefined) {
                if (_serf.is_related_to(_dest, _dir)) {
                    array_push(_result, _serf);
                }
            }
        }

        return _result;
    };

    static get_next_player = function(_player) {
        /* Collection iteration skips free slots; find the player, then the
           next live one, wrapping around to the first. */
        var _live = players.to_array();
        var _p = 0;
        while (_live[_p] != _player) {
            _p += 1;
        }
        _p += 1;
        if (_p == array_length(_live)) {
            _p = 0;
        }

        return _live[_p];
    };

    static get_enemy_score = function(_player) {
        var _enemy_score = 0;

        for (var _i = 0; _i < array_length(players.objects); _i++) {
            var _p = players.objects[_i];
            if (_p != undefined) {
                if (_player.get_index() != _p.get_index()) {
                    _enemy_score += _p.get_total_military_score();
                }
            }
        }

        return _enemy_score;
    };

    static building_captured = function(_building) {
        /* Save amount of land and buildings for each player */
        var _land_before = array_create(array_length(players.objects), 0);
        var _buildings_before = array_create(array_length(players.objects), 0);
        for (var _i = 0; _i < array_length(players.objects); _i++) {
            var _player = players.objects[_i];
            if (_player != undefined) {
                _land_before[_player.get_index()] = _player.get_land_area();
                _buildings_before[_player.get_index()] = _player.get_building_score();
            }
        }

        /* Update land ownership */
        update_land_ownership(_building.get_position());

        /* Create notfications for lost land and buildings */
        for (var _i = 0; _i < array_length(players.objects); _i++) {
            var _player = players.objects[_i];
            if (_player != undefined) {
                if (_buildings_before[_player.get_index()] > _player.get_building_score()) {
                    _player.add_notification(MessageType.lost_buildings,
                                             _building.get_position(),
                                             _building.get_owner());
                } else if (_land_before[_player.get_index()] > _player.get_land_area()) {
                    _player.add_notification(MessageType.lost_land,
                                             _building.get_position(),
                                             _building.get_owner());
                }
            }
        }
    };

    static clear_search_id = function() {
        for (var _i = 0; _i < array_length(flags.objects); _i++) {
            var _flag = flags.objects[_i];
            if (_flag != undefined) {
                _flag.clear_search_id();
            }
        }
    };
}

/// @function SettlersGame()
/// @desc Alias kept for existing callers; identical to Game().
function SettlersGame() : Game() constructor {
}
