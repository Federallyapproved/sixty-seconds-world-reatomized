class_name TripPlanner
extends Control

## Expedition planner with the risk preview (section 6): click a real place on the map or in the
## list to see walking time, trip days, the dose band, the chance of never coming back as a band
## (exact numbers on Story), likely loot, when it was last seen stocked, rumours and the tool it
## needs; pack up to three pieces of gear; confirm.

signal confirmed(place_idx: int, gear: Array)
signal cancelled()

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

var s: ShelterState
var member_id: String = ""
var browse_only: bool = false
var reserved: Array = []
var gear: Array = []
var place_idx: int = -1

var _map: ShelterMapView
var _list: VBoxContainer
var _preview: VBoxContainer
var _gear_row: HBoxContainer
var _ok: Button


func setup(state: ShelterState, mid: String, browse: bool, reserved_gear: Array) -> void:
	s = state
	member_id = mid
	browse_only = browse
	reserved = reserved_gear
	# Sensible default kit: what the risk preview says matters.
	if not browse:
		for g in ["gas_mask", "map", "suitcase"]:
			if s.has(g) and not reserved.has(g) and gear.size() < ShelterTrips.MAX_GEAR:
				gear.append(g)


func _ready() -> void:
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	_map = ShelterMapView.new()
	_map.custom_minimum_size = Vector2(560, 640)
	_map.targets = ExpeditionEngine.get_available_targets()
	_map.target_clicked.connect(_select)
	h.add_child(_map)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	var who: Dictionary = _member()
	var title: String = "Where should %s go?" % str(who.get("name", "someone")) if not browse_only else "The neighbourhood"
	right.add_child(_label(title, 18, C_AMBER))
	right.add_child(_label("Real places from OpenStreetMap. Interiors and stock are fictional; distances are walking routes.", 11, C_MUTED, true))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 200)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	right.add_child(HSeparator.new())
	_preview = VBoxContainer.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.add_theme_constant_override("separation", 3)
	right.add_child(_preview)
	_gear_row = HBoxContainer.new()
	_gear_row.add_theme_constant_override("separation", 6)
	right.add_child(_gear_row)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var cancel := _button("Back", C_RAISED, C_TEXT, Vector2(110, 36))
	cancel.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(cancel)
	_ok = _button("Send them tonight", Color("#13304a"), C_WATER, Vector2(190, 36))
	_ok.visible = not browse_only
	_ok.pressed.connect(func() -> void:
		if place_idx >= 0:
			confirmed.emit(place_idx, gear.duplicate()))
	buttons.add_child(_ok)
	_build_list()
	_build_gear()
	_refresh_preview()


func _member() -> Dictionary:
	var m: Dictionary = s.member(member_id)
	if not m.is_empty():
		return m
	var a: Dictionary = ShelterEvents.actor(s)
	return a if not a.is_empty() else (s.members[0] if not s.members.is_empty() else {})


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
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_disabled_color", C_MUTED.darkened(0.3))
	b.add_theme_stylebox_override("normal", _box(bg, bg.lightened(0.25), 6))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), C_AMBER, 6))
	b.add_theme_stylebox_override("pressed", _box(bg.lightened(0.12), C_AMBER, 6))
	b.add_theme_stylebox_override("disabled", _box(bg.darkened(0.35), C_BORDER, 6))
	return b


func _band_color(band: String) -> Color:
	match band:
		"Low":
			return C_GREEN
		"Moderate", "High":
			return C_AMBER
	return C_RED


func _build_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var order: Array = []
	for p_v in s.places:
		order.append(p_v)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["walk_m"]) < float(b["walk_m"]))
	var who: Dictionary = _member()
	for p_v in order:
		var p: Dictionary = p_v
		var pv: Dictionary = ShelterTrips.preview(s, who, int(p["idx"]), gear)
		var txt: String = "%s · %s · %d min walk · risk %s" % [ShelterTrips.place_label(p), ShelterTrips.category_word(str(p["category"])), int(pv["walk_min"]), str(pv["risk_band"])]
		var b := _button(txt, Color("#13304a") if int(p["idx"]) == place_idx else C_RAISED, C_TEXT, Vector2(0, 28))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var idx: int = int(p["idx"])
		b.pressed.connect(func() -> void: _select(idx))
		_list.add_child(b)


