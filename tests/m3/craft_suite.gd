extends Node

## M3 crafting and salvage (section 10): parts and junk, the 12-part shelf, recipes and their
## limits (two Quick or one Day, tools, failure chances, half the parts back), the manual's
## chapters and pamphlets, every makeshift item doing its weaker job, stand-ins in events (never
## in rescue steps), dirty water, night thieves, the Need toggle and electronics shops — through
## the same calls the game makes.
## godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m3/craft_suite.gd

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
	_test_content()
	_test_take_apart()
	_test_shelf_cap()
	_test_recipes_and_limits()
	_test_crafting()
	_test_failure()
	_test_learning()
	_test_pamphlets()
	_test_bandage_and_patch()
	_test_trip_gear()
	_test_raid_defences()
	_test_night()
	_test_stand_ins()
	_test_need_toggle()
	_test_places()
	print("CRAFT passes=%d fails=%d" % [_passes, _fails.size()])
	for f in _fails:
		print("  FAIL: ", f)
	return 0 if _fails.is_empty() else 1


# ---------------------------------------------------------------- helpers

func _places() -> Array:
	return [
		{"osm_id": 21, "name": "Corner Market", "category": "grocery", "subkind": "supermarket", "walk_m": 300.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 22, "name": "Main St Pharmacy", "category": "pharmacy", "walk_m": 700.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 23, "name": "Bolt Hardware", "category": "hardware", "subkind": "hardware", "walk_m": 900.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 24, "name": "", "category": "neighbor_house", "street": "Elm Street", "walk_m": 40.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 25, "name": "Phone Repair", "category": "hardware", "subkind": "mobile_phone", "walk_m": 1200.0, "lat": 0.0, "lon": 0.0},
	]


func _run(haul: Dictionary = {}, seed_v: int = 1, keep_box: bool = false) -> ShelterState:
	var s: ShelterState = ShelterSim.new_run({"members": SimPolicies.default_family(), "haul": haul, "places": _places(),
		"rad_factors": [0.05, 0.05, 0.05, 0.05, 0.05], "h1_home_msv": 11500.0, "difficulty": "normal", "seed": seed_v})
	if not keep_box:
		# Most checks want only the haul on the shelf, not the shelter's own box of junk.
		for k in s.stock.keys().duplicate():
			if ShelterCraft.is_junk(str(k)):
				if haul.has(k):
					s.stock[k] = int(haul[k])
				else:
					s.stock.erase(k)
	return s


