// scr_flag.gml - Ported from Freeserf src/flag.h and src/flag.cc (GPL-3.0),
// original copyright (C) 2013-2018 Jon Lund Steffensen <jonlst@gmail.com>.
// Flag, FlagSearch, SerfPathInfo and the flag search callbacks.
//
// Notes on the port:
//  - Flag.slot is an array of FLAG_MAX_RES_COUNT structs {type, dir, dest}
//    (C++ Flag::ResourceSlot).
//  - Flag.other_endpoint is a single array of 6 entries holding either a Flag
//    struct, a Building struct (only at Direction.up_left when has_building())
//    or undefined (C++ union other_endpoint {b[6], f[6], v[6]}).
//  - Flag.length, Flag.other_end_dir are arrays of 6 ints with the same bit
//    layout as the C++ fields.
//  - Static C++ members are exposed both as global functions
//    (flag_get_road_length_value, flag_fill_path_serf_info, flag_search_single)
//    and as statics on the constructors.
//  - Search callbacks are GML functions called as cb(flag, data).

/* Max number of resources waiting at a flag */
#macro FLAG_MAX_RES_COUNT 8

#macro FLAG_SEARCH_MAX_DEPTH 0x10000

/// Port of the C++ SerfPathInfo struct; filled in place by
/// flag_fill_path_serf_info() / Flag.fill_path_serf_info().
function SerfPathInfo() constructor {
    path_len = 0;
    serf_count = 0;
    flag_index = 0;
    flag_dir = Direction.none;
    serfs = array_create(16, 0);
}

function flag_init_tables() {
    if (variable_global_exists("flag_tables_initialised")) {
        return;
    }
    global.flag_tables_initialised = true;

    /* Resources which should be routed directly to
     buildings requesting them. Resources not listed
     here will simply be moved to an inventory. */
    global.flag_routable = [
        1,  // RESOURCE_FISH
        1,  // RESOURCE_PIG
        1,  // RESOURCE_MEAT
        1,  // RESOURCE_WHEAT
        1,  // RESOURCE_FLOUR
        1,  // RESOURCE_BREAD
        1,  // RESOURCE_LUMBER
        1,  // RESOURCE_PLANK
        0,  // RESOURCE_BOAT
        1,  // RESOURCE_STONE
        1,  // RESOURCE_IRONORE
        1,  // RESOURCE_STEEL
        1,  // RESOURCE_COAL
        1,  // RESOURCE_GOLDORE
        1,  // RESOURCE_GOLDBAR
        0,  // RESOURCE_SHOVEL
        0,  // RESOURCE_HAMMER
        0,  // RESOURCE_ROD
        0,  // RESOURCE_CLEAVER
        0,  // RESOURCE_SCYTHE
        0,  // RESOURCE_AXE
        0,  // RESOURCE_SAW
        0,  // RESOURCE_PICK
        0,  // RESOURCE_PINCER
        0,  // RESOURCE_SWORD
        0,  // RESOURCE_SHIELD
        0   // RESOURCE_GROUP_FOOD
    ];

    // max_path_serfs / max_transporters (same table in three C++ functions)
    global.flag_max_transporters = [1, 2, 3, 4, 6, 8, 11, 15];
}

/* Get road length category value for real length.
 Determines number of serfs servicing the path segment.(?) */
function flag_get_road_length_value(_length) {
    if (_length >= 24) {
        return 7;
    } else if (_length >= 18) {
        return 6;
    } else if (_length >= 13) {
        return 5;
    } else if (_length >= 10) {
        return 4;
    } else if (_length >= 7) {
        return 3;
    } else if (_length >= 6) {
        return 2;
    } else if (_length >= 4) {
        return 1;
    }
    return 0;
}

/* Find a transporter at pos and change it to state. */
function flag_change_transporter_state_at_pos(_game, _pos, _state) {
    var _serfs = _game.get_serfs_at_pos(_pos);
    for (var _i = 0; _i < array_length(_serfs); _i++) {
        var _serf = _serfs[_i];
        if (_serf.change_transporter_state_at_pos(_pos, _state)) {
            return _serf.get_index();
        }
    }

    return -1;
}

function flag_wake_transporter_at_flag(_game, _pos) {
    return flag_change_transporter_state_at_pos(_game, _pos, SerfState.wake_at_flag);
}

function flag_wake_transporter_on_path(_game, _pos) {
    return flag_change_transporter_state_at_pos(_game, _pos, SerfState.wake_on_path);
}

