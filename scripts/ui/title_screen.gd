class_name TitleScreen
extends Control

## Animated 1950s CONELRAD Civil Defense Broadcast Title Screen (1280x720).
## Features rotating radiation trefoil emblem, world latitude/radar sweep,
## hazard stripe borders, floating ItemDB supply silhouettes, CRT scanline
## shimmer, and automatic 2.4s AI Showcase Demo handoff.

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
	{"id": "soup", "label": "RATION SOUP", "side": -1, "row": 0, "phase": 0.0},
	{"id": "gas_mask", "label": "M9 GAS MASK", "side": -1, "row": 1, "phase": 1.6},
	{"id": "radio", "label": "CONELRAD RX", "side": -1, "row": 2, "phase": 3.1},
	{"id": "water", "label": "H2O RESERVE", "side": 1, "row": 0, "phase": 0.8},
	{"id": "medkit", "label": "CIVIL MEDKIT", "side": 1, "row": 1, "phase": 2.4},
	{"id": "suitcase", "label": "EVAC CASE", "side": 1, "row": 2, "phase": 4.0}
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
		{"text": "LIVE OPENSTREETMAP HOUSES & POIs", "dot": Color("#7ec850")},
		{"text": "GLOBAL NUKE IMPACT PHYSICS", "dot": Color("#e05a2b")},
		{"text": "CUSTOM FAMILY CREATOR", "dot": Color("#f5be2e")},
		{"text": "AUTHENTIC 60s SURVIVAL", "dot": Color("#3b8ec2")}
	]
	for spec in pill_specs:
		var p_text: String = str(spec.get("text", ""))
		var p_dot: Color = spec.get("dot", ThemeHelper.COLOR_HAZARD_YELLOW)
		pills_holder.add_child(_make_feature_pill(p_text, p_dot))

	# Central Command Console Card (y = 418..638)
	var console_panel := ThemeHelper.make_card_panel(Color(0.13, 0.15, 0.13, 0.94), ThemeHelper.COLOR_HAZARD_GOLD)
	console_panel.name = "CommandConsole"
	console_panel.position = Vector2(356.0, 418.0)
	console_panel.size = Vector2(568.0, 218.0)
	add_child(console_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	console_panel.add_child(vbox)

	var console_hdr := Label.new()
	console_hdr.text = "— SELECT CIVIL DEFENSE DIRECTIVE —"
	console_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	console_hdr.add_theme_font_size_override("font_size", 13)
	console_hdr.add_theme_color_override("font_color", Color("#dccba6"))
	vbox.add_child(console_hdr)

	_btn_full_setup = ThemeHelper.make_hazard_button("[ NEW ATOMIC PROTOCOL (FULL SETUP) ]", Vector2(520.0, 50.0))
	_btn_full_setup.pressed.connect(_on_new_protocol_pressed)
	vbox.add_child(_btn_full_setup)

	_btn_quick_scavenge = ThemeHelper.make_alert_button("[ QUICK 60s SCAVENGE (DEFAULT HOUSE) ]", Vector2(520.0, 46.0))
	_btn_quick_scavenge.pressed.connect(_on_quick_scavenge_pressed)
	vbox.add_child(_btn_quick_scavenge)

	_btn_demo = Button.new()
	_btn_demo.text = "[ WATCH AI SHOWCASE DEMO ]"
	_btn_demo.custom_minimum_size = Vector2(520.0, 44.0)
	_btn_demo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_demo.pressed.connect(_on_watch_demo_pressed)
	vbox.add_child(_btn_demo)

	# Bottom Telemetry Strip (y = 650..688)
	var footer_panel := ThemeHelper.make_card_panel(Color(0.10, 0.12, 0.10, 0.92), Color("#5c6454"))
	footer_panel.position = Vector2(210.0, 650.0)
	footer_panel.size = Vector2(860.0, 38.0)
	var footer_sb := StyleBoxFlat.new()
	footer_sb.bg_color = Color(0.10, 0.12, 0.10, 0.92)
	footer_sb.border_color = Color("#6e735f")
	footer_sb.set_border_width_all(1)
	footer_sb.set_corner_radius_all(3)
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
		_status_label.text = "● AUTO-DEMO SHOWCASE ACTIVE — INITIALIZING ATOMIC PROTOCOL IN 2.4s..."
		_status_label.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	else:
		var house_addr: String = LocationText.area_header()
		_status_label.text = "ACTIVE SECTOR: %s   •   CONELRAD FREQ: 640 / 1240 KC" % house_addr.to_upper()
		_status_label.add_theme_color_override("font_color", Color("#dccba6"))
	footer_panel.add_child(_status_label)

	# Non-interactive CRT Scanline & Vignette Shimmer Overlay on top
	_crt_overlay = _CrtOverlay.new()
	_crt_overlay.name = "CrtScanlineOverlay"
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_crt_overlay)

