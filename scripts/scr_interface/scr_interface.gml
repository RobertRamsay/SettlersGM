// scr_interface.gml - Ported from Freeserf src/interface.h / src/interface.cc
// (GPL-3.0), original copyright (C) 2013-2018 Jon Lund Steffensen
// <jonlst@gmail.com>. Also ports class Road from src/map.h / src/map.cc
// (Road::get_end, has_pos, is_valid_extension, is_undo, extend, undo).
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Top-level GUI interface. Notes for the integrator:
//  - There is no GameManager in GML: `Interface(_game)` takes the game
//    directly (may be undefined) and calls set_game() like the C++ ctor did
//    with GameManager::get_current_game().
//  - `Random random` is stored as `rnd` (get_random() returns it) because
//    `random` is a GML built-in.
//  - `game.can_build_road(road, player)` is assumed to return a struct
//    {result, dest, water} (C++ out-params). See interface_can_build_road().
//  - GameInitBox is only created when a `GameInitBox` script exists at runtime.
//  - TICKS_PER_SEC is expected to be defined by the Game port (scr_game.gml).
//  - Requires the following on Viewport: set_displayed, set_enabled, set_size,
//    move_to, handle_event, draw (GuiObject float protocol),
//    get_current_map_pos, move_to_map_pos, redraw_map_pos, switch_layer, update.

enum CursorType {
    none = 0,
    flag,
    removable_flag,
    building,
    path,
    clear_by_flag,
    clear_by_path,
    clear
}

enum BuildPossibility {
    none = 0,
    flag,
    mine,
    small,
    large,
    castle
}

enum StatAspect {
    all_aspects = 0,   // C++ `All`: `all` is a GML keyword
    land,
    buildings,
    military
}

enum StatScale {
    scale_30_min = 0,
    scale_60_min,
    scale_600_min,
    scale_3000_min
}

// Interval between automatic save games
#macro AUTOSAVE_INTERVAL (10 * 60 * TICKS_PER_SEC)

#macro ROAD_MAX_LENGTH 256

function interface_init_tables() {
    if (variable_global_exists("interface_map_building_sprite")) {
        return;
    }
    // static const unsigned int map_building_sprite[] (interface.h)
    global.interface_map_building_sprite = [
        0, 0xa7, 0xa8, 0xae, 0xa9,
        0xa3, 0xa4, 0xa5, 0xa6,
        0xaa, 0xc0, 0xab, 0x9a, 0x9c, 0x9b, 0xbc,
        0xa2, 0xa0, 0xa1, 0x99, 0x9d, 0x9e, 0x98, 0x9f, 0xb2
    ];
    // const int msg_category[] (Interface::update)
    global.interface_msg_category = [
        -1, 5, 5, 5, 4, 0, 4, 3, 4, 5,
        5, 5, 4, 4, 4, 4, 0, 0, 0, 0
    ];
}

// ---------------------------------------------------------------------------
// class Road (map.h / map.cc)
// ---------------------------------------------------------------------------

/// Road. `road_begin` is the C++ `road_begin`; `source` mirrors it so that the Map port's
/// place_road_segments(road) (which reads road.source / road.dirs) accepts it.
function Road() constructor {
    road_begin = BAD_MAP_POS;
    source = BAD_MAP_POS;
    dirs = [];

    static is_valid = function() {
        return (road_begin != BAD_MAP_POS);
    };

    static invalidate = function() {
        road_begin = BAD_MAP_POS;
        source = BAD_MAP_POS;
        dirs = [];
    };

    static start = function(_start) {
        road_begin = _start;
        source = _start;
    };

    static get_source = function() {
        return road_begin;
    };

    static get_dirs = function() {
        return dirs;
    };

    static get_length = function() {
        return array_length(dirs);
    };

    static get_last = function() {
        return dirs[array_length(dirs) - 1];
    };

    static is_extendable = function() {
        return (array_length(dirs) < ROAD_MAX_LENGTH);
    };

    static get_end = function(_map) {
        var _result = road_begin;
        var _n = array_length(dirs);
        for (var _i = 0; _i < _n; _i++) {
            _result = _map.move(_result, dirs[_i]);
        }
        return _result;
    };

    static has_pos = function(_map, _pos) {
        var _result = road_begin;
        var _n = array_length(dirs);
        for (var _i = 0; _i < _n; _i++) {
            if (_result == _pos) {
                return true;
            }
            _result = _map.move(_result, dirs[_i]);
        }
        return (_result == _pos);
    };

    static is_valid_extension = function(_map, _dir) {
        if (is_undo(_dir)) {
            return false;
        }

        /* Check that road does not cross itself. */
        var _extended_end = _map.move(get_end(_map), _dir);
        var _pos = road_begin;
        var _valid = true;
        var _n = array_length(dirs);
        for (var _i = 0; _i < _n; _i++) {
            _pos = _map.move(_pos, dirs[_i]);
            if (_pos == _extended_end) {
                _valid = false;
                break;
            }
        }

        return _valid;
    };

    static is_undo = function(_dir) {
        return (array_length(dirs) > 0) && (dirs[array_length(dirs) - 1] == reverse_direction(_dir));
    };

    static extend = function(_dir) {
        if (road_begin == BAD_MAP_POS) {
            return false;
        }

        array_push(dirs, _dir);

        return true;
    };

    static undo = function() {
        if (road_begin == BAD_MAP_POS) {
            return false;
        }

        array_pop(dirs);
        if (array_length(dirs) == 0) {
            road_begin = BAD_MAP_POS;
            source = BAD_MAP_POS;
        }

        return true;
    };
}

