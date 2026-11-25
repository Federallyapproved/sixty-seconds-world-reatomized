class_name ShelterState
extends RefCounted

## Everything about one shelter run: the people, the shelf, the real places nearby and the
## clocks that make waiting cost something. Pure data plus small helpers; the rules live in
## ShelterSim / ShelterTrips / ShelterEvents / ShelterChains, which never touch the GameState
## autoload, so the same code runs in the game and in the 10,000-run balance harness.

const FOOD: String = "food"
const WATER: String = "water"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0
var difficulty: String = "normal"     # story | normal | hard
var threat: int = 0                   # Threat 1-10 (unlocks after the first rescue; M6)

var day: int = 1
var members: Array = []               # Dictionaries shared with GameState.family_members in the game
var stock: Dictionary = {}            # item_id -> working units (food/water: rations; ammo: rounds)
var broken: Dictionary = {}           # item_id -> broken units on the shelf
var wear: Dictionary = {}             # item_id -> wear points (the axe)
var pets: Dictionary = {}             # "dog"/"cat" -> {"name": String, "since": int}

var places: Array = []                # real places nearby (see ShelterTrips.make_place)
var trips: Array = []                 # expeditions in progress
var caches: Array = []                # {place_idx, items} revealed supply caches

# Clocks and pressure
var followed: bool = false
var followed_since: int = 0
var next_raid_day: int = 0
var raids_stopped_streak: int = 0
var gang_day: int = 0                 # day the gang tries to take the shelter
var gang_warned: bool = false
var loud_bonus: float = 0.0           # loud choices raise the next trip's followed chance
var fallout_clear_day: int = 12
var fallout_announced: bool = false
var fallout_known_day: int = 0
var h1_home_msv: float = 5000.0       # outdoor dose rate at home 1 h after the blast (mSv/h)
var temp_c: float = 19.0              # shelter air: blast heat near ground zero, nuclear winter far away
var winter: bool = false

# Rescue chains: chain_id -> {state, step, steps, next_day, misses, place_idx}
var chains: Dictionary = {}
var harmed_innocents: bool = false

# Events
var used_events: Dictionary = {}
var scheduled: Array = []             # [{event, day}]
var warnings: Dictionary = {}         # kind -> day issued
var bad_streak: int = 0
var flags: Dictionary = {}
var today_event: Dictionary = {}
var today_resolved: bool = true
var today_options: Array = []
var last_outcome: Dictionary = {}
var events_seen: int = 0

# Journal and receipts
var receipt: Array = []               # lines for the coming morning: {kind, text, items, who}
var journal: Array = []               # [{day, lines: Array}]
var ending: String = ""               # "" while the run goes on
var ending_kind: String = ""          # "win" | "loss" | "maybe"
var ending_day: int = 0

# Defaults the ration row starts from: member_id -> {"food": bool, "water": bool}
var last_rations: Dictionary = {}

# House Rules, the Almanac and the narrator's memory (M2)
var rules: Array = []                 # House Rules passed, in order
var next_meeting_day: int = 4         # the next family meeting about a House Rule
var known_items: Dictionary = {}      # items discovered in the Almanac (their options show greyed)
var hide_unknown: bool = false        # hide the options of items never discovered
var night: bool = false               # true while the night runs (its lines are read next morning)
var later: Array = []                 # [{day, kind, text, quiet_place}]: things the narrator brings up later
var lines_used: Dictionary = {}       # narration line ids already used this run (no line plays twice)
var start_count: int = 0              # people who made it into the shelter

# Crafting and salvage (M3, section 10)
var parts: Dictionary = {}            # part_id -> count on the part shelf (12 at most)
var chapters: Dictionary = {}         # manual chapter id -> "manual" | "pamphlet" (learned for the run)
var uses: Dictionary = {}             # makeshift item_id -> uses left on the one in use
var patched: Dictionary = {}          # item_id -> true: working on a Patch Job (one more use)
var patch_spent: Dictionary = {}      # item_id -> true: the patch gave out while the item was away
var dirty_water: int = 0              # rations of dirty water (a Bottle Filter makes them water)
var need_parts: Dictionary = {}       # part_id -> true: tagged with the Need toggle (loot it first)

