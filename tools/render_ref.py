"""Reference renderer: same algorithm as scr_viewport.gml, using the baked project sprites.
Produces ref_screen.png so the GameMaker output can be compared against it."""
import json, os
from PIL import Image

P = '/home/claude/settlers/SettlersGM/sprites'
m = json.load(open('/home/claude/settlers/ref_map.json'))
COLS, ROWS = m['cols'], m['rows']
COL_MASK, ROW_MASK, ROW_SHIFT = COLS - 1, ROWS - 1, 6
TW, TH = 32, 20

def load_sprite(name):
    yy = json.load(open(f'{P}/{name}/{name}.yy'))
    frames = [Image.open(f"{P}/{name}/{f['name']}.png").convert('RGBA') for f in yy['frames']]
    return frames, yy['sequence']['xorigin'], yy['sequence']['yorigin']

SPR = {n: load_sprite(n) for n in ['spr_ground_up', 'spr_ground_down', 'spr_map_object', 'spr_map_shadow',
                                    'spr_game_object', 'spr_map_waves', 'spr_waves_up', 'spr_waves_down',
                                    'spr_frame_bottom', 'spr_panel_button']}

def draw_sprite(img, name, idx, x, y):
    frames, ox, oy = SPR[name]
    f = frames[idx]
    img.alpha_composite(f, (x - ox, y - oy)) if (x - ox >= 0 and y - oy >= 0 and x - ox + f.width <= img.width and y - oy + f.height <= img.height) else paste_clip(img, f, x - ox, y - oy)

def paste_clip(img, f, x, y):
    # alpha composite with clipping
    l = max(0, -x); t = max(0, -y); r = min(f.width, img.width - x); b = min(f.height, img.height - y)
    if r <= l or b <= t: return
    img.alpha_composite(f.crop((l, t, r, b)), (x + l, y + t))

def pos(c, r): return (r << ROW_SHIFT) | c
def pos_col(p): return p & COL_MASK
def pos_row(p): return (p >> ROW_SHIFT) & ROW_MASK
def pos_add(p, dx, dy): return pos((pos_col(p) + dx) & COL_MASK, (pos_row(p) + dy) & ROW_MASK)
def move_right(p): return pos_add(p, 1, 0)
def move_down(p): return pos_add(p, 0, 1)
def move_down_right(p): return pos_add(p, 1, 1)
def move_up(p): return pos_add(p, 0, -1)
def move_up_left(p): return pos_add(p, -1, -1)
H = m['height']; TU = m['type_up']; TD = m['type_down']; OBJ = m['obj']

tri_spr = [32]*32 + list(range(8))*4 + list(range(24,32))*3 + list(range(8,16))*3 + list(range(16,24))*2
tri_mask_up = [0,1,3,6,7,-1,-1,-1,-1, 0,1,2,5,6,7,-1,-1,-1, 0,1,2,3,5,6,7,-1,-1, 0,1,2,3,4,5,6,7,-1,
               0,1,2,3,4,4,5,6,7, -1,0,1,2,3,4,5,6,7, -1,-1,0,1,2,4,5,6,7, -1,-1,-1,0,1,2,5,6,7, -1,-1,-1,-1,0,1,4,6,7]
tri_mask_down = [0,0,0,0,0,-1,-1,-1,-1, 1,1,1,1,1,0,-1,-1,-1, 3,2,2,2,2,1,0,-1,-1, 6,5,3,3,3,2,1,0,-1,
                 7,6,5,4,4,3,2,1,0, -1,7,6,5,4,4,4,2,1, -1,-1,7,6,5,5,5,5,4, -1,-1,-1,7,6,6,6,6,6, -1,-1,-1,-1,7,7,7,7,7]

def tri_up(img, lx, ly, mm, left, right, p):
    mask = 4 + mm - left + 9*(4 + mm - right)
    assert tri_mask_up[mask] >= 0
    t = TU[move_up(p)]
    spr = tri_spr[(t << 3) | tri_mask_up[mask]]
    draw_sprite(img, 'spr_ground_up', mask*33 + spr, lx, ly)

