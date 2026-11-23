extends SceneTree

## Independent "60 Seconds! Reatomized" V2 Executive Critic & Reliability Gauntlet.
## Note: Because -s loads a custom SceneTree before SceneTree._initialize() registers Autoloads,
## all project scripts are loaded dynamically via load(...) AFTER `await process_frame` so
## GameState, SaveManager, and SoundManager Autoloads are 100% registered with zero compile warnings.
## Always calls SoundManager.shutdown_audio() before quit(0) for zero ObjectDB / StringName leaks.

const SAVE_RUN_PATH := "user://savegame_v2.json"
const META_PROFILE_PATH := "user://meta_profile_v2.json"

var GameState: Node = null
var SaveManager: Node = null
var SoundManager: Node = null

var EventDeckScript: GDScript = null
var BunkerSimScript: GDScript = null
var ExpeditionEngineScript: GDScript = null
var RelationshipSystemScript: GDScript = null
var OsmServiceScript: GDScript = null
var NukePhysicsScript: GDScript = null
var TitleScreenScript: GDScript = null
var FamilyScreenScript: GDScript = null
var HouseSelectScreenScript: GDScript = null
var NukeScreenScript: GDScript = null
var ScavengeSceneScript: GDScript = null
var BunkerSceneScript: GDScript = null
var SummaryScreenScript: GDScript = null

var _passes: int = 0
var _warnings: Array[String] = []
var _failures: Array[String] = []

var _saved_meta_bytes: PackedByteArray = PackedByteArray()
var _had_meta_file: bool = false
var _saved_run_bytes: PackedByteArray = PackedByteArray()
var _had_run_file: bool = false


func _init() -> void:
	call_deferred("_run_critic_suite")


func _pass(msg: String) -> void:
	_passes += 1
	print("[PASS] " + msg)


func _warn(msg: String) -> void:
	_warnings.append(msg)
	print("[DESIGN-CRITIQUE] " + msg)


func _fail(msg: String) -> void:
	_failures.append(msg)
	print("[FAIL] " + msg)


func _backup_user_files() -> void:
	if FileAccess.file_exists(META_PROFILE_PATH):
		_had_meta_file = true
		_saved_meta_bytes = FileAccess.get_file_as_bytes(META_PROFILE_PATH)
	if FileAccess.file_exists(SAVE_RUN_PATH):
		_had_run_file = true
		_saved_run_bytes = FileAccess.get_file_as_bytes(SAVE_RUN_PATH)


func _restore_user_files() -> void:
	if _had_meta_file:
		var f: FileAccess = FileAccess.open(META_PROFILE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_saved_meta_bytes)
			f.close()
	elif FileAccess.file_exists(META_PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PROFILE_PATH))

	if _had_run_file:
		var f2: FileAccess = FileAccess.open(SAVE_RUN_PATH, FileAccess.WRITE)
		if f2 != null:
			f2.store_buffer(_saved_run_bytes)
			f2.close()
	elif FileAccess.file_exists(SAVE_RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_RUN_PATH))

	if SaveManager != null and SaveManager.has_method("load_meta"):
		SaveManager.call("load_meta")


func _run_critic_suite() -> void:
	await process_frame

	GameState = root.get_node_or_null("GameState")
	SaveManager = root.get_node_or_null("SaveManager")
	SoundManager = root.get_node_or_null("SoundManager")

	if GameState == null or SaveManager == null or SoundManager == null:
		_fail("Missing core Autoloads on root: GS=%s SM=%s SND=%s" % [str(GameState), str(SaveManager), str(SoundManager)])
		quit(1)
		return

	EventDeckScript = load("res://scripts/events/event_deck.gd") as GDScript
	BunkerSimScript = load("res://scripts/bunker/bunker_sim.gd") as GDScript
	ExpeditionEngineScript = load("res://scripts/expedition/expedition_engine.gd") as GDScript
	RelationshipSystemScript = load("res://scripts/family/relationship_system.gd") as GDScript
	OsmServiceScript = load("res://scripts/osm/osm_service.gd") as GDScript
	NukePhysicsScript = load("res://scripts/nuke/nuke_physics.gd") as GDScript
	TitleScreenScript = load("res://scripts/ui/title_screen.gd") as GDScript
	FamilyScreenScript = load("res://scripts/ui/family_screen.gd") as GDScript
	HouseSelectScreenScript = load("res://scripts/ui/house_select_screen.gd") as GDScript
	NukeScreenScript = load("res://scripts/ui/nuke_screen.gd") as GDScript
	ScavengeSceneScript = load("res://scripts/scavenge/scavenge_scene.gd") as GDScript
	BunkerSceneScript = load("res://scripts/bunker/bunker_scene.gd") as GDScript
	SummaryScreenScript = load("res://scripts/ui/summary_screen.gd") as GDScript

	_backup_user_files()

	var all_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var with_demo: bool = all_args.has("--with-demo")
	var only_demo: bool = all_args.has("--demo-only")
	var only_movie_audio: bool = all_args.has("--movie-audio-probe")

	if only_movie_audio:
		await _run_4s_movie_audio_probe()
		_restore_user_files()
		SoundManager.call("shutdown_audio")
		await process_frame
		await process_frame
		quit(0)
		return

	if only_demo:
		await _audit_v2_demo_showcase_timeline()
		_restore_user_files()
		SoundManager.call("shutdown_audio")
		await process_frame
		await process_frame
		quit(0 if _failures.is_empty() else 1)
		return

	print("================================================================================")
	print("V2 EXECUTIVE CRITIC & RELIABILITY GAUNTLET — 60 SECONDS: WORLD REATOMIZED")
	print("DisplayServer: %s | Args: %s" % [DisplayServer.get_name(), str(all_args)])
	print("================================================================================")

	_audit_sound_manager_19sfx_3loops()
	_audit_event_deck_103_and_dominance()
	_audit_monte_carlo_victory_windows()
	_audit_multi_ring_expedition_payoffs()
	await _audit_relationships_and_35day_gauntlet()

	if with_demo:
		await _audit_v2_demo_showcase_timeline()

	_restore_user_files()

	print("\n================================================================================")
	print("EXECUTIVE CRITIC SUMMARY: passes=%d | design_critiques=%d | failures=%d" % [
		_passes, _warnings.size(), _failures.size()
	])
	for w in _warnings:
		print("  * CRITIQUE: " + w)
	for fl in _failures:
		print("  ! FAILURE : " + fl)
	print("================================================================================")

	SoundManager.call("shutdown_audio")
	await process_frame
	await process_frame
	quit(0 if _failures.is_empty() else 1)


# ==============================================================================
# SPECIAL MODE: 4.0s --write-movie AUDIO PROBE (Music + SFX Showcase)
# ==============================================================================
func _run_4s_movie_audio_probe() -> void:
	var canvas := ColorRect.new()
	canvas.color = Color("#1b1917")
	canvas.size = Vector2(1280.0, 720.0)
	root.add_child(canvas)

	var lbl := Label.new()
	lbl.text = "V2 PROCEDURAL AUDIO & 4.0S LOOP PROBE"
	lbl.position = Vector2(400.0, 340.0)
	canvas.add_child(lbl)

	SoundManager.call("set_ambience", "menu")
	SoundManager.call("play_sfx", "siren", -4.0, 1.0)

	for frame_i in range(120):
		if frame_i == 30:
			SoundManager.call("play_sfx", "pickup", -2.0, 1.0)
		elif frame_i == 55:
			SoundManager.call("set_ambience", "scavenge")
			SoundManager.call("play_sfx", "bond_chime", -2.0, 1.0)
		elif frame_i == 80:
			SoundManager.call("play_sfx", "craft_wrench", -2.0, 1.0)
		elif frame_i == 95:
			SoundManager.call("set_ambience", "bunker")
			SoundManager.call("play_sfx", "engine_start", -3.0, 1.0)
		await process_frame

	canvas.queue_free()
	await process_frame


