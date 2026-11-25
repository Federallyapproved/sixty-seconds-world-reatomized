extends Node

## Central GameState Autoload for "The End Is Near".
## Owns canonical state shared across Title, Family Creator, OSM House Picker,
## Global Nuke Selector, 60-Second Scavenge Sequence, Bunker Survival, and End Screen.

signal screen_requested(screen_name: String)
signal day_advanced(new_day: int)
signal inventory_changed()
signal family_changed()
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

# Demo / Automated QA Showcase flags
var demo_mode: bool = false
var headless_fast_test: bool = false
var autopilot_full_run: bool = false   # bots/probes: autopilot plays the full scavenge timer
var rng := RandomNumberGenerator.new()

# Family customization list (Array of Dictionaries)
var family_members: Array = []

# Selected OpenStreetMap house and discovered real-world neighborhood POIs
var selected_house: Dictionary = {}
var nearby_pois: Array = []
var current_neighborhood_label: String = "Capitol Hill, Seattle, WA"

# Real map geometry around the chosen house (from the same OSM payload as the POIs).
# roads: [{osm_id, name, kind, points_latlon: Array[Vector2(lon, lat)]}], parks: [{kind, name, polygon_latlon}]
var map_roads: Array = []
var map_parks: Array = []
var map_buildings: Array = []      # lightweight {osm_id, lat, lon, polygon_latlon, is_residential}
var map_bounds: Dictionary = {}    # {minlat, minlon, maxlat, maxlon} of the loaded data
var map_source: String = ""        # "preset:<id>" | "live" | "unmapped"
var place_names: Dictionary = {}   # {street, neighborhood, city, region, country, postcode}
var map_landmarks: Array = []      # verified named places beyond the map bbox: {name, lat, lon, source}
# Full records from the ~450 m live/preset fetch, kept so late-arriving wider-area results can
# rebuild the expedition targets after the house-select screen is gone.
var osm_local_buildings: Array = []
var osm_local_pois: Array = []
var osm_local_roads: Array = []
# Wider-area search (2.2 km, widened to 6 km when needed) run by ExtendedAreaFetcher.
var extended_pois: Array = []
var extended_roads: Array = []
var extended_status: String = ""
var extended_radius_m: int = 0
var _extended_fetcher: ExtendedAreaFetcher = null

# Difficulty: "normal" (60 s scavenge) or "hard" (30 s scavenge). Recon time is separate.
var difficulty: String = "normal"

# Global Nuke Detonation configuration & computed impact conditions
var nuke_config: Dictionary = {}

# Bunker Survival State
var day: int = 1
var soup_quarters: int = 0   # 4 quarters = 1 full soup can
var water_quarters: int = 0  # 4 quarters = 1 full water bottle
var ammo_count: int = 0
var medkit_count: int = 0
var bug_spray_count: int = 0
var padlock_active: bool = false

# Durable / Unique Bunker Gear: item_id -> {"owned": bool, "broken": bool, "count": int}
var bunker_items: Dictionary = {}

# Companions & Special States
var has_cat_sharikov: bool = false
var has_dog_pancake: bool = false
var bunker_structural_integrity: float = 100.0
var surface_radiation_sv: float = 4.5   # current outdoor dose rate at home in Sv/h (see RadiationModel)
var rad_hotspots: Array = []            # localized re-contamination: rain-out, dust, debris
var extra_strikes: Array = []           # later detonations with their own decay clocks
var shelter_dose_today_msv: float = 0.0
var bunker_temp_c: float = 20.0

# Finite loot: osm_id (as String) -> {"items": {item_id: count}, "initial_total": int, "raids": int}
var poi_inventories: Dictionary = {}
# Salvaged vehicle parts kept on the shelter's storage rack (fuel in litres)
var parts: Dictionary = {"car_battery": 0, "fuel_l": 0.0, "spark_plugs": 0, "fan_belt": 0, "tire_patch": 0}
# Items that just arrived from an expedition and still need to be shown going onto the shelves
var storage_arrivals: Array = []
# Family car state (see VehicleSystem); empty until the shelter run starts
var vehicle: Dictionary = {}

# Active Expedition State (at most 1 expedition out at a time, as in the classic game)
var active_expedition: Dictionary = {} # Empty when nobody is outside

# Rescue & Storyline Chains
var rescue_chains: Dictionary = {
	"military": 0,   # 0..3 -> 3 triggers Military Rescue Victory!
	"sanctuary": 0,  # 0..3 -> 3 triggers Real-World Church/Town Sanctuary Victory!
	"scientist": 0   # 0..3 -> 3 triggers Vault Scientist / Sharikov Victory!
}

# Daily Notebook Logs & Summary Outcome
var daily_log_entries: Array = []
var scavenge_stats: Dictionary = {}
var game_over: bool = false
var victory: bool = false
var ending_title: String = ""
var ending_description: String = ""

const DURABLE_GEAR_IDS := [
	"gas_mask", "radio", "flashlight", "map", "book",
	"axe", "rifle", "cards", "checkers", "suitcase",
	"harmonica", "toolbox"
]

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
		elif a.begins_with("--seed="):
			rng.seed = int(a.split("=")[1])
		elif a.begins_with("--difficulty="):
			difficulty = "hard" if a.split("=")[1] == "hard" else "normal"

