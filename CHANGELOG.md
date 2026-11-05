# Changelog

What changed in each SettlersGM release, newest first. Dates are when the
release was announced (the `version.txt` bump), not when work started.

Entries up to 1.2.0 are rebuilt from the git history. Those commit messages
are short, so the early notes are summaries, and the odd change may sit one
release out from where it really shipped.

## 1.2.4

- **Fixed: a one-second freeze every 10–15 seconds** in games against the AI.
  At every decision, each AI player tried to reconnect every one of its
  disconnected flags. A road that couldn't be built made the road search scan
  the whole map before giving up. Now the AI tries one disconnected flag per
  decision, taking them in turn. Its road search only crosses its own land and
  gives up after a fixed number of steps. Roads you place yourself are not
  affected.
- The same fix stops the AI getting stuck retrying roads it can never build.
- **Custom games: the AI now attacks.** It follows the same rules you do: it
  can only attack occupied military buildings on its border, and only with
  knights its own buildings can spare. It goes for the target where it
  outnumbers the defenders by the most, needing at least one knight more than
  the defenders (three more for a castle). Smarter opponents think more often,
  so they attack more often too.
- **Custom games: the AI builds towers on the front line.** When a new
  military site is near another player's land and it has the stone and planks
  to spare, it builds a tower instead of a hut.
- **Custom games: the AI settles within reach.** It used to put its castle as
  far from yours as the map allowed, which on a big map (the map wraps) is the
  other side of the world, so your borders might never meet. It now aims for a
  site about 40 steps from the nearest castle, or the furthest site on a map
  too small for that. On big maps it also considers the whole map, not just a
  few columns.
- Campaign missions are unchanged: their AI still neither attacks nor builds
  towers, and settles where it always has.
- **"Your settlement is under attack" comes once per attack wave**, when the
  first enemy knight of that wave reaches your building. It used to repeat for
  every fight at the door, so a castle holding off a big attack filled the
  message list. This applies to missions too.

## 1.2.3 — 2026-11-05

- **Fixed: crash when the AI tried to build a road across a segment that was
  no longer valid** (the 1.2.2 crash in `Map.get_obj`). That road is now just
  refused.

## 1.2.2 — 2026-10-31

- **New: screen shape setting.** The Fullscreen row in Options is now
  *Screen &lt;shape&gt;*: **Pixel** (square pixels, as before), **4:3** (the
  shape of the original's CRT, with no black bands on a 4:3 monitor) or
  **Fill** (the window's shape). Scaling keeps pixel rows even when the
  stretch is uneven. The window size follows the chosen shape.
- Option values you can click (Screen, Messages, Invert, Sfx) are drawn in a
  lighter green and turn white under the pointer.
- **Hotfix:** music, effects, both volumes, the message filter, drag
  direction, stereo and fullscreen are now remembered between launches (in
  `settlers.ini`).
- **Hotfix (Mac):** the app now has its own id, so its saves live in their own
  folder. Saves from the old folder are copied across on first launch.

## 1.2.1 — 2026-10-27

- **Fixed: crash when a knight was sent to a flag whose building link had gone
  stale** (introduced in 1.2.0). The link is now repaired to the right
  building instead of being cut.
- Serfs can no longer be requested for a building at a flag that has no
  building. Only transporters and geologists can be sent there.
- Guards added to the remaining places that trusted a flag, building, road or
  inventory link that could already be gone.

## 1.2.0 — 2026-10-26

*(1.1.9 was built but never announced; its changes are included here.)*

- **Fixed: crash in inventory updates** (`update_inventories_cb`, 1.1.7–1.1.9)
  caused by a flag still pointing at a building that no longer existed. Stale
  links are now detected, and they are also checked when a save is loaded.
- **Fixed: crash when a serf tried to enter a building that had just been
  destroyed.**

## 1.1.8 — 2026-10-21

- Save slot improvements.
- **Fixed:** a building popup could stay open after its building was gone.

## 1.1.7 — 2026-10-03

- New back button and on-screen helper.
- **Fixed:** building names displaying wrongly.
- **Fixed:** the load hint.

## 1.1.6 — 2026-09-30

- Alt (Windows) or Option (Mac) + click can now be used instead of clicking
  both mouse buttons.
- Clearer warning when an update is available.
- Serf fix.

## 1.1.5 — 2026-09-28

- Geologist confirmation fix.
- Reminder to save.

## 1.1.4 — 2026-09-22

A big round of AI work:

- AI decisions follow game time, so fast-forward speeds them up instead of
  changing how the enemy plays.
- Expansion is paced, and the AI no longer bursts out military huts or stalls
  with nothing to build.
- The AI repairs roads to buildings left disconnected, and its new roads join
  the real network instead of forming islands.
- It plans its economy, manages stone and weapons, and arms and occupies its
  garrisons.
- Enemy *intelligence* now works as in the original: it sets how often the AI
  thinks, which is the campaign's difficulty curve.
- An "AI did nothing" report and a simulation log, for diagnosing stuck games.

## 1.1.3 — 2026-09-18

- **Fixed: crash in the viewport** (offset guard, 1.1.2).
- macOS build fixes.

## 1.1.2 — 2026-09-17

- Birdsong is quieter and less frequent.
- Fixes to map panning and the geologist.

## 1.1.1 — 2026-09-14

- New victory art.
- New popup.
- **Fixed:** a toolmaker bug (a -1 value), plus other small fixes.
- Code cleanup.

## 1.1.0 — 2026-09-11

- Net play checks both players are on the same version before starting.
- Version check on the start screen (shows UPDATE when a newer build is out).
- Fullscreen start-up fixes and a borderless mode.
- Performance work, with a profiler (F3, temporarily disabled).
- The game catches up properly after a speed change.
- Net play and save fixes from player feedback.
- **Fixed:** knights fighting nobody ("shadow boxing") and wandering off.

## 1.0.9 — 2026-09-10

- Crash reports are captured more reliably.

## 1.0.8 — 2026-09-10

*(1.0.7 was built but never announced; its changes are included here.)*

- **German translation.**
- Custom maps in net play.
- Effects volume control.
- Window sizing fix.
- **Fixed:** crash report delivery.

## 1.0.6 — 2026-09-09

- Net play: leave a game, and get told when the host or the other player has
  left.

## 1.0.5 — 2026-09-09

- In-game chat for net play.
- Font update.
- Sound: birdsong and ambience, quieter effects, new sound dynamics.
- Tidier net play and mission panels.

## 1.0.4 — 2026-09-08

- Map generator changes, including terrain flattening.
- The minimap is cached, so it draws faster.
- Play reports.
- End-game fixes.
- **Fixed:** a transporter crash.

## 1.0.3 — 2026-09-08

- Crash reports: when the game stops, it offers to send what went wrong.
- Knights: return home properly, fewer traffic jams, no phantom or frozen
  knights, free roaming.
- End-game guards and a building overlay fix.

## 1.0.2 — 2026-09-07

- **Net play lobby**: host and join from the start screen.
- Load button.
- Reminder timers.
- Water transparency and tint, and better border graphics.

## 1.0.1 — 2026-09-06

The first public build. It included:

- The full game simulation, ported from Freeserf: serfs, roads, flags,
  buildings, transport and the economy.
- Missions with saved progress, victory and defeat.
- Enemy AI: expansion, economy and military.
- Military: attacks, sieges, building health, burning buildings.
- Save and load with multiple slots.
- Game speed control (one button that cycles), zoom, centre on castle, map
  drag direction setting.
- Two-player net play (lockstep), with desync detection.
- Full soundtrack, stereo effects with panning.
- Fullscreen (F10), cheats.
