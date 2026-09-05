/// scr_serf_b.gml
/// Ported from Freeserf (GPL-3.0), original copyright (C) 2013-2018 Jon Lund Steffensen
/// and the Freeserf contributors. This file is part of a GML port of Freeserf and is
/// distributed under the GNU General Public License v3.0.
///
/// Ports src/serf.cc lines 2353-4282:
///   Serf::handle_serf_free_walking_state_dest_reached ... Serf::handle_serf_sampling_geo_spot_state
///
/// Every function here is a GLOBAL function named serf_<cpp_method_name>(_serf, ...)
/// where _serf is the Serf struct (defined in scr_serf.gml, part A). The C++ state
/// union `s` is one flattened struct: s.free_walking.dist_col -> _serf.s.free_walking_dist_col.
///
/// Assumptions about part A (scr_serf.gml):
///   - global.serf_counter_from_animation is the file-level counter_from_animation[] table.
///   - _serf.is_waiting() returns a struct { result: bool, dir: Direction } (C++ out-param).
///   - _serf.switch_waiting(dir), _serf.get_walking_animation(h_diff, dir, switch_pos),
///     _serf.start_walking(dir, slope, change_pos), _serf.drop_resource(res),
///     _serf.find_inventory(), _serf.set_state(state), _serf.set_lost_state(),
///     _serf.get_type(), _serf.get_owner(), _serf.get_index() exist with C++ names.
///   - enum MessageType (player.h Message::Type) provides found_gold/found_iron/found_coal/found_stone.

/// @function serf_b_init_tables()
/// @desc Builds the static tables used by this file (file-local const arrays in serf.cc).
function serf_b_init_tables() {
    if (variable_global_exists("serf_b_dir_from_offset")) {
        return;
    }

    /* dir_from_offset (used by follow_edge and free_walking_common) */
    global.serf_b_dir_from_offset = [
        Direction.up_left, Direction.up,   Direction.none,
        Direction.left,    Direction.none, Direction.right,
        Direction.none,    Direction.down, Direction.down_right
    ];

    /* Follow right-hand edge */
    global.serf_b_dir_right_edge = [
        Direction.down, Direction.down_right, Direction.right, Direction.up,
        Direction.up_left, Direction.left, Direction.left, Direction.down,
        Direction.down_right, Direction.right, Direction.up, Direction.up_left,
        Direction.up_left, Direction.left, Direction.down, Direction.down_right,
        Direction.right, Direction.up, Direction.up, Direction.up_left, Direction.left,
        Direction.down, Direction.down_right, Direction.right, Direction.right,
        Direction.up, Direction.up_left, Direction.left, Direction.down,
        Direction.down_right, Direction.down_right, Direction.right, Direction.up,
        Direction.up_left, Direction.left, Direction.down
    ];

    /* Follow left-hand edge */
    global.serf_b_dir_left_edge = [
        Direction.up_left, Direction.up, Direction.right, Direction.down_right,
        Direction.down, Direction.left, Direction.up, Direction.right,
        Direction.down_right, Direction.down, Direction.left, Direction.up_left,
        Direction.right, Direction.down_right, Direction.down, Direction.left,
        Direction.up_left, Direction.up, Direction.down_right, Direction.down,
        Direction.left, Direction.up_left, Direction.up, Direction.right, Direction.down,
        Direction.left, Direction.up_left, Direction.up, Direction.right,
        Direction.down_right, Direction.left, Direction.up_left, Direction.up,
        Direction.right, Direction.down_right, Direction.down
    ];

    /* Directions for moving forwards. Each of the 12 lines represents
       a general direction as shown in the diagram below.
       The lines list the local directions in order of preference for that
       general direction.

       *         1    0
       *    2   ________   11
       *       /\      /\
       *      /  \    /  \
       *  3  /    \  /    \  10
       *    /______\/______\
       *    \      /\      /
       *  4  \    /  \    /  9
       *      \  /    \  /
       *       \/______\/
       *    5             8
       *         6    7
       */
    global.serf_b_dir_forward = [
        Direction.up, Direction.up_left, Direction.right, Direction.left,
        Direction.down_right, Direction.down, Direction.up_left, Direction.up,
        Direction.left, Direction.right, Direction.down, Direction.down_right,
        Direction.up_left, Direction.left, Direction.up, Direction.down, Direction.right,
        Direction.down_right, Direction.left, Direction.up_left, Direction.down,
        Direction.up, Direction.down_right, Direction.right, Direction.left,
        Direction.down, Direction.up_left, Direction.down_right, Direction.up,
        Direction.right, Direction.down, Direction.left, Direction.down_right,
        Direction.up_left, Direction.right, Direction.up, Direction.down,
        Direction.down_right, Direction.left, Direction.right, Direction.up_left,
        Direction.up, Direction.down_right, Direction.down, Direction.right,
        Direction.left, Direction.up, Direction.up_left, Direction.down_right,
        Direction.right, Direction.down, Direction.up, Direction.left, Direction.up_left,
        Direction.right, Direction.down_right, Direction.up, Direction.down,
        Direction.up_left, Direction.left, Direction.right, Direction.up,
        Direction.down_right, Direction.up_left, Direction.down, Direction.left,
        Direction.up, Direction.right, Direction.up_left, Direction.down_right,
        Direction.left, Direction.down
    ];

    /* Hand resource to miner (handle_serf_mining_state) */
    global.serf_b_res_from_mine_type = [
        ResourceType.gold_ore, ResourceType.iron_ore,
        ResourceType.coal, ResourceType.stone
    ];

    /* When the serf is present there is also at least one
       pig present and at most eight. (handle_serf_pigfarming_state) */
    global.serf_b_breeding_prob = [
        6000, 8000, 10000, 11000, 12000, 13000, 14000, 0
    ];
}