/// Port of static Flag::fill_path_serf_info(game, pos, dir, data).
/// _data is a SerfPathInfo struct which is filled in place.
function flag_fill_path_serf_info(_game, _pos, _dir, _data) {
    if (_data == undefined) {
        _data = new SerfPathInfo();
    }
    var _map = _game.get_map();
    var _pos_ = _pos;
    var _dir_ = _dir;
    if (_map.get_idle_serf(_pos_)) {
        flag_wake_transporter_at_flag(_game, _pos_);
    }

    var _serf_count = 0;
    var _path_len = 0;

    /* Handle first position. */
    if (_map.has_serf(_pos_)) {
        var _serf = _game.get_serf_at_pos(_pos_);
        if (_serf != undefined &&
            _serf.get_state() == SerfState.transporting &&
            _serf.get_walking_wait_counter() != -1) {
            var _d = _serf.get_walking_dir();
            if (_d < 0) {
                _d += 6;
            }

            if (_dir_ == _d) {
                _serf.set_walking_wait_counter(0);
                _data.serfs[_serf_count] = _serf.get_index();
                _serf_count++;
            }
        }
    }

    /* Trace along the path to the flag at the other end. */
    var _paths = 0;
    while (true) {
        _path_len += 1;
        _pos_ = _map.move(_pos_, _dir_);
        _paths = _map.get_paths(_pos_);
        _paths &= ~(1 << reverse_direction(_dir_));

        if (_map.has_flag(_pos_)) {
            break;
        }

        /* Find out which direction the path follows. */
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            if ((_paths & (1 << _d)) != 0) {
                _dir_ = _d;
                break;
            }
        }

        /* Check if there is a transporter waiting here. */
        if (_map.get_idle_serf(_pos_)) {
            var _index = flag_wake_transporter_on_path(_game, _pos_);
            if (_index >= 0) {
                _data.serfs[_serf_count] = _index;
                _serf_count++;
            }
        }

        /* Check if there is a serf occupying this space. */
        if (_map.has_serf(_pos_)) {
            var _serf2 = _game.get_serf_at_pos(_pos_);
            if (_serf2 != undefined &&
                _serf2.get_state() == SerfState.transporting &&
                _serf2.get_walking_wait_counter() != -1) {
                _serf2.set_walking_wait_counter(0);
                _data.serfs[_serf_count] = _serf2.get_index();
                _serf_count++;
            }
        }
    }

    /* Handle last position. */
    if (_map.has_serf(_pos_)) {
        var _serf3 = _game.get_serf_at_pos(_pos_);
        if (_serf3 != undefined &&
           ((_serf3.get_state() == SerfState.transporting &&
             _serf3.get_walking_wait_counter() != -1) ||
            _serf3.get_state() == SerfState.delivering)) {
            var _d2 = _serf3.get_walking_dir();
            if (_d2 < 0) {
                _d2 += 6;
            }

            if (_d2 == reverse_direction(_dir_)) {
                _serf3.set_walking_wait_counter(0);
                _data.serfs[_serf_count] = _serf3.get_index();
                _serf_count++;
            }
        }
    }

    /* Fill the rest of the struct. */
    _data.path_len = _path_len;
    _data.serf_count = _serf_count;
    _data.flag_index = _map.get_obj_index(_pos_);
    _data.flag_dir = reverse_direction(_dir_);
    return _data;
}

// ---------------------------------------------------------------------------
// Search callbacks (C++ file-level static functions). Called as cb(flag, data).
// ---------------------------------------------------------------------------

/// data: {resource, max_prio, flag}
function flag_schedule_unknown_dest_cb(_flag, _data) {
    if (_flag.has_building()) {
        var _building = _flag.get_building();

        var _bld_prio = _building.get_max_priority_for_resource(_data.resource, 0);
        if (_bld_prio > _data.max_prio) {
            _data.max_prio = _bld_prio;
            _data.flag = _flag;
        }

        if (_data.max_prio > 204) {
            return true;
        }
    }

    return false;
}

/// data: {dest} (Flag or undefined)
function flag_find_nearest_inventory_search_cb(_flag, _data) {
    if (_flag.accepts_resources()) {
        _data.dest = _flag;
        return true;
    }
    return false;
}

/// data: {dest_index}
function flag_search_inventory_search_cb(_flag, _data) {
    if (_flag.accepts_serfs()) {
        var _building = _flag.get_building();
        _data.dest_index = _building.get_flag_index();
        return true;
    }

    return false;
}

/// data: {src, dest, slot}
function flag_schedule_known_dest_cb(_flag, _data) {
    return (_flag.schedule_known_dest_cb_(_data.src, _data.dest, _data.slot) != 0);
}

/// data: {inventory, water}
function flag_send_serf_to_road_search_cb(_flag, _data) {
    if (_flag.has_inventory()) {
        /* Inventory reached */
        var _building = _flag.get_building();
        var _inventory = _building.get_inventory();
        if (!_data.water) {
            if (_inventory.have_serf(SerfType.transporter)) {
                _data.inventory = _inventory;
                return true;
            }
        } else {
            if (_inventory.have_serf(SerfType.sailor)) {
                _data.inventory = _inventory;
                return true;
            }
        }

        if (_data.inventory == undefined &&
            _inventory.have_serf(SerfType.generic) &&
            (!_data.water ||
             _inventory.get_count_of(ResourceType.boat) > 0)) {
            _data.inventory = _inventory;
        }
    }

    return false;
}

// ---------------------------------------------------------------------------
// FlagSearch
// ---------------------------------------------------------------------------

/// Port of static FlagSearch::single(src, callback, land, transporter, data).
function flag_search_single(_src, _callback, _land, _transporter, _data) {
    var _search = new FlagSearch(_src.get_game());
    _search.add_source(_src);
    return _search.execute(_callback, _land, _transporter, _data);
}

