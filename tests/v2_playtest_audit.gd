extends SceneTree

## V2 Mandatory Playtesting, Save/Load & Balance Metrics Audit Suite
## Run with:
## /home/antigravity/.local/bin/godot --headless --path /home/antigravity/sixty_seconds_world -s res://tests/v2_playtest_audit.gd

var pass_count: int = 0
var fail_count: int = 0
var findings: Array[String] = []

var ItemDBRef: Script
var HouseGenRef: Script
var OsmServiceRef: Script
var ScavengeSceneRef: Script
var FamilyScreenRef: Script
var TitleScreenRef: Script
var SummaryScreenRef: Script
var BunkerSimRef: Script
var BunkerSceneRef: Script
var EventDeckRef: Script
var ExpeditionRef: Script
var RelationshipRef: Script
var NukePhysicsRef: Script

var main_inst: Node = null

# Backup & restore existing user:// save files so audit leaves workspace clean
var _had_save_run: bool = false
var _backup_save_run: String = ""
var _had_meta_profile: bool = false
var _backup_meta_profile: String = ""

# Quantitative telemetry accumulators
var diff_metrics: Dictionary = {}
var mode_metrics: Dictionary = {}
var all_window_stats: Array[Dictionary] = []
var dynamic_events_drawn: int = 0
var dynamic_events_ge3_total_opts: int = 0
var dynamic_events_ge3_avail_opts: int = 0
var dynamic_events_with_tradeoff: int = 0
var resource_violation_count: int = 0
var softlock_count: int = 0

func _init() -> void:
	call_deferred("_run_all_v2_audits")

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

func _backup_user_files(sm: Node) -> void:
	var save_path: String = str(sm.get("SAVE_RUN_PATH"))
	var meta_path: String = str(sm.get("META_PROFILE_PATH"))
	if FileAccess.file_exists(save_path):
		_had_save_run = true
		var f1 := FileAccess.open(save_path, FileAccess.READ)
		if f1 != null:
			_backup_save_run = f1.get_as_text()
			f1.close()
	if FileAccess.file_exists(meta_path):
		_had_meta_profile = true
		var f2 := FileAccess.open(meta_path, FileAccess.READ)
		if f2 != null:
			_backup_meta_profile = f2.get_as_text()
			f2.close()

func _restore_user_files(sm: Node) -> void:
	var save_path: String = str(sm.get("SAVE_RUN_PATH"))
	var meta_path: String = str(sm.get("META_PROFILE_PATH"))
	if _had_save_run:
		var f1 := FileAccess.open(save_path, FileAccess.WRITE)
		if f1 != null:
			f1.store_string(_backup_save_run)
			f1.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if _had_meta_profile:
		var f2 := FileAccess.open(meta_path, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(_backup_meta_profile)
			f2.close()
	elif FileAccess.file_exists(meta_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta_path))
	sm.call("load_meta")

func _run_all_v2_audits() -> void:
	await _wait_frames(2)
	ItemDBRef = load("res://scripts/core/item_db.gd")
	HouseGenRef = load("res://scripts/scavenge/house_generator.gd")
	OsmServiceRef = load("res://scripts/osm/osm_service.gd")
	ScavengeSceneRef = load("res://scripts/scavenge/scavenge_scene.gd")
	FamilyScreenRef = load("res://scripts/ui/family_screen.gd")
	TitleScreenRef = load("res://scripts/ui/title_screen.gd")
	SummaryScreenRef = load("res://scripts/ui/summary_screen.gd")
	BunkerSimRef = load("res://scripts/bunker/bunker_sim.gd")
	BunkerSceneRef = load("res://scripts/bunker/bunker_scene.gd")
	EventDeckRef = load("res://scripts/events/event_deck.gd")
	ExpeditionRef = load("res://scripts/expedition/expedition_engine.gd")
	RelationshipRef = load("res://scripts/family/relationship_system.gd")
	NukePhysicsRef = load("res://scripts/nuke/nuke_physics.gd")

	var main_packed: PackedScene = load("res://scenes/main.tscn")
	main_inst = main_packed.instantiate()
	root.add_child(main_inst)
	await _wait_frames(2)

	var gs: Node = root.get_node("GameState")
	var sm: Node = root.get_node("SaveManager")
	_backup_user_files(sm)

	# Reset meta profile cleanly for deterministic playtesting
	sm.set("meta", {
		"vehicle_chassis_tier": 0,
		"total_vehicle_parts_banked": 0,
		"unlocked_achievements": {},
		"unlocked_hats": ["none"],
		"runs_played": 0,
		"victories": 0,
		"longest_days": 0,
		"best_scavenge_items": 0
	})
	sm.call("clear_saved_run")

	print("=========================================================================")
	print("V2 MANDATORY PLAYTESTING, SAVE/LOAD & BALANCE METRICS AUDIT STARTING")
	print("=========================================================================")

	await _suite_1_playthroughs_and_modes(gs, sm)
	await _suite_2_all_5_victory_routes_and_vehicle_tiers(gs, sm)
	await _suite_3_relationships_and_left_behind(gs, sm)
	await _suite_4_save_load_and_accounting(gs, sm)

	_print_quantitative_report()

	print("=========================================================================")
	print("V2 AUDIT SUMMARY: %d PASSED | %d FAILED" % [pass_count, fail_count])
	for i in range(findings.size()):
		print("  DEFECT #%d: %s" % [i + 1, findings[i]])
	print("=========================================================================")

	_restore_user_files(sm)
	if is_instance_valid(main_inst):
		main_inst.queue_free()
	await _wait_frames(2)
	quit(0)

# =============================================================================
# SHARED HELPERS: RESOURCE ACCOUNTING & SMART PLAYER POLICY
# =============================================================================

func _verify_resource_invariants(gs: Node, context_tag: String) -> void:
	var bad: Array[String] = []
	for k in ["soup_quarters", "water_quarters", "ammo_count", "medkit_count", "bug_spray_count", "antibiotics_count", "antirad_count", "scrap_count", "fuel_cans"]:
		var val: int = int(gs.get(k))
		if val < 0:
			bad.append("%s=%d" % [k, val])
	var hull: float = float(gs.get("bunker_structural_integrity"))
	if not is_finite(hull) or hull < 0.0 or hull > 100.01:
		bad.append("hull=%.2f" % hull)
	var rad_sv: float = float(gs.get("surface_radiation_sv"))
	if not is_finite(rad_sv) or rad_sv < 0.0:
		bad.append("surface_sv=%.2f" % rad_sv)
	var rels: Dictionary = gs.get("relationships")
	for rk in rels.keys():
		var rv: int = int(rels[rk])
		if rv < -100 or rv > 100:
			bad.append("rel[%s]=%d" % [str(rk), rv])
	var fams: Array = gs.get("family_members")
	for fm_v in fams:
		if fm_v is Dictionary:
			var fm: Dictionary = fm_v
			if float(fm.get("radiation", 0.0)) < -0.001 or not is_finite(float(fm.get("radiation", 0.0))):
				bad.append("%s.rad=%s" % [str(fm.get("name", "?")), str(fm.get("radiation"))])
			for sk in ["hunger", "thirst", "sanity", "sickness", "injury", "fatigue", "days_without_water", "days_without_food", "breakdown_days"]:
				if int(fm.get(sk, 0)) < 0:
					bad.append("%s.%s=%d" % [str(fm.get("name", "?")), sk, int(fm.get(sk, 0))])
	if not bad.is_empty():
		resource_violation_count += bad.size()
		print("    [INVARIANT VIOLATION @ %s] %s" % [context_tag, ", ".join(bad)])

func _simulate_smart_scavenge(gs: Node, target_item_cap: int = 99, leave_one_behind: bool = false) -> Dictionary:
	# Runs ScavengeScene with demo_mode=false so REAL difficulty timers & scout bonuses execute!
	gs.set("demo_mode", false)
	var scav: Node2D = ScavengeSceneRef.new()
	root.add_child(scav)

	var scout_total: float = float(scav.get("_scout_total"))
	var scav_total: float = float(scav.get("_scavenge_total"))
	var spawned_soup: int = 0
	var spawned_water: int = 0
	for it_v in (scav.get("_world_items") as Array):
		var it: Dictionary = it_v
		if str(it.get("item_id", "")) == "soup":
			spawned_soup += 1
		elif str(it.get("item_id", "")) == "water":
			spawned_water += 1

	# Tick through SCOUT phase
	var guard_scout: int = 0
	while int(scav.get("_phase")) == 0 and guard_scout < 800:
		scav.call("_process", 0.05)
		guard_scout += 1

	# Drive SCAVENGE phase using smart priority navigation + manual click/pickup/dive APIs
	var wp_list: Array[Vector2] = []
	var wp_idx: int = 0
	var cur_goal_uid: int = -999
	var cur_goal_kind: String = ""
	var attempt_t: float = 0.0
	var blacklist: Dictionary = {}

	var guard_scav: int = 0
	while int(scav.get("_phase")) == 1 and guard_scav < 3000:
		var dt: float = 0.04
		var time_left: float = float(scav.get("_scavenge_time_left"))
		var ppos: Vector2 = scav.get("_player_pos")
		var hpos: Vector2 = scav.get("_hatch_pos")
		var hrad: float = float(scav.get("_hatch_radius"))
		var cur_spd: float = float(scav.call("_compute_move_speed"))
		var max_slots: int = int(scav.get("_max_slots"))
		var used_slots: int = int(scav.call("_get_used_slots"))
		var free_slots: int = max_slots - used_slots
		var items_dep: int = int(scav.get("_items_deposited_count"))

		for bk in blacklist.keys():
			blacklist[bk] = float(blacklist[bk]) - dt
			if float(blacklist[bk]) <= 0.0:
				blacklist.erase(bk)

		# Opportunistic grab of 1-slot high-value items while passing by if spare slot exists
		if free_slots >= 1 and items_dep < target_item_cap:
			for it_v in (scav.get("_world_items") as Array):
				var it: Dictionary = it_v
				if bool(it.get("collected", false)):
					continue
				var sl: int = int(it["slots"])
				var reserve: int = 0
				if cur_goal_kind == "family" or cur_goal_kind == "item":
					var gt: Dictionary = scav.call("_get_target_by_uid", cur_goal_kind, cur_goal_uid)
					if not gt.is_empty():
						reserve = int(gt.get("slots", 1))
				if sl <= (free_slots - reserve) and ppos.distance_to(it["pos"]) <= 46.0:
					scav.call("_attempt_pickup_target", {
						"kind": "item",
						"uid": int(it["uid"]),
						"pos": it["pos"],
						"slots": sl,
						"name": str(it["name"]),
						"item_id": str(it["item_id"]),
						"ref": it
					})
					break

		used_slots = int(scav.call("_get_used_slots"))
		free_slots = max_slots - used_slots

		var dist_home: float = ppos.distance_to(hpos)
		var return_sec: float = (dist_home / maxf(cur_spd, 130.0)) * 1.65 + 3.4
		var cap_reached: bool = items_dep >= target_item_cap
		var house_done: bool = (int(scav.call("_count_remaining_world_items")) == 0 and int(scav.call("_count_remaining_world_family")) == 0)
		var go_home: bool = (time_left <= maxf(4.5, return_sec)) or house_done or cap_reached

		var target_pos: Vector2 = hpos
		if go_home:
			if dist_home <= hrad + 14.0 and (scav.get("_carried_entries") as Array).is_empty():
				if bool(scav.call("_can_dive_into_bunker")) and (time_left <= 3.0 or house_done or cap_reached):
					scav.call("trigger_hud_dive_in")
					break
			cur_goal_kind = "hatch"
			cur_goal_uid = -1
		else:
			var carrying_suitcase: bool = bool(scav.call("_is_carrying_item", "suitcase"))
			var next_pick: Dictionary = _pick_smart_scavenge_target(scav, free_slots, blacklist, leave_one_behind)
			if free_slots <= 0 or next_pick.is_empty() or (carrying_suitcase and used_slots >= 3):
				cur_goal_kind = "hatch"
				cur_goal_uid = -1
				target_pos = hpos
			else:
				var active_t: Dictionary = scav.call("_get_target_by_uid", cur_goal_kind, cur_goal_uid)
				if active_t.is_empty() or int(active_t.get("slots", 1)) > free_slots or blacklist.has(cur_goal_uid):
					active_t = next_pick
					cur_goal_kind = str(active_t["kind"])
					cur_goal_uid = int(active_t["uid"])
					attempt_t = 0.0
					wp_list.clear()
				target_pos = active_t["pos"]
				if ppos.distance_to(target_pos) <= 46.0:
					if bool(scav.call("_attempt_pickup_target", active_t)):
						cur_goal_kind = ""
						cur_goal_uid = -1
						wp_list.clear()
				attempt_t += dt
				if attempt_t > 4.2 and cur_goal_uid >= 0:
					blacklist[cur_goal_uid] = 6.5
					cur_goal_kind = ""
					cur_goal_uid = -1
					wp_list.clear()

		if wp_list.is_empty() or wp_list[wp_list.size() - 1].distance_to(target_pos) > 20.0:
			wp_list = scav.call("_compute_nav_path", ppos, target_pos)
			wp_idx = 0
		while wp_idx < wp_list.size() - 1 and ppos.distance_to(wp_list[wp_idx]) <= 20.0:
			wp_idx += 1
		var step_goal: Vector2 = wp_list[wp_idx] if (wp_idx >= 0 and wp_idx < wp_list.size()) else target_pos
		scav.set("_has_click_target", true)
		scav.set("_click_target_pos", step_goal)
		scav.set("_click_pickup_kind", "")
		scav.set("_click_pickup_uid", -1)

		scav.call("_process", dt)
		guard_scav += 1

	# Finish outro
	var guard_outro: int = 0
	while not bool(scav.get("_outro_transitioned")) and guard_outro < 100:
		scav.call("_process", 0.05)
		guard_outro += 1

	var summary: Dictionary = {
		"scout_total": scout_total,
		"scavenge_total": scav_total,
		"spawned_soup": spawned_soup,
		"spawned_water": spawned_water,
		"items_deposited": int(scav.get("_items_deposited_count")),
		"family_deposited": int(scav.get("_family_deposited_count")),
		"max_slots_end": int(scav.get("_max_slots")),
		"leader_escaped": not bool(scav.get("_leader_caught_outside"))
	}
	if is_instance_valid(scav):
		scav.queue_free()
	return summary

