extends SceneTree

## Renders the M3 screens to PNG for the milestone report and the /next/ media page: the shelter
## with junk and parts on the HUD, the workbench (browse, all recipes, a survivor's bench, the
## manual), the job menu, a stand-in on an event card, the morning after a craft, and the trip
## planner with the Need toggle on.
## Needs a display (a normal no-focus window via override.cfg):
##   godot --path . --rendering-driver opengl3 -s res://tests/m3/capture_m3.gd -- --out=<dir> [--prefix=m3]

var _out: String = "user://capture_m3"
var _prefix: String = "m3"
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


func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var f: Node = _find(c, nm)
		if f != null:
			return f
	return null


func _press(nm: String) -> bool:
	var b: Node = _find(root, nm)
	if b is BaseButton and not (b as BaseButton).disabled:
		(b as BaseButton).pressed.emit()
		return true
	print("CAPTURE: no enabled button ", nm)
	return false


func _run() -> void:
	_out = _arg("out", _out)
	_prefix = _arg("prefix", _prefix)
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_gs = root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = int(_arg("seed", "7"))
	await _frames(20)
	_gs.call("reset_to_defaults")
	for m in _gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for pair in [["food", 4], ["water", 4], ["manual", 1], ["axe", 1], ["flashlight", 1], ["radio", 1], ["gas_mask", 1],
			["toaster", 1], ["bedsheet", 2], ["sanitizer", 1], ["duct_tape", 1], ["pots_pans", 1], ["old_phone", 1], ["bottles", 1]]:
		_gs.call("add_scavenged_item", pair[0], pair[1])
	_gs.call("request_screen", "bunker")
	await _frames(40)
	var bunker: Node = _main.get("_active_node")
	var s: ShelterState = _gs.get("shelter")
	if bunker == null or s == null:
		print("CAPTURE: no bunker")
		quit(1)
		return
	# Day 1 is quiet so the screen shows the plan, not a dilemma.
	s.today_event = {}
	s.today_resolved = true
	s.today_options = []
	bunker.call("_refresh_all")
	await _snap("shelter_junk")

	bunker.call("_open_bench", "", "browse")
	await _frames(10)
	await _snap("bench_browse")
	_press("TakeApart_toaster")
	await _frames(6)
	_press("ShowAll")
	await _frames(10)
	await _snap("bench_all_recipes")
	_press("Back")
	await _frames(6)

	# The job menu, then a day at the bench for the second adult.
	var adult: String = ""
	for m_v in s.home():
		var m: Dictionary = m_v
		if not bool(m.get("is_leader", false)) and not ShelterState.is_child(m):
			adult = str(m["id"])
			break
	var jb: Node = _find(root, "Job_" + adult)
	if jb != null:
		bunker.call("_open_job_menu", adult, jb)
		await _frames(6)
		await _snap("job_menu")
		bunker.call("_close_job_menu")
	bunker.call("_open_bench", adult, "craft")
	await _frames(8)
	_press("Make_rag_bandage")
	await _frames(4)
	_press("Make_bindle")
	await _frames(8)
	await _snap("bench_craft")
	_press("Confirm")
	await _frames(8)
	# The leader studies the manual today.
	var leader: String = ""
	for m_v in s.home():
		if bool((m_v as Dictionary).get("is_leader", false)):
			leader = str((m_v as Dictionary)["id"])
	bunker.call("_open_bench", leader, "study")
	await _frames(8)
	await _snap("bench_study")
	_press("Study_ch2")
	await _frames(8)
	await _snap("shelter_jobs")
	bunker.call("_commit_end_day")
	await _frames(90)
	s.today_event = {}
	s.today_resolved = true
	s.today_options = []
	bunker.call("_refresh_all")
	await _snap("morning_after")

	# A stand-in on an event card: soap spray instead of bug spray.
	s.add("soap_spray", 1)
	s.add("phone_torch", 1)
	s.today_event = ShelterEvents._prepare(s, ShelterData.event("uninvited"))
	s.today_options = ShelterEvents.options_for(s, s.today_event)
	s.today_resolved = false
	bunker.call("_refresh_all")
	await _snap("standin")
	s.today_event = {}
	s.today_resolved = true
	bunker.call("_refresh_all")

	# The Need toggle in the trip planner: tag the barricade's parts, look at the hardware store.
	ShelterCraft.toggle_need(s, "door_barricade")
	var hw: int = -1
	for p_v in s.places:
		if not ShelterTrips.junk_hint(s, p_v as Dictionary).is_empty() and (hw < 0 or str((p_v as Dictionary)["category"]) != "neighbor_house"):
			hw = int((p_v as Dictionary)["idx"])
			if str((p_v as Dictionary)["category"]) != "neighbor_house":
				break
	print("CAPTURE: planner place %d, need %s" % [hw, str(s.need_parts)])
	bunker.call("_open_planner", adult, false)
	await _frames(20)
	var planner: Node = bunker.get("_planner")
	if planner != null and hw >= 0:
		planner.call("_select", hw)
		await _frames(10)
		await _snap("planner_need")
	print("CAPTURE_DONE")
	quit(0)
