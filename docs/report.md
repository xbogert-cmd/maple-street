# Maple Street — build report

Built overnight on 2026-10-09 from the design in
`docs/superpowers/specs/2026-10-09-maple-street-design.md`.

## What is in the game

| Area | State |
|---|---|
| Street: 12 houses from 3 floor plans (mirrored), park, market, plant bus stop, day and night | Built |
| You: walk, run, sneak; doors, windows, containers; pockets; notebook | Built |
| Neighbours: daily routines, cars, sleep, sight cones, hearing, per-person suspicion and memory, gossip | Built |
| Jobs from the Centre: photograph, borrow-and-copy, bug a telephone; darkroom bench; three dead drops | Built |
| Consequences: break-in signs found on return, police calls, patrols, the man from the Bureau, house searches with a 45-second scramble, arrest, leaving town | Built |
| Daily life: hunger, tiredness, sleep (saves), Miller's Market, playable janitor shift with snooping and write-ups | Built |
| Killing as a last resort: bodies, discovery, carrying, the pond, the car trunk, missing-person reports | Built |
| Extras chosen by the owner: shuffled street, dogs and kids, telephone taps, Saturday barbecue, your car, turning a neighbour, hidden counter-agent | Built |
| Claude's extras: trash and mail as intel, key copying, rain, evidence burning, morning paper | Built |
| Sound: footsteps, doors, lockpicks, barks, alarm stings, radio static, siren, rain, crickets (all synthesised) | Built |
| Save on sleep, permadeath, title menu, end screen, desktop shortcut | Built |

## Graphics and ambience pass (second session, same night)

- **Houses:** clapboard siding, shingled roofs with fascia and brick chimneys (smoke when someone
  is home in the evening), front porches with a light, shutters and curtains in a colour per
  house, door panels and knobs, skirting, textured floors.
- **Furniture:** every piece is drawn in detail (sofa cushions, bookshelves full of books, a
  typewriter on the desk, a red safelight at your bench), plus rugs, lamps that light up, chairs
  and pot plants.
- **Gardens and street:** flower beds, shrubs, rail fences, sheds, washing lines, vegetable
  patches, kennels, toys, kerbs, crosswalks, telephone poles, a hydrant, a telephone box, three
  kinds of tree that sway slightly, boxy 1980s sedans and station wagons.
- **Park and market:** stone-rimmed pond with reeds, a running fountain in a ring of flowers,
  playground, park lamps, fireflies at dusk; a brick market with a striped awning and crates.
- **People:** faces, shoes, belts, skirts, short sleeves, six hair styles, moustaches, glasses,
  caps on the kids, a slight walking bob.
- **Light:** colour through the day from a low orange dawn to golden hour to blue night, light
  cones and moths under street lamps, television flicker in living rooms, lightning in storms,
  a soft vignette and a trace of film grain.
- **Interface:** typewriter lettering throughout.
- **Sound:** birdsong by day, wind, a quiet night score that turns tense when someone is
  watching you, thunder, and the plant whistle at 7 AM and 5 PM on weekdays.

Frame rate after this pass, vsync off on this Mac: 160 to 270 fps. The 17 tests still pass.
Ideas saved for later and new ones to choose from are in `docs/ideas.md`.

## What has been checked, and how

- `tools/dev/check.sh` runs 16 tests. They build the real street and drive it: routines over a
  day, a neighbour walking out and back, a full job by the on-screen prompts, being caught
  inside, dogs, the barbecue, body discovery, the counter-agent, shopping, the shift, sleep and
  save, and both search outcomes.
- Screenshots were taken of the street by day and night, interiors, every panel, the plant, the
  barbecue, rain and the police.
- The desktop shortcut was launched once and opened the game.
- Frame rate with vsync off on this Mac was 230 to 330 fps before the graphics pass (160 to 270 after).
- A simulated week with nobody at the controls ran through the daily turnover, the Bureau's
  arrival and a house search without errors.

## What has not been checked

- **Nobody has played it by hand.** Movement, doors and prompts were exercised by scripts, but
  feel, pacing and difficulty are untested by a person. Expect the numbers below to need tuning.
- Sound, including the new ambience and score, was generated and wired up but never listened to.
  Volumes are a guess; they are set in `Sfx.ambience` and at each `Sfx.play` call.
- A run longer than a few simulated days has not been played through.

## Numbers most likely to need tuning

| What | Now | Where |
|---|---|---|
| Game minute | 0.75 s (a day is 18 minutes) | `Clock.SEC_PER_MIN` |
| Lockpick time | 8 s at level 0 | `Interact._portal` |
| Time from "!" to the police being called | walk to the phone plus 4 s | `Neighbour._routine` |
| Police arrival | 40 game minutes (30 s) | `Law.RESPONSE_MIN` |
| Heat for the investigator / a search | 35 / 65 | `Rules` |
| Search finds: floor hiding place / floor safe | 25% / 8% per item | `Rules.find_chance` |
| Shift length | about 75 s | `Shift.RATE` |

## Decisions taken without the owner

- Three keys for ordinary actions (E, R, T) because some spots offer three choices.
- A quiet takedown needs you sneaking and behind the person; otherwise they see your face.
- Kids tell their parents (half weight) and nobody phones the police on a child's word alone.
- The counter-agent needs no telephone: if he gets a clear look, the Bureau knows at once.
- The Centre leaves a spare listening device at a dead drop after each completed job.
- Passing out from exhaustion inside someone else's house ends the run.
- The shortcut runs the project through the installed Godot, the same as the other games.

## Not built

- A second person in the household, disguises, snow footprints, neighbourhood watch (all marked
  "later" in the design).
- Driving the car on the street. The car is a trunk, a way to dump a body and a way to leave.
- Per-room hiding of furniture: a house between you and the camera is shown cut away, people
  inside stay hidden unless you have a line of sight.
