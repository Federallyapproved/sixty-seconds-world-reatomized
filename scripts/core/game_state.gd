extends Node

## Central GameState Autoload for "60 Seconds: World Reatomized" (V2 Autonomous Overhaul).
## Preserves 100% compatibility with V1 APIs while adding:
## - Difficulty Levels ("little_boy", "fat_man", "tsar_bomba")
## - Game Modes ("full_protocol", "scavenge_drill", "survival_only", "challenge") & Challenges
## - Pairwise Family Relationships (-100..+100), Arguments, Bonding, Breakdowns & Betrayal
## - Multi-Ring (0-10km) Real-World OSM Landmarks (Grocery, Doctor's Office, Pharmacy, Gas/Auto, etc.)
## - Specialty Supplies (Antibiotics, Anti-Rad Pills, Scrap) & Multi-Run Vehicle Escape System
## - Persistent Story Flags, Left-Behind Consequences, Achievements & Unlockable Hats

signal screen_requested(screen_name: String)
signal day_advanced(new_day: int)
signal inventory_changed()
signal family_changed()
signal relationships_changed()
signal achievement_unlocked(ach_id: String, ach_title: String)
signal osm_house_selected(house_data: Dictionary)
signal nuke_configured(nuke_data: Dictionary)

const SCREEN_TITLE := "title"
const SCREEN_FAMILY := "family"
const SCREEN_OSM_HOUSE := "osm_house"
const SCREEN_NUKE := "nuke"
const SCREEN_SCAVENGE := "scavenge"
const SCREEN_BUNKER := "bunker"
const SCREEN_SUMMARY := "summary"

var current_screen: String = SCREEN_TITLE

# Difficulty & Game Mode
var difficulty: String = "fat_man"       # "little_boy" | "fat_man" | "tsar_bomba"
var game_mode: String = "full_protocol"  # "full_protocol" | "scavenge_drill" | "survival_only" | "challenge"
var active_challenge_id: String = ""     # "" | "cul_de_sac_odyssey" | "nuclear_winter_zero" | "lone_wolf_pets"

# Demo / Automated QA Showcase flags
var demo_mode: bool = false
var promo_video_mode: bool = false
var headless_fast_test: bool = false
var rng := RandomNumberGenerator.new()

# Family customization list (Array of Dictionaries)
var family_members: Array = []

# Pairwise Relationship Matrix: "idA|idB" -> int (-100..100)
var relationships: Dictionary = {}
var recent_relationship_events: Array = []

# Selected OpenStreetMap house and Multi-Ring real-world neighborhood POIs
var selected_house: Dictionary = {}
var nearby_pois: Array = []
var neighborhood_modifiers: Dictionary = {}
var current_neighborhood_label: String = "Capitol Hill, Seattle, WA"

# Global Nuke Detonation configuration & computed impact conditions
var nuke_config: Dictionary = {}

# Bunker Survival State
var day: int = 1
var soup_quarters: int = 0   # 4 quarters = 1 full soup can
var water_quarters: int = 0  # 4 quarters = 1 full water bottle
var ammo_count: int = 0
var medkit_count: int = 0
var bug_spray_count: int = 0
var antibiotics_count: int = 0  # Doctor's Office / Urgent Care specialty cure
var antirad_count: int = 0      # Pharmacy / Hospital radiation purge (-35 rads)
var scrap_count: int = 0        # Hardware / Auto Shop repair & fortification resource
var padlock_active: bool = false

# Multi-Run & In-Run Wasteland Vehicle Escape System
var fuel_cans: int = 0
var fuel_needed: int = 3
var vehicle_parts: Dictionary = {
	"battery": false,
	"alternator": false,
	"spark_plugs": false,
	"radiator_hose": false
}
var vehicle_tuned: bool = false

# Durable / Unique Bunker Gear: item_id -> {"owned": bool, "broken": bool, "count": int, "checked_out": bool}
var bunker_items: Dictionary = {}

# Companions, Deterioration & Special States
var has_cat_sharikov: bool = false
var has_dog_pancake: bool = false
var roach_infestation: int = 0  # 0..3 visual & sanitary deterioration
var bunker_structural_integrity: float = 100.0
var surface_radiation_sv: float = 4.5
var bunker_temp_c: float = 20.0

# Consequences from 60s Scavenge & Chained Narrative Flags
var left_behind_members: Array = []
var story_flags: Dictionary = {}

