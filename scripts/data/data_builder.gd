class_name DataBuilder
extends RefCounted

## Compiles the editable tables in data/ (CSV + data/events/*.json) into data/build/*.json and
## validates them. Run it with `godot --headless -s res://tools/build_data.gd`; the test suite
## runs it too, so a broken table fails the build.
##
## Validator rules (any error fails the build):
## * duplicate ids, dangling references (items, events, chains, effects, conditions);
## * a missing icon; an item's slot count outside 1-3;
## * a core item gating fewer than 3 events; an event without a no-item option, or an item-gated
##   event whose no-item options all cost nothing; a fatal outcome without a warning kind;
## * a recipe part that no junk in at least 2 place types can supply; a recipe, part, manual
##   chapter or makeshift stand-in ("alt") that points nowhere, or an alt on a rescue step;
## * a narration line without its .ogg (allowed while the row is marked pending);
## * banned words (the 1950s list and brand names) in any table or event text;
## * a third-party asset with a license outside the allowed list, or a file under assets/ with no
##   manifest row (CREDITS.md is generated from the manifest, so every row gets its credit line).

const DATA_DIR: String = "res://data"
const BUILD_DIR: String = "res://data/build"
const EVENTS_DIR: String = "res://data/events"
const MAX_SETUP_WORDS: int = 25
const MAX_OUTCOME_WORDS: int = 30
const MAX_NARRATION_WORDS: int = 15

var errors: Array[String] = []
var warnings: Array[String] = []
var out: Dictionary = {}


static func build(write: bool = true) -> Dictionary:
	var b := DataBuilder.new()
	b._run(write)
	return {"errors": b.errors, "warnings": b.warnings, "out": b.out}


func _err(msg: String) -> void:
	errors.append(msg)


func _run(write: bool) -> void:
	var items: Dictionary = _load_items()
	var loot: Dictionary = _load_loot(items)
	var balance: Dictionary = _load_balance()
	var parts: Dictionary = _load_parts()
	var chapters: Dictionary = _load_chapters()
	var recipes: Dictionary = _load_recipes(items, parts, chapters)
	_check_makeshift(items, recipes)
	var narration: Dictionary = _load_narration()
	var rules: Dictionary = _load_simple_table("house_rules.csv", "id")
	var achievements: Dictionary = _load_simple_table("achievements.csv", "id")
	var afflictions: Dictionary = _load_simple_table("afflictions.csv", "id")
	_check_rules(rules)
	_check_afflictions(afflictions)
	_check_achievements(achievements)
	var manifest: Array = _load_manifest()
	var events: Dictionary = _load_events(items)
	_check_item_coverage(items, events)
	_check_recipe_parts(items, loot, recipes)
	_check_alts(events, items)
	_check_banned_text(items, events, narration, rules, achievements, afflictions)
	_check_strangers(events)
	_check_later_triggers(events, narration)
	_check_assets(items, manifest)
	var gate_counts: Dictionary = out.get("item_gate_counts", {})
	out = {
		"items": items, "loot": loot, "balance": balance, "parts": parts, "recipes": recipes, "chapters": chapters,
		"narration": narration, "house_rules": rules, "achievements": achievements, "afflictions": afflictions,
		"events": events, "assets": manifest, "item_gate_counts": gate_counts,
	}
	if write and errors.is_empty():
		_write_all()


# ---------------------------------------------------------------- CSV helpers

static func read_csv(path: String) -> Array:
	var rows: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	var header: PackedStringArray = f.get_csv_line()
	while not f.eof_reached():
		var line: PackedStringArray = f.get_csv_line()
		if line.size() == 1 and str(line[0]).strip_edges() == "":
			continue
		var row: Dictionary = {}
		for i in range(header.size()):
			row[str(header[i]).strip_edges()] = str(line[i]).strip_edges() if i < line.size() else ""
		rows.append(row)
	return rows


## "a=1;b=0.5;c" -> {"a": 1.0, "b": 0.5, "c": true}; "metal:2;cloth:1" (sep ":") likewise.
static func parse_kv(s: String, sep: String = "=") -> Dictionary:
	var d: Dictionary = {}
	for part in s.split(";", false):
		var p: String = part.strip_edges()
		if p == "":
			continue
		var bits: PackedStringArray = p.split(sep, true, 1)
		var k: String = bits[0].strip_edges()
		if bits.size() == 1:
			d[k] = true
		else:
			var v: String = bits[1].strip_edges()
			d[k] = float(v) if v.is_valid_float() else v
	return d


