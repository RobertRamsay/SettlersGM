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

// 2: version 1 files were written with the map stored twice, and restoring the
// duplicate replaced the live Map with a plain copy. Those files cannot be
// repaired on read, so they are refused rather than half loaded.
// 3: versions 1 and 2 wrote null for anything produced by a bitwise operation
// (Player.flags, Map.height and friends), because is_real() is false for int64.
#macro SAVEGAME_VERSION 3

/// The flat per-tile arrays every Map carries. Checked after a load, because a
/// short or hole-y one of these shows up much later as an undefined terrain
/// type deep inside the minimap or the viewport.
#macro SAVEGAME_MAP_ARRAYS ["height", "type_up", "type_down", "mineral", \
                            "res_amount", "obj", "serf", "owner", "obj_index", \
                            "paths", "idle_serf"]
#macro SAVEGAME_SLOTS 10

/// Labels starting with this were generated rather than typed, so there is no
/// name worth carrying over when the slot is selected for overwriting.
#macro SAVEGAME_DEFAULT_PREFIX "Tick "

/// Fields that must never be followed: back references, GPU/GUI objects and
/// things rebuilt from scratch on load.
#macro SAVEGAME_SKIP ["game", "interface", "ctor", "handlers", "geom", "parent", "floats"]

/// Collections on Game, in the order they are rebuilt.
#macro SAVEGAME_COLLECTIONS ["players", "flags", "inventories", "buildings", "serfs"]

/// Fields of Game written separately rather than inline.
#macro SAVEGAME_GAME_SKIP ["players", "flags", "inventories", "buildings", "serfs", "map"]

/// Why the last load failed, for the UI to display. "" means it succeeded.
function savegame_fail(_reason) {
    global.savegame_last_error = _reason;
    show_debug_message("savegame: " + _reason);
    return undefined;
}

function savegame_last_error() {
    if (!variable_global_exists("savegame_last_error")) {
        return "";
    }
    return global.savegame_last_error;
}

