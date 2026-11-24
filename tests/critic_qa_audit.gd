extends SceneTree

## Ruthless End-to-End QA, Stress Fuzzer, Memory Leak & Demo Showcase Audit Runner.
## Usage:
##   1) Full audit (fuzzer + audio + edge cases + demo showcase at 30 FPS):
##      /home/antigravity/.local/bin/godot --headless --fixed-fps 30 --verbose --path /home/antigravity/sixty_seconds_world -s res://tests/critic_qa_audit.gd
##   2) Pure demo showcase timing run (with optional --clean-audio-exit to verify leak fix):
##      /home/antigravity/.local/bin/godot --headless --fixed-fps 30 --verbose --path /home/antigravity/sixty_seconds_world -s res://tests/critic_qa_audit.gd -- --only-demo --clean-audio-exit

var FamilyScreenScript: GDScript
var ScavengeSceneScript: GDScript
var EventDeckScript: GDScript
var BunkerSimScript: GDScript
var ExpeditionEngineScript: GDScript
var BunkerSceneScript: GDScript
var HouseSelectScreenScript: GDScript
var NukeScreenScript: GDScript
var SummaryScreenScript: GDScript

var _failures: Array[String] = []
var _warnings: Array[String] = []
var _passes: int = 0

func _init() -> void:
	call_deferred("_run_all_audits")

func _record_pass(msg: String) -> void:
	_passes += 1
	print("[PASS] " + msg)

func _record_fail(msg: String) -> void:
	_failures.append(msg)
	print("[FAIL] " + msg)

func _record_warn(msg: String) -> void:
	_warnings.append(msg)
	print("[WARN] " + msg)

func _run_all_audits() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var only_demo: bool = user_args.has("--only-demo")
	var clean_audio_exit: bool = user_args.has("--clean-audio-exit")

	print("==================================================================")
	print("RUTHLESS QA & RELIABILITY GAUNTLET AUDIT STARTING")
	print("User args: ", user_args)
	print("==================================================================")

	await process_frame

	FamilyScreenScript = load("res://scripts/ui/family_screen.gd")
	ScavengeSceneScript = load("res://scripts/scavenge/scavenge_scene.gd")
	EventDeckScript = load("res://scripts/events/event_deck.gd")
	BunkerSimScript = load("res://scripts/bunker/bunker_sim.gd")
	ExpeditionEngineScript = load("res://scripts/expedition/expedition_engine.gd")
	BunkerSceneScript = load("res://scripts/bunker/bunker_scene.gd")
	HouseSelectScreenScript = load("res://scripts/ui/house_select_screen.gd")
	NukeScreenScript = load("res://scripts/ui/nuke_screen.gd")
	SummaryScreenScript = load("res://scripts/ui/summary_screen.gd")

	if not only_demo:
		_audit_procedural_audio()
		_audit_nuke_physics_edge_cases()
		_audit_osm_and_house_generator()
		await _audit_ui_screens_and_scavenge_edge_cases()
		_audit_all_60_events_exhaustively()
		_audit_10_seed_35_day_bunker_fuzz()
		await _audit_targeted_bug_repros()

	await _audit_full_demo_showcase()

	print("==================================================================")
	print("QA SUMMARY: passes=%d warnings=%d failures=%d" % [_passes, _warnings.size(), _failures.size()])
	for w in _warnings:
		print("  WARNING: " + w)
	for f in _failures:
		print("  FAILURE: " + f)
	print("==================================================================")

	var all_cli: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if clean_audio_exit or all_cli.has("--write-movie"):
		var sm_exit: Node = root.get_node_or_null("SoundManager")
		if sm_exit != null and sm_exit.has_method("shutdown_audio"):
			sm_exit.call("shutdown_audio")
		OS.delay_msec(60)
		await process_frame
		await process_frame

	quit(0 if _failures.is_empty() else 1)

func _stop_all_sound_manager_players() -> void:
	var sm: Node = root.get_node_or_null("SoundManager")
	if sm == null:
		return
	var amb: AudioStreamPlayer = sm.get("_ambient_player")
	if amb != null:
		amb.stop()
		amb.stream = null
	var pool: Array = sm.get("_sfx_pool")
	for p in pool:
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stop()
			(p as AudioStreamPlayer).stream = null
	var sfx_dict: Dictionary = sm.get("_sfx_streams")
	sfx_dict.clear()
	var amb_dict: Dictionary = sm.get("_ambient_streams")
	amb_dict.clear()

# ==============================================================================
# 1. PROCEDURAL AUDIO WAVEFORM & STREAM AUDIT
# ==============================================================================
func _audit_procedural_audio() -> void:
	print("\n--- [SUITE 1] Procedural Audio Waveform Verification ---")
	var sm: Node = root.get_node_or_null("SoundManager")
	if sm == null:
		_record_fail("SoundManager autoload missing from root!")
		return

	var expected_sfx: Array[String] = [
		"siren", "tick", "urgent_tick", "pickup", "hatch_drop",
		"hatch_slam", "nuke_boom", "page_turn", "button_click",
		"geiger", "knock", "victory", "gameover"
	]
	var expected_amb: Array[String] = ["menu", "scavenge", "bunker"]

	var sfx_streams: Dictionary = sm.get("_sfx_streams")
	var amb_streams: Dictionary = sm.get("_ambient_streams")

	for s_name in expected_sfx:
		if not sfx_streams.has(s_name):
			_record_fail("Missing SFX stream: " + s_name)
			continue
		var wav: AudioStreamWAV = sfx_streams[s_name]
		_verify_wav_stream("sfx:" + s_name, wav, false)

	for a_name in expected_amb:
		if not amb_streams.has(a_name):
			_record_fail("Missing Ambience stream: " + a_name)
			continue
		var wav_a: AudioStreamWAV = amb_streams[a_name]
		_verify_wav_stream("ambience:" + a_name, wav_a, true)

	# Stress pool wrap-around (> 6 simultaneous SFX) and invalid inputs
	for i in range(10):
		sm.call("play_sfx", expected_sfx[i % expected_sfx.size()], -3.0, 0.5 + float(i) * 0.1)
	sm.call("play_sfx", "non_existent_sfx_id", 0.0, -5.0)
	sm.call("set_ambience", "menu")
	sm.call("set_ambience", "scavenge")
	sm.call("set_ambience", "bunker")
	sm.call("set_ambience", "none")
	_record_pass("SoundManager pool wrap-around & ambience switching survived cleanly")

