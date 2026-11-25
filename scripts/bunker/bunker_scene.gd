class_name BunkerScene
extends Control

## The shelter phase, one screen per day (section 3):
##   1. morning receipt (every change with a named cause),
##   2. today's dilemma card (basic options + item options; greyed "Needs: X"),
##   3. the ration row (Give/Skip food and water per person, with tomorrow's preview),
##   4. assignments (Rest, an expedition to a real place with the risk preview, a day at the
##      workbench, or a day with the manual),
##   5. End Day.
## Rules live in ShelterSim; this screen only shows the run and collects the plan.

signal demo_sequence_completed()

## Set when the --demo-showcase run through the shelter finishes (watched by tests/critic_qa_audit.gd).
static var demo_completed_flag: bool = false

const C_BG := Color("#0f1115")
const C_PANEL := Color("#1a1e24")
const C_RAISED := Color("#262c34")
const C_BORDER := Color("#39414b")
const C_TEXT := Color("#e8eaed")
const C_MUTED := Color("#9aa3ad")
const C_AMBER := Color("#ffb020")
const C_RED := Color("#ff4d4f")
const C_GREEN := Color("#4cc38a")
const C_WATER := Color("#4aa3ff")
const C_FOOD := Color("#f0a35e")
const C_PURPLE := Color("#b388ff")

const PANEL_RECT := Rect2(452, 54, 818, 656)

var s: ShelterState = null
var _backdrop: BunkerBackdrop = null
var _cinematic: ShelterCinematic = null
var _hud: Control = null
var _hud_day: Label
var _hud_supplies: HBoxContainer
var _hud_status: Label
var _panel: PanelContainer
var _receipt_box: VBoxContainer
var _event_box: VBoxContainer
var _family_box: VBoxContainer
var _footer_lbl: Label
var _end_btn: Button
var _curtain: ColorRect
var _curtain_lbl: Label
var _planner: Control = null
var _bench: Workbench = null
var _job_menu: PanelContainer = null
var _confirm: ConfirmationDialog = null

var _morning: Dictionary = {}
var _plan: Dictionary = {}
var _outcome: Dictionary = {}
var _busy: bool = false
var _pending_returns: Array = []
var _demo_days: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280.0, 720.0)
	SoundManager.set_ambience("bunker")
	if GameState.shelter == null:
		BunkerSim.start_bunker_run()
	s = GameState.shelter
	_backdrop = BunkerBackdrop.new()
	_backdrop.name = "BunkerBackdrop"
	add_child(_backdrop)
	_build_hud()
	_build_panel()
	_cinematic = ShelterCinematic.new()
	_cinematic.name = "ShelterCinematic"
	add_child(_cinematic)
	_cinematic.sequence_finished.connect(_on_cinematic_finished)
	_cinematic.visible = false
	_build_curtain()
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Leave the shelter empty?"
	_confirm.dialog_text = "Everyone is going out and there is no padlock. An empty, unlocked shelter is lost."
	_confirm.ok_button_text = "Go anyway"
	_confirm.cancel_button_text = "Keep someone home"
	_confirm.confirmed.connect(_commit_end_day)
	add_child(_confirm)
	_begin_day()
	if GameState.demo_mode:
		_run_demo.call_deferred()


# ---------------------------------------------------------------- building

