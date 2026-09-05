/// scr_serf_c.gml
/// Ported from Freeserf (GPL-3.0), original copyright (C) 2013-2018 Jon Lund Steffensen
/// and the Freeserf contributors. Port of src/serf.cc lines 4283-6257:
/// Serf::handle_serf_knight_engaging_building_state() through Serf::print_state(),
/// including Serf::update(). The savegame operators (>> / <<) in that range are skipped
/// per CONVENTIONS2.md.
///
/// All functions here are GLOBAL functions named serf_<cpp_method_name>(_serf, ...)
/// where _serf is the Serf struct (defined in scr_serf.gml, part A). The C++ state
/// union `s` is flattened: s.walking.dir -> _serf.s.walking_dir, etc.
///
/// The C++ set_state()/set_other_state() macros are a verbose log + assignment; here
/// they are ported as plain assignments (`_serf.state = ...`, `other.state = ...`).
///
/// NOTE on union aliasing: in C++ `s.attacking_victory_free.move` aliases
/// `s.attacking.move` and `s.attacking_victory_free.def_index` aliases
/// `s.attacking.def_index` (same offsets B and E). Because the GML struct is
/// flattened, both names are written wherever the C++ relied on the alias so that
/// every later read sees the same value the C++ would.

function serf_c_init_tables() {
  if (variable_global_exists("serf_c_moves")) {
    return;
  }

  /* Fight move sequence table (handle_knight_attacking). */
  global.serf_c_moves = [
    1, 2, 4, 2, 0, 2, 4, 2, 1, 0, 2, 2, 3, 0, 0, -1,
    3, 2, 2, 3, 0, 4, 1, 3, 2, 4, 2, 2, 3, 0, 0, -1,
    2, 1, 4, 3, 2, 2, 2, 3, 0, 3, 1, 2, 0, 2, 0, -1,
    2, 1, 3, 2, 4, 2, 3, 0, 0, 4, 2, 0, 2, 1, 0, -1,
    3, 1, 0, 2, 2, 1, 0, 2, 4, 2, 2, 3, 0, 0, -1,
    0, 3, 1, 2, 3, 4, 2, 1, 2, 0, 2, 4, 0, 2, 0, -1,
    0, 2, 1, 2, 4, 2, 3, 0, 2, 4, 3, 2, 0, 0, -1,
    0, 0, 1, 4, 3, 2, 2, 1, 2, 0, 0, 4, 3, 0, -1
  ];

  global.serf_c_fight_anim = [
    24, 35, 41, 56, 67, 72, 83, 89, 100, 121, 0, 0, 0, 0, 0, 0,
    26, 40, 42, 57, 73, 74, 88, 104, 106, 120, 122, 0, 0, 0, 0, 0,
    17, 18, 23, 33, 34, 38, 39, 98, 102, 103, 113, 114, 118, 119, 0, 0,
    130, 133, 134, 135, 147, 148, 161, 162, 164, 166, 167, 0, 0, 0, 0, 0,
    50, 52, 53, 70, 129, 131, 132, 146, 149, 151, 0, 0, 0, 0, 0, 0
  ];

  global.serf_c_fight_anim_max = [ 10, 11, 14, 11, 10 ];

  /* Knight training parameters per defending building type. */
  global.serf_c_training_params_hut = [ 250, 125, 62, 31 ];
  global.serf_c_training_params_tower = [ 1000, 500, 250, 125 ];
  global.serf_c_training_params_fortress = [ 2000, 1000, 500, 250 ];
  global.serf_c_training_params_castle = [ 4000, 2000, 1000, 500 ];
}

function serf_handle_serf_knight_engaging_building_state(_serf) {
  /* "borntodie": the player's knights do not duel for a building, they besiege
     it. The whole assault runs inside this state - shooting, grenading, the
     burn, then mopping up the garrison as it is turned out - and hands the serf
     back via SerfState.lost when it is done. Returns false for everyone else,
     and the ported duel below runs untouched. */
  if (cf_siege_tick(_serf)) {
    return;
  }

  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter < 0) {
    var map = _serf.game.get_map();
    var obj = map.get_obj(map.move_up_left(_serf.pos));
    if (obj >= MapObject.small_building &&
        obj <= MapObject.castle) {
      var building = _serf.game.get_building(map.get_obj_index(
                                               map.move_up_left(_serf.pos)));
      if (building.is_done() &&
          building.is_military() &&
          building.get_owner() != _serf.get_owner() &&
          building.has_knight()) {
        if (building.is_under_attack()) {
          _serf.game.get_player(building.get_owner()).add_notification(
                                                  MessageType.under_attack,
                                                  building.get_position(),
                                                  _serf.get_owner());
        }

        /* Change state of attacking knight */
        _serf.counter = 0;
        _serf.state = SerfState.knight_prepare_attacking;
        _serf.animation = 168;

        var def_serf = building.call_defender_out();

        _serf.s.attacking_def_index = def_serf.get_index();

        /* Change state of defending knight */
        def_serf.state = SerfState.knight_leave_for_fight;
        def_serf.s.leaving_building_next_state = SerfState.knight_prepare_defending;
        def_serf.counter = 0;
        return;
      }
    }

    /* No one to defend this building. Occupy it. */
    _serf.state = SerfState.knight_occupy_enemy_building;
    _serf.animation = 179;
    _serf.counter = global.serf_counter_from_animation[_serf.animation];
    _serf.tick = _serf.game.get_tick() & 0xFFFF;
  }
}

