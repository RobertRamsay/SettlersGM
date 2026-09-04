// scr_popup.gml - Ported from Freeserf src/popup.h and src/popup.cc (GPL-3.0),
// original copyright (C) 2013-2018 Jon Lund Steffensen <jonlst@gmail.com>.
// This file covers popup.cc lines 1-1478 (enums, constructor, draw helpers up to
// draw_stat_3_box), internal_draw / activate_sett_5_6_item / move_sett_5_6_item
// (2607-2819), handle_click_left / show / hide / set_box (4188-end).
// The remaining draw_* boxes (1479-2606) and handle_* / handle_action (2820-4187)
// are ported by other agents as GLOBAL functions popup_<name>(_popup, ...); thin
// static wrappers for them are defined at the end of PopupBox so callers can use
// popup.<name>(...).
//
// PopupBox is a GuiObject (scr_gui.gml). The minimap member is a MinimapGame
// (scr_minimap.gml, other agent). TextInput / ListSavedFiles / RandomInput are
// STUBS defined at the bottom of this file (they draw nothing meaningful).

/* PopupBox::Type */
enum PopupType {
    none = 0,
    map = 1,
    map_overlay, /* UNUSED */
    mine_building,
    basic_bld,
    basic_bld_flip,
    adv_1_bld,
    adv_2_bld,
    stat_select,
    stat_4,
    stat_bld_1,
    stat_bld_2,
    stat_bld_3,
    stat_bld_4,
    stat_8,
    stat_7,
    stat_1,
    stat_2,
    stat_6,
    stat_3,
    start_attack,
    start_attack_redraw,
    ground_analysis,
    load_archive,
    load_save,
    type_25,
    disk_msg,
    sett_select,
    sett_1,
    sett_2,
    sett_3,
    knight_level,
    sett_4,
    sett_5,
    quit_confirm,
    no_save_quit_confirm,
    sett_select_file, /* UNUSED */
    options,
    castle_res,
    mine_output,
    ordered_bld,
    defenders,
    transport_info,
    castle_serf,
    res_dir,
    sett_8,
    sett_6,
    bld_1,
    bld_2,
    bld_3,
    bld_4,
    message,
    bld_stock,
    player_faces,
    game_end_box,   /* C++ TypeGameEnd: `game_end` is a GML built-in function */
    demolish,
    js_calib,
    js_calib_up_left,
    js_calib_down_right,
    js_calib_center,
    ctrls_info
}

/* PopupBox::BackgroundPattern */
enum BackgroundPattern {
    striped_green = 129,             // \\\.
    diagonal_green = 310,            // xxx
    checkerd_diagonal_brown = 311,   // xxx
    plaid_along_green = 312,         // ###
    stares_green = 313,              // * *
    squares_green = 314,
    construction = 131,              // many dots
    overall_comparison = 132,        // sward + building + land
    rural_properties = 133,          // land
    buildings = 134,                 // buildings
    combat_power = 135,              // sward
    fish = 138,
    pig = 139,
    meat = 140,
    eheat = 141,
    flour = 142,
    bread = 143,
    lumber = 144,
    plank = 145,
    boat = 146,
    stone = 147,
    ironore = 148,
    steel = 149,
    coal = 150,
    goldore = 151,
    goldbar = 152,
    shovel = 153,
    hammer = 154,
    rod = 155,
    cleaver = 156,
    scythe = 157,
    axe = 158,
    saw = 159,
    pick = 160,
    pincer = 161,
    sword = 162,
    shield = 163
}

/* Action types that can be fired from
   clicks in the popup window. (popup.cc `enum Action`) */
enum Action {
    minimap_click = 0,
    minimap_mode,
    minimap_roads,
    minimap_buildings,
    minimap_grid,
    build_stonemine,
    build_coalmine,
    build_ironmine,
    build_goldmine,
    build_flag,
    build_stonecutter,
    build_hut,
    build_lumberjack,
    build_forester,
    build_fisher,
    build_mill,
    build_boatbuilder,
    build_butcher,
    build_weaponsmith,
    build_steelsmelter,
    build_sawmill,
    build_baker,
    build_goldsmelter,
    build_fortress,
    build_tower,
    build_toolmaker,
    build_farm,
    build_pigfarm,
    bld_flip_page,
    show_stat_1,
    show_stat_2,
    show_stat_8,
    show_stat_bld,
    show_stat_6,
    show_stat_7,
    show_stat_4,
    show_stat_3,
    show_stat_select,
    stat_bld_flip,
    close_box,
    sett_8_set_aspect_all,
    sett_8_set_aspect_land,
    sett_8_set_aspect_buildings,
    sett_8_set_aspect_military,
    sett_8_set_scale_30_min,
    sett_8_set_scale_60_min,
    sett_8_set_scale_600_min,
    sett_8_set_scale_3000_min,
    stat_7_select_fish,
    stat_7_select_pig,
    stat_7_select_meat,
    stat_7_select_wheat,
    stat_7_select_flour,
    stat_7_select_bread,
    stat_7_select_lumber,
    stat_7_select_plank,
    stat_7_select_boat,
    stat_7_select_stone,
    stat_7_select_ironore,
    stat_7_select_steel,
    stat_7_select_coal,
    stat_7_select_goldore,
    stat_7_select_goldbar,
    stat_7_select_shovel,
    stat_7_select_hammer,
    stat_7_select_rod,
    stat_7_select_cleaver,
    stat_7_select_scythe,
    stat_7_select_axe,
    stat_7_select_saw,
    stat_7_select_pick,
    stat_7_select_pincer,
    stat_7_select_sword,
    stat_7_select_shield,
    attacking_knights_dec,
    attacking_knights_inc,
    start_attack,
    close_attack_box,
    /* ... 78 - 91 ... */
    close_sett_box = 92,
    show_sett_1,
    show_sett_2,
    show_sett_3,
    show_sett_7,
    show_sett_4,
    show_sett_5,
    show_sett_select,
    sett_1_adjust_stonemine,
    sett_1_adjust_coalmine,
    sett_1_adjust_ironmine,
    sett_1_adjust_goldmine,
    sett_2_adjust_construction,
    sett_2_adjust_boatbuilder,
    sett_2_adjust_toolmaker_planks,
    sett_2_adjust_toolmaker_steel,
    sett_2_adjust_weaponsmith,
    sett_3_adjust_steelsmelter,
    sett_3_adjust_goldsmelter,
    sett_3_adjust_weaponsmith,
    sett_3_adjust_pigfarm,
    sett_3_adjust_mill,
    knight_level_closest_min_dec,
    knight_level_closest_min_inc,
    knight_level_closest_max_dec,
    knight_level_closest_max_inc,
    knight_level_close_min_dec,
    knight_level_close_min_inc,
    knight_level_close_max_dec,
    knight_level_close_max_inc,
    knight_level_far_min_dec,
    knight_level_far_min_inc,
    knight_level_far_max_dec,
    knight_level_far_max_inc,
    knight_level_farthest_min_dec,
    knight_level_farthest_min_inc,
    knight_level_farthest_max_dec,
    knight_level_farthest_max_inc,
    sett_4_adjust_shovel,
    sett_4_adjust_hammer,
    sett_4_adjust_axe,
    sett_4_adjust_saw,
    sett_4_adjust_scythe,
    sett_4_adjust_pick,
    sett_4_adjust_pincer,
    sett_4_adjust_cleaver,
    sett_4_adjust_rod,
    sett_5_6_item_1,
    sett_5_6_item_2,
    sett_5_6_item_3,
    sett_5_6_item_4,
    sett_5_6_item_5,
    sett_5_6_item_6,
    sett_5_6_item_7,
    sett_5_6_item_8,
    sett_5_6_item_9,
    sett_5_6_item_10,
    sett_5_6_item_11,
    sett_5_6_item_12,
    sett_5_6_item_13,
    sett_5_6_item_14,
    sett_5_6_item_15,
    sett_5_6_item_16,
    sett_5_6_item_17,
    sett_5_6_item_18,
    sett_5_6_item_19,
    sett_5_6_item_20,
    sett_5_6_item_21,
    sett_5_6_item_22,
    sett_5_6_item_23,
    sett_5_6_item_24,
    sett_5_6_item_25,
    sett_5_6_item_26,
    sett_5_6_top,
    sett_5_6_up,
    sett_5_6_down,
    sett_5_6_bottom,
    quit_confirm,
    quit_cancel,
    no_save_quit_confirm,
    show_quit,
    show_options,
    show_save,
    sett_8_cycle,
    close_options,
    options_pathway_scrolling_1,
    options_pathway_scrolling_2,
    options_fast_map_click_1,
    options_fast_map_click_2,
    options_fast_building_1,
    options_fast_building_2,
    options_message_count_1,
    options_message_count_2,
    show_sett_select_file, /* UNUSED */
    show_stat_select_file, /* UNUSED */
    default_sett_1,
    default_sett_2,
    default_sett_5_6,
    build_stock,
    show_castle_serf,
    show_resdir,
    show_castle_res,
    send_geologist,
    res_mode_in,
    res_mode_stop,
    res_mode_out,
    serf_mode_in,
    serf_mode_stop,
    serf_mode_out,
    show_sett_8,
    show_sett_6,
    sett_8_adjust_rate,
    sett_8_train_1,
    sett_8_train_5,
    sett_8_train_20,
    sett_8_train_100,
    default_sett_3,
    sett_8_set_combat_mode_weak,
    sett_8_set_combat_mode_strong,
    attacking_select_all_1,
    attacking_select_all_2,
    attacking_select_all_3,
    attacking_select_all_4,
    minimap_bld_1,
    minimap_bld_2,
    minimap_bld_3,
    minimap_bld_4,
    minimap_bld_5,
    minimap_bld_6,
    minimap_bld_7,
    minimap_bld_8,
    minimap_bld_9,
    minimap_bld_10,
    minimap_bld_11,
    minimap_bld_12,
    minimap_bld_13,
    minimap_bld_14,
    minimap_bld_15,
    minimap_bld_16,
    minimap_bld_17,
    minimap_bld_18,
    minimap_bld_19,
    minimap_bld_20,
    minimap_bld_21,
    minimap_bld_22,
    minimap_bld_23,
    minimap_bld_flag,
    minimap_bld_next,
    minimap_bld_exit,
    close_message,
    default_sett_4,
    show_player_faces,
    minimap_scale,
    options_right_side,
    close_ground_analysis,
    unknown_tp_info_flag,
    sett_8_castle_def_dec,
    sett_8_castle_def_inc,
    options_music,
    options_fullscreen,
    options_volume_minus,
    options_volume_plus,
    demolish,
    options_sfx,
    save,
    new_name
}

