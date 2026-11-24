class_name FamilyScreen
extends Control

## 1950s Civil Defense Personnel Dossier — Interactive Family Customization Screen (1280x720).
## Built purely in code in _ready() with zero .tscn dependencies.

const COL_BG_DARK := Color("#1a1d1a")
const COL_BG_PANEL := Color("#242924")
const COL_PARCHMENT := Color("#efe3c8")
const COL_PARCHMENT_DARK := Color("#dccba6")
const COL_INK := Color("#1d1a16")
const COL_HAZARD_YELLOW := Color("#f2b82e")
const COL_ATOMIC_ORANGE := Color("#d94c2a")
const COL_TOXIC_GREEN := Color("#7ec850")
const COL_WATER_BLUE := Color("#3b8ec2")

const TRAIT_LIST: Array[Dictionary] = [
	{"id": "handy", "name": "Handy Mechanic", "desc": "Repairs broken bunker gear faster & safer."},
	{"id": "sprinter", "name": "60s Sprinter", "desc": "+15% top movement speed during house scavenge."},
	{"id": "iron_stomach", "name": "Iron Stomach", "desc": "Resists sickness from stale rations & fallout."},
	{"id": "scout", "name": "Neighborhood Scout", "desc": "Finds extra supplies at real-world OSM landmarks."},
	{"id": "bookworm", "name": "Civil Bookworm", "desc": "Keeps sanity steadier during long bunker lockups."},
	{"id": "optimist", "name": "Atomic Optimist", "desc": "Boosts household morale during dark events."}
]

const RANDOM_FIRST_NAMES: Array[String] = [
	"Arthur", "Betty", "Clarence", "Dorothy", "Eugene", "Francine", "George", "Hazel",
	"Howard", "Irene", "Junior", "Lorraine", "Milton", "Nancy", "Otis", "Peggy",
	"Raymond", "Shirley", "Stanley", "Virginia", "Walter", "Wanda", "Billy", "Susie"
]

var selected_index: int = 0
var condition_preview_mode: String = "healthy" # "healthy", "starving", "sick", "insane", "mutant"
var anim_clock: float = 0.0
var _updating_ui: bool = false

# Demo showcase state
var _demo_elapsed: float = 0.0
var _demo_step_idx: int = -1
var _demo_finished: bool = false

# UI Node references
var _roster_cards_box: VBoxContainer
var _add_member_btn: Button
var _remove_member_btn: Button
var _preview_canvas: Control
var _role_perk_label: Label
var _cond_buttons: Dictionary = {}

var _name_edit: LineEdit
var _leader_btn: Button
var _age_slider: HSlider
var _age_value_label: Label
var _trait_label: Label
var _trait_desc_label: Label
var _hair_style_label: Label
var _facial_hair_label: Label
var _shirt_style_label: Label
var _glasses_check: CheckBox

var _skin_swatch_btns: Array[Button] = []
var _hair_color_btns: Array[Button] = []
var _eye_color_btns: Array[Button] = []
var _outfit_color_btns: Array[Button] = []

var _footer_summary_label: Label
var _demo_banner_panel: PanelContainer
var _demo_banner_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280, 720)

	if SoundManager != null and SoundManager.has_method("set_ambience"):
		SoundManager.set_ambience("menu")

	_ensure_valid_household()
	_build_ui()
	_refresh_all_ui()

func _process(delta: float) -> void:
	anim_clock += delta
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()
	if _roster_cards_box != null:
		for child in _roster_cards_box.get_children():
			if child is Control:
				(child as Control).queue_redraw()

	if GameState.demo_mode and not _demo_finished:
		_update_demo_mode(delta)

func _draw() -> void:
	var vp := Rect2(Vector2.ZERO, Vector2(1280, 720))
	draw_rect(vp, COL_BG_DARK, true)

	# Subtle bunker concrete grid lines
	var grid_col := Color(1.0, 0.96, 0.88, 0.03)
	for gx in range(0, 1280, 64):
		draw_line(Vector2(float(gx), 56.0), Vector2(float(gx), 654.0), grid_col, 1.0)
	for gy in range(64, 654, 64):
		draw_line(Vector2(0.0, float(gy)), Vector2(1280.0, float(gy)), grid_col, 1.0)

	# Top Civil Defense Header Bar
	var top_rect := Rect2(0, 0, 1280, 56)
	draw_rect(top_rect, COL_BG_PANEL, true)
	draw_line(Vector2(0, 55), Vector2(1280, 55), COL_HAZARD_YELLOW, 3.0)

	# Hazard diagonal stripes accent on top-right & top-left
	_draw_hazard_strip(Rect2(0, 0, 110, 8))
	_draw_hazard_strip(Rect2(1170, 0, 110, 8))

	# CONELRAD Civil Defense Triangle-in-Circle emblem at (38, 28)
	var emb_c := Vector2(36, 29)
	draw_circle(emb_c, 18.0, COL_HAZARD_YELLOW)
	draw_arc(emb_c, 18.0, 0.0, TAU, 24, COL_INK, 2.2)
	var tri := PackedVector2Array([
		emb_c + Vector2(0, -12),
		emb_c + Vector2(11, 8),
		emb_c + Vector2(-11, 8)
	])
	draw_colored_polygon(tri, COL_ATOMIC_ORANGE)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), COL_INK, 1.8)

	# Bottom Navigation Bar backdrop
	var bot_rect := Rect2(0, 654, 1280, 66)
	draw_rect(bot_rect, COL_BG_PANEL, true)
	draw_line(Vector2(0, 654), Vector2(1280, 654), COL_HAZARD_YELLOW, 2.5)

func _draw_hazard_strip(rect: Rect2) -> void:
	draw_rect(rect, COL_HAZARD_YELLOW, true)
	var step: float = 16.0
	var x: float = rect.position.x
	while x < rect.end.x:
		var p := PackedVector2Array([
			Vector2(x, rect.end.y),
			Vector2(minf(x + 8.0, rect.end.x), rect.end.y),
			Vector2(minf(x + 14.0, rect.end.x), rect.position.y),
			Vector2(minf(x + 6.0, rect.end.x), rect.position.y)
		])
		draw_colored_polygon(p, COL_INK)
		x += step

# ==============================================================================
# HOUSEHOLD INTEGRITY & HELPERS
# ==============================================================================
func _ensure_valid_household() -> void:
	if GameState.family_members.is_empty():
		GameState.init_default_family()
	# Clamp 1..4 members
	while GameState.family_members.size() > 4:
		GameState.family_members.pop_back()

	# Normalize roles, slots, and guarantee exactly 1 leader with age >= 13
	var leader_found: bool = false
	for i in range(GameState.family_members.size()):
		var m: Dictionary = GameState.family_members[i]
		m["id"] = "member_%d" % i
		var age_val: int = clampi(int(m.get("age", 35)), 5, 85)
		m["age"] = age_val
		var role_str: String = CharacterArtist.get_role_for_age(age_val)
		m["role"] = role_str
		m["scavenge_slots"] = 2 if age_val < 18 else 3
		if bool(m.get("is_leader", false)) and age_val >= 13 and not leader_found:
			m["is_leader"] = true
			leader_found = true
		else:
			m["is_leader"] = false

	if not leader_found:
		# Pick first member with age >= 13, or promote member 0 to age 18
		var promoted: bool = false
		for m in GameState.family_members:
			if int(m.get("age", 35)) >= 13:
				m["is_leader"] = true
				promoted = true
				break
		if not promoted and not GameState.family_members.is_empty():
			var m0: Dictionary = GameState.family_members[0]
			m0["age"] = 32
			m0["role"] = "adult"
			m0["scavenge_slots"] = 3
			m0["is_leader"] = true

	selected_index = clampi(selected_index, 0, GameState.family_members.size() - 1)

