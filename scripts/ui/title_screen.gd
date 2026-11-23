class_name TitleScreen
extends Control

## Animated 1950s CONELRAD Civil Defense Broadcast Title & Command Launcher (1280x720).
## Features rotating radiation trefoil emblem, world latitude/radar sweep, outer-corner
## radar blips, Continue Saved Shelter, Difficulty Selector, Full Campaign / 3D Scavenge Drill /
## Survival Only modes, 3 Special Challenges modal, 16 Achievements & Garage Chassis Tier modal,
## and automatic 2.4s AI Showcase Demo handoff.

const DEMO_HOLD_DURATION: float = 2.4

var _anim_time: float = 0.0
var _demo_started_on_ready: bool = false
var _demo_timer: float = 0.0
var _geiger_played_1: bool = false
var _geiger_played_2: bool = false
var _click_played: bool = false
var _transitioning: bool = false

var _btn_continue: Button = null
var _diff_buttons: Dictionary = {}
var _btn_full_setup: Button = null
var _btn_scavenge_drill: Button = null
var _btn_survival_only: Button = null
var _btn_challenges: Button = null
var _btn_achievements: Button = null
var _btn_demo: Button = null
var _status_label: Label = null
var _crt_overlay: Control = null

var _challenge_modal: Control = null
var _achievements_modal: Control = null

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

const DIFFICULTY_SPECS := [
	{"id": "little_boy", "label": "Little Boy (Casual)", "accent": "#7ec850", "summary": "70s Scavenge • +2 Bonus Rations • -30% Raider Risk"},
	{"id": "fat_man", "label": "Fat Man (Reatomized)", "accent": "#f5be2e", "summary": "60s Scavenge • Authentic Civil Defense Survival"},
	{"id": "tsar_bomba", "label": "Tsar Bomba (Hardcore)", "accent": "#e05a2b", "summary": "60s Scavenge • Scarce Rations • +35% Raiders & Fallout"}
]

const CHALLENGE_SPECS := [
	{
		"id": "cul_de_sac_odyssey",
		"title": "1. SUBURBAN CUL-DE-SAC (6217 WALBOROUGH CT)",
		"badge": "REAL-WORLD SUBURBIA • VEHICLE ESCAPE FOCUS",
		"accent": "#f5be2e",
		"desc": "Deploy into the real 6217 Walborough Ct residence in Glen Allen, VA. Surrounded by quiet suburban cul-de-sacs, grocery stores, clinics, and gas stations lie kilometers away in Rings 2 & 3 — scavenge smart and rebuild the Station Wagon!"
	},
	{
		"id": "nuclear_winter_zero",
		"title": "2. NUCLEAR WINTER ZERO (-16°C)",
		"badge": "EXTREME ARCTIC FALLOUT • HYPOTHERMIA HAZARD",
		"accent": "#3b8ec2",
		"desc": "Stratospheric soot plunges shelter temperature to -16°C from Day 1 alongside heavy 9.2 Sv/hr fallout. Protect fuel, toolbox, and family warmth bonds before frostbite and sickness overwhelm the bunker!"
	},
	{
		"id": "lone_wolf_pets",
		"title": "3. LONE WOLF & PETS",
		"badge": "SOLO SURVIVOR • SHARIKOV & PANCAKE LOYALTY",
		"accent": "#7ec850",
		"desc": "Only Ted remains at home when the sirens wail — accompanied by Sharikov the Cat and Pancake the Dog! Scavenge solo against the clock and rely on your two four-legged companions to guard sanity and rations underground."
	}
]

const HAT_LABELS := {
	"none": "Standard Issue (None)",
	"cd_helmet": "Civil Defense Brodie Helmet",
	"aviator": "1950s Leather Aviator Cap",
	"medic_cap": "Field Triage Medic Cap",
	"ushanka": "Sub-Zero Winter Ushanka"
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = ThemeHelper.get_game_theme()

	if GameState.difficulty != "little_boy" and GameState.difficulty != "fat_man" and GameState.difficulty != "tsar_bomba":
		GameState.difficulty = "fat_man"

	_demo_started_on_ready = GameState.demo_mode
	_build_ui()

func _peek_saved_run_day() -> int:
	if not SaveManager.has_saved_run():
		return 1
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_RUN_PATH, FileAccess.READ)
	if f == null:
		return 1
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return maxi(1, int(d.get("day", 1)))
	return 1

func _count_unlocked_achievements() -> int:
	var count: int = 0
	for ach_id in SaveManager.ACHIEVEMENTS_DEF.keys():
		if SaveManager.is_achievement_unlocked(str(ach_id)):
			count += 1
	return count