func _load_items() -> Dictionary:
	var items: Dictionary = {}
	for r_v in read_csv(DATA_DIR + "/items.csv"):
		var r: Dictionary = r_v
		var iid: String = str(r.get("id", ""))
		if iid == "":
			_err("items.csv: a row has no id")
			continue
		if items.has(iid):
			_err("items.csv: duplicate id '%s'" % iid)
			continue
		var cat: String = str(r.get("category", ""))
		if not (cat in DataSchema.ITEM_CATEGORIES):
			_err("items.csv: '%s' has unknown category '%s'" % [iid, cat])
		var slots: int = int(str(r.get("slots", "0")))
		if slots < 1 or slots > 3:
			_err("items.csv: '%s' takes %d slots (must be 1-3)" % [iid, slots])
		var icon: String = str(r.get("icon", ""))
		if icon == "" or not FileAccess.file_exists(icon):
			_err("items.csv: '%s' icon is missing (%s)" % [iid, icon])
		if str(r.get("purpose_line", "")) == "":
			_err("items.csv: '%s' has no purpose line" % iid)
		var variants: Array = []
		for v in str(r.get("variants", "")).split("|", false):
			variants.append(v.strip_edges())
		items[iid] = {
			"id": iid, "name": str(r.get("name", iid)), "short_name": str(r.get("short_name", r.get("name", iid))), "category": cat, "slots": slots,
			"grab_rooms": str(r.get("grab_rooms", "")).split("|", false),
			"purpose": str(r.get("purpose_line", "")), "effects": parse_kv(str(r.get("effects", ""))),
			"breaks_on": parse_kv(str(r.get("breaks_on", "")), ":"), "repair": str(r.get("repair", "")),
			"scrap": parse_kv(str(r.get("scrap_yield", "")), ":"), "icon": icon,
			"icon_author": str(r.get("icon_author", "")), "icon_source": str(r.get("icon_source", "")),
			"icon_color": str(r.get("icon_color", "#e8eaed")), "variants": variants,
			"almanac": str(r.get("almanac_text", "")), "narration_ids": str(r.get("narration_ids", "")).split("|", false),
		}
	return items


func _load_loot(items: Dictionary) -> Dictionary:
	var loot: Dictionary = {}
	for r_v in read_csv(DATA_DIR + "/loot_weights.csv"):
		var r: Dictionary = r_v
		var pt: String = str(r.get("place_type", ""))
		var iid: String = str(r.get("item_id", ""))
		if not items.has(iid):
			_err("loot_weights.csv: %s lists unknown item '%s'" % [pt, iid])
			continue
		if not loot.has(pt):
			loot[pt] = {}
		var tbl: Dictionary = loot[pt]
		if tbl.has(iid):
			_err("loot_weights.csv: %s lists '%s' twice" % [pt, iid])
		var lo: int = int(str(r.get("min", "0")))
		var hi: int = int(str(r.get("max", "0")))
		if hi < lo:
			_err("loot_weights.csv: %s/%s max < min" % [pt, iid])
		tbl[iid] = {"min": lo, "max": hi, "chance": float(str(r.get("chance", "1"))), "size_scaled": str(r.get("size_scaled", "0")) == "1"}
	return loot


func _load_balance() -> Dictionary:
	var bal: Dictionary = {}
	for r_v in read_csv(DATA_DIR + "/balance.csv"):
		var r: Dictionary = r_v
		var k: String = str(r.get("key", ""))
		if k == "":
			continue
		if bal.has(k):
			_err("balance.csv: duplicate key '%s'" % k)
		var v: String = str(r.get("value", ""))
		if not v.is_valid_float():
			_err("balance.csv: '%s' is not a number" % k)
		bal[k] = float(v)
	return bal


func _load_simple_table(file: String, key: String) -> Dictionary:
	var t: Dictionary = {}
	for r_v in read_csv(DATA_DIR + "/" + file):
		var r: Dictionary = r_v
		var k: String = str(r.get(key, ""))
		if k == "":
			continue
		if t.has(k):
			_err("%s: duplicate id '%s'" % [file, k])
		t[k] = r
	return t


func _load_parts() -> Dictionary:
	var parts: Dictionary = _load_simple_table("parts.csv", "id")
	var shapes: Dictionary = {}
	for pid in parts.keys():
		var r: Dictionary = parts[pid]
		var shape: String = str(r.get("icon_shape", ""))
		if not (shape in DataSchema.PART_SHAPES):
			_err("parts.csv: '%s' has unknown shape '%s'" % [pid, shape])
		if shapes.has(shape):
			_err("parts.csv: '%s' and '%s' share the shape '%s' (each part needs its own, for colour-blind players)" % [pid, str(shapes[shape]), shape])
		shapes[shape] = pid
		if not Color.html_is_valid(str(r.get("color", ""))):
			_err("parts.csv: '%s' has an invalid colour" % pid)
		parts[pid] = {"id": str(pid), "name": str(r.get("name", pid)), "shape": shape, "color": str(r.get("color", "#e8eaed"))}
	return parts


func _load_chapters() -> Dictionary:
	var ch: Dictionary = _load_simple_table("manual_chapters.csv", "id")
	for cid in ch.keys():
		var r: Dictionary = ch[cid]
		for k in ["order", "title", "pamphlet", "pamphlet_places"]:
			if str(r.get(k, "")) == "":
				_err("manual_chapters.csv: '%s' has no %s" % [cid, k])
		ch[cid] = {"id": str(cid), "order": int(str(r.get("order", "0"))), "title": str(r.get("title", "")),
			"pamphlet": str(r.get("pamphlet", "")), "pamphlet_places": str(r.get("pamphlet_places", "")).split("|", false)}
	return ch


