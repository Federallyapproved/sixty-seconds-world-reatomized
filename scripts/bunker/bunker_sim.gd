class_name BunkerSim
extends RefCounted

## The End Is Near — Bunker Survival Simulation Engine.
## Governs Day 1 blast aftermath, fractional soup/water rationing, exact dehydration/starvation
## curves, temperature & fallout decay, sickness/injury/mutation, morale items & pets,
## OpenStreetMap wasteland expeditions, and Rescue / Game-Over endings.

const ITEM_LABELS: Dictionary = {
	"soup": "Soup",
	"water": "Water",
	"medkit": "Medkit",
	"gas_mask": "Gas Mask",
	"radio": "CONELRAD Radio",
	"flashlight": "Flashlight",
	"map": "Neighborhood Map",
	"book": "Survival Handbook",
	"ammo": "Ammo",
	"bug_spray": "Bug Spray",
	"padlock": "Padlock",
	"cards": "Playing Cards",
	"checkers": "Checkers",
	"harmonica": "Harmonica",
	"axe": "Fireman's Axe",
	"rifle": "Hunting Rifle",
	"suitcase": "Suitcase",
	"toolbox": "Toolbox"
}


static func start_bunker_run() -> void:
	GameState.day = 1
	GameState.game_over = false
	GameState.victory = false
	GameState.ending_title = ""
	GameState.ending_description = ""
	GameState.active_expedition = {}

	EventDeck.reset_state()

	for raw_gid in GameState.bunker_items.keys():
		var gid: String = str(raw_gid)
		if GameState.bunker_items[gid] is Dictionary:
			GameState.bunker_items[gid]["checked_out"] = false

	for i in range(GameState.nearby_pois.size()):
		if GameState.nearby_pois[i] is Dictionary:
			var poi_entry: Dictionary = GameState.nearby_pois[i]
			poi_entry["visited_count"] = 0
			poi_entry["depleted"] = false
			GameState.nearby_pois[i] = poi_entry

	var nuke: Dictionary = GameState.nuke_config
	var init_sv: float = maxf(0.15, float(nuke.get("initial_sv_hr", GameState.surface_radiation_sv)))
	var init_temp: float = float(nuke.get("bunker_temp_c", GameState.bunker_temp_c))
	var struct_dmg: float = clampf(float(nuke.get("structural_damage", 0.25)), 0.0, 1.0)
	var dist_km: float = float(nuke.get("distance_km", 3.5))
	var yield_kt: int = int(nuke.get("yield_kt", 800))
	var target_name: String = str(nuke.get("target_name", "Regional Target"))
	var zone_id: String = str(nuke.get("zone", "fallout_plume"))

	GameState.surface_radiation_sv = init_sv
	GameState.bunker_temp_c = init_temp
	GameState.bunker_structural_integrity = clampf(100.0 - struct_dmg * 45.0, 25.0, 100.0)
	GameState.rad_hotspots = []
	GameState.extra_strikes = []
	VehicleSystem.init_for_run()

	# Ensure neighborhood expedition targets are initialized on Day 1 and reset visit/depletion flags
	ExpeditionEngine.get_available_targets()
	for i in range(GameState.nearby_pois.size()):
		if GameState.nearby_pois[i] is Dictionary:
			var poi_post: Dictionary = GameState.nearby_pois[i]
			poi_post["visited_count"] = 0
			poi_post["depleted"] = false
			GameState.nearby_pois[i] = poi_post

	var house_addr: String = LocationText.home_ref()
	var survivors_names: Array[String] = []
	var lost_names: Array[String] = []

	if GameState.demo_mode:
		var any_marked_in: bool = false
		for raw_chk in GameState.family_members:
			if raw_chk is Dictionary and bool((raw_chk as Dictionary).get("in_bunker", false)):
				any_marked_in = true
				break
		if not any_marked_in:
			for raw_seed in GameState.family_members:
				if raw_seed is Dictionary:
					var sd: Dictionary = raw_seed
					sd["in_bunker"] = true
					sd["alive"] = true

	for raw_m in GameState.family_members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		var m_name: String = str(m.get("name", "Survivor"))
		var made_it: bool = bool(m.get("in_bunker", false)) and bool(m.get("alive", true))
		if made_it:
			m["alive"] = true
			m["on_expedition"] = false
			m["days_away"] = 0
			m["sick_days"] = 0
			m["injury_days"] = 0
			m["insane_days"] = 0
			m["mutant_fast_tick"] = 0
			m["heat_thirst_ticked"] = false
			m["iron_grace_used"] = false
			if bool(m.get("is_mutant", false)):
				m["sickness"] = 0
				m["sick_days"] = 0
			survivors_names.append(m_name)
		else:
			m["in_bunker"] = false
			m["alive"] = false
			m["on_expedition"] = false
			if str(m.get("death_reason", "")) == "":
				m["death_reason"] = "Caught above ground when the nuclear shockwave hit."
			m["status_note"] = str(m["death_reason"])
			lost_names.append(m_name)

	# Initial grief if family members were left outside
	if not lost_names.is_empty() and not survivors_names.is_empty():
		for raw_m in GameState.family_members:
			if not (raw_m is Dictionary):
				continue
			var m: Dictionary = raw_m
			if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)):
				var tr: String = str(m.get("trait", "")).to_lower()
				if tr != "optimist" and tr != "calm" and tr != "bookworm":
					m["sanity"] = mini(3, int(m.get("sanity", 0)) + 1)

	var lines: Array[String] = []
	if survivors_names.is_empty():
		lines.append("The steel Civil Defense hatch beneath %s slammed shut on an empty shelter as the blinding flash swallowed the street above." % house_addr)
	else:
		lines.append("Seconds before the shockwave tore across the block, %s tumbled down the ladder and dogged the steel hatch beneath %s." % [
			_join_names_naturally(survivors_names), house_addr
		])
		if not lost_names.is_empty():
			lines.append("Heartbreak already hangs heavy in the shelter—%s did not reach the hatch before detonation." % _join_names_naturally(lost_names))

	var gz_lat: float = float(nuke.get("lat", 0.0))
	var gz_lon: float = float(nuke.get("lon", 0.0))
	var gz_dir: String = LocationText.compass_word(NukePhysics.bearing_deg(float(GameState.selected_house.get("lat", 0.0)), float(GameState.selected_house.get("lon", 0.0)), gz_lat, gz_lon))
	var rate_now: float = RadiationModel.dose_rate_msv_h(float(GameState.selected_house.get("lat", 0.0)), float(GameState.selected_house.get("lon", 0.0)), 1.0, 1)
	lines.append("CONELRAD reports a %d kt detonation at %s, %.1f km to the %s. A %s is carrying the fallout toward the %s." % [
		yield_kt, target_name, dist_km, gz_dir, LocationText.wind_name(), LocationText.compass_word(LocationText.downwind_bearing())
	])
	lines.append("Outdoor dose rate an hour after the blast: %s (%s). Shelter air: %.1f °C." % [RadiationModel.format_rate(rate_now), RadiationModel.risk_label(rate_now), init_temp])
	var veh: Dictionary = GameState.vehicle
	if bool(veh.get("wrecked", false)):
		lines.append("Through the periscope: the family car is crushed under blast debris. Driving out is not an option.")
	else:
		lines.append("Through the periscope: the family car survived, but its battery cracked in the blast. %d part(s) needed before it could run." % VehicleSystem.missing_parts().size())

	if struct_dmg > 0.4:
		lines.append("Violent ground tremors rattled our teeth—concrete dust sifted from the ceiling seams and hairline cracks spiderwebbed the plaster (structural integrity %.0f%%)." % GameState.bunker_structural_integrity)
	elif struct_dmg > 0.15:
		lines.append("A muffled thunderclap shook fine mortar dust off the rafters and set the overhead bulb swinging, though the reinforced bunker walls held firm.")
	else:
		lines.append("Only a low subterranean rumble rolled through the floor slabs; our shelter seals remain tight.")

	lines.append("Initial ration count on the shelves: %s cans of Soup and %s bottles of Water." % [
		GameState.format_quarters_as_cans(GameState.soup_quarters),
		GameState.format_quarters_as_cans(GameState.water_quarters)
	])

	var living_start: Array = GameState.get_all_living_members()
	if living_start.is_empty():
		GameState.game_over = true
		GameState.victory = false
		GameState.ending_title = "SILENT SHELTER"
		GameState.ending_description = "Nobody made it inside the fallout shelter beneath %s before the warhead struck %.2f km away. Only the battery-powered CONELRAD dial glowed in the dark." % [
			house_addr, dist_km
		]
		lines.append("With no survivors inside the bunker, our Civil Defense vigil ends before it could begin.")
	elif not _has_living_guardian(living_start):
		GameState.game_over = true
		GameState.victory = false
		GameState.ending_title = "NO ADULT GUARDIAN IN SHELTER"
		GameState.ending_description = "Only young children made it inside without an adult or teenager to operate shelter life support."
		lines.append("Only young children made it inside without an adult or teenager to operate shelter life support.")

	_refresh_all_status_notes()
	var day1_title: String = "DAY 1 — SEALED BENEATH %s" % house_addr.to_upper()
	GameState.daily_log_entries = [{
		"day": 1,
		"title": day1_title,
		"lines": lines,
		"text": day1_title + "\n" + "\n".join(lines)
	}]
	GameState.inventory_changed.emit()
	GameState.family_changed.emit()


