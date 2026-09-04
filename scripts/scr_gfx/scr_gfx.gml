// scr_gfx.gml - Port of the Freeserf Frame drawing API (src/gfx.cc, GPL-3.0,
// original copyright (C) 2013-2018 Jon Lund Steffensen) onto GameMaker drawing.
// Coordinates are local to the current GUI object; global.gfx_ox/global.gfx_oy
// hold the object's screen position (set by GuiObject.draw()).

enum Asset {
    none = 0,
    art_landscape,
    animation,
    serf_shadow,
    dotted_lines,
    art_flag,
    art_box,
    credits_bg,
    logo,
    symbol,
    map_mask_up,
    map_mask_down,
    path_mask,
    map_ground,
    path_ground,
    game_object,
    frame_top,
    map_border,
    map_waves,
    frame_popup,
    indicator,
    font,
    font_shadow,
    icon,
    map_object,
    map_shadow,
    panel_button,
    frame_bottom,
    serf_torso,
    serf_head,
    frame_split,
    sound,
    music,
    cursor
}

function gfx_init() {
    global.gfx_ox = 0;
    global.gfx_oy = 0;
    // Asset -> [sprite, mask sprite (or -1), meta rows]
    global.gfx_assets = array_create(Asset.cursor + 1, undefined);
    global.gfx_assets[Asset.serf_shadow] = [spr_serf_shadow, -1, global.sprite_meta.serf_shadow];
    global.gfx_assets[Asset.art_box] = [spr_art_box, -1, global.sprite_meta.art_box];
    global.gfx_assets[Asset.credits_bg] = [spr_credits_bg, -1, global.sprite_meta.credits_bg];
    global.gfx_assets[Asset.logo] = [spr_logo, -1, global.sprite_meta.logo];
    global.gfx_assets[Asset.symbol] = [spr_symbol, -1, global.sprite_meta.symbol];
    global.gfx_assets[Asset.map_mask_up] = [spr_map_mask_up, -1, global.sprite_meta.map_mask_up];
    global.gfx_assets[Asset.map_mask_down] = [spr_map_mask_down, -1, global.sprite_meta.map_mask_down];
    global.gfx_assets[Asset.path_mask] = [spr_path_mask, -1, global.sprite_meta.path_mask];
    global.gfx_assets[Asset.map_ground] = [spr_map_ground, -1, global.sprite_meta.map_ground];
    global.gfx_assets[Asset.path_ground] = [spr_path_ground, -1, global.sprite_meta.path_ground];
    global.gfx_assets[Asset.game_object] = [spr_game_object, -1, global.sprite_meta.game_object];
    global.gfx_assets[Asset.frame_top] = [spr_frame_top, -1, global.sprite_meta.frame_top];
    global.gfx_assets[Asset.map_border] = [spr_map_border, -1, global.sprite_meta.map_border];
    global.gfx_assets[Asset.map_waves] = [spr_map_waves, -1, global.sprite_meta.map_waves];
    global.gfx_assets[Asset.frame_popup] = [spr_frame_popup, -1, global.sprite_meta.frame_popup];
    global.gfx_assets[Asset.indicator] = [spr_indicator, -1, global.sprite_meta.indicator];
    global.gfx_assets[Asset.font] = [-1, spr_font_mask, global.sprite_meta.font];
    global.gfx_assets[Asset.font_shadow] = [-1, spr_font_shadow_mask, global.sprite_meta.font_shadow];
    global.gfx_assets[Asset.icon] = [spr_icon, -1, global.sprite_meta.icon];
    global.gfx_assets[Asset.map_object] = [spr_map_object, spr_map_object_mask, global.sprite_meta.map_object];
    global.gfx_assets[Asset.map_shadow] = [spr_map_shadow, -1, global.sprite_meta.map_shadow];
    global.gfx_assets[Asset.panel_button] = [spr_panel_button, -1, global.sprite_meta.panel_button];
    global.gfx_assets[Asset.frame_bottom] = [spr_frame_bottom, -1, global.sprite_meta.frame_bottom];
    global.gfx_assets[Asset.serf_torso] = [spr_serf_torso, spr_serf_torso_mask, global.sprite_meta.serf_torso];
    global.gfx_assets[Asset.serf_head] = [spr_serf_head, -1, global.sprite_meta.serf_head];
    global.gfx_assets[Asset.cursor] = [spr_cursor, -1, global.sprite_meta.cursor];

    // ASCII -> font sprite index (Frame::draw_char_sprite)
    global.gfx_font_map = array_create(256, -1);
    var _tbl = [
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, 43, -1, -1, -1, -1, -1, -1, -1, 40, 39, -1,
        29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 41, -1, -1, -1, -1, 42,
        -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
        -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1
    ];
    for (var _i = 0; _i < 128; _i++) {
        global.gfx_font_map[_i] = _tbl[_i];
    }
}

function gfx_set_origin(_x, _y) {
    global.gfx_ox = _x;
    global.gfx_oy = _y;
}

