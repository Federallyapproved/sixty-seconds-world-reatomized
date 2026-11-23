class_name RelationshipSystem
extends RefCounted

## Pairwise Family Relationship Engine for "60 Seconds: World Reatomized" (V2).
## Governs 60s Scavenge survivor's guilt vs Full-House relief, daily ration fairness
## & favoritism resentment, medical gratitude bonds, devoted cooperation, heated bunker
## arguments, emotional breakdowns, and hostile overnight betrayal.

const MAX_RECENT_EVENTS: int = 16


static func apply_scavenge_trauma_or_relief() -> Array[String]:
	var lines: Array[String] = []
	var living_bunker: Array = _get_all_living_in_bunker()
	if living_bunker.is_empty():
		return lines

	var left_names: Array[String] = _collect_left_behind_names()
	var leader: Dictionary = _find_leader_member()
	var leader_id: String = str(leader.get("id", ""))
	var leader_name: String = str(leader.get("name", "the Scavenge Leader"))
	var leader_in_bunker: bool = bool(leader.get("alive", false)) and bool(leader.get("in_bunker", false))

	if not left_names.is_empty():
		var left_joined: String = _join_names(left_names)
		var mourner_name: String = ""
		for raw_m in living_bunker:
			if not (raw_m is Dictionary):
				continue
			var m: Dictionary = raw_m
			var m_id: String = str(m.get("id", ""))
			var m_name: String = str(m.get("name", "Survivor"))
			m["sanity"] = mini(3, int(m.get("sanity", 0)) + 1)
			m["last_bubble"] = "!"
			if m_id != "" and leader_id != "" and m_id != leader_id and leader_in_bunker:
				GameState.change_relationship(m_id, leader_id, -22)
				if mourner_name == "":
					mourner_name = m_name
			elif mourner_name == "":
				mourner_name = m_name

		if mourner_name == "":
			mourner_name = str((living_bunker[0] as Dictionary).get("name", "Everyone"))

		var guilt_line: String = ""
		if leader_in_bunker and living_bunker.size() >= 2 and mourner_name != leader_name:
			guilt_line = "%s can't stop staring at the hatch, haunted that %s was left behind (-22 relationship with %s, +1 grief stress)." % [
				mourner_name, left_joined, leader_name
			]
		else:
			guilt_line = "%s can't stop staring at the hatch, haunted that %s was left behind (+1 grief stress)..." % [
				mourner_name, left_joined
			]
		lines.append(guilt_line)
		_record_event("trauma", guilt_line)
		GameState.family_changed.emit()
		GameState.relationships_changed.emit()
		return lines

	# Nobody was left behind: check if all family members (>= 2) made it safely into the bunker
	var total_family: int = GameState.family_members.size()
	if living_bunker.size() >= 2 and living_bunker.size() == total_family:
		for i in range(living_bunker.size()):
			var ma: Dictionary = living_bunker[i]
			ma["last_bubble"] = "♥"
			var ida: String = str(ma.get("id", ""))
			for j in range(i + 1, living_bunker.size()):
				var mb: Dictionary = living_bunker[j]
				var idb: String = str(mb.get("id", ""))
				if ida != "" and idb != "":
					GameState.change_relationship(ida, idb, 12)
		GameState.run_metrics["bonds_formed"] = int(GameState.run_metrics.get("bonds_formed", 0)) + 1
		if total_family >= 4:
			GameState.unlock_achievement("full_house")
		var relief_line: String = "Everyone made it down the ladder together before detonation—tearful hugs beneath the hatch strengthened family bonds (+12 relationship)!"
		lines.append(relief_line)
		_record_event("relief", relief_line)
		GameState.family_changed.emit()
		GameState.relationships_changed.emit()

	return lines