static func advance_day(
	ration_plan: Dictionary = {},
	medkit_target_id: String = "",
	event_notes: Variant = null,
	expedition_launch: Dictionary = {}
) -> Array[String]:
	var day_lines: Array[String] = []
	var house_addr: String = LocationText.home_ref()
	var extracted_event_lines: Array[String] = _extract_event_notes(event_notes)

	var has_gameover_tag: bool = false
	if event_notes is Dictionary:
		var raw_tags: Variant = (event_notes as Dictionary).get("tags", [])
		if raw_tags is Array:
			has_gameover_tag = (raw_tags as Array).has("gameover")

	var all_living_start: Array = _get_all_living_household_members()
	var is_defeat_at_start: bool = (
		GameState.bunker_structural_integrity <= 0.0
		or has_gameover_tag
		or GameState.get_all_living_members().is_empty()
		or all_living_start.is_empty()
		or not _has_living_guardian(all_living_start)
	)
	if is_defeat_at_start:
		GameState.day += 1
		var def_day: int = GameState.day
		for ev_line in extracted_event_lines:
			day_lines.append(ev_line)
		var def_eval_line: String = _evaluate_win_or_loss(house_addr)
		GameState.victory = false
		GameState.game_over = true
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "CLAIMED BY THE WASTELAND"
		if GameState.ending_description.strip_edges() == "":
			GameState.ending_description = "On Day %d beneath %s, our fallout shelter's struggle came to an end." % [def_day, house_addr]
		if day_lines.is_empty() and def_eval_line != "":
			day_lines.append(def_eval_line)
		_refresh_all_status_notes()
		var def_title: String = "DAY %d — %s" % [def_day, LocationText.area_header().to_upper()]
		GameState.daily_log_entries.append({
			"day": def_day,
			"title": def_title,
			"lines": day_lines.duplicate(),
			"text": def_title + "\n" + "\n".join(day_lines)
		})
		GameState.inventory_changed.emit()
		GameState.family_changed.emit()
		GameState.day_advanced.emit(GameState.day)
		return day_lines

	var any_rescue_stage_3: bool = (
		int(GameState.rescue_chains.get("military", 0)) >= 3
		or int(GameState.rescue_chains.get("sanctuary", 0)) >= 3
		or int(GameState.rescue_chains.get("scientist", 0)) >= 3
	)
	if (GameState.victory or any_rescue_stage_3) and not GameState.get_all_living_members().is_empty():
		GameState.day += 1
		var vic_day: int = GameState.day
		for ev_line in extracted_event_lines:
			day_lines.append(ev_line)
		GameState.victory = true
		GameState.game_over = true
		var vic_eval_line: String = _evaluate_win_or_loss(house_addr)
		GameState.victory = true
		GameState.game_over = true
		if day_lines.is_empty() and vic_eval_line != "":
			day_lines.append(vic_eval_line)
		_refresh_all_status_notes()
		var vic_title: String = "DAY %d — %s" % [vic_day, LocationText.area_header().to_upper()]
		GameState.daily_log_entries.append({
			"day": vic_day,
			"title": vic_title,
			"lines": day_lines.duplicate(),
			"text": vic_title + "\n" + "\n".join(day_lines)
		})
		GameState.inventory_changed.emit()
		GameState.family_changed.emit()
		GameState.day_advanced.emit(GameState.day)
		return day_lines

	if GameState.game_over:
		GameState.game_over = false

	var rng: RandomNumberGenerator = GameState.rng
	GameState.day += 1
	var cur_day: int = GameState.day
	var pre_weather_temp_c: float = GameState.bunker_temp_c

	# Pre-count living bunker members & total soup assigned today (for Nuclear Winter warmth check)
	var bunker_members_start: Array = GameState.get_living_bunker_members()
	var total_soup_q_planned: int = _sum_planned_soup_quarters(ration_plan, bunker_members_start)
	var generous_hot_soup: bool = (not bunker_members_start.is_empty()) and (total_soup_q_planned > bunker_members_start.size())

	# 1. Radiation & Weather Decay
	var weather_note: String = _tick_radiation_and_weather(generous_hot_soup, rng)
	var peak_temp_today_c: float = maxf(pre_weather_temp_c, GameState.bunker_temp_c)
	day_lines.append(RadiationModel.tick_day(cur_day) + " Thermometer: %.1f °C." % GameState.bunker_temp_c)
	if weather_note != "":
		day_lines.append(weather_note)

	# 2. Previous Event Resolution Notes (accepts Array, Dictionary, or String; "**" already stripped)
	for ev_line in extracted_event_lines:
		day_lines.append(ev_line)

	# 3. Medical Care
	if medkit_target_id != "" and GameState.medkit_count > 0:
		var med_member: Dictionary = _find_living_bunker_member(medkit_target_id)
		if not med_member.is_empty():
			var m_name: String = str(med_member.get("name", "Survivor"))
			var had_sick: int = int(med_member.get("sickness", 0))
			var had_inj: int = int(med_member.get("injury", 0))
			GameState.break_or_consume_item("medkit")
			med_member["sickness"] = 0
			med_member["injury"] = 0
			med_member["sick_days"] = 0
			med_member["injury_days"] = 0
			if had_sick > 0 and had_inj > 0:
				day_lines.append("We cracked open a First Aid Medkit for %s—antiseptic, bandages, and antibiotics cleared up both fever and wounds!" % m_name)
			elif had_sick > 0:
				day_lines.append("A dose of antibiotics from our Medkit broke %s's fever and restored healthy color!" % m_name)
			elif had_inj > 0:
				day_lines.append("Clean gauze and stitches from a Medkit patched %s's injuries right up!" % m_name)
			else:
				day_lines.append("We used a First Aid Medkit on %s for a thorough Civil Defense checkup." % m_name)

	# 4. Fractional Soup & Water Rationing (classic thresholds)
	var deaths_today: Array[String] = []
	var fed_names: Array[String] = []
	var watered_names: Array[String] = []

	for raw_m in GameState.get_living_bunker_members():
		var m: Dictionary = raw_m
		var m_id: String = str(m.get("id", ""))
		var m_name: String = str(m.get("name", "Survivor"))
		var role: String = str(m.get("role", "adult")).to_lower()
		var trait_id: String = str(m.get("trait", "")).to_lower()
		var is_mutant: bool = bool(m.get("is_mutant", false))

		var req_rations: Vector2i = _extract_member_ration_quarters(ration_plan, m_id)
		var soup_q: int = clampi(req_rations.x, 0, GameState.soup_quarters)
		var water_q: int = clampi(req_rations.y, 0, GameState.water_quarters)

		GameState.soup_quarters -= soup_q
		GameState.water_quarters -= water_q

		if soup_q > 0:
			fed_names.append(m_name)
		if water_q > 0:
			watered_names.append(m_name)

		if is_mutant:
			# Mutants don't need water, are immune to radiation, sickness & injury, and get hungry half as fast
			m["days_without_water"] = 0
			m["thirst"] = 0
			m["sickness"] = 0
			m["sick_days"] = 0
			m["injury"] = 0
			m["injury_days"] = 0
			m["radiation"] = 0.0
			if soup_q >= 1:
				m["days_without_food"] = 0
				m["mutant_fast_tick"] = 0
				var m_h_drop: int = maxi(2, soup_q * 2)
				m["hunger"] = maxi(0, int(m.get("hunger", 0)) - m_h_drop)
				m["fatigue"] = maxi(0, int(m.get("fatigue", 0)) - 1)
			else:
				var tick_half: int = int(m.get("mutant_fast_tick", 0)) + 1
				if tick_half >= 2:
					m["mutant_fast_tick"] = 0
					m["days_without_food"] = int(m.get("days_without_food", 0)) + 1
				else:
					m["mutant_fast_tick"] = tick_half
				var m_dwf: int = int(m.get("days_without_food", 0))
				if m_dwf >= 12:
					m["alive"] = false
					m["death_reason"] = "Succumbed to starvation in the bunker."
					deaths_today.append(m_name)
					day_lines.append("Even %s's mutated metabolism finally gave out after weeks without soup." % m_name)
					continue
				else:
					m["hunger"] = maxi(int(m.get("hunger", 0)), _hunger_tier_for_days(m_dwf))
			continue

		# Standard Human Thirst Progression (with Scorching Heat coupling)
		if water_q >= 1:
			m["days_without_water"] = 0
			m["heat_thirst_ticked"] = false
			var w_drop: int = maxi(2, water_q * 2)
			m["thirst"] = maxi(0, int(m.get("thirst", 0)) - w_drop)
		else:
			var dww: int = int(m.get("days_without_water", 0)) + 1
			if int(m.get("sickness", 0)) >= 2 and dww >= 2 and cur_day % 2 == 0:
				dww += 1
				day_lines.append("%s's fever is burning through what little water is left in the body." % m_name)
			if peak_temp_today_c >= 25.0 and not bool(m.get("heat_thirst_ticked", false)) and (peak_temp_today_c >= 29.0 or dww >= 2):
				dww += 1
				m["heat_thirst_ticked"] = true
				day_lines.append("Stifling %.1f °C blast heat in the shelter left %s sweating heavily, accelerating thirst!" % [peak_temp_today_c, m_name])
			m["days_without_water"] = dww
			if dww >= 6:
				m["alive"] = false
				m["death_reason"] = "Perished from severe dehydration."
				deaths_today.append(m_name)
				day_lines.append("Six parched days without a drop of water proved fatal—%s perished from severe dehydration." % m_name)
				continue
			else:
				var w_tier: int = _thirst_tier_for_days(dww)
				m["thirst"] = maxi(int(m.get("thirst", 0)), w_tier)
				if dww == 4:
					day_lines.append("%s's lips are cracked with dehydration—water is urgently needed!" % m_name)
				elif dww == 5:
					day_lines.append("CRITICAL: %s can barely swallow from extreme thirst and won't survive another dry day!" % m_name)

		# Standard Human Hunger Progression
		var stretches_food: bool = (trait_id == "iron_stomach" or role == "child")
		if soup_q >= 1:
			m["days_without_food"] = 0
			m["iron_grace_used"] = false
			var f_drop: int = maxi(2, soup_q * 2)
			m["hunger"] = maxi(0, int(m.get("hunger", 0)) - f_drop)
			m["fatigue"] = maxi(0, int(m.get("fatigue", 0)) - 1)
		else:
			var dwf: int = int(m.get("days_without_food", 0))
			if stretches_food and not bool(m.get("iron_grace_used", false)) and dwf == 2:
				# Iron stomach / child stretches rations slightly before hunger sets in
				m["iron_grace_used"] = true
			else:
				dwf += 1
				m["days_without_food"] = dwf

			if dwf >= 12:
				m["alive"] = false
				m["death_reason"] = "Succumbed to starvation in the bunker."
				deaths_today.append(m_name)
				day_lines.append("Twelve agonizing days without food took their final toll—%s succumbed to starvation." % m_name)
				continue
			else:
				var f_tier: int = _hunger_tier_for_days(dwf)
				m["hunger"] = maxi(int(m.get("hunger", 0)), f_tier)
				if dwf == 6:
					day_lines.append("%s's stomach growls painfully; starvation is setting in." % m_name)
				elif dwf == 10:
					day_lines.append("CRITICAL: %s is dangerously weak from starvation and needs soup immediately!" % m_name)
				if int(m.get("thirst", 0)) <= 1 and int(m.get("hunger", 0)) <= 1 and int(m.get("fatigue", 0)) > 0:
					m["fatigue"] = maxi(0, int(m.get("fatigue", 0)) - 1)

	if not fed_names.is_empty() or not watered_names.is_empty():
		var ration_bits: Array[String] = []
		if not watered_names.is_empty():
			ration_bits.append("water rationed to %s" % _join_names_naturally(watered_names))
		if not fed_names.is_empty():
			ration_bits.append("warm tomato soup shared with %s" % _join_names_naturally(fed_names))
		day_lines.append("Daily rations distributed: %s." % "; ".join(ration_bits))

	# 5. Health, Cold/Heat, Sickness, Injury, Radiation Mutation & Sanity Progression
	var has_medic_or_book: bool = GameState.has_working_item("book") or _any_bunker_member_has_trait("medic")
	var has_axe: bool = GameState.has_working_item("axe")
	var has_book: bool = GameState.has_working_item("book")
	var morale_sources: Array[String] = _collect_working_morale_sources()
	var morale_flavor_logged: bool = false

	for raw_m in GameState.get_living_bunker_members():
		var m: Dictionary = raw_m
		var m_name: String = str(m.get("name", "Survivor"))
		var trait_id: String = str(m.get("trait", "")).to_lower()
		var is_mutant: bool = bool(m.get("is_mutant", false))
		var iron_resist_mult: float = 0.5 if trait_id == "iron_stomach" else 1.0

		# Radiation: acute radiation sickness from the 7-day dose (RadiationModel).
		var recent_msv: float = RadiationModel.recent_dose(m, cur_day)
		m["dose_recent_msv"] = recent_msv
		m["radiation"] = recent_msv / 50.0
		var ars: int = RadiationModel.ars_stage(recent_msv)
		m["ars_stage"] = ars
		var rad_val: float = float(m.get("radiation", 0.0))
		if not is_mutant and ars >= 2 and ars < 4:
			# Mild/moderate ARS: nausea and fever unless well fed and watered.
			var ars_p: float = (0.25 if ars == 2 else 0.5) * iron_resist_mult
			if int(m.get("hunger", 0)) >= 2 or int(m.get("thirst", 0)) >= 2:
				ars_p += 0.2
			if int(m.get("sickness", 0)) < ars - 1 and rng.randf() < ars_p:
				m["sickness"] = maxi(int(m.get("sickness", 0)), ars - 1)
				day_lines.append("%s is showing %s — nausea and fever." % [m_name, RadiationModel.ars_label(ars).to_lower()])
		if not is_mutant and ars >= 4:
			# Severe ARS: marrow failure. Water, food and a medkit improve the odds; nothing guarantees them.
			var care: float = 0.0
			if int(m.get("thirst", 0)) == 0:
				care += 0.1
			if int(m.get("hunger", 0)) == 0:
				care += 0.05
			var p_die: float = clampf((0.12 if ars == 4 else 0.35) - care, 0.03, 0.6)
			m["sickness"] = maxi(int(m.get("sickness", 0)), 2)
			if rng.randf() < p_die:
				m["alive"] = false
				m["death_reason"] = "Died of acute radiation sickness (%s in a week)." % RadiationModel.format_dose(recent_msv)
				deaths_today.append(m_name)
				day_lines.append("%s's body could not recover from %s of radiation in a week. %s died in the night." % [m_name, RadiationModel.format_dose(recent_msv), m_name])
				continue
		if not is_mutant and rad_val > 65.0:
			if rng.randf() < 0.18:
				m["is_mutant"] = true
				is_mutant = true
				m["sickness"] = 0
				m["injury"] = 0
				m["thirst"] = 0
				m["days_without_water"] = 0
				m["radiation"] = 0.0
				m["sick_days"] = 0
				m["injury_days"] = 0
				day_lines.append("ATOMIC MIRACLE! High radiation triggered an extraordinary mutation in %s—glowing emerald skin cured all sickness and thirst forever!" % m_name)
			else:
				if int(m.get("sickness", 0)) < 2 and rng.randf() < (0.45 * iron_resist_mult):
					m["sickness"] = maxi(int(m.get("sickness", 0)), 2)
					day_lines.append("A heavy recent dose (%s) left %s violently feverish." % [RadiationModel.format_dose(recent_msv), m_name])

		if is_mutant:
			m["sickness"] = 0
			m["sick_days"] = 0
			m["injury"] = 0
			m["injury_days"] = 0
			m["thirst"] = 0
			m["days_without_water"] = 0
			m["radiation"] = 0.0
			continue

		# Extreme Cold (< 0.0 C from Nuclear Winter) sickness risk if hungry
		var hunger_now: int = int(m.get("hunger", 0))
		var thirst_now: int = int(m.get("thirst", 0))
		if GameState.bunker_temp_c < 0.0 and hunger_now >= 1:
			var chill_chance: float = (0.24 if GameState.bunker_temp_c >= -6.0 else 0.34) * iron_resist_mult
			if has_axe:
				chill_chance *= 0.35
			if has_book:
				chill_chance *= 0.50
			if rng.randf() < chill_chance and int(m.get("sickness", 0)) == 0:
				m["sickness"] = 1
				day_lines.append("Shivering in the sub-zero shelter air (%.1f °C) on an empty stomach, %s caught a rattling chest cold." % [GameState.bunker_temp_c, m_name])

		# Weakened bodies catch infections: dehydration and hunger raise the odds of falling ill.
		if int(m.get("sickness", 0)) == 0 and (thirst_now >= 2 or hunger_now >= 3):
			var weak_p: float = (0.08 + 0.06 * float(maxi(thirst_now - 1, 0)) + 0.04 * float(maxi(hunger_now - 2, 0))) * iron_resist_mult
			if rng.randf() < weak_p:
				m["sickness"] = 1
				day_lines.append("Weak from %s, %s came down with a fever." % ["thirst" if thirst_now >= 2 else "hunger", m_name])

		# Sickness & Injury Natural Recovery vs Fatal Escalation
		var sick_lvl: int = int(m.get("sickness", 0))
		var inj_lvl: int = int(m.get("injury", 0))

		if hunger_now == 0 and thirst_now == 0 and (sick_lvl > 0 or inj_lvl > 0):
			var rec_chance: float = 0.32 + (0.15 if has_medic_or_book else 0.0)
			# Radiation sickness suppresses the immune system and slows healing.
			if ars >= 3:
				rec_chance *= 0.35
			elif ars == 2:
				rec_chance *= 0.7
			if sick_lvl > 0 and rng.randf() < rec_chance:
				sick_lvl = maxi(0, sick_lvl - 1)
				m["sickness"] = sick_lvl
				if sick_lvl == 0:
					m["sick_days"] = 0
					day_lines.append("Well-fed and hydrated, %s fought off the illness naturally!" % m_name)
			if inj_lvl > 0 and rng.randf() < rec_chance:
				inj_lvl = maxi(0, inj_lvl - 1)
				m["injury"] = inj_lvl
				if inj_lvl == 0:
					m["injury_days"] = 0
					day_lines.append("Rest, water, and hot soup helped %s's wounds mend." % m_name)

		sick_lvl = int(m.get("sickness", 0))
		inj_lvl = int(m.get("injury", 0))
		var malnourished: bool = (hunger_now >= 2 or thirst_now >= 2)

		if sick_lvl > 0:
			var s_days: int = int(m.get("sick_days", 0)) + 1
			m["sick_days"] = s_days
			if sick_lvl == 1 and malnourished and s_days >= 3 and rng.randf() < (0.28 * iron_resist_mult):
				sick_lvl = 2
				m["sickness"] = 2
				day_lines.append("%s's untreated illness worsened into a burning fever!" % m_name)
			elif sick_lvl >= 2 and s_days >= 4:
				var mal_pen: float = (0.16 * iron_resist_mult) if malnourished else 0.0
				# Fever dehydrates: an untreated fever without water is far more dangerous.
				if thirst_now >= 2:
					mal_pen += 0.1
				var fatal_s_prob: float = (0.08 + float(s_days - 4) * 0.07) * iron_resist_mult + mal_pen
				if sick_lvl >= 3:
					fatal_s_prob += 0.10 * iron_resist_mult
				if rng.randf() < fatal_s_prob:
					m["alive"] = false
					m["death_reason"] = "Succumbed to untreated fever and sickness."
					deaths_today.append(m_name)
					day_lines.append("Without medicine to break the fever, %s passed away quietly in the night." % m_name)
					continue
		else:
			m["sick_days"] = 0

		if inj_lvl > 0:
			var i_days: int = int(m.get("injury_days", 0)) + 1
			m["injury_days"] = i_days
			if inj_lvl == 1 and malnourished and i_days >= 3 and rng.randf() < 0.25:
				inj_lvl = 2
				m["injury"] = 2
				day_lines.append("%s's untreated cuts grew inflamed and infected!" % m_name)
			elif inj_lvl >= 2 and i_days >= 4:
				var fatal_i_prob: float = 0.08 + float(i_days - 4) * 0.07 + (0.16 if malnourished else 0.0) + (0.12 if ars >= 3 else 0.0)
				if inj_lvl >= 3:
					fatal_i_prob += 0.10
				if rng.randf() < fatal_i_prob:
					m["alive"] = false
					m["death_reason"] = "Succumbed to untreated festering injuries."
					deaths_today.append(m_name)
					day_lines.append("%s's untreated wounds turned fatal during the night." % m_name)
					continue
		else:
			m["injury_days"] = 0

	# Sanity Progression (runs after any deaths today so grief is felt immediately)
	var living_now: Array = GameState.get_living_bunker_members()
	var solo_isolated: bool = (living_now.size() == 1 and GameState.active_expedition.is_empty())
	var ev_morale: int = int((event_notes as Dictionary).get("morale_delta", 0)) if event_notes is Dictionary else 0
	var has_elder_in_bunker: bool = _any_bunker_member_has_role("elder")
	var has_optimist_in_bunker: bool = _any_bunker_member_has_trait("optimist")

	for raw_m in living_now:
		var m: Dictionary = raw_m
		var m_name: String = str(m.get("name", "Survivor"))
		var role_str: String = str(m.get("role", "adult")).to_lower()
		var trait_id: String = str(m.get("trait", "")).to_lower()
		var cur_sanity: int = int(m.get("sanity", 0))
		var calm_nature: bool = (trait_id == "optimist" or trait_id == "calm" or trait_id == "bookworm" or role_str == "elder")

		var stress_delta: int = 0
		if not deaths_today.is_empty():
			if not calm_nature or rng.randf() < 0.5:
				stress_delta += 1
		if solo_isolated and rng.randf() < (0.18 if calm_nature else 0.35):
			stress_delta += 1
		if (int(m.get("thirst", 0)) >= 2 or int(m.get("hunger", 0)) >= 2) and rng.randf() < (0.14 if calm_nature else 0.28):
			stress_delta += 1
		if ev_morale <= -2:
			stress_delta += 1
		elif ev_morale == -1 and rng.randf() < 0.50:
			stress_delta += 1

		cur_sanity = mini(3, cur_sanity + stress_delta)

		if ev_morale >= 2:
			cur_sanity = maxi(0, cur_sanity - 1)
		elif ev_morale == 1 and rng.randf() < 0.50:
			cur_sanity = maxi(0, cur_sanity - 1)

		# Morale Items, Household Optimist/Elder & Bookworm Stabilize / Improve Sanity
		var personal_morale_cnt: int = morale_sources.size()
		if has_elder_in_bunker:
			personal_morale_cnt += 1
		if has_optimist_in_bunker:
			personal_morale_cnt += 1
		if trait_id == "bookworm":
			personal_morale_cnt += 1
			if has_book:
				personal_morale_cnt += 1

		if personal_morale_cnt > 0 and cur_sanity > 0 and deaths_today.is_empty():
			var soothe_prob: float = clampf(0.24 + float(personal_morale_cnt) * 0.12, 0.24, 0.78)
			if rng.randf() < soothe_prob:
				cur_sanity = maxi(0, cur_sanity - 1)
				if not morale_flavor_logged and not morale_sources.is_empty():
					var picked_source: String = morale_sources[rng.randi_range(0, morale_sources.size() - 1)]
					day_lines.append(_build_morale_remark(m_name, picked_source))
					morale_flavor_logged = true
		elif not morale_flavor_logged and not morale_sources.is_empty() and rng.randf() < 0.28:
			var ambient_src: String = morale_sources[rng.randi_range(0, morale_sources.size() - 1)]
			day_lines.append(_build_morale_remark(m_name, ambient_src))
			morale_flavor_logged = true

		m["sanity"] = cur_sanity

		# Insanity Consequences (sanity >= 3 for multiple days)
		if cur_sanity >= 3:
			var ins_days: int = int(m.get("insane_days", 0)) + 1
			m["insane_days"] = ins_days
			if ins_days == 1:
				day_lines.append("%s has started arguing with shadow puppets on the bunker wall—cabin fever has reached full madness!" % m_name)
			elif ins_days >= 3 and rng.randf() < 0.20:
				m["alive"] = false
				m["in_bunker"] = false
				m["death_reason"] = "Unbolted the hatch in a fit of cabin fever and vanished into the wasteland."
				day_lines.append("Before anyone could grab the ladder, a delirious %s spun the hatch wheel open and wandered singing into the radioactive fog!" % m_name)
				continue
			elif ins_days >= 2 and rng.randf() < 0.28:
				var broken_id: String = _break_random_working_durable(rng)
				if broken_id != "":
					var b_label: String = str(ITEM_LABELS.get(broken_id, broken_id.capitalize()))
					day_lines.append("In a paranoid outburst, %s hurled our %s against the concrete bulkhead and broke it!" % [m_name, b_label])
		else:
			m["insane_days"] = 0

	# 6. Pet Upkeep & Bonus Moments (Sharikov & Pancake)
	var pet_line: String = _tick_companions(cur_day, rng)
	if pet_line != "":
		day_lines.append(pet_line)

	# 7. Expedition Tick (existing trip) & Launch (new trip)
	if not GameState.active_expedition.is_empty():
		var exp_result: Dictionary = ExpeditionEngine.tick_active_expedition()
		var exp_text: String = str(exp_result.get("narrative", ""))
		if exp_text != "":
			day_lines.append(exp_text)

	if not expedition_launch.is_empty() and GameState.active_expedition.is_empty():
		var launch_member_id: String = str(expedition_launch.get("member_id", expedition_launch.get("member", "")))
		var launch_poi_idx: int = int(expedition_launch.get("poi_index", expedition_launch.get("target_index", expedition_launch.get("index", 0))))
		var launch_gear: Array = expedition_launch.get("gear_ids", expedition_launch.get("gear", []))
		if launch_member_id != "":
			var depart_line: String = ExpeditionEngine.start_expedition(launch_member_id, launch_poi_idx, launch_gear)
			if depart_line != "":
				day_lines.append(depart_line)

	# 8. Win / Loss Evaluation
	var end_line: String = _evaluate_win_or_loss(house_addr)
	if end_line != "":
		day_lines.append(end_line)

	_refresh_all_status_notes()
	var day_title: String = "DAY %d — %s" % [cur_day, LocationText.area_header().to_upper()]
	GameState.daily_log_entries.append({
		"day": cur_day,
		"title": day_title,
		"lines": day_lines.duplicate(),
		"text": day_title + "\n" + "\n".join(day_lines)
	})
	GameState.inventory_changed.emit()
	GameState.family_changed.emit()
	GameState.day_advanced.emit(GameState.day)

	return day_lines


