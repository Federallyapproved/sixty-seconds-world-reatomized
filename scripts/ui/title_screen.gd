class_name TitleScreen
extends Control

## Animated title screen (1280x720) styled as a present-day emergency alert:
## a radiation warning badge, a map grid with spreading alert rings, a phone with
## no signal, hazard-tape borders, floating supply icons, and the automatic 2.4 s
## demo handoff.

const DEMO_HOLD_DURATION: float = 2.4

var _anim_time: float = 0.0
var _demo_started_on_ready: bool = false
var _demo_timer: float = 0.0
var _geiger_played_1: bool = false
var _geiger_played_2: bool = false
var _click_played: bool = false
var _transitioning: bool = false

var _btn_full_setup: Button = null
var _btn_quick_scavenge: Button = null
var _btn_demo: Button = null
var _status_label: Label = null
var _crt_overlay: Control = null

const FLOATING_SUPPLIES := [
	{"id": "food", "label": "CANNED FOOD", "side": -1, "row": 0, "phase": 0.0},
	{"id": "gas_mask", "label": "GAS MASK", "side": -1, "row": 1, "phase": 1.6},
	{"id": "radio", "label": "CRANK RADIO", "side": -1, "row": 2, "phase": 3.1},
	{"id": "water", "label": "BOTTLED WATER", "side": 1, "row": 0, "phase": 0.8},
	{"id": "medkit", "label": "FIRST AID KIT", "side": 1, "row": 1, "phase": 2.4},
	{"id": "suitcase", "label": "GO BAG", "side": 1, "row": 2, "phase": 4.0}
]

