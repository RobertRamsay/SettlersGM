#!/usr/bin/env python3
"""
extract_animations.py - read the serf animation table out of the Amiga
`gfxfast` file and write it into scripts/scr_sprite_meta/scr_sprite_meta.gml.

WHY
tools/dump.cc wrote the table with `ds.get_animation(a, p)`, but that function
does `phase >>= 3` before indexing, so it sampled only real phases 0..n/8 and
wrote each one eight times over. Serfs played eight coarse positions covering
about an eighth of a tile, then jumped the rest.

That same off-by-eight is what lets this script check itself. The old table
satisfies old[k] == real[k >> 3], so real[j] == old[j * 8]. The first entries of
animation 0 therefore give a byte signature we can search for, which means we do
not have to guess how the file is framed - we find the table instead.

Usage:
    python tools/extract_animations.py <path/to/gfxfast> [project_root]

Nothing is written unless every rebuilt phase agrees with the existing table.
"""

import json
import re
import sys

GFXFAST = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
GML = ROOT + '/scripts/scr_sprite_meta/scr_sprite_meta.gml'

ANIMATION_COUNT = 200
# load_animation_table() is handed get_subbuffer(0, 30528), so the block is that
# many bytes and the last animation ends there - not at the end of the file.
ANIMATION_BLOCK_BYTES = 30528


def decode(data):
    """DataSourceAmiga::decode - xor each byte with its own index."""
    return bytes((b ^ (i & 0xFF)) for i, b in enumerate(data))


def unpack(data):
    """DataSourceAmiga::unpack - run length, first byte is the escape flag."""
    out = bytearray()
    flag = data[0]
    i = 1
    n = len(data)
    while i < n:
        val = data[i]
        i += 1
        count = 0
        if val == flag:
            if i + 1 >= n:
                break
            count = data[i]
            val = data[i + 1]
            i += 2
        out.extend(bytes([val]) * (count + 1))
    return bytes(out)


def signed(b):
    return b - 256 if b > 127 else b


def current_table(text):
    m = re.search(r'global\.animations = (\[\[\[.*?\]\]\]);', text, re.S)
    if m is None:
        raise SystemExit('could not find global.animations in ' + GML)
    return json.loads(m.group(1))


def stride(old):
    """8 if the table still has the off-by-eight repeats, else 1.

    Lets the script be re-run against a table it has already rebuilt."""
    a0 = old[0]
    if len(a0) >= 8 and all(a0[k] == a0[0] for k in range(8)):
        return 8
    return 1


def signature(old, step):
    """Bytes the real animation 0 must start with."""
    sig = bytearray()
    a0 = old[0]
    for j in range(0, len(a0) // step):
        s, x, y = a0[j * step]
        sig += bytes([s & 0xFF, x & 0xFF, y & 0xFF])
        if len(sig) >= 24:
            break
    return bytes(sig)


def locate(blob, sig):
    """Every place the animation block could sit, as (base, animation0_pos)."""
    hits = []
    start = 0
    while True:
        p = blob.find(sig, start)
        if p < 0:
            break
        start = p + 1
        # animation_block[0] is a uint32 offset from the block base to
        # animation 0's phases, so base + that offset == p.
        for base in range(0, p - 3):
            if int.from_bytes(blob[base:base + 4], 'big') == p - base:
                hits.append((base, p))
                break
    return hits


def read_table(blob, base):
    limit = min(ANIMATION_BLOCK_BYTES, len(blob) - base)
    offsets = [int.from_bytes(blob[base + i * 4:base + i * 4 + 4], 'big')
               for i in range(ANIMATION_COUNT)]
    animations = []
    for i in range(ANIMATION_COUNT):
        a = offsets[i]
        nxt = limit
        for b in offsets:
            if b > a:
                nxt = min(nxt, b)
        phases = []
        for j in range((nxt - a) // 3):
            p = base + a + 3 * j
            if p + 2 >= len(blob):
                break
            phases.append([blob[p], signed(blob[p + 1]), signed(blob[p + 2])])
        animations.append(phases)
    return animations


def check(animations, old, step):
    """Every rebuilt phase j must equal old phase j * step. Count, or None."""
    checked = 0
    for i in range(min(len(old), len(animations))):
        for j, phase in enumerate(animations[i]):
            k = j * step
            if k >= len(old[i]):
                break
            if old[i][k] != phase:
                return None
            checked += 1
    return checked


def main():
    raw = open(GFXFAST, 'rb').read()
    print('read %s (%d bytes)' % (GFXFAST, len(raw)))

    text = open(GML, encoding='utf-8').read()
    old = current_table(text)
    step = stride(old)
    sig = signature(old, step)
    print('existing table stride %d (%s)'
          % (step, 'still has the off-by-eight repeats' if step == 8
             else 'already rebuilt, re-verifying'))
    print('searching for a %d byte signature from animation 0: %s'
          % (len(sig), sig.hex()))

    variants = [
        ('unpack(decode(raw))', lambda d: unpack(decode(d))),
        ('decode(raw)', decode),
        ('unpack(raw)', unpack),
        ('raw', lambda d: d),
    ]

    best = None
    for name, fn in variants:
        try:
            blob = fn(raw)
        except Exception as exc:
            print('  %-20s failed: %s' % (name, exc))
            continue
        hits = locate(blob, sig)
        print('  %-20s %8d bytes, %d candidate position(s)'
              % (name, len(blob), len(hits)))
        for base, pos in hits:
            animations = read_table(blob, base)
            n = check(animations, old, step)
            if n is None:
                print('    base 0x%x rejected by self-check' % base)
            else:
                print('    base 0x%x, animation 0 at 0x%x -> self-check passed '
                      'on %d phases' % (base, pos, n))
                if best is None or n > best[0]:
                    best = (n, animations, name, base)

    if best is None:
        raise SystemExit(
            'No framing of this file reproduced the existing table. Nothing '
            'written. Send me the output above and I will work out the layout.')

    n, animations, name, base = best
    print('using %s at base 0x%x' % (name, base))

    old_distinct = sum(len({tuple(p) for p in a}) for a in old)
    new_distinct = sum(len({tuple(p) for p in a}) for a in animations)
    widest = max(max((abs(p[1]) for p in a), default=0) for a in animations)
    print('distinct phases: %d before, %d after' % (old_distinct, new_distinct))
    print('widest x offset: %d px' % widest)

    line = json.dumps(animations, separators=(',', ':'))
    text = re.sub(r'(global\.animations = )\[\[\[.*?\]\]\](;)',
                  lambda m: m.group(1) + line + m.group(2), text, count=1,
                  flags=re.S)
    open(GML, 'w', encoding='utf-8', newline='\n').write(text)
    print('wrote', GML)


main()
