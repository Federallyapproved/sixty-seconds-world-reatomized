extends SceneTree

## Difficulty probe: lets the built-in pathfinding autopilot (a perfect-knowledge
## greedy player) run the scavenge phase on many seeds/houses and reports how much
## of the house it secured. Works on both the original and the reworked scavenge.
## Usage (headless, deterministic 60 fps):
##   godot --headless --fixed-fps 60 --path . -s res://tests/pass2/bot_difficulty_probe.gd -- --seeds=12 [--hard] [--out=/tmp/probe.json]

var _results: Array = []


func _init() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
	return fallback


func _run() -> void:
	var seeds: int = int(_arg("seeds", "10"))
	var hard: bool = OS.get_cmdline_user_args().has("--hard")
	var out_path: String = _arg("out", "")
	var presets: Array = ["seattle", "concord", "brooklyn"]

	var main_packed: PackedScene = load("res://scenes/main.tscn")
	var main_inst: Control = main_packed.instantiate()
	root.add_child(main_inst)
	await process_frame

	var gs: Node = root.get_node("GameState")
	var osm_script: GDScript = load("res://scripts/osm/osm_service.gd")

	for s in range(seeds):
		var preset_id: String = presets[s % presets.size()]
		var parsed: Dictionary = osm_script.call("load_preset", preset_id)
		var bldgs: Array = parsed.get("buildings", [])
		var res_bldgs: Array = []
		for b in bldgs:
			if bool(b.get("is_residential", true)) and float(b.get("area_sqm", 0.0)) >= 60.0 and float(b.get("area_sqm", 0.0)) <= 400.0:
				res_bldgs.append(b)
		if res_bldgs.is_empty():
			res_bldgs = bldgs
		var house: Dictionary = res_bldgs[(s * 7919) % res_bldgs.size()]
		gs.set("selected_house", house)
		gs.set("nearby_pois", osm_script.call("build_nearby_targets_for_house", house, bldgs, parsed.get("pois", [])))
		if gs.get("difficulty") != null:
			gs.set("difficulty", "hard" if hard else "normal")
		gs.call("init_default_family")
		gs.get("rng").seed = 1000 + s
		gs.set("demo_mode", true)
		gs.set("autopilot_full_run", true)
		gs.call("request_screen", "scavenge")
		await process_frame
		await process_frame
		var scene: Node = main_inst.get("_active_node")
		var total_items: int = 0
		var total_family: int = 0
		var total_value: float = 0.0
		var scav_total: float = float(scene.get("_scavenge_total"))
		for it in scene.get("_world_items"):
			total_items += 1
			total_value += _item_value(str(it.get("item_id", "")))
		total_family = (scene.get("_world_family") as Array).size()
		var house_bounds: Rect2 = scene.get("_house_bounds")
		var room_count: int = (scene.get("_rooms") as Array).size()

		# run until the screen leaves scavenge (max 200s game time)
		var guard: int = 0
		while gs.get("current_screen") == "scavenge" and guard < 60 * 200:
			await process_frame
			guard += 1

		var stats: Dictionary = gs.get("scavenge_stats")
		var secured_value: float = 0.0
		var secured_items: int = 0
		# Count what actually reached the shelter
		secured_value += float(gs.get("soup_quarters")) / 4.0 * _item_value("food")
		secured_value += float(gs.get("water_quarters")) / 4.0 * _item_value("water")
		secured_items += int(gs.get("soup_quarters")) / 4 + int(gs.get("water_quarters")) / 4
		var bi: Dictionary = gs.get("bunker_items")
		for k in bi.keys():
			var c: int = int(bi[k].get("count", 0))
			secured_items += c
			secured_value += float(c) * _item_value(str(k))
		for k2 in ["medkit", "bug_spray"]:
			var cnt: int = int(gs.get(k2 + "_count"))
			secured_items += cnt
			secured_value += float(cnt) * _item_value(k2)
		if bool(gs.get("padlock_active")):
			secured_items += 1
			secured_value += _item_value("padlock")
		if int(gs.get("ammo_count")) > 0:
			secured_items += 1
			secured_value += _item_value("ammo")
		var fam_saved: int = 0
		for m in gs.get("family_members"):
			if bool(m.get("in_bunker", false)) and bool(m.get("alive", false)) and not bool(m.get("is_leader", false)):
				fam_saved += 1
		var rec: Dictionary = {
			"seed": 1000 + s,
			"preset": preset_id,
			"house_osm_id": int(house.get("osm_id", 0)),
			"house_area_sqm": float(house.get("area_sqm", 0.0)),
			"rooms": room_count,
			"level_px": [house_bounds.size.x, house_bounds.size.y],
			"scavenge_seconds": scav_total,
			"items_total": total_items,
			"items_secured": secured_items,
			"value_total": total_value,
			"value_secured": secured_value,
			"value_pct": (secured_value / total_value * 100.0) if total_value > 0.0 else 0.0,
			"family_total": total_family,
			"family_saved": fam_saved,
			"leader_escaped": bool(stats.get("leader_escaped", false)),
			"time_left_at_dive": float(stats.get("time_remaining", 0.0)),
		}
		_results.append(rec)
		print("PROBE ", JSON.stringify(rec))
		gs.set("demo_mode", false)
		gs.call("request_screen", "title")
		await process_frame

	var pct_sum: float = 0.0
	var all_family: int = 0
	var full_clear: int = 0
	for r in _results:
		pct_sum += float(r["value_pct"])
		if int(r["family_saved"]) >= int(r["family_total"]):
			all_family += 1
		if int(r["family_saved"]) >= int(r["family_total"]) and float(r["value_pct"]) >= 99.0:
			full_clear += 1
	var summary: Dictionary = {
		"runs": _results.size(),
		"hard": hard,
		"mean_value_pct": pct_sum / maxf(1.0, float(_results.size())),
		"runs_all_family_saved": all_family,
		"runs_everything_secured": full_clear,
	}
	print("PROBE_SUMMARY ", JSON.stringify(summary))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"summary": summary, "runs": _results}, "  "))
		f.close()
	quit(0)


func _item_value(item_id: String) -> float:
	match item_id:
		"food", "water":
			return 3.0
		"medkit", "gas_mask", "radio", "rifle", "axe", "manual", "map", "flashlight":
			return 4.0
		"suitcase", "padlock", "ammo", "bug_spray", "manual":
			return 2.0
		_:
			return 1.0
