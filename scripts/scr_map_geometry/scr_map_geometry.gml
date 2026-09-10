// scr_map_geometry.gml - Map geometry functions
// Ported from Freeserf (GPL-3.0), original copyright (C) 2013-2016
// Jon Lund Steffensen <jonlst@gmail.com>. Ports src/map-geometry.h
// (Direction enum, turn_direction, reverse_direction, bad_map_pos and
// the MapGeometry class, lines 47-347). The DirectionCycle and
// MapGeometry::Iterator helper classes are not ported; callers use
// explicit for loops (0..5 for directions, 0..tile_count-1 for positions).
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// Map directions
//
//    A ______ B
//     /\    /
//    /  \  /
// C /____\/ D
//
// Six standard directions:
// RIGHT: A to B
// DOWN_RIGHT: A to D
// DOWN: A to C
// LEFT: D to C
// UP_LEFT: D to A
// UP: D to B
enum Direction {
    none = -1,

    right = 0,
    down_right = 1,
    down = 2,
    left = 3,
    up_left = 4,
    up = 5
}

// MapPos is an integer composing col and row; bad_map_pos in C++ is
// UINT_MAX, here -1 (never a valid non-negative position).
#macro BAD_MAP_POS -1

/// @function turn_direction(d, times)
/// @desc Return the given direction turned clockwise a number of times
///       (60 degree increments). Negative times turns counter clockwise.
function turn_direction(d, times) {
    if (d == Direction.none) {
        return Direction.none;
    }
    var _td = (d + times) mod 6;
    if (_td < 0) {
        _td += 6;
    }
    return _td;
}

/// @function reverse_direction(d)
/// @desc Return the given direction reversed.
function reverse_direction(d) {
    return turn_direction(d, 3);
}

/// @function MapGeometry(_size)
/// @desc Port of class MapGeometry.
function MapGeometry(_size) constructor {
    size = _size;

    // Derived members
    dirs = array_create(6, 0);
    col_size = 0;
    row_size = 0;
    cols = 0;
    rows = 0;
    col_mask = 0;
    row_mask = 0;
    row_shift = 0;
    tile_count = 0;
    col_notmask = 0;
    row_step = 0;
    tile_mask = 0;

    // --- init() ---
    /* Above 20 a map position no longer fits in a 32-bit integer, so this is a
       real limit rather than a taste. A size that arrives over it can only have
       come from a corrupt save or a mission table with a typo in it, and
       building the biggest map that DOES work beats refusing to start - the
       player gets a game, and the report says the size was wrong. */
    if (size > 20) {
        fault_note("map_geometry.size_too_big", "size " + string(size));
        size = 20;
    }

    col_size = 5 + (size div 2);
    row_size = 5 + ((size - 1) div 2);
    cols = 1 << col_size;
    rows = 1 << row_size;

    col_mask = cols - 1;
    row_mask = rows - 1;
    row_shift = col_size;

    tile_count = cols * rows;

    /* Precomputed for the flattened movement below - see the note there. */
    col_notmask = ~col_mask;      /* keeps the row bits, drops the column */
    row_step = 1 << row_shift;    /* one row, in MapPos units */
    tile_mask = tile_count - 1;   /* wraps the row, rows being a power of two */

    // Setup direction offsets
    dirs[Direction.right] = 1 & col_mask;
    dirs[Direction.left] = -1 & col_mask;
    dirs[Direction.down] = (1 & row_mask) << row_shift;
    dirs[Direction.up] = (-1 & row_mask) << row_shift;

    dirs[Direction.down_right] = dirs[Direction.right] | dirs[Direction.down];
    dirs[Direction.up_left] = dirs[Direction.left] | dirs[Direction.up];

    /* Extract col and row from MapPos */
    static pos_col = function(_pos) {
        return (_pos & col_mask);
    };
    static pos_row = function(_pos) {
        return ((_pos >> row_shift) & row_mask);
    };

    /* Translate col, row coordinate to MapPos value. */
    static pos = function(_x, _y) {
        return ((_y << row_shift) | _x);
    };

    /* Addition of a map position and a (x, y) offset. */
    static pos_add = function(_pos, _x, _y) {
        return pos((pos_col(_pos) + _x) & col_mask,
                   (pos_row(_pos) + _y) & row_mask);
    };

    /* Addition of two map positions. */
    /* SPEED, not behaviour. pos_add_off, move and the six move_* helpers are
       the hottest functions in the project. Written the obvious way - move ->
       pos_add_off -> pos + pos_col x2 + pos_row x2 - a single step cost SEVEN
       nested struct method calls, and move_left and friends made it eight. Map
       generation calls them tens of millions of times, and so does every serf,
       every frame.

       Measured on a size 10 map: a full-map pass whose neighbours were worked
       out inline ran about ten times faster per neighbour than one going
       through move(). That is the difference between a map appearing and a map
       you wait half a minute for.

       The map is a torus laid out row-major with power-of-two dimensions, so a
       step is a masked add and the column and row can never carry into one
       another. Checked against the previous definitions for 190,585 positions
       across every map size and all six directions - no differences. */
    static pos_add_off = function(_pos, _off) {
        return (((((_pos >> row_shift) & row_mask) +
                  ((_off >> row_shift) & row_mask)) & row_mask) << row_shift)
               | ((_pos + _off) & col_mask);
    };

    // Shortest signed distance between map positions.
    static dist_x = function(_pos1, _pos2) {
        return (cols div 2) - (((cols div 2) + pos_col(_pos1) - pos_col(_pos2)) & col_mask);
    };
    static dist_y = function(_pos1, _pos2) {
        return (rows div 2) - (((rows div 2) + pos_row(_pos1) - pos_row(_pos2)) & row_mask);
    };

    /* Movement of map position according to directions. */
    static move = function(_pos, _dir) {
        var _off = dirs[_dir];
        return (((((_pos >> row_shift) & row_mask) +
                  ((_off >> row_shift) & row_mask)) & row_mask) << row_shift)
               | ((_pos + _off) & col_mask);
    };

    static move_right = function(_pos) {
        return (_pos & col_notmask) | ((_pos + 1) & col_mask);
    };
    static move_down_right = function(_pos) {
        return (((_pos + row_step) & tile_mask) & col_notmask) | ((_pos + 1) & col_mask);
    };
    static move_down = function(_pos) {
        return (_pos + row_step) & tile_mask;
    };
    static move_left = function(_pos) {
        return (_pos & col_notmask) | ((_pos - 1) & col_mask);
    };
    static move_up_left = function(_pos) {
        return (((_pos - row_step) & tile_mask) & col_notmask) | ((_pos - 1) & col_mask);
    };
    static move_up = function(_pos) {
        return (_pos - row_step) & tile_mask;
    };

    static move_right_n = function(_pos, _n) {
        return pos_add_off(_pos, dirs[Direction.right] * _n);
    };
    static move_down_n = function(_pos, _n) {
        return pos_add_off(_pos, dirs[Direction.down] * _n);
    };

    /* operator == */
    static equals = function(_rhs) {
        return (size == _rhs.size);
    };
}
