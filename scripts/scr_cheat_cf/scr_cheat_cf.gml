/// scr_cheat_cf.gml
/// "borntodie" cheat: the player's knights fight as commandos.
///
/// Name any save "borntodie" (the slot label or the file name, case and
/// surrounding spaces ignored) and player 0's knights are redrawn as soldiers
/// who shoot and grenade their way into enemy buildings, which burn instead of
/// being captured.
///
/// Design note: the ported Freeserf combat state machine is NOT rewritten. The
/// same fight is fought, with the same morale maths, the same move sequence and
/// the same win/lose transitions. This file only
///   (a) substitutes what gets drawn,
///   (b) hangs muzzle flashes, tracers, grenades, fire and sound off the moves
///       the fight is already making, and
///   (c) swaps the single "occupy the enemy building" step for "burn it down".
/// Everything here is original work: no asset or code comes from any commercial
/// game.

// ---------------------------------------------------------------- constants

/// Frame layout of spr_cf_soldier (65 frames, 32x32, origin 16,20).
/// Directions are the Settlers hex directions:
///   0 right, 1 down_right, 2 down, 3 left, 4 up_left, 5 up
#macro CF_WALK  0     // dir * 4 + phase(0..3)   -> 0..23
#macro CF_STAND 24    // dir                     -> 24..29
#macro CF_FIRE  30    // dir * 2 + phase(0..1)   -> 30..41
#macro CF_THROW 42    // dir * 2 + phase(0..1)   -> 42..53
#macro CF_HIT   54    // dir                     -> 54..59
#macro CF_DIE   60    // phase(0..4)             -> 60..64

/// Frame layout of spr_cf_fx (21 frames, 16x16, origin 8,8).
#macro CF_FX_FLASH  0     // 3 frames
#macro CF_FX_GREN   3     // 3 frames
#macro CF_FX_BOOM   6     // 6 frames
#macro CF_FX_FIRE   12    // 6 frames
#macro CF_FX_IMPACT 18    // 3 frames

#macro CF_CHEAT_WORD "borntodie"

/// How far back from the building the attacker is drawn, in screen pixels.
/// Purely cosmetic - the serf's map position is untouched, so nothing in the
/// game logic can be confused by it.
#macro CF_STANDOFF_X 13
#macro CF_STANDOFF_Y 7

/// Ticks a burst of rifle rounds is spread over, and rounds per burst.
#macro CF_BURST_GAP 6
#macro CF_BURST_ROUNDS 3

/// Every Nth exchange in a fight is a grenade rather than rifle fire.
#macro CF_GRENADE_EVERY 3

#macro CF_FX_LIMIT 192

enum CfFx {
    flash,
    tracer,
    grenade,
    boom,
    fire,
    impact
}

// ---------------------------------------------------------------- state

/// Called once from obj_game Create. Every global this file reads is created
/// here, so nothing downstream has to test whether it exists yet.
function cf_init() {
    global.cf_active = false;
    global.cf_fx = [];
    global.cf_fx_count = 0;
    global.cf_shot_cool = 0;
}

function cf_is_active() {
    return global.cf_active;
}

function cf_set_active(_on) {
    if (global.cf_active == _on) {
        return;
    }
    global.cf_active = _on;
    if (_on) {
        show_debug_message("cheat: BORN TO DIE - the lads are up");
    } else {
        show_debug_message("cheat: borntodie off");
    }
}

/// True when _name is the cheat word. Case, surrounding whitespace and a
/// trailing ".save" are all ignored, so every route into the save system
/// (slot label, typed file name, autosave label) is covered by one test.
function cf_name_is_cheat(_name) {
    if (!is_string(_name)) {
        return false;
    }
    var _n = string_lower(string_trim(_name));
    var _dot = string_last_pos(".", _n);
    if (_dot != 0) {
        var _ext = string_copy(_n, _dot + 1, string_length(_n) - _dot);
        if (_ext == "save" || _ext == "json") {
            _n = string_copy(_n, 1, _dot - 1);
            _n = string_trim(_n);
        }
    }
    return _n == CF_CHEAT_WORD;
}

