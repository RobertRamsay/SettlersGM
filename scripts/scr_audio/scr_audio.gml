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
    /* Freeserf calls these TypeSfxUnknown28 and TypeSfxUnknown29 and has never
       identified them, and it never plays either. Bob identified them by ear
       from the Amiga samples: 86 is water, 88 is wind. Both are ambience, and
       ambience is the one thing Freeserf's viewport has no code for at all -
       see Viewport.ambient_step, which is where they are used. */
    water = 86,
    wind = 88
}

// ---------------------------------------------------------------------------
// The mixer.
//
// The Amiga had four sound channels and one mix, so however busy the map got
// you never heard more than four things at once and the hardware itself did
// the ducking. GameMaker will happily play a hundred, at full gain, all at the
// centre of your head - which is why a settlement of any size turned into a
// wall of hammering. This puts the Amiga's limits back, and adds the one thing
// the original did in the mix rather than the hardware: sounds are loudest at
// the middle of the view and fade out towards the edges.
//
// Positions are viewport LOGICAL pixels (the coordinates the viewport draws
// its own contents at), which is exactly what the draw code already has in
// hand at the moment it decides to make a noise.
// ---------------------------------------------------------------------------

/// Everything an effect plays at, before the master volume slider.
#macro SFX_BASE_GAIN 0.55

/// Amiga channel count. A fifth simultaneous effect only gets in by being
/// louder than the quietest one already playing, which it then replaces.
#macro SFX_VOICES 4

/// The same sample cannot restart faster than this. Twelve woodcutters swinging
/// in the same second is one axe blow, not twelve.
#macro SFX_REPEAT_MS 110

/// How many recent plays are remembered for that check.
#macro SFX_RECENT 24

/// Gain multiplier at the edge of the view, and the distance (in half-screens)
/// past which an effect is simply not played.
#macro SFX_EDGE_GAIN 0.08
#macro SFX_CUTOFF 1.15

/// How far to one side a sound at the very edge of the view is placed. 1 is
/// the full width of the stereo image; anything less pulls everything in
/// towards the middle, which is what made the first attempt so subtle it was
/// easy to miss.
#macro SFX_PAN_MAX 1.0

/// How far to either side of the listener a fully panned voice's emitter sits.
/// The number itself does not matter to the panning - the direction from the
/// listener does, and that is the same at any distance along the axis - but a
/// source sitting almost on top of the listener is exactly where a spatialiser
/// is least sure which ear it belongs to, so it is worth putting real distance
/// between them.
#macro SFX_PAN_DISTANCE 500

/// Falloff reference and maximum distance for every voice emitter. Reference =
/// the pan distance means a fully panned emitter sits exactly ON the reference
/// distance and everything nearer is clamped to it, so under every one of
/// GameMaker's falloff models the engine's distance gain works out at exactly
/// 1. Loudness stays entirely ours; the emitter only ever decides the ear.
/// (max must not equal ref: the linear model divides by their difference.)
#macro SFX_PAN_REF SFX_PAN_DISTANCE
#macro SFX_PAN_MAX_DIST (SFX_PAN_DISTANCE * 2)

/// Whether voices go out through their emitters (which is the only way GML
/// offers to pan a sound) or straight through audio_play_sound with the gain
/// set on the handle.
///
/// The emitter path is the one that pans. The plain path cannot, but it is the
/// dumbest thing the audio engine can be asked to do, so if effects ever go
/// silent this is the switch that says whether the mixer or the emitters are
/// at fault: set it to false, and if the sound comes back it was the
/// emitters - positional audio needs mono samples and a listener at the
/// origin, and a machine or a sound asset can fail either.
#macro SFX_USE_EMITTERS true

/// Is stereo placement on? The options popup toggles this; Mono plays every
/// effect dead centre and leaves the distance-from-centre volume alone.
function sfx_stereo_enabled() {
    audio_get_instance();
    return global.sfx_stereo;
}

function sfx_set_stereo(_on) {
    audio_get_instance();
    global.sfx_stereo = _on;
}

function sfx_toggle_stereo() {
    sfx_set_stereo(!sfx_stereo_enabled());
}

/// Where the ear is. The viewport refreshes this every time it redraws itself;
/// until then, and on the start screen, there is no view and positional sounds
/// fall back to playing centred.
function sfx_set_listener(_view, _width, _height) {
    audio_get_instance();
    global.sfx_view = _view;
    global.sfx_half_w = max(1, _width / 2);
    global.sfx_half_h = max(1, _height / 2);
}

