extends Node

## M2 events and drama (sections 7, 8, 9): afflictions with a day's warning, House Rules and
## their effects, at most one stranger per run, occupied homes and Guilt, gamble endings, the
## death recap and MVP items, and the Survival Almanac — through the same calls the game uses.
## godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m2/drama_suite.gd

var _passes: int = 0
var _fails: Array[String] = []


func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] ", label)
	else:
		_fails.append(label)
		print("[FAIL] ", label)


func run() -> int:
	_test_content_shape()
	_test_afflictions()
	_test_affliction_behaviour()
	_test_house_meetings()
	_test_house_rule_effects()
	_test_strangers()
	_test_occupied_homes()
	_test_maybe_endings()
	_test_recap_and_mvp()
	_test_almanac()
	print("DRAMA passes=%d fails=%d" % [_passes, _fails.size()])
	for f in _fails:
		print("  FAIL: ", f)
	return 0 if _fails.is_empty() else 1


# ---------------------------------------------------------------- helpers

func _places() -> Array:
	return [
		{"osm_id": 11, "name": "Corner Market", "category": "grocery", "walk_m": 300.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 12, "name": "Far Pharmacy", "category": "pharmacy", "walk_m": 3100.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 13, "name": "Town Church", "category": "church", "walk_m": 900.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 14, "name": "", "category": "neighbor_house", "street": "Elm Street", "walk_m": 40.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 15, "name": "Lincoln School", "category": "school", "walk_m": 5000.0, "lat": 0.0, "lon": 0.0},
	]


func _run(haul: Dictionary = {}, seed_v: int = 1, opts: Dictionary = {}) -> ShelterState:
	var o: Dictionary = {"members": SimPolicies.default_family(), "haul": haul, "places": _places(),
		"rad_factors": [0.05, 0.05, 0.05, 0.05, 0.05], "h1_home_msv": 11500.0, "difficulty": "normal", "seed": seed_v}
	for k in opts.keys():
		o[k] = opts[k]
	return ShelterSim.new_run(o)


func _quiet_day(s: ShelterState, plan: Dictionary = {}) -> Dictionary:
	var morning: Dictionary = ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	var p: Dictionary = plan if not plan.is_empty() else _feed_all(s)
	ShelterSim.end_day(s, p)
	return morning


func _feed_all(s: ShelterState) -> Dictionary:
	var r: Dictionary = {}
	for m_v in s.home():
		r[str((m_v as Dictionary)["id"])] = {"food": true, "water": true}
	return {"rations": r, "treat": {}, "jobs": {}}


func _lines_text(lines: Array) -> String:
	var bits: Array[String] = []
	for l in lines:
		bits.append(str((l as Dictionary).get("text", "")))
	return "\n".join(bits)


func _occupied_idx(s: ShelterState) -> int:
	for p_v in s.places:
		if str((p_v as Dictionary)["category"]) == "neighbor_house":
			(p_v as Dictionary)["occupied"] = true
			return int((p_v as Dictionary)["idx"])
	return -1


func _set_event(s: ShelterState, eid: String) -> void:
	var ev: Dictionary = ShelterEvents._prepare(s, ShelterData.event(eid))
	s.today_event = ev
	s.today_resolved = false
	s.today_options = ShelterEvents.options_for(s, ev)


func _option(s: ShelterState, oid: String) -> Dictionary:
	for o_v in s.today_options:
		if str((o_v as Dictionary)["id"]) == oid:
			return o_v
	return {}


# ---------------------------------------------------------------- content