func _pick_smart_scavenge_target(scav: Node2D, free_slots: int, blacklist: Dictionary, leave_one_behind: bool) -> Dictionary:
	if free_slots <= 0:
		return {}
	var ppos: Vector2 = scav.get("_player_pos")
	var best_score: float = -1.0e9
	var best: Dictionary = {}

	var wf: Array = scav.get("_world_family")
	var skipped_last_fam: int = int((wf[wf.size() - 1] as Dictionary)["uid"]) if (leave_one_behind and not wf.is_empty()) else -9999
	for f_v in wf:
		var fam: Dictionary = f_v
		var uid: int = int(fam["uid"])
		if uid == skipped_last_fam or bool(fam.get("collected", false)) or blacklist.has(uid):
			continue
		var f_slots: int = int(fam["slots"])
		if f_slots > free_slots:
			continue
		var score: float = 240.0 - ppos.distance_to(fam["pos"]) * 0.14
		if score > best_score:
			best_score = score
			best = {"kind": "family", "uid": uid, "pos": fam["pos"], "slots": f_slots, "name": str(fam["name"]), "ref": fam}

	var soup_n: int = int(scav.call("_count_total_secured_or_carried", "soup"))
	var water_n: int = int(scav.call("_count_total_secured_or_carried", "water"))
	var has_weap: bool = int(scav.call("_count_total_secured_or_carried", "rifle")) > 0 or int(scav.call("_count_total_secured_or_carried", "axe")) > 0
	for it_v in (scav.get("_world_items") as Array):
		var it: Dictionary = it_v
		var uid2: int = int(it["uid"])
		if bool(it.get("collected", false)) or blacklist.has(uid2):
			continue
		var sl: int = int(it["slots"])
		if sl > free_slots:
			continue
		var iid: String = str(it["item_id"])
		var owned: int = int(scav.call("_count_total_secured_or_carried", iid))
		var prio: float = 110.0
		match iid:
			"suitcase":
				prio = 285.0 if owned == 0 else 75.0
			"gas_mask":
				prio = 220.0 if owned == 0 else 90.0
			"radio":
				prio = 205.0 if owned == 0 else 85.0
			"medkit":
				prio = 200.0 if owned == 0 else 135.0
			"water":
				prio = (196.0 - float(water_n) * 6.5) if water_n < 5 else 132.0
			"soup":
				prio = (192.0 - float(soup_n) * 6.5) if soup_n < 5 else 130.0
			"rifle", "axe":
				prio = 184.0 if not has_weap else 105.0
			"map", "toolbox", "book", "flashlight":
				prio = 172.0 if owned == 0 else 90.0
			"padlock", "ammo", "bug_spray":
				prio = 145.0
			_:
				prio = 118.0 if owned == 0 else 82.0
		var sc: float = prio - ppos.distance_to(it["pos"]) * 0.16
		if sc > best_score:
			best_score = sc
			best = {"kind": "item", "uid": uid2, "pos": it["pos"], "slots": sl, "name": str(it["name"]), "item_id": iid, "ref": it}
	return best

func _pick_smart_event_choice(gs: Node, ev: Dictionary, pursue_rescues: bool) -> String:
	var ev_id: String = str(ev.get("id", ""))
	var opts: Array = ev.get("options", [])
	var avail_ids: Array[String] = []
	for o_v in opts:
		if o_v is Dictionary and bool((o_v as Dictionary).get("available", false)):
			avail_ids.append(str((o_v as Dictionary).get("id", "")))
	if avail_ids.is_empty():
		softlock_count += 1
		return "ignore"

	# Stage-3 final rescue victory yes/no
	if ev_id in ["rescue_military_3", "rescue_sanctuary_3", "rescue_scientist_3", "rescue_raider_pact_3"]:
		if pursue_rescues and avail_ids.has("yes"):
			return "yes"
		if not pursue_rescues and avail_ids.has("no"):
			return "no"

	# Rescue stage 1 & 2 priority choices
	if pursue_rescues and ev_id.begins_with("rescue_"):
		for pref in ["use_radio", "use_map", "use_flashlight", "use_axe", "use_toolbox", "use_rifle", "use_book", "adopt_soup", "give_water", "give_soup", "use_medkit", "give_fuel", "use_scrap", "use_antibiotics", "use_harmonica", "give_ammo", "send_note", "help_hands", "push_rig", "tap_pipes", "wave_arms", "adopt_pet", "flash_mirror"]:
			if avail_ids.has(pref):
				# Avoid giving last water/soup if critically low
				if pref == "give_water" and int(gs.get("water_quarters")) < 8:
					continue
				if pref == "give_soup" and int(gs.get("soup_quarters")) < 8:
					continue
				return pref

	# Prefer [COOPERATE] options when unlocked!
	for o_v in opts:
		if o_v is Dictionary:
			var od: Dictionary = o_v
			if bool(od.get("available", false)) and str(od.get("label", "")).find("[COOPERATE]") != -1:
				return str(od.get("id", ""))

	# Raider defense priority
	if ev_id == "raiders_blast_hatch" or ev_id == "vendetta_reprisal_raid":
		for r_pref in ["use_mutant", "use_dog", "use_rifle", "use_rifle_ammo", "use_axe", "use_harmonica", "use_padlock"]:
			if avail_ids.has(r_pref):
				return r_pref

	# Delayed positive investments when affordable
	if ev_id == "stranger_wounded_courier":
		if avail_ids.has("help_medkit") and int(gs.get("medkit_count")) >= 2:
			return "help_medkit"
		if avail_ids.has("help_rations") and int(gs.get("water_quarters")) >= 8 and int(gs.get("soup_quarters")) >= 8:
			return "help_rations"
	if ev_id == "stranger_desperate_tinker":
		if avail_ids.has("lend_scrap"):
			return "lend_scrap"
		if avail_ids.has("give_water") and int(gs.get("water_quarters")) >= 8:
			return "give_water"
	if ev_id == "mystery_seed_tin":
		if avail_ids.has("plant_tray") and int(gs.get("water_quarters")) >= 10:
			return "plant_tray"
		if avail_ids.has("eat_seeds_now"):
			return "eat_seeds_now"
	if ev_id == "unsealed_munitions_crate":
		if avail_ids.has("use_toolbox_disarm"):
			return "use_toolbox_disarm"
		if avail_ids.has("fire_signal_beacon"):
			return "fire_signal_beacon"
	if ev_id == "stranger_chemist_vial" and avail_ids.has("store_honestly"):
		return "store_honestly"

	# Prefer item-backed options that don't drain scarce rations
	for o_v in opts:
		if o_v is Dictionary:
			var od2: Dictionary = o_v
			if not bool(od2.get("available", false)):
				continue
			var iid: String = str(od2.get("item_id", ""))
			var oid: String = str(od2.get("id", ""))
			if iid != "" and not (iid in ["soup", "water", "medkit", "antibiotics", "antirad"]):
				return oid

	# Positive family reconciliation options
	for f_pref in ["leader_apologize", "encourage_truce", "praise_both", "swap_tales", "hang_watch", "accept_basket", "claim_drop", "install_gift", "harvest_feast", "recover_pod", "collect_share", "haul_one", "sprint_grab", "tap_antenna", "roll_call"]:
		if avail_ids.has(f_pref):
			return f_pref

	# Safe fallback (usually last non-destructive option)
	for safe_id in ["ignore", "decline", "no", "send_away", "turn_away", "leave_crate", "refuse_storage", "pass_by", "skip_pump", "leave_parcel", "burn_map", "wave_on"]:
		if avail_ids.has(safe_id):
			return safe_id
	return avail_ids[0]

func _build_smart_turn_decisions(gs: Node, selfish_policy: bool, visited_categories: Dictionary, pursue_vehicle: bool) -> Dictionary:
	var living: Array = gs.call("get_living_bunker_members")
	var soup_avail: int = int(gs.get("soup_quarters"))
	var water_avail: int = int(gs.get("water_quarters"))
	var rations: Dictionary = {}

	# Sort by urgency (or Leader-first if selfish_policy)
	var ordered: Array = living.duplicate()
	if selfish_policy:
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return bool(a.get("is_leader", false)) and not bool(b.get("is_leader", false))
		)
	else:
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("days_without_water", 0)) * 3 + int(a.get("days_without_food", 0)) > int(b.get("days_without_water", 0)) * 3 + int(b.get("days_without_food", 0))
		)

	for m_v in ordered:
		var m: Dictionary = m_v
		var mid: String = str(m.get("id", ""))
		var is_mut: bool = bool(m.get("is_mutant", false))
		var dww: int = int(m.get("days_without_water", 0))
		var dwf: int = int(m.get("days_without_food", 0))
		var t_lvl: int = int(m.get("thirst", 0))
		var h_lvl: int = int(m.get("hunger", 0))

		var wq: int = 0
		var sq: int = 0
		if not is_mut:
			if dww >= 3 or t_lvl >= 2 or (water_avail >= living.size() * 3 and t_lvl >= 1):
				if water_avail >= 1:
					wq = 1
					water_avail -= 1
			elif selfish_policy and bool(m.get("is_leader", false)) and water_avail >= 2 and int(gs.get("day")) % 4 == 2:
				wq = 1
				water_avail -= 1

		if dwf >= 5 or h_lvl >= 2 or (soup_avail >= living.size() * 3 and h_lvl >= 1):
			if soup_avail >= 1:
				sq = 1
				soup_avail -= 1
		elif float(gs.get("bunker_temp_c")) < 0.0 and h_lvl >= 1 and soup_avail >= 1:
			sq = 1
			soup_avail -= 1
		elif selfish_policy and bool(m.get("is_leader", false)) and soup_avail >= 2 and int(gs.get("day")) % 5 == 3:
			sq = 1
			soup_avail -= 1

		rations[mid] = {"soup_q": sq, "water_q": wq}

	# Specialty & Medical care
	var medkit_tid: String = ""
	var spec: Dictionary = {}
	var abx_targets: Array[String] = []
	var ar_targets: Array[String] = []

	for m_v in living:
		var m: Dictionary = m_v
		var mid: String = str(m.get("id", ""))
		var sick: int = int(m.get("sickness", 0))
		var inj: int = int(m.get("injury", 0))
		var rad: float = float(m.get("radiation", 0.0))
		var bd: int = int(m.get("breakdown_days", 0))

		if bd > 0 and not spec.has("comfort_target_id"):
			spec["comfort_target_id"] = mid

		if rad >= 30.0 and int(gs.get("antirad_count")) > ar_targets.size():
			ar_targets.append(mid)

		if sick >= 1 and int(gs.get("antibiotics_count")) > abx_targets.size():
			abx_targets.append(mid)
		elif (sick >= 2 or inj >= 2 or (sick >= 1 and inj >= 1)) and medkit_tid == "" and int(gs.get("medkit_count")) > 0:
			medkit_tid = mid

	if not abx_targets.is_empty():
		spec["antibiotics_target_id"] = abx_targets
	if not ar_targets.is_empty():
		spec["antirad_target_id"] = ar_targets

	# Scrap repairs & hull reinforcement
	if int(gs.get("scrap_count")) > 0:
		var b_items: Dictionary = gs.get("bunker_items")
		for priority_gid in ["gas_mask", "radio", "toolbox", "rifle", "axe", "map", "suitcase", "flashlight"]:
			if b_items.has(priority_gid):
				var be: Dictionary = b_items[priority_gid]
				if bool(be.get("owned", false)) and bool(be.get("broken", false)):
					spec["use_scrap_repair_id"] = priority_gid
					break
		if not spec.has("use_scrap_repair_id") and float(gs.get("bunker_structural_integrity")) < 65.0:
			spec["use_scrap_hull"] = true

	# Vehicle tuning & breakout check
	if pursue_vehicle:
		if not bool(gs.get("vehicle_tuned")) and (bool(gs.call("has_working_item", "toolbox")) or bool(gs.call("has_working_item", "book")) or int(gs.get("scrap_count")) >= 2):
			spec["tune_vehicle"] = true
		if bool(gs.call("can_escape_by_vehicle")):
			spec["escape_vehicle"] = true

	# Multi-Ring Expedition Planning (Ring 1, Ring 2, Ring 3 across all landmark categories!)
	var exp_launch: Dictionary = {}
	var active_exp: Dictionary = gs.get("active_expedition")
	var surface_sv: float = float(gs.get("surface_radiation_sv"))
	var has_mask: bool = bool(gs.call("has_working_item", "gas_mask"))

	if active_exp.is_empty() and (has_mask or surface_sv <= 3.2 or int(gs.get("water_quarters")) <= 4):
		# Pick healthiest adult/teen explorer (keep at least 1 guardian inside if 2+ members, or allow solo explorer!)
		var best_exp: Dictionary = {}
		var best_exp_score: float = -999.0
		for m_v in living:
			var m: Dictionary = m_v
			var role_s: String = str(m.get("role", "adult")).to_lower()
			var age_i: int = int(m.get("age", 30))
			if role_s == "child" or age_i < 13:
				continue
			if not bool(ExpeditionRef.call("can_member_expedition", m)):
				continue
			# Check leaving bunker won't strand a child without guardian
			var others_have_guardian: bool = true
			if living.size() >= 2:
				var any_other_child: bool = false
				var any_other_guard: bool = false
				for o_v in living:
					var o: Dictionary = o_v
					if str(o.get("id", "")) == str(m.get("id", "")):
						continue
					if str(o.get("role", "")) == "child" or int(o.get("age", 30)) < 13:
						any_other_child = true
					else:
						any_other_guard = true
				if any_other_child and not any_other_guard:
					others_have_guardian = false
			if not others_have_guardian:
				continue
			if int(m.get("thirst", 0)) >= 2 or int(m.get("hunger", 0)) >= 2 or int(m.get("injury", 0)) >= 2 or int(m.get("sickness", 0)) >= 2:
				continue

			var sc_m: float = 20.0
			if bool(m.get("is_mutant", false)):
				sc_m += 40.0
			if str(m.get("trait", "")) == "scout":
				sc_m += 18.0
			sc_m -= float(int(m.get("fatigue", 0)) * 8 + int(m.get("injury", 0)) * 10 + int(m.get("sickness", 0)) * 10)
			if sc_m > best_exp_score:
				best_exp_score = sc_m
				best_exp = m

		if not best_exp.is_empty():
			var targets: Array = ExpeditionRef.call("get_available_targets")
			var best_idx: int = -1
			var best_t_score: float = -999.0
			var need_rations: bool = (int(gs.get("water_quarters")) <= 10 or int(gs.get("soup_quarters")) <= 10)
			var need_meds: bool = (int(gs.get("medkit_count")) + int(gs.get("antibiotics_count")) == 0)

			for ti in range(targets.size()):
				var td: Dictionary = targets[ti]
				if bool(td.get("depleted", false)):
					continue
				var cat: String = str(td.get("category", "neighbor_house"))
				var ring: int = int(td.get("ring", 1))
				var t_sc: float = 15.0

				if need_rations and cat in ["grocery", "neighbor_house", "church"]:
					t_sc += 42.0 if cat == "grocery" else 26.0
				elif need_meds and cat in ["doctor", "pharmacy", "church"]:
					t_sc += 40.0
				elif pursue_vehicle and (int(gs.call("get_vehicle_parts_owned_count")) < 4 or int(gs.get("fuel_cans")) < int(gs.get("fuel_needed"))) and cat in ["fuel_auto", "hardware"]:
					t_sc += 45.0
				elif cat in ["church", "civic", "doctor", "pharmacy", "fuel_auto", "hardware", "grocery", "school"]:
					t_sc += 24.0

				if not visited_categories.has(cat):
					t_sc += 18.0
				if ring == 2 and int(gs.get("day")) >= 4:
					t_sc += 10.0
				elif ring == 3 and int(gs.get("day")) >= 7 and (has_mask or surface_sv < 2.2):
					t_sc += 14.0
				elif ring >= 2 and not has_mask and surface_sv > 4.0:
					t_sc -= 25.0

				t_sc -= float(int(td.get("visited_count", 0))) * 14.0
				if t_sc > best_t_score:
					best_t_score = t_sc
					best_idx = ti

			if best_idx >= 0:
				var gear: Array[String] = []
				if bool(gs.call("has_working_item", "suitcase")):
					gear.append("suitcase")
					for g_opt in ["gas_mask", "rifle", "axe", "map", "flashlight"]:
						if gear.size() >= 4:
							break
						if g_opt == "axe" and gear.has("rifle"):
							continue
						if bool(gs.call("has_working_item", g_opt)):
							gear.append(g_opt)
				else:
					if has_mask and surface_sv >= 2.0:
						gear.append("gas_mask")
					elif bool(gs.call("has_working_item", "rifle")):
						gear.append("rifle")
					elif bool(gs.call("has_working_item", "axe")):
						gear.append("axe")
					elif bool(gs.call("has_working_item", "flashlight")):
						gear.append("flashlight")
				exp_launch = {
					"member_id": str(best_exp["id"]),
					"poi_index": best_idx,
					"gear_ids": gear
				}

	return {
		"rations": rations,
		"medkit_target": medkit_tid,
		"specialty": spec,
		"expedition": exp_launch
	}