# Measurements for the balance harness and the end-of-run screens
var stats: Dictionary = {}


func _init() -> void:
	stats = {
		"trips": 0, "trip_deaths": 0, "trips_by_member": {}, "deaths": [], "credits": {},
		"credits_makeshift": 0, "credits_total": 0, "mistakes": [], "raids": 0, "raids_stopped": 0,
		"rescue_day": 0, "events": 0, "item_options_used": 0, "missing_when_counted": {},
		"places_looted": {}, "followed_count": 0,
		# M2: what the end-of-run screens, the Almanac and the achievements read
		"meetings": 0, "rules_declined": 0, "afflictions": 0, "afflicted_max": 0, "afflicted_all": false,
		"selfish_meals": 0, "padlock_stops": 0, "cures": 0, "map_trips": 0, "heavy_clean": 0,
		"gang_shaken": 0, "takeover_stopped": false, "radio_all_clear": false, "repairs": 0,
		"thirsty_ever": false, "hungry_ever": false, "pharmacy_medkit": false, "stranger": "", "stranger_helped": false,
		"pets_adopted": [], "seen_items": {}, "credit_lines": {}, "item_option_labels": {},
		"stole": 0, "harmed": false, "occupied_left_alone": 0,
		# M3: crafting and salvage
		"crafted": {}, "craft_fails": 0, "taken_apart": 0, "parts_lost": 0, "studied": 0, "pamphlets": 0,
		"pamphlet_learned": 0, "makeshift_used": 0, "filtered": 0, "thefts": 0, "alarms": 0, "patches": 0,
		"dirty_collected": 0,
	}


# ---------------------------------------------------------------- people

func member(id: String) -> Dictionary:
	for m_v in members:
		var m: Dictionary = m_v
		if str(m.get("id", "")) == id:
			return m
	return {}


func living() -> Array:
	var res: Array = []
	for m_v in members:
		var m: Dictionary = m_v
		if bool(m.get("alive", false)) and str(m.get("loc", "")) != "outside":
			res.append(m)
	return res


## Alive and inside the shelter (not away on a trip).
func home() -> Array:
	var res: Array = []
	for m_v in members:
		var m: Dictionary = m_v
		if bool(m.get("alive", false)) and str(m.get("loc", "")) == "shelter":
			res.append(m)
	return res


func away() -> Array:
	var res: Array = []
	for m_v in members:
		var m: Dictionary = m_v
		if bool(m.get("alive", false)) and str(m.get("loc", "")) == "away":
			res.append(m)
	return res


static func is_child(m: Dictionary) -> bool:
	return str(m.get("role", "adult")) == "child" or int(m.get("age", 30)) < 13


func has_adult(group: Array) -> bool:
	for m_v in group:
		if not is_child(m_v as Dictionary):
			return true
	return false


func has_rule(rule_id: String) -> bool:
	return rules.has(rule_id)


## The affliction a survivor has now ("" for none): selfish, paranoid, reckless or withdrawn.
static func affliction(m: Dictionary) -> String:
	return str(m.get("affliction", ""))


# ---------------------------------------------------------------- the shelf

func count(item_id: String) -> int:
	return int(stock.get(item_id, 0))


func has(item_id: String) -> bool:
	return int(stock.get(item_id, 0)) > 0


func broken_count(item_id: String) -> int:
	return int(broken.get(item_id, 0))


## Owned at all (working or broken) — e.g. for "Needs: X" hints.
func owns(item_id: String) -> bool:
	return has(item_id) or broken_count(item_id) > 0


func add(item_id: String, n: int = 1) -> void:
	if n <= 0:
		return
	stock[item_id] = count(item_id) + n
	(stats["seen_items"] as Dictionary)[item_id] = true


## Removes up to n working units; returns how many were removed.
func remove(item_id: String, n: int = 1) -> int:
	var have: int = count(item_id)
	var k: int = mini(have, maxi(0, n))
	if k > 0:
		stock[item_id] = have - k
		if int(stock[item_id]) <= 0:
			stock.erase(item_id)
	return k


