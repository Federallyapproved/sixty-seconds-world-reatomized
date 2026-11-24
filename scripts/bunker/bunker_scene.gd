class_name BunkerScene
extends Control

## Main Bunker Survival Controller, Top Civil Defense HUD, 4-Tab Flipbook Survival Notebook,
## Real-World OpenStreetMap Expedition Planner/Tracker, and 4-Day Automated Demo Showcase.

signal demo_sequence_completed()

static var demo_completed_flag: bool = false

const TAB_LOG: int = 0
const TAB_RATIONS: int = 1
const TAB_DILEMMA: int = 2
const TAB_EXPEDITION: int = 3

const COL_PARCHMENT := Color("#efe3c8")
const COL_PARCHMENT_DARK := Color("#dfd0ae")
const COL_CARD_BG := Color("#e5d6b5")
const COL_INK := Color("#1d1a16")
const COL_INK_MUTED := Color("#544c3f")
const COL_HAZARD := Color("#f2b82e")
const COL_ORANGE := Color("#d94c2a")
const COL_STAMP_RED := Color("#b8321e")
const COL_GREEN := Color("#4f8f32")
const COL_WATER := Color("#2c76a8")
const COL_SLATE := Color("#232824")

const EXPEDITION_GEAR_SLOTS: Array[String] = [
	"gas_mask", "rifle", "axe", "flashlight", "map", "suitcase"
]
const MAX_DAILY_RATION_QUARTERS: int = 2

var _backdrop: BunkerBackdrop = null
var _hud_bar: _TopHudBar = null
var _toggle_notebook_btn: Button = null
var _minimized_dock: PanelContainer = null
var _minimized_end_btn: Button = null

var _notebook_root: Control = null
var _notebook_canvas: _NotebookBackdrop = null
var _tab_buttons: Array[Button] = []
var _tab_containers: Array[Control] = []
var _prev_page_btn: Button = null
var _next_page_btn: Button = null
var _page_indicator_lbl: Label = null
var _end_day_btn: Button = null

var _curtain_overlay: _DayCurtainOverlay = null

# Runtime Notebook & Daily Turn State
var _notebook_open: bool = true
var _current_tab: int = TAB_LOG
var _sanity_hundred_scale: bool = false

# Tab 2: Planned Rations & Medkit for current day
var _planned_rations: Dictionary = {} # member_id -> {"soup_q": int, "water_q": int}
var _planned_medkit_member_id: String = ""

# Tab 3: Daily Dilemma State
var _current_event: Dictionary = {}
var _selected_event_choice_id: String = ""
var _has_unresolved_dilemma: bool = false

# Tab 4: Real-World OSM Expedition State
var _available_targets: Array = []
var _selected_poi_index: int = 0
var _selected_explorer_id: String = ""
var _selected_gear_ids: Array[String] = []
var _expedition_scheduled: bool = false
var _radar_map_widget: ShelterMapView = null

# Pass 2: cinematic day flow, garage and big map
var _cinematic: ShelterCinematic = null
var _garage: GarageView = null
var _map_overlay: Control = null
var _big_map: ShelterMapView = null
var _resolved_outcome: Dictionary = {}
var _day_queue: Array = []
var _dilemma_actor: Dictionary = {}

# Curtain Transition State
var _in_day_transition: bool = false
var _curtain_timer: float = 0.0
var _curtain_duration: float = 0.85
var _curtain_midpoint_fired: bool = false

# Demo Mode State
var _demo_running: bool = false
var _demo_finished: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280.0, 720.0)

	SoundManager.set_ambience("bunker")
	_initialize_bunker_run_if_needed()
	_detect_sanity_scale()

	# 1. Full-screen Illustrated Bunker Backdrop
	_backdrop = BunkerBackdrop.new()
	_backdrop.name = "BunkerBackdrop"
	add_child(_backdrop)

	# 2. Top Civil Defense HUD Bar
	_build_top_hud()

	# 3. Right/Center Flipbook Survival Notebook (740x560)
	_build_survival_notebook()

	# 4. Minimized Floating Quick-Action Pill (shown when Notebook is minimized)
	_build_minimized_dock()

	# 5. Full-Screen Black "DAY <N>" Curtain Overlay
	_curtain_overlay = _DayCurtainOverlay.new()
	_curtain_overlay.name = "DayCurtainOverlay"
	_curtain_overlay.visible = false
	add_child(_curtain_overlay)

	# 6. Garage, big neighbourhood map and the cinematic stage (top-most)
	_garage = GarageView.new()
	_garage.name = "GarageView"
	add_child(_garage)
	_garage.install_requested.connect(_on_install_requested)
	_garage.drive_requested.connect(_on_drive_requested)
	_build_map_overlay()
	_cinematic = ShelterCinematic.new()
	_cinematic.name = "ShelterCinematic"
	add_child(_cinematic)
	_cinematic.choice_made.connect(_on_dilemma_choice)
	_cinematic.sequence_finished.connect(_on_cinematic_finished)

	if not GameState.inventory_changed.is_connected(_on_external_state_changed):
		GameState.inventory_changed.connect(_on_external_state_changed)
	if not GameState.family_changed.is_connected(_on_external_state_changed):
		GameState.family_changed.connect(_on_external_state_changed)

	_prepare_new_day_turn(true)

	if GameState.demo_mode:
		_set_notebook_open(false)
		_start_demo_showcase()
	else:
		_set_notebook_open(true)

func set_active_tab(tab_index: int) -> void:
	_switch_tab(clampi(tab_index, 0, 3), false)

func set_notebook_visible(open_flag: bool) -> void:
	_set_notebook_open(open_flag)

func _initialize_bunker_run_if_needed() -> void:
	var cli_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var direct_cli_bunker: bool = cli_args.has("--start-screen=bunker")

	# Ensure real-world OSM nearby_pois are ready
	if GameState.nearby_pois.is_empty():
		_populate_default_osm_targets_if_empty()

	# If launched directly via --start-screen=bunker (or demo without scavenge), ensure family/supplies exist
	if direct_cli_bunker and GameState.get_all_living_members().is_empty():
		_seed_direct_bunker_start()

	if GameState.demo_mode and GameState.day <= 1:
		_ensure_demo_bunker_readiness()

	if GameState.day <= 1:
		BunkerSim.start_bunker_run()

	if GameState.daily_log_entries.is_empty():
		_append_initial_orientation_log()

func _populate_default_osm_targets_if_empty() -> void:
	var preset_path: String = "res://data/osm_presets/seattle_capitol_hill.json"
	if FileAccess.file_exists(preset_path):
		var f: FileAccess = FileAccess.open(preset_path, FileAccess.READ)
		if f != null:
			var raw_txt: String = f.get_as_text()
			var parsed_json: Variant = JSON.parse_string(raw_txt)
			if parsed_json is Dictionary:
				var h_lat: float = float(GameState.selected_house.get("lat", 47.6242))
				var h_lon: float = float(GameState.selected_house.get("lon", -122.3195))
				var map_parsed: Dictionary = OsmService.parse_osm_json(parsed_json as Dictionary, h_lat, h_lon)
				var bldgs: Array = map_parsed.get("buildings", [])
				var pois: Array = map_parsed.get("pois", [])
				var cfg: Dictionary = OsmService.PRESET_CONFIGS.get("seattle", {})
				map_parsed["place_names"] = (cfg.get("place_names", {}) as Dictionary).duplicate()
				map_parsed["landmarks"] = (cfg.get("landmarks", []) as Array).duplicate(true)
				map_parsed["source"] = "preset:seattle"
				if not bldgs.is_empty() or not pois.is_empty():
					GameState.nearby_pois = OsmService.build_nearby_targets_for_house(GameState.selected_house, bldgs, pois, map_parsed.get("roads", []))
				if GameState.map_roads.is_empty():
					HouseSelectScreen.store_map_context(GameState.selected_house, bldgs, map_parsed, [])
	if GameState.nearby_pois.is_empty():
		var targets: Array = ExpeditionEngine.get_available_targets()
		if not targets.is_empty():
			GameState.nearby_pois = targets

func _seed_direct_bunker_start() -> void:
	for m_v in GameState.family_members:
		if m_v is Dictionary:
			var md: Dictionary = m_v
			md["in_bunker"] = true
			md["alive"] = true
	if GameState.soup_quarters <= 0:
		GameState.soup_quarters = 18
	if GameState.water_quarters <= 0:
		GameState.water_quarters = 20
	if GameState.medkit_count <= 0:
		GameState.medkit_count = 2
	if GameState.bug_spray_count <= 0:
		GameState.bug_spray_count = 1
	if GameState.ammo_count <= 0:
		GameState.ammo_count = 4
	GameState.padlock_active = true
	for gid in ["gas_mask", "suitcase", "radio", "map", "flashlight", "axe", "cards"]:
		if GameState.bunker_items.has(gid):
			GameState.bunker_items[gid]["owned"] = true
			GameState.bunker_items[gid]["broken"] = false
			GameState.bunker_items[gid]["count"] = 1
	GameState.has_cat_sharikov = true

func _ensure_demo_bunker_readiness() -> void:
	# Guarantee at least 2 living members in bunker + working gas_mask & suitcase for demo showcase
	var any_in_bunker: bool = false
	for m_v in GameState.family_members:
		if m_v is Dictionary:
			var md: Dictionary = m_v
			if bool(md.get("in_bunker", false)) and bool(md.get("alive", true)):
				any_in_bunker = true
	if not any_in_bunker:
		for m_v in GameState.family_members:
			if m_v is Dictionary:
				var md2: Dictionary = m_v
				md2["in_bunker"] = true
				md2["alive"] = true
	if GameState.soup_quarters < 12:
		GameState.soup_quarters = 16
	if GameState.water_quarters < 12:
		GameState.water_quarters = 20
	if GameState.medkit_count < 1:
		GameState.medkit_count = 2
	for req_id in ["gas_mask", "suitcase", "radio", "map"]:
		if GameState.bunker_items.has(req_id):
			GameState.bunker_items[req_id]["owned"] = true
			GameState.bunker_items[req_id]["broken"] = false
			GameState.bunker_items[req_id]["count"] = maxi(1, int(GameState.bunker_items[req_id].get("count", 1)))

func _append_initial_orientation_log() -> void:
	var h_name: String = LocationText.home_ref()
	var n_target: String = str(GameState.nuke_config.get("target_name", "ground zero"))
	var dist_km: float = float(GameState.nuke_config.get("distance_km", 4.2))
	var survivors: Array[String] = []
	for m_v in GameState.get_all_living_members():
		if m_v is Dictionary:
			survivors.append(str((m_v as Dictionary).get("name", "Survivor")))
	var fam_line: String = ", ".join(survivors) if not survivors.is_empty() else "Nobody"
	var lines: Array[String] = [
		"The blast hatch slammed shut beneath %s just as the shockwave from %s (%.1f km away) rattled the concrete ceiling." % [h_name, n_target, dist_km],
		"Survivors accounted for inside the shelter: %s." % fam_line,
		"Stockpile inventory: %s cans of Tomato Soup and %s bottles of Drinking Water." % [
			GameState.format_quarters_as_cans(GameState.soup_quarters),
			GameState.format_quarters_as_cans(GameState.water_quarters)
		],
		"Check RATIONS & CARE to feed the family, or open the REAL-WORLD OSM EXPEDITION MAP to chart a scavenging run!"
	]
	GameState.daily_log_entries.append({
		"day": GameState.day,
		"title": "DAY %d — BLAST DOORS SEALED" % GameState.day,
		"lines": lines
	})

func _detect_sanity_scale() -> void:
	for m_v in GameState.family_members:
		if m_v is Dictionary:
			if int((m_v as Dictionary).get("sanity", 0)) > 10:
				_sanity_hundred_scale = true
				return

func _on_external_state_changed() -> void:
	if is_instance_valid(_hud_bar):
		_hud_bar.queue_redraw()
	if is_instance_valid(_backdrop):
		_backdrop.refresh_bunker()

func _unhandled_input(event: InputEvent) -> void:
	if GameState.demo_mode or _in_day_transition:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_TAB or ke.keycode == KEY_N:
				_set_notebook_open(not _notebook_open)
				SoundManager.play_sfx("page_turn")
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _in_day_transition:
		_curtain_timer += delta
		var progress: float = clampf(_curtain_timer / _curtain_duration, 0.0, 1.0)
		_curtain_overlay.set_progress(progress)
		if progress >= 0.50 and not _curtain_midpoint_fired:
			_curtain_midpoint_fired = true
			_on_curtain_midpoint()
		if progress >= 1.0:
			_in_day_transition = false
			_curtain_overlay.visible = false

# ---------------------------------------------------------------------------
# TOP HUD BAR (1280x52)
# ---------------------------------------------------------------------------
func _build_top_hud() -> void:
	_hud_bar = _TopHudBar.new()
	_hud_bar.name = "TopHudBar"
	_hud_bar.position = Vector2.ZERO
	_hud_bar.size = Vector2(1280.0, 52.0)
	add_child(_hud_bar)

	_toggle_notebook_btn = Button.new()
	_toggle_notebook_btn.name = "ToggleNotebookButton"
	_toggle_notebook_btn.position = Vector2(986.0, 8.0)
	_toggle_notebook_btn.size = Vector2(282.0, 36.0)
	_toggle_notebook_btn.add_theme_font_size_override("font_size", 13)
	_style_conelrad_button(_toggle_notebook_btn, Color("#2c342b"), COL_HAZARD, COL_PARCHMENT)
	_toggle_notebook_btn.pressed.connect(func() -> void:
		if _in_day_transition:
			return
		SoundManager.play_sfx("page_turn")
		_set_notebook_open(not _notebook_open)
	)
	_hud_bar.add_child(_toggle_notebook_btn)

func _build_minimized_dock() -> void:
	_minimized_dock = PanelContainer.new()
	_minimized_dock.name = "MinimizedDock"
	_minimized_dock.position = Vector2(822.0, 658.0)
	_minimized_dock.size = Vector2(442.0, 50.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.11, 0.94)
	sb.border_color = COL_HAZARD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	_minimized_dock.add_theme_stylebox_override("panel", sb)
	add_child(_minimized_dock)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_minimized_dock.add_child(hbox)

	var open_btn := Button.new()
	open_btn.text = "OPEN SURVIVAL NOTEBOOK"
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_btn.add_theme_font_size_override("font_size", 13)
	_style_conelrad_button(open_btn, Color("#333d31"), COL_HAZARD, COL_HAZARD)
	open_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("page_turn")
		_set_notebook_open(true)
	)
	hbox.add_child(open_btn)

	_minimized_end_btn = Button.new()
	_minimized_end_btn.text = "END DAY 1"
	_minimized_end_btn.custom_minimum_size = Vector2(156.0, 34.0)
	_minimized_end_btn.add_theme_font_size_override("font_size", 13)
	_style_conelrad_button(_minimized_end_btn, COL_STAMP_RED, COL_INK, COL_PARCHMENT)
	_minimized_end_btn.pressed.connect(_on_end_day_pressed)
	hbox.add_child(_minimized_end_btn)

func _set_notebook_open(open_flag: bool) -> void:
	_notebook_open = open_flag
	if is_instance_valid(_notebook_root):
		_notebook_root.visible = open_flag
	if is_instance_valid(_minimized_dock):
		_minimized_dock.visible = not open_flag
	if is_instance_valid(_backdrop):
		_backdrop.set_notebook_occluding(open_flag)
	if is_instance_valid(_toggle_notebook_btn):
		_toggle_notebook_btn.text = "[ MINIMIZE SURVIVAL NOTEBOOK ]" if open_flag else "[ OPEN SURVIVAL NOTEBOOK ]"

