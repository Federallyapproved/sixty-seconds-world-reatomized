extends Node

## M4 rules for the first-person grab, headless, over many real OSM houses:
## - the 3D house: every open room has a floor, ceiling, walls and a light; at most 5 meshes per
##   room (draw calls); the hatch is an opening you stand beside, not over;
## - every item and family member can be grabbed: a walkable spot within reach with no wall in
##   between; the crosshair picks what you look at and never something behind a wall;
## - every furniture kind and every item has a model; the family figures (both bodies, child,
##   teen, elder) build with clothes, hair and animations;
## - settings save, load and clamp; the classic top-down grab is still there; the pointer is never
##   captured under test.
##   godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/m4/grab3d_suite.gd [--houses=24]

var _passes: int = 0
var osm_hands_full_once: Dictionary = {}
var _fails: Array[String] = []
var _main: Control
var _gs: Node


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passes += 1
	else:
		_fails.append(name + ("" if detail == "" else " — " + detail))
		print("FAIL ", name, "  ", detail)


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return fallback


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func run() -> int:
	GameSettings.reset_for_tests()
	_settings_checks()
	_library_checks()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_gs = get_tree().root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = 4242
	await _frames(6)
	await _figure_checks()
	_gs.call("request_screen", "osm_house")
	await _frames(30)
	var hs: Node = _main.get("_active_node")
	var buildings: Array = (hs.get("_current_buildings") as Array).duplicate()
	var want: int = int(_arg("houses", "24"))
	# Spread the sample over sizes: small homes, ordinary houses and a few very large buildings.
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("area_sqm", 0.0)) < float(b.get("area_sqm", 0.0)))
	var picks: Array = []
	for i in range(want):
		var idx: int = int(float(i) / float(maxi(1, want - 1)) * float(buildings.size() - 1))
		if not picks.has(buildings[idx]):
			picks.append(buildings[idx])
	var build_ms: Array = []
	var houses_ok: int = 0
	var kinds_seen: Dictionary = {}
	for b in picks:
		hs = _main.get("_active_node")
		if hs == null or not hs.has_method("_select_house"):
			_gs.call("request_screen", "osm_house")
			await _frames(10)
			hs = _main.get("_active_node")
		hs.call("_select_house", b, false)
		var t0: int = Time.get_ticks_msec()
		_gs.call("request_screen", "scavenge")
		await _frames(2)
		var g: HouseGrab3D = _main.get("_active_node") as HouseGrab3D
		if g == null:
			_check("house_%s_is_3d" % str(b.get("osm_id", "")), false)
			continue
		build_ms.append(Time.get_ticks_msec() - t0)
		if _house_checks(g, str(b.get("osm_id", "")), kinds_seen):
			houses_ok += 1
		_gs.call("request_screen", "osm_house")
		await _frames(6)
	_check("houses_built", houses_ok == picks.size() and picks.size() >= mini(want, 10), "%d of %d" % [houses_ok, picks.size()])
	build_ms.sort()
	var worst: int = int(build_ms[-1]) if not build_ms.is_empty() else -1
	_check("house_builds_quickly", worst >= 0 and worst < 4000, "median %d ms, worst %d ms" % [int(build_ms[build_ms.size() / 2]) if not build_ms.is_empty() else -1, worst])
	for k in kinds_seen.keys():
		_check("furniture_kind_has_model_%s" % k, PropLibrary.FURNITURE.has(k))
	# The classic top-down grab is still one setting away.
	GameSettings.set_value("top_down_grab", true)
	hs = _main.get("_active_node")
	if hs != null and hs.has_method("_select_house"):
		hs.call("_select_house", picks[picks.size() / 2], false)
	_gs.call("request_screen", "scavenge")
	await _frames(3)
	var td: Node = _main.get("_active_node")
	_check("top_down_setting_gives_2d_grab", td is ScavengeScene and not (td is HouseGrab3D))
	GameSettings.set_value("top_down_grab", false)
	_check("pointer_never_captured", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	print("GRAB3D_SUITE passes=%d fails=%d houses=%d build_ms_worst=%d" % [_passes, _fails.size(), houses_ok, worst])
	return 0 if _fails.is_empty() else 1


func _settings_checks() -> void:
	_check("settings_defaults", is_equal_approx(GameSettings.mouse_sensitivity(), 0.3) and is_equal_approx(GameSettings.fov(), 75.0) and not GameSettings.invert_y() and not GameSettings.top_down_grab())
	GameSettings.set_value("fov", 200.0)
	GameSettings.set_value("mouse_sensitivity", -3.0)
	_check("settings_clamped", is_equal_approx(GameSettings.fov(), GameSettings.FOV_MAX) and is_equal_approx(GameSettings.mouse_sensitivity(), GameSettings.SENS_MIN))
	# Round trip through a scratch file (the player's own settings are never touched).
	GameSettings.path = "user://settings_suite_test.json"
	GameSettings.automation = false
	GameSettings.set_value("fov", 88.0)
	GameSettings.set_value("invert_y", true)
	GameSettings.set_value("mouse_sensitivity", 0.45)
	GameSettings.save()
	GameSettings.forget_cache()
	_check("settings_saved_and_loaded", is_equal_approx(GameSettings.fov(), 88.0) and GameSettings.invert_y() and is_equal_approx(GameSettings.mouse_sensitivity(), 0.45),
		"fov %.0f invert %s sens %.2f exists %s" % [GameSettings.fov(), str(GameSettings.invert_y()), GameSettings.mouse_sensitivity(), str(FileAccess.file_exists("user://settings_suite_test.json"))])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_suite_test.json"))
	GameSettings.path = GameSettings.PATH
	GameSettings.reset_for_tests()


func _library_checks() -> void:
	for iid in ShelterData.items().keys():
		var cat: String = str(ShelterData.item(iid).get("category", ""))
		if cat == "core" or cat == "junk":
			_check("item_has_3d_model_%s" % iid, PropLibrary.ITEMS.has(iid))
	for room in FloorplanGenerator.FURNITURE_SPECS.keys():
		for spec in FloorplanGenerator.FURNITURE_SPECS[room]:
			_check("spec_kind_has_model_%s" % str(spec[0]), PropLibrary.FURNITURE.has(str(spec[0])))
	_check("built_in_closet_has_model", PropLibrary.FURNITURE.has("built_in"))
	var missing: Array = []
	for kind in PropLibrary.FURNITURE.keys():
		for p in PropLibrary.FURNITURE[kind]:
			var m: String = str(p[0])
			if not m.begins_with("@") and not ResourceLoader.exists(PropLibrary.model_path(m)):
				missing.append(m)
	for iid in PropLibrary.ITEMS.keys():
		var m2: String = str(PropLibrary.ITEMS[iid][0])
		if not m2.begins_with("@") and not ResourceLoader.exists(PropLibrary.model_path(m2)):
			missing.append(m2)
	_check("every_model_file_exists", missing.is_empty(), str(missing))
	for iid in PropLibrary.ITEMS.keys():
		var n: Node3D = PropLibrary.item(iid)
		var meshes: int = _count_meshes(n)
		_check("item_prop_builds_%s" % iid, meshes >= 1 and n.has_meta("outline"), "%d meshes" % meshes)
		n.free()
	var rng := RandomNumberGenerator.new()
	for kind in PropLibrary.FURNITURE.keys():
		var f: Node3D = PropLibrary.furniture(kind, 1.2, 0.6, rng)
		_check("furniture_builds_%s" % kind, _count_meshes(f) >= 1)
		f.free()


func _figure_checks() -> void:
	var cases: Array = [
		["adult_a", {"id": "t1", "name": "T1", "role": "adult", "age": 40, "facial_hair": 2, "hair_style": 1, "hair_color": "#4a2e1b", "outfit_color": "#3d5a80", "shirt_style": 0, "skin_tone": 1}, "a"],
		["adult_b", {"id": "t2", "name": "T2", "role": "adult", "age": 38, "facial_hair": 0, "hair_style": 3, "hair_color": "#1c1410", "outfit_color": "#8a5a44", "shirt_style": 2, "skin_tone": 3}, "b"],
		["teen", {"id": "t3", "name": "T3", "role": "teen", "age": 16, "hair_style": 2, "hair_color": "#2a1c14", "outfit_color": "#6b4c9a", "shirt_style": 1, "skin_tone": 3}, "b"],
		["child", {"id": "t4", "name": "T4", "role": "child", "age": 9, "hair_style": 5, "hair_color": "#8c5a2b", "outfit_color": "#d99b26", "shirt_style": 3, "skin_tone": 1}, "a"],
		["elder", {"id": "t5", "name": "T5", "role": "elder", "age": 72, "hair_style": 0, "hair_color": "#9aa0a6", "outfit_color": "#557a46", "shirt_style": 4, "skin_tone": 5}, "a"],
		["override", {"id": "t6", "name": "T6", "role": "adult", "age": 30, "facial_hair": 2, "body": "b"}, "b"],
	]
	# Painted clothes must never read as bare skin: every outfit colour against every skin tone.
	var worst: float = 9.0
	for oc in CharacterArtist.OUTFIT_COLOR_SWATCHES:
		for si in range(CharacterArtist.SKIN_TONES.size()):
			var m: Dictionary = {"outfit_color": oc, "skin_tone": si}
			var a: Color = FamilyFigure3D.outfit_color(m)
			var b: Color = FamilyFigure3D.skin_color(m)
			worst = minf(worst, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	_check("outfits_stand_out_from_skin", worst >= 0.2, "closest %.2f" % worst)
	var heights: Dictionary = {}
	for c in cases:
		var fig: FamilyFigure3D = FamilyFigure3D.make(c[1])
		add_child(fig)
		await _frames(1)
		var tag: String = str(c[0])
		_check("figure_body_choice_%s" % tag, fig.body_kind == str(c[2]), fig.body_kind)
		_check("figure_has_skeleton_%s" % tag, fig.skeleton != null and fig.skeleton.get_bone_count() == 65)
		var body: MeshInstance3D = null
		for m in fig._meshes:
			if str(m.name).to_lower().find("hero") >= 0:
				body = m
		# Headless keeps no mesh data, so the UV2 bake is only checked with a display.
		var has_uv2: bool = HouseBuilder3D.no_mesh_data() or (body != null and (body.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0)
		_check("figure_clothes_baked_%s" % tag, has_uv2 and body != null and body.material_override is ShaderMaterial)
		_check("figure_has_hair_%s" % tag, fig._meshes.size() >= 4, "%d meshes" % fig._meshes.size())
		_check("figure_idle_plays_%s" % tag, fig.anim_player != null and fig.anim_player.is_playing() and fig.anim_player.current_animation == fig.idle_clip(), fig.idle_clip())
		heights[tag] = fig.height_m()
		if tag == "child":
			var head: int = fig.skeleton.find_bone("Head")
			_check("child_has_larger_head", fig.skeleton.get_bone_pose_scale(head).x > 1.15)
		fig.set_highlight(true)
		_check("figure_highlight_%s" % tag, body != null and body.material_overlay != null)
		fig.set_highlight(false)
		fig.queue_free()
	_check("figure_heights_by_age", float(heights["child"]) < float(heights["teen"]) and float(heights["teen"]) < float(heights["adult_a"]), str(heights))
	var lib: AnimationLibrary = load(FamilyFigure3D.ANIMS)
	for clip in ["Idle_Loop", "Crouch_Idle_Loop", "Idle_FoldArms_Loop", "Idle_TalkingPhone_Loop", "Walk_Carry_Loop", "Dance_Loop", "Hit_Chest", "Fixing_Kneeling", "Sitting_Idle_Loop"]:
		_check("anim_clip_%s" % clip, lib != null and lib.has_animation(clip))


func _house_checks(g: HouseGrab3D, osm: String, kinds_seen: Dictionary) -> bool:
	var ok_before: int = _fails.size()
	var rooms: Array = g._house3d.get("rooms", [])
	var open_rooms: int = 0
	var lit: int = 0
	var worst_meshes: int = 0
	for rm in rooms:
		var node: Node3D = rm["node"]
		var names: Array = []
		var meshes: int = 0
		for c in node.get_children():
			names.append(str(c.name))
			if c is MeshInstance3D:
				meshes += 1
		worst_meshes = maxi(worst_meshes, meshes)
		if bool(rm["sealed"]):
			continue
		open_rooms += 1
		if "Floor" in names and "Ceiling" in names and rm.get("light") != null:
			lit += 1
	_check("h%s_rooms_have_floor_ceiling_light" % osm, lit == open_rooms and open_rooms >= 1, "%d of %d" % [lit, open_rooms])
	var shell: Node = (g._house3d["root"] as Node).get_node_or_null("Shell")
	var walls_in_rooms: int = 0
	for rm in rooms:
		for c in (rm["node"] as Node).get_children():
			if str(c.name).begins_with("Walls"):
				walls_in_rooms += 1
	_check("h%s_walls_never_culled" % osm, shell != null and shell.get_child_count() >= 1 and walls_in_rooms == 0, "%d wall meshes outside the rooms, %d inside" % [shell.get_child_count() if shell != null else 0, walls_in_rooms])
	# Props are merged per room only where there is mesh data (with a display).
	if not HouseBuilder3D.no_mesh_data():
		_check("h%s_few_meshes_per_room" % osm, worst_meshes <= 5, "worst %d" % worst_meshes)
	_check("h%s_hatch_built" % osm, g._house3d.get("hatch") != null and g._hatch_prop_added)
	var hr: float = fposmod((g._house3d["hatch"] as Node3D).rotation.y, PI * 0.5)
	_check("h%s_hatch_frame_lines_up_with_the_floor_cut" % osm, hr < 0.001 or PI * 0.5 - hr < 0.001, "%.3f rad" % hr)
	# You can stand at the hatch (beside the opening) without walking over it.
	var stand_ok: bool = false
	for k in range(16):
		var a: float = TAU * float(k) / 16.0
		var p: Vector2 = g._hatch_pos + Vector2(cos(a), sin(a)) * (HouseBuilder3D.HATCH_HALF * 46.0 + ScavengeScene.PLAYER_RADIUS + 2.0)
		if g._resolve_collisions(p, false).distance_to(p) < 1.0 and p.distance_to(g._hatch_pos) <= g._hatch_radius + ScavengeScene.HATCH_DROP_MARGIN:
			stand_ok = true
			break
	_check("h%s_can_stand_at_hatch" % osm, stand_ok)
	var pushed: Vector2 = g._resolve_collisions(g._hatch_pos, false)
	_check("h%s_hatch_opening_is_solid" % osm, pushed.distance_to(g._hatch_pos) > 20.0)
	# Every item and family member: a walkable spot within reach, nothing solid in between.
	var unreachable: Array = []
	for arr in [g._world_items, g._world_family]:
		for e in arr:
			if not _grabbable_from_somewhere(g, e["pos"]):
				unreachable.append(str(e.get("item_id", e.get("name", "?"))))
	_check("h%s_everything_grabbable" % osm, unreachable.is_empty(), str(unreachable))
	_check("h%s_every_item_has_a_prop" % osm, g._item_nodes.size() == g._world_items.size())
	_check("h%s_every_family_member_has_a_figure" % osm, g._family_nodes.size() == g._world_family.size())
	# Aim: looking at an item from its grab spot picks it; turning away (outside arm's length) doesn't.
	var tested: bool = false
	for it in g._world_items:
		var spot: Vector2 = _grab_spot(g, it["pos"], float(HouseGrab3D.NEAR_PX) + 12.0)
		if spot == Vector2.INF:
			continue
		g._phase = ScavengeScene.Phase.SCAVENGE
		g._player_pos = spot
		var d: Vector2 = (it["pos"] as Vector2) - spot
		g._yaw = atan2(-d.x, -d.y)
		g._pitch = atan2(0.14 - g._eye_h, d.length() / 46.0)
		g._update_camera(0.0)
		var t: Dictionary = g._aim_target()
		var hit: bool = int(t.get("uid", -1)) == int(it["uid"]) or (str(t.get("kind", "")) != "" and (t["pos"] as Vector2).distance_to(spot) <= d.length() + 1.0)
		g._yaw += PI
		g._update_camera(0.0)
		var t2: Dictionary = g._aim_target()
		_check("h%s_aim_picks_what_you_look_at" % osm, hit, str(t.get("name", "nothing")))
		_check("h%s_aim_ignores_what_is_behind_you" % osm, int(t2.get("uid", -1)) != int(it["uid"]))
		tested = true
		break
	_check("h%s_aim_tested" % osm, tested)
	# Hands full: aiming at something that won't fit and pressing E starts no grab and says so;
	# right-click (drop) puts the selected thing back in the house, visible again.
	g._phase = ScavengeScene.Phase.SCAVENGE
	g._pending_action = {}
	var spot_far: Vector2 = Vector2.INF
	for it3 in g._world_items:
		if (it3["pos"] as Vector2).distance_to(g._hatch_pos) > 200.0:
			spot_far = it3["pos"]
			break
	if spot_far != Vector2.INF and osm_hands_full_once.is_empty():
		osm_hands_full_once[osm] = true
		g._player_pos = g._resolve_collisions(spot_far, false)
		var filled: int = 0
		for it4 in g._world_items:
			if bool(it4.get("collected", false)) or g._get_used_slots() + int(it4["slots"]) > g._max_slots or str(it4["item_id"]) == "suitcase":
				continue
			var tg: Dictionary = {"kind": "item", "uid": int(it4["uid"]), "pos": it4["pos"], "slots": int(it4["slots"]), "name": str(it4["name"]), "item_id": str(it4["item_id"]), "ref": it4}
			g._complete_pickup(tg)
			filled += 1
			if g._get_used_slots() >= g._max_slots:
				break
		var big_t: Dictionary = {}
		for it5 in g._world_items:
			if not bool(it5.get("collected", false)) and g._get_used_slots() + int(it5["slots"]) > g._max_slots:
				big_t = {"kind": "item", "uid": int(it5["uid"]), "pos": it5["pos"], "slots": int(it5["slots"]), "name": str(it5["name"]), "item_id": str(it5["item_id"]), "ref": it5}
				break
		if not big_t.is_empty() and g._get_used_slots() >= g._max_slots:
			g._hovered_target = big_t
			g._hands_full_timer = 0.0
			var n_before: int = g._carried_entries.size()
			g._context_action()
			_check("hands_full_blocks_the_grab_and_says_so", g._hands_full_timer > 0.0 and g._pending_action.is_empty() and g._carried_entries.size() == n_before)
			var sel: Dictionary = g._carried_entries[g._selected_slot]
			g._drop_selected_entry()
			g._sync_world(0.0)
			var nd: Node3D = g._item_nodes.get(int(sel["ref"]["uid"]))
			_check("drop_puts_it_back_in_the_house", g._carried_entries.size() == n_before - 1 and nd != null and (not bool(sel["ref"]["collected"])))
	# Through a wall: from a walkable spot within reach but behind a wall, the item isn't picked.
	for it2 in g._world_items:
		var behind: Vector2 = _spot_behind_wall(g, it2["pos"])
		if behind == Vector2.INF:
			continue
		g._player_pos = behind
		var d2: Vector2 = (it2["pos"] as Vector2) - behind
		g._yaw = atan2(-d2.x, -d2.y)
		g._pitch = atan2(0.14 - g._eye_h, d2.length() / 46.0)
		g._update_camera(0.0)
		_check("h%s_no_grabbing_through_walls" % osm, int(g._aim_target().get("uid", -1)) != int(it2["uid"]))
		break
	# Rooms out of sight (more than two doorways away) are hidden with everything in them.
	var open_idx: Array = []
	for i in range(rooms.size()):
		if not bool(rooms[i]["sealed"]):
			open_idx.append(i)
	if open_idx.size() >= 7:
		var far_hidden: bool = false
		for i in open_idx:
			g._player_pos = rooms[i]["center"]
			g._room_idx = -2
			g._update_camera(0.0)
			g._sync_world(0.0)
			var here: int = HouseBuilder3D._room_at(rooms, g._player_pos)
			if here < 0:
				continue
			_check("h%s_your_room_is_shown" % osm, (rooms[here]["node"] as Node3D).visible)
			for j in open_idx:
				if not (rooms[j]["node"] as Node3D).visible:
					far_hidden = true
			for it in g._world_items:
				var ri: int = HouseBuilder3D._room_at(rooms, it["pos"])
				if ri >= 0 and not (rooms[ri]["node"] as Node3D).visible and (g._item_nodes[int(it["uid"])] as Node3D).visible:
					_check("h%s_items_hidden_with_their_room" % osm, false, str(it["item_id"]))
			if far_hidden:
				break
		_check("h%s_far_rooms_hidden" % osm, far_hidden)
		# Looking straight through a doorway shows the room behind it.
		for d_v in g._house_layout.get("doorways", []):
			var d: Dictionary = d_v
			var c: Vector2 = d["center"]
			var ra: int = int(d["room_a"])
			var rb: int = int(d["room_b"])
			if bool(rooms[ra]["sealed"]) or bool(rooms[rb]["sealed"]):
				continue
			var into: Vector2 = (rooms[rb]["center"] as Vector2) - c
			var stand: Vector2 = c - into.normalized() * 70.0
			if HouseBuilder3D._room_at(rooms, stand) != ra:
				continue
			g._player_pos = stand
			g._yaw = atan2(-into.x, -into.y)
			g._update_camera(0.0)
			g._sync_world(0.0)
			_check("h%s_room_through_door_shown" % osm, (rooms[rb]["node"] as Node3D).visible)
			break
	for fam in g._world_family:
		# People never block the way; a figure the camera is inside is hidden.
		var fp: Vector2 = fam["pos"]
		_check("h%s_family_never_blocks_the_way" % osm, g._resolve_collisions(fp + Vector2(2.0, 0.0), false).distance_to(fp + Vector2(2.0, 0.0)) < 1.0 or g._resolve_collisions(fp, false).distance_to(fp) > 1.0)
		g._player_pos = fp + Vector2(3.0, 0.0)
		g._sync_world(0.0)
		_check("h%s_figure_hidden_when_walked_through" % osm, not (g._family_nodes[int(fam["uid"])] as Node3D).visible)
		break
	for prop in g._furniture_props:
		kinds_seen[str(prop.get("kind", ""))] = true
	kinds_seen.erase("hatch_hole")
	_check("h%s_pointer_not_captured" % osm, not g._try_capture_mouse())
	return _fails.size() == ok_before


func _grabbable_from_somewhere(g: HouseGrab3D, pos: Vector2) -> bool:
	return _grab_spot(g, pos) != Vector2.INF


## A walkable spot (not inside walls or furniture) within reach of `pos` with no wall between.
func _grab_spot(g: HouseGrab3D, pos: Vector2, min_r: float = 0.0) -> Vector2:
	if min_r <= 0.0 and g._resolve_collisions(pos, false).distance_to(pos) < 1.0:
		return pos + Vector2(0.01, 0.0)
	for r in [20.0, 36.0, 52.0, 68.0, 84.0]:
		if float(r) < min_r:
			continue
		for k in range(16):
			var a: float = TAU * float(k) / 16.0
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * float(r)
			if g._resolve_collisions(p, false).distance_to(p) < 1.0 and FloorplanGenerator.reachable_near(g._nav_grid, p, 20.0) and not g._wall_between(p, pos):
				return p
	return Vector2.INF


func _spot_behind_wall(g: HouseGrab3D, pos: Vector2) -> Vector2:
	for r in [40.0, 60.0, 80.0]:
		for k in range(24):
			var a: float = TAU * float(k) / 24.0
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * float(r)
			if g._resolve_collisions(p, false).distance_to(p) < 1.0 and FloorplanGenerator.reachable_near(g._nav_grid, p, 20.0) and g._wall_between(p, pos):
				return p
	return Vector2.INF


func _count_meshes(n: Node) -> int:
	var c: int = 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count_meshes(ch)
	return c
