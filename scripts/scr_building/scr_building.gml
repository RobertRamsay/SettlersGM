// scr_building.gml - Ported from Freeserf src/building.h and src/building.cc (GPL-3.0),
// original copyright (C) 2012-2013 Jon Lund Steffensen <jonlst@gmail.com>.
// Building class, BuildingType enum, construction/request tables and
// building_get_score_from_type().
//
// Notes on the port:
//  - Building.stock is an array of BUILDING_MAX_STOCK structs
//    {type, prio, available, requested, maximum} (C++ Building::Stock).
//  - The C++ union u {tick, level} is a single field `u`; get_tick/set_tick
//    and get_level/set_level all read/write that same field.
//  - inventory is an Inventory struct or undefined (C++ nullptr).

// Max number of different types of resources accepted by buildings.
#macro BUILDING_MAX_STOCK 3

enum BuildingType {
    none = 0,
    fisher,
    lumberjack,
    boatbuilder,
    stonecutter,
    stone_mine,
    coal_mine,
    iron_mine,
    gold_mine,
    forester,
    stock,
    hut,
    farm,
    butcher,
    pig_farm,
    mill,
    baker,
    sawmill,
    steel_smelter,
    tool_maker,
    weapon_smith,
    tower,
    fortress,
    gold_smelter,
    castle
}

function building_init_tables() {
    if (variable_global_exists("building_tables_initialised")) {
        return;
    }
    global.building_tables_initialised = true;

    // ConstructionInfo const_info[] : {map_obj, planks, stones, phase_1, phase_2}
    global.building_const_info = [
        { map_obj: MapObject.none,           planks: 0, stones: 0, phase_1:    0, phase_2:    0 },  // BUILDING_NONE
        { map_obj: MapObject.small_building, planks: 2, stones: 0, phase_1: 4096, phase_2: 4096 },  // BUILDING_FISHER
        { map_obj: MapObject.small_building, planks: 2, stones: 0, phase_1: 4096, phase_2: 4096 },  // BUILDING_LUMBERJACK
        { map_obj: MapObject.small_building, planks: 3, stones: 0, phase_1: 4096, phase_2: 2048 },  // BUILDING_BOATBUILDER
        { map_obj: MapObject.small_building, planks: 2, stones: 0, phase_1: 4096, phase_2: 4096 },  // BUILDING_STONECUTTER
        { map_obj: MapObject.small_building, planks: 4, stones: 1, phase_1: 2048, phase_2: 1366 },  // BUILDING_STONEMINE
        { map_obj: MapObject.small_building, planks: 5, stones: 0, phase_1: 2048, phase_2: 1366 },  // BUILDING_COALMINE
        { map_obj: MapObject.small_building, planks: 5, stones: 0, phase_1: 2048, phase_2: 1366 },  // BUILDING_IRONMINE
        { map_obj: MapObject.small_building, planks: 5, stones: 0, phase_1: 2048, phase_2: 1366 },  // BUILDING_GOLDMINE
        { map_obj: MapObject.small_building, planks: 2, stones: 0, phase_1: 4096, phase_2: 4096 },  // BUILDING_FORESTER
        { map_obj: MapObject.large_building, planks: 4, stones: 3, phase_1: 1366, phase_2: 1024 },  // BUILDING_STOCK
        { map_obj: MapObject.small_building, planks: 1, stones: 1, phase_1: 4096, phase_2: 4096 },  // BUILDING_HUT
        { map_obj: MapObject.large_building, planks: 4, stones: 1, phase_1: 2048, phase_2: 1366 },  // BUILDING_FARM
        { map_obj: MapObject.large_building, planks: 2, stones: 1, phase_1: 4096, phase_2: 2048 },  // BUILDING_BUTCHER
        { map_obj: MapObject.large_building, planks: 4, stones: 1, phase_1: 2048, phase_2: 1366 },  // BUILDING_PIGFARM
        { map_obj: MapObject.small_building, planks: 3, stones: 1, phase_1: 2048, phase_2: 2048 },  // BUILDING_MILL
        { map_obj: MapObject.large_building, planks: 2, stones: 1, phase_1: 4096, phase_2: 2048 },  // BUILDING_BAKER
        { map_obj: MapObject.large_building, planks: 3, stones: 2, phase_1: 2048, phase_2: 1366 },  // BUILDING_SAWMILL
        { map_obj: MapObject.large_building, planks: 3, stones: 2, phase_1: 2048, phase_2: 1366 },  // BUILDING_STEELSMELTER
        { map_obj: MapObject.large_building, planks: 3, stones: 3, phase_1: 2048, phase_2: 1024 },  // BUILDING_TOOLMAKER
        { map_obj: MapObject.large_building, planks: 2, stones: 1, phase_1: 4096, phase_2: 2048 },  // BUILDING_WEAPONSMITH
        { map_obj: MapObject.large_building, planks: 2, stones: 3, phase_1: 2048, phase_2: 1366 },  // BUILDING_TOWER
        { map_obj: MapObject.large_building, planks: 5, stones: 5, phase_1: 1024, phase_2:  683 },  // BUILDING_FORTRESS
        { map_obj: MapObject.large_building, planks: 4, stones: 1, phase_1: 2048, phase_2: 1366 },  // BUILDING_GOLDSMELTER
        { map_obj: MapObject.castle,         planks: 0, stones: 0, phase_1:  256, phase_2:  256 }   // BUILDING_CASTLE
    ];

    // Request requests[] (request_serf_if_needed): {serf_type, res_type_1, res_type_2}
    global.building_requests = [
        { serf_type: SerfType.none,         res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.fisher,       res_type_1: ResourceType.rod,     res_type_2: ResourceType.none   },
        { serf_type: SerfType.lumberjack,   res_type_1: ResourceType.axe,     res_type_2: ResourceType.none   },
        { serf_type: SerfType.boat_builder, res_type_1: ResourceType.hammer,  res_type_2: ResourceType.none   },
        { serf_type: SerfType.stonecutter,  res_type_1: ResourceType.pick,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.miner,        res_type_1: ResourceType.pick,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.miner,        res_type_1: ResourceType.pick,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.miner,        res_type_1: ResourceType.pick,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.miner,        res_type_1: ResourceType.pick,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.forester,     res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.none,         res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.none,         res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.farmer,       res_type_1: ResourceType.scythe,  res_type_2: ResourceType.none   },
        { serf_type: SerfType.butcher,      res_type_1: ResourceType.cleaver, res_type_2: ResourceType.none   },
        { serf_type: SerfType.pig_farmer,   res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.miller,       res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.baker,        res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.sawmiller,    res_type_1: ResourceType.saw,     res_type_2: ResourceType.none   },
        { serf_type: SerfType.smelter,      res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.toolmaker,    res_type_1: ResourceType.hammer,  res_type_2: ResourceType.saw    },
        { serf_type: SerfType.weapon_smith, res_type_1: ResourceType.hammer,  res_type_2: ResourceType.pincer },
        { serf_type: SerfType.none,         res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.none,         res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.smelter,      res_type_1: ResourceType.none,    res_type_2: ResourceType.none   },
        { serf_type: SerfType.none,         res_type_1: ResourceType.none,    res_type_2: ResourceType.none   }
    ];

    // update_military_flag_state
    global.building_border_check_offsets = [
        31,  32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,
        100, 101, 102, 103, 104, 105, 106, 107, 108,
        259, 260, 261, 262, 263, 264,
        241, 242, 243, 244, 245, 246,
        217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228,
        247, 248, 249, 250, 251, 252,
        -1,

        265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276,
        -1,

        277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288,
        289, 290, 291, 292, 293, 294,
        -1
    ];

    // update_military
    global.building_hut_occupants_from_level = [
        1, 1, 2, 2, 3,
        1, 1, 1, 1, 2
    ];

    global.building_tower_occupants_from_level = [
        1, 2, 3, 4, 6,
        1, 1, 2, 3, 4
    ];

    global.building_fortress_occupants_from_level = [
        1, 3, 6, 9, 12,
        1, 2, 4, 6, 8
    ];

    // building_get_score_from_type
    global.building_score_from_type = [
        2, 2, 2, 2, 5, 5, 5, 5, 2, 10,
        3, 6, 4, 6, 5, 4, 7, 7, 9, 4,
        8, 15, 6, 20
    ];
}