func _event_has_nontrivial_tradeoff(ev: Dictionary) -> bool:
	var opts: Array = ev.get("options", [])
	if opts.size() < 2:
		return false
	for o_v in opts:
		if o_v is Dictionary:
			var od: Dictionary = o_v
			var iid: String = str(od.get("item_id", ""))
			var lbl: String = str(od.get("label", "")).to_lower()
			if iid != "" or lbl.find("[cooperate]") != -1 or lbl.find("risk") != -1 or lbl.find("trade") != -1 or lbl.find("share") != -1 or lbl.find("siphon") != -1:
				return true
	return str(ev.get("type", "")) == "yes_no"

func _classify_run_defeat_cause(gs: Node) -> String:
	var route: String = str(gs.get("ending_route"))
	var title: String = str(gs.get("ending_title")).to_lower()
	if route == "breached" or title.find("overrun") != -1 or title.find("breach") != -1:
		return "raider_or_hull_breach"
	if route == "no_guardian" or title.find("guardian") != -1:
		return "no_adult_guardian"
	if route == "silent_shelter" or title.find("atomic blast") != -1:
		return "caught_in_60s_blast"

	# Inspect last member death reason
	var fams: Array = gs.get("family_members")
	var last_reason: String = ""
	for fm_v in fams:
		if fm_v is Dictionary:
			var dr: String = str((fm_v as Dictionary).get("death_reason", "")).to_lower()
			if dr != "" and dr.find("left behind") == -1 and dr.find("caught above") == -1:
				last_reason = dr
	if last_reason.find("dehydration") != -1:
		return "dehydration"
	if last_reason.find("starvation") != -1:
		return "starvation"
	if last_reason.find("fever") != -1 or last_reason.find("sickness") != -1:
		return "sickness"
	if last_reason.find("injur") != -1 or last_reason.find("wound") != -1:
		return "injury"
	if last_reason.find("betrayed") != -1:
		return "hostile_betrayal"
	if last_reason.find("cabin fever") != -1 or last_reason.find("vanished") != -1:
		return "insanity_desertion"
	if last_reason.find("raiders") != -1:
		return "expedition_ambush"
	return "attrition_other"

func _compute_window_repeat_stats(drawn_ids: Array[String]) -> Dictionary:
	# Check all 25-day windows AND 16-day non-repeat buffer compliance
	var win_len: int = mini(25, drawn_ids.size())
	var total_in_windows: int = 0
	var repeats_25d_all: int = 0
	var repeats_25d_non_rescue: int = 0
	var buffer_16d_violations_all: int = 0
	var buffer_16d_violations_non_rescue: int = 0

	if drawn_ids.size() >= 2:
		var num_windows: int = maxi(1, drawn_ids.size() - win_len + 1)
		for w0 in range(num_windows):
			var w_end: int = mini(drawn_ids.size(), w0 + win_len)
			var seen_all: Dictionary = {}
			var seen_nr: Dictionary = {}
			for idx in range(w0, w_end):
				var eid: String = drawn_ids[idx]
				total_in_windows += 1
				if seen_all.has(eid):
					repeats_25d_all += 1
				seen_all[eid] = true
				if not eid.begins_with("rescue_"):
					if seen_nr.has(eid):
						repeats_25d_non_rescue += 1
					seen_nr[eid] = true

		for i in range(drawn_ids.size()):
			var cur_id: String = drawn_ids[i]
			var lookback_start: int = maxi(0, i - 16)
			for j in range(lookback_start, i):
				if drawn_ids[j] == cur_id:
					buffer_16d_violations_all += 1
					if not cur_id.begins_with("rescue_"):
						buffer_16d_violations_non_rescue += 1
					break

	return {
		"draws": drawn_ids.size(),
		"total_in_25d_windows": total_in_windows,
		"repeats_25d_all": repeats_25d_all,
		"repeats_25d_non_rescue": repeats_25d_non_rescue,
		"buffer_16d_violations_all": buffer_16d_violations_all,
		"buffer_16d_violations_non_rescue": buffer_16d_violations_non_rescue
	}

func _run_bunker_playthrough(
	gs: Node,
	max_days: int,
	pursue_rescues: bool,
	pursue_vehicle: bool,
	selfish_policy: bool
) -> Dictionary:
	BunkerSimRef.call("start_bunker_run")
	_verify_resource_invariants(gs, "day1_start")

	var drawn_ids: Array[String] = []
	var visited_cats: Dictionary = {}
	var ring_counts: Dictionary = {1: 0, 2: 0, 3: 0}
	var abx_used: int = 0
	var ar_used: int = 0
	var med_used: int = 0

	var guard_days: int = 0
	while not bool(gs.get("game_over")) and int(gs.get("day")) < max_days and guard_days < max_days:
		var cur_day: int = int(gs.get("day"))
		var gs_rng: RandomNumberGenerator = gs.get("rng")
		var ev_out: Dictionary = {}

		if not (gs.call("get_living_bunker_members") as Array).is_empty():
			var ev: Dictionary = EventDeckRef.call("draw_daily_event", cur_day, gs_rng)
			var eid: String = str(ev.get("id", ""))
			drawn_ids.append(eid)

			var opts: Array = ev.get("options", [])
			var avail_n: int = 0
			for o_v in opts:
				if o_v is Dictionary and bool((o_v as Dictionary).get("available", false)):
					avail_n += 1
			dynamic_events_drawn += 1
			if opts.size() >= 3:
				dynamic_events_ge3_total_opts += 1
			if avail_n >= 3:
				dynamic_events_ge3_avail_opts += 1
			if _event_has_nontrivial_tradeoff(ev):
				dynamic_events_with_tradeoff += 1
			if avail_n == 0:
				softlock_count += 1

			var choice: String = _pick_smart_event_choice(gs, ev, pursue_rescues)
			ev_out = EventDeckRef.call("resolve_event", ev, choice, gs_rng)
			_verify_resource_invariants(gs, "post_event_d%d_%s" % [cur_day, eid])

			if bool(gs.get("game_over")):
				# Finalize win/loss day transition through BunkerSim.advance_day just like BunkerScene._on_curtain_midpoint!
				BunkerSimRef.call("advance_day", {}, "", ev_out, {}, {})
				_verify_resource_invariants(gs, "post_gameover_advance_d%d" % cur_day)
				break

		var plan: Dictionary = _build_smart_turn_decisions(gs, selfish_policy, visited_cats, pursue_vehicle)
		var spec_d: Dictionary = plan["specialty"]
		if str(plan["medkit_target"]) != "":
			med_used += 1
		if spec_d.has("antibiotics_target_id"):
			abx_used += (spec_d["antibiotics_target_id"] as Array).size()
		if spec_d.has("antirad_target_id"):
			ar_used += (spec_d["antirad_target_id"] as Array).size()

		var exp_d: Dictionary = plan["expedition"]
		if not exp_d.is_empty():
			var targets: Array = ExpeditionRef.call("get_available_targets")
			var pidx: int = int(exp_d.get("poi_index", 0))
			if pidx >= 0 and pidx < targets.size():
				var td: Dictionary = targets[pidx]
				var c_str: String = str(td.get("category", "neighbor_house"))
				var r_int: int = int(td.get("ring", 1))
				visited_cats[c_str] = int(visited_cats.get(c_str, 0)) + 1
				ring_counts[r_int] = int(ring_counts.get(r_int, 0)) + 1

		BunkerSimRef.call("advance_day", plan["rations"], str(plan["medkit_target"]), ev_out, exp_d, spec_d)
		_verify_resource_invariants(gs, "post_advance_d%d" % int(gs.get("day")))
		guard_days += 1

	var win_stats: Dictionary = _compute_window_repeat_stats(drawn_ids)
	all_window_stats.append(win_stats)

	var member_deaths: Dictionary = {}
	for fm_v in (gs.get("family_members") as Array):
		if fm_v is Dictionary:
			var fm: Dictionary = fm_v
			if not bool(fm.get("alive", true)):
				var dr: String = str(fm.get("death_reason", "unknown")).to_lower()
				var cat_d: String = "other"
				if dr.find("dehydration") != -1:
					cat_d = "dehydration"
				elif dr.find("starvation") != -1:
					cat_d = "starvation"
				elif dr.find("sickness") != -1 or dr.find("fever") != -1:
					cat_d = "sickness"
				elif dr.find("injur") != -1 or dr.find("wound") != -1:
					cat_d = "injury"
				elif dr.find("betrayed") != -1:
					cat_d = "betrayal"
				elif dr.find("cabin fever") != -1 or dr.find("vanished") != -1:
					cat_d = "insanity"
				elif dr.find("raiders") != -1:
					cat_d = "raiders"
				elif dr.find("left behind") != -1 or dr.find("caught above") != -1 or dr.find("shockwave") != -1:
					cat_d = "scavenge_blast"
				member_deaths[cat_d] = int(member_deaths.get(cat_d, 0)) + 1

	return {
		"days": int(gs.get("day")),
		"victory": bool(gs.get("victory")),
		"game_over": bool(gs.get("game_over")),
		"ending_route": str(gs.get("ending_route")),
		"defeat_cause": "" if bool(gs.get("victory")) else _classify_run_defeat_cause(gs),
		"member_deaths": member_deaths,
		"expeditions_completed": int((gs.get("run_metrics") as Dictionary).get("expeditions_completed", 0)),
		"distant_looted": int((gs.get("run_metrics") as Dictionary).get("distant_landmarks_looted", 0)),
		"visited_cats": visited_cats,
		"ring_counts": ring_counts,
		"abx_used": abx_used,
		"ar_used": ar_used,
		"med_used": med_used,
		"window_stats": win_stats
	}

# =============================================================================
# SUITE 1: 30+ FULL AUTOMATED PLAYTHROUGHS, ALL MODES, EVENT BUFFER & VARIETY
# =============================================================================

