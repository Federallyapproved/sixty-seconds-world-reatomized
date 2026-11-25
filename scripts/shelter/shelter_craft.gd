class_name ShelterCraft
extends RefCounted

## Crafting and salvage (section 10). A small system that adds decisions, not chores:
## * junk (and broken gear) comes apart into six parts on a shelf that holds 12;
## * a survivor spends the day at the bench: two Quick recipes, or one Day recipe;
## * what comes out is Makeshift — weaker than the real thing, with a few uses, and never food,
##   water, a rescue signal or a way out (makeshift items can't meet rescue or ending conditions);
## * the manual's four chapters (Study, or a pamphlet found on a trip) unlock the rest.
## Like the other Shelter* modules this never touches the GameState autoload, so the game and
## the balance harness run the same rules.

const DEFENCE: Array[String] = ["door_barricade", "tin_can_alarm", "pipe_club"]


# ---------------------------------------------------------------- lookups

static func is_junk(item_id: String) -> bool:
	return str(ShelterData.item(item_id).get("category", "")) == "junk"


static func is_makeshift(item_id: String) -> bool:
	return str(ShelterData.item(item_id).get("category", "")) == "makeshift"


## Uses one makeshift item has when it is made (0: until it breaks).
static func max_uses(item_id: String) -> int:
	return int(ShelterData.item_effect(item_id, "uses", 0.0))


static func uses_left(s: ShelterState, item_id: String) -> int:
	var mx: int = max_uses(item_id)
	if mx <= 0:
		return 0
	return int(s.uses.get(item_id, mx))


static func scrap_yield(item_id: String) -> Dictionary:
	return (ShelterData.item(item_id).get("scrap", {}) as Dictionary)


## "a bedsheet", "an extension cord", "a roll of duct tape", "2 bedsheets" (for receipts).
static func a_name(item_id: String, n: int = 1) -> String:
	var nm: String = ShelterData.item_name(item_id).to_lower()
	var special: Dictionary = {"duct_tape": "a roll of duct tape", "pots_pans": "pots and pans", "sanitizer": "a bottle of hand sanitizer"}
	if n > 1:
		return "%d × %s" % [n, nm]
	if special.has(item_id):
		return str(special[item_id])
	return ("an " if nm.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + nm


static func part_name(part_id: String) -> String:
	return str(ShelterData.part(part_id).get("name", part_id.capitalize()))


## "2 Metal, 1 Electronics"
static func parts_text(parts: Dictionary) -> String:
	var bits: Array[String] = []
	for pid in ShelterData.part_ids():
		if int(parts.get(pid, 0)) > 0:
			bits.append("%d %s" % [int(parts[pid]), part_name(pid)])
	return ", ".join(bits) if not bits.is_empty() else "nothing"


## Recipes in the order the bench shows them: known first, then by chapter.
static func recipe_ids() -> Array:
	var ids: Array = ShelterData.recipes().keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ua: String = str(ShelterData.recipe(str(a)).get("unlock", "known"))
		var ub: String = str(ShelterData.recipe(str(b)).get("unlock", "known"))
		var oa: int = 0 if ua == "known" else int(ShelterData.chapter(ua).get("order", 9))
		var ob: int = 0 if ub == "known" else int(ShelterData.chapter(ub).get("order", 9))
		if oa != ob:
			return oa < ob
		return str(a) < str(b))
	return ids


static func chapter_ids() -> Array:
	var ids: Array = ShelterData.chapters().keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(ShelterData.chapter(str(a)).get("order", 0)) < int(ShelterData.chapter(str(b)).get("order", 0)))
	return ids


static func known(s: ShelterState, rid: String) -> bool:
	var u: String = str(ShelterData.recipe(rid).get("unlock", "known"))
	return u == "known" or s.chapters.has(u)


## "Manual Ch.2 / home-security flyer" — where a locked recipe comes from.
static func unlock_label(rid: String) -> String:
	var u: String = str(ShelterData.recipe(rid).get("unlock", "known"))
	if u == "known":
		return "Known"
	var ch: Dictionary = ShelterData.chapter(u)
	var flyer: String = str(ch.get("pamphlet", "")).trim_prefix("a ").trim_prefix("an ")
	return "Manual Ch.%d / %s" % [int(ch.get("order", 0)), flyer]