static func get_latest_day_report() -> String:
	if GameState.daily_log_entries.is_empty():
		return ""
	var latest: Variant = GameState.daily_log_entries.back()
	if latest is Dictionary:
		var d: Dictionary = latest
		return str(d.get("text", ""))
	return str(latest)


static func get_condition_labels(member: Dictionary) -> Array[String]:
	var badges: Array[String] = []
	if not bool(member.get("alive", false)):
		badges.append("Deceased")
		return badges
	if bool(member.get("on_expedition", false)):
		badges.append("On Expedition (%dd)" % int(member.get("days_away", 1)))
	if bool(member.get("is_mutant", false)):
		badges.append("Mutant")

	var t: int = int(member.get("thirst", 0))
	if t == 1:
		badges.append("Thirsty")
	elif t == 2:
		badges.append("Dehydrated")
	elif t >= 3:
		badges.append("Parched!")

	var h: int = int(member.get("hunger", 0))
	if h == 1:
		badges.append("Hungry")
	elif h == 2:
		badges.append("Starving")
	elif h >= 3:
		badges.append("Famished!")

	var s: int = int(member.get("sickness", 0))
	if s == 1:
		badges.append("Mildly Ill")
	elif s == 2:
		badges.append("Sick")
	elif s >= 3:
		badges.append("Critically Sick!")

	var inj: int = int(member.get("injury", 0))
	if inj == 1:
		badges.append("Bruised")
	elif inj == 2:
		badges.append("Wounded")
	elif inj >= 3:
		badges.append("Severely Injured!")

	var san: int = int(member.get("sanity", 0))
	if san == 1:
		badges.append("Stressed")
	elif san == 2:
		badges.append("Unhinged")
	elif san >= 3:
		badges.append("Insane!")

	var fat: int = int(member.get("fatigue", 0))
	if fat == 1:
		badges.append("Tired")
	elif fat >= 2:
		badges.append("Exhausted")

	if badges.is_empty():
		badges.append("Healthy")
	return badges


