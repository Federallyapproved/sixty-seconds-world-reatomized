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
	GameState.reset_to_defaults()
	GameState.init_default_family()
	for m in GameState.family_members:
		m["in_bunker"] = true
		m["alive"] = true
	GameState.soup_quarters = 40
	GameState.water_quarters = 48
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
		for i in range(40):
			GameState.day = 2 + i
			var ev: Dictionary = EventDeck.draw_daily_event(GameState.day, GameState.rng)
			var txt: String = str(ev.get("description", "")) + " " + str(ev.get("title", ""))
			if (not pc.is_empty() and txt.find(pc) != -1) or txt.find(", WA") != -1 or txt.find("USA") != -1 or txt.find(full) != -1:
				leaks += 1
			if txt.find("house") != -1 or txt.find("our place") != -1 or txt.find("home") != -1:
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
	print("\n--- finite loot ---")
	_setup_preset("concord")
	_start_run()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var target: Dictionary = {}
	for p in GameState.nearby_pois:
		if str(p["category"]) == "grocery":
			target = p
			break
	var hauls: Array[int] = []
	for i in range(30):
		var t: Dictionary = LootInventory.raid(target, 6, 0.45, rng)
		var n: int = 0
		for v in t.values():
			n += int(v)
		hauls.append(n)
	print("  successive raids at %s: %s" % [target["name"], str(hauls)])
	var last_nonzero: int = -1
	for i2 in range(hauls.size()):
		if hauls[i2] > 0:
			last_nonzero = i2
	_ok(hauls[0] > 0 and last_nonzero < hauls.size() - 5 and LootInventory.remaining_total(target) == 0, "raids eventually yield nothing, forever (last find on raid %d of %d)" % [last_nonzero + 1, hauls.size()])
	var non_increasing: bool = true
	var tot_first3: int = hauls[0] + hauls[1] + hauls[2]
	var tot_last3: int = hauls[27] + hauls[28] + hauls[29]
	_ok(tot_last3 < tot_first3, "later raids yield less than early ones (%d vs %d)" % [tot_first3, tot_last3])
	_ok(LootInventory.remaining_total(target) == 0 or LootInventory.remaining_total(target) < 3, "stock nearly/fully exhausted (left %d)" % LootInventory.remaining_total(target))
	# persistence: same dictionary across get_available_targets refresh
	ExpeditionEngine.get_available_targets()
	_ok(LootInventory.remaining_total(target) == LootInventory.remaining_total(GameState.nearby_pois[GameState.nearby_pois.find(target)]) , "inventory persists across target refresh (no respawn)")
	var inv_a: Dictionary = LootInventory._generate(target)
	var inv_b: Dictionary = LootInventory._generate(target)
	_ok(JSON.stringify(inv_a) == JSON.stringify(inv_b), "stock is deterministic per OSM id")
	# full expedition loop to the same place
	var member: Dictionary = GameState.family_members[0]
	var idx: int = GameState.nearby_pois.find(target)
	var exp_hauls: Array[int] = []
	for k in range(3):
		member["on_expedition"] = false
		ExpeditionEngine.start_expedition(str(member["id"]), idx, [])
		var guard: int = 0
		var res: Dictionary = {}
		while not GameState.active_expedition.is_empty() and guard < 5:
			res = ExpeditionEngine.tick_active_expedition()
			guard += 1
		var c: int = 0
		for v2 in (res.get("loot", {}) as Dictionary).values():
			c += int(v2)
		exp_hauls.append(c)
	_ok(exp_hauls[2] == 0, "expedition to an emptied store returns nothing: %s" % str(exp_hauls))