# ---------------------------------------------------------------------------
# SURVIVAL NOTEBOOK FLIPBOOK PANEL (740x560 at (516, 86))
# ---------------------------------------------------------------------------
func _build_survival_notebook() -> void:
	_notebook_root = Control.new()
	_notebook_root.name = "SurvivalNotebook"
	_notebook_root.position = Vector2(516.0, 86.0)
	_notebook_root.size = Vector2(740.0, 560.0)
	add_child(_notebook_root)

	# 4 Protruding Folder Index Tabs across top edge (y = -30..2)
	var tab_defs := [
		{"title": "1. DAILY LOG", "x": 30.0, "w": 162.0},
		{"title": "2. RATIONS & CARE", "x": 198.0, "w": 176.0},
		{"title": "3. DILEMMA", "x": 380.0, "w": 166.0},
		{"title": "4. OSM EXPEDITION", "x": 552.0, "w": 178.0}
	]
	_tab_buttons.clear()
	for i in range(tab_defs.size()):
		var td: Dictionary = tab_defs[i]
		var tb := _NotebookTabButton.new()
		tb.tab_title = str(td["title"])
		tb.position = Vector2(float(td["x"]), -30.0)
		tb.size = Vector2(float(td["w"]), 32.0)
		var captured_idx: int = i
		tb.pressed.connect(func() -> void:
			_switch_tab(captured_idx, true)
		)
		_notebook_root.add_child(tb)
		_tab_buttons.append(tb)

	# Illustrated Parchment + Spiral Binding Canvas
	_notebook_canvas = _NotebookBackdrop.new()
	_notebook_canvas.position = Vector2.ZERO
	_notebook_canvas.size = Vector2(740.0, 560.0)
	_notebook_root.add_child(_notebook_canvas)

	# 4 Non-Overlapping Inner Tab Containers (Rect2(38, 14, 686, 482))
	_tab_containers.clear()
	for i in range(4):
		var page := Control.new()
		page.name = "NotebookTab_%d" % i
		page.position = Vector2(38.0, 14.0)
		page.size = Vector2(686.0, 482.0)
		page.clip_contents = true
		page.visible = (i == 0)
		_notebook_root.add_child(page)
		_tab_containers.append(page)

	# Bottom Notebook Navigation & Red-Stamp "END DAY" Bar (Rect2(38, 504, 686, 44))
	_prev_page_btn = Button.new()
	_prev_page_btn.text = "GARAGE & CAR"
	_prev_page_btn.position = Vector2(38.0, 506.0)
	_prev_page_btn.size = Vector2(124.0, 38.0)
	_prev_page_btn.add_theme_font_size_override("font_size", 13)
	_style_notebook_ink_button(_prev_page_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK)
	_prev_page_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("page_turn")
		_open_garage()
	)
	_notebook_root.add_child(_prev_page_btn)

	_next_page_btn = Button.new()
	_next_page_btn.text = "BIG MAP"
	_next_page_btn.position = Vector2(168.0, 506.0)
	_next_page_btn.size = Vector2(124.0, 38.0)
	_next_page_btn.add_theme_font_size_override("font_size", 13)
	_style_notebook_ink_button(_next_page_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK)
	_next_page_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("page_turn")
		_open_map_overlay()
	)
	_notebook_root.add_child(_next_page_btn)

	_page_indicator_lbl = _make_ink_label("Page 1 / 4", 13, COL_INK_MUTED)
	_page_indicator_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_indicator_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_indicator_lbl.position = Vector2(296.0, 506.0)
	_page_indicator_lbl.size = Vector2(104.0, 38.0)
	_notebook_root.add_child(_page_indicator_lbl)

	_end_day_btn = Button.new()
	_end_day_btn.name = "EndDayButton"
	_end_day_btn.text = "[ END DAY 1 — LIGHTS OUT! ]"
	_end_day_btn.position = Vector2(406.0, 504.0)
	_end_day_btn.size = Vector2(318.0, 42.0)
	_end_day_btn.add_theme_font_size_override("font_size", 14)
	_style_conelrad_button(_end_day_btn, COL_STAMP_RED, COL_INK, Color("#fff3db"))
	_end_day_btn.pressed.connect(_on_end_day_pressed)
	_notebook_root.add_child(_end_day_btn)

func _switch_tab(new_tab: int, play_sound: bool) -> void:
	_current_tab = clampi(new_tab, 0, 3)
	if play_sound:
		SoundManager.play_sfx("page_turn")
	for i in range(_tab_containers.size()):
		_tab_containers[i].visible = (i == _current_tab)
	_refresh_tab_headers_and_footer()
	match _current_tab:
		TAB_LOG:
			_rebuild_tab_daily_log()
		TAB_RATIONS:
			_rebuild_tab_rations()
		TAB_DILEMMA:
			_rebuild_tab_dilemma()
		TAB_EXPEDITION:
			_rebuild_tab_expedition()

func _refresh_tab_headers_and_footer() -> void:
	for i in range(_tab_buttons.size()):
		var tb: _NotebookTabButton = _tab_buttons[i] as _NotebookTabButton
		tb.is_active_tab = (i == _current_tab)
		if i == TAB_DILEMMA:
			tb.badge_text = "!" if (_has_unresolved_dilemma and GameState.day >= 1 and not GameState.get_living_bunker_members().is_empty()) else ""
			tb.badge_color = COL_ORANGE
		elif i == TAB_EXPEDITION:
			if not GameState.active_expedition.is_empty():
				tb.badge_text = "OUT"
				tb.badge_color = COL_WATER
			elif _expedition_scheduled:
				tb.badge_text = "SET"
				tb.badge_color = COL_GREEN
			else:
				tb.badge_text = ""
		tb.queue_redraw()

	if is_instance_valid(_page_indicator_lbl):
		_page_indicator_lbl.text = "Tab %d / 4" % (_current_tab + 1)
	if is_instance_valid(_end_day_btn):
		_end_day_btn.text = "[ END DAY %d — LIGHTS OUT! ]" % GameState.day
	if is_instance_valid(_minimized_end_btn):
		_minimized_end_btn.text = "END DAY %d" % GameState.day
	if is_instance_valid(_prev_page_btn):
		_prev_page_btn.disabled = false
	if is_instance_valid(_next_page_btn):
		_next_page_btn.disabled = false

# ---------------------------------------------------------------------------
# DAILY TURN INITIALIZATION & EVENT DRAW
# ---------------------------------------------------------------------------
func _prepare_new_day_turn(reset_tab_to_log: bool) -> void:
	_detect_sanity_scale()
	_planned_rations.clear()
	for m_v in GameState.get_living_bunker_members():
		if m_v is Dictionary:
			var mid: String = str((m_v as Dictionary).get("id", ""))
			_planned_rations[mid] = {"soup_q": 0, "water_q": 0}
	_planned_medkit_member_id = ""
	_expedition_scheduled = false
	_selected_gear_ids.clear()

	# Refresh available OSM targets & pick default explorer/target
	_available_targets = ExpeditionEngine.get_available_targets()
	if _selected_poi_index < 0 or _selected_poi_index >= _available_targets.size():
		_selected_poi_index = 0
	_ensure_valid_explorer_selected()

	# Draw Today's Dilemma on Day 1+ when at least one survivor is inside the shelter
	_current_event = {}
	_selected_event_choice_id = ""
	_has_unresolved_dilemma = false
	if GameState.day >= 1 and not GameState.get_living_bunker_members().is_empty():
		_current_event = EventDeck.draw_daily_event(GameState.day, GameState.rng)
		var opts: Array = _get_event_options(_current_event)
		if not opts.is_empty():
			# Every occupied day presents a real decision; nothing is chosen for the player.
			_has_unresolved_dilemma = true
			_selected_event_choice_id = ""
	_resolved_outcome = {}

	_rebuild_all_tabs()
	if reset_tab_to_log:
		_switch_tab(TAB_LOG, false)
	else:
		_refresh_tab_headers_and_footer()

	if is_instance_valid(_hud_bar):
		_hud_bar.queue_redraw()
	if is_instance_valid(_backdrop):
		_backdrop.refresh_bunker()
	call_deferred("_begin_day_sequence")

func _rebuild_all_tabs() -> void:
	_rebuild_tab_daily_log()
	_rebuild_tab_rations()
	_rebuild_tab_dilemma()
	_rebuild_tab_expedition()
	_refresh_tab_headers_and_footer()

# ---------------------------------------------------------------------------
# TAB 1: DAILY LOG (686x482)
# ---------------------------------------------------------------------------
func _rebuild_tab_daily_log() -> void:
	var root: Control = _tab_containers[TAB_LOG]
	_clear_children(root)

	# Header Banner
	var hdr := _make_ink_label("CIVIL DEFENSE SHELTER LOG — DAY %d" % GameState.day, 19, COL_INK)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 26.0)
	root.add_child(hdr)

	var house_label: String = LocationText.home_label()
	var sub_txt: String = "%s  |  Outside: %s  |  Temp: %.0f °C  |  Hull: %.0f%%" % [
		house_label, RadiationModel.format_rate(GameState.surface_radiation_sv * 1000.0), GameState.bunker_temp_c, GameState.bunker_structural_integrity
	]
	var sub := _make_ink_label(sub_txt, 12, COL_INK_MUTED)
	sub.position = Vector2(0.0, 24.0)
	sub.size = Vector2(686.0, 18.0)
	root.add_child(sub)

	# Family Quick Status Cards Row (y = 46..142)
	var fam_row := HBoxContainer.new()
	fam_row.position = Vector2(0.0, 46.0)
	fam_row.size = Vector2(686.0, 94.0)
	fam_row.add_theme_constant_override("separation", 8)
	root.add_child(fam_row)

	for m_v in GameState.family_members:
		if not (m_v is Dictionary):
			continue
		var member: Dictionary = m_v
		var card := _make_parchment_card(Vector2(165.0, 94.0), COL_CARD_BG, COL_INK)
		fam_row.add_child(card)

		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 6)
		card.add_child(row_box)

		var port := _MemberPortraitWidget.new()
		port.member_data = member
		port.custom_minimum_size = Vector2(48.0, 62.0)
		row_box.add_child(port)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.add_theme_constant_override("separation", 2)
		row_box.add_child(info_v)

		var m_name: String = str(member.get("name", "Survivor"))
		var n_lbl := _make_ink_label(m_name, 13, COL_INK)
		n_lbl.clip_text = true
		info_v.add_child(n_lbl)

		var role_age: String = "%s · %dy" % [str(member.get("role", "adult")).capitalize(), int(member.get("age", 30))]
		var r_lbl := _make_ink_label(role_age, 10, COL_INK_MUTED)
		info_v.add_child(r_lbl)

		var status_summary: Dictionary = _summarize_member_quick_badge(member)
		var pill := _make_status_pill(str(status_summary["text"]), status_summary["color"])
		info_v.add_child(pill)

	# Scrollable Journal Narrative (y = 148..480)
	var log_frame := _make_parchment_card(Vector2(686.0, 330.0), Color("#f5ebd4"), COL_INK)
	log_frame.position = Vector2(0.0, 148.0)
	log_frame.size = Vector2(686.0, 330.0)
	root.add_child(log_frame)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_frame.add_child(scroll)

	var entries_vbox := VBoxContainer.new()
	entries_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(entries_vbox)

	# Render newest day at top so today's events & expedition loot are immediately readable
	var total_entries: int = GameState.daily_log_entries.size()
	if total_entries == 0:
		var empty_lbl := _make_ink_label("Shelter journal opened. Awaiting Day 1 notes...", 14, COL_INK)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entries_vbox.add_child(empty_lbl)
	else:
		for idx in range(total_entries - 1, -1, -1):
			var raw_entry: Variant = GameState.daily_log_entries[idx]
			var formatted: Dictionary = _format_log_entry(raw_entry, idx + 1)
			var is_latest: bool = (idx == total_entries - 1)

			var day_hdr := _make_ink_label(
				str(formatted["header"]),
				14 if is_latest else 13,
				COL_STAMP_RED if is_latest else COL_INK_MUTED
			)
			entries_vbox.add_child(day_hdr)

			var body_lbl := _make_ink_label(str(formatted["body"]), 14 if is_latest else 13, COL_INK)
			body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body_lbl.custom_minimum_size = Vector2(648.0, 0.0)
			entries_vbox.add_child(body_lbl)

			if idx > 0:
				var sep := ColorRect.new()
				sep.custom_minimum_size = Vector2(648.0, 1.0)
				sep.color = Color(0.25, 0.21, 0.16, 0.28)
				entries_vbox.add_child(sep)

func _strip_md(text_val: String) -> String:
	return text_val.replace("**", "")

func _format_log_entry(raw_entry: Variant, fallback_day: int) -> Dictionary:
	if raw_entry is Dictionary:
		var d: Dictionary = raw_entry
		var d_num: int = int(d.get("day", fallback_day))
		var hdr: String = _strip_md(str(d.get("title", d.get("header", "=== DAY %d REPORT ===" % d_num))))
		var body_parts: Array[String] = []
		if d.has("lines") and d["lines"] is Array:
			for ln_v in d["lines"]:
				var s: String = _strip_md(str(ln_v)).strip_edges()
				if s != "":
					body_parts.append("• " + s)
		elif d.has("entries") and d["entries"] is Array:
			for ln_v2 in d["entries"]:
				var s2: String = _strip_md(str(ln_v2)).strip_edges()
				if s2 != "":
					body_parts.append("• " + s2)
		else:
			var single: String = _strip_md(str(d.get("text", d.get("body", d.get("summary", ""))))).strip_edges()
			if single != "":
				body_parts.append(single)
		return {
			"header": hdr,
			"body": "\n".join(body_parts) if not body_parts.is_empty() else "Quiet hours inside the bunker."
		}
	elif raw_entry is Array:
		var lines_arr: Array[String] = []
		for item_v in (raw_entry as Array):
			var st: String = _strip_md(str(item_v)).strip_edges()
			if st != "":
				lines_arr.append("• " + st)
		return {
			"header": "=== DAY %d REPORT ===" % fallback_day,
			"body": "\n".join(lines_arr)
		}
	var full_str: String = _strip_md(str(raw_entry)).strip_edges()
	var split_lines: PackedStringArray = full_str.split("\n", false)
	if split_lines.size() >= 2:
		var first_ln: String = split_lines[0].strip_edges()
		if first_ln.begins_with("===") or first_ln.to_upper().begins_with("DAY "):
			var rest: Array[String] = []
			for li in range(1, split_lines.size()):
				var rl: String = split_lines[li].strip_edges()
				if rl != "":
					rest.append("• " + rl if not rl.begins_with("•") else rl)
			return {
				"header": first_ln,
				"body": "\n".join(rest)
			}
	return {
		"header": "=== DAY %d ENTRY ===" % fallback_day,
		"body": full_str
	}

