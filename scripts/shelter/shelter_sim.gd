class_name ShelterSim
extends RefCounted

## The shelter phase (sections 3 and 6): one screen per day.
##
##   var s := ShelterSim.new_run({...})
##   loop:
##     var morning := ShelterSim.begin_day(s)        # overnight receipt + today's dilemma
##     ShelterSim.choose(s, option_id)               # answer the dilemma (if there is one)
##     ShelterSim.end_day(s, plan)                   # rations, medkits, jobs -> the night
##
## A plan is {"rations": {member_id: {"food": bool, "water": bool}}, "treat": {member_id: true},
##            "jobs": {member_id: {"job": "rest"|"trip", "place": int, "gear": [item_id]}}}.
## The game UI and the balance harness both drive exactly these calls.

const ENDINGS: Dictionary = {
	"rescue_convoy": {"kind": "win", "title": "The Convoy", "text": "The knock was the convoy. They had a list, and your family was on it."},
	"rescue_neighbourhood": {"kind": "win", "title": "The Neighbourhood Shelter", "text": "The people at {place} sent an escort. There is soup there, and a rota for the dishes."},
	"rescue_airlift": {"kind": "win", "title": "The Airlift", "text": "A helicopter took the family out over the roofs. Nobody looked down for long."},
	"loss_all_dead": {"kind": "loss", "title": "The Shelter Went Quiet", "text": "Nobody is left to write in the journal."},
	"loss_empty": {"kind": "loss", "title": "Taken While Empty", "text": "Everyone was out and the hatch was unlocked. Someone else lives here now."},
	"loss_takeover": {"kind": "loss", "title": "The Gang Moved In", "text": "They came for the shelter, not the supplies. There was nothing left to stop them."},
	"loss_no_adult": {"kind": "loss", "title": "Only the Children", "text": "The children are alone. A neighbour heard them through the vent; what happened next is not in the journal."},
}


# ---------------------------------------------------------------- setup

## opts: members (Array of member Dictionaries; in_bunker marks who made it), haul ({item: units}
## from the grab), places (expedition targets), rad_factors (Array of floats, one per place),
## h1_home_msv, difficulty, seed.
static func new_run(opts: Dictionary) -> ShelterState:
	var s := ShelterState.new()
	s.seed_value = int(opts.get("seed", 1))
	s.rng.seed = s.seed_value
	s.difficulty = str(opts.get("difficulty", "normal"))
	s.h1_home_msv = float(opts.get("h1_home_msv", 5000.0))
	s.temp_c = float(opts.get("temp_c", 19.0))
	s.winter = str(opts.get("zone", "")).find("winter") != -1 or s.temp_c <= 5.0
	s.members = opts.get("members", [])
	for m_v in s.members:
		init_member(m_v as Dictionary)
	var haul: Dictionary = opts.get("haul", {})
	for k in haul.keys():
		s.add_units(str(k), int(haul[k]))
	var stock_mult: float = ShelterData.B("story_stock_mult", 1.5) if s.difficulty == "story" else 1.0
	var pois: Array = opts.get("places", [])
	var factors: Array = opts.get("rad_factors", [])
	for i in range(pois.size()):
		var f: float = float(factors[i]) if i < factors.size() else 1.0
		s.places.append(ShelterTrips.make_place(pois[i] as Dictionary, i, f, stock_mult))
	s.fallout_clear_day = compute_fallout_clear_day(s.h1_home_msv, s.rng)
	ShelterChains.init(s)
	for m_v in s.home():
		var m: Dictionary = m_v
		s.last_rations[str(m["id"])] = {"food": false, "water": false}
	var names: Array[String] = []
	for m_v in s.home():
		names.append(str((m_v as Dictionary)["name"]))
	if names.is_empty():
		s.say("death", "Nobody reached the hatch.")
		finish(s, "loss_all_dead")
	else:
		s.say("info", "Day 1. %s sealed the hatch. Food: %d rations. Water: %d rations." % [join_names(names), s.food(), s.water()])
		if not s.has_adult(s.home()):
			finish(s, "loss_no_adult")
	for m_v in s.members:
		sync_visuals(m_v as Dictionary, s.day)
	return s


static func init_member(m: Dictionary) -> void:
	var made_it: bool = bool(m.get("in_bunker", false)) and bool(m.get("alive", true))
	m["alive"] = made_it
	m["loc"] = "shelter" if made_it else "outside"
	if not made_it and str(m.get("death_reason", "")) == "":
		m["death_reason"] = "Didn't reach the hatch in time."
	m["dwf"] = 0
	m["dww"] = 0
	m["sick"] = false
	m["sick_days"] = 0
	m["injured"] = false
	m["injured_days"] = 0
	m["relapse_until"] = 0
	m["tired_until"] = 0
	m["refuse_until"] = 0
	m["morale"] = ShelterData.Bi("morale_start", 7)
	m["morale_cap"] = ShelterData.Bi("morale_max", 10)
	m["guilt"] = false
	m["causes"] = []
	m["dose_hist"] = []
	m["ars_warned"] = false
	# Per-run flags (the family dictionaries are reused from one run to the next).
	for k in ["heat_ticked", "drank_today", "ate_today"]:
		m[k] = false
	m["dose_msv"] = 0.0
	m["on_expedition"] = false
	m["death_day"] = 0


