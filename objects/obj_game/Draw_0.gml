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
