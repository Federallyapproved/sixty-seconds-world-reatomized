class_name ShelterEvents
extends RefCounted

## The event director and the effect interpreter for data/events/*.json (section 9).
##
## Fairness rules enforced here:
## * no event repeats within a run;
## * at most `bad_streak_max` bad events in a row;
## * an event that can kill or end the run is only drawn once its warning kind was issued on an
##   earlier day (the director shows the event's "omen" line first);
## * rescue requests and scheduled follow-ups take the slot on their day; then a House meeting
##   every few days (section 7); everything else is a weighted draw over the events whose
##   conditions hold today;
## * at most one stranger per run (events marked "stranger": true).

const FRAGILE: Array[String] = ["gas_mask", "flashlight", "radio"]
const REPAIRABLE_ORDER: Array[String] = ["radio", "gas_mask", "flashlight", "rifle", "axe", "map"]


# ---------------------------------------------------------------- drawing

static func draw(s: ShelterState) -> Dictionary:
	# 1. Delayed consequences scheduled for today.
	var keep: Array = []
	var due_id: String = ""
	for sc_v in s.scheduled:
		var sc: Dictionary = sc_v
		if due_id == "" and int(sc["day"]) <= s.day and not s.used_events.has(str(sc["event"])):
			var ev0: Dictionary = ShelterData.event(str(sc["event"]))
			if not ev0.is_empty() and _conditions_ok(s, ev0, true):
				due_id = str(sc["event"])
				continue
		if int(sc["day"]) >= s.day - 3:
			keep.append(sc)
	s.scheduled = keep
	if due_id != "":
		return _prepare(s, ShelterData.event(due_id))
	# 2. Rescue requests due today.
	var chain_ev: String = ShelterChains.due_event(s)
	if chain_ev != "":
		return _prepare(s, ShelterData.event(chain_ev))
	# 2b. A House meeting every few days, while there is a rule left to argue about.
	if s.day >= s.next_meeting_day and not actor(s).is_empty():
		var mt: Dictionary = meeting_event(s)
		if mt.is_empty():
			s.next_meeting_day = 9999
		else:
			s.next_meeting_day = s.day + ShelterData.Bi("rule_meeting_every", 4)
			return mt
	# 3. A quiet day now and then.
	if s.rng.randf() > ShelterData.B("event_day_p", 0.9):
		return {}
	var cands: Array = []
	var weights: Array[float] = []
	var total: float = 0.0
	var max_bad: int = ShelterData.Bi("bad_streak_max", 2)
	var all: Dictionary = ShelterData.events()
	var ids: Array = all.keys()
	ids.sort()
	for eid_v in ids:
		var ev: Dictionary = all[eid_v]
		if s.used_events.has(str(eid_v)) or bool(ev.get("system", false)) or ev.has("chain"):
			continue
		if bool(ev.get("stranger", false)) and str(s.stats.get("stranger", "")) != "":
			continue
		if bool(ev.get("contagion", false)) and s.has_rule("sick_sleep_upstairs"):
			continue
		if str(ev.get("mood", "")) == "bad" and s.bad_streak >= max_bad:
			continue
		if not _conditions_ok(s, ev, false):
			continue
		var warn: String = str(ev.get("warning", ""))
		if warn != "" and not _warned(s, warn):
			continue
		var w: float = _weight(s, ev)
		if w <= 0.0:
			continue
		cands.append(ev)
		weights.append(w)
		total += w
	# Fatal events whose warning hasn't been given yet: sometimes the omen appears today.
	_maybe_issue_omen(s, all, ids)
	if cands.is_empty():
		return {}
	var r: float = s.rng.randf() * total
	for i in range(cands.size()):
		r -= weights[i]
		if r <= 0.0:
			return _prepare(s, cands[i])
	return _prepare(s, cands.back())


static func _warned(s: ShelterState, kind: String) -> bool:
	return s.warnings.has(kind) and int(s.warnings[kind]) < s.day


static func _maybe_issue_omen(s: ShelterState, all: Dictionary, ids: Array) -> void:
	for eid_v in ids:
		var ev: Dictionary = all[eid_v]
		var warn: String = str(ev.get("warning", ""))
		if warn == "" or s.warnings.has(warn) or s.used_events.has(str(eid_v)):
			continue
		if not _conditions_ok(s, ev, false):
			continue
		if s.rng.randf() < 0.35:
			s.warnings[warn] = s.day
			var omen: String = str(ev.get("omen", ""))
			if omen != "":
				s.say("warn", _fill(s, omen, {}), [])
			return


