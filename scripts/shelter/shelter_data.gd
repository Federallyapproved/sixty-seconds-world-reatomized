class_name ShelterData
extends RefCounted

## Read-only access to the compiled content tables (data/build/*.json, produced by
## tools/build_data.gd). Everything the shelter rules need to know about items, loot, events
## and balance numbers comes through here, so new content is a table edit, not a code change.

const BUILD_DIR: String = "res://data/build"

static var _cache: Dictionary = {}


static func _table(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var path: String = "%s/%s.json" % [BUILD_DIR, name]
	var d: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
	else:
		push_error("ShelterData: %s is missing; run tools/build_data.gd" % path)
	_cache[name] = d
	return d


## Drops the cache (tests that rebuild the data call this).
static func reload() -> void:
	_cache = {}


static func items() -> Dictionary:
	return _table("items")


static func item(item_id: String) -> Dictionary:
	return items().get(item_id, {})


static func has_item(item_id: String) -> bool:
	return items().has(item_id)


static func item_name(item_id: String) -> String:
	return str(item(item_id).get("name", item_id.capitalize()))


static func item_slots(item_id: String) -> int:
	return int(item(item_id).get("slots", 1))


static func item_effect(item_id: String, key: String, default_value: float = 0.0) -> float:
	var eff: Dictionary = item(item_id).get("effects", {})
	if not eff.has(key):
		return default_value
	var v: Variant = eff[key]
	return float(v) if (v is float or v is int) else (1.0 if bool(v) else 0.0)


static func core_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in items().keys():
		if str((items()[k] as Dictionary).get("category", "")) == "core":
			ids.append(str(k))
	return ids


static func loot() -> Dictionary:
	return _table("loot")


static func loot_for(place_type: String) -> Dictionary:
	var l: Dictionary = loot()
	if l.has(place_type):
		return l[place_type]
	return l.get("neighbor_house", {})


static func events() -> Dictionary:
	return _table("events")


static func event(event_id: String) -> Dictionary:
	return events().get(event_id, {})


static func narration() -> Dictionary:
	return _table("narration")


static func balance() -> Dictionary:
	return _table("balance")


## A balance number from data/balance.csv.
static func B(key: String, default_value: float = 0.0) -> float:
	var b: Dictionary = balance()
	if not b.has(key):
		push_warning("ShelterData: balance key '%s' missing" % key)
		return default_value
	return float(b[key])


static func Bi(key: String, default_value: int = 0) -> int:
	return int(round(B(key, float(default_value))))
