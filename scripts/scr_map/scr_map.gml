// scr_map.gml - Map data and map update functions
// Ported from Freeserf (GPL-3.0), original copyright (C) 2013-2018
// Jon Lund Steffensen <jonlst@gmail.com>. Ports src/map.h (enums Object,
// Minerals, Space, Terrain, LandscapeTile/GameTile/UpdateState and the
// inline accessors of class Map) and src/map.cc lines 76-772 (spiral
// pattern tables, map_space_from_obj, constructor, get_rnd_coord,
// get_gold_deposit, init_spiral_pos_pattern, init_tiles, set_height,
// set_object, remove_ground_deposit, remove_fish, set_serf_index,
// update_public, update_hidden, update, is_road_segment_valid,
// place_road_segments, remove_road_backref_until_flag,
// remove_road_backrefs, remove_road_segment, road_segment_in_water,
// add/del_change_handler, types_within).
// NOT ported: class Road, operator ==/!=, save/load operators (>> <<),
// pos_from_saved_value.
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

/* Basically the map is constructed from a regular, square grid, with
   rows and columns, except that the grid is actually sheared like this:
   http://mathworld.wolfram.com/Polyrhomb.html
   This is the foundational 2D grid for the map, where each vertex can be
   identified by an integer col and row (commonly encoded as MapPos).

   Each tile has the shape of a rhombus:
      A ______ B
       /\    /
      /  \  /
   C /____\/ D

   but is actually composed of two triangles called "up" (a,c,d) and
   "down" (a,b,d). A serf can move on the perimeter of any of these
   triangles. Each vertex has various properties associated with it,
   among others a height value which means that the 3D landscape is
   defined by these points in (col, row, height)-space.

   Terrain types:
   - 0-3: Water (range encodes adjacency to shore)
   - 4-7: Grass (4=adjacency to water, 5=only tile that allows large buildings,
                 6-7=elevation based)
   - 8-10: Desert (range encodes adjacency to grass)
   - 11-13: Tundra (elevation based)
   - 14-15: Snow (elevation based)
*/

enum Terrain {
    water0 = 0,
    water1,
    water2,
    water3,
    grass0 = 4,
    grass1,
    grass2,
    grass3,
    desert0 = 8,
    desert1,
    desert2,
    tundra0 = 11,
    tundra1,
    tundra2,
    snow0 = 14,
    snow1
}

enum MapObject {
    none = 0,
    flag,
    small_building,
    large_building,
    castle,

    tree0 = 8,
    tree1,
    tree2, /* 10 */
    tree3,
    tree4,
    tree5,
    tree6,
    tree7, /* 15 */

    pine0,
    pine1,
    pine2,
    pine3,
    pine4, /* 20 */
    pine5,
    pine6,
    pine7,

    palm0,
    palm1, /* 25 */
    palm2,
    palm3,

    water_tree0,
    water_tree1,
    water_tree2, /* 30 */
    water_tree3,

    stone0 = 72,
    stone1,
    stone2,
    stone3, /* 75 */
    stone4,
    stone5,
    stone6,
    stone7,

    sandstone0, /* 80 */
    sandstone1,

    cross,
    stub,

    stone,
    sandstone3, /* 85 */

    cadaver0,
    cadaver1,

    water_stone0,
    water_stone1,

    cactus0, /* 90 */
    cactus1,

    dead_tree,

    felled_pine0,
    felled_pine1,
    felled_pine2, /* 95 */
    felled_pine3,
    felled_pine4,

    felled_tree0,
    felled_tree1,
    felled_tree2, /* 100 */
    felled_tree3,
    felled_tree4,

    new_pine,
    new_tree,

    seeds0, /* 105 */
    seeds1,
    seeds2,
    seeds3,
    seeds4,
    seeds5, /* 110 */
    field_expired,

    sign_large_gold,
    sign_small_gold,
    sign_large_iron,
    sign_small_iron, /* 115 */
    sign_large_coal,
    sign_small_coal,
    sign_large_stone,
    sign_small_stone,