# ---------------------------------------------------------------------------
# TAB 2: RATIONS & CARE (686x482)
# ---------------------------------------------------------------------------
func _rebuild_tab_rations() -> void:
	var root: Control = _tab_containers[TAB_RATIONS]
	_clear_children(root)

	var planned_soup: int = _get_total_planned_soup_q()
	var planned_water: int = _get_total_planned_water_q()
	var rem_soup: int = maxi(0, GameState.soup_quarters - planned_soup)
	var rem_water: int = maxi(0, GameState.water_quarters - planned_water)
	var rem_medkits: int = maxi(0, GameState.medkit_count - (1 if _planned_medkit_member_id != "" else 0))

	# Top Stockpile Reserve Strip (y = 0..54)
	var reserve_card := _make_parchment_card(Vector2(686.0, 54.0), COL_CARD_BG, COL_INK)
	reserve_card.position = Vector2.ZERO
	reserve_card.size = Vector2(686.0, 54.0)
	root.add_child(reserve_card)

	var res_hbox := HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 16)
	reserve_card.add_child(res_hbox)

	res_hbox.add_child(_make_supply_counter_widget("soup", "SOUP: %s cans" % GameState.format_quarters_as_cans(rem_soup), COL_ORANGE))
	res_hbox.add_child(_make_supply_counter_widget("water", "WATER: %s bottles" % GameState.format_quarters_as_cans(rem_water), COL_WATER))
	res_hbox.add_child(_make_supply_counter_widget("medkit", "MEDKITS: %d" % rem_medkits, COL_GREEN))

	# Living Bunker Member Ration Rows (y = 62..434)
	var rows_vbox := VBoxContainer.new()
	rows_vbox.position = Vector2(0.0, 62.0)
	rows_vbox.size = Vector2(686.0, 372.0)
	rows_vbox.add_theme_constant_override("separation", 6)
	root.add_child(rows_vbox)

	var living_in_bunker: Array = GameState.get_living_bunker_members()
	for m_v in living_in_bunker:
		if not (m_v is Dictionary):
			continue
		var member: Dictionary = m_v
		var mid: String = str(member.get("id", ""))
		if not _planned_rations.has(mid):
			_planned_rations[mid] = {"soup_q": 0, "water_q": 0}
		var plan_entry: Dictionary = _planned_rations[mid]
		var cur_sq: int = int(plan_entry.get("soup_q", 0))
		var cur_wq: int = int(plan_entry.get("water_q", 0))

		var row_card := _make_parchment_card(Vector2(686.0, 82.0), Color("#f6edd8"), COL_INK)
		row_card.custom_minimum_size = Vector2(686.0, 82.0)
		rows_vbox.add_child(row_card)

		var r_hbox := HBoxContainer.new()
		r_hbox.add_theme_constant_override("separation", 8)
		row_card.add_child(r_hbox)

		# Portrait
		var port := _MemberPortraitWidget.new()
		port.member_data = member
		port.custom_minimum_size = Vector2(52.0, 66.0)
		r_hbox.add_child(port)

		# Name, Age, Hunger & Thirst Status Pills
		var bio_v := VBoxContainer.new()
		bio_v.custom_minimum_size = Vector2(184.0, 66.0)
		bio_v.add_theme_constant_override("separation", 3)
		r_hbox.add_child(bio_v)

		var title_lbl := _make_ink_label("%s (%dy)" % [str(member.get("name", "Survivor")), int(member.get("age", 30))], 14, COL_INK)
		bio_v.add_child(title_lbl)

		var pills_h := HBoxContainer.new()
		pills_h.add_theme_constant_override("separation", 4)
		bio_v.add_child(pills_h)

		var h_info: Dictionary = _get_hunger_status(member)
		var t_info: Dictionary = _get_thirst_status(member)
		pills_h.add_child(_make_status_pill(str(h_info["text"]), h_info["color"]))
		pills_h.add_child(_make_status_pill(str(t_info["text"]), t_info["color"]))

		var extra_conds: Array[String] = []
		if int(member.get("sickness", 0)) > 0:
			extra_conds.append("Sick")
		if int(member.get("injury", 0)) > 0:
			extra_conds.append("Injured")
		if bool(member.get("is_mutant", false)):
			extra_conds.append("Mutant")
		var sub_note: String = " + ".join(extra_conds) if not extra_conds.is_empty() else str(member.get("role", "adult")).capitalize()
		var sub_lbl := _make_ink_label(sub_note, 11, COL_STAMP_RED if not extra_conds.is_empty() else COL_INK_MUTED)
		bio_v.add_child(sub_lbl)

		# [+1/4 Soup] Stepper Group
		var soup_box := _build_quarter_stepper(
			"Soup",
			cur_sq,
			rem_soup > 0,
			COL_ORANGE,
			func(delta_q: int) -> void:
				_adjust_member_ration(mid, "soup_q", delta_q)
		)
		r_hbox.add_child(soup_box)

		# [+1/4 Water] Stepper Group
		var water_box := _build_quarter_stepper(
			"Water",
			cur_wq,
			rem_water > 0,
			COL_WATER,
			func(delta_q: int) -> void:
				_adjust_member_ration(mid, "water_q", delta_q)
		)
		r_hbox.add_child(water_box)

		# [Use Medkit] Toggle
		var needs_medkit: bool = (int(member.get("sickness", 0)) > 0) or (int(member.get("injury", 0)) > 0)
		var med_selected: bool = (_planned_medkit_member_id == mid)
		var med_btn := Button.new()
		med_btn.custom_minimum_size = Vector2(114.0, 44.0)
		med_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		med_btn.add_theme_font_size_override("font_size", 12)
		if med_selected:
			med_btn.text = "[ MEDKIT SET ]"
			_style_conelrad_button(med_btn, COL_GREEN, COL_INK, COL_PARCHMENT)
		elif needs_medkit and GameState.medkit_count > 0:
			med_btn.text = "[ Use Medkit ]"
			_style_notebook_ink_button(med_btn, Color("#e8d9b8"), COL_GREEN, COL_INK)
		elif needs_medkit:
			med_btn.text = "No Medkit"
			med_btn.disabled = true
			_style_notebook_ink_button(med_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
		else:
			med_btn.text = "Well"
			med_btn.disabled = true
			_style_notebook_ink_button(med_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)

		var captured_mid: String = mid
		med_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			if _planned_medkit_member_id == captured_mid:
				_planned_medkit_member_id = ""
			else:
				_planned_medkit_member_id = captured_mid
			_rebuild_tab_rations()
		)
		r_hbox.add_child(med_btn)

	if living_in_bunker.is_empty():
		var empty_card := _make_parchment_card(Vector2(686.0, 96.0), Color("#f6edd8"), COL_INK)
		rows_vbox.add_child(empty_card)
		var empty_msg: String = "SHELTER UNOCCUPIED — No indoor rations required today while all surviving shelter members are outside scavenging."
		var empty_lbl := _make_ink_label(empty_msg, 13, COL_INK)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_card.add_child(empty_lbl)

	# Note if someone is currently away on an expedition
	if not GameState.active_expedition.is_empty():
		var out_name: String = str(GameState.active_expedition.get("member_name", "Explorer"))
		var out_place: String = str(GameState.active_expedition.get("short_target_name", GameState.active_expedition.get("target_name", "the wasteland")))
		var away_lbl := _make_ink_label("Note: %s is currently outside scavenging %s." % [out_name, out_place], 12, COL_INK_MUTED)
		rows_vbox.add_child(away_lbl)

	# Bottom Helper Bar (y = 440..480)
	var foot_hbox := HBoxContainer.new()
	foot_hbox.position = Vector2(0.0, 442.0)
	foot_hbox.size = Vector2(686.0, 36.0)
	foot_hbox.add_theme_constant_override("separation", 10)
	root.add_child(foot_hbox)

	var tip_lbl := _make_ink_label("Standard Ration: 1/4 Water & 1/4 Soup restores hydration & hunger (max 2/4/day).", 12, COL_INK_MUTED)
	tip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_lbl.clip_text = true
	tip_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot_hbox.add_child(tip_lbl)

	var hydrate_all_btn := Button.new()
	hydrate_all_btn.text = "+1/4 Water Thirsty"
	hydrate_all_btn.custom_minimum_size = Vector2(148.0, 32.0)
	hydrate_all_btn.add_theme_font_size_override("font_size", 12)
	_style_notebook_ink_button(hydrate_all_btn, COL_CARD_BG, COL_WATER, COL_INK)
	hydrate_all_btn.pressed.connect(_on_auto_water_thirsty)
	foot_hbox.add_child(hydrate_all_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Reset"
	clear_btn.custom_minimum_size = Vector2(72.0, 32.0)
	clear_btn.add_theme_font_size_override("font_size", 12)
	_style_notebook_ink_button(clear_btn, COL_CARD_BG, COL_INK_MUTED, COL_INK)
	clear_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		for k in _planned_rations.keys():
			_planned_rations[k] = {"soup_q": 0, "water_q": 0}
		_planned_medkit_member_id = ""
		_rebuild_tab_rations()
	)
	foot_hbox.add_child(clear_btn)

func _build_quarter_stepper(kind_label: String, current_q: int, can_add: bool, accent: Color, on_delta: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(26.0, 44.0)
	minus_btn.disabled = (current_q <= 0)
	minus_btn.add_theme_font_size_override("font_size", 14)
	_style_notebook_ink_button(minus_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK)
	minus_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		on_delta.call(-1)
	)
	box.add_child(minus_btn)

	var plus_btn := Button.new()
	plus_btn.custom_minimum_size = Vector2(118.0, 44.0)
	plus_btn.add_theme_font_size_override("font_size", 12)
	if current_q >= MAX_DAILY_RATION_QUARTERS:
		plus_btn.text = "%d/4 %s (MAX)" % [current_q, kind_label]
		_style_conelrad_button(plus_btn, accent, COL_INK, COL_PARCHMENT)
	elif current_q > 0:
		plus_btn.text = "%d/4 %s (+)" % [current_q, kind_label]
		_style_conelrad_button(plus_btn, accent, COL_INK, COL_PARCHMENT)
	else:
		plus_btn.text = "+1/4 %s" % kind_label
		_style_notebook_ink_button(plus_btn, Color("#ebe0c5"), accent, COL_INK)
	plus_btn.disabled = (current_q == 0 and not can_add)
	plus_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		if can_add and current_q < MAX_DAILY_RATION_QUARTERS:
			on_delta.call(1)
		else:
			on_delta.call(-current_q)
	)
	box.add_child(plus_btn)
	return box

func _adjust_member_ration(member_id: String, field: String, delta_q: int) -> void:
	if not _planned_rations.has(member_id):
		_planned_rations[member_id] = {"soup_q": 0, "water_q": 0}
	var entry: Dictionary = _planned_rations[member_id]
	var cur_val: int = int(entry.get(field, 0))
	var next_val: int = clampi(cur_val + delta_q, 0, MAX_DAILY_RATION_QUARTERS)
	if delta_q > 0:
		if field == "soup_q" and _get_total_planned_soup_q() >= GameState.soup_quarters:
			return
		if field == "water_q" and _get_total_planned_water_q() >= GameState.water_quarters:
			return
	entry[field] = next_val
	_planned_rations[member_id] = entry
	_rebuild_tab_rations()

func _on_auto_water_thirsty() -> void:
	SoundManager.play_sfx("button_click")
	for m_v in GameState.get_living_bunker_members():
		if not (m_v is Dictionary):
			continue
		var m: Dictionary = m_v
		var mid: String = str(m.get("id", ""))
		var t: int = int(m.get("thirst", 0))
		var dww: int = int(m.get("days_without_water", 0))
		if t > 0 or dww >= 1 or GameState.water_quarters >= 8:
			if _get_total_planned_water_q() < GameState.water_quarters:
				var e: Dictionary = _planned_rations.get(mid, {"soup_q": 0, "water_q": 0})
				if int(e.get("water_q", 0)) == 0:
					e["water_q"] = 1
					_planned_rations[mid] = e
	_rebuild_tab_rations()

# ---------------------------------------------------------------------------
# TAB 3: TODAY'S DILEMMA / DAY 1 SHELTER ORIENTATION (686x482)
# ---------------------------------------------------------------------------
func _rebuild_tab_dilemma() -> void:
	var root: Control = _tab_containers[TAB_DILEMMA]
	_clear_children(root)

	if GameState.get_living_bunker_members().is_empty():
		_build_unoccupied_shelter_view(root)
		return

	if _current_event.is_empty() or _get_event_options(_current_event).is_empty():
		_build_day1_orientation_view(root)
		return

	var ev_title: String = _strip_md(str(_current_event.get("title", "SHELTER DILEMMA"))).to_upper()
	var ev_desc: String = _strip_md(str(_current_event.get("description", _current_event.get("text", "Something stirs outside the blast hatch..."))))
	if not _has_unresolved_dilemma and not _resolved_outcome.is_empty():
		ev_desc += "\n\nDECIDED: %s acted. %s" % [str(_resolved_outcome.get("actor_name", "")), _strip_md(str(_resolved_outcome.get("outcome_text", "")))]
		var replay := Button.new()
		replay.text = "REPLAY WHAT HAPPENED"
		replay.position = Vector2(470.0, 190.0)
		replay.size = Vector2(214.0, 22.0)
		replay.add_theme_font_size_override("font_size", 11)
		_style_notebook_ink_button(replay, COL_PARCHMENT_DARK, COL_INK, COL_INK)
		replay.pressed.connect(func() -> void:
			_cinematic.play_outcome(_resolved_outcome, _current_event)
		)
		root.add_child(replay)
	var options: Array = _get_event_options(_current_event)
	var compact_opts: bool = options.size() >= 5

	var hdr := _make_ink_label("DAY %d DILEMMA — %s" % [GameState.day, ev_title], 18, COL_STAMP_RED)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 26.0)
	hdr.clip_text = true
	root.add_child(hdr)

	# Story box (y = 28..190)
	var story_card := _make_parchment_card(Vector2(686.0, 162.0), Color("#f6edd8"), COL_INK)
	story_card.position = Vector2(0.0, 28.0)
	story_card.size = Vector2(686.0, 162.0)
	root.add_child(story_card)

	var story_scroll := ScrollContainer.new()
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_card.add_child(story_scroll)

	var story_lbl := _make_ink_label(ev_desc, 15, COL_INK)
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_lbl.custom_minimum_size = Vector2(652.0, 0.0)
	story_scroll.add_child(story_lbl)

	var prompt_lbl := _make_ink_label("CHOOSE YOUR RESPONSE:" if _has_unresolved_dilemma else "DECISION MADE — RECORDED IN THE JOURNAL", 12, COL_INK_MUTED)
	prompt_lbl.position = Vector2(2.0, 193.0)
	prompt_lbl.size = Vector2(680.0, 18.0)
	root.add_child(prompt_lbl)

	# Scrollable Options Stack (Rect2(0, 214, 686, 266)) so 5+ options fit cleanly without clipping
	var opts_scroll := ScrollContainer.new()
	opts_scroll.position = Vector2(0.0, 214.0)
	opts_scroll.size = Vector2(686.0, 266.0)
	opts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(opts_scroll)

	var opts_vbox := VBoxContainer.new()
	opts_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_vbox.add_theme_constant_override("separation", 6 if compact_opts else 8)
	opts_scroll.add_child(opts_vbox)

	var card_h: float = 46.0 if compact_opts else 54.0
	var btn_h: float = 34.0 if compact_opts else 40.0
	var icon_sz: float = 32.0 if compact_opts else 38.0

	for opt_v in options:
		if not (opt_v is Dictionary):
			continue
		var opt: Dictionary = opt_v
		var cid: String = str(opt.get("id", ""))
		var label_txt: String = _strip_md(str(opt.get("label", opt.get("text", cid.capitalize()))))
		var req_item: String = str(opt.get("item_id", opt.get("required_item", "")))
		var avail: bool = _is_event_option_available(opt)
		var is_chosen: bool = (_selected_event_choice_id == cid)

		var opt_panel := _make_parchment_card(
			Vector2(672.0, card_h),
			Color("#f7e7ba") if is_chosen else (Color("#efe4c8") if avail else Color("#ded4bd")),
			COL_STAMP_RED if is_chosen else (COL_INK if avail else COL_INK_MUTED)
		)
		opt_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt_panel.custom_minimum_size = Vector2(672.0, card_h)
		if compact_opts:
			var sb_opt: StyleBoxFlat = opt_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			if sb_opt != null:
				sb_opt.content_margin_top = 4.0
				sb_opt.content_margin_bottom = 4.0
				opt_panel.add_theme_stylebox_override("panel", sb_opt)
		opts_vbox.add_child(opt_panel)

		var oh := HBoxContainer.new()
		oh.add_theme_constant_override("separation", 8)
		opt_panel.add_child(oh)

		var sel_btn := Button.new()
		sel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel_btn.custom_minimum_size = Vector2(440.0, btn_h)
		sel_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sel_btn.clip_text = true
		sel_btn.disabled = not avail
		sel_btn.add_theme_font_size_override("font_size", 13 if compact_opts else 14)
		var prefix: String = "[ SELECTED ]  " if is_chosen else "[   ]  "
		sel_btn.text = prefix + label_txt
		if is_chosen:
			_style_conelrad_button(sel_btn, COL_STAMP_RED, COL_INK, Color("#fff5df"))
		elif avail:
			_style_notebook_ink_button(sel_btn, Color("#f2e6cb"), COL_INK, COL_INK)
		else:
			_style_notebook_ink_button(sel_btn, Color("#dad0ba"), COL_INK_MUTED, COL_INK_MUTED)
		if compact_opts:
			for st_n in ["normal", "hover", "pressed", "disabled", "focus"]:
				if sel_btn.has_theme_stylebox_override(st_n):
					var sb_b: StyleBoxFlat = sel_btn.get_theme_stylebox(st_n).duplicate() as StyleBoxFlat
					if sb_b != null:
						sb_b.content_margin_top = 2.0
						sb_b.content_margin_bottom = 2.0
						sel_btn.add_theme_stylebox_override(st_n, sb_b)

		var captured_cid: String = cid
		sel_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			_on_dilemma_choice(captured_cid)
		)
		if not _has_unresolved_dilemma:
			sel_btn.disabled = true
		oh.add_child(sel_btn)

		if req_item != "":
			var item_broken: bool = _is_item_owned_but_broken(req_item)
			var icon_w := _ItemIconWidget.new()
			icon_w.item_id = req_item
			icon_w.is_broken = item_broken
			icon_w.custom_minimum_size = Vector2(icon_sz, icon_sz)
			oh.add_child(icon_w)

			var st_txt: String = "READY" if avail else ("BROKEN" if item_broken else "MISSING")
			var st_col: Color = COL_GREEN if avail else COL_STAMP_RED
			oh.add_child(_make_status_pill(st_txt, st_col))

