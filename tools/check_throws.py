#!/usr/bin/env python3
"""Nothing in the game scripts may throw.

Freeserf is written with assertions in it, and this port inherited them. In C++
an assertion ends a process that a developer is running; in GML an uncaught
throw ends the session of a player who was forty minutes into a game, and takes
their settlement with it. Every one of them has been replaced by fault_note()
plus the most conservative recovery available - skip the draw, clamp the
counter, leave the loop, lose the one item - so the game carries on and the
crash report, if something else does end the session, arrives with the last
dozen faults in it.

That sweep is only worth doing once. This is what stops the next port of a
Freeserf function quietly bringing its `throw` along with it.

If you are here because this failed on a line you just wrote: the answer is
almost never a throw. Decide what the smallest survivable outcome is, do that,
and call fault_note("area.thing.what", "the numbers") on the way past. See
scripts/scr_fault/scr_fault.gml.

Usage: python3 tools/check_throws.py [repo root]
Exit status 1 if anything is found, so it can go in a pre-commit hook.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gml_scan import blank_comments, gml_files, line_of

THROW = re.compile(r'\bthrow\b')


def check(root):
    found = 0

    for path in gml_files(root):
        with open(path, encoding='utf-8') as handle:
            clean = blank_comments(handle.read())

        for match in THROW.finditer(clean):
            found += 1
            rel = os.path.relpath(path, root)
            print(f'{rel}:{line_of(clean, match.start())}: throws - an '
                  f'uncaught throw ends the player\'s session; call '
                  f'fault_note() and recover instead')

    if found == 0:
        print('nothing in the game scripts throws')
    return found


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sys.exit(1 if check(root) > 0 else 0)
