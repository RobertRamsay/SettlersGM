// scr_serf.gml - Ported from Freeserf src/serf.h and src/serf.cc lines 1-2352 (GPL-3.0),
// original copyright (C) 2013-2019 Jon Lund Steffensen <jonlst@gmail.com>.
// Serf enums, the Serf constructor (all fields + state data), static tables and
// the first half of the serf state machine. Serf state handlers from serf.cc
// lines 2353-6257 are ported elsewhere as global functions named
// serf_<cpp_name>(_serf, ...) and are reachable through thin static wrappers here.
//
// Ported from Freeserf (GPL-3.0). freeserf is free software: you can redistribute
// it and/or modify it under the terms of the GNU General Public License as
// published by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version. See <http://www.gnu.org/licenses/>.

enum SerfType {
    none = -1,
    transporter = 0,        // 0
    sailor,
    digger,
    builder,
    transporter_inventory,
    lumberjack,             // 5
    sawmiller,
    stonecutter,
    forester,
    miner,
    smelter,                // 10
    fisher,
    pig_farmer,
    butcher,
    farmer,
    miller,                 // 15
    baker,
    boat_builder,
    toolmaker,
    weapon_smith,
    geologist,              // 20
    generic,
    knight0,
    knight1,
    knight2,
    knight3,                // 25
    knight4,
    dead                    // 27
}

/* The term FREE is used loosely in the following
   names to denote a state where the serf is not
   bound to a road or a flag. */
enum SerfState {
    null_state = 0,
    idle_in_stock,
    walking,
    transporting,
    entering_building,
    leaving_building,               /* 5 */
    ready_to_enter,
    ready_to_leave,
    digging,
    building,
    building_castle,                /* 10 */
    move_resource_out,
    wait_for_resource_out,
    drop_resource_out,
    delivering,
    ready_to_leave_inventory,       /* 15 */
    free_walking,
    logging,
    planning_logging,
    planning_planting,
    planting,                       /* 20 */
    planning_stone_cutting,
    stone_cutter_free_walking,
    stone_cutting,
    sawing,
    lost,                           /* 25 */
    lost_sailor,
    free_sailing,
    escape_building,
    mining,
    smelting,                       /* 30 */
    planning_fishing,
    fishing,
    planning_farming,
    farming,
    milling,                        /* 35 */
    baking,
    pig_farming,
    butchering,
    making_weapon,
    making_tool,                    /* 40 */
    building_boat,
    looking_for_geo_spot,
    sampling_geo_spot,
    knight_engaging_building,
    knight_prepare_attacking,       /* 45 */
    knight_leave_for_fight,
    knight_prepare_defending,
    knight_attacking,
    knight_defending,
    knight_attacking_victory,       /* 50 */
    knight_attacking_defeat,
    knight_occupy_enemy_building,
    knight_free_walking,
    knight_engage_defending_free,
    knight_engage_attacking_free,   /* 55 */
    knight_engage_attacking_free_join,
    knight_prepare_attacking_free,
    knight_prepare_defending_free,
    knight_prepare_defending_free_wait,
    knight_attacking_free,          /* 60 */
    knight_defending_free,
    knight_attacking_victory_free,
    knight_defending_victory_free,
    knight_attacking_free_wait,
    knight_leave_for_walk_to_fight, /* 65 */
    idle_on_path,
    wait_idle_on_path,
    wake_at_flag,
    wake_on_path,
    defending_hut,                  /* 70 */
    defending_tower,
    defending_fortress,
    scatter,
    finished_building,
    defending_castle,               /* 75 */

    /* Additional state: goes at the end to ease loading of
       original save game. */
    knight_attacking_defeat_free
}

/// Static tables for the Serf class (serf.cc file-level statics and
/// function-local const tables). Created once, stored under global.serf_*.
function serf_init_tables() {
    if (variable_global_exists("serf_counter_from_animation")) {
        return;
    }

    // Set to true to get the verbose "state X -> Y" log of the C++ set_state macro.
    global.serf_verbose_log = false;

    global.serf_counter_from_animation = [
        /* Walking (0-80) */
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,
        511, 447, 383, 319, 255, 319, 511, 767, 1023,

        /* Waiting (81-86) */
        127, 127, 127, 127, 127, 127,

        /* Digging (87-88) */
        383, 383,

        255, 223, 191, 159, 127, 159, 255, 383,  511,

        /* Building (98) */
        255,

        /* Engage defending free (99) */
        255,

        /* Building large building (100) */
        255,

        0,

        /* Building (102-105) */
        767, 511, 511, 767,

        1023, 639, 639, 1023,

        /* Transporting (turning?) (110-115) */
        63, 63, 63, 63, 63, 63,

        /* Logging (116-120) */
        1023, 31, 767, 767, 255,

        /* Planting (121-122) */
        191, 127,

        /* Stonecutting (123) */
        1535,

        /* Sawing (124) */
        2367,

        /* Mining (125-128) */
        383, 303, 303, 383,

        /* Smelting (129-130) */
        383, 383,

        /* Fishing (131-134) */
        767, 767, 127, 127,

        /* Farming (135-136) */
        1471, 1983,

        /* Milling (137) */
        383,

        /* Baking (138) */
        767,

        /* Pig farming (139) */
        383,

        /* Butchering (140) */
        1535,

        /* Sampling geology (142) */
        783, 63,

        /* Making weapon (143) */
        575,

        /* Making tool (144) */
        1535,

        /* Building boat (145-146) */
        1407, 159,

        /* Attacking (147-156) */
        127, 127, 127, 127, 127, 127, 127, 127, 127, 127,

        /* Defending (157-166) */
        127, 127, 127, 127, 127, 127, 127, 127, 127, 127,

        /* Engage attacking (167) */
        191,

        /* Victory attacking (168) */
        7,

        /* Dying attacking (169-173) */
        255, 255, 255, 255, 255,

        /* Dying defending (174-178) */
        255, 255, 255, 255, 255,

        /* Occupy attacking (179) */
        127,

        /* Victory defending (180) */
        7
    ];

    global.serf_state_name = [
        "NULL",                         // SERF_STATE_NULL
        "IDLE IN STOCK",                // SERF_STATE_IDLE_IN_STOCK
        "WALKING",                      // SERF_STATE_WALKING
        "TRANSPORTING",                 // SERF_STATE_TRANSPORTING
        "ENTERING BUILDING",            // SERF_STATE_ENTERING_BUILDING
        "LEAVING BUILDING",             // SERF_STATE_LEAVING_BUILDING
        "READY TO ENTER",               // SERF_STATE_READY_TO_ENTER
        "READY TO LEAVE",               // SERF_STATE_READY_TO_LEAVE
        "DIGGING",                      // SERF_STATE_DIGGING
        "BUILDING",                     // SERF_STATE_BUILDING
        "BUILDING CASTLE",              // SERF_STATE_BUILDING_CASTLE
        "MOVE RESOURCE OUT",            // SERF_STATE_MOVE_RESOURCE_OUT
        "WAIT FOR RESOURCE OUT",        // SERF_STATE_WAIT_FOR_RESOURCE_OUT
        "DROP RESOURCE OUT",            // SERF_STATE_DROP_RESOURCE_OUT
        "DELIVERING",                   // SERF_STATE_DELIVERING
        "READY TO LEAVE INVENTORY",     // SERF_STATE_READY_TO_LEAVE_INVENTORY
        "FREE WALKING",                 // SERF_STATE_FREE_WALKING
        "LOGGING",                      // SERF_STATE_LOGGING
        "PLANNING LOGGING",             // SERF_STATE_PLANNING_LOGGING
        "PLANNING PLANTING",            // SERF_STATE_PLANNING_PLANTING
        "PLANTING",                     // SERF_STATE_PLANTING
        "PLANNING STONECUTTING",        // SERF_STATE_PLANNING_STONECUTTING
        "STONECUTTER FREE WALKING",     // SERF_STATE_STONECUTTER_FREE_WALKING
        "STONECUTTING",                 // SERF_STATE_STONECUTTING
        "SAWING",                       // SERF_STATE_SAWING
        "LOST",                         // SERF_STATE_LOST
        "LOST SAILOR",                  // SERF_STATE_LOST_SAILOR
        "FREE SAILING",                 // SERF_STATE_FREE_SAILING
        "ESCAPE BUILDING",              // SERF_STATE_ESCAPE_BUILDING
        "MINING",                       // SERF_STATE_MINING
        "SMELTING",                     // SERF_STATE_SMELTING
        "PLANNING FISHING",             // SERF_STATE_PLANNING_FISHING
        "FISHING",                      // SERF_STATE_FISHING
        "PLANNING FARMING",             // SERF_STATE_PLANNING_FARMING
        "FARMING",                      // SERF_STATE_FARMING
        "MILLING",                      // SERF_STATE_MILLING
        "BAKING",                       // SERF_STATE_BAKING
        "PIGFARMING",                   // SERF_STATE_PIGFARMING
        "BUTCHERING",                   // SERF_STATE_BUTCHERING
        "MAKING WEAPON",                // SERF_STATE_MAKING_WEAPON
        "MAKING TOOL",                  // SERF_STATE_MAKING_TOOL
        "BUILDING BOAT",                // SERF_STATE_BUILDING_BOAT
        "LOOKING FOR GEO SPOT",         // SERF_STATE_LOOKING_FOR_GEO_SPOT
        "SAMPLING GEO SPOT",            // SERF_STATE_SAMPLING_GEO_SPOT
        "KNIGHT ENGAGING BUILDING",     // SERF_STATE_KNIGHT_ENGAGING_BUILDING
        "KNIGHT PREPARE ATTACKING",     // SERF_STATE_KNIGHT_PREPARE_ATTACKING
        "KNIGHT LEAVE FOR FIGHT",       // SERF_STATE_KNIGHT_LEAVE_FOR_FIGHT
        "KNIGHT PREPARE DEFENDING",     // SERF_STATE_KNIGHT_PREPARE_DEFENDING
        "KNIGHT ATTACKING",             // SERF_STATE_KNIGHT_ATTACKING
        "KNIGHT DEFENDING",             // SERF_STATE_KNIGHT_DEFENDING
        "KNIGHT ATTACKING VICTORY",     // SERF_STATE_KNIGHT_ATTACKING_VICTORY
        "KNIGHT ATTACKING DEFEAT",      // SERF_STATE_KNIGHT_ATTACKING_DEFEAT
        "KNIGHT OCCUPY ENEMY BUILDING", // SERF_STATE_KNIGHT_OCCUPY_ENEMY_BUILDING
        "KNIGHT FREE WALKING",          // SERF_STATE_KNIGHT_FREE_WALKING
        "KNIGHT ENGAGE DEFENDING FREE", // SERF_STATE_KNIGHT_ENGAGE_DEFENDING_FREE
        "KNIGHT ENGAGE ATTACKING FREE", // SERF_STATE_KNIGHT_ENGAGE_ATTACKING_FREE
        "KNIGHT ENGAGE ATTACKING FREE JOIN",
                                        // SERF_STATE_KNIGHT_ENGAGE_ATTACKING_FREE_JOIN
        "KNIGHT PREPARE ATTACKING FREE",   // SERF_STATE_KNIGHT_PREPARE_ATTACKING_FREE
        "KNIGHT PREPARE DEFENDING FREE",   // SERF_STATE_KNIGHT_PREPARE_DEFENDING_FREE
        "KNIGHT PREPARE DEFENDING FREE WAIT",
                                        // SERF_STATE_KNIGHT_PREPARE_DEFENDING_FREE_WAIT
        "KNIGHT ATTACKING FREE",        // SERF_STATE_KNIGHT_ATTACKING_FREE
        "KNIGHT DEFENDING FREE",        // SERF_STATE_KNIGHT_DEFENDING_FREE
        "KNIGHT ATTACKING VICTORY FREE",   // SERF_STATE_KNIGHT_ATTACKING_VICTORY_FREE
        "KNIGHT DEFENDING VICTORY FREE",   // SERF_STATE_KNIGHT_DEFENDING_VICTORY_FREE
        "KNIGHT ATTACKING FREE WAIT",   // SERF_STATE_KNIGHT_ATTACKING_FREE_WAIT
        "KNIGHT LEAVE FOR WALK TO FIGHT",
                                        // SERF_STATE_KNIGHT_LEAVE_FOR_WALK_TO_FIGHT
        "IDLE ON PATH",                 // SERF_STATE_IDLE_ON_PATH
        "WAIT IDLE ON PATH",            // SERF_STATE_WAIT_IDLE_ON_PATH
        "WAKE AT FLAG",                 // SERF_STATE_WAKE_AT_FLAG
        "WAKE ON PATH",                 // SERF_STATE_WAKE_ON_PATH
        "DEFENDING HUT",                // SERF_STATE_DEFENDING_HUT
        "DEFENDING TOWER",              // SERF_STATE_DEFENDING_TOWER
        "DEFENDING FORTRESS",           // SERF_STATE_DEFENDING_FORTRESS
        "SCATTER",                      // SERF_STATE_SCATTER
        "FINISHED BUILDING",            // SERF_STATE_FINISHED_BUILDING
        "DEFENDING CASTLE",             // SERF_STATE_DEFENDING_CASTLE
        "KNIGHT ATTACKING DEFEAT FREE"  // SERF_STATE_KNIGHT_ATTACKING_DEFEAT_FREE
    ];

    global.serf_type_name = [
        "TRANSPORTER",              // SERF_TRANSPORTER = 0,
        "SAILOR",                   // SERF_SAILOR,
        "DIGGER",                   // SERF_DIGGER,
        "BUILDER",                  // SERF_BUILDER,
        "TRANSPORTER_INVENTORY",    // SERF_TRANSPORTER_INVENTORY,
        "LUMBERJACK",               // SERF_LUMBERJACK,
        "SAWMILLER",                // TypeSawmiller,
        "STONECUTTER",              // TypeStonecutter,
        "FORESTER",                 // TypeForester,
        "MINER",                    // TypeMiner,
        "SMELTER",                  // TypeSmelter,
        "FISHER",                   // TypeFisher,
        "PIGFARMER",                // TypePigFarmer,
        "BUTCHER",                  // TypeButcher,
        "FARMER",                   // TypeFarmer,
        "MILLER",                   // TypeMiller,
        "BAKER",                    // TypeBaker,
        "BOATBUILDER",              // TypeBoatBuilder,
        "TOOLMAKER",                // TypeToolmaker,
        "WEAPONSMITH",              // TypeWeaponSmith,
        "GEOLOGIST",                // TypeGeologist,
        "GENERIC",                  // TypeGeneric,
        "KNIGHT_0",                 // TypeKnight0,
        "KNIGHT_1",                 // TypeKnight1,
        "KNIGHT_2",                 // TypeKnight2,
        "KNIGHT_3",                 // TypeKnight3,
        "KNIGHT_4",                 // TypeKnight4,
        "DEAD"                      // TypeDead
    ];

    // Serf::is_waiting(): dir_from_offset
    global.serf_dir_from_offset = [
        Direction.up_left, Direction.up,   Direction.none,
        Direction.left,    Direction.none, Direction.right,
        Direction.none,    Direction.down, Direction.down_right
    ];

    // serf.cc: road_building_slope (indexed by Building::Type)
    global.serf_road_building_slope = [
        /* Finished building */
        5, 18, 18, 15, 18, 22, 22, 22,
        22, 18, 16, 18, 1, 10, 1, 15,
        15, 16, 15, 15, 10, 15, 20, 15,
        18
    ];

    // Serf::handle_serf_digging_state(): h_diff
    global.serf_digging_h_diff = [
        -1, 1, -2, 2, -3, 3, -4, 4,
        -5, 5, -6, 6, -7, 7, -8, 8
    ];

    // Serf::handle_serf_building_state(): material_order (indexed by Building::Type)
    global.serf_material_order = [
        0, 0, 0, 0, 0, 4, 0, 0,
        0, 0, 0x38, 2, 8, 2, 8, 4,
        4, 0xc, 0x14, 0x2c, 2, 0x1c, 0x1f0, 4,
        0, 0, 0, 0, 0, 0, 0, 0
    ];
}

