class_name Workbench
extends Control

## The bench (section 10). Three ways in:
## * "browse" (the Bench button): the part shelf, junk to take apart, recipes and the Need toggle;
## * "craft" for one survivor: pick two Quick recipes or one Day recipe for today;
## * "study" for one survivor: pick a chapter of the manual.
## Taking junk apart is instant and free (it changes the shelf at once); making and studying are
## the survivor's job for the day and happen at night (ShelterSim._apply_jobs).
##
## Recipe cards always read in the same order: what it's for; "Makeshift X" with the comparison;
## uses and failure %; parts you have and need (with where to find missing ones); tool and time.

signal confirmed(job: Dictionary)
signal cancelled()
signal changed()

const C_PANEL := Color("#1a1e24")
const C_RAISED := Color("#262c34")
const C_BORDER := Color("#39414b")
const C_TEXT := Color("#e8eaed")
const C_MUTED := Color("#9aa3ad")
const C_AMBER := Color("#ffb020")
const C_RED := Color("#ff4d4f")
const C_GREEN := Color("#4cc38a")
const C_WATER := Color("#4aa3ff")
const C_TAPE := Color("#d9c7a0")

var s: ShelterState
var member_id: String = ""
var mode: String = "browse"        # browse | craft | study
var picks: Array = []              # [{id, target}] for craft mode
var show_all: bool = false

var _left: VBoxContainer
var _cards: VBoxContainer
var _bottom: HBoxContainer
var _title: Label
var _sub: Label
var _ok: Button


func setup(state: ShelterState, mid: String, how: String, current: Dictionary = {}) -> void:
	s = state
	member_id = mid
	mode = how
	if mode == "craft":
		for r_v in current.get("recipes", []):
			picks.append((r_v as Dictionary).duplicate() if r_v is Dictionary else {"id": str(r_v)})


func _ready() -> void:
	name = "Workbench"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(1232, 672)
	panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_BORDER, 10))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_title = _label("", 18, C_AMBER)
	v.add_child(_title)
	_sub = _label("", 12, C_MUTED, true)
	v.add_child(_sub)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(400, 0)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(ls)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", 4)
	ls.add_child(_left)
	var rs := ScrollContainer.new()
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(rs)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 6)
	rs.add_child(_cards)
	_bottom = HBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 10)
	v.add_child(_bottom)
	_refresh()


func _member() -> Dictionary:
	return s.member(member_id)


# ---------------------------------------------------------------- building blocks

func _label(text: String, px: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _box(bg: Color, border: Color, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


func _button(text: String, bg: Color, fg: Color, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_disabled_color", C_MUTED.darkened(0.3))
	b.add_theme_stylebox_override("normal", _box(bg, bg.lightened(0.25), 8))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), C_AMBER, 8))
	b.add_theme_stylebox_override("pressed", _box(bg.lightened(0.12), C_AMBER, 8))
	b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.35), C_BORDER, 8))
	return b