## One working unit becomes broken (kept on the shelf for repair or scrap).
func break_one(item_id: String) -> bool:
	if remove(item_id, 1) == 1:
		broken[item_id] = broken_count(item_id) + 1
		wear.erase(item_id)
		patched.erase(item_id)
		return true
	return false


func repair_one(item_id: String) -> bool:
	if broken_count(item_id) <= 0:
		return false
	broken[item_id] = broken_count(item_id) - 1
	if int(broken[item_id]) <= 0:
		broken.erase(item_id)
	add(item_id, 1)
	return true


func discard_broken(item_id: String) -> void:
	if broken_count(item_id) > 0:
		broken[item_id] = broken_count(item_id) - 1
		if int(broken[item_id]) <= 0:
			broken.erase(item_id)


func food() -> int:
	return count(FOOD)


func water() -> int:
	return count(WATER)


## Gains a number of whole items (food and water arrive as cans/bottles of 4 rations).
func add_units(item_id: String, n: int) -> void:
	if item_id == FOOD or item_id == WATER:
		add(item_id, n * int(ShelterData.item_effect(item_id, "rations", 4.0)))
	else:
		add(item_id, n)


## Loses whole items (food/water: cans of 4 rations, or what is left). Returns units lost.
func lose_units(item_id: String, n: int) -> int:
	if item_id == FOOD or item_id == WATER:
		var per: int = int(ShelterData.item_effect(item_id, "rations", 4.0))
		var lost_r: int = remove(item_id, n * per)
		return int(ceil(float(lost_r) / float(per)))
	return remove(item_id, n)


# ---------------------------------------------------------------- journal

func say(kind: String, text: String, item_ids: Array = [], who: String = "") -> void:
	receipt.append({"kind": kind, "text": text, "items": item_ids, "who": who, "day": day})


## Credits an item for doing its job ("Used: Axe → raid stopped") — feeds MVP Items and the
## crafted-credit check.
func credit(item_id: String, what: String) -> void:
	var c: Dictionary = stats["credits"]
	c[item_id] = int(c.get(item_id, 0)) + 1
	stats["credits_total"] = int(stats["credits_total"]) + 1
	# Crafted items, and gear running on a Patch Job, count toward the crafted-credit share (section 6).
	var makeshift: bool = str(ShelterData.item(item_id).get("category", "")) == "makeshift" or patched.has(item_id)
	if makeshift:
		stats["credits_makeshift"] = int(stats["credits_makeshift"]) + 1
		stats["makeshift_used"] = int(stats["makeshift_used"]) + 1
	# The Almanac lists what each item has been seen doing.
	var cl: Dictionary = stats["credit_lines"]
	if not cl.has(item_id):
		cl[item_id] = []
	var seen_lines: Array = cl[item_id]
	if not seen_lines.has(what) and seen_lines.size() < 12:
		seen_lines.append(what)
	say("used", "Used: %s → %s" % [ShelterData.item_name(item_id) + (" (patched)" if patched.has(item_id) else ""), what], [item_id])
	# A Patch Job is good for one more use: the item breaks again now (or when it comes home).
	if patched.has(item_id):
		patched.erase(item_id)
		if has(item_id):
			break_one(item_id)
		else:
			patch_spent[item_id] = true
		say("break", "The patch gave out: the %s is broken again." % ShelterData.item_name(item_id).to_lower(), [item_id])


## "No gas mask → Dolores got sick": what was missing when it counted.
func missed(item_id: String, what: String) -> void:
	var c: Dictionary = stats["missing_when_counted"]
	c[item_id] = int(c.get(item_id, 0)) + 1
	say("missing", "No %s → %s" % [ShelterData.item_name(item_id).to_lower(), what], [item_id])


func mistake(kind: String, detail: String) -> void:
	(stats["mistakes"] as Array).append({"day": day, "kind": kind, "detail": detail})


## Adds a link to a survivor's cause chain (for the death recap).
static func note_cause(m: Dictionary, day_n: int, text: String, root: String = "decision") -> void:
	if not m.has("causes"):
		m["causes"] = []
	(m["causes"] as Array).append({"day": day_n, "text": text, "root": root})
	if (m["causes"] as Array).size() > 12:
		(m["causes"] as Array).pop_front()


func is_over() -> bool:
	return ending != ""