static func _weight(s: ShelterState, ev: Dictionary) -> float:
	var w: float = float(ev.get("weight", 1.0))
	var mods: Dictionary = ev.get("weight_mods", {})
	for k_v in mods.keys():
		var k: String = str(k_v)
		var f: float = float(mods[k_v])
		var hit: bool = false
		if k == "followed":
			hit = s.followed
		elif k == "heavy_fallout":
			hit = ShelterTrips.heavy_fallout(s)
		elif k == "after_escalation":
			hit = s.day >= ShelterData.Bi("escalation_day", 8)
		elif k == "sick":
			hit = _any(s.home(), func(m: Dictionary) -> bool: return bool(m.get("sick", false)))
		elif k == "low_morale":
			hit = _any(s.home(), func(m: Dictionary) -> bool: return int(m.get("morale", 5)) <= 3)
		elif k == "pet":
			hit = not s.pets.is_empty()
		elif k.begins_with("owned:"):
			hit = s.has(k.substr(6))
		elif k.begins_with("missing:"):
			hit = not s.owns(k.substr(8))
		elif k.begins_with("place:"):
			hit = _place_of(s, [k.substr(6)]) >= 0
		elif k == "afflicted":
			hit = _any(s.home(), func(m: Dictionary) -> bool: return ShelterState.affliction(m) != "")
		elif k == "guilt":
			hit = _any(s.living(), func(m: Dictionary) -> bool: return bool(m.get("guilt", false)))
		elif k.begins_with("rule:"):
			hit = s.has_rule(k.substr(5))
		if hit:
			w *= f
	return w


static func _any(arr: Array, pred: Callable) -> bool:
	for a in arr:
		if pred.call(a):
			return true
	return false


static func _conditions_ok(s: ShelterState, ev: Dictionary, forced: bool) -> bool:
	var c: Dictionary = ev.get("conditions", {})
	if c.has("min_day") and s.day < int(c["min_day"]):
		return false
	if c.has("max_day") and s.day > int(c["max_day"]):
		return false
	if c.has("needs_place") and _place_of(s, c["needs_place"]) < 0:
		return false
	if bool(c.get("needs_away", false)) and s.trips.is_empty():
		return false
	if c.has("trip_place") and _trip_at(s, c["trip_place"]).is_empty():
		return false
	if bool(c.get("needs_followed", false)) and not s.followed:
		return false
	if bool(c.get("not_followed", false)) and s.followed:
		return false
	if bool(c.get("needs_fallout_clear", false)) and ShelterTrips.heavy_fallout(s):
		return false
	if bool(c.get("needs_heavy_fallout", false)) and not ShelterTrips.heavy_fallout(s):
		return false
	if c.has("needs_flag") and not s.flags.has(str(c["needs_flag"])):
		return false
	if c.has("not_flag") and s.flags.has(str(c["not_flag"])):
		return false
	if c.has("needs_owned") and not s.has(str(c["needs_owned"])):
		return false
	if c.has("needs_missing") and s.owns(str(c["needs_missing"])):
		return false
	if c.has("needs_broken") and s.broken_count(str(c["needs_broken"])) <= 0:
		return false
	if c.has("needs_pet") and not s.pets.has(str(c["needs_pet"])):
		return false
	if bool(c.get("no_pet", false)) and not s.pets.is_empty():
		return false
	if bool(c.get("needs_sick", false)) and not _any(s.home(), func(m: Dictionary) -> bool: return bool(m.get("sick", false))):
		return false
	if bool(c.get("needs_injured", false)) and not _any(s.home(), func(m: Dictionary) -> bool: return bool(m.get("injured", false))):
		return false
	if bool(c.get("needs_child", false)) and not _any(s.home(), func(m: Dictionary) -> bool: return ShelterState.is_child(m)):
		return false
	if bool(c.get("needs_low_morale", false)) and not _any(s.home(), func(m: Dictionary) -> bool: return int(m.get("morale", 5)) <= 4):
		return false
	if c.has("min_people") and s.home().size() < int(c["min_people"]):
		return false
	if c.has("needs_chain_active") and str((s.chains.get(str(c["needs_chain_active"]), {}) as Dictionary).get("state", "")) != "active":
		return false
	if bool(c.get("after_escalation", false)) and s.day < ShelterData.Bi("escalation_day", 8):
		return false
	if bool(c.get("trip_occupied", false)) and _occupied_trip(s).is_empty():
		return false
	if c.has("needs_rule") and not s.has_rule(str(c["needs_rule"])):
		return false
	if c.has("not_rule") and s.has_rule(str(c["not_rule"])):
		return false
	if c.has("needs_affliction"):
		var want: String = str(c["needs_affliction"])
		if not _any(s.home(), func(m: Dictionary) -> bool: return ShelterState.affliction(m) != "" and (want == "any" or ShelterState.affliction(m) == want)):
			return false
	if bool(c.get("needs_guilt", false)) and not _any(s.living(), func(m: Dictionary) -> bool: return bool(m.get("guilt", false))):
		return false
	if bool(c.get("needs_pet_any", false)) and s.pets.is_empty():
		return false
	# Somebody has to be home and able to act on a shelter event.
	if not forced and actor(s).is_empty() and not c.has("trip_place"):
		return false
	return true


## Index of the nearest real place of one of these categories, or -1.
static func _place_of(s: ShelterState, cats: Variant) -> int:
	var arr: Array = cats if cats is Array else [cats]
	var best: int = -1
	var best_d: float = INF
	for p_v in s.places:
		var p: Dictionary = p_v
		if bool(p.get("fictional", false)):
			continue
		if str(p["category"]) in arr and float(p["walk_m"]) < best_d:
			best_d = float(p["walk_m"])
			best = int(p["idx"])
	return best


## The trip whose explorer is at a house where somebody still lives.
static func _occupied_trip(s: ShelterState) -> Dictionary:
	for t_v in s.trips:
		var t: Dictionary = t_v
		if not bool(t["dead"]) and bool((s.places[int(t["place_idx"])] as Dictionary).get("occupied", false)):
			return t
	return {}