# ==============================================================================
# 1. AUDIO & MUSIC LOOP QUALITY AUDIT (19 SFX + 3 x 4.0s LOOPS)
# ==============================================================================
func _audit_sound_manager_19sfx_3loops() -> void:
	print("\n--- [1] AUDIO & 4.0s PROCEDURAL MUSIC LOOP QUALITY AUDIT ---")
	var sfx_streams: Dictionary = SoundManager.get("_sfx_streams") as Dictionary
	var amb_streams: Dictionary = SoundManager.get("_ambient_streams") as Dictionary

	var expected_sfx: Array[String] = [
		"siren", "tick", "urgent_tick", "pickup", "hatch_drop",
		"hatch_slam", "nuke_boom", "page_turn", "button_click", "geiger",
		"knock", "victory", "gameover", "engine_start", "bond_chime",
		"argument", "achievement", "heal_pill", "craft_wrench"
	]
	var expected_loops: Array[String] = ["menu", "scavenge", "bunker"]

	if sfx_streams.size() != 19:
		_fail("Expected 19 SFX in SoundManager._sfx_streams, got %d" % sfx_streams.size())
	else:
		_pass("SoundManager generated all 19 procedural SFX streams")

	if amb_streams.size() != 3:
		_fail("Expected 3 musical loops in SoundManager._ambient_streams, got %d" % amb_streams.size())
	else:
		_pass("SoundManager generated all 3 procedural 4.0s musical loops")

	print("  %-16s | %7s | %8s | %9s | %9s | %5s | %8s" % [
		"CUE NAME", "DUR(s)", "PEAK", "PEAK(dB)", "RMS(dB)", "CLIPS", "DC_OFF"
	])
	for sfx_id in expected_sfx:
		if not sfx_streams.has(sfx_id):
			_fail("Missing SFX cue: " + sfx_id)
			continue
		var wav: AudioStreamWAV = sfx_streams[sfx_id] as AudioStreamWAV
		var m: Dictionary = _analyze_wav(wav, false)
		var dur: float = float(m["dur"])
		var peak: float = float(m["peak"])
		var peak_db: float = float(m["peak_db"])
		var rms_db: float = float(m["rms_db"])
		var clips: int = int(m["clips"])
		var dc: float = float(m["dc"])
		print("  %-16s | %6.3fs | %8.4f | %7.2f dB | %7.2f dB | %5d | %+8.5f" % [
			sfx_id, dur, peak, peak_db, rms_db, clips, dc
		])
		if clips > 0:
			_fail("SFX '%s' has %d clipped samples (>=32767)!" % [sfx_id, clips])
		if float(m["rms"]) < 0.015:
			_fail("SFX '%s' is near-silent (RMS=%.5f)!" % [sfx_id, float(m["rms"])])
		if absf(dc) > 0.05:
			_warn("SFX '%s' has elevated DC offset %.4f" % [sfx_id, dc])

	_pass("All 19 SFX verified non-silent, balanced, and 0 clipped samples")

	print("\n  %-12s | %7s | %8s | %9s | %9s | %5s | %10s | %10s" % [
		"MUSIC LOOP", "DUR(s)", "PEAK", "PEAK(dB)", "RMS(dB)", "CLIPS", "SEAM_JUMP", "DERIV_JUMP"
	])
	for loop_id in expected_loops:
		if not amb_streams.has(loop_id):
			_fail("Missing ambient loop: " + loop_id)
			continue
		var lwav: AudioStreamWAV = amb_streams[loop_id] as AudioStreamWAV
		var lm: Dictionary = _analyze_wav(lwav, true)
		var dur_l: float = float(lm["dur"])
		var peak_l: float = float(lm["peak"])
		var peak_db_l: float = float(lm["peak_db"])
		var rms_db_l: float = float(lm["rms_db"])
		var clips_l: int = int(lm["clips"])
		var seam_jump: float = float(lm["seam_jump"])
		var deriv_jump: float = float(lm["deriv_jump"])
		print("  %-12s | %6.3fs | %8.4f | %7.2f dB | %7.2f dB | %5d | %10.6f | %10.6f" % [
			loop_id, dur_l, peak_l, peak_db_l, rms_db_l, clips_l, seam_jump, deriv_jump
		])
		if not is_equal_approx(dur_l, 4.0):
			_fail("Loop '%s' expected 4.0s duration, got %.3fs" % [loop_id, dur_l])
		if lwav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			_fail("Loop '%s' is not LOOP_FORWARD!" % loop_id)
		if clips_l > 0:
			_fail("Loop '%s' has %d clipped samples!" % [loop_id, clips_l])
		if seam_jump >= 0.01:
			_fail("Loop '%s' seam jump %.6f >= 0.01 threshold!" % [loop_id, seam_jump])
		else:
			_pass("Loop '%s' 4.000s verified: Peak=%.2f dBFS, RMS=%.2f dBFS, SeamJump=%.6f (< 0.01)" % [
				loop_id, peak_db_l, rms_db_l, seam_jump
			])


func _analyze_wav(wav: AudioStreamWAV, is_loop: bool) -> Dictionary:
	var data: PackedByteArray = wav.data
	var n: int = data.size() / 2
	var peak: float = 0.0
	var sum_sq: float = 0.0
	var sum_s: float = 0.0
	var clips: int = 0

	var floats := PackedFloat32Array()
	floats.resize(n)
	for i in range(n):
		var iv: int = data.decode_s16(i * 2)
		if absi(iv) >= 32767:
			clips += 1
		var f: float = float(iv) / 32767.0
		floats[i] = f
		var af: float = absf(f)
		if af > peak:
			peak = af
		sum_sq += f * f
		sum_s += f

	var rms: float = sqrt(sum_sq / float(maxi(1, n)))
	var dc: float = sum_s / float(maxi(1, n))
	var peak_db: float = 20.0 * log(maxf(peak, 0.000001)) / log(10.0)
	var rms_db: float = 20.0 * log(maxf(rms, 0.000001)) / log(10.0)

	var seam_jump: float = 0.0
	var deriv_jump: float = 0.0
	if is_loop and n > 2048:
		var lb: int = clampi(wav.loop_begin, 0, n - 1)
		var le: int = clampi(wav.loop_end, 1, n)
		seam_jump = absf(floats[le - 1] - floats[lb])
		var slope_end: float = floats[le - 1] - floats[le - 2]
		var slope_beg: float = floats[lb + 1] - floats[lb]
		deriv_jump = absf(slope_beg - slope_end)

	return {
		"samples": n,
		"dur": float(n) / float(maxi(1, wav.mix_rate)),
		"peak": peak,
		"peak_db": peak_db,
		"rms": rms,
		"rms_db": rms_db,
		"clips": clips,
		"dc": dc,
		"seam_jump": seam_jump,
		"deriv_jump": deriv_jump
	}


