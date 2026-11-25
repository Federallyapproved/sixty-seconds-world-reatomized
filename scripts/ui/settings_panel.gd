class_name SettingsPanel
extends PanelContainer

## Settings: mouse sensitivity, invert-Y and field of view for the first-person grab, and the
## classic top-down grab for machines that can't run the 3D house smoothly. Saved on Close.

signal closed

var _sens: HSlider
var _sens_val: Label
var _fov: HSlider
var _fov_val: Label
var _invert: CheckBox
var _topdown: CheckBox


func _ready() -> void:
	name = "SettingsPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.14, 0.98)
	sb.border_color = ThemeHelper.COLOR_ALERT_AMBER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(520.0, 0.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", ThemeHelper.COLOR_ALERT_AMBER)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "The house grab is first person: WASD to move, the mouse to look, E or a click to grab."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT_MUTED)
	v.add_child(sub)

	var r1: Array = _slider_row(v, "Mouse sensitivity", GameSettings.SENS_MIN, GameSettings.SENS_MAX, 0.01, GameSettings.mouse_sensitivity(), "SensSlider")
	_sens = r1[0]
	_sens_val = r1[1]
	_sens.value_changed.connect(func(x: float) -> void:
		GameSettings.set_value("mouse_sensitivity", x)
		_sens_val.text = "%.2f" % x)
	var r2: Array = _slider_row(v, "Field of view", GameSettings.FOV_MIN, GameSettings.FOV_MAX, 1.0, GameSettings.fov(), "FovSlider")
	_fov = r2[0]
	_fov_val = r2[1]
	_fov.value_changed.connect(func(x: float) -> void:
		GameSettings.set_value("fov", x)
		_fov_val.text = "%d°" % int(x))
	_sens_val.text = "%.2f" % GameSettings.mouse_sensitivity()
	_fov_val.text = "%d°" % int(GameSettings.fov())

	_invert = CheckBox.new()
	_invert.name = "InvertY"
	_invert.text = "Invert mouse Y"
	_invert.button_pressed = GameSettings.invert_y()
	_invert.toggled.connect(func(on: bool) -> void: GameSettings.set_value("invert_y", on))
	v.add_child(_invert)
	_topdown = CheckBox.new()
	_topdown.name = "TopDownGrab"
	_topdown.text = "Classic top-down house grab (for slower computers)"
	_topdown.button_pressed = GameSettings.top_down_grab()
	_topdown.toggled.connect(func(on: bool) -> void: GameSettings.set_value("top_down_grab", on))
	v.add_child(_topdown)

	var close := Button.new()
	close.name = "CloseSettings"
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(160.0, 40.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(_close)
	v.add_child(close)


func _slider_row(parent: Control, label: String, lo: float, hi: float, step: float, value: float, node_name: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170.0, 0.0)
	row.add_child(l)
	var s := HSlider.new()
	s.name = node_name
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(230.0, 24.0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(val)
	return [s, val]


func _close() -> void:
	GameSettings.save()
	SoundManager.play_sfx("button_click")
	closed.emit()
	queue_free()
