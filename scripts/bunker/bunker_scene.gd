class_name BunkerScene
extends Control

## Main Bunker Survival Controller (V2 Shelter Overhaul):
## - Top Civil Defense HUD with [ SAVE ] Quick Button & Achievement Unlocked Toast Banner
## - 5-Tab Flipbook Survival Notebook (740x560):
##   1. LOG: Daily narrative log, survivor relationship pills, [ SAVE SHELTER ] & [ SAVE & EXIT TO TITLE ]
##   2. CARE & BONDS: 1/4 Soup & Water steppers, [ Medkit ], [ Antibiotics ], [ Anti-Rad ], & Family Relationship Strip
##   3. DILEMMA: Scrollable dilemma choices with specialty item icons & [COOPERATE] bond badges
##   4. OSM RADAR: Multi-Ring (R1 <0.5km, R2 0.5-3.5km, R3 3.5-10km) landmarks, Ring filter chips, 9 category icons & Gameplay Impact
##   5. ESCAPE: 1950s Station Wagon Escape Blueprint, 4 Engine Parts, Fuel Cans, Tune/Scrap actions, 4 Faction Meters & [ IGNITE STATION WAGON — ESCAPE NOW! ]
## - Preserves set_active_tab(0..4), Wave 4 layout clearances, and 4-Day GameState.demo_mode showcase.

signal demo_sequence_completed()

static var demo_completed_flag: bool = false

const TAB_LOG: int = 0
const TAB_RATIONS: int = 1
const TAB_DILEMMA: int = 2
const TAB_EXPEDITION: int = 3
const TAB_ESCAPE: int = 4
const NUM_TABS: int = 5

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
const COL_BOND_PINK := Color("#b83b68")

const EXPEDITION_GEAR_SLOTS: Array[String] = [
	"gas_mask", "rifle", "axe", "flashlight", "map", "suitcase"
]
const MAX_DAILY_RATION_QUARTERS: int = 2

var _backdrop: BunkerBackdrop = null
var _hud_bar: _TopHudBar = null
var _save_hud_btn: Button = null
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

var _toast_overlay: _ToastOverlay = null
var _curtain_overlay: _DayCurtainOverlay = null

# Runtime Notebook & Daily Turn State
var _notebook_open: bool = true
var _current_tab: int = TAB_LOG
var _sanity_hundred_scale: bool = false

# Tab 2: Planned Rations & Specialty Medical Care for current day
var _planned_rations: Dictionary = {} # member_id -> {"soup_q": int, "water_q": int}
var _planned_medkit_member_id: String = ""
var _planned_antibiotics_ids: Array[String] = []
var _planned_antirad_ids: Array[String] = []

# Tab 3: Daily Dilemma State
var _current_event: Dictionary = {}
var _selected_event_choice_id: String = ""
var _has_unresolved_dilemma: bool = false

# Tab 4: Multi-Ring Real-World OSM Expedition State
var _available_targets: Array = []
var _selected_ring_filter: int = 0 # 0=All, 1=R1, 2=R2, 3=R3
var _selected_poi_index: int = 0
var _selected_explorer_id: String = ""
var _selected_gear_ids: Array[String] = []
var _expedition_scheduled: bool = false
var _radar_map_widget: _ExpeditionRadarMap = null

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

	if not GameState.achievement_unlocked.is_connected(_on_achievement_unlocked):
		GameState.achievement_unlocked.connect(_on_achievement_unlocked)

	SoundManager.set_ambience("bunker")
	_initialize_bunker_run_if_needed()
	_detect_sanity_scale()

	# 1. Full-screen Illustrated Bunker Backdrop
	_backdrop = BunkerBackdrop.new()
	_backdrop.name = "BunkerBackdrop"
	add_child(_backdrop)

	# 2. Top Civil Defense HUD Bar (+ [ SAVE ] quick button)
	_build_top_hud()

	# 3. Right/Center 5-Tab Flipbook Survival Notebook (740x560)
	_build_survival_notebook()

	# 4. Minimized Floating Quick-Action Pill (shown when Notebook is minimized)
	_build_minimized_dock()

	# 5. Save & Achievement Toast Overlay (non-blocking)
	_toast_overlay = _ToastOverlay.new()
	_toast_overlay.name = "ToastOverlay"
	add_child(_toast_overlay)

	# 6. Full-Screen Black "DAY <N>" Curtain Overlay
	_curtain_overlay = _DayCurtainOverlay.new()
	_curtain_overlay.name = "DayCurtainOverlay"
	_curtain_overlay.visible = false
	add_child(_curtain_overlay)

	if not GameState.inventory_changed.is_connected(_on_external_state_changed):
		GameState.inventory_changed.connect(_on_external_state_changed)
	if not GameState.family_changed.is_connected(_on_external_state_changed):
		GameState.family_changed.connect(_on_external_state_changed)
	if not GameState.relationships_changed.is_connected(_on_external_state_changed):
		GameState.relationships_changed.connect(_on_external_state_changed)

	_prepare_new_day_turn(true)

	# Unlock Day 1 "first_seal" achievement if entering shelter on Day 1
	if GameState.day == 1 and not GameState.get_all_living_members().is_empty():
		GameState.unlock_achievement("first_seal")

	if GameState.demo_mode:
		_set_notebook_open(false)
		_start_demo_showcase()
	else:
		_set_notebook_open(true)

func set_active_tab(tab_index: int) -> void:
	_switch_tab(clampi(tab_index, 0, NUM_TABS - 1), false)

func set_notebook_visible(open_flag: bool) -> void:
	_set_notebook_open(open_flag)

func _initialize_bunker_run_if_needed() -> void:
	var cli_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var direct_cli_bunker: bool = cli_args.has("--start-screen=bunker")

	if GameState.nearby_pois.is_empty():
		_populate_default_osm_targets_if_empty()

	if direct_cli_bunker and GameState.get_all_living_members().is_empty():
		_seed_direct_bunker_start()

	if GameState.demo_mode and GameState.day <= 1:
		_ensure_demo_bunker_readiness()

	if GameState.day <= 1 and GameState.daily_log_entries.is_empty():
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
				if not bldgs.is_empty() or not pois.is_empty():
					GameState.nearby_pois = OsmService.build_nearby_targets_for_house(GameState.selected_house, bldgs, pois)
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
	if GameState.antibiotics_count <= 0:
		GameState.antibiotics_count = 1
	if GameState.antirad_count <= 0:
		GameState.antirad_count = 1
	if GameState.scrap_count <= 0:
		GameState.scrap_count = 2
	if GameState.bug_spray_count <= 0:
		GameState.bug_spray_count = 1
	if GameState.ammo_count <= 0:
		GameState.ammo_count = 4
	if GameState.fuel_cans <= 0:
		GameState.fuel_cans = 1
	GameState.vehicle_parts["battery"] = true
	GameState.vehicle_parts["radiator_hose"] = true
	GameState.padlock_active = true
	for gid in ["gas_mask", "suitcase", "radio", "map", "flashlight", "axe", "cards", "toolbox"]:
		if GameState.bunker_items.has(gid):
			GameState.bunker_items[gid]["owned"] = true
			GameState.bunker_items[gid]["broken"] = false
			GameState.bunker_items[gid]["count"] = 1
	GameState.has_cat_sharikov = true

func _ensure_demo_bunker_readiness() -> void:
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
	if GameState.antibiotics_count < 1:
		GameState.antibiotics_count = 1
	if GameState.antirad_count < 1:
		GameState.antirad_count = 1
	if GameState.scrap_count < 1:
		GameState.scrap_count = 2
	if GameState.fuel_cans < 1:
		GameState.fuel_cans = 1
	GameState.vehicle_parts["battery"] = true
	GameState.vehicle_parts["radiator_hose"] = true
	for req_id in ["gas_mask", "suitcase", "radio", "map", "toolbox"]:
		if GameState.bunker_items.has(req_id):
			GameState.bunker_items[req_id]["owned"] = true
			GameState.bunker_items[req_id]["broken"] = false
			GameState.bunker_items[req_id]["count"] = maxi(1, int(GameState.bunker_items[req_id].get("count", 1)))

func _append_initial_orientation_log() -> void:
	var h_name: String = str(GameState.selected_house.get("name", "Civil Defense Shelter"))
	var n_target: String = str(GameState.nuke_config.get("target_name", "Downtown Ground Zero"))
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
		"Check 2. CARE & BONDS to ration fairly, 4. OSM RADAR for multi-ring expeditions, or 5. ESCAPE to rebuild the Station Wagon!"
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
	_refresh_tab_headers_and_footer()

func _on_achievement_unlocked(ach_id: String, ach_title: String) -> void:
	var desc_str: String = ""
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		var defs_v: Variant = sm.get("ACHIEVEMENTS_DEF")
		if defs_v is Dictionary and (defs_v as Dictionary).has(ach_id):
			var d_entry: Dictionary = (defs_v as Dictionary)[ach_id]
			desc_str = str(d_entry.get("desc", ""))
			var hat_r: String = str(d_entry.get("unlock_hat", ""))
			if hat_r != "":
				desc_str += " [Unlocked Hat: %s!]" % hat_r.replace("_", " ").capitalize()
	SoundManager.play_sfx("pickup")
	if is_instance_valid(_toast_overlay):
		_toast_overlay.push_achievement_toast(ach_title, desc_str)

func _on_quick_save_pressed() -> void:
	if _in_day_transition:
		return
	SoundManager.play_sfx("button_click")
	var ok: bool = SaveManager.save_run()
	if is_instance_valid(_toast_overlay):
		if ok:
			_toast_overlay.show_status_toast("✓ SHELTER SAVED (DAY %d)" % GameState.day, COL_GREEN)
		else:
			_toast_overlay.show_status_toast("! SAVE FAILED", COL_STAMP_RED)

