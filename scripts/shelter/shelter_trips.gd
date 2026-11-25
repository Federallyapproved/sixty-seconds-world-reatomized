class_name ShelterTrips
extends RefCounted

## Expeditions to real places (section 6): trip length from the walking distance, the chance of
## never returning, sickness in heavy fallout, finite stock, being followed, breakage, and the
## risk preview shown before the player commits.

const GEAR_IDS: Array[String] = ["gas_mask", "map", "rifle", "axe", "flashlight", "medkit", "suitcase"]
const MAX_GEAR: int = 3
const SHUTTER_CATEGORIES: Array[String] = ["pharmacy", "hardware"]
const ESSENTIAL: Array[String] = ["grocery", "pharmacy"]


## Builds a place record from an expedition target (GameState.nearby_pois entry or a fixture).
static func make_place(poi: Dictionary, idx: int, rad_factor: float, stock_mult: float) -> Dictionary:
	var cat: String = _category(poi)
	var walk_m: float = float(poi.get("walk_m", poi.get("distance_m", 300.0)))
	var p: Dictionary = {
		"idx": idx, "name": str(poi.get("name", "")), "category": cat, "subkind": str(poi.get("subkind", "")),
		"walk_m": walk_m, "walk_source": str(poi.get("walk_source", "")), "lat": float(poi.get("lat", 0.0)),
		"lon": float(poi.get("lon", 0.0)), "osm_id": int(poi.get("osm_id", 0)), "fictional": bool(poi.get("fictional", false)),
		"area_sqm": float(poi.get("area_sqm", 0.0)), "rad_factor": rad_factor, "visits": 0, "last_visit_day": 0,
		"last_seen_total": -1, "quiet": false, "occupied": false, "rumour": "",
		"street": str(poi.get("street", "")), "bearing": str(poi.get("bearing_dir", poi.get("bearing", ""))),
	}
	p["stock"] = generate_stock(p, stock_mult)
	p["initial_total"] = stock_total(p)
	p["last_seen_total"] = -1
	return p


static func _category(poi: Dictionary) -> String:
	var c: String = str(poi.get("category", "neighbor_house"))
	if c in ["house", "neighbor", "residential", ""]:
		return "neighbor_house"
	return c


## Deterministic per building (from its OSM id), sized by footprint area for stores.
static func generate_stock(p: Dictionary, stock_mult: float) -> Dictionary:
	var r := RandomNumberGenerator.new()
	var key: String = str(p["osm_id"]) if int(p["osm_id"]) != 0 else "%s@%.5f,%.5f" % [str(p["name"]), float(p["lat"]), float(p["lon"])]
	r.seed = hash(key) ^ 0x5EED
	var cat: String = str(p["category"])
	var table: Dictionary = ShelterData.loot_for(cat)
	var size_mult: float = 1.0
	var area: float = float(p.get("area_sqm", 0.0))
	if area > 0.0:
		size_mult = clampf(sqrt(area / 250.0), 0.5, 2.2)
	var sub: String = str(p.get("subkind", ""))
	if cat == "grocery":
		if sub == "supermarket":
			size_mult *= 1.5
		elif sub in ["convenience", "deli", "bakery", "butcher", "pastry"]:
			size_mult *= 0.6
	var items: Dictionary = {}
	var keys: Array = table.keys()
	keys.sort()
	for iid_v in keys:
		var iid: String = str(iid_v)
		var row: Dictionary = table[iid]
		if r.randf() > float(row.get("chance", 1.0)):
			continue
		var n: int = r.randi_range(int(row.get("min", 0)), int(row.get("max", 0)))
		if bool(row.get("size_scaled", false)):
			n = int(round(float(n) * size_mult))
		n = int(round(float(n) * stock_mult))
		if n > 0:
			items[iid] = n
	return items


static func stock_total(p: Dictionary) -> int:
	var t: int = 0
	for v in (p["stock"] as Dictionary).values():
		t += int(v)
	return t


# ---------------------------------------------------------------- rules

static func round_trip_km(p: Dictionary) -> float:
	return 2.0 * float(p["walk_m"]) / 1000.0


static func base_days(p: Dictionary) -> int:
	var d: float = round_trip_km(p)
	var days: int = 1 + int(ceil(d / ShelterData.B("trip_km_per_day", 6.0)))
	return clampi(days, ShelterData.Bi("trip_days_min", 2), ShelterData.Bi("trip_days_max", 7))


