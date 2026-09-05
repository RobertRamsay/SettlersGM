/// obj_game Draw - Interface draws viewport, panel, popups (GuiObject float protocol)
// Re-assert point sampling every frame: GameMaker's "Interpolate colours
// between pixels" game option is on by default and would blur the x2 upscale
// of the application surface, muddying the Amiga palette.
gpu_set_texfilter(false);
interface.handle_event(gui_make_event(EventType.draw, 0, 0, 0, 0, 0));

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
}

// ---- networking status, drawn last so nothing covers it.
// Only while networked: offline this is not a thing the player should see.
// Shown whenever there is anything to say, NOT only while connected: a join
// that fails leaves the role back at off, so gating this on net_is_active()
// hid the one message that mattered - which is how a failed connection came to
// look like a key that did nothing.
if (net_status_line() != "") {
    var _msg = "NET: " + net_status_line();
    if (net_is_running() && net_ticks_available() <= 0) {
        _msg += "  [waiting for the other player]";
    }
    draw_set_colour(c_black);
    draw_text(5, 5, _msg);
    draw_set_colour(c_white);
    draw_text(4, 4, _msg);
    draw_set_colour(c_white);
}