# Active Expedition State (at most 1 expedition out at a time)
var active_expedition: Dictionary = {}

# Rescue & Escape Routes (5 Victory Paths: Military, Sanctuary, Scientist, Raider Convoy, + Vehicle Escape!)
var rescue_chains: Dictionary = {
	"military": 0,     # 0..3 -> U.S. Civil Defense Extraction
	"sanctuary": 0,    # 0..3 -> Real-World OSM Church/Parish Settlement
	"scientist": 0,    # 0..3 -> Vault Institute & Sharikov Extraction
	"raider_pact": 0   # 0..3 -> Wasteland Convoy / Smuggler Highway Alliance
}

# Daily Notebook Logs & Summary Outcome
var daily_log_entries: Array = []
var scavenge_stats: Dictionary = {}
var run_metrics: Dictionary = {}
var game_over: bool = false
var victory: bool = false
var ending_route: String = ""
var ending_title: String = ""
var ending_description: String = ""

const DURABLE_GEAR_IDS := [
	"gas_mask", "radio", "flashlight", "map", "book",
	"axe", "rifle", "cards", "checkers", "suitcase",
	"harmonica", "toolbox"
]

const VEHICLE_PART_IDS := ["battery", "alternator", "spark_plugs", "radiator_hose"]

func _ready() -> void:
	rng.randomize()
	_parse_cli_args()
	reset_to_defaults()

func _parse_cli_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in args:
		if a == "--demo-showcase":
			demo_mode = true
			rng.seed = 60602026
		elif a == "--promo-video":
			demo_mode = true
			promo_video_mode = true
			rng.seed = 60602026
		elif a.begins_with("--seed="):
			rng.seed = int(a.split("=")[1])

func get_difficulty_config() -> Dictionary:
	match difficulty:
		"little_boy":
			return {
				"id": "little_boy",
				"label": "LITTLE BOY (CASUAL)",
				"scavenge_seconds": 70.0,
				"scout_bonus_sec": 4.0,
				"spawn_soup_bonus": 2,
				"spawn_water_bonus": 2,
				"raider_mult": 0.70,
				"radiation_mult": 0.75,
				"ration_grace": 1
			}
		"tsar_bomba":
			return {
				"id": "tsar_bomba",
				"label": "TSAR BOMBA (APOCALYPSE)",
				"scavenge_seconds": 60.0,
				"scout_bonus_sec": -3.0,
				"spawn_soup_bonus": -2,
				"spawn_water_bonus": -2,
				"raider_mult": 1.35,
				"radiation_mult": 1.30,
				"ration_grace": 0
			}
		_:
			return {
				"id": "fat_man",
				"label": "FAT MAN (REATOMIZED)",
				"scavenge_seconds": 60.0,
				"scout_bonus_sec": 0.0,
				"spawn_soup_bonus": 0,
				"spawn_water_bonus": 0,
				"raider_mult": 1.0,
				"radiation_mult": 1.0,
				"ration_grace": 0
			}

func reset_to_defaults() -> void:
	day = 1
	game_over = false
	victory = false
	ending_route = ""
	ending_title = ""
	ending_description = ""
	soup_quarters = 0
	water_quarters = 0
	ammo_count = 0
	medkit_count = 0
	bug_spray_count = 0
	antibiotics_count = 0
	antirad_count = 0
	scrap_count = 0
	padlock_active = false
	has_cat_sharikov = false
	has_dog_pancake = false
	roach_infestation = 0
	bunker_structural_integrity = 100.0
	active_expedition = {}
	left_behind_members = []
	story_flags = {}
	recent_relationship_events = []
	daily_log_entries = []
	scavenge_stats = {
		"items_collected": 0,
		"family_saved": 0,
		"leader_escaped": false,
		"time_remaining": 0.0
	}
	run_metrics = {
		"expeditions_completed": 0,
		"distant_landmarks_looted": 0,
		"arguments_had": 0,
		"bonds_formed": 0,
		"events_resolved": 0,
		"vehicle_parts_scavenged": 0
	}
	rescue_chains = {"military": 0, "sanctuary": 0, "scientist": 0, "raider_pact": 0}
	bunker_items = {}
	for gid in DURABLE_GEAR_IDS:
		bunker_items[gid] = {"owned": false, "broken": false, "count": 0, "checked_out": false}

	_init_vehicle_from_meta_tier()

	if family_members.is_empty():
		init_default_family()
	else:
		reset_family_runtime_status()

	init_relationships(20)

	if selected_house.is_empty():
		init_default_house()
	if nuke_config.is_empty():
		init_default_nuke()

