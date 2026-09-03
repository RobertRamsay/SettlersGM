// scr_minimap.gml - Ported from Freeserf src/minimap.h / src/minimap.cc
// (GPL-3.0), original copyright (C) 2013-2014 Jon Lund Steffensen
// <jonlst@gmail.com>. Minimap GUI component.
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Differences from the C++:
//  - The per-tile colour vector `minimap` (init_minimap) is kept as a GML
//    array `minimap` AND baked into two GameMaker surfaces sized
//    map cols x rows (one pixel per tile): `minimap_surface_even` holds the
//    even map rows, `minimap_surface_odd` the odd map rows (the other rows
//    are transparent). draw_minimap_map() blits them with
//    draw_surface_part_ext instead of calling draw_minimap_point() per tile.
//    Pixel (col,row) is stored at surface x = (col - row div 2) mod cols so
//    that, drawn at `scale`, a tile lands at
//        scale*col - scale*(row div 2)            (even rows)
//        scale*col - scale*(row div 2) - scale div 2  (odd rows)
//    which is exactly Freeserf's  col*scale - (row*scale)/2.
//    The surfaces are rebuilt when set_map() is called or when they were
//    lost (surface_exists check in draw_minimap_map).
//  - Everything else (ownership, roads, buildings, traffic, grid) still goes
//    through draw_minimap_point() -> gfx_fill_rect, like the C++.
//  - Frame clipping to the object's rectangle is done explicitly in
//    draw_minimap_point() and minimap_draw_surface_tile().

/// MinimapGame::OwnershipMode
enum OwnershipMode {
    none = 0,
    mixed = 1,
    solid_mode = 2,   // C++ `Solid`: `solid` is a GML built-in variable
    last = 2
}

#macro MINIMAP_MAX_SCALE 8

