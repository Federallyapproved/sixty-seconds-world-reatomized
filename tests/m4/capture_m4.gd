extends Node

## Renders the first-person grab for review: for each house, the opening view, four turns of
## the look-around, the view walking up to the nearest item, and an overhead cut-away (ceilings
## hidden) to check the layout against the floorplan.
## Needs a display (a normal no-focus window via override.cfg):
##   godot --path . --rendering-driver opengl3 -s res://tools/run_node.gd -- --script=res://tests/m4/capture_m4.gd --out=<dir> [--houses=3] [--seed=7]

var _out: String = "user://capture_m4"
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
	await _frames(4)
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("SNAP ", name)


func run() -> int:
	_out = _arg("out", _out)
	DirAccess.make_dir_recursive_absolute(_out)
	GameSettings.reset_for_tests()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_gs = get_tree().root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = int(_arg("seed", "7"))
	await _frames(8)
	_gs.call("request_screen", "osm_house")
	await _frames(30)
	var hs: Node = _main.get("_active_node")
	var buildings: Array = hs.get("_current_buildings")
	var want: int = int(_arg("houses", "2"))
	var ids: Array = []
	var only: String = _arg("osm", "")
	for b in buildings:
		if only != "" and str(b.get("osm_id", "")) != only:
			continue
		if ids.size() < want:
			ids.append(b)
	var hn: int = 0
	for b in ids:
		hs = _main.get("_active_node")
		if hs == null or not hs.has_method("_select_house"):
			_gs.call("request_screen", "osm_house")
			await _frames(20)
			hs = _main.get("_active_node")
		hs.call("_select_house", b, false)
		_gs.call("request_screen", "scavenge")
		await _frames(30)
		var sc: Node = _main.get("_active_node")
		if not (sc is HouseGrab3D):
			print("CAPTURE: not the 3D grab")
			return 1
		var g: HouseGrab3D = sc
		var tag: String = "h%d_%s" % [hn, str(b.get("osm_id", ""))]
		await _snap(tag + "_a_start")
		for k in range(4):
			g._yaw += PI * 0.5
			await _snap("%s_b_look%d" % [tag, k])
		# Walk next to the nearest item and look at it.
		var best: Dictionary = {}
		var best_d: float = 1e9
		for it in g._world_items:
			var d: float = (it["pos"] as Vector2).distance_to(g._player_pos)
			if d < best_d and d > 60.0:
				best_d = d
				best = it
		if not best.is_empty():
			var tp: Vector2 = best["pos"]
			var path: PackedVector2Array = FloorplanGenerator.find_path(g._nav_grid, g._player_pos, tp)
			var stand: Vector2 = tp
			if path.size() >= 2:
				stand = path[maxi(0, path.size() - 3)]
			g._player_pos = stand
			var to_i: Vector2 = tp - stand
			g._yaw = atan2(-to_i.x, -to_i.y)
			g._pitch = -0.45
			g._phase = ScavengeScene.Phase.SCAVENGE
			await _snap(tag + "_c_item")
		# Family member in view.
		for f in g._world_family:
			var fp: Vector2 = f["pos"]
			var path2: PackedVector2Array = FloorplanGenerator.find_path(g._nav_grid, g._hatch_pos, fp)
			if path2.size() >= 3:
				g._player_pos = path2[path2.size() - 3]
				var to_f: Vector2 = fp - g._player_pos
				g._yaw = atan2(-to_f.x, -to_f.y)
				g._pitch = -0.12
				await _snap("%s_d_family_%s" % [tag, str(f["name"])])
		# Overhead cut-away.
		for rm in g._house3d.get("rooms", []):
			var ce: Node = (rm["node"] as Node).get_node_or_null("Ceiling")
			if ce != null:
				ce.visible = false
		var cam: Camera3D = g.camera_3d()
		var c: Vector2 = g._house_bounds.get_center()
		var span: float = maxf(g._house_bounds.size.x, g._house_bounds.size.y) / 46.0
		g.set_process(false)
		HouseGrab3D._set_visibility_range(g._world, 0.0)
		cam.transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), HouseBuilder3D.to3(c, span * 0.72 + 2.5))
		cam.fov = 70.0
		g._hud.visible = false
		await _snap(tag + "_e_overhead")
		g._hud.visible = true
		g.set_process(true)
		hn += 1
		_gs.call("request_screen", "osm_house")
		await _frames(20)
	print("CAPTURE_M4 done houses=%d" % hn)
	return 0