static func trip_days(p: Dictionary, gear: Array) -> int:
	var days: int = base_days(p)
	if gear.has("map"):
		days -= 1
	return maxi(1, days)


static func heavy_fallout(s: ShelterState, day_n: int = -1) -> bool:
	var d: int = s.day if day_n < 0 else day_n
	# A radiation storm (rain-out) makes it heavy again for a couple of days.
	if s.flags.has("storm") and d - int(s.flags["storm"]) <= ShelterData.Bi("storm_days", 2):
		return true
	return d < s.fallout_clear_day


static func raiders_active(s: ShelterState) -> bool:
	return s.followed or s.day >= ShelterData.Bi("escalation_day", 8)


## Expected trip dose (mSv) from the fallout model, for the dose band. Leaves tonight.
static func dose_estimate(s: ShelterState, p: Dictionary, days: int, masked: bool) -> float:
	var total: float = 0.0
	for d in range(days):
		var day_n: int = s.day + 1 + d
		var start_h: float = 1.0 + float(day_n - 1) * 24.0 + 4.0
		var outside: float = _decay(start_h, start_h + 5.0)
		var inside: float = _decay(start_h + 5.0, start_h + 24.0) / 4.0
		total += (outside + inside) * s.h1_home_msv * float(p.get("rad_factor", 1.0))
	return total * (0.85 if masked else 1.0)


static func _decay(t1: float, t2: float) -> float:
	var a: float = maxf(1.0, t1)
	var b: float = maxf(a, t2)
	return 5.0 * (pow(a, -0.2) - pow(b, -0.2))


static func dose_band(dose_msv: float) -> String:
	if dose_msv >= ShelterData.B("dose_band_lethal_msv", 1000.0):
		return "Lethal"
	if dose_msv >= ShelterData.B("dose_band_high_msv", 100.0):
		return "High"
	return "Low"


## Daily chance of never returning, with every multiplier that applies (and why).
static func daily_risk(s: ShelterState, m: Dictionary, p: Dictionary, gear: Array, dose_b: String) -> Dictionary:
	var pd: float = ShelterData.B("trip_base_p_day", 0.025)
	var why: Array[String] = []
	if heavy_fallout(s) and not gear.has("gas_mask"):
		pd *= ShelterData.B("trip_mult_no_mask_heavy", 2.0)
		why.append("no mask in heavy fallout ×2")
	if dose_b == "Lethal":
		pd *= ShelterData.B("trip_mult_lethal_dose", 1.5)
		why.append("lethal dose ×1.5")
	if hungry_or_thirsty(m):
		pd *= ShelterData.B("trip_mult_hungry", 1.5)
		why.append("hungry or thirsty ×1.5")
	if bool(m.get("sick", false)):
		pd *= ShelterData.B("trip_mult_sick", 2.0)
		why.append("sick ×2")
	if bool(m.get("injured", false)):
		pd *= ShelterData.B("trip_mult_injured", 1.5)
		why.append("injured ×1.5")
	if gear.has("map"):
		pd *= ShelterData.B("trip_mult_map", 0.6)
		why.append("map ×0.6")
	if raiders_active(s) and (gear.has("rifle") or gear.has("axe")):
		pd *= ShelterData.B("trip_mult_armed_raiders", 0.7)
		why.append("armed while raiders are about ×0.7")
	return {"p_day": pd, "why": why}


static func hungry_or_thirsty(m: Dictionary) -> bool:
	return int(m.get("dwf", 0)) >= ShelterData.Bi("food_hungry_day", 6) or int(m.get("dww", 0)) >= ShelterData.Bi("water_thirsty_day", 3)


static func risk_band(p_death: float) -> String:
	if p_death < 0.08:
		return "Low"
	if p_death < 0.15:
		return "Moderate"
	if p_death < 0.25:
		return "High"
	return "Severe"