func _on_save_and_exit_to_title_pressed() -> void:
	if _in_day_transition:
		return
	SoundManager.play_sfx("button_click")
	SaveManager.save_run()
	GameState.request_screen(GameState.SCREEN_TITLE)

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
			elif ke.keycode == KEY_F5:
				_on_quick_save_pressed()
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
# TOP HUD BAR (1280x52) WITH [ SAVE ] QUICK BUTTON
# ---------------------------------------------------------------------------
func _build_top_hud() -> void:
	_hud_bar = _TopHudBar.new()
	_hud_bar.name = "TopHudBar"
	_hud_bar.position = Vector2.ZERO
	_hud_bar.size = Vector2(1280.0, 52.0)
	add_child(_hud_bar)

	_save_hud_btn = Button.new()
	_save_hud_btn.name = "QuickSaveHudButton"
	_save_hud_btn.text = "[ SAVE ]"
	_save_hud_btn.position = Vector2(902.0, 8.0)
	_save_hud_btn.size = Vector2(90.0, 36.0)
	_save_hud_btn.add_theme_font_size_override("font_size", 13)
	_style_conelrad_button(_save_hud_btn, Color("#2b3e29"), COL_GREEN, COL_PARCHMENT)
	_save_hud_btn.pressed.connect(_on_quick_save_pressed)
	_hud_bar.add_child(_save_hud_btn)

	_toggle_notebook_btn = Button.new()
	_toggle_notebook_btn.name = "ToggleNotebookButton"
	_toggle_notebook_btn.position = Vector2(1000.0, 8.0)
	_toggle_notebook_btn.size = Vector2(268.0, 36.0)
	_toggle_notebook_btn.add_theme_font_size_override("font_size", 12)
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
# SURVIVAL NOTEBOOK 5-TAB FLIPBOOK PANEL (740x560 at (516, 86))
# ---------------------------------------------------------------------------
func _build_survival_notebook() -> void:
	_notebook_root = Control.new()
	_notebook_root.name = "SurvivalNotebook"
	_notebook_root.position = Vector2(516.0, 86.0)
	_notebook_root.size = Vector2(740.0, 560.0)
	add_child(_notebook_root)

	# 5 Clean, Non-Overlapping Protruding Folder Index Tabs across top edge (x = 24..732)
	var tab_defs := [
		{"title": "1. LOG", "x": 24.0, "w": 116.0},
		{"title": "2. CARE & BONDS", "x": 144.0, "w": 158.0},
		{"title": "3. DILEMMA", "x": 306.0, "w": 136.0},
		{"title": "4. OSM RADAR", "x": 446.0, "w": 148.0},
		{"title": "5. ESCAPE", "x": 598.0, "w": 134.0}
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

	# 5 Non-Overlapping Inner Tab Containers (Rect2(38, 14, 686, 482))
	_tab_containers.clear()
	for i in range(NUM_TABS):
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
	_prev_page_btn.text = "< PREV PAGE"
	_prev_page_btn.position = Vector2(38.0, 506.0)
	_prev_page_btn.size = Vector2(124.0, 38.0)
	_prev_page_btn.add_theme_font_size_override("font_size", 13)
	_style_notebook_ink_button(_prev_page_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK)
	_prev_page_btn.pressed.connect(func() -> void:
		_switch_tab(posmod(_current_tab - 1, NUM_TABS), true)
	)
	_notebook_root.add_child(_prev_page_btn)

	_next_page_btn = Button.new()
	_next_page_btn.text = "NEXT PAGE >"
	_next_page_btn.position = Vector2(168.0, 506.0)
	_next_page_btn.size = Vector2(124.0, 38.0)
	_next_page_btn.add_theme_font_size_override("font_size", 13)
	_style_notebook_ink_button(_next_page_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK)
	_next_page_btn.pressed.connect(func() -> void:
		_switch_tab(posmod(_current_tab + 1, NUM_TABS), true)
	)
	_notebook_root.add_child(_next_page_btn)

	_page_indicator_lbl = _make_ink_label("Tab 1 / 5", 13, COL_INK_MUTED)
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
	_current_tab = clampi(new_tab, 0, NUM_TABS - 1)
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
		TAB_ESCAPE:
			_rebuild_tab_escape()

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
		elif i == TAB_ESCAPE:
			if GameState.can_escape_by_vehicle():
				tb.badge_text = "GO!"
				tb.badge_color = COL_GREEN
			else:
				tb.badge_text = ""
		else:
			tb.badge_text = ""
		tb.queue_redraw()

	if is_instance_valid(_page_indicator_lbl):
		_page_indicator_lbl.text = "Tab %d / %d" % [_current_tab + 1, NUM_TABS]
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
	_planned_antibiotics_ids.clear()
	_planned_antirad_ids.clear()
	_expedition_scheduled = false
	_selected_gear_ids.clear()

	_available_targets = ExpeditionEngine.get_available_targets()
	if _selected_poi_index < 0 or _selected_poi_index >= _available_targets.size():
		_selected_poi_index = 0
	if not _available_targets.is_empty() and bool((_available_targets[_selected_poi_index] as Dictionary).get("depleted", false)):
		for pi in range(_available_targets.size()):
			if not bool((_available_targets[pi] as Dictionary).get("depleted", false)):
				_selected_poi_index = pi
				break
	_ensure_valid_explorer_selected()

	_current_event = {}
	_selected_event_choice_id = ""
	_has_unresolved_dilemma = false
	if GameState.day >= 1 and not GameState.get_living_bunker_members().is_empty():
		_current_event = EventDeck.draw_daily_event(GameState.day, GameState.rng)
		var opts: Array = _get_event_options(_current_event)
		if not opts.is_empty():
			_has_unresolved_dilemma = true
			for i in range(opts.size() - 1, -1, -1):
				var od: Dictionary = opts[i]
				if _is_event_option_available(od):
					_selected_event_choice_id = str(od.get("id", ""))
					break
			if GameState.demo_mode and GameState.day == 1:
				for opt_v in opts:
					if opt_v is Dictionary:
						var od_demo: Dictionary = opt_v
						if _is_event_option_available(od_demo) and str(od_demo.get("item_id", "")) != "":
							_selected_event_choice_id = str(od_demo.get("id", ""))
							break

	_rebuild_all_tabs()
	if reset_tab_to_log:
		_switch_tab(TAB_LOG, false)
	else:
		_refresh_tab_headers_and_footer()

	if is_instance_valid(_hud_bar):
		_hud_bar.queue_redraw()
	if is_instance_valid(_backdrop):
		_backdrop.refresh_bunker()

func _rebuild_all_tabs() -> void:
	_rebuild_tab_daily_log()
	_rebuild_tab_rations()
	_rebuild_tab_dilemma()
	_rebuild_tab_expedition()
	_rebuild_tab_escape()
	_refresh_tab_headers_and_footer()

# ---------------------------------------------------------------------------
# TAB 1: DAILY LOG + SURVIVOR RELATIONSHIP PILLS + SAVE BUTTONS (686x482)
# ---------------------------------------------------------------------------
func _rebuild_tab_daily_log() -> void:
	var root: Control = _tab_containers[TAB_LOG]
	_clear_children(root)

	# Header Banner (left: Day & Shelter Telemetry; right: [ SAVE SHELTER ] & [ SAVE & EXIT TO TITLE ])
	var hdr := _make_ink_label("SHELTER LOG — DAY %d" % GameState.day, 17, COL_INK)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(340.0, 24.0)
	hdr.clip_text = true
	root.add_child(hdr)

	var house_label: String = str(GameState.selected_house.get("name", "Selected Shelter"))
	var sub_txt: String = "%s · %.1f Sv/hr · %.0f°C · Hull %.0f%%" % [
		house_label, GameState.surface_radiation_sv, GameState.bunker_temp_c, GameState.bunker_structural_integrity
	]
	var sub := _make_ink_label(sub_txt, 11, COL_INK_MUTED)
	sub.position = Vector2(0.0, 23.0)
	sub.size = Vector2(340.0, 18.0)
	sub.clip_text = true
	root.add_child(sub)

	var save_btn := Button.new()
	save_btn.name = "SaveShelterLogButton"
	save_btn.text = "[ SAVE SHELTER ]"
	save_btn.position = Vector2(346.0, 4.0)
	save_btn.size = Vector2(140.0, 32.0)
	save_btn.add_theme_font_size_override("font_size", 11)
	_style_conelrad_button(save_btn, Color("#2c402a"), COL_GREEN, COL_PARCHMENT)
	_tighten_button_margins(save_btn)
	save_btn.pressed.connect(_on_quick_save_pressed)
	root.add_child(save_btn)

	var save_exit_btn := Button.new()
	save_exit_btn.name = "SaveExitTitleButton"
	save_exit_btn.text = "[ SAVE & EXIT TO TITLE ]"
	save_exit_btn.position = Vector2(492.0, 4.0)
	save_exit_btn.size = Vector2(194.0, 32.0)
	save_exit_btn.add_theme_font_size_override("font_size", 11)
	_style_notebook_ink_button(save_exit_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK)
	_tighten_button_margins(save_exit_btn)
	save_exit_btn.pressed.connect(_on_save_and_exit_to_title_pressed)
	root.add_child(save_exit_btn)

	# Family Quick Status & Relationship Cards Row (y = 44..152, height 108px)
	var fam_row := HBoxContainer.new()
	fam_row.position = Vector2(0.0, 44.0)
	fam_row.size = Vector2(686.0, 108.0)
	fam_row.add_theme_constant_override("separation", 8)
	root.add_child(fam_row)

	for m_v in GameState.family_members:
		if not (m_v is Dictionary):
			continue
		var member: Dictionary = m_v
		var mid: String = str(member.get("id", ""))
		var card := _make_parchment_card(Vector2(165.0, 108.0), COL_CARD_BG, COL_INK)
		fam_row.add_child(card)

		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 6)
		card.add_child(row_box)

		var port := _MemberPortraitWidget.new()
		port.member_data = member
		port.custom_minimum_size = Vector2(46.0, 62.0)
		port.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row_box.add_child(port)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.add_theme_constant_override("separation", 2)
		row_box.add_child(info_v)

		var m_name: String = str(member.get("name", "Survivor"))
		var n_lbl := _make_ink_label(m_name, 12, COL_INK)
		n_lbl.clip_text = true
		info_v.add_child(n_lbl)

		var role_age: String = "%s · %dy" % [str(member.get("role", "adult")).capitalize(), int(member.get("age", 30))]
		var r_lbl := _make_ink_label(role_age, 10, COL_INK_MUTED)
		info_v.add_child(r_lbl)

		var status_summary: Dictionary = _summarize_member_quick_badge(member)
		info_v.add_child(_make_status_pill(str(status_summary["text"]), status_summary["color"]))

		# Relationship Status Pill (Devoted, Loyal, Neutral, Resentful, Hostile)
		var rel_info: Dictionary = _get_member_relationship_pill_info(member, mid)
		info_v.add_child(_make_status_pill(str(rel_info["text"]), rel_info["color"]))

	# Scrollable Journal Narrative (y = 158..480, height 322px)
	var log_frame := _make_parchment_card(Vector2(686.0, 322.0), Color("#f5ebd4"), COL_INK)
	log_frame.position = Vector2(0.0, 158.0)
	log_frame.size = Vector2(686.0, 322.0)
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
# TAB 2: CARE & BONDS (1/4 RATIONS, MEDKIT, ANTIBIOTICS, ANTI-RAD & BONDS)
# ---------------------------------------------------------------------------
func _rebuild_tab_rations() -> void:
	var root: Control = _tab_containers[TAB_RATIONS]
	_clear_children(root)

	var planned_soup: int = _get_total_planned_soup_q()
	var planned_water: int = _get_total_planned_water_q()
	var rem_soup: int = maxi(0, GameState.soup_quarters - planned_soup)
	var rem_water: int = maxi(0, GameState.water_quarters - planned_water)
	var rem_medkits: int = maxi(0, GameState.medkit_count - (1 if _planned_medkit_member_id != "" else 0))
	var rem_antibiotics: int = maxi(0, GameState.antibiotics_count - _planned_antibiotics_ids.size())
	var rem_antirad: int = maxi(0, GameState.antirad_count - _planned_antirad_ids.size())

	# 1. Top Stockpile Reserve Strip (y = 0..42, height 42px)
	var reserve_card := _make_parchment_card(Vector2(686.0, 42.0), COL_CARD_BG, COL_INK)
	reserve_card.position = Vector2.ZERO
	reserve_card.size = Vector2(686.0, 42.0)
	var sb_res: StyleBoxFlat = reserve_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb_res != null:
		sb_res.content_margin_top = 4.0
		sb_res.content_margin_bottom = 4.0
		reserve_card.add_theme_stylebox_override("panel", sb_res)
	root.add_child(reserve_card)

	var res_hbox := HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 8)
	reserve_card.add_child(res_hbox)

	res_hbox.add_child(_make_compact_supply_chip("soup", "Soup: %s" % GameState.format_quarters_as_cans(rem_soup), COL_ORANGE))
	res_hbox.add_child(_make_compact_supply_chip("water", "Water: %s" % GameState.format_quarters_as_cans(rem_water), COL_WATER))
	res_hbox.add_child(_make_compact_supply_chip("medkit", "Medkit: %d" % rem_medkits, COL_GREEN))
	res_hbox.add_child(_make_compact_supply_chip("antibiotics", "Antibio: %d" % rem_antibiotics, Color("#2f7d6d")))
	res_hbox.add_child(_make_compact_supply_chip("antirad", "Anti-Rad: %d" % rem_antirad, Color("#8a4f9e")))

	# 2. Living Bunker Member Care Rows (y = 46..378, height 332px)
	var rows_scroll := ScrollContainer.new()
	rows_scroll.position = Vector2(0.0, 46.0)
	rows_scroll.size = Vector2(686.0, 332.0)
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(rows_scroll)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 5)
	rows_scroll.add_child(rows_vbox)

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

		var row_card := _make_parchment_card(Vector2(684.0, 77.0), Color("#f6edd8"), COL_INK)
		row_card.custom_minimum_size = Vector2(684.0, 77.0)
		var sb_rc: StyleBoxFlat = row_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb_rc != null:
			sb_rc.content_margin_left = 6.0
			sb_rc.content_margin_right = 6.0
			sb_rc.content_margin_top = 4.0
			sb_rc.content_margin_bottom = 4.0
			row_card.add_theme_stylebox_override("panel", sb_rc)
		rows_vbox.add_child(row_card)

		var r_hbox := HBoxContainer.new()
		r_hbox.add_theme_constant_override("separation", 6)
		row_card.add_child(r_hbox)

		# Col 1: Portrait (44x60)
		var port := _MemberPortraitWidget.new()
		port.member_data = member
		port.custom_minimum_size = Vector2(44.0, 60.0)
		port.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r_hbox.add_child(port)

		# Col 2: Name, Loyalty, Hunger/Thirst & Sickness/Rads (152px)
		var bio_v := VBoxContainer.new()
		bio_v.custom_minimum_size = Vector2(152.0, 62.0)
		bio_v.add_theme_constant_override("separation", 2)
		r_hbox.add_child(bio_v)

		var avg_rel: int = GameState.get_member_avg_relationship(mid)
		var rel_tier: String = GameState.get_relationship_tier(avg_rel)
		var title_lbl := _make_ink_label("%s · %s (%+d)" % [str(member.get("name", "Survivor")), rel_tier, avg_rel], 11, COL_INK)
		title_lbl.clip_text = true
		bio_v.add_child(title_lbl)

		var pills_h := HBoxContainer.new()
		pills_h.add_theme_constant_override("separation", 4)
		bio_v.add_child(pills_h)
		var h_info: Dictionary = _get_hunger_status(member)
		var t_info: Dictionary = _get_thirst_status(member)
		pills_h.add_child(_make_status_pill(str(h_info["text"]), h_info["color"]))
		pills_h.add_child(_make_status_pill(str(t_info["text"]), t_info["color"]))

		var extra_conds: Array[String] = []
		var sick_lvl: int = int(member.get("sickness", 0))
		var inj_lvl: int = int(member.get("injury", 0))
		var rad_val: float = float(member.get("radiation", 0.0))
		if sick_lvl > 0:
			extra_conds.append("Sick")
		if inj_lvl > 0:
			extra_conds.append("Injured")
		if rad_val >= 1.0:
			extra_conds.append("%.0f Rads" % rad_val)
		if bool(member.get("is_mutant", false)):
			extra_conds.append("Mutant")
		var sub_note: String = " · ".join(extra_conds) if not extra_conds.is_empty() else "Healthy · 0 Rads"
		var sub_lbl := _make_ink_label(sub_note, 10, COL_STAMP_RED if (sick_lvl > 0 or inj_lvl > 0 or rad_val >= 25.0) else COL_INK_MUTED)
		sub_lbl.clip_text = true
		bio_v.add_child(sub_lbl)

		# Col 3: [+1/4 Soup] Stepper (120px)
		var soup_box := _build_quarter_stepper(
			"Soup",
			cur_sq,
			rem_soup > 0,
			COL_ORANGE,
			func(delta_q: int) -> void:
				_adjust_member_ration(mid, "soup_q", delta_q)
		)
		r_hbox.add_child(soup_box)

		# Col 4: [+1/4 Water] Stepper (122px)
		var water_box := _build_quarter_stepper(
			"Water",
			cur_wq,
			rem_water > 0,
			COL_WATER,
			func(delta_q: int) -> void:
				_adjust_member_ration(mid, "water_q", delta_q)
		)
		r_hbox.add_child(water_box)

		# Col 5: Medical Care Stack — [ Medkit ] + [ Antibiotics ] + [ Anti-Rad ] (204px)
		var med_col := VBoxContainer.new()
		med_col.custom_minimum_size = Vector2(204.0, 62.0)
		med_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		med_col.add_theme_constant_override("separation", 4)
		r_hbox.add_child(med_col)

		var captured_mid: String = mid

		# Row A: [ Medkit ]
		var needs_medkit: bool = (sick_lvl > 0) or (inj_lvl > 0)
		var med_selected: bool = (_planned_medkit_member_id == mid)
		var med_btn := Button.new()
		med_btn.custom_minimum_size = Vector2(204.0, 28.0)
		med_btn.add_theme_font_size_override("font_size", 11)
		_tighten_button_margins(med_btn)
		if med_selected:
			med_btn.text = "[ MEDKIT SET ✓ ]"
			_style_conelrad_button(med_btn, COL_GREEN, COL_INK, COL_PARCHMENT)
			_tighten_button_margins(med_btn)
		elif needs_medkit and GameState.medkit_count > 0:
			med_btn.text = "[ Medkit ]"
			_style_notebook_ink_button(med_btn, Color("#e8d9b8"), COL_GREEN, COL_INK)
			_tighten_button_margins(med_btn)
		elif needs_medkit:
			med_btn.text = "Medkit (0)"
			med_btn.disabled = true
			_style_notebook_ink_button(med_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
			_tighten_button_margins(med_btn)
		else:
			med_btn.text = "[ Medkit ] (Well)"
			med_btn.disabled = true
			_style_notebook_ink_button(med_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
			_tighten_button_margins(med_btn)
		med_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			if _planned_medkit_member_id == captured_mid:
				_planned_medkit_member_id = ""
			else:
				_planned_medkit_member_id = captured_mid
			_rebuild_tab_rations()
		)
		med_col.add_child(med_btn)

		# Row B: [ Antibiotics ] + [ Anti-Rad ] side-by-side (100px + 4px + 100px = 204px)
		var spec_h := HBoxContainer.new()
		spec_h.add_theme_constant_override("separation", 4)
		med_col.add_child(spec_h)

		var abx_selected: bool = _planned_antibiotics_ids.has(mid)
		var needs_abx: bool = (sick_lvl > 0) or (inj_lvl > 0)
		var abx_btn := Button.new()
		abx_btn.custom_minimum_size = Vector2(100.0, 28.0)
		abx_btn.add_theme_font_size_override("font_size", 10)
		if abx_selected:
			abx_btn.text = "[ Antibio ✓ ]"
			_style_conelrad_button(abx_btn, Color("#2f7d6d"), COL_INK, COL_PARCHMENT)
		elif needs_abx and rem_antibiotics > 0:
			abx_btn.text = "[ Antibiotics ]"
			_style_notebook_ink_button(abx_btn, Color("#e0eee8"), Color("#2f7d6d"), COL_INK)
		else:
			abx_btn.text = "[ Antibiotics ]"
			abx_btn.disabled = true
			_style_notebook_ink_button(abx_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
		_tighten_button_margins(abx_btn)
		abx_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			if _planned_antibiotics_ids.has(captured_mid):
				_planned_antibiotics_ids.erase(captured_mid)
			elif _planned_antibiotics_ids.size() < GameState.antibiotics_count:
				_planned_antibiotics_ids.append(captured_mid)
			_rebuild_tab_rations()
		)
		spec_h.add_child(abx_btn)

		var ar_selected: bool = _planned_antirad_ids.has(mid)
		var needs_ar: bool = (rad_val > 0.0) or (sick_lvl > 0) or (GameState.surface_radiation_sv >= 4.0)
		var ar_btn := Button.new()
		ar_btn.custom_minimum_size = Vector2(100.0, 28.0)
		ar_btn.add_theme_font_size_override("font_size", 10)
		if ar_selected:
			ar_btn.text = "[ Anti-Rad ✓ ]"
			_style_conelrad_button(ar_btn, Color("#7c4394"), COL_INK, COL_PARCHMENT)
		elif needs_ar and rem_antirad > 0:
			ar_btn.text = "[ Anti-Rad ]"
			_style_notebook_ink_button(ar_btn, Color("#ece0f2"), Color("#7c4394"), COL_INK)
		else:
			ar_btn.text = "[ Anti-Rad ]"
			ar_btn.disabled = true
			_style_notebook_ink_button(ar_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
		_tighten_button_margins(ar_btn)
		ar_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			if _planned_antirad_ids.has(captured_mid):
				_planned_antirad_ids.erase(captured_mid)
			elif _planned_antirad_ids.size() < GameState.antirad_count:
				_planned_antirad_ids.append(captured_mid)
			_rebuild_tab_rations()
		)
		spec_h.add_child(ar_btn)

	if living_in_bunker.is_empty():
		var empty_card := _make_parchment_card(Vector2(680.0, 92.0), Color("#f6edd8"), COL_INK)
		rows_vbox.add_child(empty_card)
		var empty_msg: String = "SHELTER UNOCCUPIED — No indoor rations required today while all surviving shelter members are outside scavenging."
		var empty_lbl := _make_ink_label(empty_msg, 13, COL_INK)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_card.add_child(empty_lbl)

	if not GameState.active_expedition.is_empty():
		var out_name: String = str(GameState.active_expedition.get("member_name", "Explorer"))
		var out_place: String = str(GameState.active_expedition.get("short_target_name", GameState.active_expedition.get("target_name", "the wasteland")))
		rows_vbox.add_child(_make_ink_label("Note: %s is outside scavenging %s." % [out_name, out_place], 11, COL_INK_MUTED))

	# 3. Compact Family Relationship Strip (y = 382..440, height 58px) above unclipped "Reset" row!
	_build_family_relationship_strip(root)

	# 4. Unclipped Bottom Helper & "Reset" Row (y = 444..480, height 36px)
	var foot_hbox := HBoxContainer.new()
	foot_hbox.position = Vector2(0.0, 444.0)
	foot_hbox.size = Vector2(686.0, 36.0)
	foot_hbox.add_theme_constant_override("separation", 8)
	root.add_child(foot_hbox)

	var tip_lbl := _make_ink_label("Fair rations build loyalty; skipping hungry kin breeds resentment.", 11, COL_INK_MUTED)
	tip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_lbl.clip_text = true
	tip_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot_hbox.add_child(tip_lbl)

	var hydrate_all_btn := Button.new()
	hydrate_all_btn.text = "+1/4 Water Thirsty"
	hydrate_all_btn.custom_minimum_size = Vector2(142.0, 32.0)
	hydrate_all_btn.add_theme_font_size_override("font_size", 11)
	_style_notebook_ink_button(hydrate_all_btn, COL_CARD_BG, COL_WATER, COL_INK)
	hydrate_all_btn.pressed.connect(_on_auto_water_thirsty)
	foot_hbox.add_child(hydrate_all_btn)

	var feed_all_btn := Button.new()
	feed_all_btn.text = "+1/4 Soup Hungry"
	feed_all_btn.custom_minimum_size = Vector2(132.0, 32.0)
	feed_all_btn.add_theme_font_size_override("font_size", 11)
	_style_notebook_ink_button(feed_all_btn, COL_CARD_BG, COL_ORANGE, COL_INK)
	feed_all_btn.pressed.connect(_on_auto_soup_hungry)
	foot_hbox.add_child(feed_all_btn)

	var clear_btn := Button.new()
	clear_btn.name = "ResetRationsButton"
	clear_btn.text = "Reset"
	clear_btn.custom_minimum_size = Vector2(72.0, 32.0)
	clear_btn.add_theme_font_size_override("font_size", 12)
	_style_notebook_ink_button(clear_btn, COL_CARD_BG, COL_INK_MUTED, COL_INK)
	clear_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		for k in _planned_rations.keys():
			_planned_rations[k] = {"soup_q": 0, "water_q": 0}
		_planned_medkit_member_id = ""
		_planned_antibiotics_ids.clear()
		_planned_antirad_ids.clear()
		_rebuild_tab_rations()
	)
	foot_hbox.add_child(clear_btn)