/// Save/load funnel both call this with whatever the player named the save.
/// Naming a save "borntodie" arms the cheat; it stays armed for the session
/// and travels inside the snapshot, so reloading that save comes back armed.
function cf_check_name(_name) {
    if (cf_name_is_cheat(_name)) {
        cf_set_active(true);
        return true;
    }
    return false;
}

/// Randomness for cosmetics only. This deliberately uses GameMaker's own
/// generator rather than the game's random_int(): that one is part of the
/// simulation and its call sequence has to stay identical for a reloaded save
/// to play out the same way, so decoration must never draw from it.
function cf_rand(_n) {
    return irandom(_n - 1);
}

// ---------------------------------------------------------------- who is a soldier

/// Player 0's knights only. A knight that has just died has been re-typed to
/// SerfType.dead, so the death animation band is accepted as well - otherwise
/// a soldier would flick back to a knight sprite at the moment he is shot.
function cf_is_soldier(_serf) {
    if (!global.cf_active) {
        return false;
    }
    if (_serf.get_owner() != 0) {
        return false;
    }
    var _type = _serf.get_type();
    if (_type >= SerfType.knight0 && _type <= SerfType.knight4) {
        return true;
    }
    if (_type == SerfType.dead) {
        var _anim = _serf.get_animation();
        return _anim >= 147 && _anim <= 165;
    }
    return false;
}

// ---------------------------------------------------------------- pose

/// Walking animations are laid out as 4 + h_diff + 9 * d with h_diff in
/// -4..4, so animation `a` in 0..80 belongs to direction a div 9, and
/// directions 6..8 are the "switch position" duplicates of 0..2.
function cf_dir_from_animation(_anim) {
    if (_anim >= 0 && _anim <= 80) {
        var _d = _anim div 9;
        if (_d >= 6) {
            _d -= 6;
        }
        return _d;
    }
    if (_anim >= 81 && _anim <= 86) {
        return _anim - 81;
    }
    if (_anim >= 110 && _anim <= 115) {
        return _anim - 110;
    }
    return -1;
}

/// The facing to draw a soldier at. Serfs remember the last direction they
/// actually walked in (Serf.cf_facing, initialised in the Serf constructor),
/// so a soldier standing still or fighting keeps looking the way he came.
function cf_facing_of(_serf) {
    var _d = cf_dir_from_animation(_serf.get_animation());
    if (_d >= 0) {
        _serf.cf_facing = _d;
        return _d;
    }
    return _serf.cf_facing;
}

/// Frame of spr_cf_soldier to draw for this serf right now.
function cf_frame_for(_serf) {
    var _dir = cf_facing_of(_serf);
    var _state = _serf.get_state();
    var _anim = _serf.get_animation();
    var _counter = _serf.get_counter();

    // dying: 5-frame fall, played out over the 255-tick death counter
    if (_serf.get_type() == SerfType.dead) {
        var _p = ((255 - _counter) * 5) div 256;
        if (_p < 0) {
            _p = 0;
        }
        if (_p > 4) {
            _p = 4;
        }
        return CF_DIE + _p;
    }

    switch (_state) {
    case SerfState.knight_attacking:
    case SerfState.knight_attacking_free:
        // Rifle fire, or the throwing pose on a grenade exchange. attacking_move
        // steps once per exchange, so it is what decides which.
        if ((_serf.s.attacking_move mod CF_GRENADE_EVERY) == (CF_GRENADE_EVERY - 1)) {
            var _tp = 0;
            if (_counter < 48) {
                _tp = 1;
            }
            return CF_THROW + _dir * 2 + _tp;
        }
        var _fp = 0;
        if ((_counter >> 3) & 1) {
            _fp = 1;
        }
        return CF_FIRE + _dir * 2 + _fp;

    case SerfState.knight_prepare_attacking:
    case SerfState.knight_prepare_attacking_free:
    case SerfState.knight_engaging_building:
    case SerfState.knight_attacking_victory:
    case SerfState.knight_attacking_victory_free:
    case SerfState.knight_occupy_enemy_building:
        return CF_FIRE + _dir * 2;

    case SerfState.knight_defending:
    case SerfState.knight_defending_free:
    case SerfState.knight_prepare_defending:
    case SerfState.knight_prepare_defending_free:
        return CF_HIT + _dir;

    default:
        break;
    }

    // walking bands
    if ((_anim >= 0 && _anim <= 80) || (_anim >= 110 && _anim <= 115)) {
        var _wp = (_counter >> 3) mod 4;
        if (_wp < 0) {
            _wp = -_wp mod 4;
        }
        return CF_WALK + _dir * 4 + _wp;
    }

    return CF_STAND + _dir;
}

