# M4 — First-person house grab, asset starter kit, characters

Branch `v3-m4-firstperson`, stacked on `v3-m3-crafting` (PR #11). Godot 4.3, GL Compatibility, web export.

## What changed

**The grab is first person.** The house is the selected building's real OpenStreetMap outline, extruded to 2.55 m walls; rooms, doors and furniture still come from `FloorplanGenerator`, regenerated every run. Every room has a floor (wood, tiles, carpet or concrete by room type), a ceiling, walls painted per room (the side of a wall facing the kitchen is the kitchen's colour), door frames over every doorway, windows on the outer walls with a dusk sky behind them, the locked front and back doors, and one ceiling light. The shelter hatch is a real opening in the floor: a hazard-striped frame, the lid propped open on the far side with its wheel, and a ladder down a lit shaft. Things dropped down it fall into the shaft.

**Controls.** WASD to move (↑ ↓ too), the mouse to look (a click locks the pointer; ESC frees it; ← → also turn), E, SPACE or a left click to grab what the crosshair is on, E at the hatch to drop everything down, right-click or G to drop the selected thing, Q, 1–7 or the wheel to select, F to climb down, TAB to end the look-around. Settings (top right of the title screen): mouse sensitivity, invert-Y, field of view, and the classic top-down grab for slower computers. Mouse look uses the pointer's real screen movement, so sensitivity is the same at any window size. F3 shows frames per second and draw calls.

**Feel.** A generous reach (2.1 m; anything within 0.9 m counts even if it isn't under the crosshair), a crosshair that rings amber on a target and fills while you grab, the name, slot count and purpose of what you aim at, the carried slots always on screen, the timer, and the hatch compass turned to your view. Nothing can be grabbed through a wall. Items within 5 m carry a subtle outline (an inverted hull, `assets/shaders/outline.gdshader`, original code) that turns bright amber when aimed at; junk the workbench asked for has an orange outline and a ring under it. People don't block the way (as in the top-down grab): walking through someone hides them rather than showing the inside of the model.

**Rules unchanged.** `HouseGrab3D` extends the top-down `ScavengeScene`: hand slots, the timed grab, the suitcase, depositing at the hatch, carrying family to it, the look-around, the timer, the outro and the demo autopilot are the same code. Movement and collision still run on the floorplan, so the 3D house needs no physics; the hatch opening is solid (you stand at its rim). The top-down view is kept as a setting rather than deleted.

**The family.** Everyone the leader has to fetch stands in the house as a 3D figure: a Quaternius Universal Base Character body with clothes painted on by a shader in the member's outfit colour and style (hoodie and fleece with long sleeves, tees with short ones, the T-shirt dress to the knee, the rain jacket long), tinted skin and hair, and an idle from the Universal Animation Library (adults try a phone with no signal, a teen folds their arms, a child crouches). Aiming at someone outlines them.

**Asset starter kit (all CC0).** Kenney Furniture Kit, Survival Kit and Food Kit; Quaternius Universal Base Characters and Universal Animation Library 1 and 2 (free Standard versions); ambientCG WoodFloor051, Tiles141, Carpet016, Concrete034 and Plaster002 (1K colour, 512 px normals). Each licence file was read before anything went in. Every file has a row in `data/assets_manifest.csv`; `CREDITS.md` now lists each pack once; the CC0 legal text is in `licenses/`. Only the files the game uses are in the repo: 53 furniture models, 14 props with their two colour maps, 2 bodies and 8 hair pieces (textures cut to 1K and 512 px), and 19 animation clips cut from the 34 MB libraries by `tools/build_family_anims.gd`. The rest of the section 18 kit (Kenney UI, particles and audio, music, the CRT shader, Dialogue Manager, Phantom Camera) belongs to M5 and M6.

## Characters: please choose

The free tier of Universal Base Characters has **only the athletic "Superhero" bodies** (male and female, in underwear); the Regular and Teen bodies the spec suggested are in the paid Source version. What the game does now (picture: `/next/media/m4_family_lineup.png`):

- adults and elders use the two athletic bodies with painted-on clothes;
- a teen is the same body at 92 %;
- a child is the body at 56–74 % (by age) with a 1.24× head.

Options: keep this; buy the Source version ($19.99 on itch.io: Regular and Teen bodies, 20 hairstyles; a purchase, so it needs your go-ahead); or switch to a clothed CC0 pack such as Quaternius' Ultimate Modular Men and Women (modern outfits, but a different rig, so the animation library would have to be retargeted). The spec's free animation check: carry (`Walk_Carry_Loop`) and celebrate (`Dance_Loop`, `Yes`) are in the free tier; there is no injured idle (`Hit_Chest` and `Crouch_Idle_Loop` are the nearest).

## Measured

**Web budget** (`tests/m4/perf_probe.gd` and the windowed playthrough, Compatibility renderer, 1280×720, the same 7-room house as the tests). The spec's targets are about 300 draw calls and one shadowed light per room.

| | Draw calls per frame |
|---|---|
| Whole frame while playing (3,235 frames) | average 205, peak 298, no frame over 300 |
| The 3D house alone (walls, floors, merged furniture) | 29 |
| House + items + their outlines + family + the room's shadow | about 73 |
| The HUD (minimap, timer, slots, tally, tooltip) | about 135 |
| Triangles, peak | about 106,000 (each family figure is about 15,000) |

What it took: the first version drew 578 calls per frame. A shadowed omni light renders its casters six times (a cubemap), so room lights are shadowless and one shadowed spot light moves to the ceiling of the room you're in (−240). The family portraits in the HUD were dozens of shapes each, every frame; they're drawn once into small textures (−200). Each room's furniture, fixtures, windows and doors are merged into one mesh per material, and whole rooms are hidden unless you can see into them through a doorway (portal culling on the floorplan, since occlusion culling doesn't work on the web). Room lights stay on when a room is hidden, so turning around never changes the light.