func _label(text: String, size_px: int, col: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _box(bg: Color, border: Color, radius: int = 6, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
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
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", C_MUTED.darkened(0.3))
	var n: StyleBoxFlat = _box(bg, bg.lightened(0.25), 5, 8)
	b.add_theme_stylebox_override("normal", n)
	var h: StyleBoxFlat = _box(bg.lightened(0.12), C_AMBER, 5, 8)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	var d: StyleBoxFlat = _box(bg.darkened(0.35), C_BORDER, 5, 8)
	b.add_theme_stylebox_override("disabled", d)
	return b


func _icon(item_id: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ItemDB.get_icon_texture(item_id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.tooltip_text = ItemDB.tooltip_line(item_id)
	return t


func _clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.position = Vector2(8, 6)
	_hud.size = Vector2(1264, 42)
	_hud.add_theme_stylebox_override("panel", _box(Color(C_BG, 0.92), C_BORDER, 6, 8))
	add_child(_hud)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_hud.add_child(row)
	_hud_day = _label("Day 1", 18, C_AMBER)
	row.add_child(_hud_day)
	_hud_supplies = HBoxContainer.new()
	_hud_supplies.add_theme_constant_override("separation", 6)
	row.add_child(_hud_supplies)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_hud_status = _label("", 13, C_MUTED)
	row.add_child(_hud_status)
	var bench_btn := _button("Bench", C_RAISED, C_TEXT, Vector2(70, 28))
	bench_btn.name = "BenchButton"
	bench_btn.tooltip_text = "The workbench: parts, junk to take apart, recipes and the Need toggle"
	bench_btn.pressed.connect(func() -> void: _open_bench("", "browse"))
	row.add_child(bench_btn)
	var map_btn := _button("Map", C_RAISED, C_TEXT, Vector2(64, 28))
	map_btn.pressed.connect(func() -> void: _open_planner("", true))
	row.add_child(map_btn)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	_panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_BORDER, 8, 10))
	_panel.clip_contents = true
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	v.add_child(_label("THIS MORNING", 11, C_MUTED))
	var rs := ScrollContainer.new()
	rs.custom_minimum_size = Vector2(0, 118)
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rs)
	_receipt_box = VBoxContainer.new()
	_receipt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_receipt_box.add_theme_constant_override("separation", 1)
	rs.add_child(_receipt_box)
	v.add_child(HSeparator.new())
	_event_box = VBoxContainer.new()
	_event_box.custom_minimum_size = Vector2(0, 150)
	_event_box.add_theme_constant_override("separation", 4)
	v.add_child(_event_box)
	v.add_child(HSeparator.new())
	var fam_hdr := HBoxContainer.new()
	fam_hdr.add_child(_label("FAMILY", 11, C_MUTED))
	var hsp := Control.new()
	hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fam_hdr.add_child(hsp)
	fam_hdr.add_child(_label("food · water · tomorrow · care · job", 11, C_MUTED))
	v.add_child(fam_hdr)
	var fs := ScrollContainer.new()
	fs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(fs)
	_family_box = VBoxContainer.new()
	_family_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family_box.add_theme_constant_override("separation", 4)
	fs.add_child(_family_box)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_footer_lbl = _label("", 12, C_MUTED, true)
	_footer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_footer_lbl)
	_end_btn = _button("END DAY  ▸", Color("#3a2a10"), C_AMBER, Vector2(150, 38))
	_end_btn.add_theme_font_size_override("font_size", 15)
	_end_btn.pressed.connect(_on_end_day)
	foot.add_child(_end_btn)


func _build_curtain() -> void:
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 0)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_curtain)
	_curtain_lbl = _label("", 40, C_AMBER)
	_curtain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curtain_lbl.position = Vector2(440, 330)
	_curtain_lbl.size = Vector2(400, 60)
	_curtain_lbl.modulate.a = 0.0
	_curtain_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain_lbl)


# ---------------------------------------------------------------- day flow

func _begin_day() -> void:
	_morning = ShelterSim.begin_day(s)
	_outcome = {}
	_plan = ShelterSim.default_plan(s)
	BunkerSim.sync_outcome()
	_pending_returns = []
	for l_v in _morning.get("morning", []):
		if str((l_v as Dictionary).get("kind", "")) == "return":
			_pending_returns.append(l_v)
	_refresh_all()
	if s.is_over():
		_finish_run()


func _refresh_all() -> void:
	_refresh_hud()
	_refresh_receipt()
	_refresh_event()
	_refresh_family()
	_refresh_footer()
	if _backdrop != null:
		_backdrop.queue_redraw()


