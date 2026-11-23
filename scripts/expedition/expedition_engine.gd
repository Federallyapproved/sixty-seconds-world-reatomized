class_name ExpeditionEngine
extends RefCounted

## 3-Ring Real-World OpenStreetMap Wasteland Expedition Engine for "60 Seconds: World Reatomized" (V2).
## Turns real nearby & city-wide Neighborhood Houses, Supermarkets, Doctor's Offices, Pharmacies,
## Gas Stations / Auto Shops, Hardware Stores, Police/Fire Stations, Churches, and Schools across
## Ring 1 (<500m), Ring 2 (500..3500m), and Ring 3 (>=3500m) into high-stakes scavenging runs.

const CARRYABLE_GEAR_IDS: Array[String] = [
	"gas_mask", "rifle", "axe", "flashlight", "map", "suitcase"
]

const ITEM_NAMES: Dictionary = {
	"soup": "Tomato Soup",
	"water": "Drinking Water",
	"medkit": "First Aid Medkit",
	"antibiotics": "Prescription Antibiotics",
	"antirad": "Potassium Iodide Anti-Rad Pack",
	"scrap": "Salvaged Scrap",
	"fuel": "Gasoline Jerrycan",
	"vehicle_part": "Station Wagon Engine Part",
	"battery": "Heavy-Duty Car Battery",
	"alternator": "Station Wagon Alternator",
	"spark_plugs": "Ignition Spark Plugs",
	"radiator_hose": "Reinforced Radiator Hose",
	"gas_mask": "Gas Mask",
	"radio": "CONELRAD Radio",
	"flashlight": "Flashlight",
	"map": "Neighborhood Map",
	"book": "Scout Survival Handbook",
	"ammo": "Rifle Ammo",
	"bug_spray": "Bug Spray",
	"padlock": "Heavy Padlock",
	"cards": "Playing Cards",
	"checkers": "Checkers Set",
	"harmonica": "Harmonica",
	"axe": "Fireman's Axe",
	"rifle": "Hunting Rifle",
	"suitcase": "Leather Suitcase",
	"toolbox": "Repair Toolbox"
}


static func get_expedition_gear_ids() -> Array[String]:
	return CARRYABLE_GEAR_IDS.duplicate()


static func get_radiation_hazard_label(sv_hr: float = -1.0) -> String:
	var rad: float = GameState.surface_radiation_sv if sv_hr < 0.0 else sv_hr
	if rad < 1.5:
		return "Low"
	elif rad < 5.0:
		return "Moderate"
	return "EXTREME"


static func compute_ring_for_distance(dist_m: float) -> int:
	if dist_m < 500.0:
		return 1
	elif dist_m < 3500.0:
		return 2
	return 3


static func compute_base_travel_days(dist_m: float, ring: int = 0, cat: String = "") -> int:
	var r: int = ring if ring >= 1 and ring <= 3 else compute_ring_for_distance(dist_m)
	if cat == "neighbor_house" or cat == "house":
		return 1
	if r <= 1:
		return 1
	elif r == 2:
		return 2 if dist_m < 1850.0 else 3
	return 3 if dist_m < 6200.0 else 4


static func can_member_expedition(member: Dictionary) -> bool:
	if member.is_empty():
		return false
	if not bool(member.get("alive", false)) or not bool(member.get("in_bunker", false)):
		return false
	if bool(member.get("on_expedition", false)):
		return false
	if int(member.get("breakdown_days", 0)) > 0:
		return false
	return true


static func get_available_targets() -> Array:
	if GameState.nearby_pois.is_empty():
		GameState.nearby_pois = _generate_fallback_pois(GameState.selected_house)

	var rad_label: String = get_radiation_hazard_label(GameState.surface_radiation_sv)
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var raider_mult: float = float(diff_cfg.get("raider_mult", 1.0))
	var raider_aggr: float = float(GameState.nuke_config.get("raider_aggression", 0.45)) * raider_mult
	var house_lat: float = float(GameState.selected_house.get("lat", 47.6242))
	var house_lon: float = float(GameState.selected_house.get("lon", -122.3195))

	var enriched: Array = []
	for i in range(GameState.nearby_pois.size()):
		var raw_entry: Variant = GameState.nearby_pois[i]
		if not (raw_entry is Dictionary):
			continue
		var poi: Dictionary = raw_entry
		var cat: String = _normalize_category(poi)
		var dist_m: float = _extract_distance_m(poi, house_lat, house_lon, i)
		var ring: int = compute_ring_for_distance(dist_m)
		var bearing: String = _extract_bearing(poi, house_lat, house_lon, i)
		var base_name: String = _extract_base_name(poi, cat, i)
		var display_name: String = _format_target_display(base_name, dist_m, bearing)

		var computed_days: int = compute_base_travel_days(dist_m, ring, cat)
		var existing_days: int = int(poi.get("travel_days", 0))
		var travel_days: int = computed_days
		if ring == 1:
			travel_days = 1
		elif ring == 2 and existing_days >= 2 and existing_days <= 3:
			travel_days = existing_days
		elif ring == 3 and existing_days >= 3 and existing_days <= 4:
			travel_days = existing_days

		var visited_count: int = int(poi.get("visited_count", 0))
		var depleted: bool = visited_count >= 2 or bool(poi.get("depleted", false))
		if visited_count >= 2:
			depleted = true

		var risk_score: float = _compute_bandit_risk_prob(cat, ring, raider_aggr, visited_count)
		var bandit_risk: String = "Moderate"
		if risk_score < 0.34:
			bandit_risk = "Low"
		elif risk_score >= 0.45:
			bandit_risk = "High"

		var expected_loot: Array = _expected_loot_for_category(cat)

		poi["index"] = i
		poi["name"] = base_name
		poi["display_name"] = display_name
		poi["category"] = cat
		poi["ring"] = ring
		poi["ring_label"] = _format_ring_label(ring)
		poi["distance_m"] = roundf(dist_m)
		poi["bearing"] = bearing
		poi["bearing_dir"] = bearing
		poi["travel_days"] = travel_days
		poi["expected_days"] = travel_days
		poi["effective_days_with_map"] = maxi(1, travel_days - 1)
		poi["radiation_risk"] = rad_label
		poi["hazard_level"] = rad_label
		poi["risk_bandits"] = risk_score
		poi["bandit_risk"] = bandit_risk
		poi["expected_loot"] = expected_loot
		poi["loot_icons"] = expected_loot.duplicate()
		poi["visited_count"] = visited_count
		poi["depleted"] = depleted
		poi["sanctuary_site"] = (cat == "church" or cat == "school")

		GameState.nearby_pois[i] = poi
		enriched.append(poi)

	return enriched


static func compute_trip_days(member: Dictionary, poi: Dictionary, gear_ids: Array) -> int:
	var dist_m: float = float(poi.get("distance_m", 250.0))
	var ring: int = int(poi.get("ring", 0))
	if ring < 1 or ring > 3:
		ring = compute_ring_for_distance(dist_m)
	var cat: String = _normalize_category(poi)

	var base_days: int = int(poi.get("travel_days", 0))
	if base_days < 1 or base_days > 4:
		base_days = compute_base_travel_days(dist_m, ring, cat)
	else:
		base_days = clampi(base_days, 1, 4)

	var trait_id: String = str(member.get("trait", "")).to_lower()
	var map_broken: bool = false
	if GameState.bunker_items.has("map") and GameState.bunker_items["map"] is Dictionary:
		map_broken = bool((GameState.bunker_items["map"] as Dictionary).get("broken", false))

	var carried_working_map: bool = ("map" in gear_ids) and not map_broken
	if carried_working_map or trait_id == "scout" or trait_id == "sprinter":
		return maxi(1, base_days - 1)
	return base_days