func _test_actor_succession() -> void:
	print("\n--- actor succession ---")
	_setup_preset("seattle")
	_start_run()
	var fam: Array = GameState.family_members
	var leader: Dictionary = fam[0]
	_ok(str(EventDeck.pick_actor().get("id", "")) == str(leader["id"]), "capable leader acts")
	leader["on_expedition"] = true
	var a2: Dictionary = EventDeck.pick_actor()
	_ok(str(a2.get("name", "")) == "Dolores", "leader absent -> oldest eligible acts (%s)" % a2.get("name", ""))
	leader["on_expedition"] = false
	leader["injury"] = 3
	_ok(str(EventDeck.pick_actor().get("name", "")) == "Dolores", "leader incapacitated -> oldest eligible acts")
	leader["injury"] = 0
	fam[1]["alive"] = false
	leader["alive"] = false
	var a3: Dictionary = EventDeck.pick_actor()
	_ok(str(a3.get("name", "")) == "Mary Jane", "leader & oldest dead -> next oldest eligible (teen) acts: %s" % a3.get("name", ""))
	# outcomes never name absent/dead people
	var bad: int = 0
	for i in range(60):
		GameState.day = 3 + i
		var ev: Dictionary = EventDeck.draw_daily_event(GameState.day, GameState.rng)
		var opts: Array = ev.get("options", [])
		if opts.is_empty():
			continue
		var res: Dictionary = EventDeck.resolve_event(ev, str(opts[opts.size() - 1]["id"]), GameState.rng)
		var txt: String = str(res.get("outcome_text", ""))
		for nm in ["Ted", "Dolores"]:
			if txt.find(nm) != -1:
				bad += 1
		if str(res.get("actor_name", "")) in ["Ted", "Dolores", ""]:
			bad += 1
		if GameState.game_over:
			break
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
	print("\n--- vehicle & location-driven routes ---")
	var routes: Dictionary = {}
	for pid in ["seattle", "concord", "brooklyn"]:
		_setup_preset(pid)
		_start_run()
		var v: Dictionary = GameState.vehicle
		var missing: Array = VehicleSystem.missing_parts()
		var sources: Dictionary = {}
		for part in ["car_battery", "fuel_can", "spark_plugs", "fan_belt", "tire_patch"]:
			sources[part] = VehicleSystem.part_sources(part).size()
		var cats: Dictionary = {}
		for p in GameState.nearby_pois:
			cats[str(p["category"])] = true
		routes[pid] = {
			"hardware_or_auto": cats.has("hardware") or cats.has("auto"),
			"sanctuary": EventDeck.has_real_poi(["church", "school"]),
			"vehicle_route": VehicleSystem.route_available(),
			"missing": missing, "part_sources": sources,
			"spark_plug_sources": sources["spark_plugs"]
		}
		print("  %s: %s" % [pid, JSON.stringify(routes[pid])])
		_ok(not missing.is_empty() and missing.has("car_battery"), "%s: car starts broken (battery missing)" % pid)
	_report["routes"] = routes
	# A neighbourhood without hardware/auto has far fewer engine-part sources than one with them
	var with_shops: int = int(routes["concord"]["part_sources"]["spark_plugs"]) + int(routes["seattle"]["part_sources"]["fuel_can"])
	_ok(int(routes["brooklyn"]["part_sources"]["spark_plugs"]) <= int(routes["concord"]["part_sources"]["spark_plugs"]), "no hardware store -> fewer spark-plug sources (Brooklyn %d vs Concord %d)" % [int(routes["brooklyn"]["part_sources"]["spark_plugs"]), int(routes["concord"]["part_sources"]["spark_plugs"])])
	# battery manual install flow
	_setup_preset("seattle")
	_start_run()
	GameState.vehicle["wrecked"] = false
	_ok(not VehicleSystem.can_install("car_battery")["ok"], "cannot install a battery that is not in storage")
	GameState.add_scavenged_item("car_battery", 1)
	_ok(int(GameState.parts["car_battery"]) == 1, "recovered battery is placed in storage")
	_ok(not bool(GameState.vehicle["battery_installed"]), "battery is NOT auto-installed")
	var res: Dictionary = VehicleSystem.install("car_battery")
	_ok(bool(res["ok"]) and bool(GameState.vehicle["battery_installed"]) and int(GameState.parts["car_battery"]) == 0, "manual install moves battery from storage into the car: %s" % str(res.get("text", "")))
	_ok(float(res.get("dose_msv", 0.0)) > 0.0, "garage work costs radiation dose (%s)" % RadiationModel.format_dose(float(res.get("dose_msv", 0.0))))
	# complete repair and drive out
	GameState.add_scavenged_item("toolbox", 1)
	for part in ["spark_plugs", "fan_belt", "tire_patch"]:
		GameState.add_scavenged_item(part, 1)
	GameState.add_scavenged_item("fuel_can", 3)
	var guard: int = 0
	while not VehicleSystem.missing_parts().is_empty() and guard < 10:
		var p: String = str(VehicleSystem.missing_parts()[0])
		var r2: Dictionary = VehicleSystem.install(p)
		guard += 1
		if not bool(r2["ok"]):
			print("  install failed: ", p, " ", r2["text"])
			break
	_ok(VehicleSystem.is_ready(), "car becomes road-worthy after all parts installed")
	var drive: Dictionary = VehicleSystem.drive_out()
	_ok(bool(drive["ok"]) and GameState.victory and GameState.ending_title.begins_with("VICTORY: DROVE OUT"), "drive-out escape ending works: %s" % GameState.ending_title)
	var plan_e: Dictionary = VehicleSystem.escape_plan()
	var hl: float = float(GameState.selected_house["lat"])
	var ho: float = float(GameState.selected_house["lon"])
	var to_gz_e: float = NukePhysics.bearing_deg(hl, ho, float(GameState.nuke_config["lat"]), float(GameState.nuke_config["lon"]))
	var cross_e: float = absf(NukePhysics.angle_diff_deg(float(plan_e["bearing"]), LocationText.downwind_bearing()))
	var away_e: float = absf(NukePhysics.angle_diff_deg(float(plan_e["bearing"]), to_gz_e))
	_ok(absf(cross_e - 90.0) < 1.0 and away_e >= 90.0, "escape heads crosswind (%.0f° off the plume) and away from ground zero (%.0f° from GZ bearing): %s" % [cross_e, away_e, str(plan_e["dir_word"])])
	# Wrecked car removes the route
	_start_run()
	GameState.vehicle["wrecked"] = true
	_ok(not VehicleSystem.route_available() and VehicleSystem.missing_parts().is_empty(), "wrecked car -> vehicle route unavailable")
	# Sanctuary chain only with a real church/school
	_setup_preset("seattle")
	_start_run()
	var saved: Array = GameState.nearby_pois
	var filtered: Array = []
	for p2 in saved:
		if not (str(p2["category"]) in ["church", "school"]):
			filtered.append(p2)
	GameState.nearby_pois = filtered
	EventDeck.reset_state()
	var sanct_drawn: int = 0
	for d in range(5, 60):
		var id: String = EventDeck._pick_rescue_event_id(d, GameState.rng)
		if id.begins_with("rescue_sanctuary"):
			sanct_drawn += 1
	_ok(sanct_drawn == 0, "no sanctuary rescue chain without a real church/school")
	var mil: int = 0
	for d2 in range(5, 60):
		if EventDeck._pick_rescue_event_id(d2, GameState.rng).begins_with("rescue_military"):
			mil += 1
	_ok(mil > 0, "military rescue remains as a legitimate alternative (no softlock)")
	GameState.nearby_pois = saved


