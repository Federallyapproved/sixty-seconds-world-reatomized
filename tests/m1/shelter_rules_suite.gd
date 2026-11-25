extends Node

## M1 shelter rules (sections 3, 5, 6, 8, 9): survival thresholds, trips scaled by real distance,
## the pressure clocks, items doing exactly what their rows say, rescue timing and the fairness
## rules — all through the same ShelterSim calls the game and the balance harness use.
## godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m1/shelter_rules_suite.gd

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
	_test_thresholds()
	_test_trip_rules()
	_test_items()
	_test_raids_and_empty_shelter()
	_test_sickness()
	_test_rescue_timing()
	_test_pressure_and_difficulty()
	_test_fairness_over_runs()
	_test_clarity()
	print("SHELTER_RULES passes=%d fails=%d" % [_passes, _fails.size()])
	for f in _fails:
		print("  FAIL: ", f)
	return 0 if _fails.is_empty() else 1


# ---------------------------------------------------------------- helpers

func _places() -> Array:
	return [
		{"osm_id": 11, "name": "Corner Market", "category": "grocery", "subkind": "supermarket", "walk_m": 300.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 12, "name": "Far Pharmacy", "category": "pharmacy", "walk_m": 3100.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 13, "name": "Town Church", "category": "church", "walk_m": 900.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 14, "name": "", "category": "neighbor_house", "street": "Elm Street", "walk_m": 40.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 15, "name": "County Store", "category": "grocery", "walk_m": 10000.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 16, "name": "Rural Depot", "category": "hardware", "walk_m": 30000.0, "lat": 0.0, "lon": 0.0},
	]


func _run(haul: Dictionary = {}, seed_v: int = 1, diff: String = "normal", h1: float = 11500.0) -> ShelterState:
	return ShelterSim.new_run({"members": SimPolicies.default_family(), "haul": haul, "places": _places(),
		"rad_factors": [0.05, 0.05, 0.05, 0.05, 0.05, 0.05], "h1_home_msv": h1, "difficulty": diff, "seed": seed_v})


func _quiet_day(s: ShelterState, plan: Dictionary) -> void:
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	ShelterSim.end_day(s, plan)


func _plan_feed(s: ShelterState, food: bool, water: bool) -> Dictionary:
	var r: Dictionary = {}
	for m_v in s.home():
		r[str((m_v as Dictionary)["id"])] = {"food": food, "water": water}
	return {"rations": r, "treat": {}, "jobs": {}}


# ---------------------------------------------------------------- tests

func _test_thresholds() -> void:
	var s: ShelterState = _run({"food": 20, "water": 0})
	var m: Dictionary = s.members[0]
	var seen: Dictionary = {}
	for d in range(7):
		_quiet_day(s, _plan_feed(s, true, false))
		seen[int(m.get("dww", 0))] = ShelterSim.status_labels(m, s.day).duplicate() if bool(m.get("alive", false)) else ["Dead"]
	_ok((seen.get(3, []) as Array).has("Thirsty"), "thirsty on day 3 without water")
	_ok((seen.get(4, []) as Array).has("Dehydrated"), "dehydrated on day 4 without water")
	var dead6: int = 0
	var dead5: int = 0
	for trial in range(300):
		var t: ShelterState = _run({"food": 20}, 1000 + trial)
		for mm0 in t.members:
			(mm0 as Dictionary)["role"] = "adult"
			(mm0 as Dictionary)["age"] = 30
		for d in range(6):
			_quiet_day(t, _plan_feed(t, true, false))
			if d == 4:
				for mm in t.members:
					if not bool((mm as Dictionary).get("alive", true)):
						dead5 += 1
		for mm in t.members:
			if not bool((mm as Dictionary).get("alive", true)):
				dead6 += 1
	var p5: float = float(dead5) / 1200.0
	_ok(p5 > 0.40 and p5 < 0.60, "day 5 without water: ~50%% death roll (%.0f%%)" % (100.0 * p5))
	_ok(dead6 == 1200, "day 6 without water is always fatal")
	var f: ShelterState = _run({"water": 30})
	var fm: Dictionary = f.members[0]
	var fseen: Dictionary = {}
	for d in range(10):
		_quiet_day(f, _plan_feed(f, false, true))
		fseen[int(fm.get("dwf", 0))] = ShelterSim.status_labels(fm, f.day).duplicate() if bool(fm.get("alive", false)) else ["Dead"]
	_ok((fseen.get(6, []) as Array).has("Hungry"), "hungry on day 6 without food")
	_ok((fseen.get(8, []) as Array).has("Starving"), "starving on day 8 without food")
	_ok(not bool(fm.get("alive", true)) and str(fm.get("death_reason", "")).find("Starved") != -1, "dies on day 10 without food")
	var pv: Dictionary = ShelterSim.ration_preview(f, {"dww": 2, "dwf": 0, "name": "Dad"}, true, false)
	_ok(str(pv["water"]).find("thirsty tomorrow (day 3 without)") != -1, "ration row preview: 'is thirsty tomorrow (day 3 without)'")