static func chapter_recipes(ch: String) -> Array[String]:
	var out: Array[String] = []
	for rid in recipe_ids():
		if str(ShelterData.recipe(str(rid)).get("unlock", "")) == ch:
			out.append(str(ShelterData.recipe(str(rid)).get("name", rid)))
	return out


## Place types whose junk supplies a part ("hardware store, neighbours' houses").
static func part_sources(part_id: String) -> Array[String]:
	var out: Array[String] = []
	var loot: Dictionary = ShelterData.loot()
	var types: Array = loot.keys()
	types.sort()
	for pt in types:
		if str(pt) == "home":
			continue
		for iid in (loot[pt] as Dictionary).keys():
			if is_junk(str(iid)) and scrap_yield(str(iid)).has(part_id):
				out.append(str(pt))
				break
	return out


static func place_type_word(pt: String) -> String:
	match pt:
		"electronics":
			return "phone shops"
		"neighbor_house":
			return "neighbours' houses"
		"grocery":
			return "supermarkets"
		"pharmacy":
			return "pharmacies"
		"hardware":
			return "hardware stores"
		"auto":
			return "gas stations"
		"restaurant":
			return "restaurants"
		"civic":
			return "station houses"
		"church":
			return "churches"
		"home":
			return "the house"
	return pt + "s"


# ---------------------------------------------------------------- the part shelf

static func parts_total(s: ShelterState) -> int:
	var n: int = 0
	for k in s.parts.keys():
		n += int(s.parts[k])
	return n


static func shelf_room(s: ShelterState) -> int:
	return maxi(0, ShelterData.Bi("part_shelf_max", 12) - parts_total(s))


## Puts parts on the shelf; what doesn't fit is thrown out. Returns {"kept": {}, "lost": {}}.
static func add_parts(s: ShelterState, got: Dictionary) -> Dictionary:
	var kept: Dictionary = {}
	var lost: Dictionary = {}
	for pid in ShelterData.part_ids():
		var n: int = int(got.get(pid, 0))
		if n <= 0:
			continue
		var fit: int = mini(n, shelf_room(s))
		if fit > 0:
			s.parts[pid] = int(s.parts.get(pid, 0)) + fit
			kept[pid] = fit
		if n > fit:
			lost[pid] = n - fit
			s.stats["parts_lost"] = int(s.stats["parts_lost"]) + n - fit
	return {"kept": kept, "lost": lost}


## Everything that could become parts today: the shelf plus every piece of junk.
static func parts_reachable(s: ShelterState) -> Dictionary:
	var have: Dictionary = s.parts.duplicate()
	for iid in s.stock.keys():
		if not is_junk(str(iid)):
			continue
		var y: Dictionary = scrap_yield(str(iid))
		for pid in y.keys():
			have[pid] = int(have.get(pid, 0)) + int(y[pid]) * s.count(str(iid))
	return have


## Junk (from the shelf) and broken gear that can be taken apart, with what each gives.
static func salvage_list(s: ShelterState) -> Array:
	var out: Array = []
	var ids: Array = s.stock.keys()
	ids.sort()
	for iid in ids:
		if is_junk(str(iid)) and s.count(str(iid)) > 0:
			out.append({"item": str(iid), "broken": false, "count": s.count(str(iid)), "yield": scrap_yield(str(iid))})
	var bids: Array = s.broken.keys()
	bids.sort()
	for iid in bids:
		if s.broken_count(str(iid)) > 0 and not scrap_yield(str(iid)).is_empty():
			out.append({"item": str(iid), "broken": true, "count": s.broken_count(str(iid)), "yield": scrap_yield(str(iid))})
	return out


