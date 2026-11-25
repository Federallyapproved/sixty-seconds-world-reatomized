extends Node

## Achievements (section 14): every achievement in data/achievements.csv has a test here that
## earns it through the game's own calls (a decision, not a lucky drop), and a fresh run earns none.
## godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m2/achievements_suite.gd

var _passes: int = 0
var _fails: Array[String] = []


func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] ", label)
	else:
		_fails.append(label)
		print("[FAIL] ", label)


func _places(far: bool = false) -> Array:
	var k: float = 7000.0 if far else 1.0
	return [
		{"osm_id": 11, "name": "Corner Market", "category": "grocery", "walk_m": 300.0 * k, "lat": 0.0, "lon": 0.0},
		{"osm_id": 12, "name": "Main Pharmacy", "category": "pharmacy", "walk_m": 400.0 * k, "lat": 0.0, "lon": 0.0},
		{"osm_id": 13, "name": "Town Church", "category": "church", "walk_m": 500.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 14, "name": "", "category": "neighbor_house", "street": "Elm Street", "walk_m": 40.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 15, "name": "Lincoln School", "category": "school", "walk_m": 600.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 16, "name": "Lumber Yard", "category": "hardware", "walk_m": 700.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 17, "name": "Station 4", "category": "civic", "walk_m": 800.0, "lat": 0.0, "lon": 0.0},
	]


func _run(haul: Dictionary = {}, seed_v: int = 1, diff: String = "normal", far: bool = false) -> ShelterState:
	return ShelterSim.new_run({"members": SimPolicies.default_family(), "haul": haul, "places": _places(far),
		"rad_factors": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05], "h1_home_msv": 11500.0, "difficulty": diff, "seed": seed_v})


func _feed(s: ShelterState) -> Dictionary:
	var r: Dictionary = {}
	for m_v in s.home():
		r[str((m_v as Dictionary)["id"])] = {"food": true, "water": true}
	return {"rations": r, "treat": {}, "jobs": {}}


func _quiet_day(s: ShelterState, plan: Dictionary = {}) -> void:
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	ShelterSim.end_day(s, plan if not plan.is_empty() else _feed(s))


func _trip(s: ShelterState, mid: String, place: int, gear: Array) -> void:
	var m: Dictionary = s.member(mid)
	m["loc"] = "shelter"
	m["tired_until"] = 0
	m["sick"] = false
	m["injured"] = false
	for g in gear:
		if not s.has(str(g)):
			s.add(str(g), 1)
	if ShelterTrips.launch(s, m, place, gear) != "":
		return
	for t_v in s.trips:
		(t_v as Dictionary)["p_day"] = 0.0
	var guard: int = 0
	while str(m.get("loc", "")) == "away" and guard < 12:
		ShelterTrips.tick(s)
		s.day += 1
		guard += 1


func _meeting(s: ShelterState, pick: String) -> void:
	var ev: Dictionary = ShelterEvents.meeting_event(s)
	s.today_event = ev
	s.today_resolved = false
	s.today_options = ShelterEvents.options_for(s, ev)
	ShelterSim.choose(s, pick)


func _event(s: ShelterState, eid: String, oid: String) -> void:
	var ev: Dictionary = ShelterEvents._prepare(s, ShelterData.event(eid))
	s.today_event = ev
	s.today_resolved = false
	s.today_options = ShelterEvents.options_for(s, ev)
	ShelterSim.choose(s, oid)


