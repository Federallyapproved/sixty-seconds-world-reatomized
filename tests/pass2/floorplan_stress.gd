extends Node

## Generates floorplans for many real OSM buildings from the bundled presets and
## verifies: level stays inside the real footprint, every open room is reachable
## from the hatch, every item/family spawn is reachable, room count tracks area,
## and different seeds give different layouts. Optional --sheet=<png> renders a
## contact sheet (needs a display).

var _fails: Array[String] = []
var _passes: int = 0
var _sheet_layouts: Array = []


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
	return fallback


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails.append(msg)
		print("[FAIL] ", msg)


func run() -> int:
	var per_preset: int = int(_arg("per", "20"))
	var sheet: String = _arg("sheet", "")
	var rng := RandomNumberGenerator.new()
	var fam: Array = GameState.get("family_members")
	var t0: int = Time.get_ticks_msec()
	var area_rooms: Array = []
	var n_total: int = 0
	for preset in ["seattle", "concord", "brooklyn"]:
		var parsed: Dictionary = OsmService.load_preset(preset)
		GameState.set("map_roads", parsed.get("roads", []))
		var bl: Array = parsed.get("buildings", [])
		bl.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["area_sqm"]) < float(b["area_sqm"]))
		var picks: Array = []
		for i in range(per_preset):
			picks.append(bl[int(float(i) / float(per_preset) * float(bl.size() - 1))])
		for b_v in picks:
			var b: Dictionary = b_v
			rng.seed = int(b["osm_id"]) % 100000
			var t_start: int = Time.get_ticks_msec()
			var lay: Dictionary = HouseGenerator.generate_from_osm_house(b, fam, rng)
			var dt: int = Time.get_ticks_msec() - t_start
			n_total += 1
			var tag: String = "%s way %d (%.0f m2)" % [preset, int(b["osm_id"]), float(b["area_sqm"])]
			_verify(tag, lay, b)
			var meta: Dictionary = lay["meta"]
			area_rooms.append([float(b["area_sqm"]), int(meta["room_count"]), dt])
			if _sheet_layouts.size() < 12 and (n_total % 5 == 0):
				_sheet_layouts.append({"lay": lay, "tag": "%s %d m2 %d rooms" % [preset, int(b["area_sqm"]), int(meta["room_count"])]})
	# seed variety
	var parsed2: Dictionary = OsmService.load_preset("seattle")
	var house: Dictionary = OsmService.pick_best_house(parsed2["buildings"], 47.624, -122.3195, 206082403)
	var sigs: Dictionary = {}
	for s in range(6):
		rng.seed = 77 + s
		var l2: Dictionary = HouseGenerator.generate_from_osm_house(house, fam, rng)
		var sig: String = ""
		for r in l2["rooms"]:
			sig += "%s@%d,%d;" % [str(r["name"]), int((r["center"] as Vector2).x), int((r["center"] as Vector2).y)]
		sigs[sig] = true
	_ok(sigs.size() >= 4, "randomized floorplans: only %d distinct layouts across 6 seeds" % sigs.size())
	print("distinct layouts over 6 seeds for way 206082403: ", sigs.size())
	# rooms vs area monotonic trend
	area_rooms.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var small_avg: float = 0.0
	var big_avg: float = 0.0
	var third: int = area_rooms.size() / 3
	for i in range(third):
		small_avg += float(area_rooms[i][1])
		big_avg += float(area_rooms[area_rooms.size() - 1 - i][1])
	small_avg /= float(third)
	big_avg /= float(third)
	print("avg rooms: smallest third %.1f, largest third %.1f" % [small_avg, big_avg])
	_ok(big_avg > small_avg + 2.0, "room count does not scale with building size (%.1f vs %.1f)" % [small_avg, big_avg])
	var max_ms: int = 0
	for ar in area_rooms:
		max_ms = maxi(max_ms, int(ar[2]))
	print("generated %d layouts in %d ms (slowest %d ms)" % [n_total, Time.get_ticks_msec() - t0, max_ms])
	for ar in area_rooms:
		print("  area %.0f m2 -> %d rooms (%d ms)" % [float(ar[0]), int(ar[1]), int(ar[2])])
	print("FLOORPLAN_STRESS passes=%d fails=%d" % [_passes, _fails.size()])
	if sheet != "":
		await _render_sheet(sheet)
	return 0 if _fails.is_empty() else 1