static func _trip_at(s: ShelterState, cats: Variant) -> Dictionary:
	var arr: Array = cats if cats is Array else [cats]
	for t_v in s.trips:
		var t: Dictionary = t_v
		if bool(t["dead"]):
			continue
		var p: Dictionary = s.places[int(t["place_idx"])]
		if str(p["category"]) in arr or arr.has("any"):
			return t
	return {}


## The leader acts when present and able; otherwise the oldest able survivor (never a child
## unless nobody else is home).
static func actor(s: ShelterState) -> Dictionary:
	var home: Array = s.home()
	for m_v in home:
		var m: Dictionary = m_v
		if bool(m.get("is_leader", false)) and _able(m, s):
			return m
	var best: Dictionary = {}
	for m_v in home:
		var m: Dictionary = m_v
		if not _able(m, s) or ShelterState.is_child(m):
			continue
		if best.is_empty() or int(m.get("age", 0)) > int(best.get("age", 0)):
			best = m
	if best.is_empty() and not home.is_empty():
		best = home[0]
	return best


static func _able(m: Dictionary, s: ShelterState = null) -> bool:
	if not bool(m.get("alive", false)) or str(m.get("loc", "")) != "shelter":
		return false
	if ShelterState.affliction(m) == "withdrawn":
		return s != null and s.has_rule("work_or_dont_eat")
	return true


## Copies the event, picks its actor/subject/explorer, and fills the text placeholders.
static func _prepare(s: ShelterState, ev_src: Dictionary) -> Dictionary:
	var ev: Dictionary = ev_src.duplicate(true)
	var ctx: Dictionary = {}
	var a: Dictionary = actor(s)
	ctx["actor"] = str(a.get("id", ""))
	ctx["title"] = str(ev.get("title", ""))
	var c: Dictionary = ev.get("conditions", {})
	if c.has("trip_place"):
		var t: Dictionary = _occupied_trip(s) if bool(c.get("trip_occupied", false)) else _trip_at(s, c["trip_place"])
		ctx["explorer"] = str(t.get("member", ""))
		ctx["place_idx"] = int(t.get("place_idx", -1))
	elif ev.has("chain"):
		ctx["place_idx"] = int((s.chains.get(str(ev["chain"]), {}) as Dictionary).get("place_idx", -1))
	var subj: Dictionary = _pick_subject(s, ev, a)
	ctx["subject"] = str(subj.get("id", ""))
	ev["ctx"] = ctx
	ev["title"] = _fill(s, str(ev.get("title", "")), ctx)
	ev["setup"] = _fill(s, str(ev.get("setup", "")), ctx)
	for o_v in ev.get("options", []):
		var o: Dictionary = o_v
		o["label"] = _fill(s, str(o.get("label", "")), ctx)
	return ev


static func _pick_subject(s: ShelterState, ev: Dictionary, a: Dictionary) -> Dictionary:
	var home: Array = s.home()
	if home.is_empty():
		return {}
	var c: Dictionary = ev.get("conditions", {})
	if bool(c.get("needs_sick", false)):
		for m_v in home:
			if bool((m_v as Dictionary).get("sick", false)):
				return m_v
	if bool(c.get("needs_injured", false)):
		for m_v in home:
			if bool((m_v as Dictionary).get("injured", false)):
				return m_v
	if bool(c.get("needs_child", false)):
		for m_v in home:
			if ShelterState.is_child(m_v as Dictionary):
				return m_v
	if c.has("needs_affliction"):
		for m_v in home:
			var aff: String = ShelterState.affliction(m_v as Dictionary)
			if aff != "" and (str(c["needs_affliction"]) == "any" or aff == str(c["needs_affliction"])):
				return m_v
	if bool(c.get("needs_guilt", false)):
		for m_v in s.living():
			if bool((m_v as Dictionary).get("guilt", false)):
				return m_v
	var others: Array = home.filter(func(m: Dictionary) -> bool: return str(m["id"]) != str(a.get("id", "")))
	if others.is_empty():
		return a
	return others[s.rng.randi_range(0, others.size() - 1)]


## A House meeting (section 7): up to two rules on the table, or none. Built from house_rules.csv.
static func meeting_event(s: ShelterState) -> Dictionary:
	var offers: Array = ShelterSim.offered_rules(s)
	if offers.is_empty():
		return {}
	var setup: String = ShelterData.line_for("house_meeting", s.lines_used, s.rng)
	if setup == "":
		setup = "Someone has written HOUSE RULES on the wall again. There's room for one more line."
	var opts: Array = []
	for rid_v in offers:
		var rid: String = str(rid_v)
		var r: Dictionary = ShelterData.house_rule(rid)
		opts.append({
			"id": "rule_" + rid, "label": "Adopt \"%s\"" % str(r.get("name", rid)),
			"stakes": "%s · %s" % [str(r.get("bonus", "")), str(r.get("cost", ""))],
			"effects": [{"do": "rule", "rule": rid}], "outcome": str(r.get("narrator_line", "")), "cinematic": "gloom",
		})
	opts.append({"id": "no_rule", "label": "No new rules this time", "stakes": "nothing changes",
		"effects": [{"do": "rule_declined"}], "outcome": "The meeting ends without a vote. The wall keeps its space.", "cinematic": ""})
	var ev: Dictionary = {"id": "house_meeting", "title": "House Meeting", "type": "house_rule", "mood": "neutral",
		"system": true, "setup": setup, "options": opts}
	return _prepare(s, ev)


