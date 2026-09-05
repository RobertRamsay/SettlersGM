// scr_popup_b.gml - Ported from Freeserf src/popup.cc lines 1479-2606 (GPL-3.0),
// original copyright (C) 2013-2018 Jon Lund Steffensen <jonlst@gmail.com>.
// PopupBox::draw_start_attack_redraw_box .. PopupBox::draw_save_box as global
// functions popup_<name>(_popup, ...) where _popup is the PopupBox struct.
//
// Ported from Freeserf (GPL-3.0), original copyright (C) 2013-2018 Jon Lund Steffensen.

/// Static tables for this range (file-level const arrays in the C++ functions).
function popup_b_init_tables() {
    if (variable_global_exists("popup_b_tables_ready")) {
        return;
    }
    global.popup_b_tables_ready = true;

    // interface.h: map_building_sprite[] (indexed by BuildingType)
    global.popup_b_map_building_sprite = [
        0, 0xa7, 0xa8, 0xae, 0xa9,
        0xa3, 0xa4, 0xa5, 0xa6,
        0xaa, 0xc0, 0xab, 0x9a, 0x9c, 0x9b, 0xbc,
        0xa2, 0xa0, 0xa1, 0x99, 0x9d, 0x9e, 0x98, 0x9f, 0xb2
    ];

    // draw_start_attack_box
    global.popup_b_start_attack_building_layout = [
        0x0, 2, 33,
        0xa, 6, 30,
        0x7, 10, 33,
        0xc, 14, 30,
        0xe, 2, 36,
        0x2, 6, 39,
        0xb, 10, 36,
        0x4, 12, 39,
        0x8, 8, 42,
        0xf, 12, 42,
        -1
    ];
    global.popup_b_start_attack_icon_layout = [
        216, 1, 80,
        217, 5, 80,
        218, 9, 80,
        219, 13, 80,
        220, 4, 112,
        221, 10, 112,
        222, 0, 128,
        60, 14, 128,
        -1
    ];

    // draw_ground_analysis_box
    global.popup_b_ground_analysis_layout = [
        0x1c, 7, 10,
        0x2f, 1, 50,
        0x2c, 1, 70,
        0x2e, 1, 90,
        0x2b, 1, 110,
        0x3c, 14, 128,
        -1
    ];

    // draw_sett_select_box
    global.popup_b_sett_select_layout = [
        230, 1, 8,
        231, 6, 8,
        232, 11, 8,
        234, 1, 48,
        235, 6, 48,
        299, 11, 48,
        233, 1, 88,
        298, 6, 88,
        61, 12, 104,
        60, 14, 128,

        285, 4, 128,
        286, 0, 128,
        224, 8, 128,
        -1
    ];

    // draw_sett_1_box
    global.popup_b_sett_1_bld_layout = [
        163, 12, 21,
        164, 8, 41,
        165, 4, 61,
        166, 0, 81,
        -1
    ];
    global.popup_b_sett_1_layout = [
        34, 4, 1,
        36, 7, 1,
        39, 10, 1,
        60, 14, 128,
        295, 1, 8,
        -1
    ];
    global.popup_b_sett_1_prio_layout = [
        4,  21, BuildingType.stone_mine,
        0,  41, BuildingType.coal_mine,
        8, 114, BuildingType.iron_mine,
        4, 133, BuildingType.gold_mine
    ];

    // draw_sett_2_box
    global.popup_b_sett_2_bld_layout = [
        186, 2, 0,
        174, 2, 41,
        153, 8, 54,
        157, 0, 102,
        -1
    ];
    global.popup_b_sett_2_layout = [
        41, 9, 25,
        45, 9, 119,
        60, 14, 128,
        295, 13, 8,
        -1
    ];

    // draw_sett_3_box
    global.popup_b_sett_3_bld_layout = [
        161, 0, 1,
        159, 10, 0,
        157, 4, 56,
        188, 12, 61,
        155, 0, 101,
        -1
    ];
    global.popup_b_sett_3_layout = [
        46, 7, 19,
        37, 8, 101,
        60, 14, 128,
        295, 1, 60,
        -1
    ];

    // draw_knight_level_box
    global.popup_b_knight_level_str = [
        "Minimum", "Weak", "Medium", "Good", "Full", "ERROR", "ERROR", "ERROR"
    ];
    global.popup_b_knight_level_layout = [
        226, 0, 2,
        227, 0, 36,
        228, 0, 70,
        229, 0, 104,

        220, 4, 2,  /* minus */
        221, 6, 2,  /* plus */
        220, 4, 18, /* ... */
        221, 6, 18,
        220, 4, 36,
        221, 6, 36,
        220, 4, 52,
        221, 6, 52,
        220, 4, 70,
        221, 6, 70,
        220, 4, 86,
        221, 6, 86,
        220, 4, 104,
        221, 6, 104,
        220, 4, 120,
        221, 6, 120,

        60, 14, 128, /* exit */
        -1
    ];

    // draw_sett_4_box
    global.popup_b_sett_4_layout = [
        49, 1, 0, /* shovel */
        50, 1, 16, /* hammer */
        54, 1, 32, /* axe */
        55, 1, 48, /* saw */
        53, 1, 64, /* scythe */
        56, 1, 80, /* pick */
        57, 1, 96, /* pincer */
        52, 1, 112, /* cleaver */
        51, 1, 128, /* rod */

        60, 14, 128, /* exit*/
        295, 13, 8, /* default */
        -1
    ];

    // draw_popup_resource_stairs
    global.popup_b_spiral_layout = [
        5, 4,
        7, 6,
        9, 8,
        11, 10,
        13, 12,
        13, 28,
        11, 30,
        9, 32,
        7, 34,
        5, 36,
        3, 38,
        1, 40,
        1, 56,
        3, 58,
        5, 60,
        7, 62,
        9, 64,
        11, 66,
        13, 68,
        13, 84,
        11, 86,
        9, 88,
        7, 90,
        5, 92,
        3, 94,
        1, 96
    ];

    // draw_sett_5_box
    global.popup_b_sett_5_layout = [
        237, 1, 120, /* up */
        238, 3, 120, /* smallup */
        239, 9, 120, /* smalldown */
        240, 11, 120, /* down */
        295, 1, 4, /* default*/
        60, 14, 128, /* exit */
        -1
    ];

    // draw_castle_res_box
    global.popup_b_castle_res_layout = [
        0x3d, 12, 128, /* flip */
        0x3c, 14, 128, /* exit */
        -1
    ];

    // draw_mine_output_box
    global.popup_b_mine_output_weight = [ 10, 10, 9, 9, 8, 8, 7, 7,
                                           6,  6, 5, 5, 4, 3, 2, 1 ];

    // draw_transport_info_box
    global.popup_b_transport_info_layout = [
        9, 24,
        5, 24,
        3, 44,
        5, 64,
        9, 64,
        11, 44
    ];

    // draw_castle_serf_box
    global.popup_b_castle_serf_layout = [
        0x3d, 12, 128, /* flip */
        0x3c, 14, 128, /* exit */
        -1
    ];

    // draw_resdir_box
    global.popup_b_resdir_layout = [
        0x128, 4, 16,
        0x129, 4, 80,
        0xdc, 9, 16,
        0xdc, 9, 32,
        0xdc, 9, 48,
        0xdc, 9, 80,
        0xdc, 9, 96,
        0xdc, 9, 112,
        0x3d, 12, 128,
        0x3c, 14, 128,
        -1
    ];
    global.popup_b_resdir_knights_layout = [
        0x21, 12, 16,
        0x20, 12, 36,
        0x1f, 12, 56,
        0x1e, 12, 76,
        0x1d, 12, 96,
        -1
    ];

    // draw_sett_8_box
    global.popup_b_sett_8_layout = [
        9, 2, 8,
        29, 12, 8,
        300, 2, 28,
        59, 7, 44,
        130, 8, 28,
        58, 9, 44,
        304, 3, 64,
        303, 11, 64,
        302, 2, 84,
        220, 6, 84,
        220, 6, 100,
        301, 10, 84,
        220, 3, 120,
        221, 9, 120,
        60, 14, 128,
        -1
    ];

    // draw_sett_6_box
    global.popup_b_sett_6_layout = [
        237, 1, 120,
        238, 3, 120,
        239, 9, 120,
        240, 11, 120,

        295, 1, 4, /* default */
        60, 14, 128, /* exit */
        -1
    ];

    // draw_bld_1_box
    global.popup_b_bld_1_layout = [
        0xc0, 0, 5, /* stock */
        0xab, 2, 77, /* hut */
        0x9e, 8, 7, /* tower */
        0x98, 6, 69, /* fortress */
        -1
    ];

    // draw_bld_2_box
    global.popup_b_bld_2_layout = [
        153, 0, 4,
        160, 8, 6,
        157, 0, 68,
        169, 8, 65,
        174, 12, 57,
        170, 4, 105,
        168, 8, 107,
        -1
    ];

    // draw_bld_3_box
    global.popup_b_bld_3_layout = [
        155, 0, 2,
        154, 8, 3,
        167, 0, 61,
        156, 8, 60,
        188, 4, 75,
        162, 8, 100,
        -1
    ];

    // draw_bld_4_box
    global.popup_b_bld_4_layout = [
        163, 0, 4,
        164, 4, 4,
        165, 8, 4,
        166, 12, 4,
        161, 2, 90,
        159, 8, 90,
        -1
    ];

    // draw_building_stock_box
    global.popup_b_map_building_serf_sprite = [
        -1, 0x13, 0xd, 0x19,
        0xf, -1, -1, -1,
        -1, 0x10, -1, -1,
        0x16, 0x15, 0x14, 0x17,
        0x18, 0xe, 0x12, 0x1a,
        0x1b, -1, -1, 0x12,
        -1
    ];

    // draw_save_box
    global.popup_b_save_layout = [
        224, 0, 128,
        -1
    ];
}

