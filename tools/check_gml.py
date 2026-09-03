#!/usr/bin/env python3
"""Cheap cross-file consistency checker for the GML port."""
import re, os, sys, glob
from collections import defaultdict

GML = '/home/claude/settlers/gml'
OBJ = '/home/claude/settlers/objects'
files = sorted(glob.glob(f'{GML}/*.gml')) + sorted(glob.glob(f'{OBJ}/*/*.gml'))

def strip_comments(t):
    t = re.sub(r'/\*.*?\*/', lambda m: ' ' * len(m.group(0)), t, flags=re.S)
    t = re.sub(r'//[^\n]*', '', t)
    t = re.sub(r'"(?:\\.|[^"\\])*"', '""', t)
    return t

src = {}
for f in files:
    src[f] = strip_comments(open(f).read())

statics = defaultdict(set)     # name -> files
functions = defaultdict(set)
enums = {}                     # Enum -> set(members)
macros = set()
globals_def = set()
for f, t in src.items():
    for m in re.finditer(r'\bstatic\s+([A-Za-z_]\w*)\s*=\s*function', t):
        statics[m.group(1)].add(os.path.basename(f))
    for m in re.finditer(r'^\s*function\s+([A-Za-z_]\w*)\s*\(', t, re.M):
        functions[m.group(1)].add(os.path.basename(f))
    for m in re.finditer(r'\benum\s+([A-Za-z_]\w*)\s*\{([^}]*)\}', t, re.S):
        members = set()
        for part in m.group(2).split(','):
            part = part.strip()
            if not part:
                continue
            members.add(part.split('=')[0].strip())
        enums.setdefault(m.group(1), set()).update(members)
    for m in re.finditer(r'#macro\s+([A-Za-z_]\w*)', t):
        macros.add(m.group(1))
    for m in re.finditer(r'\bglobal\.([A-Za-z_]\w*)\s*=', t):
        globals_def.add(m.group(1))

# GML builtins commonly used as methods/functions on structs (skip these)
builtin_methods = {'length'}
problems = []

for f, t in src.items():
    b = os.path.basename(f)
    # method calls
    for m in re.finditer(r'\.([A-Za-z_]\w*)\s*\(', t):
        name = m.group(1)
        if name in statics or name in functions or name in builtin_methods:
            continue
        line = t.count('\n', 0, m.start()) + 1
        problems.append((b, line, f'method .{name}() not defined anywhere'))
    # enum member refs
    for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]*)\.([a-z_][A-Za-z0-9_]*)\b', t):
        en, mem = m.group(1), m.group(2)
        if en in enums:
            if mem not in enums[en]:
                line = t.count('\n', 0, m.start()) + 1
                problems.append((b, line, f'enum member {en}.{mem} missing (has {sorted(enums[en])[:3]}...)'))
    # global reads
    for m in re.finditer(r'\bglobal\.([A-Za-z_]\w*)', t):
        if m.group(1) not in globals_def:
            line = t.count('\n', 0, m.start()) + 1
            problems.append((b, line, f'global.{m.group(1)} never assigned'))
    # bare function calls to unknown functions (only snake_case names with underscore prefix patterns typical of ports)
    for m in re.finditer(r'(?<![\.\w])([a-z][a-z0-9]*_[a-z0-9_]*)\s*\(', t):
        name = m.group(1)
        if name in functions or name in statics or name in macros:
            continue
        line = t.count('\n', 0, m.start()) + 1
        problems.append((b, line, f'call {name}() - not a project function (builtin?)'))

# constructor calls: new X(
ctors = set(functions)
for f, t in src.items():
    b = os.path.basename(f)
    for m in re.finditer(r'\bnew\s+([A-Za-z_]\w*)\s*\(', t):
        if m.group(1) not in ctors:
            line = t.count('\n', 0, m.start()) + 1
            problems.append((b, line, f'new {m.group(1)}() - constructor not defined'))

seen = set()
for p in sorted(problems):
    key = (p[0], p[2])
    if key in seen:
        continue
    seen.add(key)
    print(f'{p[0]}:{p[1]}: {p[2]}')
print(f'-- {len(seen)} unique problems; statics={len(statics)} functions={len(functions)} enums={len(enums)}')
# duplicate top-level function names across files
for name, fs in functions.items():
    if len(fs) > 1:
        print('DUP function', name, fs)
dup_enum = defaultdict(list)
for f, t in src.items():
    for m in re.finditer(r'\benum\s+([A-Za-z_]\w*)', t):
        dup_enum[m.group(1)].append(os.path.basename(f))
for k, v in dup_enum.items():
    if len(v) > 1:
        print('DUP enum', k, v)
mac = defaultdict(list)
for f, t in src.items():
    for m in re.finditer(r'#macro\s+([A-Za-z_]\w*)', t):
        mac[m.group(1)].append(os.path.basename(f))
for k, v in mac.items():
    if len(v) > 1:
        print('DUP macro', k, v)