## Each returns [ShelterState or null, ctx, meta].
func _setups() -> Dictionary:
	return {
		"item_whisperer": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10, "rifle": 1, "ammo": 20})
			for _i in range(10):
				_event(s, "signature_required", "shoot")
			return [s, {}, Almanac.blank()],
		"pharmacist": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			(s.places[1] as Dictionary)["stock"] = {"medkit": 3}
			_trip(s, "m1", 1, ["axe"])
			return [s, {}, Almanac.blank()],
		"local_tourist": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			for i in [0, 1, 2, 4, 5, 6]:
				(s.places[i] as Dictionary)["stock"] = {"water": 2}
				_trip(s, "m1", i, ["axe"])
			var meta: Dictionary = Almanac.blank()
			Almanac.record_run(meta, s, {})
			return [s, {}, meta],
		"hometown_hero": func() -> Array:
			var meta: Dictionary = Almanac.blank()
			var last: ShelterState = null
			for k in ["osm:1", "osm:2", "osm:3"]:
				last = _run({"food": 10, "water": 10})
				ShelterSim.finish(last, "rescue_convoy")
				Almanac.record_run(meta, last, {"address_key": k})
			return [last, {}, meta],
		"boiled_frog": func() -> Array:
			var s: ShelterState = _run({"food": 40, "water": 40})
			s.pets["dog"] = {"since": 1}
			for _i in range(7):
				var offers: Array = ShelterSim.offered_rules(s)
				if offers.is_empty():
					break
				_meeting(s, "rule_" + str(offers[0]))
			return [s, {}, Almanac.blank()],
		"cuckoo_house": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			for m_v in s.home():
				ShelterSim.add_morale(s, m_v as Dictionary, -10, "")
			s.day += 1
			for m_v in s.home():
				(m_v as Dictionary)["morale"] = 0
			ShelterSim.begin_day(s)
			return [s, {}, Almanac.blank()],
		"five_seconds_flat": func() -> Array:
			return [_run(), {"grab_all_down_left": 3.4}, Almanac.blank()],
		"long_haul": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10}, 1, "normal", true)
			ShelterSim.finish(s, "rescue_airlift")
			return [s, {"nearest_store_m": Achievements.nearest_store_m(s)}, Almanac.blank()],
		"door_jewellery": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10, "padlock": 3})
			s.followed = true
			for _i in range(3):
				s.raids_stopped_streak = 0
				s.followed = true
				ShelterSim._raid(s)
			return [s, {}, Almanac.blank()],
		"on_the_list": func() -> Array:
			var s: ShelterState = _run()
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"dish_rota": func() -> Array:
			var s: ShelterState = _run()
			ShelterSim.finish(s, "rescue_neighbourhood")
			return [s, {}, Almanac.blank()],
		"dont_look_down": func() -> Array:
			var s: ShelterState = _run()
			ShelterSim.finish(s, "rescue_airlift")
			return [s, {}, Almanac.blank()],
		"clean_hands": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			_quiet_day(s)
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"full_house": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			_quiet_day(s)
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"leap_of_faith": func() -> Array:
			var s: ShelterState = _run()
			ShelterEvents.apply_effect(s, {"do": "end_run", "ending": "maybe_walk_out"}, {}, [])
			return [s, {}, Almanac.blank()],
		"both_ways_out": func() -> Array:
			var meta: Dictionary = Almanac.blank()
			var s: ShelterState = null
			for e in ["maybe_walk_out", "maybe_stranger"]:
				s = _run()
				ShelterEvents.apply_effect(s, {"do": "end_run", "ending": e}, {}, [])
				Almanac.record_run(meta, s, {})
			return [s, {}, meta],
		"well_equipped": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			for it in ["axe", "rifle", "padlock", "bug_spray", "manual", "medkit", "radio", "gas_mask", "flashlight", "map"]:
				s.credit(it, "test")
			return [s, {}, Almanac.blank()],
		"field_medic": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10, "medkit": 3})
			for mid in ["m0", "m1", "m2"]:
				ShelterSim.make_sick(s, s.member(mid), "test", "chance")
			var plan: Dictionary = _feed(s)
			plan["treat"] = {"m0": true, "m1": true, "m2": true}
			_quiet_day(s, plan)
			return [s, {}, Almanac.blank()],
		"tuned_in": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10, "radio": 1})
			s.fallout_clear_day = 2
			_quiet_day(s)
			_quiet_day(s)
			return [s, {}, Almanac.blank()],
		"map_reader": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			for _i in range(3):
				_trip(s, "m1", 4, ["map"])
			return [s, {}, Almanac.blank()],
		"clean_lungs": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			s.fallout_clear_day = 99
			for _i in range(12):
				if int(s.stats["heavy_clean"]) >= 3:
					break
				_trip(s, "m1", 0, ["gas_mask"])
			return [s, {}, Almanac.blank()],
		"shake_them_off": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10, "padlock": 2})
			ShelterSim.become_followed(s, "test")
			ShelterSim._raid(s)
			ShelterSim._raid(s)
			return [s, {}, Almanac.blank()],
		"not_today": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10, "rifle": 1, "ammo": 2})
			ShelterSim.become_followed(s, "test")
			s.gang_warned = true
			ShelterSim._takeover(s)
			return [s, {}, Almanac.blank()],
		"second_opinion": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10, "manual": 1})
			for _i in range(10):
				if int(s.stats["repairs"]) >= 1:
					break
				s.broken["radio"] = 1
				ShelterEvents.apply_effect(s, {"do": "repair", "item": "radio"}, {"actor": "m0"}, [])
			return [s, {}, Almanac.blank()],
		"town_meeting": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			_meeting(s, "rule_finders_eat_first")
			return [s, {}, Almanac.blank()],
		"constitutional": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			_meeting(s, "no_rule")
			_meeting(s, "no_rule")
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"bedtime_story": func() -> Array:
			var s: ShelterState = _run({}, 1, "story")
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"by_the_book": func() -> Array:
			var s: ShelterState = _run({}, 1, "normal")
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"hard_bargain": func() -> Array:
			var s: ShelterState = _run({}, 1, "hard")
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"ration_book": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			for _i in range(5):
				_quiet_day(s)
			ShelterSim.finish(s, "rescue_airlift")
			return [s, {}, Almanac.blank()],
		"well_fed": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			for _i in range(5):
				_quiet_day(s)
			ShelterSim.finish(s, "rescue_airlift")
			return [s, {}, Almanac.blank()],
		"everyone_home": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			for _i in range(4):
				_trip(s, "m1", 0, [])
			ShelterSim.finish(s, "rescue_convoy")
			return [s, {}, Almanac.blank()],
		"good_neighbour": func() -> Array:
			var s: ShelterState = _run({"food": 10, "water": 10})
			(s.places[3] as Dictionary)["occupied"] = true
			ShelterSim.begin_day(s)
			s.today_event = {}
			s.today_resolved = true
			ShelterTrips.launch(s, s.member("m1"), 3, [])
			for t_v in s.trips:
				(t_v as Dictionary)["p_day"] = 0.0
			ShelterSim.end_day(s, _feed(s))
			ShelterSim.begin_day(s)
			ShelterSim.choose(s, "leave")
			for _i in range(6):
				if str(s.member("m1")["loc"]) == "shelter":
					break
				s.today_event = {}
				s.today_resolved = true
				ShelterSim.end_day(s, _feed(s))
				ShelterSim.begin_day(s)
			return [s, {}, Almanac.blank()],
	}


