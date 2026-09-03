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
}

// ---- time-advance buttons: burn through the owed ticks a slice at a time
if (global.fast_forward_ticks > 0) {
    var _burst = min(global.fast_forward_ticks, FAST_FORWARD_TICKS_PER_FRAME);
    for (var _f = 0; _f < _burst; _f++) {
        interface.handle_event(gui_make_event(EventType.update, 0, 0, 0, 0, 0));
    }
    global.fast_forward_ticks -= _burst;
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
var _mx = clamp(floor(mouse_x), 0, SCREEN_W - 1);
var _my = clamp(floor(mouse_y), 0, SCREEN_H - 1);

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
            drag_x = _mx;
            drag_y = _my;
            break;
        }
        if (drag_button == _b) {
            // Freeserf sends the delta from the drag anchor and then warps the
            // pointer back to it (SDL_WarpMouseInWindow). Warping the real
            // cursor every frame fights the user's mouse on Windows, so we send
            // the same movement as an incremental delta instead - the handlers
            // only ever use dx/dy, so the result is identical but smooth.
            var _dx = _mx - drag_x;
            var _dy = _my - drag_y;
            if (_dx != 0 || _dy != 0) {
                interface.handle_event(gui_make_event(EventType.drag, drag_x, drag_y, _dx, _dy, _b));
                drag_x = _mx;
                drag_y = _my;
            }
        }
        break;
    }
}

// ---- keyboard: map scroll (arrow keys = drag by 32) and key presses
if (keyboard_check_pressed(vk_up)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, 0, -32, EventButton.left));
}
if (keyboard_check_pressed(vk_down)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, 0, 32, EventButton.left));
}
if (keyboard_check_pressed(vk_left)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, -32, 0, EventButton.left));
}
if (keyboard_check_pressed(vk_right)) {
    interface.handle_event(gui_make_event(EventType.drag, 0, 0, 32, 0, EventButton.left));
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