/// @function serf_handle_serf_free_walking_state_dest_reached(_serf)
function serf_handle_serf_free_walking_state_dest_reached(_serf) {
    if (_serf.s.free_walking_neg_dist1 == -128 &&
        _serf.s.free_walking_neg_dist2 < 0) {
        _serf.find_inventory();
        return;
    }

    var _map = _serf.game.get_map();
    switch (_serf.get_type()) {
        case SerfType.lumberjack:
            if (_serf.s.free_walking_neg_dist1 == -128) {
                if (_serf.s.free_walking_neg_dist2 > 0) {
                    _serf.drop_resource(ResourceType.lumber);
                }

                _serf.set_state(SerfState.ready_to_enter);
                _serf.s.ready_to_enter_field_B = 0;
                _serf.counter = 0;
            } else {
                _serf.s.free_walking_dist_col = _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row = _serf.s.free_walking_neg_dist2;
                var _obj = _map.get_obj(_serf.pos);
                if (_obj >= MapObject.tree0 &&
                    _obj <= MapObject.pine7) {
                    _serf.set_state(SerfState.logging);
                    _serf.s.free_walking_neg_dist1 = 0;
                    _serf.s.free_walking_neg_dist2 = 0;
                    if (_obj < 16) {
                        _serf.s.free_walking_neg_dist1 = -1;
                    }
                    _serf.animation = 116;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                } else {
                    /* The expected tree is gone */
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                }
            }
            break;
        case SerfType.stonecutter:
            if (_serf.s.free_walking_neg_dist1 == -128) {
                if (_serf.s.free_walking_neg_dist2 > 0) {
                    _serf.drop_resource(ResourceType.stone);
                }

                _serf.set_state(SerfState.ready_to_enter);
                _serf.s.ready_to_enter_field_B = 0;
                _serf.counter = 0;
            } else {
                _serf.s.free_walking_dist_col = _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row = _serf.s.free_walking_neg_dist2;

                var _new_pos = _map.move_up_left(_serf.pos);
                var _obj = _map.get_obj(_new_pos);
                if (!_map.has_serf(_new_pos) &&
                    _obj >= MapObject.stone0 &&
                    _obj <= MapObject.stone7) {
                    _serf.counter = 0;
                    _serf.start_walking(Direction.up_left, 32, 1);

                    _serf.set_state(SerfState.stone_cutting);
                    _serf.s.free_walking_neg_dist2 = _serf.counter >> 2;
                    _serf.s.free_walking_neg_dist1 = 0;
                } else {
                    /* The expected stone is gone or unavailable */
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                }
            }
            break;
        case SerfType.forester:
            if (_serf.s.free_walking_neg_dist1 == -128) {
                _serf.set_state(SerfState.ready_to_enter);
                _serf.s.ready_to_enter_field_B = 0;
                _serf.counter = 0;
            } else {
                _serf.s.free_walking_dist_col = _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row = _serf.s.free_walking_neg_dist2;
                if (_map.get_obj(_serf.pos) == MapObject.none) {
                    _serf.set_state(SerfState.planting);
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.animation = 121;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                } else {
                    /* The expected free space is no longer empty */
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                }
            }
            break;
        case SerfType.fisher:
            if (_serf.s.free_walking_neg_dist1 == -128) {
                if (_serf.s.free_walking_neg_dist2 > 0) {
                    _serf.drop_resource(ResourceType.fish);
                }

                _serf.set_state(SerfState.ready_to_enter);
                _serf.s.ready_to_enter_field_B = 0;
                _serf.counter = 0;
            } else {
                _serf.s.free_walking_dist_col = _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row = _serf.s.free_walking_neg_dist2;

                var _a = -1;
                if (_map.get_paths(_serf.pos) == 0) {
                    if (_map.get_type_down(_serf.pos) <= Terrain.water3 &&
                        _map.get_type_up(_map.move_up_left(_serf.pos)) >= Terrain.grass0) {
                        _a = 132;
                    } else if (
                        _map.get_type_down(_map.move_left(_serf.pos)) <= Terrain.water3 &&
                        _map.get_type_up(_map.move_up(_serf.pos)) >= Terrain.grass0) {
                        _a = 131;
                    }
                }

                if (_a < 0) {
                    /* Cannot fish here after all. */
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                } else {
                    _serf.set_state(SerfState.fishing);
                    _serf.s.free_walking_neg_dist1 = 0;
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.s.free_walking_flags = 0;
                    _serf.animation = _a;
                    _serf.counter = global.serf_counter_from_animation[_a];
                }
            }
            break;
        case SerfType.farmer:
            if (_serf.s.free_walking_neg_dist1 == -128) {
                if (_serf.s.free_walking_neg_dist2 > 0) {
                    _serf.drop_resource(ResourceType.wheat);
                }

                _serf.set_state(SerfState.ready_to_enter);
                _serf.s.ready_to_enter_field_B = 0;
                _serf.counter = 0;
            } else {
                _serf.s.free_walking_dist_col = _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row = _serf.s.free_walking_neg_dist2;

                if (_map.get_obj(_serf.pos) == MapObject.seeds5 ||
                    (_map.get_obj(_serf.pos) >= MapObject.field0 &&
                     _map.get_obj(_serf.pos) <= MapObject.field5)) {
                    /* Existing field. */
                    _serf.animation = 136;
                    _serf.s.free_walking_neg_dist1 = 1;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                } else if (_map.get_obj(_serf.pos) == MapObject.none &&
                           _map.get_paths(_serf.pos) == 0) {
                    /* Empty space. */
                    _serf.animation = 135;
                    _serf.s.free_walking_neg_dist1 = 0;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                } else {
                    /* Space not available after all. */
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                    break;
                }

                _serf.set_state(SerfState.farming);
                _serf.s.free_walking_neg_dist2 = 0;
            }
            break;
        case SerfType.geologist:
            if (_serf.s.free_walking_neg_dist1 == -128) {
                if (_map.get_obj(_serf.pos) == MapObject.flag &&
                    _map.get_owner(_serf.pos) == _serf.get_owner()) {
                    _serf.set_state(SerfState.looking_for_geo_spot);
                    _serf.counter = 0;
                } else {
                    _serf.set_state(SerfState.lost);
                    _serf.s.lost_field_B = 0;
                    _serf.counter = 0;
                }
            } else {
                _serf.s.free_walking_dist_col = _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row = _serf.s.free_walking_neg_dist2;
                if (_map.get_obj(_serf.pos) == MapObject.none) {
                    _serf.set_state(SerfState.sampling_geo_spot);
                    _serf.s.free_walking_neg_dist1 = 0;
                    _serf.animation = 141;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                } else {
                    /* Destination is not a free space after all. */
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = 0;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                }
            }
            break;
        case SerfType.knight0:
        case SerfType.knight1:
        case SerfType.knight2:
        case SerfType.knight3:
        case SerfType.knight4:
            if (_serf.s.free_walking_neg_dist1 == -128) {
                _serf.find_inventory();
            } else {
                _serf.set_state(SerfState.knight_occupy_enemy_building);
                _serf.counter = 0;
            }
            break;
        default:
            _serf.find_inventory();
            break;
    }
}

/// @function serf_handle_serf_free_walking_switch_on_dir(_serf, _dir)
function serf_handle_serf_free_walking_switch_on_dir(_serf, _dir) {
    // A suitable direction has been found; walk.
    if (_dir < Direction.right) {
        throw ("Wrong direction.");
    }
    var _sign = -1;
    if (_dir < 3) {
        _sign = 1;
    }
    var _dx = 0;
    if ((_dir mod 3) < 2) {
        _dx = _sign;
    }
    var _dy = 0;
    if ((_dir mod 3) > 0) {
        _dy = _sign;
    }

    show_debug_message("serf: serf " + string(_serf.index) + ": free walking: dest " +
                       string(_serf.s.free_walking_dist_col) + ", " +
                       string(_serf.s.free_walking_dist_row) +
                       ", move " + string(_dx) + ", " + string(_dy));

    _serf.s.free_walking_dist_col -= _dx;
    _serf.s.free_walking_dist_row -= _dy;

    _serf.start_walking(_dir, 32, 1);

    if (_serf.s.free_walking_dist_col == 0 && _serf.s.free_walking_dist_row == 0) {
        /* Arriving to destination */
        _serf.s.free_walking_flags = (1 << 3);
    }
}

/// @function serf_handle_serf_free_walking_switch_with_other(_serf)
function serf_handle_serf_free_walking_switch_with_other(_serf) {
    /* No free position can be found. Switch with
       other serf. */
    var _new_pos = 0;
    var _dir = Direction.none;
    var _other_serf = undefined;
    var _map = _serf.game.get_map();
    for (var _i = 0; _i < 6; _i++) {
        _new_pos = _map.move(_serf.pos, _i);
        if (_map.has_serf(_new_pos)) {
            _other_serf = _serf.game.get_serf_at_pos(_new_pos);
            if (_other_serf == undefined) {
                continue;   /* tile pointed at a serf that is gone */
            }
            var _other_dir = Direction.none;

            /* is_waiting returns { result, dir } (C++ out-param) */
            var _w = _other_serf.is_waiting();
            _other_dir = _w.dir;
            if (_w.result &&
                _other_dir == reverse_direction(_i) &&
                _other_serf.switch_waiting(_other_dir)) {
                _dir = _i;
                break;
            }
        }
    }

    if (_dir > Direction.none) {
        var _sign = -1;
        if (_dir < 3) {
            _sign = 1;
        }
        var _dx = 0;
        if ((_dir mod 3) < 2) {
            _dx = _sign;
        }
        var _dy = 0;
        if ((_dir mod 3) > 0) {
            _dy = _sign;
        }

        show_debug_message("serf: free walking (switch): dest " +
                           string(_serf.s.free_walking_dist_col) + ", " +
                           string(_serf.s.free_walking_dist_row) + ", move " +
                           string(_dx) + ", " + string(_dy));

        _serf.s.free_walking_dist_col -= _dx;
        _serf.s.free_walking_dist_row -= _dy;

        if (_serf.s.free_walking_dist_col == 0 &&
            _serf.s.free_walking_dist_row == 0) {
            /* Arriving to destination */
            _serf.s.free_walking_flags = (1 << 3);
        }

        /* Switch with other serf. */
        _map.set_serf_index(_serf.pos, _other_serf.index);
        _map.set_serf_index(_new_pos, _serf.index);

        _other_serf.animation = _serf.get_walking_animation(_map.get_height(_serf.pos) -
                                                            _map.get_height(_other_serf.pos),
                                                            reverse_direction(_dir), 1);
        _serf.animation = _serf.get_walking_animation(_map.get_height(_new_pos) -
                                                      _map.get_height(_serf.pos),
                                                      _dir, 1);

        _other_serf.counter = global.serf_counter_from_animation[_other_serf.animation];
        _serf.counter = global.serf_counter_from_animation[_serf.animation];

        _other_serf.pos = _serf.pos;
        _serf.pos = _new_pos;
    } else {
        _serf.animation = 82;
        _serf.counter = global.serf_counter_from_animation[_serf.animation];
    }
}

/// @function serf_can_pass_map_pos(_serf, _test_pos)
function serf_can_pass_map_pos(_serf, _test_pos) {
    return global.map_space_from_obj[_serf.game.get_map().get_obj(_test_pos)] <=
           Space.semipassable;
}