## Who may go out today, and if not, why (shown on the assignment row).
static func can_go(s: ShelterState, m: Dictionary) -> String:
	if not bool(m.get("alive", false)) or str(m.get("loc", "")) != "shelter":
		return "not in the shelter"
	if ShelterState.is_child(m):
		return "too young to go out"
	if int(m.get("tired_until", 0)) > s.day:
		return "Tired until day %d" % int(m.get("tired_until", 0))
	if int(m.get("refuse_until", 0)) > s.day:
		return "refuses to go today"
	if int(m.get("dww", 0)) >= ShelterData.Bi("water_dehydrated_day", 4):
		return "too dehydrated to walk"
	if int(m.get("dwf", 0)) >= ShelterData.Bi("food_starving_day", 8):
		return "too weak from hunger"
	if int(m.get("morale", 5)) <= ShelterData.Bi("morale_withdrawn_at", 0):
		return "Withdrawn: won't leave their corner"
	return ""


## The same reason in two or three words, for the job button.
static func can_go_short(s: ShelterState, m: Dictionary) -> String:
	var why: String = can_go(s, m)
	if why == "":
		return ""
	if why.begins_with("too young"):
		return "Too young"
	if why.begins_with("Tired"):
		return "Tired"
	if why.begins_with("refuses"):
		return "Refuses"
	if why.find("dehydrated") != -1:
		return "Too dehydrated"
	if why.find("hunger") != -1:
		return "Too weak"
	if why.begins_with("Withdrawn"):
		return "Withdrawn"
	return "Can't go"


## The risk preview shown when a real place is clicked (This War of Mine style).
static func preview(s: ShelterState, m: Dictionary, place_idx: int, gear: Array) -> Dictionary:
	var p: Dictionary = s.places[place_idx]
	var days: int = trip_days(p, gear)
	var masked: bool = gear.has("gas_mask")
	var dose: float = dose_estimate(s, p, days, masked)
	var db: String = dose_band(dose)
	var r: Dictionary = daily_risk(s, m, p, gear, db)
	var p_death: float = 1.0 - pow(1.0 - float(r["p_day"]), float(days))
	var sick_p: float = 0.0
	if db == "Lethal":
		sick_p = ShelterData.B("trip_sick_lethal_mask", 0.6) if masked else 1.0
	elif heavy_fallout(s):
		sick_p = ShelterData.B("trip_sick_heavy_mask", 0.2) if masked else ShelterData.B("trip_sick_heavy_nomask", 0.7)
	var carry: int = carry_for(m, gear)
	var left: int = stock_total(p)
	var stocked: String = "Never visited"
	if int(p["visits"]) > 0:
		var ago: int = s.day - int(p["last_visit_day"])
		stocked = "Visited %d day%s ago: %s" % [ago, "" if ago == 1 else "s", "empty" if int(p["last_seen_total"]) == 0 else "%d things left" % int(p["last_seen_total"])]
	var tool: String = ""
	if str(p["category"]) in SHUTTER_CATEGORIES:
		tool = "Axe (steel shutter)" if not gear.has("axe") else "Axe packed (opens the shutter)"
	var followed_p: float = followed_chance(s, gear)
	return {
		"place": p, "days": days, "days_no_map": base_days(p), "round_trip_km": round_trip_km(p),
		"walk_min": int(round(float(p["walk_m"]) / 80.0)), "p_death": p_death, "risk_band": risk_band(p_death),
		"risk_why": r["why"], "dose_msv": dose, "dose_band": db, "sick_p": sick_p, "carry": carry,
		"loot_hint": loot_hint(p), "stocked": stocked, "rumour": str(p.get("rumour", "")), "tool": tool,
		"followed_p": followed_p, "tired": days >= ShelterData.Bi("trip_tired_min_days", 3),
		"overdue_p": ShelterData.B("trip_overdue_p", 0.25), "fallout_known": s.fallout_announced,
		"remaining_hint": left,
	}


static func loot_hint(p: Dictionary) -> Array:
	var table: Dictionary = ShelterData.loot_for(str(p["category"]))
	var ids: Array = table.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((table[a] as Dictionary)["max"]) > int((table[b] as Dictionary)["max"]))
	return ids.slice(0, 4)


## Carry for this explorer: the bag plus a Knows the Area explorer's extra pocket.
static func carry_for(m: Dictionary, gear: Array) -> int:
	return carry_slots(gear) + (ShelterData.Bi("scout_extra_carry", 1) if str(m.get("trait", "")) == "scout" else 0)


static func carry_slots(gear: Array) -> int:
	var c: int = ShelterData.Bi("carry_base", 2)
	if gear.has("suitcase"):
		c += int(ShelterData.item_effect("suitcase", "carry", 3.0))
	return c