## Fallout counts as heavy until the home dose rate drops below the threshold; the all-clear is
## clamped to days 7-20 (section 6) with a little day-to-day noise.
static func compute_fallout_clear_day(h1: float, rng: RandomNumberGenerator) -> int:
	var thr: float = ShelterData.B("heavy_fallout_msv_h", 10.0)
	var d: int = 1
	while d < 40:
		var hours: float = 1.0 + float(d - 1) * 24.0
		if h1 * pow(hours, -1.2) < thr:
			break
		d += 1
	d += rng.randi_range(-1, 2)
	return clampi(d, ShelterData.Bi("fallout_clear_min_day", 7), ShelterData.Bi("fallout_clear_max_day", 20))


# ---------------------------------------------------------------- the day

static func begin_day(s: ShelterState) -> Dictionary:
	var morning: Array = s.receipt.duplicate()
	s.receipt = []
	s.journal.append({"day": s.day, "lines": morning.duplicate()})
	if s.is_over():
		return {"day": s.day, "morning": morning, "event": {}, "options": [], "over": true}
	_morning_omens(s)
	var omens: Array = s.receipt.duplicate()
	s.receipt = []
	morning.append_array(omens)
	(s.journal.back() as Dictionary)["lines"].append_array(omens)
	s.today_event = ShelterEvents.draw(s)
	s.today_resolved = s.today_event.is_empty()
	s.today_options = ShelterEvents.options_for(s, s.today_event)
	return {"day": s.day, "morning": morning, "event": s.today_event, "options": s.today_options, "over": false}


## Answers today's dilemma. Returns the outcome (text, receipt lines, scenario hint).
static func choose(s: ShelterState, option_id: String) -> Dictionary:
	if s.today_resolved or s.today_event.is_empty():
		return {}
	var out: Dictionary = ShelterEvents.resolve(s, s.today_event, option_id)
	if out.is_empty():
		return out
	s.today_resolved = true
	s.last_outcome = out
	var entry: Dictionary = s.journal.back() if not s.journal.is_empty() else {}
	if not entry.is_empty():
		(entry["lines"] as Array).append({"kind": "event", "text": "%s — %s" % [str(s.today_event.get("title", "")), str(out.get("text", ""))], "items": out.get("items", []), "who": ""})
		(entry["lines"] as Array).append_array(out.get("lines", []))
	_evaluate(s)
	return out


## What the ration row starts from: yesterday's choices.
static func default_plan(s: ShelterState) -> Dictionary:
	var rations: Dictionary = {}
	for m_v in s.home():
		var m: Dictionary = m_v
		var prev: Dictionary = s.last_rations.get(str(m["id"]), {"food": false, "water": false})
		rations[str(m["id"])] = {"food": bool(prev.get("food", false)), "water": bool(prev.get("water", false))}
	return {"rations": rations, "treat": {}, "jobs": {}}


## Tomorrow-preview for one row of the ration screen ("Skip water: Dad is thirsty tomorrow").
static func ration_preview(s: ShelterState, m: Dictionary, give_food: bool, give_water: bool) -> Dictionary:
	var dww: int = 0 if give_water else int(m.get("dww", 0)) + 1
	var dwf: int = 0 if give_food else int(m.get("dwf", 0)) + 1
	var w_txt: String = ""
	if not give_water:
		if dww >= ShelterData.Bi("water_death_day", 6):
			w_txt = "dies of thirst tonight"
		elif dww >= ShelterData.Bi("water_death_roll_day", 5):
			w_txt = "may die of thirst tonight (day %d without)" % dww
		elif dww >= ShelterData.Bi("water_dehydrated_day", 4):
			w_txt = "is dehydrated tomorrow (day %d without)" % dww
		elif dww >= ShelterData.Bi("water_thirsty_day", 3):
			w_txt = "is thirsty tomorrow (day %d without)" % dww
		else:
			w_txt = "is fine (day %d without)" % dww
	var f_txt: String = ""
	if not give_food:
		if dwf >= ShelterData.Bi("food_death_day", 10):
			f_txt = "starves tonight"
		elif dwf >= ShelterData.Bi("food_starving_day", 8):
			f_txt = "is starving tomorrow (day %d without)" % dwf
		elif dwf >= ShelterData.Bi("food_hungry_day", 6):
			f_txt = "is hungry tomorrow (day %d without)" % dwf
		else:
			f_txt = "is fine (day %d without)" % dwf
	return {"water": w_txt, "food": f_txt, "dww": dww, "dwf": dwf}