function minimap_init_tables() {
    if (variable_global_exists("minimap_color_offset")) {
        return;
    }

    // static const int color_offset[]
    global.minimap_color_offset = [
        0, 85, 102, 119, 17, 17, 17, 17,
        34, 34, 34, 51, 51, 51, 68, 68
    ];

    // static const Color colors[]  (stored as [r, g, b] triples)
    var _c = [
        [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf],
        [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf],
        [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf],
        [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf],
        [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf],
        [0x00, 0x00, 0xaf], [0x00, 0x00, 0xaf], [0x73, 0xb3, 0x43],
        [0x73, 0xb3, 0x43], [0x6b, 0xab, 0x3b], [0x63, 0xa3, 0x33],
        [0x5f, 0x9b, 0x2f], [0x57, 0x93, 0x27], [0x53, 0x8b, 0x23],
        [0x4f, 0x83, 0x1b], [0x47, 0x7f, 0x17], [0x3f, 0x73, 0x13],
        [0x3b, 0x6b, 0x13], [0x33, 0x63, 0x0f], [0x2f, 0x57, 0x0b],
        [0x2b, 0x4f, 0x0b], [0x23, 0x43, 0x0b], [0x1f, 0x3b, 0x07],
        [0x1b, 0x33, 0x07], [0xef, 0xcf, 0xaf], [0xef, 0xcf, 0xaf],
        [0xe3, 0xbf, 0x9f], [0xd7, 0xb3, 0x8f], [0xd7, 0xb3, 0x8f],
        [0xcb, 0xa3, 0x7f], [0xbf, 0x97, 0x73], [0xbf, 0x97, 0x73],
        [0xb3, 0x87, 0x67], [0xab, 0x7b, 0x5b], [0xab, 0x7b, 0x5b],
        [0x9f, 0x6f, 0x4f], [0x93, 0x63, 0x43], [0x93, 0x63, 0x43],
        [0x87, 0x57, 0x3b], [0x7b, 0x4f, 0x33], [0x7b, 0x4f, 0x33],
        [0xd7, 0xb3, 0x8f], [0xd7, 0xb3, 0x8f], [0xcb, 0xa3, 0x7f],
        [0xcb, 0xa3, 0x7f], [0xbf, 0x97, 0x73], [0xbf, 0x97, 0x73],
        [0xb3, 0x87, 0x67], [0xab, 0x7b, 0x5b], [0x9f, 0x6f, 0x4f],
        [0x93, 0x63, 0x43], [0x87, 0x57, 0x3b], [0x7b, 0x4f, 0x33],
        [0x73, 0x43, 0x2b], [0x67, 0x3b, 0x23], [0x5b, 0x33, 0x1b],
        [0x4f, 0x2b, 0x17], [0x43, 0x23, 0x13], [0xff, 0xff, 0xff],
        [0xff, 0xff, 0xff], [0xef, 0xef, 0xef], [0xef, 0xef, 0xef],
        [0xdf, 0xdf, 0xdf], [0xd3, 0xd3, 0xd3], [0xc3, 0xc3, 0xc3],
        [0xb3, 0xb3, 0xb3], [0xa7, 0xa7, 0xa7], [0x97, 0x97, 0x97],
        [0x87, 0x87, 0x87], [0x7b, 0x7b, 0x7b], [0x6b, 0x6b, 0x6b],
        [0x5b, 0x5b, 0x5b], [0x4f, 0x4f, 0x4f], [0x3f, 0x3f, 0x3f],
        [0x2f, 0x2f, 0x2f], [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3],
        [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3],
        [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3],
        [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3],
        [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3],
        [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3], [0x07, 0x07, 0xb3],
        [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7],
        [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7],
        [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7],
        [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7],
        [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7],
        [0x0b, 0x0b, 0xb7], [0x0b, 0x0b, 0xb7], [0x13, 0x13, 0xbb],
        [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb],
        [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb],
        [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb],
        [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb],
        [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb], [0x13, 0x13, 0xbb],
        [0x13, 0x13, 0xbb]
    ];
    global.minimap_colors_rgb = _c;
    var _n = array_length(_c);
    global.minimap_colors = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) {
        global.minimap_colors[_i] = make_colour_rgb(_c[_i][0], _c[_i][1], _c[_i][2]);
    }

    global.minimap_color_black = make_colour_rgb(0x00, 0x00, 0x00);
    global.minimap_color_grid = make_colour_rgb(0xab, 0x7b, 0x5b);

    // const int building_remap[] (MinimapGame::draw_minimap_buildings)
    global.minimap_building_remap = [
        BuildingType.castle,
        BuildingType.stock, BuildingType.tower, BuildingType.hut,
        BuildingType.fortress, BuildingType.tool_maker, BuildingType.sawmill,
        BuildingType.weapon_smith, BuildingType.stonecutter,
        BuildingType.boatbuilder, BuildingType.forester, BuildingType.lumberjack,
        BuildingType.pig_farm, BuildingType.farm, BuildingType.fisher,
        BuildingType.mill, BuildingType.butcher, BuildingType.baker,
        BuildingType.stone_mine, BuildingType.coal_mine, BuildingType.iron_mine,
        BuildingType.gold_mine, BuildingType.steel_smelter,
        BuildingType.gold_smelter
    ];
}