/// Cosmetic pull-back so an attacker and his target are not standing on the
/// same pixel. Returns [dx, dy] in screen pixels.
function cf_standoff(_serf, _is_defender) {
    var _state = _serf.get_state();
    var _fighting = (_state == SerfState.knight_attacking ||
                     _state == SerfState.knight_attacking_free ||
                     _state == SerfState.knight_prepare_attacking ||
                     _state == SerfState.knight_prepare_attacking_free);
    if (!_fighting) {
        return [0, 0];
    }
    if (_is_defender) {
        return [-CF_STANDOFF_X, -CF_STANDOFF_Y];
    }
    return [CF_STANDOFF_X, CF_STANDOFF_Y];
}

/// Draw a soldier where draw_row_serf would have drawn the knight.
/// `_colour` is the player colour the knight would have been masked with. It is
/// unused while the cheat is scoped to player 0 - every soldier on screen is
/// the player's - and is kept in the signature so that widening the scope later
/// only means tinting here.
function cf_draw_soldier(_lx, _ly, _colour, _serf) {
    draw_sprite(spr_serf_shadow, 0, _lx, _ly);
    draw_sprite(spr_cf_soldier, cf_frame_for(_serf), _lx, _ly);
}

// ---------------------------------------------------------------- effects

/// One-shot visual. `_pos` is a map position; `_ox`/`_oy` are pixel offsets
/// from that tile's screen origin, so effects scroll correctly with the map.
function cf_fx_add(_kind, _pos, _ox, _oy, _life, _delay) {
    if (global.cf_fx_count >= CF_FX_LIMIT) {
        return undefined;
    }
    var _fx = {
        kind: _kind,
        pos: _pos,
        ox: _ox,
        oy: _oy,
        tx: _ox,
        ty: _oy,
        life: _life,
        life_max: _life,
        delay: _delay,
        boom_on_end: false,
        boom_sound: false
    };
    array_push(global.cf_fx, _fx);
    global.cf_fx_count = array_length(global.cf_fx);
    return _fx;
}

/// One tick of effect life. Called once per game tick from obj_game Step.
function cf_fx_update() {
    if (global.cf_shot_cool > 0) {
        global.cf_shot_cool -= 1;
    }

    var _n = array_length(global.cf_fx);
    if (_n == 0) {
        return;
    }

    // Survivors are collected first and the list is replaced before anything
    // new is spawned: cf_fx_add() appends to global.cf_fx, so spawning during
    // the sweep would push onto the list that is about to be thrown away.
    var _keep = [];
    var _detonate = [];
    for (var _i = 0; _i < _n; _i++) {
        var _fx = global.cf_fx[_i];
        if (_fx.delay > 0) {
            _fx.delay -= 1;
            array_push(_keep, _fx);
            continue;
        }
        _fx.life -= 1;
        if (_fx.life > 0) {
            array_push(_keep, _fx);
            continue;
        }
        if (_fx.boom_on_end) {
            array_push(_detonate, _fx);
        }
    }
    global.cf_fx = _keep;
    global.cf_fx_count = array_length(_keep);

    var _d = array_length(_detonate);
    for (var _j = 0; _j < _d; _j++) {
        var _g = _detonate[_j];
        var _b = cf_fx_add(CfFx.boom, _g.pos, _g.tx, _g.ty, 30, 0);
        if (_b != undefined && _g.boom_sound) {
            cf_play(snd_cf_explosion);
        }
    }
}