func _refresh_hud() -> void:
	_hud_day.text = "Day %d" % s.day
	_clear(_hud_supplies)
	var food_l := _label("%d" % s.food(), 14, C_FOOD)
	food_l.tooltip_text = "Food: %d rations (%s cans)" % [s.food(), GameState.format_quarters_as_cans(s.food())]
	_hud_supplies.add_child(_icon("food", 22))
	_hud_supplies.add_child(food_l)
	_hud_supplies.add_child(_icon("water", 22))
	var water_l := _label("%d" % s.water(), 14, C_WATER)
	water_l.tooltip_text = "Water: %d rations (%s bottles)" % [s.water(), GameState.format_quarters_as_cans(s.water())]
	_hud_supplies.add_child(water_l)
	_hud_supplies.add_child(VSeparator.new())
	var ids: Array = ShelterData.core_ids()
	ids.sort()
	for iid in ids:
		if iid == "food" or iid == "water":
			continue
		var n: int = s.count(iid)
		var b: int = s.broken_count(iid)
		if n + b == 0:
			continue
		var ic := _icon(iid, 22)
		if n == 0:
			ic.modulate = Color(0.6, 0.4, 0.4)
			ic.tooltip_text = "%s (broken)" % ItemDB.tooltip_line(iid)
		_hud_supplies.add_child(ic)
		if n > 1:
			_hud_supplies.add_child(_label("×%d" % n, 11, C_MUTED))
	# Makeshift items (taped icons), the part shelf and dirty water (section 10).
	var made_any: bool = false
	for iid in ShelterData.ids_in("makeshift"):
		if s.count(iid) <= 0:
			continue
		if not made_any:
			_hud_supplies.add_child(VSeparator.new())
			made_any = true
		var mic := _icon(iid, 22)
		var uses: int = ShelterCraft.uses_left(s, iid)
		if uses > 0:
			mic.tooltip_text += " (%d use%s left)" % [uses, "" if uses == 1 else "s"]
		_hud_supplies.add_child(mic)
	var parts_n: int = ShelterCraft.parts_total(s)
	var junk_n: int = 0
	for iid in ShelterData.ids_in("junk"):
		junk_n += s.count(iid)
	if parts_n + junk_n > 0:
		var pl := _label("parts %d/%d%s" % [parts_n, ShelterData.Bi("part_shelf_max", 12), (" · junk %d" % junk_n) if junk_n > 0 else ""], 11, Color("#d9c7a0"))
		pl.tooltip_text = "The part shelf and junk waiting to be taken apart (Bench)"
		_hud_supplies.add_child(pl)
	if s.dirty_water > 0:
		var dl := _label("dirty %d" % s.dirty_water, 11, Color("#8c7b5a"))
		dl.tooltip_text = "Dirty water (rations): a Bottle Filter makes it drinkable"
		_hud_supplies.add_child(dl)
	var bits: Array[String] = []
	if not s.fallout_announced:
		bits.append("Fallout: %s" % ("heavy" if ShelterTrips.heavy_fallout(s) else "no all-clear yet"))
	else:
		bits.append("Fallout: all-clear")
	if s.followed:
		bits.append("NOTICED")
	for c_v in ShelterChains.progress(s):
		var c: Dictionary = c_v
		if str(c["state"]) == "active" and int(c["step"]) > 1:
			bits.append("%s %d/%d" % [str(c["label"]).capitalize(), int(c["step"]) - 1, int(c["steps"])])
	_hud_status.text = "   ".join(bits)
	_hud_status.add_theme_color_override("font_color", C_RED if s.followed else C_MUTED)


func _kind_color(kind: String) -> Color:
	match kind:
		"death":
			return C_RED
		"warn", "raid":
			return C_AMBER
		"used", "good":
			return C_GREEN
		"missing", "lost", "break":
			return Color("#ff8a65")
		"gain", "return", "trip", "gear":
			return C_WATER
		"sick":
			return Color("#f48fb1")
		"morale", "rule":
			return C_PURPLE
		"status":
			return Color("#ffd27f")
	return C_TEXT


