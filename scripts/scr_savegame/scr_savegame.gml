/// scr_savegame — snapshot the whole Game struct to disk and read it back.
///
/// Freeserf's savegame.cc is a hand written section-per-class text format. This
/// is a reflective serialiser instead: it walks the Game struct with
/// variable_struct_get_names and writes whatever it finds, so new fields are
/// picked up without touching this file.
///
/// The one thing reflection cannot handle on its own is object identity.
/// Flag.other_endpoint holds live Flag and Building structs (mirroring the C++
/// union), so a plain dump would either recurse forever or lose the sharing.
/// Anything that lives in one of Game's Collections is therefore written as
/// {__r: kind, i: index} and relinked in a second pass once every object exists.

#macro SAVEGAME_VERSION 1
#macro SAVEGAME_SLOTS 10

/// Fields that must never be followed: back references, GPU/GUI objects and
/// things rebuilt from scratch on load.
#macro SAVEGAME_SKIP ["game", "interface", "ctor", "handlers", "geom", "parent", "floats"]

/// Collections on Game, in the order they are rebuilt.
#macro SAVEGAME_COLLECTIONS ["players", "flags", "inventories", "buildings", "serfs"]

function savegame_init_tables() {
    if (variable_global_exists("savegame_ref_kinds")) {
        return;
    }
    // instanceof() name -> the Game collection it belongs to.
    global.savegame_ref_kinds = {
        Player: "players",
        Flag: "flags",
        Inventory: "inventories",
        Building: "buildings",
        Serf: "serfs",
    };
    global.savegame_skip = SAVEGAME_SKIP;
}

/// Which collection does this struct live in? undefined for plain structs.
function savegame_ref_kind(_value) {
    savegame_init_tables();
    var _name = instanceof(_value);
    if (_name == undefined) {
        return undefined;
    }
    if (!variable_struct_exists(global.savegame_ref_kinds, _name)) {
        return undefined;
    }
    return global.savegame_ref_kinds[$ _name];
}

function savegame_is_skipped(_name) {
    savegame_init_tables();
    var _n = array_length(global.savegame_skip);
    for (var _i = 0; _i < _n; _i++) {
        if (global.savegame_skip[_i] == _name) {
            return true;
        }
    }
    return false;
}

// ---------------------------------------------------------------- encoding

function savegame_encode_value(_value, _depth) {
    if (_depth > 32) {
        return undefined;
    }
    if (is_undefined(_value) || is_method(_value)) {
        return undefined;
    }
    if (is_real(_value) || is_bool(_value) || is_string(_value)) {
        return _value;
    }
    if (is_array(_value)) {
        var _n = array_length(_value);
        var _out = array_create(_n, undefined);
        for (var _i = 0; _i < _n; _i++) {
            _out[_i] = savegame_encode_value(_value[_i], _depth + 1);
        }
        return _out;
    }
    if (is_struct(_value)) {
        var _kind = savegame_ref_kind(_value);
        if (_kind != undefined) {
            return { __r: _kind, i: _value.index };
        }
        return savegame_encode_struct(_value, _depth + 1, []);
    }
    return undefined;
}

/// _extra_skip lets a caller drop fields it is writing separately.
function savegame_encode_struct(_source, _depth, _extra_skip) {
    var _out = {};
    var _names = variable_struct_get_names(_source);
    var _n = array_length(_names);

    for (var _i = 0; _i < _n; _i++) {
        var _name = _names[_i];
        if (savegame_is_skipped(_name)) {
            continue;
        }

        var _skip_this = false;
        var _m = array_length(_extra_skip);
        for (var _j = 0; _j < _m; _j++) {
            if (_extra_skip[_j] == _name) {
                _skip_this = true;
            }
        }
        if (_skip_this) {
            continue;
        }

        var _value = variable_struct_get(_source, _name);
        if (is_method(_value)) {
            continue;
        }
        _out[$ _name] = savegame_encode_value(_value, _depth + 1);
    }

    return _out;
}