func _make_feature_pill(label_str: String, dot_color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(306.0, 32.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.12, 0.92)
	sb.border_color = Color("#b8912d")
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_corner_radius_all(3)
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
	lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
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
			_status_label.text = "● AI SHOWCASE BROADCAST ENGAGED — LAUNCHING FAMILY & OSM PROTOCOL (%.1fs)" % rem
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
				_btn_full_setup.modulate = Color(1.18, 1.15, 0.95, 1.0)
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

	# 1. Deep Bunker Olive / CONELRAD Broadcast Backdrop
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#171a17"), true)
	draw_circle(Vector2(vp.x * 0.5, 250.0), 540.0, Color(0.18, 0.21, 0.17, 0.55))
	draw_circle(Vector2(vp.x * 0.5, 165.0), 340.0, Color(0.24, 0.26, 0.19, 0.38))

	# 2. World Latitude & Longitude Grid + Radar Sweep
	_draw_world_grid_and_radar(vp, font)

	# 3. Top & Bottom CONELRAD Hazard Stripe Borders
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, 0.0, vp.x, 22.0), 18.0)
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, vp.y - 22.0, vp.x, 22.0), 18.0)
	draw_line(Vector2(0.0, 23.0), Vector2(vp.x, 23.0), ThemeHelper.COLOR_HAZARD_GOLD, 2.0)
	draw_line(Vector2(0.0, vp.y - 23.0), Vector2(vp.x, vp.y - 23.0), ThemeHelper.COLOR_HAZARD_GOLD, 2.0)

	# 4. Broadcast Top Ticker Banner
	_draw_broadcast_banner(vp, font)

	# 5. Rotating Radiation Trefoil Emblem & Flanking Frequency Oscilloscopes
	var emblem_center := Vector2(vp.x * 0.5, 144.0)
	_draw_frequency_scopes(emblem_center, font)
	_draw_radiation_emblem(emblem_center, 64.0, font)

	# 6. Hero Poster Title & Subtitle
	_draw_hero_typography(vp, font)

	# 7. Floating Soup Can, Gas Mask & Civil Defense Supply Silhouettes
	_draw_floating_supplies(vp, font)

	# 8. Demo Progress Bar Indicator (when in auto-demo mode)
	if _demo_started_on_ready:
		var prog: float = clampf(_demo_timer / DEMO_HOLD_DURATION, 0.0, 1.0)
		var bar_rect := Rect2(210.0, 688.0, 860.0 * prog, 4.0)
		draw_rect(Rect2(210.0, 688.0, 860.0, 4.0), Color(0.1, 0.1, 0.1, 0.8), true)
		draw_rect(bar_rect, ThemeHelper.COLOR_HAZARD_YELLOW, true)