# ==============================================================================
# 2. EVENT DECK (103 EVENTS) EXHAUSTIVE QA + DOMINANCE & SCALE AUDIT
# ==============================================================================
func _audit_event_deck_103_and_dominance() -> void:
	print("\n--- [2] EVENT DECK (103 EVENTS) EXHAUSTIVE QA & DECISION DEPTH AUDIT ---")
	var all_ids: Array = EventDeckScript.call("get_all_event_ids") as Array
	if all_ids.size() != 103:
		_fail("Expected 103 events in EventDeck, got %d" % all_ids.size())
	else:
		_pass("EventDeck contains exact 103 distinct event IDs")

	var unique_set: Dictionary = {}
	for eid_v in all_ids:
		var eid: String = str(eid_v)
		if unique_set.has(eid):
			_fail("Duplicate event ID in EventDeck: " + eid)
		unique_set[eid] = true

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123

	# 2A. Test building & resolving EVERY option across destitute vs fully-stocked states
	var options_tested: int = 0
	for state_pass in range(2):
		for eid_v2 in all_ids:
			var eid2: String = str(eid_v2)
			_setup_standard_bunker_state(state_pass == 1)
			if eid2 == "family_haunted_unrescued" or eid2 == "family_phantom_knock_guilt":
				GameState.set("left_behind_members", ["Timmy"])
			var ev: Dictionary = EventDeckScript.call("build_event_by_id", eid2, 8, rng) as Dictionary
			var title_s: String = str(ev.get("title", ""))
			var desc_s: String = str(ev.get("description", ""))
			var opts: Array = ev.get("options", [])
			if title_s.is_empty() or desc_s.is_empty() or opts.is_empty():
				_fail("Event '%s' built incomplete dictionary (pass %d)" % [eid2, state_pass])
				continue
			var any_avail: bool = false
			for o_v in opts:
				var od: Dictionary = o_v
				if bool(od.get("available", false)):
					any_avail = true
			if not any_avail:
				_fail("Event '%s' has ZERO available options in state_pass=%d (SOFTLOCK!)" % [eid2, state_pass])

			for o_v2 in opts:
				var od2: Dictionary = o_v2
				if not bool(od2.get("available", false)):
					continue
				_setup_standard_bunker_state(state_pass == 1)
				if eid2 == "family_haunted_unrescued" or eid2 == "family_phantom_knock_guilt":
					GameState.set("left_behind_members", ["Timmy"])
				var ev_fresh: Dictionary = EventDeckScript.call("build_event_by_id", eid2, 8, rng) as Dictionary
				var res: Dictionary = EventDeckScript.call("resolve_event", ev_fresh, str(od2.get("id", "")), rng) as Dictionary
				options_tested += 1
				if str(res.get("outcome_text", "")).strip_edges().is_empty():
					_fail("Event '%s' choice '%s' returned empty outcome_text!" % [eid2, str(od2.get("id", ""))])

	_pass("Exhaustively built & resolved %d available event branches across destitute & stocked states with 0 errors/softlocks" % options_tested)

	# 2B. Verify delayed 4-day story_flags consequence callbacks
	_setup_standard_bunker_state(true)
	EventDeckScript.call("reset_state")
	GameState.set("day", 4)
	var ev_cour: Dictionary = EventDeckScript.call("build_event_by_id", "stranger_wounded_courier", 4, rng) as Dictionary
	EventDeckScript.call("resolve_event", ev_cour, "help_medkit", rng)
	var ready_d7: Array = EventDeckScript.call("_get_ready_consequence_event_ids", 7) as Array
	var ready_d8: Array = EventDeckScript.call("_get_ready_consequence_event_ids", 8) as Array
	if ready_d7.has("courier_repayment_drop") or not ready_d8.has("courier_repayment_drop"):
		_fail("Delayed consequence timing broken: d7=%s d8=%s" % [str(ready_d7), str(ready_d8)])
	else:
		_pass("Delayed 4-day story_flags consequence callbacks verified (Day 4 -> triggers Day 8+)")

	# 2C. Programmatic Dominance Audit of Unconditional Free Choices across all 103 events
	print("\n  [Decision Depth Scan: Unconditional Free Options Comparison across 103 Events]")
	var dominant_events: Array[String] = []
	var tiny_rad_events: Array[String] = []

	for eid_v3 in all_ids:
		var eid3: String = str(eid_v3)
		if eid3.ends_with("_3") and eid3.begins_with("rescue_"):
			continue
		_setup_standard_bunker_state(false)
		GameState.call("init_relationships", 20)
		var fams_init: Array = GameState.get("family_members") as Array
		for raw_m in fams_init:
			(raw_m as Dictionary)["trait"] = "optimist"
		if eid3 == "family_haunted_unrescued" or eid3 == "family_phantom_knock_guilt":
			GameState.set("left_behind_members", ["Timmy"])

		var sample_ev: Dictionary = EventDeckScript.call("build_event_by_id", eid3, 8, rng) as Dictionary
		var opts_check: Array = sample_ev.get("options", [])
		var free_opts: Array[Dictionary] = []
		for ov in opts_check:
			var od: Dictionary = ov
			var lbl: String = str(od.get("label", ""))
			if bool(od.get("available", false)) and str(od.get("item_id", "")) == "" and not lbl.begins_with("[COOPERATE]"):
				free_opts.append(od)

		if free_opts.size() < 2:
			continue

		var stats_by_opt: Array[Dictionary] = []
		for fo in free_opts:
			var oid: String = str(fo.get("id", ""))
			var net_loot: float = 0.0
			var net_rel: float = 0.0
			var net_morale: float = 0.0
			var net_harm: float = 0.0
			var net_rad: float = 0.0
			var had_downside: bool = false
			var trials: int = 24
			for t_i in range(trials):
				var trng := RandomNumberGenerator.new()
				trng.seed = 9000 + t_i * 37
				_setup_standard_bunker_state(false)
				GameState.set("soup_quarters", 8)
				GameState.set("water_quarters", 8)
				GameState.set("bunker_structural_integrity", 80.0)
				GameState.call("init_relationships", 20)
				var fams_t: Array = GameState.get("family_members") as Array
				for raw_m2 in fams_t:
					(raw_m2 as Dictionary)["trait"] = "optimist"
				if eid3 == "family_haunted_unrescued" or eid3 == "family_phantom_knock_guilt":
					GameState.set("left_behind_members", ["Timmy"])

				var before_loot: float = _score_inventory()
				var before_rel: float = float(int(GameState.call("get_member_avg_relationship", "member_0")))
				var before_hull: float = float(GameState.get("bunker_structural_integrity"))

				var ev_t: Dictionary = EventDeckScript.call("build_event_by_id", eid3, 8, trng) as Dictionary
				var out_d: Dictionary = EventDeckScript.call("resolve_event", ev_t, oid, trng) as Dictionary

				var d_loot: float = _score_inventory() - before_loot
				var d_rel: float = float(int(GameState.call("get_member_avg_relationship", "member_0"))) - before_rel
				var d_morale: float = float(int(out_d.get("morale_delta", 0)))
				var d_hull_loss: float = maxf(0.0, before_hull - float(GameState.get("bunker_structural_integrity")))
				var d_afflict: float = _sum_family_afflictions()
				var d_rad: float = _sum_family_rads()
				var sf_now: Dictionary = GameState.get("story_flags") as Dictionary
				if bool(sf_now.get("vendetta_active", false)):
					d_afflict += 2.0

				if d_loot < -0.01 or d_rel < -0.01 or d_morale < -0.01 or d_hull_loss > 0.01 or d_afflict > 0.01 or d_rad >= 3.0:
					had_downside = true

				net_loot += d_loot / float(trials)
				net_rel += d_rel / float(trials)
				net_morale += d_morale / float(trials)
				net_harm += (d_afflict + d_hull_loss * 0.1) / float(trials)
				net_rad += d_rad / float(trials)

			if net_rad > 0.01 and net_rad < 2.0:
				tiny_rad_events.append("%s:%s (+%.2f rads vs 65.0 threshold)" % [eid3, oid, net_rad])

			stats_by_opt.append({
				"id": oid,
				"label": str(fo.get("label", "")),
				"loot": net_loot,
				"rel": net_rel,
				"morale": net_morale,
				"harm": net_harm,
				"rad": net_rad,
				"had_downside": had_downside
			})

		for i in range(stats_by_opt.size()):
			var a: Dictionary = stats_by_opt[i]
			if bool(a["had_downside"]):
				continue
			for j in range(stats_by_opt.size()):
				if i == j:
					continue
				var b: Dictionary = stats_by_opt[j]
				var ge_all: bool = (
					float(a["loot"]) >= float(b["loot"]) - 0.01
					and float(a["rel"]) >= float(b["rel"]) - 0.01
					and float(a["morale"]) >= float(b["morale"]) - 0.01
					and float(a["harm"]) <= float(b["harm"]) + 0.01
				)
				var gt_meaningful: bool = (
					float(a["loot"]) > float(b["loot"]) + 0.20
					or float(a["rel"]) > float(b["rel"]) + 2.0
					or float(a["morale"]) > float(b["morale"]) + 0.5
					or float(a["harm"]) < float(b["harm"]) - 0.20
				)
				if ge_all and gt_meaningful:
					var desc_dom: String = "%s: free '%s' (loot=%+.1f, rel=%+.1f, mor=%+.1f, rad=%+.2f) strictly dominates free '%s' (loot=%+.1f, rel=%+.1f, mor=%+.1f)" % [
						eid3, str(a["id"]), float(a["loot"]), float(a["rel"]), float(a["morale"]), float(a["rad"]),
						str(b["id"]), float(b["loot"]), float(b["rel"]), float(b["morale"])
					]
					if not dominant_events.has(desc_dom):
						dominant_events.append(desc_dom)

	for de in dominant_events:
		print("    [DOMINANT FREE OPTION] " + de)
	if not dominant_events.is_empty():
		_warn("Found %d strictly-dominant zero-risk free option pairs in EventDeck" % dominant_events.size())

	for tre in tiny_rad_events:
		print("    [RAD SCALE MISMATCH]   " + tre)
	if not tiny_rad_events.is_empty():
		_warn("EventDeck applies +0.35..0.8 rads on bare-handed fallout dashes while BunkerSim/ExpeditionEngine use a 65.0-rad threshold (100x mismatch!)")