func _build_ui() -> void:
	# Feature Callout Pills (2x2 centered grid at y = 262..320)
	var pills_holder := GridContainer.new()
	pills_holder.name = "FeaturePills"
	pills_holder.columns = 2
	pills_holder.add_theme_constant_override("h_separation", 12)
	pills_holder.add_theme_constant_override("v_separation", 6)
	pills_holder.position = Vector2(280.0, 262.0)
	pills_holder.size = Vector2(720.0, 58.0)
	add_child(pills_holder)

	var pill_specs: Array = [
		{"text": "3D ISOMETRIC SCAVENGE & REAL OSM HOUSES", "dot": Color("#7ec850")},
		{"text": "MULTI-RING 10KM LANDMARKS & NUKE PHYSICS", "dot": Color("#e05a2b")},
		{"text": "FAMILY RELATIONSHIPS, BONDS & BETRAYALS", "dot": Color("#f5be2e")},
		{"text": "MULTI-RUN STATION WAGON ESCAPE GARAGE", "dot": Color("#3b8ec2")}
	]
	for raw_spec in pill_specs:
		if raw_spec is Dictionary:
			var spec: Dictionary = raw_spec
			var p_text: String = str(spec.get("text", ""))
			var p_dot: Color = spec.get("dot", ThemeHelper.COLOR_HAZARD_YELLOW) as Color
			pills_holder.add_child(_make_feature_pill(p_text, p_dot))

	# Central Command Console Card (y = 326..644, width = 740px)
	var has_save: bool = SaveManager.has_saved_run()
	var console_panel := ThemeHelper.make_card_panel(Color(0.13, 0.15, 0.13, 0.95), ThemeHelper.COLOR_HAZARD_GOLD)
	console_panel.name = "CommandConsole"
	console_panel.position = Vector2(270.0, 326.0)
	console_panel.size = Vector2(740.0, 318.0)
	var console_sb := StyleBoxFlat.new()
	console_sb.bg_color = Color(0.13, 0.15, 0.13, 0.95)
	console_sb.border_color = ThemeHelper.COLOR_HAZARD_GOLD
	console_sb.set_border_width_all(2)
	console_sb.set_corner_radius_all(4)
	console_sb.content_margin_left = 14.0
	console_sb.content_margin_right = 14.0
	console_sb.content_margin_top = 8.0
	console_sb.content_margin_bottom = 8.0
	console_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	console_sb.shadow_size = 5
	console_sb.shadow_offset = Vector2(0, 2)
	console_panel.add_theme_stylebox_override("panel", console_sb)
	add_child(console_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5 if has_save else 7)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	console_panel.add_child(vbox)

	var console_hdr := Label.new()
	console_hdr.text = "— YIELD DIFFICULTY & CIVIL DEFENSE DIRECTIVE —"
	console_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	console_hdr.add_theme_font_size_override("font_size", 12)
	console_hdr.add_theme_color_override("font_color", Color("#dccba6"))
	vbox.add_child(console_hdr)

	# 1. Continue Saved Shelter Button (at the very top of the button stack whenever SaveManager.has_saved_run() is true)
	if has_save:
		var saved_day: int = _peek_saved_run_day()
		_btn_continue = _make_continue_button("[ CONTINUE SAVED SHELTER — DAY %d ]" % saved_day, Vector2(712.0, 36.0))
		_btn_continue.name = "ContinueSavedButton"
		_btn_continue.pressed.connect(_on_continue_saved_pressed)
		vbox.add_child(_btn_continue)

	# 2. Difficulty Selector Bar
	var diff_row := HBoxContainer.new()
	diff_row.name = "DifficultySelectorBar"
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_row)

	_diff_buttons.clear()
	for raw_d in DIFFICULTY_SPECS:
		var d_spec: Dictionary = raw_d
		var d_id: String = str(d_spec.get("id", "fat_man"))
		var d_lbl: String = str(d_spec.get("label", ""))
		var d_btn := Button.new()
		d_btn.name = "DiffBtn_" + d_id
		d_btn.text = "[ %s ]" % d_lbl
		d_btn.custom_minimum_size = Vector2(232.0, 32.0)
		d_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		d_btn.add_theme_font_size_override("font_size", 13)
		d_btn.pressed.connect(select_difficulty.bind(d_id))
		diff_row.add_child(d_btn)
		_diff_buttons[d_id] = d_btn
	_refresh_difficulty_styles()

	# 3. Primary Full Campaign Button
	_btn_full_setup = ThemeHelper.make_hazard_button("[ NEW ATOMIC PROTOCOL (FULL CAMPAIGN) ]", Vector2(712.0, 40.0))
	_btn_full_setup.name = "NewProtocolButton"
	_btn_full_setup.add_theme_font_size_override("font_size", 15)
	_btn_full_setup.pressed.connect(_on_new_protocol_pressed)
	vbox.add_child(_btn_full_setup)

	# 4. 2x2 Grid for Scavenge Drill, Survival Only, Special Challenges, and Achievements/Garage
	var modes_grid := GridContainer.new()
	modes_grid.name = "ModesAndMetaGrid"
	modes_grid.columns = 2
	modes_grid.add_theme_constant_override("h_separation", 8)
	modes_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(modes_grid)

	_btn_scavenge_drill = ThemeHelper.make_alert_button("[ 3D SCAVENGE DRILL ]", Vector2(352.0, 36.0))
	_btn_scavenge_drill.name = "ScavengeDrillButton"
	_btn_scavenge_drill.add_theme_font_size_override("font_size", 13)
	_btn_scavenge_drill.pressed.connect(_on_scavenge_drill_pressed)
	modes_grid.add_child(_btn_scavenge_drill)

	_btn_survival_only = Button.new()
	_btn_survival_only.name = "SurvivalOnlyButton"
	_btn_survival_only.text = "[ SURVIVAL ONLY (INSTANT BUNKER) ]"
	_btn_survival_only.custom_minimum_size = Vector2(352.0, 36.0)
	_btn_survival_only.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_survival_only.add_theme_font_size_override("font_size", 13)
	_btn_survival_only.pressed.connect(_on_survival_only_pressed)
	modes_grid.add_child(_btn_survival_only)

	_btn_challenges = Button.new()
	_btn_challenges.name = "SpecialChallengesButton"
	_btn_challenges.text = "[ SPECIAL CHALLENGES (3) ]"
	_btn_challenges.custom_minimum_size = Vector2(352.0, 36.0)
	_btn_challenges.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_challenges.add_theme_font_size_override("font_size", 13)
	_style_secondary_accent_button(_btn_challenges, Color("#2d2720"), Color("#e08b2b"))
	_btn_challenges.pressed.connect(open_challenges_modal)
	modes_grid.add_child(_btn_challenges)

	var ach_unlocked: int = _count_unlocked_achievements()
	var total_ach: int = SaveManager.ACHIEVEMENTS_DEF.size()
	_btn_achievements = Button.new()
	_btn_achievements.name = "AchievementsGarageButton"
	_btn_achievements.text = "[ ACHIEVEMENTS & GARAGE TIER (%d/%d) ]" % [ach_unlocked, total_ach]
	_btn_achievements.custom_minimum_size = Vector2(352.0, 36.0)
	_btn_achievements.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_achievements.add_theme_font_size_override("font_size", 13)
	_style_secondary_accent_button(_btn_achievements, Color("#202925"), Color("#7ec850"))
	_btn_achievements.pressed.connect(open_achievements_modal)
	modes_grid.add_child(_btn_achievements)

	# 5. Watch AI Demo Button
	_btn_demo = Button.new()
	_btn_demo.name = "WatchDemoButton"
	_btn_demo.text = "[ WATCH AI DEMO ]"
	_btn_demo.custom_minimum_size = Vector2(712.0, 33.0)
	_btn_demo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_demo.add_theme_font_size_override("font_size", 13)
	_btn_demo.pressed.connect(_on_watch_demo_pressed)
	vbox.add_child(_btn_demo)

	# Bottom Telemetry Strip (y = 652..686)
	var footer_panel := ThemeHelper.make_card_panel(Color(0.10, 0.12, 0.10, 0.92), Color("#5c6454"))
	footer_panel.position = Vector2(210.0, 652.0)
	footer_panel.size = Vector2(860.0, 34.0)
	var footer_sb := StyleBoxFlat.new()
	footer_sb.bg_color = Color(0.10, 0.12, 0.10, 0.92)
	footer_sb.border_color = Color("#6e735f")
	footer_sb.set_border_width_all(1)
	footer_sb.set_corner_radius_all(3)
	footer_sb.content_margin_left = 12.0
	footer_sb.content_margin_right = 12.0
	footer_sb.content_margin_top = 3.0
	footer_sb.content_margin_bottom = 3.0
	footer_panel.add_theme_stylebox_override("panel", footer_sb)
	add_child(footer_panel)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.add_theme_font_size_override("font_size", 12)
	footer_panel.add_child(_status_label)
	_update_footer_telemetry()

	# Modal Overlays (hidden by default)
	_build_challenges_modal()
	_build_achievements_modal()

	# Non-interactive CRT Scanline & Vignette Shimmer Overlay on top
	_crt_overlay = _CrtOverlay.new()
	_crt_overlay.name = "CrtScanlineOverlay"
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_crt_overlay)