function FlagSearch(_game) constructor {
    game = _game;
    queue = [];
    search_id = game.next_search_id();

    static get_id = function() {
        return search_id;
    };

    static add_source = function(_flag) {
        array_push(queue, _flag);
        _flag.search_num = search_id;
    };

    static execute = function(_callback, _land, _transporter, _data) {
        for (var _i = 0; _i < FLAG_SEARCH_MAX_DEPTH && array_length(queue) > 0; _i++) {
            var _flag = queue[0];
            array_delete(queue, 0, 1);

            if (_callback(_flag, _data)) {
                /* Clean up */
                queue = [];
                return true;
            }

            // cycle_directions_ccw(): up, up_left, left, down, down_right, right
            for (var _d = Direction.up; _d >= Direction.right; _d--) {
                if ((!_land || !_flag.is_water_path(_d)) &&
                    (!_transporter || _flag.has_transporter(_d)) &&
                    _flag.other_endpoint[_d] != undefined &&
                    _flag.other_endpoint[_d].search_num != search_id) {
                    _flag.other_endpoint[_d].search_num = search_id;
                    _flag.other_endpoint[_d].search_dir = _flag.search_dir;
                    var _other_flag = _flag.other_endpoint[_d];
                    array_push(queue, _other_flag);
                }
            }
        }

        /* Clean up */
        queue = [];

        return false;
    };

    static single = function(_src, _callback, _land, _transporter, _data) {
        return flag_search_single(_src, _callback, _land, _transporter, _data);
    };
}

// ---------------------------------------------------------------------------
// Flag
// ---------------------------------------------------------------------------