function popup_draw_start_attack_redraw_box(_popup) {
    /* TODO Should overwrite the previously drawn number.
       Just use fill_rect(), perhaps? */
    _popup.draw_green_string(6, 116, "    ");
    _popup.draw_green_number(7, 116, _popup.interface.get_player().knights_attacking);
}

function popup_draw_start_attack_box(_popup) {
    popup_b_init_tables();
    var _building_layout = global.popup_b_start_attack_building_layout;
    var _icon_layout = global.popup_b_start_attack_icon_layout;

    _popup.draw_box_background(BackgroundPattern.construction);

    for (var _i = 0; _building_layout[_i] >= 0; _i += 3) {
        _popup.draw_popup_building(_building_layout[_i + 1], _building_layout[_i + 2],
                                   _building_layout[_i]);
    }

    var _building = _popup.interface.get_game().get_building(
                                _popup.interface.get_player().building_attacked);
    var _ly = 0;

    switch (_building.get_type()) {
        case BuildingType.hut: _ly = 50; break;
        case BuildingType.tower: _ly = 32; break;
        case BuildingType.fortress: _ly = 17; break;
        case BuildingType.castle: _ly = 0; break;
        default: throw ("NOT_REACHED: draw_start_attack_box"); break;
    }

    _popup.draw_popup_building(0, _ly, global.popup_b_map_building_sprite[_building.get_type()]);
    _popup.draw_custom_icon_box(_icon_layout);

    /* Draw number of knight at each distance. */
    for (var _i = 0; _i < 4; _i++) {
        _popup.draw_green_number(1 + 4 * _i, 96, _popup.interface.get_player().attacking_knights[_i]);
    }

    popup_draw_start_attack_redraw_box(_popup);
}