func _receipt_row(line: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var items: Array = line.get("items", [])
	if not items.is_empty() and ShelterData.has_item(str(items[0])):
		row.add_child(_icon(str(items[0]), 16))
	else:
		var dot := ColorRect.new()
		dot.color = _kind_color(str(line.get("kind", "")))
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
	var l := _label(str(line.get("text", "")), 13, _kind_color(str(line.get("kind", ""))), true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _refresh_receipt() -> void:
	_clear(_receipt_box)
	var lines: Array = _morning.get("morning", [])
	if lines.is_empty():
		_receipt_box.add_child(_label("A quiet night. Nothing changed.", 13, C_MUTED))
	for l_v in lines:
		_receipt_box.add_child(_receipt_row(l_v as Dictionary))


func _refresh_event() -> void:
	_clear(_event_box)
	var ev: Dictionary = s.today_event
	if ev.is_empty():
		_event_box.add_child(_label("TODAY", 11, C_MUTED))
		_event_box.add_child(_label("A quiet day. Nobody knocks; nothing breaks.", 15, C_TEXT, true))
		return
	var hdr := HBoxContainer.new()
	hdr.add_child(_label(str(ev.get("title", "")).to_upper(), 15, C_AMBER))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	var actor: Dictionary = s.member(str((ev.get("ctx", {}) as Dictionary).get("actor", "")))
	if not actor.is_empty():
		hdr.add_child(_label("acting: %s" % str(actor.get("name", "")), 11, C_MUTED))
	_event_box.add_child(hdr)
	_event_box.add_child(_label(str(ev.get("setup", "")), 14, C_TEXT, true))
	if s.today_resolved:
		_event_box.add_child(_label(str(_outcome.get("text", "")), 14, C_GREEN, true))
		for l_v in _outcome.get("lines", []):
			_event_box.add_child(_receipt_row(l_v as Dictionary))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	_event_box.add_child(grid)
	var i: int = 0
	for o_v in s.today_options:
		var o: Dictionary = o_v
		i += 1
		var it: String = str(o.get("item", ""))
		var label: String = "%d. %s" % [i, str(o.get("label", ""))]
		if it != "":
			label = "%d. [%s] %s" % [i, ShelterData.item_name(it), str(o.get("label", ""))]
		var b := _button(label, C_RAISED if it == "" else Color("#1f3326"), C_TEXT, Vector2(384, 0))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		if it != "":
			b.icon = ItemDB.get_icon_texture(it)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 18)
		var tip: String = str(o.get("stakes", ""))
		if not bool(o.get("available", true)):
			b.disabled = true
			tip = str(o.get("needs", "")) + ("; " + tip if tip != "" else "")
			b.text = "%d. %s — %s" % [i, str(o.get("needs", "")), str(o.get("label", ""))]
		b.tooltip_text = tip
		var oid: String = str(o["id"])
		b.pressed.connect(func() -> void: _choose(oid))
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(b)
		if tip != "":
			cell.add_child(_label(tip, 10, C_MUTED))
		grid.add_child(cell)


func _choose(option_id: String) -> void:
	if _busy or s.today_resolved:
		return
	SoundManager.play_sfx("button_click")
	_outcome = ShelterSim.choose(s, option_id)
	if _outcome.is_empty():
		return
	BunkerSim.sync_outcome()
	var lines_txt: Array[String] = []
	for l_v in _outcome.get("lines", []):
		lines_txt.append(str((l_v as Dictionary).get("text", "")))
	var cine: Dictionary = {
		"tags": _outcome.get("tags", []), "choice_id": option_id, "item_used": str(_outcome.get("item_used", "")),
		"actor_id": str(_outcome.get("actor_id", "")), "subject_id": str(_outcome.get("subject_id", "")),
		"outcome_text": str(_outcome.get("text", "")) + ("\n" + "\n".join(lines_txt) if not lines_txt.is_empty() else ""),
	}
	_busy = true
	_cinematic.play_outcome(cine, s.today_event)
	_refresh_all()


func _on_cinematic_finished(_kind: String) -> void:
	_cinematic.visible = false
	_busy = false
	if not _pending_returns.is_empty():
		_play_next_return()
		return
	_refresh_all()
	if s.is_over():
		_finish_run()


func _play_next_return() -> void:
	var l: Dictionary = _pending_returns.pop_front()
	var m: Dictionary = s.member(str(l.get("who", "")))
	var arr: Array = []
	for it in l.get("items", []):
		arr.append({"item_id": str(it), "count": 1})
	_busy = true
	_cinematic.play_return({"member_name": str(m.get("name", "")), "from": "", "items": arr}, m)


# ---------------------------------------------------------------- family rows

func _refresh_family() -> void:
	_clear(_family_box)
	var rations: Dictionary = _plan.get("rations", {})
	var treat: Dictionary = _plan.get("treat", {})
	var jobs: Dictionary = _plan.get("jobs", {})
	var medkits_left: int = s.count("medkit") - treat.size()
	var bandages_used: int = 0
	for m_v in s.members:
		var m: Dictionary = m_v
		var mid: String = str(m["id"])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _box(C_RAISED if bool(m.get("alive", false)) else C_BG, C_BORDER, 6, 6))
		_family_box.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		var portrait := _Portrait.new()
		portrait.member = m
		portrait.custom_minimum_size = Vector2(44, 44)
		h.add_child(portrait)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(128, 0)
		info.add_theme_constant_override("separation", 0)
		info.add_child(_label(str(m.get("name", "")) + ("  ★" if bool(m.get("is_leader", false)) else ""), 14, C_TEXT))
		var status: String = ", ".join(ShelterSim.status_labels(m, s.day))
		var alarming: bool = status.find("Dehydrated") != -1 or status.find("Starving") != -1 or status.find("Diseased") != -1
		info.add_child(_label(status, 11, C_RED if alarming else C_MUTED, true))
		if bool(m.get("alive", false)):
			info.add_child(_label("morale %d/10" % int(m.get("morale", 0)), 10, C_PURPLE))
		h.add_child(info)
		if not bool(m.get("alive", false)):
			var dl := _label(str(m.get("death_reason", "")), 12, C_MUTED, true)
			dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(dl)
			continue
		if str(m.get("loc", "")) == "away":
			var trip: Dictionary = _trip_of(mid)
			var txt: String = "Away"
			if not trip.is_empty():
				var p: Dictionary = s.places[int(trip["place_idx"])]
				var due: int = int(trip["due_day"])
				txt = "Away at %s · due back day %d%s" % [ShelterTrips.place_label(p), due, " (late)" if s.day > due else ""]
			var al := _label(txt, 13, C_WATER, true)
			al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(al)
			continue
		var r: Dictionary = rations.get(mid, {"food": false, "water": false})
		h.add_child(_toggle("food", bool(r.get("food", false)), s.food() > 0, func() -> void: _toggle_ration(mid, "food")))
		h.add_child(_toggle("water", bool(r.get("water", false)), s.water() > 0, func() -> void: _toggle_ration(mid, "water")))
		var pv: Dictionary = ShelterSim.ration_preview(s, m, bool(r.get("food", false)), bool(r.get("water", false)))
		var pv_lines: Array[String] = []
		if str(pv["water"]) != "":
			pv_lines.append("Skip water: %s %s" % [str(m["name"]), str(pv["water"])])
		if str(pv["food"]) != "":
			pv_lines.append("Skip food: %s %s" % [str(m["name"]), str(pv["food"])])
		if pv_lines.is_empty():
			pv_lines.append("Eats and drinks today.")
		var danger: bool = int(pv["dww"]) >= ShelterData.Bi("water_death_roll_day", 5) or int(pv["dwf"]) >= ShelterData.Bi("food_death_day", 10)
		var pl := _label("\n".join(pv_lines), 11, C_RED if danger else C_MUTED, true)
		pl.custom_minimum_size = Vector2(190, 0)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(pl)
		var unwell: bool = bool(m.get("sick", false)) or bool(m.get("injured", false))
		var wound_only: bool = bool(m.get("injured", false)) and not bool(m.get("sick", false))
		var use_bandage: bool = wound_only and s.count("rag_bandage") - bandages_used > 0 and (not treat.has(mid) or str(treat.get(mid, "")) != "medkit")
		if treat.has(mid) and use_bandage:
			bandages_used += 1
		var tb := _button("Treat" if not treat.has(mid) else "✓ Treat", Color("#3a1f24") if treat.has(mid) else C_RAISED, Color("#ff6b6b"), Vector2(70, 30))
		tb.icon = ItemDB.get_icon_texture("rag_bandage" if use_bandage else "medkit")
		tb.add_theme_constant_override("icon_max_width", 16)
		tb.disabled = not unwell or (medkits_left <= 0 and not use_bandage and not treat.has(mid))
		tb.tooltip_text = (("Close %s's wound with a rag bandage (saves the medkit)" % str(m["name"])) if use_bandage else ("Cure %s (uses 1 medkit)" % str(m["name"]))) if unwell else "Not sick or injured"
		tb.pressed.connect(func() -> void: _toggle_treat(mid))
		h.add_child(tb)
		var job: Dictionary = jobs.get(mid, {})
		var jb: Button
		match str(job.get("job", "rest")):
			"trip":
				var p2: Dictionary = s.places[int(job["place"])]
				jb = _button("Trip: %s ▾" % _short(ShelterTrips.place_label(p2), 12), Color("#13304a"), C_WATER, Vector2(132, 30))
				jb.tooltip_text = "Leaving tonight. Click to change or cancel."
			"craft":
				var names: Array[String] = []
				for r_v in job.get("recipes", []):
					names.append(str(ShelterData.recipe(str((r_v as Dictionary).get("id", ""))).get("name", "")))
				jb = _button("Bench: %s ▾" % _short(" + ".join(names), 13), Color("#2b2616"), Color("#d9c7a0"), Vector2(132, 30))
				jb.tooltip_text = "At the workbench today: %s. Click to change or cancel." % ", ".join(names)
			"study":
				var c: Dictionary = ShelterData.chapter(str(job.get("chapter", "")))
				jb = _button("Study: Ch.%d ▾" % int(c.get("order", 0)), Color("#13304a"), C_WATER, Vector2(132, 30))
				jb.tooltip_text = "Studying the manual today: %s" % str(c.get("title", ""))
			_:
				var why: String = ShelterTrips.can_go(s, m)
				jb = _button("Rest ▾" if why == "" else "Rest · %s ▾" % ShelterTrips.can_go_short(s, m), C_RAISED, C_TEXT, Vector2(132, 30))
				jb.tooltip_text = "Choose %s's job today: rest, a trip, the workbench or the manual" % str(m["name"])
		jb.name = "Job_" + mid
		jb.disabled = ShelterCraft.can_work(s, m) != "" and ShelterTrips.can_go(s, m) != "" and str(job.get("job", "rest")) == "rest"
		if jb.disabled:
			jb.tooltip_text = ShelterTrips.can_go(s, m)
		jb.pressed.connect(func() -> void: _open_job_menu(mid, jb))
		h.add_child(jb)


