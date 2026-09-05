#!/usr/bin/env python3
"""
Generate original commando sprites for the SettlersGM "borntodie" cheat.

All artwork here is drawn from scratch by parametric pixel plotting.
Nothing is derived from any commercial game's assets.

Canvas 32 x 32, origin (16, 20), figure centre column 16, ground contact y = 22.
That places the figure exactly where spr_serf_torso puts a serf (origin at the
figure's centre column, two pixels above the feet), so the soldier can be drawn
at the same screen position the serf would have been.

Settlers uses a 6-direction hex grid:
    0 right, 1 down_right, 2 down(-left), 3 left, 4 up_left, 5 up(-right)
Mirror pairs are 0<->3, 1<->2, 5<->4, so only the three right-facing views are
authored and the left-facing three are horizontal flips.
"""
import os
from PIL import Image

W, H = 32, 32
CX = 16          # origin x / figure centre column
BASE = 22        # ground contact row

# ---------------------------------------------------------------- palette
OUTLINE   = (26, 30, 18, 255)
HELM      = (78, 92, 50, 255)
HELM_HI   = (146, 166, 96, 255)
SKIN      = (240, 190, 140, 255)
SKIN_LO   = (198, 146, 96, 255)
JACKET    = (92, 116, 52, 255)
JACKET_HI = (128, 156, 78, 255)
JACKET_LO = (58, 76, 32, 255)
PACK      = (108, 92, 56, 255)
PACK_HI   = (140, 120, 76, 255)
WEBBING   = (52, 46, 32, 255)
LEGS      = (78, 98, 44, 255)
LEGS_LO   = (54, 70, 30, 255)
BOOT      = (40, 34, 26, 255)
GUN       = (46, 38, 28, 255)
GUN_METAL = (126, 126, 116, 255)
BLOOD     = (166, 34, 28, 255)

FLASH_A   = (255, 246, 190, 255)
FLASH_B   = (255, 184, 62, 255)
FLASH_C   = (240, 96, 28, 255)
SMOKE_A   = (128, 124, 116, 255)
SMOKE_B   = (82, 78, 72, 255)
GREN      = (66, 82, 44, 255)
GREN_HI   = (104, 124, 74, 255)


