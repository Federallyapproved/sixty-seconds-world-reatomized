# 60 Seconds: World Reatomized — V2 Autonomous Redesign Architecture Contract

## Core Autoloads (`project.godot`)
- `GameState` (`res://scripts/core/game_state.gd`) — ALREADY UPDATED ON DISK. Read it before coding!
- `SaveManager` (`res://scripts/core/save_manager.gd`) — ALREADY UPDATED ON DISK. Read it before coding!
- `SoundManager` (`res://scripts/audio/sound_manager.gd`)

## Strict Rules for All V2 Builder Sub-Agents
1. **Read `scripts/core/game_state.gd` and `scripts/core/save_manager.gd` first** so you use exact property and method names.
2. **ONLY modify the exact files assigned to you.** Do NOT touch `project.godot`, `scripts/core/game_state.gd`, `scripts/core/save_manager.gd`, or files owned by sibling agents.
3. **Do NOT run project-wide `godot` on `/home/antigravity/sixty_seconds_world`** while sibling agents are editing files (you may test isolated copies in `/tmp` if needed).
4. **Godot 4.3 Strict GDScript Typing**: NEVER write `var x := dict["key"]` or `var x := arr[i]` on untyped Dictionaries/Arrays/Variants! Always write explicit types with casts (`var x: float = float(dict.get("key", 0.0))`, `var s: String = str(dict.get("k", ""))`).

---

## V2 New & Expanded Item / Category / Relationship Contracts

### 1. Specialty Bunker & Landmark Items (`ItemDB`)
- **18 Canonical House Scavenge Items** (`ItemDB.get_all_item_ids()` MUST still return these exact 18 IDs with `axe`, `rifle`, `suitcase`, `toolbox` = `2` slots and the other `14` = `1` slot!):
  `soup`, `water`, `medkit`, `gas_mask`, `radio`, `flashlight`, `map`, `book`, `ammo`, `bug_spray`, `padlock`, `cards`, `checkers`, `harmonica`, `axe`, `rifle`, `suitcase`, `toolbox`.
