#!/usr/bin/env python3
"""Three cheap structural checks that a compile would catch late and a brace
count would not catch at all.

  1. Brace balance per file, with the line of the first unmatched brace.
  2. `continue` and `break` used outside a loop (or, for break, a switch).
     GML reports "Continue used without context" at compile time; a bulk edit
     that pastes a nil guard into a block that merely LOOKS like a loop is the
     way this happens.
  3. Undeclared locals: an identifier starting with `_` that is used inside a
     function but is neither one of its parameters nor declared with `var`
     anywhere in that function. This is the class of bug where an edit assumes
     a variable is in scope because a nearby function has it.

Usage: python3 tools/check_locals.py [files...]   (defaults to every .gml)
Exit status 1 if anything is found.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gml_scan import blank_comments, gml_files

IDENT = re.compile(r'\b(_[A-Za-z0-9_]*)\b')
FUNC_START = re.compile(r'\bfunction\b\s*([A-Za-z_]\w*)?\s*\(([^)]*)\)')
VAR_DECL = re.compile(r'\bvar\s+([^;]*)')
LOOP_KW = re.compile(r'\b(for|while|do|switch|repeat|with)\b')


def check_braces(text, name, problems):
    depth = 0
    first_bad = None
    for lineno, line in enumerate(text.split('\n'), 1):
        for ch in line:
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth < 0 and first_bad is None:
                    first_bad = lineno
    if depth != 0 or first_bad is not None:
        problems.append('%s: brace imbalance (depth %d at EOF, first bad line %s)'
                        % (name, depth, first_bad))


def check_context(text, name, problems):
    """Walk the file tracking a stack of block kinds; flag continue/break
    that have no loop (or switch) between them and the enclosing function."""
    stack = []          # entries: 'loop', 'switch', 'function', 'block'
    pending = None      # kind waiting for its '{'
    i = 0
    n = len(text)
    lineno = 1
    while i < n:
        ch = text[i]
        if ch == '\n':
            lineno += 1
            i += 1
            continue
        if ch.isalpha() or ch == '_':
            j = i
            while j < n and (text[j].isalnum() or text[j] == '_'):
                j += 1
            word = text[i:j]
            if word in ('for', 'while', 'do', 'repeat', 'with', 'switch'):
                pending = 'switch' if word == 'switch' else 'loop'
                # skip the parenthesised header so its ';' and '{' do not
                # confuse the block tracking (for (...;...;...) especially)
                k = j
                while k < n and text[k] in ' \t\n':
                    if text[k] == '\n':
                        lineno += 1
                    k += 1
                if k < n and text[k] == '(':
                    depth = 0
                    while k < n:
                        if text[k] == '(':
                            depth += 1
                        elif text[k] == ')':
                            depth -= 1
                            if depth == 0:
                                k += 1
                                break
                        elif text[k] == '\n':
                            lineno += 1
                        k += 1
                    j = k
            elif word == 'function':
                pending = 'function'
            elif word in ('continue', 'break'):
                ok = False
                for kind in reversed(stack):
                    if kind == 'function':
                        break
                    if kind == 'loop' or (kind == 'switch' and word == 'break'):
                        ok = True
                        break
                if not ok:
                    problems.append('%s:%d: %s used without an enclosing loop%s'
                                    % (name, lineno, word,
                                       '/switch' if word == 'break' else ''))
            i = j
            continue
        if ch == '{':
            stack.append(pending if pending else 'block')
            pending = None
        elif ch == '}':
            if stack:
                stack.pop()
        elif ch == ';' and pending in ('loop', 'switch'):
            # single-statement loop body without braces: forget it
            pending = None
        i += 1


def split_functions(text):
    """Yield (start_line, header_params, body) for each function, where body
    is the text up to the matching close brace of its own block. Nested
    functions are included in the outer body too, which is fine: a name
    declared in the outer function is still in scope for the inner one."""
    for m in FUNC_START.finditer(text):
        params = m.group(2)
        j = m.end()
        # find the opening brace
        while j < len(text) and text[j] != '{':
            if text[j] == ';':
                break
            j += 1
        if j >= len(text) or text[j] != '{':
            continue
        depth = 0
        k = j
        while k < len(text):
            if text[k] == '{':
                depth += 1
            elif text[k] == '}':
                depth -= 1
                if depth == 0:
                    break
            k += 1
        start_line = text.count('\n', 0, m.start()) + 1
        yield start_line, params, text[j:k + 1]


def check_locals(text, name, problems):
    for start_line, params, body in split_functions(text):
        declared = set()
        for p in params.split(','):
            p = p.strip().split('=')[0].strip()
            if p:
                declared.add(p)
        for vm in VAR_DECL.finditer(body):
            for piece in vm.group(1).split(','):
                nm = piece.strip().split('=')[0].strip()
                if nm:
                    declared.add(nm)
        # a nested function's params count as declared for the body too
        for fm in FUNC_START.finditer(body):
            for p in fm.group(2).split(','):
                p = p.strip().split('=')[0].strip()
                if p:
                    declared.add(p)
        seen = set()
        for um in IDENT.finditer(body):
            ident = um.group(1)
            if ident in declared or ident in seen or ident == '_':
                continue
            # struct field access `.foo` and `s._x`: skip when preceded by '.'
            pre = body[um.start() - 1] if um.start() > 0 else ''
            if pre == '.':
                continue
            seen.add(ident)
            line = start_line + body.count('\n', 0, um.start())
            problems.append('%s:%d: `%s` used but never declared in this function'
                            % (name, line, ident))


def main():
    files = sys.argv[1:] or gml_files('.')
    problems = []
    for path in files:
        raw = open(path, encoding='utf-8').read()
        text = blank_comments(raw)
        short = os.path.basename(path)
        check_braces(text, short, problems)
        check_context(text, short, problems)
        check_locals(text, short, problems)
    for p in problems:
        print(p)
    print('-- %d problems' % len(problems))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
