# 60 Seconds: World Reatomized — Master Architecture & Interface Contract

## Overview
Godot 4.3 (`gl_compatibility`, `1280x720`) survival strategy + frantic real-world house scavenge game.
Autoloads configured in `project.godot`:
- `GameState` (`res://scripts/core/game_state.gd`)
- `SoundManager` (`res://scripts/audio/sound_manager.gd`)

## Important Godot 4.3 GDScript Rules (Zero Parse Errors!)
1. **Never use `:=` type inference on untyped `Dictionary`/`Array`/`JSON` lookups** (e.g., `var x := dict["key"]` FAILS to compile in Godot 4.3 because `dict["key"]` is `Variant`!). Always write explicit types with conversion (`var x: float = float(dict.get("key", 0.0))`, `var s: String = str(dict.get("name", ""))`, `var sub: Dictionary = dict.get("sub", {})`).
2. Only write to the exact files assigned to your agent. Do NOT edit `project.godot` or `scripts/core/game_state.gd`.

---

## Visual Style Palette (Mid-Century 1950s CONELRAD Civil Defense)
- Bunker Dark BG: `Color("#1a1d1a")` / `Color("#242924")`
- Notebook Parchment: `Color("#efe3c8")`, Aged Paper Darker: `Color("#dccba6")`
- Ink Outline / Text Dark: `Color("#1d1a16")`
- CONELRAD Hazard Yellow: `Color("#f2b82e")`
- Atomic Alert Red/Orange: `Color("#d94c2a")`
- Fallout Toxic Green: `Color("#7ec850")`
- Water Cyan-Blue: `Color("#3b8ec2")`

---

## Module Contracts & Exact Method Signatures

### 1. `ItemDB` (`res://scripts/core/item_db.gd`, `class_name ItemDB`)
Canonical item IDs:
- 1-slot items (`slots = 1`): `"soup"`, `"water"`, `"medkit"`, `"gas_mask"`, `"radio"`, `"flashlight"`, `"map"`, `"book"`, `"ammo"`, `"bug_spray"`, `"padlock"`, `"cards"`, `"checkers"`, `"harmonica"`
- 2-slot items (`slots = 2`): `"axe"`, `"rifle"`, `"suitcase"`, `"toolbox"`
- Companion icons (for drawing): `"cat"`, `"dog"`

Required static methods:
- `static func get_all_item_ids() -> Array[String]`
- `static func get_scavenge_pool_ids() -> Array[String]`
- `static func get_item_info(item_id: String) -> Dictionary`
  Returns `{"id": String, "name": String, "short_name": String, "slots": int, "category": String, "description": String, "preferred_rooms": Array, "color": Color}`
- `static func draw_item_icon(canvas: CanvasItem, item_id: String, center: Vector2, size: float, broken: bool = false) -> void`
  Draws detailed multi-shape vector art centered at `center` fitting within `size x size` pixels. If `broken == true`, draws crack lines and a red `X` badge.

### 2. `CharacterArtist` (`res://scripts/family/character_artist.gd`, `class_name CharacterArtist`)
Renders custom family members consistently across Family Creator, 60s Scavenge, and Bunker Survival.
Reads fields from a `member: Dictionary` (see `GameState.make_family_member`):
`name`, `role` (`"adult"|"teen"|"child"|"elder"`), `age`, `skin_tone` (`0..5`), `hair_style` (`0..7`), `hair_color` (hex String), `eye_color` (hex String), `glasses` (bool), `facial_hair` (`0..3`), `outfit_color` (hex String), `shirt_style` (`0..4`), plus runtime states: `hunger`, `thirst`, `sanity`, `sickness`, `injury`, `fatigue`, `radiation`, `is_mutant`, `alive`, `on_expedition`.