func _test_content_shape() -> void:
	var evs: Dictionary = ShelterData.events()
	_ok(evs.size() >= 80, "the event tables hold %d events (80 or more)" % evs.size())
	var short: Array = []
	var gated: int = 0
	var strangers: int = 0
	var maybe_endings: Dictionary = {}
	for eid in evs.keys():
		var ev: Dictionary = evs[eid]
		var basic: int = 0
		var has_item: bool = false
		for o_v in ev.get("options", []):
			if str((o_v as Dictionary).get("item", "")) == "":
				basic += 1
			else:
				has_item = true
			for e_v in DataBuilder._flat_effects((o_v as Dictionary).get("effects", [])):
				if str((e_v as Dictionary).get("do", "")) == "end_run":
					maybe_endings[str((e_v as Dictionary).get("ending", ""))] = true
		if basic < 2:
			short.append(eid)
		if has_item:
			gated += 1
		if bool(ev.get("stranger", false)):
			strangers += 1
	_ok(short.is_empty(), "every event has 2 options that need no item (short: %s)" % str(short))
	print("  item-gated events: %d of %d (%.0f%%)" % [gated, evs.size(), 100.0 * float(gated) / float(evs.size())])
	_ok(strangers >= 3, "%d rare strangers in the tables (3 or more)" % strangers)
	_ok(maybe_endings.size() >= 2, "both gamble endings can be chosen in events (%s)" % str(maybe_endings.keys()))
	_ok(ShelterData.house_rules().size() == 7, "7 House Rules, in order: %s" % str(ShelterData.house_rule_ids()))
	_ok(ShelterData.afflictions().size() == 4, "4 afflictions: %s" % str(ShelterData.afflictions().keys()))
	_ok(ShelterData.achievements().size() >= 30, "%d achievements (30 or more)" % ShelterData.achievements().size())


# ---------------------------------------------------------------- afflictions

func _test_afflictions() -> void:
	var s: ShelterState = _run({"food": 10, "water": 10}, 21)
	var maya: Dictionary = s.member("m2")
	maya["morale"] = 3
	# A day-time drop (an event) to the warning line: the warning is read today.
	ShelterSim.begin_day(s)
	s.receipt = []
	ShelterSim.add_morale(s, maya, -2, "")
	var warn_txt: String = _lines_text(s.receipt)
	_ok(warn_txt.find("Maya") != -1 and str(maya.get("affliction_next", "")) != "" and ShelterState.affliction(maya) == "",
		"morale 1 brings a one-line warning naming the person, not the affliction yet ('%s')" % warn_txt.strip_edges())
	ShelterSim.add_morale(s, maya, -1, "")
	_ok(ShelterState.affliction(maya) == "", "reaching 0 the same day does not afflict anyone yet")
	s.today_event = {}
	s.today_resolved = true
	ShelterSim.end_day(s, _feed_all(s))
	maya["morale"] = 0
	var m2: Dictionary = ShelterSim.begin_day(s)
	var aff: String = ShelterState.affliction(maya)
	_ok(aff != "" and _lines_text(m2["morning"]).find("Maya is ") != -1,
		"the next morning Maya is %s, and the receipt says what that means" % aff)
	_ok(ShelterSim.status_labels(maya, s.day).has(str(ShelterData.affliction(aff)["name"])), "the family row shows the affliction by name")

	# A night-time drop: the warning is only read next morning, so the affliction waits one more day.
	var n: ShelterState = _run({"food": 10, "water": 10}, 22)
	var sam: Dictionary = n.member("m0")
	ShelterSim.begin_day(n)
	n.today_event = {}
	n.today_resolved = true
	n.night = true
	sam["morale"] = 1
	ShelterSim.add_morale(n, sam, -1, "")
	n.night = false
	ShelterSim.end_day(n, _feed_all(n))
	sam["morale"] = 0
	var morning1: Dictionary = ShelterSim.begin_day(n)
	_ok(ShelterState.affliction(sam) == "" and _lines_text(morning1["morning"]).find("Sam") != -1,
		"a warning written at night is read in the morning, and nothing takes hold that morning")
	n.today_event = {}
	n.today_resolved = true
	ShelterSim.end_day(n, _feed_all(n))
	sam["morale"] = 0
	ShelterSim.begin_day(n)
	_ok(ShelterState.affliction(sam) != "", "one full day after the warning, the affliction takes hold (%s)" % ShelterState.affliction(sam))

	# Recovery at morale 3.
	sam["morale"] = 3
	n.today_event = {}
	n.today_resolved = true
	ShelterSim.end_day(n, _feed_all(n))
	var m3: Dictionary = ShelterSim.begin_day(n)
	_ok(ShelterState.affliction(sam) == "" and _lines_text(m3["morning"]).find("Sam") != -1, "morale back to 3 lifts the affliction, with a line")

	# Everyone afflicted at once is remembered (Cuckoo House).
	var c: ShelterState = _run({"food": 10, "water": 10}, 23)
	for m_v in c.home():
		(m_v as Dictionary)["morale"] = 0
		(m_v as Dictionary)["affliction_next"] = "withdrawn"
		(m_v as Dictionary)["affliction_warned_day"] = 0
	ShelterSim.begin_day(c)
	_ok(bool(c.stats["afflicted_all"]), "everyone at home afflicted at once is recorded")