static func end_day(s: ShelterState, plan: Dictionary) -> Dictionary:
	if s.is_over():
		return {"over": true}
	if not s.today_resolved and not s.today_event.is_empty():
		# The UI never allows this; the harness and tests resolve with the first option.
		var opts: Array = s.today_options
		for o_v in opts:
			if bool((o_v as Dictionary).get("available", false)):
				choose(s, str((o_v as Dictionary)["id"]))
				break
	if s.is_over():
		return {"over": true}
	_apply_treatment(s, plan.get("treat", {}))
	_apply_rations(s, plan.get("rations", {}))
	_apply_jobs(s, plan.get("jobs", {}))
	if s.is_over():
		_close_day(s)
		return {"over": true}
	_health_tick(s)
	_weather_tick(s)
	_morale_tick(s)
	_pets_tick(s)
	_raid_clock(s)
	ShelterTrips.tick(s)
	ShelterTrips.drain(s)
	_close_day(s)
	return {"over": s.is_over()}


static func _close_day(s: ShelterState) -> void:
	s.day += 1
	for t_v in s.trips:
		var t: Dictionary = t_v
		var m: Dictionary = s.member(str(t["member"]))
		m["days_away"] = maxi(0, int(t["due_day"]) - s.day)
	if not s.is_over():
		_fallout_news(s)
		ShelterChains.tick(s)
		_evaluate(s)
	for m_v in s.members:
		sync_visuals(m_v as Dictionary, s.day)


# ---------------------------------------------------------------- plan

static func _apply_treatment(s: ShelterState, treat: Dictionary) -> void:
	for mid in treat.keys():
		if not bool(treat[mid]):
			continue
		var m: Dictionary = s.member(str(mid))
		if m.is_empty() or str(m.get("loc", "")) != "shelter" or not bool(m.get("alive", false)):
			continue
		if not (bool(m.get("sick", false)) or bool(m.get("injured", false))):
			continue
		if not s.has("medkit"):
			continue
		s.remove("medkit", 1)
		var what: String = "cured %s" % str(m["name"])
		if bool(m.get("sick", false)) and bool(m.get("injured", false)):
			what = "cured %s's fever and wounds" % str(m["name"])
		cure(s, m)
		s.credit("medkit", what)


static func _apply_rations(s: ShelterState, rations: Dictionary) -> void:
	for m_v in s.home():
		var m: Dictionary = m_v
		var mid: String = str(m["id"])
		var r: Dictionary = rations.get(mid, {})
		var give_f: bool = bool(r.get("food", false))
		var give_w: bool = bool(r.get("water", false))
		s.last_rations[mid] = {"food": give_f, "water": give_w}
		if give_w and s.remove(ShelterState.WATER, 1) == 1:
			m["dww"] = 0
			m["drank_today"] = true
		else:
			m["drank_today"] = false
			if give_w:
				s.say("missing", "No water left for %s." % str(m["name"]), ["water"], mid)
			elif s.water() > 0 and int(m.get("dww", 0)) + 1 >= ShelterData.Bi("water_dehydrated_day", 4):
				s.mistake("skipped_water", "%s went without water with %d rations on the shelf" % [str(m["name"]), s.water()])
				ShelterState.note_cause(m, s.day, "skipped water (day %d without)" % (int(m.get("dww", 0)) + 1), "decision")
		if give_f and s.remove(ShelterState.FOOD, 1) == 1:
			m["dwf"] = 0
			m["ate_today"] = true
		else:
			m["ate_today"] = false
			if give_f:
				s.say("missing", "No food left for %s." % str(m["name"]), ["food"], mid)
			elif s.food() > 0 and int(m.get("dwf", 0)) + 1 >= ShelterData.Bi("food_starving_day", 8):
				s.mistake("skipped_food", "%s went without food with %d rations on the shelf" % [str(m["name"]), s.food()])
				ShelterState.note_cause(m, s.day, "skipped food (day %d without)" % (int(m.get("dwf", 0)) + 1), "decision")


static func _apply_jobs(s: ShelterState, jobs: Dictionary) -> void:
	var launched: int = 0
	for mid in jobs.keys():
		var j: Dictionary = jobs[mid]
		if str(j.get("job", "rest")) != "trip":
			continue
		var m: Dictionary = s.member(str(mid))
		if m.is_empty():
			continue
		var why: String = ShelterTrips.launch(s, m, int(j.get("place", -1)), j.get("gear", []))
		if why == "":
			launched += 1
	if launched > 0 and s.home().is_empty():
		if s.has("padlock"):
			s.remove("padlock", 1)
			s.flags["locked_empty"] = true
			s.credit("padlock", "locked the hatch behind the last one out")
		else:
			s.mistake("empty_unlocked", "the shelter was left empty without a padlock")
			s.missed("padlock", "the hatch stayed open behind them")
			finish(s, "loss_empty")


# ---------------------------------------------------------------- the night

## Shelter air: blast heat fades toward 19 °C; a nuclear winter keeps falling unless there is
## something to burn or insulate with (an axe for kindling, the manual's chapter on drafts).
static func _weather_tick(s: ShelterState) -> void:
	var before: float = s.temp_c
	if s.winter:
		if s.has("axe") or s.has("manual"):
			s.temp_c = minf(s.temp_c + s.rng.randf_range(0.2, 0.8), 12.0)
		else:
			s.temp_c = maxf(s.temp_c - s.rng.randf_range(0.5, 1.2), -15.0)
		if before >= 0.0 and s.temp_c < 0.0:
			s.say("warn", "The shelter is below freezing (%.0f °C). Hungry people will catch chills." % s.temp_c, ["axe", "manual"])
	elif s.temp_c > 19.5 and s.day >= 2:
		# Blast heat soaks the walls and lingers through day 2 before it starts to fade.
		s.temp_c = maxf(19.0, s.temp_c - s.rng.randf_range(0.6, 1.3))
	if before >= ShelterData.B("heat_thirst_c", 28.0) and s.temp_c < ShelterData.B("heat_thirst_c", 28.0):
		s.say("good", "The blast heat has finally gone out of the walls (%.0f °C)." % s.temp_c)


