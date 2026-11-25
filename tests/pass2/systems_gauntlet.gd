extends Node

## Systems gauntlet for the pass-2 changes (no rendering needed).
## Run: godot --headless --path . -s res://tests/pass2/run.gd -- --suite=systems_gauntlet

var _passes: int = 0
var _fails: Array[String] = []
var _report: Dictionary = {}


func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] ", label)
	else:
		_fails.append(label)
		print("[FAIL] ", label)


func _setup_preset(pid: String) -> Dictionary:
	var parsed: Dictionary = OsmService.load_preset(pid)
	var house: Dictionary = OsmService.pick_best_house(parsed["buildings"], float(parsed["center_lat"]), float(parsed["center_lon"]), int(parsed["preferred_osm_id"]))
	var meta: Dictionary = {"roads": parsed["roads"], "parks": parsed["parks"], "bounds": parsed.get("bounds", {}), "source": parsed["source"], "place_names": parsed["place_names"], "landmarks": parsed["landmarks"]}
	GameState.selected_house = house.duplicate(true)
	GameState.nearby_pois = OsmService.build_nearby_targets_for_house(house, parsed["buildings"], parsed["pois"], parsed["roads"])
	HouseSelectScreen.store_map_context(house, parsed["buildings"], meta, [])
	var tgt: Dictionary = NukePhysics.pick_local_target(float(house["lat"]), float(house["lon"]), GameState.map_landmarks)
	var wind: float = NukePhysics.bearing_deg(float(tgt["lat"]), float(tgt["lon"]), float(house["lat"]), float(house["lon"]))
	GameState.nuke_config = NukePhysics.compute_impact(float(house["lat"]), float(house["lon"]), float(tgt["lat"]), float(tgt["lon"]), 250, wind, str(tgt["target_name"]))
	return parsed


func _start_run() -> void:
	# M1: the shelter is a ShelterState built from the grab haul (rations are whole cans/bottles).
	GameState.reset_to_defaults()
	GameState.init_default_family()
	for m in GameState.family_members:
		m["in_bunker"] = true
		m["alive"] = true
	GameState.add_scavenged_item("food", 10)
	GameState.add_scavenged_item("water", 12)
	BunkerSim.start_bunker_run()

