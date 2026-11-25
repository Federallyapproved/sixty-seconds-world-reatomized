extends SceneTree

## Compiles data/*.csv and data/events/*.json into data/build/*.json, regenerates CREDITS.md and
## fails (exit 1) on any validation error.
## Usage: godot --headless --path . -s res://tools/build_data.gd [-- --check]   (--check: validate only)

func _init() -> void:
	var write: bool = not ("--check" in OS.get_cmdline_user_args())
	var res: Dictionary = DataBuilder.build(write)
	var errs: Array = res["errors"]
	for w in res["warnings"]:
		print("WARN  ", w)
	for e in errs:
		printerr("ERROR ", e)
	var o: Dictionary = res["out"]
	print("DATA_BUILD items=%d events=%d narration=%d loot_places=%d errors=%d" % [
		(o.get("items", {}) as Dictionary).size(), (o.get("events", {}) as Dictionary).size(),
		(o.get("narration", {}) as Dictionary).size(), (o.get("loot", {}) as Dictionary).size(), errs.size()])
	quit(0 if errs.is_empty() else 1)