func _afflict(s: ShelterState, mid: String, aff: String) -> Dictionary:
	var m: Dictionary = s.member(mid)
	m["morale"] = 0
	m["affliction"] = aff
	return m


func _test_affliction_behaviour() -> void:
	# Selfish: an extra ration at night, on the receipt.
	var s: ShelterState = _run({"food": 3, "water": 10}, 31)
	_afflict(s, "m1", "selfish")
	var before: int = s.food()
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	ShelterSim.end_day(s, _feed_all(s))
	var m: Dictionary = ShelterSim.begin_day(s)
	_ok(before - s.food() == 5 and _lines_text(m["morning"]).find("Selfish Priya ate an extra ration") != -1,
		"Selfish Priya eats an extra ration at night and the morning receipt says so (%d → %d)" % [before, s.food()])

	# Paranoid: no hatch options, no trips.
	var p: ShelterState = _run({"food": 10, "water": 10, "ammo": 2}, 32)
	_afflict(p, "m1", "paranoid")
	var hatch_ev: String = ""
	for eid in ShelterData.events().keys():
		for o_v in (ShelterData.events()[eid] as Dictionary).get("options", []):
			if bool((o_v as Dictionary).get("hatch", false)) and str((o_v as Dictionary).get("item", "")) == "" and hatch_ev == "" and not (ShelterData.events()[eid] as Dictionary).has("conditions"):
				hatch_ev = str(eid)
	if hatch_ev == "":
		hatch_ev = "water_man"
	_set_event(p, hatch_ev)
	var blocked: bool = false
	var other_ok: bool = false
	for o_v in p.today_options:
		var src: Dictionary = {}
		for so in p.today_event["options"]:
			if str((so as Dictionary)["id"]) == str((o_v as Dictionary)["id"]):
				src = so
		if bool(src.get("hatch", false)):
			blocked = not bool((o_v as Dictionary)["available"]) and str((o_v as Dictionary)["needs"]).begins_with("Paranoid Priya")
		elif bool((o_v as Dictionary)["available"]):
			other_ok = true
	_ok(blocked and other_ok, "Paranoid Priya won't open the hatch: '%s' greys its hatch option and leaves another" % hatch_ev)
	_ok(ShelterTrips.can_go(p, p.member("m1")).begins_with("Paranoid"), "a Paranoid survivor won't go out")

	# Reckless: the farthest place, if someone stays home.
	var r: ShelterState = _run({"food": 10, "water": 10}, 33)
	_afflict(r, "m1", "reckless")
	ShelterSim.begin_day(r)
	r.today_event = {}
	r.today_resolved = true
	ShelterSim.end_day(r, _feed_all(r))
	var far: int = ShelterTrips.farthest_place(r)
	var went: bool = false
	for t_v in r.trips:
		if str((t_v as Dictionary)["member"]) == "m1" and int((t_v as Dictionary)["place_idx"]) == far:
			went = true
	_ok(went and str(r.places[far]["name"]) == "Lincoln School", "Reckless Priya sets off for the farthest place on the map (%s)" % str(r.places[far]["name"]))
	var lone: ShelterState = ShelterSim.new_run({"members": [SimPolicies.default_family()[0]], "haul": {"food": 5, "water": 5}, "places": _places(),
		"rad_factors": [0.05, 0.05, 0.05, 0.05, 0.05], "seed": 34})
	_afflict(lone, "m0", "reckless")
	_quiet_day(lone)
	_ok(lone.trips.is_empty(), "a Reckless survivor alone in the shelter stays (somebody has to)")

	# Withdrawn won't work, unless the House Rule says so.
	var w: ShelterState = _run({"food": 10, "water": 10}, 35)
	_afflict(w, "m1", "withdrawn")
	_ok(ShelterTrips.can_go(w, w.member("m1")).begins_with("Withdrawn"), "a Withdrawn survivor won't take a job")
	ShelterSim.adopt_rule(w, "work_or_dont_eat")
	_ok(ShelterTrips.can_go(w, w.member("m1")) == "", "\"Work or don't eat\" puts the Withdrawn back to work")