func _make_continue_button(text_str: String, min_sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = min_sz
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#243b27")
	normal.border_color = Color("#8fe05a")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 5.0
	normal.content_margin_bottom = 5.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2f4f33")
	hover.border_color = ThemeHelper.COLOR_HAZARD_YELLOW
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#1b2d1d")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("#eaffd8"))
	btn.add_theme_color_override("font_hover_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _style_secondary_accent_button(btn: Button, bg_col: Color, border_col: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = border_col
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 5.0
	normal.content_margin_bottom = 5.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg_col.lightened(0.14)
	hover.border_color = ThemeHelper.COLOR_HAZARD_YELLOW
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg_col.darkened(0.15)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func select_difficulty(diff_id: String) -> void:
	if diff_id != "little_boy" and diff_id != "fat_man" and diff_id != "tsar_bomba":
		return
	GameState.difficulty = diff_id
	SoundManager.play_sfx("button_click")
	_refresh_difficulty_styles()
	_update_footer_telemetry()

func _refresh_difficulty_styles() -> void:
	for raw_d in DIFFICULTY_SPECS:
		var spec: Dictionary = raw_d
		var d_id: String = str(spec.get("id", ""))
		var d_lbl: String = str(spec.get("label", ""))
		var accent_hex: String = str(spec.get("accent", "#f5be2e"))
		var accent_col := Color(accent_hex)
		if not _diff_buttons.has(d_id):
			continue
		var btn: Button = _diff_buttons[d_id] as Button
		var active: bool = (GameState.difficulty == d_id)
		btn.text = ("● [ %s ]" % d_lbl) if active else ("[ %s ]" % d_lbl)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(accent_col.r * 0.28, accent_col.g * 0.28, accent_col.b * 0.24, 0.96) if active else Color("#1d221d")
		sb.border_color = accent_col if active else Color("#565e50")
		sb.set_border_width_all(2 if active else 1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.border_color = accent_col.lightened(0.2)
		sb_hover.bg_color = sb.bg_color.lightened(0.10)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", accent_col.lightened(0.25) if active else Color("#c9bfa6"))
		btn.add_theme_color_override("font_hover_color", Color("#ffffff"))

func _update_footer_telemetry() -> void:
	if _status_label == null:
		return
	if _demo_started_on_ready and not GameState.promo_video_mode:
		_status_label.text = "● AUTO-DEMO SHOWCASE ACTIVE — INITIALIZING ATOMIC PROTOCOL IN 2.4s..."
		_status_label.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
		return

	var diff_summary: String = "60s Scavenge • Authentic Civil Defense Survival"
	for raw_d in DIFFICULTY_SPECS:
		var spec: Dictionary = raw_d
		if str(spec.get("id", "")) == GameState.difficulty:
			diff_summary = str(spec.get("summary", diff_summary))
			break
	var tier: int = SaveManager.get_vehicle_chassis_tier()
	_status_label.text = "DIFFICULTY: %s   •   GARAGE TIER: %d/3   •   FREQ: 640 / 1240 KC" % [diff_summary, tier]
	_status_label.add_theme_color_override("font_color", Color("#dccba6"))

func _make_feature_pill(label_str: String, dot_color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(354.0, 26.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.12, 0.92)
	sb.border_color = Color("#b8912d")
	sb.set_border_width_all(1)
	sb.border_width_left = 4
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
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
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
	hbox.add_child(lbl)
	return pill

# ==============================================================================
# SPECIAL CHALLENGES (3) OVERLAY MODAL
# ==============================================================================

func _build_challenges_modal() -> void:
	_challenge_modal = Control.new()
	_challenge_modal.name = "SpecialChallengesModal"
	_challenge_modal.visible = false
	_challenge_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_challenge_modal)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.05, 0.04, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_challenge_modal.add_child(backdrop)

	var card := ThemeHelper.make_card_panel(Color("#1d221d"), ThemeHelper.COLOR_HAZARD_GOLD)
	card.position = Vector2(180.0, 84.0)
	card.size = Vector2(920.0, 552.0)
	_challenge_modal.add_child(card)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	card.add_child(root_vbox)

	var hdr_row := HBoxContainer.new()
	root_vbox.add_child(hdr_row)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "★ SPECIAL CIVIL DEFENSE CHALLENGE DIRECTIVES (3) ★"
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_lbl.add_theme_font_size_override("font_size", 20)
	hdr_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	hdr_row.add_child(hdr_lbl)

	var close_btn := ThemeHelper.make_alert_button("[ X CLOSE ]", Vector2(126.0, 34.0))
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(close_challenges_modal)
	hdr_row.add_child(close_btn)

	var sub_lbl := Label.new()
	sub_lbl.text = "Each Special Challenge overrides house geography, shelter climate, or family roster with unique survival rules."
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color("#dccba6"))
	root_vbox.add_child(sub_lbl)

	for raw_c in CHALLENGE_SPECS:
		var c_spec: Dictionary = raw_c
		var c_id: String = str(c_spec.get("id", ""))
		var c_title: String = str(c_spec.get("title", ""))
		var c_badge: String = str(c_spec.get("badge", ""))
		var c_desc: String = str(c_spec.get("desc", ""))
		var c_acc := Color(str(c_spec.get("accent", "#f5be2e")))

		var item_card := ThemeHelper.make_card_panel(Color("#252b24"), c_acc)
		item_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(item_card)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 16)
		item_card.add_child(row_hbox)

		var txt_vbox := VBoxContainer.new()
		txt_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		txt_vbox.add_theme_constant_override("separation", 4)
		row_hbox.add_child(txt_vbox)

		var t_lbl := Label.new()
		t_lbl.text = c_title
		t_lbl.add_theme_font_size_override("font_size", 16)
		t_lbl.add_theme_color_override("font_color", c_acc.lightened(0.18))
		txt_vbox.add_child(t_lbl)

		var b_lbl := Label.new()
		b_lbl.text = c_badge
		b_lbl.add_theme_font_size_override("font_size", 11)
		b_lbl.add_theme_color_override("font_color", Color("#dccba6"))
		txt_vbox.add_child(b_lbl)

		var d_lbl := Label.new()
		d_lbl.text = c_desc
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.custom_minimum_size = Vector2(640.0, 0.0)
		d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_lbl.add_theme_font_size_override("font_size", 13)
		d_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
		txt_vbox.add_child(d_lbl)

		var launch_btn := ThemeHelper.make_hazard_button("[ DEPLOY ]", Vector2(164.0, 44.0))
		launch_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		launch_btn.pressed.connect(launch_challenge.bind(c_id))
		row_hbox.add_child(launch_btn)

func open_challenges_modal() -> void:
	if _transitioning or _challenge_modal == null:
		return
	SoundManager.play_sfx("page_turn")
	if _achievements_modal != null:
		_achievements_modal.visible = false
	_challenge_modal.visible = true

func close_challenges_modal() -> void:
	if _challenge_modal == null:
		return
	SoundManager.play_sfx("button_click")
	_challenge_modal.visible = false

# ==============================================================================
# ACHIEVEMENTS & GARAGE TIER (X/16) MODAL
# ==============================================================================

func _build_achievements_modal() -> void:
	if _achievements_modal != null and is_instance_valid(_achievements_modal):
		_achievements_modal.queue_free()

	_achievements_modal = Control.new()
	_achievements_modal.name = "AchievementsGarageModal"
	_achievements_modal.visible = false
	_achievements_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_achievements_modal)
	if _crt_overlay != null and is_instance_valid(_crt_overlay):
		move_child(_crt_overlay, get_child_count() - 1)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.05, 0.04, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_achievements_modal.add_child(backdrop)

	var card := ThemeHelper.make_card_panel(Color("#1d221d"), ThemeHelper.COLOR_HAZARD_GOLD)
	card.position = Vector2(140.0, 56.0)
	card.size = Vector2(1000.0, 608.0)
	_achievements_modal.add_child(card)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	card.add_child(root_vbox)

	var ach_cnt: int = _count_unlocked_achievements()
	var ach_tot: int = SaveManager.ACHIEVEMENTS_DEF.size()

	var hdr_row := HBoxContainer.new()
	root_vbox.add_child(hdr_row)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "★ SERVICE COMMENDATIONS (%d/%d) & STATION WAGON GARAGE ★" % [ach_cnt, ach_tot]
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_lbl.add_theme_font_size_override("font_size", 19)
	hdr_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	hdr_row.add_child(hdr_lbl)

	var close_btn := ThemeHelper.make_alert_button("[ X CLOSE ]", Vector2(126.0, 34.0))
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(close_achievements_modal)
	hdr_row.add_child(close_btn)

	# Top Summary Split: Left = Multi-Run Garage Chassis Tier 0..3, Right = Career Stats & Unlocked Hats
	var top_split := HBoxContainer.new()
	top_split.add_theme_constant_override("separation", 12)
	top_split.custom_minimum_size = Vector2(960.0, 134.0)
	root_vbox.add_child(top_split)

	var tier: int = SaveManager.get_vehicle_chassis_tier()
	var banked_parts: int = int(SaveManager.meta.get("total_vehicle_parts_banked", 0))
	var garage_card := ThemeHelper.make_card_panel(Color("#232a24"), Color("#7ec850") if tier > 0 else Color("#b8912d"))
	garage_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_split.add_child(garage_card)

	var g_vbox := VBoxContainer.new()
	g_vbox.add_theme_constant_override("separation", 4)
	garage_card.add_child(g_vbox)

	var g_hdr := Label.new()
	g_hdr.text = "MULTI-RUN STATION WAGON CHASSIS — TIER %d / 3" % tier
	g_hdr.add_theme_font_size_override("font_size", 15)
	g_hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	g_vbox.add_child(g_hdr)

	var g_perk_txt: String = _describe_garage_tier(tier)
	var g_perk := Label.new()
	g_perk.text = g_perk_txt
	g_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g_perk.custom_minimum_size = Vector2(430.0, 0.0)
	g_perk.add_theme_font_size_override("font_size", 13)
	g_perk.add_theme_color_override("font_color", Color("#b8f28a") if tier > 0 else ThemeHelper.COLOR_PARCHMENT)
	g_vbox.add_child(g_perk)

	var g_bank := Label.new()
	g_bank.text = "Career Engine Parts Banked: %d   •   Tier 1: 2 pts | Tier 2: 4 pts | Tier 3: 8 pts or Vehicle Escape" % banked_parts
	g_bank.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g_bank.custom_minimum_size = Vector2(430.0, 0.0)
	g_bank.add_theme_font_size_override("font_size", 11)
	g_bank.add_theme_color_override("font_color", Color("#dccba6"))
	g_vbox.add_child(g_bank)

	# Career Stats & Unlocked Hats Card
	var stats_card := ThemeHelper.make_card_panel(Color("#232824"), Color("#8c7b54"))
	stats_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_split.add_child(stats_card)

	var s_vbox := VBoxContainer.new()
	s_vbox.add_theme_constant_override("separation", 5)
	stats_card.add_child(s_vbox)

	var s_hdr := Label.new()
	s_hdr.text = "CAREER DOSSIER STATS & UNLOCKED SURVIVOR HATS"
	s_hdr.add_theme_font_size_override("font_size", 15)
	s_hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	s_vbox.add_child(s_hdr)

	var runs_p: int = int(SaveManager.meta.get("runs_played", 0))
	var wins_p: int = int(SaveManager.meta.get("victories", 0))
	var best_d: int = int(SaveManager.meta.get("longest_days", 0))
	var best_i: int = int(SaveManager.meta.get("best_scavenge_items", 0))

	var s_metrics := Label.new()
	s_metrics.text = "Runs Played: %d   •   Victories: %d   •   Longest Survival: %d Days   •   Best 60s Haul: %d Items" % [runs_p, wins_p, best_d, best_i]
	s_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_metrics.custom_minimum_size = Vector2(430.0, 0.0)
	s_metrics.add_theme_font_size_override("font_size", 12)
	s_metrics.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
	s_vbox.add_child(s_metrics)

	var unlocked_hats: Array = SaveManager.get_unlocked_hats()
	var hat_names: Array[String] = []
	for raw_h in unlocked_hats:
		var hid: String = str(raw_h)
		if hid == "none":
			continue
		hat_names.append(str(HAT_LABELS.get(hid, hid.capitalize())))
	var hats_str: String = ", ".join(hat_names) if not hat_names.is_empty() else "None yet — earn Achievements below to unlock Civil Defense headgear!"

	var s_hats := Label.new()
	s_hats.text = "Unlocked Hats (%d/4): %s" % [hat_names.size(), hats_str]
	s_hats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_hats.custom_minimum_size = Vector2(430.0, 0.0)
	s_hats.add_theme_font_size_override("font_size", 12)
	s_hats.add_theme_color_override("font_color", Color("#9fd878") if not hat_names.is_empty() else Color("#dccba6"))
	s_vbox.add_child(s_hats)

	# Scrollable 16-Achievement Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var ach_grid := GridContainer.new()
	ach_grid.columns = 2
	ach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_grid.add_theme_constant_override("h_separation", 10)
	ach_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(ach_grid)

	for raw_key in SaveManager.ACHIEVEMENTS_DEF.keys():
		var ach_id: String = str(raw_key)
		var def_d: Dictionary = SaveManager.ACHIEVEMENTS_DEF[ach_id]
		var unlocked: bool = SaveManager.is_achievement_unlocked(ach_id)
		var a_title: String = str(def_d.get("title", ach_id))
		var a_desc: String = str(def_d.get("desc", ""))
		var a_hat: String = str(def_d.get("unlock_hat", ""))

		var a_card := ThemeHelper.make_card_panel(
			Color("#253024") if unlocked else Color("#1c201c"),
			Color("#8fe05a") if unlocked else Color("#4a5246")
		)
		a_card.custom_minimum_size = Vector2(468.0, 74.0)
		ach_grid.add_child(a_card)

		var a_vbox := VBoxContainer.new()
		a_vbox.add_theme_constant_override("separation", 2)
		a_card.add_child(a_vbox)

		var prefix: String = "★ [UNLOCKED] " if unlocked else "○ [LOCKED] "
		var reward_tag: String = ("  •  Hat: " + str(HAT_LABELS.get(a_hat, a_hat))) if a_hat != "" else ""
		var at_lbl := Label.new()
		at_lbl.text = prefix + a_title + reward_tag
		at_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		at_lbl.custom_minimum_size = Vector2(436.0, 0.0)
		at_lbl.add_theme_font_size_override("font_size", 13)
		at_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW if unlocked else Color("#a89f8c"))
		a_vbox.add_child(at_lbl)

		var ad_lbl := Label.new()
		ad_lbl.text = a_desc
		ad_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ad_lbl.custom_minimum_size = Vector2(436.0, 0.0)
		ad_lbl.add_theme_font_size_override("font_size", 11)
		ad_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT if unlocked else Color("#8a8372"))
		a_vbox.add_child(ad_lbl)