## The wider-area store search lives here (under the autoload) so it survives screen changes.
func get_extended_fetcher() -> ExtendedAreaFetcher:
	if _extended_fetcher == null or not is_instance_valid(_extended_fetcher):
		_extended_fetcher = ExtendedAreaFetcher.new()
		_extended_fetcher.name = "ExtendedAreaFetcher"
		add_child(_extended_fetcher)
	return _extended_fetcher


func reset_to_defaults() -> void:
	day = 1
	game_over = false
	victory = false
	ending_title = ""
	ending_description = ""
	soup_quarters = 0
	water_quarters = 0
	ammo_count = 0
	medkit_count = 0
	bug_spray_count = 0
	padlock_active = false
	has_cat_sharikov = false
	has_dog_pancake = false
	bunker_structural_integrity = 100.0
	active_expedition = {}
	daily_log_entries = []
	scavenge_stats = {
		"items_collected": 0,
		"family_saved": 0,
		"leader_escaped": false,
		"time_remaining": 0.0
	}
	rescue_chains = {"military": 0, "sanctuary": 0, "scientist": 0}
	rad_hotspots = []
	extra_strikes = []
	shelter_dose_today_msv = 0.0
	poi_inventories = {}
	parts = {"car_battery": 0, "fuel_l": 0.0, "spark_plugs": 0, "fan_belt": 0, "tire_patch": 0}
	storage_arrivals = []
	vehicle = {}
	bunker_items = {}
	for gid in DURABLE_GEAR_IDS:
		bunker_items[gid] = {"owned": false, "broken": false, "count": 0}

	if family_members.is_empty():
		init_default_family()
	else:
		reset_family_runtime_status()

	if selected_house.is_empty():
		init_default_house()
	if nuke_config.is_empty():
		init_default_nuke()

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
		"scavenge_slots": slots,
		"in_bunker": false,
		"alive": true,
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
		"dose_msv": 0.0,
		"dose_recent_msv": 0.0,
		"dose_history": [],
		"is_mutant": false,
		"on_expedition": false,
		"days_away": 0,
		"status_note": "Healthy and alert."
	}

func reset_family_runtime_status() -> void:
	for m in family_members:
		var role_str: String = str(m.get("role", "adult"))
		var age_val: int = int(m.get("age", 30))
		m["scavenge_slots"] = 2 if (role_str == "child" or role_str == "teen" or age_val < 18) else 3
		m["in_bunker"] = false
		m["alive"] = true
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
		m["dose_msv"] = 0.0
		m["dose_recent_msv"] = 0.0
		m["dose_history"] = []
		m["is_mutant"] = false
		m["on_expedition"] = false
		m["days_away"] = 0
		m["status_note"] = "Ready for Civil Defense drill."

func init_default_house() -> void:
	# Real OSM building (Seattle preset): way 206082403, tags addr:housenumber=1002,
	# addr:street=East Republican Street, building=semidetached_house. Footprint in metres
	# relative to its centroid (x east, y south), derived from the bundled OSM data.
	selected_house = {
		"osm_id": 206082403,
		"osm_type": "way",
		"name": "1002 East Republican Street",
		"address": "1002 East Republican Street, Seattle",
		"short_address": "1002 East Republican Street",
		"housenumber": "1002",
		"street": "East Republican Street",
		"city": "Seattle",
		"postcode": "98102",
		"lat": 47.6232846,
		"lon": -122.3196813,
		"building_type": "semidetached_house",
		"is_residential": true,
		"area_sqm": 128.2,
		"footprint_meters": [
			Vector2(4.86, -5.61), Vector2(4.83, 6.61), Vector2(-4.89, 6.60), Vector2(-4.86, -5.49),
			Vector2(-3.26, -5.49), Vector2(-3.25, -7.05), Vector2(3.42, -7.03), Vector2(3.42, -5.61)
		],
		"estimated_rooms": 7,
		"source": "osm"
	}
	if place_names.is_empty():
		place_names = {"street": "East Republican Street", "housenumber": "1002", "postcode": "98102", "neighborhood": "Capitol Hill", "city": "Seattle", "region": "WA", "country": "USA"}

func init_default_nuke() -> void:
	nuke_config = {
		"target_name": "Elliott Bay waterfront, Seattle",
		"lat": 47.6030,
		"lon": -122.3390,
		"yield_kt": 800,
		"wind_bearing_deg": 32.8,   # plume heads from Elliott Bay toward the house (NNE)
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
		"padlock":
			padlock_active = true
		"car_battery", "spark_plugs", "fan_belt", "tire_patch":
			parts[item_id] = int(parts.get(item_id, 0)) + amount
		"fuel_can":
			parts["fuel_l"] = float(parts.get("fuel_l", 0.0)) + 10.0 * float(amount)
		_:
			if bunker_items.has(item_id):
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
		"padlock":
			return padlock_active
		"car_battery", "spark_plugs", "fan_belt", "tire_patch":
			return int(parts.get(item_id, 0)) > 0
		"fuel_can":
			return float(parts.get("fuel_l", 0.0)) >= 10.0
		_:
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

func request_screen(screen_name: String) -> void:
	current_screen = screen_name
	screen_requested.emit(screen_name)