# ---------------------------------------------------------------- House Rules

func _test_house_meetings() -> void:
	var s: ShelterState = _run({"food": 20, "water": 20}, 41)
	var meeting: Dictionary = {}
	for _d in range(6):
		var m: Dictionary = ShelterSim.begin_day(s)
		if str((m["event"] as Dictionary).get("id", "")) == "house_meeting":
			meeting = m
			break
		s.today_event = {}
		s.today_resolved = true
		ShelterSim.end_day(s, _feed_all(s))
	_ok(not meeting.is_empty() and int(meeting["day"]) == 4, "the first House meeting is on day 4 (day %d)" % int(meeting.get("day", -1)))
	var opts: Array = meeting.get("options", [])
	_ok(opts.size() == 3 and str((opts[0] as Dictionary)["id"]) == "rule_finders_eat_first" and str((opts[2] as Dictionary)["id"]) == "no_rule",
		"it offers the next two rules in order and 'No new rules' (%s)" % str(opts.map(func(o: Dictionary) -> String: return str(o["id"]))))
	_ok(str((opts[0] as Dictionary)["stakes"]).find("10%") != -1, "each rule shows its bonus and cost ('%s')" % str((opts[0] as Dictionary)["stakes"]))
	var mo_before: int = int(s.member("m0")["morale"])
	var out: Dictionary = ShelterSim.choose(s, "rule_finders_eat_first")
	_ok(s.has_rule("finders_eat_first") and int(s.member("m0")["morale"]) == mo_before - 1 and str(out["text"]) != "",
		"adopting a rule costs morale and the narrator remarks on it ('%s')" % str(out.get("text", "")))
	_ok(s.next_meeting_day == 8, "the next meeting is 4 days later")
	_ok(ShelterSim.offered_rules(s) == ["nobody_opens_hatch", "work_or_dont_eat"], "each rule goes a little further: next up %s" % str(ShelterSim.offered_rules(s)))
	_ok(not ShelterSim.offered_rules(s).has("pet_ration"), "the pet rule waits until there is a pet")
	ShelterSim.finish(s, "rescue_convoy")
	var info: Dictionary = ShelterSim.ending_info(s)
	_ok(str(info.get("rules_text", "")).find("Finders eat first") != -1, "the ending lists every rule passed ('%s')" % str(info.get("rules_text", "")))


func _trip_home(s: ShelterState, mid: String, place: int, gear: Array) -> String:
	var m: Dictionary = s.member(mid)
	m["loc"] = "shelter"
	m["tired_until"] = 0
	var why: String = ShelterTrips.launch(s, m, place, gear)
	if why != "":
		return why
	for t_v in s.trips:
		(t_v as Dictionary)["p_day"] = 0.0
	var guard: int = 0
	while str(m.get("loc", "")) == "away" and guard < 12:
		ShelterTrips.tick(s)
		s.day += 1
		guard += 1
	return ""


