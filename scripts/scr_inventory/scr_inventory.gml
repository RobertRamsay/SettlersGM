// scr_inventory.gml - Ported from Freeserf src/inventory.h and src/inventory.cc (GPL-3.0),
// original copyright (C) 2015 Wicked_Digger <wicked_digger@mail.ru>.
// Resources related definitions and implementations.
// Save/load operators (SaveReaderBinary/SaveReaderText/SaveWriterText) are skipped.

// Port of Inventory::Mode
enum InventoryMode {
    mode_in = 0,    // 00
    mode_stop = 1,  // 01
    mode_out = 3    // 11
}

/// Static const tables of inventory.cc (apply_supplies_preset, res_needed).
function inventory_init_tables() {
    if (variable_global_exists("inventory_supplies_template")) {
        return;
    }
    global.inventory_supplies_template = [
        [  0,  0,  0,  0,  0,  0,  0,   7,   0,   2,  0,   0,   0,  0,  0,  1,
           6,  1,  0,  0,  1,  2,  3,   0,  10,  10 ],
        [  2,  1,  1,  3,  2,  1,  0,  25,   1,   8,  4,   3,   8,  2,  1,  3,
          12,  2,  1,  1,  2,  3,  4,   1,  30,  30 ],
        [  3,  2,  2, 10,  3,  1,  0,  40,   2,  20, 12,   8,  20,  4,  2,  5,
          20,  3,  1,  2,  3,  4,  6,   2,  60,  60 ],
        [  8,  4,  6, 20,  7,  5,  3,  80,   5,  40, 20,  40,  50,  8,  4, 10,
          30,  5,  2,  4,  6,  6, 12,   4, 100, 100 ],
        [ 30, 10, 30, 50, 10, 30, 10, 200,  10, 100, 30, 150, 100, 10,  5, 20,
          50, 10,  5, 10, 20, 20, 50,  10, 200, 200 ]
    ];

    // Resource::Type res_needed[] (two entries per Serf::Type)
    global.inventory_res_needed = [
        ResourceType.none,    ResourceType.none,    // SERF_TRANSPORTER = 0,
        ResourceType.boat,    ResourceType.none,    // SERF_SAILOR,
        ResourceType.shovel,  ResourceType.none,    // SERF_DIGGER,
        ResourceType.hammer,  ResourceType.none,    // SERF_BUILDER,
        ResourceType.none,    ResourceType.none,    // SERF_TRANSPORTER_INVENTORY,
        ResourceType.axe,     ResourceType.none,    // SERF_LUMBERJACK,
        ResourceType.saw,     ResourceType.none,    // TypeSawmiller,
        ResourceType.pick,    ResourceType.none,    // TypeStonecutter,
        ResourceType.none,    ResourceType.none,    // TypeForester,
        ResourceType.pick,    ResourceType.none,    // TypeMiner,
        ResourceType.none,    ResourceType.none,    // TypeSmelter,
        ResourceType.rod,     ResourceType.none,    // TypeFisher,
        ResourceType.none,    ResourceType.none,    // TypePigFarmer,
        ResourceType.cleaver, ResourceType.none,    // TypeButcher,
        ResourceType.scythe,  ResourceType.none,    // TypeFarmer,
        ResourceType.none,    ResourceType.none,    // TypeMiller,
        ResourceType.none,    ResourceType.none,    // TypeBaker,
        ResourceType.hammer,  ResourceType.none,    // TypeBoatBuilder,
        ResourceType.hammer,  ResourceType.saw,     // TypeToolmaker,
        ResourceType.hammer,  ResourceType.pincer,  // TypeWeaponSmith,
        ResourceType.hammer,  ResourceType.none,    // TypeGeologist,
        ResourceType.none,    ResourceType.none,    // TypeGeneric,
        ResourceType.sword,   ResourceType.shield,  // TypeKnight0,
        ResourceType.none,    ResourceType.none,    // TypeKnight1,
        ResourceType.none,    ResourceType.none,    // TypeKnight2,
        ResourceType.none,    ResourceType.none,    // TypeKnight3,
        ResourceType.none,    ResourceType.none,    // TypeKnight4,
        ResourceType.none,    ResourceType.none     // TypeDead
    ];
}