/// Sprite meta row for an asset index: [present, ox, oy, dx, dy, w, h]
function gfx_meta(_asset, _index) {
    var _a = global.gfx_assets[_asset];
    if (_a == undefined) {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    var _rows = _a[2];
    if (_index < 0 || _index >= array_length(_rows)) {
        return [0, 0, 0, 0, 0, 0, 0];
    }
    return _rows[_index];
}

function gfx_get_sprite_width(_asset, _index) {
    var _m = gfx_meta(_asset, _index);
    return _m[5];
}

function gfx_get_sprite_height(_asset, _index) {
    var _m = gfx_meta(_asset, _index);
    return _m[6];
}

/// Full form: Frame::draw_sprite(x, y, res, index, use_off, color, progress)
function gfx_draw_sprite_full(_x, _y, _asset, _index, _use_off, _color, _progress) {
    var _a = global.gfx_assets[_asset];
    if (_a == undefined) {
        return;
    }
    var _m = gfx_meta(_asset, _index);
    if (_m[0] == 0) {
        return;
    }
    var _sx = global.gfx_ox + _x;
    var _sy = global.gfx_oy + _y;
    // GameMaker origins already include the offset; undo it when use_off is false.
    if (!_use_off) {
        _sx -= _m[1];
        _sy -= _m[2];
    }
    var _spr = _a[0];
    var _mask = _a[1];
    if (_progress >= 1) {
        if (_spr != -1) {
            draw_sprite(_spr, _index, _sx, _sy);
        }
        if (_mask != -1 && _color != -1) {
            draw_sprite_ext(_mask, _index, _sx, _sy, 1, 1, 0, _color, 1);
        }
    } else {
        // Only the lower `progress` part of the sprite is drawn (building construction).
        var _h = _m[6];
        var _y_off = _h - floor(_h * _progress);
        var _ox = sprite_get_xoffset(_spr);
        var _oy = sprite_get_yoffset(_spr);
        var _left = _ox + _m[1];       // frame-local x of the image
        var _top = _oy + _m[2] + _y_off;
        var _ih = _h - _y_off;
        if (_spr != -1 && _ih > 0) {
            draw_sprite_part(_spr, _index, _left, _top, _m[5], _ih, _sx - _ox + _left, _sy - _oy + _top);
        }
        if (_mask != -1 && _color != -1 && _ih > 0) {
            draw_sprite_part_ext(_mask, _index, _left, _top, _m[5], _ih, _sx - _ox + _left, _sy - _oy + _top, 1, 1, _color, 1);
        }
    }
}

function gfx_draw_sprite(_x, _y, _asset, _index) {
    gfx_draw_sprite_full(_x, _y, _asset, _index, false, -1, 1);
}

/// Draw an arbitrary sub-rect of a sprite. Lets a tiled run take its last
/// piece from the END of the art, so the carved cap lands on the corner
/// instead of a stud appearing partway along.
function gfx_draw_sprite_region(_x, _y, _asset, _index, _rx, _ry, _w, _h) {
    var _a = global.gfx_assets[_asset];
    if (_a == undefined) {
        return;
    }
    var _m = gfx_meta(_asset, _index);
    if (_m[0] == 0) {
        return;
    }

    var _cw = min(_w, _m[5] - _rx);
    var _ch = min(_h, _m[6] - _ry);
    if (_cw <= 0 || _ch <= 0) {
        return;
    }

    var _spr = _a[0];
    if (_spr == -1) {
        return;
    }

    draw_sprite_part(_spr, _index,
                     sprite_get_xoffset(_spr) + _m[1] + _rx,
                     sprite_get_yoffset(_spr) + _m[2] + _ry,
                     _cw, _ch,
                     global.gfx_ox + _x, global.gfx_oy + _y);
}

/// Tile a frame_popup piece for _len px, taking the final piece from the END of
/// the art so both carved caps land on the corners rather than a joint showing
/// partway along the run.
function gfx_draw_frame_run_h(_x0, _y, _index, _len, _sw, _sh) {
    var _done = 0;
    while (_done < _len) {
        var _left = _len - _done;
        if (_left >= _sw) {
            gfx_draw_sprite_region(_x0 + _done, _y, Asset.frame_popup, _index, 0, 0, _sw, _sh);
            _done += _sw;
        } else {
            gfx_draw_sprite_region(_x0 + _done, _y, Asset.frame_popup, _index,
                                   _sw - _left, 0, _left, _sh);
            _done += _left;
        }
    }
}

function gfx_draw_frame_run_v(_x, _y0, _index, _len, _sw, _sh) {
    var _done = 0;
    while (_done < _len) {
        var _left = _len - _done;
        if (_left >= _sh) {
            gfx_draw_sprite_region(_x, _y0 + _done, Asset.frame_popup, _index, 0, 0, _sw, _sh);
            _done += _sh;
        } else {
            gfx_draw_sprite_region(_x, _y0 + _done, Asset.frame_popup, _index,
                                   0, _sh - _left, _sw, _left);
            _done += _left;
        }
    }
}

/// Wooden surround for a box of any size. Uses the plain rail top and bottom:
/// frame_popup piece 0 carries a crest centred for a 144 wide popup, which
/// would repeat across anything wider.
function gfx_draw_frame_box(_x, _y, _w, _h) {
    gfx_draw_frame_run_h(_x, _y, 1, _w, 144, 7);
    gfx_draw_frame_run_h(_x, _y + _h - 7, 1, _w, 144, 7);
    gfx_draw_frame_run_v(_x, _y, 2, _h, 8, 144);
    gfx_draw_frame_run_v(_x + _w - 8, _y, 3, _h, 8, 144);
}

/// Draw only the top-left _w x _h of a sprite. Used to tile the wooden frame
/// without the last piece overhanging the corner it is running into.
function gfx_draw_sprite_part(_x, _y, _asset, _index, _w, _h) {
    var _a = global.gfx_assets[_asset];
    if (_a == undefined) {
        return;
    }
    var _m = gfx_meta(_asset, _index);
    if (_m[0] == 0) {
        return;
    }

    var _cw = min(_w, _m[5]);
    var _ch = min(_h, _m[6]);
    if (_cw <= 0 || _ch <= 0) {
        return;
    }

    var _spr = _a[0];
    if (_spr == -1) {
        return;
    }

    draw_sprite_part(_spr, _index,
                     sprite_get_xoffset(_spr) + _m[1],
                     sprite_get_yoffset(_spr) + _m[2],
                     _cw, _ch,
                     global.gfx_ox + _x, global.gfx_oy + _y);
}

function gfx_draw_sprite_off(_x, _y, _asset, _index, _use_off) {
    gfx_draw_sprite_full(_x, _y, _asset, _index, _use_off, -1, 1);
}

function gfx_draw_sprite_color(_x, _y, _asset, _index, _use_off, _color) {
    gfx_draw_sprite_full(_x, _y, _asset, _index, _use_off, _color, 1);
}

function gfx_draw_sprite_progress(_x, _y, _asset, _index, _use_off, _progress) {
    gfx_draw_sprite_full(_x, _y, _asset, _index, _use_off, -1, _progress);
}

function gfx_draw_sprite_relatively(_x, _y, _asset, _index, _rel_asset, _rel_index) {
    var _m = gfx_meta(_rel_asset, _rel_index);
    gfx_draw_sprite_full(_x + _m[3], _y + _m[4], _asset, _index, true, -1, 1);
}

function gfx_draw_rect(_x, _y, _w, _h, _color) {
    draw_set_color(_color);
    draw_rectangle(global.gfx_ox + _x, global.gfx_oy + _y, global.gfx_ox + _x + _w - 1, global.gfx_oy + _y + _h - 1, true);
    draw_set_color(c_white);
}

function gfx_fill_rect(_x, _y, _w, _h, _color) {
    draw_set_color(_color);
    draw_rectangle(global.gfx_ox + _x, global.gfx_oy + _y, global.gfx_ox + _x + _w - 1, global.gfx_oy + _y + _h - 1, false);
    draw_set_color(c_white);
}

function gfx_draw_line(_x, _y, _x1, _y1, _color) {
    draw_set_color(_color);
    draw_line(global.gfx_ox + _x, global.gfx_oy + _y, global.gfx_ox + _x1, global.gfx_oy + _y1);
    draw_set_color(c_white);
}

function gfx_draw_char_sprite(_x, _y, _c, _color, _shadow) {
    var _s = global.gfx_font_map[_c & 0xFF];
    if (_s < 0) {
        return;
    }
    if (_shadow != -1) {
        gfx_draw_sprite_full(_x, _y, Asset.font_shadow, _s, false, _shadow, 1);
    }
    gfx_draw_sprite_full(_x, _y, Asset.font, _s, false, _color, 1);
}

function gfx_draw_string(_x, _y, _str, _color, _shadow) {
    var _cx = _x;
    var _n = string_length(_str);
    for (var _i = 1; _i <= _n; _i++) {
        var _c = string_ord_at(_str, _i);
        if (_c == 9) {
            _cx += 8 * 2;
        } else if (_c == 10) {
            _y += 8;
            _cx = _x;
        } else {
            gfx_draw_char_sprite(_cx, _y, _c, _color, _shadow);
            _cx += 8;
        }
    }
}

function gfx_draw_number(_x, _y, _value, _color, _shadow) {
    if (_value < 0) {
        gfx_draw_char_sprite(_x, _y, ord("-"), _color, _shadow);
        _x += 8;
        _value = -_value;
    }
    if (_value == 0) {
        gfx_draw_char_sprite(_x, _y, ord("0"), _color, _shadow);
        return;
    }
    var _digits = 0;
    for (var _i = _value; _i > 0; _i = _i div 10) {
        _digits += 1;
    }
    for (var _i = _digits - 1; _i >= 0; _i--) {
        gfx_draw_char_sprite(_x + 8 * _i, _y, ord("0") + (_value mod 10), _color, _shadow);
        _value = _value div 10;
    }
}
