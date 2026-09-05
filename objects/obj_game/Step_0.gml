/// obj_game Step - event loop (port of event_loop-sdl.cc) + fixed-rate game ticks

// ---- game ticks: one update per TICK_LENGTH_MS of real time (50 Hz)
tick_accumulator += delta_time / 1000;   // delta_time is microseconds
var _ticks = tick_accumulator div TICK_LENGTH_MS;
if (_ticks > MAX_CATCHUP_TICKS) {
    _ticks = MAX_CATCHUP_TICKS;          // never spiral after a stall
    tick_accumulator = 0;
} else {
    tick_accumulator -= _ticks * TICK_LENGTH_MS;
}
for (var _t = 0; _t < _ticks; _t++) {
    interface.handle_event(gui_make_event(EventType.update, 0, 0, 0, 0, 0));
    // "borntodie" effects age on the game tick, so tracers and flames keep
    // pace with the fight that spawned them at every game speed.
    cf_fx_update();
}

// ---- a queued game switch runs here, never inside event dispatch
interface.apply_pending_game();

// ---- F12 dumps the save slot state to the output log
if (keyboard_check_pressed(vk_f12)) {
    var _box = interface.get_game_init_box();
    if (_box != undefined) {
        _box.dump_save_state();
    } else {
        show_debug_message("--- savegame state (no start screen open) ---");
        for (var _i = 0; _i < SAVEGAME_SLOTS; _i++) {
            show_debug_message("  slot " + string(_i) + ": " + savegame_slot_path(_i) +
                               " exists=" + string(file_exists(savegame_slot_path(_i))) +
                               " label=" + savegame_slot_label(_i));
        }
        show_debug_message("last load error: '" + savegame_last_error() + "'");
    }
}

// ---- save / load, until the slot UI lands
// F1..F10 pick the slot, F5 saves to it, F9 loads it, F11 runs the round-trip
// self test and reports to the output log.
for (var _s = 0; _s < SAVEGAME_SLOTS; _s++) {
    if (keyboard_check_pressed(vk_f1 + _s) && _s != 4 && _s != 8) {
        global.save_slot = _s;
        show_debug_message("savegame: slot " + string(_s) + " selected");
    }
}

if (keyboard_check_pressed(vk_f5)) {
    savegame_save_slot(global.save_slot, interface.get_game());
}

if (keyboard_check_pressed(vk_f9)) {
    var _loaded = savegame_load_slot(global.save_slot);
    if (_loaded == undefined) {
        show_debug_message("savegame: slot " + string(global.save_slot) + " did not load");
    } else {
        interface.set_game(_loaded);
        show_debug_message("savegame: loaded slot " + string(global.save_slot));
    }
}

if (keyboard_check_pressed(vk_f11)) {
    savegame_self_test(interface.get_game());
}

// ---- mouse wheel: integer pixel zoom, 1x to 4x
if (mouse_wheel_up() || mouse_wheel_down()) {
    var _viewport = interface.get_viewport();
    if (_viewport != undefined) {
        var _step = 0;
        if (mouse_wheel_up()) {
            _step = 1;
        } else {
            _step = -1;
        }
        _viewport.set_zoom(_viewport.get_zoom() + _step);
    }
}

// ---- mouse position in screen pixels (room == screen size)
// mouse_x / mouse_y are room coordinates, so GameMaker has already divided out
// the window-to-application-surface scale for us: x2 in a window, whatever
// ratio fullscreen ends up using. One unit here is always one drawn game pixel,
// so nothing else in this file needs to know the window size. The unrounded
// values are kept as well, because 1:1 dragging needs the fraction.
var _mx_raw = clamp(mouse_x, 0, SCREEN_W - 1);
var _my_raw = clamp(mouse_y, 0, SCREEN_H - 1);
var _mx = floor(_mx_raw);
var _my = floor(_my_raw);

// ---- clicks fire on button release; double click within time/move sensitivity
var _buttons = [mb_left, mb_middle, mb_right];

// Left + right held together == "both buttons" on a two-button Amiga mouse.
if (mouse_check_button(mb_left) && mouse_check_button(mb_right)) {
    both_buttons_active = true;
    suppress_click[EventButton.left] = true;
    suppress_click[EventButton.right] = true;
}

