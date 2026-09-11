/// obj_game Draw - Interface draws viewport, panel, popups (GuiObject float protocol)
// Re-assert point sampling every frame: GameMaker's "Interpolate colours
// between pixels" game option is on by default and would blur the x2 upscale
// of the application surface, muddying the Amiga palette.
gpu_set_texfilter(false);
prof_draw_begin();
interface.handle_event(gui_make_event(EventType.draw, 0, 0, 0, 0, 0));
prof_draw_end();

if (show_debug) {
    var _pos = interface.get_map_cursor_pos();
    var _map = game.get_map();
    var _g = _map.geom;
    draw_set_color(c_white);
    draw_text(4, 4, "fps " + string(fps) + "  tick " + string(game.get_tick())
        + "  cursor " + string(_g.pos_col(_pos)) + "," + string(_g.pos_row(_pos))
        + " h=" + string(_map.get_height(_pos))
        + " obj=" + string(_map.get_obj(_pos))
        + " owner=" + string(_map.get_owner(_pos))
        + "  flags=" + string(game.flags.size()) + " bld=" + string(game.buildings.size()) + " serfs=" + string(game.serfs.size()));
    /* Where the time goes - see the profiler in scr_gfx. Rebuilt a few times
       a second, drawn every frame. */
    prof_refresh(game, interface);
    prof_draw_overlay(4, 16);
}

// ---- networking status, drawn last so nothing covers it.
// Only while networked: offline this is not a thing the player should see.
// Shown whenever there is anything to say, NOT only while connected: a join
// that fails leaves the role back at off, so gating this on net_is_active()
// hid the one message that mattered - which is how a failed connection came to
// look like a key that did nothing.
// Wrapped, not clipped. These lines carry the whole diagnosis - the addresses
// tried, the desync turn and both hashes - and a message that runs off the
// right-hand edge is the half you cannot read.
//
// draw_text_ext wraps at NET_TEXT_WIDTH and breaks on spaces, so the numbers
// stay whole; NET_TEXT_LINE is the line height it steps by.
/* The on-screen text metrics live in scr_net.gml, beside net_draw_message
   which uses them - a script cannot sensibly depend on a macro declared in an
   object event, even though GML makes them global. */



// The NET PLAY panel says all of this itself, in its own place and its own
// font, so while it is on screen the corner stays empty: the same line twice,
// once on the panel and once floating over it, reads as two different things.
var _netplay_panel = false;
var _init_box = interface.get_game_init_box();
if (_init_box != undefined && _init_box.game_type == GameType.netplay) {
    _netplay_panel = true;
}

/* Net play chat, along the bottom left. Drawn whether or not the box is open,
   because a line that arrives while you are looking at the map is the whole
   point of having chat at all. Lines age out after about ten seconds unless
   the box is open, in which case they stay up while you are reading them. */
if (net_is_active() || global.net_chat_open ||
    array_length(global.net_chat_lines) > 0) {
    /* Chat sits over the bottom of the screen, where the panel is, so it can
       cover the controls. Putting the pointer down there is as clear a signal
       as any that the panel is what you are looking at, so the words step back
       to NET_CHAT_DIM rather than disappearing - still readable, no longer in
       the way. mouse_x/mouse_y are room coordinates and GameMaker has already
       divided the window scale out of them, so they are in the same space as
       everything drawn here. */
    /* gfx_* coordinates are relative to the current GUI origin, which the
       floats move about as they draw. Put it back to the screen corner. */
    gfx_set_origin(0, 0);

    var _chat_alpha = 1;
    if (mouse_y >= NET_CHAT_FADE_Y) {
        _chat_alpha = NET_CHAT_DIM;
    }

    var _chat_n = array_length(global.net_chat_lines);
    var _chat_y = SCREEN_H - 16 - (_chat_n * NET_TEXT_LINE);
    if (global.net_chat_open) {
        _chat_y -= NET_TEXT_LINE;
    }

    for (var _i = 0; _i < _chat_n; _i++) {
        var _line = global.net_chat_lines[_i];
        var _who = "THEM: ";
        var _col = c_aqua;
        if (_line.mine) {
            _who = "YOU: ";
            _col = c_white;
        }
        gfx_draw_string_shadow(4, _chat_y, _who + _line.text, _col, _chat_alpha);
        _chat_y += NET_TEXT_LINE;
    }

    if (global.net_chat_open) {
        /* A caret, so an empty box still looks like somewhere to type. The box
           you are typing into does not dim - you are looking straight at it. */
        gfx_draw_string_shadow(4, _chat_y,
                               "SAY: " + global.net_chat_text + "_", c_yellow, 1);
    }
}