func _build_unoccupied_shelter_view(root: Control) -> void:
	var hdr := _make_ink_label("SHELTER UNOCCUPIED — AWAITING EXPLORER RETURN", 18, COL_INK)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 28.0)
	root.add_child(hdr)

	var card := _make_parchment_card(Vector2(686.0, 236.0), Color("#f6edd8"), COL_INK)
	card.position = Vector2(0.0, 34.0)
	card.size = Vector2(686.0, 236.0)
	root.add_child(card)

	var h_addr: String = LocationText.home_ref()
	var exp_name: String = str(GameState.active_expedition.get("member_name", "Our lone survivor"))
	var exp_dest: String = str(GameState.active_expedition.get("short_target_name", GameState.active_expedition.get("target_name", "the irradiated neighborhood")))
	var days_rem: int = maxi(1, int(GameState.active_expedition.get("days_remaining", 1)))
	var lines: Array[String] = [
		"• SHELTER STATUS: Heavy blast doors locked from the outside beneath %s." % h_addr,
		"• ACTIVE RECON: %s is currently out scavenging %s (%d day%s until expected return)." % [
			exp_name, exp_dest, days_rem, "" if days_rem == 1 else "s"
		],
		"• DILEMMA PROTOCOL: With nobody inside to answer the hatch or tune the CONELRAD receiver, bunker dilemmas are paused until the explorer returns.",
		"• DIRECTIVE: Advance the day to track %s's return from the wasteland!" % exp_name
	]
	var body := _make_ink_label("\n\n".join(lines), 14, COL_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(body)

	var eq_hdr := _make_ink_label("STANDBY SHELTER EQUIPMENT:", 13, COL_INK_MUTED)
	eq_hdr.position = Vector2(2.0, 286.0)
	eq_hdr.size = Vector2(680.0, 20.0)
	root.add_child(eq_hdr)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(0.0, 312.0)
	grid.size = Vector2(686.0, 156.0)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	for key_id in ["radio", "gas_mask", "suitcase", "map", "medkit", "rifle", "axe", "padlock"]:
		var owned_ok: bool = GameState.has_working_item(key_id)
		var g_card := _make_parchment_card(Vector2(165.0, 68.0), COL_CARD_BG if owned_ok else Color("#ddd2bc"), COL_GREEN if owned_ok else COL_INK_MUTED)
		g_card.custom_minimum_size = Vector2(165.0, 68.0)
		grid.add_child(g_card)

		var gh := HBoxContainer.new()
		gh.add_theme_constant_override("separation", 6)
		g_card.add_child(gh)

		var ic := _ItemIconWidget.new()
		ic.item_id = key_id
		ic.is_broken = _is_item_owned_but_broken(key_id)
		ic.custom_minimum_size = Vector2(36.0, 36.0)
		gh.add_child(ic)

		var gv := VBoxContainer.new()
		gh.add_child(gv)
		var info: Dictionary = ItemDB.get_item_info(key_id)
		gv.add_child(_make_ink_label(str(info.get("short_name", key_id.capitalize())), 12, COL_INK))
		gv.add_child(_make_ink_label("READY" if owned_ok else "OUT / NONE", 10, COL_GREEN if owned_ok else COL_INK_MUTED))

func _build_day1_orientation_view(root: Control) -> void:
	var hdr := _make_ink_label("CONELRAD FORM CD-1 — DAY 1 SHELTER ORIENTATION", 18, COL_INK)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 28.0)
	root.add_child(hdr)

	var card := _make_parchment_card(Vector2(686.0, 250.0), Color("#f6edd8"), COL_INK)
	card.position = Vector2(0.0, 34.0)
	card.size = Vector2(686.0, 250.0)
	root.add_child(card)

	var h_addr: String = LocationText.home_ref()
	var n_name: String = str(GameState.nuke_config.get("target_name", "Strategic Target"))
	var n_yield: int = int(GameState.nuke_config.get("yield_kt", 800))
	var n_dist: float = float(GameState.nuke_config.get("distance_km", 3.0))
	var n_zone: String = str(GameState.nuke_config.get("zone", "fallout_plume")).replace("_", " ").to_upper()

	var orient_lines: Array[String] = [
		"• DESIGNATED FALLOUT SHELTER: %s" % h_addr,
		"• DETONATION TELEMETRY: %d kt warhead at %s (%.2f km — %s)" % [n_yield, n_name, n_dist, n_zone],
		"• ATMOSPHERIC READINGS: %s outside | %.0f °C interior shelter climate" % [RadiationModel.format_rate(GameState.surface_radiation_sv * 1000.0), GameState.bunker_temp_c],
		"• DAY 1 SURFACE STATUS: Heavy fallout dust is still settling — no surface knocks or raids today.",
		"• SURVIVAL DIRECTIVE: Ration 1/4 Water before dehydration sets in, equip a Gas Mask + Suitcase for real-world OpenStreetMap scavenging runs, and monitor CONELRAD radio & nearby Churches for evacuation!"
	]
	var body := _make_ink_label("\n".join(orient_lines), 14, COL_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(body)

	var eq_hdr := _make_ink_label("KEY SHELTER EQUIPMENT READINESS:", 13, COL_INK_MUTED)
	eq_hdr.position = Vector2(2.0, 294.0)
	eq_hdr.size = Vector2(680.0, 20.0)
	root.add_child(eq_hdr)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(0.0, 318.0)
	grid.size = Vector2(686.0, 152.0)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	for key_id in ["radio", "gas_mask", "suitcase", "map", "medkit", "rifle", "axe", "padlock"]:
		var owned_ok: bool = GameState.has_working_item(key_id)
		var g_card := _make_parchment_card(Vector2(165.0, 68.0), COL_CARD_BG if owned_ok else Color("#ddd2bc"), COL_GREEN if owned_ok else COL_INK_MUTED)
		g_card.custom_minimum_size = Vector2(165.0, 68.0)
		grid.add_child(g_card)

		var gh := HBoxContainer.new()
		gh.add_theme_constant_override("separation", 6)
		g_card.add_child(gh)

		var ic := _ItemIconWidget.new()
		ic.item_id = key_id
		ic.is_broken = _is_item_owned_but_broken(key_id)
		ic.custom_minimum_size = Vector2(36.0, 36.0)
		gh.add_child(ic)

		var gv := VBoxContainer.new()
		gh.add_child(gv)
		var info: Dictionary = ItemDB.get_item_info(key_id)
		gv.add_child(_make_ink_label(str(info.get("short_name", key_id.capitalize())), 12, COL_INK))
		gv.add_child(_make_ink_label("READY" if owned_ok else "MISSING", 10, COL_GREEN if owned_ok else COL_STAMP_RED))

# ---------------------------------------------------------------------------
# TAB 4: REAL-WORLD OSM EXPEDITION MAP (686x482)
# ---------------------------------------------------------------------------
func _rebuild_tab_expedition() -> void:
	var root: Control = _tab_containers[TAB_EXPEDITION]
	_clear_children(root)

	_available_targets = ExpeditionEngine.get_available_targets()
	if _selected_poi_index < 0 or _selected_poi_index >= _available_targets.size():
		_selected_poi_index = 0

	if not GameState.active_expedition.is_empty():
		_build_active_expedition_tracker(root)
	else:
		_build_expedition_planner(root)

func _build_active_expedition_tracker(root: Control) -> void:
	var exp_d: Dictionary = GameState.active_expedition
	var explorer_name: String = str(exp_d.get("member_name", "Explorer"))
	var explorer_id: String = str(exp_d.get("member_id", ""))
	var target_name: String = str(exp_d.get("short_target_name", exp_d.get("target_name", "Real-World Landmark")))
	var cat_str: String = str(exp_d.get("category", "landmark")).to_upper()
	var dist_m: float = float(exp_d.get("distance_m", 180.0))
	var bearing_str: String = str(exp_d.get("bearing", "N"))
	var days_rem: int = maxi(1, int(exp_d.get("days_remaining", 1)))
	var days_tot: int = maxi(days_rem, int(exp_d.get("days_total", days_rem)))
	var carried_gear: Array = exp_d.get("gear_ids", [])
	var active_poi_idx: int = int(exp_d.get("poi_index", 0))

	var hdr := _make_ink_label("LIVE SURFACE EXPEDITION TRACKER — RECON IN PROGRESS", 17, COL_STAMP_RED)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 26.0)
	root.add_child(hdr)

	# Left: Tactical Radar Map showing active route & explorer beacon
	var radar := _ExpeditionRadarMap.new()
	radar.position = Vector2(0.0, 32.0)
	radar.size = Vector2(328.0, 444.0)
	radar.targets = _available_targets
	radar.selected_index = clampi(active_poi_idx, 0, maxi(0, _available_targets.size() - 1))
	radar.active_expedition_mode = true
	radar.route_progress = clampf(1.0 - float(days_rem) / float(days_tot + 1), 0.25, 0.85)
	root.add_child(radar)

	# Right: Explorer dossier, Real-World OSM Destination, Gear Loadout, Countdown
	var right_card := _make_parchment_card(Vector2(344.0, 444.0), Color("#f6edd8"), COL_INK)
	right_card.position = Vector2(342.0, 32.0)
	right_card.size = Vector2(344.0, 444.0)
	root.add_child(right_card)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	right_card.add_child(rv)

	var member_dict: Dictionary = _find_member_by_id(explorer_id)
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 10)
	rv.add_child(exp_row)

	if not member_dict.is_empty():
		var port := _MemberPortraitWidget.new()
		port.member_data = member_dict
		port.custom_minimum_size = Vector2(64.0, 78.0)
		exp_row.add_child(port)

	var who_v := VBoxContainer.new()
	who_v.add_theme_constant_override("separation", 4)
	exp_row.add_child(who_v)
	who_v.add_child(_make_ink_label("EXPLORER OUTSIDE:", 11, COL_INK_MUTED))
	who_v.add_child(_make_ink_label(explorer_name.to_upper(), 18, COL_INK))
	who_v.add_child(_make_status_pill("SCAVENGING TOPSIDE", COL_WATER))

	var dest_box := _make_parchment_card(Vector2(320.0, 108.0), COL_CARD_BG, COL_INK)
	rv.add_child(dest_box)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	dest_box.add_child(dv)
	dv.add_child(_make_ink_label("OPENSTREETMAP DESTINATION (%s):" % cat_str, 11, COL_INK_MUTED))
	var t_lbl := _make_ink_label(target_name, 16, COL_STAMP_RED)
	t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(t_lbl)
	dv.add_child(_make_ink_label("Distance: %.0f m (%s of shelter)" % [dist_m, bearing_str], 12, COL_INK))

	rv.add_child(_make_ink_label("CARRIED SURVIVAL GEAR:", 12, COL_INK_MUTED))
	var gear_h := HBoxContainer.new()
	gear_h.add_theme_constant_override("separation", 8)
	rv.add_child(gear_h)
	if carried_gear.is_empty():
		gear_h.add_child(_make_ink_label("Travelling light (no gear checked out)", 13, COL_INK))
	else:
		for g_v in carried_gear:
			var gid: String = str(g_v)
			var g_chip := _make_parchment_card(Vector2(50.0, 50.0), COL_CARD_BG, COL_INK)
			var ic := _ItemIconWidget.new()
			ic.item_id = gid
			ic.custom_minimum_size = Vector2(38.0, 38.0)
			g_chip.add_child(ic)
			gear_h.add_child(g_chip)

	var eta_card := _make_parchment_card(Vector2(320.0, 74.0), Color("#232923"), COL_HAZARD)
	rv.add_child(eta_card)
	var eta_lbl := Label.new()
	eta_lbl.text = "DAYS UNTIL RETURN: %d DAY%s" % [days_rem, "" if days_rem == 1 else "S"]
	eta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eta_lbl.add_theme_font_size_override("font_size", 17)
	eta_lbl.add_theme_color_override("font_color", COL_HAZARD)
	eta_card.add_child(eta_lbl)

