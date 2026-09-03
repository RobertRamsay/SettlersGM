// scr_player.gml - Ported from Freeserf src/player.h and src/player.cc (GPL-3.0),
// original copyright (C) 2013-2017 Jon Lund Steffensen <jonlst@gmail.com>.
// Player object. Holds the game state of a player.
// Save/load operators (SaveReaderBinary/SaveReaderText/SaveWriterText) are skipped.

// Port of Message::Type
enum MessageType {
    none = 0,
    under_attack = 1,
    lose_fight = 2,
    win_fight = 3,
    mine_empty = 4,
    call_to_location = 5,
    knight_occupied = 6,
    new_stock = 7,
    lost_land = 8,
    lost_buildings = 9,
    emergency_active = 10,
    emergency_neutral = 11,
    found_gold = 12,
    found_iron = 13,
    found_coal = 14,
    found_stone = 15,
    call_to_menu = 16,
    thirty_m_since_save = 17,
    one_h_since_save = 18,
    call_to_stock = 19
}

/// Port of Message: {type, pos, data}
function Message() constructor {
    type = MessageType.none;
    pos = 0;
    data = 0;
}

/// Port of PosTimer: {timeout, pos}
function PosTimer() constructor {
    timeout = 0;
    pos = 0;
}

/// Port of Player::Color: {red, green, blue}
function PlayerColor(_red, _green, _blue) constructor {
    red = _red;
    green = _green;
    blue = _blue;
}

/// Static const tables of player.cc (init_ai_values, available_knights_at_pos, start_attack).
function player_init_tables() {
    if (variable_global_exists("player_ai_values_0")) {
        return;
    }
    global.player_ai_values_0 = [ 13, 10, 16, 9, 10, 8, 6, 10, 12, 5, 8 ];
    global.player_ai_values_1 = [ 10000, 13000, 16000, 16000, 18000, 20000,
                                  19000, 18000, 30000, 23000, 26000 ];
    global.player_ai_values_2 = [ 10000, 35000, 20000, 27000, 37000, 25000,
                                  40000, 30000, 50000, 35000, 40000 ];
    global.player_ai_values_3 = [ 0, 36, 0, 31, 8, 480, 3, 16, 0, 193, 39 ];
    global.player_ai_values_4 = [ 0, 30000, 5000, 40000, 50000, 20000, 45000,
                                  35000, 65000, 25000, 30000 ];
    global.player_ai_values_5 = [ 60000, 61000, 60000, 65400, 63000, 62000,
                                  65000, 63000, 64000, 64000, 64000 ];

    global.player_min_level_hut = [ 1, 1, 2, 2, 3 ];
    global.player_min_level_tower = [ 1, 2, 3, 4, 6 ];
    global.player_min_level_fortress = [ 1, 3, 6, 9, 12 ];
}