static func _tick_radiation_and_weather(generous_hot_soup: bool, rng: RandomNumberGenerator) -> String:
	var nuke: Dictionary = GameState.nuke_config
	var init_sv: float = maxf(0.2, float(nuke.get("initial_sv_hr", 4.5)))
	var fallout_days: int = maxi(3, int(nuke.get("fallout_days", 14)))
	var zone_str: String = str(nuke.get("zone", "fallout_plume")).to_lower()

	# Radiation now follows RadiationModel (t^-1.2 decay, plume, hotspots); see advance_day().

	var is_nuclear_winter: bool = (zone_str.find("winter") != -1) or (float(nuke.get("bunker_temp_c", 20.0)) <= 5.0)
	var has_axe: bool = GameState.has_working_item("axe")
	var has_book: bool = GameState.has_working_item("book")

	if is_nuclear_winter:
		if has_axe or has_book or generous_hot_soup:
			GameState.bunker_temp_c = clampf(GameState.bunker_temp_c + rng.randf_range(0.3, 1.0), -12.0, 14.5)
			if GameState.bunker_temp_c < 5.0:
				if has_axe:
					return "Nuclear winter howls above, but kindling split with our Fireman's Axe kept the shelter stove glowing."
				elif generous_hot_soup:
					return "Extra steaming mugs of tomato soup kept everyone's hands warm against the nuclear winter chill."
				else:
					return "Insulation tips from the Survival Handbook kept the freezing nuclear winter draft sealed out."
		else:
			GameState.bunker_temp_c = maxf(-15.0, GameState.bunker_temp_c - rng.randf_range(0.9, 1.7))
			if GameState.bunker_temp_c < 0.0:
				return "Soot-darkened skies have plunged the block into nuclear winter (%.1f °C)—rime frost coats the hatch bolts!" % GameState.bunker_temp_c
	elif GameState.bunker_temp_c > 21.5:
		if GameState.day <= 2 and GameState.bunker_temp_c >= 25.0 and GameState.bunker_temp_c < 26.0:
			# Near-blast ground heat lingers through Day 2 before cooling
			GameState.bunker_temp_c = GameState.bunker_temp_c
		else:
			GameState.bunker_temp_c = move_toward(GameState.bunker_temp_c, 18.5, rng.randf_range(0.6, 1.3))
	else:
		GameState.bunker_temp_c = clampf(GameState.bunker_temp_c + rng.randf_range(-0.35, 0.35), 16.5, 20.5)

	return ""