function Flag(_game, _index) : GameObject(_game, _index) constructor {
    flag_init_tables();

    owner = -1;
    pos = 0;
    path_con = 0;
    endpoint = 0;
    slot = array_create(FLAG_MAX_RES_COUNT, undefined);
    for (var _j = 0; _j < FLAG_MAX_RES_COUNT; _j++) {
        slot[_j] = { type: ResourceType.none, dir: Direction.none, dest: 0 };
    }

    search_num = 0;
    search_dir = Direction.right;
    transporter = 0;
    length = array_create(6, 0);
    other_endpoint = array_create(6, undefined);
    other_end_dir = array_create(6, 0);

    bld_flags = 0;
    bld2_flags = 0;

    // -----------------------------------------------------------------------
    // Inline getters/setters from flag.h
    // -----------------------------------------------------------------------

    static get_position = function() {
        return pos;
    };
    static set_position = function(_pos) {
        pos = _pos;
    };

    /* Bitmap of all directions with outgoing paths. */
    static paths = function() {
        return path_con & 0x3f;
    };

    /* Whether a path exists in a given direction. */
    static has_path = function(_dir) {
        return ((path_con & (1 << _dir)) != 0);
    };

    /* Owner of this flag. */
    static get_owner = function() {
        return owner;
    };
    static set_owner = function(_owner) {
        owner = _owner;
    };

    /* Bitmap showing whether the outgoing paths are land paths. */
    static land_paths = function() {
        return endpoint & 0x3f;
    };
    /* Whether the path in the given direction is a water path. */
    static is_water_path = function(_dir) {
        return ((endpoint & (1 << _dir)) == 0);
    };
    /* Whether a building is connected to this flag. If so, the pointer to
     the other endpoint is a valid building pointer.
     (Always at UP LEFT direction). */
    static has_building = function() {
        return (((endpoint >> 6) & 1) != 0);
    };

    /* Whether resources exist that are not yet scheduled. */
    static has_resources = function() {
        return (((endpoint >> 7) & 1) != 0);
    };

    /* Bitmap showing whether the outgoing paths have transporters
     servicing them. */
    static transporters = function() {
        return transporter & 0x3f;
    };
    /* Whether the path in the given direction has a transporter
     serving it. */
    static has_transporter = function(_dir) {
        return ((transporter & (1 << _dir)) != 0);
    };
    /* Whether this flag has tried to request a transporter without success. */
    static serf_request_fail = function() {
        return (((transporter >> 7) & 1) != 0);
    };
    static serf_request_clear = function() {
        transporter &= ~(1 << 7);
    };

    /* Current number of transporters on path. */
    static free_transporter_count = function(_dir) {
        return length[_dir] & 0xf;
    };
    static transporter_to_serve = function(_dir) {
        length[_dir] -= 1;
    };
    /* Length category of path determining max number of transporters. */
    static length_category = function(_dir) {
        return (length[_dir] >> 4) & 7;
    };
    /* Whether a transporter serf was successfully requested for this path. */
    static serf_requested = function(_dir) {
        return (((length[_dir] >> 7) & 1) != 0);
    };
    static cancel_serf_request = function(_dir) {
        length[_dir] &= ~(1 << 7);
    };
    static complete_serf_request = function(_dir) {
        length[_dir] &= ~(1 << 7);
        length[_dir] += 1;
    };

    /* The slot that is scheduled for pickup by the given path. */
    static scheduled_slot = function(_dir) {
        return other_end_dir[_dir] & 7;
    };
    /* The direction from the other endpoint leading back to this flag. */
    static get_other_end_dir = function(_dir) {
        return (other_end_dir[_dir] >> 3) & 7;
    };
    static get_other_end_flag = function(_dir) {
        return other_endpoint[_dir];
    };
    /* Whether the given direction has a resource pickup scheduled. */
    static is_scheduled = function(_dir) {
        return (((other_end_dir[_dir] >> 7) & 1) != 0);
    };

    /* Whether this flag has an inventory building. */
    static has_inventory = function() {
        return (((bld_flags >> 6) & 1) != 0);
    };
    /* Whether this inventory accepts resources. */
    static accepts_resources = function() {
        return (((bld2_flags >> 7) & 1) != 0);
    };
    /* Whether this inventory accepts serfs. */
    static accepts_serfs = function() {
        return (((bld_flags >> 7) & 1) != 0);
    };

    static set_has_inventory = function() {
        bld_flags |= (1 << 6);
    };
    static set_accepts_resources = function(_accepts) {
        if (_accepts) {
            bld2_flags |= (1 << 7);
        } else {
            bld2_flags &= ~(1 << 7);
        }
    };
    static set_accepts_serfs = function(_accepts) {
        if (_accepts) {
            bld_flags |= (1 << 7);
        } else {
            bld_flags &= ~(1 << 7);
        }
    };
    static clear_flags = function() {
        bld_flags = 0;
        bld2_flags = 0;
    };

    static get_building = function() {
        return other_endpoint[Direction.up_left];
    };

    static set_search_dir = function(_dir) {
        search_dir = _dir;
    };
    static get_search_dir = function() {
        return search_dir;
    };
    static clear_search_id = function() {
        search_num = 0;
    };

    // -----------------------------------------------------------------------
    // flag.cc
    // -----------------------------------------------------------------------

    static add_path = function(_dir, _water) {
        path_con |= (1 << _dir);
        if (_water) {
            endpoint &= ~(1 << _dir);
        } else {
            endpoint |= (1 << _dir);
        }
        transporter &= ~(1 << _dir);
    };

    static del_path = function(_dir) {
        path_con &= ~(1 << _dir);
        endpoint &= ~(1 << _dir);
        transporter &= ~(1 << _dir);

        if (serf_requested(_dir)) {
            cancel_serf_request(_dir);
            var _dest = game.get_map().get_obj_index(pos);
            var _serfs = game.get_serfs_related_to(_dest, _dir);
            for (var _i = 0; _i < array_length(_serfs); _i++) {
                var _serf = _serfs[_i];
                _serf.path_deleted(_dest, _dir);
            }
        }

        other_end_dir[_dir] &= 0x78;
        other_endpoint[_dir] = undefined;

        /* Mark resource path for recalculation if they would
         have followed the removed path. */
        invalidate_resource_path(_dir);
    };

    /// C++: bool pick_up_resource(slot, Resource::Type *res, unsigned int *dest)
    /// Returns a struct {result, res, dest}: result false when the slot is
    /// empty (C++ false), otherwise true with the out-params filled.
    static pick_up_resource = function(_from_slot) {
        if (_from_slot >= FLAG_MAX_RES_COUNT) {
            throw ("Wrong flag slot index.");
        }

        if (slot[_from_slot].type == ResourceType.none) {
            return { result: false, res: ResourceType.none, dest: 0 };
        }

        var _result = { result: true, res: slot[_from_slot].type, dest: slot[_from_slot].dest };
        slot[_from_slot].type = ResourceType.none;
        slot[_from_slot].dir = Direction.none;

        fix_scheduled();

        return _result;
    };

    static drop_resource = function(_res, _dest) {
        if (_res < ResourceType.none || _res > ResourceType.group_food) {
            throw ("Wrong resource type.");
        }

        for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
            if (slot[_i].type == ResourceType.none) {
                slot[_i].type = _res;
                slot[_i].dest = _dest;
                slot[_i].dir = Direction.none;
                endpoint |= (1 << 7);
                return true;
            }
        }

        return false;
    };

    static has_empty_slot = function() {
        var _scheduled_slots = 0;
        for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
            if (slot[_i].type != ResourceType.none) {
                _scheduled_slots++;
            }
        }

        return (_scheduled_slots != FLAG_MAX_RES_COUNT);
    };

    static remove_all_resources = function() {
        for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
            if (slot[_i].type != ResourceType.none) {
                var _res = slot[_i].type;
                var _dest = slot[_i].dest;
                game.cancel_transported_resource(_res, _dest);
                game.lose_resource(_res);
            }
        }
    };

    static get_resource_at_slot = function(_slot) {
        return slot[_slot].type;
    };

    static fix_scheduled = function() {
        var _scheduled_slots = 0;
        for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
            if (slot[_i].type != ResourceType.none) {
                _scheduled_slots++;
            }
        }

        if (_scheduled_slots != 0) {
            endpoint |= (1 << 7);
        } else {
            endpoint &= ~(1 << 7);
        }
    };

    static schedule_slot_to_unknown_dest = function(_slot_num) {
        var _res = slot[_slot_num].type;
        if (global.flag_routable[_res] != 0) {
            var _search = new FlagSearch(game);
            _search.add_source(self);

            /* Handle food as one resource group */
            if (_res == ResourceType.meat ||
                _res == ResourceType.fish ||
                _res == ResourceType.bread) {
                _res = ResourceType.group_food;
            }

            var _data = { resource: _res, flag: undefined, max_prio: 0 };

            _search.execute(flag_schedule_unknown_dest_cb, false, true, _data);
            if (_data.flag != undefined) {
                show_debug_message("game: dest for flag " + string(index) + " res " +
                                   string(_slot_num) + " found: flag " +
                                   string(_data.flag.get_index()));
                var _dest_bld = _data.flag.other_endpoint[Direction.up_left];

                if (!_dest_bld.add_requested_resource(_res, true)) {
                    throw ("Failed to request resource.");
                }

                slot[_slot_num].dest = _dest_bld.get_flag_index();
                endpoint |= (1 << 7);
                return;
            }
        }

        /* Either this resource cannot be routed to a destination
         other than an inventory or such destination could not be
         found. Send to inventory instead. */
        var _r = find_nearest_inventory_for_resource();
        if (_r < 0 || _r == index) {
            /* No path to inventory was found, or
             resource is already at destination.
             In the latter case we need to move it
             forth and back once before it can be delivered. */
            if (transporters() == 0) {
                endpoint |= (1 << 7);
            } else {
                var _dir = Direction.none;
                // cycle_directions_ccw()
                for (var _d = Direction.up; _d >= Direction.right; _d--) {
                    if (has_transporter(_d)) {
                        _dir = _d;
                        break;
                    }
                }

                if ((_dir < Direction.right) || (_dir > Direction.up)) {
                    throw ("Failed to request resource.");
                }

                if (!is_scheduled(_dir)) {
                    other_end_dir[_dir] = (1 << 7) |
                        (other_end_dir[_dir] & 0x38) | _slot_num;
                }
                slot[_slot_num].dir = _dir;
            }
        } else {
            slot[_slot_num].dest = _r;
            endpoint |= (1 << 7);
        }
    };

    /* Return the flag index of the inventory nearest to flag. */
    static find_nearest_inventory_for_resource = function() {
        var _data = { dest: undefined };
        flag_search_single(self, flag_find_nearest_inventory_search_cb, false, true,
                           _data);
        if (_data.dest != undefined) {
            return _data.dest.get_index();
        }

        return -1;
    };

    static find_nearest_inventory_for_serf = function() {
        var _data = { dest_index: -1 };
        flag_search_single(self, flag_search_inventory_search_cb, true, false,
                           _data);

        return _data.dest_index;
    };

    static schedule_known_dest_cb_ = function(_src, _dest, _slot) {
        if (self == _dest) {
            /* Destination found */
            if (search_dir != 6) {
                if (!_src.is_scheduled(search_dir)) {
                    /* Item is requesting to be fetched */
                    _src.other_end_dir[search_dir] =
                        (1 << 7) | (_src.other_end_dir[search_dir] & 0x78) | _slot;
                } else {
                    var _player = game.get_player(get_owner());
                    var _other_dir = _src.other_end_dir[search_dir];

                    /* The slot the scheduled bit points at can be EMPTY by now.
                       other_end_dir names a slot and nothing guarantees the two
                       stay in step: a slot scheduled through the branch above
                       never gets its `dir` set, so Flag.update keeps offering it
                       and it can end up named by two directions at once. The
                       transporter that collects it calls prioritize_pickup for
                       its own direction only, which leaves the other direction
                       still flagged as scheduled, pointing at a slot whose type
                       is now ResourceType.none (-1).

                       Freeserf has the same hole; there it is a silent
                       out-of-bounds read of flag_prio[-1], so it never shows.
                       GML throws, which is how we found it: "Variable Index [-1]
                       out of range [26]". Treating an empty slot as no
                       competition is both safe and right - whatever is waiting
                       now should take the schedule, and the stale pointer is
                       overwritten below, which heals it. */
                    var _prio_old = -1;
                    var _old_type = _src.slot[_other_dir & 7].type;
                    if (_old_type != ResourceType.none) {
                        _prio_old = _player.get_flag_prio(_old_type);
                    }

                    var _prio_new = -1;
                    var _new_type = _src.slot[_slot].type;
                    if (_new_type != ResourceType.none) {
                        _prio_new = _player.get_flag_prio(_new_type);
                    }

                    if (_prio_new > _prio_old) {
                        /* This item has the highest priority now */
                        _src.other_end_dir[search_dir] =
                            (_src.other_end_dir[search_dir] & 0xf8) | _slot;
                    }
                    _src.slot[_slot].dir = search_dir;
                }
            }
            return true;
        }

        return false;
    };

    /// _res_waiting: array of 4 ints
    static schedule_slot_to_known_dest = function(_slot, _res_waiting) {
        var _search = new FlagSearch(game);

        search_num = _search.get_id();
        search_dir = Direction.none;
        var _tr = transporters();

        var _sources = 0;

        /* Directions where transporters are idle (zero slots waiting) */
        var _flags = (_res_waiting[0] ^ 0x3f) & transporter;

        if (_flags != 0) {
            // cycle_directions_ccw()
            for (var _k = Direction.up; _k >= Direction.right; _k--) {
                if ((_flags & (1 << _k)) != 0) {
                    _tr &= ~(1 << _k);
                    var _other_flag = other_endpoint[_k];
                    if (_other_flag.search_num != _search.get_id()) {
                        _other_flag.search_dir = _k;
                        _search.add_source(_other_flag);
                        _sources += 1;
                    }
                }
            }
        }

        if (_tr != 0) {
            for (var _j = 0; _j < 3; _j++) {
                _flags = _res_waiting[_j] ^ _res_waiting[_j + 1];
                for (var _k = Direction.up; _k >= Direction.right; _k--) {
                    if ((_flags & (1 << _k)) != 0) {
                        _tr &= ~(1 << _k);
                        var _other_flag2 = other_endpoint[_k];
                        if (_other_flag2.search_num != _search.get_id()) {
                            _other_flag2.search_dir = _k;
                            _search.add_source(_other_flag2);
                            _sources += 1;
                        }
                    }
                }
            }

            if (_tr != 0) {
                _flags = _res_waiting[3];
                for (var _k = Direction.up; _k >= Direction.right; _k--) {
                    if ((_flags & (1 << _k)) != 0) {
                        _tr &= ~(1 << _k);
                        var _other_flag3 = other_endpoint[_k];
                        if (_other_flag3.search_num != _search.get_id()) {
                            _other_flag3.search_dir = _k;
                            _search.add_source(_other_flag3);
                            _sources += 1;
                        }
                    }
                }
                if (_flags == 0) {
                    return;
                }
            }
        }

        if (_sources > 0) {
            // NOTE: `self` inside a struct literal refers to the literal itself
            // in GML, so capture the flag in a local first.
            var _this_flag = self;
            var _data = {
                src: _this_flag,
                dest: game.get_flag(slot[_slot].dest),
                slot: _slot
            };
            var _r = _search.execute(flag_schedule_known_dest_cb, false, true, _data);
            if (!_r || _data.dest == self) {
                /* Unable to deliver */
                game.cancel_transported_resource(slot[_slot].type,
                                                 slot[_slot].dest);
                slot[_slot].dest = 0;
                endpoint |= (1 << 7);
            }
        } else {
            endpoint |= (1 << 7);
        }
    };

    static prioritize_pickup = function(_dir, _player) {
        var _res_next = -1;
        var _res_prio = -1;

        for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
            if (slot[_i].type != ResourceType.none) {
                /* Use flag_prio to prioritize resource pickup. */
                var _res_dir = slot[_i].dir;
                var _res_type = slot[_i].type;
                if (_res_dir == _dir && _player.get_flag_prio(_res_type) > _res_prio) {
                    _res_next = _i;
                    _res_prio = _player.get_flag_prio(_res_type);
                }
            }
        }

        other_end_dir[_dir] &= 0x78;
        if (_res_next > -1) {
            other_end_dir[_dir] |= (1 << 7) | _res_next;
        }
    };

    static invalidate_resource_path = function(_dir) {
        for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
            if (slot[_i].type != ResourceType.none && slot[_i].dir == _dir) {
                slot[_i].dir = Direction.none;
                endpoint |= (1 << 7);
            }
        }
    };

    /* Get road length category value for real length.
     Determines number of serfs servicing the path segment.(?) */
    static get_road_length_value = function(_length) {
        return flag_get_road_length_value(_length);
    };

    static link_with_flag = function(_dest_flag, _water_path, _length, _in_dir, _out_dir) {
        _dest_flag.add_path(_in_dir, _water_path);
        add_path(_out_dir, _water_path);

        _dest_flag.other_end_dir[_in_dir] =
            (_dest_flag.other_end_dir[_in_dir] & 0xc7) | (_out_dir << 3);
        other_end_dir[_out_dir] = (other_end_dir[_out_dir] & 0xc7) | (_in_dir << 3);

        var _len = flag_get_road_length_value(_length);

        _dest_flag.length[_in_dir] = _len << 4;
        length[_out_dir] = _len << 4;

        _dest_flag.other_endpoint[_in_dir] = self;
        other_endpoint[_out_dir] = _dest_flag;
    };

    /// _data: SerfPathInfo struct
    static restore_path_serf_info = function(_dir, _data) {
        var _max_path_serfs = global.flag_max_transporters;

        var _other_flag = game.get_flag(_data.flag_index);
        var _other_dir = _data.flag_dir;

        add_path(_dir, _other_flag.is_water_path(_other_dir));

        _other_flag.transporter &= ~(1 << _other_dir);

        var _len = flag_get_road_length_value(_data.path_len);

        length[_dir] = _len << 4;
        _other_flag.length[_other_dir] =
            (0x80 & _other_flag.length[_other_dir]) | (_len << 4);

        if (_other_flag.serf_requested(_other_dir)) {
            length[_dir] |= (1 << 7);
        }

        other_end_dir[_dir] = (other_end_dir[_dir] & 0xc7) | (_other_dir << 3);
        _other_flag.other_end_dir[_other_dir] =
            (_other_flag.other_end_dir[_other_dir] & 0xc7) | (_dir << 3);

        other_endpoint[_dir] = _other_flag;
        _other_flag.other_endpoint[_other_dir] = self;

        var _max_serfs = _max_path_serfs[_len];
        if (serf_requested(_dir)) {
            _max_serfs -= 1;
        }

        if (_data.serf_count > _max_serfs) {
            for (var _i = 0; _i < _data.serf_count - _max_serfs; _i++) {
                var _serf = game.get_serf(_data.serfs[_i]);
                _serf.restore_path_serf_info();
            }
        }

        if (min(_data.serf_count, _max_serfs) > 0) {
            /* There are still transporters on the paths. */
            transporter |= (1 << _dir);
            _other_flag.transporter |= (1 << _other_dir);

            length[_dir] |= min(_data.serf_count, _max_serfs);
            _other_flag.length[_other_dir] |= min(_data.serf_count, _max_serfs);
        }
    };

    static can_demolish = function() {
        var _connected = 0;
        var _other_end = undefined;

        // cycle_directions_cw()
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            if (has_path(_d)) {
                if (is_water_path(_d)) {
                    return false;
                }

                _connected += 1;

                if (_other_end != undefined) {
                    if (other_endpoint[_d] == _other_end) {
                        return false;
                    }
                } else {
                    _other_end = other_endpoint[_d];
                }
            }
        }

        if (_connected == 2) {
            return true;
        }

        return false;
    };

    /// Static C++ Flag::fill_path_serf_info; see flag_fill_path_serf_info().
    static fill_path_serf_info = function(_game, _pos, _dir, _data) {
        flag_fill_path_serf_info(_game, _pos, _dir, _data);
    };

    static merge_paths = function(_pos) {
        var _max_transporters = global.flag_max_transporters;

        var _map = game.get_map();
        if (_map.get_paths(_pos) == 0) {
            return;
        }

        var _path_1_dir = Direction.right;
        var _path_2_dir = Direction.right;

        /* Find first direction */
        // cycle_directions_cw()
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            if (_map.has_path(_pos, _d)) {
                _path_1_dir = _d;
                break;
            }
        }

        /* Find second direction */
        // cycle_directions_ccw()
        for (var _d = Direction.up; _d >= Direction.right; _d--) {
            if (_map.has_path(_pos, _d)) {
                _path_2_dir = _d;
                break;
            }
        }

        var _path_1_data = new SerfPathInfo();
        var _path_2_data = new SerfPathInfo();

        flag_fill_path_serf_info(game, _pos, _path_1_dir, _path_1_data);
        flag_fill_path_serf_info(game, _pos, _path_2_dir, _path_2_data);

        var _flag_1 = game.get_flag(_path_1_data.flag_index);
        var _flag_2 = game.get_flag(_path_2_data.flag_index);
        var _dir_1 = _path_1_data.flag_dir;
        var _dir_2 = _path_2_data.flag_dir;

        _flag_1.other_end_dir[_dir_1] =
            (_flag_1.other_end_dir[_dir_1] & 0xc7) | (_dir_2 << 3);
        _flag_2.other_end_dir[_dir_2] =
            (_flag_2.other_end_dir[_dir_2] & 0xc7) | (_dir_1 << 3);

        _flag_1.other_endpoint[_dir_1] = _flag_2;
        _flag_2.other_endpoint[_dir_2] = _flag_1;

        _flag_1.transporter &= ~(1 << _dir_1);
        _flag_2.transporter &= ~(1 << _dir_2);

        var _len = flag_get_road_length_value(_path_1_data.path_len +
                                              _path_2_data.path_len);
        _flag_1.length[_dir_1] = _len << 4;
        _flag_2.length[_dir_2] = _len << 4;

        var _max_serfs = _max_transporters[_flag_1.length_category(_dir_1)];
        var _serf_count = _path_1_data.serf_count + _path_2_data.serf_count;
        if (_serf_count > 0) {
            _flag_1.transporter |= (1 << _dir_1);
            _flag_2.transporter |= (1 << _dir_2);

            if (_serf_count > _max_serfs) {
                /* TODO 59B8B */
            }

            _flag_1.length[_dir_1] += _serf_count;
            _flag_2.length[_dir_2] += _serf_count;
        }

        /* Update serfs with reference to this flag. */
        var _serfs = game.get_serfs_related_to(_flag_1.get_index(), _dir_1);
        var _serfs2 = game.get_serfs_related_to(_flag_2.get_index(), _dir_2);
        for (var _i = 0; _i < array_length(_serfs2); _i++) {
            array_push(_serfs, _serfs2[_i]);
        }
        for (var _i = 0; _i < array_length(_serfs); _i++) {
            var _serf = _serfs[_i];
            _serf.path_merged2(_flag_1.get_index(), _dir_1,
                               _flag_2.get_index(), _dir_2);
        }
    };

    static update = function() {
        var _max_transporters = global.flag_max_transporters;

        /* Count and store in bitfield which directions
         have strictly more than 0,1,2,3 slots waiting. */
        var _res_waiting = [0, 0, 0, 0];
        for (var _j = 0; _j < FLAG_MAX_RES_COUNT; _j++) {
            if (slot[_j].type != ResourceType.none && slot[_j].dir != Direction.none) {
                var _res_dir = slot[_j].dir;
                for (var _k = 0; _k < 4; _k++) {
                    if ((_res_waiting[_k] & (1 << _res_dir)) == 0) {
                        _res_waiting[_k] |= (1 << _res_dir);
                        break;
                    }
                }
            }
        }

        /* Count of total resources waiting at flag */
        var _waiting_count = 0;

        if (has_resources()) {
            endpoint &= ~(1 << 7);
            for (var _slot = 0; _slot < FLAG_MAX_RES_COUNT; _slot++) {
                if (slot[_slot].type != ResourceType.none) {
                    _waiting_count += 1;

                    /* Only schedule the slot if it has not already
                     been scheduled for fetch. */
                    var _res_dir2 = slot[_slot].dir;
                    if (_res_dir2 < 0) {
                        if (slot[_slot].dest != 0) {
                            /* Destination is known */
                            schedule_slot_to_known_dest(_slot, _res_waiting);
                        } else {
                            /* Destination is not known */
                            schedule_slot_to_unknown_dest(_slot);
                        }
                    }
                }
            }
        }

        /* Update transporter flags, decide if serf needs to be sent to road */
        // cycle_directions_ccw()
        for (var _j = Direction.up; _j >= Direction.right; _j--) {
            if (has_path(_j)) {
                if (serf_requested(_j)) {
                    if ((_res_waiting[2] & (1 << _j)) != 0) {
                        if (_waiting_count >= 7) {
                            transporter &= (1 << _j);
                        }
                    } else if (free_transporter_count(_j) != 0) {
                        transporter |= (1 << _j);
                    }
                } else if (free_transporter_count(_j) == 0 ||
                           (_res_waiting[2] & (1 << _j)) != 0) {
                    var _max_tr = _max_transporters[length_category(_j)];
                    if (free_transporter_count(_j) < _max_tr &&
                        !serf_request_fail()) {
                        var _r = call_transporter(_j, is_water_path(_j));
                        if (!_r) {
                            transporter |= (1 << 7);
                        }
                    }
                    if (_waiting_count >= 7) {
                        transporter &= (1 << _j);
                    }
                } else {
                    transporter |= (1 << _j);
                }
            }
        }
    };

    static call_transporter = function(_dir, _water) {
        var _dir_ = _dir;
        var _src_2 = other_endpoint[_dir_];
        var _dir_2 = get_other_end_dir(_dir_);

        search_dir = Direction.right;
        _src_2.search_dir = Direction.down_right;

        var _search = new FlagSearch(game);
        _search.add_source(self);
        _search.add_source(_src_2);

        var _data = { inventory: undefined, water: _water };
        _search.execute(flag_send_serf_to_road_search_cb, true, false, _data);
        var _inventory = _data.inventory;
        if (_inventory == undefined) {
            return false;
        }

        var _serf = _data.inventory.call_transporter(_water);

        var _dest_flag = game.get_flag(_inventory.get_flag_index());

        length[_dir_] |= (1 << 7);
        _src_2.length[_dir_2] |= (1 << 7);

        var _src = self;
        if (_dest_flag.search_dir == _src_2.search_dir) {
            _src = _src_2;
            _dir_ = _dir_2;
        }

        _serf.go_out_from_inventory(_inventory.get_index(), _src.get_index(), _dir_);

        return true;
    };

    static reset_transport = function(_other) {
        for (var _slot = 0; _slot < FLAG_MAX_RES_COUNT; _slot++) {
            if (_other.slot[_slot].type != ResourceType.none &&
                _other.slot[_slot].dest == index) {
                _other.slot[_slot].dest = 0;
                _other.endpoint |= (1 << 7);

                if (_other.slot[_slot].dir != Direction.none) {
                    var _dir = _other.slot[_slot].dir;
                    var _player = game.get_player(_other.get_owner());
                    _other.prioritize_pickup(_dir, _player);
                }
            }
        }
    };

    static reset_destination_of_stolen_resources = function() {
        for (var _i = 0; _i < FLAG_MAX_RES_COUNT; _i++) {
            if (slot[_i].type != ResourceType.none) {
                var _res = slot[_i].type;
                game.cancel_transported_resource(_res, slot[_i].dest);
                slot[_i].dest = 0;
            }
        }
    };

    static link_building = function(_building) {
        other_endpoint[Direction.up_left] = _building;
        endpoint |= (1 << 6);
    };

    static unlink_building = function() {
        other_endpoint[Direction.up_left] = undefined;
        endpoint &= ~(1 << 6);
        clear_flags();
    };
}