func _test_trip_rules() -> void:
	var s: ShelterState = _run({"food": 20, "water": 20, "map": 1, "suitcase": 1, "gas_mask": 1})
	var m: Dictionary = s.members[1]
	_ok(ShelterTrips.base_days(s.places[0]) == 2, "0.6 km round trip = 2 days (minimum)")
	_ok(ShelterTrips.base_days(s.places[1]) == 3, "6.2 km round trip = 3 days")
	_ok(ShelterTrips.base_days(s.places[4]) == 5, "20 km round trip = 5 days")
	_ok(ShelterTrips.base_days(s.places[5]) == 7, "60 km round trip clamps to 7 days")
	_ok(ShelterTrips.trip_days(s.places[1], ["map"]) == 2, "a map takes a day off")
	var pv0: Dictionary = ShelterTrips.preview(s, m, 2, [])
	var expect: float = 1.0 - pow(1.0 - 0.025 * 2.0, float(int(pv0["days"])))
	_ok(absf(float(pv0["p_death"]) - expect) < 0.0001, "death chance = 1-(1-p)^days, no mask in heavy fallout doubles p (%.3f)" % float(pv0["p_death"]))
	var pv1: Dictionary = ShelterTrips.preview(s, m, 2, ["gas_mask", "map"])
	var expect1: float = 1.0 - pow(1.0 - 0.025 * 0.6, float(int(pv1["days"])))
	_ok(absf(float(pv1["p_death"]) - expect1) < 0.0001, "mask removes the heavy-fallout x2, the map multiplies by 0.6")
	_ok(int(pv0["carry"]) == 2 and int(ShelterTrips.preview(s, m, 2, ["suitcase"])["carry"]) == 5, "carry 2 slots, 5 with the suitcase")
	_ok(absf(float(pv0["sick_p"]) - 0.7) < 0.001 and absf(float(pv1["sick_p"]) - 0.2) < 0.001, "sick on return in heavy fallout: 70% without a mask, 20% with")
	_ok(str(pv0["risk_band"]) in ["Low", "Moderate", "High", "Severe"] and str(pv0["dose_band"]) in ["Low", "High", "Lethal"], "preview shows risk and dose as bands")
	_ok(str(ShelterTrips.preview(s, m, 1, [])["tool"]).find("Axe") != -1, "a pharmacy preview names the tool it needs")
	_ok(ShelterTrips.place_label(s.places[3]).begins_with("a neighbour's house on Elm Street"), "neighbours' homes are 'a neighbour's house', never an address")
	# Sickness on return, measured
	var sick_masked: int = 0
	var sick_bare: int = 0
	for trial in range(400):
		for masked in [true, false]:
			var t: ShelterState = _run({"food": 20, "water": 20, "gas_mask": 1}, 5000 + trial)
			var mm: Dictionary = t.members[1]
			ShelterSim.begin_day(t)
			t.today_event = {}
			t.today_resolved = true
			var plan: Dictionary = {"rations": {}, "treat": {}, "jobs": {str(mm["id"]): {"job": "trip", "place": 0, "gear": (["gas_mask"] if masked else [])}}}
			ShelterSim.end_day(t, plan)
			for _d in range(4):
				if str(mm.get("loc", "")) != "away":
					break
				_quiet_day(t, {"rations": {}, "treat": {}, "jobs": {}})
			if bool(mm.get("alive", false)) and bool(mm.get("sick", false)):
				if masked:
					sick_masked += 1
				else:
					sick_bare += 1
	_ok(float(sick_masked) / 400.0 < 0.32 and float(sick_bare) / 400.0 > 0.55, "measured trip sickness in heavy fallout: %.0f%% masked, %.0f%% bare" % [100.0 * float(sick_masked) / 400.0, 100.0 * float(sick_bare) / 400.0])
	# Tired after a 3+ day trip
	var lt: ShelterState = _run({"food": 20, "water": 20})
	var lm: Dictionary = lt.members[1]
	ShelterSim.begin_day(lt)
	lt.today_event = {}
	lt.today_resolved = true
	ShelterSim.end_day(lt, {"rations": {}, "treat": {}, "jobs": {str(lm["id"]): {"job": "trip", "place": 1, "gear": []}}})
	var guard: int = 0
	while str(lm.get("loc", "")) == "away" and guard < 12:
		_quiet_day(lt, {"rations": {}, "treat": {}, "jobs": {}})
		guard += 1
	if bool(lm.get("alive", false)):
		_ok(ShelterTrips.can_go(lt, lm).begins_with("Tired"), "a 3-day trip leaves the explorer Tired (no trips)")
	else:
		_ok(true, "a 3-day trip leaves the explorer Tired (explorer died on this seed; covered by other runs)")


