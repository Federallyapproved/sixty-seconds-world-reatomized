class_name HouseSelectScreen
extends Control

## Step 2 Screen (1280x720): Real-World OpenStreetMap House & Scavenge Target Recon.
## Features live Nominatim address/city search, live OSM API 0.6 neighborhood loading,
## 3 instant authentic OSM neighborhood presets (Seattle Capitol Hill, Concord MA, Brooklyn NY),
## interactive OsmSlippyMap parcel picker, architectural footprint blueprint preview,
## and scrollable real-world Churches / Supermarkets / Pharmacies / Schools / Neighbor Houses list.

const COL_BG_DARK := Color("#1a1d1a")
const COL_PANEL_SLATE := Color("#232824")
const COL_CARD_PARCHMENT := Color("#efe3c8")
const COL_CARD_AGED := Color("#dccba6")
const COL_INK := Color("#1b1917")
const COL_HAZARD_YELLOW := Color("#f5be2e")
const COL_ATOMIC_ORANGE := Color("#e05a2b")
const COL_SAFE_GREEN := Color("#7ec850")
const COL_BLUEPRINT_BG := Color("#132b40")
const COL_BLUEPRINT_GRID := Color(0.32, 0.58, 0.78, 0.22)
const COL_BLUEPRINT_LINE := Color("#eef7ff")

var _osm_service: OsmService
var _slippy_map: OsmSlippyMap

# Top bar controls
var _search_input: LineEdit
var _search_btn: Button
var _preset_buttons: Dictionary = {}
var _status_label: Label
var _status_busy: bool = false
var _search_results_bar: HBoxContainer
var _search_results_panel: PanelContainer

# Right sidebar: Blueprint & House Info
var _blueprint_canvas: Control
var _lbl_house_address: Label
var _lbl_house_neighborhood: Label
var _lbl_house_coords: Label
var _lbl_house_area: Label
var _lbl_house_rooms: Label
var _lbl_house_osm_id: Label

# Right sidebar: Nearby POIs list
var _lbl_poi_header: Label
var _lbl_poi_summary: Label
var _poi_scroll: ScrollContainer
var _poi_list_vbox: VBoxContainer

# Bottom bar
var _btn_back: Button
var _btn_confirm: Button
var _lbl_bottom_summary: Label

# Current parsed map state
var _current_buildings: Array = []
var _current_pois: Array = []
var _current_parsed_meta: Dictionary = {}
var _extended_pois: Array = []
var _extended_roads: Array = []
var _current_neighborhood_label: String = "Capitol Hill, Seattle, WA"
var _active_preset_id: String = "seattle"

# Demo showcase choreography state
var _demo_elapsed: float = 0.0
var _demo_stage: int = 0
var _demo_finished: bool = false
var _demo_banner: Control
var _anim_clock: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280.0, 720.0)

	_osm_service = OsmService.new()
	_osm_service.name = "OsmService"
	add_child(_osm_service)
	_osm_service.status_changed.connect(_on_osm_status_changed)
	_osm_service.search_completed.connect(_on_nominatim_search_completed)
	_osm_service.search_failed.connect(_on_nominatim_search_failed)
	_osm_service.map_data_loaded.connect(_on_live_map_data_loaded)
	_osm_service.extended_data_loaded.connect(_on_extended_data_loaded)
	_osm_service.map_data_failed.connect(_on_live_map_data_failed)

	_build_ui()
	_load_preset_neighborhood("seattle", true)

	if GameState.demo_mode:
		_init_demo_mode()

func _process(delta: float) -> void:
	_anim_clock += delta
	if _status_busy or GameState.demo_mode:
		queue_redraw()
	if is_instance_valid(_blueprint_canvas):
		_blueprint_canvas.queue_redraw()
	if GameState.demo_mode and not _demo_finished:
		_tick_demo_mode(delta)

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size if size.x > 100.0 else Vector2(1280.0, 720.0))
	draw_rect(full, COL_BG_DARK, true)

	# Subtle CONELRAD top hazard trim & tactical background scanlines
	for y in range(0, int(full.size.y), 6):
		draw_line(Vector2(0.0, float(y)), Vector2(full.size.x, float(y)), Color(0.0, 0.0, 0.0, 0.12), 1.0)

	var stripe_h: float = 4.0
	var stripe_w: float = 28.0
	var sx: float = 0.0
	var toggle: bool = false
	while sx < full.size.x:
		draw_rect(Rect2(sx, 0.0, stripe_w, stripe_h), COL_HAZARD_YELLOW if toggle else COL_INK, true)
		sx += stripe_w
		toggle = not toggle

# --- UI Construction (1280x720 Precision Layout) ---

func _build_ui() -> void:
	_build_top_bar()
	_build_map_section()
	_build_right_sidebar()
	_build_bottom_bar()
	_build_search_results_overlay()

