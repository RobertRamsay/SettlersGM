# SettlersGM — The Settlers (Amiga, 1993) recreated in GameMaker

Milestone 1: **original Amiga assets extracted + landscape renderer**.

Open `SettlersGM.yyp` in GameMaker Studio 2026 LTS and press F5. You get the
Tutorial 1 map (the same 64×64 map the original/Freeserf generates from mission
seed `3762665523225478`), drawn with the real Amiga graphics, trees/stones/deserts,
animated water and trees, the bottom panel and the map cursor.

## Controls

| Input | Action |
|---|---|
| Right mouse drag | Scroll the map (wraps like the original) |
| Arrow keys (+Shift) | Scroll |
| Left click | Place the map cursor (plays the click sample) |
| N | Generate a new random map |
| P | Pause / resume the game tick |
| M | Music on/off |
| F3 | Debug overlay (fps, tick, cursor col/row, height, terrain types) |

## What is where

```
SettlersGM.yyp
scripts/
  scr_random         Freeserf Random (the original 3×16-bit LFSR) — bit-identical
  scr_map_geometry   MapGeometry: wrap-around hex grid, MapPos packing, 6 directions
  scr_map            Map: landscape/game tile arrays, spiral pattern, update()
                     (tree growth, fields, fish/signs), road segment helpers
  scr_map_generator  ClassicMapGenerator / ClassicMissionMapGenerator — the full
                     original terrain generator (midpoint/diamond-square heights,
                     water bodies, deserts, object clusters, mineral deposits)
  scr_viewport       Landscape renderer (masked triangle tiles cached on surfaces),
                     map objects, waves, cursor, screen<->map coordinates
  scr_panel          Bottom panel bar
  scr_game           SettlersGame: map + tick counters (20 ticks/s, +2 per tick)
  scr_audio          Sfx enum + play_sfx()
  scr_sprite_meta    GENERATED: per-frame offsets/deltas, serf animation table
                     (200 animations), sound index map
objects/obj_game     Controller: window setup, input, tick loop, draw order
rooms/rm_game        640×400 logical screen, scaled ×2 (see SCREEN_* macros)
sprites/
  spr_<category>     One sprite per Freeserf resource category; every frame is
                     padded to a common canvas so the sprite ORIGIN encodes the
                     original per-frame offset. draw_sprite(spr, index, x, y)
                     is therefore exactly Freeserf's Frame::draw_sprite(x, y, res, index).
  spr_<category>_mask  Player-colour part (white on transparent) — draw with
                     draw_sprite_ext(..., player_colour, 1) over the base sprite.
  spr_ground_up / spr_ground_down   Pre-baked (mask × ground texture) triangles.
                     frame = mask_index * 33 + ground_index (81 masks × 33 grounds).
  spr_path_baked     Pre-baked road segments: frame = path_mask * 10 + path_ground.
  spr_waves_up/down  Shoreline wave sprites through mask 40.
sounds/snd_<n>       Amiga samples (8 kHz 16-bit mono WAV); n = Freeserf sound id.
sounds/mus_settlers  The Amiga MOD soundtrack rendered to OGG (first 4 minutes;
                     the original .mod is in tools/ if you want a tracker player).
tools/               The extraction pipeline (see below) so everything is reproducible.
```

## Asset pipeline (reproducible)

`tools/dump.cc` links against Freeserf's `DataSourceAmiga` and dumps every sprite
(with mask, offset and delta), sound and music from the WHDLoad `data/` folder.
`tools/topng.py` converts the raw dumps to PNG; `tools/build_project.py` builds
this whole GameMaker project from them (sprite padding, baking, .yy/.yyp files).

```
g++ -std=c++17 -I freeserf -o dump tools/dump.cc freeserf/src/{data-source-amiga,data-source-legacy,data-source,data,data-source-dos,data-source-custom,buffer,log,sfx2wav,pcm2wav,tpwm,xmi2mid,debug,configfile,sprite-file-dummy}.cc
./dump "<path to WHDLoad data folder>" out
python3 tools/topng.py && python3 tools/build_project.py
```

## Fidelity notes

* Map generation, RNG, map update and the triangle renderer are line-for-line
  ports of Freeserf (which is itself a reverse-engineering of the original);
  the map for a given seed is bit-identical to Freeserf's.
* `tools/render_ref.py` renders the same map with the same algorithm in Python —
  `ref_screen.png` is what the GameMaker window should look like at start.
* Missing so far (next milestones): players/castle placement, flags & roads
  (road drawing sprites are already baked), buildings, serfs + animations
  (serf torso/head sprites and the 200-entry animation table are already in),
  economy, popups/minimap, AI, combat, mission table (30 campaign missions),
  intro/menu screens.

## Licence

The game logic is ported from Freeserf (GPL-3.0, © Jon Lund Steffensen and
contributors); this project is therefore GPL-3.0. The graphics, sounds and music
are © Blue Byte and are only usable with a legitimately owned copy of the game.