func _load_recipes(items: Dictionary, parts: Dictionary, chapters: Dictionary) -> Dictionary:
	var recipes: Dictionary = {}
	for r_v in read_csv(DATA_DIR + "/recipes.csv"):
		var r: Dictionary = r_v
		var rid: String = str(r.get("id", ""))
		if rid == "":
			continue
		if recipes.has(rid):
			_err("recipes.csv: duplicate id '%s'" % rid)
		var needs: Dictionary = parse_kv(str(r.get("parts", "")), ":")
		if needs.is_empty():
			_err("recipes.csv: '%s' needs no parts" % rid)
		for p in needs.keys():
			# "match" is the part the broken item scraps into (the Patch Job).
			if not parts.has(str(p)) and str(p) != "match":
				_err("recipes.csv: '%s' needs unknown part '%s'" % [rid, str(p)])
		var tool: String = str(r.get("tool", ""))
		if tool != "" and tool != "-" and not items.has(tool):
			_err("recipes.csv: '%s' needs unknown tool '%s'" % [rid, tool])
		var makes: String = str(r.get("makes", ""))
		if makes == "patch":
			if not needs.has("match"):
				_err("recipes.csv: '%s' patches an item but needs no matching part" % rid)
		elif not items.has(makes):
			_err("recipes.csv: '%s' makes unknown item '%s'" % [rid, makes])
		elif str((items[makes] as Dictionary).get("category", "")) != "makeshift":
			_err("recipes.csv: '%s' makes '%s', which is not marked makeshift" % [rid, makes])
		var time: String = str(r.get("time", "quick"))
		if not (time in DataSchema.RECIPE_TIMES):
			_err("recipes.csv: '%s' has unknown time '%s' (quick or day)" % [rid, time])
		var unlock: String = str(r.get("unlock", "known"))
		if unlock != "known" and not chapters.has(unlock):
			_err("recipes.csv: '%s' is unlocked by unknown chapter '%s'" % [rid, unlock])
		for k in ["name", "purpose", "compare"]:
			if str(r.get(k, "")) == "":
				_err("recipes.csv: '%s' has no %s" % [rid, k])
		recipes[rid] = {"id": rid, "name": str(r.get("name", rid)), "parts": needs, "tool": "" if tool == "-" else tool, "time": time,
			"makes": makes, "purpose": str(r.get("purpose", "")), "compare": str(r.get("compare", "")), "unlock": unlock}
	return recipes


## Junk scraps into known parts; every makeshift item is made by a recipe and declares only
## effects the rules know; a stand-in names a core item.
func _check_makeshift(items: Dictionary, recipes: Dictionary) -> void:
	var made: Dictionary = {}
	for rid in recipes.keys():
		made[str((recipes[rid] as Dictionary)["makes"])] = true
	var parts: Array = ["cloth", "metal", "electronics", "plastic", "binding", "chemicals"]
	for iid in items.keys():
		var it: Dictionary = items[iid]
		var cat: String = str(it.get("category", ""))
		for part in (it.get("scrap", {}) as Dictionary).keys():
			if not (str(part) in parts):
				_err("items.csv: '%s' scraps into unknown part '%s'" % [iid, str(part)])
		if cat == "junk" and (it.get("scrap", {}) as Dictionary).is_empty():
			_err("items.csv: junk '%s' breaks into nothing" % iid)
		if cat != "makeshift":
			continue
		if not made.has(iid):
			_err("items.csv: makeshift '%s' has no recipe" % iid)
		var eff: Dictionary = it.get("effects", {})
		for k in eff.keys():
			if not (str(k) in DataSchema.MAKESHIFT_EFFECTS):
				_err("items.csv: makeshift '%s' has unknown effect '%s'" % [iid, str(k)])
		if eff.has("stands_in"):
			var real: String = str(eff["stands_in"])
			if not items.has(real) or str((items[real] as Dictionary).get("category", "")) != "core":
				_err("items.csv: makeshift '%s' stands in for '%s', which is not a core item" % [iid, real])


func _load_narration() -> Dictionary:
	var lines: Dictionary = {}
	for r_v in read_csv(DATA_DIR + "/narration.csv"):
		var r: Dictionary = r_v
		var nid: String = str(r.get("id", ""))
		if nid == "":
			continue
		if lines.has(nid):
			_err("narration.csv: duplicate id '%s'" % nid)
		var text: String = str(r.get("text", ""))
		if _word_count(text) > MAX_NARRATION_WORDS:
			_err("narration.csv: '%s' is %d words (max %d)" % [nid, _word_count(text), MAX_NARRATION_WORDS])
		var audio: String = str(r.get("audio", ""))
		var status: String = str(r.get("status", "pending"))
		if status != "pending" and (audio == "" or not FileAccess.file_exists(audio)):
			_err("narration.csv: '%s' has no audio file (%s) and is not marked pending" % [nid, audio])
		lines[nid] = {"id": nid, "trigger": str(r.get("trigger", "")), "voice": str(r.get("voice", "")), "text": text, "audio": audio, "status": status}
	return lines