func _draw_world_grid_and_radar(vp: Vector2, font: Font) -> void:
	var grid_col := Color(0.52, 0.72, 0.42, 0.11)
	var eq_col := Color(0.95, 0.74, 0.18, 0.16)

	# World Latitude Parallels (curved subtle arcs across screen)
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

	# World Longitude Meridians
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

	# Concentric Tactical Radar Range Rings centered behind emblem/title
	var radar_origin := Vector2(vp.x * 0.5, 290.0)
	for ring_r in [160.0, 280.0, 410.0, 540.0]:
		draw_arc(radar_origin, ring_r, 0.0, TAU, 72, Color(0.95, 0.74, 0.18, 0.08), 1.0, true)

	# Rotating Radar Sweep Wedge
	var sweep_angle: float = fmod(_anim_time * 0.95, TAU)
	var wedge_slices: int = 14
	var wedge_span: float = 0.52
	for w_idx in range(wedge_slices):
		var frac0: float = float(w_idx) / float(wedge_slices)
		var frac1: float = float(w_idx + 1) / float(wedge_slices)
		var a0: float = sweep_angle - wedge_span * frac1
		var a1: float = sweep_angle - wedge_span * frac0
		var alpha: float = (1.0 - frac0) * 0.085
		var r_sweep: float = 560.0
		var tri := PackedVector2Array([
			radar_origin,
			radar_origin + Vector2(cos(a0), sin(a0)) * r_sweep,
			radar_origin + Vector2(cos(a1), sin(a1)) * r_sweep
		])
		draw_colored_polygon(tri, Color(0.55, 0.88, 0.38, alpha))

	var sweep_tip: Vector2 = radar_origin + Vector2(cos(sweep_angle), sin(sweep_angle)) * 560.0
	draw_line(radar_origin, sweep_tip, Color(0.68, 0.96, 0.45, 0.32), 1.8, true)

	# Pulsing Global Strike Target Blips
	for blip in RADAR_BLIPS:
		var uv: Vector2 = blip.get("uv", Vector2(0.5, 0.5))
		var b_pos := Vector2(uv.x * vp.x, uv.y * vp.y)
		var ph: float = float(blip.get("phase", 0.0))
		var pulse: float = fmod(_anim_time * 0.7 + ph, 1.0)
		draw_arc(b_pos, 6.0 + pulse * 26.0, 0.0, TAU, 24, Color(0.88, 0.35, 0.17, (1.0 - pulse) * 0.38), 1.4, true)
		draw_circle(b_pos, 3.2, Color(0.96, 0.75, 0.18, 0.65))
		var b_name: String = str(blip.get("name", ""))
		draw_string(font, b_pos + Vector2(7.0, 4.0), b_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.90, 0.78, 0.38))

func _draw_broadcast_banner(vp: Vector2, font: Font) -> void:
	var bar_rect := Rect2(vp.x * 0.5 - 350.0, 30.0, 700.0, 26.0)
	draw_rect(bar_rect, Color(0.11, 0.12, 0.10, 0.94), true)
	draw_rect(bar_rect, ThemeHelper.COLOR_HAZARD_GOLD, false, 1.5)

	# Blinking ON-AIR Atomic Lamp
	var blink_on: bool = sin(_anim_time * 5.5) > -0.2
	var lamp_col: Color = Color("#ff4c29") if blink_on else Color("#5e2216")
	draw_circle(Vector2(bar_rect.position.x + 18.0, bar_rect.position.y + 13.0), 5.0, lamp_col)
	draw_arc(Vector2(bar_rect.position.x + 18.0, bar_rect.position.y + 13.0), 5.0, 0.0, TAU, 16, ThemeHelper.COLOR_INK, 1.2)

	var txt := "CONELRAD EMERGENCY BROADCAST   •   640 / 1240 KC   •   CIVIL DEFENSE"
	var t_sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(
		font,
		Vector2(vp.x * 0.5 - t_sz.x * 0.5 + 8.0, bar_rect.position.y + 17.5),
		txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		ThemeHelper.COLOR_HAZARD_YELLOW
	)

