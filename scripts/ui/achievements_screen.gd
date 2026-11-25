class_name AchievementsScreen
extends Control

## Achievements (section 14): every achievement with what it asks for; locked ones are greyed.

var _transitioning: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = ThemeHelper.get_game_theme()
	var bg := ColorRect.new()
	bg.color = ThemeHelper.COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var rows: Array = Achievements.rows()
	var got: Dictionary = GameState.achievements_unlocked
	var n_got: int = 0
	for r_v in rows:
		if got.has(str((r_v as Dictionary)["id"])):
			n_got += 1

	var hdr := Label.new()
	hdr.name = "Header"
	hdr.text = "ACHIEVEMENTS   %d / %d" % [n_got, rows.size()]
	hdr.position = Vector2(48.0, 28.0)
	hdr.add_theme_font_size_override("font_size", 24)
	hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_ALERT_AMBER)
	add_child(hdr)

	var note := Label.new()
	note.text = "Each one asks for a decision, not luck. Unlocks never make the family stronger."
	note.position = Vector2(48.0, 64.0)
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT_MUTED)
	add_child(note)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(48.0, 96.0)
	scroll.size = Vector2(1184.0, 536.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "List"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for r_v in rows:
		var r: Dictionary = r_v
		var unlocked: bool = got.has(str(r["id"]))
		var card := ThemeHelper.make_card_panel(ThemeHelper.COLOR_PANEL_RAISED if unlocked else ThemeHelper.COLOR_PANEL,
			ThemeHelper.COLOR_ALERT_AMBER if unlocked else ThemeHelper.COLOR_BORDER)
		card.custom_minimum_size = Vector2(384.0, 64.0)
		card.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.55)
		var vb := VBoxContainer.new()
		card.add_child(vb)
		var name_lbl := Label.new()
		name_lbl.text = str(r.get("name", "")) + ("   UNLOCKED" if unlocked else "")
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_ALERT_AMBER if unlocked else ThemeHelper.COLOR_TEXT)
		vb.add_child(name_lbl)
		var desc := Label.new()
		desc.text = str(r.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT_MUTED)
		vb.add_child(desc)
		grid.add_child(card)

	var back := ThemeHelper.make_hazard_button("BACK", Vector2(220.0, 44.0))
	back.position = Vector2(48.0, 644.0)
	back.pressed.connect(_on_back)
	add_child(back)


func _on_back() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.request_screen(GameState.SCREEN_TITLE)