static func evaluate_ration_fairness(ration_plan: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var living: Array = GameState.get_living_bunker_members()
	if living.size() < 2 or ration_plan.is_empty():
		return lines

	var pampered_soup: Array[Dictionary] = []
	var neglected_soup: Array[Dictionary] = []
	var pampered_water: Array[Dictionary] = []
	var neglected_water: Array[Dictionary] = []

	var total_rations_given: int = 0
	var recipients_count: int = 0
	var needy_count: int = 0
	var needy_cared_count: int = 0

	for raw_m in living:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		var m_id: String = str(m.get("id", ""))
		var is_mutant: bool = bool(m.get("is_mutant", false))
		var h_lvl: int = int(m.get("hunger", 0))
		var t_lvl: int = int(m.get("thirst", 0))
		var q: Vector2i = _extract_member_ration_quarters(ration_plan, m_id)
		var soup_q: int = q.x
		var water_q: int = q.y

		total_rations_given += soup_q + water_q
		if soup_q > 0 or water_q > 0:
			recipients_count += 1

		var is_needy: bool = (h_lvl >= 1) or (not is_mutant and t_lvl >= 1)
		if is_needy:
			needy_count += 1
			var got_needed_soup: bool = (h_lvl == 0) or (soup_q >= 1)
			var got_needed_water: bool = is_mutant or (t_lvl == 0) or (water_q >= 1)
			if got_needed_soup and got_needed_water:
				needy_cared_count += 1

		if h_lvl == 0 and soup_q > 0:
			pampered_soup.append(m)
		elif h_lvl >= 1 and soup_q == 0:
			neglected_soup.append(m)

		if not is_mutant:
			if t_lvl == 0 and water_q > 0:
				pampered_water.append(m)
			elif t_lvl >= 1 and water_q == 0:
				neglected_water.append(m)

	var soup_favoritism: bool = (not pampered_soup.is_empty()) and (not neglected_soup.is_empty())
	var water_favoritism: bool = (not pampered_water.is_empty()) and (not neglected_water.is_empty())

	if soup_favoritism or water_favoritism:
		var penalized_pairs: Dictionary = {}
		var neglected_names: Array[String] = []
		var pampered_names: Array[String] = []
		var leader: Dictionary = _find_leader_member()
		var leader_id: String = str(leader.get("id", ""))
		var leader_here: bool = _is_member_in_list(living, leader_id)

		var all_neglected: Array[Dictionary] = []
		for nm in neglected_soup:
			if not _is_member_in_list(all_neglected, str(nm.get("id", ""))):
				all_neglected.append(nm)
		for nm2 in neglected_water:
			if not _is_member_in_list(all_neglected, str(nm2.get("id", ""))):
				all_neglected.append(nm2)

		var all_pampered: Array[Dictionary] = []
		for pm in pampered_soup:
			if not _is_member_in_list(all_pampered, str(pm.get("id", ""))):
				all_pampered.append(pm)
		for pm2 in pampered_water:
			if not _is_member_in_list(all_pampered, str(pm2.get("id", ""))):
				all_pampered.append(pm2)

		for neg_m in all_neglected:
			var neg_id: String = str(neg_m.get("id", ""))
			var neg_name: String = str(neg_m.get("name", "Survivor"))
			neg_m["last_bubble"] = "⚡"
			if not neglected_names.has(neg_name):
				neglected_names.append(neg_name)

			for pamp_m in all_pampered:
				var pamp_id: String = str(pamp_m.get("id", ""))
				var pamp_name: String = str(pamp_m.get("name", "Survivor"))
				if not pampered_names.has(pamp_name):
					pampered_names.append(pamp_name)
				if neg_id != "" and pamp_id != "" and neg_id != pamp_id:
					var rk: String = GameState.make_rel_key(neg_id, pamp_id)
					if not penalized_pairs.has(rk):
						penalized_pairs[rk] = true
						GameState.change_relationship(neg_id, pamp_id, -12)

			if leader_here and leader_id != "" and leader_id != neg_id:
				var lk: String = GameState.make_rel_key(neg_id, leader_id)
				if not penalized_pairs.has(lk):
					penalized_pairs[lk] = true
					GameState.change_relationship(neg_id, leader_id, -12)

		var fav_line: String = "Bitter ration favoritism! %s went without needed rations while %s ate and drank despite being satisfied (-12 resentment ⚡)." % [
			_join_names(neglected_names), _join_names(pampered_names)
		]
		lines.append(fav_line)
		_record_event("favoritism", fav_line)
		GameState.family_changed.emit()
		return lines

	# Check fair sharing when supplies are tight
	var supplies_tight: bool = (
		GameState.soup_quarters <= living.size() * 4
		or GameState.water_quarters <= living.size() * 4
	)
	var shared_fairly: bool = (
		total_rations_given >= 2
		and recipients_count >= mini(2, living.size())
		and needy_count >= 2
		and needy_cared_count == needy_count
	)
	if supplies_tight and shared_fairly:
		for i in range(living.size()):
			var ma: Dictionary = living[i]
			var ida: String = str(ma.get("id", ""))
			if str(ma.get("last_bubble", "")) == "":
				ma["last_bubble"] = "♥"
			for j in range(i + 1, living.size()):
				var mb: Dictionary = living[j]
				var idb: String = str(mb.get("id", ""))
				if ida != "" and idb != "":
					GameState.change_relationship(ida, idb, 5)
		var fair_line: String = "Even with shelves running thin, fair ration sharing around the table fostered quiet trust (+5 family loyalty)."
		lines.append(fair_line)
		_record_event("fair_rations", fair_line)
		GameState.family_changed.emit()
	elif supplies_tight and needy_count >= 2 and (needy_count - needy_cared_count) >= 2:
		# Shared hardship: nobody was favoured, but too many went without. Tempers fray.
		for i in range(living.size()):
			var ha: Dictionary = living[i]
			var hida: String = str(ha.get("id", ""))
			for j in range(i + 1, living.size()):
				var hb: Dictionary = living[j]
				var hidb: String = str(hb.get("id", ""))
				if hida != "" and hidb != "":
					GameState.change_relationship(hida, hidb, -3)
		var hard_line: String = "Empty bowls all round. Nobody was singled out, but hunger shortens every temper in the shelter (-3 family friction)."
		lines.append(hard_line)
		_record_event("hardship", hard_line)
		GameState.family_changed.emit()

	return lines


static func on_medical_care_given(healer_or_leader_id: String, patient_id: String, item_used: String) -> String:
	var patient: Dictionary = _find_living_bunker_member(patient_id)
	if patient.is_empty():
		return ""

	var patient_name: String = str(patient.get("name", "Survivor"))
	patient["last_bubble"] = "♥"
	if int(patient.get("breakdown_days", 0)) > 0:
		patient["breakdown_days"] = maxi(0, int(patient.get("breakdown_days", 0)) - 1)

	var caregiver: Dictionary = _find_living_bunker_member(healer_or_leader_id)
	if caregiver.is_empty() or str(caregiver.get("id", "")) == patient_id:
		caregiver = _find_other_caregiver(patient_id)

	var nice_item: String = _humanize_medical_item(item_used)
	if caregiver.is_empty():
		GameState.family_changed.emit()
		return ""

	var caregiver_id: String = str(caregiver.get("id", ""))
	var caregiver_name: String = str(caregiver.get("name", "Survivor"))
	caregiver["last_bubble"] = "♥"
	GameState.change_relationship(caregiver_id, patient_id, 16)
	GameState.run_metrics["bonds_formed"] = int(GameState.run_metrics.get("bonds_formed", 0)) + 1

	var gratitude_line: String = "%s cared for %s with %s, earning deep gratitude (+16 relationship ♥)." % [
		caregiver_name, patient_name, nice_item
	]
	_record_event("medical_care", gratitude_line)
	GameState.family_changed.emit()
	return gratitude_line


static func tick_daily_relationships(rng: RandomNumberGenerator) -> Dictionary:
	var active_rng: RandomNumberGenerator = rng if rng != null else GameState.rng
	var lines: Array[String] = []
	var arguments_cnt: int = 0
	var bonds_cnt: int = 0
	var betrayal_member: String = ""

	var living: Array = GameState.get_living_bunker_members()
	if living.size() < 2:
		return {
			"lines": lines,
			"arguments": 0,
			"bonds": 0,
			"betrayal_member": ""
		}

	# 1. Devoted Cooperation (score >= 55)
	var devoted_logged: bool = false
	for i in range(living.size()):
		var ma: Dictionary = living[i]
		var ida: String = str(ma.get("id", ""))
		var name_a: String = str(ma.get("name", "Survivor"))
		for j in range(i + 1, living.size()):
			var mb: Dictionary = living[j]
			var idb: String = str(mb.get("id", ""))
			var name_b: String = str(mb.get("name", "Survivor"))
			var score: int = GameState.get_relationship(ida, idb)
			if score >= 55:
				bonds_cnt += 1
				GameState.unlock_achievement("unbreakable_bond")
				ma["last_bubble"] = "♥"
				mb["last_bubble"] = "♥"

				var soothed_someone: bool = false
				if int(ma.get("breakdown_days", 0)) > 0:
					ma["breakdown_days"] = 0
					soothed_someone = true
				if int(mb.get("breakdown_days", 0)) > 0:
					mb["breakdown_days"] = 0
					soothed_someone = true

				if int(ma.get("sanity", 0)) > 0 and active_rng.randf() < 0.55:
					ma["sanity"] = maxi(0, int(ma.get("sanity", 0)) - 1)
					soothed_someone = true
				elif int(mb.get("sanity", 0)) > 0 and active_rng.randf() < 0.55:
					mb["sanity"] = maxi(0, int(mb.get("sanity", 0)) - 1)
					soothed_someone = true

				var shared_warmth: bool = false
				if GameState.bunker_temp_c < 10.0:
					GameState.bunker_temp_c = minf(18.0, GameState.bunker_temp_c + 0.9)
					shared_warmth = true

				if not devoted_logged and (soothed_someone or shared_warmth or active_rng.randf() < 0.35):
					GameState.run_metrics["bonds_formed"] = int(GameState.run_metrics.get("bonds_formed", 0)) + 1
					var coop_line: String = ""
					if shared_warmth:
						coop_line = "Devoted bond: %s and %s huddled under a shared wool blanket, keeping each other warm and steady against the chill ♥." % [name_a, name_b]
					elif soothed_someone:
						coop_line = "Devoted bond: %s talked %s through dark thoughts beside the radio lantern, easing shelter stress ♥." % [name_a, name_b]
					else:
						coop_line = "Devoted cooperation: %s and %s worked side-by-side keeping the shelter tidy and spirits steady ♥." % [name_a, name_b]
					lines.append(coop_line)
					_record_event("devoted", coop_line)
					devoted_logged = true

	# 2. Resentful Arguments (score <= -35, 30% daily chance)
	var argument_triggered_today: bool = false
	for i in range(living.size()):
		if argument_triggered_today:
			break
		var ma: Dictionary = living[i]
		var ida: String = str(ma.get("id", ""))
		var name_a: String = str(ma.get("name", "Survivor"))
		for j in range(i + 1, living.size()):
			var mb: Dictionary = living[j]
			var idb: String = str(mb.get("id", ""))
			var name_b: String = str(mb.get("name", "Survivor"))
			var score: int = GameState.get_relationship(ida, idb)
			if score <= -35 and active_rng.randf() < 0.30:
				argument_triggered_today = true
				arguments_cnt += 1
				GameState.run_metrics["arguments_had"] = int(GameState.run_metrics.get("arguments_had", 0)) + 1
				ma["last_bubble"] = "⚡"
				mb["last_bubble"] = "⚡"
				GameState.change_relationship(ida, idb, -4)

				var arg_line: String = ""
				if active_rng.randf() < 0.20:
					if GameState.water_quarters >= 1 and active_rng.randf() < 0.55:
						GameState.water_quarters = maxi(0, GameState.water_quarters - 1)
						arg_line = "Heated argument! %s and %s shouted across the table and knocked over 1/4 bottle of Drinking Water ⚡!" % [name_a, name_b]
					else:
						GameState.bunker_structural_integrity = maxf(2.0, GameState.bunker_structural_integrity - 2.0)
						arg_line = "Fierce bunker argument! %s slammed a steel pipe during a shouting match with %s, chipping shelter integrity (-2%% hull) ⚡!" % [name_a, name_b]
					ma["sanity"] = mini(3, int(ma.get("sanity", 0)) + 1)
				else:
					ma["sanity"] = mini(3, int(ma.get("sanity", 0)) + 1)
					mb["sanity"] = mini(3, int(mb.get("sanity", 0)) + 1)
					arg_line = "Bitter resentment boiled over between %s and %s—their shouting match left everyone's nerves frayed (+1 stress ⚡)!" % [name_a, name_b]

				lines.append(arg_line)
				_record_event("argument", arg_line)
				break

	# 3. Emotional Breakdown (sanity >= 2 and avg_rel <= -20 and breakdown_days == 0 -> 25% chance)
	for raw_m in living:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		var m_id: String = str(m.get("id", ""))
		var m_name: String = str(m.get("name", "Survivor"))
		var cur_sanity: int = int(m.get("sanity", 0))
		var cur_bd: int = int(m.get("breakdown_days", 0))
		var avg_rel: int = GameState.get_member_avg_relationship(m_id)

		if cur_sanity >= 2 and avg_rel <= -20 and cur_bd == 0:
			if active_rng.randf() < 0.25:
				m["breakdown_days"] = 2
				m["last_bubble"] = "!"
				var bd_line: String = ""
				if GameState.soup_quarters >= 1 and active_rng.randf() < 0.55:
					GameState.soup_quarters = maxi(0, GameState.soup_quarters - 1)
					m["hunger"] = maxi(0, int(m.get("hunger", 0)) - 1)
					bd_line = "EMOTIONAL BREAKDOWN! Feeling isolated and unhinged, %s snuck 1/4 can of Soup overnight and refuses all expeditions for 2 days (!)!" % m_name
				else:
					bd_line = "EMOTIONAL BREAKDOWN! Overwhelmed by stress and family friction, %s curled up weeping by the bunk and refuses expeditions for 2 days (!)!" % m_name
				lines.append(bd_line)
				_record_event("breakdown", bd_line)
				break

	# 4. Hostile Betrayal (avg_rel <= -75 and (sanity >= 2 or hunger >= 2) and role != "child" and living.size() >= 2 -> 30% chance)
	var living_for_betrayal: Array = GameState.get_living_bunker_members()
	if living_for_betrayal.size() >= 2:
		for raw_m in living_for_betrayal:
			if not (raw_m is Dictionary):
				continue
			var m: Dictionary = raw_m
			var m_id: String = str(m.get("id", ""))
			var m_name: String = str(m.get("name", "Survivor"))
			var role_str: String = str(m.get("role", "adult")).to_lower()
			var san_val: int = int(m.get("sanity", 0))
			var hun_val: int = int(m.get("hunger", 0))
			var avg_rel: int = GameState.get_member_avg_relationship(m_id)

			if role_str != "child" and avg_rel <= -75 and (san_val >= 2 or hun_val >= 2):
				if active_rng.randf() < 0.30:
					var stolen_soup_q: int = mini(4, GameState.soup_quarters)
					var stolen_water_q: int = mini(4, GameState.water_quarters)
					GameState.soup_quarters = maxi(0, GameState.soup_quarters - stolen_soup_q)
					GameState.water_quarters = maxi(0, GameState.water_quarters - stolen_water_q)

					m["alive"] = false
					m["in_bunker"] = false
					m["on_expedition"] = false
					m["betrayed"] = true
					m["last_bubble"] = "⚡"
					m["death_reason"] = "Betrayed the family and fled into the wasteland with stolen rations."
					m["status_note"] = str(m["death_reason"])
					betrayal_member = m_name

					for raw_rem in GameState.get_living_bunker_members():
						if raw_rem is Dictionary:
							var rem_m: Dictionary = raw_rem
							rem_m["sanity"] = mini(3, int(rem_m.get("sanity", 0)) + 1)
							rem_m["last_bubble"] = "!"

					var bet_line: String = "HOSTILE BETRAYAL! Driven to bitter hatred, %s unbolted the blast hatch before dawn, stuffed %s Soup and %s Water into a sack, and abandoned the family forever!" % [
						m_name,
						GameState.format_quarters_as_cans(stolen_soup_q),
						GameState.format_quarters_as_cans(stolen_water_q)
					]
					lines.append(bet_line)
					_record_event("betrayal", bet_line)
					GameState.inventory_changed.emit()
					break

	GameState.family_changed.emit()
	GameState.relationships_changed.emit()
	return {
		"lines": lines,
		"arguments": arguments_cnt,
		"bonds": bonds_cnt,
		"betrayal_member": betrayal_member
	}


static func has_bonded_pair(min_score: int = 45) -> bool:
	var living: Array = GameState.get_living_bunker_members()
	for i in range(living.size()):
		if not (living[i] is Dictionary):
			continue
		var ida: String = str((living[i] as Dictionary).get("id", ""))
		for j in range(i + 1, living.size()):
			if not (living[j] is Dictionary):
				continue
			var idb: String = str((living[j] as Dictionary).get("id", ""))
			if ida != "" and idb != "" and GameState.get_relationship(ida, idb) >= min_score:
				return true
	return false


static func get_repair_cooperation_bonus() -> float:
	return 0.25 if has_bonded_pair(45) else 0.0


static func comfort_member(target_id: String) -> String:
	var target: Dictionary = _find_living_bunker_member(target_id)
	if target.is_empty():
		return ""
	var caregiver: Dictionary = _find_other_caregiver(target_id)
	var target_name: String = str(target.get("name", "Survivor"))
	target["breakdown_days"] = 0
	target["last_bubble"] = "♥"
	if int(target.get("sanity", 0)) > 0:
		target["sanity"] = maxi(0, int(target.get("sanity", 0)) - 1)
	if not caregiver.is_empty():
		var cid: String = str(caregiver.get("id", ""))
		var cname: String = str(caregiver.get("name", "Survivor"))
		caregiver["last_bubble"] = "♥"
		GameState.change_relationship(cid, target_id, 10)
		var line: String = "%s sat quietly with %s, calming their breakdown (+10 relationship ♥)." % [cname, target_name]
		_record_event("comfort", line)
		GameState.family_changed.emit()
		return line
	GameState.family_changed.emit()
	return "%s took a quiet moment to steady their breathing." % target_name


# --- Internal Helpers ---

static func _collect_left_behind_names() -> Array[String]:
	var names: Array[String] = []
	for raw_item in GameState.left_behind_members:
		if raw_item is Dictionary:
			var d: Dictionary = raw_item
			var nm: String = str(d.get("name", "")).strip_edges()
			if nm == "" and d.has("id"):
				nm = _member_name_by_id(str(d.get("id", "")))
			if nm != "" and not names.has(nm):
				names.append(nm)
		else:
			var s: String = str(raw_item).strip_edges()
			if s != "":
				var resolved: String = _member_name_by_id(s)
				var final_nm: String = resolved if resolved != "" else s
				if not names.has(final_nm):
					names.append(final_nm)
	return names


static func _member_name_by_id(id_or_name: String) -> String:
	for raw_m in GameState.family_members:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if str(m.get("id", "")) == id_or_name:
				return str(m.get("name", id_or_name))
	return ""


static func _get_all_living_in_bunker() -> Array:
	var out: Array = []
	for raw_m in GameState.family_members:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)):
				out.append(m)
	return out