func _get_selected_member() -> Dictionary:
	_ensure_valid_household()
	return GameState.family_members[selected_index]

func _get_age_perk_summary(age: int, role: String) -> String:
	if role == "child" or age <= 12:
		return "Child (2 Carry Slots) • Light eater, cannot lead 60s scavenge"
	elif role == "teen" or age <= 17:
		return "Teen (2 Carry Slots) • Agile, eligible Scavenge Leader & Scout"
	elif role == "elder" or age >= 60:
		return "Elder (3 Carry Slots) • Wise morale anchor, eligible Leader"
	return "Adult (3 Carry Slots) • Strong carrier, prime Scavenge Leader"

func _get_trait_info(trait_id: String) -> Dictionary:
	for t in TRAIT_LIST:
		if str(t.get("id", "")) == trait_id:
			return t
	return TRAIT_LIST[0]

func _build_preview_member_dict(base_member: Dictionary) -> Dictionary:
	var copy_m: Dictionary = base_member.duplicate(true)
	copy_m["alive"] = true
	copy_m["on_expedition"] = false
	copy_m["hunger"] = 0
	copy_m["thirst"] = 0
	copy_m["sickness"] = 0
	copy_m["injury"] = 0
	copy_m["sanity"] = 0
	copy_m["is_mutant"] = false

	match condition_preview_mode:
		"starving":
			copy_m["hunger"] = 3
			copy_m["thirst"] = 2
		"sick":
			copy_m["sickness"] = 2
			copy_m["injury"] = 1
		"insane":
			copy_m["sanity"] = 3
		"mutant":
			copy_m["is_mutant"] = true
	return copy_m

func _play_sfx(sfx_name: String) -> void:
	if SoundManager != null and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx(sfx_name)

# ==============================================================================
# UI CONSTRUCTION (1280x720 NON-OVERLAPPING DOSSIER LAYOUT)
# ==============================================================================
func _make_stylebox(bg: Color, border: Color, border_w: int = 2, radius: int = 4, pad_h: int = 8, pad_v: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb

func _style_button(btn: Button, bg: Color, fg: Color, border: Color = COL_INK, font_sz: int = 13) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(bg, border, 2, 4, 8, 4))
	btn.add_theme_stylebox_override("hover", _make_stylebox(bg.lightened(0.12), border, 2, 4, 8, 4))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(bg.darkened(0.12), border, 2, 4, 8, 4))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(Color("#333832"), COL_INK, 2, 4, 8, 4))
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_focus_color", fg)
	btn.add_theme_color_override("font_disabled_color", Color("#c5beae"))
	if fg.get_luminance() < 0.25:
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if btn.disabled else Control.CURSOR_POINTING_HAND