func _load_manifest() -> Array:
	var rows: Array = []
	var seen: Dictionary = {}
	for r_v in read_csv(DATA_DIR + "/assets_manifest.csv"):
		var r: Dictionary = r_v
		var p: String = str(r.get("path", ""))
		if p == "":
			continue
		if seen.has(p):
			_err("assets_manifest.csv: '%s' listed twice" % p)
		seen[p] = true
		var lic: String = str(r.get("license", ""))
		if not (lic in DataSchema.ALLOWED_LICENSES):
			_err("assets_manifest.csv: '%s' has license '%s' (allowed: %s)" % [p, lic, ", ".join(DataSchema.ALLOWED_LICENSES)])
		if not FileAccess.file_exists("res://" + p):
			_err("assets_manifest.csv: '%s' does not exist" % p)
		rows.append(r)
	return rows


# ---------------------------------------------------------------- events

func _load_events(items: Dictionary) -> Dictionary:
	var events: Dictionary = {}
	var dir := DirAccess.open(EVENTS_DIR)
	if dir == null:
		_err("data/events is missing")
		return events
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	for f in files:
		var txt: String = FileAccess.get_file_as_string(EVENTS_DIR + "/" + f)
		var json := JSON.new()
		if json.parse(txt) != OK:
			_err("events/%s: JSON error on line %d: %s" % [f, json.get_error_line(), json.get_error_message()])
			continue
		var arr: Array = json.data if json.data is Array else [json.data]
		for ev_v in arr:
			if not (ev_v is Dictionary):
				_err("events/%s: an entry is not an object" % f)
				continue
			var ev: Dictionary = ev_v
			var eid: String = str(ev.get("id", ""))
			if eid == "":
				_err("events/%s: an event has no id" % f)
				continue
			if events.has(eid):
				_err("events: duplicate id '%s' (%s)" % [eid, f])
				continue
			ev["file"] = f
			events[eid] = ev
	for eid in events.keys():
		_check_event(events[eid], events, items)
	return events


func _check_event(ev: Dictionary, events: Dictionary, items: Dictionary) -> void:
	var eid: String = str(ev["id"])
	for k in ["title", "setup", "type", "mood", "options"]:
		if not ev.has(k):
			_err("event '%s' has no '%s'" % [eid, k])
			return
	if not (str(ev["type"]) in DataSchema.EVENT_TYPES):
		_err("event '%s' has unknown type '%s'" % [eid, str(ev["type"])])
	if not (str(ev["mood"]) in DataSchema.EVENT_MOODS):
		_err("event '%s' has unknown mood '%s'" % [eid, str(ev["mood"])])
	if _word_count(str(ev["setup"])) > MAX_SETUP_WORDS:
		_err("event '%s' setup is %d words (max %d)" % [eid, _word_count(str(ev["setup"])), MAX_SETUP_WORDS])
	_check_tokens(eid, str(ev["setup"]))
	var cond: Dictionary = ev.get("conditions", {})
	for ck in cond.keys():
		if not (str(ck) in DataSchema.CONDITION_KEYS):
			_err("event '%s' has unknown condition '%s'" % [eid, str(ck)])
	if cond.has("needs_dirty_water") and not str(cond["needs_dirty_water"]).is_valid_int():
		_err("event '%s' needs_dirty_water must be a whole number of rations" % eid)
	for ck in ["needs_owned", "needs_missing", "needs_broken"]:
		if cond.has(ck) and not items.has(str(cond[ck])):
			_err("event '%s' condition %s names unknown item '%s'" % [eid, ck, str(cond[ck])])
	if ev.has("chain") and not (str(ev["chain"]) in DataSchema.CHAINS):
		_err("event '%s' belongs to unknown chain '%s'" % [eid, str(ev["chain"])])
	var opts: Array = ev["options"]
	if opts.size() < 2 or opts.size() > 4:
		_err("event '%s' has %d options (2-4)" % [eid, opts.size()])
	var seen: Dictionary = {}
	var n_item: int = 0
	var n_basic: int = 0
	var basic_cost: bool = false
	var fatal: bool = false
	for o_v in opts:
		var o: Dictionary = o_v
		var oid: String = str(o.get("id", ""))
		if oid == "" or seen.has(oid):
			_err("event '%s' has a missing or duplicate option id '%s'" % [eid, oid])
		seen[oid] = true
		if str(o.get("label", "")) == "" or str(o.get("outcome", "")) == "":
			_err("event '%s' option '%s' needs a label and an outcome" % [eid, oid])
		if _word_count(str(o.get("outcome", ""))) > MAX_OUTCOME_WORDS:
			_err("event '%s' option '%s' outcome is %d words (max %d)" % [eid, oid, _word_count(str(o.get("outcome", ""))), MAX_OUTCOME_WORDS])
		_check_tokens(eid, str(o.get("outcome", "")))
		_check_tokens(eid, str(o.get("label", "")))
		var it: String = str(o.get("item", ""))
		if it != "":
			n_item += 1
			if not items.has(it):
				_err("event '%s' option '%s' needs unknown item '%s'" % [eid, oid, it])
		else:
			n_basic += 1
		var effs: Array = o.get("effects", [])
		var info: Dictionary = _check_effects(eid, oid, effs, events, items)
		if bool(info["fatal"]):
			fatal = true
		if it == "" and bool(info["cost"]):
			basic_cost = true
	if n_basic < 2:
		_err("event '%s' has %d option(s) that need no item (needs 2)" % [eid, n_basic])
	if n_item > 2:
		_err("event '%s' has %d item options (max 2)" % [eid, n_item])
	if n_item > 0 and not basic_cost and not bool(ev.get("free_basic_ok", false)):
		_err("event '%s' is item-gated but every no-item option is free" % eid)
	if fatal and str(ev.get("warning", "")) == "":
		_err("event '%s' can kill or end the run but declares no warning kind" % eid)


