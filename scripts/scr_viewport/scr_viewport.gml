// scr_viewport.gml - Ported from Freeserf src/viewport.cc (GPL-3.0),
// original copyright (C) 2013-2019 Jon Lund Steffensen <jonlst@gmail.com>.
// Landscape rendering, map object rendering, water waves, map cursor and
// screen <-> map coordinate conversion. Landscape tiles are cached on surfaces
// exactly like Freeserf caches them on frames.
// Viewport is a GuiObject (scr_gui.gml): construct with `new Viewport(interface, map)`,
// size it with set_size(w, h), and draw it via GuiObject.draw() (which sets the
// gfx origin and calls internal_draw()). draw_at(ox, oy) is kept for callers
// that draw the viewport standalone at a screen position.

#macro MAP_TILE_WIDTH 32
#macro MAP_TILE_HEIGHT 20
#macro MAP_TILE_TEXTURES 33
#macro MAP_TILE_MASKS 81
#macro MAX_ZOOM 4

#macro MAP_TILE_COLS 16
#macro MAP_TILE_ROWS 16

enum ViewportLayer {
    landscape = 1 << 0,
    paths = 1 << 1,
    objects = 1 << 2,
    serfs = 1 << 3,
    cursor = 1 << 4,
    grid = 1 << 5,
    builds = 1 << 6,
    // viewport.h: LayerAll = landscape|paths|objects|serfs|cursor.
    // LayerBuilds is deliberately NOT included - it is switched on only while
    // the player is in build mode (PanelBar's build button calls switch_layer),
    // otherwise the build-possibility icons cover the whole map.
    all_layers = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
}

// File-level static tables of viewport.cc (and map_building_sprite from
// interface.h), built once and stored in global.viewport_*.
function viewport_init_tables() {
    if (variable_global_exists("viewport_map_building_sprite")) {
        return;
    }

    // interface.h: map_building_sprite[]
    global.viewport_map_building_sprite = [
        0, 0xa7, 0xa8, 0xae, 0xa9,
        0xa3, 0xa4, 0xa5, 0xa6,
        0xaa, 0xc0, 0xab, 0x9a, 0x9c, 0x9b, 0xbc,
        0xa2, 0xa0, 0xa1, 0x99, 0x9d, 0x9e, 0x98, 0x9f, 0xb2
    ];

    // viewport.cc: map_building_frame_sprite[]
    global.viewport_map_building_frame_sprite = [
        0, 0xba, 0xba, 0xba, 0xba,
        0xb9, 0xb9, 0xb9, 0xb9,
        0xba, 0xc1, 0xba, 0xb1, 0xb8, 0xb1, 0xbb,
        0xb7, 0xb5, 0xb6, 0xb0, 0xb8, 0xb3, 0xaf, 0xb4
    ];

    // Viewport::draw_unharmed_building: pigfarm_anim[]
    global.viewport_pigfarm_anim = [
        0xa2, 0, 0xa2, 0, 0xa2, 0, 0xa2, 0, 0xa2, 0, 0xa3, 0,
        0xa2, 1, 0xa3, 1, 0xa2, 2, 0xa3, 2, 0xa2, 3, 0xa3, 3,
        0xa2, 4, 0xa3, 4, 0xa6, 4, 0xa6, 4, 0xa6, 4, 0xa6, 4,
        0xa4, 4, 0xa5, 4, 0xa4, 3, 0xa5, 3, 0xa4, 2, 0xa5, 2,
        0xa4, 1, 0xa5, 1, 0xa4, 0, 0xa5, 0, 0xa2, 0, 0xa2, 0,
        0xa6, 0, 0xa6, 0, 0xa6, 0, 0xa2, 0, 0xa7, 0, 0xa8, 0,
        0xa7, 0, 0xa8, 0, 0xa7, 0, 0xa8, 0, 0xa7, 0, 0xa8, 0,
        0xa7, 0, 0xa8, 0, 0xa7, 0, 0xa8, 0, 0xa7, 0, 0xa8, 0,
        0xa7, 0, 0xa8, 0, 0xa7, 0, 0xa2, 0, 0xa2, 0, 0xa2, 0,
        0xa2, 0, 0xa6, 0, 0xa6, 0, 0xa6, 0, 0xa6, 0, 0xa6, 0,
        0xa6, 0, 0xa2, 0, 0xa2, 0, 0xa7, 0, 0xa8, 0, 0xa9, 0,
        0xaa, 0, 0xab, 0, 0xac, 0, 0xad, 0, 0xac, 0, 0xad, 0,
        0xac, 0, 0xad, 0, 0xac, 0, 0xad, 0, 0xac, 0, 0xad, 0,
        0xac, 0, 0xad, 0, 0xac, 0, 0xad, 0, 0xac, 0, 0xab, 0,
        0xaa, 0, 0xa9, 0, 0xa8, 0, 0xa7, 0, 0xa2, 0, 0xa2, 0,
        0xa2, 0, 0xa2, 0, 0xa3, 0, 0xa2, 1, 0xa3, 1, 0xa2, 1,
        0xa3, 2, 0xa2, 2, 0xa3, 2, 0xa7, 2, 0xa8, 2, 0xa7, 2,
        0xa8, 2, 0xa7, 2, 0xa8, 2, 0xa7, 2, 0xa8, 2, 0xa7, 2,
        0xa8, 2, 0xa7, 2, 0xa8, 2, 0xa7, 2, 0xa8, 2, 0xa7, 2,
        0xa2, 2, 0xa2, 2, 0xa6, 2, 0xa6, 2, 0xa6, 2, 0xa6, 2,
        0xa4, 2, 0xa5, 2, 0xa4, 1, 0xa5, 1, 0xa4, 0, 0xa5, 0,
        0xa2, 0, 0xa2, 0
    ];

    // Viewport::draw_unharmed_building: pigs_layout[]
    global.viewport_pigs_layout = [
        0,   0,   0,  0,
        6, 140,  -2,  6,
        5, 280,   8,  8,
        3, 420, -11,  8,
        1,  40,   2, 11,
        7, 180,  -8, 13,
        8, 320,  13, 14,
        2, 460,   0, 17,
        4,  90, -11, 19
    ];

    // Viewport::draw_burning_building: building_anim_offset_from_type[]
    global.viewport_building_anim_offset_from_type = [
        0, 10, 26, 39, 49, 62, 78, 97, 97, 116,
        129, 157, 167, 198, 211, 236, 255, 277, 305, 324,
        349, 362, 381, 418, 446
    ];

    // Viewport::draw_burning_building: building_burn_animation[]
    global.viewport_building_burn_animation = [
        /* Unfinished */
        0, -8, 2,
        8, 0, 4,
        0, 8, 2, -1,

        /* Fisher */
        0, -8, -10,
        0, 4, -12,
        8, -8, 4,
        8, 7, 4,
        0, -2, 8, -1,

        /* Lumberjack */
        0, 3, -13,
        0, -8, -10,
        8, 9, 3,
        8, -6, 3, -1,

        /* Boat builder */
        0, -1, -12,
        8, -8, 11,
        8, 7, 5, -1,

        /* Stone cutter */
        0, 6, -14,
        0, -9, -11,
        8, -8, 5,
        8, 6, 5, -1,

        /* Stone mine */
        8, -4, -40,
        8, -8, -15,
        8, 3, -14,
        8, -9, 4,
        8, 6, 5, -1,

        /* Coal mine */
        8, -4, -40,
        8, -1, -18,
        8, -8, -15,
        8, 6, 2,
        8, 0, 8,
        8, -8, 9, -1,

        /* Iron mine, gold mine */
        8, -4, -40,
        8, -2, -19,
        8, -9, -14,
        8, -8, 2,
        8, 6, 2,
        0, -4, 8, -1,

        /* Forester */
        0, 8, -11,
        0, -6, -8,
        8, -8, 4,
        8, 6, 4, -1,

        /* Stock */
        0, -2, -25,
        0, 6, -17,
        0, -9, -16,
        8, -21, 1,
        8, 21, 2,
        0, 15, 18,
        0, -16, 10,
        8, -8, 15,
        8, 5, 15, -1,

        /* Hut */
        0, 0, -11,
        8, -8, 5,
        8, 8, 5, -1,

        /* Farm */
        8, 22, -2,
        8, 7, -5,
        8, -3, -1,
        8, -23, 0,
        8, -12, 4,
        0, 25, 5,
        0, 21, 13,
        0, -17, 8,
        0, -10, 15,
        0, -2, 15, -1,

        /* Butcher */
        8, -15, 3,
        8, 20, 3,
        8, 7, 3,
        8, -4, 3, -1,

        /* Pig farm */
        8, 0, -2,
        8, 22, 1,
        8, 15, 5,
        8, -20, -1,
        8, -11, 3,
        0, 20, 12,
        0, -16, 7,
        0, -12, 14, -1,

        /* Mill */
        0, 7, -33,
        0, 5, -20,
        8, -2, -24,
        8, -6, 1,
        8, 4, 2,
        0, -3, 6, -1,

        /* Baker */
        0, -15, -16,
        0, -4, -19,
        0, 3, -16,
        8, -13, 2,
        8, -9, 7,
        8, 6, 7,
        0, 17, 1, -1,

        /* Saw mill */
        0, 7, -19,
        0, -1, -14,
        0, 16, -13,
        0, 5, -8,
        8, 14, 4,
        0, 10, 9,
        0, -17, 8,
        8, -11, 10,
        8, -1, 12, -1,

        /* Steel smelter */
        0, 5, -19,
        0, 16, -16,
        8, -14, 2,
        8, -10, 5,
        8, 15, 5,
        8, 2, 5, -1,

        /* Tool maker */
        8, 7, -19,
        0, -11, -17,
        0, -4, -11,
        0, 12, -10,
        8, -20, 0,
        8, -15, 7,
        8, 1, 7,
        8, 15, 7, -1,

        /* Weapon smith */
        8, -15, 1,
        8, -10, 3,
        8, 20, 3,
        8, 5, 3, -1,

        /* Tower */
        0, -6, -30,
        0, 7, -14,
        8, -11, -3,
        0, -8, 4,
        8, 9, 5,
        8, -4, 5, -1,

        /* Fortress */
        0, -3, -30,
        0, -15, -26,
        0, 21, -29,
        0, -13, -17,
        8, 4, -11,
        8, -2, -6,
        8, -22, 0,
        8, -17, 8,
        8, 20, 1,
        8, 10, 8,
        8, 4, 13,
        8, -11, 15, -1,

        /* Gold smelter */
        0, -15, -20,
        0, 10, -22,
        0, -3, -25,
        0, -8, -10,
        0, 7, -10,
        0, -13, 2,
        8, -8, 5,
        8, 6, 5,
        0, 16, 6, -1,

        /* Castle */
        0, 11, -46,
        0, -19, -42,
        8, 1, -27,
        8, 10, -13,
        0, -7, -24,
        8, -16, -6,
        0, -23, 4,
        8, -2, 0,
        8, 12, 12,
        8, -14, 17,
        8, -4, 19,
        0, 13, 19, -1
    ];

    // Viewport::draw_flag_and_res: res_pos[]
    global.viewport_res_pos = [
         6, -4,
        10, -2,
        -4, -4,
        10,  2,
        -8, -2,
         6,  4,
        -8,  2,
        -4,  4
    ];

    // Viewport::draw_row_serf: index1[]
    global.viewport_index1 = [
        0, 0, 48, 6, 96, -1, 48, 24,
        240, -1, 48, 30, 248, -1, 48, 12,
        48, 18, 96, 306, 96, 300, 48, 54,
        48, 72, 48, 36, 0, 48, 272, -1,
        48, 60, 264, -1, 48, 42, 280, -1,
        48, 66, 96, 312, 500, 600, 48, 318,
        48, 78, 0, 84, 48, 90, 48, 96,
        48, 102, 48, 108, 48, 114, 96, 324,
        96, 330, 96, 336, 96, 342, 96, 348,
        48, 354, 48, 360, 48, 366, 48, 372,
        48, 378, 48, 384, 504, 604, 509, -1,
        48, 120, 288, -1, 288, 420, 48, 126,
        48, 132, 96, 426, 0, 138, 304, -1,
        48, 390, 48, 144, 96, 432, 48, 198,
        510, 608, 48, 204, 48, 402, 48, 150,
        96, 438, 48, 156, 312, -1, 320, -1,
        48, 162, 48, 168, 96, 444, 0, 174,
        513, -1, 48, 408, 48, 180, 96, 450,
        0, 186, 520, -1, 48, 414, 48, 192,
        96, 456, 328, -1, 48, 210, 344, -1,
        48, 6, 48, 6, 48, 216, 528, -1,
        48, 534, 48, 528, 48, 288, 48, 282,
        48, 222, 533, -1, 48, 540, 48, 546,
        48, 552, 48, 558, 48, 564, 96, 468,
        96, 462, 48, 570, 48, 576, 48, 582,
        48, 396, 48, 228, 48, 234, 48, 240,
        48, 246, 48, 252, 48, 258, 48, 264,
        48, 270, 48, 276, 96, 474, 96, 480,
        96, 486, 96, 492, 96, 498, 96, 504,
        96, 510, 96, 516, 96, 522, 96, 612,
        144, 294, 144, 588, 144, 594, 144, 618,
        144, 624, 401, 294, 352, 297, 401, 588,
        352, 591, 401, 594, 352, 597, 401, 618,
        352, 621, 401, 624, 352, 627, 450, -1,
        192, -1
    ];

    // Viewport::draw_row_serf: index2[]
    global.viewport_index2 = [
        0, 0, 1, 0, 2, 0, 3, 0,
        4, 0, 5, 0, 6, 0, 7, 0,
        8, 1, 9, 1, 10, 1, 11, 1,
        12, 1, 13, 1, 14, 1, 15, 1,
        16, 2, 17, 2, 18, 2, 19, 2,
        20, 2, 21, 2, 22, 2, 23, 2,
        24, 3, 25, 3, 26, 3, 27, 3,
        28, 3, 29, 3, 30, 3, 31, 3,
        32, 4, 33, 4, 34, 4, 35, 4,
        36, 4, 37, 4, 38, 4, 39, 4,
        40, 5, 41, 5, 42, 5, 43, 5,
        44, 5, 45, 5, 46, 5, 47, 5,
        0, 0, 1, 0, 2, 0, 3, 0,
        4, 0, 5, 0, 6, 0, 2, 0,
        0, 1, 1, 1, 2, 1, 3, 1,
        4, 1, 5, 1, 6, 1, 2, 1,
        0, 2, 1, 2, 2, 2, 3, 2,
        4, 2, 5, 2, 6, 2, 2, 2,
        0, 3, 1, 3, 2, 3, 3, 3,
        4, 3, 5, 3, 6, 3, 2, 3,
        0, 0, 1, 0, 2, 0, 3, 0,
        4, 0, 5, 0, 6, 0, 7, 0,
        8, 0, 9, 0, 10, 0, 11, 0,
        12, 0, 13, 0, 14, 0, 15, 0,
        16, 0, 17, 0, 18, 0, 19, 0,
        20, 0, 21, 0, 22, 0, 23, 0,
        24, 0, 25, 0, 26, 0, 27, 0,
        28, 0, 29, 0, 30, 0, 31, 0,
        32, 0, 33, 0, 34, 0, 35, 0,
        36, 0, 37, 0, 38, 0, 39, 0,
        40, 0, 41, 0, 42, 0, 43, 0,
        44, 0, 45, 0, 46, 0, 47, 0,
        48, 0, 49, 0, 50, 0, 51, 0,
        52, 0, 53, 0, 54, 0, 55, 0,
        56, 0, 57, 0, 58, 0, 59, 0,
        60, 0, 61, 0, 62, 0, 63, 0,
        64, 0
    ];

    // Viewport::serf_get_body: transporter_type[]
    global.viewport_transporter_type = [
        0, 0x3000, 0x3500, 0x3b00, 0x4100, 0x4600, 0x4b00, 0x1400,
        0x700, 0x5100, 0x800, 0x1c00, 0x1d00, 0x1e00, 0x1a00, 0x1b00,
        0x6800, 0x6d00, 0x6500, 0x6700, 0x6b00, 0x6a00, 0x6600, 0x6900,
        0x6c00, 0x5700, 0x5600, 0, 0, 0, 0, 0
    ];

    // Viewport::serf_get_body: sailor_type[]
    global.viewport_sailor_type = [
        0, 0x3100, 0x3600, 0x3c00, 0x4200, 0x4700, 0x4c00, 0x1500,
        0x900, 0x7700, 0xa00, 0x2100, 0x2200, 0x2300, 0x1f00, 0x2000,
        0x6e00, 0x6f00, 0x7000, 0x7100, 0x7200, 0x7300, 0x7400, 0x7500,
        0x7600, 0x5f00, 0x6000, 0, 0, 0, 0, 0
    ];

    // Viewport::draw_active_serf: arr_4[]
    global.viewport_arr_4 = [
         9, 5,
        10, 7,
        10, 2,
         8, 6,
        11, 8,
         9, 6,
         9, 8,
         0, 0,
         0, 0,
         0, 0,
         5, 5,
         4, 7,
         4, 2,
         7, 5,
         3, 8,
         5, 6,
         5, 8,
         0, 0,
         0, 0,
         0, 0
    ];

    // Viewport::draw_serf_row: arr_1[]
    global.viewport_arr_1 = [
        0x240, 0x40, 0x380, 0x140, 0x300, 0x80, 0x180, 0x200,
        0, 0x340, 0x280, 0x100, 0x1c0, 0x2c0, 0x3c0, 0xc0
    ];

    // Viewport::draw_serf_row: arr_2[]
    global.viewport_arr_2 = [
        0x8800, 0x8800, 0x8800, 0x8800, 0x8801, 0x8802, 0x8803, 0x8804,
        0x8804, 0x8804, 0x8804, 0x8804, 0x8803, 0x8802, 0x8801, 0x8800,
        0x8800, 0x8800, 0x8800, 0x8800, 0x8801, 0x8802, 0x8803, 0x8804,
        0x8805, 0x8806, 0x8807, 0x8808, 0x8809, 0x8808, 0x8809, 0x8808,
        0x8809, 0x8807, 0x8806, 0x8805, 0x8804, 0x8804, 0x8804, 0x8804,
        0x28, 0x29, 0x2a, 0x2b, 0x4, 0x5, 0xe, 0xf,
        0x10, 0x11, 0x1a, 0x1b, 0x23, 0x25, 0x26, 0x27,
        0x8800, 0x8800, 0x8800, 0x8800, 0x8801, 0x8802, 0x8803, 0x8804,
        0x8803, 0x8802, 0x8801, 0x8800, 0x8800, 0x8800, 0x8800, 0x8800,
        0x8801, 0x8802, 0x8803, 0x8804, 0x8804, 0x8804, 0x8804, 0x8804,
        0x8805, 0x8806, 0x8807, 0x8808, 0x8809, 0x8807, 0x8806, 0x8805,
        0x8804, 0x8803, 0x8802, 0x8802, 0x8802, 0x8802, 0x8801, 0x8800,
        0x8800, 0x8800, 0x8800, 0x8801, 0x8802, 0x8803, 0x8803, 0x8803,
        0x8803, 0x8804, 0x8804, 0x8804, 0x8805, 0x8806, 0x8807, 0x8808,
        0x8809, 0x8808, 0x8809, 0x8808, 0x8809, 0x8807, 0x8806, 0x8805,
        0x8803, 0x8803, 0x8803, 0x8802, 0x8802, 0x8801, 0x8801, 0x8801
    ];

    // Viewport::draw_serf_row: arr_3[]
    global.viewport_arr_3 = [
        0, 0, 0, 0, 0, 0, -2, 1, 0, 0, 2, 2, 0, 5, 0, 0,
        0, 0, 0, 3, -2, 2, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0,
        0, 0, -1, 2, -2, 1, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0,
        1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, -1, 2, -2, 1, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0,
        1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ];
}