func _build_family_relationship_strip(root: Control) -> void:
	var strip := _make_parchment_card(Vector2(686.0, 58.0), Color("#ece0c3"), COL_INK)
	strip.position = Vector2(0.0, 382.0)
	strip.size = Vector2(686.0, 58.0)
	var sb_st: StyleBoxFlat = strip.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb_st != null:
		sb_st.content_margin_left = 6.0
		sb_st.content_margin_right = 6.0
		sb_st.content_margin_top = 4.0
		sb_st.content_margin_bottom = 4.0
		strip.add_theme_stylebox_override("panel", sb_st)
	root.add_child(strip)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 3)
	strip.add_child(sv)

	var living: Array = GameState.get_all_living_members()
	var best_score: int = -999
	var best_pair_txt: String = ""
	var worst_score: int = 999
	var worst_pair_txt: String = ""

	for i in range(living.size()):
		for j in range(i + 1, living.size()):
			var ma: Dictionary = living[i]
			var mb: Dictionary = living[j]
			var sc: int = GameState.get_relationship(str(ma.get("id", "")), str(mb.get("id", "")))
			var na_short: String = str(ma.get("name", "")).strip_edges().split(" ")[0]
			var nb_short: String = str(mb.get("name", "")).strip_edges().split(" ")[0]
			if sc > best_score:
				best_score = sc
				best_pair_txt = "%s & %s (%+d)" % [na_short, nb_short, sc]
			if sc < worst_score:
				worst_score = sc
				worst_pair_txt = "%s & %s (%+d)" % [na_short, nb_short, sc]

	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 8)
	sv.add_child(top_h)
	top_h.add_child(_make_ink_label("FAMILY BONDS:", 11, COL_INK))

	var effect_txt: String = "Steady Shelter Morale — Fair sharing strengthens family loyalty."
	var effect_col: Color = COL_INK_MUTED
	if best_score >= 55:
		effect_txt = "♥ DEVOTED COOPERATION: Soothes stress, shares warmth & +25% Scrap hull repairs!"
		effect_col = COL_GREEN
	elif best_score >= 45:
		effect_txt = "♥ COOPERATING PAIR: Unlocks [COOPERATE] dilemma options & repair bonus!"
		effect_col = COL_GREEN
	elif worst_score <= -75:
		effect_txt = "! BETRAYAL RISK: Hostile survivor may steal rations & abandon the shelter!"
		effect_col = COL_STAMP_RED
	elif worst_score <= -35:
		effect_txt = "⚡ RESENTMENT ACTIVE: Arguments & emotional breakdowns likely tonight!"
		effect_col = COL_ORANGE

	var eff_lbl := _make_ink_label(effect_txt, 11, effect_col)
	eff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff_lbl.clip_text = true
	top_h.add_child(eff_lbl)

	var bot_h := HBoxContainer.new()
	bot_h.add_theme_constant_override("separation", 5)
	sv.add_child(bot_h)

	var show_strained: bool = (worst_pair_txt != "" and worst_pair_txt != best_pair_txt)
	if living.size() >= 2:
		bot_h.add_child(_make_status_pill("Closest: " + best_pair_txt, COL_BOND_PINK if best_score >= 45 else COL_GREEN))
		if show_strained:
			bot_h.add_child(_make_status_pill("Strained: " + worst_pair_txt, COL_STAMP_RED if worst_score <= -35 else COL_INK_MUTED))
	elif living.size() == 1:
		bot_h.add_child(_make_status_pill("Lone Survivor Inside Shelter", COL_INK_MUTED))

	var member_font_sz: int = 9 if (living.size() >= 4 and show_strained) else 10
	for m_v in living:
		var md: Dictionary = m_v
		var mid_s: String = str(md.get("id", ""))
		var avg_r: int = GameState.get_member_avg_relationship(mid_s)
		var tier_s: String = GameState.get_relationship_tier(avg_r)
		var nm_short: String = str(md.get("name", "")).strip_edges().split(" ")[0]
		var lbl_s := _make_ink_label("%s: %s (%+d)" % [nm_short, tier_s, avg_r], member_font_sz, COL_INK)
		lbl_s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bot_h.add_child(lbl_s)

func _build_quarter_stepper(kind_label: String, current_q: int, can_add: bool, accent: Color, on_delta: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(24.0, 38.0)
	minus_btn.disabled = (current_q <= 0)
	minus_btn.add_theme_font_size_override("font_size", 13)
	_style_notebook_ink_button(minus_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK)
	_tighten_button_margins(minus_btn)
	minus_btn.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		on_delta.call(-1)
	)
	box.add_child(minus_btn)

	var plus_btn := Button.new()
	plus_btn.custom_minimum_size = Vector2(95.0, 38.0)
	plus_btn.add_theme_font_size_override("font_size", 11)
	if current_q >= MAX_DAILY_RATION_QUARTERS:
		plus_btn.text = "%d/4 %s MAX" % [current_q, kind_label]
		_style_conelrad_button(plus_btn, accent, COL_INK, COL_PARCHMENT)
	elif current_q > 0:
		plus_btn.text = "%d/4 %s (+)" % [current_q, kind_label]
		_style_conelrad_button(plus_btn, accent, COL_INK, COL_PARCHMENT)
	else:
		plus_btn.text = "+1/4 %s" % kind_label
		_style_notebook_ink_button(plus_btn, Color("#ebe0c5"), accent, COL_INK)
	_tighten_button_margins(plus_btn)
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

func _on_auto_soup_hungry() -> void:
	SoundManager.play_sfx("button_click")
	for m_v in GameState.get_living_bunker_members():
		if not (m_v is Dictionary):
			continue
		var m: Dictionary = m_v
		var mid: String = str(m.get("id", ""))
		var h: int = int(m.get("hunger", 0))
		var dwf: int = int(m.get("days_without_food", 0))
		if h > 0 or dwf >= 2 or GameState.soup_quarters >= 8:
			if _get_total_planned_soup_q() < GameState.soup_quarters:
				var e: Dictionary = _planned_rations.get(mid, {"soup_q": 0, "water_q": 0})
				if int(e.get("soup_q", 0)) == 0:
					e["soup_q"] = 1
					_planned_rations[mid] = e
	_rebuild_tab_rations()

# ---------------------------------------------------------------------------
# TAB 3: DILEMMA (SPECIALTY ITEM ICONS & [COOPERATE] RELATIONSHIP BADGES)
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
	var options: Array = _get_event_options(_current_event)
	var compact_opts: bool = options.size() >= 5

	var hdr := _make_ink_label("DAY %d DILEMMA — %s" % [GameState.day, ev_title], 18, COL_STAMP_RED)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 26.0)
	hdr.clip_text = true
	root.add_child(hdr)

	var story_card := _make_parchment_card(Vector2(686.0, 158.0), Color("#f6edd8"), COL_INK)
	story_card.position = Vector2(0.0, 28.0)
	story_card.size = Vector2(686.0, 158.0)
	root.add_child(story_card)

	var story_scroll := ScrollContainer.new()
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_card.add_child(story_scroll)

	var story_lbl := _make_ink_label(ev_desc, 14, COL_INK)
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_lbl.custom_minimum_size = Vector2(652.0, 0.0)
	story_scroll.add_child(story_lbl)

	var prompt_lbl := _make_ink_label("CHOOSE YOUR RESPONSE BEFORE LIGHTS OUT:", 12, COL_INK_MUTED)
	prompt_lbl.position = Vector2(2.0, 190.0)
	prompt_lbl.size = Vector2(680.0, 18.0)
	root.add_child(prompt_lbl)

	var opts_scroll := ScrollContainer.new()
	opts_scroll.position = Vector2(0.0, 210.0)
	opts_scroll.size = Vector2(686.0, 270.0)
	opts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(opts_scroll)

	var opts_vbox := VBoxContainer.new()
	opts_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_vbox.add_theme_constant_override("separation", 6 if compact_opts else 8)
	opts_scroll.add_child(opts_vbox)

	var card_h: float = 46.0 if compact_opts else 54.0
	var btn_h: float = 34.0 if compact_opts else 40.0
	var icon_sz: float = 30.0 if compact_opts else 36.0

	for opt_v in options:
		if not (opt_v is Dictionary):
			continue
		var opt: Dictionary = opt_v
		var cid: String = str(opt.get("id", ""))
		var label_txt: String = _strip_md(str(opt.get("label", opt.get("text", cid.capitalize()))))
		var req_item: String = str(opt.get("item_id", opt.get("required_item", "")))
		var is_coop: bool = (
			label_txt.to_upper().contains("[COOPERATE]")
			or bool(opt.get("cooperate", false))
			or bool(opt.get("requires_bond", false))
			or cid.to_lower().contains("coop")
		)
		var avail: bool = _is_event_option_available(opt)
		var is_chosen: bool = (_selected_event_choice_id == cid)

		var border_c: Color = COL_STAMP_RED if is_chosen else (COL_BOND_PINK if (is_coop and avail) else (COL_INK if avail else COL_INK_MUTED))
		var opt_panel := _make_parchment_card(
			Vector2(672.0, card_h),
			Color("#f7e7ba") if is_chosen else (Color("#f7eaf0") if (is_coop and avail) else (Color("#efe4c8") if avail else Color("#ded4bd"))),
			border_c
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
		oh.add_theme_constant_override("separation", 6)
		opt_panel.add_child(oh)

		var sel_btn := Button.new()
		sel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel_btn.custom_minimum_size = Vector2(400.0, btn_h)
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
			_tighten_button_margins(sel_btn)

		var captured_cid: String = cid
		sel_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			_selected_event_choice_id = captured_cid
			_has_unresolved_dilemma = false
			_rebuild_tab_dilemma()
			_refresh_tab_headers_and_footer()
		)
		oh.add_child(sel_btn)

		if is_coop:
			oh.add_child(_make_status_pill("♥ COOPERATE" if avail else "NEED BOND", COL_BOND_PINK if avail else COL_INK_MUTED))

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

	var h_addr: String = _strip_md(str(GameState.selected_house.get("address", GameState.current_neighborhood_label)))
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
	_build_equipment_readiness_grid(root, 286.0)

func _build_day1_orientation_view(root: Control) -> void:
	var hdr := _make_ink_label("CONELRAD FORM CD-1 — DAY 1 SHELTER ORIENTATION", 18, COL_INK)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 28.0)
	root.add_child(hdr)

	var card := _make_parchment_card(Vector2(686.0, 244.0), Color("#f6edd8"), COL_INK)
	card.position = Vector2(0.0, 34.0)
	card.size = Vector2(686.0, 244.0)
	root.add_child(card)

	var h_addr: String = str(GameState.selected_house.get("address", GameState.current_neighborhood_label))
	var n_name: String = str(GameState.nuke_config.get("target_name", "Strategic Target"))
	var n_yield: int = int(GameState.nuke_config.get("yield_kt", 800))
	var n_dist: float = float(GameState.nuke_config.get("distance_km", 3.0))
	var n_zone: String = str(GameState.nuke_config.get("zone", "fallout_plume")).replace("_", " ").to_upper()

	var orient_lines: Array[String] = [
		"• DESIGNATED FALLOUT SHELTER: %s" % h_addr,
		"• DETONATION TELEMETRY: %d kt warhead at %s (%.2f km — %s)" % [n_yield, n_name, n_dist, n_zone],
		"• ATMOSPHERIC READINGS: %.1f Sv/hr surface fallout | %.0f °C interior shelter climate" % [GameState.surface_radiation_sv, GameState.bunker_temp_c],
		"• SPECIALTY STOCKS: %d Antibiotics · %d Anti-Rad · %d Scrap · %d/%d Fuel Cans" % [
			GameState.antibiotics_count, GameState.antirad_count, GameState.scrap_count, GameState.fuel_cans, GameState.fuel_needed
		],
		"• SURVIVAL DIRECTIVE: Ration fairly in 2. CARE & BONDS, scout Rings 1–3 in 4. OSM RADAR, and rebuild the 1950s Station Wagon in 5. ESCAPE!"
	]
	var body := _make_ink_label("\n".join(orient_lines), 13, COL_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(body)
	_build_equipment_readiness_grid(root, 288.0)

func _build_equipment_readiness_grid(root: Control, y_top: float) -> void:
	var eq_hdr := _make_ink_label("KEY SHELTER & SPECIALTY EQUIPMENT READINESS:", 12, COL_INK_MUTED)
	eq_hdr.position = Vector2(2.0, y_top)
	eq_hdr.size = Vector2(680.0, 18.0)
	root.add_child(eq_hdr)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(0.0, y_top + 22.0)
	grid.size = Vector2(686.0, 152.0)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	for key_id in ["radio", "gas_mask", "suitcase", "map", "antibiotics", "antirad", "scrap", "toolbox"]:
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
		ic.custom_minimum_size = Vector2(34.0, 34.0)
		gh.add_child(ic)

		var gv := VBoxContainer.new()
		gh.add_child(gv)
		gv.add_child(_make_ink_label(_get_short_item_label(key_id), 12, COL_INK))
		gv.add_child(_make_ink_label("READY" if owned_ok else "NONE", 10, COL_GREEN if owned_ok else COL_STAMP_RED))

# ---------------------------------------------------------------------------
# TAB 4: MULTI-RING (0–10 KM) REAL-WORLD OSM RADAR & PLANNER (686x482)
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
	var cat_raw: String = str(exp_d.get("category", "neighbor_house"))
	var cat_label: String = _human_category_name(cat_raw).to_upper()
	var dist_m: float = float(exp_d.get("distance_m", 180.0))
	var ring_num: int = _get_poi_ring(exp_d)
	var bearing_str: String = str(exp_d.get("bearing", "N"))
	var days_rem: int = maxi(1, int(exp_d.get("days_remaining", 1)))
	var days_tot: int = maxi(days_rem, int(exp_d.get("days_total", days_rem)))
	var carried_gear: Array = exp_d.get("gear_ids", [])
	var active_poi_idx: int = int(exp_d.get("poi_index", 0))

	var hdr := _make_ink_label("LIVE SURFACE EXPEDITION TRACKER — RING %d RECON IN PROGRESS" % ring_num, 16, COL_STAMP_RED)
	hdr.position = Vector2(0.0, 0.0)
	hdr.size = Vector2(686.0, 26.0)
	hdr.clip_text = true
	root.add_child(hdr)

	var radar := _ExpeditionRadarMap.new()
	radar.position = Vector2(0.0, 32.0)
	radar.size = Vector2(328.0, 444.0)
	radar.targets = _available_targets
	radar.ring_filter = 0
	radar.selected_index = clampi(active_poi_idx, 0, maxi(0, _available_targets.size() - 1))
	radar.active_expedition_mode = true
	radar.route_progress = clampf(1.0 - float(days_rem) / float(days_tot + 1), 0.25, 0.85)
	root.add_child(radar)

	var right_card := _make_parchment_card(Vector2(344.0, 444.0), Color("#f6edd8"), COL_INK)
	right_card.position = Vector2(342.0, 32.0)
	right_card.size = Vector2(344.0, 444.0)
	root.add_child(right_card)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right_card.add_child(rv)

	var member_dict: Dictionary = _find_member_by_id(explorer_id)
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 10)
	rv.add_child(exp_row)

	if not member_dict.is_empty():
		var port := _MemberPortraitWidget.new()
		port.member_data = member_dict
		port.custom_minimum_size = Vector2(60.0, 74.0)
		exp_row.add_child(port)

	var who_v := VBoxContainer.new()
	who_v.add_theme_constant_override("separation", 4)
	exp_row.add_child(who_v)
	who_v.add_child(_make_ink_label("EXPLORER OUTSIDE:", 11, COL_INK_MUTED))
	who_v.add_child(_make_ink_label(explorer_name.to_upper(), 17, COL_INK))
	who_v.add_child(_make_status_pill("RING %d · %s" % [ring_num, _format_distance_m_or_km(dist_m)], COL_WATER))

	var dest_box := _make_parchment_card(Vector2(320.0, 122.0), COL_CARD_BG, COL_INK)
	rv.add_child(dest_box)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 3)
	dest_box.add_child(dv)
	dv.add_child(_make_ink_label("OSM DESTINATION (%s):" % cat_label, 11, COL_INK_MUTED))
	var t_lbl := _make_ink_label(target_name, 15, COL_STAMP_RED)
	t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(t_lbl)
	dv.add_child(_make_ink_label("Distance: %s (%s) · Ring %d" % [_format_distance_m_or_km(dist_m), bearing_str, ring_num], 12, COL_INK))
	var imp_lbl := _make_ink_label(_get_category_gameplay_impact(cat_raw), 10, COL_GREEN)
	imp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(imp_lbl)

	rv.add_child(_make_ink_label("CARRIED SURVIVAL GEAR:", 12, COL_INK_MUTED))
	var gear_h := HBoxContainer.new()
	gear_h.add_theme_constant_override("separation", 8)
	rv.add_child(gear_h)
	if carried_gear.is_empty():
		gear_h.add_child(_make_ink_label("Travelling light (no gear checked out)", 12, COL_INK))
	else:
		for g_v in carried_gear:
			var gid: String = str(g_v)
			var g_chip := _make_parchment_card(Vector2(48.0, 48.0), COL_CARD_BG, COL_INK)
			var ic := _ItemIconWidget.new()
			ic.item_id = gid
			ic.custom_minimum_size = Vector2(36.0, 36.0)
			g_chip.add_child(ic)
			gear_h.add_child(g_chip)

	var eta_card := _make_parchment_card(Vector2(320.0, 68.0), Color("#232923"), COL_HAZARD)
	rv.add_child(eta_card)
	var eta_lbl := Label.new()
	eta_lbl.text = "DAYS UNTIL RETURN: %d DAY%s" % [days_rem, "" if days_rem == 1 else "S"]
	eta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eta_lbl.add_theme_font_size_override("font_size", 16)
	eta_lbl.add_theme_color_override("font_color", COL_HAZARD)
	eta_card.add_child(eta_lbl)

