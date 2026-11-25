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
	# M1 (section 5): 16 core items; medkit takes 2 slots, the suitcase 3; checkers, harmonica and
	# the toolbox are gone.
	var expected_1_slot: Array[String] = [
		"food", "water", "gas_mask", "radio", "flashlight", "map",
		"manual", "ammo", "bug_spray", "padlock", "cards", "console"
	]
	var expected_2_slot: Array[String] = ["axe", "rifle", "medkit"]

	var all_ids: Array = ItemDBRef.call("get_all_item_ids")
	_check(all_ids.size() == 16, "ItemDB has exactly the 16 core items", "got %d" % all_ids.size())
	var sc_info: Dictionary = ItemDBRef.call("get_item_info", "suitcase")
	_check(int(sc_info.get("slots", -1)) == 3 and int((HouseGenRef.get("ITEM_META").get("suitcase", {}) as Dictionary).get("slots", -1)) == 3, "3-slot item 'suitcase' has slots=3 in ItemDB & HouseGenerator")

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
				if iid != "food" and iid != "water" and iid != "ammo":
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
	for two_id in ["suitcase", "axe", "rifle", "medkit", "food"]:
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
	var medkit_target: Dictionary = scav.call("_get_target_by_uid", "item", 9003)

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
	_check(ok_ax and ok_rf0 and int(scav.call("_get_used_slots")) == 7, "Suitcase (3) + Axe (2) + Rifle (2) = 7 slots in suitcase hands")
	_space_deposit(scav, hatch_pos_val)
	_check(bool(gs.call("has_working_item", "axe")) and bool(gs.call("has_working_item", "rifle")) and bool(scav.call("_is_carrying_item", "suitcase")),
		"SPACE at the hatch drops Axe & Rifle down the chute and keeps the suitcase in hand")

	var fam_elder_target: Dictionary = scav.call("_get_target_by_uid", "family", int((wf[1] as Dictionary)["uid"]))
	var ok_el: bool = _grab_now(scav, fam_elder_target)
	var ok_tb0: bool = _grab_now(scav, medkit_target)
	_check(ok_el and ok_tb0 and int(scav.call("_get_used_slots")) == 8, "Suitcase hands hold Suitcase (3) + Elder (3) + Medkit (2) = 8/8")
	_space_deposit(scav, hatch_pos_val)
	_check(bool((gs_fams[2] as Dictionary)["in_bunker"]) and bool(gs.call("has_working_item", "medkit")), "Elder and Medkit deposited cleanly")

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
	# M1 (section 3): recon look-around follows the difficulty (Normal 10 s); the grab is 60 s.
	_check(int(scav.get("_phase")) == 0 and is_equal_approx(float(scav.get("_scout_total")), float(gs.call("recon_seconds"))) and is_equal_approx(float(scav.get("_scavenge_total")), 60.0),
		"Starts in the recon phase (%.0fs on Normal) with exact 60.0s grab timer ready" % float(gs.call("recon_seconds")),
		"phase=%d scout_total=%.2f scav_total=%.2f" % [int(scav.get("_phase")), float(scav.get("_scout_total")), float(scav.get("_scavenge_total"))])

	var wi0: Array = scav.get("_world_items")
	var any_item: Dictionary = scav.call("_get_target_by_uid", "item", int((wi0[0] as Dictionary)["uid"]))
	_check(not bool(scav.call("_attempt_pickup_target", any_item)), "Cannot pick up items during SCOUT phase")

	for _step in range(int(ceil((float(gs.call("recon_seconds")) + 0.25) / 0.05))):
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
# 3. SHELTER SURVIVAL LOOP FIDELITY (M1 rules; each check replaces the pre-M1 one listed in brackets)
# =============================================================================
# Pre-M1 checks with no M1 counterpart (the rule itself is gone), kept here so none vanish silently:
#   - "Child role is a light eater": M1 rations are one food and one water per person per day; age
#     matters for trips ("Too young") and for the no-adult loss (3D), not for appetite.
#   - "Elder role is a wise morale anchor": roles carry no morale perk in M1; the Bookworm trait keeps
#     the morale floor (3J).
#   - "Mutant scares off raiders", "Mutant immune to thirst/sickness": the mutation perk is off (3F).
#   - "Harmonica charms raiders", "Pancake the Dog repels raiders": the harmonica left the item list
#     and pets don't fight in M1; raids are stopped by rifle, axe or padlock (4G).
#   - "EventDeck.reset_state clears the sanctuary cache": there is no cache; each run builds its
#     places and chains fresh (3L).
func _m1_run(members: Array, haul: Dictionary, seed_v: int, temp_c: float = 19.0) -> ShelterState:
	var places: Array = [
		{"osm_id": 501, "name": "Corner Market", "category": "grocery", "walk_m": 300.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 502, "name": "Town Church", "category": "church", "walk_m": 600.0, "lat": 0.0, "lon": 0.0},
		{"osm_id": 503, "name": "Lincoln School", "category": "school", "walk_m": 500.0, "lat": 0.0, "lon": 0.0},
	]
	return ShelterSim.new_run({"members": members, "haul": haul, "places": places, "rad_factors": [0.05, 0.05, 0.05],
		"h1_home_msv": 11500.0, "seed": seed_v, "temp_c": temp_c})