/// Determines the byte order GameMaker uses for buffer_get_surface /
/// buffer_set_surface on this platform by drawing a known colour into a 1x1
/// surface and reading it back. Result: global.minimap_pixel_order =
/// [red_byte_index, green_byte_index, blue_byte_index, alpha_byte_index].
function minimap_probe_pixel_order() {
    if (variable_global_exists("minimap_pixel_order")) {
        return;
    }
    // Default assumption: R, G, B, A.
    global.minimap_pixel_order = [0, 1, 2, 3];

    var _surf = surface_create(1, 1);
    surface_set_target(_surf);
    draw_clear_alpha(make_colour_rgb(0x11, 0x22, 0x33), 1);
    surface_reset_target();

    var _buf = buffer_create(4, buffer_fixed, 1);
    buffer_get_surface(_buf, _surf, 0);
    var _bytes = [0, 0, 0, 0];
    for (var _i = 0; _i < 4; _i++) {
        _bytes[_i] = buffer_peek(_buf, _i, buffer_u8);
    }
    buffer_delete(_buf);
    surface_free(_surf);

    var _order = [-1, -1, -1, -1];
    for (var _i = 0; _i < 4; _i++) {
        if (_bytes[_i] == 0x11) {
            _order[0] = _i;
        } else if (_bytes[_i] == 0x22) {
            _order[1] = _i;
        } else if (_bytes[_i] == 0x33) {
            _order[2] = _i;
        } else if (_bytes[_i] == 0xff) {
            _order[3] = _i;
        }
    }
    if (_order[0] >= 0 && _order[1] >= 0 && _order[2] >= 0 && _order[3] >= 0) {
        global.minimap_pixel_order = _order;
    } else {
        show_debug_message("minimap: could not probe surface pixel order, assuming RGBA");
    }
}