const RADAR_BLIPS := [
	{"name": "SEATTLE", "uv": Vector2(0.075, 0.11), "phase": 0.2},
	{"name": "CONCORD", "uv": Vector2(0.195, 0.11), "phase": 1.5},
	{"name": "BROOKLYN", "uv": Vector2(0.075, 0.91), "phase": 2.8},
	{"name": "LONDON", "uv": Vector2(0.845, 0.11), "phase": 0.9},
	{"name": "TOKYO", "uv": Vector2(0.865, 0.91), "phase": 2.1}
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = ThemeHelper.get_game_theme()

	_demo_started_on_ready = GameState.demo_mode
	_build_ui()

func _build_ui() -> void:
	# Feature Callout Pills (2x2 centered grid at y = 334..406)
	var pills_holder := GridContainer.new()
	pills_holder.name = "FeaturePills"
	pills_holder.columns = 2
	pills_holder.add_theme_constant_override("h_separation", 12)
	pills_holder.add_theme_constant_override("v_separation", 8)
	pills_holder.position = Vector2(328.0, 334.0)
	pills_holder.size = Vector2(624.0, 72.0)
	add_child(pills_holder)

	var pill_specs := [
		{"text": "REAL OPENSTREETMAP HOUSES & PLACES", "dot": ThemeHelper.COLOR_OK_GREEN},
		{"text": "BLAST & FALLOUT PHYSICS", "dot": ThemeHelper.COLOR_ALERT_RED},
		{"text": "CUSTOM FAMILY CREATOR", "dot": ThemeHelper.COLOR_ALERT_AMBER},
		{"text": "60-SECOND GRAB, THEN THE SHELTER", "dot": ThemeHelper.COLOR_WATER_BLUE}
	]
	for spec in pill_specs:
		var p_text: String = str(spec.get("text", ""))
		var p_dot: Color = spec.get("dot", ThemeHelper.COLOR_ALERT_AMBER)
		pills_holder.add_child(_make_feature_pill(p_text, p_dot))

	# Central Command Console Card (y = 418..638)
	var console_panel := ThemeHelper.make_card_panel(Color(0.10, 0.12, 0.14, 0.96), ThemeHelper.COLOR_BORDER)
	console_panel.name = "CommandConsole"
	console_panel.position = Vector2(356.0, 418.0)
	console_panel.size = Vector2(568.0, 218.0)
	add_child(console_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	console_panel.add_child(vbox)

	var console_hdr := Label.new()
	console_hdr.text = "Choose how to start"
	console_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	console_hdr.add_theme_font_size_override("font_size", 13)
	console_hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT_MUTED)
	vbox.add_child(console_hdr)

	_btn_full_setup = ThemeHelper.make_hazard_button("NEW GAME  (FULL SETUP)", Vector2(520.0, 50.0))
	_btn_full_setup.pressed.connect(_on_new_protocol_pressed)
	vbox.add_child(_btn_full_setup)

	_btn_quick_scavenge = ThemeHelper.make_alert_button("QUICK GRAB  (DEFAULT HOUSE)", Vector2(520.0, 46.0))
	_btn_quick_scavenge.pressed.connect(_on_quick_scavenge_pressed)
	vbox.add_child(_btn_quick_scavenge)

	# Demo, the Survival Almanac and the achievements share the last row.
	var row := HBoxContainer.new()
	row.name = "MetaRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	_btn_demo = Button.new()
	_btn_demo.text = "WATCH THE DEMO"
	_btn_demo.custom_minimum_size = Vector2(168.0, 44.0)
	_btn_demo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_demo.pressed.connect(_on_watch_demo_pressed)
	row.add_child(_btn_demo)
	var btn_almanac := Button.new()
	btn_almanac.name = "AlmanacButton"
	btn_almanac.text = "ALMANAC"
	btn_almanac.custom_minimum_size = Vector2(168.0, 44.0)
	btn_almanac.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_almanac.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		GameState.request_screen(GameState.SCREEN_ALMANAC))
	row.add_child(btn_almanac)
	var btn_ach := Button.new()
	btn_ach.name = "AchievementsButton"
	btn_ach.text = "ACHIEVEMENTS %d/%d" % [GameState.achievements_unlocked.size(), ShelterData.achievements().size()]
	btn_ach.custom_minimum_size = Vector2(168.0, 44.0)
	btn_ach.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_ach.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		GameState.request_screen(GameState.SCREEN_ACHIEVEMENTS))
	row.add_child(btn_ach)

	# Bottom Telemetry Strip (y = 650..688)
	var footer_panel := ThemeHelper.make_card_panel(Color(0.10, 0.12, 0.14, 0.92), ThemeHelper.COLOR_BORDER)
	footer_panel.position = Vector2(210.0, 650.0)
	footer_panel.size = Vector2(860.0, 38.0)
	var footer_sb := StyleBoxFlat.new()
	footer_sb.bg_color = Color(0.10, 0.12, 0.14, 0.92)
	footer_sb.border_color = ThemeHelper.COLOR_BORDER
	footer_sb.set_border_width_all(1)
	footer_sb.set_corner_radius_all(19)
	footer_sb.content_margin_left = 12.0
	footer_sb.content_margin_right = 12.0
	footer_sb.content_margin_top = 4.0
	footer_sb.content_margin_bottom = 4.0
	footer_panel.add_theme_stylebox_override("panel", footer_sb)
	add_child(footer_panel)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.add_theme_font_size_override("font_size", 13)
	if _demo_started_on_ready:
		_status_label.text = "● AUTO-DEMO RUNNING — STARTING IN 2.4 s..."
		_status_label.add_theme_color_override("font_color", ThemeHelper.COLOR_ALERT_AMBER)
	else:
		var house_addr: String = LocationText.area_header()
		_status_label.text = "AREA: %s   •   NO SERVICE   •   EMERGENCY ALERTS ONLY" % house_addr.to_upper()
		_status_label.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT_MUTED)
	footer_panel.add_child(_status_label)

	# Non-interactive edge vignette on top
	_crt_overlay = _CrtOverlay.new()
	_crt_overlay.name = "CrtScanlineOverlay"
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_crt_overlay)

