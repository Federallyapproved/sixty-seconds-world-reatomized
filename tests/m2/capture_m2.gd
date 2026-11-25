extends SceneTree

## Renders the M2 screens to PNG for the milestone report and the /next/ media page: the title,
## the end-of-run summary after a whole run played by the expert policy, the Survival Almanac
## and the Achievements screen. Works on the M1 branch too (for "before" shots): the M2 classes
## are loaded at run time and skipped when missing.
## Needs a display (run in a normal no-focus window via override.cfg):
##   godot --path . --rendering-driver opengl3 -s res://tests/m2/capture_m2.gd -- --out=<dir> [--seed=7] [--prefix=m2]

var _out: String = "user://capture_m2"
var _prefix: String = "m2"
var _main: Control
var _gs: Node


func _init() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return fallback


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _snap(name: String) -> void:
	await _frames(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [_out, _prefix, name])
	print("SNAP %s_%s" % [_prefix, name])


func _run() -> void:
	_out = _arg("out", _out)
	_prefix = _arg("prefix", _prefix)
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_gs = root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = int(_arg("seed", "7"))
	await _frames(20)
	var alm_script: Script = load("res://scripts/meta/almanac.gd") if ResourceLoader.exists("res://scripts/meta/almanac.gd") else null
	var ach_script: Script = load("res://scripts/meta/achievements.gd") if ResourceLoader.exists("res://scripts/meta/achievements.gd") else null

	# A whole run, played by the harness's expert on the default house, ending on the summary.
	_gs.call("reset_to_defaults")
	for m in _gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for pair in [["food", 4], ["water", 4], ["medkit", 1], ["gas_mask", 1], ["radio", 1], ["axe", 1], ["map", 1], ["flashlight", 1], ["padlock", 1], ["cards", 1]]:
		_gs.call("add_scavenged_item", pair[0], pair[1])
	if alm_script != null:
		# This player has met most items in earlier runs.
		for iid in ShelterData.core_ids():
			if iid != "console" and iid != "bug_spray":
				alm_script.call("mark_seen", _gs.get("almanac"), iid)
	_gs.call("request_screen", "bunker")
	await _frames(30)
	var s: ShelterState = _gs.get("shelter")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_arg("seed", "7"))
	while not s.is_over() and s.day < 80:
		ShelterSim.begin_day(s)
		if s.is_over():
			break
		if not s.today_event.is_empty():
			ShelterSim.choose(s, SimPolicies.pick_option(s, "expert", rng))
		if s.is_over():
			break
		ShelterSim.end_day(s, SimPolicies.make_plan(s, "expert", rng))
	print("RUN ended day %d: %s" % [s.day, s.ending])
	var bsim: Script = load("res://scripts/bunker/bunker_sim.gd")
	bsim.call("sync_outcome")
	_gs.call("request_screen", "summary")
	await _frames(40)
	await _snap("summary")

	_gs.call("request_screen", "title")
	await _frames(30)
	await _snap("title")
	if alm_script != null:
		_gs.call("request_screen", "almanac")
		await _frames(20)
		var al: Node = _main.get("_active_node")
		# Open the page of the item that did the most this run.
		var page_item: String = "radio"
		var credits: Dictionary = s.stats.get("credits", {})
		var best: int = 0
		for k in credits.keys():
			if int(credits[k]) > best and str(k) != "food" and str(k) != "water":
				best = int(credits[k])
				page_item = str(k)
		al.call("_show_item", page_item)
		await _frames(6)
		await _snap("almanac")
	if ach_script != null:
		_gs.call("request_screen", "achievements")
		await _frames(20)
		await _snap("achievements")
	print("CAPTURE_DONE")
	quit(0)
