extends Node

## SaveManager Autoload (`res://scripts/core/save_manager.gd`)
## Handles:
## 1. Full mid-run shelter Save / Load (`user://savegame_v2.json`) including Vector2 footprint serialization.
## 2. Persistent Meta-Progression (`user://meta_profile_v2.json`):
##    - Multi-Run Vehicle Chassis Tier (Tier 0..3 permanently upgraded by recovering vehicle parts / escaping!)
##    - 16 Achievements & Unlockable Survivor Hats / Shelter Plaques
##    - Career Run Statistics

const SAVE_RUN_PATH := "user://savegame_v2.json"
const META_PROFILE_PATH := "user://meta_profile_v2.json"

const ACHIEVEMENTS_DEF := {
	"first_seal": {"title": "Duck and Cover", "desc": "Seal the blast hatch and survive Day 1 in the shelter.", "unlock_hat": "cd_helmet"},
	"full_house": {"title": "No One Left Behind", "desc": "Evacuate all 4 family members during the 60-second scavenge.", "unlock_hat": ""},
	"pack_mule": {"title": "Suitcase Strategist", "desc": "Secure 18+ supply items during a single 60-second scavenge.", "unlock_hat": "aviator"},
	"road_warrior_parts": {"title": "Wasteland Mechanic", "desc": "Install at least 2 vehicle parts on the shelter escape chassis.", "unlock_hat": ""},
	"highway_breakout": {"title": "Highway Breakout", "desc": "Rebuild the Station Wagon and drive out of the fallout zone!", "unlock_hat": "ushanka"},
	"military_evac": {"title": "Operation CONELRAD", "desc": "Achieve rescue via U.S. Civil Defense Military Extraction.", "unlock_hat": ""},
	"parish_alliance": {"title": "Sanctuary Bells", "desc": "Unite with a real-world OpenStreetMap Church or School community.", "unlock_hat": "medic_cap"},
	"vault_agent": {"title": "Comrade Sharikov", "desc": "Escape with Sharikov the Cat into the Secret Scientist Vault.", "unlock_hat": ""},
	"convoy_pact": {"title": "Smuggler's Highway", "desc": "Broker an escape aboard the Wasteland Convoy faction.", "unlock_hat": ""},
	"deep_trek": {"title": "Long-Range Recon", "desc": "Complete a distant Ring 2/3 expedition (> 1.5 km from home).", "unlock_hat": ""},
	"doctor_house": {"title": "Paging Doctor Atomic", "desc": "Scavenge Antibiotics or Medkits from a real Doctor's Office or Clinic.", "unlock_hat": "medic_cap"},
	"grocery_haul": {"title": "Aisle Nine Sweep", "desc": "Return from a real Supermarket or Grocery Store with rations.", "unlock_hat": ""},
	"unbreakable_bond": {"title": "Thick as Fallout", "desc": "Reach 'Devoted' (+55) relationship status between two survivors.", "unlock_hat": ""},
	"mutant_awakening": {"title": "Atom's Blessing", "desc": "Witness a survivor transform into a helpful shelter Mutant.", "unlock_hat": ""},
	"survivor_20": {"title": "Twenty Atomic Nights", "desc": "Survive until Day 20 in a single shelter run.", "unlock_hat": ""},
	"tsar_survivor": {"title": "Tsar Bomba Veteran", "desc": "Win a run on Tsar Bomba difficulty.", "unlock_hat": "ushanka"}
}

var meta: Dictionary = {
	"vehicle_chassis_tier": 0,
	"total_vehicle_parts_banked": 0,
	"unlocked_achievements": {},
	"unlocked_hats": ["none"],
	"runs_played": 0,
	"victories": 0,
	"longest_days": 0,
	"best_scavenge_items": 0
}

func _ready() -> void:
	load_meta()

# --- Meta Profile Persistence ---

