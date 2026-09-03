// scr_mission.gml - Ported from Freeserf src/mission.h and src/mission.cc
// (GPL-3.0), original copyright (C) 2013-2017 Jon Lund Steffensen
// <jonlst@gmail.com>. Predefined game mission maps, PlayerInfo and GameInfo.
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tables (mission.cc lines 25-378) live in global.mission_characters,
// global.mission_def_color, global.mission_tutorials and global.mission_missions.
// Mission entries are structs {name, random_base (16-char string),
// players: [{face, intelligence, supplies, reproduction, castle:{col,row}}]}.

/// Helper for the mission tables: Preset {character, intelligence, supplies,
/// reproduction, castle} where `character` is an index into characters[].
function mission_preset(_character, _intelligence, _supplies, _reproduction, _col, _row) {
    return {
        face: global.mission_characters[_character].face,
        intelligence: _intelligence,
        supplies: _supplies,
        reproduction: _reproduction,
        castle: { col: _col, row: _row }
    };
}

function mission_init_tables() {
    if (variable_global_exists("mission_characters")) {
        return;
    }

    // Character characters[]
    global.mission_characters = [
        { face: 0, name: "ERROR", characterization: "ERROR" },
        { face: 1, name: "Lady Amalie",
          characterization: "An inoffensive lady, reserved, who goes about her work peacefully." },
        { face: 2, name: "Kumpy Onefinger",
          characterization: "A very hostile character, who loves gold above all else." },
        { face: 3, name: "Balduin, a former monk",
          characterization: "A very discrete character, who worries chiefly about the protection of his"
            + " lands and his important buildings." },
        { face: 4, name: "Frollin",
          characterization: "His unpredictable behaviour will always take you by surprise. "
            + "He will \"pilfer\" away lands that are not occupied." },
        { face: 5, name: "Kallina",
          characterization: "She is a fighter who attempts to block the enemy’s food supply by using "
            + "strategic tactics." },
        { face: 6, name: "Rasparuk the druid",
          characterization: "His tactics consist in amassing large stocks of raw materials. "
            + "But he attacks slyly." },
        { face: 7, name: "Count Aldaba",
          characterization: "Protect your warehouses well, because he is aggressive and knows exactly "
            + "where he must attack." },
        { face: 8, name: "The King Rolph VII",
          characterization: "He is a prudent ruler, without any particular weakness. He will try to "
            + "check the supply of construction materials of his adversaries." },
        { face: 9, name: "Homen Doublehorn",
          characterization: "He is the most aggressive enemy. Watch your buildings carefully, "
            + "otherwise he might take you by surprise." },
        { face: 10, name: "Sollok the Joker",
          characterization: "A sly and repugnant adversary, he will try to stop the supply of raw "
            + "materials of his enemies right from the beginning of the game." },
        { face: 11, name: "Enemy",
          characterization: "Last enemy." },
        { face: 12, name: "You",
          characterization: "You." },
        { face: 13, name: "Friend",
          characterization: "Your partner." }
    ];

    // Player::Color def_color[]
    global.mission_def_color = [
        { red: 0x00, green: 0xe3, blue: 0xe3 },
        { red: 0xcf, green: 0x63, blue: 0x63 },
        { red: 0xdf, green: 0x7f, blue: 0xef },
        { red: 0xef, green: 0xef, blue: 0x8f },
        { red: 0x00, green: 0x00, blue: 0x00 }
    ];

    // GameInfo::Mission tutorials[]
    global.mission_tutorials = [
        { name: "Tutorial 1", random_base: "3762665523225478", players: [
            mission_preset(12, 40, 30, 30, -1, -1) ] },
        { name: "Tutorial 2", random_base: "1616118277634871", players: [
            mission_preset(12, 40, 30, 30, -1, -1) ] },
        { name: "Tutorial 3", random_base: "2418554743842118", players: [
            mission_preset(12, 40, 30, 30, -1, -1) ] },
        { name: "Tutorial 4", random_base: "4454333314864658", players: [
            mission_preset(12, 40, 30, 30, -1, -1) ] },
        { name: "Tutorial 5", random_base: "4264118313621432", players: [
            mission_preset(12, 40, 30, 30, -1, -1) ] },
        { name: "Tutorial 6", random_base: "2487251185361288", players: [
            mission_preset(12, 40, 30, 30, -1, -1) ] }
    ];

    // GameInfo::Mission missions[]
    global.mission_missions = [
        { name: "START", random_base: "8667715887436237", players: [
            mission_preset(12, 40, 35, 30, -1, -1),
            mission_preset( 1, 10,  5, 30, -1, -1) ] },
        { name: "STATION", random_base: "2831713285431227", players: [
            mission_preset(12, 40, 30, 40, -1, -1),
            mission_preset( 2, 12, 15, 30, -1, -1),
            mission_preset( 3, 14, 15, 30, -1, -1) ] },
        { name: "UNITY", random_base: "4632253338621228", players: [
            mission_preset(12, 40, 30, 30, -1, -1),
            mission_preset( 2, 18, 10, 25, -1, -1),
            mission_preset( 4, 18, 10, 25, -1, -1) ] },
        { name: "WAVE", random_base: "8447342476811762", players: [
            mission_preset(12, 40, 25, 40, -1, -1),
            mission_preset( 2, 16, 20, 30, -1, -1) ] },
        { name: "EXPORT", random_base: "4276472414845177", players: [
            mission_preset(12, 40, 30, 30, -1, -1),
            mission_preset( 3, 16, 25, 20, -1, -1),
            mission_preset( 4, 16, 25, 20, -1, -1) ] },
        { name: "OPTION", random_base: "2333577877517478", players: [
            mission_preset(12, 40, 30, 30, -1, -1),
            mission_preset( 3, 20, 12, 14, -1, -1),
            mission_preset( 5, 20, 12, 14, -1, -1) ] },
        { name: "RECORD", random_base: "1416541231242884", players: [
            mission_preset(12, 40, 30, 40, -1, -1),
            mission_preset( 3, 22, 30, 30, -1, -1) ] },
        { name: "SCALE", random_base: "7845187715476348", players: [
            mission_preset(12, 40, 25, 30, -1, -1),
            mission_preset( 4, 23, 25, 30, -1, -1),
            mission_preset( 6, 24, 25, 30, -1, -1) ] },
        { name: "SIGN", random_base: "5185768873118642", players: [
            mission_preset(12, 40, 25, 40, -1, -1),
            mission_preset( 4, 26, 13, 30, -1, -1),
            mission_preset( 5, 28, 13, 30, -1, -1),
            mission_preset( 6, 30, 13, 30, -1, -1) ] },
        { name: "ACORN", random_base: "3183215728814883", players: [
            mission_preset(12, 40, 20, 16, 28, 14),
            mission_preset( 4, 30, 19, 20,  5, 47) ] },
        { name: "CHOPPER", random_base: "4376241846215474", players: [
            mission_preset(12, 40, 16, 20, 16, 42),
            mission_preset( 5, 33, 10, 20, 52, 25),
            mission_preset( 7, 34, 13, 20, 23, 12) ] },
        { name: "GATE", random_base: "6371557668231277", players: [
            mission_preset(12, 40, 23, 27, 53, 13),
            mission_preset( 5, 27, 17, 24, 27, 10),
            mission_preset( 6, 27, 13, 24, 29, 38),
            mission_preset( 7, 27, 13, 24, 15, 32) ] },
        { name: "ISLAND", random_base: "8473352672411117", players: [
            mission_preset(12, 40, 24, 20,  7, 26),
            mission_preset( 5, 20, 30, 20,  2, 10) ] },
        { name: "LEGION", random_base: "1167854231884464", players: [
            mission_preset(12, 40, 20, 23, 19,  3),
            mission_preset( 6, 28, 16, 20, 55,  7),
            mission_preset( 8, 28, 16, 20, 55, 46) ] },
        { name: "PIECE", random_base: "2571462671725414", players: [
            mission_preset(12, 40, 20, 17, 41,  5),
            mission_preset( 6, 40, 23, 20, 19, 49),
            mission_preset( 7, 37, 20, 20, 58, 52),
            mission_preset( 8, 40, 15, 15, 43, 31) ] },
        { name: "RIVAL", random_base: "4563653871271587", players: [
            mission_preset(12, 40, 26, 23, 36, 63),
            mission_preset( 6, 28, 29, 40, 14, 15) ] },
        { name: "SAVAGE", random_base: "7212145428156114", players: [
            mission_preset(12, 40, 25, 12, 63, 59),
            mission_preset( 7, 29, 17, 10, 29, 24),
            mission_preset( 8, 29, 17, 10, 39, 26),
            mission_preset( 9, 32, 17, 10, 42, 49) ] },
        { name: "XAVER", random_base: "4276472414435177", players: [
            mission_preset(12, 40, 25, 40, 15,  0),
            mission_preset( 7, 40, 30, 35, 34, 48),
            mission_preset( 9, 30, 30, 35, 58,  5) ] },
        { name: "BLADE", random_base: "7142748441424786", players: [
            mission_preset(12, 40, 30, 20, 13, 37),
            mission_preset( 7, 40, 20, 20, 32, 34) ] },
        { name: "BEACON", random_base: "6882188351133886", players: [
            mission_preset(12, 40,  9, 10, 14, 42),
            mission_preset( 8, 40, 16, 22, 62,  1),
            mission_preset( 9, 40, 16, 23, 32, 14) ] },
        { name: "PASTURE", random_base: "7742136435163436", players: [
            mission_preset(12, 40, 20, 11, 38, 17),
            mission_preset( 8, 30, 22, 13, 32, 51),
            mission_preset( 9, 30, 23, 13,  1, 50),
            mission_preset(10, 30, 21, 13,  4,  9) ] },
        { name: "OMNUS", random_base: "6764387728224725", players: [
            mission_preset(12, 40, 20, 40, 42, 20),
            mission_preset( 8, 36, 25, 40, 48, 47) ] },
        { name: "TRIBUTE", random_base: "5848744734731253", players: [
            mission_preset(12, 40,  5, 11, 53,  1),
            mission_preset( 9, 35, 30, 10, 20,  2),
            mission_preset(10, 37, 30, 10, 16, 55) ] },
        { name: "FOUNTAIN", random_base: "6183541838474434", players: [
            mission_preset(12, 40, 20, 12,  3, 34),
            mission_preset( 9, 30, 25, 10, 47, 41),
            mission_preset(10, 30, 26, 10, 42, 52) ] },
        { name: "CHUDE", random_base: "7633126817245833", players: [
            mission_preset(12, 40, 20, 40, 23, 38),
            mission_preset( 9, 40, 25, 40, 57, 52) ] },
        { name: "TRAILER", random_base: "5554144773646312", players: [
            mission_preset(12, 40, 20, 30, 29, 11),
            mission_preset(10, 38, 30, 35, 15, 40) ] },
        { name: "CANYON", random_base: "3122431112682557", players: [
            mission_preset(12, 40, 18, 28, 49, 53),
            mission_preset(10, 39, 25, 40, 14, 53) ] },
        { name: "REPRESS", random_base: "2568412624848266", players: [
            mission_preset(12, 40, 20, 40, 44, 39),
            mission_preset(10, 39, 25, 40, 44, 63) ] },
        { name: "YOKI", random_base: "3736685353284538", players: [
            mission_preset(12, 40,  5, 22, 53,  8),
            mission_preset(11, 40, 15, 20, 30, 22) ] },
        { name: "PASSIVE", random_base: "5471458635555317", players: [
            mission_preset(12, 40,  5, 20, 25, 46),
            mission_preset(11, 40, 20, 20, 51, 42) ] }
    ];
}