static func followed_chance(s: ShelterState, gear: Array) -> float:
	var f: float = ShelterData.B("trip_followed_p", 0.2) + s.loud_bonus
	if gear.has("map"):
		f *= ShelterData.B("trip_followed_map_mult", 0.5)
	return clampf(f, 0.0, 0.9)


# ---------------------------------------------------------------- launch and resolve

## Sends a survivor out tonight. Gear leaves the shelf with them. Returns "" or a refusal reason.
static func launch(s: ShelterState, m: Dictionary, place_idx: int, gear_in: Array) -> String:
	var why: String = can_go(s, m)
	if why != "":
		return why
	if place_idx < 0 or place_idx >= s.places.size():
		return "no such place"
	var gear: Array = []
	for g_v in gear_in:
		var g: String = str(g_v)
		if g in GEAR_IDS and not gear.has(g) and s.has(g) and gear.size() < MAX_GEAR:
			gear.append(g)
	var pv: Dictionary = preview(s, m, place_idx, gear)
	for g in gear:
		s.remove(str(g), 1)
	var p: Dictionary = s.places[place_idx]
	var days: int = int(pv["days"])
	var overdue: int = 0
	if s.rng.randf() < ShelterData.B("trip_overdue_p", 0.25):
		overdue = s.rng.randi_range(1, 2)
	m["loc"] = "away"
	m["on_expedition"] = true
	var t: Dictionary = {
		"member": str(m["id"]), "place_idx": place_idx, "gear": gear, "days": days, "overdue": overdue,
		"left_day": s.day, "due_day": s.day + days, "return_day": s.day + days + overdue, "p_day": float(pv["p_day"]) if pv.has("p_day") else 0.0,
		"dead": false, "death_day": 0, "dose_band": str(pv["dose_band"]), "dose": float(pv["dose_msv"]),
		"heavy": heavy_fallout(s), "extra_loot": {}, "injured": false, "events": [],
	}
	t["p_day"] = float(daily_risk(s, m, p, gear, str(pv["dose_band"]))["p_day"])
	# Hazards in the shelter's own decisions are recorded for the balance harness.
	if heavy_fallout(s) and not gear.has("gas_mask") and s.has("gas_mask"):
		s.mistake("mask_left_home", "%s went out in heavy fallout and the mask stayed home" % str(m["name"]))
	if bool(m.get("sick", false)) or bool(m.get("injured", false)):
		s.mistake("sent_unwell", "%s was sent out unwell" % str(m["name"]))
	if str(pv["dose_band"]) == "Lethal":
		s.mistake("lethal_trip", "%s was sent into a lethal dose" % str(m["name"]))
	s.trips.append(t)
	s.stats["trips"] = int(s.stats["trips"]) + 1
	var tb: Dictionary = s.stats["trips_by_member"]
	tb[str(m["id"])] = int(tb.get(str(m["id"]), 0)) + 1
	ShelterState.note_cause(m, s.day, "sent %.1f km to %s" % [float(p["walk_m"]) / 1000.0, place_label(p)], "decision")
	var gear_txt: String = "nothing but a coat" if gear.is_empty() else ", ".join(gear.map(func(g: Variant) -> String: return ShelterData.item_name(str(g)).to_lower()))
	s.say("trip", "%s left for %s with %s. Expected back on day %d." % [str(m["name"]), place_label(p), gear_txt, s.day + days], gear, str(m["id"]))
	return ""


## Real names only as neutral facts; neighbours' homes never by address (section 7).
static func place_label(p: Dictionary) -> String:
	if str(p.get("category", "")) == "neighbor_house":
		var st: String = str(p.get("street", "")).strip_edges()
		var where: String = (" on " + st) if st != "" else ""
		return "a neighbour's house%s (%d m %s)" % [where, int(round(float(p.get("walk_m", 0.0)))), str(p.get("bearing", ""))] if str(p.get("bearing", "")) != "" else "a neighbour's house%s" % where
	var nm: String = str(p.get("name", "")).strip_edges()
	if nm != "" and not nm.begins_with("Unnamed"):
		return nm
	return "the " + category_word(str(p["category"]))


static func category_word(cat: String) -> String:
	match cat:
		"grocery": return "grocery store"
		"pharmacy": return "pharmacy"
		"hardware": return "hardware store"
		"auto": return "gas station"
		"church": return "church"
		"school": return "school"
		"civic": return "station house"
		"restaurant": return "restaurant"
		"park": return "park"
		"neighbor_house": return "neighbour's house"
	return "building"


