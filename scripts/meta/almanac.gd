class_name Almanac
extends RefCounted

## The Survival Almanac (section 8, from Balatro's collection): what the player has discovered
## across runs. Undiscovered entries are greyed out; each item's page lists the effects seen so far
## and the item options unlocked. Item options for undiscovered items are hidden in the shelter;
## discovered-but-missing items show as greyed "Needs: X", which teaches next run's grab.
##
## Pure functions over a plain Dictionary (so tests never touch the player's file), plus load/save.

const PATH: String = "user://almanac.json"
const VERSION: int = 1
const MAX_LINES: int = 12


static func blank() -> Dictionary:
	return {"version": VERSION, "runs": 0, "items": {}, "events": {}, "endings": {}, "rules": {},
		"strangers": {}, "places_looted": {}, "addresses_won": {}, "afflictions": {}}


static func load_data(path: String = PATH) -> Dictionary:
	var d: Dictionary = blank()
	if not FileAccess.file_exists(path):
		return d
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for k in (parsed as Dictionary).keys():
			d[k] = parsed[k]
	return d


static func save_data(d: Dictionary, path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


static func _item(d: Dictionary, item_id: String) -> Dictionary:
	var items: Dictionary = d["items"]
	if not items.has(item_id):
		items[item_id] = {"seen": true, "effects": [], "options": []}
	return items[item_id]


## An item was seen (aimed at in the grab, or owned in the shelter).
static func mark_seen(d: Dictionary, item_id: String) -> void:
	if item_id == "" or not ShelterData.has_item(item_id):
		return
	_item(d, item_id)["seen"] = true


static func is_known(d: Dictionary, item_id: String) -> bool:
	return (d.get("items", {}) as Dictionary).has(item_id)


## The items whose options the shelter shows (greyed when missing).
static func known_items(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in (d.get("items", {}) as Dictionary).keys():
		out[str(k)] = true
	return out


static func _add_unique(arr: Array, v: String) -> void:
	if v != "" and not arr.has(v) and arr.size() < MAX_LINES:
		arr.append(v)


## Folds a finished run into the Almanac. ctx: {"address_key": String} for a rescue.
static func record_run(d: Dictionary, s: ShelterState, ctx: Dictionary = {}) -> void:
	d["runs"] = int(d.get("runs", 0)) + 1
	for k in (s.stats["seen_items"] as Dictionary).keys():
		mark_seen(d, str(k))
	var cl: Dictionary = s.stats["credit_lines"]
	for k in cl.keys():
		var page: Dictionary = _item(d, str(k))
		for line in cl[k]:
			_add_unique(page["effects"], str(line))
	var ol: Dictionary = s.stats["item_option_labels"]
	for k in ol.keys():
		var page2: Dictionary = _item(d, str(k))
		for line in ol[k]:
			_add_unique(page2["options"], str(line))
	var ev: Dictionary = d["events"]
	for eid in s.used_events.keys():
		ev[str(eid)] = int(ev.get(str(eid), 0)) + 1
	if s.ending != "":
		var en: Dictionary = d["endings"]
		en[s.ending] = int(en.get(s.ending, 0)) + 1
	for rid in s.rules:
		(d["rules"] as Dictionary)[str(rid)] = true
	if str(s.stats.get("stranger", "")) != "":
		(d["strangers"] as Dictionary)[str(s.stats["stranger"])] = true
	for cat in (s.stats["places_looted"] as Dictionary).keys():
		(d["places_looted"] as Dictionary)[str(cat)] = true
	for m_v in s.members:
		var a: String = str((m_v as Dictionary).get("affliction", ""))
		if a != "":
			(d["afflictions"] as Dictionary)[a] = true
	if s.ending_kind == "win" and str(ctx.get("address_key", "")) != "":
		(d["addresses_won"] as Dictionary)[str(ctx["address_key"])] = true


## One item's page: discovered or not, effects seen, options unlocked.
static func item_page(d: Dictionary, item_id: String) -> Dictionary:
	var it: Dictionary = ShelterData.item(item_id)
	var known: bool = is_known(d, item_id)
	var page: Dictionary = (d.get("items", {}) as Dictionary).get(item_id, {})
	return {
		"id": item_id, "known": known, "name": str(it.get("name", item_id)) if known else "???",
		"purpose": str(it.get("purpose", "")) if known else "Not discovered yet.",
		"almanac": str(it.get("almanac", "")) if known else "",
		"slots": int(it.get("slots", 1)),
		"effects": (page.get("effects", []) as Array).duplicate(), "options": (page.get("options", []) as Array).duplicate(),
	}


## Counts for the Almanac header ("Items 9/16 · Events 41/101 · Endings 3/10 ...").
static func progress(d: Dictionary) -> Dictionary:
	return {
		"items": [(d["items"] as Dictionary).size(), ShelterData.core_ids().size()],
		"events": [(d["events"] as Dictionary).size(), ShelterData.events().size()],
		"endings": [(d["endings"] as Dictionary).size(), ShelterSim.ENDINGS.size()],
		"rules": [(d["rules"] as Dictionary).size(), ShelterData.house_rules().size()],
		"places": [(d["places_looted"] as Dictionary).size(), 10],
	}