func _toggle(item_id: String, on: bool, any_left: bool, cb: Callable) -> Button:
	var b := _button("Give" if on else "Skip", Color("#1f3326") if on else C_RAISED, C_TEXT if on else C_MUTED, Vector2(60, 30))
	b.icon = ItemDB.get_icon_texture(item_id)
	b.add_theme_constant_override("icon_max_width", 16)
	b.tooltip_text = ("Give 1 %s ration" % item_id) if not on else ("Skip %s today" % item_id)
	if not on and not any_left:
		b.disabled = true
		b.tooltip_text = "No %s left" % item_id
	b.pressed.connect(cb)
	return b


func _short(t: String, n: int) -> String:
	return t if t.length() <= n else t.substr(0, n - 1) + "…"


func _trip_of(mid: String) -> Dictionary:
	for t_v in s.trips:
		if str((t_v as Dictionary)["member"]) == mid:
			return t_v
	return {}


func _toggle_ration(mid: String, kind: String) -> void:
	var rations: Dictionary = _plan["rations"]
	var r: Dictionary = rations.get(mid, {"food": false, "water": false})
	r[kind] = not bool(r.get(kind, false))
	rations[mid] = r
	SoundManager.play_sfx("button_click")
	_refresh_family()
	_refresh_footer()


func _toggle_treat(mid: String) -> void:
	var treat: Dictionary = _plan["treat"]
	if treat.has(mid):
		treat.erase(mid)
	else:
		treat[mid] = true
	_refresh_family()
	_refresh_footer()