static func _health_tick(s: ShelterState) -> void:
	var hot: bool = s.temp_c >= ShelterData.B("heat_thirst_c", 28.0)
	var cold: bool = s.temp_c < 0.0
	if hot and not s.flags.has("heat_said"):
		s.flags["heat_said"] = s.day
		s.say("status", "%.0f °C in the shelter from the blast heat: everyone gets thirsty a day sooner." % s.temp_c, ["water"])
	for m_v in s.home():
		var m: Dictionary = m_v
		var name: String = str(m["name"])
		var mid: String = str(m["id"])
		# Water (blast heat brings thirst forward by a day, once per person)
		if not bool(m.get("drank_today", false)):
			var extra: int = 0
			if hot and int(m.get("dww", 0)) >= 1 and not bool(m.get("heat_ticked", false)):
				extra = 1
				m["heat_ticked"] = true
			m["dww"] = int(m.get("dww", 0)) + 1 + extra
		var dww: int = int(m["dww"])
		if dww >= ShelterData.Bi("water_death_day", 6):
			_die(s, m, "thirst", "Died of thirst after %d days without water." % dww)
			continue
		if dww == ShelterData.Bi("water_death_roll_day", 5):
			if s.rng.randf() < ShelterData.B("water_death_roll_p", 0.5):
				_die(s, m, "thirst", "Died of thirst after %d days without water." % dww)
				continue
			s.say("warn", "%s barely made it through the night. Water, today." % name, ["water"], mid)
		elif dww == ShelterData.Bi("water_dehydrated_day", 4):
			s.say("warn", "%s is dehydrated (day %d without water)." % [name, dww], ["water"], mid)
		elif dww == ShelterData.Bi("water_thirsty_day", 3):
			s.say("status", "%s is thirsty (day %d without water)." % [name, dww], ["water"], mid)
		# Food
		if not bool(m.get("ate_today", false)):
			m["dwf"] = int(m.get("dwf", 0)) + 1
		var dwf: int = int(m["dwf"])
		if dwf >= ShelterData.Bi("food_death_day", 10):
			_die(s, m, "starvation", "Starved after %d days without food." % dwf)
			continue
		if dwf == ShelterData.Bi("food_starving_day", 8):
			s.say("warn", "%s is starving (day %d without food)." % [name, dwf], ["food"], mid)
		elif dwf == ShelterData.Bi("food_hungry_day", 6):
			s.say("status", "%s is hungry (day %d without food)." % [name, dwf], ["food"], mid)
		# Sickness
		if bool(m.get("sick", false)):
			m["sick_days"] = int(m.get("sick_days", 0)) + 1
			var sd: int = int(m["sick_days"])
			if sd >= ShelterData.Bi("sick_death_day", 18):
				_die(s, m, "sickness", "Died of an untreated illness (day %d)." % sd)
				continue
			if sd >= ShelterData.Bi("sick_death_roll_day", 10) and s.rng.randf() < ShelterData.B("sick_death_roll_p", 0.1):
				_die(s, m, "sickness", "Died of an untreated illness (day %d)." % sd)
				continue
			if sd == ShelterData.Bi("sick_diseased_day", 7):
				s.say("warn", "%s's illness has turned serious. A medkit would still cure it." % name, ["medkit"], mid)
				if s.has("medkit"):
					s.mistake("medkit_unused", "%s turned Diseased with a medkit on the shelf" % name)
			elif sd == ShelterData.Bi("sick_death_roll_day", 10):
				s.say("warn", "%s may not survive the illness without a medkit." % name, ["medkit"], mid)
		# Injury: untreated wounds can turn into sickness
		if bool(m.get("injured", false)):
			m["injured_days"] = int(m.get("injured_days", 0)) + 1
			if int(m["injured_days"]) >= ShelterData.Bi("injury_infection_day", 6) and not bool(m.get("sick", false)):
				if s.rng.randf() < ShelterData.B("injury_infection_p", 0.3):
					make_sick(s, m, "an untreated wound got infected", "decision")
				elif int(m["injured_days"]) == ShelterData.Bi("injury_infection_day", 6):
					s.say("warn", "%s's wound is hot to the touch." % name, ["medkit"], mid)
		# Acute radiation sickness from the dose of the last 7 days (stages below).
		var ars: int = ars_stage(recent_dose(m, s.day))
		if ars >= 2 and not bool(m.get("sick", false)):
			make_sick(s, m, ars_label(ars).to_lower(), "decision")
		if ars >= 4:
			if bool(m.get("ars_warned", false)) and s.rng.randf() < ShelterData.B("ars_severe_death_p", 0.15):
				_die(s, m, "radiation", "Died of acute radiation sickness.")
				continue
			if not bool(m.get("ars_warned", false)):
				m["ars_warned"] = true
				s.say("warn", "%s has severe radiation sickness. The next days are dangerous." % name, ["medkit"], mid)
		else:
			m["ars_warned"] = false
		# Cold and hungry people catch chills.
		if cold and not bool(m.get("sick", false)) and dwf >= 3:
			var chill: float = ShelterData.B("cold_sick_p", 0.2) * (0.5 if s.has("axe") else 1.0)
			if s.rng.randf() < chill:
				make_sick(s, m, "cold and hungry at %.0f °C" % s.temp_c, "decision")
		# Weak bodies catch things
		if not bool(m.get("sick", false)):
			var weak: bool = dww >= ShelterData.Bi("water_dehydrated_day", 4) or dwf >= ShelterData.Bi("food_starving_day", 8)
			var weak_p: float = ShelterData.B("malnutrition_sick_p", 0.1) * (0.5 if str(m.get("trait", "")) == "iron_stomach" else 1.0)
			if weak and s.rng.randf() < weak_p:
				make_sick(s, m, "weak from %s" % ("thirst" if dww >= ShelterData.Bi("water_dehydrated_day", 4) else "hunger"), "decision")
			elif int(m.get("relapse_until", 0)) > s.day and s.rng.randf() < ShelterData.B("relapse_p", 0.06):
				make_sick(s, m, "the illness came back", "chance")


