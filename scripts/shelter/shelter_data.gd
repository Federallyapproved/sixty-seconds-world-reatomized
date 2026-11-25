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


## A narration line for a trigger that hasn't played this run (section 15: no line plays twice).
## `used` is the run's ShelterState.lines_used; returns "" when every line has played.
static func line_for(trigger: String, used: Dictionary, rng: RandomNumberGenerator) -> String:
	var pool: Array = []
	var ids: Array = narration().keys()
	ids.sort()
	for nid in ids:
		var r: Dictionary = narration()[nid]
		if str(r.get("trigger", "")) == trigger and not used.has(nid):
			pool.append(nid)
	if pool.is_empty():
		return ""
	var pick: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	used[pick] = true
	return str((narration()[pick] as Dictionary).get("text", ""))


static func house_rules() -> Dictionary:
	return _table("house_rules")


static func house_rule(rule_id: String) -> Dictionary:
	return house_rules().get(rule_id, {})


## House Rules in the order the family meets them (each goes a little further than the last).
static func house_rule_ids() -> Array:
	var ids: Array = house_rules().keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((house_rules()[a] as Dictionary).get("order", 0)) < int((house_rules()[b] as Dictionary).get("order", 0)))
	return ids


static func afflictions() -> Dictionary:
	return _table("afflictions")


static func affliction(aff_id: String) -> Dictionary:
	return afflictions().get(aff_id, {})


static func achievements() -> Dictionary:
	return _table("achievements")


# ---------------------------------------------------------------- crafting (M3)

static func parts() -> Dictionary:
	return _table("parts")


static func part(part_id: String) -> Dictionary:
	return parts().get(part_id, {})


## The six parts in a fixed display order.
static func part_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in ["cloth", "metal", "electronics", "plastic", "binding", "chemicals"]:
		if parts().has(k):
			ids.append(k)
	return ids


static func recipes() -> Dictionary:
	return _table("recipes")


static func recipe(recipe_id: String) -> Dictionary:
	return recipes().get(recipe_id, {})


static func chapters() -> Dictionary:
	return _table("chapters")


static func chapter(chapter_id: String) -> Dictionary:
	return chapters().get(chapter_id, {})


static func ids_in(category: String) -> Array[String]:
	var ids: Array[String] = []
	for k in items().keys():
		if str((items()[k] as Dictionary).get("category", "")) == category:
			ids.append(str(k))
	ids.sort()
	return ids


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