function popup_draw_ground_analysis_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_ground_analysis_layout;

    var _pos = _popup.interface.get_map_cursor_pos();
    var _estimates = array_create(5, 0);

    _popup.draw_box_background(BackgroundPattern.striped_green);
    _popup.draw_custom_icon_box(_layout);
    // Game::prepare_ground_analysis(pos, int estimates[5]) - out-param array;
    // the GML port fills the array passed in (arrays are references).
    _popup.interface.get_game().prepare_ground_analysis(_pos, _estimates);
    _popup.draw_green_string(0, 30, "GROUND-ANALYSIS:");

    /* Gold */
    var _s = _popup.prepare_res_amount_text(2 * _estimates[Minerals.gold]);
    _popup.draw_green_string(3, 54, _s);

    /* Iron */
    _s = _popup.prepare_res_amount_text(_estimates[Minerals.iron]);
    _popup.draw_green_string(3, 74, _s);

    /* Coal */
    _s = _popup.prepare_res_amount_text(_estimates[Minerals.coal]);
    _popup.draw_green_string(3, 94, _s);

    /* Stone */
    _s = _popup.prepare_res_amount_text(2 * _estimates[Minerals.stone]);
    _popup.draw_green_string(3, 114, _s);
}

function popup_draw_sett_select_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_sett_select_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_icon_box(_layout);
}

/* Draw slide bar in a popup box. */
function popup_draw_slide_bar(_popup, _lx, _ly, _value) {
    _popup.draw_popup_icon(_lx, _ly, 236);

    var _lwidth = _value div 1310;
    if (_lwidth > 0) {
        gfx_fill_rect(8 * _lx + 15, _ly + 11, _lwidth, 4, make_colour_rgb(0x6b, 0xab, 0x3b));
    }
}

function popup_draw_sett_1_box(_popup) {
    popup_b_init_tables();
    var _bld_layout = global.popup_b_sett_1_bld_layout;
    var _layout = global.popup_b_sett_1_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_bld_box(_bld_layout);
    _popup.draw_custom_icon_box(_layout);

    var _player = _popup.interface.get_player();

    var _prio_layout = global.popup_b_sett_1_prio_layout;

    for (var _i = 0; _i < 4; _i++) {
        popup_draw_slide_bar(_popup, _prio_layout[_i * 3], _prio_layout[_i * 3 + 1],
                             _player.get_food_for_building(_prio_layout[_i * 3 + 2]));
    }
}

function popup_draw_sett_2_box(_popup) {
    popup_b_init_tables();
    var _bld_layout = global.popup_b_sett_2_bld_layout;
    var _layout = global.popup_b_sett_2_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_bld_box(_bld_layout);
    _popup.draw_custom_icon_box(_layout);

    var _player = _popup.interface.get_player();

    popup_draw_slide_bar(_popup, 0, 26, _player.get_planks_construction());
    popup_draw_slide_bar(_popup, 0, 36, _player.get_planks_boatbuilder());
    popup_draw_slide_bar(_popup, 8, 44, _player.get_planks_toolmaker());
    popup_draw_slide_bar(_popup, 8, 103, _player.get_steel_toolmaker());
    popup_draw_slide_bar(_popup, 0, 130, _player.get_steel_weaponsmith());
}

function popup_draw_sett_3_box(_popup) {
    popup_b_init_tables();
    var _bld_layout = global.popup_b_sett_3_bld_layout;
    var _layout = global.popup_b_sett_3_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_bld_box(_bld_layout);
    _popup.draw_custom_icon_box(_layout);

    var _player = _popup.interface.get_player();

    popup_draw_slide_bar(_popup, 0, 39, _player.get_coal_steelsmelter());
    popup_draw_slide_bar(_popup, 8, 39, _player.get_coal_goldsmelter());
    popup_draw_slide_bar(_popup, 4, 47, _player.get_coal_weaponsmith());
    popup_draw_slide_bar(_popup, 0, 92, _player.get_wheat_pigfarm());
    popup_draw_slide_bar(_popup, 8, 118, _player.get_wheat_mill());
}

