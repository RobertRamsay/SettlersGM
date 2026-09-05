#!/usr/bin/env python3
"""
Install the generated soldier sprites, effects and sound effects into the
SettlersGM GameMaker project, and register everything in the .yyp.

Serialisation deliberately matches what the IDE itself writes for this project
(v1 yyp, v2 sprites without channels/seqWidth/seqHeight, single-line array
entries with trailing commas, LF endings), because GameMaker's reader is strict.
"""
import os
import re
import shutil
import subprocess
import uuid
import wave

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "tools", "cf_build")


def guid():
    return str(uuid.uuid4())


def entry(d):
    """One-line object with a trailing comma inside, GameMaker style."""
    parts = []
    for k, v in d.items():
        parts.append('"%s":%s' % (k, v))
    return "{" + ",".join(parts) + ",}"


def q(s):
    return '"%s"' % s


# ------------------------------------------------------------------ sprites
def write_sprite(name, src_dir, origin_x, origin_y):
    files = sorted(f for f in os.listdir(src_dir) if f.endswith(".png"))
    dst = os.path.join(REPO, "sprites", name)
    os.makedirs(dst, exist_ok=True)

    w, h = Image.open(os.path.join(src_dir, files[0])).size
    bl, bt, br, bb = w, h, 0, 0
    frame_ids = []
    for f in files:
        im = Image.open(os.path.join(src_dir, f)).convert("RGBA")
        bb_ = im.getbbox()
        if bb_ is not None:
            bl = min(bl, bb_[0])
            bt = min(bt, bb_[1])
            br = max(br, bb_[2] - 1)
            bb = max(bb, bb_[3] - 1)
        fid = guid()
        frame_ids.append(fid)
        shutil.copyfile(os.path.join(src_dir, f), os.path.join(dst, fid + ".png"))

    layer_id = guid()
    frames = "\n".join(
        "    " + entry({
            "$GMSpriteFrame": q("v1"),
            "%Name": q(fid),
            "name": q(fid),
            "resourceType": q("GMSpriteFrame"),
            "resourceVersion": q("2.0"),
        }) + "," for fid in frame_ids)

    keyframes = []
    for i, fid in enumerate(frame_ids):
        chan = ('{"0":{"$SpriteFrameKeyframe":"","Id":{"name":"%s",'
                '"path":"sprites/%s/%s.yy",},"resourceType":"SpriteFrameKeyframe",'
                '"resourceVersion":"2.0",},}' % (fid, name, name))
        keyframes.append(entry({
            "$Keyframe<SpriteFrameKeyframe>": q(""),
            "Channels": chan,
            "Disabled": "false",
            "id": q(guid()),
            "IsCreationKey": "false",
            "Key": "%.1f" % i,
            "Length": "1.0",
            "resourceType": q("Keyframe<SpriteFrameKeyframe>"),
            "resourceVersion": q("2.0"),
            "Stretch": "false",
        }))
    kfstore = ('{"$KeyframeStore<SpriteFrameKeyframe>":"","Keyframes":[%s],'
               '"resourceType":"KeyframeStore<SpriteFrameKeyframe>",'
               '"resourceVersion":"2.0",}' % (",".join(keyframes) + ","))

    track = entry({
        "$GMSpriteFramesTrack": q(""),
        "builtinName": "0",
        "events": "[]",
        "inheritsTrackColour": "true",
        "interpolation": "1",
        "isCreationTrack": "false",
        "keyframes": kfstore,
        "modifiers": "[]",
        "name": q("frames"),
        "resourceType": q("GMSpriteFramesTrack"),
        "resourceVersion": q("2.0"),
        "spriteId": "null",
        "trackColour": "0",
        "tracks": "[]",
        "traits": "0",
    })

    layer = entry({
        "$GMImageLayer": q(""),
        "%Name": q(layer_id),
        "blendMode": "0",
        "displayName": q("default"),
        "isLocked": "false",
        "name": q(layer_id),
        "opacity": "100.0",
        "resourceType": q("GMImageLayer"),
        "resourceVersion": q("2.0"),
        "visible": "true",
    })

    yy = f'''{{
  "$GMSprite":"v2",
  "%Name":"{name}",
  "bboxMode":0,
  "bbox_bottom":{bb},
  "bbox_left":{bl},
  "bbox_right":{br},
  "bbox_top":{bt},
  "collisionKind":1,
  "collisionTolerance":0,
  "DynamicTexturePage":false,
  "edgeFiltering":false,
  "For3D":false,
  "frames":[
{frames}
  ],
  "gridX":0,
  "gridY":0,
  "height":{h},
  "HTile":false,
  "layers":[
    {layer},
  ],
  "name":"{name}",
  "nineSlice":null,
  "origin":9,
  "parent":{{
    "name":"Sprites",
    "path":"folders/Sprites.yy",
  }},
  "preMultiplyAlpha":false,
  "resourceType":"GMSprite",
  "resourceVersion":"2.0",
  "sequence":{{
    "$GMSequence":"v1",
    "%Name":"{name}",
    "autoRecord":true,
    "backdropHeight":768,
    "backdropImageOpacity":0.5,
    "backdropImagePath":"",
    "backdropWidth":1366,
    "backdropXOffset":0.0,
    "backdropYOffset":0.0,
    "events":{{
      "$KeyframeStore<MessageEventKeyframe>":"",
      "Keyframes":[],
      "resourceType":"KeyframeStore<MessageEventKeyframe>",
      "resourceVersion":"2.0",
    }},
    "eventStubScript":null,
    "eventToFunction":{{}},
    "length":{len(frame_ids)}.0,
    "lockOrigin":false,
    "moments":{{
      "$KeyframeStore<MomentsEventKeyframe>":"",
      "Keyframes":[],
      "resourceType":"KeyframeStore<MomentsEventKeyframe>",
      "resourceVersion":"2.0",
    }},
    "name":"{name}",
    "playback":1,
    "playbackSpeed":0.0,
    "playbackSpeedType":0,
    "resourceType":"GMSequence",
    "resourceVersion":"2.0",
    "showBackdrop":true,
    "showBackdropImage":false,
    "timeUnits":1,
    "tracks":[
      {track},
    ],
    "visibleRange":null,
    "volume":1.0,
    "xorigin":{origin_x},
    "yorigin":{origin_y},
  }},
  "swatchColours":null,
  "swfPrecision":0.5,
  "textureGroupId":{{
    "name":"Default",
    "path":"texturegroups/Default",
  }},
  "type":0,
  "VTile":false,
  "width":{w},
}}'''
    with open(os.path.join(dst, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    print("sprite %-18s %d frames %dx%d origin %d,%d"
          % (name, len(frame_ids), w, h, origin_x, origin_y))


# ------------------------------------------------------------------ sounds
def write_sound(name, wav_path):
    dst = os.path.join(REPO, "sounds", name)
    os.makedirs(dst, exist_ok=True)
    shutil.copyfile(wav_path, os.path.join(dst, name + ".wav"))
    with wave.open(wav_path) as w:
        dur = w.getnframes() / w.getframerate()
        rate = w.getframerate()
        chans = w.getnchannels()
    yy = f'''{{
  "$GMSound":"v2",
  "%Name":"{name}",
  "audioGroupId":{{
    "name":"audiogroup_default",
    "path":"audiogroups/audiogroup_default",
  }},
  "bitDepth":1,
  "channelFormat":{0 if chans == 1 else 1},
  "compression":0,
  "compressionQuality":4,
  "conversionMode":0,
  "duration":{dur:.3f},
  "exportDir":"",
  "name":"{name}",
  "parent":{{
    "name":"Sounds",
    "path":"folders/Sounds.yy",
  }},
  "preload":true,
  "resourceType":"GMSound",
  "resourceVersion":"2.0",
  "sampleRate":{rate},
  "soundFile":"{name}.wav",
  "volume":1.0,
}}'''
    with open(os.path.join(dst, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    print("sound  %-18s %.2f s  %d Hz" % (name, dur, rate))


# ------------------------------------------------------------------ script
def write_script(name):
    dst = os.path.join(REPO, "scripts", name)
    os.makedirs(dst, exist_ok=True)
    yy = f'''{{
  "$GMScript":"v1",
  "%Name":"{name}",
  "isCompatibility":false,
  "isDnD":false,
  "name":"{name}",
  "parent":{{
    "name":"Scripts",
    "path":"folders/Scripts.yy",
  }},
  "resourceType":"GMScript",
  "resourceVersion":"2.0",
}}'''
    with open(os.path.join(dst, name + ".yy"), "w", newline="\n") as f:
        f.write(yy)
    print("script %-18s" % name)


# ------------------------------------------------------------------ yyp
def register(entries):
    """Add {name, path} rows to the .yyp resources list if not already there."""
    path = os.path.join(REPO, "SettlersGM.yyp")
    with open(path, encoding="utf-8") as f:
        txt = f.read()

    added = []
    for name, rel in entries:
        if '"name":"%s"' % name in txt:
            continue
        row = '    {"id":{"name":"%s","path":"%s",},},\n' % (name, rel)
        added.append(row)

    if not added:
        print("yyp: nothing to add")
        return

    marker = '  "resources":[\n'
    i = txt.index(marker) + len(marker)
    txt = txt[:i] + "".join(added) + txt[i:]
    with open(path, "w", newline="\n", encoding="utf-8") as f:
        f.write(txt)
    print("yyp: registered %d resources" % len(added))


SOUND_NAMES = ["snd_cf_rifle", "snd_cf_grenade", "snd_cf_explosion",
               "snd_cf_fire", "snd_cf_hurt1", "snd_cf_hurt2", "snd_cf_death"]


def main():
    # resample the synthesised effects to the project's 44.1 kHz
    hi = os.path.join(OUT, "sfx44")
    os.makedirs(hi, exist_ok=True)
    for n in SOUND_NAMES:
        src = os.path.join(OUT, "sfx", n + ".wav")
        dstw = os.path.join(hi, n + ".wav")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src,
                        "-ar", "44100", "-ac", "1", dstw], check=True)

    write_sprite("spr_cf_soldier", os.path.join(OUT, "soldier"), 16, 20)
    write_sprite("spr_cf_fx", os.path.join(OUT, "fx"), 8, 8)
    for n in SOUND_NAMES:
        write_sound(n, os.path.join(hi, n + ".wav"))
    write_script("scr_cheat_cf")

    rows = [("scr_cheat_cf", "scripts/scr_cheat_cf/scr_cheat_cf.yy"),
            ("spr_cf_soldier", "sprites/spr_cf_soldier/spr_cf_soldier.yy"),
            ("spr_cf_fx", "sprites/spr_cf_fx/spr_cf_fx.yy")]
    rows += [(n, "sounds/%s/%s.yy" % (n, n)) for n in SOUND_NAMES]
    register(rows)


if __name__ == "__main__":
    main()