## Returns {"fatal": bool, "cost": bool} for an effect list (recursing into chances).
func _check_effects(eid: String, oid: String, effs: Array, events: Dictionary, items: Dictionary) -> Dictionary:
	var res: Dictionary = {"fatal": false, "cost": false}
	for e_v in effs:
		if not (e_v is Dictionary):
			_err("event '%s' option '%s' has a non-object effect" % [eid, oid])
			continue
		var e: Dictionary = e_v
		var op: String = str(e.get("do", ""))
		if not (op in DataSchema.EFFECT_OPS):
			_err("event '%s' option '%s' has unknown effect '%s'" % [eid, oid, op])
			continue
		if e.has("item") and str(e["item"]) != "any" and not items.has(str(e["item"])):
			_err("event '%s' option '%s' effect %s names unknown item '%s'" % [eid, oid, op, str(e["item"])])
		if op == "junk" and str((items.get(str(e.get("item", "")), {}) as Dictionary).get("category", "")) != "junk":
			_err("event '%s' option '%s' 'junk' names '%s', which is not junk" % [eid, oid, str(e.get("item", ""))])
		if e.has("who") and not (str(e["who"]) in DataSchema.WHO):
			_err("event '%s' option '%s' effect %s has unknown target '%s'" % [eid, oid, op, str(e["who"])])
		match op:
			"kill", "lose_run":
				res["fatal"] = true
				res["cost"] = true
			"end_run":
				res["cost"] = true
				var ending: String = str(e.get("ending", ""))
				if not ShelterSim.ENDINGS.has(ending) or str((ShelterSim.ENDINGS[ending] as Dictionary).get("kind", "")) != "maybe":
					_err("event '%s' option '%s' ends the run with '%s', which is not a maybe ending" % [eid, oid, ending])
			"later":
				if str(e.get("text", "")) == "" and str(e.get("trigger", "")) == "":
					_err("event '%s' option '%s' 'later' needs a text or a narration trigger" % [eid, oid])
			"rule":
				if not ShelterData.house_rules().is_empty() and str(e.get("rule", "")) == "":
					_err("event '%s' option '%s' 'rule' names no rule" % [eid, oid])
			"lose", "steal", "sick", "injure", "dose", "break", "break_fragile", "tired", "refuse_trip", "guilt", "pet_leaves", "followed":
				res["cost"] = true
			"rations", "morale", "dirty_water":
				if float(e.get("n", 0)) < 0.0:
					res["cost"] = true
			"schedule":
				if not events.has(str(e.get("event", ""))):
					_err("event '%s' option '%s' schedules unknown event '%s'" % [eid, oid, str(e.get("event", ""))])
				else:
					var target: Dictionary = events[str(e.get("event", ""))]
					if str(target.get("mood", "")) == "bad":
						res["cost"] = true
			"chain":
				if not (str(e.get("chain", "")) in DataSchema.CHAINS):
					_err("event '%s' option '%s' refers to unknown chain '%s'" % [eid, oid, str(e.get("chain", ""))])
				if str(e.get("step", "")) == "miss":
					res["cost"] = true
			"chance":
				var a: Dictionary = _check_effects(eid, oid, e.get("then", []), events, items)
				var b: Dictionary = _check_effects(eid, oid, e.get("else", []), events, items)
				res["fatal"] = bool(res["fatal"]) or bool(a["fatal"]) or bool(b["fatal"])
				res["cost"] = bool(res["cost"]) or bool(a["cost"]) or bool(b["cost"])
			"supply_drop", "reveal_cache":
				var its: Dictionary = e.get("items", {})
				for k in its.keys():
					if not items.has(str(k)):
						_err("event '%s' option '%s' %s names unknown item '%s'" % [eid, oid, op, str(k)])
	return res


## House Rules (section 7): a fixed order, a concrete bonus and cost, a morale hit, a narrator remark.
func _check_rules(rules: Dictionary) -> void:
	var orders: Dictionary = {}
	for rid in rules.keys():
		var r: Dictionary = rules[rid]
		for k in ["name", "order", "bonus", "cost", "morale_hit", "narrator_line"]:
			if str(r.get(k, "")) == "":
				_err("house_rules.csv: '%s' has no %s" % [rid, k])
		if not str(r.get("order", "")).is_valid_int() or orders.has(str(r.get("order", ""))):
			_err("house_rules.csv: '%s' needs a unique whole-number order" % rid)
		orders[str(r.get("order", ""))] = true
		if not str(r.get("morale_hit", "")).is_valid_int():
			_err("house_rules.csv: '%s' morale_hit must be a whole number" % rid)
		if not (str(r.get("needs", "")) in DataSchema.RULE_NEEDS):
			_err("house_rules.csv: '%s' has unknown needs '%s'" % [rid, str(r.get("needs", ""))])
		if _word_count(str(r.get("narrator_line", ""))) > MAX_NARRATION_WORDS:
			_err("house_rules.csv: '%s' narrator line is over %d words" % [rid, MAX_NARRATION_WORDS])
	if not rules.is_empty() and rules.size() < 7:
		_err("house_rules.csv: %d rules (section 7 lists 7)" % rules.size())


