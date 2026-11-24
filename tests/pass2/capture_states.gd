extends SceneTree

## Renders key game states to PNG for visual review (before/after comparisons).
## Usage (needs a display; GL Compatibility renderer):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       -s res://tests/pass2/capture_states.gd -- --out=/tmp/shots [--preset=seattle]

var _out: String = "/tmp/shots"
var _main: Control


func _init() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
	return fallback


func _run() -> void:
	_out = _arg("out", "/tmp/shots")
	var preset: String = _arg("preset", "seattle")
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	var gs: Node = root.get_node("GameState")
	gs.get("rng").seed = 424242
	await _frames(10)

	gs.call("request_screen", "osm_house")
	await _frames(20)
	var hs: Node = _main.get("_active_node")
	if preset != "seattle" and hs.has_method("_load_preset_neighborhood"):
		hs.call("_load_preset_neighborhood", preset, false)
		await _frames(10)
	await _snap("10_house_select")

	gs.call("request_screen", "nuke")
	await _frames(14)
	await _snap("20_nuke_screen")

	gs.call("request_screen", "scavenge")
	await _frames(30)
	await _snap("30_scavenge_scout")
	var sc: Node = _main.get("_active_node")
	if sc.has_method("_start_scavenge_phase"):
		sc.call("_start_scavenge_phase")
	await _frames(40)
	await _snap("31_scavenge_active")

	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for pair in [["soup", 5], ["water", 6], ["medkit", 1], ["gas_mask", 1], ["radio", 1], ["rifle", 1], ["toolbox", 1], ["map", 1]]:
		gs.call("add_scavenged_item", pair[0], pair[1])
	gs.call("request_screen", "bunker")
	await _frames(30)
	await _snap("40_bunker_open")
	var bk: Node = _main.get("_active_node")
	if bk.has_method("set_active_tab"):
		bk.call("set_active_tab", 2)
		await _frames(8)
		await _snap("41_bunker_dilemma_tab")
		bk.call("set_active_tab", 3)
		await _frames(8)
		await _snap("42_bunker_expedition_map")
	print("CAPTURE_DONE ", _out)
	quit(0)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(_out + "/" + name + ".png")
		print("SNAP ", name)
