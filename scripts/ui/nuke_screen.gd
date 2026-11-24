class_name NukeScreen
extends Control

## Global & Regional Nuclear Detonation Selector and Civil Defense Forecast Screen (1280x720).
## Features dual-mode tactical map (Regional Metro Radar 0-60 km + Global World Strike Map),
## Warhead Yield & Wind Vector controls, live Civil Defense Condition Forecast dossier,
## and automated demo showcase support.

signal strike_updated(nuke_config: Dictionary)

const MODE_REGIONAL: String = "regional"
const MODE_GLOBAL: String = "global"

# Mid-century 1950s CONELRAD Civil Defense palette
const COL_BG_DARK := Color("#191c19")
const COL_PANEL_OLIVE := Color("#232824")
const COL_PANEL_LIGHT := Color("#2e352f")
const COL_PARCHMENT := Color("#f2e6ce")
const COL_PARCHMENT_DARK := Color("#dccba6")
const COL_INK := Color("#1b1917")
const COL_YELLOW := Color("#f5be2e")
const COL_ORANGE := Color("#e05a2b")
const COL_RED := Color("#c93824")
const COL_GREEN := Color("#7ec850")
const COL_CYAN := Color("#3b8ec2")
const COL_MUTED := Color("#9aa396")

const YIELD_OPTIONS: Array[Dictionary] = [
	{"kt": 15, "label": "15 kt Tactical"},
	{"kt": 250, "label": "250 kt Urban"},
	{"kt": 800, "label": "800 kt ICBM"},
	{"kt": 50000, "label": "50,000 kt Tsar Bomba"}
]

const WIND_OPTIONS: Array[Dictionary] = [
	{"dir": "N", "deg": 0.0},
	{"dir": "NE", "deg": 45.0},
	{"dir": "E", "deg": 90.0},
	{"dir": "SE", "deg": 135.0},
	{"dir": "S", "deg": 180.0},
	{"dir": "SW", "deg": 225.0},
	{"dir": "W", "deg": 270.0},
	{"dir": "NW", "deg": 315.0}
]

var _house_lat: float = 47.6242
var _house_lon: float = -122.3195
var _house_label: String = "518 E Roy St, Capitol Hill, Seattle, WA"

var _nuke_lat: float = 47.6050
var _nuke_lon: float = -122.3470
var _target_name: String = "3.0 km SW of home"
var _yield_kt: int = 800
var _wind_deg: float = 45.0
var _map_mode: String = MODE_REGIONAL
var _current_impact: Dictionary = {}

# UI Node references
var _tab_regional_btn: Button
var _tab_global_btn: Button
var _map_canvas: _StrikeMapCanvas
var _preset_buttons: Array[Button] = []
var _preset_defs: Array[Dictionary] = []
var _yield_buttons: Dictionary = {}
var _yield_info_lbl: Label
var _wind_buttons: Dictionary = {}
var _wind_dial: _WindDialControl
var _wind_status_lbl: Label
var _forecast_panel: _ForecastPanelControl
var _back_btn: Button
var _launch_btn: _HazardSirenButton
var _difficulty_btn: Button

# Animation & Demo state
var _anim_time: float = 0.0
var _demo_elapsed: float = 0.0
var _demo_stage: int = 0
var _demo_finished: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280.0, 720.0)

	_build_ui()
	refresh_from_game_state()

	if not GameState.osm_house_selected.is_connected(_on_osm_house_selected):
		GameState.osm_house_selected.connect(_on_osm_house_selected)
	visibility_changed.connect(_on_visibility_changed)

	if GameState.demo_mode:
		_start_demo_sequence()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh_from_game_state()
		if GameState.demo_mode and not _demo_finished:
			_start_demo_sequence()


func _on_osm_house_selected(_house_data: Dictionary) -> void:
	refresh_from_game_state()


func refresh_from_game_state() -> void:
	var house: Dictionary = GameState.selected_house
	if not house.is_empty():
		_house_lat = float(house.get("lat", 47.6242))
		_house_lon = float(house.get("lon", -122.3195))
		var addr: String = str(house.get("address", "")).strip_edges()
		var hname: String = str(house.get("name", "")).strip_edges()
		if not addr.is_empty():
			_house_label = addr
		elif not hname.is_empty():
			_house_label = hname
		else:
			_house_label = GameState.current_neighborhood_label

	var existing_cfg: Dictionary = GameState.nuke_config
	var matches_current_house: bool = false
	if existing_cfg.has("house_lat") and existing_cfg.has("house_lon"):
		var d_house: float = NukePhysics.haversine_km(
			_house_lat,
			_house_lon,
			float(existing_cfg.get("house_lat", 999.0)),
			float(existing_cfg.get("house_lon", 999.0))
		)
		matches_current_house = d_house < 1.0

	if matches_current_house and existing_cfg.has("lat") and existing_cfg.has("lon"):
		_nuke_lat = float(existing_cfg.get("lat", _house_lat))
		_nuke_lon = float(existing_cfg.get("lon", _house_lon))
		_yield_kt = int(existing_cfg.get("yield_kt", 800))
		_wind_deg = float(existing_cfg.get("wind_bearing_deg", 45.0))
		_target_name = str(existing_cfg.get("target_name", "Strategic Target"))
	else:
		var local_pick: Dictionary = NukePhysics.pick_local_target(_house_lat, _house_lon, GameState.map_landmarks)
		_nuke_lat = float(local_pick["lat"])
		_nuke_lon = float(local_pick["lon"])
		_yield_kt = 800
		# Plume carried from ground zero toward home (wind bearing = direction the plume travels).
		_wind_deg = NukePhysics.bearing_deg(_nuke_lat, _nuke_lon, _house_lat, _house_lon)
		_target_name = str(local_pick["target_name"])

	_rebuild_presets()
	_recompute_and_sync(false)


func _process(delta: float) -> void:
	_anim_time += delta
	if _map_canvas != null:
		_map_canvas.advance_anim(delta)
	if _forecast_panel != null:
		_forecast_panel.advance_anim(delta)
	if _launch_btn != null:
		_launch_btn.advance_anim(delta)
	queue_redraw()

	if GameState.demo_mode and is_visible_in_tree() and not _demo_finished:
		_tick_demo_mode(delta)


func _start_demo_sequence() -> void:
	_demo_elapsed = 0.0
	_demo_stage = 0
	_demo_finished = false
	# Begin on Global World Strike Map testing a distant intercontinental strike (Nuclear Winter)
	set_map_mode(MODE_GLOBAL)
	set_yield_kt(800)
	set_wind_bearing(90.0)
	set_strike_target(35.6762, 139.6503, "Tokyo, Japan")
	if _map_canvas != null:
		_map_canvas.trigger_shockwave()


func _tick_demo_mode(delta: float) -> void:
	var speed_mult: float = 5.0 if GameState.headless_fast_test else 1.0
	_demo_elapsed += delta * speed_mult

	if _demo_stage == 0 and _demo_elapsed >= 1.15:
		_demo_stage = 1
		# Test antipodal / Moscow global winter trajectory on the Global Map
		set_yield_kt(50000)
		set_strike_target(55.7558, 37.6173, "Moscow, Russia")
		if _map_canvas != null:
			_map_canvas.trigger_shockwave()
		_play_sfx("tick")

	elif _demo_stage == 1 and _demo_elapsed >= 2.15:
		_demo_stage = 2
		# Switch to Regional Metro Radar and place an 800kt strike ~3.2 km from selected house
		set_map_mode(MODE_REGIONAL)
		set_yield_kt(800)
		var local_strike: Dictionary = NukePhysics.pick_local_target(_house_lat, _house_lon, GameState.map_landmarks)
		var s_lat: float = float(local_strike["lat"])
		var s_lon: float = float(local_strike["lon"])
		var downwind_brng: float = NukePhysics.bearing_deg(s_lat, s_lon, _house_lat, _house_lon)
		set_wind_bearing(downwind_brng)
		set_strike_target(s_lat, s_lon, str(local_strike["target_name"]))
		if _map_canvas != null:
			_map_canvas.set_radar_range_km(25.0)
			_map_canvas.trigger_shockwave()
		_play_sfx("geiger")

	elif _demo_stage == 2 and _demo_elapsed >= 3.05:
		_demo_stage = 3
		if _map_canvas != null:
			_map_canvas.trigger_shockwave()

	elif _demo_elapsed >= 3.80:
		_demo_finished = true
		launch_scavenge()


func set_map_mode(mode_id: String) -> void:
	_map_mode = MODE_GLOBAL if mode_id == MODE_GLOBAL else MODE_REGIONAL
	_update_mode_tab_styles()
	if _map_canvas != null:
		_map_canvas.set_mode(_map_mode)


func set_strike_target(lat: float, lon: float, target_name: String = "") -> void:
	_nuke_lat = clampf(lat, -89.5, 89.5)
	_nuke_lon = NukePhysics.wrap_lon(lon)
	_target_name = target_name
	_recompute_and_sync(true)


func set_yield_kt(new_yield_kt: int) -> void:
	_yield_kt = maxi(1, new_yield_kt)
	_recompute_and_sync(true)


func set_wind_bearing(deg_val: float) -> void:
	_wind_deg = NukePhysics.normalize_deg(deg_val)
	_recompute_and_sync(false)


func launch_scavenge() -> void:
	_recompute_and_sync(false)
	GameState.nuke_config = _current_impact.duplicate(true)
	GameState.surface_radiation_sv = float(_current_impact.get("initial_sv_hr", 4.5))
	GameState.bunker_temp_c = float(_current_impact.get("bunker_temp_c", 20.0))
	GameState.nuke_configured.emit(GameState.nuke_config)
	_play_sfx("siren")
	GameState.request_screen(GameState.SCREEN_SCAVENGE)


func _recompute_and_sync(spawn_shockwave: bool) -> void:
	_current_impact = NukePhysics.compute_impact(
		_house_lat,
		_house_lon,
		_nuke_lat,
		_nuke_lon,
		_yield_kt,
		_wind_deg,
		_target_name
	)
	GameState.nuke_config = _current_impact.duplicate(true)
	GameState.surface_radiation_sv = float(_current_impact.get("initial_sv_hr", 4.5))
	GameState.bunker_temp_c = float(_current_impact.get("bunker_temp_c", 20.0))

	_update_yield_button_styles()
	_update_wind_button_styles()

	if _wind_dial != null:
		_wind_dial.set_state(
			_wind_deg,
			float(_current_impact.get("bearing_from_nuke_deg", 0.0)),
			bool(_current_impact.get("in_fallout_plume", false))
		)

	if _map_canvas != null:
		_map_canvas.sync_data(_house_lat, _house_lon, _current_impact, GameState.nearby_pois)
		if spawn_shockwave:
			_map_canvas.trigger_shockwave()

	if _forecast_panel != null:
		_forecast_panel.set_impact(_current_impact)

	strike_updated.emit(_current_impact)
	queue_redraw()