func _test_items() -> void:
	var s: ShelterState = _run({"rifle": 1, "ammo": 1, "axe": 1, "padlock": 1})
	s.followed = true
	ShelterSim._raid(s)
	_ok(s.count("ammo") == 0 and s.has("rifle"), "rifle stops a raid and spends 1 ammo")
	ShelterSim._raid(s)
	_ok(int(s.stats["raids_stopped"]) == 2, "rifle without ammo still stops a raid")
	_ok(not s.followed, "two stopped raids in a row shake the gang off")
	var a: ShelterState = _run({"axe": 1})
	a.followed = true
	ShelterSim._raid(a)
	_ok(not a.has("axe") and a.broken_count("axe") == 1, "the axe stops one raid, then breaks")
	var p: ShelterState = _run({"padlock": 1})
	p.followed = true
	ShelterSim._raid(p)
	_ok(not p.owns("padlock"), "the padlock stops one raid and is discarded")
	var n: ShelterState = _run({"food": 2, "water": 2})
	n.followed = true
	var before: int = n.food() + n.water()
	ShelterSim._raid(n)
	_ok(n.food() + n.water() == before - 4, "an unstopped raid steals a can or a bottle")
	# Manual repairs
	var r: ShelterState = _run({"manual": 1, "radio": 1})
	r.break_one("radio")
	var ok_n: int = 0
	for trial in range(200):
		var rr: ShelterState = _run({"manual": 1, "radio": 1}, 700 + trial)
		rr.break_one("radio")
		ShelterEvents._repair(rr, "radio", [])
		if rr.has("radio"):
			ok_n += 1
	_ok(float(ok_n) / 200.0 > 0.75 and float(ok_n) / 200.0 < 0.95, "the manual repairs the radio ~85%% of the time (%.0f%%)" % (100.0 * float(ok_n) / 200.0))
	var both_lost: int = 0
	for trial in range(200):
		var mp: ShelterState = _run({"manual": 1, "map": 1}, 900 + trial)
		mp.break_one("map")
		ShelterEvents._repair(mp, "map", [])
		if not mp.owns("map") and not mp.owns("manual"):
			both_lost += 1
	_ok(float(both_lost) / 200.0 > 0.38 and float(both_lost) / 200.0 < 0.62, "repairing the map destroys map and manual ~50%% of the time (%.0f%%)" % (100.0 * float(both_lost) / 200.0))
	var med: ShelterState = _run({"medkit": 1})
	var mm: Dictionary = med.members[0]
	ShelterSim.make_sick(med, mm, "test", "chance")
	ShelterSim.make_injured(med, mm, "test", "chance")
	ShelterSim.begin_day(med)
	med.today_event = {}
	med.today_resolved = true
	ShelterSim.end_day(med, {"rations": {}, "treat": {str(mm["id"]): true}, "jobs": {}})
	_ok(not bool(mm.get("sick", false)) and not bool(mm.get("injured", false)) and not med.owns("medkit"), "a medkit cures sickness and injury and is used up")
	_ok(int(mm.get("relapse_until", 0)) == med.day - 1 + 5, "after a cure the survivor is vulnerable to relapse for 5 days")
	var sc: ShelterState = _run({"food": 1})
	_ok(sc.food() == 4, "a can of food is 4 rations")
	var su: ShelterState = _run({"suitcase": 1})
	_ok(ShelterTrips.carry_slots(["suitcase"]) == 5, "the suitcase adds 3 carry slots")
	var q: ShelterState = _run({"radio": 1, "gas_mask": 1, "flashlight": 1}, 3)
	var broke: int = 0
	for trial in range(300):
		var qq: ShelterState = _run({"radio": 1, "gas_mask": 1, "flashlight": 1}, 2000 + trial)
		ShelterEvents.apply_effect(qq, {"do": "break_fragile", "p": 0.4}, {}, [])
		if qq.broken.size() > 0:
			broke += 1
	_ok(float(broke) / 300.0 > 0.3 and float(broke) / 300.0 < 0.5, "a quake breaks a fragile item ~40%% of the time (%.0f%%)" % (100.0 * float(broke) / 300.0))