## Advances every trip by one night. Returns the members who came home this morning.
static func tick(s: ShelterState) -> Array:
	var back: Array = []
	var still: Array = []
	for t_v in s.trips:
		var t: Dictionary = t_v
		var m: Dictionary = s.member(str(t["member"]))
		# One roll for every night away, starting the night they leave (matches the preview's
		# 1 - (1 - p)^days; late trips keep rolling until they're home).
		if not bool(t["dead"]) and s.day >= int(t["left_day"]):
			if s.rng.randf() < float(t["p_day"]):
				t["dead"] = true
				t["death_day"] = s.day
		var day_n: int = s.day + 1   # the morning about to start
		if bool(t["dead"]):
			# The family only learns when the trip is long overdue.
			if day_n == int(t["due_day"]) + 1:
				s.say("warn", "%s is overdue." % str(m.get("name", "Someone")), [], str(t["member"]))
				still.append(t)
			elif day_n >= int(t["due_day"]) + 3:
				_lost(s, t, m)
			else:
				still.append(t)
			continue
		if day_n == int(t["due_day"]) and int(t["overdue"]) > 0:
			s.say("warn", "%s is overdue." % str(m.get("name", "Someone")), [], str(t["member"]))
		if day_n >= int(t["return_day"]):
			_return(s, t, m)
			back.append(m)
		else:
			still.append(t)
	s.trips = still
	return back


static func _lost(s: ShelterState, t: Dictionary, m: Dictionary) -> void:
	var p: Dictionary = s.places[int(t["place_idx"])]
	m["alive"] = false
	m["loc"] = "dead"
	m["on_expedition"] = false
	m["death_day"] = s.day + 1
	m["death_reason"] = "Never came back from %s." % place_label(p)
	ShelterState.note_cause(m, s.day + 1, "didn't return", "decision")
	s.stats["trip_deaths"] = int(s.stats["trip_deaths"]) + 1
	ShelterSim.record_death(s, m, "trip", "decision")
	s.say("death", "%s didn't come back from %s." % [str(m.get("name", "")), place_label(p)], t["gear"], str(m.get("id", "")))
	for g in t["gear"]:
		s.say("break", "The %s went with them." % ShelterData.item_name(str(g)).to_lower(), [str(g)])