/// Drawn by the viewport after the serf rows, so effects sit on top.
/// `_view` is the Viewport (for screen_pix_from_map_coord), `_ox`/`_oy` its
/// own screen origin.
function cf_fx_draw(_view, _ox, _oy) {
    var _n = array_length(global.cf_fx);
    if (_n == 0) {
        return;
    }
    for (var _i = 0; _i < _n; _i++) {
        var _fx = global.cf_fx[_i];
        if (_fx.delay > 0) {
            continue;
        }
        var _s = _view.screen_pix_from_map_coord(_fx.pos);
        var _sx = _ox + _s[0];
        var _sy = _oy + _s[1];
        var _t = 1.0 - (_fx.life / _fx.life_max);   // 0 at birth, 1 at death

        switch (_fx.kind) {
        case CfFx.flash:
            draw_sprite(spr_cf_fx, CF_FX_FLASH + min(2, floor(_t * 3)),
                        _sx + _fx.ox, _sy + _fx.oy);
            break;

        case CfFx.tracer: {
            // a short bright dash travelling from muzzle to target
            var _hx = lerp(_fx.ox, _fx.tx, _t);
            var _hy = lerp(_fx.oy, _fx.ty, _t);
            var _bx = lerp(_fx.ox, _fx.tx, max(0, _t - 0.28));
            var _by = lerp(_fx.oy, _fx.ty, max(0, _t - 0.28));
            draw_line_colour(_sx + _bx, _sy + _by, _sx + _hx, _sy + _hy,
                             make_colour_rgb(255, 184, 62),
                             make_colour_rgb(255, 246, 190));
            break;
        }

        case CfFx.grenade: {
            // parabolic arc: linear across, with a lob added to the height
            var _gx = lerp(_fx.ox, _fx.tx, _t);
            var _gy = lerp(_fx.oy, _fx.ty, _t) - 14 * sin(pi * _t);
            draw_sprite(spr_cf_fx, CF_FX_GREN + (floor(_t * 9) mod 3),
                        _sx + _gx, _sy + _gy);
            break;
        }

        case CfFx.boom:
            draw_sprite(spr_cf_fx, CF_FX_BOOM + min(5, floor(_t * 6)),
                        _sx + _fx.ox, _sy + _fx.oy);
            break;

        case CfFx.fire:
            draw_sprite(spr_cf_fx, CF_FX_FIRE + (floor(_t * 24) mod 6),
                        _sx + _fx.ox, _sy + _fx.oy);
            break;

        case CfFx.impact:
            draw_sprite(spr_cf_fx, CF_FX_IMPACT + min(2, floor(_t * 3)),
                        _sx + _fx.ox, _sy + _fx.oy);
            break;

        default:
            break;
        }
    }
}

/// Sound effects go through the game's own sfx enable flag, so the options
/// popup still turns them off.
function cf_play(_snd) {
    if (!audio_get_instance().sfx.is_enabled()) {
        return;
    }
    audio_play_sound(_snd, 10, false);
}

/// Rifle fire specifically: several fights running at once would otherwise
/// stack a burst per fight per exchange into a wall of noise, so gunfire is
/// rate-limited across the whole map. Everything else plays unthrottled.
function cf_play_rifle() {
    if (global.cf_shot_cool > 0) {
        return;
    }
    global.cf_shot_cool = 5;
    cf_play(snd_cf_rifle);
}

// ---------------------------------------------------------------- fight hooks

