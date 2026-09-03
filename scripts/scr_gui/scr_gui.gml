// scr_gui.gml - Ported from Freeserf src/gui.h / src/gui.cc (GPL-3.0) and the
// Event struct of src/event_loop.h, original copyright (C) 2012-2018
// Jon Lund Steffensen <jonlst@gmail.com>.
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Base functions for the GUI hierarchy. Every GUI class is a constructor
// inheriting from GuiObject(). Drawing goes through the scr_gfx.gml helpers,
// whose coordinates are local to the current GUI object; GuiObject.draw()
// sets the object's screen origin with gfx_set_origin() before drawing.
//
// Differences from the C++:
//  - There is no per-object cached Frame: the whole hierarchy is redrawn every
//    frame, so `redraw` is kept as a field but set_redraw() is a no-op.
//  - GuiObject::focused_object (static) is global.gui_focused_object.
//  - A C++ subclass calling GuiObject::handle_event() explicitly (Interface)
//    calls gui_handle_event() instead, since GML has no `super`.

/// Event::Type (event_loop.h)
enum EventType {
    click = 0,
    dbl_click,
    drag,
    key_pressed,
    resize,
    update,
    draw
}

/// Event::Button (event_loop.h)
enum EventButton {
    left = 1,
    middle,
    right
}

/// Event (event_loop.h): {type, x, y, dx, dy, button}.
/// For EventType.key_pressed, dx = key (ascii code) and dy = modifier, exactly
/// like Freeserf's EventLoop::notify_key_pressed.
function gui_make_event(_type, _x, _y, _dx, _dy, _button) {
    return { type: _type, x: _x, y: _y, dx: _dx, dy: _dy, button: _button };
}

function gui_init_globals() {
    if (!variable_global_exists("gui_focused_object")) {
        global.gui_focused_object = undefined;
    }
}

/* Get the resulting value from a click on a slider bar. */
function gui_get_slider_click_value(_x) {
    return 1310 * clamp(_x - 7, 0, 50);
}

function GuiObject() constructor {
    gui_init_globals();

    floats = [];          // array of {obj, x, y}
    x = 0;
    y = 0;
    width = 0;
    height = 0;
    displayed = false;
    enabled = true;
    redraw = true;
    parent = undefined;
    focused = false;

    /* Virtuals with default implementations. Subclasses override by
       re-declaring the static with the same name. */
    static internal_draw = function() {
    };

    static layout = function() {
    };

    static handle_click_left = function(_x, _y) {
        return false;
    };

    static handle_dbl_click = function(_x, _y, _button) {
        return false;
    };

    static handle_drag = function(_dx, _dy) {
        return true;
    };

    static handle_key_pressed = function(_key, _modifier) {
        return false;
    };

    static handle_focus_loose = function() {
        return false;
    };

    /// Screen position of this object = own x, y plus every ancestor's x, y.
    /// Returns [screen_x, screen_y].
    static get_screen_position = function() {
        var _sx = x;
        var _sy = y;
        var _p = parent;
        while (_p != undefined) {
            _sx += _p.x;
            _sy += _p.y;
            _p = _p.parent;
        }
        return [_sx, _sy];
    };

    /// GuiObject::draw(Frame *). Sets the gfx origin, draws self, then floats.
    static draw = function() {
        if (!displayed) {
            return;
        }

        var _sp = get_screen_position();
        gfx_set_origin(_sp[0], _sp[1]);
        internal_draw();

        var _n = array_length(floats);
        for (var _i = 0; _i < _n; _i++) {
            var _f = floats[_i].obj;
            if (_f.displayed) {
                _f.draw();
            }
        }
        redraw = false;

        // Restore our origin in case a caller keeps drawing after us.
        gfx_set_origin(_sp[0], _sp[1]);
    };

    /// GuiObject::handle_event(const Event *). `_event` = {type, x, y, dx, dy, button}.
    static gui_handle_event = function(_event) {
        if (!enabled || !displayed) {
            return false;
        }

        var _event_x = _event.x;
        var _event_y = _event.y;
        if (_event.type == EventType.click ||
            _event.type == EventType.dbl_click ||
            _event.type == EventType.drag) {
            _event_x = _event.x - x;
            _event_y = _event.y - y;
            if (_event_x < 0 || _event_y < 0 || _event_x > width || _event_y > height) {
                return false;
            }
        }

        var _internal_event = gui_make_event(_event.type, _event_x, _event_y,
                                             _event.dx, _event.dy, _event.button);

        /* Find the corresponding float element if any */
        for (var _i = array_length(floats) - 1; _i >= 0; _i--) {
            var _fl = floats[_i].obj;
            var _fresult = _fl.handle_event(_internal_event);
            if (_fresult != false) {
                return _fresult;
            }
        }

        var _result = false;
        switch (_event.type) {
            case EventType.click:
                if (_event.button == EventButton.left) {
                    _result = handle_click_left(_event_x, _event_y);
                }
                break;
            case EventType.drag:
                _result = handle_drag(_event.dx, _event.dy);
                break;
            case EventType.dbl_click:
                _result = handle_dbl_click(_event.x, _event.y, _event.button);
                break;
            case EventType.key_pressed:
                _result = handle_key_pressed(_event.dx, _event.dy);
                break;
            default:
                break;
        }

        if (_result && (global.gui_focused_object != self)) {
            if (global.gui_focused_object != undefined) {
                global.gui_focused_object.focused = false;
                global.gui_focused_object.handle_focus_loose();
                global.gui_focused_object.set_redraw();
                global.gui_focused_object = undefined;
            }
        }

        return _result;
    };

    static handle_event = function(_event) {
        return gui_handle_event(_event);
    };

    static set_focused = function() {
        if (global.gui_focused_object != self) {
            if (global.gui_focused_object != undefined) {
                global.gui_focused_object.focused = false;
                global.gui_focused_object.handle_focus_loose();
                global.gui_focused_object.set_redraw();
            }
            focused = true;
            global.gui_focused_object = self;
            set_redraw();
        }
    };

    static move_to = function(_px, _py) {
        x = _px;
        y = _py;
        set_redraw();
    };

    /// Returns [x, y]
    static get_position = function() {
        return [x, y];
    };

    static set_size = function(_new_width, _new_height) {
        width = _new_width;
        height = _new_height;
        layout();
        set_redraw();
    };

    /// Returns [width, height]
    static get_size = function() {
        return [width, height];
    };

    static set_displayed = function(_displayed) {
        displayed = _displayed;
        set_redraw();
    };

    static set_enabled = function(_enabled) {
        enabled = _enabled;
    };

    /// No-op: everything is redrawn every frame in GML.
    static set_redraw = function() {
        redraw = true;
    };

    static is_displayed = function() {
        return displayed;
    };

    static get_parent = function() {
        return parent;
    };

    static set_parent = function(_parent) {
        parent = _parent;
    };

    static point_inside = function(_point_x, _point_y) {
        return (_point_x >= x && _point_y >= y &&
                _point_x < x + width && _point_y < y + height);
    };

    static add_float = function(_obj, _fx, _fy) {
        _obj.set_parent(self);
        array_push(floats, { obj: _obj, x: _fx, y: _fy });
        _obj.move_to(_fx, _fy);
        set_redraw();
    };

    static del_float = function(_obj) {
        _obj.set_parent(undefined);
        var _n = array_length(floats);
        for (var _i = _n - 1; _i >= 0; _i--) {
            if (floats[_i].obj == _obj) {
                array_delete(floats, _i, 1);
            }
        }
        set_redraw();
    };

    static play_sound = function(_sound) {
        play_sfx(_sound);
    };
}