/// Port of PlayerInfo (mission.h lines 39-87). This constructor is the
/// 5-argument C++ constructor PlayerInfo(character, color, intelligence,
/// supplies, reproduction); use player_info_from_random(rnd) for the
/// PlayerInfo(Random *random_base) constructor.
/// _color is a Player::Color struct {red, green, blue}.
function PlayerInfo(_character, _color, _intelligence, _supplies, _reproduction) constructor {
    mission_init_tables();

    intelligence = 0;
    supplies = 0;
    reproduction = 0;
    face = 0;
    color = { red: 0, green: 0, blue: 0 };
    name = "";
    characterization = "";
    castle_pos = { col: 0, row: 0 };

    static set_intelligence = function(_intelligence) {
        intelligence = _intelligence;
    };
    static set_supplies = function(_supplies) {
        supplies = _supplies;
    };
    static set_reproduction = function(_reproduction) {
        reproduction = _reproduction;
    };
    /// _castle_pos: struct {col, row}
    static set_castle_pos = function(_castle_pos) {
        castle_pos = { col: _castle_pos.col, row: _castle_pos.row };
    };
    static set_character = function(_character) {
        face = global.mission_characters[_character].face;
        name = global.mission_characters[_character].name;
        characterization = global.mission_characters[_character].characterization;
    };
    static set_color = function(_color) {
        color = { red: _color.red, green: _color.green, blue: _color.blue };
    };

    static get_intelligence = function() { return intelligence; };
    static get_supplies = function() { return supplies; };
    static get_reproduction = function() { return reproduction; };
    static get_face = function() { return face; };
    static get_color = function() { return color; };
    static get_castle_pos = function() { return castle_pos; };
    static get_name = function() { return name; };
    static get_characterization = function() { return characterization; };

    static has_castle = function() {
        return (castle_pos.col >= 0);
    };

    // Body of PlayerInfo(size_t character, const Player::Color &_color, ...)
    set_character(_character);
    set_intelligence(_intelligence);
    set_supplies(_supplies);
    set_reproduction(_reproduction);
    set_color(_color);
    set_castle_pos({ col: -1, row: -1 });
}