func _build_gear() -> void:
	for c in _gear_row.get_children():
		c.queue_free()
	if browse_only:
		return
	_gear_row.add_child(_label("Pack (max %d):" % ShelterTrips.MAX_GEAR, 12, C_MUTED))
	for g in ShelterTrips.GEAR_IDS:
		if not s.has(g):
			continue
		var on: bool = gear.has(g)
		var b := _button(ShelterData.item_name(g), Color("#1f3326") if on else C_RAISED, C_TEXT if on else C_MUTED, Vector2(0, 30))
		b.icon = ItemDB.get_icon_texture(g)
		b.add_theme_constant_override("icon_max_width", 16)
		b.tooltip_text = ItemDB.tooltip_line(g)
		if ShelterCraft.uses_left(s, g) > 0:
			b.tooltip_text += " (%d use%s left)" % [ShelterCraft.uses_left(s, g), "" if ShelterCraft.uses_left(s, g) == 1 else "s"]
		if reserved.has(g) and s.count(g) <= 1:
			b.disabled = true
			b.tooltip_text = "Already packed for someone else"
		var gid: String = g
		b.pressed.connect(func() -> void: _toggle_gear(gid))
		_gear_row.add_child(b)


func _toggle_gear(g: String) -> void:
	if gear.has(g):
		gear.erase(g)
	elif gear.size() < ShelterTrips.MAX_GEAR:
		gear.append(g)
	_build_gear()
	_build_list()
	_refresh_preview()


func _select(idx: int) -> void:
	if idx < 0 or idx >= s.places.size():
		return
	place_idx = idx
	_map.selected_index = idx
	_map.queue_redraw()
	SoundManager.play_sfx("button_click")
	_build_list()
	_refresh_preview()