func _build_top_bar() -> void:
	var top_panel := Panel.new()
	top_panel.position = Vector2(16.0, 8.0)
	top_panel.size = Vector2(1248.0, 80.0)
	top_panel.add_theme_stylebox_override("panel", _make_panel_style(COL_PANEL_SLATE, COL_HAZARD_YELLOW, 2, 5))
	add_child(top_panel)

	# Row 1: Step Badge + Search LineEdit + [ SEARCH LIVE OSM ]
	var badge_panel := PanelContainer.new()
	badge_panel.position = Vector2(10.0, 8.0)
	badge_panel.size = Vector2(218.0, 32.0)
	badge_panel.add_theme_stylebox_override("panel", _make_panel_style(COL_HAZARD_YELLOW, COL_INK, 2, 3))
	top_panel.add_child(badge_panel)

	var badge_lbl := Label.new()
	badge_lbl.text = " 02 // REAL-WORLD HOUSE"
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_color_override("font_color", COL_INK)
	badge_lbl.add_theme_font_size_override("font_size", 14)
	badge_panel.add_child(badge_lbl)

	_search_input = LineEdit.new()
	_search_input.position = Vector2(236.0, 8.0)
	_search_input.size = Vector2(782.0, 32.0)
	_search_input.placeholder_text = "Type any street address, neighborhood, or city (e.g. Boston, Austin, London)..."
	_search_input.clear_button_enabled = true
	_style_search_input(_search_input)
	_search_input.text_submitted.connect(func(_txt: String) -> void: _trigger_live_search())
	top_panel.add_child(_search_input)

	_search_btn = Button.new()
	_search_btn.position = Vector2(1026.0, 8.0)
	_search_btn.size = Vector2(212.0, 32.0)
	_search_btn.text = "[ SEARCH LIVE OSM ]"
	_style_button(_search_btn, COL_HAZARD_YELLOW, COL_INK, COL_INK, 14)
	_search_btn.pressed.connect(_trigger_live_search)
	top_panel.add_child(_search_btn)

	# Row 2: Instant Neighborhood Preset Buttons + Live Status Readout
	var preset_caption := Label.new()
	preset_caption.position = Vector2(12.0, 48.0)
	preset_caption.size = Vector2(150.0, 24.0)
	preset_caption.text = "INSTANT PRESETS:"
	preset_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preset_caption.add_theme_color_override("font_color", Color("#c8bfa8"))
	preset_caption.add_theme_font_size_override("font_size", 12)
	top_panel.add_child(preset_caption)

	var presets: Array = OsmService.get_preset_list()
	var px: float = 152.0
	for p_v in presets:
		var p: Dictionary = p_v
		var pid: String = str(p.get("id", "seattle"))
		var b_label: String = "[ %s ]" % str(p.get("button_label", pid))
		var btn := Button.new()
		var bw: float = float(b_label.length()) * 7.6 + 22.0
		btn.position = Vector2(px, 46.0)
		btn.size = Vector2(bw, 27.0)
		btn.text = b_label
		var captured_id: String = pid
		btn.pressed.connect(func() -> void:
			_play_sfx("button_click")
			_hide_search_results_overlay()
			_load_preset_neighborhood(captured_id, false)
		)
		top_panel.add_child(btn)
		_preset_buttons[pid] = btn
		px += bw + 8.0

	_status_label = Label.new()
	_status_label.position = Vector2(px + 10.0, 46.0)
	_status_label.size = Vector2(1238.0 - (px + 10.0), 27.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.text = "● OSM READY"
	_status_label.add_theme_color_override("font_color", COL_SAFE_GREEN)
	_status_label.add_theme_font_size_override("font_size", 12)
	top_panel.add_child(_status_label)

func _build_map_section() -> void:
	_slippy_map = OsmSlippyMap.new()
	_slippy_map.name = "OsmSlippyMap"
	_slippy_map.position = Vector2(16.0, 94.0)
	_slippy_map.size = Vector2(840.0, 560.0)
	_slippy_map.house_clicked.connect(_on_map_house_clicked)
	add_child(_slippy_map)

	# Tactical Legend Pill overlaid at top of slippy map (non-blocking mouse_filter)
	var legend_bar := Control.new()
	legend_bar.position = Vector2(54.0, 8.0)
	legend_bar.size = Vector2(778.0, 26.0)
	legend_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_bar.draw.connect(func() -> void: _draw_map_legend_strip(legend_bar))
	_slippy_map.add_child(legend_bar)

	# Bottom instruction hint pill on map
	var hint_bar := Control.new()
	hint_bar.position = Vector2(168.0, 532.0)
	hint_bar.size = Vector2(490.0, 22.0)
	hint_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_bar.draw.connect(func() -> void:
		var f: Font = get_theme_default_font()
		if f == null:
			f = ThemeDB.fallback_font
		hint_bar.draw_rect(Rect2(Vector2.ZERO, hint_bar.size), Color(0.10, 0.11, 0.10, 0.86), true)
		hint_bar.draw_rect(Rect2(Vector2.ZERO, hint_bar.size), Color(0.95, 0.75, 0.18, 0.55), false, 1.0)
		hint_bar.draw_string(
			f,
			Vector2(10.0, 15.0),
			"DRAG: PAN   •   WHEEL / [+/-]: ZOOM   •   CLICK ANY BUILDING: CLAIM YOUR HOUSE",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			COL_CARD_PARCHMENT
		)
	)
	_slippy_map.add_child(hint_bar)

func _draw_map_legend_strip(ctrl: Control) -> void:
	var f: Font = get_theme_default_font()
	if f == null:
		f = ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, ctrl.size)
	ctrl.draw_rect(r, Color(0.11, 0.12, 0.11, 0.90), true)
	ctrl.draw_rect(r, COL_HAZARD_YELLOW, false, 1.2)

	var entries: Array = [
		{"cat": "selected", "label": "Your House"},
		{"cat": "church", "label": "Church"},
		{"cat": "grocery", "label": "Grocery"},
		{"cat": "pharmacy", "label": "Pharmacy"},
		{"cat": "civic", "label": "Police/Fire"},
		{"cat": "hardware", "label": "Hardware"},
		{"cat": "school", "label": "School"},
		{"cat": "neighbor_house", "label": "Neighbor"}
	]

	var font_size: int = 10
	var icon_span: float = 17.0
	var text_widths: Array[float] = []
	var total_items_w: float = 0.0
	for e_v in entries:
		var e: Dictionary = e_v
		var txt: String = str(e.get("label", ""))
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		text_widths.append(tw)
		total_items_w += icon_span + tw

	var count_gaps: int = maxi(1, entries.size() - 1)
	var gap: float = clampf((r.size.x - 20.0 - total_items_w) / float(count_gaps), 6.0, 22.0)
	var row_w: float = total_items_w + gap * float(count_gaps)
	var x: float = maxf(10.0, (r.size.x - row_w) * 0.5)
	var baseline_y: float = (r.size.y - f.get_height(font_size)) * 0.5 + f.get_ascent(font_size)

	for idx in range(entries.size()):
		var e: Dictionary = entries[idx]
		var cat: String = str(e.get("cat", ""))
		var txt: String = str(e.get("label", ""))
		var tw: float = text_widths[idx]
		var ic := Vector2(x + 6.5, r.size.y * 0.5)
		if cat == "selected":
			ctrl.draw_circle(ic, 6.5, COL_ATOMIC_ORANGE)
			ctrl.draw_arc(ic, 6.5, 0.0, TAU, 16, COL_HAZARD_YELLOW, 1.7, true)
		else:
			OsmSlippyMap.draw_poi_badge(ctrl, ic, 6.8 if cat != "neighbor_house" else 5.6, cat, false)
		ctrl.draw_string(f, Vector2(x + icon_span, baseline_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COL_CARD_PARCHMENT)
		x += icon_span + tw + gap

func _build_right_sidebar() -> void:
	# 1. Upper Card: Selected House Architectural Blueprint & Metadata (396 x 236)
	var bp_card := Panel.new()
	bp_card.position = Vector2(868.0, 94.0)
	bp_card.size = Vector2(396.0, 236.0)
	bp_card.add_theme_stylebox_override("panel", _make_panel_style(COL_CARD_PARCHMENT, COL_INK, 2, 5))
	add_child(bp_card)

	var bp_header := Panel.new()
	bp_header.position = Vector2(0.0, 0.0)
	bp_header.size = Vector2(396.0, 28.0)
	bp_header.add_theme_stylebox_override("panel", _make_panel_style(COL_INK, COL_HAZARD_YELLOW, 1, 4))
	bp_card.add_child(bp_header)

	var bp_title := Label.new()
	bp_title.position = Vector2(10.0, 2.0)
	bp_title.size = Vector2(265.0, 24.0)
	bp_title.text = "SELECTED HOUSE BLUEPRINT"
	bp_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bp_title.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	bp_title.add_theme_font_size_override("font_size", 13)
	bp_header.add_child(bp_title)

	_lbl_house_osm_id = Label.new()
	_lbl_house_osm_id.position = Vector2(268.0, 2.0)
	_lbl_house_osm_id.size = Vector2(118.0, 24.0)
	_lbl_house_osm_id.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_house_osm_id.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_house_osm_id.text = "OSM #--"
	_lbl_house_osm_id.add_theme_color_override("font_color", Color("#bfb69f"))
	_lbl_house_osm_id.add_theme_font_size_override("font_size", 11)
	bp_header.add_child(_lbl_house_osm_id)

	_blueprint_canvas = Control.new()
	_blueprint_canvas.position = Vector2(10.0, 36.0)
	_blueprint_canvas.size = Vector2(170.0, 190.0)
	_blueprint_canvas.draw.connect(_draw_house_blueprint)
	bp_card.add_child(_blueprint_canvas)

	var meta_vbox := VBoxContainer.new()
	meta_vbox.position = Vector2(188.0, 36.0)
	meta_vbox.size = Vector2(200.0, 190.0)
	meta_vbox.add_theme_constant_override("separation", 5)
	bp_card.add_child(meta_vbox)

	_lbl_house_address = Label.new()
	_lbl_house_address.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_house_address.custom_minimum_size = Vector2(198.0, 38.0)
	_lbl_house_address.add_theme_color_override("font_color", COL_INK)
	_lbl_house_address.add_theme_font_size_override("font_size", 14)
	meta_vbox.add_child(_lbl_house_address)

	_lbl_house_neighborhood = Label.new()
	_lbl_house_neighborhood.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_house_neighborhood.add_theme_color_override("font_color", Color("#564d3f"))
	_lbl_house_neighborhood.add_theme_font_size_override("font_size", 11)
	meta_vbox.add_child(_lbl_house_neighborhood)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(196.0, 2.0)
	sep.color = Color(0.15, 0.13, 0.11, 0.25)
	meta_vbox.add_child(sep)

	_lbl_house_coords = _make_meta_row_label(meta_vbox)
	_lbl_house_area = _make_meta_row_label(meta_vbox)
	_lbl_house_rooms = _make_meta_row_label(meta_vbox)

	var hatch_note := Label.new()
	hatch_note.text = "★ Central Bunker Hatch Installed"
	hatch_note.clip_text = true
	hatch_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hatch_note.add_theme_color_override("font_color", Color("#a63c1c"))
	hatch_note.add_theme_font_size_override("font_size", 11)
	meta_vbox.add_child(hatch_note)

	# 2. Lower Card: Nearby Real-World Scavenge Places Found (396 x 316)
	var poi_card := Panel.new()
	poi_card.position = Vector2(868.0, 338.0)
	poi_card.size = Vector2(396.0, 316.0)
	poi_card.add_theme_stylebox_override("panel", _make_panel_style(COL_CARD_PARCHMENT, COL_INK, 2, 5))
	add_child(poi_card)

	var poi_header := Panel.new()
	poi_header.position = Vector2(0.0, 0.0)
	poi_header.size = Vector2(396.0, 28.0)
	poi_header.add_theme_stylebox_override("panel", _make_panel_style(COL_INK, COL_HAZARD_YELLOW, 1, 4))
	poi_card.add_child(poi_header)

	_lbl_poi_header = Label.new()
	_lbl_poi_header.position = Vector2(10.0, 2.0)
	_lbl_poi_header.size = Vector2(376.0, 24.0)
	_lbl_poi_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_poi_header.text = "NEARBY REAL-WORLD SCAVENGE PLACES"
	_lbl_poi_header.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	_lbl_poi_header.add_theme_font_size_override("font_size", 13)
	poi_header.add_child(_lbl_poi_header)

	_lbl_poi_summary = Label.new()
	_lbl_poi_summary.position = Vector2(8.0, 31.0)
	_lbl_poi_summary.size = Vector2(380.0, 20.0)
	_lbl_poi_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_poi_summary.clip_text = true
	_lbl_poi_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_poi_summary.add_theme_color_override("font_color", Color("#473f33"))
	_lbl_poi_summary.add_theme_font_size_override("font_size", 10)
	poi_card.add_child(_lbl_poi_summary)

	_poi_scroll = ScrollContainer.new()
	_poi_scroll.position = Vector2(8.0, 54.0)
	_poi_scroll.size = Vector2(380.0, 254.0)
	_poi_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	poi_card.add_child(_poi_scroll)

	_poi_list_vbox = VBoxContainer.new()
	_poi_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poi_list_vbox.add_theme_constant_override("separation", 5)
	_poi_scroll.add_child(_poi_list_vbox)

func _make_meta_row_label(parent: VBoxContainer) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(198.0, 0.0)
	lbl.add_theme_color_override("font_color", COL_INK)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(lbl)
	return lbl

func _build_bottom_bar() -> void:
	var bot_panel := Panel.new()
	bot_panel.position = Vector2(16.0, 662.0)
	bot_panel.size = Vector2(1248.0, 50.0)
	bot_panel.add_theme_stylebox_override("panel", _make_panel_style(COL_PANEL_SLATE, COL_INK, 2, 5))
	add_child(bot_panel)

	_btn_back = Button.new()
	_btn_back.position = Vector2(8.0, 6.0)
	_btn_back.size = Vector2(158.0, 38.0)
	_btn_back.text = "[ < FAMILY ]"
	_style_button(_btn_back, Color("#353b35"), COL_CARD_PARCHMENT, COL_HAZARD_YELLOW, 14)
	_btn_back.pressed.connect(func() -> void:
		_play_sfx("button_click")
		GameState.request_screen(GameState.SCREEN_FAMILY)
	)
	bot_panel.add_child(_btn_back)

	_lbl_bottom_summary = Label.new()
	_lbl_bottom_summary.position = Vector2(174.0, 6.0)
	_lbl_bottom_summary.size = Vector2(638.0, 38.0)
	_lbl_bottom_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_bottom_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_bottom_summary.clip_text = true
	_lbl_bottom_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_bottom_summary.add_theme_color_override("font_color", COL_CARD_PARCHMENT)
	_lbl_bottom_summary.add_theme_font_size_override("font_size", 11)
	bot_panel.add_child(_lbl_bottom_summary)

	_btn_confirm = Button.new()
	_btn_confirm.position = Vector2(820.0, 6.0)
	_btn_confirm.size = Vector2(420.0, 38.0)
	_btn_confirm.text = "[ CONFIRM HOUSE & SELECT NUKE GROUND ZERO > ]"
	_style_button(_btn_confirm, COL_ATOMIC_ORANGE, Color("#fff7e4"), COL_HAZARD_YELLOW, 14)
	_btn_confirm.pressed.connect(_on_confirm_house_pressed)
	bot_panel.add_child(_btn_confirm)

func _build_search_results_overlay() -> void:
	_search_results_panel = PanelContainer.new()
	_search_results_panel.position = Vector2(252.0, 50.0)
	_search_results_panel.custom_minimum_size = Vector2(782.0, 34.0)
	_search_results_panel.visible = false
	_search_results_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.11, 0.13, 0.11, 0.97), COL_HAZARD_YELLOW, 2, 4))
	add_child(_search_results_panel)

	_search_results_bar = HBoxContainer.new()
	_search_results_bar.add_theme_constant_override("separation", 6)
	_search_results_panel.add_child(_search_results_bar)