/// Gain and pan for something drawn at _lx,_ly in viewport logical pixels.
/// Returns [gain, pan], or undefined when it is too far off to be worth a voice.
function sfx_place(_lx, _ly) {
    audio_get_instance();
    if (global.sfx_half_w <= 1) {
        return [1, 0];
    }

    var _dx = (_lx - global.sfx_half_w) / global.sfx_half_w;
    var _dy = (_ly - global.sfx_half_h) / global.sfx_half_h;
    var _d = sqrt(_dx * _dx + _dy * _dy);
    if (_d > SFX_CUTOFF) {
        return undefined;
    }

    /* Squared falloff: full in the middle of the screen, most of the drop
       happening over the outer half, so the centre of the view stays clearly
       the place you are listening from. */
    var _f = clamp(1 - (_d / SFX_CUTOFF), 0, 1);
    var _gain = SFX_EDGE_GAIN + (1 - SFX_EDGE_GAIN) * _f * _f;
    var _pan = clamp(_dx, -1, 1) * SFX_PAN_MAX;
    return [_gain, _pan];
}

/// Screen position of a map tile, for the parts of the game that make a noise
/// from the simulation rather than from the draw code. undefined when there is
/// no view to ask.
function sfx_screen_from_map_pos(_pos) {
    audio_get_instance();
    if (global.sfx_view == undefined) {
        return undefined;
    }
    return global.sfx_view.screen_pix_from_map_coord(_pos);
}

/// Has this sample been started within the last SFX_REPEAT_MS?
function sfx_repeated(_asset) {
    var _now = current_time;
    for (var _i = 0; _i < SFX_RECENT; _i++) {
        if (global.sfx_recent_asset[_i] == _asset) {
            if (_now - global.sfx_recent_time[_i] < SFX_REPEAT_MS) {
                return true;
            }
            return false;
        }
    }
    return false;
}

function sfx_note_played(_asset) {
    var _now = current_time;
    for (var _i = 0; _i < SFX_RECENT; _i++) {
        if (global.sfx_recent_asset[_i] == _asset) {
            global.sfx_recent_time[_i] = _now;
            return;
        }
    }
    global.sfx_recent_asset[global.sfx_recent_next] = _asset;
    global.sfx_recent_time[global.sfx_recent_next] = _now;
    global.sfx_recent_next = (global.sfx_recent_next + 1) % SFX_RECENT;
}

/// Start _asset on one of the four voices. _gain is 0..1 before the base level,
/// _pan is -1..1. _force is for interface feedback, which is answering the
/// player and must never be swallowed by the map being busy.
///
/// Returns true if it was played.
function sfx_start(_asset, _gain, _pan, _force) {
    audio_get_instance();
    if (!global.audio_sfx_enabled) {
        return false;
    }
    if (!_force && sfx_repeated(_asset)) {
        return false;
    }

    /* A free voice: one that has never been used, or whose sound has ended. */
    var _slot = -1;
    for (var _i = 0; _i < SFX_VOICES; _i++) {
        if (global.sfx_voice_handle[_i] < 0) {
            _slot = _i;
            break;
        }
        if (!audio_is_playing(global.sfx_voice_handle[_i])) {
            _slot = _i;
            break;
        }
    }

    /* All four busy: take the quietest, but only for something louder than it,
       so a distant hammer never interrupts a fight in front of you. */
    if (_slot < 0) {
        var _worst = 0;
        for (var _j = 1; _j < SFX_VOICES; _j++) {
            if (global.sfx_voice_gain[_j] < global.sfx_voice_gain[_worst]) {
                _worst = _j;
            }
        }
        if (!_force && _gain <= global.sfx_voice_gain[_worst]) {
            return false;
        }
        audio_stop_sound(global.sfx_voice_handle[_worst]);
        _slot = _worst;
    }

    /* There is no audio_sound_pan() in GML - panning comes from where an
       emitter sits relative to the listener, and nowhere else. Each voice
       therefore owns an emitter, which is moved left or right of the listener
       and given the voice's gain BEFORE the sound starts on it, so nothing is
       ever heard at full level or in the wrong ear for a frame first.
       audio_emitter_falloff() has set the reference distance so that no
       emitter position we ever use is attenuated, so moving the emitter
       changes which speaker the sound comes from and never how loud it is:
       distance is our business, not the audio engine's. */
    var _place_pan = _pan;
    if (!global.sfx_stereo) {
        _place_pan = 0;
    }

    var _handle = -1;
    if (SFX_USE_EMITTERS) {
        var _emitter = global.sfx_voice_emitter[_slot];
        audio_emitter_gain(_emitter, _gain * SFX_BASE_GAIN);
        audio_emitter_position(_emitter, _place_pan * SFX_PAN_DISTANCE, 0, 0);
        _handle = audio_play_sound_on(_emitter, _asset, false, 10);
    } else {
        _handle = audio_play_sound(_asset, 10, false);
        audio_sound_gain(_handle, _gain * SFX_BASE_GAIN, 0);
    }

    /* The Amiga sounds are played back at the rate the Amiga played them.
       See SFX_AMIGA_PITCH: they were extracted at 8000 Hz and the hardware
       ran them at 28604, so without this every sound in the game is more than
       three semitone-octaves low and three times too long. Only the sounds
       that came out of the Amiga data are corrected - the cheat's own samples
       were generated at 44100 and are already right. */
    if (_handle >= 0 && sfx_is_amiga_asset(_asset)) {
        audio_sound_pitch(_handle, SFX_AMIGA_PITCH);
    }

    global.sfx_voice_handle[_slot] = _handle;
    global.sfx_voice_gain[_slot] = _gain;
    sfx_note_played(_asset);
    return true;
}

