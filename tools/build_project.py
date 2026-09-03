#!/usr/bin/env python3
"""Builds the SettlersGM GameMaker Studio 2026 LTS project from extracted assets."""
import json, os, shutil, uuid, wave
from collections import defaultdict
from PIL import Image

SRC = '/home/claude/settlers/out'
GML = '/home/claude/settlers/gml'
OUT = '/home/claude/settlers/SettlersGM'
NAME = 'SettlersGM'

def uid():
    return str(uuid.uuid4())

def gm_inline(v):
    """GameMaker's own serialisation style for objects nested in arrays: single line, trailing commas."""
    if isinstance(v, dict):
        return "{" + "".join(json.dumps(k) + ":" + gm_inline(x) + "," for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "[" + "".join(gm_inline(x) + "," for x in v) + "]"
    return json.dumps(v)

def gm_multiline(v, indent):
    pad = " " * (indent + 2)
    if isinstance(v, dict):
        if not v:
            return "{}"
        out = "{\n"
        for k, x in v.items():
            out += pad + json.dumps(k) + ":" + gm_multiline(x, indent + 2) + ",\n"
        return out + " " * indent + "}"
    if isinstance(v, list):
        if not v:
            return "[]"
        if all(isinstance(x, (dict, list)) for x in v):
            out = "[\n"
            for x in v:
                out += pad + gm_inline(x) + ",\n"
            return out + " " * indent + "]"
        return gm_inline(v)
    return json.dumps(v)

def dump(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', newline='\n') as f:
        f.write(gm_multiline(obj, 0))

# ---------------------------------------------------------------- metadata
meta = json.load(open(f'{SRC}/meta.json'))
by_res = defaultdict(dict)
for s in meta['sprites']:
    by_res[s['res']][s['index']] = s

resources = []   # yyp resource list
folders = []

def add_folder(name):
    folders.append({"$GMFolder": "", "%Name": name, "folderPath": f"folders/{name}.yy",
                    "name": name, "resourceType": "GMFolder", "resourceVersion": "2.0"})

for fn in ["Sprites", "Sounds", "Scripts", "Objects", "Rooms"]:
    add_folder(fn)

# ---------------------------------------------------------------- sprites
def write_sprite(name, frames, ox, oy, folder="Sprites"):
    """frames: list of PIL RGBA images all the same size."""
    w, h = frames[0].size
    sdir = f'{OUT}/sprites/{name}'
    os.makedirs(f'{sdir}/layers', exist_ok=True)
    layer_id = uid()
    frame_ids = []
    for im in frames:
        fid = uid()
        frame_ids.append(fid)
        im.save(f'{sdir}/{fid}.png')
        os.makedirs(f'{sdir}/layers/{fid}', exist_ok=True)
        im.save(f'{sdir}/layers/{fid}/{layer_id}.png')
    keyframes = []
    for i, fid in enumerate(frame_ids):
        keyframes.append({
            "$Keyframe<SpriteFrameKeyframe>": "",
            "Channels": {"0": {"$SpriteFrameKeyframe": "",
                               "Id": {"name": fid, "path": f"sprites/{name}/{name}.yy"},
                               "resourceType": "SpriteFrameKeyframe", "resourceVersion": "2.0"}},
            "Disabled": False, "id": uid(), "IsCreationKey": False, "Key": float(i),
            "Length": 1.0,
            "resourceType": "Keyframe<SpriteFrameKeyframe>", "resourceVersion": "2.0", "Stretch": False})
    yy = {
        "$GMSprite": "v2", "%Name": name,
        "bboxMode": 0, "bbox_bottom": h - 1, "bbox_left": 0, "bbox_right": w - 1, "bbox_top": 0,
        "collisionKind": 1, "collisionTolerance": 0,
        "DynamicTexturePage": False, "edgeFiltering": False, "For3D": False,
        "frames": [{"$GMSpriteFrame": "v1", "%Name": fid, "name": fid,
                    "resourceType": "GMSpriteFrame", "resourceVersion": "2.0"} for fid in frame_ids],
        "gridX": 0, "gridY": 0, "height": h, "HTile": False,
        "layers": [{"$GMImageLayer": "", "%Name": layer_id, "blendMode": 0, "displayName": "default",
                    "isLocked": False, "name": layer_id, "opacity": 100.0,
                    "resourceType": "GMImageLayer", "resourceVersion": "2.0", "visible": True}],
        "name": name, "nineSlice": None, "origin": 9,
        "parent": {"name": folder, "path": f"folders/{folder}.yy"},
        "preMultiplyAlpha": False, "resourceType": "GMSprite", "resourceVersion": "2.0",
        "sequence": {
            "$GMSequence": "v1", "%Name": name, "autoRecord": True, "backdropHeight": 768,
            "backdropImageOpacity": 0.5, "backdropImagePath": "", "backdropWidth": 1366,
            "backdropXOffset": 0.0, "backdropYOffset": 0.0,
            "events": {"$KeyframeStore<MessageEventKeyframe>": "", "Keyframes": [],
                       "resourceType": "KeyframeStore<MessageEventKeyframe>", "resourceVersion": "2.0"},
            "eventStubScript": None, "eventToFunction": {}, "length": float(len(frame_ids)),
            "lockOrigin": False,
            "moments": {"$KeyframeStore<MomentsEventKeyframe>": "", "Keyframes": [],
                        "resourceType": "KeyframeStore<MomentsEventKeyframe>", "resourceVersion": "2.0"},
            "name": name, "playback": 1, "playbackSpeed": 0.0, "playbackSpeedType": 0,
            "resourceType": "GMSequence", "resourceVersion": "2.0",
            "showBackdrop": True, "showBackdropImage": False,
            "timeUnits": 1,
            "tracks": [{"$GMSpriteFramesTrack": "", "builtinName": 0, "events": [],
                        "inheritsTrackColour": True, "interpolation": 1, "isCreationTrack": False,
                        "keyframes": {"$KeyframeStore<SpriteFrameKeyframe>": "", "Keyframes": keyframes,
                                      "resourceType": "KeyframeStore<SpriteFrameKeyframe>", "resourceVersion": "2.0"},
                        "modifiers": [], "name": "frames", "resourceType": "GMSpriteFramesTrack",
                        "resourceVersion": "2.0", "spriteId": None, "trackColour": 0, "tracks": [],
                        "traits": 0}],
            "visibleRange": None, "volume": 1.0, "xorigin": ox, "yorigin": oy},
        "swatchColours": None, "swfPrecision": 0.5,
        "textureGroupId": {"name": "Default", "path": "texturegroups/Default"},
        "type": 0, "VTile": False, "width": w}
    dump(f'{sdir}/{name}.yy', yy)
    resources.append({"id": {"name": name, "path": f"sprites/{name}/{name}.yy"}})

def load_png(res, index, mask=False):
    suffix = '_mask' if mask else ''
    p = f'{SRC}/{res}/{index}{suffix}.png'
    if os.path.exists(p):
        return Image.open(p).convert('RGBA')
    return None

def category_canvas(res, use_mask):
    entries = by_res[res]
    boxes = []
    for i, s in entries.items():
        if use_mask and 'mw' in s:
            boxes.append((s['mox'], s['moy'], s['mw'], s['mh']))
        elif not use_mask and 'w' in s:
            boxes.append((s['ox'], s['oy'], s['w'], s['h']))
    minx = min(b[0] for b in boxes); miny = min(b[1] for b in boxes)
    maxx = max(b[0] + b[2] for b in boxes); maxy = max(b[1] + b[3] for b in boxes)
    return minx, miny, maxx - minx, maxy - miny

def build_category(res, count, use_mask=False):
    minx, miny, cw, ch = category_canvas(res, use_mask)
    frames = []
    for i in range(count):
        canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        s = by_res[res].get(i)
        if s is not None:
            im = load_png(res, i, use_mask)
            if im is not None:
                if use_mask:
                    canvas.paste(im, (s['mox'] - minx, s['moy'] - miny))
                else:
                    canvas.paste(im, (s['ox'] - minx, s['oy'] - miny))
        frames.append(canvas)
    return frames, -minx, -miny

COUNTS = {"art_landscape": 1, "serf_shadow": 1, "dotted_lines": 7, "art_flag": 7, "art_box": 14,
          "credits_bg": 1, "logo": 1, "symbol": 16, "map_mask_up": 81, "map_mask_down": 81,
          "path_mask": 27, "map_ground": 33, "path_ground": 10, "game_object": 279,
          "frame_top": 4, "map_border": 10, "map_waves": 16, "frame_popup": 4, "indicator": 8,
          "font": 44, "font_shadow": 44, "icon": 318, "map_object": 194, "map_shadow": 194,
          "panel_button": 25, "frame_bottom": 26, "serf_torso": 541, "serf_head": 630,
          "frame_split": 3, "cursor": 1}

sprite_meta = {}   # name -> per-frame [ox, oy, dx, dy, w, h] for GML tables

for res, count in COUNTS.items():
    if res not in by_res:
        continue
    has_image = any('w' in s for s in by_res[res].values())
    has_mask = any('mw' in s for s in by_res[res].values())
    if has_image:
        frames, ox, oy = build_category(res, count, False)
        write_sprite(f'spr_{res}', frames, ox, oy)
    if has_mask:
        frames, ox, oy = build_category(res, count, True)
        write_sprite(f'spr_{res}_mask', frames, ox, oy)
    rows = []
    for i in range(count):
        s = by_res[res].get(i)
        if s is None:
            rows.append([0, 0, 0, 0, 0, 0, 0])
        elif 'w' in s:
            rows.append([1, s['ox'], s['oy'], s['dx'], s['dy'], s['w'], s['h']])
        else:
            rows.append([1, s['mox'], s['moy'], s['mdx'], s['mdy'], s['mw'], s['mh']])
    sprite_meta[res] = rows
    print('sprite', res, count, 'img' if has_image else '', 'mask' if has_mask else '')

# ---------------------------------------------------------------- baked ground (mask x ground)
def apply_mask(ground, mask):
    """Port of SpriteBase::get_masked: ground tiled vertically, AND with mask."""
    mw, mh = mask.size
    gw, gh = ground.size
    out = Image.new('RGBA', (mw, mh), (0, 0, 0, 0))
    gp = ground.load(); mp = mask.load(); op = out.load()
    # C++ walks the source linearly with wraparound; source width == mask width (32)
    spos = 0
    total = gw * gh
    for y in range(mh):
        for x in range(mw):
            if spos >= total:
                spos = 0
            sx = spos % gw; sy = spos // gw
            r, g, b, a = gp[sx, sy]
            mr, mg, mb, ma = mp[x, y]
            op[x, y] = (r & mr, g & mg, b & mb, a & ma)
            spos += 1
        spos += gw - mw
    return out

def bake(mask_res, mask_count, ground_res, ground_count, name, ground_base=0):
    minx, miny, cw, ch = category_canvas(mask_res, False)
    frames = []
    for m in range(mask_count):
        ms = by_res[mask_res].get(m)
        mim = load_png(mask_res, m) if ms is not None else None
        for g in range(ground_count):
            canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
            gim = load_png(ground_res, ground_base + g)
            if mim is not None and gim is not None:
                canvas.paste(apply_mask(gim, mim), (ms['ox'] - minx, ms['oy'] - miny))
            frames.append(canvas)
    write_sprite(name, frames, -minx, -miny)
    print('baked', name, len(frames))

bake('map_mask_up', 81, 'map_ground', 33, 'spr_ground_up')
bake('map_mask_down', 81, 'map_ground', 33, 'spr_ground_down')
# Roads are NOT drawn with the terrain texture. Freeserf's Amiga data source
# maps AssetPathGround onto get_ground_sprite(index), i.e. the same tiles as the
# terrain, which makes a road over grass green-on-green and effectively
# invisible. In the original the road is always the sand ramp, so bake the road
# from ground tiles 10..19: 10-12 normal terrain, 13-15 desert, 16-18 snow,
# 19 water (draw_path_segment adds +3 / +6 / uses 9 for those cases).
bake('path_mask', 27, 'map_ground', 10, 'spr_path_baked', ground_base=10)

# waves: full (unmasked) waves are spr_map_waves; masked with mask 40 up/down
def bake_waves(mask_res, name):
    ms = by_res[mask_res][40]
    mim = load_png(mask_res, 40)
    minx, miny, cw, ch = category_canvas(mask_res, False)
    frames = []
    for i in range(16):
        canvas = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        wim = load_png('map_waves', i)
        canvas.paste(apply_mask(wim, mim), (ms['ox'] - minx, ms['oy'] - miny))
        frames.append(canvas)
    write_sprite(name, frames, -minx, -miny)
bake_waves('map_mask_up', 'spr_waves_up')
bake_waves('map_mask_down', 'spr_waves_down')

# ---------------------------------------------------------------- sounds
def write_sound(name, src, ext, kind):
    sdir = f'{OUT}/sounds/{name}'
    os.makedirs(sdir, exist_ok=True)
    shutil.copy(src, f'{sdir}/{name}.{ext}')
    duration = 1.0
    if ext == 'wav':
        with wave.open(src) as w:
            duration = w.getnframes() / float(w.getframerate())
    yy = {"$GMSound": "", "%Name": name,
          "audioGroupId": {"name": "audiogroup_default", "path": "audiogroups/audiogroup_default"},
          "bitDepth": 1, "bitRate": 128, "compression": 0 if kind == 'sfx' else 1, "conversionMode": 0,
          "duration": duration, "name": name, "parent": {"name": "Sounds", "path": "folders/Sounds.yy"},
          "preload": True, "resourceType": "GMSound", "resourceVersion": "2.0", "sampleRate": 44100,
          "soundFile": f"{name}.{ext}", "type": 0 if kind == 'sfx' else 1, "volume": 1.0}
    dump(f'{sdir}/{name}.yy', yy)
    resources.append({"id": {"name": name, "path": f"sounds/{name}/{name}.yy"}})

sound_indices = []
for f in sorted(os.listdir(f'{SRC}/sound'), key=lambda x: int(x.split('.')[0])):
    idx = int(f.split('.')[0])
    sound_indices.append(idx)
    write_sound(f'snd_{idx}', f'{SRC}/sound/{f}', 'wav', 'sfx')
write_sound('mus_settlers', f'{SRC}/music/settlers.ogg', 'ogg', 'music')

# ---------------------------------------------------------------- scripts
def write_script(name, code):
    sdir = f'{OUT}/scripts/{name}'
    os.makedirs(sdir, exist_ok=True)
    open(f'{sdir}/{name}.gml', 'w').write(code)
    dump(f'{sdir}/{name}.yy', {"$GMScript": "v1", "%Name": name, "isCompatibility": False, "isDnD": False,
                               "name": name, "parent": {"name": "Scripts", "path": "folders/Scripts.yy"},
                               "resourceType": "GMScript", "resourceVersion": "2.0"})
    resources.append({"id": {"name": name, "path": f"scripts/{name}/{name}.yy"}})

for f in sorted(os.listdir(GML)):
    if f.endswith('.gml'):
        write_script(f[:-4], open(f'{GML}/{f}').read())

# generated sprite metadata script
lines = ["// scr_sprite_meta.gml - GENERATED by build_project.py from the Amiga data files.",
         "// Per-frame metadata: [present, offset_x, offset_y, delta_x, delta_y, width, height]",
         "// matching Freeserf's Sprite offset/delta values. Offsets are already baked into the",
         "// GameMaker sprite origins; deltas are used for relative drawing (serf heads).",
         "function sprite_meta_init() {",
         "    global.sprite_meta = {};"]
for res, rows in sprite_meta.items():
    lines.append(f"    global.sprite_meta.{res} = {json.dumps(rows, separators=(',', ':'))};")
lines.append("    global.animations = " + json.dumps(meta['animations'], separators=(',', ':')) + ";")
lines.append("    global.sound_index_map = " + json.dumps(sound_indices) + ";")
lines.append("    global.sound_assets = [" + ", ".join(f"snd_{i}" for i in sound_indices) + "];")
lines.append("}")
write_script('scr_sprite_meta', "\n".join(lines) + "\n")

# ---------------------------------------------------------------- objects
EVENT_FILES = {"Create_0": (0, 0), "Alarm_0": (2, 0), "Step_0": (3, 0), "Draw_0": (8, 0), "Draw_64": (8, 64),
               "CleanUp_0": (12, 0), "KeyPress_27": (9, 27)}

def write_object(name, events):
    odir = f'{OUT}/objects/{name}'
    os.makedirs(odir, exist_ok=True)
    ev_list = []
    for ev_name, code in events.items():
        etype, enum_ = EVENT_FILES[ev_name]
        open(f'{odir}/{ev_name}.gml', 'w').write(code)
        ev_list.append({"$GMEvent": "v1", "%Name": "", "collisionObjectId": None, "eventNum": enum_,
                        "eventType": etype, "isDnD": False, "name": "", "resourceType": "GMEvent",
                        "resourceVersion": "2.0"})
    yy = {"$GMObject": "", "%Name": name, "eventList": ev_list, "managed": True, "name": name,
          "overriddenProperties": [], "parent": {"name": "Objects", "path": "folders/Objects.yy"},
          "parentObjectId": None, "persistent": False, "physicsAngularDamping": 0.1, "physicsDensity": 0.5,
          "physicsFriction": 0.2, "physicsGroup": 1, "physicsKinematic": False, "physicsLinearDamping": 0.1,
          "physicsObject": False, "physicsRestitution": 0.1, "physicsSensor": False, "physicsShape": 1,
          "physicsShapePoints": [], "physicsStartAwake": True, "properties": [], "resourceType": "GMObject",
          "resourceVersion": "2.0", "solid": False, "spriteId": None, "spriteMaskId": None, "visible": True}
    dump(f'{odir}/{name}.yy', yy)
    resources.append({"id": {"name": name, "path": f"objects/{name}/{name}.yy"}})

OBJ = '/home/claude/settlers/objects'
for oname in sorted(os.listdir(OBJ)):
    events = {}
    for f in sorted(os.listdir(f'{OBJ}/{oname}')):
        if f.endswith('.gml'):
            events[f[:-4]] = open(f'{OBJ}/{oname}/{f}').read()
    write_object(oname, events)

# ---------------------------------------------------------------- room
def write_room(name, w, h, instances):
    rdir = f'{OUT}/rooms/{name}'
    os.makedirs(rdir, exist_ok=True)
    inst_entries = []
    order = []
    for obj, x, y in instances:
        iname = 'inst_' + uid().replace('-', '')[:8].upper()
        order.append({"name": iname, "path": f"rooms/{name}/{name}.yy"})
        inst_entries.append({"$GMRInstance": "v4", "%Name": iname, "colour": 4294967295, "frozen": False,
                             "hasCreationCode": False, "ignore": False, "imageIndex": 0, "imageSpeed": 1.0,
                             "inheritCode": False, "inheritedItemId": None, "inheritItemSettings": False,
                             "isDnd": False, "name": iname,
                             "objectId": {"name": obj, "path": f"objects/{obj}/{obj}.yy"},
                             "properties": [], "resourceType": "GMRInstance", "resourceVersion": "2.0",
                             "rotation": 0.0, "scaleX": 1.0, "scaleY": 1.0, "x": float(x), "y": float(y)})
    views = []
    for i in range(8):
        views.append({"hborder": 32, "hport": h, "hspeed": -1, "hview": h, "inherit": False,
                      "objectId": None, "vborder": 32,
                      "visible": i == 0, "vspeed": -1, "wport": w, "wview": w, "xport": 0, "xview": 0,
                      "yport": 0, "yview": 0})
    yy = {"$GMRoom": "v1", "%Name": name, "creationCodeFile": "", "inheritCode": False,
          "inheritCreationOrder": False, "inheritLayers": False, "instanceCreationOrder": order,
          "isDnd": False,
          "layers": [
              {"$GMRInstanceLayer": "", "%Name": "Instances", "depth": 0, "effectEnabled": True,
               "effectType": None, "gridX": 32, "gridY": 32, "hierarchyFrozen": False,
               "inheritLayerDepth": False, "inheritLayerSettings": False, "inheritSubLayers": True,
               "inheritVisibility": True, "instances": inst_entries, "layers": [], "name": "Instances",
               "properties": [], "resourceType": "GMRInstanceLayer", "resourceVersion": "2.0",
               "userdefinedDepth": False, "visible": True},
              {"$GMRBackgroundLayer": "", "%Name": "Background", "animationFPS": 15.0,
               "animationSpeedType": 0, "colour": 4278190080, "depth": 100, "effectEnabled": True,
               "effectType": None, "gridX": 32, "gridY": 32, "hierarchyFrozen": False, "hspeed": 0.0,
               "htiled": False, "inheritLayerDepth": False, "inheritLayerSettings": False,
               "inheritSubLayers": True, "inheritVisibility": True, "layers": [], "name": "Background",
               "properties": [], "resourceType": "GMRBackgroundLayer", "resourceVersion": "2.0",
               "spriteId": None, "stretch": False, "userdefinedAnimFPS": False, "userdefinedDepth": False,
               "visible": True, "vspeed": 0.0, "vtiled": False, "x": 0, "y": 0}],
          "name": name, "parent": {"name": "Rooms", "path": "folders/Rooms.yy"}, "parentRoom": None,
          "physicsSettings": {"inheritPhysicsSettings": False, "PhysicsWorld": False,
                              "PhysicsWorldGravityX": 0.0, "PhysicsWorldGravityY": 10.0,
                              "PhysicsWorldPixToMetres": 0.1},
          "resourceType": "GMRoom", "resourceVersion": "2.0",
          "roomSettings": {"Height": h, "inheritRoomSettings": False, "persistent": False, "Width": w},
          "sequenceId": None, "views": views,
          "viewSettings": {"clearDisplayBuffer": True, "clearViewBackground": False, "enableViews": True,
                           "inheritViewSettings": False},
          "volume": 1.0}
    dump(f'{rdir}/{name}.yy', yy)
    resources.append({"id": {"name": name, "path": f"rooms/{name}/{name}.yy"}})

write_room('rm_game', 640, 400, [('obj_game', 0, 0)])

# ---------------------------------------------------------------- options + project
dump(f'{OUT}/options/main/options_main.yy', {
    "$GMMainOptions": "v5", "%Name": "Main", "name": "Main",
    "option_allow_instance_change": True, "option_audio_error_behaviour": True, "option_author": "",
    "option_collision_compatibility": False, "option_copy_on_write_enabled": False,
    "option_draw_colour": 4294967295, "option_gameguid": uid(), "option_gameid": "0", "option_game_speed": 60,
    "option_legacy_json_parsing": True, "option_legacy_number_conversion": True,
    "option_legacy_other_behaviour": True, "option_legacy_primitive_drawing": True,
    "option_mips_for_3d_textures": False, "option_remove_unused_assets": False, "option_sci_usesci": False,
    "option_spine_licence": False, "option_steam_app_id": "0", "option_template_description": None,
    "option_template_icon": "${base_options_dir}/main/template_icon.png",
    "option_template_image": "${base_options_dir}/main/template_image.png",
    "option_window_colour": 255, "resourceType": "GMMainOptions", "resourceVersion": "2.0"})

resources.sort(key=lambda r: r['id']['name'])
yyp = {
    "$GMProject": "v1", "%Name": NAME,
    "AudioGroups": [{"$GMAudioGroup": "v1", "%Name": "audiogroup_default", "exportDir": "", "name": "audiogroup_default",
                     "resourceType": "GMAudioGroup", "resourceVersion": "2.0", "targets": -1}],
    "configs": {"children": [], "name": "Default"},
    "defaultScriptType": 1,
    "Folders": folders,
    "ForcedPrefabProjectReferences": [],
    "IncludedFiles": [],
    "isEcma": False,
    "LibraryEmitters": [],
    "MetaData": {"IDEVersion": "2024.14.3.217"},
    "name": NAME,
    "resources": resources,
    "resourceType": "GMProject", "resourceVersion": "2.0",
    "RoomOrderNodes": [{"roomId": {"name": "rm_game", "path": "rooms/rm_game/rm_game.yy"}}],
    "templateType": "game",
    "TextureGroups": [{"$GMTextureGroup": "", "%Name": "Default", "autocrop": True, "border": 2,
                       "compressFormat": "bz2", "customOptions": "", "directory": "", "groupParent": None,
                       "isScaled": True, "loadType": "default", "mipsToGenerate": 0, "name": "Default",
                       "resourceType": "GMTextureGroup", "resourceVersion": "2.0", "targets": -1}]}
dump(f'{OUT}/{NAME}.yyp', yyp)
order = [{"name": r['id']['name'], "order": i, "path": r['id']['path']} for i, r in enumerate(resources)]
dump(f'{OUT}/{NAME}.resource_order', {"FolderOrderSettings": [], "ResourceOrderSettings": order})
shutil.copy('/mnt/user-data/uploads/GameMakerProjects/TheC64GameDevTool/.gitignore', f'{OUT}/.gitignore')
shutil.copy('/mnt/user-data/uploads/GameMakerProjects/TheC64GameDevTool/.gitattributes', f'{OUT}/.gitattributes')
print('resources:', len(resources))