func _test_house_rule_effects() -> void:
	# Finders eat first: the others lose a point of morale when the explorer comes home.
	var f: ShelterState = _run({"food": 20, "water": 20}, 51)
	ShelterSim.adopt_rule(f, "finders_eat_first")
	var mo: int = int(f.member("m0")["morale"])
	_trip_home(f, "m1", 0, [])
	_ok(int(f.member("m0")["morale"]) == mo - 1, "Finders eat first: the family at home loses 1 morale when Priya gets back")

	# Nobody opens the hatch: an event can't give the hatch away, and hatch options are greyed.
	var h: ShelterState = _run({"food": 20, "water": 20, "ammo": 2, "cards": 1}, 52)
	ShelterSim.adopt_rule(h, "nobody_opens_hatch")
	ShelterEvents.apply_effect(h, {"do": "followed", "p": 1.0, "why": "test"}, {"actor": "m0"}, [])
	_ok(not h.followed, "Nobody opens the hatch: an event's 'followed' never lands")
	_set_event(h, "water_man")
	var greyed: bool = false
	for o_v in h.today_options:
		if str((o_v as Dictionary)["needs"]) == "House Rule: Nobody opens the hatch":
			greyed = true
	_ok(greyed, "Nobody opens the hatch: the water man's hatch option is greyed with the rule's name")

	# The sick sleep upstairs: contagion events never come up; the sick lose morale each night.
	var u: ShelterState = _run({"food": 40, "water": 40}, 53)
	ShelterSim.adopt_rule(u, "sick_sleep_upstairs")
	var contagion: Array = []
	for eid in ShelterData.events().keys():
		if bool((ShelterData.events()[eid] as Dictionary).get("contagion", false)):
			contagion.append(eid)
	var drawn_contagion: bool = false
	ShelterSim.make_sick(u, u.member("m1"), "test", "chance")
	var smo: int = int(u.member("m1")["morale"])
	for _d in range(30):
		ShelterSim.begin_day(u)
		if contagion.has(str(u.today_event.get("id", ""))):
			drawn_contagion = true
		u.today_event = {}
		u.today_resolved = true
		u.member("m1")["sick_days"] = 0
		ShelterSim.end_day(u, _feed_all(u))
		if u.is_over():
			break
	_ok(not contagion.is_empty() and not drawn_contagion, "The sick sleep upstairs: %d contagion event(s) never drawn in 30 days" % contagion.size())
	_ok(int(u.member("m1")["morale"]) < smo, "The sick sleep upstairs: the sick lose morale at night (%d → %d)" % [smo, int(u.member("m1")["morale"])])

	# Kids eat last: a skipped child's ration only counts every other day.
	var k: ShelterState = _run({"food": 20, "water": 20}, 54)
	ShelterSim.adopt_rule(k, "kids_eat_last")
	var leo: Dictionary = k.member("m3")
	for _d in range(6):
		var plan: Dictionary = _feed_all(k)
		(plan["rations"] as Dictionary)["m3"] = {"food": false, "water": true}
		_quiet_day(k, plan)
	_ok(int(leo["dwf"]) == 3, "Kids eat last: six skipped days count as three for Leo (%d)" % int(leo["dwf"]))
	_ok(int(leo["morale_cap"]) <= 5, "Kids eat last: Leo's morale stays at 5 or below")

	# Occupied homes are fair game: more loot, Guilt, and the neighbourhood rescue is gone.
	var o: ShelterState = _run({"food": 20, "water": 20}, 55)
	var oi: int = _occupied_idx(o)
	ShelterSim.adopt_rule(o, "occupied_fair_game")
	_trip_home(o, "m1", oi, [])
	_ok(bool(o.member("m1")["guilt"]) and o.harmed_innocents and o.scheduled.filter(func(x: Dictionary) -> bool: return str(x["event"]) == "occupied_house").is_empty(),
		"Occupied homes are fair game: no knock, the explorer carries Guilt, innocents were harmed")

	# The pet is an emergency ration.
	var pr: ShelterState = _run({"water": 20}, 56)
	pr.pets["dog"] = {"since": 1}
	ShelterSim.adopt_rule(pr, "pet_ration")
	var pm: int = int(pr.member("m0")["morale"])
	_quiet_day(pr, {"rations": {}, "treat": {}, "jobs": {}})
	var told: bool = _lines_text(pr.receipt).find("Nobody talks about the dog") != -1
	_ok(not pr.pets.has("dog") and pr.food() == 8 and int(pr.member("m0")["morale"]) < pm and told,
		"The pet is an emergency ration: the dog becomes 8 rations, everyone pays in morale, and nobody talks about it")