static func _thirst_tier_for_days(days_without_water: int) -> int:
	if days_without_water <= 1:
		return 0
	elif days_without_water <= 3:
		return 1
	elif days_without_water == 4:
		return 2
	return 3


static func _hunger_tier_for_days(days_without_food: int) -> int:
	if days_without_food <= 2:
		return 0
	elif days_without_food <= 5:
		return 1
	elif days_without_food <= 9:
		return 2
	return 3


static func _extract_member_ration_quarters(ration_plan: Dictionary, member_id: String) -> Vector2i:
	if not ration_plan.has(member_id):
		return Vector2i(0, 0)
	var entry: Variant = ration_plan.get(member_id)
	if not (entry is Dictionary):
		return Vector2i(0, 0)
	var d: Dictionary = entry
	var soup_q: int = 0
	var water_q: int = 0

	if d.has("soup_q"):
		soup_q = int(d.get("soup_q", 0))
	elif d.has("soup_quarters"):
		soup_q = int(d.get("soup_quarters", 0))
	elif d.has("soup"):
		var sv: Variant = d.get("soup", 0)
		soup_q = (1 if bool(sv) else 0) if (sv is bool) else int(sv)

	if d.has("water_q"):
		water_q = int(d.get("water_q", 0))
	elif d.has("water_quarters"):
		water_q = int(d.get("water_quarters", 0))
	elif d.has("water"):
		var wv: Variant = d.get("water", 0)
		water_q = (1 if bool(wv) else 0) if (wv is bool) else int(wv)

	return Vector2i(maxi(0, soup_q), maxi(0, water_q))