func _build_ui() -> void:
	# Header Title Labels
	var title_lbl := Label.new()
	title_lbl.text = "CIVIL DEFENSE FORM CD-60  //  FAMILY SURVIVOR DOSSIER"
	title_lbl.position = Vector2(66, 9)
	title_lbl.size = Vector2(760, 24)
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "CUSTOMIZE AGES, HAIR, OUTFITS & SCAVENGE LEADER BEFORE SELECTING YOUR REAL-WORLD HOUSE"
	sub_lbl.position = Vector2(66, 32)
	sub_lbl.size = Vector2(820, 18)
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", COL_PARCHMENT)
	add_child(sub_lbl)

	# Demo Mode Top Right/Center Banner
	_demo_banner_panel = PanelContainer.new()
	_demo_banner_panel.position = Vector2(760, 9)
	_demo_banner_panel.size = Vector2(502, 38)
	_demo_banner_panel.add_theme_stylebox_override("panel", _make_stylebox(COL_ATOMIC_ORANGE, COL_HAZARD_YELLOW, 2, 4, 10, 4))
	_demo_banner_label = Label.new()
	_demo_banner_label.text = "DEMO: CUSTOMIZING FAMILY AGES, HAIR & LOOKS..."
	_demo_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demo_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_demo_banner_label.add_theme_font_size_override("font_size", 13)
	_demo_banner_label.add_theme_color_override("font_color", Color.WHITE)
	_demo_banner_panel.add_child(_demo_banner_label)
	_demo_banner_panel.visible = GameState.demo_mode
	add_child(_demo_banner_panel)

	# --------------------------------------------------------------------------
	# LEFT COLUMN (x=16, y=64, w=342, h=580): Roster Cards + Add/Remove + Presets
	# --------------------------------------------------------------------------
	var left_panel := PanelContainer.new()
	left_panel.position = Vector2(16, 64)
	left_panel.size = Vector2(342, 580)
	left_panel.add_theme_stylebox_override("panel", _make_stylebox(COL_PARCHMENT_DARK, COL_INK, 3, 5, 10, 10))
	add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 7)
	left_panel.add_child(left_vbox)

	var roster_hdr := Label.new()
	roster_hdr.text = "HOUSEHOLD ROSTER (1-4 SURVIVORS)"
	roster_hdr.add_theme_font_size_override("font_size", 14)
	roster_hdr.add_theme_color_override("font_color", COL_INK)
	roster_hdr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	left_vbox.add_child(roster_hdr)

	_roster_cards_box = VBoxContainer.new()
	_roster_cards_box.add_theme_constant_override("separation", 6)
	_roster_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_roster_cards_box)

	# Add / Remove Member Row
	var add_rem_row := HBoxContainer.new()
	add_rem_row.add_theme_constant_override("separation", 6)
	left_vbox.add_child(add_rem_row)

	_add_member_btn = Button.new()
	_add_member_btn.text = "+ ADD MEMBER"
	_add_member_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_member_btn.custom_minimum_size = Vector2(0, 32)
	_style_button(_add_member_btn, Color("#4b7844"), Color.WHITE, COL_INK, 12)
	_add_member_btn.pressed.connect(_on_add_member_pressed)
	add_rem_row.add_child(_add_member_btn)

	_remove_member_btn = Button.new()
	_remove_member_btn.text = "- REMOVE"
	_remove_member_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remove_member_btn.custom_minimum_size = Vector2(0, 32)
	_style_button(_remove_member_btn, Color("#a83b2c"), Color.WHITE, COL_INK, 12)
	_remove_member_btn.pressed.connect(_on_remove_member_pressed)
	add_rem_row.add_child(_remove_member_btn)

	# Preset Classic / Randomize Household Row
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	left_vbox.add_child(preset_row)

	var classic_btn := Button.new()
	classic_btn.text = "CLASSIC FAMILY"
	classic_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	classic_btn.custom_minimum_size = Vector2(0, 32)
	_style_button(classic_btn, COL_BG_PANEL, COL_PARCHMENT, COL_INK, 11)
	classic_btn.pressed.connect(_on_classic_preset_pressed)
	preset_row.add_child(classic_btn)

	var random_btn := Button.new()
	random_btn.text = "RANDOMIZE HOUSEHOLD"
	random_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_btn.custom_minimum_size = Vector2(0, 32)
	_style_button(random_btn, COL_HAZARD_YELLOW, COL_INK, COL_INK, 11)
	random_btn.pressed.connect(_on_randomize_household_pressed)
	preset_row.add_child(random_btn)

	# --------------------------------------------------------------------------
	# CENTER COLUMN (x=370, y=64, w=396, h=580): Live Portraits + Mini Views + Conditions
	# --------------------------------------------------------------------------
	var center_panel := PanelContainer.new()
	center_panel.position = Vector2(370, 64)
	center_panel.size = Vector2(396, 580)
	center_panel.add_theme_stylebox_override("panel", _make_stylebox(COL_PARCHMENT, COL_INK, 3, 5, 12, 10))
	add_child(center_panel)

	var center_vbox := VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 6)
	center_panel.add_child(center_vbox)

	var prev_hdr := Label.new()
	prev_hdr.text = "PERSONNEL VISUAL INSPECTION"
	prev_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_hdr.add_theme_font_size_override("font_size", 14)
	prev_hdr.add_theme_color_override("font_color", COL_INK)
	prev_hdr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	center_vbox.add_child(prev_hdr)

	_preview_canvas = Control.new()
	_preview_canvas.custom_minimum_size = Vector2(368, 412)
	_preview_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_canvas.draw.connect(_on_draw_preview_stage)
	center_vbox.add_child(_preview_canvas)

	# Age / Carry Slots / Perk summary banner
	var info_box := PanelContainer.new()
	info_box.add_theme_stylebox_override("panel", _make_stylebox(COL_BG_PANEL, COL_INK, 2, 4, 8, 5))
	center_vbox.add_child(info_box)

	_role_perk_label = Label.new()
	_role_perk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role_perk_label.custom_minimum_size = Vector2(340, 36)
	_role_perk_label.add_theme_font_size_override("font_size", 11)
	_role_perk_label.add_theme_color_override("font_color", COL_PARCHMENT)
	info_box.add_child(_role_perk_label)

	var cond_title := Label.new()
	cond_title.text = "CONDITION SIMULATOR (VISUAL PREVIEW ONLY):"
	cond_title.add_theme_font_size_override("font_size", 11)
	cond_title.add_theme_color_override("font_color", COL_INK)
	cond_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	center_vbox.add_child(cond_title)

	var cond_row := HBoxContainer.new()
	cond_row.add_theme_constant_override("separation", 4)
	center_vbox.add_child(cond_row)

	var cond_defs: Array[Dictionary] = [
		{"id": "healthy", "label": "Healthy"},
		{"id": "starving", "label": "Starving"},
		{"id": "sick", "label": "Sick"},
		{"id": "insane", "label": "Insane"},
		{"id": "mutant", "label": "Mutant!"}
	]
	for cd in cond_defs:
		var cid: String = str(cd["id"])
		var cbtn := Button.new()
		cbtn.text = str(cd["label"])
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cbtn.custom_minimum_size = Vector2(0, 30)
		cbtn.pressed.connect(_on_condition_preview_selected.bind(cid))
		cond_row.add_child(cbtn)
		_cond_buttons[cid] = cbtn

	# --------------------------------------------------------------------------
	# RIGHT COLUMN (x=778, y=64, w=486, h=580): Appearance & Bio Controls
	# --------------------------------------------------------------------------
	var right_panel := PanelContainer.new()
	right_panel.position = Vector2(778, 64)
	right_panel.size = Vector2(486, 580)
	right_panel.add_theme_stylebox_override("panel", _make_stylebox(COL_PARCHMENT, COL_INK, 3, 5, 14, 10))
	add_child(right_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right_panel.add_child(rv)

	var edit_hdr := Label.new()
	edit_hdr.text = "BIOGRAPHIC & APPEARANCE RECORD"
	edit_hdr.add_theme_font_size_override("font_size", 14)
	edit_hdr.add_theme_color_override("font_color", COL_INK)
	edit_hdr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	rv.add_child(edit_hdr)

	# Row 1: Name LineEdit + Make Scavenge Leader Button
	var r_name := HBoxContainer.new()
	r_name.add_theme_constant_override("separation", 8)
	rv.add_child(r_name)

	var lbl_name := _make_field_label("NAME:", 68)
	r_name.add_child(lbl_name)

	_name_edit = LineEdit.new()
	_name_edit.max_length = 18
	_name_edit.placeholder_text = "Survivor Name"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(150, 32)
	_name_edit.add_theme_stylebox_override("normal", _make_stylebox(Color("#fbf6ea"), COL_INK, 2, 3, 8, 4))
	_name_edit.add_theme_stylebox_override("focus", _make_stylebox(Color.WHITE, COL_ATOMIC_ORANGE, 2, 3, 8, 4))
	_name_edit.add_theme_color_override("font_color", COL_INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Color("#6e6556"))
	_name_edit.add_theme_color_override("caret_color", COL_INK)
	_name_edit.add_theme_font_size_override("font_size", 14)
	_name_edit.text_changed.connect(_on_name_changed)
	r_name.add_child(_name_edit)

	_leader_btn = Button.new()
	_leader_btn.text = "★ MAKE LEADER"
	_leader_btn.custom_minimum_size = Vector2(168, 32)
	_leader_btn.pressed.connect(_on_make_leader_pressed)
	r_name.add_child(_leader_btn)

	# Row 2: Age Slider (5..85)
	var r_age := HBoxContainer.new()
	r_age.add_theme_constant_override("separation", 8)
	rv.add_child(r_age)

	r_age.add_child(_make_field_label("AGE:", 68))

	_age_slider = HSlider.new()
	_age_slider.min_value = 5.0
	_age_slider.max_value = 85.0
	_age_slider.step = 1.0
	_age_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_age_slider.custom_minimum_size = Vector2(180, 28)
	_age_slider.value_changed.connect(_on_age_slider_changed)
	r_age.add_child(_age_slider)

	_age_value_label = Label.new()
	_age_value_label.custom_minimum_size = Vector2(172, 28)
	_age_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_age_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_age_value_label.add_theme_font_size_override("font_size", 13)
	_age_value_label.add_theme_color_override("font_color", COL_INK)
	_age_value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	r_age.add_child(_age_value_label)

	# Row 3: Perk / Trait Selector + Description
	var trait_box := PanelContainer.new()
	trait_box.add_theme_stylebox_override("panel", _make_stylebox(COL_PARCHMENT_DARK, COL_INK, 2, 4, 8, 5))
	rv.add_child(trait_box)

	var trait_v := VBoxContainer.new()
	trait_v.add_theme_constant_override("separation", 3)
	trait_box.add_child(trait_v)

	var r_trait := HBoxContainer.new()
	r_trait.add_theme_constant_override("separation", 6)
	trait_v.add_child(r_trait)
	r_trait.add_child(_make_field_label("TRAIT:", 62))
	var tr_prev := _make_cycle_btn("<", _on_cycle_trait.bind(-1))
	r_trait.add_child(tr_prev)
	_trait_label = _make_cycle_value_label()
	r_trait.add_child(_trait_label)
	var tr_next := _make_cycle_btn(">", _on_cycle_trait.bind(1))
	r_trait.add_child(tr_next)

	_trait_desc_label = Label.new()
	_trait_desc_label.add_theme_font_size_override("font_size", 11)
	_trait_desc_label.add_theme_color_override("font_color", Color("#2b251e"))
	_trait_desc_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	trait_v.add_child(_trait_desc_label)

	# Row 4: Skin Tone Swatches (6)
	var r_skin := HBoxContainer.new()
	r_skin.add_theme_constant_override("separation", 6)
	rv.add_child(r_skin)
	r_skin.add_child(_make_field_label("SKIN:", 82))
	_skin_swatch_btns.clear()
	for s_idx in range(CharacterArtist.SKIN_TONES.size()):
		var sw := _make_swatch_button(Color(CharacterArtist.SKIN_TONES[s_idx]), Vector2(42, 28))
		sw.pressed.connect(_on_skin_tone_selected.bind(s_idx))
		r_skin.add_child(sw)
		_skin_swatch_btns.append(sw)

	# Row 5: Hair Style Cycle (8 styles)
	var r_hstyle := HBoxContainer.new()
	r_hstyle.add_theme_constant_override("separation", 6)
	rv.add_child(r_hstyle)
	r_hstyle.add_child(_make_field_label("HAIR CUT:", 82))
	r_hstyle.add_child(_make_cycle_btn("<", _on_cycle_hair_style.bind(-1)))
	_hair_style_label = _make_cycle_value_label()
	r_hstyle.add_child(_hair_style_label)
	r_hstyle.add_child(_make_cycle_btn(">", _on_cycle_hair_style.bind(1)))

	# Row 6: Hair Color Swatches (10 vivid & natural colors!)
	var r_hcol := HBoxContainer.new()
	r_hcol.add_theme_constant_override("separation", 5)
	rv.add_child(r_hcol)
	r_hcol.add_child(_make_field_label("HAIR DYE:", 82))
	_hair_color_btns.clear()
	for hex_c in CharacterArtist.HAIR_COLOR_SWATCHES:
		var hb := _make_swatch_button(Color(hex_c), Vector2(32, 28))
		hb.pressed.connect(_on_hair_color_selected.bind(hex_c))
		r_hcol.add_child(hb)
		_hair_color_btns.append(hb)

	# Row 7: Eye Color Swatches (6) + Horn-Rimmed Glasses CheckBox
	var r_eyes := HBoxContainer.new()
	r_eyes.add_theme_constant_override("separation", 5)
	rv.add_child(r_eyes)
	r_eyes.add_child(_make_field_label("EYES:", 82))
	_eye_color_btns.clear()
	for e_hex in CharacterArtist.EYE_COLOR_SWATCHES:
		var eb := _make_swatch_button(Color(e_hex), Vector2(30, 26))
		eb.pressed.connect(_on_eye_color_selected.bind(e_hex))
		r_eyes.add_child(eb)
		_eye_color_btns.append(eb)

	var spacer_e := Control.new()
	spacer_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_eyes.add_child(spacer_e)

	_glasses_check = CheckBox.new()
	_glasses_check.text = "Glasses"
	_glasses_check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_glasses_check.add_theme_stylebox_override("normal", _make_stylebox(Color("#faf5e8"), COL_INK, 2, 4, 8, 4))
	_glasses_check.add_theme_stylebox_override("hover", _make_stylebox(Color("#f5ebcf"), COL_INK, 2, 4, 8, 4))
	_glasses_check.add_theme_stylebox_override("pressed", _make_stylebox(Color("#f2b82e"), COL_INK, 2, 4, 8, 4))
	_glasses_check.add_theme_stylebox_override("hover_pressed", _make_stylebox(Color("#f5c43d"), COL_INK, 2, 4, 8, 4))
	_glasses_check.add_theme_icon_override("checked", ThemeHelper.make_checkbox_icon(true))
	_glasses_check.add_theme_icon_override("unchecked", ThemeHelper.make_checkbox_icon(false))
	_glasses_check.add_theme_color_override("font_color", COL_INK)
	_glasses_check.add_theme_color_override("font_pressed_color", COL_INK)
	_glasses_check.add_theme_color_override("font_hover_color", COL_INK)
	_glasses_check.add_theme_color_override("font_hover_pressed_color", COL_INK)
	_glasses_check.add_theme_color_override("font_focus_color", COL_INK)
	_glasses_check.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_glasses_check.add_theme_font_size_override("font_size", 13)
	_glasses_check.toggled.connect(_on_glasses_toggled)
	r_eyes.add_child(_glasses_check)

	# Row 8: Facial Hair Cycle (0..3)
	var r_beard := HBoxContainer.new()
	r_beard.add_theme_constant_override("separation", 6)
	rv.add_child(r_beard)
	r_beard.add_child(_make_field_label("BEARD:", 82))
	r_beard.add_child(_make_cycle_btn("<", _on_cycle_facial_hair.bind(-1)))
	_facial_hair_label = _make_cycle_value_label()
	r_beard.add_child(_facial_hair_label)
	r_beard.add_child(_make_cycle_btn(">", _on_cycle_facial_hair.bind(1)))

	# Row 9: Outfit Color Swatches (8)
	var r_ocol := HBoxContainer.new()
	r_ocol.add_theme_constant_override("separation", 6)
	rv.add_child(r_ocol)
	r_ocol.add_child(_make_field_label("COLOR:", 82))
	_outfit_color_btns.clear()
	for o_hex in CharacterArtist.OUTFIT_COLOR_SWATCHES:
		var ob := _make_swatch_button(Color(o_hex), Vector2(39, 28))
		ob.pressed.connect(_on_outfit_color_selected.bind(o_hex))
		r_ocol.add_child(ob)
		_outfit_color_btns.append(ob)

	# Row 10: Shirt Style Cycle (0..4)
	var r_shirt := HBoxContainer.new()
	r_shirt.add_theme_constant_override("separation", 6)
	rv.add_child(r_shirt)
	r_shirt.add_child(_make_field_label("OUTFIT:", 82))
	r_shirt.add_child(_make_cycle_btn("<", _on_cycle_shirt_style.bind(-1)))
	_shirt_style_label = _make_cycle_value_label()
	r_shirt.add_child(_shirt_style_label)
	r_shirt.add_child(_make_cycle_btn(">", _on_cycle_shirt_style.bind(1)))

	# Quick Randomize Selected Member Look button at bottom of Right Column
	var rand_one_btn := Button.new()
	rand_one_btn.text = "SHUFFLE THIS SURVIVOR'S LOOK"
	rand_one_btn.custom_minimum_size = Vector2(0, 32)
	_style_button(rand_one_btn, COL_PARCHMENT_DARK, COL_INK, COL_INK, 12)
	rand_one_btn.pressed.connect(_on_shuffle_selected_look)
	rv.add_child(rand_one_btn)

	# --------------------------------------------------------------------------
	# BOTTOM NAVIGATION BAR (y=662..710)
	# --------------------------------------------------------------------------
	var back_btn := Button.new()
	back_btn.text = "< BACK TO TITLE"
	back_btn.position = Vector2(18, 665)
	back_btn.size = Vector2(210, 44)
	_style_button(back_btn, Color("#353b35"), COL_PARCHMENT, COL_PARCHMENT_DARK, 14)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	_footer_summary_label = Label.new()
	_footer_summary_label.position = Vector2(240, 665)
	_footer_summary_label.size = Vector2(490, 44)
	_footer_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_summary_label.add_theme_font_size_override("font_size", 13)
	_footer_summary_label.add_theme_color_override("font_color", COL_PARCHMENT)
	add_child(_footer_summary_label)

	var next_btn := Button.new()
	next_btn.text = "SELECT REAL-WORLD HOUSE ON OPENSTREETMAP >"
	next_btn.position = Vector2(746, 664)
	next_btn.size = Vector2(518, 46)
	_style_button(next_btn, COL_HAZARD_YELLOW, COL_INK, COL_ATOMIC_ORANGE, 15)
	next_btn.pressed.connect(_on_confirm_next_pressed)
	add_child(next_btn)

func _make_field_label(txt: String, min_w: float) -> Label:
	var l := Label.new()
	l.text = txt
	l.custom_minimum_size = Vector2(min_w, 26)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", COL_INK)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l

func _make_cycle_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(36, 30)
	_style_button(b, COL_BG_PANEL, COL_HAZARD_YELLOW, COL_INK, 14)
	b.pressed.connect(cb)
	return b

func _make_cycle_value_label() -> Label:
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(120, 30)
	l.add_theme_stylebox_override("normal", _make_stylebox(Color("#faf5e8"), COL_INK, 1, 3, 6, 3))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", COL_INK)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l

func _make_swatch_button(col: Color, min_sz: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_sz
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_swatch_selected_state(b, col, false)
	return b

func _apply_swatch_selected_state(btn: Button, col: Color, is_sel: bool) -> void:
	var border_col: Color = COL_HAZARD_YELLOW if is_sel else COL_INK
	var bw: int = 3 if is_sel else 2
	btn.add_theme_stylebox_override("normal", _make_stylebox(col, border_col, bw, 4, 2, 2))
	btn.add_theme_stylebox_override("hover", _make_stylebox(col.lightened(0.1), COL_HAZARD_YELLOW, 3, 4, 2, 2))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(col.darkened(0.1), COL_ATOMIC_ORANGE, 3, 4, 2, 2))
	btn.text = "✓" if is_sel else ""
	var lum: float = col.get_luminance()
	var mark_col: Color = COL_INK if lum > 0.52 else Color.WHITE
	btn.add_theme_color_override("font_color", mark_col)
	btn.add_theme_color_override("font_hover_color", mark_col)
	btn.add_theme_font_size_override("font_size", 12)

# ==============================================================================
# ROSTER CARDS & LIVE STAGE RENDERING
# ==============================================================================
func _rebuild_roster_cards() -> void:
	for child in _roster_cards_box.get_children():
		child.queue_free()

	for idx in range(GameState.family_members.size()):
		var card := Button.new()
		card.custom_minimum_size = Vector2(316, 102)
		card.flat = true
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.pressed.connect(_on_roster_card_clicked.bind(idx))
		card.draw.connect(_on_draw_roster_card.bind(card, idx))
		_roster_cards_box.add_child(card)

func _on_draw_roster_card(card: Control, idx: int) -> void:
	if idx < 0 or idx >= GameState.family_members.size():
		return
	var m: Dictionary = GameState.family_members[idx]
	var is_sel: bool = (idx == selected_index)
	var r := Rect2(Vector2.ZERO, card.size)

	var bg_col: Color = Color("#fff9ec") if is_sel else COL_PARCHMENT
	var border_col: Color = COL_ATOMIC_ORANGE if is_sel else COL_INK
	card.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.2), true)
	card.draw_rect(r, bg_col, true)
	card.draw_rect(r, border_col, false, 3.0 if is_sel else 2.0)

	if is_sel:
		card.draw_rect(Rect2(0, 0, 7, r.size.y), COL_ATOMIC_ORANGE, true)

	# Mini Portrait
	var port_rect := Rect2(12, 9, 76, 84)
	CharacterArtist.draw_portrait(card, port_rect, m, true)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var p_name: String = str(m.get("name", "Survivor"))
	var age: int = int(m.get("age", 35))
	var role: String = str(m.get("role", "adult")).to_upper()
	var slots: int = int(m.get("scavenge_slots", 3))
	var is_leader: bool = bool(m.get("is_leader", false))
	var trait_info: Dictionary = _get_trait_info(str(m.get("trait", "handy")))

	card.draw_string(font, Vector2(98, 28), p_name, HORIZONTAL_ALIGNMENT_LEFT, 130, 15, COL_INK)

	if is_leader:
		var badge_r := Rect2(r.size.x - 88, 9, 80, 22)
		card.draw_rect(badge_r, COL_HAZARD_YELLOW, true)
		card.draw_rect(badge_r, COL_INK, false, 1.5)
		card.draw_string(font, Vector2(badge_r.position.x + 2, badge_r.position.y + 15), "★ LEADER", HORIZONTAL_ALIGNMENT_CENTER, badge_r.size.x - 4, 11, COL_INK)

	var meta_line: String = "Age %d • %s • %d Slots" % [age, role, slots]
	card.draw_string(font, Vector2(98, 49), meta_line, HORIZONTAL_ALIGNMENT_LEFT, 210, 12, Color("#3f382e"))

	var perk_line: String = "Trait: " + str(trait_info.get("name", "Handy"))
	card.draw_string(font, Vector2(98, 68), perk_line, HORIZONTAL_ALIGNMENT_LEFT, 210, 12, Color("#24523b"))

	var cap_note: String = "Leads 60s Run!" if is_leader else ("Carry Weight: %d Slots" % slots)
	card.draw_string(font, Vector2(98, 87), cap_note, HORIZONTAL_ALIGNMENT_LEFT, 210, 11, COL_ATOMIC_ORANGE if is_leader else Color("#5c5244"))