func _init_vehicle_from_meta_tier() -> void:
	var tier: int = 0
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		if sm.has_method("get_vehicle_chassis_tier"):
			tier = int(sm.call("get_vehicle_chassis_tier"))
	fuel_cans = 1 if tier >= 3 else 0
	fuel_needed = 4 if tier >= 3 else 5
	if tier >= 2:
		scrap_count = maxi(scrap_count, 1)
	vehicle_tuned = false
	vehicle_parts = {
		"battery": tier >= 1,
		"radiator_hose": tier >= 2,
		"alternator": false,
		"spark_plugs": false
	}

func init_default_family() -> void:
	family_members = [
		make_family_member("member_0", "Ted", "adult", 42, true, "handy", 1, 1, "#4a2e1b", "#2f5d8a", true, 1, "#c84b31", 0),
		make_family_member("member_1", "Dolores", "adult", 39, false, "optimist", 1, 3, "#d8a438", "#3a7d5c", false, 0, "#3d7a8a", 2),
		make_family_member("member_2", "Mary Jane", "teen", 16, false, "bookworm", 1, 2, "#8c3b2b", "#4c6a92", true, 0, "#7b4b94", 1),
		make_family_member("member_3", "Timmy", "child", 9, false, "scout", 1, 5, "#e0822b", "#2f5d8a", false, 0, "#d99b26", 3)
	]

func make_family_member(
	id_str: String,
	p_name: String,
	role: String,
	age: int,
	is_leader: bool,
	trait_id: String,
	skin_tone: int,
	hair_style: int,
	hair_color: String,
	eye_color: String,
	glasses: bool,
	facial_hair: int,
	outfit_color: String,
	shirt_style: int
) -> Dictionary:
	var slots: int = 2 if (role == "child" or role == "teen" or age < 18) else 3
	return {
		"id": id_str,
		"name": p_name,
		"role": role,
		"age": age,
		"is_leader": is_leader,
		"trait": trait_id,
		"skin_tone": skin_tone,
		"hair_style": hair_style,
		"hair_color": hair_color,
		"eye_color": eye_color,
		"glasses": glasses,
		"facial_hair": facial_hair,
		"outfit_color": outfit_color,
		"shirt_style": shirt_style,
		"hat_id": "none",
		"scavenge_slots": slots,
		"in_bunker": false,
		"alive": true,
		"betrayed": false,
		"death_reason": "",
		"days_without_water": 0,
		"days_without_food": 0,
		"hunger": 0,
		"thirst": 0,
		"sanity": 0,
		"sickness": 0,
		"injury": 0,
		"fatigue": 0,
		"radiation": 0.0,
		"is_mutant": false,
		"on_expedition": false,
		"days_away": 0,
		"soot_days": 0,
		"expedition_scars": 0,
		"breakdown_days": 0,
		"last_bubble": "",
		"status_note": "Healthy and alert."
	}

func reset_family_runtime_status() -> void:
	for m in family_members:
		var role_str: String = str(m.get("role", "adult"))
		var age_val: int = int(m.get("age", 30))
		var default_slots: int = 2 if (role_str == "child" or role_str == "teen" or age_val < 18) else 3
		if game_mode == "challenge" and active_challenge_id == "lone_wolf_pets" and bool(m.get("is_leader", false)):
			m["scavenge_slots"] = 4
		else:
			m["scavenge_slots"] = default_slots
		m["in_bunker"] = false
		m["alive"] = true
		m["betrayed"] = false
		m["death_reason"] = ""
		m["days_without_water"] = 0
		m["days_without_food"] = 0
		m["hunger"] = 0
		m["thirst"] = 0
		m["sanity"] = 0
		m["sickness"] = 0
		m["injury"] = 0
		m["fatigue"] = 0
		m["radiation"] = 0.0
		m["is_mutant"] = false
		m["on_expedition"] = false
		m["days_away"] = 0
		m["soot_days"] = 0
		m["expedition_scars"] = 0
		m["breakdown_days"] = 0
		m["last_bubble"] = ""
		m["status_note"] = "Ready for Civil Defense drill."

# --- Pairwise Family Relationship Helpers ---