func _m1_member(id: String, name: String, role: String, age: int, trait_id: String = "") -> Dictionary:
	return {"id": id, "name": name, "role": role, "age": age, "trait": trait_id, "is_leader": id == "m0", "in_bunker": true, "alive": true}


func _m1_day(s: ShelterState, food: bool, water: bool, treat: Dictionary = {}) -> void:
	ShelterSim.begin_day(s)
	s.today_event = {}
	s.today_resolved = true
	var r: Dictionary = {}
	for m_v in s.home():
		r[str((m_v as Dictionary)["id"])] = {"food": food, "water": water}
	ShelterSim.end_day(s, {"rations": r, "treat": treat, "jobs": {}})


func _death_day(s: ShelterState, m: Dictionary, food: bool, water: bool, max_days: int) -> int:
	for _d in range(max_days):
		_m1_day(s, food, water)
		if not bool(m.get("alive", true)):
			return int(m.get("death_day", -1))
	return -1


func _audit_3_bunker_survival_math(gs: Node) -> void:
	print("\n--- SUITE 3: Shelter survival loop (M1 rules) ---")
	# [3A dehydration death day 7 -> M1: 50% roll on day 5 without water, certain death on day 6]
	var thirst_days: Array = []
	for trial in range(40):
		var s: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39)], {"food": 20}, 700 + trial)
		thirst_days.append(_death_day(s, s.members[0], true, false, 8))
	_check(thirst_days.min() >= 6 and thirst_days.max() <= 7, "No water: death roll on day 5, death certain on day 6 (died on days %s)" % str(thirst_days.slice(0, 8)))
	# [3B starvation death day 13 -> M1: day 10 without food]
	var sf: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39)], {"water": 30}, 711)
	var starve_day: int = _death_day(sf, sf.members[0], false, true, 12)
	_check(starve_day == 11, "No food: starving on day 8, dead on day 10 without food (died the morning of day %d)" % starve_day)
	# [3C quarter-ration recovery -> M1: one ration a day resets the counter]
	var rc: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"food": 5, "water": 5}, 712)
	var rm: Dictionary = rc.members[0]
	for _d in range(3):
		_m1_day(rc, false, false)
	var thirsty_before: bool = ShelterSim.status_labels(rm, rc.day).has("Thirsty")
	_m1_day(rc, true, true)
	_check(thirsty_before and int(rm["dww"]) == 0 and int(rm["dwf"]) == 0 and not ShelterSim.status_labels(rm, rc.day).has("Thirsty"),
		"A water and a food ration reset days without to 0 and clear Thirsty")
	var plan: Dictionary = ShelterSim.default_plan(rc)
	_check(plan["rations"]["m0"] is Dictionary and (plan["rations"]["m0"] as Dictionary).has("food") and (plan["rations"]["m0"] as Dictionary).has("water"),
		"The ration row is Give/Skip per person, starting from yesterday's choice")
	# [3D blast heat accelerates thirst -> M1: heat brings thirst forward one day; children alone lose]
	var cool: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"food": 9}, 713, 19.0)
	var hot: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"food": 9}, 713, 32.0)
	for _d in range(3):
		_m1_day(cool, true, false)
		_m1_day(hot, true, false)
	_check(int((hot.members[0] as Dictionary)["dww"]) == int((cool.members[0] as Dictionary)["dww"]) + 1, "Blast heat (32 °C) brings thirst forward one day versus a cool shelter")
	var guard: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m3", "Leo", "child", 9)], {}, 714)
	(guard.members[0] as Dictionary)["dww"] = 5
	(guard.members[0] as Dictionary)["dwf"] = 9
	_m1_day(guard, false, false)
	_check(not bool((guard.members[0] as Dictionary)["alive"]) and bool((guard.members[1] as Dictionary)["alive"]) and guard.ending == "loss_no_adult",
		"When only a child is left, the run ends (no adult to run the shelter)")
	# [3E medkit cures sickness & injury]
	var med: ShelterState = _m1_run([_m1_member("m0", "Priya", "adult", 39)], {"medkit": 2}, 715)
	var mm: Dictionary = med.members[0]
	ShelterSim.make_sick(med, mm, "test", "chance")
	ShelterSim.make_injured(med, mm, "test", "chance")
	_m1_day(med, false, false, {"m0": true})
	_check(not bool(mm["sick"]) and not bool(mm["injured"]) and med.count("medkit") == 1, "One medkit cures both sickness and injury")
	# [3F mutant transformation -> M1: the mutation perk is switched off (tone guide)]
	var mut: ShelterState = _m1_run([_m1_member("m0", "Maya", "teen", 16)], {"food": 20, "water": 20}, 716)
	ShelterSim.add_dose(mut.members[0], mut.day, 9000.0)
	for _d in range(4):
		_m1_day(mut, true, true)
	_check(not bool(gs.get("FEATURE_MUTATION")) and not bool((mut.members[0] as Dictionary).get("is_mutant", false)), "Radiation never turns anyone into a mutant (feature off); it causes radiation sickness instead")
	# [3G insanity breaks gear / abandons bunker -> M1: morale 0 means Withdrawn -> M2: morale 0 brings an
	#  affliction (Selfish, Paranoid, Reckless or Withdrawn) after a day's warning; a Withdrawn survivor won't go out]
	var wd: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39)], {"food": 8, "water": 8}, 717)
	ShelterSim.add_morale(wd, wd.members[1], -10, "")
	var warned: bool = str((wd.members[1] as Dictionary).get("affliction_next", "")) != "" and ShelterState.affliction(wd.members[1]) == ""
	(wd.members[1] as Dictionary)["affliction"] = "withdrawn"
	_check(warned and ShelterTrips.can_go(wd, wd.members[1]).begins_with("Withdrawn"), "At morale 0 a survivor is warned first, then afflicted; a Withdrawn one won't go out")
	# [3H repair via toolbox/book/handy -> M1: the survival manual repairs (85%, better for a Handy actor)]
	var fixed: int = 0
	for trial in range(100):
		var rp: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40, "handy")], {"manual": 1, "radio": 1}, 900 + trial)
		rp.break_one("radio")
		ShelterEvents._repair(rp, "radio", [], true)
		if rp.has("radio"):
			fixed += 1
	_check(fixed >= 85, "A Handy survivor repairs the radio with the manual (%d/100)" % fixed)
	# [3I pets adopted by soup / coaxing, upkeep, run away -> M1: pets come through events; the dog eats a ration every 3 days and leaves when there is none]
	var pet: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"food": 1, "water": 10, "bug_spray": 1}, 718)
	var gb: Dictionary = ShelterEvents._prepare(pet, ShelterData.event("good_boy"))
	pet.today_event = gb
	pet.today_resolved = false
	pet.today_options = ShelterEvents.options_for(pet, gb)
	ShelterSim.choose(pet, "spray")
	_check(pet.pets.has("dog") and not pet.has("bug_spray"), "Good Boy: bug spray de-fleas the dog and he moves in")
	pet.remove("food", 999)
	var left: bool = false
	for _d in range(12):
		ShelterSim.begin_day(pet)
		pet.today_event = {}
		pet.today_resolved = true
		ShelterSim.end_day(pet, {"rations": {"m0": {"food": false, "water": true}}, "treat": {}, "jobs": {}})
		if not pet.pets.has("dog"):
			left = true
			break
	_check(left, "With no food left, the dog slips out")
	# [3J age & trait promises -> M1 traits: Iron Stomach resists malnutrition sickness, Knows the Area finds extra, Optimist softens grief]
	var iron_sick: int = 0
	var plain_sick: int = 0
	for trial in range(200):
		for iron in [true, false]:
			var t: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40, "iron_stomach" if iron else "")], {"food": 20}, 1200 + trial)
			(t.members[0] as Dictionary)["dww"] = 3
			_m1_day(t, true, false)
			if bool((t.members[0] as Dictionary).get("sick", false)):
				if iron:
					iron_sick += 1
				else:
					plain_sick += 1
	_check(iron_sick < plain_sick, "Iron Stomach falls sick less often when dehydrated (%d vs %d of 200)" % [iron_sick, plain_sick])
	var og: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39, "optimist"), _m1_member("m2", "Maya", "teen", 16)], {}, 719)
	ShelterSim.record_death(og, og.members[2], "test", "chance")
	_check(int((og.members[0] as Dictionary)["morale"]) == ShelterData.Bi("morale_start", 7) - 2, "An Optimist at home softens the grief hit (−2 instead of −3)")
	var bw_after: Array = []
	for bw_trait in ["bookworm", ""]:
		var bw: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40, bw_trait)], {"water": 4}, 722)
		(bw.members[0] as Dictionary)["morale"] = 2
		(bw.members[0] as Dictionary)["dwf"] = 8
		_m1_day(bw, false, true)
		bw_after.append(int((bw.members[0] as Dictionary)["morale"]))
	_check(int(bw_after[0]) == 2 and int(bw_after[1]) == 1, "A starving Bookworm stays at morale 2 while others slip to 1 (%s)" % str(bw_after))
	var found_scout: int = 0
	var found_plain: int = 0
	for trial in range(30):
		for scout in [true, false]:
			var ka: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39, "scout" if scout else "")], {"suitcase": 1, "food": 10, "water": 10}, 1300 + trial)
			var before_units: int = 0
			for k in ka.stock.keys():
				before_units += int(ka.stock[k])
			ShelterTrips.launch(ka, ka.members[1], 0, ["suitcase"])
			(ka.trips[0] as Dictionary)["p_day"] = 0.0
			for _d in range(9):
				if str((ka.members[1] as Dictionary).get("loc", "")) != "away":
					break
				ShelterTrips.tick(ka)
				ka.day += 1
			var after_units: int = 0
			for k in ka.stock.keys():
				after_units += int(ka.stock[k])
			if scout:
				found_scout += after_units - before_units
			else:
				found_plain += after_units - before_units
	_check(found_scout > found_plain, "Knows the Area brings home more from the same 30 grocery trips (%d vs %d units)" % [found_scout, found_plain])
	# [3K expedition gear limit 1/4 -> M1: up to 3 pieces of gear; a dead explorer's gear is gone with them]
	var gl: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39)], {"map": 1, "gas_mask": 1, "suitcase": 1, "flashlight": 1, "food": 4, "water": 4}, 720)
	ShelterTrips.launch(gl, gl.members[1], 0, ["map", "gas_mask", "suitcase", "flashlight"])
	_check(((gl.trips[0] as Dictionary)["gear"] as Array).size() == 3 and gl.has("flashlight"), "An explorer packs at most 3 pieces of gear; the rest stays on the shelf")
	(gl.trips[0] as Dictionary)["p_day"] = 1.0
	for _d in range(6):
		_m1_day(gl, true, true)
	_check(not bool((gl.members[1] as Dictionary)["alive"]) and not gl.owns("map") and not gl.owns("suitcase"), "A lost explorer's gear is gone with them (no phantom 'checked out' gear)")
	# [3L POI depletion reset across runs -> M1: each run builds fresh stock for every place]
	var r1: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {}, 721)
	(r1.places[0]["stock"] as Dictionary).clear()
	var r2: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {}, 721)
	_check(ShelterTrips.stock_total(r2.places[0]) > 0, "A new run starts with fresh stock (a store emptied last run is full again)")