/// @function serf_handle_free_walking_follow_edge(_serf)
function serf_handle_free_walking_follow_edge(_serf) {
    serf_b_init_tables();
    var _dir_from_offset = global.serf_b_dir_from_offset;
    var _dir_right_edge = global.serf_b_dir_right_edge;
    var _dir_left_edge = global.serf_b_dir_left_edge;

    var _water = 0;
    if (_serf.state == SerfState.free_sailing) {
        _water = 1;
    }
    var _dir_index = -1;
    var _dir_arr = undefined;

    if ((_serf.s.free_walking_flags & (1 << 3)) != 0) {
        /* Follow right-hand edge */
        _dir_arr = _dir_left_edge;
        _dir_index = (_serf.s.free_walking_flags & 7) - 1;
    } else {
        /* Follow right-hand edge */
        _dir_arr = _dir_right_edge;
        _dir_index = (_serf.s.free_walking_flags & 7) - 1;
    }

    var _d1 = _serf.s.free_walking_dist_col;
    var _d2 = _serf.s.free_walking_dist_row;

    /* Check if dest is only one step away. */
    if (!_water && abs(_d1) <= 1 && abs(_d2) <= 1 &&
        _dir_from_offset[(_d1 + 1) + 3 * (_d2 + 1)] > Direction.none) {
        /* Convert offset in two dimensions to
           direction variable. */
        var _dir = _dir_from_offset[(_d1 + 1) + 3 * (_d2 + 1)];
        var _new_pos = _serf.game.get_map().move(_serf.pos, _dir);

        if (!serf_can_pass_map_pos(_serf, _new_pos)) {
            if (_serf.state != SerfState.knight_free_walking &&
                _serf.s.free_walking_neg_dist1 != -128) {
                _serf.s.free_walking_dist_col += _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row += _serf.s.free_walking_neg_dist2;
                _serf.s.free_walking_neg_dist1 = 0;
                _serf.s.free_walking_neg_dist2 = 0;
                _serf.s.free_walking_flags = 0;
                _serf.animation = 82;
                _serf.counter = global.serf_counter_from_animation[_serf.animation];
            } else {
                _serf.set_state(SerfState.lost);
                _serf.s.lost_field_B = 0;
                _serf.counter = 0;
            }
            return 0;
        }

        if (_serf.state == SerfState.knight_free_walking &&
            _serf.s.free_walking_neg_dist1 != -128 &&
            _serf.game.get_map().has_serf(_new_pos)) {
            /* Wait for other serfs */
            _serf.s.free_walking_flags = 0;
            _serf.animation = 82;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            return 0;
        }
    }

    var _a0 = 6 * _dir_index; /* offset of a0 inside _dir_arr */
    var _i0 = Direction.none;
    var _dir = Direction.none;
    var _map = _serf.game.get_map();
    for (var _i = 0; _i < 6; _i++) {
        var _new_pos = _map.move(_serf.pos, _dir_arr[_a0 + _i]);
        if (((_water && _map.get_obj(_new_pos) == 0) ||
             (!_water && !_map.is_in_water(_new_pos) &&
              serf_can_pass_map_pos(_serf, _new_pos))) && !_map.has_serf(_new_pos)) {
            _dir = _dir_arr[_a0 + _i];
            _i0 = _i;
            break;
        }
    }

    if (_i0 > Direction.none) {
        var _upper = ((_serf.s.free_walking_flags >> 4) & 0xf) + _i0 - 2;
        if (_i0 < 2 && _upper < 0) {
            _serf.s.free_walking_flags = 0;
            serf_handle_serf_free_walking_switch_on_dir(_serf, _dir);
            return 0;
        } else if (_i0 > 2 && _upper > 15) {
            _serf.s.free_walking_flags = 0;
        } else {
            var _dir_index2 = _dir + 1;
            _serf.s.free_walking_flags = (_upper << 4) |
                                         (_serf.s.free_walking_flags & 0x8) | _dir_index2;
            serf_handle_serf_free_walking_switch_on_dir(_serf, _dir);
            return 0;
        }
    } else {
        var _dir_index3 = 0;
        _serf.s.free_walking_flags = (_serf.s.free_walking_flags & 0xf8) | _dir_index3;
        _serf.s.free_walking_flags &= ~(1 << 3);
        serf_handle_serf_free_walking_switch_with_other(_serf);
        return 0;
    }

    return -1;
}

/// @function serf_handle_free_walking_common(_serf)
function serf_handle_free_walking_common(_serf) {
    serf_b_init_tables();
    var _dir_from_offset = global.serf_b_dir_from_offset;
    var _dir_forward = global.serf_b_dir_forward;

    var _water = 0;
    if (_serf.state == SerfState.free_sailing) {
        _water = 1;
    }

    if ((_serf.s.free_walking_flags & (1 << 3)) != 0 &&
        (_serf.s.free_walking_flags & 7) == 0) {
        /* Destination reached */
        serf_handle_serf_free_walking_state_dest_reached(_serf);
        return;
    }

    if ((_serf.s.free_walking_flags & 7) != 0) {
        /* Obstacle encountered, follow along the edge */
        var _r = serf_handle_free_walking_follow_edge(_serf);
        if (_r >= 0) {
            return;
        }
    }

    /* Move fowards */
    var _dir_index = -1;
    var _d1 = _serf.s.free_walking_dist_col;
    var _d2 = _serf.s.free_walking_dist_row;
    if (_d1 < 0) {
        if (_d2 < 0) {
            if (-_d2 < -_d1) {
                if (-2 * _d2 < -_d1) {
                    _dir_index = 3;
                } else {
                    _dir_index = 2;
                }
            } else {
                if (-_d2 < -2 * _d1) {
                    _dir_index = 1;
                } else {
                    _dir_index = 0;
                }
            }
        } else {
            if (_d2 >= -_d1) {
                _dir_index = 5;
            } else {
                _dir_index = 4;
            }
        }
    } else {
        if (_d2 < 0) {
            if (-_d2 >= _d1) {
                _dir_index = 11;
            } else {
                _dir_index = 10;
            }
        } else {
            if (_d2 < _d1) {
                if (2 * _d2 < _d1) {
                    _dir_index = 9;
                } else {
                    _dir_index = 8;
                }
            } else {
                if (_d2 < 2 * _d1) {
                    _dir_index = 7;
                } else {
                    _dir_index = 6;
                }
            }
        }
    }

    /* Try to move directly in the preferred direction */
    var _a0 = 6 * _dir_index; /* offset of a0 inside _dir_forward */
    var _dir = _dir_forward[_a0 + 0];
    var _map = _serf.game.get_map();
    var _new_pos = _map.move(_serf.pos, _dir);
    if (((_water && _map.get_obj(_new_pos) == 0) ||
         (!_water && !_map.is_in_water(_new_pos) &&
          serf_can_pass_map_pos(_serf, _new_pos))) &&
        !_map.has_serf(_new_pos)) {
        serf_handle_serf_free_walking_switch_on_dir(_serf, _dir);
        return;
    }

    /* Check if dest is only one step away. */
    if (!_water && abs(_d1) <= 1 && abs(_d2) <= 1 &&
        _dir_from_offset[(_d1 + 1) + 3 * (_d2 + 1)] > Direction.none) {
        /* Convert offset in two dimensions to
           direction variable. */
        var _d = _dir_from_offset[(_d1 + 1) + 3 * (_d2 + 1)];
        var _new_pos2 = _map.move(_serf.pos, _d);

        if (!serf_can_pass_map_pos(_serf, _new_pos2)) {
            if (_serf.state != SerfState.knight_free_walking &&
                _serf.s.free_walking_neg_dist1 != -128) {
                _serf.s.free_walking_dist_col += _serf.s.free_walking_neg_dist1;
                _serf.s.free_walking_dist_row += _serf.s.free_walking_neg_dist2;
                _serf.s.free_walking_neg_dist1 = 0;
                _serf.s.free_walking_neg_dist2 = 0;
                _serf.s.free_walking_flags = 0;
            } else {
                _serf.set_state(SerfState.lost);
                _serf.s.lost_field_B = 0;
                _serf.counter = 0;
            }
            return;
        }

        if (_serf.state == SerfState.knight_free_walking &&
            _serf.s.free_walking_neg_dist1 != -128 &&
            _map.has_serf(_new_pos2)) {
            var _other_serf = _serf.game.get_serf_at_pos(_new_pos2);
            if (_other_serf == undefined) {
                continue;   /* tile pointed at a serf that is gone */
            }
            var _other_dir = Direction.none;

            /* is_waiting returns { result, dir } (C++ out-param) */
            var _w = _other_serf.is_waiting();
            _other_dir = _w.dir;
            if (_w.result &&
                (_other_dir == reverse_direction(_d) || _other_dir == Direction.none) &&
                _other_serf.switch_waiting(reverse_direction(_d))) {
                /* Do the switch */
                _other_serf.pos = _serf.pos;
                _map.set_serf_index(_other_serf.pos,
                                    _other_serf.get_index());
                _other_serf.animation =
                    _serf.get_walking_animation(_map.get_height(_other_serf.pos) -
                                                _map.get_height(_new_pos2),
                                                reverse_direction(_d), 1);
                _other_serf.counter = global.serf_counter_from_animation[_other_serf.animation];

                _serf.animation = _serf.get_walking_animation(_map.get_height(_new_pos2) -
                                                              _map.get_height(_serf.pos), _d, 1);
                _serf.counter = global.serf_counter_from_animation[_serf.animation];

                _serf.pos = _new_pos2;
                _map.set_serf_index(_serf.pos, _serf.index);
                return;
            }

            if (_other_serf.state == SerfState.walking ||
                _other_serf.state == SerfState.transporting) {
                _serf.s.free_walking_neg_dist2 += 1;
                if (_serf.s.free_walking_neg_dist2 >= 10) {
                    _serf.s.free_walking_neg_dist2 = 0;
                    if (_other_serf.state == SerfState.transporting) {
                        if (_map.has_flag(_new_pos2)) {
                            if (_other_serf.s.walking_wait_counter != -1) {
                                // int dir = other_serf->s.walking.dir;
                                // if (dir < 0) dir += 6;
                                show_debug_message("serf: TODO remove " +
                                                   string(_other_serf.get_index()) +
                                                   " from path");
                            }
                            _other_serf.set_lost_state();
                        }
                    } else {
                        _other_serf.set_lost_state();
                    }
                }
            }

            _serf.animation = 82;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            return;
        }
    }

    /* Look for another direction to go in. */
    var _i0 = Direction.none;
    for (var _i = 0; _i < 5; _i++) {
        _dir = _dir_forward[_a0 + 1 + _i];
        var _new_pos3 = _map.move(_serf.pos, _dir);
        if (((_water && _map.get_obj(_new_pos3) == 0) ||
             (!_water && !_map.is_in_water(_new_pos3) &&
              serf_can_pass_map_pos(_serf, _new_pos3))) && !_map.has_serf(_new_pos3)) {
            _i0 = _i;
            break;
        }
    }

    if (_i0 < 0) {
        serf_handle_serf_free_walking_switch_with_other(_serf);
        return;
    }

    var _edge = 0;
    if (((_dir_index ^ _i0) & (1 << 0)) != 0) {
        _edge = 1;
    }
    var _upper = (_i0 div 2) + 1;

    _serf.s.free_walking_flags = (_upper << 4) | (_edge << 3) | (_dir + 1);

    serf_handle_serf_free_walking_switch_on_dir(_serf, _dir);
}

