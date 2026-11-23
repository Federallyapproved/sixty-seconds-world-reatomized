class_name EventDeck
extends RefCounted

## 60 Seconds: World Reatomized — V2 Branching Daily Event Deck (103 Events).
## Combines 60 classic 60 Seconds! Reatomized dark-comedy dilemmas with 43 V2 narrative events:
## 1. 4-Chain 3-Stage Rescue Victory Routes (Military, OSM Sanctuary, Vault Scientist, Wasteland Smuggler Convoy)
## 2. Station Wagon Garage & Vehicle Escape Story Events (vehicle_part, fuel, scrap, vehicle_tuned)
## 3. Deep Family Relationships, Guilt over Unrescued Kin, Breakdowns & [COOPERATE] Choices
## 4. Real-World OpenStreetMap Landmark Conditional Events (Doctor, Supermarket, Pharmacy, Gas Station, etc.)
## 5. Delayed Persistent Consequences via GameState.story_flags (4+ day callbacks & vendetta reprisals)

const NON_REPEAT_BUFFER_DAYS: int = 16

const ITEM_LABELS: Dictionary = {
	"soup": "Tomato Soup",
	"water": "Clean Water",
	"medkit": "First Aid Medkit",
	"gas_mask": "Gas Mask",
	"radio": "CONELRAD Radio",
	"flashlight": "Flashlight",
	"map": "Civil Defense Map",
	"book": "Boy Scout Handbook",
	"ammo": "Rifle Ammo",
	"bug_spray": "Mutant Bug Spray",
	"padlock": "Heavy Padlock",
	"cards": "Playing Cards",
	"checkers": "Checkers Set",
	"harmonica": "Harmonica",
	"axe": "Fireman's Axe",
	"rifle": "Hunting Rifle",
	"suitcase": "Leather Suitcase",
	"toolbox": "Repair Toolbox",
	"cat": "Sharikov the Cat",
	"dog": "Pancake the Dog",
	"antibiotics": "Prescription Antibiotics",
	"antirad": "Anti-Rad Iodide Pack",
	"scrap": "Salvaged Scrap",
	"fuel": "Gasoline Jerrycan",
	"battery": "12V Car Battery",
	"alternator": "Alternator",
	"spark_plugs": "Spark Plugs",
	"radiator_hose": "Radiator Hose",
	"vehicle_part": "Engine Part"
}

const ALL_EVENT_IDS: Array[String] = [
	"day1_civil_defense_seal",
	# 3-Stage Rescue Chains — 4 Routes (12 events)
	"rescue_military_1",
	"rescue_military_2",
	"rescue_military_3",
	"rescue_sanctuary_1",
	"rescue_sanctuary_2",
	"rescue_sanctuary_3",
	"rescue_scientist_1",
	"rescue_scientist_2",
	"rescue_scientist_3",
	"rescue_raider_pact_1",
	"rescue_raider_pact_2",
	"rescue_raider_pact_3",
	# Core Classic 60 Seconds! Hazards, Companions, Raiders & Traders (13 events)
	"hazard_mutant_roaches",
	"hazard_vent_filter",
	"raiders_blast_hatch",
	"ooze_green_pipe",
	"companion_pancake_dog",
	"trader_wasteland_swap",
	"repair_broken_gear",
	"bunker_darkness_bulb",
	"family_argument",
	"outside_suspicious_suitcase",
	"outside_mysterious_knock",
	"quirky_beard_overgrowth",
	"family_birthday",
	# Nuke Zone & Detonation Physics Special Events (4 events)
	"nuke_blizzard_freeze",
	"nuke_ground_zero_tremor",
	"nuke_downwind_acid_rain",
	"nuke_emp_magnetic_storm",
	# Real-World OpenStreetMap Neighborhood Events (10 events)
	"osm_grocery_cart_rattle",
	"osm_pharmacy_courier",
	"osm_neighbor_bunker_tap",
	"osm_hardware_looters",
	"osm_restaurant_aroma",
	"osm_school_civil_defense_cache",
	"osm_park_mutant_geese",
	"osm_civic_siren_malfunction",
	"osm_street_delivery_van",
	"osm_firefighter_check",
	# Iconic Reatomized Bunker Survival, Quirky & Companion Events (23 events)
	"classic_radioactive_spider",
	"classic_pancake_treasure",
	"classic_sharikov_mice",
	"classic_leaky_water_jug",
	"classic_suspicious_soup_can",
	"classic_cabin_fever_checkers",
	"classic_boy_scout_quiz",
	"classic_periscope_smudge",
	"classic_strange_fungus",
	"classic_voices_in_pipes",
	"classic_ammo_press",
	"classic_red_phone_ringing",
	"classic_wandering_doctor",
	"classic_raider_extortion_note",
	"classic_suitcase_false_bottom",
	"classic_mutant_night_vision",
	"classic_condensation_still",
	"classic_board_game_feud",
	"classic_civil_defense_drop",
	"classic_bad_dream_choir",
	"classic_salesman_vault_insurance",
	"classic_splinter_first_aid",
	"classic_radio_quiz_show",
	# V2 Pillar 2: Station Wagon Garage & Vehicle Escape Story Events (5 events)
	"vehicle_garage_discovery",
	"vehicle_siphon_derelict",
	"vehicle_engine_tuneup",
	"vehicle_armored_bumper",
	"vehicle_nomad_parts_swap",
	# V2 Pillar 3: Deep Family Relationships, Guilt, Loyalty & [COOPERATE] Events (13 events)
	"family_haunted_unrescued",
	"family_phantom_knock_guilt",
	"family_ration_accusation",
	"family_generation_clash",
	"family_midnight_card_tournament",
	"family_shared_coat_freeze",
	"family_breakdown_intervention",
	"family_quiet_apology",
	"family_cooperate_pipe_burst",
	"family_cooperate_hatch_brace",
	"family_secret_diary_feud",
	"family_expedition_jealousy",
	"family_heirloom_watch_pledge",
	# V2 Pillar 4: Real-World Landmark Conditional Events (11 events)
	"landmark_doctor_triage_ledger",
	"landmark_supermarket_cold_storage",
	"landmark_pharmacy_iodide_shipment",
	"landmark_gas_station_underground_tank",
	"landmark_firehouse_siren_relay",
	"landmark_highschool_ham_club",
	"landmark_hardware_scrap_yard",
	"landmark_church_sanctuary_candles",
	"landmark_clinic_quarantine_notice",
	"landmark_auto_shop_battery_rack",
	"landmark_library_microfilm_atlas",
	# V2 Pillar 5: Delayed Persistent Consequences via story_flags & Trade-Offs (11 events)
	"stranger_wounded_courier",
	"courier_repayment_drop",
	"vendetta_reprisal_raid",
	"stranger_desperate_tinker",
	"tinker_workshop_dividend",
	"mystery_seed_tin",
	"sprouted_bunker_greens",
	"unsealed_munitions_crate",
	"beacon_supply_drop_arrival",
	"stranger_chemist_vial",
	"chemist_antidote_return"
]

static var _last_drawn_day: int = 0
static var _last_rescue_day: int = 0
static var _recent_event_ids: Array[String] = []
static var _sanctuary_poi_cache: String = ""


static func reset_state() -> void:
	_last_drawn_day = 0
	_last_rescue_day = 0
	_recent_event_ids.clear()
	_sanctuary_poi_cache = ""


static func export_state() -> Dictionary:
	return {
		"last_drawn_day": _last_drawn_day,
		"last_rescue_day": _last_rescue_day,
		"recent_event_ids": Array(_recent_event_ids),
		"sanctuary_poi_cache": _sanctuary_poi_cache,
	}


static func import_state(st: Dictionary) -> void:
	_last_drawn_day = int(st.get("last_drawn_day", 0))
	_last_rescue_day = int(st.get("last_rescue_day", 0))
	_recent_event_ids.clear()
	var ids_v: Variant = st.get("recent_event_ids", [])
	if ids_v is Array:
		for e in (ids_v as Array):
			_recent_event_ids.append(str(e))
	_sanctuary_poi_cache = str(st.get("sanctuary_poi_cache", ""))


static func get_all_event_ids() -> Array[String]:
	return ALL_EVENT_IDS.duplicate()


static func draw_daily_event(day: int, rng: RandomNumberGenerator) -> Dictionary:
	var active_rng: RandomNumberGenerator = rng if rng != null else GameState.rng

	if day <= 1 or day < _last_drawn_day:
		reset_state()
	_last_drawn_day = day

	# Day 1 always opens with the Civil Defense Blast Door Seal briefing & setup choice
	if day <= 1:
		var ev_day1: Dictionary = build_event_by_id("day1_civil_defense_seal", day, active_rng)
		_record_drawn_id("day1_civil_defense_seal")
		return ev_day1

	# Fair, reliable Rescue Chain Pacing starting Day 5+ across all 4 escape routes
	if day >= 5 and _should_draw_rescue_event(day, active_rng):
		var rescue_id: String = _pick_rescue_event_id(day, active_rng)
		if rescue_id != "":
			_last_rescue_day = day
			_record_drawn_id(rescue_id)
			return build_event_by_id(rescue_id, day, active_rng)

	# Priority Contextual Check 0: Delayed story_flags callbacks ready after 4+ days!
	var due_consequences: Array[String] = _get_ready_consequence_event_ids(day)
	if not due_consequences.is_empty() and active_rng.randf() < 0.72:
		var conseq_id: String = due_consequences[active_rng.randi_range(0, due_consequences.size() - 1)]
		_record_drawn_id(conseq_id)
		return build_event_by_id(conseq_id, day, active_rng)

	# Priority Contextual Check 1: Broken equipment repair opportunity
	var broken_ids: Array[String] = _get_broken_owned_item_ids()
	if not broken_ids.is_empty() and not _recent_event_ids.has("repair_broken_gear"):
		if active_rng.randf() < 0.30:
			_record_drawn_id("repair_broken_gear")
			return build_event_by_id("repair_broken_gear", day, active_rng)

	# Priority Contextual Check 2: Emergency Wasteland Doctor if someone is badly hurt/sick with 0 medkits/antibiotics
	if GameState.medkit_count <= 0 and GameState.antibiotics_count <= 0 and _has_severely_afflicted_member() and not _recent_event_ids.has("classic_wandering_doctor"):
		if active_rng.randf() < 0.28:
			_record_drawn_id("classic_wandering_doctor")
			return build_event_by_id("classic_wandering_doctor", day, active_rng)

	# General Weighted Pool across all eligible events
	var weighted_pool: Array = []
	var total_weight: float = 0.0

	for ev_id in ALL_EVENT_IDS:
		if ev_id == "day1_civil_defense_seal" or ev_id.begins_with("rescue_"):
			continue
		if _recent_event_ids.has(ev_id):
			continue
		var w: float = _get_event_weight(ev_id, day)
		if w > 0.0:
			weighted_pool.append({"id": ev_id, "weight": w})
			total_weight += w

	# Safety fallback if history exhausted all weights (still strictly respects w > 0.0 preconditions!)
	if weighted_pool.is_empty() or total_weight <= 0.0:
		_recent_event_ids.clear()
		for ev_id in ALL_EVENT_IDS:
			if ev_id == "day1_civil_defense_seal" or ev_id.begins_with("rescue_"):
				continue
			var w_fb: float = _get_event_weight(ev_id, day)
			if w_fb > 0.0:
				weighted_pool.append({"id": ev_id, "weight": w_fb})
				total_weight += w_fb

	if weighted_pool.is_empty() or total_weight <= 0.0:
		_record_drawn_id("family_argument")
		return build_event_by_id("family_argument", day, active_rng)

	var roll: float = active_rng.randf() * total_weight
	var chosen_id: String = "family_argument"
	var accum: float = 0.0
	for entry_v in weighted_pool:
		var entry: Dictionary = entry_v
		accum += float(entry.get("weight", 1.0))
		if roll <= accum:
			chosen_id = str(entry.get("id", "family_argument"))
			break

	_record_drawn_id(chosen_id)
	return build_event_by_id(chosen_id, day, active_rng)


static func _record_drawn_id(event_id: String) -> void:
	var existing_idx: int = _recent_event_ids.find(event_id)
	if existing_idx != -1:
		_recent_event_ids.remove_at(existing_idx)
	_recent_event_ids.append(event_id)
	while _recent_event_ids.size() > (NON_REPEAT_BUFFER_DAYS + 2):
		_recent_event_ids.remove_at(0)


## Difficulty-scaled rescue pacing: [min_day, min_gap, probability]
static func _rescue_pacing() -> Array:
	match str(GameState.difficulty):
		"little_boy":
			return [5, 3, 0.80]
		"tsar_bomba":
			return [8, 5, 0.52]
		_:
			return [6, 4, 0.68]


static func _should_draw_rescue_event(day: int, rng: RandomNumberGenerator) -> bool:
	var pacing: Array = _rescue_pacing()
	var min_day: int = int(pacing[0])
	var min_gap: int = int(pacing[1])
	var prob: float = float(pacing[2])
	if day < min_day:
		return false
	if _last_rescue_day == 0:
		return rng.randf() < prob
	var gap: int = day - _last_rescue_day
	if gap < min_gap:
		return false
	# A chain sitting at Stage 2 gets a modest nudge so players aren't left hanging forever
	var any_stage_two: bool = false
	for k in ["military", "sanctuary", "scientist", "raider_pact"]:
		if int(GameState.rescue_chains.get(k, 0)) == 2:
			any_stage_two = true
	var p: float = prob + (0.12 if any_stage_two else 0.0)
	if gap >= min_gap * 2:
		p += 0.2
	return rng.randf() < clampf(p, 0.0, 0.97)


static func _pick_rescue_event_id(day: int, rng: RandomNumberGenerator) -> String:
	var mil_st: int = clampi(int(GameState.rescue_chains.get("military", 0)), 0, 3)
	var sanc_st: int = clampi(int(GameState.rescue_chains.get("sanctuary", 0)), 0, 3)
	var sci_st: int = clampi(int(GameState.rescue_chains.get("scientist", 0)), 0, 3)
	var pact_st: int = clampi(int(GameState.rescue_chains.get("raider_pact", 0)), 0, 3)
	if sci_st >= 1 and not GameState.has_cat_sharikov:
		sci_st = 0
		GameState.rescue_chains["scientist"] = 0
	var extraction_day: int = 15 if str(GameState.difficulty) == "tsar_bomba" else 12

	var candidates: Array = []

	# 1. Military Chain candidate
	if mil_st < 3:
		var mil_id: String = "rescue_military_%d" % (mil_st + 1)
		var mil_w: float = 3.0
		if mil_st == 2:
			mil_w = 20.0
		elif mil_st == 1:
			var has_sig: bool = GameState.has_working_item("map") or GameState.has_working_item("flashlight") or GameState.has_working_item("axe")
			mil_w = 12.0 if has_sig else 7.5
		else:
			mil_w = 6.5 if GameState.has_working_item("radio") else 2.8
		var mil_w_ok: bool = not _recent_event_ids.has(mil_id) and not (mil_st == 2 and day < extraction_day)
		if mil_w_ok:
			candidates.append({"id": mil_id, "weight": mil_w})

	# 2. Real-World OSM Sanctuary Chain candidate
	if sanc_st < 3:
		var sanc_id: String = "rescue_sanctuary_%d" % (sanc_st + 1)
		var sanc_w: float = 3.5
		if sanc_st == 2:
			sanc_w = 20.0
		elif sanc_st == 1:
			var has_build: bool = GameState.has_working_item("toolbox") or GameState.has_working_item("axe") or GameState.has_working_item("rifle") or GameState.has_working_item("book")
			sanc_w = 12.0 if has_build else 7.5
		else:
			var can_share: bool = (GameState.water_quarters >= 4) or (GameState.soup_quarters >= 4) or GameState.has_working_item("medkit") or GameState.has_working_item("book")
			sanc_w = 6.5 if can_share else 3.0
		var sanc_w_ok: bool = not _recent_event_ids.has(sanc_id) and not (sanc_st == 2 and day < extraction_day)
		if sanc_w_ok:
			candidates.append({"id": sanc_id, "weight": sanc_w})

	# 3. Vault Scientist & Sharikov the Cat Chain candidate
	if sci_st < 3:
		var sci_id: String = "rescue_scientist_%d" % (sci_st + 1)
		var sci_w: float = 3.5
		if sci_st == 2:
			sci_w = 20.0
		elif sci_st == 1:
			sci_w = 12.0
		else:
			sci_w = 6.2 if (GameState.has_cat_sharikov or GameState.soup_quarters >= 1) else 3.5
		var sci_w_ok: bool = not _recent_event_ids.has(sci_id) and not (sci_st == 2 and day < extraction_day)
		if sci_w_ok:
			candidates.append({"id": sci_id, "weight": sci_w})

	# 4. Wasteland Smuggler Convoy Pact candidate
	if pact_st < 3:
		var pact_id: String = "rescue_raider_pact_%d" % (pact_st + 1)
		var pact_w: float = 3.2
		if pact_st == 2:
			pact_w = 20.0
		elif pact_st == 1:
			var has_mech: bool = GameState.has_working_item("fuel") or GameState.has_working_item("scrap") or GameState.has_working_item("antibiotics") or GameState.has_working_item("medkit") or GameState.has_working_item("toolbox")
			pact_w = 12.0 if has_mech else 7.5
		else:
			var can_hail: bool = GameState.has_working_item("radio") or GameState.ammo_count >= 2 or GameState.soup_quarters >= 4 or GameState.has_working_item("harmonica")
			pact_w = 6.2 if can_hail else 2.8
		var pact_w_ok: bool = not _recent_event_ids.has(pact_id) and not (pact_st == 2 and day < extraction_day)
		if pact_w_ok:
			candidates.append({"id": pact_id, "weight": pact_w})

	if candidates.is_empty():
		return ""

	var sum_w: float = 0.0
	for c_v in candidates:
		var c: Dictionary = c_v
		sum_w += float(c.get("weight", 1.0))

	var r: float = rng.randf() * sum_w
	var acc: float = 0.0
	for c_v in candidates:
		var c: Dictionary = c_v
		acc += float(c.get("weight", 1.0))
		if r <= acc:
			return str(c.get("id", ""))
	var first_c: Dictionary = candidates[0]
	return str(first_c.get("id", ""))


static func _get_ready_consequence_event_ids(day: int) -> Array[String]:
	var ready: Array[String] = []
	var sf: Dictionary = GameState.story_flags
	if sf.has("helped_courier_day") and not bool(sf.get("courier_repaid", false)):
		if day >= int(sf.get("helped_courier_day", 0)) + 4 and not _recent_event_ids.has("courier_repayment_drop"):
			ready.append("courier_repayment_drop")
	if bool(sf.get("vendetta_active", false)):
		var v_day: int = int(sf.get("vendetta_day", 1))
		if day >= v_day + 4 and not _recent_event_ids.has("vendetta_reprisal_raid"):
			ready.append("vendetta_reprisal_raid")
	if sf.has("helped_tinker_day") and not bool(sf.get("tinker_repaid", false)):
		if day >= int(sf.get("helped_tinker_day", 0)) + 4 and not _recent_event_ids.has("tinker_workshop_dividend"):
			ready.append("tinker_workshop_dividend")
	if sf.has("planted_greens_day") and not bool(sf.get("harvested_greens", false)):
		if day >= int(sf.get("planted_greens_day", 0)) + 4 and not _recent_event_ids.has("sprouted_bunker_greens"):
			ready.append("sprouted_bunker_greens")
	if sf.has("flare_drop_day") and not bool(sf.get("flare_drop_claimed", false)):
		if day >= int(sf.get("flare_drop_day", 0)) + 4 and not _recent_event_ids.has("beacon_supply_drop_arrival"):
			ready.append("beacon_supply_drop_arrival")
	if sf.has("chemist_stored_day") and not bool(sf.get("chemist_returned", false)):
		if day >= int(sf.get("chemist_stored_day", 0)) + 4 and not _recent_event_ids.has("chemist_antidote_return"):
			ready.append("chemist_antidote_return")
	return ready


static func _get_event_weight(event_id: String, day: int) -> float:
	var dist_km: float = float(GameState.nuke_config.get("distance_km", 10.0))
	var raider_agg: float = float(GameState.nuke_config.get("raider_aggression", 0.5))
	raider_agg *= float(GameState.get_difficulty_config().get("raider_mult", 1.0))
	if day <= 12:
		raider_agg += float(GameState.neighborhood_modifiers.get("early_raider_mod", 0.0))
	var temp_c: float = float(GameState.bunker_temp_c)
	var sf: Dictionary = GameState.story_flags
	var present_cnt: int = _get_present_members().size()

	match event_id:
		"repair_broken_gear":
			return 4.0 if not _get_broken_owned_item_ids().is_empty() else 0.0
		"companion_pancake_dog":
			if GameState.has_dog_pancake or day < 3:
				return 0.0
			return 2.4
		"classic_pancake_treasure":
			return 2.2 if GameState.has_dog_pancake else 0.7
		"classic_sharikov_mice":
			return 2.0 if GameState.has_cat_sharikov else 1.2
		"raiders_blast_hatch":
			if day < 4:
				return 0.0
			return 1.4 + raider_agg * 2.0
		"classic_raider_extortion_note":
			if day < 6:
				return 0.0
			return 1.0 + raider_agg * 1.5
		"nuke_blizzard_freeze":
			if temp_c < 5.0:
				return 4.5
			elif temp_c < 13.0:
				return 1.4
			return 0.35
		"nuke_ground_zero_tremor":
			if dist_km < 15.0:
				return 4.2
			elif dist_km < 35.0:
				return 1.5
			return 0.4
		"nuke_downwind_acid_rain":
			return 2.4 if GameState.surface_radiation_sv > 2.5 else 1.1
		"nuke_emp_magnetic_storm":
			return 1.8 if int(GameState.nuke_config.get("yield_kt", 800)) >= 250 else 0.9
		"ooze_green_pipe":
			return 1.9 if _get_mutant_member().is_empty() else 0.7
		"classic_mutant_night_vision":
			return 2.4 if not _get_mutant_member().is_empty() else 0.9
		"trader_wasteland_swap":
			return 2.2 if day >= 4 else 0.8
		"family_birthday":
			return 1.3 if day >= 5 else 0.4
		"hazard_mutant_roaches", "hazard_vent_filter":
			return 1.8
		"osm_grocery_cart_rattle", "osm_pharmacy_courier", "osm_neighbor_bunker_tap", "osm_hardware_looters", "osm_restaurant_aroma", "osm_school_civil_defense_cache", "osm_park_mutant_geese", "osm_civic_siren_malfunction", "osm_street_delivery_van", "osm_firefighter_check":
			return 1.55
		# --- V2 Vehicle Escape Events ---
		"vehicle_garage_discovery":
			return 2.4 if GameState.get_vehicle_parts_owned_count() < 4 else 0.7
		"vehicle_siphon_derelict":
			return 2.4 if GameState.fuel_cans < GameState.fuel_needed else 0.9
		"vehicle_engine_tuneup":
			if GameState.vehicle_tuned:
				return 0.25
			return 2.5 if GameState.get_vehicle_parts_owned_count() >= 1 else 1.3
		"vehicle_armored_bumper":
			return 2.1 if (GameState.get_vehicle_parts_owned_count() < 4 or not GameState.vehicle_tuned) else 1.0
		"vehicle_nomad_parts_swap":
			if day < 3:
				return 0.0
			return 2.0 if (GameState.get_vehicle_parts_owned_count() < 4 or GameState.fuel_cans < GameState.fuel_needed) else 0.6
		# --- V2 Deep Family Relationship, Guilt & [COOPERATE] Events ---
		"family_haunted_unrescued":
			if GameState.left_behind_members.is_empty():
				return 0.0
			return 3.4
		"family_phantom_knock_guilt":
			if GameState.left_behind_members.is_empty():
				return 0.0
			return 2.7
		"family_ration_accusation":
			if present_cnt < 2:
				return 0.0
			return 2.6 if (GameState.soup_quarters <= 8 or _has_strained_pair(5)) else 1.3
		"family_generation_clash", "family_secret_diary_feud":
			return 1.9 if present_cnt >= 2 else 0.0
		"family_expedition_jealousy":
			return 1.9 if (present_cnt >= 2 and day >= 4) else 0.0
		"family_midnight_card_tournament":
			return 2.0 if present_cnt >= 2 else 0.5
		"family_shared_coat_freeze":
			if present_cnt < 2:
				return 0.0
			return 2.8 if temp_c < 14.0 else 1.25
		"family_breakdown_intervention":
			return 3.2 if _has_stressed_or_breakdown_member() else 1.0
		"family_quiet_apology":
			if present_cnt < 2:
				return 0.0
			return 2.9 if _has_strained_pair(10) else 1.1
		"family_cooperate_pipe_burst":
			return 2.1 if _has_cooperating_pair(45) else 1.35
		"family_cooperate_hatch_brace":
			if day < 3:
				return 0.4
			return 2.2 if _has_cooperating_pair(45) else 1.35
		"family_heirloom_watch_pledge":
			return 1.75 if (present_cnt >= 2 and day >= 4) else 0.5
		# --- V2 Real-World Landmark Conditional Events ---
		"landmark_doctor_triage_ledger", "landmark_clinic_quarantine_notice":
			return 2.35 if _has_poi_matching(["doctor", "clinic", "hospital", "urgent", "medical"]) else 1.15
		"landmark_supermarket_cold_storage":
			var rival_boost: float = 0.5 if sf.has("rival_looters_day") else 0.0
			return (2.25 if _has_poi_matching(["grocery", "supermarket", "market", "bakery"]) else 1.15) + rival_boost
		"landmark_pharmacy_iodide_shipment":
			return 2.25 if _has_poi_matching(["pharmacy", "drug", "apothecary"]) else 1.15
		"landmark_gas_station_underground_tank", "landmark_auto_shop_battery_rack":
			return 2.3 if _has_poi_matching(["fuel_auto", "fuel", "gas", "auto", "76", "service"]) else 1.15
		"landmark_firehouse_siren_relay":
			return 2.2 if _has_poi_matching(["civic", "fire", "police", "ems", "station"]) else 1.15
		"landmark_highschool_ham_club", "landmark_library_microfilm_atlas":
			return 2.15 if _has_poi_matching(["school", "high", "library", "college"]) else 1.1
		"landmark_hardware_scrap_yard":
			return 2.2 if _has_poi_matching(["hardware", "lumber", "tool", "supply"]) else 1.15
		"landmark_church_sanctuary_candles":
			return 2.15 if _has_poi_matching(["church", "parish", "chapel", "worship"]) else 1.1
		# --- V2 Delayed Persistent Consequences via story_flags ---
		"stranger_wounded_courier":
			if day < 3 or bool(sf.get("courier_resolved", false)):
				return 0.0
			return 2.4
		"courier_repayment_drop":
			if sf.has("helped_courier_day") and not bool(sf.get("courier_repaid", false)) and day >= int(sf.get("helped_courier_day", 0)) + 4:
				return 14.0
			return 0.0
		"vendetta_reprisal_raid":
			if bool(sf.get("vendetta_active", false)) and day >= int(sf.get("vendetta_day", 1)) + 4:
				return 14.0
			return 0.0
		"stranger_desperate_tinker":
			if day < 3 or bool(sf.get("tinker_met", false)):
				return 0.0
			return 2.1
		"tinker_workshop_dividend":
			if sf.has("helped_tinker_day") and not bool(sf.get("tinker_repaid", false)) and day >= int(sf.get("helped_tinker_day", 0)) + 4:
				return 12.0
			return 0.0
		"mystery_seed_tin":
			if day < 2 or bool(sf.get("seed_tin_seen", false)):
				return 0.0
			return 2.0
		"sprouted_bunker_greens":
			if sf.has("planted_greens_day") and not bool(sf.get("harvested_greens", false)) and day >= int(sf.get("planted_greens_day", 0)) + 4:
				return 12.0
			return 0.0
		"unsealed_munitions_crate":
			if day < 4 or bool(sf.get("munitions_seen", false)):
				return 0.0
			return 1.9
		"beacon_supply_drop_arrival":
			if sf.has("flare_drop_day") and not bool(sf.get("flare_drop_claimed", false)) and day >= int(sf.get("flare_drop_day", 0)) + 4:
				return 12.0
			return 0.0
		"stranger_chemist_vial":
			if day < 5 or bool(sf.get("chemist_seen", false)):
				return 0.0
			return 1.85
		"chemist_antidote_return":
			if sf.has("chemist_stored_day") and not bool(sf.get("chemist_returned", false)) and day >= int(sf.get("chemist_stored_day", 0)) + 4:
				return 12.0
			return 0.0
		_:
			return 1.25


# ==============================================================================
# EVENT BUILDER (103 DISTINCT EVENTS)
# ==============================================================================