static func start_expedition(member_id: String, poi_index: int, gear_ids: Array) -> String:
	if GameState.game_over:
		return ""
	if not GameState.active_expedition.is_empty():
		var out_name: String = str(GameState.active_expedition.get("member_name", "Someone"))
		return "%s is already outside scavenging the wasteland." % out_name

	var member: Dictionary = _find_living_bunker_member(member_id)
	if member.is_empty():
		return ""

	var member_name: String = str(member.get("name", "Survivor"))
	var bd_days: int = int(member.get("breakdown_days", 0))
	if bd_days > 0:
		return "%s is in the middle of an emotional breakdown (%dd remaining) and refuses to venture out through the blast hatch!" % [
			member_name, bd_days
		]

	var targets: Array = get_available_targets()
	if targets.is_empty():
		return ""

	var safe_idx: int = clampi(poi_index, 0, targets.size() - 1)
	var poi: Dictionary = targets[safe_idx]
	if bool(poi.get("depleted", false)):
		return "%s has been picked clean - there is nothing left worth the radiation. Choose another destination." % str(poi.get("name", "That place"))

	# Sanitize expedition gear: Suitcase allows Suitcase + up to 3 other items (4 total); without Suitcase, clamp to at most 1 item
	var valid_requested: Array[String] = []
	for raw_gid in gear_ids:
		var gid: String = str(raw_gid)
		if gid == "" or valid_requested.has(gid):
			continue
		if not (gid in CARRYABLE_GEAR_IDS) and not GameState.bunker_items.has(gid):
			continue
		if GameState.has_working_item(gid) and GameState.bunker_items.has(gid):
			valid_requested.append(gid)

	var sanitized_gear: Array[String] = []
	if valid_requested.has("suitcase"):
		var other_added: int = 0
		for gid in valid_requested:
			if gid == "suitcase":
				sanitized_gear.append(gid)
			elif other_added < 3:
				sanitized_gear.append(gid)
				other_added += 1
	else:
		if not valid_requested.is_empty():
			sanitized_gear.append(valid_requested[0])

	var days_away: int = compute_trip_days(member, poi, sanitized_gear)

	# Check out carried durable gear from the bunker so it accompanies the explorer
	var checked_out_gear: Array = []
	var checked_out_counts: Dictionary = {}
	for gid in sanitized_gear:
		var item_entry: Dictionary = GameState.bunker_items[gid]
		var prev_count: int = maxi(1, int(item_entry.get("count", 1)))
		checked_out_counts[gid] = prev_count
		if prev_count <= 1:
			item_entry["owned"] = false
			item_entry["count"] = 0
		else:
			item_entry["count"] = prev_count - 1
		item_entry["checked_out"] = true
		checked_out_gear.append(gid)

	var target_display: String = str(poi.get("display_name", poi.get("name", "Wasteland Ruins")))
	var base_name: String = str(poi.get("name", "Wasteland Ruins"))
	var category: String = _normalize_category(poi)
	var dist_m: float = float(poi.get("distance_m", 180.0))
	var ring: int = int(poi.get("ring", compute_ring_for_distance(dist_m)))
	var bearing: String = str(poi.get("bearing", "E"))

	member["on_expedition"] = true
	member["days_away"] = days_away
	member["status_note"] = "Scavenging %s (%dd remaining)." % [
		base_name, days_away
	]

	GameState.active_expedition = {
		"member_id": str(member.get("id", member_id)),
		"member_name": member_name,
		"poi_index": safe_idx,
		"poi": poi,
		"target_name": target_display,
		"short_target_name": base_name,
		"category": category,
		"ring": ring,
		"distance_m": dist_m,
		"bearing": bearing,
		"gear_ids": checked_out_gear,
		"checked_out_counts": checked_out_counts,
		"days_total": days_away,
		"days_remaining": days_away,
		"launch_day": GameState.day
	}

	GameState.inventory_changed.emit()
	GameState.family_changed.emit()

	var gear_phrase: String = "empty-handed and travelling light"
	if not checked_out_gear.is_empty():
		var gear_labels: Array[String] = []
		for gid_v in checked_out_gear:
			var g_str: String = str(gid_v)
			gear_labels.append(str(ITEM_NAMES.get(g_str, g_str.capitalize())))
		gear_phrase = "equipped with %s" % ", ".join(gear_labels)

	var speed_note: String = ""
	var trait_id: String = str(member.get("trait", "")).to_lower()
	if checked_out_gear.has("map"):
		speed_note = " Using the street map to cut through back alleys shaved precious hours off the Ring %d route." % ring
	elif trait_id == "scout" or trait_id == "sprinter":
		speed_note = " %s's quick footing across the rubble sped up the Ring %d trek." % [member_name, ring]

	var day_word: String = "day" if days_away == 1 else "days"
	return "We unbolted the heavy hatch at dusk: %s ventured topside toward %s [Ring %d], %s (expected return in %d %s).%s" % [
		member_name, target_display, ring, gear_phrase, days_away, day_word, speed_note
	]


static func tick_active_expedition() -> Dictionary:
	if GameState.active_expedition.is_empty():
		return {
			"active": false,
			"returned": false,
			"survived": true,
			"narrative": "",
			"loot": {}
		}

	var exp_data: Dictionary = GameState.active_expedition
	var member_id: String = str(exp_data.get("member_id", ""))
	var member_name: String = str(exp_data.get("member_name", "Survivor"))
	var target_display: String = str(exp_data.get("target_name", "the street above"))
	var short_target: String = str(exp_data.get("short_target_name", target_display))
	var days_remaining: int = int(exp_data.get("days_remaining", 1)) - 1
	exp_data["days_remaining"] = days_remaining

	var member: Dictionary = _find_member_any_state(member_id)
	if not member.is_empty():
		member["days_away"] = maxi(0, days_remaining)

	if days_remaining > 0:
		if not member.is_empty():
			member["status_note"] = "Exploring %s (%dd left)." % [short_target, days_remaining]
		var d_word: String = "day" if days_remaining == 1 else "days"
		var wait_line: String = "%s is still picking through the fallout toward %s (%d %s until expected return)." % [
			member_name, target_display, days_remaining, d_word
		]
		GameState.family_changed.emit()
		return {
			"active": true,
			"returned": false,
			"survived": true,
			"member_id": member_id,
			"member_name": member_name,
			"target_name": target_display,
			"days_remaining": days_remaining,
			"narrative": wait_line,
			"loot": {}
		}

	# Expedition has reached days_remaining <= 0 -> Resolve return!
	return _resolve_expedition_return(exp_data, member)


