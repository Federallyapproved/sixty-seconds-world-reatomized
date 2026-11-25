class_name SimPolicies
extends RefCounted

## Three ways to play the shelter phase for the balance harness (section 6):
## * random — coin flips for rations, a random option for every dilemma, the odd random trip;
## * naive  — feeds everyone every 5 days, always uses an item when an event offers one, goes to
##            the nearest store when the shelf runs low;
## * expert — rations to the thresholds, scores every option by its effects, plans trips by
##            loot, risk and need, keeps the rescue items working.
## Policies only read what the player can see (stock, statuses, the risk preview), never the
## random numbers.

const ITEM_VALUE: Dictionary = {
	"food": 5.0, "water": 6.0, "medkit": 9.0, "gas_mask": 7.0, "radio": 9.0, "map": 7.0, "flashlight": 6.0,
	"padlock": 6.0, "rifle": 7.0, "ammo": 2.0, "axe": 5.0, "suitcase": 5.0, "manual": 4.0, "bug_spray": 2.0,
	"cards": 2.0, "console": 2.0,
}
const EXPERT_GRAB: Array[String] = [
	"water", "water", "food", "suitcase", "water", "medkit", "radio", "gas_mask", "map", "flashlight", "food", "water",
	"padlock", "food", "rifle", "ammo", "axe", "manual", "water", "food", "bug_spray", "cards", "console",
]


static func default_family() -> Array:
	return [
		{"id": "m0", "name": "Sam", "role": "adult", "age": 42, "is_leader": true, "trait": "handy", "in_bunker": true, "alive": true},
		{"id": "m1", "name": "Priya", "role": "adult", "age": 39, "is_leader": false, "trait": "optimist", "in_bunker": true, "alive": true},
		{"id": "m2", "name": "Maya", "role": "teen", "age": 16, "is_leader": false, "trait": "bookworm", "in_bunker": true, "alive": true},
		{"id": "m3", "name": "Leo", "role": "child", "age": 9, "is_leader": false, "trait": "scout", "in_bunker": true, "alive": true},
	]


static func grab_budget(difficulty: String) -> int:
	return ShelterData.Bi("grab_budget_" + difficulty, 12)


## What ends up on the shelf after the 60 seconds, from the house's spawn table.
static func grab(policy: String, rng: RandomNumberGenerator, budget: int) -> Dictionary:
	var spawn: Array[String] = []
	var table: Dictionary = ShelterData.loot_for("home")
	var keys: Array = table.keys()
	keys.sort()
	for k in keys:
		var row: Dictionary = table[k]
		if rng.randf() > float(row["chance"]):
			continue
		for _i in range(rng.randi_range(int(row["min"]), int(row["max"]))):
			spawn.append(str(k))
	var order: Array[String] = []
	match policy:
		"random":
			order = spawn.duplicate()
			_shuffle(order, rng)
		"naive":
			var rest: Array[String] = []
			for it in spawn:
				if it == "food" or it == "water":
					order.append(it)
				else:
					rest.append(it)
			_shuffle(rest, rng)
			order.append_array(rest)
		_:
			var pool: Array[String] = spawn.duplicate()
			for want in EXPERT_GRAB:
				var i: int = pool.find(want)
				if i >= 0:
					order.append(want)
					pool.remove_at(i)
			order.append_array(pool)
	var haul: Dictionary = {}
	var left: int = budget
	for it in order:
		var cost: int = ShelterData.item_slots(it)
		if cost > left:
			continue
		left -= cost
		haul[it] = int(haul.get(it, 0)) + 1
	return haul


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t


# ---------------------------------------------------------------- dilemmas

static func pick_option(s: ShelterState, policy: String, rng: RandomNumberGenerator) -> String:
	var avail: Array = []
	for o_v in s.today_options:
		if bool((o_v as Dictionary)["available"]):
			avail.append(o_v)
	if avail.is_empty():
		return ""
	match policy:
		"random":
			return str((avail[rng.randi_range(0, avail.size() - 1)] as Dictionary)["id"])
		"naive":
			for o_v in avail:
				if str((o_v as Dictionary)["item"]) != "":
					return str((o_v as Dictionary)["id"])
			return str((avail[0] as Dictionary)["id"])
	var best: String = ""
	var best_v: float = -INF
	for o_v in avail:
		var o: Dictionary = o_v
		var src: Dictionary = {}
		for so in s.today_event.get("options", []):
			if str((so as Dictionary)["id"]) == str(o["id"]):
				src = so
		var v: float = score_effects(s, src.get("effects", []), s.today_event.get("ctx", {}))
		if v > best_v:
			best_v = v
			best = str(o["id"])
	return best


