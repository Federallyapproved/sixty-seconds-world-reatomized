extends Node

## M1 content pipeline checks (section 11): the tables build cleanly, the committed build matches
## the sources, and the validator really rejects each kind of broken content.
## godot --headless --path . -s res://tests/pass2/run.gd -- --suite=../m1/data_pipeline_suite

var _passes: int = 0
var _fails: Array[String] = []


func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] ", label)
	else:
		_fails.append(label)
		print("[FAIL] ", label)


func run() -> int:
	var res: Dictionary = DataBuilder.build(false)
	var errs: Array = res["errors"]
	for e in errs:
		print("  build error: ", e)
	_ok(errs.is_empty(), "data/ builds with no validation errors (%d errors)" % errs.size())
	var out: Dictionary = res["out"]
	_check_build_is_current(out)
	_check_items(out)
	_check_events(out)
	_check_validator_rejects()
	_check_banned_words_in_code()
	print("DATA_PIPELINE passes=%d fails=%d" % [_passes, _fails.size()])
	for f in _fails:
		print("  FAIL: ", f)
	return 0 if _fails.is_empty() else 1


## data/build/*.json on disk must equal what the sources compile to (no stale build committed).
func _check_build_is_current(out: Dictionary) -> void:
	for k in ["items", "loot", "balance", "events", "narration"]:
		var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/build/%s.json" % k))
		var fresh: Variant = JSON.parse_string(JSON.stringify(out[k]))
		_ok(on_disk != null and JSON.stringify(on_disk) == JSON.stringify(fresh), "data/build/%s.json matches the sources (rerun tools/build_data.gd if not)" % k)


func _check_items(out: Dictionary) -> void:
	var items: Dictionary = out["items"]
	var core: int = 0
	for k in items.keys():
		var it: Dictionary = items[k]
		if str(it["category"]) == "core":
			core += 1
		_ok(int(it["slots"]) >= 1 and int(it["slots"]) <= 3, "%s takes 1-3 slots" % k)
		_ok(ResourceLoader.exists(str(it["icon"])), "%s icon loads (%s)" % [k, str(it["icon"])])
		_ok(str(it["purpose"]) != "" and ItemDB.tooltip_line(str(k)).find("[%d]" % int(it["slots"])) != -1, "%s tooltip shows name, slots and purpose: %s" % [k, ItemDB.tooltip_line(str(k))])
	_ok(core == 16, "exactly the 16 core items (%d)" % core)
	for gone in ["toolbox", "checkers", "harmonica", "soup", "book"]:
		_ok(not items.has(gone), "removed item '%s' is gone" % gone)
	var expect_slots: Dictionary = {"medkit": 2, "suitcase": 3, "axe": 2, "rifle": 2, "food": 1, "water": 1, "console": 1}
	for k in expect_slots.keys():
		_ok(int((items[k] as Dictionary)["slots"]) == int(expect_slots[k]), "%s takes %d slots" % [k, int(expect_slots[k])])
	var gates: Dictionary = out["item_gate_counts"]
	for k in items.keys():
		if str((items[k] as Dictionary)["category"]) == "core":
			_ok(int(gates.get(k, 0)) >= 3, "core item %s gates %d events (>= 3)" % [k, int(gates.get(k, 0))])


func _check_events(out: Dictionary) -> void:
	var events: Dictionary = out["events"]
	var gated: int = 0
	var appendix: Array[String] = ["signature_required", "exterior_modification", "one_bar", "pending_update", "bunker_tour", "night_shift",
		"good_boy", "motion_detected", "unexpected_item", "cabin_fever", "fizzy_rain", "model_home"]
	for a in appendix:
		_ok(events.has(a), "Appendix A vignette '%s' is in the data" % a)
	var chains: Dictionary = {}
	for eid in events.keys():
		var ev: Dictionary = events[eid]
		var has_item: bool = false
		for o_v in ev["options"]:
			if str((o_v as Dictionary).get("item", "")) != "":
				has_item = true
		if has_item:
			gated += 1
		if ev.has("chain"):
			chains[str(ev["chain"])] = int(chains.get(str(ev["chain"]), 0)) + 1
	_ok(float(gated) / float(events.size()) >= 0.35, "about 40%% of events are item-gated (%d of %d)" % [gated, events.size()])
	for cid in DataSchema.CHAINS:
		_ok(int(chains.get(cid, 0)) >= 4, "rescue chain '%s' has %d requests (4-6)" % [cid, int(chains.get(cid, 0))])


func _event_with(opts: Array, extra: Dictionary = {}) -> Dictionary:
	var ev: Dictionary = {"id": "t", "title": "T", "setup": "A short setup.", "type": "visitor", "mood": "neutral", "options": opts}
	ev.merge(extra, true)
	return ev