function serf_set_fight_outcome(_serf, attacker, defender) {
  /* Calculate "morale" for attacker. */
  var exp_factor = 1 << (attacker.get_type() - SerfType.knight0);
  var land_factor = 0x1000;
  if (attacker.get_owner() != _serf.game.get_map().get_owner(attacker.pos)) {
    land_factor = _serf.game.get_player(attacker.get_owner()).get_knight_morale();
  }

  var morale = (0x400 * exp_factor * land_factor) >> 16;

  /* Calculate "morale" for defender. */
  var def_exp_factor = 1 << (defender.get_type() - SerfType.knight0);
  var def_land_factor = 0x1000;
  if (defender.get_owner() != _serf.game.get_map().get_owner(defender.pos)) {
    def_land_factor =
                _serf.game.get_player(defender.get_owner()).get_knight_morale();
  }

  var def_morale = (0x400 * def_exp_factor * def_land_factor) >> 16;

  var player = -1;
  var value = -1;
  var ktype = SerfType.none;
  var r = ((morale + def_morale) * _serf.game.random_int()) >> 16;
  if (r < morale) {
    player = defender.get_owner();
    value = def_exp_factor;
    ktype = defender.get_type();
    attacker.s.attacking_attacker_won = 1;
    show_debug_message("serf: Fight: " + string(morale) + " vs " + string(def_morale)
                       + " (" + string(r) + "). Attacker winning.");
  } else {
    player = attacker.get_owner();
    value = exp_factor;
    ktype = attacker.get_type();
    attacker.s.attacking_attacker_won = 0;
    show_debug_message("serf: Fight: " + string(morale) + " vs " + string(def_morale)
                       + " (" + string(r) + "). Defender winning.");
  }

  _serf.game.get_player(player).decrease_military_score(value);
  attacker.s.attacking_move = _serf.game.random_int() & 0x70;
  /* union alias: attacking_victory_free.move shares storage with attacking.move */
  attacker.s.attacking_victory_free_move = attacker.s.attacking_move;
}

function serf_handle_serf_knight_prepare_attacking(_serf) {
  var def_serf = _serf.game.get_serf(_serf.s.attacking_def_index);
  if (cf_lost_partner(_serf, def_serf)) {
    return;
  }
  if (def_serf.state == SerfState.knight_prepare_defending) {
    /* Change state of attacker. */
    _serf.state = SerfState.knight_attacking;
    _serf.counter = 0;
    _serf.tick = _serf.game.get_tick() & 0xFFFF;

    /* Change state of defender. */
    def_serf.state = SerfState.knight_defending;
    def_serf.counter = 0;

    serf_set_fight_outcome(_serf, _serf, def_serf);
  }
}

function serf_handle_serf_knight_leave_for_fight_state(_serf) {
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter = 0;

  if (_serf.game.get_map().get_serf_index(_serf.pos) == _serf.index ||
      !_serf.game.get_map().has_serf(_serf.pos)) {
    _serf.leave_building(1);
  }
}

function serf_handle_serf_knight_prepare_defending_state(_serf) {
  _serf.counter = 0;
  _serf.animation = 84;
}

function serf_handle_knight_attacking(_serf) {
  serf_c_init_tables();

  var moves = global.serf_c_moves;
  var fight_anim = global.serf_c_fight_anim;
  var fight_anim_max = global.serf_c_fight_anim_max;

  var def_serf = _serf.game.get_serf(_serf.s.attacking_def_index);
  if (cf_lost_partner(_serf, def_serf)) {
    return;
  }

  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  def_serf.tick = _serf.tick;
  _serf.counter -= delta;
  def_serf.counter = _serf.counter;

  while (_serf.counter < 0) {
    var move = moves[_serf.s.attacking_move];
    if (move < 0) {
      /* "borntodie": one last cry as somebody goes down. Cosmetic only - the
         outcome below is unchanged. */
      cf_on_fight_end(_serf, def_serf, _serf.s.attacking_attacker_won);

      if (_serf.s.attacking_attacker_won == 0) {
        /* Defender won. */
        if (_serf.state == SerfState.knight_attacking_free) {
          def_serf.state = SerfState.knight_defending_victory_free;

          def_serf.animation = 180;
          def_serf.counter = 0;

          /* Attacker dies. */
          _serf.state = SerfState.knight_attacking_defeat_free;
          _serf.animation = 152 + _serf.get_type();
          _serf.counter = 255;
          _serf.set_type(SerfType.dead);
        } else {
          /* Defender returns to building. */
          def_serf.enter_building(-1, 1);

          /* Attacker dies. */
          _serf.state = SerfState.knight_attacking_defeat;
          _serf.animation = 152 + _serf.get_type();
          _serf.counter = 255;
          _serf.set_type(SerfType.dead);
        }
      } else {
        /* Attacker won. */
        if (_serf.state == SerfState.knight_attacking_free) {
          _serf.state = SerfState.knight_attacking_victory_free;
          _serf.animation = 168;
          _serf.counter = 0;

          _serf.s.attacking_victory_free_move = def_serf.s.defending_free_field_D;
          _serf.s.attacking_victory_free_dist_col =
                                      def_serf.s.defending_free_other_dist_col;
          _serf.s.attacking_victory_free_dist_row =
                                      def_serf.s.defending_free_other_dist_row;
          /* union aliases: attacking.move (B) / attacking.def_index (E) share
             storage with attacking_victory_free.move / .def_index. */
          _serf.s.attacking_move = _serf.s.attacking_victory_free_move;
          _serf.s.attacking_victory_free_def_index = _serf.s.attacking_def_index;
        } else {
          _serf.state = SerfState.knight_attacking_victory;
          _serf.animation = 168;
          _serf.counter = 0;

          var obj = _serf.game.get_map().get_obj_index(
                                 _serf.game.get_map().move_up_left(def_serf.pos));
          var building = _serf.game.get_building(obj);
          building.requested_knight_defeat_on_walk();
        }

        /* Defender dies. */
        def_serf.tick = _serf.game.get_tick() & 0xFFFF;
        def_serf.animation = 147 + _serf.get_type();
        def_serf.counter = 255;
        def_serf.set_type(SerfType.dead);
      }
    } else {
      /* Go to next move in fight sequence. */
      _serf.s.attacking_move += 1;
      /* union alias */
      _serf.s.attacking_victory_free_move = _serf.s.attacking_move;
      if (_serf.s.attacking_attacker_won == 0) {
        move = 4 - move;
      }
      _serf.s.attacking_field_D = move;

      var off = (_serf.game.random_int() * fight_anim_max[move]) >> 16;
      var a = fight_anim[move * 16 + off];

      _serf.animation = 146 + ((a >> 4) & 0xf);
      def_serf.animation = 156 + (a & 0xf);
      _serf.counter = 72 + (_serf.game.random_int() & 0x18);
      def_serf.counter = _serf.counter;

      /* "borntodie": hang muzzle flashes, tracers, grenades and sound off the
         exchange the fight has just made. Reads the fight, never changes it. */
      cf_on_fight_step(_serf, def_serf, move);
    }
  }
}