    sign_empty, /* 120 */

    field0,
    field1,
    field2,
    field3,
    field4, /* 125 */
    field5,
    object127
}

enum Minerals {
    none = 0,
    gold,
    iron,
    coal,
    stone
}

/* A map space can be OPEN which means that
   a building can be constructed in the space.
   A FILLED space can be passed by a serf, but
   nothing can be built in this space except roads.
   A SEMIPASSABLE space is like FILLED but no roads
   can be built. A IMPASSABLE space can neither be
   used for contructions nor passed by serfs. */
enum Space {
    open = 0,
    filled,
    semipassable,
    impassable
}

/// @function map_init_space_table()
/// @desc Builds global.map_space_from_obj (128 entries), the mapping from
///       MapObject to Space. Port of Map::map_space_from_obj.
function map_init_space_table() {
    global.map_space_from_obj = [

        Space.open, // MapObject.none = 0,
        Space.filled, // MapObject.flag,
        Space.impassable, // MapObject.small_building,
        Space.impassable, // MapObject.large_building,
        Space.impassable, // MapObject.castle,
        Space.open,
        Space.open,
        Space.open,

        Space.filled, // MapObject.tree0 = 8,
        Space.filled, // MapObject.tree1,
        Space.filled, // MapObject.tree2, /* 10 */
        Space.filled, // MapObject.tree3,
        Space.filled, // MapObject.tree4,
        Space.filled, // MapObject.tree5,
        Space.filled, // MapObject.tree6,
        Space.filled, // MapObject.tree7, /* 15 */

        Space.filled, // MapObject.pine0,
        Space.filled, // MapObject.pine1,
        Space.filled, // MapObject.pine2,
        Space.filled, // MapObject.pine3,
        Space.filled, // MapObject.pine4, /* 20 */
        Space.filled, // MapObject.pine5,
        Space.filled, // MapObject.pine6,
        Space.filled, // MapObject.pine7,

        Space.filled, // MapObject.palm0,
        Space.filled, // MapObject.palm1, /* 25 */
        Space.filled, // MapObject.palm2,
        Space.filled, // MapObject.palm3,

        Space.impassable, // MapObject.water_tree0,
        Space.impassable, // MapObject.water_tree1,
        Space.impassable, // MapObject.water_tree2, /* 30 */
        Space.impassable, // MapObject.water_tree3,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,
        Space.open,

        Space.impassable, // MapObject.stone0 = 72,
        Space.impassable, // MapObject.stone1,
        Space.impassable, // MapObject.stone2,
        Space.impassable, // MapObject.stone3, /* 75 */
        Space.impassable, // MapObject.stone4,
        Space.impassable, // MapObject.stone5,
        Space.impassable, // MapObject.stone6,
        Space.impassable, // MapObject.stone7,

        Space.impassable, // MapObject.sandstone0, /* 80 */
        Space.impassable, // MapObject.sandstone1,

        Space.filled, // MapObject.cross,
        Space.open, // MapObject.stub,

        Space.open, // MapObject.stone,
        Space.open, // MapObject.sandstone3, /* 85 */

        Space.open, // MapObject.cadaver0,
        Space.open, // MapObject.cadaver1,

        Space.impassable, // MapObject.water_stone0,
        Space.impassable, // MapObject.water_stone1,

        Space.filled, // MapObject.cactus0, /* 90 */
        Space.filled, // MapObject.cactus1,

        Space.filled, // MapObject.dead_tree,

        Space.filled, // MapObject.felled_pine0,
        Space.filled, // MapObject.felled_pine1,
        Space.filled, // MapObject.felled_pine2, /* 95 */
        Space.filled, // MapObject.felled_pine3,
        Space.open, // MapObject.felled_pine4,

        Space.filled, // MapObject.felled_tree0,
        Space.filled, // MapObject.felled_tree1,
        Space.filled, // MapObject.felled_tree2, /* 100 */
        Space.filled, // MapObject.felled_tree3,
        Space.open, // MapObject.felled_tree4,

        Space.filled, // MapObject.new_pine,
        Space.filled, // MapObject.new_tree,

        Space.semipassable, // MapObject.seeds0, /* 105 */
        Space.semipassable, // MapObject.seeds1,
        Space.semipassable, // MapObject.seeds2,
        Space.semipassable, // MapObject.seeds3,
        Space.semipassable, // MapObject.seeds4,
        Space.semipassable, // MapObject.seeds5, /* 110 */
        Space.open, // MapObject.field_expired,

        Space.open, // MapObject.sign_large_gold,
        Space.open, // MapObject.sign_small_gold,
        Space.open, // MapObject.sign_large_iron,
        Space.open, // MapObject.sign_small_iron, /* 115 */
        Space.open, // MapObject.sign_large_coal,
        Space.open, // MapObject.sign_small_coal,
        Space.open, // MapObject.sign_large_stone,
        Space.open, // MapObject.sign_small_stone,

        Space.open, // MapObject.sign_empty, /* 120 */

        Space.semipassable, // MapObject.field0,
        Space.semipassable, // MapObject.field1,
        Space.semipassable, // MapObject.field2,
        Space.semipassable, // MapObject.field3,
        Space.semipassable, // MapObject.field4, /* 125 */
        Space.semipassable, // MapObject.field5,
        Space.open  // MapObject.127

    ];
}

