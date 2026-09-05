/// scr_cheat_cf.gml
/// "borntodie" cheat: the player's knights fight as commandos.
///
/// Name any save "borntodie" (the slot label or the file name, case and
/// surrounding spaces ignored) and player 0's knights become soldiers who
/// besiege enemy buildings instead of duelling for them.
///
/// The assault, in order:
///   1. The soldier sets off exactly as a knight would, and stops as soon as his
///      target is within CF_SIEGE_RANGE tiles - he does not walk to the door.
///   2. He shoots it. Four rifle rounds, then a lobbed grenade, repeating.
///      Twenty rounds and five grenades bring a building down.
///   3. The building burns. Its garrison is turned out into the open by the
///      game's own burnup(), which is what ejects knights from a demolished
///      military building.
///   4. The soldiers shoot the knights as they come out - three hits each.
///   5. With nothing left standing, they walk home.
///
/// Design note: the ported Freeserf combat state machine is NOT rewritten and
/// its duel is never entered by a besieging soldier. The siege is a small state
/// machine of its own that runs entirely inside SerfState.knight_engaging_building
/// - the one state a knight is already in when he arrives at an enemy building -
/// and hands the serf back to the ported code, via SerfState.lost, when it is
/// finished with him. A soldier who is DEFENDING one of the player's own huts is
/// untouched by all this and fights the normal ported duel, dressed as a soldier.
///
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

/// Death animations, for spotting a knight who has already been killed:
/// the ported code uses 147 + type for a beaten defender and 152 + type for a
/// beaten attacker, and knight types run 22..26, so the whole band is 169..178.
#macro CF_DEATH_ANIM_LO 169
#macro CF_DEATH_ANIM_HI 178

/// Siege economics. A soldier fires four rounds then lobs a grenade, so each
/// cycle of five shots does 4 * CF_DMG_BULLET + CF_DMG_GRENADE = 13 damage.
/// How much a building takes depends on its type; a castle is a real siege.
#macro CF_DMG_BULLET      2
#macro CF_DMG_GRENADE     5
#macro CF_SHOT_CYCLE      5      // every 5th shot is a grenade

#macro CF_HP_HUT          80
#macro CF_HP_TOWER        140
#macro CF_HP_FORTRESS     220
#macro CF_HP_CASTLE       300
#macro CF_HP_DEFAULT      80     // anything else the lads decide to shoot at
#macro CF_FIRE_INTERVAL   25     // ticks between shots (50 ticks = 1 second)
#macro CF_GRENADE_FLIGHT  22     // ticks a grenade spends in the air

/// Mopping up the garrison once it is turned out.
#macro CF_KNIGHT_HP    3         // rifle hits to put a knight down in the open
#macro CF_MOP_RADIUS   61        // spiral positions searched (radius 4)
#macro CF_MOP_INTERVAL 18        // ticks between shots at a man in the open

/// Hold fire for three seconds after a building comes down. burnup() turns the
/// garrison out, but they need a moment to actually walk clear of the rubble -
/// without the pause the lads shoot at the doorway before anyone is standing in
/// it, and the survivors then scatter before the first target is even acquired.
#macro CF_MOP_DELAY    150       // 50 ticks = 1 second

/// How far out the lads will open up on a building, in map tiles. A knight sent
/// to attack stops as soon as his target comes within this range instead of
/// walking all the way to the door. Three tiles is "somewhere in the local
/// surroundings" - close enough to read as one action on screen, far enough that
/// they are visibly shooting at the place rather than standing in the doorway.
#macro CF_SIEGE_RANGE 3

/// Muzzle height above the tile origin, in screen pixels, and how far along the
/// soldier-to-target line the muzzle flash sits. Both flash and tracer are given
/// the soldier's tile and the target's tile and resolved to the screen at draw
/// time, so the flash lands on the barrel line whichever way he is facing -
/// there is no way to get that right from the hex direction alone, because a
/// hex step is not a fixed screen vector.
#macro CF_MUZZLE_Y -10
#macro CF_FLASH_T  0.16

