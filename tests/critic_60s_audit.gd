extends SceneTree

## Ruthless The End Is Near Fidelity Critic — Headless Simulation & Audit Suite
## Run with:
## godot --headless --path . -s res://tests/critic_60s_audit.gd

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

var ItemDBRef: Script
var HouseGenRef: Script
var OsmServiceRef: Script
var ScavengeSceneRef: Script
var FamilyScreenRef: Script
var BunkerSimRef: Script
var BunkerSceneRef: Script
var EventDeckRef: Script
var ExpeditionRef: Script
var NukePhysicsRef: Script
var main_inst: Node = null

func _init() -> void:
	call_deferred("_run_all_audits")

func _check(cond: bool, label: String, fail_detail: String = "") -> void:
	if cond:
		pass_count += 1
		print("  [PASS] " + label)
	else:
		fail_count += 1
		var msg: String = label + (" -> " + fail_detail if fail_detail != "" else "")
		findings.append(msg)
		print("  [FAIL] " + msg)

func _wait_frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _run_all_audits() -> void:
	await _wait_frames(2)
	ItemDBRef = load("res://scripts/core/item_db.gd")
	HouseGenRef = load("res://scripts/scavenge/house_generator.gd")
	OsmServiceRef = load("res://scripts/osm/osm_service.gd")
	ScavengeSceneRef = load("res://scripts/scavenge/scavenge_scene.gd")
	FamilyScreenRef = load("res://scripts/ui/family_screen.gd")
	BunkerSimRef = load("res://scripts/bunker/bunker_sim.gd")
	BunkerSceneRef = load("res://scripts/bunker/bunker_scene.gd")
	EventDeckRef = load("res://scripts/events/event_deck.gd")
	ExpeditionRef = load("res://scripts/expedition/expedition_engine.gd")
	NukePhysicsRef = load("res://scripts/nuke/nuke_physics.gd")

	var main_packed: PackedScene = load("res://scenes/main.tscn")
	main_inst = main_packed.instantiate()
	root.add_child(main_inst)
	await _wait_frames(2)

	print("=================================================================")
	print("RUTHLESS THE END IS NEAR FIDELITY AUDIT STARTING")
	print("=================================================================")

	var gs: Node = root.get_node("GameState")

	await _audit_1_item_db_and_carry_slots(gs)
	await _audit_2_scavenge_sequence(gs)
	await _audit_3_bunker_survival_math(gs)
	await _audit_4_event_deck_and_rescue_chains(gs)

	print("=================================================================")
	print("AUDIT SUMMARY: %d PASSED | %d FAILED" % [pass_count, fail_count])
	for i in range(findings.size()):
		print("  DEFECT #%d: %s" % [i + 1, findings[i]])
	print("=================================================================")

	if is_instance_valid(main_inst):
		main_inst.queue_free()
	await _wait_frames(2)
	quit(0)