func _build_ui() -> void:
	# 1. Mode Toggle Tabs above map (x=16..816, y=60..94)
	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(16.0, 60.0)
	tab_row.size = Vector2(800.0, 34.0)
	tab_row.add_theme_constant_override("separation", 8)
	add_child(tab_row)

	_tab_regional_btn = Button.new()
	_tab_regional_btn.text = "[ REGIONAL METRO RADAR (0-60 km) ]"
	_tab_regional_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_regional_btn.custom_minimum_size = Vector2(390.0, 34.0)
	_tab_regional_btn.focus_mode = Control.FOCUS_NONE
	_tab_regional_btn.pressed.connect(func() -> void:
		_play_sfx("button_click")
		set_map_mode(MODE_REGIONAL)
	)
	tab_row.add_child(_tab_regional_btn)

	_tab_global_btn = Button.new()
	_tab_global_btn.text = "[ GLOBAL WORLD STRIKE MAP ]"
	_tab_global_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_global_btn.custom_minimum_size = Vector2(390.0, 34.0)
	_tab_global_btn.focus_mode = Control.FOCUS_NONE
	_tab_global_btn.pressed.connect(func() -> void:
		_play_sfx("button_click")
		set_map_mode(MODE_GLOBAL)
	)
	tab_row.add_child(_tab_global_btn)

	# 2. Tactical Map Viewport (x=16..816, y=98..462 -> 800x364)
	_map_canvas = _StrikeMapCanvas.new()
	_map_canvas.position = Vector2(16.0, 98.0)
	_map_canvas.size = Vector2(800.0, 364.0)
	_map_canvas.target_picked.connect(_on_map_target_picked)
	add_child(_map_canvas)

	# 3. Preset Strike Coordinate Buttons (x=16..816, y=468..530 -> 800x62, 4x2 grid)
	var preset_grid := GridContainer.new()
	preset_grid.columns = 4
	preset_grid.position = Vector2(16.0, 468.0)
	preset_grid.size = Vector2(800.0, 62.0)
	preset_grid.add_theme_constant_override("h_separation", 6)
	preset_grid.add_theme_constant_override("v_separation", 6)
	add_child(preset_grid)

	for i in range(8):
		var pbtn := Button.new()
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pbtn.custom_minimum_size = Vector2(194.0, 28.0)
		pbtn.focus_mode = Control.FOCUS_NONE
		pbtn.add_theme_font_size_override("font_size", 12)
		_apply_tactical_button_style(pbtn, false, false)
		var idx: int = i
		pbtn.pressed.connect(func() -> void:
			_on_preset_button_pressed(idx)
		)
		preset_grid.add_child(pbtn)
		_preset_buttons.append(pbtn)

	# 4A. Warhead Yield Selector Box (x=16..452, y=536..648 -> 436x112)
	var yield_panel := Panel.new()
	yield_panel.position = Vector2(16.0, 536.0)
	yield_panel.size = Vector2(436.0, 112.0)
	yield_panel.add_theme_stylebox_override("panel", _make_box_style(COL_PANEL_OLIVE, COL_INK, 2, 4))
	add_child(yield_panel)

	var yield_hdr := Label.new()
	yield_hdr.text = "WARHEAD YIELD SELECTOR"
	yield_hdr.position = Vector2(10.0, 5.0)
	yield_hdr.size = Vector2(240.0, 18.0)
	yield_hdr.add_theme_font_size_override("font_size", 12)
	yield_hdr.add_theme_color_override("font_color", COL_YELLOW)
	yield_panel.add_child(yield_hdr)

	_yield_info_lbl = Label.new()
	_yield_info_lbl.position = Vector2(195.0, 5.0)
	_yield_info_lbl.size = Vector2(232.0, 18.0)
	_yield_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_yield_info_lbl.add_theme_font_size_override("font_size", 11)
	_yield_info_lbl.add_theme_color_override("font_color", COL_PARCHMENT_DARK)
	yield_panel.add_child(_yield_info_lbl)

	var yield_grid := GridContainer.new()
	yield_grid.columns = 2
	yield_grid.position = Vector2(8.0, 26.0)
	yield_grid.size = Vector2(420.0, 78.0)
	yield_grid.add_theme_constant_override("h_separation", 8)
	yield_grid.add_theme_constant_override("v_separation", 6)
	yield_panel.add_child(yield_grid)

	for opt in YIELD_OPTIONS:
		var kt_val: int = int(opt.get("kt", 800))
		var lbl_str: String = str(opt.get("label", ""))
		var ybtn := Button.new()
		ybtn.text = lbl_str
		ybtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ybtn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ybtn.custom_minimum_size = Vector2(204.0, 35.0)
		ybtn.focus_mode = Control.FOCUS_NONE
		ybtn.add_theme_font_size_override("font_size", 13)
		ybtn.pressed.connect(func() -> void:
			_play_sfx("button_click")
			set_yield_kt(kt_val)
		)
		yield_grid.add_child(ybtn)
		_yield_buttons[kt_val] = ybtn

	# 4B. Prevailing Wind Vector Box (x=460..816, y=536..648 -> 356x112)
	var wind_panel := Panel.new()
	wind_panel.position = Vector2(460.0, 536.0)
	wind_panel.size = Vector2(356.0, 112.0)
	wind_panel.add_theme_stylebox_override("panel", _make_box_style(COL_PANEL_OLIVE, COL_INK, 2, 4))
	add_child(wind_panel)

	var wind_hdr := Label.new()
	wind_hdr.text = "WIND & FALLOUT VECTOR"
	wind_hdr.position = Vector2(10.0, 5.0)
	wind_hdr.size = Vector2(190.0, 18.0)
	wind_hdr.add_theme_font_size_override("font_size", 12)
	wind_hdr.add_theme_color_override("font_color", COL_YELLOW)
	wind_panel.add_child(wind_hdr)

	_wind_status_lbl = Label.new()
	_wind_status_lbl.position = Vector2(180.0, 5.0)
	_wind_status_lbl.size = Vector2(168.0, 18.0)
	_wind_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wind_status_lbl.add_theme_font_size_override("font_size", 11)
	wind_panel.add_child(_wind_status_lbl)

	_wind_dial = _WindDialControl.new()
	_wind_dial.position = Vector2(10.0, 26.0)
	_wind_dial.size = Vector2(80.0, 80.0)
	_wind_dial.angle_selected.connect(func(deg_val: float) -> void:
		set_wind_bearing(deg_val)
	)
	wind_panel.add_child(_wind_dial)

	var wind_grid := GridContainer.new()
	wind_grid.columns = 4
	wind_grid.position = Vector2(98.0, 28.0)
	wind_grid.size = Vector2(248.0, 76.0)
	wind_grid.add_theme_constant_override("h_separation", 5)
	wind_grid.add_theme_constant_override("v_separation", 6)
	wind_panel.add_child(wind_grid)

	for wopt in WIND_OPTIONS:
		var dir_code: String = str(wopt.get("dir", "N"))
		var deg_f: float = float(wopt.get("deg", 0.0))
		var wbtn := Button.new()
		wbtn.text = dir_code
		wbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wbtn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		wbtn.custom_minimum_size = Vector2(56.0, 34.0)
		wbtn.focus_mode = Control.FOCUS_NONE
		wbtn.add_theme_font_size_override("font_size", 12)
		wbtn.pressed.connect(func() -> void:
			_play_sfx("tick")
			set_wind_bearing(deg_f)
		)
		wind_grid.add_child(wbtn)
		_wind_buttons[dir_code] = wbtn

	# 5. Right-Hand Civil Defense Condition Forecast Dossier (x=828..1264, y=60..648 -> 436x588)
	_forecast_panel = _ForecastPanelControl.new()
	_forecast_panel.position = Vector2(828.0, 60.0)
	_forecast_panel.size = Vector2(436.0, 588.0)
	add_child(_forecast_panel)

	# 6. Bottom Navigation & Launch Bar (y=658..708)
	_back_btn = Button.new()
	_back_btn.text = "[ < CHANGE HOUSE ]"
	_back_btn.position = Vector2(16.0, 658.0)
	_back_btn.size = Vector2(220.0, 48.0)
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.add_theme_font_size_override("font_size", 14)
	_apply_tactical_button_style(_back_btn, false, false)
	_back_btn.pressed.connect(func() -> void:
		_play_sfx("button_click")
		GameState.request_screen(GameState.SCREEN_OSM_HOUSE)
	)
	add_child(_back_btn)

	_difficulty_btn = Button.new()
	_difficulty_btn.position = Vector2(252.0, 658.0)
	_difficulty_btn.size = Vector2(464.0, 48.0)
	_difficulty_btn.focus_mode = Control.FOCUS_NONE
	_difficulty_btn.add_theme_font_size_override("font_size", 14)
	_apply_tactical_button_style(_difficulty_btn, false, false)
	_difficulty_btn.pressed.connect(func() -> void:
		_play_sfx("button_click")
		GameState.difficulty = "normal" if GameState.difficulty == "hard" else "hard"
		_refresh_difficulty_labels()
	)
	add_child(_difficulty_btn)

	_launch_btn = _HazardSirenButton.new()
	_launch_btn.text = "[ SOUND THE SIREN — BEGIN 60 SECONDS! > ]"
	_launch_btn.position = Vector2(732.0, 658.0)
	_launch_btn.size = Vector2(532.0, 48.0)
	_launch_btn.focus_mode = Control.FOCUS_NONE
	_launch_btn.pressed.connect(func() -> void:
		launch_scavenge()
	)
	add_child(_launch_btn)
	_refresh_difficulty_labels()

	_update_mode_tab_styles()


func _refresh_difficulty_labels() -> void:
	var hard: bool = GameState.difficulty == "hard"
	if _difficulty_btn != null:
		_difficulty_btn.text = "DIFFICULTY: HARD — 30 s SCAVENGE  [click to change]" if hard else "DIFFICULTY: NORMAL — 60 s SCAVENGE  [click to change]"
	if _launch_btn != null:
		_launch_btn.text = "[ SOUND THE SIREN — BEGIN %d SECONDS! > ]" % (30 if hard else 60)
	queue_redraw()


func _rebuild_presets() -> void:
	_preset_defs = NukePhysics.get_preset_targets(_house_lat, _house_lon, GameState.map_landmarks)
	for i in range(mini(_preset_buttons.size(), _preset_defs.size())):
		var pdef: Dictionary = _preset_defs[i]
		_preset_buttons[i].text = str(pdef.get("button_label", "Preset"))


func _on_preset_button_pressed(idx: int) -> void:
	if idx < 0 or idx >= _preset_defs.size():
		return
	var pdef: Dictionary = _preset_defs[idx]
	var plat: float = float(pdef.get("lat", _house_lat))
	var plon: float = float(pdef.get("lon", _house_lon))
	var pname: String = str(pdef.get("target_name", "Strategic Target"))
	var pref_reg: bool = bool(pdef.get("prefer_regional", false))

	_play_sfx("button_click")
	if pref_reg:
		set_map_mode(MODE_REGIONAL)
		var dist_check: float = NukePhysics.haversine_km(_house_lat, _house_lon, plat, plon)
		if _map_canvas != null:
			_map_canvas.set_radar_range_km(60.0 if dist_check > 20.0 else 25.0)
	else:
		var dist_global: float = NukePhysics.haversine_km(_house_lat, _house_lon, plat, plon)
		if dist_global > 65.0:
			set_map_mode(MODE_GLOBAL)
		else:
			set_map_mode(MODE_REGIONAL)

	set_strike_target(plat, plon, pname)
	for i in range(_preset_buttons.size()):
		_apply_tactical_button_style(_preset_buttons[i], i == idx, false)


func _on_map_target_picked(lat: float, lon: float, label_hint: String) -> void:
	_play_sfx("geiger")
	for btn in _preset_buttons:
		_apply_tactical_button_style(btn, false, false)
	set_strike_target(lat, lon, label_hint)


func _update_mode_tab_styles() -> void:
	if _tab_regional_btn != null:
		_apply_tactical_button_style(_tab_regional_btn, _map_mode == MODE_REGIONAL, true)
	if _tab_global_btn != null:
		_apply_tactical_button_style(_tab_global_btn, _map_mode == MODE_GLOBAL, true)


