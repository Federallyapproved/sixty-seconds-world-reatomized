class_name SummaryScreen
extends Control

## Post-Game Civil Defense Survival Dossier Screen (1280x720).
## Displays Victory vs Perished rubber stamp, ending_title, ending_description,
## Days Survived, Selected OSM House address & footprint, Nuke Ground Zero
## distance & telemetry, Family final portraits via CharacterArtist.draw_portrait,
## and [ PLAY AGAIN ] / [ RETURN TO TITLE ] actions.

var _anim_time: float = 0.0
var _stamp_canvas: Control = null
var _transitioning: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = ThemeHelper.get_game_theme()

	_build_dossier_ui()

	if GameState.victory:
		SoundManager.play_sfx("victory")
	else:
		SoundManager.play_sfx("gameover")

func _process(delta: float) -> void:
	_anim_time += delta
	if _stamp_canvas != null and _anim_time < 0.5:
		_stamp_canvas.set("anim_t", _anim_time)
		_stamp_canvas.queue_redraw()

func _build_dossier_ui() -> void:
	var is_victory: bool = GameState.victory

	var end_title: String = GameState.ending_title.strip_edges()
	if end_title.is_empty():
		if is_victory:
			end_title = "CIVIL DEFENSE EXTRACTION SUCCESSFUL"
		else:
			end_title = "SHELTER PROTOCOL TERMINATED — LOST IN THE FALLOUT"

	var end_desc: String = GameState.ending_description.strip_edges()
	if end_desc.is_empty():
		if is_victory:
			end_desc = "Against overwhelming atomic odds beneath their real-world neighborhood shelter, the family rationed supplies, answered rescue transmissions, and emerged alive."
		else:
			end_desc = "Radio contact ceased from the fallout shelter beneath the residence. Civil Defense recovery teams logged this dossier as final record of their stand."

	# --- 1. TOP HEADER ROW (y = 50..178) ---
	# Left: Days Survived Badge Card
	var days_card := ThemeHelper.make_card_panel(
		Color("#212621"),
		Color("#7ec850") if is_victory else ThemeHelper.COLOR_ATOMIC_ORANGE
	)
	days_card.position = Vector2(68.0, 50.0)
	days_card.size = Vector2(184.0, 128.0)
	add_child(days_card)

	var days_vbox := VBoxContainer.new()
	days_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	days_vbox.add_theme_constant_override("separation", 2)
	days_card.add_child(days_vbox)

	var days_cap := Label.new()
	days_cap.text = "DAYS SURVIVED"
	days_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_cap.add_theme_font_size_override("font_size", 12)
	days_cap.add_theme_color_override("font_color", Color("#dccba6"))
	days_vbox.add_child(days_cap)

	var days_num := Label.new()
	days_num.text = "%d" % maxi(1, GameState.day)
	days_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_num.add_theme_font_size_override("font_size", 40)
	days_num.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	days_vbox.add_child(days_num)

	var rations_lbl := Label.new()
	var soup_str: String = GameState.format_quarters_as_cans(GameState.soup_quarters)
	var water_str: String = GameState.format_quarters_as_cans(GameState.water_quarters)
	rations_lbl.text = "SOUP: %s  •  H2O: %s" % [soup_str, water_str]
	rations_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rations_lbl.add_theme_font_size_override("font_size", 11)
	rations_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
	days_vbox.add_child(rations_lbl)

	# Center: Ending Title & Description on Parchment Dossier
	var narrative_box := VBoxContainer.new()
	narrative_box.position = Vector2(268.0, 50.0)
	narrative_box.size = Vector2(656.0, 128.0)
	narrative_box.add_theme_constant_override("separation", 5)
	add_child(narrative_box)

	var dossier_code := Label.new()
	dossier_code.text = "FORM CD-60  •  OFFICIAL CIVIL DEFENSE AFTER-ACTION SURVIVAL REPORT"
	dossier_code.add_theme_font_size_override("font_size", 11)
	dossier_code.add_theme_color_override("font_color", Color("#6b5d47"))
	dossier_code.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	narrative_box.add_child(dossier_code)

	var title_lbl := Label.new()
	title_lbl.text = end_title.to_upper()
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.max_lines_visible = 2
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color("#1e5c26") if is_victory else Color("#a62b17"))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	narrative_box.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = end_desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.max_lines_visible = 4
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_INK)
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	narrative_box.add_child(desc_lbl)

	# Right: Procedural Victory vs Perished Rubber Stamp
	_stamp_canvas = _OutcomeStampCanvas.new()
	_stamp_canvas.set("victory", is_victory)
	_stamp_canvas.set("days_count", maxi(1, GameState.day))
	_stamp_canvas.position = Vector2(936.0, 48.0)
	_stamp_canvas.size = Vector2(274.0, 130.0)
	_stamp_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamp_canvas)

	# --- 2. MIDDLE INTELLIGENCE ROW (y = 190..350, 562px each with 16px gap) ---
	_build_osm_house_card(Rect2(68.0, 190.0, 562.0, 160.0))
	_build_nuke_telemetry_card(Rect2(646.0, 190.0, 562.0, 160.0))

	# --- 3. FAMILY FINAL PORTRAITS ROSTER (y = 364..600) ---
	_build_family_roster(Rect2(68.0, 364.0, 1140.0, 236.0))

	# --- 4. ACTION BUTTONS (y = 614..664) ---
	var btn_bar := HBoxContainer.new()
	btn_bar.position = Vector2(68.0, 616.0)
	btn_bar.size = Vector2(1142.0, 48.0)
	btn_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_bar.add_theme_constant_override("separation", 24)
	add_child(btn_bar)

	var btn_play_again := ThemeHelper.make_hazard_button("[ PLAY AGAIN ]", Vector2(270.0, 46.0))
	btn_play_again.pressed.connect(_on_play_again_pressed)
	btn_bar.add_child(btn_play_again)

	var btn_title := Button.new()
	btn_title.text = "[ RETURN TO TITLE ]"
	btn_title.custom_minimum_size = Vector2(270.0, 46.0)
	btn_title.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_title.pressed.connect(_on_return_to_title_pressed)
	btn_bar.add_child(btn_title)

