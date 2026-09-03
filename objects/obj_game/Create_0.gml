/// obj_game Create - top-level controller: port of Freeserf's main loop
/// (src/freeserf.cc + src/event_loop-sdl.cc) driving the Interface.
#macro SCREEN_W 640
#macro SCREEN_H 400
#macro SCREEN_SCALE 2
// 60 fps / 3 = 20 game ticks per second (Freeserf TICKS_PER_SEC)
#macro FRAMES_PER_TICK 3
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
frame_counter = 0;
drag_button = 0;
drag_x = 0;
drag_y = 0;
last_click_time = array_create(4, -100000);
last_click_x = 0;
last_click_y = 0;
show_debug = false;
audio_play_music();