I can't measure the spec's real target (at least 50 fps in Chrome on a mid-range laptop) from here: this machine has an RTX 4090, where a frame takes about 1 ms. Press **F3** in the grab to see frames per second and draw calls on any machine; the top-down grab in Settings is the fallback.

**Web build.** The `.pck` is 20.7 MB (M3: 9.0 MB): the models, characters and textures. Thread support stays off; textures are VRAM-compressed for desktop with mipmaps.

**The grab with a greedy bot** (`tests/pass2/bot_difficulty_probe.gd`, 12 real houses, now in first person): Normal keeps 54% of core-item value and saves the whole family in 10 of 12 houses; Hard keeps 18% and saves everyone in 5 of 12 (M3, top-down: 48% and 10 of 12; 18% and 5 of 12). The rules are the same code, so the difficulty didn't move.

**Balance.** M4 doesn't touch the shelter, the trips or the data tables (only `assets_manifest.csv` changed under `data/`), and the harness doesn't model the grab's camera, so the M3 numbers stand: at 10,000 runs per policy on Normal, random 0.1%, naive 11.1%, expert 54.1% (Story 79%, Hard 19%). I didn't re-run the eight-process harness this time so as not to load the machine while you were play-testing.

## Tests

All on this branch with Godot 4.3, headless unless noted; windows were placed off the screen (`--position 30000,30000`, no focus). Checks whose meaning changed under M4 say so; none were removed.

