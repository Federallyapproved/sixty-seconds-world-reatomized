extends SceneTree

## V2 Visual Art Direction, 3D Diorama, Shelter Deterioration & UI Layout Critic Audit.
## Renders all 18 required 1280x720 PNG states to /home/antigravity/sixty_seconds_world/screenshots/v2_*.png
## without modifying any files under scripts/ or scenes/, and calls SoundManager.shutdown_audio() before quit(0).

func _init() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var out_dir: String = "/home/antigravity/sixty_seconds_world/screenshots"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var gs: Node = root.get_node("GameState")
	var sm: Node = root.get_node("SaveManager")
	var snd: Node = root.get_node_or_null("SoundManager")

	# Back up any existing user save / meta files so we restore user:// cleanly on exit
	var save_path: String = "user://savegame_v2.json"
	var meta_path: String = "user://meta_profile_v2.json"
	var had_orig_save: bool = FileAccess.file_exists(save_path)
	var orig_save_txt: String = ""
	if had_orig_save:
		var fs_orig: FileAccess = FileAccess.open(save_path, FileAccess.READ)
		if fs_orig != null:
			orig_save_txt = fs_orig.get_as_text()
			fs_orig.close()

	var had_orig_meta: bool = FileAccess.file_exists(meta_path)
	var orig_meta_txt: String = ""
	if had_orig_meta:
		var fm_orig: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
		if fm_orig != null:
			orig_meta_txt = fm_orig.get_as_text()
			fm_orig.close()

	gs.set("demo_mode", false)
	gs.set("headless_fast_test", false)
	var rng_obj: RandomNumberGenerator = gs.get("rng") as RandomNumberGenerator
	if rng_obj != null:
		rng_obj.seed = 20261123

	# Seed SaveManager BEFORE instantiating main.tscn so TitleScreen builds with:
	# - [ CONTINUE SAVED SHELTER — DAY 9 ]
	# - Chassis Tier 2 & 7/16 Achievements + Unlocked Hats (cd_helmet, aviator, medic_cap, ushanka)
	var meta_dict: Dictionary = sm.get("meta") as Dictionary
	meta_dict["vehicle_chassis_tier"] = 2
	meta_dict["total_vehicle_parts_banked"] = 5
	meta_dict["runs_played"] = 7
	meta_dict["victories"] = 3
	meta_dict["longest_days"] = 22
	meta_dict["best_scavenge_items"] = 19
	meta_dict["unlocked_hats"] = ["none", "cd_helmet", "aviator", "medic_cap", "ushanka"]
	meta_dict["unlocked_achievements"] = {
		"first_seal": 1763850000,
		"full_house": 1763850100,
		"pack_mule": 1763850200,
		"road_warrior_parts": 1763850300,
		"highway_breakout": 1763850400,
		"doctor_house": 1763850500,
		"unbreakable_bond": 1763850600
	}
	sm.call("save_meta")

	gs.set("day", 9)
	gs.set("soup_quarters", 14)
	gs.set("water_quarters", 16)
	sm.call("save_run")
	gs.set("day", 1)

	var main_packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var main_inst: Control = main_packed.instantiate() as Control
	root.add_child(main_inst)

	# =========================================================================
	# 1. v2_01_title.png — V2 Title Screen (Continue Saved Shelter, Difficulty, Modes)
	# =========================================================================
	await _settle_screen(main_inst, 18)
	await _snap(out_dir + "/v2_01_title.png")

	# =========================================================================
	# 2. v2_02_title_challenges_modal.png — Title Screen with Special Challenges (3) modal
	# =========================================================================
	var title_scr: Control = main_inst.get("_active_node") as Control
	if is_instance_valid(title_scr):
		title_scr.call("open_challenges_modal")
		await _wait_frames(12)
		await _snap(out_dir + "/v2_02_title_challenges_modal.png")
		title_scr.call("close_challenges_modal")
		await _wait_frames(6)

		# =====================================================================
		# 3. v2_03_title_achievements_modal.png — Achievements & Garage Tier (Tier 2) modal
		# =====================================================================
		title_scr.call("open_achievements_modal")
		await _wait_frames(12)
		await _snap(out_dir + "/v2_03_title_achievements_modal.png")
		title_scr.call("close_achievements_modal")
		await _wait_frames(6)

	# =========================================================================
	# 4. v2_04_family_hats_deterioration.png — Family Creator showing unlocked Hat
	#    (cd_helmet & aviator) + Soot/Breakdown/Betrayed preview!
	# =========================================================================
	gs.call("request_screen", "family")
	await _settle_screen(main_inst, 16)
	var fam_scr: Control = main_inst.get("_active_node") as Control
	if is_instance_valid(fam_scr):
		var members: Array = gs.get("family_members") as Array
		if members.size() >= 4:
			var m0: Dictionary = members[0] as Dictionary
			m0["name"] = "Ted"
			m0["age"] = 44
			m0["role"] = "adult"
			m0["is_leader"] = true
			m0["skin_tone"] = 2
			m0["hair_style"] = 1
			m0["hair_color"] = "#4a2e1b"
			m0["facial_hair"] = 2
			m0["glasses"] = true
			m0["outfit_color"] = "#c84b31"
			m0["shirt_style"] = 4
			m0["hat_id"] = "cd_helmet"
			m0["soot_days"] = 2

			var m1: Dictionary = members[1] as Dictionary
			m1["name"] = "Dolores"
			m1["age"] = 39
			m1["role"] = "adult"
			m1["skin_tone"] = 1
			m1["hair_style"] = 3
			m1["hair_color"] = "#e85ca8"
			m1["glasses"] = true
			m1["outfit_color"] = "#3d7a8a"
			m1["shirt_style"] = 2
			m1["hat_id"] = "aviator"
			m1["soot_days"] = 2
			m1["breakdown_days"] = 2
			m1["sanity"] = 2

			var m2: Dictionary = members[2] as Dictionary
			m2["name"] = "Mary Jane"
			m2["age"] = 16
			m2["role"] = "teen"
			m2["skin_tone"] = 0
			m2["hair_style"] = 4
			m2["hair_color"] = "#2bc4d8"
			m2["glasses"] = false
			m2["outfit_color"] = "#7b4b94"
			m2["shirt_style"] = 3
			m2["hat_id"] = "medic_cap"
			m2["soot_days"] = 2
			m2["injury"] = 1

			var m3: Dictionary = members[3] as Dictionary
			m3["name"] = "Timmy"
			m3["age"] = 10
			m3["role"] = "child"
			m3["skin_tone"] = 3
			m3["hair_style"] = 5
			m3["hair_color"] = "#e06d2b"
			m3["glasses"] = true
			m3["outfit_color"] = "#d99b26"
			m3["shirt_style"] = 1
			m3["hat_id"] = "ushanka"
			m3["betrayed"] = true
			m3["alive"] = false

		fam_scr.set("selected_index", 1) # Dolores with Aviator hat (while Roster shows Ted w/ CD Helmet + Soot, Mary Jane w/ Medic Cap + Soot + Bandage, Timmy w/ Betrayed DESERTED!)
		fam_scr.call("_on_condition_preview_selected", "insane")
		# Re-apply runtime preview flags after _refresh_all_ui so roster portraits show Soot/Breakdown/Betrayed alongside Aviator Hat!
		if members.size() >= 4:
			(members[0] as Dictionary)["soot_days"] = 2
			(members[1] as Dictionary)["soot_days"] = 2
			(members[1] as Dictionary)["breakdown_days"] = 2
			(members[1] as Dictionary)["sanity"] = 2
			(members[2] as Dictionary)["soot_days"] = 2
			(members[2] as Dictionary)["injury"] = 1
			(members[3] as Dictionary)["betrayed"] = true
			(members[3] as Dictionary)["alive"] = false
		fam_scr.call("_refresh_all_ui")
		await _wait_frames(14)
		await _snap(out_dir + "/v2_04_family_hats_deterioration.png")

		# Restore healthy living flags on all 4 customized survivors (keeping their Hats!)
		fam_scr.call("_on_condition_preview_selected", "healthy")
		gs.call("reset_family_runtime_status")
		if members.size() >= 4:
			(members[0] as Dictionary)["hat_id"] = "cd_helmet"
			(members[1] as Dictionary)["hat_id"] = "aviator"
			(members[2] as Dictionary)["hat_id"] = "medic_cap"
			(members[3] as Dictionary)["hat_id"] = "ushanka"

	# =========================================================================
	# 5. v2_05_osm_walborough_all.png — House Select on Suburban VA (6217 Walborough Ct) All
	# =========================================================================
	gs.call("request_screen", "osm_house")
	await _settle_screen(main_inst, 20)
	var house_scr: Control = main_inst.get("_active_node") as Control
	var walborough_house: Dictionary = {}
	var walborough_pois: Array = []
	var walborough_mods: Dictionary = {}
	var walborough_label: String = "Suburban VA (Walborough Ct)"
	if is_instance_valid(house_scr):
		house_scr.call("_load_preset_neighborhood", "wyndham", false)
		await create_timer(1.6).timeout
		await _wait_frames(20)
		await _snap(out_dir + "/v2_05_osm_walborough_all.png")

		# =====================================================================
		# 6. v2_06_osm_walborough_deep_zoom.png — Suburban VA switched to Deep 3.5km+ (Z13)
		# =====================================================================
		house_scr.call("_set_ring_filter", 3, true)
		await create_timer(1.6).timeout
		await _wait_frames(20)
		await _snap(out_dir + "/v2_06_osm_walborough_deep_zoom.png")

		# Reset ring filter to All and cache Walborough house + multi-ring POIs
		house_scr.call("_set_ring_filter", 0, false)
		await _wait_frames(6)
		walborough_house = (gs.get("selected_house") as Dictionary).duplicate(true)
		walborough_pois = (gs.get("nearby_pois") as Array).duplicate(true)
		walborough_mods = (gs.get("neighborhood_modifiers") as Dictionary).duplicate(true)
		walborough_label = str(gs.get("current_neighborhood_label"))

	# =========================================================================
	# 7. v2_07_nuke_screen.png — Nuke Detonation Selector
	# =========================================================================
	gs.call("request_screen", "nuke")
	await _settle_screen(main_inst, 20)
	var nuke_scr: Control = main_inst.get("_active_node") as Control
	if is_instance_valid(nuke_scr):
		nuke_scr.call("set_map_mode", "regional")
		nuke_scr.call("_on_preset_button_pressed", 0)
		await _wait_frames(36)
		await _snap(out_dir + "/v2_07_nuke_screen.png")

	# =========================================================================
	# 8. v2_08_scavenge_3d_recon.png — 3D Isometric Scavenge House in warm Recon light
	# =========================================================================
	gs.call("request_screen", "scavenge")
	await _settle_screen(main_inst, 22)
	var scav_scr: Node2D = main_inst.get("_active_node") as Node2D
	if is_instance_valid(scav_scr):
		await _wait_frames(14)
		await _snap(out_dir + "/v2_08_scavenge_3d_recon.png")

		# =====================================================================
		# 9. v2_09_scavenge_3d_siren_carrying.png — 3D Isometric Scavenge House at T = 11.0s
		#    (red CONELRAD siren light active, player carrying 3D stack + 5-slot Suitcase bar!)
		# =====================================================================
		scav_scr.call("trigger_hud_skip_scout")
		await _wait_frames(8)

		var world_items: Array = scav_scr.get("_world_items") as Array
		var world_fam: Array = scav_scr.get("_world_family") as Array
		var hatch_p: Vector2 = scav_scr.get("_hatch_pos") as Vector2

		# Step A: Pick up & deposit Suitcase + 2 rations into hatch to unlock 5-slot Suitcase Carry Bar!
		var found_suitcase: bool = false
		for it_v in world_items:
			var it_d: Dictionary = it_v as Dictionary
			if str(it_d.get("item_id", "")) == "suitcase" and not bool(it_d.get("collected", false)):
				scav_scr.call("_attempt_pickup_target", {
					"kind": "item",
					"uid": int(it_d.get("uid", 0)),
					"pos": it_d.get("pos", hatch_p),
					"slots": int(it_d.get("slots", 2)),
					"name": str(it_d.get("name", "Suitcase")),
					"item_id": "suitcase",
					"ref": it_d
				})
				found_suitcase = true
				break
		if found_suitcase:
			scav_scr.call("_deposit_carried_into_hatch")
		else:
			scav_scr.set("_suitcase_upgraded", true)
			scav_scr.set("_max_slots", 5)

		var dep_count: int = 0
		for it_v2 in world_items:
			if dep_count >= 2:
				break
			var it_d2: Dictionary = it_v2 as Dictionary
			if int(it_d2.get("slots", 1)) == 1 and not bool(it_d2.get("collected", false)):
				scav_scr.call("_attempt_pickup_target", {
					"kind": "item",
					"uid": int(it_d2.get("uid", 0)),
					"pos": it_d2.get("pos", hatch_p),
					"slots": 1,
					"name": str(it_d2.get("name", "Item")),
					"item_id": str(it_d2.get("item_id", "soup")),
					"ref": it_d2
				})
				dep_count += 1
		scav_scr.call("_deposit_carried_into_hatch")

		# Move player away from hatch into a clear room so carried stack stays on player's back/arms!
		var stand_pos: Vector2 = hatch_p + Vector2(135.0, -90.0)
		for it_v3 in world_items:
			var it_d3: Dictionary = it_v3 as Dictionary
			if not bool(it_d3.get("collected", false)):
				var cand: Vector2 = it_d3.get("pos", stand_pos) as Vector2
				if cand.distance_to(hatch_p) > 115.0:
					stand_pos = cand
					break
		var resolved_pos: Vector2 = scav_scr.call("_resolve_collisions", stand_pos, false) as Vector2
		scav_scr.set("_player_pos", resolved_pos)
		scav_scr.set("_player_facing", Vector2(0.45, 0.89).normalized())
		scav_scr.set("_floating_popups", [])

		# Fill all 5/5 Suitcase slots: 1 2-slot family member + 3 1-slot items!
		for f_v in world_fam:
			var fd: Dictionary = f_v as Dictionary
			if int(fd.get("slots", 2)) == 2 and not bool(fd.get("collected", false)):
				scav_scr.call("_attempt_pickup_target", {
					"kind": "family",
					"uid": int(fd.get("uid", 1000)),
					"pos": fd.get("pos", resolved_pos),
					"slots": 2,
					"name": str(fd.get("name", "Mary Jane")),
					"ref": fd
				})
				break

		var carried_cnt: int = 0
		for it_v4 in world_items:
			if carried_cnt >= 3:
				break
			var it_d4: Dictionary = it_v4 as Dictionary
			if int(it_d4.get("slots", 1)) == 1 and not bool(it_d4.get("collected", false)):
				scav_scr.call("_attempt_pickup_target", {
					"kind": "item",
					"uid": int(it_d4.get("uid", 0)),
					"pos": it_d4.get("pos", resolved_pos),
					"slots": 1,
					"name": str(it_d4.get("name", "Item")),
					"item_id": str(it_d4.get("item_id", "soup")),
					"ref": it_d4
				})
				carried_cnt += 1

		# Set timer so after 10 frames (~0.16s) _scavenge_time_left == 11.0s and siren klaxon is at peak red glow!
		scav_scr.set("_siren_15_played", true)
		scav_scr.set("_scavenge_time_left", 11.16)
		scav_scr.set("_last_whole_sec", 12)
		scav_scr.set("_anim_time", 1.18) # After ~0.16s -> 1.34 * 10.5 = 14.07 rad -> sin() ~ +0.995 (peak red siren!)
		scav_scr.set("_floating_popups", [])
		await _wait_frames(10)
		scav_scr.set("_scavenge_time_left", 11.0)
		await _wait_frames(1)
		await _snap(out_dir + "/v2_09_scavenge_3d_siren_carrying.png")

	# =========================================================================
	# 10. v2_10_bunker_pristine_day1.png — Shelter Interior (Notebook minimized, Day 1 clean)
	# =========================================================================
	if not walborough_house.is_empty():
		gs.set("selected_house", walborough_house.duplicate(true))
		gs.set("nearby_pois", walborough_pois.duplicate(true))
		gs.set("neighborhood_modifiers", walborough_mods.duplicate(true))
		gs.set("current_neighborhood_label", walborough_label)

	var b_members: Array = gs.get("family_members") as Array
	for bm_v in b_members:
		var bm: Dictionary = bm_v as Dictionary
		bm["in_bunker"] = true
		bm["alive"] = true
		bm["betrayed"] = false
		bm["on_expedition"] = false
		bm["hunger"] = 0
		bm["thirst"] = 0
		bm["sickness"] = 0
		bm["injury"] = 0
		bm["sanity"] = 0
		bm["fatigue"] = 0
		bm["radiation"] = 0.0
		bm["soot_days"] = 0
		bm["breakdown_days"] = 0
		bm["is_mutant"] = false
		bm["last_bubble"] = ""
		bm["status_note"] = "Safe inside the fallout shelter."

	gs.call("init_relationships", 28)
	gs.set("day", 1)
	gs.set("bunker_structural_integrity", 98.0)
	gs.set("roach_infestation", 0)
	gs.set("surface_radiation_sv", 3.2)
	gs.set("bunker_temp_c", 21.0)
	gs.set("soup_quarters", 22)
	gs.set("water_quarters", 25)
	gs.set("medkit_count", 2)
	gs.set("antibiotics_count", 2)
	gs.set("antirad_count", 2)
	gs.set("scrap_count", 3)
	gs.set("bug_spray_count", 1)
	gs.set("ammo_count", 6)
	gs.set("padlock_active", true)
	gs.set("has_cat_sharikov", true)
	gs.set("has_dog_pancake", true)
	gs.set("fuel_cans", 1)
	gs.set("fuel_needed", 3)
	gs.set("vehicle_tuned", false)
	gs.set("vehicle_parts", {
		"battery": true,
		"radiator_hose": true,
		"alternator": false,
		"spark_plugs": false
	})
	gs.set("rescue_chains", {"military": 0, "sanctuary": 0, "scientist": 0, "raider_pact": 0})
	gs.set("daily_log_entries", [])

	var b_items: Dictionary = gs.get("bunker_items") as Dictionary
	for gid in ["gas_mask", "radio", "rifle", "map", "book", "suitcase", "cards", "toolbox", "flashlight", "axe"]:
		if b_items.has(gid):
			b_items[gid] = {"owned": true, "broken": false, "count": 1, "checked_out": false}

	gs.call("request_screen", "bunker")
	await _settle_screen(main_inst, 20)
	var bunker_scr: Control = main_inst.get("_active_node") as Control
	if is_instance_valid(bunker_scr):
		# Clear any Day 1 achievement toast so Day 1 interior view is completely unobstructed
		var toast_ov: Control = bunker_scr.get("_toast_overlay") as Control
		if is_instance_valid(toast_ov):
			toast_ov.visible = false
		bunker_scr.call("set_notebook_visible", false)
		await _wait_frames(15)
		await _snap(out_dir + "/v2_10_bunker_pristine_day1.png")
		if is_instance_valid(toast_ov):
			toast_ov.visible = true

		# =====================================================================
		# 11. v2_11_bunker_deteriorated_day16.png — Day 16 Deteriorated Shelter Interior:
		#     hull = 42%, roach_infestation = 2, surface_radiation_sv = 7.5, bunker_temp_c = -8.0
		#     frost + breath puffs, cobwebs, wall cracks, drip puddle, peeling poster,
		#     3/4 Station Wagon Engine Workbench, Hats, Soot, Bandages, ♥ & ⚡ bubbles!
		# =====================================================================
		gs.set("day", 16)
		gs.set("bunker_structural_integrity", 42.0)
		gs.set("roach_infestation", 2)
		gs.set("surface_radiation_sv", 7.5)
		gs.set("bunker_temp_c", -8.0)
		gs.set("soup_quarters", 13)
		gs.set("water_quarters", 15)
		gs.set("fuel_cans", 2)
		gs.set("fuel_needed", 3)
		gs.set("vehicle_parts", {
			"battery": true,
			"radiator_hose": true,
			"alternator": true,
			"spark_plugs": false
		})
		gs.set("rescue_chains", {"military": 2, "sanctuary": 1, "scientist": 2, "raider_pact": 1})
		if b_items.has("flashlight"):
			b_items["flashlight"] = {"owned": true, "broken": true, "count": 1, "checked_out": false}

		if b_members.size() >= 4:
			var bm0: Dictionary = b_members[0] as Dictionary
			bm0["hat_id"] = "cd_helmet"
			bm0["soot_days"] = 2
			bm0["injury"] = 1
			bm0["last_bubble"] = "♥"

			var bm1: Dictionary = b_members[1] as Dictionary
			bm1["hat_id"] = "aviator"
			bm1["soot_days"] = 1
			bm1["sickness"] = 1
			bm1["last_bubble"] = "♥"

			var bm2: Dictionary = b_members[2] as Dictionary
			bm2["hat_id"] = "medic_cap"
			bm2["soot_days"] = 2
			bm2["injury"] = 2
			bm2["hunger"] = 1
			bm2["radiation"] = 42.0
			bm2["last_bubble"] = "⚡"

			var bm3: Dictionary = b_members[3] as Dictionary
			bm3["hat_id"] = "ushanka"
			bm3["thirst"] = 2
			bm3["sanity"] = 2
			bm3["breakdown_days"] = 1
			bm3["last_bubble"] = "⚡"

		# Set Devoted (+68) between Ted & Dolores, and Resentful (-46) involving Mary Jane & Timmy
		gs.set("relationships", {
			"member_0|member_1": 68,
			"member_0|member_2": 24,
			"member_0|member_3": 12,
			"member_1|member_2": 32,
			"member_1|member_3": -18,
			"member_2|member_3": -52
		})

		gs.set("daily_log_entries", [
			{
				"day": 14,
				"title": "DAY 14 — KROGER & VERA CLINIC EXPEDITION HAUL",
				"lines": [
					"Ted returned soot-streaked from Vera Whole Health (Ring 2, 1.8 km) carrying Prescription Antibiotics and an Alternator salvaged along Twin Hickory.",
					"Ted & Dolores shared coats in the -8°C Nuclear Winter chill (+8 Devoted bond)."
				]
			},
			{
				"day": 16,
				"title": "DAY 16 — SUB-ZERO FROST, SEEPING CRACKS & ROACH SWARM",
				"lines": [
					"Surface fallout spiked to 7.5 Sv/hr around 6217 Walborough Ct, casting an eerie green Cherenkov glow around the blast hatch.",
					"Structural hull dropped to 42% — groundwater is dripping into a floor puddle and roaches are swarming the drain grate!",
					"Mary Jane & Timmy argued bitterly over cold soup rations (⚡ -12 relationship), while Ted & Dolores kept engine repairs on track (♥ 3/4 Station Wagon parts installed)."
				]
			}
		])

		bunker_scr.call("_on_external_state_changed")
		bunker_scr.call("_rebuild_all_tabs")
		bunker_scr.call("set_notebook_visible", false)
		await _wait_frames(18)
		await _snap(out_dir + "/v2_11_bunker_deteriorated_day16.png")

		# =====================================================================
		# 12. v2_12_bunker_tab1_log_save.png — Notebook Tab 1 (1. LOG + [ SAVE SHELTER ])
		# =====================================================================
		bunker_scr.call("set_notebook_visible", true)
		bunker_scr.call("set_active_tab", 0)
		await _wait_frames(12)
		await _snap(out_dir + "/v2_12_bunker_tab1_log_save.png")

		# =====================================================================
		# 13. v2_13_bunker_tab2_care_bonds.png — Notebook Tab 2 (2. CARE & BONDS)
		# =====================================================================
		bunker_scr.call("set_active_tab", 1)
		bunker_scr.call("_adjust_member_ration", "member_2", "soup_q", 1)
		bunker_scr.call("_adjust_member_ration", "member_3", "water_q", 1)
		bunker_scr.set("_planned_medkit_member_id", "member_0")
		var abx_plan: Array[String] = ["member_1"]
		bunker_scr.set("_planned_antibiotics_ids", abx_plan)
		var ar_plan: Array[String] = ["member_2"]
		bunker_scr.set("_planned_antirad_ids", ar_plan)
		bunker_scr.call("_rebuild_tab_rations")
		await _wait_frames(12)
		await _snap(out_dir + "/v2_13_bunker_tab2_care_bonds.png")

		# =====================================================================
		# 14. v2_14_bunker_tab3_dilemma_cooperate.png — Notebook Tab 3 (3. DILEMMA w/ [COOPERATE])
		# =====================================================================
		var event_deck_script: Script = load("res://scripts/events/event_deck.gd") as Script
		var coop_ev: Dictionary = event_deck_script.call("build_event_by_id", "family_cooperate_pipe_burst", 16, gs.get("rng")) as Dictionary
		bunker_scr.set("_current_event", coop_ev)
		bunker_scr.set("_has_unresolved_dilemma", true)
		bunker_scr.set("_selected_event_choice_id", "cooperate_brace")
		bunker_scr.call("set_active_tab", 2)
		await _wait_frames(12)
		await _snap(out_dir + "/v2_14_bunker_tab3_dilemma_cooperate.png")

		# =====================================================================
		# 15. v2_15_bunker_tab4_osm_walborough.png — Notebook Tab 4 (4. OSM RADAR on 6217 Walborough Ct)
		# =====================================================================
		bunker_scr.set("_selected_ring_filter", 0)
		bunker_scr.call("_rebuild_tab_expedition")
		var avail_t: Array = bunker_scr.get("_available_targets") as Array
		var best_landmark_idx: int = 0
		for ti in range(avail_t.size()):
			var td: Dictionary = avail_t[ti] as Dictionary
			var tcat: String = str(td.get("category", ""))
			if tcat == "grocery" or tcat == "doctor":
				best_landmark_idx = ti
				break
		bunker_scr.set("_selected_poi_index", best_landmark_idx)
		var exp_gear: Array[String] = ["suitcase", "gas_mask", "map"]
		bunker_scr.set("_selected_gear_ids", exp_gear)
		bunker_scr.call("set_active_tab", 3)
		await _wait_frames(14)
		await _snap(out_dir + "/v2_15_bunker_tab4_osm_walborough.png")

		# =====================================================================
		# 16. v2_16_bunker_tab5_escape_ready.png — Notebook Tab 5 (5. ESCAPE Ready!)
		# =====================================================================
		gs.set("vehicle_parts", {
			"battery": true,
			"radiator_hose": true,
			"alternator": true,
			"spark_plugs": true
		})
		gs.set("fuel_cans", 3)
		gs.set("fuel_needed", 3)
		gs.set("vehicle_tuned", true)
		gs.set("scrap_count", 2)
		bunker_scr.call("_on_external_state_changed")
		bunker_scr.call("set_active_tab", 4)
		await _wait_frames(14)
		await _snap(out_dir + "/v2_16_bunker_tab5_escape_ready.png")

	# =========================================================================
	# 17. v2_17_summary_vehicle_victory.png — Summary Dossier (HIGHWAY BREAKOUT + Tier Upgrade!)
	# =========================================================================
	meta_dict["vehicle_chassis_tier"] = 1 # So escaping by vehicle upgrades Tier 1 -> Tier 2!
	sm.call("save_meta")
	gs.set("scavenge_stats", {"items_collected": 16, "family_saved": 4})
	gs.set("run_metrics", {
		"expeditions_completed": 5,
		"distant_landmarks_looted": 4,
		"arguments_had": 2,
		"bonds_formed": 4,
		"events_resolved": 15
	})
	gs.set("left_behind_members", [])
	var bsim_script: Script = load("res://scripts/bunker/bunker_sim.gd") as Script
	bsim_script.call("execute_vehicle_escape")
	gs.call("request_screen", "summary")
	await _settle_screen(main_inst, 34)
	await _snap(out_dir + "/v2_17_summary_vehicle_victory.png")

	# =========================================================================
	# 18. v2_18_summary_betrayal_defeat.png — Summary Dossier (DESERTED Betrayal + LEFT BEHIND!)
	# =========================================================================
	var d_members: Array = gs.get("family_members") as Array
	if d_members.size() >= 4:
		var dm0: Dictionary = d_members[0] as Dictionary
		dm0["alive"] = false
		dm0["in_bunker"] = true
		dm0["betrayed"] = false
		dm0["death_reason"] = "Collapsed from severe dehydration on Day 14 after rations were stolen."

		var dm1: Dictionary = d_members[1] as Dictionary
		dm1["alive"] = false
		dm1["in_bunker"] = false
		dm1["betrayed"] = true
		dm1["death_reason"] = "Stole 1 Soup & 1 Water and abandoned the shelter in bitter betrayal on Day 12."

		var dm2: Dictionary = d_members[2] as Dictionary
		dm2["alive"] = false
		dm2["in_bunker"] = true
		dm2["betrayed"] = false
		dm2["death_reason"] = "Succumbed to untreated fallout radiation sickness in the freezing dark."

		var dm3: Dictionary = d_members[3] as Dictionary
		dm3["alive"] = false
		dm3["in_bunker"] = false
		dm3["betrayed"] = false
		dm3["death_reason"] = ""

	gs.set("left_behind_members", [{"id": "member_3", "name": "Timmy"}])
	gs.set("relationships", {
		"member_0|member_1": -84,
		"member_0|member_2": -28,
		"member_0|member_3": -22,
		"member_1|member_2": -78,
		"member_1|member_3": -60,
		"member_2|member_3": 15
	})
	gs.set("day", 14)
	gs.set("soup_quarters", 0)
	gs.set("water_quarters", 0)
	gs.set("bunker_structural_integrity", 19.0)
	gs.set("fuel_cans", 1)
	gs.set("vehicle_parts", {
		"battery": true,
		"radiator_hose": true,
		"alternator": false,
		"spark_plugs": false
	})
	gs.set("run_metrics", {
		"expeditions_completed": 3,
		"distant_landmarks_looted": 2,
		"arguments_had": 8,
		"bonds_formed": 0,
		"events_resolved": 13
	})
	gs.set("victory", false)
	gs.set("game_over", true)
	gs.set("ending_route", "")
	gs.set("ending_title", "SHELTER PROTOCOL TERMINATED — BETRAYED & LOST IN THE FALLOUT")
	gs.set("ending_description", "Haunted by leaving Timmy outside during the 60-second scramble and fractured by bitter rationing feuds, Dolores deserted with the last water reserves on Day 12. Radio silence followed on Day 14.")
	gs.call("request_screen", "summary")
	await _settle_screen(main_inst, 34)
	await _snap(out_dir + "/v2_18_summary_betrayal_defeat.png")

	# Restore original user:// files cleanly
	if had_orig_save:
		var fs_out: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if fs_out != null:
			fs_out.store_string(orig_save_txt)
			fs_out.close()
	else:
		sm.call("clear_saved_run")

	if had_orig_meta:
		var fm_out: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
		if fm_out != null:
			fm_out.store_string(orig_meta_txt)
			fm_out.close()
	elif FileAccess.file_exists(meta_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta_path))

	print("V2_VISUAL_AUDIT_COMPLETE")
	if snd != null and snd.has_method("shutdown_audio"):
		snd.call("shutdown_audio")
	quit(0)

func _settle_screen(main_inst: Control, frames: int) -> void:
	await _wait_frames(4)
	if is_instance_valid(main_inst):
		main_inst.set("_fade_alpha", 0.0)
		var fr: ColorRect = main_inst.get("_fade_rect") as ColorRect
		if is_instance_valid(fr):
			fr.color.a = 0.0
	await _wait_frames(frames)

func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(path)
		print("Saved V2 audit screenshot: " + path + " (" + str(img.get_width()) + "x" + str(img.get_height()) + ")")