## Takes one piece of junk (or one broken item) apart. Free and instant: it is the bench's
## part of the shelf, not a job. Returns {"ok", "kept", "lost"}.
static func take_apart(s: ShelterState, item_id: String, broken: bool = false, quiet: bool = false) -> Dictionary:
	var y: Dictionary = scrap_yield(item_id)
	if y.is_empty():
		return {"ok": false}
	if broken:
		if s.broken_count(item_id) <= 0:
			return {"ok": false}
		s.discard_broken(item_id)
	else:
		if not is_junk(item_id) or s.remove(item_id, 1) != 1:
			return {"ok": false}
	s.stats["taken_apart"] = int(s.stats["taken_apart"]) + 1
	var res: Dictionary = add_parts(s, y)
	res["ok"] = true
	if not quiet:
		var txt: String = "Took apart the %s%s: %s." % ["broken " if broken else "", ShelterData.item_name(item_id).to_lower(), parts_text(res["kept"])]
		if not (res["lost"] as Dictionary).is_empty():
			txt += " No room on the shelf for %s." % parts_text(res["lost"])
		s.say("craft", txt, [item_id])
	return res


# ---------------------------------------------------------------- recipes

## The part a Patch Job needs for this broken item: the one it scraps into that is easiest to get.
static func match_part(s: ShelterState, target: String) -> String:
	var y: Dictionary = scrap_yield(target)
	var have: Dictionary = parts_reachable(s)
	var best: String = ""
	for pid in ShelterData.part_ids():
		if y.has(pid) and (best == "" or int(have.get(pid, 0)) > int(have.get(best, 0))):
			best = pid
	return best


## Broken items a Patch Job could get working again (they need a part to match).
static func patch_targets(s: ShelterState) -> Array[String]:
	var out: Array[String] = []
	for iid in ShelterEvents.REPAIRABLE_ORDER:
		if s.broken_count(iid) > 0 and not scrap_yield(iid).is_empty():
			out.append(iid)
	return out


## Concrete parts a recipe needs ("match" resolved against the patch target).
static func parts_needed(s: ShelterState, rid: String, target: String = "") -> Dictionary:
	var need: Dictionary = {}
	var r: Dictionary = ShelterData.recipe(rid)
	for k in (r.get("parts", {}) as Dictionary).keys():
		var n: int = int((r["parts"] as Dictionary)[k])
		var pid: String = str(k)
		if pid == "match":
			var t: String = target if target != "" else (patch_targets(s)[0] if not patch_targets(s).is_empty() else "")
			pid = match_part(s, t) if t != "" else ""
			if pid == "":
				continue
		need[pid] = int(need.get(pid, 0)) + n
	return need


## Parts still missing after the shelf and every piece of junk: {part: short}.
static func short_by(s: ShelterState, need: Dictionary) -> Dictionary:
	var have: Dictionary = parts_reachable(s)
	var short: Dictionary = {}
	for pid in need.keys():
		var m: int = int(need[pid]) - int(have.get(pid, 0))
		if m > 0:
			short[pid] = m
	return short


static func short_count(short: Dictionary) -> int:
	var n: int = 0
	for k in short.keys():
		n += int(short[k])
	return n


## Junk to take apart to cover what the shelf lacks, wasting as little as possible.
static func junk_plan(s: ShelterState, need: Dictionary) -> Array[String]:
	var gap: Dictionary = {}
	for pid in need.keys():
		var m: int = int(need[pid]) - int(s.parts.get(pid, 0))
		if m > 0:
			gap[pid] = m
	var pool: Dictionary = {}
	for iid in s.stock.keys():
		if is_junk(str(iid)):
			pool[str(iid)] = s.count(str(iid))
	var plan: Array[String] = []
	while not gap.is_empty():
		var best: String = ""
		var best_score: float = -INF
		var keys: Array = pool.keys()
		keys.sort()
		for jid in keys:
			if int(pool[jid]) <= 0:
				continue
			var y: Dictionary = scrap_yield(str(jid))
			var useful: int = 0
			var waste: int = 0
			for pid in y.keys():
				var u: int = mini(int(y[pid]), int(gap.get(pid, 0)))
				useful += u
				waste += int(y[pid]) - u
			if useful <= 0:
				continue
			var score: float = float(useful) - 0.4 * float(waste)
			if score > best_score:
				best_score = score
				best = str(jid)
		if best == "":
			break
		plan.append(best)
		pool[best] = int(pool[best]) - 1
		var yb: Dictionary = scrap_yield(best)
		for pid in yb.keys():
			if gap.has(pid):
				gap[pid] = int(gap[pid]) - int(yb[pid])
				if int(gap[pid]) <= 0:
					gap.erase(pid)
	return plan