func _update_yield_button_styles() -> void:
	for kt_key in _yield_buttons.keys():
		var kt_int: int = int(kt_key)
		var btn: Button = _yield_buttons[kt_key]
		var active: bool = (kt_int == _yield_kt)
		_apply_tactical_button_style(btn, active, false)

	if _yield_info_lbl != null:
		var blast5: float = float(_current_impact.get("blast_5psi_radius_km", 4.6))
		var therm: float = float(_current_impact.get("thermal_radius_km", 7.8))
		_yield_info_lbl.text = "5-psi: %.1f km | Burn: %.1f km" % [blast5, therm]


func _update_wind_button_styles() -> void:
	var active_compass: String = NukePhysics.compass_label(_wind_deg)
	for dir_key in _wind_buttons.keys():
		var d_str: String = str(dir_key)
		var btn: Button = _wind_buttons[dir_key]
		_apply_tactical_button_style(btn, d_str == active_compass, false)

	if _wind_status_lbl != null:
		var in_plume: bool = bool(_current_impact.get("in_fallout_plume", false))
		var zone_id: String = str(_current_impact.get("zone", ""))
		if zone_id == "nuclear_winter":
			_wind_status_lbl.text = "%s (%d deg) STRATOSPHERIC" % [active_compass, int(round(_wind_deg))]
			_wind_status_lbl.add_theme_color_override("font_color", COL_CYAN)
		elif in_plume:
			_wind_status_lbl.text = "%s (%d deg) PLUME ON HOUSE!" % [active_compass, int(round(_wind_deg))]
			_wind_status_lbl.add_theme_color_override("font_color", COL_ORANGE)
		else:
			_wind_status_lbl.text = "%s (%d deg) CROSSWIND SAFE" % [active_compass, int(round(_wind_deg))]
			_wind_status_lbl.add_theme_color_override("font_color", COL_GREEN)