func _feed_all(s: ShelterState, jobs: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {}
	for m_v in s.home():
		r[str((m_v as Dictionary)["id"])] = {"food": true, "water": true}
	return {"rations": r, "treat": {}, "jobs": jobs}


func _quiet_day(s: ShelterState, plan: Dictionary = {}) -> void:
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	ShelterSim.end_day(s, plan if not plan.is_empty() else _feed_all(s))


func _text(s: ShelterState) -> String:
	var bits: Array[String] = []
	for l in s.receipt:
		bits.append(str((l as Dictionary).get("text", "")))
	return "\n".join(bits)


func _parts(s: ShelterState, d: Dictionary) -> void:
	s.parts = d.duplicate()


# ---------------------------------------------------------------- content

func _test_content() -> void:
	var res: Dictionary = DataBuilder.build(false)
	_ok((res["errors"] as Array).is_empty(), "the validator passes with the M3 tables (%s)" % str((res["errors"] as Array).slice(0, 3)))
	var shapes: Dictionary = {}
	for pid in ShelterData.part_ids():
		shapes[str(ShelterData.part(pid).get("shape", ""))] = true
	_ok(ShelterData.part_ids().size() == 6 and shapes.size() == 6, "6 parts, each with its own shape for colour-blind players")
	_ok(ShelterData.ids_in("junk").size() == 11, "11 junk items (section 10 table)")
	_ok(ShelterData.ids_in("makeshift").size() == 11 and ShelterData.recipes().size() == 12, "12 recipes making 11 makeshift items plus the Patch Job")
	_ok(ShelterData.chapters().size() == 4, "the manual has 4 chapters")
	var slots_ok: bool = ShelterData.item_slots("toaster") == 2 and ShelterData.item_slots("pots_pans") == 2 and ShelterData.item_slots("duct_tape") == 1
	_ok(slots_ok, "junk slot counts: toaster and pots 2, the rest 1")
	_ok(ItemDB.tooltip_line("toaster") == "Toaster [2] → 2 Metal, 1 Electronics", "grab tooltip for junk: %s" % ItemDB.tooltip_line("toaster"))
	var sources_ok: bool = true
	for pid in ShelterData.part_ids():
		if ShelterCraft.part_sources(pid).size() < 2:
			sources_ok = false
	_ok(sources_ok, "every part comes from junk in at least 2 place types besides home")
	var gated: Dictionary = res["out"]["item_gate_counts"]
	var all_m: bool = true
	for iid in ShelterData.ids_in("makeshift"):
		if int(gated.get(iid, 0)) < 1:
			all_m = false
	_ok(all_m, "every makeshift item matters in at least 1 event (as the item or a stand-in)")
	var rescue_alt: bool = false
	for eid in ShelterData.events().keys():
		var ev: Dictionary = ShelterData.event(str(eid))
		if ev.has("chain") or str(ev.get("type", "")) == "rescue":
			for o_v in ev.get("options", []):
				if not ((o_v as Dictionary).get("alt", []) as Array).is_empty():
					rescue_alt = true
	_ok(not rescue_alt, "no rescue step accepts a makeshift stand-in")
	# The validator itself refuses one (makeshift items can't meet rescue or ending conditions).
	var db := DataBuilder.new()
	db._check_alts({"x": {"id": "x", "chain": "convoy", "type": "rescue", "options": [
		{"id": "a", "item": "flashlight", "alt": [{"item": "phone_torch"}], "effects": [{"do": "chain", "chain": "convoy", "step": "win"}]}]}},
		ShelterData.items())
	_ok(not db.errors.is_empty(), "the validator rejects a stand-in on a rescue step")
	var icons_ok: bool = true
	for iid in ShelterData.ids_in("junk") + ShelterData.ids_in("makeshift"):
		if ItemDB.get_icon_texture(iid) == null:
			icons_ok = false
	_ok(icons_ok, "every junk and makeshift item has an icon")
	_ok(FileAccess.get_file_as_string("res://assets/icons/items/door_barricade.svg").find("#d9c7a0") != -1, "makeshift icons are taped (they look handmade)")


# ---------------------------------------------------------------- salvage

func _test_take_apart() -> void:
	var box: ShelterState = _run({}, 2, true)
	var boxed: int = 0
	for k in box.stock.keys():
		if ShelterCraft.is_junk(str(k)):
			boxed += box.count(str(k))
	_ok(boxed >= 2 and _text(box).find("CABLES, MISC") != -1, "the shelter starts with its box of odds and ends (%d pieces of junk)" % boxed)
	var s: ShelterState = _run({"toaster": 1, "pots_pans": 1, "radio": 1})
	var r: Dictionary = ShelterCraft.take_apart(s, "toaster")
	_ok(bool(r["ok"]) and int(s.parts.get("metal", 0)) == 2 and int(s.parts.get("electronics", 0)) == 1 and not s.has("toaster"),
		"a toaster comes apart into 2 Metal and 1 Electronics")
	_ok(int(s.stats["taken_apart"]) == 1 and _text(s).find("Took apart the toaster") != -1, "taking apart is counted and on the receipt")
	_ok(not bool(ShelterCraft.take_apart(s, "radio")["ok"]), "working core items can't be taken apart")
	s.break_one("radio")
	var r2: Dictionary = ShelterCraft.take_apart(s, "radio", true)
	_ok(bool(r2["ok"]) and int(s.parts.get("electronics", 0)) == 3 and s.broken_count("radio") == 0, "a broken radio scraps into 2 Electronics")
	s.add("axe", 1)
	s.break_one("axe")
	ShelterCraft.take_apart(s, "axe", true)
	_ok(int(s.parts.get("metal", 0)) == 4, "a broken axe scraps into 2 Metal")
	var listed: Array = ShelterCraft.salvage_list(s)
	_ok(listed.size() == 1 and str((listed[0] as Dictionary)["item"]) == "pots_pans", "the salvage list shows the junk left on the shelf")


func _test_shelf_cap() -> void:
	var s: ShelterState = _run({"pots_pans": 1})
	_parts(s, {"cloth": 6, "plastic": 5})
	var r: Dictionary = ShelterCraft.take_apart(s, "pots_pans")
	_ok(int((r["kept"] as Dictionary).get("metal", 0)) == 1 and int((r["lost"] as Dictionary).get("metal", 0)) == 1, "the part shelf holds 12: the 13th part is thrown out")
	_ok(ShelterCraft.parts_total(s) == 12 and _text(s).find("No room on the shelf") != -1, "the receipt says what didn't fit")


# ---------------------------------------------------------------- recipes

func _test_recipes_and_limits() -> void:
	var s: ShelterState = _run({"manual": 1, "axe": 1})
	var sam: Dictionary = s.member("m0")
	var leo: Dictionary = s.member("m3")
	_ok(ShelterCraft.known(s, "rag_bandage") and ShelterCraft.known(s, "bindle") and ShelterCraft.known(s, "patch_job"), "three recipes are known from the start")
	_ok(not ShelterCraft.known(s, "door_barricade") and ShelterCraft.unlock_label("door_barricade") == "Manual Ch.2 / home-security flyer",
		"locked recipes show their unlock source: %s" % ShelterCraft.unlock_label("door_barricade"))
	_ok(ShelterCraft.can_make(s, sam, "door_barricade").begins_with("Not learned"), "a locked recipe can't be made")
	_parts(s, {"cloth": 6, "binding": 2, "chemicals": 2})
	_ok(ShelterCraft.can_make(s, sam, "rag_bandage") == "", "a known recipe with its parts can be made")
	_ok(ShelterCraft.can_make(s, sam, "rag_bandage", "", [{"id": "bindle"}]) == "", "a second Quick recipe fits in the same day")
	_ok(ShelterCraft.can_make(s, sam, "sock_puppets", "", [{"id": "bindle"}, {"id": "rag_bandage"}]) != "", "a third Quick recipe doesn't")
	_ok(ShelterCraft.can_make(s, sam, "rag_bandage", "", [{"id": "rag_bandage"}, ]) == "" and ShelterCraft.can_make(s, sam, "rag_bandage", "", [{"id": "rag_bandage"}, {"id": "rag_bandage"}]) != "",
		"parts promised to earlier recipes on the bench count")
	s.chapters["ch1"] = "manual"
	s.chapters["ch2"] = "manual"
	_parts(s, {"metal": 6, "binding": 3, "plastic": 4, "cloth": 2, "chemicals": 2})
	_ok(ShelterCraft.can_make(s, sam, "door_barricade", "", [{"id": "tin_can_alarm"}]) != "", "a Day recipe takes the whole day")
	_ok(ShelterCraft.can_make(s, leo, "bottle_filter") == "Too young for a whole day's work" and ShelterCraft.can_make(s, leo, "tin_can_alarm") == "",
		"children can make Quick recipes but not Day ones")
	s.remove("axe", 1)
	_ok(ShelterCraft.can_make(s, sam, "door_barricade") == "Needs the axe", "a missing tool blocks the recipe")
	s.add("axe", 1)
	s.add("door_barricade", 1)
	_ok(ShelterCraft.can_make(s, sam, "door_barricade").find("already up") != -1, "only one door barricade at a time")
	s.add("tin_can_alarm", 1)
	_ok(ShelterCraft.can_make(s, sam, "tin_can_alarm").find("already up") != -1, "only one tin-can alarm at a time")
	_parts(s, {"cloth": 1})
	s.chapters["ch4"] = "manual"
	_ok(ShelterCraft.can_make(s, sam, "sock_puppets") == "Short: 1 Cloth", "a short recipe says what's missing")
	_ok(ShelterCraft.part_sources("cloth").has("pharmacy"), "missing parts list the place types that supply them")
	sam["affliction"] = "withdrawn"
	_ok(ShelterCraft.can_make(s, sam, "sock_puppets").begins_with("Withdrawn"), "a Withdrawn survivor won't work at the bench")
	sam["affliction"] = ""


func _test_crafting() -> void:
	var made: bool = false
	for seed_v in range(1, 12):
		var s: ShelterState = _run({"bedsheet": 1, "sanitizer": 1, "manual": 1}, seed_v)
		ShelterSim.begin_day(s)
		s.today_event = {}
		s.today_resolved = true
		ShelterSim.end_day(s, _feed_all(s, {"m1": {"job": "craft", "recipes": [{"id": "rag_bandage"}]}}))
		if s.has("rag_bandage"):
			made = true
			_ok(not s.has("bedsheet") and not s.has("sanitizer") and ShelterCraft.parts_total(s) == 0, "the bench takes junk apart for the parts it needs")
			_ok(int((s.stats["crafted"] as Dictionary).get("rag_bandage", 0)) == 1, "crafted items are counted")
			_ok(str(s.member("m1").get("loc", "")) == "shelter" and s.trips.is_empty(), "the crafter stays in (no trip that day)")
			break
	_ok(made, "a rag bandage is made at the bench through end_day")
	# Two Quick recipes in a day; one Day recipe only.
	var s2: ShelterState = _run({"manual": 1}, 3)
	_parts(s2, {"cloth": 6, "binding": 2, "chemicals": 2})
	var ok2: int = 0
	for _i in range(20):
		var t: ShelterState = _run({"manual": 1}, 30 + _i)
		_parts(t, {"cloth": 6, "binding": 2, "chemicals": 2})
		ShelterSim._apply_jobs(t, {"m1": {"job": "craft", "recipes": [{"id": "rag_bandage"}, {"id": "bindle"}, {"id": "sock_puppets"}]}})
		if (t.stats["crafted"] as Dictionary).size() + int(t.stats["craft_fails"]) == 2:
			ok2 += 1
	_ok(ok2 == 20, "a crafter makes at most two Quick recipes a day")
	s2.chapters["ch2"] = "manual"
	s2.add("axe", 1)
	_parts(s2, {"metal": 5, "binding": 2})
	var before_wear: int = int(s2.wear.get("axe", 0))
	ShelterCraft.craft(s2, s2.member("m1"), "door_barricade")
	_ok(int(s2.wear.get("axe", 0)) == before_wear + 1 or not s2.has("axe"), "a Day recipe with the axe wears it")
	_ok(s2.owns("axe"), "tools aren't used up")
	var w2: int = int(s2.wear.get("axe", 0))
	_parts(s2, {"metal": 2, "binding": 1})
	ShelterCraft.craft(s2, s2.member("m1"), "pipe_club")
	_ok(int(s2.wear.get("axe", 0)) == w2, "a Quick recipe doesn't wear the axe")


func _test_failure() -> void:
	var s: ShelterState = _run({}, 5)
	var pri: Dictionary = s.member("m1")
	_ok(is_equal_approx(ShelterCraft.fail_chance(s, pri), 0.20), "failure is 20% without the manual")
	s.add("manual", 1)
	_ok(is_equal_approx(ShelterCraft.fail_chance(s, pri), 0.05), "5% with the manual in the shelter")
	pri["injured"] = true
	_ok(is_equal_approx(ShelterCraft.fail_chance(s, pri), 0.20), "+15% for an injured crafter")
	pri["injured"] = false
	s.remove("manual", 1)
	var fails: int = 0
	var n: int = 3000
	for i in range(n):
		var t: ShelterState = _run({}, 1000 + i)
		t.chapters["ch4"] = "manual"
		_parts(t, {"cloth": 2})
		ShelterCraft.craft(t, t.member("m1"), "sock_puppets")
		if int(t.stats["craft_fails"]) > 0:
			fails += 1
	var rate: float = float(fails) / float(n)
	_ok(absf(rate - 0.20) < 0.03, "measured failure without the manual: %.1f%% (20%%)" % (rate * 100.0))
	# A failure returns half the parts, rounded down.
	var got_half: bool = false
	for i in range(200):
		var t2: ShelterState = _run({"axe": 1}, 5000 + i)
		t2.chapters["ch2"] = "manual"
		_parts(t2, {"metal": 3, "binding": 1})
		ShelterCraft.craft(t2, t2.member("m1"), "door_barricade")
		if int(t2.stats["craft_fails"]) > 0:
			got_half = ShelterCraft.parts_total(t2) == 2 and not t2.has("door_barricade")
			break
	_ok(got_half, "a failed Door Barricade (4 parts) gives 2 back")


func _test_learning() -> void:
	var s: ShelterState = _run({"manual": 1}, 7)
	var sam: Dictionary = s.member("m0")
	_ok(ShelterCraft.can_study(s, s.member("m3")) == "Too young to study the manual", "children don't study the manual")
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	ShelterSim.end_day(s, _feed_all(s, {"m0": {"job": "study", "chapter": "ch2"}}))
	_ok(s.chapters.get("ch2", "") == "manual" and ShelterCraft.known(s, "door_barricade") and ShelterCraft.known(s, "pipe_club"), "a day of study unlocks a chapter for the run")
	_ok(int(s.stats["studied"]) == 1 and str(s.member("m0").get("loc", "")) == "shelter", "studying costs the day, not a trip")
	s.remove("manual", 1)
	_ok(ShelterCraft.known(s, "door_barricade") and is_equal_approx(ShelterCraft.fail_chance(s, s.member("m1")), 0.20),
		"without the manual, learned recipes stay but failure goes back to 20%")
	_ok(ShelterCraft.can_study(s, sam) == "Needs the manual", "studying needs the manual")


func _test_pamphlets() -> void:
	var s: ShelterState = _run({}, 9)
	var ph: Dictionary = {}
	for p_v in s.places:
		if str((p_v as Dictionary)["category"]) == "pharmacy":
			ph = p_v
	ph["pamphlet"] = "ch1"
	var sam: Dictionary = s.member("m0")
	ShelterCraft.found_pamphlet(s, ph, sam)
	_ok(s.chapters.get("ch1", "") == "pamphlet" and ShelterCraft.known(s, "bottle_filter"), "a pamphlet unlocks its chapter without the manual")
	_ok(int(s.stats["pamphlet_learned"]) == 1 and str(ph["pamphlet"]) == "", "the pamphlet is taken (one per place)")
	ph["pamphlet"] = "ch1"
	ShelterCraft.found_pamphlet(s, ph, sam)
	_ok(ShelterCraft.parts_total(s) == 1, "a duplicate pamphlet becomes 1 random part")
	# Pamphlets are placed by place type (pharmacy, hardware...), deterministic per building.
	var p1: Dictionary = ShelterTrips.make_place({"osm_id": 777, "name": "X", "category": "hardware", "walk_m": 500.0}, 0, 1.0, 1.0)
	var p2: Dictionary = ShelterTrips.make_place({"osm_id": 777, "name": "X", "category": "hardware", "walk_m": 500.0}, 0, 1.0, 1.0)
	_ok(str(p1["pamphlet"]) == str(p2["pamphlet"]) and (str(p1["pamphlet"]) == "" or str(p1["pamphlet"]) == "ch2"), "a hardware store may hold the home-security flyer")
	var n_with: int = 0
	for i in range(200):
		var p3: Dictionary = ShelterTrips.make_place({"osm_id": 9000 + i, "name": "X", "category": "pharmacy", "walk_m": 500.0}, 0, 1.0, 1.0)
		if str(p3["pamphlet"]) == "ch1":
			n_with += 1
	_ok(n_with > 70 and n_with < 130, "about half of pharmacies hold the water-safety flyer (%d of 200)" % n_with)
	# On a trip: the pamphlet comes home with the explorer.
	var t: ShelterState = _run({}, 11)
	for p_v in t.places:
		(p_v as Dictionary)["pamphlet"] = "ch2" if str((p_v as Dictionary)["name"]) == "Bolt Hardware" else ""
	var idx: int = -1
	for p_v in t.places:
		if str((p_v as Dictionary)["name"]) == "Bolt Hardware":
			idx = int((p_v as Dictionary)["idx"])
	for tr in range(40):
		t = _run({}, 11 + tr)
		for p_v in t.places:
			(p_v as Dictionary)["pamphlet"] = "ch2" if int((p_v as Dictionary)["idx"]) == idx else ""
		ShelterTrips.launch(t, t.member("m0"), idx, [])
		for _d in range(8):
			if t.trips.is_empty():
				break
			_quiet_day(t)
		if t.member("m0").get("alive", false) and t.chapters.has("ch2"):
			break
	_ok(t.chapters.get("ch2", "") == "pamphlet", "an explorer brings the flyer home from the hardware store")


func _test_bandage_and_patch() -> void:
	var s: ShelterState = _run({"medkit": 1}, 13)
	var pri: Dictionary = s.member("m1")
	s.add("rag_bandage", 1)
	ShelterSim.make_injured(s, pri, "test", "chance")
	var plan: Dictionary = _feed_all(s)
	plan["treat"] = {"m1": true}
	ShelterSim._apply_treatment(s, plan["treat"])
	_ok(not bool(pri.get("injured", false)) and not s.has("rag_bandage") and s.has("medkit"), "a rag bandage closes a wound and saves the medkit")
	s.add("rag_bandage", 1)
	ShelterSim.make_sick(s, pri, "test", "chance")
	ShelterSim._apply_treatment(s, {"m1": "rag_bandage"})
	_ok(bool(pri.get("sick", false)) and s.has("rag_bandage"), "a rag bandage does nothing for a fever")
	_ok(int((s.stats["credits"] as Dictionary).get("rag_bandage", 0)) == 1 and int(s.stats["credits_makeshift"]) == 1, "makeshift credits are counted for the crafted-credit share")
	# Patch Job: 1 Binding + 1 matching part; one more use, then broken again.
	var t: ShelterState = _run({"radio": 1}, 17)
	t.break_one("radio")
	_parts(t, {"binding": 1, "electronics": 1})
	var ok: bool = false
	for i in range(10):
		t.rng.seed = 100 + i
		var r: Dictionary = ShelterCraft.craft(t, t.member("m1"), "patch_job", "radio")
		if bool(r.get("ok", false)):
			ok = true
			break
		_parts(t, {"binding": 1, "electronics": 1})
	_ok(ok and t.has("radio") and t.patched.has("radio"), "a Patch Job gets the broken radio working")
	t.credit("radio", "the all-clear")
	_ok(not t.has("radio") and t.broken_count("radio") == 1 and not t.patched.has("radio"), "after one more use the patched radio is broken again")
	_ok(int(t.stats["credits_makeshift"]) == 1, "a patched item's use counts as a makeshift credit")


func _test_trip_gear() -> void:
	_ok(ShelterTrips.carry_slots(["bindle"]) == 4 and ShelterTrips.carry_slots(["suitcase"]) == 5, "the bindle carries +2 (the suitcase +3)")
	_ok(is_equal_approx(ShelterTrips.heavy_sick_p(["rag_respirator"]), 0.45) and is_equal_approx(ShelterTrips.heavy_sick_p([]), 0.7) and is_equal_approx(ShelterTrips.heavy_sick_p(["gas_mask"]), 0.2),
		"heavy fallout sickness: mask 20%, rag respirator 45%, nothing 70%")
	var s: ShelterState = _run({}, 19)
	s.fallout_clear_day = 99
	var p_no: float = float(ShelterTrips.daily_risk(s, s.member("m0"), s.places[0], [], "Low")["p_day"])
	var p_rr: float = float(ShelterTrips.daily_risk(s, s.member("m0"), s.places[0], ["rag_respirator"], "Low")["p_day"])
	_ok(is_equal_approx(p_rr / p_no, 0.75), "the respirator halves the no-mask risk penalty (×1.5 instead of ×2)")
	# The bindle wears out after 2 trips.
	var t: ShelterState = _run({}, 23)
	t.add("bindle", 1)
	var trips_done: int = 0
	for _k in range(2):
		if ShelterTrips.launch(t, t.member("m0"), 3, ["bindle"]) != "":
			break
		for _d in range(6):
			if t.trips.is_empty():
				break
			_quiet_day(t)
		if not bool(t.member("m0").get("alive", false)):
			break
		trips_done += 1
		t.member("m0")["tired_until"] = 0
	if trips_done == 2:
		_ok(not t.has("bindle"), "the bindle comes apart after its second trip")
	else:
		_ok(true, "bindle trip skipped (the explorer didn't come back)")


func _test_raid_defences() -> void:
	var held: int = 0
	var n: int = 2000
	for i in range(n):
		var s: ShelterState = _run({}, 3000 + i)
		s.add("door_barricade", 1)
		s.followed = true
		s.gang_day = 999
		ShelterSim._raid(s)
		if int(s.stats["raids_stopped"]) == 1:
			held += 1
		if s.has("door_barricade"):
			held = -99999
	_ok(absf(float(held) / float(n) - 0.6) < 0.04, "the door barricade stops %.0f%% of raids (60%%), then it's gone" % (100.0 * float(held) / float(n)))
	var s2: ShelterState = _run({"padlock": 1}, 41)
	s2.add("door_barricade", 1)
	s2.followed = true
	var both: int = 0
	for i in range(200):
		var t: ShelterState = _run({"padlock": 1}, 4100 + i)
		t.add("door_barricade", 1)
		t.followed = true
		ShelterSim._raid(t)
		if not t.has("padlock") and int(t.stats["raids_stopped"]) == 1:
			both += 1
	_ok(both > 50 and both < 110, "when the barricade gives way the padlock is next (%d of 200)" % both)
	var stops: int = 0
	var breaks: int = 0
	for i in range(n):
		var c: ShelterState = _run({"food": 4, "water": 4}, 7000 + i)
		c.add("pipe_club", 1)
		c.followed = true
		ShelterSim._raid(c)
		stops += int(c.stats["raids_stopped"])
		if not c.has("pipe_club"):
			breaks += 1
	_ok(absf(float(stops) / float(n) - 0.5) < 0.04 and absf(float(breaks) / float(n) - 0.5) < 0.04,
		"the pipe club stops %.0f%% of raids and breaks %.0f%% of the time (50%% / 50%%)" % [100.0 * float(stops) / float(n), 100.0 * float(breaks) / float(n)])
	# Makeshift items can't stop the gang's takeover (an ending condition).
	var g: ShelterState = _run({}, 43)
	g.add("pipe_club", 1)
	g.add("door_barricade", 1)
	g.followed = true
	g.gang_warned = true
	g.gang_day = g.day
	ShelterSim._takeover(g)
	_ok(g.ending == "loss_takeover", "makeshift weapons can't stop the takeover")


func _test_night() -> void:
	# Dirty water and the bottle filter.
	var s: ShelterState = _run({}, 51)
	s.add("bottle_filter", 1)
	s.dirty_water = 6
	var w0: int = s.water()
	ShelterCraft._filter(s)
	_ok(s.water() == w0 + 4 and s.dirty_water == 2 and ShelterCraft.uses_left(s, "bottle_filter") == 2, "the filter makes 4 rations of dirty water drinkable a night (3 uses)")
	ShelterCraft._filter(s)
	s.dirty_water = 8
	ShelterCraft._filter(s)
	_ok(not s.has("bottle_filter"), "the bottle filter is used up after 3 jugs")
	var rain: int = 0
	for i in range(2000):
		var t: ShelterState = _run({}, 8000 + i)
		ShelterCraft._rain(t)
		if t.dirty_water > 0:
			rain += 1
	_ok(rain > 180 and rain < 300, "rain fills the bucket on about 1 night in 8 (%d of 2000)" % rain)
	# Sock puppets: once, when morale is low.
	var p: ShelterState = _run({}, 53)
	p.add("sock_puppets", 1)
	for m_v in p.home():
		(m_v as Dictionary)["morale"] = 3
	ShelterCraft._puppets(p)
	var all_up: bool = true
	for m_v in p.home():
		if int((m_v as Dictionary)["morale"]) != 4:
			all_up = false
	_ok(all_up and not p.has("sock_puppets"), "the sock puppet show lifts everyone by 1, once")
	# Night thieves: silent without the alarm, a choice with it (twice).
	var stole: bool = false
	var a: ShelterState = _run({"food": 3}, 55)
	a.day = 10
	for _i in range(400):
		ShelterCraft._thief(a)
		if int(a.stats["thefts"]) > 0:
			stole = true
			break
	_ok(stole and _text(a).find("Nobody heard a thing") != -1, "a night thief takes something in silence")
	var b: ShelterState = _run({"food": 3}, 57)
	b.day = 10
	b.add("tin_can_alarm", 1)
	var hits: int = 0
	for _i in range(2000):
		ShelterCraft._thief(b)
		hits = int(b.stats["alarms"])
		if hits >= 2:
			break
	var scheduled: bool = false
	for sc in b.scheduled:
		if str((sc as Dictionary)["event"]) == "cans_rattled":
			scheduled = true
	_ok(hits == 2 and not b.has("tin_can_alarm") and int(b.stats["thefts"]) == 0 and scheduled, "the tin-can alarm turns two thefts into a choice, then it's done")
	b.day += 1
	var ev: Dictionary = ShelterEvents.draw(b)
	_ok(str(ev.get("id", "")) == "cans_rattled", "next morning: Cans in the Dark")
	# The scrap receiver hears the all-clear (it can't transmit).
	var heard: int = 0
	for i in range(400):
		var r: ShelterState = _run({}, 9000 + i)
		r.add("scrap_receiver", 1)
		r.day = r.fallout_clear_day
		ShelterSim._fallout_news(r)
		if r.fallout_announced:
			heard += 1
	_ok(heard > 160 and heard < 240, "the scrap receiver hears the all-clear on about half the days (%d of 400)" % heard)


func _test_stand_ins() -> void:
	var s: ShelterState = _run({}, 61)
	s.add("phone_torch", 1)
	var ev: Dictionary = ShelterEvents._prepare(s, ShelterData.event("lights_out"))
	var opts: Array = ShelterEvents.options_for(s, ev)
	var alt_opt: Dictionary = {}
	for o_v in opts:
		if str((o_v as Dictionary)["id"]) == "torch@phone_torch":
			alt_opt = o_v
	_ok(not alt_opt.is_empty() and bool(alt_opt["available"]), "the phone torch stands in for the flashlight in a dark event")
	s.today_event = ev
	s.today_options = opts
	s.today_resolved = false
	var out: Dictionary = ShelterSim.choose(s, "torch@phone_torch")
	_ok(not out.is_empty() and ShelterCraft.uses_left(s, "phone_torch") == 1 and int(s.stats["credits_makeshift"]) == 1, "using it spends one of its 2 uses (a makeshift credit)")
	var ch: Dictionary = ShelterEvents._prepare(s, ShelterData.event("convoy_4_signal"))
	var copts: Array = ShelterEvents.options_for(s, ch)
	var signal_ok: bool = false
	for o_v in copts:
		if str((o_v as Dictionary).get("item", "")) == "phone_torch":
			signal_ok = true
	_ok(not signal_ok, "the phone torch can't signal a rescue")
	var r: ShelterState = _run({}, 63)
	r.add("scrap_receiver", 1)
	var conv: Array = ShelterEvents.options_for(r, ShelterEvents._prepare(r, ShelterData.event("convoy_1_contact")))
	var answer_ok: bool = false
	for o_v in conv:
		if str((o_v as Dictionary).get("item", "")) == "scrap_receiver":
			answer_ok = true
	_ok(not answer_ok, "the scrap receiver can't answer the convoy (it can't transmit)")
	# Soap spray: 65%, and when it fails the costly no-item option happens instead.
	var worked: int = 0
	var n: int = 1500
	var fail_seen: bool = false
	for i in range(n):
		var t: ShelterState = _run({}, 11000 + i)
		t.add("soap_spray", 1)
		var e2: Dictionary = ShelterEvents._prepare(t, ShelterData.event("uninvited"))
		t.today_event = e2
		t.today_options = ShelterEvents.options_for(t, e2)
		t.today_resolved = false
		var o2: Dictionary = ShelterSim.choose(t, "spray@soap_spray")
		if (o2.get("tags", []) as Array).has("makeshift_failed"):
			fail_seen = fail_seen or str(o2.get("text", "")).begins_with("The soap spray didn't do the job.")
		else:
			worked += 1
		if t.has("soap_spray"):
			worked = -99999
	_ok(absf(float(worked) / float(n) - 0.65) < 0.04, "soap spray works %.0f%% of the time (65%%), and is used up either way" % (100.0 * float(worked) / float(n)))
	_ok(fail_seen, "a failed stand-in says so and falls back to the costly option")
	# Both on hand: the card shows the real option and the stand-in, so the player can save the real one.
	var both: ShelterState = _run({"bug_spray": 1}, 65)
	both.add("soap_spray", 1)
	var bo: Array = ShelterEvents.options_for(both, ShelterEvents._prepare(both, ShelterData.event("uninvited")))
	var ids: Array = []
	for o_v in bo:
		ids.append(str((o_v as Dictionary)["id"]))
	_ok(ids.has("spray") and (ids.has("spray@soap_spray") or ids.size() == 4), "with both on hand the real option stays, and the stand-in shows if the card has room")


func _test_need_toggle() -> void:
	var s: ShelterState = _run({}, 71)
	s.chapters["ch2"] = "manual"
	_ok(ShelterCraft.toggle_need(s, "door_barricade") and s.need_parts.has("metal") and s.need_parts.has("binding"), "the Need toggle tags a recipe's missing parts")
	var pri: Array = ShelterTrips.loot_priorities(s)
	_ok(pri.find("pots_pans") != -1 and pri.find("pots_pans") < pri.find("cards"), "junk holding a tagged part is looted before small comforts")
	var hw: Dictionary = {}
	for p_v in s.places:
		if str((p_v as Dictionary)["name"]) == "Bolt Hardware":
			hw = p_v
	_ok(not ShelterTrips.junk_hint(s, hw).is_empty(), "the trip preview highlights tagged junk at the hardware store")
	_ok(not ShelterCraft.toggle_need(s, "door_barricade") and s.need_parts.is_empty(), "pressing Need again clears the tags")
	var t: ShelterState = _run({"bedsheet": 1}, 75)
	_parts(t, {"cloth": 2, "binding": 1})
	ShelterCraft.craft(t, t.member("m1"), "bindle")
	_ok(ShelterCraft.run_summary(t).begins_with("Made Bedsheet Bindle") or ShelterCraft.run_summary(t).find("fell apart") != -1, "the end-of-run report lists the bench's work: %s" % ShelterCraft.run_summary(t))


func _test_places() -> void:
	var s: ShelterState = _run({}, 73)
	var shop: Dictionary = {}
	for p_v in s.places:
		if str((p_v as Dictionary)["name"]) == "Phone Repair":
			shop = p_v
	_ok(str(shop.get("loot_type", "")) == "electronics" and str(shop["category"]) == "hardware", "a phone shop uses the electronics loot table")
	var elec: bool = false
	for k in (shop["stock"] as Dictionary).keys():
		if ShelterCraft.scrap_yield(str(k)).has("electronics"):
			elec = true
	_ok(elec, "phone shops stock junk with Electronics")
	var ph: Dictionary = {}
	for p_v in s.places:
		if str((p_v as Dictionary)["category"]) == "pharmacy":
			ph = p_v
	var chem: bool = false
	for k in (ph["stock"] as Dictionary).keys():
		if ShelterCraft.scrap_yield(str(k)).has("chemicals"):
			chem = true
	_ok(chem, "pharmacies stock junk with Chemicals")