func _make_feature_pill(label_str: String, dot_color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(306.0, 32.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.14, 0.92)
	sb.border_color = ThemeHelper.COLOR_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	pill.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(hbox)

	var dot := ColorRect.new()
	dot.color = dot_color
	dot.custom_minimum_size = Vector2(8.0, 8.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(dot)

	var lbl := Label.new()
	lbl.text = label_str
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT)
	hbox.add_child(lbl)
	return pill

func _process(delta: float) -> void:
	_anim_time += delta
	if _crt_overlay != null:
		_crt_overlay.set("scan_time", _anim_time)
		_crt_overlay.queue_redraw()

	if _demo_started_on_ready and not _transitioning:
		_demo_timer += delta
		var rem: float = maxf(0.0, DEMO_HOLD_DURATION - _demo_timer)
		if _status_label != null:
			_status_label.text = "● AUTO-DEMO RUNNING — FAMILY, HOUSE, STRIKE, GRAB (%.1f s)" % rem
		if not _geiger_played_1 and _demo_timer >= 0.25:
			_geiger_played_1 = true
			SoundManager.play_sfx("geiger")
		if not _geiger_played_2 and _demo_timer >= 1.30:
			_geiger_played_2 = true
			SoundManager.play_sfx("geiger")
		if not _click_played and _demo_timer >= 2.15:
			_click_played = true
			SoundManager.play_sfx("button_click")
			if _btn_full_setup != null:
				_btn_full_setup.modulate = Color(1.15, 1.15, 1.15, 1.0)
		if _demo_timer >= DEMO_HOLD_DURATION:
			_transitioning = true
			GameState.reset_to_defaults()
			GameState.request_screen(GameState.SCREEN_FAMILY)
			return

	queue_redraw()

func _on_new_protocol_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = false
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_FAMILY)

func _on_quick_scavenge_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("siren")
	GameState.demo_mode = false
	GameState.init_default_family()
	GameState.init_default_house()
	GameState.init_default_nuke()
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_SCAVENGE)

func _on_watch_demo_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = true
	GameState.init_default_family()
	GameState.init_default_house()
	GameState.init_default_nuke()
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_FAMILY)

func _draw() -> void:
	var vp: Vector2 = size
	if vp.x < 100.0 or vp.y < 100.0:
		vp = Vector2(1280.0, 720.0)

	var font: Font = ThemeDB.fallback_font

	# 1. Night backdrop with a faint glow behind the alert badge
	draw_rect(Rect2(Vector2.ZERO, vp), ThemeHelper.COLOR_BG, true)
	draw_circle(Vector2(vp.x * 0.5, 250.0), 540.0, Color(0.10, 0.12, 0.15, 0.60))
	draw_circle(Vector2(vp.x * 0.5, 165.0), 340.0, Color(0.16, 0.13, 0.08, 0.35))

	# 2. Map grid with expanding alert-area rings
	_draw_world_grid_and_radar(vp, font)

	# 3. Top & bottom hazard-tape borders
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, 0.0, vp.x, 22.0), 18.0)
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, vp.y - 22.0, vp.x, 22.0), 18.0)
	draw_line(Vector2(0.0, 23.0), Vector2(vp.x, 23.0), ThemeHelper.COLOR_BORDER, 1.0)
	draw_line(Vector2(0.0, vp.y - 23.0), Vector2(vp.x, vp.y - 23.0), ThemeHelper.COLOR_BORDER, 1.0)

	# 4. Emergency-alert notification banner
	_draw_broadcast_banner(vp, font)

	# 5. Radiation alert badge, flanked by the phone's signal and the alert tone
	var emblem_center := Vector2(vp.x * 0.5, 144.0)
	_draw_frequency_scopes(emblem_center, font)
	_draw_radiation_emblem(emblem_center, 64.0, font)

	# 6. Title & subtitle
	_draw_hero_typography(vp, font)

	# 7. Floating supplies: canned food, gas mask, crank radio...
	_draw_floating_supplies(vp, font)

	# 8. Demo progress bar (auto-demo only)
	if _demo_started_on_ready:
		var prog: float = clampf(_demo_timer / DEMO_HOLD_DURATION, 0.0, 1.0)
		var bar_rect := Rect2(210.0, 688.0, 860.0 * prog, 4.0)
		draw_rect(Rect2(210.0, 688.0, 860.0, 4.0), ThemeHelper.COLOR_PANEL_RAISED, true)
		draw_rect(bar_rect, ThemeHelper.COLOR_ALERT_AMBER, true)

