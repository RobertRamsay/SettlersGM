/// scr_fault.gml - what the port does instead of throwing.
///
/// Freeserf is written with assertions in it. When the simulation reaches a
/// state its author believed impossible - a serf index in a queue that no
/// longer exists, a resource delivered to a building with no slot for it, a
/// switch reaching a building type it has no case for - it throws, and the
/// C++ ends the process.
///
/// In GML an uncaught throw ends the session, and there is a person on the
/// other side of it who was forty minutes into a game. That trade is wrong in
/// both directions: the assertion is right that something has gone wrong, and
/// wrong that the right answer is to take the game away. A player who loses a
/// settlement to a bookkeeping mismatch cannot tell us anything; a player whose
/// game carried on with one plank in the wrong place can.
///
/// So every one of those throws now calls fault_note() and carries on with the
/// most conservative thing available - skip the draw, clamp the counter, leave
/// the loop, lose the one item. What is lost is always small and always local.
/// What is gained is that the game keeps running and the crash report, when
/// something DOES end the session, arrives with the last dozen of these in it -
/// which is usually the story of what went wrong, told in order.
///
/// Three rules for anything added here:
///
///   1. It must never throw. It is the thing that runs when something has
///      already gone wrong.
///   2. It must be cheap when nothing is wrong, which it is: nothing calls it
///      unless a fault has actually happened.
///   3. A fault that repeats every frame must not fill the log with itself, so
///      each SITE is written out once and counted after that.

/// How many recent faults the crash report carries.
#macro FAULT_KEEP 12

/// Set up before anything can report one. Called from obj_game Create.
function fault_init() {
    /* One entry per distinct site: { site, count }. A linear scan, because
       there are a few dozen sites in the whole game and this is only touched
       when something has gone wrong. */
    global.fault_sites = [];

    /* The last FAULT_KEEP faults, newest last, for the crash report. */
    global.fault_recent = [];

    global.fault_total = 0;

    /* Whose tick numbers to stamp them with. undefined until a game starts. */
    global.fault_game = undefined;
}

/// Something the simulation believed impossible has happened.
///
/// _site  is where, as a short stable string - it is the key the repeat count
///        is kept under, so it must not have a tick or an index in it.
/// _detail is everything that varies: indexes, types, positions.
///
/// Returns nothing. The caller carries on with whatever recovery it chose,
/// which is the important half - this only writes it down.
function fault_note(_site, _detail) {
    global.fault_total += 1;

    /* Have we said this one before? */
    var _n = array_length(global.fault_sites);
    var _seen = -1;
    for (var _i = 0; _i < _n; _i++) {
        if (global.fault_sites[_i].site == _site) {
            _seen = _i;
            break;
        }
    }

    if (_seen < 0) {
        array_push(global.fault_sites, { site: _site, count: 1 });
        show_debug_message("fault: " + string(_site) + " - " + string(_detail));
    } else {
        global.fault_sites[_seen].count += 1;
        /* Powers of two after the first, so a fault that happens every frame
           leaves a trail of how bad it got without being the whole log. */
        var _count = global.fault_sites[_seen].count;
        if ((_count & (_count - 1)) == 0) {
            show_debug_message("fault: " + string(_site) + " (x" +
                               string(_count) + ") - " + string(_detail));
        }
    }

    /* The ring for the crash report. Tick where there is one: the ordering of
       these against each other is most of what makes them readable. */
    var _tick = -1;
    if (global.fault_game != undefined) {
        _tick = global.fault_game.get_tick();
    }

    array_push(global.fault_recent, {
        site: _site,
        detail: string(_detail),
        tick: _tick
    });
    while (array_length(global.fault_recent) > FAULT_KEEP) {
        array_delete(global.fault_recent, 0, 1);
    }
}

/// The game the tick numbers come from. Set when a game starts and cleared when
/// it goes, so fault_note never has to reach through the interface - which may
/// be mid-rebuild at exactly the moment a fault is reported.
function fault_set_game(_game) {
    global.fault_game = _game;
}

/// How many faults this session has seen, and how many distinct sites.
function fault_summary() {
    return string(global.fault_total) + " faults from " +
           string(array_length(global.fault_sites)) + " places";
}

/// The block the crash report carries: every site with its count, then the last
/// FAULT_KEEP in the order they happened.
function fault_report() {
    if (global.fault_total == 0) {
        return "";
    }

    var _out = fault_summary() + "\n";

    var _n = array_length(global.fault_sites);
    for (var _i = 0; _i < _n; _i++) {
        _out += "  " + string(global.fault_sites[_i].count) + "x  " +
                string(global.fault_sites[_i].site) + "\n";
    }

    var _m = array_length(global.fault_recent);
    if (_m > 0) {
        _out += "last " + string(_m) + ", in order:\n";
        for (var _j = 0; _j < _m; _j++) {
            var _f = global.fault_recent[_j];
            _out += "  tick " + string(_f.tick) + "  " + string(_f.site) +
                    " - " + string(_f.detail) + "\n";
        }
    }

    return _out;
}
