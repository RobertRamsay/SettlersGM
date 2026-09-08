// scr_map_generator.gml
// Ported from Freeserf (GPL-3.0), original copyright (C) 2013-2016
// Jon Lund Steffensen <jonlst@gmail.com>.
// Ports src/map-generator.h and src/map-generator.cc (ClassicMapGenerator,
// ClassicMissionMapGenerator) in full. Also carries a private copy of
// Map::map_space_from_obj (src/map.cc lines 170-319) and an inline port of
// Map::get_rnd_coord (src/map.cc lines 345-353) because those are consumed
// with the generator's OWN random state.
//
// This file is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.

enum HeightGenerator {
  midpoints = 0,
  diamond_square
}

#macro CLASSIC_MAP_GEN_DEFAULT_MAX_LAKE_AREA 14
#macro CLASSIC_MAP_GEN_DEFAULT_WATER_LEVEL 20
#macro CLASSIC_MAP_GEN_DEFAULT_TERRAIN_SPIKYNESS 0x9999

/// Classic map generator as in original game.
/// _map : Map struct (exposes geom, regions, spiral_pos_pattern)
/// _rnd : RandomState struct (state[3], random())
function ClassicMapGenerator(_map, _rnd) constructor {
  map = _map;

  // C++ holds a COPY of the random state (Random rnd). Copy it here so the
  // caller's generator is not advanced.
  rnd = new RandomState(_rnd.state[0], _rnd.state[1], _rnd.state[2]);
  rnd.state = [_rnd.state[0], _rnd.state[1], _rnd.state[2]];

  height_generator = HeightGenerator.midpoints;
  preserve_bugs = false;
  water_level = CLASSIC_MAP_GEN_DEFAULT_WATER_LEVEL;
  max_lake_area = CLASSIC_MAP_GEN_DEFAULT_MAX_LAKE_AREA;
  terrain_spikyness = CLASSIC_MAP_GEN_DEFAULT_TERRAIN_SPIKYNESS;

  // Landscape tiles (std::vector<Map::LandscapeTile> tiles, value initialised
  // to zero), one flat array per field.
  tile_count = map.geom.tile_count;
  height = array_create(tile_count, 0);
  type_up = array_create(tile_count, Terrain.water0);
  type_down = array_create(tile_count, Terrain.water0);
  mineral = array_create(tile_count, Minerals.none);
  res_amount = array_create(tile_count, 0);
  obj = array_create(tile_count, MapObject.none);

  // std::vector<int> tags
  tags = array_create(tile_count, 0);

  // Map::map_space_from_obj[128] (src/map.cc). Index = MapObject value.
  map_space_from_obj = array_create(128, Space.open);
  map_space_from_obj[0] = Space.open;          // none = 0
  map_space_from_obj[1] = Space.filled;        // flag
  map_space_from_obj[2] = Space.impassable;    // small_building
  map_space_from_obj[3] = Space.impassable;    // large_building
  map_space_from_obj[4] = Space.impassable;    // castle
  map_space_from_obj[5] = Space.open;
  map_space_from_obj[6] = Space.open;
  map_space_from_obj[7] = Space.open;
  // tree0 .. tree7 (8..15)
  for (var _i = 8; _i <= 15; _i++) {
    map_space_from_obj[_i] = Space.filled;
  }
  // pine0 .. pine7 (16..23)
  for (var _i = 16; _i <= 23; _i++) {
    map_space_from_obj[_i] = Space.filled;
  }
  // palm0 .. palm3 (24..27)
  for (var _i = 24; _i <= 27; _i++) {
    map_space_from_obj[_i] = Space.filled;
  }
  // water_tree0 .. water_tree3 (28..31)
  for (var _i = 28; _i <= 31; _i++) {
    map_space_from_obj[_i] = Space.impassable;
  }
  // 32 .. 71 : open (already)
  // stone0 .. stone7 (72..79)
  for (var _i = 72; _i <= 79; _i++) {
    map_space_from_obj[_i] = Space.impassable;
  }
  map_space_from_obj[80] = Space.impassable;   // sandstone0
  map_space_from_obj[81] = Space.impassable;   // sandstone1
  map_space_from_obj[82] = Space.filled;       // cross
  map_space_from_obj[83] = Space.open;         // stub
  map_space_from_obj[84] = Space.open;         // stone
  map_space_from_obj[85] = Space.open;         // sandstone3
  map_space_from_obj[86] = Space.open;         // cadaver0
  map_space_from_obj[87] = Space.open;         // cadaver1
  map_space_from_obj[88] = Space.impassable;   // water_stone0
  map_space_from_obj[89] = Space.impassable;   // water_stone1
  map_space_from_obj[90] = Space.filled;       // cactus0
  map_space_from_obj[91] = Space.filled;       // cactus1
  map_space_from_obj[92] = Space.filled;       // dead_tree
  map_space_from_obj[93] = Space.filled;       // felled_pine0
  map_space_from_obj[94] = Space.filled;       // felled_pine1
  map_space_from_obj[95] = Space.filled;       // felled_pine2
  map_space_from_obj[96] = Space.filled;       // felled_pine3
  map_space_from_obj[97] = Space.open;         // felled_pine4
  map_space_from_obj[98] = Space.filled;       // felled_tree0
  map_space_from_obj[99] = Space.filled;       // felled_tree1
  map_space_from_obj[100] = Space.filled;      // felled_tree2
  map_space_from_obj[101] = Space.filled;      // felled_tree3
  map_space_from_obj[102] = Space.open;        // felled_tree4
  map_space_from_obj[103] = Space.filled;      // new_pine
  map_space_from_obj[104] = Space.filled;      // new_tree
  // seeds0 .. seeds5 (105..110)
  for (var _i = 105; _i <= 110; _i++) {
    map_space_from_obj[_i] = Space.semipassable;
  }
  map_space_from_obj[111] = Space.open;        // field_expired
  // 112 .. 120 : signs, open (already)
  // field0 .. field5 (121..126)
  for (var _i = 121; _i <= 126; _i++) {
    map_space_from_obj[_i] = Space.semipassable;
  }
  map_space_from_obj[127] = Space.open;        // object127

  // ---------------------------------------------------------------------
  // Accessors (MapGenerator interface)
  // ---------------------------------------------------------------------
  static get_height = function(_pos) {
    return height[_pos];
  };
  static get_type_up = function(_pos) {
    return type_up[_pos];
  };
  static get_type_down = function(_pos) {
    return type_down[_pos];
  };
  static get_obj = function(_pos) {
    return obj[_pos];
  };
  static get_resource_type = function(_pos) {
    return mineral[_pos];
  };
  static get_resource_amount = function(_pos) {
    return res_amount[_pos];
  };

  // ---------------------------------------------------------------------
  // init
  // ---------------------------------------------------------------------
  static init = function(_height_generator, _preserve_bugs, _max_lake_area,
                         _water_level, _terrain_spikyness) {
    height_generator = _height_generator;
    preserve_bugs = _preserve_bugs;
    if (is_undefined(_max_lake_area)) {
      max_lake_area = CLASSIC_MAP_GEN_DEFAULT_MAX_LAKE_AREA;
    } else {
      max_lake_area = _max_lake_area;
    }
    if (is_undefined(_water_level)) {
      water_level = CLASSIC_MAP_GEN_DEFAULT_WATER_LEVEL;
    } else {
      water_level = _water_level;
    }
    if (is_undefined(_terrain_spikyness)) {
      terrain_spikyness = CLASSIC_MAP_GEN_DEFAULT_TERRAIN_SPIKYNESS;
    } else {
      terrain_spikyness = _terrain_spikyness;
    }
  };

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  /// uint16_t random_int()
  static random_int = function() {
    return rnd.next_random() & 0xFFFF;
  };

  /// Port of Map::get_rnd_coord(NULL, NULL, &rnd) using the generator's rnd.
  static get_rnd_coord = function() {
    var _c = rnd.next_random() & map.geom.col_mask;
    var _r = rnd.next_random() & map.geom.row_mask;
    return map.geom.pos(_c, _r);
  };

  /// Port of Map::pos_add_spirally(pos, off).
  static pos_add_spirally = function(_pos, _off) {
    return map.geom.pos_add_off(_pos, map.spiral_pos_pattern[_off]);
  };

  /// Whether any of the two up/down tiles at this pos are water.
  static is_water_tile = function(_pos) {
    return (type_down[_pos] <= Terrain.water3) &&
           (type_up[_pos] <= Terrain.water3);
  };

  /// Whether the position is completely surrounded by water.
  static is_in_water = function(_pos) {
    return (is_water_tile(_pos) &&
            is_water_tile(map.geom.move_up_left(_pos)) &&
            (type_down[map.geom.move_left(_pos)] <= Terrain.water3) &&
            (type_up[map.geom.move_up(_pos)] <= Terrain.water3));
  };

  // ---------------------------------------------------------------------
  // generate
  // ---------------------------------------------------------------------
  static generate = function() {
    // rnd ^= Random(0x5a5a, 0xa5a5, 0xc3c3);
    rnd.state[0] = (rnd.state[0] ^ 0x5a5a) & 0xFFFF;
    rnd.state[1] = (rnd.state[1] ^ 0xa5a5) & 0xFFFF;
    rnd.state[2] = (rnd.state[2] ^ 0xc3c3) & 0xFFFF;

    random_int();
    random_int();

    init_heights_squares();
    switch (height_generator) {
      case HeightGenerator.midpoints:
        init_heights_midpoints(); /* Midpoint displacement algorithm */
        break;
      case HeightGenerator.diamond_square:
        init_heights_diamond_square(); /* Diamond square algorithm */
        break;
      default:
        throw "ClassicMapGenerator.generate: unknown height generator";
    }

    clamp_heights();
    create_water_bodies();
    heights_rebase();
    init_types();
    remove_islands();
    heights_rescale();

    // Adjust terrain types on shores
    change_shore_water_type();
    change_shore_grass_type();

    // Create deserts
    create_deserts();

    // Create map objects (trees, boulders, etc.)
    create_objects();

    create_mineral_deposits();

    clean_up();
  };

  // ---------------------------------------------------------------------
  // Heights
  // ---------------------------------------------------------------------

  /// Midpoint displacement map generator. This function initialises the
  /// height values in the corners of 16x16 squares.
  static init_heights_squares = function() {
    var _rows = map.geom.rows;
    var _cols = map.geom.cols;
    for (var _y = 0; _y < _rows; _y += 16) {
      for (var _x = 0; _x < _cols; _x += 16) {
        var _rndl = random_int() & 0xff;
        height[map.geom.pos(_x, _y)] = min(_rndl, 250);
      }
    }
  };

  static calc_height_displacement = function(_avg, _base, _offset) {
    var _r = random_int();
    var _h = ((_r * _base) >> 16) - _offset + _avg;

    return max(0, min(_h, 250));
  };

  /// Calculate height values of the subdivisions in the midpoint
  /// displacement algorithm.
  static init_heights_midpoints = function() {
    var _rndl = random_int();
    var _r1 = 0x80 + (_rndl & 0x7f);
    var _r2 = (_r1 * terrain_spikyness) >> 16;

    var _rows = map.geom.rows;
    var _cols = map.geom.cols;

    for (var _i = 8; _i > 0; _i = _i >> 1) {
      for (var _y = 0; _y < _rows; _y += 2 * _i) {
        for (var _x = 0; _x < _cols; _x += 2 * _i) {
          var _pos = map.geom.pos(_x, _y);
          var _h = height[_pos];

          var _pos_r = map.geom.move_right_n(_pos, 2 * _i);
          var _pos_mid_r = map.geom.move_right_n(_pos, _i);
          var _h_r = height[_pos_r];

          if (preserve_bugs) {
            /* The intention was probably just to set h_r to the map height
               value, but the upper bits of rnd must be preserved in h_r in
               the first iteration to generate the same maps as the original
               game. */
            if (_x == 0 && _y == 0 && _i == 8) {
              _h_r = _h_r | (_rndl & 0xff00);
            }
          }

          height[_pos_mid_r] =
            calc_height_displacement((_h + _h_r) div 2, _r1, _r2);

          var _pos_d = map.geom.move_down_n(_pos, 2 * _i);
          var _pos_mid_d = map.geom.move_down_n(_pos, _i);
          var _h_d = height[_pos_d];
          height[_pos_mid_d] =
            calc_height_displacement((_h + _h_d) div 2, _r1, _r2);

          var _pos_dr = map.geom.move_right_n(
            map.geom.move_down_n(_pos, 2 * _i), 2 * _i);
          var _pos_mid_dr = map.geom.move_right_n(
            map.geom.move_down_n(_pos, _i), _i);
          var _h_dr = height[_pos_dr];
          height[_pos_mid_dr] =
            calc_height_displacement((_h + _h_dr) div 2, _r1, _r2);
        }
      }

      _r1 = _r1 >> 1;
      _r2 = _r2 >> 1;
    }
  };

  static init_heights_diamond_square = function() {
    var _rndl = random_int();
    var _r1 = 0x80 + (_rndl & 0x7f);
    var _r2 = (_r1 * terrain_spikyness) >> 16;

    var _rows = map.geom.rows;
    var _cols = map.geom.cols;

    for (var _i = 8; _i > 0; _i = _i >> 1) {
      /* Diamond step */
      for (var _y = 0; _y < _rows; _y += 2 * _i) {
        for (var _x = 0; _x < _cols; _x += 2 * _i) {
          var _pos = map.geom.pos(_x, _y);
          var _h = height[_pos];

          var _pos_r = map.geom.move_right_n(_pos, 2 * _i);
          var _h_r = height[_pos_r];

          var _pos_d = map.geom.move_down_n(_pos, 2 * _i);
          var _h_d = height[_pos_d];

          var _pos_dr = map.geom.move_right_n(
            map.geom.move_down_n(_pos, 2 * _i), 2 * _i);
          var _h_dr = height[_pos_dr];

          var _pos_mid_dr = map.geom.move_right_n(
            map.geom.move_down_n(_pos, _i), _i);
          var _avg = (_h + _h_r + _h_d + _h_dr) div 4;
          height[_pos_mid_dr] = calc_height_displacement(_avg, _r1, _r2);
        }
      }

      /* Square step */
      for (var _y = 0; _y < _rows; _y += 2 * _i) {
        for (var _x = 0; _x < _cols; _x += 2 * _i) {
          var _pos = map.geom.pos(_x, _y);
          var _h = height[_pos];

          var _pos_r = map.geom.move_right_n(_pos, 2 * _i);
          var _h_r = height[_pos_r];

          var _pos_d = map.geom.move_down_n(_pos, 2 * _i);
          var _h_d = height[_pos_d];

          var _pos_ur = map.geom.move_right_n(
            map.geom.move_down_n(_pos, -_i), _i);
          var _h_ur = height[_pos_ur];

          var _pos_dr = map.geom.move_right_n(
            map.geom.move_down_n(_pos, _i), _i);
          var _h_dr = height[_pos_dr];

          var _pos_dl = map.geom.move_right_n(
            map.geom.move_down_n(_pos, _i), -_i);
          var _h_dl = height[_pos_dl];

          var _pos_mid_r = map.geom.move_right_n(_pos, _i);
          var _avg_r = (_h + _h_r + _h_ur + _h_dr) div 4;
          height[_pos_mid_r] = calc_height_displacement(_avg_r, _r1, _r2);

          var _pos_mid_d = map.geom.move_down_n(_pos, _i);
          var _avg_d = (_h + _h_d + _h_dl + _h_dr) div 4;
          height[_pos_mid_d] = calc_height_displacement(_avg_d, _r1, _r2);
        }
      }

      _r1 = _r1 >> 1;
      _r2 = _r2 >> 1;
    }
  };

  static adjust_map_height = function(_h1, _h2, _pos) {
    if (abs(_h1 - _h2) > 32) {
      if (_h1 < _h2) {
        height[_pos] = _h1 + 32;
      } else {
        height[_pos] = _h1 - 32;
      }
      return true;
    }

    return false;
  };

  /// Ensure that map heights of adjacent fields are not too far apart.
  static clamp_heights = function() {
    var _changed = true;
    while (_changed) {
      _changed = false;
      for (var _pos = 0; _pos < tile_count; _pos++) {
        var _h = height[_pos];

        var _pos_d = map.geom.move_down(_pos);
        var _h_d = height[_pos_d];
        if (adjust_map_height(_h, _h_d, _pos_d)) {
          _changed = true;
        }

        var _pos_dr = map.geom.move_down_right(_pos);
        var _h_dr = height[_pos_dr];
        if (adjust_map_height(_h, _h_dr, _pos_dr)) {
          _changed = true;
        }

        var _pos_r = map.geom.move_right(_pos);
        var _h_r = height[_pos_r];
        if (adjust_map_height(_h, _h_r, _pos_r)) {
          _changed = true;
        }
      }
    }
  };

  // ---------------------------------------------------------------------
  // Water bodies
  // ---------------------------------------------------------------------

  /// Expand water around position.
  ///
  /// Expand water area by marking shores with 254 and water positions with
  /// 255. Water (255) can only be expanded to a position where all six
  /// adjacent positions are at or lower than the water level. When a
  /// position is marked as water (255) the surrounding positions, that are
  /// not yet marked, are changed to shore (254). Returns true only if the
  /// given position was converted to water.
  static expand_water_position = function(_pos) {
    var _expanding = false;

    for (var _d = Direction.right; _d <= Direction.up; _d++) {
      var _new_pos = map.geom.move(_pos, _d);
      var _height = height[_new_pos];
      if (water_level < _height && _height < 254) {
        return false;
      } else if (_height == 255) {
        _expanding = true;
      }
    }

    if (_expanding) {
      height[_pos] = 255;

      for (var _d = Direction.right; _d <= Direction.up; _d++) {
        var _new_pos = map.geom.move(_pos, _d);
        if (height[_new_pos] != 255) {
          height[_new_pos] = 254;
        }
      }
    }

    return _expanding;
  };

  /// Try to expand area around position into a water body.
  ///
  /// After expanding, the water body will be tagged with the heights 253 for
  /// positions in water and 252 for positions on the shore.
  static expand_water_body = function(_pos) {
    // Check whether it is possible to expand from this position.
    for (var _d = Direction.right; _d <= Direction.up; _d++) {
      var _new_pos = map.geom.move(_pos, _d);
      if (height[_new_pos] > water_level) {
        // Expanding water from this position was not possible. Just raise
        // the height to one above sea level.
        height[_pos] = 0;
        return;
      }
    }

    // Initialize expansion
    height[_pos] = 255;
    for (var _d = Direction.right; _d <= Direction.up; _d++) {
      var _new_pos = map.geom.move(_pos, _d);
      height[_new_pos] = 254;
    }

    // Expand water until we are unable to expand any more or until the max
    // lake area limit has been reached.
    for (var _i = 0; _i < max_lake_area; _i++) {
      var _expanded = false;

      var _new_pos = map.geom.move_right_n(_pos, _i + 1);
      // cycle_directions_cw(DirectionDown): down, left, up_left, up, right,
      // down_right
      for (var _k = 0; _k < 6; _k++) {
        var _d = (Direction.down + _k) mod 6;
        for (var _j = 0; _j <= _i; _j++) {
          if (expand_water_position(_new_pos)) {
            _expanded = true;
          }
          _new_pos = map.geom.move(_new_pos, _d);
        }
      }

      if (!_expanded) {
        break;
      }
    }

    // Change the water encoding from 255,254 to 253,252. This change means
    // that when expanding another lake, this area will look like an
    // elevated plateau at heights 252/253 and the other lake will not be
    // able to expand into this area. This keeps water bodies from growing
    // larger than the max lake area.
    height[_pos] -= 2;

    for (var _i = 0; _i < max_lake_area + 1; _i++) {
      var _new_pos = map.geom.move_right_n(_pos, _i + 1);
      for (var _k = 0; _k < 6; _k++) {
        var _d = (Direction.down + _k) mod 6;
        for (var _j = 0; _j <= _i; _j++) {
          if (height[_new_pos] > 253) {
            height[_new_pos] -= 2;
          }
          _new_pos = map.geom.move(_new_pos, _d);
        }
      }
    }
  };

  /// Create water bodies on the map.
  ///
  /// Try to expand every position that is at or below the water level into
  /// a body of water. After expanding bodies of water, the height of the
  /// positions are changed such that the lowest points on the map are at
  /// water_level - 1 (marking water) and just above that the height is at
  /// water_level (marking shore).
  static create_water_bodies = function() {
    for (var _h = 0; _h <= water_level; _h++) {
      for (var _pos = 0; _pos < tile_count; _pos++) {
        if (height[_pos] == _h) {
          expand_water_body(_pos);
        }
      }
    }

    // Map positions are marked in the previous loop.
    // 0: Above water level.
    // 252: Land at water level.
    // 253: Water.
    for (var _pos = 0; _pos < tile_count; _pos++) {
      var _h = height[_pos];
      switch (_h) {
        case 0:
          height[_pos] = water_level + 1;
          break;
        case 252:
          height[_pos] = water_level;
          break;
        case 253:
          height[_pos] = water_level - 1;
          mineral[_pos] = Minerals.none;
          res_amount[_pos] = random_int() & 7; /* Fish */
          break;
      }
    }
  };

  /// Adjust heights so zero height is sea level.
  static heights_rebase = function() {
    var _h = water_level - 1;

    for (var _pos = 0; _pos < tile_count; _pos++) {
      height[_pos] -= _h;
    }
  };

  // ---------------------------------------------------------------------
  // Types
  // ---------------------------------------------------------------------

  static calc_map_type = function(_h_sum) {
    if (_h_sum < 3) {
      return Terrain.water0;
    } else if (_h_sum < 384) {
      return Terrain.grass1;
    } else if (_h_sum < 416) {
      return Terrain.grass2;
    } else if (_h_sum < 448) {
      return Terrain.tundra0;
    } else if (_h_sum < 480) {
      return Terrain.tundra1;
    } else if (_h_sum < 528) {
      return Terrain.tundra2;
    } else if (_h_sum < 560) {
      return Terrain.snow0;
    }
    return Terrain.snow1;
  };

  /// Set type of map fields based on the height value.
  static init_types = function() {
    for (var _pos = 0; _pos < tile_count; _pos++) {
      var _h1 = height[_pos];
      var _h2 = height[map.geom.move_right(_pos)];
      var _h3 = height[map.geom.move_down_right(_pos)];
      var _h4 = height[map.geom.move_down(_pos)];
      type_up[_pos] = calc_map_type(_h1 + _h3 + _h4);
      type_down[_pos] = calc_map_type(_h1 + _h2 + _h3);
    }
  };

  static clear_all_tags = function() {
    for (var _pos = 0; _pos < tile_count; _pos++) {
      tags[_pos] = 0;
    }
  };

  /// Remove islands.
  ///
  /// Pick an initial map position, then search from there to see which
  /// other positions on the map are reachable (over land) from that
  /// position. If the reachable positions cover at least 1/4 of the map,
  /// then stop and convert any position that was _not_ reached to water.
  /// Otherwise, keep trying new initial positions.
  static remove_islands = function() {
    // Initially all positions are tagged with 0. When reached from another
    // position the tag is changed to 1, and later when that position is
    // itself expanded the tag is changed to 2.
    clear_all_tags();

    for (var _start = 0; _start < tile_count; _start++) {
      if (height[_start] > 0 && tags[_start] == 0) {
        tags[_start] = 1;

        var _num = 0;
        var _changed = true;
        while (_changed) {
          _changed = false;
          for (var _pos = 0; _pos < tile_count; _pos++) {
            if (tags[_pos] == 1) {
              _num += 1;
              tags[_pos] = 2;

              // The i'th flag will indicate whether a path on land from
              // pos_in direction i is possible.
              var _flags = 0;
              if (type_down[_pos] >= Terrain.grass0) {
                _flags = _flags | 3;
              }
              if (type_up[_pos] >= Terrain.grass0) {
                _flags = _flags | 6;
              }
              if (type_down[map.geom.move_left(_pos)] >= Terrain.grass0) {
                _flags = _flags | 0xc;
              }
              if (type_up[map.geom.move_up_left(_pos)] >= Terrain.grass0) {
                _flags = _flags | 0x18;
              }
              if (type_down[map.geom.move_up_left(_pos)] >= Terrain.grass0) {
                _flags = _flags | 0x30;
              }
              if (type_up[map.geom.move_up(_pos)] >= Terrain.grass0) {
                _flags = _flags | 0x21;
              }

              // Mark positions following any valid direction on land.
              for (var _d = Direction.right; _d <= Direction.up; _d++) {
                if ((_flags & (1 << _d)) != 0) {
                  var _moved = map.geom.move(_pos, _d);
                  if (tags[_moved] == 0) {
                    tags[_moved] = 1;
                    _changed = true;
                  }
                }
              }
            }
          }
        }

        if (4 * _num >= tile_count) {
          break;
        }
      }
    }

    // Change every position that was not tagged (i.e. tag is 0) to water.
    for (var _pos = 0; _pos < tile_count; _pos++) {
      if (height[_pos] > 0 && tags[_pos] == 0) {
        height[_pos] = 0;
        // NOTE: Freeserf sets type_up twice here (and never type_down);
        // preserved verbatim.
        type_up[_pos] = Terrain.water0;
        type_up[_pos] = Terrain.water0;

        type_down[map.geom.move_left(_pos)] = Terrain.water0;
        type_up[map.geom.move_up_left(_pos)] = Terrain.water0;
        type_down[map.geom.move_up_left(_pos)] = Terrain.water0;
        type_up[map.geom.move_up(_pos)] = Terrain.water0;
      }
    }
  };

  /// Rescale height values to be in [0;31].
  static heights_rescale = function() {
    for (var _pos = 0; _pos < tile_count; _pos++) {
      height[_pos] = (height[_pos] + 6) >> 3;
    }
  };

  /// Change terrain types based on a seed type in adjacent tiles.
  ///
  /// For every triangle, if the current type is old and any adjacent
  /// triangle has type seed, then the triangle is changed into the new_
  /// terrain type.
  static seed_terrain_type = function(_old, _seed, _new) {
    for (var _pos = 0; _pos < tile_count; _pos++) {
      var _ul = map.geom.move_up_left(_pos);
      var _u = map.geom.move_up(_pos);
      var _l = map.geom.move_left(_pos);
      var _r = map.geom.move_right(_pos);
      var _d = map.geom.move_down(_pos);
      var _dr = map.geom.move_down_right(_pos);

      // Up triangle
      if (type_up[_pos] == _old &&
          (_seed == type_down[_ul] ||
           _seed == type_up[_ul] ||
           _seed == type_up[_u] ||
           _seed == type_down[_l] ||
           _seed == type_up[_l] ||
           _seed == type_down[_pos] ||
           _seed == type_up[_r] ||
           _seed == type_down[map.geom.move_left(_d)] ||
           _seed == type_down[_d] ||
           _seed == type_up[_d] ||
           _seed == type_down[_dr] ||
           _seed == type_up[_dr])) {
        type_up[_pos] = _new;
      }

      // Down triangle
      if (type_down[_pos] == _old &&
          (_seed == type_down[_ul] ||
           _seed == type_up[_ul] ||
           _seed == type_down[_u] ||
           _seed == type_up[_u] ||
           _seed == type_up[map.geom.move_right(_u)] ||
           _seed == type_down[_l] ||
           _seed == type_up[_pos] ||
           _seed == type_down[_r] ||
           _seed == type_up[_r] ||
           _seed == type_down[_d] ||
           _seed == type_down[_dr] ||
           _seed == type_up[_dr])) {
        type_down[_pos] = _new;
      }
    }
  };

  /// Change water type based on closeness to shore.
  static change_shore_water_type = function() {
    seed_terrain_type(Terrain.water0, Terrain.grass1, Terrain.water3);
    seed_terrain_type(Terrain.water0, Terrain.water3, Terrain.water2);
    seed_terrain_type(Terrain.water0, Terrain.water2, Terrain.water1);
  };

  /// Change grass type of shore to TerrainGrass0.
  static change_shore_grass_type = function() {
    seed_terrain_type(Terrain.grass1, Terrain.water3, Terrain.grass0);
  };

  // ---------------------------------------------------------------------
  // Deserts
  // ---------------------------------------------------------------------

  /// Check whether large down-triangle is suitable for desert.
  static check_desert_down_triangle = function(_pos) {
    var _type_d = type_down[_pos];
    var _type_u = type_up[_pos];

    if (_type_d != Terrain.grass1 && _type_d != Terrain.desert2) {
      return false;
    }
    if (_type_u != Terrain.grass1 && _type_u != Terrain.desert2) {
      return false;
    }

    _type_d = type_down[map.geom.move_left(_pos)];
    if (_type_d != Terrain.grass1 && _type_d != Terrain.desert2) {
      return false;
    }

    _type_d = type_down[map.geom.move_down(_pos)];
    if (_type_d != Terrain.grass1 && _type_d != Terrain.desert2) {
      return false;
    }

    return true;
  };

  /// Check whether large up-triangle is suitable for desert.
  static check_desert_up_triangle = function(_pos) {
    var _type_d = type_down[_pos];
    var _type_u = type_up[_pos];

    if (_type_d != Terrain.grass1 && _type_d != Terrain.desert2) {
      return false;
    }
    if (_type_u != Terrain.grass1 && _type_u != Terrain.desert2) {
      return false;
    }

    _type_u = type_up[map.geom.move_right(_pos)];
    if (_type_u != Terrain.grass1 && _type_u != Terrain.desert2) {
      return false;
    }

    _type_u = type_up[map.geom.move_up(_pos)];
    if (_type_u != Terrain.grass1 && _type_u != Terrain.desert2) {
      return false;
    }

    return true;
  };

  /// Create deserts.
  static create_deserts = function() {
    // Initialize random areas of desert based on spiral pattern.
    // Only TerrainGrass1 triangles will be converted to desert.
    var _regions = map.regions;
    for (var _i = 0; _i < _regions; _i++) {
      for (var _try = 0; _try < 200; _try++) {
        var _rnd_pos = get_rnd_coord();

        if (type_up[_rnd_pos] == Terrain.grass1 &&
            type_down[_rnd_pos] == Terrain.grass1) {
          for (var _index = 255; _index >= 0; _index--) {
            var _pos = pos_add_spirally(_rnd_pos, _index);

            if (check_desert_down_triangle(_pos)) {
              type_up[_pos] = Terrain.desert2;
            }

            if (check_desert_up_triangle(_pos)) {
              type_down[_pos] = Terrain.desert2;
            }
          }
          break;
        }
      }
    }

    // Convert outer triangles in the desert areas into a gradual transition
    // through TerrainGrass3, TerrainDesert0, TerrainDesert1 to
    // TerrainDesert2.
    seed_terrain_type(Terrain.desert2, Terrain.grass1, Terrain.grass3);
    seed_terrain_type(Terrain.desert2, Terrain.grass3, Terrain.desert0);
    seed_terrain_type(Terrain.desert2, Terrain.desert0, Terrain.desert1);

    // Convert all triangles in the TerrainGrass3 - TerrainDesert1 range to
    // TerrainGrass1. This reduces the size of the desert areas to the core
    // that was made up of TerrainDesert2.
    for (var _pos = 0; _pos < tile_count; _pos++) {
      var _type_d = type_down[_pos];
      var _type_u = type_up[_pos];

      if (_type_d >= Terrain.grass3 && _type_d <= Terrain.desert1) {
        type_down[_pos] = Terrain.grass1;
      }
      if (_type_u >= Terrain.grass3 && _type_u <= Terrain.desert1) {
        type_up[_pos] = Terrain.grass1;
      }
    }

    // Restore the gradual transition from TerrainGrass3 to TerrainDesert2
    // around the desert.
    seed_terrain_type(Terrain.grass1, Terrain.desert2, Terrain.desert1);
    seed_terrain_type(Terrain.grass1, Terrain.desert1, Terrain.desert0);
    seed_terrain_type(Terrain.grass1, Terrain.desert0, Terrain.grass3);
  };

  // ---------------------------------------------------------------------
  // Objects
  // ---------------------------------------------------------------------

  /// Put crosses on top of mountains.
  static create_crosses = function() {
    for (var _pos = 0; _pos < tile_count; _pos++) {
      var _h = height[_pos];
      if (_h >= 26 &&
          _h >= height[map.geom.move_right(_pos)] &&
          _h >= height[map.geom.move_down_right(_pos)] &&
          _h >= height[map.geom.move_down(_pos)] &&
          _h > height[map.geom.move_left(_pos)] &&
          _h > height[map.geom.move_up_left(_pos)] &&
          _h > height[map.geom.move_up(_pos)]) {
        obj[_pos] = MapObject.cross;
      }
    }
  };

  /// Check that hexagon has tile types in range.
  ///
  /// NOTE: This function has a quirk which is enabled by preserve_bugs. When
  /// this quirk is enabled, one of the tiles that is checked is not in the
  /// hexagon but is instead an adjacent tile. This is necessary to generate
  /// original game maps.
  static hexagon_types_in_range = function(_pos, _min, _max) {
    var _type_d = type_down[_pos];
    var _type_u = type_up[_pos];

    if (_type_d < _min || _type_d > _max) {
      return false;
    }
    if (_type_u < _min || _type_u > _max) {
      return false;
    }

    _type_d = type_down[map.geom.move_left(_pos)];
    if (_type_d < _min || _type_d > _max) {
      return false;
    }

    _type_d = type_down[map.geom.move_up_left(_pos)];
    _type_u = type_up[map.geom.move_up_left(_pos)];
    if (_type_d < _min || _type_d > _max) {
      return false;
    }
    if (_type_u < _min || _type_u > _max) {
      return false;
    }

    /* Should be checking the up tri type. */
    if (preserve_bugs) {
      _type_d = type_down[map.geom.move_up(_pos)];
      if (_type_d < _min || _type_d > _max) {
        return false;
      }
    } else {
      _type_u = type_up[map.geom.move_up(_pos)];
      if (_type_u < _min || _type_u > _max) {
        return false;
      }
    }

    return true;
  };

  /// Get a random position in the spiral pattern based at col, row.
  static pos_add_spirally_random = function(_pos, _mask) {
    return pos_add_spirally(_pos, random_int() & _mask);
  };

  /// Create clusters of map objects.
  static create_random_object_clusters = function(_num_clusters,
      _objs_in_cluster, _pos_mask, _type_min, _type_max, _obj_base,
      _obj_mask) {
    for (var _i = 0; _i < _num_clusters; _i++) {
      for (var _try = 0; _try < 100; _try++) {
        var _rnd_pos = get_rnd_coord();
        if (hexagon_types_in_range(_rnd_pos, _type_min, _type_max)) {
          for (var _j = 0; _j < _objs_in_cluster; _j++) {
            var _pos = pos_add_spirally_random(_rnd_pos, _pos_mask);
            if (hexagon_types_in_range(_pos, _type_min, _type_max) &&
                obj[_pos] == MapObject.none) {
              obj[_pos] = (random_int() & _obj_mask) + _obj_base;
            }
          }
          break;
        }
      }
    }
  };

  static create_objects = function() {
    var _regions = map.regions;

    create_crosses();

    // Add either tree or pine.
    create_random_object_clusters(
      _regions * 8, 10, 0xff, Terrain.grass1, Terrain.grass2,
      MapObject.tree0, 0xf);

    // Add only trees.
    create_random_object_clusters(
      _regions, 45, 0x3f, Terrain.grass1, Terrain.grass2,
      MapObject.tree0, 0x7);

    // Add only pines.
    create_random_object_clusters(
      _regions, 30, 0x3f, Terrain.grass0, Terrain.grass2,
      MapObject.pine0, 0x7);

    // Add either tree or pine.
    create_random_object_clusters(
      _regions, 20, 0x7f, Terrain.grass1, Terrain.grass2,
      MapObject.tree0, 0xf);

    // Create dense clusters of stone.
    create_random_object_clusters(
      _regions, 40, 0x3f, Terrain.grass1, Terrain.grass2,
      MapObject.stone0, 0x7);

    // Create sparse clusters.
    create_random_object_clusters(
      _regions, 15, 0xff, Terrain.grass1, Terrain.grass2,
      MapObject.stone0, 0x7);

    // Create dead trees.
    create_random_object_clusters(
      _regions, 2, 0xff, Terrain.grass1, Terrain.grass2,
      MapObject.dead_tree, 0);

    // Create sandstone boulders.
    create_random_object_clusters(
      _regions, 6, 0xff, Terrain.grass1, Terrain.grass2,
      MapObject.sandstone0, 0x1);

    // Create trees submerged in water.
    create_random_object_clusters(
      _regions, 50, 0x7f, Terrain.water2, Terrain.water3,
      MapObject.water_tree0, 0x3);

    // Create tree stubs.
    create_random_object_clusters(
      _regions, 5, 0xff, Terrain.grass1, Terrain.grass2,
      MapObject.stub, 0);

    // Create small boulders.
    create_random_object_clusters(
      _regions, 10, 0xff, Terrain.grass1, Terrain.grass2,
      MapObject.stone, 0x1);

    // Create animal cadavers in desert.
    create_random_object_clusters(
      _regions, 2, 0xf, Terrain.desert2, Terrain.desert2,
      MapObject.cadaver0, 0x1);

    // Create cacti in desert.
    create_random_object_clusters(
      _regions, 6, 0x7f, Terrain.desert0, Terrain.desert2,
      MapObject.cactus0, 0x1);

    // Create boulders submerged in water.
    create_random_object_clusters(
      _regions, 8, 0x7f, Terrain.water0, Terrain.water2,
      MapObject.water_stone0, 0x1);

    // Create palm trees in desert.
    create_random_object_clusters(
      _regions, 6, 0x3f, Terrain.desert2, Terrain.desert2,
      MapObject.palm0, 0x3);
  };

  // ---------------------------------------------------------------------
  // Minerals
  // ---------------------------------------------------------------------

  /// Expand a cluster of minerals. C++ passes `index` by pointer; here the
  /// updated index is returned.
  static expand_mineral_cluster = function(_iters, _init_pos, _index,
                                           _amount, _type) {
    for (var _i = 0; _i < _iters; _i++) {
      var _pos = pos_add_spirally(_init_pos, _index);
      _index += 1;

      if (mineral[_pos] == Minerals.none ||
          res_amount[_pos] < _amount) {
        mineral[_pos] = _type;
        res_amount[_pos] = _amount;
      }
    }
    return _index;
  };

  /// Create random clusters of mineral deposits.
  static create_random_mineral_clusters = function(_num_clusters, _type,
                                                   _min, _max) {
    var _iterations = [1, 6, 12, 18, 24, 30];

    for (var _i = 0; _i < _num_clusters; _i++) {
      for (var _try = 0; _try < 100; _try++) {
        var _pos = get_rnd_coord();

        if (hexagon_types_in_range(_pos, _min, _max)) {
          var _index = 0;
          var _count = 2 + ((random_int() >> 2) & 3);

          for (var _j = 0; _j < _count; _j++) {
            var _amount = 4 * (_count - _j);
            _index = expand_mineral_cluster(_iterations[_j], _pos, _index,
                                            _amount, _type);
          }

          break;
        }
      }
    }
  };

  /// Initialize mineral deposits in the ground.
  static create_mineral_deposits = function() {
    // { mult, mineral }
    var _deposits = [
      [9, Minerals.coal],
      [4, Minerals.iron],
      [2, Minerals.gold],
      [2, Minerals.stone]
    ];

    var _regions = map.regions;

    for (var _i = 0; _i < 4; _i++) {
      var _mult = _deposits[_i][0];
      var _mineral = _deposits[_i][1];
      create_random_mineral_clusters(_regions * _mult, _mineral,
                                     Terrain.tundra0, Terrain.snow0);
    }
  };

  // ---------------------------------------------------------------------
  // Clean up
  // ---------------------------------------------------------------------

  static clean_up = function() {
    /* Make sure that it is always possible to walk around
       any impassable objects. This also clears water obstacles
       except in certain positions near the shore. */
    for (var _pos = 0; _pos < tile_count; _pos++) {
      if (map_space_from_obj[obj[_pos]] >= Space.impassable) {
        // Due to a quirk in the original game the three adjacent positions
        // were not checked directly whether they were impassable but
        // instead another flag was used to mark the position impassable.
        // This flag was only initialzed for water positions before this
        // loop and was initialized as part of this same loop for non-water
        // positions. For this reason, the check for impassable spaces would
        // never succeed under two particular conditions at the map edge:
        // 1) x == 0 && d == DirectionLeft
        // 2) y == 0 && (d == DirectionUp || d == DirectionUpLeft)
        // cycle_directions_cw(DirectionLeft, 3): left, up_left, up
        for (var _d = Direction.left; _d <= Direction.up; _d++) {
          var _other_pos = map.geom.move(_pos, _d);
          var _s = map_space_from_obj[obj[_other_pos]];

          var _check_impassable = false;
          if (!(map.geom.pos_col(_pos) == 0 && _d == Direction.left) &&
              !((_d == Direction.up || _d == Direction.up_left) &&
                map.geom.pos_row(_pos) == 0)) {
            _check_impassable = (_s >= Space.impassable);
          }

          if (is_in_water(_other_pos) || _check_impassable) {
            obj[_pos] = MapObject.none;
            break;
          }
        }
      }
    }
  };
}

/// Classic map generator that generates identical maps for missions.
/// C++: ClassicMissionMapGenerator::init() calls
/// ClassicMapGenerator::init(HeightGeneratorMidpoints, true) with defaults.
function ClassicMissionMapGenerator(_map, _rnd) : ClassicMapGenerator(_map, _rnd) constructor {
  static init = function() {
    height_generator = HeightGenerator.midpoints;
    preserve_bugs = true;
    max_lake_area = CLASSIC_MAP_GEN_DEFAULT_MAX_LAKE_AREA;
    water_level = CLASSIC_MAP_GEN_DEFAULT_WATER_LEVEL;
    terrain_spikyness = CLASSIC_MAP_GEN_DEFAULT_TERRAIN_SPIKYNESS;
  };
}