static func _return(s: ShelterState, t: Dictionary, m: Dictionary) -> void:
	var p: Dictionary = s.places[int(t["place_idx"])]
	var gear: Array = t["gear"]
	var name: String = str(m.get("name", ""))
	m["loc"] = "shelter"
	m["on_expedition"] = false
	s.flags.erase("locked_empty")
	var label: String = place_label(p)
	# Explorers live off what they find, but come home hungry and thirsty.
	m["dww"] = maxi(int(m.get("dww", 0)), 2)
	m["dwf"] = maxi(int(m.get("dwf", 0)), 3)
	var days_out: int = int(t["return_day"]) - int(t["left_day"])
	var lines_gear: Array[String] = []
	# Radiation
	var dose: float = float(t["dose"]) * s.rng.randf_range(0.8, 1.2)
	ShelterSim.add_dose(m, s.day, dose)
	if gear.has("gas_mask"):
		lines_gear.append("Gas mask: blocked ~%d mSv" % int(round(dose / 0.85 * 0.15)))
	var sick_p: float = 0.0
	if str(t["dose_band"]) == "Lethal":
		sick_p = ShelterData.B("trip_sick_lethal_mask", 0.6) if gear.has("gas_mask") else 1.0
	elif bool(t["heavy"]):
		sick_p = ShelterData.B("trip_sick_heavy_mask", 0.2) if gear.has("gas_mask") else ShelterData.B("trip_sick_heavy_nomask", 0.7)
	if sick_p > 0.0 and s.rng.randf() < sick_p:
		ShelterSim.make_sick(s, m, "fallout dust on the trip to %s" % label, "decision")
		if not gear.has("gas_mask"):
			s.missed("gas_mask", "%s got sick" % name)
	elif sick_p > 0.0 and gear.has("gas_mask"):
		s.credit("gas_mask", "%s came back clean" % name)
	# Raiders on the road
	var armed: bool = gear.has("rifle") or gear.has("axe")
	var injury_p: float = ShelterData.B("trip_injury_p", 0.2)
	if raiders_active(s) and s.rng.randf() < ShelterData.B("trip_encounter_p", 0.3):
		if armed:
			var w: String = "rifle" if gear.has("rifle") else "axe"
			lines_gear.append("%s: looters backed off" % ShelterData.item_name(w))
			s.credit(w, "looters backed off on the road")
			injury_p *= ShelterData.B("trip_injury_armed_mult", 0.6)
		else:
			injury_p += ShelterData.B("trip_encounter_unarmed_injury", 0.25)
			if s.has("rifle") or s.has("axe"):
				s.missed("rifle" if s.has("rifle") else "axe", "%s met looters empty-handed" % name)
	if gear.has("map"):
		lines_gear.append("Map: trip %d day shorter" % (base_days(p) - int(t["days"])))
		s.credit("map", "trip to %s 1 day shorter" % label)
	if bool(t["injured"]) or s.rng.randf() < injury_p:
		if gear.has("medkit"):
			s.credit("medkit", "patched %s up on the road" % name)
			gear.erase("medkit")   # used up
		else:
			ShelterSim.make_injured(s, m, "hurt on the trip to %s" % label, "decision")
	# Loot from the building's finite stock
	var carry: int = carry_for(m, gear)
	var share: float = ShelterData.B("search_share", 0.55)
	if str(p["category"]) in SHUTTER_CATEGORIES:
		if gear.has("axe"):
			lines_gear.append("Axe: opened the shutter")
			s.credit("axe", "opened the shutter at %s" % label)
		else:
			share *= ShelterData.B("shutter_share_mult", 0.6)
			s.missed("axe", "the shutter at %s stayed shut" % label)
	if gear.has("flashlight"):
		share += 0.15
	if str(m.get("trait", "")) == "scout":
		share += ShelterData.B("scout_extra_share", 0.1)   # knows the area: finds a little extra
	var haul: Dictionary = raid_stock(s, p, carry, share)
	for k in (t["extra_loot"] as Dictionary).keys():
		haul[k] = int(haul.get(k, 0)) + int(t["extra_loot"][k])
	# Collect revealed caches at this place
	var keep_caches: Array = []
	for c_v in s.caches:
		var c: Dictionary = c_v
		if int(c["place_idx"]) == int(t["place_idx"]):
			for k in (c["items"] as Dictionary).keys():
				haul[k] = int(haul.get(k, 0)) + int(c["items"][k])
			s.say("gain", "%s found the cache marked on the map." % name)
		else:
			keep_caches.append(c)
	s.caches = keep_caches
	if gear.has("suitcase") and _haul_slots(haul) > ShelterData.Bi("carry_base", 2):
		lines_gear.append("Suitcase: carried %d more" % (_haul_slots(haul) - ShelterData.Bi("carry_base", 2)))
		s.credit("suitcase", "carried %d more things home" % (_haul_slots(haul) - ShelterData.Bi("carry_base", 2)))
	var got: Array[String] = []
	for k in haul.keys():
		var n: int = int(haul[k])
		if n <= 0:
			continue
		s.add_units(str(k), n)
		got.append(("%d× %s" % [n, ShelterData.item_name(str(k))]) if n > 1 else ShelterData.item_name(str(k)))
	p["visits"] = int(p["visits"]) + 1
	p["last_visit_day"] = s.day + 1
	p["last_seen_total"] = stock_total(p)
	var pl: Dictionary = s.stats["places_looted"]
	pl[str(p["category"])] = true
	# Gear comes home, unless it broke or was lost
	for g_v in gear:
		var g: String = str(g_v)
		if s.rng.randf() < ShelterData.B("trip_item_break_p", 0.10):
			if str(ShelterData.item(g).get("repair", "none")) != "none" and s.rng.randf() < 0.5:
				s.broken[g] = s.broken_count(g) + 1
				s.say("break", "%s broke on the way back." % ShelterData.item_name(g), [g])
			else:
				s.say("break", "%s was lost on the road." % ShelterData.item_name(g), [g])
		else:
			s.add(g, 1)
	# Followed home?
	if not s.followed and s.rng.randf() < followed_chance(s, gear):
		ShelterSim.become_followed(s, "someone followed %s home from %s" % [name, label])
	s.loud_bonus = 0.0
	if days_out >= ShelterData.Bi("trip_tired_min_days", 3):
		m["tired_until"] = s.day + 1 + ShelterData.Bi("trip_tired_days", 2)
	var haul_txt: String = "nothing" if got.is_empty() else ", ".join(got)
	s.say("return", "%s is back from %s with %s." % [name, label, haul_txt], haul.keys(), str(m["id"]))
	for gl in lines_gear:
		s.say("gear", gl, [], str(m["id"]))
	if stock_total(p) == 0:
		s.say("info", "%s is stripped bare now." % label)