static func _resolve_expedition_return(exp_data: Dictionary, member: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = GameState.rng
	var member_id: String = str(exp_data.get("member_id", ""))
	var member_name: String = str(exp_data.get("member_name", "Survivor"))
	var poi_index: int = int(exp_data.get("poi_index", 0))
	var target_display: String = str(exp_data.get("target_name", "Neighborhood Ruins"))
	var short_target: String = str(exp_data.get("short_target_name", target_display))
	var raw_cat: String = str(exp_data.get("category", "neighbor_house"))
	var category: String = _normalize_category({"category": raw_cat, "name": short_target})
	var dist_m: float = float(exp_data.get("distance_m", 200.0))
	var ring: int = int(exp_data.get("ring", compute_ring_for_distance(dist_m)))
	var days_total: int = maxi(1, int(exp_data.get("days_total", 1)))
	var gear_ids: Array = exp_data.get("gear_ids", [])
	var checked_out_counts: Dictionary = exp_data.get("checked_out_counts", {})

	if member.is_empty() or not bool(member.get("alive", false)):
		_clear_checked_out_flags(gear_ids)
		GameState.active_expedition = {}
		GameState.inventory_changed.emit()
		GameState.family_changed.emit()
		return {
			"active": false,
			"returned": true,
			"survived": false,
			"member_id": member_id,
			"member_name": member_name,
			"target_name": target_display,
			"narrative": "%s never returned from %s." % [member_name, target_display],
			"loot": {}
		}

	var is_mutant: bool = bool(member.get("is_mutant", false))
	var trait_id: String = str(member.get("trait", "")).to_lower()
	var has_gas_mask: bool = gear_ids.has("gas_mask")
	var has_rifle: bool = gear_ids.has("rifle")
	var has_axe: bool = gear_ids.has("axe")
	var has_flashlight: bool = gear_ids.has("flashlight")
	var has_suitcase: bool = gear_ids.has("suitcase")
	var is_armed: bool = has_rifle or has_axe or is_mutant

	var story_parts: Array[String] = []
	story_parts.append(_build_arrival_prose(member_name, target_display, category, has_flashlight))

	# 1. Surface Radiation Exposure (90% blocked by Gas Mask; Mutants 100% immune)
	var sv_hr: float = GameState.surface_radiation_sv
	var raw_rad_dose: float = sv_hr * (3.2 + float(days_total) * 1.45)
	var rad_gained: float = 0.0
	if is_mutant:
		rad_gained = 0.0
		if sv_hr >= 4.0:
			story_parts.append("%s's mutated physiology shrugged off the %.1f Sv/hr fallout haze like morning mist." % [member_name, sv_hr])
	elif has_gas_mask:
		rad_gained = raw_rad_dose * 0.10
		if sv_hr >= 2.5:
			story_parts.append("The Gas Mask canisters hissed steadily, blocking 90%% of the %.1f Sv/hr radioactive ash drifting across the street." % sv_hr)
	else:
		rad_gained = raw_rad_dose
		var iron_mult: float = 0.5 if trait_id == "iron_stomach" else 1.0
		if sv_hr >= 5.0:
			story_parts.append("Without a Gas Mask in %.1f Sv/hr fallout, %s inhaled stinging ash and returned coughing with radiation burns!" % [sv_hr, member_name])
			if rng.randf() < (0.65 * iron_mult):
				member["sickness"] = maxi(int(member.get("sickness", 0)), 2)
			elif rng.randf() < iron_mult:
				member["sickness"] = maxi(int(member.get("sickness", 0)), 1)
		elif sv_hr >= 2.0 and rng.randf() < (0.35 * iron_mult):
			story_parts.append("Unfiltered fallout dust left %s queasy and rasping." % member_name)
			member["sickness"] = maxi(int(member.get("sickness", 0)), 1)

	member["radiation"] = float(member.get("radiation", 0.0)) + rad_gained

	# Retrieve & update POI visited count
	var poi_ref: Dictionary = exp_data.get("poi", {})
	if poi_index >= 0 and poi_index < GameState.nearby_pois.size():
		var stored_poi: Variant = GameState.nearby_pois[poi_index]
		if stored_poi is Dictionary:
			poi_ref = stored_poi
	var prior_visits: int = int(poi_ref.get("visited_count", 0))

	# 2. Bandit / Scavenger Ambush Resolution (Grocery has elevated 0.45+ contestation; Church is peaceful)
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var raider_mult: float = float(diff_cfg.get("raider_mult", 1.0))
	var raider_aggr: float = float(GameState.nuke_config.get("raider_aggression", 0.45)) * raider_mult
	if GameState.day <= 12:
		raider_aggr += float(GameState.neighborhood_modifiers.get("early_raider_mod", 0.0))
	var ambush_chance: float = _compute_bandit_risk_prob(category, ring, raider_aggr, prior_visits)
	if str(GameState.difficulty) == "tsar_bomba":
		ambush_chance = clampf(ambush_chance * 1.2 + 0.04, 0.0, 0.92)

	var was_ambushed: bool = rng.randf() < ambush_chance
	var loot_stolen_factor: float = 1.0
	var bonus_raider_loot: bool = false

	if was_ambushed:
		if has_rifle:
			if GameState.ammo_count > 0:
				GameState.break_or_consume_item("ammo")
				story_parts.append("Hostile raiders cornered %s outside %s, but a single warning crack from the Hunting Rifle sent them scrambling over abandoned cars!" % [member_name, short_target])
			else:
				story_parts.append("Desperate looters crept out of an alley near %s, until %s leveled the Hunting Rifle and backed them down without firing a shot!" % [short_target, member_name])
			if rng.randf() < 0.35:
				bonus_raider_loot = true
		elif has_axe:
			story_parts.append("Two masked scavengers lunged from behind a doorway at %s, but %s swung the Fireman's Axe through a crate and sent them fleeing!" % [short_target, member_name])
		elif is_mutant:
			story_parts.append("Wasteland bandits tried to ambush %s near %s—one glimpse of %s's glowing mutant eyes sent the gang sprinting in terror!" % [member_name, short_target, member_name])
		else:
			loot_stolen_factor = 0.55
			var wound_add: int = 1 if (trait_id == "tough" or rng.randf() < 0.65) else 2
			var prev_inj: int = int(member.get("injury", 0))
			var prev_sick: int = int(member.get("sickness", 0))
			var tsar_lethal: bool = str(GameState.difficulty) == "tsar_bomba" and prev_inj >= 2 and prev_sick >= 1
			if ((prev_inj >= 3 and prev_sick >= 2) or tsar_lethal) and rng.randf() < 0.35:
				member["alive"] = false
				member["on_expedition"] = false
				member["days_away"] = 0
				member["death_reason"] = "Overwhelmed by wasteland raiders near %s." % short_target
				member["status_note"] = str(member["death_reason"])
				poi_ref["visited_count"] = prior_visits + 1
				poi_ref["depleted"] = int(poi_ref["visited_count"]) >= 2
				if poi_index >= 0 and poi_index < GameState.nearby_pois.size():
					GameState.nearby_pois[poi_index] = poi_ref
				_clear_checked_out_flags(gear_ids)
				GameState.active_expedition = {}
				GameState.inventory_changed.emit()
				GameState.family_changed.emit()
				var tragic_msg: String = "Tragedy struck topside: already gravely weakened and unarmed, %s was ambushed near %s and never came back through the hatch." % [member_name, target_display]
				return {
					"active": false,
					"returned": true,
					"survived": false,
					"member_id": member_id,
					"member_name": member_name,
					"target_name": target_display,
					"category": category,
					"ring": ring,
					"ambushed": true,
					"rad_gained": rad_gained,
					"narrative": tragic_msg,
					"loot": {}
				}
			member["injury"] = mini(3, prev_inj + wound_add)
			story_parts.append("Unarmed near %s, %s was jumped by crowbar-wielding raiders who snatched nearly half the pack and left %s bruised and bleeding!" % [short_target, member_name, member_name])

	# 3. Restore Checked-Out Gear FIRST so _roll_category_loot / _pick_needed_durable sees carried gear as owned
	# and never overwrites newly scavenged item counts!
	var broken_gear: Array[String] = []
	for raw_gid in gear_ids:
		var gid: String = str(raw_gid)
		if not GameState.bunker_items.has(gid):
			continue
		var entry: Dictionary = GameState.bunker_items[gid]
		var restore_cnt: int = maxi(1, int(checked_out_counts.get(gid, 1)))
		entry["owned"] = true
		entry["checked_out"] = false
		entry["count"] = maxi(int(entry.get("count", 0)), restore_cnt)

	# 4. Calculate Scavenged Loot (Ring 1..3 bonus, Suitcase 2x, Flashlight +35%, Depletion scaling)
	var ring_mult: float = 1.0
	if ring == 2:
		ring_mult = 1.25
	elif ring >= 3:
		ring_mult = 1.55

	var mult: float = ring_mult
	if has_flashlight:
		mult *= 1.35
	if has_suitcase:
		mult *= 2.0
	if trait_id == "scout":
		mult *= 1.15
	if prior_visits == 1:
		mult *= 0.62
	elif prior_visits >= 2:
		mult *= 0.35
	mult *= loot_stolen_factor

	var loot_dict: Dictionary = _roll_category_loot(category, ring, mult, rng, prior_visits)
	if bonus_raider_loot:
		loot_dict["soup"] = int(loot_dict.get("soup", 0)) + 1

	var loot_labels: Array[String] = []
	for item_key in loot_dict.keys():
		var iid: String = str(item_key)
		var qty: int = int(loot_dict.get(iid, 0))
		if qty <= 0:
			continue

		if iid == "vehicle_part":
			for _vp_i in range(qty):
				var installed_part: String = GameState.add_next_missing_vehicle_part()
				if installed_part != "":
					var p_label: String = str(ITEM_NAMES.get(installed_part, installed_part.capitalize()))
					loot_labels.append(p_label)
				else:
					GameState.add_scavenged_item("scrap", 1)
					loot_labels.append("Salvaged Scrap")
			if GameState.get_vehicle_parts_owned_count() >= 2:
				GameState.unlock_achievement("road_warrior_parts")
			continue

		GameState.add_scavenged_item(iid, qty)
		if GameState.VEHICLE_PART_IDS.has(iid) and GameState.get_vehicle_parts_owned_count() >= 2:
			GameState.unlock_achievement("road_warrior_parts")

		var nice_name: String = str(ITEM_NAMES.get(iid, iid.capitalize()))
		if iid == "soup":
			loot_labels.append("%d %s" % [qty, "can of Soup" if qty == 1 else "cans of Soup"])
		elif iid == "water":
			loot_labels.append("%d %s" % [qty, "bottle of Water" if qty == 1 else "bottles of Water"])
		elif iid == "ammo":
			loot_labels.append("%d %s" % [qty * 2, "Rifle rounds"])
		elif iid == "fuel":
			loot_labels.append("%d %s" % [qty, "Jerrycan of Fuel" if qty == 1 else "Jerrycans of Fuel"])
		elif qty > 1:
			loot_labels.append("%dx %s" % [qty, nice_name])
		else:
			loot_labels.append(nice_name)

	if has_suitcase and not loot_labels.is_empty():
		story_parts.append("Stuffing the Leather Suitcase doubled what %s could haul home!" % member_name)
	elif has_flashlight and not loot_labels.is_empty():
		story_parts.append("The Flashlight beam uncovered untouched shelves in the pitch-black back room (+35%% haul).")

	var loot_summary: String = "nothing but empty wrappers"
	if not loot_labels.is_empty():
		loot_summary = ", ".join(loot_labels)
	story_parts.append("Three sharp knocks echoed on the bunker hatch—%s returned carrying: %s." % [member_name, loot_summary])

	# 5. Category-Specific On-Site Effects, Rescue Chains, Harmony & Achievements
	if category == "grocery":
		GameState.story_flags["grocery_looted"] = true
		if int(loot_dict.get("soup", 0)) > 0 or int(loot_dict.get("water", 0)) > 0:
			GameState.unlock_achievement("grocery_haul")

	elif category == "doctor":
		GameState.unlock_achievement("doctor_house")
		var prev_d_inj: int = int(member.get("injury", 0))
		var prev_d_sick: int = int(member.get("sickness", 0))
		if prev_d_inj > 0 or prev_d_sick > 0:
			member["injury"] = maxi(0, prev_d_inj - 1)
			member["sickness"] = maxi(0, prev_d_sick - 1)
			if int(member.get("injury", 0)) == 0:
				member["injury_days"] = 0
			if int(member.get("sickness", 0)) == 0:
				member["sick_days"] = 0
			story_parts.append("Inside the exam room at %s, %s treated wounds and fever with sterile clinic supplies (-1 injury / -1 sickness)!" % [short_target, member_name])
		if ring >= 3 and prior_visits == 0:
			member["injury"] = 0
			member["sickness"] = 0
			member["injury_days"] = 0
			member["sick_days"] = 0
			member["radiation"] = maxf(0.0, float(member.get("radiation", 0.0)) - 20.0)
			story_parts.append("The deep-ring medical centre still had a working decon shower and an intact surgery - %s came home fully patched up." % member_name)

	elif category == "pharmacy":
		if int(member.get("sanity", 0)) > 0:
			member["sanity"] = maxi(0, int(member.get("sanity", 0)) - 1)
			story_parts.append("Calming pharmacy tonics from %s steadied %s's nerves (-1 stress)." % [short_target, member_name])

	poi_ref["visited_count"] = prior_visits + 1
	poi_ref["depleted"] = int(poi_ref["visited_count"]) >= 2
	if poi_index >= 0 and poi_index < GameState.nearby_pois.size():
		GameState.nearby_pois[poi_index] = poi_ref

	var sanctuary_advanced: bool = false
	if category == "church":
		var cur_sanc: int = int(GameState.rescue_chains.get("sanctuary", 0))
		if cur_sanc < 2 and prior_visits == 0:
			var next_sanc: int = mini(3, cur_sanc + 1)
			GameState.rescue_chains["sanctuary"] = next_sanc
			sanctuary_advanced = true
			if next_sanc == 1:
				story_parts.append("Inside %s, %s traded peaceful Civil Defense hand signals with candlelit parish volunteers organizing a relief shelter (Sanctuary 1/3)." % [short_target, member_name])
			elif next_sanc == 2:
				story_parts.append("Parish volunteers fortified inside %s shared rainwater blueprints and marked our address on their rescue roster (Sanctuary 2/3)!" % short_target)
			else:
				story_parts.append("The parish council at %s rang their sanctuary bell and dispatched an escort convoy directly to our street (Sanctuary 3/3)!" % short_target)

		# +10 Family Relationship Harmony across everyone in the shelter!
		_grant_shelter_harmony_bonus(10)
		story_parts.append("Messages of hope and altar candles from %s warmed everyone's heart (+10 family harmony across the shelter ♥)!" % short_target)

	elif category == "school":
		var cur_sanc_sch: int = int(GameState.rescue_chains.get("sanctuary", 0))
		if cur_sanc_sch < 2 and prior_visits == 0 and (ring >= 2 or rng.randf() < 0.65):
			var next_sanc_sch: int = mini(3, cur_sanc_sch + 1)
			GameState.rescue_chains["sanctuary"] = next_sanc_sch
			sanctuary_advanced = true
			story_parts.append("Survivors organizing a Civil Defense classroom hub at %s logged our shelter coordinates (Sanctuary %d/3)!" % [short_target, next_sanc_sch])

	elif category == "civic" and ring >= 2:
		var cur_mil: int = int(GameState.rescue_chains.get("military", 0))
		if cur_mil < 2 and prior_visits == 0:
			var next_mil: int = mini(3, cur_mil + 1)
			GameState.rescue_chains["military"] = next_mil
			story_parts.append("From the dispatch radio room inside %s, %s recovered encrypted Civil Defense evacuation frequencies (Military %d/3)!" % [short_target, member_name, next_mil])

	# 6. Realistic Minor Wear Chance on Carried Gear (if not handy and not freshly scavenged)
	if not gear_ids.is_empty() and trait_id != "handy":
		var wear_chance: float = 0.06 if is_armed else 0.20
		if was_ambushed and not is_armed:
			wear_chance = 0.35
		if rng.randf() < wear_chance:
			var pick_idx: int = rng.randi_range(0, gear_ids.size() - 1)
			var worn_gid: String = str(gear_ids[pick_idx])
			if GameState.bunker_items.has(worn_gid) and not loot_dict.has(worn_gid):
				GameState.break_or_consume_item(worn_gid)
				broken_gear.append(worn_gid)
				var worn_label: String = str(ITEM_NAMES.get(worn_gid, worn_gid.capitalize()))
				story_parts.append("Rough scrapes on the trip cracked our %s (needs Toolbox or Scrap repair)." % worn_label)

	# 7. Explorer Fatigue, Soot, Scars, Gratitude Relationship & Metrics
	member["on_expedition"] = false
	member["days_away"] = 0
	member["in_bunker"] = true
	member["soot_days"] = 2
	member["expedition_scars"] = int(member.get("expedition_scars", 0)) + (1 if ring >= 2 else 0)
	member["last_bubble"] = "♥"
	member["fatigue"] = mini(2, int(member.get("fatigue", 0)) + 1)
	if not is_mutant:
		var trek_strain: int = clampi(int(ceil(float(days_total) / 2.0)), 1, 3)
		member["days_without_water"] = int(member.get("days_without_water", 0)) + trek_strain
		member["days_without_food"] = int(member.get("days_without_food", 0)) + trek_strain
		member["thirst"] = mini(3, int(member.get("thirst", 0)) + trek_strain)
		member["hunger"] = mini(3, int(member.get("hunger", 0)) + trek_strain)
	member["status_note"] = "Back from %s, catching breath." % short_target

	GameState.change_member_relationships_with_all(member_id, 10, true)

	GameState.run_metrics["expeditions_completed"] = int(GameState.run_metrics.get("expeditions_completed", 0)) + 1
	if ring >= 2 or dist_m >= 500.0:
		GameState.run_metrics["distant_landmarks_looted"] = int(GameState.run_metrics.get("distant_landmarks_looted", 0)) + 1
	if dist_m >= 1500.0:
		GameState.unlock_achievement("deep_trek")

	GameState.active_expedition = {}
	GameState.inventory_changed.emit()
	GameState.family_changed.emit()

	return {
		"active": false,
		"returned": true,
		"survived": true,
		"member_id": member_id,
		"member_name": member_name,
		"target_name": target_display,
		"category": category,
		"ring": ring,
		"distance_m": dist_m,
		"loot": loot_dict,
		"loot_summary": loot_summary,
		"broken_gear": broken_gear,
		"sanctuary_advanced": sanctuary_advanced,
		"ambushed": was_ambushed,
		"rad_gained": rad_gained,
		"narrative": " ".join(story_parts)
	}


static func _roll_category_loot(category: String, ring: int, mult: float, rng: RandomNumberGenerator, prior_visits: int = 0) -> Dictionary:
	var loot: Dictionary = {}
	match category:
		"grocery", "restaurant":
			var base_soup: int = rng.randi_range(2, 3) if ring == 1 else (rng.randi_range(4, 5) if ring == 2 else rng.randi_range(6, 8))
			var base_water: int = rng.randi_range(3, 4) if ring <= 2 else rng.randi_range(4, 5)
			# Ring multiplier is already baked into base_soup, so strip it from mult to avoid double-dipping
			var grocery_scale: float = clampf(mult / maxf(1.0, 1.0 + float(ring - 1) * 0.275), 0.55, 2.5)
			loot["soup"] = maxi(2, roundi(float(base_soup) * grocery_scale))
			loot["water"] = maxi(2, roundi(float(base_water) * grocery_scale))
			if rng.randf() < 0.28 * mult:
				loot["bug_spray"] = 1

		"doctor":
			if ring >= 3 and prior_visits == 0:
				# Deep-ring medical centre jackpot: a fully stocked clinic dispensary
				loot["antibiotics"] = 2
				loot["medkit"] = 2
				loot["antirad"] = 2
			else:
				var abx_cnt: int = 2 if (ring >= 2 or mult >= 1.65 or rng.randf() < 0.45) else 1
				loot["antibiotics"] = abx_cnt
				loot["medkit"] = 2 if mult >= 2.1 else 1
				if ring >= 2 or rng.randf() < 0.55:
					loot["antirad"] = 1

		"pharmacy":
			var ar_cnt: int = 2 if (ring >= 2 or mult >= 1.65 or rng.randf() < 0.45) else 1
			loot["antirad"] = ar_cnt
			loot["medkit"] = 2 if mult >= 2.1 else 1
			if rng.randf() < 0.50:
				loot["bug_spray"] = 1
			if mult >= 1.25:
				loot["water"] = 1

		"fuel_auto":
			var fuel_cnt: int = 2 if (ring >= 2 or mult >= 1.60 or rng.randf() < 0.45) else 1
			loot["fuel"] = fuel_cnt
			loot["scrap"] = 2 if mult >= 1.85 else 1
			if ring >= 3 and prior_visits == 0:
				# Deep-ring truck stop / auto yard jackpot
				loot["fuel"] = rng.randi_range(2, 3)
				loot["scrap"] = 2
				var parts_jp: int = 1 if str(GameState.difficulty) == "tsar_bomba" else 2
				var missing_parts: int = maxi(0, 4 - GameState.get_vehicle_parts_owned_count())
				if missing_parts > 0:
					loot["vehicle_part"] = mini(parts_jp, missing_parts)
				else:
					loot["scrap"] = 3
			elif prior_visits == 0 and GameState.get_vehicle_parts_owned_count() < 4:
				loot["vehicle_part"] = 1
			else:
				loot["scrap"] = int(loot["scrap"]) + 1

		"hardware":
			loot["scrap"] = 2 if (ring >= 2 or mult >= 1.50 or rng.randf() < 0.50) else 1
			var hw_pool: Array[String] = ["toolbox", "axe", "rifle", "ammo", "padlock", "flashlight"]
			var picked_durable: String = _pick_needed_durable(hw_pool, rng)
			if picked_durable != "":
				loot[picked_durable] = maxi(1, int(loot.get(picked_durable, 0)))
			if mult >= 1.65:
				var second_hw: String = _pick_needed_durable(["rifle", "ammo", "padlock", "toolbox", "axe"], rng)
				if second_hw != "" and not loot.has(second_hw):
					loot[second_hw] = 1
			if GameState.get_vehicle_parts_owned_count() < 4 and rng.randf() < 0.45:
				loot["vehicle_part"] = 1

		"civic":
			loot["ammo"] = maxi(1, roundi(1.1 * clampf(mult, 0.8, 2.2)))
			loot["water"] = maxi(1, roundi(1.0 * clampf(mult, 0.8, 2.0)))
			var civic_gear: String = _pick_needed_durable(["rifle", "gas_mask", "radio"], rng)
			if civic_gear != "":
				loot[civic_gear] = 1
			if ring >= 2 or mult >= 1.75:
				var civic_extra: String = _pick_needed_durable(["gas_mask", "radio", "rifle", "medkit"], rng)
				if civic_extra != "" and not loot.has(civic_extra):
					loot[civic_extra] = 1

		"church":
			loot["water"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * clampf(mult, 0.8, 2.2)))
			loot["medkit"] = 1
			if rng.randf() < 0.70:
				loot["soup"] = maxi(1, roundi(1.1 * clampf(mult, 0.8, 2.0)))
			var church_gift: String = _pick_needed_durable(["book", "harmonica", "cards"], rng)
			if church_gift != "" and rng.randf() < 0.45:
				loot[church_gift] = 1

		"school":
			var school_primary: String = _pick_needed_durable(["map", "book", "flashlight", "checkers", "cards"], rng)
			if school_primary != "":
				loot[school_primary] = 1
			if ring >= 2 or mult >= 1.50:
				var school_second: String = _pick_needed_durable(["book", "map", "checkers", "cards", "flashlight"], rng)
				if school_second != "" and not loot.has(school_second):
					loot[school_second] = 1
			loot["soup"] = maxi(1, roundi(1.0 * clampf(mult, 0.8, 2.0)))
			loot["water"] = maxi(1, roundi(1.0 * clampf(mult, 0.8, 2.0)))

		_:
			# "neighbor_house" / fast 1-day household scavenge
			loot["soup"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * clampf(mult, 0.75, 2.2)))
			loot["water"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * clampf(mult, 0.75, 2.2)))
			var home_pool: Array[String] = [
				"cards", "padlock", "flashlight", "medkit", "ammo",
				"suitcase", "radio", "checkers", "harmonica", "bug_spray"
			]
			if rng.randf() < 0.70 * clampf(mult, 0.7, 1.6):
				var home_pick: String = _pick_needed_durable(home_pool, rng)
				if home_pick != "":
					loot[home_pick] = 1

	return loot