/// Sound asset for a Freeserf sound index, or -1 if the Amiga data has no such
/// sample.
function sfx_asset_for(_id) {
    var _n = array_length(global.sound_index_map);
    for (var _i = 0; _i < _n; _i++) {
        if (global.sound_index_map[_i] == _id) {
            return global.sound_assets[_i];
        }
    }
    return -1;
}

/// Playback rate correction for the Amiga sound effects.
///
/// Read off the original, not guessed. data/TheSettlers sets every one of
/// Paula's four channel period registers to the same hardcoded value:
///
///     move.w #$7c, $dff0a6      (and $dff0b6, $dff0c6, $dff0d6)
///
/// $7c is 124, and on PAL the sample rate is 3546895 / period, so the game
/// plays all of its effects at 28604 Hz. Ours were extracted from the same
/// data as 8000 Hz WAVs - the sample COUNTS match the raw Amiga bytes exactly,
/// so nothing was resampled, only mislabelled. Everything has therefore been
/// playing at 8000/28604 of the intended pitch, and lasting the reciprocal of
/// that: a bird chirp meant to be a 33 ms tweet came out a 119 ms warble, and
/// the whole game sounded like a tape running slow.
///
/// The register therefore says 28604 Hz, and 28604 / 8000 would be 3.5755.
///
/// SFX_AMIGA_RATE is set to HALF that - 14302 Hz, a pitch of 1.788 - because
/// that is what sounds right, and it is exactly one octave down rather than
/// some arbitrary taste correction. A factor of exactly two is suspicious
/// enough that there is probably a second mechanism at work: the #$7c block
/// may be an init for one purpose while the effects take their period from a
/// table set elsewhere. A scan for other period writes turned up nothing but
/// false positives, so that is a guess and is not claimed as a finding - the
/// one thing actually read off the hardware is the 28604 above.
///
/// If the missing table ever turns up, this is the single number to change.
#macro SFX_AMIGA_RATE   14302
#macro SFX_WAV_RATE     8000
#macro SFX_AMIGA_PITCH  (SFX_AMIGA_RATE / SFX_WAV_RATE)

/// Is this one of the sounds that came out of the Amiga data? The cheat's own
/// samples were generated at 44100 and must not be touched.
function sfx_is_amiga_asset(_asset) {
    var _n = array_length(global.sound_assets);
    for (var _i = 0; _i < _n; _i++) {
        if (global.sound_assets[_i] == _asset) {
            return true;
        }
    }
    return false;
}

/// Plays the sound effect with Freeserf sound index _id (if the Amiga data has
/// it), centred and at full level. This is the interface's voice - clicks,
/// refusals, the message chime - so it is never positioned and never dropped.
function play_sfx(_id) {
    var _asset = sfx_asset_for(_id);
    if (_asset < 0) {
        return false;
    }
    return sfx_start(_asset, 1, 0, true);
}

/// Plays the sound effect for something on the map, drawn at _lx,_ly in
/// viewport logical pixels: quieter the further it is from the middle of the
/// view, panned towards the side it is on, and not played at all when it is off
/// the edge.
function play_sfx_at(_id, _lx, _ly) {
    var _place = sfx_place(_lx, _ly);
    if (_place == undefined) {
        return false;
    }
    var _asset = sfx_asset_for(_id);
    if (_asset < 0) {
        return false;
    }
    return sfx_start(_asset, _place[0], _place[1], false);
}

/// As play_sfx_at, but for a sound raised from the simulation, which knows a
/// map position rather than a screen one.
function play_sfx_at_map_pos(_id, _pos) {
    var _s = sfx_screen_from_map_pos(_pos);
    if (_s == undefined) {
        return play_sfx(_id);
    }
    return play_sfx_at(_id, _s[0], _s[1]);
}

// ---------------------------------------------------------------------------
// Minimal port of Freeserf's Audio singleton (src/audio.h) used by the options
// popup: music player, sound player and a volume controller.