static func _sum_planned_soup_quarters(ration_plan: Dictionary, bunker_members: Array) -> int:
	var total: int = 0
	for raw_m in bunker_members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		var m_id: String = str(m.get("id", ""))
		var q: Vector2i = _extract_member_ration_quarters(ration_plan, m_id)
		total += q.x
	return total


static func _extract_event_notes(event_notes: Variant) -> Array[String]:
	var res: Array[String] = []
	if event_notes == null:
		return res
	if event_notes is Array:
		var arr: Array = event_notes
		for item in arr:
			var s: String = str(item).replace("**", "").strip_edges()
			if s != "":
				res.append(s)
	elif event_notes is Dictionary:
		var d: Dictionary = event_notes
		var outcome_txt: String = str(d.get("outcome_text", d.get("text", d.get("log", "")))).replace("**", "").strip_edges()
		if outcome_txt != "":
			res.append(outcome_txt)
		var sub_notes: Variant = d.get("notes", [])
		if sub_notes is Array:
			var sub_arr: Array = sub_notes
			for sub_item in sub_arr:
				var sub_s: String = str(sub_item).replace("**", "").strip_edges()
				if sub_s != "" and not res.has(sub_s):
					res.append(sub_s)
	elif event_notes is String:
		var direct_s: String = str(event_notes).replace("**", "").strip_edges()
		if direct_s != "":
			res.append(direct_s)
	return res