func _verify(tag: String, lay: Dictionary, b: Dictionary) -> void:
	var nav: Dictionary = lay["nav_grid"]
	var poly: PackedVector2Array = lay["outer_polygon"]
	var rooms: Array = lay["rooms"]
	var meta: Dictionary = lay["meta"]
	_ok(poly.size() >= 3, tag + ": no footprint polygon")
	# Footprint matches the real OSM polygon area (within scale^2)
	var area_px: float = absf(FloorplanGenerator._signed_area_packed(poly))
	var expect_px: float = float(meta["real_area_m2"]) * pow(float(meta["scale"]) * FloorplanGenerator.PX_PER_M, 2.0)
	_ok(absf(area_px - expect_px) / maxf(1.0, expect_px) < 0.12, tag + ": playable footprint area %.0f differs from OSM area %.0f" % [area_px, expect_px])
	_ok(Geometry2D.is_point_in_polygon(lay["hatch_pos"], poly), tag + ": hatch outside footprint")
	_ok(FloorplanGenerator.is_reachable(nav, lay["leader_start_pos"]), tag + ": leader start unreachable")
	var counts: Array = nav["room_reachable_cells"]
	for i in range(rooms.size()):
		var r: Dictionary = rooms[i]
		if bool(r.get("sealed", false)):
			continue
		_ok(int(counts[i]) > 0, tag + ": room '%s' unreachable" % str(r["name"]))
	for it in lay["items"]:
		var p: Vector2 = it["pos"]
		_ok(Geometry2D.is_point_in_polygon(p, poly), tag + ": item %s outside footprint" % str(it["item_id"]))
		_ok(FloorplanGenerator.reachable_near(nav, p, 44.0), tag + ": item %s not reachable" % str(it["item_id"]))
	for f in lay["family_spawns"]:
		_ok(FloorplanGenerator.is_reachable(nav, f["pos"]), tag + ": family %s unreachable" % str(f["name"]))
	# Doors must be wide enough for the player (diameter 28 px)
	for d in lay["doorways"]:
		_ok(float(d["width"]) >= 40.0, tag + ": door too narrow")
	# A path from hatch to every family member exists
	for f2 in lay["family_spawns"]:
		var path: PackedVector2Array = HouseGenerator.find_path(nav, lay["hatch_pos"], f2["pos"])
		_ok(path.size() >= 2 and path[path.size() - 1].distance_to(f2["pos"]) < 30.0, tag + ": no path hatch->%s" % str(f2["name"]))


func _render_sheet(path: String) -> void:
	var canvas := _SheetCanvas.new()
	canvas.layouts = _sheet_layouts
	canvas.size = Vector2(1280, 720)
	get_tree().root.add_child(canvas)
	for _i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	print("SHEET ", path)


class _SheetCanvas extends Control:
	var layouts: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1d211d"))
		var font: Font = ThemeDB.fallback_font
		for i in range(layouts.size()):
			var cell := Rect2(Vector2(float(i % 4) * 320.0, float(i / 4) * 240.0), Vector2(320, 240))
			var lay: Dictionary = layouts[i]["lay"]
			var b: Rect2 = lay["bounds"]
			var s: float = minf((cell.size.x - 20.0) / b.size.x, (cell.size.y - 40.0) / b.size.y)
			var off: Vector2 = cell.position + Vector2(10, 28) - b.position * s + (Vector2(cell.size.x - 20.0, cell.size.y - 40.0) - b.size * s) * 0.5
			draw_set_transform(off, 0.0, Vector2(s, s))
			draw_colored_polygon(lay["outer_polygon"], Color("#e4d5b7"))
			var cols: Array = [Color("#d8c7a2"), Color("#c9d8c0"), Color("#d9c2b8"), Color("#c2cfd9"), Color("#d6d2a8"), Color("#cdbfd8")]
			var k: int = 0
			for r in lay["rooms"]:
				var rp: PackedVector2Array = r["polygon"]
				if rp.size() >= 3:
					draw_colored_polygon(rp, Color("#444") if bool(r.get("sealed", false)) else cols[k % cols.size()])
				k += 1
			for f in lay["furniture"]:
				draw_rect(f["rect"], Color("#7a5434") if bool(f.get("solid", true)) else Color(0.6, 0.3, 0.3, 0.3))
			for w in lay["walls"]:
				if w.has("rect"):
					draw_rect(w["rect"], Color("#2a241e"))
				else:
					draw_line(w["a"], w["b"], Color("#1a1612"), float(w["thickness"]))
			for e in lay.get("entrances", []):
				draw_line(e["center"] - e["dir"] * 25.0, e["center"] + e["dir"] * 25.0, Color("#d94c2a"), 10.0)
			draw_circle(lay["hatch_pos"], 40.0, Color("#f2b82e"))
			for it in lay["items"]:
				draw_circle(it["pos"], 9.0, Color("#3b8ec2"))
			for fs in lay["family_spawns"]:
				draw_circle(fs["pos"], 13.0, Color("#7ec850"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_string(font, cell.position + Vector2(10, 18), str(layouts[i]["tag"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#efe3c8"))