static func _make_box_style(bg: Color, border: Color, border_w: int = 2, corner: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


func _apply_tactical_button_style(btn: Button, active: bool, is_tab: bool) -> void:
	if active:
		var bg_act: Color = COL_YELLOW if is_tab else Color("#e6ad27")
		btn.add_theme_stylebox_override("normal", _make_box_style(bg_act, COL_INK, 2, 4))
		btn.add_theme_stylebox_override("hover", _make_box_style(bg_act.lightened(0.10), COL_INK, 2, 4))
		btn.add_theme_stylebox_override("pressed", _make_box_style(COL_ORANGE, COL_INK, 2, 4))
		btn.add_theme_color_override("font_color", COL_INK)
		btn.add_theme_color_override("font_hover_color", COL_INK)
		btn.add_theme_color_override("font_pressed_color", COL_PARCHMENT)
	else:
		var bg_idle: Color = Color("#282f29") if is_tab else Color("#2d352e")
		btn.add_theme_stylebox_override("normal", _make_box_style(bg_idle, COL_INK, 2, 4))
		btn.add_theme_stylebox_override("hover", _make_box_style(Color("#3a443b"), COL_YELLOW, 2, 4))
		btn.add_theme_stylebox_override("pressed", _make_box_style(COL_YELLOW, COL_INK, 2, 4))
		btn.add_theme_color_override("font_color", COL_PARCHMENT)
		btn.add_theme_color_override("font_hover_color", COL_YELLOW)
		btn.add_theme_color_override("font_pressed_color", COL_INK)


func _play_sfx(sfx_name: String) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sfx"):
		sm.call("play_sfx", sfx_name)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var view_size := Vector2(maxf(size.x, 1280.0), maxf(size.y, 720.0))
	var full_rect := Rect2(Vector2.ZERO, view_size)

	# Bunker steel background with subtle grid
	draw_rect(full_rect, COL_BG_DARK, true)
	for gx in range(0, int(view_size.x), 32):
		draw_line(Vector2(float(gx), 0.0), Vector2(float(gx), view_size.y), Color(1.0, 1.0, 1.0, 0.02), 1.0)
	for gy in range(0, int(view_size.y), 32):
		draw_line(Vector2(0.0, float(gy)), Vector2(view_size.x, float(gy)), Color(1.0, 1.0, 1.0, 0.02), 1.0)

	# Top Strategic Command Header Bar (16..1264, y=8..52)
	var hdr_rect := Rect2(16.0, 8.0, 1248.0, 46.0)
	draw_rect(hdr_rect, COL_PANEL_OLIVE, true)
	draw_rect(hdr_rect, COL_INK, false, 2.0)
	draw_line(Vector2(18.0, 52.0), Vector2(1262.0, 52.0), COL_YELLOW, 2.0)

	# Civil Defense CD Emblem at left of header
	var cd_center := Vector2(42.0, 31.0)
	draw_circle(cd_center, 16.0, COL_RED)
	draw_circle(cd_center, 13.5, COL_PARCHMENT)
	var tri := PackedVector2Array([
		cd_center + Vector2(0.0, -11.0),
		cd_center + Vector2(10.0, 7.0),
		cd_center + Vector2(-10.0, 7.0)
	])
	draw_colored_polygon(tri, COL_CYAN.darkened(0.25))
	draw_arc(cd_center, 16.0, 0.0, TAU, 28, COL_INK, 2.0)

	# Header Title & Selected Bunker House Subtitle
	draw_string(
		font,
		Vector2(68.0, 25.0),
		"CONELRAD NORAD STRATEGIC DETONATION & IMPACT SELECTOR",
		HORIZONTAL_ALIGNMENT_LEFT,
		760.0,
		16,
		COL_YELLOW
	)
	var house_coord_str: String = "HOME BUNKER: %s (%.3f, %.3f)" % [_house_label, _house_lat, _house_lon]
	draw_string(
		font,
		Vector2(68.0, 44.0),
		house_coord_str,
		HORIZONTAL_ALIGNMENT_LEFT,
		780.0,
		12,
		COL_PARCHMENT
	)

	# Right side DEFCON 1 pulsing alert lamp & GZ telemetry
	var defcon_box := Rect2(950.0, 14.0, 304.0, 34.0)
	draw_rect(defcon_box, Color("#141714"), true)
	draw_rect(defcon_box, COL_ORANGE, false, 1.5)
	var pulse: float = 0.55 + 0.45 * sin(_anim_time * 6.0)
	draw_circle(Vector2(968.0, 31.0), 6.5, Color(COL_ORANGE.r, COL_ORANGE.g, COL_ORANGE.b, pulse))
	draw_arc(Vector2(968.0, 31.0), 6.5, 0.0, TAU, 16, COL_YELLOW, 1.2)
	var gz_txt: String = "DEFCON 1 | GZ %.2f, %.2f | %s kt" % [_nuke_lat, _nuke_lon, str(_yield_kt)]
	draw_string(font, Vector2(982.0, 36.0), gz_txt, HORIZONTAL_ALIGNMENT_LEFT, 266.0, 12, COL_PARCHMENT)

	# Bottom CONELRAD Emergency Broadcast Ticker Box (between Back and Siren buttons)
	var ticker_rect := Rect2(246.0, 658.0, 476.0, 48.0)
	draw_rect(ticker_rect, Color("#141814"), true)
	draw_rect(ticker_rect, COL_INK, false, 2.0)
	# Subtle hazard bar at top of ticker
	_draw_hazard_stripes(Rect2(248.0, 660.0, 472.0, 5.0), 10.0)

	var ticker_line1: String = "CONELRAD 640 / 1240 kHz CIVIL DEFENSE DIRECTIVE:"
	var ticker_line2: String = "Click any radar block or world continent to test warhead impact!"
	if GameState.demo_mode:
		ticker_line1 = "CONELRAD AUTOMATED TACTICAL SHOWCASE ACTIVE:"
		ticker_line2 = "Comparing distant Global Nuclear Winter vs 3.2 km Metro Strike."

	draw_string(
		font,
		Vector2(258.0, 680.0),
		ticker_line1,
		HORIZONTAL_ALIGNMENT_LEFT,
		454.0,
		10,
		COL_YELLOW
	)
	draw_string(
		font,
		Vector2(258.0, 696.0),
		ticker_line2,
		HORIZONTAL_ALIGNMENT_LEFT,
		454.0,
		10,
		COL_PARCHMENT if GameState.demo_mode else COL_PARCHMENT_DARK
	)


func _draw_hazard_stripes(rect: Rect2, stripe_w: float) -> void:
	draw_rect(rect, COL_INK, true)
	var x_cur: float = rect.position.x
	var toggle: bool = true
	while x_cur < rect.end.x:
		if toggle:
			var w: float = minf(stripe_w, rect.end.x - x_cur)
			draw_rect(Rect2(x_cur, rect.position.y, w, rect.size.y), COL_YELLOW, true)
		x_cur += stripe_w
		toggle = not toggle


# ==============================================================================
# INNER CLASS 1: TACTICAL DUAL-MODE STRIKE MAP (REGIONAL RADAR + GLOBAL WORLD)
# ==============================================================================
class _StrikeMapCanvas extends Control:
	signal target_picked(lat: float, lon: float, label_hint: String)

	var _mode: String = "regional"
	var _house_lat: float = 47.6242
	var _house_lon: float = -122.3195
	var _impact: Dictionary = {}
	var _pois: Array = []

	var _radar_range_km: float = 60.0
	var _is_dragging: bool = false
	var _hover_pos: Vector2 = Vector2(-1.0, -1.0)
	var _time: float = 0.0
	var _shockwaves: Array[float] = [0.0]

	# Regional quick-pinpoint ring buttons (rect + km + label)
	var _quick_ring_rects: Array[Dictionary] = []

	# Stylized World Continent Polygons (simple non-self-intersecting [lon, lat] loops)
	var _world_polys: Array[Array] = []
	var _world_cities: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		_init_world_geometry()

	func set_mode(new_mode: String) -> void:
		_mode = new_mode
		queue_redraw()

	func set_radar_range_km(km_val: float) -> void:
		_radar_range_km = clampf(km_val, 10.0, 100.0)
		queue_redraw()

	func sync_data(h_lat: float, h_lon: float, impact_dict: Dictionary, nearby_pois: Array) -> void:
		_house_lat = h_lat
		_house_lon = h_lon
		_impact = impact_dict
		_pois = nearby_pois
		queue_redraw()

	func trigger_shockwave() -> void:
		_shockwaves.append(0.0)
		if _shockwaves.size() > 4:
			_shockwaves.pop_front()
		queue_redraw()

	func advance_anim(delta: float) -> void:
		_time += delta
		for i in range(_shockwaves.size()):
			_shockwaves[i] = _shockwaves[i] + delta * 0.75
		while _shockwaves.size() > 1 and _shockwaves[0] > 1.35:
			_shockwaves.pop_front()
		if _shockwaves.is_empty():
			_shockwaves.append(fposmod(_time * 0.55, 1.0))
		elif _shockwaves[0] > 1.25:
			_shockwaves[0] = 0.0
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event
			_hover_pos = mm.position
			if _is_dragging:
				_pick_at_pixel(mm.position)
			queue_redraw()
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if _mode == "regional" and _try_click_quick_pill(mb.position):
						return
					_is_dragging = true
					_pick_at_pixel(mb.position)
				else:
					_is_dragging = false
			elif mb.pressed and _mode == "regional":
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					set_radar_range_km(_radar_range_km * 0.80)
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					set_radar_range_km(_radar_range_km * 1.25)

	func _try_click_quick_pill(pos: Vector2) -> bool:
		for entry in _quick_ring_rects:
			var r: Rect2 = entry.get("rect", Rect2())
			if r.has_point(pos):
				var action_str: String = str(entry.get("action", ""))
				if action_str == "zoom_toggle":
					set_radar_range_km(15.0 if _radar_range_km > 25.0 else 60.0)
				else:
					var km_dist: float = float(entry.get("km", 5.0))
					var pt: Dictionary = NukePhysics.destination_point(_house_lat, _house_lon, 225.0, km_dist)
					var lbl: String = str(entry.get("label", "Pinpoint Strike"))
					if km_dist <= 6.0 and _radar_range_km > 25.0:
						set_radar_range_km(20.0)
					elif km_dist >= 25.0 and _radar_range_km < 45.0:
						set_radar_range_km(60.0)
					target_picked.emit(float(pt.get("lat", _house_lat)), float(pt.get("lon", _house_lon)), lbl)
				return true
		return false

	func _pick_at_pixel(pos: Vector2) -> void:
		if _mode == "regional":
			var center: Vector2 = size * 0.5
			var px_per_km: float = _get_radar_px_per_km()
			var east_km: float = (pos.x - center.x) / px_per_km
			var north_km: float = -(pos.y - center.y) / px_per_km
			var dist_km: float = sqrt(east_km * east_km + north_km * north_km)
			var dest: Dictionary = NukePhysics.offset_km_to_latlon(_house_lat, _house_lon, east_km, north_km)
			var nlat: float = float(dest.get("lat", _house_lat))
			var nlon: float = float(dest.get("lon", _house_lon))
			var brng: float = NukePhysics.bearing_deg(_house_lat, _house_lon, nlat, nlon)
			var dir_s: String = NukePhysics.compass_label(brng)
			var hint: String = "Metro Sector %s (%.1f km)" % [dir_s, dist_km]
			if dist_km < 1.8:
				hint = "Direct Block Strike (%.2f km %s)" % [dist_km, dir_s]
			target_picked.emit(nlat, nlon, hint)
		else:
			var map_r: Rect2 = _get_world_map_rect()
			var clamped_x: float = clampf(pos.x, map_r.position.x, map_r.end.x)
			var clamped_y: float = clampf(pos.y, map_r.position.y, map_r.end.y)
			var u: float = (clamped_x - map_r.position.x) / map_r.size.x
			var v: float = (clamped_y - map_r.position.y) / map_r.size.y
			var lon: float = -180.0 + u * 360.0
			var lat: float = 85.0 - v * 170.0
			var hint_g: String = _nearest_city_or_region(lat, lon)
			target_picked.emit(lat, lon, hint_g)

	func _nearest_city_or_region(lat: float, lon: float) -> String:
		for city in _world_cities:
			var clat: float = float(city.get("lat", 0.0))
			var clon: float = float(city.get("lon", 0.0))
			if NukePhysics.haversine_km(lat, lon, clat, clon) < 420.0:
				return str(city.get("name", "Global City"))
		var ns: String = "N" if lat >= 0.0 else "S"
		var ew: String = "E" if lon >= 0.0 else "W"
		return "Global Strike (%.1f%s, %.1f%s)" % [absf(lat), ns, absf(lon), ew]

	func _get_radar_px_per_km() -> float:
		var usable_r: float = minf(size.x, size.y) * 0.5 - 22.0
		return maxf(0.5, usable_r / maxf(5.0, _radar_range_km))

	func _get_world_map_rect() -> Rect2:
		return Rect2(20.0, 18.0, size.x - 40.0, size.y - 36.0)

	func _latlon_to_world_px(lat: float, lon: float, map_r: Rect2) -> Vector2:
		var u: float = (NukePhysics.wrap_lon(lon) + 180.0) / 360.0
		var v: float = (85.0 - clampf(lat, -85.0, 85.0)) / 170.0
		return Vector2(map_r.position.x + u * map_r.size.x, map_r.position.y + v * map_r.size.y)

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var rect := Rect2(Vector2.ZERO, size)

		if _mode == "regional":
			_draw_regional_radar(font, rect)
		else:
			_draw_global_world_map(font, rect)

		# Steel NORAD CRT Bezel & Corner Rivets
		draw_rect(rect, Color("#1b1917"), false, 3.0)
		draw_rect(rect.grow(-2.0), Color("#465046"), false, 1.5)
		for corner in [Vector2(8, 8), Vector2(size.x - 8, 8), Vector2(8, size.y - 8), Vector2(size.x - 8, size.y - 8)]:
			draw_circle(corner, 3.0, Color("#6b756a"))
			draw_arc(corner, 3.0, 0.0, TAU, 10, Color("#1b1917"), 1.0)

	func _draw_regional_radar(font: Font, rect: Rect2) -> void:
		# Deep phosphor CRT green-black radar scope
		draw_rect(rect, Color("#0c150f"), true)

		var center: Vector2 = size * 0.5
		var px_per_km: float = _get_radar_px_per_km()
		var scope_r: float = _radar_range_km * px_per_km

		# Metro street/sector grid (every 5 km or 10 km depending on zoom)
		var grid_step_km: float = 5.0 if _radar_range_km <= 30.0 else 10.0
		var grid_step_px: float = grid_step_km * px_per_km
		var max_steps_x: int = int(ceil((size.x * 0.5) / grid_step_px))
		var max_steps_y: int = int(ceil((size.y * 0.5) / grid_step_px))

		for gx in range(-max_steps_x, max_steps_x + 1):
			var x_pos: float = center.x + float(gx) * grid_step_px
			var col_g := Color(0.28, 0.58, 0.34, 0.16 if gx != 0 else 0.36)
			draw_line(Vector2(x_pos, 0.0), Vector2(x_pos, size.y), col_g, 1.0)
		for gy in range(-max_steps_y, max_steps_y + 1):
			var y_pos: float = center.y + float(gy) * grid_step_px
			var col_gy := Color(0.28, 0.58, 0.34, 0.16 if gy != 0 else 0.36)
			draw_line(Vector2(0.0, y_pos), Vector2(size.x, y_pos), col_gy, 1.0)

		# Diagonal metro arterial highways + stylized local river/bay channel for urban context
		draw_line(center + Vector2(-380.0, 140.0), center + Vector2(380.0, -135.0), Color(0.35, 0.65, 0.40, 0.14), 2.0)
		draw_line(center + Vector2(-240.0, -180.0), center + Vector2(220.0, 180.0), Color(0.35, 0.65, 0.40, 0.12), 1.5)

		# Rotating NORAD phosphor radar sweep wedge
		var sweep_ang: float = fposmod(_time * 1.15, TAU)
		var sweep_pts := PackedVector2Array([center])
		for s_i in range(9):
			var a: float = sweep_ang - float(s_i) * 0.045
			sweep_pts.append(center + Vector2(cos(a), sin(a)) * scope_r)
		if sweep_pts.size() >= 3:
			draw_colored_polygon(sweep_pts, Color(0.35, 0.88, 0.45, 0.07))
		draw_line(center, center + Vector2(cos(sweep_ang), sin(sweep_ang)) * scope_r, Color(0.49, 0.92, 0.52, 0.35), 1.5)

		# Concentric kilometer range rings
		var rings_km: Array[float] = [1.0, 5.0, 15.0, 30.0, 45.0, 60.0, 90.0]
		if _radar_range_km <= 26.0:
			rings_km = [1.0, 3.0, 5.0, 10.0, 15.0, 20.0, 25.0]

		for r_km in rings_km:
			if r_km > _radar_range_km * 1.05:
				continue
			var r_px: float = r_km * px_per_km
			if r_px < 5.0:
				continue
			var ring_alpha: float = 0.42 if is_equal_approx(r_km, _radar_range_km) else 0.25
			draw_arc(center, r_px, 0.0, TAU, 64, Color(0.48, 0.85, 0.46, ring_alpha), 1.2)
			if r_px >= 30.0:
				draw_string(
					font,
					Vector2(center.x + 4.0, center.y - r_px + 11.0),
					"%d km" % int(round(r_km)),
					HORIZONTAL_ALIGNMENT_LEFT,
					60.0,
					10,
					Color(0.62, 0.92, 0.60, 0.75)
				)

		# Degree azimuth ticks around outer radar ring
		for deg_i in range(0, 360, 15):
			var rad_i: float = deg_to_rad(float(deg_i) - 90.0)
			var inner_k: float = scope_r - (7.0 if deg_i % 45 == 0 else 4.0)
			draw_line(
				center + Vector2(cos(rad_i), sin(rad_i)) * inner_k,
				center + Vector2(cos(rad_i), sin(rad_i)) * scope_r,
				Color(0.55, 0.88, 0.55, 0.45),
				1.2
			)

		# Cardinal N / E / S / W markers
		draw_string(font, Vector2(center.x - 5.0, center.y - scope_r - 5.0), "N", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 12, Color("#f5be2e"))
		draw_string(font, Vector2(center.x - 5.0, center.y + scope_r + 14.0), "S", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 12, Color("#9aa396"))
		draw_string(font, Vector2(center.x + scope_r + 6.0, center.y + 4.0), "E", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 12, Color("#9aa396"))
		draw_string(font, Vector2(center.x - scope_r - 16.0, center.y + 4.0), "W", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 12, Color("#9aa396"))

		# Real nearby OSM POIs around center (if loaded)
		for poi in _pois:
			if poi is Dictionary:
				var p_dict: Dictionary = poi
				var plat: float = float(p_dict.get("lat", _house_lat))
				var plon: float = float(p_dict.get("lon", _house_lon))
				var local_v: Vector2 = NukePhysics.latlon_to_local_km(_house_lat, _house_lon, plat, plon)
				var poi_px := Vector2(center.x + local_v.x * px_per_km, center.y - local_v.y * px_per_km)
				if rect.has_point(poi_px):
					draw_circle(poi_px, 2.5, Color("#7ec850"))

		# Compute Ground Zero position on Regional Radar
		var nlat: float = float(_impact.get("lat", _house_lat))
		var nlon: float = float(_impact.get("lon", _house_lon))
		var dist_km: float = float(_impact.get("distance_km", 3.0))
		var gz_local_km: Vector2 = NukePhysics.latlon_to_local_km(_house_lat, _house_lon, nlat, nlon)
		var gz_px := Vector2(center.x + gz_local_km.x * px_per_km, center.y - gz_local_km.y * px_per_km)
		var gz_inside_view: bool = rect.grow(120.0).has_point(gz_px)

		if gz_inside_view:
			_draw_local_blast_and_plume(font, gz_px, center, px_per_km)
		else:
			# Distant global strike indicator arrow pointing toward remote Ground Zero
			var dir_vec: Vector2 = (gz_px - center).normalized()
			var edge_pt: Vector2 = center + dir_vec * (scope_r - 12.0)
			draw_line(center, edge_pt, Color(0.88, 0.35, 0.17, 0.65), 2.0)
			draw_circle(edge_pt, 6.0, Color("#e05a2b"))
			var warn_box := Rect2(center.x - 195.0, size.y - 36.0, 390.0, 24.0)
			draw_rect(warn_box, Color(0.1, 0.12, 0.1, 0.90), true)
			draw_rect(warn_box, Color("#f5be2e"), false, 1.5)
			draw_string(
				font,
				Vector2(warn_box.position.x + 8.0, warn_box.position.y + 16.0),
				"DISTANT STRIKE (%d km) - CLICK RADAR FOR LOCAL OR VIEW GLOBAL TAB" % int(round(dist_km)),
				HORIZONTAL_ALIGNMENT_LEFT,
				376.0,
				10,
				Color("#f5be2e")
			)

		# Draw Player's OSM House Bunker Icon at Radar Center
		_draw_house_bunker_marker(font, center, true)

		# Left Legend Box (Blast Rings Key)
		var leg_r := Rect2(12.0, 12.0, 168.0, 86.0)
		draw_rect(leg_r, Color(0.08, 0.11, 0.09, 0.86), true)
		draw_rect(leg_r, Color("#3a483b"), false, 1.0)
		draw_string(font, Vector2(18.0, 26.0), "OVERPRESSURE & PLUME", HORIZONTAL_ALIGNMENT_LEFT, 155.0, 10, Color("#f5be2e"))
		_draw_legend_item(font, Vector2(18.0, 40.0), Color("#fff099"), "Fireball Core")
		_draw_legend_item(font, Vector2(18.0, 54.0), Color("#e05a2b"), "5-psi Severe Blast")
		_draw_legend_item(font, Vector2(18.0, 68.0), Color("#f5be2e"), "Thermal 3rd-Deg Burn")
		_draw_legend_item(font, Vector2(18.0, 82.0), Color("#7ec850"), "Downwind Fallout Cone")

		# Right Pinpoint Strike Quick Pills (1 km, 5 km, 30 km + Zoom toggle)
		_quick_ring_rects.clear()
		var pills: Array[Dictionary] = [
			{"label": "Pinpoint 1 km Strike", "short": "Pin 1 km", "km": 1.0, "action": "pin"},
			{"label": "Metro 5 km Strike", "short": "Pin 5 km", "km": 5.0, "action": "pin"},
			{"label": "Suburban 30 km Strike", "short": "Pin 30 km", "km": 30.0, "action": "pin"},
			{"label": "Toggle Zoom", "short": "Scope: %d km" % int(round(_radar_range_km)), "km": 0.0, "action": "zoom_toggle"}
		]
		for p_i in range(pills.size()):
			var p_entry: Dictionary = pills[p_i]
			var pr := Rect2(size.x - 108.0, 12.0 + float(p_i) * 26.0, 96.0, 22.0)
			var hovered: bool = pr.has_point(_hover_pos)
			draw_rect(pr, Color("#2c382d") if not hovered else Color("#f5be2e"), true)
			draw_rect(pr, Color("#7ec850") if not hovered else Color("#1b1917"), false, 1.2)
			draw_string(
				font,
				Vector2(pr.position.x + 6.0, pr.position.y + 15.0),
				str(p_entry.get("short", "")),
				HORIZONTAL_ALIGNMENT_LEFT,
				86.0,
				10,
				Color("#f2e6ce") if not hovered else Color("#1b1917")
			)
			_quick_ring_rects.append({
				"rect": pr,
				"km": float(p_entry.get("km", 5.0)),
				"label": str(p_entry.get("label", "")),
				"action": str(p_entry.get("action", "pin"))
			})

	func _draw_local_blast_and_plume(font: Font, gz_px: Vector2, house_px: Vector2, px_per_km: float) -> void:
		var wind_deg: float = float(_impact.get("wind_bearing_deg", 45.0))
		var plume_len_px: float = clampf(float(_impact.get("fallout_plume_length_km", 40.0)) * px_per_km, 45.0, 420.0)
		var wind_screen_rad: float = deg_to_rad(wind_deg - 90.0)
		var half_rad: float = deg_to_rad(NukePhysics.PLUME_HALF_ANGLE_DEG)

		# Outer & inner downwind fallout plume wedges
		var outer_cone := PackedVector2Array([gz_px])
		var inner_cone := PackedVector2Array([gz_px])
		var steps: int = 16
		for i in range(steps + 1):
			var frac: float = float(i) / float(steps)
			var ang_o: float = wind_screen_rad - half_rad + frac * (2.0 * half_rad)
			var profile: float = sin(frac * PI)
			var r_o: float = plume_len_px * (0.45 + 0.55 * profile)
			outer_cone.append(gz_px + Vector2(cos(ang_o), sin(ang_o)) * r_o)

			var ang_in: float = wind_screen_rad - half_rad * 0.55 + frac * (1.1 * half_rad)
			var r_in: float = plume_len_px * 0.62 * (0.45 + 0.55 * profile)
			inner_cone.append(gz_px + Vector2(cos(ang_in), sin(ang_in)) * r_in)

		if outer_cone.size() >= 3:
			draw_colored_polygon(outer_cone, Color(0.49, 0.78, 0.31, 0.22))
			draw_polyline(outer_cone, Color(0.49, 0.78, 0.31, 0.55), 1.4)
		if inner_cone.size() >= 3:
			draw_colored_polygon(inner_cone, Color(0.96, 0.75, 0.18, 0.20))

		# Thermal Burn Radius Ring
		var therm_px: float = maxf(8.0, float(_impact.get("thermal_radius_km", 7.8)) * px_per_km)
		draw_circle(gz_px, therm_px, Color(0.96, 0.75, 0.18, 0.08))
		_draw_dashed_circle(gz_px, therm_px, Color("#f5be2e"), 1.6, 36)

		# 5-psi Blast Overpressure Ring
		var blast_px: float = maxf(5.0, float(_impact.get("blast_5psi_radius_km", 4.6)) * px_per_km)
		draw_circle(gz_px, blast_px, Color(0.88, 0.35, 0.17, 0.16))
		draw_arc(gz_px, blast_px, 0.0, TAU, 48, Color("#e05a2b"), 2.2)

		# Fireball Core
		var fire_px: float = maxf(3.5, float(_impact.get("fireball_radius_km", 0.6)) * px_per_km)
		draw_circle(gz_px, fire_px, Color(1.0, 0.94, 0.62, 0.85))
		draw_arc(gz_px, fire_px, 0.0, TAU, 24, Color("#ffffff"), 1.5)

		# Animated expanding shockwave rings
		for sw in _shockwaves:
			if sw >= 0.0 and sw <= 1.2:
				var sw_r: float = lerpf(4.0, maxf(blast_px * 2.1, 68.0), clampf(sw, 0.0, 1.0))
				var sw_a: float = clampf(1.0 - sw, 0.0, 1.0) * 0.75
				draw_arc(gz_px, sw_r, 0.0, TAU, 48, Color(1.0, 0.78, 0.32, sw_a), 2.0)

		# Vector measurement line from Ground Zero to House & Ground Zero Reticle
		draw_line(gz_px, house_px, Color(0.96, 0.75, 0.18, 0.65), 1.5)
		_draw_gz_reticle(gz_px)

		# Position yellow distance tag away from HOME BUNKER and GZ reticle so zero text overlaps
		var sep_px: float = gz_px.distance_to(house_px)
		var dist_km: float = float(_impact.get("distance_km", 0.0))
		var tag_str: String = "%.2f km" % dist_km if dist_km < 10.0 else "%.1f km" % dist_km
		var home_excl := Rect2(house_px.x - 16.0, house_px.y - 16.0, 108.0, 32.0)
		var gz_excl := Rect2(gz_px.x - 17.0, gz_px.y - 17.0, 34.0, 34.0)
		var tag_box := Rect2()

		if sep_px < 56.0:
			if gz_px.y >= house_px.y - 4.0:
				var tx: float = clampf(gz_px.x - 29.0, 14.0, size.x - 72.0)
				var ty: float = clampf(maxf(gz_px.y + 18.0, house_px.y + 18.0), 14.0, size.y - 26.0)
				tag_box = Rect2(tx, ty, 58.0, 16.0)
				draw_line(gz_px + Vector2(0.0, 14.0), Vector2(tag_box.get_center().x, tag_box.position.y), Color(0.96, 0.75, 0.18, 0.55), 1.0)
			else:
				var tx_n: float = clampf(minf(gz_px.x, house_px.x) - 76.0, 14.0, size.x - 72.0)
				var ty_n: float = clampf(gz_px.y - 8.0, 14.0, size.y - 26.0)
				tag_box = Rect2(tx_n, ty_n, 58.0, 16.0)
				draw_line(gz_px + Vector2(-14.0, 0.0), Vector2(tag_box.end.x, tag_box.get_center().y), Color(0.96, 0.75, 0.18, 0.55), 1.0)
		else:
			var mid_pt: Vector2 = (gz_px + house_px) * 0.5
			var seg_dir: Vector2 = (gz_px - house_px).normalized()
			var perp := Vector2(-seg_dir.y, seg_dir.x)
			if perp.y < 0.0:
				perp = -perp
			var cand_center: Vector2 = mid_pt + perp * 16.0
			tag_box = Rect2(
				clampf(cand_center.x - 29.0, 14.0, size.x - 72.0),
				clampf(cand_center.y - 8.0, 14.0, size.y - 26.0),
				58.0,
				16.0
			)
			if tag_box.intersects(home_excl) or tag_box.intersects(gz_excl):
				tag_box.position.y = clampf(maxf(home_excl.end.y, gz_excl.end.y) + 4.0, 14.0, size.y - 26.0)

		draw_rect(tag_box, Color(0.08, 0.09, 0.08, 0.90), true)
		draw_rect(tag_box, Color("#f5be2e"), false, 1.0)
		draw_string(font, Vector2(tag_box.position.x + 4.0, tag_box.position.y + 12.0), tag_str, HORIZONTAL_ALIGNMENT_CENTER, 50.0, 10, Color("#f5be2e"))

	func _draw_global_world_map(font: Font, rect: Rect2) -> void:
		# Deep NORAD ocean background
		draw_rect(rect, Color("#0d171e"), true)
		var map_r: Rect2 = _get_world_map_rect()
		draw_rect(map_r, Color("#11212b"), true)

		# Lat/Lon 30-degree graticule
		for lon_i in range(-150, 180, 30):
			var p_top: Vector2 = _latlon_to_world_px(85.0, float(lon_i), map_r)
			var p_bot: Vector2 = _latlon_to_world_px(-85.0, float(lon_i), map_r)
			var col_m := Color(0.32, 0.55, 0.68, 0.28 if lon_i == 0 else 0.14)
			draw_line(p_top, p_bot, col_m, 1.0)
		for lat_i in [-60, -30, 0, 30, 60]:
			var p_left: Vector2 = _latlon_to_world_px(float(lat_i), -180.0, map_r)
			var p_right: Vector2 = _latlon_to_world_px(float(lat_i), 180.0, map_r)
			var col_p := Color(0.45, 0.72, 0.82, 0.34 if lat_i == 0 else 0.15)
			draw_line(p_left, p_right, col_p, 1.0)
			draw_string(
				font,
				Vector2(map_r.position.x + 3.0, p_left.y - 2.0),
				"%d" % lat_i,
				HORIZONTAL_ALIGNMENT_LEFT,
				32.0,
				9,
				Color(0.55, 0.75, 0.82, 0.55)
			)

		# Multi-point Vector Continents & Major Islands
		for poly_ll in _world_polys:
			var pts := PackedVector2Array()
			for v in poly_ll:
				var vec: Vector2 = v
				pts.append(_latlon_to_world_px(vec.y, vec.x, map_r))
			if pts.size() >= 3:
				var tri_idx: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
				if not tri_idx.is_empty():
					draw_colored_polygon(pts, Color("#2d3d2f"))
				pts.append(pts[0])
				draw_polyline(pts, Color("#62825e"), 1.3)

		draw_rect(map_r, Color("#3d5a66"), false, 1.2)

		var house_px: Vector2 = _latlon_to_world_px(_house_lat, _house_lon, map_r)
		var nlat: float = float(_impact.get("lat", _house_lat))
		var nlon: float = float(_impact.get("lon", _house_lon))
		var gz_px: Vector2 = _latlon_to_world_px(nlat, nlon, map_r)
		var home_badge_r := Rect2(house_px.x + 10.0, house_px.y - 9.0, 42.0, 16.0)
		if home_badge_r.end.x > size.x - 10.0:
			home_badge_r.position.x = house_px.x - home_badge_r.size.x - 10.0

		# Reference Strategic Cities (skip labels within 36px of HOME or GZ markers)
		for city in _world_cities:
			var c_px: Vector2 = _latlon_to_world_px(float(city.get("lat", 0.0)), float(city.get("lon", 0.0)), map_r)
			var dist_home: float = c_px.distance_to(house_px)
			var dist_gz: float = c_px.distance_to(gz_px)
			if dist_home >= 20.0 and dist_gz >= 20.0:
				draw_circle(c_px, 2.2, Color("#dccba6"))
			var city_lbl_r := Rect2(c_px.x + 4.0, c_px.y - 7.0, 46.0, 12.0)
			if dist_home >= 36.0 and dist_gz >= 36.0 and not city_lbl_r.intersects(home_badge_r.grow(4.0)):
				draw_string(
					font,
					c_px + Vector2(4.0, 3.0),
					str(city.get("short", "")),
					HORIZONTAL_ALIGNMENT_LEFT,
					90.0,
					9,
					Color(0.92, 0.88, 0.76, 0.72)
				)

		# Downwind regional/synoptic fallout plume indicator from GZ on World Map
		var wind_deg: float = float(_impact.get("wind_bearing_deg", 45.0))
		var w_rad: float = deg_to_rad(wind_deg - 90.0)
		var plume_world := PackedVector2Array([
			gz_px,
			gz_px + Vector2(cos(w_rad - 0.42), sin(w_rad - 0.42)) * 34.0,
			gz_px + Vector2(cos(w_rad), sin(w_rad)) * 42.0,
			gz_px + Vector2(cos(w_rad + 0.42), sin(w_rad + 0.42)) * 34.0
		])
		draw_colored_polygon(plume_world, Color(0.49, 0.78, 0.31, 0.35))

		# Great-circle geodesic trajectory arc from Ground Zero to Home Bunker
		var geo_ll: Array[Vector2] = NukePhysics.sample_geodesic_points(nlat, nlon, _house_lat, _house_lon, 44)
		var current_seg := PackedVector2Array()
		var prev_lon: float = 0.0
		for g_i in range(geo_ll.size()):
			var ll: Vector2 = geo_ll[g_i]
			if g_i > 0 and absf(ll.x - prev_lon) > 170.0:
				if current_seg.size() >= 2:
					draw_polyline(current_seg, Color(0.96, 0.75, 0.18, 0.82), 1.8)
				current_seg = PackedVector2Array()
			current_seg.append(_latlon_to_world_px(ll.y, ll.x, map_r))
			prev_lon = ll.x
		if current_seg.size() >= 2:
			draw_polyline(current_seg, Color(0.96, 0.75, 0.18, 0.82), 1.8)

		# Global Nuclear Winter vs Regional Zone tint ring around GZ
		var zone_id: String = str(_impact.get("zone", ""))
		var ring_col: Color = Color("#3b8ec2") if zone_id == "nuclear_winter" else Color("#e05a2b")
		for sw in _shockwaves:
			if sw >= 0.0 and sw <= 1.2:
				var r_w: float = lerpf(4.0, 56.0, clampf(sw, 0.0, 1.0))
				var a_w: float = clampf(1.0 - sw, 0.0, 1.0) * 0.85
				draw_arc(gz_px, r_w, 0.0, TAU, 36, Color(ring_col.r, ring_col.g, ring_col.b, a_w), 2.0)

		_draw_house_bunker_marker(font, house_px, false)
		_draw_gz_reticle(gz_px)

		# Top-right Global Telemetry Pill
		var dist_km: float = float(_impact.get("distance_km", 0.0))
		var g_box := Rect2(size.x - 242.0, 22.0, 216.0, 22.0)
		draw_rect(g_box, Color(0.06, 0.09, 0.12, 0.88), true)
		draw_rect(g_box, ring_col, false, 1.2)
		draw_string(
			font,
			Vector2(g_box.position.x + 6.0, g_box.position.y + 15.0),
			"GREAT-CIRCLE RANGE: %d km" % int(round(dist_km)),
			HORIZONTAL_ALIGNMENT_LEFT,
			204.0,
			10,
			Color("#f2e6ce")
		)

	func _draw_house_bunker_marker(font: Font, pos: Vector2, show_full_label: bool) -> void:
		var pulse_r: float = 11.0 + 4.0 * (0.5 + 0.5 * sin(_time * 4.5))
		draw_arc(pos, pulse_r, 0.0, TAU, 24, Color(0.49, 0.78, 0.31, 0.55), 1.5)
		draw_circle(pos, 7.5, Color("#1b1917"))
		draw_circle(pos, 6.0, Color("#7ec850"))
		# Tiny house roof + bunker base silhouette inside marker
		var roof := PackedVector2Array([
			pos + Vector2(0.0, -4.2),
			pos + Vector2(4.2, -0.5),
			pos + Vector2(-4.2, -0.5)
		])
		draw_colored_polygon(roof, Color("#1b1917"))
		draw_rect(Rect2(pos.x - 2.8, pos.y - 0.5, 5.6, 4.0), Color("#1b1917"), true)

		var lbl: String = "HOME BUNKER" if show_full_label else "HOME"
		var lbox := Rect2(pos.x + 10.0, pos.y - 9.0, 78.0 if show_full_label else 42.0, 16.0)
		if lbox.end.x > size.x - 10.0:
			lbox.position.x = pos.x - lbox.size.x - 10.0
		draw_rect(lbox, Color(0.08, 0.14, 0.08, 0.90), true)
		draw_rect(lbox, Color("#7ec850"), false, 1.0)
		draw_string(font, Vector2(lbox.position.x + 4.0, lbox.position.y + 12.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, lbox.size.x - 6.0, 9, Color("#7ec850"))

	func _draw_gz_reticle(pos: Vector2) -> void:
		draw_arc(pos, 10.0, 0.0, TAU, 24, Color("#1b1917"), 3.2)
		draw_arc(pos, 10.0, 0.0, TAU, 24, Color("#e05a2b"), 1.8)
		draw_line(pos + Vector2(-15.0, 0.0), pos + Vector2(-5.0, 0.0), Color("#f5be2e"), 2.0)
		draw_line(pos + Vector2(5.0, 0.0), pos + Vector2(15.0, 0.0), Color("#f5be2e"), 2.0)
		draw_line(pos + Vector2(0.0, -15.0), pos + Vector2(0.0, -5.0), Color("#f5be2e"), 2.0)
		draw_line(pos + Vector2(0.0, 5.0), pos + Vector2(0.0, 15.0), Color("#f5be2e"), 2.0)
		draw_circle(pos, 2.8, Color("#f5be2e"))

	func _draw_dashed_circle(center: Vector2, radius: float, col: Color, width: float, segs: int) -> void:
		var step: float = TAU / float(segs)
		for i in range(0, segs, 2):
			var a0: float = float(i) * step
			var a1: float = float(i + 1) * step
			draw_arc(center, radius, a0, a1, 5, col, width)

	func _draw_legend_item(font: Font, pos: Vector2, col: Color, text: String) -> void:
		draw_rect(Rect2(pos.x, pos.y - 8.0, 9.0, 9.0), col, true)
		draw_rect(Rect2(pos.x, pos.y - 8.0, 9.0, 9.0), Color("#1b1917"), false, 1.0)
		draw_string(font, Vector2(pos.x + 14.0, pos.y), text, HORIZONTAL_ALIGNMENT_LEFT, 138.0, 10, Color("#f2e6ce"))

	func _init_world_geometry() -> void:
		# Accurate multi-point continent & island silhouettes (each [lon, lat] loop verified simple)
		_world_polys = [
			# North America
			[
				Vector2(-166, 65), Vector2(-160, 71), Vector2(-138, 70), Vector2(-120, 70),
				Vector2(-98, 69), Vector2(-84, 67), Vector2(-93, 61), Vector2(-89, 56),
				Vector2(-80, 52), Vector2(-78, 59), Vector2(-74, 62), Vector2(-64, 60),
				Vector2(-55, 52), Vector2(-60, 46), Vector2(-67, 44), Vector2(-71, 41),
				Vector2(-76, 36), Vector2(-81, 31), Vector2(-80, 25), Vector2(-83, 29),
				Vector2(-90, 29), Vector2(-97, 26), Vector2(-96, 19), Vector2(-90, 21),
				Vector2(-87, 21), Vector2(-88, 16), Vector2(-83, 15), Vector2(-83, 10),
				Vector2(-78, 8), Vector2(-80, 7), Vector2(-86, 11), Vector2(-95, 16),
				Vector2(-105, 20), Vector2(-110, 27), Vector2(-113, 31), Vector2(-114, 29),
				Vector2(-111, 23), Vector2(-115, 27), Vector2(-118, 33), Vector2(-123, 38),
				Vector2(-124, 48), Vector2(-132, 55), Vector2(-141, 60), Vector2(-151, 60),
				Vector2(-161, 55), Vector2(-166, 60)
			],
			# Greenland
			[
				Vector2(-52, 60), Vector2(-42, 60), Vector2(-22, 70), Vector2(-18, 79),
				Vector2(-36, 83), Vector2(-60, 81), Vector2(-71, 76), Vector2(-56, 68)
			],
			# Cuba
			[Vector2(-85, 22), Vector2(-79, 23), Vector2(-74, 20), Vector2(-81, 20)],
			# South America
			[
				Vector2(-78, 9), Vector2(-71, 12), Vector2(-61, 10), Vector2(-50, 1),
				Vector2(-35, -6), Vector2(-38, -15), Vector2(-41, -22), Vector2(-48, -26),
				Vector2(-54, -34), Vector2(-62, -40), Vector2(-67, -48), Vector2(-67, -55),
				Vector2(-73, -53), Vector2(-75, -45), Vector2(-72, -35), Vector2(-70, -18),
				Vector2(-77, -11), Vector2(-81, -5), Vector2(-79, 2)
			],
			# Mainland Europe
			[
				Vector2(-9, 37), Vector2(-9, 43), Vector2(-2, 44), Vector2(-4, 48),
				Vector2(2, 51), Vector2(8, 55), Vector2(10, 57), Vector2(12, 54),
				Vector2(19, 55), Vector2(24, 59), Vector2(29, 60), Vector2(32, 65),
				Vector2(40, 67), Vector2(54, 68), Vector2(56, 54), Vector2(49, 46),
				Vector2(39, 44), Vector2(30, 46), Vector2(28, 41), Vector2(24, 40),
				Vector2(23, 37), Vector2(19, 40), Vector2(14, 45), Vector2(16, 41),
				Vector2(15, 38), Vector2(11, 43), Vector2(5, 43), Vector2(0, 39),
				Vector2(-5, 36)
			],
			# Scandinavia (Norway / Sweden / Finland)
			[
				Vector2(5, 59), Vector2(6, 63), Vector2(14, 68), Vector2(26, 71),
				Vector2(31, 69), Vector2(29, 62), Vector2(23, 61), Vector2(20, 64),
				Vector2(18, 59), Vector2(14, 56), Vector2(11, 58)
			],
			# Great Britain, Ireland, Iceland
			[Vector2(-5, 50), Vector2(-6, 54), Vector2(-5, 58), Vector2(-2, 58), Vector2(1, 52), Vector2(-1, 50)],
			[Vector2(-10, 52), Vector2(-9, 55), Vector2(-6, 55), Vector2(-6, 52)],
			[Vector2(-24, 64), Vector2(-22, 66), Vector2(-14, 66), Vector2(-15, 64)],
			# Africa
			[
				Vector2(-17, 15), Vector2(-16, 22), Vector2(-10, 30), Vector2(-6, 36),
				Vector2(10, 37), Vector2(12, 33), Vector2(24, 32), Vector2(32, 31),
				Vector2(39, 20), Vector2(43, 12), Vector2(51, 12), Vector2(48, 5),
				Vector2(41, -2), Vector2(40, -11), Vector2(35, -20), Vector2(32, -28),
				Vector2(25, -34), Vector2(18, -35), Vector2(14, -24), Vector2(12, -14),
				Vector2(12, -5), Vector2(9, 4), Vector2(2, 6), Vector2(-7, 5),
				Vector2(-13, 9)
			],
			# Madagascar
			[Vector2(44, -25), Vector2(44, -18), Vector2(49, -12), Vector2(50, -18), Vector2(47, -25)],
			# Asia
			[
				Vector2(27, 41), Vector2(36, 42), Vector2(48, 45), Vector2(55, 68),
				Vector2(74, 72), Vector2(102, 75), Vector2(135, 72), Vector2(168, 69),
				Vector2(178, 65), Vector2(164, 58), Vector2(158, 51), Vector2(155, 54),
				Vector2(156, 60), Vector2(143, 55), Vector2(139, 46), Vector2(131, 42),
				Vector2(129, 35), Vector2(126, 35), Vector2(124, 39), Vector2(120, 39),
				Vector2(122, 31), Vector2(117, 23), Vector2(109, 20), Vector2(109, 12),
				Vector2(103, 9), Vector2(104, 1), Vector2(100, 3), Vector2(98, 9),
				Vector2(97, 16), Vector2(91, 22), Vector2(86, 20), Vector2(80, 14),
				Vector2(77, 8), Vector2(73, 16), Vector2(70, 23), Vector2(65, 25),
				Vector2(56, 26), Vector2(49, 30), Vector2(50, 26), Vector2(56, 24),
				Vector2(59, 21), Vector2(53, 16), Vector2(44, 13), Vector2(39, 21),
				Vector2(34, 28), Vector2(36, 36), Vector2(27, 37)
			],
			# Japan, Sumatra, Borneo, Java, Philippines, Sri Lanka
			[Vector2(130, 32), Vector2(136, 34), Vector2(141, 37), Vector2(144, 43), Vector2(140, 42), Vector2(136, 37), Vector2(131, 34)],
			[Vector2(95, 5), Vector2(100, 2), Vector2(105, -5), Vector2(103, -6), Vector2(96, 3)],
			[Vector2(109, 2), Vector2(115, 6), Vector2(118, 4), Vector2(117, -3), Vector2(111, -3)],
			[Vector2(106, -6), Vector2(114, -7), Vector2(114, -9), Vector2(106, -8)],
			[Vector2(120, 18), Vector2(123, 15), Vector2(126, 8), Vector2(122, 7), Vector2(120, 13)],
			[Vector2(80, 9), Vector2(82, 7), Vector2(81, 6), Vector2(79, 7)],
			# Australia, Tasmania, New Guinea, New Zealand
			[
				Vector2(114, -22), Vector2(122, -17), Vector2(130, -12), Vector2(136, -12),
				Vector2(138, -16), Vector2(142, -11), Vector2(147, -19), Vector2(153, -27),
				Vector2(150, -36), Vector2(142, -38), Vector2(134, -34), Vector2(126, -32),
				Vector2(116, -34), Vector2(113, -26)
			],
			[Vector2(145, -41), Vector2(148, -41), Vector2(147, -43), Vector2(145, -43)],
			[Vector2(132, -2), Vector2(141, -3), Vector2(150, -9), Vector2(145, -9), Vector2(135, -5)],
			[Vector2(173, -35), Vector2(178, -38), Vector2(174, -42), Vector2(170, -46), Vector2(167, -45), Vector2(172, -40)],
			# Antarctica
			[
				Vector2(-179, -84), Vector2(-179, -74), Vector2(-125, -73), Vector2(-72, -70),
				Vector2(-60, -64), Vector2(-54, -72), Vector2(-15, -71), Vector2(35, -69),
				Vector2(85, -67), Vector2(135, -68), Vector2(172, -73), Vector2(179, -76),
				Vector2(179, -84)
			]
		]

		_world_cities = [
			{"name": "Washington D.C., USA", "short": "D.C.", "lat": 38.8951, "lon": -77.0364},
			{"name": "Nevada Test Site", "short": "NTS", "lat": 37.1167, "lon": -116.0500},
			{"name": "London Thames Sector", "short": "London", "lat": 51.5074, "lon": -0.1278},
			{"name": "Moscow", "short": "Moscow", "lat": 55.7558, "lon": 37.6173},
			{"name": "Tokyo Bay Metro", "short": "Tokyo", "lat": 35.6762, "lon": 139.6503},
			{"name": "Sydney Harbor", "short": "Sydney", "lat": -33.8688, "lon": 151.2093}
		]


# ==============================================================================
# INNER CLASS 2: PROCEDURAL WIND VECTOR COMPASS DIAL
# ==============================================================================
class _WindDialControl extends Control:
	signal angle_selected(deg_val: float)

	var _wind_deg: float = 45.0
	var _house_bearing_deg: float = 45.0
	var _in_plume: bool = true
	var _dragging: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_state(wind_d: float, house_brng: float, in_plume: bool) -> void:
		_wind_deg = wind_d
		_house_bearing_deg = house_brng
		_in_plume = in_plume
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_dragging = mb.pressed
				if mb.pressed:
					_emit_from_pos(mb.position)
		elif event is InputEventMouseMotion and _dragging:
			var mm: InputEventMouseMotion = event
			_emit_from_pos(mm.position)

	func _emit_from_pos(pos: Vector2) -> void:
		var c: Vector2 = size * 0.5
		var v: Vector2 = pos - c
		if v.length() > 3.0:
			var deg_v: float = fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)
			angle_selected.emit(deg_v)

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 4.0

		draw_circle(c, r, Color("#121713"))
		draw_arc(c, r, 0.0, TAU, 32, Color("#4c594d"), 2.0)

		# Plume cone sector
		var w_rad: float = deg_to_rad(_wind_deg - 90.0)
		var half_p: float = deg_to_rad(NukePhysics.PLUME_HALF_ANGLE_DEG)
		var cone := PackedVector2Array([c])
		for i in range(9):
			var a: float = w_rad - half_p + (float(i) / 8.0) * (2.0 * half_p)
			cone.append(c + Vector2(cos(a), sin(a)) * (r - 3.0))
		var cone_col: Color = Color(0.88, 0.35, 0.17, 0.38) if _in_plume else Color(0.49, 0.78, 0.31, 0.28)
		draw_colored_polygon(cone, cone_col)

		# House bearing dot on compass rim
		var h_rad: float = deg_to_rad(_house_bearing_deg - 90.0)
		var h_pt: Vector2 = c + Vector2(cos(h_rad), sin(h_rad)) * (r - 6.0)
		draw_circle(h_pt, 3.5, Color("#7ec850"))

		# Wind vector arrow
		var tip: Vector2 = c + Vector2(cos(w_rad), sin(w_rad)) * (r - 5.0)
		var tail: Vector2 = c - Vector2(cos(w_rad), sin(w_rad)) * (r * 0.45)
		draw_line(tail, tip, Color("#f5be2e"), 2.4)
		var left_w: Vector2 = tip - Vector2(cos(w_rad - 0.5), sin(w_rad - 0.5)) * 8.0
		var right_w: Vector2 = tip - Vector2(cos(w_rad + 0.5), sin(w_rad + 0.5)) * 8.0
		draw_colored_polygon(PackedVector2Array([tip, left_w, right_w]), Color("#f5be2e"))
		draw_circle(c, 3.0, Color("#e05a2b"))

		draw_string(font, Vector2(c.x - 4.0, c.y - r + 10.0), "N", HORIZONTAL_ALIGNMENT_LEFT, 14.0, 9, Color("#f2e6ce"))


# ==============================================================================
# INNER CLASS 3: CIVIL DEFENSE CONDITION FORECAST DOSSIER PANEL
# ==============================================================================
class _ForecastPanelControl extends Control:
	var _impact: Dictionary = {}
	var _disp_tremor: float = 0.0
	var _disp_struct: float = 0.0
	var _disp_raider: float = 0.0
	var _disp_rad: float = 0.0

	func set_impact(impact_dict: Dictionary) -> void:
		_impact = impact_dict
		queue_redraw()

	func advance_anim(delta: float) -> void:
		var k: float = clampf(delta * 9.0, 0.0, 1.0)
		_disp_tremor = lerpf(_disp_tremor, float(_impact.get("tremor_intensity", 0.5)), k)
		_disp_struct = lerpf(_disp_struct, float(_impact.get("structural_damage", 0.2)), k)
		_disp_raider = lerpf(_disp_raider, float(_impact.get("raider_aggression", 0.5)), k)
		_disp_rad = lerpf(_disp_rad, clampf(float(_impact.get("initial_sv_hr", 4.5)) / 10.0, 0.0, 1.0), k)
		queue_redraw()

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var full := Rect2(Vector2.ZERO, size)

		# Steel outer clipboard & warm CONELRAD parchment sheet
		draw_rect(full, Color("#232824"), true)
		draw_rect(full, Color("#1b1917"), false, 3.0)

		var sheet := Rect2(8.0, 8.0, size.x - 16.0, size.y - 16.0)
		draw_rect(sheet, Color("#f2e6ce"), true)
		draw_rect(sheet, Color("#1b1917"), false, 2.0)

		# Aged paper header band
		var hdr_band := Rect2(10.0, 10.0, size.x - 20.0, 44.0)
		draw_rect(hdr_band, Color("#dccba6"), true)
		draw_line(Vector2(10.0, 54.0), Vector2(size.x - 10.0, 54.0), Color("#1b1917"), 2.0)

		draw_string(
			font,
			Vector2(18.0, 29.0),
			"CIVIL DEFENSE CONDITION FORECAST",
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 36.0,
			15,
			Color("#1b1917")
		)
		var tgt_str: String = "TARGET: " + str(_impact.get("target_name", "Strategic Detonation"))
		draw_string(
			font,
			Vector2(18.0, 47.0),
			tgt_str,
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 36.0,
			11,
			Color("#473f35")
		)

		# Zone Classification Badge (y=62..96)
		var zone_id: String = str(_impact.get("zone", "near_blast"))
		var zone_title: String = str(_impact.get("zone_title", "METRO STRIKE ZONE"))
		var zone_col: Color = _get_zone_color(zone_id)
		var badge_r := Rect2(16.0, 62.0, size.x - 32.0, 34.0)
		draw_rect(badge_r, zone_col, true)
		draw_rect(badge_r, Color("#1b1917"), false, 2.0)
		var zone_fg: Color = Color("#1b1917") if zone_id == "near_blast" else Color("#f2e6ce")
		draw_string(
			font,
			Vector2(badge_r.position.x + 8.0, badge_r.position.y + 23.0),
			"ZONE: " + zone_title,
			HORIZONTAL_ALIGNMENT_CENTER,
			badge_r.size.x - 16.0,
			14,
			zone_fg
		)

		# 2x2 Telemetry Readout Cards (y=104..220)
		var card_w: float = (size.x - 40.0) * 0.5
		var card_h: float = 54.0
		var dist_km: float = float(_impact.get("distance_km", 0.0))
		var dist_txt: String = "%.2f km" % dist_km if dist_km < 10.0 else ("%.1f km" % dist_km if dist_km < 100.0 else "%d km" % int(round(dist_km)))
		var brng_str: String = NukePhysics.compass_label(float(_impact.get("bearing_to_nuke_deg", 0.0)))

		var sv_hr: float = float(_impact.get("initial_sv_hr", 4.5))
		var in_plume: bool = bool(_impact.get("in_fallout_plume", false))
		var rad_sub: String = "DOWNWIND PLUME!" if (in_plume and zone_id != "nuclear_winter") else ("%d-day decay" % int(_impact.get("fallout_days", 10)))

		var temp_c: float = float(_impact.get("bunker_temp_c", 20.0))
		var temp_txt: String = "%+.1f °C" % temp_c
		var temp_sub: String = "SCORCHING HEAT" if temp_c >= 30.0 else ("FREEZING WINTER!" if temp_c <= -3.0 else ("NUCLEAR AUTUMN" if temp_c <= 4.5 else ("CHILLY DUSK" if temp_c <= 14.0 else "BLAST WARMTH")))

		var scout_s: float = float(_impact.get("scout_seconds", 8.0))
		var scav_s: float = 30.0 if GameState.difficulty == "hard" else 60.0

		_draw_telemetry_card(
			font,
			Rect2(16.0, 104.0, card_w, card_h),
			"GROUND ZERO RANGE",
			dist_txt,
			"Bearing: %s from home" % brng_str,
			Color("#1b1917")
		)
		_draw_telemetry_card(
			font,
			Rect2(24.0 + card_w, 104.0, card_w, card_h),
			"SURFACE RADIATION",
			RadiationModel.format_rate(sv_hr * 1000.0) + " @H+1",
			rad_sub,
			Color("#b5331d") if sv_hr >= 5.0 else Color("#2f6b28")
		)
		_draw_telemetry_card(
			font,
			Rect2(16.0, 164.0, card_w, card_h),
			"BUNKER TEMPERATURE",
			temp_txt,
			temp_sub,
			Color("#c93824") if temp_c >= 28.0 else (Color("#23689b") if temp_c <= 2.0 else Color("#1b1917"))
		)
		_draw_telemetry_card(
			font,
			Rect2(24.0 + card_w, 164.0, card_w, card_h),
			"WARNING + GRAB TIMER",
			"%.0fs + %.0fs" % [scout_s, scav_s],
			"%.0fs Recon / %.0fs Scavenge (%s)" % [scout_s, scav_s, GameState.difficulty.to_upper()],
			Color("#1b1917")
		)

		# Shockwave Tremor & Hazard Bars Box (y=226..322)
		var gauge_box := Rect2(16.0, 226.0, size.x - 32.0, 94.0)
		draw_rect(gauge_box, Color("#e5d7b8"), true)
		draw_rect(gauge_box, Color("#1b1917"), false, 1.5)

		var trem_pct: int = int(round(float(_impact.get("tremor_intensity", 0.5)) * 100.0))
		draw_string(font, Vector2(24.0, 243.0), "SHOCKWAVE TREMOR INTENSITY", HORIZONTAL_ALIGNMENT_LEFT, 260.0, 11, Color("#1b1917"))
		draw_string(font, Vector2(gauge_box.end.x - 68.0, 243.0), "%d%%" % trem_pct, HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 12, Color("#b5331d") if trem_pct >= 65 else Color("#1b1917"))

		# Segmented seismograph tremor bar
		var seg_count: int = 16
		var bar_x: float = 24.0
		var bar_w: float = gauge_box.size.x - 16.0
		var seg_w: float = (bar_w - float(seg_count - 1) * 3.0) / float(seg_count)
		for s_i in range(seg_count):
			var thresh: float = float(s_i + 1) / float(seg_count)
			var sr := Rect2(bar_x + float(s_i) * (seg_w + 3.0), 248.0, seg_w, 14.0)
			var active_seg: bool = _disp_tremor >= (thresh - 0.03)
			var scol := Color("#c8b896")
			if active_seg:
				scol = Color("#c93824") if s_i >= 11 else (Color("#e07b24") if s_i >= 6 else Color("#629632"))
			draw_rect(sr, scol, true)
			draw_rect(sr, Color("#1b1917"), false, 1.0)

		# Three secondary mini-gauges: Hull Loss (aligned to BunkerSim), Fallout Duration, Raider Threat
		var mini_w: float = (bar_w - 16.0) / 3.0
		var struct_raw: float = clampf(float(_impact.get("structural_damage", 0.2)), 0.0, 1.0)
		var hull_integ_pct: int = int(round(clampf(100.0 - struct_raw * 45.0, 25.0, 100.0)))
		var hull_loss_pct: int = int(_impact.get("hull_loss_pct", 100 - hull_integ_pct))
		_draw_mini_bar(font, Rect2(24.0, 272.0, mini_w, 40.0), "HULL LOSS", "%d%%" % hull_loss_pct, _disp_struct, Color("#d9532b"))
		var f_days: int = int(_impact.get("fallout_days", 10))
		_draw_mini_bar(font, Rect2(24.0 + mini_w + 8.0, 272.0, mini_w, 40.0), "FALLOUT", "%d DAYS" % f_days, clampf(float(f_days) / 20.0, 0.0, 1.0), Color("#6a9a3b"))
		_draw_mini_bar(font, Rect2(24.0 + (mini_w + 8.0) * 2.0, 272.0, mini_w, 40.0), "RAIDERS", "%d%%" % int(round(float(_impact.get("raider_aggression", 0.5)) * 100.0)), _disp_raider, Color("#b5331d"))

		# Survival Consequences Section (y=328..574)
		draw_string(font, Vector2(18.0, 344.0), "SURVIVAL CONSEQUENCES & DOCTRINE:", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36.0, 12, Color("#1b1917"))
		draw_line(Vector2(18.0, 349.0), Vector2(size.x - 18.0, 349.0), Color("#8c7b62"), 1.0)

		var cur_y: float = 365.0
		var max_text_w: float = size.x - 42.0
		var summary_str: String = str(_impact.get("summary", ""))
		cur_y = _draw_wrapped_text(font, summary_str, Vector2(18.0, cur_y), max_text_w, 11, 14.0, Color("#3a3229")) + 6.0

		var raw_bullets: Variant = _impact.get("condition_bullets", [])
		if raw_bullets is Array:
			var arr_b: Array = raw_bullets
			for b_item in arr_b:
				if cur_y > size.y - 22.0:
					break
				var b_str: String = str(b_item)
				# Hazard bullet diamond
				var d_pt := Vector2(22.0, cur_y - 4.0)
				draw_colored_polygon(PackedVector2Array([
					d_pt + Vector2(0, -4), d_pt + Vector2(4, 0), d_pt + Vector2(0, 4), d_pt + Vector2(-4, 0)
				]), zone_col)
				cur_y = _draw_wrapped_text(font, b_str, Vector2(31.0, cur_y), max_text_w - 13.0, 11, 13.5, Color("#1b1917")) + 5.0

	func _draw_telemetry_card(font: Font, r: Rect2, title: String, big_val: String, sub: String, val_col: Color) -> void:
		draw_rect(r, Color("#faf2e1"), true)
		draw_rect(r, Color("#1b1917"), false, 1.5)
		draw_string(font, Vector2(r.position.x + 7.0, r.position.y + 13.0), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, 9, Color("#5c5245"))
		draw_string(font, Vector2(r.position.x + 7.0, r.position.y + 34.0), big_val, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, 16, val_col)
		draw_string(font, Vector2(r.position.x + 7.0, r.position.y + 48.0), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, 9, Color("#4a4237"))

	func _draw_mini_bar(font: Font, r: Rect2, label: String, val_txt: String, ratio: float, fill_col: Color) -> void:
		draw_string(font, Vector2(r.position.x, r.position.y + 12.0), label + ": " + val_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 9, Color("#1b1917"))
		var bar_r := Rect2(r.position.x, r.position.y + 17.0, r.size.x, 10.0)
		draw_rect(bar_r, Color("#c8b896"), true)
		var fill_w: float = clampf(ratio, 0.0, 1.0) * bar_r.size.x
		if fill_w > 1.0:
			draw_rect(Rect2(bar_r.position.x, bar_r.position.y, fill_w, bar_r.size.y), fill_col, true)
		draw_rect(bar_r, Color("#1b1917"), false, 1.0)

	func _draw_wrapped_text(font: Font, text: String, pos: Vector2, max_w: float, font_size: int, line_h: float, col: Color) -> float:
		var words: PackedStringArray = text.split(" ", false)
		var line: String = ""
		var y: float = pos.y
		for w in words:
			var cand: String = w if line.is_empty() else (line + " " + w)
			var cw: float = font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if cw > max_w and not line.is_empty():
				draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, max_w + 8.0, font_size, col)
				y += line_h
				line = w
			else:
				line = cand
		if not line.is_empty():
			draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, max_w + 8.0, font_size, col)
			y += line_h
		return y

	func _get_zone_color(zone_id: String) -> Color:
		match zone_id:
			"ground_zero_edge":
				return Color("#c93824")
			"near_blast":
				return Color("#f5be2e")
			"regional_fallout":
				return Color("#4e7a32")
			"nuclear_winter":
				return Color("#2b6f9e")
		return Color("#e05a2b")


