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
    _serf.counter = serf_anim_counter(_serf.animation);
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

  if (!_serf.game.get_map().other_serf_at(_serf, _serf.pos)) {
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
    _serf.game.get_map().clear_serf_index(_serf.pos, _serf);
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
    /* Our own castle or stock: straight in, no waiting, whether he came back
       from a fight, was turned out of a hut, or was sent here on purpose.
       Freeserf only knew the castle here; a knight sent to a stock across
       country (see "Knights walk everywhere") ends up at this door too. */
    if (!building.is_burning() && building.is_done() &&
        building.has_inventory() &&
        building.get_owner() == _serf.owner) {
      _serf.home_tries = 0;   /* he is home; start counting again next time */
      _serf.knight_dest_building = 0;
      _serf.enter_building(-2, 0);
      return;
    }

    if (!building.is_burning() && building.is_military()) {
      if (building.get_owner() == _serf.owner) {
        /* Enter building if there is space. */
        if (building.get_type() == BuildingType.castle) {
          _serf.home_tries = 0;   /* he is home; start counting again next time */
          _serf.knight_dest_building = 0;
          _serf.enter_building(-2, 0);
          return;
        } else if (_serf.knight_dest_building == building.get_index()) {
          /* The garrison that asked for him. His place was booked in
             stock[0].requested when he was called out (knight_request_granted),
             so he is taken in the way a knight arriving by road is - holder,
             then requested_knight_arrived once he is through the door - and
             NOT through knight_occupy(), which would book him a second time. */
          _serf.home_tries = 0;
          _serf.knight_dest_building = 0;
          building.requested_serf_reached(_serf);
          _serf.enter_building(-1, 0);
          return;
        } else {
          /* Somewhere he was not expected. If he was expected elsewhere, that
             request is given back first so the other garrison asks again. */
          knight_drop_dest(_serf);

          /* wants_another_knight, not is_enough_place_for_knight: the second
             asks whether the building could HOLD him, which for a hut with one
             knight in it is yes right up to three - and the hut then turns him
             out on the next update_military because the occupancy setting only
             wanted one. Walking in through a door you are about to be thrown
             out of is the loop this whole change is about. */
          if (building.wants_another_knight()) {
            /* Enter building */
            _serf.home_tries = 0; /* he is home; start counting again next time */
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

/// ---------------------------------------------------------------------------
/// Knights coming home from a fight. DELIBERATE DEPARTURE FROM FREESERF.
/// ---------------------------------------------------------------------------
/// Freeserf drops a knight who has finished fighting in the open into
/// SerfState.lost. That state spirals outwards for the NEAREST owned flag, free
/// walks to it, and then calls find_inventory(), which puts him on the road
/// network and walks him to the closest stock. Two things go wrong with that
/// out at the border, and both are visible in play:
///
///   - The nearest flag is often on a stretch of road that does not reach any
///     inventory. find_inventory() hands him straight back to lost, lost picks
///     the same flag again because nothing has changed, and he paces around it
///     for ever. That is the lurking.
///
///   - Even when it works he spends the whole journey standing on road tiles,
///     one serf per tile, in the way of every transporter trying to use them.
///     A handful of knights walking home after a battle will throttle the
///     supply network for as long as the walk takes.
///
/// He does not need a road at all. knight_occupy_enemy_building already knows
/// how to walk a knight into a FRIENDLY military building straight off the
/// grass - that is the `building.get_owner() == _serf.owner` branch above - so
/// the fix is to give him a building instead of a flag as his destination and
/// let him cross country to it. He only touches the road network at the very
/// end, at the door, where the tile-occupancy checks make him take his turn
/// behind whatever traffic is already going in and out.
///
/// The destination is chosen the way Bob asked for it: the nearest military
/// building with at least KNIGHT_HOME_FREE_SLOTS spare places, else the castle,
/// else anywhere at all with a single place left.

/// Prefer somewhere with room to spare rather than the last free bunk, so that
/// the slot is unlikely to have been taken by the time he walks in.
#macro KNIGHT_HOME_FREE_SLOTS 2

/// Places left in a military building, counting knights already on their way.
///
/// Against what the garrison WANTS - Building.get_needed_occupants - and not
/// against what it could physically hold. Those are different numbers, and
/// using the wrong one sent knights home to buildings that immediately turned
/// them out again:
///
///   A hut holds three. How many it asks for comes from the player's
///   knight-occupation setting for its threat level, and inside your own
///   country that is ONE. Measured by capacity, every interior hut in the
///   kingdom looks like it has two free bunks, so it is the nearest and best
///   ranked home for miles. A knight walks there, walks in, and on the very
///   next update_military the hut is over its occupancy and puts him out of the
///   door. He is lost again, picks the nearest home again, and it is the same
///   hut - out, in, out, in, for as long as anybody watches.
///
/// Reading the number the garrison itself acts on is the whole fix: a building
/// that would turn him out never looks like somewhere to go.
function knight_home_free_slots(_building) {
  switch (_building.get_type()) {
    case BuildingType.hut:
    case BuildingType.tower:
    case BuildingType.fortress:
      break;
    default:
      return 0;
  }

  var _taken = _building.get_res_count_in_stock(0) +
               _building.get_requested_in_stock(0);
  return _building.get_needed_occupants() - _taken;
}

/// Rank a candidate home. Higher is better, 0 means "not a home at all".
function knight_home_rank(_building) {
  if (_building.is_burning() || !_building.is_done() ||
      !_building.is_military()) {
    return 0;
  }

  if (_building.get_type() == BuildingType.castle) {
    return 2;                       /* always takes him back */
  }

  var _free = knight_home_free_slots(_building);
  if (_free >= KNIGHT_HOME_FREE_SLOTS) {
    return 3;                       /* what we actually want */
  }
  if (_free >= 1) {
    return 1;                       /* last resort: one bunk, might be gone */
  }
  return 0;
}

/// Best home for this knight, skipping the _skip best ones. Skipping is how a
/// knight who could not reach his first choice - across water, say - ends up
/// trying somewhere else instead of the same place for ever.
///
/// Deterministic: buildings are visited in index order and every comparison is
/// integer, so every machine in a network game makes the same choice.
function knight_pick_home(_serf, _skip) {
  var _game = _serf.game;
  var _map = _game.get_map();
  var _buildings = _game.get_player_buildings(_game.get_player(_serf.get_owner()));
  var _count = array_length(_buildings);

  var _taken = [];
  var _chosen = undefined;

  for (var _round = 0; _round <= _skip; _round++) {
    var _best = undefined;
    var _best_rank = 0;
    var _best_dist = 0;

    for (var _i = 0; _i < _count; _i++) {
      var _b = _buildings[_i];
      if (_b == undefined) {
        continue;
      }

      var _already = false;
      for (var _t = 0; _t < array_length(_taken); _t++) {
        if (_taken[_t] == _b.get_index()) {
          _already = true;
          break;
        }
      }
      if (_already) {
        continue;
      }

      var _rank = knight_home_rank(_b);
      if (_rank == 0) {
        continue;
      }

      var _door = _map.move_down_right(_b.get_position());
      var _dist = abs(_map.dist_x(_door, _serf.pos)) +
                  abs(_map.dist_y(_door, _serf.pos));

      if (_best == undefined || _rank > _best_rank ||
          (_rank == _best_rank && _dist < _best_dist)) {
        _best = _b;
        _best_rank = _rank;
        _best_dist = _dist;
      }
    }

    if (_best == undefined) {
      /* Ran out of candidates: keep the last good one rather than nothing. */
      break;
    }

    _chosen = _best;
    array_push(_taken, _best.get_index());
  }

  return _chosen;
}

/// Point a knight at a garrison and set him walking cross country to its door.
/// Returns false if there is nowhere to send him, in which case the caller
/// should carry on with whatever it did before - the ported "lost" walk.
function knight_send_home(_serf) {
  /* Four failed attempts and we stop guessing; Freeserf's own lost handling is
     a better bet than a fifth building we probably cannot reach either. */
  if (_serf.home_tries >= 4) {
    _serf.home_tries = 0;
    return false;
  }

  var _building = knight_pick_home(_serf, _serf.home_tries);
  if (_building == undefined) {
    return false;
  }
  _serf.home_tries += 1;

  var _map = _serf.game.get_map();

  /* Not the building tile: the tile one step down-right of it, which is where
     knight_occupy_enemy_building expects to be standing when it looks for its
     building at move_up_left(pos). dist_x/dist_y are measured destination
     first, serf second, matching Player.start_attack. */
  var _door = _map.move_down_right(_building.get_position());

  _serf.state = SerfState.knight_free_walking;
  _serf.s.free_walking_dist_col = _map.dist_x(_door, _serf.pos);
  _serf.s.free_walking_dist_row = _map.dist_y(_door, _serf.pos);
  /* neg_dist1 must NOT be -128 here. -128 is the flag that makes free walking
     call find_inventory() on arrival, which is the road-hunting behaviour we
     are getting away from; 0 sends him to knight_occupy_enemy_building, which
     walks him in through the door. */
  _serf.s.free_walking_neg_dist1 = 0;
  _serf.s.free_walking_neg_dist2 = 0;
  _serf.s.free_walking_flags = 0;
  _serf.counter = 0;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;

  if (global.serf_verbose_log) {
    show_debug_message("serf: knight " + string(_serf.get_index()) +
                       " heading home to building " +
                       string(_building.get_index()) + " (try " +
                       string(_serf.home_tries) + ", dist " +
                       string(_serf.s.free_walking_dist_col) + "," +
                       string(_serf.s.free_walking_dist_row) + ")");
  }

  return true;
}

/// ---------------------------------------------------------------------------
/// Knights walk everywhere. DELIBERATE DEPARTURE FROM FREESERF.
/// ---------------------------------------------------------------------------
/// knight_send_home above took knights OFF the roads on the way back from a
/// fight. This takes them off on the way OUT as well, so that a knight is never
/// path bound at all:
///
///   - A knight called out of the castle or a stock to man a hut, tower or
///     fortress (Game.send_serf_to_flag, mode -1) leaves the moment he is
///     called and crosses the country straight to that building's door -
///     knight_leave_inventory_for_building.
///
///   - A knight turned out of a garrison because it wants fewer men
///     (Building.update_military, mode -2) crosses the country to the nearest
///     castle or stock - knight_leave_for_inventory.
///
///   - If the hut's flag has no road to an inventory at all, the knight is
///     still sent, from whichever inventory is nearest as the crow flies -
///     knight_dispatch_cross_country. KNIGHT_DISPATCH_WITHOUT_ROAD turns that
///     off if a road should stay a requirement.
///
/// The walk itself is the ported knight_free_walking state, entered the way
/// Player.start_attack enters it: the distance is measured from the building
/// tile the knight is still standing on, and leave_building() then takes him
/// one step down-right without decrementing it, so the walk runs out one
/// step down-right of the destination - at its flag, where
/// knight_occupy_enemy_building looks for the building at move_up_left(pos).
///
/// Bookkeeping: a knight called out for a garrison is counted in that
/// building's stock[0].requested from the moment he is called
/// (knight_request_granted). Serf.knight_dest_building remembers which one, so
/// that arriving books him in the same way a knight arriving by road did
/// (requested_serf_reached, then requested_knight_arrived from the door) and
/// so that the request can be handed back (knight_drop_dest) if he never
/// arrives - killed on the way, or lost.
///
/// Doors: knights are phantoms (MAP_KNIGHTS_PHANTOM), blocked only by other
/// knights, and there is nothing to be gained by making one queue behind
/// another in a doorway. knight_enters_freely lets every knight walk in and
/// out of any building without waiting for the tile to clear. Two knights on
/// the building tile at once is harmless: claim_serf_index only ever names
/// the later one, clear_serf_index only clears an entry naming the caller,
/// so the tile is empty again as soon as both are through.
///
/// Watchdog: a knight who is meant to be travelling (walking, free walking,
/// lost, waiting at a door) and has not changed tile for KNIGHT_STUCK_TICKS is
/// kicked - the tiles around him are healed of stale entries and he is sent
/// off again, to the building that is expecting him if there still is one,
/// otherwise home. A loaded game runs the same kick over every knight once
/// (savegame_kick_knights), which is what unsticks a save in which knights
/// were standing still.

/// A knight who has not moved for this many game ticks while he is supposed
/// to be going somewhere is sent on his way again. Game ticks: about ten
/// seconds at normal speed.
#macro KNIGHT_STUCK_TICKS 1000

/// How many times he may be kicked at the SAME destination before the
/// destination itself is treated as the problem.
///
/// The log that came with this bug is three knights being sent to building 68
/// over and over, minutes apart, never arriving. A destination that has not
/// worked three times is not going to work the fourth: it is full, or it is
/// across water, or the door is jammed. The place is given back and he picks
/// again from somewhere new.
#macro KNIGHT_KICK_TRIES 3

/// Send a knight to a hut even when its flag has no road to any inventory.
#macro KNIGHT_DISPATCH_WITHOUT_ROAD true

function serf_is_knight(_serf) {
  if (_serf == undefined) {
    return false;
  }
  var _type = _serf.get_type();
  return (_type >= SerfType.knight0) && (_type <= SerfType.knight4);
}

/// Knights walk through doorways without waiting for the tile to clear.
function knight_enters_freely(_serf) {
  return serf_is_knight(_serf);
}

/// Distance a knight standing INSIDE a building (on its tile) must free walk
/// to arrive at the door of _building. Same convention as Player.start_attack:
/// measured destination first, from the tile he is on now, and the step
/// leave_building() takes down-right is deliberately not subtracted.
function knight_dist_from_inside(_serf, _building) {
  var _map = _serf.game.get_map();
  return {
    col: _map.dist_x(_building.get_position(), _serf.pos),
    row: _map.dist_y(_building.get_position(), _serf.pos)
  };
}

/// Distance a knight standing OUTDOORS must free walk to reach the door of
/// _building, the way knight_send_home measures it.
function knight_dist_from_outside(_serf, _building) {
  var _map = _serf.game.get_map();
  var _door = _map.move_down_right(_building.get_position());
  return {
    col: _map.dist_x(_door, _serf.pos),
    row: _map.dist_y(_door, _serf.pos)
  };
}

/// Set an outdoor knight free walking to the door of _building, right now.
function knight_free_walk_to_building(_serf, _building) {
  var _dist = knight_dist_from_outside(_serf, _building);

  _serf.state = SerfState.knight_free_walking;
  _serf.s.free_walking_dist_col = _dist.col;
  _serf.s.free_walking_dist_row = _dist.row;
  _serf.s.free_walking_neg_dist1 = 0;   /* 0, not -128: arrive at the door,
                                           do not go looking for roads */
  _serf.s.free_walking_neg_dist2 = 0;
  _serf.s.free_walking_flags = 0;
  if (_dist.col == 0 && _dist.row == 0) {
    /* Already standing at the door: report arrival instead of stepping away
       and back, which is what a zero distance would otherwise do. */
    _serf.s.free_walking_flags = (1 << 3);
  }
  _serf.animation = 82;
  _serf.counter = 0;
  _serf.tick = _serf.game.get_tick() & 0xFFFF;
}

/// The nearest castle or stock of this knight's owner that is finished, not
/// burning, and takes serfs in. Deterministic: index order, integer distance.
function knight_pick_inventory(_serf) {
  var _game = _serf.game;
  var _map = _game.get_map();
  var _buildings = _game.get_player_buildings(_game.get_player(_serf.get_owner()));
  var _count = array_length(_buildings);

  var _best = undefined;
  var _best_dist = 0;

  for (var _i = 0; _i < _count; _i++) {
    var _b = _buildings[_i];
    if (_b == undefined) {
      continue;
    }
    if (_b.is_burning() || !_b.is_done() || !_b.has_inventory()) {
      continue;
    }
    var _flag = _game.get_flag(_b.get_flag_index());
    if (_flag == undefined || !_flag.accepts_serfs()) {
      continue;
    }

    var _door = _map.move_down_right(_b.get_position());
    var _dist = abs(_map.dist_x(_door, _serf.pos)) +
                abs(_map.dist_y(_door, _serf.pos));
    if (_best == undefined || _dist < _best_dist) {
      _best = _b;
      _best_dist = _dist;
    }
  }

  return _best;
}

/// Is _building still somewhere this knight can be sent: exists, ours,
/// finished, not burning, and either an inventory or a military building.
function knight_dest_is_valid(_serf, _building) {
  if (_building == undefined) {
    return false;
  }
  if (_building.get_owner() != _serf.get_owner()) {
    return false;
  }
  if (_building.is_burning() || !_building.is_done()) {
    return false;
  }

  /* An inventory always takes him: the castle and the stocks have no
     occupancy to be over. */
  if (_building.has_inventory()) {
    return true;
  }
  if (!_building.is_military()) {
    return false;
  }

  /* A garrison, though, can stop wanting him while he is walking - somebody
     came back from a fight and took the bunk, or the player pulled the
     occupancy setting down. Walking on regardless is what put knights at the
     door of a full hut trying to get in over and over: he arrives, the place
     is gone, he is turned out, and the watchdog sends him straight back.
     Letting the destination go here means he becomes lost at the point he
     finds out, and picks somewhere that does want him. */
  return _building.still_expecting_knight();
}

/// Hand back the request this knight was counted against, because he is not
/// going to arrive. Safe to call when there is nothing to hand back.
function knight_drop_dest(_serf) {
  var _index = _serf.knight_dest_building;
  if (_index == 0) {
    return;
  }
  _serf.knight_dest_building = 0;

  var _building = _serf.game.get_building(_index);
  if (_building == undefined) {
    return;
  }
  if (_building.get_owner() != _serf.get_owner()) {
    return;
  }
  /* Only a garrison counts knights in stock[0]. An inventory never booked
     him, and anything else never asked for a knight at all. */
  if (_building.has_inventory() || !_building.is_military() ||
      _building.is_burning()) {
    return;
  }
  _building.requested_serf_lost();
}

/// Called from Serf.go_out_from_building for a knight turned out of a
/// garrison (mode -2). Redirects the leaving_building_* fields the caller has
/// just filled in so that he free walks to the nearest inventory instead of
/// taking the roads. Returns false, leaving the road walk in place, if there
/// is no inventory to send him to.
function knight_leave_for_inventory(_serf) {
  var _building = knight_pick_inventory(_serf);
  if (_building == undefined) {
    return false;
  }

  var _dist = knight_dist_from_inside(_serf, _building);

  _serf.knight_dest_building = _building.get_index();
  _serf.home_tries = 0;
  _serf.s.leaving_building_next_state = SerfState.knight_free_walking;
  _serf.s.leaving_building_field_B = _dist.col;   /* -> free_walking_dist_col */
  _serf.s.leaving_building_dest = _dist.row;      /* -> free_walking_dist_row */
  _serf.s.leaving_building_dest2 = 0;             /* -> free_walking_neg_dist1 */
  _serf.s.leaving_building_dir = 0;               /* -> free_walking_neg_dist2 */

  if (global.serf_verbose_log) {
    show_debug_message("serf: knight " + string(_serf.get_index()) +
                       " turned out, walking to inventory building " +
                       string(_building.get_index()));
  }
  return true;
}

/// Called from Serf.handle_serf_ready_to_leave_inventory_state for a knight
/// in mode -1 (sent to a building). Leaves the inventory at once and free
/// walks to the building behind the destination flag. Returns false if that
/// flag has no military building behind it, in which case the caller carries
/// on with the ported road walk.
function knight_leave_inventory_for_building(_serf) {
  var _game = _serf.game;
  var _flag = _game.get_flag(_serf.s.ready_to_leave_inventory_dest);
  if (_flag == undefined || !_flag.has_building()) {
    return false;
  }
  var _building = _flag.get_building();
  if (_building == undefined || !_building.is_military()) {
    return false;
  }

  var _dist = knight_dist_from_inside(_serf, _building);

  var _inventory = _game.get_inventory(_serf.s.ready_to_leave_inventory_inv_index);
  if (_inventory != undefined) {
    _inventory.serf_away();
  }

  _serf.knight_dest_building = _building.get_index();
  _serf.home_tries = 0;

  _serf.leave_building(0);
  _serf.s.leaving_building_next_state = SerfState.knight_free_walking;
  _serf.s.leaving_building_field_B = _dist.col;   /* -> free_walking_dist_col */
  _serf.s.leaving_building_dest = _dist.row;      /* -> free_walking_dist_row */
  _serf.s.leaving_building_dest2 = 0;             /* -> free_walking_neg_dist1 */
  _serf.s.leaving_building_dir = 0;               /* -> free_walking_neg_dist2 */

  if (global.serf_verbose_log) {
    show_debug_message("serf: knight " + string(_serf.get_index()) +
                       " called out for building " + string(_building.get_index()) +
                       " (dist " + string(_dist.col) + "," + string(_dist.row) + ")");
  }
  return true;
}

/// Game.send_serf_to_flag found no inventory by road. Pick the nearest of the
/// owner's inventories that holds a knight of the wanted grade (or the makings
/// of one, when any grade will do) and call him out from there. _type is the
/// negative "knight of at least this grade" code send_serf_to_flag uses.
/// Returns true if a knight was sent.
function knight_dispatch_cross_country(_game, _building, _type) {
  if (!KNIGHT_DISPATCH_WITHOUT_ROAD) {
    return false;
  }
  var _map = _game.get_map();
  var _player = _game.get_player(_building.get_owner());
  var _inventories = _game.get_player_inventories(_player);
  var _count = array_length(_inventories);

  var _best_inv = undefined;
  var _best_bld = undefined;
  var _best_type = -1;
  var _best_dist = 0;

  for (var _i = 0; _i < _count; _i++) {
    var _inv = _inventories[_i];
    if (_inv == undefined) {
      continue;
    }
    var _bld = _game.get_building(_inv.get_building_index());
    if (_bld == undefined || _bld.is_burning() || !_bld.is_done()) {
      continue;
    }

    var _knight_type = -1;
    for (var _k = 4; _k >= -_type - 1; _k--) {
      if (_inv.have_serf(SerfType.knight0 + _k)) {
        _knight_type = _k;
        break;
      }
    }
    if (_knight_type < 0 && _type == -1) {
      if (_inv.have_serf(SerfType.generic) &&
          _inv.get_count_of(ResourceType.sword) > 0 &&
          _inv.get_count_of(ResourceType.shield) > 0) {
        _knight_type = 5;   /* "make one" */
      }
    }
    if (_knight_type < 0) {
      continue;
    }

    var _dist = abs(_map.dist_x(_building.get_position(), _bld.get_position())) +
                abs(_map.dist_y(_building.get_position(), _bld.get_position()));
    if (_best_inv == undefined || _dist < _best_dist) {
      _best_inv = _inv;
      _best_bld = _bld;
      _best_type = _knight_type;
      _best_dist = _dist;
    }
  }

  if (_best_inv == undefined) {
    return false;
  }

  var _serf = undefined;
  if (_best_type == 5) {
    _serf = _best_inv.call_out_serf(SerfType.generic);
    _serf.set_type(SerfType.knight0);
    _best_inv.pop_resource(ResourceType.sword);
    _best_inv.pop_resource(ResourceType.shield);
  } else {
    _serf = _best_inv.call_out_serf(SerfType.knight0 + _best_type);
  }

  _building.knight_request_granted();
  _serf.knight_dest_building = _building.get_index();
  _serf.go_out_from_inventory(_best_inv.get_index(), _building.get_flag_index(), -1);

  if (global.serf_verbose_log) {
    show_debug_message("serf: knight " + string(_serf.get_index()) +
                       " sent cross country from building " +
                       string(_best_bld.get_index()) + " to " +
                       string(_building.get_index()));
  }
  return true;
}

/// The building a free-walking knight is heading for, worked out from the
/// distance left to walk the way cf_try_open_siege does: dist runs out at the
/// attack tile, one step down-right of the building. undefined if there is no
/// building there.
function knight_free_walk_target(_serf) {
  var _map = _serf.game.get_map();
  var _geom = _map.geom;
  var _dc = (_geom.pos_col(_serf.pos) + _serf.s.free_walking_dist_col) & _geom.col_mask;
  var _dr = (_geom.pos_row(_serf.pos) + _serf.s.free_walking_dist_row) & _geom.row_mask;
  var _dest = _geom.pos(_dc, _dr);
  return _serf.game.get_building_at_pos(_map.move_up_left(_dest));
}

/// A knight sent to attack queues at the enemy's door while the duel ahead of
/// him plays out, and that can take longer than the watchdog's patience. He
/// is walking at an enemy military building with nobody expecting him at
/// home, and that is the shape the watchdog must leave alone.
function knight_is_attacking(_serf) {
  if (_serf.state != SerfState.knight_free_walking) {
    return false;
  }
  if (_serf.knight_dest_building != 0) {
    return false;
  }
  if (_serf.s.free_walking_neg_dist1 == -128) {
    return false;   /* a lost knight looking for a flag, not an attacker */
  }
  var _target = knight_free_walk_target(_serf);
  if (_target == undefined) {
    return false;
  }
  return _target.is_military() && _target.get_owner() != _serf.get_owner();
}

/// Is this a state in which a knight is supposed to be getting somewhere.
function knight_is_travelling(_serf) {
  switch (_serf.state) {
    case SerfState.walking:
    case SerfState.knight_free_walking:
    case SerfState.lost:
    case SerfState.ready_to_enter:
    case SerfState.knight_occupy_enemy_building:
      return true;
    default:
      return false;
  }
}

/// Send a travelling knight off again from where he stands. Used by the
/// watchdog and by the load-time pass. The tiles around him are healed first,
/// so whatever stale entry was holding him up is gone before he tries again.
function knight_kick(_serf, _why) {
  var _game = _serf.game;
  var _map = _game.get_map();

  _game.heal_tile(_serf.pos);
  for (var _d = Direction.right; _d <= Direction.up; _d++) {
    _game.heal_tile(_map.move(_serf.pos, _d));
  }

  /* A knight still on the roads (an older save, or the road fallback) has
     his destination in the walking fields: -1 is "the building behind this
     flag", -2 is "any inventory". Take it over so he can cross country. */
  if (_serf.state == SerfState.walking && _serf.knight_dest_building == 0) {
    if (_serf.s.walking_dir1 == -1) {
      var _flag = _game.get_flag(_serf.s.walking_dest);
      if (_flag != undefined && _flag.has_building()) {
        var _bld = _flag.get_building();
        if (_bld != undefined) {
          _serf.knight_dest_building = _bld.get_index();
        }
      }
    }
    if (_serf.s.walking_dir1 == -2 || _serf.knight_dest_building == 0) {
      var _inv_bld = knight_pick_inventory(_serf);
      if (_inv_bld != undefined) {
        _serf.knight_dest_building = _inv_bld.get_index();
      }
    }
  }

  var _dest = undefined;
  if (_serf.knight_dest_building != 0) {
    _dest = _game.get_building(_serf.knight_dest_building);
    if (!knight_dest_is_valid(_serf, _dest)) {
      knight_drop_dest(_serf);
      _dest = undefined;
    }
  }

  /* Kicked at the same destination too many times. The destination is not the
     problem - being kicked means he has stood still for a thousand ticks
     already - so sending him there once more is the definition of not
     learning. Give the place back and let the lost walk pick somewhere else;
     home_tries carries the count onwards, so knight_pick_home skips the homes
     it has already offered him and eventually gives up on the whole idea. */
  if (_dest != undefined) {
    _serf.home_tries += 1;
    if (_serf.home_tries > KNIGHT_KICK_TRIES) {
      knight_drop_dest(_serf);
      _dest = undefined;
    }
  }

  /* Clear an engagement link he cannot be holding in any of these states, so
     the viewport's "additional serf" draw never follows it. */
  _serf.s.attacking_def_index = 0;

  if (_dest != undefined) {
    show_debug_message("serf: knight " + string(_serf.get_index()) + " kicked (" +
                       _why + "), walking to building " +
                       string(_dest.get_index()));
    knight_free_walk_to_building(_serf, _dest);
    return;
  }

  show_debug_message("serf: knight " + string(_serf.get_index()) + " kicked (" +
                     _why + "), going home after " + string(_serf.home_tries) +
                     " tries");
  /* home_tries is NOT reset here. It is what knight_pick_home skips by, so a
     knight who has just given up on one destination is offered a different one
     rather than the same best-ranked building he could not reach - and after
     four of those, knight_send_home stands down and Freeserf's own lost walk
     takes him. Resetting it here is what made that ladder a circle. */
  _serf.set_state(SerfState.lost);
  _serf.s.lost_field_B = 0;
  _serf.counter = 0;
  _serf.tick = _game.get_tick() & 0xFFFF;
}

/// Run every update for every knight, before his state handler. Notes the
/// tile he is on; if he is meant to be travelling and has not changed tile
/// for KNIGHT_STUCK_TICKS, kicks him.
function knight_watchdog(_serf) {
  var _now = _serf.game.get_tick() & 0xFFFF;

  if (!knight_is_travelling(_serf) || knight_is_attacking(_serf)) {
    _serf.knight_stuck_pos = _serf.pos;
    _serf.knight_stuck_since = _now;
    return;
  }

  if (_serf.pos != _serf.knight_stuck_pos) {
    _serf.knight_stuck_pos = _serf.pos;
    _serf.knight_stuck_since = _now;
    return;
  }

  if (((_now - _serf.knight_stuck_since) & 0xFFFF) < KNIGHT_STUCK_TICKS) {
    return;
  }

  _serf.knight_stuck_since = _now;
  knight_kick(_serf, "not moved for " + string(KNIGHT_STUCK_TICKS) + " ticks");
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

      if (map.has_any_serf(pos_)) {
        /* Both candidates below are knights, so look on the knight layer
           first: a knight sharing a tile with a transporter must not be
           hidden behind him. The fall-back is the ordinary layer, which is
           where every knight lives while MAP_KNIGHTS_PHANTOM is off. */
        var _other = _serf.game.get_knight_at_pos(pos_);
        if (_other == undefined) {
          _other = _serf.game.get_serf_at_pos(pos_);
        }
        if (_other == undefined) {
          /* Belt and braces. Game.delete_serf now clears the map tile it is
             leaving, so a tile should never point at a serf that is gone -
             but if one ever does again, skip the neighbour rather than take
             the whole game down. */
          continue;
        }
        if (_serf.get_owner() != _other.get_owner()) {
          if (_other.state == SerfState.knight_free_walking) {
            /* pos_, NOT _serf.pos. Freeserf moves the LOCAL position here -
               "is the tile left of him one I could fight on" - and the port
               wrote the serf's own field instead, which teleported him one
               tile without telling the map.

               That is where the knights with mirror images came from. The tile
               he was standing on still named him, so the draw code kept drawing
               him there: a copy that shadowboxes, because it is the same serf
               struct and therefore the same animation, and that vanishes the
               moment he dies. When the fight sent him walking again, free
               walking cleared the tile he THOUGHT he was on and claimed the
               next one, so the tile he really came from was never cleared and
               the ghost stayed for good. Every engagement left another one,
               which is why there were sometimes three or four.

               The branch below, for a knight in the walking state, has always
               done this correctly - that asymmetry is what gave it away. */
            pos_ = map.move_left(pos_);
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
    /* start_walking with change_pos 0 advanced _other's pos without touching
       the map, so the tile he came from still names him. */
    _serf.game.get_map().clear_serf_index(other_pos, _other);
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

    /* Remove itself, handing the tile to the survivor. Released first so that
       the loser leaves no entry behind on his own layer. delete_serf below
       clears only entries that still name the serf being deleted, so the
       survivor's claim is safe from it. */
    _serf.game.get_map().clear_serf_index(_serf.pos, _serf);
    _serf.game.get_map().claim_serf_index(_serf.pos, _other);
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
  if (map.other_serf_at(_serf, _serf.pos)) {
    _serf.animation = 82;
    _serf.counter = 0;
    return;
  }

  var building = _serf.game.get_building(map.get_obj_index(_serf.pos));
  var new_pos = map.move_down_right(_serf.pos);

  if (!map.blocked_for(_serf, new_pos)) {
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
    /* undefined = the tile is not really occupied; wait a tick and let
       get_serf_at_pos's healing clear it, then take the free path above. */
    if (_other == undefined || _serf.get_owner() == _other.get_owner()) {
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
          /* A knight coming back to something that is not a garrison. He keeps
             the state he has and the building refuses him below. */
          fault_note("serf.knight_return.building_type",
                     "type " + string(building.get_type()));
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

  /* Set walking dir in field_E.
     The direction was parked in the low byte of tick by
     handle_serf_transporting_state - "TODO Don't use anim as state var" - and
     what was parked there is s.walking_dir AFTER it went negative, so -6..-1.
     A byte holds that as 250..255, and reading it back as a plain byte gives
     256..261 rather than the 0..5 this wants. The serf then walked away with a
     walking_dir of, say, 259, and the next transporting step computed
     animation = 110 + 259 = 369 and indexed a 181-entry table with it, which
     killed the game mid-step. Sign-extend the byte first and the six values
     come back as the six directions. */
  if (flag.is_scheduled(rev_dir)) {
    var _packed = _serf.tick & 0xff;
    if (_packed >= 128) {
      _packed -= 256;
    }
    _serf.s.idle_on_path_field_E = _packed + 6;
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
  if (!map.blocked_for(_serf, _serf.pos)) {
    map.clear_idle_serf(_serf.pos);
    map.claim_serf_index(_serf.pos, _serf);

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
  if (!map.blocked_for(_serf, _serf.pos)) {
    /* Duplicate code from handle_serf_idle_on_path_state() */
    map.clear_idle_serf(_serf.pos);
    map.claim_serf_index(_serf.pos, _serf);

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
  if (!map.blocked_for(_serf, map.move_down_right(_serf.pos))) {
    _serf.state = SerfState.ready_to_leave;
    _serf.s.leaving_building_dest = 0;
    _serf.s.leaving_building_field_B = -2;
    _serf.s.leaving_building_dir = 0;
    _serf.s.leaving_building_next_state = SerfState.walking;

    if (map.other_serf_at(_serf, _serf.pos)) {
      _serf.animation = 82;
    }
  }
}

function serf_handle_serf_wake_at_flag_state(_serf) {
  var map = _serf.game.get_map();
  if (!map.blocked_for(_serf, _serf.pos)) {
    map.clear_idle_serf(_serf.pos);
    map.claim_serf_index(_serf.pos, _serf);
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
    /* Somebody defending who is not a knight. No training, no crash. */
    fault_note("serf.defending.serf_type", "type " + string(_serf.get_type()));
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
  /* Knights who should be going somewhere and are not get sent on their way
     again - see knight_watchdog under "Knights walk everywhere". */
  if (serf_is_knight(_serf)) {
    knight_watchdog(_serf);
  }

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