/// Port of PlayerInfo::PlayerInfo(Random *random_base) (mission.cc
/// lines 518-531). Consumes four values from _random_base (a RandomState,
/// modified in place, exactly like the C++ pointer).
function player_info_from_random(_random_base) {
    mission_init_tables();
    var _info = new PlayerInfo(0, { red: 0, green: 0, blue: 0 }, 0, 0, 0);
    // The 5-arg constructor already set colour to {0,0,0} and castle to
    // {-1,-1}; now redo the random-based initialisation in C++ order.
    var _character = (((_random_base.next_random() * 10) >> 16) + 1) & 0xFF;
    _info.set_character(_character);
    _info.set_intelligence(((_random_base.next_random() * 41) >> 16) & 0xFF);
    _info.set_supplies(((_random_base.next_random() * 41) >> 16) & 0xFF);
    _info.set_reproduction(((_random_base.next_random() * 41) >> 16) & 0xFF);
    _info.set_castle_pos({ col: -1, row: -1 });
    return _info;
}

/// Port of GameInfo (mission.h lines 95-137). This is the public
/// GameInfo(const Random &random_base) constructor; the protected
/// GameInfo(const Mission *) is game_info_from_mission(preset).
/// _random_base is a RandomState.
function GameInfo(_random_base) constructor {
    mission_init_tables();

    map_size = 3;
    random_base = new RandomState(0, 0, 0);
    players = [];
    name = "";

    static get_map_size = function() { return map_size; };
    static set_map_size = function(_size) { map_size = _size; };
    /// Returns a copy (C++ returns Random by value).
    static get_random_base = function() {
        return random_state_copy(random_base);
    };
    static get_player_count = function() { return array_length(players); };
    static get_player = function(_player) { return players[_player]; };
    static get_name = function() { return name; };

    static set_random_base = function(_base) {
        var _random = random_state_copy(_base);
        random_base = random_state_copy(_base);

        players = [];

        // Player 0
        array_push(players, player_info_from_random(_random));
        players[0].set_character(12);
        players[0].set_intelligence(40);

        // Player 1
        array_push(players, player_info_from_random(_random));

        var _val = _random.next_random();
        if ((_val & 7) != 0) {
            // Player 2
            array_push(players, player_info_from_random(_random));
            var _val2 = _random.next_random();
            if ((_val2 & 3) == 0) {
                // Player 3
                array_push(players, player_info_from_random(_random));
            }
        }

        var _i = 0;
        var _n = array_length(players);
        for (var _p = 0; _p < _n; _p++) {
            var _info = players[_p];
            if (_i < 4) {
                _info.set_color(global.mission_def_color[_i]);
                _i++;
            }
        }
    };

    /// add_player(const PPlayerInfo &player)
    static add_player_info = function(_player) {
        array_push(players, _player);
    };

    /// add_player(character, color, intelligence, supplies, reproduction)
    static add_player = function(_character, _color, _intelligence, _supplies, _reproduction) {
        var _player = new PlayerInfo(_character, _color, _intelligence, _supplies, _reproduction);
        add_player_info(_player);
    };

    static remove_player = function(_index) {
        if (_index >= array_length(players)) {
            return;
        }
        array_delete(players, _index, 1);
    };

    static remove_all_players = function() {
        players = [];
    };

    static get_mission = function(_m) {
        return game_info_get_mission(_m);
    };
    static get_mission_count = function() {
        return game_info_get_mission_count();
    };
    static get_tutorial = function(_t) {
        return game_info_get_tutorial(_t);
    };
    static get_tutorial_count = function() {
        return game_info_get_tutorial_count();
    };
    static get_character = function(_character) {
        return game_info_get_character(_character);
    };
    static get_character_count = function() {
        return game_info_get_character_count();
    };

    /// Port of GameInfo::instantiate() (mission.cc lines 492-516).
    /// The C++ creates a new Game; here the caller passes the Game object
    /// (constructed by the caller) and it is initialised in place.
    /// Returns the game, or undefined when game.init() fails.
    static instantiate = function(_game) {
        if (!_game.init(map_size, random_base)) {
            return undefined;
        }

        /* Initialize player and build initial castle */
        var _n = array_length(players);
        for (var _p = 0; _p < _n; _p++) {
            var _player_info = players[_p];
            var _index = _game.add_player(_player_info.get_intelligence(),
                                          _player_info.get_supplies(),
                                          _player_info.get_reproduction());
            var _player = _game.get_player(_index);
            _player.init_view(_player_info.get_color(), _player_info.get_face());

            var _castle_pos = _player_info.get_castle_pos();
            if (_castle_pos.col > -1 && _castle_pos.row > -1) {
                var _pos = _game.get_map().pos(_castle_pos.col, _castle_pos.row);
                _game.build_castle(_pos, _player);
            }
        }

        return _game;
    };

    // Body of GameInfo(const Random &_random_base): map_size(3), name(_random_base)
    name = random_state_to_string(_random_base);
    set_random_base(_random_base);
}

