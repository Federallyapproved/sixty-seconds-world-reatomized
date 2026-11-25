# The End Is Near — Master Architecture & Interface Contract

## Overview
Godot 4.3 (`gl_compatibility`, `1280x720`) survival strategy + frantic real-world house scavenge game.
Autoloads configured in `project.godot`:
- `GameState` (`res://scripts/core/game_state.gd`)
- `SoundManager` (`res://scripts/audio/sound_manager.gd`)

## Important Godot 4.3 GDScript Rules (Zero Parse Errors!)
1. **Never use `:=` type inference on untyped `Dictionary`/`Array`/`JSON` lookups** (e.g., `var x := dict["key"]` FAILS to compile in Godot 4.3 because `dict["key"]` is `Variant`!). Always write explicit types with conversion (`var x: float = float(dict.get("key", 0.0))`, `var s: String = str(dict.get("name", ""))`, `var sub: Dictionary = dict.get("sub", {})`).
2. Only write to the exact files assigned to your agent. Do NOT edit `project.godot` or `scripts/core/game_state.gd`.
3. **Scripts run with `-s` (`extends SceneTree`) compile before the autoloads exist.** In them, reach `GameState` with `root.get_node("GameState")`, and `load()` at run time any script that uses `GameState` or `SoundManager` (scenes, `BunkerSim`, `RadiationModel`, ...) instead of naming its class; otherwise Godot caches a broken copy. The shelter engine (`scripts/shelter/`) and `scripts/data/` use no autoload, so tests and the harness can name them freely.
4. A new `class_name` script needs one `godot --headless --path . --import` before `-s` scripts can see it.

---

## Setting & Visual Style (present day: emergency alert / phone UI)
The game is set now. Phones show no service, the Emergency Alert System and NOAA alerts still
get through, the radio is a hand-crank emergency radio, and the UI looks like a phone in dark mode.
Palette (`ThemeHelper` constants; screens use the same values):
- Background `#0f1115` · Panel `#1a1e24` · Panel raised `#262c34` · Border `#39414b`
- Text `#e8eaed` · Muted text `#9aa3ad`
- Alert amber `#ffb020` · Alert red `#ff4d4f` · OK green `#4cc38a`
- Water blue `#4aa3ff` · Food `#f0a35e`

Tone: deadpan, brief, dry about the world and warm toward the family. No jokes about radiation
sickness, injury, disability or mental illness; a death line has no punchline; no brand names.

---

## Module Contracts & Exact Method Signatures

### 1. `ItemDB` (`res://scripts/core/item_db.gd`, `class_name ItemDB`)
Items come from `data/items.csv` (built to `data/build/items.json`; see `docs/ADDING_CONTENT.md`).
Core ids include `"food"` (canned food), `"water"`, `"medkit"`, `"gas_mask"`, `"radio"` (hand-crank),
`"flashlight"`, `"map"`, `"manual"` (survival manual), `"ammo"`, `"bug_spray"`, `"padlock"`, `"cards"`,
`"console"` (handheld game console), `"axe"`, `"rifle"`, `"suitcase"`. Old saves' `"soup"`/`"book"`
map to `"food"`/`"manual"`. Pet icons (for drawing): `"cat"`, `"dog"`.

Required static methods:
- `static func get_all_item_ids() -> Array[String]`
- `static func get_scavenge_pool_ids() -> Array[String]`
- `static func get_item_info(item_id: String) -> Dictionary`
  Returns `{"id", "name", "short_name", "slots", "category", "description", "purpose", "preferred_rooms", "color"}`
- `static func tooltip_line(item_id: String) -> String` — e.g. `"Medkit [2] — cures one sick or injured person"` (the grab HUD shows it).
- `static func draw_item_icon(canvas: CanvasItem, item_id: String, center: Vector2, size: float, broken: bool = false) -> void`
  Draws the item's SVG icon centred at `center` within `size x size` pixels; `broken` greys it and adds a crack overlay.