# ---------------------------------------------------------------- options

## Options as the card shows them: basic first, then item options; unavailable item options are
## greyed "Needs: X". Each carries a stakes band.
static func options_for(s: ShelterState, ev: Dictionary) -> Array:
	var res: Array = []
	if ev.is_empty():
		return res
	var ctx: Dictionary = ev.get("ctx", {})
	var para: Dictionary = ShelterSim.paranoid_home(s)
	for o_v in ev.get("options", []):
		var o: Dictionary = o_v
		var it: String = str(o.get("item", ""))
		var avail: bool = true
		var need: String = ""
		if it != "":
			if s.hide_unknown and not s.known_items.has(it) and not s.owns(it):
				continue
			avail = _item_ready(s, it, ctx)
			if not avail:
				need = "Needs: %s" % ShelterData.item_name(it)
		if avail and bool(o.get("hatch", false)):
			if s.has_rule("nobody_opens_hatch"):
				avail = false
				need = "House Rule: Nobody opens the hatch"
			elif not para.is_empty():
				avail = false
				need = "Paranoid %s won't open the hatch" % str(para.get("name", ""))
		res.append({
			"id": str(o["id"]), "label": str(o.get("label", "")), "item": it, "available": avail,
			"needs": need, "stakes": str(o.get("stakes", "")) if str(o.get("stakes", "")) != "" else stakes_for(o.get("effects", []), s.difficulty == "story"),
		})
	return res


static func _item_ready(s: ShelterState, it: String, ctx: Dictionary) -> bool:
	if ctx.has("explorer") and str(ctx.get("explorer", "")) != "":
		for t_v in s.trips:
			var t: Dictionary = t_v
			if str(t["member"]) == str(ctx["explorer"]) and (t["gear"] as Array).has(it):
				return true
		return false
	if it == ShelterState.FOOD or it == ShelterState.WATER:
		return s.count(it) >= int(ShelterData.item_effect(it, "rations", 4.0))
	return s.has(it)


## A short, honest summary of what an option risks ("likely lose 2 water"); Story mode shows the
## exact odds ("40%: lose 2 water").
static func stakes_for(effs: Array, exact: bool = false) -> String:
	var bits: Array[String] = []
	for e_v in effs:
		var e: Dictionary = e_v
		var op: String = str(e.get("do", ""))
		match op:
			"lose":
				bits.append("lose %d %s" % [int(e.get("n", 1)), _unit_word(str(e.get("item", "")), int(e.get("n", 1)))])
			"rations":
				if int(e.get("n", 0)) < 0:
					bits.append("lose %d %s ration%s" % [-int(e.get("n", 0)), str(e.get("kind", "food")), "" if int(e.get("n", 0)) == -1 else "s"])
			"steal":
				bits.append("lose %d supplies" % int(e.get("n", 1)))
			"sick":
				bits.append("someone gets sick")
			"injure":
				bits.append("someone gets hurt")
			"kill":
				bits.append("someone may die")
			"lose_run":
				bits.append("could end the run")
			"morale":
				if int(e.get("n", 0)) < 0:
					bits.append("morale drops")
			"dose":
				bits.append("radiation")
			"followed":
				bits.append("may be followed")
			"chain":
				if str(e.get("step", "")) == "miss":
					bits.append("rescue delayed")
			"chance":
				var inner: String = stakes_for(e.get("then", []), exact)
				if inner != "":
					var p: float = float(e.get("p", 0.5))
					var word: String = ("%d%%:" % int(round(p * 100.0))) if exact else ("likely" if p >= 0.6 else ("maybe" if p >= 0.35 else "small chance:"))
					bits.append("%s %s" % [word, inner])
	return "; ".join(bits)


static func _unit_word(item_id: String, n: int) -> String:
	if item_id == ShelterState.FOOD:
		return "can" if n == 1 else "cans"
	if item_id == ShelterState.WATER:
		return "water"
	return ShelterData.item_name(item_id).to_lower()


# ---------------------------------------------------------------- resolving

static func resolve(s: ShelterState, ev: Dictionary, option_id: String) -> Dictionary:
	var opt: Dictionary = {}
	for o_v in ev.get("options", []):
		if str((o_v as Dictionary).get("id", "")) == option_id:
			opt = o_v
	if opt.is_empty():
		return {}
	var ctx: Dictionary = ev.get("ctx", {})
	var it: String = str(opt.get("item", ""))
	if it != "" and not _item_ready(s, it, ctx):
		return {}
	if bool(opt.get("hatch", false)) and (s.has_rule("nobody_opens_hatch") or not ShelterSim.paranoid_home(s).is_empty()):
		return {}
	var mark: int = s.receipt.size()
	var eid: String = str(ev.get("id", ""))
	s.used_events[eid] = s.day
	s.events_seen += 1
	s.stats["events"] = int(s.stats["events"]) + 1
	if str(ev.get("mood", "")) == "bad":
		s.bad_streak += 1
	else:
		s.bad_streak = 0
	if it != "":
		s.stats["item_options_used"] = int(s.stats["item_options_used"]) + 1
		var ol: Dictionary = s.stats["item_option_labels"]
		if not ol.has(it):
			ol[it] = []
		if not (ol[it] as Array).has(str(opt.get("label", ""))):
			(ol[it] as Array).append(str(opt.get("label", "")))
	if bool(ev.get("stranger", false)):
		s.stats["stranger"] = eid
		if it != "":
			s.stats["stranger_helped"] = true
	if bool(opt.get("loud", false)):
		s.loud_bonus += 0.1
	var tags: Array = []
	apply_effects(s, opt.get("effects", []), ctx, tags)
	var lines: Array = s.receipt.slice(mark)
	s.receipt = s.receipt.slice(0, mark)
	var text: String = _fill(s, str(opt.get("outcome", "")), ctx)
	return {
		"event_id": eid, "choice_id": option_id, "item_used": it, "text": text, "lines": lines,
		"items": ([it] if it != "" else []), "tags": tags, "cinematic": str(opt.get("cinematic", "")),
		"actor_id": str(ctx.get("actor", "")), "subject_id": str(ctx.get("subject", "")),
	}