/// Value copy of a Road (C++ `Road old_road = building_road;`).
function road_copy(_road) {
    var _r = new Road();
    _r.road_begin = _road.road_begin;
    _r.source = _road.source;
    var _n = array_length(_road.dirs);
    for (var _i = 0; _i < _n; _i++) {
        array_push(_r.dirs, _road.dirs[_i]);
    }
    return _r;
}

/// Wrapper for Game::can_build_road(road, player, MapPos *dest, bool *water).
/// The GML Game port is expected to return {result, dest, water} where
/// `result` is the C++ int return value and `dest` is BAD_MAP_POS (or
/// undefined) whenever the C++ would not have written *dest (early returns).
/// Adjust here if the Game port's shape differs. Returns that struct.
function interface_can_build_road(_game, _road, _player) {
    return _game.can_build_road(_road, _player);
}

// ---------------------------------------------------------------------------
// class Interface
// ---------------------------------------------------------------------------

function Interface(_game = undefined) : GuiObject() constructor {
    interface_init_tables();

    building_road_valid_dir = 0;
    sfx_queue = [0, 0, 0, 0];
    water_in_view = false;
    trees_in_view = false;
    return_pos = 0;

    displayed = true;

    game = undefined;

    // Random random; (default ctor seeds from time() and consumes one value)
    rnd = new RandomState(irandom(0xFFFF), irandom(0xFFFF), irandom(0xFFFF));
    rnd.next_random();

    map_cursor_pos = 0;
    map_cursor_type = CursorType.none;
    build_possibility = BuildPossibility.none;

    player = undefined;

    /* Settings */
    config = 0x39;
    msg_flags = 0;
    return_timeout = 0;

    selected_stat_scale = StatScale.scale_30_min;
    selected_stat_aspect = StatAspect.all_aspects;
    selected_stat_resource = ResourceType.plank;

    // SpriteLoc map_cursor_sprites[7]: {sprite, x, y}
    map_cursor_sprites = array_create(7, undefined);
    map_cursor_sprites[0] = { sprite: 32, x: 0, y: 0 };
    map_cursor_sprites[1] = { sprite: 33, x: 0, y: 0 };
    map_cursor_sprites[2] = { sprite: 33, x: 0, y: 0 };
    map_cursor_sprites[3] = { sprite: 33, x: 0, y: 0 };
    map_cursor_sprites[4] = { sprite: 33, x: 0, y: 0 };
    map_cursor_sprites[5] = { sprite: 33, x: 0, y: 0 };
    map_cursor_sprites[6] = { sprite: 33, x: 0, y: 0 };

    last_const_tick = 0;

    building_road = new Road();

    viewport = undefined;
    panel = undefined;
    popup = undefined;
    init_box = undefined;
    notification_box = undefined;

    // ----------------------------------------------------------- accessors

    static get_game = function() {
        return game;
    };

    static get_viewport = function() {
        return viewport;
    };

    static get_panel_bar = function() {
        return panel;
    };

    static get_popup_box = function() {
        return popup;
    };

    static get_notification_box = function() {
        return notification_box;
    };

    static get_config = function(_i) {
        return ((config & (1 << _i)) != 0);
    };

    static set_config = function(_i) {
        config |= (1 << _i);
    };

    static switch_config = function(_i) {
        config ^= (1 << _i);
    };

    static get_map_cursor_pos = function() {
        return map_cursor_pos;
    };

    static get_map_cursor_type = function() {
        return map_cursor_type;
    };

    static get_map_cursor_sprite = function(_i) {
        return map_cursor_sprites[_i].sprite;
    };

    static get_random = function() {
        return rnd;
    };

    static get_msg_flag = function(_i) {
        return ((msg_flags & (1 << _i)) != 0);
    };

    static set_msg_flag = function(_i) {
        msg_flags |= (1 << _i);
    };

    static get_selected_stat_scale = function() {
        return selected_stat_scale;
    };

    static set_selected_stat_scale = function(_scale) {
        selected_stat_scale = _scale;
    };

    static get_selected_stat_aspect = function() {
        return selected_stat_aspect;
    };

    static set_selected_stat_aspect = function(_aspect) {
        selected_stat_aspect = _aspect;
    };

    static get_selected_stat_resource = function() {
        return selected_stat_resource;
    };

    static set_selected_stat_resource = function(_item) {
        selected_stat_resource = _item;
    };

    static get_build_possibility = function() {
        return build_possibility;
    };

    static get_player = function() {
        return player;
    };

    static is_building_road = function() {
        return building_road.is_valid();
    };

    static get_building_road = function() {
        return building_road;
    };

    static build_road_reset = function() {
        build_road_end();
        build_road_begin();
    };

    static build_road_is_valid_dir = function(_dir) {
        return ((building_road_valid_dir & (1 << _dir)) != 0);
    };

    // ----------------------------------------------------------- popups

    /* Open popup box */
    static open_popup = function(_box) {
        if (popup == undefined) {
            popup = new PopupBox(self);
            add_float(popup, 0, 0);
        }
        layout();
        popup.show(_box);
        if (panel != undefined) {
            panel.update();
        }
    };

    /* Close the current popup. */
    static close_popup = function() {
        if (popup == undefined) {
            return;
        }
        popup.hide();
        del_float(popup);
        popup = undefined;
        update_map_cursor_pos(map_cursor_pos);
        if (panel != undefined) {
            panel.update();
        }
    };

    /* Open box for starting a new game */
    static open_game_init = function() {
        if (init_box == undefined) {
            // GameInitBox is created only if its constructor exists at runtime.
            var _ctor = GameInitBox;
            if (_ctor != -1) {
                init_box = new _ctor(self);
                add_float(init_box, 0, 0);
            }
        }
        if (init_box != undefined) {
            init_box.set_displayed(true);
            init_box.set_enabled(true);
        }
        if (panel != undefined) {
            panel.set_displayed(false);
        }
        viewport.set_enabled(false);
        layout();
    };

    static close_game_init = function() {
        if (init_box != undefined) {
            init_box.set_displayed(false);
            del_float(init_box);
            init_box = undefined;
        }
        if (panel != undefined) {
            panel.set_displayed(true);
            panel.set_enabled(true);
        }
        viewport.set_enabled(true);
        layout();

        update_map_cursor_pos(map_cursor_pos);
    };

    /* Open box for next message in the message queue */
    static open_message = function() {
        if (!player.has_notification()) {
            play_sound(Sfx.click);
            return;
        } else if ((msg_flags & (1 << 3)) == 0) {
            msg_flags |= (1 << 4);
            msg_flags |= (1 << 3);
            var _pos = viewport.get_current_map_pos();
            return_pos = _pos;
        }

        var _message = player.pop_notification();

        if (_message.type == MessageType.call_to_menu) {
            /* TODO */
        }

        if (notification_box == undefined) {
            notification_box = new NotificationBox(self);
            add_float(notification_box, 0, 0);
        }
        notification_box.show(_message);
        layout();

        if ((0x8f3fe & (1 << _message.type)) != 0) {
            /* Move screen to new position */
            viewport.move_to_map_pos(_message.pos);
            update_map_cursor_pos(_message.pos);
        }

        msg_flags |= (1 << 1);
        return_timeout = 60 * TICKS_PER_SEC;
        play_sound(Sfx.click);
    };

    static return_from_message = function() {
        if ((msg_flags & (1 << 3)) != 0) { /* Return arrow present */
            msg_flags |= (1 << 4);
            msg_flags &= ~(1 << 3);

            return_timeout = 0;
            viewport.move_to_map_pos(return_pos);

            if ((popup != undefined) && (popup.get_box() == PopupType.message)) {
                close_popup();
            }
            play_sound(Sfx.click);
        }
    };

    static close_message = function() {
        if (notification_box == undefined) {
            return;
        }

        notification_box.set_displayed(false);
        del_float(notification_box);
        notification_box = undefined;
        layout();
    };

    // ----------------------------------------------------------- cursor

    /* Return the cursor type and various related values of a MapPos.
       Returns {bld_possibility, cursor_type}. */
    static get_map_cursor_type_at = function(_player, _pos) {
        var _map = game.get_map();
        var _bld_possibility = BuildPossibility.none;
        var _cursor_type = CursorType.none;
        if (_player == undefined) {
            _bld_possibility = BuildPossibility.none;
            _cursor_type = CursorType.clear;
            return { bld_possibility: _bld_possibility, cursor_type: _cursor_type };
        }

        if (game.can_build_castle(_pos, _player)) {
            _bld_possibility = BuildPossibility.castle;
        } else if (game.can_player_build(_pos, _player) &&
                   global.map_space_from_obj[_map.get_obj(_pos)] == Space.open &&
                   (game.can_build_flag(_map.move_down_right(_pos), _player) ||
                    _map.has_flag(_map.move_down_right(_pos)))) {
            if (game.can_build_mine(_pos)) {
                _bld_possibility = BuildPossibility.mine;
            } else if (game.can_build_large(_pos)) {
                _bld_possibility = BuildPossibility.large;
            } else if (game.can_build_small(_pos)) {
                _bld_possibility = BuildPossibility.small;
            } else if (game.can_build_flag(_pos, _player)) {
                _bld_possibility = BuildPossibility.flag;
            } else {
                _bld_possibility = BuildPossibility.none;
            }
        } else if (game.can_build_flag(_pos, _player)) {
            _bld_possibility = BuildPossibility.flag;
        } else {
            _bld_possibility = BuildPossibility.none;
        }

        if (_map.get_obj(_pos) == MapObject.flag &&
            _map.get_owner(_pos) == _player.get_index()) {
            if (game.can_demolish_flag(_pos, _player)) {
                _cursor_type = CursorType.removable_flag;
            } else {
                _cursor_type = CursorType.flag;
            }
        } else if (!_map.has_building(_pos) &&
                   !_map.has_flag(_pos)) {
            var _paths = _map.get_paths(_pos);
            if (_paths == 0) {
                if (_map.get_obj(_map.move_down_right(_pos)) == MapObject.flag) {
                    _cursor_type = CursorType.clear_by_flag;
                } else if (_map.get_paths(_map.move_down_right(_pos)) == 0) {
                    _cursor_type = CursorType.clear;
                } else {
                    _cursor_type = CursorType.clear_by_path;
                }
            } else if (_map.get_owner(_pos) == _player.get_index()) {
                _cursor_type = CursorType.path;
            } else {
                _cursor_type = CursorType.none;
            }
        } else if ((_map.get_obj(_pos) == MapObject.small_building ||
                    _map.get_obj(_pos) == MapObject.large_building) &&
                   _map.get_owner(_pos) == _player.get_index()) {
            var _bld = game.get_building_at_pos(_pos);
            if (!_bld.is_burning()) {
                _cursor_type = CursorType.building;
            } else {
                _cursor_type = CursorType.none;
            }
        } else {
            _cursor_type = CursorType.none;
        }

        return { bld_possibility: _bld_possibility, cursor_type: _cursor_type };
    };

    /* Update the interface_t object with the information returned
       in get_map_cursor_type(). */
    static determine_map_cursor_type = function() {
        var _r = get_map_cursor_type_at(player, map_cursor_pos);
        build_possibility = _r.bld_possibility;
        map_cursor_type = _r.cursor_type;
    };

    /* Update the interface_t object with the information returned
       in get_map_cursor_type(). This is sets the appropriate values
       when the player interface is in road construction mode. */
    static determine_map_cursor_type_road = function() {
        var _map = game.get_map();
        var _pos = map_cursor_pos;
        var _h = _map.get_height(_pos);
        var _valid_dir = 0;

        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            var _sprite = 0;

            if (building_road.is_undo(_d)) {
                _sprite = 45; /* undo */
                _valid_dir |= (1 << _d);
            } else if (_map.is_road_segment_valid(_pos, _d)) {
                if (building_road.is_valid_extension(_map, _d)) {
                    var _h_diff = _map.get_height(_map.move(_pos, _d)) - _h;
                    _sprite = 39 + _h_diff; /* height indicators */
                    _valid_dir |= (1 << _d);
                } else {
                    _sprite = 44;
                }
            } else {
                _sprite = 44; /* striped */
            }
            map_cursor_sprites[_d + 1].sprite = _sprite;
        }

        building_road_valid_dir = _valid_dir;
    };

    /* Set the appropriate sprites for the panel buttons and the map cursor. */
    static update_interface = function() {
        if (!building_road.is_valid()) {
            switch (map_cursor_type) {
            case CursorType.none:
                map_cursor_sprites[0].sprite = 32;
                map_cursor_sprites[2].sprite = 33;
                break;
            case CursorType.flag:
                map_cursor_sprites[0].sprite = 51;
                map_cursor_sprites[2].sprite = 33;
                break;
            case CursorType.removable_flag:
                map_cursor_sprites[0].sprite = 51;
                map_cursor_sprites[2].sprite = 33;
                break;
            case CursorType.building:
                map_cursor_sprites[0].sprite = 32;
                map_cursor_sprites[2].sprite = 33;
                break;
            case CursorType.path:
                map_cursor_sprites[0].sprite = 52;
                map_cursor_sprites[2].sprite = 33;
                if (build_possibility != BuildPossibility.none) {
                    map_cursor_sprites[0].sprite = 47;
                }
                break;
            case CursorType.clear_by_flag:
                if (build_possibility < BuildPossibility.mine) {
                    map_cursor_sprites[0].sprite = 32;
                    map_cursor_sprites[2].sprite = 33;
                } else {
                    map_cursor_sprites[0].sprite = 46 + build_possibility;
                    map_cursor_sprites[2].sprite = 33;
                }
                break;
            case CursorType.clear_by_path:
                if (build_possibility != BuildPossibility.none) {
                    map_cursor_sprites[0].sprite = 46 + build_possibility;
                    if (build_possibility == BuildPossibility.flag) {
                        map_cursor_sprites[2].sprite = 33;
                    } else {
                        map_cursor_sprites[2].sprite = 47;
                    }
                } else {
                    map_cursor_sprites[0].sprite = 32;
                    map_cursor_sprites[2].sprite = 33;
                }
                break;
            case CursorType.clear:
                if (build_possibility != BuildPossibility.none) {
                    if (build_possibility == BuildPossibility.castle) {
                        map_cursor_sprites[0].sprite = 50;
                    } else {
                        map_cursor_sprites[0].sprite = 46 + build_possibility;
                    }
                    if (build_possibility == BuildPossibility.flag) {
                        map_cursor_sprites[2].sprite = 33;
                    } else {
                        map_cursor_sprites[2].sprite = 47;
                    }
                } else {
                    map_cursor_sprites[0].sprite = 32;
                    map_cursor_sprites[2].sprite = 33;
                }
                break;
            default:
                throw ("Interface::update_interface: NOT_REACHED");
                break;
            }
        }

        if (panel != undefined) {
            panel.update();
        }
    };

    // ----------------------------------------------------------- game/player

    static set_game = function(_new_game) {
        if (viewport != undefined) {
            del_float(viewport);
            viewport = undefined;
        }

        game = _new_game;

        // The old player struct belongs to the previous Game, so it must not be
        // carried over. It also unblocks set_player() below: that deletes the
        // panel first and then returns early when the index is unchanged, so
        // starting a new game as player 0 while player 0 was already selected
        // removed the panel and never rebuilt it.
        player = undefined;

        if (game != undefined) {
            viewport = new Viewport(self, game.get_map());
            viewport.set_size(width, height);
            viewport.set_displayed(true);
            add_float(viewport, 0, 0);
        }

        layout();

        set_player(0);
    };

    static set_player = function(_player_index) {
        if (panel != undefined) {
            del_float(panel);
            panel = undefined;
        }

        if (game == undefined) {
            player = undefined;
            return;
        }

        if ((player != undefined) && (_player_index == player.get_index())) {
            return;
        }

        player = game.get_player(_player_index);

        /* Move viewport to initial position */
        var _init_pos = game.get_map().pos(0, 0);

        if (player != undefined) {
            panel = new PanelBar(self);
            panel.set_displayed(true);
            add_float(panel, 0, 0);
            layout();

            var _buildings = game.get_player_buildings(player);
            var _n = array_length(_buildings);
            for (var _i = 0; _i < _n; _i++) {
                var _building = _buildings[_i];
                if (_building.get_type() == BuildingType.castle) {
                    _init_pos = _building.get_position();
                }
            }
        }

        update_map_cursor_pos(_init_pos);
        viewport.move_to_map_pos(map_cursor_pos);
    };

    /// Returns a GameMaker colour (Freeserf Color -> make_colour_rgb).
    static get_player_color = function(_player_index) {
        var _player_color = game.get_player(_player_index).get_color();
        var _color = make_colour_rgb(_player_color.red, _player_color.green, _player_color.blue);
        return _color;
    };

    static update_map_cursor_pos = function(_pos) {
        map_cursor_pos = _pos;
        if (building_road.is_valid()) {
            determine_map_cursor_type_road();
        } else {
            determine_map_cursor_type();
        }
        update_interface();
        // Freeserf lets the cursor wait for the viewport's next animation
        // redraw (up to ~80 ms). Mark the viewport dirty straight away so that
        // clicking the map responds on the very next frame.
        if (viewport != undefined) {
            viewport.set_redraw();
        }
    };

    // ----------------------------------------------------------- roads

    /* Start road construction mode for player interface. */
    static build_road_begin = function() {
        determine_map_cursor_type();

        if (map_cursor_type != CursorType.flag &&
            map_cursor_type != CursorType.removable_flag) {
            update_interface();
            return;
        }

        building_road.invalidate();
        building_road.start(map_cursor_pos);
        update_map_cursor_pos(map_cursor_pos);

        panel.update();
    };

    /* End road construction mode for player interface. */
    static build_road_end = function() {
        map_cursor_sprites[1].sprite = 33;
        map_cursor_sprites[2].sprite = 33;
        map_cursor_sprites[3].sprite = 33;
        map_cursor_sprites[4].sprite = 33;
        map_cursor_sprites[5].sprite = 33;
        map_cursor_sprites[6].sprite = 33;

        building_road.invalidate();
        update_map_cursor_pos(map_cursor_pos);

        panel.update();
    };

    /* Build a single road segment. Return -1 on fail, 0 on successful
       construction, and 1 if this segment completed the path. */
    static build_road_segment = function(_dir) {
        if (!building_road.is_extendable()) {
            /* Max length reached */
            return -1;
        }

        building_road.extend(_dir);

        var _cbr = interface_can_build_road(game, building_road, player);
        var _dest = _cbr.dest;
        var _r = _cbr.result;
        if (_r <= 0) {
            /* Invalid construction, undo. */
            return remove_road_segment();
        }

        if (game.get_map().get_obj(_dest) == MapObject.flag) {
            /* Existing flag at destination, try to connect. */
            if (!game.build_road(building_road, player)) {
                build_road_end();
                return -1;
            } else {
                build_road_end();
                update_map_cursor_pos(_dest);
                return 1;
            }
        } else if (game.get_map().get_paths(_dest) == 0) {
            /* No existing paths at destination, build segment. */
            update_map_cursor_pos(_dest);

            /* TODO Pathway scrolling */
        } else {
            /* TODO fast split path and connect on double click */
            return -1;
        }

        return 0;
    };

    static remove_road_segment = function() {
        var _dest = building_road.get_source();
        var _res = 0;
        building_road.undo();
        var _abort = false;
        if (building_road.get_length() == 0) {
            _abort = true;
        } else {
            var _cbr = interface_can_build_road(game, building_road, player);
            // C++ only writes *dest when the walk along the road completes.
            if (_cbr.dest != undefined && _cbr.dest != BAD_MAP_POS) {
                _dest = _cbr.dest;
            }
            if (_cbr.result == 0) {
                _abort = true;
            }
        }
        if (_abort) {
            /* Road construction is no longer valid, abort. */
            build_road_end();
            _res = -1;
        }

        update_map_cursor_pos(_dest);

        /* TODO Pathway scrolling */

        return _res;
    };

    /* Extend currently constructed road with an array of directions. */
    static extend_road = function(_road) {
        var _old_road = road_copy(building_road);
        var _dirs = _road.get_dirs();
        var _n = array_length(_dirs);
        for (var _i = 0; _i < _n; _i++) {
            var _dir = _dirs[_i];
            var _r = build_road_segment(_dir);
            if (_r < 0) {
                building_road = _old_road;
                return -1;
            } else if (_r == 1) {
                building_road.invalidate();
                return 1;
            }
        }

        return 0;
    };

    // ----------------------------------------------------------- building

    static demolish_object = function() {
        determine_map_cursor_type();

        if (map_cursor_type == CursorType.removable_flag) {
            play_sound(Sfx.click);
            game.demolish_flag(map_cursor_pos, player);
        } else if (map_cursor_type == CursorType.building) {
            var _building = game.get_building_at_pos(map_cursor_pos);

            if (_building.is_done() &&
                (_building.get_type() == BuildingType.hut ||
                 _building.get_type() == BuildingType.tower ||
                 _building.get_type() == BuildingType.fortress)) {
                /* TODO */
            }

            play_sound(Sfx.ahhh);
            game.demolish_building(map_cursor_pos, player);
        } else {
            play_sound(Sfx.not_accepted);
            update_interface();
        }
    };

    /* Build new flag. */
    static build_flag = function() {
        if (!game.build_flag(map_cursor_pos, player)) {
            play_sound(Sfx.not_accepted);
            return;
        }

        update_map_cursor_pos(map_cursor_pos);
    };

    /* Build a new building. */
    static build_building = function(_type) {
        if (!game.build_building(map_cursor_pos, _type, player)) {
            play_sound(Sfx.not_accepted);
            return;
        }

        play_sound(Sfx.accepted);
        close_popup();

        /* Move cursor to flag. */
        var _flag_pos = game.get_map().move_down_right(map_cursor_pos);
        update_map_cursor_pos(_flag_pos);
    };

    /* Build castle. */
    static build_castle = function() {
        if (!game.build_castle(map_cursor_pos, player)) {
            play_sound(Sfx.not_accepted);
            return;
        }

        play_sound(Sfx.accepted);
        update_map_cursor_pos(map_cursor_pos);
    };

    static build_road = function() {
        var _r = game.build_road(building_road, player);
        if (!_r) {
            play_sound(Sfx.not_accepted);
            game.demolish_flag(map_cursor_pos, player);
        } else {
            play_sound(Sfx.accepted);
            build_road_end();
        }
    };

    /// static void update_map_height(MapPos pos, void *data)
    static update_map_height = function(_pos, _data) {
        var _interface = _data;
        _interface.viewport.redraw_map_pos(_pos);
    };

    // ----------------------------------------------------------- GUI

    static internal_draw = function() {
    };

    static layout = function() {
        var _panel_x = 0;
        var _panel_y = height;

        if (panel != undefined) {
            var _panel_width = PANEL_WIDTH;
            var _panel_height = 40;
            _panel_x = (width - _panel_width) div 2;
            _panel_y = height - _panel_height;
            panel.move_to(_panel_x, _panel_y);
            panel.set_size(_panel_width, _panel_height);
        }

        if (popup != undefined) {
            var _popup_width = 144;
            var _popup_height = 160;
            var _popup_x = (width - _popup_width) div 2;
            var _popup_y = (height - _popup_height) div 2;
            popup.move_to(_popup_x, _popup_y);
            popup.set_size(_popup_width, _popup_height);
        }

        if (init_box != undefined) {
            var _init_box_width = 360;
            var _init_box_height = 256;
            var _init_box_x = (width - _init_box_width) div 2;
            var _init_box_y = (height - _init_box_height) div 2;
            init_box.move_to(_init_box_x, _init_box_y);
            init_box.set_size(_init_box_width, _init_box_height);
        }

        if (notification_box != undefined) {
            var _notification_box_width = 200;
            var _notification_box_height = 88;
            var _notification_box_x = _panel_x + 40;
            var _notification_box_y = _panel_y - _notification_box_height;
            notification_box.move_to(_notification_box_x, _notification_box_y);
            notification_box.set_size(_notification_box_width, _notification_box_height);
        }

        if (viewport != undefined) {
            viewport.set_size(width, height);
        }

        set_redraw();
    };

    /* Called periodically when the game progresses. */
    static update = function() {
        if (game == undefined) {
            return;
        }

        game.update();

        var _tick_diff = game.get_const_tick() - last_const_tick;
        last_const_tick = game.get_const_tick();

        /* Clear return arrow after a timeout */
        if (return_timeout < _tick_diff) {
            msg_flags |= (1 << 4);
            msg_flags &= ~(1 << 3);
            return_timeout = 0;
        } else {
            return_timeout -= _tick_diff;
        }

        var _msg_category = global.interface_msg_category;

        /* Handle newly enqueued messages */
        if ((player != undefined) && player.has_message()) {
            player.drop_message();
            while (player.has_notification()) {
                var _message = player.peek_notification();
                if ((config & (1 << _msg_category[_message.type])) != 0) {
                    play_sound(Sfx.message);
                    msg_flags |= (1 << 0);
                    break;
                }
                player.pop_notification();
            }
        }

        if ((player != undefined) && ((msg_flags & (1 << 1)) != 0)) {
            msg_flags &= ~(1 << 1);
            while (true) {
                if (!player.has_notification()) {
                    msg_flags &= ~(1 << 0);
                    break;
                }

                var _message2 = player.peek_notification();
                if ((config & (1 << _msg_category[_message2.type])) != 0) {
                    break;
                }
                player.pop_notification();
            }
        }

        viewport.update();
        set_redraw();
    };

    /// _key is the ascii code of the key (char), _modifier the modifier bits
    /// (1 = ctrl, 2 = shift) as in Freeserf.
    static handle_key_pressed = function(_key, _modifier) {
        switch (_key) {
            /* Interface control */
            case 9: { // '\t'
                if ((_modifier & 2) != 0) {
                    return_from_message();
                } else {
                    open_message();
                }
                break;
            }
            case 27: {
                if ((notification_box != undefined) && notification_box.is_displayed()) {
                    close_message();
                } else if ((popup != undefined) && popup.is_displayed()) {
                    close_popup();
                } else if (building_road.is_valid()) {
                    build_road_end();
                }
                break;
            }

            /* Game speed */
            case ord("+"): {
                game.speed_increase();
                break;
            }
            case ord("-"): {
                game.speed_decrease();
                break;
            }
            case ord("0"): {
                game.speed_reset();
                break;
            }
            case ord("p"): {
                game.pause();
                break;
            }

            /* Audio */
            case ord("s"): {
                // Audio sound player enable toggle: no sound-player object in the
                // GML port (play_sfx is a plain function). TODO when scr_audio
                // gains an enable flag.
                break;
            }
            case ord("m"): {
                // Audio::get_music_player()->enable(!is_enabled())
                audio_toggle_music();
                break;
            }

            /* Debug */
            case ord("g"): {
                viewport.switch_layer(ViewportLayer.grid);
                break;
            }

            /* Game control */
            case ord("b"): {
                viewport.switch_layer(ViewportLayer.builds);
                break;
            }
            case ord("j"): {
                var _index = game.get_next_player(player).get_index();
                set_player(_index);
                show_debug_message("main: Switched to player #" + string(_index));
                break;
            }
            case ord("z"):
                if ((_modifier & 1) != 0) {
                    // GameStore::get_instance().quick_save("quicksave", game) -- save/load skipped.
                }
                break;
            case ord("n"):
                if ((_modifier & 1) != 0) {
                    open_game_init();
                }
                break;
            case ord("c"):
                if ((_modifier & 1) != 0) {
                    open_popup(PopupType.quit_confirm);
                }
                break;

            default:
                return false;
        }

        return true;
    };

    static handle_event = function(_event) {
        switch (_event.type) {
            case EventType.resize:
                set_size(_event.dx, _event.dy);
                break;
            case EventType.update:
                update();
                break;
            case EventType.draw:
                draw();
                break;

            default:
                return gui_handle_event(_event);
                break;
        }

        return true;
    };

    // GameManager::Handler implementation
    static on_new_game = function(_new_game) {
        set_game(_new_game);
    };

    static on_end_game = function(_game_) {
        set_game(undefined);
    };

    // Constructor tail (C++: GameManager add_handler + set_game(current game)).
    set_game(_game);
}