func _build_expedition_planner(root: Control) -> void:
	_ensure_valid_explorer_selected()

	# --- LEFT COLUMN (x = 0..332): Radar Map (0..246) + Scrollable OSM Target List (252..480) ---
	_radar_map_widget = ShelterMapView.new()
	_radar_map_widget.compact = true
	_radar_map_widget.position = Vector2(0.0, 0.0)
	_radar_map_widget.size = Vector2(332.0, 246.0)
	_radar_map_widget.targets = _available_targets
	_radar_map_widget.selected_index = _selected_poi_index
	_radar_map_widget.target_clicked.connect(func(idx: int) -> void:
		SoundManager.play_sfx("button_click")
		_selected_poi_index = idx
		_rebuild_tab_expedition()
	)
	root.add_child(_radar_map_widget)

	var list_card := _make_parchment_card(Vector2(332.0, 228.0), Color("#f6edd8"), COL_INK)
	list_card.position = Vector2(0.0, 252.0)
	list_card.size = Vector2(332.0, 228.0)
	root.add_child(list_card)

	var t_scroll := ScrollContainer.new()
	t_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_card.add_child(t_scroll)

	var t_vbox := VBoxContainer.new()
	t_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_vbox.add_theme_constant_override("separation", 4)
	t_scroll.add_child(t_vbox)

	for i in range(_available_targets.size()):
		var td: Dictionary = _available_targets[i]
		var is_sel: bool = (i == _selected_poi_index)
		var base_name: String = str(td.get("name", "Landmark"))
		var cat: String = str(td.get("category", "house"))
		var dist_m: int = int(td.get("distance_m", 150))
		var t_days: int = int(td.get("travel_days", 2))
		var depl: bool = bool(td.get("depleted", false))

		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(304.0, 36.0)
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.clip_text = true
		row_btn.add_theme_font_size_override("font_size", 12)
		var cat_short: String = _short_category_tag(cat)
		var depl_suffix: String = " [EMPTY]" if depl else ""
		row_btn.text = "[%s] %s (%dm · %dd)%s" % [cat_short, base_name, dist_m, t_days, depl_suffix]
		if is_sel:
			_style_conelrad_button(row_btn, COL_STAMP_RED, COL_INK, Color("#fff5df"))
		else:
			_style_notebook_ink_button(row_btn, COL_CARD_BG if not depl else Color("#d8ceba"), COL_INK, COL_INK if not depl else COL_INK_MUTED)

		var cap_idx: int = i
		row_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			_selected_poi_index = cap_idx
			_rebuild_tab_expedition()
		)
		t_vbox.add_child(row_btn)

	# --- RIGHT COLUMN (x = 344..686, width = 342) ---
	# 1. Selected Target Detail Header (y = 0..86)
	var sel_poi: Dictionary = _available_targets[_selected_poi_index] if not _available_targets.is_empty() else {}
	var detail_card := _make_parchment_card(Vector2(336.0, 86.0), COL_CARD_BG, COL_INK)
	detail_card.position = Vector2(344.0, 0.0)
	detail_card.size = Vector2(336.0, 86.0)
	root.add_child(detail_card)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 3)
	detail_card.add_child(dv)

	var p_name: String = str(sel_poi.get("name", "No Target"))
	var p_cat: String = str(sel_poi.get("category", "landmark")).to_upper()
	var p_dist: int = int(sel_poi.get("distance_m", 150))
	var p_bear: String = str(sel_poi.get("bearing", "E"))
	var sel_member: Dictionary = _find_member_by_id(_selected_explorer_id)
	var est_days: int = ExpeditionEngine.compute_trip_days(sel_member, sel_poi, _selected_gear_ids) if not sel_poi.is_empty() else 2
	var b_risk: String = str(sel_poi.get("bandit_risk", "Moderate"))

	var d_title := _make_ink_label(p_name, 14, COL_STAMP_RED)
	d_title.clip_text = true
	dv.add_child(d_title)
	var walk_tag: String = "walk" if str(sel_poi.get("walk_source", "")) == "network" else "est."
	dv.add_child(_make_ink_label("%s · %dm %s %s · Trip: %dd · Raiders: %s" % [str(sel_poi.get("kind_label", p_cat)), int(sel_poi.get("walk_m", p_dist)), walk_tag, p_bear, est_days, b_risk], 11, COL_INK))
	var has_mask_sel: bool = _selected_gear_ids.has("gas_mask")
	var dose_est: float = float(sel_poi.get("dose_estimate_mask_msv" if has_mask_sel else "dose_estimate_msv", 0.0))
	dv.add_child(_make_ink_label("Outside now: %s (%s) · Trip dose from tomorrow ≈ %s · %s" % [RadiationModel.format_rate(float(sel_poi.get("dose_rate_msv_h", 0.0))), str(sel_poi.get("radiation_risk", "")), RadiationModel.format_dose(dose_est), str(sel_poi.get("loot_status", ""))], 11, COL_STAMP_RED if dose_est > 250.0 else COL_INK_MUTED))

	var loot_h := HBoxContainer.new()
	loot_h.add_theme_constant_override("separation", 5)
	dv.add_child(loot_h)
	loot_h.add_child(_make_ink_label("Expected Loot:", 11, COL_INK_MUTED))
	var loot_ids: Array = sel_poi.get("expected_loot", ["soup", "water"])
	for lid_v in loot_ids:
		var ic := _ItemIconWidget.new()
		ic.item_id = str(lid_v)
		ic.custom_minimum_size = Vector2(22.0, 22.0)
		loot_h.add_child(ic)

	# 2. Explorer Selector (y = 92..222)
	var exp_hdr := _make_ink_label("1. SELECT EXPLORER (ADULT / TEEN):", 12, COL_INK_MUTED)
	exp_hdr.position = Vector2(346.0, 92.0)
	exp_hdr.size = Vector2(336.0, 18.0)
	root.add_child(exp_hdr)

	var exp_grid := GridContainer.new()
	exp_grid.columns = 2
	exp_grid.position = Vector2(344.0, 112.0)
	exp_grid.size = Vector2(336.0, 108.0)
	exp_grid.add_theme_constant_override("h_separation", 6)
	exp_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(exp_grid)

	var candidates: Array = _get_eligible_explorers()
	if candidates.is_empty():
		exp_grid.add_child(_make_ink_label("No healthy adult/teen available in shelter!", 12, COL_STAMP_RED))
	else:
		for m_v in candidates:
			var md: Dictionary = m_v
			var mid: String = str(md.get("id", ""))
			var chosen_m: bool = (mid == _selected_explorer_id)
			var m_btn := Button.new()
			m_btn.custom_minimum_size = Vector2(164.0, 46.0)
			m_btn.clip_text = true
			m_btn.add_theme_font_size_override("font_size", 12)
			var m_lbl: String = "%s (%s)" % [str(md.get("name", "Survivor")), str(md.get("role", "adult")).capitalize()]
			m_btn.text = ("[X] " if chosen_m else "[ ] ") + m_lbl
			if chosen_m:
				_style_conelrad_button(m_btn, Color("#33442d"), COL_HAZARD, COL_HAZARD)
			else:
				_style_notebook_ink_button(m_btn, COL_CARD_BG, COL_INK, COL_INK)
			var cap_mid: String = mid
			m_btn.pressed.connect(func() -> void:
				SoundManager.play_sfx("button_click")
				_selected_explorer_id = cap_mid
				_rebuild_tab_expedition()
			)
			exp_grid.add_child(m_btn)

	# 3. Gear Loadout Checkboxes (y = 226..408) — 3 * 104 + 10 = 322px <= 342px (zero right clipping!)
	var has_suitcase_sel: bool = _selected_gear_ids.has("suitcase") and GameState.has_working_item("suitcase")
	var extra_gear_cnt: int = _count_non_suitcase_selected_gear()
	var gear_hdr_txt: String = (
		"2. GEAR LOADOUT (SUITCASE: %d/3 EXTRA SLOTS):" % extra_gear_cnt
		if has_suitcase_sel
		else "2. GEAR (%d/1 ITEM — PACK SUITCASE FOR +3!):" % _selected_gear_ids.size()
	)
	var gear_hdr := _make_ink_label(gear_hdr_txt, 11, COL_GREEN if has_suitcase_sel else COL_INK_MUTED)
	gear_hdr.position = Vector2(344.0, 226.0)
	gear_hdr.size = Vector2(338.0, 18.0)
	gear_hdr.clip_text = true
	root.add_child(gear_hdr)

	var g_grid := GridContainer.new()
	g_grid.columns = 3
	g_grid.position = Vector2(344.0, 246.0)
	g_grid.size = Vector2(342.0, 162.0)
	g_grid.add_theme_constant_override("h_separation", 5)
	g_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(g_grid)

	for gid in EXPEDITION_GEAR_SLOTS:
		var working: bool = GameState.has_working_item(gid)
		var broken: bool = _is_item_owned_but_broken(gid)
		var checked: bool = working and _selected_gear_ids.has(gid)

		var cell := _make_parchment_card(
			Vector2(104.0, 74.0),
			Color("#e9f0d8") if checked else (COL_CARD_BG if working else Color("#dcd2be")),
			COL_GREEN if checked else (COL_INK if working else COL_INK_MUTED)
		)
		cell.custom_minimum_size = Vector2(104.0, 74.0)
		var sb_cell: StyleBoxFlat = cell.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb_cell != null:
			sb_cell.content_margin_left = 6.0
			sb_cell.content_margin_right = 6.0
			sb_cell.content_margin_top = 5.0
			sb_cell.content_margin_bottom = 5.0
			cell.add_theme_stylebox_override("panel", sb_cell)
		g_grid.add_child(cell)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		cell.add_child(cv)

		var top_h := HBoxContainer.new()
		top_h.add_theme_constant_override("separation", 4)
		cv.add_child(top_h)

		var ic := _ItemIconWidget.new()
		ic.item_id = gid
		ic.is_broken = broken
		ic.custom_minimum_size = Vector2(26.0, 26.0)
		top_h.add_child(ic)

		var info: Dictionary = ItemDB.get_item_info(gid)
		var short_n: String = str(info.get("short_name", gid.capitalize()))
		var n_lbl := _make_ink_label(short_n, 10, COL_INK if working else COL_INK_MUTED)
		n_lbl.clip_text = true
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_h.add_child(n_lbl)

		var chk_btn := Button.new()
		chk_btn.custom_minimum_size = Vector2(86.0, 26.0)
		chk_btn.disabled = not working
		chk_btn.add_theme_font_size_override("font_size", 10)
		if checked:
			chk_btn.text = "[X] PACKED"
			_style_conelrad_button(chk_btn, COL_GREEN, COL_INK, COL_PARCHMENT)
		elif working:
			chk_btn.text = "[ ] EQUIP"
			_style_notebook_ink_button(chk_btn, Color("#f2e6cc"), COL_INK, COL_INK)
		elif broken:
			chk_btn.text = "BROKEN"
			_style_notebook_ink_button(chk_btn, Color("#d8ceba"), COL_STAMP_RED, COL_STAMP_RED)
		else:
			chk_btn.text = "NONE"
			_style_notebook_ink_button(chk_btn, Color("#d8ceba"), COL_INK_MUTED, COL_INK_MUTED)
		for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			if chk_btn.has_theme_stylebox_override(st_name):
				var sb_chk: StyleBoxFlat = chk_btn.get_theme_stylebox(st_name).duplicate() as StyleBoxFlat
				if sb_chk != null:
					sb_chk.content_margin_left = 4.0
					sb_chk.content_margin_right = 4.0
					chk_btn.add_theme_stylebox_override(st_name, sb_chk)

		var cap_gid: String = gid
		chk_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			_toggle_expedition_gear(cap_gid)
			_rebuild_tab_expedition()
		)
		cv.add_child(chk_btn)

	# 4. [ SCHEDULE EXPEDITION ON NEXT DAY ] Toggle (y = 416..478)
	var sched_btn := Button.new()
	sched_btn.name = "ScheduleExpeditionButton"
	sched_btn.position = Vector2(344.0, 416.0)
	sched_btn.size = Vector2(336.0, 60.0)
	sched_btn.clip_text = true
	sched_btn.disabled = candidates.is_empty() or _available_targets.is_empty()
	sched_btn.add_theme_font_size_override("font_size", 13)
	if _expedition_scheduled:
		var exp_m: Dictionary = _find_member_by_id(_selected_explorer_id)
		var m_nm: String = str(exp_m.get("name", "Explorer"))
		sched_btn.text = "[ EXPEDITION ARMED: %s -> %s ]" % [m_nm.to_upper(), p_name]
		_style_conelrad_button(sched_btn, COL_GREEN, COL_INK, Color("#fff8e6"))
	else:
		sched_btn.text = "[ SCHEDULE EXPEDITION ON NEXT DAY ]"
		_style_conelrad_button(sched_btn, Color("#2d362b"), COL_HAZARD, COL_HAZARD)

	sched_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		_expedition_scheduled = not _expedition_scheduled
		_rebuild_tab_expedition()
		_refresh_tab_headers_and_footer()
	)
	root.add_child(sched_btn)

func _count_non_suitcase_selected_gear() -> int:
	var cnt: int = 0
	for g in _selected_gear_ids:
		if g != "suitcase":
			cnt += 1
	return cnt

func _toggle_expedition_gear(gid: String) -> void:
	if _selected_gear_ids.has(gid):
		_selected_gear_ids.erase(gid)
		# Without Suitcase checked, max 1 gear item may remain packed
		if not _selected_gear_ids.has("suitcase"):
			while _selected_gear_ids.size() > 1:
				_selected_gear_ids.remove_at(0)
		return

	if not GameState.has_working_item(gid):
		return

	if gid == "suitcase":
		_selected_gear_ids.insert(0, "suitcase")
		while _count_non_suitcase_selected_gear() > 3:
			for idx in range(_selected_gear_ids.size() - 1, -1, -1):
				if _selected_gear_ids[idx] != "suitcase":
					_selected_gear_ids.remove_at(idx)
					break
		return

	var has_suitcase: bool = _selected_gear_ids.has("suitcase") and GameState.has_working_item("suitcase")
	if not has_suitcase:
		# Classic 60 Seconds! rule: max 1 gear item without Suitcase (selecting new replaces previous)
		_selected_gear_ids.clear()
		_selected_gear_ids.append(gid)
	else:
		# Suitcase packed: allow Suitcase + up to 3 additional gear items
		if _count_non_suitcase_selected_gear() < 3:
			_selected_gear_ids.append(gid)
		else:
			for idx in range(_selected_gear_ids.size()):
				if _selected_gear_ids[idx] != "suitcase":
					_selected_gear_ids.remove_at(idx)
					break
			_selected_gear_ids.append(gid)

# ---------------------------------------------------------------------------
# END DAY TURN RESOLUTION & DRAMATIC "DAY <N>" CURTAIN
# ---------------------------------------------------------------------------
func _on_end_day_pressed() -> void:
	if _in_day_transition or (is_instance_valid(_cinematic) and _cinematic.is_busy()):
		return
	if _has_unresolved_dilemma and not GameState.get_living_bunker_members().is_empty():
		# The day's dilemma must be answered first – reopen it instead of choosing silently.
		_day_queue = [{"type": "dilemma"}]
		_run_day_queue()
		return
	SoundManager.play_sfx("page_turn")

	var next_day_preview: int = GameState.day + 1
	var house_sub: String = LocationText.area_header()
	_curtain_duration = 0.62 if GameState.demo_mode else 0.85
	_curtain_timer = 0.0
	_curtain_midpoint_fired = false
	_in_day_transition = true
	_curtain_overlay.configure(next_day_preview, house_sub)
	_curtain_overlay.visible = true
	_curtain_overlay.set_progress(0.0)