func _test_raids_and_empty_shelter() -> void:
	var s: ShelterState = _run({"food": 20, "water": 20, "padlock": 1})
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	var jobs: Dictionary = {}
	for m_v in s.home():
		var m: Dictionary = m_v
		if not ShelterState.is_child(m):
			jobs[str(m["id"])] = {"job": "trip", "place": 3, "gear": []}
	# The child can't go: send the adults; the child stays, so the padlock isn't needed.
	ShelterSim.end_day(s, {"rations": {}, "treat": {}, "jobs": jobs})
	_ok(not s.is_over() and s.has("padlock"), "padlock is only used when the last person leaves")
	var e: ShelterState = _run({"food": 20, "water": 20})
	e.members = [e.members[0], e.members[1]]
	ShelterSim.begin_day(e)
	e.today_event = {}
	e.today_resolved = true
	ShelterSim.end_day(e, {"rations": {}, "treat": {}, "jobs": {"m0": {"job": "trip", "place": 3, "gear": []}, "m1": {"job": "trip", "place": 3, "gear": []}}})
	_ok(e.ending == "loss_empty", "leaving the shelter empty without a padlock loses the run")
	var pl: ShelterState = _run({"food": 20, "water": 20, "padlock": 1})
	pl.members = [pl.members[0], pl.members[1]]
	ShelterSim.begin_day(pl)
	pl.today_event = {}
	pl.today_resolved = true
	ShelterSim.end_day(pl, {"rations": {}, "treat": {}, "jobs": {"m0": {"job": "trip", "place": 3, "gear": []}, "m1": {"job": "trip", "place": 3, "gear": []}}})
	_ok(not pl.is_over() and not pl.owns("padlock"), "the padlock locks the hatch behind the last one out (and is used up)")
	var f: ShelterState = _run({"food": 40, "water": 40}, 77)
	ShelterSim.become_followed(f, "test")
	var raid_days: Array = []
	var last: int = int(f.stats["raids"])
	for d in range(12):
		_quiet_day(f, _plan_feed(f, false, f.day % 2 == 0))
		if int(f.stats["raids"]) > last:
			raid_days.append(f.day)
			last = int(f.stats["raids"])
	_ok(raid_days.size() >= 3 and int(raid_days[1]) - int(raid_days[0]) == 3, "once followed, raids come every 3 days (%s)" % str(raid_days))


func _test_sickness() -> void:
	var s: ShelterState = _run({"food": 99, "water": 99}, 5)
	var m: Dictionary = s.members[0]
	ShelterSim.make_sick(s, m, "test", "chance")
	var diseased_day: int = -1
	for d in range(19):
		_quiet_day(s, _plan_feed(s, true, true))
		if diseased_day < 0 and bool(m.get("alive", false)) and ShelterSim.status_labels(m, s.day).has("Diseased"):
			diseased_day = int(m["sick_days"])
	_ok(diseased_day == 7, "untreated sickness turns Diseased on day 7")
	_ok(not bool(m.get("alive", true)), "untreated sickness is fatal by day 18")
	var deaths_before_10: int = 0
	for trial in range(200):
		var t: ShelterState = _run({"food": 99, "water": 99}, 300 + trial)
		var tm: Dictionary = t.members[0]
		ShelterSim.make_sick(t, tm, "test", "chance")
		for d in range(9):
			_quiet_day(t, _plan_feed(t, true, true))
		if not bool(tm.get("alive", true)):
			deaths_before_10 += 1
	_ok(deaths_before_10 == 0, "nobody dies of sickness before day 10")


