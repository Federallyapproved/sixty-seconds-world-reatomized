class_name GarageView
extends Control

## The garage above the shelter: the family car with its visible condition, the salvaged
## parts in storage, and buttons to install each part BY HAND (plays a cinematic and costs
## the worker radiation dose). Shows where missing parts could come from in the real
## neighbourhood, so the player can see which escape routes this location allows.
## Hidden while GameState.FEATURE_CAR_ESCAPE is false: show_view() does nothing.

signal install_requested(part: String)
signal drive_requested()
signal closed()

var _info_lbl: Label
var _btn_box: VBoxContainer
var _anim_t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var close := Button.new()
	close.text = "BACK TO SHELTER  [ESC]"
	close.position = Vector2(1040, 12)
	close.size = Vector2(220, 34)
	close.focus_mode = Control.FOCUS_NONE
	_style(close, Color("#262c34"), Color("#ffb020"))
	close.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		hide_view()
	)
	add_child(close)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1a1e24")
	sb.border_color = Color("#39414b")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(20, 470)
	panel.size = Vector2(1240, 236)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	panel.add_child(hb)
	_info_lbl = Label.new()
	_info_lbl.custom_minimum_size = Vector2(640, 210)
	_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_lbl.add_theme_font_size_override("font_size", 13)
	_info_lbl.add_theme_color_override("font_color", Color("#e8eaed"))
	hb.add_child(_info_lbl)
	_btn_box = VBoxContainer.new()
	_btn_box.add_theme_constant_override("separation", 5)
	_btn_box.custom_minimum_size = Vector2(560, 0)
	hb.add_child(_btn_box)


func _style(b: Button, bg: Color, fg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color("#39414b")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = bg.lightened(0.12)
	var sbd: StyleBoxFlat = sb.duplicate()
	sbd.bg_color = Color("#1a1e24")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("#9aa3ad"))
	b.add_theme_font_size_override("font_size", 13)


func show_view() -> void:
	if not GameState.FEATURE_CAR_ESCAPE:
		visible = false
		return
	visible = true
	refresh()


func hide_view() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		hide_view()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	for c in _btn_box.get_children():
		c.queue_free()
	var v: Dictionary = GameState.vehicle
	var lines: Array[String] = []
	lines.append("FAMILY CAR — " + ("WRECKED" if bool(v.get("wrecked", false)) else ("READY TO DRIVE" if VehicleSystem.is_ready() else "NOT RUNNING")))
	for ln in VehicleSystem.status_lines():
		lines.append("• " + ln)
	lines.append("")
	lines.append("In storage: battery ×%d, spark plugs ×%d, fan belt ×%d, tire kit ×%d, fuel %.0f L in cans." % [
		int(GameState.parts.get("car_battery", 0)), int(GameState.parts.get("spark_plugs", 0)), int(GameState.parts.get("fan_belt", 0)),
		int(GameState.parts.get("tire_patch", 0)), float(GameState.parts.get("fuel_l", 0.0))])
	var missing: Array = VehicleSystem.missing_parts()
	if not missing.is_empty():
		var src_bits: Array[String] = []
		for part in missing:
			if VehicleSystem.part_in_storage(str(part)):
				continue
			var srcs: Array = VehicleSystem.part_sources(str(part))
			var nm: String = str(ItemDB.get_item_info(str(part)).get("short_name", part))
			if srcs.is_empty():
				src_bits.append("%s: none left anywhere mapped nearby" % nm)
			else:
				var names: Array[String] = []
				for s in srcs.slice(0, 2):
					var sd: Dictionary = s
					var kl: String = str(sd.get("kind_label", ""))
					names.append(("%s (%s)" % [str(sd["name"]), kl]) if kl != "" and kl != str(sd["name"]) else str(sd["name"]))
				src_bits.append("%s: %s" % [nm, ", ".join(names)])
		if not src_bits.is_empty():
			lines.append("Where to find missing parts (real places): " + "; ".join(src_bits) + ".")
		if not VehicleSystem.route_available():
			lines.append("No route: at least one part cannot be found in this neighbourhood.")
	_info_lbl.text = "\n".join(lines)
	if bool(v.get("wrecked", false)):
		return
	for part2 in ["car_battery", "spark_plugs", "fan_belt", "tire_patch", "fuel_can"]:
		if not missing.has(part2):
			continue
		var chk: Dictionary = VehicleSystem.can_install(part2)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(540, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var nm2: String = str(ItemDB.get_item_info(part2).get("name", part2))
		if bool(chk.get("ok", false)):
			b.text = "INSTALL %s — %s does it by hand" % [nm2.to_upper(), str((chk["worker"] as Dictionary).get("name", ""))]
			_style(b, Color("#262c34"), Color("#e8eaed"))
		else:
			b.text = "%s — %s" % [nm2, str(chk.get("why", ""))]
			b.disabled = true
			_style(b, Color("#262c34"), Color("#e8eaed"))
		var cap: String = part2
		b.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			install_requested.emit(cap)
		)
		_btn_box.add_child(b)
	var drive := Button.new()
	drive.focus_mode = Control.FOCUS_NONE
	drive.custom_minimum_size = Vector2(540, 36)
	var plan: Dictionary = VehicleSystem.escape_plan()
	drive.text = "DRIVE OUT %s (everyone aboard)" % str(plan["dir_word"]).to_upper() if VehicleSystem.is_ready() else "DRIVE OUT — car not ready (%d part(s) missing)" % missing.size()
	drive.disabled = not VehicleSystem.is_ready()
	_style(drive, Color("#ff4d4f"), Color("#ffffff"))
	drive.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		drive_requested.emit()
	)
	_btn_box.add_child(drive)