func _suite_1_playthroughs_and_modes(gs: Node, sm: Node) -> void:
	print("\n--- SUITE 1: 30+ Full Automated Playthroughs Across Difficulties & Modes ---")
	var difficulties: Array[String] = ["little_boy", "fat_man", "tsar_bomba"]
	var presets: Array[String] = ["seattle", "wyndham", "concord", "brooklyn"]
	var strike_dists_km: Array[float] = [2.4, 6.5, 22.0, 120.0, 4800.0]
	var strike_yields: Array[int] = [800, 250, 800, 50000, 800]

	var global_cats_visited: Dictionary = {}
	var global_rings_launched: Dictionary = {1: 0, 2: 0, 3: 0}
	var scavenge_soup_spawns_by_diff: Dictionary = {"little_boy": [], "fat_man": [], "tsar_bomba": []}
	var scavenge_time_by_diff: Dictionary = {"little_boy": 0.0, "fat_man": 0.0, "tsar_bomba": 0.0}

	for diff_id in difficulties:
		var days_arr: Array[int] = []
		var wins: int = 0
		var routes_won: Dictionary = {}
		var defeat_causes: Dictionary = {}
		var indiv_deaths: Dictionary = {}
		var total_exps: int = 0
		var total_deep_exps: int = 0

		for run_i in range(10):
			var seed_val: int = 202600 + difficulties.find(diff_id) * 100 + run_i * 7
			var gs_rng: RandomNumberGenerator = gs.get("rng")
			gs_rng.seed = seed_val

			gs.set("difficulty", diff_id)
			gs.set("game_mode", "full_protocol")
			gs.set("active_challenge_id", "")
			gs.call("init_default_family")

			# Vary traits/ages realistically across runs
			var preset_id: String = presets[run_i % presets.size()]
			var parsed_osm: Dictionary = OsmServiceRef.call("load_preset", preset_id)
			var bldgs: Array = parsed_osm.get("buildings", [])
			var pois: Array = parsed_osm.get("pois", [])
			var house: Dictionary = OsmServiceRef.call("pick_best_house", bldgs, float(parsed_osm.get("center_lat", 47.624)), float(parsed_osm.get("center_lon", -122.319)), int(parsed_osm.get("preferred_osm_id", -1)))
			gs.set("selected_house", house.duplicate(true))
			gs.set("current_neighborhood_label", str(parsed_osm.get("label", preset_id)))
			var targets: Array = OsmServiceRef.call("build_nearby_targets_for_house", house, bldgs, pois, str(parsed_osm.get("label", "")))
			gs.set("nearby_pois", targets)

			var h_lat: float = float(house.get("lat", 47.624))
			var h_lon: float = float(house.get("lon", -122.319))
			var dist_km: float = strike_dists_km[run_i % strike_dists_km.size()]
			var y_kt: int = strike_yields[run_i % strike_yields.size()]
			var strike_pt: Dictionary = NukePhysicsRef.call("destination_point", h_lat, h_lon, 225.0, dist_km)
			var nuke_cfg: Dictionary = NukePhysicsRef.call("compute_impact", h_lat, h_lon, float(strike_pt["lat"]), float(strike_pt["lon"]), y_kt, 45.0, "Strike #%d" % run_i)
			gs.set("nuke_config", nuke_cfg)

			# Realistic human scavenge haul distribution (4..15 items on 60s, +3 on 70s Little Boy) + diverse bunker policies
			var base_caps: Array[int] = [14, 12, 11, 13, 9, 10, 8, 5, 6, 4]
			var item_cap: int = base_caps[run_i % base_caps.size()] + (3 if diff_id == "little_boy" else 0)
			var leave_one: bool = (run_i == 8)
			var selfish: bool = (run_i == 4 or run_i == 9)
			var pursue_rescues: bool = (run_i < 7)
			var pursue_vehicle: bool = (run_i % 2 == 0 or run_i < 4)

			var scav_res: Dictionary = _simulate_smart_scavenge(gs, item_cap, leave_one)
			await _wait_frames(1)
			(scavenge_soup_spawns_by_diff[diff_id] as Array).append(int(scav_res["spawned_soup"]))
			scavenge_time_by_diff[diff_id] = float(scav_res["scavenge_total"])

			var run_res: Dictionary = _run_bunker_playthrough(gs, 65, pursue_rescues, pursue_vehicle, selfish)
			days_arr.append(int(run_res["days"]))
			total_exps += int(run_res["expeditions_completed"])
			total_deep_exps += int(run_res["distant_looted"])

			if bool(run_res["victory"]):
				wins += 1
				var rt: String = str(run_res["ending_route"])
				routes_won[rt] = int(routes_won.get(rt, 0)) + 1
			else:
				var dc: String = str(run_res["defeat_cause"])
				if dc == "":
					dc = "survived_to_cap"
				defeat_causes[dc] = int(defeat_causes.get(dc, 0)) + 1

			var md_map: Dictionary = run_res["member_deaths"]
			for dk in md_map.keys():
				indiv_deaths[dk] = int(indiv_deaths.get(dk, 0)) + int(md_map[dk])

			var vc_map: Dictionary = run_res["visited_cats"]
			for ck in vc_map.keys():
				global_cats_visited[ck] = int(global_cats_visited.get(ck, 0)) + int(vc_map[ck])
			var rc_map: Dictionary = run_res["ring_counts"]
			for rk in rc_map.keys():
				global_rings_launched[rk] = int(global_rings_launched.get(rk, 0)) + int(rc_map[rk])

		diff_metrics[diff_id] = {
			"runs": 10,
			"days": days_arr,
			"mean_days": _mean_int(days_arr),
			"median_days": _median_int(days_arr),
			"min_days": _min_int(days_arr),
			"max_days": _max_int(days_arr),
			"wins": wins,
			"win_rate_pct": float(wins) * 10.0,
			"routes_won": routes_won,
			"defeat_causes": defeat_causes,
			"indiv_deaths": indiv_deaths,
			"expeditions_completed": total_exps,
			"distant_looted": total_deep_exps
		}

	_check(
		is_equal_approx(float(scavenge_time_by_diff["little_boy"]), 70.0)
		and is_equal_approx(float(scavenge_time_by_diff["fat_man"]), 60.0)
		and is_equal_approx(float(scavenge_time_by_diff["tsar_bomba"]), 60.0),
		"Difficulty scavenge countdowns match spec (Little Boy=70s, Fat Man=60s, Tsar Bomba=60s)",
		"got LB=%.1fs FM=%.1fs TB=%.1fs" % [float(scavenge_time_by_diff["little_boy"]), float(scavenge_time_by_diff["fat_man"]), float(scavenge_time_by_diff["tsar_bomba"])]
	)

	# Check whether HouseGenerator applies GameState.get_difficulty_config()["spawn_soup_bonus"] (+2 on Little Boy vs -2 on Tsar Bomba)!
	var lb_mean_soup: float = _mean_int(scavenge_soup_spawns_by_diff["little_boy"])
	var tb_mean_soup: float = _mean_int(scavenge_soup_spawns_by_diff["tsar_bomba"])
	_check(
		lb_mean_soup >= tb_mean_soup + 2.5,
		"3D HouseGenerator applies difficulty spawn_soup_bonus (+2 on Little Boy vs -2 on Tsar Bomba per TitleScreen:52-54 & GameState:146,158)",
		"HouseGenerator._spawn_house_items (scripts/scavenge/house_generator.gd:2036,2043) hardcodes randi_range(6, 8) and ignores spawn_soup_bonus/spawn_water_bonus (LB avg=%.1f vs TB avg=%.1f cans)" % [lb_mean_soup, tb_mean_soup]
	)

	var lb_wr: float = float((diff_metrics["little_boy"] as Dictionary)["win_rate_pct"])
	var tb_wr: float = float((diff_metrics["tsar_bomba"] as Dictionary)["win_rate_pct"])
	_check(
		tb_wr <= 70.0 and tb_wr < lb_wr,
		"Difficulty balance: 'tsar_bomba' (Hardcore) imposes harsher win rate (<=70%% and < Little Boy) under identical policy",
		"Tsar Bomba win_rate=%.1f%% vs Little Boy=%.1f%% — HouseGenerator ignores -2 ration penalty (house_generator.gd:2036), EventDeck forces rescue every 3 days from Day 5 (event_deck.gd:271-288), and fuel_auto guarantees parts+fuel (expedition_engine.gd:729-736)!" % [tb_wr, lb_wr]
	)

	# Verify Ring 1, Ring 2, and Ring 3 + all 7 required landmark categories were exercised in playtests
	var required_cats: Array[String] = ["grocery", "doctor", "pharmacy", "fuel_auto", "hardware", "church", "civic"]
	var missing_cats: Array[String] = []
	for req_c in required_cats:
		if int(global_cats_visited.get(req_c, 0)) <= 0:
			missing_cats.append(req_c)
	_check(
		int(global_rings_launched[1]) > 0 and int(global_rings_launched[2]) > 0 and int(global_rings_launched[3]) > 0 and missing_cats.is_empty(),
		"Smart playtests launched Ring 1 (%d), Ring 2 (%d), and Ring 3 (%d) expeditions across all required landmark categories" % [
			int(global_rings_launched[1]), int(global_rings_launched[2]), int(global_rings_launched[3])
		],
		"missing_cats=%s" % str(missing_cats)
	)

	# --- Standalone Modes & All 3 Special Challenges ---
	print("\n--- Testing Standalone Modes (scavenge_drill, survival_only) & All 3 Challenge Modes ---")

	# 1) Standalone scavenge_drill via TitleScreen._on_scavenge_drill_pressed()
	gs.set("difficulty", "fat_man")
	var ts_drill: Control = TitleScreenRef.new()
	root.add_child(ts_drill)
	await _wait_frames(1)
	ts_drill.call("_on_scavenge_drill_pressed")
	await _wait_frames(2)
	ts_drill.queue_free()
	var drill_scav_res: Dictionary = _simulate_smart_scavenge(gs, 99, false)
	await _wait_frames(2)
	var drill_stats: Dictionary = gs.get("scavenge_stats")
	mode_metrics["scavenge_drill"] = {
		"items": int(drill_stats.get("items_collected", 0)),
		"family_saved": int(drill_stats.get("family_saved", 0)),
		"score": int(drill_stats.get("drill_score", 0)),
		"grade": str(drill_stats.get("drill_grade", "")),
		"victory": bool(gs.get("victory"))
	}
	_check(
		str(gs.get("game_mode")) == "scavenge_drill"
		and str(gs.get("ending_route")) == "scavenge_drill"
		and bool(gs.get("game_over"))
		and bool(gs.get("victory"))
		and int(drill_stats.get("drill_score", 0)) > 0
		and str(gs.get("current_screen")) == "summary",
		"Standalone 'scavenge_drill' completes 60s house sweep, scores Grade %s (%d pts, %d items), and routes directly to Summary" % [
			str(drill_stats.get("drill_grade", "?")), int(drill_stats.get("drill_score", 0)), int(drill_scav_res["items_deposited"])
		]
	)

	# 2) Standalone survival_only via TitleScreen._on_survival_only_pressed()
	gs.set("difficulty", "fat_man")
	(gs.get("rng") as RandomNumberGenerator).seed = 314159
	var ts_surv: Control = TitleScreenRef.new()
	root.add_child(ts_surv)
	await _wait_frames(1)
	ts_surv.call("_on_survival_only_pressed")
	await _wait_frames(2)
	ts_surv.queue_free()
	# Destroy mounted BunkerScene so we can step BunkerSim fast & cleanly
	if is_instance_valid(main_inst.get("_active_node")):
		(main_inst.get("_active_node") as Node).queue_free()
		main_inst.set("_active_node", null)
	await _wait_frames(1)
	var surv_only_res: Dictionary = _run_bunker_playthrough(gs, 50, true, true, false)
	mode_metrics["survival_only"] = surv_only_res
	_check(
		str(gs.get("game_mode")) == "survival_only" and int(surv_only_res["days"]) >= 5 and bool(surv_only_res["game_over"]),
		"Standalone 'survival_only' seeds instant shelter loadout and completes full survival run (Day %d, victory=%s, route=%s)" % [
			int(surv_only_res["days"]), str(surv_only_res["victory"]), str(surv_only_res["ending_route"])
		]
	)

	# 3) All 3 Special Challenges via REAL TitleScreen.launch_challenge(id) -> ScavengeScene -> BunkerSim!
	var challenge_ids: Array[String] = ["cul_de_sac_odyssey", "nuclear_winter_zero", "lone_wolf_pets"]
	for ch_id in challenge_ids:
		gs.set("difficulty", "fat_man")
		(gs.get("rng") as RandomNumberGenerator).seed = 505000 + challenge_ids.find(ch_id) * 111
		var ts_ch: Control = TitleScreenRef.new()
		root.add_child(ts_ch)
		await _wait_frames(1)
		ts_ch.call("launch_challenge", ch_id)
		await _wait_frames(2)
		ts_ch.queue_free()
		# Free auto-mounted ScavengeScene from MainController before running our controlled ScavengeScene
		# Wait: inspect what MainController's mounted ScavengeScene ALREADY did to GameState on launch_challenge!
		var post_mount_cat: bool = bool(gs.get("has_cat_sharikov"))
		var post_mount_dog: bool = bool(gs.get("has_dog_pancake"))
		var post_mount_flags: Dictionary = (gs.get("story_flags") as Dictionary).duplicate(true)
		var post_mount_slots: int = int(((gs.get("family_members") as Array)[0] as Dictionary).get("scavenge_slots", 0))
		if is_instance_valid(main_inst.get("_active_node")):
			(main_inst.get("_active_node") as Node).queue_free()
			main_inst.set("_active_node", null)
		await _wait_frames(1)

		if ch_id == "cul_de_sac_odyssey":
			var h_addr: String = str((gs.get("selected_house") as Dictionary).get("address", ""))
			_check(h_addr.find("6217 Walborough") != -1, "Challenge 'cul_de_sac_odyssey' deploys at 6217 Walborough Ct, Glen Allen, VA", "got '%s'" % h_addr)
		elif ch_id == "nuclear_winter_zero":
			var b_temp: float = float(gs.get("bunker_temp_c"))
			_check(b_temp <= -15.0, "Challenge 'nuclear_winter_zero' starts at arctic -16.0 C", "got %.1f C" % b_temp)
		elif ch_id == "lone_wolf_pets":
			_check(
				(gs.get("family_members") as Array).size() == 1 and post_mount_cat and post_mount_dog and bool(post_mount_flags.get("lone_wolf_pets", false)) and post_mount_slots == 4,
				"Challenge 'lone_wolf_pets' preserves Sharikov, Pancake, 4-slot solo perk & story_flags when entering ScavengeScene",
				"ScavengeScene._preserve_and_reset_run_state (scripts/scavenge/scavenge_scene.gd:225-269) called reset_to_defaults() & reset_family_runtime_status(), wiping has_cat_sharikov=%s, has_dog_pancake=%s, story_flags=%s, scavenge_slots=%d!" % [
					str(post_mount_cat), str(post_mount_dog), str(post_mount_flags), post_mount_slots
				]
			)

		var ch_scav: Dictionary = _simulate_smart_scavenge(gs, 99, false)
		if is_instance_valid(main_inst.get("_active_node")):
			(main_inst.get("_active_node") as Node).queue_free()
			main_inst.set("_active_node", null)
		await _wait_frames(1)
		var ch_run: Dictionary = _run_bunker_playthrough(gs, 50, true, true, false)
		ch_run["scavenge_items"] = int(ch_scav["items_deposited"])
		mode_metrics[ch_id] = ch_run
		_check(
			int(ch_run["days"]) >= 2 and bool(ch_run["game_over"]),
			"Challenge '%s' completes full scavenge + bunker playthrough (Day %d, victory=%s, route=%s)" % [
				ch_id, int(ch_run["days"]), str(ch_run["victory"]), str(ch_run["ending_route"])
			]
		)

	# --- Dedicated 25-Day Window Event Repetition & 16-Day Buffer Audit + Static 103-Event Decision Variety Audit ---
	print("\n--- Auditing EventDeck 16-Day Non-Repeat Buffer (25-Day Windows) & 103-Event Decision Variety ---")
	var stress_25d_all_rep: int = 0
	var stress_25d_nr_rep: int = 0
	var stress_25d_draws: int = 0
	var stress_16d_viol_all: int = 0
	var stress_16d_viol_nr: int = 0

	var rng_ev := RandomNumberGenerator.new()
	for win_trial in range(8):
		rng_ev.seed = 910000 + win_trial * 53
		gs.set("difficulty", "fat_man")
		gs.set("game_mode", "survival_only")
		gs.call("init_default_family")
		gs.call("init_default_house")
		gs.call("init_default_nuke")
		gs.call("reset_to_defaults")
		for fm_v in (gs.get("family_members") as Array):
			(fm_v as Dictionary)["in_bunker"] = true
			(fm_v as Dictionary)["alive"] = true
		gs.set("soup_quarters", 60)
		gs.set("water_quarters", 60)
		gs.set("medkit_count", 2)
		gs.set("antibiotics_count", 1)
		gs.set("antirad_count", 1)
		gs.set("scrap_count", 2)
		gs.set("ammo_count", 4)
		for gid in ["radio", "gas_mask", "map", "flashlight", "toolbox", "book", "cards", "axe"]:
			gs.call("add_scavenged_item", gid, 1)
		EventDeckRef.call("reset_state")

		var seq: Array[String] = []
		for d_i in range(1, 26):
			gs.set("day", d_i)
			var ev_d: Dictionary = EventDeckRef.call("draw_daily_event", d_i, rng_ev)
			seq.append(str(ev_d.get("id", "")))
		var ws: Dictionary = _compute_window_repeat_stats(seq)
		stress_25d_draws += int(ws["draws"])
		stress_25d_all_rep += int(ws["repeats_25d_all"])
		stress_25d_nr_rep += int(ws["repeats_25d_non_rescue"])
		stress_16d_viol_all += int(ws["buffer_16d_violations_all"])
		stress_16d_viol_nr += int(ws["buffer_16d_violations_non_rescue"])

	_check(
		stress_16d_viol_nr == 0,
		"EventDeck 16-day non-repeat buffer holds with 0 violations for all general/narrative events across 8 x 25-day windows (%d draws)" % stress_25d_draws,
		"non-rescue 16d violations=%d" % stress_16d_viol_nr
	)
	_check(
		stress_16d_viol_all == 0,
		"EventDeck 16-day non-repeat buffer holds across ALL events (including rescue_* draws) in 25-day windows",
		"EventDeck._should_draw_rescue_event & _pick_rescue_event_id (scripts/events/event_deck.gd:271-360) forces a rescue_* draw every 3 days (8 times in Days 5..25) from only 4 chains using soft 0.08x weight instead of skipping _recent_event_ids -> %d 16-day rescue repeat violations & %d/200 total 25-day repeats!" % [
			stress_16d_viol_all, stress_25d_all_rep
		]
	)

	# Static audit across all 103 EventDeck events
	var all_ev_ids: Array = EventDeckRef.call("get_all_event_ids")
	var static_ge3_opts: int = 0
	var static_tradeoff: int = 0
	var static_zero_avail: int = 0
	# Give stocked shelter + bonded pair so conditional options build cleanly
	gs.call("init_relationships", 60)
	gs.set("has_cat_sharikov", true)
	gs.set("has_dog_pancake", true)
	gs.set("padlock_active", true)
	gs.set("left_behind_members", ["Timmy"])
	for gid_all in ["gas_mask", "radio", "flashlight", "map", "book", "axe", "rifle", "cards", "checkers", "suitcase", "harmonica", "toolbox"]:
		gs.call("add_scavenged_item", gid_all, 1)
	gs.call("break_or_consume_item", "checkers") # ensure >=1 broken item for repair_broken_gear
	gs.call("add_scavenged_item", "checkers", 1)

	for eid_v in all_ev_ids:
		var eid_s: String = str(eid_v)
		var ev_built: Dictionary = EventDeckRef.call("build_event_by_id", eid_s, 10, rng_ev)
		var b_opts: Array = ev_built.get("options", [])
		var b_avail: int = 0
		for bo_v in b_opts:
			if bo_v is Dictionary and bool((bo_v as Dictionary).get("available", false)):
				b_avail += 1
		if b_avail == 0:
			static_zero_avail += 1
		if b_opts.size() >= 3:
			static_ge3_opts += 1
		if _event_has_nontrivial_tradeoff(ev_built):
			static_tradeoff += 1

	var pct_static_ge3: float = 100.0 * float(static_ge3_opts) / float(maxi(1, all_ev_ids.size()))
	var pct_static_trade: float = 100.0 * float(static_tradeoff) / float(maxi(1, all_ev_ids.size()))
	_check(static_zero_avail == 0 and all_ev_ids.size() >= 100,
		"All %d EventDeck events build cleanly with >=1 available option (zero softlocks); %.1f%% have >=3 options, %.1f%% have non-trivial trade-offs" % [
			all_ev_ids.size(), pct_static_ge3, pct_static_trade
		]
	)
	_check(resource_violation_count == 0 and softlock_count == 0,
		"Zero negative/NaN resource accounting violations (%d) and zero dilemma softlocks (%d) across all 35+ full runs" % [
			resource_violation_count, softlock_count
		]
	)