func _build_expedition_planner(root: Control) -> void:
	_ensure_valid_explorer_selected()

	# If a ring filter is active and current selected POI doesn't match, snap to first non-depleted matching POI
	if _selected_ring_filter > 0 and not _available_targets.is_empty():
		var cur_td: Dictionary = _available_targets[clampi(_selected_poi_index, 0, _available_targets.size() - 1)]
		if _get_poi_ring(cur_td) != _selected_ring_filter:
			var fallback_ring_idx: int = -1
			for idx_f in range(_available_targets.size()):
				var cand_td: Dictionary = _available_targets[idx_f]
				if _get_poi_ring(cand_td) == _selected_ring_filter:
					if fallback_ring_idx < 0:
						fallback_ring_idx = idx_f
					if not bool(cand_td.get("depleted", false)):
						fallback_ring_idx = idx_f
						break
			if fallback_ring_idx >= 0:
				_selected_poi_index = fallback_ring_idx

	# --- LEFT COLUMN (x = 0..332): Radar Map (0..214) + Ring Filter Chips (218..246) + Target List (250..480) ---
	_radar_map_widget = _ExpeditionRadarMap.new()
	_radar_map_widget.position = Vector2(0.0, 0.0)
	_radar_map_widget.size = Vector2(332.0, 214.0)
	_radar_map_widget.targets = _available_targets
	_radar_map_widget.ring_filter = _selected_ring_filter
	_radar_map_widget.selected_index = _selected_poi_index
	_radar_map_widget.target_clicked.connect(func(idx: int) -> void:
		SoundManager.play_sfx("button_click")
		_selected_poi_index = idx
		_rebuild_tab_expedition()
	)
	root.add_child(_radar_map_widget)

	# Ring Filter Chips Row: All, R1 Near, R2 District, R3 Deep (y = 218..246)
	var chips_h := HBoxContainer.new()
	chips_h.position = Vector2(0.0, 218.0)
	chips_h.size = Vector2(332.0, 28.0)
	chips_h.add_theme_constant_override("separation", 4)
	root.add_child(chips_h)

	var ring_chips := [
		{"ring": 0, "label": "All", "w": 52.0},
		{"ring": 1, "label": "R1 Near", "w": 84.0},
		{"ring": 2, "label": "R2 District", "w": 98.0},
		{"ring": 3, "label": "R3 Deep", "w": 86.0}
	]
	for rc_v in ring_chips:
		var rc: Dictionary = rc_v
		var r_val: int = int(rc["ring"])
		var r_active: bool = (_selected_ring_filter == r_val)
		var chip_btn := Button.new()
		chip_btn.text = str(rc["label"])
		chip_btn.custom_minimum_size = Vector2(float(rc["w"]), 26.0)
		chip_btn.add_theme_font_size_override("font_size", 10)
		if r_active:
			_style_conelrad_button(chip_btn, Color("#293c28"), COL_HAZARD, COL_HAZARD)
		else:
			_style_notebook_ink_button(chip_btn, COL_CARD_BG, COL_INK, COL_INK)
		_tighten_button_margins(chip_btn)
		chip_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			_selected_ring_filter = r_val
			_rebuild_tab_expedition()
		)
		chips_h.add_child(chip_btn)

	# Scrollable Filtered OSM Target List (y = 250..480, height 230px)
	var list_card := _make_parchment_card(Vector2(332.0, 230.0), Color("#f6edd8"), COL_INK)
	list_card.position = Vector2(0.0, 250.0)
	list_card.size = Vector2(332.0, 230.0)
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

	var sel_member: Dictionary = _find_member_by_id(_selected_explorer_id)
	var any_shown: bool = false
	for i in range(_available_targets.size()):
		var td: Dictionary = _available_targets[i]
		var poi_ring: int = _get_poi_ring(td)
		if _selected_ring_filter > 0 and poi_ring != _selected_ring_filter:
			continue
		any_shown = true
		var is_sel: bool = (i == _selected_poi_index)
		var base_name: String = str(td.get("name", "Landmark"))
		var cat: String = str(td.get("category", "neighbor_house"))
		var dist_m: float = float(td.get("distance_m", 150.0))
		var t_days: int = ExpeditionEngine.compute_trip_days(sel_member, td, _selected_gear_ids)
		var depl: bool = bool(td.get("depleted", false))

		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(304.0, 34.0)
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.clip_text = true
		row_btn.disabled = depl
		row_btn.add_theme_font_size_override("font_size", 11)
		var cat_short: String = _short_category_tag(cat)
		if depl:
			row_btn.text = "[DEPLETED] [R%d·%s] %s (%s)" % [poi_ring, cat_short, base_name, _format_distance_m_or_km(dist_m)]
			_style_notebook_ink_button(row_btn, Color("#d8ceba"), COL_INK_MUTED, COL_INK_MUTED)
		else:
			row_btn.text = "[R%d·%s] %s (%s · %dd)" % [poi_ring, cat_short, base_name, _format_distance_m_or_km(dist_m), t_days]
			if is_sel:
				_style_conelrad_button(row_btn, COL_STAMP_RED, COL_INK, Color("#fff5df"))
			else:
				_style_notebook_ink_button(row_btn, COL_CARD_BG, _get_category_color(cat).darkened(0.25), COL_INK)
		_tighten_button_margins(row_btn)

		var cap_idx: int = i
		row_btn.pressed.connect(func() -> void:
			if depl:
				return
			SoundManager.play_sfx("button_click")
			_selected_poi_index = cap_idx
			_rebuild_tab_expedition()
		)
		t_vbox.add_child(row_btn)

	if not any_shown:
		t_vbox.add_child(_make_ink_label("No landmarks charted in Ring %d — switch Ring chip to 'All'." % _selected_ring_filter, 11, COL_INK_MUTED))

	# --- RIGHT COLUMN (x = 344..686, width = 342) ---
	# 1. Selected Target Detail + Gameplay Impact Card (y = 0..104)
	var sel_poi: Dictionary = _available_targets[_selected_poi_index] if not _available_targets.is_empty() else {}
	var sel_depleted: bool = bool(sel_poi.get("depleted", false))
	if sel_depleted:
		_expedition_scheduled = false

	var detail_card := _make_parchment_card(
		Vector2(338.0, 104.0),
		Color("#d8ceba") if sel_depleted else COL_CARD_BG,
		COL_INK_MUTED if sel_depleted else COL_INK
	)
	detail_card.position = Vector2(344.0, 0.0)
	detail_card.size = Vector2(338.0, 104.0)
	var sb_det: StyleBoxFlat = detail_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb_det != null:
		sb_det.content_margin_top = 4.0
		sb_det.content_margin_bottom = 4.0
		detail_card.add_theme_stylebox_override("panel", sb_det)
	root.add_child(detail_card)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 2)
	detail_card.add_child(dv)

	var p_name: String = str(sel_poi.get("name", "No Target"))
	var p_cat_raw: String = str(sel_poi.get("category", "neighbor_house"))
	var p_cat_lbl: String = _human_category_name(p_cat_raw)
	var p_ring: int = _get_poi_ring(sel_poi)
	var p_dist: float = float(sel_poi.get("distance_m", 150.0))
	var p_bear: String = str(sel_poi.get("bearing", "E"))
	var est_days: int = ExpeditionEngine.compute_trip_days(sel_member, sel_poi, _selected_gear_ids) if not sel_poi.is_empty() else 1
	var b_risk: String = str(sel_poi.get("bandit_risk", "Moderate"))

	var d_title_txt: String = ("[DEPLETED] " + p_name) if sel_depleted else p_name
	var d_title := _make_ink_label(d_title_txt, 13, COL_INK_MUTED if sel_depleted else COL_STAMP_RED)
	d_title.clip_text = true
	dv.add_child(d_title)

	var meta_lbl := _make_ink_label("Ring %d · %s · %s %s · %dd · Risk: %s" % [
		p_ring, p_cat_lbl, _format_distance_m_or_km(p_dist), p_bear, est_days, b_risk
	], 10, COL_INK_MUTED if sel_depleted else COL_INK)
	meta_lbl.clip_text = true
	dv.add_child(meta_lbl)

	# Gameplay Impact Description explaining why you'd trek here (wraps cleanly up to 2 lines without cutting off)
	var impact_txt: String = (
		"Status: [DEPLETED] — Fully scavenged on prior recon; select another landmark."
		if sel_depleted
		else _get_category_gameplay_impact(p_cat_raw)
	)
	var impact_lbl := _make_ink_label(impact_txt, 10, COL_INK_MUTED if sel_depleted else Color("#245c2a"))
	impact_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(impact_lbl)

	var loot_h := HBoxContainer.new()
	loot_h.add_theme_constant_override("separation", 5)
	dv.add_child(loot_h)
	loot_h.add_child(_make_ink_label("Expected Loot:", 10, COL_INK_MUTED))
	var loot_ids: Array = sel_poi.get("expected_loot", ["soup", "water"])
	for lid_v in loot_ids:
		var ic := _ItemIconWidget.new()
		ic.item_id = str(lid_v)
		ic.custom_minimum_size = Vector2(20.0, 20.0)
		loot_h.add_child(ic)

	# 2. Explorer Selector (y = 108..224)
	var exp_hdr := _make_ink_label("1. SELECT EXPLORER (ADULT / TEEN):", 11, COL_INK_MUTED)
	exp_hdr.position = Vector2(346.0, 108.0)
	exp_hdr.size = Vector2(336.0, 16.0)
	root.add_child(exp_hdr)

	var exp_grid := GridContainer.new()
	exp_grid.columns = 2
	exp_grid.position = Vector2(344.0, 126.0)
	exp_grid.size = Vector2(338.0, 96.0)
	exp_grid.add_theme_constant_override("h_separation", 6)
	exp_grid.add_theme_constant_override("v_separation", 5)
	root.add_child(exp_grid)

	var candidates: Array = _get_eligible_explorers()
	if candidates.is_empty():
		exp_grid.add_child(_make_ink_label("No fit adult/teen available (check Breakdowns)!", 11, COL_STAMP_RED))
	else:
		for m_v in candidates:
			var md: Dictionary = m_v
			var mid: String = str(md.get("id", ""))
			var chosen_m: bool = (mid == _selected_explorer_id)
			var m_btn := Button.new()
			m_btn.custom_minimum_size = Vector2(164.0, 42.0)
			m_btn.clip_text = true
			m_btn.add_theme_font_size_override("font_size", 11)
			var m_lbl: String = "%s (%s)" % [str(md.get("name", "Survivor")), str(md.get("role", "adult")).capitalize()]
			m_btn.text = ("[X] " if chosen_m else "[ ] ") + m_lbl
			if chosen_m:
				_style_conelrad_button(m_btn, Color("#33442d"), COL_HAZARD, COL_HAZARD)
			else:
				_style_notebook_ink_button(m_btn, COL_CARD_BG, COL_INK, COL_INK)
			_tighten_button_margins(m_btn)
			var cap_mid: String = mid
			m_btn.pressed.connect(func() -> void:
				SoundManager.play_sfx("button_click")
				_selected_explorer_id = cap_mid
				_rebuild_tab_expedition()
			)
			exp_grid.add_child(m_btn)

	# 3. Gear Loadout Checkboxes (y = 228..410) — 3 * 104 + 10 = 322px <= 342px (zero right clipping!)
	var has_suitcase_sel: bool = _selected_gear_ids.has("suitcase") and GameState.has_working_item("suitcase")
	var extra_gear_cnt: int = _count_non_suitcase_selected_gear()
	var gear_hdr_txt: String = (
		"2. GEAR LOADOUT (SUITCASE: %d/3 EXTRA SLOTS):" % extra_gear_cnt
		if has_suitcase_sel
		else "2. GEAR (%d/1 ITEM — PACK SUITCASE FOR +3!):" % _selected_gear_ids.size()
	)
	var gear_hdr := _make_ink_label(gear_hdr_txt, 11, COL_GREEN if has_suitcase_sel else COL_INK_MUTED)
	gear_hdr.position = Vector2(344.0, 228.0)
	gear_hdr.size = Vector2(338.0, 18.0)
	gear_hdr.clip_text = true
	root.add_child(gear_hdr)

	var g_grid := GridContainer.new()
	g_grid.columns = 3
	g_grid.position = Vector2(344.0, 248.0)
	g_grid.size = Vector2(342.0, 160.0)
	g_grid.add_theme_constant_override("h_separation", 5)
	g_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(g_grid)

	for gid in EXPEDITION_GEAR_SLOTS:
		var working: bool = GameState.has_working_item(gid)
		var broken: bool = _is_item_owned_but_broken(gid)
		var checked: bool = working and _selected_gear_ids.has(gid)

		var cell := _make_parchment_card(
			Vector2(104.0, 72.0),
			Color("#e9f0d8") if checked else (COL_CARD_BG if working else Color("#dcd2be")),
			COL_GREEN if checked else (COL_INK if working else COL_INK_MUTED)
		)
		cell.custom_minimum_size = Vector2(104.0, 72.0)
		var sb_cell: StyleBoxFlat = cell.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb_cell != null:
			sb_cell.content_margin_left = 6.0
			sb_cell.content_margin_right = 6.0
			sb_cell.content_margin_top = 4.0
			sb_cell.content_margin_bottom = 4.0
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
		ic.custom_minimum_size = Vector2(24.0, 24.0)
		top_h.add_child(ic)

		var short_n: String = _get_short_item_label(gid)
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
		_tighten_button_margins(chk_btn)

		var cap_gid: String = gid
		chk_btn.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			_toggle_expedition_gear(cap_gid)
			_rebuild_tab_expedition()
		)
		cv.add_child(chk_btn)

	# 4. [ SCHEDULE EXPEDITION ON NEXT DAY ] Toggle (y = 418..478)
	var sched_btn := Button.new()
	sched_btn.name = "ScheduleExpeditionButton"
	sched_btn.position = Vector2(344.0, 418.0)
	sched_btn.size = Vector2(338.0, 58.0)
	sched_btn.clip_text = true
	sched_btn.disabled = candidates.is_empty() or _available_targets.is_empty() or sel_depleted
	sched_btn.add_theme_font_size_override("font_size", 12)
	if sel_depleted:
		sched_btn.text = "[ DEPLETED — SELECT ANOTHER LANDMARK ]"
		_style_notebook_ink_button(sched_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
	elif _expedition_scheduled:
		var exp_m: Dictionary = _find_member_by_id(_selected_explorer_id)
		var m_nm: String = str(exp_m.get("name", "Explorer"))
		sched_btn.text = "[ ARMED: %s -> %s (%dd) ]" % [m_nm.to_upper(), p_name, est_days]
		_style_conelrad_button(sched_btn, COL_GREEN, COL_INK, Color("#fff8e6"))
	else:
		sched_btn.text = "[ SCHEDULE EXPEDITION ON NEXT DAY ]"
		_style_conelrad_button(sched_btn, Color("#2d362b"), COL_HAZARD, COL_HAZARD)

	sched_btn.pressed.connect(func() -> void:
		if sel_depleted:
			return
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
		_selected_gear_ids.clear()
		_selected_gear_ids.append(gid)
	else:
		if _count_non_suitcase_selected_gear() < 3:
			_selected_gear_ids.append(gid)
		else:
			for idx in range(_selected_gear_ids.size()):
				if _selected_gear_ids[idx] != "suitcase":
					_selected_gear_ids.remove_at(idx)
					break
			_selected_gear_ids.append(gid)

# ---------------------------------------------------------------------------
# TAB 5: WASTELAND STATION WAGON ESCAPE BLUEPRINT & 4 FACTION METERS (686x482)
# ---------------------------------------------------------------------------
func _rebuild_tab_escape() -> void:
	var root: Control = _tab_containers[TAB_ESCAPE]
	_clear_children(root)

	var chassis_tier: int = SaveManager.get_vehicle_chassis_tier()
	var can_escape: bool = GameState.can_escape_by_vehicle() and not GameState.get_all_living_members().is_empty()

	# 1. Header + Multi-Run Chassis Tier Badge (y = 0..28)
	var hdr := _make_ink_label("STATION WAGON ESCAPE BLUEPRINT & RESCUE", 17, COL_INK)
	hdr.position = Vector2(0.0, 2.0)
	hdr.size = Vector2(462.0, 24.0)
	hdr.clip_text = true
	root.add_child(hdr)

	var tier_pill := _make_parchment_card(Vector2(218.0, 26.0), Color("#252d26"), COL_HAZARD)
	tier_pill.position = Vector2(468.0, 0.0)
	tier_pill.size = Vector2(218.0, 26.0)
	var sb_tp: StyleBoxFlat = tier_pill.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb_tp != null:
		sb_tp.content_margin_top = 2.0
		sb_tp.content_margin_bottom = 2.0
		tier_pill.add_theme_stylebox_override("panel", sb_tp)
	root.add_child(tier_pill)
	var tier_lbl := _make_ink_label("META CHASSIS TIER %d / 3" % chassis_tier, 11, COL_HAZARD)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_pill.add_child(tier_lbl)

	# 2. Left: Cyanotype 1950s Station Wagon Schematic Blueprint (x = 0..312, y = 32..234)
	var bp_widget := _VehicleBlueprintWidget.new()
	bp_widget.position = Vector2(0.0, 32.0)
	bp_widget.size = Vector2(312.0, 202.0)
	root.add_child(bp_widget)

	# 3. Right: 4 Engine Parts + Fuel Cans + Engine Tune Checklist (x = 320..686, y = 32..234)
	var chk_card := _make_parchment_card(Vector2(366.0, 202.0), Color("#f6edd8"), COL_INK)
	chk_card.position = Vector2(320.0, 32.0)
	chk_card.size = Vector2(366.0, 202.0)
	var sb_ck: StyleBoxFlat = chk_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb_ck != null:
		sb_ck.content_margin_left = 8.0
		sb_ck.content_margin_right = 8.0
		sb_ck.content_margin_top = 6.0
		sb_ck.content_margin_bottom = 6.0
		chk_card.add_theme_stylebox_override("panel", sb_ck)
	root.add_child(chk_card)

	var ck_vbox := VBoxContainer.new()
	ck_vbox.add_theme_constant_override("separation", 6)
	chk_card.add_child(ck_vbox)

	var parts_grid := GridContainer.new()
	parts_grid.columns = 2
	parts_grid.add_theme_constant_override("h_separation", 6)
	parts_grid.add_theme_constant_override("v_separation", 6)
	ck_vbox.add_child(parts_grid)

	var part_defs := [
		{"id": "battery", "name": "Battery"},
		{"id": "radiator_hose", "name": "Radiator Hose"},
		{"id": "alternator", "name": "Alternator"},
		{"id": "spark_plugs", "name": "Spark Plugs"}
	]
	for pd_v in part_defs:
		var pd: Dictionary = pd_v
		var pid: String = str(pd["id"])
		var pname: String = str(pd["name"])
		var installed: bool = bool(GameState.vehicle_parts.get(pid, false))

		var p_cell := _make_parchment_card(
			Vector2(170.0, 56.0),
			Color("#e6f2de") if installed else COL_CARD_BG,
			COL_GREEN if installed else COL_INK_MUTED
		)
		p_cell.custom_minimum_size = Vector2(170.0, 56.0)
		var sb_pc: StyleBoxFlat = p_cell.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb_pc != null:
			sb_pc.content_margin_left = 6.0
			sb_pc.content_margin_right = 6.0
			sb_pc.content_margin_top = 4.0
			sb_pc.content_margin_bottom = 4.0
			p_cell.add_theme_stylebox_override("panel", sb_pc)
		parts_grid.add_child(p_cell)

		var ph := HBoxContainer.new()
		ph.add_theme_constant_override("separation", 6)
		p_cell.add_child(ph)

		var ic := _ItemIconWidget.new()
		ic.item_id = pid
		ic.custom_minimum_size = Vector2(28.0, 28.0)
		ph.add_child(ic)

		var pv := VBoxContainer.new()
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pv.add_theme_constant_override("separation", 2)
		ph.add_child(pv)
		var pn_lbl := _make_ink_label(pname, 11, COL_INK)
		pn_lbl.clip_text = true
		pv.add_child(pn_lbl)
		pv.add_child(_make_status_pill("INSTALLED ✓" if installed else "MISSING", COL_GREEN if installed else COL_STAMP_RED))

	# Fuel Cans (X / Y) & Engine Tuned Status Bar
	var fuel_ok: bool = GameState.fuel_cans >= GameState.fuel_needed
	var has_tune_cap: bool = GameState.has_vehicle_tuning_capability()
	var is_tuned: bool = GameState.vehicle_tuned

	var ft_row := _make_parchment_card(Vector2(346.0, 62.0), Color("#ece0c3"), COL_INK)
	ft_row.custom_minimum_size = Vector2(346.0, 62.0)
	ck_vbox.add_child(ft_row)

	var ft_v := VBoxContainer.new()
	ft_v.add_theme_constant_override("separation", 4)
	ft_row.add_child(ft_v)

	var fuel_h := HBoxContainer.new()
	fuel_h.add_theme_constant_override("separation", 6)
	ft_v.add_child(fuel_h)
	var f_ic := _ItemIconWidget.new()
	f_ic.item_id = "fuel"
	f_ic.custom_minimum_size = Vector2(22.0, 22.0)
	fuel_h.add_child(f_ic)
	fuel_h.add_child(_make_ink_label("Fuel Cans: %d / %d" % [GameState.fuel_cans, GameState.fuel_needed], 12, COL_GREEN if fuel_ok else COL_ORANGE))
	var scrap_lbl := _make_ink_label("  |  Scrap Stock: %d" % GameState.scrap_count, 11, COL_INK_MUTED)
	fuel_h.add_child(scrap_lbl)

	var tune_txt: String = (
		"Engine Tuned: YES ✓"
		if is_tuned
		else "Engine Tuned: NO (Click Tune Engine)"
	)
	ft_v.add_child(_make_ink_label(tune_txt, 11, COL_GREEN if is_tuned else COL_STAMP_RED))

	# 4. Workshop & Scrap Action Buttons Row (y = 240..280)
	var act_row := HBoxContainer.new()
	act_row.position = Vector2(0.0, 240.0)
	act_row.size = Vector2(686.0, 38.0)
	act_row.add_theme_constant_override("separation", 6)
	root.add_child(act_row)

	# [ Tune Engine ]
	var can_tune_now: bool = (not is_tuned) and (has_tune_cap or GameState.scrap_count > 0)
	var tune_btn := Button.new()
	tune_btn.name = "TuneEngineButton"
	tune_btn.custom_minimum_size = Vector2(224.0, 38.0)
	tune_btn.add_theme_font_size_override("font_size", 11)
	tune_btn.clip_text = true
	if is_tuned:
		tune_btn.text = "[ Engine Tuned ✓ ]"
		tune_btn.disabled = true
		_style_conelrad_button(tune_btn, COL_GREEN, COL_INK, COL_PARCHMENT)
	else:
		tune_btn.text = "[ Tune Engine ]" if (has_tune_cap or GameState.scrap_count <= 0) else "[ Tune Engine (1 Scrap) ]"
		tune_btn.disabled = not can_tune_now
		if can_tune_now:
			_style_conelrad_button(tune_btn, Color("#2f3e2c"), COL_HAZARD, COL_HAZARD)
		else:
			_style_notebook_ink_button(tune_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
	_tighten_button_margins(tune_btn)
	tune_btn.pressed.connect(_on_tune_engine_pressed)
	act_row.add_child(tune_btn)

	# [ Reinforce Hull (+12% for 1 Scrap) ]
	var can_reinforce: bool = (GameState.scrap_count > 0) and (GameState.bunker_structural_integrity < 100.0)
	var hull_btn := Button.new()
	hull_btn.name = "ReinforceHullButton"
	hull_btn.text = "[ Reinforce Hull (+12% · 1 Scrap) ]"
	hull_btn.custom_minimum_size = Vector2(224.0, 38.0)
	hull_btn.add_theme_font_size_override("font_size", 11)
	hull_btn.clip_text = true
	hull_btn.disabled = not can_reinforce
	if can_reinforce:
		_style_notebook_ink_button(hull_btn, Color("#e8dec2"), COL_GREEN, COL_INK)
	else:
		_style_notebook_ink_button(hull_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
	_tighten_button_margins(hull_btn)
	hull_btn.pressed.connect(_on_reinforce_hull_pressed)
	act_row.add_child(hull_btn)

	# [ Repair Broken Gear (1 Scrap) ]
	var broken_gid: String = _pick_first_broken_gear_id()
	var can_repair: bool = (GameState.scrap_count > 0) and (broken_gid != "")
	var rep_btn := Button.new()
	rep_btn.name = "RepairBrokenGearButton"
	rep_btn.text = (
		"[ Repair %s (1 Scrap) ]" % _get_short_item_label(broken_gid)
		if broken_gid != ""
		else "[ Repair Broken Gear (1 Scrap) ]"
	)
	rep_btn.custom_minimum_size = Vector2(226.0, 38.0)
	rep_btn.add_theme_font_size_override("font_size", 11)
	rep_btn.clip_text = true
	rep_btn.disabled = not can_repair
	if can_repair:
		_style_notebook_ink_button(rep_btn, Color("#f2e2be"), COL_ORANGE, COL_INK)
	else:
		_style_notebook_ink_button(rep_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
	_tighten_button_margins(rep_btn)
	rep_btn.pressed.connect(func() -> void:
		_on_repair_broken_gear_pressed(broken_gid)
	)
	act_row.add_child(rep_btn)

	# 5. 4 Faction Rescue Meters (y = 286..420)
	var fac_hdr := _make_ink_label("FACTION EXTRACTION TRACKS (3 / 3 STAGES TRIGGERS RESCUE):", 11, COL_INK_MUTED)
	fac_hdr.position = Vector2(2.0, 286.0)
	fac_hdr.size = Vector2(680.0, 16.0)
	root.add_child(fac_hdr)

	var fac_grid := GridContainer.new()
	fac_grid.columns = 2
	fac_grid.position = Vector2(0.0, 304.0)
	fac_grid.size = Vector2(686.0, 114.0)
	fac_grid.add_theme_constant_override("h_separation", 8)
	fac_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(fac_grid)

	var faction_defs := [
		{"key": "military", "title": "Military (CONELRAD)", "sub": "Radio signals & Police/Fire intel", "col": Color("#3d7042")},
		{"key": "sanctuary", "title": "Sanctuary Parish", "sub": "OSM Churches & School outreach", "col": Color("#b88418")},
		{"key": "scientist", "title": "Scientist Institute", "sub": "Sharikov & Vault telemetry", "col": Color("#2c76a8")},
		{"key": "raider_pact", "title": "Smuggler Convoy", "sub": "Highway Caravan trade pacts", "col": Color("#b84b27")}
	]
	for fd_v in faction_defs:
		var fd: Dictionary = fd_v
		var fkey: String = str(fd["key"])
		var stage: int = clampi(int(GameState.rescue_chains.get(fkey, 0)), 0, 3)
		var fcol: Color = fd["col"]

		var fcard := _make_parchment_card(Vector2(339.0, 52.0), COL_CARD_BG, fcol if stage > 0 else COL_INK_MUTED)
		fcard.custom_minimum_size = Vector2(339.0, 52.0)
		var sb_fc: StyleBoxFlat = fcard.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb_fc != null:
			sb_fc.content_margin_left = 8.0
			sb_fc.content_margin_right = 8.0
			sb_fc.content_margin_top = 4.0
			sb_fc.content_margin_bottom = 4.0
			fcard.add_theme_stylebox_override("panel", sb_fc)
		fac_grid.add_child(fcard)

		var fh := HBoxContainer.new()
		fh.add_theme_constant_override("separation", 8)
		fcard.add_child(fh)

		var fv := VBoxContainer.new()
		fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fv.add_theme_constant_override("separation", 1)
		fh.add_child(fv)
		fv.add_child(_make_ink_label(str(fd["title"]), 12, COL_INK))
		var fsub := _make_ink_label(str(fd["sub"]), 10, COL_INK_MUTED)
		fsub.clip_text = true
		fv.add_child(fsub)

		var meter_str: String = "%s %d/3" % [
			("■".repeat(stage) + "□".repeat(3 - stage)),
			stage
		]
		fh.add_child(_make_status_pill(meter_str, fcol if stage > 0 else COL_INK_MUTED))

	# 6. Bold [ IGNITE STATION WAGON — ESCAPE NOW! ] Button (y = 426..478)
	var ignite_btn := Button.new()
	ignite_btn.name = "IgniteStationWagonButton"
	ignite_btn.position = Vector2(0.0, 426.0)
	ignite_btn.size = Vector2(686.0, 52.0)
	ignite_btn.disabled = not can_escape
	ignite_btn.add_theme_font_size_override("font_size", 15)
	ignite_btn.text = "[ IGNITE STATION WAGON — ESCAPE NOW! ]"
	if can_escape:
		_style_conelrad_button(ignite_btn, COL_GREEN, COL_HAZARD, Color("#fffbe8"))
	else:
		_style_notebook_ink_button(ignite_btn, COL_PARCHMENT_DARK, COL_INK_MUTED, COL_INK_MUTED)
		ignite_btn.tooltip_text = "Install all 4 Engine Parts, collect %d Fuel Cans, and have Toolbox/Book/Tuned Engine to escape!" % GameState.fuel_needed
	ignite_btn.pressed.connect(_on_ignite_vehicle_escape_pressed)
	root.add_child(ignite_btn)

func _on_tune_engine_pressed() -> void:
	SoundManager.play_sfx("pickup")
	var msg: String = BunkerSim.tune_escape_vehicle()
	if msg != "" and is_instance_valid(_toast_overlay):
		_toast_overlay.show_status_toast("✓ ENGINE TUNED & TIMED!", COL_GREEN)
	_rebuild_tab_escape()
	_refresh_tab_headers_and_footer()

func _on_reinforce_hull_pressed() -> void:
	SoundManager.play_sfx("hatch_drop")
	var msg: String = BunkerSim.reinforce_hull_with_scrap()
	if msg != "" and is_instance_valid(_toast_overlay):
		_toast_overlay.show_status_toast("✓ HULL REINFORCED (%.0f%%)" % GameState.bunker_structural_integrity, COL_GREEN)
	_rebuild_tab_escape()
	_rebuild_tab_daily_log()

func _on_repair_broken_gear_pressed(broken_gid: String) -> void:
	if broken_gid == "":
		return
	SoundManager.play_sfx("pickup")
	var msg: String = BunkerSim.repair_item_with_scrap(broken_gid)
	if msg != "" and is_instance_valid(_toast_overlay):
		_toast_overlay.show_status_toast("✓ REPAIRED %s!" % _get_short_item_label(broken_gid).to_upper(), COL_GREEN)
	_rebuild_all_tabs()

func _on_ignite_vehicle_escape_pressed() -> void:
	if _in_day_transition or not GameState.can_escape_by_vehicle():
		return
	var escaped: bool = BunkerSim.execute_vehicle_escape()
	if escaped:
		SoundManager.play_sfx("victory")
		GameState.request_screen(GameState.SCREEN_SUMMARY)

# ---------------------------------------------------------------------------
# END DAY TURN RESOLUTION & DRAMATIC "DAY <N>" CURTAIN
# ---------------------------------------------------------------------------
func _on_end_day_pressed() -> void:
	if _in_day_transition:
		return
	SoundManager.play_sfx("page_turn")

	var next_day_preview: int = GameState.day + 1
	var house_sub: String = str(GameState.selected_house.get("name", GameState.current_neighborhood_label))
	_curtain_duration = 0.62 if GameState.demo_mode else 0.85
	_curtain_timer = 0.0
	_curtain_midpoint_fired = false
	_in_day_transition = true
	_curtain_overlay.configure(next_day_preview, house_sub)
	_curtain_overlay.visible = true
	_curtain_overlay.set_progress(0.0)

func _on_curtain_midpoint() -> void:
	# 1. Resolve today's event if Day >= 1, shelter is occupied, and an event has options
	var event_outcome: Dictionary = {}
	var opts: Array = _get_event_options(_current_event)
	if GameState.day >= 1 and not GameState.get_living_bunker_members().is_empty() and not _current_event.is_empty() and not opts.is_empty():
		if _selected_event_choice_id == "":
			for i in range(opts.size() - 1, -1, -1):
				if opts[i] is Dictionary and _is_event_option_available(opts[i] as Dictionary):
					_selected_event_choice_id = str((opts[i] as Dictionary).get("id", ""))
					break
		if _selected_event_choice_id == "":
			_selected_event_choice_id = str((opts[opts.size() - 1] as Dictionary).get("id", ""))
		event_outcome = EventDeck.resolve_event(_current_event, _selected_event_choice_id, GameState.rng)

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
	var specialty_actions: Dictionary = {}
	if not _planned_antibiotics_ids.is_empty() and GameState.antibiotics_count > 0:
		specialty_actions["antibiotics_target_id"] = _planned_antibiotics_ids.duplicate()
	if not _planned_antirad_ids.is_empty() and GameState.antirad_count > 0:
		specialty_actions["antirad_target_id"] = _planned_antirad_ids.duplicate()

	# 3. Build expedition_launch payload if scheduled and target is not depleted
	var expedition_launch: Dictionary = {}
	if _expedition_scheduled and GameState.active_expedition.is_empty() and _selected_explorer_id != "" and not _available_targets.is_empty():
		var safe_poi_idx: int = clampi(_selected_poi_index, 0, _available_targets.size() - 1)
		var launch_poi: Dictionary = _available_targets[safe_poi_idx]
		if not bool(launch_poi.get("depleted", false)):
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

	if GameState.demo_mode and GameState.day == 3 and not GameState.active_expedition.is_empty():
		if int(GameState.active_expedition.get("days_remaining", 1)) > 1:
			GameState.active_expedition["days_remaining"] = 1

	# 4. Advance Bunker Simulation!
	var prev_log_count: int = GameState.daily_log_entries.size()
	var day_lines: Array = BunkerSim.advance_day(clamped_rations, med_target, event_outcome, expedition_launch, specialty_actions)

	if not expedition_launch.is_empty() and GameState.active_expedition.is_empty():
		var launch_note: String = ExpeditionEngine.start_expedition(
			str(expedition_launch["member_id"]),
			int(expedition_launch["poi_index"]),
			expedition_launch["gear_ids"] as Array
		)
		if launch_note != "":
			day_lines.append(launch_note)

	if GameState.daily_log_entries.size() == prev_log_count and not day_lines.is_empty():
		GameState.daily_log_entries.append({
			"day": GameState.day,
			"title": "DAY %d — SHELTER REPORT" % GameState.day,
			"lines": day_lines
		})

	_curtain_overlay.configure(GameState.day, str(GameState.selected_house.get("name", GameState.current_neighborhood_label)))

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

func _run_demo_sequence() -> void:
	_set_notebook_open(false)
	await get_tree().create_timer(1.50).timeout
	if not is_inside_tree():
		return

	_set_notebook_open(true)
	_switch_tab(TAB_LOG, true)
	await get_tree().create_timer(0.85).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_RATIONS, true)
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	_demo_apply_smart_rations()
	await get_tree().create_timer(0.50).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_DILEMMA, true)
	_demo_pick_best_event_choice()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_EXPEDITION, true)
	await get_tree().create_timer(0.50).timeout
	if not is_inside_tree():
		return

	_demo_pick_best_osm_grocery_or_church()
	_rebuild_tab_expedition()
	await get_tree().create_timer(0.50).timeout
	if not is_inside_tree():
		return

	_demo_pack_expedition_gear()
	_rebuild_tab_expedition()
	await get_tree().create_timer(0.50).timeout
	if not is_inside_tree():
		return

	_expedition_scheduled = true
	SoundManager.play_sfx("button_click")
	_rebuild_tab_expedition()
	_refresh_tab_headers_and_footer()
	await get_tree().create_timer(0.50).timeout
	if not is_inside_tree():
		return

	# End Day 1 -> Day 2
	_on_end_day_pressed()
	await _wait_for_day_curtain()
	if not is_inside_tree():
		return

	# --- DAY 2: Daily Report -> Live Radar -> Escape Blueprint -> Care & Bonds -> Dilemma -> End Day 2 ---
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_EXPEDITION, true)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_ESCAPE, true)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_RATIONS, true)
	_demo_apply_smart_rations()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_DILEMMA, true)
	_demo_pick_best_event_choice()
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return

	# End Day 2 -> Day 3
	_on_end_day_pressed()
	await _wait_for_day_curtain()
	if not is_inside_tree():
		return

	# --- DAY 3: Daily Report -> Care & Bonds -> Dilemma -> End Day 3 ---
	await get_tree().create_timer(0.60).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_RATIONS, true)
	_demo_apply_smart_rations()
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	_switch_tab(TAB_DILEMMA, true)
	_demo_pick_best_event_choice()
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return

	# End Day 3 -> Day 4
	_on_end_day_pressed()
	await _wait_for_day_curtain()
	if not is_inside_tree():
		return

	# --- DAY 4: Explorer Return Log + Restocked Bunker Shelves & Reunited Family! ---
	_switch_tab(TAB_LOG, false)
	await get_tree().create_timer(0.95).timeout
	if not is_inside_tree():
		return

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
		if bool(td.get("depleted", false)):
			continue
		var cat: String = str(td.get("category", "")).to_lower()
		var t_days: int = int(td.get("travel_days", 2))
		var sc: float = 0.0
		if cat == "grocery" or cat == "church" or cat == "doctor":
			sc += 100.0
		elif cat == "pharmacy" or cat == "fuel_auto":
			sc += 70.0
		sc -= float(t_days) * 20.0
		if sc > best_score:
			best_score = sc
			best_idx = i
	_selected_poi_index = best_idx

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
	var opts: Array = _get_event_options(_current_event)
	if opts.is_empty():
		return
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
# SHARED HELPERS, CATEGORY METADATA & UI FACTORIES
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
		if int(m.get("breakdown_days", 0)) > 0:
			continue
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