/// @function serf_handle_serf_free_walking_state(_serf)
function serf_handle_serf_free_walking_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    while (_serf.counter < 0) {
        serf_handle_free_walking_common(_serf);
    }
}

/// @function serf_handle_serf_logging_state(_serf)
function serf_handle_serf_logging_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    while (_serf.counter < 0) {
        _serf.s.free_walking_neg_dist2 += 1;

        var _new_obj = -1;
        if (_serf.s.free_walking_neg_dist1 != 0) {
            _new_obj = MapObject.felled_tree0 + _serf.s.free_walking_neg_dist2 - 1;
        } else {
            _new_obj = MapObject.felled_pine0 + _serf.s.free_walking_neg_dist2 - 1;
        }

        /* Change map object. */
        _serf.game.get_map().set_object(_serf.pos, _new_obj, -1);

        if (_serf.s.free_walking_neg_dist2 < 5) {
            _serf.animation = 116 + _serf.s.free_walking_neg_dist2;
            _serf.counter += global.serf_counter_from_animation[_serf.animation];
        } else {
            _serf.set_state(SerfState.free_walking);
            _serf.counter = 0;
            _serf.s.free_walking_neg_dist1 = -128;
            _serf.s.free_walking_neg_dist2 = 1;
            _serf.s.free_walking_flags = 0;
            return;
        }
    }
}

/// @function serf_handle_serf_planning_logging_state(_serf)
function serf_handle_serf_planning_logging_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    while (_serf.counter < 0) {
        var _dist = (_serf.game.random_int() & 0x7f) + 1;
        var _pos_ = _serf.game.get_map().pos_add_spirally(_serf.pos, _dist);
        var _obj = _serf.game.get_map().get_obj(_pos_);
        if (_obj >= MapObject.tree0 && _obj <= MapObject.pine7) {
            var _sp = map_get_spiral_pattern();
            _serf.set_state(SerfState.ready_to_leave);
            _serf.s.leaving_building_field_B = _sp[2 * _dist] - 1;
            _serf.s.leaving_building_dest = _sp[2 * _dist + 1] - 1;
            _serf.s.leaving_building_dest2 = -_sp[2 * _dist] + 1;
            _serf.s.leaving_building_dir = -_sp[2 * _dist + 1] + 1;
            _serf.s.leaving_building_next_state = SerfState.free_walking;
            show_debug_message("serf: planning logging: tree found, dist " +
                               string(_serf.s.leaving_building_field_B) + ", " +
                               string(_serf.s.leaving_building_dest) + ".");
            return;
        }

        _serf.counter += 400;
    }
}

/// @function serf_handle_serf_planning_planting_state(_serf)
function serf_handle_serf_planning_planting_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        var _dist = (_serf.game.random_int() & 0x7f) + 1;
        var _pos_ = _map.pos_add_spirally(_serf.pos, _dist);
        if (_map.get_paths(_pos_) == 0 &&
            _map.get_obj(_pos_) == MapObject.none &&
            _map.get_type_up(_pos_) == Terrain.grass1 &&
            _map.get_type_down(_pos_) == Terrain.grass1 &&
            _map.get_type_up(_map.move_up_left(_pos_)) == Terrain.grass1 &&
            _map.get_type_down(_map.move_up_left(_pos_)) == Terrain.grass1) {
            var _sp = map_get_spiral_pattern();
            _serf.set_state(SerfState.ready_to_leave);
            _serf.s.leaving_building_field_B = _sp[2 * _dist] - 1;
            _serf.s.leaving_building_dest = _sp[2 * _dist + 1] - 1;
            _serf.s.leaving_building_dest2 = -_sp[2 * _dist] + 1;
            _serf.s.leaving_building_dir = -_sp[2 * _dist + 1] + 1;
            _serf.s.leaving_building_next_state = SerfState.free_walking;
            show_debug_message("serf: planning planting: free space found, dist " +
                               string(_serf.s.leaving_building_field_B) + ", " +
                               string(_serf.s.leaving_building_dest) + ".");
            return;
        }

        _serf.counter += 700;
    }
}

/// @function serf_handle_serf_planting_state(_serf)
function serf_handle_serf_planting_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        if (_serf.s.free_walking_neg_dist2 != 0) {
            _serf.set_state(SerfState.free_walking);
            _serf.s.free_walking_neg_dist1 = -128;
            _serf.s.free_walking_neg_dist2 = 0;
            _serf.s.free_walking_flags = 0;
            _serf.counter = 0;
            return;
        }

        /* Plant a tree */
        _serf.animation = 122;
        var _new_obj = MapObject.new_pine + (_serf.game.random_int() & 1);

        if (_map.get_paths(_serf.pos) == 0 && _map.get_obj(_serf.pos) == MapObject.none) {
            _map.set_object(_serf.pos, _new_obj, -1);
        }

        _serf.s.free_walking_neg_dist2 = -_serf.s.free_walking_neg_dist2 - 1;
        _serf.counter += 128;
    }
}

/// @function serf_handle_serf_planning_stonecutting(_serf)
function serf_handle_serf_planning_stonecutting(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        var _dist = (_serf.game.random_int() & 0x7f) + 1;
        var _pos_ = _map.pos_add_spirally(_serf.pos, _dist);
        var _obj = _map.get_obj(_map.move_up_left(_pos_));
        if (_obj >= MapObject.stone0 && _obj <= MapObject.stone7 &&
            serf_can_pass_map_pos(_serf, _pos_)) {
            var _sp = map_get_spiral_pattern();
            _serf.set_state(SerfState.ready_to_leave);
            _serf.s.leaving_building_field_B = _sp[2 * _dist] - 1;
            _serf.s.leaving_building_dest = _sp[2 * _dist + 1] - 1;
            _serf.s.leaving_building_dest2 = -_sp[2 * _dist] + 1;
            _serf.s.leaving_building_dir = -_sp[2 * _dist + 1] + 1;
            _serf.s.leaving_building_next_state = SerfState.stone_cutter_free_walking;
            show_debug_message("serf: planning stonecutting: stone found, dist " +
                               string(_serf.s.leaving_building_field_B) + ", " +
                               string(_serf.s.leaving_building_dest) + ".");
            return;
        }

        _serf.counter += 100;
    }
}

/// @function serf_handle_stonecutter_free_walking(_serf)
function serf_handle_stonecutter_free_walking(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        var _pos_ = _map.move_up_left(_serf.pos);
        if (!_map.has_serf(_serf.pos) && _map.get_obj(_pos_) >= MapObject.stone0 &&
            _map.get_obj(_pos_) <= MapObject.stone7) {
            _serf.s.free_walking_neg_dist1 += _serf.s.free_walking_dist_col;
            _serf.s.free_walking_neg_dist2 += _serf.s.free_walking_dist_row;
            _serf.s.free_walking_dist_col = 0;
            _serf.s.free_walking_dist_row = 0;
            _serf.s.free_walking_flags = 8;
        }

        serf_handle_free_walking_common(_serf);
    }
}