/// Collection members are written in full here; everywhere else they are refs.
function savegame_encode_collection(_collection) {
    var _objects = [];
    var _n = array_length(_collection.objects);

    for (var _i = 0; _i < _n; _i++) {
        var _object = _collection.objects[_i];
        if (_object == undefined) {
            _objects[_i] = undefined;
        } else {
            _objects[_i] = savegame_encode_struct(_object, 0, []);
        }
    }

    return {
        last_object_index: _collection.last_object_index,
        free_object_indexes: savegame_encode_value(_collection.free_object_indexes, 0),
        objects: _objects,
    };
}

function savegame_encode_game(_game) {
    var _map = _game.get_map();

    var _data = {
        version: SAVEGAME_VERSION,
        map_size: _map.geom.size,
        map: savegame_encode_struct(_map, 0, []),
        game: savegame_encode_struct(_game, 0, SAVEGAME_COLLECTIONS),
        collections: {},
    };

    var _n = array_length(SAVEGAME_COLLECTIONS);
    for (var _i = 0; _i < _n; _i++) {
        var _name = SAVEGAME_COLLECTIONS[_i];
        _data.collections[$ _name] = savegame_encode_collection(
            variable_struct_get(_game, _name));
    }

    return _data;
}

// ---------------------------------------------------------------- decoding

function savegame_is_ref(_value) {
    if (!is_struct(_value)) {
        return false;
    }
    return variable_struct_exists(_value, "__r") && variable_struct_exists(_value, "i");
}

/// Rebuild a value, turning {__r,i} markers back into the live objects.
function savegame_decode_value(_value, _game, _depth) {
    if (_depth > 32) {
        return undefined;
    }
    if (is_undefined(_value) || is_real(_value) || is_bool(_value) || is_string(_value)) {
        return _value;
    }
    if (is_array(_value)) {
        var _n = array_length(_value);
        var _out = array_create(_n, undefined);
        for (var _i = 0; _i < _n; _i++) {
            _out[_i] = savegame_decode_value(_value[_i], _game, _depth + 1);
        }
        return _out;
    }
    if (is_struct(_value)) {
        if (savegame_is_ref(_value)) {
            var _collection = variable_struct_get(_game, _value.__r);
            return _collection.get(_value.i);
        }
        var _out = {};
        var _names = variable_struct_get_names(_value);
        var _m = array_length(_names);
        for (var _j = 0; _j < _m; _j++) {
            _out[$ _names[_j]] = savegame_decode_value(
                variable_struct_get(_value, _names[_j]), _game, _depth + 1);
        }
        return _out;
    }
    return undefined;
}

/// Copy decoded fields onto a live struct, leaving its statics alone.
function savegame_apply_struct(_target, _source, _game) {
    var _names = variable_struct_get_names(_source);
    var _n = array_length(_names);
    for (var _i = 0; _i < _n; _i++) {
        var _name = _names[_i];
        if (savegame_is_skipped(_name)) {
            continue;
        }
        variable_struct_set(_target, _name,
                            savegame_decode_value(variable_struct_get(_source, _name),
                                                  _game, 0));
    }
}

function savegame_decode_game(_data) {
    if (!is_struct(_data) || !variable_struct_exists(_data, "version")) {
        return undefined;
    }
    if (_data.version != SAVEGAME_VERSION) {
        show_debug_message("savegame: version " + string(_data.version) +
                           ", expected " + string(SAVEGAME_VERSION));
        return undefined;
    }

    var _game = new Game();
    _game.map = new Map(new MapGeometry(_data.map_size));

    // Pass one: every collection slot must exist before anything is linked,
    // because objects reference each other in both directions.
    var _cn = array_length(SAVEGAME_COLLECTIONS);
    for (var _c = 0; _c < _cn; _c++) {
        var _name = SAVEGAME_COLLECTIONS[_c];
        var _saved = _data.collections[$ _name];
        var _collection = variable_struct_get(_game, _name);
        _collection.clear();
        var _n = array_length(_saved.objects);
        for (var _i = 0; _i < _n; _i++) {
            if (_saved.objects[_i] != undefined) {
                _collection.get_or_insert(_i);
            }
        }
        _collection.last_object_index = _saved.last_object_index;
        _collection.free_object_indexes = _saved.free_object_indexes;
    }

    // Pass two: fill in the fields, resolving refs against the objects above.
    for (var _c = 0; _c < _cn; _c++) {
        var _name = SAVEGAME_COLLECTIONS[_c];
        var _saved = _data.collections[$ _name];
        var _collection = variable_struct_get(_game, _name);
        var _n = array_length(_saved.objects);
        for (var _i = 0; _i < _n; _i++) {
            if (_saved.objects[_i] != undefined) {
                savegame_apply_struct(_collection.get(_i), _saved.objects[_i], _game);
            }
        }
    }

    savegame_apply_struct(_game.map, _data.map, _game);
    savegame_apply_struct(_game, _data.game, _game);

    return _game;
}

