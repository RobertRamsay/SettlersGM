#!/usr/bin/env python3
"""Find duplicate `static name = function` inside one GML constructor.

GML keeps the LAST definition and says nothing. The earlier one is simply gone,
so a working feature disappears the moment somebody adds a second handler with
the same name further down the same constructor - which is how PanelBar's map
icon lost its castle jump: two handle_click_middle definitions, one for the map
button and one for the build button, and only the second existed.

Two things this needs to get right, both learned the hard way:

  - A constructor that inherits is written `function PanelBar(_i) : GuiObject()
    constructor {`, so a pattern of `function NAME(...) constructor` matches none
    of the GUI classes - which is all of the ones with handlers.

  - Comments and strings have to be removed by a real scanner, not by regex.
    A string containing // (a URL in a #macro, say) breaks the naive version and
    whole constructors drop out of view, at which point the tool reports "clean"
    and is worse than nothing. See tools/gml_scan.py.

Usage: python3 tools/check_dup_statics.py [repo root]
Exit status 1 if anything is found, so it can go in a pre-commit hook.
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gml_scan import blank_comments, body_of, gml_files, line_of

CTOR = re.compile(
    r'function\s+(\w+)\s*\([^)]*\)\s*(?::\s*\w+\s*\([^)]*\)\s*)?constructor\s*\{')
STATIC = re.compile(r'\bstatic\s+(\w+)\s*=\s*function')


def check(root):
    found = 0

    for path in gml_files(root):
        with open(path, encoding='utf-8') as handle:
            clean = blank_comments(handle.read())

        for match in CTOR.finditer(clean):
            body = body_of(clean, match.end())
            counts = collections.Counter(STATIC.findall(body))
            dupes = sorted(name for name, n in counts.items() if n > 1)
            if not dupes:
                continue

            line = line_of(clean, match.start())
            rel = os.path.relpath(path, root)
            for name in dupes:
                found += 1
                print(f'{rel}:{line}: {match.group(1)} defines "{name}" '
                      f'{counts[name]} times - only the last survives')

    if found == 0:
        print('no duplicate statics')
    return found


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sys.exit(1 if check(root) > 0 else 0)