func _draw_world_grid_and_radar(vp: Vector2, font: Font) -> void:
	var grid_col := Color(0.60, 0.64, 0.68, 0.07)
	var eq_col := Color(1.0, 0.69, 0.13, 0.12)

	# Latitude lines (gentle arcs)
	for lat_i in range(-3, 4):
		var y_base: float = vp.y * 0.50 + float(lat_i) * 76.0
		var pts := PackedVector2Array()
		var steps: int = 32
		for s in range(steps + 1):
			var u: float = float(s) / float(steps)
			var x: float = u * vp.x
			var curve_y: float = y_base + sin(u * PI) * float(lat_i) * 10.0
			pts.append(Vector2(x, curve_y))
		var c: Color = eq_col if lat_i == 0 else grid_col
		draw_polyline(pts, c, 1.2 if lat_i == 0 else 1.0, true)

	# Longitude lines
	for lon_i in range(-5, 6):
		var pts_m := PackedVector2Array()
		var steps_m: int = 24
		for s in range(steps_m + 1):
			var v: float = float(s) / float(steps_m)
			var y: float = 24.0 + v * (vp.y - 48.0)
			var bulge: float = sin(v * PI)
			var x: float = vp.x * 0.5 + float(lon_i) * (112.0 * (0.55 + 0.45 * bulge))
			pts_m.append(Vector2(x, y))
		draw_polyline(pts_m, grid_col, 1.0, true)

	# Alert-area rings spreading out from behind the title, like a broadcast going out
	var radar_origin := Vector2(vp.x * 0.5, 290.0)
	for ring_r in [160.0, 280.0, 410.0, 540.0]:
		draw_arc(radar_origin, ring_r, 0.0, TAU, 72, Color(0.60, 0.64, 0.68, 0.06), 1.0, true)
	for wave in range(3):
		var w_t: float = fmod(_anim_time * 0.22 + float(wave) / 3.0, 1.0)
		draw_arc(radar_origin, 60.0 + w_t * 520.0, 0.0, TAU, 96, Color(1.0, 0.69, 0.13, (1.0 - w_t) * 0.16), 2.0, true)

	# Pulsing alert markers over a few cities
	for blip in RADAR_BLIPS:
		var uv: Vector2 = blip.get("uv", Vector2(0.5, 0.5))
		var b_pos := Vector2(uv.x * vp.x, uv.y * vp.y)
		var ph: float = float(blip.get("phase", 0.0))
		var pulse: float = fmod(_anim_time * 0.7 + ph, 1.0)
		draw_arc(b_pos, 6.0 + pulse * 26.0, 0.0, TAU, 24, Color(1.0, 0.30, 0.31, (1.0 - pulse) * 0.38), 1.4, true)
		draw_circle(b_pos, 3.2, Color(1.0, 0.69, 0.13, 0.70))
		var b_name: String = str(blip.get("name", ""))
		draw_string(font, b_pos + Vector2(7.0, 4.0), b_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.91, 0.92, 0.93, 0.38))

func _draw_broadcast_banner(vp: Vector2, font: Font) -> void:
	# A phone-style alert notification across the top
	var bar_rect := Rect2(vp.x * 0.5 - 350.0, 30.0, 700.0, 26.0)
	_draw_round_rect(bar_rect, 8.0, Color(0.10, 0.12, 0.14, 0.96))
	draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y + 6.0, 3.0, bar_rect.size.y - 12.0), ThemeHelper.COLOR_ALERT_RED, true)

	# Blinking alert dot
	var blink_on: bool = sin(_anim_time * 5.5) > -0.2
	var lamp_col: Color = ThemeHelper.COLOR_ALERT_RED if blink_on else Color("#5a1d1e")
	draw_circle(Vector2(bar_rect.position.x + 18.0, bar_rect.position.y + 13.0), 5.0, lamp_col)

	var txt := "EMERGENCY ALERT   •   SEEK SHELTER NOW   •   NOT A DRILL"
	var t_sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(
		font,
		Vector2(vp.x * 0.5 - t_sz.x * 0.5 + 8.0, bar_rect.position.y + 17.5),
		txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		ThemeHelper.COLOR_TEXT
	)