/// @function serf_handle_serf_stonecutting_state(_serf)
function serf_handle_serf_stonecutting_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    if (_serf.s.free_walking_neg_dist1 == 0) {
        if (_serf.counter > _serf.s.free_walking_neg_dist2) {
            return;
        }
        _serf.counter -= _serf.s.free_walking_neg_dist2 + 1;
        _serf.s.free_walking_neg_dist1 = 1;
        _serf.animation = 123;
        _serf.counter += 1536;
    }

    while (_serf.counter < 0) {
        if (_serf.s.free_walking_neg_dist1 != 1) {
            _serf.set_state(SerfState.free_walking);
            _serf.s.free_walking_neg_dist1 = -128;
            _serf.s.free_walking_neg_dist2 = 1;
            _serf.s.free_walking_flags = 0;
            _serf.counter = 0;
            return;
        }

        var _map = _serf.game.get_map();
        if (_map.has_serf(_map.move_down_right(_serf.pos))) {
            _serf.counter = 0;
            return;
        }

        /* Decrement stone quantity or remove entirely if this
           was the last piece. */
        var _obj = _map.get_obj(_serf.pos);
        if (_obj <= MapObject.stone6) {
            _map.set_object(_serf.pos, _obj + 1, -1);
        } else {
            _map.set_object(_serf.pos, MapObject.none, -1);
        }

        _serf.counter = 0;
        _serf.start_walking(Direction.down_right, 24, 1);
        _serf.tick = _serf.game.get_tick();

        _serf.s.free_walking_neg_dist1 = 2;
    }
}

/// @function serf_handle_serf_sawing_state(_serf)
function serf_handle_serf_sawing_state(_serf) {
    if (_serf.s.sawing_mode == 0) {
        var _building =
            _serf.game.get_building(_serf.game.get_map().get_obj_index(_serf.pos));
        if (_building.use_resource_in_stock(1)) {
            _serf.s.sawing_mode = 1;
            _serf.animation = 124;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            _serf.tick = _serf.game.get_tick();
            _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        }
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        if (_serf.counter >= 0) {
            return;
        }

        _serf.game.get_map().set_serf_index(_serf.pos, 0);
        _serf.set_state(SerfState.move_resource_out);
        _serf.s.move_resource_out_res = 1 + ResourceType.plank;
        _serf.s.move_resource_out_res_dest = 0;
        _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

        /* Update resource stats. */
        var _player = _serf.game.get_player(_serf.get_owner());
        _player.increase_res_count(ResourceType.plank);
    }
}

/// @function serf_handle_serf_lost_state(_serf)
function serf_handle_serf_lost_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        /* Try to find a suitable destination. */
        for (var _i = 0; _i < 258; _i++) {
            var _dist = 258 - _i;
            if (_serf.s.lost_field_B == 0) {
                _dist = 1 + _i;
            }
            var _dest = _map.pos_add_spirally(_serf.pos, _dist);

            if (_map.has_flag(_dest)) {
                var _flag = _serf.game.get_flag(_map.get_obj_index(_dest));
                if ((_flag.land_paths() != 0 ||
                     (_flag.has_inventory() && _flag.accepts_serfs())) &&
                    _map.has_owner(_dest) &&
                    _map.get_owner(_dest) == _serf.get_owner()) {
                    if (_serf.get_type() >= SerfType.knight0 &&
                        _serf.get_type() <= SerfType.knight4) {
                        _serf.set_state(SerfState.knight_free_walking);
                    } else {
                        _serf.set_state(SerfState.free_walking);
                    }

                    var _sp = map_get_spiral_pattern();
                    _serf.s.free_walking_dist_col = _sp[2 * _dist];
                    _serf.s.free_walking_dist_row = _sp[2 * _dist + 1];
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = -1;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                    return;
                }
            }
        }

        /* Choose a random destination */
        var _size = 16;
        var _tries = 10;

        while (true) {
            _tries -= 1;
            if (_tries < 0) {
                if (_size < 64) {
                    _tries = 19;
                    _size *= 2;
                } else {
                    _tries = -1;
                    _size = 16;
                }
            }

            var _r = _serf.game.random_int();
            var _col = ((_r & (_size - 1)) - (_size div 2));
            var _row = (((_r >> 8) & (_size - 1)) - (_size div 2));

            var _dest2 = _map.pos_add(_serf.pos, _col, _row);
            if ((_map.get_obj(_dest2) == 0 && _map.get_height(_dest2) > 0) ||
                (_map.has_flag(_dest2) &&
                 (_map.has_owner(_dest2) &&
                  _map.get_owner(_dest2) == _serf.get_owner()))) {
                if (_serf.get_type() >= SerfType.knight0 &&
                    _serf.get_type() <= SerfType.knight4) {
                    _serf.set_state(SerfState.knight_free_walking);
                } else {
                    _serf.set_state(SerfState.free_walking);
                }

                _serf.s.free_walking_dist_col = _col;
                _serf.s.free_walking_dist_row = _row;
                _serf.s.free_walking_neg_dist1 = -128;
                _serf.s.free_walking_neg_dist2 = -1;
                _serf.s.free_walking_flags = 0;
                _serf.counter = 0;
                return;
            }
        }
    }
}

/// @function serf_handle_lost_sailor(_serf)
function serf_handle_lost_sailor(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        /* Try to find a suitable destination. */
        for (var _i = 0; _i < 258; _i++) {
            var _dest = _map.pos_add_spirally(_serf.pos, _i);

            if (_map.has_flag(_dest)) {
                var _flag = _serf.game.get_flag(_map.get_obj_index(_dest));
                if (_flag.land_paths() != 0 &&
                    _map.has_owner(_dest) &&
                    _map.get_owner(_dest) == _serf.get_owner()) {
                    _serf.set_state(SerfState.free_sailing);

                    var _sp = map_get_spiral_pattern();
                    _serf.s.free_walking_dist_col = _sp[2 * _i];
                    _serf.s.free_walking_dist_row = _sp[2 * _i + 1];
                    _serf.s.free_walking_neg_dist1 = -128;
                    _serf.s.free_walking_neg_dist2 = -1;
                    _serf.s.free_walking_flags = 0;
                    _serf.counter = 0;
                    return;
                }
            }
        }

        /* Choose a random, empty destination */
        while (true) {
            var _r = _serf.game.random_int();
            var _col = (_r & 0x1f) - 16;
            var _row = ((_r >> 8) & 0x1f) - 16;

            var _dest2 = _map.pos_add(_serf.pos, _col, _row);
            if (_map.get_obj(_dest2) == 0) {
                _serf.set_state(SerfState.free_sailing);

                _serf.s.free_walking_dist_col = _col;
                _serf.s.free_walking_dist_row = _row;
                _serf.s.free_walking_neg_dist1 = -128;
                _serf.s.free_walking_neg_dist2 = -1;
                _serf.s.free_walking_flags = 0;
                _serf.counter = 0;
                return;
            }
        }
    }
}

/// @function serf_handle_free_sailing(_serf)
function serf_handle_free_sailing(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    while (_serf.counter < 0) {
        if (!_serf.game.get_map().is_in_water(_serf.pos)) {
            _serf.set_state(SerfState.lost);
            _serf.s.lost_field_B = 0;
            return;
        }

        serf_handle_free_walking_common(_serf);
    }
}

/// @function serf_handle_serf_escape_building_state(_serf)
function serf_handle_serf_escape_building_state(_serf) {
    if (!_serf.game.get_map().has_serf(_serf.pos)) {
        _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        _serf.animation = 82;
        _serf.counter = 0;
        _serf.tick = _serf.game.get_tick();

        _serf.set_state(SerfState.lost);
        _serf.s.lost_field_B = 0;
    }
}