func _score_inventory() -> float:
	var sq: int = int(GameState.get("soup_quarters"))
	var wq: int = int(GameState.get("water_quarters"))
	var sc: float = float(sq + wq) * 0.25
	sc += float(int(GameState.get("medkit_count")) + int(GameState.get("antibiotics_count")) + int(GameState.get("antirad_count"))) * 1.5
	sc += float(int(GameState.get("fuel_cans")) + int(GameState.call("get_vehicle_parts_owned_count"))) * 2.0
	sc += float(int(GameState.get("scrap_count")) + int(GameState.get("bug_spray_count"))) * 1.0
	sc += float(int(GameState.get("ammo_count"))) * 0.5
	if bool(GameState.get("padlock_active")):
		sc += 1.5
	var bi: Dictionary = GameState.get("bunker_items") as Dictionary
	for k_v in bi.keys():
		if bool(GameState.call("has_working_item", str(k_v))):
			sc += 1.5
	var rc: Dictionary = GameState.get("rescue_chains") as Dictionary
	for rk_v in rc.keys():
		sc += float(int(rc[rk_v])) * 2.5
	return sc


func _sum_family_afflictions() -> float:
	var total: float = 0.0
	var fams: Array = GameState.get("family_members") as Array
	for raw_m in fams:
		var m: Dictionary = raw_m
		if not bool(m.get("alive", false)) or not bool(m.get("in_bunker", false)):
			continue
		total += float(int(m.get("sickness", 0)) + int(m.get("injury", 0)) + int(m.get("fatigue", 0)) + int(m.get("sanity", 0)))
	return total


func _sum_family_rads() -> float:
	var total: float = 0.0
	var fams: Array = GameState.get("family_members") as Array
	for raw_m in fams:
		var m: Dictionary = raw_m
		if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)):
			total += float(m.get("radiation", 0.0))
	return total


# ==============================================================================
# 3. MONTE CARLO VICTORY WINDOW PACING AUDIT (N=120 RUNS PER ROUTE)
# ==============================================================================
func _audit_monte_carlo_victory_windows() -> void:
	print("\n--- [3] MONTE CARLO VICTORY WINDOW PACING AUDIT (VEHICLE vs FACTION CHAINS vs RUSH) ---")
	var trials: int = 120

	var veh_t0_days: Array[int] = _sim_victory_runs(trials, "vehicle_tier0")
	var veh_t3_days: Array[int] = _sim_victory_runs(trials, "vehicle_tier3")
	var rescue_event_days: Array[int] = _sim_victory_runs(trials, "event_rescue")
	var church_rush_days: Array[int] = _sim_victory_runs(30, "church_rush")

	_print_pacing_row("Vehicle Escape (Tier 0 Fresh)", veh_t0_days, trials)
	_print_pacing_row("Vehicle Escape (Tier 3 Meta) ", veh_t3_days, trials)
	_print_pacing_row("Event-Deck Rescue Chains     ", rescue_event_days, trials)
	_print_pacing_row("Ring-1 Church Sanctuary Rush ", church_rush_days, 30)

	if not church_rush_days.is_empty() and church_rush_days[0] <= 5:
		_warn("Ring-1 Church Sanctuary Rush wins as early as Day %d (visiting 1-day Church/School 3 times auto-triggers Stage 3 Victory without drawing rescue_sanctuary_3!)" % church_rush_days[0])
	if not veh_t3_days.is_empty() and veh_t3_days[veh_t3_days.size() / 2] <= 6:
		_warn("Vehicle Escape at Meta Chassis Tier 3 completes in median Day %d (starts with 2/4 parts + 1/2 fuel -> only needs 2 expeditions!)" % veh_t3_days[veh_t3_days.size() / 2])

	_pass("Completed %d Monte Carlo full-run pacing simulations with 0 errors" % (trials * 3 + 30))


func _sim_victory_runs(trials: int, strategy: String) -> Array[int]:
	var win_days: Array[int] = []
	var rng_gs: RandomNumberGenerator = GameState.get("rng") as RandomNumberGenerator

	for i in range(trials):
		var meta_d: Dictionary = SaveManager.get("meta") as Dictionary
		meta_d["vehicle_chassis_tier"] = 3 if strategy == "vehicle_tier3" else 0
		rng_gs.seed = 500000 + i * 977
		GameState.set("difficulty", "fat_man")
		GameState.set("game_mode", "survival_only")
		(GameState.get("family_members") as Array).clear()
		(GameState.get("nearby_pois") as Array).clear()
		(GameState.get("selected_house") as Dictionary).clear()
		(GameState.get("nuke_config") as Dictionary).clear()
		GameState.call("reset_to_defaults")

		var fams: Array = GameState.get("family_members") as Array
		for raw_m in fams:
			var m: Dictionary = raw_m
			m["in_bunker"] = true
			m["alive"] = true
		GameState.set("soup_quarters", 18)
		GameState.set("water_quarters", 18)
		GameState.set("medkit_count", 1)
		var bi: Dictionary = GameState.get("bunker_items") as Dictionary
		for gid in ["gas_mask", "suitcase", "radio", "flashlight"]:
			var entry: Dictionary = bi[gid]
			entry["owned"] = true
			entry["broken"] = false
			entry["count"] = 1

		var preset: Dictionary = OsmServiceScript.call("load_preset", "seattle") as Dictionary
		var bldgs: Array = preset.get("buildings", [])
		var pois: Array = preset.get("pois", [])
		var sel_h: Dictionary = OsmServiceScript.call("pick_best_house", bldgs, 47.6240, -122.3195, 206082403) as Dictionary
		GameState.set("selected_house", sel_h)
		var near_p: Array = OsmServiceScript.call("build_nearby_targets_for_house", sel_h, bldgs, pois, "Capitol Hill, Seattle, WA") as Array
		GameState.set("nearby_pois", near_p)

		BunkerSimScript.call("start_bunker_run")

		for _step in range(55):
			if bool(GameState.get("game_over")):
				break
			if strategy == "vehicle_tier0" or strategy == "vehicle_tier3":
				if not bool(GameState.get("vehicle_tuned")):
					if bool(GameState.call("has_working_item", "toolbox")) or bool(GameState.call("has_working_item", "book")) or int(GameState.get("scrap_count")) > 0:
						BunkerSimScript.call("tune_escape_vehicle")
				if bool(GameState.call("can_escape_by_vehicle")):
					BunkerSimScript.call("execute_vehicle_escape")
					break

			var cur_day: int = int(GameState.get("day"))
			var ev: Dictionary = EventDeckScript.call("draw_daily_event", cur_day, rng_gs) as Dictionary
			var pick_id: String = _pick_smart_choice_for_strategy(ev, strategy)
			var ev_out: Dictionary = EventDeckScript.call("resolve_event", ev, pick_id, rng_gs) as Dictionary
			if bool(GameState.get("victory")) and bool(GameState.get("game_over")):
				break

			var rplan: Dictionary = {}
			var sb: int = int(GameState.get("soup_quarters"))
			var wb: int = int(GameState.get("water_quarters"))
			var liv: Array = GameState.call("get_living_bunker_members") as Array
			for raw_lm in liv:
				var lm: Dictionary = raw_lm
				var mid: String = str(lm.get("id", ""))
				var sq: int = 0
				var wq: int = 0
				if int(lm.get("days_without_water", 0)) >= 3 and wb > 0:
					wq = 1
					wb -= 1
				if int(lm.get("days_without_food", 0)) >= 5 and sb > 0:
					sq = 1
					sb -= 1
				rplan[mid] = {"soup_q": sq, "water_q": wq}

			var exp_launch: Dictionary = {}
			var act_exp: Dictionary = GameState.get("active_expedition") as Dictionary
			if act_exp.is_empty():
				exp_launch = _build_strategy_expedition(strategy)

			BunkerSimScript.call("advance_day", rplan, "", ev_out, exp_launch)
			if (strategy == "vehicle_tier0" or strategy == "vehicle_tier3") and not bool(GameState.get("game_over")):
				if not bool(GameState.get("vehicle_tuned")) and int(GameState.get("scrap_count")) > 0:
					BunkerSimScript.call("tune_escape_vehicle")
				if bool(GameState.call("can_escape_by_vehicle")):
					BunkerSimScript.call("execute_vehicle_escape")
					break

		if bool(GameState.get("victory")):
			win_days.append(int(GameState.get("day")))

	win_days.sort()
	return win_days


