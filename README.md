# SettlersGM — The Settlers (Amiga, 1993) recreated in GameMaker

A 1:1 recreation of Blue Byte's *The Settlers* for GameMaker Studio 2026 LTS, built from
the original Amiga assets and a line-for-line GML port of the
[Freeserf](https://github.com/freeserf/freeserf) reverse-engineering of the game logic.

Open `SettlersGM.yyp` and press F5. You start on the Tutorial 1 map (mission seed
`3762665523225478`), with no castle — place it from the build menu, exactly like the original.

## Controls

| Input | Action |
|---|---|
| Left click | Map cursor / UI buttons |
| Double click | Context popup for the clicked object |
| Drag (any button) | Scroll the map (wraps, like the original) |
| Arrow keys | Scroll by 32 px |
| `+` / `-` | Game speed up / down |
| `P` | Pause |
| F3 | Debug overlay (fps, tick, cursor col/row, height, object, owner, entity counts) |

## What is here

```
scripts/
  scr_random          Freeserf Random (the original 3x16-bit LFSR) — bit-identical
  scr_map_geometry    MapGeometry: wrap-around hex grid, MapPos packing, 6 directions
  scr_map             Map: landscape/game tile arrays, spiral pattern, per-tick update
  scr_map_generator   ClassicMapGenerator / ClassicMissionMapGenerator — the original
                      terrain generator (midpoint + diamond-square heights, water bodies,
                      deserts, object clusters, mineral deposits)
  scr_objects         GameObject + Collection (the C++ Collection<T, growth> container)
  scr_player          Player: stats, priorities, notifications, knights, history
  scr_inventory       Inventory: stocks, out-queue, serf specialisation
  scr_flag            Flag + FlagSearch: the transport graph and resource scheduling
  scr_building        Building: construction, stocks, military, per-tick update
  scr_serf            Serf part A: type/state enums, fields, movement, walking
  scr_serf_b/_c       Serf parts B and C: the full 76-state serf state machine
  scr_game            Game: build/demolish, roads, land ownership, the update loop
  scr_pathfinder      A* road pathfinder (same heuristic and tie-breaking as the original)
  scr_mission         The 30 campaign missions + tutorials, characters, player colours
  scr_gfx             Port of Freeserf's Frame drawing API onto GameMaker
  scr_gui             GuiObject: layout, event dispatch, redraw flags, frame caching
  scr_interface       Interface + Road: cursor logic, road building, popup routing
  scr_viewport        Landscape, paths, borders, buildings, serfs, waves, cursor
  scr_panel           Bottom panel bar
  scr_popup/_b/_c     Every popup: build menus, stats, settings, minimap, attack, options
  scr_minimap         Minimap / MinimapGame
  scr_notification    Message boxes
  scr_game_init       New-game dialog with map preview
  scr_audio           Sfx ids, play_sfx(), music/volume control
  scr_sprite_meta     GENERATED: per-frame offsets/deltas, the 200-entry serf animation
                      table, the sound index map
objects/obj_game      Controller: window setup, Freeserf's event loop, tick pacing
rooms/rm_game         640x400 logical screen, scaled x2 (see SCREEN_* macros)
sprites/              See "Sprite conventions" below
sounds/               snd_<n> = Amiga sample n; mus_settlers = the MOD soundtrack
tools/                The extraction pipeline, so everything is reproducible
```

## Sprite conventions

Every Freeserf resource category is one GameMaker sprite. All frames in a category are padded
to a common canvas so that the sprite **origin** encodes the original per-frame offset —
`draw_sprite(spr, index, x, y)` is therefore exactly Freeserf's
`Frame::draw_sprite(x, y, res, index)` with `use_off = true`.

* `spr_<category>` — the image. `spr_<category>_mask` — the player-colour part (white on
  transparent); draw it over the base with `draw_sprite_ext(..., player_colour, 1)`.
* `spr_ground_up` / `spr_ground_down` — pre-baked (slope mask x ground texture) triangles.
  Frame = `mask_index * 33 + ground_index` (81 masks x 33 textures).
* `spr_path_baked` — pre-baked road segments. Frame = `path_mask * 10 + path_ground`.
* `spr_waves_up` / `spr_waves_down` — shoreline waves through mask 40.

## Timing

Freeserf's `TICK_LENGTH` is 20 ms, so the game runs at **50 ticks per second** regardless of
frame rate; `obj_game` drives updates from elapsed milliseconds with a catch-up cap.
Rendering follows the original's redraw model: `GuiObject.set_redraw()` propagates to the
parent, and the viewport renders into its own cached surface only when marked dirty —
`Viewport.update()` does that every 8 game ticks, plus immediately on scroll or cursor moves.

## Asset pipeline (reproducible)

`tools/dump.cc` links against Freeserf's `DataSourceAmiga` and dumps every sprite (with mask,
offset and delta), sound and music from a WHDLoad `data/` folder. `tools/topng.py` converts
the raw dumps to PNG; `tools/build_project.py` builds this entire GameMaker project from them
(sprite padding, baking, and the `.yy`/`.yyp` files in the IDE's own serialisation format).
`tools/check_gml.py` is a cross-file symbol checker for the GML sources.

```
g++ -std=c++17 -I freeserf -o dump tools/dump.cc freeserf/src/{data-source-amiga,\
data-source-legacy,data-source,data,data-source-dos,data-source-custom,buffer,log,sfx2wav,\
pcm2wav,tpwm,xmi2mid,debug,configfile,sprite-file-dummy}.cc
./dump "<path to WHDLoad data folder>" out
python3 tools/topng.py && python3 tools/build_project.py
```

## Fidelity notes

* Map generation, the RNG, the map update and the triangle renderer are line-for-line ports;
  the map for a given seed is bit-identical to Freeserf's.
* `tools/render_ref.py` renders the same map with the same algorithm in Python —
  `ref_screen.png` is what the window should look like at start.
* **Palette:** the game's real Amiga copper palette lives in the WHDLoad `data/TheSettlers`
  executable at offset `0x2a3e`. Freeserf's hand-typed 32-colour table matches the hardware
  exactly on indices 0 and 7–31 (all terrain, stone, snow, sand and UI colours); only 1–6
  differ, and those are the slots the game reprograms at runtime for player colours and the
  water ramp. Ground tiles store 3–4 bitplanes decoded as 5-bit indices (254-byte entries =
  2 + 3x84), so there is no sixth EHB plane in the tile data — extra-half-brite is used only
  for the shadow plane, which the extractor emits as 50% black and composites identically.
* Not yet ported: save/load, the intro sequence, and the AI's higher-level strategy.

## Licence

The game logic is ported from Freeserf (GPL-3.0, (C) Jon Lund Steffensen and contributors);
this project is therefore GPL-3.0. The graphics, sounds and music are (C) Blue Byte and are
only usable with a legitimately owned copy of the game.