static func build_event_by_id(event_id: String, day: int, rng: RandomNumberGenerator) -> Dictionary:
	var active_rng: RandomNumberGenerator = rng if rng != null else GameState.rng
	var house_addr: String = _get_house_address()
	var hood: String = _get_neighborhood_label()
	var nuke_target: String = str(GameState.nuke_config.get("target_name", "Strategic Ground Zero"))
	var yield_kt: int = int(GameState.nuke_config.get("yield_kt", 800))
	var dist_km: float = float(GameState.nuke_config.get("distance_km", 8.5))
	var rand_member: Dictionary = _pick_random_member(active_rng)
	var m_name: String = str(rand_member.get("name", "Ted"))
	var m_id: String = str(rand_member.get("id", "member_0"))

	var ev: Dictionary = {
		"id": event_id,
		"title": "Shelter Log Entry",
		"description": "",
		"category": "general",
		"type": "item_choice",
		"options": [],
		"context": {
			"day": day,
			"member_id": m_id,
			"member_name": m_name
		}
	}

	match event_id:
		# ----------------------------------------------------------------------
		# 1. DAY 1 OPENING BRIEFING
		# ----------------------------------------------------------------------
		"day1_civil_defense_seal":
			ev["title"] = "CONELRAD Seal Protocol: Day 1"
			ev["category"] = "opening"
			ev["type"] = "item_choice"
			ev["description"] = "Plaster dust drifts from the concrete ceiling beneath %s. Exactly %.1f km away at %s, the %d kt shockwave has subsided into an eerie orange twilight over %s. Before settling in for the long haul, how should we secure the shelter?" % [house_addr, dist_km, nuke_target, yield_kt, hood]
			ev["options"] = [
				_opt("use_radio", "Tune CONELRAD 640 AM Band", "radio", GameState.has_working_item("radio")),
				_opt("use_toolbox", "Torque Blast Hatch Gaskets", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_book", "Consult Civil Defense Manual", "book", GameState.has_working_item("book")),
				_opt("roll_call", "Take Family Roll Call & Ration Count", "", true)
			]

		# ----------------------------------------------------------------------
		# 2-4. MILITARY RESCUE CHAIN (0 -> 1 -> 2 -> 3)
		# ----------------------------------------------------------------------
		"rescue_military_1":
			ev["title"] = "CONELRAD Emergency Carrier Wave"
			ev["category"] = "rescue_military"
			ev["type"] = "item_choice"
			ev["description"] = "Between bursts of Geiger-counter static from the %s blast zone, a crisp Civil Defense evacuation tone pulses across 640 and 1240 kHz! Someone out there is triangulating surviving fallout shelters across %s." % [nuke_target, hood]
			ev["options"] = [
				_opt("use_radio", "Lock Signal on the Radio!", "radio", GameState.has_working_item("radio")),
				_opt("tap_pipes", "Tap SOS on Municipal Water Main", "", true),
				_opt("ignore", "Conserve Power & Stay Quiet", "", true)
			]

		"rescue_military_2":
			ev["title"] = "Civil Defense Helicopter Recon!"
			ev["category"] = "rescue_military"
			ev["type"] = "item_choice"
			ev["description"] = "THWOP-THWOP-THWOP! The tableware rattles as an olive-drab U.S. Civil Defense rotorcraft banks low right over %s! A spotter drops a flare canister asking surviving bunkers in this grid sector to mark their coordinates immediately." % house_addr
			ev["options"] = [
				_opt("use_map", "Relay Exact Grid Sector from Map", "map", GameState.has_working_item("map")),
				_opt("use_flashlight", "Flash Morse SOS via Periscope", "flashlight", GameState.has_working_item("flashlight")),
				_opt("use_axe", "Chop Crate Wood for Signal Smoke", "axe", GameState.has_working_item("axe")),
				_opt("wave_arms", "Bang Soup Pots on the Hatch!", "", true),
				_opt("ignore", "Stay Hidden Below Ground", "", true)
			]

		"rescue_military_3":
			ev["title"] = "Hazmat Boots on the Blast Hatch!"
			ev["category"] = "rescue_military"
			ev["type"] = "yes_no"
			ev["description"] = "Heavy lead-lined boots thud onto the porch of %s! Through the periscope you spot three U.S. Civil Defense troopers in yellow CONELRAD hazmat suits waving a decontamination stretcher and shouting: 'EVACUATION CONVOY CHARLIE — UNBOLT YOUR HATCH NOW!'" % house_addr
			ev["options"] = [
				_opt("yes", "Unbolt Hatch & Evacuate to Safety!", "", true),
				_opt("no", "Refuse — It Might Be a Trick!", "", true)
			]

		# ----------------------------------------------------------------------
		# 5-7. REAL-WORLD OSM NEIGHBORHOOD SANCTUARY CHAIN (0 -> 1 -> 2 -> 3)
		# ----------------------------------------------------------------------
		"rescue_sanctuary_1":
			var church_name: String = _get_sanctuary_poi_name()
			ev["context"]["poi_name"] = church_name
			ev["title"] = "Bell Toll from %s" % church_name
			ev["category"] = "rescue_sanctuary"
			ev["type"] = "item_choice"
			ev["description"] = "Three clear bronze bell strokes echo across %s! Survivors fortifying %s have slipped a charcoal-written note under the hatch at %s: they are building a clean-water community sanctuary and ask if good neighbors can spare supplies or know-how." % [hood, church_name, house_addr]
			ev["options"] = [
				_opt("give_water", "Share 1 Bottle of Clean Water", "water", GameState.water_quarters >= 4),
				_opt("give_soup", "Share 1 Can of Tomato Soup", "soup", GameState.soup_quarters >= 4),
				_opt("use_medkit", "Donate Antiseptic from Medkit", "medkit", GameState.has_working_item("medkit")),
				_opt("use_book", "Copy Filter Plans from Handbook", "book", GameState.has_working_item("book")),
				_opt("ignore", "Keep Hatch Sealed & Hoard Goods", "", true)
			]

		"rescue_sanctuary_2":
			var church_name2: String = _get_sanctuary_poi_name()
			ev["context"]["poi_name"] = church_name2
			ev["title"] = "Fortifying %s" % church_name2
			ev["category"] = "rescue_sanctuary"
			ev["type"] = "item_choice"
			ev["description"] = "A lantern blinks friendly code outside %s. Wardens from %s report their basement hydroponic greenhouse and diesel generator are nearly online, but they need tools, timber, or armed watchmen for one night to secure the perimeter!" % [house_addr, church_name2]
			ev["options"] = [
				_opt("use_toolbox", "Wire Generator with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_axe", "Hew Barricade Beams with Axe", "axe", GameState.has_working_item("axe")),
				_opt("use_rifle", "Stand Perimeter Watch with Rifle", "rifle", GameState.has_working_item("rifle")),
				_opt("use_book", "Draft Rain-Cistern Blueprints", "book", GameState.has_working_item("book")),
				_opt("help_hands", "Send %s to Haul Sandbags" % m_name, "", true),
				_opt("ignore", "Apologize & Stay Downstairs", "", true)
			]

		"rescue_sanctuary_3":
			var church_name3: String = _get_sanctuary_poi_name()
			ev["context"]["poi_name"] = church_name3
			ev["title"] = "The %s Delegation!" % church_name3
			ev["category"] = "rescue_sanctuary"
			ev["type"] = "yes_no"
			ev["description"] = "Warm guitar music and the scent of fresh baked flatbread drift down your air intake! Neighbors from %s stand outside %s in stitched fallout ponchos holding extra masks: 'The greenhouse and clean well are running! There is a warm bunk waiting for every one of you!'" % [church_name3, house_addr]
			ev["options"] = [
				_opt("yes", "Join the %s Sanctuary!" % church_name3, "", true),
				_opt("no", "Politely Stay in Our Own Bunker", "", true)
			]

		# ----------------------------------------------------------------------
		# 8-10. VAULT SCIENTIST & SHARIKOV THE CAT CHAIN (0 -> 1 -> 2 -> 3)
		# ----------------------------------------------------------------------
		"rescue_scientist_1":
			ev["title"] = "The Cat with the Copper Wire Collar"
			ev["category"] = "rescue_scientist"
			ev["type"] = "item_choice"
			ev["description"] = "Mrrrow? Scratching echoes inside the ventilation elbow! Peering out stands a dignified, slightly cross-eyed striped cat wearing an anodized " + "'SHARIKOV-7' aluminum capsule collar trailing a thin spool of insulated telephone wire."
			ev["options"] = [
				_opt("adopt_soup", "Feed 1/4 Soup & Adopt Sharikov!", "soup", GameState.soup_quarters >= 1),
				_opt("adopt_pet", "Coax the Curious Cat Inside Gently", "", true),
				_opt("ignore", "Shoo the Mysterious Feline Away", "", true)
			]

		"rescue_scientist_2":
			ev["title"] = "Sharikov's Humming Telemetry Wire"
			ev["category"] = "rescue_scientist"
			ev["type"] = "item_choice"
			ev["description"] = "Sharikov sits ramrod-straight beside the periscope, pawing rhythmically at the copper wire trailing from his collar into a storm-drain conduit beneath %s! Unscrewing his collar capsule reveals microfilm stamped: 'INSTITUTE SUB-VAULT OMEGA — TRANSMIT SURFACE DATA.'" % house_addr
			ev["options"] = [
				_opt("use_radio", "Patch Telemetry Wire into Radio", "radio", GameState.has_working_item("radio")),
				_opt("use_flashlight", "Follow Wire with Flashlight", "flashlight", GameState.has_working_item("flashlight")),
				_opt("use_map", "Clip Local Fallout Map to Collar", "map", GameState.has_working_item("map")),
				_opt("send_note", "Tuck a Polite Charcoal Note Inside", "", true),
				_opt("ignore", "Ignore It — Cats Are Weird", "", true)
			]

		"rescue_scientist_3":
			ev["title"] = "Men in Gleaming Mylar Radiation Suits!"
			ev["category"] = "rescue_scientist"
			ev["type"] = "yes_no"
			ev["description"] = "HISS-CLICK! Two bespectacled government scientists in mirror-bright silver Mylar suits knock politely on your hatch, holding a velvet cushion for Sharikov: 'Congratulations, test household! Having passed the Feline Biospherics Evaluation, your family is cleared for VIP Sub-Vault Omega extraction!'"
			ev["options"] = [
				_opt("yes", "Board the VIP Sub-Vault Transport!", "", true),
				_opt("no", "Decline — Too Much Science for Us", "", true)
			]

		# ----------------------------------------------------------------------
		# 11-23. CLASSIC 60 SECONDS! HAZARDS, RAIDERS, OOZE, TRADER, REPAIR
		# ----------------------------------------------------------------------
		"hazard_mutant_roaches":
			ev["title"] = "Rad-Roaches the Size of Loafers!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "CHITTER-CLACK! Half a dozen glossy, six-inch mutant cockroaches with glowing antennae squeeze out from under the sump grate and begin forming a union near the soup shelf! %s is already standing on a chair." % m_name
			ev["options"] = [
				_opt("use_bug_spray", "Blast Them with Mutant Bug Spray!", "bug_spray", GameState.has_working_item("bug_spray")),
				_opt("use_cat", "Let Sharikov Hunt Them Down!", "cat", GameState.has_cat_sharikov),
				_opt("use_axe", "Chop the Swarm with the Axe", "axe", GameState.has_working_item("axe")),
				_opt("use_book", "Whack Them with the Heavy Handbook", "book", GameState.has_working_item("book")),
				_opt("ignore", "Make Peace with Our Bug Overlords", "", true)
			]

		"hazard_vent_filter":
			ev["title"] = "Choking Fallout Dust in the Air Vent!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "COUGH! The hand-cranked air intake filter begins rattling like a coffee grinder, puffing radioactive gray ash from the %s plume straight into the bunker! Someone needs to service that baffle fast." % nuke_target
			ev["options"] = [
				_opt("use_toolbox", "Rebuild Baffle with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_gas_mask", "Wear Gas Mask & Clean Filter", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_book", "Fold Charcoal Filter per Handbook", "book", GameState.has_working_item("book")),
				_opt("stuff_rags", "Stuff Old Socks into the Pipe", "", true)
			]

		"raiders_blast_hatch":
			var mut_member: Dictionary = _get_mutant_member()
			var mut_name: String = str(mut_member.get("name", "Mutant"))
			ev["context"]["mutant_name"] = mut_name
			ev["title"] = "Wasteland Raiders Banging on the Hatch!"
			ev["category"] = "raiders"
			ev["type"] = "item_choice"
			ev["description"] = "CLANG! CLANG! Crowbars scrape viciously against the exterior hatch at %s! A gang of masked marauders prowling %s has spotted your air pipe and is trying to wrench the blast door open!" % [house_addr, hood]
			var raid_opts: Array = []
			if GameState.padlock_active:
				raid_opts.append(_opt("use_padlock", "Rely on Heavy Padlock (Auto-Blocks!)", "padlock", true))
			var rifle_lbl: String = "Fire Warning Shot (Uses 1 Ammo)" if GameState.ammo_count > 0 else "Brandish Rifle to Intimidate"
			raid_opts.append(_opt("use_rifle", rifle_lbl, "rifle", GameState.has_working_item("rifle")))
			raid_opts.append(_opt("use_axe", "Swing the Fireman's Axe!", "axe", GameState.has_working_item("axe")))
			raid_opts.append(_opt("use_dog", "Unleash Pancake's Hound Bark!", "dog", GameState.has_dog_pancake))
			if not mut_member.is_empty():
				raid_opts.append(_opt("use_mutant", "Have %s Roar at the Viewport!" % mut_name, "", true))
			raid_opts.append(_opt("use_harmonica", "Serenade Them on Harmonica?!", "harmonica", GameState.has_working_item("harmonica")))
			raid_opts.append(_opt("cower", "Brace in the Dark & Pray", "", true))
			ev["options"] = raid_opts

		"ooze_green_pipe":
			var mut_cand: Dictionary = _pick_mutant_candidate(active_rng)
			var cand_name: String = str(mut_cand.get("name", m_name))
			var cand_id: String = str(mut_cand.get("id", m_id))
			ev["context"]["member_id"] = cand_id
			ev["context"]["member_name"] = cand_name
			ev["title"] = "Mysterious Glowing Green Pipe Ooze!"
			ev["category"] = "mutation"
			ev["type"] = "item_choice"
			ev["description"] = "BLORP... SIZZLE. Thick, neon-emerald sludge that glows bright enough to read comic books by is oozing from an overhead pipe joint right above %s's bunk! It smells faintly of lime gelatin and split atoms." % cand_name
			ev["options"] = [
				_opt("use_toolbox", "Wrench the Joint Tight with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_gas_mask", "Scrub Pipe Safely in Gas Mask", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("examine_ooze", "Have %s Examine & Poke the Ooze!" % cand_name, "", true),
				_opt("wipe_rag", "Wipe Cautiously with a Rag", "", true),
				_opt("ignore", "Just Move the Pillow Six Inches", "", true)
			]

		"companion_pancake_dog":
			ev["title"] = "Whimpering & Tail-Thumping at the Hatch!"
			ev["category"] = "companion"
			ev["type"] = "item_choice"
			ev["description"] = "SCRITCH-SCRITCH... THUMP-THUMP-THUMP! Checking the periscope above %s reveals a scruffy, floppy-eared golden mutt with soulful eyes and a pancake-flat nose wagging his entire backside despite the fallout!" % house_addr
			ev["options"] = [
				_opt("adopt_soup", "Share 1/4 Soup & Adopt Pancake!", "soup", GameState.soup_quarters >= 1),
				_opt("let_in", "Whistle & Let the Good Boy Inside!", "", true),
				_opt("ignore", "Keep Hatch Closed — No Pets Allowed", "", true)
			]

		"trader_wasteland_swap":
			var wanted_gear: String = "gas_mask" if not GameState.has_working_item("gas_mask") else ("radio" if not GameState.has_working_item("radio") else "supplies")
			ev["context"]["wanted_gear"] = wanted_gear
			var offer_desc: String = "a mint-condition Gas Mask" if wanted_gear == "gas_mask" else ("a working CONELRAD Radio" if wanted_gear == "radio" else "1 Soup Can, 1 Water Bottle & 1 Medkit")
			ev["title"] = "Polite Knock: The Wasteland Peddler"
			ev["category"] = "trader"
			ev["type"] = "item_choice"
			ev["description"] = "Shave-and-a-haircut, two bits! A masked tinker pushing a lead-lined wheelbarrow down %s offers a fair swap through the hatch chute: he'll trade %s in exchange for ammunition, bug spray, or a pastime game!" % [hood, offer_desc]
			ev["options"] = [
				_opt("trade_ammo", "Trade 2 Rifle Ammo", "ammo", GameState.ammo_count >= 2),
				_opt("trade_bug_spray", "Trade 1 Mutant Bug Spray", "bug_spray", GameState.has_working_item("bug_spray")),
				_opt("trade_cards", "Trade Deck of Playing Cards", "cards", GameState.has_working_item("cards")),
				_opt("trade_checkers", "Trade Checkers Set", "checkers", GameState.has_working_item("checkers")),
				_opt("decline", "No Thanks — Wave Him On", "", true)
			]

		"repair_broken_gear":
			var broken_list: Array[String] = _get_broken_owned_item_ids()
			var target_broken: String = broken_list[0] if not broken_list.is_empty() else "radio"
			var broken_label: String = str(ITEM_LABELS.get(target_broken, target_broken.capitalize()))
			var handy_member: Dictionary = _get_member_with_trait("handy")
			var handy_name: String = str(handy_member.get("name", ""))
			ev["context"]["broken_item_id"] = target_broken
			ev["context"]["broken_item_name"] = broken_label
			ev["context"]["handy_name"] = handy_name
			ev["title"] = "Workbench Opportunity: Broken %s" % broken_label
			ev["category"] = "repair"
			ev["type"] = "item_choice"
			ev["description"] = "Our broken %s has been gathering dust on the shelf like an expensive 1950s paperweight. With a quiet afternoon in the bunker, we might be able to get it working again!" % broken_label
			var rep_opts: Array = [
				_opt("use_toolbox", "Overhaul with the Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_book", "Follow Boy Scout Repair Diagram", "book", GameState.has_working_item("book"))
			]
			if not handy_member.is_empty():
				rep_opts.append(_opt("use_handy", "Let Handy %s Fix It by Ear!" % handy_name, "", true))
			rep_opts.append(_opt("tinker_blind", "Whack It Firmly & Twist Wires", "", true))
			rep_opts.append(_opt("ignore", "Leave It Broken for Now", "", true))
			ev["options"] = rep_opts

		"bunker_darkness_bulb":
			ev["title"] = "BZZT-POP! Pitch Black in the Bunker!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "The single overhead incandescent bulb flickers thrice, turns violet, and plunges the shelter into velvety darkness! Immediately somebody steps on %s's toe and panic begins rising." % m_name
			ev["options"] = [
				_opt("use_flashlight", "Click On the Flashlight", "flashlight", GameState.has_working_item("flashlight")),
				_opt("use_toolbox", "Splice Spare Filament with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_harmonica", "Play Calm Music in the Dark", "harmonica", GameState.has_working_item("harmonica")),
				_opt("sit_in_dark", "Sit Completely Still Until Eyes Adjust", "", true)
			]

		"family_argument":
			ev["title"] = "Great Bunker Elbow-Room Dispute!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Cabin fever strikes! %s accuses everyone else of chewing soup too loudly and hogging the good blanket. Voices are echoing off the concrete walls at dangerous decibels." % m_name
			ev["options"] = [
				_opt("use_cards", "Deal a Friendly Round of Rummy", "cards", GameState.has_working_item("cards")),
				_opt("use_checkers", "Settle It Over Checkers", "checkers", GameState.has_working_item("checkers")),
				_opt("use_harmonica", "Drown Out Bickering with Harmonica", "harmonica", GameState.has_working_item("harmonica")),
				_opt("use_book", "Read Aloud from Adventure Stories", "book", GameState.has_working_item("book")),
				_opt("let_vent", "Enforce Five Minutes of Quiet Time", "", true)
			]

		"outside_suspicious_suitcase":
			ev["title"] = "Unattended Leather Valise on the Porch!"
			ev["category"] = "exploration"
			ev["type"] = "yes_no"
			ev["description"] = "Peering through the periscope at %s, you spot a monogrammed 1950s travel valise sitting neatly beside your hatch! No footprints in the ash... just a brass clasp gleaming invitingly. Reach out and drag it inside?" % house_addr
			ev["options"] = [
				_opt("yes", "Snatch the Valise Inside Quickly!", "", true),
				_opt("no", "Leave It — Classic Booby-Trap!", "", true)
			]

		"outside_mysterious_knock":
			ev["title"] = "Three Slow Knocks at 3:15 AM"
			ev["category"] = "exploration"
			ev["type"] = "yes_no"
			ev["description"] = "BOOM... BOOM... BOOM. Everyone freezes awake. At 3:15 in the morning, something—or someone—just knocked three deliberate times on the steel hatch above %s. The periscope is fogged with condensation. Crack the hatch?" % house_addr
			ev["options"] = [
				_opt("yes", "Crack Open the Hatch & Peek!", "", true),
				_opt("no", "Keep Double-Bolted Till Dawn", "", true)
			]

		"quirky_beard_overgrowth":
			ev["title"] = "Magnificent Atomic Beard Overgrowth!"
			ev["category"] = "quirky"
			ev["type"] = "item_choice"
			ev["description"] = "Without a barbershop left standing in %s, facial hair and unruly bangs in the shelter have reached Old Testament prophet proportions! Soup spoons keep getting tangled mid-bite." % hood
			ev["options"] = [
				_opt("use_axe", "Perform a Heroic Close Shave with Axe!", "axe", GameState.has_working_item("axe")),
				_opt("braid_it", "Style & Braid Into Post-War Fashion", "", true),
				_opt("ignore", "Let Nature Take Its Woolly Course", "", true)
			]

		"family_birthday":
			var new_age: int = int(rand_member.get("age", 25)) + 1
			ev["context"]["new_age"] = new_age
			ev["title"] = "Happy %dth Bunker Birthday, %s!" % [new_age, m_name]
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "According to the grease-pencil calendar scratched onto the wall, today %s officially turns %d! Even beneath %s in the middle of an atomic wasteland, a birthday deserves a proper celebration." % [m_name, new_age, house_addr]
			ev["options"] = [
				_opt("feast_soup", "Frost a Warm Soup 'Birthday Cake' (2/4 Soup)", "soup", GameState.soup_quarters >= 2),
				_opt("use_harmonica", "Play 'Happy Birthday' on Harmonica!", "harmonica", GameState.has_working_item("harmonica")),
				_opt("use_cards", "Let %s Win at Card Tricks!" % m_name, "cards", GameState.has_working_item("cards")),
				_opt("sing_song", "Sing Four-Part Civil Defense Harmony!", "", true)
			]

		# ----------------------------------------------------------------------
		# 24-27. NUKE ZONE & PHYSICS SPECIAL EVENTS
		# ----------------------------------------------------------------------
		"nuke_blizzard_freeze":
			ev["title"] = "Nuclear Winter Blizzard & Freezing Pipes!"
			ev["category"] = "nuke_zone"
			ev["type"] = "item_choice"
			ev["description"] = "Soot-blackened clouds blocking the sun have plunged shelter temperature to %.1f°C! Hoarfrost creeps across the concrete walls beneath %s, and the copper water manifold is groaning on the verge of bursting solid!" % [GameState.bunker_temp_c, house_addr]
			ev["options"] = [
				_opt("use_axe", "Chop Packing Crates for Brazier Heat", "axe", GameState.has_working_item("axe")),
				_opt("use_toolbox", "Insulate & Bleed Pipes with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_flashlight", "Warm Valve & Huddle Under Blankets", "flashlight", GameState.has_working_item("flashlight")),
				_opt("shiver", "Jump in Place & Share Body Heat", "", true)
			]

		"nuke_ground_zero_tremor":
			ev["title"] = "Ground Zero Crater Aftershock!"
			ev["category"] = "nuke_zone"
			ev["type"] = "item_choice"
			ev["description"] = "RUMBLE-CRACK! Being just %.1f km from the %s (%d kt) crater, a violent subterranean tectonic settling wave slams into the foundation of %s! Hairline cracks spiderweb across our bunker ceiling!" % [dist_km, nuke_target, yield_kt, house_addr]
			ev["options"] = [
				_opt("use_toolbox", "Shore Up Ceiling Joists with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_gas_mask", "Don Gas Mask Against Falling Dust", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("duck_cover", "Bert the Turtle: DUCK AND COVER!", "", true)
			]

		"nuke_downwind_acid_rain":
			ev["title"] = "Downwind Black Fallout Rainstorm!"
			ev["category"] = "nuke_zone"
			ev["type"] = "item_choice"
			ev["description"] = "Oily black rain carried downwind from %s hisses across the street above %s (surface reading: %.1f Sv/hr). Acidic runoff threatens to seep around the exterior sump drain—unless distilled or sealed!" % [nuke_target, house_addr, GameState.surface_radiation_sv]
			ev["options"] = [
				_opt("use_book", "Rig Double-Boil Charcoal Still (Handbook)", "book", GameState.has_working_item("book")),
				_opt("use_toolbox", "Tighten Sump Check-Valve with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_radio", "Track CONELRAD Weather Front", "radio", GameState.has_working_item("radio")),
				_opt("wait_out", "Bucket Out Seepage by Hand", "", true)
			]

		"nuke_emp_magnetic_storm":
			ev["title"] = "Compton Ionization Sparks on the Conduits!"
			ev["category"] = "nuke_zone"
			ev["type"] = "item_choice"
			ev["description"] = "Eerie magenta St. Elmo's fire dances along the metal plumbing! Upper-atmosphere magnetic disturbances lingering from the %d kt detonation over %s are inducing wild voltage surges in our shelter wiring!" % [yield_kt, nuke_target]
			ev["options"] = [
				_opt("use_toolbox", "Clamp Grounding Strap with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("unplug_gear", "Quickly Unplug & Cage Electronics", "", true),
				_opt("watch_aurora", "Marvel at the Pretty Atomic Sparks", "", true)
			]

		# ----------------------------------------------------------------------
		# 28-37. REAL-WORLD OPENSTREETMAP NEIGHBORHOOD EVENTS
		# ----------------------------------------------------------------------
		"osm_grocery_cart_rattle":
			var groc_name: String = _find_poi_name(["grocery", "supermarket", "market", "bakery", "qfc", "store"], "Broadway Corner Market")
			ev["context"]["poi_name"] = groc_name
			ev["title"] = "Runaway Cart from %s!" % groc_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "RATTLE-CLANG! A gust of fallout wind sends a chrome shopping cart stamped %s rolling down %s right into your front curb—still loaded with a forgotten case of canned rations!" % [groc_name, house_addr]
			ev["options"] = [
				_opt("use_gas_mask", "Sprint Out in Gas Mask & Grab Tins!", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_axe", "Hook the Cart Handle from Hatch with Axe", "axe", GameState.has_working_item("axe")),
				_opt("dash_bare", "Hold Breath & Make a 5-Second Dash!", "", true),
				_opt("ignore", "Too Radioactive — Leave the Cart", "", true)
			]

		"osm_pharmacy_courier":
			var pharm_name: String = _find_poi_name(["pharmacy", "clinic", "hospital", "drug", "apothecary", "medical"], "Neighborhood Pharmacy")
			ev["context"]["poi_name"] = pharm_name
			ev["title"] = "Pharmacist Evacuating %s" % pharm_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "A polite tap sounds on the speaking tube. A parched pharmacist carrying a red-cross satchel rescued from %s offers sealed medical supplies if we can spare drinking water or local road directions out of %s." % [pharm_name, hood]
			ev["options"] = [
				_opt("give_water", "Give 2/4 Clean Water for Medicine", "water", GameState.water_quarters >= 2),
				_opt("use_map", "Show Safe Detour on Our Map", "map", GameState.has_working_item("map")),
				_opt("decline", "Wish Them Luck & Keep Sealed", "", true)
			]

		"osm_neighbor_bunker_tap":
			var neigh_name: String = _find_poi_name(["neighbor", "house", "residence", "residential", "apartments"], "the Neighboring Basement Down the Street")
			ev["context"]["poi_name"] = neigh_name
			ev["title"] = "Pipe Tapping from %s!" % neigh_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "TING-TING-TING... TING! Metallic Morse code rings along the municipal cast-iron water line connecting %s to %s! Another family survived on our block and is trying to communicate!" % [house_addr, neigh_name]
			ev["options"] = [
				_opt("use_book", "Decode Morse with Boy Scout Handbook", "book", GameState.has_working_item("book")),
				_opt("use_harmonica", "Play a Cheerful Duet Down the Pipe", "harmonica", GameState.has_working_item("harmonica")),
				_opt("tap_hello", "Tap Back a Friendly Rhythm with a Spoon", "", true),
				_opt("ignore", "Stay Silent — Could Be Looters", "", true)
			]

		"osm_hardware_looters":
			var hw_name: String = _find_poi_name(["hardware", "tool", "supply", "fuel", "76", "auto"], "Local Hardware & Supply")
			ev["context"]["poi_name"] = hw_name
			ev["title"] = "Dropped Loot Sack from %s!" % hw_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "Two arguing scavengers sprinting past %s trip over your garden hose, dropping a heavy canvas sack stenciled %s right beside your hatch! They're circling back for it!" % [house_addr, hw_name]
			ev["options"] = [
				_opt("use_rifle", "Rack Rifle at Viewport to Scare Them Off!", "rifle", GameState.has_working_item("rifle")),
				_opt("use_dog", "Have Pancake Bark Ferociously!", "dog", GameState.has_dog_pancake),
				_opt("snatch_fast", "Snatch the Sack Before They Turn Around!", "", true),
				_opt("ignore", "Let Them Take It & Move Along", "", true)
			]

		"osm_restaurant_aroma":
			var rest_name: String = _find_poi_name(["restaurant", "cafe", "pub", "bar", "pho", "grill", "diner"], "Corner Diner")
			ev["context"]["poi_name"] = rest_name
			ev["title"] = "Tantalizing Broth Scent from %s!" % rest_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "Torture! Somebody camping inside the ruins of %s lit a Sterno stove, and the heavenly aroma of hot spiced broth wafts straight down our air pipe! %s starts licking the wallpaper in sheer culinary nostalgia." % [rest_name, m_name]
			ev["options"] = [
				_opt("cook_soup", "Heat a Deluxe 2/4 Soup Feast Together", "soup", GameState.soup_quarters >= 2),
				_opt("use_cards", "Distract Everyone with High-Stakes Poker", "cards", GameState.has_working_item("cards")),
				_opt("endure", "Sniff Deeply & Pretend Cold Water Is Pho", "", true)
			]

		"osm_school_civil_defense_cache":
			var sch_name: String = _find_poi_name(["school", "library", "college", "academy", "civic"], "District Elementary Civil Defense Post")
			ev["context"]["poi_name"] = sch_name
			ev["title"] = "Civil Defense Blueprint from %s" % sch_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "Wind plasters a laminated 1956 CONELRAD auxiliary water-main chart stamped %s right across our periscope lens! It marks a pressurized emergency fire-cistern valve right beneath our curb on %s!" % [sch_name, house_addr]
			ev["options"] = [
				_opt("use_map", "Cross-Reference Valve on Our Map", "map", GameState.has_working_item("map")),
				_opt("use_toolbox", "Tap Curb Cistern Valve with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("ignore", "Leave the Street Valve Untouched", "", true)
			]

		"osm_park_mutant_geese":
			var park_name: String = _find_poi_name(["park", "garden", "green", "square", "common"], "Municipal Park")
			ev["context"]["poi_name"] = park_name
			ev["title"] = "Three-Eyed Geese from %s on Our Vent!" % park_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "HONK! HONK! A squadron of belligerent, slightly luminescent Canada geese displaced from %s has nested directly atop our warm air-intake pipe, cutting oxygen flow and honking like foghorns!" % park_name
			ev["options"] = [
				_opt("use_harmonica", "Honk Back in B-Flat on Harmonica!", "harmonica", GameState.has_working_item("harmonica")),
				_opt("use_rifle", "Scare Flock (or Bag Dinner!) with Rifle", "rifle", GameState.has_working_item("rifle")),
				_opt("use_axe", "Clang Pipe Loudly with Axe Flat", "axe", GameState.has_working_item("axe")),
				_opt("wait_geese", "Wheeze Patiently Until Migration", "", true)
			]

		"osm_civic_siren_malfunction":
			var civ_name: String = _find_poi_name(["civic", "station", "transit", "stop", "fire", "post"], "Neighborhood Transit Plaza")
			ev["context"]["poi_name"] = civ_name
			ev["title"] = "Short-Circuited Air-Raid Siren Near %s!" % civ_name
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "WEEEE-OOOOO-WEEEE! A damaged Civil Defense siren tower over by %s has shorted onto solar trickle-charge, wailing non-stop across %s for fourteen hours straight! %s's left eye is twitching." % [civ_name, hood, m_name]
			ev["options"] = [
				_opt("use_radio", "Counter-Blast Smooth Big-Band Static", "radio", GameState.has_working_item("radio")),
				_opt("use_checkers", "Focus Intensely on Checkers Strategy", "checkers", GameState.has_working_item("checkers")),
				_opt("stuff_ears", "Stuff Cotton & Endure the Wailing", "", true)
			]

		"osm_street_delivery_van":
			ev["title"] = "Overturned Spring-Water Van on %s!" % house_addr
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "As dust swirls clear outside %s, the periscope reveals a 1950s 'Cascade Pure Spring Water' delivery step-van wedged against a lamppost thirty feet from your hatch, rear doors swinging open!" % house_addr
			ev["options"] = [
				_opt("use_gas_mask", "Haul Crates Safely in Gas Mask!", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_suitcase", "Pack Extra Bottles in Leather Suitcase!", "suitcase", GameState.has_working_item("suitcase")),
				_opt("ignore", "Stay Inside — Street Looks Sketchy", "", true)
			]

		"osm_firefighter_check":
			ev["title"] = "Civil Defense Warden Chalk-Mark Patrol"
			ev["category"] = "osm_neighborhood"
			ev["type"] = "item_choice"
			ev["description"] = "Boots crunch past %s! A lone volunteer Civil Defense warden making rounds through %s kneels with yellow chalk to mark houses as 'ABANDONED' or 'OCCUPIED — DROP RATIONS.'" % [house_addr, hood]
			ev["options"] = [
				_opt("use_flashlight", "Signal 'ALIVE' Through Periscope Lens!", "flashlight", GameState.has_working_item("flashlight")),
				_opt("use_radio", "Hail Warden Walkie-Talkie Band", "radio", GameState.has_working_item("radio")),
				_opt("bang_hatch", "Thump Twice on the Steel Hatch!", "", true),
				_opt("stay_silent", "Let Them Chalk 'Abandoned' & Move On", "", true)
			]

		# ----------------------------------------------------------------------
		# 38-60. ICONIC REATOMIZED QUIRKY, COMPANION & SURVIVAL EVENTS
		# ----------------------------------------------------------------------
		"classic_radioactive_spider":
			ev["title"] = "Dinner-Plate Spider Over the Soup Shelf!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "An eight-legged emerald arachnid wearing what looks suspiciously like a tiny frown lowers itself on glowing silk directly in front of %s's nose! Does biting it give superpowers, or just hives?" % m_name
			ev["options"] = [
				_opt("use_bug_spray", "Hose It Down with Bug Spray!", "bug_spray", GameState.has_working_item("bug_spray")),
				_opt("use_book", "THWACK! Boy Scout Handbook Justice!", "book", GameState.has_working_item("book")),
				_opt("use_cat", "Point Sharikov at the Intruder!", "cat", GameState.has_cat_sharikov),
				_opt("poke_spider", "Let %s Poke It for Science!" % m_name, "", true),
				_opt("ignore", "Name Him 'Boris' & Cede That Corner", "", true)
			]

		"classic_pancake_treasure":
			ev["title"] = "Hollow Clink Beneath the Bunker Floorslab!"
			ev["category"] = "companion"
			ev["type"] = "item_choice"
			if GameState.has_dog_pancake:
				ev["description"] = "WOOF! Pancake has been digging furiously at a loose mortar seam behind the water heater, tail spinning like a propeller! Something metallic is wedged in a pre-war builder's cache!"
			else:
				ev["description"] = "While pacing the shelter floor, %s's heel hits a hollow-sounding concrete tile behind the water heater! Something metallic glints inside a 1952 contractor's stash!" % m_name
			ev["options"] = [
				_opt("use_toolbox", "Pry Tile Cleanly with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_axe", "Pop the Mortar Seam with Axe", "axe", GameState.has_working_item("axe")),
				_opt("dig_hands", "Dig It Out with Bare Hands!", "", true)
			]

		"classic_sharikov_mice":
			ev["title"] = "Bold Field Mice Raiding the Pantry!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "SQUEAK-SCRATCH! Two brazen fallout mice have chewed into the ration crate corner and are eyeing our soup labels like fine literature!"
			ev["options"] = [
				_opt("use_cat", "Deploy Officer Sharikov Immediately!", "cat", GameState.has_cat_sharikov),
				_opt("use_bug_spray", "Repel Pests with Bug Spray Perimeter", "bug_spray", GameState.has_working_item("bug_spray")),
				_opt("guard_night", "Have %s Guard Rations All Night" % m_name, "", true),
				_opt("ignore", "Ignore the Tiny Squeaking Bandits", "", true)
			]

		"classic_leaky_water_jug":
			ev["title"] = "Hairline Split in a Water Bottle!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "PLIP... PLIP... PLIP. Disaster in slow motion! One of our precious Civil Defense water containers has developed a seam crack and is pooling clean water onto the dusty floor!"
			ev["options"] = [
				_opt("use_toolbox", "Clamp & Seal Seam with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("drink_fast", "Chug the Leaking Water Immediately!", "", true),
				_opt("ignore", "Cup Hands & Hope It Stops", "", true)
			]

		"classic_suspicious_soup_can":
			ev["title"] = "The Unlabeled Bulging Tin Can of Mystery"
			ev["category"] = "quirky"
			ev["type"] = "yes_no"
			ev["description"] = "Rolling out from under the bunk is a dusty, label-free tin can stamped 'LOT #1953-X' with a slightly domed lid. Could be peaches in heavy syrup... could be experimental Civil Defense potted mystery meat. Crack it open?"
			ev["options"] = [
				_opt("yes", "Pop the Lid — Fortune Favors the Hungry!", "", true),
				_opt("no", "Toss It Out the Disposal Chute!", "", true)
			]

		"classic_cabin_fever_checkers":
			ev["title"] = "Grand Underground Championship Night"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Time moves like cold molasses underground. Everyone has counted all 412 cinderblocks twice, and %s is starting to hold philosophical debates with a soup spoon. We need entertainment!" % m_name
			ev["options"] = [
				_opt("use_checkers", "Host the Bunker Checkers Open!", "checkers", GameState.has_working_item("checkers")),
				_opt("use_cards", "Run a Championship Card Night!", "cards", GameState.has_working_item("cards")),
				_opt("use_harmonica", "Put On a Talent Show with Harmonica!", "harmonica", GameState.has_working_item("harmonica")),
				_opt("stare_wall", "Count the Cinderblocks a Third Time", "", true)
			]

		"classic_boy_scout_quiz":
			ev["title"] = "The Great Civil Defense Trivia Wager"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "%s bets everyone that official 1955 Civil Defense doctrine recommends rubbing raw potato on a Geiger counter to recalibrate it. Tempers flare over scientific accuracy!" % m_name
			ev["options"] = [
				_opt("use_book", "Fact-Check in the Boy Scout Handbook!", "book", GameState.has_working_item("book")),
				_opt("use_radio", "Listen for a Science Bulletin on Radio", "radio", GameState.has_working_item("radio")),
				_opt("nod_smile", "Smile Politely & Change the Subject", "", true)
			]

		"classic_periscope_smudge":
			ev["title"] = "Periscope Blinded by Caked Fallout Soot"
			ev["category"] = "exploration"
			ev["type"] = "item_choice"
			ev["description"] = "Peering through the periscope reveals nothing whatsoever—just a solid wall of sticky gray ash caked across the exterior prism above %s! Without visibility, raiders or supply drops could pass unseen." % house_addr
			ev["options"] = [
				_opt("use_gas_mask", "Pop Hatch in Gas Mask & Polish Lens", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_water", "Squirt 1/4 Water Through Washer Tube", "water", GameState.water_quarters >= 1),
				_opt("leave_blind", "Fly Blind & Save Our Supplies", "", true)
			]

		"classic_strange_fungus":
			ev["title"] = "Bioluminescent Bunker Wall Truffles!"
			ev["category"] = "mutation"
			ev["type"] = "item_choice"
			ev["description"] = "Overnight, a cluster of plump turquoise mushrooms shaped like little atomic clouds has sprouted in the damp corner! %s insists they smell exactly like French onion soup." % m_name
			ev["options"] = [
				_opt("use_book", "Identify Safe Caps with Handbook", "book", GameState.has_working_item("book")),
				_opt("use_bug_spray", "Eliminate Spores with Bug Spray", "bug_spray", GameState.has_working_item("bug_spray")),
				_opt("taste_raw", "Harvest & Sample a Bold Bite!", "", true),
				_opt("scrape_boot", "Scrape Them Off with a Boot Heel", "", true)
			]

		"classic_voices_in_pipes":
			ev["title"] = "1929 Stock Tips in the Radiator Pipe"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "%s has had their ear pressed against the cold copper plumbing for two hours, whispering back and insisting the water heater is offering hot Wall Street tips on zeppelin futures." % m_name
			ev["options"] = [
				_opt("use_medkit", "Give %s Aspirin & Rest from Medkit" % m_name, "medkit", GameState.has_working_item("medkit")),
				_opt("use_cards", "Coax %s Into a Grounding Card Game" % m_name, "cards", GameState.has_working_item("cards")),
				_opt("play_along", "Ask the Pipe About Canned Soup Futures", "", true)
			]

		"classic_ammo_press":
			ev["title"] = "Tarnished Brass & Loose Cartridges"
			ev["category"] = "exploration"
			ev["type"] = "item_choice"
			ev["description"] = "Sweeping beneath the storage rack turns up a handful of dusty brass rifle cartridges—though damp bunker humidity is threatening to corrode our ammunition primers!"
			ev["options"] = [
				_opt("use_toolbox", "Clean & Re-Seat Brass with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_flashlight", "Inspect & Dry Primers Under Lamp", "flashlight", GameState.has_working_item("flashlight")),
				_opt("wipe_shirt", "Rub Them on a Dry Sleeve", "", true)
			]

		"classic_red_phone_ringing":
			ev["title"] = "A Buried Civil Defense Field Phone Rings!"
			ev["category"] = "exploration"
			ev["type"] = "yes_no"
			ev["description"] = "BRRRING! Behind a loose panel stamped 'CD-SECTOR TRUNK LINE,' a dusty olive-drab rotary handset suddenly rings inside your wall! Nobody knew %s was wired to an old Cold War trunk cable. Pick up the receiver?" % house_addr
			ev["options"] = [
				_opt("yes", "Pick Up the Receiver: 'Hello?!'", "", true),
				_opt("no", "Let It Ring — Don't Reveal Our Bunker", "", true)
			]

		"classic_wandering_doctor":
			ev["title"] = "Dr. Stanislaus, Wasteland House-Call Medic"
			ev["category"] = "trader"
			ev["type"] = "item_choice"
			ev["description"] = "Two gentle taps on the hatch: an elderly physician in a singed tweed coat with a leather stethoscope offers to treat any sick or injured family member through the airlock cuff in exchange for a modest ration!"
			ev["options"] = [
				_opt("pay_soup", "Offer 2/4 Soup for Full Medical Care", "soup", GameState.soup_quarters >= 2),
				_opt("pay_water", "Offer 2/4 Water for Full Medical Care", "water", GameState.water_quarters >= 2),
				_opt("decline", "Thank the Doctor & Decline", "", true)
			]

		"classic_raider_extortion_note":
			ev["title"] = "Extortion Note from the 'Atomic Greasers'!"
			ev["category"] = "raiders"
			ev["type"] = "item_choice"
			ev["description"] = "THWACK! A switchblade pins a greased diner napkin to your periscope: 'NICE BUNKER AT %s! LEAVE 1 CAN OF SOUP OUTSIDE OR WE SLEDGEHAMMER YOUR VENT! — THE ATOMIC GREASERS.'" % house_addr.to_upper()
			ev["options"] = [
				_opt("use_rifle", "Poke Rifle Barrel Out the Chute!", "rifle", GameState.has_working_item("rifle")),
				_opt("use_axe", "Split Their Switchblade with Our Axe!", "axe", GameState.has_working_item("axe")),
				_opt("pay_tribute", "Leave 1 Can of Soup (4/4) to Keep Peace", "soup", GameState.soup_quarters >= 4),
				_opt("refuse", "Crumple the Note & Call Their Bluff", "", true)
			]

		"classic_suitcase_false_bottom":
			ev["title"] = "Hollow Lining in the Shelter Footlocker!"
			ev["category"] = "exploration"
			ev["type"] = "item_choice"
			ev["description"] = "While rearranging rations, %s notices the Civil Defense storage trunk is three inches shallower inside than outside—a classic pre-war smuggling false bottom!" % m_name
			ev["options"] = [
				_opt("use_toolbox", "Unscrew Brass Hinges with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_axe", "Crack the False Panel with Axe", "axe", GameState.has_working_item("axe")),
				_opt("pry_spoon", "Work the Seam Open with a Soup Spoon", "", true)
			]

		"classic_mutant_night_vision":
			var mut_m: Dictionary = _get_mutant_member()
			ev["context"]["has_mutant"] = not mut_m.is_empty()
			ev["context"]["mutant_name"] = str(mut_m.get("name", ""))
			if not mut_m.is_empty():
				var mn: String = str(mut_m.get("name", "Mutant"))
				ev["title"] = "%s's Atomic Night-Vision Perk!" % mn
				ev["category"] = "mutation"
				ev["type"] = "item_choice"
				ev["description"] = "At midnight, %s's faintly glowing eyes spot a hidden recessed Civil Defense cubby high behind the air duct that normal human eyes completely missed!" % mn
				ev["options"] = [
					_opt("mutant_reach", "Let %s Reach Into the High Cubby!" % mn, "", true),
					_opt("ignore", "Let Everyone Sleep Instead", "", true)
				]
			else:
				ev["title"] = "Eerie Scratching Behind the Cinderblocks"
				ev["category"] = "quirky"
				ev["type"] = "item_choice"
				ev["description"] = "SCRITCH... SCRITCH. Something behind the north concrete wall is tapping out 'Yankee Doodle' at two in the morning. Nerves in the bunker are stretched drum-tight!"
				ev["options"] = [
					_opt("use_flashlight", "Sweep Wall Cracks with Flashlight", "flashlight", GameState.has_working_item("flashlight")),
					_opt("use_harmonica", "Play the Second Verse Back on Harmonica", "harmonica", GameState.has_working_item("harmonica")),
					_opt("pull_covers", "Pull Blankets Over Heads", "", true)
				]

		"classic_condensation_still":
			ev["title"] = "Cold Steel I-Beam Condensation Drip"
			ev["category"] = "exploration"
			ev["type"] = "item_choice"
			ev["description"] = "Cool subsoil around %s is condensing clean moisture beads all along the overhead structural steel beam! With a clever rig, we could harvest drinking water." % house_addr
			ev["options"] = [
				_opt("use_toolbox", "Bend Tin Gutter Funnel with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_gas_mask", "Filter Drip Through Gas Mask Canister", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("catch_cup", "Balance a Tin Cup Underneath", "", true)
			]

		"classic_board_game_feud":
			ev["title"] = "Mystery of the Missing Red King Piece!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Scandal in the shelter! Somebody lost a game piece under the heavy iron bunk frame, and %s is conducting a full courtroom cross-examination of every suspect." % m_name
			ev["options"] = [
				_opt("use_flashlight", "Shine Flashlight Under the Bunk Frame", "flashlight", GameState.has_working_item("flashlight")),
				_opt("use_cards", "Declare Mistrial & Deal Playing Cards", "cards", GameState.has_working_item("cards")),
				_opt("crawling_search", "Crawl Around Groping in the Dust", "", true)
			]

		"classic_civil_defense_drop":
			ev["title"] = "CONELRAD Parachute Crate Snagged Overhead!"
			ev["category"] = "exploration"
			ev["type"] = "item_choice"
			ev["description"] = "WHUMP! A bright yellow Civil Defense cargo parachute drifted off course over %s and snagged its shroud lines right onto the shattered porch railing of %s!" % [hood, house_addr]
			ev["options"] = [
				_opt("use_axe", "Slash Parachute Lines Fast with Axe!", "axe", GameState.has_working_item("axe")),
				_opt("use_gas_mask", "Unclip Cargo Canister in Gas Mask!", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("tug_lines", "Yank Shroud Lines from Inside Hatch", "", true),
				_opt("leave_drop", "Leave It — Could Attract Raiders", "", true)
			]

		"classic_bad_dream_choir":
			ev["title"] = "Nightmare of the Giant Atomic Toasters!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "%s bolts upright at midnight shouting that 50-foot chrome 1950s pop-up toasters are marching down %s! Now nobody in the bunker can fall back asleep." % [m_name, house_addr]
			ev["options"] = [
				_opt("use_harmonica", "Play a Gentle Lullaby on Harmonica", "harmonica", GameState.has_working_item("harmonica")),
				_opt("use_radio", "Tune Soft Late-Night Crooner Static", "radio", GameState.has_working_item("radio")),
				_opt("tell_story", "Tell Cozy Pre-War Bedtime Stories", "", true)
			]

		"classic_salesman_vault_insurance":
			ev["title"] = "Door-to-Door Megaton Insurance Salesman?!"
			ev["category"] = "quirky"
			ev["type"] = "item_choice"
			ev["description"] = "Unbelievable! A cheery fellow in a singed plaid suit and bowler hat tips his brim at your periscope: 'Good day, %s homeowner! For a mere snack, Mutual of Bikini Atoll includes a FREE promotional survival gift!'" % house_addr
			ev["options"] = [
				_opt("buy_soup", "Sign Policy for 2/4 Soup (Get Free Gift!)", "soup", GameState.soup_quarters >= 2),
				_opt("listen_pitch", "Endure His 45-Minute Sales Pitch for Sample", "", true),
				_opt("slam_shutter", "Close the Periscope Shutter Politely", "", true)
			]

		"classic_splinter_first_aid":
			ev["title"] = "Jagged Steel Burr on the Hatch Ladder!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "OUCH! Climbing down from checking the hatch seal, %s catches their shin on a rusted, razor-sharp steel rivet protruding from the ladder rung!" % m_name
			ev["options"] = [
				_opt("use_medkit", "Disinfect & Bandage with Medkit", "medkit", GameState.has_working_item("medkit")),
				_opt("use_toolbox", "File the Jagged Rivet Flat with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("walk_off", "Grit Teeth & Rub Some Dirt Off", "", true)
			]

		"classic_radio_quiz_show":
			ev["title"] = "Pirate Broadcast: 'DJ Atomic Al's Quiz Hour!'"
			ev["category"] = "quirky"
			ev["type"] = "item_choice"
			ev["description"] = "Broadcasting from a lead-lined bowling alley somewhere outside %s, pirate disc jockey 'Atomic Al' spins rockabilly 45s and announces clues to an unlooted Civil Defense stash nearby!" % hood
			ev["options"] = [
				_opt("use_radio", "Fine-Tune Radio & Copy Stash Clues!", "radio", GameState.has_working_item("radio")),
				_opt("use_map", "Plot Al's Landmarks on Our Map!", "map", GameState.has_working_item("map")),
				_opt("tap_toes", "Snap Fingers & Hum Along to the Beat", "", true)
			]

		# ----------------------------------------------------------------------
		# 61-63. V2 PILLAR 1: WASTELAND SMUGGLER CONVOY ESCAPE CHAIN (0 -> 1 -> 2 -> 3)
		# ----------------------------------------------------------------------
		"rescue_raider_pact_1":
			ev["title"] = "Diesel Air-Horns & CB Channel 19 Truce Hail!"
			ev["category"] = "rescue_raider_pact"
			ev["type"] = "item_choice"
			ev["description"] = "BWAAAH-BWAAAH! Heavy twin-stack diesel air-horns thunder down the highway corridor past %s! Over emergency CB frequencies and flare smoke outside %s, the 'Chrome Caravaneers' — a fiercely independent Wasteland Smuggler Convoy — broadcast an open truce hail to any surviving households willing to deal fairly." % [hood, house_addr]
			ev["options"] = [
				_opt("use_radio", "Answer Convoy Captain on CB Band (Radio)", "radio", GameState.has_working_item("radio")),
				_opt("give_ammo", "Slide 2 Brass Cartridges as Convoy Toll", "ammo", GameState.ammo_count >= 2),
				_opt("give_soup", "Offer 1 Can of Hot Soup to Outrider", "soup", GameState.soup_quarters >= 4),
				_opt("use_harmonica", "Play Roadhouse Truce Blues on Harmonica", "harmonica", GameState.has_working_item("harmonica")),
				_opt("flash_mirror", "Blink Periscope Mirror in Truce Pattern", "", true),
				_opt("ignore", "Keep Hatch Dogged — Trust No Convoy", "", true)
			]

		"rescue_raider_pact_2":
			ev["title"] = "Smuggler Convoy Mechanic at the Curb!"
			ev["category"] = "rescue_raider_pact"
			ev["type"] = "item_choice"
			ev["description"] = "HISS-CLANK! A soot-streaked outrider motorcycle and armored tow-wrecker idle in the alley beside %s! Chief mechanic 'Grease-Gun Greta' raps code on your speaking tube: their lead semi-rig blew a turbo hose and took shrapnel breaking a warlord roadblock near %s. Help patch their crew or engine, and your whole family earns sleeper-cab seats out of the fallout zone!" % [house_addr, hood]
			ev["options"] = [
				_opt("give_fuel", "Pass Up 1 Gasoline Jerrycan", "fuel", GameState.has_working_item("fuel")),
				_opt("use_scrap", "Hand Over Salvaged Scrap & Hose Clamps", "scrap", GameState.has_working_item("scrap")),
				_opt("use_antibiotics", "Treat Wounded Driver with Antibiotics", "antibiotics", GameState.has_working_item("antibiotics")),
				_opt("use_medkit", "Bandage Shrapnel Burns with Medkit", "medkit", GameState.has_working_item("medkit")),
				_opt("use_toolbox", "Loan Precision Socket Set (Toolbox)", "toolbox", GameState.has_working_item("toolbox")),
				_opt("push_rig", "Send %s Out to Crank & Push the Wrecker" % m_name, "", true),
				_opt("ignore", "Stay Below — Too Risky on the Curb", "", true)
			]

		"rescue_raider_pact_3":
			ev["title"] = "Armored 18-Wheeler War-Rig Idling Outside!"
			ev["category"] = "rescue_raider_pact"
			ev["type"] = "yes_no"
			ev["description"] = "HONK-HONK! Twin chrome smokestacks belch black diesel exhaust right in front of %s! Plated in welded highway signs and a V-blade snowplow, the Smuggler Convoy's flagship semi-rig idles across the street while Grease-Gun Greta kicks open the armored sleeper door: 'A PACT IS A PACT, BUNKER FOLKS! WE'RE PUNCHING OUT OF %s TO CLEAR COASTAL HIGHWAY — CLIMB ABOARD NOW!'" % [house_addr, hood.to_upper()]
			ev["options"] = [
				_opt("yes", "Board the Armored Smuggler Convoy!", "", true),
				_opt("no", "Wave Them Off — Stay in Our Shelter", "", true)
			]

		# ----------------------------------------------------------------------
		# 64-68. V2 PILLAR 2: STATION WAGON GARAGE & VEHICLE ESCAPE EVENTS
		# ----------------------------------------------------------------------
		"vehicle_garage_discovery":
			var owned_parts: int = GameState.get_vehicle_parts_owned_count()
			ev["title"] = "Tarp-Covered 1957 Country Squire in the Carport!"
			ev["category"] = "vehicle"
			ev["type"] = "item_choice"
			ev["description"] = "Peering through the side foundation grate of %s, %s spots the wood-grain tailfins of a 1957 Country Squire Station Wagon under collapsed garage rafters (Engine Parts ready: %d/4)! Popping its jammed hood could yield a vital missing engine component!" % [house_addr, m_name, owned_parts]
			ev["options"] = [
				_opt("use_toolbox", "Unbolt Pristine Engine Part with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_flashlight", "Search Engine Bay & Trunk with Flashlight", "flashlight", GameState.has_working_item("flashlight")),
				_opt("cooperate_pry", "[COOPERATE] Heave Buckled Garage Beam Together", "", _has_cooperating_pair(45)),
				_opt("crawl_under", "Wriggle Under the Chassis by Hand", "", true)
			]

		"vehicle_siphon_derelict":
			ev["title"] = "Abandoned Municipal Sedan on the Curb!"
			ev["category"] = "vehicle"
			ev["type"] = "item_choice"
			ev["description"] = "A stalled 1956 Civil Defense staff sedan sits wedged against a parking meter outside %s (Fuel Cans banked: %d/%d)! Its rear tank still sloshes with leaded high-octane gasoline if we can siphon it cleanly." % [house_addr, GameState.fuel_cans, GameState.fuel_needed]
			ev["options"] = [
				_opt("use_gas_mask", "Siphon Tank Fume-Free in Gas Mask", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_axe", "Pop Locking Gas Cap with Fireman's Axe", "axe", GameState.has_working_item("axe")),
				_opt("mouth_siphon", "Have %s Siphon Fast with Garden Hose!" % m_name, "", true),
				_opt("ignore", "Leave the Derelict Sedan Alone", "", true)
			]

		"vehicle_engine_tuneup":
			var handy_v: Dictionary = _get_member_with_trait("handy")
			var handy_v_name: String = str(handy_v.get("name", ""))
			ev["context"]["handy_name"] = handy_v_name
			ev["title"] = "Station Wagon V8 Carburetor & Timing Tune-Up"
			ev["category"] = "vehicle"
			ev["type"] = "item_choice"
			ev["description"] = "Before our escape Station Wagon can roar through fallout drifts across %s without stalling, its four-barrel carburetor, distributor points, and manifold gaskets need a proper mechanical tune-up!" % hood
			var tune_opts: Array = [
				_opt("use_toolbox", "Gap Points & Time Ignition with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_scrap", "Stamp Fresh Manifold Gaskets from Scrap", "scrap", GameState.has_working_item("scrap")),
				_opt("use_book", "Follow Illustrated Shop Diagram in Book", "book", GameState.has_working_item("book"))
			]
			if not handy_v.is_empty():
				tune_opts.append(_opt("use_handy", "Let Handy %s Tune the V8 by Ear!" % handy_v_name, "", true))
			tune_opts.append(_opt("cooperate_tune", "[COOPERATE] Two-Person Pedal & Timing Calibration", "", _has_cooperating_pair(45)))
			tune_opts.append(_opt("eyeball_it", "Twist the Idle Screws & Pray", "", true))
			ev["options"] = tune_opts

		"vehicle_armored_bumper":
			ev["title"] = "Nomad Pit-Mechanic & Ram-Bumper Fabrication"
			ev["category"] = "vehicle"
			ev["type"] = "item_choice"
			ev["description"] = "A goggled Nomad Mechanic pulling a salvage cart pauses beside %s! She offers a tested Alternator or Spark Plugs set in trade for surplus Soup or Rifle Ammo—or we can weld our own Scrap onto the chassis and shelter hatch!" % house_addr
			ev["options"] = [
				_opt("trade_soup_part", "Trade 1 Soup Can (4/4) for Missing Engine Part", "soup", GameState.soup_quarters >= 4),
				_opt("trade_ammo_part", "Trade 2 Rifle Ammo for Missing Engine Part", "ammo", GameState.ammo_count >= 2),
				_opt("weld_scrap", "Weld Scrap into Ram-Bumper & Hatch Brace", "scrap", GameState.has_working_item("scrap")),
				_opt("use_toolbox", "Swap Shop Secrets & Tune Frame (Toolbox)", "toolbox", GameState.has_working_item("toolbox")),
				_opt("decline", "Wish the Nomad Mechanic Safe Roads", "", true)
			]

		"vehicle_nomad_parts_swap":
			ev["title"] = "Sparkplug Sal's Tow-Rig Salvage Swap"
			ev["category"] = "vehicle"
			ev["type"] = "item_choice"
			ev["description"] = "Tire chains clank across %s as old tow-operator 'Sparkplug Sal' hauls crates of pre-war Detroit auto parts past %s! Parched from the highway, he'll swap a rebuilt Engine Part or Gasoline Jerrycan for water, medical gear, or cards!" % [hood, house_addr]
			ev["options"] = [
				_opt("swap_water", "Trade 1 Water Bottle (4/4) for Engine Part", "water", GameState.water_quarters >= 4),
				_opt("swap_medkit", "Trade 1 Medkit for Engine Part + Fuel", "medkit", GameState.has_working_item("medkit")),
				_opt("swap_cards", "Trade Playing Cards for 1 Fuel Jerrycan", "cards", GameState.has_working_item("cards")),
				_opt("decline", "Pass on Sal's Auto Parts Today", "", true)
			]

		# ----------------------------------------------------------------------
		# 69-81. V2 PILLAR 3: DEEP FAMILY RELATIONSHIPS, GUILT & [COOPERATE]
		# ----------------------------------------------------------------------
		"family_haunted_unrescued":
			var lost_kin: String = _get_left_behind_name(active_rng)
			var leader_m: Dictionary = _get_leader_or_first_member(active_rng)
			var leader_name: String = str(leader_m.get("name", m_name))
			var leader_id: String = str(leader_m.get("id", m_id))
			ev["context"]["lost_name"] = lost_kin
			ev["context"]["leader_id"] = leader_id
			ev["context"]["leader_name"] = leader_name
			ev["title"] = "Haunted by the Unrescued: %s's Keepsake" % lost_kin
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Silence falls heavy beneath %s. Shaking dust from a spare blanket, %s uncovers a singed pocket keepsake belonging to %s — who was left behind above ground when the blast hatch slammed shut. Wet eyes turn toward %s in unspoken grief." % [house_addr, m_name, lost_kin, leader_name]
			ev["options"] = [
				_opt("leader_apologize", "Have %s Apologize Openly & Grieve Together" % leader_name, "", true),
				_opt("use_harmonica", "Play a Quiet Memorial Hymn on Harmonica", "harmonica", GameState.has_working_item("harmonica")),
				_opt("suppress_talk", "Forbid Mentioning %s — Focus Only on Survival" % lost_kin, "", true)
			]

		"family_phantom_knock_guilt":
			var lost_kin2: String = _get_left_behind_name(active_rng)
			ev["context"]["lost_name"] = lost_kin2
			ev["title"] = "Phantom Voice in the Vent Pipe"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "At 3:00 AM, fallout wind moaning across the porch of %s sounds heartbreakingly like %s calling to be let inside! Sleep-deprived %s stumbles toward the hatch wheel with trembling hands!" % [house_addr, lost_kin2, m_name]
			ev["options"] = [
				_opt("cooperate_hold", "[COOPERATE] Embrace %s & Gently Talk Them Down" % m_name, "", _has_cooperating_pair(45)),
				_opt("use_radio", "Verify Porch via Periscope & Play Soft Radio", "radio", GameState.has_working_item("radio")),
				_opt("harsh_order", "Bark Orders & Pull %s Roughly from the Ladder" % m_name, "", true)
			]

		"family_ration_accusation":
			var pair_ra: Array = _pick_member_pair(active_rng, true, false)
			var ma_ra: Dictionary = pair_ra[0]
			var mb_ra: Dictionary = pair_ra[1]
			var na_ra: String = str(ma_ra.get("name", "Ted"))
			var nb_ra: String = str(mb_ra.get("name", "Dolores"))
			ev["context"]["pair_a_id"] = str(ma_ra.get("id", ""))
			ev["context"]["pair_b_id"] = str(mb_ra.get("id", ""))
			ev["context"]["pair_a_name"] = na_ra
			ev["context"]["pair_b_name"] = nb_ra
			ev["title"] = "The Midnight Soup-Spoon Accusation!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Tempers flare by the pantry shelf! %s points an accusing finger, swearing %s licked an extra spoonful of Tomato Soup while everyone's backs were turned! Resentment threatens to fracture the shelter." % [na_ra, nb_ra]
			ev["options"] = [
				_opt("cooperate_audit", "[COOPERATE] Calmly Verify Chalk Ration Marks Together", "", _has_cooperating_pair(45)),
				_opt("share_extra", "Pour a Fair 1/4 Soup Peace-Offering", "soup", GameState.soup_quarters >= 1),
				_opt("use_book", "Post Official Civil Defense Ration Charter (Book)", "book", GameState.has_working_item("book")),
				_opt("take_sides", "Scold Both Loudly & Lock the Shelf", "", true)
			]

		"family_generation_clash":
			var pair_gc: Array = _pick_member_pair(active_rng, true, false)
			var ma_gc: Dictionary = pair_gc[0]
			var mb_gc: Dictionary = pair_gc[1]
			var na_gc: String = str(ma_gc.get("name", "Ted"))
			var nb_gc: String = str(mb_gc.get("name", "Mary Jane"))
			ev["context"]["pair_a_id"] = str(ma_gc.get("id", ""))
			ev["context"]["pair_b_id"] = str(mb_gc.get("id", ""))
			ev["context"]["pair_a_name"] = na_gc
			ev["context"]["pair_b_name"] = nb_gc
			ev["title"] = "Bunker Curfew & Generation Clash!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Four concrete walls make tiny habits feel colossal! %s lectures %s nonstop about slouching, whistling off-key, and leaving dusty boots in the aisle until neither will look at the other!" % [na_gc, nb_gc]
			ev["options"] = [
				_opt("use_checkers", "Settle Household Honor Over Checkers", "checkers", GameState.has_working_item("checkers")),
				_opt("use_cards", "Pair Them as Partners in Rummy (Cards)", "cards", GameState.has_working_item("cards")),
				_opt("cooperate_mediate", "[COOPERATE] Mediate a Fair Bunker Chore Pact", "", _has_cooperating_pair(45)),
				_opt("let_bicker", "Let Them Argue Until Their Voices Give Out", "", true)
			]

		"family_midnight_card_tournament":
			ev["title"] = "Candlelight Stories & Midnight Bonding"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "While fallout wind rattles the gutters above %s, nobody feels sleepy. Gathered around an upturned ration crate, everyone starts reminiscing about Sunday afternoons in %s before the sirens." % [house_addr, hood]
			ev["options"] = [
				_opt("use_cards", "Host the Midnight Bunker Card Championship!", "cards", GameState.has_working_item("cards")),
				_opt("use_harmonica", "Play Warm Campfire Blues on Harmonica", "harmonica", GameState.has_working_item("harmonica")),
				_opt("toast_water", "Toast Survival with 1/4 Clean Water", "water", GameState.water_quarters >= 1),
				_opt("swap_tales", "Share Favorite Neighborhood Memories", "", true)
			]

		"family_shared_coat_freeze":
			var pair_sc: Array = _pick_member_pair(active_rng, false, true)
			var ma_sc: Dictionary = pair_sc[0]
			var mb_sc: Dictionary = pair_sc[1]
			var na_sc: String = str(ma_sc.get("name", "Dolores"))
			var nb_sc: String = str(mb_sc.get("name", "Timmy"))
			ev["context"]["pair_a_id"] = str(ma_sc.get("id", ""))
			ev["context"]["pair_b_id"] = str(mb_sc.get("id", ""))
			ev["context"]["pair_a_name"] = na_sc
			ev["context"]["pair_b_name"] = nb_sc
			ev["title"] = "One Dry Wool Overcoat in the Draft!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "A freezing night draft snakes down the intake pipe (%.1f°C), and only one heavy wool trench coat hangs dry on the peg while both %s and %s are shivering!" % [GameState.bunker_temp_c, na_sc, nb_sc]
			ev["options"] = [
				_opt("cooperate_huddle", "[COOPERATE] Drape Coat Across Both & Share Warmth", "", _has_cooperating_pair(45)),
				_opt("heat_soup", "Simmer 1/4 Piping-Hot Soup for Everyone", "soup", GameState.soup_quarters >= 1),
				_opt("give_coat", "Wrap %s in the Coat & Tough It Out" % na_sc, "", true),
				_opt("tug_of_war", "Quarrel Over Blanket Rights All Night", "", true)
			]

		"family_breakdown_intervention":
			var stressed_m: Dictionary = _pick_most_stressed_member(rand_member)
			var st_name: String = str(stressed_m.get("name", m_name))
			var st_id: String = str(stressed_m.get("id", m_id))
			ev["context"]["member_id"] = st_id
			ev["context"]["member_name"] = st_name
			ev["title"] = "Claustrophobic Breakdown by the Ladder!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Cabin fever hits a dangerous peak! %s sits curled beside the sump grate with hands pressed over their ears, insisting the concrete ceiling beneath %s is lowering half an inch every hour!" % [st_name, house_addr]
			var pet_icon: String = "dog" if GameState.has_dog_pancake else "cat"
			ev["options"] = [
				_opt("cooperate_soothe", "[COOPERATE] Sit Together & Ground %s Calmly" % st_name, "", _has_cooperating_pair(45)),
				_opt("use_medkit", "Give Restorative Tonic & Compress (Medkit)", "medkit", GameState.has_working_item("medkit")),
				_opt("use_pet", "Let Our Loyal Pet Comfort %s" % st_name, pet_icon, GameState.has_dog_pancake or GameState.has_cat_sharikov),
				_opt("snap_out", "Tell %s Sternly to Pull It Together" % st_name, "", true)
			]

		"family_quiet_apology":
			var pair_qa: Array = _pick_member_pair(active_rng, true, false)
			var ma_qa: Dictionary = pair_qa[0]
			var mb_qa: Dictionary = pair_qa[1]
			var na_qa: String = str(ma_qa.get("name", "Ted"))
			var nb_qa: String = str(mb_qa.get("name", "Dolores"))
			ev["context"]["pair_a_id"] = str(ma_qa.get("id", ""))
			ev["context"]["pair_b_id"] = str(mb_qa.get("id", ""))
			ev["context"]["pair_a_name"] = na_qa
			ev["context"]["pair_b_name"] = nb_qa
			ev["title"] = "Quiet Apology Beside the Periscope"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "After days of frayed underground nerves, %s quietly polishes %s's dented tin mug and offers a hesitant apology under the dim lamp. Pride hangs in the balance." % [na_qa, nb_qa]
			ev["options"] = [
				_opt("encourage_truce", "Encourage an Honest Handshake & Fresh Start", "", true),
				_opt("celebrate_soup", "Seal the Peace Over 2/4 Warm Tomato Soup", "soup", GameState.soup_quarters >= 2),
				_opt("reopen_grudge", "Remind Everyone Who Started It First", "", true)
			]

		"family_cooperate_pipe_burst":
			ev["title"] = "High-Pressure Galvanized Pipe Rupture!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "HISSS-CRACK! A corroded overhead pipe coupling splits open beneath %s, spraying icy water toward our bunks! Holding the bucking pipe aligned while tightening the collar really takes two trusted sets of hands!" % house_addr
			ev["options"] = [
				_opt("cooperate_brace", "[COOPERATE] Brace Pipe & Crimp Collar Together (Zero Wear!)", "", _has_cooperating_pair(45)),
				_opt("use_toolbox", "Force Solo Wrench Repair with Toolbox", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_scrap", "Hammer Salvaged Scrap Clamp Over Seam", "scrap", GameState.has_working_item("scrap")),
				_opt("bail_buckets", "Wrap Rags & Bail Spray by Hand", "", true)
			]

		"family_cooperate_hatch_brace":
			ev["title"] = "Shifting Rubble Slamming the Blast Hatch!"
			ev["category"] = "hazard"
			ev["type"] = "item_choice"
			ev["description"] = "BOOM-GROAN! Settling masonry outside %s slides across our steel hatch, popping two interior locking dogs loose! Resetting the heavy pins cleanly takes synchronized teamwork or solid steel wedges!" % house_addr
			ev["options"] = [
				_opt("cooperate_dogs", "[COOPERATE] Shoulder Hatch & Pin Dogs Together!", "", _has_cooperating_pair(45)),
				_opt("use_scrap", "Drive Steel Scrap Wedges Into Latch", "scrap", GameState.has_working_item("scrap")),
				_opt("use_axe", "Lever Hatch Dogs Shut with Axe Handle", "axe", GameState.has_working_item("axe")),
				_opt("solo_strain", "Have %s Brace the Heavy Door Solo" % m_name, "", true)
			]

		"family_secret_diary_feud":
			var pair_sd: Array = _pick_member_pair(active_rng, true, false)
			var ma_sd: Dictionary = pair_sd[0]
			var mb_sd: Dictionary = pair_sd[1]
			var na_sd: String = str(ma_sd.get("name", "Mary Jane"))
			var nb_sd: String = str(mb_sd.get("name", "Ted"))
			ev["context"]["pair_a_id"] = str(ma_sd.get("id", ""))
			ev["context"]["pair_b_id"] = str(mb_sd.get("id", ""))
			ev["context"]["pair_a_name"] = na_sd
			ev["context"]["pair_b_name"] = nb_sd
			ev["title"] = "Scandal: The Secret Bunker Burn-Book!"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Uproar under %s! %s just found %s's secret charcoal notebook grading every family member's snoring decibels and wasteland survival IQ!" % [house_addr, na_sd, nb_sd]
			ev["options"] = [
				_opt("cooperate_chronicle", "[COOPERATE] Co-Write an Official Family Time Capsule", "", _has_cooperating_pair(45)),
				_opt("use_book", "Tuck Notes Safely Into Survival Handbook", "book", GameState.has_working_item("book")),
				_opt("laugh_roast", "Read It Aloud as a Good-Natured Comedy Roast!", "", true),
				_opt("confiscate", "Confiscate the Pages & Lecture Everyone", "", true)
			]

		"family_expedition_jealousy":
			var pair_ej: Array = _pick_member_pair(active_rng, true, false)
			var ma_ej: Dictionary = pair_ej[0]
			var mb_ej: Dictionary = pair_ej[1]
			var na_ej: String = str(ma_ej.get("name", "Ted"))
			var nb_ej: String = str(mb_ej.get("name", "Dolores"))
			ev["context"]["pair_a_id"] = str(ma_ej.get("id", ""))
			ev["context"]["pair_b_id"] = str(mb_ej.get("id", ""))
			ev["context"]["pair_a_name"] = na_ej
			ev["context"]["pair_b_name"] = nb_ej
			ev["title"] = "Who Pulls Their Weight Underground?"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "Sore muscles spark a heated debate! %s grumbles about doing all the heavy maintenance and risky watch shifts around %s while %s supposedly gets off easy!" % [na_ej, house_addr, nb_ej]
			ev["options"] = [
				_opt("cooperate_chores", "[COOPERATE] Team Up Side-by-Side on Sump Duty", "", _has_cooperating_pair(45)),
				_opt("use_checkers", "Winner of Checkers Assigns Tomorrow's Shifts", "checkers", GameState.has_working_item("checkers")),
				_opt("praise_both", "Credit Everyone's Grit Equally", "", true),
				_opt("pick_favorite", "Side Publicly with %s" % na_ej, "", true)
			]

		"family_heirloom_watch_pledge":
			ev["title"] = "The Stopped 1952 Heirloom Wristwatch"
			ev["category"] = "family"
			ev["type"] = "item_choice"
			ev["description"] = "%s holds up a cracked brass wristwatch whose hands froze at the exact minute %s was struck. Passing it around the circle, the household reflects on what keeps a family whole in the dark." % [m_name, nuke_target]
			ev["options"] = [
				_opt("cooperate_oath", "[COOPERATE] Swear the Unbreakable Shelter Loyalty Pact", "", _has_cooperating_pair(45)),
				_opt("use_toolbox", "Clean & Re-Wind the Watch Mainspring (Toolbox)", "toolbox", GameState.has_working_item("toolbox")),
				_opt("hang_watch", "Hang It Proudly Above the Civil Defense Log", "", true)
			]

		# ----------------------------------------------------------------------
		# 82-92. V2 PILLAR 4: REAL-WORLD LANDMARK CONDITIONAL EVENTS
		# ----------------------------------------------------------------------
		"landmark_doctor_triage_ledger":
			var doc_poi: String = _find_poi_name(["doctor", "clinic", "urgent", "hospital", "medical", "health"], "Neighborhood Urgent Care Clinic")
			ev["context"]["poi_name"] = doc_poi
			ev["title"] = "Triage Nurse & Ledger from %s!" % doc_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "Nurse Evelyn, relocating emergency stock from %s across %s, taps code on your speaking tube! She carries a physician's dosage ledger and blister-packs of Prescription Antibiotics—offering a trade or offering to compound our own Antibiotics into a full surgical trauma kit!" % [doc_poi, hood]
			ev["options"] = [
				_opt("trade_soup_abx", "Trade 2/4 Soup for Prescription Antibiotics", "soup", GameState.soup_quarters >= 2),
				_opt("use_antibiotics", "Compound Our Antibiotics Into Full Clinic Cure!", "antibiotics", GameState.has_working_item("antibiotics")),
				_opt("use_book", "Transcribe Dosage Ledger Into Handbook (+Antibiotics)", "book", GameState.has_working_item("book")),
				_opt("decline", "Thank Nurse Evelyn & Keep Hatch Sealed", "", true)
			]

		"landmark_supermarket_cold_storage":
			var groc_poi: String = _find_poi_name(["grocery", "supermarket", "market", "bakery", "qfc", "store"], "Neighborhood Supermarket")
			ev["context"]["poi_name"] = groc_poi
			ev["title"] = "Sub-Basement Cold-Storage Map to %s!" % groc_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "Pinned against your vent grate is a night-manager's delivery chute diagram from %s! An unlooted pallet of canned soup sits just inside its service alley—but rival scavengers in %s are already sniffing around the block!" % [groc_poi, hood]
			ev["options"] = [
				_opt("use_gas_mask", "Slip Through Ash Fog in Gas Mask (+2 Cans Soup!)", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_rifle", "Cover the Haul Against Rivals with Rifle", "rifle", GameState.has_working_item("rifle")),
				_opt("greedy_haul", "Haul Crate Noisily by Hand (May Draw Rivals!)", "", true),
				_opt("burn_map", "Pass — Too Many Scavengers Watching", "", true)
			]

		"landmark_pharmacy_iodide_shipment":
			var pharm_poi: String = _find_poi_name(["pharmacy", "drug", "apothecary", "chemist"], "Corner Pharmacy")
			ev["context"]["poi_name"] = pharm_poi
			ev["title"] = "Potassium Iodide Parcel from %s!" % pharm_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "Through the periscope outside %s, you spot a toppled delivery scooter stenciled %s! Wedged inside its lead-lined dispatch box are sealed Civil Defense packs of Potassium Iodide Anti-Rad tablets!" % [house_addr, pharm_poi]
			ev["options"] = [
				_opt("use_gas_mask", "Recover Full Shipment Safely in Gas Mask (+2 Anti-Rad)", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_flashlight", "Hook Dispatch Box at Dusk with Flashlight", "flashlight", GameState.has_working_item("flashlight")),
				_opt("sprint_grab", "Hold Breath & Snatch One Pack Fast!", "", true),
				_opt("leave_parcel", "Stay Sealed Below Ground", "", true)
			]

		"landmark_gas_station_underground_tank":
			var fuel_poi: String = _find_poi_name(["fuel_auto", "fuel", "gas", "76", "shell", "chevron", "auto", "service"], "Corner Service Station")
			ev["context"]["poi_name"] = fuel_poi
			ev["title"] = "Buried Reserve Tank at %s!" % fuel_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "A grease-pencil memo blown down from %s reveals its underground Regular Unleaded storage tank still holds hand-pump suction—gold-dust fuel for anyone rebuilding an escape vehicle in %s!" % [fuel_poi, hood]
			ev["options"] = [
				_opt("use_toolbox", "Couple Hand-Pump & Salvage Hardware (Toolbox)", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_gas_mask", "Pump 1 Jerrycan Safely in Gas Mask", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("trade_water_fuel", "Pay Station Watchman 2/4 Water for 1 Jerrycan", "water", GameState.water_quarters >= 2),
				_opt("skip_pump", "Too Volatile — Stay Inside Today", "", true)
			]

		"landmark_firehouse_siren_relay":
			var fire_poi: String = _find_poi_name(["fire", "civic", "police", "ems", "station"], "District Firehouse")
			ev["context"]["poi_name"] = fire_poi
			ev["title"] = "Emergency Call-Box Linked to %s!" % fire_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "The red cast-iron fire alarm box outside %s is clicking with live trickle voltage from %s's auxiliary Civil Defense repeater! Bridging the relay could ping military evac teams or pop the curbside hydrant first-aid locker!" % [house_addr, fire_poi]
			ev["options"] = [
				_opt("use_radio", "Patch Radio Into %s Repeater (+Military Intel!)" % fire_poi, "radio", GameState.has_working_item("radio")),
				_opt("use_axe", "Pry Curbside Trauma Box Open with Axe", "axe", GameState.has_working_item("axe")),
				_opt("cooperate_crank", "[COOPERATE] Crank Manual Telegraph Dynamo Together", "", _has_cooperating_pair(45)),
				_opt("ignore", "Leave the Street Call-Box Untouched", "", true)
			]

		"landmark_highschool_ham_club":
			var sch_poi: String = _find_poi_name(["school", "high", "college", "academy", "library"], "Local High School")
			ev["context"]["poi_name"] = sch_poi
			ev["title"] = "Shortwave Broadcast: %s Ham Radio Club!" % sch_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "CQ-CQ-FALLOUT! Student operators fortified inside the science wing of %s are broadcasting weather balloons, safe street grids, and convoy frequencies across %s on bicycle-dynamo power!" % [sch_poi, hood]
			ev["options"] = [
				_opt("use_radio", "Exchange Telemetry on CONELRAD Radio", "radio", GameState.has_working_item("radio")),
				_opt("use_book", "Decode Chemistry Lab Tip with Handbook (+Anti-Rad)", "book", GameState.has_working_item("book")),
				_opt("tap_antenna", "Clip Wire to Plumbing & Listen Together", "", true)
			]

		"landmark_hardware_scrap_yard":
			var hw_poi: String = _find_poi_name(["hardware", "lumber", "supply", "tool"], "Neighborhood Hardware & Lumber")
			ev["context"]["poi_name"] = hw_poi
			ev["title"] = "Galvanized Sheet-Steel Spill from %s!" % hw_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "A buckled flatbed trailer stenciled %s shed bundles of heavy-gauge steel brackets, rivets, and pipe fittings right into the service lane behind %s!" % [hw_poi, house_addr]
			ev["options"] = [
				_opt("use_toolbox", "Strip Prime Brackets & Reinforce Hatch (Toolbox)", "toolbox", GameState.has_working_item("toolbox")),
				_opt("use_suitcase", "Pack 2 Bundles of Scrap in Leather Suitcase", "suitcase", GameState.has_working_item("suitcase")),
				_opt("haul_one", "Drag 1 Scrap Bundle Down the Ladder by Hand", "", true)
			]

		"landmark_church_sanctuary_candles":
			var ch_poi: String = _get_sanctuary_poi_name()
			ev["context"]["poi_name"] = ch_poi
			ev["title"] = "Lantern Vigil & Care Basket from %s" % ch_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "Warm amber storm-lanterns flicker from the bell tower of %s across %s, and a volunteer has left a woven basket of beeswax candles and filtered well water beside %s!" % [ch_poi, hood, house_addr]
			ev["options"] = [
				_opt("return_note_soup", "Send Back 1/4 Soup & Neighborly Blessing", "soup", GameState.soup_quarters >= 1),
				_opt("accept_basket", "Bring Inside the Candles & Water Gratefully", "", true),
				_opt("leave_others", "Leave Basket for Worse-Off Neighbors (+Pride)", "", true)
			]

		"landmark_clinic_quarantine_notice":
			var cl_poi: String = _find_poi_name(["doctor", "clinic", "hospital", "medical", "urgent"], "District Medical Clinic")
			ev["context"]["poi_name"] = cl_poi
			ev["title"] = "Post-Blast Bio-Advisory from %s" % cl_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "A mimeographed health warning from %s flutters against your periscope: damp fallout drains across %s are breeding fever spores unless scrubbed or treated with Antibiotics!" % [cl_poi, hood]
			ev["options"] = [
				_opt("use_antibiotics", "Administer Prophylactic Antibiotics Dose", "antibiotics", GameState.has_working_item("antibiotics")),
				_opt("use_bug_spray", "Sterilize Floor Drains with Bug Spray", "bug_spray", GameState.has_working_item("bug_spray")),
				_opt("boil_scrub", "Boil 1/4 Water to Steam-Clean Bunks", "water", GameState.water_quarters >= 1),
				_opt("ignore", "Hope Our Concrete Sump Trap Holds", "", true)
			]

		"landmark_auto_shop_battery_rack":
			var auto_poi: String = _find_poi_name(["fuel_auto", "auto", "garage", "gas", "76", "service"], "Corner Auto Repair")
			ev["context"]["poi_name"] = auto_poi
			ev["title"] = "Wind-Charged 12V Battery Rack at %s!" % auto_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "Blue sparks glint down the street at %s, where a spinning rooftop weather-vane alternator is still trickle-charging heavy 12-volt automotive batteries and spare engine parts!" % auto_poi
			ev["options"] = [
				_opt("use_gas_mask", "Haul Charged Engine Part & Scrap in Gas Mask", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("use_scrap", "Splice Heavy Jumper Leads Using Scrap", "scrap", GameState.has_working_item("scrap")),
				_opt("pass_by", "Stay Low — Sparks Attract Scavengers", "", true)
			]

		"landmark_library_microfilm_atlas":
			var lib_poi: String = _find_poi_name(["library", "school", "college", "book"], "Branch Public Library")
			ev["context"]["poi_name"] = lib_poi
			ev["title"] = "Archivist Evacuating %s Microfilms" % lib_poi
			ev["category"] = "osm_landmark"
			ev["type"] = "item_choice"
			ev["description"] = "An archivist pushing a book-cart from %s pauses outside %s with a waterproof cylinder of municipal storm-drain & civil-defense microfilms covering %s!" % [lib_poi, house_addr, hood]
			ev["options"] = [
				_opt("use_flashlight", "Project & Copy Shortcut Charts (Flashlight)", "flashlight", GameState.has_working_item("flashlight")),
				_opt("give_soup", "Trade 2/4 Warm Soup for Atlas & Iodide", "soup", GameState.soup_quarters >= 2),
				_opt("wave_on", "Tip Hat & Wish the Archivist Well", "", true)
			]

		# ----------------------------------------------------------------------
		# 93-103. V2 PILLAR 5: DELAYED PERSISTENT CONSEQUENCES (STORY_FLAGS)
		# ----------------------------------------------------------------------
		"stranger_wounded_courier":
			ev["title"] = "Wounded Dispatch Courier at the Hatch!"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "A raspy knock echoes above %s. Dispatch Courier Vera leans pale against your porch post clutching bruised ribs after escaping highway ambushers outside %s. Her supply depot is four days' march away—do we patch her up, rob her belt pouch, or stay out of it?" % [house_addr, hood]
			ev["options"] = [
				_opt("help_medkit", "Bandage Vera's Ribs with Medkit (Delayed Reward)", "medkit", GameState.has_working_item("medkit")),
				_opt("help_rations", "Give 2/4 Water & 2/4 Soup for Her Trek", "water", GameState.water_quarters >= 2 and GameState.soup_quarters >= 2),
				_opt("rob_courier", "Mug Her Belt Pouch for Fast Loot (Risk Vendetta!)", "", true),
				_opt("turn_away", "Keep Hatch Bolted & Stay Uninvolved", "", true)
			]

		"courier_repayment_drop":
			var helped_d: int = int(GameState.story_flags.get("helped_courier_day", maxi(1, day - 4)))
			ev["context"]["helped_day"] = helped_d
			ev["title"] = "Courier Vera's Gratitude Cache!"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "THREE SHARP RAPS! Waiting on the blast hatch of %s is an oiled canvas depot crate tied with green surgical ribbon and a note: 'YOU KEPT ME ALIVE ON DAY %d. COURIERS ALWAYS PAY THEIR DEBTS! — VERA.'" % [house_addr, helped_d]
			ev["options"] = [
				_opt("use_flashlight", "Blink Thanks via Periscope & Haul In Bonus Crate!", "flashlight", GameState.has_working_item("flashlight")),
				_opt("claim_drop", "Haul Inside Antibiotics, Fuel & Soup!", "", true)
			]

		"vendetta_reprisal_raid":
			ev["title"] = "VENDETTA REPRISAL: Caravan Posse at the Door!"
			ev["category"] = "raiders"
			ev["type"] = "item_choice"
			ev["description"] = "SLEDGEHAMMERS ON STEEL! Our past sins just caught up with us—allies of the wanderer we robbed days ago have tracked boot-prints straight to %s across %s! Armed with pry-bars, they roar: 'TIME TO SETTLE ACCOUNTS DOUBLE!'" % [house_addr, hood]
			var v_opts: Array = []
			if GameState.padlock_active:
				v_opts.append(_opt("use_padlock", "Absorb Breach with Heavy Padlock!", "padlock", true))
			v_opts.append(_opt("use_rifle_ammo", "Drive Posse Back with Live Rifle Fire (-2 Ammo)", "rifle", GameState.has_working_item("rifle") and GameState.ammo_count >= 2))
			v_opts.append(_opt("pay_blood_debt", "Surrender 2 Full Soup Cans (8/4) to End Feud", "soup", GameState.soup_quarters >= 8))
			v_opts.append(_opt("endure_reprisal", "Brace the Hatch & Weather the Assault!", "", true))
			ev["options"] = v_opts

		"stranger_desperate_tinker":
			ev["title"] = "Old Man Mercer's Burned-Out Soldering Iron"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "Squinting through taped spectacles at %s, elderly radio-clockmaker Old Man Mercer begs for a bit of Scrap or Water so he can reach his cellar workshop four blocks past %s—promising to build us a custom air-scrubber and engine part, though his heavy brass toolbag sits right within snatching reach!" % [house_addr, hood]
			ev["options"] = [
				_opt("lend_scrap", "Donate 1 Scrap & Tighten His Glasses", "scrap", GameState.has_working_item("scrap")),
				_opt("give_water", "Share 2/4 Clean Water for His Walk", "water", GameState.water_quarters >= 2),
				_opt("rob_tinker", "Snatch His Brass Satchel & Slam Hatch!", "", true),
				_opt("send_away", "Decline Politely & Keep Sealed", "", true)
			]

		"tinker_workshop_dividend":
			ev["title"] = "Old Man Mercer's Custom Workshop Delivery!"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "WHIRRR-CLICK! True to his word from days ago, Old Man Mercer wheels a handcart up to %s, bolting a custom lead-baffle air scrubber onto our vent and sliding a rebuilt Engine Part and Anti-Rad pack down the chute!" % house_addr
			ev["options"] = [
				_opt("install_gift", "Accept Scrubber, Engine Part & Anti-Rad Pack!", "", true)
			]

		"mystery_seed_tin":
			ev["title"] = "1954 Agricultural Extension Micro-Seed Tin"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "Tucked behind the meter beneath %s sits a wax-dipped packet of 'FAST-SPROUT RADISH & BARLEY SHOOTS.' Eating the dry seeds yields a tiny snack right now—but sacrificing scarce Clean Water to irrigate them could grow a lush harvest in 4 days!" % house_addr
			ev["options"] = [
				_opt("plant_tray", "Irrigate Seed Tray with 3/4 Water (4-Day Harvest!)", "water", GameState.water_quarters >= 3),
				_opt("eat_seeds_now", "Eat Toasted Seeds Today (+2/4 Soup)", "", true),
				_opt("save_dry", "Leave Packet Sealed on the Shelf", "", true)
			]

		"sprouted_bunker_greens":
			ev["title"] = "Emerald Radish & Barley Harvest Underground!"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "PATIENCE PAYS OFF! Four days after watering our seed tray beneath the shelter bulb, crisp emerald radish greens and sweet barley shoots overflow the pan—fresh living vitamins in the middle of an atomic wasteland!"
			ev["options"] = [
				_opt("harvest_feast", "Harvest Fresh Greens (+2 Cans Ration & Soothe Sickness!)", "", true)
			]

		"unsealed_munitions_crate":
			ev["title"] = "Blinking National Guard Flare & Ammo Crate!"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "Half-buried in fallout ash outside %s lies an Army crate stamped 'HIGH-ALTITUDE RESCUE FLARES & .30-06 BALL' with a live locator transponder blinking red! Firing the flare summons a 4-day parachute drop; hauling the hot transponder inside unshielded could draw company!" % house_addr
			ev["options"] = [
				_opt("use_toolbox_disarm", "Disarm Locator with Toolbox & Loot Safely!", "toolbox", GameState.has_working_item("toolbox")),
				_opt("fire_signal_beacon", "Fire Sky-Flare for 4-Day Supply Drop (+2 Ammo Now)", "", true),
				_opt("haul_hot_crate", "Drag Whole Blinking Crate Inside Fast!", "", true),
				_opt("leave_crate", "Leave It Untouched in the Ash", "", true)
			]

		"beacon_supply_drop_arrival":
			ev["title"] = "High-Altitude Weather-Balloon Pod Touchdown!"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "WHOOSH-THUD! Guided by the distress flare you launched four days ago, an automated Civil Defense weather-balloon cargo pod settles right onto the lawn of %s!" % house_addr
			ev["options"] = [
				_opt("recover_pod", "Winch Inside Water, Soup & Anti-Rad Pod!", "", true)
			]

		"stranger_chemist_vial":
			ev["title"] = "The Bio-Chemist's Sealed Isotope Thermos"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "A breathless field bio-chemist knocks at %s holding a wax-sealed Dewar flask of experimental culture. She asks to store it untouched in our cool sump corner for four days while she fetches stabilizer across %s—promising half the refined medicine on her return!" % [house_addr, hood]
			ev["options"] = [
				_opt("store_honestly", "Store Sealed Flask Untouched in Sump (4 Days)", "", true),
				_opt("crack_thermos_now", "Break Seal & Sample Culture Immediately! (Wild Risk)", "", true),
				_opt("refuse_storage", "Decline Bio-Culture Storage Politely", "", true)
			]

		"chemist_antidote_return":
			ev["title"] = "The Bio-Chemist Returns with Refined Medicine!"
			ev["category"] = "consequence"
			ev["type"] = "item_choice"
			ev["description"] = "Punctual to the hour, the field bio-chemist taps cheerfully above %s! Inspecting the unbroken wax seal on her Dewar flask, she beams and passes down freshly compounded pharmaceuticals!" % house_addr
			ev["options"] = [
				_opt("collect_share", "Claim Antibiotics, Anti-Rad Pack & Medkit!", "", true)
			]

		_:
			ev["title"] = "Quiet Hum in the Shelter"
			ev["category"] = "info"
			ev["type"] = "info"
			ev["description"] = "Dust motes drift lazily beneath the dim shelter lamp under %s. Outside, the wind whispers across %s while everyone rests their feet." % [house_addr, hood]
			ev["options"] = [
				_opt("acknowledge", "Record Entry in Civil Defense Notebook", "", true)
			]

	# Guarantee at least 1 option is ALWAYS available == true (zero softlock guarantee!)
	_ensure_available_fallback(ev)
	return ev


static func _opt(opt_id: String, label: String, item_id: String, available: bool) -> Dictionary:
	return {
		"id": opt_id,
		"label": label,
		"item_id": item_id,
		"available": available
	}


static func _ensure_available_fallback(ev: Dictionary) -> void:
	var opts: Array = ev.get("options", [])
	var any_avail: bool = false
	for o_v in opts:
		var o: Dictionary = o_v
		if bool(o.get("available", false)):
			any_avail = true
			break
	if not any_avail:
		opts.append(_opt("ignore", "Play It Safe & Do Nothing", "", true))
		ev["options"] = opts


# ==============================================================================
# EVENT RESOLVER (MUTATES GAMESTATE CLEANLY & RETURNS OUTCOME)
# ==============================================================================

static func resolve_event(event_dict: Dictionary, choice_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var active_rng: RandomNumberGenerator = rng if rng != null else GameState.rng
	var ev_id: String = str(event_dict.get("id", ""))
	var ctx: Dictionary = event_dict.get("context", {})
	var chosen: String = _sanitize_choice(event_dict, choice_id)

	var house_addr: String = _get_house_address()
	var hood: String = _get_neighborhood_label()
	var poi_name: String = str(ctx.get("poi_name", _get_sanctuary_poi_name()))
	var target_member: Dictionary = _find_member_by_id_or_random(str(ctx.get("member_id", "")), active_rng)
	var m_name: String = str(target_member.get("name", str(ctx.get("member_name", "Ted"))))

	var outcome_text: String = "Another tense day logged in the Civil Defense notebook."
	var morale_delta: int = 0
	var tags: Array = []
	GameState.run_metrics["events_resolved"] = int(GameState.run_metrics.get("events_resolved", 0)) + 1

	# TSAR BOMBA extraction peril: the firestorm belt can turn back even a confirmed rescue.
	if str(GameState.difficulty) == "tsar_bomba" and ev_id.begins_with("rescue_") and ev_id.ends_with("_3") and chosen == "yes" and active_rng.randf() < 0.30:
		var chain_key: String = ev_id.trim_prefix("rescue_").trim_suffix("_3")
		GameState.rescue_chains[chain_key] = 1
		_add_soup_quarters(-2)
		_add_water_quarters(-2)
		_change_all_bunker_relationships(-4)
		return {
			"outcome_text": "We packed, we climbed, we waited at the hatch... and the column never came. A firestorm front rolled across %s and our rescuers turned back. Half a day's rations were wasted on the wait, and the contact will have to be rebuilt from scratch." % hood,
			"morale_delta": -2,
			"tags": ["rescue_failed", "item_lost", "morale_down"]
		}

	match ev_id:
		# ----------------------------------------------------------------------
		# 1. DAY 1 OPENING
		# ----------------------------------------------------------------------
		"day1_civil_defense_seal":
			GameState.unlock_achievement("first_seal")
			match chosen:
				"use_radio":
					GameState.surface_radiation_sv = maxf(0.2, GameState.surface_radiation_sv - 0.35)
					outcome_text = "CONELRAD 640 AM came through loud and clear! The announcer confirmed wind shear away from %s and reminded everyone to keep calm and ration wisely." % house_addr
					morale_delta = 1
					tags = ["morale_up"]
				"use_toolbox":
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 10.0, 0.0, 100.0)
					outcome_text = "Using the Toolbox, we torqued every hatch bolt snug (+10 Shelter Integrity). Not a speck of fallout dust is getting past this seal!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_book":
					_add_water_quarters(2)
					outcome_text = "Flipping open the Boy Scout & Civil Defense Handbook revealed a forgotten emergency water flask tucked behind the shelf (+2/4 Water)!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "Everyone answered roll call under %s, stacked the rations neatly, and swore to get through this together." % house_addr
					morale_delta = 1
					tags = ["morale_up"]

		# ----------------------------------------------------------------------
		# 2-4. MILITARY RESCUE CHAIN
		# ----------------------------------------------------------------------
		"rescue_military_1":
			match chosen:
				"use_radio":
					GameState.rescue_chains["military"] = maxi(1, int(GameState.rescue_chains.get("military", 0)))
					outcome_text = "BEEP-BEEP-LOCK! You tuned the CONELRAD Radio straight onto U.S. Civil Defense Evacuation Band Bravo! An operator logged %s as an active survivor shelter! (Military Rescue: Stage 1/3)" % house_addr
					morale_delta = 2
					tags = ["rescue_progress", "morale_up"]
				"tap_pipes":
					if active_rng.randf() < 0.45:
						GameState.rescue_chains["military"] = maxi(1, int(GameState.rescue_chains.get("military", 0)))
						outcome_text = "Remarkably, acoustic listening posts picked up your SOS ringing along the municipal water main! Faint static clicks confirmed receipt! (Military Rescue: Stage 1/3)"
						morale_delta = 1
						tags = ["rescue_progress", "morale_up"]
					else:
						outcome_text = "You hammered SOS onto the cold water pipe until your knuckles ached, but only distant echoes answered for now."
						morale_delta = 0
						tags = ["neutral"]
						if active_rng.randf() < 0.40:
							_add_water_quarters(-2)
							outcome_text = "The pipe carried our SOS to the wrong ears. By dawn someone had cut into the main upstream and our cistern tap ran dry (-2/4 Water)."
							morale_delta = -1
							tags = ["item_lost", "morale_down"]
				_:
					outcome_text = "We kept silent and let the CONELRAD carrier wave fade into static."
					morale_delta = 0
					tags = ["neutral"]

		"rescue_military_2":
			match chosen:
				"use_map", "use_flashlight", "use_axe":
					GameState.rescue_chains["military"] = maxi(2, int(GameState.rescue_chains.get("military", 0)))
					var method_txt: String = "pinpointed our exact street coordinates from the Map" if chosen == "use_map" else ("flashed crisp Morse SOS into the pilot's visor with the Flashlight" if chosen == "use_flashlight" else "sent up three clean puffs of signal smoke using Axe-split crate wood")
					outcome_text = "DIRECT VISUAL CONFIRMATION! You %s! The Civil Defense helicopter dipped its rotors twice over %s and dropped a green smoke marker: ground extraction is inbound! (Military Rescue: Stage 2/3)" % [method_txt, house_addr]
					morale_delta = 2
					tags = ["rescue_progress", "morale_up"]
				"wave_arms":
					if active_rng.randf() < 0.50:
						GameState.rescue_chains["military"] = maxi(2, int(GameState.rescue_chains.get("military", 0)))
						outcome_text = "Against all odds, the tail spotter heard your frantic soup-pot percussion echoing up the driveway of %s and waggled the chopper's wings! (Military Rescue: Stage 2/3)" % house_addr
						morale_delta = 2
						tags = ["rescue_progress", "morale_up"]
					else:
						outcome_text = "You banged pots until your ears rang, but rotor wash drowned out the noise. Hopefully they circle %s again soon!" % hood
						morale_delta = 0
						tags = ["neutral"]
						if active_rng.randf() < 0.45 and not bool(target_member.get("is_mutant", false)):
							target_member["radiation"] = float(target_member.get("radiation", 0.0)) + 18.0
							GameState.family_changed.emit()
							outcome_text += " %s stood in the open hatch far too long, breathing rotor-whipped ash." % m_name
							morale_delta = -1
							tags = ["morale_down"]
				_:
					outcome_text = "Unsure whose helicopter it was, we stayed tucked out of sight while rotor blades faded into the haze."
					morale_delta = 0
					tags = ["neutral"]

		"rescue_military_3":
			if chosen == "yes":
				GameState.rescue_chains["military"] = 3
				GameState.victory = true
				GameState.game_over = true
				GameState.ending_route = "military"
				GameState.ending_title = "VICTORY: U.S. Civil Defense Evacuation!"
				GameState.ending_description = "On Day %d, your family unbolted the blast hatch beneath %s and stepped into the warm floodlights of U.S. Civil Defense Convoy Charlie! Escorted safely out of %s aboard an armored fallout transport, everyone received hot rations, clean beds, and a brand-new start." % [GameState.day, house_addr, hood]
				GameState.unlock_achievement("military_evac")
				outcome_text = "THE HATCH SWINGS WIDE! U.S. Civil Defense hazmat medics wrap warm blankets around your shoulders and escort your family out of %s to freedom! VICTORY: U.S. Civil Defense Evacuation!" % house_addr
				morale_delta = 3
				tags = ["victory", "rescue_progress", "morale_up"]
			else:
				GameState.rescue_chains["military"] = 1
				outcome_text = "Paranoia got the better of us—we kept the hatch bolted while the bewildered Civil Defense squad moved down the street."
				morale_delta = -1
				tags = ["morale_down"]

		# ----------------------------------------------------------------------
		# 5-7. REAL-WORLD OSM SANCTUARY RESCUE CHAIN
		# ----------------------------------------------------------------------
		"rescue_sanctuary_1":
			match chosen:
				"give_water":
					_add_water_quarters(-4)
					GameState.rescue_chains["sanctuary"] = maxi(1, int(GameState.rescue_chains.get("sanctuary", 0)))
					outcome_text = "You passed a full bottle of Clean Water through the chute to the courier from %s. They pressed a carved wooden dove token into your palm and promised we wouldn't be forgotten! (Sanctuary Rescue: Stage 1/3)" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "item_lost", "morale_up"]
				"give_soup":
					_add_soup_quarters(-4)
					GameState.rescue_chains["sanctuary"] = maxi(1, int(GameState.rescue_chains.get("sanctuary", 0)))
					outcome_text = "Sharing a full can of Tomato Soup earned warm gratitude from the %s survivors! They sketched our address onto their neighborhood alliance roster. (Sanctuary Rescue: Stage 1/3)" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "item_lost", "morale_up"]
				"use_medkit":
					if GameState.has_working_item("medkit"):
						GameState.break_or_consume_item("medkit")
					GameState.rescue_chains["sanctuary"] = maxi(1, int(GameState.rescue_chains.get("sanctuary", 0)))
					outcome_text = "Your First Aid Medkit saved an injured parish volunteer at %s! Their council swore a solemn oath to reserve space for our household. (Sanctuary Rescue: Stage 1/3)" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "item_lost", "morale_up"]
				"use_book":
					GameState.rescue_chains["sanctuary"] = maxi(1, int(GameState.rescue_chains.get("sanctuary", 0)))
					outcome_text = "Copying water-purification diagrams from the Boy Scout Handbook thrilled the organizers at %s—and cost us zero rations! (Sanctuary Rescue: Stage 1/3)" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "morale_up"]
				_:
					outcome_text = "Afraid of running short ourselves, we left the note from %s unanswered." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"rescue_sanctuary_2":
			match chosen:
				"use_toolbox", "use_axe", "use_rifle", "use_book":
					GameState.rescue_chains["sanctuary"] = maxi(2, int(GameState.rescue_chains.get("sanctuary", 0)))
					_add_soup_quarters(2)
					outcome_text = "Pitching in to secure %s worked wonders! Their greenhouse lamps flickered to life across %s, and the grateful wardens sent back 2/4 hot Soup while preparing our family quarters! (Sanctuary Rescue: Stage 2/3)" % [poi_name, hood]
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"help_hands":
					_adjust_member_stat(target_member, "fatigue", 1)
					if active_rng.randf() < 0.70:
						GameState.rescue_chains["sanctuary"] = maxi(2, int(GameState.rescue_chains.get("sanctuary", 0)))
						outcome_text = "%s came back dusty and tired after hauling sandbags for %s, but the sanctuary walls are standing tall! (Sanctuary Rescue: Stage 2/3)" % [m_name, poi_name]
						morale_delta = 1
						tags = ["rescue_progress", "morale_up"]
					else:
						outcome_text = "Sudden fallout gusts forced %s back inside %s before the job at %s finished, though everyone stayed safe." % [m_name, house_addr, poi_name]
						morale_delta = 0
						tags = ["neutral"]
				_:
					outcome_text = "We stayed locked inside while distant hammering echoed from %s." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"rescue_sanctuary_3":
			if chosen == "yes":
				GameState.rescue_chains["sanctuary"] = 3
				GameState.victory = true
				GameState.game_over = true
				GameState.ending_route = "sanctuary"
				GameState.ending_title = "VICTORY: Rebuilt Neighborhood Sanctuary!"
				GameState.ending_description = "On Day %d, your family walked side-by-side from %s into the fortified gardens of %s! Together with resilient neighbors across %s, you rebuilt clean wells, rooftop greenhouses, and a thriving post-atomic community." % [GameState.day, house_addr, poi_name, hood]
				GameState.unlock_achievement("parish_alliance")
				outcome_text = "BELLS RING ACROSS %s! Welcomed with open arms into the fortified greenhouse walls of %s, your family's underground ordeal is finally over! VICTORY: Rebuilt Neighborhood Sanctuary!" % [hood.to_upper(), poi_name]
				morale_delta = 3
				tags = ["victory", "rescue_progress", "morale_up"]
			else:
				GameState.rescue_chains["sanctuary"] = 1
				outcome_text = "We thanked the delegation from %s, though turning down warm bread left everyone sighing wistfully." % poi_name
				morale_delta = -1
				tags = ["morale_down"]

		# ----------------------------------------------------------------------
		# 8-10. VAULT SCIENTIST & SHARIKOV RESCUE CHAIN
		# ----------------------------------------------------------------------
		"rescue_scientist_1":
			match chosen:
				"adopt_soup":
					_add_soup_quarters(-1)
					GameState.has_cat_sharikov = true
					GameState.rescue_chains["scientist"] = maxi(1, int(GameState.rescue_chains.get("scientist", 0)))
					outcome_text = "PURRRRR! Licking up 1/4 Tomato Soup, Sharikov the Cat strutted into the bunker like he owned the mortgage on %s! That mysterious copper wire on his collar still hums faintly... (Scientist Rescue: Stage 1/3)" % house_addr
					morale_delta = 2
					tags = ["companion", "rescue_progress", "morale_up"]
				"adopt_pet":
					if active_rng.randf() < 0.45:
						GameState.has_cat_sharikov = true
						GameState.rescue_chains["scientist"] = maxi(1, int(GameState.rescue_chains.get("scientist", 0)))
						outcome_text = "With a gentle 'pspsps,' cautious Sharikov the Cat finally hopped down onto %s's lap, trailing his enigmatic Institute wire behind him! (Scientist Rescue: Stage 1/3)" % m_name
						morale_delta = 2
						tags = ["companion", "rescue_progress", "morale_up"]
					else:
						outcome_text = "Without a warm snack to win his trust, the skittish cat flicked his copper-collared tail and trotted back into the fog unharmed."
						morale_delta = 0
						tags = ["neutral"]
						if active_rng.randf() < 0.40:
							_adjust_member_stat(target_member, "injury", 1)
							outcome_text = "Sharikov did NOT want to be picked up. %s's forearm is striped with deep, dirty scratches that will need watching." % m_name
							morale_delta = -1
							tags = ["injured", "morale_down"]
				_:
					outcome_text = "Sharikov gave us a deeply judgmental squint and trotted off down the pipe with his mysterious collar."
					morale_delta = 0
					tags = ["neutral"]

		"rescue_scientist_2":
			match chosen:
				"use_radio", "use_flashlight", "use_map":
					GameState.rescue_chains["scientist"] = maxi(2, int(GameState.rescue_chains.get("scientist", 0)))
					_add_water_quarters(2)
					outcome_text = "EUREKA! Following Sharikov's telemetry cable revealed a pneumatic canister chute from Sub-Vault Omega! Along with a pneumatic chime confirming VIP clearance, a chilled tube of purified water popped up (+2/4 Water)! (Scientist Rescue: Stage 2/3)"
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"send_note":
					if active_rng.randf() < 0.78:
						GameState.rescue_chains["scientist"] = maxi(2, int(GameState.rescue_chains.get("scientist", 0)))
						outcome_text = "Sharikov vanished down the conduit for ten minutes and trotted back wearing a stamped brass badge reading: 'HOUSEHOLD APPROVED — PREPARE FOR EXTRACTION!' (Scientist Rescue: Stage 2/3)"
						morale_delta = 2
						tags = ["rescue_progress", "morale_up"]
					else:
						outcome_text = "Sharikov vanished down the conduit and came back two days later, thin and limping, without his collar. Whoever is on the other end may have lost track of us."
						GameState.rescue_chains["scientist"] = maxi(0, int(GameState.rescue_chains.get("scientist", 0)) - 1)
						morale_delta = -1
						tags = ["morale_down"]
				_:
					outcome_text = "We left the humming copper wire coiled neatly by the wall while Sharikov purred like a Geiger counter."
					morale_delta = 0
					tags = ["neutral"]

		"rescue_scientist_3":
			if chosen == "yes":
				GameState.rescue_chains["scientist"] = 3
				GameState.victory = true
				GameState.game_over = true
				GameState.ending_route = "scientist"
				GameState.ending_title = "VICTORY: Secret Vault Scientist Extraction!"
				GameState.ending_description = "On Day %d, guided by Sharikov the Cat's telemetry collar, secret Institute researchers whisked your family from %s down into Sub-Vault Omega — complete with subterranean orchards, Jell-O buffets, and unlimited tuna for Sharikov!" % [GameState.day, house_addr]
				GameState.unlock_achievement("vault_agent")
				outcome_text = "SCIENCE TRIUMPHS! Carrying Sharikov on his velvet cushion, the silver-suited agents guide your entire family into a gleaming subterranean monorail beneath %s! VICTORY: Secret Vault Scientist Extraction!" % hood
				morale_delta = 3
				tags = ["victory", "rescue_progress", "morale_up"]
			else:
				GameState.rescue_chains["scientist"] = 1
				outcome_text = "The Vault Scientists adjusted their spectacles in disbelief, left Sharikov a tiny fish biscuit, and sealed their tunnel."
				morale_delta = 0
				tags = ["neutral"]

		# ----------------------------------------------------------------------
		# 11-23. CLASSIC 60 SECONDS! HAZARDS, RAIDERS, OOZE, TRADER, REPAIR
		# ----------------------------------------------------------------------
		"hazard_mutant_roaches":
			match chosen:
				"use_bug_spray":
					if GameState.has_working_item("bug_spray"):
						GameState.break_or_consume_item("bug_spray")
					outcome_text = "PSSSSHT! One heroic cloud of Mutant Bug Spray sent the six-inch roaches belly-up in seconds! The soup shelf is secure."
					morale_delta = 1
					tags = ["item_lost", "morale_up"]
				"use_cat":
					outcome_text = "Sharikov blurred into furry lightning, swatting every last mutant cockroach back into the sump drain without spilling a drop of soup! Good kitty!"
					morale_delta = 2
					tags = ["companion", "morale_up"]
				"use_axe":
					if active_rng.randf() < 0.15 and GameState.has_working_item("axe"):
						GameState.break_or_consume_item("axe")
						outcome_text = "CHOP! You flattened the mutant roach battalion, though slamming concrete chipped the Axe handle! (Axe broken)"
						morale_delta = 0
						tags = ["item_broken"]
					else:
						outcome_text = "WHACK! Precision lumberjack form dispatched every giant cockroach—and left dramatic battle marks in the floor!"
						morale_delta = 1
						tags = ["morale_up"]
				"use_book":
					outcome_text = "THUD! Nothing beats 600 pages of American Civil Defense & Boy Scout wisdom applied at high velocity! The roaches retreated in disgrace."
					morale_delta = 1
					tags = ["morale_up"]
				_:
					if not bool(target_member.get("is_mutant", false)):
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "Allowing loafer-sized cockroaches to sublet the pantry backfired—%s caught a nasty bug from contaminated spoons!" % m_name
						morale_delta = -2
						tags = ["sick", "morale_down"]
					else:
						outcome_text = "Oddly enough, the mutant cockroaches saluted %s like a cousin and marched politely out the drain!" % m_name
						morale_delta = 1
						tags = ["mutant", "morale_up"]

		"hazard_vent_filter":
			match chosen:
				"use_toolbox":
					outcome_text = "With the Toolbox, you stripped the jammed intake fan, cleared the fallout grit, and restored crisp airflow!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_gas_mask":
					if active_rng.randf() < 0.18 and GameState.has_working_item("gas_mask"):
						GameState.break_or_consume_item("gas_mask")
						outcome_text = "Wearing the Gas Mask let %s scrub the radioactive soot safely, though grit clogged the mask's filter! (Gas Mask needs repair)" % m_name
						morale_delta = 0
						tags = ["item_broken"]
					else:
						outcome_text = "Protected by the Gas Mask, %s vacuumed every flake of fallout ash out of the intake elbow!" % m_name
						morale_delta = 1
						tags = ["morale_up"]
				"use_book":
					outcome_text = "Following Chapter 9 ('Improvised Activated Charcoal Baffles'), you folded a textbook replacement filter that works like a charm!"
					morale_delta = 1
					tags = ["morale_up"]
				_:
					var iron_vent: bool = _has_iron_stomach(target_member)
					if not bool(target_member.get("is_mutant", false)):
						target_member["radiation"] = float(target_member.get("radiation", 0.0)) + (9.0 if iron_vent else 18.0)
						GameState.family_changed.emit()
					if bool(target_member.get("is_mutant", false)):
						outcome_text = "Fallout ash puffed from the pipe, but mutant %s barely sneezed at the soot!" % m_name
						morale_delta = 0
						tags = ["mutant", "neutral"]
					elif iron_vent and active_rng.randf() < 0.50:
						var iron_m_v: Dictionary = target_member if str(target_member.get("trait", "")).to_lower() == "iron_stomach" else _get_member_with_trait("iron_stomach")
						var iron_name_v: String = str(iron_m_v.get("name", m_name))
						outcome_text = "Stuffing gym socks into the air intake kicked up gray ash, but %s's Iron Stomach fought off the fallout nausea!" % iron_name_v
						morale_delta = 0
						tags = ["neutral"]
					else:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "Stuffing gym socks into a radioactive air intake only flavored the fallout dust—%s started coughing from ash inhalation!" % m_name
						morale_delta = -1
						tags = ["sick", "morale_down"]

		"raiders_blast_hatch":
			if chosen == "use_padlock" or (chosen == "cower" and GameState.padlock_active):
				GameState.break_or_consume_item("padlock")
				outcome_text = "CLANG-SNAP! Your hardened Heavy Padlock absorbed the raiders' crowbar blows until their pry-bar bent in half! Though the padlock sheared off in the struggle, the gang fled down %s empty-handed!" % house_addr
				morale_delta = 1
				tags = ["raid", "item_lost", "morale_up"]
			else:
				match chosen:
					"use_rifle":
						if GameState.ammo_count > 0:
							GameState.break_or_consume_item("ammo")
							_add_soup_quarters(2)
							outcome_text = "CRACK! Firing 1 Rifle round out the periscope baffle sent raiders scrambling over fences across %s—dropping 2/4 Soup in their panic!" % hood
							morale_delta = 2
							tags = ["raid", "item_gained", "morale_up"]
						else:
							if active_rng.randf() < 0.82:
								outcome_text = "CHICK-CLACK! Even unloaded, racking the Hunting Rifle's bolt down the speaking tube convinced the raiders to find softer targets!"
								morale_delta = 1
								tags = ["raid", "morale_up"]
							else:
								GameState.break_or_consume_item("rifle")
								outcome_text = "You jammed the Rifle barrel into their pry-slot and successfully levered them off the hatch, though the wooden stock cracked! (Rifle broken)"
								morale_delta = 0
								tags = ["raid", "item_broken"]
					"use_axe":
						if active_rng.randf() < 0.15 and GameState.has_working_item("axe"):
							GameState.break_or_consume_item("axe")
							outcome_text = "A ferocious swing of the Fireman's Axe sent sparks flying off their crowbar and routed the raiders, chipping the blade! (Axe needs repair)"
							morale_delta = 0
							tags = ["raid", "item_broken"]
						else:
							outcome_text = "One lumberjack war-cry and a gleaming Axe blade poking out the hatch sent the raiders sprinting back down %s!" % house_addr
							morale_delta = 2
							tags = ["raid", "morale_up"]
					"use_dog":
						outcome_text = "GRRRRR-WOOF! Pancake unleashed a bass-boosted hound roar down the echo pipe that sounded like a 400-pound dire wolf! The raiders vanished in record time!"
						morale_delta = 2
						tags = ["raid", "companion", "morale_up"]
					"use_mutant":
						var mut_n: String = str(ctx.get("mutant_name", m_name))
						outcome_text = "When %s pressed a glowing green face against the thick glass port and hissed, the raiders shrieked 'SWAMP MONSTER!' and bolted!" % mut_n
						morale_delta = 2
						tags = ["raid", "mutant", "morale_up"]
					"use_harmonica":
						_add_water_quarters(2)
						outcome_text = "Miraculously, your soulful 1950s Harmonica blues made the lead raider weep with homesickness! Instead of robbing us, they left 2/4 Water on the porch!"
						morale_delta = 2
						tags = ["raid", "item_gained", "morale_up"]
					_:
						var present: Array = _get_present_members()
						if GameState.day >= 12 and GameState.bunker_structural_integrity <= 30.0 and present.size() <= 1:
							for m_v in present:
								if m_v is Dictionary:
									var m_def: Dictionary = m_v
									m_def["alive"] = false
									m_def["in_bunker"] = false
									m_def["death_reason"] = "Shelter overrun by wasteland raiders."
									m_def["status_note"] = "Shelter overrun by wasteland raiders."
							GameState.bunker_structural_integrity = 0.0
							GameState.game_over = true
							GameState.victory = false
							GameState.ending_title = "DEFEAT: Shelter Overrun by Raiders"
							GameState.ending_description = "On Day %d, with the blast hatch already weakened and no weapons or padlock left to hold the line, wasteland marauders pried open the shelter beneath %s." % [GameState.day, house_addr]
							GameState.family_changed.emit()
							outcome_text = "CRUNCH! With structural integrity critical and no defenses left, the raiders wrenched open the buckled blast hatch at %s! GAME OVER!" % house_addr
							morale_delta = -2
							tags = ["raid", "gameover", "morale_down"]
						else:
							var stolen_s: int = mini(4, GameState.soup_quarters)
							var stolen_w: int = mini(4, GameState.water_quarters)
							_add_soup_quarters(-stolen_s)
							_add_water_quarters(-stolen_w)
							GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 15.0, 5.0, 100.0)
							_adjust_member_stat(target_member, "injury", 1)
							outcome_text = "The raiders wrenched the supply chute open, bruising %s in the tug-of-war (-15 Integrity) and looting %d/4 Soup and %d/4 Water before fleeing!" % [m_name, stolen_s, stolen_w]
							morale_delta = -2
							tags = ["raid", "injured", "item_lost", "morale_down"]

		"ooze_green_pipe":
			match chosen:
				"use_toolbox":
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 5.0, 0.0, 100.0)
					outcome_text = "Two firm turns of the pipe wrench from the Toolbox sealed the glowing ooze right back where it came from (+5 Integrity)!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_gas_mask":
					outcome_text = "Wearing the Gas Mask and heavy gloves, %s scrubbed the fluorescent slime into a jar—makes a surprisingly cozy nightlight!" % m_name
					morale_delta = 1
					tags = ["morale_up"]
				"examine_ooze":
					if active_rng.randf() < 0.75 and not bool(target_member.get("is_mutant", false)):
						outcome_text = _apply_mutant_transformation(target_member)
						morale_delta = 2
						tags = ["mutant", "healed", "morale_up"]
					else:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "BLORP! A drop of lime-green pipe sludge landed on %s's nose—no superpowers today, just an upset stomach!" % m_name
						morale_delta = -1
						tags = ["sick", "morale_down"]
				"wipe_rag":
					if active_rng.randf() < 0.45 and not bool(target_member.get("is_mutant", false)):
						outcome_text = _apply_mutant_transformation(target_member)
						morale_delta = 1
						tags = ["mutant", "healed", "morale_up"]
					else:
						outcome_text = "%s gingerly wiped the pipe clean using three soup labels and a stick. Crispy rags, zero casualties!" % m_name
						morale_delta = 0
						tags = ["neutral"]
				_:
					if active_rng.randf() < 0.35 and not bool(target_member.get("is_mutant", false)):
						outcome_text = _apply_mutant_transformation(target_member)
						morale_delta = 1
						tags = ["mutant", "morale_up"]
					else:
						outcome_text = "The emerald drip hardened into a harmless glowing stalactite above the bunk."
						morale_delta = 0
						tags = ["neutral"]

		"companion_pancake_dog":
			match chosen:
				"adopt_soup":
					_add_soup_quarters(-1)
					GameState.has_dog_pancake = true
					outcome_text = "ARF! Pancake the Dog inhaled 1/4 Tomato Soup, licked every single face in the bunker, and curled up proudly on guard duty by the hatch!"
					morale_delta = 2
					tags = ["companion", "morale_up"]
				"let_in":
					if active_rng.randf() < 0.45:
						GameState.has_dog_pancake = true
						outcome_text = "Whistling softly coaxed cautious Pancake the Dog down the ladder! Our shelter now has a four-legged morale officer and watchdog!"
						morale_delta = 2
						tags = ["companion", "morale_up"]
						if active_rng.randf() < 0.35:
							_add_soup_quarters(-2)
							outcome_text += " ...who promptly chewed through a soup can in the night (-2/4 Soup)."
							tags = ["companion", "item_lost", "morale_up"]
					else:
						outcome_text = "Without a bite of soup to coax him down the dark steel ladder, the skittish pup gave a shy whimper and trotted back into the fog unharmed."
						morale_delta = 0
						tags = ["neutral"]
				_:
					outcome_text = "Listening to the little dog trot sadly away from %s left everyone staring quietly at their shoes." % house_addr
					morale_delta = -1
					tags = ["morale_down"]

		"trader_wasteland_swap":
			if chosen == "decline":
				outcome_text = "You tipped an imaginary hat through the periscope, and the peddler wheeled his cart onward down %s." % hood
				morale_delta = 0
				tags = ["neutral"]
			else:
				# Pay trade cost cleanly
				match chosen:
					"trade_ammo":
						GameState.ammo_count = maxi(0, GameState.ammo_count - 2)
					"trade_bug_spray":
						GameState.break_or_consume_item("bug_spray")
					"trade_cards":
						_remove_durable_item("cards")
					"trade_checkers":
						_remove_durable_item("checkers")
				# Grant dynamically needed reward
				var reward_kind: String = str(ctx.get("wanted_gear", "supplies"))
				if reward_kind == "gas_mask":
					GameState.add_scavenged_item("gas_mask", 1)
					outcome_text = "PLEASURE DOING BUSINESS! Through the chute dropped a factory-sealed Gas Mask—ready for expeditions across %s!" % hood
				elif reward_kind == "radio":
					GameState.add_scavenged_item("radio", 1)
					outcome_text = "BARGAIN OF THE CENTURY! The trader slid a working CONELRAD Radio down the chute! Now we can listen for rescue!"
				else:
					_add_soup_quarters(4)
					_add_water_quarters(4)
					GameState.add_scavenged_item("medkit", 1)
					outcome_text = "JACKPOT SWAP! The peddler delivered 1 full Soup Can, 1 full Water Bottle, and 1 Medkit down the chute!"
				GameState.inventory_changed.emit()
				morale_delta = 2
				tags = ["item_gained", "morale_up"]

		"repair_broken_gear":
			var b_id: String = str(ctx.get("broken_item_id", "radio"))
			var b_name: String = str(ctx.get("broken_item_name", "Equipment"))
			match chosen:
				"use_toolbox", "use_book", "use_handy":
					GameState.repair_item(b_id)
					var fixer: String = str(ctx.get("handy_name", "Steady craftsmanship")) if chosen == "use_handy" else ("The Repair Toolbox" if chosen == "use_toolbox" else "The Boy Scout Handbook")
					outcome_text = "FIXED! %s brought our broken %s roaring back to 1955 showroom condition!" % [fixer, b_name]
					morale_delta = 2
					tags = ["item_repaired", "morale_up"]
				"tinker_blind":
					if active_rng.randf() < 0.45:
						GameState.repair_item(b_id)
						outcome_text = "MIRACLE PERCUSSIVE MAINTENANCE! Giving the %s two firm thumps on the side actually reconnected the loose contact—it works!" % b_name
						morale_delta = 2
						tags = ["item_repaired", "morale_up"]
					else:
						outcome_text = "Sparks flew and %s pinched a thumb—the %s remains stubbornly broken for now." % [m_name, b_name]
						morale_delta = -1
						tags = ["morale_down"]
				_:
					outcome_text = "We set the broken %s back on the shelf for another day." % b_name
					morale_delta = 0
					tags = ["neutral"]

		"bunker_darkness_bulb":
			match chosen:
				"use_flashlight":
					outcome_text = "CLICK! The Flashlight beam cut away the gloom while you twisted the spare ceiling fuse back into place!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_toolbox":
					outcome_text = "By touch alone, you used insulated pliers from the Toolbox to clean the corroded lamp socket—LET THERE BE LIGHT!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_harmonica":
					outcome_text = "Campfire Harmonica tunes kept everyone giggling in the pitch black until the backup bulb cooled and flickered back on!"
					morale_delta = 1
					tags = ["morale_up"]
				_:
					if active_rng.randf() < 0.45:
						_adjust_member_stat(target_member, "injury", 1)
						outcome_text = "Stumbling toward the latrine in total darkness, %s barked a shin hard against the steel ladder!" % m_name
						morale_delta = -1
						tags = ["injured", "morale_down"]
					else:
						outcome_text = "After three spooky hours of ghost noises, the backup filament finally flickered back to life."
						morale_delta = -1
						tags = ["morale_down"]

		"family_argument":
			match chosen:
				"use_cards", "use_checkers", "use_harmonica", "use_book":
					_reduce_family_stress(1)
					outcome_text = "Laughter replaced bickering within ten minutes! Nothing smooths over bunker cabin fever like classic 1950s parlor entertainment."
					morale_delta = 2
					tags = ["morale_up"]
				_:
					outcome_text = "Everyone sulked in their respective corners of the concrete box for the rest of the evening."
					morale_delta = -1
					tags = ["morale_down"]

		"outside_suspicious_suitcase":
			if chosen == "yes":
				var has_scout: bool = not _get_member_with_trait("scout").is_empty()
				if has_scout or active_rng.randf() < 0.68:
					_add_soup_quarters(4)
					_add_water_quarters(4)
					if not GameState.padlock_active:
						GameState.add_scavenged_item("padlock", 1)
						outcome_text = "SCORE! Inside the monogrammed valise sat 1 Soup Can, 1 Water Bottle, and a gleaming Heavy Padlock!"
					else:
						GameState.add_scavenged_item("ammo", 1)
						outcome_text = "SCORE! Inside the monogrammed valise sat 1 Soup Can, 1 Water Bottle, and 2 rounds of Rifle Ammo!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				else:
					_adjust_member_stat(target_member, "sickness", 1)
					outcome_text = "COUGH-SPUTTER! A prankster wasteland bandit had rigged the valise with a fermented skunk-cabbage stink canister! %s feels queasy." % m_name
					morale_delta = -1
					tags = ["sick", "morale_down"]
			else:
				outcome_text = "Discipline wins survival—we left the mysterious valise untouched until wind blew it down %s." % house_addr
				morale_delta = 0
				tags = ["neutral"]

		"outside_mysterious_knock":
			if chosen == "yes":
				if active_rng.randf() < 0.65:
					_add_soup_quarters(4)
					GameState.add_scavenged_item("medkit", 1)
					outcome_text = "Nobody was in sight—only a Red Cross relief parcel resting on the hatch containing 1 Soup Can and 1 First Aid Medkit!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				else:
					var lost_w: int = mini(2, GameState.water_quarters)
					_add_water_quarters(-lost_w)
					outcome_text = "A freezing gust of radioactive ash blew straight down the ladder (and startled %s into spilling %d/4 Water) before you slammed the hatch!" % [m_name, lost_w]
					morale_delta = -1
					tags = ["item_lost", "morale_down"]
			else:
				outcome_text = "We kept the hatch double-bolted. By morning, only windblown ash covered the porch."
				morale_delta = 0
				tags = ["neutral"]

		"quirky_beard_overgrowth":
			match chosen:
				"use_axe":
					if active_rng.randf() < 0.85:
						_reduce_family_stress(1)
						outcome_text = "DAPPER AS 1954! Honed to a mirror shine, the Fireman's Axe delivered crisp barbershop trims all around! Morale soared!"
						morale_delta = 2
						tags = ["morale_up"]
					else:
						_adjust_member_stat(target_member, "injury", 1)
						outcome_text = "Mostly dapper—except %s sneezed mid-trim and earned a dramatic chin nick!" % m_name
						morale_delta = 0
						tags = ["injured"]
				"braid_it":
					if active_rng.randf() < 0.65:
						outcome_text = "Viking wasteland chic is officially in season beneath %s! Everyone looks fiercely heroic." % house_addr
						morale_delta = 1
						tags = ["morale_up"]
					else:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "The braids looked heroic for a day. Then the itching started - bunker lice. %s has a scalp rash and a fever." % m_name
						morale_delta = -1
						tags = ["sick", "morale_down"]
				_:
					outcome_text = "At least the extra whiskers help keep ears warm when drafts blow."
					morale_delta = 0
					tags = ["neutral"]

		"family_birthday":
			var next_age: int = int(ctx.get("new_age", int(target_member.get("age", 20)) + 1))
			target_member["age"] = next_age
			target_member["sanity"] = maxi(0, int(target_member.get("sanity", 0)) - 1)
			target_member["status_note"] = "Celebrated turning %d in the shelter!" % next_age
			GameState.family_changed.emit()
			match chosen:
				"feast_soup":
					_add_soup_quarters(-2)
					_reduce_family_stress(1)
					outcome_text = "With a matchstick candle balanced atop warm Tomato Soup, everyone sang to %s (now %d)! Best bunker party in %s!" % [m_name, next_age, hood]
					morale_delta = 2
					tags = ["morale_up"]
				"use_harmonica", "use_cards":
					_reduce_family_stress(1)
					outcome_text = "Music and parlor tricks made %s's %dth birthday genuinely unforgettable despite the concrete ceiling!" % [m_name, next_age]
					morale_delta = 2
					tags = ["morale_up"]
				_:
					outcome_text = "Four-part acappella harmony echoed warmly around the shelter for %s's %dth birthday!" % [m_name, next_age]
					morale_delta = 1
					tags = ["morale_up"]

		# ----------------------------------------------------------------------
		# 24-27. NUKE ZONE SPECIAL EVENTS
		# ----------------------------------------------------------------------
		"nuke_blizzard_freeze":
			match chosen:
				"use_axe":
					GameState.bunker_temp_c = clampf(GameState.bunker_temp_c + 5.0, -15.0, 35.0)
					outcome_text = "Splitting spare crate slats with the Axe fueled a cozy tin-can brazier, warming the shelter by +5.0°C and thawing the pipes!"
					morale_delta = 2
					tags = ["morale_up"]
				"use_toolbox":
					GameState.bunker_temp_c = clampf(GameState.bunker_temp_c + 2.5, -15.0, 35.0)
					_add_water_quarters(2)
					outcome_text = "Bleeding and lagging the copper manifold with the Toolbox prevented pipe rupture—and drained +2/4 clean reserve Water!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
				"use_flashlight":
					GameState.bunker_temp_c = clampf(GameState.bunker_temp_c + 1.5, -15.0, 35.0)
					outcome_text = "Tucking the warm incandescent Flashlight bulb beside the main valve kept ice from splitting the brass joint!"
					morale_delta = 1
					tags = ["morale_up"]
				_:
					var lost_ice: int = mini(3, GameState.water_quarters)
					_add_water_quarters(-lost_ice)
					if active_rng.randf() < 0.50:
						_adjust_member_stat(target_member, "sickness", 1)
					outcome_text = "BRRR! Frost split a bottle cap (-%d/4 Water) and left %s sniffling under three blankets!" % [lost_ice, m_name]
					morale_delta = -2
					tags = ["item_lost", "sick", "morale_down"]

		"nuke_ground_zero_tremor":
			match chosen:
				"use_toolbox":
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 12.0, 0.0, 100.0)
					outcome_text = "Fast work with the Toolbox wedged steel angle-brackets into the ceiling joists (+12 Shelter Integrity)!"
					morale_delta = 2
					tags = ["morale_up"]
				"use_gas_mask":
					outcome_text = "While plaster rained down, the Gas Mask kept %s breathing clear as you swept debris away!" % m_name
					morale_delta = 1
					tags = ["morale_up"]
				_:
					if active_rng.randf() < 0.65:
						GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 5.0, 10.0, 100.0)
						outcome_text = "Bert the Turtle would be proud! Everyone tucked safely beneath the bunks with only minor dust (-5 Integrity)."
						morale_delta = 0
						tags = ["neutral"]
					else:
						GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 10.0, 10.0, 100.0)
						_adjust_member_stat(target_member, "injury", 1)
						outcome_text = "A tumbling ration crate clipped %s's shoulder during the aftershock (-10 Integrity)!" % m_name
						morale_delta = -1
						tags = ["injured", "morale_down"]

		"nuke_downwind_acid_rain":
			match chosen:
				"use_book":
					_add_water_quarters(4)
					GameState.surface_radiation_sv = maxf(0.15, GameState.surface_radiation_sv - 0.4)
					outcome_text = "Brilliant science! Using the Handbook's charcoal-sand distillation rig turned storm runoff into 1 full bottle of Clean Water (+4/4)!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_toolbox":
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 6.0, 0.0, 100.0)
					outcome_text = "Sealing the sump check-valve with the Toolbox kept every drop of black fallout rain outside (+6 Integrity)!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_radio":
					GameState.surface_radiation_sv = maxf(0.15, GameState.surface_radiation_sv - 0.6)
					outcome_text = "CONELRAD meteorology confirmed the storm washed airborne particulates out of %s—surface radiation eased!" % hood
					morale_delta = 1
					tags = ["morale_up"]
				_:
					_adjust_member_stat(target_member, "fatigue", 1)
					outcome_text = "%s spent three hours bailing damp seepage into the floor drain, keeping rations dry at the cost of sore arms." % m_name
					morale_delta = 0
					tags = ["neutral"]

		"nuke_emp_magnetic_storm":
			match chosen:
				"use_toolbox":
					outcome_text = "Grounding the copper conduit with the Toolbox harmlessly bled off the EMP surge—and even topped up the emergency battery!"
					morale_delta = 1
					tags = ["morale_up"]
				"unplug_gear":
					outcome_text = "Quick thinking! Disconnecting the antenna and tucking electronics inside a tin pot saved every circuit from the surge."
					morale_delta = 1
					tags = ["morale_up"]
				_:
					if active_rng.randf() < 0.35 and GameState.has_working_item("radio"):
						GameState.break_or_consume_item("radio")
						outcome_text = "ZAP! A violet arc jumped from the pipe straight into the CONELRAD Radio's vacuum tube! (Radio needs repair)"
						morale_delta = -1
						tags = ["item_broken", "morale_down"]
					else:
						outcome_text = "The purple St. Elmo's glow faded harmlessly, leaving everyone's hair standing hilariously on end!"
						morale_delta = 1
						tags = ["morale_up"]

		# ----------------------------------------------------------------------
		# 28-37. REAL-WORLD OPENSTREETMAP NEIGHBORHOOD EVENTS
		# ----------------------------------------------------------------------
		"osm_grocery_cart_rattle":
			match chosen:
				"use_gas_mask":
					_add_soup_quarters(6)
					outcome_text = "Wearing the Gas Mask, %s vaulted outside %s and hauled in 1 + 2/4 cans of Tomato Soup from the %s shopping cart!" % [m_name, house_addr, poi_name]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_axe":
					_add_soup_quarters(4)
					outcome_text = "Clever reach! Hooking the %s cart basket with the Axe blade reeled 1 full Soup Can (+4/4) right into the hatch!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"dash_bare":
					_add_soup_quarters(4)
					if not bool(target_member.get("is_mutant", false)):
						target_member["radiation"] = float(target_member.get("radiation", 0.0)) + 15.0
						GameState.family_changed.emit()
					outcome_text = "%s sprinted out unmasked and scored 1 Soup Can (+4/4) from the %s cart, catching a mild whiff of surface fallout!" % [m_name, poi_name]
					morale_delta = 1
					tags = ["item_gained"]
					if active_rng.randf() < 0.35:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text += " By nightfall %s was retching and feverish from the dust." % m_name
						morale_delta = 0
						tags = ["item_gained", "sick"]
				_:
					outcome_text = "Another gust sent the %s shopping cart rattling away down the empty street." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"osm_pharmacy_courier":
			match chosen:
				"give_water":
					_add_water_quarters(-2)
					GameState.add_scavenged_item("medkit", 1)
					_heal_one_afflicted_member()
					outcome_text = "Grateful for 2/4 Clean Water, the %s pharmacist handed down 1 First Aid Medkit and antibiotics that eased our ailments!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "healed", "morale_up"]
				"use_map":
					GameState.add_scavenged_item("medkit", 1)
					outcome_text = "Tracing clear streets out of %s from your Map earned a sealed First Aid Medkit from the grateful %s pharmacist!" % [hood, poi_name]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "You wished the %s pharmacist safe travels down the road." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"osm_neighbor_bunker_tap":
			match chosen:
				"use_book":
					_add_water_quarters(3)
					outcome_text = "Decoding Morse from %s revealed a secret: turning our auxiliary basement valve twice released +3/4 trapped clean Water!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_harmonica":
					_reduce_family_stress(1)
					outcome_text = "When you played 'Oh! Susanna' down the pipe, %s tapped rhythmic percussion back on a wrench! Nobody feels alone tonight." % poi_name
					morale_delta = 2
					tags = ["morale_up"]
				"tap_hello":
					outcome_text = "Friendly spoon-taps echoed back and forth with %s, lifting spirits across the dark block!" % poi_name
					morale_delta = 1
					tags = ["morale_up"]
					if active_rng.randf() < 0.30:
						_add_soup_quarters(-2)
						outcome_text = "The tapping from %s went on a little too long. Someone above was listening for it - by morning our ration chute had been jimmied and 2/4 Soup was gone." % poi_name
						morale_delta = -1
						tags = ["item_lost", "morale_down"]
				_:
					outcome_text = "Eventually the tapping along the pipe from %s fell quiet." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"osm_hardware_looters":
			match chosen:
				"use_rifle", "use_dog":
					if not GameState.has_working_item("bug_spray"):
						GameState.add_scavenged_item("bug_spray", 1)
					if not GameState.padlock_active:
						GameState.add_scavenged_item("padlock", 1)
						outcome_text = "Spooked stiff, the looters fled %s—leaving behind a %s sack containing Bug Spray and a Heavy Padlock!" % [house_addr, poi_name]
					else:
						GameState.add_scavenged_item("ammo", 1)
						outcome_text = "Spooked stiff, the looters fled %s—leaving behind a %s sack containing Bug Spray and 2 Rifle Ammo!" % [house_addr, poi_name]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"snatch_fast":
					if active_rng.randf() < 0.70:
						GameState.add_scavenged_item("bug_spray", 1)
						outcome_text = "Quick hands! You yanked the %s canvas sack down the hatch and scored a fresh can of Mutant Bug Spray!" % poi_name
						morale_delta = 1
						tags = ["item_gained", "morale_up"]
					else:
						_adjust_member_stat(target_member, "injury", 1)
						outcome_text = "One looter tugged back on the %s strap, scraping %s's knuckles before you slammed the hatch!" % [poi_name, m_name]
						morale_delta = -1
						tags = ["injured", "morale_down"]
				_:
					outcome_text = "The scavengers scooped up their %s sack and vanished into the fog." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"osm_restaurant_aroma":
			match chosen:
				"cook_soup":
					_add_soup_quarters(-2)
					_reduce_family_stress(1)
					target_member["hunger"] = maxi(0, int(target_member.get("hunger", 0)) - 1)
					GameState.family_changed.emit()
					outcome_text = "Inspired by %s, you simmered 2/4 Tomato Soup with a pinch of oregano—tasted like five-star dining!" % poi_name
					morale_delta = 2
					tags = ["morale_up"]
				"use_cards":
					outcome_text = "Fierce competition at the card table distracted everyone until the breeze shifted away from %s." % poi_name
					morale_delta = 1
					tags = ["morale_up"]
				_:
					outcome_text = "Stomachs rumbled symphony-loud all afternoon dreaming of %s takeout." % poi_name
					morale_delta = -1
					tags = ["morale_down"]

		"osm_school_civil_defense_cache":
			match chosen:
				"use_map":
					_add_water_quarters(6)
					outcome_text = "Matching the %s chart to our Map pinpointed the exact auxiliary siphon—yielding 1 + 2/4 bottles of Clean Water!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_toolbox":
					_add_water_quarters(4)
					outcome_text = "Cranking the street auxiliary valve with the Toolbox filled 1 full Water Bottle (+4/4) from the %s reserve!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "Wind eventually peeled the %s Civil Defense chart off our periscope." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"osm_park_mutant_geese":
			match chosen:
				"use_harmonica":
					outcome_text = "HONK-BLUES! Your B-flat Harmonica solo convinced the three-eyed %s geese you were their alpha gander—they flew south in V-formation!" % poi_name
					morale_delta = 2
					tags = ["morale_up"]
				"use_rifle":
					if GameState.ammo_count > 0:
						GameState.break_or_consume_item("ammo")
						_add_soup_quarters(4)
						outcome_text = "BANG! The %s flock scattered skyward, leaving behind enough prime roast ration for +4/4 Soup!" % poi_name
						morale_delta = 2
						tags = ["item_gained", "morale_up"]
					else:
						outcome_text = "Poking the Rifle barrel up the vent pipe startled the %s geese into finding somebody else's roof!" % poi_name
						morale_delta = 1
						tags = ["morale_up"]
				"use_axe":
					outcome_text = "Ringing the vent pipe like a church bell with the flat of the Axe sent the %s geese flapping away indignantly!" % poi_name
					morale_delta = 1
					tags = ["morale_up"]
				_:
					outcome_text = "Six hours of muffled tuba-honking from the %s geese gave everyone a mild headache before they left." % poi_name
					morale_delta = -1
					tags = ["morale_down"]

		"osm_civic_siren_malfunction":
			match chosen:
				"use_radio":
					outcome_text = "Swinging 1950s jazz crackled over the Radio, turning the wailing %s siren into weirdly catchy avant-garde saxophone!" % poi_name
					morale_delta = 1
					tags = ["morale_up"]
				"use_checkers":
					outcome_text = "Intense Checkers concentration tuned out the %s siren until its backup battery finally died at sunset!" % poi_name
					morale_delta = 1
					tags = ["morale_up"]
				_:
					outcome_text = "Fourteen hours of nonstop wailing from %s left everyone grumpy and bleary-eyed." % poi_name
					morale_delta = -1
					tags = ["morale_down"]

		"osm_street_delivery_van":
			match chosen:
				"use_gas_mask":
					_add_water_quarters(8)
					outcome_text = "Protected by the Gas Mask, %s hauled 2 full bottles of Clean Water (+8/4) straight out of the overturned delivery van on %s!" % [m_name, house_addr]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_suitcase":
					_add_water_quarters(6)
					_add_soup_quarters(2)
					outcome_text = "Stuffing the Leather Suitcase to the brim brought back 1 + 2/4 Water plus 2/4 Soup from the driver's lunchbox!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "Playing it cautious, we watched from the periscope until nightfall hid the delivery van."
					morale_delta = 0
					tags = ["neutral"]

		"osm_firefighter_check":
			match chosen:
				"use_flashlight", "use_radio":
					_add_water_quarters(4)
					_add_soup_quarters(4)
					outcome_text = "SIGNAL RECEIVED! The %s Civil Defense warden saluted your periscope and dropped 1 Soup Can & 1 Water Bottle down your ration chute!" % hood
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"bang_hatch":
					_add_water_quarters(4)
					outcome_text = "Hearing your rhythmic knocks on the steel hatch, the warden chalked 'OCCUPIED' and slid 1 bottle of Clean Water (+4/4) inside!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
					if active_rng.randf() < 0.35:
						_add_water_quarters(-4)
						outcome_text = "The knocking carried. It wasn't the warden who answered - a scavenger chalked 'OCCUPIED' himself, then siphoned a full bottle of Water (-4/4) through the vent pipe overnight."
						morale_delta = -1
						tags = ["item_lost", "morale_down"]
				_:
					outcome_text = "Chalking 'NO RESPONSE' on the curb of %s, the warden walked quietly into the mist." % house_addr
					morale_delta = 0
					tags = ["neutral"]

		# ----------------------------------------------------------------------
		# 38-60. ICONIC REATOMIZED QUIRKY, COMPANION & SURVIVAL EVENTS
		# ----------------------------------------------------------------------
		"classic_radioactive_spider":
			match chosen:
				"use_bug_spray":
					if GameState.has_working_item("bug_spray"):
						GameState.break_or_consume_item("bug_spray")
					outcome_text = "PSSHT! One spritz of Mutant Bug Spray sent the glowing arachnid curling into a harmless green marble!"
					morale_delta = 1
					tags = ["item_lost", "morale_up"]
				"use_book":
					outcome_text = "WHAM! Chapter 4 ('Arachnids of North America') flattened the neon intruder on the first swing!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_cat":
					outcome_text = "Sharikov batted the glowing spider off its web like a Christmas ornament and strutted away victorious!"
					morale_delta = 2
					tags = ["companion", "morale_up"]
				"poke_spider":
					if active_rng.randf() < 0.45 and not bool(target_member.get("is_mutant", false)):
						outcome_text = _apply_mutant_transformation(target_member)
						morale_delta = 2
						tags = ["mutant", "morale_up"]
					else:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "CHOMP! Sadly, instead of wall-crawling powers, %s just got a swollen thumb and mild radiation chills!" % m_name
						morale_delta = -1
						tags = ["sick", "morale_down"]
				_:
					outcome_text = "'Boris' spun a neat glowing web over the air vent and actually caught two mosquitoes. Uneasy truce!"
					morale_delta = 0
					tags = ["neutral"]

		"classic_pancake_treasure":
			match chosen:
				"use_toolbox", "use_axe":
					_add_soup_quarters(4)
					GameState.add_scavenged_item("medkit", 1)
					var finder: String = "Pancake" if GameState.has_dog_pancake else m_name
					outcome_text = "TREASURE CACHE! %s's discovery beneath the slab yielded a 1952 Civil Defense tin holding 1 Soup Can and 1 Medkit!" % finder
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					_add_soup_quarters(4)
					outcome_text = "Dusty fingernails paid off—wedged inside the hollow slab sat 1 preserved can of Tomato Soup (+4/4)!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]

		"classic_sharikov_mice":
			match chosen:
				"use_cat":
					outcome_text = "Officer Sharikov pounced with Soviet precision! The field mice surrendered immediately and our soup labels remain pristine."
					morale_delta = 2
					tags = ["companion", "morale_up"]
				"use_bug_spray":
					if GameState.has_working_item("bug_spray"):
						GameState.break_or_consume_item("bug_spray")
					outcome_text = "A perimeter spritz of Bug Spray sent the mice packing with crinkled noses!"
					morale_delta = 1
					tags = ["item_lost", "morale_up"]
				"guard_night":
					_adjust_member_stat(target_member, "fatigue", 1)
					outcome_text = "%s stood broomstick sentry until dawn—exhausting work, but zero rations were lost!" % m_name
					morale_delta = 0
					tags = ["neutral"]
				_:
					var nibbled: int = mini(2, GameState.soup_quarters)
					_add_soup_quarters(-nibbled)
					outcome_text = "Those bold little rodents gnawed into a cardboard ration pack and spoiled %d/4 Soup!" % nibbled
					morale_delta = -1
					tags = ["item_lost", "morale_down"]

		"classic_leaky_water_jug":
			match chosen:
				"use_toolbox":
					outcome_text = "Friction tape and hose clamps from the Toolbox sealed the cracked water jug without losing a single drop!"
					morale_delta = 1
					tags = ["morale_up"]
				"drink_fast":
					var needy: Dictionary = _pick_thirstiest_member(target_member)
					var n_name: String = str(needy.get("name", m_name))
					needy["thirst"] = maxi(0, int(needy.get("thirst", 0)) - 1)
					needy["days_without_water"] = maxi(0, int(needy.get("days_without_water", 0)) - 1)
					var lost_jug: int = mini(1, GameState.water_quarters)
					_add_water_quarters(-lost_jug)
					GameState.family_changed.emit()
					outcome_text = "Waste not, want not! %s chugged the leaking water on the spot, quenching thirst before it hit the floor!" % n_name
					morale_delta = 1
					tags = ["morale_up"]
				_:
					var leaked: int = mini(3, GameState.water_quarters)
					_add_water_quarters(-leaked)
					outcome_text = "Drip by agonizing drip, %d/4 Clean Water soaked into the dusty concrete before the jug emptied." % leaked
					morale_delta = -1
					tags = ["item_lost", "morale_down"]

		"classic_suspicious_soup_can":
			if chosen == "yes":
				var iron_soup: bool = _has_iron_stomach(target_member)
				var soup_sick_chance: float = 0.16 if iron_soup else 0.32
				if active_rng.randf() < (1.0 - soup_sick_chance):
					_add_soup_quarters(4)
					outcome_text = "SWEET VICTORY! 'LOT #1953-X' turned out to be heavy-syrup cling peaches and hearty minestrone (+4/4 Soup)! Delicious!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				else:
					_adjust_member_stat(target_member, "sickness", 1)
					outcome_text = "HISSSSS! Gray pickled herring from the Eisenhower administration! %s took one brave nibble and turned chartreuse." % m_name
					morale_delta = -1
					tags = ["sick", "morale_down"]
			else:
				outcome_text = "Playing food-safety inspector, you launched the bulging 1953 tin out the disposal chute where it popped harmlessly."
				morale_delta = 0
				tags = ["neutral"]

		"classic_cabin_fever_checkers":
			match chosen:
				"use_checkers", "use_cards", "use_harmonica":
					_reduce_family_stress(1)
					outcome_text = "Cheers and applause echoed off the bunker walls! %s crowned three kings in a row and spirits lifted dramatically." % m_name
					morale_delta = 2
					tags = ["morale_up"]
				_:
					outcome_text = "Update: there are actually 413 cinderblocks. Nobody is thrilled by this breakthrough."
					morale_delta = -1
					tags = ["morale_down"]

		"classic_boy_scout_quiz":
			match chosen:
				"use_book":
					_add_water_quarters(2)
					outcome_text = "The Boy Scout Handbook debunked the potato myth—AND reminded us how to reclaim +2/4 clean Water from the dehumidifier tray!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_radio":
					outcome_text = "A CONELRAD public-service bulletin settled the trivia bet cleanly and made everyone chuckle!"
					morale_delta = 1
					tags = ["morale_up"]
				_:
					outcome_text = "%s smugly declared intellectual victory by default, to mild eye-rolling." % m_name
					morale_delta = 0
					tags = ["neutral"]

		"classic_periscope_smudge":
			match chosen:
				"use_gas_mask":
					GameState.add_scavenged_item("ammo", 1)
					outcome_text = "Crystal-clear optics restored! Even better, while wiping the prism in the Gas Mask, %s spotted 2 Rifle Ammo resting on the stoop!" % m_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_water":
					_add_water_quarters(-1)
					outcome_text = "One brisk squirt of 1/4 Water cleared the exterior periscope mirror—visibility over %s is sharp again!" % house_addr
					morale_delta = 1
					tags = ["morale_up"]
				_:
					outcome_text = "Looking through the periscope still resembles staring inside a vacuum cleaner bag."
					morale_delta = -1
					tags = ["morale_down"]

		"classic_strange_fungus":
			match chosen:
				"use_book":
					_add_soup_quarters(4)
					outcome_text = "Guided by the Handbook's mycology chart, you harvested the safe golden caps and simmered +4/4 savory Mushroom Soup!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_bug_spray":
					if GameState.has_working_item("bug_spray"):
						GameState.break_or_consume_item("bug_spray")
					outcome_text = "A quick blast of Bug Spray shriveled the glowing spores before they could spread!"
					morale_delta = 1
					tags = ["item_lost", "morale_up"]
				"taste_raw":
					var iron_fungus: bool = _has_iron_stomach(target_member)
					var roll_f: float = active_rng.randf()
					if roll_f < 0.45:
						_add_soup_quarters(4)
						outcome_text = "Gourmet luck! The turquoise bunker truffles tasted like buttered garlic rolls (+4/4 Soup)!"
						morale_delta = 2
						tags = ["item_gained", "morale_up"]
					elif roll_f < 0.75 and not bool(target_member.get("is_mutant", false)):
						outcome_text = _apply_mutant_transformation(target_member)
						morale_delta = 1
						tags = ["mutant", "morale_up"]
					elif iron_fungus and active_rng.randf() < 0.50:
						var iron_m_f: Dictionary = target_member if str(target_member.get("trait", "")).to_lower() == "iron_stomach" else _get_member_with_trait("iron_stomach")
						var iron_name_f: String = str(iron_m_f.get("name", m_name))
						outcome_text = "%s's Iron Stomach shrugged off the bitter glowing spores without a single hiccup!" % iron_name_f
						morale_delta = 0
						tags = ["neutral"]
					else:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "%s immediately regretted sampling glowing wall flora and spent the afternoon hiccuping green bubbles!" % m_name
						morale_delta = -1
						tags = ["sick", "morale_down"]
				_:
					outcome_text = "Scraped into the disposal bin—no questionable subterranean salad today."
					morale_delta = 0
					tags = ["neutral"]

		"classic_voices_in_pipes":
			match chosen:
				"use_medkit":
					if GameState.has_working_item("medkit"):
						GameState.break_or_consume_item("medkit")
					target_member["sickness"] = 0
					target_member["sanity"] = 0
					GameState.family_changed.emit()
					outcome_text = "A calm dose from the Medkit and eight hours of uninterrupted sleep brought %s right back to sharp form!" % m_name
					morale_delta = 2
					tags = ["healed", "morale_up"]
				"use_cards":
					_reduce_family_stress(1)
					outcome_text = "Friendly banter over Playing Cards pulled %s away from the radiator and back into good humor!" % m_name
					morale_delta = 2
					tags = ["morale_up"]
				_:
					outcome_text = "We all agreed to buy 100 imaginary shares of Canned Tomato Consolidated. Weirdly comforting!"
					morale_delta = 0
					tags = ["neutral"]

		"classic_ammo_press":
			match chosen:
				"use_toolbox":
					GameState.ammo_count += 3
					GameState.inventory_changed.emit()
					outcome_text = "Polishing and crimping the loose brass with the Toolbox added +3 crisp rounds of Rifle Ammo to our locker!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
				"use_flashlight":
					GameState.ammo_count += 2
					GameState.inventory_changed.emit()
					outcome_text = "Inspecting primers under the Flashlight beam salvaged +2 dry rounds of Rifle Ammo!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
				_:
					GameState.ammo_count += 1
					GameState.inventory_changed.emit()
					outcome_text = "Wiping the cleanest cartridge dry on a flannel sleeve salvaged +1 Rifle Ammo."
					morale_delta = 0
					tags = ["item_gained"]

		"classic_red_phone_ringing":
			if chosen == "yes":
				if active_rng.randf() < 0.72:
					_add_soup_quarters(4)
					if int(GameState.rescue_chains.get("military", 0)) == 0:
						GameState.rescue_chains["military"] = 1
						outcome_text = "'CONELRAD TRUNK VERIFIED!' An automated Civil Defense switchboard logged %s for evacuation priority AND unlocked a wall ration cubby (+4/4 Soup, Military Stage 1/3)!" % house_addr
						tags = ["rescue_progress", "item_gained", "morale_up"]
					else:
						_add_water_quarters(4)
						outcome_text = "'SECTOR LINE ACTIVE!' A Civil Defense quartermaster revealed a sealed wall panel right behind the phone (+1 Soup & +1 Water)!"
						tags = ["item_gained", "morale_up"]
					morale_delta = 2
				else:
					outcome_text = "Only a spooky synthesized voice reading numbers in reverse ('SEVEN... ZERO... TUNA...') before the line clicked dead! Nobody slept well afterwards."
					_increase_family_stress_safe(1)
					morale_delta = -1
					tags = ["morale_down"]
			else:
				outcome_text = "After six rings, the buried Cold War landline fell silent again."
				morale_delta = 0
				tags = ["neutral"]

		"classic_wandering_doctor":
			if chosen == "pay_soup" or chosen == "pay_water":
				if chosen == "pay_soup":
					_add_soup_quarters(-2)
				else:
					_add_water_quarters(-2)
				var healed_count: int = _heal_all_family_afflictions()
				if healed_count == 0:
					GameState.add_scavenged_item("medkit", 1)
					outcome_text = "Finding everyone already shipshape, Dr. Stanislaus smiled and left 1 First Aid Medkit for a rainy day!"
				else:
					outcome_text = "MIRACLE HOUSE CALL! Dr. Stanislaus bandaged wounds and administered antibiotics, curing %d afflicted family member(s)!" % healed_count
				morale_delta = 2
				tags = ["healed", "morale_up"]
			else:
				outcome_text = "Dr. Stanislaus tipped his tweed cap politely and continued down %s." % house_addr
				morale_delta = 0
				tags = ["neutral"]

		"classic_raider_extortion_note":
			match chosen:
				"use_rifle":
					GameState.ammo_count += 2
					GameState.inventory_changed.emit()
					outcome_text = "Sighting your Hunting Rifle barrel made the 'Atomic Greasers' trip over their pompadours fleeing—dropping +2 Rifle Ammo!"
					morale_delta = 2
					tags = ["raid", "item_gained", "morale_up"]
				"use_axe":
					outcome_text = "Splitting their switchblade cleanly in half with our Fireman's Axe sent a very clear message—the Greasers didn't come back!"
					morale_delta = 2
					tags = ["raid", "morale_up"]
				"pay_tribute":
					_add_soup_quarters(-4)
					outcome_text = "Grumbling, you slid 1 Soup Can outside. The hoodlums left our air vent untouched and sauntered off."
					morale_delta = -1
					tags = ["raid", "item_lost", "morale_down"]
				_:
					if GameState.padlock_active:
						outcome_text = "They rattled the vent once, saw our gleaming Heavy Padlock, and decided we weren't worth the trouble!"
						morale_delta = 1
						tags = ["raid", "morale_up"]
					elif active_rng.randf() < 0.55:
						outcome_text = "All bark and no crowbar! Calling the Atomic Greasers' bluff worked—nobody showed up."
						morale_delta = 1
						tags = ["raid", "morale_up"]
					else:
						GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 10.0, 10.0, 100.0)
						outcome_text = "At midnight the punks dented our exterior vent hood with a pipe (-10 Shelter Integrity) before slinking away!"
						morale_delta = -1
						tags = ["raid", "morale_down"]

		"classic_suitcase_false_bottom":
			match chosen:
				"use_toolbox":
					_add_soup_quarters(4)
					_add_water_quarters(4)
					if not GameState.has_working_item("cards"):
						GameState.add_scavenged_item("cards", 1)
						outcome_text = "Unscrewing the brass panel cleanly revealed 1 Soup Can, 1 Water Bottle, and a crisp deck of Playing Cards!"
					else:
						outcome_text = "Unscrewing the brass panel cleanly revealed a pre-war stash of 1 Soup Can and 1 Water Bottle!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_axe":
					_add_soup_quarters(4)
					GameState.add_scavenged_item("medkit", 1)
					outcome_text = "CRACK! Splitting the false bottom open revealed 1 Soup Can and 1 First Aid Medkit!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
				_:
					_add_soup_quarters(2)
					outcome_text = "Bending a soup spoon slightly pried out +2/4 Soup tucked inside the lining!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]

		"classic_mutant_night_vision":
			if bool(ctx.get("has_mutant", false)):
				if chosen == "mutant_reach":
					_add_soup_quarters(4)
					_add_water_quarters(4)
					var mn2: String = str(ctx.get("mutant_name", m_name))
					outcome_text = "SUPERHUMAN PERK! %s effortlessly reached into the high duct niche and pulled down 1 Soup Can & 1 Water Bottle!" % mn2
					morale_delta = 2
					tags = ["mutant", "item_gained", "morale_up"]
				else:
					outcome_text = "Everyone slept soundly under the comforting emerald nightlight of our resident mutant."
					morale_delta = 1
					tags = ["morale_up"]
			else:
				match chosen:
					"use_flashlight":
						_add_soup_quarters(2)
						outcome_text = "Just a loose thermal expansion bolt—and shining the Flashlight into the gap revealed a forgotten +2/4 Soup tin!"
						morale_delta = 1
						tags = ["item_gained", "morale_up"]
					"use_harmonica":
						outcome_text = "Playing the second verse on Harmonica made everyone laugh away the midnight jitters!"
						morale_delta = 1
						tags = ["morale_up"]
					_:
						outcome_text = "By dawn the mysterious tapping stopped, though nobody got top-tier sleep."
						morale_delta = 0
						tags = ["neutral"]

		"classic_condensation_still":
			match chosen:
				"use_toolbox":
					_add_water_quarters(4)
					outcome_text = "Engineering genius! Your Toolbox tin-gutter rig harvested 1 full bottle of Clean Water (+4/4) overnight!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_gas_mask":
					_add_water_quarters(3)
					outcome_text = "Filtering the I-beam condensation through activated charcoal yielded +3/4 Clean Water!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
				_:
					_add_water_quarters(1)
					outcome_text = "Patiently balancing a tin cup beneath the beam caught +1/4 Clean Water by morning."
					morale_delta = 0
					tags = ["item_gained"]

		"classic_board_game_feud":
			match chosen:
				"use_flashlight":
					_add_soup_quarters(4)
					outcome_text = "CASE CLOSED! Shining the Flashlight under the bunk found the missing red king—AND a rolled-away can of Tomato Soup (+4/4)!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_cards":
					outcome_text = "Switching to Go Fish restored domestic harmony immediately!"
					morale_delta = 1
					tags = ["morale_up"]
				_:
					outcome_text = "%s found a bottle cap to substitute as king, plus three dust bunnies." % m_name
					morale_delta = 0
					tags = ["neutral"]

		"classic_civil_defense_drop":
			match chosen:
				"use_axe", "use_gas_mask":
					_add_soup_quarters(4)
					_add_water_quarters(4)
					GameState.add_scavenged_item("medkit", 1)
					outcome_text = "AIRDROP SECURED! You hauled the yellow CONELRAD canister inside %s: 1 Soup Can, 1 Water Bottle, and 1 Medkit!" % house_addr
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"tug_lines":
					if active_rng.randf() < 0.65:
						_add_soup_quarters(4)
						outcome_text = "Tugging a tangled shroud cord spilled one packet down the hatch (+4/4 Soup) before wind carried the chute away!"
						morale_delta = 1
						tags = ["item_gained", "morale_up"]
					else:
						_adjust_member_stat(target_member, "injury", 1)
						outcome_text = "A gust snapped the shroud lines taut and the canister swung down hard - %s took it square on the forearm. The chute sailed off empty-handed." % m_name
						morale_delta = -1
						tags = ["injured", "morale_down"]
				_:
					outcome_text = "Playing it ultra-safe, we left the yellow parachute flapping on the roof."
					morale_delta = 0
					tags = ["neutral"]

		"classic_bad_dream_choir":
			match chosen:
				"use_harmonica", "use_radio":
					_reduce_family_stress(1)
					for m_v in _get_present_members():
						var mem: Dictionary = m_v
						mem["fatigue"] = maxi(0, int(mem.get("fatigue", 0)) - 1)
					GameState.family_changed.emit()
					outcome_text = "Soft 1950s melodies banished every giant atomic toaster nightmare—everyone woke refreshed!"
					morale_delta = 2
					tags = ["morale_up"]
				_:
					outcome_text = "Sharing fond memories of neighborhood picnics across %s helped %s drift peacefully back to sleep." % [hood, m_name]
					morale_delta = 1
					tags = ["morale_up"]

		"classic_salesman_vault_insurance":
			match chosen:
				"buy_soup":
					_add_soup_quarters(-2)
					if not GameState.padlock_active:
						GameState.add_scavenged_item("padlock", 1)
						outcome_text = "Read the fine print later—the salesman's 'Complimentary Gift' was a brand-new Heavy Padlock!"
					elif not GameState.has_working_item("map"):
						GameState.add_scavenged_item("map", 1)
						outcome_text = "What a deal! Along with your gold-embossed policy, he handed over an official Civil Defense Map!"
					else:
						GameState.add_scavenged_item("medkit", 1)
						outcome_text = "Pleasure doing megaton business! Your promotional gift box contained 1 First Aid Medkit!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"listen_pitch":
					_add_water_quarters(2)
					outcome_text = "Sitting through 45 minutes of actuarial tables earned a free promotional canteen sample (+2/4 Clean Water)!"
					morale_delta = 0
					tags = ["item_gained"]
				_:
					outcome_text = "Undeterred by nuclear war or closed shutters, the salesman tipped his bowler hat and strolled cheerily down %s." % house_addr
					morale_delta = 1
					tags = ["morale_up"]

		"classic_splinter_first_aid":
			match chosen:
				"use_medkit":
					if GameState.has_working_item("medkit"):
						GameState.break_or_consume_item("medkit")
					target_member["injury"] = 0
					GameState.family_changed.emit()
					outcome_text = "Prompt iodine and sterile gauze from the Medkit kept %s completely infection-free!" % m_name
					morale_delta = 1
					tags = ["healed", "morale_up"]
				"use_toolbox":
					outcome_text = "Filing the jagged steel rivet smooth with the Toolbox made the ladder safe for everyone, leaving %s with only a tiny scratch!" % m_name
					morale_delta = 1
					tags = ["morale_up"]
				_:
					if str(target_member.get("trait", "")).to_lower() == "iron_stomach" or bool(target_member.get("is_mutant", false)):
						outcome_text = "Built with an iron constitution, %s barely blinked—in fact, the steel rivet bent instead!" % m_name
						morale_delta = 1
						tags = ["morale_up"]
					else:
						_adjust_member_stat(target_member, "injury", 1)
						outcome_text = "Without antiseptic or filing, %s ended up limping with a painful shin gash!" % m_name
						morale_delta = -1
						tags = ["injured", "morale_down"]

		"classic_radio_quiz_show":
			match chosen:
				"use_radio":
					_add_water_quarters(4)
					outcome_text = "'LINCOLN, NEBRASKA!' Tuning DJ Atomic Al's bonus clue led straight to a storm-drain stash right beneath %s (+4/4 Clean Water)!" % house_addr
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_map":
					_add_soup_quarters(4)
					outcome_text = "Plotting DJ Atomic Al's bowling-alley landmarks on our Map uncovered a curbside Civil Defense cache (+4/4 Soup)!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "Even through muffled pipes, snapping fingers to 1950s rockabilly brightened the bunker mood!"
					morale_delta = 1
					tags = ["morale_up"]

		# ----------------------------------------------------------------------
		# 61-63. V2 PILLAR 1: WASTELAND SMUGGLER CONVOY ESCAPE CHAIN
		# ----------------------------------------------------------------------
		"rescue_raider_pact_1":
			match chosen:
				"use_radio":
					GameState.rescue_chains["raider_pact"] = maxi(1, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "'BREAKER-BREAKER, COPY THAT!' Convoy Captain Vance logged %s on his laminated highway truce chart! 'Keep your ears on, bunker folks—our mechanics roll back through %s soon!' (Smuggler Convoy: Stage 1/3)" % [house_addr, hood]
					morale_delta = 2
					tags = ["rescue_progress", "morale_up"]
				"give_ammo":
					GameState.ammo_count = maxi(0, GameState.ammo_count - 2)
					GameState.inventory_changed.emit()
					GameState.rescue_chains["raider_pact"] = maxi(1, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "Sliding 2 gleaming brass cartridges out the chute earned a two-finger salute from the Chrome Caravaneers outrider! A convoy truce emblem now marks %s! (Smuggler Convoy: Stage 1/3)" % house_addr
					morale_delta = 2
					tags = ["rescue_progress", "item_lost", "morale_up"]
				"give_soup":
					_add_soup_quarters(-4)
					GameState.rescue_chains["raider_pact"] = maxi(1, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "Passing up 1 full can of Tomato Soup won instant roadhouse goodwill—the convoy outrider chalked a safe-conduct wheel onto the curb of %s! (Smuggler Convoy: Stage 1/3)" % house_addr
					morale_delta = 2
					tags = ["rescue_progress", "item_lost", "morale_up"]
				"use_harmonica":
					GameState.rescue_chains["raider_pact"] = maxi(1, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "HONK-WAIL! Your gritty 12-bar Harmonica blues echoed out the vent pipe and got an air-horn ovation from the semi-rigs! You are officially friends of the road! (Smuggler Convoy: Stage 1/3)"
					morale_delta = 2
					tags = ["rescue_progress", "morale_up"]
				"flash_mirror":
					if active_rng.randf() < 0.48:
						GameState.rescue_chains["raider_pact"] = maxi(1, int(GameState.rescue_chains.get("raider_pact", 0)))
						outcome_text = "A sharp-eyed tail-gunner caught your periscope mirror flashes cutting through the haze and blinked two amber clearance lights back! (Smuggler Convoy: Stage 1/3)"
						morale_delta = 1
						tags = ["rescue_progress", "morale_up"]
					else:
						outcome_text = "Thick ash clouds swallowed your mirror flashes before the diesel column rumbled out of earshot."
						morale_delta = 0
						tags = ["neutral"]
						if active_rng.randf() < 0.45:
							GameState.story_flags["vendetta_active"] = true
							GameState.story_flags["vendetta_day"] = GameState.day
							outcome_text = "Someone saw the mirror flashes - just not the convoy. A rival scavenger crew now knows a shelter sits under %s." % house_addr
							morale_delta = -1
							tags = ["morale_down"]
				_:
					outcome_text = "Keeping our heads down, we let the rumbling smuggler rigs roll on past %s." % hood
					morale_delta = 0
					tags = ["neutral"]

		"rescue_raider_pact_2":
			match chosen:
				"give_fuel":
					if GameState.has_working_item("fuel"):
						GameState.break_or_consume_item("fuel")
					_add_soup_quarters(4)
					GameState.rescue_chains["raider_pact"] = maxi(2, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "Grease-Gun Greta poured your Gasoline Jerrycan into the wrecker tank, roared the diesel back to life, and tossed down 1 Soup Can (+4/4): 'Pack light—our armored war-rig swings back for your crew!' (Smuggler Convoy: Stage 2/3)"
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"use_scrap":
					if GameState.has_working_item("scrap"):
						GameState.break_or_consume_item("scrap")
					_add_water_quarters(4)
					GameState.rescue_chains["raider_pact"] = maxi(2, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "Your Salvaged Scrap clamped their blown turbo hose drum-tight! Grateful, Greta slid 1 bottle of Clean Water (+4/4) down the chute and reserved sleeper bunks for our household! (Smuggler Convoy: Stage 2/3)"
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"use_antibiotics":
					if GameState.has_working_item("antibiotics"):
						GameState.break_or_consume_item("antibiotics")
					GameState.ammo_count += 2
					GameState.inventory_changed.emit()
					GameState.rescue_chains["raider_pact"] = maxi(2, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "Your Prescription Antibiotics saved the convoy's lead driver from shrapnel fever! Greta swore a highway blood-oath to extract us—and left +2 Rifle Ammo as earnest money! (Smuggler Convoy: Stage 2/3)"
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"use_medkit":
					if GameState.has_working_item("medkit"):
						GameState.break_or_consume_item("medkit")
					GameState.rescue_chains["raider_pact"] = maxi(2, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "Bandaging the wounded convoy outriders with our Medkit sealed an ironclad alliance with the Chrome Caravaneers! (Smuggler Convoy: Stage 2/3)"
					morale_delta = 2
					tags = ["rescue_progress", "item_lost", "morale_up"]
				"use_toolbox":
					_add_soup_quarters(2)
					GameState.rescue_chains["raider_pact"] = maxi(2, int(GameState.rescue_chains.get("raider_pact", 0)))
					outcome_text = "Loaning socket wrenches from our Toolbox let Greta torque the manifold in five minutes flat—returning every tool spotless plus +2/4 hot Soup! (Smuggler Convoy: Stage 2/3)"
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"push_rig":
					_adjust_member_stat(target_member, "fatigue", 1)
					if active_rng.randf() < 0.72:
						GameState.rescue_chains["raider_pact"] = maxi(2, int(GameState.rescue_chains.get("raider_pact", 0)))
						outcome_text = "Heaving shoulder-to-fender in the alley, %s helped bump-start the convoy wrecker! Greta flashed thumbs-up: 'Wait for our twin air-horns!' (Smuggler Convoy: Stage 2/3)" % m_name
						morale_delta = 1
						tags = ["rescue_progress", "morale_up"]
					else:
						outcome_text = "Slick fallout mud spun the tires until the crew winched off a lamppost instead, leaving %s winded but unharmed." % m_name
						morale_delta = 0
						tags = ["neutral"]
				_:
					outcome_text = "We stayed bolted underground until the convoy wrecker clanked back toward the highway."
					morale_delta = 0
					tags = ["neutral"]

		"rescue_raider_pact_3":
			if chosen == "yes":
				GameState.rescue_chains["raider_pact"] = 3
				GameState.victory = true
				GameState.game_over = true
				GameState.ending_route = "raider_pact"
				GameState.ending_title = "VICTORY: Wasteland Smuggler Convoy!"
				GameState.ending_description = "On Day %d, your family climbed out from beneath %s and into the armored sleeper cab of the Chrome Caravaneers! Thundering past the ruins of %s behind welded snowplows and roaring twin diesels, you rode the Smuggler's Highway out of the fallout zone to coastal freedom!" % [GameState.day, house_addr, hood]
				GameState.unlock_achievement("convoy_pact")
				outcome_text = "AIR-HORNS ROAR ACROSS %s! Grease-Gun Greta hauls your family aboard the armored 18-wheeler war-rig, drops the snowplow, and blasts out of %s toward open coastal skies! VICTORY: Wasteland Smuggler Convoy!" % [hood.to_upper(), house_addr]
				morale_delta = 3
				tags = ["victory", "rescue_progress", "morale_up"]
			else:
				GameState.rescue_chains["raider_pact"] = 1
				outcome_text = "Greta shrugged from the cab window, double-clutched into gear, and rumbled down %s without us." % house_addr
				morale_delta = -1
				tags = ["morale_down"]

		# ----------------------------------------------------------------------
		# 64-68. V2 PILLAR 2: STATION WAGON GARAGE & VEHICLE ESCAPE EVENTS
		# ----------------------------------------------------------------------
		"vehicle_garage_discovery":
			match chosen:
				"use_toolbox":
					var p_tb: String = _grant_missing_vehicle_part_or_scrap([])
					GameState.add_scavenged_item("scrap", 1)
					outcome_text = "MECHANIC'S JACKPOT! With the Toolbox, you cleanly unbolted a %s from the 1957 Country Squire plus +1 Salvaged Scrap!" % _get_pretty_part_name(p_tb)
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_flashlight":
					var p_fl: String = _grant_missing_vehicle_part_or_scrap([])
					outcome_text = "Sweeping the Flashlight beam under the collapsed rafters revealed a factory-boxed %s in the Country Squire's spare wheel well!" % _get_pretty_part_name(p_fl)
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"cooperate_pry":
					var p_co: String = _grant_missing_vehicle_part_or_scrap([])
					_change_all_bunker_relationships(6)
					outcome_text = "TEAMWORK TRIUMPH! Heaving together lifted the jammed garage beam without denting a single tool, recovering a %s (+6 Family Bond)!" % _get_pretty_part_name(p_co)
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					_adjust_member_stat(target_member, "fatigue", 1)
					if active_rng.randf() < 0.68:
						var p_hand: String = _grant_missing_vehicle_part_or_scrap([])
						outcome_text = "With scraped knuckles and grease on their nose, %s wriggled out from under the Country Squire clutching a %s!" % [m_name, _get_pretty_part_name(p_hand)]
						morale_delta = 1
						tags = ["item_gained", "morale_up"]
					else:
						GameState.add_scavenged_item("scrap", 1)
						outcome_text = "The hood latch stayed rusted shut, though %s pried loose +1 Salvaged Scrap from the bumper!" % m_name
						morale_delta = 0
						tags = ["item_gained"]

		"vehicle_siphon_derelict":
			match chosen:
				"use_gas_mask":
					GameState.add_scavenged_item("fuel", 1)
					GameState.add_scavenged_item("scrap", 1)
					outcome_text = "Breathing easy through the Gas Mask, %s siphoned +1 full Gasoline Jerrycan and stripped +1 Scrap from the derelict sedan!" % m_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_axe":
					GameState.add_scavenged_item("fuel", 1)
					outcome_text = "CLANG! Popping the locking fuel cap with the Axe let us drain +1 Gasoline Jerrycan toward our Station Wagon escape!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"mouth_siphon":
					GameState.add_scavenged_item("fuel", 1)
					if _has_iron_stomach(target_member) or bool(target_member.get("is_mutant", false)) or active_rng.randf() < 0.55:
						outcome_text = "Ptooey! %s spat out a drop of 1956 leaded premium, but successfully filled +1 Gasoline Jerrycan!" % m_name
						morale_delta = 1
						tags = ["item_gained", "morale_up"]
					else:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "%s filled +1 Gasoline Jerrycan, though inhaling 98-octane fumes left them green around the gills!" % m_name
						morale_delta = 0
						tags = ["item_gained", "sick"]
				_:
					outcome_text = "Playing it safe, we left the derelict municipal sedan parked in the ash."
					morale_delta = 0
					tags = ["neutral"]

		"vehicle_engine_tuneup":
			match chosen:
				"use_toolbox", "use_book", "use_handy":
					GameState.vehicle_tuned = true
					GameState.inventory_changed.emit()
					var tuner_label: String = str(ctx.get("handy_name", m_name)) if chosen == "use_handy" else ("Precision Toolbox gauges" if chosen == "use_toolbox" else "Illustrated Handbook specs")
					outcome_text = "PURRS LIKE DETROIT THUNDER! %s dialed in the Station Wagon's carburetor and ignition timing (Vehicle Tuned = READY)!" % tuner_label
					morale_delta = 2
					tags = ["morale_up"]
				"use_scrap":
					if GameState.has_working_item("scrap"):
						GameState.break_or_consume_item("scrap")
					GameState.vehicle_tuned = true
					GameState.inventory_changed.emit()
					outcome_text = "Punching custom copper-shim gaskets out of Salvaged Scrap sealed the intake manifold—our Station Wagon V8 is officially tuned!"
					morale_delta = 2
					tags = ["item_lost", "morale_up"]
				"cooperate_tune":
					GameState.vehicle_tuned = true
					_change_all_bunker_relationships(6)
					GameState.inventory_changed.emit()
					outcome_text = "One survivor feathered the throttle while their partner strobed the distributor—Station Wagon V8 tuned to perfection (+6 Bond)!"
					morale_delta = 2
					tags = ["morale_up"]
				_:
					if active_rng.randf() < 0.42:
						GameState.vehicle_tuned = true
						GameState.inventory_changed.emit()
						outcome_text = "Beginner's luck! Quarter-turning the brass idle screws smoothed out the V8 rumble—Vehicle Tuned!"
						morale_delta = 1
						tags = ["morale_up"]
					else:
						_adjust_member_stat(target_member, "fatigue", 1)
						outcome_text = "POW-COUGH! The carburetor backfired a soot cloud into %s's eyebrows—still needs a proper tune-up." % m_name
						morale_delta = 0
						tags = ["neutral"]

		"vehicle_armored_bumper":
			match chosen:
				"trade_soup_part":
					_add_soup_quarters(-4)
					var got_p1: String = _grant_missing_vehicle_part_or_fuel(["alternator", "spark_plugs"])
					outcome_text = "FAIR HIGHWAY TRADE! For 1 Soup Can, the Nomad Mechanic handed down a bench-tested %s!" % _get_pretty_part_name(got_p1)
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"trade_ammo_part":
					GameState.ammo_count = maxi(0, GameState.ammo_count - 2)
					GameState.inventory_changed.emit()
					var got_p2: String = _grant_missing_vehicle_part_or_fuel(["spark_plugs", "alternator"])
					outcome_text = "DEAL SEALED! Trading 2 Rifle Ammo scored us a scarce %s from the Nomad Mechanic's dolly!" % _get_pretty_part_name(got_p2)
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"weld_scrap":
					if GameState.has_working_item("scrap"):
						GameState.break_or_consume_item("scrap")
					GameState.vehicle_tuned = true
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 12.0, 0.0, 100.0)
					GameState.inventory_changed.emit()
					outcome_text = "SPARKS FLY! Welding our Scrap forged a debris-smashing bumper AND reinforced our shelter hatch (+12 Integrity, Vehicle Tuned)!"
					morale_delta = 2
					tags = ["morale_up"]
				"use_toolbox":
					GameState.vehicle_tuned = true
					GameState.add_scavenged_item("scrap", 1)
					outcome_text = "Trading ignition tricks over our Toolbox tuned the Station Wagon chassis and netted +1 bonus Scrap!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "You exchanged friendly road salutes as the Nomad Mechanic wheeled onward through %s." % hood
					morale_delta = 0
					tags = ["neutral"]

		"vehicle_nomad_parts_swap":
			match chosen:
				"swap_water":
					_add_water_quarters(-4)
					var sal_p1: String = _grant_missing_vehicle_part_or_fuel([])
					outcome_text = "Refreshing his canteen with 1 Clean Water, Sparkplug Sal passed down a greased %s!" % _get_pretty_part_name(sal_p1)
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"swap_medkit":
					if GameState.has_working_item("medkit"):
						GameState.break_or_consume_item("medkit")
					var sal_p2: String = _grant_missing_vehicle_part_or_scrap([])
					GameState.add_scavenged_item("fuel", 1)
					outcome_text = "Overjoyed to get a First Aid Medkit, Sparkplug Sal traded BOTH a %s AND +1 Gasoline Jerrycan!" % _get_pretty_part_name(sal_p2)
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"swap_cards":
					_remove_durable_item("cards")
					GameState.add_scavenged_item("fuel", 1)
					outcome_text = "Sal tucked the Playing Cards into his coveralls and lowered +1 full Gasoline Jerrycan down our hatch!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "Sparkplug Sal tipped his grease-stained cap and jingled down %s." % house_addr
					morale_delta = 0
					tags = ["neutral"]

		# ----------------------------------------------------------------------
		# 69-81. V2 PILLAR 3: DEEP FAMILY RELATIONSHIPS, GUILT & [COOPERATE]
		# ----------------------------------------------------------------------
		"family_haunted_unrescued":
			var lost_nm: String = str(ctx.get("lost_name", _get_left_behind_name(active_rng)))
			var lead_m: Dictionary = _find_member_by_id_or_random(str(ctx.get("leader_id", "")), active_rng)
			var lead_nm: String = str(lead_m.get("name", str(ctx.get("leader_name", m_name))))
			match chosen:
				"leader_apologize":
					_change_all_bunker_relationships(15)
					for m_v in _get_present_members():
						var mem_g: Dictionary = m_v
						if str(mem_g.get("id", "")) != str(lead_m.get("id", "")):
							mem_g["sanity"] = maxi(0, int(mem_g.get("sanity", 0)) - 1)
					_adjust_member_stat(lead_m, "sanity", 1)
					outcome_text = "Voice cracking, %s apologized openly for failing to get %s down the hatch in time. Tears flowed, shoulders met, and deep bitterness began healing (+15 Family Bond, %s carries the grief)." % [lead_nm, lost_nm, lead_nm]
					morale_delta = 1
					tags = ["morale_up"]
				"use_harmonica":
					_change_all_bunker_relationships(12)
					_reduce_family_stress(1)
					outcome_text = "A soft, aching Harmonica hymn in memory of %s brought quiet unity beneath %s (+12 Family Bond)." % [lost_nm, house_addr]
					morale_delta = 2
					tags = ["morale_up"]
				_:
					_change_all_bunker_relationships(-15)
					outcome_text = "Snapping that nobody is allowed to speak %s's name froze the room into cold, simmering resentment (-15 Family Resentment)." % lost_nm
					morale_delta = -2
					tags = ["morale_down"]

		"family_phantom_knock_guilt":
			var lost_nm2: String = str(ctx.get("lost_name", _get_left_behind_name(active_rng)))
			match chosen:
				"cooperate_hold":
					_change_all_bunker_relationships(10)
					_reduce_family_stress(1)
					outcome_text = "Wrapped in steady arms by devoted kin, %s wept until the wind subsided, keeping the hatch sealed and everyone closer (+10 Bond)." % m_name
					morale_delta = 2
					tags = ["morale_up"]
				"use_radio":
					_change_all_bunker_relationships(8)
					target_member["sanity"] = maxi(0, int(target_member.get("sanity", 0)) - 1)
					GameState.family_changed.emit()
					outcome_text = "Showing the empty porch in the periscope and playing warm Radio static gently eased %s's grief over %s (+8 Bond)." % [m_name, lost_nm2]
					morale_delta = 1
					tags = ["morale_up"]
				_:
					_change_all_bunker_relationships(-12)
					outcome_text = "Yanking %s away from the ladder kept the seal intact, but harsh words left raw hurt (-12 Resentment)." % m_name
					morale_delta = -1
					tags = ["morale_down"]

		"family_ration_accusation":
			var ida_ra: String = str(ctx.get("pair_a_id", ""))
			var idb_ra: String = str(ctx.get("pair_b_id", ""))
			var na_r: String = str(ctx.get("pair_a_name", m_name))
			var nb_r: String = str(ctx.get("pair_b_name", "Dolores"))
			match chosen:
				"cooperate_audit":
					_change_all_bunker_relationships(10)
					_reduce_family_stress(1)
					outcome_text = "Walking calmly through the chalk ration tally together proved every quarter-can accounted for—turning suspicion into trust (+10 Bond)!"
					morale_delta = 2
					tags = ["morale_up"]
				"share_extra":
					_add_soup_quarters(-1)
					_change_pair_relationship(ida_ra, idb_ra, 12)
					outcome_text = "Splitting 1/4 warm Tomato Soup between %s and %s melted the pantry standoff into sheepish grins (+12 Bond)!" % [na_r, nb_r]
					morale_delta = 1
					tags = ["morale_up"]
				"use_book":
					_change_pair_relationship(ida_ra, idb_ra, 8)
					outcome_text = "Posting the Handbook's official Civil Defense quartermaster chart satisfied both %s and %s (+8 Bond)!" % [na_r, nb_r]
					morale_delta = 1
					tags = ["morale_up"]
				_:
					_change_pair_relationship(ida_ra, idb_ra, -12)
					outcome_text = "%s and %s glared daggers across the soup shelf all night (-12 Resentment)." % [na_r, nb_r]
					morale_delta = -1
					tags = ["morale_down"]

		"family_generation_clash":
			var ida_gc: String = str(ctx.get("pair_a_id", ""))
			var idb_gc: String = str(ctx.get("pair_b_id", ""))
			var na_g: String = str(ctx.get("pair_a_name", m_name))
			var nb_g: String = str(ctx.get("pair_b_name", "Mary Jane"))
			match chosen:
				"use_checkers", "use_cards":
					_change_pair_relationship(ida_gc, idb_gc, 14)
					_reduce_family_stress(1)
					outcome_text = "Friendly tabletop rivalry turned %s and %s from bickering critics into laughing teammates (+14 Bond)!" % [na_g, nb_g]
					morale_delta = 2
					tags = ["morale_up"]
				"cooperate_mediate":
					_change_all_bunker_relationships(10)
					outcome_text = "Calm household mediation forged a fair chore schedule that respected everyone's space (+10 Bond)!"
					morale_delta = 1
					tags = ["morale_up"]
				_:
					_change_pair_relationship(ida_gc, idb_gc, -12)
					outcome_text = "Doors can't slam in a one-room bunker, so %s and %s aggressively rattled tin cups instead (-12 Resentment)." % [na_g, nb_g]
					morale_delta = -1
					tags = ["morale_down"]

		"family_midnight_card_tournament":
			match chosen:
				"use_cards", "use_harmonica":
					_change_all_bunker_relationships(14)
					_reduce_family_stress(1)
					outcome_text = "Laughter and late-night camaraderie beneath %s wove the whole family closer together (+14 Family Bond)!" % house_addr
					morale_delta = 2
					tags = ["morale_up"]
				"toast_water":
					_add_water_quarters(-1)
					_change_all_bunker_relationships(12)
					outcome_text = "Clinking tin mugs with 1/4 Clean Water ('To %s!') warmed every heart in the shelter (+12 Family Bond)!" % hood
					morale_delta = 2
					tags = ["morale_up"]
				_:
					_change_all_bunker_relationships(7)
					outcome_text = "Trading funny pre-war stories into the small hours reminded everyone why survival matters (+7 Family Bond)."
					morale_delta = 1
					tags = ["morale_up"]

		"family_shared_coat_freeze":
			var ida_sc: String = str(ctx.get("pair_a_id", ""))
			var idb_sc: String = str(ctx.get("pair_b_id", ""))
			var na_s: String = str(ctx.get("pair_a_name", m_name))
			var nb_s: String = str(ctx.get("pair_b_name", "Timmy"))
			match chosen:
				"cooperate_huddle":
					_change_pair_relationship(ida_sc, idb_sc, 14)
					GameState.bunker_temp_c = clampf(GameState.bunker_temp_c + 1.5, -15.0, 35.0)
					_reduce_family_stress(1)
					outcome_text = "Shoulders tucked beneath the heavy wool coat, %s and %s shared warmth through the frost (+14 Bond)!" % [na_s, nb_s]
					morale_delta = 2
					tags = ["morale_up"]
				"heat_soup":
					_add_soup_quarters(-1)
					_change_all_bunker_relationships(10)
					outcome_text = "Steaming mugs from 1/4 Tomato Soup chased the chill right out of everyone's bones (+10 Bond)!"
					morale_delta = 2
					tags = ["morale_up"]
				"give_coat":
					_change_pair_relationship(ida_sc, idb_sc, 8)
					var mb_mem: Dictionary = _find_member_by_id_or_random(idb_sc, active_rng)
					_adjust_member_stat(mb_mem, "fatigue", 1)
					outcome_text = "Giving the dry overcoat to %s earned heartfelt gratitude (+8 Bond), though %s shivered through a restless night." % [na_s, nb_s]
					morale_delta = 1
					tags = ["morale_up"]
				_:
					_change_pair_relationship(ida_sc, idb_sc, -14)
					outcome_text = "Tugging the wool coat back and forth all night left both %s and %s cold and resentful (-14 Resentment)!" % [na_s, nb_s]
					morale_delta = -1
					tags = ["morale_down"]

		"family_breakdown_intervention":
			match chosen:
				"cooperate_soothe":
					target_member["sanity"] = maxi(0, int(target_member.get("sanity", 0)) - 2)
					target_member["breakdown_days"] = 0
					target_member["status_note"] = "Steadied by devoted family support."
					GameState.family_changed.emit()
					_change_all_bunker_relationships(12)
					outcome_text = "Gentle voices and steady hands pulled %s back from the brink of breakdown without spending a single supply (+12 Bond)!" % m_name
					morale_delta = 2
					tags = ["healed", "morale_up"]
				"use_medkit":
					if GameState.has_working_item("medkit"):
						GameState.break_or_consume_item("medkit")
					target_member["sanity"] = maxi(0, int(target_member.get("sanity", 0)) - 2)
					target_member["breakdown_days"] = 0
					GameState.family_changed.emit()
					_change_all_bunker_relationships(6)
					outcome_text = "A cool compress and calming draught from the Medkit steadied %s's breathing and cleared the panic!" % m_name
					morale_delta = 2
					tags = ["healed", "morale_up"]
				"use_pet":
					target_member["sanity"] = maxi(0, int(target_member.get("sanity", 0)) - 1)
					target_member["breakdown_days"] = 0
					GameState.family_changed.emit()
					_change_all_bunker_relationships(8)
					var pet_nm: String = "Pancake" if GameState.has_dog_pancake else "Sharikov"
					outcome_text = "%s curled warmly in %s's lap until the trembling subsided into peaceful rest (+8 Bond)!" % [pet_nm, m_name]
					morale_delta = 2
					tags = ["companion", "morale_up"]
				_:
					_change_all_bunker_relationships(-10)
					outcome_text = "Telling %s to 'just tough it out' stopped the shouting, but deepened the emotional rift underground (-10 Resentment)." % m_name
					morale_delta = -1
					tags = ["morale_down"]

		"family_quiet_apology":
			var ida_qa: String = str(ctx.get("pair_a_id", ""))
			var idb_qa: String = str(ctx.get("pair_b_id", ""))
			var na_q: String = str(ctx.get("pair_a_name", m_name))
			var nb_q: String = str(ctx.get("pair_b_name", "Dolores"))
			match chosen:
				"celebrate_soup":
					_add_soup_quarters(-2)
					_change_pair_relationship(ida_qa, idb_qa, 22)
					_reduce_family_stress(1)
					outcome_text = "Breaking bread—or rather 2/4 hot Tomato Soup—turned %s and %s's awkward truce into genuine warmth (+22 Bond)!" % [na_q, nb_q]
					morale_delta = 2
					tags = ["morale_up"]
				"encourage_truce":
					if active_rng.randf() < 0.55:
						_change_pair_relationship(ida_qa, idb_qa, 16)
						_reduce_family_stress(1)
						outcome_text = "%s accepted the polished tin mug with a nod, healing old friction with %s (+16 Bond)!" % [nb_q, na_q]
						morale_delta = 2
						tags = ["morale_up"]
					else:
						_change_pair_relationship(ida_qa, idb_qa, -6)
						outcome_text = "Being pushed into it made %s bristle. The mug sat untouched on the crate between them all night." % nb_q
						morale_delta = -1
						tags = ["morale_down"]
				_:
					_change_pair_relationship(ida_qa, idb_qa, -12)
					outcome_text = "Rehashing last week's grievances spoiled the olive branch instantly (-12 Resentment)."
					morale_delta = -1
					tags = ["morale_down"]

		"family_cooperate_pipe_burst":
			match chosen:
				"cooperate_brace":
					_add_water_quarters(3)
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 5.0, 0.0, 100.0)
					_change_all_bunker_relationships(8)
					outcome_text = "TEXTBOOK COOPERATION! Holding the bucking pipe together let you crimp the collar with zero tool wear AND catch +3/4 Clean Water (+5 Integrity, +8 Bond)!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_toolbox":
					_add_water_quarters(2)
					if active_rng.randf() < 0.15 and GameState.has_working_item("toolbox"):
						GameState.break_or_consume_item("toolbox")
						outcome_text = "Wrestling the pressurized collar solo saved +2/4 Water, though the pipe wrench slipped and bent a hinge! (Toolbox needs repair)"
						morale_delta = 0
						tags = ["item_gained", "item_broken"]
					else:
						outcome_text = "Solo grit with the Toolbox sealed the galvanized coupling and salvaged +2/4 Clean Water!"
						morale_delta = 1
						tags = ["item_gained", "morale_up"]
				"use_scrap":
					if GameState.has_working_item("scrap"):
						GameState.break_or_consume_item("scrap")
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 5.0, 0.0, 100.0)
					outcome_text = "Peening a Salvaged Scrap sleeve around the burst seam stopped the spray cold (+5 Integrity)!"
					morale_delta = 1
					tags = ["morale_up"]
				_:
					var lost_pb: int = mini(2, GameState.water_quarters)
					_add_water_quarters(-lost_pb)
					_adjust_member_stat(target_member, "fatigue", 1)
					outcome_text = "Soaked to the elbows, %s finally knotted rags over the joint after losing %d/4 Water pressure." % [m_name, lost_pb]
					morale_delta = -1
					tags = ["item_lost", "morale_down"]

		"family_cooperate_hatch_brace":
			match chosen:
				"cooperate_dogs":
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 10.0, 0.0, 100.0)
					_change_all_bunker_relationships(10)
					outcome_text = "SHOULDER TO SHOULDER! Devoted teamwork slammed the blast hatch dogs home without chipping a single tool (+10 Integrity, +10 Bond)!"
					morale_delta = 2
					tags = ["morale_up"]
				"use_scrap":
					if GameState.has_working_item("scrap"):
						GameState.break_or_consume_item("scrap")
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 12.0, 0.0, 100.0)
					outcome_text = "Hammering Salvaged Scrap shims behind the hatch dogs reinforced our seal stronger than factory spec (+12 Integrity)!"
					morale_delta = 2
					tags = ["morale_up"]
				"use_axe":
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 4.0, 0.0, 100.0)
					if active_rng.randf() < 0.18 and GameState.has_working_item("axe"):
						GameState.break_or_consume_item("axe")
						outcome_text = "Levering the hatch shut with the Axe saved the seal (+4 Integrity), though the hickory handle cracked! (Axe broken)"
						morale_delta = 0
						tags = ["item_broken"]
					else:
						outcome_text = "Prying with the Fireman's Axe snapped the heavy hatch pins back into lock (+4 Integrity)!"
						morale_delta = 1
						tags = ["morale_up"]
				_:
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 6.0, 10.0, 100.0)
					if active_rng.randf() < 0.35:
						_adjust_member_stat(target_member, "injury", 1)
						outcome_text = "Straining solo against shifting rubble bruised %s's ribs and warped the rim (-6 Integrity)!" % m_name
						morale_delta = -1
						tags = ["injured", "morale_down"]
					else:
						outcome_text = "%s barely muscled the hatch pin shut after dust rattled loose (-6 Integrity)." % m_name
						morale_delta = 0
						tags = ["neutral"]

		"family_secret_diary_feud":
			var ida_sd: String = str(ctx.get("pair_a_id", ""))
			var idb_sd: String = str(ctx.get("pair_b_id", ""))
			var na_sd2: String = str(ctx.get("pair_a_name", m_name))
			var nb_sd2: String = str(ctx.get("pair_b_name", "Ted"))
			match chosen:
				"cooperate_chronicle":
					_change_all_bunker_relationships(14)
					_reduce_family_stress(1)
					outcome_text = "Turning the snarky notes into an illustrated family chronicle had everyone adding doodles and laughing till tears ran (+14 Bond)!"
					morale_delta = 2
					tags = ["morale_up"]
				"use_book":
					_change_pair_relationship(ida_sd, idb_sd, 10)
					outcome_text = "Binding the pages into the Survival Handbook as 'Official Anthropological Notes' diffused %s and %s's feud (+10 Bond)!" % [na_sd2, nb_sd2]
					morale_delta = 1
					tags = ["morale_up"]
				"laugh_roast":
					if active_rng.randf() < 0.65:
						_change_all_bunker_relationships(10)
						_reduce_family_stress(1)
						outcome_text = "Admitting that %s really DOES snore like a chainsaw broke the tension in a roar of bunker laughter (+10 Bond)!" % na_sd2
						morale_delta = 2
						tags = ["morale_up"]
					else:
						_change_pair_relationship(ida_sd, idb_sd, -10)
						outcome_text = "Halfway through page two, someone took the snoring score personally (-10 Resentment)!"
						morale_delta = -1
						tags = ["morale_down"]
				_:
					_change_pair_relationship(ida_sd, idb_sd, -14)
					outcome_text = "Confiscating %s's journal sparked sulking silence across the shelter (-14 Resentment)." % nb_sd2
					morale_delta = -1
					tags = ["morale_down"]

		"family_expedition_jealousy":
			var ida_ej: String = str(ctx.get("pair_a_id", ""))
			var idb_ej: String = str(ctx.get("pair_b_id", ""))
			var na_ej2: String = str(ctx.get("pair_a_name", m_name))
			var nb_ej2: String = str(ctx.get("pair_b_name", "Dolores"))
			match chosen:
				"cooperate_chores":
					_change_pair_relationship(ida_ej, idb_ej, 12)
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 4.0, 0.0, 100.0)
					outcome_text = "Tackling the sump pump and vent baffles together earned mutual respect between %s and %s (+12 Bond, +4 Integrity)!" % [na_ej2, nb_ej2]
					morale_delta = 2
					tags = ["morale_up"]
				"use_checkers":
					_change_pair_relationship(ida_ej, idb_ej, 10)
					outcome_text = "High-stakes Checkers settled tomorrow's duty roster without a single complaint (+10 Bond)!"
					morale_delta = 1
					tags = ["morale_up"]
				"praise_both":
					if active_rng.randf() < 0.55:
						_change_pair_relationship(ida_ej, idb_ej, 6)
						outcome_text = "Acknowledging both %s and %s's sacrifices restored quiet pride (+6 Bond)." % [na_ej2, nb_ej2]
						morale_delta = 1
						tags = ["morale_up"]
					else:
						_change_pair_relationship(ida_ej, idb_ej, -8)
						outcome_text = "Even-handed praise rang hollow. %s muttered that some of us risk our lungs out there while others count cans." % na_ej2
						morale_delta = -1
						tags = ["morale_down"]
				_:
					_change_pair_relationship(ida_ej, idb_ej, -15)
					outcome_text = "Playing favorites left %s fuming on their bunk (-15 Resentment)!" % nb_ej2
					morale_delta = -1
					tags = ["morale_down"]

		"family_heirloom_watch_pledge":
			match chosen:
				"cooperate_oath":
					_change_all_bunker_relationships(15)
					_reduce_family_stress(1)
					outcome_text = "Hands stacked atop the heirloom watch, the household swore an unbreakable oath to leave nobody behind again (+15 Family Bond)!"
					morale_delta = 2
					tags = ["morale_up"]
				"use_toolbox":
					_change_all_bunker_relationships(14)
					_reduce_family_stress(1)
					outcome_text = "TICK-TICK-TICK! Delicate jeweler's drivers from the Toolbox brought the 1952 wristwatch back to steady life (+14 Family Bond)!"
					morale_delta = 2
					tags = ["morale_up"]
				_:
					_change_all_bunker_relationships(6)
					outcome_text = "Hanging the brass watch above the calendar gave the concrete room a touch of home (+6 Family Bond)."
					morale_delta = 1
					tags = ["morale_up"]

		# ----------------------------------------------------------------------
		# 82-92. V2 PILLAR 4: REAL-WORLD LANDMARK CONDITIONAL EVENTS
		# ----------------------------------------------------------------------
		"landmark_doctor_triage_ledger":
			match chosen:
				"trade_soup_abx":
					_add_soup_quarters(-2)
					GameState.add_scavenged_item("antibiotics", 1)
					_heal_one_afflicted_member()
					GameState.unlock_achievement("doctor_house")
					outcome_text = "Grateful for 2/4 Soup, Nurse Evelyn from %s passed down 1 Prescription Antibiotics pack and dressed our worst ailment!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "healed", "morale_up"]
				"use_antibiotics":
					if GameState.has_working_item("antibiotics"):
						GameState.break_or_consume_item("antibiotics")
					_heal_all_family_afflictions()
					GameState.add_scavenged_item("medkit", 1)
					GameState.add_scavenged_item("antirad", 1)
					GameState.unlock_achievement("doctor_house")
					outcome_text = "Using %s's sterile compounding ledger, Nurse Evelyn turned 1 Antibiotics dose into a full household cure PLUS 1 Medkit & 1 Anti-Rad Pack!" % poi_name
					morale_delta = 3
					tags = ["item_gained", "healed", "morale_up"]
				"use_book":
					GameState.add_scavenged_item("antibiotics", 1)
					GameState.unlock_achievement("doctor_house")
					outcome_text = "Copying %s's emergency dosage tables into our Handbook earned a complimentary pack of Prescription Antibiotics!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "You wished Nurse Evelyn from %s safe travels across %s." % [poi_name, hood]
					morale_delta = 0
					tags = ["neutral"]

		"landmark_supermarket_cold_storage":
			match chosen:
				"use_gas_mask":
					_add_soup_quarters(8)
					_add_water_quarters(4)
					GameState.unlock_achievement("grocery_haul")
					outcome_text = "Ghosting through the ash fog in our Gas Mask, %s emptied %s's cold-storage chute unseen: +2 full Soup Cans & +1 Water Bottle!" % [m_name, poi_name]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_rifle":
					if GameState.ammo_count > 0:
						GameState.break_or_consume_item("ammo")
					_add_soup_quarters(8)
					_add_water_quarters(4)
					GameState.unlock_achievement("grocery_haul")
					outcome_text = "Shouldering the Hunting Rifle warned off rival scavengers at %s, securing +2 Soup Cans & +1 Water Bottle!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"greedy_haul":
					_add_soup_quarters(6)
					GameState.story_flags["rival_looters_day"] = GameState.day
					if active_rng.randf() < 0.45:
						GameState.story_flags["vendetta_active"] = true
						GameState.story_flags["vendetta_day"] = GameState.day
						outcome_text = "%s dragged back 1 + 2/4 Soup from %s, but rival scavengers spotted our hatch and swore they'd be back in a few days!" % [m_name, poi_name]
					else:
						GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 5.0, 10.0, 100.0)
						outcome_text = "%s hauled 1 + 2/4 Soup from %s while dodging thrown bricks from jealous looters (-5 Integrity)!" % [m_name, poi_name]
					morale_delta = 1
					tags = ["item_gained"]
				_:
					outcome_text = "Wise caution—we let rival gangs fight over %s's service alley instead." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"landmark_pharmacy_iodide_shipment":
			match chosen:
				"use_gas_mask":
					GameState.add_scavenged_item("antirad", 2)
					target_member["radiation"] = maxf(0.0, float(target_member.get("radiation", 0.0)) - 18.0)
					GameState.family_changed.emit()
					outcome_text = "Protected by the Gas Mask, %s recovered +2 Potassium Iodide Anti-Rad Packs from the %s dispatch box!" % [m_name, poi_name]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_flashlight":
					GameState.add_scavenged_item("antirad", 1)
					_add_water_quarters(2)
					outcome_text = "Spotting the clasp under our Flashlight beam snagged +1 Anti-Rad Pack and +2/4 sterile Water from the %s courier box!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"sprint_grab":
					GameState.add_scavenged_item("antirad", 1)
					if not bool(target_member.get("is_mutant", false)):
						target_member["radiation"] = float(target_member.get("radiation", 0.0)) + 12.0
						GameState.family_changed.emit()
					outcome_text = "%s dashed out to the %s scooter and grabbed +1 Anti-Rad Pack at the cost of minor surface dust!" % [m_name, poi_name]
					morale_delta = 1
					tags = ["item_gained"]
					if active_rng.randf() < 0.35:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text += " A looter's bottle clipped %s on the way back - the cut is already festering." % m_name
						morale_delta = 0
						tags = ["item_gained", "sick"]
				_:
					outcome_text = "We kept the hatch sealed while wind dusted over the %s scooter." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"landmark_gas_station_underground_tank":
			match chosen:
				"use_toolbox":
					GameState.add_scavenged_item("fuel", 1)
					GameState.add_scavenged_item("scrap", 1)
					outcome_text = "Coupling brass fittings with the Toolbox pumped +1 Gasoline Jerrycan and salvaged +1 Scrap from %s!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_gas_mask":
					GameState.add_scavenged_item("fuel", 1)
					outcome_text = "Protected from benzene vapors by the Gas Mask, %s pumped +1 full Gasoline Jerrycan at %s!" % [m_name, poi_name]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"trade_water_fuel":
					_add_water_quarters(-2)
					GameState.add_scavenged_item("fuel", 1)
					outcome_text = "Swapping 2/4 Clean Water to the %s watchman put +1 Gasoline Jerrycan in our garage!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "We left %s's underground reserve tank for a calmer day." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"landmark_firehouse_siren_relay":
			match chosen:
				"use_radio":
					if int(GameState.rescue_chains.get("military", 0)) < 2:
						GameState.rescue_chains["military"] = int(GameState.rescue_chains.get("military", 0)) + 1
					_add_water_quarters(4)
					outcome_text = "SIGNAL BOOSTED! Relaying through %s's firehouse repeater advanced our Civil Defense evacuation priority AND unlocked +4/4 hydrant reserve Water!" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"use_axe":
					GameState.add_scavenged_item("medkit", 1)
					GameState.add_scavenged_item("scrap", 1)
					outcome_text = "Popping the %s curbside call-box locker with our Fireman's Axe scored 1 First Aid Medkit and +1 Scrap!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"cooperate_crank":
					if int(GameState.rescue_chains.get("military", 0)) < 2:
						GameState.rescue_chains["military"] = int(GameState.rescue_chains.get("military", 0)) + 1
					else:
						_add_soup_quarters(4)
					_change_all_bunker_relationships(8)
					outcome_text = "Cranking the heavy %s telegraph dynamo in tandem pinged Civil Defense headquarters cleanly (+8 Bond)!" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "morale_up"]
				_:
					outcome_text = "The clicking relay from %s eventually cycled into standby." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"landmark_highschool_ham_club":
			match chosen:
				"use_radio":
					GameState.surface_radiation_sv = maxf(0.15, GameState.surface_radiation_sv - 0.4)
					if int(GameState.rescue_chains.get("raider_pact", 0)) == 0:
						GameState.rescue_chains["raider_pact"] = 1
					if not GameState.has_working_item("map"):
						GameState.add_scavenged_item("map", 1)
						outcome_text = "QSL CONFIRMED! The teen ham operators at %s shared convoy frequencies (Convoy Stage 1/3) and helped us chart a full Civil Defense Map!" % poi_name
					else:
						_add_soup_quarters(4)
						outcome_text = "QSL CONFIRMED! %s's ham club guided us to an unlooted cafeteria stash (+4/4 Soup) and logged highway convoy frequencies!" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"use_book":
					GameState.add_scavenged_item("antirad", 1)
					outcome_text = "Decoding %s's chemistry-club cipher with our Handbook led to a sealed Potassium Iodide pack (+1 Anti-Rad)!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					_reduce_family_stress(1)
					outcome_text = "Hearing cheerful student voices broadcasting from %s lifted spirits across the bunker!" % poi_name
					morale_delta = 1
					tags = ["morale_up"]

		"landmark_hardware_scrap_yard":
			match chosen:
				"use_toolbox":
					GameState.add_scavenged_item("scrap", 2)
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 8.0, 0.0, 100.0)
					outcome_text = "Stripping %s's spilled trailer with the Toolbox yielded +2 Salvaged Scrap and +8 Shelter Integrity!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_suitcase":
					GameState.add_scavenged_item("scrap", 2)
					outcome_text = "Packing our Leather Suitcase full of %s hardware added +2 Salvaged Scrap to the workbench!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					GameState.add_scavenged_item("scrap", 1)
					_adjust_member_stat(target_member, "fatigue", 1)
					outcome_text = "%s wrestled +1 heavy bundle of %s Scrap down the ladder by hand!" % [m_name, poi_name]
					morale_delta = 1
					tags = ["item_gained"]

		"landmark_church_sanctuary_candles":
			match chosen:
				"return_note_soup":
					_add_soup_quarters(-1)
					_add_water_quarters(4)
					_change_all_bunker_relationships(12)
					if int(GameState.rescue_chains.get("sanctuary", 0)) < 2:
						GameState.rescue_chains["sanctuary"] = int(GameState.rescue_chains.get("sanctuary", 0)) + 1
					outcome_text = "Exchanging 1/4 Soup and a warm note with %s brought +1 full bottle of Clean Water, +12 Family Harmony, and deeper Sanctuary ties!" % poi_name
					morale_delta = 2
					tags = ["rescue_progress", "item_gained", "morale_up"]
				"accept_basket":
					_add_water_quarters(4)
					_change_all_bunker_relationships(8)
					_reduce_family_stress(1)
					outcome_text = "Beeswax candlelight and +4/4 filtered Clean Water from %s filled the bunker with peace (+8 Family Bond)!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
					if active_rng.randf() < 0.35:
						_add_water_quarters(-4)
						_add_soup_quarters(-2)
						outcome_text = "Someone had watched the %s volunteers drop that basket. While we unpacked it, looters pried the vent grate and made off with the water and 2/4 of our Soup!" % poi_name
						morale_delta = -1
						tags = ["item_lost", "morale_down"]
				_:
					_change_all_bunker_relationships(5)
					outcome_text = "Leaving %s's care basket for a hungrier family down the block made everyone quietly proud (+5 Bond)." % poi_name
					morale_delta = 1
					tags = ["morale_up"]
					if int(GameState.rescue_chains.get("sanctuary", 0)) < 2:
						GameState.rescue_chains["sanctuary"] = int(GameState.rescue_chains.get("sanctuary", 0)) + 1
						outcome_text += " Word of our restraint reached the parish elders."
						tags = ["morale_up", "rescue_progress"]

		"landmark_clinic_quarantine_notice":
			match chosen:
				"use_antibiotics":
					if GameState.has_working_item("antibiotics"):
						GameState.break_or_consume_item("antibiotics")
					_heal_all_family_afflictions()
					outcome_text = "Following %s's advisory, a preventative Antibiotics course wiped out every trace of fever and infection in our shelter!" % poi_name
					morale_delta = 2
					tags = ["healed", "morale_up"]
				"use_bug_spray":
					if GameState.has_working_item("bug_spray"):
						GameState.break_or_consume_item("bug_spray")
					GameState.roach_infestation = 0
					outcome_text = "Sterilizing the sump traps with Bug Spray per %s's bulletin eliminated pests and spores completely!" % poi_name
					morale_delta = 1
					tags = ["morale_up"]
				"boil_scrub":
					_add_water_quarters(-1)
					target_member["sickness"] = maxi(0, int(target_member.get("sickness", 0)) - 1)
					GameState.family_changed.emit()
					outcome_text = "Boiling 1/4 Water to steam-scrub the bunks per %s's flyer kept everyone healthy!" % poi_name
					morale_delta = 1
					tags = ["healed", "morale_up"]
				_:
					if not bool(target_member.get("is_mutant", false)) and not _has_iron_stomach(target_member) and active_rng.randf() < 0.35:
						_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "Ignoring %s's bio-warning backfired—damp sump spores left %s feverish!" % [poi_name, m_name]
						morale_delta = -1
						tags = ["sick", "morale_down"]
					else:
						outcome_text = "Thankfully, our dry concrete sump trap kept the %s drain spores out." % poi_name
						morale_delta = 0
						tags = ["neutral"]

		"landmark_auto_shop_battery_rack":
			match chosen:
				"use_gas_mask":
					var p_bat: String = _grant_missing_vehicle_part_or_scrap(["battery", "alternator"])
					GameState.add_scavenged_item("scrap", 1)
					outcome_text = "Braving the ozone sparks at %s in our Gas Mask scored a fully charged %s plus +1 Scrap!" % [poi_name, _get_pretty_part_name(p_bat)]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_scrap":
					if GameState.has_working_item("scrap"):
						GameState.break_or_consume_item("scrap")
					var broken_now: Array[String] = _get_broken_owned_item_ids()
					if not broken_now.is_empty():
						GameState.repair_item(broken_now[0])
						outcome_text = "Using %s's wind-charger and our Scrap leads repaired our broken %s!" % [poi_name, str(ITEM_LABELS.get(broken_now[0], broken_now[0]))]
					else:
						var p_alt: String = _grant_missing_vehicle_part_or_fuel(["battery"])
						outcome_text = "Splicing Scrap leads into %s's rack recovered a working %s!" % [poi_name, _get_pretty_part_name(p_alt)]
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "We stayed out of sight while blue sparks danced atop %s." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		"landmark_library_microfilm_atlas":
			match chosen:
				"use_flashlight":
					if not GameState.has_working_item("map"):
						GameState.add_scavenged_item("map", 1)
						outcome_text = "Projecting %s's microfilms with our Flashlight let us trace a complete Civil Defense Map of %s!" % [poi_name, hood]
					elif not GameState.has_working_item("book"):
						GameState.add_scavenged_item("book", 1)
						outcome_text = "Grateful for our Flashlight inspection, the %s archivist gifted us a mint Survival Handbook!" % poi_name
					else:
						_add_water_quarters(4)
						_add_soup_quarters(4)
						outcome_text = "Projecting %s's storm-tunnel microfilm pinpointed a municipal cache (+1 Soup Can & +1 Water Bottle)!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"give_soup":
					_add_soup_quarters(-2)
					if not GameState.has_working_item("map"):
						GameState.add_scavenged_item("map", 1)
					GameState.add_scavenged_item("antirad", 1)
					outcome_text = "Warmed by 2/4 Soup, the %s archivist gifted us Civil Defense tunnel charts and +1 Anti-Rad Pack!" % poi_name
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				_:
					outcome_text = "The %s archivist adjusted their spectacles and wheeled their book-cart onward." % poi_name
					morale_delta = 0
					tags = ["neutral"]

		# ----------------------------------------------------------------------
		# 93-103. V2 PILLAR 5: DELAYED PERSISTENT CONSEQUENCES (STORY_FLAGS)
		# ----------------------------------------------------------------------
		"stranger_wounded_courier":
			GameState.story_flags["courier_resolved"] = true
			match chosen:
				"help_medkit":
					if GameState.has_working_item("medkit"):
						GameState.break_or_consume_item("medkit")
					GameState.story_flags["helped_courier_day"] = GameState.day
					_change_all_bunker_relationships(6)
					outcome_text = "Dressing Courier Vera's ribs with our Medkit saved her life! She tapped our hatch twice: 'Give me four days to reach my depot—I won't forget %s!' (+6 Bond)" % house_addr
					morale_delta = 2
					tags = ["item_lost", "morale_up"]
				"help_rations":
					_add_water_quarters(-2)
					_add_soup_quarters(-2)
					GameState.story_flags["helped_courier_day"] = GameState.day
					_change_all_bunker_relationships(6)
					outcome_text = "Strengthened by 2/4 Water and 2/4 Soup, Courier Vera swore on her dispatch badge to send a depot drop back to %s in four days!" % house_addr
					morale_delta = 2
					tags = ["item_lost", "morale_up"]
				"rob_courier":
					_add_soup_quarters(4)
					GameState.ammo_count += 2
					GameState.inventory_changed.emit()
					GameState.story_flags["vendetta_active"] = true
					GameState.story_flags["vendetta_day"] = GameState.day
					_change_all_bunker_relationships(-10)
					outcome_text = "You wrenched +1 Soup Can and +2 Rifle Ammo off the wounded courier! Limping into the fog, she memorized %s and spat: 'My caravan will collect double in four days!' (-10 Family Shame)" % house_addr
					morale_delta = -1
					tags = ["item_gained", "morale_down"]
				_:
					outcome_text = "Keeping our hatch sealed, we listened as the limping courier faded down the block."
					morale_delta = 0
					tags = ["neutral"]

		"courier_repayment_drop":
			GameState.story_flags["courier_repaid"] = true
			GameState.add_scavenged_item("antibiotics", 1)
			GameState.add_scavenged_item("fuel", 1)
			if chosen == "use_flashlight":
				_add_soup_quarters(6)
				_add_water_quarters(4)
				_change_all_bunker_relationships(8)
				outcome_text = "KARMA REPAID IN SPADES! Signaling Courier Vera with our Flashlight brought down 1 Prescription Antibiotics, 1 Gasoline Jerrycan, 1 + 2/4 Soup, AND 1 Water Bottle!"
			else:
				_add_soup_quarters(4)
				_change_all_bunker_relationships(8)
				outcome_text = "MERCY REWARDED! Inside Courier Vera's gratitude drop sat 1 Prescription Antibiotics, 1 Gasoline Jerrycan, and 1 full Can of Tomato Soup (+8 Bond)!"
			morale_delta = 3
			tags = ["item_gained", "morale_up"]

		"vendetta_reprisal_raid":
			GameState.story_flags["vendetta_active"] = false
			if chosen == "use_padlock":
				GameState.break_or_consume_item("padlock")
				GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 5.0, 10.0, 100.0)
				outcome_text = "CLANG-SNAP! Our Heavy Padlock sacrificed itself to stop the caravan posse's sledgehammers (-5 Integrity)! Cursing, they called the vendetta settled and left!"
				morale_delta = 0
				tags = ["raid", "item_lost"]
			elif chosen == "use_rifle_ammo":
				GameState.ammo_count = maxi(0, GameState.ammo_count - 2)
				GameState.add_scavenged_item("scrap", 1)
				outcome_text = "BLAM-BLAM! Two live Rifle rounds sent the reprisal posse diving behind cars across %s, dropping +1 Scrap as they retreated for good!" % hood
				morale_delta = 2
				tags = ["raid", "item_gained", "morale_up"]
			elif chosen == "pay_blood_debt":
				_add_soup_quarters(-8)
				outcome_text = "Handing over 2 full Cans of Soup (8/4) satisfied the caravan posse's blood-debt. Expensive lesson in wasteland karma!"
				morale_delta = -1
				tags = ["raid", "item_lost", "morale_down"]
			else:
				var present_v: Array = _get_present_members()
				if GameState.day >= 12 and GameState.bunker_structural_integrity <= 25.0 and present_v.size() <= 1:
					for m_v in present_v:
						if m_v is Dictionary:
							var m_def_v: Dictionary = m_v
							m_def_v["alive"] = false
							m_def_v["in_bunker"] = false
							m_def_v["death_reason"] = "Shelter overrun in a vendetta reprisal raid."
							m_def_v["status_note"] = "Shelter overrun in a vendetta reprisal raid."
					GameState.bunker_structural_integrity = 0.0
					GameState.game_over = true
					GameState.victory = false
					GameState.ending_title = "DEFEAT: Vendetta Reprisal Overrun"
					GameState.ending_description = "On Day %d, the wasteland posse we wronged returned in force and breached the weakened blast hatch beneath %s." % [GameState.day, house_addr]
					GameState.family_changed.emit()
					outcome_text = "BREACH! With our hatch already weakened and no defenses left, the vendetta posse battered down the blast door at %s! GAME OVER!" % house_addr
					morale_delta = -2
					tags = ["raid", "gameover", "morale_down"]
				else:
					var lost_vs: int = mini(6, GameState.soup_quarters)
					var lost_vw: int = mini(4, GameState.water_quarters)
					_add_soup_quarters(-lost_vs)
					_add_water_quarters(-lost_vw)
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity - 18.0, 5.0, 100.0)
					_adjust_member_stat(target_member, "injury", 1)
					outcome_text = "A brutal reprisal! The posse battered our chute (-18 Integrity), bruised %s, and seized %d/4 Soup & %d/4 Water to settle the score!" % [m_name, lost_vs, lost_vw]
					morale_delta = -2
					tags = ["raid", "injured", "item_lost", "morale_down"]

		"stranger_desperate_tinker":
			GameState.story_flags["tinker_met"] = true
			match chosen:
				"lend_scrap":
					if GameState.has_working_item("scrap"):
						GameState.break_or_consume_item("scrap")
					GameState.story_flags["helped_tinker_day"] = GameState.day
					_change_all_bunker_relationships(5)
					outcome_text = "Old Man Mercer beamed through straightened spectacles: 'Four days at my lathe and I'll bring %s a machine worth ten times this Scrap!'" % house_addr
					morale_delta = 1
					tags = ["item_lost", "morale_up"]
				"give_water":
					_add_water_quarters(-2)
					GameState.story_flags["helped_tinker_day"] = GameState.day
					outcome_text = "Revived by 2/4 Clean Water, Old Man Mercer sketched our vent dimensions and promised to return in four days with custom gear!"
					morale_delta = 1
					tags = ["item_lost", "morale_up"]
				"rob_tinker":
					GameState.add_scavenged_item("scrap", 2)
					GameState.story_flags["vendetta_active"] = true
					GameState.story_flags["vendetta_day"] = GameState.day
					_change_all_bunker_relationships(-12)
					outcome_text = "Snatching Mercer's brass bag yielded +2 Scrap today—but highway wardens protecting the old tinker spotted our address (-12 Family Guilt, Vendetta Active)!"
					morale_delta = -2
					tags = ["item_gained", "morale_down"]
				_:
					outcome_text = "Old Man Mercer nodded understandingly and shuffled onward down %s." % house_addr
					morale_delta = 0
					tags = ["neutral"]

		"tinker_workshop_dividend":
			GameState.story_flags["tinker_repaid"] = true
			var mercer_part: String = _grant_missing_vehicle_part_or_scrap([])
			GameState.add_scavenged_item("antirad", 1)
			GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 10.0, 0.0, 100.0)
			GameState.surface_radiation_sv = maxf(0.15, GameState.surface_radiation_sv - 0.5)
			var broken_t: Array[String] = _get_broken_owned_item_ids()
			if not broken_t.is_empty():
				GameState.repair_item(broken_t[0])
			outcome_text = "CRAFTSMAN'S HONOR! Old Man Mercer installed his custom vent scrubber (+10 Integrity, -0.5 Sv/hr) AND delivered a precision %s plus +1 Anti-Rad Pack!" % _get_pretty_part_name(mercer_part)
			morale_delta = 3
			tags = ["item_gained", "morale_up"]

		"mystery_seed_tin":
			GameState.story_flags["seed_tin_seen"] = true
			match chosen:
				"plant_tray":
					_add_water_quarters(-3)
					GameState.story_flags["planted_greens_day"] = GameState.day
					outcome_text = "Investing 3/4 Clean Water moistened the seed tray beneath our lamp—tiny green cotyledons should sprout in 4 days!"
					morale_delta = 1
					tags = ["item_lost", "morale_up"]
				"eat_seeds_now":
					_add_soup_quarters(2)
					outcome_text = "Crunching the toasted barley and radish seeds gave an immediate +2/4 ration boost today."
					morale_delta = 1
					tags = ["item_gained"]
				_:
					_change_all_bunker_relationships(5)
					outcome_text = "We tucked the wax-sealed 1954 seed tin back onto the shelf. Someday there will be soil again - just knowing it's there gives everyone something to talk about."
					morale_delta = 1
					tags = ["morale_up"]

		"sprouted_bunker_greens":
			GameState.story_flags["harvested_greens"] = true
			_add_soup_quarters(8)
			for m_v in _get_present_members():
				var mem_gr: Dictionary = m_v
				mem_gr["sickness"] = maxi(0, int(mem_gr.get("sickness", 0)) - 1)
			_reduce_family_stress(1)
			_change_all_bunker_relationships(8)
			outcome_text = "BOUNTIFUL BUNKER HARVEST! Fresh radish and barley micro-greens added +2 full Cans worth of rations (+8/4), eased sickness across the shelter, and lifted every heart (+8 Bond)!"
			morale_delta = 3
			tags = ["item_gained", "healed", "morale_up"]

		"unsealed_munitions_crate":
			GameState.story_flags["munitions_seen"] = true
			match chosen:
				"use_toolbox_disarm":
					GameState.ammo_count += 4
					GameState.add_scavenged_item("scrap", 1)
					_add_soup_quarters(4)
					outcome_text = "Clipping the lithium locator wire with our Toolbox let us safely strip +4 Rifle Ammo, +1 Scrap, and +1 Soup Can with zero trace!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"fire_signal_beacon":
					GameState.ammo_count += 2
					GameState.inventory_changed.emit()
					GameState.story_flags["flare_drop_day"] = GameState.day
					outcome_text = "WHOOSH! Your high-altitude distress flare streaked into the stratosphere (+2 Rifle Ammo pocketed)—watch the skies above %s in four days!" % house_addr
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
					if active_rng.randf() < 0.35:
						GameState.story_flags["vendetta_active"] = true
						GameState.story_flags["vendetta_day"] = GameState.day
						outcome_text += " Unfortunately, a flare is visible to everyone - raiders across %s now know exactly where our hatch is." % hood
						morale_delta = 1
				"haul_hot_crate":
					GameState.ammo_count += 4
					_add_soup_quarters(4)
					if active_rng.randf() < 0.50:
						GameState.story_flags["vendetta_active"] = true
						GameState.story_flags["vendetta_day"] = GameState.day
						outcome_text = "You scored +4 Rifle Ammo and +1 Soup Can, though the crate's blinking RF transponder pinged scavenger scanners across %s before dying!" % hood
					else:
						outcome_text = "Lucky break! Smothering the blinking transponder in an iron pot secured +4 Rifle Ammo and +1 Soup Can cleanly!"
					morale_delta = 1
					tags = ["item_gained"]
				_:
					outcome_text = "Suspecting a tracker trap, we left the blinking crate buried in the ash."
					morale_delta = 0
					tags = ["neutral"]

		"beacon_supply_drop_arrival":
			GameState.story_flags["flare_drop_claimed"] = true
			_add_water_quarters(4)
			_add_soup_quarters(4)
			GameState.add_scavenged_item("antirad", 1)
			if int(GameState.rescue_chains.get("military", 0)) == 0:
				GameState.rescue_chains["military"] = 1
			outcome_text = "SKY-DROP DELIVERED! Your flare from four days ago guided down 1 Clean Water, 1 Tomato Soup, and 1 Anti-Rad Pack straight to %s!" % house_addr
			morale_delta = 3
			tags = ["rescue_progress", "item_gained", "morale_up"]

		"stranger_chemist_vial":
			GameState.story_flags["chemist_seen"] = true
			match chosen:
				"store_honestly":
					GameState.story_flags["chemist_stored_day"] = GameState.day
					outcome_text = "Tucked safely in our cool sump corner, the sealed Dewar flask hums softly while we await the bio-chemist's return in four days."
					morale_delta = 1
					tags = ["morale_up"]
					if active_rng.randf() < 0.30 and not bool(target_member.get("is_mutant", false)):
						target_member["radiation"] = float(target_member.get("radiation", 0.0)) + 14.0
						GameState.family_changed.emit()
						outcome_text += " Overnight the seal wept a faint green vapor - %s, sleeping nearest the sump, woke with a metallic taste and a pounding head." % m_name
						morale_delta = 0
						tags = ["morale_down"]
				"crack_thermos_now":
					if active_rng.randf() < 0.48 and not bool(target_member.get("is_mutant", false)):
						outcome_text = _apply_mutant_transformation(target_member)
						morale_delta = 2
						tags = ["mutant", "morale_up"]
					else:
						if not bool(target_member.get("is_mutant", false)):
							target_member["radiation"] = float(target_member.get("radiation", 0.0)) + 25.0
							_adjust_member_stat(target_member, "sickness", 1)
						outcome_text = "FIZZ-POP! Unrefined isotope vapor gave %s a bout of green hiccups instead of miracle medicine!" % m_name
						morale_delta = -1
						tags = ["sick", "morale_down"]
				_:
					outcome_text = "Preferring zero experimental isotopes near the soup shelf, you politely declined."
					morale_delta = 0
					tags = ["neutral"]

		"chemist_antidote_return":
			GameState.story_flags["chemist_returned"] = true
			GameState.add_scavenged_item("antibiotics", 1)
			GameState.add_scavenged_item("antirad", 1)
			GameState.add_scavenged_item("medkit", 1)
			_change_all_bunker_relationships(8)
			outcome_text = "TRUST REWARDED! Keeping our word to the field bio-chemist earned 1 Prescription Antibiotics, 1 Anti-Rad Pack, and 1 First Aid Medkit (+8 Bond)!"
			morale_delta = 3
			tags = ["item_gained", "morale_up"]

		_:
			outcome_text = "Another calm entry penciled into the Civil Defense logbook beneath %s." % house_addr
			morale_delta = 0
			tags = ["neutral"]

	return {
		"outcome_text": outcome_text,
		"morale_delta": morale_delta,
		"tags": tags
	}


# ==============================================================================
# INTERNAL HELPERS (STRICTLY TYPED FOR GODOT 4.3)
# ==============================================================================

static func _sanitize_choice(event_dict: Dictionary, choice_id: String) -> String:
	var opts: Array = event_dict.get("options", [])
	if choice_id != "":
		for o_v in opts:
			if not (o_v is Dictionary):
				continue
			var o: Dictionary = o_v
			if str(o.get("id", "")) == choice_id and bool(o.get("available", false)):
				return choice_id
	# Default to first available option
	for o_v in opts:
		if not (o_v is Dictionary):
			continue
		var o: Dictionary = o_v
		if bool(o.get("available", false)):
			return str(o.get("id", "ignore"))
	return "ignore"


static func _get_house_address() -> String:
	var addr: String = str(GameState.selected_house.get("address", ""))
	if addr != "":
		return addr
	var h_name: String = str(GameState.selected_house.get("name", ""))
	if h_name != "":
		return h_name
	return "518 E Roy St"


static func _get_neighborhood_label() -> String:
	if GameState.current_neighborhood_label != "":
		return GameState.current_neighborhood_label
	return "Capitol Hill, Seattle"


static func _get_sanctuary_poi_name() -> String:
	if _sanctuary_poi_cache != "":
		return _sanctuary_poi_cache
	var found: String = _find_poi_name(["church", "parish", "chapel", "worship", "cathedral", "temple", "school"], "")
	if found != "":
		_sanctuary_poi_cache = found
		return found
	var hood_low: String = (_get_neighborhood_label() + " " + _get_house_address()).to_lower()
	if hood_low.find("concord") != -1:
		_sanctuary_poi_cache = "First Parish in Concord"
	elif hood_low.find("brooklyn") != -1 or hood_low.find("carroll") != -1:
		_sanctuary_poi_cache = "St. Agnes Parish Hall"
	else:
		_sanctuary_poi_cache = "All Pilgrims Christian Church"
	return _sanctuary_poi_cache


static func _has_poi_matching(keywords: Array) -> bool:
	for p_v in GameState.nearby_pois:
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = p_v
		var p_cat: String = str(p.get("category", p.get("type", p.get("poi_type", p.get("kind", ""))))).to_lower()
		var p_name_low: String = str(p.get("name", p.get("label", ""))).to_lower()
		for kw_v in keywords:
			var kw: String = str(kw_v).to_lower()
			if p_cat.find(kw) != -1 or p_name_low.find(kw) != -1:
				return true
	return false


static func _find_poi_name(keywords: Array, fallback_label: String) -> String:
	for p_v in GameState.nearby_pois:
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = p_v
		var p_cat: String = str(p.get("category", p.get("type", p.get("poi_type", p.get("kind", ""))))).to_lower()
		var p_name: String = str(p.get("name", p.get("label", p.get("title", p.get("address", "")))))
		if p_name == "":
			continue
		var p_name_low: String = p_name.to_lower()
		for kw_v in keywords:
			var kw: String = str(kw_v).to_lower()
			if p_cat.find(kw) != -1 or p_name_low.find(kw) != -1:
				return p_name

	if fallback_label == "":
		return ""

	# Authentic preset-aware fallback if nearby_pois hasn't been populated yet
	var hood_low: String = (_get_neighborhood_label() + " " + _get_house_address()).to_lower()
	var first_kw: String = str(keywords[0]).to_lower() if not keywords.is_empty() else ""
	if hood_low.find("seattle") != -1 or hood_low.find("roy") != -1 or hood_low.find("capitol") != -1:
		match first_kw:
			"grocery":
				return "Broadway QFC Supermarket"
			"doctor":
				return "First Hill Urgent Care Clinic"
			"pharmacy":
				return "Capitol Hill Apothecary"
			"fuel_auto":
				return "915 E Roy St 76 Service Station"
			"neighbor":
				return "524 E Roy St Neighbor Residence"
			"hardware":
				return "Pacific Supply & Hardware"
			"restaurant":
				return "Pho Than Brothers on Broadway"
			"school", "library":
				return "Broadway Civil Defense High School"
			"park":
				return "Cal Anderson Park"
			"civic", "fire":
				return "Seattle Fire Station No. 25"
	elif hood_low.find("concord") != -1:
		match first_kw:
			"grocery":
				return "Crosby's Marketplace"
			"doctor":
				return "Emerson Community Clinic"
			"pharmacy":
				return "Concord Colonial Pharmacy"
			"fuel_auto":
				return "Lexington Rd Gulf Service"
			"neighbor":
				return "Monument Sq Neighbor House"
			"school", "library":
				return "Concord Free Public Library"
			"park":
				return "Minuteman National Park"
			"civic", "fire":
				return "Concord Walden St Firehouse"
	elif hood_low.find("brooklyn") != -1 or hood_low.find("carroll") != -1:
		match first_kw:
			"grocery":
				return "Court Street Grocers"
			"doctor":
				return "Cobble Hill Medical Office"
			"pharmacy":
				return "Carroll Gardens Pharmacy"
			"fuel_auto":
				return "Atlantic Ave Auto & Service"
			"neighbor":
				return "President St Brownstone"
			"school", "library":
				return "Carroll Park Branch Library"
			"park":
				return "Carroll Park"
			"civic", "fire":
				return "FDNY Engine Co. 204"
	return fallback_label


static func _get_present_members() -> Array:
	var living_bunker: Array = GameState.get_living_bunker_members()
	if not living_bunker.is_empty():
		return living_bunker
	var fallback: Array = []
	for m_v in GameState.family_members:
		if m_v is Dictionary:
			var m: Dictionary = m_v
			if bool(m.get("alive", true)) and not bool(m.get("on_expedition", false)):
				fallback.append(m)
	return fallback


static func _pick_random_member(rng: RandomNumberGenerator) -> Dictionary:
	var present: Array = _get_present_members()
	if present.is_empty():
		return {"id": "member_0", "name": "Ted", "age": 42, "role": "adult"}
	var idx: int = rng.randi_range(0, present.size() - 1)
	var picked: Dictionary = present[idx]
	return picked


static func _find_member_by_id_or_random(member_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var present: Array = _get_present_members()
	if member_id != "":
		for m_v in present:
			var m: Dictionary = m_v
			if str(m.get("id", "")) == member_id:
				return m
	return _pick_random_member(rng)


static func _get_leader_or_first_member(rng: RandomNumberGenerator) -> Dictionary:
	var present: Array = _get_present_members()
	for m_v in present:
		var m: Dictionary = m_v
		if bool(m.get("is_leader", false)):
			return m
	return _pick_random_member(rng)


static func _get_left_behind_name(rng: RandomNumberGenerator) -> String:
	if not GameState.left_behind_members.is_empty():
		var idx: int = rng.randi_range(0, GameState.left_behind_members.size() - 1)
		var entry: Variant = GameState.left_behind_members[idx]
		if entry is Dictionary:
			var d: Dictionary = entry
			var dn: String = str(d.get("name", ""))
			if dn != "":
				return dn
			var did: String = str(d.get("id", ""))
			for fm_v in GameState.family_members:
				if fm_v is Dictionary and str((fm_v as Dictionary).get("id", "")) == did:
					return str((fm_v as Dictionary).get("name", "our missing kin"))
		else:
			var s: String = str(entry)
			for fm_v2 in GameState.family_members:
				if fm_v2 is Dictionary and str((fm_v2 as Dictionary).get("id", "")) == s:
					return str((fm_v2 as Dictionary).get("name", s))
			if s != "":
				return s
	for fm_v3 in GameState.family_members:
		if fm_v3 is Dictionary:
			var fm: Dictionary = fm_v3
			if not bool(fm.get("in_bunker", true)) and not bool(fm.get("on_expedition", false)):
				var fn: String = str(fm.get("name", ""))
				if fn != "":
					return fn
	return "our unrescued family member"


static func _has_cooperating_pair(min_score: int = 45) -> bool:
	var present: Array = _get_present_members()
	if present.size() < 2:
		return false
	for i in range(present.size()):
		var ma: Dictionary = present[i]
		var ida: String = str(ma.get("id", ""))
		for j in range(i + 1, present.size()):
			var mb: Dictionary = present[j]
			var idb: String = str(mb.get("id", ""))
			if GameState.get_relationship(ida, idb) >= min_score:
				return true
	return false


static func _has_strained_pair(max_score: int = 5) -> bool:
	var present: Array = _get_present_members()
	if present.size() < 2:
		return false
	for i in range(present.size()):
		var ma: Dictionary = present[i]
		var ida: String = str(ma.get("id", ""))
		for j in range(i + 1, present.size()):
			var mb: Dictionary = present[j]
			var idb: String = str(mb.get("id", ""))
			if GameState.get_relationship(ida, idb) <= max_score:
				return true
	return false


static func _has_stressed_or_breakdown_member() -> bool:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if int(m.get("sanity", 0)) >= 2 or int(m.get("breakdown_days", 0)) > 0:
			return true
	return false


static func _pick_most_stressed_member(default_member: Dictionary) -> Dictionary:
	var best: Dictionary = default_member
	var best_score: int = -1
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		var sc: int = int(m.get("sanity", 0)) * 3 + int(m.get("breakdown_days", 0)) * 4
		if sc > best_score:
			best_score = sc
			best = m
	return best


static func _pick_member_pair(rng: RandomNumberGenerator, prefer_strained: bool = false, prefer_bonded: bool = false) -> Array:
	var present: Array = _get_present_members()
	if present.is_empty():
		var fallback_m: Dictionary = {"id": "member_0", "name": "Ted", "age": 42, "role": "adult"}
		return [fallback_m, fallback_m]
	if present.size() == 1:
		var solo: Dictionary = present[0]
		return [solo, solo]

	var best_a: Dictionary = present[0]
	var best_b: Dictionary = present[1]
	if prefer_strained:
		var lowest: int = 999
		for i in range(present.size()):
			var ma: Dictionary = present[i]
			for j in range(i + 1, present.size()):
				var mb: Dictionary = present[j]
				var rel: int = GameState.get_relationship(str(ma.get("id", "")), str(mb.get("id", "")))
				if rel < lowest:
					lowest = rel
					best_a = ma
					best_b = mb
		return [best_a, best_b]
	elif prefer_bonded:
		var highest: int = -999
		for i in range(present.size()):
			var ma2: Dictionary = present[i]
			for j in range(i + 1, present.size()):
				var mb2: Dictionary = present[j]
				var rel2: int = GameState.get_relationship(str(ma2.get("id", "")), str(mb2.get("id", "")))
				if rel2 > highest:
					highest = rel2
					best_a = ma2
					best_b = mb2
		return [best_a, best_b]

	var idx_a: int = rng.randi_range(0, present.size() - 1)
	var idx_b: int = (idx_a + rng.randi_range(1, present.size() - 1)) % present.size()
	var ra: Dictionary = present[idx_a]
	var rb: Dictionary = present[idx_b]
	return [ra, rb]


static func _change_pair_relationship(id_a: String, id_b: String, delta: int) -> void:
	if id_a == "" or id_b == "" or id_a == id_b:
		return
	var prev: int = GameState.get_relationship(id_a, id_b)
	var nxt: int = GameState.change_relationship(id_a, id_b, delta)
	if nxt >= 55:
		GameState.unlock_achievement("unbreakable_bond")
		if prev < 55:
			GameState.run_metrics["bonds_formed"] = int(GameState.run_metrics.get("bonds_formed", 0)) + 1
	if delta <= -10:
		GameState.run_metrics["arguments_had"] = int(GameState.run_metrics.get("arguments_had", 0)) + 1


static func _change_all_bunker_relationships(delta: int) -> void:
	var present: Array = _get_present_members()
	if present.size() < 2:
		return
	var any_argument_logged: bool = false
	for i in range(present.size()):
		var ma: Dictionary = present[i]
		var ida: String = str(ma.get("id", ""))
		for j in range(i + 1, present.size()):
			var mb: Dictionary = present[j]
			var idb: String = str(mb.get("id", ""))
			if ida == "" or idb == "" or ida == idb:
				continue
			var prev: int = GameState.get_relationship(ida, idb)
			var nxt: int = GameState.change_relationship(ida, idb, delta)
			if nxt >= 55:
				GameState.unlock_achievement("unbreakable_bond")
				if prev < 55:
					GameState.run_metrics["bonds_formed"] = int(GameState.run_metrics.get("bonds_formed", 0)) + 1
	if delta <= -10 and not any_argument_logged:
		GameState.run_metrics["arguments_had"] = int(GameState.run_metrics.get("arguments_had", 0)) + 1


static func _grant_missing_vehicle_part_or_scrap(preferred_ids: Array) -> String:
	for p_v in preferred_ids:
		var pid: String = str(p_v)
		if GameState.vehicle_parts.has(pid) and not bool(GameState.vehicle_parts.get(pid, false)):
			GameState.vehicle_parts[pid] = true
			GameState.inventory_changed.emit()
			if GameState.get_vehicle_parts_owned_count() >= 2:
				GameState.unlock_achievement("road_warrior_parts")
			return pid
	var added: String = GameState.add_next_missing_vehicle_part()
	if added != "":
		if GameState.get_vehicle_parts_owned_count() >= 2:
			GameState.unlock_achievement("road_warrior_parts")
		return added
	GameState.add_scavenged_item("scrap", 1)
	return "scrap"


static func _grant_missing_vehicle_part_or_fuel(preferred_ids: Array) -> String:
	for p_v in preferred_ids:
		var pid: String = str(p_v)
		if GameState.vehicle_parts.has(pid) and not bool(GameState.vehicle_parts.get(pid, false)):
			GameState.vehicle_parts[pid] = true
			GameState.inventory_changed.emit()
			if GameState.get_vehicle_parts_owned_count() >= 2:
				GameState.unlock_achievement("road_warrior_parts")
			return pid
	var added: String = GameState.add_next_missing_vehicle_part()
	if added != "":
		if GameState.get_vehicle_parts_owned_count() >= 2:
			GameState.unlock_achievement("road_warrior_parts")
		return added
	GameState.add_scavenged_item("fuel", 1)
	return "fuel"


static func _get_pretty_part_name(part_id: String) -> String:
	match part_id:
		"battery":
			return "12V Car Battery"
		"alternator":
			return "Heavy-Duty Alternator"
		"spark_plugs":
			return "Copper Spark Plugs"
		"radiator_hose":
			return "Reinforced Radiator Hose"
		"fuel":
			return "Gasoline Jerrycan"
		"scrap":
			return "Salvaged Scrap Bundle"
		_:
			return "Station Wagon Engine Part"


static func _pick_mutant_candidate(rng: RandomNumberGenerator) -> Dictionary:
	var present: Array = _get_present_members()
	# Priority 1: Mary Jane or teen who isn't mutated yet (classic 60 Seconds! Mutant Mary Jane nod!)
	for m_v in present:
		var m: Dictionary = m_v
		if not bool(m.get("is_mutant", false)):
			var n_low: String = str(m.get("name", "")).to_lower()
			var r_low: String = str(m.get("role", "")).to_lower()
			if n_low.find("mary") != -1 or r_low == "teen":
				return m
	# Priority 2: Any non-mutant adult
	for m_v in present:
		var m: Dictionary = m_v
		if not bool(m.get("is_mutant", false)) and str(m.get("role", "")) == "adult":
			return m
	# Priority 3: Any non-mutant member
	for m_v in present:
		var m: Dictionary = m_v
		if not bool(m.get("is_mutant", false)):
			return m
	return _pick_random_member(rng)


static func _get_mutant_member() -> Dictionary:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if bool(m.get("is_mutant", false)):
			return m
	return {}


static func _get_member_with_trait(trait_name: String) -> Dictionary:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if str(m.get("trait", "")).to_lower() == trait_name.to_lower():
			return m
	return {}


static func _has_iron_stomach(target_member: Dictionary) -> bool:
	if str(target_member.get("trait", "")).to_lower() == "iron_stomach":
		return true
	return not _get_member_with_trait("iron_stomach").is_empty()


static func _has_severely_afflicted_member() -> bool:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if int(m.get("injury", 0)) >= 2 or int(m.get("sickness", 0)) >= 2:
			return true
	return false


static func _pick_thirstiest_member(default_member: Dictionary) -> Dictionary:
	var best: Dictionary = default_member
	var max_thirst: int = -1
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		var score: int = int(m.get("thirst", 0)) * 2 + int(m.get("days_without_water", 0))
		if score > max_thirst:
			max_thirst = score
			best = m
	return best


static func _get_broken_owned_item_ids() -> Array[String]:
	var res: Array[String] = []
	for k_v in GameState.bunker_items.keys():
		var k: String = str(k_v)
		var entry: Dictionary = GameState.bunker_items[k]
		if bool(entry.get("owned", false)) and bool(entry.get("broken", false)):
			res.append(k)
	return res


static func _add_soup_quarters(delta: int) -> void:
	GameState.soup_quarters = maxi(0, GameState.soup_quarters + delta)
	GameState.inventory_changed.emit()


static func _add_water_quarters(delta: int) -> void:
	GameState.water_quarters = maxi(0, GameState.water_quarters + delta)
	GameState.inventory_changed.emit()


static func _remove_durable_item(item_id: String) -> void:
	if GameState.bunker_items.has(item_id):
		GameState.bunker_items[item_id]["owned"] = false
		GameState.bunker_items[item_id]["broken"] = false
		GameState.bunker_items[item_id]["count"] = 0
		GameState.inventory_changed.emit()


static func _adjust_member_stat(member: Dictionary, stat_key: String, delta: int) -> void:
	if member.is_empty() or not member.has(stat_key):
		return
	if bool(member.get("is_mutant", false)) and stat_key in ["sickness", "injury", "thirst", "radiation"] and delta > 0:
		return
	member[stat_key] = clampi(int(member.get(stat_key, 0)) + delta, 0, 3)
	GameState.family_changed.emit()


static func _reduce_family_stress(amount: int) -> void:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if m.has("sanity"):
			m["sanity"] = maxi(0, int(m.get("sanity", 0)) - amount)
	GameState.family_changed.emit()


static func _increase_family_stress_safe(amount: int) -> void:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		m["sanity"] = mini(3, int(m.get("sanity", 0)) + amount)
	GameState.family_changed.emit()


static func _heal_one_afflicted_member() -> void:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if int(m.get("sickness", 0)) > 0 or int(m.get("injury", 0)) > 0:
			m["sickness"] = 0
			m["injury"] = 0
			m["status_note"] = "Treated by neighborhood medic."
			GameState.family_changed.emit()
			return


static func _heal_all_family_afflictions() -> int:
	var count: int = 0
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if int(m.get("sickness", 0)) > 0 or int(m.get("injury", 0)) > 0:
			m["sickness"] = 0
			m["injury"] = 0
			m["radiation"] = maxf(0.0, float(m.get("radiation", 0.0)) - 18.0)
			m["status_note"] = "Patched up with Wasteland medical care!"
			count += 1
	if count > 0:
		GameState.family_changed.emit()
	return count


static func _apply_mutant_transformation(member: Dictionary) -> String:
	var m_name: String = str(member.get("name", "Mary Jane"))
	member["is_mutant"] = true
	member["sickness"] = 0
	member["injury"] = 0
	member["fatigue"] = 0
	member["radiation"] = 0.0
	member["status_note"] = "Mutated! Lime-green glow, immune to fallout & pests!"
	GameState.unlock_achievement("mutant_awakening")
	GameState.family_changed.emit()
	return "ATOMIC TRANSFORMATION! Instead of getting sick, %s absorbed the glowing green isotope, healed every scratch, sprouted lime-green skin, and mutated into our bunker's fearless radioactive guardian!" % m_name