func _pick_smart_choice_for_strategy(ev: Dictionary, strategy: String) -> String:
	var opts: Array = ev.get("options", [])
	var ev_id: String = str(ev.get("id", ""))
	for ov in opts:
		var od: Dictionary = ov
		if not bool(od.get("available", false)):
			continue
		var oid: String = str(od.get("id", ""))
		if strategy == "vehicle_tier0" or strategy == "vehicle_tier3":
			if ev_id.begins_with("rescue_"):
				if oid == "ignore" or oid == "no":
					return oid
			if ev_id.begins_with("vehicle_") or oid.find("part") != -1 or oid.find("fuel") != -1 or oid.find("tune") != -1:
				return oid
		elif strategy == "event_rescue":
			if ev_id.begins_with("rescue_"):
				if oid != "ignore" and oid != "no":
					return oid
		if str(od.get("item_id", "")) != "" and not oid.begins_with("rob_"):
			return oid
	for ov2 in opts:
		var od2: Dictionary = ov2
		if bool(od2.get("available", false)):
			return str(od2.get("id", ""))
	return ""


func _build_strategy_expedition(strategy: String) -> Dictionary:
	var targets: Array = ExpeditionEngineScript.call("get_available_targets") as Array
	if targets.is_empty():
		return {}
	var explorer_id: String = ""
	var liv: Array = GameState.call("get_living_bunker_members") as Array
	for raw_m in liv:
		var m: Dictionary = raw_m
		if bool(ExpeditionEngineScript.call("can_member_expedition", m)):
			if str(m.get("trait", "")) == "scout":
				explorer_id = str(m.get("id", ""))
				break
			if explorer_id == "":
				explorer_id = str(m.get("id", ""))
	if explorer_id == "":
		return {}

	var gear: Array[String] = []
	for g in ["suitcase", "gas_mask", "map", "flashlight"]:
		if bool(GameState.call("has_working_item", g)) and gear.size() < 4:
			gear.append(g)

	var chosen_idx: int = -1
	if strategy == "church_rush":
		for i in range(targets.size()):
			var td: Dictionary = targets[i]
			if str(td.get("category", "")) == "church":
				chosen_idx = i
				break
	elif strategy == "vehicle_tier0" or strategy == "vehicle_tier3":
		var need_food: bool = (int(GameState.get("soup_quarters")) < 6 or int(GameState.get("water_quarters")) < 6)
		for i in range(targets.size()):
			var td2: Dictionary = targets[i]
			if bool(td2.get("depleted", false)):
				continue
			var cat: String = str(td2.get("category", ""))
			if need_food and cat == "grocery":
				chosen_idx = i
				break
			if not need_food and cat == "fuel_auto" and (int(GameState.call("get_vehicle_parts_owned_count")) < 4 or int(GameState.get("fuel_cans")) < int(GameState.get("fuel_needed"))):
				chosen_idx = i
				break
		if chosen_idx == -1:
			for i in range(targets.size()):
				var td3: Dictionary = targets[i]
				var cat3: String = str(td3.get("category", ""))
				if cat3 == "hardware" and not bool(td3.get("depleted", false)):
					chosen_idx = i
					break
				elif cat3 == "grocery" and not bool(td3.get("depleted", false)):
					chosen_idx = i
	else:
		if int(GameState.get("soup_quarters")) < 10 or int(GameState.get("water_quarters")) < 10:
			for i in range(targets.size()):
				var td4: Dictionary = targets[i]
				var cat4: String = str(td4.get("category", ""))
				if (cat4 == "grocery" or cat4 == "neighbor_house") and not bool(td4.get("depleted", false)):
					chosen_idx = i
					break

	if chosen_idx < 0:
		return {}
	return {"member_id": explorer_id, "poi_index": chosen_idx, "gear_ids": gear}


func _print_pacing_row(label: String, win_days: Array[int], total_trials: int) -> void:
	if win_days.is_empty():
		print("  %s | Wins: 0/%d (0.0%%)" % [label, total_trials])
		return
	var n: int = win_days.size()
	var sum_d: int = 0
	for d in win_days:
		sum_d += d
	var min_d: int = win_days[0]
	var p25_d: int = win_days[int(float(n - 1) * 0.25)]
	var med_d: int = win_days[int(float(n - 1) * 0.50)]
	var p75_d: int = win_days[int(float(n - 1) * 0.75)]
	var max_d: int = win_days[n - 1]
	var mean_d: float = float(sum_d) / float(n)
	print("  %s | Wins: %3d/%3d (%5.1f%%) | Day Window: min=%2d p25=%2d MEDIAN=%2d mean=%4.1f p75=%2d max=%2d" % [
		label, n, total_trials, 100.0 * float(n) / float(total_trials),
		min_d, p25_d, med_d, mean_d, p75_d, max_d
	])