/// Port of the protected GameInfo(const Mission *mission_preset) constructor
/// (mission.cc lines 386-401). _mission_preset is a table entry.
function game_info_from_mission(_mission_preset) {
    mission_init_tables();
    var _info = new GameInfo(random_state_from_string(_mission_preset.random_base));
    _info.map_size = 3;
    _info.name = _mission_preset.name;
    _info.random_base = random_state_from_string(_mission_preset.random_base);
    _info.players = [];
    var _n = array_length(_mission_preset.players);
    for (var _i = 0; _i < _n; _i++) {
        var _player_info = _mission_preset.players[_i];
        var _character = _player_info.face;
        var _player = new PlayerInfo(_character,
                                     global.mission_def_color[_i],
                                     _player_info.intelligence,
                                     _player_info.supplies,
                                     _player_info.reproduction);
        _player.set_castle_pos(_player_info.castle);
        _info.add_player_info(_player);
    }
    return _info;
}

/// static GameInfo::get_mission(size_t m)
function game_info_get_mission(_m) {
    mission_init_tables();
    if (_m < 0 || _m >= game_info_get_mission_count()) {
        return undefined;
    }
    return game_info_from_mission(global.mission_missions[_m]);
}

/// static GameInfo::get_mission_count()
function game_info_get_mission_count() {
    mission_init_tables();
    return array_length(global.mission_missions);
}

/// Tutorial accessor (tutorials[] table; no C++ accessor exists).
function game_info_get_tutorial(_t) {
    mission_init_tables();
    if (_t < 0 || _t >= game_info_get_tutorial_count()) {
        return undefined;
    }
    return game_info_from_mission(global.mission_tutorials[_t]);
}

function game_info_get_tutorial_count() {
    mission_init_tables();
    return array_length(global.mission_tutorials);
}

/// static GameInfo::get_character(size_t character)
function game_info_get_character(_character) {
    mission_init_tables();
    if (_character < 0 || _character >= game_info_get_character_count()) {
        return undefined;
    }
    return global.mission_characters[_character];
}

/// static GameInfo::get_character_count()
function game_info_get_character_count() {
    mission_init_tables();
    return array_length(global.mission_characters);
}