static func _collect_working_morale_sources() -> Array[String]:
	var sources: Array[String] = []
	for item_id in ["cards", "checkers", "harmonica", "radio"]:
		if GameState.has_working_item(item_id):
			sources.append(item_id)
	if GameState.has_cat_sharikov:
		sources.append("cat")
	if GameState.has_dog_pancake:
		sources.append("dog")
	return sources


static func _build_morale_remark(member_name: String, source_id: String) -> String:
	match source_id:
		"cards":
			return "A spirited hand of gin rummy with our dog-eared Playing Cards lifted %s's spirits." % member_name
		"checkers":
			return "%s set up the Checkers board on an upturned crate, keeping everyone's mind off the fallout." % member_name
		"harmonica":
			return "%s played a warm 1950s melody on the Harmonica that echoed softly around the bunker." % member_name
		"radio":
			return "%s tuned the CONELRAD Radio past static until a crackly big-band jazz record cheered the room." % member_name
		"cat":
			return "Sharikov the cat curled into a purring loaf on %s's lap, melting away bunker tension." % member_name
		"dog":
			return "Pancake thumped his tail against the shelter floor and licked %s's cheek, keeping morale bright!" % member_name
		_:
			return "%s shared stories from the Survival Handbook to keep spirits steady." % member_name


static func _tick_companions(cur_day: int, rng: RandomNumberGenerator) -> String:
	if not GameState.has_cat_sharikov and not GameState.has_dog_pancake:
		return ""
	if cur_day % 4 == 0:
		if GameState.soup_quarters >= 1:
			GameState.soup_quarters -= 1
			if GameState.has_cat_sharikov and GameState.has_dog_pancake:
				return "Sharikov and Pancake split a quarter-tin of tomato soup (1/4 can) and patrolled the pantry for beetles."
			elif GameState.has_cat_sharikov:
				return "Sharikov delicately lapped up a spoonful of soup (1/4 can) and stood guard by the air vent."
			else:
				return "Pancake happily polished off a quarter-tin of soup (1/4 can) and stood watch beside the hatch."
		else:
			var pet_escape_notes: Array[String] = []
			if GameState.has_cat_sharikov and rng.randf() < 0.50:
				GameState.has_cat_sharikov = false
				pet_escape_notes.append("With zero soup left on the shelf, hungry Sharikov gave one last reproachful meow and slipped out through an air vent into the night.")
			if GameState.has_dog_pancake and rng.randf() < 0.50:
				GameState.has_dog_pancake = false
				pet_escape_notes.append("Whimpering beside an empty soup tin, hungry Pancake nuzzled our hands goodbye and squeezed out through the exhaust duct in search of scraps.")
			if not pet_escape_notes.is_empty():
				return " ".join(pet_escape_notes)
			return "With the soup shelf completely bare, our hungry pet whimpered softly beside an empty bowl."

	if GameState.has_dog_pancake and rng.randf() < 0.14:
		GameState.add_scavenged_item("soup", 1)
		return "Good boy, Pancake! Our loyal mutt pawed behind a loose storage crate and uncovered a forgotten can of Tomato Soup!"
	if GameState.has_cat_sharikov and rng.randf() < 0.12:
		var sci: int = int(GameState.rescue_chains.get("scientist", 0))
		if sci > 0 and sci < 3 and rng.randf() < 0.35:
			GameState.rescue_chains["scientist"] = mini(3, sci + 1)
			return "Sharikov's collar transmitter blinked green, relaying telemetry to the subterranean Vault Scientists (Scientist %d/3)!" % int(GameState.rescue_chains["scientist"])
	return ""