static func apply_effects(s: ShelterState, effs: Array, ctx: Dictionary, tags: Array) -> void:
	for e_v in effs:
		apply_effect(s, e_v as Dictionary, ctx, tags)


static func _targets(s: ShelterState, who: String, ctx: Dictionary) -> Array:
	var home: Array = s.home()
	match who:
		"actor":
			var a: Dictionary = s.member(str(ctx.get("actor", "")))
			return [a] if not a.is_empty() else []
		"explorer":
			var e: Dictionary = s.member(str(ctx.get("explorer", "")))
			return [e] if not e.is_empty() else []
		"subject":
			var sb: Dictionary = s.member(str(ctx.get("subject", "")))
			return [sb] if not sb.is_empty() else []
		"all":
			return home
		"random":
			return [home[s.rng.randi_range(0, home.size() - 1)]] if not home.is_empty() else []
		"child":
			for m_v in home:
				if ShelterState.is_child(m_v as Dictionary):
					return [m_v]
			return [home[s.rng.randi_range(0, home.size() - 1)]] if not home.is_empty() else []
		"adult":
			var ad: Array = home.filter(func(m: Dictionary) -> bool: return not ShelterState.is_child(m))
			return [ad[s.rng.randi_range(0, ad.size() - 1)]] if not ad.is_empty() else []
		"weakest":
			var best: Dictionary = {}
			for m_v in home:
				var m: Dictionary = m_v
				if best.is_empty() or int(m.get("morale", 5)) < int(best.get("morale", 5)):
					best = m
			return [best] if not best.is_empty() else []
		"sickest":
			for m_v in home:
				if bool((m_v as Dictionary).get("sick", false)):
					return [m_v]
			return [home[s.rng.randi_range(0, home.size() - 1)]] if not home.is_empty() else []
		"thirstiest":
			var bt: Dictionary = {}
			for m_v in home:
				var m: Dictionary = m_v
				if bt.is_empty() or int(m.get("dww", 0)) > int(bt.get("dww", 0)):
					bt = m
			return [bt] if not bt.is_empty() else []
	return []


