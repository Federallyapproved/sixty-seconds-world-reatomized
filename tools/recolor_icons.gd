extends SceneTree

## Recolours the game-icons.net source SVGs (assets/icons/source/<author>/<name>.svg, white on a
## black square) into game icons: the background square is removed and the glyph takes the item's
## palette colour from data/items.csv (icon_color). UI icons use the default ink colour.
## Usage: godot --headless --path . -s res://tools/recolor_icons.gd

const UI_ICONS: Dictionary = {
	"cat": ["lorc/cat", "#e8eaed"], "dog": ["delapouite/sitting-dog", "#e8eaed"],
	"radioactive": ["lorc/radioactive", "#ffb020"], "tombstone": ["lorc/tombstone", "#9aa3ad"],
	"hatch": ["delapouite/floor-hatch", "#e8eaed"],
}

func _init() -> void:
	var n: int = 0
	for r_v in DataBuilder.read_csv("res://data/items.csv"):
		var r: Dictionary = r_v
		if str(r.get("icon_source", "")) == "":
			continue
		if _convert(str(r["icon_source"]), str(r.get("icon", "")), str(r.get("icon_color", "#e8eaed"))):
			n += 1
	for k in UI_ICONS.keys():
		var spec: Array = UI_ICONS[k]
		if _convert(str(spec[0]), "res://assets/icons/ui/%s.svg" % k, str(spec[1])):
			n += 1
	print("RECOLOR_ICONS wrote %d icons" % n)
	quit(0)


func _convert(source: String, dest: String, color: String) -> bool:
	var src: String = "res://assets/icons/source/%s.svg" % source
	var svg: String = FileAccess.get_file_as_string(src)
	if svg == "":
		printerr("missing source ", src)
		return false
	svg = svg.replace("<path d=\"M0 0h512v512H0z\"/>", "")
	svg = svg.replace("fill=\"#fff\"", "fill=\"%s\"" % color)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest.get_base_dir()))
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(svg)
	return true