# --- Blueprint Footprint Custom Renderer ---

func _draw_house_blueprint() -> void:
	var r := Rect2(Vector2.ZERO, _blueprint_canvas.size)
	_blueprint_canvas.draw_rect(r, COL_BLUEPRINT_BG, true)

	# Blueprint millimeter coordinate grid
	var step: float = 16.0
	var gx: float = step
	while gx < r.size.x:
		_blueprint_canvas.draw_line(Vector2(gx, 0.0), Vector2(gx, r.size.y), COL_BLUEPRINT_GRID, 1.0)
		gx += step
	var gy: float = step
	while gy < r.size.y:
		_blueprint_canvas.draw_line(Vector2(0.0, gy), Vector2(r.size.x, gy), COL_BLUEPRINT_GRID, 1.0)
		gy += step

	_blueprint_canvas.draw_rect(r, Color("#5aa2d6"), false, 1.8)
	_blueprint_canvas.draw_rect(r.grow(-3.0), Color(0.75, 0.90, 1.0, 0.30), false, 1.0)

	var f: Font = get_theme_default_font()
	if f == null:
		f = ThemeDB.fallback_font

	var house: Dictionary = GameState.selected_house
	var fp_v: Variant = house.get("footprint_meters", [])
	var fp: Array = fp_v if typeof(fp_v) == TYPE_ARRAY else []
	if fp.size() < 3:
		_blueprint_canvas.draw_string(f, Vector2(18.0, 96.0), "NO FOOTPRINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_BLUEPRINT_LINE)
		return

	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	for pt_v in fp:
		var pt: Vector2 = pt_v
		min_p.x = minf(min_p.x, pt.x)
		min_p.y = minf(min_p.y, pt.y)
		max_p.x = maxf(max_p.x, pt.x)
		max_p.y = maxf(max_p.y, pt.y)

	var span_m: Vector2 = (max_p - min_p).max(Vector2(4.0, 4.0))
	var avail := Vector2(r.size.x - 42.0, r.size.y - 48.0)
	var scale_px: float = minf(avail.x / span_m.x, avail.y / span_m.y)
	var mid_m: Vector2 = (min_p + max_p) * 0.5
	var center_px: Vector2 = r.size * 0.5 + Vector2(0.0, -3.0)

	var poly := PackedVector2Array()
	for pt_v in fp:
		var pt: Vector2 = pt_v
		poly.append(center_px + (pt - mid_m) * scale_px)

	# Blueprint shaded interior
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if not tris.is_empty():
		_blueprint_canvas.draw_colored_polygon(poly, Color(0.24, 0.56, 0.82, 0.34))

	# Architectural interior partition preview lines clipped to bounding box
	var bbox_tl: Vector2 = center_px + (min_p - mid_m) * scale_px
	var bbox_br: Vector2 = center_px + (max_p - mid_m) * scale_px
	var bbox_sz: Vector2 = bbox_br - bbox_tl
	if bbox_sz.x > 26.0 and bbox_sz.y > 26.0:
		var rooms_est: int = int(house.get("estimated_rooms", 5))
		var v_splits: int = 2 if rooms_est >= 6 else 1
		for vs in range(1, v_splits + 1):
			var vx: float = bbox_tl.x + bbox_sz.x * (float(vs) / float(v_splits + 1))
			_draw_clipped_blueprint_wall(Vector2(vx, bbox_tl.y), Vector2(vx, bbox_br.y), poly)
		var hy: float = bbox_tl.y + bbox_sz.y * 0.52
		_draw_clipped_blueprint_wall(Vector2(bbox_tl.x, hy), Vector2(bbox_br.x, hy), poly)

	# Crisp double architectural outer wall outline
	var closed := PackedVector2Array()
	closed.append_array(poly)
	closed.append(poly[0])
	_blueprint_canvas.draw_polyline(closed, COL_BLUEPRINT_LINE, 2.4, true)

	# Vertex corner ticks
	for v_pt in poly:
		_blueprint_canvas.draw_rect(Rect2(v_pt - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color("#8ad0ff"), true)

	# Central Bunker Hatch emblem
	var hatch_px: Vector2 = center_px - mid_m * scale_px
	if not Geometry2D.is_point_in_polygon(hatch_px, poly):
		hatch_px = center_px
	_blueprint_canvas.draw_circle(hatch_px, 8.5, COL_INK)
	_blueprint_canvas.draw_arc(hatch_px, 8.5, 0.0, TAU, 20, COL_HAZARD_YELLOW, 2.0, true)
	_blueprint_canvas.draw_circle(hatch_px, 3.0, COL_ATOMIC_ORANGE)

	# North indicator & metric dimensions
	_blueprint_canvas.draw_string(f, Vector2(7.0, 14.0), "N↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#9bd4ff"))
	var dim_str: String = "%.1fm × %.1fm" % [span_m.x, span_m.y]
	_blueprint_canvas.draw_string(f, Vector2(8.0, r.size.y - 7.0), dim_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_BLUEPRINT_LINE)

func _draw_clipped_blueprint_wall(a: Vector2, b: Vector2, poly: PackedVector2Array) -> void:
	var steps: int = 18
	for i in range(steps):
		if i % 2 == 1:
			continue
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var p0: Vector2 = a.lerp(b, t0)
		var p1: Vector2 = a.lerp(b, t1)
		if Geometry2D.is_point_in_polygon((p0 + p1) * 0.5, poly):
			_blueprint_canvas.draw_line(p0, p1, Color(0.85, 0.95, 1.0, 0.45), 1.2)

# --- OSM Data Loading & Selection Flow ---

func _load_preset_neighborhood(preset_id: String, check_existing_selection: bool) -> void:
	_active_preset_id = preset_id
	_refresh_preset_button_styles()

	var parsed: Dictionary = OsmService.load_preset(preset_id)
	var label: String = str(parsed.get("label", "Capitol Hill, Seattle, WA"))
	var pref_id: int = int(parsed.get("preferred_osm_id", -1))

	if check_existing_selection and not GameState.selected_house.is_empty() and not GameState.nearby_pois.is_empty():
		var existing_id: int = int(GameState.selected_house.get("osm_id", -1))
		if existing_id > 0:
			pref_id = existing_id

	_apply_parsed_neighborhood(parsed, label, pref_id)
	var b_count: int = _current_buildings.size()
	var p_count: int = _current_pois.size()
	_set_status_text("● %s • %d BUILDINGS • %d REAL POIS" % [label.to_upper(), b_count, p_count], false)

func _trigger_live_search() -> void:
	var q: String = _search_input.text.strip_edges()
	_play_sfx("button_click")
	_active_preset_id = ""
	_refresh_preset_button_styles()
	_hide_search_results_overlay()
	_osm_service.search_nominatim(q, true)

func _on_osm_status_changed(status_text: String, is_busy: bool) -> void:
	_set_status_text(("◌ " if is_busy else "● ") + status_text, is_busy)

func _on_nominatim_search_completed(results: Array, _query: String) -> void:
	if results.size() <= 1:
		_hide_search_results_overlay()
		return

	# Show compact quick-switch chips if Nominatim returned multiple cities/matches
	for child in _search_results_bar.get_children():
		child.queue_free()

	var title_lbl := Label.new()
	title_lbl.text = " Matches:"
	title_lbl.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	title_lbl.add_theme_font_size_override("font_size", 11)
	_search_results_bar.add_child(title_lbl)

	var count: int = mini(4, results.size())
	for i in range(count):
		var item: Dictionary = results[i]
		var sname: String = str(item.get("short_name", "Match"))
		if sname.length() > 26:
			sname = sname.substr(0, 24) + ".."
		var chip := Button.new()
		chip.text = sname
		_style_button(chip, Color("#2a302b"), COL_CARD_PARCHMENT, COL_HAZARD_YELLOW, 11)
		var r_lat: float = float(item.get("lat", 0.0))
		var r_lon: float = float(item.get("lon", 0.0))
		var full_short: String = str(item.get("short_name", sname))
		chip.pressed.connect(func() -> void:
			_play_sfx("button_click")
			_hide_search_results_overlay()
			_osm_service.fetch_live_osm_bbox(r_lat, r_lon, full_short)
		)
		_search_results_bar.add_child(chip)

	var close_btn := Button.new()
	close_btn.text = "×"
	_style_button(close_btn, COL_INK, COL_HAZARD_YELLOW, COL_HAZARD_YELLOW, 12)
	close_btn.pressed.connect(_hide_search_results_overlay)
	_search_results_bar.add_child(close_btn)
	_search_results_panel.visible = true

func _hide_search_results_overlay() -> void:
	if is_instance_valid(_search_results_panel):
		_search_results_panel.visible = false

func _on_nominatim_search_failed(error_message: String) -> void:
	_set_status_text("▲ " + error_message, false)

func _on_live_map_data_loaded(parsed_data: Dictionary, label: String) -> void:
	_apply_parsed_neighborhood(parsed_data, label, -1)

func _on_extended_data_loaded(ext: Dictionary) -> void:
	_extended_pois = ext.get("pois", [])
	_extended_roads = ext.get("roads", [])
	if not GameState.selected_house.is_empty():
		_select_house(GameState.selected_house, false)


func _on_live_map_data_failed(error_message: String) -> void:
	_set_status_text("▲ " + error_message, false)

func _apply_parsed_neighborhood(parsed: Dictionary, label: String, preferred_osm_id: int) -> void:
	_extended_pois = []
	_extended_roads = []
	_current_neighborhood_label = label
	GameState.current_neighborhood_label = label
	_current_parsed_meta = {
		"roads": parsed.get("roads", []),
		"parks": parsed.get("parks", []),
		"bounds": parsed.get("bounds", {}),
		"source": str(parsed.get("source", "live")),
		"place_names": parsed.get("place_names", {}),
		"landmarks": parsed.get("landmarks", []),
	}
	if str(parsed.get("source", "")) == "live" and is_instance_valid(_osm_service):
		_osm_service.fetch_extended_area(float(parsed.get("center_lat", 0.0)), float(parsed.get("center_lon", 0.0)))

	var b_v: Variant = parsed.get("buildings", [])
	_current_buildings = b_v if typeof(b_v) == TYPE_ARRAY else []
	var p_v: Variant = parsed.get("pois", [])
	_current_pois = p_v if typeof(p_v) == TYPE_ARRAY else []

	_slippy_map.set_map_data(parsed, true)

	var c_lat: float = float(parsed.get("center_lat", 47.6240))
	var c_lon: float = float(parsed.get("center_lon", -122.3195))
	var chosen_house: Dictionary = OsmService.pick_best_house(_current_buildings, c_lat, c_lon, preferred_osm_id)
	if not chosen_house.is_empty():
		_select_house(chosen_house, true)

func _on_map_house_clicked(building_dict: Dictionary) -> void:
	_hide_search_results_overlay()
	_select_house(building_dict, false)

func _select_house(bldg: Dictionary, recenter_softly: bool) -> void:
	if bldg.is_empty():
		return

	var all_pois: Array = _current_pois.duplicate()
	all_pois.append_array(_extended_pois)
	var all_roads: Array = (_current_parsed_meta.get("roads", []) as Array).duplicate()
	all_roads.append_array(_extended_roads)
	var targets: Array = OsmService.build_nearby_targets_for_house(bldg, _current_buildings, all_pois, all_roads)

	var house_copy: Dictionary = bldg.duplicate(true)
	if not _current_neighborhood_label.is_empty():
		var addr_str: String = str(house_copy.get("short_address", str(house_copy.get("address", "Residence"))))
		if addr_str.find(_current_neighborhood_label) == -1:
			house_copy["address"] = "%s, %s" % [addr_str, _current_neighborhood_label]

	GameState.selected_house = house_copy
	GameState.nearby_pois = targets.duplicate(true)
	store_map_context(house_copy, _current_buildings, _current_parsed_meta, _extended_roads)
	GameState.osm_house_selected.emit(GameState.selected_house)

	_slippy_map.set_selected_house(house_copy, targets)
	if recenter_softly:
		_slippy_map.set_center_and_zoom(
			float(house_copy.get("lat", 47.6240)),
			float(house_copy.get("lon", -122.3195)),
			OsmSlippyMap.DEFAULT_ZOOM,
			true
		)

	_refresh_sidebar_inspector(house_copy, targets)

## Copies the real map geometry + place names for the chosen house into GameState so the
## shelter map, expeditions and story text can use true positions and names later.
static func store_map_context(house: Dictionary, buildings: Array, meta: Dictionary, extended_roads: Array) -> void:
	var roads: Array = (meta.get("roads", []) as Array).duplicate()
	roads.append_array(extended_roads)
	GameState.map_roads = roads
	GameState.map_parks = meta.get("parks", [])
	GameState.map_bounds = meta.get("bounds", {})
	GameState.map_source = str(meta.get("source", ""))
	GameState.map_landmarks = meta.get("landmarks", [])
	var lite: Array = []
	var h_lat: float = float(house.get("lat", 0.0))
	var h_lon: float = float(house.get("lon", 0.0))
	for b_v in buildings:
		var b: Dictionary = b_v
		var db: Dictionary = OsmService.distance_and_bearing(h_lat, h_lon, float(b.get("lat", 0.0)), float(b.get("lon", 0.0)))
		if float(db["distance_m"]) > 650.0:
			continue
		lite.append({"osm_id": int(b.get("osm_id", 0)), "polygon_latlon": b.get("polygon_latlon", []), "is_residential": bool(b.get("is_residential", true))})
	GameState.map_buildings = lite
	var pn: Dictionary = (meta.get("place_names", {}) as Dictionary).duplicate()
	var st: String = str(house.get("street", ""))
	if not st.is_empty():
		pn["street"] = st
	var hn: String = str(house.get("housenumber", ""))
	if not hn.is_empty():
		pn["housenumber"] = hn
	var pc: String = str(house.get("postcode", ""))
	if not pc.is_empty():
		pn["postcode"] = pc
	var cty: String = str(house.get("city", ""))
	if not cty.is_empty() and str(pn.get("city", "")).is_empty():
		pn["city"] = cty
	GameState.place_names = pn


func _refresh_sidebar_inspector(house: Dictionary, targets: Array) -> void:
	var short_addr: String = str(house.get("short_address", str(house.get("address", "Selected House"))))
	var osm_id_val: int = int(house.get("osm_id", 0))
	var lat_val: float = float(house.get("lat", 0.0))
	var lon_val: float = float(house.get("lon", 0.0))
	var area_val: float = float(house.get("area_sqm", 120.0))
	var rooms_val: int = int(house.get("estimated_rooms", 5))
	var btype_val: String = OsmService.format_building_type(str(house.get("building_type", "house")))

	_lbl_house_osm_id.text = "FICTIONAL — no mapped building" if bool(house.get("fictional", false)) else ("OSM way %d" % osm_id_val)
	_lbl_house_address.text = short_addr
	_lbl_house_neighborhood.text = _current_neighborhood_label

	var ns_char: String = "N" if lat_val >= 0.0 else "S"
	var ew_char: String = "E" if lon_val >= 0.0 else "W"
	_lbl_house_coords.text = "Coords: %.4f° %s, %.4f° %s" % [absf(lat_val), ns_char, absf(lon_val), ew_char]
	_lbl_house_area.text = "Footprint: %.1f m² (%s)" % [area_val, btype_val]
	_lbl_house_rooms.text = "Interior: ~%d rooms (fictional layout in real outline)" % rooms_val

	_blueprint_canvas.queue_redraw()
	_populate_poi_list(targets)

	_lbl_bottom_summary.text = "★ HOUSE: %s • %d Scavenge Targets Mapped" % [
		short_addr,
		targets.size()
	]

func _populate_poi_list(targets: Array) -> void:
	for child in _poi_list_vbox.get_children():
		child.queue_free()

	_lbl_poi_header.text = "NEARBY SCAVENGE PLACES FOUND (%d)" % targets.size()

	var counts: Dictionary = {"church": 0, "grocery": 0, "pharmacy": 0, "civic": 0, "hardware": 0, "auto": 0, "school": 0, "neighbor_house": 0}
	for t_v in targets:
		var t: Dictionary = t_v
		var c: String = str(t.get("category", ""))
		if counts.has(c):
			counts[c] = int(counts[c]) + 1
	# What the real neighbourhood offers decides which survival routes exist.
	_lbl_poi_summary.text = "Food %d · Med %d · Hardware %d · Fuel/Auto %d · Church/School %d · Police/Fire %d · Homes %d" % [
		int(counts["grocery"]), int(counts["pharmacy"]), int(counts["hardware"]), int(counts["auto"]),
		int(counts["church"]) + int(counts["school"]), int(counts["civic"]), int(counts["neighbor_house"])
	]

	for idx in range(targets.size()):
		var t: Dictionary = targets[idx]
		var row: PanelContainer = _create_poi_row_card(t)
		_poi_list_vbox.add_child(row)

func _create_poi_row_card(poi: Dictionary) -> PanelContainer:
	var cat: String = str(poi.get("category", "grocery"))
	var poi_id: int = int(poi.get("osm_id", -1))
	var pname: String = str(poi.get("name", "Landmark"))
	var dist_m: int = int(poi.get("distance_m", 100))
	var bearing: String = str(poi.get("bearing_dir", "N"))
	var days: int = int(poi.get("travel_days", 1))
	var loot_v: Variant = poi.get("loot_profile", [])
	var loot_arr: Array = loot_v if typeof(loot_v) == TYPE_ARRAY else []

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(364.0, 42.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_sb: StyleBoxFlat = _make_panel_style(COL_CARD_AGED, Color(0.18, 0.16, 0.13, 0.55), 1, 4)
	var hover_sb: StyleBoxFlat = _make_panel_style(Color("#f7e7b4"), COL_ATOMIC_ORANGE, 2, 4)
	card.add_theme_stylebox_override("panel", normal_sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var icon_ctrl := Control.new()
	icon_ctrl.custom_minimum_size = Vector2(28.0, 36.0)
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var captured_cat: String = cat
	icon_ctrl.draw.connect(func() -> void:
		OsmSlippyMap.draw_poi_badge(icon_ctrl, Vector2(15.0, 19.0), 10.0 if captured_cat != "neighbor_house" else 8.0, captured_cat, false)
	)
	hbox.add_child(icon_ctrl)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 1)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = pname
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_color_override("font_color", COL_INK)
	name_lbl.add_theme_font_size_override("font_size", 12)
	text_vbox.add_child(name_lbl)

	var loot_pretty: PackedStringArray = PackedStringArray()
	for i in range(mini(3, loot_arr.size())):
		loot_pretty.append(str(loot_arr[i]).replace("_", " ").capitalize())
	var sub_lbl := Label.new()
	var kind_txt: String = str(poi.get("kind_label", OsmService.get_category_label(cat)))
	sub_lbl.text = "%s  •  OSM %s %d" % [kind_txt, str(poi.get("osm_type", "node")), int(poi.get("osm_id", 0))]
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_lbl.add_theme_color_override("font_color", Color("#524839"))
	sub_lbl.add_theme_font_size_override("font_size", 10)
	text_vbox.add_child(sub_lbl)

	var dist_lbl := Label.new()
	dist_lbl.custom_minimum_size = Vector2(76.0, 36.0)
	dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dist_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var walk_m: int = int(poi.get("walk_m", dist_m))
	var walk_tag: String = "walk" if str(poi.get("walk_source", "")) == "network" else "est."
	dist_lbl.text = "%dm %s %s\n%dd trip " % [walk_m, walk_tag, bearing, days]
	dist_lbl.add_theme_color_override("font_color", Color("#8c2f16") if cat != "neighbor_house" else Color("#4a4235"))
	dist_lbl.add_theme_font_size_override("font_size", 11)
	hbox.add_child(dist_lbl)

	var captured_id: int = poi_id
	var captured_lat: float = float(poi.get("lat", 0.0))
	var captured_lon: float = float(poi.get("lon", 0.0))
	card.mouse_entered.connect(func() -> void:
		card.add_theme_stylebox_override("panel", hover_sb)
		_slippy_map.set_highlighted_poi_id(captured_id)
	)
	card.mouse_exited.connect(func() -> void:
		card.add_theme_stylebox_override("panel", normal_sb)
		_slippy_map.set_highlighted_poi_id(-1)
	)
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb: InputEventMouseButton = ev
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_play_sfx("tick")
				_slippy_map.set_highlighted_poi_id(captured_id)
				_slippy_map.pan_smooth_to(captured_lat, captured_lon, 0.45)
	)

	return card

func _on_confirm_house_pressed() -> void:
	_play_sfx("button_click")
	if GameState.selected_house.is_empty() and not _current_buildings.is_empty():
		_select_house(_current_buildings[0], false)
	GameState.osm_house_selected.emit(GameState.selected_house)
	GameState.request_screen(GameState.SCREEN_NUKE)

# --- Automated Demo Mode Choreography (~4.5s) ---

func _init_demo_mode() -> void:
	_demo_elapsed = 0.0
	_demo_stage = 0
	_demo_finished = false

	# Prominent CONELRAD Hazard Banner across top of map
	_demo_banner = Control.new()
	_demo_banner.position = Vector2(26.0, 132.0)
	_demo_banner.size = Vector2(820.0, 36.0)
	_demo_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_banner.draw.connect(func() -> void:
		var f: Font = get_theme_default_font()
		if f == null:
			f = ThemeDB.fallback_font
		var r := Rect2(Vector2.ZERO, _demo_banner.size)
		_demo_banner.draw_rect(r, COL_INK, true)
		_demo_banner.draw_rect(r, COL_HAZARD_YELLOW, false, 2.5)
		_demo_banner.draw_rect(Rect2(4.0, 4.0, 10.0, r.size.y - 8.0), COL_ATOMIC_ORANGE, true)
		_demo_banner.draw_string(
			f,
			Vector2(22.0, 23.0),
			"DEMO: PICKING REAL HOUSE & SCANNING NEARBY CHURCHES / GROCERY STORES VIA OPENSTREETMAP",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			COL_HAZARD_YELLOW
		)
	)
	add_child(_demo_banner)

	# Stage 0: Highlight first house on Federal Ave E & pan Northwest across Capitol Hill
	_search_input.text = "Capitol Hill, Seattle, WA"
	var h1: Dictionary = OsmService.pick_best_house(_current_buildings, 47.62375, -122.31911, 206082387)
	if not h1.is_empty():
		_select_house(h1, true)
		_slippy_map.set_hovered_house_by_id(int(h1.get("osm_id", -1)))
	_slippy_map.pan_smooth_to(47.62455, -122.31965, 1.25)

func _tick_demo_mode(delta: float) -> void:
	_demo_elapsed += delta

	if _demo_stage == 0 and _demo_elapsed >= 1.30:
		_demo_stage = 1
		# Stage 1: Highlight & select second house on 10th Ave E, pan toward Broadway Church & QFC
		var h2: Dictionary = OsmService.pick_best_house(_current_buildings, 47.62459, -122.31965, 206082296)
		if not h2.is_empty():
			_play_sfx("tick")
			_select_house(h2, false)
			_slippy_map.set_hovered_house_by_id(int(h2.get("osm_id", -1)))
		_slippy_map.pan_smooth_to(47.62315, -122.32045, 1.35)

	elif _demo_stage == 1 and _demo_elapsed >= 2.65:
		_demo_stage = 2
		# Stage 2: Select final real house right next to All Pilgrims Christian Church & QFC Supermarket!
		var h3: Dictionary = OsmService.pick_best_house(_current_buildings, 47.62331, -122.31968, 206082403)
		if not h3.is_empty():
			_play_sfx("button_click")
			_select_house(h3, false)
			_slippy_map.set_hovered_house_by_id(-1)
			# Highlight QFC Supermarket (1726081341) or All Pilgrims Christian Church (356550413)
			_slippy_map.set_highlighted_poi_id(356550413)

	elif _demo_stage == 2 and _demo_elapsed >= 3.60:
		_demo_stage = 3
		_slippy_map.set_highlighted_poi_id(1726081341)

	elif _demo_elapsed >= 4.55 and not _demo_finished:
		_demo_finished = true
		_play_sfx("button_click")
		GameState.osm_house_selected.emit(GameState.selected_house)
		GameState.request_screen(GameState.SCREEN_NUKE)

# --- Visual Styling Helpers ---

func _set_status_text(txt: String, busy: bool) -> void:
	_status_busy = busy
	if is_instance_valid(_status_label):
		_status_label.text = txt
		_status_label.add_theme_color_override("font_color", COL_HAZARD_YELLOW if busy else COL_SAFE_GREEN)

func _refresh_preset_button_styles() -> void:
	for pid_k in _preset_buttons.keys():
		var pid: String = str(pid_k)
		var btn: Button = _preset_buttons[pid]
		if pid == _active_preset_id:
			_style_button(btn, COL_HAZARD_YELLOW, COL_INK, COL_INK, 12)
		else:
			_style_button(btn, Color("#303630"), COL_CARD_PARCHMENT, Color("#6e756a"), 12)

func _make_panel_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb

func _style_search_input(le: LineEdit) -> void:
	var normal := _make_panel_style(COL_CARD_PARCHMENT, COL_INK, 2, 4)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	var focus := _make_panel_style(Color("#fff7e2"), COL_ATOMIC_ORANGE, 2, 4)
	focus.content_margin_left = 10.0
	focus.content_margin_right = 10.0
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", COL_INK)
	le.add_theme_color_override("font_placeholder_color", Color("#6e6352"))
	le.add_theme_color_override("caret_color", COL_ATOMIC_ORANGE)
	le.add_theme_font_size_override("font_size", 13)

func _style_button(btn: Button, bg: Color, fg: Color, border: Color, fsize: int) -> void:
	var normal := _make_panel_style(bg, border, 2, 4)
	var hover := _make_panel_style(bg.lightened(0.14), COL_HAZARD_YELLOW, 2, 4)
	var pressed_sb := _make_panel_style(bg.darkened(0.15), COL_CARD_PARCHMENT, 2, 4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg.lightened(0.10))
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_font_size_override("font_size", fsize)

func _play_sfx(sfx_name: String) -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx(sfx_name)
