# Maple Street — notes for Claude sessions

Single-player sleeper-agent sandbox for Mac (keyboard + trackpad), in the style of Project Zomboid
without zombies. Godot **4.7.1**, typed GDScript, Forward+ renderer. Every model, sound and icon is
made by code; there are no art or audio files.

- Design agreed with the owner: `docs/superpowers/specs/2026-10-09-maple-street-design.md`.
- What is built, what is not, and what the owner has not reviewed yet: `docs/report.md`.

## Owner's decisions (do not undo)
- Title Maple Street. 1980s America, real Cold War, serious tone.
- 3D low-poly world, fixed Zomboid-style isometric camera (orthographic, yaw 45°, pitch -36°).
- Non-lethal by default; killing a witness is allowed and has consequences (body, missing-person
  report, police).
- Light daily life. The day job is a short playable shift, never a pure time-skip.
- Cover job: janitor at the plant. The player lives alone for now (room for a second person later).
- Permadeath. The game saves only when the player sleeps; arrest wipes the save.
- No handler deadlines (the owner declined that idea).
- A desktop shortcut app for every game (`~/Desktop/Maple Street.app`).

## Where things live
- `game/main.gd` builds everything and owns the per-frame context (`Game.ctx`: what the player is
  doing, read by `Rules.judge`).
- `game/core`: autoloads `Clock`, `Game` (run state), `Sfx` (synthesised sounds); `Save`; `Demo`.
- `game/world`: `Templates` (floor plans as data), `House`, `Furnish` (how each piece of furniture
  is drawn), `Portal` (doors, windows), `Street` (map + navmesh), `Build` (shared meshes and
  materials, generated detail textures, the faceted foliage shader, physics layers).
- `game/actors`: `Figure`, `Player`, `Walker` (path following + sight), `Neighbour`, `Dog`.
- `game/systems`: `Cast` (who lives where, from a seed), `Rules` (pure judgement functions),
  `Missions`, `Law` (inspections, police, investigator, searches), `Life` (needs, days, weather,
  events, car), `Shift` (the plant), `Interact` (E/R/T/F prompts and timed actions).
- `game/ui/hud.gd`: all interface, one modal window reused for every panel.

## Commands
```bash
tools/dev/check.sh                         # import, load every script, run all tests
tools/dev/run.sh /tmp/x.log 60 --path . -- --seed=7 --demo=look --shots=/tmp/shots
godot --headless --path . --script tools/gen_icon.gd   # regenerate icon.png
```
- Demos (`game/core/demo.gd`): `look`, `ui`, `scenes`, `walk`, `title`. Other dev switches:
  `-- --seed=N --hour=22 --at=x,z --zoom=40 --shot=/path.png`.
- New `class_name`s are not visible until `godot --headless --path . --import` runs (check.sh does it).
- GDScript: annotate types (`var x: bool = ...`) wherever a value comes out of a Dictionary or an
  untyped `main`; the parser treats failed inference as an error.
- Do not put multi-line lambdas inside call arguments; use a named method and `.bind()`.

## Things that will bite
- The navigation map builds in the background. Nothing may call `Street.path` before
  `main.ready_to_play`; `Walker.go_to` teleports if it gets an empty path.
- Navmesh `agent_radius` is 0 on purpose: doorways are under a metre and any erosion closes them.
- Physics layers: 1 blocks sight and movement, 2 movement only (furniture, windows), 3 doors
  (kept out of the navmesh), 4 the player. Sight rays use layers 1 and 3.
- `Neighbour.visible` means "on the map" (false while away). Use `figure.visible` for drawing.
- Saves use `var_to_str`, and containers and portals are restored by position in a list, so the
  street must be rebuilt from the same seed before `Save.apply`.

## Look
- Detailed but low-poly: boxes, cylinders and faceted blobs only, flat colour plus small generated
  greyscale textures (`Build.texture`) that the material colour tints. No image files.
- Use `Build.box/cyl/leaf` so meshes and materials are shared; do not create a new material per
  object. Decorative pieces get no collider, so they cannot change the navmesh.
- Volumetric fog does not work with the orthographic camera (it blacks the scene out). Lamp cones
  are additive meshes instead (`Street._shaft`).
- Ideas the owner has parked, and candidates for next: `docs/ideas.md`. Do not build from that
  list without being asked.

## Review gates
The owner judges look and feel from screenshots or by playing. Do not call a visual or feel change
done without showing captures.
