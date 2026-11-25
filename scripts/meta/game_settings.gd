class_name GameSettings
extends RefCounted

## Player settings kept in user://settings.json: mouse sensitivity, invert-Y and field of view
## for the first-person grab, and the classic top-down grab for machines that can't run 3D well.

const PATH: String = "user://settings.json"
const SENS_MIN: float = 0.05
const SENS_MAX: float = 1.0
const FOV_MIN: float = 60.0
const FOV_MAX: float = 100.0

static var path: String = PATH          # tests point this somewhere else
static var _loaded: bool = false
static var _data: Dictionary = {}
## Set by tests and capture tools: the grab never captures the real mouse, and simulated mouse
## motion turns the view even though the pointer isn't locked.
static var automation: bool = false

const DEFAULTS: Dictionary = {
	"mouse_sensitivity": 0.30,   # degrees of turn per pixel of mouse motion
	"invert_y": false,
	"fov": 75.0,
	"top_down_grab": false,
}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_data = DEFAULTS.duplicate()
	if "--automation" in OS.get_cmdline_user_args():
		automation = true
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in DEFAULTS.keys():
			if (parsed as Dictionary).has(k):
				_data[k] = (parsed as Dictionary)[k]
	_clamp()


static func _clamp() -> void:
	_data["mouse_sensitivity"] = clampf(float(_data.get("mouse_sensitivity", 0.3)), SENS_MIN, SENS_MAX)
	_data["fov"] = clampf(float(_data.get("fov", 75.0)), FOV_MIN, FOV_MAX)
	_data["invert_y"] = bool(_data.get("invert_y", false))
	_data["top_down_grab"] = bool(_data.get("top_down_grab", false))


static func save() -> void:
	_ensure()
	_clamp()
	if automation:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_data, "\t"))


## Forgets what's in memory so the next read loads the file again (tests).
static func forget_cache() -> void:
	_loaded = false


static func get_value(key: String) -> Variant:
	_ensure()
	return _data.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant) -> void:
	_ensure()
	_data[key] = value
	_clamp()


static func mouse_sensitivity() -> float:
	return float(get_value("mouse_sensitivity"))


static func invert_y() -> bool:
	return bool(get_value("invert_y"))


static func fov() -> float:
	return float(get_value("fov"))


static func top_down_grab() -> bool:
	return bool(get_value("top_down_grab"))


## Restores the defaults in memory (tests).
static func reset_for_tests() -> void:
	_loaded = true
	_data = DEFAULTS.duplicate()
	automation = true