static func apply_effect(s: ShelterState, e: Dictionary, ctx: Dictionary, tags: Array) -> void:
	var op: String = str(e.get("do", ""))
	var it: String = str(e.get("item", ""))
	var n: int = int(e.get("n", 1))
	var who: String = str(e.get("who", "actor"))
	match op:
		"add":
			s.add_units(it, n)
			tags.append("item_gained")
			s.say("gain", "+%d %s" % [n, _unit_name(it, n)], [it])
		"lose":
			var lost: int = s.lose_units(it, n)
			if lost > 0:
				tags.append("item_lost")
				s.say("lost", "−%d %s" % [lost, _unit_name(it, lost)], [it])
		"rations":
			var kind: String = str(e.get("kind", "food"))
			if n >= 0:
				s.add(kind, n)
				s.say("gain", "+%d %s ration%s" % [n, kind, "" if n == 1 else "s"], [kind])
			else:
				var r: int = s.remove(kind, -n)
				if r > 0:
					s.say("lost", "−%d %s ration%s" % [r, kind, "" if r == 1 else "s"], [kind])
		"use":
			_use_item(s, it, str(e.get("mode", "")), _fill(s, str(e.get("what", "did its job")), ctx), ctx)
			tags.append("used_" + it)
		"give":
			if s.remove(it, 1) == 1:
				s.credit(it, _fill(s, str(e.get("what", "handed over")), ctx))
				tags.append("item_lost")
		"break":
			if s.break_one(it):
				s.say("break", "%s broke." % ShelterData.item_name(it), [it])
				tags.append("item_broken")
		"break_fragile":
			if s.rng.randf() < float(e.get("p", ShelterData.B("quake_break_p", 0.4))):
				var pool: Array[String] = []
				for f in FRAGILE:
					if s.has(f):
						pool.append(f)
				if not pool.is_empty():
					var pick: String = pool[s.rng.randi_range(0, pool.size() - 1)]
					s.break_one(pick)
					s.say("break", "The %s broke in the shaking." % ShelterData.item_name(pick).to_lower(), [pick])
					tags.append("item_broken")
		"repair":
			_repair(s, it, tags, str(s.member(str(ctx.get("actor", ""))).get("trait", "")) == "handy")
		"sick":
			for m_v in _targets(s, who, ctx):
				ShelterSim.make_sick(s, m_v as Dictionary, str(e.get("why", "an event")), str(e.get("root", "decision")))
				tags.append("sick")
		"injure":
			for m_v in _targets(s, who, ctx):
				ShelterSim.make_injured(s, m_v as Dictionary, str(e.get("why", "an event")), str(e.get("root", "decision")))
				tags.append("injured")
		"cure":
			for m_v in _targets(s, who, ctx):
				ShelterSim.cure(s, m_v as Dictionary)
				tags.append("healed")
		"kill":
			for m_v in _targets(s, who, ctx):
				var m: Dictionary = m_v
				if not bool(m.get("alive", false)):
					continue
				m["alive"] = false
				m["loc"] = "dead"
				m["death_day"] = s.day
				m["death_reason"] = str(e.get("cause", "Died."))
				ShelterState.note_cause(m, s.day, str(e.get("cause", "died")), str(e.get("root", "decision")))
				ShelterSim.record_death(s, m, str(e.get("kind", "event")), str(e.get("root", "decision")))
				s.say("death", "%s died. %s" % [str(m["name"]), str(e.get("cause", ""))], [], str(m["id"]))
				tags.append("death")
		"morale":
			var tg: Array = _targets(s, str(e.get("who", "all")), ctx)
			for m_v in tg:
				ShelterSim.add_morale(s, m_v as Dictionary, n, "")
			if not tg.is_empty():
				var who_txt: String = "everyone" if str(e.get("who", "all")) == "all" and tg.size() > 1 else str((tg[0] as Dictionary).get("name", ""))
				var why: String = str(e.get("why", "")) if str(e.get("why", "")) != "" else _fill(s, str(ctx.get("title", "")), ctx)
				s.say("morale", "Morale %+d for %s (%s)." % [n, who_txt, why.to_lower() if why != "" else "today"], [])
			tags.append("morale_up" if n > 0 else "morale_down")
		"dose":
			for m_v in _targets(s, who, ctx):
				var m: Dictionary = m_v
				ShelterSim.add_dose(m, s.day, float(e.get("msv", 20.0)))
				s.say("info", "%s took about %d mSv." % [str(m["name"]), int(e.get("msv", 20))], [], str(m["id"]))
			tags.append("hazard_return")
		"tired":
			for m_v in _targets(s, who, ctx):
				(m_v as Dictionary)["tired_until"] = s.day + 1 + int(e.get("days", 1))
		"refuse_trip":
			for m_v in _targets(s, who, ctx):
				(m_v as Dictionary)["refuse_until"] = s.day + 1 + int(e.get("days", 1))
				s.say("status", "%s refuses to go out tomorrow." % str((m_v as Dictionary)["name"]))
		"chance":
			if s.rng.randf() < float(e.get("p", 0.5)):
				apply_effects(s, e.get("then", []), ctx, tags)
			else:
				apply_effects(s, e.get("else", []), ctx, tags)
		"followed":
			if s.rng.randf() < float(e.get("p", 1.0)):
				if s.has_rule("nobody_opens_hatch") and str(ctx.get("explorer", "")) == "":
					s.say("good", "Nobody saw anything worth following: the hatch stayed shut (House Rule).")
				else:
					ShelterSim.become_followed(s, str(e.get("why", "somebody saw the hatch")))
					tags.append("raid")
		"unfollow":
			if s.followed:
				s.followed = false
				s.gang_warned = false
				s.say("good", "Nobody is watching the hatch any more.")
		"schedule":
			s.scheduled.append({"event": str(e.get("event", "")), "day": s.day + int(e.get("in", 1))})
		"warn":
			s.warnings[str(e.get("kind", ""))] = s.day
		"chain":
			ShelterChains.step(s, str(e.get("chain", "")), str(e.get("step", "advance")), ctx)
			tags.append("rescue_progress")
		"pet":
			var kind: String = str(e.get("kind", "dog"))
			s.pets[kind] = {"since": s.day}
			if not (s.stats["pets_adopted"] as Array).has(kind):
				(s.stats["pets_adopted"] as Array).append(kind)
			tags.append("companion")
			s.say("good", "A %s lives in the shelter now." % kind)
		"pet_leaves":
			if not s.pets.is_empty():
				s.pets.clear()
				s.say("lost", "The animal is gone.")
		"steal":
			var taken: Array[String] = ShelterSim.steal(s, n)
			if not taken.is_empty():
				s.say("lost", "Taken: %s." % ", ".join(taken))
				tags.append("item_lost")
		"trip_loot":
			for t_v in s.trips:
				var t: Dictionary = t_v
				if str(t["member"]) == str(ctx.get("explorer", "")):
					var ex: Dictionary = t["extra_loot"]
					ex[it] = int(ex.get(it, 0)) + n
		"supply_drop":
			var cat_v: Variant = e.get("category", "school")
			var idx: int = _place_of(s, cat_v if cat_v is Array else [str(cat_v)])
			if idx >= 0:
				var p: Dictionary = s.places[idx]
				var items: Dictionary = e.get("items", {})
				for k in items.keys():
					(p["stock"] as Dictionary)[k] = int((p["stock"] as Dictionary).get(k, 0)) + int(items[k])
				p["rumour"] = "Supply drop reported"
				s.say("good", "A supply drop is waiting at %s." % ShelterTrips.place_label(p))
		"reveal_cache":
			var cands: Array = []
			for p_v in s.places:
				if str((p_v as Dictionary)["category"]) in ["neighbor_house", "park", "church", "school"]:
					cands.append(p_v)
			if not cands.is_empty():
				var pc: Dictionary = cands[s.rng.randi_range(0, cands.size() - 1)]
				s.caches.append({"place_idx": int(pc["idx"]), "items": (e.get("items", {}) as Dictionary).duplicate()})
				pc["rumour"] = "Cache marked on the map"
				s.say("good", "A cache is marked near %s." % ShelterTrips.place_label(pc))
		"lose_run":
			ShelterSim.finish(s, str(e.get("ending", "loss_all_dead")))
			tags.append("gameover")
		"guilt":
			for m_v in _targets(s, who, ctx):
				var m: Dictionary = m_v
				m["guilt"] = true
				m["morale_cap"] = mini(int(m.get("morale_cap", 10)), ShelterData.Bi("guilt_morale_cap", 6))
				ShelterSim.add_morale(s, m, -2, "guilt")
				ShelterState.note_cause(m, s.day, "carries the guilt of %s" % str(e.get("why", "what they did")), "decision")
			s.harmed_innocents = s.harmed_innocents or bool(e.get("harm", false))
			if bool(e.get("harm", false)):
				s.stats["harmed"] = true
			if bool(e.get("stole", false)):
				s.stats["stole"] = int(s.stats["stole"]) + 1
		"flag":
			if e.has("set"):
				s.flags[str(e["set"])] = s.day
			if e.has("clear"):
				s.flags.erase(str(e["clear"]))
		"fallout_news":
			if s.day >= s.fallout_clear_day - 2:
				s.fallout_clear_day = mini(s.fallout_clear_day, s.day)
				s.fallout_announced = true
				s.fallout_known_day = s.day
				s.say("good", "The fallout is light enough to travel now.")
		"house_quiet":
			var hi: int = int(ctx.get("place_idx", -1))
			if hi < 0 or hi >= s.places.size() or str((s.places[hi] as Dictionary)["category"]) != "neighbor_house":
				hi = _place_of(s, ["neighbor_house"])
			if hi >= 0:
				(s.places[hi] as Dictionary)["quiet"] = true
				(s.places[hi] as Dictionary)["occupied"] = false
		"later":
			# Something the narrator brings up days later (a narration trigger, or plain text).
			var text: String = str(e.get("text", ""))
			if e.has("trigger"):
				var line: String = ShelterData.line_for(str(e["trigger"]), s.lines_used, s.rng)
				if line != "":
					text = line
			var qp: int = int(ctx.get("place_idx", -1)) if bool(e.get("quiet_place", false)) else -1
			s.later.append({"day": s.day + int(e.get("in", 3)), "kind": str(e.get("kind", "info")), "text": _fill(s, text, ctx), "quiet_place": qp})
		"trip_flag":
			for t_v in s.trips:
				var t: Dictionary = t_v
				if str(t["member"]) == str(ctx.get("explorer", "")):
					t[str(e.get("set", "flag"))] = true
		"rule":
			ShelterSim.adopt_rule(s, str(e.get("rule", "")))
			s.stats["meetings"] = int(s.stats["meetings"]) + 1
			tags.append("house_rule")
		"rule_declined":
			s.stats["meetings"] = int(s.stats["meetings"]) + 1
			s.stats["rules_declined"] = int(s.stats["rules_declined"]) + 1
		"end_run":
			ShelterSim.finish(s, str(e.get("ending", "maybe_walk_out")))
			tags.append("gameover")
		"junk":
			pass
		"say":
			s.say(str(e.get("kind", "info")), _fill(s, str(e.get("text", "")), ctx))
		"drain":
			var cats: Array = e.get("category", ["grocery", "pharmacy"])
			var share: float = float(e.get("share", 0.3))
			for p_v in s.places:
				var p: Dictionary = p_v
				if str(p["category"]) in cats:
					var stock: Dictionary = p["stock"]
					for k in stock.keys().duplicate():
						stock[k] = int(floor(float(int(stock[k])) * (1.0 - share)))
						if int(stock[k]) <= 0:
							stock.erase(k)
			s.say("warn", "Stores are being emptied faster now.", [])