static func _compute_bandit_risk_prob(cat: String, ring: int, raider_aggr: float, visited_count: int) -> float:
	var base: float = 0.18 + raider_aggr * 0.28 + float(ring - 1) * 0.06 + float(visited_count) * 0.06
	match cat:
		"grocery":
			base = maxf(0.45, 0.36 + raider_aggr * 0.24 + float(ring - 1) * 0.06 + float(visited_count) * 0.05)
		"fuel_auto":
			base += 0.08
		"civic", "hardware":
			base += 0.05
		"doctor", "pharmacy":
			base += 0.04
		"church":
			base -= 0.18
		"school":
			base -= 0.10
		"neighbor_house", "house":
			base -= 0.05
	return clampf(base, 0.06, 0.75)


static func _grant_shelter_harmony_bonus(delta: int) -> void:
	var members: Array = GameState.get_all_living_members()
	for i in range(members.size()):
		if not (members[i] is Dictionary):
			continue
		var ma: Dictionary = members[i]
		ma["last_bubble"] = "♥"
		var ida: String = str(ma.get("id", ""))
		for j in range(i + 1, members.size()):
			if not (members[j] is Dictionary):
				continue
			var mb: Dictionary = members[j]
			var idb: String = str(mb.get("id", ""))
			if ida != "" and idb != "":
				GameState.change_relationship(ida, idb, delta)