/* The crash notice sits above all of it: it is asking a question, and the run
   it is about is already over, so nothing else on this line matters more. */
if (global.crash_notice != "") {
    draw_set_colour(c_black);
    draw_text_ext(5, 5, global.crash_notice, NET_TEXT_LINE, NET_TEXT_WIDTH);
    draw_set_colour(c_yellow);
    draw_text_ext(4, 4, global.crash_notice, NET_TEXT_LINE, NET_TEXT_WIDTH);
    draw_set_colour(c_white);

    /* The two answers, drawn as things that look pressable because they are.
       Written on the line as "Y / N" they read as buttons and are not, which is
       exactly what happened - the first thing anybody does is click them.

       The rectangles are worked out here rather than guessed at, because only
       the drawing knows how wide the words came out, and handed to the Step
       event to hit-test. */
    if (global.crash_asking) {
        var _gap   = string_width("  ");
        var _yes   = "[ YES ]";
        var _no    = "[ NO ]";
        var _cx    = 4 + string_width(global.crash_notice) + _gap;
        var _cy    = 4;

        global.crash_hit_y1 = _cy;
        global.crash_hit_y2 = _cy + string_height(_yes);

        global.crash_yes_x1 = _cx;
        global.crash_yes_x2 = _cx + string_width(_yes);

        var _nx = global.crash_yes_x2 + _gap;
        global.crash_no_x1 = _nx;
        global.crash_no_x2 = _nx + string_width(_no);

        draw_set_colour(c_black);
        draw_text(_cx + 1, _cy + 1, _yes);
        draw_text(_nx + 1, _cy + 1, _no);
        draw_set_colour(c_white);
        draw_text(_cx, _cy, _yes);
        draw_text(_nx, _cy, _no);
        draw_set_colour(c_white);
    }
} else if (global.net_ip_prompt && global.net_ip_prompt_mode == "join") {
    /* F8's own prompt. The lobby's ADD prompt is drawn by the panel. */
    var _prompt = "HOST PC's IP: " + global.net_ip_text + "_" +
                  "   :" + string(NET_PORT) + "   (Enter connects, Esc cancels)";
    net_draw_message(_prompt, c_yellow);
} else if (!_netplay_panel &&
           (net_status_visible() || net_exit_pending() ||
            net_live_notice(interface.get_game()) != "")) {
    /* Three things share this line. The status ("player 2 joined", "in game as
       player 2") is news: worth reading once, clutter for the rest of the
       session, so it ages out after ten seconds. The live notice - whose turn
       it is to place a castle, and whether we are actually held up waiting for
       the peer - is a statement about right now, so it stays for exactly as
       long as it is true. The exit notice counts down the last five seconds of
       a session the other player has walked out of, and holds the whole line up
       while it does, since the reason above it is the point. */
    var _msg = "";
    if (net_status_visible() || net_exit_pending()) {
        _msg = "NET: " + net_status_line();
    }
    _msg += net_exit_notice();
    _msg += net_live_notice(interface.get_game());

    var _colour = c_white;
    if (net_exit_pending()) {
        _colour = c_yellow;
    }

    net_draw_message(_msg, _colour);
    draw_set_colour(c_white);
}

/* The language question, over everything, until it has been answered once.
   Draws nothing at all after that. */
locale_prompt_draw();