/// Viewport(Interface *interface, PMap map) : GuiObject, Map::Handler.
/// `width`/`height`/`x`/`y`/`displayed`/... come from GuiObject (set_size()).
/// The map cursor position and sprites live in the Interface
/// (interface.get_map_cursor_pos(), interface.get_map_cursor_sprite(i)).
function Viewport(_interface, _map) : GuiObject() constructor {
    viewport_init_tables();
    interface = _interface;
    game = _interface.get_game();
    map = _map;
    offset_x = 0;
    offset_y = 0;
    last_tick = 0;
    layers = ViewportLayer.all_layers;
    // Landscape tile cache: surface per tile id (or -1)
    horiz_tiles = map.geom.cols div MAP_TILE_COLS;
    vert_tiles = map.geom.rows div MAP_TILE_ROWS;
    landscape_tiles = array_create(horiz_tiles * vert_tiles, -1);
    // GuiObject frame cache (gui.cc: GuiObject::draw only calls internal_draw()
    // when `redraw` is set, otherwise it blits the object's own frame). The
    // viewport is by far the most expensive object to render, and Freeserf only
    // marks it dirty every 8 game ticks (Viewport::update), so caching it here
    // reproduces the original's redraw cadence instead of redrawing at 60 Hz.
    frame_surface = -1;

    // Integer pixel zoom. The viewport always renders at 1:1 into a surface of
    // width x height (which is the *logical* size, screen size div zoom) and
    // that surface is then blitted at `zoom` scale, so zooming never resamples.
    zoom = 1;
    screen_width = 0;
    screen_height = 0;
    // A drag delta arrives in screen pixels and the map can only move by whole
    // *map* pixels, so dividing by the zoom leaves a remainder. It is carried
    // here into the next event rather than dropped: at 4x, dropping it threw
    // away up to 3 pixels of every event, which is most of a slow drag.
    drag_carry_x = 0;
    drag_carry_y = 0;

    tri_spr = [
        32, 32, 32, 32, 32, 32, 32, 32,
        32, 32, 32, 32, 32, 32, 32, 32,
        32, 32, 32, 32, 32, 32, 32, 32,
        32, 32, 32, 32, 32, 32, 32, 32,
        0, 1, 2, 3, 4, 5, 6, 7,
        0, 1, 2, 3, 4, 5, 6, 7,
        0, 1, 2, 3, 4, 5, 6, 7,
        0, 1, 2, 3, 4, 5, 6, 7,
        24, 25, 26, 27, 28, 29, 30, 31,
        24, 25, 26, 27, 28, 29, 30, 31,
        24, 25, 26, 27, 28, 29, 30, 31,
        8, 9, 10, 11, 12, 13, 14, 15,
        8, 9, 10, 11, 12, 13, 14, 15,
        8, 9, 10, 11, 12, 13, 14, 15,
        16, 17, 18, 19, 20, 21, 22, 23,
        16, 17, 18, 19, 20, 21, 22, 23
    ];

    tri_mask_up = [
         0,  1,  3,  6,  7, -1, -1, -1, -1,
         0,  1,  2,  5,  6,  7, -1, -1, -1,
         0,  1,  2,  3,  5,  6,  7, -1, -1,
         0,  1,  2,  3,  4,  5,  6,  7, -1,
         0,  1,  2,  3,  4,  4,  5,  6,  7,
        -1,  0,  1,  2,  3,  4,  5,  6,  7,
        -1, -1,  0,  1,  2,  4,  5,  6,  7,
        -1, -1, -1,  0,  1,  2,  5,  6,  7,
        -1, -1, -1, -1,  0,  1,  4,  6,  7
    ];

    tri_mask_down = [
         0,  0,  0,  0,  0, -1, -1, -1, -1,
         1,  1,  1,  1,  1,  0, -1, -1, -1,
         3,  2,  2,  2,  2,  1,  0, -1, -1,
         6,  5,  3,  3,  3,  2,  1,  0, -1,
         7,  6,  5,  4,  4,  3,  2,  1,  0,
        -1,  7,  6,  5,  4,  4,  4,  2,  1,
        -1, -1,  7,  6,  5,  5,  5,  5,  4,
        -1, -1, -1,  7,  6,  6,  6,  6,  6,
        -1, -1, -1, -1,  7,  7,  7,  7,  7
    ];

    // ------------------------------------------------------------ helpers

    // set_size / set_redraw / play_sound / move_to / set_displayed etc. are
    // inherited from GuiObject (set_size() calls layout(), which clears the
    // landscape tile cache exactly like Viewport::layout()).

    /// void switch_layer(Layer layer) { layers ^= layer; }
    static switch_layer = function(_layer) {
        layers ^= _layer;
    };

    static get_layers = function() {
        return layers;
    };

    static set_layers = function(_layers) {
        layers = _layers;
    };

    // Player colour: Interface.get_player_color() already returns a GameMaker
    // colour (make_colour_rgb of the Player::Color {red, green, blue}).
    static get_player_colour = function(_player_index) {
        return interface.get_player_color(_player_index);
    };

    // DataSource::get_animation(animation, phase): returns [sprite, x, y].
    static get_animation = function(_animation, _phase) {
        _phase = _phase >> 3;
        if ((_animation < 0) || (_animation >= array_length(global.animations))) {
            show_debug_message("data: Failed to get animation #" + string(_animation) + " phase #" + string(_phase));
            return [0, 0, 0];
        }
        var _phases = global.animations[_animation];
        if ((_phase < 0) || (_phase >= array_length(_phases))) {
            show_debug_message("data: Failed to get animation #" + string(_animation) + " phase #" + string(_phase) + " (got only " + string(array_length(_phases)) + " phases)");
            return [0, 0, 0];
        }
        return _phases[_phase];
    };

    // Freeserf Frame::draw_sprite(x, y, res, index): offsets are baked into the
    // GameMaker sprite origin, so a plain draw_sprite is equivalent.
    static draw_game_sprite = function(_lx, _ly, _index) {
        draw_sprite(spr_game_object, _index - 1, _lx, _ly);
    };

    static draw_shadow_and_building_sprite = function(_lx, _ly, _index, _color) {
        draw_sprite(spr_map_shadow, _index, _lx, _ly);
        draw_sprite(spr_map_object, _index, _lx, _ly);
        if (sprite_exists(spr_map_object_mask)) {
            var _row = global.sprite_meta.map_object[_index];
            if (_row[0] == 1) {
                draw_sprite_ext(spr_map_object_mask, _index, _lx, _ly, 1, 1, 0, _color, 1);
            }
        }
    };

    // Viewport::draw_serf(x, y, color, head, body): torso (colour masked) plus
    // the head drawn relatively to the torso delta (Frame::draw_sprite_relatively).
    // Screen coordinates.
    static draw_serf = function(_lx, _ly, _color, _head, _body) {
        var _trow = global.sprite_meta.serf_torso[_body];
        if (_trow[0] == 1) {
            draw_sprite(spr_serf_torso, _body, _lx, _ly);
            if (sprite_exists(spr_serf_torso_mask)) {
                draw_sprite_ext(spr_serf_torso_mask, _body, _lx, _ly, 1, 1, 0, _color, 1);
            }
        }

        if (_head >= 0) {
            var _hrow = global.sprite_meta.serf_head[_head];
            if (_hrow[0] == 1) {
                draw_sprite(spr_serf_head, _head, _lx + _trow[3], _ly + _trow[4]);
            }
        }
    };

    // Frame::draw_sprite(x, y, res, index, use_off=true, progress): only the
    // lower `progress` part of the sprite is drawn (same clipping as
    // gfx_draw_sprite_full). Screen coordinates, origin baked into the sprite.
    static draw_sprite_progress_screen = function(_spr, _rows, _index, _sx, _sy, _p) {
        var _m = _rows[_index];
        if (_m[0] == 0) {
            return;
        }
        if (_p >= 1) {
            draw_sprite(_spr, _index, _sx, _sy);
        } else {
            var _h = _m[6];
            var _y_off = _h - floor(_h * _p);
            var _ox = sprite_get_xoffset(_spr);
            var _oy = sprite_get_yoffset(_spr);
            var _left = _ox + _m[1];
            var _top = _oy + _m[2] + _y_off;
            var _ih = _h - _y_off;
            if (_ih > 0) {
                draw_sprite_part(_spr, _index, _left, _top, _m[5], _ih, _sx - _ox + _left, _sy - _oy + _top);
            }
        }
    };

    static draw_shadow_and_building_unfinished = function(_lx, _ly, _index, _progress) {
        var _p = _progress / 0xFFFF;
        draw_sprite_progress_screen(spr_map_shadow, global.sprite_meta.map_shadow, _index, _lx, _ly, _p);
        draw_sprite_progress_screen(spr_map_object, global.sprite_meta.map_object, _index, _lx, _ly, _p);
    };

    // ------------------------------------------------------------ landscape

    static draw_triangle_up = function(_lx, _ly, _m, _left, _right, _pos) {
        if (((_left - _m) < -4) || ((_left - _m) > 4)) {
            throw ("Failed to draw triangle up (1).");
        }
        if (((_right - _m) < -4) || ((_right - _m) > 4)) {
            throw ("Failed to draw triangle up (2).");
        }
        var _mask = 4 + _m - _left + 9 * (4 + _m - _right);
        if (tri_mask_up[_mask] < 0) {
            throw ("Failed to draw triangle up (3).");
        }
        var _type = map.get_type_up(map.geom.move_up(_pos));
        var _index = (_type << 3) | tri_mask_up[_mask];
        if (_index >= 128) {
            throw ("Failed to draw triangle up (4).");
        }
        var _sprite = tri_spr[_index];
        draw_sprite(spr_ground_up, _mask * MAP_TILE_TEXTURES + _sprite, _lx, _ly);
    };

    static draw_triangle_down = function(_lx, _ly, _m, _left, _right, _pos) {
        if (((_left - _m) < -4) || ((_left - _m) > 4)) {
            throw ("Failed to draw triangle down (1).");
        }
        if (((_right - _m) < -4) || ((_right - _m) > 4)) {
            throw ("Failed to draw triangle down (2).");
        }
        var _mask = 4 + _left - _m + 9 * (4 + _right - _m);
        if (tri_mask_down[_mask] < 0) {
            throw ("Failed to draw triangle down (3).");
        }
        var _type = map.get_type_down(map.geom.move_up_left(_pos));
        var _index = (_type << 3) | tri_mask_down[_mask];
        if (_index >= 128) {
            throw ("Failed to draw triangle down (4).");
        }
        var _sprite = tri_spr[_index];
        draw_sprite(spr_ground_down, _mask * MAP_TILE_TEXTURES + _sprite, _lx, _ly + MAP_TILE_HEIGHT);
    };

    // Draw a column (vertical) of tiles, starting at an up pointing tile.
    static draw_up_tile_col = function(_pos, _x_base, _y_base, _max_y) {
        var _m = map.get_height(_pos);
        var _left = 0;
        var _right = 0;
        var _goto_down = false;

        // Loop until a tile is inside the frame (y >= 0).
        while (true) {
            _pos = map.geom.move_down(_pos);
            _left = map.get_height(_pos);
            _right = map.get_height(map.geom.move_right(_pos));
            var _t = min(_left, _right);
            if (_y_base + MAP_TILE_HEIGHT - 4 * _t >= 0) {
                break;
            }
            _y_base += MAP_TILE_HEIGHT;
            _pos = map.geom.move_down_right(_pos);
            _m = map.get_height(_pos);
            if (_y_base + MAP_TILE_HEIGHT - 4 * _m >= 0) {
                _goto_down = true;
                break;
            }
            _y_base += MAP_TILE_HEIGHT;
        }

        // Loop until a tile is completely outside the frame (y >= max_y).
        while (true) {
            if (!_goto_down) {
                if (_y_base - 2 * MAP_TILE_HEIGHT - 4 * _m >= _max_y) {
                    break;
                }
                draw_triangle_up(_x_base, _y_base - 4 * _m, _m, _left, _right, _pos);
                _y_base += MAP_TILE_HEIGHT;
                _pos = map.geom.move_down_right(_pos);
                _m = map.get_height(_pos);
                if (_y_base - 2 * MAP_TILE_HEIGHT - 4 * max(_left, _right) >= _max_y) {
                    break;
                }
            }
            _goto_down = false;
            draw_triangle_down(_x_base, _y_base - 4 * _m, _m, _left, _right, _pos);
            _y_base += MAP_TILE_HEIGHT;
            _pos = map.geom.move_down(_pos);
            _left = map.get_height(_pos);
            _right = map.get_height(map.geom.move_right(_pos));
        }
    };

    // Draw a column (vertical) of tiles, starting at a down pointing tile.
    static draw_down_tile_col = function(_pos, _x_base, _y_base, _max_y) {
        var _left = map.get_height(_pos);
        var _right = map.get_height(map.geom.move_right(_pos));
        var _m = 0;
        var _goto_down = false;

        while (true) {
            _pos = map.geom.move_down_right(_pos);
            _m = map.get_height(_pos);
            if (_y_base + MAP_TILE_HEIGHT - 4 * _m >= 0) {
                _goto_down = true;
                break;
            }
            _y_base += MAP_TILE_HEIGHT;
            _pos = map.geom.move_down(_pos);
            _left = map.get_height(_pos);
            _right = map.get_height(map.geom.move_right(_pos));
            var _t = min(_left, _right);
            if (_y_base + MAP_TILE_HEIGHT - 4 * _t >= 0) {
                break;
            }
            _y_base += MAP_TILE_HEIGHT;
        }

        while (true) {
            if (!_goto_down) {
                if (_y_base - 2 * MAP_TILE_HEIGHT - 4 * _m >= _max_y) {
                    break;
                }
                draw_triangle_up(_x_base, _y_base - 4 * _m, _m, _left, _right, _pos);
                _y_base += MAP_TILE_HEIGHT;
                _pos = map.geom.move_down_right(_pos);
                _m = map.get_height(_pos);
                if (_y_base - 2 * MAP_TILE_HEIGHT - 4 * max(_left, _right) >= _max_y) {
                    break;
                }
            }
            _goto_down = false;
            draw_triangle_down(_x_base, _y_base - 4 * _m, _m, _left, _right, _pos);
            _y_base += MAP_TILE_HEIGHT;
            _pos = map.geom.move_down(_pos);
            _left = map.get_height(_pos);
            _right = map.get_height(map.geom.move_right(_pos));
        }
    };

    /// GuiObject.set_size(), but the argument is the on-screen size. The
    /// logical size the map is rendered at is that divided by the zoom.
    static set_size = function(_new_width, _new_height) {
        screen_width = _new_width;
        screen_height = _new_height;
        width = _new_width div zoom;
        height = _new_height div zoom;
        layout();
        set_redraw();
    };

    static get_zoom = function() {
        return zoom;
    };

    /// 1..MAX_ZOOM. Keeps whatever map position is under the middle of the
    /// view centred, so zooming does not throw you across the map.
    static set_zoom = function(_new_zoom) {
        var _z = clamp(_new_zoom, 1, MAX_ZOOM);
        if (_z == zoom) {
            return;
        }

        var _centre = get_current_map_pos();
        zoom = _z;
        drag_carry_x = 0;
        drag_carry_y = 0;
        set_size(screen_width, screen_height);
        move_to_map_pos(_centre);
    };

    static layout = function() {
        if (surface_exists(frame_surface)) {
            surface_free(frame_surface);
        }
        frame_surface = -1;
        var _n = array_length(landscape_tiles);
        for (var _i = 0; _i < _n; _i++) {
            if (landscape_tiles[_i] != -1) {
                if (surface_exists(landscape_tiles[_i])) {
                    surface_free(landscape_tiles[_i]);
                }
                landscape_tiles[_i] = -1;
            }
        }
    };

    static redraw_map_pos = function(_pos) {
        var _mp = map_pix_from_map_coord(_pos, map.get_height(_pos));
        var _tile_width = MAP_TILE_COLS * MAP_TILE_WIDTH;
        var _tile_height = MAP_TILE_ROWS * MAP_TILE_HEIGHT;
        var _tc = (_mp[0] div _tile_width) mod horiz_tiles;
        var _tr = (_mp[1] div _tile_height) mod vert_tiles;
        var _tid = _tc + horiz_tiles * _tr;
        if (landscape_tiles[_tid] != -1) {
            if (surface_exists(landscape_tiles[_tid])) {
                surface_free(landscape_tiles[_tid]);
            }
            landscape_tiles[_tid] = -1;
        }
    };

    static get_tile_surface = function(_tid, _tc, _tr) {
        var _surf = landscape_tiles[_tid];
        if (_surf != -1) {
            if (surface_exists(_surf)) {
                return _surf;
            }
        }
        var _tile_width = MAP_TILE_COLS * MAP_TILE_WIDTH;
        var _tile_height = MAP_TILE_ROWS * MAP_TILE_HEIGHT;

        _surf = surface_create(_tile_width, _tile_height);
        surface_set_target(_surf);
        draw_clear(c_black);

        var _col = (_tc * MAP_TILE_COLS + (_tr * MAP_TILE_ROWS) div 2) mod map.geom.cols;
        var _row = _tr * MAP_TILE_ROWS;
        var _pos = map.geom.pos(_col, _row);
        var _x_base = -(MAP_TILE_WIDTH div 2);

        // Draw one extra column as half a column will be outside the tile on both sides.
        for (var _c = 0; _c < MAP_TILE_COLS + 1; _c++) {
            draw_up_tile_col(_pos, _x_base, 0, _tile_height);
            draw_down_tile_col(_pos, _x_base + MAP_TILE_WIDTH div 2, 0, _tile_height);
            _pos = map.geom.move_right(_pos);
            _x_base += MAP_TILE_WIDTH;
        }
        surface_reset_target();
        landscape_tiles[_tid] = _surf;
        return _surf;
    };

    // Draws the landscape at screen origin (_ox, _oy) — the viewport's top-left.
    /// Builds any visible landscape tile surfaces that are missing. Called
    /// before the frame surface is targeted so that get_tile_surface() never
    /// has to nest a second render target inside the frame.
    static prepare_landscape_tiles = function() {
        var _tile_width = MAP_TILE_COLS * MAP_TILE_WIDTH;
        var _tile_height = MAP_TILE_ROWS * MAP_TILE_HEIGHT;
        var _map_width = map.geom.cols * MAP_TILE_WIDTH;
        var _map_height = map.geom.rows * MAP_TILE_HEIGHT;

        var _my = offset_y;
        var _ly = 0;
        var _x_base = 0;
        while (_ly < height) {
            while (_my >= _map_height) {
                _my -= _map_height;
                _x_base += (map.geom.rows * MAP_TILE_WIDTH) div 2;
            }
            var _ty = _my mod _tile_height;
            var _lx = 0;
            var _mx = (offset_x + _x_base) mod _map_width;
            while (_lx < width) {
                var _tx = _mx mod _tile_width;
                var _tc = (_mx div _tile_width) mod horiz_tiles;
                var _tr = (_my div _tile_height) mod vert_tiles;
                var _tid = _tc + horiz_tiles * _tr;
                get_tile_surface(_tid, _tc, _tr);
                _lx += _tile_width - _tx;
                _mx += _tile_width - _tx;
            }
            _ly += _tile_height - _ty;
            _my += _tile_height - _ty;
        }
    };

    static draw_landscape = function(_ox, _oy) {
        var _tile_width = MAP_TILE_COLS * MAP_TILE_WIDTH;
        var _tile_height = MAP_TILE_ROWS * MAP_TILE_HEIGHT;
        var _map_width = map.geom.cols * MAP_TILE_WIDTH;
        var _map_height = map.geom.rows * MAP_TILE_HEIGHT;

        var _my = offset_y;
        var _ly = 0;
        var _x_base = 0;
        while (_ly < height) {
            while (_my >= _map_height) {
                _my -= _map_height;
                _x_base += (map.geom.rows * MAP_TILE_WIDTH) div 2;
            }
            var _ty = _my mod _tile_height;
            var _lx = 0;
            var _mx = (offset_x + _x_base) mod _map_width;
            while (_lx < width) {
                var _tx = _mx mod _tile_width;
                var _tc = (_mx div _tile_width) mod horiz_tiles;
                var _tr = (_my div _tile_height) mod vert_tiles;
                var _tid = _tc + horiz_tiles * _tr;
                var _surf = get_tile_surface(_tid, _tc, _tr);
                var _w = _tile_width - _tx;
                if (_lx + _w > width) {
                    _w = width - _lx;
                }
                var _h = _tile_height - _ty;
                if (_ly + _h > height) {
                    _h = height - _ly;
                }
                draw_surface_part(_surf, _tx, _ty, _w, _h, _ox + _lx, _oy + _ly);
                _lx += _tile_width - _tx;
                _mx += _tile_width - _tx;
            }
            _ly += _tile_height - _ty;
            _my += _tile_height - _ty;
        }
    };

    // ------------------------------------------------------------ paths and borders
    // These take viewport-local coordinates and add global.gfx_ox/gfx_oy
    // (set by draw() via gfx_set_origin), like Freeserf's frame-local drawing.

    static draw_path_segment = function(_lx, _ly, _pos, _dir) {
        var _h1 = map.get_height(_pos);
        var _h2 = map.get_height(map.move(_pos, _dir));
        var _h_diff = _h1 - _h2;

        var _t1 = 0;
        var _t2 = 0;
        var _h3 = 0;
        var _h4 = 0;
        var _h_diff_2 = 0;

        switch (_dir) {
        case Direction.right:
            _ly -= 4 * max(_h1, _h2) + 2;
            _t1 = map.get_type_down(_pos);
            _t2 = map.get_type_up(map.move_up(_pos));
            _h3 = map.get_height(map.move_up(_pos));
            _h4 = map.get_height(map.move_down_right(_pos));
            _h_diff_2 = (_h3 - _h4) - 4 * _h_diff;
            break;
        case Direction.down_right:
            _ly -= 4 * _h1 + 2;
            _t1 = map.get_type_up(_pos);
            _t2 = map.get_type_down(_pos);
            _h3 = map.get_height(map.move_right(_pos));
            _h4 = map.get_height(map.move_down(_pos));
            _h_diff_2 = 2 * (_h3 - _h4);
            break;
        case Direction.down:
            _lx -= MAP_TILE_WIDTH div 2;
            _ly -= 4 * _h1 + 2;
            _t1 = map.get_type_up(_pos);
            _t2 = map.get_type_down(map.move_left(_pos));
            _h3 = map.get_height(map.move_left(_pos));
            _h4 = map.get_height(map.move_down(_pos));
            _h_diff_2 = 4 * _h_diff - _h3 + _h4;
            break;
        default:
            throw ("draw_path_segment: NOT_REACHED");
            break;
        }

        var _mask = _h_diff + 4 + _dir * 9;
        var _sprite = 0;
        var _type = max(_t1, _t2);

        if (_h_diff_2 > 4) {
            _sprite = 0;
        } else if (_h_diff_2 > -6) {
            _sprite = 1;
        } else {
            _sprite = 2;
        }

        if (_type <= Terrain.water3) {
            _sprite = 9;
        } else if (_type >= Terrain.desert0) {
            /* Grey set for rock and snow alike. Sprites 3-5 are baked from the
               brown ground tiles, so a path over a mountain came out the same
               colour as the rock under it; 6-8 are grey and read clearly. */
            _sprite += 6;
        }

        // Frame::draw_masked_sprite(AssetPathMask, mask, AssetPathGround, sprite):
        // pre-baked as spr_path_baked frame = mask * 10 + ground.
        draw_sprite(spr_path_baked, _mask * 10 + _sprite, global.gfx_ox + _lx, global.gfx_oy + _ly);
    };

    static draw_border_segment = function(_lx, _ly, _pos, _dir) {
        var _h1 = map.get_height(_pos);
        var _h2 = map.get_height(map.move(_pos, _dir));
        var _h_diff = _h2 - _h1;

        var _t1 = 0;
        var _t2 = 0;
        var _h3 = 0;
        var _h4 = 0;
        var _h_diff_2 = 0;

        switch (_dir) {
        case Direction.right:
            _lx += MAP_TILE_WIDTH div 2;
            _ly -= 2 * (_h1 + _h2) + 4;
            _t1 = map.get_type_down(_pos);
            _t2 = map.get_type_up(map.move_up(_pos));
            _h3 = map.get_height(map.move_up(_pos));
            _h4 = map.get_height(map.move_down_right(_pos));
            _h_diff_2 = _h3 - _h4 + 4 * _h_diff;
            break;
        case Direction.down_right:
            _lx += MAP_TILE_WIDTH div 4;
            _ly -= 2 * (_h1 + _h2) - 6;
            _t1 = map.get_type_up(_pos);
            _t2 = map.get_type_down(_pos);
            _h3 = map.get_height(map.move_right(_pos));
            _h4 = map.get_height(map.move_down(_pos));
            _h_diff_2 = 2 * (_h3 - _h4);
            break;
        case Direction.down:
            _lx -= MAP_TILE_WIDTH div 4;
            _ly -= 2 * (_h1 + _h2) - 6;
            _t1 = map.get_type_up(_pos);
            _t2 = map.get_type_down(map.move_left(_pos));
            _h3 = map.get_height(map.move_left(_pos));
            _h4 = map.get_height(map.move_down(_pos));
            _h_diff_2 = 4 * _h_diff - _h3 + _h4;
            break;
        default:
            throw ("draw_border_segment: NOT_REACHED");
            break;
        }

        var _sprite = 0;
        var _type = max(_t1, _t2);

        if (_h_diff_2 > 1) {
            _sprite = 0;
        } else if (_h_diff_2 > -9) {
            _sprite = 1;
        } else {
            _sprite = 2;
        }

        if (_type <= Terrain.water3) {
            _sprite = 9; /* Bouy */
        } else if (_type >= Terrain.desert0) {
            /* Matches draw_path_segment above: grey for rock and snow. */
            _sprite += 6;
        }

        gfx_draw_sprite_off(_lx, _ly, Asset.map_border, _sprite, false);
    };

    static draw_paths_and_borders = function() {
        var _off = get_offset();
        var _x_off = _off[0];
        var _y_off = _off[1];
        var _base_pos = _off[4];

        for (var _x_base = _x_off; _x_base < width + MAP_TILE_WIDTH; _x_base += MAP_TILE_WIDTH) {
            var _pos = _base_pos;
            var _y_base = _y_off;
            var _row = 0;

            while (true) {
                var _lx = 0;
                if (_row mod 2 == 0) {
                    _lx = _x_base;
                } else {
                    _lx = _x_base - MAP_TILE_WIDTH div 2;
                }

                var _ly = _y_base - 4 * map.get_height(_pos);
                if (_ly >= height) {
                    break;
                }

                /* For each direction right, down right and down,
                   draw the corresponding paths and borders. */
                for (var _d = Direction.right; _d <= Direction.down; _d++) {
                    var _other_pos = map.move(_pos, _d);

                    if (map.has_path(_pos, _d)) {
                        draw_path_segment(_lx, _y_base, _pos, _d);
                    } else if (map.has_owner(_pos) != map.has_owner(_other_pos) ||
                               map.get_owner(_pos) != map.get_owner(_other_pos)) {
                        draw_border_segment(_lx, _y_base, _pos, _d);
                    }
                }

                if (_row mod 2 == 0) {
                    _pos = map.move_down(_pos);
                } else {
                    _pos = map.move_down_right(_pos);
                }

                _y_base += MAP_TILE_HEIGHT;
                _row += 1;
            }

            _base_pos = map.move_right(_base_pos);
        }

        /* If we're in road construction mode, also draw
           the temporarily placed roads. */
        if (interface.is_building_road()) {
            var _road = interface.get_building_road();
            var _rpos = _road.get_source();
            var _dirs = _road.get_dirs();
            var _n = array_length(_dirs);
            for (var _i = 0; _i < _n; _i++) {
                var _dir = _dirs[_i];
                var _draw_pos = _rpos;
                var _draw_dir = _dir;
                if (_draw_dir > Direction.down) {
                    _draw_pos = map.move(_rpos, _dir);
                    _draw_dir = reverse_direction(_dir);
                }

                var _s = screen_pix_from_map_coord(_draw_pos);

                draw_path_segment(_s[0], _s[1] + 4 * map.get_height(_draw_pos), _draw_pos, _draw_dir);

                _rpos = map.move(_rpos, _dir);
            }
        }
    };

    // ------------------------------------------------------------ objects

    static draw_water_waves = function(_pos, _lx, _ly) {
        var _sprite = (((_pos ^ 5) + (interface.get_game().get_tick() >> 3)) & 0xf);
        if (map.get_type_down(_pos) <= Terrain.water3 && map.get_type_up(_pos) <= Terrain.water3) {
            draw_sprite(spr_map_waves, _sprite, _lx - 16, _ly);
        } else if (map.get_type_down(_pos) <= Terrain.water3) {
            draw_sprite(spr_waves_down, _sprite, _lx, _ly + 16);
        } else {
            draw_sprite(spr_waves_up, _sprite, _lx - 16, _ly);
        }
    };

    static draw_water_waves_row = function(_pos, _y_base, _cols, _x_base) {
        for (var _i = 0; _i < _cols; _i++) {
            if (map.get_type_up(_pos) <= Terrain.water3 || map.get_type_down(_pos) <= Terrain.water3) {
                draw_water_waves(_pos, _x_base, _y_base);
            }
            _x_base += MAP_TILE_WIDTH;
            _pos = map.geom.move_right(_pos);
        }
    };

    // ------------------------------------------------------------ buildings
    // Building/flag/serf drawing functions take SCREEN coordinates (the row
    // functions receive _ox + _lx from draw_game_objects).

    static draw_building_unfinished = function(_building, _bld_type, _lx, _ly) {
        if (_building.get_progress() == 0) { /* Draw cross */
            draw_shadow_and_building_sprite(_lx, _ly, 0x90, c_white);
        } else {
            /* Stone waiting */
            var _stone = _building.waiting_stone();
            for (var _i = 0; _i < _stone; _i++) {
                draw_game_sprite(_lx + 10 - _i * 3, _ly - 8 + _i, 1 + ResourceType.stone);
            }

            /* Planks waiting */
            var _planks = _building.waiting_planks();
            for (var _i = 0; _i < _planks; _i++) {
                draw_game_sprite(_lx + 12 - _i * 3, _ly - 6 + _i, 1 + ResourceType.plank);
            }

            if ((_building.get_progress() & (1 << 15)) != 0) { /* Frame finished */
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_frame_sprite[_bld_type], c_white);
                draw_shadow_and_building_unfinished(_lx, _ly, global.viewport_map_building_sprite[_bld_type],
                                                    2 * (_building.get_progress() & 0x7fff));
            } else {
                draw_shadow_and_building_sprite(_lx, _ly, 0x91, c_white); /* corner stone */
                if (_building.get_progress() > 1) {
                    draw_shadow_and_building_unfinished(_lx, _ly,
                                                        global.viewport_map_building_frame_sprite[_bld_type],
                                                        2 * _building.get_progress());
                }
            }
        }
    };

    static draw_ocupation_flag = function(_building, _lx, _ly, _mul) {
        if (_building.has_knight()) {
            draw_game_sprite(_lx, _ly - floor(_mul * _building.get_knight_count()),
                             182 + ((interface.get_game().get_tick() >> 3) & 3) +
                             4 * _building.get_threat_level());
        }
    };

    static draw_unharmed_building = function(_building, _lx, _ly) {
        // Random random; (default constructor: seeded from the clock, one random() consumed)
        var _random = new RandomState(irandom(0xFFFF), irandom(0xFFFF), irandom(0xFFFF));
        _random.next_random();

        var _pigfarm_anim = global.viewport_pigfarm_anim;
        var _tick = interface.get_game().get_tick();

        if (_building.is_done()) {
            var _type = _building.get_type();
            switch (_type) {
            case BuildingType.fisher:
            case BuildingType.lumberjack:
            case BuildingType.stonecutter:
            case BuildingType.forester:
            case BuildingType.stock:
            case BuildingType.farm:
            case BuildingType.butcher:
            case BuildingType.sawmill:
            case BuildingType.tool_maker:
            case BuildingType.castle:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                break;
            case BuildingType.boatbuilder:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                if (_building.get_res_count_in_stock(1) > 0) {
                    /* TODO x might not be correct */
                    draw_game_sprite(_lx + 3, _ly + 13,
                                     174 + _building.get_res_count_in_stock(1));
                }
                break;
            case BuildingType.stone_mine:
            case BuildingType.coal_mine:
            case BuildingType.iron_mine:
            case BuildingType.gold_mine:
                if (_building.is_active()) { /* Draw elevator up */
                    draw_game_sprite(_lx - 6, _ly - 39, 152);
                }
                if (_building.is_playing_sfx()) { /* Draw elevator down */
                    draw_game_sprite(_lx - 6, _ly - 39, 153);
                    var _bpos = _building.get_position();
                    // reinterpret_cast<uint8_t*>(&pos)[1] -> second (little endian) byte of pos
                    if ((((_tick + ((_bpos >> 8) & 0xff)) >> 3) & 7) == 0
                        && _random.next_random() < 40000) {
                        play_sound(Sfx.elevator);
                    }
                }
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                break;
            case BuildingType.hut:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                draw_ocupation_flag(_building, _lx - 14, _ly + 2, 2);
                break;
            case BuildingType.pig_farm:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                if (_building.get_res_count_in_stock(1) > 0) {
                    if ((_random.next_random() & 0x7f) < _building.get_res_count_in_stock(1)) {
                        play_sound(Sfx.pig_oink);
                    }

                    var _pigs_count = _building.get_res_count_in_stock(1);
                    var _pigs_layout = global.viewport_pigs_layout;

                    for (var _p = 1; _p <= _pigs_count; _p++) {
                        if (_pigs_count >= _pigs_layout[_p * 4]) {
                            var _i = (_pigs_layout[_p * 4 + 1] + (_tick >> 3)) & 0xfe;
                            draw_game_sprite(_lx + _pigfarm_anim[_i + 1] + _pigs_layout[_p * 4 + 2],
                                             _ly + _pigs_layout[_p * 4 + 3], _pigfarm_anim[_i]);
                        }
                    }
                }
                break;
            case BuildingType.mill:
                if (_building.is_active()) {
                    if (((_tick >> 4) & 3) != 0) {
                        _building.stop_playing_sfx();
                    } else if (!_building.is_playing_sfx()) {
                        _building.start_playing_sfx();
                        play_sound(Sfx.mill_grinding);
                    }
                    draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type] +
                                                    ((_tick >> 4) & 3), c_white);
                } else {
                    draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                }
                break;
            case BuildingType.baker:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                if (_building.is_active()) {
                    draw_game_sprite(_lx + 5, _ly - 21, 154 + ((_tick >> 3) & 7));
                }
                break;
            case BuildingType.steel_smelter:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                if (_building.is_active()) {
                    var _i = (_tick >> 3) & 7;
                    if (_i == 0 || (_i == 7 && !_building.is_playing_sfx())) {
                        _building.start_playing_sfx();
                        play_sound(Sfx.gold_boils);
                    } else if (_i != 7) {
                        _building.stop_playing_sfx();
                    }

                    draw_game_sprite(_lx + 6, _ly - 32, 128 + _i);
                }
                break;
            case BuildingType.weapon_smith:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                if (_building.is_active()) {
                    draw_game_sprite(_lx - 16, _ly - 21, 128 + ((_tick >> 3) & 7));
                }
                break;
            case BuildingType.tower:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                draw_ocupation_flag(_building, _lx + 13, _ly - 18, 1);
                break;
            case BuildingType.fortress:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                draw_ocupation_flag(_building, _lx - 12, _ly - 21, 0.5);
                if (_building.has_knight()) {
                    draw_game_sprite(_lx + 22, _ly - 34 - (_building.get_knight_count() + 1) div 2,
                                     182 + (((_tick >> 3) + 2) & 3) +
                                     4 * _building.get_threat_level());
                }
                break;
            case BuildingType.gold_smelter:
                draw_shadow_and_building_sprite(_lx, _ly, global.viewport_map_building_sprite[_type], c_white);
                if (_building.is_active()) {
                    var _i = (_tick >> 3) & 7;
                    if (_i == 0 || (_i == 7 && !_building.is_playing_sfx())) {
                        _building.start_playing_sfx();
                        play_sound(Sfx.gold_boils);
                    } else if (_i != 7) {
                        _building.stop_playing_sfx();
                    }

                    draw_game_sprite(_lx - 7, _ly - 33, 128 + _i);
                }
                break;
            default:
                throw ("draw_unharmed_building: NOT_REACHED");
                break;
            }
        } else { /* unfinished building */
            if (_building.get_type() != BuildingType.castle) {
                draw_building_unfinished(_building, _building.get_type(), _lx, _ly);
            } else {
                draw_shadow_and_building_unfinished(_lx, _ly, 0xb2, _building.get_progress());
            }
        }
    };

    static draw_burning_building = function(_building, _lx, _ly) {
        var _building_anim_offset_from_type = global.viewport_building_anim_offset_from_type;
        var _building_burn_animation = global.viewport_building_burn_animation;

        /* Play sound effect. */
        if (((_building.get_burning_counter() >> 3) & 3) == 3 &&
            !_building.is_playing_sfx()) {
            _building.start_playing_sfx();
            play_sound(Sfx.burning);
        } else {
            _building.stop_playing_sfx();
        }

        var _delta = (interface.get_game().get_tick() - _building.get_tick()) & 0xFFFF;
        _building.set_tick(interface.get_game().get_tick());

        if (_building.get_burning_counter() >= _delta) {
            _building.decrease_burning_counter(_delta);  // TODO(jonls): this is also
                                                         // done in update_buildings().
            draw_unharmed_building(_building, _lx, _ly);

            var _type = 0;
            if (_building.is_done() ||
                _building.get_progress() >= 16000) {
                _type = _building.get_type();
            }

            var _offset = ((_building.get_burning_counter() >> 3) & 7) ^ 7;
            var _anim = _building_anim_offset_from_type[_type];
            while (_building_burn_animation[_anim] >= 0) {
                draw_game_sprite(_lx + _building_burn_animation[_anim + 1],
                                 _ly + _building_burn_animation[_anim + 2],
                                 136 + _building_burn_animation[_anim] + _offset);
                _offset = (_offset + 3) & 7;
                _anim += 3;
            }
        } else {
            _building.set_burning_counter(0);
        }
    };

    static draw_building = function(_pos, _lx, _ly) {
        var _building = interface.get_game().get_building_at_pos(_pos);

        if (_building.is_burning()) {
            draw_burning_building(_building, _lx, _ly);
        } else {
            draw_unharmed_building(_building, _lx, _ly);
        }
    };

    static draw_flag_and_res = function(_pos, _lx, _ly) {
        var _flag = interface.get_game().get_flag_at_pos(_pos);
        var _res_pos = global.viewport_res_pos;

        for (var _i = 0; _i < 3; _i++) {
            if (_flag.get_resource_at_slot(_i) != ResourceType.none) {
                draw_game_sprite(_lx + _res_pos[_i * 2], _ly + _res_pos[_i * 2 + 1],
                                 _flag.get_resource_at_slot(_i) + 1);
            }
        }

        var _pl_num = _flag.get_owner();
        var _player_color = get_player_colour(_pl_num);
        var _spr = 0x80 + ((interface.get_game().get_tick() >> 3) & 3);

        draw_shadow_and_building_sprite(_lx, _ly, _spr, _player_color);

        for (var _i = 3; _i < 8; _i++) {
            if (_flag.get_resource_at_slot(_i) != ResourceType.none) {
                draw_game_sprite(_lx + _res_pos[_i * 2], _ly + _res_pos[_i * 2 + 1],
                                 _flag.get_resource_at_slot(_i) + 1);
            }
        }
    };

    static draw_map_objects_row = function(_pos, _y_base, _cols, _x_base) {
        for (var _i = 0; _i < _cols; _i++) {
            var _obj = map.get_obj(_pos);
            if (_obj != MapObject.none) {
                var _ly = _y_base - 4 * map.get_height(_pos);
                if (_obj < MapObject.tree0) {
                    if (_obj == MapObject.flag) {
                        draw_flag_and_res(_pos, _x_base, _ly);
                    } else if (_obj <= MapObject.castle) {
                        draw_building(_pos, _x_base, _ly);
                    }
                } else {
                    var _sprite = _obj - MapObject.tree0;
                    if (_sprite < 24) {
                        // Trees: adding sprite number to animation de-synchronises them.
                        var _tree_anim = (interface.get_game().get_tick() + _sprite) >> 4;
                        if (_sprite < 16) {
                            _sprite = (_sprite & ~7) + (_tree_anim & 7);
                        } else {
                            _sprite = (_sprite & ~3) + (_tree_anim & 3);
                        }
                    }
                    draw_shadow_and_building_sprite(_x_base, _ly, _sprite, c_white);
                }
            }
            _x_base += MAP_TILE_WIDTH;
            _pos = map.geom.move_right(_pos);
        }
    };

    // ------------------------------------------------------------ serfs

    /* Draw one individual serf in the row. */
    static draw_row_serf = function(_lx, _ly, _shadow, _color, _body) {
        var _index1 = global.viewport_index1;
        var _index2 = global.viewport_index2;

        /* Shadow */
        if (_shadow) {
            draw_sprite(spr_serf_shadow, 0, _lx, _ly);
        }

        var _hi = ((_body >> 8) & 0xff) * 2;
        var _lo = (_body & 0xff) * 2;

        var _base = _index1[_hi];
        var _head = _index1[_hi + 1];

        if (_head < 0) {
            _base += _index2[_lo];
        } else {
            _base += _index2[_lo];
            _head += _index2[_lo + 1];
        }

        draw_serf(_lx, _ly, _color, _head, _base);
    };

    /* Extracted from obsolete update_map_serf_rows(). */
    /* Translate serf type into the corresponding sprite code. */
    static serf_get_body = function(_serf) {
        var _transporter_type = global.viewport_transporter_type;
        var _sailor_type = global.viewport_sailor_type;

        var _animation = get_animation(_serf.get_animation(), _serf.get_counter());
        var _t = _animation[0];

        switch (_serf.get_type()) {
        case SerfType.transporter:
        case SerfType.generic:
            if (_serf.get_state() == SerfState.idle_on_path) {
                return -1;
            } else if ((_serf.get_state() == SerfState.transporting ||
                        _serf.get_state() == SerfState.delivering) &&
                       _serf.get_delivery() != 0) {
                _t += _transporter_type[_serf.get_delivery()];
            }
            break;
        case SerfType.sailor:
            if (_serf.get_state() == SerfState.transporting && _t < 0x80) {
                if (((_t & 7) == 4 && !_serf.playing_sfx()) ||
                    (_t & 7) == 3) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.rowing);
                } else {
                    _serf.stop_playing_sfx();
                }
            }

            if ((_serf.get_state() == SerfState.transporting &&
                 _serf.get_delivery() == 0) ||
                _serf.get_state() == SerfState.lost_sailor ||
                _serf.get_state() == SerfState.free_sailing) {
                if (_t < 0x80) {
                    if (((_t & 7) == 4 && !_serf.playing_sfx()) ||
                        (_t & 7) == 3) {
                        _serf.start_playing_sfx();
                        play_sound(Sfx.rowing);
                    } else {
                        _serf.stop_playing_sfx();
                    }
                }
                _t += 0x200;
            } else if (_serf.get_state() == SerfState.transporting) {
                _t += _sailor_type[_serf.get_delivery()];
            } else {
                _t += 0x100;
            }
            break;
        case SerfType.digger:
            if (_t < 0x80) {
                _t += 0x300;
            } else if (_t == 0x83 || _t == 0x84) {
                if (_t == 0x83 || !_serf.playing_sfx()) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.digging);
                }
                _t += 0x380;
            } else {
                _serf.stop_playing_sfx();
                _t += 0x380;
            }
            break;
        case SerfType.builder:
            if (_t < 0x80) {
                _t += 0x500;
            } else if ((_t & 7) == 4 || (_t & 7) == 5) {
                if ((_t & 7) == 4 || !_serf.playing_sfx()) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.hammer_blow);
                }
                _t += 0x580;
            } else {
                _serf.stop_playing_sfx();
                _t += 0x580;
            }
            break;
        case SerfType.transporter_inventory:
            if (_serf.get_state() == SerfState.building_castle) {
                return -1;
            } else {
                var _res = _serf.get_delivery();
                _t += _transporter_type[_res];
            }
            break;
        case SerfType.lumberjack:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.free_walking &&
                    _serf.get_free_walking_neg_dist1() == -128 &&
                    _serf.get_free_walking_neg_dist2() == 1) {
                    _t += 0x1000;
                } else {
                    _t += 0xb00;
                }
            } else if ((_t == 0x86 && !_serf.playing_sfx()) ||
                       _t == 0x85) {
                _serf.start_playing_sfx();
                play_sound(Sfx.ax_blow);
                /* TODO Dangerous reference to unknown state vars.
                   It is probably free walking. */
                if (_serf.get_free_walking_neg_dist2() == 0 &&
                    _serf.get_counter() < 64) {
                    play_sound(Sfx.tree_fall);
                }
                _t += 0xe80;
            } else if (_t != 0x86) {
                _serf.stop_playing_sfx();
                _t += 0xe80;
            }
            break;
        case SerfType.sawmiller:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    _t += 0x1700;
                } else {
                    _t += 0xc00;
                }
            } else {
                /* player_num += 4; ??? */
                if (_t == 0xb3 || _t == 0xbb || _t == 0xc3 || _t == 0xcb ||
                    (!_serf.playing_sfx() && (_t == 0xb7 || _t == 0xbf ||
                                              _t == 0xc7 || _t == 0xcf))) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.sawing);
                } else if (_t != 0xb7 && _t != 0xbf && _t != 0xc7 && _t != 0xcf) {
                    _serf.stop_playing_sfx();
                }
                _t += 0x1580;
            }
            break;
        case SerfType.stonecutter:
            if (_t < 0x80) {
                if ((_serf.get_state() == SerfState.free_walking &&
                     _serf.get_free_walking_neg_dist1() == -128 &&
                     _serf.get_free_walking_neg_dist2() == 1) ||
                    (_serf.get_state() == SerfState.stone_cutting &&
                     _serf.get_free_walking_neg_dist1() == 2)) {
                    _t += 0x1200;
                } else {
                    _t += 0xd00;
                }
            } else if (_t == 0x85 || (_t == 0x86 && !_serf.playing_sfx())) {
                _serf.start_playing_sfx();
                play_sound(Sfx.pick_blow);
                _t += 0x1280;
            } else if (_t != 0x86) {
                _serf.stop_playing_sfx();
                _t += 0x1280;
            }
            break;
        case SerfType.forester:
            if (_t < 0x80) {
                _t += 0xe00;
            } else if (_t == 0x86 || (_t == 0x87 && !_serf.playing_sfx())) {
                _serf.start_playing_sfx();
                play_sound(Sfx.planting);
                _t += 0x1080;
            } else if (_t != 0x87) {
                _serf.stop_playing_sfx();
                _t += 0x1080;
            }
            break;
        case SerfType.miner:
            if (_t < 0x80) {
                if ((_serf.get_state() != SerfState.mining ||
                     _serf.get_mining_res() == 0) &&
                    (_serf.get_state() != SerfState.leaving_building ||
                     _serf.get_leaving_building_next_state() != SerfState.drop_resource_out)) {
                    _t += 0x1800;
                } else {
                    var _res = ResourceType.none;

                    switch (_serf.get_state()) {
                    case SerfState.mining:
                        _res = _serf.get_mining_res() - 1;
                        break;
                    case SerfState.leaving_building:
                        _res = _serf.get_leaving_building_field_B() - 1;
                        break;
                    default:
                        throw ("serf_get_body (miner): NOT_REACHED");
                        break;
                    }

                    switch (_res) {
                    case ResourceType.stone: _t += 0x2700; break;
                    case ResourceType.iron_ore: _t += 0x2500; break;
                    case ResourceType.coal: _t += 0x2600; break;
                    case ResourceType.gold_ore: _t += 0x2400; break;
                    default: throw ("serf_get_body (miner res): NOT_REACHED"); break;
                    }
                }
            } else {
                _t += 0x2a80;
            }
            break;
        case SerfType.smelter:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    if (_serf.get_leaving_building_field_B() == 1 + ResourceType.steel) {
                        _t += 0x2900;
                    } else {
                        _t += 0x2800;
                    }
                } else {
                    _t += 0x1900;
                }
            } else {
                /* edi10 += 4; */
                _t += 0x2980;
            }
            break;
        case SerfType.fisher:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.free_walking &&
                    _serf.get_free_walking_neg_dist1() == -128 &&
                    _serf.get_free_walking_neg_dist2() == 1) {
                    _t += 0x2f00;
                } else {
                    _t += 0x2c00;
                }
            } else {
                if (_t != 0x80 && _t != 0x87 && _t != 0x88 && _t != 0x8f) {
                    play_sound(Sfx.fishing_rod_reel);
                }

                /* TODO no check for state */
                if (_serf.get_free_walking_neg_dist2() == 1) {
                    _t += 0x2d80;
                } else {
                    _t += 0x2c80;
                }
            }
            break;
        case SerfType.pig_farmer:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    _t += 0x3400;
                } else {
                    _t += 0x3200;
                }
            } else {
                _t += 0x3280;
            }
            break;
        case SerfType.butcher:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    _t += 0x3a00;
                } else {
                    _t += 0x3700;
                }
            } else {
                /* edi10 += 4; */
                if ((_t == 0xb2 || _t == 0xba || _t == 0xc2 || _t == 0xca) &&
                    !_serf.playing_sfx()) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.backsword_blow);
                } else if (_t != 0xb2 && _t != 0xba && _t != 0xc2 && _t != 0xca) {
                    _serf.stop_playing_sfx();
                }
                _t += 0x3780;
            }
            break;
        case SerfType.farmer:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.free_walking &&
                    _serf.get_free_walking_neg_dist1() == -128 &&
                    _serf.get_free_walking_neg_dist2() == 1) {
                    _t += 0x4000;
                } else {
                    _t += 0x3d00;
                }
            } else {
                /* TODO access to state without state check */
                if (_serf.get_free_walking_neg_dist1() == 0) {
                    _t += 0x3d80;
                } else if (_t == 0x83 || (_t == 0x84 && !_serf.playing_sfx())) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.mowing);
                    _t += 0x3e80;
                } else if (_t != 0x83 && _t != 0x84) {
                    _serf.stop_playing_sfx();
                    _t += 0x3e80;
                }
            }
            break;
        case SerfType.miller:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    _t += 0x4500;
                } else {
                    _t += 0x4300;
                }
            } else {
                /* edi10 += 4; */
                _t += 0x4380;
            }
            break;
        case SerfType.baker:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    _t += 0x4a00;
                } else {
                    _t += 0x4800;
                }
            } else {
                /* edi10 += 4; */
                _t += 0x4880;
            }
            break;
        case SerfType.boat_builder:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    _t += 0x5000;
                } else {
                    _t += 0x4e00;
                }
            } else if (_t == 0x84 || _t == 0x85) {
                if (_t == 0x84 || !_serf.playing_sfx()) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.wood_hammering);
                }
                _t += 0x4e80;
            } else {
                _serf.stop_playing_sfx();
                _t += 0x4e80;
            }
            break;
        case SerfType.toolmaker:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    switch (_serf.get_leaving_building_field_B() - 1) {
                    case ResourceType.shovel: _t += 0x5a00; break;
                    case ResourceType.hammer: _t += 0x5b00; break;
                    case ResourceType.rod: _t += 0x5c00; break;
                    case ResourceType.cleaver: _t += 0x5d00; break;
                    case ResourceType.scythe: _t += 0x5e00; break;
                    case ResourceType.axe: _t += 0x6100; break;
                    case ResourceType.saw: _t += 0x6200; break;
                    case ResourceType.pick: _t += 0x6300; break;
                    case ResourceType.pincer: _t += 0x6400; break;
                    default: throw ("serf_get_body (toolmaker): NOT_REACHED"); break;
                    }
                } else {
                    _t += 0x5800;
                }
            } else {
                /* edi10 += 4; */
                if (_t == 0x83 || (_t == 0xb2 && !_serf.playing_sfx())) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.sawing);
                } else if (_t == 0x87 || (_t == 0xb6 && !_serf.playing_sfx())) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.wood_hammering);
                } else if (_t != 0xb2 && _t != 0xb6) {
                    _serf.stop_playing_sfx();
                }
                _t += 0x5880;
            }
            break;
        case SerfType.weapon_smith:
            if (_t < 0x80) {
                if (_serf.get_state() == SerfState.leaving_building &&
                    _serf.get_leaving_building_next_state() == SerfState.drop_resource_out) {
                    if (_serf.get_leaving_building_field_B() == 1 + ResourceType.sword) {
                        _t += 0x5500;
                    } else {
                        _t += 0x5400;
                    }
                } else {
                    _t += 0x5200;
                }
            } else {
                /* edi10 += 4; */
                if (_t == 0x83 || (_t == 0x84 && !_serf.playing_sfx())) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.metal_hammering);
                } else if (_t != 0x84) {
                    _serf.stop_playing_sfx();
                }
                _t += 0x5280;
            }
            break;
        case SerfType.geologist:
            if (_t < 0x80) {
                _t += 0x3900;
            } else if (_t == 0x83 || _t == 0x84 || _t == 0x86) {
                if (_t == 0x83 || !_serf.playing_sfx()) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.geologist_sampling);
                }
                _t += 0x4c80;
            } else if (_t == 0x8c || _t == 0x8d) {
                if (_t == 0x8c || !_serf.playing_sfx()) {
                    _serf.start_playing_sfx();
                    play_sound(Sfx.resource_found);
                }
                _t += 0x4c80;
            } else {
                _serf.stop_playing_sfx();
                _t += 0x4c80;
            }
            break;
        case SerfType.knight0:
        case SerfType.knight1:
        case SerfType.knight2:
        case SerfType.knight3:
        case SerfType.knight4: {
            var _k = _serf.get_type() - SerfType.knight0;

            if (_t < 0x80) {
                _t += 0x7800 + 0x100 * _k;
            } else if (_t < 0xc0) {
                if (_serf.get_state() == SerfState.knight_attacking ||
                    _serf.get_state() == SerfState.knight_attacking_free) {
                    if (_serf.get_counter() >= 24 || _serf.get_counter() < 8) {
                        _serf.stop_playing_sfx();
                    } else if (!_serf.playing_sfx()) {
                        _serf.start_playing_sfx();
                        if (_serf.get_attacking_field_D() == 0 ||
                            _serf.get_attacking_field_D() == 4) {
                            play_sound(Sfx.fight01);
                        } else if (_serf.get_attacking_field_D() == 2) {
                            /* TODO when is TypeSfxFight02 played? */
                            play_sound(Sfx.fight03);
                        } else {
                            play_sound(Sfx.fight04);
                        }
                    }
                }

                _t += 0x7cd0 + 0x200 * _k;
            } else {
                _t += 0x7d90 + 0x200 * _k;
            }
        }
            break;
        case SerfType.dead:
            if ((!_serf.playing_sfx() &&
                 (_t == 2 || _t == 5)) ||
                (_t == 1 || _t == 4)) {
                _serf.start_playing_sfx();
                play_sound(Sfx.serf_dying);
            } else {
                _serf.stop_playing_sfx();
            }
            _t += 0x8700;
            break;
        default:
            throw ("serf_get_body: NOT_REACHED");
            break;
        }

        return _t;
    };

    static draw_active_serf = function(_serf, _pos, _x_base, _y_base) {
        var _arr_4 = global.viewport_arr_4;

        if ((_serf.get_animation() < 0) || (_serf.get_animation() > 199) ||
            (_serf.get_counter() < 0)) {
            show_debug_message("viewport: bad animation for serf #" + string(_serf.get_index())
                               + " (" + string(_serf.get_state_name(_serf.get_state()))
                               + "): " + string(_serf.get_animation())
                               + "," + string(_serf.get_counter()));
            return;
        }

        var _animation = get_animation(_serf.get_animation(), _serf.get_counter());

        var _lx = _x_base + _animation[1];
        var _ly = _y_base + _animation[2] - 4 * map.get_height(_pos);
        var _body = serf_get_body(_serf);

        if (_body > -1) {
            var _color = get_player_colour(_serf.get_owner());
            /* "borntodie": the player's knights are drawn as soldiers, pulled
               back off the door during a fight so attacker and target are not
               overlapping. The offset is applied to the drawn position only -
               the serf's map position is untouched. */
            if (cf_is_soldier(_serf)) {
                cf_draw_soldier(_lx, _ly, _color, _serf);
            } else {
                draw_row_serf(_lx, _ly, true, _color, _body);
            }
            if ((layers & ViewportLayer.grid) != 0) {
                gfx_draw_number(_lx - global.gfx_ox, _ly - global.gfx_oy, _serf.get_index(), make_colour_rgb(0, 0, 128), -1);
                gfx_draw_string(_lx - global.gfx_ox, _ly - global.gfx_oy + 8, _serf.print_state(), make_colour_rgb(0, 0, 128), -1);
            }
        }

        /* Draw additional serf. Skipped for a serf the "borntodie" cheat is
           driving: a besieging soldier stays in knight_engaging_building for the
           whole assault and has no duel partner, so there is nothing to draw
           beside him. */
        if (!cf_in_siege(_serf) &&
           (_serf.get_state() == SerfState.knight_engaging_building ||
            _serf.get_state() == SerfState.knight_prepare_attacking ||
            _serf.get_state() == SerfState.knight_attacking ||
            _serf.get_state() == SerfState.knight_prepare_attacking_free ||
            _serf.get_state() == SerfState.knight_attacking_free ||
            _serf.get_state() == SerfState.knight_attacking_victory_free ||
            _serf.get_state() == SerfState.knight_attacking_defeat_free ||
            _serf.get_state() == SerfState.knight_attacking_victory)) {
            var _index = _serf.get_attacking_def_index();
            var _def_serf = undefined;
            if (_index != 0) {
                _def_serf = interface.get_game().get_serf(_index);
            }
            if (_def_serf != undefined) {
                var _danimation = get_animation(_def_serf.get_animation(), _def_serf.get_counter());

                var _dlx = _x_base + _danimation[1];
                var _dly = _y_base + _danimation[2] - 4 * map.get_height(_pos);
                var _dbody = serf_get_body(_def_serf);

                if (_dbody > -1) {
                    var _dcolor = get_player_colour(_def_serf.get_owner());
                    if (cf_is_soldier(_def_serf)) {
                        cf_draw_soldier(_dlx, _dly, _dcolor, _def_serf);
                    } else {
                        draw_row_serf(_dlx, _dly, true, _dcolor, _dbody);
                    }
                }
            }
        }

        /* Draw extra objects for fight. The sword-clash sparks are suppressed
           while "borntodie" is on - the tracers and grenades from
           scr_cheat_cf.gml stand in for them. */
        if ((_serf.get_state() == SerfState.knight_attacking ||
             _serf.get_state() == SerfState.knight_attacking_free) &&
            !cf_is_soldier(_serf) &&
            _animation[0] >= 0x80 && _animation[0] < 0xc0) {
            var _index = _serf.get_attacking_def_index();
            if (_index != 0) {
                var _def_serf = interface.get_game().get_serf(_index);

                if (_serf.get_animation() >= 146 && _serf.get_animation() < 156) {
                    if ((_serf.get_attacking_field_D() == 0 ||
                         _serf.get_attacking_field_D() == 4) &&
                        _serf.get_counter() < 32) {
                        var _anim = -1;
                        if (_serf.get_attacking_field_D() == 0) {
                            _anim = _serf.get_animation() - 147;
                        } else {
                            _anim = _def_serf.get_animation() - 147;
                        }

                        var _sprite = 198 + ((_serf.get_counter() >> 3) ^ 3);
                        draw_game_sprite(_lx + _arr_4[2 * _anim], _ly - _arr_4[2 * _anim + 1], _sprite);
                    }
                }
            }
        }
    };

    /* Draw one row of serfs. The serfs are composed of two or three transparent
       sprites (arm, torso, possibly head). A shadow is also drawn if appropriate.
       Note that idle serfs do not have their serf_t object linked from the map
       so they are drawn seperately from active serfs. */
    static draw_serf_row = function(_pos, _y_base, _cols, _x_base) {
        var _arr_1 = global.viewport_arr_1;
        var _arr_2 = global.viewport_arr_2;
        var _arr_3 = global.viewport_arr_3;

        for (var _i = 0; _i < _cols; _i++) {
            /* Active serf */
            if (map.has_serf(_pos)) {
                var _serf = interface.get_game().get_serf_at_pos(_pos);

                /* get_serf_at_pos heals a tile that points at a serf which is
                   gone, but it still hands back undefined for this frame. */
                if (_serf != undefined &&
                   (_serf.get_state() != SerfState.mining ||
                    (_serf.get_mining_substate() != 3 &&
                     _serf.get_mining_substate() != 4 &&
                     _serf.get_mining_substate() != 9 &&
                     _serf.get_mining_substate() != 10))) {
                    draw_active_serf(_serf, _pos, _x_base, _y_base);
                }
            }

            /* Idle serf */
            if (map.get_idle_serf(_pos)) {
                var _lx = 0;
                var _ly = 0;
                var _body = 0;
                if (map.is_in_water(_pos)) { /* Sailor */
                    _lx = _x_base;
                    _ly = _y_base - 4 * map.get_height(_pos);
                    _body = 0x203;
                } else { /* Transporter */
                    _lx = _x_base + _arr_3[2 * map.get_paths(_pos)];
                    _ly = _y_base - 4 * map.get_height(_pos) +
                          _arr_3[2 * map.get_paths(_pos) + 1];
                    _body = _arr_2[((interface.get_game().get_tick() +
                                     _arr_1[_pos & 0xf]) >> 3) & 0x7f];
                }

                var _color = get_player_colour(map.get_owner(_pos));
                draw_row_serf(_lx, _ly, true, _color, _body);
            }

            _x_base += MAP_TILE_WIDTH;
            _pos = map.move_right(_pos);
        }
    };

    /* Draw serfs that should appear behind the building at their
       current position. */
    static draw_serf_row_behind = function(_pos, _y_base, _cols, _x_base) {
        for (var _i = 0; _i < _cols; _i++) {
            /* Active serf */
            if (map.has_serf(_pos)) {
                var _serf = interface.get_game().get_serf_at_pos(_pos);

                if (_serf != undefined &&
                    _serf.get_state() == SerfState.mining &&
                    (_serf.get_mining_substate() == 3 ||
                     _serf.get_mining_substate() == 4 ||
                     _serf.get_mining_substate() == 9 ||
                     _serf.get_mining_substate() == 10)) {
                    draw_active_serf(_serf, _pos, _x_base, _y_base);
                }
            }

            _x_base += MAP_TILE_WIDTH;
            _pos = map.move_right(_pos);
        }
    };

    static draw_game_objects = function(_layers, _ox, _oy) {
        var _draw_landscape = (_layers & ViewportLayer.landscape) != 0;
        var _draw_objects = (_layers & ViewportLayer.objects) != 0;
        var _draw_serfs = (_layers & ViewportLayer.serfs) != 0;
        if (!_draw_landscape && !_draw_objects && !_draw_serfs) {
            return;
        }
        var _cols = (2 * (width div MAP_TILE_WIDTH) + 1);
        var _short_row_len = ((_cols + 1) >> 1) + 1;
        var _long_row_len = ((_cols + 2) >> 1) + 1;

        var _lx = -((offset_x + 16 * (offset_y div 20)) mod 32);
        var _ly = -(offset_y mod 20);

        var _col_0 = ((offset_x div 16 + offset_y div 20) div 2) & map.geom.col_mask;
        var _row_0 = (offset_y div MAP_TILE_HEIGHT) & map.geom.row_mask;
        var _pos = map.geom.pos(_col_0, _row_0);

        while (true) {
            // short row
            if (_draw_landscape) {
                draw_water_waves_row(_pos, _oy + _ly, _short_row_len, _ox + _lx);
            }
            if (_draw_serfs) {
                draw_serf_row_behind(_pos, _oy + _ly, _short_row_len, _ox + _lx);
            }
            if (_draw_objects) {
                draw_map_objects_row(_pos, _oy + _ly, _short_row_len, _ox + _lx);
            }
            if (_draw_serfs) {
                draw_serf_row(_pos, _oy + _ly, _short_row_len, _ox + _lx);
            }
            _ly += MAP_TILE_HEIGHT;
            if (_ly >= height + 6 * MAP_TILE_HEIGHT) {
                break;
            }
            _pos = map.geom.move_down(_pos);

            // long row
            if (_draw_landscape) {
                draw_water_waves_row(_pos, _oy + _ly, _long_row_len, _ox + _lx - 16);
            }
            if (_draw_serfs) {
                draw_serf_row_behind(_pos, _oy + _ly, _long_row_len, _ox + _lx - 16);
            }
            if (_draw_objects) {
                draw_map_objects_row(_pos, _oy + _ly, _long_row_len, _ox + _lx - 16);
            }
            if (_draw_serfs) {
                draw_serf_row(_pos, _oy + _ly, _long_row_len, _ox + _lx - 16);
            }
            _ly += MAP_TILE_HEIGHT;
            if (_ly >= height + 6 * MAP_TILE_HEIGHT) {
                break;
            }
            _pos = map.geom.move_down_right(_pos);
        }

        /* "borntodie": muzzle flashes, tracers, grenades, blasts and burning
           buildings, drawn last so they sit over everything. */
        if (_draw_serfs) {
            var _vp = self;
            cf_fx_draw(_vp, _ox, _oy);
        }
    };

    // ------------------------------------------------------------ cursor

    static draw_map_cursor_sprite = function(_pos, _sprite, _ox, _oy) {
        var _s = screen_pix_from_map_coord(_pos);
        draw_game_sprite(_ox + _s[0], _oy + _s[1], _sprite);
    };

    // Viewport::draw_map_cursor_possible_build(). Local coordinates
    // (draw_game_sprite takes screen coordinates, so the gfx origin is added).
    static draw_map_cursor_possible_build = function() {
        var _off = get_offset();
        var _x_off = _off[0];
        var _y_off = _off[1];
        var _base_pos = _off[4];

        var _game = interface.get_game();

        for (var _x_base = _x_off; _x_base < width + MAP_TILE_WIDTH; _x_base += MAP_TILE_WIDTH) {
            var _pos = _base_pos;
            var _y_base = _y_off;
            var _row = 0;

            while (true) {
                var _lx = 0;
                if (_row mod 2 == 0) {
                    _lx = _x_base;
                } else {
                    _lx = _x_base - MAP_TILE_WIDTH div 2;
                }

                var _ly = _y_base - 4 * map.get_height(_pos);
                if (_ly >= height) {
                    break;
                }

                /* Draw possible building */
                var _sprite = -1;
                if (_game.can_build_castle(_pos, interface.get_player())) {
                    _sprite = 50;
                } else if (_game.can_player_build(_pos, interface.get_player()) &&
                           global.map_space_from_obj[map.get_obj(_pos)] == Space.open &&
                           (_game.can_build_flag(map.move_down_right(_pos), interface.get_player()) ||
                            map.has_flag(map.move_down_right(_pos)))) {
                    if (_game.can_build_mine(_pos)) {
                        _sprite = 48;
                    } else if (_game.can_build_large(_pos)) {
                        _sprite = 50;
                    } else if (_game.can_build_small(_pos)) {
                        _sprite = 49;
                    }
                }

                if (_sprite >= 0) {
                    draw_game_sprite(global.gfx_ox + _lx, global.gfx_oy + _ly, _sprite);
                }

                if (_row mod 2 == 0) {
                    _pos = map.move_down(_pos);
                } else {
                    _pos = map.move_down_right(_pos);
                }

                _y_base += MAP_TILE_HEIGHT;
                _row += 1;
            }

            _base_pos = map.move_right(_base_pos);
        }
    };

    // Viewport::draw_map_cursor(). (_ox, _oy) = screen origin of the viewport.
    static draw_map_cursor = function(_ox, _oy) {
        if ((layers & ViewportLayer.builds) != 0) {
            draw_map_cursor_possible_build();
        }

        var _pos = interface.get_map_cursor_pos();

        draw_map_cursor_sprite(_pos, interface.get_map_cursor_sprite(0), _ox, _oy);

        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            draw_map_cursor_sprite(map.move(_pos, _d), interface.get_map_cursor_sprite(1 + _d), _ox, _oy);
        }
    };

    // ------------------------------------------------------------ grid overlays
    // Local coordinates through the gfx helpers.

    static draw_base_grid_overlay = function(_color) {
        var _off = get_offset();
        var _x_base = _off[0];
        var _y_base = _off[1];

        var _row = 0;
        for (var _ly = _y_base; _ly < height; _ly += MAP_TILE_HEIGHT) {
            gfx_draw_line(0, _ly, width, _ly, _color);
            var _lx_start = _x_base;
            if (_row mod 2 != 0) {
                _lx_start = _x_base - MAP_TILE_WIDTH div 2;
            }
            for (var _lx = _lx_start; _lx < width; _lx += MAP_TILE_WIDTH) {
                gfx_draw_line(_lx, _ly - 3, _lx, _ly + 3, _color);
            }
            _row += 1;
        }
    };

    static draw_height_grid_overlay = function(_color) {
        var _off = get_offset();
        var _x_off = _off[0];
        var _y_off = _off[1];
        var _base_pos = _off[4];

        for (var _x_base = _x_off; _x_base < width + MAP_TILE_WIDTH; _x_base += MAP_TILE_WIDTH) {
            var _pos = _base_pos;
            var _y_base = _y_off;
            var _row = 0;

            while (true) {
                var _lx = 0;
                if (_row mod 2 == 0) {
                    _lx = _x_base;
                } else {
                    _lx = _x_base - MAP_TILE_WIDTH div 2;
                }

                var _ly = _y_base - 4 * map.get_height(_pos);
                if (_ly >= height) {
                    break;
                }

                /* Draw cross. */
                if (_pos != map.pos(0, 0)) {
                    gfx_fill_rect(_lx, _ly - 1, 1, 3, _color);
                    gfx_fill_rect(_lx - 1, _ly, 3, 1, _color);
                } else {
                    gfx_fill_rect(_lx, _ly - 2, 1, 5, _color);
                    gfx_fill_rect(_lx - 2, _ly, 5, 1, _color);
                }

                if (_row mod 2 == 0) {
                    _pos = map.move_down(_pos);
                } else {
                    _pos = map.move_down_right(_pos);
                }

                _y_base += MAP_TILE_HEIGHT;
                _row += 1;
            }

            _base_pos = map.move_right(_base_pos);
        }
    };

    // ------------------------------------------------------------ draw

    /// Viewport::internal_draw(). GuiObject.draw() has already set the gfx
    /// origin (global.gfx_ox/gfx_oy) to this object's screen position.
    static internal_draw = function() {
        if (map == undefined) {
            return;
        }

        var _ox = global.gfx_ox;
        var _oy = global.gfx_oy;

        if ((layers & ViewportLayer.landscape) != 0) {
            draw_landscape(_ox, _oy);
        }
        if ((layers & ViewportLayer.grid) != 0) {
            draw_base_grid_overlay(make_colour_rgb(0xcf, 0x63, 0x63));
            draw_height_grid_overlay(make_colour_rgb(0xef, 0xef, 0x8f));
        }
        if ((layers & ViewportLayer.paths) != 0) {
            draw_paths_and_borders();
        }
        draw_game_objects(layers, _ox, _oy);
        if ((layers & ViewportLayer.cursor) != 0) {
            draw_map_cursor(_ox, _oy);
        }
    };

    /// Old-style entry point: draw the viewport with its top-left at screen
    /// position (_ox, _oy) without going through the GuiObject hierarchy.
    static draw_at = function(_ox, _oy) {
        gfx_set_origin(_ox, _oy);
        internal_draw();
    };

    /// GuiObject::draw(Frame*) for the viewport: render into our own frame only
    /// when `redraw` is set, then blit it. Overrides GuiObject.draw.
    static draw = function() {
        if (!displayed || width <= 0 || height <= 0 || map == undefined) {
            return;
        }

        var _saved_ox = global.gfx_ox;
        var _saved_oy = global.gfx_oy;

        var _pos = get_screen_position();

        // Build missing landscape tiles first (no nested render targets).
        prepare_landscape_tiles();

        if (!surface_exists(frame_surface)) {
            frame_surface = surface_create(width, height);
            redraw = true;
        }

        if (redraw) {
            surface_set_target(frame_surface);
            draw_clear(c_black);
            gfx_set_origin(0, 0);
            internal_draw();
            surface_reset_target();
            redraw = false;
        }

        gfx_set_origin(0, 0);
        if (zoom == 1) {
            draw_surface(frame_surface, _pos[0], _pos[1]);
        } else {
            draw_surface_ext(frame_surface, _pos[0], _pos[1], zoom, zoom,
                             0, c_white, 1);
        }

        // Floats (the viewport has none in Freeserf, but keep the contract).
        var _n = array_length(floats);
        for (var _i = 0; _i < _n; _i++) {
            var _fl = floats[_i];
            if (_fl.obj.is_displayed()) {
                _fl.obj.draw();
            }
        }

        gfx_set_origin(_saved_ox, _saved_oy);
    };

    // ------------------------------------------------------------ events

    /// Pointer events arrive in screen pixels. The map renders at the logical
    /// size, so divide the position and any drag delta by the zoom before
    /// GuiObject's bounds check and the handlers below see them.
    static handle_event = function(_event) {
        if (zoom == 1) {
            return gui_handle_event(_event);
        }

        if (_event.type != EventType.click &&
            _event.type != EventType.dbl_click &&
            _event.type != EventType.drag) {
            return gui_handle_event(_event);
        }

        var _dx = _event.dx;
        var _dy = _event.dy;

        if (_event.type == EventType.drag) {
            // Whole map pixels only, remainder carried (see drag_carry_x).
            // floor() rather than div so the carry stays positive and the sign
            // is handled the same dragging either way.
            var _rest_x = _event.dx + drag_carry_x;
            var _rest_y = _event.dy + drag_carry_y;
            _dx = floor(_rest_x / zoom);
            _dy = floor(_rest_y / zoom);
            drag_carry_x = _rest_x - _dx * zoom;
            drag_carry_y = _rest_y - _dy * zoom;
        }

        var _scaled = gui_make_event(_event.type,
                                     x + (_event.x - x) div zoom,
                                     y + (_event.y - y) div zoom,
                                     _dx,
                                     _dy,
                                     _event.button);
        return gui_handle_event(_scaled);
    };

    /// bool handle_click_left(int lx, int ly)
    static handle_click_left = function(_lx, _ly) {
        set_redraw();

        var _clk_pos = map_pos_from_screen_pix(_lx, _ly);

        if (interface.is_building_road()) {
            var _dx = -map.dist_x(interface.get_map_cursor_pos(), _clk_pos) + 1;
            var _dy = -map.dist_y(interface.get_map_cursor_pos(), _clk_pos) + 1;
            var _dir = Direction.none;

            if (_dx == 0) {
                if (_dy == 1) {
                    _dir = Direction.left;
                } else if (_dy == 0) {
                    _dir = Direction.up_left;
                } else {
                    return false;
                }
            } else if (_dx == 1) {
                if (_dy == 2) {
                    _dir = Direction.down;
                } else if (_dy == 0) {
                    _dir = Direction.up;
                } else {
                    return false;
                }
            } else if (_dx == 2) {
                if (_dy == 1) {
                    _dir = Direction.right;
                } else if (_dy == 2) {
                    _dir = Direction.down_right;
                } else {
                    return false;
                }
            } else {
                return false;
            }

            if (interface.build_road_is_valid_dir(_dir)) {
                var _road = interface.get_building_road();
                if (_road.is_undo(_dir)) {
                    /* Delete existing path */
                    var _r = interface.remove_road_segment();
                    if (_r < 0) {
                        play_sound(Sfx.not_accepted);
                    } else {
                        play_sound(Sfx.click);
                    }
                } else {
                    /* Build new road segment */
                    var _r = interface.build_road_segment(_dir);
                    if (_r < 0) {
                        play_sound(Sfx.not_accepted);
                    } else if (_r == 0) {
                        play_sound(Sfx.click);
                    } else {
                        play_sound(Sfx.accepted);
                    }
                }
            }
        } else {
            interface.update_map_cursor_pos(_clk_pos);
            play_sound(Sfx.click);
        }

        return true;
    };

    /// bool handle_dbl_click(int lx, int ly, Event::Button button)
    /// Both mouse buttons on one of your own flags sends a geologist to it,
    /// as in the original. Useful on a mountain, where the geologist surveys
    /// for ore; harmless anywhere else, and the game refuses if it cannot
    /// spare one.
    static handle_click_middle = function(_lx, _ly) {
        var _player = interface.get_player();
        if (_player == undefined) {
            return false;
        }

        var _clk_pos = map_pos_from_screen_pix(_lx, _ly);

        if (map.get_obj(_clk_pos) != MapObject.flag) {
            return false;
        }
        if (map.get_owner(_clk_pos) != _player.get_index()) {
            return false;
        }

        var _game = interface.get_game();
        if (_game == undefined) {
            return false;
        }

        var _flag = _game.get_flag_at_pos(_clk_pos);
        if (_flag == undefined) {
            return false;
        }

        /* Confirm first. The popup reads the flag back off the map cursor, so
           move the cursor there before opening it. */
        interface.update_map_cursor_pos(_clk_pos);
        set_redraw();
        interface.open_popup(PopupType.send_geologist_confirm);

        return true;
    };

    static handle_dbl_click = function(_lx, _ly, _button) {
        if (_button != EventButton.left) {
            return false;
        }

        set_redraw();

        var _player = interface.get_player();

        var _clk_pos = map_pos_from_screen_pix(_lx, _ly);

        if (interface.is_building_road()) {
            if (_clk_pos != interface.get_map_cursor_pos()) {
                var _pos = interface.get_building_road().get_end(map);
                var _road = pathfinder_map(map, _pos, _clk_pos, interface.get_building_road());
                if (_road.get_length() != 0) {
                    var _r = interface.extend_road(_road);
                    if (_r < 0) {
                        play_sound(Sfx.not_accepted);
                    } else if (_r == 1) {
                        play_sound(Sfx.accepted);
                    } else {
                        play_sound(Sfx.click);
                    }
                } else {
                    play_sound(Sfx.not_accepted);
                }
            } else {
                var _r = interface.get_game().build_flag(interface.get_map_cursor_pos(), _player);
                if (_r) {
                    interface.build_road();
                } else {
                    play_sound(Sfx.not_accepted);
                }
            }
        } else {
            /* Fast building click: the first click already moved the cursor and
               refreshed the panel, so a second click on a spot showing a build
               possibility icon can just press the panel's build button. That
               picks basic_bld / basic_bld_flip / mine_building / flag / castle
               to match the possibility, exactly as clicking the button does. */
            if (global.fast_building_click &&
                interface.get_build_possibility() != BuildPossibility.none) {
                var _panel = interface.get_panel_bar();
                if (_panel != undefined) {
                    _panel.button_click(0);
                    return true;
                }
            }

            if (map.get_obj(_clk_pos) == MapObject.none ||
                map.get_obj(_clk_pos) > MapObject.castle) {
                return false;
            }

            if (map.get_obj(_clk_pos) == MapObject.flag) {
                if (map.get_owner(_clk_pos) == _player.get_index()) {
                    /* Fast map click: start a road from this flag rather than
                       opening the transport info popup. */
                    if (global.fast_map_click) {
                        interface.build_road_begin();
                    } else {
                        interface.open_popup(PopupType.transport_info);
                    }
                }

                _player.temp_index = map.get_obj_index(_clk_pos);
            } else { /* Building */
                var _building = interface.get_game().get_building_at_pos(_clk_pos);
                if ((_building == undefined) || _building.is_burning()) {
                    return false;
                }
                if (map.get_owner(_clk_pos) == _player.get_index()) {
                    if (!_building.is_done()) {
                        interface.open_popup(PopupType.ordered_bld);
                    } else if (_building.get_type() == BuildingType.castle) {
                        interface.open_popup(PopupType.castle_res);
                    } else if (_building.get_type() == BuildingType.stock) {
                        if (!_building.is_active()) {
                            return false;
                        }
                        interface.open_popup(PopupType.castle_res);
                    } else if (_building.get_type() == BuildingType.hut ||
                               _building.get_type() == BuildingType.tower ||
                               _building.get_type() == BuildingType.fortress) {
                        interface.open_popup(PopupType.defenders);
                    } else if (_building.get_type() == BuildingType.stone_mine ||
                               _building.get_type() == BuildingType.coal_mine ||
                               _building.get_type() == BuildingType.iron_mine ||
                               _building.get_type() == BuildingType.gold_mine) {
                        interface.open_popup(PopupType.mine_output);
                    } else {
                        interface.open_popup(PopupType.bld_stock);
                    }

                    _player.temp_index = map.get_obj_index(_clk_pos);
                } else { /* Foreign building */
                    /* TODO handle coop mode*/
                    _player.building_attacked = _building.get_index();

                    if (_building.is_done() &&
                        _building.is_military()) {
                        if (!_building.is_active() ||
                            _building.get_threat_level() != 3) {
                            /* It is not allowed to attack
                               if currently not occupied or
                               is too far from the border. */
                            if (!_building.is_active()) {
                                show_debug_message("attack refused: that building has no knight in it yet");
                            } else {
                                show_debug_message("attack refused: threat level " +
                                                   string(_building.get_threat_level()) +
                                                   ", needs 3 - it is not on the border with you");
                            }
                            play_sound(Sfx.not_accepted);
                            return false;
                        }

                        var _found = 0;
                        for (var _i = 257; _i >= 0; _i--) {
                            var _spos = map.pos_add_spirally(_building.get_position(), 7 + 257 - _i);
                            if (map.has_owner(_spos)
                                && map.get_owner(_spos) == _player.get_index()) {
                                _found = 1;
                                break;
                            }
                        }

                        if (_found == 0) {
                            show_debug_message("attack refused: none of your land is close enough to it");
                            play_sound(Sfx.not_accepted);
                            return false;
                        }

                        /* Action accepted */
                        play_sound(Sfx.click);

                        var _max_knights = 0;
                        switch (_building.get_type()) {
                        case BuildingType.hut: _max_knights = 3; break;
                        case BuildingType.tower: _max_knights = 6; break;
                        case BuildingType.fortress: _max_knights = 12; break;
                        case BuildingType.castle: _max_knights = 20; break;
                        default: throw ("handle_dbl_click: NOT_REACHED"); break;
                        }

                        var _knights = _player.knights_available_for_attack(_building.get_position());
                        _player.knights_attacking = min(_knights, _max_knights);
                        interface.open_popup(PopupType.start_attack);
                    }
                }
            }
        }

        return false;
    };

    /// bool handle_drag(int lx, int ly)
    static handle_drag = function(_dx, _dy) {
        if (_dx != 0 || _dy != 0) {
            // Default (Invert = No) grabs the ground: the map travels with the
            // pointer, so the pixel under the cursor stays under it. Inverted is
            // Freeserf's original, where the drag pushes the view and the map
            // slides against the hand. That is the whole difference - the two
            // are the same movement with opposite signs, which is why one
            // setting covers it.
            var _sign = -1;
            if (global.map_drag_invert) {
                _sign = 1;
            }
            move_by_pixels(_sign * _dx, _sign * _dy);
        }

        return true;
    };

    /* Called periodically when the game progresses. */
    static update = function() {
        var _tick_xor = interface.get_game().get_tick() ^ last_tick;
        last_tick = interface.get_game().get_tick();

        /* Viewport animation does not care about low bits in anim */
        if (_tick_xor >= (1 << 3)) {
            set_redraw();
        }
    };

    // ------------------------------------------------------------ coordinates

    static get_offset = function() {
        // returns [x_off, y_off, col, row, pos]
        var _x_off = -((offset_x + 16 * (offset_y div 20)) mod 32);
        var _y_off = -(offset_y mod 20);
        var _col_0 = ((offset_x div 16 + offset_y div 20) div 2) & map.geom.col_mask;
        var _row_0 = (offset_y div MAP_TILE_HEIGHT) & map.geom.row_mask;
        return [_x_off, _y_off, _col_0, _row_0, map.geom.pos(_col_0, _row_0)];
    };

    static screen_pix_from_map_pix = function(_mx, _my) {
        var _lwidth = map.geom.cols * MAP_TILE_WIDTH;
        var _lheight = map.geom.rows * MAP_TILE_HEIGHT;
        var _sx = _mx - offset_x;
        var _sy = _my - offset_y;
        while (_sy < 0) {
            _sx -= (map.geom.rows * MAP_TILE_WIDTH) div 2;
            _sy += _lheight;
        }
        while (_sy >= _lheight) {
            _sx += (map.geom.rows * MAP_TILE_WIDTH) div 2;
            _sy -= _lheight;
        }
        while (_sx < 0) {
            _sx += _lwidth;
        }
        while (_sx >= _lwidth) {
            _sx -= _lwidth;
        }
        return [_sx, _sy];
    };

    static map_pix_from_map_coord = function(_pos, _h) {
        var _lwidth = map.geom.cols * MAP_TILE_WIDTH;
        var _lheight = map.geom.rows * MAP_TILE_HEIGHT;
        var _mx = MAP_TILE_WIDTH * map.geom.pos_col(_pos) - (MAP_TILE_WIDTH div 2) * map.geom.pos_row(_pos);
        var _my = MAP_TILE_HEIGHT * map.geom.pos_row(_pos) - 4 * _h;
        if (_my < 0) {
            _mx -= (map.geom.rows * MAP_TILE_WIDTH) div 2;
            _my += _lheight;
        }
        if (_mx < 0) {
            _mx += _lwidth;
        } else if (_mx >= _lwidth) {
            _mx -= _lwidth;
        }
        return [_mx, _my];
    };

    static screen_pix_from_map_coord = function(_pos) {
        var _h = map.get_height(_pos);
        var _mp = map_pix_from_map_coord(_pos, _h);
        return screen_pix_from_map_pix(_mp[0], _mp[1]);
    };

    static map_pos_from_screen_pix = function(_sx, _sy) {
        var _off = get_offset();
        var _col = _off[2];
        var _row = _off[3];
        _sx -= _off[0];
        _sy -= _off[1];

        var _y_base = -4;
        var _col_offset = (_sx + 24) >> 5;
        if (((_sx + 24) & (1 << 4)) == 0) {
            _row += 1;
            _y_base = 16;
        }
        _col = (_col + _col_offset) & map.geom.col_mask;
        _row = _row & map.geom.row_mask;

        var _ly = 0;
        var _last_y = -100;
        while (true) {
            _ly = _y_base - 4 * map.get_height(map.geom.pos(_col, _row));
            if (_sy < _ly) {
                break;
            }
            _last_y = _ly;
            _col = (_col + 1) & map.geom.col_mask;
            _row = (_row + 2) & map.geom.row_mask;
            _y_base += 2 * MAP_TILE_HEIGHT;
        }
        if (_sy < (_ly + _last_y) div 2) {
            _col = (_col - 1) & map.geom.col_mask;
            _row = (_row - 2) & map.geom.row_mask;
        }
        return map.geom.pos(_col, _row);
    };

    static get_current_map_pos = function() {
        return map_pos_from_screen_pix(width div 2, height div 2);
    };

    static move_to_map_pos = function(_pos) {
        var _mp = map_pix_from_map_coord(_pos, map.get_height(_pos));
        var _mx = _mp[0];
        var _my = _mp[1];
        var _map_width = map.geom.cols * MAP_TILE_WIDTH;
        var _map_height = map.geom.rows * MAP_TILE_HEIGHT;
        _mx -= width div 2;
        _my -= height div 2;
        if (_my < 0) {
            _mx -= (map.geom.rows * MAP_TILE_WIDTH) div 2;
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

    static move_by_pixels = function(_lx, _ly) {
        var _lwidth = map.geom.cols * MAP_TILE_WIDTH;
        var _lheight = map.geom.rows * MAP_TILE_HEIGHT;
        offset_x += _lx;
        offset_y += _ly;
        if (offset_y < 0) {
            offset_y += _lheight;
            offset_x -= (map.geom.rows * MAP_TILE_WIDTH) div 2;
        } else if (offset_y >= _lheight) {
            offset_y -= _lheight;
            offset_x += (map.geom.rows * MAP_TILE_WIDTH) div 2;
        }
        if (offset_x >= _lwidth) {
            offset_x -= _lwidth;
        } else if (offset_x < 0) {
            offset_x += _lwidth;
        }

        set_redraw();
    };

    // Map change handler interface (Map::Handler)
    static on_height_changed = function(_pos) {
        redraw_map_pos(_pos);
    };
    static on_object_changed = function(_pos) {
        if (interface.get_map_cursor_pos() == _pos) {
            interface.update_map_cursor_pos(_pos);
        }
    };

    // Viewport::Viewport(): map->add_change_handler(this);
    map.add_change_handler(self);
}
