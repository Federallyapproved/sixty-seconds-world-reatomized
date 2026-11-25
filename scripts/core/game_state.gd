extends Node

## Central GameState autoload for The End Is Near.
## Owns what the screens share: the family, the chosen house and its real neighbourhood, the
## strike, the grab haul, and the shelter run (a ShelterState driven by ShelterSim). The shelter
## rules never read this autoload, so the balance harness can run them headless; the fields
## below marked "compatibility" mirror the run for the shelter artwork and older screens.

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

## Feature flags. The car escape and the radiation-mutation perk are kept in the code but switched
## off (section 4: modern setting; section 15: no jokes about radiation sickness).
const FEATURE_CAR_ESCAPE: bool = false
const FEATURE_MUTATION: bool = false

## Recon look-around and grab timer per difficulty (section 3).
const DIFFICULTY_TIMERS: Dictionary = {
	"story": {"recon": 20.0, "grab": 60.0},
	"normal": {"recon": 10.0, "grab": 60.0},
	"hard": {"recon": 3.0, "grab": 30.0},
}

var current_screen: String = SCREEN_TITLE

# Demo / automated QA flags
var demo_mode: bool = false
var headless_fast_test: bool = false
var autopilot_full_run: bool = false   # bots/probes: autopilot plays the full scavenge timer
var rng := RandomNumberGenerator.new()

# Family (Array of member Dictionaries; the shelter run uses these same dictionaries)
var family_members: Array = []

# Selected OpenStreetMap house and the real places around it
var selected_house: Dictionary = {}
var nearby_pois: Array = []
var current_neighborhood_label: String = "Capitol Hill, Seattle, WA"

# Real map geometry around the chosen house (from the same OSM payload as the POIs).
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

# Difficulty: "story" | "normal" | "hard" (section 6).
var difficulty: String = "normal"

# The strike and its computed conditions
var nuke_config: Dictionary = {}

# The 60-second grab: item_id -> whole items carried down the hatch.
var grab_haul: Dictionary = {}

# The shelter run (null until the hatch closes).
var shelter: ShelterState = null

# Radiation model state shared with RadiationModel (rain-out hotspots, later strikes)
var surface_radiation_sv: float = 4.5
var rad_hotspots: Array = []
var extra_strikes: Array = []
var shelter_dose_today_msv: float = 0.0
var bunker_temp_c: float = 20.0
var bunker_structural_integrity: float = 100.0

# Car escape (disabled feature; see FEATURE_CAR_ESCAPE)
var parts: Dictionary = {"car_battery": 0, "fuel_l": 0.0, "spark_plugs": 0, "fan_belt": 0, "tire_patch": 0}
var vehicle: Dictionary = {}

# Items that just came home from a trip and still need to go up on the rack (shown by the cinematic)
var storage_arrivals: Array = []

# Outcome
var scavenge_stats: Dictionary = {}
var game_over: bool = false
var victory: bool = false
var ending_title: String = ""
var ending_description: String = ""

var _day_pre_shelter: int = 1

const DURABLE_GEAR_IDS := [
	"gas_mask", "radio", "flashlight", "map", "manual", "axe", "rifle", "cards", "console", "suitcase",
]


# ---------------------------------------------------------------- compatibility mirrors

var day: int:
	get:
		return shelter.day if shelter != null else _day_pre_shelter
	set(v):
		if shelter != null:
			shelter.day = v
		else:
			_day_pre_shelter = v

## Rations of food / water on the shelf (the names predate canned food; 1 ration = 1 quarter can).
var soup_quarters: int:
	get:
		return shelter.food() if shelter != null else 4 * int(grab_haul.get("food", 0))
var water_quarters: int:
	get:
		return shelter.water() if shelter != null else 4 * int(grab_haul.get("water", 0))
var ammo_count: int:
	get:
		return _count("ammo")
var medkit_count: int:
	get:
		return _count("medkit")
var bug_spray_count: int:
	get:
		return _count("bug_spray")
var padlock_active: bool:
	get:
		return _count("padlock") > 0
var has_cat: bool:
	get:
		return shelter != null and shelter.pets.has("cat")
var has_dog: bool:
	get:
		return shelter != null and shelter.pets.has("dog")