func _icon(item_id: String, px: int, silhouette: bool = false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ItemDB.get_icon_texture(item_id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.tooltip_text = ItemDB.tooltip_line(item_id) if not silhouette else ""
	if silhouette:
		t.modulate = Color(0.05, 0.05, 0.06, 0.9)
	return t


func _part_row(parts: Dictionary, px: int = 16, col: Color = C_TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for pid in ShelterData.part_ids():
		if int(parts.get(pid, 0)) <= 0:
			continue
		row.add_child(PartIcon.make(pid, px))
		row.add_child(_label("%d %s" % [int(parts[pid]), ShelterCraft.part_name(pid)], 12, col))
	return row


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	# Remove the old controls right away so the new ones keep their names (tests click by name).
	for box in [_left, _cards, _bottom]:
		for c in (box as Node).get_children():
			(box as Node).remove_child(c)
			c.queue_free()
	var who: Dictionary = _member()
	var nm: String = str(who.get("name", "someone"))
	match mode:
		"craft":
			_title.text = "What should %s make today?" % nm
		"study":
			_title.text = "Which chapter should %s study today?" % nm
		_:
			_title.text = "The workbench"
	var fail_bits: String = "Crafting fails %d%% of the time%s." % [int(round(100.0 * ShelterCraft.fail_chance(s, who if not who.is_empty() else {}))), " (the manual is on the shelf)" if s.has("manual") else " (5% with the manual on the shelf)"]
	_sub.text = "Parts %d/%d. Taking junk apart is free; making something takes a survivor's day (two Quick recipes or one Day recipe). %s" % [ShelterCraft.parts_total(s), ShelterData.Bi("part_shelf_max", 12), fail_bits]
	_build_left()
	if mode == "study":
		_build_study()
	else:
		_build_cards()
	_build_bottom()


func _build_left() -> void:
	_left.add_child(_label("PART SHELF  %d/%d" % [ShelterCraft.parts_total(s), ShelterData.Bi("part_shelf_max", 12)], 11, C_MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	for pid in ShelterData.part_ids():
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(PartIcon.make(pid, 18))
		var n: int = int(s.parts.get(pid, 0))
		var tagged: bool = s.need_parts.has(pid)
		cell.add_child(_label("%s %d%s" % [ShelterCraft.part_name(pid), n, "  NEED" if tagged else ""], 12, C_AMBER if tagged else (C_TEXT if n > 0 else C_MUTED)))
		cell.tooltip_text = "%s: from %s" % [ShelterCraft.part_name(pid), ", ".join(ShelterCraft.part_sources(pid).map(func(pt: Variant) -> String: return ShelterCraft.place_type_word(str(pt))))]
		grid.add_child(cell)
	_left.add_child(grid)
	_left.add_child(HSeparator.new())
	_left.add_child(_label("JUNK AND BROKEN GEAR (taking apart is free)", 11, C_MUTED))
	var salv: Array = ShelterCraft.salvage_list(s)
	if salv.is_empty():
		_left.add_child(_label("Nothing to take apart. Junk turns up in the house, in stores and in neighbours' homes.", 12, C_MUTED, true))
	for e_v in salv:
		var e: Dictionary = e_v
		var iid: String = str(e["item"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.add_child(_icon(iid, 20))
		var need_hit: bool = ShelterCraft.junk_matches_need(iid, s.need_parts) and not bool(e["broken"])
		var txt: String = "%s%s ×%d → %s" % ["Broken " if bool(e["broken"]) else "", ShelterData.item_name(iid).to_lower() if bool(e["broken"]) else ShelterData.item_name(iid), int(e["count"]), ShelterCraft.parts_text(e["yield"])]
		var l := _label(txt, 12, C_AMBER if need_hit else C_TEXT, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var tb := _button("Take apart", C_RAISED, C_TEXT, Vector2(86, 26))
		tb.name = "TakeApart_" + iid + ("_broken" if bool(e["broken"]) else "")
		var y_total: int = 0
		for k in (e["yield"] as Dictionary).keys():
			y_total += int(e["yield"][k])
		if ShelterCraft.shelf_room(s) < y_total:
			tb.tooltip_text = "Only room for %d more part%s: the rest is thrown out." % [ShelterCraft.shelf_room(s), "" if ShelterCraft.shelf_room(s) == 1 else "s"]
		var broken: bool = bool(e["broken"])
		tb.pressed.connect(func() -> void: _take_apart(iid, broken))
		row.add_child(tb)
		_left.add_child(row)
	if s.dirty_water > 0:
		_left.add_child(HSeparator.new())
		_left.add_child(_label("Dirty water: %d ration%s. A Bottle Filter makes up to %d a night drinkable." % [s.dirty_water, "" if s.dirty_water == 1 else "s", ShelterData.Bi("filter_jug_rations", 4)], 12, C_WATER, true))
	var made: Array = []
	for iid in ShelterData.ids_in("makeshift"):
		if s.count(iid) > 0:
			made.append(iid)
	if not made.is_empty():
		_left.add_child(HSeparator.new())
		_left.add_child(_label("MAKESHIFT ON THE SHELF", 11, C_MUTED))
		for iid in made:
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 5)
			row2.add_child(_icon(str(iid), 20))
			var uses: int = ShelterCraft.uses_left(s, str(iid))
			row2.add_child(_label("%s%s%s" % [ShelterData.item_name(str(iid)), " ×%d" % s.count(str(iid)) if s.count(str(iid)) > 1 else "", " · %d use%s left" % [uses, "" if uses == 1 else "s"] if uses > 0 else ""], 12, C_TEXT))
			_left.add_child(row2)
	_left.add_child(HSeparator.new())
	_left.add_child(_label("THE MANUAL", 11, C_MUTED))
	for ch in ShelterCraft.chapter_ids():
		var c: Dictionary = ShelterData.chapter(str(ch))
		var learned: String = str(s.chapters.get(str(ch), ""))
		var t: String = "Ch.%d %s: %s" % [int(c.get("order", 0)), str(c.get("title", "")), ", ".join(ShelterCraft.chapter_recipes(str(ch)))]
		var how: String = (" (learned from %s)" % ("the manual" if learned == "manual" else str(c.get("pamphlet", "a pamphlet")))) if learned != "" else ""
		_left.add_child(_label(t + how, 12, C_GREEN if learned != "" else C_MUTED, true))


## Cards: what it's for; Makeshift X with the comparison; uses and failure %; parts; tool and time.
func _build_cards() -> void:
	var hdr := HBoxContainer.new()
	hdr.add_child(_label("RECIPES" + ("" if show_all else " YOU CAN MAKE (or are 1 part short of)"), 11, C_MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	var all_b := _button("Show all recipes" if not show_all else "Show what I can make", C_RAISED, C_TEXT, Vector2(150, 24))
	all_b.name = "ShowAll"
	all_b.pressed.connect(func() -> void:
		show_all = not show_all
		_refresh())
	hdr.add_child(all_b)
	_cards.add_child(hdr)
	var who: Dictionary = _member()
	var shown: int = 0
	for rid_v in ShelterCraft.recipe_ids():
		var rid: String = str(rid_v)
		var r: Dictionary = ShelterData.recipe(rid)
		var known: bool = ShelterCraft.known(s, rid)
		var target: String = ""
		if str(r.get("makes", "")) == "patch" and not ShelterCraft.patch_targets(s).is_empty():
			target = ShelterCraft.patch_targets(s)[0]
		var need: Dictionary = ShelterCraft.parts_needed(s, rid, target)
		var short: Dictionary = ShelterCraft.short_by(s, need)
		var near: bool = known and ShelterCraft.short_count(short) <= 1
		if str(r.get("makes", "")) == "patch" and target == "":
			near = false   # nothing broken to patch
		if not show_all and not near:
			continue
		shown += 1
		if not known:
			_cards.add_child(_locked_card(rid))
			continue
		_cards.add_child(_card(rid, r, need, short, target, who))
	if shown == 0:
		_cards.add_child(_label("Nothing you can make right now. \"Show all recipes\" lists what each one needs and where to find the parts.", 13, C_MUTED, true))


func _locked_card(rid: String) -> PanelContainer:
	var r: Dictionary = ShelterData.recipe(rid)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("#14171b"), C_BORDER, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var makes: String = str(r.get("makes", ""))
	h.add_child(_icon(makes if ShelterData.has_item(makes) else "manual", 34, true))
	var v := VBoxContainer.new()
	v.add_child(_label(str(r.get("name", rid)), 14, C_MUTED))
	v.add_child(_label("Locked: " + ShelterCraft.unlock_label(rid), 12, C_MUTED))
	h.add_child(v)
	return card


func _card(rid: String, r: Dictionary, need: Dictionary, short: Dictionary, target: String, who: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_" + rid
	var picked: int = 0
	for p_v in picks:
		if str((p_v as Dictionary).get("id", "")) == rid:
			picked += 1
	card.add_theme_stylebox_override("panel", _box(C_RAISED if picked == 0 else Color("#1f3326"), C_TAPE.darkened(0.4) if short.is_empty() else C_BORDER, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var makes: String = str(r.get("makes", ""))
	h.add_child(_icon(makes if ShelterData.has_item(makes) else (target if target != "" else "manual"), 40))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	# 1. What it's for
	var title_row := HBoxContainer.new()
	title_row.add_child(_label(str(r.get("name", rid)), 15, C_TEXT))
	title_row.add_child(_label("  —  " + str(r.get("purpose", "")), 13, C_TEXT))
	v.add_child(title_row)
	# 2. Makeshift X, compared with the real thing
	var cmp: String = str(r.get("compare", ""))
	if makes == "patch" and target != "":
		cmp += " — would patch the %s" % ShelterData.item_name(target).to_lower()
	v.add_child(_label(cmp, 12, C_TAPE, true))
	# 3. Uses and failure %
	var uses: int = ShelterCraft.max_uses(makes) if ShelterData.has_item(makes) else 1
	var fail_p: float = ShelterCraft.fail_chance(s, who) if not who.is_empty() else ShelterCraft.fail_chance(s, {})
	v.add_child(_label("%s · fails %d%%" % [("%d use%s" % [uses, "" if uses == 1 else "s"]) if uses > 0 else "until it breaks", int(round(fail_p * 100.0))], 12, C_MUTED))
	# 4. Parts you have and need
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 4)
	var have: Dictionary = ShelterCraft.parts_reachable(s)
	for pid in ShelterData.part_ids():
		if not need.has(pid):
			continue
		prow.add_child(PartIcon.make(pid, 16))
		var miss: bool = short.has(pid)
		prow.add_child(_label("%d/%d %s" % [mini(int(have.get(pid, 0)), int(need[pid])), int(need[pid]), ShelterCraft.part_name(pid)], 12, C_RED if miss else C_GREEN))
	if makes == "patch" and target == "":
		prow.add_child(_label("+1 part matching a broken item", 12, C_MUTED))
	v.add_child(prow)
	for pid in short.keys():
		var src: Array = ShelterCraft.part_sources(str(pid)).map(func(pt: Variant) -> String: return ShelterCraft.place_type_word(str(pt)))
		v.add_child(_label("Need %d %s: junk from %s" % [int(short[pid]), ShelterCraft.part_name(str(pid)), ", ".join(src)], 11, C_RED, true))
	# 5. Tool and time
	var tool: String = str(r.get("tool", ""))
	var tt: String = ("Tool: %s · " % ShelterData.item_name(tool)) if tool != "" else ""
	tt += "Day (the whole day)" if str(r.get("time", "")) == "day" else "Quick (two a day)"
	if tool != "" and not s.has(tool):
		v.add_child(_label(tt + " — no %s on the shelf" % ShelterData.item_name(tool).to_lower(), 12, C_RED))
	else:
		v.add_child(_label(tt, 12, C_MUTED))
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)
	h.add_child(btns)
	var need_on: bool = false
	for pid in (short.keys() if not short.is_empty() else need.keys()):
		if s.need_parts.has(pid):
			need_on = true
	var nb := _button("Need ✓" if need_on else "Need", Color("#3a2a10") if need_on else C_RAISED, C_AMBER, Vector2(84, 26))
	nb.name = "Need_" + rid
	nb.tooltip_text = "Tag the parts this needs: junk holding them is looted first and highlighted in the house and in stores."
	nb.pressed.connect(func() -> void:
		ShelterCraft.toggle_need(s, rid)
		SoundManager.play_sfx("button_click")
		changed.emit()
		_refresh())
	btns.add_child(nb)
	if mode == "craft":
		var why: String = ShelterCraft.can_make(s, who, rid, target, picks)
		var mb := _button("Make" + (" (%d)" % picked if picked > 0 else ""), Color("#1f3326"), C_GREEN, Vector2(84, 26))
		mb.name = "Make_" + rid
		mb.disabled = why != ""
		mb.tooltip_text = why if why != "" else "Add to %s's bench today" % str(who.get("name", ""))
		mb.pressed.connect(func() -> void:
			picks.append({"id": rid, "target": target})
			SoundManager.play_sfx("button_click")
			_refresh())
		btns.add_child(mb)
		if why != "" and why != "Two Quick recipes a day" and why != "A Day recipe takes the whole day":
			btns.add_child(_label(_short(why, 22), 10, C_RED))
	return card


func _short(t: String, n: int) -> String:
	return t if t.length() <= n else t.substr(0, n - 1) + "…"


func _build_study() -> void:
	var who: Dictionary = _member()
	_cards.add_child(_label("A day with the manual unlocks one chapter for the rest of the run. Pamphlets found on trips unlock a chapter without it.", 13, C_MUTED, true))
	for ch_v in ShelterCraft.chapter_ids():
		var ch: String = str(ch_v)
		var c: Dictionary = ShelterData.chapter(ch)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _box(C_RAISED, C_BORDER, 8))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_label("Ch.%d %s" % [int(c.get("order", 0)), str(c.get("title", ""))], 15, C_TEXT))
		v.add_child(_label("Recipes: " + ", ".join(ShelterCraft.chapter_recipes(ch)), 12, C_MUTED, true))
		v.add_child(_label("Or find %s at %s." % [str(c.get("pamphlet", "")), " or ".join((c.get("pamphlet_places", []) as Array).map(func(pt: Variant) -> String: return ShelterCraft.place_type_word(str(pt))))], 11, C_MUTED, true))
		h.add_child(v)
		var why: String = ShelterCraft.can_study(s, who, ch)
		var b := _button("Learned" if s.chapters.has(ch) else "Study this", Color("#13304a"), C_WATER, Vector2(110, 30))
		b.name = "Study_" + ch
		b.disabled = why != ""
		b.tooltip_text = why
		b.pressed.connect(func() -> void: confirmed.emit({"job": "study", "chapter": ch}))
		h.add_child(b)
		_cards.add_child(row)


func _build_bottom() -> void:
	if mode == "craft":
		var names: Array[String] = []
		for p_v in picks:
			var r: Dictionary = ShelterData.recipe(str((p_v as Dictionary).get("id", "")))
			names.append(str(r.get("name", "")))
		var l := _label("Today: " + (", ".join(names) if not names.is_empty() else "nothing yet"), 13, C_TEXT, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bottom.add_child(l)
		var clear := _button("Clear", C_RAISED, C_TEXT, Vector2(80, 34))
		clear.disabled = picks.is_empty()
		clear.pressed.connect(func() -> void:
			picks.clear()
			_refresh())
		_bottom.add_child(clear)
	else:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bottom.add_child(sp)
	var back := _button("Back", C_RAISED, C_TEXT, Vector2(100, 34))
	back.name = "Back"
	back.pressed.connect(func() -> void: cancelled.emit())
	_bottom.add_child(back)
	if mode == "craft":
		_ok = _button("At the bench tonight", Color("#1f3326"), C_GREEN, Vector2(190, 34))
		_ok.name = "Confirm"
		_ok.disabled = picks.is_empty()
		_ok.pressed.connect(func() -> void: confirmed.emit({"job": "craft", "recipes": picks.duplicate(true)}))
		_bottom.add_child(_ok)


func _take_apart(iid: String, broken: bool) -> void:
	var r: Dictionary = ShelterCraft.take_apart(s, iid, broken)
	if bool(r.get("ok", false)):
		SoundManager.play_sfx("button_click")
	changed.emit()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		cancelled.emit()
		get_viewport().set_input_as_handled()


## A part's icon: its own shape and colour (readable without colour).
class PartIcon extends Control:
	var part_id: String = ""

	static func make(pid: String, px: int) -> PartIcon:
		var p := PartIcon.new()
		p.part_id = pid
		p.custom_minimum_size = Vector2(px, px)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		p.tooltip_text = ShelterCraft.part_name(pid)
		return p

	func _draw() -> void:
		PartIcon.draw_part(self, Rect2(Vector2.ZERO, size), part_id)

	static func draw_part(ci: CanvasItem, r: Rect2, pid: String) -> void:
		var d: Dictionary = ShelterData.part(pid)
		var col := Color(str(d.get("color", "#e8eaed")))
		var c: Vector2 = r.get_center()
		var h: float = minf(r.size.x, r.size.y) * 0.46
		var pts := PackedVector2Array()
		match str(d.get("shape", "circle")):
			"square":
				pts = PackedVector2Array([c + Vector2(-h, -h) * 0.85, c + Vector2(h, -h) * 0.85, c + Vector2(h, h) * 0.85, c + Vector2(-h, h) * 0.85])
			"hexagon":
				for i in range(6):
					pts.append(c + Vector2.from_angle(TAU * float(i) / 6.0) * h)
			"diamond":
				pts = PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.8, 0), c + Vector2(0, h), c + Vector2(-h * 0.8, 0)])
			"triangle":
				pts = PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, h * 0.8), c + Vector2(-h, h * 0.8)])
			"drop":
				# A teardrop: the tip, then a round bottom from the right side, under, and up the left.
				pts.append(c + Vector2(0, -h))
				for i in range(15):
					var a: float = deg_to_rad(-35.0 + 250.0 * float(i) / 14.0)
					pts.append(c + Vector2(0, h * 0.32) + Vector2(cos(a), sin(a)) * h * 0.62)
			_:
				for i in range(18):
					pts.append(c + Vector2.from_angle(TAU * float(i) / 18.0) * h)
		ci.draw_colored_polygon(pts, col)
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		ci.draw_polyline(outline, Color(0, 0, 0, 0.55), 1.2, true)