# ---------------------------------------------------------------- strangers

func _test_strangers() -> void:
	var ids: Array = []
	for eid in ShelterData.events().keys():
		if bool((ShelterData.events()[eid] as Dictionary).get("stranger", false)):
			ids.append(eid)
	var s: ShelterState = _run({"food": 40, "water": 40}, 61)
	s.stats["stranger"] = str(ids[0]) if not ids.is_empty() else ""
	var again: bool = false
	for _d in range(60):
		ShelterSim.begin_day(s)
		if ids.has(str(s.today_event.get("id", ""))):
			again = true
		s.today_event = {}
		s.today_resolved = true
		ShelterSim.end_day(s, _feed_all(s))
		if s.is_over():
			break
		for m_v in s.living():
			(m_v as Dictionary)["dww"] = 0
			(m_v as Dictionary)["dwf"] = 0
	_ok(not ids.is_empty() and not again, "after one stranger, no other stranger turns up (60 days)")


# ---------------------------------------------------------------- moral choices

func _test_occupied_homes() -> void:
	var s: ShelterState = _run({"food": 20, "water": 20}, 71)
	var oi: int = _occupied_idx(s)
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	ShelterTrips.launch(s, s.member("m1"), oi, [])
	for t_v in s.trips:
		(t_v as Dictionary)["p_day"] = 0.0
	ShelterSim.end_day(s, _feed_all(s))
	var m: Dictionary = ShelterSim.begin_day(s)
	_ok(str((m["event"] as Dictionary).get("id", "")) == "occupied_house", "arriving at a home somebody still lives in is a choice the next day")
	var label: String = str((m["event"] as Dictionary).get("setup", ""))
	_ok(label.find("neighbour's house") != -1 and label.find("Elm Street") != -1 and label.find("14") == -1,
		"the house is 'a neighbour's house', never an address ('%s')" % label)
	ShelterSim.choose(s, "steal")
	var guilt_day: int = s.day
	for _d in range(8):
		s.today_event = {}
		s.today_resolved = true
		ShelterSim.end_day(s, _feed_all(s))
		ShelterSim.begin_day(s)
	var priya: Dictionary = s.member("m1")
	_ok(bool(priya["guilt"]) and int(priya["morale_cap"]) <= 6 and s.count("medkit") >= 1,
		"stealing their medicine brings it home and puts Guilt (a morale cap) on Priya")
	_ok(bool(s.places[oi]["quiet"]) and str(ShelterTrips.place_label(s.places[oi])).find("quiet now") != -1,
		"days later the house is marked 'quiet now'")
	var quiet_lines: Array = []
	for nid in ShelterData.narration().keys():
		if str((ShelterData.narration()[nid] as Dictionary)["trigger"]) == "house_quiet":
			quiet_lines.append(str((ShelterData.narration()[nid] as Dictionary)["text"]))
	var said: bool = false
	for j in s.journal:
		if int((j as Dictionary)["day"]) > guilt_day + 2:
			for ql in quiet_lines:
				if _lines_text((j as Dictionary)["lines"]).find(str(ql)) != -1:
					said = true
	_ok(said, "the narrator brings it up days later")
	_ok(not s.harmed_innocents, "stealing alone doesn't count as harming innocents")

	var r: ShelterState = _run({"food": 20, "water": 20, "rifle": 1, "ammo": 3}, 72)
	var ri: int = _occupied_idx(r)
	ShelterSim.begin_day(r)
	r.today_event = {}
	r.today_resolved = true
	ShelterTrips.launch(r, r.member("m0"), ri, ["rifle"])
	for t_v in r.trips:
		(t_v as Dictionary)["p_day"] = 0.0
	ShelterSim.end_day(r, _feed_all(r))
	ShelterSim.begin_day(r)
	(r.chains["neighbourhood"] as Dictionary)["state"] = "active"
	ShelterSim.choose(r, "rob")
	ShelterChains.tick(r)
	_ok(r.harmed_innocents and str((r.chains["neighbourhood"] as Dictionary)["state"]) == "failed",
		"robbing a family at gunpoint locks the neighbourhood rescue, even one under way (%s)" % str((r.chains["neighbourhood"] as Dictionary)["state"]))

	var l: ShelterState = _run({"food": 20, "water": 20}, 73)
	var li: int = _occupied_idx(l)
	ShelterSim.begin_day(l)
	l.today_event = {}
	l.today_resolved = true
	ShelterTrips.launch(l, l.member("m1"), li, [])
	for t_v in l.trips:
		(t_v as Dictionary)["p_day"] = 0.0
	ShelterSim.end_day(l, _feed_all(l))
	ShelterSim.begin_day(l)
	ShelterSim.choose(l, "leave")
	for _d in range(6):
		l.today_event = {}
		l.today_resolved = true
		ShelterSim.end_day(l, _feed_all(l))
		ShelterSim.begin_day(l)
		if str(l.member("m1")["loc"]) == "shelter":
			break
	_ok(int(l.stats["occupied_left_alone"]) == 1 and not bool(l.member("m1")["guilt"]), "leaving them be takes nothing and leaves no Guilt")