static func _describe_garage_tier(tier: int) -> String:
	match tier:
		1:
			return "Active Bonus: Heavy-Duty 12V Battery is pre-installed in the shelter Station Wagon every run!"
		2:
			return "Active Bonus: 12V Battery & Reinforced Radiator Hose are pre-installed every run!"
		3:
			return "MAX TIER BONUS: Battery, Radiator Hose & 1 Fuel Jerrycan pre-installed + Fuel Needed reduced to 2!"
		_:
			return "Current Status: Bare Rusty Frame (0/4 parts pre-installed). Scavenge Auto Shops & Hardware Stores to bank upgrades!"

func open_achievements_modal() -> void:
	if _transitioning:
		return
	SoundManager.play_sfx("page_turn")
	if _challenge_modal != null:
		_challenge_modal.visible = false
	_build_achievements_modal()
	_achievements_modal.visible = true
	if _btn_achievements != null:
		_btn_achievements.text = "[ ACHIEVEMENTS & GARAGE TIER (%d/%d) ]" % [_count_unlocked_achievements(), SaveManager.ACHIEVEMENTS_DEF.size()]

func close_achievements_modal() -> void:
	if _achievements_modal == null:
		return
	SoundManager.play_sfx("button_click")
	_achievements_modal.visible = false

# ==============================================================================
# MODE, CONTINUE, CHALLENGE & DEMO LAUNCH HANDLERS
# ==============================================================================