/// Port of the free function building_get_score_from_type(Building::Type type).
function building_get_score_from_type(_type) {
    building_init_tables();
    return global.building_score_from_type[_type - 1];
}

function Building(_game, _index) : GameObject(_game, _index) constructor {
    building_init_tables();

    type = BuildingType.none;
    constructing = true; /* Unfinished building */
    flag = 0;
    playing_sfx = false;
    threat_level = 0;
    owner = 0;
    serf_requested = false;
    serf_request_failed = false;
    burning = false;
    active = false;
    holder = false;
    pos = 0;
    progress = 0;
    u = 0;  /* union { tick; level; } */
    inventory = undefined;

    stock = array_create(BUILDING_MAX_STOCK, undefined);
    for (var _j = 0; _j < BUILDING_MAX_STOCK; _j++) {
        stock[_j] = {
            type: ResourceType.none,
            prio: 0,
            available: 0,
            requested: 0,
            maximum: 0
        };
    }

    first_knight = 0;
    burning_counter = 0;

    /* "borntodie" cheat: damage taken so far. It is stored as an accumulating
       total rather than a remaining-hitpoints count because how much a building
       can take depends on its TYPE, and type is not known here in the
       constructor - see cf_building_hp_for() in scr_cheat_cf.gml, which is a
       pure function of the type and is consulted at the moment of comparison.
       Inert unless the cheat is armed. */
    cf_damage = 0;

    // -----------------------------------------------------------------------
    // Inline getters/setters from building.h
    // -----------------------------------------------------------------------

    static get_position = function() {
        return pos;
    };
    static set_position = function(_position) {
        pos = _position;
    };

    static get_flag_index = function() {
        return flag;
    };
    static link_flag = function(_flag_index) {
        flag = _flag_index;
    };
    static unlink_flag = function() {
        flag = 0;
    };

    static has_knight = function() {
        return (first_knight != 0);
    };
    static get_first_knight = function() {
        return first_knight;
    };

    static get_burning_counter = function() {
        return burning_counter;
    };
    static set_burning_counter = function(_counter) {
        burning_counter = _counter;
    };
    static decrease_burning_counter = function(_delta) {
        burning_counter -= _delta;
    };

    /* Type of building. */
    static get_type = function() {
        return type;
    };
    static is_military = function() {
        return (type == BuildingType.hut) ||
               (type == BuildingType.tower) ||
               (type == BuildingType.fortress) ||
               (type == BuildingType.castle);
    };
    /* Owning player of the building. */
    static get_owner = function() {
        return owner;
    };
    static set_owner = function(_new_owner) {
        owner = _new_owner;
    };
    /* Whether construction of the building is finished. */
    static is_done = function() {
        return !constructing;
    };
    static is_leveling = function() {
        return (!is_done() && progress == 0);
    };
    static get_progress = function() {
        return progress;
    };
    static set_under_attack = function() {
        progress |= (1 << 0);
    };
    static is_under_attack = function() {
        return ((progress & (1 << 0)) != 0);
    };

    /* The threat level of the building. Higher values mean that
     the building is closer to the enemy. */
    static get_threat_level = function() {
        return threat_level;
    };
    /* Building is currently playing back a sound effect. */
    static is_playing_sfx = function() {
        return playing_sfx;
    };
    static start_playing_sfx = function() {
        playing_sfx = true;
    };
    static stop_playing_sfx = function() {
        playing_sfx = false;
    };
    /* Building is active (specifics depend on building type). */
    static is_active = function() {
        return active;
    };
    static start_activity = function() {
        active = true;
    };
    static stop_activity = function() {
        active = false;
    };
    /* Building is burning. */
    static is_burning = function() {
        return burning;
    };
    /* Building has an associated serf. */
    static has_serf = function() {
        return holder;
    };
    /* Building has succesfully requested a serf. */
    static serf_request_granted = function() {
        serf_requested = true;
    };
    /* Building has requested a serf but none was available. */
    static clear_serf_request_failure = function() {
        serf_request_failed = false;
    };

    /* Building has inventory and the inventory pointer is valid. */
    static has_inventory = function() {
        return (inventory != undefined);
    };
    static get_inventory = function() {
        return inventory;
    };
    static set_inventory = function(_inventory) {
        inventory = _inventory;
    };

    static get_level = function() {
        return u;
    };
    static set_level = function(_level) {
        u = _level;
    };

    static get_tick = function() {
        return u;
    };
    static set_tick = function(_tick) {
        u = _tick;
    };

    static get_knight_count = function() {
        return waiting_planks();
    };

    static waiting_stone = function() {
        return stock[1].available;  // Stone allways in stock #1
    };
    static waiting_planks = function() {
        return stock[0].available;  // Planks allways in stock #0
    };

    static is_stock_active = function(_stock_num) {
        return (stock[_stock_num].type > 0);
    };
    static get_res_count_in_stock = function(_stock_num) {
        return stock[_stock_num].available;
    };
    static get_res_type_in_stock = function(_stock_num) {
        return stock[_stock_num].type;
    };
    static get_maximum_in_stock = function(_stock_num) {
        return stock[_stock_num].maximum;
    };
    static get_requested_in_stock = function(_stock_num) {
        return stock[_stock_num].requested;
    };
    static set_priority_in_stock = function(_stock_num, _priority) {
        stock[_stock_num].prio = _priority;
    };
    static set_initial_res_in_stock = function(_stock_num, _count) {
        stock[_stock_num].available = _count;
    };
    static plank_used_for_build = function() {
        stock[0].available -= 1;
        stock[0].maximum -= 1;
    };
    static stone_used_for_build = function() {
        stock[1].available -= 1;
        stock[1].maximum -= 1;
    };
    static decrease_requested_for_stock = function(_stock_num) {
        stock[_stock_num].requested -= 1;
    };

    static pigs_count = function() {
        return stock[1].available;
    };
    static send_pig_to_butcher = function() {
        stock[1].available -= 1;
    };
    static place_new_pig = function() {
        stock[1].available += 1;
    };

    static boat_clear = function() {
        stock[1].available = 0;
    };
    static boat_do = function() {
        stock[1].available++;
    };

    static requested_knight_attacking_on_walk = function() {
        stock[0].requested -= 1;
    };
    static requested_knight_defeat_on_walk = function() {
        if (!has_inventory()) {
            stock[0].requested -= 1;
        }
    };

    // -----------------------------------------------------------------------
    // building.cc
    // -----------------------------------------------------------------------

    static start_building = function(_type) {
        type = _type;
        var _map_obj = global.building_const_info[type].map_obj;
        if (_map_obj == MapObject.large_building) {
            progress = 0;
        } else {
            progress = 1;
        }

        if (type == BuildingType.castle) {
            active = true;
            holder = true;

            stock[0].available = 0xff;
            stock[0].requested = 0xff;
            stock[1].available = 0xff;
            stock[1].requested = 0xff;
        } else {
            stock[0].type = ResourceType.plank;
            stock[0].prio = 0;
            stock[0].maximum = global.building_const_info[type].planks;
            stock[1].type = ResourceType.stone;
            stock[1].prio = 0;
            stock[1].maximum = global.building_const_info[type].stones;
        }

        return _map_obj;
    };

    static done_leveling = function() {
        progress = 1;
        holder = false;
        first_knight = 0;
    };

    static build_progress = function() {
        var _frame_finished = 0;
        if ((progress & (1 << 15)) != 0) {
            _frame_finished = 1;
        }
        if (_frame_finished == 0) {
            progress += global.building_const_info[type].phase_1;
        } else {
            progress += global.building_const_info[type].phase_2;
        }

        if (progress <= 0xffff) {
            // Not finished yet
            return false;
        }

        progress = 0;
        constructing = false; /* Building finished */
        first_knight = 0;

        if (type == BuildingType.castle) {
            return true;
        }

        holder = false;

        if (is_military()) {
            update_military_flag_state();
        }

        var _f = game.get_flag(get_flag_index());

        stock_init(0, ResourceType.none, 0);
        stock_init(1, ResourceType.none, 0);
        _f.clear_flags();

        /* Update player fields. */
        var _player = game.get_player(owner);
        _player.building_built(self);

        return true;
    };

    static increase_mining = function(_res) {
        active = true;

        if (progress == 0x8000) {
            /* Handle empty mine. */
            var _player = game.get_player(owner);
            if (_player.is_ai()) {
                /* TODO Burn building. */
            }

            _player.add_notification(MessageType.mine_empty, pos, type - BuildingType.stone_mine);
        }

        progress = (progress << 1) & 0xffff;
        if (_res > 0) {
            progress++;
        }
    };

    static set_first_knight = function(_serf) {
        first_knight = _serf;

        /* Test whether building is already occupied by knights */
        if (!active) {
            active = true;

            var _mil_type = -1;
            var _max_gold = -1;
            switch (type) {
                case BuildingType.hut:
                    _mil_type = 0;
                    _max_gold = 2;
                    break;
                case BuildingType.tower:
                    _mil_type = 1;
                    _max_gold = 4;
                    break;
                case BuildingType.fortress:
                    _mil_type = 2;
                    _max_gold = 8;
                    break;
                default:
                    throw ("NOT_REACHED: Building.set_first_knight");
                    break;
            }

            game.get_player(owner).add_notification(MessageType.knight_occupied, pos,
                                                    _mil_type);

            var _f = game.get_flag_at_pos(game.get_map().move_down_right(pos));
            _f.clear_flags();
            stock_init(1, ResourceType.gold_bar, _max_gold);
            game.building_captured(self);
        }
    };

    static call_defender_out = function() {
        /* Remove knight from stats of defending building */
        if (has_inventory()) { /* Castle */
            game.get_player(get_owner()).decrease_castle_knights();
        } else {
            stock[0].available -= 1;
            stock[0].requested += 1;
        }

        /* The last knight in the list has to defend. */
        var _first_serf = game.get_serf(first_knight);
        var _def_serf = _first_serf.extract_last_knight_from_list();

        if (_def_serf.get_index() == first_knight) {
            first_knight = 0;
        }

        return _def_serf;
    };

    static call_attacker_out = function(_knight_index) {
        stock[0].available -= 1;

        /* Unlink knight from list. */
        var _first_serf = game.get_serf(first_knight);
        var _def_serf = _first_serf.extract_last_knight_from_list();

        if (_def_serf.get_index() == first_knight) {
            first_knight = 0;
        }

        return _def_serf;
    };

    static military_gold_count = function() {
        var _count = 0;

        if (get_type() == BuildingType.hut ||
            get_type() == BuildingType.tower ||
            get_type() == BuildingType.fortress) {
            for (var _j = 0; _j < BUILDING_MAX_STOCK; _j++) {
                if (stock[_j].type == ResourceType.gold_bar) {
                    _count += stock[_j].available;
                }
            }
        }

        return _count;
    };

    static cancel_transported_resource = function(_res) {
        var _res_ = _res;
        if (_res_ == ResourceType.fish ||
            _res_ == ResourceType.meat ||
            _res_ == ResourceType.bread) {
            _res_ = ResourceType.group_food;
        }

        var _in_stock = -1;
        for (var _i = 0; _i < BUILDING_MAX_STOCK; _i++) {
            if (stock[_i].type == _res_) {
                _in_stock = _i;
                break;
            }
        }

        if (_in_stock >= 0) {
            stock[_in_stock].requested -= 1;
            if (stock[_in_stock].requested < 0) {
                throw ("Failed to cancel unrequested resource delivery.");
            }
        }
    };

    static add_requested_resource = function(_res, _fix_priority) {
        for (var _j = 0; _j < BUILDING_MAX_STOCK; _j++) {
            if (stock[_j].type == _res) {
                if (_fix_priority) {
                    var _prio = stock[_j].prio;
                    if ((_prio & 1) == 0) {
                        _prio = 0;
                    }
                    stock[_j].prio = _prio >> 1;
                } else {
                    stock[_j].prio = 0;
                }
                stock[_j].requested += 1;
                return true;
            }
        }

        return false;
    };

    static stock_init = function(_stock_num, _res_type, _maximum) {
        stock[_stock_num].type = _res_type;
        stock[_stock_num].prio = 0;
        stock[_stock_num].maximum = _maximum;
    };

    static requested_resource_delivered = function(_resource) {
        if (burning) {
            return;
        }
        if (has_inventory()) {
            inventory.push_resource(_resource);
        } else {
            var _resource_ = _resource;
            if (_resource_ == ResourceType.fish ||
                _resource_ == ResourceType.meat ||
                _resource_ == ResourceType.bread) {
                _resource_ = ResourceType.group_food;
            }

            /* Add to building stock */
            for (var _i = 0; _i < BUILDING_MAX_STOCK; _i++) {
                if (stock[_i].type == _resource_) {
                    stock[_i].available += 1;
                    stock[_i].requested -= 1;
                    if (stock[_i].requested < 0) {
                        throw ("Delivered more resources than requested.");
                    }
                    return;
                }
            }

            throw ("Delivered unexpected resource.");
        }
    };

    static requested_knight_arrived = function() {
        stock[0].available += 1;
        stock[0].requested -= 1;
    };

    static is_enough_place_for_knight = function() {
        var _max_capacity = -1;
        switch (get_type()) {
            case BuildingType.hut:
                _max_capacity = 3;
                break;
            case BuildingType.tower:
                _max_capacity = 6;
                break;
            case BuildingType.fortress:
                _max_capacity = 12;
                break;
            default:
                throw ("NOT_REACHED: Building.is_enough_place_for_knight");
                break;
        }

        var _total_knights = stock[0].requested + stock[0].available;
        return (_total_knights < _max_capacity);
    };

    static knight_come_back_from_fight = function(_knight) {
        if (is_enough_place_for_knight()) {
            stock[0].available += 1;
            var _serf = game.get_serf(first_knight);
            _knight.insert_before(_serf);
            first_knight = _knight.get_index();
            return true;
        }

        return false;
    };

    static knight_occupy = function() {
        if (!has_knight()) {
            stock[0].available = 0;
            stock[0].requested = 1;
        } else {
            stock[0].requested += 1;
        }
    };

    static burnup = function() {
        if (is_burning()) {
            return true;
        }

        burning = true;

        /* Remove lost gold stock from total count. */
        if (!constructing &&
            (get_type() == BuildingType.hut ||
             get_type() == BuildingType.tower ||
             get_type() == BuildingType.fortress ||
             get_type() == BuildingType.gold_smelter)) {
            var _gold_stock = get_res_count_in_stock(1);
            game.add_gold_total(-_gold_stock);
        }

        /* Update land owner ship if the building is military. */
        if (!constructing && active && is_military()) {
            game.update_land_ownership(pos);
        }

        if (!constructing && (type == BuildingType.castle || type == BuildingType.stock)) {
            /* Cancel resources in the out queue and remove gold from map total. */
            if (active) {
                game.delete_inventory(inventory);
                inventory = undefined;

                /* The flag has to stop advertising an inventory at the same
                   moment the inventory goes. bld_flags carries only
                   has_inventory / accepts_serfs and bld2_flags only
                   accepts_resources, so clear_flags() clears exactly those and
                   nothing else - the same call the code already makes when a
                   building is finished or captured.

                   Without this the flag keeps claiming an inventory for the
                   whole burn, which for a castle is 8191 ticks (over two
                   minutes), and send_serf_to_flag_search_cb walks past its
                   has_inventory() guard straight into
                   building.get_inventory() == undefined. Burning a castle
                   killed the game a second or two later, as soon as anything
                   asked for a serf. */
                var _burnt_flag = game.get_flag(get_flag_index());
                if (_burnt_flag != undefined) {
                    _burnt_flag.clear_flags();
                }
            }

            /* Let some serfs escape while the building is burning. */
            var _escaping_serfs = 0;
            var _serfs = game.get_serfs_at_pos(pos);
            for (var _i = 0; _i < array_length(_serfs); _i++) {
                var _serf = _serfs[_i];
                if (_serf.building_deleted(pos, _escaping_serfs < 12)) {
                    _escaping_serfs++;
                }
            }
        } else {
            active = false;
        }

        /* Remove stock from building. */
        remove_stock();

        stop_playing_sfx();

        var _serf_index = first_knight;
        burning_counter = 2047;
        u = game.get_tick();

        var _player = game.get_player(owner);
        _player.building_demolished(self);

        if (holder) {
            holder = false;

            if (!constructing && (type == BuildingType.castle)) {
                set_burning_counter(8191);

                var _serfs2 = game.get_serfs_at_pos(pos);
                for (var _i = 0; _i < array_length(_serfs2); _i++) {
                    var _serf2 = _serfs2[_i];
                    _serf2.castle_deleted(pos, true);
                }
            }

            if (!constructing && is_military()) {
                while (_serf_index != 0) {
                    var _serf3 = game.get_serf(_serf_index);
                    _serf_index = _serf3.get_next();

                    _serf3.castle_deleted(pos, false);
                }
            } else {
                var _serf4 = game.get_serf(_serf_index);
                if (_serf4.get_type() == SerfType.transporter_inventory) {
                    _serf4.set_type(SerfType.transporter);
                }

                _serf4.castle_deleted(pos, false);
            }
        }

        var _map = game.get_map();
        var _flag_pos = _map.move_down_right(pos);
        if (_map.get_paths(_flag_pos) == 0 &&
            _map.get_obj(_flag_pos) == MapObject.flag) {
            game.demolish_flag(_flag_pos, _player);
        }

        return true;
    };

    /* Calculate the flag state of military buildings (distance to enemy). */
    static update_military_flag_state = function() {
        var _border_check_offsets = global.building_border_check_offsets;

        var _f = 0;
        var _k = 0;
        var _map = game.get_map();
        _f = 3;
        _k = 0;
        // C++: for (f = 3, k = 0; f > 0; f--) { while ((offset = tbl[k++]) >= 0) {...} }
        while (_f > 0) {
            var _offset = _border_check_offsets[_k];
            _k++;
            while (_offset >= 0) {
                var _check_pos = _map.pos_add_spirally(get_position(), _offset);
                if (_map.has_owner(_check_pos) && _map.get_owner(_check_pos) != owner) {
                    threat_level = _f;
                    return;
                }
                _offset = _border_check_offsets[_k];
                _k++;
            }
            _f--;
        }
    };

    /// C++ Building::update(unsigned int tick). The private no-arg update()
    /// is update_() in GML.
    static update = function(_tick) {
        if (burning) {
            var _delta = (_tick - u) & 0xFFFF;
            u = _tick;
            if (burning_counter >= _delta) {
                burning_counter -= _delta;
            } else {
                game.delete_building(self);
            }
        } else {
            update_();
        }
    };

    static requested_serf_lost = function() {
        if (serf_requested) {
            serf_requested = false;
        } else if (!has_inventory()) {
            decrease_requested_for_stock(0);
        }
    };

    static requested_serf_reached = function(_serf) {
        holder = true;
        if (serf_requested) {
            first_knight = _serf.get_index();
        }
        serf_requested = false;
    };

    static knight_request_granted = function() {
        stock[0].requested += 1;
        serf_requested = false;
    };

    static remove_stock = function() {
        stock[0].available = 0;
        stock[0].requested = 0;
        stock[1].available = 0;
        stock[1].requested = 0;
    };

    /// C++ default argument minimum = 0: GML callers must pass it explicitly.
    static get_max_priority_for_resource = function(_resource, _minimum) {
        var _max_prio = -1;

        for (var _i = 0; _i < BUILDING_MAX_STOCK; _i++) {
            if (stock[_i].type == _resource &&
                stock[_i].prio >= _minimum &&
                stock[_i].prio > _max_prio) {
                _max_prio = stock[_i].prio;
            }
        }

        return _max_prio;
    };

    static use_resource_in_stock = function(_stock_num) {
        if (stock[_stock_num].available > 0) {
            stock[_stock_num].available -= 1;
            return true;
        }
        return false;
    };

    static use_resources_in_stocks = function() {
        if (stock[0].available > 0 && stock[1].available > 0) {
            stock[0].available -= 1;
            stock[1].available -= 1;
            return true;
        }
        return false;
    };

    static request_serf_if_needed = function() {
        var _requests = global.building_requests;

        if (!serf_request_failed && !holder && !serf_requested) {
            if (_requests[type].serf_type != SerfType.none) {
                serf_request_failed = !send_serf_to_building(_requests[type].serf_type,
                                                             _requests[type].res_type_1,
                                                             _requests[type].res_type_2);
            }
        }
    };

    /// Port of the private C++ Building::update() (no args).
    static update_ = function() {
        var _player = undefined;
        var _total_tree = 0;
        var _total_food = 0;
        var _total_stock = 0;
        var _total_coal = 0;
        var _total_ironore = 0;
        var _total_steel = 0;
        var _total_goldore = 0;
        var _inv = undefined;
        var _map = undefined;
        var _flag_pos = 0;
        var _serf = undefined;
        if (!constructing) {
            request_serf_if_needed();

            switch (get_type()) {
                case BuildingType.boatbuilder:
                    if (holder) {
                        _player = game.get_player(get_owner());
                        _total_tree = stock[0].requested + stock[0].available;
                        if (_total_tree < stock[0].maximum) {
                            stock[0].prio =
                                _player.get_planks_boatbuilder() >> (8 + _total_tree);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.stone_mine:
                    if (holder) {
                        _total_food = stock[0].requested + stock[0].available;
                        if (_total_food < stock[0].maximum) {
                            _player = game.get_player(get_owner());
                            stock[0].prio = _player.get_food_stonemine() >> (8 + _total_food);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.coal_mine:
                    if (holder) {
                        _total_food = stock[0].requested + stock[0].available;
                        if (_total_food < stock[0].maximum) {
                            _player = game.get_player(get_owner());
                            stock[0].prio = _player.get_food_coalmine() >> (8 + _total_food);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.iron_mine:
                    if (holder) {
                        _total_food = stock[0].requested + stock[0].available;
                        if (_total_food < stock[0].maximum) {
                            _player = game.get_player(get_owner());
                            stock[0].prio = _player.get_food_ironmine() >> (8 + _total_food);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.gold_mine:
                    if (holder) {
                        _total_food = stock[0].requested + stock[0].available;
                        if (_total_food < stock[0].maximum) {
                            _player = game.get_player(get_owner());
                            stock[0].prio = _player.get_food_goldmine() >> (8 + _total_food);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.stock:
                    if (!is_active()) {
                        _inv = game.create_inventory();
                        if (_inv == undefined) {
                            return;
                        }

                        _inv.set_owner(get_owner());
                        _inv.set_building_index(get_index());
                        _inv.set_flag_index(flag);

                        inventory = _inv;
                        stock[0].requested = 0xff;
                        stock[0].available = 0xff;
                        stock[1].requested = 0xff;
                        stock[1].available = 0xff;
                        active = true;

                        game.get_player(get_owner()).add_notification(
                            MessageType.new_stock, pos, 0);
                    } else {
                        if (!serf_request_failed && !holder && !serf_requested) {
                            send_serf_to_building(SerfType.transporter,
                                                  ResourceType.none,
                                                  ResourceType.none);
                        }

                        _player = game.get_player(get_owner());
                        if (holder &&
                            (!inventory.have_any_out_mode()) == 0 &&  // Not serf or
                                                                      // res OUT mode
                            inventory.free_serf_count() == 0) {
                            if (_player.tick_send_generic_delay()) {
                                send_serf_to_building(SerfType.generic,
                                                      ResourceType.none,
                                                      ResourceType.none);
                            }
                        }

                        /* TODO Following code looks like a hack */
                        _map = game.get_map();
                        _flag_pos = _map.move_down_right(pos);
                        if (_map.has_serf(_flag_pos)) {
                            _serf = game.get_serf_at_pos(_flag_pos);
                            if (_serf == undefined || _serf.get_pos() != _flag_pos) {
                                _map.set_serf_index(_flag_pos, 0);
                            }
                        }
                    }
                    break;
                case BuildingType.hut:
                case BuildingType.tower:
                case BuildingType.fortress:
                    update_military();
                    break;
                case BuildingType.butcher:
                    if (holder) {
                        /* Request more of that delicious meat. */
                        _total_stock = stock[0].requested + stock[0].available;
                        if (_total_stock < stock[0].maximum) {
                            stock[0].prio = (0xff >> _total_stock);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.pig_farm:
                    if (holder) {
                        /* Request more wheat. */
                        _total_stock = stock[0].requested + stock[0].available;
                        if (_total_stock < stock[0].maximum) {
                            _player = game.get_player(get_owner());
                            stock[0].prio = _player.get_wheat_pigfarm() >> (8 + _total_stock);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.mill:
                    if (holder) {
                        /* Request more wheat. */
                        _total_stock = stock[0].requested + stock[0].available;
                        if (_total_stock < stock[0].maximum) {
                            _player = game.get_player(get_owner());
                            stock[0].prio = _player.get_wheat_mill() >> (8 + _total_stock);
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.baker:
                    if (holder) {
                        /* Request more flour. */
                        _total_stock = stock[0].requested + stock[0].available;
                        if (_total_stock < stock[0].maximum) {
                            stock[0].prio = 0xff >> _total_stock;
                        } else {
                            stock[0].prio = 0;
                        }
                    }
                    break;
                case BuildingType.sawmill:
                    if (holder) {
                        /* Request more lumber */
                        _total_stock = stock[1].requested + stock[1].available;
                        if (_total_stock < stock[1].maximum) {
                            stock[1].prio = 0xff >> _total_stock;
                        } else {
                            stock[1].prio = 0;
                        }
                    }
                    break;
                case BuildingType.steel_smelter:
                    if (holder) {
                        /* Request more coal */
                        _total_coal = stock[0].requested + stock[0].available;
                        if (_total_coal < stock[0].maximum) {
                            _player = game.get_player(get_owner());
                            stock[0].prio = _player.get_coal_steelsmelter() >> (8 + _total_coal);
                        } else {
                            stock[0].prio = 0;
                        }

                        /* Request more iron ore */
                        _total_ironore = stock[1].requested + stock[1].available;
                        if (_total_ironore < stock[1].maximum) {
                            stock[1].prio = 0xff >> _total_ironore;
                        } else {
                            stock[1].prio = 0;
                        }
                    }
                    break;
                case BuildingType.tool_maker:
                    if (holder) {
                        /* Request more planks. */
                        _player = game.get_player(get_owner());
                        _total_tree = stock[0].requested + stock[0].available;
                        if (_total_tree < stock[0].maximum) {
                            stock[0].prio = _player.get_planks_toolmaker() >> (8 + _total_tree);
                        } else {
                            stock[0].prio = 0;
                        }

                        /* Request more steel. */
                        _total_steel = stock[1].requested + stock[1].available;
                        if (_total_steel < stock[1].maximum) {
                            stock[1].prio = _player.get_steel_toolmaker() >> (8 + _total_steel);
                        } else {
                            stock[1].prio = 0;
                        }
                    }
                    break;
                case BuildingType.weapon_smith:
                    if (holder) {
                        /* Request more coal. */
                        _player = game.get_player(get_owner());
                        _total_coal = stock[0].requested + stock[0].available;
                        if (_total_coal < stock[0].maximum) {
                            stock[0].prio = _player.get_coal_weaponsmith() >> (8 + _total_coal);
                        } else {
                            stock[0].prio = 0;
                        }

                        /* Request more steel. */
                        _total_steel = stock[1].requested + stock[1].available;
                        if (_total_steel < stock[1].maximum) {
                            stock[1].prio =
                                _player.get_steel_weaponsmith() >> (8 + _total_steel);
                        } else {
                            stock[1].prio = 0;
                        }
                    }
                    break;
                case BuildingType.gold_smelter:
                    if (holder) {
                        /* Request more coal. */
                        _player = game.get_player(get_owner());
                        _total_coal = stock[0].requested + stock[0].available;
                        if (_total_coal < stock[0].maximum) {
                            stock[0].prio = _player.get_coal_goldsmelter() >> (8 + _total_coal);
                        } else {
                            stock[0].prio = 0;
                        }

                        /* Request more gold ore. */
                        _total_goldore = stock[1].requested + stock[1].available;
                        if (_total_goldore < stock[1].maximum) {
                            stock[1].prio = 0xff >> _total_goldore;
                        } else {
                            stock[1].prio = 0;
                        }
                    }
                    break;
                case BuildingType.castle:
                    update_castle();
                    break;
                default:
                    break;
            }
        } else { /* Unfinished */
            switch (type) {
                case BuildingType.none:
                case BuildingType.castle:
                    break;
                case BuildingType.fisher:
                case BuildingType.lumberjack:
                case BuildingType.boatbuilder:
                case BuildingType.stonecutter:
                case BuildingType.stone_mine:
                case BuildingType.coal_mine:
                case BuildingType.iron_mine:
                case BuildingType.gold_mine:
                case BuildingType.forester:
                case BuildingType.hut:
                case BuildingType.mill:
                    update_unfinished();
                    break;
                case BuildingType.stock:
                case BuildingType.farm:
                case BuildingType.butcher:
                case BuildingType.pig_farm:
                case BuildingType.baker:
                case BuildingType.sawmill:
                case BuildingType.steel_smelter:
                case BuildingType.tool_maker:
                case BuildingType.weapon_smith:
                case BuildingType.tower:
                case BuildingType.fortress:
                case BuildingType.gold_smelter:
                    update_unfinished_adv();
                    break;
                default:
                    throw ("NOT_REACHED: Building.update_");
                    break;
            }
        }
    };

    /* Update unfinished building as part of the game progression. */
    static update_unfinished = function() {
        var _player = game.get_player(get_owner());

        /* Request builder serf */
        if (!serf_request_failed && !holder && !serf_requested) {
            progress = 1;
            serf_request_failed = !send_serf_to_building(SerfType.builder,
                                                         ResourceType.hammer,
                                                         ResourceType.none);
        }

        /* Request planks */
        var _total_planks = stock[0].requested + stock[0].available;
        if (_total_planks < stock[0].maximum) {
            var _planks_prio = _player.get_planks_construction() >> (8 + _total_planks);
            if (!holder) {
                _planks_prio = _planks_prio >> 2;
            }
            stock[0].prio = _planks_prio & ~(1 << 0);
        } else {
            stock[0].prio = 0;
        }

        /* Request stone */
        var _total_stone = stock[1].requested + stock[1].available;
        if (_total_stone < stock[1].maximum) {
            var _stone_prio = 0xff >> _total_stone;
            if (!holder) {
                _stone_prio = _stone_prio >> 2;
            }
            stock[1].prio = _stone_prio & ~(1 << 0);
        } else {
            stock[1].prio = 0;
        }
    };

    static update_unfinished_adv = function() {
        if (progress > 0) {
            update_unfinished();
            return;
        }

        if (holder || serf_requested) {
            return;
        }

        /* Check whether building needs leveling */
        var _need_leveling = 0;
        var _height = game.get_leveling_height(pos);
        for (var _i = 0; _i < 7; _i++) {
            var _pos = game.get_map().pos_add_spirally(pos, _i);
            if (game.get_map().get_height(_pos) != _height) {
                _need_leveling = 1;
                break;
            }
        }

        if (_need_leveling == 0) {
            /* Already at the correct level, don't send digger */
            progress = 1;
            update_unfinished();
            return;
        }

        /* Request digger */
        if (!serf_request_failed) {
            serf_request_failed = !send_serf_to_building(SerfType.digger,
                                                         ResourceType.shovel,
                                                         ResourceType.none);
        }
    };

    /* Dispatch serf to building. */
    static send_serf_to_building = function(_serf_type, _res1, _res2) {
        var _dest = game.get_flag(flag);
        return game.send_serf_to_flag(_dest, _serf_type, _res1, _res2);
    };

    /* Update castle as part of the game progression. */
    static update_castle = function() {
        var _player = game.get_player(get_owner());
        if (_player.get_castle_knights() == _player.get_castle_knights_wanted()) {
            var _best_knight = undefined;
            var _last_knight = undefined;
            var _next_serf_index = first_knight;
            while (_next_serf_index != 0) {
                var _serf = game.get_serf(_next_serf_index);
                if (_serf == undefined) {
                    throw ("Index of nonexistent serf in the queue.");
                }
                if ((_best_knight == undefined) || _serf.get_type() < _best_knight.get_type()) {
                    _best_knight = _serf;
                }
                _last_knight = _serf;
                _next_serf_index = _serf.get_next();
            }

            if (_best_knight != undefined) {
                var _knight_type = _best_knight.get_type();
                for (var _t = SerfType.knight0; _t <= SerfType.knight4; _t++) {
                    if (_knight_type > _t) {
                        inventory.call_internal(_best_knight);
                    }
                }

                /* Switch types */
                var _tmp = _best_knight.get_type();
                _best_knight.set_type(_last_knight.get_type());
                _last_knight.set_type(_tmp);
            }
        } else if (_player.get_castle_knights() <
                   _player.get_castle_knights_wanted()) {
            var _knight_type2 = SerfType.none;
            for (var _t = SerfType.knight4; _t >= SerfType.knight0; _t--) {
                if (inventory.have_serf(_t)) {
                    _knight_type2 = _t;
                    break;
                }
            }

            if (_knight_type2 < 0) {
                /* None found */
                if (inventory.have_serf(SerfType.generic) &&
                    inventory.get_count_of(ResourceType.sword) != 0 &&
                    inventory.get_count_of(ResourceType.shield) != 0) {
                    var _serf2 = inventory.specialize_free_serf(SerfType.knight0);
                    inventory.call_internal(_serf2);

                    _serf2.add_to_defending_queue(first_knight, false);
                    first_knight = _serf2.get_index();
                    _player.increase_castle_knights();
                } else {
                    if (_player.tick_send_knight_delay()) {
                        send_serf_to_building(SerfType.none,
                                              ResourceType.none,
                                              ResourceType.none);
                    }
                }
            } else {
                /* Prepend to knights list */
                var _serf3 = inventory.call_internal(_knight_type2);
                _serf3.add_to_defending_queue(first_knight, true);
                first_knight = _serf3.get_index();
                _player.increase_castle_knights();
            }
        } else {
            _player.decrease_castle_knights();

            var _serf_index = first_knight;
            var _serf4 = game.get_serf(_serf_index);
            first_knight = _serf4.get_next();

            _serf4.stay_idle_in_stock(inventory.get_index());
        }

        if (holder &&
            !inventory.have_any_out_mode() && /* Not serf or res OUT mode */
            inventory.free_serf_count() == 0) {
            if (_player.tick_send_generic_delay()) {
                send_serf_to_building(SerfType.generic,
                                      ResourceType.none,
                                      ResourceType.none);
            }
        }

        var _map = game.get_map();
        var _flag_pos = _map.move_down_right(pos);
        if (_map.has_serf(_flag_pos)) {
            var _serf5 = game.get_serf_at_pos(_flag_pos);
            if (_serf5 == undefined || _serf5.get_pos() != _flag_pos) {
                _map.set_serf_index(_flag_pos, 0);
            }
        }
    };

    static update_military = function() {
        var _hut_occupants_from_level = global.building_hut_occupants_from_level;
        var _tower_occupants_from_level = global.building_tower_occupants_from_level;
        var _fortress_occupants_from_level = global.building_fortress_occupants_from_level;

        var _player = game.get_player(get_owner());
        var _max_occ_level =
            (_player.get_knight_occupation(threat_level) >> 4) & 0xf;
        if (_player.reduced_knight_level()) {
            _max_occ_level += 5;
        }
        if (_max_occ_level > 9) {
            _max_occ_level = 9;
        }

        var _needed_occupants = -1;
        var _max_gold = -1;
        switch (get_type()) {
            case BuildingType.hut:
                _needed_occupants = _hut_occupants_from_level[_max_occ_level];
                _max_gold = 2;
                break;
            case BuildingType.tower:
                _needed_occupants = _tower_occupants_from_level[_max_occ_level];
                _max_gold = 4;
                break;
            case BuildingType.fortress:
                _needed_occupants = _fortress_occupants_from_level[_max_occ_level];
                _max_gold = 8;
                break;
            default:
                throw ("NOT_REACHED: Building.update_military");
                break;
        }

        var _total_knights = stock[0].requested + stock[0].available;
        var _present_knights = stock[0].available;
        if (_total_knights < _needed_occupants) {
            if (!serf_request_failed) {
                serf_request_failed = !send_serf_to_building(SerfType.none,
                                                             ResourceType.none,
                                                             ResourceType.none);
            }
        } else if (_needed_occupants < _present_knights &&
                   !game.get_map().has_serf(
                       game.get_map().move_down_right(pos))) {
            /* Kick least trained knight out. */
            var _leaving_serf = undefined;
            var _serf_index = first_knight;
            while (_serf_index != 0) {
                var _serf = game.get_serf(_serf_index);
                if (_serf == undefined) {
                    throw ("Index of nonexistent serf in the queue.");
                }
                if (_leaving_serf == undefined || _serf.get_type() < _leaving_serf.get_type()) {
                    _leaving_serf = _serf;
                }
                _serf_index = _serf.get_next();
            }

            if (_leaving_serf != undefined) {
                /* Remove leaving serf from list. */
                if (_leaving_serf.get_index() == first_knight) {
                    first_knight = _leaving_serf.get_next();
                } else {
                    _serf_index = first_knight;
                    while (_serf_index != 0) {
                        var _serf2 = game.get_serf(_serf_index);
                        if (_serf2.get_next() == _leaving_serf.get_index()) {
                            _serf2.set_next(_leaving_serf.get_next());
                            break;
                        }
                        _serf_index = _serf2.get_next();
                    }
                }

                /* Update serf state. */
                _leaving_serf.go_out_from_building(0, 0, -2);

                stock[0].available -= 1;
            }
        }

        /* Request gold */
        if (holder) {
            var _total_gold = stock[1].requested + stock[1].available;
            _player.increase_military_max_gold(_max_gold);

            if (_total_gold < _max_gold) {
                stock[1].prio = ((0xfe >> _total_gold) + 1) & 0xfe;
            } else {
                stock[1].prio = 0;
            }
        }
    };
}