func run() -> int:
	GameState.rng.seed = 777
	_test_location_honesty()
	_test_osm_verification()
	_test_finite_loot()
	_test_actor_succession()
	_test_radiation_units_and_decay()
	_test_vehicle_and_endings()
	_test_health_links()
	_test_long_runs()
	print("SYSTEMS_GAUNTLET passes=%d fails=%d" % [_passes, _fails.size()])
	for f in _fails:
		print("  FAIL: ", f)
	var out := FileAccess.open("user://systems_gauntlet.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify({"passes": _passes, "fails": _fails, "report": _report}, "  "))
	return 0 if _fails.is_empty() else 1


# ------------------------------------------------------------------------------
func _test_location_honesty() -> void:
	print("\n--- location honesty ---")
	var bad_names: Array[String] = []
	for pid in ["seattle", "concord", "brooklyn"]:
		var parsed: Dictionary = _setup_preset(pid)
		for b in parsed["buildings"]:
			var sa: String = str(b.get("short_address", ""))
			if sa.find("#") != -1:
				bad_names.append(sa)
		for p in GameState.nearby_pois:
			var nm: String = str(p.get("name", ""))
			if nm.find("#") != -1 or nm.begins_with("Local "):
				bad_names.append(nm)
		# Event text: run 25 events and look for the full postal address / postcode / country
		_start_run()
		var full: String = LocationText.full_address()
		var pc: String = str(GameState.place_names.get("postcode", ""))
		var leaks: int = 0
		var mentions_home: int = 0
		var sh: ShelterState = GameState.shelter
		for i in range(40):
			ShelterSim.begin_day(sh)
			var ev: Dictionary = sh.today_event
			var txt: String = str(ev.get("setup", "")) + " " + str(ev.get("title", ""))
			for o_v in sh.today_options:
				txt += " " + str((o_v as Dictionary).get("label", ""))
			for pl in sh.places:
				txt += " " + ShelterTrips.place_label(pl as Dictionary)
			if not ev.is_empty():
				var oc: Dictionary = ShelterSim.choose(sh, str((sh.today_options[0] as Dictionary)["id"]) if bool((sh.today_options[0] as Dictionary)["available"]) else str((sh.today_options[sh.today_options.size() - 1] as Dictionary)["id"]))
				txt += " " + str(oc.get("text", ""))
			if sh.is_over():
				break
			ShelterSim.end_day(sh, SimPolicies.make_plan(sh, "expert", GameState.rng))
			if (not pc.is_empty() and txt.find(pc) != -1) or txt.find(", WA") != -1 or txt.find("USA") != -1 or txt.find(full) != -1:
				leaks += 1
			if txt.find("house") != -1 or txt.find("hatch") != -1 or txt.find("home") != -1:
				mentions_home += 1
		_ok(leaks == 0, "%s: no full address/postcode/country in 40 event texts (leaks=%d)" % [pid, leaks])
		_ok(mentions_home > 0, "%s: events still refer to home naturally (%d mentions)" % [pid, mentions_home])
		_ok(LocationText.full_address().find(str(GameState.selected_house.get("street", "~"))) != -1, "%s: exact address kept for property info: %s" % [pid, LocationText.full_address()])
	_ok(bad_names.is_empty(), "no fake numbered names/addresses (found %d: %s)" % [bad_names.size(), str(bad_names.slice(0, 4))])
	# Unmapped: fictional homestead, no businesses
	var empty: Dictionary = OsmService.parse_osm_json({"elements": []}, 44.0, -100.0)
	_ok((empty["pois"] as Array).is_empty(), "unmapped area invents no businesses")
	_ok((empty["buildings"] as Array).size() == 1 and bool(empty["buildings"][0].get("fictional", false)) and str(empty["buildings"][0]["name"]).find("Fictional") != -1, "unmapped area offers one clearly-labelled fictional homestead")
	var ft: Array = ExpeditionEngine._fictional_targets({"lat": 44.0, "lon": -100.0})
	var all_labelled: bool = true
	for t in ft:
		all_labelled = all_labelled and str(t["name"]).find("(fictional)") != -1 and bool(t.get("fictional", false))
	_ok(all_labelled, "fictional expedition targets are labelled fictional")
	# Strike targets
	_setup_preset("seattle")
	var lt: Dictionary = NukePhysics.pick_local_target(float(GameState.selected_house["lat"]), float(GameState.selected_house["lon"]), GameState.map_landmarks)
	_ok(str(lt["target_name"]).find("Downtown") == -1 and str(lt.get("source", "")).find("OSM node") != -1, "local strike uses a sourced landmark: %s [%s]" % [lt["target_name"], lt.get("source", "")])
	GameState.map_landmarks = []
	var lt2: Dictionary = NukePhysics.pick_local_target(float(GameState.selected_house["lat"]), float(GameState.selected_house["lon"]), GameState.map_landmarks)
	_ok(str(lt2["target_name"]).find("of home") != -1, "without landmarks the strike target is an honest offset: %s" % lt2["target_name"])


func _test_osm_verification() -> void:
	print("\n--- OSM id / coordinate / tag verification against raw data ---")
	for pid in ["seattle", "concord", "brooklyn"]:
		var cfg: Dictionary = OsmService.PRESET_CONFIGS[pid]
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(cfg["path"])))
		var nodes: Dictionary = {}
		var ways: Dictionary = {}
		for e in raw["elements"]:
			if str(e["type"]) == "node":
				nodes[int(e["id"])] = e
			elif str(e["type"]) == "way":
				ways[int(e["id"])] = e
		_setup_preset(pid)
		var checked: int = 0
		var bad: Array[String] = []
		for p in GameState.nearby_pois:
			var oid: int = int(p["osm_id"])
			var typ: String = str(p.get("osm_type", ""))
			var elem: Dictionary = nodes.get(oid, {}) if typ == "node" else ways.get(oid, {})
			if elem.is_empty():
				bad.append("%s %d missing" % [typ, oid])
				continue
			var tags: Dictionary = elem.get("tags", {})
			if typ == "node":
				var d_m: float = OsmService.distance_and_bearing(float(elem["lat"]), float(elem["lon"]), float(p["lat"]), float(p["lon"]))["distance_m"]
				if d_m > 1.0:
					bad.append("node %d off by %.1fm" % [oid, d_m])
			if bool(p.get("named", false)) and str(p["category"]) != "neighbor_house" and str(tags.get("name", "")) != str(p["name"]):
				bad.append("name mismatch %d '%s' vs '%s'" % [oid, p["name"], tags.get("name", "")])
			var tag_str: String = str(p.get("osm_tag", ""))
			if tag_str != "" and tag_str.find("=") != -1 and str(p["category"]) != "neighbor_house":
				var kv: PackedStringArray = tag_str.split("=")
				if str(tags.get(kv[0], "")).find(kv[1]) == -1:
					bad.append("tag %s not on %d" % [tag_str, oid])
			checked += 1
		_ok(bad.is_empty() and checked >= 10, "%s: %d nearby places match raw OSM ids/coords/names/tags (%s)" % [pid, checked, str(bad.slice(0, 3))])
		var net_count: int = 0
		for p2 in GameState.nearby_pois:
			if str(p2.get("walk_source", "")) == "network":
				net_count += 1
			_ok(int(p2.get("walk_m", 0)) >= int(p2.get("distance_m", 0)) - 1, "%s: walk >= straight for %s" % [pid, p2["name"]])
		_ok(net_count >= GameState.nearby_pois.size() * 0.7, "%s: %d/%d walking distances come from the real path network" % [pid, net_count, GameState.nearby_pois.size()])