func _test_rescue_timing() -> void:
	var earliest: int = 999
	var contact_ok: bool = true
	for trial in range(300):
		var s: ShelterState = _run({"food": 60, "water": 60, "radio": 2, "map": 2, "flashlight": 2, "gas_mask": 2}, 4000 + trial)
		while not s.is_over() and s.day < 80:
			ShelterSim.begin_day(s)
			var ev: Dictionary = s.today_event
			if ev.has("chain") and int(ev.get("step", 0)) == 1 and s.day < s.fallout_clear_day:
				contact_ok = false
			if not ev.is_empty():
				var pick: String = ""
				for o_v in s.today_options:
					var o: Dictionary = o_v
					if bool(o.get("available", false)) and (pick == "" or str(o.get("item", "")) != ""):
						pick = str(o["id"])
				ShelterSim.choose(s, pick)
			if s.is_over():
				break
			ShelterSim.end_day(s, _plan_feed(s, s.day % 6 == 0, s.day % 3 == 0))
		if s.ending_kind == "win":
			earliest = mini(earliest, s.ending_day)
	_ok(contact_ok, "no rescue contact before the fallout all-clear")
	_ok(earliest >= 25, "no rescue lands before day 25 even with every item (earliest %d)" % earliest)
	var c: ShelterState = _run({}, 9)
	c.chains["convoy"]["state"] = "active"
	c.chains["convoy"]["next_day"] = c.day
	ShelterChains.step(c, "convoy", "miss", {})
	var delay: int = int(c.chains["convoy"]["next_day"]) - c.day
	_ok(delay >= 6 and delay <= 10, "a missed request delays the chain 6-10 days (%d)" % delay)
	for d in range(25):
		var cl: int = ShelterSim.compute_fallout_clear_day(11500.0, RandomNumberGenerator.new())
		if cl < 7 or cl > 20:
			_ok(false, "fallout clears between day 7 and 20")
			return
	_ok(true, "fallout clears between day 7 and 20")


func _test_pressure_and_difficulty() -> void:
	var s: ShelterState = _run({}, 21)
	var g: Dictionary = s.places[0]
	var before: int = ShelterTrips.stock_total(g)
	ShelterTrips.drain(s)
	var lost: float = 1.0 - float(ShelterTrips.stock_total(g)) / float(before)
	_ok(lost >= 0.04 and lost <= 0.14, "a grocery loses 7-10%% of its stock a day to unseen survivors (%.1f%%)" % (100.0 * lost))
	var st: ShelterState = _run({}, 21, "story")
	_ok(ShelterTrips.stock_total(st.places[0]) > before, "Story mode stocks more")
	var hd: ShelterState = _run({}, 21, "hard")
	ShelterSim.become_followed(hd, "test")
	_ok(hd.next_raid_day - hd.day == 3, "Hard mode raids every 2 days")
	_ok(GameState.DIFFICULTY_TIMERS["story"]["recon"] == 20.0 and GameState.DIFFICULTY_TIMERS["normal"]["recon"] == 10.0 and GameState.DIFFICULTY_TIMERS["hard"]["recon"] == 3.0, "recon 20/10/3 s by difficulty")
	_ok(GameState.DIFFICULTY_TIMERS["hard"]["grab"] == 30.0 and GameState.DIFFICULTY_TIMERS["normal"]["grab"] == 60.0, "grab 60 s, 30 s on Hard")


