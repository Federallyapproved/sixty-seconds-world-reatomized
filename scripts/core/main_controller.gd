extends Control

## Root scene router & transition manager for "The End Is Near".
## Connects GameState.screen_requested to instantiate each screen cleanly,
## applies ThemeHelper's global emergency-alert theme, and supports CLI hooks for
## automated Critic screenshot tours and Movie Maker demo showcase recording.

var _screen_holder: Control
var _active_node: Node = null
var _fade_rect: ColorRect
var _fade_alpha: float = 0.0

func _ready() -> void:
	theme = ThemeHelper.get_game_theme()

	_screen_holder = Control.new()
	_screen_holder.name = "ScreenHolder"
	_screen_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen_holder)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "TransitionFade"
	_fade_rect.color = Color(0.06, 0.067, 0.082, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)

	GameState.screen_requested.connect(_on_screen_requested)

	var toast := AchievementToast.new()
	toast.name = "AchievementToast"
	add_child(toast)

	var start_screen: String = GameState.SCREEN_TITLE
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--start-screen="):
			start_screen = arg.split("=")[1]

	_mount_screen(start_screen)

func _process(delta: float) -> void:
	if _fade_alpha > 0.0:
		_fade_alpha = maxf(0.0, _fade_alpha - delta * 4.5)
		_fade_rect.color.a = _fade_alpha

func _on_screen_requested(screen_name: String) -> void:
	_fade_alpha = 0.65
	_fade_rect.color.a = _fade_alpha
	_mount_screen(screen_name)

func _mount_screen(screen_name: String) -> void:
	if is_instance_valid(_active_node):
		_active_node.queue_free()
		_active_node = null

	GameState.current_screen = screen_name
	if "--log-screens" in OS.get_cmdline_user_args() or "--log-screens" in OS.get_cmdline_args():
		# Smoke tests of exported packs grep these lines (headless runs print nothing else).
		print("SCREEN %s day=%d" % [screen_name, GameState.day])

	match screen_name:
		GameState.SCREEN_TITLE:
			SoundManager.set_ambience("menu")
			var s := TitleScreen.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_FAMILY:
			SoundManager.set_ambience("menu")
			var s := FamilyScreen.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_OSM_HOUSE:
			SoundManager.set_ambience("menu")
			var s := HouseSelectScreen.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_NUKE:
			SoundManager.set_ambience("menu")
			var s := NukeScreen.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_SCAVENGE:
			SoundManager.set_ambience("scavenge")
			var s := ScavengeScene.new()
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_BUNKER:
			SoundManager.set_ambience("bunker")
			var s := BunkerScene.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_SUMMARY:
			SoundManager.set_ambience("menu")
			var s := SummaryScreen.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_ALMANAC:
			SoundManager.set_ambience("menu")
			var s := AlmanacScreen.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		GameState.SCREEN_ACHIEVEMENTS:
			SoundManager.set_ambience("menu")
			var s := AchievementsScreen.new()
			s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_screen_holder.add_child(s)
			_active_node = s
		_:
			push_warning("Unknown screen requested: " + screen_name)
