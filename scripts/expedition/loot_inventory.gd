class_name LootInventory
extends RefCounted

## Finite, persistent loot for every real place.
##
## Each building gets a stock the first time anyone looks at it: deterministic from its OSM id,
## sized by category and (for mapped building outlines) by footprint area. A raid only searches
## part of what is left and is limited by what the explorer can carry, so successive raids find
## progressively less until the place is stripped. Nothing ever respawns.

const STOCK_TABLE: Dictionary = LootTables.STOCK_TABLE

# Chance that a neighbour's driveway car / garage yields these at all (rarer parts are rarer).
const NEIGHBOR_RARE: Dictionary = {"car_battery": 0.28, "fuel_can": 0.3, "spark_plugs": 0.08, "fan_belt": 0.06, "tire_patch": 0.12}

const SLOT_COST: Dictionary = {"axe": 2, "rifle": 2, "toolbox": 2, "suitcase": 2, "car_battery": 2, "fuel_can": 2}


static func key_for(poi: Dictionary) -> String:
	var oid: int = int(poi.get("osm_id", 0))
	if oid != 0:
		return str(oid)
	return "%s@%.5f,%.5f" % [str(poi.get("name", "place")), float(poi.get("lat", 0.0)), float(poi.get("lon", 0.0))]


static func get_inventory(poi: Dictionary) -> Dictionary:
	var k: String = key_for(poi)
	if not GameState.poi_inventories.has(k):
		GameState.poi_inventories[k] = _generate(poi)
	return GameState.poi_inventories[k]


static func _size_mult(poi: Dictionary) -> float:
	var cat: String = str(poi.get("category", ""))
	var sub: String = str(poi.get("subkind", ""))
	var m: float = 1.0
	var area: float = float(poi.get("area_sqm", 0.0))
	if area > 0.0:
		m = clampf(sqrt(area / 250.0), 0.5, 2.2)
	if cat == "grocery":
		if sub == "supermarket":
			m *= 1.5
		elif sub in ["convenience", "deli", "bakery", "butcher", "pastry"]:
			m *= 0.6
	if cat == "auto" and sub in ["car_repair", "car_parts"]:
		m *= 1.2
	return m


static func _generate(poi: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key_for(poi)) ^ 0x5EED
	var cat: String = str(poi.get("category", "neighbor_house"))
	if cat == "house" or cat == "":
		cat = "neighbor_house"
	var sub: String = str(poi.get("subkind", ""))
	var table: Dictionary = STOCK_TABLE.get(cat, STOCK_TABLE["neighbor_house"])
	var mult: float = _size_mult(poi)
	var items: Dictionary = {}
	for iid_v in table.keys():
		var iid: String = str(iid_v)
		var rngv: Array = table[iid]
		var lo: int = int(rngv[0])
		var hi: int = int(rngv[1])
		var n: int = rng.randi_range(lo, hi)
		if iid in ["soup", "water", "medkit", "spark_plugs", "fuel_can", "ammo", "tire_patch"]:
			n = int(round(float(n) * mult))
		# Batteries: fuel stations rarely stock them; repair/parts shops do.
		if cat == "auto" and iid == "car_battery":
			n = rng.randi_range(1, 3) if sub in ["car_repair", "car_parts", "battery"] else (1 if rng.randf() < 0.35 else 0)
		if cat == "auto" and iid == "fuel_can" and sub not in ["fuel"]:
			n = rng.randi_range(0, 2)
		if cat == "neighbor_house" and NEIGHBOR_RARE.has(iid):
			n = 1 if rng.randf() < float(NEIGHBOR_RARE[iid]) else 0
		if n > 0:
			items[iid] = n
	var total: int = 0
	for v in items.values():
		total += int(v)
	return {"items": items, "initial_total": total, "raids": 0, "category": cat}


static func remaining_total(poi: Dictionary) -> int:
	var inv: Dictionary = get_inventory(poi)
	var total: int = 0
	for v in (inv["items"] as Dictionary).values():
		total += int(v)
	return total


static func fraction_left(poi: Dictionary) -> float:
	var inv: Dictionary = get_inventory(poi)
	var init: int = int(inv.get("initial_total", 0))
	if init <= 0:
		return 0.0
	return float(remaining_total(poi)) / float(init)


static func status_label(poi: Dictionary) -> String:
	var inv: Dictionary = get_inventory(poi)
	var raids: int = int(inv.get("raids", 0))
	var left: int = remaining_total(poi)
	if left == 0:
		return "Stripped bare" if raids > 0 else "Nothing worth taking"
	if raids == 0:
		return "Unsearched"
	return "Picked over (%d%% left)" % int(round(fraction_left(poi) * 100.0))


## Searches the place: finds a share of what is left (better with a flashlight / scout) and keeps
## what fits in `capacity_slots`. Removes it from the building permanently. Returns {item: count}.
static func raid(poi: Dictionary, capacity_slots: int, search_share: float, rng: RandomNumberGenerator, priorities: Array = []) -> Dictionary:
	var inv: Dictionary = get_inventory(poi)
	var stock: Dictionary = inv["items"]
	inv["raids"] = int(inv.get("raids", 0)) + 1
	# What a search turns up this time (a share of each remaining stack, at least 1 of a stack sometimes).
	var found: Dictionary = {}
	for iid_v in stock.keys():
		var iid: String = str(iid_v)
		var have: int = int(stock[iid])
		if have <= 0:
			continue
		var exp_n: float = float(have) * clampf(search_share, 0.05, 1.0)
		var n: int = int(floor(exp_n))
		if rng.randf() < exp_n - float(n):
			n += 1
		n = mini(n, have)
		if n > 0:
			found[iid] = n
	# Carry what fits, most needed first.
	var order: Array = found.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool:
		var pa: int = priorities.find(str(a))
		var pb: int = priorities.find(str(b))
		pa = 999 if pa < 0 else pa
		pb = 999 if pb < 0 else pb
		return pa < pb
	)
	var taken: Dictionary = {}
	var slots_left: int = capacity_slots
	for iid_v2 in order:
		var iid2: String = str(iid_v2)
		var cost: int = int(SLOT_COST.get(iid2, 1))
		var can: int = mini(int(found[iid2]), slots_left / cost)
		if can <= 0:
			continue
		taken[iid2] = can
		slots_left -= can * cost
		stock[iid2] = int(stock[iid2]) - can
		if int(stock[iid2]) <= 0:
			stock.erase(iid2)
	return taken


## Ambushers took part of the haul: it is gone (not returned to the building).
static func lose_share(taken: Dictionary, share: float, rng: RandomNumberGenerator) -> Dictionary:
	var kept: Dictionary = {}
	for k in taken.keys():
		var n: int = int(taken[k])
		var lost: int = 0
		for _i in range(n):
			if rng.randf() < share:
				lost += 1
		if n - lost > 0:
			kept[k] = n - lost
	return kept


## Category-level availability of a resource across the real neighbourhood (for UI & endings).
static func neighbourhood_stock(item_id: String) -> int:
	var total: int = 0
	for p_v in GameState.nearby_pois:
		var p: Dictionary = p_v
		var inv: Dictionary = get_inventory(p)
		total += int((inv["items"] as Dictionary).get(item_id, 0))
	return total