func _check_afflictions(afflictions: Dictionary) -> void:
	for a in DataSchema.AFFLICTIONS:
		if not afflictions.has(a):
			_err("afflictions.csv: missing '%s'" % a)
	for aid in afflictions.keys():
		var r: Dictionary = afflictions[aid]
		if not (str(aid) in DataSchema.AFFLICTIONS):
			_err("afflictions.csv: unknown affliction '%s'" % aid)
		for k in ["name", "effect", "onset", "recover", "warning_1", "warning_2", "warning_3"]:
			if str(r.get(k, "")) == "":
				_err("afflictions.csv: '%s' has no %s" % [aid, k])
		for k in ["warning_1", "warning_2", "warning_3"]:
			if _word_count(str(r.get(k, ""))) > MAX_NARRATION_WORDS + 2:
				_err("afflictions.csv: '%s' %s is too long" % [aid, k])
			if str(r.get(k, "")).find("{name}") == -1:
				_err("afflictions.csv: '%s' %s must name the person ({name})" % [aid, k])


func _check_achievements(achievements: Dictionary) -> void:
	for aid in achievements.keys():
		var r: Dictionary = achievements[aid]
		for k in ["name", "description", "condition"]:
			if str(r.get(k, "")) == "":
				_err("achievements.csv: '%s' has no %s" % [aid, k])
		var ck: String = str(r.get("condition", "")).get_slice(":", 0)
		if not (ck in Achievements.CONDITIONS):
			_err("achievements.csv: '%s' has unknown condition '%s'" % [aid, ck])
		if ck.begins_with("survive") or ck == "days":
			_err("achievements.csv: '%s' rewards hiding in the shelter (section 14)" % aid)
	if not achievements.is_empty() and achievements.size() < 30:
		_err("achievements.csv: %d achievements (section 14 asks for 30+)" % achievements.size())


## Strangers (section 7): rare, at most one per run (the director enforces it), each with an
## item-gated option of its own.
func _check_strangers(events: Dictionary) -> void:
	var n: int = 0
	for eid in events.keys():
		var ev: Dictionary = events[eid]
		if not bool(ev.get("stranger", false)):
			continue
		n += 1
		if bool(ev.get("system", false)):
			_err("stranger event '%s' can't be a system event" % eid)
		var gated: bool = false
		for o_v in ev.get("options", []):
			if str((o_v as Dictionary).get("item", "")) != "":
				gated = true
		if not gated:
			_err("stranger event '%s' needs an item-gated option" % eid)


func _check_later_triggers(events: Dictionary, narration: Dictionary) -> void:
	var triggers: Dictionary = {}
	for nid in narration.keys():
		triggers[str((narration[nid] as Dictionary).get("trigger", ""))] = true
	for eid in events.keys():
		for o_v in (events[eid] as Dictionary).get("options", []):
			for e_v in _flat_effects((o_v as Dictionary).get("effects", [])):
				var e: Dictionary = e_v
				if str(e.get("do", "")) == "later" and e.has("trigger") and not triggers.has(str(e["trigger"])):
					_err("event '%s' brings up narration trigger '%s', which has no lines" % [eid, str(e["trigger"])])


static func _flat_effects(effs: Array) -> Array:
	var out: Array = []
	for e_v in effs:
		if e_v is Dictionary:
			out.append(e_v)
			out.append_array(_flat_effects((e_v as Dictionary).get("then", [])))
			out.append_array(_flat_effects((e_v as Dictionary).get("else", [])))
	return out


func _check_tokens(eid: String, text: String) -> void:
	var rx := RegEx.new()
	rx.compile("\\{[a-z_]+\\}")
	for m in rx.search_all(text):
		if not (m.get_string() in DataSchema.TEXT_TOKENS):
			_err("event '%s' uses unknown placeholder %s" % [eid, m.get_string()])


## Every core item must gate at least 3 events; every makeshift item at least 1 (as an option's
## item, or as the makeshift stand-in an option accepts: its "alt" list).
func _check_item_coverage(items: Dictionary, events: Dictionary) -> void:
	var gates: Dictionary = {}
	for eid in events.keys():
		var ev: Dictionary = events[eid]
		var seen: Dictionary = {}
		for o_v in ev.get("options", []):
			var ids: Array = [str((o_v as Dictionary).get("item", ""))]
			for a_v in (o_v as Dictionary).get("alt", []):
				ids.append(str((a_v as Dictionary).get("item", "")) if a_v is Dictionary else str(a_v))
			for it_v in ids:
				var it: String = str(it_v)
				if it != "" and not seen.has(it):
					seen[it] = true
					gates[it] = int(gates.get(it, 0)) + 1
	out["item_gate_counts"] = gates
	for iid in items.keys():
		var cat: String = str((items[iid] as Dictionary).get("category", ""))
		var need: int = 3 if cat == "core" else (1 if cat == "makeshift" else 0)
		if int(gates.get(iid, 0)) < need:
			_err("item '%s' (%s) gates %d events (needs %d)" % [iid, cat, int(gates.get(iid, 0)), need])