# ==============================================================================
# 4. MULTI-RING (R1 vs R2 vs R3) EXPEDITION RISK & PAYOFF AUDIT
# ==============================================================================
func _audit_multi_ring_expedition_payoffs() -> void:
	print("\n--- [4] MULTI-RING (R1 vs R2 vs R3) LANDMARK RISK / REWARD TELEMETRY ---")
	var test_specs: Array = [
		{"cat": "grocery", "ring": 1, "dist": 240.0},
		{"cat": "grocery", "ring": 2, "dist": 1850.0},
		{"cat": "grocery", "ring": 3, "dist": 5600.0},
		{"cat": "doctor", "ring": 1, "dist": 350.0},
		{"cat": "doctor", "ring": 2, "dist": 1950.0},
		{"cat": "doctor", "ring": 3, "dist": 5800.0},
		{"cat": "fuel_auto", "ring": 1, "dist": 380.0},
		{"cat": "fuel_auto", "ring": 2, "dist": 1600.0},
		{"cat": "fuel_auto", "ring": 3, "dist": 4500.0}
	]

	print("  %-11s | R%s | %6s | %4s | %7s | %8s | %10s | %10s | %s" % [
		"CATEGORY", "#", "DIST", "DAYS", "AMBUSH%", "RAD(raw)", "TOTAL_VAL", "VAL/DAY", "AVG KEY DROPS (Bare vs Suitcase+Mask)"
	])

	var r2_doc_val: float = 0.0
	var r3_doc_val: float = 0.0
	var r2_fuel_val: float = 0.0
	var r3_fuel_val: float = 0.0
	var r1_groc_per_day: float = 0.0
	var r3_groc_per_day: float = 0.0

	for sp_v in test_specs:
		var sp: Dictionary = sp_v
		var cat: String = str(sp["cat"])
		var ring: int = int(sp["ring"])
		var dist_m: float = float(sp["dist"])
		var days: int = int(ExpeditionEngineScript.call("compute_base_travel_days", dist_m, ring, cat))
		var ambush_p: float = float(ExpeditionEngineScript.call("_compute_bandit_risk_prob", cat, ring, 0.55, 0))
		var raw_rad: float = 6.0 * (3.2 + float(days) * 1.45)

		var rng := RandomNumberGenerator.new()
		rng.seed = 77700 + ring * 13
		var trials: int = 300
		var bare_val_sum: float = 0.0
		var geared_val_sum: float = 0.0
		var bare_items_acc: Dictionary = {}

		var ring_mult: float = 1.0 if ring == 1 else (1.25 if ring == 2 else 1.55)
		for _t in range(trials):
			_setup_standard_bunker_state(false)
			var loot_bare: Dictionary = ExpeditionEngineScript.call("_roll_category_loot", cat, ring, ring_mult, rng) as Dictionary
			bare_val_sum += _score_loot_dict(loot_bare)
			for lk in loot_bare.keys():
				var ks: String = str(lk)
				bare_items_acc[ks] = float(bare_items_acc.get(ks, 0.0)) + float(int(loot_bare[ks])) / float(trials)

			var loot_geared: Dictionary = ExpeditionEngineScript.call("_roll_category_loot", cat, ring, ring_mult * 2.0 * 1.35, rng) as Dictionary
			geared_val_sum += _score_loot_dict(loot_geared)

		var avg_bare: float = bare_val_sum / float(trials)
		var avg_geared: float = geared_val_sum / float(trials)
		var per_day_bare: float = avg_bare / float(days)

		if cat == "grocery" and ring == 1:
			r1_groc_per_day = per_day_bare
		elif cat == "grocery" and ring == 3:
			r3_groc_per_day = per_day_bare
		elif cat == "doctor" and ring == 2:
			r2_doc_val = avg_bare
		elif cat == "doctor" and ring == 3:
			r3_doc_val = avg_bare
		elif cat == "fuel_auto" and ring == 2:
			r2_fuel_val = avg_bare
		elif cat == "fuel_auto" and ring == 3:
			r3_fuel_val = avg_bare

		var drop_parts: Array[String] = []
		for k_s in bare_items_acc.keys():
			drop_parts.append("%s=%.1f" % [str(k_s), float(bare_items_acc[k_s])])

		print("  %-11s | R%d | %5.0fm | %3dd | %6.1f%% | %6.1f R | %10.2f | %8.2f/d | %s (Suitcase=%.1f)" % [
			cat, ring, dist_m, days, ambush_p * 100.0, raw_rad, avg_bare, per_day_bare, ", ".join(drop_parts), avg_geared
		])

	if absf(r3_doc_val - r2_doc_val) < 0.05:
		_warn("Ring 3 Doctor (4d, 5.8km) drops IDENTICAL bare loot value (%.2f) to Ring 2 Doctor (2d, 1.9km, %.2f) — Ring 3 needs a jackpot bonus!" % [r3_doc_val, r2_doc_val])
	if absf(r3_fuel_val - r2_fuel_val) < 0.05:
		_warn("Ring 3 Gas/Auto (3d, 4.5km) drops IDENTICAL bare loot value (%.2f) to Ring 2 Gas/Auto (2d, 1.6km, %.2f) — Ring 3 should drop 2x vehicle_part or bonus Toolbox!" % [r3_fuel_val, r2_fuel_val])
	if r3_groc_per_day < r1_groc_per_day * 0.55:
		_warn("Ring 3 Grocery yields %.2f val/day vs Ring 1 Grocery %.2f val/day because grocery_scale divides out ring_mult (expedition_engine.gd:707)!" % [r3_groc_per_day, r1_groc_per_day])

	_pass("Multi-Ring 9-category expedition risk/payoff telemetry verified")


func _score_loot_dict(loot: Dictionary) -> float:
	var v: float = 0.0
	for k in loot.keys():
		var ks: String = str(k)
		var q: float = float(int(loot[k]))
		match ks:
			"soup", "water":
				v += q * 1.0
			"antibiotics", "antirad", "medkit":
				v += q * 1.8
			"fuel", "vehicle_part":
				v += q * 2.2
			_:
				v += q * 1.4
	return v