function popup_draw_knight_level_box(_popup) {
    popup_b_init_tables();
    var _level_str = global.popup_b_knight_level_str;
    var _layout = global.popup_b_knight_level_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);

    var _player = _popup.interface.get_player();

    for (var _i = 0; _i < 4; _i++) {
        var _ly = 8 + (34 * _i);
        _popup.draw_green_string(8, _ly,
                                 _level_str[(_player.get_knight_occupation(3 - _i) >> 4) & 0x7]);
        _popup.draw_green_string(8, _ly + 11,
                                 _level_str[_player.get_knight_occupation(3 - _i) & 0x7]);
    }

    _popup.draw_custom_icon_box(_layout);
}

function popup_draw_sett_4_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_sett_4_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_icon_box(_layout);

    var _player = _popup.interface.get_player();
    popup_draw_slide_bar(_popup, 4, 4, _player.get_tool_prio(0)); /* shovel */
    popup_draw_slide_bar(_popup, 4, 20, _player.get_tool_prio(1)); /* hammer */
    popup_draw_slide_bar(_popup, 4, 36, _player.get_tool_prio(5)); /* axe */
    popup_draw_slide_bar(_popup, 4, 52, _player.get_tool_prio(6)); /* saw */
    popup_draw_slide_bar(_popup, 4, 68, _player.get_tool_prio(4)); /* scythe */
    popup_draw_slide_bar(_popup, 4, 84, _player.get_tool_prio(7)); /* pick */
    popup_draw_slide_bar(_popup, 4, 100, _player.get_tool_prio(8)); /* pincer */
    popup_draw_slide_bar(_popup, 4, 116, _player.get_tool_prio(3)); /* cleaver */
    popup_draw_slide_bar(_popup, 4, 132, _player.get_tool_prio(2)); /* rod */
}

/* Draw generic popup box of resource stairs. */
/* _order: array of 26 ints (Player flag_prio / inventory_prio). */
function popup_draw_popup_resource_stairs(_popup, _order) {
    popup_b_init_tables();
    var _spiral_layout = global.popup_b_spiral_layout;

    for (var _i = 0; _i < 26; _i++) {
        var _pos = 26 - _order[_i];
        _popup.draw_popup_icon(_spiral_layout[2 * _pos], _spiral_layout[2 * _pos + 1], 34 + _i);
    }
}

function popup_draw_sett_5_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_sett_5_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_icon_box(_layout);
    popup_draw_popup_resource_stairs(_popup, _popup.interface.get_player().get_flag_prio());

    _popup.draw_popup_icon(6, 120, 33 + _popup.current_sett_5_item);
}

function popup_draw_quit_confirm_box(_popup) {
    _popup.draw_box_background(BackgroundPattern.diagonal_green);

    _popup.draw_green_string(0, 10, "   Do you want");
    _popup.draw_green_string(0, 20, "     to quit");
    _popup.draw_green_string(0, 30, "   this game?");
    _popup.draw_green_string(0, 45, "  Yes       No");
}

/// Confirm dispatching a geologist to the flag under the map cursor. Reached
/// by pressing both mouse buttons on one of your own flags.
function popup_draw_send_geologist_confirm_box(_popup) {
    _popup.draw_box_background(BackgroundPattern.diagonal_green);

    /* draw_green_string(sx, sy) lands at (8 * sx + 8, sy + 9) and the font is
       8px per character, so a 14 character line centres in the 128px interior
       at sx = 1 and a 16px icon centres at sx = 7. */
    _popup.draw_green_string(1, 16, "Send geologist");
    _popup.draw_green_string(1, 26, "to this flag?");

    /* Same icon the transport info box uses for its geologist button. */
    _popup.draw_popup_icon(7, 52, 0x1c);

    _popup.draw_green_string(3, 100, "Yes");
    _popup.draw_green_string(11, 100, "No");

    _popup.draw_popup_icon(14, 128, 60); /* Exit */
}

function popup_draw_no_save_quit_confirm_box(_popup) {
    _popup.draw_green_string(0, 70, "The game has not");
    _popup.draw_green_string(0, 80, "   been saved");
    _popup.draw_green_string(0, 90, "   recently.");
    _popup.draw_green_string(0, 100, "    Are you");
    _popup.draw_green_string(0, 110, "     sure?");
    _popup.draw_green_string(0, 125, "  Yes       No");
}

