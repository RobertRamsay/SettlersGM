// scr_random.gml - Random number generator
// Ported from Freeserf (GPL-3.0), original copyright (C) 2012-2013
// Jon Lund Steffensen <jonlst@gmail.com>. Ports src/random.h and
// src/random.cc (Random class, lines 27-110 of random.cc).
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// All three state words are 16-bit unsigned in the original; every store
// into state[] is masked with & 0xFFFF to emulate uint16_t wraparound.

/// @function RandomState(_s0, _s1, _s2)
/// @desc Port of Random(uint16_t base_0, uint16_t base_1, uint16_t base_2).
function RandomState(_s0, _s1, _s2) constructor {
    state = array_create(3, 0);
    state[0] = _s0 & 0xFFFF;
    state[1] = _s1 & 0xFFFF;
    state[2] = _s2 & 0xFFFF;

    /// @desc Port of Random::random(). Returns a 16-bit value.
    static next_random = function() {
        var _r = ((state[0] + state[1]) ^ state[2]) & 0xFFFF;
        state[2] = (state[2] + state[1]) & 0xFFFF;
        state[1] = (state[1] ^ state[2]) & 0xFFFF;
        state[1] = (state[1] >> 1) | ((state[1] << 15) & 0xFFFF);
        state[2] = (state[2] >> 1) | ((state[2] << 15) & 0xFFFF);
        state[0] = _r;
        return _r;
    };
}

/// @function random_state_from_seed(value)
/// @desc Port of Random(const uint16_t &value): all three words = value.
function random_state_from_seed(value) {
    return new RandomState(value, value, value);
}

/// @function random_state_copy(rnd)
/// @desc Port of the copy constructor Random(const Random &random_state).
function random_state_copy(rnd) {
    return new RandomState(rnd.state[0], rnd.state[1], rnd.state[2]);
}

/// @function random_state_from_string(str)
/// @desc Port of Random(const std::string &string). The string is 16
///       characters in '1'..'8', each encoding 3 bits, least significant
///       group first.
function random_state_from_string(str) {
    var _tmp = 0;

    for (var _i = 15; _i >= 0; _i--) {
        _tmp = _tmp << 3;
        // uint8_t c = string[i] - '0' - 1;  (GML strings are 1-indexed)
        var _c = (ord(string_char_at(str, _i + 1)) - 48 - 1) & 0xFF;
        _tmp = _tmp | _c;
    }

    var _s0 = _tmp & 0xFFFF;
    _tmp = _tmp >> 16;
    var _s1 = _tmp & 0xFFFF;
    _tmp = _tmp >> 16;
    var _s2 = _tmp & 0xFFFF;

    return new RandomState(_s0, _s1, _s2);
}

/// @function random_state_to_string(rnd)
/// @desc Port of Random::operator std::string(). Returns a 16-character
///       string of '1'..'8'.
function random_state_to_string(rnd) {
    var _tmp0 = rnd.state[0];
    var _tmp1 = rnd.state[1];
    var _tmp2 = rnd.state[2];

    var _tmp = _tmp0;
    _tmp = _tmp | (_tmp1 << 16);
    _tmp = _tmp | (_tmp2 << 32);

    var _result = "";
    for (var _i = 0; _i < 16; _i++) {
        var _c = _tmp & 0x07;
        _c += 49; // '1'
        _result += chr(_c);
        _tmp = _tmp >> 3;
    }

    return _result;
}

/// @function random_state_xor(left, right)
/// @desc Port of operator^=(Random& left, const Random& right).
///       Modifies left in place and returns it.
function random_state_xor(left, right) {
    left.state[0] = (left.state[0] ^ right.state[0]) & 0xFFFF;
    left.state[1] = (left.state[1] ^ right.state[1]) & 0xFFFF;
    left.state[2] = (left.state[2] ^ right.state[2]) & 0xFFFF;
    return left;
}