func _has_handy_bunker_member() -> bool:
	for m_v in GameState.get_living_bunker_members():
		if m_v is Dictionary:
			if str((m_v as Dictionary).get("trait", "")).to_lower() == "handy":
				return true
	return false

func _pick_first_broken_gear_id() -> String:
	var priority_order: Array[String] = [
		"gas_mask", "rifle", "radio", "suitcase", "toolbox", "map",
		"axe", "flashlight", "book", "cards", "checkers", "harmonica"
	]
	for gid in priority_order:
		if _is_item_owned_but_broken(gid):
			return gid
	for raw_k in GameState.bunker_items.keys():
		var k_s: String = str(raw_k)
		if _is_item_owned_but_broken(k_s):
			return k_s
	return ""

func _get_event_options(ev: Dictionary) -> Array:
	if ev.has("options") and ev["options"] is Array:
		return ev["options"] as Array
	if ev.has("choices") and ev["choices"] is Array:
		return ev["choices"] as Array
	return []

func _has_any_bonded_bunker_pair(min_score: int = 45) -> bool:
	var living: Array = GameState.get_living_bunker_members()
	for i in range(living.size()):
		for j in range(i + 1, living.size()):
			var ida: String = str((living[i] as Dictionary).get("id", ""))
			var idb: String = str((living[j] as Dictionary).get("id", ""))
			if GameState.get_relationship(ida, idb) >= min_score:
				return true
	return false

