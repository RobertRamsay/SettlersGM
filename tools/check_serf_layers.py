#!/usr/bin/env python3
"""Guard the two map occupancy layers (see MAP_KNIGHTS_PHANTOM in scr_map.gml).

The map keeps serfs on one of two per-tile arrays: `serf` for everyone who
obstructs traffic, `knight` for knights, who do not. Which one a serf belongs
on follows from his type, so the only safe way to write a tile is to hand the
map the serf itself and let it choose - claim_serf_index / clear_serf_index.

The old Map.set_serf_index took a bare index and could not choose. It has been
removed rather than deprecated so that a missed call site fails to compile, but
that only protects the calls that exist today. This checker covers what the
compiler cannot:

  1. Nothing outside scr_map.gml writes map.serf[] or map.knight[] directly.
     Those arrays are the map's own business; a direct write skips the layer
     choice and the "only clear an entry that names this serf" rule, which is
     what stops one serf wiping a tile another is standing on.

  2. No set_serf_index survives anywhere, including in a comment that would
     send a future reader looking for a function that is gone.

  3. Serf movement code asks blocked_for(serf, pos) rather than has_serf(pos).
     has_serf means "a NON-KNIGHT is here", which is the right question for a
     transporter and the wrong one for a knight, so a movement test written in
     terms of it works for most serfs and quietly fails for knights - the kind
     of bug that only shows up as a knight walking through a wall.

Usage: python3 tools/check_serf_layers.py [repo root]
Exit status 1 if anything is found, so it can go in a pre-commit hook.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gml_scan import blank_comments, gml_files, line_of

MAP_FILE = os.path.join('scripts', 'scr_map', 'scr_map.gml')

# Files whose has_serf() calls are movement tests and must be layer aware.
# The serf files are the ones with walking code in them.
MOVEMENT_FILES = {
    os.path.join('scripts', 'scr_serf', 'scr_serf.gml'),
    os.path.join('scripts', 'scr_serf_b', 'scr_serf_b.gml'),
    os.path.join('scripts', 'scr_serf_c', 'scr_serf_c.gml'),
}

DIRECT_WRITE = re.compile(r'(?<![\w.])(?:_?map|_map_st)\s*\.\s*(serf|knight)\s*\[[^\]]*\]\s*=')
OLD_SETTER = re.compile(r'\bset_serf_index\b')
BARE_HAS_SERF = re.compile(r'\.has_serf\s*\(')
BARE_GET_INDEX = re.compile(r'\.get_serf_index\s*\(')
# "the tile ahead is occupied, so ask its occupant to move" - the lookup has to
# come from the same layer the test did, or a knight blocked by a knight is
# handed the transporter sharing that tile and waits on it for ever.
BLOCKED_THEN_LOOKUP = re.compile(
    r'blocked_for\s*\([^)]*\)(?:[^\n]*\n){0,14}?[^\n]*?\bget_serf_at_pos\s*\(')


def check(root):
    found = 0

    for path in gml_files(root):
        rel = os.path.relpath(path, root)
        with open(path, encoding='utf-8') as handle:
            raw = handle.read()
        clean = blank_comments(raw)

        # 1: direct writes to either occupancy array
        if rel != MAP_FILE:
            for match in DIRECT_WRITE.finditer(clean):
                found += 1
                print(f'{rel}:{line_of(clean, match.start())}: writes map.'
                      f'{match.group(1)}[] directly - use claim_serf_index / '
                      f'clear_serf_index so the layer is chosen for you')

        # 2: the removed setter, in code OR in a comment
        for match in OLD_SETTER.finditer(raw):
            # scr_map.gml explains the removal, and the savegame normaliser is
            # allowed to talk about it.
            if rel == MAP_FILE:
                continue
            found += 1
            print(f'{rel}:{line_of(raw, match.start())}: mentions '
                  f'set_serf_index, which no longer exists')

        # 3: movement code must not ask has_serf or get_serf_index directly
        if rel in MOVEMENT_FILES:
            for match in BARE_HAS_SERF.finditer(clean):
                found += 1
                print(f'{rel}:{line_of(clean, match.start())}: has_serf() in '
                      f'movement code - it means "a non-knight is here", so it '
                      f'is wrong for knights; use blocked_for(serf, pos), '
                      f'has_any_serf(pos) or other_serf_at(serf, pos)')

            for match in BARE_GET_INDEX.finditer(clean):
                found += 1
                print(f'{rel}:{line_of(clean, match.start())}: get_serf_index() '
                      f'in movement code - it reads the ordinary layer only, so '
                      f'it never names a knight; use serf_is_at(pos, serf) or '
                      f'other_serf_at(serf, pos)')

        # 4: a lookup that follows a blocked_for test must use the same layer
        for match in BLOCKED_THEN_LOOKUP.finditer(clean):
            found += 1
            print(f'{rel}:{line_of(clean, match.start())}: get_serf_at_pos() '
                  f'shortly after blocked_for() - the test and the lookup must '
                  f'agree on the layer, or a blocked knight is handed whoever '
                  f'is on the ordinary layer and waits on the wrong serf; use '
                  f'get_blocker_at_pos(serf, pos)')

    if found == 0:
        print('serf occupancy layers look consistent')
    return found


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sys.exit(1 if check(root) > 0 else 0)