/// Static tables for popup.cc (the local `const int layout[]` arrays of the
/// functions in this file, plus interface.h's map_building_sprite). Created once.
function popup_init_tables() {
    if (variable_global_exists("popup_tables_ready")) {
        return;
    }
    global.popup_tables_ready = true;

    /* Color::green */
    global.popup_color_green = make_colour_rgb(0x73, 0xb3, 0x43);
    /* Color(0xcf, 0x63, 0x63) used by the stat 7 chart */
    global.popup_color_chart_red = make_colour_rgb(0xcf, 0x63, 0x63);

    /* interface.h: map_building_sprite[] indexed by Building::Type */
    global.popup_map_building_sprite = [
        0, 0xa7, 0xa8, 0xae, 0xa9,
        0xa3, 0xa4, 0xa5, 0xa6,
        0xaa, 0xc0, 0xab, 0x9a, 0x9c, 0x9b, 0xbc,
        0xa2, 0xa0, 0xa1, 0x99, 0x9d, 0x9e, 0x98, 0x9f, 0xb2
    ];

    /* draw_mine_building_box */
    global.popup_layout_mine_building = [
        0xa3, 2, 8,
        0xa4, 8, 8,
        0xa5, 4, 77,
        0xa6, 10, 77,
        -1
    ];

    /* draw_basic_building_box */
    global.popup_layout_basic_building = [
        0xab, 10, 13, /* hut */
        0xa9, 2, 13,
        0xa8, 0, 58,
        0xaa, 6, 56,
        0xa7, 12, 55,
        0xbc, 2, 85,
        0xae, 10, 87,
        -1
    ];

    /* draw_adv_1_building_box */
    global.popup_layout_adv_1_building = [
        0x9c, 0, 15,
        0x9d, 8, 15,
        0xa1, 0, 50,
        0xa0, 8, 50,
        0xa2, 2, 100,
        0x9f, 10, 96,
        -1
    ];

    /* draw_adv_2_building_box */
    global.popup_layout_adv_2_building = [
        0x9e, 2, 99, /* tower */
        0x98, 8, 84, /* fortress */
        0x99, 0, 1,
        0xc0, 0, 46,
        0x9a, 8, 1,
        0x9b, 8, 45,
        -1
    ];

    /* draw_resources_box */
    global.popup_layout_resources = [
        0x28, 1, 0, /* resources */
        0x29, 1, 16,
        0x2a, 1, 32,
        0x2b, 1, 48,
        0x2e, 1, 64,
        0x2c, 1, 80,
        0x2d, 1, 96,
        0x2f, 1, 112,
        0x30, 1, 128,
        0x31, 6, 0,
        0x32, 6, 16,
        0x36, 6, 32,
        0x37, 6, 48,
        0x35, 6, 64,
        0x38, 6, 80,
        0x39, 6, 96,
        0x34, 6, 112,
        0x33, 6, 128,
        0x3a, 11, 0,
        0x3b, 11, 16,
        0x22, 11, 32,
        0x23, 11, 48,
        0x24, 11, 64,
        0x25, 11, 80,
        0x26, 11, 96,
        0x27, 11, 112,
        -1
    ];

    global.popup_layout_resources_res = [
         3,   4, ResourceType.lumber,
         3,  20, ResourceType.plank,
         3,  36, ResourceType.boat,
         3,  52, ResourceType.stone,
         3,  68, ResourceType.coal,
         3,  84, ResourceType.iron_ore,
         3, 100, ResourceType.steel,
         3, 116, ResourceType.gold_ore,
         3, 132, ResourceType.gold_bar,
         8,   4, ResourceType.shovel,
         8,  20, ResourceType.hammer,
         8,  36, ResourceType.axe,
         8,  52, ResourceType.saw,
         8,  68, ResourceType.scythe,
         8,  84, ResourceType.pick,
         8, 100, ResourceType.pincer,
         8, 116, ResourceType.cleaver,
         8, 132, ResourceType.rod,
        13,   4, ResourceType.sword,
        13,  20, ResourceType.shield,
        13,  36, ResourceType.fish,
        13,  52, ResourceType.pig,
        13,  68, ResourceType.meat,
        13,  84, ResourceType.wheat,
        13, 100, ResourceType.flour,
        13, 116, ResourceType.bread
    ];

    /* draw_serfs_box (also used verbatim by draw_stat_3_box) */
    global.popup_layout_serfs = [
        0x9, 1, 0, /* serfs */
        0xa, 1, 16,
        0xb, 1, 32,
        0xc, 1, 48,
        0x21, 1, 64,
        0x20, 1, 80,
        0x1f, 1, 96,
        0x1e, 1, 112,
        0x1d, 1, 128,
        0xd, 6, 0,
        0xe, 6, 16,
        0x12, 6, 32,
        0xf, 6, 48,
        0x10, 6, 64,
        0x11, 6, 80,
        0x19, 6, 96,
        0x1a, 6, 112,
        0x1b, 6, 128,
        0x13, 11, 0,
        0x14, 11, 16,
        0x15, 11, 32,
        0x16, 11, 48,
        0x17, 11, 64,
        0x18, 11, 80,
        0x1c, 11, 96,
        0x82, 11, 112,
        -1
    ];

    /* draw_stat_select_box */
    global.popup_layout_stat_select = [
        72, 1, 12,
        73, 6, 12,
        77, 11, 12,
        74, 1, 56,
        76, 6, 56,
        75, 11, 56,
        71, 1, 100,
        70, 6, 100,
        61, 12, 104, /* Flip */
        60, 14, 128, /* Exit */
        -1
    ];

    /* draw_stat_bld_1_box */
    global.popup_bld_layout_stat_bld_1 = [
        192, 0, 5,
        171, 2, 77,
        158, 8, 7,
        152, 6, 69,
        -1
    ];

    /* draw_stat_bld_2_box */
    global.popup_bld_layout_stat_bld_2 = [
        153, 0, 4,
        160, 8, 6,
        157, 0, 68,
        169, 8, 65,
        174, 12, 57,
        170, 4, 105,
        168, 8, 107,
        -1
    ];

    /* draw_stat_bld_3_box */
    global.popup_bld_layout_stat_bld_3 = [
        155, 0, 2,
        154, 8, 3,
        167, 0, 61,
        156, 8, 60,
        188, 4, 75,
        162, 8, 100,
        -1
    ];

    /* draw_stat_bld_4_box */
    global.popup_bld_layout_stat_bld_4 = [
        163, 0, 4,
        164, 4, 4,
        165, 8, 4,
        166, 12, 4,
        161, 2, 90,
        159, 8, 90,
        -1
    ];

    /* draw_stat_8_box */
    global.popup_layout_stat_8 = [
        0x58, 14, 0,
        0x59, 0, 100,
        0x41, 8, 112,
        0x42, 10, 112,
        0x43, 8, 128,
        0x44, 10, 128,
        0x45, 2, 112,
        0x40, 4, 112,
        0x3e, 2, 128,
        0x3f, 4, 128,
        0x133, 14, 112,

        0x3c, 14, 128, /* exit */
        -1
    ];

    /* draw_stat_7_box */
    global.popup_layout_stat_7 = [
        0x81, 6, 80,
        0x81, 8, 80,
        0x81, 6, 96,
        0x81, 8, 96,

        0x59, 0, 64,
        0x5a, 14, 0,

        0x28, 0, 75, /* lumber */
        0x29, 2, 75, /* plank */
        0x2b, 4, 75, /* stone */
        0x2e, 0, 91, /* coal */
        0x2c, 2, 91, /* ironore */
        0x2f, 4, 91, /* goldore */
        0x2a, 0, 107, /* boat */
        0x2d, 2, 107, /* iron */
        0x30, 4, 107, /* goldbar */
        0x3a, 7, 83, /* sword */
        0x3b, 7, 99, /* shield */
        0x31, 10, 75, /* shovel */
        0x32, 12, 75, /* hammer */
        0x36, 14, 75, /* axe */
        0x37, 10, 91, /* saw */
        0x38, 12, 91, /* pick */
        0x35, 14, 91, /* scythe */
        0x34, 10, 107, /* cleaver */
        0x39, 12, 107, /* pincer */
        0x33, 14, 107, /* rod */
        0x22, 1, 125, /* fish */
        0x23, 3, 125, /* pig */
        0x24, 5, 125, /* meat */
        0x25, 7, 125, /* wheat */
        0x26, 9, 125, /* flour */
        0x27, 11, 125, /* bread */

        0x3c, 14, 128, /* exitbox */
        -1
    ];

    global.popup_stat_7_sample_weights = [4, 6, 8, 9, 10, 9, 8, 6, 4];

    global.popup_stat_7_axis_icons_1 = [110, 109, 108, 107];
    global.popup_stat_7_axis_icons_2 = [112, 111, 110, 108];
    global.popup_stat_7_axis_icons_3 = [114, 113, 112, 110];
    global.popup_stat_7_axis_icons_4 = [117, 116, 114, 112];
    global.popup_stat_7_axis_icons_5 = [120, 119, 118, 115];
    global.popup_stat_7_axis_icons_6 = [122, 121, 120, 118];
    global.popup_stat_7_axis_icons_7 = [125, 124, 122, 120];
    global.popup_stat_7_axis_icons_8 = [128, 127, 126, 123];

    /* draw_stat_1_box */
    global.popup_layout_stat_1 = [
        0x18, 0, 0, /* baker */
        0xb4, 0, 16,
        0xb3, 0, 24,
        0xb2, 0, 32,
        0xb3, 0, 40,
        0xb2, 0, 48,
        0xb3, 0, 56,
        0xb2, 0, 64,
        0xb3, 0, 72,
        0xb2, 0, 80,
        0xb3, 0, 88,
        0xd4, 0, 96,
        0xb1, 0, 112,
        0x13, 0, 120, /* fisher */
        0x15, 2, 48, /* butcher */
        0xb4, 2, 64,
        0xb3, 2, 72,
        0xd4, 2, 80,
        0xa4, 2, 96,
        0xa4, 2, 112,
        0xae, 4, 4,
        0xae, 4, 36,
        0xa6, 4, 80,
        0xa6, 4, 96,
        0xa6, 4, 112,
        0x26, 6, 0, /* flour */
        0x23, 6, 32, /* pig */
        0xb5, 6, 64,
        0x24, 6, 76, /* meat */
        0x27, 6, 92, /* bread */
        0x22, 6, 108, /* fish */
        0xb6, 6, 124,
        0x17, 8, 0, /* miller */
        0x14, 8, 32, /* pigfarmer */
        0xa6, 8, 64,
        0xab, 8, 88,
        0xab, 8, 104,
        0xa6, 8, 128,
        0xba, 12, 8,
        0x11, 12, 56, /* miner */
        0x11, 12, 80, /* miner */
        0x11, 12, 104, /* miner */
        0x11, 12, 128, /* miner */
        0x16, 14, 0, /* farmer */
        0x25, 14, 16, /* wheat */
        0x2f, 14, 56, /* goldore */
        0x2e, 14, 80, /* coal */
        0x2c, 14, 104, /* ironore */
        0x2b, 14, 128, /* stone */
        -1
    ];

    /* draw_stat_2_box */
    global.popup_layout_stat_2 = [
        0x11, 0, 0, /* miner */
        0x11, 0, 24, /* miner */
        0x11, 0, 56, /* miner */
        0xd, 0, 80, /* lumberjack */
        0x11, 0, 104, /* miner */
        0xf, 0, 128, /* stonecutter */
        0x2f, 2, 0, /* goldore */
        0x2e, 2, 24, /* coal */
        0xb0, 2, 40,
        0x2c, 2, 56, /* ironore */
        0x28, 2, 80, /* lumber */
        0x2b, 2, 104, /* stone */
        0x2b, 2, 128, /* stone */
        0xaa, 4, 4,
        0xab, 4, 24,
        0xad, 4, 32,
        0xa8, 4, 40,
        0xac, 4, 60,
        0xaa, 4, 84,
        0xbb, 4, 108,
        0xa4, 6, 32,
        0xe, 6, 96, /* sawmiller */
        0xa5, 6, 132,
        0x30, 8, 0, /* gold */
        0x12, 8, 16, /* smelter */
        0xa4, 8, 32,
        0x2d, 8, 40, /* steel */
        0x12, 8, 56, /* smelter */
        0xb8, 8, 80,
        0x29, 8, 96, /* planks */
        0xaf, 8, 112,
        0xa5, 8, 132,
        0xaa, 10, 4,
        0xb9, 10, 24,
        0xab, 10, 40,
        0xb7, 10, 48,
        0xa6, 10, 80,
        0xa9, 10, 96,
        0xa6, 10, 112,
        0xa7, 10, 132,
        0x21, 14, 0, /* knight 4 */
        0x1b, 14, 28, /* weaponsmith */
        0x1a, 14, 64, /* toolmaker */
        0x19, 14, 92, /* boatbuilder */
        0xc, 14, 120, /* builder */
        -1
    ];

    /* draw_stat_3_box (identical to the serfs layout) */
    global.popup_layout_stat_3 = [
        0x9, 1, 0, /* serfs */
        0xa, 1, 16,
        0xb, 1, 32,
        0xc, 1, 48,
        0x21, 1, 64,
        0x20, 1, 80,
        0x1f, 1, 96,
        0x1e, 1, 112,
        0x1d, 1, 128,
        0xd, 6, 0,
        0xe, 6, 16,
        0x12, 6, 32,
        0xf, 6, 48,
        0x10, 6, 64,
        0x11, 6, 80,
        0x19, 6, 96,
        0x1a, 6, 112,
        0x1b, 6, 128,
        0x13, 11, 0,
        0x14, 11, 16,
        0x15, 11, 32,
        0x16, 11, 48,
        0x17, 11, 64,
        0x18, 11, 80,
        0x1c, 11, 96,
        0x82, 11, 112,
        -1
    ];
}