func _test_finite_loot() -> void:
	print("\n--- finite loot (M1: ShelterTrips + the run's place stock) ---")
	_setup_preset("concord")
	_start_run()
	var s: ShelterState = GameState.shelter
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var place: Dictionary = {}
	for p in s.places:
		if str((p as Dictionary)["category"]) == "grocery":
			place = p
			break
	_ok(not place.is_empty(), "the Concord preset has a real grocery among the expedition targets")
	var hauls: Array[int] = []
	for i in range(30):
		var t: Dictionary = ShelterTrips.raid_stock(s, place, 5, 0.8)
		var n: int = 0
		for v in t.values():
			n += int(v)
		hauls.append(n)
	print("  successive searches at %s: %s" % [place.get("name", ""), str(hauls)])
	var last_nonzero: int = -1
	for i2 in range(hauls.size()):
		if hauls[i2] > 0:
			last_nonzero = i2
	_ok(hauls[0] > 0 and last_nonzero < hauls.size() - 5 and ShelterTrips.stock_total(place) == 0, "searches eventually yield nothing, forever (last find on search %d of %d)" % [last_nonzero + 1, hauls.size()])
	var tot_first3: int = hauls[0] + hauls[1] + hauls[2]
	var tot_last3: int = hauls[27] + hauls[28] + hauls[29]
	_ok(tot_last3 < tot_first3, "later searches yield less than early ones (%d vs %d)" % [tot_first3, tot_last3])
	_ok(ShelterTrips.stock_total(place) < 3, "stock nearly/fully exhausted (left %d)" % ShelterTrips.stock_total(place))
	var poi: Dictionary = GameState.nearby_pois[int(place["idx"])]
	_ok(LootInventory.remaining_total(poi) == ShelterTrips.stock_total(place), "the map's stock readout is the run's stock (no respawn on refresh)")
	ExpeditionEngine.get_available_targets()
	_ok(LootInventory.remaining_total(GameState.nearby_pois[int(place["idx"])]) == ShelterTrips.stock_total(place), "inventory persists across target refresh")
	var a: Dictionary = ShelterTrips.generate_stock(place, 1.0)
	var b: Dictionary = ShelterTrips.generate_stock(place, 1.0)
	_ok(JSON.stringify(a) == JSON.stringify(b), "stock is deterministic per OSM id")
	# A full trip to the emptied store brings nothing back.
	var m: Dictionary = s.home()[1]
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	ShelterSim.end_day(s, {"rations": {}, "treat": {}, "jobs": {str(m["id"]): {"job": "trip", "place": int(place["idx"]), "gear": []}}})
	var guard: int = 0
	while str(m.get("loc", "")) == "away" and guard < 10:
		ShelterSim.begin_day(s)
		s.today_event = {}
		s.today_resolved = true
		ShelterSim.end_day(s, {"rations": {}, "treat": {}, "jobs": {}})
		guard += 1
	var back_line: String = ""
	for l_v in s.receipt:
		if str((l_v as Dictionary).get("kind", "")) == "return":
			back_line = str((l_v as Dictionary)["text"])
	_ok(not bool(m.get("alive", true)) or back_line.ends_with("with nothing."), "a trip to an emptied store returns nothing: %s" % back_line)

