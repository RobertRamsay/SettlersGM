// scr_pathfinder.gml - Ported from Freeserf src/pathfinder.h and
// src/pathfinder.cc (GPL-3.0), original copyright (C) 2012-2014
// Jon Lund Steffensen <jonlst@gmail.com>.
//
// freeserf is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// A* road search between two map positions. The open list is kept as a
// binary max-heap (on "less" = larger f_score) using a manual, exact
// replica of libstdc++'s std::push_heap / std::pop_heap / std::make_heap
// so that the pop order (and therefore the resulting road) is identical
// to the C++ build.

/// SearchNode (pathfinder.cc lines 33-47).
function PathfinderSearchNode() constructor {
    parent = undefined;
    g_score = 0;
    f_score = 0;
    pos = 0;
    dir = Direction.none;
}

/// search_node_less(left, right): a node is "less" when it has a larger
/// f-score so the smallest f-score goes to the top of the max-heap.
function pathfinder_search_node_less(_left, _right) {
    return (_left.f_score > _right.f_score);
}

function pathfinder_init_tables() {
    if (variable_global_exists("pathfinder_walk_cost")) {
        return;
    }
    global.pathfinder_walk_cost = [255, 319, 383, 447, 511];
}

/// heuristic_cost(map, start, end)
function pathfinder_heuristic_cost(_map, _start, _end) {
    /* Calculate distance to target. */
    var _dist_col = _map.dist_x(_start, _end);
    var _dist_row = _map.dist_y(_start, _end);

    var _h_diff = abs(_map.get_height(_start) - _map.get_height(_end));
    var _dist = 0;

    if ((_dist_col > 0 && _dist_row > 0) ||
        (_dist_col < 0 && _dist_row < 0)) {
        _dist = max(abs(_dist_col), abs(_dist_row));
    } else {
        _dist = abs(_dist_col) + abs(_dist_row);
    }

    if (_dist > 0) {
        return _dist * global.pathfinder_walk_cost[_h_diff div _dist];
    }
    return 0;
}

/// actual_cost(map, pos, dir)
function pathfinder_actual_cost(_map, _pos, _dir) {
    var _other_pos = _map.move(_pos, _dir);
    var _h_diff = abs(_map.get_height(_pos) - _map.get_height(_other_pos));
    return global.pathfinder_walk_cost[_h_diff];
}

// ---------------------------------------------------------------------------
// libstdc++ heap primitives (bits/stl_heap.h), specialised for the
// search_node_less comparator. `_open` is a GML array (by reference).
// ---------------------------------------------------------------------------

/// std::__push_heap(first, holeIndex, topIndex, value, comp)
function pathfinder_heap_push_hole(_open, _hole_index, _top_index, _value) {
    var _parent = (_hole_index - 1) div 2;
    while (_hole_index > _top_index &&
           pathfinder_search_node_less(_open[_parent], _value)) {
        _open[@ _hole_index] = _open[_parent];
        _hole_index = _parent;
        _parent = (_hole_index - 1) div 2;
    }
    _open[@ _hole_index] = _value;
}

/// std::__adjust_heap(first, holeIndex, len, value, comp)
function pathfinder_heap_adjust(_open, _hole_index, _len, _value) {
    var _top_index = _hole_index;
    var _second_child = _hole_index;
    while (_second_child < ((_len - 1) div 2)) {
        _second_child = 2 * (_second_child + 1);
        if (pathfinder_search_node_less(_open[_second_child],
                                        _open[_second_child - 1])) {
            _second_child -= 1;
        }
        _open[@ _hole_index] = _open[_second_child];
        _hole_index = _second_child;
    }
    if (((_len & 1) == 0) && (_second_child == ((_len - 2) div 2))) {
        _second_child = 2 * (_second_child + 1);
        _open[@ _hole_index] = _open[_second_child - 1];
        _hole_index = _second_child - 1;
    }
    pathfinder_heap_push_hole(_open, _hole_index, _top_index, _value);
}

/// std::push_heap(first, last, comp): the new element is already at the back.
function pathfinder_push_heap(_open) {
    var _len = array_length(_open);
    var _value = _open[_len - 1];
    pathfinder_heap_push_hole(_open, _len - 1, 0, _value);
}

/// std::pop_heap(first, last, comp): moves the top element to the back.
function pathfinder_pop_heap(_open) {
    var _len = array_length(_open);
    if (_len > 1) {
        var _result = _len - 1;
        var _value = _open[_result];
        _open[@ _result] = _open[0];
        pathfinder_heap_adjust(_open, 0, _result, _value);
    }
}

/// std::make_heap(first, last, comp)
function pathfinder_make_heap(_open) {
    var _len = array_length(_open);
    if (_len < 2) {
        return;
    }
    var _parent = (_len - 2) div 2;
    while (true) {
        var _value = _open[_parent];
        pathfinder_heap_adjust(_open, _parent, _len, _value);
        if (_parent == 0) {
            return;
        }
        _parent -= 1;
    }
}

