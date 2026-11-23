class_name HouseSelectScreen
extends Control

## Step 2 Screen (1280x720): Real-World OpenStreetMap House & Multi-Ring (0-9.5km) Scavenge Recon.
## Features live Nominatim address/city search, live OSM API 0.6 + polite wide-area multi-ring POI scanning,
## 4 instant authentic OSM presets ([ Seattle ], [ Suburban VA ], [ Concord ], [ Brooklyn ]),
## interactive OsmSlippyMap parcel picker, architectural footprint blueprint preview,
## Neighborhood Gameplay Impact banner, and Ring Filter Pills (All, Near <0.5km, District 0.5-3.5km, Deep 3.5km+).

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

# Right sidebar: Blueprint, House Info & Neighborhood Gameplay Impact Banner
var _blueprint_canvas: Control
var _lbl_house_address: Label
var _lbl_house_neighborhood: Label
var _lbl_house_coords: Label
var _lbl_house_area: Label
var _lbl_house_rooms: Label
var _lbl_house_osm_id: Label
var _impact_panel: Panel
var _lbl_impact_title: Label
var _lbl_impact_body: Label

# Right sidebar: Ring Filter Pills & Nearby POIs list
var _lbl_poi_header: Label
var _ring_filter_buttons: Dictionary = {}
var _active_ring_filter: int = 0
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
var _current_targets: Array = []
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
	_osm_service.map_data_failed.connect(_on_live_map_data_failed)
	_osm_service.wide_area_pois_merged.connect(_on_wide_area_pois_merged)

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