function serf_handle_serf_knight_attacking_victory_state(_serf) {
  var def_serf = _serf.game.get_serf(_serf.s.attacking_def_index);
  if (cf_lost_partner(_serf, def_serf)) {
    return;
  }

  var delta = (_serf.game.get_tick() - def_serf.tick) & 0xFFFF;
  def_serf.tick = _serf.game.get_tick() & 0xFFFF;
  def_serf.counter -= delta;

  if (def_serf.counter < 0) {
    _serf.game.delete_serf(def_serf);
    _serf.s.attacking_def_index = 0;

    _serf.state = SerfState.knight_engaging_building;
    _serf.tick = _serf.game.get_tick() & 0xFFFF;
    _serf.counter = 0;
  }
}

function serf_handle_serf_knight_attacking_defeat_state(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter < 0) {
    _serf.game.get_map().set_serf_index(_serf.pos, 0);
    _serf.game.delete_serf(_serf);
  }
}

function serf_handle_knight_occupy_enemy_building(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter >= 0) {
    return;
  }

  var building =
        _serf.game.get_building_at_pos(_serf.game.get_map().move_up_left(_serf.pos));
  if (building != undefined) {
    if (!building.is_burning() && building.is_military()) {
      if (building.get_owner() == _serf.owner) {
        /* Enter building if there is space. */
        if (building.get_type() == BuildingType.castle) {
          _serf.enter_building(-2, 0);
          return;
        } else {
          if (building.is_enough_place_for_knight()) {
            /* Enter building */
            _serf.enter_building(-1, 0);
            building.knight_occupy();
            return;
          }
        }
      } else if (!building.has_knight()) {
        /* "borntodie": the lads do not move in, they burn it. burnup() does the
           whole demolition - land ownership, stock, escaping serfs - so the
           soldier is simply left standing outside afterwards, and reverts to
           the "lost" walk home below. */
        if (cf_burn_enemy_building(_serf, building)) {
          _serf.state = SerfState.lost;
          _serf.s.lost_field_B = 0;
          _serf.counter = 0;
          return;
        }

        /* Occupy the building. */
        _serf.game.occupy_enemy_building(building, _serf.get_owner());

        if (building.get_type() == BuildingType.castle) {
          _serf.counter = 0;
        } else {
          /* Enter building */
          _serf.enter_building(-1, 0);
          building.knight_occupy();
        }
        return;
      } else {
        _serf.state = SerfState.knight_engaging_building;
        _serf.animation = 167;
        _serf.counter = 191;
        return;
      }
    }
  }

  /* Something is wrong. */
  _serf.state = SerfState.lost;
  _serf.s.lost_field_B = 0;
  _serf.counter = 0;
}

function serf_handle_state_knight_free_walking(_serf) {
  /* "borntodie": a soldier sent to attack stops and opens fire as soon as his
     target is within a few tiles, instead of walking all the way to the door.
     The target is known exactly from free_walking_dist_col/row, so a soldier
     is never hijacked by an enemy building he merely walks past. */
  if (cf_try_open_siege(_serf)) {
    return;
  }

  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  var map = _serf.game.get_map();
  while (_serf.counter < 0) {
    /* Check for enemy knights nearby. */
    /* cycle_directions_cw(): Right, DownRight, Down, Left, UpLeft, Up */
    for (var d = Direction.right; d <= Direction.up; d++) {
      var pos_ = map.move(_serf.pos, d);

      if (map.has_serf(pos_)) {
        var _other = _serf.game.get_serf_at_pos(pos_);
        if (_other == undefined) {
          /* Belt and braces. Game.delete_serf now clears the map tile it is
             leaving, so a tile should never point at a serf that is gone -
             but if one ever does again, skip the neighbour rather than take
             the whole game down. */
          continue;
        }
        if (_serf.get_owner() != _other.get_owner()) {
          if (_other.state == SerfState.knight_free_walking) {
            _serf.pos = map.move_left(pos_);
            if (_serf.can_pass_map_pos(pos_)) {
              var dist_col = _serf.s.free_walking_dist_col;
              var dist_row = _serf.s.free_walking_dist_row;

              _serf.state = SerfState.knight_engage_defending_free;

              _serf.s.defending_free_dist_col = dist_col;
              _serf.s.defending_free_dist_row = dist_row;
              _serf.s.defending_free_other_dist_col = _other.s.free_walking_dist_col;
              _serf.s.defending_free_other_dist_row = _other.s.free_walking_dist_row;
              _serf.s.defending_free_field_D = 1;
              _serf.animation = 99;
              _serf.counter = 255;

              _other.state = SerfState.knight_engage_attacking_free;
              _other.s.attacking_field_D = d;
              _other.s.attacking_def_index = _serf.get_index();
              return;
            }
          } else if (_other.state == SerfState.walking &&
                     _other.get_type() >= SerfType.knight0 &&
                     _other.get_type() <= SerfType.knight4) {
            pos_ = map.move_left(pos_);
            if (_serf.can_pass_map_pos(pos_)) {
              var dist_col2 = _serf.s.free_walking_dist_col;
              var dist_row2 = _serf.s.free_walking_dist_row;

              _serf.state = SerfState.knight_engage_defending_free;
              _serf.s.defending_free_dist_col = dist_col2;
              _serf.s.defending_free_dist_row = dist_row2;
              _serf.s.defending_free_field_D = 0;
              _serf.animation = 99;
              _serf.counter = 255;

              var dest = _serf.game.get_flag(_other.s.walking_dest);
              var building = dest.get_building();
              if (!building.has_inventory()) {
                building.requested_knight_attacking_on_walk();
              }

              _other.state = SerfState.knight_engage_attacking_free;
              _other.s.attacking_field_D = d;
              _other.s.attacking_def_index = _serf.get_index();
              return;
            }
          }
        }
      }
    }

    _serf.handle_free_walking_common();
  }
}