static func make_rel_key(id_a: String, id_b: String) -> String:
	return (id_a + "|" + id_b) if id_a < id_b else (id_b + "|" + id_a)

func init_relationships(base_score: int = 20) -> void:
	relationships = {}
	for i in range(family_members.size()):
		for j in range(i + 1, family_members.size()):
			var ida: String = str(family_members[i].get("id", ""))
			var idb: String = str(family_members[j].get("id", ""))
			if ida != "" and idb != "":
				relationships[make_rel_key(ida, idb)] = clampi(base_score, -100, 100)

func get_relationship(id_a: String, id_b: String) -> int:
	if id_a == id_b or id_a == "" or id_b == "":
		return 0
	var k: String = make_rel_key(id_a, id_b)
	return int(relationships.get(k, 15))

func change_relationship(id_a: String, id_b: String, delta: int) -> int:
	if id_a == id_b or id_a == "" or id_b == "":
		return 0
	var k: String = make_rel_key(id_a, id_b)
	var cur: int = int(relationships.get(k, 15))
	var nxt: int = clampi(cur + delta, -100, 100)
	relationships[k] = nxt
	relationships_changed.emit()
	return nxt

func change_member_relationships_with_all(member_id: String, delta: int, only_bunker: bool = true) -> void:
	for m in family_members:
		var oid: String = str(m.get("id", ""))
		if oid == "" or oid == member_id:
			continue
		if only_bunker and (not bool(m.get("alive", false)) or not bool(m.get("in_bunker", false))):
			continue
		change_relationship(member_id, oid, delta)

func get_member_avg_relationship(member_id: String) -> int:
	var sum_v: int = 0
	var cnt: int = 0
	for m in family_members:
		var oid: String = str(m.get("id", ""))
		if oid == "" or oid == member_id or not bool(m.get("alive", false)) or not bool(m.get("in_bunker", false)):
			continue
		sum_v += get_relationship(member_id, oid)
		cnt += 1
	return int(round(float(sum_v) / float(cnt))) if cnt > 0 else 0

static func get_relationship_tier(score: int) -> String:
	if score >= 55:
		return "Devoted"
	elif score >= 20:
		return "Loyal"
	elif score >= -19:
		return "Neutral"
	elif score >= -49:
		return "Resentful"
	return "Hostile"

# --- Multi-Run & In-Run Vehicle Escape Helpers ---

func get_vehicle_parts_owned_count() -> int:
	var c: int = 0
	for k in VEHICLE_PART_IDS:
		if bool(vehicle_parts.get(k, false)):
			c += 1
	return c

func add_next_missing_vehicle_part() -> String:
	for k in VEHICLE_PART_IDS:
		if not bool(vehicle_parts.get(k, false)):
			vehicle_parts[k] = true
			run_metrics["vehicle_parts_scavenged"] = int(run_metrics.get("vehicle_parts_scavenged", 0)) + 1
			inventory_changed.emit()
			return k
	return ""

func has_vehicle_tuning_capability() -> bool:
	if has_working_item("toolbox") or has_working_item("book"):
		return true
	for m in get_living_bunker_members():
		if str(m.get("trait", "")) == "handy":
			return true
	return false

func can_escape_by_vehicle() -> bool:
	if get_vehicle_parts_owned_count() < 4:
		return false
	if fuel_cans < fuel_needed:
		return false
	return vehicle_tuned

# --- Default House & Nuke ---

func init_default_house() -> void:
	selected_house = {
		"osm_id": 240109182,
		"name": "518 E Roy St Residence",
		"address": "518 E Roy St, Capitol Hill, Seattle, WA",
		"lat": 47.6242,
		"lon": -122.3195,
		"building_type": "house",
		"area_sqm": 182.0,
		"footprint_meters": [
			Vector2(-7.2, -6.0),
			Vector2(7.2, -6.0),
			Vector2(7.2, 1.5),
			Vector2(3.5, 1.5),
			Vector2(3.5, 6.2),
			Vector2(-7.2, 6.2)
		],
		"estimated_rooms": 6
	}

