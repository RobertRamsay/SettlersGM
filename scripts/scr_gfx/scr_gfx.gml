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

    /* The Amiga font has three glyphs Freeserf's ASCII table never reaches:
       Ä, Ö and Ü at 26, 27 and 28, between Z and the digits. The German text
       in scr_locale.gml needs them. Both cases map to the one glyph, as the
       Latin letters do above; the code points are Latin-1, which is what
       string_ord_at hands back for them and what the & 0xFF in
       gfx_draw_char_sprite keeps whole. There is no ß - it is written ss. */
    global.gfx_font_map[0xC4] = 26;   /* Ä */
    global.gfx_font_map[0xE4] = 26;   /* ä */
    global.gfx_font_map[0xD6] = 27;   /* Ö */
    global.gfx_font_map[0xF6] = 27;   /* ö */
    global.gfx_font_map[0xDC] = 28;   /* Ü */
    global.gfx_font_map[0xFC] = 28;   /* ü */
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
/// _alpha defaults to 1, which takes the same path this always took - every
/// existing caller is unaffected. Below 1 the sprite goes through
/// draw_sprite_ext instead, which is the only way to get alpha on it.
function gfx_draw_sprite_full(_x, _y, _asset, _index, _use_off, _color, _progress,
                              _alpha = 1) {
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
            if (_alpha >= 1) {
                draw_sprite(_spr, _index, _sx, _sy);
            } else {
                draw_sprite_ext(_spr, _index, _sx, _sy, 1, 1, 0, c_white, _alpha);
            }
        }
        if (_mask != -1 && _color != -1) {
            draw_sprite_ext(_mask, _index, _sx, _sy, 1, 1, 0, _color, _alpha);
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

function gfx_draw_char_sprite(_x, _y, _c, _color, _shadow, _alpha = 1) {
    var _s = global.gfx_font_map[_c & 0xFF];
    if (_s < 0) {
        return;
    }
    if (_shadow != -1) {
        gfx_draw_sprite_full(_x, _y, Asset.font_shadow, _s, false, _shadow, 1, _alpha);
    }
    gfx_draw_sprite_full(_x, _y, Asset.font, _s, false, _color, 1, _alpha);
}

function gfx_draw_string(_x, _y, _str, _color, _shadow, _alpha = 1) {
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
            gfx_draw_char_sprite(_cx, _y, _c, _color, _shadow, _alpha);
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


/// The game's own font with a dropped shadow: black, one pixel right and two
/// down, at 0.8 of whatever alpha the text itself is drawn at.
///
/// This is not Asset.font_shadow, which is a separate outline sprite drawn in
/// register with the glyph. Over the map an outline is not enough - the shadow
/// has to be offset to lift the words off whatever terrain is behind them.
///
/// Fixed width, 8 pixels a character, so a caller wanting to know how wide a
/// line came out can just multiply.
#macro GFX_TEXT_SHADOW_ALPHA 0.8
#macro GFX_TEXT_CHAR_W       8

function gfx_draw_string_shadow(_x, _y, _str, _color, _alpha = 1) {
    gfx_draw_string(_x + 1, _y + 2, _str, c_black, -1,
                    _alpha * GFX_TEXT_SHADOW_ALPHA);
    gfx_draw_string(_x, _y, _str, _color, -1, _alpha);
}

/// Break a string into lines of at most _cols characters, on spaces where it
/// can. The font is fixed width, so _cols is just pixels div 8.
function gfx_wrap_string(_str, _cols) {
    var _lines = [];
    var _line = "";
    var _word = "";
    var _n = string_length(_str);

    for (var _i = 1; _i <= _n + 1; _i++) {
        var _c = "";
        if (_i <= _n) {
            _c = string_char_at(_str, _i);
        }

        if (_c == " " || _c == "" || _c == "\n") {
            if (string_length(_line) == 0) {
                _line = _word;
            } else if (string_length(_line) + 1 + string_length(_word) <= _cols) {
                _line += " " + _word;
            } else {
                array_push(_lines, _line);
                _line = _word;
            }
            _word = "";

            if (_c == "\n") {
                array_push(_lines, _line);
                _line = "";
            }
        } else {
            _word += _c;
            /* A single word longer than the line has to break somewhere. */
            if (string_length(_word) >= _cols) {
                if (string_length(_line) > 0) {
                    array_push(_lines, _line);
                    _line = "";
                }
                array_push(_lines, _word);
                _word = "";
            }
        }
    }

    if (string_length(_line) > 0) {
        array_push(_lines, _line);
    }
    return _lines;
}

/* ---------------------------------------------------------------------------
   Fullscreen - as a borderless window the size of the display, NOT the
   runtime's own fullscreen mode.

   window_set_fullscreen(true) makes the runtime tear down and recreate its
   swap chain, and if the window is not in the foreground at that moment it
   faults inside that recreation:

     Fullscreen state changed (was: 0, want: 1) - need to recreate swap chain
     Runner.exe exited with non-zero status (-1073741819)

   0xC0000005, every time the game was launched and then clicked away from
   before it finished loading. Waiting for window_has_focus() before asking
   was not enough: the focus can go again during the recreation itself, and
   the same fault came back as a heavy flicker followed by the crash.

   A window with no border, moved to the top-left corner and sized to the
   display, looks the same to the player and never touches the swap chain: it
   is an ordinary resize, which the runtime already survives while
   unfocused. The application surface stays SCREEN_W x SCREEN_H and is scaled
   into the window by the project's keep-aspect-ratio setting, exactly as it
   is for a dragged window edge. The platform's "start fullscreen" option and
   "allow fullscreen switching" stay off on every target, so nothing else can
   ask for the real thing.

   Two more rules, both learned from building and then alt-tabbing away:

   - The window is one pixel SHORT of the display. A borderless window that
     covers the monitor exactly is promoted by DXGI to its "fullscreen
     optimisation" path - the same swap-chain dance as real fullscreen, with
     the same fault when the window is in the background. One pixel short and
     it stays an ordinary window.
   - The switch only happens on a frame when this window has the focus. It
     costs nothing - the game just stays windowed until the player comes back
     to it - and it means the resize never lands on a window that Windows is
     in the middle of pushing behind something else. */
#macro FULLSCREEN_AT_START      true
#macro FULLSCREEN_SETTLE_FRAMES 8

function fullscreen_init() {
    global.fullscreen_wanted = FULLSCREEN_AT_START;
    global.fullscreen_delay = FULLSCREEN_SETTLE_FRAMES;
    global.fullscreen_on = false;
}

/* What the options popup and F10 read. window_get_fullscreen() would answer
   false here forever, because the runtime's own mode is never entered. */
function fullscreen_is_on() {
    return global.fullscreen_on;
}

/* Called once a frame from obj_game's Step. The settling frames let the Create
   event's window_set_size and Alarm 0's window_center land first, so the
   restore path below has a real windowed size to go back to. */
function fullscreen_step() {
    if (!global.fullscreen_wanted) {
        return;
    }
    if (!window_has_focus()) {
        /* Somebody else has the foreground. The count does not run down while
           we are in the background, so the window still gets its settling
           frames after the player comes back to it. */
        return;
    }
    global.fullscreen_delay -= 1;
    if (global.fullscreen_delay > 0) {
        return;
    }
    global.fullscreen_wanted = false;
    fullscreen_set(true);
}

/* Go full-window, or back to the pixel-scaled window in the middle of the
   display. */
function fullscreen_set(_on) {
    global.fullscreen_on = _on;
    if (_on) {
        window_set_showborder(false);
        window_set_position(0, 0);
        window_set_size(display_get_width(), display_get_height() - 1);
        return;
    }
    window_set_showborder(true);
    window_set_size(SCREEN_W * SCREEN_SCALE, SCREEN_H * SCREEN_SCALE);
    /* Centre next frame, the same way Create does: the size change has to
       settle before window_center measures it. */
    with (obj_game) {
        alarm[0] = 1;
    }
}

/* F10 and the options popup's Fullscreen row both come through here. */
function fullscreen_toggle() {
    /* A deliberate toggle cancels the pending start-up switch: if the player
       got there first, honour what they asked for rather than overriding it a
       few frames later. */
    global.fullscreen_wanted = false;
    fullscreen_set(!global.fullscreen_on);
}
