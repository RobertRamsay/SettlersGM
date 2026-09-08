#!/usr/bin/env python3
"""Nothing may index the animation counter table directly.

global.serf_counter_from_animation is indexed with a number computed from live
game state - a direction, a height difference, a packed state variable - at
several points per serf per frame. In GML an out-of-range array read is not a
wrong sprite, it is the end of the session, so a fault anywhere upstream lands
here as a crash with somebody's game in it.

That is not hypothetical. A transporter woken off an idle path carried a
walking_dir of 259, because the direction parked in the low byte of `tick` was
read back without sign-extending it; 110 + 259 = 369 was handed to a 181-entry
table, and a player lost their game to it.

serf_anim_counter() does the same lookup, reports an out-of-range animation
once per distinct value, and returns a usable default instead of dying. The
underlying bug still has to be found and fixed - the point is that finding it
should not cost somebody their afternoon.

Usage: python3 tools/check_anim_table.py [repo root]
Exit status 1 if anything is found, so it can go in a pre-commit hook.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gml_scan import blank_comments, gml_files, line_of

DIRECT_INDEX = re.compile(r'global\.serf_counter_from_animation\s*\[')


def check(root):
    found = 0

    for path in gml_files(root):
        with open(path, encoding='utf-8') as handle:
            clean = blank_comments(handle.read())

        for match in DIRECT_INDEX.finditer(clean):
            found += 1
            rel = os.path.relpath(path, root)
            print(f'{rel}:{line_of(clean, match.start())}: indexes the animation '
                  f'counter table directly - an out-of-range animation here ends '
                  f'the session; call serf_anim_counter(animation) instead')

    if found == 0:
        print('animation counter table is only read through serf_anim_counter')
    return found


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sys.exit(1 if check(root) > 0 else 0)