function serf_handle_state_knight_engage_defending_free(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  while (_serf.counter < 0) {
    _serf.counter += 256;
  }
}

function serf_handle_state_knight_engage_attacking_free(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter < 0) {
    _serf.state = SerfState.knight_engage_attacking_free_join;
    _serf.animation = 167;
    _serf.counter += 191;
  }
}

function serf_handle_state_knight_engage_attacking_free_join(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter < 0) {
    _serf.state = SerfState.knight_prepare_attacking_free;
    _serf.animation = 168;
    _serf.counter = 0;

    var _other = _serf.game.get_serf(_serf.s.attacking_def_index);
    if (cf_lost_partner(_serf, _other)) {
      return;
    }
    var other_pos = _other.pos;
    _other.state = SerfState.knight_prepare_defending_free;
    _other.counter = _serf.counter;

    /* Adjust distance to final destination. */
    var d = _serf.s.attacking_field_D;
    if (d == Direction.right || d == Direction.down_right) {
      _other.s.defending_free_dist_col -= 1;
    } else if (d == Direction.left || d == Direction.up_left) {
      _other.s.defending_free_dist_col += 1;
    }

    if (d == Direction.down_right || d == Direction.down) {
      _other.s.defending_free_dist_row -= 1;
    } else if (d == Direction.up_left || d == Direction.up) {
      _other.s.defending_free_dist_row += 1;
    }

    _other.start_walking(d, 32, 0);
    _serf.game.get_map().set_serf_index(other_pos, 0);
  }
}

function serf_handle_state_knight_prepare_attacking_free(_serf) {
  var _other = _serf.game.get_serf(_serf.s.attacking_def_index);
  if (cf_lost_partner(_serf, _other)) {
    return;
  }
  if (_other.state == SerfState.knight_prepare_defending_free_wait) {
    _serf.state = SerfState.knight_attacking_free;
    _serf.counter = 0;

    _other.state = SerfState.knight_defending_free;
    _other.counter = 0;

    serf_set_fight_outcome(_serf, _serf, _other);
  }
}

function serf_handle_state_knight_prepare_defending_free(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter < 0) {
    _serf.state = SerfState.knight_prepare_defending_free_wait;
    _serf.counter = 0;
  }
}

function serf_handle_knight_attacking_victory_free(_serf) {
  /* attacking_victory_free.def_index aliases attacking.def_index in C++;
     both are kept in sync by handle_knight_attacking. */
  var _other = _serf.game.get_serf(_serf.s.attacking_victory_free_def_index);

  var delta = (_serf.game.get_tick() - _other.tick) & 0xFFFF;
  _other.tick = _serf.game.get_tick() & 0xFFFF;
  _other.counter -= delta;

  if (_other.counter < 0) {
    _serf.game.delete_serf(_other);

    var dist_col = _serf.s.attacking_victory_free_dist_col;
    var dist_row = _serf.s.attacking_victory_free_dist_row;

    _serf.state = SerfState.knight_attacking_free_wait;

    _serf.s.free_walking_dist_col = dist_col;
    _serf.s.free_walking_dist_row = dist_row;
    _serf.s.free_walking_neg_dist1 = 0;
    _serf.s.free_walking_neg_dist2 = 0;

    /* C++ reads s.attacking.move, which aliases attacking_victory_free.move. */
    if (_serf.s.attacking_move != 0) {
      _serf.s.free_walking_flags = 1;
    } else {
      _serf.s.free_walking_flags = 0;
    }

    _serf.animation = 179;
    _serf.counter = 127;
    _serf.tick = _serf.game.get_tick() & 0xFFFF;
  }
}

function serf_handle_knight_defending_victory_free(_serf) {
  _serf.animation = 180;
  _serf.counter = 0;
}

function serf_handle_serf_knight_attacking_defeat_free_state(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter < 0) {
    /* Change state of other. */
    var _other = _serf.game.get_serf(_serf.s.attacking_def_index);
    if (cf_lost_partner(_serf, _other)) {
      return;
    }
    var dist_col = _other.s.defending_free_dist_col;
    var dist_row = _other.s.defending_free_dist_row;

    _other.state = SerfState.knight_free_walking;

    _other.s.free_walking_dist_col = dist_col;
    _other.s.free_walking_dist_row = dist_row;
    _other.s.free_walking_neg_dist1 = 0;
    _other.s.free_walking_neg_dist2 = 0;
    _other.s.free_walking_flags = 0;

    _other.animation = 179;
    _other.counter = 0;
    _other.tick = _serf.game.get_tick() & 0xFFFF;

    /* Remove itself. */
    _serf.game.get_map().set_serf_index(_serf.pos, _other.index);
    _serf.game.delete_serf(_serf);
  }
}

function serf_handle_knight_attacking_free_wait(_serf) {
  var delta = (_serf.game.get_tick() - _serf.tick) & 0xFFFF;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter -= delta;

  if (_serf.counter < 0) {
    if (_serf.s.free_walking_flags != 0) {
      _serf.state = SerfState.knight_free_walking;
    } else {
      _serf.state = SerfState.lost;
    }

    _serf.counter = 0;
  }
}