func _draw_frequency_scopes(center: Vector2, font: Font) -> void:
	for side in [-1, 1]:
		var sx: float = center.x + float(side) * 195.0
		var box := Rect2(sx - 78.0, center.y - 26.0, 156.0, 52.0)
		_draw_round_rect(box, 10.0, Color(0.10, 0.12, 0.14, 0.92))
		_draw_round_rect_outline(box, 10.0, ThemeHelper.COLOR_BORDER, 1.0)

		var tag: String = ""
		if side < 0:
			# The phone: empty signal bars and a slash. Alerts still get through.
			var base := Vector2(box.position.x + 40.0, center.y + 14.0)
			for b in range(4):
				var bh: float = 6.0 + float(b) * 6.0
				var bar_r := Rect2(base + Vector2(float(b) * 12.0, -bh), Vector2(8.0, bh))
				draw_rect(bar_r, Color(0.60, 0.64, 0.68, 0.22), true)
			var blink: float = 0.55 + 0.45 * sin(_anim_time * 3.0)
			draw_line(base + Vector2(-4.0, 2.0), base + Vector2(50.0, -28.0), Color(1.0, 0.30, 0.31, blink), 2.4, true)
			tag = "NO SERVICE"
		else:
			# The alert tone: two sine waves, 853 Hz and 960 Hz, beating against each other
			draw_line(Vector2(box.position.x, center.y), Vector2(box.end.x, center.y), Color(0.60, 0.64, 0.68, 0.18), 1.0)
			var wave_pts := PackedVector2Array()
			for idx in range(41):
				var u: float = float(idx) / 40.0
				var wx: float = box.position.x + 6.0 + u * (box.size.x - 12.0)
				var env: float = sin(u * PI)
				var ph: float = u * TAU * 4.0 - _anim_time * 6.5
				var wy: float = center.y + (sin(ph) + sin(ph * 1.125)) * 7.0 * env
				wave_pts.append(Vector2(wx, wy))
			draw_polyline(wave_pts, ThemeHelper.COLOR_ALERT_AMBER, 1.8, true)
			tag = "ALERT TONE 853 / 960 Hz"
		var tag_sz: Vector2 = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, Vector2(sx - tag_sz.x * 0.5, box.end.y + 13.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ThemeHelper.COLOR_TEXT_MUTED)

func _draw_radiation_emblem(center: Vector2, radius: float, _font: Font) -> void:
	# Soft pulsing glow
	var halo_pulse: float = 0.5 + 0.5 * sin(_anim_time * 3.0)
	draw_circle(center, radius + 10.0 + halo_pulse * 4.0, Color(1.0, 0.69, 0.13, 0.10 + halo_pulse * 0.08))

	# Flat amber badge with a thin dark ring (an app-icon style warning sign)
	draw_circle(center, radius + 3.0, ThemeHelper.COLOR_BG)
	draw_circle(center, radius, ThemeHelper.COLOR_ALERT_AMBER)
	draw_arc(center, radius - 6.0, 0.0, TAU, 64, Color(0.06, 0.07, 0.08, 0.35), 1.5, true)

	# Slowly turning radiation trefoil
	var rot: float = _anim_time * 0.35
	var r_in: float = radius * 0.24
	var r_out: float = radius * 0.76
	for blade in range(3):
		var base_a: float = rot + float(blade) * (TAU / 3.0) - PI * 0.5
		var a_start: float = base_a - PI / 6.0
		var a_end: float = base_a + PI / 6.0
		var blade_poly := PackedVector2Array()
		var arc_steps: int = 12
		for s in range(arc_steps + 1):
			var a: float = lerpf(a_start, a_end, float(s) / float(arc_steps))
			blade_poly.append(center + Vector2(cos(a), sin(a)) * r_out)
		for s in range(arc_steps, -1, -1):
			var a: float = lerpf(a_start, a_end, float(s) / float(arc_steps))
			blade_poly.append(center + Vector2(cos(a), sin(a)) * r_in)
		draw_colored_polygon(blade_poly, ThemeHelper.COLOR_BG)

	# Centre hub
	draw_circle(center, radius * 0.17, ThemeHelper.COLOR_ALERT_AMBER)
	draw_circle(center, radius * 0.12, ThemeHelper.COLOR_BG)