/// @function map_init_spiral_pattern()
/// @desc Builds global.map_spiral_pattern (590 ints = 2 + 49*12). Port of
///       the static spiral_pattern[] table plus init_spiral_pattern().
///       The columns following the second of each row are filled out here.
function map_init_spiral_pattern() {
    global.map_spiral_pattern = [
        0, 0,
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        3, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        4, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        4, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        6, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        6, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        6, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        6, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        6, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        7, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        7, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        7, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        7, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        7, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        7, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        16, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        24, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        24, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        24, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ];

    var _spiral_matrix = [
        1,  0,  0,  1,
        1,  1, -1,  0,
        0,  1, -1, -1,
        -1,  0,  0, -1,
        -1, -1,  1,  0,
        0, -1,  1,  1
    ];

    for (var _i = 0; _i < 49; _i++) {
        var _x = global.map_spiral_pattern[2 + 12 * _i];
        var _y = global.map_spiral_pattern[2 + 12 * _i + 1];

        for (var _j = 0; _j < 6; _j++) {
            global.map_spiral_pattern[2 + 12 * _i + 2 * _j] =
                _x * _spiral_matrix[4 * _j + 0] + _y * _spiral_matrix[4 * _j + 2];
            global.map_spiral_pattern[2 + 12 * _i + 2 * _j + 1] =
                _x * _spiral_matrix[4 * _j + 1] + _y * _spiral_matrix[4 * _j + 3];
        }
    }
}

/// @function map_init_static_tables()
/// @desc One-time initialisation of the static tables shared by all maps.
///       This is the single place the global existence check is done.
function map_init_static_tables() {
    if (!variable_global_exists("map_space_from_obj")) {
        map_init_space_table();
        map_init_spiral_pattern();
    }
}

/// @function map_get_spiral_pattern()
/// @desc Port of static Map::get_spiral_pattern(). Returns the 590-entry
///       (x, y) offset array.
function map_get_spiral_pattern() {
    map_init_static_tables();
    return global.map_spiral_pattern;
}

/// @function MapUpdateState()
/// @desc Port of Map::UpdateState.
function MapUpdateState() constructor {
    remove_signs_counter = 0;
    last_tick = 0;
    counter = 0;
    initial_pos = 0;
}