func _on_draw_preview_stage() -> void:
	var c: Control = _preview_canvas
	var sz: Vector2 = c.size
	var base_m: Dictionary = _get_selected_member()
	var prev_m: Dictionary = _build_preview_member_dict(base_m)
	var font: Font = ThemeDB.fallback_font

	# 1. Main Large Animated Portrait Frame (centered top)
	var port_w: float = 216.0
	var port_h: float = 236.0
	var port_x: float = (sz.x - port_w) * 0.5
	var port_rect := Rect2(port_x, 4.0, port_w, port_h)
	CharacterArtist.draw_portrait(c, port_rect, prev_m, true)

	# Nameplate Stamp under main portrait
	var plate_rect := Rect2(port_x - 14.0, port_rect.end.y - 12.0, port_w + 28.0, 28.0)
	c.draw_rect(plate_rect, COL_BG_PANEL, true)
	c.draw_rect(plate_rect, COL_HAZARD_YELLOW, false, 2.0)
	if font != null:
		var title_txt: String = "%s (%d, %s)" % [
			str(base_m.get("name", "Survivor")).to_upper(),
			int(base_m.get("age", 35)),
			str(base_m.get("role", "adult")).to_upper()
		]
		c.draw_string(font, Vector2(plate_rect.position.x + 6, plate_rect.position.y + 19), title_txt, HORIZONTAL_ALIGNMENT_CENTER, plate_rect.size.x - 12, 13, COL_HAZARD_YELLOW)

	# 2. Bottom Split Mini-Stages: Left = 60s Top-Down Scavenge, Right = Bunker Seated
	var mini_y: float = 264.0
	var mini_h: float = maxf(138.0, sz.y - mini_y - 4.0)
	var mini_w: float = (sz.x - 12.0) * 0.5

	# Left Mini-Stage: 60s House Floor Tiles + Rotating Walking Top-Down Character
	var td_rect := Rect2(0.0, mini_y, mini_w, mini_h)
	c.draw_rect(td_rect, Color("#d8c8a8"), true)
	# Retro 1950s kitchen checkerboard tiles
	var tile_sz: float = 22.0
	var cols: int = int(td_rect.size.x / tile_sz) + 1
	var rows: int = int(td_rect.size.y / tile_sz) + 1
	for ty in range(rows):
		for tx in range(cols):
			if (tx + ty) % 2 == 0:
				var tr := Rect2(
					td_rect.position.x + float(tx) * tile_sz,
					td_rect.position.y + float(ty) * tile_sz,
					minf(tile_sz, td_rect.end.x - (td_rect.position.x + float(tx) * tile_sz)),
					minf(tile_sz, td_rect.end.y - (td_rect.position.y + float(ty) * tile_sz))
				)
				if tr.size.x > 0.0 and tr.size.y > 0.0:
					c.draw_rect(tr, Color("#c7b491"), true)
	c.draw_rect(td_rect, COL_INK, false, 2.0)

	var facing_ang: float = anim_clock * 1.35
	var facing_vec := Vector2(cos(facing_ang), sin(facing_ang))
	var td_center := Vector2(td_rect.get_center().x, td_rect.get_center().y + 8.0)
	CharacterArtist.draw_topdown_character(c, td_center, facing_vec, prev_m, anim_clock * 7.5, 1.35)

	c.draw_rect(Rect2(td_rect.position.x, td_rect.position.y, td_rect.size.x, 20.0), COL_BG_PANEL, true)
	if font != null:
		c.draw_string(font, td_rect.position + Vector2(4, 14), "60s TOP-DOWN VIEW", HORIZONTAL_ALIGNMENT_CENTER, td_rect.size.x - 8, 10, COL_PARCHMENT)

	# Right Mini-Stage: Bunker Concrete Wall + Wooden Supply Crate + Seated Character
	var bk_rect := Rect2(mini_w + 12.0, mini_y, mini_w, mini_h)
	c.draw_rect(bk_rect, Color("#2a302a"), true)
	c.draw_rect(Rect2(bk_rect.position.x, bk_rect.end.y - 30.0, bk_rect.size.x, 30.0), Color("#1e221e"), true)
	c.draw_line(Vector2(bk_rect.position.x, bk_rect.end.y - 30.0), Vector2(bk_rect.end.x, bk_rect.end.y - 30.0), COL_INK, 2.0)

	# Bunker wooden seat crate
	var seat_pt := Vector2(bk_rect.get_center().x, bk_rect.end.y - 38.0)
	var crate_r := Rect2(seat_pt.x - 26.0, seat_pt.y - 2.0, 52.0, 28.0)
	c.draw_rect(crate_r, Color("#7c5938"), true)
	c.draw_rect(crate_r, COL_INK, false, 2.0)
	c.draw_line(crate_r.position + Vector2(4, 14), Vector2(crate_r.end.x - 4, crate_r.position.y + 14), Color("#593e25"), 1.5)

	CharacterArtist.draw_bunker_seated_character(c, seat_pt, prev_m, anim_clock, 0.92)

	c.draw_rect(bk_rect, COL_INK, false, 2.0)
	c.draw_rect(Rect2(bk_rect.position.x, bk_rect.position.y, bk_rect.size.x, 20.0), COL_BG_PANEL, true)
	if font != null:
		c.draw_string(font, bk_rect.position + Vector2(4, 14), "BUNKER SEATED VIEW", HORIZONTAL_ALIGNMENT_CENTER, bk_rect.size.x - 8, 10, COL_PARCHMENT)