static func _pick_needed_durable(pool: Array[String], rng: RandomNumberGenerator) -> String:
	var missing: Array[String] = []
	for gid in pool:
		if not GameState.has_working_item(gid):
			missing.append(gid)
	if not missing.is_empty():
		return missing[rng.randi_range(0, missing.size() - 1)]
	if not pool.is_empty():
		return pool[rng.randi_range(0, pool.size() - 1)]
	return ""


static func _clear_checked_out_flags(gear_ids: Array) -> void:
	for raw_gid in gear_ids:
		var gid: String = str(raw_gid)
		if GameState.bunker_items.has(gid) and GameState.bunker_items[gid] is Dictionary:
			GameState.bunker_items[gid]["checked_out"] = false


static func _build_arrival_prose(member_name: String, target_display: String, category: String, has_flashlight: bool) -> String:
	var light_clause: String = "sweeping a Flashlight beam across dusty aisles" if has_flashlight else "feeling through dim shafts of amber fallout light"
	match category:
		"grocery", "restaurant":
			return "%s crept beneath shattered neon signage into %s, %s for intact soup tins and bottled water." % [member_name, target_display, light_clause]
		"doctor":
			return "%s slipped through the triage doors of %s, %s across steel medicine cabinets and exam trays." % [member_name, target_display, light_clause]
		"pharmacy":
			return "%s pried open the security grille at %s, %s behind the prescription counter." % [member_name, target_display, light_clause]
		"fuel_auto":
			return "%s crouched past rusted fuel pumps into the service bay of %s, %s for jerrycans and intact engine parts." % [member_name, target_display, light_clause]
		"hardware":
			return "%s slipped through the loading bay of %s, %s among toppled tool racks, scrap bins, and workbenches." % [member_name, target_display, light_clause]
		"civic":
			return "%s picked past sandbags into %s, searching emergency Civil Defense lockers and radio dispatch consoles." % [member_name, target_display]
		"church":
			return "%s reached the stone steps of %s, where stained-glass shards glinted in the haze and Civil Defense candles flickered inside." % [member_name, target_display]
		"school":
			return "%s crossed the ash-dusted courtyard of %s, checking library map drawers, emergency lockers, and the cafeteria pantry." % [member_name, target_display]
		_:
			return "%s vaulted a splintered picket fence to search %s, %s from kitchen cupboards to cellar stairs." % [member_name, target_display, light_clause]