#macro CF_FX_LIMIT 192

/// Serf.cf_mode
enum CfMode {
    none = 0,       // not under cheat control
    siege = 1,      // shooting at a building
    mopping = 2,    // shooting at a knight in the open
    withdraw = 3    // done, walk home
}

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
            _n = string_trim(string_copy(_n, 1, _dot - 1));
        }
    }
    return _n == CF_CHEAT_WORD;
}

/// Save/load funnel both call this with whatever the player named the save.
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

/// Player 0's knights only. A knight who has just died has been re-typed to
/// SerfType.dead, so the death animation band is accepted as well - otherwise a
/// soldier would flick back to a knight sprite at the moment he is shot.
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
        return _anim >= CF_DEATH_ANIM_LO && _anim <= CF_DEATH_ANIM_HI;
    }
    return false;
}

/// How much damage this building type absorbs before it comes down. A pure
/// function of the type, so it is safe to call at any moment and nothing has to
/// be initialised or kept in step when a building changes type.
function cf_building_hp_for(_type) {
    switch (_type) {
    case BuildingType.hut:
        return CF_HP_HUT;
    case BuildingType.tower:
        return CF_HP_TOWER;
    case BuildingType.fortress:
        return CF_HP_FORTRESS;
    case BuildingType.castle:
        return CF_HP_CASTLE;
    default:
        return CF_HP_DEFAULT;
    }
}

/// True while the cheat is driving this serf, i.e. he is besieging or mopping
/// up rather than running the ported state machine.
function cf_in_siege(_serf) {
    return _serf.cf_mode != CfMode.none;
}

/// Distance in tiles between two map positions on the Settlers hex grid.
/// The six directions are right (1,0), down_right (1,1), down (0,1) and their
/// opposites, so a step can change column and row together when the two deltas
/// share a sign - that is the case where the distance is the larger of the two
/// rather than their sum.
function cf_hex_dist(_dc, _dr) {
    if ((_dc >= 0 && _dr >= 0) || (_dc <= 0 && _dr <= 0)) {
        return max(abs(_dc), abs(_dr));
    }
    return abs(_dc) + abs(_dr);
}

/// Is this a building the lads should be shooting at?
function cf_building_is_target(_bld, _serf) {
    if (_bld == undefined) {
        return false;
    }
    if (!_bld.is_done() || _bld.is_burning()) {
        return false;
    }
    if (_bld.get_owner() == _serf.get_owner()) {
        return false;
    }
    /* An undefended building is left to the ported "occupy it" path, which
       scr_serf_c hands to cf_burn_enemy_building. There is nothing to besiege,
       so there is no point standing off and shooting at it. */
    return _bld.has_knight();
}

/// Put a soldier into the siege, aimed at _bld, wherever he happens to be
/// standing. SerfState.knight_engaging_building is the cheat's home state: the
/// hook at the top of its handler runs cf_siege_tick every update from here on.
function cf_begin_siege(_serf, _bld) {
    var _map = _serf.game.get_map();
    _serf.cf_mode = CfMode.siege;
    _serf.cf_target = _bld.get_index();
    _serf.cf_shots = 0;
    _serf.cf_timer = CF_FIRE_INTERVAL;
    _serf.cf_facing = cf_dir_towards(_map, _serf.pos, _bld.get_position());
    _serf.state = SerfState.knight_engaging_building;
    _serf.animation = 168;
    _serf.counter = 0;
    _serf.tick = _serf.game.get_tick() & 0xFFFF;

    /* A besieging soldier has no duel partner. This matters because the ported
       code only ever clears s.attacking_def_index on the way out of a duel it
       actually finished, so a knight who once engaged someone in the field can
       still be carrying that serf's index - and the viewport draws an
       "additional serf" for anyone in knight_engaging_building whose index is
       non-zero. */
    _serf.s.attacking_def_index = 0;

    if (_bld.is_under_attack()) {
        _serf.game.get_player(_bld.get_owner()).add_notification(
            MessageType.under_attack, _bld.get_position(), _serf.get_owner());
    }
    show_debug_message("cheat: soldier " + string(_serf.get_index()) +
                       " opening up on building " + string(_serf.cf_target));
}