static func _format_building_type(raw_type: String) -> String:
	var key: String = raw_type.strip_edges().to_lower()
	match key:
		"", "yes", "residential":
			return "RESIDENCE"
		"house":
			return "HOUSE"
		"semidetached_house", "semi", "duplex":
			return "DUPLEX"
		"terrace", "row_house", "townhouse":
			return "ROWHOUSE"
		"apartments", "flats", "dormitory":
			return "APARTMENTS"
		"detached":
			return "DETACHED HOUSE"
		"bungalow":
			return "BUNGALOW"
		"cabin":
			return "CABIN"
		"farm":
			return "FARMHOUSE"
		_:
			return key.replace("_", " ").to_upper()

func _build_osm_house_card(rect: Rect2) -> void:
	var card := ThemeHelper.make_card_panel(Color("#232823"), Color("#8c7b54"))
	card.position = rect.position
	card.size = rect.size
	card.clip_contents = true
	add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var fp_ctrl := _HouseFootprintCanvas.new()
	var fp_pts: Array = GameState.selected_house.get("footprint_meters", [])
	fp_ctrl.set("footprint_points", fp_pts)
	fp_ctrl.custom_minimum_size = Vector2(114.0, 128.0)
	hbox.add_child(fp_ctrl)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var hdr := Label.new()
	hdr.text = "SELECTED OPENSTREETMAP HOUSE"
	hdr.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	info_vbox.add_child(hdr)

	var house_addr: String = str(GameState.selected_house.get("address", ""))
	if house_addr.strip_edges().is_empty():
		house_addr = str(GameState.selected_house.get("name", "518 E Roy St, Capitol Hill, Seattle, WA"))

	var addr_lbl := Label.new()
	addr_lbl.text = house_addr
	addr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	addr_lbl.max_lines_visible = 2
	addr_lbl.add_theme_font_size_override("font_size", 14)
	addr_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
	info_vbox.add_child(addr_lbl)

	var area_sqm: float = float(GameState.selected_house.get("area_sqm", 180.0))
	var bldg_type: String = _format_building_type(str(GameState.selected_house.get("building_type", "house")))
	var h_lat: float = float(GameState.selected_house.get("lat", 47.6242))
	var h_lon: float = float(GameState.selected_house.get("lon", -122.3195))

	var meta_lbl := Label.new()
	meta_lbl.text = "TYPE: %s  •  %.0f m²  •  GPS: %.4f, %.4f" % [bldg_type, area_sqm, h_lat, h_lon]
	meta_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_lbl.add_theme_font_size_override("font_size", 12)
	meta_lbl.add_theme_color_override("font_color", Color("#dccba6"))
	info_vbox.add_child(meta_lbl)

	var items_col: int = int(GameState.scavenge_stats.get("items_collected", 0))
	var fam_saved: int = int(GameState.scavenge_stats.get("family_saved", 0))
	var scav_lbl := Label.new()
	scav_lbl.text = "60s SCAVENGE HAUL: %d Supplies Secured  •  %d Family Evacuated" % [items_col, fam_saved]
	scav_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	scav_lbl.add_theme_font_size_override("font_size", 12)
	scav_lbl.add_theme_color_override("font_color", Color("#9fd878"))
	info_vbox.add_child(scav_lbl)