/// Index into the flat gauge-values array of popup_calculate_gauge_values:
/// C++ `unsigned int values[24][Building::kMaxStock][2]` (kMaxStock = 3).
function popup_gauge_idx(_type, _stock, _k) {
    return (_type * 3 + _stock) * 2 + _k;
}

/// static void calculate_gauge_values(Player *player, values[24][kMaxStock][2])
/// Returns the flat array (24*3*2 ints, zeroed) filled in; address with popup_gauge_idx.
function popup_calculate_gauge_values(_player) {
    var _values = array_create(24 * 3 * 2, 0);
    var _buildings = _player.game.get_player_buildings(_player);
    var _n = array_length(_buildings);
    for (var _b = 0; _b < _n; _b++) {
        var _building = _buildings[_b];
        if (_building.is_burning() || !_building.has_serf()) {
            continue;
        }

        var _type = _building.get_type();
        if (!_building.is_done()) {
            _type = 0;
        }

        for (var _i = 0; _i < 3; _i++) {
            if (_building.get_maximum_in_stock(_i) > 0) {
                var _v = 2 * _building.get_res_count_in_stock(_i) +
                         _building.get_requested_in_stock(_i);
                _values[popup_gauge_idx(_type, _i, 0)] += (16 * _v) div (2 * _building.get_maximum_in_stock(_i));
                _values[popup_gauge_idx(_type, _i, 1)] += 1;
            }
        }
    }
    return _values;
}