func _test_actor_succession() -> void:
	print("\n--- actor succession ---")
	_setup_preset("seattle")
	_start_run()
	var s: ShelterState = GameState.shelter
	var fam: Array = GameState.family_members
	var leader: Dictionary = fam[0]
	_ok(str(EventDeck.pick_actor().get("id", "")) == str(leader["id"]), "capable leader acts")
	leader["loc"] = "away"
	var a2: Dictionary = EventDeck.pick_actor()
	_ok(str(a2.get("name", "")) == "Priya", "leader away -> oldest able survivor acts (%s)" % a2.get("name", ""))
	leader["loc"] = "shelter"
	leader["morale"] = 0
	leader["affliction"] = "withdrawn"   # M2: Withdrawn is an affliction that follows morale 0 and a warning
	_ok(str(EventDeck.pick_actor().get("name", "")) == "Priya", "leader withdrawn -> oldest able survivor acts")
	leader["affliction"] = ""
	leader["morale"] = 7
	fam[1]["alive"] = false
	fam[1]["loc"] = "dead"
	leader["alive"] = false
	leader["loc"] = "dead"
	var a3: Dictionary = EventDeck.pick_actor()
	_ok(str(a3.get("name", "")) == "Maya", "leader & oldest dead -> next oldest able (teen) acts: %s" % a3.get("name", ""))
	# Outcomes never name the dead.
	var bad: int = 0
	for i in range(40):
		ShelterSim.begin_day(s)
		if s.is_over():
			break
		if not s.today_event.is_empty():
			var pick: String = ""
			for o_v in s.today_options:
				if bool((o_v as Dictionary)["available"]):
					pick = str((o_v as Dictionary)["id"])
			var res: Dictionary = ShelterSim.choose(s, pick)
			var txt: String = str(res.get("text", ""))
			for nm in ["Sam", "Priya"]:
				if txt.find(nm) != -1:
					bad += 1
			if str(s.member(str(res.get("actor_id", ""))).get("name", "")) in ["Sam", "Priya"]:
				bad += 1
		if s.is_over():
			break
		ShelterSim.end_day(s, SimPolicies.make_plan(s, "expert", GameState.rng))
	_ok(bad == 0, "no outcome attributes actions to dead characters (%d violations)" % bad)