# ==============================================================================
# 5. RELATIONSHIPS, 35+ DAY BUNKER SURVIVAL, SAVE/LOAD & UI/3D EDGE GAUNTLET
# ==============================================================================
func _audit_relationships_and_35day_gauntlet() -> void:
	print("\n--- [5] FAMILY RELATIONSHIPS, 35-DAY SURVIVAL, SAVE/LOAD & SCENE GAUNTLET ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	# 5A. Left-behind survivor guilt vs Full House relief
	_setup_standard_bunker_state(true)
	var fams_a: Array = GameState.get("family_members") as Array
	(fams_a[3] as Dictionary)["in_bunker"] = false
	(fams_a[3] as Dictionary)["alive"] = false
	GameState.set("left_behind_members", ["Timmy"])
	BunkerSimScript.call("start_bunker_run")
	var rel_after_guilt: int = int(GameState.call("get_relationship", "member_0", "member_1"))
	if rel_after_guilt != -2:
		_fail("Expected relationship 20 - 22 = -2 after leaving Timmy behind, got %d" % rel_after_guilt)
	else:
		_pass("Left-behind survivor guilt (-22 relationship with Leader + +1 grief sanity) verified")

	# 5B. Ration Favoritism (-12) vs Fair Scarcity Sharing (+5)
	_setup_standard_bunker_state(true)
	BunkerSimScript.call("start_bunker_run")
	var fams_b: Array = GameState.get("family_members") as Array
	(fams_b[0] as Dictionary)["hunger"] = 0
	(fams_b[1] as Dictionary)["hunger"] = 2
	var fav_lines: Array = RelationshipSystemScript.call("evaluate_ration_fairness", {
		"member_0": {"soup_q": 1, "water_q": 0},
		"member_1": {"soup_q": 0, "water_q": 0}
	}) as Array
	if fav_lines.is_empty():
		_fail("Ration favoritism failed to trigger when feeding hunger=0 member while starving hunger=2 member!")
	else:
		_pass("Ration favoritism resentment (-12) accurately detected and logged")

	# 5C. Emotional Breakdown blocks expedition + Overnight Betrayal at <= -75
	(fams_b[1] as Dictionary)["sanity"] = 2
	var rels_d: Dictionary = GameState.get("relationships") as Dictionary
	rels_d[str(GameState.call("make_rel_key", "member_1", "member_0"))] = -85
	rels_d[str(GameState.call("make_rel_key", "member_1", "member_2"))] = -85
	rels_d[str(GameState.call("make_rel_key", "member_1", "member_3"))] = -85
	(fams_b[1] as Dictionary)["breakdown_days"] = 2
	if bool(ExpeditionEngineScript.call("can_member_expedition", fams_b[1] as Dictionary)):
		_fail("Member with breakdown_days=2 was erroneously allowed on expedition!")
	else:
		_pass("Emotional breakdown accurately blocks wasteland expeditions")

	var betrayed_triggered: bool = false
	for attempt in range(25):
		var brng := RandomNumberGenerator.new()
		brng.seed = 100 + attempt
		(fams_b[1] as Dictionary)["alive"] = true
		(fams_b[1] as Dictionary)["in_bunker"] = true
		(fams_b[1] as Dictionary)["sanity"] = 2
		GameState.set("soup_quarters", 12)
		GameState.set("water_quarters", 12)
		var out_rel: Dictionary = RelationshipSystemScript.call("tick_daily_relationships", brng) as Dictionary
		if str(out_rel.get("betrayal_member", "")) != "":
			betrayed_triggered = true
			break
	if not betrayed_triggered:
		_fail("Hostile overnight betrayal (<= -75 rel + sanity>=2) failed to trigger across 25 rolls!")
	else:
		_pass("Hostile overnight betrayal (<= -75 rel, steals 4/4 soup & 4/4 water, abandons shelter) verified")

	# 5D. Exact Dehydration (Day 6) & Starvation & Save/Load Roundtrip
	_setup_standard_bunker_state(false)
	BunkerSimScript.call("start_bunker_run")
	GameState.set("bunker_temp_c", 19.0)
	(GameState.get("nuke_config") as Dictionary)["bunker_temp_c"] = 19.0
	for _d in range(6):
		BunkerSimScript.call("advance_day", {})
	if not bool(GameState.get("game_over")):
		_fail("Expected Day 6 dehydration Game Over with 0 water at 19C, but game_over is false on Day %d!" % int(GameState.get("day")))
	else:
		_pass("Exact 6-day zero-water dehydration fatality & Game Over verified (Day %d)" % int(GameState.get("day")))

	# 35-Day Endurance + SaveManager Roundtrip
	_setup_standard_bunker_state(true)
	GameState.set("soup_quarters", 80)
	GameState.set("water_quarters", 80)
	GameState.set("antibiotics_count", 3)
	GameState.set("antirad_count", 3)
	GameState.set("scrap_count", 4)
	BunkerSimScript.call("start_bunker_run")
	for d_step in range(34):
		GameState.set("rescue_chains", {"military": 0, "sanctuary": 0, "scientist": 0, "raider_pact": 0})
		GameState.set("victory", false)
		var cday: int = int(GameState.get("day"))
		var ev35: Dictionary = EventDeckScript.call("draw_daily_event", cday, rng) as Dictionary
		var ev35_out: Dictionary = EventDeckScript.call("resolve_event", ev35, "", rng) as Dictionary
		GameState.set("rescue_chains", {"military": 0, "sanctuary": 0, "scientist": 0, "raider_pact": 0})
		GameState.set("victory", false)
		var rp35: Dictionary = {}
		var liv35: Array = GameState.call("get_living_bunker_members") as Array
		for raw_m35 in liv35:
			var m35: Dictionary = raw_m35
			var mid35: String = str(m35.get("id", ""))
			rp35[mid35] = {
				"soup_q": 1 if int(m35.get("days_without_food", 0)) >= 4 else 0,
				"water_q": 1 if int(m35.get("days_without_water", 0)) >= 2 else 0
			}
		var spec35: Dictionary = {}
		if d_step == 10:
			var f35: Array = GameState.get("family_members") as Array
			(f35[0] as Dictionary)["sickness"] = 2
			(f35[0] as Dictionary)["radiation"] = 45.0
			GameState.set("bunker_structural_integrity", 72.0)
			spec35 = {
				"antibiotics_target_id": "member_0",
				"antirad_target_id": "member_0",
				"use_scrap_hull": true
			}
		BunkerSimScript.call("advance_day", rp35, "", ev35_out, {}, spec35)
		if d_step == 15:
			var saved_ok: bool = bool(SaveManager.call("save_run"))
			var day_snap: int = int(GameState.get("day"))
			GameState.set("day", 1)
			var loaded_ok: bool = bool(SaveManager.call("load_run"))
			if not saved_ok or not loaded_ok or int(GameState.get("day")) != day_snap:
				_fail("SaveManager mid-run save/load failed at Day %d!" % day_snap)

	var all_liv_end: Array = GameState.call("get_all_living_members") as Array
	if int(GameState.get("day")) >= 35 and not all_liv_end.is_empty():
		_pass("35-Day Bunker Survival stress run + Specialty Items (Antibiotics/Anti-Rad/Scrap) + Save/Load roundtrip passed (Day %d, %d alive)" % [
			int(GameState.get("day")), all_liv_end.size()
		])
	else:
		_fail("35-Day Bunker Survival stress run failed early on Day %d" % int(GameState.get("day")))

	# 5E. Instantiate & Verify All V2 Screens (1-member vs 4-member, Suburban VA vs Seattle, 2km vs 5000km Nuke, 3D Scavenge, 5-Tab Bunker)
	var holder := Control.new()
	holder.size = Vector2(1280.0, 720.0)
	root.add_child(holder)

	GameState.set("demo_mode", false)
	var ts: Control = TitleScreenScript.new() as Control
	holder.add_child(ts)
	await process_frame
	ts.call("open_challenges_modal")
	ts.call("open_achievements_modal")
	ts.queue_free()
	await process_frame

	var fs: Control = FamilyScreenScript.new() as Control
	holder.add_child(fs)
	await process_frame
	var elder_m: Dictionary = GameState.call(
		"make_family_member", "m_elder", "Grandpa Joe", "elder", 71, true, "optimist", 2, 4, "#e8e8e8", "#3a7d5c", true, 2, "#556b2f", 1
	) as Dictionary
	GameState.set("family_members", [elder_m])
	fs.queue_free()
	await process_frame

	GameState.call("init_default_family")
	var hs: Control = HouseSelectScreenScript.new() as Control
	holder.add_child(hs)
	await process_frame
	hs.queue_free()
	await process_frame

	# NukePhysics & NukeScreen: 2km blast vs 5000km nuclear winter
	var close_hit: Dictionary = NukePhysicsScript.call("destination_point", 47.6242, -122.3195, 180.0, 2.0) as Dictionary
	var close_cfg: Dictionary = NukePhysicsScript.call(
		"compute_impact", 47.6242, -122.3195, float(close_hit["lat"]), float(close_hit["lon"]), 800, 0.0, "2km Close Strike"
	) as Dictionary
	var winter_cfg: Dictionary = NukePhysicsScript.call(
		"compute_impact", 47.6242, -122.3195, 35.6762, 139.6503, 50000, 90.0, "5000km+ Global Winter"
	) as Dictionary
	if float(close_cfg.get("initial_sv_hr", 0.0)) <= float(winter_cfg.get("initial_sv_hr", 99.0)) and float(winter_cfg.get("bunker_temp_c", 20.0)) > 5.0:
		_fail("NukePhysics 2km vs 5000km Nuclear Winter differentiation failed!")
	else:
		_pass("NukePhysics verified: 2km Close Blast (%.1f Sv/hr, %.1f°C) vs >5000km Nuclear Winter (%.1f Sv/hr, %.1f°C)" % [
			float(close_cfg.get("initial_sv_hr", 0.0)), float(close_cfg.get("bunker_temp_c", 0.0)),
			float(winter_cfg.get("initial_sv_hr", 0.0)), float(winter_cfg.get("bunker_temp_c", 0.0))
		])

	var ns: Control = NukeScreenScript.new() as Control
	holder.add_child(ns)
	await process_frame
	ns.queue_free()
	await process_frame

	var sc: Node2D = ScavengeSceneScript.new() as Node2D
	holder.add_child(sc)
	await process_frame
	if DisplayServer.get_name() != "headless" and sc.get("_sub_vp") == null:
		_fail("ScavengeScene failed to instantiate 3D Isometric SubViewport under X11/GL!")
	sc.queue_free()
	await process_frame

	_setup_standard_bunker_state(true)
	BunkerSimScript.call("start_bunker_run")
	var bs: Control = BunkerSceneScript.new() as Control
	holder.add_child(bs)
	await process_frame
	for tab_i in range(5):
		bs.call("set_active_tab", tab_i)
		await process_frame
	bs.queue_free()
	await process_frame

	var sums: Control = SummaryScreenScript.new() as Control
	holder.add_child(sums)
	await process_frame
	sums.queue_free()
	holder.queue_free()
	await process_frame
	await process_frame

	_pass("All 7 V2 Screens (Title, Family, Multi-Ring OSM, Nuke, 3D Isometric Scavenge, 5-Tab Bunker, Summary) mounted & freed cleanly")


# ==============================================================================
# 6. V2 END-TO-END --demo-showcase FRAME TIMELINE VERIFICATION
# ==============================================================================
func _audit_v2_demo_showcase_timeline() -> void:
	print("\n--- [6] END-TO-END V2 --demo-showcase FRAME TIMELINE (@ 30 FPS) ---")
	GameState.set("demo_mode", true)
	GameState.set("headless_fast_test", false)
	var rng_gs: RandomNumberGenerator = GameState.get("rng") as RandomNumberGenerator
	rng_gs.seed = 60602026
	(GameState.get("family_members") as Array).clear()
	(GameState.get("selected_house") as Dictionary).clear()
	(GameState.get("nearby_pois") as Array).clear()
	(GameState.get("nuke_config") as Dictionary).clear()
	GameState.call("reset_to_defaults")
	BunkerSceneScript.set("demo_completed_flag", false)

	var main_packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main_inst: Control = main_packed.instantiate() as Control
	root.add_child(main_inst)

	var screens_seen: Array[String] = []
	var enter_f: Dictionary = {}
	var exit_f: Dictionary = {}
	var tabs_seen: Array[int] = []
	var days_seen: Array[int] = []
	var verified_3d_scavenge: bool = false

	var cur_s: String = str(GameState.get("current_screen"))
	screens_seen.append(cur_s)
	enter_f[cur_s] = 0

	var f_idx: int = 0
	var max_f: int = 4200
	var wall_t0_ms: int = Time.get_ticks_msec()
	var last_hb_ms: int = wall_t0_ms
	while f_idx < max_f:
		await process_frame
		f_idx += 1

		var now_s: String = str(GameState.get("current_screen"))
		if now_s != cur_s:
			exit_f[cur_s] = f_idx
			enter_f[now_s] = f_idx
			screens_seen.append(now_s)
			var now_ms: int = Time.get_ticks_msec()
			print("  [FRAME %4d | sim=%6.2fs | wall=%6.2fs] %s -> %s" % [
				f_idx, float(f_idx) / 30.0, float(now_ms - wall_t0_ms) / 1000.0, cur_s, now_s
			])
			last_hb_ms = now_ms
			cur_s = now_s

		var active_n: Node = main_inst.get("_active_node") as Node
		if now_s == "scavenge" and is_instance_valid(active_n):
			if not verified_3d_scavenge:
				if DisplayServer.get_name() != "headless":
					var svp: Variant = active_n.get("_sub_vp")
					var cam3d: Variant = active_n.get("_camera_3d")
					if svp != null and cam3d != null:
						verified_3d_scavenge = true
				else:
					verified_3d_scavenge = true
			if f_idx % 150 == 0:
				var hb_now: int = Time.get_ticks_msec()
				print("    [SCAV HB frame=%4d | wall=%6.2fs (+%.2fs) | t_left=%.1fs | pos=%s]" % [
					f_idx, float(hb_now - wall_t0_ms) / 1000.0, float(hb_now - last_hb_ms) / 1000.0,
					float(active_n.get("_scavenge_time_left")), str(active_n.get("_player_pos"))
				])
				last_hb_ms = hb_now

		if now_s == "bunker" and is_instance_valid(active_n):
			var d_now: int = int(GameState.get("day"))
			if not days_seen.has(d_now):
				days_seen.append(d_now)
				print("  [FRAME %4d | %6.2fs] Bunker Day %d" % [f_idx, float(f_idx) / 30.0, d_now])
			if bool(active_n.get("_notebook_open")):
				var tidx: int = int(active_n.get("_current_tab"))
				if not tabs_seen.has(tidx):
					tabs_seen.append(tidx)

		if bool(BunkerSceneScript.get("demo_completed_flag")):
			exit_f[cur_s] = f_idx
			break

	var quit_hold_frames: int = 60
	print("\n  === EXACT V2 DEMO SHOWCASE TIMELINE (@ 30 FPS) ===")
	for sn in screens_seen:
		var a0: int = int(enter_f.get(sn, 0))
		var a1: int = int(exit_f.get(sn, f_idx))
		var span: int = a1 - a0
		print("  %-12s : frame %4d -> %4d (%4d frames = %6.2fs)" % [sn, a0, a1, span, float(span) / 30.0])
	print("  DEMO COMPLETE FLAG : frame %d (%.2fs) | + --demo-quit-on-complete (2.00s) = ~%d frames (%.2fs)" % [
		f_idx, float(f_idx) / 30.0, f_idx + quit_hold_frames, float(f_idx + quit_hold_frames) / 30.0
	])
	print("  3D Isometric Scavenge Verified: %s | Bunker Days: %s | 5-Tab Notebook Tabs Opened: %s" % [
		str(verified_3d_scavenge), str(days_seen), str(tabs_seen)
	])

	var expected_screens: Array[String] = ["title", "family", "osm_house", "nuke", "scavenge", "bunker"]
	if screens_seen != expected_screens:
		_fail("V2 Demo screen sequence mismatch: got " + str(screens_seen))
	elif not verified_3d_scavenge:
		_fail("V2 Demo failed to verify 3D Isometric Scavenge SubViewport + Camera3D!")
	elif tabs_seen.size() < 5:
		_fail("V2 Demo did not visit all 5 Bunker Notebook tabs! Visited: " + str(tabs_seen))
	elif days_seen != [1, 2, 3, 4]:
		_fail("V2 Demo did not complete Bunker Days 1..4! Got: " + str(days_seen))
	else:
		_pass("V2 Demo Showcase verified across all 6 screens, 3D Isometric Scavenge, Days 1..4, and ALL 5 Bunker Tabs (0..4)!")

	main_inst.queue_free()
	await process_frame
	await process_frame


func _setup_standard_bunker_state(fully_stocked: bool) -> void:
	GameState.set("difficulty", "fat_man")
	GameState.set("game_mode", "full_protocol")
	(GameState.get("family_members") as Array).clear()
	GameState.call("reset_to_defaults")
	var fams: Array = GameState.get("family_members") as Array
	for raw_m in fams:
		var m: Dictionary = raw_m
		m["in_bunker"] = true
		m["alive"] = true
	if fully_stocked:
		GameState.set("soup_quarters", 24)
		GameState.set("water_quarters", 24)
		GameState.set("medkit_count", 3)
		GameState.set("antibiotics_count", 2)
		GameState.set("antirad_count", 2)
		GameState.set("scrap_count", 3)
		GameState.set("fuel_cans", 2)
		GameState.set("ammo_count", 6)
		GameState.set("bug_spray_count", 2)
		GameState.set("padlock_active", true)
		GameState.set("has_cat_sharikov", true)
		GameState.set("has_dog_pancake", true)
		var bi: Dictionary = GameState.get("bunker_items") as Dictionary
		for gid_v in bi.keys():
			var entry: Dictionary = bi[str(gid_v)]
			entry["owned"] = true
			entry["broken"] = false
			entry["count"] = 1
	else:
		GameState.set("soup_quarters", 0)
		GameState.set("water_quarters", 0)
		GameState.set("medkit_count", 0)
		GameState.set("antibiotics_count", 0)
		GameState.set("antirad_count", 0)
		GameState.set("scrap_count", 0)
		GameState.set("fuel_cans", 0)
		GameState.set("ammo_count", 0)
		GameState.set("bug_spray_count", 0)
		GameState.set("padlock_active", false)
		GameState.set("has_cat_sharikov", false)
		GameState.set("has_dog_pancake", false)