/// PopupBox : GuiObject
function PopupBox(_interface) : GuiObject() constructor {
    popup_init_tables();

    interface = _interface;
    minimap = new MinimapGame(_interface, _interface.get_game());
    file_list = new ListSavedFiles();
    file_field = new TextInput();
    box = PopupType.none;

    current_sett_5_item = 8;
    current_sett_6_item = 15;

    // Small map view inside the transport-info popup. Built on first use and
    // kept, because every Viewport owns GPU surfaces - making a new one each
    // redraw leaked them.
    flag_view = undefined;

    /* Initialize minimap */
    minimap.set_displayed(false);
    minimap.set_parent(self);
    minimap.set_size(128, 128);
    add_float(minimap, 8, 9);

    file_list.set_size(120, 100);
    file_list.set_displayed(false);
    file_list.set_selection_handler(method(self, function(_item) {
        /* size_t p = item.find_last_of("/\\"); file_name = item.substr(p+1) */
        var _p = 0;
        var _len = string_length(_item);
        for (var _i = 1; _i <= _len; _i++) {
            var _c = string_char_at(_item, _i);
            if (_c == "/" || _c == "\\") {
                _p = _i;
            }
        }
        var _file_name = string_copy(_item, _p + 1, _len - _p);
        file_field.set_text(_file_name);
    }));
    add_float(file_list, 12, 22);

    file_field.set_size(120, 10);
    file_field.set_displayed(false);
    add_float(file_field, 12, 124);

    static get_box = function() {
        return box;
    };

    static get_minimap = function() {
        return minimap;
    };

    /* Draw the frame around the popup box. */
    static draw_popup_box_frame = function() {
        gfx_draw_sprite(0, 0, Asset.frame_popup, 0);
        gfx_draw_sprite(0, 153, Asset.frame_popup, 1);
        gfx_draw_sprite(0, 9, Asset.frame_popup, 2);
        gfx_draw_sprite(136, 9, Asset.frame_popup, 3);
    };

    /* Draw icon in a popup frame. */
    static draw_popup_icon = function(_x, _y, _sprite) {
        gfx_draw_sprite(8 * _x + 8, _y + 9, Asset.icon, _sprite);
    };

    /* Draw building in a popup frame. */
    static draw_popup_building = function(_x, _y, _sprite) {
        var _player = interface.get_player();
        var _color = interface.get_player_color(_player.get_index());
        gfx_draw_sprite_color(8 * _x + 8, _y + 9, Asset.map_object, _sprite, false, _color);
    };

    /* Fill the background of a popup frame. */
    static draw_box_background = function(_sprite) {
        for (var _iy = 0; _iy < 144; _iy += 16) {
            for (var _ix = 0; _ix < 16; _ix += 2) {
                draw_popup_icon(_ix, _iy, _sprite);
            }
        }
    };

    /* Fill one row of a popup frame. */
    static draw_box_row = function(_sprite, _iy) {
        for (var _ix = 0; _ix < 16; _ix += 2) {
            draw_popup_icon(_ix, _iy, _sprite);
        }
    };

    /* Draw a green string in a popup frame. */
    static draw_green_string = function(_sx, _sy, _str) {
        gfx_draw_string(8 * _sx + 8, _sy + 9, _str, global.popup_color_green, -1);
    };

    /* Draw a green number in a popup frame.
       n must be non-negative. If > 999 simply draw ">999" (three characters). */
    static draw_green_number = function(_sx, _sy, _n) {
        if (_n >= 1000) {
            draw_popup_icon(_sx, _sy, 0xd5); /* Draw >999 */
            draw_popup_icon(_sx + 1, _sy, 0xd6);
            draw_popup_icon(_sx + 2, _sy, 0xd7);
        } else {
            gfx_draw_number(8 * _sx + 8, 9 + _sy, _n, global.popup_color_green, -1);
        }
    };

    /* Draw a green number in a popup frame.
       No limits on n. */
    static draw_green_large_number = function(_sx, _sy, _n) {
        gfx_draw_number(8 * _sx + 8, 9 + _sy, _n, global.popup_color_green, -1);
    };

    /* Draw small green number. */
    static draw_additional_number = function(_ix, _iy, _n) {
        if (_n > 0) {
            draw_popup_icon(_ix, _iy, 240 + min(_n, 10));
        }
    };

    /* Get the sprite number for a face. */
    static get_player_face_sprite = function(_face) {
        if (_face != 0) {
            return 0x10b + _face;
        }
        return 0x119; /* sprite_face_none */
    };

    /* Draw player face in popup frame. */
    static draw_player_face = function(_ix, _iy, _player) {
        var _color = -1; /* Color() default: fully transparent */
        var _face = 0;
        var _p = interface.get_game().get_player(_player);
        if (_p != undefined) {
            _color = interface.get_player_color(_player);
            _face = _p.get_face();
        }

        if (_color != -1) {
            gfx_fill_rect(8 * _ix, _iy + 5, 48, 72, _color);
        }
        draw_popup_icon(_ix, _iy, get_player_face_sprite(_face));
    };

    /* Draw a layout of buildings in a popup box.
       _start: index of the first triple (C++ pointer offset `sprites += n`). */
    static draw_custom_bld_box = function(_sprites, _start = 0) {
        var _i = _start;
        while (_sprites[_i] > 0) {
            var _sx = _sprites[_i + 1];
            var _sy = _sprites[_i + 2];
            gfx_draw_sprite_off(8 * _sx + 8, _sy + 9, Asset.map_object, _sprites[_i], false);
            _i += 3;
        }
    };

    /* Draw a layout of icons in a popup box. */
    static draw_custom_icon_box = function(_sprites) {
        var _i = 0;
        while (_sprites[_i] > 0) {
            draw_popup_icon(_sprites[_i + 1], _sprites[_i + 2], _sprites[_i]);
            _i += 3;
        }
    };

    /* Translate resource amount to text. */
    static prepare_res_amount_text = function(_amount) {
        if (_amount == 0) {
            return "Not Present";
        } else if (_amount < 100) {
            return "Minimum";
        } else if (_amount < 180) {
            return "Very Few";
        } else if (_amount < 240) {
            return "Few";
        } else if (_amount < 300) {
            return "Below Average";
        } else if (_amount < 400) {
            return "Average";
        } else if (_amount < 500) {
            return "Above Average";
        } else if (_amount < 600) {
            return "Much";
        } else if (_amount < 800) {
            return "Very Much";
        }
        return "Perfect";
    };

    static draw_map_box = function() {
        /* Icons */
        draw_popup_icon(0, 128, minimap.get_ownership_mode());  // Mode
        if (minimap.get_draw_roads()) {  // Roads
            draw_popup_icon(4, 128, 3);
        } else {
            draw_popup_icon(4, 128, 4);
        }
        if (minimap.get_advanced() >= 0) {  // Unknown mode
            if (minimap.get_advanced() == 0) {
                draw_popup_icon(8, 128, 306);
            } else {
                draw_popup_icon(8, 128, 305);
            }
        } else {  // Buildings
            if (minimap.get_draw_buildings()) {
                draw_popup_icon(8, 128, 5);
            } else {
                draw_popup_icon(8, 128, 6);
            }
        }
        if (minimap.get_draw_grid()) {  // Grid
            draw_popup_icon(12, 128, 7);
        } else {
            draw_popup_icon(12, 128, 8);
        }
        if (minimap.get_scale() == 1) {  // Scale
            draw_popup_icon(14, 128, 91);
        } else {
            draw_popup_icon(14, 128, 92);
        }
    };

    /* Draw building mine popup box. */
    static draw_mine_building_box = function() {
        var _layout = global.popup_layout_mine_building;

        draw_box_background(BackgroundPattern.construction);

        if (interface.get_game().can_build_flag(interface.get_map_cursor_pos(),
                                                interface.get_player())) {
            draw_popup_building(2, 114, 0x80 + 4 * interface.get_player().get_index());
        }

        draw_custom_bld_box(_layout);
    };

    /* Draw .. popup box... */
    static draw_basic_building_box = function(_flip) {
        var _layout = global.popup_layout_basic_building;

        draw_box_background(BackgroundPattern.construction);

        var _l = 0;
        if (!interface.get_game().can_build_military(interface.get_map_cursor_pos())) {
            _l += 3; /* Skip hut */
        }

        draw_custom_bld_box(_layout, _l);

        if (interface.get_game().can_build_flag(interface.get_map_cursor_pos(),
                                                interface.get_player())) {
            draw_popup_building(8, 108, 0x80 + 4 * interface.get_player().get_index());
        }

        if (_flip) {
            draw_popup_icon(0, 128, 0x3d);
        }
    };

    static draw_adv_1_building_box = function() {
        var _layout = global.popup_layout_adv_1_building;

        draw_box_background(BackgroundPattern.construction);
        draw_custom_bld_box(_layout);
        draw_popup_icon(0, 128, 0x3d);
    };

    static draw_adv_2_building_box = function() {
        var _layout = global.popup_layout_adv_2_building;

        var _l = 0;
        if (!interface.get_game().can_build_military(interface.get_map_cursor_pos())) {
            _l += 2 * 3; /* Skip tower and fortress */
        }

        draw_box_background(BackgroundPattern.construction);
        draw_custom_bld_box(_layout, _l);
        draw_popup_icon(0, 128, 0x3d);
    };

    /* Draw generic popup box of resources.
       _resources: array indexed by ResourceType (ResourceMap). */
    static draw_resources_box = function(_resources) {
        var _layout = global.popup_layout_resources;

        draw_custom_icon_box(_layout);

        var _layout_res = global.popup_layout_resources_res;

        var _count = array_length(_layout_res) div 3;
        for (var _i = 0; _i < _count; _i++) {
            var _res_type = _layout_res[_i * 3 + 2];
            var _value = 0;
            if (_res_type >= 0 && _res_type < array_length(_resources)) {
                _value = _resources[_res_type];
            }
            draw_green_number(_layout_res[_i * 3], _layout_res[_i * 3 + 1], _value);
        }
    };

    /* Draw generic popup box of serfs.
       _serfs: array indexed by SerfType. */
    static draw_serfs_box = function(_serfs, _total) {
        var _layout = global.popup_layout_serfs;

        draw_custom_icon_box(_layout);

        /* First column */
        draw_green_number(3, 4, _serfs[SerfType.transporter]);
        draw_green_number(3, 20, _serfs[SerfType.sailor]);
        draw_green_number(3, 36, _serfs[SerfType.digger]);
        draw_green_number(3, 52, _serfs[SerfType.builder]);
        draw_green_number(3, 68, _serfs[SerfType.knight4]);
        draw_green_number(3, 84, _serfs[SerfType.knight3]);
        draw_green_number(3, 100, _serfs[SerfType.knight2]);
        draw_green_number(3, 116, _serfs[SerfType.knight1]);
        draw_green_number(3, 132, _serfs[SerfType.knight0]);

        /* Second column */
        draw_green_number(8, 4, _serfs[SerfType.lumberjack]);
        draw_green_number(8, 20, _serfs[SerfType.sawmiller]);
        draw_green_number(8, 36, _serfs[SerfType.smelter]);
        draw_green_number(8, 52, _serfs[SerfType.stonecutter]);
        draw_green_number(8, 68, _serfs[SerfType.forester]);
        draw_green_number(8, 84, _serfs[SerfType.miner]);
        draw_green_number(8, 100, _serfs[SerfType.boat_builder]);
        draw_green_number(8, 116, _serfs[SerfType.toolmaker]);
        draw_green_number(8, 132, _serfs[SerfType.weapon_smith]);

        /* Third column */
        draw_green_number(13, 4, _serfs[SerfType.fisher]);
        draw_green_number(13, 20, _serfs[SerfType.pig_farmer]);
        draw_green_number(13, 36, _serfs[SerfType.butcher]);
        draw_green_number(13, 52, _serfs[SerfType.farmer]);
        draw_green_number(13, 68, _serfs[SerfType.miller]);
        draw_green_number(13, 84, _serfs[SerfType.baker]);
        draw_green_number(13, 100, _serfs[SerfType.geologist]);
        draw_green_number(13, 116, _serfs[SerfType.generic]);

        if (_total >= 0) {
            draw_green_large_number(11, 132, _total);
        }
    };

    static draw_stat_select_box = function() {
        var _layout = global.popup_layout_stat_select;

        draw_box_background(BackgroundPattern.striped_green);
        draw_custom_icon_box(_layout);
    };

    static draw_stat_4_box = function() {
        draw_box_background(BackgroundPattern.striped_green);

        /* Sum up resources of all inventories. */
        var _resources = interface.get_player().get_stats_resources();

        draw_resources_box(_resources);

        draw_popup_icon(14, 128, 60); /* exit */
    };

    static draw_building_count = function(_x, _y, _type) {
        var _player = interface.get_player();
        draw_green_number(_x, _y, _player.get_completed_building_count(_type));
        draw_additional_number(_x + 1, _y, _player.get_incomplete_building_count(_type));
    };

    static draw_stat_bld_1_box = function() {
        var _bld_layout = global.popup_bld_layout_stat_bld_1;

        draw_box_background(BackgroundPattern.striped_green);

        draw_custom_bld_box(_bld_layout);

        draw_building_count(2, 105, BuildingType.hut);
        draw_building_count(10, 53, BuildingType.tower);
        draw_building_count(9, 130, BuildingType.fortress);
        draw_building_count(4, 61, BuildingType.stock);

        draw_popup_icon(0, 128, 61); /* flip */
        draw_popup_icon(14, 128, 60); /* exit */
    };

    static draw_stat_bld_2_box = function() {
        var _bld_layout = global.popup_bld_layout_stat_bld_2;

        draw_box_background(BackgroundPattern.striped_green);

        draw_custom_bld_box(_bld_layout);

        draw_building_count(3, 54, BuildingType.tool_maker);
        draw_building_count(10, 48, BuildingType.sawmill);
        draw_building_count(3, 95, BuildingType.weapon_smith);
        draw_building_count(8, 95, BuildingType.stonecutter);
        draw_building_count(12, 95, BuildingType.boatbuilder);
        draw_building_count(5, 132, BuildingType.forester);
        draw_building_count(9, 132, BuildingType.lumberjack);

        draw_popup_icon(0, 128, 61); /* flip */
        draw_popup_icon(14, 128, 60); /* exit */
    };

    static draw_stat_bld_3_box = function() {
        var _bld_layout = global.popup_bld_layout_stat_bld_3;

        draw_box_background(BackgroundPattern.striped_green);

        draw_custom_bld_box(_bld_layout);

        draw_building_count(3, 48, BuildingType.pig_farm);
        draw_building_count(11, 48, BuildingType.farm);
        draw_building_count(0, 92, BuildingType.fisher);
        draw_building_count(11, 87, BuildingType.butcher);
        draw_building_count(5, 134, BuildingType.mill);
        draw_building_count(10, 134, BuildingType.baker);

        draw_popup_icon(0, 128, 61); /* flip */
        draw_popup_icon(14, 128, 60); /* exit */
    };

    static draw_stat_bld_4_box = function() {
        var _bld_layout = global.popup_bld_layout_stat_bld_4;

        draw_box_background(BackgroundPattern.striped_green);

        draw_custom_bld_box(_bld_layout);

        draw_building_count(0, 71, BuildingType.stone_mine);
        draw_building_count(4, 71, BuildingType.coal_mine);
        draw_building_count(8, 71, BuildingType.iron_mine);
        draw_building_count(12, 71, BuildingType.gold_mine);
        draw_building_count(4, 130, BuildingType.steel_smelter);
        draw_building_count(9, 130, BuildingType.gold_smelter);

        draw_popup_icon(0, 128, 61); /* flip */
        draw_popup_icon(14, 128, 60); /* exit */
    };

    /* _data: array (player_stat_history[mode]); _color: GM colour. */
    static draw_player_stat_chart = function(_data, _index, _color) {
        var _lx = 8;
        var _ly = 9;
        var _lw = 112;
        var _lh = 100;

        var _prev_value = _data[_index];

        for (var _i = 0; _i < _lw; _i++) {
            var _value = _data[_index];
            if (_index > 0) {
                _index = _index - 1;
            } else {
                _index = _lw - 1;
            }

            if (_value > 0 || _prev_value > 0) {
                if (_value > _prev_value) {
                    var _diff = _value - _prev_value;
                    var _h = _diff div 2;
                    gfx_fill_rect(_lx + _lw - _i, _ly + _lh - _h - _prev_value, 1, _h, _color);
                    _diff -= _h;
                    gfx_fill_rect(_lx + _lw - _i - 1, _ly + _lh - _value, 1, _diff, _color);
                } else if (_value == _prev_value) {
                    gfx_fill_rect(_lx + _lw - _i - 1, _ly + _lh - _value, 2, 1, _color);
                } else {
                    var _diff2 = _prev_value - _value;
                    var _h2 = _diff2 div 2;
                    gfx_fill_rect(_lx + _lw - _i, _ly + _lh - _prev_value, 1, _h2, _color);
                    _diff2 -= _h2;
                    gfx_fill_rect(_lx + _lw - _i - 1, _ly + _lh - _value - _diff2, 1, _diff2, _color);
                }
            }

            _prev_value = _value;
        }
    };

    static draw_stat_8_box = function() {
        var _layout = global.popup_layout_stat_8;

        var _scale = interface.get_selected_stat_scale();
        var _aspect = interface.get_selected_stat_aspect();

        /* Draw background */
        draw_box_row(132 + _aspect, 0);
        draw_box_row(132 + _aspect, 16);
        draw_box_row(132 + _aspect, 32);
        draw_box_row(132 + _aspect, 48);
        draw_box_row(132 + _aspect, 64);
        draw_box_row(132 + _aspect, 80);
        draw_box_row(132 + _aspect, 96);

        draw_box_row(136, 108);
        draw_box_row(129, 116);
        draw_box_row(137, 132);

        draw_custom_icon_box(_layout);

        /* Draw checkmarks to indicate current settings. */
        var _cx = 6;
        if ((_aspect & (1 << 0)) == 0) {
            _cx = 1;
        }
        var _cy = 132;
        if ((_aspect & (1 << 1)) == 0) {
            _cy = 116;
        }
        draw_popup_icon(_cx, _cy, 106); /* checkmark */

        _cx = 12;
        if ((_scale & (1 << 0)) == 0) {
            _cx = 7;
        }
        _cy = 132;
        if ((_scale & (1 << 1)) == 0) {
            _cy = 116;
        }
        draw_popup_icon(_cx, _cy, 106); /* checkmark */

        /* Correct numbers on time scale. */
        draw_popup_icon(2, 103, 94 + 3 * _scale + 0);
        draw_popup_icon(6, 103, 94 + 3 * _scale + 1);
        draw_popup_icon(10, 103, 94 + 3 * _scale + 2);

        /* Draw chart */
        var _game = interface.get_game();
        var _index = _game.get_player_history_index(_scale);
        for (var _i = 0; _i < GAME_MAX_PLAYER_COUNT; _i++) {
            if (_game.get_player(GAME_MAX_PLAYER_COUNT - _i - 1) != undefined) {
                var _player = _game.get_player(GAME_MAX_PLAYER_COUNT - _i - 1);
                var _color = interface.get_player_color(GAME_MAX_PLAYER_COUNT - _i - 1);
                /* NOTE: the original uses logical `||` here (a Freeserf bug that is
                   preserved): int mode = (aspect << 2) || scale; */
                var _mode = 0;
                if (((_aspect << 2) != 0) || (_scale != 0)) {
                    _mode = 1;
                }
                draw_player_stat_chart(_player.get_player_stat_history(_mode), _index, _color);
            }
        }
    };

    static draw_stat_7_box = function() {
        var _layout = global.popup_layout_stat_7;

        draw_box_row(129, 64);
        draw_box_row(129, 112);
        draw_box_row(129, 128);

        draw_custom_icon_box(_layout);

        var _item = interface.get_selected_stat_resource();

        /* Draw background of chart */
        for (var _iy = 0; _iy < 64; _iy += 16) {
            for (var _ix = 0; _ix < 14; _ix += 2) {
                draw_popup_icon(_ix, _iy, 138 + _item);
            }
        }

        var _sample_weights = global.popup_stat_7_sample_weights;

        /* Create array of historical counts */
        var _historical_data = array_create(112, 0);
        var _max_val = 0;
        var _index = interface.get_game().get_resource_history_index();

        var _history = interface.get_player().get_resource_count_history(_item);
        for (var _i = 0; _i < 112; _i++) {
            _historical_data[_i] = 0;
            var _j = _index;
            for (var _k = 0; _k < 9; _k++) {
                _historical_data[_i] += _sample_weights[_k] * _history[_j];
                if (_j > 0) {
                    _j = _j - 1;
                } else {
                    _j = 119;
                }
            }

            if (_historical_data[_i] > _max_val) {
                _max_val = _historical_data[_i];
            }

            if (_index > 0) {
                _index = _index - 1;
            } else {
                _index = 119;
            }
        }

        var _axis_icons = undefined;
        var _multiplier = 0;

        /* TODO chart background pattern */

        if (_max_val <= 64) {
            _axis_icons = global.popup_stat_7_axis_icons_1;
            _multiplier = 0x8000;
        } else if (_max_val <= 128) {
            _axis_icons = global.popup_stat_7_axis_icons_2;
            _multiplier = 0x4000;
        } else if (_max_val <= 256) {
            _axis_icons = global.popup_stat_7_axis_icons_3;
            _multiplier = 0x2000;
        } else if (_max_val <= 512) {
            _axis_icons = global.popup_stat_7_axis_icons_4;
            _multiplier = 0x1000;
        } else if (_max_val <= 1280) {
            _axis_icons = global.popup_stat_7_axis_icons_5;
            _multiplier = 0x666;
        } else if (_max_val <= 2560) {
            _axis_icons = global.popup_stat_7_axis_icons_6;
            _multiplier = 0x333;
        } else if (_max_val <= 5120) {
            _axis_icons = global.popup_stat_7_axis_icons_7;
            _multiplier = 0x199;
        } else {
            _axis_icons = global.popup_stat_7_axis_icons_8;
            _multiplier = 0xa3;
        }

        /* Draw axis icons */
        for (var _i = 0; _i < 4; _i++) {
            draw_popup_icon(14, _i * 16, _axis_icons[_i]);
        }

        /* Draw chart */
        for (var _i = 0; _i < 112; _i++) {
            var _value = min((_historical_data[_i] * _multiplier) >> 16, 64);
            if (_value > 0) {
                gfx_fill_rect(119 - _i, 73 - _value, 1, _value, global.popup_color_chart_red);
            }
        }
    };

    static draw_gauge_balance = function(_lx, _ly, _value, _count) {
        var _sprite = 0xd3;
        if (_count > 0) {
            var _v = (16 * _value) div _count;
            if (_v >= 230) {
                _sprite = 0xd2;
            } else if (_v >= 207) {
                _sprite = 0xd1;
            } else if (_v >= 184) {
                _sprite = 0xd0;
            } else if (_v >= 161) {
                _sprite = 0xcf;
            } else if (_v >= 138) {
                _sprite = 0xce;
            } else if (_v >= 115) {
                _sprite = 0xcd;
            } else if (_v >= 92) {
                _sprite = 0xcc;
            } else if (_v >= 69) {
                _sprite = 0xcb;
            } else if (_v >= 46) {
                _sprite = 0xca;
            } else if (_v >= 23) {
                _sprite = 0xc9;
            } else {
                _sprite = 0xc8;
            }
        }

        draw_popup_icon(_lx, _ly, _sprite);
    };

    static draw_gauge_full = function(_lx, _ly, _value, _count) {
        var _sprite = 0xc7;
        if (_count > 0) {
            var _v = (16 * _value) div _count;
            if (_v >= 230) {
                _sprite = 0xc6;
            } else if (_v >= 207) {
                _sprite = 0xc5;
            } else if (_v >= 184) {
                _sprite = 0xc4;
            } else if (_v >= 161) {
                _sprite = 0xc3;
            } else if (_v >= 138) {
                _sprite = 0xc2;
            } else if (_v >= 115) {
                _sprite = 0xc1;
            } else if (_v >= 92) {
                _sprite = 0xc0;
            } else if (_v >= 69) {
                _sprite = 0xbf;
            } else if (_v >= 46) {
                _sprite = 0xbe;
            } else if (_v >= 23) {
                _sprite = 0xbd;
            } else {
                _sprite = 0xbc;
            }
        }

        draw_popup_icon(_lx, _ly, _sprite);
    };

    static draw_stat_1_box = function() {
        var _layout = global.popup_layout_stat_1;

        draw_box_background(BackgroundPattern.striped_green);

        draw_custom_icon_box(_layout);

        var _values = popup_calculate_gauge_values(interface.get_player());

        draw_gauge_balance(10, 0, _values[popup_gauge_idx(BuildingType.mill, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.mill, 0, 1)]);
        draw_gauge_balance(2, 0, _values[popup_gauge_idx(BuildingType.baker, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.baker, 0, 1)]);
        draw_gauge_full(10, 32, _values[popup_gauge_idx(BuildingType.pig_farm, 0, 0)],
                        _values[popup_gauge_idx(BuildingType.pig_farm, 0, 1)]);
        draw_gauge_balance(2, 32, _values[popup_gauge_idx(BuildingType.butcher, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.butcher, 0, 1)]);
        draw_gauge_full(10, 56, _values[popup_gauge_idx(BuildingType.gold_mine, 0, 0)],
                        _values[popup_gauge_idx(BuildingType.gold_mine, 0, 1)]);
        draw_gauge_full(10, 80, _values[popup_gauge_idx(BuildingType.coal_mine, 0, 0)],
                        _values[popup_gauge_idx(BuildingType.coal_mine, 0, 1)]);
        draw_gauge_full(10, 104, _values[popup_gauge_idx(BuildingType.iron_mine, 0, 0)],
                        _values[popup_gauge_idx(BuildingType.iron_mine, 0, 1)]);
        draw_gauge_full(10, 128, _values[popup_gauge_idx(BuildingType.stone_mine, 0, 0)],
                        _values[popup_gauge_idx(BuildingType.stone_mine, 0, 1)]);
    };

    static draw_stat_2_box = function() {
        var _layout = global.popup_layout_stat_2;

        draw_box_background(BackgroundPattern.striped_green);

        draw_custom_icon_box(_layout);

        var _values = popup_calculate_gauge_values(interface.get_player());

        draw_gauge_balance(6, 0, _values[popup_gauge_idx(BuildingType.gold_smelter, 1, 0)],
                           _values[popup_gauge_idx(BuildingType.gold_smelter, 1, 1)]);
        draw_gauge_balance(6, 16, _values[popup_gauge_idx(BuildingType.gold_smelter, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.gold_smelter, 0, 1)]);
        draw_gauge_balance(6, 40, _values[popup_gauge_idx(BuildingType.steel_smelter, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.steel_smelter, 0, 1)]);
        draw_gauge_balance(6, 56, _values[popup_gauge_idx(BuildingType.steel_smelter, 1, 0)],
                           _values[popup_gauge_idx(BuildingType.steel_smelter, 1, 1)]);

        draw_gauge_balance(6, 80, _values[popup_gauge_idx(BuildingType.sawmill, 1, 0)],
                           _values[popup_gauge_idx(BuildingType.sawmill, 1, 1)]);

        var _gold_value = _values[popup_gauge_idx(BuildingType.hut, 1, 0)] +
                          _values[popup_gauge_idx(BuildingType.tower, 1, 0)] +
                          _values[popup_gauge_idx(BuildingType.fortress, 1, 0)];
        var _gold_count = _values[popup_gauge_idx(BuildingType.hut, 1, 1)] +
                          _values[popup_gauge_idx(BuildingType.tower, 1, 1)] +
                          _values[popup_gauge_idx(BuildingType.fortress, 1, 1)];
        draw_gauge_full(12, 0, _gold_value, _gold_count);

        draw_gauge_balance(12, 20, _values[popup_gauge_idx(BuildingType.weapon_smith, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.weapon_smith, 0, 1)]);
        draw_gauge_balance(12, 36, _values[popup_gauge_idx(BuildingType.weapon_smith, 1, 0)],
                           _values[popup_gauge_idx(BuildingType.weapon_smith, 1, 1)]);

        draw_gauge_balance(12, 56, _values[popup_gauge_idx(BuildingType.tool_maker, 1, 0)],
                           _values[popup_gauge_idx(BuildingType.tool_maker, 1, 1)]);
        draw_gauge_balance(12, 72, _values[popup_gauge_idx(BuildingType.tool_maker, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.tool_maker, 0, 1)]);

        draw_gauge_balance(12, 92, _values[popup_gauge_idx(BuildingType.boatbuilder, 0, 0)],
                           _values[popup_gauge_idx(BuildingType.boatbuilder, 0, 1)]);

        draw_gauge_full(12, 112, _values[popup_gauge_idx(0, 0, 0)], _values[popup_gauge_idx(0, 0, 1)]);
        draw_gauge_full(12, 128, _values[popup_gauge_idx(0, 1, 0)], _values[popup_gauge_idx(0, 1, 1)]);
    };

    static draw_stat_6_box = function() {
        draw_box_background(BackgroundPattern.striped_green);

        var _total = 0;
        for (var _i = 0; _i < 27; _i++) {
            if (_i != SerfType.transporter_inventory) {
                _total += interface.get_player().get_serf_count(_i);
            }
        }

        draw_serfs_box(interface.get_player().get_serfs(), _total);

        draw_popup_icon(14, 128, 60); /* exit */
    };

    static draw_stat_3_meter = function(_lx, _ly, _value) {
        var _sprite = 0xc6;
        if (_value < 1) {
            _sprite = 0xbc;
        } else if (_value < 2) {
            _sprite = 0xbe;
        } else if (_value < 3) {
            _sprite = 0xc0;
        } else if (_value < 4) {
            _sprite = 0xc1;
        } else if (_value < 5) {
            _sprite = 0xc2;
        } else if (_value < 7) {
            _sprite = 0xc3;
        } else if (_value < 10) {
            _sprite = 0xc4;
        } else if (_value < 20) {
            _sprite = 0xc5;
        }
        draw_popup_icon(_lx, _ly, _sprite);
    };

    static draw_stat_3_box = function() {
        draw_box_background(BackgroundPattern.striped_green);

        /* Serf::SerfMap → arrays indexed by SerfType (27 entries). */
        var _serfs_idle = interface.get_player().get_stats_serfs_idle();
        var _serfs_potential = interface.get_player().get_stats_serfs_potential();
        var _serfs = array_create(27, 0);
        for (var _i = 0; _i < 27; _i++) {
            _serfs[_i] = _serfs_idle[_i] + _serfs_potential[_i];
        }

        var _layout = global.popup_layout_stat_3;

        draw_custom_icon_box(_layout);

        /* First column */
        draw_stat_3_meter(3, 0, _serfs[SerfType.transporter]);
        draw_stat_3_meter(3, 16, _serfs[SerfType.sailor]);
        draw_stat_3_meter(3, 32, _serfs[SerfType.digger]);
        draw_stat_3_meter(3, 48, _serfs[SerfType.builder]);
        draw_stat_3_meter(3, 64, _serfs[SerfType.knight4]);
        draw_stat_3_meter(3, 80, _serfs[SerfType.knight3]);
        draw_stat_3_meter(3, 96, _serfs[SerfType.knight2]);
        draw_stat_3_meter(3, 112, _serfs[SerfType.knight1]);
        draw_stat_3_meter(3, 128, _serfs[SerfType.knight0]);

        /* Second column */
        draw_stat_3_meter(8, 0, _serfs[SerfType.lumberjack]);
        draw_stat_3_meter(8, 16, _serfs[SerfType.sawmiller]);
        draw_stat_3_meter(8, 32, _serfs[SerfType.smelter]);
        draw_stat_3_meter(8, 48, _serfs[SerfType.stonecutter]);
        draw_stat_3_meter(8, 64, _serfs[SerfType.forester]);
        draw_stat_3_meter(8, 80, _serfs[SerfType.miner]);
        draw_stat_3_meter(8, 96, _serfs[SerfType.boat_builder]);
        draw_stat_3_meter(8, 112, _serfs[SerfType.toolmaker]);
        draw_stat_3_meter(8, 128, _serfs[SerfType.weapon_smith]);

        /* Third column */
        draw_stat_3_meter(13, 0, _serfs[SerfType.fisher]);
        draw_stat_3_meter(13, 16, _serfs[SerfType.pig_farmer]);
        draw_stat_3_meter(13, 32, _serfs[SerfType.butcher]);
        draw_stat_3_meter(13, 48, _serfs[SerfType.farmer]);
        draw_stat_3_meter(13, 64, _serfs[SerfType.miller]);
        draw_stat_3_meter(13, 80, _serfs[SerfType.baker]);
        draw_stat_3_meter(13, 96, _serfs[SerfType.geologist]);
        draw_stat_3_meter(13, 112, _serfs[SerfType.generic]);

        draw_popup_icon(14, 128, 60); /* exit */
    };

    /* ---- popup.cc 2607-2761: internal_draw ---- */
    static internal_draw = function() {
        draw_popup_box_frame();

        /* Dispatch to one of the popup box functions above. */
        switch (box) {
        case PopupType.map:
            draw_map_box();
            break;
        case PopupType.mine_building:
            draw_mine_building_box();
            break;
        case PopupType.basic_bld:
            draw_basic_building_box(0);
            break;
        case PopupType.basic_bld_flip:
            draw_basic_building_box(1);
            break;
        case PopupType.adv_1_bld:
            draw_adv_1_building_box();
            break;
        case PopupType.adv_2_bld:
            draw_adv_2_building_box();
            break;
        case PopupType.stat_select:
            draw_stat_select_box();
            break;
        case PopupType.stat_4:
            draw_stat_4_box();
            break;
        case PopupType.stat_bld_1:
            draw_stat_bld_1_box();
            break;
        case PopupType.stat_bld_2:
            draw_stat_bld_2_box();
            break;
        case PopupType.stat_bld_3:
            draw_stat_bld_3_box();
            break;
        case PopupType.stat_bld_4:
            draw_stat_bld_4_box();
            break;
        case PopupType.stat_8:
            draw_stat_8_box();
            break;
        case PopupType.stat_7:
            draw_stat_7_box();
            break;
        case PopupType.stat_1:
            draw_stat_1_box();
            break;
        case PopupType.stat_2:
            draw_stat_2_box();
            break;
        case PopupType.stat_6:
            draw_stat_6_box();
            break;
        case PopupType.stat_3:
            draw_stat_3_box();
            break;
        case PopupType.start_attack:
            draw_start_attack_box();
            break;
        case PopupType.start_attack_redraw:
            draw_start_attack_redraw_box();
            break;
        case PopupType.ground_analysis:
            draw_ground_analysis_box();
            break;
            /* TODO */
        case PopupType.sett_select:
            draw_sett_select_box();
            break;
        case PopupType.sett_1:
            draw_sett_1_box();
            break;
        case PopupType.sett_2:
            draw_sett_2_box();
            break;
        case PopupType.sett_3:
            draw_sett_3_box();
            break;
        case PopupType.knight_level:
            draw_knight_level_box();
            break;
        case PopupType.sett_4:
            draw_sett_4_box();
            break;
        case PopupType.sett_5:
            draw_sett_5_box();
            break;
        case PopupType.quit_confirm:
            draw_quit_confirm_box();
            break;
        case PopupType.no_save_quit_confirm:
            draw_no_save_quit_confirm_box();
            break;
        case PopupType.options:
            draw_options_box();
            break;
        case PopupType.castle_res:
            draw_castle_res_box();
            break;
        case PopupType.mine_output:
            draw_mine_output_box();
            break;
        case PopupType.ordered_bld:
            draw_ordered_building_box();
            break;
        case PopupType.defenders:
            draw_defenders_box();
            break;
        case PopupType.transport_info:
            draw_transport_info_box();
            break;
        case PopupType.castle_serf:
            draw_castle_serf_box();
            break;
        case PopupType.res_dir:
            draw_resdir_box();
            break;
        case PopupType.sett_8:
            draw_sett_8_box();
            break;
        case PopupType.sett_6:
            draw_sett_6_box();
            break;
        case PopupType.bld_1:
            draw_bld_1_box();
            break;
        case PopupType.bld_2:
            draw_bld_2_box();
            break;
        case PopupType.bld_3:
            draw_bld_3_box();
            break;
        case PopupType.bld_4:
            draw_bld_4_box();
            break;
        case PopupType.bld_stock:
            draw_building_stock_box();
            break;
        case PopupType.player_faces:
            draw_player_faces_box();
            break;
        case PopupType.demolish:
            draw_demolish_box();
            break;
        case PopupType.load_save:
            draw_save_box();
            break;
        default:
            break;
        }
    };

    static activate_sett_5_6_item = function(_index) {
        if (box == PopupType.sett_5) {
            var _i = 0;
            for (_i = 0; _i < 26; _i++) {
                if (interface.get_player().get_flag_prio(_i) == _index) {
                    break;
                }
            }
            current_sett_5_item = _i + 1;
        } else {
            var _i2 = 0;
            for (_i2 = 0; _i2 < 26; _i2++) {
                if (interface.get_player().get_inventory_prio(_i2) == _index) {
                    break;
                }
            }
            current_sett_6_item = _i2 + 1;
        }
    };

    static move_sett_5_6_item = function(_up, _to_end) {
        /* C++ takes `int *prio = player->get_flag_prio()` (the raw array) and edits
           it in place; GML arrays are references so we take the player's array
           member directly (the C++ getter is overloaded on arity). */
        var _prio = undefined;
        var _cur = -1;

        if (interface.get_popup_box().get_box() == PopupType.sett_5) {
            _prio = interface.get_player().flag_prio;
            _cur = current_sett_5_item - 1;
        } else {
            _prio = interface.get_player().inventory_prio;
            _cur = current_sett_6_item - 1;
        }

        var _cur_value = _prio[_cur];
        var _next_value = -1;
        if (_up) {
            if (_to_end) {
                _next_value = 26;
            } else {
                _next_value = _cur_value + 1;
            }
        } else {
            if (_to_end) {
                _next_value = 1;
            } else {
                _next_value = _cur_value - 1;
            }
        }

        if (_next_value >= 1 && _next_value < 27) {
            var _delta = 1;
            var _min = _next_value;
            var _max = _cur_value - 1;
            if (_next_value > _cur_value) {
                _delta = -1;
                _min = _cur_value + 1;
                _max = _next_value;
            }
            for (var _i = 0; _i < 26; _i++) {
                if (_prio[_i] >= _min && _prio[_i] <= _max) {
                    _prio[_i] += _delta;
                }
            }
            _prio[_cur] = _next_value;
        }
    };

    /* ---- popup.cc 4188-4353: handle_click_left / show / hide / set_box ---- */
    static handle_click_left = function(_cx, _cy) {
        _cx -= 8;
        _cy -= 8;

        switch (box) {
        case PopupType.map:
            handle_minimap_clk(_cx, _cy);
            break;
        case PopupType.mine_building:
            handle_mine_building_clk(_cx, _cy);
            break;
        case PopupType.basic_bld:
            handle_basic_building_clk(_cx, _cy, 0);
            break;
        case PopupType.basic_bld_flip:
            handle_basic_building_clk(_cx, _cy, 1);
            break;
        case PopupType.adv_1_bld:
            handle_adv_1_building_clk(_cx, _cy);
            break;
        case PopupType.adv_2_bld:
            handle_adv_2_building_clk(_cx, _cy);
            break;
        case PopupType.stat_select:
            handle_stat_select_click(_cx, _cy);
            break;
        case PopupType.stat_1:
        case PopupType.stat_2:
        case PopupType.stat_3:
        case PopupType.stat_4:
        case PopupType.stat_6:
            handle_stat_1_2_3_4_6_click(_cx, _cy);
            break;
        case PopupType.stat_bld_1:
        case PopupType.stat_bld_2:
        case PopupType.stat_bld_3:
        case PopupType.stat_bld_4:
            handle_stat_bld_click(_cx, _cy);
            break;
        case PopupType.stat_8:
            handle_stat_8_click(_cx, _cy);
            break;
        case PopupType.stat_7:
            handle_stat_7_click(_cx, _cy);
            break;
        case PopupType.start_attack:
        case PopupType.start_attack_redraw:
            handle_start_attack_click(_cx, _cy);
            break;
            /* TODO */
        case PopupType.ground_analysis:
            handle_ground_analysis_clk(_cx, _cy);
            break;
            /* TODO ... */
        case PopupType.sett_select:
            handle_sett_select_clk(_cx, _cy);
            break;
        case PopupType.sett_1:
            handle_sett_1_click(_cx, _cy);
            break;
        case PopupType.sett_2:
            handle_sett_2_click(_cx, _cy);
            break;
        case PopupType.sett_3:
            handle_sett_3_click(_cx, _cy);
            break;
        case PopupType.knight_level:
            handle_knight_level_click(_cx, _cy);
            break;
        case PopupType.sett_4:
            handle_sett_4_click(_cx, _cy);
            break;
        case PopupType.sett_5:
            handle_sett_5_6_click(_cx, _cy);
            break;
        case PopupType.quit_confirm:
            handle_quit_confirm_click(_cx, _cy);
            break;
        case PopupType.no_save_quit_confirm:
            handle_no_save_quit_confirm_click(_cx, _cy);
            break;
        case PopupType.options:
            handle_box_options_clk(_cx, _cy);
            break;
        case PopupType.castle_res:
            handle_castle_res_clk(_cx, _cy);
            break;
        case PopupType.mine_output:
            handle_box_close_clk(_cx, _cy);
            break;
        case PopupType.ordered_bld:
            handle_box_close_clk(_cx, _cy);
            break;
        case PopupType.defenders:
            handle_box_close_clk(_cx, _cy);
            break;
        case PopupType.transport_info:
            handle_transport_info_clk(_cx, _cy);
            break;
        case PopupType.castle_serf:
            handle_castle_serf_clk(_cx, _cy);
            break;
        case PopupType.res_dir:
            handle_resdir_clk(_cx, _cy);
            break;
        case PopupType.sett_8:
            handle_sett_8_click(_cx, _cy);
            break;
        case PopupType.sett_6:
            handle_sett_5_6_click(_cx, _cy);
            break;
        case PopupType.bld_1:
            handle_box_bld_1(_cx, _cy);
            break;
        case PopupType.bld_2:
            handle_box_bld_2(_cx, _cy);
            break;
        case PopupType.bld_3:
            handle_box_bld_3(_cx, _cy);
            break;
        case PopupType.bld_4:
            handle_box_bld_4(_cx, _cy);
            break;
        case PopupType.message:
            handle_message_clk(_cx, _cy);
            break;
        case PopupType.bld_stock:
            handle_box_close_clk(_cx, _cy);
            break;
        case PopupType.player_faces:
            handle_player_faces_click(_cx, _cy);
            break;
        case PopupType.demolish:
            handle_box_demolish_clk(_cx, _cy);
            break;
        case PopupType.load_save:
            handle_save_clk(_cx, _cy);
            break;
        default:
            show_debug_message("popup: unhandled box: " + string(box));
            break;
        }

        return true;
    };

    static show = function(_box) {
        set_box(_box);
        set_displayed(true);
    };

    static hide = function() {
        set_box(0);
        set_displayed(false);
    };

    static set_box = function(_box) {
        box = _box;
        if (box == PopupType.map) {
            minimap.set_displayed(true);
        } else {
            minimap.set_displayed(false);
        }
        set_redraw();
    };

    /* ---- Thin wrappers for methods ported as global functions by other agents.
       popup.cc 1479-2606 (draw boxes) → popup_<name>(_popup, ...) ---- */
    static draw_start_attack_redraw_box = function() { popup_draw_start_attack_redraw_box(self); };
    static draw_start_attack_box = function() { popup_draw_start_attack_box(self); };
    static draw_ground_analysis_box = function() { popup_draw_ground_analysis_box(self); };
    static draw_sett_select_box = function() { popup_draw_sett_select_box(self); };
    static draw_slide_bar = function(_lx, _ly, _value) { popup_draw_slide_bar(self, _lx, _ly, _value); };
    static draw_sett_1_box = function() { popup_draw_sett_1_box(self); };
    static draw_sett_2_box = function() { popup_draw_sett_2_box(self); };
    static draw_sett_3_box = function() { popup_draw_sett_3_box(self); };
    static draw_knight_level_box = function() { popup_draw_knight_level_box(self); };
    static draw_sett_4_box = function() { popup_draw_sett_4_box(self); };
    static draw_popup_resource_stairs = function(_order) { popup_draw_popup_resource_stairs(self, _order); };
    static draw_sett_5_box = function() { popup_draw_sett_5_box(self); };
    static draw_quit_confirm_box = function() { popup_draw_quit_confirm_box(self); };
    static draw_no_save_quit_confirm_box = function() { popup_draw_no_save_quit_confirm_box(self); };
    static draw_options_box = function() { popup_draw_options_box(self); };
    static draw_castle_res_box = function() { popup_draw_castle_res_box(self); };
    static draw_mine_output_box = function() { popup_draw_mine_output_box(self); };
    static draw_ordered_building_box = function() { popup_draw_ordered_building_box(self); };
    static draw_defenders_box = function() { popup_draw_defenders_box(self); };
    static draw_transport_info_box = function() { popup_draw_transport_info_box(self); };
    static draw_castle_serf_box = function() { popup_draw_castle_serf_box(self); };
    static draw_resdir_box = function() { popup_draw_resdir_box(self); };
    static draw_sett_8_box = function() { popup_draw_sett_8_box(self); };
    static draw_sett_6_box = function() { popup_draw_sett_6_box(self); };
    static draw_bld_1_box = function() { popup_draw_bld_1_box(self); };
    static draw_bld_2_box = function() { popup_draw_bld_2_box(self); };
    static draw_bld_3_box = function() { popup_draw_bld_3_box(self); };
    static draw_bld_4_box = function() { popup_draw_bld_4_box(self); };
    static draw_building_stock_box = function() { popup_draw_building_stock_box(self); };
    static draw_player_faces_box = function() { popup_draw_player_faces_box(self); };
    static draw_demolish_box = function() { popup_draw_demolish_box(self); };
    static draw_save_box = function() { popup_draw_save_box(self); };

    /* popup.cc 2820-4187 (handlers) → popup_<name>(_popup, ...) */
    static handle_send_geologist = function() { popup_handle_send_geologist(self); };
    static sett_8_train = function(_number) { popup_sett_8_train(self, _number); };
    static set_inventory_resource_mode = function(_mode) { popup_set_inventory_resource_mode(self, _mode); };
    static set_inventory_serf_mode = function(_mode) { popup_set_inventory_serf_mode(self, _mode); };
    static handle_action = function(_action, _x, _y) { popup_handle_action(self, _action, _x, _y); };
    static handle_clickmap = function(_x, _y, _clkmap) { return popup_handle_clickmap(self, _x, _y, _clkmap); };
    static handle_box_close_clk = function(_cx, _cy) { popup_handle_box_close_clk(self, _cx, _cy); };
    static handle_box_options_clk = function(_cx, _cy) { popup_handle_box_options_clk(self, _cx, _cy); };
    static handle_mine_building_clk = function(_cx, _cy) { popup_handle_mine_building_clk(self, _cx, _cy); };
    static handle_basic_building_clk = function(_cx, _cy, _flip) { popup_handle_basic_building_clk(self, _cx, _cy, _flip); };
    static handle_adv_1_building_clk = function(_cx, _cy) { popup_handle_adv_1_building_clk(self, _cx, _cy); };
    static handle_adv_2_building_clk = function(_cx, _cy) { popup_handle_adv_2_building_clk(self, _cx, _cy); };
    static handle_stat_select_click = function(_cx, _cy) { popup_handle_stat_select_click(self, _cx, _cy); };
    static handle_stat_1_2_3_4_6_click = function(_cx, _cy) { popup_handle_stat_1_2_3_4_6_click(self, _cx, _cy); };
    static handle_stat_bld_click = function(_cx, _cy) { popup_handle_stat_bld_click(self, _cx, _cy); };
    static handle_stat_8_click = function(_cx, _cy) { popup_handle_stat_8_click(self, _cx, _cy); };
    static handle_stat_7_click = function(_cx, _cy) { popup_handle_stat_7_click(self, _cx, _cy); };
    static handle_start_attack_click = function(_cx, _cy) { popup_handle_start_attack_click(self, _cx, _cy); };
    static handle_ground_analysis_clk = function(_cx, _cy) { popup_handle_ground_analysis_clk(self, _cx, _cy); };
    static handle_sett_select_clk = function(_cx, _cy) { popup_handle_sett_select_clk(self, _cx, _cy); };
    static handle_sett_1_click = function(_cx, _cy) { popup_handle_sett_1_click(self, _cx, _cy); };
    static handle_sett_2_click = function(_cx, _cy) { popup_handle_sett_2_click(self, _cx, _cy); };
    static handle_sett_3_click = function(_cx, _cy) { popup_handle_sett_3_click(self, _cx, _cy); };
    static handle_knight_level_click = function(_cx, _cy) { popup_handle_knight_level_click(self, _cx, _cy); };
    static handle_sett_4_click = function(_cx, _cy) { popup_handle_sett_4_click(self, _cx, _cy); };
    static handle_sett_5_6_click = function(_cx, _cy) { popup_handle_sett_5_6_click(self, _cx, _cy); };
    static handle_quit_confirm_click = function(_cx, _cy) { popup_handle_quit_confirm_click(self, _cx, _cy); };
    static handle_no_save_quit_confirm_click = function(_cx, _cy) { popup_handle_no_save_quit_confirm_click(self, _cx, _cy); };
    static handle_castle_res_clk = function(_cx, _cy) { popup_handle_castle_res_clk(self, _cx, _cy); };
    static handle_transport_info_clk = function(_cx, _cy) { popup_handle_transport_info_clk(self, _cx, _cy); };
    static handle_castle_serf_clk = function(_cx, _cy) { popup_handle_castle_serf_clk(self, _cx, _cy); };
    static handle_resdir_clk = function(_cx, _cy) { popup_handle_resdir_clk(self, _cx, _cy); };
    static handle_sett_8_click = function(_cx, _cy) { popup_handle_sett_8_click(self, _cx, _cy); };
    static handle_message_clk = function(_cx, _cy) { popup_handle_message_clk(self, _cx, _cy); };
    static handle_player_faces_click = function(_cx, _cy) { popup_handle_player_faces_click(self, _cx, _cy); };
    static handle_box_demolish_clk = function(_cx, _cy) { popup_handle_box_demolish_clk(self, _cx, _cy); };
    static handle_minimap_clk = function(_cx, _cy) { popup_handle_minimap_clk(self, _cx, _cy); };
    static handle_box_bld_1 = function(_cx, _cy) { popup_handle_box_bld_1(self, _cx, _cy); };
    static handle_box_bld_2 = function(_cx, _cy) { popup_handle_box_bld_2(self, _cx, _cy); };
    static handle_box_bld_3 = function(_cx, _cy) { popup_handle_box_bld_3(self, _cx, _cy); };
    static handle_box_bld_4 = function(_cx, _cy) { popup_handle_box_bld_4(self, _cx, _cy); };
    static handle_save_clk = function(_cx, _cy) { popup_handle_save_clk(self, _cx, _cy); };
}