function savegame_init_tables() {
    if (variable_global_exists("savegame_ref_kinds")) {
        return;
    }
    global.savegame_last_error = "";
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
    // GML's bitwise operators yield int64, and is_real() is false for those.
    // Player.flags is built with |= and &=, Map.height comes from the generator
    // the same way - both were falling past every branch below and being
    // written as null. real() normalises them.
    if (is_real(_value) || is_bool(_value) || is_int32(_value) || is_int64(_value)) {
        return real(_value);
    }
    if (is_string(_value)) {
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

        var _encoded = savegame_encode_value(_value, _depth + 1);
        if (is_undefined(_encoded) && !is_undefined(_value)) {
            show_debug_message("savegame: cannot encode field '" + _name +
                               "' of type " + typeof(_value) + " - saved as null");
        }
        _out[$ _name] = _encoded;
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
        game: savegame_encode_struct(_game, 0, SAVEGAME_GAME_SKIP),
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

/// Rebuild a value. `_current` is whatever the freshly constructed object
/// already holds there: when it is a struct we fill it in place rather than
/// substituting a plain copy, so members built by a constructor (RandomState,
/// MapUpdateState, the Map itself) keep their type and therefore their statics.
function savegame_decode_value(_value, _current, _game, _depth) {
    if (_depth > 32) {
        return undefined;
    }
    if (is_undefined(_value) || is_real(_value) || is_bool(_value) || is_string(_value)) {
        return _value;
    }

    if (is_array(_value)) {
        var _n = array_length(_value);
        var _out = array_create(_n, undefined);
        var _current_is_array = is_array(_current);
        for (var _i = 0; _i < _n; _i++) {
            var _element = undefined;
            if (_current_is_array && _i < array_length(_current)) {
                _element = _current[_i];
            }
            _out[_i] = savegame_decode_value(_value[_i], _element, _game, _depth + 1);
        }
        return _out;
    }

    if (is_struct(_value)) {
        if (savegame_is_ref(_value)) {
            var _collection = variable_struct_get(_game, _value.__r);
            return _collection.get(_value.i);
        }
        if (is_struct(_current)) {
            savegame_apply_struct(_current, _value, _game);
            return _current;
        }
        var _out_struct = {};
        var _names = variable_struct_get_names(_value);
        var _m = array_length(_names);
        for (var _j = 0; _j < _m; _j++) {
            _out_struct[$ _names[_j]] = savegame_decode_value(
                variable_struct_get(_value, _names[_j]), undefined, _game, _depth + 1);
        }
        return _out_struct;
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
        var _current = undefined;
        if (variable_struct_exists(_target, _name)) {
            _current = variable_struct_get(_target, _name);
        }

        var _decoded = savegame_decode_value(variable_struct_get(_source, _name),
                                             _current, _game, 0);

        // A null in the file would otherwise wipe out a field the constructor
        // had already given a sane default, turning a missing number into a
        // crash the next time anything reads it.
        if (is_undefined(_decoded) && !is_undefined(_current)) {
            show_debug_message("savegame: '" + _name +
                               "' is null in the file, keeping " + string(_current));
            continue;
        }

        variable_struct_set(_target, _name, _decoded);
    }
}

function savegame_decode_game(_data) {
    savegame_init_tables();

    if (!is_struct(_data) || !variable_struct_exists(_data, "version")) {
        return savegame_fail("file has no version field");
    }
    if (_data.version != SAVEGAME_VERSION) {
        return savegame_fail("save is version " + string(_data.version) + ", need " +
                             string(SAVEGAME_VERSION) + " - please save again");
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

    if (!savegame_check_map(_game, _data)) {
        return undefined;
    }

    return _game;
}

/// Every per-tile array must be present and the right length. Reporting here
/// turns a crash somewhere far away into one line naming the field.
/// Print what an array looks like as saved and as applied, so a bad entry can
/// be pinned on the encoder or the decoder rather than guessed at.
function savegame_report_array(_name, _applied, _data) {
    show_debug_message("  applied: length " + string(array_length(_applied)));

    var _shown = "";
    var _limit = min(8, array_length(_applied));
    for (var _i = 0; _i < _limit; _i++) {
        _shown += string(_applied[_i]) + " ";
    }
    show_debug_message("  applied first " + string(_limit) + ": " + _shown);

    var _saved = undefined;
    if (is_struct(_data) && variable_struct_exists(_data, "map")) {
        if (variable_struct_exists(_data.map, _name)) {
            _saved = variable_struct_get(_data.map, _name);
        }
    }

    if (!is_array(_saved)) {
        show_debug_message("  saved: not an array (" + string(_saved) + ")");
        return;
    }

    var _undefined_count = 0;
    var _n = array_length(_saved);
    for (var _j = 0; _j < _n; _j++) {
        if (is_undefined(_saved[_j])) {
            _undefined_count += 1;
        }
    }

    var _saved_shown = "";
    var _saved_limit = min(8, _n);
    for (var _k = 0; _k < _saved_limit; _k++) {
        _saved_shown += string(_saved[_k]) + " ";
    }

    show_debug_message("  saved: length " + string(_n) + ", " +
                       string(_undefined_count) + " undefined");
    show_debug_message("  saved first " + string(_saved_limit) + ": " + _saved_shown);
}

function savegame_check_map(_game, _data) {
    var _map = _game.map;
    if (_map == undefined || !is_struct(_map) || !variable_struct_exists(_map, "geom")) {
        savegame_fail("loaded game has no map geometry");
        return false;
    }

    var _expected = _map.geom.tile_count;
    var _n = array_length(SAVEGAME_MAP_ARRAYS);

    for (var _i = 0; _i < _n; _i++) {
        var _name = SAVEGAME_MAP_ARRAYS[_i];

        if (!variable_struct_exists(_map, _name)) {
            savegame_fail("map." + _name + " is missing");
            return false;
        }

        var _array = variable_struct_get(_map, _name);
        if (!is_array(_array)) {
            savegame_fail("map." + _name + " is not an array");
            return false;
        }

        // idle_serf is the only non-numeric one.
        var _default = 0;
        if (_name == "idle_serf") {
            _default = false;
        }

        if (array_length(_array) == 0) {
            savegame_fail("map." + _name + " is empty, expected " + string(_expected));
            savegame_report_array(_name, _array, _data);
            return false;
        }

        if (array_length(_array) != _expected) {
            show_debug_message("savegame: map." + _name + " had " +
                               string(array_length(_array)) + " entries, padding to " +
                               string(_expected));
            savegame_report_array(_name, _array, _data);
            array_resize(_array, _expected);
        }

        var _repaired = 0;
        for (var _j = 0; _j < _expected; _j++) {
            if (is_undefined(_array[_j])) {
                _array[_j] = _default;
                _repaired += 1;
            }
        }

        if (_repaired > 0) {
            show_debug_message("savegame: map." + _name + " filled " + string(_repaired) +
                               " of " + string(_expected) + " missing entries with " +
                               string(_default));
            savegame_report_array(_name, _array, _data);
        }

        variable_struct_set(_map, _name, _array);
    }

    return true;
}

// ---------------------------------------------------------------- files

function savegame_slot_path(_slot) {
    return "settlers_save_" + string(_slot) + ".json";
}

/// Write a snapshot to an arbitrary path. Returns true on success.
/// Is this one of the numbered slot files, rather than a name the player typed?
/// Used to tell a deliberate "save it as this" from the F5 quicksave.
function savegame_is_slot_path(_path) {
    var _name = filename_name(_path);
    for (var _i = 0; _i < SAVEGAME_SLOTS; _i++) {
        if (_name == filename_name(savegame_slot_path(_i))) {
            return true;
        }
    }
    return false;
}

function savegame_save_path(_path, _game, _label = "") {
    if (_game == undefined) {
        show_debug_message("savegame: no game to save");
        return false;
    }

    /* "borntodie": the save NAME is the switch, and it works both ways. A save
       called borntodie arms the cheat; saving under any other name turns it off
       again and hands the game back to ordinary knights.

       Only a name the player actually CHOSE counts. Both deliberate routes are
       covered - the label typed into the save popup's slot row, and the file
       name typed into its name field - but the F5 quicksave supplies neither: it
       writes a numbered slot under a generated "Tick 1234 ..." label. Nobody
       named that, so a quicksave leaves the cheat exactly as it is rather than
       silently disarming it mid-assault.

       This runs BEFORE the snapshot is taken, on purpose. Standing the lads down
       changes serf state, and a save written from a snapshot taken beforehand
       would come back with cf_active off but soldiers still flagged mid-siege. */
    var _typed_name = _label;
    if (_typed_name == "" && !savegame_is_slot_path(_path)) {
        _typed_name = filename_name(_path);
    }
    if (_typed_name != "") {
        var _armed = cf_name_is_cheat(_typed_name);
        if (!_armed && cf_is_active()) {
            cf_stand_down(_game);
        }
        cf_set_active(_armed);
    }

    var _data = savegame_encode_game(_game);
    if (_label == "") {
        _data.label = SAVEGAME_DEFAULT_PREFIX + string(_game.tick) + "  " +
                      date_datetime_string(date_current_datetime());
    } else {
        _data.label = _label;
    }
    _data.cf_active = cf_is_active();

    var _text = json_stringify(_data);
    var _buffer = buffer_create(string_byte_length(_text) + 1, buffer_grow, 1);
    buffer_write(_buffer, buffer_text, _text);
    buffer_save(_buffer, _path);
    buffer_delete(_buffer);

    // Sidecar so the slot list can show a label without parsing the whole
    // snapshot: the save popup redraws every frame, and ten json_parse calls
    // over a few hundred KB each would make it unusable.
    var _label_buffer = buffer_create(string_byte_length(_data.label) + 1, buffer_grow, 1);
    buffer_write(_label_buffer, buffer_text, _data.label);
    buffer_save(_label_buffer, _path + ".label");
    buffer_delete(_label_buffer);

    show_debug_message("savegame: wrote " + string(_path) + " (" +
                       string(string_length(_text)) + " chars)");
    return true;
}

/// Read a snapshot back. Returns a Game, or undefined.
function savegame_load_path(_path) {
    savegame_init_tables();
    global.savegame_last_error = "";

    if (!file_exists(_path)) {
        return savegame_fail("no file at " + string(_path));
    }

    var _buffer = buffer_load(_path);
    if (_buffer < 0) {
        return savegame_fail("could not open " + string(_path));
    }
    var _text = buffer_read(_buffer, buffer_text);
    buffer_delete(_buffer);

    var _data = undefined;
    try {
        _data = json_parse(_text);
    } catch (_e) {
        return savegame_fail("file is not valid JSON");
    }

    /* "borntodie": a save comes back exactly as it was written - on if the cheat
       was on when it was saved, off if it was not. variable_struct_get returns
       undefined for a key an older save does not have; those predate the flag,
       so fall back to reading the name the same way saving does.

       Effects in flight belong to the game being replaced, and their map
       positions mean nothing in the one coming in. */
    var _cf_flag = variable_struct_get(_data, "cf_active");
    if (_cf_flag != undefined) {
        cf_set_active(_cf_flag == true);
    } else {
        cf_set_active(cf_name_is_cheat(variable_struct_get(_data, "label")) ||
                      cf_name_is_cheat(filename_name(_path)));
    }
    global.cf_fx = [];
    global.cf_fx_count = 0;

    return savegame_decode_game(_data);
}

function savegame_slot_exists(_slot) {
    return file_exists(savegame_slot_path(_slot));
}

/// The typed name for a slot, or "" when the label was generated. Used to keep
/// a name on screen when an existing save is selected, so pressing SAVE writes
/// over it under the same name instead of a blank one.
function savegame_slot_name(_slot) {
    var _label = savegame_slot_label(_slot);
    var _prefix_length = string_length(SAVEGAME_DEFAULT_PREFIX);

    if (string_copy(_label, 1, _prefix_length) == SAVEGAME_DEFAULT_PREFIX) {
        return "";
    }
    if (string_char_at(_label, 1) == "-") {
        return "";   // "- empty -" and friends
    }

    return _label;
}

/// Short label for a slot, read from the sidecar written alongside the save.
/// Cheap enough to call from a draw handler.
function savegame_slot_label(_slot) {
    if (!savegame_slot_exists(_slot)) {
        return "- empty -";
    }

    var _label_path = savegame_slot_path(_slot) + ".label";
    if (!file_exists(_label_path)) {
        return "saved game";
    }

    var _buffer = buffer_load(_label_path);
    if (_buffer < 0) {
        return "saved game";
    }
    var _text = buffer_read(_buffer, buffer_text);
    buffer_delete(_buffer);

    return _text;
}

function savegame_save_slot(_slot, _game, _label = "") {
    return savegame_save_path(savegame_slot_path(_slot), _game, _label);
}

function savegame_load_slot(_slot) {
    return savegame_load_path(savegame_slot_path(_slot));
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

// ---------------------------------------------------------- mission progress
// Not in Freeserf, which never recorded what you had finished. Which missions
// have been won is kept in an ini beside the save slots, so the start screen can
// mark them off and you can see where you got to.
//
// Deliberately its own file rather than part of a save: progress belongs to the
// player, not to one game, and it has to survive starting a new mission.
//
// An ini rather than JSON in a buffer. GameMaker's ini_* functions read and
// write the sandboxed save area as one operation, with no separate load step to
// get wrong, and ini_close() is what commits the file - so a write cannot end up
// somewhere the next read does not look. The section is named so other settings
// can move in later without disturbing this one.

#macro PROGRESS_PATH    "settlers.ini"
#macro PROGRESS_SECTION "missions"

/// The lower bound on how many flags to keep, whatever the mission table says.
/// If the table were ever empty or not yet built when progress is first asked
/// about, an array sized from it would be empty AND CACHED THAT WAY - after
/// which every mission reads as not done and every attempt to record one is
/// dropped, silently and permanently. This makes that unreachable.
#macro PROGRESS_MIN_SLOTS 64

function progress_key(_index) {
    return "mission_" + string(_index);
}

/// Which mission is in play, recorded by GameInitBox the moment it starts one
/// and -1 for anything that is not a numbered mission. Game.mission_index is
/// still the primary record - it serialises, so a mission resumed from a save
/// knows what it is - but this does not travel through the Game at all, so
/// nothing that copies, resets or re-creates the Game can lose it.
function progress_set_current_mission(_index) {
    global.current_mission_index = _index;
    show_debug_message("progress: current mission index is now " + string(_index));
}

function progress_get_current_mission() {
    if (!variable_global_exists("current_mission_index")) {
        return -1;
    }
    return global.current_mission_index;
}

/// The index a finished game should tick off: what the Game says if it knows,
/// otherwise what the start screen last launched.
function progress_index_for_game(_game) {
    if (_game != undefined && _game.mission_index >= 0) {
        return _game.mission_index;
    }
    return progress_get_current_mission();
}

/// Everything this knows, to the output log. Bound to F12 alongside the save
/// slot dump, so the state can be read off in one key rather than inferred.
function progress_dump(_game) {
    progress_load();
    show_debug_message("--- mission progress ---");
    show_debug_message("  file: " + game_save_id + PROGRESS_PATH +
                       "  exists=" + string(file_exists(PROGRESS_PATH)));
    show_debug_message("  start screen last launched index: " +
                       string(progress_get_current_mission()));
    if (_game == undefined) {
        show_debug_message("  no game running");
    } else {
        show_debug_message("  this game: mission_index=" + string(_game.mission_index) +
                           " game_over=" + string(_game.game_over) +
                           " game_over_shown=" + string(_game.game_over_shown));
        show_debug_message("  would tick index: " + string(progress_index_for_game(_game)));
    }
    var _list = "";
    for (var _i = 0; _i < array_length(global.progress_done); _i++) {
        if (global.progress_done[_i]) {
            _list += string(_i + 1) + " ";
        }
    }
    if (_list == "") {
        _list = "(none)";
    }
    show_debug_message("  missions recorded complete: " + _list);
}

/// Read the ini into memory once. The start screen asks about the selected
/// mission on every frame it draws, so this must not touch the disk each time.
function progress_load() {
    if (variable_global_exists("progress_done")) {
        return;
    }

    var _count = game_info_get_mission_count();
    if (_count < PROGRESS_MIN_SLOTS) {
        _count = PROGRESS_MIN_SLOTS;
    }
    global.progress_done = array_create(_count, false);

    ini_open(PROGRESS_PATH);
    var _found = 0;
    for (var _i = 0; _i < _count; _i++) {
        if (ini_read_real(PROGRESS_SECTION, progress_key(_i), 0) != 0) {
            global.progress_done[_i] = true;
            _found++;
        }
    }
    ini_close();

    show_debug_message("progress: " + string(_found) + " mission(s) recorded as " +
                       "complete, from " + game_save_id + PROGRESS_PATH);
}

/// Has this mission been won? Index is 0-based, as game_mission is.
function progress_mission_is_done(_index) {
    progress_load();
    if (_index < 0 || _index >= array_length(global.progress_done)) {
        return false;
    }
    return global.progress_done[_index];
}

/// Record a win and commit it at once. Writing immediately rather than at
/// shutdown is the point: the game can be closed from the window's X, and a
/// mission won but not recorded is exactly the thing a player would notice.
/// Safe to call more than once for the same mission - the callers deliberately
/// do, so that every path to a victory records it.
function progress_mark_mission_done(_index) {
    if (_index < 0) {
        show_debug_message("progress: asked to record mission index " + string(_index) +
                           ", which is not a mission - nothing written");
        return;
    }

    progress_load();

    /* Writing past the end of a GML array extends it, so an index beyond what
       the mission table admitted to is still stored rather than dropped. */
    global.progress_done[_index] = true;

    ini_open(PROGRESS_PATH);
    ini_write_real(PROGRESS_SECTION, progress_key(_index), 1);
    ini_close();   /* ini_close is what actually writes the file out */

    /* Read it straight back. This separates the two ways the mark can fail -
       never called, or called and not persisted - which from the start screen
       look identical, and which is what made this hard to pin down. */
    ini_open(PROGRESS_PATH);
    var _check = ini_read_real(PROGRESS_SECTION, progress_key(_index), 0);
    ini_close();

    var _note = "";
    if (_check == 0) {
        _note = "  *** WRITE DID NOT STICK ***";
    }
    show_debug_message("progress: mission " + string(_index + 1) +
                       " marked complete in " + game_save_id + PROGRESS_PATH +
                       " - read back as " + string(_check) + _note);
}