static func _need_mult(s: ShelterState, item: String) -> float:
	var people: float = maxf(1.0, float(s.living().size()))
	if item == "water":
		var wd: float = float(s.water()) / people
		return 2.5 if wd < 2.0 else (1.6 if wd < 4.0 else 1.0)
	if item == "food":
		var fd: float = float(s.food()) / people
		return 2.5 if fd < 1.5 else (1.5 if fd < 3.0 else 1.0)
	if item in ["padlock", "rifle", "axe"] and s.followed and not s.has("padlock") and not s.has("rifle") and not s.has("axe"):
		return 3.0
	if item in ["rifle", "axe"] and s.followed and not s.has("rifle") and not s.has("axe"):
		return 2.5
	if item == "medkit" and s.count("medkit") < 2:
		return 1.8   # keep a spare: untreated sickness is the slowest, surest killer
	if s.owns(item) and not (item in ["medkit", "ammo", "food", "water"]):
		return 0.3
	return 1.0


static func _n_targets(s: ShelterState, who: String) -> float:
	return float(s.home().size()) if who == "all" else 1.0


static func score_effects(s: ShelterState, effs: Array, ctx: Dictionary) -> float:
	var v: float = 0.0
	for e_v in effs:
		var e: Dictionary = e_v
		var op: String = str(e.get("do", ""))
		var it: String = str(e.get("item", ""))
		var n: float = float(e.get("n", 1))
		var who: String = str(e.get("who", "actor"))
		match op:
			"add", "trip_loot":
				v += float(ITEM_VALUE.get(it, 2.0)) * n * _need_mult(s, it)
			"lose":
				v -= float(ITEM_VALUE.get(it, 2.0)) * n * _need_mult(s, it)
			"rations":
				var rk: String = str(e.get("kind", "food"))
				v += n * float(ITEM_VALUE.get(rk, 5.0)) / 4.0 * (_need_mult(s, rk) if n < 0 else 1.0)
			"use":
				v -= _use_cost(s, it, str(e.get("mode", "")))
			"give":
				v -= float(ITEM_VALUE.get(it, 2.0))
			"break":
				v -= float(ITEM_VALUE.get(it, 2.0)) * 0.7
			"break_fragile":
				v -= float(e.get("p", 0.4)) * 6.0
			"repair":
				v += 4.0
			"sick":
				v -= (9.0 if s.has("medkit") else 25.0) * _n_targets(s, who)
			"injure":
				v -= 6.0 * _n_targets(s, who)
			"cure":
				v += 9.0
			"kill":
				v -= 45.0
			"morale":
				v += n * 0.7 * _n_targets(s, str(e.get("who", "all")))
			"dose":
				v -= float(e.get("msv", 20)) / 12.0 * _n_targets(s, who)
			"tired":
				v -= 1.5 * float(e.get("days", 1))
			"refuse_trip":
				v -= 1.0
			"chance":
				var p: float = float(e.get("p", 0.5))
				v += p * score_effects(s, e.get("then", []), ctx) + (1.0 - p) * score_effects(s, e.get("else", []), ctx)
			"followed":
				if not s.followed:
					v -= 14.0 * float(e.get("p", 1.0))
			"unfollow":
				if s.followed:
					v += 12.0
			"schedule":
				var mood: String = str(ShelterData.event(str(e.get("event", ""))).get("mood", "neutral"))
				v += 4.0 if mood == "good" else (-5.0 if mood == "bad" else 0.0)
			"chain":
				var st: String = str(e.get("step", ""))
				v += 30.0 if st == "advance" else (200.0 if st == "win" else (-18.0 if st == "miss" else 0.0))
			"pet":
				v += 3.0
			"steal":
				v -= 5.0 * n
			"supply_drop":
				v += 6.0
			"reveal_cache":
				v += 5.0
			"lose_run":
				v -= 200.0
			"guilt":
				v -= 3.0
			"fallout_news":
				if not s.fallout_announced:
					v += 3.0
	return v