function popup_draw_options_box(_popup) {
    _popup.draw_box_background(BackgroundPattern.diagonal_green);

    _popup.draw_green_string(1, 14, "Music");
    _popup.draw_green_string(1, 30, "Sound");
    _popup.draw_green_string(1, 39, "effects");
    _popup.draw_green_string(1, 54, "Volume");

    // Audio::get_instance() -> audio_get_instance() (scr_audio.gml, Audio singleton struct)
    var _audio = audio_get_instance();
    var _player = _audio.get_music_player();
    // Music
    var _music_sprite = 220;
    if ((_player != undefined) && _player.is_enabled()) {
        _music_sprite = 288;
    }
    _popup.draw_popup_icon(13, 10, _music_sprite);
    _player = _audio.get_sound_player();
    // Sfx
    var _sfx_sprite = 220;
    if ((_player != undefined) && _player.is_enabled()) {
        _sfx_sprite = 288;
    }
    _popup.draw_popup_icon(13, 30, _sfx_sprite);
    _popup.draw_popup_icon(11, 50, 220); /* Volume minus */
    _popup.draw_popup_icon(13, 50, 221); /* Volume plus */

    var _volume = 0.0;
    var _volume_controller = _audio.get_volume_controller();
    if (_volume_controller != undefined) {
        _volume = 99.0 * _volume_controller.get_volume();
    }
    var _str = string(floor(_volume));
    _popup.draw_green_string(8, 54, _str);

    _popup.draw_green_string(1, 70, "Fullscreen");
    _popup.draw_green_string(1, 79, "video");

    /* Fullscreen mode */
    var _fullscreen_sprite = 220;
    if (window_get_fullscreen()) {
        _fullscreen_sprite = 288;
    }
    _popup.draw_popup_icon(13, 70, _fullscreen_sprite);

    var _value = "All";
    if (!_popup.interface.get_config(3)) {
        _value = "Most";
        if (!_popup.interface.get_config(4)) {
            _value = "Few";
            if (!_popup.interface.get_config(5)) {
                _value = "None";
            }
        }
    }
    _popup.draw_green_string(1, 94, "Messages");
    _popup.draw_green_string(11, 94, _value);

    // Not in the original. There are only two possible drag behaviours and they
    // differ by nothing but the sign: No grabs the ground, so the pixel under
    // the cursor stays under it, and Yes is Freeserf's original, where the drag
    // pushes the view and the map slides against the hand. Both are pixel exact
    // at any zoom - Viewport.handle_event divides the delta by the zoom, with a
    // carry, before this ever sees it.
    var _invert_value = "No";
    if (global.map_drag_invert) {
        _invert_value = "Yes";
    }
    _popup.draw_green_string(1, 110, "Invert");
    _popup.draw_green_string(11, 110, _invert_value);

    _popup.draw_popup_icon(14, 128, 60); /* exit */
}

function popup_draw_castle_res_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_castle_res_layout;

    _popup.draw_box_background(BackgroundPattern.plaid_along_green);
    _popup.draw_custom_icon_box(_layout);

    if (_popup.interface.get_player().temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _building = _popup.interface.get_game().get_building(_popup.interface.get_player().temp_index);
    if (_building.is_burning()) {
        _popup.interface.close_popup();
        return;
    }

    if (_building.get_type() != BuildingType.stock &&
        _building.get_type() != BuildingType.castle) {
        _popup.interface.close_popup();
        return;
    }

    var _inventory = _building.get_inventory();
    // ResourceMap -> array indexed by ResourceType
    var _resources = _inventory.get_all_resources();
    _popup.draw_resources_box(_resources);
}

