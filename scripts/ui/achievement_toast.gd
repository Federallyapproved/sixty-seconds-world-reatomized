class_name AchievementToast
extends CanvasLayer

## The unlock toast (section 14): slides in at the top right when GameState.achievement_unlocked
## fires, one at a time, for a few seconds each. Never takes input.

const SHOW_SECONDS: float = 3.2

var _queue: Array = []
var _panel: PanelContainer = null
var _title: Label = null
var _desc: Label = null
var _t: float = -1.0


func _ready() -> void:
	layer = 50
	_panel = ThemeHelper.make_card_panel(Color(0.10, 0.12, 0.14, 0.97), ThemeHelper.COLOR_ALERT_AMBER)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(1280.0 - 380.0, -90.0)
	_panel.size = Vector2(360.0, 64.0)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vb)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", ThemeHelper.COLOR_ALERT_AMBER)
	vb.add_child(_title)
	_desc = Label.new()
	_desc.add_theme_font_size_override("font_size", 12)
	_desc.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT_MUTED)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_desc)
	_panel.visible = false
	GameState.achievement_unlocked.connect(_on_unlocked)


func _on_unlocked(aid: String) -> void:
	_queue.append(aid)
	if _t < 0.0:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_t = -1.0
		_panel.visible = false
		return
	var aid: String = str(_queue.pop_front())
	var row: Dictionary = ShelterData.achievements().get(aid, {})
	_title.text = "Achievement: %s" % str(row.get("name", aid))
	_desc.text = str(row.get("description", ""))
	_panel.visible = true
	_t = 0.0
	SoundManager.play_sfx("pickup")


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var slide: float = clampf(_t / 0.25, 0.0, 1.0) * clampf((SHOW_SECONDS - _t) / 0.25, 0.0, 1.0)
	_panel.position.y = lerpf(-90.0, 16.0, slide)
	if _t >= SHOW_SECONDS:
		_next()