func _is_event_option_available(opt: Dictionary) -> bool:
	if opt.has("available"):
		return bool(opt.get("available", true))
	if bool(opt.get("cooperate", false)) or bool(opt.get("requires_bond", false)):
		if not _has_any_bonded_bunker_pair(int(opt.get("min_bond", 45))):
			return false
	var req: String = str(opt.get("item_id", opt.get("required_item", "")))
	if req == "":
		return true
	if req == "vehicle_part":
		return GameState.get_vehicle_parts_owned_count() > 0
	return GameState.has_working_item(req)

func _is_item_owned_but_broken(item_id: String) -> bool:
	if GameState.bunker_items.has(item_id):
		var d: Dictionary = GameState.bunker_items[item_id]
		return bool(d.get("owned", false)) and bool(d.get("broken", false))
	return false

func _get_short_item_label(item_id: String) -> String:
	var info: Dictionary = ItemDB.get_item_info(item_id)
	var sn: String = str(info.get("short_name", ""))
	if sn != "":
		return sn
	match item_id:
		"antibiotics":
			return "Antibiotics"
		"antirad":
			return "Anti-Rad"
		"scrap":
			return "Scrap"
		"fuel":
			return "Fuel Can"
		"radiator_hose":
			return "Rad Hose"
		"spark_plugs":
			return "Spark Plugs"
	return item_id.replace("_", " ").capitalize()

func _get_poi_ring(poi: Dictionary) -> int:
	var r: int = int(poi.get("ring", 0))
	if r >= 1 and r <= 3:
		return r
	var dm: float = float(poi.get("distance_m", 250.0))
	if dm < 500.0:
		return 1
	elif dm < 3500.0:
		return 2
	return 3

static func _format_distance_m_or_km(dist_m: float) -> String:
	if dist_m >= 1000.0:
		return "%.1f km" % (dist_m / 1000.0)
	return "%d m" % int(round(dist_m))

static func _short_category_tag(cat: String) -> String:
	var c: String = cat.to_lower()
	if c.contains("doc") or c.contains("clin") or c.contains("hosp") or c.contains("urgent"):
		return "DOCTOR"
	if c.contains("groc") or c.contains("super") or c.contains("market") or c.contains("bak"):
		return "GROCERY"
	if c.contains("fuel") or c.contains("auto") or c.contains("gas") or c.contains("car"):
		return "GAS/AUTO"
	if c.contains("pharm") or c.contains("drug"):
		return "PHARMACY"
	if c.contains("hard") or c.contains("lumber"):
		return "HARDWARE"
	if c.contains("civic") or c.contains("polic") or c.contains("fire") or c.contains("ems"):
		return "POLICE/FD"
	if c.contains("church") or c.contains("parish") or c.contains("worship"):
		return "CHURCH"
	if c.contains("school") or c.contains("lib"):
		return "SCHOOL"
	return "HOUSE"

static func _human_category_name(cat: String) -> String:
	var c: String = cat.to_lower()
	if c.contains("doc") or c.contains("clin") or c.contains("hosp") or c.contains("urgent"):
		return "Doctor / Clinic"
	if c.contains("groc") or c.contains("super") or c.contains("market") or c.contains("bak"):
		return "Grocery"
	if c.contains("fuel") or c.contains("auto") or c.contains("gas") or c.contains("car"):
		return "Gas / Auto"
	if c.contains("pharm") or c.contains("drug"):
		return "Pharmacy"
	if c.contains("hard") or c.contains("lumber"):
		return "Hardware"
	if c.contains("civic") or c.contains("polic") or c.contains("fire") or c.contains("ems"):
		return "Police / Fire"
	if c.contains("church") or c.contains("parish") or c.contains("worship"):
		return "Church"
	if c.contains("school") or c.contains("lib"):
		return "School"
	return "Neighbor House"

static func _get_category_color(cat: String) -> Color:
	var c: String = cat.to_lower()
	if c.contains("doc") or c.contains("clin") or c.contains("hosp") or c.contains("urgent"):
		return Color("#ff5964")
	if c.contains("groc") or c.contains("super") or c.contains("market") or c.contains("bak"):
		return Color("#7ec850")
	if c.contains("fuel") or c.contains("auto") or c.contains("gas") or c.contains("car"):
		return Color("#ff9f1c")
	if c.contains("pharm") or c.contains("drug"):
		return Color("#d96ce8")
	if c.contains("hard") or c.contains("lumber"):
		return Color("#c98a4b")
	if c.contains("civic") or c.contains("polic") or c.contains("fire") or c.contains("ems"):
		return Color("#4ea8de")
	if c.contains("church") or c.contains("parish") or c.contains("worship"):
		return Color("#f5d451")
	if c.contains("school") or c.contains("lib"):
		return Color("#72ddf7")
	return Color("#cfc2a5")

static func _get_category_gameplay_impact(cat: String) -> String:
	var c: String = cat.to_lower()
	if c.contains("doc") or c.contains("clin") or c.contains("hosp") or c.contains("urgent"):
		return "Impact: Antibiotics, Medkits & heals -1 Injury/Sickness on-site!"
	if c.contains("groc") or c.contains("super") or c.contains("market") or c.contains("bak"):
		return "Impact: Big 3–6 Soup & Water haul; unlocks Trader Caravans!"
	if c.contains("fuel") or c.contains("auto") or c.contains("gas") or c.contains("car"):
		return "Impact: Fuel Cans, Station Wagon Engine Parts & Salvaged Scrap!"
	if c.contains("pharm") or c.contains("drug"):
		return "Impact: Anti-Rad Pills (-35 Rads), Medkits & calming tonics!"
	if c.contains("hard") or c.contains("lumber"):
		return "Impact: Salvaged Scrap, Toolbox, Axe, Padlock & Engine Parts!"
	if c.contains("civic") or c.contains("polic") or c.contains("fire") or c.contains("ems"):
		return "Impact: Armory Rifle, Ammo, Gas Mask, Radio & +1 Military intel!"
	if c.contains("church") or c.contains("parish") or c.contains("worship"):
		return "Impact: Safe sanctuary: +1 Parish Rescue & +10 Family Harmony!"
	if c.contains("school") or c.contains("lib"):
		return "Impact: Maps (-1d Ring 2/3 travel!), Books, Checkers & Lights!"
	return "Impact: Fast 1-day Ring 1 sweep for Soup, Water & home gear."