# ==============================================================================
# INNER CLASS 4: PULSING HAZARD SIREN LAUNCH BUTTON
# ==============================================================================
class _HazardSirenButton extends Button:
	var _t: float = 0.0

	func _init() -> void:
		flat = true

	func advance_anim(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var r := Rect2(Vector2.ZERO, size)
		var pulse: float = 0.5 + 0.5 * sin(_t * 6.5)
		var hovered: bool = is_hovered()

		var base_col: Color = Color("#c93824").lerp(Color("#e85d2a"), pulse * 0.65)
		if hovered:
			base_col = base_col.lightened(0.12)
		draw_rect(r, base_col, true)

		# Left & right CONELRAD yellow/black hazard stripe end-caps
		for side_x in [0.0, size.x - 28.0]:
			var cap := Rect2(side_x, 0.0, 28.0, size.y)
			draw_rect(cap, Color("#1b1917"), true)
			for sy in range(0, int(size.y), 12):
				draw_rect(Rect2(side_x, float(sy), 28.0, 6.0), Color("#f5be2e"), true)

		var border_col: Color = Color("#f5be2e").lerp(Color("#fff5c0"), pulse)
		draw_rect(r, Color("#1b1917"), false, 3.0)
		draw_rect(r.grow(-3.0), border_col, false, 2.0)

		var ascent: float = font.get_ascent(16)
		var text_y: float = (size.y - font.get_height(16)) * 0.5 + ascent
		draw_string(
			font,
			Vector2(34.0, text_y + 1.0),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 68.0,
			16,
			Color("#1b1917")
		)
		draw_string(
			font,
			Vector2(33.0, text_y),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 68.0,
			16,
			Color("#fff6dc")
		)