func _test_radiation_units_and_decay() -> void:
	print("\n--- radiation ---")
	_setup_preset("seattle")
	_start_run()
	var h_lat: float = float(GameState.selected_house["lat"])
	var h_lon: float = float(GameState.selected_house["lon"])
	var r1: float = RadiationModel.dose_rate_msv_h(h_lat, h_lon, 1.0, 1)
	var r7: float = RadiationModel.dose_rate_msv_h(h_lat, h_lon, 7.0, 1)
	var r49: float = RadiationModel.dose_rate_msv_h(h_lat, h_lon, 49.0, 3)
	print("  H+1 %s, H+7 %s, H+49 %s" % [RadiationModel.format_rate(r1), RadiationModel.format_rate(r7), RadiationModel.format_rate(r49)])
	_ok(absf(r7 / r1 - 0.097) < 0.02 and absf(r49 / r1 - 0.0094) < 0.003, "7-10 rule holds (x7 time -> ~1/10 rate)")
	var integral: float = RadiationModel.decay_integral(1.0, 25.0)
	var numeric: float = 0.0
	for k in range(2400):
		var t: float = 1.0 + (float(k) + 0.5) * 0.01
		numeric += pow(t, -1.2) * 0.01
	_ok(absf(integral - numeric) / numeric < 0.01, "exact decay integral matches numeric (%.4f vs %.4f)" % [integral, numeric])
	# location factor: downwind vs upwind
	var dw: float = LocationText.downwind_bearing()
	var p_dw: Dictionary = NukePhysics.destination_point(h_lat, h_lon, dw, 1.5)
	var p_uw: Dictionary = NukePhysics.destination_point(h_lat, h_lon, dw + 180.0, 1.5)
	var p_cw: Dictionary = NukePhysics.destination_point(h_lat, h_lon, dw + 90.0, 1.5)
	var f_dw: float = RadiationModel.location_factor(float(p_dw["lat"]), float(p_dw["lon"]))
	var f_uw: float = RadiationModel.location_factor(float(p_uw["lat"]), float(p_uw["lon"]))
	var f_cw: float = RadiationModel.location_factor(float(p_cw["lat"]), float(p_cw["lon"]))
	print("  location factors: downwind %.2f, crosswind %.2f, upwind %.2f" % [f_dw, f_cw, f_uw])
	_ok(f_uw > f_cw * 0.6 and f_cw < 1.0, "crosswind places get less fallout than home on the plume axis")
	# daily decline then localized return
	var readings: Array[float] = []
	for d in range(2, 9):
		GameState.day = d
		RadiationModel.tick_day(d)
		readings.append(GameState.surface_radiation_sv)
	var declining: bool = true
	for i in range(1, readings.size()):
		declining = declining and readings[i] < readings[i - 1]
	_ok(declining, "outdoor rate declines every day after fallout")
	var before: float = readings[readings.size() - 1]
	RadiationModel.add_hotspot(h_lat, h_lon, 400.0, 2.4, 5.0, "rain")
	GameState.day = 9
	RadiationModel.tick_day(9)
	_ok(GameState.surface_radiation_sv > before, "rain-out hotspot makes home hotter again (%s -> %s)" % [RadiationModel.format_rate(before * 1000.0), RadiationModel.format_rate(GameState.surface_radiation_sv * 1000.0)])
	var far: Dictionary = NukePhysics.destination_point(h_lat, h_lon, 0.0, 2.0)
	_ok(RadiationModel.hotspot_multiplier(float(far["lat"]), float(far["lon"]), 9) < 1.05, "hotspot is localized (2 km away unaffected)")
	RadiationModel.add_strike(float(far["lat"]), float(far["lon"]), RadiationModel.h1_home_msv() * 0.3)
	var r_before_strike: float = RadiationModel.dose_rate_msv_h(h_lat, h_lon, RadiationModel.hours_since_detonation(9) - 2.0, 9)
	var r_after_strike: float = RadiationModel.dose_rate_msv_h(h_lat, h_lon, RadiationModel.hours_since_detonation(9) + 12.0, 9)
	_ok(r_after_strike > r_before_strike, "an additional strike adds fresh fallout")
	# labels are monotonic & consistent with units
	var labels: Array = []
	for rate in [0.001, 0.05, 0.5, 5.0, 50.0, 500.0, 5000.0]:
		labels.append(RadiationModel.risk_short(rate))
	_ok(labels == ["LOW", "LOW", "ELEVATED", "HIGH", "VERY HIGH", "SEVERE", "LETHAL"], "risk labels ordered by dose rate: %s" % str(labels))
	_ok(RadiationModel.ars_stage(200.0) == 0 and RadiationModel.ars_stage(1500.0) == 2 and RadiationModel.ars_stage(4500.0) == 4, "ARS stages match standard dose thresholds")
	# per-location exposure tracked per member
	var m: Dictionary = GameState.family_members[0]
	var before_d: float = float(m.get("dose_msv", 0.0))
	RadiationModel.add_dose(m, 120.0, GameState.day)
	_ok(float(m["dose_msv"]) - before_d == 120.0 and float(m["dose_recent_msv"]) >= 120.0, "cumulative and 7-day dose tracked per survivor")
	_report["radiation_home_h1_msv"] = r1