func _build_nuke_telemetry_card(rect: Rect2) -> void:
	var card := ThemeHelper.make_card_panel(Color("#232823"), Color("#b85d38"))
	card.position = rect.position
	card.size = rect.size
	card.clip_contents = true
	add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var dist_km: float = float(GameState.nuke_config.get("distance_km", 2.78))
	var radar_ctrl := _GroundZeroMiniCanvas.new()
	radar_ctrl.set("distance_km", dist_km)
	radar_ctrl.custom_minimum_size = Vector2(114.0, 128.0)
	radar_ctrl.clip_contents = true
	hbox.add_child(radar_ctrl)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var hdr := Label.new()
	hdr.text = "NUCLEAR DETONATION & GROUND ZERO IMPACT"
	hdr.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_ATOMIC_ORANGE)
	info_vbox.add_child(hdr)

	var dist_lbl := Label.new()
	dist_lbl.text = "GROUND ZERO DISTANCE: %.2f km" % dist_km
	dist_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dist_lbl.add_theme_font_size_override("font_size", 15)
	dist_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	info_vbox.add_child(dist_lbl)

	var target_name: String = str(GameState.nuke_config.get("target_name", "Strategic Target"))
	var target_lbl := Label.new()
	target_lbl.text = "STRIKE POINT: %s" % target_name
	target_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_lbl.max_lines_visible = 2
	target_lbl.add_theme_font_size_override("font_size", 12)
	target_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
	info_vbox.add_child(target_lbl)

	var yield_kt: int = int(GameState.nuke_config.get("yield_kt", 800))
	var yield_str: String = ("%d Mt" % (yield_kt / 1000)) if yield_kt >= 1000 else ("%d kt" % yield_kt)
	var zone_str: String = str(GameState.nuke_config.get("zone", "fallout_plume")).replace("_", " ").to_upper()
	var sv_hr: float = float(GameState.nuke_config.get("initial_sv_hr", GameState.surface_radiation_sv))

	var phys_lbl := Label.new()
	phys_lbl.text = "YIELD: %s  •  ZONE: %s  •  DOSE RATE AT H+1: %s" % [yield_str, zone_str, RadiationModel.format_rate(sv_hr * 1000.0)]
	phys_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	phys_lbl.add_theme_font_size_override("font_size", 12)
	phys_lbl.add_theme_color_override("font_color", Color("#dccba6"))
	info_vbox.add_child(phys_lbl)

	var companions: Array[String] = []
	if GameState.has_cat_sharikov:
		companions.append("Sharikov (Cat)")
	if GameState.has_dog_pancake:
		companions.append("Pancake (Dog)")
	var comp_suffix: String = ("  •  PETS: " + ", ".join(companions)) if not companions.is_empty() else ""
	var bunker_lbl := Label.new()
	bunker_lbl.text = "SHELTER INTEGRITY: %.0f%%%s" % [GameState.bunker_structural_integrity, comp_suffix]
	bunker_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bunker_lbl.add_theme_font_size_override("font_size", 12)
	bunker_lbl.add_theme_color_override("font_color", Color("#9fd878") if GameState.bunker_structural_integrity >= 50.0 else ThemeHelper.COLOR_ATOMIC_ORANGE)
	info_vbox.add_child(bunker_lbl)