func init_default_nuke() -> void:
	nuke_config = {
		"target_name": "Elliott Bay Strategic Port, Seattle",
		"lat": 47.6030,
		"lon": -122.3390,
		"yield_kt": 800,
		"wind_bearing_deg": 225.0,
		"distance_km": 2.78,
		"zone": "ground_zero_edge",
		"initial_sv_hr": 7.4,
		"bunker_temp_c": 28.5,
		"tremor_intensity": 0.85,
		"structural_damage": 0.35,
		"raider_aggression": 0.65,
		"fallout_days": 14,
		"scavenge_seconds": 60.0,
		"scout_seconds": 8.0
	}
	surface_radiation_sv = float(nuke_config["initial_sv_hr"])
	bunker_temp_c = float(nuke_config["bunker_temp_c"])

# --- Inventory Helpers ---

func add_scavenged_item(item_id: String, amount: int = 1) -> void:
	match item_id:
		"soup":
			soup_quarters += 4 * amount
		"water":
			water_quarters += 4 * amount
		"ammo":
			ammo_count += 2 * amount
		"medkit":
			medkit_count += amount
		"bug_spray":
			bug_spray_count += amount
		"antibiotics":
			antibiotics_count += amount
		"antirad":
			antirad_count += amount
		"scrap":
			scrap_count += amount
		"fuel":
			fuel_cans += amount
		"vehicle_part":
			for _i in range(amount):
				add_next_missing_vehicle_part()
		"padlock":
			padlock_active = true
		_:
			if VEHICLE_PART_IDS.has(item_id):
				if not bool(vehicle_parts.get(item_id, false)):
					run_metrics["vehicle_parts_scavenged"] = int(run_metrics.get("vehicle_parts_scavenged", 0)) + 1
				vehicle_parts[item_id] = true
			elif bunker_items.has(item_id):
				bunker_items[item_id]["owned"] = true
				bunker_items[item_id]["broken"] = false
				bunker_items[item_id]["count"] = int(bunker_items[item_id].get("count", 0)) + amount
	inventory_changed.emit()

func has_working_item(item_id: String) -> bool:
	match item_id:
		"soup":
			return soup_quarters > 0
		"water":
			return water_quarters > 0
		"ammo":
			return ammo_count > 0
		"medkit":
			return medkit_count > 0
		"bug_spray":
			return bug_spray_count > 0
		"antibiotics":
			return antibiotics_count > 0
		"antirad":
			return antirad_count > 0
		"scrap":
			return scrap_count > 0
		"fuel":
			return fuel_cans > 0
		"padlock":
			return padlock_active
		_:
			if VEHICLE_PART_IDS.has(item_id):
				return bool(vehicle_parts.get(item_id, false))
			if bunker_items.has(item_id):
				var entry: Dictionary = bunker_items[item_id]
				return bool(entry.get("owned", false)) and not bool(entry.get("broken", false))
	return false

func break_or_consume_item(item_id: String) -> void:
	match item_id:
		"medkit":
			medkit_count = maxi(0, medkit_count - 1)
		"bug_spray":
			bug_spray_count = maxi(0, bug_spray_count - 1)
		"antibiotics":
			antibiotics_count = maxi(0, antibiotics_count - 1)
		"antirad":
			antirad_count = maxi(0, antirad_count - 1)
		"scrap":
			scrap_count = maxi(0, scrap_count - 1)
		"fuel":
			fuel_cans = maxi(0, fuel_cans - 1)
		"ammo":
			ammo_count = maxi(0, ammo_count - 1)
		"padlock":
			padlock_active = false
		_:
			if bunker_items.has(item_id):
				bunker_items[item_id]["broken"] = true
	inventory_changed.emit()

func repair_item(item_id: String) -> void:
	if bunker_items.has(item_id) and bool(bunker_items[item_id].get("owned", false)):
		bunker_items[item_id]["broken"] = false
		inventory_changed.emit()

func get_living_bunker_members() -> Array:
	var res: Array = []
	for m in family_members:
		if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)) and not bool(m.get("on_expedition", false)):
			res.append(m)
	return res

func get_all_living_members() -> Array:
	var res: Array = []
	for m in family_members:
		if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)):
			res.append(m)
	return res

func format_quarters_as_cans(quarters: int) -> String:
	var whole: int = quarters / 4
	var rem: int = quarters % 4
	if rem == 0:
		return "%d" % whole
	return "%d + %d/4" % [whole, rem]

func unlock_achievement(ach_id: String) -> void:
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		if sm.has_method("unlock_achievement"):
			sm.call("unlock_achievement", ach_id)

func request_screen(screen_name: String) -> void:
	current_screen = screen_name
	screen_requested.emit(screen_name)