def tri_down(img, lx, ly, mm, left, right, p):
    mask = 4 + left - mm + 9*(4 + right - mm)
    assert tri_mask_down[mask] >= 0
    t = TD[move_up_left(p)]
    spr = tri_spr[(t << 3) | tri_mask_down[mask]]
    draw_sprite(img, 'spr_ground_down', mask*33 + spr, lx, ly + TH)

def up_tile_col(img, p, xb, yb, max_y):
    mm = H[p]; goto_down = False
    while True:
        p = move_down(p); left = H[p]; right = H[move_right(p)]
        if yb + TH - 4*min(left, right) >= 0: break
        yb += TH; p = move_down_right(p); mm = H[p]
        if yb + TH - 4*mm >= 0: goto_down = True; break
        yb += TH
    while True:
        if not goto_down:
            if yb - 2*TH - 4*mm >= max_y: break
            tri_up(img, xb, yb - 4*mm, mm, left, right, p)
            yb += TH; p = move_down_right(p); mm = H[p]
            if yb - 2*TH - 4*max(left, right) >= max_y: break
        goto_down = False
        tri_down(img, xb, yb - 4*mm, mm, left, right, p)
        yb += TH; p = move_down(p); left = H[p]; right = H[move_right(p)]

def down_tile_col(img, p, xb, yb, max_y):
    left = H[p]; right = H[move_right(p)]; mm = 0; goto_down = False
    while True:
        p = move_down_right(p); mm = H[p]
        if yb + TH - 4*mm >= 0: goto_down = True; break
        yb += TH; p = move_down(p); left = H[p]; right = H[move_right(p)]
        if yb + TH - 4*min(left, right) >= 0: break
        yb += TH
    while True:
        if not goto_down:
            if yb - 2*TH - 4*mm >= max_y: break
            tri_up(img, xb, yb - 4*mm, mm, left, right, p)
            yb += TH; p = move_down_right(p); mm = H[p]
            if yb - 2*TH - 4*max(left, right) >= max_y: break
        goto_down = False
        tri_down(img, xb, yb - 4*mm, mm, left, right, p)
        yb += TH; p = move_down(p); left = H[p]; right = H[move_right(p)]