func _get_member_relationship_pill_info(member: Dictionary, member_id: String) -> Dictionary:
	if bool(member.get("betrayed", false)):
		return {"text": "Betrayed", "color": COL_STAMP_RED}
	if not bool(member.get("in_bunker", false)) and not bool(member.get("on_expedition", false)):
		return {"text": "Absent", "color": COL_INK_MUTED}
	if not bool(member.get("alive", true)):
		return {"text": "Mourned", "color": COL_INK_MUTED}
	var avg_rel: int = GameState.get_member_avg_relationship(member_id)
	var tier: String = GameState.get_relationship_tier(avg_rel)
	match tier:
		"Devoted":
			return {"text": "Devoted", "color": COL_BOND_PINK}
		"Loyal":
			return {"text": "Loyal", "color": COL_GREEN}
		"Resentful":
			return {"text": "Resentful", "color": COL_ORANGE}
		"Hostile":
			return {"text": "Hostile", "color": COL_STAMP_RED}
		_:
			return {"text": "Neutral", "color": Color("#6d6455")}

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
	if bool(member.get("betrayed", false)):
		return {"text": "BETRAYED", "color": COL_STAMP_RED}
	if not bool(member.get("in_bunker", false)):
		return {"text": "LEFT BEHIND", "color": COL_INK_MUTED}
	if not bool(member.get("alive", true)):
		return {"text": "FALLEN", "color": COL_STAMP_RED}
	if bool(member.get("on_expedition", false)):
		return {"text": "SCAVENGING", "color": COL_WATER}
	if int(member.get("breakdown_days", 0)) > 0:
		return {"text": "BREAKDOWN", "color": Color("#7d389c")}
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
	var lbl := _make_ink_label(text_val, 9, Color("#fffaf0"))
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

func _make_compact_supply_chip(item_id: String, label_txt: String, accent: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 4)
	var ic := _ItemIconWidget.new()
	ic.item_id = item_id
	ic.custom_minimum_size = Vector2(24.0, 24.0)
	hb.add_child(ic)
	var lbl := _make_ink_label(label_txt, 11, accent)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(lbl)
	return hb

func _tighten_button_margins(btn: Button) -> void:
	for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		if btn.has_theme_stylebox_override(st_name):
			var sb_c: StyleBoxFlat = btn.get_theme_stylebox(st_name).duplicate() as StyleBoxFlat
			if sb_c != null:
				sb_c.content_margin_left = 4.0
				sb_c.content_margin_right = 4.0
				sb_c.content_margin_top = 2.0
				sb_c.content_margin_bottom = 2.0
				btn.add_theme_stylebox_override(st_name, sb_c)

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
# INNER VISUAL WIDGETS (HUD, TOASTS, NOTEBOOK, MULTI-RING RADAR, BLUEPRINT)
# ===========================================================================

class _TopHudBar extends Control:
	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(0.0, 0.0, 1280.0, 52.0), Color("#171a17"), true)
		draw_line(Vector2(0.0, 51.0), Vector2(1280.0, 51.0), Color("#f2b82e"), 2.0)

		# 1. DAY <N> Stencil Badge (12..110)
		var day_r := Rect2(12.0, 8.0, 98.0, 36.0)
		draw_rect(day_r, Color("#f2b82e"), true)
		draw_rect(day_r, Color("#1b1917"), false, 2.0)
		draw_string(font, day_r.position + Vector2(0.0, 24.0), "DAY %d" % GameState.day, HORIZONTAL_ALIGNMENT_CENTER, day_r.size.x, 16, Color("#1b1917"))

		# 2. House Address Badge (116..376)
		var house_r := Rect2(116.0, 8.0, 260.0, 36.0)
		draw_rect(house_r, Color("#242a24"), true)
		draw_rect(house_r, Color("#565f55"), false, 1.5)
		var h_name: String = str(GameState.selected_house.get("name", "Civil Defense Shelter"))
		var shelter_max_w: float = house_r.size.x - 14.0
		var shelter_str: String = _fit_hud_ellipsis(font, "SHELTER: " + h_name, 11, shelter_max_w)
		draw_string(font, house_r.position + Vector2(7.0, 23.0), shelter_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f2e6ce"))

		# 3. Radiation Sv/hr Badge (382..508)
		var rad_r := Rect2(382.0, 8.0, 126.0, 36.0)
		var sv: float = GameState.surface_radiation_sv
		var sv_col := Color("#7ec850") if sv < 2.0 else (Color("#f2b82e") if sv < 5.5 else Color("#e05a2b"))
		draw_rect(rad_r, Color("#242a24"), true)
		draw_rect(rad_r, sv_col, false, 1.5)
		draw_string(font, rad_r.position + Vector2(0.0, 23.0), "RAD: %.1f Sv/h" % sv, HORIZONTAL_ALIGNMENT_CENTER, rad_r.size.x, 12, sv_col)

		# 4. Bunker Temp Badge (514..614)
		var tmp_r := Rect2(514.0, 8.0, 100.0, 36.0)
		var tc: float = GameState.bunker_temp_c
		var tc_col := Color("#8ad8ff") if tc < 2.0 else (Color("#f2e6ce") if tc <= 28.0 else Color("#e05a2b"))
		draw_rect(tmp_r, Color("#242a24"), true)
		draw_rect(tmp_r, tc_col, false, 1.5)
		draw_string(font, tmp_r.position + Vector2(0.0, 23.0), "TEMP: %.0f°C" % tc, HORIZONTAL_ALIGNMENT_CENTER, tmp_r.size.x, 12, tc_col)

		# 5. Soup Count Badge (620..754)
		var soup_r := Rect2(620.0, 8.0, 134.0, 36.0)
		draw_rect(soup_r, Color("#242a24"), true)
		draw_rect(soup_r, Color("#e05a2b"), false, 1.5)
		ItemDB.draw_item_icon(self, "soup", soup_r.position + Vector2(18.0, 18.0), 22.0, false)
		draw_string(font, soup_r.position + Vector2(34.0, 23.0), "Soup: %s" % GameState.format_quarters_as_cans(GameState.soup_quarters), HORIZONTAL_ALIGNMENT_LEFT, 94.0, 12, Color("#f2e6ce"))

		# 6. Water Count Badge (760..894) — cleanly left of [ SAVE ] at x=902!
		var wat_r := Rect2(760.0, 8.0, 134.0, 36.0)
		draw_rect(wat_r, Color("#242a24"), true)
		draw_rect(wat_r, Color("#3b8ec2"), false, 1.5)
		ItemDB.draw_item_icon(self, "water", wat_r.position + Vector2(18.0, 18.0), 22.0, false)
		draw_string(font, wat_r.position + Vector2(34.0, 23.0), "Water: %s" % GameState.format_quarters_as_cans(GameState.water_quarters), HORIZONTAL_ALIGNMENT_LEFT, 94.0, 12, Color("#f2e6ce"))

	static func _fit_hud_ellipsis(font: Font, text: String, font_size: int, max_w: float) -> String:
		if max_w <= 0.0 or text == "":
			return ""
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
			return text
		var ell: String = "..."
		var trimmed: String = text
		while trimmed.length() > 1:
			trimmed = trimmed.substr(0, trimmed.length() - 1).strip_edges(false, true)
			var candidate: String = trimmed + ell
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
				return candidate
		return ell

class _ToastOverlay extends Control:
	var _status_text: String = ""
	var _status_col: Color = Color("#4f8f32")
	var _status_timer: float = 0.0
	var _ach_queue: Array = []
	var _active_ach: Dictionary = {}
	var _ach_timer: float = 0.0
	const ACH_DURATION: float = 3.8

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func show_status_toast(msg: String, accent: Color) -> void:
		_status_text = msg
		_status_col = accent
		_status_timer = 2.4
		queue_redraw()

	func push_achievement_toast(title: String, desc: String) -> void:
		_ach_queue.append({"title": title, "desc": desc})
		if _active_ach.is_empty():
			_pop_next_achievement()
		queue_redraw()

	func _pop_next_achievement() -> void:
		if _ach_queue.is_empty():
			_active_ach = {}
			_ach_timer = 0.0
			return
		_active_ach = _ach_queue.pop_front()
		_ach_timer = ACH_DURATION

	func _process(delta: float) -> void:
		var dirty: bool = false
		if _status_timer > 0.0:
			_status_timer = maxf(0.0, _status_timer - delta)
			dirty = true
		if not _active_ach.is_empty():
			_ach_timer -= delta
			dirty = true
			if _ach_timer <= 0.0:
				_pop_next_achievement()
		if dirty:
			queue_redraw()

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		# 1. Quick Save / Action Toast Pill (top-right below HUD)
		if _status_timer > 0.0 and _status_text != "":
			var a_st: float = clampf(_status_timer / 0.45, 0.0, 1.0)
			var sr := Rect2(860.0, 56.0, 240.0, 30.0)
			draw_rect(Rect2(sr.position + Vector2(3.0, 3.0), sr.size), Color(0.04, 0.05, 0.04, 0.65 * a_st), true)
			draw_rect(sr, Color(0.11, 0.14, 0.11, 0.96 * a_st), true)
			draw_rect(sr, Color(_status_col.r, _status_col.g, _status_col.b, a_st), false, 2.0)
			draw_string(font, sr.position + Vector2(0.0, 20.0), _status_text, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 12, Color(0.95, 0.96, 0.88, a_st))

		# 2. Achievement Unlocked Commendation Banner (top-left below HUD, clear of Notebook!)
		if not _active_ach.is_empty():
			var elapsed: float = ACH_DURATION - _ach_timer
			var slide_t: float = clampf(elapsed / 0.24, 0.0, 1.0)
			var fade_t: float = clampf(_ach_timer / 0.45, 0.0, 1.0)
			var alpha: float = minf(slide_t, fade_t)
			var y_off: float = (1.0 - slide_t) * -18.0
			var ar := Rect2(18.0, 58.0 + y_off, 468.0, 62.0)

			draw_rect(Rect2(ar.position + Vector2(4.0, 5.0), ar.size), Color(0.03, 0.04, 0.03, 0.72 * alpha), true)
			draw_rect(ar, Color(0.12, 0.14, 0.12, 0.96 * alpha), true)
			draw_rect(Rect2(ar.position, Vector2(6.0, ar.size.y)), Color(0.95, 0.74, 0.18, alpha), true)
			draw_rect(ar, Color(0.95, 0.74, 0.18, alpha), false, 2.2)

			# Civil Defense Gold Star Medal Icon
			var mc := ar.position + Vector2(34.0, 31.0)
			draw_circle(mc, 19.0, Color(0.95, 0.74, 0.18, alpha))
			draw_arc(mc, 19.0, 0.0, TAU, 24, Color(0.11, 0.10, 0.09, alpha), 2.0)
			var star_pts := PackedVector2Array()
			for si in range(10):
				var sa: float = -PI * 0.5 + float(si) * TAU / 10.0
				var rad_s: float = 12.0 if (si % 2 == 0) else 5.2
				star_pts.append(mc + Vector2(cos(sa) * rad_s, sin(sa) * rad_s))
			draw_colored_polygon(star_pts, Color(0.14, 0.12, 0.10, alpha))

			draw_string(font, ar.position + Vector2(62.0, 19.0), "ACHIEVEMENT UNLOCKED!", HORIZONTAL_ALIGNMENT_LEFT, 396.0, 11, Color(0.95, 0.74, 0.18, alpha))
			draw_string(font, ar.position + Vector2(62.0, 37.0), str(_active_ach.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, 396.0, 14, Color(0.96, 0.92, 0.82, alpha))
			var desc_s: String = str(_active_ach.get("desc", ""))
			if desc_s != "":
				draw_string(font, ar.position + Vector2(62.0, 53.0), desc_s, HORIZONTAL_ALIGNMENT_LEFT, 396.0, 10, Color(0.82, 0.78, 0.68, alpha))

class _NotebookBackdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(6.0, 8.0, size.x + 4.0, size.y + 4.0), Color(0.04, 0.04, 0.03, 0.65), true)
		draw_rect(Rect2(-4.0, -2.0, size.x + 10.0, size.y + 8.0), Color("#2c261e"), true)
		draw_rect(Rect2(-4.0, -2.0, size.x + 10.0, size.y + 8.0), Color("#1b1917"), false, 2.5)

		draw_rect(Rect2(4.0, 4.0, size.x, size.y), Color("#cbb993"), true)
		draw_rect(Rect2(2.0, 2.0, size.x, size.y), Color("#dfd0ae"), true)

		var page_r := Rect2(0.0, 0.0, size.x, size.y)
		draw_rect(page_r, Color("#efe3c8"), true)
		draw_rect(page_r, Color("#1d1a16"), false, 2.2)

		for ly in range(44, int(size.y) - 58, 24):
			draw_line(Vector2(28.0, float(ly)), Vector2(size.x - 14.0, float(ly)), Color(0.55, 0.49, 0.38, 0.22), 1.0)
		draw_line(Vector2(30.0, 10.0), Vector2(30.0, size.y - 10.0), Color(0.76, 0.30, 0.24, 0.35), 1.4)
		draw_line(Vector2(34.0, 498.0), Vector2(size.x - 14.0, 498.0), Color(0.18, 0.15, 0.12, 0.45), 1.5)

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
			Vector2(5.0, 2.0),
			Vector2(size.x - 5.0, 2.0),
			Vector2(size.x, size.y)
		])
		draw_colored_polygon(poly, fill)
		if is_active_tab:
			draw_line(Vector2(5.0, 3.0), Vector2(size.x - 5.0, 3.0), Color("#f2b82e"), 4.0)
			draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3]]), Color("#1d1a16"), 2.2)
		else:
			draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color("#1d1a16"), 1.8)

		draw_string(
			font,
			Vector2(2.0, 21.0),
			tab_title,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x - (28.0 if badge_text != "" else 4.0),
			11,
			Color("#1d1a16")
		)

		if badge_text != "":
			var br := Rect2(size.x - 30.0, 7.0, 24.0, 15.0)
			draw_rect(br, badge_color, true)
			draw_rect(br, Color("#1d1a16"), false, 1.1)
			draw_string(font, br.position + Vector2(0.0, 11.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 8, Color("#fff8e8"))

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
	var ring_filter: int = 0
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
				if hit >= 0 and hit < targets.size():
					var hit_td: Dictionary = targets[hit]
					if not bool(hit_td.get("depleted", false)):
						selected_index = hit
						target_clicked.emit(hit)

	func _is_idx_visible_for_filter(idx: int) -> bool:
		if ring_filter <= 0 or idx < 0 or idx >= targets.size():
			return true
		var td: Dictionary = targets[idx]
		var r: int = int(td.get("ring", 0))
		if r < 1 or r > 3:
			var dm: float = float(td.get("distance_m", 250.0))
			r = 1 if dm < 500.0 else (2 if dm < 3500.0 else 3)
		return r == ring_filter

	func _pick_pin(pt: Vector2) -> int:
		var best: int = -1
		var best_d: float = 15.0
		for i in range(_pin_positions.size()):
			if not _is_idx_visible_for_filter(i):
				continue
			var d: float = _pin_positions[i].distance_to(pt)
			if d < best_d:
				best_d = d
				best = i
		return best

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("#131d16"), true)
		draw_rect(rect, Color("#1d1a16"), false, 2.2)

		var center := Vector2(size.x * 0.5, size.y * 0.47)
		var max_r: float = minf(size.x, size.y) * 0.35
		var safe_rect := Rect2(24.0, 26.0, maxf(16.0, size.x - 48.0), maxf(16.0, size.y - 62.0))

		# 3 Multi-Ring Tactical Range Circles: R1 (<0.5km), R2 (0.5-3.5km), R3 (3.5-10km)
		var ring_specs := [
			{"rf": 0.34, "lbl": "R1 <0.5km", "col": Color(0.45, 0.85, 0.45, 0.30)},
			{"rf": 0.67, "lbl": "R2 3.5km", "col": Color(0.92, 0.76, 0.25, 0.26)},
			{"rf": 1.00, "lbl": "R3 10km", "col": Color(0.90, 0.45, 0.22, 0.26)}
		]
		for rs_v in ring_specs:
			var rs: Dictionary = rs_v
			var rr: float = max_r * float(rs["rf"])
			draw_arc(center, rr, 0.0, TAU, 44, rs["col"], 1.2)
			draw_string(font, Vector2(center.x + 3.0, center.y - rr + 9.0), str(rs["lbl"]), HORIZONTAL_ALIGNMENT_LEFT, 72.0, 8, Color(0.75, 0.88, 0.72, 0.55))

		draw_line(Vector2(8.0, center.y), Vector2(size.x - 8.0, center.y), Color(0.45, 0.78, 0.42, 0.18), 1.0)
		draw_line(Vector2(center.x, 20.0), Vector2(center.x, size.y - 22.0), Color(0.45, 0.78, 0.42, 0.18), 1.0)

		var sweep_tip := center + Vector2(cos(_sweep_angle), sin(_sweep_angle)) * max_r
		draw_line(center, sweep_tip, Color(0.55, 0.95, 0.48, 0.35), 2.0)

		# Top banner
		draw_rect(Rect2(0.0, 0.0, size.x, 19.0), Color("#1d1a16"), true)
		var filter_tag: String = "ALL RINGS" if ring_filter <= 0 else ("RING %d" % ring_filter)
		var map_hdr: String = "MULTI-RING OSM RADAR [%s]" % filter_tag
		draw_string(font, Vector2(6.0, 13.0), map_hdr, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 10, Color("#f2b82e"))

		var h_lat: float = float(GameState.selected_house.get("lat", 47.6242))
		var h_lon: float = float(GameState.selected_house.get("lon", -122.3195))
		var cos_lat: float = maxf(0.25, cos(deg_to_rad(h_lat)))

		_pin_positions.clear()
		var min_inner_r: float = 17.0
		for i in range(targets.size()):
			var td: Dictionary = targets[i]
			var dx_m: float = 0.0
			var dy_m: float = 0.0
			if td.has("lat") and td.has("lon"):
				dx_m = (float(td.get("lon", h_lon)) - h_lon) * 111320.0 * cos_lat
				dy_m = -(float(td.get("lat", h_lat)) - h_lat) * 111320.0
			else:
				var ang_fb: float = float(i) * 0.95
				var dm_fb: float = float(td.get("distance_m", 250.0))
				dx_m = cos(ang_fb) * dm_fb
				dy_m = sin(ang_fb) * dm_fb

			var v := Vector2(dx_m, dy_m)
			var dist_m: float = maxf(float(td.get("distance_m", v.length())), v.length())
			var dir: Vector2 = (v / v.length()) if v.length() > 0.001 else Vector2(cos(float(i) * 0.95), sin(float(i) * 0.95))

			# Piecewise multi-ring radial mapping so R1 (<500m), R2 (500-3500m), and R3 (3.5-10km) sit in their exact ring bands!
			var ring_u: float = 0.25
			if dist_m < 500.0:
				ring_u = lerpf(0.18, 0.33, clampf(dist_m / 500.0, 0.0, 1.0))
			elif dist_m < 3500.0:
				ring_u = lerpf(0.37, 0.65, clampf((dist_m - 500.0) / 3000.0, 0.0, 1.0))
			else:
				ring_u = lerpf(0.70, 0.95, clampf((dist_m - 3500.0) / 6500.0, 0.0, 1.0))

			var pt: Vector2 = center + dir * maxf(min_inner_r, ring_u * max_r)
			pt.x = clampf(pt.x, safe_rect.position.x, safe_rect.end.x)
			pt.y = clampf(pt.y, safe_rect.position.y, safe_rect.end.y)
			_pin_positions.append(pt)

		# 6 passes of pairwise pin separation (min_sep = 14.5 px, re-clamping inside safe_rect each pass)
		var min_sep: float = 14.5
		for _pass_idx in range(6):
			for i in range(_pin_positions.size()):
				for j in range(i + 1, _pin_positions.size()):
					var delta_v: Vector2 = _pin_positions[j] - _pin_positions[i]
					var d: float = delta_v.length()
					if d < min_sep:
						var push_dir: Vector2
						if d > 0.05:
							push_dir = delta_v / d
							if absf(delta_v.x) < 1.2 and (_pin_positions[i].y >= safe_rect.end.y - 2.0 or _pin_positions[j].y >= safe_rect.end.y - 2.0):
								var side_sign: float = 1.0 if ((i + j) % 2 == 0) else -1.0
								push_dir = Vector2(push_dir.x + side_sign * 0.65, push_dir.y * 0.5).normalized()
						else:
							var ang_sep: float = float(i * 7 + j * 13) * 2.39996
							push_dir = Vector2(cos(ang_sep), sin(ang_sep))
						var push: Vector2 = push_dir * ((min_sep - d) * 0.55)
						_pin_positions[i] -= push
						_pin_positions[j] += push
			for i in range(_pin_positions.size()):
				var from_c: Vector2 = _pin_positions[i] - center
				var dc: float = from_c.length()
				if dc < min_inner_r:
					var c_dir: Vector2 = (from_c / dc) if dc > 0.001 else Vector2(cos(float(i) * 0.95), sin(float(i) * 0.95))
					_pin_positions[i] = center + c_dir * min_inner_r
				_pin_positions[i].x = clampf(_pin_positions[i].x, safe_rect.position.x, safe_rect.end.x)
				_pin_positions[i].y = clampf(_pin_positions[i].y, safe_rect.position.y, safe_rect.end.y)

		if selected_index >= 0 and selected_index < _pin_positions.size():
			var sel_pt: Vector2 = _pin_positions[selected_index]
			draw_line(center, sel_pt, Color("#f2b82e"), 2.0)
			if active_expedition_mode:
				var beacon: Vector2 = center.lerp(sel_pt, route_progress)
				var pulse_r: float = 5.5 + sin(_sweep_angle * 3.0) * 2.2
				draw_circle(beacon, pulse_r + 3.0, Color(0.23, 0.72, 0.98, 0.32))
				draw_circle(beacon, 4.8, Color("#7fd0f5"))
				draw_arc(beacon, 4.8, 0.0, TAU, 14, Color("#1d1a16"), 1.4)

		# Home Shelter icon at center
		draw_circle(center, 8.0, Color("#e05a2b"))
		draw_arc(center, 8.0, 0.0, TAU, 18, Color("#f2b82e"), 1.8)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -4.5),
			center + Vector2(4.5, 3.5),
			center + Vector2(-4.5, 3.5)
		]), Color("#fff6de"))

		for i in range(targets.size()):
			if i == selected_index:
				continue
			var td: Dictionary = targets[i]
			var cat: String = str(td.get("category", "neighbor_house")).to_lower()
			var vis_f: bool = _is_idx_visible_for_filter(i)
			var depl_f: bool = bool(td.get("depleted", false))
			var pin_alpha: float = (0.35 if depl_f else 1.0) if vis_f else 0.18
			_draw_category_pin(_pin_positions[i], cat, false, (i == _hovered_idx) and not depl_f, pin_alpha)

		if selected_index >= 0 and selected_index < targets.size():
			var sel_td: Dictionary = targets[selected_index]
			var sel_cat: String = str(sel_td.get("category", "neighbor_house")).to_lower()
			var sel_depl: bool = bool(sel_td.get("depleted", false))
			_draw_category_pin(_pin_positions[selected_index], sel_cat, true, selected_index == _hovered_idx, 0.45 if sel_depl else 1.0)

		var label_idx: int = _hovered_idx if _hovered_idx >= 0 else selected_index
		if label_idx >= 0 and label_idx < targets.size():
			var lt: Dictionary = targets[label_idx]
			var cap_r := Rect2(4.0, size.y - 20.0, size.x - 8.0, 17.0)
			draw_rect(cap_r, Color(0.08, 0.10, 0.08, 0.90), true)
			var dm_l: float = float(lt.get("distance_m", 150.0))
			var depl_tag: String = "[DEPLETED] " if bool(lt.get("depleted", false)) else ""
			var cap_s: String = "%s%s (%s)" % [depl_tag, str(lt.get("name", "Landmark")), BunkerScene._format_distance_m_or_km(dm_l)]
			draw_string(font, cap_r.position + Vector2(6.0, 12.0), cap_s, HORIZONTAL_ALIGNMENT_LEFT, cap_r.size.x - 12.0, 9, Color("#f2e6ce"))

	func _draw_category_pin(pt: Vector2, cat: String, is_sel: bool, is_hov: bool, alpha_m: float) -> void:
		var base_col: Color = BunkerScene._get_category_color(cat)
		var col := Color(base_col.r, base_col.g, base_col.b, alpha_m)
		var ink := Color(0.11, 0.10, 0.09, alpha_m)

		if is_sel or is_hov:
			draw_arc(pt, 11.5, 0.0, TAU, 20, Color("#f2b82e") if is_sel else Color("#ffffff"), 2.0)

		draw_circle(pt, 7.2, col)
		draw_arc(pt, 7.2, 0.0, TAU, 16, ink, 1.5)

		if cat.contains("doc") or cat.contains("clin") or cat.contains("hosp") or cat.contains("urgent"):
			draw_line(pt + Vector2(0.0, -4.2), pt + Vector2(0.0, 4.2), Color(1, 1, 1, alpha_m), 2.4)
			draw_line(pt + Vector2(-4.2, 0.0), pt + Vector2(4.2, 0.0), Color(1, 1, 1, alpha_m), 2.4)
		elif cat.contains("groc") or cat.contains("super") or cat.contains("market"):
			draw_rect(Rect2(pt - Vector2(3.6, 1.8), Vector2(7.2, 5.0)), ink, false, 1.5)
			draw_arc(pt + Vector2(0.0, -1.8), 2.6, PI, TAU, 8, ink, 1.3)
		elif cat.contains("fuel") or cat.contains("auto") or cat.contains("gas"):
			draw_rect(Rect2(pt - Vector2(3.0, 4.0), Vector2(5.2, 8.0)), ink, true)
			draw_line(pt + Vector2(2.4, -2.5), pt + Vector2(4.2, 2.5), ink, 1.5)
		elif cat.contains("pharm") or cat.contains("drug"):
			draw_line(pt + Vector2(-3.2, -3.2), pt + Vector2(3.2, 3.2), Color(1, 1, 1, alpha_m), 2.4)
			draw_circle(pt + Vector2(-1.8, -1.8), 1.5, ink)
		elif cat.contains("hard") or cat.contains("lumber"):
			draw_line(pt + Vector2(-3.5, 3.5), pt + Vector2(3.5, -3.5), ink, 2.0)
			draw_circle(pt + Vector2(2.8, -2.8), 2.0, ink)
		elif cat.contains("civic") or cat.contains("polic") or cat.contains("fire"):
			var sh := PackedVector2Array([pt + Vector2(0.0, -4.5), pt + Vector2(4.0, -1.5), pt + Vector2(2.5, 4.2), pt + Vector2(-2.5, 4.2), pt + Vector2(-4.0, -1.5)])
			draw_colored_polygon(sh, ink)
		elif cat.contains("church") or cat.contains("parish"):
			draw_line(pt + Vector2(0.0, -4.6), pt + Vector2(0.0, 4.6), ink, 1.9)
			draw_line(pt + Vector2(-3.2, -1.4), pt + Vector2(3.2, -1.4), ink, 1.9)
		elif cat.contains("school") or cat.contains("lib"):
			draw_rect(Rect2(pt - Vector2(3.8, 3.2), Vector2(7.6, 6.4)), ink, false, 1.4)
			draw_line(pt + Vector2(0.0, -3.2), pt + Vector2(0.0, 3.2), ink, 1.2)
		else:
			draw_colored_polygon(PackedVector2Array([pt + Vector2(0.0, -4.2), pt + Vector2(4.2, 0.5), pt + Vector2(-4.2, 0.5)]), ink)
			draw_rect(Rect2(pt + Vector2(-2.8, 0.5), Vector2(5.6, 3.5)), ink, true)