func _process(delta: float) -> void:
	_anim_time += delta
	if _crt_overlay != null:
		_crt_overlay.set("scan_time", _anim_time)
		_crt_overlay.queue_redraw()

	if _demo_started_on_ready and not _transitioning:
		_demo_timer += delta
		var rem: float = maxf(0.0, DEMO_HOLD_DURATION - _demo_timer)
		if _status_label != null and not GameState.promo_video_mode:
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
			GameState.game_mode = "full_protocol"
			GameState.active_challenge_id = ""
			GameState.reset_to_defaults()
			GameState.request_screen(GameState.SCREEN_FAMILY)
			return

	queue_redraw()

func _on_continue_saved_pressed() -> void:
	if _transitioning:
		return
	if not SaveManager.load_run():
		return
	_transitioning = true
	SoundManager.play_sfx("hatch_slam")
	GameState.demo_mode = false
	GameState.story_flags["loaded_from_save"] = true
	GameState.request_screen(GameState.SCREEN_BUNKER)

func _on_new_protocol_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = false
	GameState.game_mode = "full_protocol"
	GameState.active_challenge_id = ""
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_FAMILY)

func _on_scavenge_drill_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("siren")
	GameState.demo_mode = false
	GameState.game_mode = "scavenge_drill"
	GameState.active_challenge_id = ""
	GameState.init_default_family()
	GameState.init_default_house()
	GameState.init_default_nuke()
	GameState.reset_to_defaults()
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	GameState.nuke_config["scavenge_seconds"] = float(diff_cfg.get("scavenge_seconds", 60.0))
	GameState.request_screen(GameState.SCREEN_SCAVENGE)