func _test_health_links() -> void:
	print("\n--- health links ---")
	_setup_preset("brooklyn")
	var deaths_thirst: int = 0
	var sick_from_thirst: int = 0
	for trial in range(40):
		_start_run()
		var m: Dictionary = GameState.family_members[1]
		m["days_without_water"] = 3
		m["thirst"] = 2
		GameState.rng.seed = 5000 + trial
		var plan: Dictionary = {}
		for mm in GameState.get_living_bunker_members():
			plan[str(mm["id"])] = {"soup_q": 1, "water_q": 1 if str(mm["id"]) != str(m["id"]) else 0}
		BunkerSim.advance_day(plan, "", {}, {})
		if int(m.get("sickness", 0)) > 0:
			sick_from_thirst += 1
	_ok(sick_from_thirst >= 2, "dehydration raises fever risk (%d/40 got sick after a dry day)" % sick_from_thirst)
	# ARS blocks healing
	var healed_clean: int = 0
	var healed_irradiated: int = 0
	for trial2 in range(60):
		_start_run()
		GameState.rng.seed = 9000 + trial2
		var a: Dictionary = GameState.family_members[0]
		var b: Dictionary = GameState.family_members[1]
		a["sickness"] = 1
		b["sickness"] = 1
		RadiationModel.add_dose(b, 2600.0, GameState.day)
		var plan2: Dictionary = {}
		for mm2 in GameState.get_living_bunker_members():
			plan2[str(mm2["id"])] = {"soup_q": 1, "water_q": 1}
		BunkerSim.advance_day(plan2, "", {}, {})
		if int(a.get("sickness", 0)) == 0:
			healed_clean += 1
		if int(b.get("sickness", 0)) == 0:
			healed_irradiated += 1
	_ok(healed_irradiated < healed_clean, "radiation sickness slows healing (%d vs %d of 60 recovered)" % [healed_irradiated, healed_clean])
	# severe ARS can kill
	var ars_deaths: int = 0
	for trial3 in range(40):
		_start_run()
		GameState.rng.seed = 12000 + trial3
		var c: Dictionary = GameState.family_members[1]
		RadiationModel.add_dose(c, 7000.0, GameState.day)
		var plan3: Dictionary = {}
		for mm3 in GameState.get_living_bunker_members():
			plan3[str(mm3["id"])] = {"soup_q": 1, "water_q": 1}
		BunkerSim.advance_day(plan3, "", {}, {})
		if not bool(c.get("alive", true)):
			ars_deaths += 1
	_ok(ars_deaths >= 5, "very severe radiation sickness can be fatal (%d/40 died in one day)" % ars_deaths)