/// Called from serf_handle_state_knight_free_walking, i.e. while a knight the
/// player sent to attack is still crossing the map. He stops and opens fire as
/// soon as his target is within CF_SIEGE_RANGE rather than walking to the door.
///
/// The target is known exactly, so a soldier can never be hijacked by an enemy
/// building he merely walks past: Player.start_attack sends him off with
/// free_walking_dist_col/row set to map.dist_x/dist_y from HIM to the building
/// he was sent at, and free walking decrements those as he moves, so his
/// destination is always his own position plus what is left of them.
///
/// Returns true when the siege has been opened and the ported free-walking
/// handler should not run.
function cf_try_open_siege(_serf) {
    if (!global.cf_active) {
        return false;
    }
    if (_serf.get_owner() != 0) {
        return false;
    }
    var _type = _serf.get_type();
    if (_type < SerfType.knight0 || _type > SerfType.knight4) {
        return false;
    }

    var _dc = _serf.s.free_walking_dist_col;
    var _dr = _serf.s.free_walking_dist_row;
    if (cf_hex_dist(_dc, _dr) > CF_SIEGE_RANGE) {
        return false;               /* still a long way off, keep walking */
    }

    var _map = _serf.game.get_map();
    var _geom = _map.geom;
    var _dc2 = (_geom.pos_col(_serf.pos) + _dc) & _geom.col_mask;
    var _dr2 = (_geom.pos_row(_serf.pos) + _dr) & _geom.row_mask;
    var _dest = _geom.pos(_dc2, _dr2);

    /* Where dist runs out is NOT the building - it is the attack tile, one step
       down-right of it. start_attack measures dist from the knight while he is
       still inside his own hut, then leave_building() walks him one step
       down-right without decrementing it, so the whole walk is offset by that
       step. Landing on the tile down-right of the target is exactly what the
       ported code wants, because knight_engaging_building looks for its
       building at move_up_left(pos).
       Both tiles are tried rather than trusting the derivation alone. */
    var _bld = _serf.game.get_building_at_pos(_map.move_up_left(_dest));
    if (!cf_building_is_target(_bld, _serf)) {
        _bld = _serf.game.get_building_at_pos(_dest);
    }
    if (!cf_building_is_target(_bld, _serf)) {
        return false;               /* not walking at a building we can besiege */
    }

    cf_begin_siege(_serf, _bld);
    return true;
}

// ---------------------------------------------------------------- geometry