func _test_vehicle_and_endings() -> void:
	print("\n--- vehicle (disabled feature) & location-driven routes ---")
	_ok(not GameState.FEATURE_CAR_ESCAPE, "the car escape sits behind a disabled feature flag (section 4)")
	VehicleSystem.init_for_run()
	_ok(GameState.vehicle.is_empty() and not VehicleSystem.route_available(), "with the flag off, a run has no car and no drive-out route")
	VehicleSystem.test_override = true
	var routes: Dictionary = {}
	for pid in ["seattle", "concord", "brooklyn"]:
		_setup_preset(pid)
		_start_run()
		VehicleSystem.init_for_run()
		var missing: Array = VehicleSystem.missing_parts()
		var sources: Dictionary = {}
		for part in ["car_battery", "fuel_can", "spark_plugs", "fan_belt", "tire_patch"]:
			sources[part] = VehicleSystem.part_sources(part).size()
		var cats: Dictionary = {}
		for p in GameState.nearby_pois:
			cats[str(p["category"])] = true
		routes[pid] = {"neighbourhood_rescue": EventDeck.has_real_poi(["church", "school"]), "missing": missing, "part_sources": sources}
		print("  %s: %s" % [pid, JSON.stringify(routes[pid])])
		_ok(not missing.is_empty() and missing.has("car_battery"), "%s: the (disabled) car still starts broken" % pid)
	_report["routes"] = routes
	_setup_preset("seattle")
	_start_run()
	VehicleSystem.init_for_run()
	GameState.vehicle["wrecked"] = false
	_ok(not VehicleSystem.can_install("car_battery")["ok"], "cannot install a battery that is not in storage")
	GameState.add_scavenged_item("car_battery", 1)
	_ok(int(GameState.parts["car_battery"]) == 1, "a recovered battery goes into storage")
	_ok(not bool(GameState.vehicle["battery_installed"]), "battery is NOT auto-installed")
	var res: Dictionary = VehicleSystem.install("car_battery")
	_ok(bool(res["ok"]) and bool(GameState.vehicle["battery_installed"]), "manual install moves the battery into the car: %s" % str(res.get("text", "")))
	var plan_e: Dictionary = VehicleSystem.escape_plan()
	var hl: float = float(GameState.selected_house["lat"])
	var ho: float = float(GameState.selected_house["lon"])
	var to_gz_e: float = NukePhysics.bearing_deg(hl, ho, float(GameState.nuke_config["lat"]), float(GameState.nuke_config["lon"]))
	var cross_e: float = absf(NukePhysics.angle_diff_deg(float(plan_e["bearing"]), LocationText.downwind_bearing()))
	var away_e: float = absf(NukePhysics.angle_diff_deg(float(plan_e["bearing"]), to_gz_e))
	_ok(absf(cross_e - 90.0) < 1.0 and away_e >= 90.0, "the escape plan still heads crosswind and away from ground zero (%s)" % str(plan_e["dir_word"]))
	GameState.vehicle["wrecked"] = true
	_ok(not VehicleSystem.route_available(), "wrecked car -> vehicle route unavailable")
	VehicleSystem.test_override = false
	# The neighbourhood rescue needs a real church or school; the convoy and airlift never do.
	_setup_preset("seattle")
	_start_run()
	var s: ShelterState = GameState.shelter
	var community: int = 0
	for p2 in s.places:
		if str((p2 as Dictionary)["category"]) in ["church", "school"]:
			(p2 as Dictionary)["category"] = "neighbor_house"
	for d in range(60):
		s.day = 10 + d
		ShelterChains.tick(s)
		if str((s.chains["neighbourhood"] as Dictionary)["state"]) != "idle":
			community += 1
	_ok(community == 0, "no neighbourhood rescue without a real church/school")
	_ok(str((s.chains["convoy"] as Dictionary)["state"]) == "active" and str((s.chains["airlift"] as Dictionary)["state"]) == "active", "convoy and airlift rescues remain (no softlock)")