Required static methods:
- `static func draw_portrait(canvas: CanvasItem, rect: Rect2, member: Dictionary, show_frame: bool = true) -> void`
- `static func draw_topdown_character(canvas: CanvasItem, pos: Vector2, facing: Vector2, member: Dictionary, walk_phase: float = 0.0, scale_f: float = 1.0) -> void`
- `static func draw_bunker_seated_character(canvas: CanvasItem, seat_pos: Vector2, member: Dictionary, anim_time: float = 0.0, scale_f: float = 1.0) -> void`

### 3. `FamilyScreen` (`res://scripts/ui/family_screen.gd`, `class_name FamilyScreen extends Control`)
Interactive Family Customization screen (`1280x720`).
- Edits `GameState.family_members` (1 to 4 members; guarantees exactly 1 member has `is_leader = true` who is an adult or teen).
- Controls for: Add/Remove Member, Preset Classic Family vs Randomize Family, Name (`LineEdit`), Age slider (`5..85`, auto-updating `role` & `scavenge_slots`), Leader toggle, Trait selector, Skin Tone swatches, Hair Style selector (`8` styles), Hair Color swatches (`8+` colors), Eye Color, Glasses toggle, Facial Hair, Outfit Color & Shirt Style!
- Live preview using `CharacterArtist.draw_portrait` AND condition preview toggle (Preview Healthy / Starving / Crazy / Mutant!).
- Navigation buttons: Back (`GameState.request_screen(GameState.SCREEN_TITLE)`) and Confirm -> Choose House (`GameState.request_screen(GameState.SCREEN_OSM_HOUSE)`).
- Supports `GameState.demo_mode`: smoothly cycles hair colors/styles/ages on screen over ~3.5 seconds before advancing to `SCREEN_OSM_HOUSE`.

### 4. `OsmService` (`res://scripts/osm/osm_service.gd`, `class_name OsmService extends Node`) & `OsmSlippyMap` (`res://scripts/osm/osm_slippy_map.gd`, `class_name OsmSlippyMap extends Control`) & `HouseSelectScreen` (`res://scripts/ui/house_select_screen.gd`, `class_name HouseSelectScreen extends Control`)
- `OsmService`:
  - Live geocoding via `https://nominatim.openstreetmap.org/search?q=<encoded>&format=json&limit=5` (`User-Agent: SixtySecondsWorldReatomized/1.0`).
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
  - Downloads & caches `256x256` OSM PNG tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`), supports drag pan, mouse-wheel/button zoom (`z = 15..18`), draws building polygons on top, highlights hovered house in yellow & selected house in bright CONELRAD orange/yellow, draws POI markers (Church cross, Grocery cart, Pharmacy cross, Neighbor house), emits `house_clicked(building_dict: Dictionary)`.
- `HouseSelectScreen`:
  - Search bar (`LineEdit` + `Search Live OSM` button), 3 instant real-world preset buttons (`Seattle: Capitol Hill`, `Concord, MA`, `Brooklyn, NY`), `OsmSlippyMap` centerpiece, right-hand Inspector showing Selected House footprint diagram, address, `m²` area, room estimate, AND list of real nearby Churches, Grocery Stores, Pharmacies, and Neighbor Houses discovered!
  - Updates `GameState.selected_house` and `GameState.nearby_pois`.
  - Next button -> `GameState.request_screen(GameState.SCREEN_NUKE)`.
  - Supports `GameState.demo_mode` (~4.5s animated pan/search + selecting specific house + showing nearby QFC Supermarket & Church before advancing).

### 5. `HouseGenerator` (`res://scripts/scavenge/house_generator.gd`, `class_name HouseGenerator extends RefCounted`)
- `static func generate_from_osm_house(house_data: Dictionary, family_members: Array, rng: RandomNumberGenerator) -> Dictionary`
- Scale: `const PX_PER_METER: float = 46.0`. Clamps/normalizes extreme OSM footprints to reasonable residential playable dimensions (`11m..24m` span) while preserving the exact polygon silhouette / aspect ratio of the selected OSM house!
- Subdivides interior into named rooms (`Kitchen`, `Living Room`, `Master Bedroom`, `Bedroom`, `Bathroom`, `Garage / Study`, `Hallway`), places central **Bunker Hatch** (`hatch_pos: Vector2`, `hatch_radius: float = 52.0`), builds wall segments (`Array[Rect2]` or `Array[Dictionary]`) with doorways (`>= 72 px` wide), furniture props, and **verifies via grid BFS flood-fill** from `hatch_pos` that every spawned item & family member sits on a walkable tile reachable from `hatch_pos`!
- Guarantees rich classic *60 Seconds!* random house spawn:
  - `5..8` Soup cans (`"soup"`), `5..8` Water bottles (`"water"`), `1` `"medkit"`, `1` `"gas_mask"`, `1` `"radio"`, plus `8..11` randomized items from `ItemDB.get_scavenge_pool_ids()` (ensuring `"suitcase"`, `"book"`, `"flashlight"`, `"map"`, `"axe"` or `"rifle"`, `"padlock"`, `"cards"`/`"checkers"`, `"bug_spray"` frequently appear!), plus all non-leader `family_members` placed in bedrooms/living room, and `leader_start_pos` near `hatch_pos`.
