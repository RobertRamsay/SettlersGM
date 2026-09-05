// scr_panel.gml - Ported from Freeserf src/panel.h / src/panel.cc (GPL-3.0),
// original copyright (C) 2012-2016 Jon Lund Steffensen <jonlst@gmail.com>.
// Bottom panel bar (PanelBar : GuiObject).
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The 700 ms blink Timer of the C++ is emulated with current_time inside
// internal_draw() (see on_timer_fired).

#macro PANEL_WIDTH 400
#macro PANEL_HEIGHT 40

/// PanelBar::Button
// PANEL_WIDTH above was 352 in the original: five buttons plus the two round
// end pieces. Widened by one 48px slot for the game-speed button.
#macro PANEL_BUTTON_COUNT 6
#macro SPEED_BUTTON 5

// Multiples of DEFAULT_GAME_SPEED the button cycles through: >, >>, >>>.
// game_speed is what Game.update adds to tick each step.
// Halved from 20 / 50 / 100 - the old steps ran away from the eye and there was
// nothing usable between normal pace and a blur. Normal play is deliberately
// NOT touched: step 1 stays at DEFAULT_GAME_SPEED, which is Freeserf's own
// value and therefore the Amiga's pace.
#macro SPEED_STEP_2 10
#macro SPEED_STEP_3 25
#macro SPEED_STEP_4 50


enum PanelButton {
    build_inactive = 0,
    build_flag,
    build_mine,
    build_small,
    build_large,
    build_castle,
    destroy,
    destroy_inactive,
    build_road,
    map_inactive,
    map,
    stats_inactive,
    stats,
    sett_inactive,
    sett,
    destroy_road,
    ground_analysis,
    build_small_starred,
    build_large_starred,
    map_starred,
    stats_starred,
    sett_starred,
    ground_analysis_starred,
    build_mine_starred,
    build_road_starred
}

function panel_init_tables() {
    if (variable_global_exists("panel_bottom_svga_layout")) {
        return;
    }
    // const int bottom_svga_layout[] (PanelBar::draw_panel_frame); -1 terminated
    global.panel_bottom_svga_layout = [
        6, 0, 0,
        0, 40, 0,
        20, 48, 0,

        7, 64, 0,
        8, 64, 36,
        21, 96, 0,

        9, 112, 0,
        10, 112, 36,
        22, 144, 0,

        11, 160, 0,
        12, 160, 36,
        23, 192, 0,

        13, 208, 0,
        14, 208, 36,
        24, 240, 0,

        15, 256, 0,
        16, 256, 36,
        25, 288, 0,

        // One extra slot for the game-speed button. Not in the original; the
        // strip pair is reused because there are only five distinct ones.
        7, 304, 0,
        8, 304, 36,
        21, 336, 0,

        1, 352, 0,
        6, 360, 0,
        -1
    ];
    // const int inactive_buttons[] (PanelBar::draw_panel_buttons)
    // Multipliers of DEFAULT_GAME_SPEED the speed button steps through. Held as
    // data so a step can be added or removed here alone: the chevron count, the
    // stepping and the clamping all read from it.
    global.panel_speed_steps = [1, SPEED_STEP_2, SPEED_STEP_3, SPEED_STEP_4];

    global.panel_inactive_buttons = [
        PanelButton.build_inactive,
        PanelButton.destroy_inactive,
        PanelButton.map_inactive,
        PanelButton.stats_inactive,
        PanelButton.sett_inactive
    ];
}