/// Minimap : GuiObject  (C++: explicit Minimap(PMap map))
/// _map may be undefined (C++ nullptr), e.g. GameInitBox's preview minimap.
function Minimap(_map) : GuiObject() constructor {
    minimap_init_tables();

    map = undefined;

    offset_x = 0;
    offset_y = 0;
    scale = 1;

    draw_grid = false;

    // std::vector<Color> minimap  (GM colours, one per tile)
    minimap = [];

    // Baked surfaces (see file header).
    minimap_surface_even = -1;
    minimap_surface_odd = -1;
    minimap_surface_cols = 0;
    minimap_surface_rows = 0;

    static get_scale = function() {
        return scale;
    };

    static get_draw_grid = function() {
        return draw_grid;
    };

    static set_draw_grid = function(_draw_grid) {
        draw_grid = _draw_grid;
        set_redraw();
    };

    /// Frees the GameMaker surfaces (call when the minimap is discarded).
    static free_surfaces = function() {
        if (minimap_surface_even != -1) {
            if (surface_exists(minimap_surface_even)) {
                surface_free(minimap_surface_even);
            }
            minimap_surface_even = -1;
        }
        if (minimap_surface_odd != -1) {
            if (surface_exists(minimap_surface_odd)) {
                surface_free(minimap_surface_odd);
            }
            minimap_surface_odd = -1;
        }
        minimap_surface_cols = 0;
        minimap_surface_rows = 0;
    };

    /* Initialize minimap data. */
    static init_minimap = function() {
        if (map == undefined) {
            return;
        }

        minimap = [];

        var _tile_count = map.geom.tile_count;
        for (var _pos = 0; _pos < _tile_count; _pos++) {
            var _p = _pos;
            var _type_off = global.minimap_color_offset[map.get_type_up(_p)];

            _p = map.move_right(_p);
            var _h1 = map.get_height(_p);

            _p = map.move_left(map.move_down(_p));
            var _h2 = map.get_height(_p);

            var _h_off = _h2 - _h1 + 8;
            array_push(minimap, global.minimap_colors[_type_off + _h_off]);
        }

        build_surfaces();
    };

    /// Bakes `minimap` into minimap_surface_even / minimap_surface_odd
    /// (one pixel per tile, pre-sheared: x = (col - row div 2) mod cols).
    static build_surfaces = function() {
        free_surfaces();
        if (map == undefined) {
            return;
        }

        var _cols = map.get_cols();
        var _rows = map.get_rows();
        if (_cols == 0 || _rows == 0) {
            return;
        }

        minimap_probe_pixel_order();
        var _ri = global.minimap_pixel_order[0];
        var _gi = global.minimap_pixel_order[1];
        var _bi = global.minimap_pixel_order[2];
        var _ai = global.minimap_pixel_order[3];

        var _buf_even = buffer_create(_cols * _rows * 4, buffer_fixed, 1);
        var _buf_odd = buffer_create(_cols * _rows * 4, buffer_fixed, 1);
        buffer_fill(_buf_even, 0, buffer_u8, 0, _cols * _rows * 4);
        buffer_fill(_buf_odd, 0, buffer_u8, 0, _cols * _rows * 4);

        var _color_index = 0;
        for (var _row = 0; _row < _rows; _row++) {
            var _buf = _buf_even;
            if ((_row mod 2) == 1) {
                _buf = _buf_odd;
            }
            for (var _col = 0; _col < _cols; _col++) {
                var _color = minimap[_color_index];
                _color_index += 1;
                var _sx = (_col - (_row div 2)) mod _cols;
                if (_sx < 0) {
                    _sx += _cols;
                }
                var _off = (_row * _cols + _sx) * 4;
                buffer_poke(_buf, _off + _ri, buffer_u8, colour_get_red(_color));
                buffer_poke(_buf, _off + _gi, buffer_u8, colour_get_green(_color));
                buffer_poke(_buf, _off + _bi, buffer_u8, colour_get_blue(_color));
                buffer_poke(_buf, _off + _ai, buffer_u8, 255);
            }
        }

        minimap_surface_even = surface_create(_cols, _rows);
        minimap_surface_odd = surface_create(_cols, _rows);
        buffer_set_surface(_buf_even, minimap_surface_even, 0);
        buffer_set_surface(_buf_odd, minimap_surface_odd, 0);
        buffer_delete(_buf_even);
        buffer_delete(_buf_odd);

        minimap_surface_cols = _cols;
        minimap_surface_rows = _rows;
    };

    static draw_minimap_point = function(_col, _row, _color, _density) {
        var _map_width = map.get_cols() * scale;
        var _map_height = map.get_rows() * scale;

        if (0 == _map_width || 0 == _map_height) {
            return;
        }

        var _mm_y = _row * scale - offset_y;
        // static_cast<int>(mm_y / map_height): C++ int division truncates
        // toward zero, like GML `div`.
        _col -= (map.get_rows() div 2) * (_mm_y div _map_height);
        _mm_y = _mm_y mod _map_height;

        while (_mm_y < height) {
            if (_mm_y >= -_density) {
                var _mm_x = _col * scale - ((_row * scale) div 2) - offset_x;
                _mm_x = _mm_x mod _map_width;
                while (_mm_x < width) {
                    if (_mm_x >= -_density) {
                        minimap_fill_rect_clipped(_mm_x, _mm_y, _density, _density, _color);
                    }
                    _mm_x += _map_width;
                }
            }
            _col -= map.get_rows() div 2;
            _mm_y += _map_height;
        }
    };

    /// frame->fill_rect clipped to this object's rectangle (Freeserf's Frame
    /// is a sub-frame clipped to the object's size).
    static minimap_fill_rect_clipped = function(_rx, _ry, _rw, _rh, _color) {
        var _x0 = max(_rx, 0);
        var _y0 = max(_ry, 0);
        var _x1 = min(_rx + _rw, width);
        var _y1 = min(_ry + _rh, height);
        if (_x1 <= _x0 || _y1 <= _y0) {
            return;
        }
        gfx_fill_rect(_x0, _y0, _x1 - _x0, _y1 - _y0, _color);
    };

    /// Draws one repetition of a baked surface whose top-left tile corner
    /// lands at local (_dx, _dy) at the current scale, clipped to the object.
    static minimap_draw_surface_tile = function(_surf, _dx, _dy) {
        var _map_width = minimap_surface_cols * scale;
        var _map_height = minimap_surface_rows * scale;
        var _x0 = max(_dx, 0);
        var _y0 = max(_dy, 0);
        var _x1 = min(_dx + _map_width, width);
        var _y1 = min(_dy + _map_height, height);
        if (_x1 <= _x0 || _y1 <= _y0) {
            return;
        }
        var _left = (_x0 - _dx) / scale;
        var _top = (_y0 - _dy) / scale;
        var _w = (_x1 - _x0) / scale;
        var _h = (_y1 - _y0) / scale;
        draw_surface_part_ext(_surf, _left, _top, _w, _h,
                              global.gfx_ox + _x0, global.gfx_oy + _y0,
                              scale, scale, c_white, 1);
    };

    static draw_minimap_map = function() {
        if (map == undefined) {
            return;
        }
        if (minimap_surface_even == -1 || minimap_surface_odd == -1 ||
            !surface_exists(minimap_surface_even) || !surface_exists(minimap_surface_odd) ||
            minimap_surface_cols != map.get_cols() || minimap_surface_rows != map.get_rows()) {
            if (array_length(minimap) != map.geom.tile_count) {
                init_minimap();
            } else {
                build_surfaces();
            }
        }
        if (minimap_surface_even == -1 || minimap_surface_odd == -1) {
            return;
        }

        var _map_width = map.get_cols() * scale;
        var _map_height = map.get_rows() * scale;
        if (0 == _map_width || 0 == _map_height) {
            return;
        }

        var _row_shift = (map.get_rows() div 2) * scale;
        var _half = scale div 2;

        // Vertical repetitions: tile j has its row 0 at y = j*map_height - offset_y
        // and is shifted left by j*row_shift (col -= rows/2 per wrap).
        var _j = floor(offset_y / _map_height);
        var _ty = _j * _map_height - offset_y;
        while (_ty < height) {
            var _tx = -offset_x - _j * _row_shift;
            _tx = _tx mod _map_width;
            if (_tx > 0) {
                _tx -= _map_width;
            }
            var _sx = _tx;
            while (_sx < width) {
                minimap_draw_surface_tile(minimap_surface_even, _sx, _ty);
                _sx += _map_width;
            }
            // Odd rows are shifted by an extra scale/2 to the left
            // (Freeserf: col*scale - (row*scale)/2).
            _sx = _tx;
            while (_sx - _half < width) {
                minimap_draw_surface_tile(minimap_surface_odd, _sx - _half, _ty);
                _sx += _map_width;
            }
            _j += 1;
            _ty += _map_height;
        }
    };

    static draw_minimap_grid = function() {
        var _rows_px = map.get_rows() * scale;
        for (var _py = 0; _py < _rows_px; _py += 2) {
            draw_minimap_point(0, _py, global.minimap_color_grid, 1);
            draw_minimap_point(0, _py + 1, global.minimap_color_black, 1);
        }

        var _cols_px = map.get_cols() * scale;
        for (var _px = 0; _px < _cols_px; _px += 2) {
            draw_minimap_point(_px, 0, global.minimap_color_grid, 1);
            draw_minimap_point(_px + 1, 0, global.minimap_color_black, 1);
        }
    };

    static draw_minimap_rect = function() {
        var _px = width div 2;
        var _py = height div 2;
        gfx_draw_sprite_off(_px, _py, Asset.game_object, 33, true);
    };

    static internal_draw = function() {
        if (map == undefined) {
            gfx_fill_rect(0, 0, width, height, global.minimap_color_black);
            return;
        }

        draw_minimap_map();

        if (draw_grid) {
            draw_minimap_grid();
        }
    };

    static handle_scroll = function(_up) {
        var _scale = 0;

        if (_up) {
            _scale = scale + 1;
        } else {
            _scale = scale - 1;
        }

        set_scale(clamp(_scale, 1, MINIMAP_MAX_SCALE));

        return 0;
    };

    static handle_drag = function(_dx, _dy) {
        if (_dx != 0 || _dy != 0) {
            move_by_pixels(_dx, _dy);
        }

        return true;
    };

    static set_map = function(_map) {
        map = _map;
        init_minimap();
        set_redraw();
    };

    /* Set the scale of the map (zoom). Must be positive. */
    static set_scale = function(_scale) {
        var _pos = get_current_map_pos();
        scale = _scale;
        move_to_map_pos(_pos);

        set_redraw();
    };

    /// Returns [sx, sy].
    static screen_pix_from_map_pix = function(_mx, _my) {
        var _pwidth = map.get_cols() * scale;
        var _pheight = map.get_rows() * scale;

        var _sx = _mx - offset_x;
        var _sy = _my - offset_y;

        while (_sy < 0) {
            _sx -= _pheight div 2;
            _sy += _pheight;
        }

        while (_sy >= _pheight) {
            _sx += _pheight div 2;
            _sy -= _pheight;
        }

        while (_sx < 0) {
            _sx += _pwidth;
        }
        while (_sx >= _pwidth) {
            _sx -= _pwidth;
        }

        return [_sx, _sy];
    };

    /// Returns [mx, my].
    static map_pix_from_map_coord = function(_pos) {
        var _pwidth = map.get_cols() * scale;
        var _pheight = map.get_rows() * scale;

        var _mx = scale * map.pos_col(_pos) - ((scale * map.pos_row(_pos)) div 2);
        var _my = scale * map.pos_row(_pos);

        if (_my < 0) {
            _mx -= _pheight div 2;
            _my += _pheight;
        }

        if (_mx < 0) {
            _mx += _pwidth;
        } else if (_mx >= _pwidth) {
            _mx -= _pwidth;
        }

        return [_mx, _my];
    };

    /// Returns [sx, sy].
    static screen_pix_from_map_coord = function(_pos) {
        var _m = map_pix_from_map_coord(_pos);
        return screen_pix_from_map_pix(_m[0], _m[1]);
    };

    static map_pos_from_screen_pix = function(_sx, _sy) {
        var _mx = _sx + offset_x;
        var _my = _sy + offset_y;

        var _col = (((_my div 2) + _mx) div scale) & map.get_col_mask();
        var _row = (_my div scale) & map.get_row_mask();

        return map.pos(_col, _row);
    };

    static get_current_map_pos = function() {
        return map_pos_from_screen_pix(width div 2, height div 2);
    };

    static move_to_map_pos = function(_pos) {
        var _m = map_pix_from_map_coord(_pos);
        var _mx = _m[0];
        var _my = _m[1];

        var _map_width = map.get_cols() * scale;
        var _map_height = map.get_rows() * scale;

        /* Center view */
        _mx -= width div 2;
        _my -= height div 2;

        if (_my < 0) {
            _mx -= _map_height div 2;
            _my += _map_height;
        }

        if (_mx < 0) {
            _mx += _map_width;
        } else if (_mx >= _map_width) {
            _mx -= _map_width;
        }

        offset_x = _mx;
        offset_y = _my;

        set_redraw();
    };

    static move_by_pixels = function(_dx, _dy) {
        var _pwidth = map.get_cols() * scale;
        var _pheight = map.get_rows() * scale;

        offset_x += _dx;
        offset_y += _dy;

        if (offset_y < 0) {
            offset_y += _pheight;
            offset_x -= _pheight div 2;
        } else if (offset_y >= _pheight) {
            offset_y -= _pheight;
            offset_x += _pheight div 2;
        }

        if (offset_x >= _pwidth) {
            offset_x -= _pwidth;
        } else if (offset_x < 0) {
            offset_x += _pwidth;
        }

        set_redraw();
    };

    // Constructor body: Minimap(PMap _map) -> set_map(_map)
    set_map(_map);
}