function popup_draw_mine_output_box(_popup) {
    popup_b_init_tables();
    _popup.draw_box_background(BackgroundPattern.plaid_along_green);

    if (_popup.interface.get_player().temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _building = _popup.interface.get_game().get_building(_popup.interface.get_player().temp_index);
    if (_building.is_burning()) {
        _popup.interface.close_popup();
        return;
    }

    var _type = _building.get_type();

    if (_type != BuildingType.stone_mine &&
        _type != BuildingType.coal_mine &&
        _type != BuildingType.iron_mine &&
        _type != BuildingType.gold_mine) {
        _popup.interface.close_popup();
        return;
    }

    /* Draw building */
    _popup.draw_popup_building(6, 60, global.popup_b_map_building_sprite[_type]);

    /* Draw serf icon */
    var _sprite = 0xdc; /* minus box */
    if (_building.has_serf()) {
        _sprite = 0x11; /* miner */
    }

    _popup.draw_popup_icon(10, 75, _sprite);

    /* Draw food present at mine */
    var _stock = _building.get_res_count_in_stock(0);
    var _stock_left_col = (_stock + 1) >> 1;
    var _stock_right_col = _stock >> 1;

    /* Left column */
    for (var _i = 0; _i < _stock_left_col; _i++) {
        _popup.draw_popup_icon(1, 90 - 8 * _stock_left_col + _i * 16,
                               0x24); /* meat (food) sprite */
    }

    /* Right column */
    for (var _i = 0; _i < _stock_right_col; _i++) {
        _popup.draw_popup_icon(13, 90 - 8 * _stock_right_col + _i * 16,
                               0x24); /* meat (food) sprite */
    }

    /* Calculate output percentage (simple WMA) */
    var _output_weight = global.popup_b_mine_output_weight;
    var _output = 0;
    for (var _i = 0; _i < 15; _i++) {
        if ((_building.get_progress() & (1 << _i)) != 0) {
            _output += _output_weight[_i];
        }
    }

    /* Print output precentage */
    var _lx = 7;
    if (_output >= 100) {
        _lx += 1;
    }
    if (_output >= 10) {
        _lx += 1;
    }
    _popup.draw_green_string(_lx, 38, "%");
    _popup.draw_green_number(6, 38, _output);

    _popup.draw_green_string(1, 14, "MINING");
    _popup.draw_green_string(1, 24, "OUTPUT:");

    /* Exit box */
    _popup.draw_popup_icon(14, 128, 0x3c);
}

function popup_draw_ordered_building_box(_popup) {
    popup_b_init_tables();
    _popup.draw_box_background(BackgroundPattern.plaid_along_green);

    if (_popup.interface.get_player().temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _building = _popup.interface.get_game().get_building(_popup.interface.get_player().temp_index);
    if (_building.is_burning()) {
        _popup.interface.close_popup();
        return;
    }

    var _type = _building.get_type();

    var _sprite = global.popup_b_map_building_sprite[_type];
    var _lx = 6;
    if (_sprite == 0xc0 /*stock*/ || _sprite < 0x9e /*tower*/) {
        _lx = 4;
    }
    _popup.draw_popup_building(_lx, 40, _sprite);

    _popup.draw_green_string(2, 4, "Ordered");
    _popup.draw_green_string(2, 14, "Building");

    if (_building.has_serf()) {
        if (_building.get_progress() == 0) { /* Digger */
            _popup.draw_popup_icon(2, 100, 0xb);
        } else { /* Builder */
            _popup.draw_popup_icon(2, 100, 0xc);
        }
    } else {
        _popup.draw_popup_icon(2, 100, 0xdc); /* Minus box */
    }

    _popup.draw_popup_icon(14, 128, 0x3c); /* Exit box */
}

function popup_draw_defenders_box(_popup) {
    popup_b_init_tables();
    _popup.draw_box_background(BackgroundPattern.plaid_along_green);

    var _player = _popup.interface.get_player();
    if (_player.temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _building = _popup.interface.get_game().get_building(_player.temp_index);
    if (_building.is_burning()) {
        _popup.interface.close_popup();
        return;
    }

    if (_building.get_owner() != _player.get_index()) {
        _popup.interface.close_popup();
        return;
    }

    if (_building.get_type() != BuildingType.hut &&
        _building.get_type() != BuildingType.tower &&
        _building.get_type() != BuildingType.fortress) {
        _popup.interface.close_popup();
        return;
    }

    /* Draw building sprite */
    var _sprite = global.popup_b_map_building_sprite[_building.get_type()];
    var _lx = 0;
    var _ly = 0;
    switch (_building.get_type()) {
        case BuildingType.hut:
            _lx = 6;
            _ly = 20;
            break;
        case BuildingType.tower:
            _lx = 4;
            _ly = 6;
            break;
        case BuildingType.fortress:
            _lx = 4;
            _ly = 1;
            break;
        default:
            throw ("NOT_REACHED: draw_defenders_box");
    }

    _popup.draw_popup_building(_lx, _ly, _sprite);

    /* Draw gold stock */
    if (_building.get_res_count_in_stock(1) > 0) {
        var _left = (_building.get_res_count_in_stock(1) + 1) div 2;
        for (var _i = 0; _i < _left; _i++) {
            _popup.draw_popup_icon(1, 32 - 8 * _left + 16 * _i, 0x30);
        }

        var _right = _building.get_res_count_in_stock(1) div 2;
        for (var _i = 0; _i < _right; _i++) {
            _popup.draw_popup_icon(13, 32 - 8 * _right + 16 * _i, 0x30);
        }
    }

    /* Draw heading string */
    _popup.draw_green_string(3, 62, "Defenders:");

    /* Draw knights */
    var _next_knight = _building.get_first_knight();
    for (var _i = 0; _next_knight != 0; _i++) {
        var _serf = _popup.interface.get_game().get_serf(_next_knight);
        _popup.draw_popup_icon(3 + 4 * (_i mod 3), 72 + 16 * (_i div 3), 7 + _serf.get_type());
        _next_knight = _serf.get_next();
    }

    _popup.draw_green_string(0, 128, "State:");
    _popup.draw_green_number(7, 128, _building.get_threat_level());

    _popup.draw_popup_icon(14, 128, 0x3c); /* Exit box */
}

function popup_draw_transport_info_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_transport_info_layout;

    _popup.draw_box_background(BackgroundPattern.plaid_along_green);

    /* TODO show path merge button. */
    /* if (r == 0) draw_popup_icon(7, 51, 0x135); */

    if (_popup.interface.get_player().temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _flag = _popup.interface.get_game().get_flag(_popup.interface.get_player().temp_index);

    /* Draw viewport of flag */
    if (_popup.flag_view == undefined) {
        var _new_view = new Viewport(_popup.interface, _popup.interface.get_game().get_map());
        _new_view.switch_layer(ViewportLayer.landscape);
        _new_view.switch_layer(ViewportLayer.serfs);
        _new_view.switch_layer(ViewportLayer.cursor);
        _new_view.set_displayed(true);
        _new_view.set_parent(_popup);
        _new_view.set_size(128, 64);
        _new_view.move_to(8, 24);
        _popup.flag_view = _new_view;
    }

    var _flag_view = _popup.flag_view;
    _flag_view.move_to_map_pos(_flag.get_position());
    _flag_view.move_by_pixels(0, -10);
    _flag_view.set_redraw();
    _flag_view.draw();

    // for (Direction d : cycle_directions_cw())
    for (var _d = Direction.right; _d <= Direction.up; _d++) {
        var _index = 5 - _d;
        var _lx = _layout[2 * _index];
        var _ly = _layout[2 * _index + 1];
        if (_flag.has_path(_d)) {
            var _sprite = 0xdc; /* Minus box */
            if (_flag.has_transporter(_d)) {
                _sprite = 0x120; /* Check box */
            }
            _popup.draw_popup_icon(_lx, _ly, _sprite);
        }
    }

    _popup.draw_green_string(0, 4, "Transport Info:");
    _popup.draw_popup_icon(2, 96, 0x1c); /* Geologist */
    _popup.draw_popup_icon(14, 128, 0x3c); /* Exit box */

    /* Draw list of resources */
    for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
        if (_flag.get_resource_at_slot(_i) != ResourceType.none) {
            _popup.draw_popup_icon(7 + 2 * (_i & 3), 88 + 16 * (_i >> 2),
                                   0x22 + _flag.get_resource_at_slot(_i));
        }
    }

    _popup.draw_green_string(0, 128, "Index:");
    _popup.draw_green_number(7, 128, _flag.get_index());
}

function popup_draw_castle_serf_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_castle_serf_layout;

    var _serfs = array_create(27, 0);

    _popup.draw_box_background(BackgroundPattern.plaid_along_green);
    _popup.draw_custom_icon_box(_layout);

    if (_popup.interface.get_player().temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _building = _popup.interface.get_game().get_building(_popup.interface.get_player().temp_index);
    if (_building.is_burning()) {
        _popup.interface.close_popup();
        return;
    }

    var _type = _building.get_type();
    if (_type != BuildingType.stock && _type != BuildingType.castle) {
        _popup.interface.close_popup();
        return;
    }

    var _inventory = _building.get_inventory();
    var _list = _popup.interface.get_game().get_serfs_in_inventory(_inventory);
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _serf = _list[_i];
        _serfs[_serf.get_type()] += 1;
    }

    _popup.draw_serfs_box(_serfs, -1);
}

function popup_draw_resdir_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_resdir_layout;
    var _knights_layout = global.popup_b_resdir_knights_layout;

    _popup.draw_box_background(BackgroundPattern.plaid_along_green);
    _popup.draw_custom_icon_box(_layout);

    if (_popup.interface.get_player().temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _building = _popup.interface.get_game().get_building(_popup.interface.get_player().temp_index);
    if (_building.is_burning()) {
        _popup.interface.close_popup();
        return;
    }

    var _type = _building.get_type();
    if (_type == BuildingType.castle) {
        var _knights = [ 0, 0, 0, 0, 0 ];
        _popup.draw_custom_icon_box(_knights_layout);

        /* Follow linked list of knights on duty */
        var _serf_index = _building.get_first_knight();
        while (_serf_index != 0) {
            var _serf = _popup.interface.get_game().get_serf(_serf_index);
            var _serf_type = _serf.get_type();
            if ((_serf_type < SerfType.knight0) || (_serf_type > SerfType.knight4)) {
                throw ("Not a knight among the castle defenders.");
            }
            _knights[_serf_type - SerfType.knight0] += 1;
            _serf_index = _serf.get_next();
        }

        _popup.draw_green_number(14, 20, _knights[4]);
        _popup.draw_green_number(14, 40, _knights[3]);
        _popup.draw_green_number(14, 60, _knights[2]);
        _popup.draw_green_number(14, 80, _knights[1]);
        _popup.draw_green_number(14, 100, _knights[0]);
    } else if (_type != BuildingType.stock) {
        _popup.interface.close_popup();
        return;
    }

    /* Draw resource mode checkbox */
    var _inventory = _building.get_inventory();
    var _res_mode = _inventory.get_res_mode();
    if (_res_mode == InventoryMode.mode_in) { /* in */
        _popup.draw_popup_icon(9, 16, 0x120);
    } else if (_res_mode == InventoryMode.mode_stop) { /* stop */
        _popup.draw_popup_icon(9, 32, 0x120);
    } else { /* out */
        _popup.draw_popup_icon(9, 48, 0x120);
    }

    /* Draw serf mode checkbox */
    var _serf_mode = _inventory.get_serf_mode();
    if (_serf_mode == InventoryMode.mode_in) { /* in */
        _popup.draw_popup_icon(9, 80, 0x120);
    } else if (_serf_mode == InventoryMode.mode_stop) { /* stop */
        _popup.draw_popup_icon(9, 96, 0x120);
    } else { /* out */
        _popup.draw_popup_icon(9, 112, 0x120);
    }
}

function popup_draw_sett_8_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_sett_8_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_icon_box(_layout);

    var _player = _popup.interface.get_player();

    popup_draw_slide_bar(_popup, 4, 12, _player.get_serf_to_knight_rate());
    _popup.draw_green_string(8, 63, "%");
    _popup.draw_green_number(6, 63, (100 * _player.get_knight_morale()) div 0x1000);

    _popup.draw_green_large_number(6, 73, _player.get_gold_deposited());

    _popup.draw_green_number(6, 119, _player.get_castle_knights_wanted());
    _popup.draw_green_number(6, 129, _player.get_castle_knights());

    if (!_player.send_strongest()) {
        _popup.draw_popup_icon(6, 84, 288); /* checkbox */
    } else {
        _popup.draw_popup_icon(6, 100, 288); /* checkbox */
    }

    var _convertible_to_knights = 0;
    var _invs = _popup.interface.get_game().get_player_inventories(_player);
    for (var _i = 0; _i < array_length(_invs); _i++) {
        var _inv = _invs[_i];
        var _c = min(_inv.get_count_of(ResourceType.sword),
                     _inv.get_count_of(ResourceType.shield));
        _convertible_to_knights += max(0, min(_c, _inv.free_serf_count()));
    }

    _popup.draw_green_number(12, 40, _convertible_to_knights);
}