## item_id -> {"owned": bool, "broken": bool, "count": int} for the shelf artwork.
var bunker_items: Dictionary:
	get:
		var d: Dictionary = {}
		for gid in DURABLE_GEAR_IDS:
			var n: int = _count(str(gid))
			var b: int = shelter.broken_count(str(gid)) if shelter != null else 0
			d[gid] = {"owned": n + b > 0, "broken": n == 0 and b > 0, "count": n + b, "checked_out": _checked_out(str(gid))}
		return d
## The first expedition in progress (the artwork shows one explorer's gear).
var active_expedition: Dictionary:
	get:
		if shelter == null or shelter.trips.is_empty():
			return {}
		var t: Dictionary = shelter.trips[0]
		var m: Dictionary = shelter.member(str(t["member"]))
		var p: Dictionary = shelter.places[int(t["place_idx"])]
		return {"member_id": str(t["member"]), "member_name": str(m.get("name", "")), "gear_ids": t["gear"],
			"target_name": ShelterTrips.place_label(p), "short_target_name": ShelterTrips.place_label(p),
			"days_remaining": maxi(0, int(t["due_day"]) - shelter.day), "category": str(p["category"])}
var rescue_chains: Dictionary:
	get:
		var d: Dictionary = {}
		if shelter != null:
			for cid in shelter.chains.keys():
				d[cid] = int((shelter.chains[cid] as Dictionary).get("step", 0)) - 1
		return d
var daily_log_entries: Array:
	get:
		var out: Array = []
		if shelter == null:
			return out
		for e_v in shelter.journal:
			var e: Dictionary = e_v
			var lines: Array[String] = []
			for l_v in e.get("lines", []):
				lines.append(str((l_v as Dictionary).get("text", "")))
			var title: String = "DAY %d" % int(e.get("day", 0))
			out.append({"day": int(e.get("day", 0)), "title": title, "lines": lines, "text": title + "\n" + "\n".join(lines)})
		return out


func _count(item_id: String) -> int:
	if shelter != null:
		return shelter.count(item_id)
	return int(grab_haul.get(item_id, 0))


func _checked_out(item_id: String) -> bool:
	if shelter == null:
		return false
	for t_v in shelter.trips:
		if ((t_v as Dictionary)["gear"] as Array).has(item_id):
			return true
	return false


# ---------------------------------------------------------------- lifecycle

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
			var d: String = a.split("=")[1]
			difficulty = d if DIFFICULTY_TIMERS.has(d) else "normal"


## The wider-area store search lives here (under the autoload) so it survives screen changes.
func get_extended_fetcher() -> ExtendedAreaFetcher:
	if _extended_fetcher == null or not is_instance_valid(_extended_fetcher):
		_extended_fetcher = ExtendedAreaFetcher.new()
		_extended_fetcher.name = "ExtendedAreaFetcher"
		add_child(_extended_fetcher)
	return _extended_fetcher


func recon_seconds() -> float:
	return float((DIFFICULTY_TIMERS.get(difficulty, DIFFICULTY_TIMERS["normal"]) as Dictionary)["recon"])


func grab_seconds() -> float:
	return float((DIFFICULTY_TIMERS.get(difficulty, DIFFICULTY_TIMERS["normal"]) as Dictionary)["grab"])


func reset_to_defaults() -> void:
	shelter = null
	_day_pre_shelter = 1
	game_over = false
	victory = false
	ending_title = ""
	ending_description = ""
	grab_haul = {}
	bunker_structural_integrity = 100.0
	scavenge_stats = {"items_collected": 0, "family_saved": 0, "leader_escaped": false, "time_remaining": 0.0}
	rad_hotspots = []
	extra_strikes = []
	shelter_dose_today_msv = 0.0
	parts = {"car_battery": 0, "fuel_l": 0.0, "spark_plugs": 0, "fan_belt": 0, "tire_patch": 0}
	storage_arrivals = []
	vehicle = {}
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
		make_family_member("member_0", "Sam", "adult", 42, true, "handy", 1, 1, "#4a2e1b", "#2f5d8a", true, 1, "#3d5a80", 0),
		make_family_member("member_1", "Priya", "adult", 39, false, "optimist", 3, 3, "#1c1410", "#3a7d5c", false, 0, "#8a5a44", 2),
		make_family_member("member_2", "Maya", "teen", 16, false, "bookworm", 3, 2, "#2a1c14", "#4c6a92", true, 0, "#6b4c9a", 1),
		make_family_member("member_3", "Leo", "child", 9, false, "scout", 1, 5, "#8c5a2b", "#2f5d8a", false, 0, "#d99b26", 3)
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
		"id": id_str, "name": p_name, "role": role, "age": age, "is_leader": is_leader, "trait": trait_id,
		"skin_tone": skin_tone, "hair_style": hair_style, "hair_color": hair_color, "eye_color": eye_color,
		"glasses": glasses, "facial_hair": facial_hair, "outfit_color": outfit_color, "shirt_style": shirt_style,
		"scavenge_slots": slots, "in_bunker": false, "alive": true, "death_reason": "",
		"hunger": 0, "thirst": 0, "sanity": 0, "sickness": 0, "injury": 0, "fatigue": 0,
		"radiation": 0.0, "dose_msv": 0.0, "dose_recent_msv": 0.0, "dose_history": [], "is_mutant": false,
		"on_expedition": false, "days_away": 0, "status_note": "OK",
	}