func _draw_hero_typography(vp: Vector2, font: Font) -> void:
	var title_str := "THE END IS NEAR"
	var title_size: int = 58
	var t_dim: Vector2 = font.get_string_size(title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size)
	var tx: float = vp.x * 0.5 - t_dim.x * 0.5
	var ty: float = 266.0

	# Plate behind the title
	var plate := Rect2(vp.x * 0.5 - t_dim.x * 0.5 - 26.0, 224.0, t_dim.x + 52.0, 56.0)
	_draw_round_rect(plate, 12.0, Color(0.10, 0.12, 0.14, 0.90))
	_draw_round_rect_outline(plate, 12.0, ThemeHelper.COLOR_BORDER, 1.0)

	# Clean white title with a soft drop shadow
	draw_string(font, Vector2(tx + 2.0, ty + 2.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, Vector2(tx, ty), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ThemeHelper.COLOR_TEXT)

	# Subtitle
	var sub_str := "PICK YOUR REAL HOUSE ON OPENSTREETMAP  •  NAME YOUR FAMILY  •  SIT OUT THE FALLOUT"
	var sub_size: int = 14
	var s_dim: Vector2 = font.get_string_size(sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size)
	var sx: float = vp.x * 0.5 - s_dim.x * 0.5
	var sy: float = 308.0
	draw_string(font, Vector2(sx, sy), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, ThemeHelper.COLOR_TEXT_MUTED)

	# Divider under the subtitle
	draw_line(Vector2(vp.x * 0.5 - 290.0, 320.0), Vector2(vp.x * 0.5 + 290.0, 320.0), Color(1.0, 0.69, 0.13, 0.40), 1.2)

func _draw_floating_supplies(vp: Vector2, font: Font) -> void:
	for entry in FLOATING_SUPPLIES:
		var item_id: String = str(entry.get("id", "food"))
		var label_txt: String = str(entry.get("label", ""))
		var side: int = int(entry.get("side", -1))
		var row: int = int(entry.get("row", 0))
		var ph: float = float(entry.get("phase", 0.0))

		var base_x: float = 128.0 if side < 0 else (vp.x - 128.0)
		var base_y: float = 195.0 + float(row) * 175.0
		var bob_y: float = sin(_anim_time * 1.9 + ph) * 7.5
		var bob_x: float = cos(_anim_time * 1.2 + ph) * 3.5
		var c_pos := Vector2(base_x + bob_x, base_y + bob_y)

		# Round app-icon tile
		draw_circle(c_pos, 42.0, Color(0.10, 0.12, 0.14, 0.90))
		draw_arc(c_pos, 42.0, 0.0, TAU, 36, ThemeHelper.COLOR_BORDER, 1.4, true)
		draw_arc(c_pos, 42.0, -PI * 0.5, -PI * 0.5 + TAU * fmod(_anim_time * 0.15 + ph * 0.2, 1.0), 36, Color(1.0, 0.69, 0.13, 0.55), 1.8, true)

		ItemDB.draw_item_icon(self, item_id, c_pos, 46.0, false)

		# Caption chip
		var tag_dim: Vector2 = font.get_string_size(label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var tag_rect := Rect2(c_pos.x - tag_dim.x * 0.5 - 8.0, c_pos.y + 47.0, tag_dim.x + 16.0, 18.0)
		_draw_round_rect(tag_rect, 9.0, ThemeHelper.COLOR_PANEL_RAISED)
		draw_string(
			font,
			Vector2(c_pos.x - tag_dim.x * 0.5, c_pos.y + 60.0),
			label_txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			ThemeHelper.COLOR_TEXT
		)

func _draw_round_rect(r: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)

func _draw_round_rect_outline(r: Rect2, radius: float, col: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(maxf(1.0, width)))
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)

class _CrtOverlay extends Control:
	# Kept under its old name: now only a soft edge vignette (no scanlines).
	var scan_time: float = 0.0

	func _draw() -> void:
		var vp: Vector2 = size
		if vp.x <= 10.0 or vp.y <= 10.0:
			return
		for i in range(6):
			var inset: float = float(i) * 6.0
			draw_rect(Rect2(inset, inset, vp.x - inset * 2.0, vp.y - inset * 2.0), Color(0.0, 0.0, 0.0, 0.07 - float(i) * 0.01), false, 6.0)