## Chance a craft fails: 20%, 5% with the manual in the shelter, +15% injured or sick.
static func fail_chance(s: ShelterState, m: Dictionary) -> float:
	var f: float = ShelterData.B("craft_fail_manual_p", 0.05) if s.has("manual") else ShelterData.B("craft_fail_p", 0.2)
	if bool(m.get("sick", false)) or bool(m.get("injured", false)):
		f += ShelterData.B("craft_fail_unwell_add", 0.15)
	if str(m.get("trait", "")) == "handy":
		f += ShelterData.B("craft_fail_handy_add", -0.03)
	return clampf(f, 0.0, 0.9)


## Who may work at the bench today (the reason is shown on the job button).
static func can_work(s: ShelterState, m: Dictionary) -> String:
	if not bool(m.get("alive", false)) or str(m.get("loc", "")) != "shelter":
		return "not in the shelter"
	if ShelterState.affliction(m) == "withdrawn" and not s.has_rule("work_or_dont_eat"):
		return "Withdrawn: won't work"
	return ""


## "" if this survivor can make this recipe now, else why not. `planned` lists the recipes
## already on their bench today (two Quick, or one Day).
static func can_make(s: ShelterState, m: Dictionary, rid: String, target: String = "", planned: Array = []) -> String:
	var r: Dictionary = ShelterData.recipe(rid)
	if r.is_empty():
		return "no such recipe"
	var w: String = can_work(s, m)
	if w != "":
		return w
	if not known(s, rid):
		return "Not learned: " + unlock_label(rid)
	var day: bool = str(r.get("time", "quick")) == "day"
	if day and ShelterState.is_child(m):
		return "Too young for a whole day's work"
	for pr_v in planned:
		var pr: String = str((pr_v as Dictionary).get("id", "")) if pr_v is Dictionary else str(pr_v)
		if day or str(ShelterData.recipe(pr).get("time", "quick")) == "day":
			return "A Day recipe takes the whole day"
	if planned.size() >= ShelterData.Bi("quick_per_day", 2):
		return "Two Quick recipes a day"
	var tool: String = str(r.get("tool", ""))
	if tool != "" and not s.has(tool):
		return "Needs the %s" % ShelterData.item_name(tool).to_lower()
	var makes: String = str(r.get("makes", ""))
	if makes == "patch":
		var t: String = target if target != "" else (patch_targets(s)[0] if not patch_targets(s).is_empty() else "")
		if t == "" or s.broken_count(t) <= 0:
			return "Nothing broken to patch"
	elif makes in DEFENCE and s.count(makes) > 0:
		return "One %s is already up" % ShelterData.item_name(makes).to_lower()
	var need: Dictionary = parts_needed(s, rid, target)
	# Parts already promised to the recipes before this one on the same bench.
	for pr_v in planned:
		var pr2: String = str((pr_v as Dictionary).get("id", "")) if pr_v is Dictionary else str(pr_v)
		var t2: String = str((pr_v as Dictionary).get("target", "")) if pr_v is Dictionary else ""
		var n2: Dictionary = parts_needed(s, pr2, t2)
		for pid in n2.keys():
			need[pid] = int(need.get(pid, 0)) + int(n2[pid])
	var short: Dictionary = short_by(s, need)
	if not short.is_empty():
		return "Short: " + parts_text(short)
	return ""