# ==============================================================================
# UI SYNC & INTERACTION CALLBACKS
# ==============================================================================
func _refresh_all_ui() -> void:
	_updating_ui = true
	_ensure_valid_household()
	_rebuild_roster_cards()

	var m: Dictionary = _get_selected_member()
	var age: int = int(m.get("age", 35))
	var role: String = str(m.get("role", "adult"))
	var slots: int = int(m.get("scavenge_slots", 3))
	var is_leader: bool = bool(m.get("is_leader", false))

	if _name_edit.text != str(m.get("name", "")):
		_name_edit.text = str(m.get("name", ""))

	_age_slider.value = float(age)
	_age_value_label.text = "%d yrs • %s (%d Slots)" % [age, role.to_upper(), slots]

	if is_leader:
		_leader_btn.text = "★ SCAVENGE LEADER"
		_leader_btn.disabled = true
		_style_button(_leader_btn, COL_HAZARD_YELLOW, COL_INK, COL_INK, 12)
	elif age < 13:
		_leader_btn.text = "TOO YOUNG (<13)"
		_leader_btn.disabled = true
		_style_button(_leader_btn, Color("#7a7367"), Color("#dfd8ca"), COL_INK, 12)
	else:
		_leader_btn.text = "MAKE SCAVENGE LEADER"
		_leader_btn.disabled = false
		_style_button(_leader_btn, COL_BG_PANEL, COL_HAZARD_YELLOW, COL_INK, 11)

	var t_info: Dictionary = _get_trait_info(str(m.get("trait", "handy")))
	_trait_label.text = str(t_info.get("name", "Handy Mechanic"))
	_trait_desc_label.text = str(t_info.get("desc", ""))

	var h_idx: int = clampi(int(m.get("hair_style", 0)), 0, CharacterArtist.HAIR_STYLE_NAMES.size() - 1)
	_hair_style_label.text = "%s (%d/8)" % [CharacterArtist.HAIR_STYLE_NAMES[h_idx], h_idx + 1]

	var f_idx: int = clampi(int(m.get("facial_hair", 0)), 0, CharacterArtist.FACIAL_HAIR_NAMES.size() - 1)
	_facial_hair_label.text = CharacterArtist.FACIAL_HAIR_NAMES[f_idx]

	var sh_idx: int = clampi(int(m.get("shirt_style", 0)), 0, CharacterArtist.SHIRT_STYLE_NAMES.size() - 1)
	_shirt_style_label.text = CharacterArtist.SHIRT_STYLE_NAMES[sh_idx]

	_glasses_check.button_pressed = bool(m.get("glasses", false))

	# Highlight selected color swatches
	var cur_skin: int = clampi(int(m.get("skin_tone", 1)), 0, CharacterArtist.SKIN_TONES.size() - 1)
	for i in range(_skin_swatch_btns.size()):
		_apply_swatch_selected_state(_skin_swatch_btns[i], Color(CharacterArtist.SKIN_TONES[i]), i == cur_skin)

	var cur_hair_c: String = str(m.get("hair_color", "")).to_lower()
	for i in range(_hair_color_btns.size()):
		var sw_hex: String = CharacterArtist.HAIR_COLOR_SWATCHES[i]
		_apply_swatch_selected_state(_hair_color_btns[i], Color(sw_hex), sw_hex.to_lower() == cur_hair_c)

	var cur_eye_c: String = str(m.get("eye_color", "")).to_lower()
	for i in range(_eye_color_btns.size()):
		var ew_hex: String = CharacterArtist.EYE_COLOR_SWATCHES[i]
		_apply_swatch_selected_state(_eye_color_btns[i], Color(ew_hex), ew_hex.to_lower() == cur_eye_c)

	var cur_out_c: String = str(m.get("outfit_color", "")).to_lower()
	for i in range(_outfit_color_btns.size()):
		var ow_hex: String = CharacterArtist.OUTFIT_COLOR_SWATCHES[i]
		_apply_swatch_selected_state(_outfit_color_btns[i], Color(ow_hex), ow_hex.to_lower() == cur_out_c)

	# Condition simulator button highlight
	for cid in _cond_buttons.keys():
		var cbtn: Button = _cond_buttons[cid]
		var active: bool = (cid == condition_preview_mode)
		if active:
			_style_button(cbtn, COL_ATOMIC_ORANGE, Color.WHITE, COL_INK, 11)
		else:
			_style_button(cbtn, COL_PARCHMENT_DARK, COL_INK, COL_INK, 11)

	_role_perk_label.text = "%s\nACTIVE PERK — %s: %s" % [
		_get_age_perk_summary(age, role),
		str(t_info.get("name", "")).to_upper(),
		str(t_info.get("desc", ""))
	]

	_add_member_btn.disabled = GameState.family_members.size() >= 4
	_add_member_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if _add_member_btn.disabled else Control.CURSOR_POINTING_HAND
	_remove_member_btn.disabled = GameState.family_members.size() <= 1
	_remove_member_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if _remove_member_btn.disabled else Control.CURSOR_POINTING_HAND

	# Footer leader & count summary
	var leader_name: String = "Ted"
	var leader_age: int = 42
	for fm in GameState.family_members:
		if bool(fm.get("is_leader", false)):
			leader_name = str(fm.get("name", "Leader"))
			leader_age = int(fm.get("age", 35))
			break
	_footer_summary_label.text = "SCAVENGE LEADER: %s (%d)   •   SURVIVORS: %d / 4" % [
		leader_name.to_upper(), leader_age, GameState.family_members.size()
	]

	_updating_ui = false
	if _preview_canvas != null:
		_preview_canvas.queue_redraw()