func load_meta() -> void:
	if not FileAccess.file_exists(META_PROFILE_PATH):
		return
	var f := FileAccess.open(META_PROFILE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed
		for k in meta.keys():
			if d.has(k):
				meta[k] = d[k]
		var hats: Array = meta.get("unlocked_hats", ["none"])
		if not hats.has("none"):
			hats.push_front("none")
		meta["unlocked_hats"] = hats

func save_meta() -> void:
	var f := FileAccess.open(META_PROFILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()

func get_vehicle_chassis_tier() -> int:
	return clampi(int(meta.get("vehicle_chassis_tier", 0)), 0, 3)

func record_run_completion(parts_found: int, escaped_by_vehicle: bool, is_victory: bool, days_survived: int, items_grabbed: int) -> Dictionary:
	var prev_tier: int = get_vehicle_chassis_tier()
	meta["runs_played"] = int(meta.get("runs_played", 0)) + 1
	if is_victory:
		meta["victories"] = int(meta.get("victories", 0)) + 1
	meta["longest_days"] = maxi(int(meta.get("longest_days", 0)), days_survived)
	meta["best_scavenge_items"] = maxi(int(meta.get("best_scavenge_items", 0)), items_grabbed)

	var total_parts: int = int(meta.get("total_vehicle_parts_banked", 0)) + maxi(0, parts_found)
	meta["total_vehicle_parts_banked"] = total_parts

	var next_tier: int = prev_tier
	if escaped_by_vehicle:
		next_tier = mini(3, prev_tier + 1)
	elif parts_found <= 0:
		pass # Banking milestones only unlock on runs that actually salvaged new parts
	elif total_parts >= 8:
		next_tier = maxi(next_tier, 3)
	elif total_parts >= 4:
		next_tier = maxi(next_tier, 2)
	elif total_parts >= 2:
		next_tier = maxi(next_tier, 1)

	meta["vehicle_chassis_tier"] = next_tier
	if days_survived >= 20:
		unlock_achievement("survivor_20")
	if is_victory and GameState.difficulty == "tsar_bomba":
		unlock_achievement("tsar_survivor")
	save_meta()
	return {"prev_tier": prev_tier, "new_tier": next_tier, "upgraded": next_tier > prev_tier}

func unlock_achievement(ach_id: String) -> bool:
	if not ACHIEVEMENTS_DEF.has(ach_id):
		return false
	var unlocked: Dictionary = meta.get("unlocked_achievements", {})
	if unlocked.has(ach_id):
		return false
	unlocked[ach_id] = int(Time.get_unix_time_from_system())
	meta["unlocked_achievements"] = unlocked

	var def_d: Dictionary = ACHIEVEMENTS_DEF[ach_id]
	var hat_reward: String = str(def_d.get("unlock_hat", ""))
	if hat_reward != "":
		var hats: Array = meta.get("unlocked_hats", ["none"])
		if not hats.has(hat_reward):
			hats.append(hat_reward)
			meta["unlocked_hats"] = hats

	save_meta()
	GameState.achievement_unlocked.emit(ach_id, str(def_d.get("title", ach_id)))
	return true

func is_achievement_unlocked(ach_id: String) -> bool:
	var unlocked: Dictionary = meta.get("unlocked_achievements", {})
	return unlocked.has(ach_id)

func get_unlocked_hats() -> Array:
	var hats: Array = meta.get("unlocked_hats", ["none"])
	if not hats.has("none"):
		hats.push_front("none")
	return hats

# --- Mid-Run Save / Load ---

func has_saved_run() -> bool:
	return FileAccess.file_exists(SAVE_RUN_PATH)

func clear_saved_run() -> void:
	if FileAccess.file_exists(SAVE_RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_RUN_PATH))

func save_run() -> bool:
	var house_copy: Dictionary = GameState.selected_house.duplicate(true)
	if house_copy.has("footprint_meters"):
		var serialized_fp: Array = []
		for pt in house_copy["footprint_meters"]:
			if pt is Vector2:
				serialized_fp.append({"x": (pt as Vector2).x, "y": (pt as Vector2).y})
			elif pt is Dictionary:
				serialized_fp.append(pt)
		house_copy["footprint_meters"] = serialized_fp
	if house_copy.has("polygon_latlon"):
		var serialized_ll: Array = []
		for pt in house_copy["polygon_latlon"]:
			if pt is Vector2:
				serialized_ll.append({"x": (pt as Vector2).x, "y": (pt as Vector2).y})
			elif pt is Dictionary:
				serialized_ll.append(pt)
		house_copy["polygon_latlon"] = serialized_ll

	var active_exp_copy: Dictionary = GameState.active_expedition.duplicate(true)
	if active_exp_copy.get("poi") is Dictionary:
		var p_copy: Dictionary = (active_exp_copy["poi"] as Dictionary).duplicate(true)
		p_copy.erase("footprint_meters")
		p_copy.erase("polygon_latlon")
		active_exp_copy["poi"] = p_copy

	var ev_deck_state: Dictionary = EventDeck.export_state() if ClassDB.class_exists("EventDeck") or ResourceLoader.exists("res://scripts/events/event_deck.gd") else {}

	var payload: Dictionary = {
		"version": 2,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"difficulty": GameState.difficulty,
		"game_mode": GameState.game_mode,
		"active_challenge_id": GameState.active_challenge_id,
		"day": GameState.day,
		"soup_quarters": GameState.soup_quarters,
		"water_quarters": GameState.water_quarters,
		"ammo_count": GameState.ammo_count,
		"medkit_count": GameState.medkit_count,
		"bug_spray_count": GameState.bug_spray_count,
		"antibiotics_count": GameState.antibiotics_count,
		"antirad_count": GameState.antirad_count,
		"scrap_count": GameState.scrap_count,
		"padlock_active": GameState.padlock_active,
		"fuel_cans": GameState.fuel_cans,
		"fuel_needed": GameState.fuel_needed,
		"vehicle_parts": GameState.vehicle_parts.duplicate(true),
		"vehicle_tuned": GameState.vehicle_tuned,
		"bunker_items": GameState.bunker_items.duplicate(true),
		"has_cat_sharikov": GameState.has_cat_sharikov,
		"has_dog_pancake": GameState.has_dog_pancake,
		"roach_infestation": GameState.roach_infestation,
		"bunker_structural_integrity": GameState.bunker_structural_integrity,
		"surface_radiation_sv": GameState.surface_radiation_sv,
		"bunker_temp_c": GameState.bunker_temp_c,
		"family_members": GameState.family_members.duplicate(true),
		"relationships": GameState.relationships.duplicate(true),
		"recent_relationship_events": GameState.recent_relationship_events.duplicate(true),
		"selected_house": house_copy,
		"nearby_pois": _sanitize_pois_for_json(GameState.nearby_pois),
		"neighborhood_modifiers": GameState.neighborhood_modifiers.duplicate(true),
		"current_neighborhood_label": GameState.current_neighborhood_label,
		"nuke_config": GameState.nuke_config.duplicate(true),
		"left_behind_members": GameState.left_behind_members.duplicate(true),
		"story_flags": GameState.story_flags.duplicate(true),
		"active_expedition": active_exp_copy,
		"rescue_chains": GameState.rescue_chains.duplicate(true),
		"daily_log_entries": GameState.daily_log_entries.duplicate(true),
		"scavenge_stats": GameState.scavenge_stats.duplicate(true),
		"run_metrics": GameState.run_metrics.duplicate(true),
		"event_deck_state": ev_deck_state
	}

	var f := FileAccess.open(SAVE_RUN_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return true

func _sanitize_pois_for_json(pois: Array) -> Array:
	var out: Array = []
	for p_v in pois:
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = (p_v as Dictionary).duplicate(true)
		p.erase("footprint_meters")
		p.erase("polygon_latlon")
		out.append(p)
	return out

func load_run() -> bool:
	if not FileAccess.file_exists(SAVE_RUN_PATH):
		return false
	var f := FileAccess.open(SAVE_RUN_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed

	GameState.game_over = false
	GameState.victory = false
	GameState.ending_route = ""
	GameState.ending_title = ""
	GameState.ending_description = ""

	GameState.difficulty = str(d.get("difficulty", "fat_man"))
	GameState.game_mode = str(d.get("game_mode", "full_protocol"))
	GameState.active_challenge_id = str(d.get("active_challenge_id", ""))
	GameState.day = maxi(1, int(d.get("day", 1)))
	GameState.soup_quarters = maxi(0, int(d.get("soup_quarters", 0)))
	GameState.water_quarters = maxi(0, int(d.get("water_quarters", 0)))
	GameState.ammo_count = maxi(0, int(d.get("ammo_count", 0)))
	GameState.medkit_count = maxi(0, int(d.get("medkit_count", 0)))
	GameState.bug_spray_count = maxi(0, int(d.get("bug_spray_count", 0)))
	GameState.antibiotics_count = maxi(0, int(d.get("antibiotics_count", 0)))
	GameState.antirad_count = maxi(0, int(d.get("antirad_count", 0)))
	GameState.scrap_count = maxi(0, int(d.get("scrap_count", 0)))
	GameState.padlock_active = bool(d.get("padlock_active", false))
	GameState.fuel_cans = maxi(0, int(d.get("fuel_cans", 0)))
	GameState.fuel_needed = maxi(1, int(d.get("fuel_needed", 5)))
	if d.get("vehicle_parts") is Dictionary:
		GameState.vehicle_parts = (d["vehicle_parts"] as Dictionary).duplicate(true)
	GameState.vehicle_tuned = bool(d.get("vehicle_tuned", false))
	if d.get("bunker_items") is Dictionary:
		GameState.bunker_items = (d["bunker_items"] as Dictionary).duplicate(true)
	GameState.has_cat_sharikov = bool(d.get("has_cat_sharikov", false))
	GameState.has_dog_pancake = bool(d.get("has_dog_pancake", false))
	GameState.roach_infestation = int(d.get("roach_infestation", 0))
	GameState.bunker_structural_integrity = float(d.get("bunker_structural_integrity", 100.0))
	GameState.surface_radiation_sv = float(d.get("surface_radiation_sv", 4.0))
	GameState.bunker_temp_c = float(d.get("bunker_temp_c", 20.0))

	if d.get("family_members") is Array:
		GameState.family_members = (d["family_members"] as Array).duplicate(true)
	if d.get("relationships") is Dictionary:
		var rel_in: Dictionary = d["relationships"]
		GameState.relationships = {}
		for rk in rel_in.keys():
			GameState.relationships[str(rk)] = int(rel_in[rk])
	if d.get("recent_relationship_events") is Array:
		GameState.recent_relationship_events = (d["recent_relationship_events"] as Array).duplicate(true)
	else:
		GameState.recent_relationship_events = []

	if d.get("selected_house") is Dictionary:
		var hc: Dictionary = (d["selected_house"] as Dictionary).duplicate(true)
		if hc.get("footprint_meters") is Array:
			var restored_fp: Array[Vector2] = []
			for pt in hc["footprint_meters"]:
				if pt is Dictionary:
					restored_fp.append(Vector2(float(pt.get("x", 0.0)), float(pt.get("y", 0.0))))
				elif pt is Vector2:
					restored_fp.append(pt)
			hc["footprint_meters"] = restored_fp
		if hc.get("polygon_latlon") is Array:
			var restored_ll: Array[Vector2] = []
			for pt in hc["polygon_latlon"]:
				if pt is Dictionary:
					restored_ll.append(Vector2(float(pt.get("x", 0.0)), float(pt.get("y", 0.0))))
				elif pt is Vector2:
					restored_ll.append(pt)
			hc["polygon_latlon"] = restored_ll
		GameState.selected_house = hc

	if d.get("nearby_pois") is Array:
		GameState.nearby_pois = (d["nearby_pois"] as Array).duplicate(true)
	if d.get("neighborhood_modifiers") is Dictionary:
		GameState.neighborhood_modifiers = (d["neighborhood_modifiers"] as Dictionary).duplicate(true)
	GameState.current_neighborhood_label = str(d.get("current_neighborhood_label", ""))
	if d.get("nuke_config") is Dictionary:
		GameState.nuke_config = (d["nuke_config"] as Dictionary).duplicate(true)
	if d.get("left_behind_members") is Array:
		GameState.left_behind_members = (d["left_behind_members"] as Array).duplicate(true)
	if d.get("story_flags") is Dictionary:
		GameState.story_flags = (d["story_flags"] as Dictionary).duplicate(true)
	if d.get("active_expedition") is Dictionary:
		GameState.active_expedition = (d["active_expedition"] as Dictionary).duplicate(true)
	if d.get("rescue_chains") is Dictionary:
		var rc: Dictionary = d["rescue_chains"]
		for k in ["military", "sanctuary", "scientist", "raider_pact"]:
			GameState.rescue_chains[k] = int(rc.get(k, 0))
	if d.get("daily_log_entries") is Array:
		GameState.daily_log_entries = (d["daily_log_entries"] as Array).duplicate(true)
	if d.get("scavenge_stats") is Dictionary:
		GameState.scavenge_stats = (d["scavenge_stats"] as Dictionary).duplicate(true)
	if d.get("run_metrics") is Dictionary:
		GameState.run_metrics = (d["run_metrics"] as Dictionary).duplicate(true)
	if d.get("event_deck_state") is Dictionary:
		EventDeck.import_state(d["event_deck_state"] as Dictionary)

	GameState.inventory_changed.emit()
	GameState.family_changed.emit()
	GameState.relationships_changed.emit()
	return true
