#!/usr/bin/env python3
"""Shared GML source scanning for the checkers in this folder.

The naive way to strip comments - regex out /*...*/, then //..., then "..." -
has a hole big enough to hide a bug in, and it did. `#macro UPDATE_CHECK_URL
"https://raw.githubusercontent.com/..."` contains a // INSIDE a string; removing
line comments first eats the closing quote, every quote after it pairs up wrong,
and whole constructors vanish from the checker's view. A tool that silently sees
less of the file than it thinks reports "clean" and is worse than no tool.

So this is a real scanner: one pass, tracking whether we are in code, a line
comment, a block comment or a string, and deciding by state rather than by
pattern. Newlines are preserved throughout so line numbers stay honest.
"""


def blank_comments(text):
    """Comments and string bodies replaced by spaces, newlines kept."""
    out = []
    i = 0
    n = len(text)

    while i < n:
        ch = text[i]

        # Block comment
        if ch == '/' and i + 1 < n and text[i + 1] == '*':
            while i < n:
                if text[i] == '*' and i + 1 < n and text[i + 1] == '/':
                    out.append('  ')
                    i += 2
                    break
                if text[i] == '\n':
                    out.append('\n')
                else:
                    out.append(' ')
                i += 1
            continue

        # Line comment
        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                out.append(' ')
                i += 1
            continue

        # String. GML strings do not span lines, but an unterminated one should
        # not run away with the rest of the file either, so a newline ends it.
        if ch == '"':
            out.append('"')
            i += 1
            while i < n and text[i] != '"' and text[i] != '\n':
                if text[i] == '\\' and i + 1 < n:
                    out.append('  ')
                    i += 2
                    continue
                out.append(' ')
                i += 1
            if i < n and text[i] == '"':
                out.append('"')
                i += 1
            continue

        out.append(ch)
        i += 1

    return ''.join(out)


def body_of(text, start):
    """Text between braces, given the index just past the opening one."""
    depth = 1
    i = start
    while i < len(text) and depth > 0:
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
        i += 1
    return text[start:i]


def line_of(text, index):
    """1-based line number of an index."""
    return text[:index].count('\n') + 1


def gml_files(root):
    import glob
    import os
    files = sorted(glob.glob(os.path.join(root, 'scripts', '*', '*.gml')))
    files += sorted(glob.glob(os.path.join(root, 'objects', '*', '*.gml')))
    return files


if __name__ == '__main__':
    # A self-test, because a scanner that is wrong is invisible.
    cases = [
        ('var a = "http://x"; // note\nvar b = 1;', 'b = 1'),
        ('/* a\n b */ var c = 2;', 'c = 2'),
        ('var d = "a\\"b"; var e = 3;', 'e = 3'),
    ]
    ok = True
    for src, expect in cases:
        got = blank_comments(src)
        if expect not in got:
            ok = False
            print('FAIL', repr(src), '->', repr(got))
        if got.count('\n') != src.count('\n'):
            ok = False
            print('FAIL line count', repr(src))
    print('gml_scan self-test:', 'ok' if ok else 'FAILED')