func _test_health_links() -> void:
	print("\n--- health links ---")
	_setup_preset("brooklyn")
	var sick_from_thirst: int = 0
	for trial in range(40):
		_start_run()
		var s: ShelterState = GameState.shelter
		s.rng.seed = 5000 + trial
		s.temp_c = 19.0   # no blast heat: this measures dehydration alone
		var m: Dictionary = s.members[1]
		m["dww"] = 3
		ShelterSim.begin_day(s)
		s.today_event = {}
		s.today_resolved = true
		var r: Dictionary = {}
		for mm in s.home():
			r[str(mm["id"])] = {"food": true, "water": str(mm["id"]) != str(m["id"])}
		ShelterSim.end_day(s, {"rations": r, "treat": {}, "jobs": {}})
		if bool(m.get("sick", false)):
			sick_from_thirst += 1
	_ok(sick_from_thirst >= 6, "dehydration raises the risk of falling sick (%d/40 after a day dehydrated)" % sick_from_thirst)
	# Radiation: a lethal dose in a week means radiation sickness; a very severe one can kill.
	var ars_sick: int = 0
	var ars_deaths: int = 0
	for trial3 in range(40):
		_start_run()
		var s3: ShelterState = GameState.shelter
		s3.rng.seed = 12000 + trial3
		var c: Dictionary = s3.members[1]
		ShelterSim.add_dose(c, s3.day, 7000.0)
		for d in range(3):
			ShelterSim.begin_day(s3)
			s3.today_event = {}
			s3.today_resolved = true
			var r3: Dictionary = {}
			for mm3 in s3.home():
				r3[str(mm3["id"])] = {"food": true, "water": true}
			ShelterSim.end_day(s3, {"rations": r3, "treat": {}, "jobs": {}})
		if bool(c.get("sick", false)) or not bool(c.get("alive", true)):
			ars_sick += 1
		if not bool(c.get("alive", true)):
			ars_deaths += 1
	_ok(ars_sick == 40, "a lethal weekly dose always brings radiation sickness (%d/40)" % ars_sick)
	_ok(ars_deaths >= 2 and ars_deaths < 40, "very severe radiation sickness can be fatal, after a warning (%d/40 died in 3 days)" % ars_deaths)

func _test_long_runs() -> void:
	print("\n--- long runs (expert policy to the end, 6 seeds x 3 presets) ---")
	var summaries: Array = []
	for pid in ["seattle", "concord", "brooklyn"]:
		_setup_preset(pid)
		for seed_i in range(6):
			_start_run()
			var s: ShelterState = GameState.shelter
			var rng := RandomNumberGenerator.new()
			rng.seed = 400 + seed_i
			# M2: the cap matches the balance harness (120 days); a family still alive there with every
			# rescue gone quiet is a finished run, not a script error.
			while not s.is_over() and s.day < 120:
				ShelterSim.begin_day(s)
				if s.is_over():
					break
				if not s.today_event.is_empty():
					ShelterSim.choose(s, SimPolicies.pick_option(s, "expert", rng))
				if s.is_over():
					break
				ShelterSim.end_day(s, SimPolicies.make_plan(s, "expert", rng))
			BunkerSim.sync_outcome()
			var doses: Array = []
			for m in s.members:
				doses.append(int(float((m as Dictionary).get("dose_msv", 0.0))))
			summaries.append({"preset": pid, "seed": 400 + seed_i, "day": s.day, "ending": s.ending, "victory": GameState.victory, "trips": int(s.stats["trips"]), "doses_msv": doses})
	for sm in summaries:
		print("  ", JSON.stringify(sm))
	_report["long_runs"] = summaries
	var finished: int = 0
	for sm2 in summaries:
		if str((sm2 as Dictionary)["ending"]) != "" or int((sm2 as Dictionary)["day"]) >= 120:
			finished += 1
	_ok(summaries.size() == 18 and finished == 18, "18 long simulated runs reached an ending (or the 120-day cap) without script errors (%d/18)" % finished)