/// @function serf_handle_serf_mining_state(_serf)
function serf_handle_serf_mining_state(_serf) {
    serf_b_init_tables();

    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        var _building = _serf.game.get_building(_map.get_obj_index(_serf.pos));

        show_debug_message("serf: mining substate: " + string(_serf.s.mining_substate) + ".");
        switch (_serf.s.mining_substate) {
            case 0: {
                /* There is a small chance that the miner will
                   not require food and skip to state 2. */
                var _r = _serf.game.random_int();
                if ((_r & 7) == 0) {
                    _serf.s.mining_substate = 2;
                } else {
                    _serf.s.mining_substate = 1;
                }
                _serf.counter += 100 + (_r & 0x1ff);
                break;
            }
            case 1:
                if (_building.use_resource_in_stock(0)) {
                    /* Eat the food. */
                    _serf.s.mining_substate = 3;
                    _map.set_serf_index(_serf.pos, _serf.index);
                    _serf.animation = 125;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                } else {
                    _map.set_serf_index(_serf.pos, _serf.index);
                    _serf.animation = 98;
                    _serf.counter += 256;
                    if (_serf.counter < 0) {
                        _serf.counter = 255;
                    }
                }
                break;
            case 2:
                _serf.s.mining_substate = 3;
                _map.set_serf_index(_serf.pos, _serf.index);
                _serf.animation = 125;
                _serf.counter = global.serf_counter_from_animation[_serf.animation];
                break;
            case 3:
                _serf.s.mining_substate = 4;
                _building.stop_activity();
                _serf.animation = 126;
                _serf.counter = global.serf_counter_from_animation[_serf.animation];
                break;
            case 4: {
                _building.start_playing_sfx();
                _map.set_serf_index(_serf.pos, 0);
                /* fall through */
            }
            case 5:
            case 6:
            case 7: {
                _serf.s.mining_substate += 1;

                /* Look for resource in ground. */
                var _dest = _map.pos_add_spirally(_serf.pos,
                                                  (_serf.game.random_int() >> 2) & 0x1f);
                if ((_map.get_obj(_dest) == MapObject.none ||
                     _map.get_obj(_dest) > MapObject.castle) &&
                    _map.get_res_type(_dest) == _serf.s.mining_deposit &&
                    _map.get_res_amount(_dest) > 0) {
                    /* Decrement resource count in ground. */
                    _map.remove_ground_deposit(_dest, 1);

                    /* Hand resource to miner. */
                    _serf.s.mining_res =
                        global.serf_b_res_from_mine_type[_serf.s.mining_deposit - 1] + 1;
                    _serf.s.mining_substate = 8;
                }

                _serf.counter += 1000;
                break;
            }
            case 8:
                _map.set_serf_index(_serf.pos, _serf.index);
                _serf.s.mining_substate = 9;
                _building.stop_playing_sfx();
                _serf.animation = 127;
                _serf.counter = global.serf_counter_from_animation[_serf.animation];
                break;
            case 9:
                _serf.s.mining_substate = 10;
                _building.increase_mining(_serf.s.mining_res);
                _serf.animation = 128;
                _serf.counter = global.serf_counter_from_animation[_serf.animation];
                break;
            case 10:
                _map.set_serf_index(_serf.pos, 0);
                if (_serf.s.mining_res == 0) {
                    _serf.s.mining_substate = 0;
                    _serf.counter = 0;
                } else {
                    var _res = _serf.s.mining_res;
                    _map.set_serf_index(_serf.pos, 0);

                    _serf.set_state(SerfState.move_resource_out);
                    _serf.s.move_resource_out_res = _res;
                    _serf.s.move_resource_out_res_dest = 0;
                    _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                    /* Update resource stats. */
                    var _player = _serf.game.get_player(_serf.get_owner());
                    _player.increase_res_count(_res - 1);
                    return;
                }
                break;
            default:
                throw ("NOT_REACHED: serf mining substate");
                break;
        }
    }
}

/// @function serf_handle_serf_smelting_state(_serf)
function serf_handle_serf_smelting_state(_serf) {
    var _building = _serf.game.get_building(_serf.game.get_map().get_obj_index(_serf.pos));

    if (_serf.s.smelting_mode == 0) {
        if (_building.use_resources_in_stocks()) {
            _building.start_activity();

            _serf.s.smelting_mode = 1;
            if (_serf.s.smelting_type == 0) {
                _serf.animation = 130;
            } else {
                _serf.animation = 129;
            }
            _serf.s.smelting_counter = 20;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            _serf.tick = _serf.game.get_tick();

            _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        }
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        while (_serf.counter < 0) {
            _serf.s.smelting_counter -= 1;
            if (_serf.s.smelting_counter < 0) {
                _building.stop_activity();

                var _res = -1;
                if (_serf.s.smelting_type == 0) {
                    _res = 1 + ResourceType.steel;
                } else {
                    _res = 1 + ResourceType.gold_bar;
                }

                _serf.set_state(SerfState.move_resource_out);

                _serf.s.move_resource_out_res = _res;
                _serf.s.move_resource_out_res_dest = 0;
                _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                /* Update resource stats. */
                var _player = _serf.game.get_player(_serf.get_owner());
                _player.increase_res_count(_res - 1);
                return;
            } else if (_serf.s.smelting_counter == 0) {
                _serf.game.get_map().set_serf_index(_serf.pos, 0);
            }

            _serf.counter += 384;
        }
    }
}

/// @function serf_handle_serf_planning_fishing_state(_serf)
function serf_handle_serf_planning_fishing_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        var _dist = ((_serf.game.random_int() >> 2) & 0x3f) + 1;
        var _dest = _map.pos_add_spirally(_serf.pos, _dist);

        if (_map.get_obj(_dest) == MapObject.none &&
            _map.get_paths(_dest) == 0 &&
            ((_map.get_type_down(_dest) <= Terrain.water3 &&
              _map.get_type_up(_map.move_up_left(_dest)) >= Terrain.grass0) ||
             (_map.get_type_down(_map.move_left(_dest)) <= Terrain.water3 &&
              _map.get_type_up(_map.move_up(_dest)) >= Terrain.grass0))) {
            var _sp = map_get_spiral_pattern();
            _serf.set_state(SerfState.ready_to_leave);
            _serf.s.leaving_building_field_B = _sp[2 * _dist] - 1;
            _serf.s.leaving_building_dest = _sp[2 * _dist + 1] - 1;
            _serf.s.leaving_building_dest2 = -_sp[2 * _dist] + 1;
            _serf.s.leaving_building_dir = -_sp[2 * _dist + 1] + 1;
            _serf.s.leaving_building_next_state = SerfState.free_walking;
            show_debug_message("serf: planning fishing: lake found, dist " +
                               string(_serf.s.leaving_building_field_B) + "," +
                               string(_serf.s.leaving_building_dest));
            return;
        }

        _serf.counter += 100;
    }
}

/// @function serf_handle_serf_fishing_state(_serf)
function serf_handle_serf_fishing_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    while (_serf.counter < 0) {
        if (_serf.s.free_walking_neg_dist2 != 0 ||
            _serf.s.free_walking_flags == 10) {
            /* Stop fishing. Walk back. */
            _serf.set_state(SerfState.free_walking);
            _serf.s.free_walking_neg_dist1 = -128;
            _serf.s.free_walking_flags = 0;
            _serf.counter = 0;
            return;
        }

        _serf.s.free_walking_neg_dist1 += 1;
        if ((_serf.s.free_walking_neg_dist1 mod 2) == 0) {
            _serf.animation -= 2;
            _serf.counter += 768;
            continue;
        }

        var _map = _serf.game.get_map();
        var _dir = Direction.none;
        if (_serf.animation == 131) {
            if (_map.is_in_water(_map.move_left(_serf.pos))) {
                _dir = Direction.left;
            } else {
                _dir = Direction.down;
            }
        } else {
            if (_map.is_in_water(_map.move_right(_serf.pos))) {
                _dir = Direction.right;
            } else {
                _dir = Direction.down_right;
            }
        }

        var _res = _map.get_res_fish(_map.move(_serf.pos, _dir));
        if (_res > 0 && (_serf.game.random_int() & 0x3f) + 4 < _res) {
            /* Caught a fish. */
            _map.remove_fish(_map.move(_serf.pos, _dir), 1);
            _serf.s.free_walking_neg_dist2 = 1 + ResourceType.fish;
        }

        _serf.s.free_walking_flags += 1;
        _serf.animation += 2;
        _serf.counter += 128;
    }
}

/// @function serf_handle_serf_planning_farming_state(_serf)
function serf_handle_serf_planning_farming_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;
    if (_serf.counter > 0) {
        return;
    }

    var _map = _serf.game.get_map();
    while (true) {
        var _dist = ((_serf.game.random_int() >> 2) & 0x1f) + 7;
        var _dest = _map.pos_add_spirally(_serf.pos, _dist);

        /* If destination doesn't have an object it must be
           of the correct type and the surrounding spaces
           must not be occupied by large buildings.
           If it _has_ an object it must be an existing field. */
        if ((_map.get_obj(_dest) == MapObject.none &&
             (_map.get_type_up(_dest) == Terrain.grass1 &&
              _map.get_type_down(_dest) == Terrain.grass1 &&
              _map.get_paths(_dest) == 0 &&
              _map.get_obj(_map.move_right(_dest)) != MapObject.large_building &&
              _map.get_obj(_map.move_right(_dest)) != MapObject.castle &&
              _map.get_obj(_map.move_down_right(_dest)) != MapObject.large_building &&
              _map.get_obj(_map.move_down_right(_dest)) != MapObject.castle &&
              _map.get_obj(_map.move_down(_dest)) != MapObject.large_building &&
              _map.get_obj(_map.move_down(_dest)) != MapObject.castle &&
              _map.get_type_down(_map.move_left(_dest)) == Terrain.grass1 &&
              _map.get_obj(_map.move_left(_dest)) != MapObject.large_building &&
              _map.get_obj(_map.move_left(_dest)) != MapObject.castle &&
              _map.get_type_up(_map.move_up_left(_dest)) == Terrain.grass1 &&
              _map.get_type_down(_map.move_up_left(_dest)) == Terrain.grass1 &&
              _map.get_obj(_map.move_up_left(_dest)) != MapObject.large_building &&
              _map.get_obj(_map.move_up_left(_dest)) != MapObject.castle &&
              _map.get_type_up(_map.move_up(_dest)) == Terrain.grass1 &&
              _map.get_obj(_map.move_up(_dest)) != MapObject.large_building &&
              _map.get_obj(_map.move_up(_dest)) != MapObject.castle)) ||
            _map.get_obj(_dest) == MapObject.seeds5 ||
            (_map.get_obj(_dest) >= MapObject.field0 &&
             _map.get_obj(_dest) <= MapObject.field5)) {
            var _sp = map_get_spiral_pattern();
            _serf.set_state(SerfState.ready_to_leave);
            _serf.s.leaving_building_field_B = _sp[2 * _dist] - 1;
            _serf.s.leaving_building_dest = _sp[2 * _dist + 1] - 1;
            _serf.s.leaving_building_dest2 = -_sp[2 * _dist] + 1;
            _serf.s.leaving_building_dir = -_sp[2 * _dist + 1] + 1;
            _serf.s.leaving_building_next_state = SerfState.free_walking;
            show_debug_message("serf: planning farming: field spot found, dist " +
                               string(_serf.s.leaving_building_field_B) + ", " +
                               string(_serf.s.leaving_building_dest) + ".");
            return;
        }

        _serf.counter += 500;
        if (_serf.counter >= 65500) {
            return;
        }
    }
}

