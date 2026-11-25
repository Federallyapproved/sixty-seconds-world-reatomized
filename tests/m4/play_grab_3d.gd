extends Node

## Plays the first-person house grab with simulated keyboard and mouse input only: mouse motion
## to look, W to walk, E and left-click to grab, Q to cycle, right-click to drop, E at the hatch to
## drop everything down, TAB to end the look-around, F to climb down. Checks the settings (mouse
## sensitivity, invert-Y, field of view), that the pointer is never captured under test, the aim
## target, hands-full, family carried to the hatch, and (with a display) the draw-call budget.
##   godot [--headless] --fixed-fps 60 --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/run_node.gd -- \
##       --script=res://tests/m4/play_grab_3d.gd --out=<dir> [--hard] [--seed=11]
## Runs headless too (no screenshots or draw-call numbers then).

var _out: String = "user://play_grab_3d"
var _main: Control
var _gs: Node
var _sc: HouseGrab3D
var _report: Dictionary = {"checks": []}
var _held: Dictionary = {}
var _display: bool = false
var _draw_calls: Array = []
var _prims: Array = []
var _peak: Dictionary = {}


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=", true, 1)[1]
		if a == "--" + name:
			return "1"
	return fallback


func _check(name: String, ok: bool, detail: String = "") -> void:
	(_report["checks"] as Array).append({"name": name, "ok": ok, "detail": detail})
	print(("PASS " if ok else "FAIL ") + name + ("" if detail == "" else "  — " + detail))


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame
		_sample_perf()


func _sample_perf() -> void:
	if not _display or not is_instance_valid(_sc) or _sc._phase == ScavengeScene.Phase.OUTRO:
		return
	var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_draw_calls.append(dc)
	_prims.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if dc > int(_peak.get("dc", 0)):
		var here: int = HouseBuilder3D._room_at(_sc._house3d.get("rooms", []), _sc._player_pos)
		_peak = {"dc": dc, "frame": _draw_calls.size(), "room": here, "shown": _sc._shown_rooms.size(), "phase": _sc._phase,
			"popups": _sc._floating_popups.size(), "carried": _sc._carried_entries.size(), "aim": str(_sc._hovered_target.get("name", "-")),
			"hands_full": _sc._hands_full_timer > 0.0, "pending": str(_sc._pending_action.get("type", "-"))}


func _snap(name: String) -> void:
	if not _display:
		return
	await _frames(3)
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])