function serf_handle_serf_state_knight_leave_for_walk_to_fight(_serf) {
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
  _serf.counter = 0;

  var map = _serf.game.get_map();
  if (map.get_serf_index(_serf.pos) != _serf.index && map.has_serf(_serf.pos)) {
    _serf.animation = 82;
    _serf.counter = 0;
    return;
  }

  var building = _serf.game.get_building(map.get_obj_index(_serf.pos));
  var new_pos = map.move_down_right(_serf.pos);

  if (!map.has_serf(new_pos)) {
    /* For clean state change, save the values first. */
    /* TODO maybe knight_leave_for_walk_to_fight can
       share leaving_building state vars. */
    var dist_col = _serf.s.leave_for_walk_to_fight_dist_col;
    var dist_row = _serf.s.leave_for_walk_to_fight_dist_row;
    var field_D = _serf.s.leave_for_walk_to_fight_field_D;
    var field_E = _serf.s.leave_for_walk_to_fight_field_E;
    var next_state = _serf.s.leave_for_walk_to_fight_next_state;

    _serf.leave_building(_serf.pos);
    /* TODO names for leaving_building vars make no sense here. */
    _serf.s.leaving_building_field_B = dist_col;
    _serf.s.leaving_building_dest = dist_row;
    _serf.s.leaving_building_dest2 = field_D;
    _serf.s.leaving_building_dir = field_E;
    _serf.s.leaving_building_next_state = next_state;
  } else {
    var _other = _serf.game.get_serf_at_pos(new_pos);
    if (_serf.get_owner() == _other.get_owner()) {
      _serf.animation = 82;
      _serf.counter = 0;
    } else {
      /* Go back to defending the building. */
      switch (building.get_type()) {
        case BuildingType.hut:
          _serf.state = SerfState.defending_hut;
          break;
        case BuildingType.tower:
          _serf.state = SerfState.defending_tower;
          break;
        case BuildingType.fortress:
          _serf.state = SerfState.defending_fortress;
          break;
        default:
          throw ("NOT_REACHED: serf_handle_serf_state_knight_leave_for_walk_to_fight");
          break;
      }

      if (!building.knight_come_back_from_fight(_serf)) {
        _serf.animation = 82;
        _serf.counter = 0;
      }
    }
  }
}

function serf_handle_serf_idle_on_path_state(_serf) {
  var flag = _serf.game.get_flag(_serf.s.idle_on_path_flag);
  if (flag == undefined) {
    _serf.state = SerfState.lost;
    return;
  }
  var rev_dir = _serf.s.idle_on_path_rev_dir;

  /* Set walking dir in field_E. */
  if (flag.is_scheduled(rev_dir)) {
    _serf.s.idle_on_path_field_E = (_serf.tick & 0xff) + 6;
  } else {
    var other_flag = flag.get_other_end_flag(rev_dir);
    var other_dir = flag.get_other_end_dir(rev_dir);
    if (other_flag != undefined && other_flag.is_scheduled(other_dir)) {
      _serf.s.idle_on_path_field_E = reverse_direction(rev_dir);
    } else {
      return;
    }
  }

  var map = _serf.game.get_map();
  if (!map.has_serf(_serf.pos)) {
    map.clear_idle_serf(_serf.pos);
    map.set_serf_index(_serf.pos, _serf.index);

    var dir = _serf.s.idle_on_path_field_E;

    _serf.state = SerfState.transporting;
    _serf.s.walking_dir1 = ResourceType.none;
    _serf.s.walking_wait_counter = 0;
    _serf.s.walking_dir = dir;
    _serf.tick = _serf.game.get_tick() & 0xFFFF;
    _serf.counter = 0;
  } else {
    _serf.state = SerfState.wait_idle_on_path;
  }
}

function serf_handle_serf_wait_idle_on_path_state(_serf) {
  var map = _serf.game.get_map();
  if (!map.has_serf(_serf.pos)) {
    /* Duplicate code from handle_serf_idle_on_path_state() */
    map.clear_idle_serf(_serf.pos);
    map.set_serf_index(_serf.pos, _serf.index);

    var dir = _serf.s.idle_on_path_field_E;

    _serf.state = SerfState.transporting;
    _serf.s.walking_dir1 = ResourceType.none;
    _serf.s.walking_wait_counter = 0;
    _serf.s.walking_dir = dir;
    _serf.tick = _serf.game.get_tick() & 0xFFFF;
    _serf.counter = 0;
  }
}

function serf_handle_scatter_state(_serf) {
  /* Choose a random, empty destination */
  while (true) {
    var r = _serf.game.random_int();
    var col = (r & 0xf);
    if (col < 8) {
      col -= 16;
    }
    var row = ((r >> 8) & 0xf);
    if (row < 8) {
      row -= 16;
    }

    var map = _serf.game.get_map();
    var dest = map.pos_add(_serf.pos, col, row);
    if (map.get_obj(dest) == 0 && map.get_height(dest) > 0) {
      if (_serf.get_type() >= SerfType.knight0 && _serf.get_type() <= SerfType.knight4) {
        _serf.state = SerfState.knight_free_walking;
      } else {
        _serf.state = SerfState.free_walking;
      }

      _serf.s.free_walking_dist_col = col;
      _serf.s.free_walking_dist_row = row;
      _serf.s.free_walking_neg_dist1 = -128;
      _serf.s.free_walking_neg_dist2 = -1;
      _serf.s.free_walking_flags = 0;
      _serf.counter = 0;
      return;
    }
  }
}

function serf_handle_serf_finished_building_state(_serf) {
  var map = _serf.game.get_map();
  if (!map.has_serf(map.move_down_right(_serf.pos))) {
    _serf.state = SerfState.ready_to_leave;
    _serf.s.leaving_building_dest = 0;
    _serf.s.leaving_building_field_B = -2;
    _serf.s.leaving_building_dir = 0;
    _serf.s.leaving_building_next_state = SerfState.walking;

    if (map.get_serf_index(_serf.pos) != _serf.index && map.has_serf(_serf.pos)) {
      _serf.animation = 82;
    }
  }
}

function serf_handle_serf_wake_at_flag_state(_serf) {
  var map = _serf.game.get_map();
  if (!map.has_serf(_serf.pos)) {
    map.clear_idle_serf(_serf.pos);
    map.set_serf_index(_serf.pos, _serf.index);
    _serf.tick = _serf.game.get_tick() & 0xFFFF;
    _serf.counter = 0;

    if (_serf.get_type() == SerfType.sailor) {
      _serf.state = SerfState.lost_sailor;
    } else {
      _serf.state = SerfState.lost;
      _serf.s.lost_field_B = 0;
    }
  }
}

function serf_handle_serf_wake_on_path_state(_serf) {
  _serf.state = SerfState.wait_idle_on_path;

  /* cycle_directions_ccw(): Up, UpLeft, Left, Down, DownRight, Right */
  var paths = _serf.game.get_map().get_paths(_serf.pos);
  for (var d = Direction.up; d >= Direction.right; d--) {
    if ((paths & (1 << d)) != 0) {
      _serf.s.idle_on_path_field_E = d;
      break;
    }
  }
}