TILE_W, TILE_H = 16*TW, 16*TH
tiles = {}
def tile(tc, tr):
    tid = (tc, tr)
    if tid in tiles: return tiles[tid]
    img = Image.new('RGBA', (TILE_W, TILE_H), (0, 0, 0, 255))
    col = (tc*16 + (tr*16)//2) % COLS; row = tr*16
    p = pos(col, row); xb = -16
    for c in range(17):
        up_tile_col(img, p, xb, 0, TILE_H)
        down_tile_col(img, p, xb + 16, 0, TILE_H)
        p = move_right(p); xb += TW
    tiles[tid] = img
    return img

W, HH = 640, 400
def draw_landscape(screen, off_x, off_y):
    map_w, map_h = COLS*TW, ROWS*TH
    my = off_y; ly = 0; xb = 0
    while ly < HH:
        while my >= map_h: my -= map_h; xb += ROWS*TW//2
        ty = my % TILE_H; lx = 0; mx = (off_x + xb) % map_w
        while lx < W:
            tx = mx % TILE_W
            t = tile((mx//TILE_W) % (COLS//16), (my//TILE_H) % (ROWS//16))
            w = min(TILE_W - tx, W - lx); h = min(TILE_H - ty, HH - ly)
            screen.paste(t.crop((tx, ty, tx+w, ty+h)), (lx, ly))
            lx += TILE_W - tx; mx += TILE_W - tx
        ly += TILE_H - ty; my += TILE_H - ty

def draw_objects(screen, off_x, off_y, tick=0):
    cols = 2*(W//TW) + 1; short = ((cols+1) >> 1) + 1; long_ = ((cols+2) >> 1) + 1
    lx = -((off_x + 16*(off_y//20)) % 32); ly = -(off_y % 20)
    p = pos(((off_x//16 + off_y//20)//2) & COL_MASK, (off_y//TH) & ROW_MASK)
    def row(p, yb, n, xb):
        for i in range(n):
            if TU[p] <= 3 or TD[p] <= 3:
                s = ((p ^ 5) + (tick >> 3)) & 0xf
                if TD[p] <= 3 and TU[p] <= 3: draw_sprite(screen, 'spr_map_waves', s, xb-16, yb)
                elif TD[p] <= 3: draw_sprite(screen, 'spr_waves_down', s, xb, yb+16)
                else: draw_sprite(screen, 'spr_waves_up', s, xb-16, yb)
            o = OBJ[p]
            if o >= 8:
                s = o - 8
                if s < 24:
                    ta = (tick + s) >> 4
                    s = (s & ~7) + (ta & 7) if s < 16 else (s & ~3) + (ta & 3)
                yy = yb - 4*H[p]
                draw_sprite(screen, 'spr_map_shadow', s, xb, yy); draw_sprite(screen, 'spr_map_object', s, xb, yy)
            xb += TW; p = move_right(p)
    while True:
        row(p, ly, short, lx); ly += TH
        if ly >= HH + 6*TH: break
        p = move_down(p); row(p, ly, long_, lx - 16); ly += TH
        if ly >= HH + 6*TH: break
        p = move_down_right(p)

def map_pix(p):
    mx = TW*pos_col(p) - 16*pos_row(p); my = TH*pos_row(p) - 4*H[p]
    if my < 0: mx -= ROWS*TW//2; my += ROWS*TH
    if mx < 0: mx += COLS*TW
    elif mx >= COLS*TW: mx -= COLS*TW
    return mx, my

def screen_pix(p, off_x, off_y):
    mx, my = map_pix(p); sx = mx - off_x; sy = my - off_y
    while sy < 0: sx -= ROWS*TW//2; sy += ROWS*TH
    while sy >= ROWS*TH: sx += ROWS*TW//2; sy -= ROWS*TH
    while sx < 0: sx += COLS*TW
    while sx >= COLS*TW: sx -= COLS*TW
    return sx, sy

if __name__ == '__main__':
    cursor = pos(32, 32)
    mx, my = map_pix(cursor); off_x = mx - W//2; off_y = my - HH//2
    if off_y < 0: off_x -= ROWS*TW//2; off_y += ROWS*TH
    if off_x < 0: off_x += COLS*TW
    elif off_x >= COLS*TW: off_x -= COLS*TW
    screen = Image.new('RGBA', (W, HH), (0, 0, 0, 255))
    draw_landscape(screen, off_x, off_y)
    draw_objects(screen, off_x, off_y)
    sx, sy = screen_pix(cursor, off_x, off_y); draw_sprite(screen, 'spr_game_object', 31, sx, sy)
    for d, (dx, dy) in enumerate([(1,0),(1,1),(0,1),(-1,0),(-1,-1),(0,-1)]):
        n = pos_add(cursor, dx, dy); sx, sy = screen_pix(n, off_x, off_y); draw_sprite(screen, 'spr_game_object', 32, sx, sy)
    layout = [6,0,0, 0,40,0, 20,48,0, 7,64,0, 8,64,36, 21,96,0, 9,112,0, 10,112,36, 22,144,0, 11,160,0, 12,160,36,
              23,192,0, 13,208,0, 14,208,36, 24,240,0, 15,256,0, 16,256,36, 25,288,0, 1,304,0, 6,312,0]
    px, py = (W-352)//2, HH-40
    fb = SPR['spr_frame_bottom'][0]
    for i in range(0, len(layout), 3):
        if fb[layout[i]].getbbox(): draw_sprite(screen, 'spr_frame_bottom', layout[i], px+layout[i+1], py+layout[i+2])
    for i, b in enumerate([0, 7, 10, 12, 14]):
        draw_sprite(screen, 'spr_panel_button', b, px + 64 + i*48, py + 4)
    screen.save('/home/claude/settlers/ref_screen.png')
    print('ok', off_x, off_y)