static func _use_cost(s: ShelterState, it: String, mode: String) -> float:
	match it:
		"medkit":
			return 9.0
		"axe":
			return 1.7 if mode == "wear" else 5.0
		"rifle":
			return 2.0 if s.has("ammo") else 3.5
		"padlock":
			return 6.0
		"bug_spray":
			return 2.0
		"radio":
			return 5.4 if mode == "tinker" else 0.0
		"food":
			return 5.0 * _need_mult(s, "food")
		"water":
			return 6.0 * _need_mult(s, "water")
	return 0.0


# ---------------------------------------------------------------- daily plan

static func make_plan(s: ShelterState, policy: String, rng: RandomNumberGenerator) -> Dictionary:
	match policy:
		"random":
			return _plan_random(s, rng)
		"naive":
			return _plan_naive(s)
	return _plan_expert(s)


static func _plan_random(s: ShelterState, rng: RandomNumberGenerator) -> Dictionary:
	var rations: Dictionary = {}
	var treat: Dictionary = {}
	var jobs: Dictionary = {}
	for m_v in s.home():
		var m: Dictionary = m_v
		var mid: String = str(m["id"])
		rations[mid] = {"food": rng.randf() < 0.5, "water": rng.randf() < 0.5}
		if (bool(m.get("sick", false)) or bool(m.get("injured", false))) and rng.randf() < 0.3:
			treat[mid] = true
		if ShelterTrips.can_go(s, m) == "" and rng.randf() < 0.1 and not s.places.is_empty():
			var gear: Array = []
			for g in ShelterTrips.GEAR_IDS:
				if s.has(g) and rng.randf() < 0.5:
					gear.append(g)
			jobs[mid] = {"job": "trip", "place": rng.randi_range(0, s.places.size() - 1), "gear": gear}
	return {"rations": rations, "treat": treat, "jobs": jobs}


static func _plan_naive(s: ShelterState) -> Dictionary:
	var rations: Dictionary = {}
	var treat: Dictionary = {}
	var jobs: Dictionary = {}
	var feed: bool = s.day % 5 == 0
	for m_v in s.home():
		var m: Dictionary = m_v
		rations[str(m["id"])] = {"food": feed, "water": feed}
		if bool(m.get("sick", false)) or bool(m.get("injured", false)):
			treat[str(m["id"])] = true
	var people: int = s.living().size()
	if s.trips.is_empty() and (s.water() < people * 2 or s.food() < people * 2):
		var who: Dictionary = {}
		for m_v in s.home():
			var m: Dictionary = m_v
			if ShelterTrips.can_go(s, m) == "" and (who.is_empty() or bool(m.get("is_leader", false))):
				who = m
		var home_after: int = s.home().size() - 1
		if not who.is_empty() and home_after > 0:
			var best: int = -1
			var best_d: float = INF
			for p_v in s.places:
				var p: Dictionary = p_v
				if ShelterTrips.stock_total(p) <= 0:
					continue
				var d: float = float(p["walk_m"]) * (0.6 if str(p["category"]) == "grocery" else 1.0)
				if d < best_d:
					best_d = d
					best = int(p["idx"])
			if best >= 0:
				var gear: Array = []
				for g in ShelterTrips.GEAR_IDS:
					if s.has(g) and gear.size() < ShelterTrips.MAX_GEAR:
						gear.append(g)
				jobs[str(who["id"])] = {"job": "trip", "place": best, "gear": gear}
	return {"rations": rations, "treat": treat, "jobs": jobs}