func run() -> int:
	var setups: Dictionary = _setups()
	# A fresh run earns nothing.
	var fresh_run: ShelterState = _run({"food": 10, "water": 10})
	var none: Array = Achievements.evaluate(fresh_run, {"grab_all_down_left": -1.0, "nearest_store_m": 300.0}, Almanac.blank(), {})
	_ok(none.is_empty(), "a fresh run on day 1 earns no achievement (%s)" % str(none))
	var missing: Array = []
	for aid in ShelterData.achievements().keys():
		if not setups.has(aid):
			missing.append(aid)
	_ok(missing.is_empty(), "every achievement has a test (missing: %s)" % str(missing))
	for aid in setups.keys():
		if not ShelterData.achievements().has(aid):
			_ok(false, "test '%s' has no achievement row" % aid)
			continue
		var r: Array = (setups[aid] as Callable).call()
		var unlocked: Dictionary = {}
		var got: Array = Achievements.evaluate(r[0], r[1], r[2], unlocked)
		var row: Dictionary = ShelterData.achievements()[aid]
		_ok(got.has(aid), "%s — %s" % [str(row["name"]), str(row["description"])])
	# The saved file is its own (tests never touch the player's achievements).
	var path: String = "user://test_achievements_roundtrip.json"
	Achievements.save_unlocked({"pharmacist": {"run": 1}}, path)
	var back: Dictionary = Achievements.load_unlocked(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_ok(back.has("pharmacist"), "unlocks survive a save and load")
	print("ACHIEVEMENTS passes=%d fails=%d" % [_passes, _fails.size()])
	for f in _fails:
		print("  FAIL: ", f)
	return 0 if _fails.is_empty() else 1