## Makeshift stand-ins ("alt" on an item option): the option names a core item, the stand-in is a
## makeshift item, and rescue steps never accept one (makeshift items can't meet rescue or ending
## conditions, section 10). An option that hands the real item over can't take a stand-in either.
func _check_alts(events: Dictionary, items: Dictionary) -> void:
	for eid in events.keys():
		var ev: Dictionary = events[eid]
		for o_v in ev.get("options", []):
			var o: Dictionary = o_v
			var alts: Array = o.get("alt", [])
			if alts.is_empty():
				continue
			var oid: String = str(o.get("id", ""))
			if str(o.get("item", "")) == "":
				_err("event '%s' option '%s' lists a makeshift stand-in but needs no item" % [eid, oid])
			if ev.has("chain") or str(ev.get("type", "")) == "rescue":
				_err("event '%s' is a rescue step; option '%s' can't accept a makeshift stand-in" % [eid, oid])
			for e_v in _flat_effects(o.get("effects", [])):
				var e: Dictionary = e_v
				if str(e.get("do", "")) in ["chain", "end_run", "give"]:
					_err("event '%s' option '%s' %s, so it can't accept a makeshift stand-in" % [eid, oid, str(e.get("do", ""))])
			for a_v in alts:
				if not (a_v is Dictionary):
					_err("event '%s' option '%s' alt entries must be objects" % [eid, oid])
					continue
				var a: Dictionary = a_v
				var ai: String = str(a.get("item", ""))
				if str((items.get(ai, {}) as Dictionary).get("category", "")) != "makeshift":
					_err("event '%s' option '%s' alt '%s' is not a makeshift item" % [eid, oid, ai])
				var pv: float = float(a.get("p", 1.0))
				if pv <= 0.0 or pv > 1.0:
					_err("event '%s' option '%s' alt '%s' has p %.2f (0-1)" % [eid, oid, ai, pv])
				if a.has("fail"):
					_check_effects(eid, oid, a.get("fail", []), events, items)


## Each recipe part must come from junk found in at least 2 place types.
func _check_recipe_parts(items: Dictionary, loot: Dictionary, recipes: Dictionary) -> void:
	var sources: Dictionary = {}   # part -> {place_type: true}
	for pt in loot.keys():
		for iid in (loot[pt] as Dictionary).keys():
			var it: Dictionary = items.get(iid, {})
			if str(it.get("category", "")) != "junk":
				continue
			for part in (it.get("scrap", {}) as Dictionary).keys():
				if not sources.has(part):
					sources[part] = {}
				(sources[part] as Dictionary)[pt] = true
	for rid in recipes.keys():
		for part in ((recipes[rid] as Dictionary)["parts"] as Dictionary).keys():
			if str(part) == "match":
				continue
			var n: int = (sources.get(part, {}) as Dictionary).size()
			if n < 2:
				_err("recipe '%s': part '%s' comes from junk in %d place types (needs 2)" % [rid, str(part), n])


func _check_banned_text(items: Dictionary, events: Dictionary, narration: Dictionary, rules: Dictionary, achievements: Dictionary, afflictions: Dictionary = {}) -> void:
	var texts: Array = []  # [where, text]
	for iid in items.keys():
		var it: Dictionary = items[iid]
		for k in ["name", "purpose", "almanac"]:
			texts.append(["item %s" % iid, str(it[k])])
		for v in it["variants"]:
			texts.append(["item %s" % iid, str(v)])
	for eid in events.keys():
		var ev: Dictionary = events[eid]
		texts.append(["event %s" % eid, str(ev.get("title", "")) + " " + str(ev.get("setup", ""))])
		for o_v in ev.get("options", []):
			var o: Dictionary = o_v
			texts.append(["event %s" % eid, str(o.get("label", "")) + " " + str(o.get("outcome", "")) + " " + str(o.get("stakes", ""))])
	for nid in narration.keys():
		texts.append(["narration %s" % nid, str((narration[nid] as Dictionary)["text"])])
	for t in [rules, achievements, afflictions]:
		for k in t.keys():
			texts.append(["table row %s" % k, " ".join((t[k] as Dictionary).values())])
	for pair in texts:
		var hit: String = find_banned(str(pair[1]))
		if hit != "":
			_err("%s uses banned word '%s'" % [str(pair[0]), hit])


## Returns the first banned word or brand found (whole words, case-sensitive), or "".
static func find_banned(text: String) -> String:
	for w in DataSchema.BANNED_WORDS + DataSchema.BANNED_BRANDS:
		var rx := RegEx.new()
		rx.compile("(?<![A-Za-z])" + _rx_escape(w) + "(?![A-Za-z])")
		if rx.search(text) != null:
			return w
	return ""