# =============================================================================
# 4. EVENTS & RESCUE CHAINS (M1: data/events/*.json; each check replaces the pre-M1 one in brackets)
# =============================================================================
func _audit_4_event_deck_and_rescue_chains(gs: Node) -> void:
	print("\n--- SUITE 4: Events & rescue chains (M1 data-driven events) ---")
	# [4A 61 hard-coded events -> M1: the data tables hold 70+ events and every one has 2-4 options]
	var evs: Dictionary = ShelterData.events()
	var bad_opts: int = 0
	for eid in evs.keys():
		var n: int = ((evs[eid] as Dictionary).get("options", []) as Array).size()
		if n < 2 or n > 4:
			bad_opts += 1
	_check(evs.size() >= 70 and bad_opts == 0, "The event tables hold %d events, each with 2-4 options" % evs.size())
	# [4B 320 draws -> M1: 40 days of draws across 8 runs are varied and never softlock]
	var unique: Dictionary = {}
	var draws: int = 0
	for trial in range(8):
		var s: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39), _m1_member("m3", "Leo", "child", 9)], {"food": 30, "water": 30, "medkit": 2}, 1500 + trial)
		for _d in range(40):
			ShelterSim.begin_day(s)
			if s.is_over():
				break
			if not s.today_event.is_empty():
				draws += 1
				unique[str(s.today_event["id"])] = true
				var pick: String = ""
				for o_v in s.today_options:
					if bool((o_v as Dictionary)["available"]):
						pick = str((o_v as Dictionary)["id"])
				ShelterSim.choose(s, pick)
			if s.is_over():
				break
			var rr: Dictionary = {}
			for m_v in s.home():
				rr[str((m_v as Dictionary)["id"])] = {"food": s.day % 5 == 0, "water": s.day % 2 == 0}
			ShelterSim.end_day(s, {"rations": rr, "treat": {}, "jobs": {}})
	_check(draws >= 100 and unique.size() >= 35, "%d draws over 8 runs hit %d different events; every day had an answerable option" % [draws, unique.size()])
	# [4C day-1 Civil Defense seal event -> M1: day 1 opens with a receipt naming who sealed the hatch and the stock]
	var d1: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"food": 2, "water": 3}, 1600)
	var morning: Dictionary = ShelterSim.begin_day(d1)
	_check(str(((morning["morning"] as Array)[0] as Dictionary)["text"]).find("Sam sealed the hatch") != -1, "Day 1 opens with who sealed the hatch and what's on the shelf")
	# [4D unavailable item options are rejected]
	var sg: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {}, 1601)
	var ev: Dictionary = ShelterEvents._prepare(sg, ShelterData.event("signature_required"))
	sg.today_event = ev
	sg.today_resolved = false
	sg.today_options = ShelterEvents.options_for(sg, ev)
	_check(ShelterSim.choose(sg, "shoot").is_empty() and not sg.today_resolved, "An item option without the item can't be chosen")
	# [4E morale moves both ways]
	var mo: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39)], {"console": 1}, 1602)
	var cf: Dictionary = ShelterEvents._prepare(mo, ShelterData.event("cabin_fever"))
	mo.today_event = cf
	mo.today_resolved = false
	mo.today_options = ShelterEvents.options_for(mo, cf)
	ShelterSim.choose(mo, "tournament")
	var up: int = int((mo.members[0] as Dictionary)["morale"])
	var mo2: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39)], {}, 1603)
	var cf2: Dictionary = ShelterEvents._prepare(mo2, ShelterData.event("cabin_fever"))
	mo2.today_event = cf2
	mo2.today_resolved = false
	mo2.today_options = ShelterEvents.options_for(mo2, cf2)
	ShelterSim.choose(mo2, "meeting")
	_check(up > ShelterData.Bi("morale_start", 7) and int((mo2.members[0] as Dictionary)["morale"]) < ShelterData.Bi("morale_start", 7), "Event morale moves both ways (console tournament up, family meeting down)")
	# [4F roaches / vent leak / trader -> M1: pests eat bug spray, the vent takes the gas mask, the water man takes ammo for water]
	var pe: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"bug_spray": 1, "gas_mask": 1, "ammo": 1, "water": 1}, 1604)
	for pair in [["uninvited", "spray"], ["dust_in_the_vent", "mask"], ["water_man", "ammo"]]:
		var e2: Dictionary = ShelterEvents._prepare(pe, ShelterData.event(str(pair[0])))
		pe.today_event = e2
		pe.today_resolved = false
		pe.today_options = ShelterEvents.options_for(pe, e2)
		ShelterSim.choose(pe, str(pair[1]))
	_check(not pe.has("bug_spray") and pe.has("gas_mask") and not pe.has("ammo") and pe.water() == 8, "Pests use up the bug spray, the mask reseals the vent, the water man trades ammo for a bottle")
	# [4G raider defence matrix -> M1: rifle+ammo, rifle bluff, axe and padlock each stop a raid as their rows say; an unstopped raid steals; a failed takeover ends the run]
	var rd: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"padlock": 1, "food": 5}, 1605)
	rd.followed = true
	ShelterSim._raid(rd)
	var rd2: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"food": 5}, 1606)
	rd2.followed = true
	ShelterSim._raid(rd2)
	var tk: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"food": 5}, 1607)
	tk.followed = true
	ShelterSim._takeover(tk)
	_check(not rd.owns("padlock") and rd.food() == 20 and rd2.food() == 16 and tk.ending == "loss_takeover", "Padlock stops a raid and is used up; an unstopped raid takes a can; an unstopped takeover loses the run")
	var rr: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"rifle": 1, "ammo": 2, "food": 5}, 1608)
	rr.followed = true
	ShelterSim._raid(rr)
	var ra: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {"axe": 1, "food": 5}, 1609)
	ra.followed = true
	ShelterSim._raid(ra)
	_check(rr.count("ammo") == 1 and rr.has("rifle") and rr.food() == 20 and not ra.has("axe") and ra.broken_count("axe") == 1 and ra.food() == 20,
		"Rifle + ammo stops a raid for one round; the axe stops one and breaks (nothing stolen either time)")
	# [4H three 3-stage chains reach victory -> M1: the convoy, neighbourhood and airlift chains each reach a rescue]
	for chain_name in ["convoy", "neighbourhood", "airlift"]:
		_check(_m1_chain_victory(chain_name), "Rescue chain '%s' reaches its rescue ending when every request is met" % chain_name)
	# [4I evacuation with a parched sole survivor & real church ending -> M1: a rescue still wins with one survivor left; the neighbourhood ending names the real place]
	var ev_s: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40)], {}, 1608)
	(ev_s.members[0] as Dictionary)["dww"] = 4
	ev_s.chains["neighbourhood"]["place_idx"] = 1
	ShelterChains.step(ev_s, "neighbourhood", "win", {})
	var info: Dictionary = ShelterSim.ending_info(ev_s)
	_check(ev_s.ending_kind == "win" and str(info["text"]).find("Town Church") != -1, "A rescue wins with one dehydrated survivor left, and the ending names the real place (%s)" % str(info["text"]))