function audio_init() {
    global.audio_music_enabled = true;
    global.audio_sfx_enabled = true;
    global.audio_volume = 1.0;
    global.audio_music_id = -1;

    /* The four voices, and a short history of what was started when. Both are
       laid out here rather than being grown on demand, so nothing anywhere has
       to ask whether a slot exists yet. */
    global.sfx_voice_handle = array_create(SFX_VOICES, -1);
    global.sfx_voice_gain = array_create(SFX_VOICES, 0);
    global.sfx_recent_asset = array_create(SFX_RECENT, -1);
    global.sfx_recent_time = array_create(SFX_RECENT, -100000);
    global.sfx_recent_next = 0;

    /* Stereo placement on by default. Mono only zeroes the pan; the
       distance-from-centre volume is not a stereo effect and stays either way. */
    global.sfx_stereo = true;

    /* Pin the ear before anything is placed against it. These are the usual
       defaults - at the origin, facing -Z with +Y up - and the cross product of
       those two puts +X at the right-hand speaker, which is exactly what
       sfx_place() assumes when it hands back a pan taken from the horizontal
       offset. Stating them costs nothing and means the whole stereo image no
       longer rests on an assumption about what the runtime happens to start
       with. */
    audio_listener_position(0, 0, 0);
    audio_listener_orientation(0, 0, -1, 0, 1, 0);

    /* One emitter per voice. GML has no function that pans a playing sound;
       stereo placement comes only from where an emitter sits relative to the
       listener, so a voice that can be panned has to own one. The falloff
       reference is set so that no position we ever use is attenuated, which
       takes the engine's distance model out of the gain entirely - the
       emitter's position decides the ear, sfx_place() decides the level, and
       the two never argue. Created once and kept for the life of the process;
       there are four of them. */
    global.sfx_voice_emitter = array_create(SFX_VOICES, -1);
    for (var _v = 0; _v < SFX_VOICES; _v++) {
        var _em = audio_emitter_create();
        /* max is deliberately not equal to ref: the linear falloff model
           divides by (max - ref), and this project never sets a model, so it
           must be safe under whichever one is the default. */
        audio_emitter_falloff(_em, SFX_PAN_REF, SFX_PAN_MAX_DIST, 1);
        audio_emitter_position(_em, 0, 0, 0);
        audio_emitter_gain(_em, 1);
        global.sfx_voice_emitter[_v] = _em;
    }

    /* No view yet: positional sounds play centred until the viewport says
       otherwise. */
    global.sfx_view = undefined;
    global.sfx_half_w = 0;
    global.sfx_half_h = 0;
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

function settlers_play_music() {
    var _a = audio_get_instance();
    if (global.audio_music_id == -1) {
        global.audio_music_id = audio_play_sound(mus_settlers, 1, true);
        if (!global.audio_music_enabled) {
            audio_pause_sound(global.audio_music_id);
        }
    }
}

/// Stop every sound effect at once, leaving the music playing.
///
/// Needed because leaving a finished game for the start screen used to take the
/// fire with it: the viewport keeps drawing behind the box, draw_burning_building
/// retriggers Sfx.burning as each building's burn counter rolls over, and a map
/// full of burning buildings after a victory means that never lets up.
///
/// This is a stop rather than a fade, and it stops by ASSET rather than by
/// voice handle, because the "borntodie" sounds do not go through the voice
/// table and a sound may have been started before the mixer existed. Fading by
/// asset instead would leave the gain at zero for every later play of that
/// sound, which is a worse bug than an abrupt stop.
function audio_stop_sfx() {
    var _assets = global.sound_assets;
    for (var _i = 0; _i < array_length(_assets); _i++) {
        if (audio_is_playing(_assets[_i])) {
            audio_stop_sound(_assets[_i]);
        }
    }

    /* The "borntodie" sounds are their own assets and are not in sound_assets. */
    var _cf = [snd_cf_rifle, snd_cf_grenade, snd_cf_explosion, snd_cf_fire,
               snd_cf_hurt1, snd_cf_hurt2, snd_cf_death];
    for (var _j = 0; _j < array_length(_cf); _j++) {
        if (audio_is_playing(_cf[_j])) {
            audio_stop_sound(_cf[_j]);
        }
    }

    /* Free the voices too, or the mixer spends the next four sounds deciding
       whether it is allowed to interrupt something that has already stopped. */
    for (var _k = 0; _k < SFX_VOICES; _k++) {
        global.sfx_voice_handle[_k] = -1;
        global.sfx_voice_gain[_k] = 0;
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

/// Snapshot the whole Game struct. See scr_savegame.
function game_store_save(_path, _game) {
    return savegame_save_path(_path, _game);
}

/// Read a snapshot back. Returns a Game, or undefined.
function game_store_load(_path) {
    return savegame_load_path(_path);
}
