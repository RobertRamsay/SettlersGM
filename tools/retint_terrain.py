#!/usr/bin/env python3
"""
retint_terrain.py - rework the terrain ground tiles so the dither matches the
real Amiga output instead of the harsh high-contrast mix that comes out of
Freeserf's Amiga ground decoder.

WHY
Measured from three clean 320x256 Amiga captures, by finding every window that
contains nothing but palette greens / browns / greys and pooling them:

    flat grass    #448800 44.9  #669900 33.0  #336633 14.1  #77bb44  6.1  rest ~2
    flat desert   #995522 51.8  #bb8855 21.5  #773300 18.5  #552200  4.8  rest ~3
    flat snow     #ffffff 51.8  #cccccc 42.1  #999999  4.7  #666666  1.0  rest ~0

Every one of them is the same shape: a majority "centre" colour, then one step
BRIGHTER, then one step DARKER, then progressively further out - a spread of
about two ramp steps.

The extracted tiles are nothing like that. spr_map_ground tile 4 (the tile a
flat triangle resolves to) is 58% #224400, 22% #335500 and 20% #77bb44 - the
darkest colour in the ramp mixed with the brightest, a spread of five steps.
That is the harshness.

WHAT THIS DOES
Keeps each tile's dither pattern exactly as-is and only reassigns which colour
each pixel class gets: rank the tile's colours by pixel count, then lay them
onto the ramp in the order centre, centre-1, centre+1, centre-2, centre+2, ...
CENTRES below says where each tile sits on its ramp, pinned so the flat tile of
each family lands on the measured reference centre.

Tweak RAMPS or CENTRES and re-run; nothing else depends on these values.

Usage, from the project root (or pass the project path):
    python tools/retint_terrain.py .
"""

import json
import os
import re
import sys

from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'

# Each ramp is ordered brightest -> darkest.
GRASS = [(0x77, 0xBB, 0x44), (0x66, 0x99, 0x00), (0x44, 0x88, 0x00),
         (0x33, 0x66, 0x33), (0x33, 0x55, 0x00), (0x22, 0x44, 0x00)]
BROWN = [(0xFF, 0xDD, 0xBB), (0xDD, 0xAA, 0x77), (0xBB, 0x88, 0x55),
         (0x99, 0x55, 0x22), (0x77, 0x33, 0x00), (0x55, 0x22, 0x00)]
GREY = [(0xFF, 0xFF, 0xFF), (0xCC, 0xCC, 0xCC), (0x99, 0x99, 0x99),
        (0x66, 0x66, 0x66), (0x44, 0x44, 0x44), (0x22, 0x22, 0x22)]

# ground tile index -> (ramp, centre position on that ramp)
# tri_spr maps Grass to 0-7, Tundra to 8-15, Snow to 16-23, Desert to 24-31,
# and water to 32. Within each block a flat triangle resolves to offset 4,
# because tri_mask_up[40] == 4. Those are the entries pinned to the measured
# reference centre; the rest ramp away from them for slope shading.
CENTRES = {}
for i, c in enumerate([0, 1, 1, 2, 2, 3, 3, 4]):          # grass, flat -> #448800
    CENTRES[i] = (GRASS, c)
for i, c in enumerate([0, 1, 1, 2, 2, 3, 3, 4]):          # tundra, flat -> #bb8855
    CENTRES[8 + i] = (BROWN, c)
for i, c in enumerate([3, 2, 2, 1, 0, 0, 0, 0]):          # snow, flat -> #ffffff
    CENTRES[16 + i] = (GREY, c)
for i, c in enumerate([5, 5, 4, 4, 3, 3, 2, 1]):          # desert, flat -> #995522
    CENTRES[24 + i] = (BROWN, c)
# 32 is the flat water fill, left alone.

# spr_path_baked was baked from map_ground 10..19 (see build_project.py), so
# frame = mask * 10 + g corresponds to ground tile 10 + g.
PATH_GROUND_BASE = 10


def target_order(ramp, centre, n):
    """centre, one step brighter, one step darker, then outward. Clamped."""
    out = []
    for step in range(len(ramp)):
        for pos in ([centre] if step == 0 else [centre - step, centre + step]):
            if 0 <= pos < len(ramp) and ramp[pos] not in out:
                out.append(ramp[pos])
            if len(out) >= n:
                return out
    while len(out) < n:
        out.append(ramp[-1])
    return out


def build_map(tile_index):
    """Colour -> colour for one ground tile, or None to leave it alone."""
    if tile_index not in CENTRES:
        return None
    ramp, centre = CENTRES[tile_index]
    path = tile_png(SRC_FRAMES['spr_map_ground'][tile_index], 'spr_map_ground')
    im = Image.open(path).convert('RGBA')
    counts = {}
    for n, c in im.getcolors(1 << 20):
        if c[3] > 0:
            counts[c[:3]] = counts.get(c[:3], 0) + n
    ranked = sorted(counts, key=lambda k: -counts[k])
    targets = target_order(ramp, centre, len(ranked))
    return dict(zip(ranked, targets))


def frame_names(res):
    text = open(os.path.join(ROOT, 'sprites', res, res + '.yy'),
                encoding='utf-8').read()
    yy = json.loads(re.sub(r',(\s*[}\]])', r'\1', text))
    return [f['name'] for f in yy['frames']]


def tile_png(name, res):
    return os.path.join(ROOT, 'sprites', res, name + '.png')


def apply_to(res, tile_of_frame):
    """Recolour every frame of `res`; tile_of_frame(i) gives its ground tile."""
    names = frame_names(res)
    changed = 0
    for i, name in enumerate(names):
        t = tile_of_frame(i)
        cmap = MAPS.get(t)
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


def frame_paths(res, name):
    base = os.path.join(ROOT, 'sprites', res)
    out = [os.path.join(base, name + '.png')]
    ldir = os.path.join(base, 'layers', name)
    if os.path.isdir(ldir):
        for fn in os.listdir(ldir):
            if fn.endswith('.png'):
                out.append(os.path.join(ldir, fn))
    return out


SRC_FRAMES = {'spr_map_ground': frame_names('spr_map_ground')}
MAPS = {t: build_map(t) for t in CENTRES}

print('retinting terrain in', ROOT)
apply_to('spr_map_ground', lambda i: i)
# spr_ground_up / _down were baked as frame = mask * 33 + ground.
apply_to('spr_ground_up', lambda i: i % 33)
apply_to('spr_ground_down', lambda i: i % 33)
# spr_path_baked was baked as frame = mask * 10 + g, ground tile = 10 + g.
apply_to('spr_path_baked', lambda i: PATH_GROUND_BASE + (i % 10))
print('done')
