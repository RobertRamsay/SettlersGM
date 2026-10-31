/// scr_settings.gml - the options popup's choices, remembered in settlers.ini.
///
/// Before 1.2.2 only the language and the screen shape outlived the session:
/// music, effects, both volumes, the message filter, drag direction, stereo
/// and fullscreen all came back at their defaults on every launch, so a
/// player who wanted the music off turned it off every time. Each is written
/// here the moment the popup changes it, and read back at start-up.
///
/// The file is the same one across versions - it lives in the save area,
/// which is named after the game, not the build - so a new download keeps
/// them. A key that is missing, which is every key on the first run after
/// updating, leaves that setting at its default.
///
/// The screen shape keeps its own [display] section (scr_gfx) and the language
/// its own [locale] (scr_locale); they were there first.

#macro SETTINGS_INI_SECTION "options"

/// The interface's message-filter bits: 3 = all, 4 = most, 5 = few. The
/// options popup steps through all/most/few/none, which is these four values.
#macro SETTINGS_MESSAGE_SHIFT 3
#macro SETTINGS_MESSAGE_MASK  (7 << SETTINGS_MESSAGE_SHIFT)

/// Music, effects, volumes, stereo. Straight after audio_init, before any
/// music starts: settlers_play_music reads audio_music_enabled and the volume
/// as it starts the track, so they only have to be right by then.
function settings_load_audio() {
    ini_open(PROGRESS_PATH);
    global.audio_music_enabled = ini_read_real(SETTINGS_INI_SECTION, "music", 1) != 0;
    global.audio_sfx_enabled = ini_read_real(SETTINGS_INI_SECTION, "sfx", 1) != 0;
    global.audio_music_volume = clamp(ini_read_real(SETTINGS_INI_SECTION, "music_volume", 1), 0, 1);
    global.audio_sfx_volume = clamp(ini_read_real(SETTINGS_INI_SECTION, "sfx_volume", 1), 0, 1);
    global.sfx_stereo = ini_read_real(SETTINGS_INI_SECTION, "stereo", 1) != 0;
    ini_close();
}

/// Whether to go full-window at start-up. Read by fullscreen_init.
function settings_load_fullscreen(_default) {
    ini_open(PROGRESS_PATH);
    var _on = ini_read_real(SETTINGS_INI_SECTION, "fullscreen", _default) != 0;
    ini_close();
    return _on;
}

/// The message filter and drag direction, once the interface exists and
/// Create has set global.map_drag_invert's default.
function settings_load_interface(_interface) {
    ini_open(PROGRESS_PATH);
    var _messages = ini_read_real(SETTINGS_INI_SECTION, "messages", -1);
    var _invert = ini_read_real(SETTINGS_INI_SECTION, "invert", -1);
    ini_close();

    /* Only the four states the popup can produce: anything else is a hand
       edit gone wrong, and the default is a better answer than a guess. */
    if (_messages == 7 || _messages == 6 || _messages == 4 || _messages == 0) {
        _interface.config = (_interface.config & ~SETTINGS_MESSAGE_MASK) |
                            (_messages << SETTINGS_MESSAGE_SHIFT);
    }
    if (_invert == 0 || _invert == 1) {
        global.map_drag_invert = (_invert == 1);
    }
}

/// Everything the options popup shows, written in one go. Called after each
/// change it makes - they are a handful of lines, so writing the lot is
/// simpler than tracking which one moved.
function settings_save(_interface) {
    ini_open(PROGRESS_PATH);
    ini_write_real(SETTINGS_INI_SECTION, "music", global.audio_music_enabled);
    ini_write_real(SETTINGS_INI_SECTION, "sfx", global.audio_sfx_enabled);
    ini_write_real(SETTINGS_INI_SECTION, "music_volume", global.audio_music_volume);
    ini_write_real(SETTINGS_INI_SECTION, "sfx_volume", global.audio_sfx_volume);
    ini_write_real(SETTINGS_INI_SECTION, "stereo", global.sfx_stereo);
    /* Wanted counts as on: in the first few frames the start-up switch is
       still pending, and a change made then must not record "windowed". */
    ini_write_real(SETTINGS_INI_SECTION, "fullscreen",
                   global.fullscreen_on || global.fullscreen_wanted);
    ini_write_real(SETTINGS_INI_SECTION, "invert", global.map_drag_invert);
    if (_interface != undefined) {
        ini_write_real(SETTINGS_INI_SECTION, "messages",
                       (_interface.config & SETTINGS_MESSAGE_MASK) >> SETTINGS_MESSAGE_SHIFT);
    }
    ini_close();
}

/* ---------------------------------------------------------------------------
   The Mac save folder.

   Up to the first 1.2.2 upload the Mac build's app id was
   com.polytricity.c64devmachine - copied from another project - and macOS
   names the save folder after the app id, so Mac players' settings and saves
   have been living in a folder called c64devmachine. 1.2.2 has its own id,
   which gives it a new, empty folder. The first time it starts and finds no
   settlers.ini there, it copies the game's files across from the old one, so
   nobody loses a save to the rename.

   Copied, not moved: the old folder is left exactly as it was, so going back
   to an older build still finds everything, and if the other app does use the
   folder, nothing of its is touched - only names this game writes are taken.
   It needs the sandbox off to read outside its own folder, which the Mac
   target already has ("option_mac_disable_sandbox"). */
#macro SETTINGS_MAC_APP_ID     "com.polytricity.settlersgm"
#macro SETTINGS_MAC_OLD_APP_ID "com.polytricity.c64devmachine"

/// First thing in Create - before anything opens settlers.ini.
function settings_migrate_mac_save_folder() {
    if (os_type != os_macosx) {
        return;
    }
    var _new_dir = game_save_id;
    if (string_pos(SETTINGS_MAC_APP_ID, _new_dir) == 0) {
        /* Not the folder this was written for - the id changed again, or
           the runtime put it somewhere else. Leave well alone. */
        show_debug_message("settings: save folder " + _new_dir +
                           " does not name " + SETTINGS_MAC_APP_ID + " - not migrating");
        return;
    }
    if (file_exists(_new_dir + PROGRESS_PATH)) {
        return;   /* Already migrated, or played on this build before. */
    }
    var _old_dir = string_replace(_new_dir, SETTINGS_MAC_APP_ID, SETTINGS_MAC_OLD_APP_ID);
    if (!file_exists(_old_dir + PROGRESS_PATH)) {
        return;   /* A new player: nothing to bring over. */
    }

    var _copied = 0;
    var _name = file_find_first(_old_dir + "settlers*", fa_none);
    while (_name != "") {
        file_copy(_old_dir + _name, _new_dir + _name);
        _copied += 1;
        _name = file_find_next();
    }
    file_find_close();
    if (file_exists(_old_dir + REPORT_TAG_FILE)) {
        file_copy(_old_dir + REPORT_TAG_FILE, _new_dir + REPORT_TAG_FILE);
        _copied += 1;
    }
    show_debug_message("settings: copied " + string(_copied) + " files from " +
                       _old_dir + " to " + _new_dir);
}