static func _unit_name(it: String, n: int) -> String:
	if it == ShelterState.FOOD:
		return "can of food" if n == 1 else "cans of food"
	if it == ShelterState.WATER:
		return "bottle of water" if n == 1 else "bottles of water"
	return ShelterData.item_name(it) + ("" if n == 1 else "s")


## The item does its job, with the cost its row in items.csv describes.
static func _use_item(s: ShelterState, it: String, mode: String, what: String, ctx: Dictionary) -> void:
	var on_trip: bool = ctx.has("explorer") and str(ctx.get("explorer", "")) != ""
	match it:
		"rifle":
			if s.has("ammo"):
				s.remove("ammo", 1)
				s.credit("rifle", "%s (−1 ammo)" % what)
			elif s.rng.randf() < ShelterData.B("rifle_no_ammo_break_p", 0.5):
				_break_used(s, "rifle", on_trip, ctx)
				s.credit("rifle", "%s (no ammo; the rifle broke)" % what)
			else:
				s.credit("rifle", "%s (no ammo)" % what)
		"axe":
			if mode == "wear":
				s.wear["axe"] = int(s.wear.get("axe", 0)) + 1
				if int(s.wear["axe"]) >= ShelterData.Bi("axe_wear_max", 3):
					_break_used(s, "axe", on_trip, ctx)
					s.credit("axe", "%s (the axe broke)" % what)
				else:
					s.credit("axe", "%s (the axe took wear)" % what)
			else:
				_break_used(s, "axe", on_trip, ctx)
				s.credit("axe", "%s (the axe broke)" % what)
		"padlock", "bug_spray", "medkit":
			if on_trip:
				_take_trip_gear(s, it, ctx)
			else:
				s.remove(it, 1)
			s.credit(it, "%s (used up)" % what)
		"radio":
			if mode == "tinker" and s.rng.randf() < ShelterData.B("radio_tinker_break_p", 0.6):
				s.break_one("radio")
				s.credit("radio", "%s (the radio broke)" % what)
			else:
				s.credit("radio", what)
		"food", "water":
			s.remove(it, int(ShelterData.item_effect(it, "rations", 4.0)))
			s.credit(it, what)
		_:
			s.credit(it, what)


