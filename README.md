# The End Is Near (Godot 4.3)

**The End Is Near** is a present-day nuclear-survival game built in **Godot 4.3** where **any real-world house on Earth** via **OpenStreetMap** becomes your grab-and-go floorplan and home shelter. The phones lose signal, the emergency alerts still get through, and you have a minute. Inspired by *60 Seconds! Reatomized* and *Zombies Aren't Real*.

## Play in Browser & Watch Demo Video

- **Play Directly in Your Browser (WebAssembly)**: **[https://federallyapproved.github.io/the-end-is-near/](https://federallyapproved.github.io/the-end-is-near/)**
- **Watch the Full-HD 1280x720 Gameplay Demo Video**: **[https://federallyapproved.github.io/the-end-is-near/demo.html](https://federallyapproved.github.io/the-end-is-near/demo.html)**
- **Gameplay Improvement Pass (preview build, footage, before/after)**: **[/next/](https://federallyapproved.github.io/the-end-is-near/next/)** · **[/next/media.html](https://federallyapproved.github.io/the-end-is-near/next/media.html)** · validation report: [`docs/PASS2_REPORT.md`](docs/PASS2_REPORT.md)

### Controls

| Where | Keys |
|---|---|
| Grab (first person) | **F3** shows frames per second and draw calls · **WASD** move (**↑ ↓** too) · **mouse** looks (click once to lock the pointer; **ESC** frees it; **← →** also turn) · **E**, **SPACE** or **left-click** grabs what the crosshair is on (timed) · at the hatch **E** drops your load down · **right-click** or **G** drops the selected thing · **Q**, **1–7** or the wheel select a carried slot · **F** climb down · **TAB** end the look-around early · what you aim at shows its name, slot count and what it is for |
| Grab (classic top-down, in Settings) | **WASD / arrows** move · **SPACE** grab · at the hatch **SPACE** drops your load down · elsewhere **SPACE** drops the selected item · **Q** or **1–7** select · **F** climb down · **TAB** end the look-around |
| Settings (top right of the title screen) | mouse sensitivity · invert mouse Y · field of view · the classic top-down grab for slower computers |
| Shelter | one screen per day: **1–4** or click answers the dilemma · click **Give / Skip** for each person's food and water · **Treat** spends a medkit (or a rag bandage on a wound) · each person's **job** button: **Rest**, **Trip…** (the trip planner: map, list, risk preview, gear), **Craft…** (the workbench) or **Study…** (the manual) · **Bench** (top right) takes junk apart and shows the recipes · **ENTER** or **END DAY** ends the day · **SPACE** skips an animation · **ESC** closes the bench |
| Difficulty | **Story**: 20 s look-around, 60 s grab, generous stock, exact odds · **Normal**: 10 s look-around, 60 s grab · **Hard**: 3 s look-around, 30 s grab, faster stock drain, smarter raiders (pick it on the strike screen, or `--difficulty=story|normal|hard`) |

---

## Play Locally in Desktop Godot 4.3 (Windows, macOS, or Linux)

1. Download **Godot Engine 4.3** (Standard, single binary—no install required) from [godotengine.org/download](https://godotengine.org/download/).
2. Clone this repository (or click **Code -> Download ZIP** on GitHub and unzip it):
   ```bash
   git clone https://github.com/Federallyapproved/the-end-is-near.git
   ```
3. Open Godot 4.3, click **Import**, select `project.godot`, and press **Play (`F5`)**!

---

## Core Features

1. **Family Creator (`scripts/ui/family_screen.gd`, `scripts/family/character_artist.gd`)**
   - Build a 1–4 person household (default: Sam, Priya, Maya and Leo) with **names**, **ages (`5–85`)**, **roles** (`Child`, `Teen`, `Adult`, `Elder`), **traits** (`Handy`, `Sprinter`, `Iron Stomach`, `Knows the Area`, `Bookworm`, `Optimist`), **skin tones**, **8 hair styles**, **10 hair colors**, **eye colors**, **glasses**, **facial hair**, and **5 present-day outfits** (hoodie, quarter-zip fleece, T-shirt dress, graphic tee, rain jacket).
   - The same character renders as portraits, top-down sprites in the grab and seated figures in the shelter, with visible conditions (*hungry, thirsty, sick, injured, withdrawn*). The screen is styled as a phone with no signal.

2. **Live OpenStreetMap Real-World House Picker & Neighborhood Scanner (`scripts/osm/`)**
   - Search **any street address, neighborhood, or city on Earth** via live **Nominatim geocoding**, stream real `256x256` **OpenStreetMap PNG slippy tiles**, and fetch real building polygons & POIs via **`api.openstreetmap.org/api/0.6/map.json`** (plus instant cached presets for *Capitol Hill Seattle*, *Concord MA*, and *Carroll Gardens Brooklyn*).
   - **Click any specific house polygon** to claim it as your level—automatically discovering **neighboring houses** alongside real-world **Churches / Sanctuaries**, **Grocery Stores / Supermarkets**, **Pharmacies / Clinics**, **Police & Fire Stations**, **Hardware Stores**, and **Schools / Libraries** with exact geodesic distances and compass bearings.

3. **Global & Regional Nuclear Detonation Impact Planner (`scripts/nuke/`)**
   - Select **where in the world** (or on the local map) the warhead detonates, the yield (`15 kt`, `250 kt`, `800 kt`, `50 Mt`), the wind direction, and the difficulty (**Story / Normal / Hard**).
   - Computes real Haversine distance, cube-root blast overpressure & thermal rings, downwind fallout plumes, surface radiation, inner-ring heat (`+30..+36 °C`, faster thirst), or a distant-strike cold snap (freezing shelter).

4. **The Grab (`scripts/scavenge/`)**
   - Generates the level **inside the building's real OpenStreetMap outline** (`scripts/scavenge/floorplan_generator.gd`): OBB alignment, BSP subdivision into rooms and hallways whose count follows the real floor area, doors only where a doorway fits, front door facing the mapped street, furniture, connectivity healing and BFS/A* verification. Interiors are labelled as fictional approximations.
   - **First person** (`house_grab_3d.gd`, M4): the real outline extruded to 2.55 m walls with windows, door frames, ceilings, painted rooms and one light per room (`house_builder_3d.gd`); Kenney furniture and props fitted to the floorplan, with simple modelled items where no kit has one (`prop_library.gd`); a subtle outline on every item and a brighter one on what you aim at; the family as Quaternius characters in clothes painted on by a shader, idle animations from the Universal Animation Library (`scripts/family/family_figure_3d.gd`). The shelter hatch is an opening with a ladder down a lit shaft. The top-down view is still there as a setting.
   - **Look-around, then the grab** (timers per difficulty), timed grabs, **4-slot hands** (the 3-slot **Suitcase** gives 4 more while carried: net +1), 10 %/slot encumbrance, SPACE-to-deposit at the hatch (no automatic depositing), unique durable items, a last-second climb down the hatch. The HUD shows each item's name, slot count and purpose and keeps your carried slots on screen.

5. **The Shelter & Real-World Trips (`scripts/shelter/`, `scripts/bunker/`, `data/`)**
   - An illustrated home shelter showing your exact stock: **cans of food**, **bottled water**, durable gear, the **padlock** on the hatch, a dog or a cat if one turns up, a dosimeter, a wall thermometer, a printed map of the real neighbourhood, and the seated family.
   - **One screen per day:** the morning receipt ("Used: Medkit → cured Maya", "No axe → the shutter at the pharmacy stayed shut"), the day's dilemma (item options carry their icon; missing items show "Needs: X" and what is at stake), a ration row per person with tomorrow's preview ("Skip water: Sam is thirsty tomorrow (day 3 without)"), Treat, Rest or Trip, then End Day.
   - **Trips to real, finite places** found in OpenStreetMap: walking distance sets the days away (2–7), stock runs out and other survivors empty the shelves, and the planner shows the never-return band, dose band, sickness on return, likely loot, the tool a shutter needs and the chance of being followed home before anyone leaves.
   - **Pressure clocks:** being followed brings raids that the rifle, axe or padlock stop; an unanswered gang tries to take the shelter (warned the morning before); black rain and empty shelves arrive around day 8.
   - **Drama:** at morale 0 people turn Selfish, Paranoid, Reckless or Withdrawn (always with a warning the day before); every 4 days a House meeting can pass one more House Rule ("Finders eat first", "Kids eat last"…), each with a real bonus and a morale cost; some neighbours are still home, and what you take from them stays with you; one rare stranger per run.
   - **Three rescues** heard on the hand-crank radio after the fallout clears — **the convoy**, **the neighbourhood** (opened at a real church or school) and **the airlift** — each a chain of item requests. Nothing lands before day 25. Two gamble endings let the family leave on a hope. (The car escape is switched off: `GameState.FEATURE_CAR_ESCAPE = false`.)

6. **Crafting and salvage (`scripts/shelter/shelter_craft.gd`, `scripts/bunker/workbench.gd`, `data/recipes.csv`)**
   - **Junk** (a toaster, pots and pans, an old phone, a bag of bottles, duct tape…) turns up in the house, in stores and in neighbours' homes, takes carry slots, and comes apart at the **Bench** into six **parts** (Cloth, Metal, Electronics, Plastic, Binding, Chemicals; each with its own shape). The part shelf holds 12.
   - A survivor can spend the day at the bench (two **Quick** recipes or one **Day** recipe) instead of going out. Twelve recipes make **Makeshift** things that are weaker than the real ones and wear out: a rag bandage closes a wound but does nothing for a fever, a door barricade holds one raid 60% of the time, a phone torch can't signal a rescue, a scrap receiver hears the all-clear but can't answer anyone. Crafting fails 20% of the time, 5% with the manual on the shelf.
   - Most recipes are in the manual's four chapters: a day of **Study** learns one, or a **pamphlet** brought home from a pharmacy, a hardware store or a school does it without the manual. The **Need** toggle tags the parts a recipe is short of: that junk is looted first and ringed in the house and in the trip planner.
   - New night-time pressure and supply: thieves who take a little in silence (a **tin-can alarm** turns that into a choice), and **dirty water** from rain and the toilet tank that only a **bottle filter** makes drinkable.

7. **The Survival Almanac and achievements (`scripts/meta/`)**
   - The Almanac fills in as you play: each item's page lists what it was seen doing and the options it opened; items you have never found stay greyed out, and their options stay hidden until you do. Junk and makeshift items have their own tabs; a makeshift page shows its recipe.
   - 30+ achievements that each ask for a decision (none for hiding in the shelter), with an unlock toast. The end-of-run report shows the MVP items, what was missing when it counted, and how each death happened, with the turning point marked.

---

## Content, tests and balance (v3)

The v3 rules live in data, run headless and are measured. Day-to-day commands (Godot 4.3 on `PATH` as `godot`):

| What | Command |
|---|---|
| Validate and build the data (`data/*.csv`, `data/events/*.json` → `data/build/`, `CREDITS.md`) | `godot --headless --path . -s res://tools/build_data.gd` (add `-- --check` to validate only) |
| Data pipeline suite | `godot --headless --path . -s res://tests/pass2/run.gd -- --suite=../m1/data_pipeline_suite` |
| Shelter rules suite | `godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m1/shelter_rules_suite.gd` |
| Drama and achievements suites (M2) | `godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m2/drama_suite.gd` · `--script=res://tests/m2/achievements_suite.gd` |
| Crafting and salvage suite (M3) | `godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m3/craft_suite.gd` |
| M3 screenshots (needs a display) | `godot --path . --rendering-driver opengl3 -s res://tests/m3/capture_m3.gd -- --out=<dir>` |
| First-person grab suite (M4): 3D house, reach, aim, models, figures, settings over 24 real houses | `godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m4/grab3d_suite.gd` |
| First-person grab played with simulated keys and mouse (headless, or with a display for screenshots and draw-call counts) | `godot --headless --fixed-fps 60 --path . -s res://tools/run_node.gd -- --script=res://tests/m4/play_grab_3d.gd --out=<dir> [--hard]` |
| Draw calls by part of the frame (needs a display) | `godot --path . --rendering-driver opengl3 -s res://tools/run_node.gd -- --script=res://tests/m4/perf_probe.gd` |
| Rebuild the family's animation clips from Quaternius' Universal Animation Library GLBs | `godot --headless --path . -s res://tools/build_family_anims.gd -- --ual1=<UAL1_Standard.glb> --ual2=<UAL2_Standard.glb>` |
| Systems gauntlet, QA, 60-second and OSM audits | `godot --headless --path . -s res://tests/pass2/run.gd -- --suite=systems_gauntlet` · `godot --headless --fixed-fps 30 --path . -s res://tests/critic_qa_audit.gd` · `-s res://tests/critic_60s_audit.gd` · `-s res://tests/critic_osm_audit.gd` |
| Keyboard-and-mouse playthrough of the shelter (needs a display) | `godot --path . --rendering-driver opengl3 -s res://tests/pass2/play_shelter.gd -- --out=<dir>` |
| Balance harness: 10,000 runs per policy (random, naive, expert, and the "crafter" stress test), writes `docs/BALANCE_REPORT.md` | `GODOT=godot tools/run_sim.sh 10000 8 normal` |
| One simulated run, day by day | `godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/sim_trace.gd --policy=expert --seed=5` |

Adding an item, event or loot table is a data change: see [`docs/ADDING_CONTENT.md`](docs/ADDING_CONTENT.md). Milestone reports: [`docs/M1_REPORT.md`](docs/M1_REPORT.md) · [`docs/M2_REPORT.md`](docs/M2_REPORT.md) · [`docs/M3_REPORT.md`](docs/M3_REPORT.md) · [`docs/M4_REPORT.md`](docs/M4_REPORT.md) · balance: [`docs/BALANCE_REPORT.md`](docs/BALANCE_REPORT.md).

Test windows are opened without taking focus: keep a local `override.cfg` (git-ignored) with `[display]` / `window/size/no_focus=true`; add `--position 30000,30000` to keep a capture window off the screen. Test tools pass `--automation` (or set `GameSettings.automation`), so the grab never locks the real mouse pointer.