| Suite | M3 (PR #11) | M4 |
|---|---|---|
| Data validator | 114 events, 0 errors | 114 events, 38 items, 0 errors; 156 asset manifest rows |
| `tests/m4/grab3d_suite.gd` (new) | — | 617 passed over 24 real houses, from the smallest to the largest building in the cached neighbourhood: rooms with floor, ceiling and light; the hatch is an opening you stand beside; every item and family member reachable without reaching through a wall; the crosshair picks what you look at and nothing behind you or behind a wall; hands full blocks a grab and says so; a drop puts the thing back in the house; rooms out of sight hidden, the room seen through a doorway shown; people never block the way and hide when walked through; models for every furniture kind and item; both bodies, child, teen and elder build with clothes, hair and an idle; outfits never match skin; settings save, load and clamp; the top-down setting still gives the 2D grab; the pointer is never captured |
| `tests/m4/play_grab_3d.gd` (new; simulated mouse motion, keys and clicks; `--fixed-fps 60`) | — | all checks pass on Normal (17 grabs, 8 by left click, 6 trips to the hatch, 3 family down) and Hard (6 grabs, 2 trips, 2 family down), and on four more seeds: mouse look, sensitivity, invert-Y and FOV, the leashed look-around, TAB, grabs by E and by click, the crosshair on the target, hands full (when the robot gets a clean aim; the suite checks it every time), right-click drop back into the house, Q, E at the hatch, family carried down, F, the hand-over to the shelter, the pointer never captured. With a display: no frame over 300 draw calls |
| `tests/pass2/play_scavenge_keys.gd` | 19 grabs | 8 checks, 19 grabs, 7 trips (it now sets the top-down setting first, since it covers the classic view) |
| `tests/pass2/play_shelter.gd` (real key and mouse events) | 35 checks | 35 checks (in an off-screen window: it clicks at screen positions, so it can't run headless) |
| data pipeline · shelter rules · gauntlet · floorplan stress | 182 · 60 · 127 · 5,214 | 182 · 60 · 127 · 5,208 (the stress test draws random houses) |
| 60-second · OSM · QA audits | 78 · 49 · 32 | 78 · 49 · 32 (the QA audit plays the whole demo through the first-person grab; see the note below) |
| drama · achievements · craft | 60 · 39 · 98 | 60 · 39 · 98 |
| compile_all | clean | clean |
| Web export, then the `.pck` run headless | title → day-7 summary | title → day-7 summary through the first-person grab (the autopilot works unchanged); from the pack: the M4 models, characters, animations, shaders and textures load, the grab opens in first person with a 14-room house, 40 items and 3 figures, Settings opens, the top-down setting still works |

One intermittent result: in 1 of 5 runs of the QA audit, its house-generation check got a Brooklyn building with 1 open room where it wants 2. M4 doesn't touch house generation or that check; I haven't found the source yet (the generator also reads the street data the earlier screens cached). Another QA run failed once because the 3D view drew a number from the game's shared random generator, which shifted the demo's later rolls; it no longer does, and the demo sends someone out on day 3 as in M3.

Fixed along the way: mouse look scaled with the window size (the 1280×720 stretch rescales mouse motion; it now uses `screen_relative`); the full-window screen holders swallowed mouse events, so the grab lets them through while it runs; a settings helper named `reload()` collided with Godot's own `Script.reload()` and reset the settings class; Godot's dummy renderer (headless runs) keeps no mesh data, so mesh merging and the clothing bake are skipped there.

## Known limits

- **The characters** (above): athletic bodies with painted-on clothes, and a child that is a scaled adult with a bigger head. Hair styles map to the 8 the free kit has (a curly afro becomes a short crop or buns). No injured idle in the free animations.
- **50 fps on a mid-range laptop is unmeasured** (no such machine here); F3 shows it on yours.
- The leader has no body in first person (no hands or arms), and carried things only show in the slots.
- Items lie on the floor where the floorplan puts them, not on shelves or tables; spec section 13's MultiMesh shelves are for M5's store interiors.
- Kenney's furniture is low-poly and fitted to the floorplan's footprints by stretching, so a few pieces look squat or long.
- Windows show a painted dusk sky, not the street outside; the front and back doors are locked props.
- The minimap still shows every item (as in the top-down grab), which makes the look-around less needed than it could be.
- Headless runs print a few harmless renderer messages when the 3D grab closes (the dummy renderer has no mesh data).