static func _morale_tick(s: ShelterState) -> void:
	var home: Array = s.home()
	if home.is_empty():
		return
	var changes: Array[String] = []
	for m_v in home:
		var m: Dictionary = m_v
		var before: int = int(m.get("morale", 5))
		var dehydrated: bool = int(m.get("dww", 0)) >= ShelterData.Bi("water_dehydrated_day", 4)
		var starving: bool = int(m.get("dwf", 0)) >= ShelterData.Bi("food_starving_day", 8)
		if (dehydrated or starving) and not (str(m.get("trait", "")) == "bookworm" and before <= 2):
			# Bookworms stay steadier: the daily hardship never takes them below 2.
			add_morale(s, m, ShelterData.Bi("morale_hungry_hit", -1), "")
			if int(m["morale"]) != before:
				changes.append("%s %+d (%s)" % [str(m["name"]), int(m["morale"]) - before, "dehydrated" if dehydrated else "starving"])
		elif before < 5 and not bool(m.get("sick", false)) and s.rng.randf() < ShelterData.B("morale_recover_p", 0.3) * (1.5 if _trait_home(s, "optimist") else 1.0):
			add_morale(s, m, 1, "")
			if int(m["morale"]) != before:
				changes.append("%s +1 (a quiet day)" % str(m["name"]))
	var lifts: Array[String] = []
	for iid in ["cards", "console"]:
		if s.has(iid):
			lifts.append(iid)
	for kind in s.pets.keys():
		lifts.append(str(kind))
	for src in lifts:
		var low: Dictionary = {}
		for m_v in home:
			var m: Dictionary = m_v
			if low.is_empty() or int(m.get("morale", 5)) < int(low.get("morale", 5)):
				low = m
		if not low.is_empty() and int(low.get("morale", 10)) < int(low.get("morale_cap", 10)):
			add_morale(s, low, ShelterData.Bi("morale_item_lift", 1), "")
			var what: String = {"cards": "a game of cards", "console": "the game console", "dog": "the dog", "cat": "the cat"}.get(src, src)
			changes.append("%s +1 (%s)" % [str(low["name"]), what])
			if (src == "cards" or src == "console") and int(low.get("morale", 10)) <= 4:
				s.credit(src, "%s cheered up a little" % str(low["name"]))
	if not changes.is_empty():
		s.say("morale", "Morale: " + ", ".join(changes) + ".")


static func _pets_tick(s: ShelterState) -> void:
	if s.pets.has("dog") and (s.day - int((s.pets["dog"] as Dictionary).get("since", s.day))) % 3 == 2:
		if s.remove(ShelterState.FOOD, 1) == 1:
			s.say("info", "The dog had a ration.", ["food"])
		else:
			s.pets.erase("dog")
			s.say("info", "With no food left, the dog slipped out through the vent and didn't come back.")


## Raids once the shelter has been followed; the gang's takeover attempt if raids go unresolved.
static func _raid_clock(s: ShelterState) -> void:
	if not s.followed:
		return
	if s.day + 1 >= s.gang_day and s.gang_warned:
		_takeover(s)
		return
	if s.day + 1 >= s.next_raid_day:
		_raid(s)


static func _defender_home(s: ShelterState) -> bool:
	for m_v in s.home():
		if not ShelterState.is_child(m_v as Dictionary):
			return true
	return false