func _draw_frequency_scopes(center: Vector2, font: Font) -> void:
	for side in [-1, 1]:
		var sx: float = center.x + float(side) * 195.0
		var box := Rect2(sx - 78.0, center.y - 26.0, 156.0, 52.0)
		draw_rect(box, Color(0.09, 0.12, 0.09, 0.90), true)
		draw_rect(box, Color("#626d58"), false, 1.5)

		# Scope grid lines
		draw_line(Vector2(box.position.x, center.y), Vector2(box.end.x, center.y), Color(0.4, 0.6, 0.35, 0.25), 1.0)
		var wave_pts := PackedVector2Array()
		var freq_mult: float = 2.6 if side < 0 else 4.2
		for idx in range(33):
			var u: float = float(idx) / 32.0
			var wx: float = box.position.x + 6.0 + u * (box.size.x - 12.0)
			var env: float = sin(u * PI)
			var wy: float = center.y + sin(u * TAU * freq_mult - _anim_time * 6.5 * float(side)) * 14.0 * env
			wave_pts.append(Vector2(wx, wy))
		draw_polyline(wave_pts, Color("#7ec850"), 1.8, true)

		var tag: String = "640 KC CARRIER" if side < 0 else "1240 KC ALERT"
		var tag_sz: Vector2 = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, Vector2(sx - tag_sz.x * 0.5, box.end.y + 13.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#dccba6"))

func _draw_radiation_emblem(center: Vector2, radius: float, _font: Font) -> void:
	# Outer pulsing halo
	var halo_pulse: float = 0.5 + 0.5 * sin(_anim_time * 3.0)
	draw_circle(center, radius + 10.0 + halo_pulse * 4.0, Color(0.95, 0.74, 0.18, 0.12 + halo_pulse * 0.08))

	# Outer ink & brass bezel
	draw_circle(center, radius + 4.0, ThemeHelper.COLOR_INK)
	draw_circle(center, radius, ThemeHelper.COLOR_HAZARD_GOLD)
	draw_circle(center, radius - 5.0, ThemeHelper.COLOR_INK)
	draw_circle(center, radius - 8.0, Color("#f2b82e"))

	# Dial degree ticks around bezel
	for i in range(24):
		var ang: float = float(i) * TAU / 24.0
		var r0: float = radius - 7.5
		var r1: float = radius - (3.0 if i % 2 == 0 else 5.0)
		draw_line(
			center + Vector2(cos(ang), sin(ang)) * r0,
			center + Vector2(cos(ang), sin(ang)) * r1,
			ThemeHelper.COLOR_INK,
			1.5
		)

	# Rotating 3-blade 60-degree Radiation Trefoil
	var rot: float = _anim_time * 0.75
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
		draw_colored_polygon(blade_poly, ThemeHelper.COLOR_INK)

	# Center hub
	draw_circle(center, radius * 0.19, ThemeHelper.COLOR_HAZARD_GOLD)
	draw_circle(center, radius * 0.13, ThemeHelper.COLOR_INK)
	draw_circle(center, radius * 0.05, ThemeHelper.COLOR_ATOMIC_ORANGE)

func _draw_hero_typography(vp: Vector2, font: Font) -> void:
	var title_str := "60 SECONDS: WORLD REATOMIZED"
	var title_size: int = 42
	var t_dim: Vector2 = font.get_string_size(title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size)
	var tx: float = vp.x * 0.5 - t_dim.x * 0.5
	var ty: float = 266.0

	# Backing banner plate behind hero title
	var plate := Rect2(vp.x * 0.5 - t_dim.x * 0.5 - 26.0, 224.0, t_dim.x + 52.0, 56.0)
	draw_rect(plate, Color(0.11, 0.12, 0.10, 0.88), true)
	draw_rect(plate, ThemeHelper.COLOR_ATOMIC_ORANGE, false, 2.0)

	# Multi-layered poster extrusion shadow + warm hazard-yellow face
	draw_string(font, Vector2(tx + 3.0, ty + 3.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ThemeHelper.COLOR_INK)
	draw_string(font, Vector2(tx + 1.5, ty + 1.5), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ThemeHelper.COLOR_ATOMIC_ORANGE)
	draw_string(font, Vector2(tx, ty), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ThemeHelper.COLOR_HAZARD_YELLOW)

	# Subtitle with crisp parchment lettering
	var sub_str := "PICK YOUR REAL HOUSE ON OPENSTREETMAP  •  CUSTOMIZE YOUR FAMILY  •  SURVIVE THE FALLOUT"
	var sub_size: int = 14
	var s_dim: Vector2 = font.get_string_size(sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size)
	var sx: float = vp.x * 0.5 - s_dim.x * 0.5
	var sy: float = 308.0
	draw_string(font, Vector2(sx + 1.0, sy + 1.0), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, ThemeHelper.COLOR_INK)
	draw_string(font, Vector2(sx, sy), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, ThemeHelper.COLOR_PARCHMENT)

	# Decorative divider rule under subtitle
	draw_line(Vector2(vp.x * 0.5 - 290.0, 320.0), Vector2(vp.x * 0.5 + 290.0, 320.0), Color(0.95, 0.74, 0.18, 0.45), 1.2)

func _draw_floating_supplies(vp: Vector2, font: Font) -> void:
	for entry in FLOATING_SUPPLIES:
		var item_id: String = str(entry.get("id", "soup"))
		var label_txt: String = str(entry.get("label", ""))
		var side: int = int(entry.get("side", -1))
		var row: int = int(entry.get("row", 0))
		var ph: float = float(entry.get("phase", 0.0))

		var base_x: float = 128.0 if side < 0 else (vp.x - 128.0)
		var base_y: float = 195.0 + float(row) * 175.0
		var bob_y: float = sin(_anim_time * 1.9 + ph) * 7.5
		var bob_x: float = cos(_anim_time * 1.2 + ph) * 3.5
		var c_pos := Vector2(base_x + bob_x, base_y + bob_y)

		# Civil Defense Reticle & Silhouette Pod
		draw_circle(c_pos, 42.0, Color(0.10, 0.12, 0.10, 0.85))
		draw_arc(c_pos, 42.0, 0.0, TAU, 36, Color(0.95, 0.74, 0.18, 0.52), 1.6, true)
		draw_arc(c_pos, 36.0, 0.0, TAU, 32, Color(0.88, 0.35, 0.17, 0.25), 1.0, true)

		# Reticle crosshair ticks
		for tick_dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c_pos + tick_dir * 38.0, c_pos + tick_dir * 46.0, ThemeHelper.COLOR_HAZARD_GOLD, 1.5)

		# Render crisp procedural ItemDB vector artwork
		ItemDB.draw_item_icon(self, item_id, c_pos, 46.0, false)

		# Micro caption tag below reticle
		var tag_dim: Vector2 = font.get_string_size(label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var tag_rect := Rect2(c_pos.x - tag_dim.x * 0.5 - 6.0, c_pos.y + 47.0, tag_dim.x + 12.0, 17.0)
		draw_rect(tag_rect, Color(0.11, 0.12, 0.10, 0.90), true)
		draw_rect(tag_rect, Color(0.65, 0.56, 0.34, 0.65), false, 1.0)
		draw_string(
			font,
			Vector2(c_pos.x - tag_dim.x * 0.5, c_pos.y + 59.5),
			label_txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			 Color("#dccba6")
		)

class _CrtOverlay extends Control:
	var scan_time: float = 0.0

	func _draw() -> void:
		var vp: Vector2 = size
		if vp.x <= 10.0 or vp.y <= 10.0:
			return

		# Subtle horizontal CRT scanlines
		var y: float = 0.0
		while y < vp.y:
			draw_line(Vector2(0.0, y), Vector2(vp.x, y), Color(0.0, 0.0, 0.0, 0.10), 1.0)
			y += 4.0

		# Slowly rolling phosphor shimmer bar
		var shimmer_y: float = fmod(scan_time * 95.0, vp.y + 120.0) - 60.0
		draw_rect(Rect2(0.0, shimmer_y, vp.x, 42.0), Color(0.95, 0.85, 0.55, 0.025), true)
		draw_line(Vector2(0.0, shimmer_y + 21.0), Vector2(vp.x, shimmer_y + 21.0), Color(0.96, 0.78, 0.25, 0.05), 1.5)

		# Broadcast Bezel Frame
		draw_rect(Rect2(2.0, 2.0, vp.x - 4.0, vp.y - 4.0), Color(0.08, 0.08, 0.07, 0.65), false, 4.0)