func _errors_for(ev: Dictionary) -> Array:
	var b := DataBuilder.new()
	var items: Dictionary = ShelterData.items()
	b._check_event(ev, {"t": ev, "fleas": ShelterData.event("fleas")}, items)
	return b.errors


func _check_validator_rejects() -> void:
	var basic := {"id": "a", "label": "Do nothing", "outcome": "Nothing happens.", "effects": []}
	var costly := {"id": "b", "label": "Pay", "outcome": "It costs.", "effects": [{"do": "lose", "item": "water", "n": 1}]}
	var axe := {"id": "c", "label": "Chop", "item": "axe", "outcome": "Chopped.", "effects": [{"do": "use", "item": "axe"}]}
	var wait := {"id": "w", "label": "Wait it out", "outcome": "Time passes.", "effects": [{"do": "morale", "who": "all", "n": -1}]}
	_ok(_errors_for(_event_with([basic, costly])).is_empty(), "validator accepts a well-formed event")
	# M2: "2 basic choices plus 0-2 item choices" (section 8).
	_ok(not _errors_for(_event_with([axe, costly])).is_empty(), "validator rejects an event with only one option that needs no item (M2)")
	_ok(not _errors_for(_event_with([axe, {"id": "d", "label": "Spray", "item": "bug_spray", "outcome": "x", "effects": []}])).is_empty(), "validator rejects an event with no no-item option")
	_ok(not _errors_for(_event_with([axe, basic])).is_empty(), "validator rejects an item-gated event whose no-item options are all free")
	# [was: accepts [axe, costly]; M2 needs a second no-item option, so the same event plus one]
	_ok(_errors_for(_event_with([axe, costly, wait])).is_empty(), "validator accepts an item-gated event with a costly no-item option")
	var killer := {"id": "k", "label": "Wait", "outcome": "x", "effects": [{"do": "kill", "who": "random", "cause": "x"}]}
	_ok(not _errors_for(_event_with([killer, basic])).is_empty(), "validator rejects a fatal outcome without a warning kind")
	_ok(_errors_for(_event_with([killer, basic], {"warning": "fumes"})).is_empty(), "validator accepts a fatal outcome with a warning kind")
	_ok(not _errors_for(_event_with([{"id": "u", "label": "x", "outcome": "x", "effects": [{"do": "teleport"}]}, costly])).is_empty(), "validator rejects an unknown effect")
	_ok(not _errors_for(_event_with([{"id": "u", "label": "x", "outcome": "x", "effects": [{"do": "schedule", "event": "nope", "in": 1}]}, costly])).is_empty(), "validator rejects a dangling follow-up event")
	_ok(not _errors_for(_event_with([{"id": "u", "label": "x", "item": "toolbox", "outcome": "x", "effects": []}, costly])).is_empty(), "validator rejects an unknown item")
	_ok(not _errors_for(_event_with([basic, costly], {"setup": "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twentyone twentytwo twentythree twentyfour twentyfive twentysix"})).is_empty(), "validator rejects a setup over 25 words")
	_ok(not _errors_for(_event_with([basic, costly], {"setup": "Hello {nobody}."})).is_empty(), "validator rejects an unknown placeholder")
	_ok(DataBuilder.find_banned("The CONELRAD broadcast") == "CONELRAD", "banned word: CONELRAD")
	_ok(DataBuilder.find_banned("Civil Defense van") == "Civil Defense", "banned word: Civil Defense")
	_ok(DataBuilder.find_banned("a Nintendo handheld") == "Nintendo", "banned brand: Nintendo")
	_ok(DataBuilder.find_banned("She vaulted the fence") == "", "no false hit on 'vaulted'")


## The 1950s list must not come back anywhere in the game's own code and data either.
func _check_banned_words_in_code() -> void:
	var words: Array[String] = ["CONELRAD", "Civil Defense", "Civil Defence", "1958", "vacuum-tube", "vacuum tube", "DDT"]
	var hits: Array[String] = []
	for path in _files("res://scripts") + _files("res://data/events"):
		if path.ends_with("data_schema.gd"):
			continue
		var txt: String = FileAccess.get_file_as_string(path)
		for w in words:
			if txt.find(w) != -1:
				hits.append("%s: %s" % [path, w])
	for h in hits:
		print("  banned: ", h)
	_ok(hits.is_empty(), "no 1950s words in scripts/ or data/events/ (%d hits)" % hits.size())


func _files(root: String) -> Array[String]:
	var res: Array[String] = []
	var d := DirAccess.open(root)
	if d == null:
		return res
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".json"):
			res.append(root + "/" + f)
	for sub in d.get_directories():
		res.append_array(_files(root + "/" + sub))
	return res