static func _break_random_working_durable(rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	for raw_k in GameState.bunker_items.keys():
		var gid: String = str(raw_k)
		if GameState.has_working_item(gid):
			candidates.append(gid)
	if candidates.is_empty():
		return ""
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	GameState.break_or_consume_item(chosen)
	return chosen


static func _evaluate_win_or_loss(house_addr: String) -> String:
	var all_living: Array = _get_all_living_household_members()
	var survivor_names: Array[String] = []
	for raw_m in all_living:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			survivor_names.append(str(m.get("name", "Survivor")))
	var names_str: String = _join_names_naturally(survivor_names) if not survivor_names.is_empty() else "our survivors"

	if GameState.bunker_structural_integrity <= 0.0:
		GameState.game_over = true
		GameState.victory = false
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "DEFEAT: Shelter Overrun & Breached"
		if GameState.ending_description.strip_edges() == "":
			GameState.ending_description = "On Day %d, structural integrity beneath %s gave way completely, leaving the shelter overrun by the wasteland." % [
				GameState.day, house_addr
			]
		return "The shelter hatch and walls beneath %s gave way completely on Day %d." % [house_addr, GameState.day]

	if all_living.is_empty():
		GameState.game_over = true
		GameState.victory = false
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "CLAIMED BY THE WASTELAND"
		if GameState.ending_description.strip_edges() == "":
			GameState.ending_description = "After %d days beneath %s, the last light in the fallout shelter flickered out. Our journal remains behind on the concrete table as a testament to our struggle." % [
				GameState.day, house_addr
			]
		return "Silence settles permanently inside the shelter beneath %s on Day %d." % [house_addr, GameState.day]

	if not _has_living_guardian(all_living):
		GameState.game_over = true
		GameState.victory = false
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "NO ADULT GUARDIAN IN SHELTER"
		if GameState.ending_description.strip_edges() == "":
			GameState.ending_description = "Only young children remained alive beneath %s without an adult or teenager to operate shelter life support." % house_addr
		return "With no surviving adult or teenager left to run shelter life support beneath %s, the young children could not endure alone." % house_addr

	var mil_stage: int = int(GameState.rescue_chains.get("military", 0))
	var sanc_stage: int = int(GameState.rescue_chains.get("sanctuary", 0))
	var sci_stage: int = int(GameState.rescue_chains.get("scientist", 0))

	if mil_stage >= 3:
		GameState.victory = true
		GameState.game_over = true
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "CIVIL DEFENSE EXTRACTION!"
		if GameState.ending_description.strip_edges() == "":
			GameState.ending_description = "On Day %d, heavy diesel engines rumbled above %s! Guided by our CONELRAD broadcasts and Civil Defense signals, an armored Army rescue column winched open the bunker hatch and airlifted %s to a clean safe-zone." % [
				GameState.day, house_addr, names_str
			]
		return "VICTORY! Rhythmic Civil Defense knocks rang on the steel hatch—Army rescue troopers have arrived above %s to evacuate %s!" % [house_addr, names_str]

	if sanc_stage >= 3:
		GameState.victory = true
		GameState.game_over = true
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "NEIGHBORHOOD SANCTUARY!"
		if GameState.ending_description.strip_edges() == "":
			var sanc_place: String = EventDeck._get_sanctuary_poi_name()
			GameState.ending_description = "On day %d the survivors organised at %s sent an escort to %s and brought %s into their shelter, where water and food are shared." % [
				GameState.day, sanc_place if sanc_place != "" else "a nearby shelter", house_addr, names_str
			]
		return "VICTORY! Neighborhood sanctuary bells rang across the block—friends from our local shelter escorted %s from %s into a safe, rebuilt community!" % [names_str, house_addr]

	if sci_stage >= 3:
		GameState.victory = true
		GameState.game_over = true
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "VAULT INSTITUTE RECLAMATION!"
		if GameState.ending_description.strip_edges() == "":
			var cat_clause: String = "—with Sharikov purring proudly in the lead—" if GameState.has_cat_sharikov else ""
			GameState.ending_description = "On Day %d, silver-suited Vault Institute researchers unsealed the hatch beneath %s%s and escorted %s into a gleaming subterranean biodome untouched by the fallout!" % [
				GameState.day, house_addr, cat_clause, names_str
			]
		return "VICTORY! Vault Institute scientists arrived with radiation-shielded transports beneath %s to welcome %s into their underground biodome!" % [house_addr, names_str]

	if GameState.victory:
		GameState.game_over = true
		if GameState.ending_title.strip_edges() == "":
			GameState.ending_title = "SURVIVAL VICTORY!"
		if GameState.ending_description.strip_edges() == "":
			GameState.ending_description = "On Day %d, %s emerged safely from the shelter beneath %s into a hopeful new chapter!" % [
				GameState.day, names_str, house_addr
			]
		return "VICTORY! %s safely evacuated from %s!" % [names_str, house_addr]

	var living_inside: Array = GameState.get_living_bunker_members()
	if living_inside.is_empty():
		var out_name: String = str(GameState.active_expedition.get("member_name", names_str))
		return "The shelter lies hauntingly empty inside—our sole remaining hope, %s, is still out in the wasteland..." % out_name

	return ""


static func _refresh_all_status_notes() -> void:
	for raw_m in GameState.family_members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		if bool(m.get("is_mutant", false)):
			m["sickness"] = 0
			m["sick_days"] = 0
		if not bool(m.get("alive", false)):
			var reason: String = str(m.get("death_reason", "Deceased."))
			m["status_note"] = reason if reason != "" else "Deceased."
			continue
		if bool(m.get("on_expedition", false)):
			var d_left: int = maxi(1, int(m.get("days_away", 1)))
			var tgt: String = str(GameState.active_expedition.get("short_target_name", "the wasteland"))
			m["status_note"] = "Exploring %s (%dd left)." % [tgt, d_left]
			continue

		var notes: Array[String] = []
		if bool(m.get("is_mutant", false)):
			notes.append("Mutated (no water needed)")

		var t: int = int(m.get("thirst", 0))
		if t >= 3:
			notes.append("Critically parched!")
		elif t == 2:
			notes.append("Dehydrated")
		elif t == 1:
			notes.append("Thirsty")

		var h: int = int(m.get("hunger", 0))
		if h >= 3:
			notes.append("Starving critically!")
		elif h == 2:
			notes.append("Starving")
		elif h == 1:
			notes.append("Hungry")

		var s: int = int(m.get("sickness", 0))
		if s >= 2:
			notes.append("Feverish — needs Medkit!")
		elif s == 1:
			notes.append("Sniffles")

		var inj: int = int(m.get("injury", 0))
		if inj >= 2:
			notes.append("Wounded — needs Medkit!")
		elif inj == 1:
			notes.append("Bruised")

		var san: int = int(m.get("sanity", 0))
		if san >= 3:
			notes.append("Cabin-fever mad!")
		elif san == 2:
			notes.append("Unhinged")
		elif san == 1:
			notes.append("Uneasy")

		var fat: int = int(m.get("fatigue", 0))
		if fat >= 2:
			notes.append("Exhausted")
		elif fat == 1:
			notes.append("Tired")

		if notes.is_empty():
			m["status_note"] = "Healthy and holding steady."
		else:
			m["status_note"] = ", ".join(notes) + "."


static func _get_all_living_household_members() -> Array:
	var res: Array = []
	for raw_m in GameState.family_members:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if bool(m.get("alive", false)) and (bool(m.get("in_bunker", false)) or bool(m.get("on_expedition", false))):
				res.append(m)
	return res


static func _has_living_guardian(members: Array) -> bool:
	for raw_m in members:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if str(m.get("role", "adult")).to_lower() != "child" and int(m.get("age", 30)) >= 13:
				return true
	return false


static func _find_living_bunker_member(member_id: String) -> Dictionary:
	for raw_m in GameState.family_members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		if str(m.get("id", "")) == member_id:
			if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)) and not bool(m.get("on_expedition", false)):
				return m
	return {}


static func _any_bunker_member_has_trait(target_trait: String) -> bool:
	for raw_m in GameState.get_living_bunker_members():
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if str(m.get("trait", "")).to_lower() == target_trait.to_lower():
				return true
	return false


static func _any_bunker_member_has_role(target_role: String) -> bool:
	for raw_m in GameState.get_living_bunker_members():
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if str(m.get("role", "")).to_lower() == target_role.to_lower():
				return true
	return false


static func _humanize_zone(zone_id: String) -> String:
	var z: String = zone_id.replace("_", " ").strip_edges()
	return z.capitalize() if z != "" else "Fallout Plume"


static func _join_names_naturally(names: Array[String]) -> String:
	if names.is_empty():
		return "nobody"
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var head: Array[String] = []
	for i in range(names.size() - 1):
		head.append(names[i])
	return "%s, and %s" % [", ".join(head), names[names.size() - 1]]