func _build_family_roster(rect: Rect2) -> void:
	var outer := VBoxContainer.new()
	outer.position = rect.position
	outer.size = rect.size
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)

	var sec_hdr := Label.new()
	sec_hdr.text = "FAMILY PERSONNEL FINAL DOSSIER PORTRAITS"
	sec_hdr.add_theme_font_size_override("font_size", 14)
	sec_hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_INK)
	sec_hdr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	outer.add_child(sec_hdr)

	var cards_row := HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 12)
	outer.add_child(cards_row)

	var members: Array = GameState.family_members
	if members.is_empty():
		GameState.init_default_family()
		members = GameState.family_members

	for raw_m in members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		cards_row.add_child(_make_member_card(m))

func _make_member_card(member: Dictionary) -> PanelContainer:
	var alive: bool = bool(member.get("alive", true))
	var in_bunker: bool = bool(member.get("in_bunker", true))
	var is_mutant: bool = bool(member.get("is_mutant", false))
	var on_exp: bool = bool(member.get("on_expedition", false))
	var run_ended: bool = GameState.game_over or GameState.victory or GameState.day > 1

	var status_text := "SURVIVED"
	var status_col := Color("#7ec850")
	var border_col := Color("#6a7a5c")

	if not alive:
		status_text = "DECEASED"
		status_col = Color("#e05a2b")
		border_col = Color("#943c24")
	elif run_ended and not in_bunker:
		status_text = "LEFT OUTSIDE"
		status_col = Color("#e09b2b")
		border_col = Color("#8f6a24")
	elif on_exp and not GameState.victory:
		status_text = "MISSING IN WASTELAND"
		status_col = Color("#e09b2b")
		border_col = Color("#8f6a24")
	elif is_mutant:
		status_text = "MUTANT SURVIVOR"
		status_col = Color("#8be846")
		border_col = Color("#6fb83b")

	var card := ThemeHelper.make_card_panel(Color("#222722"), border_col)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var portrait_ctrl := _MemberPortraitCanvas.new()
	portrait_ctrl.set("member_dict", member)
	portrait_ctrl.custom_minimum_size = Vector2(102.0, 128.0)
	portrait_ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(portrait_ctrl)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var m_name: String = str(member.get("name", "Survivor"))
	var is_leader: bool = bool(member.get("is_leader", false))
	var name_lbl := Label.new()
	name_lbl.text = ("%s ★" % m_name) if is_leader else m_name
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW if is_leader else ThemeHelper.COLOR_PARCHMENT)
	vbox.add_child(name_lbl)

	var role_str: String = str(member.get("role", "adult")).to_upper()
	var age_val: int = int(member.get("age", 30))
	var role_lbl := Label.new()
	role_lbl.text = "%s  •  AGE %d" % [role_str, age_val]
	role_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", Color("#b8b09c"))
	vbox.add_child(role_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = "● " + status_text
	badge_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.add_theme_color_override("font_color", status_col)
	vbox.add_child(badge_lbl)

	var detail_str: String = str(member.get("death_reason", "")).strip_edges()
	if detail_str.is_empty():
		if run_ended and alive and not in_bunker:
			detail_str = "Did not reach the bunker hatch before detonation."
		else:
			detail_str = str(member.get("status_note", "Recorded in shelter log."))
	var note_lbl := Label.new()
	note_lbl.text = detail_str
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.max_lines_visible = 3
	note_lbl.add_theme_font_size_override("font_size", 11)
	note_lbl.add_theme_color_override("font_color", Color("#dccba6"))
	vbox.add_child(note_lbl)

	return card

func _on_play_again_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = false
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_FAMILY)

func _on_return_to_title_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = false
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_TITLE)