/// @function serf_handle_serf_farming_state(_serf)
function serf_handle_serf_farming_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    if (_serf.counter >= 0) {
        return;
    }

    var _map = _serf.game.get_map();
    var _object = _map.get_obj(_serf.pos);
    if (_serf.s.free_walking_neg_dist1 == 0) {
        // Sowing
        if (_object == MapObject.none && _map.get_paths(_serf.pos) == 0) {
            _map.set_object(_serf.pos, MapObject.seeds0, -1);
        }
    } else {
        // Harvesting
        _serf.s.free_walking_neg_dist2 = 1;
        _object = _object + 1;
        if (_object == MapObject.field_expired) {
            _object = MapObject.field0;
        } else if (_object == MapObject.sign_large_gold || _object == MapObject.object127) {
            _object = MapObject.field_expired;
        }
        _map.set_object(_serf.pos, _object, -1);
    }

    _serf.set_state(SerfState.free_walking);
    _serf.s.free_walking_neg_dist1 = -128;
    _serf.s.free_walking_flags = 0;
    _serf.counter = 0;
}

/// @function serf_handle_serf_milling_state(_serf)
function serf_handle_serf_milling_state(_serf) {
    var _building = _serf.game.get_building(_serf.game.get_map().get_obj_index(_serf.pos));

    if (_serf.s.milling_mode == 0) {
        if (_building.use_resource_in_stock(0)) {
            _building.start_activity();

            _serf.s.milling_mode = 1;
            _serf.animation = 137;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            _serf.tick = _serf.game.get_tick();

            _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        }
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        while (_serf.counter < 0) {
            _serf.s.milling_mode += 1;
            if (_serf.s.milling_mode == 5) {
                /* Done milling. */
                _building.stop_activity();
                _serf.set_state(SerfState.move_resource_out);
                _serf.s.move_resource_out_res = 1 + ResourceType.flour;
                _serf.s.move_resource_out_res_dest = 0;
                _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                var _player = _serf.game.get_player(_serf.get_owner());
                _player.increase_res_count(ResourceType.flour);
                return;
            } else if (_serf.s.milling_mode == 3) {
                _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
                _serf.animation = 137;
                _serf.counter = global.serf_counter_from_animation[_serf.animation];
            } else {
                _serf.game.get_map().set_serf_index(_serf.pos, 0);
                _serf.counter += 1500;
            }
        }
    }
}

/// @function serf_handle_serf_baking_state(_serf)
function serf_handle_serf_baking_state(_serf) {
    var _building = _serf.game.get_building(_serf.game.get_map().get_obj_index(_serf.pos));

    if (_serf.s.baking_mode == 0) {
        if (_building.use_resource_in_stock(0)) {
            _serf.s.baking_mode = 1;
            _serf.animation = 138;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            _serf.tick = _serf.game.get_tick();

            _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        }
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        while (_serf.counter < 0) {
            _serf.s.baking_mode += 1;
            if (_serf.s.baking_mode == 3) {
                /* Done baking. */
                _building.stop_activity();

                _serf.set_state(SerfState.move_resource_out);
                _serf.s.move_resource_out_res = 1 + ResourceType.bread;
                _serf.s.move_resource_out_res_dest = 0;
                _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                var _player = _serf.game.get_player(_serf.get_owner());
                _player.increase_res_count(ResourceType.bread);
                return;
            } else {
                _building.start_activity();
                _serf.game.get_map().set_serf_index(_serf.pos, 0);
                _serf.counter += 1500;
            }
        }
    }
}

/// @function serf_handle_serf_pigfarming_state(_serf)
function serf_handle_serf_pigfarming_state(_serf) {
    serf_b_init_tables();
    /* When the serf is present there is also at least one
       pig present and at most eight. */
    var _breeding_prob = global.serf_b_breeding_prob;

    var _building = _serf.game.get_building_at_pos(_serf.pos);

    if (_serf.s.pigfarming_mode == 0) {
        if (_building.use_resource_in_stock(0)) {
            _serf.s.pigfarming_mode = 1;
            _serf.animation = 139;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            _serf.tick = _serf.game.get_tick();

            _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        }
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        while (_serf.counter < 0) {
            _serf.s.pigfarming_mode += 1;
            if ((_serf.s.pigfarming_mode & 1) != 0) {
                if (_serf.s.pigfarming_mode != 7) {
                    _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
                    _serf.animation = 139;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                } else if (_building.pigs_count() == 8 ||
                           (_building.pigs_count() > 3 &&
                            ((20 * _serf.game.random_int()) >> 16) < _building.pigs_count())) {
                    /* Pig is ready for the butcher. */
                    _building.send_pig_to_butcher();

                    _serf.set_state(SerfState.move_resource_out);
                    _serf.s.move_resource_out_res = 1 + ResourceType.pig;
                    _serf.s.move_resource_out_res_dest = 0;
                    _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                    /* Update resource stats. */
                    var _player = _serf.game.get_player(_serf.get_owner());
                    _player.increase_res_count(ResourceType.pig);
                } else if ((_serf.game.random_int() & 0xf) != 0) {
                    _serf.s.pigfarming_mode = 1;
                    _serf.animation = 139;
                    _serf.counter = global.serf_counter_from_animation[_serf.animation];
                    _serf.tick = _serf.game.get_tick();
                    _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
                } else {
                    _serf.s.pigfarming_mode = 0;
                }
                return;
            } else {
                _serf.game.get_map().set_serf_index(_serf.pos, 0);
                if (_building.pigs_count() < 8 &&
                    _serf.game.random_int() < _breeding_prob[_building.pigs_count() - 1]) {
                    _building.place_new_pig();
                }
                _serf.counter += 2048;
            }
        }
    }
}

/// @function serf_handle_serf_butchering_state(_serf)
function serf_handle_serf_butchering_state(_serf) {
    var _building = _serf.game.get_building(_serf.game.get_map().get_obj_index(_serf.pos));

    if (_serf.s.butchering_mode == 0) {
        if (_building.use_resource_in_stock(0)) {
            _serf.s.butchering_mode = 1;
            _serf.animation = 140;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            _serf.tick = _serf.game.get_tick();

            _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        }
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        if (_serf.counter < 0) {
            /* Done butchering. */
            _serf.game.get_map().set_serf_index(_serf.pos, 0);

            _serf.set_state(SerfState.move_resource_out);
            _serf.s.move_resource_out_res = 1 + ResourceType.meat;
            _serf.s.move_resource_out_res_dest = 0;
            _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

            /* Update resource stats. */
            var _player = _serf.game.get_player(_serf.get_owner());
            _player.increase_res_count(ResourceType.meat);
        }
    }
}

/// @function serf_handle_serf_making_weapon_state(_serf)
function serf_handle_serf_making_weapon_state(_serf) {
    var _building = _serf.game.get_building(_serf.game.get_map().get_obj_index(_serf.pos));

    if (_serf.s.making_weapon_mode == 0) {
        /* One of each resource makes a sword and a shield.
           Bit 3 is set if a sword has been made and a
           shield can be made without more resources. */
        /* TODO Use of this bit overlaps with sfx check bit. */
        if (!_building.is_playing_sfx()) {
            if (!_building.use_resources_in_stocks()) {
                return;
            }
        }

        _building.start_activity();

        _serf.s.making_weapon_mode = 1;
        _serf.animation = 143;
        _serf.counter = global.serf_counter_from_animation[_serf.animation];
        _serf.tick = _serf.game.get_tick();

        _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        while (_serf.counter < 0) {
            _serf.s.making_weapon_mode += 1;
            if (_serf.s.making_weapon_mode == 7) {
                /* Done making sword or shield. */
                _building.stop_activity();
                _serf.game.get_map().set_serf_index(_serf.pos, 0);

                var _res = ResourceType.sword;
                if (_building.is_playing_sfx()) {
                    _res = ResourceType.shield;
                }
                if (_building.is_playing_sfx()) {
                    _building.stop_playing_sfx();
                } else {
                    _building.start_playing_sfx();
                }

                _serf.set_state(SerfState.move_resource_out);
                _serf.s.move_resource_out_res = 1 + _res;
                _serf.s.move_resource_out_res_dest = 0;
                _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                /* Update resource stats. */
                var _player = _serf.game.get_player(_serf.get_owner());
                _player.increase_res_count(_res);
                return;
            } else {
                _serf.counter += 576;
            }
        }
    }
}

