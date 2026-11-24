extends SceneTree

## Runner for pass-2 suites. Suites reference game classes directly, so they are
## loaded only after the autoloads (GameState, SoundManager) exist.
## Usage: godot --headless --path . -s res://tests/pass2/run.gd -- --suite=floorplan_stress [suite args]

func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	await process_frame
	var suite: String = "floorplan_stress"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			suite = a.split("=")[1]
	var scr: GDScript = load("res://tests/pass2/%s.gd" % suite)
	if scr == null:
		push_error("suite not found: " + suite)
		quit(2)
		return
	var node: Node = scr.new()
	root.add_child(node)
	var code: int = await node.run()
	quit(code)