# --- UI Construction (1280x720 Zero-Clipping Layout) ---

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
	_search_input.placeholder_text = "Type any street address, suburb, or city (e.g. Wyndham VA, Seattle, Boston, London)..."
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

	# Row 2: Instant Presets ([ Seattle ], [ Suburban VA ], [ Concord ], [ Brooklyn ]) + Live Status
	var preset_caption := Label.new()
	preset_caption.position = Vector2(12.0, 48.0)
	preset_caption.size = Vector2(126.0, 24.0)
	preset_caption.text = "INSTANT PRESETS:"
	preset_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preset_caption.add_theme_color_override("font_color", Color("#c8bfa8"))
	preset_caption.add_theme_font_size_override("font_size", 11)
	top_panel.add_child(preset_caption)

	var font_ref: Font = get_theme_default_font()
	if font_ref == null:
		font_ref = ThemeDB.fallback_font

	var presets: Array = OsmService.get_preset_list()
	var px: float = 140.0
	for p_v in presets:
		var p: Dictionary = p_v
		var pid: String = str(p.get("id", "seattle"))
		var b_label: String = "[ %s ]" % str(p.get("button_label", pid))
		var full_lbl: String = str(p.get("neighborhood_label", b_label))
		var btn := Button.new()
		var txt_w: float = font_ref.get_string_size(b_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var bw: float = maxf(88.0, ceilf(txt_w + 22.0))
		btn.position = Vector2(px, 46.0)
		btn.size = Vector2(bw, 27.0)
		btn.text = b_label
		btn.tooltip_text = "Load bundled real-world OSM neighborhood: %s" % full_lbl
		var captured_id: String = pid
		btn.pressed.connect(func() -> void:
			_play_sfx("button_click")
			_osm_service.cancel_requests()
			_hide_search_results_overlay()
			_load_preset_neighborhood(captured_id, false)
		)
		top_panel.add_child(btn)
		_preset_buttons[pid] = btn
		px += bw + 7.0

	_status_label = Label.new()
	_status_label.position = Vector2(px + 8.0, 46.0)
	_status_label.size = Vector2(maxf(120.0, 1238.0 - (px + 8.0)), 27.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.text = "● OSM READY"
	_status_label.add_theme_color_override("font_color", COL_SAFE_GREEN)
	_status_label.add_theme_font_size_override("font_size", 11)
	top_panel.add_child(_status_label)

func _build_map_section() -> void:
	_slippy_map = OsmSlippyMap.new()
	_slippy_map.name = "OsmSlippyMap"
	_slippy_map.position = Vector2(16.0, 94.0)
	_slippy_map.size = Vector2(828.0, 560.0)
	_slippy_map.house_clicked.connect(_on_map_house_clicked)
	add_child(_slippy_map)

	# Tactical Legend Pill overlaid at top of slippy map (all 9 V2 categories + Your House, zero clipping)
	var legend_bar := Control.new()
	legend_bar.position = Vector2(54.0, 8.0)
	legend_bar.size = Vector2(766.0, 26.0)
	legend_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_bar.draw.connect(func() -> void: _draw_map_legend_strip(legend_bar))
	_slippy_map.add_child(legend_bar)

	# Bottom instruction hint pill on map
	var hint_bar := Control.new()
	hint_bar.position = Vector2(158.0, 532.0)
	hint_bar.size = Vector2(482.0, 22.0)
	hint_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_bar.draw.connect(func() -> void:
		var f: Font = get_theme_default_font()
		if f == null:
			f = ThemeDB.fallback_font
		hint_bar.draw_rect(Rect2(Vector2.ZERO, hint_bar.size), Color(0.10, 0.11, 0.10, 0.86), true)
		hint_bar.draw_rect(Rect2(Vector2.ZERO, hint_bar.size), Color(0.95, 0.75, 0.18, 0.55), false, 1.0)
		var msg := "DRAG: PAN  •  WHEEL/[+/-]: ZOOM RINGS  •  CLICK PARCEL: CLAIM HOUSE"
		var tw: float = f.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var tx: float = maxf(8.0, (hint_bar.size.x - tw) * 0.5)
		hint_bar.draw_string(f, Vector2(tx, 15.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_CARD_PARCHMENT)
	)
	_slippy_map.add_child(hint_bar)

func _draw_map_legend_strip(ctrl: Control) -> void:
	var f: Font = get_theme_default_font()
	if f == null:
		f = ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, ctrl.size)
	ctrl.draw_rect(r, Color(0.11, 0.12, 0.11, 0.92), true)
	ctrl.draw_rect(r, COL_HAZARD_YELLOW, false, 1.2)

	var entries: Array = [
		{"cat": "selected", "label": "House"},
		{"cat": "grocery", "label": "Grocery"},
		{"cat": "doctor", "label": "Doctor"},
		{"cat": "pharmacy", "label": "Rx"},
		{"cat": "fuel_auto", "label": "Gas/Auto"},
		{"cat": "hardware", "label": "Hardware"},
		{"cat": "civic", "label": "Police"},
		{"cat": "church", "label": "Church"},
		{"cat": "school", "label": "School"},
		{"cat": "neighbor_house", "label": "Nbr"}
	]

	var font_size: int = 10
	var icon_span: float = 15.5
	var text_widths: Array[float] = []
	var total_items_w: float = 0.0

	for attempt in range(2):
		text_widths.clear()
		total_items_w = 0.0
		for e_v in entries:
			var e: Dictionary = e_v
			var txt: String = str(e.get("label", ""))
			var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			text_widths.append(tw)
			total_items_w += icon_span + tw
		if total_items_w + float(entries.size() - 1) * 6.0 <= r.size.x - 14.0 or attempt == 1:
			break
		font_size = 9
		icon_span = 14.0

	var count_gaps: int = maxi(1, entries.size() - 1)
	var gap: float = clampf((r.size.x - 16.0 - total_items_w) / float(count_gaps), 4.0, 16.0)
	var row_w: float = total_items_w + gap * float(count_gaps)
	var x: float = maxf(8.0, (r.size.x - row_w) * 0.5)
	var baseline_y: float = (r.size.y - f.get_height(font_size)) * 0.5 + f.get_ascent(font_size)

	for idx in range(entries.size()):
		var e: Dictionary = entries[idx]
		var cat: String = str(e.get("cat", ""))
		var txt: String = str(e.get("label", ""))
		var tw: float = text_widths[idx]
		var ic := Vector2(x + 6.0, r.size.y * 0.5)
		if cat == "selected":
			ctrl.draw_circle(ic, 6.0, COL_ATOMIC_ORANGE)
			ctrl.draw_arc(ic, 6.0, 0.0, TAU, 16, COL_HAZARD_YELLOW, 1.6, true)
		else:
			OsmSlippyMap.draw_poi_badge(ctrl, ic, 6.4 if cat != "neighbor_house" else 5.4, cat, false)
		ctrl.draw_string(f, Vector2(x + icon_span, baseline_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COL_CARD_PARCHMENT)
		x += icon_span + tw + gap

func _build_right_sidebar() -> void:
	# 1. Upper Card: Selected House Architectural Blueprint + Neighborhood Gameplay Impact (410 x 238)
	var bp_card := Panel.new()
	bp_card.position = Vector2(854.0, 94.0)
	bp_card.size = Vector2(410.0, 238.0)
	bp_card.add_theme_stylebox_override("panel", _make_panel_style(COL_CARD_PARCHMENT, COL_INK, 2, 5))
	add_child(bp_card)

	var bp_header := Panel.new()
	bp_header.position = Vector2(0.0, 0.0)
	bp_header.size = Vector2(410.0, 26.0)
	bp_header.add_theme_stylebox_override("panel", _make_panel_style(COL_INK, COL_HAZARD_YELLOW, 1, 4))
	bp_card.add_child(bp_header)

	var bp_title := Label.new()
	bp_title.position = Vector2(10.0, 1.0)
	bp_title.size = Vector2(268.0, 24.0)
	bp_title.text = "SELECTED HOUSE & DISTRICT"
	bp_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bp_title.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	bp_title.add_theme_font_size_override("font_size", 12)
	bp_header.add_child(bp_title)

	_lbl_house_osm_id = Label.new()
	_lbl_house_osm_id.position = Vector2(280.0, 1.0)
	_lbl_house_osm_id.size = Vector2(120.0, 24.0)
	_lbl_house_osm_id.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_house_osm_id.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_house_osm_id.text = "OSM #--"
	_lbl_house_osm_id.add_theme_color_override("font_color", Color("#bfb69f"))
	_lbl_house_osm_id.add_theme_font_size_override("font_size", 11)
	bp_header.add_child(_lbl_house_osm_id)

	_blueprint_canvas = Control.new()
	_blueprint_canvas.position = Vector2(8.0, 30.0)
	_blueprint_canvas.size = Vector2(148.0, 128.0)
	_blueprint_canvas.draw.connect(_draw_house_blueprint)
	bp_card.add_child(_blueprint_canvas)

	var meta_vbox := VBoxContainer.new()
	meta_vbox.position = Vector2(164.0, 30.0)
	meta_vbox.size = Vector2(238.0, 128.0)
	meta_vbox.add_theme_constant_override("separation", 3)
	bp_card.add_child(meta_vbox)

	_lbl_house_address = Label.new()
	_lbl_house_address.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_house_address.max_lines_visible = 2
	_lbl_house_address.custom_minimum_size = Vector2(236.0, 0.0)
	_lbl_house_address.add_theme_color_override("font_color", COL_INK)
	_lbl_house_address.add_theme_font_size_override("font_size", 13)
	meta_vbox.add_child(_lbl_house_address)

	_lbl_house_neighborhood = Label.new()
	_lbl_house_neighborhood.clip_text = true
	_lbl_house_neighborhood.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_house_neighborhood.add_theme_color_override("font_color", Color("#564d3f"))
	_lbl_house_neighborhood.add_theme_font_size_override("font_size", 10)
	meta_vbox.add_child(_lbl_house_neighborhood)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(234.0, 1.0)
	sep.color = Color(0.15, 0.13, 0.11, 0.24)
	meta_vbox.add_child(sep)

	_lbl_house_coords = _make_meta_row_label(meta_vbox, 10)
	_lbl_house_area = _make_meta_row_label(meta_vbox, 10)
	_lbl_house_rooms = _make_meta_row_label(meta_vbox, 10)
	_lbl_house_rooms.add_theme_color_override("font_color", Color("#9a3518"))

	# Neighborhood Gameplay Impact Summary Banner
	_impact_panel = Panel.new()
	_impact_panel.position = Vector2(8.0, 162.0)
	_impact_panel.size = Vector2(394.0, 68.0)
	_impact_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_impact_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#1d221e"), COL_ATOMIC_ORANGE, 2, 4))
	bp_card.add_child(_impact_panel)

	_lbl_impact_title = Label.new()
	_lbl_impact_title.position = Vector2(8.0, 3.0)
	_lbl_impact_title.size = Vector2(378.0, 16.0)
	_lbl_impact_title.clip_text = true
	_lbl_impact_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_impact_title.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	_lbl_impact_title.add_theme_font_size_override("font_size", 10)
	_impact_panel.add_child(_lbl_impact_title)

	_lbl_impact_body = Label.new()
	_lbl_impact_body.position = Vector2(8.0, 20.0)
	_lbl_impact_body.size = Vector2(378.0, 45.0)
	_lbl_impact_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_impact_body.clip_text = true
	_lbl_impact_body.max_lines_visible = 3
	_lbl_impact_body.add_theme_color_override("font_color", COL_CARD_PARCHMENT)
	_lbl_impact_body.add_theme_font_size_override("font_size", 10)
	_impact_panel.add_child(_lbl_impact_body)

	# 2. Lower Card: Nearby Scavenge Places + Ring Filter Pills (410 x 316)
	var poi_card := Panel.new()
	poi_card.position = Vector2(854.0, 338.0)
	poi_card.size = Vector2(410.0, 316.0)
	poi_card.add_theme_stylebox_override("panel", _make_panel_style(COL_CARD_PARCHMENT, COL_INK, 2, 5))
	add_child(poi_card)

	var poi_header := Panel.new()
	poi_header.position = Vector2(0.0, 0.0)
	poi_header.size = Vector2(410.0, 26.0)
	poi_header.add_theme_stylebox_override("panel", _make_panel_style(COL_INK, COL_HAZARD_YELLOW, 1, 4))
	poi_card.add_child(poi_header)

	_lbl_poi_header = Label.new()
	_lbl_poi_header.position = Vector2(10.0, 1.0)
	_lbl_poi_header.size = Vector2(390.0, 24.0)
	_lbl_poi_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_poi_header.clip_text = true
	_lbl_poi_header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_poi_header.text = "NEARBY SCAVENGE PLACES"
	_lbl_poi_header.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	_lbl_poi_header.add_theme_font_size_override("font_size", 12)
	poi_header.add_child(_lbl_poi_header)

	# Ring Filter Pills Row: All | Near <0.5km | District 0.5-3.5km | Deep 3.5km+
	var filter_hbox := HBoxContainer.new()
	filter_hbox.position = Vector2(6.0, 30.0)
	filter_hbox.size = Vector2(398.0, 25.0)
	filter_hbox.add_theme_constant_override("separation", 4)
	poi_card.add_child(filter_hbox)

	var filter_defs: Array = [
		{"id": 0, "label": "All", "tip": "Show all mapped scavenge places across Rings 1-3 (0-9.5 km)"},
		{"id": 1, "label": "Near <0.5km", "tip": "Ring 1 (0-500m, 1-day sprint): Immediate shops & Neighbor Houses"},
		{"id": 2, "label": "District 0.5-3.5km", "tip": "Ring 2 (0.5-3.5 km, 2-3 day trek): District Supermarkets, Clinics & Gas"},
		{"id": 3, "label": "Deep 3.5km+", "tip": "Ring 3 (3.5 km+, 3-4 day expedition): Regional Hospitals, Depots & Precincts"}
	]
	for fd_v in filter_defs:
		var fd: Dictionary = fd_v
		var fid: int = int(fd.get("id", 0))
		var pill_btn := Button.new()
		pill_btn.text = str(fd.get("label", "All"))
		pill_btn.tooltip_text = str(fd.get("tip", ""))
		pill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL if fid > 0 else Control.SIZE_FILL
		if fid == 0:
			pill_btn.custom_minimum_size = Vector2(46.0, 25.0)
		var captured_ring: int = fid
		pill_btn.pressed.connect(func() -> void:
			_play_sfx("tick")
			_set_ring_filter(captured_ring, true)
		)
		filter_hbox.add_child(pill_btn)
		_ring_filter_buttons[fid] = pill_btn

	_refresh_ring_filter_styles()

	_lbl_poi_summary = Label.new()
	_lbl_poi_summary.position = Vector2(8.0, 57.0)
	_lbl_poi_summary.size = Vector2(394.0, 17.0)
	_lbl_poi_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_poi_summary.clip_text = true
	_lbl_poi_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_poi_summary.add_theme_color_override("font_color", Color("#473f33"))
	_lbl_poi_summary.add_theme_font_size_override("font_size", 10)
	poi_card.add_child(_lbl_poi_summary)

	_poi_scroll = ScrollContainer.new()
	_poi_scroll.position = Vector2(8.0, 76.0)
	_poi_scroll.size = Vector2(394.0, 232.0)
	_poi_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	poi_card.add_child(_poi_scroll)

	_poi_list_vbox = VBoxContainer.new()
	_poi_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poi_list_vbox.add_theme_constant_override("separation", 5)
	_poi_scroll.add_child(_poi_list_vbox)

func _make_meta_row_label(parent: VBoxContainer, fsize: int = 10) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(236.0, 0.0)
	lbl.add_theme_color_override("font_color", COL_INK)
	lbl.add_theme_font_size_override("font_size", fsize)
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
		_osm_service.cancel_requests()
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

	var step: float = 14.0
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
		_blueprint_canvas.draw_string(f, Vector2(14.0, 68.0), "NO FOOTPRINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_BLUEPRINT_LINE)
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
	var avail := Vector2(r.size.x - 32.0, r.size.y - 38.0)
	var scale_px: float = minf(avail.x / span_m.x, avail.y / span_m.y)
	var mid_m: Vector2 = (min_p + max_p) * 0.5
	var center_px: Vector2 = r.size * 0.5 + Vector2(0.0, -2.0)

	var poly := PackedVector2Array()
	for pt_v in fp:
		var pt: Vector2 = pt_v
		poly.append(center_px + (pt - mid_m) * scale_px)

	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if not tris.is_empty():
		_blueprint_canvas.draw_colored_polygon(poly, Color(0.24, 0.56, 0.82, 0.34))

	var bbox_tl: Vector2 = center_px + (min_p - mid_m) * scale_px
	var bbox_br: Vector2 = center_px + (max_p - mid_m) * scale_px
	var bbox_sz: Vector2 = bbox_br - bbox_tl
	if bbox_sz.x > 22.0 and bbox_sz.y > 22.0:
		var rooms_est: int = int(house.get("estimated_rooms", 5))
		var v_splits: int = 2 if rooms_est >= 6 else 1
		for vs in range(1, v_splits + 1):
			var vx: float = bbox_tl.x + bbox_sz.x * (float(vs) / float(v_splits + 1))
			_draw_clipped_blueprint_wall(Vector2(vx, bbox_tl.y), Vector2(vx, bbox_br.y), poly)
		var hy: float = bbox_tl.y + bbox_sz.y * 0.52
		_draw_clipped_blueprint_wall(Vector2(bbox_tl.x, hy), Vector2(bbox_br.x, hy), poly)

	var closed := PackedVector2Array()
	closed.append_array(poly)
	closed.append(poly[0])
	_blueprint_canvas.draw_polyline(closed, COL_BLUEPRINT_LINE, 2.2, true)

	for v_pt in poly:
		_blueprint_canvas.draw_rect(Rect2(v_pt - Vector2(1.8, 1.8), Vector2(3.6, 3.6)), Color("#8ad0ff"), true)

	var hatch_px: Vector2 = center_px - mid_m * scale_px
	if not Geometry2D.is_point_in_polygon(hatch_px, poly):
		hatch_px = center_px
	_blueprint_canvas.draw_circle(hatch_px, 7.2, COL_INK)
	_blueprint_canvas.draw_arc(hatch_px, 7.2, 0.0, TAU, 20, COL_HAZARD_YELLOW, 1.8, true)
	_blueprint_canvas.draw_circle(hatch_px, 2.5, COL_ATOMIC_ORANGE)

	_blueprint_canvas.draw_string(f, Vector2(6.0, 13.0), "N↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#9bd4ff"))
	var dim_str: String = "%.1fm × %.1fm" % [span_m.x, span_m.y]
	_blueprint_canvas.draw_string(f, Vector2(7.0, r.size.y - 6.0), dim_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_BLUEPRINT_LINE)

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

# --- OSM Data Loading, Wide-Area Live Merge & Selection Flow ---

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

	_active_ring_filter = 0
	_refresh_ring_filter_styles()
	_slippy_map.set_ring_filter(0, false)

	_apply_parsed_neighborhood(parsed, label, pref_id)
	var b_count: int = _current_buildings.size()
	var p_count: int = _current_pois.size()
	_set_status_text("● %s • %d BLDGS • %d MULTI-RING POIS" % [label.to_upper(), b_count, p_count], false)

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
	_active_ring_filter = 0
	_refresh_ring_filter_styles()
	_slippy_map.set_ring_filter(0, false)
	_apply_parsed_neighborhood(parsed_data, label, -1)

func _on_live_map_data_failed(error_message: String) -> void:
	_set_status_text("▲ " + error_message, false)

func _on_wide_area_pois_merged(all_pois: Array, _added_count: int) -> void:
	_current_pois = all_pois
	_slippy_map.update_pois_only(_current_pois)
	if not GameState.selected_house.is_empty():
		var cur_house: Dictionary = GameState.selected_house
		var targets: Array = OsmService.build_nearby_targets_for_house(
			cur_house,
			_current_buildings,
			_current_pois,
			_current_neighborhood_label
		)
		_current_targets = targets
		GameState.nearby_pois = targets.duplicate(true)
		GameState.neighborhood_modifiers = OsmService.compute_neighborhood_modifiers(targets)
		_slippy_map.set_selected_house(cur_house, targets)
		_refresh_sidebar_inspector(cur_house, targets)

func _apply_parsed_neighborhood(parsed: Dictionary, label: String, preferred_osm_id: int) -> void:
	_current_neighborhood_label = label
	GameState.current_neighborhood_label = label

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

	var house_copy: Dictionary = bldg.duplicate(true)
	if not _current_neighborhood_label.is_empty():
		var addr_str: String = str(house_copy.get("short_address", str(house_copy.get("address", "Residence"))))
		if addr_str.find(_current_neighborhood_label) == -1:
			house_copy["address"] = "%s, %s" % [addr_str, _current_neighborhood_label]

	var targets: Array = OsmService.build_nearby_targets_for_house(
		house_copy,
		_current_buildings,
		_current_pois,
		_current_neighborhood_label
	)
	_current_targets = targets
	var mods: Dictionary = OsmService.compute_neighborhood_modifiers(targets)

	GameState.selected_house = house_copy
	GameState.nearby_pois = targets.duplicate(true)
	GameState.neighborhood_modifiers = mods.duplicate(true)
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

func _set_ring_filter(ring_id: int, pan_map: bool) -> void:
	_active_ring_filter = clampi(ring_id, 0, 3)
	_refresh_ring_filter_styles()
	_slippy_map.set_ring_filter(_active_ring_filter, pan_map)
	_populate_poi_list(_current_targets)
	if is_instance_valid(_poi_scroll):
		_poi_scroll.scroll_vertical = 0

func _refresh_sidebar_inspector(house: Dictionary, targets: Array) -> void:
	var short_addr: String = str(house.get("short_address", str(house.get("address", "Selected House"))))
	var osm_id_val: int = int(house.get("osm_id", 0))
	var lat_val: float = float(house.get("lat", 0.0))
	var lon_val: float = float(house.get("lon", 0.0))
	var area_val: float = float(house.get("area_sqm", 120.0))
	var rooms_val: int = int(house.get("estimated_rooms", 5))
	var btype_val: String = OsmService.format_building_type(str(house.get("building_type", "house")))

	_lbl_house_osm_id.text = "OSM #%d" % osm_id_val
	_lbl_house_address.text = short_addr
	_lbl_house_neighborhood.text = _current_neighborhood_label

	var ns_char: String = "N" if lat_val >= 0.0 else "S"
	var ew_char: String = "E" if lon_val >= 0.0 else "W"
	_lbl_house_coords.text = "Coords: %.4f° %s, %.4f° %s" % [absf(lat_val), ns_char, absf(lon_val), ew_char]
	_lbl_house_area.text = "Footprint: %.1f m² (%s)" % [area_val, btype_val]
	_lbl_house_rooms.text = "Interior: ~%d Rooms  •  ★ Central Hatch" % rooms_val

	var mods: Dictionary = GameState.neighborhood_modifiers
	if mods.is_empty():
		mods = OsmService.compute_neighborhood_modifiers(targets)
	var arch: String = str(mods.get("archetype", "Mixed Residential District")).to_upper()
	var raider_delta: int = int(round(float(mods.get("early_raider_mod", 0.0)) * 100.0))
	var raider_str: String = ("Raiders %+d%%" % raider_delta) if raider_delta != 0 else "Raiders Normal"
	var veh_rating: float = float(mods.get("vehicle_escape_rating", 1.0))
	var veh_str: String = "Auto/Fuel: High" if veh_rating >= 1.12 else ("Auto/Fuel: Std" if veh_rating >= 0.92 else "Auto/Fuel: Far")

	_lbl_impact_title.text = "◆ %s  •  %s  •  %s" % [arch, raider_str, veh_str]
	_lbl_impact_body.text = str(mods.get("headline", "Real-world neighborhood landmarks shape expedition rations, medical cures, and vehicle escape parts."))

	var bullets_v: Variant = mods.get("summary_bullets", [])
	if typeof(bullets_v) == TYPE_ARRAY:
		var bullets_arr: Array = bullets_v
		var tip_lines := PackedStringArray(["NEIGHBORHOOD GAMEPLAY IMPACT (" + arch + "):"])
		for b_line in bullets_arr:
			tip_lines.append("• " + str(b_line))
		_impact_panel.tooltip_text = "\n".join(tip_lines)

	_blueprint_canvas.queue_redraw()
	_populate_poi_list(targets)

	var r1_c: int = 0
	var r23_c: int = 0
	for t_v in targets:
		var td: Dictionary = t_v
		if int(td.get("ring", 1)) == 1:
			r1_c += 1
		else:
			r23_c += 1

	_lbl_bottom_summary.text = "★ %s (%s) • %d Near (<0.5km) + %d District/Deep (0.5-9km) Targets" % [
		short_addr,
		str(mods.get("archetype", "District")),
		r1_c,
		r23_c
	]

func _populate_poi_list(targets: Array) -> void:
	for child in _poi_list_vbox.get_children():
		child.queue_free()

	var counts: Dictionary = {
		"doctor": 0,
		"pharmacy": 0,
		"grocery": 0,
		"fuel_auto": 0,
		"hardware": 0,
		"civic": 0,
		"church": 0,
		"school": 0,
		"neighbor_house": 0
	}
	var ring_counts: Dictionary = {1: 0, 2: 0, 3: 0}
	var filtered: Array = []

	for t_v in targets:
		var t: Dictionary = t_v
		var c: String = str(t.get("category", ""))
		var r_id: int = int(t.get("ring", 1))
		if counts.has(c):
			counts[c] = int(counts[c]) + 1
		if ring_counts.has(r_id):
			ring_counts[r_id] = int(ring_counts[r_id]) + 1
		if _active_ring_filter == 0 or r_id == _active_ring_filter:
			filtered.append(t)

	if _active_ring_filter == 0:
		_lbl_poi_header.text = "NEARBY SCAVENGE PLACES (%d MAPPED • R1:%d R2:%d R3:%d)" % [
			targets.size(),
			int(ring_counts[1]),
			int(ring_counts[2]),
			int(ring_counts[3])
		]
	else:
		var ring_names: Dictionary = {
			1: "RING 1 NEAR <0.5KM",
			2: "RING 2 DISTRICT 0.5-3.5KM",
			3: "RING 3 DEEP 3.5KM+"
		}
		_lbl_poi_header.text = "%s (%d OF %d PLACES)" % [
			str(ring_names.get(_active_ring_filter, "FILTERED")),
			filtered.size(),
			targets.size()
		]

	_lbl_poi_summary.text = "▣ %d Mkt • + %d Doc/%d Rx • ◆ %d Gas/%d HW • ★ %d Civ • ┼ %d Chr/%d Sch • ⌂ %d Nbr" % [
		int(counts["grocery"]),
		int(counts["doctor"]),
		int(counts["pharmacy"]),
		int(counts["fuel_auto"]),
		int(counts["hardware"]),
		int(counts["civic"]),
		int(counts["church"]),
		int(counts["school"]),
		int(counts["neighbor_house"])
	]

	if filtered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No landmarks in this distance ring — select another Ring filter above."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override("font_color", Color("#564d3f"))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		_poi_list_vbox.add_child(empty_lbl)
		return

	for idx in range(filtered.size()):
		var t: Dictionary = filtered[idx]
		var row: PanelContainer = _create_poi_row_card(t)
		_poi_list_vbox.add_child(row)

func _create_poi_row_card(poi: Dictionary) -> PanelContainer:
	var cat: String = str(poi.get("category", "grocery"))
	var poi_id: int = int(poi.get("osm_id", -1))
	var pname: String = str(poi.get("name", "Landmark"))
	var dist_m: int = int(poi.get("distance_m", 100))
	var ring_id: int = int(poi.get("ring", OsmService.compute_ring_for_distance(dist_m)))
	var bearing: String = str(poi.get("bearing_dir", "N"))
	var days: int = int(poi.get("travel_days", 1))
	var impact_str: String = str(poi.get("gameplay_impact", OsmService.get_gameplay_impact_for_category(cat, ring_id)))
	var loot_v: Variant = poi.get("loot_profile", [])
	var loot_arr: Array = loot_v if typeof(loot_v) == TYPE_ARRAY else []

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(376.0, 46.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_sb: StyleBoxFlat = _make_panel_style(COL_CARD_AGED, Color(0.18, 0.16, 0.13, 0.55), 1, 4)
	var hover_sb: StyleBoxFlat = _make_panel_style(Color("#f7e7b4"), COL_ATOMIC_ORANGE, 2, 4)
	card.add_theme_stylebox_override("panel", normal_sb)

	var loot_pretty: PackedStringArray = PackedStringArray()
	for i in range(mini(3, loot_arr.size())):
		loot_pretty.append(str(loot_arr[i]).replace("_", " ").capitalize())
	var dist_pretty: String = ("%.1fkm" % (float(dist_m) / 1000.0)) if dist_m >= 1000 else ("%dm" % dist_m)

	card.tooltip_text = "%s (%s)\nDistance: %s %s  •  Ring %d (%d-day expedition)\nKey Loot: %s\nGameplay Impact: %s" % [
		pname,
		OsmService.get_category_label(cat),
		dist_pretty,
		bearing,
		ring_id,
		days,
		", ".join(loot_pretty),
		impact_str
	]

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 7)
	card.add_child(hbox)

	var icon_ctrl := Control.new()
	icon_ctrl.custom_minimum_size = Vector2(28.0, 38.0)
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var captured_cat: String = cat
	icon_ctrl.draw.connect(func() -> void:
		OsmSlippyMap.draw_poi_badge(icon_ctrl, Vector2(14.0, 19.0), 10.2 if captured_cat != "neighbor_house" else 8.0, captured_cat, false)
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

	var sub_lbl := Label.new()
	sub_lbl.text = "%s • %s" % [OsmService.get_category_label(cat), ", ".join(loot_pretty)]
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_lbl.add_theme_color_override("font_color", Color("#524839"))
	sub_lbl.add_theme_font_size_override("font_size", 10)
	text_vbox.add_child(sub_lbl)

	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(82.0, 38.0)
	right_vbox.add_theme_constant_override("separation", 1)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right_vbox)

	var ring_badge := Label.new()
	ring_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var ring_col: Color = Color("#245e2e") if ring_id == 1 else (Color("#8f5010") if ring_id == 2 else Color("#a82f14"))
	ring_badge.text = "[R%d · %dd]" % [ring_id, days]
	ring_badge.add_theme_color_override("font_color", ring_col)
	ring_badge.add_theme_font_size_override("font_size", 10)
	right_vbox.add_child(ring_badge)

	var dist_lbl := Label.new()
	dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dist_lbl.text = "%s %s" % [dist_pretty, bearing]
	dist_lbl.add_theme_color_override("font_color", Color("#3b3429"))
	dist_lbl.add_theme_font_size_override("font_size", 10)
	right_vbox.add_child(dist_lbl)

	var captured_id: int = poi_id
	var captured_lat: float = float(poi.get("lat", 0.0))
	var captured_lon: float = float(poi.get("lon", 0.0))
	var captured_dist: int = dist_m
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
				_slippy_map.focus_poi_with_house(captured_lat, captured_lon, captured_dist)
	)

	return card

func _on_confirm_house_pressed() -> void:
	_play_sfx("button_click")
	_osm_service.cancel_requests()
	if GameState.selected_house.is_empty() and not _current_buildings.is_empty():
		_select_house(_current_buildings[0], false)
	GameState.osm_house_selected.emit(GameState.selected_house)
	GameState.request_screen(GameState.SCREEN_NUKE)

# --- Automated Demo Mode Choreography (~4.5s) ---

func _init_demo_mode() -> void:
	_demo_elapsed = 0.0
	_demo_stage = 0
	_demo_finished = false

	_demo_banner = Control.new()
	_demo_banner.position = Vector2(24.0, 132.0)
	_demo_banner.size = Vector2(812.0, 34.0)
	_demo_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_banner.draw.connect(func() -> void:
		var f: Font = get_theme_default_font()
		if f == null:
			f = ThemeDB.fallback_font
		var r := Rect2(Vector2.ZERO, _demo_banner.size)
		_demo_banner.draw_rect(r, COL_INK, true)
		_demo_banner.draw_rect(r, COL_HAZARD_YELLOW, false, 2.2)
		_demo_banner.draw_rect(Rect2(4.0, 4.0, 10.0, r.size.y - 8.0), COL_ATOMIC_ORANGE, true)
		_demo_banner.draw_string(
			f,
			Vector2(20.0, 22.0),
			"DEMO: MULTI-RING OSM RECON — GROCERY STORES, DOCTOR'S OFFICES & GAS STATIONS (0-9KM)",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			COL_HAZARD_YELLOW
		)
	)
	_demo_banner.visible = not GameState.promo_video_mode
	add_child(_demo_banner)

	_search_input.text = "6217 Walborough Court, Wyndham, VA"
	_load_preset_neighborhood("wyndham", false)
	_demo_house = GameState.selected_house.duplicate(true)
	if not _demo_house.is_empty():
		_slippy_map.set_hovered_house_by_id(int(_demo_house.get("osm_id", -1)))

var _demo_house: Dictionary = {}

func _demo_find_poi_id(category: String, ring: int) -> int:
	var best_id: int = -1
	var best_d: float = INF
	for p_v in _current_pois:
		if typeof(p_v) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_v
		if str(p.get("category", "")) != category:
			continue
		if ring > 0 and int(p.get("ring", 0)) != ring:
			continue
		var d: float = float(p.get("distance_m", 0.0))
		if d < best_d:
			best_d = d
			best_id = int(p.get("osm_id", -1))
	return best_id

func _tick_demo_mode(delta: float) -> void:
	_demo_elapsed += delta

	if _demo_stage == 0 and _demo_elapsed >= 1.30:
		_demo_stage = 1
		_play_sfx("tick")
		_set_ring_filter(1, true)
		var doc_id: int = _demo_find_poi_id("doctor", 0)
		if doc_id < 0:
			doc_id = _demo_find_poi_id("neighbor_house", 1)
		_slippy_map.set_highlighted_poi_id(doc_id)

	elif _demo_stage == 1 and _demo_elapsed >= 2.65:
		_demo_stage = 2
		_play_sfx("button_click")
		_set_ring_filter(2, true)
		_slippy_map.set_highlighted_poi_id(_demo_find_poi_id("grocery", 2))

	elif _demo_stage == 2 and _demo_elapsed >= 4.00:
		_demo_stage = 3
		_play_sfx("button_click")
		_set_ring_filter(3, true)
		var r3: int = _demo_find_poi_id("fuel_auto", 3)
		if r3 < 0:
			r3 = _demo_find_poi_id("grocery", 3)
		_slippy_map.set_highlighted_poi_id(r3)

	elif _demo_stage == 3 and _demo_elapsed >= 5.40:
		_demo_stage = 4
		_set_ring_filter(0, true)
		_slippy_map.set_highlighted_poi_id(-1)

	elif _demo_elapsed >= 6.20 and not _demo_finished:
		_demo_finished = true
		_play_sfx("button_click")
		if not _demo_house.is_empty() and GameState.selected_house.is_empty():
			_select_house(_demo_house, true)
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

func _refresh_ring_filter_styles() -> void:
	for rid_k in _ring_filter_buttons.keys():
		var rid: int = int(rid_k)
		var btn: Button = _ring_filter_buttons[rid]
		var is_active: bool = (rid == _active_ring_filter)
		var bg: Color = COL_HAZARD_YELLOW if is_active else Color("#282e29")
		var fg: Color = COL_INK if is_active else COL_CARD_PARCHMENT
		var bdr: Color = COL_INK if is_active else Color("#6e756a")
		var normal := _make_pill_style(bg, bdr, 1 if not is_active else 2, 4)
		var hover := _make_pill_style(bg.lightened(0.14), COL_HAZARD_YELLOW, 2, 4)
		var pressed_sb := _make_pill_style(bg.darkened(0.12), COL_CARD_PARCHMENT, 2, 4)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed_sb)
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_color_override("font_hover_color", COL_INK if is_active else Color("#fff4cf"))
		btn.add_theme_color_override("font_pressed_color", fg)
		btn.add_theme_font_size_override("font_size", 10)

func _make_pill_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb

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