class _VehicleBlueprintWidget extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#173042"), true)
		draw_rect(r, Color("#1d1a16"), false, 2.2)

		# Cyanotype engineering grid
		var grid_c := Color(0.52, 0.80, 0.96, 0.14)
		for gx in range(20, int(size.x), 20):
			draw_line(Vector2(float(gx), 20.0), Vector2(float(gx), size.y - 4.0), grid_c, 1.0)
		for gy in range(24, int(size.y), 20):
			draw_line(Vector2(4.0, float(gy)), Vector2(size.x - 4.0, float(gy)), grid_c, 1.0)

		draw_rect(Rect2(0.0, 0.0, size.x, 20.0), Color("#102230"), true)
		var ready_now: bool = GameState.can_escape_by_vehicle()
		draw_string(
			font,
			Vector2(6.0, 14.0),
			"SCHEMATIC: 1955 CIVIL DEFENSE STATION WAGON",
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 12.0,
			9,
			Color("#7ec850") if ready_now else Color("#9be0ff")
		)

		# Side-profile schematic of 1950s Woodie Station Wagon
		var ox: float = 28.0
		var oy: float = 122.0
		var line_cyan := Color("#bcebff")
		var fill_tint := Color(0.26, 0.56, 0.74, 0.30)
		var body_pts := PackedVector2Array([
			Vector2(ox, oy + 18.0),
			Vector2(ox + 6.0, oy - 4.0),
			Vector2(ox + 66.0, oy - 8.0),
			Vector2(ox + 92.0, oy - 36.0),
			Vector2(ox + 236.0, oy - 36.0),
			Vector2(ox + 252.0, oy - 4.0),
			Vector2(ox + 256.0, oy + 18.0)
		])
		draw_colored_polygon(body_pts, fill_tint)
		var closed_pts: PackedVector2Array = body_pts.duplicate()
		closed_pts.append(body_pts[0])
		draw_polyline(closed_pts, line_cyan, 2.0)

		# Woodgrain side trim & windows & luggage roof rack
		draw_rect(Rect2(ox + 68.0, oy - 3.0, 174.0, 10.0), Color(0.85, 0.62, 0.28, 0.38), true)
		draw_rect(Rect2(ox + 68.0, oy - 3.0, 174.0, 10.0), line_cyan, false, 1.1)
		draw_line(Vector2(ox + 102.0, oy - 41.0), Vector2(ox + 226.0, oy - 41.0), line_cyan, 1.6)
		for wx in [98.0, 146.0, 192.0]:
			draw_rect(Rect2(ox + wx, oy - 31.0, 40.0, 22.0), Color(0.08, 0.16, 0.24, 0.65), true)
			draw_rect(Rect2(ox + wx, oy - 31.0, 40.0, 22.0), line_cyan, false, 1.2)

		# Wheels
		for wheel_x in [ox + 48.0, ox + 206.0]:
			var wc := Vector2(wheel_x, oy + 20.0)
			draw_circle(wc, 18.0, Color("#102230"))
			draw_arc(wc, 18.0, 0.0, TAU, 24, line_cyan, 2.0)
			draw_circle(wc, 8.0, Color("#f2b82e") if ready_now else line_cyan)

		# Callout nodes for 4 Engine Parts + Fuel Tank
		var callouts := [
			{"id": "battery", "lbl": "BAT", "pt": Vector2(ox + 24.0, oy - 1.0), "tag": Vector2(12.0, 44.0)},
			{"id": "radiator_hose", "lbl": "RAD", "pt": Vector2(ox + 10.0, oy + 6.0), "tag": Vector2(12.0, 68.0)},
			{"id": "alternator", "lbl": "ALT", "pt": Vector2(ox + 42.0, oy + 2.0), "tag": Vector2(74.0, 44.0)},
			{"id": "spark_plugs", "lbl": "SPK", "pt": Vector2(ox + 56.0, oy - 3.0), "tag": Vector2(138.0, 44.0)}
		]
		for co_v in callouts:
			var co: Dictionary = co_v
			var ok_p: bool = bool(GameState.vehicle_parts.get(str(co["id"]), false))
			var c_col := Color("#7ec850") if ok_p else Color("#ff6b57")
			var pt_a: Vector2 = co["pt"]
			var tag_p: Vector2 = co["tag"]
			draw_line(pt_a, tag_p + Vector2(22.0, 14.0), c_col, 1.2)
			draw_circle(pt_a, 3.5, c_col)
			var tr := Rect2(tag_p, Vector2(52.0, 16.0))
			draw_rect(tr, Color("#0f1e2b"), true)
			draw_rect(tr, c_col, false, 1.3)
			draw_string(font, tr.position + Vector2(0.0, 12.0), "%s %s" % [str(co["lbl"]), "✓" if ok_p else "×"], HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 9, c_col)

		# Rear Fuel Tank Callout
		var f_ok: bool = GameState.fuel_cans >= GameState.fuel_needed
		var f_col := Color("#7ec850") if f_ok else Color("#f2b82e")
		var f_pt := Vector2(ox + 236.0, oy + 8.0)
		var f_tag := Rect2(206.0, 44.0, 94.0, 16.0)
		draw_line(f_pt, f_tag.position + Vector2(46.0, 16.0), f_col, 1.2)
		draw_circle(f_pt, 3.8, f_col)
		draw_rect(f_tag, Color("#0f1e2b"), true)
		draw_rect(f_tag, f_col, false, 1.3)
		draw_string(font, f_tag.position + Vector2(0.0, 12.0), "FUEL %d/%d" % [GameState.fuel_cans, GameState.fuel_needed], HORIZONTAL_ALIGNMENT_CENTER, f_tag.size.x, 9, f_col)

		# Bottom Blueprint Status Stamp
		var foot_txt: String = (
			"STATUS: ALL SYSTEMS GREEN — READY FOR HIGHWAY BREAKOUT!"
			if ready_now
			else "SCAVENGE GAS/AUTO & HARDWARE POIs IN TAB 4 FOR PARTS & FUEL"
		)
		draw_string(font, Vector2(8.0, size.y - 8.0), foot_txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 9, Color("#7ec850") if ready_now else Color("#f2b82e"))

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