/// @function Map(_geom)
/// @desc Port of class Map. Landscape and game tile fields are stored as
///       flat per-field arrays of length geom.tile_count, indexed by MapPos.
function Map(_geom) constructor {
    geom = _geom;

    // Some code may still assume that map has at least size 3.
    if (geom.size < 3) {
        throw "Failed to create map with size less than 3.";
    }

    map_init_static_tables();

    // LandscapeTile fields
    height = array_create(geom.tile_count, 0);
    type_up = array_create(geom.tile_count, Terrain.water0);
    type_down = array_create(geom.tile_count, Terrain.water0);
    mineral = array_create(geom.tile_count, Minerals.none);
    res_amount = array_create(geom.tile_count, 0);
    obj = array_create(geom.tile_count, MapObject.none);

    // GameTile fields
    serf = array_create(geom.tile_count, 0);
    owner = array_create(geom.tile_count, 0);
    obj_index = array_create(geom.tile_count, 0);
    paths = array_create(geom.tile_count, 0);
    idle_serf = array_create(geom.tile_count, false);

    update_state = new MapUpdateState();
    update_state.last_tick = 0;
    update_state.counter = 0;
    update_state.remove_signs_counter = 0;
    update_state.initial_pos = 0;

    regions = ((geom.cols >> 5) * (geom.rows >> 5)) & 0xFFFF;

    /* Callbacks for map height/object changes: structs with methods
       on_height_changed(pos) and on_object_changed(pos). */
    handlers = [];

    spiral_pos_pattern = array_create(295, 0);

    // ---- Geometry accessors ----
    static get_size = function() { return geom.size; };
    static get_cols = function() { return geom.cols; };
    static get_rows = function() { return geom.rows; };
    static get_col_mask = function() { return geom.col_mask; };
    static get_row_mask = function() { return geom.row_mask; };
    static get_row_shift = function() { return geom.row_shift; };
    static get_region_count = function() { return regions; };

    // Extract col and row from MapPos
    static pos_col = function(_pos) { return geom.pos_col(_pos); };
    static pos_row = function(_pos) { return geom.pos_row(_pos); };

    // Translate col, row coordinate to MapPos value.
    static pos = function(_x, _y) { return geom.pos(_x, _y); };

    // Addition of two map positions.
    static pos_add = function(_pos, _x, _y) {
        return geom.pos_add(_pos, _x, _y);
    };
    static pos_add_off = function(_pos, _off) {
        return geom.pos_add_off(_pos, _off);
    };
    static pos_add_spirally = function(_pos, _off) {
        return pos_add_off(_pos, spiral_pos_pattern[_off]);
    };

    // Shortest distance between map positions.
    static dist_x = function(_pos1, _pos2) {
        return -geom.dist_x(_pos1, _pos2);
    };
    static dist_y = function(_pos1, _pos2) {
        return -geom.dist_y(_pos1, _pos2);
    };

    /// Get random position. Returns struct {pos, col, row}.
    static get_rnd_coord = function(_rnd) {
        var _c = _rnd.next_random() & geom.col_mask;
        var _r = _rnd.next_random() & geom.row_mask;
        return { pos: pos(_c, _r), col: _c, row: _r };
    };

    // Movement of map position according to directions.
    static move = function(_pos, _dir) { return geom.move(_pos, _dir); };

    static move_right = function(_pos) { return geom.move_right(_pos); };
    static move_down_right = function(_pos) { return geom.move_down_right(_pos); };
    static move_down = function(_pos) { return geom.move_down(_pos); };
    static move_left = function(_pos) { return geom.move_left(_pos); };
    static move_up_left = function(_pos) { return geom.move_up_left(_pos); };
    static move_up = function(_pos) { return geom.move_up(_pos); };

    static move_right_n = function(_pos, _n) { return geom.move_right_n(_pos, _n); };
    static move_down_n = function(_pos, _n) { return geom.move_down_n(_pos, _n); };

    // ---- Extractors for map data ----
    static get_paths = function(_pos) {
        return (paths[_pos] & 0x3f);
    };
    static has_path = function(_pos, _dir) {
        return ((paths[_pos] & (1 << _dir)) != 0);
    };
    static add_path = function(_pos, _dir) {
        paths[_pos] = paths[_pos] | (1 << _dir);
    };
    static del_path = function(_pos, _dir) {
        paths[_pos] = paths[_pos] & ~(1 << _dir);
    };

    static has_owner = function(_pos) { return (owner[_pos] != 0); };
    static get_owner = function(_pos) { return owner[_pos] - 1; };
    static set_owner = function(_pos, _owner) { owner[_pos] = _owner + 1; };
    static del_owner = function(_pos) { owner[_pos] = 0; };
    static get_height = function(_pos) { return height[_pos]; };

    static get_type_up = function(_pos) { return type_up[_pos]; };
    static get_type_down = function(_pos) { return type_down[_pos]; };

    static get_obj = function(_pos) { return obj[_pos]; };
    static get_idle_serf = function(_pos) { return idle_serf[_pos]; };
    static set_idle_serf = function(_pos) { idle_serf[_pos] = true; };
    static clear_idle_serf = function(_pos) { idle_serf[_pos] = false; };

    static get_obj_index = function(_pos) { return obj_index[_pos]; };
    static set_obj_index = function(_pos, _index) { obj_index[_pos] = _index; };
    static get_res_type = function(_pos) { return mineral[_pos]; };
    static get_res_amount = function(_pos) { return res_amount[_pos]; };
    static get_res_fish = function(_pos) { return get_res_amount(_pos); };
    static get_serf_index = function(_pos) { return serf[_pos]; };
    static has_serf = function(_pos) { return (serf[_pos] != 0); };

    static has_flag = function(_pos) { return (get_obj(_pos) == MapObject.flag); };
    static has_building = function(_pos) {
        return (get_obj(_pos) >= MapObject.small_building &&
                get_obj(_pos) <= MapObject.castle);
    };

    /* Whether any of the two up/down tiles at this pos are water. */
    static is_water_tile = function(_pos) {
        return (get_type_down(_pos) <= Terrain.water3 &&
                get_type_up(_pos) <= Terrain.water3);
    };

    /* Whether the position is completely surrounded by water. */
    static is_in_water = function(_pos) {
        return (is_water_tile(_pos) &&
                is_water_tile(move_up_left(_pos)) &&
                get_type_down(move_left(_pos)) <= Terrain.water3 &&
                get_type_up(move_up(_pos)) <= Terrain.water3);
    };

    static get_update_state = function() { return update_state; };
    static set_update_state = function(_update_state) {
        update_state.remove_signs_counter = _update_state.remove_signs_counter;
        update_state.last_tick = _update_state.last_tick;
        update_state.counter = _update_state.counter;
        update_state.initial_pos = _update_state.initial_pos;
    };

    // ---- map.cc ----

    // Get count of gold mineral deposits in the map.
    static get_gold_deposit = function() {
        var _count = 0;

        for (var _pos = 0; _pos < geom.tile_count; _pos++) {
            if (get_res_type(_pos) == Minerals.gold) {
                _count += get_res_amount(_pos);
            }
        }

        return _count;
    };

    /* Initialize spiral_pos_pattern from spiral_pattern. */
    static init_spiral_pos_pattern = function() {
        for (var _i = 0; _i < 295; _i++) {
            var _x = global.map_spiral_pattern[2 * _i] & geom.col_mask;
            var _y = global.map_spiral_pattern[2 * _i + 1] & geom.row_mask;

            spiral_pos_pattern[_i] = pos(_x, _y);
        }
    };

    /* Copy tile data from map generator into map tile data. */
    static init_tiles = function(_generator) {
        for (var _pos = 0; _pos < geom.tile_count; _pos++) {
            height[_pos] = _generator.get_height(_pos);
            type_up[_pos] = _generator.get_type_up(_pos);
            type_down[_pos] = _generator.get_type_down(_pos);
            mineral[_pos] = _generator.get_resource_type(_pos);
            res_amount[_pos] = _generator.get_resource_amount(_pos);
            obj[_pos] = _generator.get_obj(_pos);
        }
    };

    /* Change the height of a map position. */
    static set_height = function(_pos, _height) {
        height[_pos] = _height;

        /* Mark landscape dirty */
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            for (var _h = 0; _h < array_length(handlers); _h++) {
                handlers[_h].on_height_changed(move(_pos, _d));
            }
        }
    };

    /* Change the object at a map position. If index is non-negative
       also change this. The index should be reset to zero when a flag or
       building is removed. */
    static set_object = function(_pos, _obj, _index) {
        obj[_pos] = _obj;
        if (_index >= 0) {
            obj_index[_pos] = _index;
        }

        /* Notify about object change */
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            for (var _h = 0; _h < array_length(handlers); _h++) {
                handlers[_h].on_object_changed(move(_pos, _d));
            }
        }
    };

    /* Remove resources from the ground at a map position. */
    static remove_ground_deposit = function(_pos, _amount) {
        res_amount[_pos] -= _amount;

        if (res_amount[_pos] <= 0) {
            /* Also sets the ground deposit type to none. */
            mineral[_pos] = Minerals.none;
        }
    };

    /* Remove fish at a map position (must be water). */
    static remove_fish = function(_pos, _amount) {
        res_amount[_pos] -= _amount;
    };

    /* Set the index of the serf occupying map position. */
    static set_serf_index = function(_pos, _index) {
        serf[_pos] = _index;

        /* TODO Mark dirty in viewport. */
    };

    /* Update public parts of the map data. */
    static update_public = function(_pos, _rnd) {
        /* Update other map objects */
        var _r = 0;
        switch (get_obj(_pos)) {
        case MapObject.stub:
            if ((_rnd.next_random() & 3) == 0) {
                set_object(_pos, MapObject.none, -1);
            }
            break;
        case MapObject.felled_pine0: case MapObject.felled_pine1:
        case MapObject.felled_pine2: case MapObject.felled_pine3:
        case MapObject.felled_pine4:
        case MapObject.felled_tree0: case MapObject.felled_tree1:
        case MapObject.felled_tree2: case MapObject.felled_tree3:
        case MapObject.felled_tree4:
            set_object(_pos, MapObject.stub, -1);
            break;
        case MapObject.new_pine:
            _r = _rnd.next_random();
            if ((_r & 0x300) == 0) {
                set_object(_pos, MapObject.pine0 + (_r & 7), -1);
            }
            break;
        case MapObject.new_tree:
            _r = _rnd.next_random();
            if ((_r & 0x300) == 0) {
                set_object(_pos, MapObject.tree0 + (_r & 7), -1);
            }
            break;
        case MapObject.seeds0: case MapObject.seeds1:
        case MapObject.seeds2: case MapObject.seeds3:
        case MapObject.seeds4:
        case MapObject.field0: case MapObject.field1:
        case MapObject.field2: case MapObject.field3:
        case MapObject.field4:
            set_object(_pos, get_obj(_pos) + 1, -1);
            break;
        case MapObject.seeds5:
            set_object(_pos, MapObject.field0, -1);
            break;
        case MapObject.field_expired:
            set_object(_pos, MapObject.none, -1);
            break;
        case MapObject.sign_large_gold: case MapObject.sign_small_gold:
        case MapObject.sign_large_iron: case MapObject.sign_small_iron:
        case MapObject.sign_large_coal: case MapObject.sign_small_coal:
        case MapObject.sign_large_stone: case MapObject.sign_small_stone:
        case MapObject.sign_empty:
            if (update_state.remove_signs_counter == 0) {
                set_object(_pos, MapObject.none, -1);
            }
            break;
        case MapObject.field5:
            set_object(_pos, MapObject.field_expired, -1);
            break;
        default:
            break;
        }
    };

    /* Update hidden parts of the map data. */
    static update_hidden = function(_pos, _rnd) {
        /* Update fish resources in water */
        if (is_in_water(_pos) && res_amount[_pos] > 0) {
            var _r = _rnd.next_random();

            if (res_amount[_pos] < 10 && (_r & 0x3f00) != 0) {
                /* Spawn more fish. */
                res_amount[_pos] += 1;
            }

            /* Move in a random direction of: right, down right, left, up left */
            var _adj_pos = _pos;
            switch ((_r >> 2) & 3) {
                case 0: _adj_pos = move_right(_adj_pos); break;
                case 1: _adj_pos = move_down_right(_adj_pos); break;
                case 2: _adj_pos = move_left(_adj_pos); break;
                case 3: _adj_pos = move_up_left(_adj_pos); break;
                default: throw "NOT_REACHED: Map.update_hidden"; break;
            }

            if (is_in_water(_adj_pos)) {
                /* Migrate a fish to adjacent water space. */
                res_amount[_pos] -= 1;
                res_amount[_adj_pos] += 1;
            }
        }
    };

    /* Update map data as part of the game progression. */
    static update = function(_tick, _rnd) {
        // uint16_t delta = tick - update_state.last_tick;
        var _delta = (_tick - update_state.last_tick) & 0xFFFF;
        update_state.last_tick = _tick & 0xFFFF;
        update_state.counter -= _delta;

        var _iters = 0;
        while (update_state.counter < 0) {
            _iters += regions;
            update_state.counter += 20;
        }

        var _pos = update_state.initial_pos;

        for (var _i = 0; _i < _iters; _i++) {
            update_state.remove_signs_counter -= 1;
            if (update_state.remove_signs_counter < 0) {
                update_state.remove_signs_counter = 16;
            }

            /* Test if moving 23 positions right crosses map boundary. */
            if (pos_col(_pos) + 23 < geom.cols) {
                _pos = move_right_n(_pos, 23);
            } else {
                _pos = move_right_n(_pos, 23);
                _pos = move_down(_pos);
            }

            /* Update map at position. */
            update_hidden(_pos, _rnd);
            update_public(_pos, _rnd);
        }

        update_state.initial_pos = _pos;
    };

    /* Return true if the road segment from pos in direction dir
       can be successfully constructed at the current time. */
    static is_road_segment_valid = function(_pos, _dir) {
        var _other_pos = move(_pos, _dir);

        var _obj = get_obj(_other_pos);
        if ((get_paths(_other_pos) != 0 && _obj != MapObject.flag) ||
            global.map_space_from_obj[_obj] >= Space.semipassable) {
            return false;
        }

        if (!has_owner(_other_pos) ||
            get_owner(_other_pos) != get_owner(_pos)) {
            return false;
        }

        if (is_in_water(_pos) != is_in_water(_other_pos) &&
            !(has_flag(_pos) || has_flag(_other_pos))) {
            return false;
        }

        return true;
    };

    /* Actually place road segments. _road is a struct with fields
       `source` (MapPos) and `dirs` (array of Direction). */
    static place_road_segments = function(_road) {
        var _pos = _road.source;
        var _dirs = _road.dirs;
        var _len = array_length(_dirs);
        for (var _it = 0; _it < _len; _it++) {
            var _cur = _dirs[_it];
            var _rev_dir = reverse_direction(_cur);

            if (!is_road_segment_valid(_pos, _cur)) {
                /* Not valid after all. Backtrack and abort.
                   This is needed to check that the road
                   does not cross itself. */
                while (_it != 0) {
                    _it--;
                    var _back_rev_dir = _dirs[_it];
                    var _back_dir = reverse_direction(_back_rev_dir);

                    paths[_pos] = paths[_pos] & ~(1 << _back_dir);
                    var _back_pos = move(_pos, _back_dir);
                    paths[_back_pos] = paths[_back_pos] & ~(1 << _back_rev_dir);

                    _pos = move(_pos, _back_dir);
                }

                return false;
            }

            paths[_pos] = paths[_pos] | (1 << _cur);
            var _next_pos = move(_pos, _cur);
            paths[_next_pos] = paths[_next_pos] | (1 << _rev_dir);

            _pos = move(_pos, _cur);
        }

        return true;
    };

    static remove_road_backref_until_flag = function(_pos, _dir) {
        while (true) {
            _pos = move(_pos, _dir);

            /* Clear backreference */
            paths[_pos] = paths[_pos] & ~(1 << reverse_direction(_dir));

            if (get_obj(_pos) == MapObject.flag) {
                break;
            }

            /* Find next direction of path. */
            _dir = Direction.none;
            for (var _d = Direction.right; _d <= Direction.up; _d++) {
                if (has_path(_pos, _d)) {
                    _dir = _d;
                    break;
                }
            }

            if (_dir == Direction.none) {
                return false;
            }
        }

        return true;
    };

    static remove_road_backrefs = function(_pos) {
        if (get_paths(_pos) == 0) {
            return false;
        }

        /* Find directions of path segments to be split. */
        var _path_1_dir = Direction.none;
        var _it = Direction.right;
        for (; _it <= Direction.up; _it++) {
            if (has_path(_pos, _it)) {
                _path_1_dir = _it;
                break;
            }
        }

        var _path_2_dir = Direction.none;
        _it++;
        for (; _it <= Direction.up; _it++) {
            if (has_path(_pos, _it)) {
                _path_2_dir = _it;
                break;
            }
        }

        if (_path_1_dir == Direction.none || _path_2_dir == Direction.none) {
            return false;
        }

        if (!remove_road_backref_until_flag(_pos, _path_1_dir)) {
            return false;
        }
        if (!remove_road_backref_until_flag(_pos, _path_2_dir)) {
            return false;
        }

        return true;
    };

    /* C++ takes pos by pointer and returns the next direction; here a
       struct {pos, dir} is returned instead. */
    static remove_road_segment = function(_pos, _dir) {
        /* Clear forward reference. */
        paths[_pos] = paths[_pos] & ~(1 << _dir);
        _pos = move(_pos, _dir);

        /* Clear backreference. */
        paths[_pos] = paths[_pos] & ~(1 << reverse_direction(_dir));

        /* Find next direction of path. */
        _dir = Direction.none;
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            if (has_path(_pos, _d)) {
                _dir = _d;
                break;
            }
        }

        return { pos: _pos, dir: _dir };
    };

    static road_segment_in_water = function(_pos, _dir) {
        if (_dir > Direction.down) {
            _pos = move(_pos, _dir);
            _dir = reverse_direction(_dir);
        }

        var _water = false;

        switch (_dir) {
            case Direction.right:
                if (get_type_down(_pos) <= Terrain.water3 &&
                    get_type_up(move_up(_pos)) <= Terrain.water3) {
                    _water = true;
                }
                break;
            case Direction.down_right:
                if (get_type_up(_pos) <= Terrain.water3 &&
                    get_type_down(_pos) <= Terrain.water3) {
                    _water = true;
                }
                break;
            case Direction.down:
                if (get_type_up(_pos) <= Terrain.water3 &&
                    get_type_down(move_left(_pos)) <= Terrain.water3) {
                    _water = true;
                }
                break;
            default:
                throw "NOT_REACHED: Map.road_segment_in_water";
                break;
        }

        return _water;
    };

    static add_change_handler = function(_handler) {
        array_push(handlers, _handler);
    };

    static del_change_handler = function(_handler) {
        // std::list::remove removes every element equal to the handler.
        for (var _h = array_length(handlers) - 1; _h >= 0; _h--) {
            if (handlers[_h] == _handler) {
                array_delete(handlers, _h, 1);
            }
        }
    };

    static types_within = function(_pos, _low, _high) {
        if ((get_type_up(_pos) >= _low &&
             get_type_up(_pos) <= _high) &&
            (get_type_down(_pos) >= _low &&
             get_type_down(_pos) <= _high) &&
            (get_type_down(move_left(_pos)) >= _low &&
             get_type_down(move_left(_pos)) <= _high) &&
            (get_type_up(move_up_left(_pos)) >= _low &&
             get_type_up(move_up_left(_pos)) <= _high) &&
            (get_type_down(move_up_left(_pos)) >= _low &&
             get_type_down(move_up_left(_pos)) <= _high) &&
            (get_type_up(move_up(_pos)) >= _low &&
             get_type_up(move_up(_pos)) <= _high)) {
            return true;
        }

        return false;
    };

    // ---- Constructor tail (after statics are declared) ----
    init_spiral_pos_pattern();
}