static func _raid(s: ShelterState) -> void:
	s.stats["raids"] = int(s.stats["raids"]) + 1
	var interval: int = ShelterData.Bi("hard_raid_interval_days", 2) if s.difficulty == "hard" else ShelterData.Bi("raid_interval_days", 3)
	s.next_raid_day = s.day + 1 + interval
	var stopped: bool = false
	var adult: bool = _defender_home(s)
	if s.home().is_empty() and bool(s.flags.get("locked_empty", false)):
		stopped = true
		s.say("used", "Used: Padlock → held the hatch while everyone was out", ["padlock"])
	elif adult and s.has("rifle") and s.has("ammo"):
		s.remove("ammo", 1)
		s.credit("rifle", "raid stopped (−1 ammo)")
		stopped = true
	elif adult and s.has("rifle"):
		stopped = true
		if s.rng.randf() < ShelterData.B("rifle_no_ammo_break_p", 0.5):
			s.break_one("rifle")
			s.credit("rifle", "raid stopped on a bluff (the rifle broke)")
		else:
			s.credit("rifle", "raid stopped on a bluff (no ammo)")
	elif adult and s.has("axe"):
		s.break_one("axe")
		s.credit("axe", "raid stopped (the axe broke)")
		stopped = true
	elif s.has("padlock"):
		s.remove("padlock", 1)
		s.credit("padlock", "raid stopped (padlock gone)")
		stopped = true
	if stopped:
		s.stats["raids_stopped"] = int(s.stats["raids_stopped"]) + 1
		s.raids_stopped_streak += 1
		s.say("raid", "Raiders tried the hatch in the night and gave up.")
		if s.raids_stopped_streak >= ShelterData.Bi("raids_to_shake", 2):
			s.followed = false
			s.gang_warned = false
			s.say("good", "The gang has stopped coming. Nobody is watching the hatch now.")
		return
	s.raids_stopped_streak = 0
	var taken: Array[String] = steal(s, ShelterData.Bi("raid_steal_units", 2))
	s.missed("padlock" if not s.owns("padlock") else "rifle", "raiders got in")
	s.say("raid", "Raiders got in during the night and took %s." % (", ".join(taken) if not taken.is_empty() else "nothing they wanted"))
	var home: Array = s.home()
	if not home.is_empty() and s.rng.randf() < ShelterData.B("raid_injury_p", 0.4):
		var v: Dictionary = home[s.rng.randi_range(0, home.size() - 1)]
		make_injured(s, v, "hurt in a raid", "chance")


static func _takeover(s: ShelterState) -> void:
	var adult: bool = _defender_home(s)
	if adult and (s.has("rifle") or s.has("axe")):
		var w: String = "rifle" if s.has("rifle") else "axe"
		if w == "rifle" and s.has("ammo"):
			s.remove("ammo", 1)
		elif w == "axe":
			s.break_one("axe")
		s.credit(w, "the gang was driven off for good")
		s.followed = false
		s.gang_warned = false
		s.say("good", "The gang came for the shelter itself and was driven off. They won't be back.")
		return
	if s.home().is_empty() and bool(s.flags.get("locked_empty", false)):
		s.say("raid", "The gang tried the locked hatch and left a mark on it.")
		s.gang_day = s.day + 4
		return
	s.missed("rifle", "nothing could stop the gang")
	finish(s, "loss_takeover")


static func _fallout_news(s: ShelterState) -> void:
	if s.fallout_announced or s.day < s.fallout_clear_day:
		return
	if s.has("radio"):
		s.fallout_announced = true
		s.fallout_known_day = s.day
		s.credit("radio", "the all-clear: fallout is light enough to travel")
	elif s.day >= s.fallout_clear_day + 4:
		s.fallout_announced = true
		s.fallout_known_day = s.day
		s.missed("radio", "nobody heard the all-clear; the family worked it out days late")


## The morning before something fatal can happen, the shelter gets a warning.
static func _morning_omens(s: ShelterState) -> void:
	if s.followed and s.day + 1 >= s.next_raid_day and s.day + 1 < s.gang_day:
		s.say("warn", "Noticed: fresh footprints around the hatch. Expect visitors tonight.", ["padlock", "rifle", "axe"])
	if s.followed and not s.gang_warned and s.day + 1 >= s.gang_day:
		s.gang_warned = true
		s.say("warn", "They've stopped stealing. They're measuring the hatch. Tonight they'll try to take it.", ["rifle", "axe"])


static func _evaluate(s: ShelterState) -> void:
	if s.is_over():
		return
	var living: Array = s.living()
	if living.is_empty():
		finish(s, "loss_all_dead")
		return
	if not s.has_adult(living):
		finish(s, "loss_no_adult")


static func finish(s: ShelterState, ending_id: String) -> void:
	if s.is_over():
		return
	s.ending = ending_id
	s.ending_kind = str((ENDINGS.get(ending_id, {}) as Dictionary).get("kind", "loss"))
	s.ending_day = s.day
	if s.ending_kind == "win":
		s.stats["rescue_day"] = s.day


static func ending_info(s: ShelterState) -> Dictionary:
	var e: Dictionary = (ENDINGS.get(s.ending, {}) as Dictionary).duplicate()
	var place: String = "the shelter nearby"
	var ch: Dictionary = s.chains.get("neighbourhood", {})
	if int(ch.get("place_idx", -1)) >= 0 and int(ch.get("place_idx", -1)) < s.places.size():
		place = ShelterTrips.place_label(s.places[int(ch["place_idx"])])
	e["text"] = str(e.get("text", "")).replace("{place}", place)
	e["id"] = s.ending
	e["day"] = s.ending_day
	return e


