#!/usr/bin/env python3
"""Find a constructor calling a static that belongs to a DIFFERENT constructor.

`draw_netplay()` inside GameInitBox, with `static draw_netplay` defined over in
RandomInput, compiles perfectly well and then throws at run time:

    Variable GameInitBox.draw_netplay(...) not set before reading it

which is only reached when that branch actually draws. The mistake is easy to
make with a search-and-replace edit: `static internal_draw = function() {`
appears in several constructors in one file, and an edit anchored on the first
one lands in whichever constructor happens to come first, not the intended one.

The check: for each constructor, every unqualified call whose name is a static
SOMEWHERE must be a static in this constructor or in one it inherits from.
Anything else is a call that will not resolve at run time.

Inheritance is read from `function Child(...) : Parent(...) constructor`, so a
method genuinely inherited from GuiObject is not reported.

Usage: python3 tools/check_static_scope.py [repo root]
Exit status 1 if anything is found.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gml_scan import blank_comments, body_of, gml_files

CTOR = re.compile(
    r'function\s+(\w+)\s*\([^)]*\)\s*(?::\s*(\w+)\s*\([^)]*\)\s*)?constructor\s*\{')
STATIC = re.compile(r'\bstatic\s+(\w+)\s*=\s*function')
# An unqualified call: not preceded by a dot, and not a declaration.
CALL = re.compile(r'(?<![.\w])(\w+)\s*\(')

KEYWORDS = {
    'if', 'while', 'for', 'switch', 'return', 'with', 'repeat', 'do', 'until',
    'catch', 'function', 'new', 'var', 'else', 'case', 'throw', 'delete',
}




def collect(root):
    """{constructor: (parent, {statics}, [(name, line, file)])}"""
    ctors = {}
    for path in gml_files(root):
        with open(path, encoding='utf-8') as handle:
            clean = blank_comments(handle.read())

        for match in CTOR.finditer(clean):
            body = body_of(clean, match.end())
            statics = set(STATIC.findall(body))
            calls = []
            for call in CALL.finditer(body):
                name = call.group(1)
                if name in KEYWORDS:
                    continue
                line = clean[:match.end() + call.start()].count('\n') + 1
                calls.append((name, line, path))
            ctors[match.group(1)] = (match.group(2), statics, calls)

    return ctors


def check(root):
    ctors = collect(root)
    every_static = set()
    for _parent, statics, _calls in ctors.values():
        every_static |= statics

    found = 0
    for name, (parent, statics, calls) in sorted(ctors.items()):
        # Everything reachable: our own statics plus the whole parent chain's.
        reachable = set(statics)
        seen = {name}
        walk = parent
        while walk is not None and walk in ctors and walk not in seen:
            seen.add(walk)
            reachable |= ctors[walk][1]
            walk = ctors[walk][0]

        reported = set()
        for called, line, path in calls:
            if called in reachable or called not in every_static:
                continue
            if called in reported:
                continue
            reported.add(called)

            owners = sorted(c for c, v in ctors.items() if called in v[1])
            found += 1
            rel = os.path.relpath(path, root)
            print(f'{rel}:{line}: {name} calls "{called}", which is a static of '
                  f'{", ".join(owners)} - not reachable from here')

    if found == 0:
        print('no out-of-scope static calls')
    return found


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    sys.exit(1 if check(root) > 0 else 0)
