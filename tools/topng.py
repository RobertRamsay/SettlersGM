import json, os
from PIL import Image
m = json.load(open('out/meta.json'))
for s in m['sprites']:
    d = 'out/' + s['res']
    if "w" in s and s["w"]>0 and s["h"]>0 and os.path.exists(f"{d}/{s['index']}.rgba"):
        raw = open(f"{d}/{s['index']}.rgba",'rb').read()
        im = Image.frombytes('RGBA', (s['w'], s['h']), raw, 'raw', 'BGRA')
        im.save(f"{d}/{s['index']}.png"); os.remove(f"{d}/{s['index']}.rgba")
    if "mw" in s and s["mw"]>0 and s["mh"]>0 and os.path.exists(f"{d}/{s['index']}_mask.rgba"):
        raw = open(f"{d}/{s['index']}_mask.rgba",'rb').read()
        im = Image.frombytes('RGBA', (s['mw'], s['mh']), raw, 'raw', 'BGRA')
        im.save(f"{d}/{s['index']}_mask.png"); os.remove(f"{d}/{s['index']}_mask.rgba")
# contact sheets
for res in ['map_ground','map_object','game_object','icon','serf_torso','frame_bottom','map_mask_up','panel_button']:
    files = sorted([f for f in os.listdir('out/'+res) if f.endswith('.png') and '_mask' not in f], key=lambda f:int(f[:-4]))[:120]
    ims = [Image.open('out/'+res+'/'+f) for f in files]
    cw = max(i.width for i in ims)+4; ch = max(i.height for i in ims)+4
    cols = 12; rows = (len(ims)+cols-1)//cols
    sheet = Image.new('RGBA',(cw*cols, ch*rows),(255,0,255,255))
    for k,i in enumerate(ims): sheet.paste(i,((k%cols)*cw,(k//cols)*ch),i)
    sheet.save(f'sheet_{res}.png')
print('done')
