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

#macro PANEL_WIDTH 352
#macro PANEL_HEIGHT 40

/// PanelBar::Button
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

        1, 304, 0,
        6, 312, 0,
        -1
    ];
    // const int inactive_buttons[] (PanelBar::draw_panel_buttons)
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
        } else if (_cy >= 4 && _cy < 36 && _cx >= 64) {
            _cx -= 64;

            /* Figure out what button was clicked */
            var _button = 0;
            while (true) {
                if (_cx < 32) {
                    if (_button < 5) {
                        break;
                    } else {
                        return false;
                    }
                }
                _button += 1;
                if (_cx < 48) {
                    return false;
                }
                _cx -= 48;
            }
            button_click(_button);
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