func _emit_family_updated() -> void:
	GameState.family_changed.emit()
	_refresh_all_ui()

func _on_roster_card_clicked(idx: int) -> void:
	selected_index = clampi(idx, 0, GameState.family_members.size() - 1)
	_play_sfx("button_click")
	_refresh_all_ui()

func _on_add_member_pressed() -> void:
	if GameState.family_members.size() >= 4:
		return
	_play_sfx("button_click")
	var new_idx: int = GameState.family_members.size()
	var nm: String = RANDOM_FIRST_NAMES[GameState.rng.randi_range(0, RANDOM_FIRST_NAMES.size() - 1)].strip_edges()
	var age: int = GameState.rng.randi_range(8, 68)
	var role: String = CharacterArtist.get_role_for_age(age)
	var trait_id: String = str(TRAIT_LIST[GameState.rng.randi_range(0, TRAIT_LIST.size() - 1)]["id"])
	var skin: int = GameState.rng.randi_range(0, CharacterArtist.SKIN_TONES.size() - 1)
	var hstyle: int = GameState.rng.randi_range(0, CharacterArtist.HAIR_STYLE_NAMES.size() - 1)
	var hcol: String = CharacterArtist.HAIR_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.HAIR_COLOR_SWATCHES.size() - 1)]
	var ecol: String = CharacterArtist.EYE_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.EYE_COLOR_SWATCHES.size() - 1)]
	var glasses: bool = GameState.rng.randf() < 0.35
	var fhair: int = GameState.rng.randi_range(0, 3) if (age >= 18 and GameState.rng.randf() < 0.35) else 0
	var ocol: String = CharacterArtist.OUTFIT_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.OUTFIT_COLOR_SWATCHES.size() - 1)]
	var sstyle: int = GameState.rng.randi_range(0, CharacterArtist.SHIRT_STYLE_NAMES.size() - 1)

	var new_m: Dictionary = GameState.make_family_member(
		"member_%d" % new_idx, nm, role, age, false, trait_id,
		skin, hstyle, hcol, ecol, glasses, fhair, ocol, sstyle
	)
	GameState.family_members.append(new_m)
	selected_index = new_idx
	_emit_family_updated()