func _on_survival_only_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("hatch_slam")
	GameState.demo_mode = false
	GameState.game_mode = "survival_only"
	GameState.active_challenge_id = ""
	GameState.init_default_family()
	GameState.init_default_house()
	GameState.init_default_nuke()
	GameState.nearby_pois = []
	GameState.reset_to_defaults()

	# Seed instant-bunker family & difficulty-adjusted Civil Defense rations
	for raw_m in GameState.family_members:
		if raw_m is Dictionary:
			var m: Dictionary = raw_m
			m["in_bunker"] = true
			m["alive"] = true
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var soup_bonus: int = int(diff_cfg.get("spawn_soup_bonus", 0))
	var water_bonus: int = int(diff_cfg.get("spawn_water_bonus", 0))
	GameState.soup_quarters = maxi(8, (4 + soup_bonus) * 4)
	GameState.water_quarters = maxi(8, (5 + water_bonus) * 4)
	GameState.medkit_count = 1 if GameState.difficulty == "tsar_bomba" else 2
	GameState.bug_spray_count = 1
	GameState.ammo_count = 4
	GameState.scrap_count = 2
	GameState.padlock_active = true
	for gid in ["gas_mask", "radio", "map", "suitcase", "flashlight", "cards", "toolbox"]:
		if GameState.bunker_items.has(gid):
			GameState.bunker_items[gid]["owned"] = true
			GameState.bunker_items[gid]["broken"] = false
			GameState.bunker_items[gid]["count"] = 1
	GameState.scavenge_stats = {
		"items_collected": 14,
		"family_saved": 4,
		"leader_escaped": true,
		"time_remaining": 5.0
	}
	GameState.request_screen(GameState.SCREEN_BUNKER)

func launch_challenge(challenge_id: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	if _challenge_modal != null:
		_challenge_modal.visible = false
	SoundManager.play_sfx("siren")

	GameState.demo_mode = false
	GameState.game_mode = "challenge"
	GameState.active_challenge_id = challenge_id
	GameState.init_default_family()
	GameState.init_default_house()
	GameState.init_default_nuke()
	GameState.nearby_pois = []
	GameState.reset_to_defaults()

	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var scav_secs: float = float(diff_cfg.get("scavenge_seconds", 60.0))

	match challenge_id:
		"cul_de_sac_odyssey":
			_configure_walborough_challenge(scav_secs)
		"nuclear_winter_zero":
			GameState.nuke_config["target_name"] = "Arctic Polar Vortex Detonation"
			GameState.nuke_config["zone"] = "nuclear_winter_zero"
			GameState.nuke_config["bunker_temp_c"] = -16.0
			GameState.nuke_config["initial_sv_hr"] = 9.2
			GameState.nuke_config["fallout_days"] = 21
			GameState.nuke_config["scavenge_seconds"] = scav_secs
			GameState.bunker_temp_c = -16.0
			GameState.surface_radiation_sv = 9.2
			GameState.story_flags["nuclear_winter_zero"] = true
		"lone_wolf_pets":
			if not GameState.family_members.is_empty():
				var leader_member: Dictionary = GameState.family_members[0] as Dictionary
				leader_member["is_leader"] = true
				leader_member["scavenge_slots"] = 4
				GameState.family_members = [leader_member]
			GameState.relationships = {}
			GameState.has_cat_sharikov = true
			GameState.has_dog_pancake = true
			GameState.nuke_config["scavenge_seconds"] = scav_secs
			GameState.story_flags["lone_wolf_pets"] = true

	GameState.request_screen(GameState.SCREEN_SCAVENGE)

func _configure_walborough_challenge(scav_secs: float) -> void:
	var wal_lat: float = 37.7085
	var wal_lon: float = -77.6078
	var preset_path: String = "res://data/osm_presets/wyndham_walborough_va.json"
	var chosen_house: Dictionary = {}

	if FileAccess.file_exists(preset_path):
		var f: FileAccess = FileAccess.open(preset_path, FileAccess.READ)
		if f != null:
			var raw_json: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if raw_json is Dictionary:
				var parsed: Dictionary = OsmService.parse_osm_json(raw_json as Dictionary, wal_lat, wal_lon)
				var bldgs: Array = parsed.get("buildings", [])
				var pois: Array = parsed.get("pois", [])
				for raw_b in bldgs:
					if raw_b is Dictionary:
						var bd: Dictionary = raw_b
						var addr_s: String = str(bd.get("address", ""))
						if int(bd.get("osm_id", 0)) == 706121395 or (addr_s.contains("6217") and addr_s.to_lower().contains("walborough")):
							chosen_house = bd.duplicate(true)
							break
				if chosen_house.is_empty() and not bldgs.is_empty() and bldgs[0] is Dictionary:
					chosen_house = (bldgs[0] as Dictionary).duplicate(true)
				if not chosen_house.is_empty():
					chosen_house["name"] = "6217 Walborough Ct Residence"
					chosen_house["address"] = "6217 Walborough Ct, Glen Allen, VA 23059"
					GameState.selected_house = chosen_house
					GameState.nearby_pois = OsmService.build_nearby_targets_for_house(chosen_house, bldgs, pois)

	if chosen_house.is_empty():
		GameState.selected_house = {
			"osm_id": 706121395,
			"name": "6217 Walborough Ct Residence",
			"address": "6217 Walborough Ct, Glen Allen, VA 23059",
			"lat": wal_lat,
			"lon": wal_lon,
			"building_type": "house",
			"area_sqm": 248.0,
			"footprint_meters": [
				Vector2(-8.4, -6.5),
				Vector2(8.4, -6.5),
				Vector2(8.4, 2.2),
				Vector2(4.2, 2.2),
				Vector2(4.2, 6.8),
				Vector2(-8.4, 6.8)
			],
			"estimated_rooms": 7
		}

	GameState.current_neighborhood_label = "Wyndham Cul-de-Sac, Glen Allen, VA (6217 Walborough Ct)"
	GameState.nuke_config = {
		"target_name": "Richmond / I-295 Strategic Rail & Defense Junction, VA",
		"lat": 37.6520,
		"lon": -77.5620,
		"yield_kt": 950,
		"wind_bearing_deg": 315.0,
		"distance_km": 7.45,
		"zone": "suburban_fallout_ring",
		"initial_sv_hr": 5.8,
		"bunker_temp_c": 19.5,
		"tremor_intensity": 0.65,
		"structural_damage": 0.22,
		"raider_aggression": 0.60,
		"fallout_days": 14,
		"scavenge_seconds": scav_secs,
		"scout_seconds": 8.0
	}
	GameState.surface_radiation_sv = 5.8
	GameState.bunker_temp_c = 19.5
	GameState.story_flags["cul_de_sac_odyssey"] = true

func _on_watch_demo_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = true
	GameState.game_mode = "full_protocol"
	GameState.active_challenge_id = ""
	GameState.init_default_family()
	GameState.init_default_house()
	GameState.init_default_nuke()
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_FAMILY)

# ==============================================================================
# PROCEDURAL 1950s CONELRAD POSTER & RADAR ARTWORK
# ==============================================================================