/* training_params: array of 4 ints indexed by (type - knight0). */
function serf_handle_serf_defending_state(_serf, training_params) {
  switch (_serf.get_type()) {
  case SerfType.knight0:
  case SerfType.knight1:
  case SerfType.knight2:
  case SerfType.knight3:
    _serf.train_knight(training_params[_serf.get_type() - SerfType.knight0]);
  case SerfType.knight4: /* Cannot train anymore. */
    break;
  default:
    throw ("NOT_REACHED: serf_handle_serf_defending_state");
    break;
  }
}

function serf_handle_serf_defending_hut_state(_serf) {
  serf_c_init_tables();
  serf_handle_serf_defending_state(_serf, global.serf_c_training_params_hut);
}

function serf_handle_serf_defending_tower_state(_serf) {
  serf_c_init_tables();
  serf_handle_serf_defending_state(_serf, global.serf_c_training_params_tower);
}

function serf_handle_serf_defending_fortress_state(_serf) {
  serf_c_init_tables();
  serf_handle_serf_defending_state(_serf, global.serf_c_training_params_fortress);
}

function serf_handle_serf_defending_castle_state(_serf) {
  serf_c_init_tables();
  serf_handle_serf_defending_state(_serf, global.serf_c_training_params_castle);
}

/* Per-tick state machine. Handlers ported in this file are called directly as
   serf_<name>(_serf); handlers ported in parts A/B are called as Serf methods. */
function serf_update(_serf) {
  switch (_serf.state) {
  case SerfState.null_state: /* 0 */
    break;
  case SerfState.walking:
    _serf.handle_serf_walking_state();
    break;
  case SerfState.transporting:
    _serf.handle_serf_transporting_state();
    break;
  case SerfState.idle_in_stock:
    _serf.handle_serf_idle_in_stock_state();
    break;
  case SerfState.entering_building:
    _serf.handle_serf_entering_building_state();
    break;
  case SerfState.leaving_building: /* 5 */
    _serf.handle_serf_leaving_building_state();
    break;
  case SerfState.ready_to_enter:
    _serf.handle_serf_ready_to_enter_state();
    break;
  case SerfState.ready_to_leave:
    _serf.handle_serf_ready_to_leave_state();
    break;
  case SerfState.digging:
    _serf.handle_serf_digging_state();
    break;
  case SerfState.building:
    _serf.handle_serf_building_state();
    break;
  case SerfState.building_castle: /* 10 */
    _serf.handle_serf_building_castle_state();
    break;
  case SerfState.move_resource_out:
    _serf.handle_serf_move_resource_out_state();
    break;
  case SerfState.wait_for_resource_out:
    _serf.handle_serf_wait_for_resource_out_state();
    break;
  case SerfState.drop_resource_out:
    _serf.handle_serf_drop_resource_out_state();
    break;
  case SerfState.delivering:
    _serf.handle_serf_delivering_state();
    break;
  case SerfState.ready_to_leave_inventory: /* 15 */
    _serf.handle_serf_ready_to_leave_inventory_state();
    break;
  case SerfState.free_walking:
    _serf.handle_serf_free_walking_state();
    break;
  case SerfState.logging:
    _serf.handle_serf_logging_state();
    break;
  case SerfState.planning_logging:
    _serf.handle_serf_planning_logging_state();
    break;
  case SerfState.planning_planting:
    _serf.handle_serf_planning_planting_state();
    break;
  case SerfState.planting: /* 20 */
    _serf.handle_serf_planting_state();
    break;
  case SerfState.planning_stone_cutting:
    _serf.handle_serf_planning_stonecutting();
    break;
  case SerfState.stone_cutter_free_walking:
    _serf.handle_stonecutter_free_walking();
    break;
  case SerfState.stone_cutting:
    _serf.handle_serf_stonecutting_state();
    break;
  case SerfState.sawing:
    _serf.handle_serf_sawing_state();
    break;
  case SerfState.lost: /* 25 */
    _serf.handle_serf_lost_state();
    break;
  case SerfState.lost_sailor:
    _serf.handle_lost_sailor();
    break;
  case SerfState.free_sailing:
    _serf.handle_free_sailing();
    break;
  case SerfState.escape_building:
    _serf.handle_serf_escape_building_state();
    break;
  case SerfState.mining:
    _serf.handle_serf_mining_state();
    break;
  case SerfState.smelting: /* 30 */
    _serf.handle_serf_smelting_state();
    break;
  case SerfState.planning_fishing:
    _serf.handle_serf_planning_fishing_state();
    break;
  case SerfState.fishing:
    _serf.handle_serf_fishing_state();
    break;
  case SerfState.planning_farming:
    _serf.handle_serf_planning_farming_state();
    break;
  case SerfState.farming:
    _serf.handle_serf_farming_state();
    break;
  case SerfState.milling: /* 35 */
    _serf.handle_serf_milling_state();
    break;
  case SerfState.baking:
    _serf.handle_serf_baking_state();
    break;
  case SerfState.pig_farming:
    _serf.handle_serf_pigfarming_state();
    break;
  case SerfState.butchering:
    _serf.handle_serf_butchering_state();
    break;
  case SerfState.making_weapon:
    _serf.handle_serf_making_weapon_state();
    break;
  case SerfState.making_tool: /* 40 */
    _serf.handle_serf_making_tool_state();
    break;
  case SerfState.building_boat:
    _serf.handle_serf_building_boat_state();
    break;
  case SerfState.looking_for_geo_spot:
    _serf.handle_serf_looking_for_geo_spot_state();
    break;
  case SerfState.sampling_geo_spot:
    _serf.handle_serf_sampling_geo_spot_state();
    break;
  case SerfState.knight_engaging_building:
    serf_handle_serf_knight_engaging_building_state(_serf);
    break;
  case SerfState.knight_prepare_attacking: /* 45 */
    serf_handle_serf_knight_prepare_attacking(_serf);
    break;
  case SerfState.knight_leave_for_fight:
    serf_handle_serf_knight_leave_for_fight_state(_serf);
    break;
  case SerfState.knight_prepare_defending:
    serf_handle_serf_knight_prepare_defending_state(_serf);
    break;
  case SerfState.knight_attacking:
  case SerfState.knight_attacking_free:
    serf_handle_knight_attacking(_serf);
    break;
  case SerfState.knight_defending:
  case SerfState.knight_defending_free:
    /* The actual fight update is handled for the attacking knight. */
    break;
  case SerfState.knight_attacking_victory: /* 50 */
    serf_handle_serf_knight_attacking_victory_state(_serf);
    break;
  case SerfState.knight_attacking_defeat:
    serf_handle_serf_knight_attacking_defeat_state(_serf);
    break;
  case SerfState.knight_occupy_enemy_building:
    serf_handle_knight_occupy_enemy_building(_serf);
    break;
  case SerfState.knight_free_walking:
    serf_handle_state_knight_free_walking(_serf);
    break;
  case SerfState.knight_engage_defending_free:
    serf_handle_state_knight_engage_defending_free(_serf);
    break;
  case SerfState.knight_engage_attacking_free:
    serf_handle_state_knight_engage_attacking_free(_serf);
    break;
  case SerfState.knight_engage_attacking_free_join:
    serf_handle_state_knight_engage_attacking_free_join(_serf);
    break;
  case SerfState.knight_prepare_attacking_free:
    serf_handle_state_knight_prepare_attacking_free(_serf);
    break;
  case SerfState.knight_prepare_defending_free:
    serf_handle_state_knight_prepare_defending_free(_serf);
    break;
  case SerfState.knight_prepare_defending_free_wait:
    /* Nothing to do for this state. */
    break;
  case SerfState.knight_attacking_victory_free:
    serf_handle_knight_attacking_victory_free(_serf);
    break;
  case SerfState.knight_defending_victory_free:
    serf_handle_knight_defending_victory_free(_serf);
    break;
  case SerfState.knight_attacking_defeat_free:
    serf_handle_serf_knight_attacking_defeat_free_state(_serf);
    break;
  case SerfState.knight_attacking_free_wait:
    serf_handle_knight_attacking_free_wait(_serf);
    break;
  case SerfState.knight_leave_for_walk_to_fight: /* 65 */
    serf_handle_serf_state_knight_leave_for_walk_to_fight(_serf);
    break;
  case SerfState.idle_on_path:
    serf_handle_serf_idle_on_path_state(_serf);
    break;
  case SerfState.wait_idle_on_path:
    serf_handle_serf_wait_idle_on_path_state(_serf);
    break;
  case SerfState.wake_at_flag:
    serf_handle_serf_wake_at_flag_state(_serf);
    break;
  case SerfState.wake_on_path:
    serf_handle_serf_wake_on_path_state(_serf);
    break;
  case SerfState.defending_hut: /* 70 */
    serf_handle_serf_defending_hut_state(_serf);
    break;
  case SerfState.defending_tower:
    serf_handle_serf_defending_tower_state(_serf);
    break;
  case SerfState.defending_fortress:
    serf_handle_serf_defending_fortress_state(_serf);
    break;
  case SerfState.scatter:
    serf_handle_scatter_state(_serf);
    break;
  case SerfState.finished_building:
    serf_handle_serf_finished_building_state(_serf);
    break;
  case SerfState.defending_castle: /* 75 */
    serf_handle_serf_defending_castle_state(_serf);
    break;
  default:
    show_debug_message("serf: Serf state " + string(_serf.state) + " isn't processed");
    _serf.state = SerfState.null_state;
  }
}