for (var _b = 1; _b <= 3; _b++) {
    var _mb = _buttons[_b - 1];
    if (mouse_check_button_released(_mb)) {
        if (drag_button == _b) {
            drag_button = 0;
        }
        if (both_buttons_active) {
            both_buttons_active = false;
            interface.handle_event(gui_make_event(EventType.click, _mx, _my, 0, 0,
                                                  EventButton.middle));
        }
        if (suppress_click[_b]) {
            suppress_click[_b] = false;
            continue;
        }
        interface.handle_event(gui_make_event(EventType.click, _mx, _my, 0, 0, _b));
        if (current_time - last_click_time[_b] < MOUSE_TIME_SENSITIVITY
            && _mx >= last_click_x - MOUSE_MOVE_SENSITIVITY && _mx <= last_click_x + MOUSE_MOVE_SENSITIVITY
            && _my >= last_click_y - MOUSE_MOVE_SENSITIVITY && _my <= last_click_y + MOUSE_MOVE_SENSITIVITY) {
            interface.handle_event(gui_make_event(EventType.dbl_click, _mx, _my, 0, 0, _b));
        }
        last_click_time[_b] = current_time;
        last_click_x = _mx;
        last_click_y = _my;
    }
}

// ---- dragging (any held button): drag events carry the delta since the press
for (var _b = 1; _b <= 3; _b++) {
    var _mb = _buttons[_b - 1];
    if (mouse_check_button(_mb)) {
        if (drag_button == 0) {
            drag_button = _b;
            drag_x = _mx_raw;
            drag_y = _my_raw;
            drag_sent_x = 0;
            drag_sent_y = 0;
            break;
        }
        if (drag_button == _b) {
            // Freeserf sends the delta from the drag anchor and then warps the
            // pointer back to it (SDL_WarpMouseInWindow). Warping the real
            // cursor every frame fights the user's mouse on Windows, so we send
            // the same movement as an incremental delta instead - the handlers
            // only ever use dx/dy, so the result is identical but smooth.
            //
            // The anchor stays where the button went down and we send only the
            // whole pixels not sent yet. Two things that fixes, both of which
            // made the drag feel loose:
            //   - re-anchoring every frame floored away the fraction of a pixel
            //     a slow drag makes each frame, so the map fell behind the
            //     pointer and never caught up;
            //   - the event carries the press position, so a drag that wanders
            //     over the panel or a popup still reaches the viewport instead
            //     of being swallowed by whatever is under the cursor now.
            var _want_x = round(_mx_raw - drag_x);
            var _want_y = round(_my_raw - drag_y);
            var _dx = _want_x - drag_sent_x;
            var _dy = _want_y - drag_sent_y;
            if (_dx != 0 || _dy != 0) {
                drag_sent_x = _want_x;
                drag_sent_y = _want_y;
                interface.handle_event(gui_make_event(EventType.drag, floor(drag_x), floor(drag_y), _dx, _dy, _b));
            }
        }
        break;
    }
}

// ---- keyboard: map scroll (arrow keys = drag by 32) and key presses
// The arrows scroll the view the way they point. In 1:1 mode the viewport's
// drag handler moves the map with the pointer, which is the opposite sign, so
// the synthetic delta flips to keep the arrows doing the same thing either way.
var _scroll_sign = 1;
if (global.map_drag_1to1) {
    _scroll_sign = -1;
}
if (keyboard_check_pressed(vk_up)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, 0, -32 * _scroll_sign, EventButton.left));
}
if (keyboard_check_pressed(vk_down)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, 0, 32 * _scroll_sign, EventButton.left));
}
if (keyboard_check_pressed(vk_left)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, -32 * _scroll_sign, 0, EventButton.left));
}
if (keyboard_check_pressed(vk_right)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, 32 * _scroll_sign, 0, EventButton.left));
}

var _modifier = 0;
if (keyboard_check(vk_control)) {
    _modifier |= 1;
}
if (keyboard_check(vk_shift)) {
    _modifier |= 2;
}
if (keyboard_check(vk_alt)) {
    _modifier |= 4;
}
if (keyboard_check_pressed(vk_anykey)) {
    var _key = keyboard_key;
    var _chr = -1;
    if (_key >= ord("A") && _key <= ord("Z")) {
        _chr = _key + 32;      // lower case letters like SDL keysyms
    } else if (_key >= ord("0") && _key <= ord("9")) {
        _chr = _key;
    } else if (_key == vk_add || _key == 187) {
        _chr = ord("+");
    } else if (_key == vk_subtract || _key == 189) {
        _chr = ord("-");
    } else if (_key == vk_escape || _key == vk_enter || _key == vk_backspace || _key == vk_space || _key == vk_tab) {
        _chr = _key;
    }
    if (_chr != -1) {
        interface.handle_event(gui_make_event(EventType.key_pressed, 0, 0, _chr, _modifier, 0));
    }
}

if (keyboard_check_pressed(vk_f3)) {
    show_debug = !show_debug;
}