function popup_draw_sett_6_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_sett_6_layout;

    _popup.draw_box_background(BackgroundPattern.checkerd_diagonal_brown);
    _popup.draw_custom_icon_box(_layout);
    popup_draw_popup_resource_stairs(_popup, _popup.interface.get_player().get_inventory_prio());

    _popup.draw_popup_icon(6, 120, 33 + _popup.current_sett_6_item);
}

function popup_draw_bld_1_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_bld_1_layout;

    _popup.draw_box_background(BackgroundPattern.stares_green);

    _popup.draw_popup_building(4, 112, 0x80 + 4 * _popup.interface.get_player().get_index());
    _popup.draw_custom_bld_box(_layout);

    _popup.draw_popup_icon(0, 128, 0x3d); /* flipbox */
    _popup.draw_popup_icon(14, 128, 0x3c); /* exit */
}

function popup_draw_bld_2_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_bld_2_layout;

    _popup.draw_box_background(BackgroundPattern.stares_green);

    _popup.draw_custom_bld_box(_layout);

    _popup.draw_popup_icon(0, 128, 0x3d); /* flipbox */
    _popup.draw_popup_icon(14, 128, 0x3c); /* exit */
}

function popup_draw_bld_3_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_bld_3_layout;

    _popup.draw_box_background(BackgroundPattern.stares_green);

    _popup.draw_custom_bld_box(_layout);

    _popup.draw_popup_icon(0, 128, 0x3d); /* flipbox */
    _popup.draw_popup_icon(14, 128, 0x3c); /* exit */
}