/* Savegame operators (SaveReaderBinary/SaveReaderText/SaveWriterText) skipped. */

/* Returns a string describing the serf state (debug). */
function serf_print_state(_serf) {
  var res = "";
  var s = _serf.s;

  res += _serf.get_state_name(_serf.state) + "\n";

  switch (_serf.state) {
    case SerfState.idle_in_stock:
      res += "inventory" + "\t" + string(s.idle_in_stock_inv_index) + "\n";
      break;

    case SerfState.walking:
      res += "dest" + "\t" + string(s.walking_dest) + "\n";
      res += "dir" + "\t" + string(s.walking_dir) + "\n";
      res += "wait_counter" + "\t" + string(s.walking_wait_counter) + "\n";
      res += "other_dir" + "\t" + string(s.walking_dir1) + "\n";
      break;

    case SerfState.transporting:
    case SerfState.delivering:
      res += "res" + "\t" + string(s.walking_dir1) + "\n";
      res += "dest" + "\t" + string(s.walking_dest) + "\n";
      res += "dir" + "\t" + string(s.walking_dir) + "\n";
      res += "wait_counter" + "\t" + string(s.walking_wait_counter) + "\n";
      break;

    case SerfState.entering_building:
      res += "field_B" + "\t" + string(s.entering_building_field_B) + "\n";
      res += "slope_len" + "\t" + string(s.entering_building_slope_len) + "\n";
      break;

    case SerfState.leaving_building:
    case SerfState.ready_to_leave:
    case SerfState.knight_leave_for_fight:
      res += "field_B" + "\t" + string(s.leaving_building_field_B) + "\n";
      res += "dest" + "\t" + string(s.leaving_building_dest) + "\n";
      res += "dest2" + "\t" + string(s.leaving_building_dest2) + "\n";
      res += "dir" + "\t" + string(s.leaving_building_dir) + "\n";
      res += "next_state" + "\t" + string(s.leaving_building_next_state) + "\n";
      break;

    case SerfState.ready_to_enter:
      res += "field_B" + "\t" + string(s.ready_to_enter_field_B) + "\n";
      break;

    case SerfState.digging:
      res += "h_index" + "\t" + string(s.digging_h_index) + "\n";
      res += "target_h" + "\t" + string(s.digging_target_h) + "\n";
      res += "dig_pos" + "\t" + string(s.digging_dig_pos) + "\n";
      res += "substate" + "\t" + string(s.digging_substate) + "\n";
      break;

    case SerfState.building:
      res += "mode" + "\t" + string(s.building_mode) + "\n";
      res += "bld_index" + "\t" + string(s.building_bld_index) + "\n";
      res += "material_step" + "\t" + string(s.building_material_step) + "\n";
      res += "counter" + "\t" + string(s.building_counter) + "\n";
      break;

    case SerfState.building_castle:
      res += "inv_index" + "\t" + string(s.building_castle_inv_index) + "\n";
      break;

    case SerfState.move_resource_out:
    case SerfState.drop_resource_out:
      res += "res" + "\t" + string(s.move_resource_out_res) + "\n";
      res += "res_dest" + "\t" + string(s.move_resource_out_res_dest) + "\n";
      res += "next_state" + "\t" + string(s.move_resource_out_next_state) + "\n";
      break;

    case SerfState.ready_to_leave_inventory:
      res += "mode" + "\t" + string(s.ready_to_leave_inventory_mode) + "\n";
      res += "dest" + "\t" + string(s.ready_to_leave_inventory_dest) + "\n";
      res += "inv_index" + "\t" + string(s.ready_to_leave_inventory_inv_index)
          + "\n";
      break;

    case SerfState.free_walking:
    case SerfState.logging:
    case SerfState.planting:
    case SerfState.stone_cutting:
    case SerfState.stone_cutter_free_walking:
    case SerfState.fishing:
    case SerfState.farming:
    case SerfState.sampling_geo_spot:
    case SerfState.knight_free_walking:
    case SerfState.knight_attacking_free:
    case SerfState.knight_attacking_free_wait:
      res += "dist_col" + "\t" + string(s.free_walking_dist_col) + "\n";
      res += "dist_row" + "\t" + string(s.free_walking_dist_row) + "\n";
      res += "neg_dist" + "\t" + string(s.free_walking_neg_dist1) + "\n";
      res += "neg_dist2" + "\t" + string(s.free_walking_neg_dist2) + "\n";
      res += "flags" + "\t" + string(s.free_walking_flags) + "\n";
      break;

    case SerfState.sawing:
      res += "mode" + "\t" + string(s.sawing_mode) + "\n";
      break;

    case SerfState.lost:
      res += "field_B" + "\t" + string(s.lost_field_B) + "\n";
      break;

    case SerfState.mining:
      res += "substate" + "\t" + string(s.mining_substate) + "\n";
      res += "res" + "\t" + string(s.mining_res) + "\n";
      res += "deposit" + "\t" + string(s.mining_deposit) + "\n";
      break;

    case SerfState.smelting:
      res += "mode" + "\t" + string(s.smelting_mode) + "\n";
      res += "counter" + "\t" + string(s.smelting_counter) + "\n";
      res += "type" + "\t" + string(s.smelting_type) + "\n";
      break;

    case SerfState.milling:
      res += "mode" + "\t" + string(s.milling_mode) + "\n";
      break;

    case SerfState.baking:
      res += "mode" + "\t" + string(s.baking_mode) + "\n";
      break;

    case SerfState.pig_farming:
      res += "mode" + "\t" + string(s.pigfarming_mode) + "\n";
      break;

    case SerfState.butchering:
      res += "mode" + "\t" + string(s.butchering_mode) + "\n";
      break;

    case SerfState.making_weapon:
      res += "mode" + "\t" + string(s.making_weapon_mode) + "\n";
      break;

    case SerfState.making_tool:
      res += "mode" + "\t" + string(s.making_tool_mode) + "\n";
      break;

    case SerfState.building_boat:
      res += "mode" + "\t" + string(s.building_boat_mode) + "\n";
      break;

    case SerfState.knight_engaging_building:
    case SerfState.knight_prepare_attacking:
    case SerfState.knight_prepare_defending_free_wait:
    case SerfState.knight_attacking_defeat_free:
    case SerfState.knight_attacking:
    case SerfState.knight_attacking_victory:
    case SerfState.knight_engage_attacking_free:
    case SerfState.knight_engage_attacking_free_join:
    case SerfState.knight_attacking_victory_free:
      res += "move" + "\t" + string(s.attacking_move) + "\n";
      res += "attacker_won" + "\t" + string(s.attacking_attacker_won) + "\n";
      res += "field_D" + "\t" + string(s.attacking_field_D) + "\n";
      res += "def_index" + "\t" + string(s.attacking_def_index) + "\n";
      break;

    case SerfState.knight_defending_free:
    case SerfState.knight_engage_defending_free:
      res += "dist_col" + "\t" + string(s.defending_free_dist_col) + "\n";
      res += "dist_row" + "\t" + string(s.defending_free_dist_row) + "\n";
      res += "field_D" + "\t" + string(s.defending_free_field_D) + "\n";
      res += "other_dist_col" + "\t" + string(s.defending_free_other_dist_col)
          + "\n";
      res += "other_dist_row" + "\t" + string(s.defending_free_other_dist_row)
          + "\n";
      break;

    case SerfState.knight_leave_for_walk_to_fight:
      res += "dist_col" + "\t" + string(s.leave_for_walk_to_fight_dist_col) + "\n";
      res += "dist_row" + "\t" + string(s.leave_for_walk_to_fight_dist_row) + "\n";
      res += "field_D" + "\t" + string(s.leave_for_walk_to_fight_field_D) + "\n";
      res += "field_E" + "\t" + string(s.leave_for_walk_to_fight_field_E) + "\n";
      res += "next_state" + "\t" + string(s.leave_for_walk_to_fight_next_state)
          + "\n";
      break;

    case SerfState.idle_on_path:
    case SerfState.wait_idle_on_path:
    case SerfState.wake_at_flag:
    case SerfState.wake_on_path:
      res += "rev_dir" + "\t" + string(s.idle_on_path_rev_dir) + "\n";
      res += "flag" + "\t" + string(s.idle_on_path_flag) + "\n";
      res += "field_E" + "\t" + string(s.idle_on_path_field_E) + "\n";
      break;

    case SerfState.defending_hut:
    case SerfState.defending_tower:
    case SerfState.defending_fortress:
    case SerfState.defending_castle:
      res += "next_knight" + "\t" + string(s.defending_next_knight) + "\n";
      break;

    default: break;
  }
  return res;
}