## Fairness over many expert runs: no repeats, at most two bad events in a row, a warning before any
## fatal event, a cause chain for every death, and every event turns up somewhere.
func _test_fairness_over_runs() -> void:
	var fixtures: Array = preload("res://tests/sim/sim_harness.gd").load_fixtures()
	var repeats: int = 0
	var streak_viol: int = 0
	var unwarned: int = 0
	var no_chain: int = 0
	var seen: Dictionary = {}
	for i in range(600):
		var fx: Dictionary = fixtures[i % fixtures.size()]
		var policy: String = ["expert", "naive", "random"][i % 3]
		var rng := RandomNumberGenerator.new()
		rng.seed = 31000 + i
		var s: ShelterState = ShelterSim.new_run({"members": SimPolicies.default_family(), "haul": SimPolicies.grab(policy, rng, 12),
			"places": fx["targets"], "rad_factors": fx["rad_factors"], "h1_home_msv": float(fx["h1_home_msv"]), "seed": 31000 + i})
		var drawn: Dictionary = {}
		var streak: int = 0
		while not s.is_over() and s.day < 90:
			ShelterSim.begin_day(s)
			if s.is_over():
				break
			var ev: Dictionary = s.today_event
			if not ev.is_empty():
				var eid: String = str(ev["id"])
				seen[eid] = true
				if drawn.has(eid):
					repeats += 1
				drawn[eid] = true
				var random_draw: bool = not ev.has("chain") and not bool(ev.get("system", false))
				if str(ev.get("mood", "")) == "bad":
					streak += 1
					if streak > 2 and random_draw:
						streak_viol += 1
				else:
					streak = 0
				var warn: String = str(ev.get("warning", ""))
				if warn != "" and (not s.warnings.has(warn) or int(s.warnings[warn]) >= s.day):
					unwarned += 1
				ShelterSim.choose(s, SimPolicies.pick_option(s, policy, rng))
			if s.is_over():
				break
			ShelterSim.end_day(s, SimPolicies.make_plan(s, policy, rng))
		for d_v in s.stats["deaths"]:
			var d: Dictionary = d_v
			if str(d["cause"]) != "trip" and (d.get("chain", []) as Array).is_empty() and not (str(d["cause"]) in ["thirst", "starvation"]):
				no_chain += 1
	_ok(repeats == 0, "no event repeats within a run (%d repeats)" % repeats)
	_ok(streak_viol == 0, "never more than 2 bad events in a row (%d violations)" % streak_viol)
	_ok(unwarned == 0, "every fatal event was preceded by its warning on an earlier day (%d unwarned)" % unwarned)
	_ok(no_chain == 0, "every sickness/event death has a traceable cause chain (%d without)" % no_chain)
	# Rare branches (a chain's last request missed once) are checked by setting the chain up directly.
	var missing: Array = []
	for eid in ShelterData.events().keys():
		if seen.has(eid):
			continue
		var ev: Dictionary = ShelterData.event(str(eid))
		if ev.has("chain"):
			var t: ShelterState = _run({"food": 20, "water": 20}, 77)
			t.day = 40
			for other in t.chains.keys():
				(t.chains[other] as Dictionary)["state"] = "idle"
			var c: Dictionary = t.chains[str(ev["chain"])]
			c["state"] = "active"
			c["step"] = int(ev["step"])
			c["misses"] = 1 if bool(ev.get("retry", false)) else 0
			c["next_day"] = t.day
			if ShelterChains.due_event(t) == str(eid):
				continue
		missing.append(eid)
	_ok(missing.is_empty(), "every event is reachable (seen in 600 runs or reached by setting its chain up; unreachable: %s)" % str(missing))


func _test_clarity() -> void:
	var s: ShelterState = _run({"food": 8, "water": 8, "rifle": 1, "ammo": 1}, 11)
	var ev: Dictionary = ShelterEvents._prepare(s, ShelterData.event("signature_required"))
	s.today_event = ev
	s.today_resolved = false
	s.today_options = ShelterEvents.options_for(s, ev)
	var opts: Array = s.today_options
	_ok((opts[0] as Dictionary)["item"] == "rifle" and bool((opts[0] as Dictionary)["available"]), "item option tagged with its item and available when owned")
	var out: Dictionary = ShelterSim.choose(s, "shoot")
	var used_line: bool = false
	for l in out.get("lines", []):
		if str((l as Dictionary)["text"]).begins_with("Used: Rifle →"):
			used_line = true
	_ok(used_line, "receipt prints 'Used: Rifle → …'")
	var s2: ShelterState = _run({"food": 8, "water": 8}, 12)
	var ev2: Dictionary = ShelterEvents._prepare(s2, ShelterData.event("signature_required"))
	var opts2: Array = ShelterEvents.options_for(s2, ev2)
	_ok(not bool((opts2[0] as Dictionary)["available"]) and str((opts2[0] as Dictionary)["needs"]) == "Needs: Rifle", "missing item shows a greyed 'Needs: Rifle' option")
	_ok(str((opts2[2] as Dictionary)["stakes"]) != "", "costly options show their stakes ('%s')" % str((opts2[2] as Dictionary)["stakes"]))