func _on_curtain_midpoint() -> void:
	# 1. Resolve today's event if Day >= 1, shelter is occupied, and an event has options
	# The dilemma was resolved (and animated) earlier in the day by the player's own choice.
	var event_outcome: Dictionary = _resolved_outcome.duplicate()
	_resolved_outcome = {}

	# 2. Clamp planned rations to 0..2 per person AND actual remaining GameState stockpiles
	var clamped_rations: Dictionary = {}
	var soup_budget: int = maxi(0, GameState.soup_quarters)
	var water_budget: int = maxi(0, GameState.water_quarters)
	for mid_k in _planned_rations.keys():
		var mid_s: String = str(mid_k)
		var entry: Dictionary = _planned_rations[mid_s]
		var sq: int = mini(clampi(int(entry.get("soup_q", 0)), 0, MAX_DAILY_RATION_QUARTERS), soup_budget)
		soup_budget -= sq
		var wq: int = mini(clampi(int(entry.get("water_q", 0)), 0, MAX_DAILY_RATION_QUARTERS), water_budget)
		water_budget -= wq
		clamped_rations[mid_s] = {"soup_q": sq, "water_q": wq}

	var med_target: String = _planned_medkit_member_id if GameState.medkit_count > 0 else ""

	# 3. Build expedition_launch payload if scheduled
	var expedition_launch: Dictionary = {}
	if _expedition_scheduled and GameState.active_expedition.is_empty() and _selected_explorer_id != "" and not _available_targets.is_empty():
		var safe_poi_idx: int = clampi(_selected_poi_index, 0, _available_targets.size() - 1)
		expedition_launch = {
			"scheduled": true,
			"launch": true,
			"member_id": _selected_explorer_id,
			"explorer_id": _selected_explorer_id,
			"poi_index": safe_poi_idx,
			"target_index": safe_poi_idx,
			"gear_ids": _selected_gear_ids.duplicate(),
			"gear": _selected_gear_ids.duplicate()
		}

	# In demo_mode at end of Day 3, ensure a 3-day expedition finishes right on Day 4 so the demo captures the return!
	if GameState.demo_mode and GameState.day == 3 and not GameState.active_expedition.is_empty():
		if int(GameState.active_expedition.get("days_remaining", 1)) > 1:
			GameState.active_expedition["days_remaining"] = 1

	# 4. Advance Bunker Simulation!
	var prev_log_count: int = GameState.daily_log_entries.size()
	var day_lines: Array = BunkerSim.advance_day(clamped_rations, med_target, event_outcome, expedition_launch)

	# Safety fallback: if BunkerSim didn't invoke ExpeditionEngine.start_expedition itself, launch it cleanly
	if not expedition_launch.is_empty() and GameState.active_expedition.is_empty():
		var launch_note: String = ExpeditionEngine.start_expedition(
			str(expedition_launch["member_id"]),
			int(expedition_launch["poi_index"]),
			expedition_launch["gear_ids"] as Array
		)
		if launch_note != "":
			day_lines.append(launch_note)

	# Ensure daily_log_entries captured the new day's report if BunkerSim returned lines without pushing
	if GameState.daily_log_entries.size() == prev_log_count and not day_lines.is_empty():
		GameState.daily_log_entries.append({
			"day": GameState.day,
			"title": "DAY %d — SHELTER REPORT" % GameState.day,
			"lines": day_lines
		})

	_curtain_overlay.configure(GameState.day, LocationText.area_header())

	# 5. Check Game Over / Victory transition
	if GameState.game_over and not GameState.demo_mode:
		if GameState.victory:
			SoundManager.play_sfx("victory")
		else:
			SoundManager.play_sfx("gameover")
		_in_day_transition = false
		_curtain_overlay.visible = false
		GameState.request_screen(GameState.SCREEN_SUMMARY)
		return

	_prepare_new_day_turn(true)

# ---------------------------------------------------------------------------
# SMART GAMESTATE.DEMO_MODE SHOWCASE (~14s, 4 FULL BUNKER DAYS!)
# ---------------------------------------------------------------------------
func _start_demo_showcase() -> void:
	if _demo_running:
		return
	_demo_running = true
	BunkerScene.demo_completed_flag = false
	_run_demo_sequence()

func _wait_cinematic_idle() -> void:
	await get_tree().process_frame
	while is_inside_tree() and is_instance_valid(_cinematic) and (_cinematic.is_busy() or not _day_queue.is_empty()):
		await get_tree().process_frame

func _run_demo_sequence() -> void:
	# --- DAY 1: Full Bunker View -> Log -> Rations -> Day 1 Dilemma -> OSM Expedition Map -> End Day 1 ---
	await _wait_cinematic_idle()
	_set_notebook_open(false)
	await get_tree().create_timer(1.55).timeout
	if not is_inside_tree():
		return

	_set_notebook_open(true)
	_switch_tab(TAB_LOG, true)
	await get_tree().create_timer(0.95).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_RATIONS, true)
	await get_tree().create_timer(0.50).timeout
	if not is_inside_tree():
		return
	_demo_apply_smart_rations()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_DILEMMA, true)
	_demo_pick_best_event_choice()
	await get_tree().create_timer(0.60).timeout
	if not is_inside_tree():
		return

	# Switch to Real-World OSM Expedition Map & visibly pick Explorer + Suitcase + Gas Mask + Map + Grocery/Church!
	_switch_tab(TAB_EXPEDITION, true)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_demo_pick_best_osm_grocery_or_church()
	_rebuild_tab_expedition()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_demo_pack_expedition_gear()
	_rebuild_tab_expedition()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_expedition_scheduled = true
	SoundManager.play_sfx("button_click")
	_rebuild_tab_expedition()
	_refresh_tab_headers_and_footer()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	# End Day 1 -> Day 2
	await _wait_cinematic_idle()
	_on_end_day_pressed()
	await _wait_for_day_curtain()
	await _wait_cinematic_idle()
	if not is_inside_tree():
		return

	# --- DAY 2: Daily Report -> Live Expedition Tracker -> Rations -> Event Dilemma -> End Day 2 ---
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_EXPEDITION, true)
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_RATIONS, true)
	_demo_apply_smart_rations()
	await get_tree().create_timer(0.60).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_DILEMMA, true)
	_demo_pick_best_event_choice()
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree():
		return

	# End Day 2 -> Day 3
	await _wait_cinematic_idle()
	_on_end_day_pressed()
	await _wait_for_day_curtain()
	await _wait_cinematic_idle()
	if not is_inside_tree():
		return

	# --- DAY 3: Daily Report -> Rations -> Event Dilemma -> End Day 3 (Explorer returns by Day 3/4!) ---
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_RATIONS, true)
	_demo_apply_smart_rations()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_DILEMMA, true)
	_demo_pick_best_event_choice()
	await get_tree().create_timer(0.70).timeout
	if not is_inside_tree():
		return

	# End Day 3 -> Day 4
	await _wait_cinematic_idle()
	_on_end_day_pressed()
	await _wait_for_day_curtain()
	await _wait_cinematic_idle()
	if not is_inside_tree():
		return

	# --- DAY 4: Show Explorer Return Log + Restocked Bunker Shelves & Reunited Family! ---
	_switch_tab(TAB_LOG, false)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return

	# Briefly minimize Notebook to admire restocked Soup/Water/Medkit shelves & reunited family, then show Day 4 Log
	_set_notebook_open(false)
	await get_tree().create_timer(0.95).timeout
	if not is_inside_tree():
		return
	_set_notebook_open(true)
	_switch_tab(TAB_LOG, true)

	_demo_finished = true
	BunkerScene.demo_completed_flag = true
	demo_sequence_completed.emit()

	var all_cli_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var quit_on_complete: bool = all_cli_args.has("--demo-quit-on-complete")

	if quit_on_complete:
		await get_tree().create_timer(1.75).timeout
		if not is_inside_tree():
			return
		SoundManager.shutdown_audio()
		await get_tree().create_timer(0.25).timeout
		if is_inside_tree():
			get_tree().quit()
	elif GameState.game_over:
		await get_tree().create_timer(1.5).timeout
		if is_inside_tree():
			GameState.request_screen(GameState.SCREEN_SUMMARY)

func _wait_for_day_curtain() -> void:
	while is_inside_tree() and _in_day_transition:
		await get_tree().process_frame

func _demo_pick_best_osm_grocery_or_church() -> void:
	_available_targets = ExpeditionEngine.get_available_targets()
	var best_idx: int = 0
	var best_score: float = -999.0
	for i in range(_available_targets.size()):
		var td: Dictionary = _available_targets[i]
		var cat: String = str(td.get("category", "")).to_lower()
		var t_days: int = int(td.get("travel_days", 2))
		var sc: float = 0.0
		if cat == "grocery" or cat == "church":
			sc += 100.0
		elif cat == "pharmacy":
			sc += 65.0
		sc -= float(t_days) * 18.0
		if sc > best_score:
			best_score = sc
			best_idx = i
	_selected_poi_index = best_idx

	# Prefer non-leader healthy adult/teen if available so leader stays in shelter, else leader
	var cands: Array = _get_eligible_explorers()
	for m_v in cands:
		var md: Dictionary = m_v
		if not bool(md.get("is_leader", false)):
			_selected_explorer_id = str(md.get("id", ""))
			return
	if not cands.is_empty():
		_selected_explorer_id = str((cands[0] as Dictionary).get("id", ""))

func _demo_pack_expedition_gear() -> void:
	_selected_gear_ids.clear()
	for pref_id in ["suitcase", "gas_mask", "map"]:
		if GameState.has_working_item(pref_id):
			_toggle_expedition_gear(pref_id)
	SoundManager.play_sfx("button_click")

func _demo_apply_smart_rations() -> void:
	for m_v in GameState.get_living_bunker_members():
		if not (m_v is Dictionary):
			continue
		var m: Dictionary = m_v
		var mid: String = str(m.get("id", ""))
		var h: int = int(m.get("hunger", 0))
		var t: int = int(m.get("thirst", 0))
		var dww: int = int(m.get("days_without_water", 0))
		var dwf: int = int(m.get("days_without_food", 0))
		if (t >= 1 or dww >= 1 or GameState.day == 2) and _get_total_planned_water_q() < GameState.water_quarters:
			_adjust_member_ration(mid, "water_q", 1)
		if (h >= 1 or dwf >= 3 or GameState.day == 3) and _get_total_planned_soup_q() < GameState.soup_quarters:
			_adjust_member_ration(mid, "soup_q", 1)
		if _planned_medkit_member_id == "" and GameState.medkit_count > 0:
			if int(m.get("sickness", 0)) > 0 or int(m.get("injury", 0)) > 0:
				_planned_medkit_member_id = mid
	_rebuild_tab_rations()

func _demo_pick_best_event_choice() -> void:
	# The dilemma is resolved through the cinematic flow; nothing to pick once answered.
	if not _has_unresolved_dilemma:
		return
	var opts: Array = _get_event_options(_current_event)
	if opts.is_empty():
		return
	# Prefer an available item-backed option if owned, otherwise first available option
	var chosen: String = _selected_event_choice_id
	for opt_v in opts:
		if opt_v is Dictionary:
			var od: Dictionary = opt_v
			if _is_event_option_available(od) and str(od.get("item_id", "")) != "":
				chosen = str(od.get("id", ""))
				break
	if chosen == "":
		for opt_v2 in opts:
			if opt_v2 is Dictionary and _is_event_option_available(opt_v2 as Dictionary):
				chosen = str((opt_v2 as Dictionary).get("id", ""))
				break
	_selected_event_choice_id = chosen
	_has_unresolved_dilemma = false
	SoundManager.play_sfx("button_click")
	_rebuild_tab_dilemma()
	_refresh_tab_headers_and_footer()

# ---------------------------------------------------------------------------
# PASS 2: CINEMATIC DAY SEQUENCE (returns → dilemma → animated outcome)
# ---------------------------------------------------------------------------
func _begin_day_sequence() -> void:
	if not is_inside_tree() or not is_instance_valid(_cinematic) or GameState.game_over:
		return
	_day_queue.clear()
	for arr_v in GameState.storage_arrivals:
		_day_queue.append({"type": "return", "arrival": arr_v})
	GameState.storage_arrivals.clear()
	if _has_unresolved_dilemma and not GameState.get_living_bunker_members().is_empty():
		_day_queue.append({"type": "dilemma"})
	_run_day_queue()


func _run_day_queue() -> void:
	if _day_queue.is_empty() or not is_instance_valid(_cinematic):
		return
	if _cinematic.is_busy():
		return
	var step: Dictionary = _day_queue.pop_front()
	match str(step.get("type", "")):
		"return":
			var arr: Dictionary = step["arrival"]
			var explorer: Dictionary = _member_by_id(str(arr.get("member_id", "")))
			if explorer.is_empty():
				_run_day_queue()
				return
			_cinematic.play_return(arr, explorer)
		"dilemma":
			if not _has_unresolved_dilemma:
				_run_day_queue()
				return
			_dilemma_actor = _member_by_id(str((_current_event.get("context", {}) as Dictionary).get("actor_id", "")))
			if _dilemma_actor.is_empty() or not bool(_dilemma_actor.get("alive", true)):
				_dilemma_actor = EventDeck.pick_actor()
			var opts_out: Array = []
			for o_v in _get_event_options(_current_event):
				if not (o_v is Dictionary):
					continue
				var o: Dictionary = o_v
				var req: String = str(o.get("item_id", o.get("required_item", "")))
				var avail: bool = _is_event_option_available(o)
				var status: String = ""
				if req != "":
					var nm: String = str(ItemDB.get_item_info(req).get("short_name", req))
					status = ("uses " + nm) if avail else (nm + (" (broken)" if _is_item_owned_but_broken(req) else " (missing)"))
				opts_out.append({"id": str(o.get("id", "")), "label": _strip_md(str(o.get("label", o.get("text", "")))), "available": avail, "status": status})
			_cinematic.show_dilemma(_current_event, opts_out, _dilemma_actor)
			if GameState.demo_mode or GameState.headless_fast_test:
				get_tree().create_timer(0.9).timeout.connect(func() -> void:
					if is_inside_tree() and _has_unresolved_dilemma:
						_on_dilemma_choice(_auto_choice_id())
				)


func _auto_choice_id() -> String:
	var opts: Array = _get_event_options(_current_event)
	for opt_v in opts:
		if opt_v is Dictionary and _is_event_option_available(opt_v as Dictionary) and str((opt_v as Dictionary).get("item_id", "")) != "":
			return str((opt_v as Dictionary).get("id", ""))
	for opt_v2 in opts:
		if opt_v2 is Dictionary and _is_event_option_available(opt_v2 as Dictionary):
			return str((opt_v2 as Dictionary).get("id", ""))
	return ""


func _on_dilemma_choice(choice_id: String) -> void:
	if not _has_unresolved_dilemma or choice_id == "":
		return
	_selected_event_choice_id = choice_id
	_has_unresolved_dilemma = false
	_resolved_outcome = EventDeck.resolve_event(_current_event, choice_id, GameState.rng)
	var journal_line: String = "%s — %s" % [_strip_md(str(_current_event.get("title", "Dilemma"))), _strip_md(str(_resolved_outcome.get("outcome_text", "")))]
	GameState.daily_log_entries.append({"day": GameState.day, "title": "DAY %d — DECISION (%s)" % [GameState.day, str(_resolved_outcome.get("actor_name", ""))], "lines": [journal_line]})
	_cinematic.play_outcome(_resolved_outcome, _current_event)
	_rebuild_all_tabs()
	_refresh_tab_headers_and_footer()
	if is_instance_valid(_hud_bar):
		_hud_bar.queue_redraw()
	if is_instance_valid(_backdrop):
		_backdrop.refresh_bunker()


func _on_cinematic_finished(kind: String) -> void:
	_rebuild_all_tabs()
	_refresh_tab_headers_and_footer()
	if is_instance_valid(_backdrop):
		_backdrop.refresh_bunker()
	if is_instance_valid(_hud_bar):
		_hud_bar.queue_redraw()
	if kind == "drive":
		GameState.request_screen(GameState.SCREEN_SUMMARY)
		return
	if kind == "outcome":
		var tags: Array = _resolved_outcome.get("tags", [])
		if (tags.has("victory") or tags.has("gameover")) and not GameState.demo_mode:
			call_deferred("_on_end_day_pressed")
			return
	if kind == "install" and is_instance_valid(_garage):
		_garage.show_view()
	_run_day_queue()