func reset_family_runtime_status() -> void:
	for m in family_members:
		var role_str: String = str(m.get("role", "adult"))
		var age_val: int = int(m.get("age", 30))
		m["scavenge_slots"] = 2 if (role_str == "child" or role_str == "teen" or age_val < 18) else 3
		for k in ["in_bunker", "on_expedition", "is_mutant"]:
			m[k] = false
		m["alive"] = true
		m["death_reason"] = ""
		for k in ["hunger", "thirst", "sanity", "sickness", "injury", "fatigue", "days_away"]:
			m[k] = 0
		m["radiation"] = 0.0
		m["dose_msv"] = 0.0
		m["dose_recent_msv"] = 0.0
		m["dose_history"] = []
		m["status_note"] = "OK"
		for k in ["loc", "dwf", "dww", "sick", "injured", "causes", "morale"]:
			m.erase(k)


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
		"scout_seconds": 10.0
	}
	surface_radiation_sv = float(nuke_config["initial_sv_hr"])
	bunker_temp_c = float(nuke_config["bunker_temp_c"])


# ---------------------------------------------------------------- the shelf

## The grab (and, later, anything that hands the family a whole item) lands here.
func add_scavenged_item(item_id: String, amount: int = 1) -> void:
	var iid: String = ItemDB._normalize_id(item_id)
	if iid in ["car_battery", "spark_plugs", "fan_belt", "tire_patch"]:
		parts[iid] = int(parts.get(iid, 0)) + amount
	elif iid == "fuel_can":
		parts["fuel_l"] = float(parts.get("fuel_l", 0.0)) + 10.0 * float(amount)
	elif shelter != null:
		shelter.add_units(iid, amount)
	else:
		grab_haul[iid] = int(grab_haul.get(iid, 0)) + amount
	inventory_changed.emit()


func has_working_item(item_id: String) -> bool:
	var iid: String = ItemDB._normalize_id(item_id)
	if iid == "food" or iid == "water":
		return soup_quarters > 0 if iid == "food" else water_quarters > 0
	if iid in ["car_battery", "spark_plugs", "fan_belt", "tire_patch"]:
		return int(parts.get(iid, 0)) > 0
	if iid == "fuel_can":
		return float(parts.get("fuel_l", 0.0)) >= 10.0
	return _count(iid) > 0


func break_or_consume_item(item_id: String) -> void:
	if shelter != null:
		if item_id in ["medkit", "bug_spray", "ammo", "padlock"]:
			shelter.remove(item_id, 1)
		else:
			shelter.break_one(item_id)
	inventory_changed.emit()


func repair_item(item_id: String) -> void:
	if shelter != null and shelter.repair_one(item_id):
		inventory_changed.emit()


## Alive, sheltered and not away.
func get_living_bunker_members() -> Array:
	if shelter != null:
		return shelter.home()
	var res: Array = []
	for m in family_members:
		if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)) and not bool(m.get("on_expedition", false)):
			res.append(m)
	return res


## Alive and part of the household (sheltered or away on a trip).
func get_all_living_members() -> Array:
	if shelter != null:
		return shelter.living()
	var res: Array = []
	for m in family_members:
		if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)):
			res.append(m)
	return res


## "3 cans + 2 rations" style text for the shelf labels.
func format_quarters_as_cans(quarters: int) -> String:
	var whole: int = quarters / 4
	var rem: int = quarters % 4
	if rem == 0:
		return "%d" % whole
	return "%d + %d/4" % [whole, rem]


func request_screen(screen_name: String) -> void:
	current_screen = screen_name
	screen_requested.emit(screen_name)
