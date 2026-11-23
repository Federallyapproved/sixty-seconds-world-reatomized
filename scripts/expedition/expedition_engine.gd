class_name ExpeditionEngine
extends RefCounted

## Real-World OpenStreetMap Wasteland Expedition Engine for "60 Seconds: World Reatomized".
## Turns real nearby Neighborhood Houses, Supermarkets, Churches, Pharmacies, Schools,
## and Hardware Stores into high-stakes wasteland scavenging runs.

const CARRYABLE_GEAR_IDS: Array[String] = [
	"gas_mask", "rifle", "axe", "flashlight", "map", "suitcase"
]

const ITEM_NAMES: Dictionary = {
	"soup": "Tomato Soup",
	"water": "Drinking Water",
	"medkit": "First Aid Medkit",
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


static func get_available_targets() -> Array:
	if GameState.nearby_pois.is_empty():
		GameState.nearby_pois = _generate_fallback_pois(GameState.selected_house)

	var rad_label: String = get_radiation_hazard_label(GameState.surface_radiation_sv)
	var raider_aggr: float = float(GameState.nuke_config.get("raider_aggression", 0.45))
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
		var bearing: String = _extract_bearing(poi, house_lat, house_lon, i)
		var base_name: String = _extract_base_name(poi, cat, i)
		var display_name: String = _format_target_display(base_name, dist_m, bearing)

		var travel_days: int = int(poi.get("travel_days", 0))
		if travel_days < 1 or travel_days > 3:
			if dist_m <= 190.0:
				travel_days = 1
			elif dist_m <= 420.0:
				travel_days = 2
			else:
				travel_days = 3

		var visited_count: int = int(poi.get("visited_count", 0))
		var depleted: bool = visited_count >= 2 or bool(poi.get("depleted", false))
		if visited_count >= 2:
			depleted = true

		var bandit_risk: String = "Moderate"
		var risk_score: float = raider_aggr + float(visited_count) * 0.12
		if cat == "church" or cat == "school":
			risk_score -= 0.18
		elif cat == "grocery" or cat == "pharmacy" or cat == "civic":
			risk_score += 0.10
		if risk_score < 0.42:
			bandit_risk = "Low"
		elif risk_score >= 0.68:
			bandit_risk = "High"

		var expected_loot: Array = _expected_loot_for_category(cat)

		poi["index"] = i
		poi["name"] = base_name
		poi["display_name"] = display_name
		poi["category"] = cat
		poi["distance_m"] = roundf(dist_m)
		poi["bearing"] = bearing
		poi["bearing_dir"] = bearing
		poi["travel_days"] = travel_days
		poi["expected_days"] = travel_days
		poi["effective_days_with_map"] = maxi(1, travel_days - 1)
		poi["radiation_risk"] = rad_label
		poi["hazard_level"] = rad_label
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
	var base_days: int = clampi(int(poi.get("travel_days", 2)), 1, 3)
	var trait_id: String = str(member.get("trait", "")).to_lower()
	var has_map_bonus: bool = ("map" in gear_ids)
	if has_map_bonus or trait_id == "scout" or trait_id == "sprinter":
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

	var targets: Array = get_available_targets()
	if targets.is_empty():
		return ""

	var safe_idx: int = clampi(poi_index, 0, targets.size() - 1)
	var poi: Dictionary = targets[safe_idx]

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

	var member_name: String = str(member.get("name", "Survivor"))
	var target_display: String = str(poi.get("display_name", poi.get("name", "Wasteland Ruins")))
	var base_name: String = str(poi.get("name", "Wasteland Ruins"))
	var category: String = str(poi.get("category", "house"))
	var dist_m: float = float(poi.get("distance_m", 180.0))
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
		speed_note = " Using the street map to cut through back alleys shaved precious hours off the route."
	elif trait_id == "scout" or trait_id == "sprinter":
		speed_note = " %s's quick footing across the rubble should speed up the round trip." % member_name

	var day_word: String = "day" if days_away == 1 else "days"
	return "We unbolted the heavy hatch at dusk: %s ventured topside toward %s, %s (expected return in %d %s).%s" % [
		member_name, target_display, gear_phrase, days_away, day_word, speed_note
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
	var category: String = str(exp_data.get("category", "house"))
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

	# 2. Bandit / Scavenger Ambush Resolution
	var raider_aggr: float = float(GameState.nuke_config.get("raider_aggression", 0.45))
	var ambush_chance: float = 0.20 + raider_aggr * 0.34 + float(prior_visits) * 0.06
	if category == "church" or category == "school":
		ambush_chance -= 0.15
	elif category == "grocery" or category == "pharmacy":
		ambush_chance += 0.06
	ambush_chance = clampf(ambush_chance, 0.08, 0.72)

	var was_ambushed: bool = rng.randf() < ambush_chance
	var loot_stolen_factor: float = 1.0
	var bonus_raider_ammo: bool = false

	if was_ambushed:
		if has_rifle:
			if GameState.ammo_count > 0:
				GameState.break_or_consume_item("ammo")
				story_parts.append("Hostile raiders cornered %s outside %s, but a single warning crack from the Hunting Rifle sent them scrambling over abandoned cars!" % [member_name, short_target])
			else:
				story_parts.append("Desperate looters crept out of an alley near %s, until %s leveled the Hunting Rifle and backed them down without firing a shot!" % [short_target, member_name])
			if rng.randf() < 0.35:
				bonus_raider_ammo = true
		elif has_axe:
			story_parts.append("Two masked scavengers lunged from behind a stairwell at %s, but %s swung the Fireman's Axe through a doorframe and sent them fleeing!" % [short_target, member_name])
		elif is_mutant:
			story_parts.append("Wasteland bandits tried to ambush %s near %s—one glimpse of %s's glowing mutant eyes sent the gang sprinting in terror!" % [member_name, short_target, member_name])
		else:
			# Unguarded ambush!
			loot_stolen_factor = 0.55
			var wound_add: int = 1 if (trait_id == "tough" or rng.randf() < 0.65) else 2
			var prev_inj: int = int(member.get("injury", 0))
			var prev_sick: int = int(member.get("sickness", 0))
			if prev_inj >= 3 and prev_sick >= 2 and rng.randf() < 0.35:
				# Rare fatal ambush only if explorer was sent out already critically wounded & sick without weapons
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

	# 4. Calculate Scavenged Loot (Suitcase 2x, Flashlight +35%, Depletion scaling)
	var mult: float = 1.0
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

	var loot_dict: Dictionary = _roll_category_loot(category, mult, rng)
	if bonus_raider_ammo:
		loot_dict["soup"] = int(loot_dict.get("soup", 0)) + 1

	var loot_labels: Array[String] = []
	for item_key in loot_dict.keys():
		var iid: String = str(item_key)
		var qty: int = int(loot_dict.get(iid, 0))
		if qty <= 0:
			continue
		GameState.add_scavenged_item(iid, qty)
		var nice_name: String = str(ITEM_NAMES.get(iid, iid.capitalize()))
		if iid == "soup":
			loot_labels.append("%d %s" % [qty, "can of Soup" if qty == 1 else "cans of Soup"])
		elif iid == "water":
			loot_labels.append("%d %s" % [qty, "bottle of Water" if qty == 1 else "bottles of Water"])
		elif iid == "ammo":
			loot_labels.append("%d %s" % [qty * 2, "Rifle rounds"])
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

	# 5. Update POI visited_count & Sanctuary Rescue Chain
	poi_ref["visited_count"] = prior_visits + 1
	poi_ref["depleted"] = int(poi_ref["visited_count"]) >= 2
	if poi_index >= 0 and poi_index < GameState.nearby_pois.size():
		GameState.nearby_pois[poi_index] = poi_ref

	var sanctuary_advanced: bool = false
	if category == "church" or category == "school":
		var cur_sanc: int = int(GameState.rescue_chains.get("sanctuary", 0))
		if cur_sanc < 3:
			var next_sanc: int = mini(3, cur_sanc + 1)
			GameState.rescue_chains["sanctuary"] = next_sanc
			sanctuary_advanced = true
			if next_sanc == 1:
				story_parts.append("Inside %s, %s traded peaceful Civil Defense hand signals with candlelit neighborhood survivors organizing a relief shelter (Sanctuary 1/3)." % [short_target, member_name])
			elif next_sanc == 2:
				story_parts.append("Volunteers fortified inside %s shared rainwater blueprints and marked our street on their convoy roster (Sanctuary 2/3)!" % short_target)
			else:
				story_parts.append("The community council at %s rang their bell and dispatched an armed neighborhood escort directly to our address (Sanctuary 3/3)!" % short_target)

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
				story_parts.append("Rough scrapes on the trip cracked our %s (needs Toolbox repair)." % worn_label)

	# 7. Explorer Fatigue, Wasteland Hunger/Thirst & Bunker State Reset
	member["on_expedition"] = false
	member["days_away"] = 0
	member["fatigue"] = mini(2, int(member.get("fatigue", 0)) + 1)
	if not is_mutant:
		member["days_without_water"] = int(member.get("days_without_water", 0)) + 1
		member["days_without_food"] = int(member.get("days_without_food", 0)) + 1
		member["thirst"] = mini(3, int(member.get("thirst", 0)) + 1)
		member["hunger"] = mini(3, int(member.get("hunger", 0)) + 1)
	member["status_note"] = "Back from %s, catching breath." % short_target

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
		"loot": loot_dict,
		"loot_summary": loot_summary,
		"broken_gear": broken_gear,
		"sanctuary_advanced": sanctuary_advanced,
		"ambushed": was_ambushed,
		"rad_gained": rad_gained,
		"narrative": " ".join(story_parts)
	}


static func _roll_category_loot(category: String, mult: float, rng: RandomNumberGenerator) -> Dictionary:
	var loot: Dictionary = {}
	match category:
		"grocery", "restaurant":
			var soup_cnt: int = maxi(1, roundi(float(rng.randi_range(2, 3)) * mult))
			var water_cnt: int = maxi(1, roundi(float(rng.randi_range(2, 3)) * mult))
			loot["soup"] = soup_cnt
			loot["water"] = water_cnt
			if rng.randf() < 0.28 * mult:
				loot["bug_spray"] = 1
		"pharmacy":
			var med_cnt: int = maxi(1, roundi(float(rng.randi_range(1, 2)) * clampf(mult * 0.85, 0.7, 2.2)))
			loot["medkit"] = med_cnt
			loot["water"] = maxi(1, roundi(1.2 * mult))
			if rng.randf() < 0.35:
				loot["bug_spray"] = 1
			if not GameState.has_working_item("gas_mask") and rng.randf() < 0.32 * mult:
				loot["gas_mask"] = 1
		"hardware":
			loot["water"] = maxi(1, roundi(1.0 * mult))
			if rng.randf() < 0.55:
				loot["soup"] = maxi(1, roundi(0.9 * mult))
			if rng.randf() < 0.45 * clampf(mult, 0.8, 1.8):
				loot["ammo"] = maxi(1, roundi(0.9 * mult))
			var hw_pool: Array[String] = ["toolbox", "axe", "rifle", "ammo", "padlock", "flashlight", "bug_spray"]
			var picked_durable: String = _pick_needed_durable(hw_pool, rng)
			if picked_durable != "":
				loot[picked_durable] = maxi(1, int(loot.get(picked_durable, 0)))
			if mult >= 1.75:
				var second_hw: String = _pick_needed_durable(["rifle", "ammo", "padlock", "bug_spray", "toolbox", "axe"], rng)
				if second_hw != "" and not loot.has(second_hw):
					loot[second_hw] = 1
		"church":
			loot["soup"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * mult))
			loot["water"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * mult))
			if rng.randf() < 0.40 * mult:
				loot["medkit"] = 1
			var church_gift: String = _pick_needed_durable(["book", "harmonica", "cards"], rng)
			if church_gift != "" and rng.randf() < 0.45:
				loot[church_gift] = 1
		"school":
			loot["soup"] = maxi(1, roundi(1.3 * mult))
			loot["water"] = maxi(1, roundi(1.3 * mult))
			var school_gear: String = _pick_needed_durable(["map", "book", "flashlight", "checkers", "cards"], rng)
			if school_gear != "":
				loot[school_gear] = 1
		"civic":
			loot["water"] = maxi(1, roundi(1.2 * mult))
			loot["ammo"] = maxi(1, roundi(1.1 * mult))
			var civic_gear: String = _pick_needed_durable(["rifle", "gas_mask", "radio", "medkit"], rng)
			if civic_gear != "":
				loot[civic_gear] = 1
		"park":
			loot["water"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * mult))
			if rng.randf() < 0.65:
				loot["soup"] = maxi(1, roundi(1.0 * mult))
			var cache_item: String = _pick_needed_durable(["harmonica", "ammo", "map", "bug_spray"], rng)
			if cache_item != "" and rng.randf() < 0.55:
				loot[cache_item] = 1
		_:
			# Neighboring House / Residential default
			loot["soup"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * mult))
			loot["water"] = maxi(1, roundi(float(rng.randi_range(1, 2)) * mult))
			var home_pool: Array[String] = [
				"medkit", "ammo", "suitcase", "radio", "flashlight",
				"cards", "checkers", "padlock", "harmonica", "bug_spray"
			]
			if rng.randf() < 0.65 * clampf(mult, 0.6, 1.6):
				var home_pick: String = _pick_needed_durable(home_pool, rng)
				if home_pick != "":
					loot[home_pick] = 1
	return loot


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
			return "%s crept beneath shattered neon signage into %s, %s for intact tins and bottled water." % [member_name, target_display, light_clause]
		"church":
			return "%s reached the stone steps of %s, where stained-glass shards glinted in the haze and Civil Defense candles flickered inside." % [member_name, target_display]
		"pharmacy":
			return "%s pried open the security grille at %s, %s behind the prescription counter." % [member_name, target_display, light_clause]
		"hardware":
			return "%s slipped through the loading bay of %s, %s among toppled tool racks and tarps." % [member_name, target_display, light_clause]
		"school":
			return "%s crossed the ash-dusted courtyard of %s, checking emergency Civil Defense lockers and the cafeteria pantry." % [member_name, target_display]
		"civic":
			return "%s picked past sandbags into %s, searching abandoned emergency dispatch lockers." % [member_name, target_display]
		"park":
			return "%s skirted charred sycamores across %s to locate a half-buried Civil Defense supply drum." % [member_name, target_display]
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
	var raw_cat: String = str(poi.get("category", poi.get("type", poi.get("poi_type", poi.get("amenity", poi.get("shop", poi.get("building_type", ""))))))).to_lower()
	if raw_cat in ["grocery", "supermarket", "convenience", "bakery", "greengrocer", "deli", "market", "marketplace"]:
		return "grocery"
	if raw_cat in ["restaurant", "cafe", "fast_food", "bar", "diner"]:
		return "restaurant"
	if raw_cat in ["church", "place_of_worship", "chapel", "cathedral", "synagogue", "mosque", "temple"]:
		return "church"
	if raw_cat in ["pharmacy", "chemist", "clinic", "hospital", "doctors", "medical", "dentist"]:
		return "pharmacy"
	if raw_cat in ["hardware", "doityourself", "trade", "industrial", "storage", "garage"]:
		return "hardware"
	if raw_cat in ["school", "library", "college", "university", "kindergarten", "community_centre"]:
		return "school"
	if raw_cat in ["civic", "fire_station", "police", "townhall", "post_office", "government"]:
		return "civic"
	if raw_cat in ["park", "playground", "garden", "recreation_ground"]:
		return "park"
	if raw_cat in ["house", "neighbor_house", "neighbor", "neighbour", "residential", "detached", "apartments", "terrace", "semidetached_house"]:
		return "house"

	# Fallback keyword inference from POI name
	var nm: String = str(poi.get("name", poi.get("label", ""))).to_lower()
	if nm.find("market") != -1 or nm.find("grocery") != -1 or nm.find("qfc") != -1 or nm.find("supermarket") != -1 or nm.find("food") != -1:
		return "grocery"
	if nm.find("church") != -1 or nm.find("parish") != -1 or nm.find("chapel") != -1 or nm.find("st.") != -1 or nm.find("pilgrim") != -1:
		return "church"
	if nm.find("pharm") != -1 or nm.find("walgreens") != -1 or nm.find("cvs") != -1 or nm.find("clinic") != -1 or nm.find("drug") != -1:
		return "pharmacy"
	if nm.find("hardware") != -1 or nm.find("supply") != -1 or nm.find("lumber") != -1 or nm.find("tool") != -1:
		return "hardware"
	if nm.find("school") != -1 or nm.find("library") != -1 or nm.find("elementary") != -1 or nm.find("academy") != -1:
		return "school"
	if nm.find("fire") != -1 or nm.find("station") != -1 or nm.find("precinct") != -1:
		return "civic"
	return "house"


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
			return clampf(computed, 25.0, 1500.0)
	return float(85 + idx * 55)


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
		# Strip trailing "(240m SE)" if already embedded so base_name stays clean
		var paren_pos: int = nm.rfind("(")
		if paren_pos > 2 and nm.ends_with(")") and nm.substr(paren_pos).find("m ") != -1:
			nm = nm.substr(0, paren_pos).strip_edges()
		return nm
	match cat:
		"grocery":
			return "Neighborhood Grocery Market"
		"church":
			return "Community Parish Church"
		"pharmacy":
			return "Corner Drugstore & Pharmacy"
		"hardware":
			return "Neighborhood Hardware & Supply"
		"school":
			return "Public Elementary School"
		"civic":
			return "Engine Co. Firehouse"
		"park":
			return "Municipal Civil Defense Park"
		_:
			return "Neighboring House #%d" % (idx + 1)


