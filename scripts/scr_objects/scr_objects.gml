// scr_objects.gml - Ported from Freeserf src/objects.h and src/resource.h (GPL-3.0),
// original copyright (C) 2015-2017 Wicked_Digger, Jon Lund Steffensen.
// GameObject base, the Collection container and the resource type enum.

enum ResourceType {
    none = -1,
    fish = 0,
    pig,
    meat,
    wheat,
    flour,
    bread,
    lumber,
    plank,
    boat,
    stone,
    iron_ore,
    steel,
    coal,
    gold_ore,
    gold_bar,
    shovel,
    hammer,
    rod,
    cleaver,
    scythe,
    axe,
    saw,
    pick,
    pincer,
    sword,
    shield,
    group_food,
    types_count
}

function GameObject(_game, _index) constructor {
    game = _game;
    index = _index;

    static get_game = function() {
        return game;
    };
    static get_index = function() {
        return index;
    };
}

/// Collection of game objects addressed by index (port of Collection<T, growth>).
/// _ctor is the constructor function, called as new _ctor(game, index).
function Collection(_game, _ctor) constructor {
    game = _game;
    ctor = _ctor;
    objects = [];
    free_object_indexes = [];
    last_object_index = 0;

    static clear = function() {
        objects = [];
        free_object_indexes = [];
    };

    static allocate = function() {
        var _new_index = 0;
        var _new_object = undefined;
        if (array_length(free_object_indexes) > 0) {
            _new_index = free_object_indexes[0];
            array_delete(free_object_indexes, 0, 1);
            _new_object = new ctor(game, _new_index);
            objects[_new_index] = _new_object;
        } else {
            _new_index = array_length(objects);
            _new_object = new ctor(game, _new_index);
            array_push(objects, _new_object);
        }
        return _new_object;
    };

    static exists = function(_index) {
        if (_index < 0 || _index >= array_length(objects)) {
            return false;
        }
        return (objects[_index] != undefined);
    };

    /// C++ operator[]: returns undefined when the index is out of range or free.
    static get = function(_index) {
        if (_index < 0 || _index >= array_length(objects)) {
            return undefined;
        }
        return objects[_index];
    };

    static get_or_insert = function(_index) {
        var _object = undefined;
        if (_index < array_length(objects)) {
            _object = objects[_index];
            if (_object == undefined) {
                var _n = array_length(free_object_indexes);
                for (var _i = 0; _i < _n; _i++) {
                    if (free_object_indexes[_i] == _index) {
                        array_delete(free_object_indexes, _i, 1);
                        break;
                    }
                }
                _object = new ctor(game, _index);
                objects[_index] = _object;
            }
        } else {
            for (var _i = array_length(objects); _i < _index; _i++) {
                array_push(free_object_indexes, _i);
                array_push(objects, undefined);
            }
            _object = new ctor(game, _index);
            array_push(objects, _object);
        }
        return _object;
    };

    static erase = function(_index) {
        if (_index < array_length(objects) && objects[_index] != undefined) {
            if (_index + 1 == array_length(objects)) {
                array_pop(objects);
            } else {
                array_push(free_object_indexes, _index);
                objects[_index] = undefined;
            }
        }
    };

    /// Number of slots (C++ size()), including free ones.
    static size = function() {
        return array_length(objects);
    };

    /// Convenience: array of live objects (allocates; use the index loop in hot code).
    static to_array = function() {
        var _out = [];
        var _n = array_length(objects);
        for (var _i = 0; _i < _n; _i++) {
            if (objects[_i] != undefined) {
                array_push(_out, objects[_i]);
            }
        }
        return _out;
    };
}