static func _plan_expert(s: ShelterState) -> Dictionary:
	var rations: Dictionary = {}
	var treat: Dictionary = {}
	var jobs: Dictionary = {}
	var home: Array = s.home()
	var people: float = maxf(1.0, float(s.living().size()))
	var water_left: int = s.water()
	var food_left: int = s.food()
	var water_tight: bool = float(water_left) < people * 3.0
	var food_tight: bool = float(food_left) < people * 2.0
	# Thirstiest first, so scarce water goes where it matters.
	var order: Array = home.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("dww", 0)) > int(b.get("dww", 0)))
	for m_v in order:
		var m: Dictionary = m_v
		var mid: String = str(m["id"])
		# Thirsty and Hungry are survivable; Dehydrated and Starving are not worth the risk.
		var w_at: int = ShelterData.Bi("water_dehydrated_day", 4)
		var f_at: int = ShelterData.Bi("food_starving_day", 8)
		if not water_tight and int(m.get("morale", 5)) <= 2:
			w_at = ShelterData.Bi("water_thirsty_day", 3)
		var give_w: bool = int(m.get("dww", 0)) + 1 >= w_at and water_left > 0
		var give_f: bool = int(m.get("dwf", 0)) + 1 >= f_at and food_left > 0
		if give_w:
			water_left -= 1
		if give_f:
			food_left -= 1
		rations[mid] = {"food": give_f, "water": give_w}
	var medkits: int = s.count("medkit")
	for m_v in home:
		var m: Dictionary = m_v
		if medkits <= 0:
			break
		if bool(m.get("sick", false)) or (bool(m.get("injured", false)) and int(m.get("injured_days", 0)) >= 4):
			treat[str(m["id"])] = true
			medkits -= 1
	var trip: Dictionary = _expert_trip(s, rations, treat)
	if not trip.is_empty():
		jobs[str(trip["member"])] = {"job": "trip", "place": int(trip["place"]), "gear": trip["gear"]}
		# The explorer eats and drinks before leaving (hungry or thirsty explorers take more risk).
		var em: Dictionary = s.member(str(trip["member"]))
		var r: Dictionary = rations.get(str(trip["member"]), {"food": false, "water": false})
		if int(em.get("dww", 0)) >= 1 and s.water() > 0:
			r["water"] = true
		if int(em.get("dwf", 0)) >= 4 and s.food() > 0:
			r["food"] = true
		rations[str(trip["member"])] = r
	return {"rations": rations, "treat": treat, "jobs": jobs}


static func _expert_trip(s: ShelterState, rations: Dictionary, treat: Dictionary) -> Dictionary:
	if not s.trips.is_empty():
		return {}
	var people: float = maxf(1.0, float(s.living().size()))
	var water_days: float = float(s.water()) / (people / 4.0)
	var food_days: float = float(s.food()) / (people / 8.0)
	var undefended: bool = s.followed and not s.has("rifle") and not s.has("axe")
	var sick_no_kit: bool = false
	for m_v in s.living():
		if (bool((m_v as Dictionary).get("sick", false)) or bool((m_v as Dictionary).get("injured", false))) and not s.has("medkit"):
			sick_no_kit = true
	var chain_gap: bool = _next_chain_item_missing(s)
	var urgent: bool = water_days < 5.0 or food_days < 6.0
	var wanted: bool = urgent or water_days < 6.0 or food_days < 7.0 or sick_no_kit or (undefended and s.day >= s.followed_since + 12) or (chain_gap and water_days > 8.0 and food_days > 8.0)
	if not wanted:
		return {}
	# Who goes: a healthy adult, leaving at least one adult at home.
	var adults_home: int = 0
	for m_v in s.home():
		if not ShelterState.is_child(m_v as Dictionary):
			adults_home += 1
	if adults_home < 2:
		return {}
	var who: Dictionary = {}
	for m_v in s.home():
		var m: Dictionary = m_v
		if ShelterTrips.can_go(s, m) != "" or treat.has(str(m["id"])):
			continue
		if bool(m.get("sick", false)) or bool(m.get("injured", false)):
			continue
		if int(m.get("dww", 0)) >= 2 and not bool((rations.get(str(m["id"]), {}) as Dictionary).get("water", false)):
			continue
		if who.is_empty() or int(m.get("age", 0)) < int(who.get("age", 0)) or bool(who.get("is_leader", false)):
			who = m
	if who.is_empty():
		return {}
	var heavy: bool = ShelterTrips.heavy_fallout(s) or not s.fallout_announced
	if heavy and not s.has("gas_mask") and not urgent:
		return {}
	var best: Dictionary = {}
	var best_v: float = 0.0
	for p_v in s.places:
		var p: Dictionary = p_v
		var left: int = ShelterTrips.stock_total(p)
		if left <= 0 and int(p["visits"]) > 0:
			continue
		var gear: Array = _expert_gear(s, p)
		var pv: Dictionary = ShelterTrips.preview(s, who, int(p["idx"]), gear)
		if str(pv["dose_band"]) == "Lethal":
			continue
		var val: float = _expected_loot_value(s, p, int(pv["carry"]), sick_no_kit, chain_gap)
		var sick_cost: float = 9.0 if s.count("medkit") >= 2 else (14.0 if s.has("medkit") else 25.0)
		var risk: float = float(pv["p_death"]) * 70.0 + float(pv["sick_p"]) * sick_cost + float(pv["days"]) * 0.8 + float(pv["followed_p"]) * 6.0
		var v: float = val - risk
		if v > best_v:
			best_v = v
			best = {"member": str(who["id"]), "place": int(p["idx"]), "gear": gear}
	if best_v < (2.0 if urgent else 12.0):
		return {}
	return best