func run() -> int:
	_out = _arg("out", _out)
	DirAccess.make_dir_recursive_absolute(_out)
	_display = DisplayServer.get_name() != "headless"
	GameSettings.reset_for_tests()
	var hard: bool = _arg("hard", "0") == "1"
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	_gs = get_tree().root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = int(_arg("seed", "11"))
	await _frames(8)
	_gs.call("request_screen", "osm_house")
	await _frames(30)
	var hs: Node = _main.get("_active_node")
	for b in hs.get("_current_buildings"):
		if int(b.get("osm_id", 0)) == 206082403:
			hs.call("_select_house", b, false)
	_gs.set("difficulty", "hard" if hard else "normal")
	_gs.call("request_screen", "scavenge")
	await _frames(20)
	var node: Node = _main.get("_active_node")
	_check("grab_is_first_person", node is HouseGrab3D, node.get_class() if node != null else "none")
	if not (node is HouseGrab3D):
		return 1
	_sc = node
	await _snap("g00_recon")
	_check("timer_matches_difficulty", is_equal_approx(_sc._scavenge_total, 30.0 if hard else 60.0), "%.0f s" % _sc._scavenge_total)
	_check("pointer_not_captured_under_test", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	_check("house_has_walls_floors_lights", _count_lights() >= 3 and _house_meshes() >= 6, "%d lights, %d meshes" % [_count_lights(), _house_meshes()])
	_check("family_shown_in_3d", _sc._family_nodes.size() == _sc._world_family.size() and _sc._world_family.size() > 0, "%d figures" % _sc._family_nodes.size())
	_check("items_shown_in_3d", _sc._item_nodes.size() == _sc._world_items.size(), "%d items" % _sc._item_nodes.size())

	# Mouse look and its settings.
	var y0: float = _sc._yaw
	_mouse_move(Vector2(100.0, 0.0))
	await _frames(2)
	var turned: float = y0 - _sc._yaw
	_check("mouse_motion_turns_view", absf(turned - deg_to_rad(0.3 * 100.0)) < 0.01, "%.3f rad" % turned)
	GameSettings.set_value("mouse_sensitivity", 0.6)
	y0 = _sc._yaw
	_mouse_move(Vector2(100.0, 0.0))
	await _frames(2)
	_check("sensitivity_scales_turn", absf((y0 - _sc._yaw) - deg_to_rad(60.0)) < 0.01, "%.3f rad" % (y0 - _sc._yaw))
	GameSettings.set_value("mouse_sensitivity", 0.3)
	var p0: float = _sc._pitch
	_mouse_move(Vector2(0.0, 20.0))
	await _frames(2)
	var d_normal: float = _sc._pitch - p0
	GameSettings.set_value("invert_y", true)
	p0 = _sc._pitch
	_mouse_move(Vector2(0.0, 20.0))
	await _frames(2)
	var d_inverted: float = _sc._pitch - p0
	GameSettings.set_value("invert_y", false)
	_check("invert_y_flips_vertical_look", d_normal < 0.0 and d_inverted > 0.0, "%.3f / %.3f" % [d_normal, d_inverted])
	GameSettings.set_value("fov", 90.0)
	await _frames(2)
	_check("fov_setting_applies", is_equal_approx(_sc.camera_3d().fov, 90.0), "%.0f" % _sc.camera_3d().fov)
	GameSettings.set_value("fov", 75.0)

	# The look-around keeps you near the start.
	var start: Vector2 = _sc._player_pos
	_hold(KEY_W, true)
	await _frames(70)
	_hold(KEY_W, false)
	_check("recon_walk_is_leashed", _sc._player_pos.distance_to(_sc._leader_start_pos) <= 117.0 and _sc._player_pos.distance_to(start) > 5.0, "%.0f px from start" % _sc._player_pos.distance_to(_sc._leader_start_pos))
	_tap(KEY_TAB)
	await _frames(3)
	_check("tab_starts_grab", _sc._phase == ScavengeScene.Phase.SCAVENGE)

	var grabs: int = 0
	var clicks: int = 0
	var deposits: int = 0
	var aim_ok: int = 0
	var aim_tries: int = 0
	var family_down: int = 0
	var drop_tested: bool = false
	var cycle_tested: bool = false
	var hands_full_seen: bool = false
	var use_click: bool = false
	while _sc._phase == ScavengeScene.Phase.SCAVENGE:
		var left: float = _sc._scavenge_time_left
		var used: int = _sc._get_used_slots()
		var cap: int = _sc._max_slots
		var tgt: Dictionary = _nearest_target_fit(cap - used)
		if left < 9.0 or (tgt.is_empty() and not _sc._carried_entries.is_empty()) or _sc._carried_entries.size() >= 3:
			await _walk_to(_sc._hatch_pos, 45.0, 10.0)
			if not _sc._carried_entries.is_empty():
				if not cycle_tested and _sc._carried_entries.size() >= 2:
					var s0: int = _sc._selected_slot
					_tap(KEY_Q)
					await _frames(2)
					_check("q_cycles_selected_slot", _sc._selected_slot != s0)
					cycle_tested = true
				var fam_before: int = _sc._family_deposited_count
				var before: int = _sc._items_deposited_count + fam_before
				_look_down()
				await _frames(2)
				_tap(KEY_E)
				await _frames(2)
				await _snap("g03_deposit")
				await _wait_pending()
				if _sc._items_deposited_count + _sc._family_deposited_count > before:
					deposits += 1
				family_down += _sc._family_deposited_count - fam_before
			if _sc._scavenge_time_left < 9.0:
				break
			continue
		if tgt.is_empty():
			break
		var ref: Dictionary = tgt["ref"]
		await _walk_to(tgt["pos"], 52.0, 9.0)
		if _sc._phase != ScavengeScene.Phase.SCAVENGE:
			break
		await _look_at(tgt["pos"], 0.9 if str(tgt["kind"]) == "family" else 0.14)
		await _frames(2)
		aim_tries += 1
		if int(_sc._hovered_target.get("uid", -1)) == int(ref["uid"]):
			aim_ok += 1
		elif OS.get_cmdline_user_args().has("--verbose-aim"):
			print("AIM MISS want %s at %.0f px, got %s, phase %d, t %.1f, wall %s" % [str(ref.get("name", "")), _sc._player_pos.distance_to(tgt["pos"]), str(_sc._hovered_target.get("name", "-")), _sc._phase, _sc._scavenge_time_left, str(_sc._wall_between(_sc._player_pos, tgt["pos"]))])
		var n0: int = _sc._carried_entries.size()
		if use_click:
			_click(MOUSE_BUTTON_LEFT)
		else:
			_tap(KEY_E)
		await _frames(2)
		await _wait_pending()
		if _sc._carried_entries.size() > n0:
			grabs += 1
			if use_click:
				clicks += 1
			use_click = not use_click
			if grabs == 2:
				await _snap("g01_carrying")
		else:
			ref["_skip"] = true
		# Hands full: aim at something that won't fit and press E.
		if not hands_full_seen and _sc._get_used_slots() >= 2:
			var big: Dictionary = _nearest_target_fit(99, _sc._max_slots - _sc._get_used_slots() + 1)
			if not big.is_empty() and (_sc._player_pos.distance_to(big["pos"]) < 400.0):
				await _walk_to(big["pos"], 52.0, 6.0)
				await _look_at(big["pos"], 0.9 if str(big["kind"]) == "family" else 0.14)
				await _frames(2)
				# Only when the crosshair is on the big one (something smaller can be in the way).
				if int(_sc._hovered_target.get("uid", -1)) == int(big["ref"]["uid"]):
					var c0: int = _sc._carried_entries.size()
					_tap(KEY_E)
					await _frames(3)
					hands_full_seen = _sc._hands_full_timer > 0.0 and _sc._carried_entries.size() == c0 and _sc._pending_action.is_empty()
					_check("hands_full_blocks_grab", hands_full_seen, "timer %.2f" % _sc._hands_full_timer)
					await _snap("g02_hands_full")
				await _wait_pending()
		# Drop test once, away from the hatch: right-click puts the selected thing back in the house.
		if not drop_tested and grabs >= 1 and not _sc._carried_entries.is_empty() and _sc._player_pos.distance_to(_sc._hatch_pos) > 150.0:
			await _wait_pending()
			var entry: Dictionary = _sc._carried_entries[_sc._selected_slot]
			var c1: int = _sc._carried_entries.size()
			var why: String = "kind %s, pending %s, used %d" % [str(entry.get("kind", "")), str(_sc._pending_action.get("type", "-")), _sc._get_used_slots()]
			_click(MOUSE_BUTTON_RIGHT)
			await _frames(3)
			var shown: bool = false
			if str(entry.get("kind", "")) == "item":
				var n3: Node3D = _sc._item_nodes.get(int(entry["ref"]["uid"]))
				shown = n3 != null and n3.visible
			else:
				var fig: Node3D = _sc._family_nodes.get(int(entry["ref"]["uid"]))
				shown = fig != null and fig.visible
			_check("right_click_drops_selected_back_into_house", _sc._carried_entries.size() == c1 - 1 and shown, "%d -> %d, visible %s (%s)" % [c1, _sc._carried_entries.size(), str(shown), why])
			drop_tested = true
			await _snap("g04_dropped")
			await _look_at(entry["ref"]["pos"], 0.14)
			_tap(KEY_E)
			await _wait_pending()
	_release_all()
	await _snap("g05_end")
	if _sc._phase == ScavengeScene.Phase.SCAVENGE:
		await _walk_to(_sc._hatch_pos, 40.0, 8.0)
		_tap(KEY_F)
		await _frames(6)
	_check("keyboard_and_mouse_grabs_work", grabs >= 3 and clicks >= 1, "%d grabs, %d by click" % [grabs, clicks])
	_check("drop_was_tested", drop_tested)
	_check("crosshair_aims_at_target", aim_tries > 0 and float(aim_ok) / float(aim_tries) >= 0.8, "%d of %d" % [aim_ok, aim_tries])
	_check("e_deposits_at_hatch", deposits >= 1, "%d trips" % deposits)
	_check("family_carried_down", family_down >= 1, "%d" % family_down)
	_check("leader_made_it_down", bool(_sc._leader_member.get("in_bunker", false)) or _sc._phase == ScavengeScene.Phase.OUTRO)
	_check("pointer_never_captured", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	if _display and not _draw_calls.is_empty():
		var mx: int = 0
		var sum: int = 0
		for d in _draw_calls:
			mx = maxi(mx, int(d))
			sum += int(d)
		var pmx: int = 0
		for p in _prims:
			pmx = maxi(pmx, int(p))
		_report["draw_calls_max"] = mx
		_report["draw_calls_avg"] = float(sum) / float(_draw_calls.size())
		_report["primitives_max"] = pmx
		_report["draw_calls_peak_frame"] = _peak
		print("PEAK ", JSON.stringify(_peak))
		var over: int = 0
		for d in _draw_calls:
			if int(d) > 300:
				over += 1
		_report["frames_over_300"] = over
		print("FRAMES over 300: %d of %d" % [over, _draw_calls.size()])
		_check("draw_calls_within_web_budget", mx < 300, "max %d, avg %.0f, triangles max %d" % [mx, float(sum) / float(_draw_calls.size()), pmx])
	# On to the shelter (the outro runs on real time).
	await get_tree().create_timer(2.6).timeout
	await _frames(10)
	var after: Node = _main.get("_active_node")
	_check("grab_hands_over_to_shelter", after != null and not (after is ScavengeScene), after.get_class() if after != null else "none")
	_report["grabs"] = grabs
	_report["clicks"] = clicks
	_report["deposit_trips"] = deposits
	_report["items_deposited"] = _sc._items_deposited_count if is_instance_valid(_sc) else -1
	var f := FileAccess.open(_out + "/grab3d_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	var fails: int = 0
	for c in _report["checks"]:
		if not bool(c["ok"]):
			fails += 1
	print("GRAB3D_DONE fails=%d grabs=%d clicks=%d deposits=%d family=%d" % [fails, grabs, clicks, deposits, family_down])
	return 0 if fails == 0 else 1


# ------------------------------------------------------------------------------

func _count_lights() -> int:
	var n: int = 0
	for rm in _sc._house3d.get("rooms", []):
		if rm.get("light") != null:
			n += 1
	return n


func _house_meshes() -> int:
	var n: int = 0
	for rm in _sc._house3d.get("rooms", []):
		for c in (rm["node"] as Node).get_children():
			if c is MeshInstance3D:
				n += 1
	return n


## Nearest family member or item (by walking distance) that fits `free_slots`; with `min_slots`,
## only ones at least that big (to test hands-full).
func _nearest_target_fit(free_slots: int, min_slots: int = 0) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = 1e20
	for kind in ["family", "item"]:
		var arr: Array = _sc._world_family if kind == "family" else _sc._world_items
		for e in arr:
			if bool(e.get("collected", false)) or bool(e.get("_skip", false)):
				continue
			var slots: int = int(e.get("slots", 1))
			if slots > free_slots or slots < min_slots:
				continue
			var path: PackedVector2Array = FloorplanGenerator.find_path(_sc._nav_grid, _sc._player_pos, e["pos"])
			var L: float = 0.0
			for i in range(1, path.size()):
				L += path[i - 1].distance_to(path[i])
			if kind == "family":
				L *= 0.5
			if L < bd:
				bd = L
				best = {"pos": e["pos"], "ref": e, "kind": kind}
	return best


## Walks the nav path holding W and turning with mouse motion, like a player would.
func _walk_to(goal: Vector2, arrive: float, timeout_s: float) -> void:
	var path: PackedVector2Array = FloorplanGenerator.find_path(_sc._nav_grid, _sc._player_pos, goal)
	var wp: int = 1 if path.size() > 1 else 0
	var t: float = 0.0
	var last_p: Vector2 = _sc._player_pos
	var stuck: float = 0.0
	while t < timeout_s and _sc._phase == ScavengeScene.Phase.SCAVENGE:
		var p: Vector2 = _sc._player_pos
		stuck = 0.0 if p.distance_to(last_p) > 0.5 else stuck + 1.0 / 60.0
		last_p = p
		if p.distance_to(goal) <= arrive:
			break
		var target: Vector2 = path[wp] if wp < path.size() else goal
		if p.distance_to(target) < 14.0 and wp < path.size() - 1:
			wp += 1
			target = path[wp]
		if stuck > 0.5:
			path = FloorplanGenerator.find_path(_sc._nav_grid, p, goal)
			wp = 1 if path.size() > 1 else 0
			stuck = 0.0
		var d: Vector2 = target - p
		var want: float = atan2(-d.x, -d.y)
		var delta: float = wrapf(want - _sc._yaw, -PI, PI)
		var sens: float = deg_to_rad(GameSettings.mouse_sensitivity())
		_mouse_move(Vector2(clampf(-delta / sens, -60.0, 60.0), 0.0))
		_hold(KEY_W, absf(delta) < 0.7)
		await _frames(1)
		t += 1.0 / 60.0
	_release_all()
	await _frames(2)


## Turns (and tilts) to look at a point on the floor plan at height h with mouse motion.
func _look_at(pos: Vector2, h: float) -> void:
	for _i in range(12):
		var d: Vector2 = pos - _sc._player_pos
		var want_yaw: float = atan2(-d.x, -d.y)
		var dist_m: float = maxf(0.2, d.length() / 46.0)
		var want_pitch: float = atan2(h - _sc._eye_h, dist_m)
		var sens: float = deg_to_rad(GameSettings.mouse_sensitivity())
		var dy: float = wrapf(want_yaw - _sc._yaw, -PI, PI)
		var dp: float = want_pitch - _sc._pitch
		if absf(dy) < 0.01 and absf(dp) < 0.01:
			break
		_mouse_move(Vector2(clampf(-dy / sens, -80.0, 80.0), clampf(-dp / sens, -80.0, 80.0)))
		await _frames(1)


func _look_down() -> void:
	var sens: float = deg_to_rad(GameSettings.mouse_sensitivity())
	_mouse_move(Vector2(0.0, clampf((_sc._pitch + 0.9) / sens, 0.0, 200.0)))


func _wait_pending() -> void:
	for _i in range(120):
		if _sc._pending_action.is_empty():
			break
		await _frames(1)
	await _frames(2)


func _mouse_move(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.screen_relative = rel
	ev.position = Vector2(640.0, 360.0)
	ev.global_position = Vector2(640.0, 360.0)
	Input.parse_input_event(ev)


func _click(button: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.position = Vector2(640.0, 360.0)
		ev.global_position = Vector2(640.0, 360.0)
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _hold(kc: int, down: bool) -> void:
	if bool(_held.get(kc, false)) == down:
		return
	_held[kc] = down
	var ev := InputEventKey.new()
	ev.keycode = kc
	ev.physical_keycode = kc
	ev.pressed = down
	Input.parse_input_event(ev)


func _release_all() -> void:
	for kc in _held.keys():
		_hold(int(kc), false)


func _tap(kc: int) -> void:
	_hold(kc, true)
	_hold(kc, false)
