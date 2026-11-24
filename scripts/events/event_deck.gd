class_name EventDeck
extends RefCounted

## 60 Seconds: World Reatomized — Branching Daily Event Deck.
## Combines 60 distinct classic 60 Seconds! Reatomized dark-comedy dilemmas,
## 3-stage Rescue Victory Chains (Military, Real-World OSM Sanctuary, Vault Scientist & Sharikov),
## Nuke Ground Zero / Nuclear Winter physics events, and live OpenStreetMap neighborhood stories.

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
	"dog": "Pancake the Dog"
}

const ALL_EVENT_IDS: Array[String] = [
	"day1_civil_defense_seal",
	"distant_second_strike",
	# 3-Stage Rescue Chains (9 events)
	"rescue_military_1",
	"rescue_military_2",
	"rescue_military_3",
	"rescue_sanctuary_1",
	"rescue_sanctuary_2",
	"rescue_sanctuary_3",
	"rescue_scientist_1",
	"rescue_scientist_2",
	"rescue_scientist_3",
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
	"classic_radio_quiz_show"
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

	# Fair, reliable Rescue Chain Pacing starting Day 5+
	if day >= 5 and _should_draw_rescue_event(day, active_rng):
		var rescue_id: String = _pick_rescue_event_id(day, active_rng)
		if rescue_id != "":
			_last_rescue_day = day
			_record_drawn_id(rescue_id)
			return build_event_by_id(rescue_id, day, active_rng)

	# Priority Contextual Check 1: Broken equipment repair opportunity
	var broken_ids: Array[String] = _get_broken_owned_item_ids()
	if not broken_ids.is_empty() and not _recent_event_ids.has("repair_broken_gear"):
		if active_rng.randf() < 0.30:
			_record_drawn_id("repair_broken_gear")
			return build_event_by_id("repair_broken_gear", day, active_rng)

	# Priority Contextual Check 2: Emergency Wasteland Doctor if someone is badly hurt/sick with 0 medkits
	if GameState.medkit_count <= 0 and _has_severely_afflicted_member() and not _recent_event_ids.has("classic_wandering_doctor"):
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

	# Safety fallback if history exhausted all weights
	if weighted_pool.is_empty() or total_weight <= 0.0:
		_recent_event_ids.clear()
		for ev_id in ALL_EVENT_IDS:
			if ev_id == "day1_civil_defense_seal" or ev_id.begins_with("rescue_"):
				continue
			var w_fb: float = maxf(0.2, _get_event_weight(ev_id, day))
			weighted_pool.append({"id": ev_id, "weight": w_fb})
			total_weight += w_fb

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
	_recent_event_ids.append(event_id)
	while _recent_event_ids.size() > 18:
		_recent_event_ids.remove_at(0)


static func _should_draw_rescue_event(day: int, rng: RandomNumberGenerator) -> bool:
	if _last_rescue_day == 0 and day >= 5:
		return true
	var gap: int = day - _last_rescue_day
	var mil_st: int = int(GameState.rescue_chains.get("military", 0))
	var sanc_st: int = int(GameState.rescue_chains.get("sanctuary", 0))
	var sci_st: int = int(GameState.rescue_chains.get("scientist", 0))
	var any_stage_two: bool = (mil_st == 2) or (sanc_st == 2) or (sci_st == 2)
	if any_stage_two and gap >= 3:
		return true
	if gap >= 4:
		return true
	if gap == 3 and rng.randf() < 0.60:
		return true
	return false


static func _pick_rescue_event_id(day: int, rng: RandomNumberGenerator) -> String:
	var mil_st: int = clampi(int(GameState.rescue_chains.get("military", 0)), 0, 3)
	var sanc_st: int = clampi(int(GameState.rescue_chains.get("sanctuary", 0)), 0, 3)
	var sci_st: int = clampi(int(GameState.rescue_chains.get("scientist", 0)), 0, 3)
	if sci_st >= 1 and not GameState.has_cat_sharikov:
		sci_st = 0
		GameState.rescue_chains["scientist"] = 0

	var candidates: Array = []

	# Military Chain candidate
	if mil_st < 3:
		var mil_id: String = "rescue_military_%d" % (mil_st + 1)
		var mil_w: float = 3.0
		if mil_st == 2:
			mil_w = 12.0
		elif mil_st == 1:
			var has_sig: bool = GameState.has_working_item("map") or GameState.has_working_item("flashlight") or GameState.has_working_item("axe")
			mil_w = 7.5 if has_sig else 4.5
		else:
			mil_w = 6.5 if GameState.has_working_item("radio") else 2.5
		if _recent_event_ids.has(mil_id) and day > 8:
			mil_w *= 0.45
		candidates.append({"id": mil_id, "weight": mil_w})

	# Real-World OSM Sanctuary Chain candidate (only if a real church or school is mapped nearby)
	if sanc_st < 3 and has_real_poi(["church", "school"]):
		var sanc_id: String = "rescue_sanctuary_%d" % (sanc_st + 1)
		var sanc_w: float = 3.5
		if sanc_st == 2:
			sanc_w = 12.0
		elif sanc_st == 1:
			var has_build: bool = GameState.has_working_item("toolbox") or GameState.has_working_item("axe") or GameState.has_working_item("rifle") or GameState.has_working_item("book")
			sanc_w = 7.5 if has_build else 5.0
		else:
			var can_share: bool = (GameState.water_quarters >= 4) or (GameState.soup_quarters >= 4) or GameState.has_working_item("medkit") or GameState.has_working_item("book")
			sanc_w = 6.5 if can_share else 3.0
		if _recent_event_ids.has(sanc_id) and day > 8:
			sanc_w *= 0.45
		candidates.append({"id": sanc_id, "weight": sanc_w})

	# Vault Scientist & Sharikov the Cat Chain candidate
	if sci_st < 3:
		var sci_id: String = "rescue_scientist_%d" % (sci_st + 1)
		var sci_w: float = 3.5
		if sci_st == 2:
			sci_w = 12.0
		elif sci_st == 1:
			sci_w = 7.0
		else:
			sci_w = 5.0 if not GameState.has_cat_sharikov else 6.5
		if _recent_event_ids.has(sci_id) and day > 8:
			sci_w *= 0.45
		candidates.append({"id": sci_id, "weight": sci_w})

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


static func _get_event_weight(event_id: String, day: int) -> float:
	var dist_km: float = float(GameState.nuke_config.get("distance_km", 10.0))
	var raider_agg: float = float(GameState.nuke_config.get("raider_aggression", 0.5))
	var temp_c: float = float(GameState.bunker_temp_c)

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
			return 2.4 if GameState.surface_radiation_sv > 0.05 else 1.1
		"distant_second_strike":
			return 0.0 if day < 6 or not GameState.extra_strikes.is_empty() else 0.9
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
		"osm_grocery_cart_rattle":
			return 1.65 if has_real_poi(["grocery"]) else 0.0
		"osm_pharmacy_courier":
			return 1.65 if has_real_poi(["pharmacy"]) else 0.0
		"osm_neighbor_bunker_tap":
			return 1.65 if has_real_poi(["neighbor_house"]) else 0.0
		"osm_hardware_looters":
			return 1.65 if has_real_poi(["hardware", "auto"]) else 0.0
		"osm_restaurant_aroma":
			return 1.65 if has_real_poi(["restaurant"]) else 0.0
		"osm_school_civil_defense_cache":
			return 1.65 if has_real_poi(["school"]) else 0.0
		"osm_park_mutant_geese":
			return 1.65 if has_real_poi(["park"]) else 0.0
		"osm_civic_siren_malfunction":
			return 1.65 if has_real_poi(["civic"]) else 0.0
		"osm_street_delivery_van", "osm_firefighter_check":
			return 1.65
		_:
			return 1.25


# ==============================================================================
# EVENT BUILDER (60 DISTINCT EVENTS)
# ==============================================================================

static func build_event_by_id(event_id: String, day: int, rng: RandomNumberGenerator) -> Dictionary:
	var active_rng: RandomNumberGenerator = rng if rng != null else GameState.rng
	var house_addr: String = _get_house_address()
	var hood: String = _get_neighborhood_label()
	var nuke_target: String = str(GameState.nuke_config.get("target_name", "Strategic Ground Zero"))
	var yield_kt: int = int(GameState.nuke_config.get("yield_kt", 800))
	var dist_km: float = float(GameState.nuke_config.get("distance_km", 8.5))
	# The household's actor (leader if capable, else oldest eligible) is the default protagonist.
	var actor: Dictionary = pick_actor()
	var rand_member: Dictionary = actor
	var m_name: String = str(rand_member.get("name", "Someone"))
	var m_id: String = str(rand_member.get("id", ""))

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
			"member_name": m_name,
			"actor_id": m_id,
			"actor_name": m_name
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

		"distant_second_strike":
			var upwind: float = fposmod(LocationText.downwind_bearing() + 180.0, 360.0)
			var d_km: float = 30.0 + float(active_rng.randi_range(0, 30))
			var pt: Dictionary = NukePhysics.destination_point(float(GameState.selected_house.get("lat", 0.0)), float(GameState.selected_house.get("lon", 0.0)), upwind, d_km)
			ev["context"]["strike_lat"] = float(pt["lat"])
			ev["context"]["strike_lon"] = float(pt["lon"])
			ev["context"]["strike_km"] = d_km
			ev["title"] = "A Second Flash to the %s" % LocationText.compass_word(upwind).capitalize()
			ev["category"] = "nuke_zone"
			ev["type"] = "item_choice"
			ev["description"] = "The periscope lights up white: another detonation, roughly %d km to the %s. The %s will carry fresh fallout over %s within hours — the readings that were finally dropping will climb again." % [int(d_km), LocationText.compass_word(upwind), LocationText.wind_name(), hood]
			ev["options"] = [
				_opt("seal_vents", "Seal the vents with wet sheets (2/4 water)", "water", GameState.water_quarters >= 2),
				_opt("use_gas_mask", "Strap the gas mask filter over the air intake", "gas_mask", GameState.has_working_item("gas_mask")),
				_opt("ignore", "Leave the vents open — the air is already stale", "", true)
			]

		"nuke_downwind_acid_rain":
			ev["title"] = "Downwind Black Fallout Rainstorm!"
			ev["category"] = "nuke_zone"
			ev["type"] = "item_choice"
			ev["description"] = "Oily black rain hisses across the street above %s (outdoor reading: %s). Rain scrubs fallout out of the sky and dumps it on the ground — the block will read hotter for days, and runoff is seeping toward the sump drain." % [house_addr, RadiationModel.format_rate(GameState.surface_radiation_sv * 1000.0)]
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
			var groc_name: String = _find_poi_name(["grocery", "supermarket", "market", "bakery", "qfc", "store"], "")
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
			var pharm_name: String = _find_poi_name(["pharmacy", "clinic", "hospital", "drug", "apothecary", "medical"], "")
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
			var neigh_name: String = _find_poi_name(["neighbor", "house", "residence", "residential", "apartments"], "")
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
			var hw_name: String = _find_poi_name(["hardware", "tool", "supply", "fuel", "76", "auto"], "")
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
			var rest_name: String = _find_poi_name(["restaurant", "cafe", "pub", "bar", "pho", "grill", "diner"], "")
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
			var sch_name: String = _find_poi_name(["school", "library", "college", "academy", "civic"], "")
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
			var park_name: String = _find_poi_name(["park", "garden", "green", "square", "common"], "")
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
			var civ_name: String = _find_poi_name(["civic", "station", "transit", "stop", "fire", "post"], "")
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
			ev["description"] = "As dust swirls clear outside %s, the periscope reveals a spring-water delivery step-van wedged against a lamppost thirty feet from your hatch, rear doors swinging open!" % house_addr
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
	var m_name: String = str(target_member.get("name", "Someone"))
	var actor_now: Dictionary = pick_actor()

	var outcome_text: String = "Another tense day logged in the Civil Defense notebook."
	var morale_delta: int = 0
	var tags: Array = []

	match ev_id:
		# ----------------------------------------------------------------------
		# 1. DAY 1 OPENING
		# ----------------------------------------------------------------------
		"day1_civil_defense_seal":
			match chosen:
				"use_radio":
					outcome_text = "CONELRAD 640 AM came through loud and clear: stay below ground, fallout drifts toward the %s on a %s, and the worst of it fades within days." % [LocationText.compass_word(LocationText.downwind_bearing()), LocationText.wind_name()]
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
				_:
					outcome_text = "Unsure whose helicopter it was, we stayed tucked out of sight while rotor blades faded into the haze."
					morale_delta = 0
					tags = ["neutral"]

		"rescue_military_3":
			if chosen == "yes":
				GameState.rescue_chains["military"] = 3
				GameState.victory = true
				GameState.game_over = true
				GameState.ending_title = "VICTORY: U.S. Civil Defense Evacuation!"
				GameState.ending_description = "On Day %d, your family unbolted the blast hatch beneath %s and stepped into the warm floodlights of U.S. Civil Defense Convoy Charlie! Escorted safely out of %s aboard an armored fallout transport, everyone received hot rations, clean beds, and a brand-new start." % [GameState.day, house_addr, hood]
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
				GameState.ending_title = "VICTORY: Rebuilt Neighborhood Sanctuary!"
				GameState.ending_description = "On Day %d, your family walked side-by-side from %s into the fortified gardens of %s! Together with resilient neighbors across %s, you rebuilt clean wells, rooftop greenhouses, and a thriving post-atomic community." % [GameState.day, house_addr, poi_name, hood]
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
						outcome_text = "Sharikov batted the charcoal note into a ball and took a nap on it. We'll try decoding his collar again soon!"
						morale_delta = 1
						tags = ["morale_up"]
				_:
					outcome_text = "We left the humming copper wire coiled neatly by the wall while Sharikov purred like a Geiger counter."
					morale_delta = 0
					tags = ["neutral"]

		"rescue_scientist_3":
			if chosen == "yes":
				GameState.rescue_chains["scientist"] = 3
				GameState.victory = true
				GameState.game_over = true
				GameState.ending_title = "VICTORY: Secret Vault Scientist Extraction!"
				GameState.ending_description = "On Day %d, guided by Sharikov the Cat's telemetry collar, secret Institute researchers whisked your family from %s down into Sub-Vault Omega — complete with subterranean orchards, Jell-O buffets, and unlimited tuna for Sharikov!" % [GameState.day, house_addr]
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
						RadiationModel.add_dose(target_member, 8.0 if iron_vent else 15.0, GameState.day)
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
					outcome_text = "Viking wasteland chic is officially in season beneath %s! Everyone looks fiercely heroic." % house_addr
					morale_delta = 1
					tags = ["morale_up"]
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

		"distant_second_strike":
			var s_lat: float = float(ctx.get("strike_lat", GameState.selected_house.get("lat", 0.0)))
			var s_lon: float = float(ctx.get("strike_lon", GameState.selected_house.get("lon", 0.0)))
			RadiationModel.add_strike(s_lat, s_lon, RadiationModel.h1_home_msv() * 0.3)
			tags.append("hazard_return")
			match chosen:
				"seal_vents":
					_add_water_quarters(-2)
					outcome_text = "%s soaked bedsheets and packed them over the vents. The new fallout dust stays outside; trips topside will be hotter for a while." % m_name
					morale_delta = 0
					tags.append("neutral")
				"use_gas_mask":
					outcome_text = "%s strapped the gas-mask canister over the air intake. Dust stays out, but the outside readings are climbing again." % m_name
					morale_delta = 0
					tags.append("neutral")
				_:
					for pm_v in GameState.get_living_bunker_members():
						RadiationModel.add_dose(pm_v as Dictionary, 25.0, GameState.day)
					outcome_text = "We left the vents open. Fine grey dust settled on everything; the dosimeters gained about 25 mSv each."
					morale_delta = -1
					tags.append("morale_down")

		"nuke_downwind_acid_rain":
			# Rain-out: localized re-contamination around home, decaying over ~5 days.
			RadiationModel.add_hotspot(float(GameState.selected_house.get("lat", 0.0)), float(GameState.selected_house.get("lon", 0.0)), 450.0, 2.4, 5.0, "rain")
			tags.append("hazard_return")
			match chosen:
				"use_book":
					_add_water_quarters(4)
					outcome_text = "Brilliant science! Using the Handbook's charcoal-sand distillation rig turned storm runoff into 1 full bottle of Clean Water (+4/4)!"
					morale_delta = 2
					tags = ["item_gained", "morale_up"]
				"use_toolbox":
					GameState.bunker_structural_integrity = clampf(GameState.bunker_structural_integrity + 6.0, 0.0, 100.0)
					outcome_text = "Sealing the sump check-valve with the Toolbox kept every drop of black fallout rain outside (+6 Integrity)!"
					morale_delta = 1
					tags = ["morale_up"]
				"use_radio":
					outcome_text = "CONELRAD warned that the rain-out made the ground around %s hotter for several days — expeditions should wait or take the gas mask." % hood
					morale_delta = 1
					tags = ["morale_up"]
				_:
					_adjust_member_stat(target_member, "fatigue", 1)
					RadiationModel.add_dose(target_member, 12.0, GameState.day)
					outcome_text = "%s spent three hours bailing contaminated seepage into the floor drain (about 12 mSv)." % m_name
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
						RadiationModel.add_dose(target_member, RadiationModel.outdoor_dose_msv(float(GameState.selected_house.get("lat", 0.0)), float(GameState.selected_house.get("lon", 0.0)), RadiationModel.hours_since_detonation(GameState.day) + 3.0, 0.1, GameState.day), GameState.day)
						GameState.family_changed.emit()
					outcome_text = "%s sprinted out unmasked and scored 1 Soup Can (+4/4) from the %s cart, catching a mild whiff of surface fallout!" % [m_name, poi_name]
					morale_delta = 1
					tags = ["item_gained"]
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
					outcome_text = "Only a spooky synthesized voice reading numbers in reverse ('SEVEN... ZERO... TUNA...') before the line clicked dead!"
					morale_delta = 0
					tags = ["neutral"]
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
					_add_soup_quarters(4)
					outcome_text = "Tugging a tangled shroud cord spilled one packet down the hatch (+4/4 Soup) before wind carried the chute away!"
					morale_delta = 1
					tags = ["item_gained", "morale_up"]
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

		_:
			outcome_text = "Another calm entry penciled into the Civil Defense logbook beneath %s." % house_addr
			morale_delta = 0
			tags = ["neutral"]

	return {
		"outcome_text": outcome_text,
		"morale_delta": morale_delta,
		"tags": tags,
		"event_id": ev_id,
		"choice_id": chosen,
		"category": str(event_dict.get("category", "")),
		"actor_id": str(actor_now.get("id", "")),
		"actor_name": str(actor_now.get("name", "")),
		"subject_id": str(target_member.get("id", "")),
		"subject_name": m_name,
		"item_used": _choice_item(event_dict, chosen)
	}


static func _choice_item(event_dict: Dictionary, choice_id: String) -> String:
	for o_v in event_dict.get("options", []):
		if o_v is Dictionary and str((o_v as Dictionary).get("id", "")) == choice_id:
			return str((o_v as Dictionary).get("item_id", ""))
	return ""


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


## Natural reference to home ("the house", "our place on East Republican Street") – never the
## full postal address. See LocationText.
static func _get_house_address() -> String:
	return LocationText.home_ref()


static func _get_neighborhood_label() -> String:
	return LocationText.area_name()


## Real church/school name, or "" when none is mapped (sanctuary events are then not drawn).
static func _get_sanctuary_poi_name() -> String:
	if _sanctuary_poi_cache != "":
		return _sanctuary_poi_cache
	_sanctuary_poi_cache = _poi_name_for_categories(["church", "school"])
	return _sanctuary_poi_cache


const _KEYWORD_CATEGORIES: Dictionary = {
	"grocery": ["grocery"], "pharmacy": ["pharmacy"], "neighbor": ["neighbor_house"],
	"hardware": ["hardware", "auto"], "restaurant": ["restaurant"], "school": ["school"],
	"park": ["park"], "civic": ["civic"], "church": ["church", "school"],
}


## Name of the nearest REAL mapped place for the first keyword's category. Never invents a
## fallback: returns "" when the neighbourhood has no such place (callers gate on this).
static func _find_poi_name(keywords: Array, _unused_fallback: String) -> String:
	var key: String = str(keywords[0]).to_lower() if not keywords.is_empty() else ""
	var cats: Array = _KEYWORD_CATEGORIES.get(key, [key])
	return _poi_name_for_categories(cats)


static func _poi_name_for_categories(cats: Array) -> String:
	var best: Dictionary = {}
	for p_v in GameState.nearby_pois:
		if not (p_v is Dictionary):
			continue
		var p: Dictionary = p_v
		if not cats.has(str(p.get("category", ""))) or bool(p.get("fictional", false)):
			continue
		var named: bool = bool(p.get("named", p.get("has_explicit_name", false))) or str(p.get("category", "")) == "neighbor_house"
		if best.is_empty():
			best = p
			continue
		var best_named: bool = bool(best.get("named", best.get("has_explicit_name", false))) or str(best.get("category", "")) == "neighbor_house"
		if named and not best_named:
			best = p
		elif named == best_named and int(p.get("walk_m", p.get("distance_m", 9999))) < int(best.get("walk_m", best.get("distance_m", 9999))):
			best = p
	if best.is_empty():
		return ""
	return LocationText.poi_label(best)


static func has_real_poi(cats: Array) -> bool:
	return _poi_name_for_categories(cats) != ""


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
	var present: Array = GameState.get_living_bunker_members()
	if present.is_empty():
		return pick_actor()
	var idx: int = rng.randi_range(0, present.size() - 1)
	var picked: Dictionary = present[idx]
	return picked


## Can this survivor act for the household right now?
static func is_capable(m: Dictionary) -> bool:
	if m.is_empty() or not bool(m.get("alive", false)) or not bool(m.get("in_bunker", false)) or bool(m.get("on_expedition", false)):
		return false
	if int(m.get("age", 30)) < 13:
		return false
	if int(m.get("injury", 0)) >= 3 or int(m.get("sickness", 0)) >= 3 or int(m.get("sanity", 0)) >= 3:
		return false
	if RadiationModel.ars_stage(float(m.get("dose_recent_msv", 0.0))) >= 4:
		return false
	return true


## Who acts: the leader when present and capable, otherwise the oldest eligible survivor.
## Never an absent (expedition) or dead character. Falls back to the oldest present survivor
## if nobody is fully capable; returns {} only when the shelter is empty.
static func pick_actor() -> Dictionary:
	var present: Array = GameState.get_living_bunker_members()
	for m_v in present:
		var m: Dictionary = m_v
		if bool(m.get("is_leader", false)) and is_capable(m):
			return m
	var best: Dictionary = {}
	for m_v2 in present:
		var m2: Dictionary = m_v2
		if is_capable(m2) and (best.is_empty() or int(m2.get("age", 0)) > int(best.get("age", 0))):
			best = m2
	if not best.is_empty():
		return best
	for m_v3 in present:
		var m3: Dictionary = m_v3
		if best.is_empty() or int(m3.get("age", 0)) > int(best.get("age", 0)):
			best = m3
	return best


static func _find_member_by_id_or_random(member_id: String, _rng: RandomNumberGenerator) -> Dictionary:
	# Only someone actually present and alive can be named in the outcome; otherwise the actor.
	var present: Array = GameState.get_living_bunker_members()
	if member_id != "":
		for m_v in present:
			var m: Dictionary = m_v
			if str(m.get("id", "")) == member_id:
				return m
	return pick_actor()


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


static func _heal_one_afflicted_member() -> void:
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if int(m.get("sickness", 0)) > 0 or int(m.get("injury", 0)) > 0:
			m["sickness"] = 0
			m["injury"] = 0
			m["status_note"] = "Treated by neighborhood pharmacist."
			GameState.family_changed.emit()
			return


static func _heal_all_family_afflictions() -> int:
	var count: int = 0
	for m_v in _get_present_members():
		var m: Dictionary = m_v
		if int(m.get("sickness", 0)) > 0 or int(m.get("injury", 0)) > 0:
			m["sickness"] = 0
			m["injury"] = 0
			# Medical care treats symptoms; it cannot undo absorbed radiation dose.
			m["status_note"] = "Patched up by Dr. Stanislaus!"
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
	member["dose_history"] = []
	member["dose_recent_msv"] = 0.0
	member["status_note"] = "Mutated! Lime-green glow, immune to fallout & pests!"
	GameState.family_changed.emit()
	return "ATOMIC TRANSFORMATION! Instead of getting sick, %s absorbed the glowing green isotope, healed every scratch, sprouted lime-green skin, and mutated into our bunker's fearless radioactive guardian!" % m_name
