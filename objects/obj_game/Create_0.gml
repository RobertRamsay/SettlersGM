/// obj_game Create - top-level controller: port of Freeserf's main loop
/// (src/freeserf.cc + src/event_loop-sdl.cc) driving the Interface.
#macro SCREEN_W 640
#macro SCREEN_H 400
#macro SCREEN_SCALE 2
// Game updates are driven by elapsed milliseconds, not frames: Freeserf's
// event loop fires its update timer every TICK_LENGTH_MS (20 ms) = 50 ticks per
// second, independently of the render rate (see src/event_loop-sdl.cc).
#macro MAX_CATCHUP_TICKS 5
#macro MOUSE_TIME_SENSITIVITY 600
#macro MOUSE_MOVE_SENSITIVITY 8

// Assets / lookup tables
sprite_meta_init();
gfx_init();
gui_init_globals();
audio_init();

// Window: integer-scaled, pixel-perfect
window_set_size(SCREEN_W * SCREEN_SCALE, SCREEN_H * SCREEN_SCALE);
surface_resize(application_surface, SCREEN_W, SCREEN_H);
display_set_gui_size(SCREEN_W, SCREEN_H);
gpu_set_texfilter(false);
camera_set_view_size(view_camera[0], SCREEN_W, SCREEN_H);
alarm[0] = 1;   // centre window next frame (size change must settle first)

// Game: Tutorial 1 from the mission table (player 0 = "You", no castle yet —
// the castle is placed by the player, exactly like the original).
mission_info = game_info_get_tutorial(0);
game = new Game();
mission_info.instantiate(game);

// Interface (Freeserf Interface : GuiObject) — owns viewport, panel, popups
interface = new Interface(game);
interface.set_size(SCREEN_W, SCREEN_H);
interface.set_displayed(true);
interface.set_enabled(true);
interface.get_viewport().move_to_map_pos(game.get_map().pos(game.get_map().geom.cols div 2, game.get_map().geom.rows div 2));
interface.update_map_cursor_pos(interface.get_viewport().get_current_map_pos());

// Input state (event_loop-sdl.cc)
tick_accumulator = 0;
drag_button = 0;
drag_x = 0;
drag_y = 0;
last_click_time = array_create(4, -100000);
last_click_x = 0;
last_click_y = 0;

// An Amiga mouse has two buttons, so "both buttons" is its own input in The
// Settlers. Left+right held together is reported as a middle click, and the
// left/right clicks that follow are swallowed so the build popup does not open
// as well. Index 0 is unused; 1 = left, 2 = middle, 3 = right.
both_buttons_active = false;
suppress_click = array_create(4, false);

// The original had these two as options-popup toggles. Freeserf only ever
// declared the enum entries (ACTION_OPTIONS_FAST_MAP_CLICK_1/2,
// ACTION_OPTIONS_FAST_BUILDING_1/2) and never handled them, so they are globals
// here, ready for the options popup to drive once those buttons are wired.
global.fast_map_click = true;       // dbl-click own flag -> start a road there
global.fast_building_click = true;  // dbl-click a build spot -> that build popup
show_debug = false;
settlers_play_music();
