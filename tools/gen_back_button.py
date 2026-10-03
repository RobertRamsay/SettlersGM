#!/usr/bin/env python3
"""
Build spr_btn_back - the start screen's 32x32 BACK plaque - and install it.

Made from the game's own LOAD plaque (spr_icon frame 316): its lettering is
covered with plain wood taken from the same plaque's empty rows, then BACK is
lettered in the original's style - one tall capital, then small capitals
across the top half, yellow 221,221,0 with a dark 85,34,0 edge. Nothing is
taken from anywhere but the Settlers icon set already in the project.

Re-runnable: write_sprite wipes the folder first and register() skips a
resource that is already in the .yyp.
"""
import os
import re

from PIL import Image

import pack_cf_assets as pack

REPO = pack.REPO
ICON_DIR = os.path.join(REPO, "sprites", "spr_icon")
OUT = os.path.join(REPO, "tools", "back_build", "back")

YELLOW = (221, 221, 0, 255)
EDGE = (85, 34, 0, 255)

BIG_B = ["ggggggg.",
         ".gg...gg",
         ".gg...gg",
         ".gg..gg.",
         ".ggggg..",
         ".gg...gg",
         ".gg....gg",
         ".gg....gg",
         ".gg...gg",
         "ggggggg."]
SMALL_A = [".ggg.", "g...g", "ggggg", "g...g", "g...g"]
SMALL_C = [".ggg", "g...", "g...", "g...", ".ggg"]
SMALL_K = ["g...g", "g..g.", "ggg..", "g..g.", "g...g"]


def icon_frame(index):
    yy = open(os.path.join(ICON_DIR, "spr_icon.yy"), encoding="utf-8").read()
    ids = re.findall(r'"name":"([0-9a-f-]{36})","resourceType":"GMSpriteFrame"', yy)
    path = os.path.join(ICON_DIR, ids[index] + ".png")
    return Image.open(path).convert("RGBA").crop((0, 0, 32, 32))


def build():
    src = icon_frame(316)
    im = src.copy()

    # Rows 10..21 carry the LOAD lettering. Cover them with whole rows of
    # plain plank from below and above it, border columns included, so the
    # frame down each side stays continuous.
    donor = list(range(22, 30)) + list(range(2, 6))
    for k, row in enumerate(range(10, 22)):
        for x in range(32):
            im.putpixel((x, row), src.getpixel((x, donor[k])))

    lit = set()

    def put(glyph, x0, y0):
        for dy, line in enumerate(glyph):
            for dx, c in enumerate(line):
                if c == "g":
                    lit.add((x0 + dx, y0 + dy))

    put(BIG_B, 3, 11)
    put(SMALL_A, 13, 11)
    put(SMALL_C, 19, 11)
    put(SMALL_K, 24, 11)

    edge = set()
    for (x, y) in lit:
        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1)):
            p = (x + ddx, y + ddy)
            if p not in lit:
                edge.add(p)
    for p in edge:
        im.putpixel(p, EDGE)
    for p in lit:
        im.putpixel(p, YELLOW)

    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, "00.png"))


def main():
    build()
    pack.write_sprite("spr_btn_back", OUT, 0, 0)
    pack.register([("spr_btn_back", "sprites/spr_btn_back/spr_btn_back.yy")])


if __name__ == "__main__":
    main()