/* ---------------------------------------------------------------------------
   STUB GUI widgets. Freeserf's TextInput (text-input.h), ListSavedFiles (list.h)
   and RandomInput (game-init.h) are not ported yet; these minimal GuiObject
   subclasses only carry the state and methods that popup.cc calls
   (set_text/get_text, set_selection_handler/get_folder_path). They draw nothing.
   --------------------------------------------------------------------------- */

/// STUB of TextInput : GuiObject
function TextInput() : GuiObject() constructor {
    text = "";
    max_length = 0;
    filter = undefined;

    static set_text = function(_text) {
        text = _text;
        set_redraw();
    };

    static get_text = function() {
        return text;
    };

    static set_max_length = function(_max_length) {
        max_length = _max_length;
    };

    static set_filter = function(_filter) {
        filter = _filter;
    };

    static internal_draw = function() {
        /* stub: no drawing */
    };
}

/// STUB of ListSavedFiles : GuiObject
function ListSavedFiles() : GuiObject() constructor {
    items = [];
    first_item = 0;
    selected_item = -1;
    selection_handler = undefined;
    folder_path = "";
    row_height = 10;
    color_background = make_colour_rgb(0x00, 0x00, 0x00);
    color_text = make_colour_rgb(0xff, 0xff, 0xff);
    color_selected = make_colour_rgb(0x00, 0x8b, 0x47);

    /// One entry per save slot, occupied or not, so saving over a slot is just
    /// as easy as loading one. Slot N is settlers_save_N.json.
    static update = function() {
        items = [];
        for (var _i = 0; _i < SAVEGAME_SLOTS; _i++) {
            array_push(items, savegame_slot_path(_i));
        }
        if (selected_item >= array_length(items)) {
            selected_item = -1;
        }
        set_redraw();
    };

    static set_selection_handler = function(_handler) {
        selection_handler = _handler;
    };

    static get_selected = function() {
        if (selected_item >= 0 && selected_item < array_length(items)) {
            return items[selected_item];
        }
        return "";
    };

    static get_selected_slot = function() {
        return selected_item;
    };

    static get_folder_path = function() {
        return folder_path;
    };

    static internal_draw = function() {
        if (array_length(items) == 0) {
            update();
        }

        gfx_fill_rect(0, 0, width, height, color_background);

        var _rows = height div row_height;
        var _n = array_length(items);

        for (var _i = 0; _i < _rows; _i++) {
            var _index = first_item + _i;
            if (_index >= _n) {
                break;
            }

            var _y = _i * row_height;
            if (_index == selected_item) {
                gfx_fill_rect(0, _y, width, row_height, color_selected);
            }

            var _label = string(_index + 1) + ". " + savegame_slot_label(_index);
            gfx_draw_string(1, _y + 1, _label, color_text, -1);
        }
    };

    static handle_click_left = function(_cx, _cy) {
        if (array_length(items) == 0) {
            update();
        }

        var _index = first_item + (_cy div row_height);
        if (_index < 0 || _index >= array_length(items)) {
            return false;
        }

        selected_item = _index;
        set_redraw();

        if (selection_handler != undefined) {
            selection_handler(items[_index]);
        }

        return true;
    };
}

