# SettlersGM — The Settlers (Amiga, 1993) recreated in GameMaker

A recreation of Blue Byte's *The Settlers* for GameMaker Studio 2026 LTS, built from the
original Amiga assets and a line-for-line GML port of the
[Freeserf](https://github.com/freeserf/freeserf) reverse-engineering of the game logic.

The simulation is the original's, tick for tick: the RNG, the map generator, the serf state
machine and the economy are ports rather than reimplementations, and the map for a given seed
is bit-identical to Freeserf's. Where the game deliberately does something the original did
not — two-player net play, knights that walk cross country, a crash reporter — it is listed
under **Deliberate departures** rather than left for somebody to find.

Open `SettlersGM.yyp` and press Run. The start screen offers a new game, the mission list, a
saved game, or NET PLAY.

## Controls

| Input | Action |
|---|---|
| Left click | Map cursor / UI buttons |
| Double click | Context popup for the clicked object |
| Drag (any button) | Scroll the map (wraps, like the original) |
| Arrow keys | Scroll by 32 px |
| Mouse wheel | Zoom: half size / normal / double |
| `+` / `-` | Game speed up / down |
| `P` | Pause |
| Enter | Net play: open the chat line (Enter sends, Escape cancels) |
| F1–F8 | Pick a save slot (F5 and F9 do the saving and loading) |
| F5 / F9 | Save to / load from the chosen slot |
| F7 / F8 | Host a two-player game / type a host's address to join |
| F10 | Fullscreen |
| F3 | Debug overlay (fps, tick, cursor col/row, height, object, owner, entity counts) |
| F11 | Save round-trip self test, to the output log |
| F12 | Dump the save slots and mission progress to the output log |

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
  scr_game_init       Start screen: new game, missions, saves, NET PLAY, map preview
  scr_audio           Sfx ids, the four-voice mixer, the Amiga per-sound rate/level table,
                      separate music and effects volumes
  scr_savegame        Save and load: a generic struct encoder, the slot files, the
                      load-time repairs and the F11 round-trip self test
  scr_ai              The computer players' economy building
  scr_net             Two-player lockstep net play: lobby and discovery, the command
                      stream, world hashing and desync diagnosis, chat
  scr_locale          English / German strings
  scr_crash           Crash handler, the report, and the play report
  scr_fault           What the simulation does instead of throwing (see below)
  scr_cheat_cf        The "borntodie" cheat, with generated art and sound
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
The `tools/check_*.py` scripts check the GML sources — see **Checks** below.

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
* Not ported: the intro sequence, and the AI's strategic play. The computer players build an
  economy but do not fight a campaign.

## Deliberate departures

Everything here is a decision, not an accident, and each one is argued in a comment at the
place it happens.

* **Knights walk cross country.** A knight coming back from a fight, or sent to a garrison,
  crosses open ground to the door rather than hunting for a flag and following roads. On the
  roads he is an obstruction the length of the walk, and the flag hunt loops when the flag it
  picks has no route to an inventory. See `knight_send_home` in `scr_serf_c`.
* **Knights do not block traffic.** They stand on their own occupancy layer, so a knight in
  the field is no obstacle to a transporter and vice versa. See `MAP_KNIGHTS_PHANTOM` in
  `scr_map`.
* **Two-player net play**, which the Amiga game had no notion of: deterministic lockstep,
  commands only over the wire, a world hash compared every turn, and a version check in the
  start handshake because two different builds cannot simulate the same game.
* **Nothing throws.** Freeserf asserts on states its author believed impossible; in GML an
  uncaught throw ends the player's session. Every one of those is a `fault_note()` and the
  most conservative recovery available instead, and the last dozen faults ride along in the
  crash report. See `scr_fault`.
* **Sound.** Each effect plays at the rate and level the original's own table gives it
  (`0x2e33e` in the Amiga executable), re-randomised per play as the hardware did; music and
  effects have separate volumes; the landscape ambience follows the original's rules but
  fires less often, because our frame rate is not the Amiga's.
* **Quality-of-life**: save slots, a mission-progress record, a map-generation progress bar,
  mouse-wheel zoom, a fullscreen toggle, and an update check against `version.txt`.
* **A crash reporter** that asks before it sends anything.

## Checks

`tools/` carries a set of static checkers, each written for a bug that actually happened and
cost somebody a game. They are cheap enough to run on every commit:

| Checker | What it refuses to let back in |
|---|---|
| `check_gml.py` | Cross-file symbol use: calls and methods that do not exist |
| `check_locals.py` | A local used but never declared in that function |
| `check_static_scope.py` | A constructor's static called from outside it |
| `check_dup_statics.py` | Two statics of the same name in one constructor (the later silently wins) |
| `check_serf_layers.py` | Occupancy read from the wrong layer |
| `check_serf_pos.py` | A serf's position moved without telling the map |
| `check_anim_table.py` | The animation table indexed directly — an out-of-range read ends the session |
| `check_throws.py` | Anything in the game scripts that throws |
| `check_sprite_meta.py` | Sprite metadata that does not match the sprites |

## Licence

The game logic is ported from Freeserf (GPL-3.0, (C) Jon Lund Steffensen and contributors);
this project is therefore GPL-3.0. The graphics, sounds and music are (C) Blue Byte and are
only usable with a legitimately owned copy of the game.