func _cancel_trip(mid: String) -> void:
	(_plan["jobs"] as Dictionary).erase(mid)
	_refresh_family()
	_refresh_footer()


func _refresh_footer() -> void:
	var rations: Dictionary = _plan.get("rations", {})
	var f: int = 0
	var w: int = 0
	for k in rations.keys():
		if bool((rations[k] as Dictionary).get("food", false)):
			f += 1
		if bool((rations[k] as Dictionary).get("water", false)):
			w += 1
	var bits: Array[String] = ["Today: %d food and %d water rations" % [mini(f, s.food()), mini(w, s.water())]]
	var trips: int = 0
	var bench: int = 0
	var study: int = 0
	for k in (_plan.get("jobs", {}) as Dictionary).keys():
		match str((_plan["jobs"][k] as Dictionary).get("job", "")):
			"trip":
				trips += 1
			"craft":
				bench += 1
			"study":
				study += 1
	if trips > 0:
		bits.append("%d leaving tonight" % trips)
	if bench > 0:
		bits.append("%d at the bench" % bench)
	if study > 0:
		bits.append("%d studying" % study)
	if not s.today_resolved and not s.today_event.is_empty():
		bits.append("answer today's dilemma first")
	_footer_lbl.text = " · ".join(bits)
	_end_btn.disabled = _busy or (not s.today_resolved and not s.today_event.is_empty()) or s.is_over()


# ---------------------------------------------------------------- end of day

func _on_end_day() -> void:
	if _busy or s.is_over() or _bench != null or _job_menu != null:
		return
	if not s.today_resolved and not s.today_event.is_empty():
		return
	var leaving: int = 0
	for k in (_plan.get("jobs", {}) as Dictionary).keys():
		if str((_plan["jobs"][k] as Dictionary).get("job", "")) == "trip":
			leaving += 1
	if leaving > 0 and leaving >= s.home().size() and not s.has("padlock"):
		_confirm.popup_centered()
		return
	_commit_end_day()


