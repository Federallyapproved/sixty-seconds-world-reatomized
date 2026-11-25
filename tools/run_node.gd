extends SceneTree

## Runs a Node script that has `func run() -> int` after the autoloads exist.
## Usage: godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/sim_harness.gd [args]

func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	await process_frame
	var path: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--script="):
			path = a.substr(9)
	var scr: GDScript = load(path)
	if scr == null:
		push_error("script not found: " + path)
		quit(2)
		return
	var node: Node = scr.new()
	root.add_child(node)
	var code: int = await node.run()
	quit(code)