/// @function serf_handle_serf_making_tool_state(_serf)
function serf_handle_serf_making_tool_state(_serf) {
    var _building = _serf.game.get_building(_serf.game.get_map().get_obj_index(_serf.pos));

    if (_serf.s.making_tool_mode == 0) {
        if (_building.use_resources_in_stocks()) {
            _serf.s.making_tool_mode = 1;
            _serf.animation = 144;
            _serf.counter = global.serf_counter_from_animation[_serf.animation];
            _serf.tick = _serf.game.get_tick();

            _serf.game.get_map().set_serf_index(_serf.pos, _serf.index);
        }
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        while (_serf.counter < 0) {
            _serf.s.making_tool_mode += 1;
            if (_serf.s.making_tool_mode == 4) {
                /* Done making tool. */
                _serf.game.get_map().set_serf_index(_serf.pos, 0);

                var _player = _serf.game.get_player(_serf.get_owner());
                var _total_tool_prio = 0;
                for (var _i = 0; _i < 9; _i++) {
                    _total_tool_prio += _player.get_tool_prio(_i);
                }
                _total_tool_prio = _total_tool_prio >> 4;

                var _res = -1;
                if (_total_tool_prio > 0) {
                    /* Use defined tool priorities. */
                    var _prio_offset = (_total_tool_prio * _serf.game.random_int()) >> 16;
                    for (var _j = 0; _j < 9; _j++) {
                        _prio_offset -= _player.get_tool_prio(_j) >> 4;
                        if (_prio_offset < 0) {
                            _res = ResourceType.shovel + _j;
                            break;
                        }
                    }
                } else {
                    /* Completely random. */
                    _res = ResourceType.shovel + ((9 * _serf.game.random_int()) >> 16);
                }

                _serf.set_state(SerfState.move_resource_out);
                _serf.s.move_resource_out_res = 1 + _res;
                _serf.s.move_resource_out_res_dest = 0;
                _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                /* Update resource stats. */
                _player.increase_res_count(_res);
                return;
            } else {
                _serf.counter += 1536;
            }
        }
    }
}

/// @function serf_handle_serf_building_boat_state(_serf)
function serf_handle_serf_building_boat_state(_serf) {
    var _map = _serf.game.get_map();
    var _building = _serf.game.get_building(_map.get_obj_index(_serf.pos));

    if (_serf.s.building_boat_mode == 0) {
        if (!_building.use_resource_in_stock(0)) {
            return;
        }
        _building.boat_clear();

        _serf.s.building_boat_mode = 1;
        _serf.animation = 146;
        _serf.counter = global.serf_counter_from_animation[_serf.animation];
        _serf.tick = _serf.game.get_tick();

        _map.set_serf_index(_serf.pos, _serf.index);
    } else {
        var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
        _serf.tick = _serf.game.get_tick();
        _serf.counter -= _delta;

        while (_serf.counter < 0) {
            _serf.s.building_boat_mode += 1;
            if (_serf.s.building_boat_mode == 9) {
                /* Boat done. */
                var _new_pos = _map.move_down_right(_serf.pos);
                if (_map.has_serf(_new_pos)) {
                    /* Wait for flag to be free. */
                    _serf.s.building_boat_mode -= 1;
                    _serf.counter = 0;
                } else {
                    /* Drop boat at flag. */
                    _building.boat_clear();
                    _map.set_serf_index(_serf.pos, 0);

                    _serf.set_state(SerfState.move_resource_out);
                    _serf.s.move_resource_out_res = 1 + ResourceType.boat;
                    _serf.s.move_resource_out_res_dest = 0;
                    _serf.s.move_resource_out_next_state = SerfState.drop_resource_out;

                    /* Update resource stats. */
                    var _player = _serf.game.get_player(_serf.get_owner());
                    _player.increase_res_count(ResourceType.boat);

                    break;
                }
            } else {
                /* Continue building. */
                _building.boat_do();
                _serf.animation = 145;
                _serf.counter += 1408;
            }
        }
    }
}

/// @function serf_handle_serf_looking_for_geo_spot_state(_serf)
function serf_handle_serf_looking_for_geo_spot_state(_serf) {
    var _tries = 2;
    var _map = _serf.game.get_map();
    for (var _i = 0; _i < 8; _i++) {
        var _dist = ((_serf.game.random_int() >> 2) & 0x3f) + 1;
        var _dest = _map.pos_add_spirally(_serf.pos, _dist);

        var _obj = _map.get_obj(_dest);
        if (_obj == MapObject.none) {
            var _t1 = _map.get_type_down(_dest);
            var _t2 = _map.get_type_up(_dest);
            var _t3 = _map.get_type_down(_map.move_up_left(_dest));
            var _t4 = _map.get_type_up(_map.move_up_left(_dest));
            if ((_t1 >= Terrain.tundra0 && _t1 <= Terrain.snow0) ||
                (_t2 >= Terrain.tundra0 && _t2 <= Terrain.snow0) ||
                (_t3 >= Terrain.tundra0 && _t3 <= Terrain.snow0) ||
                (_t4 >= Terrain.tundra0 && _t4 <= Terrain.snow0)) {
                var _sp = map_get_spiral_pattern();
                _serf.set_state(SerfState.free_walking);
                _serf.s.free_walking_dist_col = _sp[2 * _dist];
                _serf.s.free_walking_dist_row = _sp[2 * _dist + 1];
                _serf.s.free_walking_neg_dist1 = -_sp[2 * _dist];
                _serf.s.free_walking_neg_dist2 = -_sp[2 * _dist + 1];
                _serf.s.free_walking_flags = 0;
                _serf.tick = _serf.game.get_tick();
                show_debug_message("serf: looking for geo spot: found, dist " +
                                   string(_serf.s.free_walking_dist_col) + ", " +
                                   string(_serf.s.free_walking_dist_row) + ".");
                return;
            }
        } else if (_obj >= MapObject.sign_large_gold &&
                   _obj <= MapObject.sign_empty) {
            _tries -= 1;
            if (_tries == 0) {
                break;
            }
        }
    }

    _serf.set_state(SerfState.walking);
    _serf.s.walking_dest = 0;
    _serf.s.walking_dir1 = -2;
    _serf.s.walking_dir = 0;
    _serf.s.walking_wait_counter = 0;
    _serf.counter = 0;
}

/// @function serf_handle_serf_sampling_geo_spot_state(_serf)
function serf_handle_serf_sampling_geo_spot_state(_serf) {
    var _delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _serf.game.get_tick();
    _serf.counter -= _delta;

    var _map = _serf.game.get_map();
    while (_serf.counter < 0) {
        if (_serf.s.free_walking_neg_dist1 == 0 &&
            _map.get_obj(_serf.pos) == MapObject.none) {
            if (_map.get_res_type(_serf.pos) == Minerals.none ||
                _map.get_res_amount(_serf.pos) == 0) {
                /* No available resource here. Put empty sign. */
                _map.set_object(_serf.pos, MapObject.sign_empty, -1);
            } else {
                _serf.s.free_walking_neg_dist1 = -1;
                _serf.animation = 142;

                /* Select small or large sign with the right resource depicted. */
                var _small = 0;
                if (_map.get_res_amount(_serf.pos) < 12) {
                    _small = 1;
                }
                var _obj = MapObject.sign_large_gold +
                           2 * (_map.get_res_type(_serf.pos) - 1) +
                           _small;
                _map.set_object(_serf.pos, _obj, -1);

                /* Check whether a new notification should be posted. */
                var _show_notification = 1;
                for (var _i = 0; _i < 60; _i++) {
                    var _pos_ = _map.pos_add_spirally(_serf.pos, 1 + _i);
                    if ((_map.get_obj(_pos_) >> 1) == (_obj >> 1)) {
                        _show_notification = 0;
                        break;
                    }
                }

                /* Create notification for found resource. */
                if (_show_notification) {
                    var _mtype = MessageType.none;
                    switch (_map.get_res_type(_serf.pos)) {
                        case Minerals.coal:
                            _mtype = MessageType.found_coal;
                            break;
                        case Minerals.iron:
                            _mtype = MessageType.found_iron;
                            break;
                        case Minerals.gold:
                            _mtype = MessageType.found_gold;
                            break;
                        case Minerals.stone:
                            _mtype = MessageType.found_stone;
                            break;
                        default:
                            throw ("NOT_REACHED: sampling geo spot mineral type");
                    }
                    _serf.game.get_player(_serf.get_owner()).add_notification(
                        _mtype, _serf.pos, _map.get_res_type(_serf.pos) - 1);
                }

                _serf.counter += 64;
                continue;
            }
        }

        _serf.set_state(SerfState.free_walking);
        _serf.s.free_walking_neg_dist1 = -128;
        _serf.s.free_walking_neg_dist2 = 0;
        _serf.s.free_walking_flags = 0;
        _serf.counter = 0;
    }
}