func _commit_end_day() -> void:
	SoundManager.play_sfx("page_turn")
	_busy = true
	ShelterSim.end_day(s, _plan)
	GameState.check_achievements()
	BunkerSim.sync_world()
	BunkerSim.sync_outcome()
	GameState.inventory_changed.emit()
	GameState.family_changed.emit()
	GameState.day_advanced.emit(s.day)
	_show_curtain("Day %d" % s.day)
	await get_tree().create_timer(0.55 if not GameState.demo_mode else 0.25).timeout
	_begin_day()
	_busy = false
	_refresh_footer()
	if not _pending_returns.is_empty() and not s.is_over():
		_play_next_return()


func _show_curtain(text: String) -> void:
	_curtain_lbl.text = text
	var tw := create_tween()
	tw.tween_property(_curtain, "color:a", 0.85, 0.2)
	tw.parallel().tween_property(_curtain_lbl, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.25)
	tw.tween_property(_curtain, "color:a", 0.0, 0.35)
	tw.parallel().tween_property(_curtain_lbl, "modulate:a", 0.0, 0.35)


func _finish_run() -> void:
	BunkerSim.sync_outcome()
	_end_btn.disabled = true
	_footer_lbl.text = "%s — %s" % [GameState.ending_title, GameState.ending_description]
	await get_tree().create_timer(2.2 if not GameState.demo_mode else 0.6).timeout
	if GameState.demo_mode:
		demo_completed_flag = true
		demo_sequence_completed.emit()
	GameState.request_screen(GameState.SCREEN_SUMMARY)


# ---------------------------------------------------------------- expedition planner

func _open_planner(mid: String, browse_only: bool) -> void:
	if _planner != null:
		_planner.queue_free()
	var tp := TripPlanner.new()
	tp.setup(s, mid, browse_only, _reserved_gear(mid))
	tp.confirmed.connect(func(place_idx: int, gear: Array) -> void:
		(_plan["jobs"] as Dictionary)[mid] = {"job": "trip", "place": place_idx, "gear": gear}
		_close_planner()
		_refresh_family()
		_refresh_footer())
	tp.cancelled.connect(_close_planner)
	_planner = tp
	add_child(tp)


func _close_planner() -> void:
	if _planner != null:
		_planner.queue_free()
	_planner = null


# ---------------------------------------------------------------- jobs and the workbench

