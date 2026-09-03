// scr_notification.gml - Ported from Freeserf src/notification.h /
// src/notification.cc (GPL-3.0), original copyright (C) 2013-2014
// Jon Lund Steffensen <jonlst@gmail.com>. Notification GUI component
// (NotificationBox : GuiObject).
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Depends on `enum MessageType` (Message::Type, scr_player.gml) with the
// enumerators none, under_attack, lose_fight, win_fight, mine_empty,
// call_to_location, knight_occupied, new_stock, lost_land, lost_buildings,
// emergency_active, emergency_neutral, found_gold, found_iron, found_coal,
// found_stone, call_to_menu, since_save_30m, since_save_1h, call_to_stock.
// A Message is a struct {type, pos, data}.

#macro NOTIFICATION_SHOW_OPPONENT 0
#macro NOTIFICATION_SHOW_MINE 1
#macro NOTIFICATION_SHOW_BUILDING 2
#macro NOTIFICATION_SHOW_MAP_OBJECT 3
#macro NOTIFICATION_SHOW_ICON 4
#macro NOTIFICATION_SHOW_MENU 5

/// Color::green (gfx.cc)
#macro NOTIFICATION_COLOR_GREEN make_colour_rgb(0x73, 0xb3, 0x43)

function notification_init_tables() {
    if (variable_global_exists("notification_views")) {
        return;
    }
    interface_init_tables();
    var _mbs = global.interface_map_building_sprite;

    // NotificationView notification_views[]: {type, decoration, icon, text}
    global.notification_views = [
        { type: MessageType.under_attack,
          decoration: NOTIFICATION_SHOW_OPPONENT,
          icon: 0,
          text: "Your settlement\nis under attack" },
        { type: MessageType.lose_fight,
          decoration: NOTIFICATION_SHOW_OPPONENT,
          icon: 0,
          text: "Your knights\njust lost the\nfight" },
        { type: MessageType.win_fight,
          decoration: NOTIFICATION_SHOW_OPPONENT,
          icon: 0,
          text: "You gained\na victory here" },
        { type: MessageType.mine_empty,
          decoration: NOTIFICATION_SHOW_MINE,
          icon: 0,
          text: "This mine hauls\nno more raw\nmaterials" },
        { type: MessageType.call_to_location,
          decoration: NOTIFICATION_SHOW_MAP_OBJECT,
          icon: 0x90,
          text: "You wanted me\nto call you to\nthis location" },
        { type: MessageType.knight_occupied,
          decoration: NOTIFICATION_SHOW_BUILDING,
          icon: 0,
          text: "A knight has\noccupied this\nnew building" },
        { type: MessageType.new_stock,
          decoration: NOTIFICATION_SHOW_MAP_OBJECT,
          icon: _mbs[BuildingType.stock],
          text: "A new stock\nhas been built" },
        { type: MessageType.lost_land,
          decoration: NOTIFICATION_SHOW_OPPONENT,
          icon: 0,
          text: "Because of this\nenemy building\nyou lost some\nland" },
        { type: MessageType.lost_buildings,
          decoration: NOTIFICATION_SHOW_OPPONENT,
          icon: 0,
          text: "Because of this\nenemy building\nyou lost some\nland and\nsome buildings" },
        { type: MessageType.emergency_active,
          decoration: NOTIFICATION_SHOW_MAP_OBJECT,
          icon: _mbs[BuildingType.castle] + 1,
          text: "Emergency\nprogram\nactivated" },
        { type: MessageType.emergency_neutral,
          decoration: NOTIFICATION_SHOW_MAP_OBJECT,
          icon: _mbs[BuildingType.castle],
          text: "Emergency\nprogram\nneutralized" },
        { type: MessageType.found_gold,
          decoration: NOTIFICATION_SHOW_ICON,
          icon: 0x2f,
          text: "A geologist\nhas found gold" },
        { type: MessageType.found_iron,
          decoration: NOTIFICATION_SHOW_ICON,
          icon: 0x2c,
          text: "A geologist\nhas found iron" },
        { type: MessageType.found_coal,
          decoration: NOTIFICATION_SHOW_ICON,
          icon: 0x2e,
          text: "A geologist\nhas found coal" },
        { type: MessageType.found_stone,
          decoration: NOTIFICATION_SHOW_ICON,
          icon: 0x2b,
          text: "A geologist\nhas found stone" },
        { type: MessageType.call_to_menu,
          decoration: NOTIFICATION_SHOW_MENU,
          icon: 0,
          text: "You wanted me\nto call you\nto this menu" },
        { type: MessageType.thirty_m_since_save,
          decoration: NOTIFICATION_SHOW_ICON,
          icon: 0x5d,
          text: "30 min. passed\nsince the last\nsaving" },
        { type: MessageType.one_h_since_save,
          decoration: NOTIFICATION_SHOW_ICON,
          icon: 0x5d,
          text: "One hour passed\nsince the last\nsaving" },
        { type: MessageType.call_to_stock,
          decoration: NOTIFICATION_SHOW_MAP_OBJECT,
          icon: _mbs[BuildingType.stock],
          text: "You wanted me\nto call you\nto this stock" },
        { type: MessageType.none, decoration: 0, icon: 0, text: undefined }
    ];

    // const int map_menu_sprite[] (NotificationBox::draw_notification)
    global.notification_map_menu_sprite = [
        0xe6, 0xe7, 0xe8, 0xe9,
        0xea, 0xeb, 0x12a, 0x12b
    ];
}