function Player(_game, _index) : GameObject(_game, _index) constructor {
    player_init_tables();

    // ---- fields (C++ order) ----
    tool_prio = array_create(9, 0);
    resource_count = array_create(26, 0);
    flag_prio = array_create(26, 0);
    serf_count = array_create(27, 0);
    knight_occupation = array_create(4, 0);

    color = new PlayerColor(0, 0, 0);
    face = -1;
    flags = 0;
    build = 0;
    completed_building_count = array_create(24, 0);
    incomplete_building_count = array_create(24, 0);
    inventory_prio = array_create(26, 0);
    attacking_buildings = array_create(64, 0);

    messages = [];   // std::queue<Message> -> array (front = index 0)
    timers = [];     // std::vector<PosTimer> -> array of {timeout, pos}

    building = 0;
    castle_inventory = 0;
    cont_search_after_non_optimal_find = 7;
    knights_to_spawn = 0;
    total_land_area = 0;
    total_building_score = 0;
    total_military_score = 0;
    last_tick = 0;

    reproduction_counter = 0;
    reproduction_reset = 0;
    serf_to_knight_rate = 20000;
    serf_to_knight_counter = 0x8000; /* Overflow is important (uint16) */
    analysis_goldore = 0;
    analysis_ironore = 0;
    analysis_coal = 0;
    analysis_stone = 0;

    food_stonemine = 0;
    food_coalmine = 0;
    food_ironmine = 0;
    food_goldmine = 0;
    planks_construction = 0;
    planks_boatbuilder = 0;
    planks_toolmaker = 0;
    steel_toolmaker = 0;
    steel_weaponsmith = 0;
    coal_steelsmelter = 0;
    coal_goldsmelter = 0;
    coal_weaponsmith = 0;
    wheat_pigfarm = 0;
    wheat_mill = 0;

    castle_score = 0;
    send_generic_delay = 0;
    initial_supplies = 0;
    serf_index = 0;
    knight_cycle_counter = 0;
    send_knight_delay = 0;
    military_max_gold = 0;

    knight_morale = 0;
    gold_deposited = 0;
    castle_knights_wanted = 3;
    castle_knights = 0;
    ai_value_0 = 0;
    ai_value_1 = 0;
    ai_value_2 = 0;
    ai_value_3 = 0;
    ai_value_4 = 0;
    ai_value_5 = 0;
    ai_intelligence = 0;

    // int player_stat_history[16][112]  -> array of 16 arrays of 112
    player_stat_history = array_create(16, undefined);
    for (var _i = 0; _i < 16; _i++) {
        player_stat_history[_i] = array_create(112, 0);
    }
    // int resource_count_history[26][120] -> array of 26 arrays of 120
    resource_count_history = array_create(26, undefined);
    for (var _i = 0; _i < 26; _i++) {
        resource_count_history[_i] = array_create(120, 0);
    }

    // public (TODO(Digger): remove it to UI)
    building_attacked = 0;
    knights_attacking = 0;
    attacking_building_count = 0;
    attacking_knights = array_create(4, 0);
    total_attacking_knights = 0;
    temp_index = 0;

    // ---- constructor body (Player::Player) ----
    knight_occupation[0] = 0x10;
    knight_occupation[1] = 0x21;
    knight_occupation[2] = 0x32;
    knight_occupation[3] = 0x43;

    total_attacking_knights = 0;
    for (var _i = 0; _i < 4; _i++) {
        attacking_knights[_i] = 0;
    }

    attacking_building_count = 0;
    for (var _i = 0; _i < 64; _i++) {
        attacking_buildings[_i] = 0;
    }

    building_attacked = 0;
    knights_attacking = 0;

    // ---- static methods ----

    // Initialize player values.
    //
    // Supplies and reproduction are usually limited to 0-40 in random map games.
    //
    // Args:
    //     supplies: Initial resource supplies at castle (0-50).
    //     reproduction: How quickly new serfs spawn during the game (0-60).
    //     intelligence: AI only (unused) (0-40).
    static init = function(_intelligence, _supplies, _reproduction) {
        flags = 0;

        initial_supplies = _supplies;
        reproduction_reset = (60 - _reproduction) * 50;
        ai_intelligence = (1300 * _intelligence) + 13535;
        reproduction_counter = reproduction_reset;
    };

    /// _color is a {red, green, blue} struct.
    static init_view = function(_color, _face) {
        face = _face;

        if (face < 12) { /* AI player */
            flags |= (1 << 7); /* Set AI bit */
            /* TODO ... */
            /*game.max_next_index = 49;*/
        }

        if (is_ai()) {
            init_ai_values(face);
        }

        color = _color;
    };

    static get_color = function() {
        return color;
    };
    static get_face = function() {
        return face;
    };

    /* Whether player has built the initial castle. */
    static has_castle = function() {
        return ((flags & 1) != 0);
    };
    /* Whether the strongest knight should be sent to fight. */
    static send_strongest = function() {
        return (((flags >> 1) & 1) != 0);
    };
    static drop_send_strongest = function() {
        flags &= ~(1 << 1);
    };
    static set_send_strongest = function() {
        flags |= (1 << 1);
    };
    /* Whether cycling of knights is in progress. */
    static cycling_knight = function() {
        return (((flags >> 2) & 1) != 0);
    };
    /* Whether a message is queued for this player. */
    static has_message = function() {
        return (((flags >> 3) & 1) != 0);
    };
    static drop_message = function() {
        flags &= ~(1 << 3);
    };
    /* Whether the knight level of military buildings is temporarily
       reduced bacause of cycling of the knights. */
    static reduced_knight_level = function() {
        return (((flags >> 4) & 1) != 0);
    };
    /* Whether the cycling of knights is in the second phase. */
    static cycling_second = function() {
        return (((flags >> 5) & 1) != 0);
    };
    /* Whether this player is a computer controlled opponent. */
    static is_ai = function() {
        return (((flags >> 7) & 1) != 0);
    };

    /* Whether player is prohibited from building military
       buildings at current position. */
    static allow_military = function() {
        return !((build & 1) != 0);
    };
    /* Whether player is prohibited from building flag at
       current position. */
    static allow_flag = function() {
        return !(((build >> 1) & 1) != 0);
    };
    /* Whether player can spawn new serfs. */
    static can_spawn = function() {
        return (((build >> 2) & 1) != 0);
    };

    static get_serf_count = function(_type) {
        return serf_count[_type];
    };

    /* Initialize AI parameters. */
    static init_ai_values = function(_face) {
        ai_value_0 = global.player_ai_values_0[_face - 1];
        ai_value_1 = global.player_ai_values_1[_face - 1];
        ai_value_2 = global.player_ai_values_2[_face - 1];
        ai_value_3 = global.player_ai_values_3[_face - 1];
        ai_value_4 = global.player_ai_values_4[_face - 1];
        ai_value_5 = global.player_ai_values_5[_face - 1];
    };

    /* Enqueue a new notification message for player. */
    static add_notification = function(_type, _pos, _data) {
        flags |= (1 << 3); /* Message in queue. */
        var _new_message = new Message();
        _new_message.type = _type;
        _new_message.pos = _pos;
        _new_message.data = _data;
        array_push(messages, _new_message);
    };

    static has_notification = function() {
        return (array_length(messages) > 0);
    };

    /// Returns a Message struct {type, pos, data}.
    static pop_notification = function() {
        var _message = messages[0];
        array_delete(messages, 0, 1);
        return _message;
    };

    /// Returns a Message struct {type, pos, data}.
    static peek_notification = function() {
        var _message = messages[0];
        return _message;
    };

    static add_timer = function(_timeout, _pos) {
        var _new_timer = new PosTimer();
        _new_timer.timeout = _timeout;
        _new_timer.pos = _pos;
        array_push(timers, _new_timer);
    };

    /* Set defaults for food distribution priorities. */
    static reset_food_priority = function() {
        food_stonemine = 13100;
        food_coalmine = 45850;
        food_ironmine = 45850;
        food_goldmine = 65500;
    };

    /* Set defaults for planks distribution priorities. */
    static reset_planks_priority = function() {
        planks_construction = 65500;
        planks_boatbuilder = 3275;
        planks_toolmaker = 19650;
    };

    /* Set defaults for steel distribution priorities. */
    static reset_steel_priority = function() {
        steel_toolmaker = 45850;
        steel_weaponsmith = 65500;
    };

    /* Set defaults for coal distribution priorities. */
    static reset_coal_priority = function() {
        coal_steelsmelter = 32750;
        coal_goldsmelter = 65500;
        coal_weaponsmith = 52400;
    };

    /* Set defaults for coal distribution priorities. */
    static reset_wheat_priority = function() {
        wheat_pigfarm = 65500;
        wheat_mill = 32750;
    };

    /* Set defaults for tool production priorities. */
    static reset_tool_priority = function() {
        tool_prio[0] = 9825; /* SHOVEL */
        tool_prio[1] = 65500; /* HAMMER */
        tool_prio[2] = 13100; /* ROD */
        tool_prio[3] = 6550; /* CLEAVER */
        tool_prio[4] = 13100; /* SCYTHE */
        tool_prio[5] = 26200; /* AXE */
        tool_prio[6] = 32750; /* SAW */
        tool_prio[7] = 45850; /* PICK */
        tool_prio[8] = 6550; /* PINCER */
    };

    /* Set defaults for flag priorities. */
    static reset_flag_priority = function() {
        flag_prio[ResourceType.gold_ore] = 1;
        flag_prio[ResourceType.gold_bar] = 2;
        flag_prio[ResourceType.wheat] = 3;
        flag_prio[ResourceType.flour] = 4;
        flag_prio[ResourceType.pig] = 5;

        flag_prio[ResourceType.boat] = 6;
        flag_prio[ResourceType.pincer] = 7;
        flag_prio[ResourceType.scythe] = 8;
        flag_prio[ResourceType.rod] = 9;
        flag_prio[ResourceType.cleaver] = 10;

        flag_prio[ResourceType.saw] = 11;
        flag_prio[ResourceType.axe] = 12;
        flag_prio[ResourceType.pick] = 13;
        flag_prio[ResourceType.shovel] = 14;
        flag_prio[ResourceType.hammer] = 15;

        flag_prio[ResourceType.shield] = 16;
        flag_prio[ResourceType.sword] = 17;
        flag_prio[ResourceType.bread] = 18;
        flag_prio[ResourceType.meat] = 19;
        flag_prio[ResourceType.fish] = 20;

        flag_prio[ResourceType.iron_ore] = 21;
        flag_prio[ResourceType.lumber] = 22;
        flag_prio[ResourceType.coal] = 23;
        flag_prio[ResourceType.steel] = 24;
        flag_prio[ResourceType.stone] = 25;
        flag_prio[ResourceType.plank] = 26;
    };

    /* Set defaults for inventory priorities. */
    static reset_inventory_priority = function() {
        inventory_prio[ResourceType.wheat] = 1;
        inventory_prio[ResourceType.flour] = 2;
        inventory_prio[ResourceType.pig] = 3;
        inventory_prio[ResourceType.bread] = 4;
        inventory_prio[ResourceType.fish] = 5;

        inventory_prio[ResourceType.meat] = 6;
        inventory_prio[ResourceType.lumber] = 7;
        inventory_prio[ResourceType.plank] = 8;
        inventory_prio[ResourceType.boat] = 9;
        inventory_prio[ResourceType.stone] = 10;

        inventory_prio[ResourceType.coal] = 11;
        inventory_prio[ResourceType.iron_ore] = 12;
        inventory_prio[ResourceType.steel] = 13;
        inventory_prio[ResourceType.shovel] = 14;
        inventory_prio[ResourceType.hammer] = 15;

        inventory_prio[ResourceType.rod] = 16;
        inventory_prio[ResourceType.cleaver] = 17;
        inventory_prio[ResourceType.scythe] = 18;
        inventory_prio[ResourceType.axe] = 19;
        inventory_prio[ResourceType.saw] = 20;

        inventory_prio[ResourceType.pick] = 21;
        inventory_prio[ResourceType.pincer] = 22;
        inventory_prio[ResourceType.shield] = 23;
        inventory_prio[ResourceType.sword] = 24;
        inventory_prio[ResourceType.gold_ore] = 25;
        inventory_prio[ResourceType.gold_bar] = 26;
    };

    static get_knight_occupation = function(_threat_level) {
        return knight_occupation[_threat_level];
    };

    static change_knight_occupation = function(_index, _adjust_max, _delta) {
        var _max = (knight_occupation[_index] >> 4) & 0xf;
        var _min = knight_occupation[_index] & 0xf;

        if (_adjust_max) {
            _max = clamp(_max + _delta, _min, 4);
        } else {
            _min = clamp(_min + _delta, 0, _max);
        }

        knight_occupation[_index] = (_max << 4) | _min;
    };

    static increase_castle_knights = function() {
        castle_knights++;
    };
    static decrease_castle_knights = function() {
        castle_knights--;
    };
    static get_castle_knights = function() {
        return castle_knights;
    };
    static get_castle_knights_wanted = function() {
        return castle_knights_wanted;
    };
    static increase_castle_knights_wanted = function() {
        castle_knights_wanted = min(castle_knights_wanted + 1, 99);
    };
    static decrease_castle_knights_wanted = function() {
        castle_knights_wanted = max(1, castle_knights_wanted - 1);
    };
    static get_knight_morale = function() {
        return knight_morale;
    };
    static get_gold_deposited = function() {
        return gold_deposited;
    };

    /* Turn a number of serfs into knight for the given player. */
    static promote_serfs_to_knights = function(_number) {
        var _promoted = 0;

        var _serfs = game.get_player_serfs(self);
        var _n = array_length(_serfs);
        for (var _i = 0; _i < _n; _i++) {
            var _serf = _serfs[_i];
            if (_serf.get_state() == SerfState.idle_in_stock &&
                _serf.get_type() == SerfType.generic) {
                var _inv = game.get_inventory(_serf.get_idle_in_stock_inv_index());
                if (_inv.promote_serf_to_knight(_serf)) {
                    _promoted += 1;
                    _number -= 1;
                }
            }
        }

        return _promoted;
    };

    static available_knights_at_pos = function(_pos, _index, _dist) {
        var _map = game.get_map();
        if (_map.get_owner(_pos) != index ||
            _map.get_type_up(_pos) <= Terrain.water3 ||
            _map.get_type_down(_pos) <= Terrain.water3 ||
            _map.get_obj(_pos) < MapObject.small_building ||
            _map.get_obj(_pos) > MapObject.castle) {
            return _index;
        }

        var _bld_index = _map.get_obj_index(_pos);
        for (var _i = 0; _i < _index; _i++) {
            if (attacking_buildings[_i] == _bld_index) {
                return _index;
            }
        }

        var _building = game.get_building(_bld_index);
        if (!_building.is_done() || _building.is_burning()) {
            return _index;
        }

        var _min_level = undefined;
        switch (_building.get_type()) {
            case BuildingType.hut: _min_level = global.player_min_level_hut; break;
            case BuildingType.tower: _min_level = global.player_min_level_tower; break;
            case BuildingType.fortress: _min_level = global.player_min_level_fortress; break;
            default: return _index; break;
        }

        if (_index >= 64) {
            return _index;
        }

        attacking_buildings[_index] = _bld_index;

        var _state = _building.get_threat_level();
        var _knights_present = _building.get_knight_count();
        var _to_send = _knights_present - _min_level[knight_occupation[_state] & 0xf];

        if (_to_send > 0) {
            attacking_knights[_dist] += _to_send;
        }

        return _index + 1;
    };

    static knights_available_for_attack = function(_pos) {
        /* Reset counters. */
        for (var _i = 0; _i < 4; _i++) {
            attacking_knights[_i] = 0;
        }

        var _count = 0;
        var _map = game.get_map();

        /* Iterate each shell around the position.*/
        for (var _i = 0; _i < 32; _i++) {
            _pos = _map.move_right(_pos);
            for (var _j = 0; _j < _i + 1; _j++) {
                _count = available_knights_at_pos(_pos, _count, _i >> 3);
                _pos = _map.move_down(_pos);
            }
            for (var _j = 0; _j < _i + 1; _j++) {
                _count = available_knights_at_pos(_pos, _count, _i >> 3);
                _pos = _map.move_left(_pos);
            }
            for (var _j = 0; _j < _i + 1; _j++) {
                _count = available_knights_at_pos(_pos, _count, _i >> 3);
                _pos = _map.move_up_left(_pos);
            }
            for (var _j = 0; _j < _i + 1; _j++) {
                _count = available_knights_at_pos(_pos, _count, _i >> 3);
                _pos = _map.move_up(_pos);
            }
            for (var _j = 0; _j < _i + 1; _j++) {
                _count = available_knights_at_pos(_pos, _count, _i >> 3);
                _pos = _map.move_right(_pos);
            }
            for (var _j = 0; _j < _i + 1; _j++) {
                _count = available_knights_at_pos(_pos, _count, _i >> 3);
                _pos = _map.move_down_right(_pos);
            }
        }

        attacking_building_count = _count;

        total_attacking_knights = 0;
        for (var _i = 0; _i < 4; _i++) {
            total_attacking_knights += attacking_knights[_i];
        }

        return total_attacking_knights;
    };

    static start_attack = function() {
        var _target = game.get_building(building_attacked);
        if (!_target.is_done() || !_target.is_military() ||
            !_target.is_active() || _target.get_threat_level() != 3) {
            return;
        }

        var _map = game.get_map();
        for (var _i = 0; _i < attacking_building_count; _i++) {
            /* TODO building index may not be valid any more(?). */
            var _b = game.get_building(attacking_buildings[_i]);
            if (_b.is_burning() || _map.get_owner(_b.get_position()) != index) {
                continue;
            }

            var _flag_pos = _map.move_down_right(_b.get_position());
            if (_map.has_serf(_flag_pos)) {
                /* Check if building is under siege. */
                var _s = game.get_serf_at_pos(_flag_pos);
                if (_s.get_owner() != index) {
                    continue;
                }
            }

            var _min_level = undefined;
            switch (_b.get_type()) {
                case BuildingType.hut: _min_level = global.player_min_level_hut; break;
                case BuildingType.tower: _min_level = global.player_min_level_tower; break;
                case BuildingType.fortress: _min_level = global.player_min_level_fortress; break;
                default: continue; break;
            }

            var _state = _b.get_threat_level();
            var _knights_present = _b.get_knight_count();
            var _to_send = _knights_present - _min_level[knight_occupation[_state] & 0xf];

            for (var _j = 0; _j < _to_send; _j++) {
                /* Find most approriate knight to send according to player settings. */
                var _best_type = SerfType.knight4;
                if (send_strongest()) {
                    _best_type = SerfType.knight0;
                }
                var _best_index = -1;

                var _knight_index = _b.get_first_knight();
                while (_knight_index != 0) {
                    var _knight = game.get_serf(_knight_index);
                    if (send_strongest()) {
                        if (_knight.get_type() >= _best_type) {
                            _best_index = _knight_index;
                            _best_type = _knight.get_type();
                        }
                    } else {
                        if (_knight.get_type() <= _best_type) {
                            _best_index = _knight_index;
                            _best_type = _knight.get_type();
                        }
                    }

                    _knight_index = _knight.get_next();
                }

                var _def_serf = _b.call_attacker_out(_best_index);

                _target.set_under_attack();

                /* Calculate distance to target. */
                var _dist_col = _map.dist_x(_target.get_position(), _def_serf.get_pos());
                var _dist_row = _map.dist_y(_target.get_position(), _def_serf.get_pos());

                /* Send this serf off to fight. */
                _def_serf.send_off_to_fight(_dist_col, _dist_row);

                knights_attacking -= 1;
                if (knights_attacking == 0) {
                    return;
                }
            }
        }
    };

    /* Begin cycling knights by sending knights from military buildings
       to inventories. The knights can then be replaced by more experienced
       knights. */
    static cycle_knights = function() {
        flags |= (1 << 2) | (1 << 4);
        knight_cycle_counter = 2400;
    };

    static building_founded = function(_building) {
        _building.set_owner(index);

        if (_building.get_type() == BuildingType.castle) {
            flags |= (1 << 0); /* Has castle */
            build |= (1 << 3);
            total_building_score += building_get_score_from_type(BuildingType.castle);
            castle_inventory = _building.get_inventory().get_index();
            building = _building.get_index();
            create_initial_castle_serfs(_building);
            last_tick = game.get_tick();
        } else {
            incomplete_building_count[_building.get_type()] += 1;
        }
    };

    static building_built = function(_building) {
        var _type = _building.get_type();
        total_building_score += building_get_score_from_type(_type);
        completed_building_count[_type] += 1;
        incomplete_building_count[_type] -= 1;
    };

    static building_captured = function(_building) {
        var _def_player = game.get_player(_building.get_owner());

        _def_player.add_notification(MessageType.lose_fight,
                                     _building.get_position(), index);
        add_notification(MessageType.win_fight, _building.get_position(),
                         index);

        if (_building.get_type() == BuildingType.castle) {
            castle_score += 1;
        } else {
            /* Update player scores. */
            _def_player.total_building_score -=
                building_get_score_from_type(_building.get_type());
            _def_player.total_land_area -= 7;
            _def_player.completed_building_count[_building.get_type()] -= 1;

            total_building_score += building_get_score_from_type(_building.get_type());
            total_land_area += 7;
            completed_building_count[_building.get_type()] += 1;

            /* Change owner of building */
            _building.set_owner(index);

            if (is_ai()) {
                /* TODO AI */
            }
        }
    };

    static building_demolished = function(_building) {
        /* Update player fields. */
        if (_building.is_done()) {
            total_building_score -= building_get_score_from_type(_building.get_type());

            if (_building.get_type() != BuildingType.castle) {
                completed_building_count[_building.get_type()] -= 1;
            } else {
                build &= ~(1 << 3);
                castle_score -= 1;
            }
        } else {
            incomplete_building_count[_building.get_type()] -= 1;
        }
    };

    static get_completed_building_count = function(_type) {
        return completed_building_count[_type];
    };
    static get_incomplete_building_count = function(_type) {
        return incomplete_building_count[_type];
    };

    static spawn_serf_generic = function() {
        var _serf = game.create_serf();
        if (_serf == undefined) {
            return undefined;
        }

        _serf.set_owner(index);

        serf_count[SerfType.generic] += 1;

        return _serf;
    };

    // Spawn new serf. Returns a struct {success, serf, inventory}
    // (C++: returns bool, serf/inventory via out-params; both undefined on failure).
    static spawn_serf = function(_want_knight) {
        var _result = { success: false, serf: undefined, inventory: undefined };

        if (!can_spawn()) {
            return _result;
        }

        var _inventories = game.get_player_inventories(self);
        if (array_length(_inventories) < 1) {
            return _result;
        }

        var _inv = undefined;
        var _n = array_length(_inventories);
        for (var _i = 0; _i < _n; _i++) {
            var _loop_inv = _inventories[_i];
            if (_loop_inv.get_serf_mode() == InventoryMode.mode_in) {
                if (_want_knight && (_loop_inv.get_count_of(ResourceType.sword) == 0 ||
                                     _loop_inv.get_count_of(ResourceType.shield) == 0)) {
                    continue;
                } else if (_loop_inv.free_serf_count() == 0) {
                    _inv = _loop_inv;
                    break;
                } else if (_inv == undefined ||
                           _loop_inv.free_serf_count() < _inv.free_serf_count()) {
                    _inv = _loop_inv;
                }
            }
        }

        if (_inv == undefined) {
            if (_want_knight) {
                return spawn_serf(false);
            } else {
                return _result;
            }
        }

        var _s = _inv.spawn_serf_generic();
        if (_s == undefined) {
            return _result;
        }

        _result.success = true;
        _result.serf = _s;
        _result.inventory = _inv;

        return _result;
    };

    static tick_send_generic_delay = function() {
        send_generic_delay -= 1;
        if (send_generic_delay < 0) {
            send_generic_delay = 5;
            return true;
        }
        return false;
    };

    static tick_send_knight_delay = function() {
        send_knight_delay -= 1;
        if (send_knight_delay < 0) {
            send_knight_delay = 5;
            return true;
        }
        return false;
    };

    static get_cycling_serf_type = function(_type) {
        if (cycling_second()) {
            _type = -((knight_cycle_counter >> 8) + 1);
        }
        return _type;
    };

    static increase_serf_count = function(_type) {
        serf_count[_type]++;
    };

    static decrease_serf_count = function(_type) {
        if (serf_count[_type] == 0) {
            throw ("Failed to decrease serf count");
        }
        serf_count[_type]--;
    };

    /// C++ get_serfs(): returns the serf_count array itself.
    static get_serfs = function() {
        return serf_count;
    };

    static increase_res_count = function(_type) {
        resource_count[_type]++;
    };
    static decrease_res_count = function(_type) {
        resource_count[_type]--;
    };

    static get_tool_prio = function(_type) {
        return tool_prio[_type];
    };
    static set_tool_prio = function(_type, _prio) {
        tool_prio[_type] = _prio;
    };

    /// C++ overload: get_flag_prio(res) -> int; get_flag_prio() -> the array.
    static get_flag_prio = function(_res = undefined) {
        if (argument_count == 0) {
            return flag_prio;
        }
        return flag_prio[_res];
    };

    /// C++ overload: get_inventory_prio(type) -> int; get_inventory_prio() -> the array.
    static get_inventory_prio = function(_type = undefined) {
        if (argument_count == 0) {
            return inventory_prio;
        }
        return inventory_prio[_type];
    };

    static get_total_military_score = function() {
        return total_military_score;
    };

    /* Create the initial serfs that occupies the castle. */
    static create_initial_castle_serfs = function(_castle) {
        build |= (1 << 2);

        /* Spawn serf 4 */
        var _inventory = _castle.get_inventory();
        var _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.transporter_inventory);
        _serf.init_inventory_transporter(_inventory);

        game.get_map().set_serf_index(_serf.get_pos(), _serf.get_index());

        var _building = game.get_building(building);
        _building.set_first_knight(_serf.get_index());

        /* Spawn generic serfs */
        for (var _i = 0; _i < 5; _i++) {
            spawn_serf(false);
        }

        /* Spawn three knights */
        for (var _i = 0; _i < 3; _i++) {
            _serf = _inventory.spawn_serf_generic();
            if (_serf == undefined) {
                return;
            }
            _inventory.promote_serf_to_knight(_serf);
        }

        /* Spawn toolmaker */
        _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.toolmaker);

        /* Spawn timberman */
        _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.lumberjack);

        /* Spawn sawmiller */
        _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.sawmiller);

        /* Spawn stonecutter */
        _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.stonecutter);

        /* Spawn digger */
        _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.digger);

        /* Spawn builder */
        _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.builder);

        /* Spawn fisherman */
        _serf = _inventory.spawn_serf_generic();
        if (_serf == undefined) {
            return;
        }
        _inventory.specialize_serf(_serf, SerfType.fisher);

        /* Spawn two geologists */
        for (var _i = 0; _i < 2; _i++) {
            _serf = _inventory.spawn_serf_generic();
            if (_serf == undefined) {
                return;
            }
            _inventory.specialize_serf(_serf, SerfType.geologist);
        }

        /* Spawn two miners */
        for (var _i = 0; _i < 2; _i++) {
            _serf = _inventory.spawn_serf_generic();
            if (_serf == undefined) {
                return;
            }
            _inventory.specialize_serf(_serf, SerfType.miner);
        }
    };

    /* Update player game state as part of the game progression. */
    static update = function() {
        var _delta = (game.get_tick() - last_tick) & 0xFFFF; /* uint16_t */
        last_tick = game.get_tick() & 0xFFFF;

        /* unsigned int comparisons: a wrapped-negative value reads as > 0xffff0000 */
        if ((total_land_area & 0xFFFFFFFF) > 0xffff0000) {
            total_land_area = 0;
        }
        if ((total_military_score & 0xFFFFFFFF) > 0xffff0000) {
            total_military_score = 0;
        }
        if ((total_building_score & 0xFFFFFFFF) > 0xffff0000) {
            total_building_score = 0;
        }

        if (is_ai()) {
            /*if (player->field_1B2 != 0) player->field_1B2 -= 1;*/
            /*if (player->field_1B0 != 0) player->field_1B0 -= 1;*/
        }

        if (cycling_knight()) {
            knight_cycle_counter -= _delta;
            if (knight_cycle_counter < 1) {
                flags &= ~(1 << 5);
                flags &= ~(1 << 2);
            } else if (knight_cycle_counter < 2048 && reduced_knight_level()) {
                flags |= (1 << 5);
                flags &= ~(1 << 4);
            }
        }

        if (has_castle()) {
            reproduction_counter -= _delta;

            while (reproduction_counter < 0) {
                /* uint16_t overflow is important here */
                serf_to_knight_counter = (serf_to_knight_counter + serf_to_knight_rate) & 0xFFFF;
                if (serf_to_knight_counter < serf_to_knight_rate) {
                    knights_to_spawn += 1;
                    if (knights_to_spawn > 2) {
                        knights_to_spawn = 2;
                    }
                }

                if (knights_to_spawn == 0) {
                    // Create unassigned serf
                    spawn_serf(false);
                } else {
                    // Create knight serf
                    var _r = spawn_serf(true);
                    if (_r.success) {
                        var _serf = _r.serf;
                        var _inventory = _r.inventory;
                        if (_inventory.get_count_of(ResourceType.sword) != 0 &&
                            _inventory.get_count_of(ResourceType.shield) != 0) {
                            knights_to_spawn -= 1;
                            _inventory.specialize_serf(_serf, SerfType.knight0);
                        }
                    }
                }

                reproduction_counter += reproduction_reset;
            }
        }

        /* Update timers */
        var _it = 0;
        while (_it < array_length(timers)) {
            timers[_it].timeout -= _delta;
            if (timers[_it].timeout < 0) {
                /* Timer has expired. */
                /* TODO box (+ pos) timer */
                add_notification(MessageType.call_to_location, timers[_it].pos, 0);
                array_delete(timers, _it, 1);
            } else {
                _it++;
            }
        }
    };

    static update_stats = function(_res) {
        var _index = game.get_resource_history_index();
        resource_count_history[_res][_index] = resource_count[_res];
        resource_count[_res] = 0;
    };

    // Stats
    static update_knight_morale = function() {
        var _inventory_gold = 0;
        var _military_gold = 0;

        /* Sum gold collected in inventories */
        var _inventories = game.get_player_inventories(self);
        var _ni = array_length(_inventories);
        for (var _i = 0; _i < _ni; _i++) {
            var _inventory = _inventories[_i];
            _inventory_gold += _inventory.get_count_of(ResourceType.gold_bar);
        }

        /* Sum gold deposited in military buildings */
        var _buildings = game.get_player_buildings(self);
        var _nb = array_length(_buildings);
        for (var _i = 0; _i < _nb; _i++) {
            var _building = _buildings[_i];
            _military_gold += _building.military_gold_count();
        }

        var _depot = _inventory_gold + _military_gold;
        gold_deposited = _inventory_gold + _military_gold;

        /* Calculate according to gold collected. */
        var _total_gold = game.get_gold_total();
        if (_total_gold != 0) {
            while (_total_gold > 0xffff) {
                _total_gold = _total_gold >> 1;
                _depot = _depot >> 1;
            }
            _depot = min(_depot, _total_gold - 1);
            knight_morale = 1024 + ((game.get_gold_morale_factor() * _depot) div _total_gold);
        } else {
            knight_morale = 4096;
        }

        /* Adjust based on castle score. */
        if (castle_score < 0) {
            knight_morale = max(1, knight_morale - 1023);
        } else if (castle_score > 0) {
            knight_morale = min(knight_morale + 1024 * castle_score, 0xffff);
        }

        var _military_score = total_military_score;
        var _morale = knight_morale >> 5;
        while (_military_score > 0xffff) {
            _military_score = _military_score >> 1;
            _morale = _morale << 1;
        }

        /* Calculate fractional score used by AI */
        var _player_score = (_military_score * _morale) >> 7;
        var _enemy_score = game.get_enemy_score(self);

        while (_player_score > 0xffff && _enemy_score > 0xffff) {
            _player_score = _player_score >> 1;
            _enemy_score = _enemy_score >> 1;
        }
        /*
          player_score >>= 1;
          unsigned int frac_score = 0;
          if (player_score != 0 && enemy_score != 0) {
            if (player_score > enemy_score) {
              frac_score = 0xffffffff;
            } else {
              frac_score = (player_score * 0x10000) / enemy_score;
            }
          }
        */
        military_max_gold = 0;
    };

    static get_land_area = function() {
        return total_land_area;
    };
    static increase_land_area = function() {
        total_land_area++;
    };
    static decrease_land_area = function() {
        total_land_area--;
    };
    static get_building_score = function() {
        return total_building_score;
    };

    /* Calculate condensed score from military score and knight morale. */
    static get_military_score = function() {
        return (2048 + (knight_morale >> 1)) * (total_military_score << 6);
    };

    static increase_military_score = function(_val) {
        total_military_score += _val;
    };
    static decrease_military_score = function(_val) {
        total_military_score -= _val;
    };
    static increase_military_max_gold = function(_val) {
        military_max_gold += _val;
    };

    static get_score = function() {
        var _mil_score = get_military_score();
        return total_building_score + ((total_land_area + _mil_score) >> 4);
    };

    static get_initial_supplies = function() {
        return initial_supplies;
    };

    /// Returns the 120-entry history array for the resource type.
    static get_resource_count_history = function(_type) {
        return resource_count_history[_type];
    };
    static set_player_stat_history = function(_mode, _ind, _val) {
        player_stat_history[_mode][_ind] = _val;
    };
    /// Returns the 112-entry history array for the mode.
    static get_player_stat_history = function(_mode) {
        return player_stat_history[_mode];
    };

    /// ResourceMap -> array indexed by ResourceType (length types_count).
    static get_stats_resources = function() {
        var _resources = array_create(ResourceType.types_count, 0);

        /* Sum up resources of all inventories. */
        var _inventories = game.get_player_inventories(self);
        var _n = array_length(_inventories);
        for (var _i = 0; _i < _n; _i++) {
            var _inventory = _inventories[_i];
            for (var _j = 0; _j < 26; _j++) {
                _resources[_j] += _inventory.get_count_of(_j);
            }
        }

        return _resources;
    };

    /// Serf::SerfMap -> array indexed by SerfType (length 28, includes dead).
    static get_stats_serfs_idle = function() {
        var _res = array_create(28, 0);

        /* Sum up all existing serfs. */
        var _serfs = game.get_player_serfs(self);
        var _n = array_length(_serfs);
        for (var _i = 0; _i < _n; _i++) {
            var _serf = _serfs[_i];
            if (_serf.get_state() == SerfState.idle_in_stock) {
                _res[_serf.get_type()] += 1;
            }
        }

        return _res;
    };

    /// Serf::SerfMap -> array indexed by SerfType (length 28, includes dead).
    static get_stats_serfs_potential = function() {
        var _res = array_create(28, 0);

        /* Sum up potential serfs of all inventories. */
        var _inventories = game.get_player_inventories(self);
        var _n = array_length(_inventories);
        for (var _i = 0; _i < _n; _i++) {
            var _inventory = _inventories[_i];
            if (_inventory.free_serf_count() > 0) {
                for (var _j = 0; _j < 27; _j++) {
                    _res[_j] += _inventory.serf_potential_count(_j);
                }
            }
        }

        return _res;
    };

    // Settings
    static get_serf_to_knight_rate = function() {
        return serf_to_knight_rate;
    };
    static set_serf_to_knight_rate = function(_rate) {
        serf_to_knight_rate = _rate;
    };

    static get_food_for_building = function(_bld_type) {
        var _res = 0;
        switch (_bld_type) {
            case BuildingType.stone_mine:
                _res = get_food_stonemine();
                break;
            case BuildingType.coal_mine:
                _res = get_food_coalmine();
                break;
            case BuildingType.iron_mine:
                _res = get_food_ironmine();
                break;
            case BuildingType.gold_mine:
                _res = get_food_goldmine();
                break;
            default:
                break;
        }
        return _res;
    };

    static get_food_stonemine = function() {
        return food_stonemine;
    };
    static set_food_stonemine = function(_val) {
        food_stonemine = _val;
    };
    static get_food_coalmine = function() {
        return food_coalmine;
    };
    static set_food_coalmine = function(_val) {
        food_coalmine = _val;
    };
    static get_food_ironmine = function() {
        return food_ironmine;
    };
    static set_food_ironmine = function(_val) {
        food_ironmine = _val;
    };
    static get_food_goldmine = function() {
        return food_goldmine;
    };
    static set_food_goldmine = function(_val) {
        food_goldmine = _val;
    };
    static get_planks_construction = function() {
        return planks_construction;
    };
    static set_planks_construction = function(_val) {
        planks_construction = _val;
    };
    static get_planks_boatbuilder = function() {
        return planks_boatbuilder;
    };
    static set_planks_boatbuilder = function(_val) {
        planks_boatbuilder = _val;
    };
    static get_planks_toolmaker = function() {
        return planks_toolmaker;
    };
    static set_planks_toolmaker = function(_val) {
        planks_toolmaker = _val;
    };
    static get_steel_toolmaker = function() {
        return steel_toolmaker;
    };
    static set_steel_toolmaker = function(_val) {
        steel_toolmaker = _val;
    };
    static get_steel_weaponsmith = function() {
        return steel_weaponsmith;
    };
    static set_steel_weaponsmith = function(_val) {
        steel_weaponsmith = _val;
    };
    static get_coal_steelsmelter = function() {
        return coal_steelsmelter;
    };
    static set_coal_steelsmelter = function(_val) {
        coal_steelsmelter = _val;
    };
    static get_coal_goldsmelter = function() {
        return coal_goldsmelter;
    };
    static set_coal_goldsmelter = function(_val) {
        coal_goldsmelter = _val;
    };
    static get_coal_weaponsmith = function() {
        return coal_weaponsmith;
    };
    static set_coal_weaponsmith = function(_val) {
        coal_weaponsmith = _val;
    };
    static get_wheat_pigfarm = function() {
        return wheat_pigfarm;
    };
    static set_wheat_pigfarm = function(_val) {
        wheat_pigfarm = _val;
    };
    static get_wheat_mill = function() {
        return wheat_mill;
    };
    static set_wheat_mill = function(_val) {
        wheat_mill = _val;
    };

    // ---- remainder of the C++ constructor body (needs the statics above) ----
    reset_food_priority();
    reset_planks_priority();
    reset_steel_priority();
    reset_coal_priority();
    reset_wheat_priority();
    reset_tool_priority();

    reset_flag_priority();
    reset_inventory_priority();

    /* TODO AI: Set array field_402 of length 25 to -1. */
    /* TODO AI: Set array field_434 of length 280*2 to 0 */
    /* TODO AI: Set array field_1bc of length 8 to -1 */
}