func _draw() -> void:
	var vp: Vector2 = size
	if vp.x < 100.0 or vp.y < 100.0:
		vp = Vector2(1280.0, 720.0)

	var font: Font = ThemeDB.fallback_font

	# 1. Deep Bunker Olive / CONELRAD Broadcast Backdrop
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#171a17"), true)
	draw_circle(Vector2(vp.x * 0.5, 240.0), 540.0, Color(0.18, 0.21, 0.17, 0.55))
	draw_circle(Vector2(vp.x * 0.5, 140.0), 330.0, Color(0.24, 0.26, 0.19, 0.38))

	# 2. World Latitude & Longitude Grid + Radar Sweep + Outer-Corner Blips
	_draw_world_grid_and_radar(vp, font)

	# 3. Top & Bottom CONELRAD Hazard Stripe Borders
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, 0.0, vp.x, 20.0), 18.0)
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, vp.y - 20.0, vp.x, 20.0), 18.0)
	draw_line(Vector2(0.0, 21.0), Vector2(vp.x, 21.0), ThemeHelper.COLOR_HAZARD_GOLD, 2.0)
	draw_line(Vector2(0.0, vp.y - 21.0), Vector2(vp.x, vp.y - 21.0), ThemeHelper.COLOR_HAZARD_GOLD, 2.0)

	# 4. Broadcast Top Ticker Banner
	_draw_broadcast_banner(vp, font)

	# 5. Rotating Radiation Trefoil Emblem & Flanking Frequency Oscilloscopes
	var emblem_center := Vector2(vp.x * 0.5, 112.0)
	_draw_frequency_scopes(emblem_center, font)
	_draw_radiation_emblem(emblem_center, 50.0, font)

	# 6. Hero Poster Title & Subtitle
	_draw_hero_typography(vp, font)

	# 7. Floating Soup Can, Gas Mask & Civil Defense Supply Silhouettes
	_draw_floating_supplies(vp, font)

	# 8. Demo Progress Bar Indicator (when in auto-demo mode)
	if _demo_started_on_ready and not GameState.promo_video_mode:
		var prog: float = clampf(_demo_timer / DEMO_HOLD_DURATION, 0.0, 1.0)
		var bar_rect := Rect2(210.0, 690.0, 860.0 * prog, 4.0)
		draw_rect(Rect2(210.0, 690.0, 860.0, 4.0), Color(0.1, 0.1, 0.1, 0.8), true)
		draw_rect(bar_rect, ThemeHelper.COLOR_HAZARD_YELLOW, true)

func _draw_world_grid_and_radar(vp: Vector2, font: Font) -> void:
	var grid_col := Color(0.52, 0.72, 0.42, 0.11)
	var eq_col := Color(0.95, 0.74, 0.18, 0.16)

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

	for lon_i in range(-5, 6):
		var pts_m := PackedVector2Array()
		var steps_m: int = 24
		for s in range(steps_m + 1):
			var v: float = float(s) / float(steps_m)
			var y: float = 22.0 + v * (vp.y - 44.0)
			var bulge: float = sin(v * PI)
			var x: float = vp.x * 0.5 + float(lon_i) * (112.0 * (0.55 + 0.45 * bulge))
			pts_m.append(Vector2(x, y))
		draw_polyline(pts_m, grid_col, 1.0, true)

	var radar_origin := Vector2(vp.x * 0.5, 280.0)
	for ring_r in [160.0, 280.0, 410.0, 540.0]:
		draw_arc(radar_origin, ring_r, 0.0, TAU, 72, Color(0.95, 0.74, 0.18, 0.08), 1.0, true)

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

	# Pulsing Global Strike Target Blips in clean outer corners (zero title collision)
	for blip in RADAR_BLIPS:
		var uv: Vector2 = blip.get("uv", Vector2(0.5, 0.5))
		var b_pos := Vector2(uv.x * vp.x, uv.y * vp.y)
		var ph: float = float(blip.get("phase", 0.0))
		var pulse: float = fmod(_anim_time * 0.7 + ph, 1.0)
		draw_arc(b_pos, 6.0 + pulse * 24.0, 0.0, TAU, 24, Color(0.88, 0.35, 0.17, (1.0 - pulse) * 0.38), 1.4, true)
		draw_circle(b_pos, 3.2, Color(0.96, 0.75, 0.18, 0.65))
		var b_name: String = str(blip.get("name", ""))
		draw_string(font, b_pos + Vector2(7.0, 4.0), b_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.90, 0.78, 0.38))

func _draw_broadcast_banner(vp: Vector2, font: Font) -> void:
	var bar_rect := Rect2(vp.x * 0.5 - 350.0, 26.0, 700.0, 24.0)
	draw_rect(bar_rect, Color(0.11, 0.12, 0.10, 0.94), true)
	draw_rect(bar_rect, ThemeHelper.COLOR_HAZARD_GOLD, false, 1.5)

	var blink_on: bool = sin(_anim_time * 5.5) > -0.2
	var lamp_col: Color = Color("#ff4c29") if blink_on else Color("#5e2216")
	draw_circle(Vector2(bar_rect.position.x + 18.0, bar_rect.position.y + 12.0), 4.8, lamp_col)
	draw_arc(Vector2(bar_rect.position.x + 18.0, bar_rect.position.y + 12.0), 4.8, 0.0, TAU, 16, ThemeHelper.COLOR_INK, 1.2)

	var txt := "CONELRAD EMERGENCY BROADCAST   •   640 / 1240 KC   •   CIVIL DEFENSE V2"
	var t_sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(
		font,
		Vector2(vp.x * 0.5 - t_sz.x * 0.5 + 8.0, bar_rect.position.y + 16.5),
		txt,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		ThemeHelper.COLOR_HAZARD_YELLOW
	)