## Rest, Trip…, Craft…, Study… — each with the reason it isn't possible today.
func _open_job_menu(mid: String, anchor: Button) -> void:
	_close_job_menu()
	var m: Dictionary = s.member(mid)
	var menu := PanelContainer.new()
	menu.name = "JobMenu"
	menu.add_theme_stylebox_override("panel", _box(C_BG, C_AMBER, 6, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	menu.add_child(v)
	var trip_why: String = ShelterTrips.can_go(s, m)
	var work_why: String = ShelterCraft.can_work(s, m)
	var study_why: String = ShelterCraft.can_study(s, m)
	var entries: Array = [
		["Rest", "", "Rest today (no job)", func() -> void: _set_rest(mid)],
		["Trip…", trip_why, "Send %s to a real place nearby" % str(m.get("name", "")), func() -> void: _open_planner(mid, false)],
		["Craft…", work_why, "A day at the workbench: two Quick recipes or one Day recipe", func() -> void: _open_bench(mid, "craft")],
		["Study…", study_why, "A day with the manual: learn one chapter", func() -> void: _open_bench(mid, "study")],
	]
	for e in entries:
		var label: String = str(e[0]) if str(e[1]) == "" else "%s  (%s)" % [str(e[0]).trim_suffix("…"), str(e[1])]
		var b := _button(label, C_RAISED, C_TEXT, Vector2(240, 28))
		b.name = "Job" + str(e[0]).trim_suffix("…")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = str(e[1]) != ""
		b.tooltip_text = str(e[1]) if str(e[1]) != "" else str(e[2])
		var cb: Callable = e[3]
		b.pressed.connect(func() -> void:
			_close_job_menu()
			cb.call())
		v.add_child(b)
	add_child(menu)
	_job_menu = menu
	var r: Rect2 = anchor.get_global_rect()
	menu.position = Vector2(clampf(r.position.x + r.size.x - 248.0, 8.0, 1272.0 - 248.0), minf(r.position.y + r.size.y + 2.0, 720.0 - 140.0))


func _close_job_menu() -> void:
	if _job_menu != null:
		_job_menu.queue_free()
	_job_menu = null


func _set_rest(mid: String) -> void:
	(_plan["jobs"] as Dictionary).erase(mid)
	SoundManager.play_sfx("button_click")
	_refresh_family()
	_refresh_footer()


func _open_bench(mid: String, how: String) -> void:
	if _bench != null:
		_bench.queue_free()
	var wb := Workbench.new()
	var cur: Dictionary = (_plan.get("jobs", {}) as Dictionary).get(mid, {})
	wb.setup(s, mid, how, cur if str(cur.get("job", "")) == "craft" else {})
	wb.confirmed.connect(func(job: Dictionary) -> void:
		(_plan["jobs"] as Dictionary)[mid] = job
		_close_bench())
	wb.cancelled.connect(_close_bench)
	wb.changed.connect(func() -> void:
		_refresh_hud()
		GameState.inventory_changed.emit())
	_bench = wb
	add_child(wb)


func _close_bench() -> void:
	if _bench != null:
		_bench.queue_free()
	_bench = null
	_refresh_hud()
	_refresh_family()
	_refresh_footer()


func _reserved_gear(except_mid: String) -> Array:
	var res: Array = []
	for k in (_plan.get("jobs", {}) as Dictionary).keys():
		if str(k) == except_mid:
			continue
		for g in (_plan["jobs"][k] as Dictionary).get("gear", []):
			res.append(str(g))
	return res


func _unhandled_input(event: InputEvent) -> void:
	if _job_menu != null and event is InputEventMouseButton and event.pressed:
		# A click outside the job menu closes it.
		if not _job_menu.get_global_rect().has_point((event as InputEventMouseButton).position):
			_close_job_menu()
	if _job_menu != null and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_close_job_menu()
		get_viewport().set_input_as_handled()
		return
	if _planner != null or _bench != null or _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_4 and not s.today_resolved:
			var i: int = k - KEY_1
			if i < s.today_options.size() and bool((s.today_options[i] as Dictionary).get("available", false)):
				_choose(str((s.today_options[i] as Dictionary)["id"]))
				get_viewport().set_input_as_handled()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			if not _end_btn.disabled:
				_on_end_day()
				get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- demo showcase

func _run_demo() -> void:
	demo_completed_flag = false
	while not s.is_over() and _demo_days < 6:
		while _busy:
			await get_tree().process_frame
		if not s.today_resolved and not s.today_event.is_empty():
			var pick: String = ""
			for o_v in s.today_options:
				var o: Dictionary = o_v
				if bool(o.get("available", false)) and (pick == "" or str(o.get("item", "")) != ""):
					pick = str(o["id"])
			_choose(pick)
			await get_tree().create_timer(0.4).timeout
			while _busy:
				await get_tree().process_frame
		for m_v in s.home():
			var m: Dictionary = m_v
			var r: Dictionary = {"food": int(m.get("dwf", 0)) >= 5, "water": int(m.get("dww", 0)) >= 2}
			(_plan["rations"] as Dictionary)[str(m["id"])] = r
		# Day 2: send the second adult to the nearest real store (shows the planner's result).
		if s.day == 2 and s.trips.is_empty():
			for m_v2 in s.home():
				var em: Dictionary = m_v2
				if ShelterTrips.can_go(s, em) == "" and not bool(em.get("is_leader", false)):
					var best: int = -1
					for p_v in s.places:
						var p: Dictionary = p_v
						if str(p["category"]) in ["grocery", "pharmacy", "neighbor_house"] and (best < 0 or float(p["walk_m"]) < float((s.places[best] as Dictionary)["walk_m"])):
							best = int(p["idx"])
					if best >= 0:
						var gear: Array = []
						for g in ["gas_mask", "map"]:
							if s.has(g):
								gear.append(g)
						(_plan["jobs"] as Dictionary)[str(em["id"])] = {"job": "trip", "place": best, "gear": gear}
					break
		_refresh_family()
		await get_tree().create_timer(0.3).timeout
		_demo_days += 1
		_commit_end_day()
		await get_tree().create_timer(0.9).timeout
	demo_completed_flag = true
	demo_sequence_completed.emit()
	GameState.request_screen(GameState.SCREEN_SUMMARY)


class _Portrait extends Control:
	var member: Dictionary = {}
	func _draw() -> void:
		CharacterArtist.draw_portrait(self, Rect2(Vector2.ZERO, size), member, false)