func _member_by_id(mid: String) -> Dictionary:
	for m_v in GameState.family_members:
		if m_v is Dictionary and str((m_v as Dictionary).get("id", "")) == mid:
			return m_v
	return {}


# ---------------------------------------------------------------------------
# PASS 2: GARAGE & BIG MAP
# ---------------------------------------------------------------------------
func _open_garage() -> void:
	if is_instance_valid(_cinematic) and _cinematic.is_busy():
		return
	_garage.show_view()


func _on_install_requested(part: String) -> void:
	var before: Dictionary = GameState.vehicle.duplicate(true)
	var res: Dictionary = VehicleSystem.install(part)
	if not bool(res.get("ok", false)):
		_garage.refresh()
		return
	res["vehicle_before"] = before
	_garage.visible = false
	_cinematic.play_install(res)


func _on_drive_requested() -> void:
	var res: Dictionary = VehicleSystem.drive_out()
	if not bool(res.get("ok", false)):
		_garage.refresh()
		return
	_garage.visible = false
	_cinematic.play_drive_out(str(res.get("text", "")))


func _build_map_overlay() -> void:
	_map_overlay = Control.new()
	_map_overlay.name = "NeighborhoodMap"
	_map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_overlay.visible = false
	add_child(_map_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.05, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.add_child(bg)
	_big_map = ShelterMapView.new()
	_big_map.position = Vector2(20, 52)
	_big_map.size = Vector2(1240, 650)
	_big_map.show_controls = true
	_big_map.target_clicked.connect(func(idx: int) -> void:
		SoundManager.play_sfx("button_click")
		_selected_poi_index = idx
		_big_map.selected_index = idx
		_big_map.queue_redraw()
		_rebuild_tab_expedition()
	)
	_map_overlay.add_child(_big_map)
	var title := _make_ink_label("NEIGHBOURHOOD MAP — %s (OpenStreetMap data; click a place to plan an expedition)" % LocationText.area_header(), 16, Color("#f2b82e"))
	title.position = Vector2(24, 14)
	title.size = Vector2(1000, 26)
	_map_overlay.add_child(title)
	var close := Button.new()
	close.text = "CLOSE MAP  [ESC]"
	close.position = Vector2(1080, 10)
	close.size = Vector2(180, 34)
	close.focus_mode = Control.FOCUS_NONE
	_style_conelrad_button(close, COL_STAMP_RED, COL_INK, Color("#fff3db"))
	close.pressed.connect(func() -> void:
		SoundManager.play_sfx("page_turn")
		_map_overlay.visible = false
		_switch_tab(TAB_EXPEDITION, false)
	)
	_map_overlay.add_child(close)


func _open_map_overlay() -> void:
	if is_instance_valid(_cinematic) and _cinematic.is_busy():
		return
	_big_map.targets = _available_targets
	_big_map.selected_index = _selected_poi_index
	_map_overlay.visible = true
	_big_map.queue_redraw()

# ---------------------------------------------------------------------------
# SHARED HELPERS & UI FACTORIES
# ---------------------------------------------------------------------------
func _get_total_planned_soup_q() -> int:
	var total: int = 0
	for k in _planned_rations.keys():
		var d: Dictionary = _planned_rations[k]
		total += int(d.get("soup_q", 0))
	return total

func _get_total_planned_water_q() -> int:
	var total: int = 0
	for k in _planned_rations.keys():
		var d: Dictionary = _planned_rations[k]
		total += int(d.get("water_q", 0))
	return total

func _get_eligible_explorers() -> Array:
	var healthy: Array = []
	var fallback_adults: Array = []
	for m_v in GameState.get_living_bunker_members():
		if not (m_v is Dictionary):
			continue
		var m: Dictionary = m_v
		var role: String = str(m.get("role", "adult")).to_lower()
		var age_v: int = int(m.get("age", 30))
		if role == "child" and age_v < 13:
			continue
		fallback_adults.append(m)
		var severe_sick: bool = int(m.get("sickness", 0)) >= 3 or int(m.get("injury", 0)) >= 3
		if not severe_sick:
			healthy.append(m)
	return healthy if not healthy.is_empty() else fallback_adults

func _ensure_valid_explorer_selected() -> void:
	var cands: Array = _get_eligible_explorers()
	for m_v in cands:
		if str((m_v as Dictionary).get("id", "")) == _selected_explorer_id:
			return
	_selected_explorer_id = str((cands[0] as Dictionary).get("id", "")) if not cands.is_empty() else ""

func _find_member_by_id(member_id: String) -> Dictionary:
	for m_v in GameState.family_members:
		if m_v is Dictionary:
			var md: Dictionary = m_v
			if str(md.get("id", "")) == member_id:
				return md
	return {}

func _get_event_options(ev: Dictionary) -> Array:
	if ev.has("options") and ev["options"] is Array:
		return ev["options"] as Array
	if ev.has("choices") and ev["choices"] is Array:
		return ev["choices"] as Array
	return []

func _is_event_option_available(opt: Dictionary) -> bool:
	if opt.has("available"):
		return bool(opt.get("available", true))
	var req: String = str(opt.get("item_id", opt.get("required_item", "")))
	if req == "":
		return true
	return GameState.has_working_item(req)

func _is_item_owned_but_broken(item_id: String) -> bool:
	if GameState.bunker_items.has(item_id):
		var d: Dictionary = GameState.bunker_items[item_id]
		return bool(d.get("owned", false)) and bool(d.get("broken", false))
	return false

func _short_category_tag(cat: String) -> String:
	var c: String = cat.to_lower()
	if c.contains("church"):
		return "CHURCH"
	if c.contains("groc") or c.contains("super") or c.contains("market"):
		return "GROCERY"
	if c.contains("pharm") or c.contains("med") or c.contains("clin"):
		return "PHARMACY"
	if c.contains("hard") or c.contains("civic"):
		return "HARDWARE"
	if c.contains("school") or c.contains("lib"):
		return "SCHOOL"
	if c.contains("rest") or c.contains("cafe"):
		return "DINER"
	return "HOUSE"

func _get_hunger_status(member: Dictionary) -> Dictionary:
	var h: int = int(member.get("hunger", 0))
	var dwf: int = int(member.get("days_without_food", 0))
	if h == 0 and dwf < 3:
		return {"text": "Full", "color": COL_GREEN}
	if (h <= 10 and h == 1) or (h > 10 and h < 50) or (h == 0 and dwf >= 3):
		return {"text": "Hungry", "color": Color("#b87c14")}
	if (h <= 10 and h == 2) or (h >= 50 and h < 80):
		return {"text": "Very Hungry", "color": COL_ORANGE}
	return {"text": "Starving!", "color": COL_STAMP_RED}

func _get_thirst_status(member: Dictionary) -> Dictionary:
	var t: int = int(member.get("thirst", 0))
	var dww: int = int(member.get("days_without_water", 0))
	if t == 0 and dww < 2:
		return {"text": "Hydrated", "color": COL_WATER}
	if (t <= 10 and t == 1) or (t > 10 and t < 50) or (t == 0 and dww >= 2):
		return {"text": "Thirsty", "color": Color("#b87c14")}
	if (t <= 10 and t == 2) or (t >= 50 and t < 80):
		return {"text": "Dehydrated", "color": COL_ORANGE}
	return {"text": "Parched!", "color": COL_STAMP_RED}

func _summarize_member_quick_badge(member: Dictionary) -> Dictionary:
	if not bool(member.get("in_bunker", false)):
		return {"text": "LEFT BEHIND", "color": COL_INK_MUTED}
	if not bool(member.get("alive", true)):
		return {"text": "FALLEN", "color": COL_STAMP_RED}
	if bool(member.get("on_expedition", false)):
		return {"text": "SCAVENGING", "color": COL_WATER}
	if bool(member.get("is_mutant", false)):
		return {"text": "MUTANT", "color": COL_GREEN}
	if int(member.get("injury", 0)) > 0:
		return {"text": "INJURED", "color": COL_STAMP_RED}
	if int(member.get("sickness", 0)) > 0:
		return {"text": "SICK", "color": COL_ORANGE}
	var san: int = int(member.get("sanity", 0))
	if (_sanity_hundred_scale and san <= 35) or (not _sanity_hundred_scale and san >= 2):
		return {"text": "CRAZY", "color": Color("#7d389c")}
	var t_st: Dictionary = _get_thirst_status(member)
	if str(t_st["text"]) != "Hydrated":
		return {"text": str(t_st["text"]).to_upper(), "color": t_st["color"]}
	var h_st: Dictionary = _get_hunger_status(member)
	if str(h_st["text"]) != "Full":
		return {"text": str(h_st["text"]).to_upper(), "color": h_st["color"]}
	return {"text": "HEALTHY", "color": COL_GREEN}

func _make_ink_label(text_val: String, font_sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	return lbl

func _make_status_pill(text_val: String, bg_col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = COL_INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	pc.add_theme_stylebox_override("panel", sb)
	var lbl := _make_ink_label(text_val, 10, Color("#fffaf0"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(lbl)
	return pc

func _make_parchment_card(min_sz: Vector2, fill_col: Color, border_col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	pc.add_theme_stylebox_override("panel", sb)
	return pc

func _make_supply_counter_widget(item_id: String, label_txt: String, accent: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 6)
	var ic := _ItemIconWidget.new()
	ic.item_id = item_id
	ic.custom_minimum_size = Vector2(34.0, 34.0)
	hb.add_child(ic)
	var lbl := _make_ink_label(label_txt, 13, accent)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(lbl)
	return hb

func _style_conelrad_button(btn: Button, bg: Color, border: Color, fg: Color) -> void:
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.08) if state_name == "hover" else (bg.darkened(0.10) if state_name == "pressed" else bg)
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		btn.add_theme_stylebox_override(state_name, sb)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg.lightened(0.12))
	btn.add_theme_color_override("font_pressed_color", COL_HAZARD)
	btn.add_theme_color_override("font_focus_color", fg)

func _style_notebook_ink_button(btn: Button, bg: Color, border: Color, fg: Color) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.05) if state_name == "hover" else (bg.darkened(0.06) if state_name == "pressed" else bg)
		sb.border_color = border
		sb.set_border_width_all(2 if state_name == "hover" else 1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		btn.add_theme_stylebox_override(state_name, sb)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", COL_INK)
	btn.add_theme_color_override("font_pressed_color", COL_STAMP_RED)
	btn.add_theme_color_override("font_focus_color", fg)
	btn.add_theme_color_override("font_disabled_color", COL_INK_MUTED)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

# ===========================================================================
# INNER VISUAL WIDGETS
# ===========================================================================

class _TopHudBar extends Control:
	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(0.0, 0.0, 1280.0, 52.0), Color("#171a17"), true)
		draw_line(Vector2(0.0, 51.0), Vector2(1280.0, 51.0), Color("#f2b82e"), 2.0)

		# 1. DAY <N> Stencil Badge
		var day_r := Rect2(12.0, 8.0, 102.0, 36.0)
		draw_rect(day_r, Color("#f2b82e"), true)
		draw_rect(day_r, Color("#1b1917"), false, 2.0)
		draw_string(font, day_r.position + Vector2(0.0, 24.0), "DAY %d" % GameState.day, HORIZONTAL_ALIGNMENT_CENTER, day_r.size.x, 17, Color("#1b1917"))

		# 2. House Address Badge
		var house_r := Rect2(122.0, 8.0, 294.0, 36.0)
		draw_rect(house_r, Color("#242a24"), true)
		draw_rect(house_r, Color("#565f55"), false, 1.5)
		var h_name: String = LocationText.home_label()
		draw_string(font, house_r.position + Vector2(10.0, 23.0), "SHELTER: " + h_name, HORIZONTAL_ALIGNMENT_LEFT, house_r.size.x - 16.0, 13, Color("#f2e6ce"))

		# 3. Radiation Sv/hr Badge
		var rad_r := Rect2(424.0, 8.0, 134.0, 36.0)
		var sv: float = GameState.surface_radiation_sv
		var sv_col := Color("#7ec850") if sv < 2.0 else (Color("#f2b82e") if sv < 5.5 else Color("#e05a2b"))
		draw_rect(rad_r, Color("#242a24"), true)
		draw_rect(rad_r, sv_col, false, 1.5)
		draw_string(font, rad_r.position + Vector2(0.0, 23.0), "OUT: %s" % RadiationModel.format_rate(sv * 1000.0), HORIZONTAL_ALIGNMENT_CENTER, rad_r.size.x, 13, sv_col)

		# 4. Bunker Temp Badge
		var tmp_r := Rect2(566.0, 8.0, 108.0, 36.0)
		var tc: float = GameState.bunker_temp_c
		var tc_col := Color("#8ad8ff") if tc < 2.0 else (Color("#f2e6ce") if tc <= 28.0 else Color("#e05a2b"))
		draw_rect(tmp_r, Color("#242a24"), true)
		draw_rect(tmp_r, tc_col, false, 1.5)
		draw_string(font, tmp_r.position + Vector2(0.0, 23.0), "TEMP: %.0f°C" % tc, HORIZONTAL_ALIGNMENT_CENTER, tmp_r.size.x, 13, tc_col)

		# 5. Soup Count Badge
		var soup_r := Rect2(682.0, 8.0, 144.0, 36.0)
		draw_rect(soup_r, Color("#242a24"), true)
		draw_rect(soup_r, Color("#e05a2b"), false, 1.5)
		ItemDB.draw_item_icon(self, "soup", soup_r.position + Vector2(20.0, 18.0), 24.0, false)
		draw_string(font, soup_r.position + Vector2(38.0, 23.0), "Soup: %s" % GameState.format_quarters_as_cans(GameState.soup_quarters), HORIZONTAL_ALIGNMENT_LEFT, 100.0, 13, Color("#f2e6ce"))

		# 6. Water Count Badge
		var wat_r := Rect2(834.0, 8.0, 144.0, 36.0)
		draw_rect(wat_r, Color("#242a24"), true)
		draw_rect(wat_r, Color("#3b8ec2"), false, 1.5)
		ItemDB.draw_item_icon(self, "water", wat_r.position + Vector2(20.0, 18.0), 24.0, false)
		draw_string(font, wat_r.position + Vector2(38.0, 23.0), "Water: %s" % GameState.format_quarters_as_cans(GameState.water_quarters), HORIZONTAL_ALIGNMENT_LEFT, 100.0, 13, Color("#f2e6ce"))

class _NotebookBackdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Outer leather cover & drop shadow
		draw_rect(Rect2(6.0, 8.0, size.x + 4.0, size.y + 4.0), Color(0.04, 0.04, 0.03, 0.65), true)
		draw_rect(Rect2(-4.0, -2.0, size.x + 10.0, size.y + 8.0), Color("#2c261e"), true)
		draw_rect(Rect2(-4.0, -2.0, size.x + 10.0, size.y + 8.0), Color("#1b1917"), false, 2.5)

		# Stacked right/bottom paper edges
		draw_rect(Rect2(4.0, 4.0, size.x, size.y), Color("#cbb993"), true)
		draw_rect(Rect2(2.0, 2.0, size.x, size.y), Color("#dfd0ae"), true)

		# Main warm parchment sheet (#efe3c8)
		var page_r := Rect2(0.0, 0.0, size.x, size.y)
		draw_rect(page_r, Color("#efe3c8"), true)
		draw_rect(page_r, Color("#1d1a16"), false, 2.2)

		# Faint horizontal notebook ruled lines & red margin stripe
		for ly in range(44, int(size.y) - 58, 24):
			draw_line(Vector2(28.0, float(ly)), Vector2(size.x - 14.0, float(ly)), Color(0.55, 0.49, 0.38, 0.22), 1.0)
		draw_line(Vector2(30.0, 10.0), Vector2(30.0, size.y - 10.0), Color(0.76, 0.30, 0.24, 0.35), 1.4)
		draw_line(Vector2(34.0, 498.0), Vector2(size.x - 14.0, 498.0), Color(0.18, 0.15, 0.12, 0.45), 1.5)

		# 14 Metallic Spiral Binding Rings along the left edge
		for ri in range(14):
			var ry: float = 22.0 + float(ri) * 38.5
			draw_circle(Vector2(14.0, ry), 5.0, Color("#1d1a16"))
			draw_arc(Vector2(2.0, ry), 13.0, -PI * 0.46, PI * 0.46, 14, Color("#7a807a"), 4.2)
			draw_arc(Vector2(2.0, ry - 1.2), 13.0, -PI * 0.40, PI * 0.36, 12, Color("#d8ded6"), 1.6)
			draw_rect(Rect2(-10.0, ry - 3.0, 14.0, 6.0), Color("#9ca39c"), true)
			draw_rect(Rect2(-10.0, ry - 3.0, 14.0, 6.0), Color("#1d1a16"), false, 1.2)

class _NotebookTabButton extends Button:
	var tab_title: String = "TAB"
	var is_active_tab: bool = false
	var badge_text: String = ""
	var badge_color: Color = Color("#d94c2a")

	func _init() -> void:
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var fill := Color("#efe3c8") if is_active_tab else Color("#cbb892")
		var poly := PackedVector2Array([
			Vector2(0.0, size.y),
			Vector2(6.0, 2.0),
			Vector2(size.x - 6.0, 2.0),
			Vector2(size.x, size.y)
		])
		draw_colored_polygon(poly, fill)
		if is_active_tab:
			draw_line(Vector2(6.0, 3.0), Vector2(size.x - 6.0, 3.0), Color("#f2b82e"), 4.0)
			draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3]]), Color("#1d1a16"), 2.2)
		else:
			draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color("#1d1a16"), 1.8)

		draw_string(
			font,
			Vector2(0.0, 21.0),
			tab_title,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x - (24.0 if badge_text != "" else 0.0),
			12,
			Color("#1d1a16")
		)

		if badge_text != "":
			var br := Rect2(size.x - 34.0, 7.0, 26.0, 16.0)
			draw_rect(br, badge_color, true)
			draw_rect(br, Color("#1d1a16"), false, 1.2)
			draw_string(font, br.position + Vector2(0.0, 12.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 9, Color("#fff8e8"))

class _MemberPortraitWidget extends Control:
	var member_data: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not member_data.is_empty():
			CharacterArtist.draw_portrait(self, Rect2(Vector2.ZERO, size), member_data, true)

class _ItemIconWidget extends Control:
	var item_id: String = "soup"
	var is_broken: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dim: float = minf(size.x, size.y) * 0.88
		ItemDB.draw_item_icon(self, item_id, size * 0.5, dim, is_broken)

class _ExpeditionRadarMap extends Control:
	signal target_clicked(poi_index: int)

	var targets: Array = []
	var selected_index: int = 0
	var active_expedition_mode: bool = false
	var route_progress: float = 0.5
	var _sweep_angle: float = 0.0
	var _hovered_idx: int = -1
	var _pin_positions: Array[Vector2] = []

	func _process(delta: float) -> void:
		_sweep_angle = fposmod(_sweep_angle + delta * 1.35, TAU)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event
			_hovered_idx = _pick_pin(mm.position)
		elif event is InputEventMouseButton and not active_expedition_mode:
			var mb: InputEventMouseButton = event
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var hit: int = _pick_pin(mb.position)
				if hit >= 0:
					selected_index = hit
					target_clicked.emit(hit)

	func _pick_pin(pt: Vector2) -> int:
		var best: int = -1
		var best_d: float = 16.0
		for i in range(_pin_positions.size()):
			var d: float = _pin_positions[i].distance_to(pt)
			if d < best_d:
				best_d = d
				best = i
		return best

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("#152018"), true)
		draw_rect(rect, Color("#1d1a16"), false, 2.2)

		var center := Vector2(size.x * 0.5, size.y * 0.52)
		var max_r: float = minf(size.x, size.y) * 0.41

		# Radar grid & concentric meter rings
		for rf in [0.35, 0.68, 1.0]:
			draw_arc(center, max_r * rf, 0.0, TAU, 40, Color(0.45, 0.78, 0.42, 0.24), 1.2)
		draw_line(Vector2(8.0, center.y), Vector2(size.x - 8.0, center.y), Color(0.45, 0.78, 0.42, 0.20), 1.0)
		draw_line(Vector2(center.x, 22.0), Vector2(center.x, size.y - 10.0), Color(0.45, 0.78, 0.42, 0.20), 1.0)

		# Rotating phosphor radar sweep line
		var sweep_tip := center + Vector2(cos(_sweep_angle), sin(_sweep_angle)) * max_r
		draw_line(center, sweep_tip, Color(0.55, 0.95, 0.48, 0.35), 2.0)

		# Top banner
		draw_rect(Rect2(0.0, 0.0, size.x, 20.0), Color("#1d1a16"), true)
		var map_hdr: String = "OSM MAP — " + LocationText.home_label()
		draw_string(font, Vector2(6.0, 14.0), map_hdr, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 10, Color("#f2b82e"))

		# Compute real-world relative (lat, lon) meter offsets
		var h_lat: float = float(GameState.selected_house.get("lat", 47.6242))
		var h_lon: float = float(GameState.selected_house.get("lon", -122.3195))
		var cos_lat: float = maxf(0.25, cos(deg_to_rad(h_lat)))

		var offsets_m: Array[Vector2] = []
		var max_dist_m: float = 220.0
		for i in range(targets.size()):
			var td: Dictionary = targets[i]
			var dx_m: float = 0.0
			var dy_m: float = 0.0
			if td.has("lat") and td.has("lon"):
				dx_m = (float(td.get("lon", h_lon)) - h_lon) * 111320.0 * cos_lat
				dy_m = -(float(td.get("lat", h_lat)) - h_lat) * 111320.0
			else:
				var ang_fb: float = float(i) * 0.95
				var dm_fb: float = float(td.get("distance_m", 180.0))
				dx_m = cos(ang_fb) * dm_fb
				dy_m = sin(ang_fb) * dm_fb
			var v := Vector2(dx_m, dy_m)
			offsets_m.append(v)
			max_dist_m = maxf(max_dist_m, v.length())

		_pin_positions.clear()
		var min_inner_r: float = 24.0
		var outer_r: float = maxf(min_inner_r + 8.0, max_r * 0.90)
		for i in range(offsets_m.size()):
			var v: Vector2 = offsets_m[i]
			var dist_m: float = v.length()
			var dir: Vector2 = (v / dist_m) if dist_m > 0.001 else Vector2(cos(float(i) * 0.95), sin(float(i) * 0.95))
			var radial_u: float = sqrt(clampf(dist_m / max_dist_m, 0.06, 1.0))
			var r_px: float = maxf(min_inner_r, radial_u * outer_r)
			var pt: Vector2 = center + dir * r_px
			pt.x = clampf(pt.x, 16.0, size.x - 16.0)
			pt.y = clampf(pt.y, 30.0, size.y - 32.0)
			_pin_positions.append(pt)

		# 2 passes of pairwise pin separation (min_sep = 15.0 px) while keeping >= 24px clear of shelter icon
		var min_sep: float = 15.0
		for _pass_idx in range(2):
			for i in range(_pin_positions.size()):
				for j in range(i + 1, _pin_positions.size()):
					var delta_v: Vector2 = _pin_positions[j] - _pin_positions[i]
					var d: float = delta_v.length()
					if d < min_sep:
						var push_dir: Vector2 = (delta_v / d) if d > 0.001 else Vector2(cos(float(i + j) * 1.1), sin(float(i + j) * 1.1))
						var push: Vector2 = push_dir * ((min_sep - d) * 0.5)
						_pin_positions[i] -= push
						_pin_positions[j] += push
			for i in range(_pin_positions.size()):
				var from_c: Vector2 = _pin_positions[i] - center
				var dc: float = from_c.length()
				if dc < min_inner_r:
					var c_dir: Vector2 = (from_c / dc) if dc > 0.001 else Vector2(cos(float(i) * 0.95), sin(float(i) * 0.95))
					_pin_positions[i] = center + c_dir * min_inner_r
				_pin_positions[i].x = clampf(_pin_positions[i].x, 16.0, size.x - 16.0)
				_pin_positions[i].y = clampf(_pin_positions[i].y, 30.0, size.y - 32.0)

		# Draw bearing line to selected target
		if selected_index >= 0 and selected_index < _pin_positions.size():
			var sel_pt: Vector2 = _pin_positions[selected_index]
			draw_line(center, sel_pt, Color("#f2b82e"), 2.0)
			if active_expedition_mode:
				var beacon: Vector2 = center.lerp(sel_pt, route_progress)
				var pulse_r: float = 6.0 + sin(_sweep_angle * 3.0) * 2.5
				draw_circle(beacon, pulse_r + 3.0, Color(0.23, 0.72, 0.98, 0.32))
				draw_circle(beacon, 5.0, Color("#7fd0f5"))
				draw_arc(beacon, 5.0, 0.0, TAU, 14, Color("#1d1a16"), 1.5)

		# Draw Home Shelter at center
		draw_circle(center, 9.0, Color("#e05a2b"))
		draw_arc(center, 9.0, 0.0, TAU, 18, Color("#f2b82e"), 2.0)
		var tri := PackedVector2Array([
			center + Vector2(0.0, -5.0),
			center + Vector2(5.0, 4.0),
			center + Vector2(-5.0, 4.0)
		])
		draw_colored_polygon(tri, Color("#fff6de"))

		# Draw non-selected pins first, then selected pin on top for crisp visibility
		for i in range(targets.size()):
			if i == selected_index:
				continue
			var td: Dictionary = targets[i]
			var pt: Vector2 = _pin_positions[i]
			var cat: String = str(td.get("category", "house")).to_lower()
			_draw_category_pin(pt, cat, false, i == _hovered_idx)
		if selected_index >= 0 and selected_index < targets.size():
			var sel_td: Dictionary = targets[selected_index]
			var sel_cat: String = str(sel_td.get("category", "house")).to_lower()
			_draw_category_pin(_pin_positions[selected_index], sel_cat, true, selected_index == _hovered_idx)

		# Caption bar at bottom showing hovered or selected landmark name
		var label_idx: int = _hovered_idx if _hovered_idx >= 0 else selected_index
		if label_idx >= 0 and label_idx < targets.size():
			var lt: Dictionary = targets[label_idx]
			var cap_r := Rect2(4.0, size.y - 22.0, size.x - 8.0, 18.0)
			draw_rect(cap_r, Color(0.08, 0.10, 0.08, 0.88), true)
			var cap_s: String = "%s (%dm)" % [str(lt.get("name", "Landmark")), int(lt.get("distance_m", 150))]
			draw_string(font, cap_r.position + Vector2(6.0, 13.0), cap_s, HORIZONTAL_ALIGNMENT_LEFT, cap_r.size.x - 12.0, 10, Color("#f2e6ce"))

	func _draw_category_pin(pt: Vector2, cat: String, is_sel: bool, is_hov: bool) -> void:
		var col := Color("#cfc2a5")
		if cat.contains("church"):
			col = Color("#f5d451")
		elif cat.contains("groc") or cat.contains("super") or cat.contains("market"):
			col = Color("#7ec850")
		elif cat.contains("pharm") or cat.contains("med"):
			col = Color("#f05a5a")
		elif cat.contains("hard") or cat.contains("civic"):
			col = Color("#e89238")
		elif cat.contains("school") or cat.contains("lib"):
			col = Color("#6cb8f0")

		if is_sel or is_hov:
			draw_arc(pt, 12.5, 0.0, TAU, 20, Color("#f2b82e") if is_sel else Color("#ffffff"), 2.2)

		draw_circle(pt, 8.0, col)
		draw_arc(pt, 8.0, 0.0, TAU, 16, Color("#1d1a16"), 1.6)

		# Distinct crisp category vector glyph inside pin
		var ink := Color("#1d1a16")
		if cat.contains("church"):
			draw_line(pt + Vector2(0.0, -5.0), pt + Vector2(0.0, 5.0), ink, 2.0)
			draw_line(pt + Vector2(-3.5, -1.5), pt + Vector2(3.5, -1.5), ink, 2.0)
		elif cat.contains("groc") or cat.contains("super") or cat.contains("market"):
			draw_rect(Rect2(pt - Vector2(4.0, 2.0), Vector2(8.0, 5.5)), ink, false, 1.6)
			draw_arc(pt + Vector2(0.0, -2.0), 3.0, PI, TAU, 8, ink, 1.4)
		elif cat.contains("pharm") or cat.contains("med"):
			draw_line(pt + Vector2(0.0, -4.5), pt + Vector2(0.0, 4.5), Color("#ffffff"), 2.4)
			draw_line(pt + Vector2(-4.5, 0.0), pt + Vector2(4.5, 0.0), Color("#ffffff"), 2.4)
		elif cat.contains("hard") or cat.contains("civic"):
			draw_line(pt + Vector2(-3.5, 3.5), pt + Vector2(3.5, -3.5), ink, 2.2)
			draw_circle(pt + Vector2(3.0, -3.0), 2.0, ink)
		elif cat.contains("school") or cat.contains("lib"):
			draw_rect(Rect2(pt - Vector2(4.0, 3.5), Vector2(8.0, 7.0)), ink, false, 1.5)
			draw_line(pt + Vector2(0.0, -3.5), pt + Vector2(0.0, 3.5), ink, 1.3)
		else:
			var roof := PackedVector2Array([pt + Vector2(0.0, -4.5), pt + Vector2(4.5, 0.5), pt + Vector2(-4.5, 0.5)])
			draw_colored_polygon(roof, ink)
			draw_rect(Rect2(pt + Vector2(-3.0, 0.5), Vector2(6.0, 3.8)), ink, true)