function popup_draw_bld_4_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_bld_4_layout;

    _popup.draw_box_background(BackgroundPattern.stares_green);

    _popup.draw_custom_bld_box(_layout);

    _popup.draw_popup_icon(0, 128, 0x3d); /* flipbox */
    _popup.draw_popup_icon(14, 128, 0x3c); /* exit */
}

function popup_draw_building_stock_box(_popup) {
    popup_b_init_tables();
    _popup.draw_box_background(BackgroundPattern.plaid_along_green);

    if (_popup.interface.get_player().temp_index == 0) {
        _popup.interface.close_popup();
        return;
    }

    var _building = _popup.interface.get_game().get_building(_popup.interface.get_player().temp_index);
    if (_building.is_burning()) {
        _popup.interface.close_popup();
        return;
    }

    /* Draw list of resources */
    for (var _j = 0; _j < BUILDING_MAX_STOCK; _j++) {
        if (_building.is_stock_active(_j)) {
            var _stock = _building.get_res_count_in_stock(_j);
            if (_stock > 0) {
                var _sprite = 34 + _building.get_res_type_in_stock(_j);
                for (var _i = 0; _i < _stock; _i++) {
                    _popup.draw_popup_icon(8 - _stock + 2 * _i, 110 - _j * 20, _sprite);
                }
            } else {
                _popup.draw_popup_icon(7, 110 - _j * 20, 0xdc); /* minus box */
            }
        }
    }

    var _map_building_serf_sprite = global.popup_b_map_building_serf_sprite;

    /* Draw picture of serf present */
    var _serf_sprite = 0xdc; /* minus box */
    if (_building.has_serf()) {
        _serf_sprite = _map_building_serf_sprite[_building.get_type()];
    }

    _popup.draw_popup_icon(1, 36, _serf_sprite);

    /* Draw building */
    var _bld_sprite = global.popup_b_map_building_sprite[_building.get_type()];
    var _lx = 6;
    if (_bld_sprite == 0xc0 /*stock*/ || _bld_sprite < 0x9e /*tower*/) {
        _lx = 4;
    }
    _popup.draw_popup_building(_lx, 30, _bld_sprite);

    _popup.draw_green_string(1, 4, "Stock of");
    _popup.draw_green_string(1, 14, "this building:");

    _popup.draw_popup_icon(14, 128, 0x3c); /* exit box */
}

function popup_draw_player_faces_box(_popup) {
    _popup.draw_box_background(BackgroundPattern.striped_green);

    _popup.draw_player_face(2, 4, 0);
    _popup.draw_player_face(10, 4, 1);
    _popup.draw_player_face(2, 76, 2);
    _popup.draw_player_face(10, 76, 3);
}

function popup_draw_demolish_box(_popup) {
    _popup.draw_box_background(BackgroundPattern.squares_green);

    _popup.draw_popup_icon(14, 128, 60); /* Exit */
    _popup.draw_popup_icon(7, 45, 288); /* Checkbox */

    _popup.draw_green_string(0, 10, "    Demolish:");
    _popup.draw_green_string(0, 30, "   Click here");
    _popup.draw_green_string(0, 68, "   if you are");
    _popup.draw_green_string(0, 86, "      sure");
}

function popup_draw_save_box(_popup) {
    popup_b_init_tables();
    var _layout = global.popup_b_save_layout;

    _popup.draw_box_background(BackgroundPattern.diagonal_green);
    _popup.draw_custom_icon_box(_layout);

    _popup.draw_green_string(3, 2, "Save  Game");

    /* Rows are drawn by the file_list float; drawing them here too was what
       produced the doubled row under the list. */

    if (_popup.save_status != "") {
        _popup.draw_green_string(1, 116, _popup.save_status);
    }

    _popup.draw_popup_icon(14, 128, 60); /* Exit */
}
