extends Node

## Where the first-person grab's draw calls go: from the start view and a turn around the house,
## measures the frame with everything on, then without the room shadow, items, item outlines and
## the family, and prints the counts. Needs a display (draw calls aren't counted headless).
##   godot --path . --rendering-driver opengl3 -s res://tools/run_node.gd -- --script=res://tests/m4/perf_probe.gd [--osm=<id>]

var _gs: Node
var _main: Control


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return fallback


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _measure(g: HouseGrab3D) -> Vector2i:
	var dc: int = 0
	var tri: int = 0
	for k in range(8):
		g._yaw = float(k) * TAU / 8.0
		await _frames(3)
		dc = maxi(dc, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		tri = maxi(tri, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	return Vector2i(dc, tri)


func run() -> int:
	GameSettings.reset_for_tests()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_gs = get_tree().root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = 11
	await _frames(8)
	_gs.call("request_screen", "osm_house")
	await _frames(30)
	var hs: Node = _main.get("_active_node")
	var want: int = int(_arg("osm", "206082403"))
	for b in hs.get("_current_buildings"):
		if int(b.get("osm_id", 0)) == want:
			hs.call("_select_house", b, false)
	_gs.call("request_screen", "scavenge")
	await _frames(20)
	var g: HouseGrab3D = _main.get("_active_node")
	g.set_process(false)
	g._pitch = -0.1
	var base: Vector2i = await _measure(g)
	print("PERF all on: draw calls %d, triangles %d" % [base.x, base.y])
	g._hud.visible = false
	var no_hud: Vector2i = await _measure(g)
	print("PERF without the HUD: %d" % no_hud.x)
	g._hud.visible = true
	g._shadow_spot.shadow_enabled = false
	var no_sh: Vector2i = await _measure(g)
	print("PERF no shadow: %d (%d)" % [no_sh.x, no_sh.y])
	for n in g._item_nodes.values():
		PropLibrary._apply_overlay(n, null)
	var no_ol: Vector2i = await _measure(g)
	print("PERF no shadow, no item outlines: %d" % no_ol.x)
	for n in g._item_nodes.values():
		(n as Node3D).visible = false
	var no_it: Vector2i = await _measure(g)
	print("PERF no shadow, no items: %d" % no_it.x)
	for n in g._family_nodes.values():
		(n as Node3D).visible = false
	var no_fam: Vector2i = await _measure(g)
	print("PERF no shadow, no items, no family: %d (%d)" % [no_fam.x, no_fam.y])
	var meshes: int = 0
	var surfaces: int = 0
	for rm in g._house3d.get("rooms", []):
		for c in (rm["node"] as Node).get_children():
			if c is MeshInstance3D:
				meshes += 1
				surfaces += (c as MeshInstance3D).mesh.get_surface_count()
	g._hud.visible = false
	var bare: Vector2i = await _measure(g)
	print("PERF house only, no HUD: %d (%d)" % [bare.x, bare.y])
	print("PERF house: %d room meshes, %d surfaces, %d rooms" % [meshes, surfaces, (g._house3d.get("rooms", []) as Array).size()])
	return 0