### 2. `CharacterArtist` (`res://scripts/family/character_artist.gd`, `class_name CharacterArtist`)
Renders family members consistently across the Family Creator, the grab and the shelter, in present-day clothes.
Reads fields from a `member: Dictionary` (see `GameState.make_family_member`):
`name`, `role` (`"adult"|"teen"|"child"|"elder"`), `age`, `skin_tone` (`0..5`), `hair_style` (`0..7`), `hair_color` (hex String), `eye_color` (hex String), `glasses` (bool), `facial_hair` (`0..3`), `outfit_color` (hex String), `shirt_style` (`0..4`: hoodie, fleece, T-shirt dress, graphic tee, rain jacket), plus runtime states: `hunger`, `thirst`, `sanity` (shown as Withdrawn), `sickness`, `injury`, `fatigue`, `radiation`, `alive`, `on_expedition`.

Required static methods:
- `static func draw_portrait(canvas: CanvasItem, rect: Rect2, member: Dictionary, show_frame: bool = true) -> void`
- `static func draw_topdown_character(canvas: CanvasItem, pos: Vector2, facing: Vector2, member: Dictionary, walk_phase: float = 0.0, scale_f: float = 1.0) -> void`
- `static func draw_bunker_seated_character(canvas: CanvasItem, seat_pos: Vector2, member: Dictionary, anim_time: float = 0.0, scale_f: float = 1.0) -> void`

### 3. `FamilyScreen` (`res://scripts/ui/family_screen.gd`, `class_name FamilyScreen extends Control`)
Interactive Family Customization screen (`1280x720`).
- Edits `GameState.family_members` (1 to 4 members; guarantees exactly 1 member has `is_leader = true` who is an adult or teen).
- Controls for: Add/Remove Member, Default Family vs Randomize Household, Name (`LineEdit`), Age slider (`5..85`, auto-updating `role` & `scavenge_slots`), Leader toggle, Trait selector, Skin Tone swatches, Hair Style selector (`8` styles), Hair Color swatches, Eye Color, Glasses toggle, Facial Hair, Outfit Color & Outfit.
- Live preview using `CharacterArtist.draw_portrait` and a looks-only condition preview (OK / Starving / Sick / Injured / Withdrawn).
- Navigation buttons: Back (`GameState.request_screen(GameState.SCREEN_TITLE)`) and Confirm -> Choose House (`GameState.request_screen(GameState.SCREEN_OSM_HOUSE)`).
- Supports `GameState.demo_mode`: smoothly cycles hair colors/styles/ages on screen over ~3.5 seconds before advancing to `SCREEN_OSM_HOUSE`.

### 4. `OsmService` (`res://scripts/osm/osm_service.gd`, `class_name OsmService extends Node`) & `OsmSlippyMap` (`res://scripts/osm/osm_slippy_map.gd`, `class_name OsmSlippyMap extends Control`) & `HouseSelectScreen` (`res://scripts/ui/house_select_screen.gd`, `class_name HouseSelectScreen extends Control`)
- `OsmService`:
  - Live geocoding via `https://nominatim.openstreetmap.org/search?q=<encoded>&format=json&limit=5` (`User-Agent: TheEndIsNear/1.0`).
  - Live neighborhood fetch via `https://api.openstreetmap.org/api/0.6/map.json?bbox=min_lon,min_lat,max_lon,max_lat` (~0.008 deg span around lat/lon).
  - Bundled instant preset loader from `res://data/osm_presets/seattle_capitol_hill.json`, `res://data/osm_presets/concord_massachusetts.json`, `res://data/osm_presets/brooklyn_carroll_gardens.json`.
  - `static func parse_osm_json(data: Dictionary, ref_lat: float, ref_lon: float) -> Dictionary`
    Extracts:
    1. `buildings`: Array of building Dictionaries with `osm_id`, `name`, `address`, `lat`, `lon`, `building_type`, `area_sqm`, `polygon_latlon` (`Array[Vector2]` where x=lon, y=lat), `footprint_meters` (`Array[Vector2]` local meters relative to building centroid).
    2. `pois`: Real-world POIs (`church`, `grocery`, `pharmacy`, `hardware`, `school`, `restaurant`, `civic`, `park`) from nodes AND building ways with `amenity`, `shop`, `leisure` tags!
    3. `roads`: Highway ways for crisp vector road overlay.
  - `static func build_nearby_targets_for_house(selected_bldg: Dictionary, all_buildings: Array, all_pois: Array) -> Array`
    Builds `GameState.nearby_pois` (12 to 24 best targets around the chosen house: closest real Churches, Grocery Stores / Supermarkets / Bakeries, Pharmacies / Clinics, Schools / Libraries, Hardware / Civic, PLUS closest real Neighboring Houses with street addresses/bearings and meter distances!).