function NotificationBox(_interface) : GuiObject() constructor {
    notification_init_tables();

    // Message message; (default: TypeNone, pos 0, data 0)
    message = { type: MessageType.none, pos: 0, data: 0 };
    interface = _interface;

    static draw_icon = function(_ix, _iy, _sprite) {
        gfx_draw_sprite(8 * _ix, _iy, Asset.icon, _sprite);
    };

    static draw_bg = function(_bwidth, _bheight, _sprite) {   // C++ draw_background (legacy GM built-in name)
        for (var _sy = 0; _sy < _bheight; _sy += 16) {
            for (var _sx = 0; _sx < _bwidth; _sx += 16) {
                gfx_draw_sprite(_sx, _sy, Asset.icon, _sprite);
            }
        }
    };

    /// Draws each '\n'-separated line 10 px apart (std::getline loop).
    static draw_text_lines = function(_sx, _sy, _str) {
        var _cy = _sy;
        var _rest = _str;
        while (string_length(_rest) > 0) {
            var _nl = string_pos("\n", _rest);
            var _line = "";
            if (_nl == 0) {
                _line = _rest;
                _rest = "";
            } else {
                _line = string_copy(_rest, 1, _nl - 1);
                _rest = string_delete(_rest, 1, _nl);
            }
            gfx_draw_string(_sx * 8, _cy, _line, NOTIFICATION_COLOR_GREEN, -1);
            _cy += 10;
        }
    };

    static draw_map_object = function(_ox, _oy, _sprite) {
        gfx_draw_sprite(8 * _ox, _oy, Asset.map_object, _sprite);
    };

    static get_player_face_sprite = function(_face) {
        if (_face != 0) {
            return 0x10b + _face;
        }
        return 0x119; /* sprite_face_none */
    };

    static draw_player_face = function(_fx, _fy, _player) {
        var _p = interface.get_game().get_player(_player);
        var _color = interface.get_player_color(_player);
        gfx_fill_rect(8 * _fx, _fy, 48, 72, _color);
        draw_icon(_fx + 1, _fy + 4, get_player_face_sprite(_p.get_face()));
    };

    /* Messages boxes */
    static draw_notification = function(_view) {
        var _map_menu_sprite = global.notification_map_menu_sprite;
        var _mbs = global.interface_map_building_sprite;

        draw_text_lines(1, 10, _view.text);
        switch (_view.decoration) {
            case NOTIFICATION_SHOW_OPPONENT:
                draw_player_face(18, 8, message.data);
                break;
            case NOTIFICATION_SHOW_MINE:
                draw_map_object(18, 8, _mbs[BuildingType.stone_mine] + message.data);
                break;
            case NOTIFICATION_SHOW_BUILDING:
                switch (message.data) {
                    case 0:
                        draw_map_object(18, 8, _mbs[BuildingType.hut]);
                        break;
                    case 1:
                        draw_map_object(18, 8, _mbs[BuildingType.tower]);
                        break;
                    case 2:
                        draw_map_object(16, 8, _mbs[BuildingType.fortress]);
                        break;
                    default:
                        throw ("NotificationBox::draw_notification: NOT_REACHED");
                        break;
                }
                break;
            case NOTIFICATION_SHOW_MAP_OBJECT:
                draw_map_object(16, 8, _view.icon);
                break;
            case NOTIFICATION_SHOW_ICON:
                draw_icon(20, 14, _view.icon);
                break;
            case NOTIFICATION_SHOW_MENU:
                draw_icon(18, 8, _map_menu_sprite[message.data]);
                break;
            default:
                break;
        }
    };

    static internal_draw = function() {
        draw_bg(width, height, 0x13a);
        draw_icon(14, 128, 0x120); /* Checkbox */

        var _views = global.notification_views;
        for (var _i = 0; _views[_i].type != MessageType.none; _i++) {
            if (_views[_i].type == message.type) {
                draw_notification(_views[_i]);
            }
        }
    };

    static handle_click_left = function(_x, _y) {
        set_displayed(false);
        return true;
    };

    static show = function(_message) {
        message = _message;
        set_displayed(true);
    };
}
