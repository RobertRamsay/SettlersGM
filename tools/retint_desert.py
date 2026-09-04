#!/usr/bin/env python3
"""
retint_desert.py - make desert look like sand.

WHY
tri_spr sends desert (terrain 8-10) to ground tiles 24-31, and retint_terrain.py
centred that block on #995522 - a dark rock brown. Ground carrying cacti and
palms therefore reads as mountain, which is also why a geologist sent there
looks wrong: desert is not minable, so he samples nothing and walks home.

    desert flat (tile 28)  #995522 58%   <- rock brown, should be sand

This shifts the desert block two steps up the brown ramp so it reads as sand.
Tundra (tiles 8-15) and snow (16-23) are left exactly as they are.

WHAT THIS DOES NOT TOUCH
Tundra, snow, grass, and spr_path_baked. The baked paths draw from ground tiles
10-19 and are already correct, so they are left alone deliberately.

Usage, from the project root:
    python tools/retint_desert.py .
"""

import json
import os
import re
import sys

from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'

# Brightest to darkest, same ramp retint_terrain.py uses.
BROWN = [(0xFF, 0xDD, 0xBB), (0xDD, 0xAA, 0x77), (0xBB, 0x88, 0x55),
         (0x99, 0x55, 0x22), (0x77, 0x33, 0x00), (0x55, 0x22, 0x00)]

# ground tile -> centre on the ramp. Shading direction is preserved; both runs
# are simply shifted, so slopes still read the same way.
CENTRES = {}
for i, c in enumerate([3, 3, 2, 2, 1, 1, 0, 0]):      # desert, flat -> #ddaa77
    CENTRES[24 + i] = c

# Terrain only. spr_path_baked is deliberately absent.
TARGETS = ['spr_map_ground', 'spr_ground_up', 'spr_ground_down']
GROUND_TILE_COUNT = 33


def target_order(centre, n):
    """centre, one step brighter, one step darker, then outward."""
    out = []
    for step in range(len(BROWN)):
        positions = [centre] if step == 0 else [centre - step, centre + step]
        for pos in positions:
            if 0 <= pos < len(BROWN) and BROWN[pos] not in out:
                out.append(BROWN[pos])
            if len(out) >= n:
                return out
    while len(out) < n:
        out.append(BROWN[-1])
    return out


def frame_names(res):
    path = os.path.join(ROOT, 'sprites', res, res + '.yy')
    text = open(path, encoding='utf-8').read()
    yy = json.loads(re.sub(r',(\s*[}\]])', r'\1', text))
    return [f['name'] for f in yy['frames']]


def frame_paths(res, name):
    base = os.path.join(ROOT, 'sprites', res)
    out = [os.path.join(base, name + '.png')]
    layers = os.path.join(base, 'layers', name)
    if os.path.isdir(layers):
        for fn in os.listdir(layers):
            if fn.endswith('.png'):
                out.append(os.path.join(layers, fn))
    return out


def colour_map_for(tile):
    """Built from the master tile in spr_map_ground so every sprite that uses
    the same ground tile is remapped identically."""
    names = frame_names('spr_map_ground')
    path = os.path.join(ROOT, 'sprites', 'spr_map_ground', names[tile] + '.png')

    counts = {}
    im = Image.open(path).convert('RGBA')
    for n, c in im.getcolors(1 << 20):
        if c[3] > 0:
            counts[c[:3]] = counts.get(c[:3], 0) + n
    if not counts:
        return {}

    ranked = sorted(counts, key=lambda k: -counts[k])
    return dict(zip(ranked, target_order(CENTRES[tile], len(ranked))))


def main():
    maps = {tile: colour_map_for(tile) for tile in CENTRES}

    for res in TARGETS:
        names = frame_names(res)
        changed = 0

        for index, name in enumerate(names):
            tile = index % GROUND_TILE_COUNT if res != 'spr_map_ground' else index
            cmap = maps.get(tile)
            if not cmap:
                continue

            for path in frame_paths(res, name):
                im = Image.open(path).convert('RGBA')
                px = im.load()
                w, h = im.size
                hit = False
                for y in range(h):
                    for x in range(w):
                        r, g, b, a = px[x, y]
                        if a == 0:
                            continue
                        new = cmap.get((r, g, b))
                        if new is not None and new != (r, g, b):
                            px[x, y] = (new[0], new[1], new[2], a)
                            hit = True
                if hit:
                    im.save(path)
                    changed += 1

        print('  %-18s recoloured %d png(s)' % (res, changed))

    print('desert now reads as sand; tundra and snow untouched')


main()
