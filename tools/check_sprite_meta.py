#!/usr/bin/env python3
"""Check that every sprite's meta table has a row per frame.

gfx_draw_sprite_full starts with

    var _m = gfx_meta(_asset, _index);
    if (_m[0] == 0) { return; }

and gfx_meta returns a zero row for an index past the end of the table. So a
frame added to a sprite without a matching row in scr_sprite_meta does not draw,
does not warn, and does not crash - it is simply invisible, which is a long
afternoon if the thing you added is a button.

That is exactly how the NET PLAY icon went missing: spr_icon grew to 319 frames
while global.sprite_meta.icon still had 318 rows.

Usage: python3 tools/check_sprite_meta.py [repo root]
Exit status 1 if any sprite and its table disagree.
"""
import os
import re
import sys

META = re.compile(r'global\.sprite_meta\.(\w+)\s*=\s*\[(.*?)\];', re.S)
ROW = re.compile(r'\[[^\]]*\]')
ASSET = re.compile(r'global\.gfx_assets\[Asset\.(\w+)\]\s*=\s*\[(\w+),')


def frame_count(root, sprite):
    """Frames in a sprite's .yy, or None if there is no such sprite."""
    path = os.path.join(root, 'sprites', sprite, sprite + '.yy')
    if not os.path.isfile(path):
        return None
    with open(path, encoding='utf-8-sig') as handle:
        return handle.read().count('"$GMSpriteFrame"')


def check(root):
    meta_path = os.path.join(root, 'scripts', 'scr_sprite_meta',
                             'scr_sprite_meta.gml')
    gfx_path = os.path.join(root, 'scripts', 'scr_gfx', 'scr_gfx.gml')
    if not os.path.isfile(meta_path) or not os.path.isfile(gfx_path):
        print('sprite meta or gfx script not found - nothing to check')
        return 0

    with open(meta_path, encoding='utf-8') as handle:
        meta_src = handle.read()
    with open(gfx_path, encoding='utf-8') as handle:
        gfx_src = handle.read()

    # Asset name -> sprite resource name, from the gfx_assets table.
    sprite_of = {}
    for match in ASSET.finditer(gfx_src):
        sprite_of[match.group(1)] = match.group(2)

    found = 0
    for match in META.finditer(meta_src):
        asset = match.group(1)
        rows = len(ROW.findall(match.group(2)))
        sprite = sprite_of.get(asset)
        if sprite is None:
            continue

        frames = frame_count(root, sprite)
        if frames is None:
            continue

        if frames != rows:
            found += 1
            print(f'{sprite}: {frames} frames but sprite_meta.{asset} has '
                  f'{rows} rows - frames {rows}..{frames - 1} will not draw')

    if found == 0:
        print('sprite meta matches every sprite')
    return found


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sys.exit(1 if check(root) > 0 else 0)