## Makes one recipe at night (called from the day's jobs). Takes junk apart as needed, rolls the
## failure chance, and puts the makeshift item on the shelf. Returns {"ok", "failed", "item"}.
static func craft(s: ShelterState, m: Dictionary, rid: String, target: String = "") -> Dictionary:
	var r: Dictionary = ShelterData.recipe(rid)
	var who: String = str(m.get("name", "Someone"))
	var why: String = can_make(s, m, rid, target)
	if why != "":
		s.say("info", "%s couldn't make the %s: %s." % [who, str(r.get("name", rid)), why.to_lower()], [], str(m.get("id", "")))
		return {"ok": false, "failed": false}
	if str(r.get("makes", "")) == "patch" and target == "":
		target = patch_targets(s)[0]
	var need: Dictionary = parts_needed(s, rid, target)
	for jid in junk_plan(s, need):
		take_apart(s, jid, false, true)
	for pid in need.keys():
		s.parts[pid] = int(s.parts.get(pid, 0)) - int(need[pid])
		if int(s.parts[pid]) <= 0:
			s.parts.erase(pid)
	# The axe is a tool here, never used up, but a whole day's work wears it.
	var tool: String = str(r.get("tool", ""))
	var tool_txt: String = ""
	if tool == "axe" and str(r.get("time", "")) == "day":
		s.wear["axe"] = int(s.wear.get("axe", 0)) + 1
		if int(s.wear["axe"]) >= ShelterData.Bi("axe_wear_max", 3):
			s.break_one("axe")
			tool_txt = " The axe broke on the last cut."
		else:
			tool_txt = " The axe took wear."
	var name: String = str(r.get("name", rid))
	if s.rng.randf() < fail_chance(s, m):
		var total: int = 0
		for pid in need.keys():
			total += int(need[pid])
		var back: Dictionary = {}
		var left: int = total / 2
		var order: Array = need.keys()
		order.sort_custom(func(a: Variant, b: Variant) -> bool: return int(need[a]) > int(need[b]))
		while left > 0:
			var moved: bool = false
			for pid in order:
				if left <= 0:
					break
				if int(back.get(pid, 0)) < int(need[pid]):
					back[pid] = int(back.get(pid, 0)) + 1
					left -= 1
					moved = true
			if not moved:
				break
		var kept: Dictionary = add_parts(s, back)["kept"]
		s.stats["craft_fails"] = int(s.stats["craft_fails"]) + 1
		s.say("break", "%s's %s fell apart on the bench. %s went back on the shelf.%s" % [who, name, parts_text(kept) if not kept.is_empty() else "Nothing", tool_txt], [], str(m.get("id", "")))
		return {"ok": false, "failed": true}
	var crafted: Dictionary = s.stats["crafted"]
	crafted[rid] = int(crafted.get(rid, 0)) + 1
	var makes: String = str(r.get("makes", ""))
	if makes == "patch":
		s.repair_one(target)
		s.patched[target] = true
		s.stats["patches"] = int(s.stats["patches"]) + 1
		s.say("craft", "%s patched the %s with tape and %s: good for one more use.%s" % [who, ShelterData.item_name(target).to_lower(), parts_text(need).to_lower(), tool_txt], [target], str(m.get("id", "")))
		return {"ok": true, "failed": false, "item": target}
	if s.count(makes) == 0:
		s.uses.erase(makes)
	s.add(makes, 1)
	s.say("craft", "%s made a %s at the bench.%s" % [who, ShelterData.item_name(makes).to_lower(), tool_txt], [makes], str(m.get("id", "")))
	return {"ok": true, "failed": false, "item": makes}


# ---------------------------------------------------------------- learning

## Why this survivor can't study tonight ("" if they can).
static func can_study(s: ShelterState, m: Dictionary, ch: String = "") -> String:
	var w: String = can_work(s, m)
	if w != "":
		return w
	if ShelterState.is_child(m):
		return "Too young to study the manual"
	if not s.has("manual"):
		return "Needs the manual"
	if ch != "" and s.chapters.has(ch):
		return "Already learned"
	if next_chapters(s).is_empty():
		return "Every chapter learned"
	return ""


static func next_chapters(s: ShelterState) -> Array:
	var out: Array = []
	for ch in chapter_ids():
		if not s.chapters.has(str(ch)):
			out.append(str(ch))
	return out