static func _find_leader_member() -> Dictionary:
	for raw_m in GameState.family_members:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if bool(m.get("is_leader", false)):
				return m
	if not GameState.family_members.is_empty() and GameState.family_members[0] is Dictionary:
		return GameState.family_members[0]
	return {}


static func _find_living_bunker_member(member_id: String) -> Dictionary:
	if member_id == "":
		return {}
	for raw_m in GameState.family_members:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if str(m.get("id", "")) == member_id:
				if bool(m.get("alive", false)) and bool(m.get("in_bunker", false)) and not bool(m.get("on_expedition", false)):
					return m
	return {}


static func _find_other_caregiver(patient_id: String) -> Dictionary:
	var leader: Dictionary = _find_leader_member()
	var lid: String = str(leader.get("id", ""))
	if lid != "" and lid != patient_id and bool(leader.get("alive", false)) and bool(leader.get("in_bunker", false)) and not bool(leader.get("on_expedition", false)):
		return leader
	for raw_m in GameState.get_living_bunker_members():
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			if str(m.get("id", "")) != patient_id:
				return m
	return {}


static func _is_member_in_list(list: Array, member_id: String) -> bool:
	if member_id == "":
		return false
	for raw_m in list:
		if raw_m is Dictionary and str((raw_m as Dictionary).get("id", "")) == member_id:
			return true
	return false


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


static func _humanize_medical_item(item_used: String) -> String:
	var low: String = item_used.strip_edges().to_lower()
	match low:
		"medkit", "":
			return "a First Aid Medkit"
		"antibiotics":
			return "Prescription Antibiotics"
		"antirad":
			return "Potassium Iodide Anti-Rad Pills"
		_:
			return item_used


static func _record_event(kind: String, summary: String) -> void:
	GameState.recent_relationship_events.append({
		"day": GameState.day,
		"kind": kind,
		"text": summary
	})
	while GameState.recent_relationship_events.size() > MAX_RECENT_EVENTS:
		GameState.recent_relationship_events.pop_front()


static func _join_names(names: Array[String]) -> String:
	if names.is_empty():
		return "someone"
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var head: Array[String] = []
	for i in range(names.size() - 1):
		head.append(names[i])
	return "%s, and %s" % [", ".join(head), names[names.size() - 1]]
