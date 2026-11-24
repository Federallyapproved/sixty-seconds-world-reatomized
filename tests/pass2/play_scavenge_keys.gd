extends SceneTree

## Plays the 60-second scavenge with the KEYBOARD only (arrow keys to walk, SPACE to grab /
## deposit / drop, Q to cycle the selected slot, TAB to skip recon, F to dive), on a real OSM
## house, and verifies the rules the player relies on. Screenshots each beat when a display exists.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --audio-driver Dummy -s res://tests/pass2/play_scavenge_keys.gd -- --out=/tmp/keys [--hard]

var _out: String = "/tmp/keys"
var _main: Control
var _gs: Node
var _sc: Node
var _report: Dictionary = {"checks": []}
var _held: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
		if a == "--" + name:
			return "1"
	return fallback


func _check(name: String, ok: bool, detail: String = "") -> void:
	(_report["checks"] as Array).append({"name": name, "ok": ok, "detail": detail})
	print(("PASS " if ok else "FAIL ") + name + ("" if detail == "" else "  — " + detail))


func _run() -> void:
	_out = _arg("out", "/tmp/keys")
	var hard: bool = _arg("hard", "0") == "1"
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_gs = root.get_node("GameState")
	_gs.get("rng").seed = int(_arg("seed", "11"))
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
	_sc = _main.get("_active_node")
	await _snap("k00_recon")
	var expect_total: float = 30.0 if hard else 60.0
	_check("timer_matches_difficulty", is_equal_approx(float(_sc.get("_scavenge_total")), expect_total), "%s: %.0f s" % ["hard" if hard else "normal", float(_sc.get("_scavenge_total"))])

	# TAB skips recon
	_tap(KEY_TAB)
	await _frames(4)
	_check("tab_skips_recon", int(_sc.get("_phase")) == 1)

	# Standing on an item does not pick it up (no auto pickup)
	var items: Array = _sc.get("_world_items")
	var first: Dictionary = _nearest_uncollected(items)
	_sc.set("_player_pos", first["pos"])
	await _frames(20)
	_check("no_auto_pickup", not bool(first["collected"]) and (_sc.get("_carried_entries") as Array).is_empty())
	_sc.set("_player_pos", _sc.get("_hatch_pos"))
	await _frames(2)

	var grabs: int = 0
	var deposits: int = 0
	var drop_tested: bool = false
	var cycle_tested: bool = false
	var walked_px: float = 0.0
	while int(_sc.get("_phase")) == 1:
		var left: float = float(_sc.get("_scavenge_time_left"))
		var carried: Array = _sc.get("_carried_entries")
		var used: int = int(_sc.call("_get_used_slots"))
		var cap: int = int(_sc.get("_max_slots"))
		var hatch: Vector2 = _sc.get("_hatch_pos")
		if left < 7.0 or (used >= cap - 0 and not carried.is_empty()) or (carried.size() >= 3) or (_nearest_target_fit(cap - used).is_empty() and not carried.is_empty()):
			walked_px += await _walk_to(hatch, float(_sc.get("_hatch_radius")) * 0.6, 9.0)
			if not carried.is_empty():
				var before: int = int(_sc.get("_items_deposited_count")) + int(_sc.get("_family_deposited_count"))
				if not cycle_tested and carried.size() >= 2:
					var sel0: int = int(_sc.get("_selected_slot"))
					_tap(KEY_Q)
					await _frames(2)
					_check("q_cycles_selected_slot", int(_sc.get("_selected_slot")) != sel0)
					cycle_tested = true
					await _snap("k02_selected_slot")
				_tap(KEY_SPACE)
				await _frames(3)
				await _snap("k03_deposit_at_hatch")
				await _wait_pending()
				var after: int = int(_sc.get("_items_deposited_count")) + int(_sc.get("_family_deposited_count"))
				if after > before:
					deposits += 1
			if float(_sc.get("_scavenge_time_left")) < 7.0:
				break
			continue
		var tgt: Dictionary = _nearest_target_fit(cap - used)
		if tgt.is_empty():
			break
		walked_px += await _walk_to(tgt["pos"], 30.0, 9.0)
		if int(_sc.get("_phase")) != 1:
			break
		var n0: int = (_sc.get("_carried_entries") as Array).size()
		_tap(KEY_SPACE)
		await _wait_pending()
		if (_sc.get("_carried_entries") as Array).size() > n0:
			grabs += 1
			if grabs == 2:
				await _snap("k01_carrying")
		else:
			# could not grab (e.g. bumped away): mark tried so we do not loop forever
			tgt["ref"]["_skip"] = true
		# drop test once: SPACE away from the hatch with nothing grabbable in reach drops the selected item
		if not drop_tested and grabs >= 1 and (_sc.get("_carried_entries") as Array).size() >= 1:
			var spot: Vector2 = _sc.get("_player_pos")
			var near: Dictionary = _sc.call("_find_target_near_point", spot, float(_sc.get("INTERACT_RADIUS")))
			if near.is_empty() and spot.distance_to(hatch) > 200.0:
				var c0: int = (_sc.get("_carried_entries") as Array).size()
				_tap(KEY_SPACE)
				await _wait_pending()
				await _frames(3)
				var c1: int = (_sc.get("_carried_entries") as Array).size()
				_check("space_drops_selected_item_away_from_hatch", c1 == c0 - 1, "%d -> %d" % [c0, c1])
				await _snap("k04_dropped_item")
				drop_tested = true
				# pick it straight back up
				_tap(KEY_SPACE)
				await _wait_pending()
	_release_all()
	await _snap("k05_end_of_run")
	# F dives when allowed
	if int(_sc.get("_phase")) == 1:
		await _walk_to(_sc.get("_hatch_pos"), 20.0, 6.0)
		_tap(KEY_F)
		await _frames(6)
	_check("keyboard_grabs_work", grabs >= 3, "%d grabs" % grabs)
	_check("space_deposits_at_hatch", deposits >= 1, "%d deposit trips" % deposits)
	_check("leader_made_it_down", bool((_sc.get("_leader_member") as Dictionary).get("in_bunker", false)) or int(_sc.get("_phase")) == 2)
	_report["grabs"] = grabs
	_report["deposit_trips"] = deposits
	_report["items_deposited"] = int(_sc.get("_items_deposited_count"))
	_report["family_deposited"] = int(_sc.get("_family_deposited_count"))
	_report["walked_px"] = walked_px
	var f := FileAccess.open(_out + "/keys_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	var fails: int = 0
	for c in _report["checks"]:
		if not bool(c["ok"]):
			fails += 1
	print("KEYS_DONE fails=%d grabs=%d deposits=%d items=%d family=%d" % [fails, grabs, deposits, int(_report["items_deposited"]), int(_report["family_deposited"])])
	quit(0 if fails == 0 else 1)


func _nearest_uncollected(items: Array) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = 1e20
	var p: Vector2 = _sc.get("_player_pos")
	for it in items:
		if bool(it.get("collected", false)):
			continue
		var d: float = p.distance_to(it["pos"])
		if d < bd:
			bd = d
			best = it
	return best


## Nearest family member or item (by walking path length) that fits the free slots.
func _nearest_target_fit(free_slots: int) -> Dictionary:
	var nav: Dictionary = _sc.get("_nav_grid")
	var p: Vector2 = _sc.get("_player_pos")
	var best: Dictionary = {}
	var bd: float = 1e20
	for kind in ["family", "item"]:
		var arr: Array = _sc.get("_world_family") if kind == "family" else _sc.get("_world_items")
		for e in arr:
			if bool(e.get("collected", false)) or bool(e.get("_skip", false)):
				continue
			var t: Dictionary = _sc.call("_get_target_by_uid", kind, int(e["uid"]))
			if t.is_empty() or int(t.get("slots", 1)) > free_slots:
				continue
			var path: PackedVector2Array = HouseGenerator.find_path(nav, p, e["pos"])
			var L: float = 0.0
			for i in range(1, path.size()):
				L += path[i - 1].distance_to(path[i])
			if kind == "family":
				L *= 0.5
			if L < bd:
				bd = L
				best = {"pos": e["pos"], "ref": e}
	return best


## Walks along the nav path by holding arrow keys. Returns distance travelled.
func _walk_to(goal: Vector2, arrive: float, timeout_s: float) -> float:
	var nav: Dictionary = _sc.get("_nav_grid")
	var start: Vector2 = _sc.get("_player_pos")
	var path: PackedVector2Array = HouseGenerator.find_path(nav, start, goal)
	var wp: int = 1 if path.size() > 1 else 0
	var t: float = 0.0
	var last_p: Vector2 = start
	var stuck: float = 0.0
	var travelled: float = 0.0
	while t < timeout_s and int(_sc.get("_phase")) == 1:
		var p: Vector2 = _sc.get("_player_pos")
		travelled += p.distance_to(last_p)
		stuck = 0.0 if p.distance_to(last_p) > 0.6 else stuck + 1.0 / 60.0
		last_p = p
		if p.distance_to(goal) <= arrive:
			break
		var target: Vector2 = path[wp] if wp < path.size() else goal
		if p.distance_to(target) < 12.0 and wp < path.size() - 1:
			wp += 1
			target = path[wp]
		if stuck > 0.6:
			path = HouseGenerator.find_path(nav, p, goal)
			wp = 1 if path.size() > 1 else 0
			stuck = 0.0
		_steer(target - p)
		await process_frame
		t += 1.0 / 60.0
	_release_all()
	await _frames(2)
	return travelled


func _steer(d: Vector2) -> void:
	var n: Vector2 = d.normalized() if d.length() > 0.5 else Vector2.ZERO
	_hold(KEY_RIGHT, n.x > 0.3)
	_hold(KEY_LEFT, n.x < -0.3)
	_hold(KEY_DOWN, n.y > 0.3)
	_hold(KEY_UP, n.y < -0.3)


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
	for kc in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		_hold(kc, false)


func _tap(kc: int) -> void:
	_hold(kc, true)
	_hold(kc, false)


func _wait_pending() -> void:
	await _frames(2)
	var g: int = 0
	while not (_sc.get("_pending_action") as Dictionary).is_empty() and g < 240:
		g += 1
		await process_frame
	await _frames(2)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _snap(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(_out + "/" + name + ".png")