static func _find_living_bunker_member(member_id: String) -> Dictionary:
	for raw_m in GameState.family_members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		if str(m.get("id", "")) == member_id:
			if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)) and not bool(m.get("on_expedition", false)):
				return m
	return {}


static func _find_member_any_state(member_id: String) -> Dictionary:
	for raw_m in GameState.family_members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		if str(m.get("id", "")) == member_id:
			return m
	return {}


static func _normalize_category(poi: Dictionary) -> String:
	var raw_cat: String = str(poi.get("category", poi.get("type", poi.get("poi_type", poi.get("amenity", poi.get("shop", poi.get("building_type", ""))))))).to_lower().strip_edges()

	if raw_cat in ["neighbor_house", "house", "neighbor", "neighbour", "residential", "detached", "apartments", "terrace", "semidetached_house"]:
		return "neighbor_house"
	if raw_cat in ["grocery", "supermarket", "convenience", "bakery", "greengrocer", "deli", "market", "marketplace", "restaurant", "cafe", "fast_food", "diner"]:
		return "grocery"
	if raw_cat in ["doctor", "doctors", "clinic", "hospital", "urgent_care", "medical", "dentist", "healthcare", "veterinary"]:
		return "doctor"
	if raw_cat in ["pharmacy", "chemist", "drugstore", "apothecary", "medical_supply"]:
		return "pharmacy"
	if raw_cat in ["fuel_auto", "fuel", "gas_station", "car_repair", "car_parts", "auto_repair", "tyres", "service_station", "automotive"]:
		return "fuel_auto"
	if raw_cat in ["hardware", "doityourself", "trade", "industrial", "storage", "locksmith", "tools", "lumber"]:
		return "hardware"
	if raw_cat in ["civic", "fire_station", "police", "ambulance_station", "civil_defence", "ranger_station", "townhall", "government"]:
		return "civic"
	if raw_cat in ["church", "place_of_worship", "chapel", "cathedral", "synagogue", "mosque", "temple", "shrine"]:
		return "church"
	if raw_cat in ["school", "library", "college", "university", "kindergarten", "community_centre", "books"]:
		return "school"

	# Fallback keyword inference from POI name
	var nm: String = str(poi.get("name", poi.get("label", ""))).to_lower()
	if nm.find("urgent care") != -1 or nm.find("doctor") != -1 or nm.find("clinic") != -1 or nm.find("hospital") != -1 or nm.find("medical") != -1 or nm.find("physician") != -1:
		return "doctor"
	if nm.find("pharm") != -1 or nm.find("walgreens") != -1 or nm.find("cvs") != -1 or nm.find("rite aid") != -1 or nm.find("drug") != -1:
		return "pharmacy"
	if nm.find("shell") != -1 or nm.find("chevron") != -1 or nm.find("mobil") != -1 or nm.find("texaco") != -1 or nm.find("auto") != -1 or nm.find("gas") != -1 or nm.find("fuel") != -1 or nm.find("garage") != -1 or nm.find("tire") != -1:
		return "fuel_auto"
	if nm.find("market") != -1 or nm.find("grocery") != -1 or nm.find("qfc") != -1 or nm.find("supermarket") != -1 or nm.find("bakery") != -1 or nm.find("food") != -1 or nm.find("meyer") != -1:
		return "grocery"
	if nm.find("church") != -1 or nm.find("parish") != -1 or nm.find("chapel") != -1 or nm.find("cathedral") != -1 or nm.find("pilgrim") != -1 or nm.find("st.") != -1:
		return "church"
	if nm.find("hardware") != -1 or nm.find("supply") != -1 or nm.find("lumber") != -1 or nm.find("tool") != -1:
		return "hardware"
	if nm.find("school") != -1 or nm.find("library") != -1 or nm.find("elementary") != -1 or nm.find("high") != -1 or nm.find("academy") != -1:
		return "school"
	if nm.find("fire") != -1 or nm.find("police") != -1 or nm.find("precinct") != -1 or nm.find("station") != -1:
		return "civic"
	return "neighbor_house"