/// Find the shortest path from start to end (using A*) considering that
/// the walking time for a serf walking in any direction of the path
/// should be minimized. Returns a Road (struct from scr_interface.gml);
/// an invalid Road (is_valid() == false) when no path exists.
/// _building_road is optional (undefined = nullptr).
///
/// _owner and _max_nodes are additions for the AI, and both optional; the
/// player's own road clicks pass neither and search exactly as Freeserf does.
///
///   _owner      a player index. Only ground that player owns is entered.
///               build_road refuses any road with a step off the builder's
///               land anyway, so this loses nothing the AI could have built -
///               and it may find an owned detour the plain shortest path
///               would have missed.
///   _max_nodes  give up (no road) after expanding this many positions.
///
/// Without them a target that cannot be reached - across water, behind an
/// enemy border - made the search flood every walkable position on the map
/// before answering no, about a second of frozen game on a big map, and
/// ai_repair_roads used to ask that question for every orphaned flag at
/// every decision (the regular 1.2.3 freeze).
function pathfinder_map(_map, _start, _end, _building_road, _owner = undefined,
                        _max_nodes = undefined) {
    pathfinder_init_tables();

    // _building_road may be omitted by the caller (then it is undefined).

    if (_owner != undefined) {
        if (!_map.has_owner(_start) || _map.get_owner(_start) != _owner ||
            !_map.has_owner(_end) || _map.get_owner(_end) != _owner) {
            return new Road();
        }
    }

    // Open list kept heapified with the manual heap primitives above.
    var _open = [];
    // Membership only: iteration order is never used. Keep the original
    // open heap and score-update operations, including all tie-breaking.
    var _closed = {};
    // pos -> the node for it in _open. A position is in _open at most once,
    // so this answers "is it open, and with what score" without the linear
    // scan; the scan below now only runs to find the heap slot of a node
    // whose score actually improves, so the heap operations - and the road
    // that comes out - are unchanged.
    var _open_set = {};
    var _expanded = 0;

    /* Create start node */
    var _node = new PathfinderSearchNode();
    _node.pos = _end;
    _node.g_score = 0;
    _node.f_score = pathfinder_heuristic_cost(_map, _start, _end);

    array_push(_open, _node);
    _open_set[$ string(_node.pos)] = _node;

    while (array_length(_open) > 0) {
        pathfinder_pop_heap(_open);
        _node = _open[array_length(_open) - 1];
        array_pop(_open);
        variable_struct_remove(_open_set, string(_node.pos));

        if (_node.pos == _start) {
            /* Construct solution */
            var _solution = new Road();
            _solution.start(_start);

            while (_node.parent != undefined) {
                var _dir = _node.dir;
                _solution.extend(reverse_direction(_dir));
                _node = _node.parent;
            }

            return _solution;
        }

        if (_max_nodes != undefined) {
            _expanded += 1;
            if (_expanded > _max_nodes) {
                break;
            }
        }

        /* Put current node on closed list. */
        _closed[$ string(_node.pos)] = true;

        // cycle_directions_cw(): DirectionRight .. DirectionUp
        for (var _d = Direction.right; _d <= Direction.up; _d++) {
            var _new_pos = _map.move(_node.pos, _d);
            var _cost = pathfinder_actual_cost(_map, _node.pos, _d);

            /* Check if neighbour is valid. */
            if (!_map.is_road_segment_valid(_node.pos, _d) ||
                (_map.get_obj(_new_pos) == MapObject.flag && _new_pos != _start)) {
                continue;
            }

            if ((_building_road != undefined) && _building_road.has_pos(_map, _new_pos) &&
                (_new_pos != _end) && (_new_pos != _start)) {
                continue;
            }

            if (_owner != undefined &&
                (!_map.has_owner(_new_pos) || _map.get_owner(_new_pos) != _owner)) {
                continue;
            }

            /* Check if neighbour is in closed list. */
            var _key = string(_new_pos);
            if (variable_struct_exists(_closed, _key)) {
                continue;
            }

            /* See if neighbour is already in open list. */
            var _open_node = _open_set[$ _key];
            var _in_open = (_open_node != undefined);
            if (_in_open && _open_node.g_score >= _node.g_score + _cost) {
                _open_node.g_score = _node.g_score + _cost;
                _open_node.f_score = _open_node.g_score +
                                     pathfinder_heuristic_cost(_map, _new_pos, _start);
                _open_node.parent = _node;
                _open_node.dir = _d;

                // Move element to the back and heapify
                // (iter_swap(it, open.rbegin()); make_heap). The slot is
                // only needed here, so only here is it looked for.
                var _open_len = array_length(_open);
                for (var _it = 0; _it < _open_len; _it++) {
                    if (_open[_it] == _open_node) {
                        var _last = _open_len - 1;
                        var _tmp = _open[_last];
                        _open[_last] = _open[_it];
                        _open[_it] = _tmp;
                        break;
                    }
                }
                pathfinder_make_heap(_open);
            }

            /* If not found in the open set, create a new node. */
            if (!_in_open) {
                var _new_node = new PathfinderSearchNode();

                _new_node.pos = _new_pos;
                _new_node.g_score = _node.g_score + _cost;
                _new_node.f_score = _new_node.g_score +
                                    pathfinder_heuristic_cost(_map, _new_pos, _start);
                _new_node.parent = _node;
                _new_node.dir = _d;

                array_push(_open, _new_node);
                pathfinder_push_heap(_open);
                _open_set[$ _key] = _new_node;
            }
        }
    }

    return new Road();
}