- **New Specialty Landmark / Bunker Items** (`ItemDB.get_specialty_item_ids() -> Array[String]`):
  - `"antibiotics"` — Prescription Antibiotics (Doctor's Office / Urgent Care specialty; cures Stage-1/2 `sickness` & infection + prevents wound sepsis!)
  - `"antirad"` — Potassium Iodide Anti-Rad Pack (Pharmacy / Clinic specialty; purges `-35.0` Rads & blocks rad sickness!)
  - `"scrap"` — Salvaged Scrap & Hardware (Hardware / Auto Shop; repairs broken items or reinforces shelter hull `+12%`!)
  - `"fuel"` — Gasoline Jerrycan (Gas Station / Auto Shop; `fuel_cans` toward `fuel_needed` for Station Wagon Escape!)
  - `"battery"`, `"alternator"`, `"spark_plugs"`, `"radiator_hose"`, `"vehicle_part"` — 4 Station Wagon Engine Parts (`GameState.vehicle_parts`)!
- `ItemDB.draw_item_icon(canvas, item_id, center, size, broken)` MUST draw crisp vector icons for ALL 18 base items + `"cat"`, `"dog"` + ALL specialty/vehicle items above!

### 2. Multi-Ring (`0–10 km`) Real-World OSM Categories (`OsmService` & `ExpeditionEngine`)
9 distinct scavenge target categories (`poi["category"]`), organized across 3 distance rings (`poi["ring"]`: `1` = `0..500m`, `2` = `500..3500m`, `3` = `3500m+`):
1. `"neighbor_house"` — Immediate Neighboring Houses (`50–450m`, Ring 1, `1 day`): balanced `soup`, `water`, `cards`, `padlock`, `flashlight`.
2. `"grocery"` — Supermarkets / Grocery / Bakeries (`Ring 1–3`, `1–4 days`): massive `soup` & `water` haul (`3–6` units!), high looter contestation (`risk_bandits = 0.45..0.60`), unlocks Trader Caravans!
3. `"doctor"` — Doctor's Offices / Urgent Care / Clinics / Hospitals (`Ring 1–3`, `1–4 days`): drops `antibiotics`, `medkit`, `antirad`, AND treats `-1 injury` / `-1 sickness` on the explorer on-site!
4. `"pharmacy"` — Pharmacies / Drugstores (`Ring 1–3`, `1–3 days`): drops `antirad`, `medkit`, `bug_spray`, calming tonics (`-1 sanity` stress).
5. `"fuel_auto"` — Gas Stations / Auto Repair / Parts (`Ring 1–3`, `1–4 days`): primary source of `fuel` jerrycans, missing `vehicle_part` (`battery`, `alternator`, `spark_plugs`, `radiator_hose`), and `scrap`!
6. `"hardware"` — Hardware Stores / Lumber / Supply (`Ring 1–3`, `2–4 days`): drops `scrap`, `toolbox`, `axe`, `padlock`, `rifle`, `ammo`, and backup `vehicle_part`!
7. `"civic"` — Police / Fire / EMS Stations (`Ring 1–3`, `2–4 days`): drops `rifle`, `ammo`, `gas_mask`, `radio`, and `+1` `"military"` rescue intel!
8. `"church"` — Churches / Places of Worship (`Ring 1–3`, `1–3 days`): peaceful low-bandit sanctuary, `water`, `medkit`, `+1` `"sanctuary"` rescue progress, AND `+10` family relationship harmony!
9. `"school"` — Schools / High Schools / Libraries (`Ring 1–3`, `1–3 days`): drops `book`, `map` (which cuts Ring 2/3 travel time by `-1 day`!), `checkers`, `cards`, `flashlight`.

### 3. Family Relationships (`RelationshipSystem`, `res://scripts/family/relationship_system.gd`, `class_name RelationshipSystem`)
Required static APIs:
- `static func apply_scavenge_trauma_or_relief() -> Array[String]` (called in `BunkerSim.start_bunker_run()`: if `GameState.left_behind_members` is non-empty, surviving members lose `-22` relationship with the Leader & gain `+1` sanity grief stress; if all family saved, `+12` bond across everyone & unlocks `"full_house"` achievement!)
- `static func evaluate_ration_fairness(ration_plan: Dictionary) -> Array[String]` (if a hungry/thirsty member gets `0` while a well-fed member gets rations, `-12` resentment; fair sharing during scarcity gives `+5` loyalty!)
- `static func tick_daily_relationships(rng: RandomNumberGenerator) -> Dictionary`
  Returns `{"lines": Array[String], "arguments": int, "bonds": int, "betrayal_member": String}`:
  - Triggers **Cooperation** (`>= +55` Devoted pairs soothe `-1` sanity, share warmth in cold, unlock `"unbreakable_bond"` achievement).
  - Triggers **Arguments** (`<= -35` Resentful pairs argue, spiking sanity or `20%` chance to knock/chip a supply or cause minor bruise).
  - Triggers **Emotional Breakdown** (`sanity >= 2` + avg relationship `<= -20` sets `breakdown_days = 2`, binge-eating `1` soup quarter or refusing expeditions).
  - Triggers **Betrayal** (`<= -75` Hostile adult/teen at `sanity >= 2` or `hunger >= 2` has `30%` chance to steal `4` soup_q + `4` water_q, set `alive = false` / `in_bunker = false` / `betrayed = true` / `death_reason = "Abandoned the shelter in bitter betrayal."`, and vanish into the wasteland!).
- `static func has_bonded_pair(min_score: int = 45) -> bool` (used by `EventDeck` for `[COOPERATE]` options!)
- `static func get_repair_cooperation_bonus() -> float`

### 4. True 3D Isometric Scavenge House (`ScavengeScene` + `House3DBuilder`)
- `ScavengeScene` (`extends Node2D` or `Control` wrapper hosting a full-screen `1280x720` `SubViewportContainer` -> `SubViewport` -> `Node3D` 3D Isometric World + `CanvasLayer` 2D CONELRAD HUD!)
- Keeps exact 2D floorplan coordinates `(x, y)` mapped directly to 3D `(x * SCALE_3D, 0.0, y * SCALE_3D)` so all verified `HouseGenerator` BFS walkability, collision radii, doorway widths, and `demo_mode` AI pathfinding work 100% identically in 3D space!
- Orthographic `Camera3D` at classic isometric angle (`rotation_degrees = Vector3(-48, 35, 0)`), cutaway front/south walls (`height = 0.55m` vs back walls `2.4m`) so items, doorways, and characters are NEVER hidden behind tall front walls!