const CHAIN_ITEMS: Dictionary = {
	"convoy": {1: ["radio"], 2: ["radio"], 3: ["map"], 4: ["flashlight"]},
	"airlift": {1: ["flashlight"], 2: ["gas_mask"], 3: ["map"]},
	"neighbourhood": {1: ["medkit", "food"], 2: ["radio", "flashlight"], 3: ["map"], 4: ["water"]},
}


## True when an active rescue chain's next request needs an item the family doesn't have.
static func _next_chain_item_missing(s: ShelterState) -> bool:
	for cid in s.chains.keys():
		var c: Dictionary = s.chains[cid]
		if str(c["state"]) != "active" or int(c["next_day"]) > s.day + 6:
			continue
		var need: Array = (CHAIN_ITEMS.get(cid, {}) as Dictionary).get(int(c["step"]), [])
		if need.is_empty():
			continue
		var have: bool = false
		for it in need:
			if s.has(str(it)):
				have = true
		if not have:
			return true
	return false


static func _expert_gear(s: ShelterState, p: Dictionary) -> Array:
	# Every item carried risks breaking (8-12%), so pack only what helps this trip.
	var g: Array = []
	var days: int = ShelterTrips.base_days(p)
	var band: String = ShelterTrips.dose_band(ShelterTrips.dose_estimate(s, p, days, false))
	if (ShelterTrips.heavy_fallout(s) or band == "Lethal") and s.has("gas_mask"):
		g.append("gas_mask")
	if s.has("map") and (days >= 3 or ShelterTrips.raiders_active(s) or s.count("map") > 1):
		g.append("map")
	var expected: int = _expected_items(s, p)
	if s.has("suitcase") and expected > ShelterData.Bi("carry_base", 2) and g.size() < ShelterTrips.MAX_GEAR:
		g.append("suitcase")
	if g.size() < ShelterTrips.MAX_GEAR and str(p["category"]) in ShelterTrips.SHUTTER_CATEGORIES and s.has("axe"):
		g.append("axe")
	if g.size() < ShelterTrips.MAX_GEAR and ShelterTrips.raiders_active(s) and not s.followed and s.has("rifle"):
		g.append("rifle")
	return g


## What the player can reasonably expect to find: the real shelf if they've been, otherwise the
## typical stock for the place type, thinned by the days unseen survivors have been at it.
static func _estimated_stock(s: ShelterState, p: Dictionary) -> Dictionary:
	if int(p["visits"]) > 0:
		return p["stock"]
	var est: Dictionary = {}
	var drain: float = pow(0.92, float(maxi(0, s.day - 1)))
	var table: Dictionary = ShelterData.loot_for(str(p["category"]))
	for k in table.keys():
		var row: Dictionary = table[k]
		est[k] = int(round(float(int(row["min"]) + int(row["max"])) * 0.5 * float(row["chance"]) * drain * 0.85))
	return est


static func _expected_items(s: ShelterState, p: Dictionary) -> int:
	var n: int = 0
	var share: float = ShelterData.B("search_share", 0.8)
	for v in _estimated_stock(s, p).values():
		n += int(floor(float(int(v)) * share))
	return n


## What the household can expect to carry home from this place, weighted by need.
static func _expected_loot_value(s: ShelterState, p: Dictionary, carry: int, want_medkit: bool, chain_gap: bool) -> float:
	var stock: Dictionary = _estimated_stock(s, p)
	var share: float = ShelterData.B("search_share", 0.55)
	if str(p["category"]) in ShelterTrips.SHUTTER_CATEGORIES and not s.has("axe"):
		share *= ShelterData.B("shutter_share_mult", 0.6)
	var vals: Array = []
	for k in stock.keys():
		var it: String = str(k)
		var per: float = float(ITEM_VALUE.get(it, 2.0)) * _need_mult(s, it)
		if it == "medkit" and want_medkit:
			per += 12.0
		if chain_gap and it in ["map", "flashlight", "radio"] and not s.owns(it):
			per += 10.0
		var found: int = int(ceil(float(int(stock[k])) * share))
		for _i in range(found):
			vals.append(per / float(ShelterData.item_slots(it)))
	vals.sort()
	vals.reverse()
	var total: float = 0.0
	for i in range(mini(carry, vals.size())):
		total += float(vals[i])
	return total