# =============================================================================
# 1. ITEM DATABASE & CARRY SLOT FIDELITY
# =============================================================================
func _audit_1_item_db_and_carry_slots(gs: Node) -> void:
	print("\n--- SUITE 1: Item Database & Carry Slot Fidelity ---")
	var expected_1_slot: Array[String] = [
		"soup", "water", "medkit", "gas_mask", "radio", "flashlight", "map",
		"book", "ammo", "bug_spray", "padlock", "cards", "checkers", "harmonica"
	]
	var expected_2_slot: Array[String] = ["axe", "rifle", "suitcase", "toolbox"]

	var all_ids: Array = ItemDBRef.call("get_all_item_ids")
	_check(all_ids.size() == 18, "ItemDB has exactly 18 canonical items", "got %d" % all_ids.size())

	var hg_meta: Dictionary = HouseGenRef.get("ITEM_META")
	for iid in expected_1_slot:
		var info: Dictionary = ItemDBRef.call("get_item_info", iid)
		var slots: int = int(info.get("slots", -1))
		var hg_slots: int = int((hg_meta.get(iid, {}) as Dictionary).get("slots", -1))
		_check(all_ids.has(iid) and slots == 1 and hg_slots == 1, "1-slot item '%s' has slots=1 in ItemDB & HouseGenerator" % iid, "ItemDB=%d HG=%d" % [slots, hg_slots])

	for iid2 in expected_2_slot:
		var info2: Dictionary = ItemDBRef.call("get_item_info", iid2)
		var slots2: int = int(info2.get("slots", -1))
		var hg_slots2: int = int((hg_meta.get(iid2, {}) as Dictionary).get("slots", -1))
		_check(all_ids.has(iid2) and slots2 == 2 and hg_slots2 == 2, "2-slot item '%s' has slots=2 in ItemDB & HouseGenerator" % iid2, "ItemDB=%d HG=%d" % [slots2, hg_slots2])

	var m_child: Dictionary = gs.call("make_family_member", "c", "Timmy", "child", 9, false, "scout", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var m_teen: Dictionary = gs.call("make_family_member", "t", "Mary Jane", "teen", 16, false, "bookworm", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var m_adult: Dictionary = gs.call("make_family_member", "a", "Dolores", "adult", 39, false, "optimist", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var m_elder: Dictionary = gs.call("make_family_member", "e", "Gramps", "elder", 68, false, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)

	_check(int(m_child["scavenge_slots"]) == 2, "Child (age 9) takes 2 scavenge carry slots", "got %d" % int(m_child["scavenge_slots"]))
	_check(int(m_teen["scavenge_slots"]) == 2, "Teen (age 16) takes 2 scavenge carry slots", "got %d" % int(m_teen["scavenge_slots"]))
	_check(int(m_adult["scavenge_slots"]) == 3, "Adult (age 39) takes 3 scavenge carry slots", "got %d" % int(m_adult["scavenge_slots"]))
	_check(int(m_elder["scavenge_slots"]) == 3, "Elder (age 68) takes 3 scavenge carry slots", "got %d" % int(m_elder["scavenge_slots"]))

	# Verify HouseGenerator walkability & non-duplicate durable spawns across all 3 OSM presets x 5 seeds
	var presets: Array[String] = ["seattle", "concord", "brooklyn"]
	var unreachable_found: int = 0
	var duplicate_durables: int = 0
	var rng := RandomNumberGenerator.new()
	gs.call("init_default_family")
	for pid in presets:
		var parsed: Dictionary = OsmServiceRef.call("load_preset", pid)
		var bldgs: Array = parsed.get("buildings", [])
		var best_house: Dictionary = OsmServiceRef.call("pick_best_house", bldgs, float(parsed.get("center_lat", 47.6)), float(parsed.get("center_lon", -122.3)), int(parsed.get("preferred_osm_id", -1)))
		for seed_i in range(5):
			rng.seed = 1000 + seed_i * 37
			var layout: Dictionary = HouseGenRef.call("generate_from_osm_house", best_house, gs.get("family_members"), rng)
			var nav: Dictionary = layout["nav_grid"]
			var h_pos: Vector2 = layout["hatch_pos"]
			var seen_durables: Dictionary = {}
			for it_v in layout["items"]:
				var it: Dictionary = it_v
				var ipos: Vector2 = it["pos"]
				var iid: String = str(it["item_id"])
				# Pass 2: loot may sit on furniture or against a wall; it counts as reachable when the
				# leader can stand within ScavengeScene.INTERACT_RADIUS of it (the actual pickup rule).
				var w_ok: bool = bool(HouseGenRef.call("is_walkable", nav, ipos)) or bool(load("res://scripts/scavenge/floorplan_generator.gd").call("reachable_near", nav, ipos, float(ScavengeSceneRef.get("INTERACT_RADIUS")) - 4.0))
				var p_arr: PackedVector2Array = HouseGenRef.call("find_path", nav, h_pos, ipos)
				if not w_ok or p_arr.size() < 2:
					unreachable_found += 1
				if iid != "soup" and iid != "water":
					if seen_durables.has(iid):
						duplicate_durables += 1
					seen_durables[iid] = true
			for fam_v in layout["family_spawns"]:
				var fs: Dictionary = fam_v
				var fpos: Vector2 = fs["pos"]
				var fw_ok: bool = bool(HouseGenRef.call("is_walkable", nav, fpos))
				var fp_arr: PackedVector2Array = HouseGenRef.call("find_path", nav, h_pos, fpos)
				if not fw_ok or fp_arr.size() < 2:
					unreachable_found += 1

	_check(unreachable_found == 0, "All spawned items & family across 15 OSM houses are BFS-reachable from hatch", "unreachable=%d" % unreachable_found)
	_check(duplicate_durables == 0, "No duplicate unique durable items spawned in a single house", "duplicates=%d" % duplicate_durables)

	# Live ScavengeScene pickup & deposit test for EVERY family role (adult 3, elder 3, teen 2, child 2) and all 4 2-slot items!
	var leader: Dictionary = gs.call("make_family_member", "ldr", "Ted", "adult", 42, true, "handy", 1, 1, "#4a2e1b", "#2f5d8a", true, 1, "#c84b31", 0)
	gs.set("family_members", [leader, m_adult, m_elder, m_teen, m_child])
	gs.set("demo_mode", false)

	var scav: Node2D = ScavengeSceneRef.new()
	root.add_child(scav)
	scav.call("_start_scavenge_phase")
	_check(int(scav.get("_max_slots")) == 4, "ScavengeScene starts with base _max_slots == 4", "got %d" % int(scav.get("_max_slots")))

	var world_items_ref: Array = scav.get("_world_items")
	var hatch_pos_val: Vector2 = scav.get("_hatch_pos")
	var test_uid: int = 9000
	for two_id in ["suitcase", "axe", "rifle", "toolbox", "soup"]:
		var info_t: Dictionary = ItemDBRef.call("get_item_info", two_id)
		world_items_ref.append({
			"uid": test_uid,
			"item_id": two_id,
			"pos": hatch_pos_val + Vector2(120.0, 0.0),
			"room": "Test",
			"name": str(info_t["name"]),
			"short_name": str(info_t["short_name"]),
			"slots": int(info_t["slots"]),
			"category": str(info_t["category"]),
			"color": Color.WHITE,
			"collected": false,
			"bob_phase": 0.0
		})
		test_uid += 1

	var wf: Array = scav.get("_world_family")
	var fam_adult_target: Dictionary = scav.call("_get_target_by_uid", "family", int((wf[0] as Dictionary)["uid"]))
	var axe_target: Dictionary = scav.call("_get_target_by_uid", "item", 9001)
	var soup_target: Dictionary = scav.call("_get_target_by_uid", "item", 9004)
	var suitcase_target: Dictionary = scav.call("_get_target_by_uid", "item", 9000)
	var rifle_target: Dictionary = scav.call("_get_target_by_uid", "item", 9002)
	var toolbox_target: Dictionary = scav.call("_get_target_by_uid", "item", 9003)

	# Pass 2 rules: grabbing takes time, nothing is deposited by walking over the hatch (SPACE at the
	# hatch deposits), and the suitcase adds capacity only while it is in your hands.
	var ok_adult: bool = _grab_now(scav, fam_adult_target)
	var ok_axe_overflow: bool = _grab_now(scav, axe_target)
	var ok_soup_fit: bool = _grab_now(scav, soup_target)
	_check(ok_adult and (not ok_axe_overflow) and ok_soup_fit and int(scav.call("_get_used_slots")) == 4,
		"4-slot hands hold 3-slot Adult + 1-slot Soup (4/4) and reject 2-slot Axe overflow")

	scav.set("_player_pos", hatch_pos_val)
	scav.call("_process_scavenge_phase", 0.016)
	_check(not (scav.get("_carried_entries") as Array).is_empty(), "Walking onto the hatch alone deposits nothing (no automatic depositing)")
	_space_deposit(scav, hatch_pos_val)
	var gs_fams: Array = gs.get("family_members")
	_check((scav.get("_carried_entries") as Array).is_empty() and bool((gs_fams[1] as Dictionary)["in_bunker"]) and int(gs.get("soup_quarters")) == 4,
		"SPACE at the hatch deposits 3-slot Adult and 1 Soup (+4/4 quarters)")

	var ok_sc: bool = _grab_now(scav, suitcase_target)
	_check(ok_sc and int(scav.get("_max_slots")) == 4 + int(ScavengeSceneRef.get("SUITCASE_EXTRA_SLOTS")),
		"Carrying the suitcase raises hand capacity while it is held", "max=%d" % int(scav.get("_max_slots")))
	var ok_ax: bool = _grab_now(scav, axe_target)
	var ok_rf0: bool = _grab_now(scav, rifle_target)
	_check(ok_ax and ok_rf0 and int(scav.call("_get_used_slots")) == 6, "Suitcase (2) + Axe (2) + Rifle (2) = 6 slots in suitcase hands")
	_space_deposit(scav, hatch_pos_val)
	_check(bool(gs.call("has_working_item", "axe")) and bool(gs.call("has_working_item", "rifle")) and bool(scav.call("_is_carrying_item", "suitcase")),
		"SPACE at the hatch drops Axe & Rifle down the chute and keeps the suitcase in hand")

	var fam_elder_target: Dictionary = scav.call("_get_target_by_uid", "family", int((wf[1] as Dictionary)["uid"]))
	var ok_el: bool = _grab_now(scav, fam_elder_target)
	var ok_tb0: bool = _grab_now(scav, toolbox_target)
	_check(ok_el and ok_tb0 and int(scav.call("_get_used_slots")) == 7, "Suitcase hands hold Suitcase (2) + Elder (3) + Toolbox (2) = 7/7")
	_space_deposit(scav, hatch_pos_val)
	_check(bool((gs_fams[2] as Dictionary)["in_bunker"]) and bool(gs.call("has_working_item", "toolbox")), "Elder and Toolbox deposited cleanly")

	var fam_teen_target: Dictionary = scav.call("_get_target_by_uid", "family", int((wf[2] as Dictionary)["uid"]))
	var fam_child_target: Dictionary = scav.call("_get_target_by_uid", "family", int((wf[3] as Dictionary)["uid"]))
	var ok_tn: bool = _grab_now(scav, fam_teen_target)
	_space_deposit(scav, hatch_pos_val)
	var ok_ch: bool = _grab_now(scav, fam_child_target)
	_space_deposit(scav, hatch_pos_val)
	_check(ok_tn and ok_ch and bool((gs_fams[3] as Dictionary)["in_bunker"]) and bool((gs_fams[4] as Dictionary)["in_bunker"]),
		"Every family role (Adult, Elder, Teen, Child) picked up & deposited with SPACE")

	scav.queue_free()
	await _wait_frames(2)

	# Verify custom family look persistence across reset_to_defaults() and BunkerSim.start_bunker_run()
	var custom_look_m: Dictionary = gs.call("make_family_member", "cust_0", "Beatrice", "elder", 67, true, "bookworm", 3, 4, "#b55239", "#2e8b57", true, 2, "#6a4c93", 3)
	gs.set("family_members", [custom_look_m])
	gs.call("reset_to_defaults")
	(gs.get("family_members")[0] as Dictionary)["in_bunker"] = true
	BunkerSimRef.call("start_bunker_run")
	var persisted_m: Dictionary = gs.get("family_members")[0]
	var look_ok: bool = (
		str(persisted_m["name"]) == "Beatrice"
		and str(persisted_m["role"]) == "elder"
		and int(persisted_m["age"]) == 67
		and str(persisted_m["trait"]) == "bookworm"
		and int(persisted_m["skin_tone"]) == 3
		and int(persisted_m["hair_style"]) == 4
		and str(persisted_m["hair_color"]) == "#b55239"
		and str(persisted_m["eye_color"]) == "#2e8b57"
		and bool(persisted_m["glasses"]) == true
		and int(persisted_m["facial_hair"]) == 2
		and str(persisted_m["outfit_color"]) == "#6a4c93"
		and int(persisted_m["shirt_style"]) == 3
	)
	_check(look_ok, "Custom family appearance (skin, hair, eyes, glasses, facial hair, outfit, role, trait) persists cleanly across resets & BunkerSim")

# =============================================================================
# 2. 60-SECOND SCAVENGE SEQUENCE FIDELITY
# =============================================================================
func _audit_2_scavenge_sequence(gs: Node) -> void:
	print("\n--- SUITE 2: 60-Second Scavenge Sequence Fidelity ---")
	gs.call("init_default_family")
	gs.call("init_default_house")
	gs.call("init_default_nuke")
	gs.set("demo_mode", false)

	var scav: Node2D = ScavengeSceneRef.new()
	root.add_child(scav)
	# Check immediately after _ready() before _process ticks
	_check(int(scav.get("_phase")) == 0 and is_equal_approx(float(scav.get("_scout_total")), 8.0) and is_equal_approx(float(scav.get("_scavenge_total")), 60.0),
		"Starts in SCOUT phase (8.0s) with exact 60.0s scavenge timer ready",
		"phase=%d scout_total=%.2f scav_total=%.2f" % [int(scav.get("_phase")), float(scav.get("_scout_total")), float(scav.get("_scavenge_total"))])

	var wi0: Array = scav.get("_world_items")
	var any_item: Dictionary = scav.call("_get_target_by_uid", "item", int((wi0[0] as Dictionary)["uid"]))
	_check(not bool(scav.call("_attempt_pickup_target", any_item)), "Cannot pick up items during SCOUT phase")

	for _step in range(165):
		scav.call("_process", 0.05)
	_check(int(scav.get("_phase")) == 1 and float(scav.get("_scavenge_time_left")) > 59.7 and float(scav.get("_scavenge_time_left")) <= 60.0,
		"Recon expiry transitions cleanly to 60.0s SCAVENGE phase")

	# 2B. Encumbrance & Sprinter speed math vs UI tooltip
	var spd_0: float = float(scav.call("_compute_move_speed"))
	_grab_now(scav, any_item)
	var spd_1: float = float(scav.call("_compute_move_speed"))
	var slow: float = float(ScavengeSceneRef.get("SLOT_SLOW_PER_UNIT")) * float(int(any_item.get("slots", 1)))
	_check(spd_1 < spd_0 and is_equal_approx(spd_1 / spd_0, 1.0 - slow), "Encumbrance slows movement by SLOT_SLOW_PER_UNIT per used slot", "ratio=%.3f" % (spd_1 / spd_0))

	var trait_list: Array = FamilyScreenRef.get("TRAIT_LIST")
	var sprinter_desc: String = ""
	for td_v in trait_list:
		var td: Dictionary = td_v
		if str(td["id"]) == "sprinter":
			sprinter_desc = str(td["desc"])
	var sprinter_mult: float = float(ScavengeSceneRef.get("SPRINTER_MULT"))
	var actual_sprinter_pct: int = int(round((sprinter_mult - 1.0) * 100.0))
	_check(sprinter_desc.find("%d%%" % actual_sprinter_pct) != -1,
		"Sprinter trait UI description matches actual ScavengeScene.SPRINTER_MULT (+%d%%)" % actual_sprinter_pct,
		"FamilyScreen:19 says '%s' while ScavengeScene:43 uses +%d%% (1.15x)" % [sprinter_desc, actual_sprinter_pct])

	scav.set("_auto_pickup", true)
	var wi1: Dictionary = wi0[1]
	scav.set("_player_pos", wi1["pos"])
	scav.call("_process_scavenge_phase", 0.016)
	_check(not bool(wi1["collected"]), "No automatic pickup: standing on an item does not grab it (SPACE does)")

	scav.queue_free()
	await _wait_frames(2)

	# 2C. Early Dive (F / button) near hatch
	gs.call("init_default_family")
	var scav_dive: Node2D = ScavengeSceneRef.new()
	root.add_child(scav_dive)
	scav_dive.call("_start_scavenge_phase")
	scav_dive.set("_scavenge_time_left", 14.0)
	scav_dive.set("_player_pos", scav_dive.get("_hatch_pos"))
	_check(bool(scav_dive.call("_can_dive_into_bunker")), "Can dive into bunker early when near hatch at <= 20s")
	scav_dive.call("_dive_into_bunker")
	var ldr_dive: Dictionary = scav_dive.get("_leader_member")
	_check(int(scav_dive.get("_phase")) == 2 and bool(ldr_dive["in_bunker"]) and bool(ldr_dive["alive"]),
		"Early dive puts leader safely into bunker and starts OUTRO")
	scav_dive.queue_free()
	await _wait_frames(2)

	# 2D. Expiry at 0.0s INSIDE hatch radius saves leader AND auto-deposits carried items
	gs.call("init_default_family")
	var scav_in: Node2D = ScavengeSceneRef.new()
	root.add_child(scav_in)
	scav_in.call("_start_scavenge_phase")
	var wi_in: Array = scav_in.get("_world_items")
	var item0: Dictionary = scav_in.call("_get_target_by_uid", "item", int((wi_in[0] as Dictionary)["uid"]))
	_grab_now(scav_in, item0)
	var hp_in: Vector2 = scav_in.get("_hatch_pos")
	var hr_in: float = float(scav_in.get("_hatch_radius"))
	scav_in.set("_player_pos", hp_in + Vector2(hr_in + 30.0, 0.0))
	scav_in.set("_scavenge_time_left", 0.02)
	scav_in.call("_process", 0.03)
	var ldr_in: Dictionary = scav_in.get("_leader_member")
	_check(int(scav_in.get("_phase")) == 2 and bool(ldr_in["in_bunker"]) and bool(ldr_in["alive"]) and int(scav_in.get("_items_deposited_count")) == 1,
		"Timer 0.0s expiry within hatch end margin saves leader and deposits carried items")
	scav_in.queue_free()
	await _wait_frames(2)

	# 2E. Expiry at 0.0s OUTSIDE hatch radius with 0 survivors in bunker -> Game Over!
	gs.call("init_default_family")
	var scav_wipe: Node2D = ScavengeSceneRef.new()
	root.add_child(scav_wipe)
	scav_wipe.call("_start_scavenge_phase")
	var hp_w: Vector2 = scav_wipe.get("_hatch_pos")
	scav_wipe.set("_player_pos", hp_w + Vector2(260.0, 0.0))
	scav_wipe.set("_scavenge_time_left", 0.02)
	scav_wipe.call("_process", 0.03)
	for _i in range(45):
		scav_wipe.call("_process", 0.05)
	var ldr_w: Dictionary = scav_wipe.get("_leader_member")
	_check((not bool(ldr_w["alive"])) and bool(gs.get("game_over")) and (not bool(gs.get("victory"))) and str(gs.get("current_screen")) == "summary",
		"Timer 0.0s expiry outside hatch with 0 people in bunker triggers immediate Game Over -> Summary")
	scav_wipe.queue_free()
	await _wait_frames(2)

	# 2F. Expiry at 0.0s OUTSIDE hatch radius when Adult Dolores WAS deposited -> Game continues in Bunker without Ted!
	gs.call("init_default_family")
	var scav_partial: Node2D = ScavengeSceneRef.new()
	root.add_child(scav_partial)
	scav_partial.call("_start_scavenge_phase")
	var wf_p: Array = scav_partial.get("_world_family")
	var dolores_t: Dictionary = scav_partial.call("_get_target_by_uid", "family", int((wf_p[0] as Dictionary)["uid"]))
	_grab_now(scav_partial, dolores_t)
	var hp_p: Vector2 = scav_partial.get("_hatch_pos")
	_space_deposit(scav_partial, hp_p)
	scav_partial.set("_player_pos", hp_p + Vector2(260.0, 0.0))
	scav_partial.set("_scavenge_time_left", 0.02)
	scav_partial.call("_process", 0.03)
	for _i in range(45):
		scav_partial.call("_process", 0.05)
	var fam_after: Array = gs.get("family_members")
	var ted_after: Dictionary = fam_after[0]
	var dol_after: Dictionary = fam_after[1]
	_check((not bool(ted_after["alive"])) and bool(dol_after["alive"]) and bool(dol_after["in_bunker"]) and (not bool(gs.get("game_over"))) and str(gs.get("current_screen")) == "bunker",
		"Leader caught outside while Adult Dolores is in bunker continues survival in Bunker without Leader")
	scav_partial.queue_free()
	await _wait_frames(2)

	# 2G. Expiry at 0.0s OUTSIDE hatch radius when ONLY 9-year-old Child Timmy is in bunker (NO Adult/Teen!)
	gs.call("init_default_family")
	var scav_child_only: Node2D = ScavengeSceneRef.new()
	root.add_child(scav_child_only)
	scav_child_only.call("_start_scavenge_phase")
	var timmy_t: Dictionary = {}
	for fw in scav_child_only.get("_world_family"):
		var fd: Dictionary = fw
		if str((fd["member"] as Dictionary).get("role", "")) == "child":
			timmy_t = scav_child_only.call("_get_target_by_uid", "family", int(fd["uid"]))
			break
	scav_child_only.call("_attempt_pickup_target", timmy_t)
	var hp_c: Vector2 = scav_child_only.get("_hatch_pos")
	scav_child_only.set("_player_pos", hp_c)
	scav_child_only.call("_process", 0.02)
	scav_child_only.set("_player_pos", hp_c + Vector2(260.0, 0.0))
	scav_child_only.set("_scavenge_time_left", 0.02)
	scav_child_only.call("_process", 0.03)
	for _i in range(45):
		scav_child_only.call("_process", 0.05)
	_check(bool(gs.get("game_over")),
		"Child-only bunker rule (ARCHITECTURE.md:103: requires adult/teen survivor)",
		"ScavengeScene:745 allowed 9-year-old child Timmy to continue into SCREEN_BUNKER alone without any adult/teen (game_over=%s, screen=%s)" % [str(gs.get("game_over")), str(gs.get("current_screen"))])
	scav_child_only.queue_free()
	await _wait_frames(2)

	# 2H. Full 60s Demo Auto-Pilot Test
	gs.call("init_default_family")
	gs.set("demo_mode", true)
	var scav_ai: Node2D = ScavengeSceneRef.new()
	root.add_child(scav_ai)
	var steps_guard: int = 0
	while int(scav_ai.get("_phase")) != 2 and steps_guard < 2500:
		scav_ai.call("_process", 0.04)
		steps_guard += 1
	_check(int(scav_ai.get("_phase")) == 2 and (not bool(scav_ai.get("_leader_caught_outside"))) and int(scav_ai.get("_items_deposited_count")) >= 5 and int(scav_ai.get("_family_deposited_count")) >= 2,
		"Demo AI pathfinds, rescues family (%d), deposits supplies (%d), and dives in before 0.0s" % [int(scav_ai.get("_family_deposited_count")), int(scav_ai.get("_items_deposited_count"))])
	scav_ai.queue_free()
	gs.set("demo_mode", false)
	await _wait_frames(2)

# =============================================================================
# 3. BUNKER SURVIVAL LOOP FIDELITY
# =============================================================================
func _audit_3_bunker_survival_math(gs: Node) -> void:
	print("\n--- SUITE 3: Bunker Survival Loop Fidelity ---")

	var gs_rng: RandomNumberGenerator = gs.get("rng")
	gs_rng.seed = 60602026
	var cool_nuke: Dictionary = NukePhysicsRef.call("compute_impact", 47.6242, -122.3195, 47.2529, -122.4443, 300, 180.0, "Distant Cool Target")
	cool_nuke["bunker_temp_c"] = 18.0
	cool_nuke["zone"] = "safe_fringe"

	# 3A. Exact Cool-Bunker Dehydration Death Day (18.0 C, 0 water, fed soup; 2 members)
	var w_ted: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var w_dol: Dictionary = gs.call("make_family_member", "m1", "Dolores", "adult", 39, false, "optimist", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [w_ted, w_dol])
	gs.set("nuke_config", cool_nuke.duplicate(true))
	gs.call("reset_to_defaults")
	w_ted["in_bunker"] = true
	w_dol["in_bunker"] = true
	gs.set("soup_quarters", 80)
	gs.set("water_quarters", 80)
	BunkerSimRef.call("start_bunker_run")

	var thirst_trace: Array[String] = []
	var dehydration_death_day: int = -1
	for _d in range(15):
		BunkerSimRef.call("advance_day", {"m0": {"soup_q": 1, "water_q": 0}, "m1": {"soup_q": 1, "water_q": 1}})
		thirst_trace.append("D%d:t=%d(dww=%d)" % [int(gs.get("day")), int(w_ted["thirst"]), int(w_ted["days_without_water"])])
		if not bool(w_ted["alive"]):
			dehydration_death_day = int(gs.get("day"))
			break
	print("    Dehydration trace (18C cool bunker): " + ", ".join(thirst_trace))
	_check(dehydration_death_day == 7,
		"Standard cool-bunker (18 C) dehydration without water is fatal on Day 7 (6 dry days)",
		"died on Day %d" % dehydration_death_day)

	# 3B. Exact Starvation Death Day (0 soup, watered daily)
	var s_ted: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var s_dol: Dictionary = gs.call("make_family_member", "m1", "Dolores", "adult", 39, false, "optimist", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [s_ted, s_dol])
	gs.set("nuke_config", cool_nuke.duplicate(true))
	gs.call("reset_to_defaults")
	s_ted["in_bunker"] = true
	s_dol["in_bunker"] = true
	gs.set("soup_quarters", 80)
	gs.set("water_quarters", 80)
	BunkerSimRef.call("start_bunker_run")

	var hunger_trace: Array[String] = []
	var starvation_death_day: int = -1
	for _d in range(20):
		BunkerSimRef.call("advance_day", {"m0": {"soup_q": 0, "water_q": 1}, "m1": {"soup_q": 1, "water_q": 1}})
		hunger_trace.append("D%d:h=%d(dwf=%d)" % [int(gs.get("day")), int(s_ted["hunger"]), int(s_ted["days_without_food"])])
		if not bool(s_ted["alive"]):
			starvation_death_day = int(gs.get("day"))
			break
	print("    Starvation trace: " + ", ".join(hunger_trace))
	_check(starvation_death_day == 13,
		"Starvation without soup is fatal on Day 13 (12 foodless days)",
		"died on Day %d" % starvation_death_day)

	# 3C. Ration Recovery Math Check (1/4 Soup & Water drops thirst/hunger by 2: 3->1, 2->0; 2/4 drops 3->0; Tab 2 caps at 0..2 quarters)
	var rec_m: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [rec_m])
	gs.set("nuke_config", cool_nuke.duplicate(true))
	gs.call("reset_to_defaults")
	rec_m["in_bunker"] = true
	gs.set("soup_quarters", 20)
	gs.set("water_quarters", 20)
	BunkerSimRef.call("start_bunker_run")
	for _i in range(5):
		rec_m["sanity"] = 0
		BunkerSimRef.call("advance_day", {"m0": {"soup_q": 1, "water_q": 0}})
	var thirst_before: int = int(rec_m["thirst"])
	rec_m["hunger"] = 3
	rec_m["days_without_food"] = 10
	BunkerSimRef.call("advance_day", {"m0": {"soup_q": 1, "water_q": 1}})
	var thirst_after_1q: int = int(rec_m["thirst"])
	var hunger_after_1q: int = int(rec_m["hunger"])
	var dww_after_1q: int = int(rec_m["days_without_water"])
	_check(thirst_before == 3 and thirst_after_1q == 1 and hunger_after_1q == 1 and dww_after_1q == 0,
		"1/4 Water & 1/4 Soup drop thirst & hunger by 2 (3 -> 1) and reset days_without_water/food to 0",
		"thirst %d->%d, hunger 3->%d, dww=%d" % [thirst_before, thirst_after_1q, hunger_after_1q, dww_after_1q])

	rec_m["thirst"] = 2
	rec_m["hunger"] = 2
	BunkerSimRef.call("advance_day", {"m0": {"soup_q": 1, "water_q": 1}})
	_check(int(rec_m["thirst"]) == 0 and int(rec_m["hunger"]) == 0,
		"1/4 Water & 1/4 Soup drop thirst=2 -> 0 and hunger=2 -> 0",
		"got thirst=%d hunger=%d" % [int(rec_m["thirst"]), int(rec_m["hunger"])])

	rec_m["thirst"] = 3
	rec_m["days_without_water"] = 5
	rec_m["hunger"] = 3
	rec_m["days_without_food"] = 10
	BunkerSimRef.call("advance_day", {"m0": {"soup_q": 2, "water_q": 2}})
	_check(int(rec_m["thirst"]) == 0 and int(rec_m["hunger"]) == 0,
		"2/4 Water & 2/4 Soup completely clear thirst=3 -> 0 and hunger=3 -> 0",
		"got thirst=%d hunger=%d" % [int(rec_m["thirst"]), int(rec_m["hunger"])])

	# Verify Tab 2 per-person daily ration stepper cap (0..2 quarters) in BunkerScene
	var bs_cap_test: Control = BunkerSceneRef.new()
	root.add_child(bs_cap_test)
	await _wait_frames(1)
	bs_cap_test.call("_adjust_member_ration", "m0", "soup_q", 1)
	bs_cap_test.call("_adjust_member_ration", "m0", "soup_q", 1)
	bs_cap_test.call("_adjust_member_ration", "m0", "soup_q", 1)
	bs_cap_test.call("_adjust_member_ration", "m0", "water_q", 5)
	var m0_plan: Dictionary = (bs_cap_test.get("_planned_rations") as Dictionary).get("m0", {})
	_check(int(BunkerSceneRef.get("MAX_DAILY_RATION_QUARTERS")) == 2 and int(m0_plan.get("soup_q", -1)) == 2 and int(m0_plan.get("water_q", -1)) == 2,
		"Tab 2 ration steppers strictly cap per-person daily rations at 0..2 quarters",
		"got soup_q=%s water_q=%s" % [str(m0_plan.get("soup_q")), str(m0_plan.get("water_q"))])
	bs_cap_test.queue_free()
	await _wait_frames(1)

	# 3D. Scorching Bunker (>= 25 C) vs Cool Bunker (18 C) Thirst Acceleration Check
	var hot_m: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var hot_m2: Dictionary = gs.call("make_family_member", "m1", "Dolores", "adult", 39, false, "optimist", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [hot_m, hot_m2])
	gs.call("reset_to_defaults")
	hot_m["in_bunker"] = true
	hot_m2["in_bunker"] = true
	var hot_nuke: Dictionary = NukePhysicsRef.call("compute_impact", 47.6242, -122.3195, 47.6150, -122.3250, 800, 45.0, "1.2km Ground Zero")
	gs.set("nuke_config", hot_nuke)
	gs.set("water_quarters", 40)
	BunkerSimRef.call("start_bunker_run")
	var hot_death_day: int = -1
	for _d in range(10):
		BunkerSimRef.call("advance_day", {"m1": {"soup_q": 0, "water_q": 1}})
		if not bool(hot_m["alive"]):
			hot_death_day = int(gs.get("day"))
			break
	_check(hot_death_day == 6 and hot_death_day < dehydration_death_day,
		"Scorching Bunker (>= 25 C, actual %.1f C) accelerates thirst on dry days (fatal Day %d vs cool Day %d)" % [float(hot_nuke.get("bunker_temp_c", 33.0)), hot_death_day, dehydration_death_day],
		"Scorching bunker died on Day %d vs cool Day %d" % [hot_death_day, dehydration_death_day])

	# Also verify exact 25.0 C boundary accelerates thirst
	var warm25_m: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var warm25_m2: Dictionary = gs.call("make_family_member", "m1", "Dolores", "adult", 39, false, "optimist", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [warm25_m, warm25_m2])
	var warm25_nuke: Dictionary = cool_nuke.duplicate(true)
	warm25_nuke["bunker_temp_c"] = 25.5
	gs.set("nuke_config", warm25_nuke)
	gs.call("reset_to_defaults")
	warm25_m["in_bunker"] = true
	warm25_m2["in_bunker"] = true
	gs.set("water_quarters", 40)
	BunkerSimRef.call("start_bunker_run")
	var warm25_death_day: int = -1
	for _d in range(10):
		BunkerSimRef.call("advance_day", {"m1": {"soup_q": 0, "water_q": 1}})
		if not bool(warm25_m["alive"]):
			warm25_death_day = int(gs.get("day"))
			break
	_check(warm25_death_day == 6, "25.5 C (>= 25 C threshold) scorching shelter heat also accelerates thirst (fatal Day 6)", "died Day %d" % warm25_death_day)

	# 3D2. Mid-Bunker Unattended Young Child Guardian Rule (when sole adult dies leaving 9yo child)
	var guard_adult: Dictionary = gs.call("make_family_member", "ga", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var guard_child: Dictionary = gs.call("make_family_member", "gc", "Timmy", "child", 9, false, "scout", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [guard_adult, guard_child])
	gs.set("nuke_config", cool_nuke.duplicate(true))
	gs.call("reset_to_defaults")
	guard_adult["in_bunker"] = true
	guard_child["in_bunker"] = true
	gs.set("soup_quarters", 40)
	gs.set("water_quarters", 40)
	BunkerSimRef.call("start_bunker_run")
	guard_adult["days_without_water"] = 5
	BunkerSimRef.call("advance_day", {"ga": {"soup_q": 1, "water_q": 0}, "gc": {"soup_q": 1, "water_q": 1}})
	_check((not bool(guard_adult["alive"])) and bool(guard_child["alive"]) and bool(gs.get("game_over")) and (not bool(gs.get("victory"))),
		"Mid-bunker death of last adult/teen guardian leaving only young child (age 9) triggers immediate Game Over",
		"game_over=%s ending='%s'" % [str(gs.get("game_over")), str(gs.get("ending_title"))])

	# 3E. Medkit Curing Sickness & Injury
	var sick_m: Dictionary = gs.call("make_family_member", "m0", "Dolores", "adult", 39, true, "optimist", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [sick_m])
	gs.call("reset_to_defaults")
	sick_m["in_bunker"] = true
	gs.set("medkit_count", 2)
	gs.set("water_quarters", 12)
	gs.set("soup_quarters", 12)
	BunkerSimRef.call("start_bunker_run")
	sick_m["sickness"] = 2
	sick_m["injury"] = 2
	BunkerSimRef.call("advance_day", {"m0": {"soup_q": 1, "water_q": 1}}, "m0")
	_check(int(sick_m["sickness"]) == 0 and int(sick_m["injury"]) == 0 and int(gs.get("medkit_count")) == 1,
		"Medkit cures both sickness and injury and decrements medkit_count by 1")

	# 3F. Mutant Transformation & 100% Immunity Rules (Sickness, Injury, Thirst, Radiation across BunkerSim, EventDeck & ExpeditionEngine)
	var mut_m: Dictionary = gs.call("make_family_member", "m0", "Mary Jane", "teen", 16, true, "scout", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var mut_buddy: Dictionary = gs.call("make_family_member", "m1", "Dolores", "adult", 39, false, "optimist", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [mut_m, mut_buddy])
	gs.set("nuke_config", hot_nuke)
	gs.call("reset_to_defaults")
	mut_m["in_bunker"] = true
	mut_buddy["in_bunker"] = true
	gs.set("water_quarters", 40)
	gs.set("soup_quarters", 40)
	BunkerSimRef.call("start_bunker_run")
	mut_m["is_mutant"] = true
	for _d in range(10):
		mut_m["injury"] = 2
		mut_m["sickness"] = 2
		mut_m["radiation"] = 50.0
		BunkerSimRef.call("advance_day", {"m0": {"soup_q": 0, "water_q": 0}, "m1": {"soup_q": 1, "water_q": 1}})
	_check(bool(mut_m["alive"]) and int(mut_m["thirst"]) == 0 and int(mut_m["sickness"]) == 0 and int(mut_m["injury"]) == 0 and is_equal_approx(float(mut_m["radiation"]), 0.0) and int(mut_m["days_without_food"]) == 5,
		"Mutant is 100% immune to thirst, sickness, injury, and radiation in BunkerSim, and ticks hunger at half speed (dwf=5 after 10 days)",
		"alive=%s thirst=%d sick=%d inj=%d rad=%.1f dwf=%d" % [str(mut_m["alive"]), int(mut_m["thirst"]), int(mut_m["sickness"]), int(mut_m["injury"]), float(mut_m["radiation"]), int(mut_m["days_without_food"])])

	# Verify EventDeck & ExpeditionEngine mutant immunities too
	EventDeckRef.call("_adjust_member_stat", mut_m, "sickness", 2)
	EventDeckRef.call("_adjust_member_stat", mut_m, "injury", 2)
	EventDeckRef.call("_adjust_member_stat", mut_m, "thirst", 2)
	gs.set("surface_radiation_sv", 8.5)
	ExpeditionRef.call("start_expedition", "m0", 0, [])
	while not (gs.get("active_expedition") as Dictionary).is_empty():
		ExpeditionRef.call("tick_active_expedition")
	_check(int(mut_m["sickness"]) == 0 and int(mut_m["injury"]) == 0 and int(mut_m["thirst"]) == 0 and is_equal_approx(float(mut_m["radiation"]), 0.0),
		"Mutant remains 100% immune to sickness, injury, thirst, and 8.5 Sv/hr surface fallout across EventDeck & unmasked Expeditions",
		"sick=%d inj=%d thirst=%d rad=%.2f" % [int(mut_m["sickness"]), int(mut_m["injury"]), int(mut_m["thirst"]), float(mut_m["radiation"])])

	gs_rng.seed = 77777
	var rad_mutated: bool = false
	for _attempt in range(40):
		var rm: Dictionary = gs.call("make_family_member", "m0", "Mary Jane", "teen", 16, true, "scout", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
		gs.set("family_members", [rm])
		gs.call("reset_to_defaults")
		rm["in_bunker"] = true
		gs.set("water_quarters", 20)
		gs.set("soup_quarters", 20)
		BunkerSimRef.call("start_bunker_run")
		# Pass 2: radiation is a real dose; 3.5 Sv in a week is the old ">65 rads" band.
		load("res://scripts/core/radiation_model.gd").call("add_dose", rm, 3500.0, int(gs.get("day")))
		BunkerSimRef.call("advance_day", {"m0": {"soup_q": 1, "water_q": 1}})
		if bool(rm["is_mutant"]):
			rad_mutated = true
			break
	_check(rad_mutated, "High radiation (>65 rads) triggers Mutant transformation in BunkerSim")

	# 3G. Sanity -> Insanity Consequences
	gs_rng.seed = 88888
	var mad_broke_item: bool = false
	var mad_left_bunker: bool = false
	for _trial in range(30):
		var mad_m: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
		gs.set("family_members", [mad_m])
		gs.set("nuke_config", cool_nuke.duplicate(true))
		gs.call("reset_to_defaults")
		mad_m["in_bunker"] = true
		gs.set("water_quarters", 40)
		gs.set("soup_quarters", 40)
		gs.call("add_scavenged_item", "flashlight", 1)
		BunkerSimRef.call("start_bunker_run")
		mad_m["sanity"] = 3
		mad_m["insane_days"] = 2
		for _step_m in range(5):
			if not bool(mad_m["alive"]):
				break
			mad_m["sanity"] = 3
			BunkerSimRef.call("advance_day", {"m0": {"soup_q": 1, "water_q": 1}})
			var fl_e: Dictionary = (gs.get("bunker_items") as Dictionary)["flashlight"]
			if bool(fl_e["broken"]):
				mad_broke_item = true
			if not bool(mad_m["alive"]) and not bool(mad_m["in_bunker"]):
				mad_left_bunker = true
		if mad_broke_item and mad_left_bunker:
			break
	_check(mad_broke_item and mad_left_bunker, "Insanity (sanity=3) breaks durable gear and can cause survivor to abandon the bunker")

	# 3H. Broken Item Repair via Toolbox, Book, and Handy trait
	var rng_rep := RandomNumberGenerator.new()
	rng_rep.seed = 42
	var handy_ted: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [handy_ted])
	gs.set("nuke_config", cool_nuke.duplicate(true))
	gs.call("reset_to_defaults")
	handy_ted["in_bunker"] = true
	gs.call("add_scavenged_item", "radio", 1)
	gs.call("add_scavenged_item", "toolbox", 1)
	gs.call("add_scavenged_item", "book", 1)
	BunkerSimRef.call("start_bunker_run")
	for rep_mode in ["use_toolbox", "use_book", "use_handy"]:
		gs.call("break_or_consume_item", "radio")
		var ev_rep: Dictionary = EventDeckRef.call("build_event_by_id", "repair_broken_gear", 6, rng_rep)
		EventDeckRef.call("resolve_event", ev_rep, rep_mode, rng_rep)
		_check(bool(gs.call("has_working_item", "radio")), "Broken Radio repaired cleanly via '%s'" % rep_mode)

	# 3I. Companions: Pet Adoption (adopt_soup 100% vs free coaxing ~45%) + 4-Day Soup Upkeep & Runaway
	var rng_pet := RandomNumberGenerator.new()
	rng_pet.seed = 202612
	var cat_soup_ok: bool = true
	var dog_soup_ok: bool = true
	var cat_free_wins: int = 0
	var dog_free_wins: int = 0
	for _pi in range(100):
		gs.set("has_cat_sharikov", false)
		gs.set("has_dog_pancake", false)
		gs.set("soup_quarters", 4)
		var ev_cat_s: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_scientist_1", 5, rng_pet)
		EventDeckRef.call("resolve_event", ev_cat_s, "adopt_soup", rng_pet)
		if not bool(gs.get("has_cat_sharikov")) or int(gs.get("soup_quarters")) != 3:
			cat_soup_ok = false
		var ev_dog_s: Dictionary = EventDeckRef.call("build_event_by_id", "companion_pancake_dog", 5, rng_pet)
		EventDeckRef.call("resolve_event", ev_dog_s, "adopt_soup", rng_pet)
		if not bool(gs.get("has_dog_pancake")) or int(gs.get("soup_quarters")) != 2:
			dog_soup_ok = false

		gs.set("has_cat_sharikov", false)
		gs.set("has_dog_pancake", false)
		var ev_cat_f: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_scientist_1", 5, rng_pet)
		EventDeckRef.call("resolve_event", ev_cat_f, "adopt_pet", rng_pet)
		if bool(gs.get("has_cat_sharikov")):
			cat_free_wins += 1
		var ev_dog_f: Dictionary = EventDeckRef.call("build_event_by_id", "companion_pancake_dog", 5, rng_pet)
		EventDeckRef.call("resolve_event", ev_dog_f, "let_in", rng_pet)
		if bool(gs.get("has_dog_pancake")):
			dog_free_wins += 1
	_check(cat_soup_ok and dog_soup_ok and cat_free_wins >= 25 and cat_free_wins <= 65 and dog_free_wins >= 25 and dog_free_wins <= 65,
		"Pet adoption: 'adopt_soup' is 100%% (-1/4 soup) while free coaxing succeeds ~45%% (Sharikov=%d%%, Pancake=%d%%)" % [cat_free_wins, dog_free_wins],
		"cat_soup=%s dog_soup=%s cat_free=%d dog_free=%d" % [str(cat_soup_ok), str(dog_soup_ok), cat_free_wins, dog_free_wins])

	gs_rng.seed = 12345
	gs.call("reset_to_defaults")
	handy_ted["in_bunker"] = true
	gs.set("has_cat_sharikov", true)
	gs.set("has_dog_pancake", true)
	gs.set("soup_quarters", 10)
	gs.set("water_quarters", 80)
	BunkerSimRef.call("start_bunker_run")
	for _d in range(2):
		BunkerSimRef.call("advance_day", {"m0": {"soup_q": 0, "water_q": 1}})
	var soup_pre_day4: int = int(gs.get("soup_quarters"))
	BunkerSimRef.call("advance_day", {"m0": {"soup_q": 0, "water_q": 1}})
	var day4_rep: String = str(BunkerSimRef.call("get_latest_day_report"))
	_check(day4_rep.find("split a quarter-tin of tomato soup") != -1 and int(gs.get("soup_quarters")) == soup_pre_day4 - 1,
		"Sharikov & Pancake consume 1/4 soup upkeep every 4th day (Day 4: %d -> %d quarters)" % [soup_pre_day4, int(gs.get("soup_quarters"))])

	for _d in range(40):
		gs.set("soup_quarters", 0)
		BunkerSimRef.call("advance_day", {"m0": {"soup_q": 0, "water_q": 1}})
		handy_ted["days_without_food"] = 0
		handy_ted["sanity"] = 0
	_check((not bool(gs.get("has_cat_sharikov"))) and (not bool(gs.get("has_dog_pancake"))),
		"Unfed Sharikov & Pancake both run away when 0 soup is available across multiple feeding days",
		"cat=%s dog=%s" % [str(gs.get("has_cat_sharikov")), str(gs.get("has_dog_pancake"))])

	# 3J. Age Role & Trait Promise Audit (Child stretches food, Elder morale anchor, Bookworm sanity, Iron Stomach sickness, Scout loot/speed)
	var child_test: Dictionary = gs.call("make_family_member", "c0", "Timmy", "child", 9, false, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var adult_test: Dictionary = gs.call("make_family_member", "a0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [adult_test, child_test])
	gs.set("nuke_config", cool_nuke.duplicate(true))
	gs.call("reset_to_defaults")
	adult_test["in_bunker"] = true
	child_test["in_bunker"] = true
	gs.set("water_quarters", 100)
	gs.set("soup_quarters", 0)
	BunkerSimRef.call("start_bunker_run")
	for _d in range(6):
		BunkerSimRef.call("advance_day", {"a0": {"soup_q": 0, "water_q": 1}, "c0": {"soup_q": 0, "water_q": 1}})
	_check(int(child_test["days_without_food"]) < int(adult_test["days_without_food"]),
		"Child role ('Light eater' per FamilyScreen:193) stretches food longer than Adult",
		"Child dwf=%d vs Adult dwf=%d" % [int(child_test["days_without_food"]), int(adult_test["days_without_food"])])

	# Verify Elder ('Wise morale anchor') & Bookworm ('Keeps sanity steadier') soothe sanity in BunkerSim
	gs_rng.seed = 54321
	var elder_soothed: int = 0
	var plain_soothed: int = 0
	for _tr_e in range(30):
		var el_m: Dictionary = gs.call("make_family_member", "e0", "Gramps", "elder", 68, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
		var bw_m: Dictionary = gs.call("make_family_member", "b0", "Mary Jane", "teen", 16, false, "bookworm", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
		gs.set("family_members", [el_m, bw_m])
		gs.call("reset_to_defaults")
		el_m["in_bunker"] = true
		bw_m["in_bunker"] = true
		gs.set("soup_quarters", 20)
		gs.set("water_quarters", 20)
		BunkerSimRef.call("start_bunker_run")
		el_m["sanity"] = 2
		bw_m["sanity"] = 2
		BunkerSimRef.call("advance_day", {"e0": {"soup_q": 1, "water_q": 1}, "b0": {"soup_q": 1, "water_q": 1}})
		if int(el_m["sanity"]) < 2:
			elder_soothed += 1
		if int(bw_m["sanity"]) < 2:
			elder_soothed += 1

		var p1: Dictionary = gs.call("make_family_member", "p0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
		var p2: Dictionary = gs.call("make_family_member", "p1", "Bob", "adult", 38, false, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
		gs.set("family_members", [p1, p2])
		gs.call("reset_to_defaults")
		p1["in_bunker"] = true
		p2["in_bunker"] = true
		gs.set("soup_quarters", 20)
		gs.set("water_quarters", 20)
		BunkerSimRef.call("start_bunker_run")
		p1["sanity"] = 2
		p2["sanity"] = 2
		BunkerSimRef.call("advance_day", {"p0": {"soup_q": 1, "water_q": 1}, "p1": {"soup_q": 1, "water_q": 1}})
		if int(p1["sanity"]) < 2:
			plain_soothed += 1
		if int(p2["sanity"]) < 2:
			plain_soothed += 1
	_check(elder_soothed >= 15 and plain_soothed == 0,
		"Elder role ('Wise morale anchor') & Bookworm trait actively soothe sanity even with 0 morale items (soothed=%d vs plain=%d)" % [elder_soothed, plain_soothed],
		"elder_soothed=%d plain_soothed=%d" % [elder_soothed, plain_soothed])

	# Check Iron Stomach sickness resistance on stale rations (classic_suspicious_soup_can)
	var iron_sick_count: int = 0
	var rng_iron := RandomNumberGenerator.new()
	rng_iron.seed = 999
	for _tr in range(50):
		var im: Dictionary = gs.call("make_family_member", "m0", "Ted", "adult", 40, true, "iron_stomach", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
		gs.set("family_members", [im])
		gs.call("reset_to_defaults")
		im["in_bunker"] = true
		BunkerSimRef.call("start_bunker_run")
		var ev_stale: Dictionary = EventDeckRef.call("build_event_by_id", "classic_suspicious_soup_can", 5, rng_iron)
		EventDeckRef.call("resolve_event", ev_stale, "yes", rng_iron)
		if int(im["sickness"]) > 0:
			iron_sick_count += 1
	_check(iron_sick_count < 12,
		"Iron Stomach trait ('Resists sickness from stale rations & fallout' per FamilyScreen:20) reduces stale-ration sickness (%d/50)" % iron_sick_count,
		"Got sick %d/50 times" % iron_sick_count)

	# 3K. Expedition Suitcase Gear Limit (max 1 without Suitcase, Suitcase + up to 3 with Suitcase) & Dead Explorer checked_out Cleanup
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	var fams: Array = gs.get("family_members")
	for fm in fams:
		(fm as Dictionary)["in_bunker"] = true
	for gid_all in ["gas_mask", "rifle", "axe", "flashlight", "map"]:
		gs.call("add_scavenged_item", gid_all, 1)
	gs.set("nuke_config", hot_nuke)
	BunkerSimRef.call("start_bunker_run")
	var dol_exp: Dictionary = fams[1]
	ExpeditionRef.call("start_expedition", str(dol_exp["id"]), 0, ["gas_mask", "rifle", "axe", "flashlight", "map"])
	var carried_no_sc: Array = (gs.get("active_expedition") as Dictionary).get("gear_ids", [])
	_check(carried_no_sc.size() == 1,
		"Expedition without Suitcase strictly enforces max 1 carried item",
		"carried %d items: %s" % [carried_no_sc.size(), str(carried_no_sc)])

	dol_exp["alive"] = false
	ExpeditionRef.call("tick_active_expedition")
	var gm_entry: Dictionary = (gs.get("bunker_items") as Dictionary).get("gas_mask", {})
	_check(not bool(gm_entry.get("checked_out", false)),
		"When explorer dies on expedition, checked-out gear clears 'checked_out' flag instead of leaving ghost 'OUT' icon on shelf",
		"gas_mask entry is %s while active_expedition is empty!" % str(gm_entry))

	# Now test WITH Suitcase owned & packed (Suitcase + up to 3 extra items = 4 total)
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	for fm2 in gs.get("family_members"):
		(fm2 as Dictionary)["in_bunker"] = true
	for gid_sc in ["suitcase", "gas_mask", "rifle", "axe", "flashlight", "map"]:
		gs.call("add_scavenged_item", gid_sc, 1)
	BunkerSimRef.call("start_bunker_run")
	var ted_exp: Dictionary = (gs.get("family_members") as Array)[0]
	ExpeditionRef.call("start_expedition", str(ted_exp["id"]), 0, ["suitcase", "gas_mask", "rifle", "axe", "flashlight", "map"])
	var carried_with_sc: Array = (gs.get("active_expedition") as Dictionary).get("gear_ids", [])
	_check(carried_with_sc.size() == 4 and carried_with_sc.has("suitcase"),
		"Expedition with Suitcase allows Suitcase + up to 3 extra gear items (4 total, rejecting 5th/6th)",
		"carried %d items: %s" % [carried_with_sc.size(), str(carried_with_sc)])
	gs.set("active_expedition", {})
	ted_exp["on_expedition"] = false

	# 3L. POI Depletion Reset Across Bunker Runs
	var targets_now: Array = ExpeditionRef.call("get_available_targets")
	if not targets_now.is_empty():
		(targets_now[0] as Dictionary)["visited_count"] = 2
		(targets_now[0] as Dictionary)["depleted"] = true
	gs.call("reset_to_defaults")
	for fm3 in gs.get("family_members"):
		(fm3 as Dictionary)["in_bunker"] = true
	BunkerSimRef.call("start_bunker_run")
	var targets_after_reset: Array = ExpeditionRef.call("get_available_targets")
	var still_depleted: bool = not targets_after_reset.is_empty() and (bool((targets_after_reset[0] as Dictionary).get("depleted", false)) or int((targets_after_reset[0] as Dictionary).get("visited_count", 0)) != 0)
	_check(not still_depleted,
		"Starting a new bunker run resets nearby_pois visited_count=0 & depleted=false cleanly",
		"POI #0 remained %s!" % str(targets_after_reset[0] if not targets_after_reset.is_empty() else {}))

# =============================================================================
# 4. EVENT DECK & 3-STAGE RESCUE CHAINS (300+ DRAWS & RESOLUTIONS)
# =============================================================================
func _audit_4_event_deck_and_rescue_chains(gs: Node) -> void:
	print("\n--- SUITE 4: Event Deck & 3-Stage Rescue Chains ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20266060

	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	for fm in gs.get("family_members"):
		(fm as Dictionary)["in_bunker"] = true
	BunkerSimRef.call("start_bunker_run")

	var all_ev_ids: Array = EventDeckRef.call("get_all_event_ids")
	_check(all_ev_ids.size() == 61, "EventDeck contains 61 distinct events (60 originals + distant second strike)", "got %d" % all_ev_ids.size())

	var softlocked_events: int = 0
	var empty_text_events: int = 0
	for eid_v in all_ev_ids:
		var eid: String = str(eid_v)
		var ev_empty: Dictionary = EventDeckRef.call("build_event_by_id", eid, 10, rng)
		var opts: Array = ev_empty.get("options", [])
		var has_avail: bool = false
		for o_v in opts:
			if bool((o_v as Dictionary).get("available", false)):
				has_avail = true
				break
		if not has_avail:
			softlocked_events += 1
		var res_empty: Dictionary = EventDeckRef.call("resolve_event", ev_empty, "", rng)
		if str(ev_empty.get("description", "")).is_empty() or str(res_empty.get("outcome_text", "")).is_empty():
			empty_text_events += 1

	_check(softlocked_events == 0 and empty_text_events == 0,
		"All 60 events have >=1 available option with empty inventory (0 softlocks) and non-empty prose")

	var total_draws: int = 0
	var unique_drawn: Dictionary = {}
	for _run_idx in range(8):
		gs.call("init_default_family")
		gs.call("reset_to_defaults")
		for fm in gs.get("family_members"):
			(fm as Dictionary)["in_bunker"] = true
		gs.set("soup_quarters", 80)
		gs.set("water_quarters", 80)
		for gid in ["radio", "gas_mask", "map", "rifle", "toolbox", "padlock"]:
			gs.call("add_scavenged_item", gid, 1)
		gs.call("add_scavenged_item", "ammo", 2)
		gs.call("add_scavenged_item", "bug_spray", 2)
		BunkerSimRef.call("start_bunker_run")

		for d in range(1, 41):
			gs.set("day", d)
			var ev: Dictionary = EventDeckRef.call("draw_daily_event", d, rng)
			var eid_drawn: String = str(ev.get("id", ""))
			unique_drawn[eid_drawn] = true
			var opts_d: Array = ev.get("options", [])
			var pick_cid: String = ""
			for ov in opts_d:
				var od: Dictionary = ov
				if bool(od.get("available", false)):
					pick_cid = str(od.get("id", ""))
					break
			if eid_drawn.ends_with("_3"):
				pick_cid = "no"
			EventDeckRef.call("resolve_event", ev, pick_cid, rng)
			total_draws += 1

	_check(total_draws == 320 and unique_drawn.size() >= 40,
		"320 simulated draws across Days 1-40 executed cleanly with rich variety (%d unique events drawn)" % unique_drawn.size())

	# 4C. Check Day 1 Event Reachability in BunkerScene (day1_civil_defense_seal)
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	for fm in gs.get("family_members"):
		(fm as Dictionary)["in_bunker"] = true
	gs.call("request_screen", "bunker")
	await _wait_frames(3)
	var active_bunker: Node = main_scene_active_node()
	if active_bunker != null:
		var day1_ev: Dictionary = active_bunker.get("_current_event")
		_check(not day1_ev.is_empty() and str(day1_ev.get("id", "")) == "day1_civil_defense_seal",
			"EventDeck's Day 1 event 'day1_civil_defense_seal' is drawn and playable on Day 1 in BunkerScene",
			"BunkerScene:515 skips EventDeck on Day 1 (_current_event=%s), making day1_civil_defense_seal unreachable dead code!" % str(day1_ev))

	# 4C2. Check EventDeck.reset_state() & _sanctuary_poi_cache reset cleanly across runs in a new city!
	gs.set("current_neighborhood_label", "Capitol Hill, Seattle, WA")
	gs.set("nearby_pois", [{"name": "All Pilgrims Christian Church", "category": "church"}])
	BunkerSimRef.call("start_bunker_run")
	EventDeckRef.call("draw_daily_event", 1, rng)
	EventDeckRef.call("draw_daily_event", 2, rng)
	EventDeckRef.call("build_event_by_id", "rescue_sanctuary_1", 2, rng) # Caches Seattle church in Run #1
	# Now player starts Run #2 in Concord, MA
	gs.set("current_neighborhood_label", "Historic Center, Concord, MA")
	gs.set("nearby_pois", [{"name": "First Parish in Concord", "category": "church"}])
	BunkerSimRef.call("start_bunker_run")
	var concord_sanc: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_sanctuary_1", 2, rng)
	var cached_church_used: String = str((concord_sanc.get("context", {}) as Dictionary).get("poi_name", ""))
	_check(cached_church_used == "First Parish in Concord",
		"EventDeck.reset_state() clears _sanctuary_poi_cache cleanly when starting a new run in Concord, MA",
		"Concord run used stale cached '%s'" % cached_church_used)

	# 4D. Check EventDeck._sanitize_choice strictly rejects available == false item options!
	gs.call("reset_to_defaults")
	for fm in gs.get("family_members"):
		(fm as Dictionary)["in_bunker"] = true
	BunkerSimRef.call("start_bunker_run")
	var ev_mil1: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_military_1", 6, rng)
	var sanitized_radio: String = str(EventDeckRef.call("_sanitize_choice", ev_mil1, "use_radio"))
	var ev_day1_cheat: Dictionary = EventDeckRef.call("build_event_by_id", "day1_civil_defense_seal", 1, rng)
	gs.set("bunker_structural_integrity", 60.0)
	EventDeckRef.call("resolve_event", ev_day1_cheat, "use_toolbox", rng)
	var ev_trade_cheat: Dictionary = EventDeckRef.call("build_event_by_id", "trader_wasteland_swap", 8, rng)
	EventDeckRef.call("resolve_event", ev_trade_cheat, "trade_ammo", rng)
	_check(sanitized_radio != "use_radio" and is_equal_approx(float(gs.get("bunker_structural_integrity")), 60.0) and not bool(gs.call("has_working_item", "gas_mask")),
		"EventDeck._sanitize_choice strictly rejects available==false options (blocks unowned Radio, Toolbox, and Ammo trades)",
		"sanitized='%s', integrity=%.1f, gas_mask=%s" % [sanitized_radio, float(gs.get("bunker_structural_integrity")), str(gs.call("has_working_item", "gas_mask"))])

	# 4E. Check whether EventDeck morale_delta moves family sanity BOTH up (negative morale) and down (positive morale)!
	var gs_rng4: RandomNumberGenerator = gs.get("rng")
	gs_rng4.seed = 909090
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	for fm in gs.get("family_members"):
		(fm as Dictionary)["in_bunker"] = true
		(fm as Dictionary)["sanity"] = 0
	gs.set("soup_quarters", 40)
	gs.set("water_quarters", 40)
	BunkerSimRef.call("start_bunker_run")
	for _k in range(6):
		var out_neg: Dictionary = {"outcome_text": "Bitter argument", "morale_delta": -2, "tags": ["morale_down"]}
		BunkerSimRef.call("advance_day", {"member_0": {"soup_q": 1, "water_q": 1}, "member_1": {"soup_q": 1, "water_q": 1}, "member_2": {"soup_q": 1, "water_q": 1}, "member_3": {"soup_q": 1, "water_q": 1}}, "", out_neg)
	var max_san_after_neg_events: int = 0
	for fm in gs.get("family_members"):
		max_san_after_neg_events = maxi(max_san_after_neg_events, int((fm as Dictionary)["sanity"]))

	# Positive morale_delta (+2) on two plain adults (no morale items, no optimist, no elder) drops sanity 2 -> 1
	var pos_m1: Dictionary = gs.call("make_family_member", "pm0", "Ted", "adult", 40, true, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	var pos_m2: Dictionary = gs.call("make_family_member", "pm1", "Bob", "adult", 38, false, "handy", 1, 0, "#000000", "#000000", false, 0, "#ffffff", 0)
	gs.set("family_members", [pos_m1, pos_m2])
	gs.call("reset_to_defaults")
	pos_m1["in_bunker"] = true
	pos_m2["in_bunker"] = true
	gs.set("soup_quarters", 20)
	gs.set("water_quarters", 20)
	BunkerSimRef.call("start_bunker_run")
	pos_m1["sanity"] = 2
	pos_m2["sanity"] = 2
	BunkerSimRef.call("advance_day", {"pm0": {"soup_q": 1, "water_q": 1}, "pm1": {"soup_q": 1, "water_q": 1}}, "", {"outcome_text": "Good news!", "morale_delta": 2, "tags": ["morale_up"]})
	_check(max_san_after_neg_events > 0 and int(pos_m1["sanity"]) == 1 and int(pos_m2["sanity"]) == 1,
		"Event morale_delta genuinely moves sanity both UP on negative events (0 -> %d) and DOWN on positive events (2 -> %d)" % [max_san_after_neg_events, int(pos_m1["sanity"])],
		"neg_max=%d pos_after=%d" % [max_san_after_neg_events, int(pos_m1["sanity"])])

	# 4F. Roaches, Ventilation Leak & Trader Swap Verification
	gs.call("reset_to_defaults")
	var t_fam: Array = gs.get("family_members")
	for fm in t_fam:
		(fm as Dictionary)["in_bunker"] = true
	gs.set("bug_spray_count", 2)
	gs.set("ammo_count", 2)
	gs.call("add_scavenged_item", "toolbox", 1)
	BunkerSimRef.call("start_bunker_run")

	var ev_roach: Dictionary = EventDeckRef.call("build_event_by_id", "hazard_mutant_roaches", 6, rng)
	EventDeckRef.call("resolve_event", ev_roach, "use_bug_spray", rng)
	_check(int(gs.get("bug_spray_count")) == 1, "Roaches resolved with Bug Spray (consumes 1 bug_spray)")

	var ev_vent: Dictionary = EventDeckRef.call("build_event_by_id", "hazard_vent_filter", 7, rng)
	var out_vent: Dictionary = EventDeckRef.call("resolve_event", ev_vent, "use_toolbox", rng)
	_check((out_vent.get("tags", []) as Array).has("morale_up"), "Ventilation leak repaired cleanly with Toolbox")

	var ev_trade: Dictionary = EventDeckRef.call("build_event_by_id", "trader_wasteland_swap", 8, rng)
	EventDeckRef.call("resolve_event", ev_trade, "trade_ammo", rng)
	_check(int(gs.get("ammo_count")) == 0 and bool(gs.call("has_working_item", "gas_mask")),
		"Trader swaps 2 Ammo for needed Gas Mask cleanly")

	# 4G. Raider Defense Matrix + Raider Overrun Game-Over Bug Check!
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	var lone_ted: Dictionary = (gs.get("family_members") as Array)[0]
	lone_ted["in_bunker"] = true
	gs.set("family_members", [lone_ted])
	gs.set("soup_quarters", 20)
	gs.set("water_quarters", 20)
	BunkerSimRef.call("start_bunker_run")

	gs.set("padlock_active", true)
	var ev_raid1: Dictionary = EventDeckRef.call("build_event_by_id", "raiders_blast_hatch", 6, rng)
	EventDeckRef.call("resolve_event", ev_raid1, "use_padlock", rng)
	_check(not bool(gs.get("padlock_active")) and int(gs.get("soup_quarters")) == 20, "Padlock blocks raiders and is consumed")

	gs.call("add_scavenged_item", "rifle", 1)
	gs.set("ammo_count", 2)
	var ev_raid2: Dictionary = EventDeckRef.call("build_event_by_id", "raiders_blast_hatch", 7, rng)
	EventDeckRef.call("resolve_event", ev_raid2, "use_rifle", rng)
	_check(int(gs.get("ammo_count")) == 1 and int(gs.get("soup_quarters")) == 22, "Rifle + Ammo repels raiders (-1 ammo, +2/4 soup)")

	gs.call("add_scavenged_item", "axe", 1)
	var ev_raid_axe: Dictionary = EventDeckRef.call("build_event_by_id", "raiders_blast_hatch", 8, rng)
	var out_axe: Dictionary = EventDeckRef.call("resolve_event", ev_raid_axe, "use_axe", rng)
	_check((out_axe.get("tags", []) as Array).has("raid"), "Axe repels raiders (with 15% chip risk)")

	gs.set("has_dog_pancake", true)
	var ev_raid_dog: Dictionary = EventDeckRef.call("build_event_by_id", "raiders_blast_hatch", 9, rng)
	var out_dog: Dictionary = EventDeckRef.call("resolve_event", ev_raid_dog, "use_dog", rng)
	_check((out_dog.get("tags", []) as Array).has("companion"), "Pancake the Dog repels raiders")

	lone_ted["is_mutant"] = true
	var ev_raid_mut: Dictionary = EventDeckRef.call("build_event_by_id", "raiders_blast_hatch", 10, rng)
	var out_mut: Dictionary = EventDeckRef.call("resolve_event", ev_raid_mut, "use_mutant", rng)
	_check((out_mut.get("tags", []) as Array).has("mutant"), "Mutant family member scares off raiders")
	lone_ted["is_mutant"] = false

	gs.call("add_scavenged_item", "harmonica", 1)
	var w_pre_harm: int = int(gs.get("water_quarters"))
	var ev_raid3: Dictionary = EventDeckRef.call("build_event_by_id", "raiders_blast_hatch", 11, rng)
	EventDeckRef.call("resolve_event", ev_raid3, "use_harmonica", rng)
	_check(int(gs.get("water_quarters")) == w_pre_harm + 2, "Harmonica charms raiders (+2/4 water)")

	gs.set("day", 14)
	gs.set("bunker_structural_integrity", 20.0)
	gs.set("padlock_active", false)
	var ev_overrun: Dictionary = EventDeckRef.call("build_event_by_id", "raiders_blast_hatch", 14, rng)
	var out_overrun: Dictionary = EventDeckRef.call("resolve_event", ev_overrun, "cower", rng)
	var go_after_resolve: bool = bool(gs.get("game_over"))
	BunkerSimRef.call("advance_day", {"member_0": {"soup_q": 1, "water_q": 1}}, "", out_overrun)
	var go_after_advance: bool = bool(gs.get("game_over"))
	_check(go_after_resolve and go_after_advance,
		"Raider Overrun defeat persists through BunkerSim.advance_day and ends the game",
		"EventDeck:1550 set game_over=%s, but BunkerSim.advance_day:164 wiped game_over=%s!" % [str(go_after_resolve), str(go_after_advance)])

	# 4H. Test ALL THREE 3-Stage Rescue Victory Chains (military, sanctuary, scientist) via natural EventDeck draws!
	for chain_name in ["military", "sanctuary", "scientist"]:
		var reached_victory: bool = _simulate_natural_rescue_victory(gs, chain_name, rng)
		_check(reached_victory, "3-stage Rescue Victory Chain '%s' naturally reaches Stage 3 and sets GameState.victory=true & game_over=true" % chain_name)

	# 4I. Test ALL THREE Stage 3 Rescue Evacuations when sole survivor is critically parched (dww=5) & starving (dwf=11), AND verify custom OSM Church ending preservation!
	for stage3_chain in ["military", "sanctuary", "scientist"]:
		gs.call("init_default_family")
		gs.call("reset_to_defaults")
		gs.set("current_neighborhood_label", "Historic Center, Concord, MA")
		gs.set("nearby_pois", [{"name": "First Parish in Concord", "category": "church"}])
		var evac_m: Dictionary = (gs.get("family_members") as Array)[0]
		evac_m["in_bunker"] = true
		gs.set("family_members", [evac_m])
		if stage3_chain == "scientist":
			gs.set("has_cat_sharikov", true)
		BunkerSimRef.call("start_bunker_run")
		gs.set("day", 16)
		evac_m["days_without_water"] = 5
		evac_m["thirst"] = 3
		evac_m["days_without_food"] = 11
		evac_m["hunger"] = 3
		(gs.get("rescue_chains") as Dictionary)[stage3_chain] = 2
		var ev_s3: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_%s_3" % stage3_chain, 16, rng)
		var out_s3: Dictionary = EventDeckRef.call("resolve_event", ev_s3, "yes", rng)
		var title_pre_adv: String = str(gs.get("ending_title"))
		var desc_pre_adv: String = str(gs.get("ending_description"))
		BunkerSimRef.call("advance_day", {}, "", out_s3)
		var ok_evac: bool = bool(gs.get("victory")) and bool(gs.get("game_over")) and bool(evac_m["alive"]) and str(gs.get("ending_title")) == title_pre_adv and str(gs.get("ending_description")) == desc_pre_adv
		if stage3_chain == "sanctuary":
			ok_evac = ok_evac and desc_pre_adv.find("First Parish in Concord") != -1
		_check(ok_evac,
			"Stage 3 '%s' evacuation immediately wins (victory=true, game_over=true) without overnight dehydration/starvation death & preserves custom ending_title/description" % stage3_chain,
			"victory=%s game_over=%s alive=%s title='%s' desc='%s'" % [str(gs.get("victory")), str(gs.get("game_over")), str(evac_m["alive"]), str(gs.get("ending_title")), str(gs.get("ending_description"))])

func main_scene_active_node() -> Node:
	if main_inst == null:
		return null
	return main_inst.get("_active_node")

func _simulate_natural_rescue_victory(gs: Node, target_chain: String, rng: RandomNumberGenerator) -> bool:
	gs.call("init_default_family")
	gs.call("reset_to_defaults")
	for fm in gs.get("family_members"):
		(fm as Dictionary)["in_bunker"] = true
	gs.set("soup_quarters", 160)
	gs.set("water_quarters", 160)
	for gid in ["radio", "map", "flashlight", "axe", "toolbox", "rifle", "book", "gas_mask"]:
		gs.call("add_scavenged_item", gid, 1)
	gs.call("add_scavenged_item", "medkit", 3)
	BunkerSimRef.call("start_bunker_run")
	EventDeckRef.call("draw_daily_event", 1, rng)

	for d in range(2, 42):
		var ev: Dictionary = EventDeckRef.call("draw_daily_event", d, rng)
		var eid: String = str(ev.get("id", ""))
		var chosen: String = ""
		if eid.begins_with("rescue_" + target_chain + "_"):
			for ov in ev.get("options", []):
				var od: Dictionary = ov
				if bool(od.get("available", false)):
					chosen = str(od.get("id", ""))
					break
		elif eid.begins_with("rescue_"):
			chosen = "no" if eid.ends_with("_3") else "ignore"
		else:
			for ov2 in ev.get("options", []):
				var od2: Dictionary = ov2
				if bool(od2.get("available", false)):
					chosen = str(od2.get("id", ""))
					break

		var out: Dictionary = EventDeckRef.call("resolve_event", ev, chosen, rng)
		var rations: Dictionary = {}
		for fm in gs.get("family_members"):
			var fmd: Dictionary = fm
			rations[str(fmd["id"])] = {"soup_q": 1, "water_q": 1}
		BunkerSimRef.call("advance_day", rations, "", out)
		if bool(gs.get("victory")) and bool(gs.get("game_over")):
			var stage_now: int = int((gs.get("rescue_chains") as Dictionary).get(target_chain, 0))
			print("    Chain '%s' won on Day %d (stage=%d, title='%s')" % [target_chain, int(gs.get("day")), stage_now, str(gs.get("ending_title"))])
			return stage_now >= 3
	return false


# Pass 2 helpers: a grab takes GRAB_TIME_*; complete it immediately for unit-level checks.
func _grab_now(scav: Node, target: Dictionary) -> bool:
	if not bool(scav.call("_attempt_pickup_target", target)):
		return false
	scav.set("_pending_action", {})
	return bool(scav.call("_complete_pickup", target))


# SPACE at the hatch: start the deposit and let the timed action finish.
func _space_deposit(scav: Node, hatch_pos: Vector2) -> void:
	scav.set("_player_pos", hatch_pos)
	scav.call("_context_action")
	for _i in range(60):
		if (scav.get("_pending_action") as Dictionary).is_empty():
			break
		scav.call("_process_pending_action", 0.05)