func _on_remove_member_pressed() -> void:
	if GameState.family_members.size() <= 1:
		return
	_play_sfx("button_click")
	GameState.family_members.remove_at(selected_index)
	selected_index = clampi(selected_index, 0, GameState.family_members.size() - 1)
	_ensure_valid_household()
	_emit_family_updated()

func _on_classic_preset_pressed() -> void:
	_play_sfx("page_turn")
	condition_preview_mode = "healthy"
	GameState.init_default_family()
	selected_index = 0
	_emit_family_updated()

func _on_randomize_household_pressed() -> void:
	_play_sfx("page_turn")
	condition_preview_mode = "healthy"
	var count: int = 4
	var used_names: Array[String] = []
	var new_list: Array = []
	for i in range(count):
		var nm: String = RANDOM_FIRST_NAMES[GameState.rng.randi_range(0, RANDOM_FIRST_NAMES.size() - 1)].strip_edges()
		while used_names.has(nm):
			nm = RANDOM_FIRST_NAMES[GameState.rng.randi_range(0, RANDOM_FIRST_NAMES.size() - 1)].strip_edges()
		used_names.append(nm)
		# Guarantee member 0 is adult/teen leader, and mix child/teen/adult/elder across others
		var age: int = 38
		if i == 0:
			age = GameState.rng.randi_range(24, 52)
		elif i == 1:
			age = GameState.rng.randi_range(22, 74)
		elif i == 2:
			age = GameState.rng.randi_range(13, 19)
		else:
			age = GameState.rng.randi_range(6, 76)

		var role: String = CharacterArtist.get_role_for_age(age)
		var trait_id: String = str(TRAIT_LIST[GameState.rng.randi_range(0, TRAIT_LIST.size() - 1)]["id"])
		var skin: int = GameState.rng.randi_range(0, CharacterArtist.SKIN_TONES.size() - 1)
		var hstyle: int = GameState.rng.randi_range(0, CharacterArtist.HAIR_STYLE_NAMES.size() - 1)
		var hcol: String = CharacterArtist.HAIR_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.HAIR_COLOR_SWATCHES.size() - 1)]
		var ecol: String = CharacterArtist.EYE_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.EYE_COLOR_SWATCHES.size() - 1)]
		var glasses: bool = GameState.rng.randf() < 0.4
		var fhair: int = GameState.rng.randi_range(0, 3) if (age >= 19 and GameState.rng.randf() < 0.35) else 0
		var ocol: String = CharacterArtist.OUTFIT_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.OUTFIT_COLOR_SWATCHES.size() - 1)]
		var sstyle: int = GameState.rng.randi_range(0, CharacterArtist.SHIRT_STYLE_NAMES.size() - 1)
		new_list.append(GameState.make_family_member(
			"member_%d" % i, nm, role, age, (i == 0), trait_id,
			skin, hstyle, hcol, ecol, glasses, fhair, ocol, sstyle
		))
	GameState.family_members = new_list
	selected_index = 0
	_emit_family_updated()

func _on_shuffle_selected_look() -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	var age: int = int(m.get("age", 35))
	m["skin_tone"] = GameState.rng.randi_range(0, CharacterArtist.SKIN_TONES.size() - 1)
	m["hair_style"] = GameState.rng.randi_range(0, CharacterArtist.HAIR_STYLE_NAMES.size() - 1)
	m["hair_color"] = CharacterArtist.HAIR_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.HAIR_COLOR_SWATCHES.size() - 1)]
	m["eye_color"] = CharacterArtist.EYE_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.EYE_COLOR_SWATCHES.size() - 1)]
	m["glasses"] = GameState.rng.randf() < 0.45
	m["facial_hair"] = GameState.rng.randi_range(0, 3) if (age >= 18 and GameState.rng.randf() < 0.4) else 0
	m["outfit_color"] = CharacterArtist.OUTFIT_COLOR_SWATCHES[GameState.rng.randi_range(0, CharacterArtist.OUTFIT_COLOR_SWATCHES.size() - 1)]
	m["shirt_style"] = GameState.rng.randi_range(0, CharacterArtist.SHIRT_STYLE_NAMES.size() - 1)
	_emit_family_updated()

func _on_condition_preview_selected(mode: String) -> void:
	condition_preview_mode = mode
	_play_sfx("button_click")
	_refresh_all_ui()