# =============================================================================
# SUITE 2: ALL 5 VICTORY ROUTES & MULTI-RUN VEHICLE PROGRESSION (0->1->2->3)
# =============================================================================

func _suite_2_all_5_victory_routes_and_vehicle_tiers(gs: Node, sm: Node) -> void:
	print("\n--- SUITE 2: All 5 Victory Routes & Multi-Run Vehicle Progression ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7772026

	# Helper to prepare a clean 4-survivor bunker on Day 6
	var prep_bunker := func() -> void:
		gs.set("difficulty", "fat_man")
		gs.set("game_mode", "full_protocol")
		gs.set("active_challenge_id", "")
		gs.call("init_default_family")
		gs.call("init_default_house")
		gs.call("init_default_nuke")
		gs.call("reset_to_defaults")
		for fm_v in (gs.get("family_members") as Array):
			(fm_v as Dictionary)["in_bunker"] = true
			(fm_v as Dictionary)["alive"] = true
		gs.set("soup_quarters", 40)
		gs.set("water_quarters", 40)
		gs.set("ammo_count", 6)
		gs.set("medkit_count", 2)
		gs.set("antibiotics_count", 2)
		gs.set("scrap_count", 3)
		gs.set("fuel_cans", int(gs.get("fuel_needed")))
		for gid in ["radio", "map", "flashlight", "axe", "rifle", "toolbox", "book", "harmonica", "gas_mask", "suitcase"]:
			gs.call("add_scavenged_item", gid, 1)
		BunkerSimRef.call("start_bunker_run")
		gs.set("day", 6)

	# 1) Route 1: military ("Operation CONELRAD")
	prep_bunker.call()
	var ev_m1: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_military_1", 6, rng)
	var out_m1: Dictionary = EventDeckRef.call("resolve_event", ev_m1, "use_radio", rng)
	BunkerSimRef.call("advance_day", {}, "", out_m1)
	var st_m1: int = int((gs.get("rescue_chains") as Dictionary)["military"])

	var ev_m2: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_military_2", 9, rng)
	var out_m2: Dictionary = EventDeckRef.call("resolve_event", ev_m2, "use_map", rng)
	BunkerSimRef.call("advance_day", {}, "", out_m2)
	var st_m2: int = int((gs.get("rescue_chains") as Dictionary)["military"])

	var ev_m3: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_military_3", 12, rng)
	var out_m3: Dictionary = EventDeckRef.call("resolve_event", ev_m3, "yes", rng)
	BunkerSimRef.call("advance_day", {}, "", out_m3)
	_check(
		st_m1 == 1 and st_m2 == 2 and bool(gs.get("victory")) and bool(gs.get("game_over"))
		and str(gs.get("ending_route")) == "military" and bool(sm.call("is_achievement_unlocked", "military_evac")),
		"Victory Route 1/5 'military' (Operation CONELRAD) progresses 0->1->2->3 end-to-end and unlocks 'military_evac'",
		"stages=%d,%d victory=%s route='%s'" % [st_m1, st_m2, str(gs.get("victory")), str(gs.get("ending_route"))]
	)

	# 2) Route 2: sanctuary ("Parish Alliance" — combining Event + Real OSM Church Expedition!)
	prep_bunker.call()
	var ev_s1: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_sanctuary_1", 6, rng)
	var out_s1: Dictionary = EventDeckRef.call("resolve_event", ev_s1, "use_book", rng)
	BunkerSimRef.call("advance_day", {}, "", out_s1)
	var st_s1: int = int((gs.get("rescue_chains") as Dictionary)["sanctuary"])

	# Advance Stage 1 -> 2 via actual OSM Church Expedition!
	var sanc_targets: Array = ExpeditionRef.call("get_available_targets")
	var church_idx: int = 0
	for ti in range(sanc_targets.size()):
		if str((sanc_targets[ti] as Dictionary).get("category", "")) == "church":
			church_idx = ti
			break
	ExpeditionRef.call("start_expedition", "member_0", church_idx, ["gas_mask"])
	while not (gs.get("active_expedition") as Dictionary).is_empty():
		BunkerSimRef.call("advance_day", {"member_1": {"soup_q": 1, "water_q": 1}})
	var st_s2: int = int((gs.get("rescue_chains") as Dictionary)["sanctuary"])

	var ev_s3: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_sanctuary_3", 12, rng)
	var out_s3: Dictionary = EventDeckRef.call("resolve_event", ev_s3, "yes", rng)
	BunkerSimRef.call("advance_day", {}, "", out_s3)
	_check(
		st_s1 == 1 and st_s2 == 2 and bool(gs.get("victory")) and bool(gs.get("game_over"))
		and str(gs.get("ending_route")) == "sanctuary" and bool(sm.call("is_achievement_unlocked", "parish_alliance")),
		"Victory Route 2/5 'sanctuary' (Parish Alliance) progresses 0->1->2 (via OSM Church trek)->3 and unlocks 'parish_alliance'",
		"stages=%d,%d victory=%s route='%s'" % [st_s1, st_s2, str(gs.get("victory")), str(gs.get("ending_route"))]
	)

	# 3) Route 3: scientist ("Vault & Sharikov")
	prep_bunker.call()
	var ev_sc1: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_scientist_1", 6, rng)
	var out_sc1: Dictionary = EventDeckRef.call("resolve_event", ev_sc1, "adopt_soup", rng)
	BunkerSimRef.call("advance_day", {}, "", out_sc1)
	var st_sc1: int = int((gs.get("rescue_chains") as Dictionary)["scientist"])
	var has_sharikov: bool = bool(gs.get("has_cat_sharikov"))

	var ev_sc2: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_scientist_2", 9, rng)
	var out_sc2: Dictionary = EventDeckRef.call("resolve_event", ev_sc2, "use_radio", rng)
	BunkerSimRef.call("advance_day", {}, "", out_sc2)
	var st_sc2: int = int((gs.get("rescue_chains") as Dictionary)["scientist"])

	var ev_sc3: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_scientist_3", 12, rng)
	var out_sc3: Dictionary = EventDeckRef.call("resolve_event", ev_sc3, "yes", rng)
	BunkerSimRef.call("advance_day", {}, "", out_sc3)
	_check(
		has_sharikov and st_sc1 == 1 and st_sc2 == 2 and bool(gs.get("victory")) and bool(gs.get("game_over"))
		and str(gs.get("ending_route")) == "scientist" and bool(sm.call("is_achievement_unlocked", "vault_agent")),
		"Victory Route 3/5 'scientist' (Vault & Sharikov) adopts Sharikov, progresses 0->1->2->3, and unlocks 'vault_agent'",
		"sharikov=%s stages=%d,%d victory=%s route='%s'" % [str(has_sharikov), st_sc1, st_sc2, str(gs.get("victory")), str(gs.get("ending_route"))]
	)

	# 4) Route 4: raider_pact ("Smuggler Convoy")
	prep_bunker.call()
	var ev_rp1: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_raider_pact_1", 6, rng)
	var out_rp1: Dictionary = EventDeckRef.call("resolve_event", ev_rp1, "use_radio", rng)
	BunkerSimRef.call("advance_day", {}, "", out_rp1)
	var st_rp1: int = int((gs.get("rescue_chains") as Dictionary)["raider_pact"])

	var ev_rp2: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_raider_pact_2", 9, rng)
	var out_rp2: Dictionary = EventDeckRef.call("resolve_event", ev_rp2, "give_fuel", rng)
	BunkerSimRef.call("advance_day", {}, "", out_rp2)
	var st_rp2: int = int((gs.get("rescue_chains") as Dictionary)["raider_pact"])

	var ev_rp3: Dictionary = EventDeckRef.call("build_event_by_id", "rescue_raider_pact_3", 12, rng)
	var out_rp3: Dictionary = EventDeckRef.call("resolve_event", ev_rp3, "yes", rng)
	var route_immediate_after_event: String = str(gs.get("ending_route"))
	BunkerSimRef.call("advance_day", {}, "", out_rp3)
	var route_after_advance: String = str(gs.get("ending_route"))
	_check(
		st_rp1 == 1 and st_rp2 == 2 and bool(gs.get("victory")) and bool(gs.get("game_over"))
		and route_after_advance == "raider_pact" and bool(sm.call("is_achievement_unlocked", "convoy_pact")),
		"Victory Route 4/5 'raider_pact' (Smuggler Convoy) progresses 0->1->2->3 end-to-end and unlocks 'convoy_pact'",
		"stages=%d,%d victory=%s route='%s'" % [st_rp1, st_rp2, str(gs.get("victory")), route_after_advance]
	)
	_check(
		route_immediate_after_event == "raider_pact",
		"EventDeck 'rescue_raider_pact_3' sets canonical ending_route == 'raider_pact' (matching BunkerSim & SummaryScreen)",
		"EventDeck.resolve_event (scripts/events/event_deck.gd:3624) sets ending_route='convoy_pact' instead of 'raider_pact' (SummaryScreen._format_ending_route_stamp at scripts/ui/summary_screen.gd:94 only matches 'raider_pact'/'convoy'/'smuggler')"
	)

	# 5) Route 5: vehicle_breakout + Multi-Run Vehicle Chassis Tier Progression 0 -> 1 -> 2 -> 3!
	sm.set("meta", {
		"vehicle_chassis_tier": 0,
		"total_vehicle_parts_banked": 0,
		"unlocked_achievements": {},
		"unlocked_hats": ["none"],
		"runs_played": 0,
		"victories": 0,
		"longest_days": 0,
		"best_scavenge_items": 0
	})

	# Verify Tier 0 initial state
	prep_bunker.call()
	# Note: prep_bunker gave toolbox & fuel=3, check parts start at 0 at Tier 0
	_check(
		int(sm.call("get_vehicle_chassis_tier")) == 0
		and int(gs.call("get_vehicle_parts_owned_count")) == 0
		and int(gs.get("fuel_needed")) == 5
		and not bool(gs.call("can_escape_by_vehicle")),
		"Chassis Tier 0 starts with 0/4 pre-installed vehicle parts and fuel_needed == 5"
	)

	# Collect 4 parts, tune, and execute_vehicle_escape() -> Tier 0 -> 1
	for pid in ["battery", "alternator", "spark_plugs", "radiator_hose"]:
		gs.call("add_scavenged_item", pid, 1)
	gs.set("vehicle_tuned", false)
	gs.call("break_or_consume_item", "toolbox")
	gs.call("break_or_consume_item", "book")
	# Test Handy trait vs can_escape_by_vehicle() consistency!
	var handy_can_escape_before_tune: bool = bool(gs.call("can_escape_by_vehicle"))
	var tune_msg: String = str(BunkerSimRef.call("tune_escape_vehicle"))
	var can_escape_after_tune: bool = bool(gs.call("can_escape_by_vehicle"))
	_check(
		handy_can_escape_before_tune == false and can_escape_after_tune == true,
		"Vehicle escape requires an explicit engine tune; a 'handy' survivor can perform it without Toolbox/Book (blocked before tune, allowed after)",
		"GameState.can_escape_by_vehicle (scripts/core/game_state.gd:425) checks only vehicle_tuned/toolbox/book while BunkerScene:2145 & BunkerSim:457 also allow 'handy' trait (tune_msg='%s', after_tune=%s)" % [tune_msg, str(can_escape_after_tune)]
	)

	var esc_ok_1: bool = bool(BunkerSimRef.call("execute_vehicle_escape"))
	var rec_1: Dictionary = sm.call("record_run_completion", int(gs.call("get_vehicle_parts_owned_count")), true, true, 14, 15)
	_check(
		esc_ok_1 and bool(gs.get("victory")) and str(gs.get("ending_route")) == "vehicle_breakout"
		and int(rec_1["prev_tier"]) == 0 and int(rec_1["new_tier"]) == 1 and int(sm.call("get_vehicle_chassis_tier")) == 1
		and bool(sm.call("is_achievement_unlocked", "highway_breakout")),
		"Victory Route 5/5 'vehicle_breakout' executes Station Wagon escape and upgrades vehicle_chassis_tier 0 -> 1",
		"esc=%s route='%s' rec=%s" % [str(esc_ok_1), str(gs.get("ending_route")), str(rec_1)]
	)

	# Verify Tier 1 pre-installs Battery on next run, then escape -> Tier 1 -> 2
	gs.call("reset_to_defaults")
	for fm_v in (gs.get("family_members") as Array):
		(fm_v as Dictionary)["in_bunker"] = true
		(fm_v as Dictionary)["alive"] = true
	var t1_bat: bool = bool((gs.get("vehicle_parts") as Dictionary)["battery"])
	var t1_cnt: int = int(gs.call("get_vehicle_parts_owned_count"))
	for pid2 in ["alternator", "spark_plugs", "radiator_hose"]:
		gs.call("add_scavenged_item", pid2, 1)
	gs.set("fuel_cans", int(gs.get("fuel_needed")))
	gs.set("vehicle_tuned", true)
	var esc_ok_2: bool = bool(BunkerSimRef.call("execute_vehicle_escape"))
	var rec_2: Dictionary = sm.call("record_run_completion", int(gs.call("get_vehicle_parts_owned_count")), true, true, 12, 14)
	_check(
		t1_bat and t1_cnt == 1 and esc_ok_2 and int(rec_2["prev_tier"]) == 1 and int(rec_2["new_tier"]) == 2 and int(sm.call("get_vehicle_chassis_tier")) == 2,
		"Chassis Tier 1 pre-installs Battery (1/4) and second vehicle escape upgrades vehicle_chassis_tier 1 -> 2",
		"t1_bat=%s t1_cnt=%d rec_2=%s" % [str(t1_bat), t1_cnt, str(rec_2)]
	)

	# Audit whether dying on Day 1 without finding ANY new parts erroneously double-banks pre-installed Tier 2 parts!
	var banked_before_instant_loss: int = int((sm.get("meta") as Dictionary)["total_vehicle_parts_banked"])
	gs.call("reset_to_defaults")
	var t2_bat: bool = bool((gs.get("vehicle_parts") as Dictionary)["battery"])
	var t2_hose: bool = bool((gs.get("vehicle_parts") as Dictionary)["radiator_hose"])
	var t2_cnt: int = int(gs.call("get_vehicle_parts_owned_count"))
	# Simulate SummaryScreen._ready() on a Day 1 defeat where 0 new parts were scavenged
	gs.set("game_over", true)
	gs.set("victory", false)
	gs.set("ending_route", "perished")
	var sum_node: Control = SummaryScreenRef.new()
	root.add_child(sum_node)
	await _wait_frames(1)
	sum_node.queue_free()
	var banked_after_instant_loss: int = int((sm.get("meta") as Dictionary)["total_vehicle_parts_banked"])
	var tier_after_instant_loss: int = int(sm.call("get_vehicle_chassis_tier"))
	_check(
		banked_after_instant_loss == banked_before_instant_loss and tier_after_instant_loss == 2,
		"Dying with 0 newly scavenged parts at Tier 2 does NOT re-bank pre-installed parts to unlock Tier 3 for free",
		"SummaryScreen._ready (scripts/ui/summary_screen.gd:22-24) passes get_vehicle_parts_owned_count() (%d pre-installed parts) instead of newly scavenged parts into SaveManager.record_run_completion -> banked jumped %d -> %d and tier jumped 2 -> %d on a 0-part defeat!" % [
			t2_cnt, banked_before_instant_loss, banked_after_instant_loss, tier_after_instant_loss
		]
	)

	# Reset back to Tier 2 cleanly to verify legitimate escape upgrade 2 -> 3 and Tier 3 perks!
	(sm.get("meta") as Dictionary)["vehicle_chassis_tier"] = 2
	(sm.get("meta") as Dictionary)["total_vehicle_parts_banked"] = 6
	gs.call("reset_to_defaults")
	for fm_v in (gs.get("family_members") as Array):
		(fm_v as Dictionary)["in_bunker"] = true
		(fm_v as Dictionary)["alive"] = true
	for pid3 in ["alternator", "spark_plugs"]:
		gs.call("add_scavenged_item", pid3, 1)
	gs.set("fuel_cans", int(gs.get("fuel_needed")))
	gs.set("vehicle_tuned", true)
	var esc_ok_3: bool = bool(BunkerSimRef.call("execute_vehicle_escape"))
	var rec_3: Dictionary = sm.call("record_run_completion", 2, true, true, 11, 16)
	gs.call("reset_to_defaults")
	var t3_bat: bool = bool((gs.get("vehicle_parts") as Dictionary)["battery"])
	var t3_hose: bool = bool((gs.get("vehicle_parts") as Dictionary)["radiator_hose"])
	var t3_fuel: int = int(gs.get("fuel_cans"))
	var t3_need: int = int(gs.get("fuel_needed"))
	_check(
		t2_bat and t2_hose and t2_cnt == 2 and esc_ok_3 and int(rec_3["prev_tier"]) == 2 and int(rec_3["new_tier"]) == 3
		and t3_bat and t3_hose and t3_fuel == 1 and t3_need == 4,
		"Chassis Tier 2->3 escape succeeds and Tier 3 pre-installs Battery + Radiator Hose + 1 Fuel Can with fuel_needed == 4",
		"rec_3=%s t3=(bat=%s,hose=%s,fuel=%d/%d)" % [str(rec_3), str(t3_bat), str(t3_hose), t3_fuel, t3_need]
	)

# =============================================================================
# SUITE 3: FAMILY RELATIONSHIPS & LEFT-BEHIND CONSEQUENCES
# =============================================================================

func _suite_3_relationships_and_left_behind(gs: Node, sm: Node) -> void:
	print("\n--- SUITE 3: Family Relationships & Left-Behind Consequences ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	# 3.1 Left-behind grief penalty (-22 toward Leader, +1 sanity stress, haunting guilt events)
	gs.set("difficulty", "fat_man")
	gs.set("game_mode", "full_protocol")
	gs.call("init_default_family")
	gs.call("init_default_house")
	gs.call("init_default_nuke")
	gs.call("reset_to_defaults")
	var fams: Array = gs.get("family_members")
	# Ted (member_0, Leader) & Dolores (member_1) in bunker; Mary Jane (member_2) & Timmy (member_3) left behind!
	(fams[0] as Dictionary)["in_bunker"] = true
	(fams[0] as Dictionary)["alive"] = true
	(fams[1] as Dictionary)["in_bunker"] = true
	(fams[1] as Dictionary)["alive"] = true
	(fams[2] as Dictionary)["in_bunker"] = false
	(fams[2] as Dictionary)["alive"] = false
	(fams[3] as Dictionary)["in_bunker"] = false
	(fams[3] as Dictionary)["alive"] = false
	gs.set("left_behind_members", ["Mary Jane", "Timmy"])
	gs.set("soup_quarters", 24)
	gs.set("water_quarters", 24)

	var rel_pre_grief: int = int(gs.call("get_relationship", "member_0", "member_1")) # 20
	BunkerSimRef.call("start_bunker_run")
	var rel_post_grief: int = int(gs.call("get_relationship", "member_0", "member_1"))
	var san_ted: int = int((fams[0] as Dictionary)["sanity"])
	var san_dol: int = int((fams[1] as Dictionary)["sanity"])
	var w_haunted: float = float(EventDeckRef.call("_get_event_weight", "family_haunted_unrescued", 5))
	var w_phantom: float = float(EventDeckRef.call("_get_event_weight", "family_phantom_knock_guilt", 5))

	var ev_haunt: Dictionary = EventDeckRef.call("build_event_by_id", "family_haunted_unrescued", 5, rng)
	var haunt_desc: String = str(ev_haunt.get("description", ""))
	var out_haunt: Dictionary = EventDeckRef.call("resolve_event", ev_haunt, "leader_apologize", rng)

	_check(
		rel_pre_grief == 20 and rel_post_grief == -2 and san_ted == 1 and san_dol == 1
		and w_haunted > 2.0 and w_phantom > 2.0
		and (haunt_desc.find("Mary Jane") != -1 or haunt_desc.find("Timmy") != -1)
		and str(out_haunt.get("outcome_text", "")).find("+15") != -1,
		"Left-behind kin trigger exact -22 grief penalty toward Leader (20 -> -2), +1 grief stress, and active haunting guilt events",
		"pre=%d post=%d san=(%d,%d) w=(%.1f,%.1f)" % [rel_pre_grief, rel_post_grief, san_ted, san_dol, w_haunted, w_phantom]
	)

	# 3.2 Ration Favoritism (-12 resentment)
	gs.call("init_relationships", 20)
	(fams[0] as Dictionary)["hunger"] = 0
	(fams[0] as Dictionary)["thirst"] = 0
	(fams[1] as Dictionary)["hunger"] = 2
	(fams[1] as Dictionary)["thirst"] = 2
	var fav_lines: Array = RelationshipRef.call("evaluate_ration_fairness", {
		"member_0": {"soup_q": 1, "water_q": 1},
		"member_1": {"soup_q": 0, "water_q": 0}
	})
	var rel_after_fav: int = int(gs.call("get_relationship", "member_0", "member_1"))
	_check(
		rel_after_fav == 8 and not fav_lines.is_empty(),
		"Ration Favoritism applies exact -12 resentment penalty (20 -> 8) when pampering satisfied member while neglecting hungry/thirsty kin",
		"rel=%d lines=%s" % [rel_after_fav, str(fav_lines)]
	)

	# 3.3 Medical Care Gratitude (+16 across Medkit, Antibiotics & Anti-Rad)
	gs.set("medkit_count", 1)
	gs.set("antibiotics_count", 1)
	gs.set("antirad_count", 1)
	(fams[1] as Dictionary)["sickness"] = 2
	(fams[1] as Dictionary)["injury"] = 2
	(fams[1] as Dictionary)["radiation"] = 50.0
	var rel_m0: int = int(gs.call("get_relationship", "member_0", "member_1"))
	BunkerSimRef.call("use_medkit_on", "member_1")
	var rel_m1: int = int(gs.call("get_relationship", "member_0", "member_1"))
	(fams[1] as Dictionary)["sickness"] = 1
	BunkerSimRef.call("use_antibiotics_on", "member_1")
	var rel_m2: int = int(gs.call("get_relationship", "member_0", "member_1"))
	BunkerSimRef.call("use_antirad_on", "member_1")
	var rel_m3: int = int(gs.call("get_relationship", "member_0", "member_1"))
	_check(
		(rel_m1 - rel_m0) == 16 and (rel_m2 - rel_m1) == 16 and (rel_m3 - rel_m2) == 16
		and is_equal_approx(float((fams[1] as Dictionary)["radiation"]), 15.0),
		"Medical Care gratitude grants exact +16 bond per treatment (Medkit +16, Antibiotics +16, Anti-Rad +16 & -35 rads: 50->15)",
		"rels: %d -> %d -> %d -> %d, rad=%.1f" % [rel_m0, rel_m1, rel_m2, rel_m3, float((fams[1] as Dictionary)["radiation"])]
	)

	# 3.4 Devoted Cooperation (>= 55 repair bonus + [COOPERATE] dilemma options + daily soothing)
	gs.call("init_relationships", 10)
	var ev_pipe_low: Dictionary = EventDeckRef.call("build_event_by_id", "family_cooperate_pipe_burst", 6, rng)
	var coop_avail_low: bool = false
	for o_v in (ev_pipe_low.get("options", []) as Array):
		var od: Dictionary = o_v
		if str(od.get("id", "")) == "cooperate_brace":
			coop_avail_low = bool(od.get("available", false))

	gs.call("init_relationships", 60) # >= 55 Devoted!
	var tier_60: String = str(gs.call("get_relationship_tier", 60))
	var rep_bonus: float = float(RelationshipRef.call("get_repair_cooperation_bonus"))
	gs.set("bunker_structural_integrity", 70.0)
	gs.set("scrap_count", 1)
	BunkerSimRef.call("reinforce_hull_with_scrap")
	var hull_after_devoted_scrap: float = float(gs.get("bunker_structural_integrity"))

	var ev_pipe_high: Dictionary = EventDeckRef.call("build_event_by_id", "family_cooperate_pipe_burst", 6, rng)
	var coop_avail_high: bool = false
	for o_v2 in (ev_pipe_high.get("options", []) as Array):
		var od2: Dictionary = o_v2
		if str(od2.get("id", "")) == "cooperate_brace":
			coop_avail_high = bool(od2.get("available", false))

	(fams[1] as Dictionary)["breakdown_days"] = 2
	(fams[1] as Dictionary)["sanity"] = 2
	var dev_tick: Dictionary = RelationshipRef.call("tick_daily_relationships", rng)
	_check(
		tier_60 == "Devoted"
		and is_equal_approx(rep_bonus, 0.25)
		and is_equal_approx(hull_after_devoted_scrap, 85.0)
		and (not coop_avail_low) and coop_avail_high
		and int((fams[1] as Dictionary)["breakdown_days"]) == 0
		and int(dev_tick.get("bonds", 0)) >= 1
		and bool(sm.call("is_achievement_unlocked", "unbreakable_bond")),
		"Devoted Cooperation (>=55) grants +25% scrap hull repair bonus (70%->85%), unlocks [COOPERATE] options, clears breakdowns, and unlocks 'unbreakable_bond'",
		"tier=%s bonus=%.2f hull=%.1f coop=(%s->%s)" % [tier_60, rep_bonus, hull_after_devoted_scrap, str(coop_avail_low), str(coop_avail_high)]
	)

	# Also check exact threshold alignment: Devoted is >=55 in GameState:393 & tick_daily_relationships:283 vs 45 in has_bonded_pair:459 / EventDeck:4969
	gs.call("init_relationships", 48) # Loyal (48 < 55), NOT Devoted!
	var loyal_48_tier: String = str(gs.call("get_relationship_tier", 48))
	var loyal_48_has_bonus: float = float(RelationshipRef.call("get_repair_cooperation_bonus"))
	print("    [INFO] Threshold note: score=48 tier='%s' has repair_bonus=%.2f (unlocks at >=45 Loyal/Devoted)" % [loyal_48_tier, loyal_48_has_bonus])

	# 3.5 Resentful Arguments (<= -35)
	gs.call("init_relationships", -42)
	var args_triggered: int = 0
	for _t in range(25):
		(fams[0] as Dictionary)["sanity"] = 0
		(fams[1] as Dictionary)["sanity"] = 0
		var r_tick: Dictionary = RelationshipRef.call("tick_daily_relationships", rng)
		args_triggered += int(r_tick.get("arguments", 0))
	_check(
		args_triggered >= 3 and int(gs.call("get_relationship", "member_0", "member_1")) < -42,
		"Resentful Arguments (score <= -35) fire probabilistically (%d/25 days), eroding bond further & adding stress" % args_triggered
	)

	# 3.6 Emotional Breakdowns (sanity >= 2 and avg_rel <= -20 -> breakdown_days = 2 & blocks expeditions!)
	gs.call("init_relationships", -30)
	var bd_triggered: bool = false
	for _t2 in range(30):
		(fams[1] as Dictionary)["sanity"] = 2
		(fams[1] as Dictionary)["breakdown_days"] = 0
		RelationshipRef.call("tick_daily_relationships", rng)
		if int((fams[1] as Dictionary)["breakdown_days"]) == 2:
			bd_triggered = true
			break
	var can_exp_during_bd: bool = bool(ExpeditionRef.call("can_member_expedition", fams[1]))
	var refuse_msg: String = str(ExpeditionRef.call("start_expedition", "member_1", 0, []))
	var exp_empty_after_refuse: bool = (gs.get("active_expedition") as Dictionary).is_empty()
	RelationshipRef.call("comfort_member", "member_1")
	var can_exp_after_comfort: bool = bool(ExpeditionRef.call("can_member_expedition", fams[1]))
	_check(
		bd_triggered and (not can_exp_during_bd) and exp_empty_after_refuse and refuse_msg.find("breakdown") != -1 and can_exp_after_comfort,
		"Emotional Breakdown sets breakdown_days=2, blocks wasteland expeditions until comforted, and clears via comfort_member (+10 bond)",
		"bd=%s can_exp=%s empty=%s after_comfort=%s" % [str(bd_triggered), str(can_exp_during_bd), str(exp_empty_after_refuse), str(can_exp_after_comfort)]
	)

	# 3.7 Hostile Overnight Betrayal (avg_rel <= -75 and sanity >= 2 -> steals rations & deserts forever!)
	gs.call("init_relationships", -85)
	var betrayed_fired: bool = false
	for _t3 in range(30):
		(fams[0] as Dictionary)["alive"] = true
		(fams[0] as Dictionary)["in_bunker"] = true
		(fams[0] as Dictionary)["sanity"] = 0
		(fams[0] as Dictionary)["hunger"] = 0
		(fams[1] as Dictionary)["alive"] = true
		(fams[1] as Dictionary)["in_bunker"] = true
		(fams[1] as Dictionary)["betrayed"] = false
		(fams[1] as Dictionary)["sanity"] = 2
		(fams[1] as Dictionary)["breakdown_days"] = 2 # prevent simultaneous breakdown soup-sneak during betrayal roll
		gs.set("soup_quarters", 12)
		gs.set("water_quarters", 12)
		var b_tick: Dictionary = RelationshipRef.call("tick_daily_relationships", rng)
		if str(b_tick.get("betrayal_member", "")) == str((fams[1] as Dictionary)["name"]):
			betrayed_fired = true
			break
	var dol_badges: Array = BunkerSimRef.call("get_condition_labels", fams[1])
	_check(
		betrayed_fired
		and (not bool((fams[1] as Dictionary)["alive"]))
		and (not bool((fams[1] as Dictionary)["in_bunker"]))
		and bool((fams[1] as Dictionary)["betrayed"])
		and int(gs.get("soup_quarters")) == 8
		and int(gs.get("water_quarters")) == 8
		and dol_badges.has("Betrayed"),
		"Hostile Overnight Betrayal (<= -75) steals 4/4 Soup & 4/4 Water (12->8), marks member betrayed, and removes them from shelter",
		"fired=%s soup=%d water=%d badges=%s" % [str(betrayed_fired), int(gs.get("soup_quarters")), int(gs.get("water_quarters")), str(dol_badges)]
	)

# =============================================================================
# SUITE 4: SAVE / LOAD & 100% FIELD EQUALITY AUDIT
# =============================================================================

func _suite_4_save_load_and_accounting(gs: Node, sm: Node) -> void:
	print("\n--- SUITE 4: Mid-Run Save / Load & 100% Field Equality Audit ---")

	# Build a rich mid-run state using real OSM preset house (which includes BOTH footprint_meters AND polygon_latlon Vector2 arrays!)
	var parsed_sea: Dictionary = OsmServiceRef.call("load_preset", "seattle")
	var sea_bldgs: Array = parsed_sea.get("buildings", [])
	var sea_pois: Array = parsed_sea.get("pois", [])
	var real_house: Dictionary = OsmServiceRef.call("pick_best_house", sea_bldgs, 47.6240, -122.3195, 206082403)
	var real_targets: Array = OsmServiceRef.call("build_nearby_targets_for_house", real_house, sea_bldgs, sea_pois, "Capitol Hill, Seattle, WA")

	gs.set("difficulty", "tsar_bomba")
	gs.set("game_mode", "challenge")
	gs.set("active_challenge_id", "cul_de_sac_odyssey")
	gs.call("init_default_family")
	gs.set("selected_house", real_house.duplicate(true))
	gs.set("nearby_pois", real_targets)
	gs.set("current_neighborhood_label", "Capitol Hill, Seattle, WA")
	gs.call("init_default_nuke")
	gs.call("reset_to_defaults")

	var fams: Array = gs.get("family_members")
	var test_hats: Array[String] = ["cd_helmet", "aviator", "medic_cap", "ushanka"]
	for i in range(fams.size()):
		var fm: Dictionary = fams[i]
		fm["in_bunker"] = (i < 3)
		fm["alive"] = (i < 3)
		fm["hat_id"] = test_hats[i % test_hats.size()]
		fm["hunger"] = i % 3
		fm["thirst"] = (i + 1) % 3
		fm["sanity"] = i % 3
		fm["sickness"] = 1 if i == 1 else 0
		fm["injury"] = 1 if i == 2 else 0
		fm["radiation"] = float(i) * 12.5
		fm["expedition_scars"] = i
	(fams[3] as Dictionary)["death_reason"] = "Left behind upstairs when the CONELRAD siren ended."
	gs.set("left_behind_members", ["Timmy"])

	BunkerSimRef.call("start_bunker_run")
	gs.set("day", 11)
	gs.set("soup_quarters", 19)
	gs.set("water_quarters", 23)
	gs.set("ammo_count", 5)
	gs.set("medkit_count", 2)
	gs.set("bug_spray_count", 1)
	gs.set("antibiotics_count", 3)
	gs.set("antirad_count", 2)
	gs.set("scrap_count", 4)
	gs.set("padlock_active", true)
	gs.set("fuel_cans", 2)
	gs.set("fuel_needed", 3)
	gs.set("vehicle_parts", {
		"battery": true,
		"alternator": true,
		"spark_plugs": false,
		"radiator_hose": true
	})
	gs.set("vehicle_tuned", true)
	gs.set("has_cat_sharikov", true)
	gs.set("has_dog_pancake", true)
	gs.set("roach_infestation", 1)
	gs.set("bunker_structural_integrity", 78.5)
	gs.set("surface_radiation_sv", 3.25)
	gs.set("bunker_temp_c", 14.5)

	for gid in ["suitcase", "gas_mask", "rifle", "map", "radio", "toolbox"]:
		gs.call("add_scavenged_item", gid, 1)
	gs.call("break_or_consume_item", "radio") # broken durable gear test

	gs.call("change_relationship", "member_0", "member_1", 42) # 20+42 = 62 (Devoted)
	gs.call("change_relationship", "member_0", "member_2", -58) # 20-58 = -38 (Resentful)
	gs.call("change_relationship", "member_1", "member_2", 15) # 35 (Loyal)

	gs.set("story_flags", {
		"helped_courier_day": 8,
		"planted_greens_day": 8,
		"vendetta_active": false,
		"custom_note": "alpha"
	})
	gs.set("rescue_chains", {
		"military": 2,
		"sanctuary": 1,
		"scientist": 2,
		"raider_pact": 1
	})

	# Draw an event on Day 11 so EventDeck has non-repeat history, AND launch an active Ring 3 expedition!
	var rng_sl := RandomNumberGenerator.new()
	rng_sl.seed = 98765
	var ev_pre_save: Dictionary = EventDeckRef.call("draw_daily_event", 11, rng_sl)
	var pre_save_ev_id: String = str(ev_pre_save.get("id", ""))

	var ring3_idx: int = 0
	var avail_t: Array = ExpeditionRef.call("get_available_targets")
	for ti in range(avail_t.size()):
		if int((avail_t[ti] as Dictionary).get("ring", 1)) >= 3:
			ring3_idx = ti
			break
	var launch_str: String = str(ExpeditionRef.call("start_expedition", "member_0", ring3_idx, ["suitcase", "gas_mask", "rifle", "map"]))
	_check(launch_str != "" and not (gs.get("active_expedition") as Dictionary).is_empty(),
		"Pre-save active Ring 3 expedition launched with 4 Suitcase-packed items", "msg='%s'" % launch_str)

	# Snapshot all fields prior to SaveManager.save_run()
	var snap: Dictionary = {
		"difficulty": gs.get("difficulty"),
		"game_mode": gs.get("game_mode"),
		"active_challenge_id": gs.get("active_challenge_id"),
		"day": gs.get("day"),
		"soup_quarters": gs.get("soup_quarters"),
		"water_quarters": gs.get("water_quarters"),
		"ammo_count": gs.get("ammo_count"),
		"medkit_count": gs.get("medkit_count"),
		"bug_spray_count": gs.get("bug_spray_count"),
		"antibiotics_count": gs.get("antibiotics_count"),
		"antirad_count": gs.get("antirad_count"),
		"scrap_count": gs.get("scrap_count"),
		"padlock_active": gs.get("padlock_active"),
		"fuel_cans": gs.get("fuel_cans"),
		"fuel_needed": gs.get("fuel_needed"),
		"vehicle_parts": (gs.get("vehicle_parts") as Dictionary).duplicate(true),
		"vehicle_tuned": gs.get("vehicle_tuned"),
		"bunker_items": (gs.get("bunker_items") as Dictionary).duplicate(true),
		"has_cat_sharikov": gs.get("has_cat_sharikov"),
		"has_dog_pancake": gs.get("has_dog_pancake"),
		"roach_infestation": gs.get("roach_infestation"),
		"bunker_structural_integrity": gs.get("bunker_structural_integrity"),
		"surface_radiation_sv": gs.get("surface_radiation_sv"),
		"bunker_temp_c": gs.get("bunker_temp_c"),
		"family_members": (gs.get("family_members") as Array).duplicate(true),
		"relationships": (gs.get("relationships") as Dictionary).duplicate(true),
		"recent_relationship_events": (gs.get("recent_relationship_events") as Array).duplicate(true),
		"selected_house": (gs.get("selected_house") as Dictionary).duplicate(true),
		"neighborhood_modifiers": (gs.get("neighborhood_modifiers") as Dictionary).duplicate(true),
		"current_neighborhood_label": gs.get("current_neighborhood_label"),
		"nuke_config": (gs.get("nuke_config") as Dictionary).duplicate(true),
		"left_behind_members": (gs.get("left_behind_members") as Array).duplicate(true),
		"story_flags": (gs.get("story_flags") as Dictionary).duplicate(true),
		"active_expedition": (gs.get("active_expedition") as Dictionary).duplicate(true),
		"rescue_chains": (gs.get("rescue_chains") as Dictionary).duplicate(true),
		"daily_log_entries": (gs.get("daily_log_entries") as Array).duplicate(true),
		"scavenge_stats": (gs.get("scavenge_stats") as Dictionary).duplicate(true),
		"run_metrics": (gs.get("run_metrics") as Dictionary).duplicate(true)
	}

	var save_ok: bool = bool(sm.call("save_run"))
	_check(save_ok and bool(sm.call("has_saved_run")), "SaveManager.save_run() writes user://savegame_v2.json cleanly")

	# Wipe GameState completely!
	gs.set("difficulty", "little_boy")
	gs.set("game_mode", "full_protocol")
	gs.set("active_challenge_id", "")
	gs.set("selected_house", {})
	gs.set("nearby_pois", [])
	gs.set("family_members", [])
	gs.call("reset_to_defaults")
	EventDeckRef.call("reset_state")

	var load_ok: bool = bool(sm.call("load_run"))
	_check(load_ok, "SaveManager.load_run() parses and restores user://savegame_v2.json cleanly")

	# Verify scalar & dictionary field equality
	var scalar_mismatches: Array[String] = []
	for sk in [
		"difficulty", "game_mode", "active_challenge_id", "day",
		"soup_quarters", "water_quarters", "ammo_count", "medkit_count", "bug_spray_count",
		"antibiotics_count", "antirad_count", "scrap_count", "padlock_active",
		"fuel_cans", "fuel_needed", "vehicle_tuned", "has_cat_sharikov", "has_dog_pancake",
		"roach_infestation", "current_neighborhood_label"
	]:
		if gs.get(sk) != snap[sk]:
			scalar_mismatches.append("%s: %s != %s" % [sk, str(gs.get(sk)), str(snap[sk])])
	for fk in ["bunker_structural_integrity", "surface_radiation_sv", "bunker_temp_c"]:
		if not is_equal_approx(float(gs.get(fk)), float(snap[fk])):
			scalar_mismatches.append("%s: %f != %f" % [fk, float(gs.get(fk)), float(snap[fk])])

	_check(scalar_mismatches.is_empty(), "100% scalar & specialty supply equality across save -> wipe -> load", "; ".join(scalar_mismatches))

	# Verify vehicle_parts, relationships, story_flags, rescue_chains, left_behind_members, bunker_items
	var dict_ok: bool = (
		_deep_equiv(gs.get("vehicle_parts"), snap["vehicle_parts"])
		and _deep_equiv(gs.get("relationships"), snap["relationships"])
		and _deep_equiv(gs.get("story_flags"), snap["story_flags"])
		and _deep_equiv(gs.get("rescue_chains"), snap["rescue_chains"])
		and _deep_equiv(gs.get("left_behind_members"), snap["left_behind_members"])
		and _deep_equiv(gs.get("bunker_items"), snap["bunker_items"])
		and _deep_equiv(gs.get("family_members"), snap["family_members"])
		and _deep_equiv(gs.get("active_expedition"), snap["active_expedition"])
	)
	_check(dict_ok, "100% deep value equality for family_members (hats/scars/stats), relationships, vehicle_parts, bunker_items, active_expedition & story_flags")

	# Check recent_relationship_events persistence!
	var rel_events_preserved: bool = _deep_equiv(gs.get("recent_relationship_events"), snap["recent_relationship_events"])
	_check(
		rel_events_preserved,
		"GameState.recent_relationship_events persists across save_run() -> reset_to_defaults() -> load_run()",
		"SaveManager.save_run/load_run (scripts/core/save_manager.gd:165-206, 271-314) omits recent_relationship_events (had %d entries before save, got %d after load)" % [
			(snap["recent_relationship_events"] as Array).size(), (gs.get("recent_relationship_events") as Array).size()
		]
	)

	# Check Vector2 restoration on selected_house["footprint_meters"] AND selected_house["polygon_latlon"]!
	var loaded_house: Dictionary = gs.get("selected_house")
	var fp_arr: Array = loaded_house.get("footprint_meters", [])
	var fp_all_vec2: bool = not fp_arr.is_empty()
	for pt in fp_arr:
		if not (pt is Vector2):
			fp_all_vec2 = false
			break
	_check(fp_all_vec2 and fp_arr.size() == (snap["selected_house"]["footprint_meters"] as Array).size(),
		"selected_house['footprint_meters'] restored as typed Vector2 elements (%d vertices)" % fp_arr.size())

	var orig_ll: Array = (snap["selected_house"] as Dictionary).get("polygon_latlon", [])
	var loaded_ll: Array = loaded_house.get("polygon_latlon", [])
	var ll_all_vec2: bool = (orig_ll.size() == loaded_ll.size())
	for pt_ll in loaded_ll:
		if not (pt_ll is Vector2):
			ll_all_vec2 = false
			break
	_check(
		ll_all_vec2,
		"selected_house['polygon_latlon'] restored as typed Vector2 elements across save -> load",
		"SaveManager.save_run (scripts/core/save_manager.gd:156-163) converts polygon_latlon Vector2s to {x,y} Dictionaries, but SaveManager.load_run (scripts/core/save_manager.gd:279-290) forgets to convert polygon_latlon back to Array[Vector2] (crashes OsmSlippyMap:821 if revisited!)"
	)

	# Check EventDeck non-repeat history persistence across save/load
	var recent_ids_after_load: Array = EventDeckRef.get("_recent_event_ids")
	_check(
		recent_ids_after_load.has(pre_save_ev_id),
		"EventDeck 16-day non-repeat history (_recent_event_ids) & _last_rescue_day persist across save_run() -> load_run()",
		"SaveManager.save_run/load_run (scripts/core/save_manager.gd:165-206) does not serialize EventDeck._recent_event_ids or _last_rescue_day (scripts/events/event_deck.gd:161-163), so loading a save wipes the 16-day non-repeat buffer!"
	)

	# Post-load gameplay continuation: advance days until active Ring 3 expedition returns & delayed story_flags fire!
	var post_load_days: int = 0
	while not (gs.get("active_expedition") as Dictionary).is_empty() and post_load_days < 6:
		BunkerSimRef.call("advance_day", {"member_1": {"soup_q": 1, "water_q": 1}, "member_2": {"soup_q": 1, "water_q": 1}})
		_verify_resource_invariants(gs, "post_load_tick_%d" % post_load_days)
		post_load_days += 1

	var ted_post_exp: Dictionary = (gs.get("family_members") as Array)[0]
	var ready_conseq: Array = EventDeckRef.call("_get_ready_consequence_event_ids", int(gs.get("day")))
	_check(
		(gs.get("active_expedition") as Dictionary).is_empty()
		and not bool(ted_post_exp.get("on_expedition", false))
		and bool(gs.call("has_working_item", "suitcase"))
		and ready_conseq.has("courier_repayment_drop")
		and ready_conseq.has("sprouted_bunker_greens"),
		"Post-load continuation: active Ring 3 expedition returns cleanly with checked-out Suitcase gear restored and delayed story_flags ('courier_repayment_drop', 'sprouted_bunker_greens') unlock on schedule"
	)

	# Also verify neighborhood_modifiers gameplay wiring audit
	var urban_mods: Dictionary = {"early_raider_mod": 0.12, "ration_abundance": 1.30}
	var culdesac_mods: Dictionary = {"early_raider_mod": -0.12, "ration_abundance": 0.80}
	gs.set("neighborhood_modifiers", urban_mods)
	var raid_w_urban: float = float(EventDeckRef.call("_get_event_weight", "raiders_blast_hatch", 8))
	gs.set("neighborhood_modifiers", culdesac_mods)
	var raid_w_suburb: float = float(EventDeckRef.call("_get_event_weight", "raiders_blast_hatch", 8))
	_check(
		not is_equal_approx(raid_w_urban, raid_w_suburb),
		"GameState.neighborhood_modifiers ('early_raider_mod' promised in OsmService:1019,1035,1041) affects raider event/ambush rates",
		"GameState.neighborhood_modifiers is computed & displayed on HouseSelectScreen, but NEVER read in EventDeck._get_event_weight (scripts/events/event_deck.gd:408) or ExpeditionEngine._compute_bandit_risk_prob (scripts/expedition/expedition_engine.gd:95,436) (urban_w=%.3f == suburb_w=%.3f)!" % [raid_w_urban, raid_w_suburb]
	)

# =============================================================================
# MATH & EQUIVALENCE UTILITIES + QUANTITATIVE REPORT PRINTER
# =============================================================================

func _deep_equiv(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_INT and typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_INT:
		return is_equal_approx(float(a), float(b))
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k in da.keys():
			if not db.has(k) or not _deep_equiv(da[k], db[k]):
				return false
		return true
	if a is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in range(aa.size()):
			if not _deep_equiv(aa[i], ab[i]):
				return false
		return true
	if a is Vector2:
		return (a as Vector2).is_equal_approx(b as Vector2)
	return a == b

func _mean_int(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s: float = 0.0
	for v in arr:
		s += float(v)
	return s / float(arr.size())

func _median_int(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sorted: Array = arr.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	if n % 2 == 1:
		return float(sorted[n / 2])
	return 0.5 * (float(sorted[n / 2 - 1]) + float(sorted[n / 2]))

func _min_int(arr: Array) -> int:
	if arr.is_empty():
		return 0
	var m: int = int(arr[0])
	for v in arr:
		m = mini(m, int(v))
	return m

func _max_int(arr: Array) -> int:
	if arr.is_empty():
		return 0
	var m: int = int(arr[0])
	for v in arr:
		m = maxi(m, int(v))
	return m

func _print_quantitative_report() -> void:
	print("\n=========================================================================")
	print("QUANTITATIVE V2 PLAYTEST METRICS SUMMARY")
	print("=========================================================================")
	for diff_id in ["little_boy", "fat_man", "tsar_bomba"]:
		if not diff_metrics.has(diff_id):
			continue
		var dm: Dictionary = diff_metrics[diff_id]
		print("DIFFICULTY [%s] (n=%d): mean=%.1f days | median=%.1f days | range=%d..%d | win_rate=%.1f%% (%d/10) | exps=%d (deep=%d)" % [
			diff_id, int(dm["runs"]), float(dm["mean_days"]), float(dm["median_days"]),
			int(dm["min_days"]), int(dm["max_days"]), float(dm["win_rate_pct"]), int(dm["wins"]),
			int(dm["expeditions_completed"]), int(dm["distant_looted"])
		])
		print("  Routes Won: %s" % str(dm["routes_won"]))
		print("  Run Defeat Causes: %s" % str(dm["defeat_causes"]))
		print("  Individual Survivor Deaths: %s" % str(dm["indiv_deaths"]))

	for mk in mode_metrics.keys():
		print("MODE [%s]: %s" % [str(mk), str(mode_metrics[mk])])

	var tot_win_draws: int = 0
	var tot_rep_all: int = 0
	var tot_rep_nr: int = 0
	var tot_16_all: int = 0
	var tot_16_nr: int = 0
	for ws in all_window_stats:
		tot_win_draws += int(ws["total_in_25d_windows"])
		tot_rep_all += int(ws["repeats_25d_all"])
		tot_rep_nr += int(ws["repeats_25d_non_rescue"])
		tot_16_all += int(ws["buffer_16d_violations_all"])
		tot_16_nr += int(ws["buffer_16d_violations_non_rescue"])

	print("EVENT REPETITION (Playthrough 25d windows, n=%d window-draws): overall=%.2f%% (%d) | non-rescue=%.2f%% (%d) | 16d-buffer-violations: overall=%d, non-rescue=%d" % [
		tot_win_draws,
		100.0 * float(tot_rep_all) / float(maxi(1, tot_win_draws)), tot_rep_all,
		100.0 * float(tot_rep_nr) / float(maxi(1, tot_win_draws)), tot_rep_nr,
		tot_16_all, tot_16_nr
	])
	print("DYNAMIC DECISION VARIETY (n=%d drawn events): >=3 defined opts=%.1f%% | >=3 simultaneously available opts=%.1f%% | non-trivial trade-off=%.1f%%" % [
		dynamic_events_drawn,
		100.0 * float(dynamic_events_ge3_total_opts) / float(maxi(1, dynamic_events_drawn)),
		100.0 * float(dynamic_events_ge3_avail_opts) / float(maxi(1, dynamic_events_drawn)),
		100.0 * float(dynamic_events_with_tradeoff) / float(maxi(1, dynamic_events_drawn))
	])