static func _format_target_display(base_name: String, dist_m: float, bearing: String) -> String:
	return "%s (%dm %s)" % [base_name, int(round(dist_m)), bearing]


static func _expected_loot_for_category(cat: String) -> Array:
	match cat:
		"grocery", "restaurant":
			return ["soup", "water"]
		"pharmacy":
			return ["medkit", "water", "bug_spray"]
		"hardware":
			return ["toolbox", "axe", "rifle", "ammo", "flashlight", "padlock"]
		"church":
			return ["soup", "water", "medkit", "book"]
		"school":
			return ["map", "book", "soup", "flashlight"]
		"civic":
			return ["rifle", "ammo", "gas_mask", "radio"]
		"park":
			return ["water", "soup", "harmonica"]
		_:
			return ["soup", "water", "ammo", "cards"]


static func _generate_fallback_pois(house: Dictionary) -> Array:
	var addr: String = str(house.get("address", "518 E Roy St, Capitol Hill, Seattle, WA"))
	var addr_lower: String = addr.to_lower()
	var h_lat: float = float(house.get("lat", 47.6242))
	var h_lon: float = float(house.get("lon", -122.3195))

	if addr_lower.find("concord") != -1:
		return [
			{"name": "Neighboring Colonial House", "category": "house", "distance_m": 68.0, "bearing": "W", "lat": h_lat, "lon": h_lon - 0.0009},
			{"name": "Crosby's Marketplace", "category": "grocery", "distance_m": 255.0, "bearing": "SE", "lat": h_lat - 0.0016, "lon": h_lon + 0.0018},
			{"name": "First Parish Church in Concord", "category": "church", "distance_m": 205.0, "bearing": "E", "lat": h_lat + 0.0002, "lon": h_lon + 0.0024},
			{"name": "Concord Family Pharmacy", "category": "pharmacy", "distance_m": 320.0, "bearing": "SW", "lat": h_lat - 0.0021, "lon": h_lon - 0.0020},
			{"name": "Vanderhoof Hardware Store", "category": "hardware", "distance_m": 290.0, "bearing": "N", "lat": h_lat + 0.0026, "lon": h_lon + 0.0003},
			{"name": "Concord Free Public Library", "category": "school", "distance_m": 240.0, "bearing": "NE", "lat": h_lat + 0.0015, "lon": h_lon + 0.0018}
		]
	elif addr_lower.find("brooklyn") != -1 or addr_lower.find("carroll") != -1:
		return [
			{"name": "Neighboring Carroll St Brownstone", "category": "house", "distance_m": 58.0, "bearing": "E", "lat": h_lat, "lon": h_lon + 0.0007},
			{"name": "Union Market Carroll Gardens", "category": "grocery", "distance_m": 220.0, "bearing": "N", "lat": h_lat + 0.0020, "lon": h_lon + 0.0002},
			{"name": "Sacred Hearts & St. Stephen Church", "category": "church", "distance_m": 190.0, "bearing": "NW", "lat": h_lat + 0.0013, "lon": h_lon - 0.0014},
			{"name": "Court Street Corner Pharmacy", "category": "pharmacy", "distance_m": 305.0, "bearing": "NE", "lat": h_lat + 0.0021, "lon": h_lon + 0.0019},
			{"name": "Mazzone True Value Hardware", "category": "hardware", "distance_m": 365.0, "bearing": "S", "lat": h_lat - 0.0032, "lon": h_lon - 0.0004},
			{"name": "P.S. 58 The Carroll School", "category": "school", "distance_m": 275.0, "bearing": "SW", "lat": h_lat - 0.0018, "lon": h_lon - 0.0019}
		]
	elif addr_lower.find("seattle") != -1 or addr_lower.find("roy") != -1 or addr_lower.find("capitol hill") != -1:
		return [
			{"name": "524 E Roy St Neighbor House", "category": "house", "distance_m": 65.0, "bearing": "E", "lat": h_lat, "lon": h_lon + 0.0008},
			{"name": "QFC Supermarket", "category": "grocery", "distance_m": 240.0, "bearing": "SE", "lat": h_lat - 0.0015, "lon": h_lon + 0.0019},
			{"name": "All Pilgrims Christian Church", "category": "church", "distance_m": 185.0, "bearing": "SW", "lat": h_lat - 0.0012, "lon": h_lon - 0.0014},
			{"name": "Walgreens Pharmacy", "category": "pharmacy", "distance_m": 310.0, "bearing": "N", "lat": h_lat + 0.0028, "lon": h_lon + 0.0002},
			{"name": "City Peoples Hardware & Mercantile", "category": "hardware", "distance_m": 445.0, "bearing": "NE", "lat": h_lat + 0.0029, "lon": h_lon + 0.0031},
			{"name": "Lowell Elementary School", "category": "school", "distance_m": 370.0, "bearing": "E", "lat": h_lat - 0.0003, "lon": h_lon + 0.0048}
		]

	# Custom live-searched address anywhere in the world: extract street segment
	var street_part: String = addr.split(",")[0].strip_edges()
	if street_part == "":
		street_part = "Maple Ave"
	return [
		{"name": "Neighboring House near %s" % street_part, "category": "house", "distance_m": 70.0, "bearing": "E", "lat": h_lat, "lon": h_lon + 0.0008},
		{"name": "%s Local Grocery Market" % street_part, "category": "grocery", "distance_m": 235.0, "bearing": "SE", "lat": h_lat - 0.0015, "lon": h_lon + 0.0018},
		{"name": "%s Community Church" % street_part, "category": "church", "distance_m": 190.0, "bearing": "SW", "lat": h_lat - 0.0012, "lon": h_lon - 0.0014},
		{"name": "%s Corner Pharmacy" % street_part, "category": "pharmacy", "distance_m": 315.0, "bearing": "N", "lat": h_lat + 0.0028, "lon": h_lon + 0.0002},
		{"name": "%s Hardware & Supply" % street_part, "category": "hardware", "distance_m": 440.0, "bearing": "NE", "lat": h_lat + 0.0028, "lon": h_lon + 0.0030},
		{"name": "%s Public School Shelter" % street_part, "category": "school", "distance_m": 360.0, "bearing": "NW", "lat": h_lat + 0.0023, "lon": h_lon - 0.0024}
	]
