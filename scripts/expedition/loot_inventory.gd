class_name LootInventory
extends RefCounted

## Finite, persistent loot for every real place. During a shelter run the stock lives in the run
## (ShelterState.places, drained daily by unseen survivors); before that (house-select previews)
## it is generated the same deterministic way from the place's OSM id and loot_weights.csv.

static var _preview_cache: Dictionary = {}


static func key_for(poi: Dictionary) -> String:
	var oid: int = int(poi.get("osm_id", 0))
	if oid != 0:
		return str(oid)
	return "%s@%.5f,%.5f" % [str(poi.get("name", "place")), float(poi.get("lat", 0.0)), float(poi.get("lon", 0.0))]


static func _run_place(poi: Dictionary) -> Dictionary:
	var s: ShelterState = GameState.shelter
	if s == null:
		return {}
	var k: String = key_for(poi)
	for p_v in s.places:
		var p: Dictionary = p_v
		if key_for(p) == k:
			return p
	return {}


## {"items": {item: count}, "initial_total": int, "raids": int, "category": String}
static func get_inventory(poi: Dictionary) -> Dictionary:
	var p: Dictionary = _run_place(poi)
	if not p.is_empty():
		return {"items": p["stock"], "initial_total": int(p["initial_total"]), "raids": int(p["visits"]), "category": str(p["category"])}
	var k: String = key_for(poi)
	if not _preview_cache.has(k):
		_preview_cache[k] = _generate(poi)
	return _preview_cache[k]


static func _generate(poi: Dictionary) -> Dictionary:
	var place: Dictionary = ShelterTrips.make_place(poi, 0, 1.0, 1.0)
	return {"items": place["stock"], "initial_total": int(place["initial_total"]), "raids": 0, "category": str(place["category"])}


static func remaining_total(poi: Dictionary) -> int:
	var total: int = 0
	for v in (get_inventory(poi)["items"] as Dictionary).values():
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


## Category-level availability of a resource across the real neighbourhood.
static func neighbourhood_stock(item_id: String) -> int:
	var total: int = 0
	for p_v in GameState.nearby_pois:
		total += int((get_inventory(p_v as Dictionary)["items"] as Dictionary).get(item_id, 0))
	return total