// ---------------------------------------------------------------- files

function savegame_slot_path(_slot) {
    return "settlers_save_" + string(_slot) + ".json";
}

function savegame_slot_exists(_slot) {
    return file_exists(savegame_slot_path(_slot));
}

/// Short label for a slot, for the save/load list.
function savegame_slot_label(_slot) {
    if (!savegame_slot_exists(_slot)) {
        return "- empty -";
    }
    var _buffer = buffer_load(savegame_slot_path(_slot));
    if (_buffer < 0) {
        return "- unreadable -";
    }
    var _text = buffer_read(_buffer, buffer_text);
    buffer_delete(_buffer);

    try {
        var _data = json_parse(_text);
        return string(_data.label);
    } catch (_e) {
        return "- damaged -";
    }
}

function savegame_save_slot(_slot, _game) {
    var _data = savegame_encode_game(_game);
    _data.label = "Tick " + string(_game.tick) + "  " + date_datetime_string(date_current_datetime());

    var _text = json_stringify(_data);
    var _buffer = buffer_create(string_byte_length(_text) + 1, buffer_grow, 1);
    buffer_write(_buffer, buffer_text, _text);
    buffer_save(_buffer, savegame_slot_path(_slot));
    buffer_delete(_buffer);

    show_debug_message("savegame: wrote slot " + string(_slot) + " (" +
                       string(string_length(_text)) + " chars)");
    return true;
}

function savegame_load_slot(_slot) {
    if (!savegame_slot_exists(_slot)) {
        return undefined;
    }

    var _buffer = buffer_load(savegame_slot_path(_slot));
    if (_buffer < 0) {
        return undefined;
    }
    var _text = buffer_read(_buffer, buffer_text);
    buffer_delete(_buffer);

    var _data = undefined;
    try {
        _data = json_parse(_text);
    } catch (_e) {
        show_debug_message("savegame: slot " + string(_slot) + " is not valid JSON");
        return undefined;
    }

    return savegame_decode_game(_data);
}

// ---------------------------------------------------------------- self test

/// Encode, decode, re-encode and compare. Catches fields that do not survive
/// the round trip without needing a save file or a restart.
function savegame_self_test(_game) {
    var _first = json_stringify(savegame_encode_game(_game));

    var _copy = savegame_decode_game(json_parse(_first));
    if (_copy == undefined) {
        show_debug_message("savegame self test: decode returned nothing");
        return false;
    }

    var _second = json_stringify(savegame_encode_game(_copy));
    if (_first == _second) {
        show_debug_message("savegame self test: PASSED (" +
                           string(string_length(_first)) + " chars)");
        return true;
    }

    show_debug_message("savegame self test: FAILED, lengths " +
                       string(string_length(_first)) + " vs " +
                       string(string_length(_second)));

    var _limit = min(string_length(_first), string_length(_second));
    for (var _i = 1; _i <= _limit; _i++) {
        if (string_char_at(_first, _i) != string_char_at(_second, _i)) {
            var _from = max(1, _i - 120);
            show_debug_message("  first difference at char " + string(_i));
            show_debug_message("  before: ..." + string_copy(_first, _from, 240));
            show_debug_message("  after:  ..." + string_copy(_second, _from, 240));
            break;
        }
    }

    return false;
}