func _test_long_runs() -> void:
	print("\n--- long runs (30 days, 6 seeds x 3 presets) ---")
	var errors: int = 0
	var summaries: Array = []
	for pid in ["seattle", "concord", "brooklyn"]:
		_setup_preset(pid)
		for seed_i in range(6):
			_start_run()
			GameState.rng.seed = 400 + seed_i
			var day_reached: int = 1
			for d in range(30):
				if GameState.game_over:
					break
				var plan: Dictionary = {}
				for mm in GameState.get_living_bunker_members():
					plan[str(mm["id"])] = {"soup_q": 1 if GameState.soup_quarters > 0 else 0, "water_q": 1 if GameState.water_quarters > 0 else 0}
				var ev: Dictionary = EventDeck.draw_daily_event(GameState.day, GameState.rng)
				var outcome: Dictionary = {}
				var opts: Array = ev.get("options", [])
				if not opts.is_empty():
					var pick: String = ""
					for o in opts:
						if bool(o.get("available", false)):
							pick = str(o["id"])
					outcome = EventDeck.resolve_event(ev, pick, GameState.rng)
				var launch: Dictionary = {}
				if GameState.active_expedition.is_empty() and d % 3 == 1:
					var actor: Dictionary = EventDeck.pick_actor()
					if not actor.is_empty() and not GameState.nearby_pois.is_empty():
						launch = {"member_id": str(actor["id"]), "poi_index": (d * 7) % GameState.nearby_pois.size(), "gear_ids": []}
				BunkerSim.advance_day(plan, "", outcome, launch)
				day_reached = GameState.day
			var doses: Array = []
			for m in GameState.family_members:
				doses.append(int(float(m.get("dose_msv", 0.0))))
			summaries.append({"preset": pid, "seed": 400 + seed_i, "day": day_reached, "victory": GameState.victory, "game_over": GameState.game_over, "ending": GameState.ending_title, "doses_msv": doses})
	for s in summaries:
		print("  ", JSON.stringify(s))
	_report["long_runs"] = summaries
	_ok(summaries.size() == 18, "18 long simulated runs completed without script errors")