static func _rx_escape(s: String) -> String:
	var outs: String = ""
	for ch in s:
		if ch in ".^$*+?()[]{}|\\-":
			outs += "\\" + ch
		else:
			outs += ch
	return outs


func _check_assets(items: Dictionary, manifest: Array) -> void:
	var listed: Dictionary = {}
	for r_v in manifest:
		listed["res://" + str((r_v as Dictionary).get("path", ""))] = true
	for iid in items.keys():
		var icon: String = str((items[iid] as Dictionary)["icon"])
		if icon != "" and not listed.has(icon):
			_err("item '%s' icon %s has no assets_manifest.csv row" % [iid, icon])
	# Every shipped third-party file under assets/ needs a row (sources and imports excluded).
	for p in _list_files("res://assets"):
		if p.ends_with(".import") or p.ends_with(".gdignore") or p.find("/source/") != -1 or p.ends_with(".md"):
			continue
		if not listed.has(p):
			_err("%s is not in assets_manifest.csv" % p)


static func _list_files(root: String) -> Array[String]:
	var res: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return res
	for f in dir.get_files():
		res.append(root + "/" + f)
	for d in dir.get_directories():
		if FileAccess.file_exists(root + "/" + d + "/.gdignore"):
			continue
		res.append_array(_list_files(root + "/" + d))
	return res


static func _word_count(s: String) -> int:
	var n: int = 0
	for w in s.split(" ", false):
		if w.strip_edges() != "" and w.strip_edges() != "—" and w.strip_edges() != "→":
			n += 1
	return n


# ---------------------------------------------------------------- output

func _write_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILD_DIR))
	for k in ["items", "loot", "balance", "parts", "recipes", "chapters", "narration", "house_rules", "achievements", "afflictions", "events"]:
		_write_json(BUILD_DIR + "/" + k + ".json", out[k])
	_write_credits()


static func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t", true) + "\n")


## CREDITS.md is generated from data/assets_manifest.csv (never edit it by hand).
func _write_credits() -> void:
	var by_section: Dictionary = {}
	var icon_authors: Dictionary = {}
	for r_v in out["assets"]:
		var r: Dictionary = r_v
		if str(r.get("kind", "")) == "icon":
			var a: String = str(r.get("author", ""))
			if not icon_authors.has(a):
				icon_authors[a] = []
			(icon_authors[a] as Array).append("[%s](%s)" % [str(r.get("title", "")).replace(" (recoloured)", ""), str(r.get("source_url", ""))])
		else:
			var sec: String = str(r.get("kind", "other"))
			if not by_section.has(sec):
				by_section[sec] = []
			(by_section[sec] as Array).append(r)
	var md: String = "# Credits\n\n_Generated from `data/assets_manifest.csv` by `tools/build_data.gd`. Do not edit by hand._\n\n"
	md += "## Engine\n\n- [Godot Engine](https://godotengine.org) 4.3 (MIT). Copyright (c) 2014-present Godot Engine contributors; (c) 2007-2014 Juan Linietsky, Ariel Manzur.\n\n"
	md += "## Map data\n\n- Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, available under the Open Database License (ODbL).\n\n"
	md += "## 3D and textures (CC0)\n\n"
	md += _rows_md(by_section.get("model", []) + by_section.get("texture", []), "_None yet._")
	md += "\n## Attribution required\n\n### Icons — game-icons.net (CC BY 3.0)\n\nIcons from [game-icons.net](https://game-icons.net), licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), recoloured to the game palette.\n\n"
	var authors: Array = icon_authors.keys()
	authors.sort()
	for a in authors:
		md += "- **%s**: %s\n" % [str(a), ", ".join(icon_authors[a])]
	md += "\n### Music and other CC BY work\n\n" + _rows_md(by_section.get("music", []) + by_section.get("sound_ccby", []), "_None yet._")
	md += "\n## Audio (no attribution required)\n\n" + _rows_md(by_section.get("sound", []), "_Sound effects are synthesized in code._")
	md += "\n## Voice\n\n" + _rows_md(by_section.get("voice", []), "_Narration is not recorded yet (lines are marked pending in `data/narration.csv`)._")
	md += "\n## Code\n\n" + _rows_md(by_section.get("code", []), "_No third-party add-ons yet._")
	md += "\n## Shaders\n\n" + _rows_md(by_section.get("shader", []), "_None yet._")
	md += "\nFull license texts are in [`/licenses/`](licenses/).\n"
	var f := FileAccess.open("res://CREDITS.md", FileAccess.WRITE)
	if f != null:
		f.store_string(md)


static func _rows_md(rows: Array, empty: String) -> String:
	if rows.is_empty():
		return empty + "\n"
	var s: String = ""
	for r_v in rows:
		var r: Dictionary = r_v
		s += "- %s by %s — [source](%s), %s\n" % [str(r.get("title", "")), str(r.get("author", "")), str(r.get("source_url", "")), str(r.get("license", ""))]
	return s