- Returns Dictionary:
  `{"bounds": Rect2, "outer_polygon": PackedVector2Array, "rooms": Array, "walls": Array, "furniture": Array, "hatch_pos": Vector2, "hatch_radius": float, "leader_start_pos": Vector2, "items": Array, "family_spawns": Array, "nav_grid": Dictionary}`.

### 6. `NukePhysics` (`res://scripts/nuke/nuke_physics.gd`, `class_name NukePhysics extends RefCounted`) & `NukeScreen` (`res://scripts/ui/nuke_screen.gd`, `class_name NukeScreen extends Control`)
- `static func haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float`
- `static func compute_impact(house_lat: float, house_lon: float, nuke_lat: float, nuke_lon: float, yield_kt: int, wind_deg: float, target_name: String = "") -> Dictionary`
  Populates all fields of `GameState.nuke_config` (`distance_km`, `zone`, `initial_sv_hr`, `bunker_temp_c`, `tremor_intensity`, `structural_damage`, `raider_aggression`, `fallout_days`, `scavenge_seconds`: `60.0`, `scout_seconds`: `8.0`).
- `NukeScreen`:
  - Dual-mode Tactical Map: **Global World Map** (equirectangular coastlines/continents + major cities) AND **Regional Strike Radar** (100km radius around player's OSM house!) so the player can drop the nuke right downtown 3 km from their house OR across the globe!
  - Yield buttons (`15 kt Tactical`, `250 kt Warhead`, `800 kt ICBM`, `50 Mt Tsar Bomba`), Wind direction dial, live Hazard Impact Gauges, and red **"SOUND THE SIREN — START 60s!"** button -> `GameState.request_screen(GameState.SCREEN_SCAVENGE)`.
  - Supports `GameState.demo_mode` (~3.5s showcasing target selection & blast wave rings before launching Scavenge).

### 7. `ScavengeScene` (`res://scripts/scavenge/scavenge_scene.gd`, `class_name ScavengeScene extends Node2D`)
- Runs the 8-second Scout countdown + **60.0-second CONELRAD Scavenge** inside the OSM house!
- Calls `GameState.reset_to_defaults()` inventory reset (preserving `family_members`, `selected_house`, `nearby_pois`, `nuke_config`) at start of scavenge.
- Player controls leader (`is_leader == true`). Base `max_slots = 4` (becomes `5` once `"suitcase"` is deposited into Hatch!).
- Picking up items (`1` or `2` slots) or non-leader family members (`2` or `3` slots) adds to `carried_entries`. Walking within `hatch_radius + 18.0` deposits all carried items (`GameState.add_scavenged_item`) & family (`member["in_bunker"] = true`) into the bunker with sound & floating text!
- At `<= 15.0s`, red siren light pulses; player can press `F` / click `"DIVE INTO BUNKER"` when near Hatch, or if standing within `hatch_radius + 32.0` when timer hits `0.0`, leader safely enters bunker (`leader["in_bunker"] = true`). If leader fails to reach hatch before `0.0`, nuclear flash triggers (if another adult/teen is already in bunker, survival continues without leader; otherwise Game Over!).
- Transitions to `GameState.request_screen(GameState.SCREEN_BUNKER)`.
- In `GameState.demo_mode`, smart AI pathfinds around walls (`nav_grid` A*/BFS) to collect Soup, Water, Suitcase, Gas Mask, Radio, Medkit, Weapon, and Family Members, deposits them at the Hatch, and dives into the Bunker cleanly!

### 8. `BunkerSim` (`res://scripts/bunker/bunker_sim.gd`, `class_name BunkerSim extends RefCounted`) & `ExpeditionEngine` (`res://scripts/expedition/expedition_engine.gd`, `class_name ExpeditionEngine extends RefCounted`)
- `BunkerSim.advance_day(ration_plan: Dictionary, medkit_target_id: String, event_outcome: Dictionary, expedition_launch: Dictionary) -> Array[String]`
  - `ration_plan`: `{member_id: {"soup_q": int, "water_q": int}}` (`1` quarter = standard daily ration!).
  - Exact survival thresholds, Nuke temperature/radiation effects, age modifiers, Sharikov/Pancake upkeep, Mutant perk, Rescue/Game-Over evaluation.
- `ExpeditionEngine`:
  - `static func get_available_targets() -> Array` (returns `GameState.nearby_pois` enriched with radiation risk, travel days `1..3`, expected loot icons).
  - `static func start_expedition(member_id: String, poi_index: int, gear_ids: Array) -> String`
  - `static func tick_active_expedition() -> Dictionary` (resolves return from real OSM Church / Grocery Store / Neighbor House / Pharmacy / Hardware Store with authentic named journal story & loot!).

### 9. `EventDeck` (`res://scripts/events/event_deck.gd`, `class_name EventDeck extends RefCounted`)
- `static func draw_daily_event(day: int, rng: RandomNumberGenerator) -> Dictionary`
  Returns structured event with `id`, `title`, `description` (interpolating real OSM names & Nuke zone!), `type` (`"item_choice"` | `"yes_no"` | `"none"`), `options`: Array of `{"id", "label", "item_id", "available": bool}`, and `static func resolve_event(event_dict: Dictionary, choice_id: String, rng: RandomNumberGenerator) -> Dictionary` updating `GameState` and returning `{"outcome_text": String, "tags": Array}`.

### 10. `SoundManager`, `ThemeHelper`, `TitleScreen`, `BunkerBackdrop`, `BunkerScene`, `SummaryScreen`
- `SoundManager` (`res://scripts/audio/sound_manager.gd`): Procedural `AudioStreamWAV` synth with methods:
  `play_sfx(sfx_name: String)` (`"siren"`, `"tick"`, `"urgent_tick"`, `"pickup"`, `"hatch_drop"`, `"hatch_slam"`, `"nuke_boom"`, `"page_turn"`, `"button_click"`, `"geiger"`, `"knock"`, `"victory"`, `"gameover"`), `set_ambience(mode: String)` (`"menu"`, `"scavenge"`, `"bunker"`, `"none"`).
- `ThemeHelper` (`res://scripts/ui/theme_helper.gd`, `class_name ThemeHelper`): `static func get_game_theme() -> Theme` + styled panel/button helpers.
- `TitleScreen` (`res://scripts/ui/title_screen.gd`, `class_name TitleScreen extends Control`)
- `BunkerBackdrop` (`res://scripts/bunker/bunker_backdrop.gd`, `class_name BunkerBackdrop extends Control`)
- `BunkerScene` (`res://scripts/bunker/bunker_scene.gd`, `class_name BunkerScene extends Control`)
- `SummaryScreen` (`res://scripts/ui/summary_screen.gd`, `class_name SummaryScreen extends Control`)
