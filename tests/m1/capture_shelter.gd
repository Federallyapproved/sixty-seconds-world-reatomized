extends SceneTree

## Renders the M1 shelter screens to PNG (needs a display; run in a normal, non-focus window via
## override.cfg window/size/no_focus=true).
## godot --path . -s res://tests/m1/capture_shelter.gd -- --out=<dir> [--preset=seattle] [--difficulty=normal]

var _out: String = "user://m1_shots"
var _main: Control


func _init() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
	return fallback


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _snap(name: String) -> void:
	await _frames(3)
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SNAP ", name)


func _run() -> void:
	_out = _arg("out", "user://m1_shots")
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(5)
	var gs: Node = root.get_node("GameState")
	gs.set("difficulty", _arg("difficulty", "normal"))
	var parsed: Dictionary = OsmService.load_preset(_arg("preset", "seattle"))
	var house: Dictionary = OsmService.pick_best_house(parsed["buildings"], float(parsed["center_lat"]), float(parsed["center_lon"]), int(parsed["preferred_osm_id"]))
	var meta: Dictionary = {"roads": parsed["roads"], "parks": parsed["parks"], "bounds": parsed.get("bounds", {}), "source": parsed["source"], "place_names": parsed["place_names"], "landmarks": parsed["landmarks"]}
	gs.set("selected_house", house.duplicate(true))
	gs.set("nearby_pois", OsmService.build_nearby_targets_for_house(house, parsed["buildings"], parsed["pois"], parsed["roads"]))
	# Loaded at run time: naming the class here would compile it before the autoloads exist.
	(load("res://scripts/ui/house_select_screen.gd") as GDScript).call("store_map_context", house, parsed["buildings"], meta, [])
	var tgt: Dictionary = NukePhysics.pick_local_target(float(house["lat"]), float(house["lon"]), gs.get("map_landmarks"))
	var wind: float = NukePhysics.bearing_deg(float(tgt["lat"]), float(tgt["lon"]), float(house["lat"]), float(house["lon"]))
	gs.set("nuke_config", NukePhysics.compute_impact(float(house["lat"]), float(house["lon"]), float(tgt["lat"]), float(tgt["lon"]), 250, wind, str(tgt["target_name"])))
	gs.call("reset_to_defaults")
	(gs.get("rng") as RandomNumberGenerator).seed = 4242
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for pair in [["food", 3], ["water", 4], ["medkit", 1], ["gas_mask", 1], ["radio", 1], ["rifle", 1], ["ammo", 1], ["map", 1], ["cards", 1]]:
		gs.call("add_scavenged_item", pair[0], pair[1])
	gs.call("request_screen", "bunker")
	await _frames(40)
	await _snap("m1_10_day1")
	var bs: Node = _main.get("_active_node")
	var s: ShelterState = gs.get("shelter")
	# Play a few days with sensible choices so the receipt and the card show real content.
	for d in range(4):
		while bool(bs.get("_busy")):
			await _frames(2)
		if not s.today_resolved and not s.today_event.is_empty():
			if d == 1:
				await _snap("m1_20_dilemma_day%d" % s.day)
			var pick: String = ""
			for o_v in s.today_options:
				var o: Dictionary = o_v
				if bool(o.get("available", false)) and (pick == "" or str(o.get("item", "")) != ""):
					pick = str(o["id"])
			bs.call("_choose", pick)
			await _frames(30)
			var cin: Node = bs.get("_cinematic")
			await _snap("m1_25_outcome_day%d" % s.day)
			while bool(bs.get("_busy")):
				if cin.has_method("_on_continue"):
					cin.call("_on_continue")
				await _frames(5)
		for m_v in s.home():
			var m: Dictionary = m_v
			(bs.get("_plan")["rations"] as Dictionary)[str(m["id"])] = {"food": int(m.get("dwf", 0)) >= 5, "water": int(m.get("dww", 0)) >= 2}
		bs.call("_refresh_family")
		if d == 2:
			await _snap("m1_30_rations_day%d" % s.day)
			bs.call("_open_planner", str((s.home()[1] as Dictionary)["id"]), false)
			await _frames(20)
			var tp: Node = bs.get("_planner")
			tp.call("_select", 0)
			await _frames(10)
			await _snap("m1_40_trip_preview")
			tp.emit_signal("confirmed", 0, ["gas_mask", "map"])
			await _frames(10)
			await _snap("m1_45_trip_planned")
		bs.call("_commit_end_day")
		await _frames(60)
	await _snap("m1_50_later_day")
	print("CAPTURE_DONE")
	quit(0)