func _draw() -> void:
	var vp: Vector2 = size
	if vp.x < 100.0 or vp.y < 100.0:
		vp = Vector2(1280.0, 720.0)
	var font: Font = ThemeDB.fallback_font

	# Outer Bunker Desk Backdrop
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#161916"), true)
	draw_circle(Vector2(vp.x * 0.5, vp.y * 0.5), 620.0, Color(0.22, 0.24, 0.19, 0.45))

	# Top & Bottom Hazard Stripes
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, 0.0, vp.x, 18.0), 16.0)
	ThemeHelper.draw_hazard_stripes(self, Rect2(0.0, vp.y - 18.0, vp.x, 18.0), 16.0)

	# Manilla / Aged Parchment Civil Defense Dossier Sheet (continuous tab + folder border)
	var folder_shadow := Rect2(50.0, 42.0, vp.x - 92.0, vp.y - 72.0)
	draw_rect(folder_shadow, Color(0.0, 0.0, 0.0, 0.45), true)

	var folder_rect := Rect2(44.0, 36.0, vp.x - 88.0, vp.y - 72.0)
	var tab_rect := Rect2(56.0, 15.0, 320.0, 21.0)
	draw_rect(folder_rect, Color("#efe3c8"), true)
	draw_rect(Rect2(tab_rect.position, tab_rect.size + Vector2(0.0, 1.0)), Color("#dccba6"), true)
	draw_rect(folder_rect.grow(-5.0), Color("#c9b68f"), false, 1.2)

	# Continuous ink outline around folder + raised tab (top border starts at x = 376.0, never slicing tab text!)
	var perimeter := PackedVector2Array([
		Vector2(folder_rect.position.x, folder_rect.position.y),
		Vector2(tab_rect.position.x, folder_rect.position.y),
		Vector2(tab_rect.position.x, tab_rect.position.y),
		Vector2(tab_rect.end.x, tab_rect.position.y),
		Vector2(tab_rect.end.x, folder_rect.position.y),
		Vector2(folder_rect.end.x, folder_rect.position.y),
		Vector2(folder_rect.end.x, folder_rect.end.y),
		Vector2(folder_rect.position.x, folder_rect.end.y),
		Vector2(folder_rect.position.x, folder_rect.position.y)
	])
	draw_polyline(perimeter, ThemeHelper.COLOR_INK, 2.5)
	draw_string(font, Vector2(68.0, 30.0), "DOSSIER FILE #CD-1958-REATOMIZED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ThemeHelper.COLOR_INK)

	# Subtle ledger horizontal rules across top narrative section
	for line_y in [86.0, 108.0, 130.0, 152.0, 174.0]:
		draw_line(Vector2(264.0, line_y), Vector2(928.0, line_y), Color(0.55, 0.48, 0.36, 0.18), 1.0)

	# Divider rules between dossier sections
	draw_line(Vector2(66.0, 184.0), Vector2(vp.x - 66.0, 184.0), Color("#8c7b58"), 1.5)
	draw_line(Vector2(66.0, 358.0), Vector2(vp.x - 66.0, 358.0), Color("#8c7b58"), 1.5)
	draw_line(Vector2(66.0, 608.0), Vector2(vp.x - 66.0, 608.0), Color("#8c7b58"), 1.5)


class _OutcomeStampCanvas extends Control:
	var victory: bool = false
	var days_count: int = 1
	var anim_t: float = 1.0

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var center: Vector2 = size * 0.5
		var pop_scale: float = lerpf(1.10, 1.0, clampf(anim_t / 0.22, 0.0, 1.0))

		var ink_col: Color = Color("#1e6e2b") if victory else Color("#b82918")
		var fill_tint: Color = Color(0.16, 0.52, 0.22, 0.10) if victory else Color(0.78, 0.18, 0.10, 0.10)
		var main_txt: String = "★ VICTORY: SURVIVED ★" if victory else "✖ PERISHED IN FALLOUT ✖"
		var sub_txt: String = ("EXTRACTED ON DAY %d" % days_count) if victory else ("LOST ON DAY %d" % days_count)

		draw_set_transform(center, -0.14, Vector2(pop_scale, pop_scale))
		var outer_r := Rect2(-124.0, -44.0, 248.0, 88.0)
		var inner_r := outer_r.grow(-5.0)
		draw_rect(outer_r, fill_tint, true)
		draw_rect(outer_r, ink_col, false, 3.5)
		draw_rect(inner_r, ink_col, false, 1.5)

		var m_sz: Vector2 = font.get_string_size(main_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, Vector2(-m_sz.x * 0.5, -6.0), main_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink_col)

		draw_line(Vector2(-104.0, 4.0), Vector2(104.0, 4.0), ink_col, 1.2)

		var s_sz: Vector2 = font.get_string_size(sub_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(font, Vector2(-s_sz.x * 0.5, 22.0), sub_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class _HouseFootprintCanvas extends Control:
	var footprint_points: Array = []

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color("#152028"), true)
		# Blueprint grid lines
		var gx: float = 16.0
		while gx < size.x:
			draw_line(Vector2(gx, 0.0), Vector2(gx, size.y), Color(0.32, 0.58, 0.78, 0.16), 1.0)
			gx += 16.0
		var gy: float = 16.0
		while gy < size.y:
			draw_line(Vector2(0.0, gy), Vector2(size.x, gy), Color(0.32, 0.58, 0.78, 0.16), 1.0)
			gy += 16.0
		draw_rect(box, Color("#4c7c9c"), false, 1.5)

		var pts := PackedVector2Array()
		for p in footprint_points:
			if p is Vector2:
				pts.append(p)
		if pts.size() < 3:
			pts = PackedVector2Array([
				Vector2(-6.0, -5.0), Vector2(6.0, -5.0),
				Vector2(6.0, 5.0), Vector2(-6.0, 5.0)
			])

		var min_v: Vector2 = pts[0]
		var max_v: Vector2 = pts[0]
		for v in pts:
			min_v.x = minf(min_v.x, v.x)
			min_v.y = minf(min_v.y, v.y)
			max_v.x = maxf(max_v.x, v.x)
			max_v.y = maxf(max_v.y, v.y)

		var span := Vector2(maxf(1.0, max_v.x - min_v.x), maxf(1.0, max_v.y - min_v.y))
		var avail: Vector2 = size - Vector2(26.0, 26.0)
		var sc: float = minf(avail.x / span.x, avail.y / span.y)
		var mid: Vector2 = (min_v + max_v) * 0.5
		var center: Vector2 = size * 0.5

		var fill_poly := PackedVector2Array()
		for v in pts:
			var pt: Vector2 = center + (v - mid) * sc
			if fill_poly.is_empty() or fill_poly[fill_poly.size() - 1].distance_to(pt) > 0.25:
				fill_poly.append(pt)

		if fill_poly.size() >= 3:
			var tris: PackedInt32Array = Geometry2D.triangulate_polygon(fill_poly)
			if not tris.is_empty():
				draw_colored_polygon(fill_poly, Color(0.95, 0.74, 0.18, 0.28))
			var outline := PackedVector2Array(fill_poly)
			outline.append(fill_poly[0])
			draw_polyline(outline, ThemeHelper.COLOR_HAZARD_YELLOW, 2.0, true)
		draw_circle(center, 4.0, ThemeHelper.COLOR_ATOMIC_ORANGE)


class _GroundZeroMiniCanvas extends Control:
	var distance_km: float = 3.0

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color("#191715"), true)
		draw_rect(box, Color("#96472a"), false, 1.5)

		var gz := Vector2(size.x * 0.38, size.y * 0.54)
		for r in [16.0, 32.0, 48.0]:
			draw_arc(gz, r, 0.0, TAU, 32, Color(0.88, 0.35, 0.17, 0.38), 1.2, true)
		draw_circle(gz, 5.0, ThemeHelper.COLOR_ATOMIC_ORANGE)

		var norm_d: float = clampf(log(1.0 + distance_km) / log(51.0), 0.18, 0.95)
		var house_pos: Vector2 = gz + Vector2(0.82, -0.52).normalized() * (norm_d * 52.0)
		draw_line(gz, house_pos, Color(0.95, 0.74, 0.18, 0.65), 1.4, true)
		draw_circle(house_pos, 4.5, Color("#7ec850"))
		draw_arc(house_pos, 4.5, 0.0, TAU, 16, ThemeHelper.COLOR_INK, 1.2)


class _MemberPortraitCanvas extends Control:
	var member_dict: Dictionary = {}

	func _draw() -> void:
		var p_rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
		CharacterArtist.draw_portrait(self, p_rect, member_dict, true)