- `OsmSlippyMap`:
  - Downloads & caches `256x256` OSM PNG tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`), supports drag pan, mouse-wheel/button zoom (`z = 15..18`), draws building polygons on top, highlights the hovered house in amber & the selected house in red/amber, draws POI markers (Church cross, Grocery cart, Pharmacy cross, Neighbor house), emits `house_clicked(building_dict: Dictionary)`.
- `HouseSelectScreen`:
  - Search bar (`LineEdit` + `Search Live OSM` button), 3 instant real-world preset buttons (`Seattle: Capitol Hill`, `Concord, MA`, `Brooklyn, NY`), `OsmSlippyMap` centerpiece, right-hand Inspector showing Selected House footprint diagram, address, `m²` area, room estimate, AND list of real nearby Churches, Grocery Stores, Pharmacies, and Neighbor Houses discovered!
  - Updates `GameState.selected_house` and `GameState.nearby_pois`.
  - Next button -> `GameState.request_screen(GameState.SCREEN_NUKE)`.
  - Supports `GameState.demo_mode` (~4.5s animated pan/search + selecting specific house + showing nearby QFC Supermarket & Church before advancing).

### 5. `HouseGenerator` (`res://scripts/scavenge/house_generator.gd`, `class_name HouseGenerator extends RefCounted`)
- `static func generate_from_osm_house(house_data: Dictionary, family_members: Array, rng: RandomNumberGenerator) -> Dictionary`
- Scale: `const PX_PER_METER: float = 46.0`. Clamps/normalizes extreme OSM footprints to reasonable residential playable dimensions (`11m..24m` span) while preserving the exact polygon silhouette / aspect ratio of the selected OSM house!
- Delegates pass-2 levels to `FloorplanGenerator` (rooms inside the real footprint). Subdivides interior into named rooms (`Kitchen`, `Living Room`, `Master Bedroom`, `Bedroom`, `Bathroom`, `Garage / Study`, `Hallway`), places the central **shelter hatch** (`hatch_pos: Vector2`, `hatch_radius: float = 52.0`), builds wall segments (`Array[Rect2]` or `Array[Dictionary]`) with doorways (`>= 72 px` wide), furniture props, and **verifies via grid BFS flood-fill** from `hatch_pos` that every spawned item & family member sits on a walkable tile reachable from `hatch_pos`!
- Item spawns follow the loot tables in `data/` (cans of `"food"`, bottles of `"water"`, the core survival items and a few extras such as `"cards"` or `"console"`), plus all non-leader `family_members` placed in bedrooms/living room, and `leader_start_pos` near `hatch_pos`.
- Returns Dictionary:
  `{"bounds": Rect2, "outer_polygon": PackedVector2Array, "rooms": Array, "walls": Array, "furniture": Array, "hatch_pos": Vector2, "hatch_radius": float, "leader_start_pos": Vector2, "items": Array, "family_spawns": Array, "nav_grid": Dictionary}`.