static func learn(s: ShelterState, ch: String, source: String) -> void:
	if s.chapters.has(ch) or ShelterData.chapter(ch).is_empty():
		return
	s.chapters[ch] = source
	var c: Dictionary = ShelterData.chapter(ch)
	var names: Array[String] = chapter_recipes(ch)
	s.say("craft", "Manual Ch.%d, %s: %s %s learned." % [int(c.get("order", 0)), str(c.get("title", "")), ", ".join(names), "is" if names.size() == 1 else "are"], ["manual"])


## A day with the manual: one chapter for the rest of the run.
static func study(s: ShelterState, m: Dictionary, ch: String) -> bool:
	if ch == "" and not next_chapters(s).is_empty():
		ch = str(next_chapters(s)[0])
	var why: String = can_study(s, m, ch)
	if why != "":
		s.say("info", "%s couldn't study: %s." % [str(m.get("name", "")), why.to_lower()], [], str(m.get("id", "")))
		return false
	s.stats["studied"] = int(s.stats["studied"]) + 1
	s.credit("manual", "%s learned Ch.%d, %s" % [str(m.get("name", "")), int(ShelterData.chapter(ch).get("order", 0)), str(ShelterData.chapter(ch).get("title", ""))])
	learn(s, ch, "manual")
	return true


## A place's pamphlet, picked once per place from manual_chapters.csv (deterministic per building).
static func pamphlet_for(p: Dictionary) -> String:
	var types: Array = [str(p.get("category", "")), str(p.get("loot_type", ""))]
	for ch in chapter_ids():
		var c: Dictionary = ShelterData.chapter(str(ch))
		for pt in c.get("pamphlet_places", []):
			if str(pt) in types:
				var key: String = "%s#%s#%.5f,%.5f" % [str(p.get("osm_id", 0)), str(ch), float(p.get("lat", 0.0)), float(p.get("lon", 0.0))]
				if float(abs(hash(key)) % 1000) / 1000.0 < ShelterData.B("pamphlet_chance", 0.5):
					return str(ch)
	return ""


## The explorer brings home the place's pamphlet: a chapter, or (already known) one random part.
static func found_pamphlet(s: ShelterState, p: Dictionary, m: Dictionary) -> void:
	var ch: String = str(p.get("pamphlet", ""))
	if ch == "":
		return
	p["pamphlet"] = ""
	var c: Dictionary = ShelterData.chapter(ch)
	s.stats["pamphlets"] = int(s.stats["pamphlets"]) + 1
	if not s.chapters.has(ch):
		s.stats["pamphlet_learned"] = int(s.stats["pamphlet_learned"]) + 1
		s.say("gain", "%s brought back %s from %s." % [str(m.get("name", "")), str(c.get("pamphlet", "a pamphlet")), ShelterTrips.place_label(p)], ["manual"], str(m.get("id", "")))
		learn(s, ch, "pamphlet")
	else:
		var ids: Array[String] = ShelterData.part_ids()
		var pid: String = ids[s.rng.randi_range(0, ids.size() - 1)]
		var kept: Dictionary = add_parts(s, {pid: 1})["kept"]
		s.say("gain", "%s found %s they already knew. It went in the part box%s." % [str(m.get("name", "")), str(c.get("pamphlet", "a pamphlet")), (" as 1 " + part_name(pid)) if not kept.is_empty() else ", which was full"], [], str(m.get("id", "")))


# ---------------------------------------------------------------- using makeshift items

## Spends one use of a makeshift item on the shelf. Returns true when it is used up (gone).
static func spend_use(s: ShelterState, item_id: String) -> bool:
	var mx: int = max_uses(item_id)
	if mx <= 0:
		return false
	var left: int = uses_left(s, item_id) - 1
	if left <= 0:
		s.remove(item_id, 1)
		s.uses.erase(item_id)
		return true
	s.uses[item_id] = left
	return false


## The makeshift item breaks or wears out now (or is used once more).
static func used_text(item_id: String, gone: bool) -> String:
	if not gone:
		return ""
	match item_id:
		"door_barricade":
			return " Barricade destroyed."
		"pipe_club":
			return " The pipe club broke."
	return " %s used up." % ShelterData.item_name(item_id)


