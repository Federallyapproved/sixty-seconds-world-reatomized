extends Node

## Pictures for the M4 report and the /next/ media page: the title screen with Settings open,
## the same house in the classic top-down grab and in first person (before/after), and the family
## lineup (every role and both bodies) for the character review.
## Needs a display; keep the window off the screen:
##   godot --path . --position 30000,30000 --rendering-driver opengl3 -s res://tools/run_node.gd -- \
##       --script=res://tests/m4/capture_media_m4.gd --out=<dir>

var _out: String = "user://capture_media_m4"
var _main: Control
var _gs: Node


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return fallback


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _snap(name: String) -> void:
	await _frames(5)
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SNAP ", name)


func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var f: Node = _find(c, nm)
		if f != null:
			return f
	return null


func run() -> int:
	_out = _arg("out", _out)
	DirAccess.make_dir_recursive_absolute(_out)
	GameSettings.reset_for_tests()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_gs = get_tree().root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = 11
	await _frames(20)
	# Settings on the title screen.
	if _arg("only", "") == "lineup":
		await _lineup()
		return 0
	var btn: Node = _find(_main, "SettingsButton")
	if btn is BaseButton:
		(btn as BaseButton).pressed.emit()
		await _snap("m4_settings")
		var panel: Node = _find(_main, "SettingsPanel")
		if panel != null:
			panel.queue_free()
	# The same house, top-down then first person.
	for mode in ["before", "after"]:
		GameSettings.set_value("top_down_grab", mode == "before")
		(_gs.get("rng") as RandomNumberGenerator).seed = 11
		_gs.call("request_screen", "osm_house")
		await _frames(30)
		var hs: Node = _main.get("_active_node")
		for b in hs.get("_current_buildings"):
			if int(b.get("osm_id", 0)) == 206082403:
				hs.call("_select_house", b, false)
		_gs.call("request_screen", "scavenge")
		await _frames(30)
		var sc: Node = _main.get("_active_node")
		sc.call("trigger_hud_skip_scout")
		await _frames(10)
		if sc is HouseGrab3D:
			var g: HouseGrab3D = sc
			# Face the nearest item from a step away, so the aim tooltip shows.
			var best: Dictionary = {}
			var bd: float = 1e9
			for it in g._world_items:
				var d: float = (it["pos"] as Vector2).distance_to(g._player_pos)
				if d < bd and d > 70.0:
					bd = d
					best = it
			if not best.is_empty():
				var path: PackedVector2Array = FloorplanGenerator.find_path(g._nav_grid, g._player_pos, best["pos"])
				if path.size() >= 3:
					g._player_pos = path[path.size() - 3]
				var to_i: Vector2 = (best["pos"] as Vector2) - g._player_pos
				g._yaw = atan2(-to_i.x, -to_i.y)
				g._pitch = atan2(0.14 - g._eye_h, to_i.length() / 46.0)
		await _snap("m4_grab_%s" % mode)
		_gs.call("request_screen", "title")
		await _frames(10)
	GameSettings.set_value("top_down_grab", false)
	await _lineup()
	print("CAPTURE_MEDIA_M4 done")
	return 0


## Every role side by side under even light: the family as the game builds it.
func _lineup() -> void:
	_main.visible = false
	var world := Node3D.new()
	get_tree().root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.19)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.72)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(25.0), 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14.0, 8.0)
	fl.mesh = pm
	fl.material_override = HouseBuilder3D.surface_material("wood_floor")
	world.add_child(fl)
	var members: Array = (_gs.get("family_members") as Array).duplicate(true)
	members.append({"id": "g1", "name": "Grandad (example)", "role": "elder", "age": 74, "hair_style": 0, "hair_color": "#9aa0a6", "outfit_color": "#557a46", "shirt_style": 4, "skin_tone": 4, "facial_hair": 2})
	members.append({"id": "g2", "name": "Gran (example)", "role": "elder", "age": 70, "hair_style": 2, "hair_color": "#c9c9c9", "outfit_color": "#7b4b94", "shirt_style": 1, "skin_tone": 0})
	members.append({"id": "k2", "name": "Child, body B (example)", "role": "child", "age": 7, "hair_style": 4, "hair_color": "#e06d2b", "outfit_color": "#d46a84", "shirt_style": 2, "skin_tone": 2})
	var x: float = -float(members.size() - 1) * 0.55
	var labels: Array = []
	for m in members:
		var fig: FamilyFigure3D = FamilyFigure3D.make(m)
		fig.position = Vector3(x, 0.0, 0.0)
		world.add_child(fig)
		fig.play("Idle_Loop", 0.0)
		labels.append([x, "%s · %s %d · body %s" % [str(m.get("name", "")), str(m.get("role", "")), int(m.get("age", 0)), fig.body_kind.to_upper()]])
		x += 1.1
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 42.0
	cam.position = Vector3(0.0, 1.05, 6.2)
	cam.look_at(Vector3(0.0, 0.85, 0.0))
	cam.make_current()
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var lab := Label.new()
	lab.position = Vector2(20, 16)
	lab.add_theme_font_size_override("font_size", 16)
	lab.text = "Family figures as built in the grab (Quaternius Universal Base Characters, free tier: athletic bodies A and B; clothes painted by shader)"
	layer.add_child(lab)
	await _frames(20)
	for l in labels:
		var sp: Vector2 = cam.unproject_position(Vector3(float(l[0]), 0.0, 0.6))
		var t := Label.new()
		t.text = str(l[1]).replace(" · ", "\n")
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.09))
		t.add_theme_constant_override("outline_size", 5)
		t.size = Vector2(130, 50)
		t.position = sp - Vector2(65, -4)
		layer.add_child(t)
	await _snap("m4_family_lineup")
	world.queue_free()
	_main.visible = true