func _on_name_changed(new_text: String) -> void:
	if _updating_ui:
		return
	var m: Dictionary = _get_selected_member()
	var trimmed: String = new_text.strip_edges()
	m["name"] = trimmed if not trimmed.is_empty() else "Survivor"
	GameState.family_changed.emit()
	var age_v: int = int(m.get("age", 35))
	if bool(m.get("is_leader", false)):
		_footer_summary_label.text = "SCAVENGE LEADER: %s (%d)   •   SURVIVORS: %d / 4" % [
			str(m["name"]).to_upper(), age_v, GameState.family_members.size()
		]

func _on_make_leader_pressed() -> void:
	if _updating_ui:
		return
	var m: Dictionary = _get_selected_member()
	if int(m.get("age", 35)) < 13:
		return
	_play_sfx("button_click")
	for i in range(GameState.family_members.size()):
		var fm: Dictionary = GameState.family_members[i]
		fm["is_leader"] = (i == selected_index)
	_emit_family_updated()

func _on_age_slider_changed(val: float) -> void:
	if _updating_ui:
		return
	var m: Dictionary = _get_selected_member()
	var new_age: int = clampi(int(round(val)), 5, 85)

	# If this member is the ONLY eligible >=13 leader in the household, keep them >= 13
	if bool(m.get("is_leader", false)) and new_age < 13:
		var alt_idx: int = -1
		for i in range(GameState.family_members.size()):
			if i != selected_index and int(GameState.family_members[i].get("age", 5)) >= 13:
				alt_idx = i
				break
		if alt_idx >= 0:
			m["is_leader"] = false
			GameState.family_members[alt_idx]["is_leader"] = true
		else:
			new_age = 13

	m["age"] = new_age
	m["role"] = CharacterArtist.get_role_for_age(new_age)
	m["scavenge_slots"] = 2 if new_age < 18 else 3
	if new_age <= 12:
		m["facial_hair"] = 0
	_emit_family_updated()

func _on_cycle_trait(dir: int) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	var cur_id: String = str(m.get("trait", "handy"))
	var idx: int = 0
	for i in range(TRAIT_LIST.size()):
		if str(TRAIT_LIST[i]["id"]) == cur_id:
			idx = i
			break
	idx = posmod(idx + dir, TRAIT_LIST.size())
	m["trait"] = str(TRAIT_LIST[idx]["id"])
	_emit_family_updated()

func _on_skin_tone_selected(tone_idx: int) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	m["skin_tone"] = clampi(tone_idx, 0, CharacterArtist.SKIN_TONES.size() - 1)
	_emit_family_updated()

func _on_cycle_hair_style(dir: int) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	var cur: int = int(m.get("hair_style", 0))
	m["hair_style"] = posmod(cur + dir, CharacterArtist.HAIR_STYLE_NAMES.size())
	_emit_family_updated()

func _on_hair_color_selected(hex_col: String) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	m["hair_color"] = hex_col
	_emit_family_updated()

func _on_eye_color_selected(hex_col: String) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	m["eye_color"] = hex_col
	_emit_family_updated()

func _on_glasses_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	m["glasses"] = pressed
	_emit_family_updated()

func _on_cycle_facial_hair(dir: int) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	var cur: int = int(m.get("facial_hair", 0))
	m["facial_hair"] = posmod(cur + dir, CharacterArtist.FACIAL_HAIR_NAMES.size())
	_emit_family_updated()

func _on_outfit_color_selected(hex_col: String) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	m["outfit_color"] = hex_col
	_emit_family_updated()

func _on_cycle_shirt_style(dir: int) -> void:
	_play_sfx("button_click")
	var m: Dictionary = _get_selected_member()
	var cur: int = int(m.get("shirt_style", 0))
	m["shirt_style"] = posmod(cur + dir, CharacterArtist.SHIRT_STYLE_NAMES.size())
	_emit_family_updated()

func _on_back_pressed() -> void:
	_play_sfx("button_click")
	condition_preview_mode = "healthy"
	GameState.reset_family_runtime_status()
	GameState.request_screen(GameState.SCREEN_TITLE)

func _on_confirm_next_pressed() -> void:
	_play_sfx("page_turn")
	condition_preview_mode = "healthy"
	_ensure_valid_household()
	GameState.reset_family_runtime_status()
	GameState.family_changed.emit()
	GameState.request_screen(GameState.SCREEN_OSM_HOUSE)

# ==============================================================================
# AUTOMATED DEMO SHOWCASE (~3.9s SMOOTH CUSTOMIZATION SEQUENCE)
# ==============================================================================
func _update_demo_mode(delta: float) -> void:
	var speed_mult: float = 5.0 if GameState.headless_fast_test else 1.0
	_demo_elapsed += delta * speed_mult

	if _demo_banner_panel != null:
		_demo_banner_panel.visible = true

	var step: int = int(_demo_elapsed / 0.55)
	if step != _demo_step_idx:
		_demo_step_idx = step
		_apply_demo_step(step)

	if _demo_elapsed >= 3.95 and not _demo_finished:
		_demo_finished = true
		condition_preview_mode = "healthy"
		_ensure_valid_household()
		GameState.reset_family_runtime_status()
		GameState.family_changed.emit()
		GameState.request_screen(GameState.SCREEN_OSM_HOUSE)

func _apply_demo_step(step: int) -> void:
	if GameState.family_members.size() < 4:
		GameState.init_default_family()
	match step:
		0:
			selected_index = 0
			var m0: Dictionary = GameState.family_members[0]
			m0["hair_style"] = 1 # 50s Pompadour
			m0["facial_hair"] = 2 # Full Beard
			m0["shirt_style"] = 4 # Utility Jacket
			m0["trait"] = "sprinter"
			_play_sfx("button_click")
			_emit_family_updated()
		1:
			selected_index = 1
			var m1: Dictionary = GameState.family_members[1]
			m1["hair_style"] = 3 # High Beehive
			m1["hair_color"] = "#e85ca8" # Bubblegum Pink
			m1["glasses"] = true
			m1["age"] = 64 # Show Elder wrinkles & role update!
			m1["role"] = CharacterArtist.get_role_for_age(64)
			_play_sfx("button_click")
			_emit_family_updated()
		2:
			# Restore Dolores to classic vibrant blonde & show Mary Jane customization
			var m1b: Dictionary = GameState.family_members[1]
			m1b["age"] = 39
			m1b["role"] = "adult"
			m1b["hair_color"] = "#d8a438"
			selected_index = 2
			var m2: Dictionary = GameState.family_members[2]
			m2["hair_style"] = 7 # Spiky Punk
			m2["hair_color"] = "#2bc4d8" # Atomic Cyan!
			m2["shirt_style"] = 3 # Ringer Tee
			m2["trait"] = "scout"
			_play_sfx("button_click")
			_emit_family_updated()
		3:
			# Preview Mutant! visual simulator briefly
			condition_preview_mode = "mutant"
			_play_sfx("button_click")
			_refresh_all_ui()
		4:
			# Preview Insane tinfoil hat visual simulator briefly
			condition_preview_mode = "insane"
			_play_sfx("button_click")
			_refresh_all_ui()
		5:
			# Customize Timmy (child) & restore Healthy condition
			condition_preview_mode = "healthy"
			selected_index = 3
			var m3: Dictionary = GameState.family_members[3]
			m3["hair_style"] = 5 # Voluminous Curly
			m3["hair_color"] = "#e06d2b" # Ginger Orange
			m3["glasses"] = true
			m3["age"] = 9
			m3["role"] = "child"
			m3["scavenge_slots"] = 2
			_play_sfx("button_click")
			_emit_family_updated()
		6:
			selected_index = 0
			condition_preview_mode = "healthy"
			_refresh_all_ui()