function Inventory(_game, _index) : GameObject(_game, _index) constructor {
    inventory_init_tables();

    // ---- fields ----
    owner = 0;
    /* Index of flag connected to this inventory */
    flag = 0;
    /* Index of building containing this inventory */
    building = 0;
    /* Count of resources (ResourceMap -> array indexed by ResourceType) */
    resources = array_create(ResourceType.types_count, 0);
    /* Resources waiting to be moved out: array of 2 structs {type, dest} */
    out_queue = array_create(2, undefined);
    for (var _i = 0; _i < 2; _i++) {
        out_queue[_i] = { type: ResourceType.none, dest: 0 };
    }
    /* Count of serfs waiting to move out */
    serfs_out = 0;
    /* Count of generic serfs */
    generic_count = 0;
    res_dir = 0;
    /* Indices to serfs of each type (Serf::SerfMap -> array indexed by SerfType, includes dead) */
    serfs = array_create(28, 0);

    // ---- static methods ----

    /// Port of Inventory::~Inventory(). Must be called by Game before the
    /// inventory is erased from its collection.
    static destroy = function() {
        for (var _i = 0; _i < 2 && out_queue[_i].type != ResourceType.none; _i++) {
            var _res = out_queue[_i].type;
            var _dest = out_queue[_i].dest;

            game.cancel_transported_resource(_res, _dest);
            game.lose_resource(_res);
        }

        game.add_gold_total(-resources[ResourceType.gold_bar]);
        game.add_gold_total(-resources[ResourceType.gold_ore]);
    };

    static get_owner = function() {
        return owner;
    };
    static set_owner = function(_owner) {
        owner = _owner;
    };

    static get_flag_index = function() {
        return flag;
    };
    static set_flag_index = function(_flag_index) {
        flag = _flag_index;
    };

    static get_building_index = function() {
        return building;
    };
    static set_building_index = function(_building_index) {
        building = _building_index;
    };

    static get_res_mode = function() {
        return (res_dir & 3);
    };
    static set_res_mode = function(_mode) {
        res_dir = (res_dir & 0xFC) | _mode;
    };
    static get_serf_mode = function() {
        return ((res_dir >> 2) & 3);
    };
    static set_serf_mode = function(_mode) {
        res_dir = (res_dir & 0xF3) | (_mode << 2);
    };
    static have_any_out_mode = function() {
        return ((res_dir & 0x0A) != 0);
    };

    static get_serf_queue_length = function() {
        return serfs_out;
    };
    static serf_away = function() {
        serfs_out--;
    };
    static serf_come_back = function() {
        generic_count++;
    };
    static free_serf_count = function() {
        return generic_count;
    };
    static have_serf = function(_type) {
        return (serfs[_type] != 0);
    };

    static get_count_of = function(_resource) {
        return resources[_resource];
    };
    /// Returns the resources array itself (C++ returns a copy of the map).
    static get_all_resources = function() {
        return resources;
    };
    static pop_resource = function(_resource) {
        resources[_resource]--;
    };
    static push_resource = function(_resource) {
        /* resources[resource] += (resources[resource] < 50000) ? 1 : 0; */
        if (resources[_resource] < 50000) {
            resources[_resource] += 1;
        }
    };

    static has_resource_in_queue = function() {
        return (out_queue[0].type != ResourceType.none);
    };
    static is_queue_full = function() {
        return (out_queue[1].type != ResourceType.none);
    };

    /// C++: get_resource_from_queue(Resource::Type *res, int *dest).
    /// Returns a struct {res, dest}.
    static get_resource_from_queue = function() {
        var _result = { res: ResourceType.none, dest: 0 };
        _result.res = out_queue[0].type;
        _result.dest = out_queue[0].dest;

        out_queue[0].type = out_queue[1].type;
        out_queue[0].dest = out_queue[1].dest;

        out_queue[1].type = ResourceType.none;
        out_queue[1].dest = 0;

        return _result;
    };

    static reset_queue_for_dest = function(_flag) {
        if (out_queue[1].type != ResourceType.none &&
            out_queue[1].dest == _flag.get_index()) {
            push_resource(out_queue[1].type);
            out_queue[1].type = ResourceType.none;
        }
        if (out_queue[0].type != ResourceType.none &&
            out_queue[0].dest == _flag.get_index()) {
            push_resource(out_queue[0].type);
            out_queue[0].type = out_queue[1].type;
            out_queue[0].dest = out_queue[1].dest;
            out_queue[1].type = ResourceType.none;
        }
    };

    static has_food = function() {
        return (resources[ResourceType.fish] != 0 ||
                resources[ResourceType.meat] != 0 ||
                resources[ResourceType.bread] != 0);
    };

    /* Take resource from inventory and put in out queue.
       The resource must be present.*/
    static add_to_queue = function(_type, _dest) {
        if (_type == ResourceType.group_food) {
            /* Select the food resource with highest amount available */
            if (resources[ResourceType.meat] > resources[ResourceType.bread]) {
                if (resources[ResourceType.meat] > resources[ResourceType.fish]) {
                    _type = ResourceType.meat;
                } else {
                    _type = ResourceType.fish;
                }
            } else if (resources[ResourceType.bread] > resources[ResourceType.fish]) {
                _type = ResourceType.bread;
            } else {
                _type = ResourceType.fish;
            }
        }

        if (resources[_type] == 0) {
            throw ("No resource with type.");
        }

        resources[_type] -= 1;
        if (out_queue[0].type == ResourceType.none) {
            out_queue[0].type = _type;
            out_queue[0].dest = _dest;
        } else {
            out_queue[1].type = _type;
            out_queue[1].dest = _dest;
        }
    };

    /* Create initial resources */
    static apply_supplies_preset = function(_supplies) {
        var _template_1 = undefined;
        var _template_2 = undefined;
        if (_supplies < 10) {
            _template_1 = global.inventory_supplies_template[0];
            _template_2 = global.inventory_supplies_template[1];
        } else if (_supplies < 20) {
            _template_1 = global.inventory_supplies_template[1];
            _template_2 = global.inventory_supplies_template[2];
            _supplies -= 10;
        } else if (_supplies < 30) {
            _template_1 = global.inventory_supplies_template[2];
            _template_2 = global.inventory_supplies_template[3];
            _supplies -= 20;
        } else if (_supplies < 40) {
            _template_1 = global.inventory_supplies_template[3];
            _template_2 = global.inventory_supplies_template[4];
            _supplies -= 30;
        } else {
            _template_1 = global.inventory_supplies_template[4];
            _template_2 = global.inventory_supplies_template[4];
            _supplies -= 40;
        }

        for (var _i = 0; _i < 26; _i++) {
            var _t1 = _template_1[_i];
            var _n = ((_template_2[_i] - _template_1[_i]) * (_supplies * 6554)) & 0xFFFFFFFF;
            if (_n >= 0x8000) {
                _t1 += 1;
            }
            resources[_i] = _t1 + (_n >> 16);
        }
    };

    static call_transporter = function(_water) {
        var _serf = undefined;

        if (_water) {
            if (serfs[SerfType.sailor] != 0) {
                _serf = game.get_serf(serfs[SerfType.sailor]);
                serfs[SerfType.sailor] = 0;
            } else {
                if ((serfs[SerfType.generic] != 0) &&
                    (resources[ResourceType.boat] > 0)) {
                    _serf = game.get_serf(serfs[SerfType.generic]);
                    serfs[SerfType.generic] = 0;
                    resources[ResourceType.boat]--;
                    _serf.set_type(SerfType.sailor);
                    generic_count -= 1;
                } else {
                    return undefined;
                }
            }
        } else {
            if (serfs[SerfType.transporter] != 0) {
                _serf = game.get_serf(serfs[SerfType.transporter]);
                serfs[SerfType.transporter] = 0;
            } else {
                if (serfs[SerfType.generic] != 0) {
                    _serf = game.get_serf(serfs[SerfType.generic]);
                    serfs[SerfType.generic] = 0;
                    _serf.set_type(SerfType.transporter);
                    generic_count -= 1;
                } else {
                    return undefined;
                }
            }
        }

        serfs_out += 1;

        return _serf;
    };

    /// C++ overloads: call_out_serf(Serf *serf) -> bool and
    /// call_out_serf(Serf::Type type) -> Serf*. Dispatch on argument kind:
    /// pass a serf struct to get the bool form, a SerfType int to get the Serf form.
    static call_out_serf = function(_serf_or_type) {
        if (is_struct(_serf_or_type)) {
            var _serf = _serf_or_type;
            if (serfs[_serf.get_type()] != _serf.get_index()) {
                return false;
            }

            serfs[_serf.get_type()] = 0;
            if (_serf.get_type() == SerfType.generic) {
                generic_count--;
            }
            serfs_out++;
            return true;
        } else {
            var _type = _serf_or_type;
            if (serfs[_type] == 0) {
                return undefined;
            }

            var _serf = game.get_serf(serfs[_type]);
            if (!call_out_serf(_serf)) {
                return undefined;
            }

            return _serf;
        }
    };

    /// C++ overloads: call_internal(Serf *serf) -> bool and
    /// call_internal(Serf::Type type) -> Serf*. Dispatch on argument kind.
    static call_internal = function(_serf_or_type) {
        if (is_struct(_serf_or_type)) {
            var _serf = _serf_or_type;
            if (serfs[_serf.get_type()] != _serf.get_index()) {
                return false;
            }

            serfs[_serf.get_type()] = 0;

            return true;
        } else {
            var _type = _serf_or_type;
            if (serfs[_type] == 0) {
                return undefined;
            }

            var _serf = game.get_serf(serfs[_type]);
            serfs[_type] = 0;

            return _serf;
        }
    };

    static promote_serf_to_knight = function(_serf) {
        if (_serf.get_type() != SerfType.generic) {
            return false;
        }

        if (resources[ResourceType.sword] == 0 ||
            resources[ResourceType.shield] == 0) {
            return false;
        }

        pop_resource(ResourceType.sword);
        pop_resource(ResourceType.shield);
        generic_count--;
        serfs[SerfType.generic] = 0;

        _serf.set_type(SerfType.knight0);

        return true;
    };

    static spawn_serf_generic = function() {
        var _serf = game.get_player(owner).spawn_serf_generic();

        if (_serf != undefined) {
            _serf.init_generic(self);

            generic_count++;
            if (serfs[SerfType.generic] == 0) {
                serfs[SerfType.generic] = _serf.get_index();
            }
        }

        return _serf;
    };

    static specialize_serf = function(_serf, _type) {
        if (_serf.get_type() != SerfType.generic) {
            return false;
        }

        if (serfs[_type] != 0) {
            return false;
        }

        var _res_needed = global.inventory_res_needed;
        if ((_res_needed[_type * 2] != ResourceType.none)
            && (resources[_res_needed[_type * 2]] == 0)) {
            return false;
        }
        if ((_res_needed[_type * 2 + 1] != ResourceType.none)
            && (resources[_res_needed[_type * 2 + 1]] == 0)) {
            return false;
        }

        if (serfs[SerfType.generic] == _serf.get_index()) {
            serfs[SerfType.generic] = 0;
        }
        generic_count--;

        if (_res_needed[_type * 2] != ResourceType.none) {
            resources[_res_needed[_type * 2]]--;
        }
        if (_res_needed[_type * 2 + 1] != ResourceType.none) {
            resources[_res_needed[_type * 2 + 1]]--;
        }

        _serf.set_type(_type);

        serfs[_type] = _serf.get_index();

        return true;
    };

    static specialize_free_serf = function(_type) {
        if (serfs[SerfType.generic] == 0) {
            return undefined;
        }

        var _serf = game.get_serf(serfs[SerfType.generic]);

        if (!specialize_serf(_serf, _type)) {
            return undefined;
        }

        return _serf;
    };

    static serf_potential_count = function(_type) {
        var _count = generic_count;

        var _res_needed = global.inventory_res_needed;
        if (_res_needed[_type * 2] != ResourceType.none) {
            _count = min(_count, resources[_res_needed[_type * 2]]);
        }
        if (_res_needed[_type * 2 + 1] != ResourceType.none) {
            _count = min(_count, resources[_res_needed[_type * 2 + 1]]);
        }

        return _count;
    };

    static serf_idle_in_stock = function(_serf) {
        serfs[_serf.get_type()] = _serf.get_index();
    };

    static knight_training = function(_serf, _p) {
        var _old_type = _serf.get_type();
        var _r = _serf.train_knight(_p);
        if (_r == 0) {
            serfs[_old_type] = 0;
        }

        serf_idle_in_stock(_serf);
    };
}