func _verify_wav_stream(label: String, wav: AudioStreamWAV, expect_loop: bool) -> void:
	if wav == null:
		_record_fail(label + " is null")
		return
	if wav.format != AudioStreamWAV.FORMAT_16_BITS or wav.mix_rate != 22050 or wav.stereo:
		_record_fail("%s invalid format/rate/stereo: fmt=%d rate=%d stereo=%s" % [label, wav.format, wav.mix_rate, str(wav.stereo)])
		return
	var pcm: PackedByteArray = wav.data
	if pcm.is_empty() or (pcm.size() % 2) != 0:
		_record_fail("%s empty or odd PCM byte size (%d)" % [label, pcm.size()])
		return

	var count: int = pcm.size() / 2
	var peak: float = 0.0
	var sum_sq: float = 0.0
	var clipped_samples: int = 0
	var max_step: float = 0.0
	var prev_s: float = 0.0

	for i in range(count):
		var iv: int = pcm.decode_s16(i * 2)
		if abs(iv) >= 32767:
			clipped_samples += 1
		var s: float = float(iv) / 32767.0
		if is_nan(s) or is_inf(s):
			_record_fail("%s contains NaN/Inf at sample %d" % [label, i])
			return
		peak = maxf(peak, absf(s))
		sum_sq += s * s
		if i > 0:
			max_step = maxf(max_step, absf(s - prev_s))
		prev_s = s

	var rms: float = sqrt(sum_sq / float(count))
	var wrap_begin_idx: int = clampi(wav.loop_begin, 0, count - 1) if expect_loop else 0
	var wrap_end_idx: int = clampi(wav.loop_end - 1, 0, count - 1) if expect_loop else (count - 1)
	var first_s: float = float(pcm.decode_s16(wrap_begin_idx * 2)) / 32767.0
	var last_s: float = float(pcm.decode_s16(wrap_end_idx * 2)) / 32767.0
	var seam_jump: float = absf(first_s - last_s)

	print("  AUDIO %-18s samples=%5d (%.2fs) peak=%.3f rms=%.3f clipped=%d loop_begin=%4d seam_jump=%.4f" % [
		label, count, float(count) / 22050.0, peak, rms, clipped_samples, wav.loop_begin, seam_jump
	])

	if peak < 0.10 or rms < 0.01:
		_record_fail("%s too quiet/silent! peak=%.4f rms=%.4f" % [label, peak, rms])
		return
	if expect_loop:
		if wav.loop_mode != AudioStreamWAV.LOOP_FORWARD or wav.loop_end != count or wav.loop_begin < 0 or wav.loop_begin >= wav.loop_end:
			_record_fail("%s loop metadata mismatch: mode=%d begin=%d end=%d count=%d" % [label, wav.loop_mode, wav.loop_begin, wav.loop_end, count])
			return
		if seam_jump > 0.08:
			_record_fail("%s loop seam jump %.4f at loop_begin=%d exceeds 0.08 click threshold!" % [label, seam_jump, wav.loop_begin])
			return
	_record_pass("Audio stream verified: " + label)

# ==============================================================================
# 2. NUKE PHYSICS EDGE CASES
# ==============================================================================
func _audit_nuke_physics_edge_cases() -> void:
	print("\n--- [SUITE 2] NukePhysics Mathematical & Geodesic Edge Cases ---")
	var cases: Array[Dictionary] = [
		{"name": "Zero-distance direct hit", "hlat": 47.6242, "hlon": -122.3195, "nlat": 47.6242, "nlon": -122.3195, "kt": 800, "wind": 0.0},
		{"name": "Close 2km Ground Zero Edge", "hlat": 47.6242, "hlon": -122.3195, "nlat": 47.6100, "nlon": -122.3350, "kt": 800, "wind": 45.0},
		{"name": "5000km Nuclear Winter", "hlat": 47.6242, "hlon": -122.3195, "nlat": 35.6762, "nlon": 139.6503, "kt": 50000, "wind": 270.0},
		{"name": "Exact Antipode", "hlat": 47.6242, "hlon": -122.3195, "nlat": -47.6242, "nlon": 57.6805, "kt": 15, "wind": -725.0},
		{"name": "North Pole vs Zero Yield", "hlat": 89.9, "hlon": 180.0, "nlat": -89.9, "nlon": -180.0, "kt": 0, "wind": 9999.0}
	]
	for c in cases:
		var imp: Dictionary = NukePhysics.compute_impact(
			float(c["hlat"]), float(c["hlon"]),
			float(c["nlat"]), float(c["nlon"]),
			int(c["kt"]), float(c["wind"]), str(c["name"])
		)
		var dist: float = float(imp.get("distance_km", NAN))
		var sv: float = float(imp.get("initial_sv_hr", NAN))
		var tc: float = float(imp.get("bunker_temp_c", NAN))
		if is_nan(dist) or is_inf(dist) or is_nan(sv) or is_nan(tc):
			_record_fail("NukePhysics NaN/Inf on case " + str(c["name"]))
			return
		var arc: Array[Vector2] = NukePhysics.sample_geodesic_points(
			float(c["hlat"]), float(c["hlon"]), float(c["nlat"]), float(c["nlon"]), 32
		)
		for pt in arc:
			if is_nan(pt.x) or is_nan(pt.y) or is_inf(pt.x) or is_inf(pt.y):
				_record_fail("NukePhysics geodesic NaN/Inf on case " + str(c["name"]))
				return
	_record_pass("All NukePhysics edge cases (0km, 2km, 5000km, antipode, poles, 0kt) finite & valid")

