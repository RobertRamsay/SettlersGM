#!/usr/bin/env python3
"""A serf's position may not be moved without telling the map.

Two things say where a serf is: his own `pos`, and the occupancy layer, which
names him on exactly one tile. They are written separately, so it is possible to
move one and not the other - and the map is the one the DRAW code reads.

That is not hypothetical either. serf_c had

    _serf.pos = map.move_left(pos_);

where Freeserf moves a local variable, and a knight who engaged an enemy
teleported one tile without the map hearing about it. The tile he had been
standing on went on naming him, so he was drawn there as well: a second knight
shadowboxing beside the real one, in step with him because it was the same serf
struct, dying with him because the tile then named somebody who was gone. Every
engagement left another one behind.

So: an assignment to a serf's `pos` must have a claim_serf_index or a
clear_serf_index within a few lines of it. That is what the legitimate moves all
look like - clear the tile being left, claim the one being taken, set pos - and
what the bug did not.

Two assignments are allowed to stand alone, both listed below: a serf being
constructed, and a serf being placed inside a building, where there is no tile
to claim because he is not on the map at all.

Usage: python3 tools/check_serf_pos.py [repo root]
Exit status 1 if anything is found, so it can go in a pre-commit hook.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gml_scan import blank_comments, gml_files

# A line that is an assignment to `pos` or `<something>.pos`, and not a
# comparison. Matched a line at a time so that what is reported is the line the
# assignment is actually on.
POS_WRITE = re.compile(r'^\s*(?:\w+\.)?pos\s*=\s*[^=]')

# How far either side of the assignment the map bookkeeping may sit. Twenty,
# because the serf-swap in scr_serf_b does both serfs' bookkeeping first, then
# the animations, and only then the two positions - fourteen lines apart. The
# bug this exists to catch has no bookkeeping anywhere in its function, so a
# window this wide still finds it.
WINDOW = 20

# Assignments that do not touch the map because the serf is not on it.
ALLOWED = {
    ('scr_serf.gml', 'pos = -1;'),                        # the constructor
    ('scr_serf.gml', 'pos = _building.get_position();'),  # placed inside a building
}

BOOKKEEPING = ('claim_serf_index', 'clear_serf_index', 'clear_tile_occupancy',
               'relayer_serf')


def check(root):
    found = 0

    for path in gml_files(root):
        rel = os.path.relpath(path, root)
        name = os.path.basename(path)
        if not name.startswith('scr_serf'):
            continue

        with open(path, encoding='utf-8') as handle:
            clean = blank_comments(handle.read())
        lines = clean.splitlines()

        for number, line in enumerate(lines, 1):
            if not POS_WRITE.match(line):
                continue
            text = line.strip()
            if (name, text) in ALLOWED:
                continue

            lo = max(0, number - 1 - WINDOW)
            hi = min(len(lines), number + WINDOW)
            near = '\n'.join(lines[lo:hi])
            if any(call in near for call in BOOKKEEPING):
                continue

            found += 1
            print(f'{rel}:{number}: moves a serf without telling the map - '
                  f'`{text}` has no claim_serf_index or clear_serf_index near '
                  f'it, so the tile he is leaving will go on naming him')

    if found == 0:
        print('every serf position change tells the map')
    return found


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sys.exit(1 if check(root) > 0 else 0)