## Rag bandage: closes a wound (injured only; it does nothing for a fever).
static func bandage(s: ShelterState, m: Dictionary) -> bool:
	if not s.has("rag_bandage") or not bool(m.get("injured", false)):
		return false
	var gone: bool = spend_use(s, "rag_bandage")
	m["injured"] = false
	m["injured_days"] = 0
	s.credit("rag_bandage", "closed %s's wound%s%s" % [str(m.get("name", "")), " (the fever stays)" if bool(m.get("sick", false)) else "", "." + used_text("rag_bandage", gone) if gone else ""])
	return true


## A raid at the hatch: the barricade goes first (60%, then it breaks); returns true if it held.
static func barricade_holds(s: ShelterState) -> bool:
	if not s.has("door_barricade"):
		return false
	s.remove("door_barricade", 1)
	s.uses.erase("door_barricade")
	if s.rng.randf() < ShelterData.B("barricade_stop_p", 0.6):
		s.credit("door_barricade", "held the door. Barricade destroyed.")
		return true
	s.say("break", "The door barricade gave way. Barricade destroyed.", ["door_barricade"])
	return false


## An adult swings the pipe club: 50% the raid is stopped; 50% the club breaks either way.
static func club_stops(s: ShelterState) -> bool:
	if not s.has("pipe_club"):
		return false
	var stopped: bool = s.rng.randf() < ShelterData.B("pipe_club_stop_p", 0.5)
	var broke: bool = s.rng.randf() < ShelterData.B("pipe_club_break_p", 0.5)
	if broke:
		s.remove("pipe_club", 1)
	if stopped:
		s.credit("pipe_club", "raid stopped%s" % ("." + used_text("pipe_club", true) if broke else ""))
	else:
		s.say("break", "The pipe club didn't stop them.%s" % used_text("pipe_club", broke), ["pipe_club"])
	return stopped


# ---------------------------------------------------------------- the night

## What crafting adds to a night: rain in the bucket, the filter, the puppet show, night thieves.
static func night(s: ShelterState) -> void:
	_rain(s)
	_filter(s)
	_puppets(s)
	_thief(s)


static func _rain(s: ShelterState) -> void:
	if s.rng.randf() >= ShelterData.B("rain_night_p", 0.12):
		return
	var n: int = ShelterData.Bi("rain_dirty_rations", 2)
	s.dirty_water += n
	s.stats["dirty_collected"] = int(s.stats["dirty_collected"]) + n
	s.say("info", "It rained in the night. The bucket under the vent caught %d rations of dirty water." % n, ["water"])


static func _filter(s: ShelterState) -> void:
	if s.dirty_water <= 0 or not s.has("bottle_filter"):
		return
	var n: int = mini(s.dirty_water, ShelterData.Bi("filter_jug_rations", 4))
	s.dirty_water -= n
	s.add(ShelterState.WATER, n)
	s.stats["filtered"] = int(s.stats["filtered"]) + n
	var gone: bool = spend_use(s, "bottle_filter")
	s.credit("bottle_filter", "%d rations of dirty water made drinkable.%s" % [n, used_text("bottle_filter", gone)])


static func _puppets(s: ShelterState) -> void:
	if not s.has("sock_puppets"):
		return
	var low: bool = false
	for m_v in s.home():
		if int((m_v as Dictionary).get("morale", 5)) <= 4:
			low = true
	if not low:
		return
	for m_v in s.home():
		ShelterSim.add_morale(s, m_v as Dictionary, int(ShelterData.item_effect("sock_puppets", "morale_all", 1.0)), "")
	var gone: bool = spend_use(s, "sock_puppets")
	s.credit("sock_puppets", "the sock puppet show: +1 morale for everyone.%s" % used_text("sock_puppets", gone))