/// Serf::get_state_name(state)
function serf_get_state_name(_state) {
    serf_init_tables();
    return global.serf_state_name[_state];
}

/// Serf::get_type_name(type)
function serf_get_type_name(_type) {
    serf_init_tables();
    return global.serf_type_name[_type];
}

/// Serf::handle_serf_walking_state_search_cb(Flag *flag, void *data)
/// FlagSearch callback; _data is the searching Serf.
function serf_handle_serf_walking_state_search_cb(_flag, _data) {
    var _serf = _data;
    var _dest = _flag.get_game().get_flag(_serf.s.walking_dest);
    if (_flag == _dest) {
        show_debug_message("serf:  dest found: " + string(_dest.get_search_dir()));
        _serf.change_direction(_dest.get_search_dir(), 0);
        return true;
    }

    return false;
}

function Serf(_game, _index) : GameObject(_game, _index) constructor {
    serf_init_tables();

    state = SerfState.null_state;
    owner = -1;
    type = SerfType.none;
    sound = false;
    animation = 0;          /* Index to animation table in data file. */
    counter = 0;
    pos = -1;
    tick = 0;

    /* Last hex direction this serf actually walked in. Cosmetic only: the
       "borntodie" cheat draws soldiers instead of knights, and a soldier who
       is standing still or fighting has no direction in his animation number,
       so he keeps facing the way he came. See scr_cheat_cf.gml. */
    cf_facing = 2;

    /* The C++ union `s`, flattened: every union member's fields become
       <member>_<field>. NOTE: the C++ relies on union aliasing between some
       members (same byte offsets B..F). walking <-> transporting alias is
       realised by sharing ONE set of fields: the C++ s.transporting.res/dest/
       dir/wait_counter are s.walking_dir1/walking_dest/walking_dir/
       walking_wait_counter here (the code mixes both names for the same
       storage). attacking <-> attacking_victory_free (move, def_index) is
       kept in sync explicitly in scr_serf_c.gml. */
    s = {
        idle_in_stock_inv_index: 0,                 /* E */

        /* States: walking, transporting, delivering.
           transporting.res == walking_dir1, transporting.dest == walking_dest,
           transporting.dir == walking_dir,
           transporting.wait_counter == walking_wait_counter (C++ union). */
        walking_dir1: 0,                            /* B */
        walking_dest: 0,                            /* C */
        walking_dir: 0,                             /* E */
        walking_wait_counter: 0,                    /* F */

        entering_building_field_B: 0,               /* B */
        entering_building_slope_len: 0,             /* C */

        /* States: leaving_building, ready_to_leave, leave_for_fight */
        leaving_building_field_B: 0,                /* B */
        leaving_building_dest: 0,                   /* C */
        leaving_building_dest2: 0,                  /* D */
        leaving_building_dir: 0,                    /* E */
        leaving_building_next_state: 0,             /* F */

        ready_to_enter_field_B: 0,                  /* B */

        digging_h_index: 0,                         /* B */
        digging_target_h: 0,                        /* C */
        digging_dig_pos: 0,                         /* D */
        digging_substate: 0,                        /* E */

        building_mode: 0,                           /* B */
        building_bld_index: 0,                      /* C */
        building_material_step: 0,                  /* E */
        building_counter: 0,                        /* F */

        building_castle_inv_index: 0,               /* C */

        /* States: move_resource_out, drop_resource_out */
        move_resource_out_res: 0,                   /* B */
        move_resource_out_res_dest: 0,              /* C */
        move_resource_out_next_state: 0,            /* F */

        ready_to_leave_inventory_mode: 0,           /* B */
        ready_to_leave_inventory_dest: 0,           /* C */
        ready_to_leave_inventory_inv_index: 0,      /* E */

        /* States: free_walking, logging, planting, stonecutting, fishing,
           farming, sampling_geo_spot, knight_free_walking,
           knight_attacking_free, knight_attacking_free_wait */
        free_walking_dist_col: 0,                   /* B */
        free_walking_dist_row: 0,                   /* C */
        free_walking_neg_dist1: 0,                  /* D */
        free_walking_neg_dist2: 0,                  /* E */
        free_walking_flags: 0,                      /* F */

        sawing_mode: 0,                             /* B */

        lost_field_B: 0,                            /* B */

        mining_substate: 0,                         /* B */
        mining_res: 0,                              /* D */
        mining_deposit: 0,                          /* E */

        /* type: Type of smelter (0 is steel, else gold). */
        smelting_mode: 0,                           /* B */
        smelting_counter: 0,                        /* C */
        smelting_type: 0,                           /* D */

        milling_mode: 0,                            /* B */
        baking_mode: 0,                             /* B */
        pigfarming_mode: 0,                         /* B */
        butchering_mode: 0,                         /* B */
        making_weapon_mode: 0,                      /* B */
        making_tool_mode: 0,                        /* B */
        building_boat_mode: 0,                      /* B */

        /* States: knight_engaging_building, knight_prepare_attacking,
           knight_prepare_defending_free_wait, knight_attacking_defeat_free,
           knight_attacking, knight_attacking_victory,
           knight_engage_attacking_free, knight_engage_attacking_free_join,
           knight_attacking_victory_free */
        attacking_move: 0,                          /* B */
        attacking_attacker_won: 0,                  /* C */
        attacking_field_D: 0,                       /* D */
        attacking_def_index: 0,                     /* E */

        /* States: knight_attacking_victory_free */
        attacking_victory_free_move: 0,             /* B */
        attacking_victory_free_dist_col: 0,         /* C */
        attacking_victory_free_dist_row: 0,         /* D */
        attacking_victory_free_def_index: 0,        /* E */

        /* States: knight_defending_free, knight_engage_defending_free */
        defending_free_dist_col: 0,                 /* B */
        defending_free_dist_row: 0,                 /* C */
        defending_free_field_D: 0,                  /* D */
        defending_free_other_dist_col: 0,           /* E */
        defending_free_other_dist_row: 0,           /* F */

        leave_for_walk_to_fight_dist_col: 0,        /* B */
        leave_for_walk_to_fight_dist_row: 0,        /* C */
        leave_for_walk_to_fight_field_D: 0,         /* D */
        leave_for_walk_to_fight_field_E: 0,         /* E */
        leave_for_walk_to_fight_next_state: 0,      /* F */

        /* States: idle_on_path, wait_idle_on_path, wake_at_flag, wake_on_path. */
        idle_on_path_flag: 0,                       /* C */
        idle_on_path_field_E: 0,                    /* E */
        idle_on_path_rev_dir: 0,                    /* B */

        /* States: defending_hut, defending_tower, defending_fortress,
           defending_castle */
        defending_next_knight: 0                    /* E */
    };

    // ------------------------------------------------------------------
    // set_state / set_other_state macros
    // ------------------------------------------------------------------

    static set_state = function(_new_state) {
        if (global.serf_verbose_log) {
            show_debug_message("serf: serf " + string(index)
                + " (" + serf_get_type_name(get_type()) + "): "
                + "state " + serf_get_state_name(state)
                + " -> " + serf_get_state_name(_new_state));
        }
        state = _new_state;
    };

    static set_other_state = function(_other_serf, _new_state) {
        if (global.serf_verbose_log) {
            show_debug_message("serf: serf " + string(_other_serf.index)
                + " (" + serf_get_type_name(_other_serf.get_type()) + "): "
                + "state " + serf_get_state_name(_other_serf.state)
                + " -> " + serf_get_state_name(_new_state));
        }
        _other_serf.state = _new_state;
    };

    // ------------------------------------------------------------------
    // Inline accessors from serf.h
    // ------------------------------------------------------------------

    static get_owner = function() {
        return owner;
    };
    static set_owner = function(_player_num) {
        owner = _player_num;
    };

    static get_type = function() {
        return type;
    };

    static playing_sfx = function() {
        return sound;
    };
    static start_playing_sfx = function() {
        sound = true;
    };
    static stop_playing_sfx = function() {
        sound = false;
    };

    static get_state = function() {
        return state;
    };
    static get_animation = function() {
        return animation;
    };
    static get_counter = function() {
        return counter;
    };

    static get_pos = function() {
        return pos;
    };

    static get_free_walking_neg_dist1 = function() {
        return s.free_walking_neg_dist1;
    };
    static get_free_walking_neg_dist2 = function() {
        return s.free_walking_neg_dist2;
    };
    static get_leaving_building_next_state = function() {
        return s.leaving_building_next_state;
    };
    static get_leaving_building_field_B = function() {
        return s.leaving_building_field_B;
    };
    static get_mining_res = function() {
        return s.mining_res;
    };
    static get_attacking_field_D = function() {
        return s.attacking_field_D;
    };
    static get_attacking_def_index = function() {
        return s.attacking_def_index;
    };
    static get_walking_wait_counter = function() {
        return s.walking_wait_counter;
    };
    static set_walking_wait_counter = function(_new_counter) {
        s.walking_wait_counter = _new_counter;
    };
    static get_walking_dir = function() {
        return s.walking_dir;
    };
    static get_idle_in_stock_inv_index = function() {
        return s.idle_in_stock_inv_index;
    };
    static get_mining_substate = function() {
        return s.mining_substate;
    };

    static get_next = function() {
        return s.defending_next_knight;
    };
    static set_next = function(_next) {
        s.defending_next_knight = _next;
    };

    static get_state_name = function(_state) {
        return serf_get_state_name(_state);
    };
    static get_type_name = function(_type) {
        return serf_get_type_name(_type);
    };

    // ------------------------------------------------------------------
    // serf.cc
    // ------------------------------------------------------------------

    /* Change type of serf and update all global tables
       tracking serf types. */
    static set_type = function(_new_type) {
        if (_new_type == type) {
            return;
        }

        var _old_type = type;
        type = _new_type;

        /* Register this type as transporter */
        if (_new_type == SerfType.transporter_inventory) {
            _new_type = SerfType.transporter;
        }
        if (_old_type == SerfType.transporter_inventory) {
            _old_type = SerfType.transporter;
        }

        var _player = game.get_player(get_owner());
        if (_old_type != SerfType.none && _old_type != SerfType.dead) {
            _player.decrease_serf_count(_old_type);
        }
        if (type != SerfType.dead) {
            _player.increase_serf_count(_new_type);
        }

        if (_old_type >= SerfType.knight0 &&
            _old_type <= SerfType.knight4) {
            var _value = 1 << (_old_type - SerfType.knight0);
            _player.decrease_military_score(_value);
        }
        if (_new_type >= SerfType.knight0 &&
            _new_type <= SerfType.knight4) {
            var _value2 = 1 << (type - SerfType.knight0);
            _player.increase_military_score(_value2);
        }
        if (_new_type == SerfType.transporter) {
            counter = 0;
        }
    };

    static add_to_defending_queue = function(_next_knight_index, _pause) {
        set_state(SerfState.defending_castle);
        s.defending_next_knight = _next_knight_index;
        if (_pause) {
            counter = 6000;
        }
    };

    static init_generic = function(_inventory) {
        set_type(SerfType.generic);
        set_owner(_inventory.get_owner());
        var _building = game.get_building(_inventory.get_building_index());
        pos = _building.get_position();
        tick = game.get_tick();
        state = SerfState.idle_in_stock;
        s.idle_in_stock_inv_index = _inventory.get_index();
    };

    static init_inventory_transporter = function(_inventory) {
        set_state(SerfState.building_castle);
        s.building_castle_inv_index = _inventory.get_index();
    };

    static reset_transport = function(_flag) {
        if (state == SerfState.walking && s.walking_dest == _flag.get_index() &&
            s.walking_dir1 < 0) {
            s.walking_dir1 = -2;
            s.walking_dest = 0;
        } else if (state == SerfState.ready_to_leave_inventory &&
                   s.ready_to_leave_inventory_dest == _flag.get_index() &&
                   s.ready_to_leave_inventory_mode < 0) {
            s.ready_to_leave_inventory_mode = -2;
            s.ready_to_leave_inventory_dest = 0;
        } else if ((state == SerfState.leaving_building || state == SerfState.ready_to_leave) &&
                   s.leaving_building_next_state == SerfState.walking &&
                   s.leaving_building_dest == _flag.get_index() &&
                   s.leaving_building_field_B < 0) {
            s.leaving_building_field_B = -2;
            s.leaving_building_dest = 0;
        } else if (state == SerfState.transporting &&
                   s.walking_dest == _flag.get_index()) {
            s.walking_dest = 0;
        } else if (state == SerfState.move_resource_out &&
                   s.move_resource_out_next_state == SerfState.drop_resource_out &&
                   s.move_resource_out_res_dest == _flag.get_index()) {
            s.move_resource_out_res_dest = 0;
        } else if (state == SerfState.drop_resource_out &&
                   s.move_resource_out_res_dest == _flag.get_index()) {
            s.move_resource_out_res_dest = 0;
        } else if (state == SerfState.leaving_building &&
                   s.leaving_building_next_state == SerfState.drop_resource_out &&
                   s.leaving_building_dest == _flag.get_index()) {
            s.leaving_building_dest = 0;
        }
    };

    /// C++: bool path_splited(flag_1, dir_1, flag_2, dir_2, int *select)
    /// Returns struct { result: bool, select: int }.
    /// NOTE: the C++ writes `select = 0` (the pointer, not *select) in the
    /// first branches, so `select` is only actually written (to 1) in the
    /// second branches; that behaviour is preserved here (select unchanged
    /// from its input value in the "0" branches).
    static path_splited = function(_flag_1, _dir_1, _flag_2, _dir_2, _select) {
        if (state == SerfState.walking) {
            if (s.walking_dest == _flag_1 && s.walking_dir1 == _dir_1) {
                return { result: true, select: _select };
            } else if (s.walking_dest == _flag_2 && s.walking_dir1 == _dir_2) {
                return { result: true, select: 1 };
            }
        } else if (state == SerfState.ready_to_leave_inventory) {
            if (s.ready_to_leave_inventory_dest == _flag_1 &&
                s.ready_to_leave_inventory_mode == _dir_1) {
                return { result: true, select: _select };
            } else if (s.ready_to_leave_inventory_dest == _flag_2 &&
                       s.ready_to_leave_inventory_mode == _dir_2) {
                return { result: true, select: 1 };
            }
        } else if ((state == SerfState.ready_to_leave || state == SerfState.leaving_building) &&
                   s.leaving_building_next_state == SerfState.walking) {
            if (s.leaving_building_dest == _flag_1 &&
                s.leaving_building_field_B == _dir_1) {
                return { result: true, select: _select };
            } else if (s.leaving_building_dest == _flag_2 &&
                       s.leaving_building_field_B == _dir_2) {
                return { result: true, select: 1 };
            }
        }

        return { result: false, select: _select };
    };

    static is_related_to = function(_dest, _dir) {
        var _result = false;

        switch (state) {
            case SerfState.walking:
                if (s.walking_dest == _dest && s.walking_dir1 == _dir) {
                    _result = true;
                }
                break;
            case SerfState.ready_to_leave_inventory:
                if (s.ready_to_leave_inventory_dest == _dest &&
                    s.ready_to_leave_inventory_mode == _dir) {
                    _result = true;
                }
                break;
            case SerfState.leaving_building:
            case SerfState.ready_to_leave:
                if (s.leaving_building_dest == _dest &&
                    s.leaving_building_field_B == _dir &&
                    s.leaving_building_next_state == SerfState.walking) {
                    _result = true;
                }
                break;
            default:
                break;
        }

        return _result;
    };

    static path_deleted = function(_dest, _dir) {
        switch (state) {
            case SerfState.walking:
                if (s.walking_dest == _dest && s.walking_dir1 == _dir) {
                    s.walking_dir1 = -2;
                    s.walking_dest = 0;
                }
                break;
            case SerfState.ready_to_leave_inventory:
                if (s.ready_to_leave_inventory_dest == _dest &&
                    s.ready_to_leave_inventory_mode == _dir) {
                    s.ready_to_leave_inventory_mode = -2;
                    s.ready_to_leave_inventory_dest = 0;
                }
                break;
            case SerfState.leaving_building:
            case SerfState.ready_to_leave:
                if (s.leaving_building_dest == _dest &&
                    s.leaving_building_field_B == _dir &&
                    s.leaving_building_next_state == SerfState.walking) {
                    s.leaving_building_field_B = -2;
                    s.leaving_building_dest = 0;
                }
                break;
            default:
                break;
        }
    };

    static path_merged = function(_flag) {
        if (state == SerfState.ready_to_leave_inventory &&
            s.ready_to_leave_inventory_dest == _flag.get_index()) {
            s.ready_to_leave_inventory_dest = 0;
            s.ready_to_leave_inventory_mode = -2;
        } else if (state == SerfState.walking && s.walking_dest == _flag.get_index()) {
            s.walking_dest = 0;
            s.walking_dir1 = -2;
        } else if (state == SerfState.idle_in_stock && true/*...*/) {
            /* TODO */
        } else if ((state == SerfState.leaving_building || state == SerfState.ready_to_leave) &&
                   s.leaving_building_dest == _flag.get_index() &&
                   s.leaving_building_next_state == SerfState.walking) {
            s.leaving_building_dest = 0;
            s.leaving_building_field_B = -2;
        }
    };

    static path_merged2 = function(_flag_1, _dir_1, _flag_2, _dir_2) {
        if (state == SerfState.ready_to_leave_inventory &&
            ((s.ready_to_leave_inventory_dest == _flag_1 &&
              s.ready_to_leave_inventory_mode == _dir_1) ||
             (s.ready_to_leave_inventory_dest == _flag_2 &&
              s.ready_to_leave_inventory_mode == _dir_2))) {
            s.ready_to_leave_inventory_dest = 0;
            s.ready_to_leave_inventory_mode = -2;
        } else if (state == SerfState.walking &&
                   ((s.walking_dest == _flag_1 && s.walking_dir1 == _dir_1) ||
                    (s.walking_dest == _flag_2 && s.walking_dir1 == _dir_2))) {
            s.walking_dest = 0;
            s.walking_dir1 = -2;
        } else if (state == SerfState.idle_in_stock) {
            /* TODO */
        } else if ((state == SerfState.leaving_building || state == SerfState.ready_to_leave) &&
                   ((s.leaving_building_dest == _flag_1 &&
                     s.leaving_building_field_B == _dir_1) ||
                    (s.leaving_building_dest == _flag_2 &&
                     s.leaving_building_field_B == _dir_2)) &&
                   s.leaving_building_next_state == SerfState.walking) {
            s.leaving_building_dest = 0;
            s.leaving_building_field_B = -2;
        }
    };

    static flag_deleted = function(_flag_pos) {
        switch (state) {
            case SerfState.ready_to_leave:
            case SerfState.leaving_building:
                s.leaving_building_next_state = SerfState.lost;
                break;
            case SerfState.finished_building:
            case SerfState.walking:
                if (game.get_map().get_paths(_flag_pos) == 0) {
                    set_state(SerfState.lost);
                }
                break;
            default:
                break;
        }
    };

    static building_deleted = function(_building_pos, _escape) {
        if (pos == _building_pos &&
            (state == SerfState.idle_in_stock || state == SerfState.ready_to_leave_inventory)) {
            if (_escape) {
                /* Serf is escaping. */
                state = SerfState.escape_building;
            } else {
                /* Kill this serf. */
                set_type(SerfType.dead);
                game.delete_serf(self);
            }
            return true;
        }

        return false;
    };

    static castle_deleted = function(_castle_pos, _transporter) {
        if ((!_transporter || (get_type() == SerfType.transporter_inventory)) &&
            pos == _castle_pos) {
            if (_transporter) {
                set_type(SerfType.transporter);
            }
        }

        counter = 0;

        if (game.get_map().get_serf_index(pos) == index) {
            set_state(SerfState.lost);
            s.lost_field_B = 0;
        } else {
            set_state(SerfState.escape_building);
        }
    };

    static change_transporter_state_at_pos = function(_pos, _state) {
        if (pos == _pos &&
            (_state == SerfState.wake_at_flag || _state == SerfState.wake_on_path ||
             _state == SerfState.wait_idle_on_path || _state == SerfState.idle_on_path)) {
            set_state(_state);
            return true;
        }
        return false;
    };

    static restore_path_serf_info = function() {
        if (state != SerfState.wake_on_path) {
            s.walking_wait_counter = -1;
            if (s.walking_dir1 != ResourceType.none) {
                var _res = s.walking_dir1;
                s.walking_dir1 = ResourceType.none;

                game.cancel_transported_resource(_res, s.walking_dest);
                game.lose_resource(_res);
            }
        } else {
            set_state(SerfState.wake_at_flag);
        }
    };

    static clear_destination = function(_dest) {
        switch (state) {
            case SerfState.walking:
                if (s.walking_dest == _dest && s.walking_dir1 < 0) {
                    s.walking_dir1 = -2;
                    s.walking_dest = 0;
                }
                break;
            case SerfState.ready_to_leave_inventory:
                if (s.ready_to_leave_inventory_dest == _dest &&
                    s.ready_to_leave_inventory_mode < 0) {
                    s.ready_to_leave_inventory_mode = -2;
                    s.ready_to_leave_inventory_dest = 0;
                }
                break;
            case SerfState.leaving_building:
            case SerfState.ready_to_leave:
                if (s.leaving_building_dest == _dest &&
                    s.leaving_building_field_B < 0 &&
                    s.leaving_building_next_state == SerfState.walking) {
                    s.leaving_building_field_B = -2;
                    s.leaving_building_dest = 0;
                }
                break;
            default:
                break;
        }
    };

    static clear_destination2 = function(_dest) {
        switch (state) {
            case SerfState.transporting:
                if (s.walking_dest == _dest) {
                    s.walking_dest = 0;
                }
                break;
            case SerfState.drop_resource_out:
                if (s.move_resource_out_res_dest == _dest) {
                    s.move_resource_out_res_dest = 0;
                }
                break;
            case SerfState.leaving_building:
                if (s.leaving_building_dest == _dest &&
                    s.leaving_building_next_state == SerfState.drop_resource_out) {
                    s.leaving_building_dest = 0;
                }
                break;
            case SerfState.move_resource_out:
                if (s.move_resource_out_res_dest == _dest &&
                    s.move_resource_out_next_state == SerfState.drop_resource_out) {
                    s.move_resource_out_res_dest = 0;
                }
                break;
            default:
                break;
        }
    };

    static idle_to_wait_state = function(_pos) {
        if (pos == _pos &&
            (get_state() == SerfState.idle_on_path || get_state() == SerfState.wait_idle_on_path ||
             get_state() == SerfState.wake_at_flag || get_state() == SerfState.wake_on_path)) {
            set_state(SerfState.wake_at_flag);
            return true;
        }
        return false;
    };

    static get_delivery = function() {
        var _res = 0;

        switch (state) {
            case SerfState.delivering:
            case SerfState.transporting:
                _res = s.walking_dir1 + 1;
                break;
            case SerfState.entering_building:
                _res = s.entering_building_field_B;
                break;
            case SerfState.leaving_building:
                _res = s.leaving_building_field_B;
                break;
            case SerfState.ready_to_enter:
                _res = s.ready_to_enter_field_B;
                break;
            case SerfState.move_resource_out:
            case SerfState.drop_resource_out:
                _res = s.move_resource_out_res;
                break;

            default:
                break;
        }

        return _res;
    };

    /// C++ walks the list with a pointer to the "next" slot; here the slot
    /// owner is tracked explicitly (undefined = this serf's own index variable).
    static extract_last_knight_from_list = function() {
        var _serf_index = index;
        var _def_owner = undefined;   /* serf whose s.defending_next_knight is the slot */
        var _def_serf = game.get_serf(_serf_index);
        while (_def_serf.s.defending_next_knight != 0) {
            _def_owner = _def_serf;
            _def_serf = game.get_serf(_def_owner.s.defending_next_knight);
        }
        if (_def_owner == undefined) {
            _serf_index = 0;
        } else {
            _def_owner.s.defending_next_knight = 0;
        }

        return _def_serf;
    };

    static insert_before = function(_knight) {
        s.defending_next_knight = _knight.get_index();
    };

    static go_out_from_inventory = function(_inventory, _dest, _mode) {
        set_state(SerfState.ready_to_leave_inventory);
        s.ready_to_leave_inventory_mode = _mode;
        s.ready_to_leave_inventory_dest = _dest;
        s.ready_to_leave_inventory_inv_index = _inventory;
    };

    static send_off_to_fight = function(_dist_col, _dist_row) {
        /* Send this serf off to fight. */
        set_state(SerfState.knight_leave_for_walk_to_fight);
        s.leave_for_walk_to_fight_dist_col = _dist_col;
        s.leave_for_walk_to_fight_dist_row = _dist_row;
        s.leave_for_walk_to_fight_field_D = 0;
        s.leave_for_walk_to_fight_field_E = 0;
        s.leave_for_walk_to_fight_next_state = SerfState.knight_free_walking;
    };

    static stay_idle_in_stock = function(_inventory) {
        set_state(SerfState.idle_in_stock);
        s.idle_in_stock_inv_index = _inventory;
    };

    static go_out_from_building = function(_dest, _dir, _field_B) {
        set_state(SerfState.ready_to_leave);
        s.leaving_building_field_B = _field_B;
        s.leaving_building_dest = _dest;
        s.leaving_building_dir = _dir;
        s.leaving_building_next_state = SerfState.walking;
    };

    /* Change serf state to lost, but make necessary clean up
       from any earlier state first. */
    static set_lost_state = function() {
        if (state == SerfState.walking) {
            if (s.walking_dir1 >= 0) {
                if (s.walking_dir1 != 6) {
                    var _dir = s.walking_dir1;
                    var _flag = game.get_flag(s.walking_dest);
                    _flag.cancel_serf_request(_dir);

                    var _other_dir = _flag.get_other_end_dir(_dir);
                    _flag.get_other_end_flag(_dir).cancel_serf_request(_other_dir);
                }
            } else if (s.walking_dir1 == -1) {
                var _flag2 = game.get_flag(s.walking_dest);
                var _building = _flag2.get_building();
                _building.requested_serf_lost();
            }

            set_state(SerfState.lost);
            s.lost_field_B = 0;
        } else if (state == SerfState.transporting || state == SerfState.delivering) {
            if (s.walking_dir1 != ResourceType.none) {
                var _res = s.walking_dir1;
                var _dest = s.walking_dest;

                game.cancel_transported_resource(_res, _dest);
                game.lose_resource(_res);
            }

            if (get_type() != SerfType.sailor) {
                set_state(SerfState.lost);
                s.lost_field_B = 0;
            } else {
                set_state(SerfState.lost_sailor);
            }
        } else {
            set_state(SerfState.lost);
            s.lost_field_B = 0;
        }
    };

    /* Return true if serf is waiting for a position to be available.
       In this case, dir will be set to the desired direction of the serf,
       or DirectionNone if the desired direction cannot be determined. */
    /// C++: bool is_waiting(Direction *dir). Returns struct { result: bool, dir: Direction }.
    /// dir is Direction.none when result is false (C++ leaves it unset).
    static is_waiting = function() {
        if ((state == SerfState.transporting || state == SerfState.walking ||
             state == SerfState.delivering) &&
            s.walking_dir < 0) {
            return { result: true, dir: s.walking_dir + 6 };
        } else if ((state == SerfState.free_walking ||
                    state == SerfState.knight_free_walking ||
                    state == SerfState.stone_cutter_free_walking) &&
                   animation == 82) {
            var _dx = s.free_walking_dist_col;
            var _dy = s.free_walking_dist_row;

            var _dir = Direction.none;
            if (abs(_dx) <= 1 && abs(_dy) <= 1 &&
                global.serf_dir_from_offset[(_dx + 1) + 3 * (_dy + 1)] > Direction.none) {
                _dir = global.serf_dir_from_offset[(_dx + 1) + 3 * (_dy + 1)];
            } else {
                _dir = Direction.none;
            }
            return { result: true, dir: _dir };
        } else if (state == SerfState.digging && s.digging_substate < 0) {
            var _d = s.digging_dig_pos;
            var _dir2 = 0;
            if (_d == 0) {
                _dir2 = Direction.up;
            } else {
                _dir2 = 6 - _d;
            }
            return { result: true, dir: _dir2 };
        }

        return { result: false, dir: Direction.none };
    };

    /* Signal waiting serf that it is possible to move in direction
       while switching position with another serf. Returns 0 if the
       switch is not acceptable. */
    static switch_waiting = function(_dir) {
        if ((state == SerfState.transporting || state == SerfState.walking ||
             state == SerfState.delivering) &&
            s.walking_dir < 0) {
            s.walking_dir = reverse_direction(_dir);
            return 1;
        } else if ((state == SerfState.free_walking ||
                    state == SerfState.knight_free_walking ||
                    state == SerfState.stone_cutter_free_walking) &&
                   animation == 82) {
            var _sign = 0;
            if (_dir < 3) {
                _sign = 1;
            } else {
                _sign = -1;
            }
            var _dx = 0;
            if ((_dir mod 3) < 2) {
                _dx = _sign;
            }
            var _dy = 0;
            if ((_dir mod 3) > 0) {
                _dy = _sign;
            }

            s.free_walking_dist_col -= _dx;
            s.free_walking_dist_row -= _dy;

            if (s.free_walking_dist_col == 0 && s.free_walking_dist_row == 0) {
                /* Arriving to destination */
                s.free_walking_flags = (1 << 3);
            }
            return 1;
        } else if (state == SerfState.digging && s.digging_substate < 0) {
            return 0;
        }

        return 0;
    };

    static train_knight = function(_p) {
        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        while (counter < 0) {
            if (game.random_int() < _p) {
                /* Level up */
                var _old_type = get_type();
                set_type(_old_type + 1);
                counter = 6000;
                return 0;
            }
            counter += 6000;
        }

        return -1;
    };

    static handle_serf_idle_in_stock_state = function() {
        var _inventory = game.get_inventory(s.idle_in_stock_inv_index);

        if (_inventory.get_serf_mode() == 0
            || _inventory.get_serf_mode() == 1 /* in, stop */
            || _inventory.get_serf_queue_length() >= 3) {
            switch (get_type()) {
                case SerfType.knight0:
                    _inventory.knight_training(self, 4000);
                    break;
                case SerfType.knight1:
                    _inventory.knight_training(self, 2000);
                    break;
                case SerfType.knight2:
                    _inventory.knight_training(self, 1000);
                    break;
                case SerfType.knight3:
                    _inventory.knight_training(self, 500);
                    break;
                case SerfType.smelter: /* TODO ??? */
                    break;
                default:
                    _inventory.serf_idle_in_stock(self);
                    break;
            }
        } else { /* out */
            _inventory.call_out_serf(self);

            set_state(SerfState.ready_to_leave_inventory);
            s.ready_to_leave_inventory_mode = -3;
            s.ready_to_leave_inventory_inv_index = _inventory.get_index();
            /* TODO immediate switch to next state. */
        }
    };

    static get_walking_animation = function(_h_diff, _dir, _switch_pos) {
        var _d = _dir;
        if (_switch_pos && _d < 3) {
            _d += 6;
        }
        return 4 + _h_diff + 9 * _d;
    };

    /* Preconditon: serf is in WALKING or TRANSPORTING state */
    static change_direction = function(_dir, _alt_end) {
        var _map = game.get_map();
        var _new_pos = _map.move(pos, _dir);

        if (!_map.has_serf(_new_pos)) {
            /* Change direction, not occupied. */
            _map.set_serf_index(pos, 0);
            animation = get_walking_animation(_map.get_height(_new_pos) -
                                              _map.get_height(pos), _dir, 0);
            s.walking_dir = reverse_direction(_dir);
        } else {
            /* Direction is occupied. */
            var _other_serf = game.get_serf_at_pos(_new_pos);
            var _w = _other_serf.is_waiting();
            var _other_dir = _w.dir;

            if (_w.result &&
                (_other_dir == reverse_direction(_dir) || _other_dir == Direction.none) &&
                _other_serf.switch_waiting(reverse_direction(_dir))) {
                /* Do the switch */
                _other_serf.pos = pos;
                _map.set_serf_index(_other_serf.pos, _other_serf.get_index());
                _other_serf.animation =
                    get_walking_animation(_map.get_height(_other_serf.pos) -
                                          _map.get_height(_new_pos),
                                          reverse_direction(_dir), 1);
                _other_serf.counter = global.serf_counter_from_animation[_other_serf.animation];

                animation = get_walking_animation(_map.get_height(_new_pos) -
                                                  _map.get_height(pos),
                                                  _dir, 1);
                s.walking_dir = reverse_direction(_dir);
            } else {
                /* Wait for other serf */
                animation = 81 + _dir;
                counter = global.serf_counter_from_animation[animation];
                s.walking_dir = _dir - 6;
                return;
            }
        }

        if (!_alt_end) {
            s.walking_wait_counter = 0;
        }
        pos = _new_pos;
        _map.set_serf_index(pos, get_index());
        counter += global.serf_counter_from_animation[animation];
        if (_alt_end && counter < 0) {
            if (_map.has_flag(_new_pos)) {
                counter = 0;
            } else {
                show_debug_message("serf: unhandled jump to 31B82.");
            }
        }
    };

    /* Precondition: serf state is in WALKING or TRANSPORTING state */
    /// Flag.pick_up_resource(slot) is expected to return { result, res, dest }
    /// (out-params of the C++); res/dest are only assigned when result is true,
    /// exactly as the C++ leaves them untouched on failure.
    static transporter_move_to_flag = function(_flag) {
        var _dir = s.walking_dir;
        if (_flag.is_scheduled(_dir)) {
            /* Fetch resource from flag */
            s.walking_wait_counter = 0;
            var _res_index = _flag.scheduled_slot(_dir);

            if (s.walking_dir1 == ResourceType.none) {
                /* Pick up resource. */
                var _pu = _flag.pick_up_resource(_res_index);
                if (_pu.result) {
                    s.walking_dir1 = _pu.res;
                    s.walking_dest = _pu.dest;
                }
            } else {
                /* Switch resources and destination. */
                var _temp_res = s.walking_dir1;
                var _temp_dest = s.walking_dest;

                var _pu2 = _flag.pick_up_resource(_res_index);
                if (_pu2.result) {
                    s.walking_dir1 = _pu2.res;
                    s.walking_dest = _pu2.dest;
                }

                _flag.drop_resource(_temp_res, _temp_dest);
            }

            /* Find next resource to be picked up */
            var _player = game.get_player(get_owner());
            _flag.prioritize_pickup(_dir, _player);
        } else if (s.walking_dir1 != ResourceType.none) {
            /* Drop resource at flag */
            if (_flag.drop_resource(s.walking_dir1, s.walking_dest)) {
                s.walking_dir1 = ResourceType.none;
            }
        }

        change_direction(_dir, 1);
    };

    static handle_serf_walking_state_search_cb = function(_flag, _data) {
        return serf_handle_serf_walking_state_search_cb(_flag, _data);
    };

    static start_walking = function(_dir, _slope, _change_pos) {
        var _map = game.get_map();
        var _new_pos = _map.move(pos, _dir);
        animation = get_walking_animation(_map.get_height(_new_pos) -
                                          _map.get_height(pos), _dir, 0);
        counter += (_slope * global.serf_counter_from_animation[animation]) >> 5;

        if (_change_pos) {
            _map.set_serf_index(pos, 0);
            _map.set_serf_index(_new_pos, get_index());
        }

        pos = _new_pos;
    };

    /* Start entering building in direction up-left.
       If join_pos is set the serf is assumed to origin from
       a joined position so the source position will not have it's
       serf index cleared. */
    static enter_building = function(_field_B, _join_pos) {
        set_state(SerfState.entering_building);

        start_walking(Direction.up_left, 32, !_join_pos);
        if (_join_pos) {
            game.get_map().set_serf_index(pos, get_index());
        }

        var _building = game.get_building_at_pos(pos);
        var _slope = global.serf_road_building_slope[_building.get_type()];
        if (!_building.is_done()) {
            _slope = 1;
        }
        s.entering_building_slope_len = (_slope * counter) >> 5;
        s.entering_building_field_B = _field_B;
    };

    /* Start leaving building by switching to LEAVING BUILDING and
       setting appropriate state. */
    static leave_building = function(_join_pos) {
        var _building = game.get_building_at_pos(pos);
        var _slope = 31 - global.serf_road_building_slope[_building.get_type()];
        if (!_building.is_done()) {
            _slope = 30;
        }

        if (_join_pos) {
            game.get_map().set_serf_index(pos, 0);
        }
        start_walking(Direction.down_right, _slope, !_join_pos);

        set_state(SerfState.leaving_building);
    };

    static handle_serf_walking_state_dest_reached = function() {
        /* Destination reached. */
        if (s.walking_dir1 < 0) {
            var _map = game.get_map();
            var _building = game.get_building_at_pos(_map.move_up_left(pos));
            _building.requested_serf_reached(self);

            if (_map.has_serf(_map.move_up_left(pos))) {
                animation = 85;
                counter = 0;
                set_state(SerfState.ready_to_enter);
            } else {
                enter_building(s.walking_dir1, 0);
            }
        } else if (s.walking_dir1 == 6) {
            set_state(SerfState.looking_for_geo_spot);
            counter = 0;
        } else {
            var _flag = game.get_flag_at_pos(pos);
            if (_flag == undefined) {
                throw ("Flag expected as destination of walking serf.");
            }
            var _dir = s.walking_dir1;
            var _other_flag = _flag.get_other_end_flag(_dir);
            if (_other_flag == undefined) {
                throw ("Path has no other end flag in selected dir.");
            }
            var _other_dir = _flag.get_other_end_dir(_dir);

            /* Increment transport serf count */
            _flag.complete_serf_request(_dir);
            _other_flag.complete_serf_request(_other_dir);

            set_state(SerfState.transporting);
            s.walking_dir1 = ResourceType.none;
            s.walking_dir = _dir;
            s.walking_wait_counter = 0;

            transporter_move_to_flag(_flag);
        }
    };

    static handle_serf_walking_state_waiting = function() {
        /* Waiting for other serf. */
        var _dir = s.walking_dir + 6;

        var _map = game.get_map();
        /* Only check for loops once in a while. */
        s.walking_wait_counter += 1;
        if ((!_map.has_flag(pos) && s.walking_wait_counter >= 10) ||
            s.walking_wait_counter >= 50) {
            var _pos = pos;

            /* Follow the chain of serfs waiting for each other and
               see if there is a loop. */
            for (var _i = 0; _i < 100; _i++) {
                _pos = _map.move(_pos, _dir);

                if (!_map.has_serf(_pos)) {
                    break;
                } else if (_map.get_serf_index(_pos) == index) {
                    /* We have found a loop, try a different direction. */
                    change_direction(reverse_direction(_dir), 0);
                    return;
                }

                /* Get next serf and follow the chain */
                var _other_serf = game.get_serf_at_pos(pos);
                if (_other_serf.state != SerfState.walking &&
                    _other_serf.state != SerfState.transporting) {
                    break;
                }

                if (_other_serf.s.walking_dir >= 0 ||
                    (_other_serf.s.walking_dir + 6) == reverse_direction(_dir)) {
                    break;
                }

                _dir = _other_serf.s.walking_dir + 6;
            }
        }

        /* Stick to the same direction */
        s.walking_wait_counter = 0;
        change_direction(s.walking_dir + 6, 0);
    };

    static handle_serf_walking_state = function() {
        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        while (counter < 0) {
            if (s.walking_dir < 0) {
                handle_serf_walking_state_waiting();
                continue;
            }

            /* 301F0 */
            if (game.get_map().has_flag(pos)) {
                /* Serf has reached a flag.
                   Search for a destination if none is known. */
                if (s.walking_dest == 0) {
                    var _flag_index = game.get_map().get_obj_index(pos);
                    var _src = game.get_flag(_flag_index);
                    var _r = _src.find_nearest_inventory_for_serf();
                    if (_r < 0) {
                        set_state(SerfState.lost);
                        s.lost_field_B = 1;
                        counter = 0;
                        return;
                    }
                    s.walking_dest = _r;
                }

                /* Check whether destination has been reached.
                   If not, find out which direction to move in
                   to reach the destination. */
                if (s.walking_dest == game.get_map().get_obj_index(pos)) {
                    handle_serf_walking_state_dest_reached();
                    return;
                } else {
                    var _src2 = game.get_flag_at_pos(pos);
                    var _search = new FlagSearch(game);
                    /* cycle_directions_ccw(): up, up_left, left, down, down_right, right */
                    for (var _i = 5; _i >= 0; _i--) {
                        if (!_src2.is_water_path(_i)) {
                            var _other_flag = _src2.get_other_end_flag(_i);
                            _other_flag.set_search_dir(_i);
                            _search.add_source(_other_flag);
                        }
                    }
                    var _r2 = _search.execute(serf_handle_serf_walking_state_search_cb,
                                              true, false, self);
                    if (_r2) {
                        continue;
                    }
                }
            } else {
                /* 30A37 */
                /* Serf is not at a flag. Just follow the road. */
                var _paths = game.get_map().get_paths(pos) & ~(1 << s.walking_dir);
                var _dir = Direction.none;
                /* cycle_directions_cw(): right .. up */
                for (var _d = 0; _d < 6; _d++) {
                    if (_paths == (1 << _d)) {
                        _dir = _d;
                        break;
                    }
                }

                if (_dir >= 0) {
                    change_direction(_dir, 0);
                    continue;
                }

                counter = 0;
            }

            /* Either the road is a dead end; or
               we are at a flag, but the flag search for
               the destination failed. */
            if (s.walking_dir1 < 0) {
                if (s.walking_dir1 < -1) {
                    set_state(SerfState.lost);
                    s.lost_field_B = 1;
                    counter = 0;
                    return;
                }

                var _flag = game.get_flag(s.walking_dest);
                var _building = _flag.get_building();
                _building.requested_serf_lost();
            } else if (s.walking_dir1 != 6) {
                var _flag2 = game.get_flag(s.walking_dest);
                var _d2 = s.walking_dir1;
                _flag2.cancel_serf_request(_d2);
                _flag2.get_other_end_flag(_d2).cancel_serf_request(
                                                _flag2.get_other_end_dir(_d2));
            }

            s.walking_dir1 = -2;
            s.walking_dest = 0;
            counter = 0;
        }
    };

    static handle_serf_transporting_state = function() {
        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        if (counter >= 0) {
            return;
        }

        if (s.walking_dir < 0) {
            change_direction(s.walking_dir + 6, 1);
        } else {
            var _map = game.get_map();
            /* 31549 */
            if (_map.has_flag(pos)) {
                /* Current position occupied by waiting transporter */
                if (s.walking_wait_counter < 0) {
                    set_state(SerfState.walking);
                    s.walking_wait_counter = 0;
                    s.walking_dir1 = -2;
                    s.walking_dest = 0;
                    counter = 0;
                    return;
                }

                /* 31590 */
                if (s.walking_dir1 != ResourceType.none &&
                    _map.get_obj_index(pos) == s.walking_dest) {
                    /* At resource destination */
                    set_state(SerfState.delivering);
                    s.walking_wait_counter = 0;

                    var _new_pos = _map.move_up_left(pos);
                    animation = 3 + _map.get_height(_new_pos) - _map.get_height(pos) +
                                (Direction.up_left + 6) * 9;
                    counter = global.serf_counter_from_animation[animation];
                    /* TODO next call is actually into the middle of
                       handle_serf_delivering_state().
                       Why is a nice and clean state switch not enough???
                       Just ignore this call and we'll be safe, I think... */
                    /* handle_serf_delivering_state(serf); */
                    return;
                }

                var _flag = game.get_flag_at_pos(pos);
                transporter_move_to_flag(_flag);
            } else {
                var _paths = _map.get_paths(pos) & ~(1 << s.walking_dir);
                var _dir = Direction.none;
                /* cycle_directions_cw(): right .. up */
                for (var _d = 0; _d < 6; _d++) {
                    if (_paths == (1 << _d)) {
                        _dir = _d;
                        break;
                    }
                }

                if (_dir < 0) {
                    set_state(SerfState.lost);
                    counter = 0;
                    return;
                }

                if (!_map.has_flag(_map.move(pos, _dir)) ||
                    s.walking_dir1 != ResourceType.none ||
                    s.walking_wait_counter < 0) {
                    change_direction(_dir, 1);
                    return;
                }

                var _flag2 = game.get_flag_at_pos(_map.move(pos, _dir));
                var _rev_dir = reverse_direction(_dir);
                var _other_flag = _flag2.get_other_end_flag(_rev_dir);
                var _other_dir = _flag2.get_other_end_dir(_rev_dir);

                if (_flag2.is_scheduled(_rev_dir)) {
                    change_direction(_dir, 1);
                    return;
                }

                animation = 110 + s.walking_dir;
                counter = global.serf_counter_from_animation[animation];
                s.walking_dir -= 6;

                if (_flag2.free_transporter_count(_rev_dir) > 1) {
                    s.walking_wait_counter += 1;
                    if (s.walking_wait_counter > 3) {
                        _flag2.transporter_to_serve(_rev_dir);
                        _other_flag.transporter_to_serve(_other_dir);
                        s.walking_wait_counter = -1;
                    }
                } else {
                    if (!_other_flag.is_scheduled(_other_dir)) {
                        /* TODO Don't use anim as state var */
                        tick = (tick & 0xff00) | (s.walking_dir & 0xff);
                        set_state(SerfState.idle_on_path);
                        s.idle_on_path_rev_dir = _rev_dir;
                        s.idle_on_path_flag = _flag2.get_index();
                        _map.set_idle_serf(pos);
                        _map.set_serf_index(pos, 0);
                        return;
                    }
                }
            }
        }
    };

    static enter_inventory = function() {
        game.get_map().set_serf_index(pos, 0);
        var _building = game.get_building_at_pos(pos);
        set_state(SerfState.idle_in_stock);
        /*serf->s.idle_in_stock.field_B = 0;
          serf->s.idle_in_stock.field_C = 0;*/
        s.idle_in_stock_inv_index = _building.get_inventory().get_index();
    };

    static handle_serf_entering_building_state = function() {
        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        if (counter < 0 || counter <= s.entering_building_slope_len) {
            if (game.get_map().get_obj_index(pos) == 0 ||
                game.get_building_at_pos(pos).is_burning()) {
                /* Burning */
                set_state(SerfState.lost);
                s.lost_field_B = 0;
                counter = 0;
                return;
            }

            counter = s.entering_building_slope_len;
            var _map = game.get_map();
            switch (get_type()) {
                case SerfType.transporter:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        var _flag_index = _map.get_obj_index(_map.move_down_right(pos));
                        var _flag = game.get_flag(_flag_index);

                        /* Mark as inventory accepting resources and serfs. */
                        _flag.set_has_inventory();
                        _flag.set_accepts_resources(true);
                        _flag.set_accepts_serfs(true);

                        set_state(SerfState.wait_for_resource_out);
                        counter = 63;
                        set_type(SerfType.transporter_inventory);
                    }
                    break;
                case SerfType.sailor:
                    enter_inventory();
                    break;
                case SerfType.digger:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        set_state(SerfState.digging);
                        s.digging_h_index = 15;

                        var _building_dg = game.get_building_at_pos(pos);
                        s.digging_dig_pos = 6;
                        s.digging_target_h = _building_dg.get_level();
                        s.digging_substate = 1;
                    }
                    break;
                case SerfType.builder:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        set_state(SerfState.building);
                        animation = 98;
                        counter = 127;
                        s.building_mode = 1;
                        s.building_bld_index = _map.get_obj_index(pos);
                        s.building_material_step = 0;

                        var _building_bl = game.get_building(s.building_bld_index);
                        switch (_building_bl.get_type()) {
                            case BuildingType.stock:
                            case BuildingType.sawmill:
                            case BuildingType.tool_maker:
                            case BuildingType.fortress:
                                s.building_material_step |= (1 << 7);
                                animation = 100;
                                break;
                            default:
                                break;
                        }
                    }
                    break;
                case SerfType.transporter_inventory:
                    _map.set_serf_index(pos, 0);
                    set_state(SerfState.wait_for_resource_out);
                    counter = 63;
                    break;
                case SerfType.lumberjack:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        set_state(SerfState.planning_logging);
                    }
                    break;
                case SerfType.sawmiller:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        if (s.entering_building_field_B != 0) {
                            var _building_sw = game.get_building_at_pos(pos);
                            var _flag_index_sw = _map.get_obj_index(_map.move_down_right(pos));
                            var _flag_sw = game.get_flag(_flag_index_sw);
                            _flag_sw.clear_flags();
                            _building_sw.stock_init(1, ResourceType.lumber, 8);
                        }
                        set_state(SerfState.sawing);
                        s.sawing_mode = 0;
                    }
                    break;
                case SerfType.stonecutter:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        set_state(SerfState.planning_stone_cutting);
                    }
                    break;
                case SerfType.forester:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        set_state(SerfState.planning_planting);
                    }
                    break;
                case SerfType.miner:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        var _building_mn = game.get_building_at_pos(pos);
                        var _bld_type = _building_mn.get_type();

                        if (s.entering_building_field_B != 0) {
                            _building_mn.start_activity();
                            _building_mn.stop_playing_sfx();

                            var _flag_mn = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_mn.clear_flags();
                            _building_mn.stock_init(0, ResourceType.group_food, 8);
                        }

                        set_state(SerfState.mining);
                        s.mining_substate = 0;
                        s.mining_deposit = 4 - (_bld_type - BuildingType.stone_mine);
                        /*s.mining.field_C = 0;*/
                        s.mining_res = 0;
                    }
                    break;
                case SerfType.smelter:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);

                        var _building_sm = game.get_building_at_pos(pos);

                        if (s.entering_building_field_B != 0) {
                            var _flag_sm = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_sm.clear_flags();
                            _building_sm.stock_init(0, ResourceType.coal, 8);

                            if (_building_sm.get_type() == BuildingType.steel_smelter) {
                                _building_sm.stock_init(1, ResourceType.iron_ore, 8);
                            } else {
                                _building_sm.stock_init(1, ResourceType.gold_ore, 8);
                            }
                        }

                        /* Switch to smelting state to begin work. */
                        set_state(SerfState.smelting);

                        if (_building_sm.get_type() == BuildingType.steel_smelter) {
                            s.smelting_type = 0;
                        } else {
                            s.smelting_type = -1;
                        }

                        s.smelting_mode = 0;
                    }
                    break;
                case SerfType.fisher:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        set_state(SerfState.planning_fishing);
                    }
                    break;
                case SerfType.pig_farmer:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);

                        if (s.entering_building_field_B != 0) {
                            var _building_pf = game.get_building_at_pos(pos);
                            var _flag_pf = game.get_flag_at_pos(_map.move_down_right(pos));

                            _building_pf.set_initial_res_in_stock(1, 1);

                            _flag_pf.clear_flags();
                            _building_pf.stock_init(0, ResourceType.wheat, 8);

                            set_state(SerfState.pig_farming);
                            s.pigfarming_mode = 0;
                        } else {
                            set_state(SerfState.pig_farming);
                            s.pigfarming_mode = 6;
                            counter = 0;
                        }
                    }
                    break;
                case SerfType.butcher:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);

                        if (s.entering_building_field_B != 0) {
                            var _building_bt = game.get_building_at_pos(pos);
                            var _flag_bt = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_bt.clear_flags();
                            _building_bt.stock_init(0, ResourceType.pig, 8);
                        }

                        set_state(SerfState.butchering);
                        s.butchering_mode = 0;
                    }
                    break;
                case SerfType.farmer:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        set_state(SerfState.planning_farming);
                    }
                    break;
                case SerfType.miller:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);

                        if (s.entering_building_field_B != 0) {
                            var _building_ml = game.get_building_at_pos(pos);
                            var _flag_ml = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_ml.clear_flags();
                            _building_ml.stock_init(0, ResourceType.wheat, 8);
                        }

                        set_state(SerfState.milling);
                        s.milling_mode = 0;
                    }
                    break;
                case SerfType.baker:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);

                        if (s.entering_building_field_B != 0) {
                            var _building_bk = game.get_building_at_pos(pos);
                            var _flag_bk = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_bk.clear_flags();
                            _building_bk.stock_init(0, ResourceType.flour, 8);
                        }

                        set_state(SerfState.baking);
                        s.baking_mode = 0;
                    }
                    break;
                case SerfType.boat_builder:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        if (s.entering_building_field_B != 0) {
                            var _building_bb = game.get_building_at_pos(pos);
                            var _flag_bb = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_bb.clear_flags();
                            _building_bb.stock_init(0, ResourceType.plank, 8);
                        }

                        set_state(SerfState.building_boat);
                        s.building_boat_mode = 0;
                    }
                    break;
                case SerfType.toolmaker:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        if (s.entering_building_field_B != 0) {
                            var _building_tm = game.get_building_at_pos(pos);
                            var _flag_tm = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_tm.clear_flags();
                            _building_tm.stock_init(0, ResourceType.plank, 8);
                            _building_tm.stock_init(1, ResourceType.steel, 8);
                        }

                        set_state(SerfState.making_tool);
                        s.making_tool_mode = 0;
                    }
                    break;
                case SerfType.weapon_smith:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        _map.set_serf_index(pos, 0);
                        if (s.entering_building_field_B != 0) {
                            var _building_ws = game.get_building_at_pos(pos);
                            var _flag_ws = game.get_flag_at_pos(_map.move_down_right(pos));
                            _flag_ws.clear_flags();
                            _building_ws.stock_init(0, ResourceType.coal, 8);
                            _building_ws.stock_init(1, ResourceType.steel, 8);
                        }

                        set_state(SerfState.making_weapon);
                        s.making_weapon_mode = 0;
                    }
                    break;
                case SerfType.geologist:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        set_state(SerfState.looking_for_geo_spot); /* TODO Should never be reached */
                        counter = 0;
                    }
                    break;
                case SerfType.generic: {
                    _map.set_serf_index(pos, 0);

                    var _building_gn = game.get_building_at_pos(pos);
                    var _inventory = _building_gn.get_inventory();
                    if (_inventory == undefined) {
                        throw ("Not inventory.");
                    }
                    _inventory.serf_come_back();

                    set_state(SerfState.idle_in_stock);
                    s.idle_in_stock_inv_index = _inventory.get_index();
                    break;
                }
                case SerfType.knight0:
                case SerfType.knight1:
                case SerfType.knight2:
                case SerfType.knight3:
                case SerfType.knight4:
                    if (s.entering_building_field_B == -2) {
                        enter_inventory();
                    } else {
                        var _building_kn = game.get_building_at_pos(pos);
                        if (_building_kn.is_burning()) {
                            set_state(SerfState.lost);
                            counter = 0;
                        } else {
                            _map.set_serf_index(pos, 0);

                            if (_building_kn.has_inventory()) {
                                set_state(SerfState.defending_castle);
                                counter = 6000;

                                /* Prepend to knight list */
                                s.defending_next_knight = _building_kn.get_first_knight();
                                _building_kn.set_first_knight(get_index());

                                game.get_player(
                                    _building_kn.get_owner()).increase_castle_knights();
                                return;
                            }

                            _building_kn.requested_knight_arrived();

                            var _next_state = -1;
                            switch (_building_kn.get_type()) {
                                case BuildingType.hut:
                                    _next_state = SerfState.defending_hut;
                                    break;
                                case BuildingType.tower:
                                    _next_state = SerfState.defending_tower;
                                    break;
                                case BuildingType.fortress:
                                    _next_state = SerfState.defending_fortress;
                                    break;
                                default:
                                    throw ("NOT_REACHED: Serf::handle_serf_entering_building_state knight building type");
                                    break;
                            }

                            /* Switch to defending state */
                            set_state(_next_state);
                            counter = 6000;

                            /* Prepend to knight list */
                            s.defending_next_knight = _building_kn.get_first_knight();
                            _building_kn.set_first_knight(get_index());
                        }
                    }
                    break;
                case SerfType.dead:
                    break;
                default:
                    throw ("NOT_REACHED: Serf::handle_serf_entering_building_state serf type");
                    break;
            }
        }
    };

    static handle_serf_leaving_building_state = function() {
        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        if (counter < 0) {
            counter = 0;
            set_state(s.leaving_building_next_state);

            /* Set field_F to 0, do this for individual states if necessary */
            if (state == SerfState.walking) {
                var _mode = s.leaving_building_field_B;
                var _dest = s.leaving_building_dest;
                s.walking_dir1 = _mode;
                s.walking_dest = _dest;
                s.walking_wait_counter = 0;
            } else if (state == SerfState.drop_resource_out) {
                var _res = s.leaving_building_field_B;
                var _res_dest = s.leaving_building_dest;
                s.move_resource_out_res = _res;
                s.move_resource_out_res_dest = _res_dest;
            } else if (state == SerfState.free_walking || state == SerfState.knight_free_walking ||
                       state == SerfState.stone_cutter_free_walking) {
                var _dist1 = s.leaving_building_field_B;
                var _dist2 = s.leaving_building_dest;
                var _neg_dist1 = s.leaving_building_dest2;
                var _neg_dist2 = s.leaving_building_dir;
                s.free_walking_dist_col = _dist1;
                s.free_walking_dist_row = _dist2;
                s.free_walking_neg_dist1 = _neg_dist1;
                s.free_walking_neg_dist2 = _neg_dist2;
                s.free_walking_flags = 0;
            } else if (state == SerfState.knight_prepare_defending || state == SerfState.scatter) {
                /* No state. */
            } else {
                show_debug_message("serf: unhandled next state when leaving building.");
            }
        }
    };

    static handle_serf_ready_to_enter_state = function() {
        var _new_pos = game.get_map().move_up_left(pos);

        if (game.get_map().has_serf(_new_pos)) {
            animation = 85;
            counter = 0;
            return;
        }

        enter_building(s.ready_to_enter_field_B, 0);
    };

    static handle_serf_ready_to_leave_state = function() {
        tick = game.get_tick();
        counter = 0;

        var _map = game.get_map();
        var _new_pos = _map.move_down_right(pos);

        if ((_map.get_serf_index(pos) != index && _map.has_serf(pos))
            || _map.has_serf(_new_pos)) {
            animation = 82;
            counter = 0;
            return;
        }

        leave_building(0);
    };

    static handle_serf_digging_state = function() {
        var _h_diff = global.serf_digging_h_diff;

        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        var _map = game.get_map();

        while (counter < 0) {
            s.digging_substate -= 1;
            if (s.digging_substate < 0) {
                show_debug_message("serf: substate -1: wait for serf.");
                var _d = s.digging_dig_pos;
                var _dir = 0;
                if (_d == 0) {
                    _dir = Direction.up;
                } else {
                    _dir = 6 - _d;
                }
                var _new_pos = _map.move(pos, _dir);

                if (_map.has_serf(_new_pos)) {
                    var _other_serf = game.get_serf_at_pos(_new_pos);
                    var _w = _other_serf.is_waiting();
                    var _other_dir = _w.dir;

                    if (_w.result &&
                        _other_dir == reverse_direction(_dir) &&
                        _other_serf.switch_waiting(_other_dir)) {
                        /* Do the switch */
                        _other_serf.pos = pos;
                        _map.set_serf_index(_other_serf.pos,
                                            _other_serf.get_index());
                        _other_serf.animation =
                            get_walking_animation(_map.get_height(_other_serf.pos) -
                                                  _map.get_height(_new_pos),
                                                  reverse_direction(_dir), 1);
                        _other_serf.counter = global.serf_counter_from_animation[_other_serf.animation];

                        if (_d != 0) {
                            animation =
                                get_walking_animation(_map.get_height(_new_pos) -
                                                      _map.get_height(pos), _dir, 1);
                        } else {
                            animation = _map.get_height(_new_pos) - _map.get_height(pos);
                        }
                    } else {
                        counter = 127;
                        s.digging_substate = 0;
                        return;
                    }
                } else {
                    _map.set_serf_index(pos, 0);
                    if (_d != 0) {
                        animation =
                            get_walking_animation(_map.get_height(_new_pos) -
                                                  _map.get_height(pos), _dir, 0);
                    } else {
                        animation = _map.get_height(_new_pos) - _map.get_height(pos);
                    }
                }

                _map.set_serf_index(_new_pos, get_index());
                pos = _new_pos;
                s.digging_substate = 3;
                counter += global.serf_counter_from_animation[animation];
            } else if (s.digging_substate == 1) {
                /* 34CD6: Change height, head back to center */
                var _h = _map.get_height(pos);
                if ((s.digging_h_index & 1) != 0) {
                    _h += -1;
                    show_debug_message("serf: substate 1: change height down.");
                } else {
                    _h += 1;
                    show_debug_message("serf: substate 1: change height up.");
                }
                _map.set_height(pos, _h);

                if (s.digging_dig_pos == 0) {
                    s.digging_substate = 1;
                } else {
                    var _dir1 = reverse_direction(6 - s.digging_dig_pos);
                    start_walking(_dir1, 32, 1);
                }
            } else if (s.digging_substate > 1) {
                show_debug_message("serf: substate 2: dig.");
                /* 34E89 */
                animation = 88 - (s.digging_h_index & 1);
                counter += 383;
            } else {
                /* 34CDC: Looking for a place to dig */
                show_debug_message("serf: substate 0: looking for place to dig "
                                   + string(s.digging_dig_pos) + ", " + string(s.digging_h_index));
                do {
                    var _h2 = _h_diff[s.digging_h_index] + s.digging_target_h;
                    if (s.digging_dig_pos >= 0 && _h2 >= 0 && _h2 < 32) {
                        if (s.digging_dig_pos == 0) {
                            var _height = _map.get_height(pos);
                            if (_height != _h2) {
                                s.digging_dig_pos -= 1;
                                continue;
                            }
                            /* Dig here */
                            s.digging_substate = 2;
                            if ((s.digging_h_index & 1) != 0) {
                                animation = 87;
                            } else {
                                animation = 88;
                            }
                            counter += 383;
                        } else {
                            var _dir2 = 6 - s.digging_dig_pos;
                            var _new_pos2 = _map.move(pos, _dir2);
                            var _new_height = _map.get_height(_new_pos2);
                            if (_new_height != _h2) {
                                s.digging_dig_pos -= 1;
                                continue;
                            }
                            show_debug_message("serf:   found at: " + string(s.digging_dig_pos) + ".");
                            /* Digging spot found */
                            if (_map.has_serf(_new_pos2)) {
                                /* Occupied by other serf, wait */
                                s.digging_substate = 0;
                                animation = 87 - s.digging_dig_pos;
                                counter = global.serf_counter_from_animation[animation];
                                return;
                            }

                            /* Go to dig there */
                            start_walking(_dir2, 32, 1);
                            s.digging_substate = 3;
                        }
                        break;
                    }

                    s.digging_dig_pos = 6;
                    s.digging_h_index -= 1;
                } until (!(s.digging_h_index >= 0));

                if (s.digging_h_index < 0) {
                    /* Done digging */
                    var _building =
                        game.get_building(game.get_map().get_obj_index(pos));
                    _building.done_leveling();
                    set_state(SerfState.ready_to_leave);
                    s.leaving_building_dest = 0;
                    s.leaving_building_field_B = -2;
                    s.leaving_building_dir = 0;
                    s.leaving_building_next_state = SerfState.walking;
                    handle_serf_ready_to_leave_state();  // TODO(jonls): why isn't a
                                                         // state switch enough?
                    return;
                }
            }
        }
    };

    static handle_serf_building_state = function() {
        var _material_order = global.serf_material_order;

        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        while (counter < 0) {
            var _building = game.get_building(s.building_bld_index);
            if (s.building_mode < 0) {
                if (_building.build_progress()) {
                    counter = 0;
                    set_state(SerfState.finished_building);
                    return;
                }

                s.building_counter -= 1;
                if (s.building_counter == 0) {
                    s.building_mode = 1;
                    animation = 98;
                    if ((s.building_material_step & (1 << 7)) != 0) {
                        animation = 100;
                    }

                    /* 353A5 */
                    var _material_step = s.building_material_step & 0xf;
                    if ((_material_order[_building.get_type()] & (1 << _material_step)) == 0) {
                        /* Planks */
                        if (_building.get_res_count_in_stock(0) == 0) {
                            counter += 256;
                            if (counter < 0) {
                                counter = 255;
                            }
                            return;
                        }

                        _building.plank_used_for_build();
                    } else {
                        /* Stone */
                        if (_building.get_res_count_in_stock(1) == 0) {
                            counter += 256;
                            if (counter < 0) {
                                counter = 255;
                            }
                            return;
                        }

                        _building.stone_used_for_build();
                    }

                    s.building_material_step += 1;
                    s.building_counter = 8;
                    s.building_mode = -1;
                }
            } else {
                if (s.building_mode == 0) {
                    s.building_mode = 1;
                    animation = 98;
                    if ((s.building_material_step & (1 << 7)) != 0) {
                        animation = 100;
                    }
                }

                /* 353A5: Duplicate code */
                var _material_step2 = s.building_material_step & 0xf;
                if ((_material_order[_building.get_type()] & (1 << _material_step2)) == 0) {
                    /* Planks */
                    if (_building.get_res_count_in_stock(0) == 0) {
                        counter += 256;
                        if (counter < 0) {
                            counter = 255;
                        }
                        return;
                    }

                    _building.plank_used_for_build();
                } else {
                    /* Stone */
                    if (_building.get_res_count_in_stock(1) == 0) {
                        counter += 256;
                        if (counter < 0) {
                            counter = 255;
                        }
                        return;
                    }

                    _building.stone_used_for_build();
                }

                s.building_material_step += 1;
                s.building_counter = 8;
                s.building_mode = -1;
            }

            var _rnd = (game.random_int() & 3) + 102;
            if ((s.building_material_step & (1 << 7)) != 0) {
                _rnd += 4;
            }
            animation = _rnd;
            counter += global.serf_counter_from_animation[animation];
        }
    };

    static handle_serf_building_castle_state = function() {
        tick = game.get_tick();

        var _inventory = game.get_inventory(s.building_castle_inv_index);
        var _building = game.get_building(_inventory.get_building_index());

        if (_building.build_progress()) { /* Finished */
            game.get_map().set_serf_index(pos, 0);
            set_state(SerfState.wait_for_resource_out);
        }
    };

    static handle_serf_move_resource_out_state = function() {
        tick = game.get_tick();
        counter = 0;

        var _map = game.get_map();
        if ((_map.get_serf_index(pos) != index && _map.has_serf(pos)) ||
            _map.has_serf(_map.move_down_right(pos))) {
            /* Occupied by serf, wait */
            animation = 82;
            counter = 0;
            return;
        }

        var _flag = game.get_flag_at_pos(_map.move_down_right(pos));
        if (!_flag.has_empty_slot()) {
            /* All resource slots at flag are occupied, wait */
            animation = 82;
            counter = 0;
            return;
        }

        var _res = s.move_resource_out_res;
        var _res_dest = s.move_resource_out_res_dest;
        var _next_state = s.move_resource_out_next_state;

        leave_building(0);
        s.leaving_building_next_state = _next_state;
        s.leaving_building_field_B = _res;
        s.leaving_building_dest = _res_dest;
    };

    /// Inventory.get_resource_from_queue() is expected to return { res, dest }
    /// (the out-params of the C++).
    static handle_serf_wait_for_resource_out_state = function() {
        if (counter != 0) {
            var _delta = (game.get_tick() - tick) & 0xFFFF;
            tick = game.get_tick();
            counter -= _delta;

            if (counter >= 0) {
                return;
            }

            counter = 0;
        }

        var _obj_index = game.get_map().get_obj_index(pos);
        var _building = game.get_building(_obj_index);
        var _inventory = _building.get_inventory();
        if (_inventory.get_serf_queue_length() > 0 ||
            !_inventory.has_resource_in_queue()) {
            return;
        }

        set_state(SerfState.move_resource_out);
        var _res = ResourceType.none;
        var _dest = 0;
        var _q = _inventory.get_resource_from_queue();
        _res = _q.res;
        _dest = _q.dest;
        s.move_resource_out_res = _res + 1;
        s.move_resource_out_res_dest = _dest;
        s.move_resource_out_next_state = SerfState.drop_resource_out;

        /* why isn't a state switch enough? */
        /*handle_serf_move_resource_out_state(serf);*/
    };

    static handle_serf_drop_resource_out_state = function() {
        var _flag = game.get_flag(game.get_map().get_obj_index(pos));

        var _res = _flag.drop_resource(s.move_resource_out_res - 1,
                                       s.move_resource_out_res_dest);
        if (!_res) {
            throw ("Failed to drop resource.");
        }

        set_state(SerfState.ready_to_enter);
        s.ready_to_enter_field_B = 0;
    };

    static handle_serf_delivering_state = function() {
        var _delta = (game.get_tick() - tick) & 0xFFFF;
        tick = game.get_tick();
        counter -= _delta;

        while (counter < 0) {
            if (s.walking_wait_counter != 0) {
                set_state(SerfState.transporting);
                s.walking_wait_counter = 0;
                var _flag = game.get_flag(game.get_map().get_obj_index(pos));
                transporter_move_to_flag(_flag);
                return;
            }

            if (s.walking_dir1 != ResourceType.none) {
                var _res = s.walking_dir1;
                s.walking_dir1 = ResourceType.none;
                var _building =
                    game.get_building_at_pos(game.get_map().move_up_left(pos));
                _building.requested_resource_delivered(_res);
            }

            animation = 4 + 9 - (animation - (3 + 10 * 9));
            s.walking_wait_counter = -s.walking_wait_counter - 1;
            counter += global.serf_counter_from_animation[animation] >> 1;
        }
    };

    static handle_serf_ready_to_leave_inventory_state = function() {
        tick = game.get_tick();
        counter = 0;

        var _map = game.get_map();
        if (_map.has_serf(pos) || _map.has_serf(_map.move_down_right(pos))) {
            animation = 82;
            counter = 0;
            return;
        }

        if (s.ready_to_leave_inventory_mode == -1) {
            var _flag = game.get_flag(s.ready_to_leave_inventory_dest);
            if (_flag.has_building()) {
                var _building = _flag.get_building();
                if (_map.has_serf(_building.get_position())) {
                    animation = 82;
                    counter = 0;
                    return;
                }
            }
        }

        var _inventory =
            game.get_inventory(s.ready_to_leave_inventory_inv_index);
        _inventory.serf_away();

        var _next_state = SerfState.walking;
        if (s.ready_to_leave_inventory_mode == -3) {
            _next_state = SerfState.scatter;
        }

        var _mode = s.ready_to_leave_inventory_mode;
        var _dest = s.ready_to_leave_inventory_dest;

        leave_building(0);
        s.leaving_building_next_state = _next_state;
        s.leaving_building_field_B = _mode;
        s.leaving_building_dest = _dest;
        s.leaving_building_dir = 0;
    };

    static drop_resource = function(_res) {
        var _flag = game.get_flag(game.get_map().get_obj_index(pos));

        /* Resource is lost if no free slot is found */
        var _result = _flag.drop_resource(_res, 0);
        if (_result) {
            var _player = game.get_player(get_owner());
            _player.increase_res_count(_res);
        }
    };

    /* Serf will try to find the closest inventory from current position, either
       by following the roads if it is already at a flag, otherwise it will try
       to find a flag nearby. */
    static find_inventory = function() {
        var _map = game.get_map();
        if (_map.has_flag(pos)) {
            var _flag = game.get_flag(_map.get_obj_index(pos));
            if ((_flag.land_paths() != 0 ||
                 (_flag.has_inventory() && _flag.accepts_serfs())) &&
                _map.get_owner(pos) == get_owner()) {
                set_state(SerfState.walking);
                s.walking_dir1 = -2;
                s.walking_dest = 0;
                s.walking_dir = 0;
                counter = 0;
                return;
            }
        }

        set_state(SerfState.lost);
        s.lost_field_B = 0;
        counter = 0;
    };

    // ------------------------------------------------------------------
    // Thin wrappers for serf.cc lines 2353-6257, ported elsewhere as
    // global functions serf_<name>(_serf, ...).
    // ------------------------------------------------------------------

    static handle_serf_free_walking_state_dest_reached = function() {
        serf_handle_serf_free_walking_state_dest_reached(self);
    };
    static handle_serf_free_walking_switch_on_dir = function(_dir) {
        serf_handle_serf_free_walking_switch_on_dir(self, _dir);
    };
    static handle_serf_free_walking_switch_with_other = function() {
        serf_handle_serf_free_walking_switch_with_other(self);
    };
    static can_pass_map_pos = function(_test_pos) {
        return serf_can_pass_map_pos(self, _test_pos);
    };
    static handle_free_walking_follow_edge = function() {
        return serf_handle_free_walking_follow_edge(self);
    };
    static handle_free_walking_common = function() {
        serf_handle_free_walking_common(self);
    };
    static handle_serf_free_walking_state = function() {
        serf_handle_serf_free_walking_state(self);
    };
    static handle_serf_logging_state = function() {
        serf_handle_serf_logging_state(self);
    };
    static handle_serf_planning_logging_state = function() {
        serf_handle_serf_planning_logging_state(self);
    };
    static handle_serf_planning_planting_state = function() {
        serf_handle_serf_planning_planting_state(self);
    };
    static handle_serf_planting_state = function() {
        serf_handle_serf_planting_state(self);
    };
    static handle_serf_planning_stonecutting = function() {
        serf_handle_serf_planning_stonecutting(self);
    };
    static handle_stonecutter_free_walking = function() {
        serf_handle_stonecutter_free_walking(self);
    };
    static handle_serf_stonecutting_state = function() {
        serf_handle_serf_stonecutting_state(self);
    };
    static handle_serf_sawing_state = function() {
        serf_handle_serf_sawing_state(self);
    };
    static handle_serf_lost_state = function() {
        serf_handle_serf_lost_state(self);
    };
    static handle_lost_sailor = function() {
        serf_handle_lost_sailor(self);
    };
    static handle_free_sailing = function() {
        serf_handle_free_sailing(self);
    };
    static handle_serf_escape_building_state = function() {
        serf_handle_serf_escape_building_state(self);
    };
    static handle_serf_mining_state = function() {
        serf_handle_serf_mining_state(self);
    };
    static handle_serf_smelting_state = function() {
        serf_handle_serf_smelting_state(self);
    };
    static handle_serf_planning_fishing_state = function() {
        serf_handle_serf_planning_fishing_state(self);
    };
    static handle_serf_fishing_state = function() {
        serf_handle_serf_fishing_state(self);
    };
    static handle_serf_planning_farming_state = function() {
        serf_handle_serf_planning_farming_state(self);
    };
    static handle_serf_farming_state = function() {
        serf_handle_serf_farming_state(self);
    };
    static handle_serf_milling_state = function() {
        serf_handle_serf_milling_state(self);
    };
    static handle_serf_baking_state = function() {
        serf_handle_serf_baking_state(self);
    };
    static handle_serf_pigfarming_state = function() {
        serf_handle_serf_pigfarming_state(self);
    };
    static handle_serf_butchering_state = function() {
        serf_handle_serf_butchering_state(self);
    };
    static handle_serf_making_weapon_state = function() {
        serf_handle_serf_making_weapon_state(self);
    };
    static handle_serf_making_tool_state = function() {
        serf_handle_serf_making_tool_state(self);
    };
    static handle_serf_building_boat_state = function() {
        serf_handle_serf_building_boat_state(self);
    };
    static handle_serf_looking_for_geo_spot_state = function() {
        serf_handle_serf_looking_for_geo_spot_state(self);
    };
    static handle_serf_sampling_geo_spot_state = function() {
        serf_handle_serf_sampling_geo_spot_state(self);
    };
    static handle_serf_knight_engaging_building_state = function() {
        serf_handle_serf_knight_engaging_building_state(self);
    };
    static set_fight_outcome = function(_attacker, _defender) {
        serf_set_fight_outcome(self, _attacker, _defender);
    };
    static handle_serf_knight_prepare_attacking = function() {
        serf_handle_serf_knight_prepare_attacking(self);
    };
    static handle_serf_knight_leave_for_fight_state = function() {
        serf_handle_serf_knight_leave_for_fight_state(self);
    };
    static handle_serf_knight_prepare_defending_state = function() {
        serf_handle_serf_knight_prepare_defending_state(self);
    };
    static handle_knight_attacking = function() {
        serf_handle_knight_attacking(self);
    };
    static handle_serf_knight_attacking_victory_state = function() {
        serf_handle_serf_knight_attacking_victory_state(self);
    };
    static handle_serf_knight_attacking_defeat_state = function() {
        serf_handle_serf_knight_attacking_defeat_state(self);
    };
    static handle_knight_occupy_enemy_building = function() {
        serf_handle_knight_occupy_enemy_building(self);
    };
    static handle_state_knight_free_walking = function() {
        serf_handle_state_knight_free_walking(self);
    };
    static handle_state_knight_engage_defending_free = function() {
        serf_handle_state_knight_engage_defending_free(self);
    };
    static handle_state_knight_engage_attacking_free = function() {
        serf_handle_state_knight_engage_attacking_free(self);
    };
    static handle_state_knight_engage_attacking_free_join = function() {
        serf_handle_state_knight_engage_attacking_free_join(self);
    };
    static handle_state_knight_prepare_attacking_free = function() {
        serf_handle_state_knight_prepare_attacking_free(self);
    };
    static handle_state_knight_prepare_defending_free = function() {
        serf_handle_state_knight_prepare_defending_free(self);
    };
    static handle_knight_attacking_victory_free = function() {
        serf_handle_knight_attacking_victory_free(self);
    };
    static handle_knight_defending_victory_free = function() {
        serf_handle_knight_defending_victory_free(self);
    };
    static handle_serf_knight_attacking_defeat_free_state = function() {
        serf_handle_serf_knight_attacking_defeat_free_state(self);
    };
    static handle_knight_attacking_free_wait = function() {
        serf_handle_knight_attacking_free_wait(self);
    };
    static handle_serf_state_knight_leave_for_walk_to_fight = function() {
        serf_handle_serf_state_knight_leave_for_walk_to_fight(self);
    };
    static handle_serf_idle_on_path_state = function() {
        serf_handle_serf_idle_on_path_state(self);
    };
    static handle_serf_wait_idle_on_path_state = function() {
        serf_handle_serf_wait_idle_on_path_state(self);
    };
    static handle_scatter_state = function() {
        serf_handle_scatter_state(self);
    };
    static handle_serf_finished_building_state = function() {
        serf_handle_serf_finished_building_state(self);
    };
    static handle_serf_wake_at_flag_state = function() {
        serf_handle_serf_wake_at_flag_state(self);
    };
    static handle_serf_wake_on_path_state = function() {
        serf_handle_serf_wake_on_path_state(self);
    };
    static handle_serf_defending_state = function(_training_params) {
        serf_handle_serf_defending_state(self, _training_params);
    };
    static handle_serf_defending_hut_state = function() {
        serf_handle_serf_defending_hut_state(self);
    };
    static handle_serf_defending_tower_state = function() {
        serf_handle_serf_defending_tower_state(self);
    };
    static handle_serf_defending_fortress_state = function() {
        serf_handle_serf_defending_fortress_state(self);
    };
    static handle_serf_defending_castle_state = function() {
        serf_handle_serf_defending_castle_state(self);
    };
    static update = function() {
        serf_update(self);
    };
    static print_state = function() {
        return serf_print_state(self);
    };
}