# ---------------------------------------------------------------- health helpers

## Dose taken in the last 7 days (mSv), from the member's dose history.
## Acute radiation sickness stage 0..5 from the 7-day dose (mSv). RadiationModel uses these too.
static func ars_stage(recent_msv: float) -> int:
	if recent_msv < 250.0:
		return 0
	if recent_msv < 1000.0:
		return 1
	if recent_msv < 2000.0:
		return 2
	if recent_msv < 4000.0:
		return 3
	if recent_msv < 6000.0:
		return 4
	return 5


static func ars_label(stage: int) -> String:
	match stage:
		0:
			return "No radiation symptoms"
		1:
			return "Blood changes, no symptoms (0.25–1 Sv)"
		2:
			return "Mild radiation sickness (1–2 Sv)"
		3:
			return "Moderate radiation sickness (2–4 Sv)"
		4:
			return "Severe radiation sickness (4–6 Sv)"
		_:
			return "Very severe radiation sickness (>6 Sv)"


static func recent_dose(m: Dictionary, day_n: int) -> float:
	var total: float = 0.0
	for e_v in m.get("dose_hist", []):
		var e: Array = e_v
		if day_n - int(e[0]) < 7:
			total += float(e[1])
	return total


static func add_dose(m: Dictionary, day_n: int, msv: float) -> void:
	m["dose_msv"] = float(m.get("dose_msv", 0.0)) + msv
	if not m.has("dose_hist"):
		m["dose_hist"] = []
	(m["dose_hist"] as Array).append([day_n, msv])


static func make_sick(s: ShelterState, m: Dictionary, why: String, root: String) -> void:
	if bool(m.get("sick", false)) or not bool(m.get("alive", false)):
		return
	m["sick"] = true
	m["sick_days"] = 0
	ShelterState.note_cause(m, s.day, "got sick: " + why, root)
	s.say("sick", "%s is sick (%s)." % [str(m["name"]), why], ["medkit"], str(m["id"]))


static func make_injured(s: ShelterState, m: Dictionary, why: String, root: String) -> void:
	if not bool(m.get("alive", false)):
		return
	if not bool(m.get("injured", false)):
		m["injured"] = true
		m["injured_days"] = 0
	ShelterState.note_cause(m, s.day, "injured: " + why, root)
	s.say("sick", "%s is injured (%s)." % [str(m["name"]), why], ["medkit"], str(m["id"]))


static func cure(s: ShelterState, m: Dictionary) -> void:
	var was_sick: bool = bool(m.get("sick", false))
	m["sick"] = false
	m["sick_days"] = 0
	m["injured"] = false
	m["injured_days"] = 0
	if was_sick:
		m["relapse_until"] = s.day + ShelterData.Bi("relapse_vulnerable_days", 5)


static func add_morale(s: ShelterState, m: Dictionary, n: int, why: String) -> void:
	var before: int = int(m.get("morale", 5))
	var cap: int = int(m.get("morale_cap", 10))
	m["morale"] = clampi(before + n, 0, cap)
	if why != "" and int(m["morale"]) != before:
		s.say("morale", "%s %+d morale (%s)." % [str(m["name"]), int(m["morale"]) - before, why], [], str(m["id"]))
	if before > 0 and int(m["morale"]) == 0:
		s.say("warn", "%s has stopped talking and won't work until things improve." % str(m["name"]), ["cards", "console"], str(m["id"]))


static func _die(s: ShelterState, m: Dictionary, cause: String, reason: String) -> void:
	m["alive"] = false
	m["loc"] = "dead"
	m["death_day"] = s.day + 1
	m["death_reason"] = reason
	var root: String = "decision"
	if cause == "sickness":
		var chain: Array = m.get("causes", [])
		root = "chance"
		for c_v in chain:
			if str((c_v as Dictionary).get("root", "")) == "decision":
				root = "decision"
		if s.has("medkit"):
			s.mistake("medkit_unused_death", "%s died of an illness with a medkit on the shelf" % str(m["name"]))
	if cause == "thirst" and s.water() > 0:
		s.mistake("thirst_with_water", "%s died of thirst with water on the shelf" % str(m["name"]))
	if cause == "starvation" and s.food() > 0:
		s.mistake("hunger_with_food", "%s starved with food on the shelf" % str(m["name"]))
	record_death(s, m, cause, root)
	s.say("death", "%s died. %s" % [str(m["name"]), reason], [], str(m["id"]))


## Bookkeeping shared by every way to die: stats, cause chain, everyone's morale.
static func record_death(s: ShelterState, m: Dictionary, cause: String, root: String) -> void:
	(s.stats["deaths"] as Array).append({"id": str(m.get("id", "")), "name": str(m.get("name", "")), "day": s.day + 1, "cause": cause, "root": root, "chain": (m.get("causes", []) as Array).duplicate(true)})
	var grieving: Array = s.home()
	# An optimist at home keeps everyone's spirits up when things go badly.
	var hit: int = ShelterData.Bi("morale_death_hit", -3) + (1 if _trait_home(s, "optimist") else 0)
	for o_v in grieving:
		add_morale(s, o_v as Dictionary, hit, "")
	if not grieving.is_empty():
		s.say("morale", "Morale %d for everyone (grief)." % hit)


