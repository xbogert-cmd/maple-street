# Maple Street — design

Agreed with the owner on 2026-10-09. A Project Zomboid-style sandbox without zombies: you are a
Soviet sleeper agent on one American suburban street in the 1980s. The pressure is being noticed,
not being outnumbered.

## Owner's decisions

| Topic | Decision |
|---|---|
| Title | Maple Street |
| Setting | 1980s America, real Cold War, serious thriller tone |
| Look | 3D low-poly, fixed Zomboid-style isometric camera |
| Violence | Non-lethal tools are the norm (knock out, lock in). Killing is allowed as a last resort for a witness, with a body, a missing-person report and police |
| Daily life | Light: food and sleep matter. The day job is a short playable shift, never a pure time-skip |
| Cover job | Janitor at the defence plant (the target building) |
| Household | The player alone. Keep room for a second person later |
| Saving | Permadeath. Saves when you sleep. Arrest ends the agent; a new game reshuffles the street |
| Code | Local git plus a private GitHub repo |
| Extras wanted | Shuffled street, turn a neighbour, hidden counter-agent, dogs and kids, street events, your car, phone taps and bugs |
| Extras declined | Impatient handler (no deadlines) |
| Platform | Mac, keyboard + trackpad, Godot 4.7.1, desktop shortcut app like the other games |

Ideas offered by Claude and not objected to (build after the owner's picks): trash as intel and
evidence, key copying, rain, evidence scramble before a search, morning paper. Later: disguises,
snow footprints, neighbourhood watch.

## The loop

1. **Radio** at home, evenings: the Centre gives a job against a named neighbour.
2. **Cover**: go to work, be seen doing normal things. Skipping work raises suspicion.
3. **Scout**: learn when the house is empty, which door or window is weak, whether there is a dog.
4. **Job**: get in, search containers, photograph / bug / borrow, put everything back, get out.
5. **Dead drop** in the park at night. Intel points are the score.
6. **Sleep** saves the game and advances to morning.

There is no win screen. A run ends by arrest, or by taking extraction at the bus stop once blown.

## Systems

**Senses.** Every person has a vision cone blocked by walls (not by windows) and hears noise
events (running, lockpicking, a barking dog, a struggle). How visible you are depends on light,
stance and distance.

**Suspicion.** Per neighbour, 0–100, with remembered reasons ("saw you in the Hendersons' yard at
night"). Sources: trespass, being seen at a lock, being inside, containers left disturbed, doors
left open, skipped work, odd hours. Each evening neighbours gossip and a share spreads next door.

**Heat.** Street-wide, derived from suspicion. Past the first threshold an investigator starts
parking on the street and interviewing. Past the second your house is searched: contraband outside
a good enough hiding place means arrest. Before a search you get a short scramble to hide or burn.

**Witnesses.** A neighbour who clearly sees you inside their home recognises you and heads for the
phone. You can leave before being recognised, knock them out (they report when they wake), or kill
them (no report, but a body to move, a missing-person case and a big heat jump).

**Houses.** Built from room templates: thin walls, doors, windows, furniture, containers. Roofs
hide interiors unless you are inside. Locks take time to pick; windows may be unlatched.

**People.** About two per house with schedules: plant workers, a retiree who watches the street,
kids at school. Schedules vary a little daily and sometimes someone comes home early.

**Job shift.** A small plant floor where you mop marked spots. Offices can be peeked into for
leads at some risk. Pay buys food and gear.

**Shuffle.** A seed decides who lives where, their jobs, schedules, secrets and which one is the
counter-agent.

**Counter-agent.** Acts like a neighbour until heat is raised, then watches you actively. Tells:
never goes to the plant, lights on late, walks the street at night.

**Turning a neighbour.** Secrets found in trash, mail or bugs can be used to recruit that person,
who then brings documents out. A recruited asset can crack if heat is high.

## Build order

1. Street, houses, camera, player, clock and lighting.
2. Neighbours: navigation, schedules, vision, suspicion.
3. Containers, locks, missions, radio, dead drop, HUD.
4. Heat, investigator, search, arrest, extraction, save, menus.
5. Job shift, needs, shop.
6. Extras in this order: shuffled street, dogs and kids, bugs, street events, car, turning a
   neighbour, counter-agent, then Claude's extras.

## Technical shape

- Godot 4.7.1, typed GDScript, everything (models, textures, sounds) made by code. No art files.
- `game/core` autoloads (`Clock`, `Game`), `game/world` (street and house builders),
  `game/actors` (figure, player, neighbour, dog), `game/systems` (suspicion, missions, heat),
  `game/ui`.
- Neighbours path on a navigation mesh baked from the generated street at start.
- Rules that can be tested without graphics (suspicion maths, mission generation, shuffle,
  search outcome) get tests in `tests/`, run by `tools/dev/check.sh`.
- Scripted demos with screenshots (`-- --demo=<name> --shots=<dir>`) for look and feel reviews.