/// The hex direction pointing from _from towards _to, as a best match: the
/// six direction vectors in (col, row) are scored against the offset and the
/// closest wins. Used to aim a soldier at what he is shooting.
function cf_dir_towards(_map, _from, _to) {
    var _geom = _map.geom;
    var _dc = _geom.pos_col(_to) - _geom.pos_col(_from);
    var _dr = _geom.pos_row(_to) - _geom.pos_row(_from);

    // the map wraps, so take the short way round
    var _cols = _geom.cols;
    var _rows = _geom.rows;
    if (_dc > _cols div 2) {
        _dc -= _cols;
    }
    if (_dc < -(_cols div 2)) {
        _dc += _cols;
    }
    if (_dr > _rows div 2) {
        _dr -= _rows;
    }
    if (_dr < -(_rows div 2)) {
        _dr += _rows;
    }

    // Direction.right, down_right, down, left, up_left, up
    var _vec = [1, 0,  1, 1,  0, 1,  -1, 0,  -1, -1,  0, -1];
    var _best = 2;
    var _best_score = -100000;
    for (var _d = 0; _d < 6; _d++) {
        var _score = _dc * _vec[_d * 2] + _dr * _vec[_d * 2 + 1];
        if (_score > _best_score) {
            _best_score = _score;
            _best = _d;
        }
    }
    return _best;
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
/// actually walked in (Serf.cf_facing, initialised in the Serf constructor), so
/// a soldier standing still or shooting keeps looking where he was aimed.
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

    // under siege control: firing or throwing, aimed at cf_facing
    if (_serf.cf_mode == CfMode.siege || _serf.cf_mode == CfMode.mopping) {
        var _since = _serf.cf_last_shot;
        if (_serf.cf_throwing) {
            // wind-up, then the released pose as the grenade leaves his hand -
            // the grenade effect itself is spawned with a matching 6-tick delay
            var _tp = 0;
            if (_since > 5) {
                _tp = 1;
            }
            return CF_THROW + _dir * 2 + _tp;
        }
        var _fp = 0;
        if (_since < 6) {
            _fp = 1;                 // kicked back by the recoil, briefly
        }
        return CF_FIRE + _dir * 2 + _fp;
    }

    // the ported duel, for a soldier defending one of the player's own huts
    switch (_serf.get_state()) {
    case SerfState.knight_attacking:
    case SerfState.knight_attacking_free:
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

    var _anim = _serf.get_animation();
    if ((_anim >= 0 && _anim <= 80) || (_anim >= 110 && _anim <= 115)) {
        var _wp = (_counter >> 3) mod 4;
        if (_wp < 0) {
            _wp = -_wp mod 4;
        }
        return CF_WALK + _dir * 4 + _wp;
    }

    return CF_STAND + _dir;
}


/// Draw a soldier where draw_row_serf would have drawn the knight.
/// `_colour` is the player colour the knight would have been masked with. It is
/// unused while the cheat is scoped to player 0 - every soldier on screen is the
/// player's - and is kept in the signature so that widening the scope later only
/// means tinting here.
function cf_draw_soldier(_lx, _ly, _colour, _serf) {
    draw_sprite(spr_serf_shadow, 0, _lx, _ly);
    draw_sprite(spr_cf_soldier, cf_frame_for(_serf), _lx, _ly);
}

// ---------------------------------------------------------------- effects

/// One visual. `_pos` is the tile it starts on and `_pos2` the tile it ends on;
/// `_ox/_oy` and `_tx/_ty` are pixel offsets from each. Both tiles are resolved
/// to the screen at draw time, so an effect crossing from a soldier to the
/// building he is shooting scrolls correctly with the map.
function cf_fx_add(_kind, _pos, _ox, _oy, _pos2, _tx, _ty, _life, _delay) {
    if (global.cf_fx_count >= CF_FX_LIMIT) {
        return undefined;
    }
    var _fx = {
        kind: _kind,
        pos: _pos,
        ox: _ox,
        oy: _oy,
        pos2: _pos2,
        tx: _tx,
        ty: _ty,
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

/// An effect that stays put on one tile.
function cf_fx_at(_kind, _pos, _ox, _oy, _life, _delay) {
    return cf_fx_add(_kind, _pos, _ox, _oy, _pos, _ox, _oy, _life, _delay);
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
        var _b = cf_fx_at(CfFx.boom, _g.pos2, _g.tx, _g.ty, 30, 0);
        if (_b != undefined && _g.boom_sound) {
            cf_play(snd_cf_explosion);
        }
    }
}

/// Drawn by the viewport after the serf rows, so effects sit on top.
/// `_view` is the Viewport (for screen_pix_from_map_coord), `_ox`/`_oy` its own
/// screen origin.
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
        var _a = _view.screen_pix_from_map_coord(_fx.pos);
        var _ax = _ox + _a[0] + _fx.ox;
        var _ay = _oy + _a[1] + _fx.oy;
        var _bx = _ax;
        var _by = _ay;
        if (_fx.pos2 != _fx.pos) {
            var _b = _view.screen_pix_from_map_coord(_fx.pos2);
            _bx = _ox + _b[0] + _fx.tx;
            _by = _oy + _b[1] + _fx.ty;
        } else {
            _bx = _ox + _a[0] + _fx.tx;
            _by = _oy + _a[1] + _fx.ty;
        }
        var _t = 1.0 - (_fx.life / _fx.life_max);   // 0 at birth, 1 at death

        switch (_fx.kind) {
        case CfFx.flash:
            /* A short way along the line to the target, so it sits on the
               barrel rather than on the soldier's chest. */
            draw_sprite(spr_cf_fx, CF_FX_FLASH + min(2, floor(_t * 3)),
                        lerp(_ax, _bx, CF_FLASH_T), lerp(_ay, _by, CF_FLASH_T));
            break;

        case CfFx.tracer: {
            // a short bright dash travelling from muzzle to target
            var _hx = lerp(_ax, _bx, _t);
            var _hy = lerp(_ay, _by, _t);
            var _t0 = max(0, _t - 0.3);
            draw_line_colour(lerp(_ax, _bx, _t0), lerp(_ay, _by, _t0), _hx, _hy,
                             make_colour_rgb(255, 184, 62),
                             make_colour_rgb(255, 246, 190));
            break;
        }

        case CfFx.grenade: {
            // parabolic arc: straight across, with a lob added to the height
            var _gx = lerp(_ax, _bx, _t);
            var _gy = lerp(_ay, _by, _t) - 18 * sin(pi * _t);
            draw_sprite(spr_cf_fx, CF_FX_GREN + (floor(_t * 9) mod 3), _gx, _gy);
            break;
        }

        case CfFx.boom:
            draw_sprite(spr_cf_fx, CF_FX_BOOM + min(5, floor(_t * 6)), _ax, _ay);
            break;

        case CfFx.fire:
            draw_sprite(spr_cf_fx, CF_FX_FIRE + (floor(_t * 24) mod 6), _ax, _ay);
            break;

        case CfFx.impact:
            draw_sprite(spr_cf_fx, CF_FX_IMPACT + min(2, floor(_t * 3)), _ax, _ay);
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

/// Rifle fire specifically: several assaults running at once would otherwise
/// stack a shot per soldier into a wall of noise, so gunfire is rate-limited
/// across the whole map. Everything else plays unthrottled.
function cf_play_rifle() {
    if (global.cf_shot_cool > 0) {
        return;
    }
    global.cf_shot_cool = 5;
    cf_play(snd_cf_rifle);
}

// ---------------------------------------------------------------- shooting

/// One rifle round from _serf at _target_pos, with a muzzle flash, a tracer and
/// an impact where it lands.
function cf_shoot_at(_serf, _target_pos, _aim_y) {
    var _spread = cf_rand(5) - 2;

    /* Flash and tracer are both given the soldier's tile AND the target's, so
       the line between them is worked out from two real map positions at draw
       time. The flash then sits a short way along that line and is on the
       barrel whichever way he is facing - which cannot be done from the hex
       direction alone, because a hex step is not a fixed screen vector. */
    cf_fx_add(CfFx.flash, _serf.pos, 0, CF_MUZZLE_Y,
              _target_pos, _spread, _aim_y, 3, 0);
    cf_fx_add(CfFx.tracer, _serf.pos, 0, CF_MUZZLE_Y,
              _target_pos, _spread, _aim_y, 5, 0);
    cf_fx_at(CfFx.impact, _target_pos, _spread, _aim_y, 6, 4);
    cf_play_rifle();
    _serf.cf_throwing = false;
    _serf.cf_last_shot = 0;
}

/// One grenade from _serf at _target_pos. It arcs over, then detonates.
function cf_throw_at(_serf, _target_pos, _aim_y) {
    var _g = cf_fx_add(CfFx.grenade, _serf.pos, 0, CF_MUZZLE_Y - 2,
                       _target_pos, cf_rand(7) - 3, _aim_y,
                       CF_GRENADE_FLIGHT, 6);
    if (_g != undefined) {
        _g.boom_on_end = true;
        _g.boom_sound = true;
    }
    cf_play(snd_cf_grenade);
    _serf.cf_throwing = true;
    _serf.cf_last_shot = 0;
}

// ---------------------------------------------------------------- the siege

/// Turn a building into a bonfire and turn its garrison out. burnup() does the
/// whole demolition itself - land ownership, stock, and calling castle_deleted
/// on every knight inside, which is what puts them outside in the open.
function cf_torch_building(_building) {
    if (_building.is_burning()) {
        return;
    }
    var _pos = _building.get_position();
    cf_fx_at(CfFx.boom, _pos, 0, -12, 30, 0);
    for (var _i = 0; _i < 5; _i++) {
        cf_fx_at(CfFx.fire, _pos, cf_rand(17) - 8, -4 - cf_rand(12),
                 110 + cf_rand(80), 6 * _i);
    }
    cf_play(snd_cf_explosion);
    cf_play(snd_cf_fire);
    _building.burnup();
    show_debug_message("cheat: building at " + string(_pos) + " levelled");
}

/// Put an enemy knight down, using the ported code's own death path: the
/// knight_attacking_defeat handler waits out the 255-tick counter, clears the
/// map tile and deletes the serf. set_type(dead) already adjusts the owner's
/// serf counts and military score, so nothing else needs doing here.
function cf_kill_knight(_knight) {
    var _type = _knight.get_type();
    _knight.state = SerfState.knight_attacking_defeat;
    _knight.animation = 152 + _type;
    _knight.counter = 255;
    _knight.tick = _knight.game.get_tick() & 0xFFFF;
    _knight.set_type(SerfType.dead);
    cf_fx_at(CfFx.impact, _knight.pos, 0, -8, 8, 0);
    cf_play(snd_cf_death);
}

/// Is this serf something the lads should be shooting at?
///
/// An enemy knight, yes - but ONLY one who is out in the open and not already a
/// party to a fight the ported state machine is tracking. This restriction is
/// not squeamishness, it is load-bearing: whenever the ported code sets up an
/// engagement it stores one serf's index in the other's s.attacking_def_index
/// and puts the referenced serf into an engagement state. Six handlers in
/// scr_serf_c then dereference that index with no nil check. Shooting a knight
/// out of an engagement deletes him and leaves the index dangling, and the next
/// update of his opponent dies on it - which is exactly the crash the garrison
/// coming out of a burning building produced, because they mill about next to
/// the player's knights and get engaged within a second or two.
///
/// The states below are the ones in which a knight is provably nobody's
/// attacking_def_index. This is re-checked every tick a target is held, and the
/// killing shot happens in the same tick as the check, so a target who steps
/// into a fight mid-burst is dropped rather than killed.
function cf_is_hostile(_serf, _shooter) {
    if (_serf.get_owner() == _shooter.get_owner()) {
        return false;
    }
    var _type = _serf.get_type();
    if (_type < SerfType.knight0 || _type > SerfType.knight4) {
        return false;
    }
    switch (_serf.get_state()) {
    case SerfState.lost:              /* turned out of a burnt building */
    case SerfState.escape_building:   /* on his way out of one */
    case SerfState.walking:           /* crossing the map */
    case SerfState.knight_free_walking:
        return true;
    default:
        return false;
    }
}

/// Nearest enemy knight in the open, or 0 if the coast is clear.
function cf_find_target(_serf) {
    var _map = _serf.game.get_map();
    for (var _i = 0; _i < CF_MOP_RADIUS; _i++) {
        var _p = _map.pos_add_spirally(_serf.pos, _i);
        if (!_map.has_serf(_p)) {
            continue;
        }
        var _other = _serf.game.get_serf_at_pos(_p);
        if (_other == undefined) {
            continue;
        }
        if (cf_is_hostile(_other, _serf)) {
            return _other.get_index();
        }
    }
    return 0;
}

/// Safety net for a duel partner that has gone. The six handlers in scr_serf_c
/// that read s.attacking_def_index all dereference it without a nil check -
/// Freeserf's C++ would follow a dangling pointer and usually get away with it,
/// where GML throws and takes the whole game down. cf_is_hostile() above is what
/// stops the cheat creating that situation, so this should never fire; it is
/// here so that a mistake anywhere costs one serf rather than the session.
///
/// Call it right after the get_serf() and return if it is true. The serf gives
/// up the fight and walks home, which is what the ported code does elsewhere
/// when it finds itself somewhere it should not be.
function cf_lost_partner(_serf, _other) {
    if (_other != undefined) {
        return false;
    }
    show_debug_message("serf " + string(_serf.get_index()) +
                       " lost its fight partner (state " +
                       string(_serf.get_state()) + ") - sending it home");
    _serf.s.attacking_def_index = 0;
    _serf.state = SerfState.lost;
    _serf.s.lost_field_B = 0;
    _serf.counter = 0;
    return true;
}

/// Hand the serf back to the ported code. SerfState.lost is the game's own
/// "this one has no business here, send him home" path, so the walk back and
/// the re-absorption into the economy are all existing, tested behaviour.
function cf_send_home(_serf) {
    _serf.cf_mode = CfMode.none;
    _serf.cf_target = 0;
    _serf.state = SerfState.lost;
    _serf.s.lost_field_B = 0;
    _serf.counter = 0;
}

/// The whole cheat assault, run from inside SerfState.knight_engaging_building.
/// Returns true when the cheat has taken this serf over and the ported handler
/// should not run; false to let the normal duel proceed.
function cf_siege_tick(_serf) {
    if (!global.cf_active) {
        return false;
    }
    if (_serf.get_owner() != 0) {
        return false;
    }

    var _game = _serf.game;
    var _map = _game.get_map();

    // ---- not yet engaged: is there something in front worth besieging?
    // Most soldiers now open fire from a distance and arrive here already in
    // siege mode (see cf_try_open_siege). This is the fallback for one who
    // reached the door anyway - the ported code puts a knight in this state
    // standing on the tile down-right of the building he came for.
    if (_serf.cf_mode == CfMode.none) {
        var _bpos = _map.move_up_left(_serf.pos);
        var _obj = _map.get_obj(_bpos);
        if (_obj < MapObject.small_building || _obj > MapObject.castle) {
            return false;
        }
        var _bld = _game.get_building_at_pos(_bpos);
        if (!cf_building_is_target(_bld, _serf)) {
            return false;
        }
        cf_begin_siege(_serf, _bld);
    }

    // ---- clock
    var _delta = (_game.get_tick() - _serf.tick) & 0xFFFF;
    _serf.tick = _game.get_tick() & 0xFFFF;
    _serf.counter = 0;
    _serf.cf_timer -= _delta;
    _serf.cf_last_shot += _delta;
    _serf.s.attacking_def_index = 0;   /* never a duel partner while besieging */

    switch (_serf.cf_mode) {
    case CfMode.siege: {
        var _bld = _game.get_building(_serf.cf_target);
        if (_bld == undefined || _bld.is_burning()) {
            /* Somebody else brought it down. Same pause as if we had. */
            _serf.cf_mode = CfMode.mopping;
            _serf.cf_target = 0;
            _serf.cf_timer = CF_MOP_DELAY;
            return true;
        }
        if (_serf.cf_timer > 0) {
            return true;
        }

        _serf.cf_shots += 1;
        _serf.cf_facing = cf_dir_towards(_map, _serf.pos, _bld.get_position());

        if ((_serf.cf_shots mod CF_SHOT_CYCLE) == 0) {
            cf_throw_at(_serf, _bld.get_position(), -10);
            _bld.cf_damage += CF_DMG_GRENADE;
        } else {
            cf_shoot_at(_serf, _bld.get_position(), -14);
            _bld.cf_damage += CF_DMG_BULLET;
        }
        _serf.cf_timer = CF_FIRE_INTERVAL;

        if (_bld.cf_damage >= cf_building_hp_for(_bld.get_type())) {
            cf_torch_building(_bld);
            _serf.cf_mode = CfMode.mopping;
            _serf.cf_target = 0;
            _serf.cf_timer = CF_MOP_DELAY;   // let the garrison get clear first
        }
        return true;
    }

    case CfMode.mopping: {
        /* The clock is checked FIRST, before looking for anyone to shoot. Right
           after a building falls this is the three-second hold that lets the
           garrison walk clear - and if the search ran first, the soldier would
           find nobody outside yet, decide the coast was clear and march home
           before the first man had even stepped out of the rubble. */
        if (_serf.cf_timer > 0) {
            return true;
        }

        var _target = undefined;
        if (_serf.cf_target != 0) {
            _target = _game.get_serf(_serf.cf_target);
            if (_target == undefined || !cf_is_hostile(_target, _serf)) {
                _target = undefined;
                _serf.cf_target = 0;
            }
        }
        if (_target == undefined) {
            _serf.cf_target = cf_find_target(_serf);
            if (_serf.cf_target == 0) {
                _serf.cf_mode = CfMode.withdraw;
                return true;
            }
            _target = _game.get_serf(_serf.cf_target);
            if (_target == undefined) {
                _serf.cf_target = 0;
                return true;
            }
        }

        _serf.cf_facing = cf_dir_towards(_map, _serf.pos, _target.pos);
        cf_shoot_at(_serf, _target.pos, -12);
        _serf.cf_timer = CF_MOP_INTERVAL;

        _target.cf_hp -= 1;
        if (_target.cf_hp <= 0) {
            cf_kill_knight(_target);
            _serf.cf_target = 0;
        } else {
            if (cf_rand(2) == 0) {
                cf_on_hurt(_target);
            }
        }
        return true;
    }

    case CfMode.withdraw:
        cf_send_home(_serf);
        return true;

    default:
        break;
    }

    return false;
}

// ---------------------------------------------------------------- duel hooks
// These only fire when a soldier is DEFENDING one of the player's own huts, so
// he is in the ported duel rather than the siege above. Cosmetic only.

/// Called from serf_handle_knight_attacking on every exchange.
function cf_on_fight_step(_attacker, _defender, _move) {
    if (!global.cf_active) {
        return;
    }
    if (!cf_is_soldier(_attacker) && !cf_is_soldier(_defender)) {
        return;
    }
    var _pos = _attacker.pos;
    cf_fx_at(CfFx.flash, _pos, 6, -12, 3, 0);
    var _tr = cf_fx_add(CfFx.tracer, _pos, 7, -12, _pos, -7, -14, 5, 0);
    cf_fx_at(CfFx.impact, _pos, -7, -14, 6, 4);
    cf_play_rifle();
    if (cf_rand(3) == 0) {
        cf_on_hurt(_defender);
    }
}

/// Called when one side of a duel is about to go down.
function cf_on_fight_end(_attacker, _defender, _attacker_won) {
    if (!global.cf_active) {
        return;
    }
    if (!cf_is_soldier(_attacker) && !cf_is_soldier(_defender)) {
        return;
    }
    var _loser = _defender;
    if (_attacker_won == 0) {
        _loser = _attacker;
    }
    cf_fx_at(CfFx.impact, _loser.pos, 0, -8, 8, 0);
    cf_play(snd_cf_death);
}

/// A hit that did not put the man down.
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

/// Replaces "capture the enemy building" while the cheat is on: an undefended
/// building is simply torched. Returns true when it was, false when the normal
/// capture path should run after all.
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
    cf_throw_at(_serf, _building.get_position(), -10);
    cf_torch_building(_building);
    return true;
}