static func _extract_distance_m(poi: Dictionary, house_lat: float, house_lon: float, idx: int) -> float:
	if poi.has("distance_m") and float(poi.get("distance_m", 0.0)) > 1.0:
		return float(poi.get("distance_m", 150.0))
	if poi.has("dist_m") and float(poi.get("dist_m", 0.0)) > 1.0:
		return float(poi.get("dist_m", 150.0))
	if poi.has("distance") and float(poi.get("distance", 0.0)) > 1.0:
		return float(poi.get("distance", 150.0))
	if poi.has("lat") and poi.has("lon"):
		var p_lat: float = float(poi.get("lat", house_lat))
		var p_lon: float = float(poi.get("lon", house_lon))
		var d_lat_m: float = (p_lat - house_lat) * 111320.0
		var d_lon_m: float = (p_lon - house_lon) * 111320.0 * cos(deg_to_rad(house_lat))
		var computed: float = sqrt(d_lat_m * d_lat_m + d_lon_m * d_lon_m)
		if computed > 5.0:
			return clampf(computed, 25.0, 12000.0)
	return float(85 + idx * 180)


static func _extract_bearing(poi: Dictionary, house_lat: float, house_lon: float, idx: int) -> String:
	var raw_b: String = str(poi.get("bearing", poi.get("bearing_dir", poi.get("direction", poi.get("compass", ""))))).strip_edges().to_upper()
	if raw_b in ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]:
		return raw_b
	if poi.has("lat") and poi.has("lon"):
		var p_lat: float = float(poi.get("lat", house_lat))
		var p_lon: float = float(poi.get("lon", house_lon))
		var dy: float = p_lat - house_lat
		var dx: float = (p_lon - house_lon) * cos(deg_to_rad(house_lat))
		if absf(dx) > 0.00001 or absf(dy) > 0.00001:
			var angle_deg: float = fposmod(rad_to_deg(atan2(dx, dy)), 360.0)
			var dirs: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
			var dir_idx: int = int(round(angle_deg / 45.0)) % 8
			return dirs[dir_idx]
	var fallback_dirs: Array[String] = ["E", "SE", "SW", "N", "NE", "NW", "S", "W"]
	return fallback_dirs[idx % fallback_dirs.size()]


static func _extract_base_name(poi: Dictionary, cat: String, idx: int) -> String:
	var nm: String = str(poi.get("name", poi.get("label", poi.get("title", poi.get("address", ""))))).strip_edges()
	if nm != "":
		var paren_pos: int = nm.rfind("(")
		if paren_pos > 2 and nm.ends_with(")"):
			var tail: String = nm.substr(paren_pos)
			if tail.find("m ") != -1 or tail.find("km ") != -1:
				nm = nm.substr(0, paren_pos).strip_edges()
		return nm
	match cat:
		"grocery":
			return "Neighborhood Grocery Market"
		"doctor":
			return "Family Urgent Care & Clinic"
		"pharmacy":
			return "Corner Drugstore & Pharmacy"
		"fuel_auto":
			return "Service Station & Auto Repair"
		"hardware":
			return "Hardware & Lumber Supply"
		"civic":
			return "Municipal Fire & Police Station"
		"church":
			return "Community Parish Church"
		"school":
			return "Public School & Library"
		_:
			return "Neighboring House #%d" % (idx + 1)


static func _format_target_display(base_name: String, dist_m: float, bearing: String) -> String:
	if dist_m >= 1000.0:
		return "%s (%.1fkm %s)" % [base_name, dist_m / 1000.0, bearing]
	return "%s (%dm %s)" % [base_name, int(round(dist_m)), bearing]


static func _format_ring_label(ring: int) -> String:
	match ring:
		1:
			return "Ring 1 (<0.5 km)"
		2:
			return "Ring 2 (0.5-3.5 km)"
		_:
			return "Ring 3 (3.5+ km)"


static func _expected_loot_for_category(cat: String) -> Array:
	match cat:
		"grocery":
			return ["soup", "water", "bug_spray"]
		"doctor":
			return ["antibiotics", "medkit", "antirad"]
		"pharmacy":
			return ["antirad", "medkit", "bug_spray"]
		"fuel_auto":
			return ["fuel", "vehicle_part", "scrap"]
		"hardware":
			return ["scrap", "toolbox", "axe", "rifle", "vehicle_part"]
		"civic":
			return ["rifle", "ammo", "gas_mask", "radio"]
		"church":
			return ["water", "medkit", "soup"]
		"school":
			return ["book", "map", "checkers", "flashlight"]
		_:
			return ["soup", "water", "cards", "padlock"]


