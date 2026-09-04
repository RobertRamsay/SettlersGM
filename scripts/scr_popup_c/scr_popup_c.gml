// scr_popup_c.gml - Ported from Freeserf src/popup.cc lines 2820-4187 (GPL-3.0),
// original copyright (C) 2013-2018 Jon Lund Steffensen <jonlst@gmail.com>.
// PopupBox action handling and click maps:
//   PopupBox::handle_send_geologist .. PopupBox::handle_save_clk.
// All functions are GLOBAL functions taking the PopupBox struct as `_popup`.
// Fields of the PopupBox struct are named as in popup.h:
//   interface, minimap, file_list, file_field, box, current_sett_5_item, current_sett_6_item.
// Other PopupBox methods are reached via `_popup.<name>(...)`.

/* Click map tables. Each table is a flat int array of 5-tuples
 * (action, x, y, w, h) terminated by -1, exactly as in the C++ source. */
function popup_c_init_tables() {
  if (variable_global_exists("popup_c_clk_box_close")) {
    return;
  }

  global.popup_c_clk_box_close = [
    Action.close_box, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_box_options = [
    Action.options_music, 106, 10, 16, 16,
    Action.options_sfx, 106, 30, 16, 16,
    Action.options_volume_minus, 90, 50, 16, 16,
    Action.options_volume_plus, 106, 50, 16, 16,
    Action.options_fullscreen, 106, 70, 16, 16,
    Action.options_message_count_1, 90, 90, 32, 16,
    Action.close_options, 112, 126, 16, 16,
    -1
  ];

  global.popup_c_clk_mine_building = [
    Action.build_stonemine, 16, 8, 33, 65,
    Action.build_coalmine, 64, 8, 33, 65,
    Action.build_ironmine, 32, 77, 33, 65,
    Action.build_goldmine, 80, 77, 33, 65,
    Action.build_flag, 10, 114, 17, 21,
    -1
  ];

  global.popup_c_clk_basic_building = [
    Action.bld_flip_page, 0, 129, 16, 15,
    Action.build_stonecutter, 16, 13, 33, 29,
    Action.build_hut, 80, 13, 33, 27,
    Action.build_lumberjack, 0, 58, 33, 24,
    Action.build_forester, 48, 56, 33, 26,
    Action.build_fisher, 96, 55, 33, 30,
    Action.build_mill, 16, 92, 33, 46,
    Action.build_flag, 58, 108, 17, 21,
    Action.build_boatbuilder, 80, 87, 33, 53,
    -1
  ];

  /* Same table with the flip button (first 5 ints) skipped: C++ `c += 5`. */
  var _full = global.popup_c_clk_basic_building;
  var _n = array_length(_full) - 5;
  global.popup_c_clk_basic_building_noflip = array_create(_n, -1);
  for (var _i = 0; _i < _n; _i++) {
    global.popup_c_clk_basic_building_noflip[_i] = _full[_i + 5];
  }

  global.popup_c_clk_adv_1_building = [
    Action.bld_flip_page, 0, 129, 16, 15,
    Action.build_butcher, 0, 15, 65, 26,
    Action.build_weaponsmith, 64, 15, 65, 26,
    Action.build_steelsmelter, 0, 50, 49, 39,
    Action.build_sawmill, 64, 50, 49, 41,
    Action.build_baker, 16, 100, 49, 33,
    Action.build_goldsmelter, 80, 96, 49, 40,
    -1
  ];

  global.popup_c_clk_adv_2_building = [
    Action.bld_flip_page, 0, 129, 16, 15,
    Action.build_fortress, 64, 87, 64, 56,
    Action.build_tower, 16, 99, 48, 43,
    Action.build_toolmaker, 0, 1, 64, 48,
    Action.build_farm, 64, 1, 64, 42,
    Action.build_pigfarm, 64, 45, 64, 41,
    Action.build_stock, 0, 50, 48, 48,
    -1
  ];

  global.popup_c_clk_stat_select = [
    Action.show_stat_1, 8, 12, 32, 32,
    Action.show_stat_2, 48, 12, 32, 32,
    Action.show_stat_3, 88, 12, 32, 32,
    Action.show_stat_4, 8, 56, 32, 32,
    Action.show_stat_bld, 48, 56, 32, 32,
    Action.show_stat_6, 88, 56, 32, 32,
    Action.show_stat_7, 8, 100, 32, 32,
    Action.show_stat_8, 48, 100, 32, 32,
    Action.close_box, 112, 128, 16, 16,
    Action.show_sett_select, 96, 104, 16, 16,
    -1
  ];

  global.popup_c_clk_stat_1_2_3_4_6 = [
    Action.show_stat_select, 0, 0, 128, 144,
    -1
  ];

  global.popup_c_clk_stat_bld = [
    Action.show_stat_select, 112, 128, 16, 16,
    Action.stat_bld_flip, 0, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_stat_8 = [
    Action.sett_8_set_aspect_all, 16, 112, 16, 16,
    Action.sett_8_set_aspect_land, 32, 112, 16, 16,
    Action.sett_8_set_aspect_buildings, 16, 128, 16, 16,
    Action.sett_8_set_aspect_military, 32, 128, 16, 16,

    Action.sett_8_set_scale_30_min, 64, 112, 16, 16,
    Action.sett_8_set_scale_60_min, 80, 112, 16, 16,
    Action.sett_8_set_scale_600_min, 64, 128, 16, 16,
    Action.sett_8_set_scale_3000_min, 80, 128, 16, 16,

    Action.show_player_faces, 112, 112, 16, 14,
    Action.show_stat_select, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_stat_7 = [
    Action.stat_7_select_lumber, 0, 75, 16, 16,
    Action.stat_7_select_plank, 16, 75, 16, 16,
    Action.stat_7_select_stone, 32, 75, 16, 16,
    Action.stat_7_select_coal, 0, 91, 16, 16,
    Action.stat_7_select_ironore, 16, 91, 16, 16,
    Action.stat_7_select_goldore, 32, 91, 16, 16,
    Action.stat_7_select_boat, 0, 107, 16, 16,
    Action.stat_7_select_steel, 16, 107, 16, 16,
    Action.stat_7_select_goldbar, 32, 107, 16, 16,

    Action.stat_7_select_sword, 56, 83, 16, 16,
    Action.stat_7_select_shield, 56, 99, 16, 16,

    Action.stat_7_select_shovel, 80, 75, 16, 16,
    Action.stat_7_select_hammer, 96, 75, 16, 16,
    Action.stat_7_select_axe, 112, 75, 16, 16,
    Action.stat_7_select_saw, 80, 91, 16, 16,
    Action.stat_7_select_pick, 96, 91, 16, 16,
    Action.stat_7_select_scythe, 112, 91, 16, 16,
    Action.stat_7_select_cleaver, 80, 107, 16, 16,
    Action.stat_7_select_pincer, 96, 107, 16, 16,
    Action.stat_7_select_rod, 112, 107, 16, 16,

    Action.stat_7_select_fish, 8, 125, 16, 16,
    Action.stat_7_select_pig, 24, 125, 16, 16,
    Action.stat_7_select_meat, 40, 125, 16, 16,
    Action.stat_7_select_wheat, 56, 125, 16, 16,
    Action.stat_7_select_flour, 72, 125, 16, 16,
    Action.stat_7_select_bread, 88, 125, 16, 16,

    Action.show_stat_select, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_start_attack = [
    Action.attacking_knights_dec, 32, 112, 16, 16,
    Action.attacking_knights_inc, 80, 112, 16, 16,
    Action.start_attack, 0, 128, 32, 16,
    Action.close_attack_box, 112, 128, 16, 16,
    Action.attacking_select_all_1, 8, 80, 16, 24,
    Action.attacking_select_all_2, 40, 80, 16, 24,
    Action.attacking_select_all_3, 72, 80, 16, 24,
    Action.attacking_select_all_4, 104, 80, 16, 24,
    -1
  ];

  global.popup_c_clk_ground_analysis = [
    Action.close_ground_analysis, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_sett_select = [
    Action.show_quit, 0, 128, 32, 16,
    Action.show_options, 32, 128, 32, 16,
    Action.show_save, 64, 128, 32, 16,

    Action.show_sett_1, 8, 8, 32, 32,
    Action.show_sett_2, 48, 8, 32, 32,
    Action.show_sett_3, 88, 8, 32, 32,
    Action.show_sett_4, 8, 48, 32, 32,
    Action.show_sett_5, 48, 48, 32, 32,
    Action.show_sett_6, 88, 48, 32, 32,
    Action.show_sett_7, 8, 88, 32, 32,
    Action.show_sett_8, 48, 88, 32, 32,

    Action.close_sett_box, 112, 128, 16, 16,
    Action.show_stat_select, 96, 104, 16, 16,
    -1
  ];

  global.popup_c_clk_sett_1 = [
    Action.sett_1_adjust_stonemine, 32, 22, 64, 6,
    Action.sett_1_adjust_coalmine, 0, 42, 64, 6,
    Action.sett_1_adjust_ironmine, 64, 115, 64, 6,
    Action.sett_1_adjust_goldmine, 32, 134, 64, 6,

    Action.show_sett_select, 112, 128, 16, 16,
    Action.default_sett_1, 8, 8, 16, 16,
    -1
  ];

  global.popup_c_clk_sett_2 = [
    Action.sett_2_adjust_construction, 0, 27, 64, 6,
    Action.sett_2_adjust_boatbuilder, 0, 37, 64, 6,
    Action.sett_2_adjust_toolmaker_planks, 64, 45, 64, 6,
    Action.sett_2_adjust_toolmaker_steel, 64, 104, 64, 6,
    Action.sett_2_adjust_weaponsmith, 0, 131, 64, 6,

    Action.show_sett_select, 112, 128, 16, 16,
    Action.default_sett_2, 104, 8, 16, 16,
    -1
  ];

  global.popup_c_clk_sett_3 = [
    Action.sett_3_adjust_steelsmelter, 0, 40, 64, 6,
    Action.sett_3_adjust_goldsmelter, 64, 40, 64, 6,
    Action.sett_3_adjust_weaponsmith, 32, 48, 64, 6,
    Action.sett_3_adjust_pigfarm, 0, 93, 64, 6,
    Action.sett_3_adjust_mill, 64, 119, 64, 6,

    Action.show_sett_select, 112, 128, 16, 16,
    Action.default_sett_3, 8, 60, 16, 16,
    -1
  ];

  global.popup_c_clk_knight_level = [
    Action.knight_level_closest_max_dec, 32, 2, 16, 16,
    Action.knight_level_closest_max_inc, 48, 2, 16, 16,
    Action.knight_level_closest_min_dec, 32, 18, 16, 16,
    Action.knight_level_closest_min_inc, 48, 18, 16, 16,
    Action.knight_level_close_max_dec, 32, 36, 16, 16,
    Action.knight_level_close_max_inc, 48, 36, 16, 16,
    Action.knight_level_close_min_dec, 32, 52, 16, 16,
    Action.knight_level_close_min_inc, 48, 52, 16, 16,
    Action.knight_level_far_max_dec, 32, 70, 16, 16,
    Action.knight_level_far_max_inc, 48, 70, 16, 16,
    Action.knight_level_far_min_dec, 32, 86, 16, 16,
    Action.knight_level_far_min_inc, 48, 86, 16, 16,
    Action.knight_level_farthest_max_dec, 32, 104, 16, 16,
    Action.knight_level_farthest_max_inc, 48, 104, 16, 16,
    Action.knight_level_farthest_min_dec, 32, 120, 16, 16,
    Action.knight_level_farthest_min_inc, 48, 120, 16, 16,

    Action.show_sett_select, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_sett_4 = [
    Action.sett_4_adjust_shovel, 32, 4, 64, 8,
    Action.sett_4_adjust_hammer, 32, 20, 64, 8,
    Action.sett_4_adjust_axe, 32, 36, 64, 8,
    Action.sett_4_adjust_saw, 32, 52, 64, 8,
    Action.sett_4_adjust_scythe, 32, 68, 64, 8,
    Action.sett_4_adjust_pick, 32, 84, 64, 8,
    Action.sett_4_adjust_pincer, 32, 100, 64, 8,
    Action.sett_4_adjust_cleaver, 32, 116, 64, 8,
    Action.sett_4_adjust_rod, 32, 132, 64, 8,

    Action.show_sett_select, 112, 128, 16, 16,
    Action.default_sett_4, 104, 8, 16, 16,
    -1
  ];

  global.popup_c_clk_sett_5_6 = [
    Action.sett_5_6_item_1, 40, 4, 16, 16,
    Action.sett_5_6_item_2, 56, 6, 16, 16,
    Action.sett_5_6_item_3, 72, 8, 16, 16,
    Action.sett_5_6_item_4, 88, 10, 16, 16,
    Action.sett_5_6_item_5, 104, 12, 16, 16,
    Action.sett_5_6_item_6, 104, 28, 16, 16,
    Action.sett_5_6_item_7, 88, 30, 16, 16,
    Action.sett_5_6_item_8, 72, 32, 16, 16,
    Action.sett_5_6_item_9, 56, 34, 16, 16,
    Action.sett_5_6_item_10, 40, 36, 16, 16,
    Action.sett_5_6_item_11, 24, 38, 16, 16,
    Action.sett_5_6_item_12, 8, 40, 16, 16,
    Action.sett_5_6_item_13, 8, 56, 16, 16,
    Action.sett_5_6_item_14, 24, 58, 16, 16,
    Action.sett_5_6_item_15, 40, 60, 16, 16,
    Action.sett_5_6_item_16, 56, 62, 16, 16,
    Action.sett_5_6_item_17, 72, 64, 16, 16,
    Action.sett_5_6_item_18, 88, 66, 16, 16,
    Action.sett_5_6_item_19, 104, 68, 16, 16,
    Action.sett_5_6_item_20, 104, 84, 16, 16,
    Action.sett_5_6_item_21, 88, 86, 16, 16,
    Action.sett_5_6_item_22, 72, 88, 16, 16,
    Action.sett_5_6_item_23, 56, 90, 16, 16,
    Action.sett_5_6_item_24, 40, 92, 16, 16,
    Action.sett_5_6_item_25, 24, 94, 16, 16,
    Action.sett_5_6_item_26, 8, 96, 16, 16,

    Action.sett_5_6_top, 8, 120, 16, 16,
    Action.sett_5_6_up, 24, 120, 16, 16,
    Action.sett_5_6_down, 72, 120, 16, 16,
    Action.sett_5_6_bottom, 88, 120, 16, 16,

    Action.show_sett_select, 112, 128, 16, 16,
    Action.default_sett_5_6, 8, 4, 16, 16,
    -1
  ];

  global.popup_c_clk_quit_confirm = [
    Action.quit_confirm, 8, 45, 32, 8,
    Action.quit_cancel, 88, 45, 32, 8,
    -1
  ];

  global.popup_c_clk_no_save_quit_confirm = [
    Action.no_save_quit_confirm, 8, 125, 32, 8,
    Action.quit_cancel, 88, 125, 32, 8,
    -1
  ];

  global.popup_c_clk_castle_res = [
    Action.close_box, 112, 128, 16, 16,
    Action.show_castle_serf, 96, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_transport_info = [
    Action.unknown_tp_info_flag, 56, 51, 16, 15,
    Action.send_geologist, 16, 96, 16, 16,
    Action.close_box, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_castle_serf = [
    Action.close_box, 112, 128, 16, 16,
    Action.show_resdir, 96, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_resdir = [
    Action.res_mode_in, 72, 16, 16, 16,
    Action.res_mode_stop, 72, 32, 16, 16,
    Action.res_mode_out, 72, 48, 16, 16,
    Action.serf_mode_in, 72, 80, 16, 16,
    Action.serf_mode_stop, 72, 96, 16, 16,
    Action.serf_mode_out, 72, 112, 16, 16,

    Action.show_castle_res, 96, 128, 16, 16,
    Action.close_box, 112, 128, 16, 16,

    -1
  ];

  global.popup_c_clk_sett_8 = [
    Action.sett_8_adjust_rate, 32, 12, 64, 8,

    Action.sett_8_train_1, 16, 28, 16, 16,
    Action.sett_8_train_5, 32, 28, 16, 16,
    Action.sett_8_train_20, 16, 44, 16, 16,
    Action.sett_8_train_100, 32, 44, 16, 16,

    Action.sett_8_set_combat_mode_weak, 48, 84, 16, 16,
    Action.sett_8_set_combat_mode_strong, 48, 100, 16, 16,

    Action.sett_8_cycle, 80, 84, 32, 32,

    Action.sett_8_castle_def_dec, 24, 120, 16, 16,
    Action.sett_8_castle_def_inc, 72, 120, 16, 16,

    Action.show_sett_select, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_message = [
    Action.close_message, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_player_faces = [
    Action.show_stat_8, 0, 0, 128, 144,
    -1
  ];

  global.popup_c_clk_box_demolish = [
    Action.close_box, 112, 128, 16, 16,
    Action.demolish, 56, 45, 16, 16,
    -1
  ];

  global.popup_c_clk_minimap = [
    Action.minimap_click, 0, 0, 128, 128,
    Action.minimap_mode, 0, 128, 32, 16,
    Action.minimap_roads, 32, 128, 32, 16,
    Action.minimap_buildings, 64, 128, 32, 16,
    Action.minimap_grid, 96, 128, 16, 16,
    Action.minimap_scale, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_box_bld_1 = [
    Action.minimap_bld_1, 0, 0, 64, 51,
    Action.minimap_bld_2, 64, 0, 48, 51,
    Action.minimap_bld_3, 16, 64, 32, 32,
    Action.minimap_bld_4, 48, 60, 64, 71,
    Action.minimap_bld_flag, 25, 110, 16, 34,
    Action.minimap_bld_next, 0, 128, 16, 16,
    Action.minimap_bld_exit, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_box_bld_2 = [
    Action.minimap_bld_5, 0, 0, 64, 56,
    Action.minimap_bld_6, 64, 0, 32, 51,
    Action.minimap_bld_7, 0, 64, 64, 32,
    Action.minimap_bld_8, 64, 64, 32, 32,
    Action.minimap_bld_9, 96, 60, 32, 36,
    Action.minimap_bld_10, 32, 104, 32, 36,
    Action.minimap_bld_11, 64, 104, 32, 36,
    Action.minimap_bld_next, 0, 128, 16, 16,
    Action.minimap_bld_exit, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_box_bld_3 = [
    Action.minimap_bld_12, 0, 0, 64, 48,
    Action.minimap_bld_13, 64, 0, 64, 48,
    Action.minimap_bld_14, 0, 56, 32, 34,
    Action.minimap_bld_15, 32, 86, 32, 54,
    Action.minimap_bld_16, 64, 56, 64, 34,
    Action.minimap_bld_17, 64, 100, 48, 40,
    Action.minimap_bld_next, 0, 128, 16, 16,
    Action.minimap_bld_exit, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_box_bld_4 = [
    Action.minimap_bld_18, 0, 0, 32, 64,
    Action.minimap_bld_19, 32, 0, 32, 64,
    Action.minimap_bld_20, 61, 0, 35, 64,
    Action.minimap_bld_21, 96, 0, 32, 64,
    Action.minimap_bld_22, 16, 95, 48, 41,
    Action.minimap_bld_23, 64, 95, 48, 41,
    Action.minimap_bld_next, 0, 128, 16, 16,
    Action.minimap_bld_exit, 112, 128, 16, 16,
    -1
  ];

  global.popup_c_clk_save = [
    Action.save, 0, 128, 32, 64,
    Action.close_box, 112, 128, 16, 16,
    -1
  ];
}

/* PopupBox::handle_send_geologist */
function popup_handle_send_geologist(_popup) {
  var _pos = _popup.interface.get_map_cursor_pos();
  var _flag = _popup.interface.get_game().get_flag_at_pos(_pos);

  if (!_popup.interface.get_game().send_geologist(_flag)) {
    _popup.play_sound(Sfx.not_accepted);
  } else {
    _popup.play_sound(Sfx.accepted);
    _popup.interface.close_popup();
  }
}

/* PopupBox::sett_8_train */
function popup_sett_8_train(_popup, _number) {
  var _r = _popup.interface.get_player().promote_serfs_to_knights(_number);

  if (_r == 0) {
    _popup.play_sound(Sfx.not_accepted);
  } else {
    _popup.play_sound(Sfx.accepted);
  }
}

/* PopupBox::set_inventory_resource_mode */
function popup_set_inventory_resource_mode(_popup, _mode) {
  var _building = _popup.interface.get_game().get_building(
                                     _popup.interface.get_player().temp_index);
  var _inventory = _building.get_inventory();
  _popup.interface.get_game().set_inventory_resource_mode(_inventory, _mode);
}

/* PopupBox::set_inventory_serf_mode */
function popup_set_inventory_serf_mode(_popup, _mode) {
  var _building = _popup.interface.get_game().get_building(
                                     _popup.interface.get_player().temp_index);
  var _inventory = _building.get_inventory();
  _popup.interface.get_game().set_inventory_serf_mode(_inventory, _mode);
}

/* PopupBox::handle_action(action, x, y). `_y` is unused (as in the C++). */
function popup_handle_action(_popup, _action, _x, _y) {
  _popup.set_redraw();

  var _player = _popup.interface.get_player();
  var _interface = _popup.interface;
  var _minimap = _popup.minimap;

  switch (_action) {
  case Action.minimap_click:
    /* Not handled here, event is passed to minimap. */
    break;
  case Action.minimap_mode: {
    var _mode = _minimap.get_ownership_mode() + 1;
    if (_mode > OwnershipMode.last) {
      _mode = OwnershipMode.none;
    }
    _minimap.set_ownership_mode(_mode);
    _popup.set_box(PopupType.map);
    break;
  }
  case Action.minimap_roads:
    _minimap.set_draw_roads(!_minimap.get_draw_roads());
    _popup.set_box(PopupType.map);
    break;
  case Action.minimap_buildings:
    if (_minimap.get_advanced() >= 0) {
      _minimap.set_advanced(-1);
      _minimap.set_draw_buildings(true);
    } else {
      _minimap.set_draw_buildings(!_minimap.get_draw_buildings());
    }
    _popup.set_box(PopupType.map);

    /* TODO on double click */
    break;
  case Action.minimap_grid:
    _minimap.set_draw_grid(!_minimap.get_draw_grid());
    _popup.set_box(PopupType.map);
    break;
  case Action.build_stonemine:
    _interface.build_building(BuildingType.stone_mine);
    break;
  case Action.build_coalmine:
    _interface.build_building(BuildingType.coal_mine);
    break;
  case Action.build_ironmine:
    _interface.build_building(BuildingType.iron_mine);
    break;
  case Action.build_goldmine:
    _interface.build_building(BuildingType.gold_mine);
    break;
  case Action.build_flag:
    _interface.build_flag();
    _interface.close_popup();
    break;
  case Action.build_stonecutter:
    _interface.build_building(BuildingType.stonecutter);
    break;
  case Action.build_hut:
    _interface.build_building(BuildingType.hut);
    break;
  case Action.build_lumberjack:
    _interface.build_building(BuildingType.lumberjack);
    break;
  case Action.build_forester:
    _interface.build_building(BuildingType.forester);
    break;
  case Action.build_fisher:
    _interface.build_building(BuildingType.fisher);
    break;
  case Action.build_mill:
    _interface.build_building(BuildingType.mill);
    break;
  case Action.build_boatbuilder:
    _interface.build_building(BuildingType.boatbuilder);
    break;
  case Action.build_butcher:
    _interface.build_building(BuildingType.butcher);
    break;
  case Action.build_weaponsmith:
    _interface.build_building(BuildingType.weapon_smith);
    break;
  case Action.build_steelsmelter:
    _interface.build_building(BuildingType.steel_smelter);
    break;
  case Action.build_sawmill:
    _interface.build_building(BuildingType.sawmill);
    break;
  case Action.build_baker:
    _interface.build_building(BuildingType.baker);
    break;
  case Action.build_goldsmelter:
    _interface.build_building(BuildingType.gold_smelter);
    break;
  case Action.build_fortress:
    _interface.build_building(BuildingType.fortress);
    break;
  case Action.build_tower:
    _interface.build_building(BuildingType.tower);
    break;
  case Action.build_toolmaker:
    _interface.build_building(BuildingType.tool_maker);
    break;
  case Action.build_farm:
    _interface.build_building(BuildingType.farm);
    break;
  case Action.build_pigfarm:
    _interface.build_building(BuildingType.pig_farm);
    break;
  case Action.bld_flip_page:
    if (_popup.box + 1 <= PopupType.adv_2_bld) {
      _popup.set_box(_popup.box + 1);
    } else {
      _popup.set_box(PopupType.basic_bld_flip);
    }
    break;
  case Action.show_stat_1:
    _popup.set_box(PopupType.stat_1);
    break;
  case Action.show_stat_2:
    _popup.set_box(PopupType.stat_2);
    break;
  case Action.show_stat_8:
    _popup.set_box(PopupType.stat_8);
    break;
  case Action.show_stat_bld:
    _popup.set_box(PopupType.stat_bld_1);
    break;
  case Action.show_stat_6:
    _popup.set_box(PopupType.stat_6);
    break;
  case Action.show_stat_7:
    _popup.set_box(PopupType.stat_7);
    break;
  case Action.show_stat_4:
    _popup.set_box(PopupType.stat_4);
    break;
  case Action.show_stat_3:
    _popup.set_box(PopupType.stat_3);
    break;
  case Action.show_stat_select:
    _popup.set_box(PopupType.stat_select);
    break;
  case Action.stat_bld_flip:
    if (_popup.box + 1 <= PopupType.stat_bld_4) {
      _popup.set_box(_popup.box + 1);
    } else {
      _popup.set_box(PopupType.stat_bld_1);
    }
    break;
  case Action.close_box:
  case Action.close_sett_box:
  case Action.close_ground_analysis:
    _interface.close_popup();
    break;
  case Action.sett_8_set_aspect_all:
    _interface.set_selected_stat_aspect(StatAspect.all_aspects);
    break;
  case Action.sett_8_set_aspect_land:
    _interface.set_selected_stat_aspect(StatAspect.land);
    break;
  case Action.sett_8_set_aspect_buildings:
    _interface.set_selected_stat_aspect(StatAspect.buildings);
    break;
  case Action.sett_8_set_aspect_military:
    _interface.set_selected_stat_aspect(StatAspect.military);
    break;
  case Action.sett_8_set_scale_30_min:
    _interface.set_selected_stat_scale(StatScale.scale_30_min);
    break;
  case Action.sett_8_set_scale_60_min:
    _interface.set_selected_stat_scale(StatScale.scale_60_min);
    break;
  case Action.sett_8_set_scale_600_min:
    _interface.set_selected_stat_scale(StatScale.scale_600_min);
    break;
  case Action.sett_8_set_scale_3000_min:
    _interface.set_selected_stat_scale(StatScale.scale_3000_min);
    break;
  case Action.stat_7_select_fish:
  case Action.stat_7_select_pig:
  case Action.stat_7_select_meat:
  case Action.stat_7_select_wheat:
  case Action.stat_7_select_flour:
  case Action.stat_7_select_bread:
  case Action.stat_7_select_lumber:
  case Action.stat_7_select_plank:
  case Action.stat_7_select_boat:
  case Action.stat_7_select_stone:
  case Action.stat_7_select_ironore:
  case Action.stat_7_select_steel:
  case Action.stat_7_select_coal:
  case Action.stat_7_select_goldore:
  case Action.stat_7_select_goldbar:
  case Action.stat_7_select_shovel:
  case Action.stat_7_select_hammer:
  case Action.stat_7_select_rod:
  case Action.stat_7_select_cleaver:
  case Action.stat_7_select_scythe:
  case Action.stat_7_select_axe:
  case Action.stat_7_select_saw:
  case Action.stat_7_select_pick:
  case Action.stat_7_select_pincer:
  case Action.stat_7_select_sword:
  case Action.stat_7_select_shield: {
    /* Resource::Type(action - ACTION_STAT_7_SELECT_FISH): fish == 0 */
    var _resource = _action - Action.stat_7_select_fish;
    _interface.set_selected_stat_resource(_resource);
    _popup.set_redraw();
    break;
  }
  case Action.attacking_knights_dec:
    _player.knights_attacking = max(_player.knights_attacking - 1, 0);
    break;
  case Action.attacking_knights_inc:
    _player.knights_attacking = min(_player.knights_attacking + 1,
                                    min(_player.total_attacking_knights, 100));
    break;
  case Action.start_attack:
    if (_player.knights_attacking > 0) {
      if (_player.attacking_building_count > 0) {
        _popup.play_sound(Sfx.accepted);
        _player.start_attack();
      }
      _interface.close_popup();
    } else {
      _popup.play_sound(Sfx.not_accepted);
    }
    break;
  case Action.close_attack_box:
    _interface.close_popup();
    break;
    /* TODO */
  case Action.show_sett_1:
    _popup.set_box(PopupType.sett_1);
    break;
  case Action.show_sett_2:
    _popup.set_box(PopupType.sett_2);
    break;
  case Action.show_sett_3:
    _popup.set_box(PopupType.sett_3);
    break;
  case Action.show_sett_7:
    _popup.set_box(PopupType.knight_level);
    break;
  case Action.show_sett_4:
    _popup.set_box(PopupType.sett_4);
    break;
  case Action.show_sett_5:
    _popup.set_box(PopupType.sett_5);
    break;
  case Action.show_sett_select:
    _popup.set_box(PopupType.sett_select);
    break;
  case Action.sett_1_adjust_stonemine:
    _interface.open_popup(PopupType.sett_1);
    _player.set_food_stonemine(gui_get_slider_click_value(_x));
    break;
  case Action.sett_1_adjust_coalmine:
    _interface.open_popup(PopupType.sett_1);
    _player.set_food_coalmine(gui_get_slider_click_value(_x));
    break;
  case Action.sett_1_adjust_ironmine:
    _interface.open_popup(PopupType.sett_1);
    _player.set_food_ironmine(gui_get_slider_click_value(_x));
    break;
  case Action.sett_1_adjust_goldmine:
    _interface.open_popup(PopupType.sett_1);
    _player.set_food_goldmine(gui_get_slider_click_value(_x));
    break;
  case Action.sett_2_adjust_construction:
    _interface.open_popup(PopupType.sett_2);
    _player.set_planks_construction(gui_get_slider_click_value(_x));
    break;
  case Action.sett_2_adjust_boatbuilder:
    _interface.open_popup(PopupType.sett_2);
    _player.set_planks_boatbuilder(gui_get_slider_click_value(_x));
    break;
  case Action.sett_2_adjust_toolmaker_planks:
    _interface.open_popup(PopupType.sett_2);
    _player.set_planks_toolmaker(gui_get_slider_click_value(_x));
    break;
  case Action.sett_2_adjust_toolmaker_steel:
    _interface.open_popup(PopupType.sett_2);
    _player.set_steel_toolmaker(gui_get_slider_click_value(_x));
    break;
  case Action.sett_2_adjust_weaponsmith:
    _interface.open_popup(PopupType.sett_2);
    _player.set_steel_weaponsmith(gui_get_slider_click_value(_x));
    break;
  case Action.sett_3_adjust_steelsmelter:
    _interface.open_popup(PopupType.sett_3);
    _player.set_coal_steelsmelter(gui_get_slider_click_value(_x));
    break;
  case Action.sett_3_adjust_goldsmelter:
    _interface.open_popup(PopupType.sett_3);
    _player.set_coal_goldsmelter(gui_get_slider_click_value(_x));
    break;
  case Action.sett_3_adjust_weaponsmith:
    _interface.open_popup(PopupType.sett_3);
    _player.set_coal_weaponsmith(gui_get_slider_click_value(_x));
    break;
  case Action.sett_3_adjust_pigfarm:
    _interface.open_popup(PopupType.sett_3);
    _player.set_wheat_pigfarm(gui_get_slider_click_value(_x));
    break;
  case Action.sett_3_adjust_mill:
    _interface.open_popup(PopupType.sett_3);
    _player.set_wheat_mill(gui_get_slider_click_value(_x));
    break;
  case Action.knight_level_closest_min_dec:
    _player.change_knight_occupation(3, 0, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_closest_min_inc:
    _player.change_knight_occupation(3, 0, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_closest_max_dec:
    _player.change_knight_occupation(3, 1, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_closest_max_inc:
    _player.change_knight_occupation(3, 1, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_close_min_dec:
    _player.change_knight_occupation(2, 0, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_close_min_inc:
    _player.change_knight_occupation(2, 0, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_close_max_dec:
    _player.change_knight_occupation(2, 1, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_close_max_inc:
    _player.change_knight_occupation(2, 1, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_far_min_dec:
    _player.change_knight_occupation(1, 0, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_far_min_inc:
    _player.change_knight_occupation(1, 0, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_far_max_dec:
    _player.change_knight_occupation(1, 1, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_far_max_inc:
    _player.change_knight_occupation(1, 1, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_farthest_min_dec:
    _player.change_knight_occupation(0, 0, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_farthest_min_inc:
    _player.change_knight_occupation(0, 0, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_farthest_max_dec:
    _player.change_knight_occupation(0, 1, -1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.knight_level_farthest_max_inc:
    _player.change_knight_occupation(0, 1, 1);
    _interface.open_popup(PopupType.knight_level);
    break;
  case Action.sett_4_adjust_shovel:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(0, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_hammer:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(1, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_axe:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(5, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_saw:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(6, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_scythe:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(4, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_pick:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(7, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_pincer:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(8, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_cleaver:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(3, gui_get_slider_click_value(_x));
    break;
  case Action.sett_4_adjust_rod:
    _interface.open_popup(PopupType.sett_4);
    _player.set_tool_prio(2, gui_get_slider_click_value(_x));
    break;
  case Action.sett_5_6_item_1:
  case Action.sett_5_6_item_2:
  case Action.sett_5_6_item_3:
  case Action.sett_5_6_item_4:
  case Action.sett_5_6_item_5:
  case Action.sett_5_6_item_6:
  case Action.sett_5_6_item_7:
  case Action.sett_5_6_item_8:
  case Action.sett_5_6_item_9:
  case Action.sett_5_6_item_10:
  case Action.sett_5_6_item_11:
  case Action.sett_5_6_item_12:
  case Action.sett_5_6_item_13:
  case Action.sett_5_6_item_14:
  case Action.sett_5_6_item_15:
  case Action.sett_5_6_item_16:
  case Action.sett_5_6_item_17:
  case Action.sett_5_6_item_18:
  case Action.sett_5_6_item_19:
  case Action.sett_5_6_item_20:
  case Action.sett_5_6_item_21:
  case Action.sett_5_6_item_22:
  case Action.sett_5_6_item_23:
  case Action.sett_5_6_item_24:
  case Action.sett_5_6_item_25:
  case Action.sett_5_6_item_26:
    _popup.activate_sett_5_6_item(26 - (_action - Action.sett_5_6_item_1));
    break;
  case Action.sett_5_6_top:
    _popup.move_sett_5_6_item(1, 1);
    break;
  case Action.sett_5_6_up:
    _popup.move_sett_5_6_item(1, 0);
    break;
  case Action.sett_5_6_down:
    _popup.move_sett_5_6_item(0, 0);
    break;
  case Action.sett_5_6_bottom:
    _popup.move_sett_5_6_item(0, 1);
    break;
  case Action.quit_confirm:
    /* C++: TODO suggest save game -> TypeNoSaveQuitConfirm (disabled).
       Freeserf quits the process here; go back to the main menu instead, which
       has its own exit. */
    _popup.play_sound(Sfx.ahhh);
    _interface.close_popup();
    _interface.open_game_init();
    break;
  case Action.quit_cancel:
    _interface.close_popup();
    break;
  case Action.no_save_quit_confirm:
    _popup.play_sound(Sfx.ahhh);
    _interface.close_popup();
    _interface.open_game_init();
    break;
  case Action.show_quit:
    _interface.open_popup(PopupType.quit_confirm);
    break;
  case Action.show_options:
    _interface.open_popup(PopupType.options);
    break;
    /* TODO */
  case Action.sett_8_cycle:
    _player.cycle_knights();
    _popup.play_sound(Sfx.accepted);
    break;
  case Action.close_options:
    _interface.close_popup();
    break;
  case Action.options_message_count_1:
    if (_interface.get_config(3)) {
      _interface.switch_config(3);
      _interface.set_config(4);
    } else if (_interface.get_config(4)) {
      _interface.switch_config(4);
      _interface.set_config(5);
    } else if (_interface.get_config(5)) {
      _interface.switch_config(5);
    } else {
      _interface.set_config(3);
      _interface.set_config(4);
      _interface.set_config(5);
    }
    break;
  case Action.default_sett_1:
    _interface.open_popup(PopupType.sett_1);
    _player.reset_food_priority();
    break;
  case Action.default_sett_2:
    _interface.open_popup(PopupType.sett_2);
    _player.reset_planks_priority();
    _player.reset_steel_priority();
    break;
  case Action.default_sett_5_6:
    switch (_popup.box) {
      case PopupType.sett_5:
        _player.reset_flag_priority();
        break;
      case PopupType.sett_6:
        _player.reset_inventory_priority();
        break;
      default:
        throw ("popup_handle_action: NOT_REACHED (default_sett_5_6)");
        break;
    }
    break;
  case Action.build_stock:
    _interface.build_building(BuildingType.stock);
    break;
  case Action.show_castle_serf:
    _popup.set_box(PopupType.castle_serf);
    break;
  case Action.show_resdir:
    _popup.set_box(PopupType.res_dir);
    break;
  case Action.show_castle_res:
    _popup.set_box(PopupType.castle_res);
    break;
  case Action.send_geologist:
    popup_handle_send_geologist(_popup);
    break;
  case Action.res_mode_in:
  case Action.res_mode_stop:
  case Action.res_mode_out:
    popup_set_inventory_resource_mode(_popup, _action - Action.res_mode_in);
    break;
  case Action.serf_mode_in:
  case Action.serf_mode_stop:
  case Action.serf_mode_out:
    popup_set_inventory_serf_mode(_popup, _action - Action.serf_mode_in);
    break;
  case Action.show_sett_8:
    _popup.set_box(PopupType.sett_8);
    break;
  case Action.show_sett_6:
    _popup.set_box(PopupType.sett_6);
    break;
  case Action.sett_8_adjust_rate:
    _player.set_serf_to_knight_rate(gui_get_slider_click_value(_x));
    break;
  case Action.sett_8_train_1:
    popup_sett_8_train(_popup, 1);
    break;
  case Action.sett_8_train_5:
    popup_sett_8_train(_popup, 5);
    break;
  case Action.sett_8_train_20:
    popup_sett_8_train(_popup, 20);
    break;
  case Action.sett_8_train_100:
    popup_sett_8_train(_popup, 100);
    break;
  case Action.default_sett_3:
    _interface.open_popup(PopupType.sett_3);
    _player.reset_coal_priority();
    _player.reset_wheat_priority();
    break;
  case Action.sett_8_set_combat_mode_weak:
    _player.drop_send_strongest();
    _popup.play_sound(Sfx.accepted);
    break;
  case Action.sett_8_set_combat_mode_strong:
    _player.set_send_strongest();
    _popup.play_sound(Sfx.accepted);
    break;
  case Action.attacking_select_all_1:
    _player.knights_attacking = _player.attacking_knights[0];
    break;
  case Action.attacking_select_all_2:
    _player.knights_attacking = _player.attacking_knights[0]
                                + _player.attacking_knights[1];
    break;
  case Action.attacking_select_all_3:
    _player.knights_attacking = _player.attacking_knights[0]
                                + _player.attacking_knights[1]
                                + _player.attacking_knights[2];
    break;
  case Action.attacking_select_all_4:
    _player.knights_attacking = _player.attacking_knights[0]
                                + _player.attacking_knights[1]
                                + _player.attacking_knights[2]
                                + _player.attacking_knights[3];
    break;
  case Action.minimap_bld_1:
  case Action.minimap_bld_2:
  case Action.minimap_bld_3:
  case Action.minimap_bld_4:
  case Action.minimap_bld_5:
  case Action.minimap_bld_6:
  case Action.minimap_bld_7:
  case Action.minimap_bld_8:
  case Action.minimap_bld_9:
  case Action.minimap_bld_10:
  case Action.minimap_bld_11:
  case Action.minimap_bld_12:
  case Action.minimap_bld_13:
  case Action.minimap_bld_14:
  case Action.minimap_bld_15:
  case Action.minimap_bld_16:
  case Action.minimap_bld_17:
  case Action.minimap_bld_18:
  case Action.minimap_bld_19:
  case Action.minimap_bld_20:
  case Action.minimap_bld_21:
  case Action.minimap_bld_22:
  case Action.minimap_bld_23:
    _minimap.set_advanced(_action - Action.minimap_bld_1 + 1);
    _minimap.set_draw_buildings(true);
    _popup.set_box(PopupType.map);
    break;
  case Action.minimap_bld_flag:
    _minimap.set_advanced(0);
    _popup.set_box(PopupType.map);
    break;
  case Action.minimap_bld_next:
    _popup.set_box(_popup.box + 1);
    if (_popup.box > PopupType.bld_4) {
      _popup.set_box(PopupType.bld_1);
    }
    break;
  case Action.minimap_bld_exit:
    _popup.set_box(PopupType.map);
    break;
  case Action.default_sett_4:
    _interface.open_popup(PopupType.sett_4);
    _player.reset_tool_priority();
    break;
  case Action.show_player_faces:
    _popup.set_box(PopupType.player_faces);
    break;
  case Action.minimap_scale: {
    if (_minimap.get_scale() == 1) {
      _minimap.set_scale(2);
    } else {
      _minimap.set_scale(1);
    }
    _popup.set_box(PopupType.map);
  }
    break;
    /* TODO */
  case Action.sett_8_castle_def_dec:
    _player.decrease_castle_knights_wanted();
    break;
  case Action.sett_8_castle_def_inc:
    _player.increase_castle_knights_wanted();
    break;
  case Action.options_music: {
    /* Audio::get_instance().get_music_player()->enable(!is_enabled()) */
    audio_toggle_music();
    _popup.play_sound(Sfx.click);
    break;
  }
  case Action.options_sfx: {
    /* Audio::get_instance().get_sound_player()->enable(!is_enabled()) */
    audio_toggle_sfx();
    _popup.play_sound(Sfx.click);
    break;
  }
  case Action.options_fullscreen:
    window_set_fullscreen(!window_get_fullscreen());
    _popup.play_sound(Sfx.click);
    break;
  case Action.options_volume_minus: {
    /* Audio::get_instance().get_volume_controller()->volume_down() */
    audio_volume_down();
    _popup.play_sound(Sfx.click);
    break;
  }
  case Action.options_volume_plus: {
    /* Audio::get_instance().get_volume_controller()->volume_up() */
    audio_volume_up();
    _popup.play_sound(Sfx.click);
    break;
  }
  case Action.demolish:
    _interface.demolish_object();
    _interface.close_popup();
    break;
  case Action.show_save:
    _popup.file_list.set_displayed(true);
    _popup.file_field.set_displayed(true);
    _popup.set_box(PopupType.load_save);
    break;
  case Action.save: {
    var _slot = _popup.file_list.get_selected_slot();
    if (_slot >= 0) {
      if (savegame_save_slot(_slot, _interface.get_game(),
                             _popup.file_list.get_edit_text())) {
        _popup.file_list.stop_editing();
        _popup.set_redraw();
      }
      break;
    }

    var _file_name = _popup.file_field.get_text();
    /* file_name.find_last_of('.') -> 1-based position or 0 if none */
    var _p = string_last_pos(".", _file_name);
    var _file_ext = "";
    if (_p != 0) {
      _file_ext = string_copy(_file_name, _p + 1, string_length(_file_name) - _p);
      if (_file_ext != "save") {
        _file_ext = "";
      }
    }
    if (_file_ext == "") {
      _file_name += ".save";
    }
    var _file_path = _popup.file_list.get_folder_path() + "/" + _file_name;
    if (game_store_save(_file_path, _interface.get_game())) {
      _interface.close_popup();
    }
    break;
  }
  default:
    show_debug_message("popup: unhandled action " + string(_action));
    break;
  }
}

/* Generic handler for clicks in popup boxes.
 * `_clkmap` is a flat array of (action, x, y, w, h) tuples terminated by -1.
 * Returns 0 when a region was hit, -1 otherwise. */
function popup_handle_clickmap(_popup, _x, _y, _clkmap) {
  var _i = 0;
  while (_clkmap[_i] >= 0) {
    if (_clkmap[_i + 1] <= _x && _x < _clkmap[_i + 1] + _clkmap[_i + 3] &&
        _clkmap[_i + 2] <= _y && _y < _clkmap[_i + 2] + _clkmap[_i + 4]) {
      _popup.play_sound(Sfx.click);

      var _action = _clkmap[_i];
      popup_handle_action(_popup, _action, _x - _clkmap[_i + 1], _y - _clkmap[_i + 2]);
      return 0;
    }
    _i += 5;
  }

  return -1;
}

function popup_handle_box_close_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_box_close);
}

function popup_handle_box_options_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_box_options);
}

function popup_handle_mine_building_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_mine_building);
}

function popup_handle_basic_building_clk(_popup, _cx, _cy, _flip) {
  popup_c_init_tables();
  var _c = global.popup_c_clk_basic_building;
  if (!_flip) {
    _c = global.popup_c_clk_basic_building_noflip; /* Skip flip button */
  }

  popup_handle_clickmap(_popup, _cx, _cy, _c);
}

function popup_handle_adv_1_building_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_adv_1_building);
}

function popup_handle_adv_2_building_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_adv_2_building);
}

function popup_handle_stat_select_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_stat_select);
}

function popup_handle_stat_1_2_3_4_6_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_stat_1_2_3_4_6);
}

function popup_handle_stat_bld_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_stat_bld);
}

function popup_handle_stat_8_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_stat_8);
}

function popup_handle_stat_7_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_stat_7);
}

function popup_handle_start_attack_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_start_attack);
}

function popup_handle_ground_analysis_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_ground_analysis);
}

function popup_handle_sett_select_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_sett_select);
}

function popup_handle_sett_1_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_sett_1);
}

function popup_handle_sett_2_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_sett_2);
}

function popup_handle_sett_3_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_sett_3);
}

function popup_handle_knight_level_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_knight_level);
}

function popup_handle_sett_4_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_sett_4);
}

function popup_handle_sett_5_6_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_sett_5_6);
}

function popup_handle_quit_confirm_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_quit_confirm);
}

function popup_handle_no_save_quit_confirm_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_no_save_quit_confirm);
}

function popup_handle_castle_res_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_castle_res);
}

function popup_handle_transport_info_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_transport_info);
}

function popup_handle_castle_serf_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_castle_serf);
}

function popup_handle_resdir_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_resdir);
}

function popup_handle_sett_8_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_sett_8);
}

function popup_handle_message_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_message);
}

function popup_handle_player_faces_click(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_player_faces);
}

function popup_handle_box_demolish_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_box_demolish);
}

function popup_handle_minimap_clk(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_minimap);
}

function popup_handle_box_bld_1(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_box_bld_1);
}

function popup_handle_box_bld_2(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_box_bld_2);
}

function popup_handle_box_bld_3(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_box_bld_3);
}

function popup_handle_box_bld_4(_popup, _cx, _cy) {
  popup_c_init_tables();
  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_box_bld_4);
}

function popup_handle_save_clk(_popup, _cx, _cy) {
  popup_c_init_tables();

  popup_handle_clickmap(_popup, _cx, _cy, global.popup_c_clk_save);
}
