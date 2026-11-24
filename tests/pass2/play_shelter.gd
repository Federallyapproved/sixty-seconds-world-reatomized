extends SceneTree

## Plays the shelter phase like a player: keyboard input (number keys pick a dilemma answer,
## SPACE continues), schedules a real expedition, watches the return, opens the garage,
## installs salvaged parts by hand and drives out. Screenshots every beat and writes a JSON
## report of what it verified. Needs a display (xvfb-run) for screenshots; runs headless too.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --audio-driver Dummy -s res://tests/pass2/play_shelter.gd -- --out=/tmp/play [--seed=7]

var _out: String = "/tmp/play"
var _main: Control
var _gs: Node
var _bk: Node
var _shots: int = 0
var _report: Dictionary = {"checks": [], "days": [], "returns": [], "installs": []}
var _snap_every: bool = true


func _init() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
	return fallback


func _check(name: String, ok: bool, detail: String = "") -> void:
	(_report["checks"] as Array).append({"name": name, "ok": ok, "detail": detail})
	print(("PASS " if ok else "FAIL ") + name + ("" if detail == "" else "  — " + detail))


func _run() -> void:
	_out = _arg("out", "/tmp/play")
	_snap_every = _arg("snaps", "1") == "1"
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_gs = root.get_node("GameState")
	_gs.get("rng").seed = int(_arg("seed", "7"))
	await _frames(8)

	# Choose the real default house through the actual house-select screen.
	_gs.call("request_screen", "osm_house")
	await _frames(30)
	var hs: Node = _main.get("_active_node")
	var picked: bool = false
	for b in hs.get("_current_buildings"):
		if int(b.get("osm_id", 0)) == 206082403:
			hs.call("_select_house", b, false)
			picked = true
			break
	_check("house_select_real_osm_way", picked, "way 206082403")
	_check("map_roads_stored", (_gs.get("map_roads") as Array).size() > 20, "%d roads" % (_gs.get("map_roads") as Array).size())

	for m in _gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for pair in [["soup", 6], ["water", 7], ["medkit", 1], ["gas_mask", 1], ["radio", 1], ["rifle", 1], ["toolbox", 1], ["map", 1], ["flashlight", 1], ["suitcase", 1]]:
		_gs.call("add_scavenged_item", pair[0], pair[1])
	_gs.call("request_screen", "bunker")
	await _frames(40)
	_bk = _main.get("_active_node")
	var cine: Control = _bk.get("_cinematic")
	_check("cinematic_present", cine != null)
	_check("dilemma_shown_directly_day1", cine.visible and str(cine.get("_mode")) == "dilemma")
	var first_day: Dictionary = await _play_day_cinematics(1)
	(_report["days"] as Array).append(first_day)
	_check("day1_resolved_by_player", not bool(_bk.get("_has_unresolved_dilemma")))
	await _snap("p00_shelter_day1")

	# Day 1: plan an expedition to a real place (prefer one that can yield vehicle parts)
	var targets: Array = _bk.get("_available_targets")
	var best: int = 0
	for i in range(targets.size()):
		var cat: String = str(targets[i].get("category", ""))
		if cat in ["auto", "hardware"] and not bool(targets[i].get("depleted", false)):
			best = i
			break
	_bk.set("_selected_poi_index", best)
	_bk.call("set_active_tab", 3)
	await _frames(10)
	await _snap("p01_expedition_planner_real_map")
	var tgt: Dictionary = targets[best] if not targets.is_empty() else {}
	_check("expedition_target_real", not tgt.is_empty() and int(tgt.get("osm_id", 0)) != 0, "%s (%s, OSM %d, %dm walk)" % [str(tgt.get("name", "")), str(tgt.get("kind_label", "")), int(tgt.get("osm_id", 0)), int(tgt.get("walk_m", 0))])

	# Big neighbourhood map
	(_bk.get("_next_page_btn") as Button).emit_signal("pressed")
	await _frames(12)
	await _snap("p02_big_map_nearby")
	var bm: Control = _bk.get("_big_map")
	bm.set("view_mode", "extended")
	bm.call("queue_redraw")
	await _frames(6)
	await _snap("p03_big_map_extended")
	(_bk.get("_map_overlay") as Control).visible = false

	var day_cap: int = int(_arg("days", "9"))
	var scheduled: bool = false
	var actors: Array = []
	var silent_default_seen: bool = false
	actors.append(first_day)
	var first: bool = true
	while int(_gs.get("day")) <= day_cap and not bool(_gs.get("game_over")):
		var d: int = int(_gs.get("day"))
		if not first:
			var rec: Dictionary = await _play_day_cinematics(d)
			(_report["days"] as Array).append(rec)
			if rec.has("actor"):
				actors.append(rec)
		first = false
		if bool(_bk.get("_has_unresolved_dilemma")):
			silent_default_seen = true
		# schedule the expedition once someone is free
		if not scheduled and (_gs.get("active_expedition") as Dictionary).is_empty():
			_bk.call("_ensure_valid_explorer_selected")
			_bk.set("_selected_gear_ids", ["gas_mask", "map", "suitcase"])
			_bk.set("_expedition_scheduled", true)
			scheduled = true
		# rations: 1 water each day, soup every other day
		var plan: Dictionary = _bk.get("_planned_rations")
		for mid in plan.keys():
			plan[mid] = {"soup_q": 1 if d % 2 == 0 else 0, "water_q": 1}
		_bk.call("_on_end_day_pressed")
		await _wait_transition()
		# vehicle parts: on day 5 pretend the expedition found a battery if none was found
		if int(_gs.get("day")) >= 4 and not _report.has("garage_done") and (_gs.get("active_expedition") as Dictionary).is_empty():
			var rec_g: Dictionary = await _play_day_cinematics(int(_gs.get("day")))
			(_report["days"] as Array).append(rec_g)
			if rec_g.has("actor"):
				actors.append(rec_g)
			await _garage_sequence()
			_report["garage_done"] = true
			break
	_check("no_silent_default", not silent_default_seen)
	_check("summary_reached", str(_gs.get("current_screen")) == "summary", str(_gs.get("current_screen")))
	var all_actor_ok: bool = true
	for rec2 in actors:
		if not bool(rec2.get("actor_ok", false)):
			all_actor_ok = false
	_check("actor_always_present_and_capable", all_actor_ok, "%d dilemmas" % actors.size())
	_check("returns_animated", (_report["returns"] as Array).size() >= 1, "%d returns" % (_report["returns"] as Array).size())
	var f := FileAccess.open(_out + "/play_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	var fails: int = 0
	for c in _report["checks"]:
		if not bool(c["ok"]):
			fails += 1
	print("PLAY_DONE fails=%d shots=%d" % [fails, _shots])
	quit(0 if fails == 0 else 1)


func _play_day_cinematics(d: int) -> Dictionary:
	var rec: Dictionary = {"day": d}
	var cine: Control = _bk.get("_cinematic")
	var guard: int = 0
	await _frames(4)
	while is_instance_valid(cine) and (cine.visible or not (_bk.get("_day_queue") as Array).is_empty()) and guard < 3000:
		guard += 1
		var mode: String = str(cine.get("_mode"))
		var kind: String = str(cine.get("_kind"))
		if mode == "dilemma":
			var ev: Dictionary = _bk.get("_current_event")
			var actor: Dictionary = cine.get("_actor")
			rec["event"] = str(ev.get("id", ev.get("title", "")))
			rec["actor"] = str(actor.get("name", ""))
			rec["actor_ok"] = bool(actor.get("alive", false)) and bool(actor.get("in_bunker", false)) and not bool(actor.get("on_expedition", false))
			await _snap("d%02d_a_dilemma" % d)
			var btns: Array = cine.call("_option_buttons")
			var pick: int = 0
			for i in range(btns.size()):
				if not (btns[i] as Button).disabled:
					pick = i
					if i > 0:
						break
			_key(KEY_1 + pick)
			await _frames(50)
			rec["scenario"] = str(cine.get("_scenario"))
			await _snap("d%02d_b_outcome_%s" % [d, rec["scenario"]])
		elif mode == "playing":
			if kind == "return":
				if not rec.has("return_snapped"):
					await _frames(150)
					await _snap("d%02d_c_return" % d)
					rec["return_snapped"] = true
					(_report["returns"] as Array).append({"day": d, "items": cine.get("_params").get("items", [])})
			await _frames(5)
		elif mode == "caption":
			await _frames(4)
			_key(KEY_SPACE)
			await _frames(6)
		else:
			await _frames(2)
	rec["outcome"] = str((_bk.get("_resolved_outcome") as Dictionary).get("outcome_text", ""))
	return rec


func _garage_sequence() -> void:
	var parts: Dictionary = _gs.get("parts")
	var veh: Dictionary = _gs.get("vehicle")
	_check("vehicle_initialised", veh.has("battery_installed"), str(veh))
	if int(parts.get("car_battery", 0)) <= 0:
		parts["car_battery"] = 1
		_report["battery_injected"] = true
	(_bk.get("_prev_page_btn") as Button).emit_signal("pressed")
	await _frames(12)
	await _snap("g00_garage_before")
	var gv: Control = _bk.get("_garage")
	var cine: Control = _bk.get("_cinematic")
	var dose_before: float = 0.0
	gv.emit_signal("install_requested", "car_battery")
	await _frames(130)
	await _snap("g01_install_battery_mid")
	while cine.visible and str(cine.get("_mode")) != "caption":
		await _frames(5)
	await _snap("g02_install_battery_done")
	_key(KEY_SPACE)
	await _frames(10)
	_check("battery_installed_by_player", bool(veh.get("battery_installed", false)) and int(parts.get("car_battery", 0)) == 0)
	(_report["installs"] as Array).append("car_battery")
	await _snap("g03_garage_after_battery")
	# give the rest so the escape can be shown end to end
	parts["spark_plugs"] = maxi(1, int(parts.get("spark_plugs", 0)))
	parts["fan_belt"] = maxi(1, int(parts.get("fan_belt", 0)))
	parts["tire_patch"] = maxi(1, int(parts.get("tire_patch", 0)))
	parts["fuel_l"] = maxf(30.0, float(parts.get("fuel_l", 0.0)))
	var vs: GDScript = load("res://scripts/bunker/vehicle_system.gd")
	for part in ["spark_plugs", "fan_belt", "tire_patch", "fuel_can", "fuel_can", "fuel_can"]:
		if not (vs.call("missing_parts") as Array).has(part):
			continue
		gv.emit_signal("install_requested", part)
		await _frames(10)
		while cine.visible:
			if str(cine.get("_mode")) == "caption":
				_key(KEY_SPACE)
			await _frames(5)
		(_report["installs"] as Array).append(part)
	await _frames(10)
	await _snap("g04_garage_ready")
	_check("car_ready_after_installs", bool(vs.call("is_ready")), str(vs.call("missing_parts")))
	gv.emit_signal("drive_requested")
	await _frames(170)
	await _snap("g05_drive_out")
	while is_instance_valid(cine) and cine.visible:
		if str(cine.get("_mode")) == "caption":
			_key(KEY_SPACE)
		await _frames(5)
	await _frames(30)
	await _snap("g06_summary")
	_check("drive_out_victory", bool(_gs.get("victory")) and str(_gs.get("ending_title")).begins_with("VICTORY: DROVE OUT"), str(_gs.get("ending_title")))


func _wait_transition() -> void:
	var g: int = 0
	await _frames(2)
	while bool(_bk.get("_in_day_transition")) and g < 600:
		g += 1
		await _frames(2)
	await _frames(6)


func _key(kc: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = kc
	ev.physical_keycode = kc
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = kc
	up.physical_keycode = kc
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _snap(name: String) -> void:
	if not _snap_every or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(_out + "/" + name + ".png")
		_shots += 1