static func _trait_home(s: ShelterState, trait_id: String) -> bool:
	for m_v in s.home():
		if str((m_v as Dictionary).get("trait", "")) == trait_id:
			return true
	return false


static func become_followed(s: ShelterState, why: String) -> void:
	if s.followed:
		return
	s.followed = true
	s.followed_since = s.day
	s.raids_stopped_streak = 0
	var interval: int = ShelterData.Bi("hard_raid_interval_days", 2) if s.difficulty == "hard" else ShelterData.Bi("raid_interval_days", 3)
	s.next_raid_day = s.day + 1 + interval
	s.gang_day = s.day + s.rng.randi_range(ShelterData.Bi("gang_min_days", 20), ShelterData.Bi("gang_max_days", 30))
	s.gang_warned = false
	s.stats["followed_count"] = int(s.stats["followed_count"]) + 1
	s.say("warn", "Noticed: %s. Raids will start in a few days." % why, ["padlock", "rifle", "axe"])


## Raiders take n supply units: whole cans and bottles first, then loose gear.
static func steal(s: ShelterState, n: int) -> Array[String]:
	var taken: Array[String] = []
	for _i in range(n):
		var pool: Array[String] = []
		if s.food() >= 1:
			pool.append(ShelterState.FOOD)
		if s.water() >= 1:
			pool.append(ShelterState.WATER)
		if pool.is_empty():
			for k in s.stock.keys():
				if str(k) != "radio" and s.count(str(k)) > 0:
					pool.append(str(k))
		if pool.is_empty():
			break
		var pick: String = pool[s.rng.randi_range(0, pool.size() - 1)]
		var lost: int = s.lose_units(pick, 1)
		if lost > 0:
			taken.append(("a can of food" if pick == ShelterState.FOOD else ("a bottle of water" if pick == ShelterState.WATER else "the " + ShelterData.item_name(pick).to_lower())))
	return taken


# ---------------------------------------------------------------- visuals and text

## Keeps the fields the portraits and the shelter backdrop read in step with the rules.
static func sync_visuals(m: Dictionary, day_n: int) -> void:
	var dww: int = int(m.get("dww", 0))
	var dwf: int = int(m.get("dwf", 0))
	m["thirst"] = 0 if dww < 3 else (1 if dww < 4 else (2 if dww < 5 else 3))
	m["hunger"] = 0 if dwf < 6 else (1 if dwf < 8 else 2)
	m["sickness"] = 0 if not bool(m.get("sick", false)) else (1 if int(m.get("sick_days", 0)) < 7 else 2)
	m["injury"] = 1 if bool(m.get("injured", false)) else 0
	var mo: int = int(m.get("morale", 7))
	m["sanity"] = 0 if mo >= 5 else (1 if mo >= 3 else (2 if mo >= 1 else 3))
	m["fatigue"] = 1 if int(m.get("tired_until", 0)) > day_n else 0
	m["in_bunker"] = str(m.get("loc", "")) in ["shelter", "away"]
	m["on_expedition"] = str(m.get("loc", "")) == "away"
	m["status_note"] = status_text(m, day_n)


static func status_labels(m: Dictionary, day_n: int) -> Array[String]:
	var out: Array[String] = []
	if not bool(m.get("alive", false)):
		out.append("Dead")
		return out
	if str(m.get("loc", "")) == "away":
		out.append("Away")
	var dww: int = int(m.get("dww", 0))
	var dwf: int = int(m.get("dwf", 0))
	if dww >= 4:
		out.append("Dehydrated")
	elif dww >= 3:
		out.append("Thirsty")
	if dwf >= 8:
		out.append("Starving")
	elif dwf >= 6:
		out.append("Hungry")
	if bool(m.get("sick", false)):
		out.append("Diseased" if int(m.get("sick_days", 0)) >= 7 else "Sick")
	if bool(m.get("injured", false)):
		out.append("Injured")
	var ars: int = ars_stage(recent_dose(m, day_n))
	if ars >= 4:
		out.append("Severe radiation sickness")
	elif ars >= 2:
		out.append("Radiation sickness")
	if int(m.get("tired_until", 0)) > day_n:
		out.append("Tired")
	if int(m.get("morale", 5)) <= 0:
		out.append("Withdrawn")
	if out.is_empty():
		out.append("OK")
	return out


static func status_text(m: Dictionary, day_n: int) -> String:
	if not bool(m.get("alive", false)):
		return str(m.get("death_reason", "Dead."))
	return ", ".join(status_labels(m, day_n))


static func join_names(names: Array) -> String:
	if names.is_empty():
		return "nobody"
	if names.size() == 1:
		return str(names[0])
	if names.size() == 2:
		return "%s and %s" % [str(names[0]), str(names[1])]
	var head: Array[String] = []
	for i in range(names.size() - 1):
		head.append(str(names[i]))
	return "%s and %s" % [", ".join(head), str(names[names.size() - 1])]
