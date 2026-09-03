// scr_audio.gml - Sound effect ids ported from Freeserf src/audio.h (GPL-3.0).
// The Amiga data holds 39 samples; the id numbers below are Freeserf's sound
// resource indices, which map onto the extracted snd_<n> assets.

enum Sfx {
    message = 1,
    accepted = 2,
    not_accepted = 4,
    undo = 6,
    click = 8,
    fight01 = 10,
    fight02 = 14,
    fight03 = 18,
    fight04 = 22,
    resource_found = 26,
    pick_blow = 28,
    metal_hammering = 30,
    ax_blow = 32,
    tree_fall = 34,
    wood_hammering = 36,
    elevator = 38,
    hammer_blow = 40,
    sawing = 42,
    mill_grinding = 43,
    backsword_blow = 44,
    geologist_sampling = 46,
    planting = 48,
    digging = 50,
    mowing = 52,
    fishing_rod_reel = 54,
    unknown21 = 58,
    pig_oink = 60,
    gold_boils = 62,
    rowing = 64,
    unknown25 = 66,
    serf_dying = 69,
    bird_chirp0 = 70,
    bird_chirp1 = 74,
    ahhh = 76,
    bird_chirp2 = 78,
    bird_chirp3 = 82,
    burning = 84,
    unknown28 = 86,
    unknown29 = 88
}

/// Plays the sound effect with Freeserf sound index _id (if the Amiga data has it).
function play_sfx(_id) {
    var _n = array_length(global.sound_index_map);
    if (!audio_get_instance().sfx.is_enabled()) {
        return false;
    }
    for (var _i = 0; _i < _n; _i++) {
        if (global.sound_index_map[_i] == _id) {
            audio_play_sound(global.sound_assets[_i], 10, false);
            return true;
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// Minimal port of Freeserf's Audio singleton (src/audio.h) used by the options
// popup: music player, sound player and a volume controller.

function audio_init() {
    global.audio_music_enabled = true;
    global.audio_sfx_enabled = true;
    global.audio_volume = 1.0;
    global.audio_music_id = -1;
    global.audio_instance = {
        music: {
            is_enabled: function() { return global.audio_music_enabled; },
            enable: function(_e) {
                global.audio_music_enabled = _e;
                if (global.audio_music_id != -1) {
                    if (_e) {
                        audio_resume_sound(global.audio_music_id);
                    } else {
                        audio_pause_sound(global.audio_music_id);
                    }
                }
            }
        },
        sfx: {
            is_enabled: function() { return global.audio_sfx_enabled; },
            enable: function(_e) { global.audio_sfx_enabled = _e; }
        },
        volume: {
            get_volume: function() { return global.audio_volume; },
            set_volume: function(_v) {
                global.audio_volume = clamp(_v, 0, 1);
                audio_master_gain(global.audio_volume);
            },
            volume_up: function() { self.set_volume(global.audio_volume + 0.1); },
            volume_down: function() { self.set_volume(global.audio_volume - 0.1); }
        },
        get_music_player: function() { return self.music; },
        get_sound_player: function() { return self.sfx; },
        get_volume_controller: function() { return self.volume; }
    };
}

function audio_get_instance() {
    if (!variable_global_exists("audio_instance")) {
        audio_init();
    }
    return global.audio_instance;
}

function audio_play_music() {
    var _a = audio_get_instance();
    if (global.audio_music_id == -1) {
        global.audio_music_id = audio_play_sound(mus_settlers, 1, true);
        if (!global.audio_music_enabled) {
            audio_pause_sound(global.audio_music_id);
        }
    }
}

function audio_toggle_music() {
    var _a = audio_get_instance();
    _a.music.enable(!_a.music.is_enabled());
}

function audio_toggle_sfx() {
    var _a = audio_get_instance();
    _a.sfx.enable(!_a.sfx.is_enabled());
}

function audio_volume_up() {
    audio_get_instance().volume.volume_up();
}

function audio_volume_down() {
    audio_get_instance().volume.volume_down();
}

/// Save games are not implemented yet (see CONVENTIONS2.md).
function game_store_save(_path, _game) {
    show_debug_message("game_store_save: saving is not implemented (" + string(_path) + ")");
    return false;
}