## An item carried on a trip breaks: it comes home broken (if it comes home at all).
static func _break_used(s: ShelterState, it: String, on_trip: bool, ctx: Dictionary) -> void:
	if not on_trip:
		s.break_one(it)
		return
	if _take_trip_gear(s, it, ctx):
		s.broken[it] = s.broken_count(it) + 1


static func _take_trip_gear(s: ShelterState, it: String, ctx: Dictionary) -> bool:
	for t_v in s.trips:
		var t: Dictionary = t_v
		if str(t["member"]) == str(ctx.get("explorer", "")) and (t["gear"] as Array).has(it):
			(t["gear"] as Array).erase(it)
			return true
	return false


## The manual repairs gear (85%; a Handy survivor does it with fewer mishaps).
static func _repair(s: ShelterState, which: String, tags: Array, handy: bool = false) -> void:
	var target: String = which
	if target == "" or target == "any":
		target = ""
		for r in REPAIRABLE_ORDER:
			if s.broken_count(r) > 0:
				target = r
				break
	if target == "" or s.broken_count(target) <= 0:
		s.say("info", "Nothing was broken, so the manual was just reading material.")
		return
	if target == "map":
		if s.rng.randf() < ShelterData.B("manual_map_repair_p", 0.5) + (0.15 if handy else 0.0):
			s.repair_one("map")
			s.stats["repairs"] = int(s.stats["repairs"]) + 1
			s.credit("manual", "the map was taped back together")
		else:
			s.discard_broken("map")
			s.remove("manual", 1)
			s.say("break", "The map tore apart, and the manual went with it into the mess.", ["map", "manual"])
		tags.append("item_repaired")
		return
	if s.rng.randf() < ShelterData.B("manual_repair_p", 0.85) + (0.1 if handy else 0.0):
		s.repair_one(target)
		s.stats["repairs"] = int(s.stats["repairs"]) + 1
		s.credit("manual", "repaired the %s" % ShelterData.item_name(target).to_lower())
		tags.append("item_repaired")
	else:
		s.say("info", "The repair didn't take. The %s is still broken." % ShelterData.item_name(target).to_lower(), [target])


# ---------------------------------------------------------------- text

static func _fill(s: ShelterState, text: String, ctx: Dictionary) -> String:
	var out: String = text
	if out.find("{") == -1:
		return out
	var a: Dictionary = s.member(str(ctx.get("actor", "")))
	var ex: Dictionary = s.member(str(ctx.get("explorer", "")))
	var sb: Dictionary = s.member(str(ctx.get("subject", "")))
	var nm: String = str(ex.get("name", a.get("name", "Someone"))) if not ex.is_empty() else str(a.get("name", "Someone"))
	out = out.replace("{name}", nm)
	out = out.replace("{subject}", str(sb.get("name", "someone")))
	out = out.replace("{n}", str(s.day))
	out = out.replace("{day}", str(s.day))
	out = out.replace("{home}", "home")
	if out.find("{place}") != -1:
		var pi: int = int(ctx.get("place_idx", -1))
		out = out.replace("{place}", ShelterTrips.place_label(s.places[pi]) if pi >= 0 else "the place")
	if out.find("{food_label}") != -1:
		var vars: Array = ShelterData.item("food").get("variants", ["beans"])
		out = out.replace("{food_label}", str(vars[s.rng.randi_range(0, vars.size() - 1)]))
	for pair in [["{nearest_school}", ["school"]], ["{nearest_pharmacy}", ["pharmacy"]], ["{nearest_grocery}", ["grocery"]],
			["{nearest_hardware}", ["hardware"]], ["{nearest_church}", ["church"]], ["{nearest_clinic}", ["pharmacy"]], ["{nearest_fuel}", ["auto"]]]:
		if out.find(str(pair[0])) != -1:
			var idx: int = _place_of(s, pair[1])
			out = out.replace(str(pair[0]), ShelterTrips.place_label(s.places[idx]) if idx >= 0 else "the " + ShelterTrips.category_word(str((pair[1] as Array)[0])))
	return out
