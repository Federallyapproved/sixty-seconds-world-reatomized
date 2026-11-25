extends SceneTree

## Ruthless Visual Direction, UI Layout & Screenshot Inspection Audit Script.
## Renders 14 distinct 1280x720 PNG states to <project>/screenshots/audit_*.png
## without modifying any game files under scripts/ or scenes/.

func _init() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var out_dir := ProjectSettings.globalize_path("res://").path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var main_packed: PackedScene = load("res://scenes/main.tscn")
	var main_inst: Control = main_packed.instantiate()
	root.add_child(main_inst)

	var gs: Node = root.get_node("GameState")
	gs.set("demo_mode", false)
	gs.get("rng").seed = 20261123

	# -------------------------------------------------------------------------
	# 1. TITLE SCREEN -> audit_01_title.png
	# -------------------------------------------------------------------------
	await _settle_screen(main_inst, 16)
	await _snap(out_dir + "/audit_01_title.png")

	# -------------------------------------------------------------------------
	# 2. FAMILY CUSTOMIZATION SCREEN -> audit_02_family_custom.png
	# Customize Hair Color (Pink/Cyan/Blonde), Hair Style (Afro/Pigtails/Beehive),
	# Age (Child vs Elder), Glasses, and Condition Preview (Mutant! / Insane!)
	# -------------------------------------------------------------------------
	gs.call("request_screen", "family")
	await _settle_screen(main_inst, 16)
	var fam_scr: Control = main_inst.get("_active_node")
	if is_instance_valid(fam_scr):
		var members: Array = gs.get("family_members")
		if members.size() >= 4:
			# Member 0: Elder (68) Leader, Voluminous Afro (5), Atomic Cyan (#2bc4d8), Glasses, Beard
			members[0]["name"] = "Ted"
			members[0]["age"] = 68
			members[0]["role"] = "elder"
			members[0]["scavenge_slots"] = 3
			members[0]["is_leader"] = true
			members[0]["skin_tone"] = 3
			members[0]["hair_style"] = 5 # Voluminous Afro
			members[0]["hair_color"] = "#2bc4d8" # Atomic Cyan
			members[0]["glasses"] = true
			members[0]["facial_hair"] = 2 # Full Beard
			members[0]["outfit_color"] = "#d99b26"
			members[0]["shirt_style"] = 4

			# Member 1: Elder (66), High Beehive (3), Bubblegum Pink (#e85ca8), Glasses
			members[1]["name"] = "Dolores"
			members[1]["age"] = 66
			members[1]["role"] = "elder"
			members[1]["scavenge_slots"] = 3
			members[1]["skin_tone"] = 1
			members[1]["hair_style"] = 3 # High Beehive
			members[1]["hair_color"] = "#e85ca8" # Bubblegum Pink
			members[1]["glasses"] = true
			members[1]["outfit_color"] = "#7b4b94"
			members[1]["shirt_style"] = 2

			# Member 2: Teen (15), Twin Pigtails (4), Platinum Blonde (#f0d58c), Glasses
			members[2]["name"] = "Mary Jane"
			members[2]["age"] = 15
			members[2]["role"] = "teen"
			members[2]["scavenge_slots"] = 2
			members[2]["skin_tone"] = 0
			members[2]["hair_style"] = 4 # Twin Pigtails
			members[2]["hair_color"] = "#f0d58c" # Platinum Blonde
			members[2]["glasses"] = true
			members[2]["outfit_color"] = "#3d7a8a"
			members[2]["shirt_style"] = 3

			# Member 3: Child (7), Spiky Punk (7), Ginger Orange (#e06d2b), Glasses
			members[3]["name"] = "Timmy"
			members[3]["age"] = 7
			members[3]["role"] = "child"
			members[3]["scavenge_slots"] = 2
			members[3]["skin_tone"] = 4
			members[3]["hair_style"] = 7 # Spiky Punk
			members[3]["hair_color"] = "#e06d2b" # Ginger Orange
			members[3]["glasses"] = true
			members[3]["outfit_color"] = "#557a46"
			members[3]["shirt_style"] = 1

		fam_scr.set("selected_index", 1) # Inspect Dolores (Elder 66, Pink Beehive, Glasses)
		fam_scr.call("_on_condition_preview_selected", "mutant") # Preview Mutant! condition
		await _wait_frames(12)
		await _snap(out_dir + "/audit_02_family_custom.png")
		# Reset preview mode to healthy before advancing
		fam_scr.call("_on_condition_preview_selected", "healthy")

	# -------------------------------------------------------------------------
	# 3. OSM HOUSE SELECT (SEATTLE) -> audit_03_osm_seattle.png
	# -------------------------------------------------------------------------
	gs.call("request_screen", "osm_house")
	await _settle_screen(main_inst, 20)
	await create_timer(1.2).timeout
	await _wait_frames(15)
	await _snap(out_dir + "/audit_03_osm_seattle.png")

	# -------------------------------------------------------------------------
	# 4. OSM HOUSE SELECT (CONCORD, MA + DIFFERENT HOUSE) -> audit_04_osm_concord.png
	# -------------------------------------------------------------------------
	var house_scr: Control = main_inst.get("_active_node")
	if is_instance_valid(house_scr):
		house_scr.call("_load_preset_neighborhood", "concord", false)
		await _wait_frames(10)
		var bldgs: Array = house_scr.get("_current_buildings")
		var cur_id: int = int(gs.get("selected_house").get("osm_id", -1))
		var alt_house: Dictionary = {}
		# Pick a distinct nearby residential house in Concord, MA
		for b_var in bldgs:
			if b_var is Dictionary:
				var bd: Dictionary = b_var
				var bid: int = int(bd.get("osm_id", -1))
				var btype: String = str(bd.get("building_type", "house")).to_lower()
				if bid != cur_id and (btype.contains("house") or btype.contains("semi") or btype.contains("resid") or btype == "yes"):
					alt_house = bd
					# Prefer one with an explicit street address or interesting building_type if available
					if str(bd.get("short_address", "")).length() > 4:
						break
		if alt_house.is_empty() and bldgs.size() > 1:
			alt_house = bldgs[1]
		if not alt_house.is_empty():
			print("Audit Concord clicked house: ", alt_house.get("short_address", ""), " type=", alt_house.get("building_type", ""), " id=", alt_house.get("osm_id", 0))
			house_scr.call("_select_house", alt_house, true)
		await create_timer(1.2).timeout
		await _wait_frames(15)
		await _snap(out_dir + "/audit_04_osm_concord.png")

	# -------------------------------------------------------------------------
	# 5. NUKE SCREEN REGIONAL RADAR -> audit_05_nuke_regional.png
	# -------------------------------------------------------------------------
	gs.call("request_screen", "nuke")
	await _settle_screen(main_inst, 20)
	var nuke_scr: Control = main_inst.get("_active_node")
	if is_instance_valid(nuke_scr):
		nuke_scr.call("set_map_mode", "regional")
		nuke_scr.call("_on_preset_button_pressed", 0) # Local Downtown (3 km)
		await _wait_frames(35) # Allow ForecastPanel gauge bars to finish lerping
		await _snap(out_dir + "/audit_05_nuke_regional.png")

		# ---------------------------------------------------------------------
		# 6. NUKE SCREEN GLOBAL WORLD MAP + NUCLEAR WINTER -> audit_06_nuke_global.png
		# ---------------------------------------------------------------------
		nuke_scr.call("set_map_mode", "global")
		nuke_scr.call("_on_preset_button_pressed", 7) # Antipode Global Winter preset
		await _wait_frames(35)
		await _snap(out_dir + "/audit_06_nuke_global.png")

		# Restore 3km regional strike telemetry before entering 60s Scavenge
		nuke_scr.call("_on_preset_button_pressed", 0)
		await _wait_frames(6)

	# -------------------------------------------------------------------------
	# 7. SCAVENGE SCENE ACTIVE 60s SIREN MODE -> audit_07_scavenge_active.png
	# Skip recon, deposit a couple items, and actively carry family + items in Carry Slots!
	# -------------------------------------------------------------------------
	gs.call("request_screen", "scavenge")
	await _settle_screen(main_inst, 16)
	var scav_scr: Node2D = main_inst.get("_active_node")
	if is_instance_valid(scav_scr):
		scav_scr.call("trigger_hud_skip_scout")
		await _wait_frames(10)

		var world_items: Array = scav_scr.get("_world_items")
		var world_fam: Array = scav_scr.get("_world_family")
		var hatch_p: Vector2 = scav_scr.get("_hatch_pos")

		# Deposit 2 items into the hatch first so Bunker Chute Tally is non-zero
		var deposited_n: int = 0
		for it_v in world_items:
			if deposited_n >= 2:
				break
			var it_d: Dictionary = it_v
			if int(it_d.get("slots", 1)) == 1 and not bool(it_d.get("collected", false)):
				scav_scr.call("_attempt_pickup_target", {
					"kind": "item",
					"uid": int(it_d["uid"]),
					"pos": it_d["pos"],
					"slots": int(it_d["slots"]),
					"name": str(it_d["name"]),
					"item_id": str(it_d["item_id"]),
					"ref": it_d
				})
				deposited_n += 1
		scav_scr.call("_deposit_carried_into_hatch")

		# Move player away from hatch into a room so carried items do NOT auto-deposit
		var safe_stand_pos: Vector2 = hatch_p + Vector2(130.0, -95.0)
		for it_v2 in world_items:
			var it_d2: Dictionary = it_v2
			if not bool(it_d2.get("collected", false)):
				var p_cand: Vector2 = it_d2["pos"]
				if p_cand.distance_to(hatch_p) > 110.0:
					safe_stand_pos = p_cand
					break
		scav_scr.set("_player_pos", scav_scr.call("_resolve_collisions", safe_stand_pos, false))
		scav_scr.set("_floating_popups", []) # Clear stacked debug popups so house floor is clean

		# Carry 1 2-slot family member + 2 1-slot items = 4/4 Carry Slots!
		for f_v in world_fam:
			var fd: Dictionary = f_v
			if int(fd.get("slots", 2)) == 2 and not bool(fd.get("collected", false)):
				scav_scr.call("_attempt_pickup_target", {
					"kind": "family",
					"uid": int(fd["uid"]),
					"pos": fd["pos"],
					"slots": int(fd["slots"]),
					"name": str(fd["name"]),
					"ref": fd
				})
				break

		var carried_items_n: int = 0
		for it_v3 in world_items:
			if carried_items_n >= 2:
				break
			var it_d3: Dictionary = it_v3
			if int(it_d3.get("slots", 1)) == 1 and not bool(it_d3.get("collected", false)):
				scav_scr.call("_attempt_pickup_target", {
					"kind": "item",
					"uid": int(it_d3["uid"]),
					"pos": it_d3["pos"],
					"slots": int(it_d3["slots"]),
					"name": str(it_d3["name"]),
					"item_id": str(it_d3["item_id"]),
					"ref": it_d3
				})
				carried_items_n += 1

		await _wait_frames(18)
		await _snap(out_dir + "/audit_07_scavenge_active.png")

	# -------------------------------------------------------------------------
	# 8. BUNKER FULL INTERIOR (NOTEBOOK MINIMIZED) -> audit_08_bunker_full_interior.png
	# All 4 custom family members on bench, Sharikov Cat, Pancake Dog, Padlock on Hatch,
	# Soup/Water shelves, Geiger/Thermometer dials!
	# -------------------------------------------------------------------------
	var b_members: Array = gs.get("family_members")
	for m in b_members:
		m["in_bunker"] = true
		m["alive"] = true
		m["on_expedition"] = false
		m["hunger"] = 0
		m["thirst"] = 0
		m["sickness"] = 0
		m["injury"] = 0

	# M1: the shelter is built from the grab haul when the hatch closes; the day is one screen.
	gs.set("shelter", null)
	for pair in [["food", 5], ["water", 6], ["medkit", 2], ["bug_spray", 1], ["ammo", 3], ["padlock", 1],
			["gas_mask", 1], ["radio", 1], ["rifle", 1], ["map", 1], ["manual", 1], ["suitcase", 1], ["cards", 1], ["flashlight", 1]]:
		gs.call("add_scavenged_item", pair[0], pair[1])
	gs.call("request_screen", "bunker")
	await _settle_screen(main_inst, 20)
	var bunker_scr: Control = main_inst.get("_active_node")
	if is_instance_valid(bunker_scr):
		var sh: ShelterState = gs.get("shelter")
		sh.pets["dog"] = {"since": 1}
		sh.pets["cat"] = {"since": 1}
		sh.break_one("flashlight")   # a broken item on the shelf
		(sh.members[1] as Dictionary)["dww"] = 3
		(sh.members[2] as Dictionary)["sick"] = true
		bunker_scr.call("_refresh_all")
		await _wait_frames(15)
		await _snap(out_dir + "/audit_08_bunker_full_interior.png")
		# 9. the morning receipt + dilemma card + ration row on one screen
		if sh.today_event.is_empty() or not _has_item_option(sh):
			var ev: Dictionary = ShelterEvents._prepare(sh, ShelterData.event("signature_required"))
			sh.today_event = ev
			sh.today_resolved = false
			sh.today_options = ShelterEvents.options_for(sh, ev)
			bunker_scr.call("_refresh_all")
		await _wait_frames(12)
		await _snap(out_dir + "/audit_09_bunker_day_screen.png")
		# 10. ration row with Give/Skip toggles and tomorrow's preview
		bunker_scr.call("_toggle_ration", str((sh.members[0] as Dictionary)["id"]), "food")
		bunker_scr.call("_toggle_ration", str((sh.members[1] as Dictionary)["id"]), "water")
		await _wait_frames(12)
		await _snap(out_dir + "/audit_10_bunker_rations.png")
		# 11. the dilemma answered: outcome and "Used:" receipt
		var pick: String = ""
		for o_v in sh.today_options:
			if bool((o_v as Dictionary).get("available", false)) and (pick == "" or str((o_v as Dictionary).get("item", "")) != ""):
				pick = str((o_v as Dictionary)["id"])
		bunker_scr.call("_choose", pick)
		await _wait_frames(30)
		var cine: Node = bunker_scr.get("_cinematic")
		for _i in range(200):
			if not bool(bunker_scr.get("_busy")):
				break
			if cine.has_method("_on_continue"):
				cine.set("_t", 99.0)
				cine.call("_on_continue")
			await process_frame
		await _wait_frames(10)
		await _snap(out_dir + "/audit_11_bunker_dilemma_answered.png")
		# 12. the expedition planner with the risk preview
		bunker_scr.call("_open_planner", str((sh.members[0] as Dictionary)["id"]), false)
		await _wait_frames(15)
		var tp: Node = bunker_scr.get("_planner")
		if tp != null:
			tp.call("_select", 0)
		await _wait_frames(12)
		await _snap(out_dir + "/audit_12_bunker_trip_planner.png")
		bunker_scr.call("_close_planner")

	# -------------------------------------------------------------------------
	# 13. SUMMARY SCREEN (VICTORY) -> audit_13_summary_victory.png
	# -------------------------------------------------------------------------
	gs.set("day", 19)
	gs.set("victory", true)
	gs.set("game_over", true)
	gs.set("scavenge_stats", {"items_collected": 14, "family_saved": 4})
	gs.set("ending_title", "The Neighbourhood Shelter")
	gs.set("ending_description", "The people at First Parish in Concord sent an escort. There is soup there, and a rota for the dishes.")
	gs.call("request_screen", "summary")
	await _settle_screen(main_inst, 28)
	await _snap(out_dir + "/audit_13_summary_victory.png")

	# -------------------------------------------------------------------------
	# 14. SUMMARY SCREEN (PERISHED / GAME OVER) -> audit_14_summary_perished.png
	# -------------------------------------------------------------------------
	var p_members: Array = gs.get("family_members")
	if p_members.size() >= 4:
		p_members[0]["alive"] = false
		p_members[0]["death_reason"] = "Succumbed to severe dehydration on Day 11."
		p_members[1]["alive"] = false
		p_members[1]["death_reason"] = "Perished defending the blast hatch against raiders."
		p_members[2]["alive"] = false
		p_members[2]["in_bunker"] = true
		p_members[2]["death_reason"] = "Lost to untreated fallout radiation sickness."
		p_members[3]["alive"] = true
		p_members[3]["in_bunker"] = false
		p_members[3]["death_reason"] = ""
	gs.set("day", 11)
	gs.set("bunker_structural_integrity", 24.0)
	gs.set("victory", false)
	gs.set("game_over", true)
	gs.set("ending_title", "The Shelter Went Quiet")
	gs.set("ending_description", "Nobody is left to write in the journal.")
	gs.call("request_screen", "summary")
	await _settle_screen(main_inst, 28)
	await _snap(out_dir + "/audit_14_summary_perished.png")

	print("CRITIC_VISUAL_AUDIT_COMPLETE")
	quit(0)

func _has_item_option(sh: ShelterState) -> bool:
	for o_v in sh.today_options:
		if str((o_v as Dictionary).get("item", "")) != "":
			return true
	return false


func _event_has_item_choice(ev: Dictionary) -> bool:
	var opts: Variant = ev.get("options", ev.get("choices", []))
	if opts is Array:
		for o in opts:
			if o is Dictionary:
				var req: String = str((o as Dictionary).get("item_id", (o as Dictionary).get("required_item", "")))
				if req != "":
					return true
	return false

func _settle_screen(main_inst: Control, frames: int) -> void:
	await _wait_frames(4)
	if is_instance_valid(main_inst):
		main_inst.set("_fade_alpha", 0.0)
		var fr: ColorRect = main_inst.get("_fade_rect")
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
		print("Saved audit screenshot: " + path)