static func _generate_fallback_pois(house: Dictionary) -> Array:
	var addr: String = str(house.get("address", "518 E Roy St, Capitol Hill, Seattle, WA"))
	var addr_lower: String = addr.to_lower()
	var h_lat: float = float(house.get("lat", 47.6242))
	var h_lon: float = float(house.get("lon", -122.3195))

	if addr_lower.find("concord") != -1:
		return [
			{"name": "Neighboring Colonial House", "category": "neighbor_house", "distance_m": 68.0, "bearing": "W", "lat": h_lat, "lon": h_lon - 0.0009},
			{"name": "Crosby's Marketplace", "category": "grocery", "distance_m": 255.0, "bearing": "SE", "lat": h_lat - 0.0016, "lon": h_lon + 0.0018},
			{"name": "First Parish Church in Concord", "category": "church", "distance_m": 205.0, "bearing": "E", "lat": h_lat + 0.0002, "lon": h_lon + 0.0024},
			{"name": "Concord Family Pharmacy", "category": "pharmacy", "distance_m": 320.0, "bearing": "SW", "lat": h_lat - 0.0021, "lon": h_lon - 0.0020},
			{"name": "Concord Free Public Library", "category": "school", "distance_m": 240.0, "bearing": "NE", "lat": h_lat + 0.0015, "lon": h_lon + 0.0018},
			{"name": "Thoreau Street Shell & Auto", "category": "fuel_auto", "distance_m": 820.0, "bearing": "S", "lat": h_lat - 0.0072, "lon": h_lon - 0.0012},
			{"name": "Vanderhoof Hardware & Lumber", "category": "hardware", "distance_m": 960.0, "bearing": "N", "lat": h_lat + 0.0085, "lon": h_lon + 0.0006},
			{"name": "Concord Fire & Police HQ", "category": "civic", "distance_m": 1280.0, "bearing": "W", "lat": h_lat + 0.0010, "lon": h_lon - 0.0150},
			{"name": "Emerson Hospital & Urgent Care", "category": "doctor", "distance_m": 2150.0, "bearing": "SW", "lat": h_lat - 0.0145, "lon": h_lon - 0.0165},
			{"name": "Route 2 Automotive & Fuel Depot", "category": "fuel_auto", "distance_m": 4100.0, "bearing": "SE", "lat": h_lat - 0.0260, "lon": h_lon + 0.0320},
			{"name": "Acton Regional Supermarket Plaza", "category": "grocery", "distance_m": 5400.0, "bearing": "NW", "lat": h_lat + 0.0350, "lon": h_lon - 0.0420}
		]
	elif addr_lower.find("brooklyn") != -1 or addr_lower.find("carroll") != -1:
		return [
			{"name": "Neighboring Carroll St Brownstone", "category": "neighbor_house", "distance_m": 58.0, "bearing": "E", "lat": h_lat, "lon": h_lon + 0.0007},
			{"name": "Union Market Carroll Gardens", "category": "grocery", "distance_m": 220.0, "bearing": "N", "lat": h_lat + 0.0020, "lon": h_lon + 0.0002},
			{"name": "Sacred Hearts & St. Stephen Church", "category": "church", "distance_m": 190.0, "bearing": "NW", "lat": h_lat + 0.0013, "lon": h_lon - 0.0014},
			{"name": "Court Street Corner Pharmacy", "category": "pharmacy", "distance_m": 305.0, "bearing": "NE", "lat": h_lat + 0.0021, "lon": h_lon + 0.0019},
			{"name": "P.S. 58 The Carroll School", "category": "school", "distance_m": 275.0, "bearing": "SW", "lat": h_lat - 0.0018, "lon": h_lon - 0.0019},
			{"name": "Cobble Hill Urgent Care Physicians", "category": "doctor", "distance_m": 740.0, "bearing": "N", "lat": h_lat + 0.0066, "lon": h_lon - 0.0008},
			{"name": "4th Ave Gulf Gas & Auto Repair", "category": "fuel_auto", "distance_m": 980.0, "bearing": "E", "lat": h_lat - 0.0010, "lon": h_lon + 0.0115},
			{"name": "Mazzone True Value Hardware", "category": "hardware", "distance_m": 1120.0, "bearing": "S", "lat": h_lat - 0.0100, "lon": h_lon - 0.0008},
			{"name": "FDNY Engine 204 & 76th Precinct", "category": "civic", "distance_m": 1460.0, "bearing": "NW", "lat": h_lat + 0.0095, "lon": h_lon - 0.0110},
			{"name": "Brooklyn Methodist Hospital", "category": "doctor", "distance_m": 2480.0, "bearing": "SE", "lat": h_lat - 0.0160, "lon": h_lon + 0.0205},
			{"name": "Red Hook Terminal Fuel & Parts", "category": "fuel_auto", "distance_m": 3950.0, "bearing": "SW", "lat": h_lat - 0.0250, "lon": h_lon - 0.0310}
		]
	elif addr_lower.find("seattle") != -1 or addr_lower.find("roy") != -1 or addr_lower.find("capitol hill") != -1:
		return [
			{"name": "524 E Roy St Neighbor House", "category": "neighbor_house", "distance_m": 65.0, "bearing": "E", "lat": h_lat, "lon": h_lon + 0.0008},
			{"name": "QFC Broadway Supermarket", "category": "grocery", "distance_m": 240.0, "bearing": "SE", "lat": h_lat - 0.0015, "lon": h_lon + 0.0019},
			{"name": "All Pilgrims Christian Church", "category": "church", "distance_m": 185.0, "bearing": "SW", "lat": h_lat - 0.0012, "lon": h_lon - 0.0014},
			{"name": "Walgreens Pharmacy", "category": "pharmacy", "distance_m": 310.0, "bearing": "N", "lat": h_lat + 0.0028, "lon": h_lon + 0.0002},
			{"name": "Lowell Elementary School", "category": "school", "distance_m": 370.0, "bearing": "E", "lat": h_lat - 0.0003, "lon": h_lon + 0.0048},
			{"name": "Capitol Hill Urgent Care Clinic", "category": "doctor", "distance_m": 780.0, "bearing": "S", "lat": h_lat - 0.0070, "lon": h_lon + 0.0005},
			{"name": "Broadway Shell Gas & Auto Shop", "category": "fuel_auto", "distance_m": 940.0, "bearing": "N", "lat": h_lat + 0.0084, "lon": h_lon - 0.0006},
			{"name": "City Peoples Hardware & Mercantile", "category": "hardware", "distance_m": 1180.0, "bearing": "NE", "lat": h_lat + 0.0076, "lon": h_lon + 0.0110},
			{"name": "Seattle Fire Station #25 & Precinct", "category": "civic", "distance_m": 1490.0, "bearing": "S", "lat": h_lat - 0.0132, "lon": h_lon + 0.0015},
			{"name": "Harborview Medical Center", "category": "doctor", "distance_m": 2380.0, "bearing": "SW", "lat": h_lat - 0.0195, "lon": h_lon - 0.0130},
			{"name": "SoDo Industrial Fuel & Auto Parts", "category": "fuel_auto", "distance_m": 4350.0, "bearing": "S", "lat": h_lat - 0.0390, "lon": h_lon - 0.0080},
			{"name": "Ballard Fred Meyer Superstore", "category": "grocery", "distance_m": 5600.0, "bearing": "NW", "lat": h_lat + 0.0360, "lon": h_lon - 0.0520}
		]

	# Custom live-searched address anywhere in the world: generate full 3-Ring 9-category network
	var street_part: String = addr.split(",")[0].strip_edges()
	if street_part == "":
		street_part = "Maple Ave"
	return [
		{"name": "Neighboring House near %s" % street_part, "category": "neighbor_house", "distance_m": 70.0, "bearing": "E", "lat": h_lat, "lon": h_lon + 0.0008},
		{"name": "%s Local Grocery Market" % street_part, "category": "grocery", "distance_m": 235.0, "bearing": "SE", "lat": h_lat - 0.0015, "lon": h_lon + 0.0018},
		{"name": "%s Community Parish Church" % street_part, "category": "church", "distance_m": 190.0, "bearing": "SW", "lat": h_lat - 0.0012, "lon": h_lon - 0.0014},
		{"name": "%s Corner Pharmacy" % street_part, "category": "pharmacy", "distance_m": 315.0, "bearing": "N", "lat": h_lat + 0.0028, "lon": h_lon + 0.0002},
		{"name": "%s Public School & Library" % street_part, "category": "school", "distance_m": 360.0, "bearing": "NW", "lat": h_lat + 0.0023, "lon": h_lon - 0.0024},
		{"name": "%s Urgent Care & Doctor's Office" % street_part, "category": "doctor", "distance_m": 790.0, "bearing": "S", "lat": h_lat - 0.0071, "lon": h_lon + 0.0008},
		{"name": "%s Service Station & Auto Parts" % street_part, "category": "fuel_auto", "distance_m": 960.0, "bearing": "NE", "lat": h_lat + 0.0062, "lon": h_lon + 0.0085},
		{"name": "%s Hardware & Lumber Supply" % street_part, "category": "hardware", "distance_m": 1220.0, "bearing": "E", "lat": h_lat + 0.0010, "lon": h_lon + 0.0155},
		{"name": "%s Fire & Police Station" % street_part, "category": "civic", "distance_m": 1620.0, "bearing": "W", "lat": h_lat - 0.0015, "lon": h_lon - 0.0205},
		{"name": "Highway Fuel & Auto Salvage Yard", "category": "fuel_auto", "distance_m": 4150.0, "bearing": "S", "lat": h_lat - 0.0370, "lon": h_lon - 0.0060},
		{"name": "Regional Wholesale Supermarket", "category": "grocery", "distance_m": 5200.0, "bearing": "NW", "lat": h_lat + 0.0330, "lon": h_lon - 0.0440}
	]