def new_frame(w=W, h=H):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((int(x), int(y)), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            px(im, x, y, c)


def hline(im, x0, x1, y, c):
    rect(im, x0, y, x1, y, c)


def vline(im, x, y0, y1, c):
    rect(im, x, y0, x, y1, c)


def line(im, x0, y0, x1, y1, c):
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        px(im, x0, y0, c)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def outline(im, c=OUTLINE):
    """Dark 4-neighbour edge, so the figure reads against grass."""
    src = im.copy()
    w, h = im.size
    op = [[src.getpixel((x, y))[3] > 0 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if op[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and op[ny][nx]:
                    px(im, x, y, c)
                    break
    return im


def mirror(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


# ------------------------------------------------------------ figure parts
# view: 'profile' (facing right), 'front' (3/4 towards camera, facing right),
#       'back'    (3/4 away from camera, facing right)

def draw_head(im, view, ox=0, oy=0):
    x, y = CX + ox, 6 + oy
    if view == 'profile':
        rect(im, x - 1, y, x + 2, y + 1, HELM)          # dome
        hline(im, x - 1, x + 1, y, HELM_HI)
        hline(im, x - 2, x + 3, y + 2, HELM)            # brim, longer at the front
        rect(im, x - 1, y + 3, x + 1, y + 3, SKIN)      # jaw
        px(im, x + 2, y + 3, SKIN)                      # nose
        px(im, x - 1, y + 3, SKIN_LO)
    elif view == 'front':
        rect(im, x - 2, y, x + 2, y + 1, HELM)
        hline(im, x - 1, x + 1, y, HELM_HI)
        hline(im, x - 3, x + 3, y + 2, HELM)
        rect(im, x - 2, y + 3, x + 2, y + 3, SKIN)
        px(im, x - 2, y + 3, SKIN_LO)
        px(im, x, y + 3, OUTLINE)                       # eyes
        px(im, x + 2, y + 3, OUTLINE)
    else:  # back
        rect(im, x - 2, y, x + 2, y + 2, HELM)
        hline(im, x - 1, x + 1, y, HELM_HI)
        hline(im, x - 3, x + 3, y + 2, HELM)
        hline(im, x - 2, x + 2, y + 3, HELM)            # helmet covers the nape
        px(im, x - 2, y + 3, SKIN_LO)                   # a sliver of neck
        px(im, x + 2, y + 3, SKIN_LO)


def draw_torso(im, view, lean=0, ox=0, oy=0):
    x, y = CX + ox + lean, 10 + oy
    if view == 'profile':
        rect(im, x - 1, y, x + 2, y + 4, JACKET)
        vline(im, x + 2, y, y + 4, JACKET_HI)           # lit chest edge
        vline(im, x - 1, y, y + 4, JACKET_LO)
        rect(im, x - 3, y, x - 2, y + 3, PACK)          # pack on the back
        px(im, x - 3, y, PACK_HI)
        hline(im, x - 1, x + 2, y + 5, WEBBING)
    elif view == 'front':
        rect(im, x - 2, y, x + 3, y + 4, JACKET)
        vline(im, x + 3, y, y + 4, JACKET_LO)
        vline(im, x - 2, y, y + 4, JACKET_HI)
        px(im, x, y + 1, WEBBING)                       # webbing straps
        px(im, x + 1, y + 2, WEBBING)
        px(im, x - 1, y + 3, WEBBING)
        hline(im, x - 2, x + 3, y + 5, WEBBING)
    else:  # back
        rect(im, x - 2, y, x + 3, y + 4, JACKET_LO)
        rect(im, x - 1, y, x + 2, y + 3, PACK)          # pack dominates the back
        hline(im, x - 1, x + 2, y, PACK_HI)
        px(im, x - 2, y + 2, JACKET)
        px(im, x + 3, y + 2, JACKET)
        hline(im, x - 2, x + 3, y + 5, WEBBING)


def draw_legs(im, view, phase, ox=0, oy=0):
    """phase 0..3 = walk cycle, -1 = stand."""
    x, y = CX + ox, 16 + oy
    if phase < 0:
        pose = [(-1, 0), (1, 0)]
    else:
        pose = [
            [(-1, 0), (1, 0)],      # passing
            [(-3, 1), (2, 0)],      # stride
            [(-1, 0), (1, 0)],      # passing
            [(2, 1), (-2, 0)],      # opposite stride
        ][phase]
    if view == 'profile':
        pose = [(dx, dy) for dx, dy in pose]
    for i, (dx, dy) in enumerate(pose):
        c = LEGS if i == 0 else LEGS_LO
        lx = x + dx
        rect(im, lx, y, lx + 1, BASE - 1 - dy, c)
        rect(im, lx - (1 if dx < 0 else 0), BASE - dy, lx + 1, BASE - dy, BOOT)


def draw_arms(im, view, weapon, ox=0, oy=0):
    """weapon: 'carry' | 'aim' | 'throw0' | 'throw1' | 'none'."""
    x, y = CX + ox, 11 + oy
    if weapon == 'none':
        px(im, x + 3, y + 1, JACKET_HI)
        px(im, x - 3, y + 1, JACKET_HI)
        return

    if weapon == 'carry':
        # rifle slung muzzle-up over the right shoulder: the barrel is the
        # silhouette cue that says "this one is armed" at any zoom, so the
        # upper half is the light metal colour to keep it off the dark outline
        line(im, x + 1, y + 4, x + 3, y - 1, GUN)
        line(im, x + 3, y - 2, x + 5, y - 6, GUN_METAL)
        px(im, x + 2, y + 1, JACKET_HI)       # gripping hand
        if view != 'profile':
            px(im, x - 3, y + 2, JACKET_HI)   # free arm
    elif weapon == 'aim':
        # levelled: barrel juts a long way clear of the body
        if view == 'back':
            line(im, x + 2, y + 1, x + 6, y - 1, GUN)
            px(im, x + 7, y - 2, GUN_METAL)
        else:
            hline(im, x + 2, x + 7, y + 1, GUN)
            px(im, x + 8, y + 1, GUN_METAL)
            px(im, x + 2, y + 2, GUN)         # magazine
        rect(im, x + 1, y, x + 2, y + 1, JACKET_HI)
        px(im, x + 4, y + 2, JACKET_HI)       # supporting hand under the barrel
    elif weapon == 'throw0':
        line(im, x + 1, y + 1, x - 4, y - 1, JACKET_HI)   # cocked back
        px(im, x - 5, y - 2, GREN)
        px(im, x + 2, y + 3, GUN)                          # rifle in the off hand
    elif weapon == 'throw1':
        line(im, x + 1, y + 1, x + 4, y - 4, JACKET_HI)    # released overhead
        px(im, x + 5, y - 5, GREN)
        px(im, x + 5, y - 6, GREN_HI)
        px(im, x - 2, y + 3, GUN)


# ------------------------------------------------------------ frame builders
def build_view(view, weapon, leg_phase, lean=0, oy=0, ox=0):
    im = new_frame()
    draw_legs(im, view, leg_phase, ox=ox, oy=oy)
    draw_torso(im, view, lean=lean, ox=ox, oy=oy)
    draw_head(im, view, ox=ox + lean, oy=oy)
    draw_arms(im, view, weapon, ox=ox + lean, oy=oy)
    return outline(im)


def frame_walk(view, phase):
    bob = -1 if phase in (1, 3) else 0
    return build_view(view, 'carry', phase, oy=bob)


def frame_stand(view):
    return build_view(view, 'carry', -1)


def frame_fire(view, phase):
    # phase 0 braced and leaning in, phase 1 shoved back by the recoil
    if phase == 0:
        return build_view(view, 'aim', -1, lean=1)
    return build_view(view, 'aim', -1, lean=0, ox=-1)


def frame_throw(view, phase):
    return build_view(view, 'throw%d' % phase, -1, lean=(-1 if phase == 0 else 1))


def frame_hit(view):
    im = new_frame()
    draw_legs(im, view, -1, oy=1)
    draw_torso(im, view, lean=-1, oy=1)
    draw_head(im, view, ox=-2, oy=2)
    draw_arms(im, view, 'none', oy=1)
    # exit spray, attached to the torso edge so it reads as a hit and not a mark
    px(im, CX + 3, 13, BLOOD)
    px(im, CX + 4, 12, BLOOD)
    px(im, CX + 4, 14, BLOOD)
    px(im, CX + 5, 13, BLOOD)
    return outline(im)


def frame_die(phase):
    """5-frame fall: buckle, topple, hit the dirt, settle, still."""
    im = new_frame()
    if phase == 0:
        draw_legs(im, 'front', -1, oy=2)
        draw_torso(im, 'front', lean=-1, oy=3)
        draw_head(im, 'front', ox=-2, oy=4)
        draw_arms(im, 'front', 'none', ox=-1, oy=3)
        px(im, CX + 4, 14, BLOOD)
    elif phase == 1:
        rect(im, CX - 2, 17, CX + 2, 19, LEGS_LO)
        rect(im, CX - 4, 20, CX - 2, BASE, BOOT)
        draw_torso(im, 'front', lean=-2, oy=6)
        draw_head(im, 'front', ox=-5, oy=8)
        px(im, CX + 5, 16, BLOOD)
    elif phase == 2:
        rect(im, CX - 3, 18, CX + 4, BASE - 1, JACKET)
        hline(im, CX - 3, CX + 4, BASE, JACKET_LO)
        rect(im, CX + 5, 19, CX + 7, BASE, LEGS_LO)     # legs flung out
        rect(im, CX - 6, 17, CX - 4, 19, HELM)          # helmet come loose
        px(im, CX - 7, 20, GUN)                          # dropped rifle
        px(im, CX - 6, 21, GUN)
    else:
        rect(im, CX - 3, 19, CX + 4, BASE, JACKET_LO)
        rect(im, CX + 5, 20, CX + 7, BASE, LEGS_LO)
        rect(im, CX - 6, 19, CX - 4, 21, HELM)
        line(im, CX - 8, 22, CX - 5, 20, GUN)
        if phase == 4:
            hline(im, CX - 5, CX + 2, BASE + 1, BLOOD)
            px(im, CX - 1, BASE + 2, BLOOD)
            px(im, CX + 3, BASE + 1, BLOOD)
    return outline(im)


# ------------------------------------------------------------ effects sheet
FW, FH = 16, 16
FCX, FCY = 8, 8


def fx_flash(phase):
    im = new_frame(FW, FH)
    r = [2, 4, 3][phase]
    for i in range(r, 0, -1):
        c = [FLASH_A, FLASH_B, FLASH_C][min(2, r - i)]
        hline(im, FCX - i, FCX + i, FCY, c)
        vline(im, FCX, FCY - i + 1, FCY + i - 1, c)
        if i > 1:
            px(im, FCX + i - 1, FCY - 1, c)
            px(im, FCX + i - 1, FCY + 1, c)
    px(im, FCX, FCY, FLASH_A)
    return im


def fx_grenade(phase):
    im = new_frame(FW, FH)
    rect(im, FCX - 1, FCY - 1, FCX + 1, FCY + 1, GREN)
    px(im, FCX, FCY - 1, GREN_HI)
    spin = [(2, -2), (2, 2), (-2, 1)][phase]
    px(im, FCX + spin[0], FCY + spin[1], GUN_METAL)
    return outline(im)


def fx_explosion(phase):
    im = new_frame(FW, FH)
    if phase < 3:
        r = [3, 5, 7][phase]
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                dd = x * x + y * y
                if dd <= r * r:
                    if dd <= (r - 3) ** 2:
                        c = FLASH_A
                    elif dd <= (r - 1) ** 2:
                        c = FLASH_B
                    else:
                        c = FLASH_C
                    px(im, FCX + x, FCY + y, c)
    else:
        # dissipating smoke: a few overlapping puffs rather than a neat ring,
        # drifting up and apart as the phase advances
        k = phase - 3
        puffs = [
            [(-4, -2, 3), (2, -3, 3), (0, 1, 3), (-2, 3, 2), (4, 2, 2)],
            [(-5, -4, 3), (3, -5, 2), (0, -1, 3), (-3, 2, 2), (5, 0, 2)],
            [(-5, -6, 2), (4, -6, 2), (0, -4, 2), (-4, -1, 2), (5, -3, 1)],
        ][k]
        for cx, cy, r in puffs:
            for y in range(-r, r + 1):
                for x in range(-r, r + 1):
                    if x * x + y * y <= r * r:
                        c = SMOKE_A if (x + y) % 2 == 0 else SMOKE_B
                        px(im, FCX + cx + x, FCY + cy + y, c)
        if phase == 3:
            rect(im, FCX - 2, FCY - 1, FCX + 2, FCY + 1, FLASH_C)
            rect(im, FCX - 1, FCY, FCX + 1, FCY, FLASH_B)
    return im


def fx_fire(phase):
    """6-frame flame loop, rising from the bottom of the cell."""
    im = new_frame(FW, FH)
    sway = [0, 1, 1, 0, -1, -1][phase]
    tips = [6, 8, 9, 8, 6, 7][phase]
    for y in range(tips):
        yy = FH - 2 - y
        t = y / max(1, tips - 1)          # 0 at the base, 1 at the tip
        half = max(0, int(round((1.0 - t * t) * 2.6)))
        cx = FCX + int(round(sway * t * t * 3))
        for x in range(cx - half, cx + half + 1):
            # hottest at the base, cooling towards the tip
            if t < 0.35:
                c = FLASH_A
            elif t < 0.7:
                c = FLASH_B
            else:
                c = FLASH_C
            px(im, x, yy, c)
        # cooler outer edge, so the flame is not a flat slab of colour
        if half > 0 and t < 0.7:
            px(im, cx - half, yy, FLASH_B if t < 0.35 else FLASH_C)
            px(im, cx + half, yy, FLASH_B if t < 0.35 else FLASH_C)
    for y in range(2):
        px(im, FCX + sway * 3, FH - 2 - tips - y, SMOKE_A if y == 0 else SMOKE_B)
    return im


def fx_impact(phase):
    im = new_frame(FW, FH)
    r = [1, 2, 3][phase]
    c = [BLOOD, BLOOD, SMOKE_B][phase]
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            if abs(x) + abs(y) == r:
                px(im, FCX + x, FCY + y, c)
    return im


# ------------------------------------------------------------ build
VIEW_FOR_DIR = {0: 'profile', 1: 'front', 5: 'back'}
MIRROR_OF = {3: 0, 2: 1, 4: 5}


def per_dir(make):
    """Build all 6 directions from the three right-facing views."""
    out = {}
    for d, view in VIEW_FOR_DIR.items():
        out[d] = make(view)
    for d, src in MIRROR_OF.items():
        out[d] = [mirror(f) for f in out[src]]
    return [out[d] for d in range(6)]


def build():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cf_build")
    os.makedirs(out + "/soldier", exist_ok=True)
    os.makedirs(out + "/fx", exist_ok=True)

    walk = per_dir(lambda v: [frame_walk(v, p) for p in range(4)])
    stand = per_dir(lambda v: [frame_stand(v)])
    fire = per_dir(lambda v: [frame_fire(v, p) for p in range(2)])
    throw = per_dir(lambda v: [frame_throw(v, p) for p in range(2)])
    hit = per_dir(lambda v: [frame_hit(v)])

    soldier = []
    for d in range(6):
        soldier += walk[d]        # 0..23   4 per dir
    for d in range(6):
        soldier += stand[d]       # 24..29  1 per dir
    for d in range(6):
        soldier += fire[d]        # 30..41  2 per dir
    for d in range(6):
        soldier += throw[d]       # 42..53  2 per dir
    for d in range(6):
        soldier += hit[d]         # 54..59  1 per dir
    soldier += [frame_die(p) for p in range(5)]   # 60..64

    fx = []
    fx += [fx_flash(p) for p in range(3)]         # 0..2
    fx += [fx_grenade(p) for p in range(3)]       # 3..5
    fx += [fx_explosion(p) for p in range(6)]     # 6..11
    fx += [fx_fire(p) for p in range(6)]          # 12..17
    fx += [fx_impact(p) for p in range(3)]        # 18..20

    for i, im in enumerate(soldier):
        im.save("%s/soldier/%03d.png" % (out, i))
    for i, im in enumerate(fx):
        im.save("%s/fx/%03d.png" % (out, i))

    def sheet(frames, cols, scale, path, bg=(72, 108, 44, 255)):
        fw, fh = frames[0].size
        rows = (len(frames) + cols - 1) // cols
        s = Image.new("RGBA", (cols * fw * scale, rows * fh * scale), bg)
        for i, im in enumerate(frames):
            big = im.resize((fw * scale, fh * scale), Image.NEAREST)
            s.alpha_composite(big, ((i % cols) * fw * scale, (i // cols) * fh * scale))
        s.save(path)

    sheet(soldier, 12, 4, out + "/sheet_soldier.png")
    sheet(fx, 12, 5, out + "/sheet_fx.png", bg=(40, 40, 40, 255))
    print("soldier frames:", len(soldier))
    print("fx frames:", len(fx))


if __name__ == "__main__":
    build()