class _DayCurtainOverlay extends Control:
	var _day_num: int = 2
	var _sub_label: String = ""
	var _progress: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func configure(day_num: int, sub_label: String) -> void:
		_day_num = day_num
		_sub_label = sub_label
		queue_redraw()

	func set_progress(p: float) -> void:
		_progress = clampf(p, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var alpha: float = 1.0
		if _progress < 0.28:
			alpha = _progress / 0.28
		elif _progress > 0.74:
			alpha = (1.0 - _progress) / 0.26
		alpha = clampf(alpha, 0.0, 1.0)

		draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.05, 0.05, 0.04, alpha), true)

		var c := Vector2(640.0, 340.0)
		draw_circle(c + Vector2(0.0, -56.0), 34.0, Color(0.95, 0.72, 0.18, alpha))
		var tri := PackedVector2Array([
			c + Vector2(0.0, -82.0),
			c + Vector2(24.0, -40.0),
			c + Vector2(-24.0, -40.0)
		])
		draw_colored_polygon(tri, Color(0.10, 0.10, 0.09, alpha))

		draw_string(font, Vector2(0.0, 358.0), "DAY %d" % _day_num, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 56, Color(0.95, 0.90, 0.78, alpha))
		draw_string(font, Vector2(0.0, 396.0), _sub_label.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 16, Color(0.95, 0.72, 0.18, alpha * 0.9))