func _process(delta: float) -> void:
	if visible and not GameState.FEATURE_CAR_ESCAPE:
		visible = false
	if visible:
		_anim_t += delta
		queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1e24"))
	for x in range(0, 1280, 120):
		draw_rect(Rect2(x, 0, 116, 460), Color("#20252c"))
	draw_rect(Rect2(0, 440, 1280, 280), Color("#0f1115"))
	draw_string(font, Vector2(24, 34), "GARAGE  •  above the shelter (outside the protection factor)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffb020"))
	var rate: float = GameState.surface_radiation_sv * 1000.0 / VehicleSystem.GARAGE_PF
	draw_string(font, Vector2(24, 58), "Dose rate in here now: %s (garage walls only halve it)" % RadiationModel.format_rate(rate), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e8eaed"))
	# parts rack
	draw_rect(Rect2(40, 110, 260, 300), Color("#14171c"))
	for sy in [190.0, 290.0, 390.0]:
		draw_rect(Rect2(40, sy, 260, 8), Color("#39414b"))
	draw_string(font, Vector2(52, 130), "SALVAGED PARTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffb020"))
	var slots: Array = [["car_battery", Vector2(80, 168)], ["spark_plugs", Vector2(150, 168)], ["fan_belt", Vector2(220, 168)], ["tire_patch", Vector2(80, 268)]]
	for sl in slots:
		var part: String = sl[0]
		var n: int = int(GameState.parts.get(part, 0))
		var p: Vector2 = sl[1]
		ItemDB.draw_item_icon(self, part, p, 40.0, false)
		if n <= 0:
			draw_rect(Rect2(p - Vector2(22, 22), Vector2(44, 44)), Color(0.1, 0.1, 0.1, 0.6))
		draw_string(font, p + Vector2(-20, 34), "×%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e8eaed"))
	var cans: int = int(float(GameState.parts.get("fuel_l", 0.0)) / 10.0)
	for c in range(mini(4, cans)):
		ItemDB.draw_item_icon(self, "fuel_can", Vector2(160.0 + float(c) * 34.0, 268), 34.0, false)
	draw_string(font, Vector2(150, 302), "fuel cans: %.0f L" % float(GameState.parts.get("fuel_l", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e8eaed"))
	ShelterCinematic.draw_car(self, Vector2(420, 430), 1.0, GameState.vehicle, _anim_t)