/// MinimapGame : Minimap  (C++: MinimapGame(Interface *interface, PGame game))
function MinimapGame(_interface, _game) : Minimap(_game.get_map()) constructor {
    interface = _interface;
    game = _game;
    advanced = -1;
    draw_roads = false;
    draw_buildings = true;
    ownership_mode = OwnershipMode.none;

    static get_advanced = function() {
        return advanced;
    };

    static set_advanced = function(_advanced) {
        advanced = _advanced;
    };

    static get_draw_roads = function() {
        return draw_roads;
    };

    static set_draw_roads = function(_draw_roads) {
        draw_roads = _draw_roads;
        set_redraw();
    };

    static get_draw_buildings = function() {
        return draw_buildings;
    };

    static set_draw_buildings = function(_draw_buildings) {
        draw_buildings = _draw_buildings;
        set_redraw();
    };

    static get_ownership_mode = function() {
        return ownership_mode;
    };

    static set_ownership_mode = function(_ownership_mode) {
        ownership_mode = _ownership_mode;
        set_redraw();
    };

    static draw_minimap_ownership = function(_density) {
        var _rows = map.get_rows();
        var _cols = map.get_cols();
        for (var _row = 0; _row < _rows; _row += _density) {
            for (var _col = 0; _col < _cols; _col += _density) {
                var _pos = map.pos(_col, _row);
                if (map.has_owner(_pos)) {
                    var _color = interface.get_player_color(map.get_owner(_pos));
                    draw_minimap_point(_col, _row, _color, scale);
                }
            }
        }
    };

    static draw_minimap_roads = function() {
        var _rows = map.get_rows();
        var _cols = map.get_cols();
        for (var _row = 0; _row < _rows; _row++) {
            for (var _col = 0; _col < _cols; _col++) {
                var _pos = map.pos(_col, _row);
                if (map.get_paths(_pos) != 0) {
                    draw_minimap_point(_col, _row, global.minimap_color_black, scale);
                }
            }
        }
    };

    static draw_minimap_buildings = function() {
        var _rows = map.get_rows();
        var _cols = map.get_cols();
        for (var _row = 0; _row < _rows; _row++) {
            for (var _col = 0; _col < _cols; _col++) {
                var _pos = map.pos(_col, _row);
                var _obj = map.get_obj(_pos);
                if (_obj > MapObject.flag && _obj <= MapObject.castle) {
                    var _color = interface.get_player_color(map.get_owner(_pos));
                    if (advanced > 0) {
                        var _bld = interface.get_game().get_building_at_pos(_pos);
                        if (_bld.get_type() == global.minimap_building_remap[advanced]) {
                            draw_minimap_point(_col, _row, _color, scale);
                        }
                    } else {
                        draw_minimap_point(_col, _row, _color, scale);
                    }
                }
            }
        }
    };

    static draw_minimap_traffic = function() {
        var _rows = map.get_rows();
        var _cols = map.get_cols();
        for (var _row = 0; _row < _rows; _row++) {
            for (var _col = 0; _col < _cols; _col++) {
                var _pos = map.pos(_col, _row);
                if (map.get_idle_serf(_pos)) {
                    var _color = interface.get_player_color(map.get_owner(_pos));
                    draw_minimap_point(_col, _row, _color, scale);
                }
            }
        }
    };

    static internal_draw = function() {
        switch (ownership_mode) {
            case OwnershipMode.none:
                draw_minimap_map();
                break;
            case OwnershipMode.mixed:
                draw_minimap_map();
                draw_minimap_ownership(2);
                break;
            case OwnershipMode.solid_mode:
                gfx_fill_rect(0, 0, 128, 128, global.minimap_color_black);
                draw_minimap_ownership(1);
                break;
        }

        if (draw_roads) {
            draw_minimap_roads();
        }

        if (draw_buildings) {
            draw_minimap_buildings();
        }

        if (draw_grid) {
            draw_minimap_grid();
        }

        if (advanced > 0) {
            draw_minimap_traffic();
        }

        draw_minimap_rect();
    };

    static handle_click_left = function(_cx, _cy) {
        var _pos = map_pos_from_screen_pix(_cx, _cy);
        interface.get_viewport().move_to_map_pos(_pos);

        interface.update_map_cursor_pos(_pos);
        interface.close_popup();

        return true;
    };
}