# ---------------------------------------------------------------- endings

func _test_maybe_endings() -> void:
	var found: Dictionary = {}
	for eid in ShelterData.events().keys():
		var ev: Dictionary = ShelterData.events()[eid]
		for o_v in ev.get("options", []):
			for e_v in DataBuilder._flat_effects((o_v as Dictionary).get("effects", [])):
				if str((e_v as Dictionary).get("do", "")) == "end_run" and not found.has(str((e_v as Dictionary)["ending"])):
					found[str((e_v as Dictionary)["ending"])] = [eid, str((o_v as Dictionary)["id"])]
	for ending in found.keys():
		var s: ShelterState = _run({"food": 40, "water": 40, "map": 1, "radio": 1, "rifle": 1, "flashlight": 1, "gas_mask": 1, "medkit": 1, "console": 1, "cards": 1}, 81)
		s.day = 35
		s.fallout_clear_day = 1
		s.fallout_announced = true
		_set_event(s, str(found[ending][0]))
		var o: Dictionary = _option(s, str(found[ending][1]))
		if not bool(o.get("available", false)):
			for it in ShelterData.core_ids():
				s.add(it, 2)
			s.today_options = ShelterEvents.options_for(s, s.today_event)
		ShelterSim.choose(s, str(found[ending][1]))
		_ok(s.ending == ending and s.ending_kind == "maybe" and str(ShelterSim.ending_info(s).get("title", "")) != "",
			"'%s' → %s is a gamble ending ('%s')" % [str(found[ending][0]), ending, str(ShelterSim.ending_info(s).get("title", ""))])


# ---------------------------------------------------------------- end-of-run screens