## A night thief (not on a raid night): takes a little in silence, unless the tin cans rattle.
static func _thief(s: ShelterState) -> void:
	if s.day < ShelterData.Bi("thief_min_day", 6) or s.home().is_empty() or int(s.flags.get("raided", -1)) == s.day:
		return
	var p: float = ShelterData.B("thief_night_p", 0.05) * (ShelterData.B("thief_followed_mult", 2.0) if s.followed else 1.0)
	if s.rng.randf() >= p:
		return
	if s.has("tin_can_alarm") and not ShelterData.event("cans_rattled").is_empty():
		var gone: bool = spend_use(s, "tin_can_alarm")
		s.stats["alarms"] = int(s.stats["alarms"]) + 1
		s.scheduled.append({"event": "cans_rattled", "day": s.day + 1})
		s.used_events.erase("cans_rattled")
		s.credit("tin_can_alarm", "woke the shelter before the thief got far.%s" % used_text("tin_can_alarm", gone))
		return
	var what: String = _quiet_take(s)
	if what == "":
		return
	s.stats["thefts"] = int(s.stats["thefts"]) + 1
	s.say("lost", "Something went missing in the night: %s. Nobody heard a thing." % what, [])


## What a quiet thief can carry up the ladder: a few rations of food (cans first, water if there's
## no food), or one small thing off the shelf.
static func _quiet_take(s: ShelterState) -> String:
	var n: int = ShelterData.Bi("thief_rations", 2)
	var kind: String = ShelterState.FOOD if s.food() > 0 else ShelterState.WATER
	if s.count(kind) > 0:
		var got: int = s.remove(kind, n)
		return "%d %s ration%s" % [got, kind, "" if got == 1 else "s"]
	var pool: Array[String] = []
	for k in s.stock.keys():
		if str(k) != "radio" and s.count(str(k)) > 0 and ShelterData.item_slots(str(k)) == 1:
			pool.append(str(k))
	pool.sort()
	if pool.is_empty():
		return ""
	var pick: String = pool[s.rng.randi_range(0, pool.size() - 1)]
	s.remove(pick, 1)
	return "the " + ShelterData.item_name(pick).to_lower()


# ---------------------------------------------------------------- end of run

## "Made: Rag Bandage ×2, Door Barricade · 7 junk taken apart · 1 fell apart" ("" if the bench
## was never used).
static func run_summary(s: ShelterState) -> String:
	var made: Dictionary = s.stats["crafted"]
	var bits: Array[String] = []
	var names: Array[String] = []
	var ids: Array = made.keys()
	ids.sort()
	for rid in ids:
		var n: int = int(made[rid])
		var nm: String = str(ShelterData.recipe(str(rid)).get("name", rid))
		names.append(nm + (" ×%d" % n if n > 1 else ""))
	if not names.is_empty():
		bits.append("made " + ", ".join(names))
	if int(s.stats["taken_apart"]) > 0:
		bits.append("%d taken apart" % int(s.stats["taken_apart"]))
	if int(s.stats["craft_fails"]) > 0:
		bits.append("%d fell apart on the bench" % int(s.stats["craft_fails"]))
	if not s.chapters.is_empty():
		bits.append("learned %d of %d manual chapters" % [s.chapters.size(), ShelterData.chapters().size()])
	if bits.is_empty():
		return ""
	var t: String = "; ".join(bits)
	return t.substr(0, 1).to_upper() + t.substr(1) + "."


# ---------------------------------------------------------------- the Need toggle

## Tags (or untags) the parts a recipe is short of: junk holding them is looted first and
## highlighted in the house and in stores.
static func toggle_need(s: ShelterState, rid: String) -> bool:
	var need: Dictionary = parts_needed(s, rid)
	var short: Dictionary = short_by(s, need)
	var keys: Array = short.keys() if not short.is_empty() else need.keys()
	var on: bool = false
	for pid in keys:
		if not s.need_parts.has(pid):
			on = true
	for pid in keys:
		if on:
			s.need_parts[pid] = true
		else:
			s.need_parts.erase(pid)
	return on


## Junk ids holding a tagged part (in loot priority order).
static func needed_junk(need_parts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if need_parts.is_empty():
		return out
	for iid in ShelterData.ids_in("junk"):
		for pid in scrap_yield(iid).keys():
			if need_parts.has(pid):
				out.append(iid)
				break
	return out


static func junk_matches_need(item_id: String, need_parts: Dictionary) -> bool:
	if not is_junk(item_id):
		return false
	for pid in scrap_yield(item_id).keys():
		if need_parts.has(pid):
			return true
	return false