function PanelBar(_interface) : GuiObject() constructor {
    panel_init_tables();

    interface = _interface;

    panel_btns = array_create(5, 0);
    panel_btns[0] = PanelButton.build_inactive;
    panel_btns[1] = PanelButton.destroy_inactive;
    panel_btns[2] = PanelButton.map;
    panel_btns[3] = PanelButton.stats;
    panel_btns[4] = PanelButton.sett;

    // Timer::create(1, 700, this) -> emulated with current_time
    blink_timer_id = 1;
    blink_timer_interval = 700;
    blink_timer_last = current_time;
    blink_trigger = false;

    /* Draw the frame around action buttons. */
    static draw_panel_frame = function() {
        /* TODO request full buffer swap(?) */

        var _layout = global.panel_bottom_svga_layout;

        /* Draw layout */
        for (var _i = 0; _layout[_i] != -1; _i += 3) {
            gfx_draw_sprite(_layout[_i + 1], _layout[_i + 2], Asset.frame_bottom,
                            _layout[_i]);
        }
    };

    /* Draw notification icon in action panel. */
    static draw_message_notify = function() {
        interface.set_msg_flag(2);
        gfx_draw_sprite(40, 4, Asset.frame_bottom, 2);
    };

    /* Draw return arrow icon in action panel. */
    static draw_return_arrow = function() {
        gfx_draw_sprite(40, 28, Asset.frame_bottom, 4);
    };

    /* Draw buttons in action panel. */
    static draw_panel_buttons = function() {
        if (enabled) {
            var _player = interface.get_player();
            /* Blinking message icon. */
            if ((_player != undefined) && _player.has_notification()) {
                if (blink_trigger) {
                    draw_message_notify();
                }
            }

            /* Return arrow icon. */
            if (interface.get_msg_flag(3)) {
                draw_return_arrow();
            }
        }

        var _inactive_buttons = global.panel_inactive_buttons;

        for (var _i = 0; _i < 5; _i++) {
            var _button = panel_btns[_i];
            if (!enabled) {
                _button = _inactive_buttons[_i];
            }

            var _sx = 64 + _i * 48;
            var _sy = 4;
            gfx_draw_sprite(_sx, _sy, Asset.panel_button, _button);
        }

        draw_speed_button(64 + SPEED_BUTTON * 48, 4, speed_chevrons());
    };

    /// Which step the game speed is currently on, 0 being normal. Takes the
    /// highest step at or below the current speed, so the keyboard's
    /// speed_increase landing between steps still shows something sensible.
    static speed_step = function() {
        var _game = interface.get_game();
        if (_game == undefined) {
            return 0;
        }

        var _steps = global.panel_speed_steps;
        var _found = 0;
        for (var _i = 0; _i < array_length(_steps); _i++) {
            if (_game.game_speed >= DEFAULT_GAME_SPEED * _steps[_i]) {
                _found = _i;
            }
        }

        return _found;
    };

    static set_speed_step = function(_step) {
        var _game = interface.get_game();
        if (_game == undefined) {
            return;
        }

        var _steps = global.panel_speed_steps;
        var _clamped = clamp(_step, 0, array_length(_steps) - 1);

        _game.set_speed(DEFAULT_GAME_SPEED * _steps[_clamped]);
        play_sound(Sfx.click);
        set_redraw();
    };

    /// One chevron per step, so four steps draw >, >>, >>> and >>>>.
    static speed_chevrons = function() {
        return speed_step() + 1;
    };

    /// A panel button face with `_chevrons` >'s stamped on it, drawn in the
    /// panel's own palette so it sits with the rest of the bar.
    static draw_speed_button = function(_sx, _sy, _chevrons) {
        gfx_draw_sprite(_sx, _sy, Asset.panel_button, PanelButton.build_inactive);

        var _ox = global.gfx_ox + _sx;
        var _oy = global.gfx_oy + _sy;
        var _light = make_colour_rgb(0xff, 0xdd, 0xbb);
        var _dark = make_colour_rgb(0x55, 0x22, 0x00);

        /* Tighter once there are four, so the run still fits the 32px face. */
        var _spacing = 7;
        if (_chevrons >= 4) {
            _spacing = 6;
        }
        var _left = 16 - ((_chevrons - 1) * _spacing) div 2 - 4;

        for (var _c = 0; _c < _chevrons; _c++) {
            var _cx = _ox + _left + _c * _spacing;
            var _cy = _oy + 16;

            draw_triangle_colour(_cx + 1, _cy - 6, _cx + 1, _cy + 6,
                                 _cx + 8, _cy, _dark, _dark, _dark, false);
            draw_triangle_colour(_cx, _cy - 6, _cx, _cy + 6,
                                 _cx + 7, _cy, _light, _light, _light, false);
        }
    };

    static internal_draw = function() {
        // Blink timer emulation (Timer with interval 700 ms).
        while (current_time - blink_timer_last >= blink_timer_interval) {
            blink_timer_last += blink_timer_interval;
            on_timer_fired(blink_timer_id);
        }

        draw_panel_frame();
        draw_panel_buttons();
    };

    /* Handle a click on the panel buttons. */
    static button_click = function(_button) {
        if (_button == SPEED_BUTTON) {
            /* Left click steps up and stops at the fastest; right click steps
               down and stops at normal. See handle_click_right. */
            set_speed_step(speed_step() + 1);
            return;
        }

        var _popup = interface.get_popup_box();
        switch (panel_btns[_button]) {
            case PanelButton.map:
            case PanelButton.map_starred:
                play_sound(Sfx.click);
                if ((_popup != undefined) && _popup.is_displayed()) {
                    interface.close_popup();
                } else {
                    panel_btns[0] = PanelButton.build_inactive;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_starred;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_inactive;

                    interface.open_popup(PopupType.map);

                    /* Synchronize minimap window with viewport. */
                    if (_popup != undefined) {
                        var _viewport = interface.get_viewport();
                        var _minimap = _popup.get_minimap();
                        if (_minimap != undefined) {
                            var _pos = _viewport.get_current_map_pos();
                            _minimap.move_to_map_pos(_pos);
                        }
                    }
                }
                break;
            case PanelButton.sett:
            case PanelButton.sett_starred:
                play_sound(Sfx.click);
                if ((_popup != undefined) && _popup.is_displayed()) {
                    interface.close_popup();
                } else {
                    panel_btns[0] = PanelButton.build_inactive;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_starred;
                    interface.open_popup(PopupType.sett_select);
                }
                break;
            case PanelButton.stats:
            case PanelButton.stats_starred:
                play_sound(Sfx.click);
                if ((_popup != undefined) && _popup.is_displayed()) {
                    interface.close_popup();
                } else {
                    panel_btns[0] = PanelButton.build_inactive;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_starred;
                    panel_btns[4] = PanelButton.sett_inactive;
                    interface.open_popup(PopupType.stat_select);
                }
                break;
            case PanelButton.build_road:
            case PanelButton.build_road_starred:
                play_sound(Sfx.click);
                if (interface.is_building_road()) {
                    interface.build_road_end();
                } else {
                    interface.build_road_begin();
                }
                break;
            case PanelButton.build_flag:
                play_sound(Sfx.click);
                interface.build_flag();
                break;
            case PanelButton.build_small:
            case PanelButton.build_small_starred:
                play_sound(Sfx.click);
                if ((_popup != undefined) && _popup.is_displayed()) {
                    interface.close_popup();
                } else {
                    panel_btns[0] = PanelButton.build_small_starred;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_inactive;
                    interface.open_popup(PopupType.basic_bld);
                }
                break;
            case PanelButton.build_large:
            case PanelButton.build_large_starred:
                play_sound(Sfx.click);
                if ((_popup != undefined) && _popup.is_displayed()) {
                    interface.close_popup();
                } else {
                    panel_btns[0] = PanelButton.build_large_starred;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_inactive;
                    interface.open_popup(PopupType.basic_bld_flip);
                }
                break;
            case PanelButton.build_mine:
            case PanelButton.build_mine_starred:
                play_sound(Sfx.click);
                if ((_popup != undefined) && _popup.is_displayed()) {
                    interface.close_popup();
                } else {
                    panel_btns[0] = PanelButton.build_mine_starred;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_inactive;
                    interface.open_popup(PopupType.mine_building);
                }
                break;
            case PanelButton.destroy:
                if (interface.get_map_cursor_type() == CursorType.removable_flag) {
                    interface.demolish_object();
                } else {
                    panel_btns[0] = PanelButton.build_inactive;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_inactive;
                    interface.open_popup(PopupType.demolish);
                }
                break;
            case PanelButton.build_castle:
                interface.build_castle();
                break;
            case PanelButton.destroy_road: {
                var _r = interface.get_player().get_game().demolish_road(
                                                interface.get_map_cursor_pos(),
                                                interface.get_player());
                if (!_r) {
                    play_sound(Sfx.not_accepted);
                    interface.update_map_cursor_pos(interface.get_map_cursor_pos());
                } else {
                    play_sound(Sfx.accepted);
                }
            }
                break;
            case PanelButton.ground_analysis:
            case PanelButton.ground_analysis_starred:
                play_sound(Sfx.click);
                if ((_popup != undefined) && _popup.is_displayed()) {
                    interface.close_popup();
                } else {
                    panel_btns[0] = PanelButton.build_inactive;
                    panel_btns[1] = PanelButton.ground_analysis_starred;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_inactive;
                    interface.open_popup(PopupType.ground_analysis);
                }
                break;
        }
    };

    /// Swallow double clicks for the same reason PopupBox does: the default
    /// GuiObject handler returns false, and a float that answers false hands the
    /// event down to the viewport behind it. Clicking a panel button twice
    /// quickly would otherwise double click the map underneath the panel.
    static handle_dbl_click = function(_cx, _cy, _button) {
        return true;
    };

    static handle_click_left = function(_cx, _cy) {
        set_redraw();

        if (_cx >= 41 && _cx < 53) {
            /* Message bar click */
            if (_cy < 16) {
                /* Message icon */
                interface.open_message();
            } else if (_cy >= 28) {
                /* Return arrow */
                interface.return_from_message();
            }
        } else if (_cx >= 301 && _cx < 313) {
            /* Timer bar click */
            /* Call to map position */
            var _timer_length = 0;

            if (_cy < 7) {
                _timer_length = 5 * 60;
            } else if (_cy < 14) {
                _timer_length = 10 * 60;
            } else if (_cy < 21) {
                _timer_length = 20 * 60;
            } else if (_cy < 28) {
                _timer_length = 30 * 60;
            } else {
                _timer_length = 60 * 60;
            }

            interface.get_player().add_timer(_timer_length * TICKS_PER_SEC,
                                             interface.get_map_cursor_pos());

            play_sound(Sfx.accepted);
        } else {
            var _button = hit_test_button(_cx, _cy);
            if (_button >= 0) {
                button_click(_button);
            }
        }

        return true;
    };

    /* Which of the five panel buttons covers (_cx, _cy)? -1 for none. */
    static hit_test_button = function(_cx, _cy) {
        if (_cy < 4 || _cy >= 36 || _cx < 64) {
            return -1;
        }

        var _bx = _cx - 64;
        var _button = 0;
        while (true) {
            if (_bx < 32) {
                if (_button < PANEL_BUTTON_COUNT) {
                    return _button;
                } else {
                    return -1;
                }
            }
            _button += 1;
            if (_bx < 48) {
                return -1;
            }
            _bx -= 48;
        }
    };

    /// Right click on the speed button steps back down, so left is faster and
    /// right is slower. set_speed_step clamps, so neither end wraps.
    static handle_click_right = function(_cx, _cy) {
        if (hit_test_button(_cx, _cy) != SPEED_BUTTON) {
            return false;
        }

        set_speed_step(speed_step() - 1);
        return true;
    };

    /* Both mouse buttons on the build button toggles the build-possibility
       icons over the map - the same overlay the "b" key switches. */
    /// Both mouse buttons together. An Amiga mouse has two buttons, so
    /// left+right held together is its own input in The Settlers; obj_game
    /// reports it as a middle click and swallows the left and right clicks that
    /// follow, so none of this can also trigger the ordinary button.
    ///
    /// The build button toggles the builds overlay, which is Freeserf's. The map
    /// button jumps to your castle, which is not - but it is the same gesture on
    /// the icon that is already about finding your way around.
    ///
    /// NOTE: there must be exactly one handle_click_middle in this constructor.
    /// A second `static` of the same name silently replaces the first, whichever
    /// is written later - which is how the castle jump came to do nothing at all
    /// on the first attempt.
    static handle_click_middle = function(_cx, _cy) {
        var _button = hit_test_button(_cx, _cy);
        if (_button < 0 || _button >= array_length(panel_btns)) {
            /* Below zero is the message and timer bars and the gaps between
               buttons. At or past the end is the speed button, which is ours and
               sits beyond panel_btns - reading it would be out of range.
               Swallowed either way: a float that answers false hands the event
               down to the viewport behind the panel. */
            return true;
        }

        if (_button == 0) {
            set_redraw();
            play_sound(Sfx.click);

            var _viewport = interface.get_viewport();
            if (_viewport != undefined) {
                _viewport.switch_layer(ViewportLayer.builds);
            }

            return true;
        }

        /* Any of the map button's three states - it is the icon's position being
           aimed at, and which state it happens to be in is not worth making the
           player think about. */
        var _kind = panel_btns[_button];
        if (_kind == PanelButton.map ||
            _kind == PanelButton.map_starred ||
            _kind == PanelButton.map_inactive) {
            set_redraw();
            if (interface.move_to_castle()) {
                play_sound(Sfx.accepted);
            } else {
                play_sound(Sfx.not_accepted);
            }
        }

        return true;
    };

    static handle_key_pressed = function(_key, _modifier) {
        if (_key < ord("1") || _key > ord("5")) {
            return false;
        }

        button_click(_key - ord("1"));

        return true;
    };

    static button_type_with_build_possibility = function(_build_possibility) {
        var _result = PanelButton.build_inactive;

        switch (_build_possibility) {
            case BuildPossibility.castle:
                _result = PanelButton.build_castle;
                break;
            case BuildPossibility.mine:
                _result = PanelButton.build_mine;
                break;
            case BuildPossibility.large:
                _result = PanelButton.build_large;
                break;
            case BuildPossibility.small:
                _result = PanelButton.build_small;
                break;
            case BuildPossibility.flag:
                _result = PanelButton.build_flag;
                break;
            default:
                _result = PanelButton.build_inactive;
                break;
        }

        return _result;
    };

    static update = function() {
        if ((interface.get_popup_box() != undefined) &&
            interface.get_popup_box().is_displayed()) {
            switch (interface.get_popup_box().get_box()) {
                case PopupType.transport_info:
                case PopupType.ordered_bld:
                case PopupType.castle_res:
                case PopupType.defenders:
                case PopupType.mine_output:
                case PopupType.bld_stock:
                case PopupType.start_attack:
                case PopupType.quit_confirm:
                case PopupType.options: {
                    panel_btns[0] = PanelButton.build_inactive;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    panel_btns[2] = PanelButton.map_inactive;
                    panel_btns[3] = PanelButton.stats_inactive;
                    panel_btns[4] = PanelButton.sett_inactive;
                    break;
                }
                default:
                    break;
            }
        } else if (interface.is_building_road()) {
            panel_btns[0] = PanelButton.build_road_starred;
            panel_btns[1] = PanelButton.build_inactive;
            panel_btns[2] = PanelButton.map_inactive;
            panel_btns[3] = PanelButton.stats_inactive;
            panel_btns[4] = PanelButton.sett_inactive;
        } else {
            panel_btns[2] = PanelButton.map;
            panel_btns[3] = PanelButton.stats;
            panel_btns[4] = PanelButton.sett;

            var _build_possibility = interface.get_build_possibility();

            switch (interface.get_map_cursor_type()) {
                case CursorType.none:
                    panel_btns[0] = PanelButton.build_inactive;
                    if (interface.get_player().has_castle()) {
                        panel_btns[1] = PanelButton.destroy_inactive;
                    } else {
                        panel_btns[1] = PanelButton.ground_analysis;
                    }
                    break;
                case CursorType.flag:
                    panel_btns[0] = PanelButton.build_road;
                    panel_btns[1] = PanelButton.destroy_inactive;
                    break;
                case CursorType.removable_flag:
                    panel_btns[0] = PanelButton.build_road;
                    panel_btns[1] = PanelButton.destroy;
                    break;
                case CursorType.building:
                    panel_btns[0] = button_type_with_build_possibility(_build_possibility);
                    panel_btns[1] = PanelButton.destroy;
                    break;
                case CursorType.path:
                    panel_btns[0] = PanelButton.build_inactive;
                    panel_btns[1] = PanelButton.destroy_road;
                    if (_build_possibility != BuildPossibility.none) {
                        panel_btns[0] = PanelButton.build_flag;
                    }
                    break;
                case CursorType.clear_by_flag:
                    if (_build_possibility == BuildPossibility.none ||
                        _build_possibility == BuildPossibility.flag) {
                        panel_btns[0] = PanelButton.build_inactive;
                        if (interface.get_player().has_castle()) {
                            panel_btns[1] = PanelButton.destroy_inactive;
                        } else {
                            panel_btns[1] = PanelButton.ground_analysis;
                        }
                    } else {
                        panel_btns[0] = button_type_with_build_possibility(_build_possibility);
                        panel_btns[1] = PanelButton.destroy_inactive;
                    }
                    break;
                case CursorType.clear_by_path:
                    panel_btns[0] = button_type_with_build_possibility(_build_possibility);
                    panel_btns[1] = PanelButton.destroy_inactive;
                    break;
                case CursorType.clear:
                    panel_btns[0] = button_type_with_build_possibility(_build_possibility);
                    if ((interface.get_player() != undefined) &&
                        interface.get_player().has_castle()) {
                        panel_btns[1] = PanelButton.destroy_inactive;
                    } else {
                        panel_btns[1] = PanelButton.ground_analysis;
                    }
                    break;
                default:
                    throw ("PanelBar::update: NOT_REACHED");
                    break;
            }
        }
        set_redraw();
    };

    static on_timer_fired = function(_id) {
        blink_trigger = !blink_trigger;
        set_redraw();
    };
}