/// Called from serf_handle_knight_attacking every time the fight advances one
/// exchange. Nothing about the fight's outcome depends on this; it only makes
/// the noise and the tracers.
function cf_on_fight_step(_attacker, _defender, _move) {
    if (!global.cf_active) {
        return;
    }
    if (!cf_is_soldier(_attacker) && !cf_is_soldier(_defender)) {
        return;
    }

    var _pos = _attacker.pos;
    var _mx = CF_STANDOFF_X;
    var _my = CF_STANDOFF_Y - 9;          // muzzle height off the ground
    var _tx = -CF_STANDOFF_X;
    var _ty = -CF_STANDOFF_Y - 6;         // target: the defender's chest

    if ((_attacker.s.attacking_move mod CF_GRENADE_EVERY) == (CF_GRENADE_EVERY - 1)) {
        var _g = cf_fx_add(CfFx.grenade, _pos, _mx, _my - 2, 26, 10);
        if (_g != undefined) {
            _g.tx = _tx;
            _g.ty = _ty + 6;
            _g.boom_on_end = true;
            _g.boom_sound = true;
        }
        cf_play(snd_cf_grenade);
        return;
    }

    // a short burst rather than one shot per exchange - it should sound like
    // an automatic weapon, not a musket
    for (var _r = 0; _r < CF_BURST_ROUNDS; _r++) {
        var _d = _r * CF_BURST_GAP;
        var _spread = cf_rand(5) - 2;
        cf_fx_add(CfFx.flash, _pos, _mx + 5, _my, 3, _d);
        var _tr = cf_fx_add(CfFx.tracer, _pos, _mx + 6, _my, 5, _d);
        if (_tr != undefined) {
            _tr.tx = _tx;
            _tr.ty = _ty + _spread;
        }
        cf_fx_add(CfFx.impact, _pos, _tx, _ty + _spread, 6, _d + 4);
    }
    cf_play_rifle();

    /* Not every burst draws blood, so the grunts stay occasional rather than
       becoming a drone under a long fight. */
    if (cf_rand(3) == 0) {
        cf_on_hurt(_defender);
    }
}

/// Called when one side of a fight is about to die. `_loser` is the serf that
/// goes down; `_won` says whether the attacker won, for the log only.
function cf_on_fight_end(_attacker, _defender, _attacker_won) {
    if (!global.cf_active) {
        return;
    }
    var _loser = _defender;
    if (_attacker_won == 0) {
        _loser = _attacker;
    }
    cf_fx_add(CfFx.impact, _loser.pos, 0, -8, 8, 0);
    cf_play(snd_cf_death);
}

/// Called when a soldier takes a hit but stays up.
function cf_on_hurt(_serf) {
    if (!global.cf_active) {
        return;
    }
    if (cf_rand(2) == 0) {
        cf_play(snd_cf_hurt1);
    } else {
        cf_play(snd_cf_hurt2);
    }
}

// ---------------------------------------------------------------- buildings

/// Replaces "capture the enemy building" while the cheat is on: the soldiers
/// burn it instead. Returns true when the building was torched, false when the
/// normal capture path should run after all.
function cf_burn_enemy_building(_serf, _building) {
    if (!global.cf_active) {
        return false;
    }
    if (_serf.get_owner() != 0) {
        return false;
    }
    if (_building.is_burning()) {
        return false;
    }

    var _pos = _building.get_position();

    // a grenade goes through the door first, then the place goes up
    cf_fx_add(CfFx.boom, _pos, 0, -12, 30, 0);
    for (var _i = 0; _i < 5; _i++) {
        var _fx = cf_fx_add(CfFx.fire, _pos,
                            cf_rand(17) - 8, -4 - cf_rand(12),
                            110 + cf_rand(80), 6 * _i);
        if (_fx == undefined) {
            break;
        }
    }
    cf_play(snd_cf_explosion);
    cf_play(snd_cf_fire);

    _building.burnup();
    show_debug_message("cheat: building at " + string(_pos) + " torched");
    return true;
}