static func _haul_slots(haul: Dictionary) -> int:
	var n: int = 0
	for k in haul.keys():
		n += int(haul[k]) * ShelterData.item_slots(str(k))
	return n


## Takes a share of what is left, most needed first, as much as fits.
static func raid_stock(s: ShelterState, p: Dictionary, carry: int, share: float) -> Dictionary:
	var stock: Dictionary = p["stock"]
	var found: Dictionary = {}
	for k in stock.keys():
		var have: int = int(stock[k])
		var e: float = float(have) * clampf(share, 0.05, 1.0)
		var n: int = int(floor(e))
		if s.rng.randf() < e - float(n):
			n += 1
		n = mini(n, have)
		if n > 0:
			found[k] = n
	var order: Array = found.keys()
	var pri: Array = loot_priorities(s)
	order.sort_custom(func(a: Variant, b: Variant) -> bool:
		var pa: int = pri.find(str(a))
		var pb: int = pri.find(str(b))
		return (999 if pa < 0 else pa) < (999 if pb < 0 else pb))
	var taken: Dictionary = {}
	var left: int = carry
	for k in order:
		var cost: int = ShelterData.item_slots(str(k))
		var can: int = mini(int(found[k]), left / cost)
		if can <= 0:
			continue
		taken[k] = can
		left -= can * cost
		stock[k] = int(stock[k]) - can
		if int(stock[k]) <= 0:
			stock.erase(k)
	return taken


## What the household needs most decides what the explorer carries home first.
static func loot_priorities(s: ShelterState) -> Array:
	var pri: Array = []
	var people: int = maxi(1, s.living().size())
	var w_days: float = float(s.water()) / float(people)
	var f_days: float = float(s.food()) / float(people)
	var anyone_unwell: bool = false
	for m_v in s.living():
		if bool((m_v as Dictionary).get("sick", false)) or bool((m_v as Dictionary).get("injured", false)):
			anyone_unwell = true
	if anyone_unwell and not s.has("medkit"):
		pri.append("medkit")
	# Once the shelter is being watched, something that stops a raid comes first.
	if s.followed and not s.has("padlock") and not s.has("rifle") and not s.has("axe"):
		pri.append_array(["padlock", "axe", "rifle"])
	if w_days <= f_days * 2.0:
		pri.append_array(["water", "food"])
	else:
		pri.append_array(["food", "water"])
	for iid in ["medkit", "gas_mask", "radio", "map", "flashlight", "padlock", "rifle", "ammo", "axe", "manual", "suitcase", "bug_spray", "cards", "console"]:
		if not pri.has(iid) and not s.owns(iid):
			pri.append(iid)
	for iid in ["ammo", "medkit", "padlock", "bug_spray"]:
		if not pri.has(iid):
			pri.append(iid)
	return pri


## Unseen survivors take 5-10% of what is left in every place each day.
static func drain(s: ShelterState) -> void:
	var mult: float = ShelterData.B("hard_drain_mult", 1.5) if s.difficulty == "hard" else 1.0
	for p_v in s.places:
		var p: Dictionary = p_v
		var fast: bool = str(p["category"]) in ESSENTIAL
		var lo: float = ShelterData.B("stock_drain_fast_min" if fast else "stock_drain_min", 0.05)
		var hi: float = ShelterData.B("stock_drain_fast_max" if fast else "stock_drain_max", 0.08)
		var rate: float = s.rng.randf_range(lo, hi) * mult
		var stock: Dictionary = p["stock"]
		for k in stock.keys():
			var have: int = int(stock[k])
			var e: float = float(have) * rate
			var n: int = int(floor(e))
			if s.rng.randf() < e - float(n):
				n += 1
			if n > 0:
				stock[k] = have - n
		for k in stock.keys().duplicate():
			if int(stock[k]) <= 0:
				stock.erase(k)