# ==============================================================================
# 3. OSM PRESETS & HOUSE GENERATOR STRESS AUDIT
# ==============================================================================
func _audit_osm_and_house_generator() -> void:
	print("\n--- [SUITE 3] OSM Presets & HouseGenerator Walkability Audit ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	var gs: Node = root.get_node("GameState")
	gs.call("init_default_family")
	var fam: Array = gs.get("family_members")

	var total_houses_tested: int = 0
	for preset_id in ["seattle", "concord", "brooklyn"]:
		var parsed: Dictionary = OsmService.load_preset(preset_id)
		var bldgs: Array = parsed.get("buildings", [])
		var pois: Array = parsed.get("pois", [])
		if bldgs.is_empty() or pois.is_empty():
			_record_fail("OSM preset %s empty buildings (%d) or pois (%d)" % [preset_id, bldgs.size(), pois.size()])
			continue
		var best_h: Dictionary = OsmService.pick_best_house(bldgs, float(parsed.get("center_lat", 0.0)), float(parsed.get("center_lon", 0.0)), int(parsed.get("preferred_osm_id", -1)))
		var nearby: Array = OsmService.build_nearby_targets_for_house(best_h, bldgs, pois)
		if nearby.size() < 6:
			_record_fail("OSM preset %s produced too few nearby targets (%d)" % [preset_id, nearby.size()])

		# Test up to 15 real OSM building polygons per city
		var sample_cnt: int = mini(15, bldgs.size())
		for i in range(sample_cnt):
			var b: Dictionary = bldgs[i]
			var layout: Dictionary = HouseGenerator.generate_from_osm_house(b, fam, rng)
			total_houses_tested += 1
			if not _verify_house_layout(preset_id + "#" + str(b.get("osm_id", i)), layout, 3):
				return

	# Degenerate synthetic footprints
	var degen_footprints: Array = [
		[],
		[Vector2(0, 0), Vector2(1, 0)],
		[Vector2(0, 0), Vector2(5, 0), Vector2(10, 0)],
		[Vector2(-0.05, -0.05), Vector2(0.05, -0.05), Vector2(0.05, 0.05), Vector2(-0.05, 0.05)],
		[Vector2(-1.5, -25.0), Vector2(1.5, -25.0), Vector2(1.5, 25.0), Vector2(-1.5, 25.0)],
		# L-notches in all 4 quadrants
		[Vector2(-8, -6), Vector2(8, -6), Vector2(8, 6), Vector2(0, 6), Vector2(0, 0), Vector2(-8, 0)]
	]
	for di in range(degen_footprints.size()):
		var fake_house := {"osm_id": 9000 + di, "footprint_meters": degen_footprints[di]}
		var layout_d: Dictionary = HouseGenerator.generate_from_osm_house(fake_house, fam, rng)
		total_houses_tested += 1
		if not _verify_house_layout("degenerate_" + str(di), layout_d, 3):
			return

	_record_pass("HouseGenerator verified %d real OSM & degenerate footprints with 100%% A*/BFS reachability" % total_houses_tested)

func _verify_house_layout(tag: String, layout: Dictionary, expected_family_spawns: int) -> bool:
	var rooms: Array = layout.get("rooms", [])
	var items: Array = layout.get("items", [])
	var fspawns: Array = layout.get("family_spawns", [])
	var nav_grid: Dictionary = layout.get("nav_grid", {})
	var hatch_pos: Vector2 = layout.get("hatch_pos", Vector2.ZERO)
	var start_pos: Vector2 = layout.get("leader_start_pos", Vector2.ZERO)

	# Pass 2: room count follows the real footprint size (procedural subdivision), not a fixed 6.
	var open_rooms: int = 0
	for r_v in rooms:
		if not bool((r_v as Dictionary).get("sealed", false)):
			open_rooms += 1
	# Degenerate synthetic strips (e.g. 3 m x 50 m) are correctly a single long room.
	var min_rooms: int = 1 if tag.begins_with("degenerate") else 2
	if open_rooms < min_rooms:
		_record_fail("%s expected at least %d open rooms, got %d" % [tag, min_rooms, open_rooms])
		return false
	if fspawns.size() != expected_family_spawns:
		_record_fail("%s expected %d family spawns, got %d" % [tag, expected_family_spawns, fspawns.size()])
		return false
	if items.size() < 15:
		_record_fail("%s spawned too few items (%d)" % [tag, items.size()])
		return false
	for it in items:
		var ipos: Vector2 = (it as Dictionary).get("pos", Vector2.ZERO)
		if not HouseGenerator.is_walkable(nav_grid, ipos):
			_record_fail("%s item %s spawned on non-walkable cell!" % [tag, str((it as Dictionary).get("item_id", ""))])
			return false
		var path: PackedVector2Array = HouseGenerator.find_path(nav_grid, start_pos, ipos)
		if path.size() < 2:
			_record_fail("%s A* find_path failed to item!" % tag)
			return false
	for fs in fspawns:
		var fpos: Vector2 = (fs as Dictionary).get("pos", Vector2.ZERO)
		if not HouseGenerator.is_walkable(nav_grid, fpos):
			_record_fail("%s family member spawned on non-walkable cell!" % tag)
			return false
		var fpath: PackedVector2Array = HouseGenerator.find_path(nav_grid, fpos, hatch_pos)
		if fpath.size() < 2:
			_record_fail("%s A* find_path failed from family to hatch!" % tag)
			return false
	return true

# ==============================================================================
# 4. UI SCREENS & SCAVENGE CAPACITY / TIMER EDGE CASES
# ==============================================================================
func _audit_ui_screens_and_scavenge_edge_cases() -> void:
	print("\n--- [SUITE 4] Family Creator, OSM Search & Scavenge Capacity/Timer Edge Cases ---")
	var gs: Node = root.get_node("GameState")
	gs.set("demo_mode", false)
	gs.call("init_default_family")
	gs.call("init_default_house")
	gs.call("init_default_nuke")
	gs.call("reset_to_defaults")

	# Test FamilyScreen: 1-member solo vs 4-member child/elder + custom hair colors + leader age guard
	var fam_screen: Control = FamilyScreenScript.new()
	root.add_child(fam_screen)
	await process_frame
	await process_frame

	# Remove down to 1 solo member, try removing below 1, try setting leader age to 6 (<13 guard)
	fam_screen.call("_on_remove_member_pressed")
	fam_screen.call("_on_remove_member_pressed")
	fam_screen.call("_on_remove_member_pressed")
	fam_screen.call("_on_remove_member_pressed") # Should clamp at 1!
	if (gs.get("family_members") as Array).size() != 1:
		_record_fail("FamilyScreen failed to clamp minimum household size to 1")
	fam_screen.call("_on_age_slider_changed", 6.0) # Sole leader must clamp >= 13!
	var sole_age: int = int(((gs.get("family_members") as Array)[0] as Dictionary).get("age", 0))
	if sole_age < 13:
		_record_fail("FamilyScreen allowed sole leader age < 13 (%d)" % sole_age)

	# Add back up to 4 members with Elder (78) + Child (7) + custom hair colors & condition previews
	for _i in range(3):
		fam_screen.call("_on_add_member_pressed")
	fam_screen.selected_index = 1
	fam_screen.call("_on_age_slider_changed", 78.0)
	fam_screen.call("_on_hair_color_selected", "#2bc4d8")
	fam_screen.selected_index = 2
	fam_screen.call("_on_age_slider_changed", 7.0)
	for mode in ["healthy", "starving", "sick", "insane", "mutant"]:
		fam_screen.call("_on_condition_preview_selected", mode)
		await process_frame

	fam_screen.queue_free()
	await process_frame
	_record_pass("FamilyScreen 1-member vs 4-member, child/elder, leader age guard & condition previews clean")

	# Test HouseSelectScreen: all 3 presets + empty search + coordinate search + house click
	var house_screen: Control = HouseSelectScreenScript.new()
	root.add_child(house_screen)
	await process_frame
	await process_frame
	for pid in ["concord", "brooklyn", "seattle"]:
		house_screen.call("_load_preset_neighborhood", pid, false)
		await process_frame
	var osm_svc: Node = house_screen.get("_osm_service")
	osm_svc.call("search_nominatim", "", false) # Empty query guard
	osm_svc.call("search_nominatim", "47.6242, -122.3195", false) # Coordinate query
	var cur_bldgs: Array = house_screen.get("_current_buildings")
	if not cur_bldgs.is_empty():
		house_screen.call("_on_map_house_clicked", cur_bldgs[cur_bldgs.size() / 2])
	osm_svc.call("cancel_requests")
	house_screen.queue_free()
	await process_frame
	_record_pass("HouseSelectScreen presets, empty/coord search query & house click verified")

	# Test NukeScreen: 2km close blast vs 5000km global nuclear winter
	var nuke_screen: Control = NukeScreenScript.new()
	root.add_child(nuke_screen)
	await process_frame
	var h_lat: float = float((gs.get("selected_house") as Dictionary).get("lat", 47.6242))
	var h_lon: float = float((gs.get("selected_house") as Dictionary).get("lon", -122.3195))
	var close_2km: Dictionary = NukePhysics.destination_point(h_lat, h_lon, 225.0, 2.0)
	nuke_screen.call("set_map_mode", "regional")
	nuke_screen.call("set_yield_kt", 800)
	nuke_screen.call("set_strike_target", float(close_2km["lat"]), float(close_2km["lon"]), "Close 2km Test")
	await process_frame
	if str((gs.get("nuke_config") as Dictionary).get("zone", "")) != "ground_zero_edge":
		_record_fail("NukeScreen 2km strike expected ground_zero_edge, got " + str((gs.get("nuke_config") as Dictionary).get("zone", "")))
	var far_5000km: Dictionary = NukePhysics.destination_point(h_lat, h_lon, 90.0, 5000.0)
	nuke_screen.call("set_map_mode", "global")
	nuke_screen.call("set_yield_kt", 50000)
	nuke_screen.call("set_strike_target", float(far_5000km["lat"]), float(far_5000km["lon"]), "5000km Winter Test")
	await process_frame
	if str((gs.get("nuke_config") as Dictionary).get("zone", "")) != "nuclear_winter":
		_record_fail("NukeScreen 5000km strike expected nuclear_winter, got " + str((gs.get("nuke_config") as Dictionary).get("zone", "")))
	nuke_screen.queue_free()
	await process_frame
	_record_pass("NukeScreen close 2km ground_zero_edge vs 5000km nuclear_winter verified")

	# Test ScavengeScene capacity limits (1-slot, 2-slot, 4-slot cap, suitcase 5-slot upgrade, timer expiry!)
	gs.call("init_default_family")
	gs.call("init_default_nuke")
	gs.call("reset_to_defaults")
	var scav: Node2D = ScavengeSceneScript.new()
	root.add_child(scav)
	await process_frame
	scav.call("_start_scavenge_phase")

	# Verify 4-slot limit blocks 2-slot item when 3 slots used
	var fake_rifle := {"uid": 9991, "item_id": "rifle", "pos": scav.get("_player_pos"), "slots": 2, "name": "Rifle", "short_name": "Rifle", "collected": false}
	var fake_soup1 := {"uid": 9992, "item_id": "soup", "pos": scav.get("_player_pos"), "slots": 1, "name": "Soup", "short_name": "Soup", "collected": false}
	var fake_soup2 := {"uid": 9993, "item_id": "soup", "pos": scav.get("_player_pos"), "slots": 1, "name": "Soup", "short_name": "Soup", "collected": false}
	var fake_suit := {"uid": 9994, "item_id": "suitcase", "pos": scav.get("_player_pos"), "slots": 2, "name": "Suitcase", "short_name": "Suitcase", "collected": false}

	# Pass 2 rules: grabs are timed (completed immediately here), SPACE at the hatch deposits, and the
	# suitcase raises capacity only while it is carried.
	var t_suit := {"kind": "item", "uid": 9994, "pos": fake_suit["pos"], "slots": 2, "name": "Suitcase", "item_id": "suitcase", "ref": fake_suit}
	var t_soup1 := {"kind": "item", "uid": 9992, "pos": fake_soup1["pos"], "slots": 1, "name": "Soup", "item_id": "soup", "ref": fake_soup1}
	var t_rifle := {"kind": "item", "uid": 9991, "pos": fake_rifle["pos"], "slots": 2, "name": "Rifle", "item_id": "rifle", "ref": fake_rifle}
	var t_soup2 := {"kind": "item", "uid": 9993, "pos": fake_soup2["pos"], "slots": 1, "name": "Soup", "item_id": "soup", "ref": fake_soup2}
	var ok1: bool = _grab_now(scav, t_soup1)
	var ok2: bool = _grab_now(scav, t_rifle)
	# Now at 3/4 slots -> picking up the 2-slot Suitcase MUST fail!
	var blocked_2slot: bool = _grab_now(scav, t_suit)
	# Picking up 1-slot Soup -> 4/4 slots MUST succeed!
	var ok3: bool = _grab_now(scav, t_soup2)
	if not (ok1 and ok2 and (not blocked_2slot) and ok3):
		_record_fail("Scavenge slot enforcement failed: ok1=%s ok2=%s blocked_2slot=%s ok3=%s" % [str(ok1), str(ok2), str(blocked_2slot), str(ok3)])

	# SPACE at the hatch empties the hands; then the suitcase in hand raises capacity.
	_space_deposit(scav)
	var ok_case: bool = _grab_now(scav, t_suit)
	var case_cap: int = 4 + int(ScavengeSceneScript.get("SUITCASE_EXTRA_SLOTS"))
	if not ok_case or int(scav.get("_max_slots")) != case_cap:
		_record_fail("Carried suitcase failed to raise _max_slots to %d (got %d)" % [case_cap, int(scav.get("_max_slots"))])
	var fake_soup3 := {"uid": 9995, "item_id": "soup", "pos": scav.get("_player_pos"), "slots": 1, "name": "Soup", "short_name": "Soup", "collected": false}
	_grab_now(scav, {"kind": "item", "uid": 9995, "pos": fake_soup3["pos"], "slots": 1, "name": "Soup", "item_id": "soup", "ref": fake_soup3})
	_space_deposit(scav)
	if int(scav.get("_max_slots")) != case_cap or not bool(scav.call("_is_carrying_item", "suitcase")):
		_record_fail("Suitcase should stay in hand (and keep capacity) when SPACE deposits at the hatch")

	# Test timer expiry far from hatch with 0 survivors in bunker -> leader caught outside
	scav.set("_player_pos", (scav.get("_hatch_pos") as Vector2) + Vector2(500.0, 500.0))
	scav.call("_resolve_timer_expired")
	if not bool(scav.get("_leader_caught_outside")):
		_record_fail("Scavenge timer expiry far from hatch failed to mark leader caught outside")

	scav.queue_free()
	await process_frame
	_record_pass("ScavengeScene 1-slot/2-slot capacity limits, Suitcase 5-slot upgrade & timer expiry verified")

	# Test SummaryScreen in both Victory & Defeat states
	for vic_state in [true, false]:
		gs.set("victory", vic_state)
		gs.set("game_over", true)
		gs.set("ending_title", "")
		gs.set("ending_description", "")
		var sum_scr: Control = SummaryScreenScript.new()
		root.add_child(sum_scr)
		await process_frame
		sum_scr.queue_free()
		await process_frame
	_record_pass("SummaryScreen Victory & Defeat dossiers rendered cleanly")

# ==============================================================================
# 5. EXHAUSTIVE 60-EVENT DECK & OPTION FUZZER
# ==============================================================================
func _audit_all_60_events_exhaustively() -> void:
	print("\n--- [SUITE 5] Exhaustive 60-Event Deck & Every Option Resolution Audit ---")
	var gs: Node = root.get_node("GameState")
	var rng := RandomNumberGenerator.new()
	rng.seed = 998877

	var all_ids: Array[String] = EventDeckScript.get_all_event_ids()
	if all_ids.size() < 60:
		_record_fail("Expected >= 60 events in EventDeck, got %d" % all_ids.size())

	var total_branches_tested: int = 0
	for ev_id in all_ids:
		# Test each event in TWO inventory states: (A) fully stocked + mutant + pets, (B) 0 items & 0 rations
		for state_mode in [0, 1]:
			gs.call("init_default_family")
			gs.call("init_default_house")
			gs.call("init_default_nuke")
			gs.call("reset_to_defaults")
			for m in gs.get("family_members"):
				(m as Dictionary)["in_bunker"] = true
				(m as Dictionary)["alive"] = true
			if state_mode == 0:
				gs.set("soup_quarters", 24)
				gs.set("water_quarters", 24)
				gs.set("medkit_count", 3)
				gs.set("ammo_count", 6)
				gs.set("bug_spray_count", 2)
				gs.set("padlock_active", true)
				gs.set("has_cat_sharikov", true)
				gs.set("has_dog_pancake", true)
				for gid in gs.get("DURABLE_GEAR_IDS"):
					gs.call("add_scavenged_item", str(gid), 1)
				((gs.get("family_members") as Array)[2] as Dictionary)["is_mutant"] = true
				gs.get("bunker_items")["radio"]["broken"] = true

			var built: Dictionary = EventDeckScript.build_event_by_id(ev_id, 10, rng)
			var opts: Array = built.get("options", [])
			if opts.is_empty():
				_record_fail("Event %s produced 0 options!" % ev_id)
				return
			var any_avail: bool = false
			for o in opts:
				if bool((o as Dictionary).get("available", false)):
					any_avail = true
				var cid: String = str((o as Dictionary).get("id", ""))
				var res: Dictionary = EventDeckScript.resolve_event(built, cid, rng)
				total_branches_tested += 1
				if str(res.get("outcome_text", "")).strip_edges().is_empty():
					_record_fail("Event %s choice %s produced empty outcome_text!" % [ev_id, cid])
					return
			if not any_avail:
				_record_fail("Event %s had ZERO available options in state_mode=%d (SOFTLOCK!)" % [ev_id, state_mode])
				return

	_record_pass("All %d EventDeck events & %d option branches resolved with zero format/key errors and zero softlocks" % [all_ids.size(), total_branches_tested])

# ==============================================================================
# 6. 10-SEED 35-DAY FULL BUNKER SURVIVAL FUZZER
# ==============================================================================
func _audit_10_seed_35_day_bunker_fuzz() -> void:
	print("\n--- [SUITE 6] 10-Seed 35-Day Full Bunker Simulation Fuzzer ---")
	var gs: Node = root.get_node("GameState")

	var configs: Array[Dictionary] = [
		{"seed": 1001, "members": 1, "ages": [38], "items": "zero", "zone": "near_blast", "desc": "Solo adult, 0 items (dehydration/starvation death)"},
		{"seed": 1002, "members": 1, "ages": [16], "items": "rich", "zone": "near_blast", "desc": "Solo teen + expeditions"},
		{"seed": 1003, "members": 2, "ages": [74, 8], "items": "rich", "zone": "regional_fallout", "desc": "2-member Elder (74) + Child (8), max items"},
		{"seed": 1004, "members": 4, "ages": [42, 68, 15, 9], "items": "broken", "zone": "near_blast", "desc": "4-member w/ Elder & Kid, all gear starts broken"},
		{"seed": 1005, "members": 4, "ages": [35, 34, 17, 11], "items": "rich", "zone": "nuclear_winter", "desc": "4-member Freezing Nuclear Winter (-11C)"},
		{"seed": 1006, "members": 4, "ages": [45, 41, 16, 10], "items": "moderate", "zone": "ground_zero_edge", "desc": "4-member Ground Zero Edge (9.5 Sv/hr)"},
		{"seed": 1007, "members": 4, "ages": [40, 38, 16, 9], "items": "max", "zone": "near_blast", "desc": "4-member Mutant + Pets + Church Expeditions"},
		{"seed": 1008, "members": 2, "ages": [29, 65], "items": "max", "zone": "regional_fallout", "desc": "2-member Adult + Elder 35-day endurance"},
		{"seed": 1009, "members": 4, "ages": [50, 48, 14, 6], "items": "moderate", "zone": "near_blast", "desc": "4-member random rationing & multi-POI scavenging"},
		{"seed": 1010, "members": 3, "ages": [72, 17, 7], "items": "rich", "zone": "nuclear_winter", "desc": "3-member Elder + Teen + Child winter survival"}
	]

	for cfg in configs:
		var seed_val: int = int(cfg["seed"])
		gs.set("demo_mode", false)
		gs.get("rng").seed = seed_val

		# Build custom family
		var ages: Array = cfg["ages"]
		var new_fam: Array = []
		for i in range(ages.size()):
			var a: int = int(ages[i])
			var role: String = CharacterArtist.get_role_for_age(a)
			var traits: Array[String] = ["handy", "sprinter", "iron_stomach", "scout", "bookworm", "optimist"]
			var m: Dictionary = gs.call(
				"make_family_member",
				"member_%d" % i,
				"Fuzz_%d" % i,
				role,
				a,
				(i == 0),
				traits[(seed_val + i) % traits.size()],
				i % 6, i % 8, "#4a2e1b", "#2f5d8a", (i % 2 == 0), 0, "#c84b31", i % 5
			)
			new_fam.append(m)
		gs.set("family_members", new_fam)

		# Load preset house & targets
		var preset_ids: Array[String] = ["seattle", "concord", "brooklyn"]
		var parsed: Dictionary = OsmService.load_preset(preset_ids[seed_val % 3])
		var bldgs: Array = parsed.get("buildings", [])
		var pois: Array = parsed.get("pois", [])
		var chosen_h: Dictionary = OsmService.pick_best_house(bldgs, float(parsed.get("center_lat", 0.0)), float(parsed.get("center_lon", 0.0)), -1)
		gs.set("selected_house", chosen_h)
		gs.set("nearby_pois", OsmService.build_nearby_targets_for_house(chosen_h, bldgs, pois))

		# Configure Nuke zone
		var hlat: float = float(chosen_h.get("lat", 47.6242))
		var hlon: float = float(chosen_h.get("lon", -122.3195))
		var zone_req: String = str(cfg["zone"])
		if zone_req == "nuclear_winter":
			gs.set("nuke_config", NukePhysics.compute_impact(hlat, hlon, 35.6762, 139.6503, 50000, 90.0, "Global Winter"))
		elif zone_req == "ground_zero_edge":
			var p_close: Dictionary = NukePhysics.destination_point(hlat, hlon, 225.0, 2.0)
			gs.set("nuke_config", NukePhysics.compute_impact(hlat, hlon, float(p_close["lat"]), float(p_close["lon"]), 800, 45.0, "Close 2km Blast"))
		else:
			var p_reg: Dictionary = NukePhysics.destination_point(hlat, hlon, 180.0, 18.0)
			gs.set("nuke_config", NukePhysics.compute_impact(hlat, hlon, float(p_reg["lat"]), float(p_reg["lon"]), 800, 90.0, "Metro Strike"))

		gs.call("reset_to_defaults")
		for m in gs.get("family_members"):
			(m as Dictionary)["in_bunker"] = true
			(m as Dictionary)["alive"] = true

		var items_mode: String = str(cfg["items"])
		if items_mode == "moderate":
			gs.call("add_scavenged_item", "soup", 6)
			gs.call("add_scavenged_item", "water", 7)
			gs.call("add_scavenged_item", "medkit", 2)
			gs.call("add_scavenged_item", "gas_mask", 1)
			gs.call("add_scavenged_item", "suitcase", 1)
			gs.call("add_scavenged_item", "axe", 1)
		elif items_mode == "rich" or items_mode == "max":
			gs.call("add_scavenged_item", "soup", 18)
			gs.call("add_scavenged_item", "water", 20)
			gs.call("add_scavenged_item", "medkit", 4)
			gs.call("add_scavenged_item", "ammo", 4)
			gs.call("add_scavenged_item", "bug_spray", 2)
			gs.call("add_scavenged_item", "padlock", 1)
			for gid in gs.get("DURABLE_GEAR_IDS"):
				gs.call("add_scavenged_item", str(gid), 1)
			if items_mode == "max":
				gs.set("has_cat_sharikov", true)
				gs.set("has_dog_pancake", true)
				if (gs.get("family_members") as Array).size() >= 3:
					((gs.get("family_members") as Array)[2] as Dictionary)["is_mutant"] = true
		elif items_mode == "broken":
			gs.call("add_scavenged_item", "soup", 14)
			gs.call("add_scavenged_item", "water", 16)
			gs.call("add_scavenged_item", "medkit", 2)
			for gid in gs.get("DURABLE_GEAR_IDS"):
				gs.call("add_scavenged_item", str(gid), 1)
				if str(gid) != "toolbox":
					gs.get("bunker_items")[str(gid)]["broken"] = true

		BunkerSimScript.start_bunker_run()
		var rng: RandomNumberGenerator = gs.get("rng")
		var expeditions_launched: int = 0
		var expeditions_returned: int = 0

		while int(gs.get("day")) < 35 and not bool(gs.get("game_over")):
			var cur_day: int = int(gs.get("day"))
			var ev_outcome: Dictionary = {}
			if cur_day >= 1 and not (gs.call("get_living_bunker_members") as Array).is_empty():
				var ev: Dictionary = EventDeckScript.draw_daily_event(cur_day, rng)
				var opts: Array = ev.get("options", [])
				var avail_ids: Array[String] = []
				for o in opts:
					if bool((o as Dictionary).get("available", false)):
						avail_ids.append(str((o as Dictionary).get("id", "")))
				var pick_id: String = avail_ids[rng.randi_range(0, avail_ids.size() - 1)] if not avail_ids.is_empty() else ""
				ev_outcome = EventDeckScript.resolve_event(ev, pick_id, rng)

			# Plan rations
			var rations: Dictionary = {}
			var med_id: String = ""
			var s_left: int = int(gs.get("soup_quarters"))
			var w_left: int = int(gs.get("water_quarters"))
			for m_v in gs.call("get_living_bunker_members"):
				var md: Dictionary = m_v
				var mid: String = str(md.get("id", ""))
				var sq: int = 0
				var wq: int = 0
				if (int(md.get("thirst", 0)) >= 1 or int(md.get("days_without_water", 0)) >= 2) and w_left > 0:
					wq = 1
					w_left -= 1
				if (int(md.get("hunger", 0)) >= 1 or int(md.get("days_without_food", 0)) >= 3) and s_left > 0:
					sq = 1
					s_left -= 1
				rations[mid] = {"soup_q": sq, "water_q": wq}
				if med_id == "" and int(gs.get("medkit_count")) > 0 and (int(md.get("sickness", 0)) > 0 or int(md.get("injury", 0)) > 0):
					med_id = mid

			# Randomly launch expedition if idle
			var exp_launch: Dictionary = {}
			var was_active_before: bool = not (gs.get("active_expedition") as Dictionary).is_empty()
			if not was_active_before and rng.randf() < 0.45:
				var living_in: Array = gs.call("get_living_bunker_members")
				var elig: Array = []
				for m_v2 in living_in:
					var md2: Dictionary = m_v2
					if int(md2.get("age", 30)) >= 13:
						elig.append(md2)
				var targets: Array = ExpeditionEngineScript.get_available_targets()
				if not elig.is_empty() and not targets.is_empty():
					var chosen_m: Dictionary = elig[rng.randi_range(0, elig.size() - 1)]
					var t_idx: int = rng.randi_range(0, targets.size() - 1)
					var gear: Array[String] = []
					var max_gear_items: int = 4 if bool(gs.call("has_working_item", "suitcase")) else 1
					for g_cand in ["suitcase", "gas_mask", "rifle", "axe", "flashlight", "map"]:
						if bool(gs.call("has_working_item", g_cand)) and gear.size() < max_gear_items:
							gear.append(g_cand)
					exp_launch = {"member_id": str(chosen_m["id"]), "poi_index": t_idx, "gear_ids": gear}
					expeditions_launched += 1

			BunkerSimScript.advance_day(rations, med_id, ev_outcome, exp_launch)
			var is_active_after: bool = not (gs.get("active_expedition") as Dictionary).is_empty()
			if was_active_before and not is_active_after:
				expeditions_returned += 1

			# Sanity check: no negative counts, no NaN radiation/temp
			if int(gs.get("soup_quarters")) < 0 or int(gs.get("water_quarters")) < 0 or int(gs.get("medkit_count")) < 0 or int(gs.get("ammo_count")) < 0:
				_record_fail("Seed %d produced negative inventory count on Day %d!" % [seed_val, int(gs.get("day"))])
				return
			if is_nan(float(gs.get("surface_radiation_sv"))) or is_nan(float(gs.get("bunker_temp_c"))):
				_record_fail("Seed %d produced NaN rad/temp on Day %d!" % [seed_val, int(gs.get("day"))])
				return

		print("  FUZZ seed=%d (%s) -> ended Day %d | game_over=%s | victory=%s | exp_out=%d exp_ret=%d | title='%s'" % [
			seed_val, str(cfg["desc"]), int(gs.get("day")),
			str(gs.get("game_over")), str(gs.get("victory")),
			expeditions_launched, expeditions_returned, str(gs.get("ending_title"))
		])

	_record_pass("All 10 multi-seed 35-day Bunker simulations completed with zero runtime/math errors")

# ==============================================================================
# 7. TARGETED LOGIC BUG REPRODUCTIONS
# ==============================================================================
func _audit_targeted_bug_repros() -> void:
	print("\n--- [SUITE 7] Targeted Edge-Case & State Transition Bug Repros ---")
	var gs: Node = root.get_node("GameState")

	# Repro A: Raider Overrun -> game_over = true, victory = false
	gs.call("init_default_family")
	gs.call("init_default_house")
	gs.call("init_default_nuke")
	gs.call("reset_to_defaults")
	var m0: Dictionary = (gs.get("family_members") as Array)[0]
	m0["in_bunker"] = true
	m0["alive"] = true
	for i in range(1, (gs.get("family_members") as Array).size()):
		((gs.get("family_members") as Array)[i] as Dictionary)["in_bunker"] = false
		((gs.get("family_members") as Array)[i] as Dictionary)["alive"] = false
	gs.set("day", 15)
	gs.set("bunker_structural_integrity", 25.0)
	gs.set("padlock_active", false)
	gs.set("soup_quarters", 8)
	gs.set("water_quarters", 8)

	var raid_ev: Dictionary = EventDeckScript.build_event_by_id("raiders_blast_hatch", 15, gs.get("rng"))
	var raid_out: Dictionary = EventDeckScript.resolve_event(raid_ev, "cower", gs.get("rng"))
	var game_over_after_event: bool = bool(gs.get("game_over"))
	BunkerSimScript.advance_day({}, "", raid_out, {})
	var game_over_after_advance: bool = bool(gs.get("game_over"))
	var victory_after_advance: bool = bool(gs.get("victory"))
	print("  REPRO A (Raider Overrun): game_over_after_event=%s -> game_over=%s victory=%s | hull=%.1f | log='%s'" % [
		str(game_over_after_event), str(game_over_after_advance), str(victory_after_advance),
		float(gs.get("bunker_structural_integrity")), str(raid_out.get("outcome_text", ""))
	])
	if not game_over_after_advance or victory_after_advance:
		_record_fail("REPRO A FAILED: Raider Overrun expected game_over=true & victory=false, got game_over=%s victory=%s" % [str(game_over_after_advance), str(victory_after_advance)])
	else:
		_record_pass("Raider Overrun Game Over preserved (game_over=true, victory=false) across BunkerSimScript.advance_day")

	# Repro B: Parched Stage-3 Evacuation -> game_over = true, victory = true (Military, Sanctuary, Scientist)
	var stage3_cases: Array[Dictionary] = [
		{"chain": "military", "event_id": "rescue_military_3", "choice": "yes"},
		{"chain": "sanctuary", "event_id": "rescue_sanctuary_3", "choice": "yes"},
		{"chain": "scientist", "event_id": "rescue_scientist_3", "choice": "yes"}
	]
	var all_stage3_ok: bool = true
	for s3 in stage3_cases:
		gs.call("init_default_family")
		gs.call("reset_to_defaults")
		var m0b: Dictionary = (gs.get("family_members") as Array)[0]
		m0b["in_bunker"] = true
		m0b["alive"] = true
		m0b["days_without_water"] = 5 # Critical thirst threshold!
		m0b["days_without_food"] = 10
		for i in range(1, (gs.get("family_members") as Array).size()):
			((gs.get("family_members") as Array)[i] as Dictionary)["in_bunker"] = false
			((gs.get("family_members") as Array)[i] as Dictionary)["alive"] = false
		gs.set("day", 14)
		gs.set("has_cat_sharikov", true)
		gs.get("rescue_chains")[str(s3["chain"])] = 2
		var r3_ev: Dictionary = EventDeckScript.build_event_by_id(str(s3["event_id"]), 14, gs.get("rng"))
		var r3_out: Dictionary = EventDeckScript.resolve_event(r3_ev, str(s3["choice"]), gs.get("rng"))
		var vic_after_ev: bool = bool(gs.get("victory"))
		var go_after_ev: bool = bool(gs.get("game_over"))
		BunkerSimScript.advance_day({}, "", r3_out, {})
		var vic_after_adv: bool = bool(gs.get("victory"))
		var go_after_adv: bool = bool(gs.get("game_over"))
		print("  REPRO B (%s): after_ev=(go=%s,vic=%s) -> after_adv=(go=%s,vic=%s) | ending='%s'" % [
			str(s3["event_id"]), str(go_after_ev), str(vic_after_ev), str(go_after_adv), str(vic_after_adv), str(gs.get("ending_title"))
		])
		if not (go_after_adv and vic_after_adv):
			all_stage3_ok = false
			_record_fail("REPRO B FAILED (%s): Expected game_over=true & victory=true, got game_over=%s victory=%s" % [str(s3["event_id"]), str(go_after_adv), str(vic_after_adv)])
	if all_stage3_ok:
		_record_pass("Parched Stage-3 Evacuation (Military, Sanctuary, Scientist) preserved game_over=true & victory=true")

	# Repro C: Solo Explorer Outside -> BunkerScene Unoccupied Shelter Guard (0 phantom dilemmas)
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	var solo_m: Dictionary = (gs.get("family_members") as Array)[0]
	gs.set("family_members", [solo_m])
	solo_m["in_bunker"] = true
	solo_m["alive"] = true
	BunkerSimScript.start_bunker_run()
	gs.set("day", 2)
	ExpeditionEngineScript.start_expedition("member_0", 0, [])
	var living_in_bunker_now: Array = gs.call("get_living_bunker_members")
	var bunker_solo_scene: Control = BunkerSceneScript.new()
	root.add_child(bunker_solo_scene)
	await process_frame
	var solo_cur_ev: Dictionary = bunker_solo_scene.get("_current_event")
	var solo_unresolved: bool = bool(bunker_solo_scene.get("_has_unresolved_dilemma"))
	print("  REPRO C (Empty Shelter while Solo Explorer Out): living_in_bunker=%d, _current_event_empty=%s, _has_unresolved_dilemma=%s" % [
		living_in_bunker_now.size(), str(solo_cur_ev.is_empty()), str(solo_unresolved)
	])
	bunker_solo_scene.queue_free()
	await process_frame
	if not living_in_bunker_now.is_empty() or not solo_cur_ev.is_empty() or solo_unresolved:
		_record_fail("REPRO C FAILED: Empty shelter drew a dilemma while solo explorer was outside!")
	else:
		_record_pass("BunkerScene Empty Shelter Guard verified: zero indoor dilemmas drawn when solo explorer is outside")

	# Repro D: Day 1 Civil Defense Event & Suitcase Expedition Gear Limit (1 item vs Suitcase + 3 = 4 items)
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	for m_d in gs.get("family_members"):
		(m_d as Dictionary)["in_bunker"] = true
		(m_d as Dictionary)["alive"] = true
	for gid in ["gas_mask", "rifle", "axe", "flashlight", "map"]:
		gs.call("add_scavenged_item", gid, 1)
	var day1_ev: Dictionary = EventDeckScript.draw_daily_event(1, gs.get("rng"))
	if str(day1_ev.get("id", "")) != "day1_civil_defense_seal":
		_record_fail("Expected Day 1 event 'day1_civil_defense_seal', got '%s'" % str(day1_ev.get("id", "")))
	else:
		_record_pass("Day 1 event verified: day1_civil_defense_seal")

	# Without Suitcase: requesting 3 items clamps to 1 item
	ExpeditionEngineScript.start_expedition("member_0", 0, ["gas_mask", "rifle", "map"])
	var gear_no_suit: Array = (gs.get("active_expedition") as Dictionary).get("gear_ids", [])
	if gear_no_suit.size() != 1:
		_record_fail("Expected 1 expedition gear item without Suitcase, got %s" % str(gear_no_suit))
	# Reset and test WITH Suitcase: requesting Suitcase + 4 extras clamps to Suitcase + 3 extras (4 total)
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	for m_d2 in gs.get("family_members"):
		(m_d2 as Dictionary)["in_bunker"] = true
		(m_d2 as Dictionary)["alive"] = true
	for gid2 in ["suitcase", "gas_mask", "rifle", "axe", "flashlight", "map"]:
		gs.call("add_scavenged_item", gid2, 1)
	ExpeditionEngineScript.start_expedition("member_0", 0, ["suitcase", "gas_mask", "rifle", "axe", "flashlight"])
	var gear_with_suit: Array = (gs.get("active_expedition") as Dictionary).get("gear_ids", [])
	print("  REPRO D (Suitcase Gear Limit): without_suitcase=%s (len=%d) | with_suitcase=%s (len=%d)" % [
		str(gear_no_suit), gear_no_suit.size(), str(gear_with_suit), gear_with_suit.size()
	])
	if gear_with_suit.size() != 4 or not gear_with_suit.has("suitcase"):
		_record_fail("Expected Suitcase + 3 extra items (4 total) with Suitcase, got %s" % str(gear_with_suit))
	else:
		_record_pass("Expedition gear limit verified: 1 item without Suitcase, Suitcase + 3 items (4 total) with Suitcase")

# ==============================================================================
# 8. FULL END-TO-END --demo-showcase TIMING & PROGRESSION VERIFICATION
# ==============================================================================
func _audit_full_demo_showcase() -> void:
	print("\n--- [SUITE 8] Full End-to-End --demo-showcase Timing & Phase Audit ---")
	var gs: Node = root.get_node("GameState")

	# Configure exact --demo-showcase initial state
	gs.set("family_members", [])
	gs.set("selected_house", {})
	gs.set("nearby_pois", [])
	gs.set("nuke_config", {})
	gs.set("demo_mode", true)
	gs.set("headless_fast_test", false)
	gs.get("rng").seed = 60602026
	gs.call("reset_to_defaults")
	BunkerSceneScript.demo_completed_flag = false

	var main_packed: PackedScene = load("res://scenes/main.tscn")
	var main_inst: Control = main_packed.instantiate()
	root.add_child(main_inst)

	var visited_screens: Array[String] = []
	var phase_enter_frame: Dictionary = {}
	var phase_exit_frame: Dictionary = {}
	var bunker_tabs_seen: Array[int] = []
	var bunker_days_seen: Array[int] = []
	var expedition_launched_info: Dictionary = {}
	var expedition_returned_day: int = -1

	var cur_scr: String = str(gs.get("current_screen"))
	visited_screens.append(cur_scr)
	phase_enter_frame[cur_scr] = 0

	var frame_idx: int = 0
	var max_frames: int = 3600 # 120s @ 30 FPS safety ceiling
	var wall_start_ms: int = Time.get_ticks_msec()

	while frame_idx < max_frames:
		await process_frame
		frame_idx += 1

		var now_scr: String = str(gs.get("current_screen"))
		if now_scr != cur_scr:
			phase_exit_frame[cur_scr] = frame_idx
			phase_enter_frame[now_scr] = frame_idx
			visited_screens.append(now_scr)
			print("  [DEMO t=%6.2fs | frame=%4d] Transition: %s -> %s" % [
				float(frame_idx) / 30.0, frame_idx, cur_scr, now_scr
			])
			if cur_scr == "scavenge":
				print("    SCAVENGE STATS: ", gs.get("scavenge_stats"))
				print("    BUNKER STOCK: soup_q=%d water_q=%d medkits=%d" % [
					int(gs.get("soup_quarters")), int(gs.get("water_quarters")), int(gs.get("medkit_count"))
				])
			cur_scr = now_scr

		if now_scr == "bunker":
			var d_now: int = int(gs.get("day"))
			if not bunker_days_seen.has(d_now):
				bunker_days_seen.append(d_now)
				print("  [DEMO t=%6.2fs | frame=%4d] Bunker Day %d started" % [
					float(frame_idx) / 30.0, frame_idx, d_now
				])
			var active_node: Node = main_inst.get("_active_node")
			if is_instance_valid(active_node) and active_node.get_script() == BunkerSceneScript:
				var tab_idx: int = int(active_node.get("_current_tab"))
				if bool(active_node.get("_notebook_open")) and not bunker_tabs_seen.has(tab_idx):
					bunker_tabs_seen.append(tab_idx)
			var act_exp: Dictionary = gs.get("active_expedition")
			if not act_exp.is_empty() and expedition_launched_info.is_empty():
				expedition_launched_info = act_exp.duplicate(true)
				print("  [DEMO t=%6.2fs | frame=%4d] OSM Expedition Launched: %s -> %s (cat=%s, days=%d, gear=%s)" % [
					float(frame_idx) / 30.0, frame_idx,
					str(act_exp.get("member_name", "")),
					str(act_exp.get("target_name", "")),
					str(act_exp.get("category", "")),
					int(act_exp.get("days_total", 0)),
					str(act_exp.get("gear_ids", []))
				])
			elif act_exp.is_empty() and not expedition_launched_info.is_empty() and expedition_returned_day < 0:
				expedition_returned_day = d_now
				print("  [DEMO t=%6.2fs | frame=%4d] OSM Expedition Returned on Day %d! Latest log: %s" % [
					float(frame_idx) / 30.0, frame_idx, d_now,
					BunkerSimScript.get_latest_day_report().replace("\n", " | ")
				])

		if BunkerSceneScript.demo_completed_flag:
			phase_exit_frame[cur_scr] = frame_idx
			break

	var wall_elapsed_s: float = float(Time.get_ticks_msec() - wall_start_ms) / 1000.0
	var sim_elapsed_30fps_s: float = float(frame_idx) / 30.0

	print("\n  === DEMO SHOWCASE EXACT TIMING BREAKDOWN (@ 30 FPS) ===")
	for s_name in visited_screens:
		var f0: int = int(phase_enter_frame.get(s_name, 0))
		var f1: int = int(phase_exit_frame.get(s_name, frame_idx))
		var df: int = f1 - f0
		print("  %-14s : frames %4d -> %4d (%4d frames = %6.2fs)" % [
			s_name, f0, f1, df, float(df) / 30.0
		])
	print("  TOTAL TO DAY 4 DEMO COMPLETE : %d frames = %.2fs (@ 30 FPS) | +2.0s quit hold = %d frames (%.2fs) | wall=%.2fs" % [
		frame_idx, sim_elapsed_30fps_s, frame_idx + 60, sim_elapsed_30fps_s + 2.0, wall_elapsed_s
	])
	print("  Bunker days seen: ", bunker_days_seen)
	print("  Bunker tabs opened: ", bunker_tabs_seen)

	var expected_order: Array[String] = ["title", "family", "osm_house", "nuke", "scavenge", "bunker"]
	if visited_screens != expected_order:
		_record_fail("Demo screen order mismatch! Expected %s, got %s" % [str(expected_order), str(visited_screens)])
	elif not BunkerSceneScript.demo_completed_flag:
		_record_fail("Demo showcase timed out before BunkerSceneScript.demo_completed_flag!")
	elif expedition_launched_info.is_empty() or expedition_returned_day < 0:
		_record_fail("Demo showcase failed to launch & complete OSM expedition! launched=%s ret_day=%d" % [str(expedition_launched_info), expedition_returned_day])
	elif bunker_days_seen != [1, 2, 3, 4]:
		_record_fail("Demo showcase did not progress cleanly through Days 1..4: got " + str(bunker_days_seen))
	elif bunker_tabs_seen.size() < 4:
		_record_fail("Demo showcase did not open all 4 notebook tabs: got " + str(bunker_tabs_seen))
	else:
		_record_pass("Full --demo-showcase verified end-to-end across all 6 screens, scavenge haul, 4 bunker days, all 4 tabs & OSM expedition return!")

	main_inst.queue_free()
	await process_frame
	await process_frame


# Pass 2 helpers: a grab takes GRAB_TIME_*; complete it immediately for unit-level checks.
func _grab_now(scav: Node, target: Dictionary) -> bool:
	if not bool(scav.call("_attempt_pickup_target", target)):
		return false
	scav.set("_pending_action", {})
	return bool(scav.call("_complete_pickup", target))


func _space_deposit(scav: Node) -> void:
	scav.set("_player_pos", scav.get("_hatch_pos"))
	scav.call("_context_action")
	for _i in range(60):
		if (scav.get("_pending_action") as Dictionary).is_empty():
			break
		scav.call("_process_pending_action", 0.05)