### 6. `NukePhysics` (`res://scripts/nuke/nuke_physics.gd`, `class_name NukePhysics extends RefCounted`) & `NukeScreen` (`res://scripts/ui/nuke_screen.gd`, `class_name NukeScreen extends Control`)
- `static func haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float`
- `static func compute_impact(house_lat: float, house_lon: float, nuke_lat: float, nuke_lon: float, yield_kt: int, wind_deg: float, target_name: String = "") -> Dictionary`
  Populates all fields of `GameState.nuke_config` (`distance_km`, `zone`, `initial_sv_hr`, `bunker_temp_c`, `tremor_intensity`, `structural_damage`, `raider_aggression`, `fallout_days`, plus legacy `scavenge_seconds`/`scout_seconds`; the grab's real timers come from `GameState.recon_seconds()` / `grab_seconds()`).
- `NukeScreen`:
  - Two maps: a **world map** (equirectangular coastlines/continents + major cities) and a **local map** (up to 60 km around the player's OSM house).
  - Yield buttons (`15 kt`, `250 kt`, `800 kt`, `50 Mt`), wind dial, a live strike-forecast card, a **Story / Normal / Hard** selector (sets `GameState.difficulty`, with a one-line description of each), and the red **"TAKE SHELTER — START THE GRAB"** button -> `GameState.request_screen(GameState.SCREEN_SCAVENGE)`.
  - Supports `GameState.demo_mode` (~3.5s showcasing target selection & blast wave rings before launching Scavenge).

### 7. `ScavengeScene` (`res://scripts/scavenge/scavenge_scene.gd`, `class_name ScavengeScene extends Node2D`)
- Runs the look-around (`GameState.recon_seconds()`: Story 20 s, Normal 10 s, Hard 3 s) and then the grab (`GameState.grab_seconds()`: 60 s, or 30 s on Hard) inside the OSM house.
- Calls `GameState.reset_to_defaults()` inventory reset (preserving `family_members`, `selected_house`, `nearby_pois`, `nuke_config`) at start of scavenge.
- Player controls leader (`is_leader == true`). Hands hold `BASE_CARRY_SLOTS = 4`; carrying the 3-slot suitcase adds `SUITCASE_EXTRA_SLOTS = 4` while it is in your hands (net +1). Item slot counts come from `data/items.csv` (medkit 2, suitcase 3, axe 2, rifle 2, others 1).
- Picking up items (`1` or `2` slots) or non-leader family members (`2` or `3` slots) adds to `carried_entries`. Walking within `hatch_radius + 18.0` deposits all carried items (`GameState.add_scavenged_item`) & family (`member["in_bunker"] = true`) into the bunker with sound & floating text!
- The HUD shows `ItemDB.tooltip_line()` for the item in reach or under the mouse, and the carried slots at all times.
- At `<= 15.0s`, the screen edges pulse red; player can press `F` / click `"CLIMB DOWN THE HATCH NOW"` when near the hatch, or if standing within `hatch_radius + 32.0` when timer hits `0.0`, leader safely enters bunker (`leader["in_bunker"] = true`). If leader fails to reach hatch before `0.0`, nuclear flash triggers (if another adult/teen is already in bunker, survival continues without leader; otherwise Game Over!).
- Transitions to `GameState.request_screen(GameState.SCREEN_BUNKER)`.
- In `GameState.demo_mode`, the autopilot pathfinds around walls (`nav_grid` A*/BFS) to collect food, water, the suitcase, gas mask, radio, medkit, a weapon and the family, deposits them at the hatch, and climbs down.

### 8. The shelter run (`res://scripts/shelter/`)
The rules are pure code: nothing under `scripts/shelter/` reads the `GameState` autoload, so the game screen and the balance harness drive the same calls.
- `ShelterState` (`shelter_state.gd`): one run — rng and seed, difficulty, day, `members` (status, timers, dose history, morale, traits, `loc` = `"shelter"`/`"away"`), `stock`/`broken`/`wear`, pets, `places` (real OSM targets with finite stock), `trips`, rescue `chains`, `warnings`/`scheduled` events, raid clocks, the morning `receipt`, `journal`, `ending`. Helpers: `living()`, `home()`, `has(id)`, `count(id)`, `add/remove`, `food()/water()`, `credit(item, text)` ("Used: X → ..."), `missed(item, text)` ("No x → ..."), `is_over()`.
- `ShelterSim` (`shelter_sim.gd`): `new_run(opts) -> ShelterState`, `begin_day(s)` (morning receipt, omens, today's event), `choose(s, option_id)`, `default_plan(s)`, `ration_preview(s, m, give_food, give_water)`, `end_day(s, plan)`. A plan is `{"rations": {mid: {"food": bool, "water": bool}}, "treat": {mid: true}, "jobs": {mid: {"job": "rest"|"trip", "place": int, "gear": []}}}`. `end_day` runs treatment → rations → jobs → health → weather → morale → pets → raid clock → trips → store drain → close. `ENDINGS` lists the three rescues and the five losses.
- `ShelterTrips` (`shelter_trips.gd`): `preview(s, member, place_idx, gear)` returns everything the planner shows (days, `daily_risk` with its `why` list, `risk_band`, dose band, sickness on return, likely loot, carry, last stocked, rumour, tool needed, followed chance); `launch(s, member, place_idx, gear) -> String` (empty on success, else the reason); `tick(s)` resolves nights away and returns.
- `ShelterEvents` (`shelter_events.gd`): `draw(s)` (scheduled → rescue chain due → quiet day → weighted pick, with the fairness filters), `options_for(s, ev)` (Needs: X and stakes; exact odds on Story), `resolve(s, ev, option_id)`, `apply_effect(s, e, ctx, tags)` for every op in `DataSchema.EFFECT_OPS`.
- `ShelterChains` (`shelter_chains.gd`): the convoy, neighbourhood and airlift chains — `init`, `due_event`, `tick`, `step`, `progress`. A missed request returns once as a retry variant (`MAX_MISSES = 1`).
- `ShelterData` (`shelter_data.gd`): cached reads of `data/build/*.json` — `items()`, `item(id)`, `item_name(id)`, `item_slots(id)`, `core_ids()`, `loot_for(place_type)`, `events()`, `event(id)`, `B(key)` / `Bi(key)` for balance numbers, `reload()`.
- Facades kept for the screens and older tests: `BunkerSim` (`scripts/bunker/bunker_sim.gd`: `start_bunker_run()` builds the `ShelterState` from the grab haul, house, nuke and family; `advance_day(plan, choice_id)`; `sync_world()`; `get_condition_labels(member)`), `ExpeditionEngine.get_available_targets()` (the real targets with the same 2–7 day formula and loot preview), `LootTables`, `LootInventory`. `GameState.shelter` holds the run; `GameState` mirrors it for the artwork (`soup_quarters`/`water_quarters`, `has_cat`/`has_dog`, `rescue_chains`).
- `BunkerScene` (`scripts/bunker/bunker_scene.gd`) is the one-screen day; `TripPlanner` (`scripts/bunker/trip_planner.gd`) is the map + list planner with the risk preview and up to 3 gear items.
- Pets arrive only through events. The car escape (`VehicleSystem`, `GarageView`) is kept compiling but inert while `GameState.FEATURE_CAR_ESCAPE` is false (`VehicleSystem.test_override` lets old tests switch it on); the mutation perk is off (`FEATURE_MUTATION = false`).

### 9. `EventDeck` (`res://scripts/events/event_deck.gd`) — facade
- `static func draw_daily_event(day, rng) -> Dictionary` and `static func resolve_event(event_dict, choice_id, rng) -> Dictionary` now return `GameState.shelter.today_event` and forward the answer to `ShelterSim.choose`; `pick_actor()` and `is_capable(m)` keep their old meaning (the leader if able, else the oldest able non-child).

### 10. `SoundManager`, `ThemeHelper`, `TitleScreen`, `BunkerBackdrop`, `BunkerScene`, `SummaryScreen`
- `SoundManager` (`res://scripts/audio/sound_manager.gd`): Procedural `AudioStreamWAV` synth with methods:
  `play_sfx(sfx_name: String)` (`"siren"`, `"tick"`, `"urgent_tick"` (with the 853/960 Hz alert tone), `"pickup"`, `"hatch_drop"`, `"hatch_slam"`, `"nuke_boom"`, `"page_turn"`, `"button_click"`, `"geiger"`, `"knock"`, `"victory"`, `"gameover"`, ...), `set_ambience(mode: String)` (`"menu"`, `"scavenge"`, `"bunker"`, `"none"`).
- `ThemeHelper` (`res://scripts/ui/theme_helper.gd`, `class_name ThemeHelper`): `static func get_game_theme() -> Theme` + `make_hazard_button` (amber primary), `make_alert_button` (red), `make_card_panel`, `draw_hazard_stripes`, `make_checkbox_icon`, and the palette constants (older names such as `COLOR_PARCHMENT` remain as aliases).
- `TitleScreen` (`res://scripts/ui/title_screen.gd`, `class_name TitleScreen extends Control`)
- `BunkerBackdrop` (`res://scripts/bunker/bunker_backdrop.gd`, `class_name BunkerBackdrop extends Control`)
- `BunkerScene` (`res://scripts/bunker/bunker_scene.gd`, `class_name BunkerScene extends Control`)
- `SummaryScreen` (`res://scripts/ui/summary_screen.gd`, `class_name SummaryScreen extends Control`)

### 11. Data pipeline (`res://data/`, `res://scripts/data/`, `res://tools/build_data.gd`)
- Source tables: `data/items.csv`, `loot_weights.csv`, `balance.csv`, `narration.csv`, `assets_manifest.csv`, and (header-only until M2/M3) `house_rules.csv`, `achievements.csv`, `parts.csv`, `recipes.csv`; events are JSON files in `data/events/`. Every CSV has a `.import` file with `importer="keep"` so Godot does not import it as a translation.
- `DataSchema` (`data_schema.gd`): the allowed event types and moods, effect ops, condition keys, text tokens, chain ids, licences, and the banned words and brands.
- `DataBuilder.build(write := true) -> Dictionary` (`data_builder.gd`) validates everything (types, references, effect ops, item-gate coverage — each core item gates 3+ events — recipe part sources, banned words, every file under `assets/` has a manifest row with an allowed licence) and writes `data/build/*.json` and `CREDITS.md`. It returns `errors`, `warnings` and the built tables.
- `godot --headless --path . -s res://tools/build_data.gd [-- --check]` runs it and exits non-zero on any error. `data/build/` is committed so the game and web export never parse CSV at runtime. See `docs/ADDING_CONTENT.md`.

### 12. Balance harness (`res://tests/sim/`)
- `sim_harness.gd` plays whole shelter runs headless with `ShelterSim` and three policies from `sim_policies.gd` (Random, Naive, Expert), sweeping the 37 cached OSM homes in `tests/fixtures/sim_homes/` (city → farmland; refetch with `tools/fetch_sim_osm.py`, build with `build_fixtures.gd`). The Expert also picks its own grab.
- `tools/run_sim.sh [runs] [shards] [difficulty]` runs it in parallel shards; `sim_report.gd` merges them, checks the section-6 targets and writes `docs/BALANCE_REPORT.md` (with `docs/balance/tuning_log.md` appended). `sim_trace.gd` prints one run day by day.

### 13. Tests
- `tests/m1/data_pipeline_suite.gd` (validator, build freshness, banned words), `tests/m1/shelter_rules_suite.gd` (survival, items, trips, clocks, rescue timing, fairness over hundreds of seeded runs), `tests/m1/capture_shelter.gd` (screenshots).
- `tests/pass2/*` and `tests/critic_*` predate v3 and were ported to the new rules; any check that changed meaning is labelled with the check it replaced. `tests/pass2/play_shelter.gd` plays the shelter through real key and mouse events.