## Drives one chain to its end: every request is answered with the needed item.
func _m1_chain_victory(chain_name: String) -> bool:
	var s: ShelterState = _m1_run([_m1_member("m0", "Sam", "adult", 40), _m1_member("m1", "Priya", "adult", 39)],
		{"food": 40, "water": 40, "radio": 1, "map": 1, "flashlight": 1, "gas_mask": 1, "medkit": 2}, 1700)
	for cid in s.chains.keys():
		(s.chains[cid] as Dictionary)["state"] = "idle"
	var c: Dictionary = s.chains[chain_name]
	c["state"] = "active"
	c["step"] = 1
	c["next_day"] = 1
	c["place_idx"] = 1
	s.fallout_clear_day = 1
	for _d in range(60):
		ShelterSim.begin_day(s)
		if s.is_over():
			break
		if not s.today_event.is_empty():
			var pick: String = ""
			for o_v in s.today_options:
				var o: Dictionary = o_v
				if bool(o["available"]) and (pick == "" or str(o["item"]) != ""):
					pick = str(o["id"])
			if s.today_event.has("chain") and bool(s.today_event.get("final", false)):
				pick = str((s.today_options[0] as Dictionary)["id"])
			ShelterSim.choose(s, pick)
		if s.is_over():
			break
		var r: Dictionary = {}
		for m_v in s.home():
			r[str((m_v as Dictionary)["id"])] = {"food": s.day % 4 == 0, "water": s.day % 2 == 0}
		ShelterSim.end_day(s, {"rations": r, "treat": {}, "jobs": {}})
	return s.ending == "rescue_" + chain_name


func main_scene_active_node() -> Node:
	if main_inst == null:
		return null
	return main_inst.get("_active_node")

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