func _test_recap_and_mvp() -> void:
	var s: ShelterState = _run({"food": 20, "water": 20, "padlock": 1}, 91)
	for _d in range(8):
		var plan: Dictionary = _feed_all(s)
		(plan["rations"] as Dictionary)["m2"] = {"food": true, "water": false}
		_quiet_day(s, plan)
		if not bool(s.member("m2")["alive"]):
			break
	var recap: Array = ShelterSim.death_recap(s)
	var maya: Dictionary = {}
	for d_v in recap:
		if str((d_v as Dictionary)["name"]) == "Maya":
			maya = d_v
	_ok(not maya.is_empty() and str(maya["text"]).find("skipped water") != -1 and str(maya["text"]).find("→") != -1,
		"the death recap is a chain of causes ('%s')" % str(maya.get("text", "")))
	_ok(not maya.is_empty() and str((maya["steps"] as Array)[int(maya["turning"])]).find("skipped water") != -1,
		"its turning point is the last decision that led there")
	s.followed = true
	ShelterSim._raid(s)
	var mv: Dictionary = ShelterSim.mvp_items(s)
	_ok(not (mv["mvp"] as Array).is_empty() and str(((mv["mvp"] as Array)[0] as Dictionary)["item"]) == "padlock",
		"MVP Items lists the items that did the most (%s)" % str(mv["mvp"]))
	var t: ShelterState = _run({"food": 20, "water": 20}, 92)
	t.followed = true
	ShelterSim._raid(t)
	_ok(not (ShelterSim.mvp_items(t)["missing"] as Array).is_empty(), "…and what was missing when it counted (%s)" % str(ShelterSim.mvp_items(t)["missing"]))


func _test_almanac() -> void:
	# Item options for items never discovered stay hidden; discovered ones grey out as "Needs: X".
	var known: Dictionary = {"rifle": true}
	var s: ShelterState = _run({"food": 8, "water": 8}, 101, {"known_items": known, "hide_unknown": true})
	var ev: Dictionary = ShelterEvents._prepare(s, ShelterData.event("signature_required"))
	var opts: Array = ShelterEvents.options_for(s, ev)
	var greyed_rifle: bool = false
	for o_v in opts:
		if str((o_v as Dictionary)["item"]) == "rifle" and str((o_v as Dictionary)["needs"]) == "Needs: Rifle":
			greyed_rifle = true
	_ok(greyed_rifle, "a discovered item you don't own shows as a greyed 'Needs: Rifle' option")
	var hidden: bool = true
	for eid in ["water_man", "the_collector", "swap_meet"]:
		var ev2: Dictionary = ShelterEvents._prepare(s, ShelterData.event(eid))
		for o_v in ShelterEvents.options_for(s, ev2):
			if str((o_v as Dictionary)["item"]) != "" and not known.has(str((o_v as Dictionary)["item"])):
				hidden = false
	_ok(hidden, "options for items never discovered stay hidden")

	# A run folds into the Almanac: items seen, what they did, the options they opened, endings.
	var a: Dictionary = Almanac.blank()
	var r: ShelterState = _run({"food": 8, "water": 8, "rifle": 1, "ammo": 2}, 102)
	_set_event(r, "signature_required")
	ShelterSim.choose(r, "shoot")
	ShelterSim.finish(r, "rescue_airlift")
	Almanac.record_run(a, r, {"address_key": "osm:1"})
	var page: Dictionary = Almanac.item_page(a, "rifle")
	_ok(bool(page["known"]) and not (page["effects"] as Array).is_empty() and not (page["options"] as Array).is_empty(),
		"the rifle's Almanac page lists what it did (%s) and the option it opened (%s)" % [str(page["effects"]), str(page["options"])])
	_ok(not bool(Almanac.item_page(a, "console")["known"]) and str(Almanac.item_page(a, "console")["name"]) == "???", "undiscovered items stay '???'")
	_ok((a["endings"] as Dictionary).has("rescue_airlift") and (a["addresses_won"] as Dictionary).has("osm:1"), "endings and rescued addresses are remembered")
	var path: String = "user://test_almanac_roundtrip.json"
	Almanac.save_data(a, path)
	var b: Dictionary = Almanac.load_data(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_ok(Almanac.is_known(b, "rifle") and int(b["runs"]) == 1, "the Almanac survives a save and load (its own file in user://)")