func _draw_frequency_scopes(center: Vector2, font: Font) -> void:
	for side in [-1, 1]:
		var sx: float = center.x + float(side) * 190.0
		var box := Rect2(sx - 76.0, center.y - 23.0, 152.0, 46.0)
		draw_rect(box, Color(0.09, 0.12, 0.09, 0.90), true)
		draw_rect(box, Color("#626d58"), false, 1.5)

		draw_line(Vector2(box.position.x, center.y), Vector2(box.end.x, center.y), Color(0.4, 0.6, 0.35, 0.25), 1.0)
		var wave_pts := PackedVector2Array()
		var freq_mult: float = 2.6 if side < 0 else 4.2
		for idx in range(33):
			var u: float = float(idx) / 32.0
			var wx: float = box.position.x + 6.0 + u * (box.size.x - 12.0)
			var env: float = sin(u * PI)
			var wy: float = center.y + sin(u * TAU * freq_mult - _anim_time * 6.5 * float(side)) * 12.5 * env
			wave_pts.append(Vector2(wx, wy))
		draw_polyline(wave_pts, Color("#7ec850"), 1.8, true)

		var tag: String = "640 KC CARRIER" if side < 0 else "1240 KC ALERT"
		var tag_sz: Vector2 = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, Vector2(sx - tag_sz.x * 0.5, box.end.y + 12.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#dccba6"))

func _draw_radiation_emblem(center: Vector2, radius: float, _font: Font) -> void:
	var halo_pulse: float = 0.5 + 0.5 * sin(_anim_time * 3.0)
	draw_circle(center, radius + 8.0 + halo_pulse * 4.0, Color(0.95, 0.74, 0.18, 0.12 + halo_pulse * 0.08))

	draw_circle(center, radius + 3.5, ThemeHelper.COLOR_INK)
	draw_circle(center, radius, ThemeHelper.COLOR_HAZARD_GOLD)
	draw_circle(center, radius - 4.5, ThemeHelper.COLOR_INK)
	draw_circle(center, radius - 7.0, Color("#f2b82e"))

	for i in range(24):
		var ang: float = float(i) * TAU / 24.0
		var r0: float = radius - 6.5
		var r1: float = radius - (2.5 if i % 2 == 0 else 4.5)
		draw_line(
			center + Vector2(cos(ang), sin(ang)) * r0,
			center + Vector2(cos(ang), sin(ang)) * r1,
			ThemeHelper.COLOR_INK,
			1.4
		)

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

	draw_circle(center, radius * 0.19, ThemeHelper.COLOR_HAZARD_GOLD)
	draw_circle(center, radius * 0.13, ThemeHelper.COLOR_INK)
	draw_circle(center, radius * 0.05, ThemeHelper.COLOR_ATOMIC_ORANGE)

func _draw_hero_typography(vp: Vector2, font: Font) -> void:
	var title_str := "60 SECONDS: WORLD REATOMIZED"
	var title_size: int = 38
	var t_dim: Vector2 = font.get_string_size(title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size)
	var tx: float = vp.x * 0.5 - t_dim.x * 0.5
	var ty: float = 212.0

	var plate := Rect2(vp.x * 0.5 - t_dim.x * 0.5 - 24.0, 174.0, t_dim.x + 48.0, 50.0)
	draw_rect(plate, Color(0.11, 0.12, 0.10, 0.88), true)
	draw_rect(plate, ThemeHelper.COLOR_ATOMIC_ORANGE, false, 2.0)

	draw_string(font, Vector2(tx + 3.0, ty + 3.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ThemeHelper.COLOR_INK)
	draw_string(font, Vector2(tx + 1.5, ty + 1.5), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ThemeHelper.COLOR_ATOMIC_ORANGE)
	draw_string(font, Vector2(tx, ty), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ThemeHelper.COLOR_HAZARD_YELLOW)

	var sub_str := "PICK YOUR REAL HOUSE ON OPENSTREETMAP  •  CUSTOMIZE YOUR FAMILY  •  SURVIVE THE FALLOUT"
	var sub_size: int = 13
	var s_dim: Vector2 = font.get_string_size(sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size)
	var sx: float = vp.x * 0.5 - s_dim.x * 0.5
	var sy: float = 244.0
	draw_string(font, Vector2(sx + 1.0, sy + 1.0), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, ThemeHelper.COLOR_INK)
	draw_string(font, Vector2(sx, sy), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, ThemeHelper.COLOR_PARCHMENT)

	draw_line(Vector2(vp.x * 0.5 - 290.0, 254.0), Vector2(vp.x * 0.5 + 290.0, 254.0), Color(0.95, 0.74, 0.18, 0.45), 1.2)

func _draw_floating_supplies(vp: Vector2, font: Font) -> void:
	for entry in FLOATING_SUPPLIES:
		var item_id: String = str(entry.get("id", "soup"))
		var label_txt: String = str(entry.get("label", ""))
		var side: int = int(entry.get("side", -1))
		var row: int = int(entry.get("row", 0))
		var ph: float = float(entry.get("phase", 0.0))

		var base_x: float = 116.0 if side < 0 else (vp.x - 116.0)
		var base_y: float = 205.0 + float(row) * 170.0
		var bob_y: float = sin(_anim_time * 1.9 + ph) * 7.0
		var bob_x: float = cos(_anim_time * 1.2 + ph) * 3.0
		var c_pos := Vector2(base_x + bob_x, base_y + bob_y)

		draw_circle(c_pos, 40.0, Color(0.10, 0.12, 0.10, 0.85))
		draw_arc(c_pos, 40.0, 0.0, TAU, 36, Color(0.95, 0.74, 0.18, 0.52), 1.6, true)
		draw_arc(c_pos, 34.0, 0.0, TAU, 32, Color(0.88, 0.35, 0.17, 0.25), 1.0, true)

		for tick_dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c_pos + tick_dir * 36.0, c_pos + tick_dir * 44.0, ThemeHelper.COLOR_HAZARD_GOLD, 1.5)

		ItemDB.draw_item_icon(self, item_id, c_pos, 44.0, false)

		var tag_dim: Vector2 = font.get_string_size(label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var tag_rect := Rect2(c_pos.x - tag_dim.x * 0.5 - 6.0, c_pos.y + 45.0, tag_dim.x + 12.0, 17.0)
		draw_rect(tag_rect, Color(0.11, 0.12, 0.10, 0.90), true)
		draw_rect(tag_rect, Color(0.65, 0.56, 0.34, 0.65), false, 1.0)
		draw_string(
			font,
			Vector2(c_pos.x - tag_dim.x * 0.5, c_pos.y + 57.5),
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

		var y: float = 0.0
		while y < vp.y:
			draw_line(Vector2(0.0, y), Vector2(vp.x, y), Color(0.0, 0.0, 0.0, 0.10), 1.0)
			y += 4.0

		var shimmer_y: float = fmod(scan_time * 95.0, vp.y + 120.0) - 60.0
		draw_rect(Rect2(0.0, shimmer_y, vp.x, 42.0), Color(0.95, 0.85, 0.55, 0.025), true)
		draw_line(Vector2(0.0, shimmer_y + 21.0), Vector2(vp.x, shimmer_y + 21.0), Color(0.96, 0.78, 0.25, 0.05), 1.5)

		draw_rect(Rect2(2.0, 2.0, vp.x - 4.0, vp.y - 4.0), Color(0.08, 0.08, 0.07, 0.65), false, 4.0)