func _refresh_preview() -> void:
	for c in _preview.get_children():
		c.queue_free()
	_ok.disabled = place_idx < 0
	if place_idx < 0:
		_preview.add_child(_label("Pick a place on the map or in the list to see the risks.", 13, C_MUTED, true))
		return
	var story: bool = s.difficulty == "story"
	var who: Dictionary = _member()
	var pv: Dictionary = ShelterTrips.preview(s, who, place_idx, gear)
	var p: Dictionary = pv["place"]
	_preview.add_child(_label("%s — %s" % [ShelterTrips.place_label(p), ShelterTrips.category_word(str(p["category"]))], 16, C_TEXT, true))
	var walk_note: String = " (straight-line estimate)" if str(p.get("walk_source", "")) == "estimate" else ""
	_preview.add_child(_label("%d min walk each way · %.1f km round trip%s" % [int(pv["walk_min"]), float(pv["round_trip_km"]), walk_note], 13, C_MUTED))
	var days_txt: String = "Trip: %d day%s" % [int(pv["days"]), "" if int(pv["days"]) == 1 else "s"]
	if gear.has("map") and int(pv["days_no_map"]) > int(pv["days"]):
		days_txt += " (the map saves a day)"
	days_txt += " · 1 in 4 trips runs a day or two late"
	if bool(pv["tired"]):
		days_txt += " · Tired for 2 days after"
	_preview.add_child(_label(days_txt, 13, C_TEXT, true))
	var risk_txt: String = "Chance of not coming back: %s" % str(pv["risk_band"])
	if story:
		risk_txt += " (%.0f%%)" % (100.0 * float(pv["p_death"]))
	var why: Array = pv["risk_why"]
	if not why.is_empty():
		risk_txt += " — " + ", ".join(why)
	_preview.add_child(_label(risk_txt, 13, _band_color(str(pv["risk_band"])), true))
	var dose_txt: String = "Dose: %s" % str(pv["dose_band"])
	if story:
		dose_txt += " (~%d mSv)" % int(round(float(pv["dose_msv"])))
	var sick_p: float = float(pv["sick_p"])
	if sick_p > 0.0:
		dose_txt += " · sick on return: %s" % (("%.0f%%" % (100.0 * sick_p)) if story else ("likely" if sick_p >= 0.5 else "possible"))
	if not bool(pv["fallout_known"]):
		dose_txt += " · no all-clear on the radio yet"
	_preview.add_child(_label(dose_txt, 13, _band_color("Low" if str(pv["dose_band"]) == "Low" and sick_p < 0.3 else ("High" if str(pv["dose_band"]) != "Lethal" else "Lethal")), true))
	var loot_row := HBoxContainer.new()
	loot_row.add_theme_constant_override("separation", 4)
	loot_row.add_child(_label("Likely: ", 13, C_MUTED))
	for iid in pv["loot_hint"]:
		var t := TextureRect.new()
		t.texture = ItemDB.get_icon_texture(str(iid))
		t.custom_minimum_size = Vector2(20, 20)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.tooltip_text = ItemDB.tooltip_line(str(iid))
		loot_row.add_child(t)
	loot_row.add_child(_label("  ·  carry %d slots" % int(pv["carry"]), 13, C_MUTED))
	_preview.add_child(loot_row)
	# The Need toggle (section 10): junk here that holds a tagged part, looted first.
	var jh: Array = pv.get("junk_hint", [])
	if not jh.is_empty():
		var need_row := HBoxContainer.new()
		need_row.add_theme_constant_override("separation", 4)
		need_row.add_child(_label("Need: ", 13, C_AMBER))
		for jid in jh:
			var jt := TextureRect.new()
			jt.texture = ItemDB.get_icon_texture(str(jid))
			jt.custom_minimum_size = Vector2(20, 20)
			jt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			jt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			jt.tooltip_text = ItemDB.tooltip_line(str(jid))
			need_row.add_child(jt)
		need_row.add_child(_label(" " + ", ".join(jh.map(func(j: Variant) -> String: return ShelterData.item_name(str(j)).to_lower())), 12, C_AMBER))
		_preview.add_child(need_row)
	if str(pv.get("pamphlet_hint", "")) != "":
		_preview.add_child(_label(str(pv["pamphlet_hint"]), 12, C_MUTED, true))
	_preview.add_child(_label("Last stocked: %s" % str(pv["stocked"]), 13, C_MUTED))
	var rumour: String = str(pv["rumour"])
	if ShelterTrips.raiders_active(s):
		rumour = ("%s; " % rumour if rumour != "" else "") + "armed looters about"
	if rumour != "":
		_preview.add_child(_label("Rumour: %s" % rumour, 13, C_AMBER, true))
	if str(pv["tool"]) != "":
		_preview.add_child(_label("Tool: %s" % str(pv["tool"]), 13, C_AMBER if not gear.has("axe") else C_GREEN))
	var fp: float = float(pv["followed_p"])
	_preview.add_child(_label("Being followed home: %s" % (("%.0f%%" % (100.0 * fp)) if story else ("likely" if fp >= 0.35 else ("possible" if fp >= 0.12 else "unlikely"))), 13, C_MUTED))
	if not browse_only:
		var why_not: String = ShelterTrips.can_go(s, who)
		if why_not != "":
			_preview.add_child(_label("%s can't go: %s" % [str(who.get("name", "")), why_not], 13, C_RED))
			_ok.disabled = true
		elif s.home().size() <= 1 and not s.has("padlock"):
			_preview.add_child(_label("Nobody would be left home and there is no padlock: the shelter would be lost.", 13, C_RED, true))
