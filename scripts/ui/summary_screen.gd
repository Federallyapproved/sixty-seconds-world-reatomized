class_name SummaryScreen
extends Control

## Post-Game Civil Defense Survival Dossier Screen (1280x720) — V2 Overhaul.
## Records persistent meta-progression via SaveManager, clears completed saved runs,
## and displays Outcome & Ending Route Stamp, Multi-Run Station Wagon Chassis Tier
## Progress, OSM House & Nuke Telemetry, Family Final Portraits with Pairwise
## Relationship Tiers & Survival/Betrayal/Left-Behind Notes, and Play Again / Title actions.

var _anim_time: float = 0.0
var _stamp_canvas: Control = null
var _transitioning: bool = false
var _chassis_result: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = ThemeHelper.get_game_theme()

	if not GameState.demo_mode:
		var should_clear_save: bool = _is_finished_saved_run()
		_chassis_result = SaveManager.record_run_completion(
			int(GameState.run_metrics.get("vehicle_parts_scavenged", 0)),
			GameState.ending_route == "vehicle_breakout",
			GameState.victory,
			GameState.day,
			int(GameState.scavenge_stats.get("items_collected", 0))
		)
		if should_clear_save:
			SaveManager.clear_saved_run()
	else:
		var cur_tier: int = SaveManager.get_vehicle_chassis_tier()
		_chassis_result = {"prev_tier": cur_tier, "new_tier": cur_tier, "upgraded": false}

	_build_dossier_ui()

	if GameState.victory:
		SoundManager.play_sfx("victory")
		if GameState.ending_route == "vehicle_breakout":
			SoundManager.play_sfx("engine_start", -3.0)
		elif bool(_chassis_result.get("upgraded", false)):
			SoundManager.play_sfx("achievement", -2.5)
	else:
		SoundManager.play_sfx("gameover")
		if bool(_chassis_result.get("upgraded", false)):
			SoundManager.play_sfx("achievement", -3.5)

func _is_finished_saved_run() -> bool:
	if not SaveManager.has_saved_run():
		return false
	if bool(GameState.story_flags.get("loaded_from_save", false)):
		return true
	if not (GameState.game_over or GameState.victory):
		return false
	if GameState.game_mode == "scavenge_drill":
		return false

	var f: FileAccess = FileAccess.open(SaveManager.SAVE_RUN_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed
	var saved_house_v: Variant = d.get("selected_house", {})
	if saved_house_v is Dictionary:
		var sh: Dictionary = saved_house_v
		var saved_osm: int = int(sh.get("osm_id", -1))
		var cur_osm: int = int(GameState.selected_house.get("osm_id", -2))
		var saved_addr: String = str(sh.get("address", ""))
		var cur_addr: String = str(GameState.selected_house.get("address", ""))
		if (saved_osm > 0 and saved_osm == cur_osm) or (saved_addr != "" and saved_addr == cur_addr):
			return true
	return false

func _process(delta: float) -> void:
	_anim_time += delta
	if _stamp_canvas != null and _anim_time < 0.5:
		_stamp_canvas.set("anim_t", _anim_time)
		_stamp_canvas.queue_redraw()

static func _format_ending_route_stamp(route_id: String, is_victory: bool) -> String:
	var key: String = route_id.strip_edges().to_lower()
	match key:
		"vehicle_breakout", "vehicle", "station_wagon":
			return "ROUTE: STATION WAGON BREAKOUT"
		"military", "military_evac":
			return "ROUTE: U.S. MILITARY EXTRACTION"
		"sanctuary", "parish", "church":
			return "ROUTE: OSM PARISH SANCTUARY"
		"scientist", "vault", "sharikov":
			return "ROUTE: VAULT INSTITUTE & SHARIKOV"
		"raider_pact", "convoy", "smuggler":
			return "ROUTE: WASTELAND CONVOY PACT"
		"":
			return "ROUTE: CIVIL DEFENSE EXTRACTION" if is_victory else "OUTCOME: SHELTER PROTOCOL LOST"
		_:
			var label_up: String = key.replace("_", " ").to_upper()
			return ("ROUTE: " + label_up) if is_victory else ("CAUSE: " + label_up)

static func _format_garage_tier_headline(tier: int, upgraded: bool) -> String:
	var prefix: String = "★ TIER UPGRADED! " if upgraded else ""
	match clampi(tier, 0, 3):
		1:
			return prefix + "GARAGE CHASSIS TIER 1/3 — 12V Battery Pre-Installed Next Run!"
		2:
			return prefix + "GARAGE CHASSIS TIER 2/3 — Battery & Hose Pre-Installed Next Run!"
		3:
			return prefix + "GARAGE CHASSIS TIER 3/3 — Battery, Hose & Fuel Can Pre-Installed Next Run!"
		_:
			return "GARAGE CHASSIS TIER 0/3 — Bare Frame (Bank 2+ Engine Parts for Tier 1 Battery!)"

func _build_dossier_ui() -> void:
	var is_victory: bool = GameState.victory
	var route_stamp_str: String = _format_ending_route_stamp(GameState.ending_route, is_victory)

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

	# --- 1. TOP HEADER ROW (y = 46..166) ---
	var days_card := ThemeHelper.make_card_panel(
		Color("#212621"),
		Color("#7ec850") if is_victory else ThemeHelper.COLOR_ATOMIC_ORANGE
	)
	days_card.position = Vector2(68.0, 46.0)
	days_card.size = Vector2(184.0, 120.0)
	add_child(days_card)

	var days_vbox := VBoxContainer.new()
	days_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	days_vbox.add_theme_constant_override("separation", 1)
	days_card.add_child(days_vbox)

	var days_cap := Label.new()
	days_cap.text = "DAYS SURVIVED"
	days_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_cap.add_theme_font_size_override("font_size", 11)
	days_cap.add_theme_color_override("font_color", Color("#dccba6"))
	days_vbox.add_child(days_cap)

	var days_num := Label.new()
	days_num.text = "%d" % maxi(1, GameState.day)
	days_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	days_num.add_theme_font_size_override("font_size", 36)
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

	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	var diff_lbl := Label.new()
	diff_lbl.text = str(diff_cfg.get("label", "FAT MAN"))
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	diff_lbl.add_theme_font_size_override("font_size", 10)
	diff_lbl.add_theme_color_override("font_color", Color("#9fd878") if is_victory else Color("#e08b2b"))
	days_vbox.add_child(diff_lbl)

	# Center: Ending Route Tag, Title & Description on Parchment Dossier (FREE of OVERRUN_TRIM_ELLIPSIS on wrapped labels!)
	var narrative_box := VBoxContainer.new()
	narrative_box.position = Vector2(266.0, 46.0)
	narrative_box.size = Vector2(656.0, 120.0)
	narrative_box.add_theme_constant_override("separation", 3)
	add_child(narrative_box)

	var dossier_code := Label.new()
	dossier_code.text = "FORM CD-60  •  %s" % route_stamp_str
	dossier_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_code.add_theme_font_size_override("font_size", 11)
	dossier_code.add_theme_color_override("font_color", Color("#4e3e28"))
	dossier_code.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	narrative_box.add_child(dossier_code)

	var title_lbl := Label.new()
	title_lbl.text = end_title.to_upper()
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.custom_minimum_size = Vector2(650.0, 0.0)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.max_lines_visible = 2
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color("#1e5c26") if is_victory else Color("#a62b17"))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	narrative_box.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = end_desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(650.0, 0.0)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.max_lines_visible = 4
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_INK)
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	narrative_box.add_child(desc_lbl)

	# Right: Procedural Victory vs Perished & Ending Route Rubber Stamp
	_stamp_canvas = _OutcomeStampCanvas.new()
	_stamp_canvas.set("victory", is_victory)
	_stamp_canvas.set("route_stamp", route_stamp_str)
	_stamp_canvas.set("days_count", maxi(1, GameState.day))
	_stamp_canvas.position = Vector2(934.0, 44.0)
	_stamp_canvas.size = Vector2(276.0, 124.0)
	_stamp_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamp_canvas)

	# --- 2. MIDDLE INTELLIGENCE ROW (y = 176..322, 562px each with 16px gap) ---
	_build_osm_house_card(Rect2(68.0, 176.0, 562.0, 146.0))
	_build_nuke_telemetry_card(Rect2(646.0, 176.0, 562.0, 146.0))

	# --- 3. MULTI-RUN GARAGE CHASSIS TIER PROGRESS BANNER (y = 330..374) ---
	_build_garage_chassis_banner(Rect2(68.0, 330.0, 1140.0, 44.0))

	# --- 4. FAMILY FINAL PORTRAITS & RELATIONSHIP ROSTER (y = 382..606) ---
	_build_family_roster(Rect2(68.0, 382.0, 1140.0, 224.0))

	# --- 5. ACTION BUTTONS (y = 616..664) ---
	var btn_bar := HBoxContainer.new()
	btn_bar.position = Vector2(68.0, 616.0)
	btn_bar.size = Vector2(1140.0, 48.0)
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
	fp_ctrl.custom_minimum_size = Vector2(108.0, 118.0)
	hbox.add_child(fp_ctrl)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var hdr := Label.new()
	hdr.text = "SELECTED OPENSTREETMAP HOUSE & RECON"
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	addr_lbl.custom_minimum_size = Vector2(400.0, 0.0)
	addr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr_lbl.max_lines_visible = 2
	addr_lbl.add_theme_font_size_override("font_size", 13)
	addr_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
	info_vbox.add_child(addr_lbl)

	var area_sqm: float = float(GameState.selected_house.get("area_sqm", 180.0))
	var bldg_type: String = _format_building_type(str(GameState.selected_house.get("building_type", "house")))
	var h_lat: float = float(GameState.selected_house.get("lat", 47.6242))
	var h_lon: float = float(GameState.selected_house.get("lon", -122.3195))

	var meta_lbl := Label.new()
	meta_lbl.text = "TYPE: %s  •  %.0f m²  •  GPS: %.4f, %.4f" % [bldg_type, area_sqm, h_lat, h_lon]
	meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_lbl.add_theme_font_size_override("font_size", 11)
	meta_lbl.add_theme_color_override("font_color", Color("#dccba6"))
	info_vbox.add_child(meta_lbl)

	var items_col: int = int(GameState.scavenge_stats.get("items_collected", 0))
	var fam_saved: int = int(GameState.scavenge_stats.get("family_saved", 0))
	var exp_done: int = int(GameState.run_metrics.get("expeditions_completed", 0))
	var dist_loot: int = int(GameState.run_metrics.get("distant_landmarks_looted", 0))
	var scav_lbl := Label.new()
	scav_lbl.text = "60s HAUL: %d Items (%d Evac'd)  •  EXPEDITIONS: %d (%d Deep Ring)" % [items_col, fam_saved, exp_done, dist_loot]
	scav_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scav_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	scav_lbl.add_theme_font_size_override("font_size", 11)
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
	radar_ctrl.custom_minimum_size = Vector2(108.0, 118.0)
	radar_ctrl.clip_contents = true
	hbox.add_child(radar_ctrl)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var hdr := Label.new()
	hdr.text = "NUCLEAR DETONATION & GROUND ZERO IMPACT"
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_ATOMIC_ORANGE)
	info_vbox.add_child(hdr)

	var dist_lbl := Label.new()
	dist_lbl.text = "GROUND ZERO DISTANCE: %.2f km  •  TEMP: %.0f°C" % [dist_km, GameState.bunker_temp_c]
	dist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dist_lbl.add_theme_font_size_override("font_size", 14)
	dist_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW)
	info_vbox.add_child(dist_lbl)

	var target_name: String = str(GameState.nuke_config.get("target_name", "Strategic Target"))
	var target_lbl := Label.new()
	target_lbl.text = "STRIKE POINT: %s" % target_name
	target_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_lbl.custom_minimum_size = Vector2(400.0, 0.0)
	target_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_lbl.max_lines_visible = 2
	target_lbl.add_theme_font_size_override("font_size", 12)
	target_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_PARCHMENT)
	info_vbox.add_child(target_lbl)

	var yield_kt: int = int(GameState.nuke_config.get("yield_kt", 800))
	var yield_str: String = ("%d Mt" % (yield_kt / 1000)) if yield_kt >= 1000 else ("%d kt" % yield_kt)
	var zone_str: String = str(GameState.nuke_config.get("zone", "fallout_plume")).replace("_", " ").to_upper()
	var sv_hr: float = float(GameState.nuke_config.get("initial_sv_hr", GameState.surface_radiation_sv))

	var phys_lbl := Label.new()
	phys_lbl.text = "YIELD: %s  •  ZONE: %s  •  PEAK: %.1f Sv/hr" % [yield_str, zone_str, sv_hr]
	phys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phys_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	phys_lbl.add_theme_font_size_override("font_size", 11)
	phys_lbl.add_theme_color_override("font_color", Color("#dccba6"))
	info_vbox.add_child(phys_lbl)

	var companions: Array[String] = []
	if GameState.has_cat_sharikov:
		companions.append("Sharikov (Cat)")
	if GameState.has_dog_pancake:
		companions.append("Pancake (Dog)")
	var comp_suffix: String = ("  •  PETS: " + ", ".join(companions)) if not companions.is_empty() else ""
	var bunker_lbl := Label.new()
	bunker_lbl.text = "HULL INTEGRITY: %.0f%%%s" % [GameState.bunker_structural_integrity, comp_suffix]
	bunker_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bunker_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bunker_lbl.add_theme_font_size_override("font_size", 11)
	bunker_lbl.add_theme_color_override("font_color", Color("#9fd878") if GameState.bunker_structural_integrity >= 50.0 else ThemeHelper.COLOR_ATOMIC_ORANGE)
	info_vbox.add_child(bunker_lbl)

func _build_garage_chassis_banner(rect: Rect2) -> void:
	var new_tier: int = int(_chassis_result.get("new_tier", SaveManager.get_vehicle_chassis_tier()))
	var upgraded: bool = bool(_chassis_result.get("upgraded", false))
	var parts_run: int = GameState.get_vehicle_parts_owned_count()
	var banked_total: int = int(SaveManager.meta.get("total_vehicle_parts_banked", 0))

	var banner := PanelContainer.new()
	banner.name = "GarageChassisBanner"
	banner.position = rect.position
	banner.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f2821")
	sb.border_color = ThemeHelper.COLOR_HAZARD_YELLOW if upgraded else (Color("#7ec850") if new_tier > 0 else Color("#8c7b54"))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	banner.add_theme_stylebox_override("panel", sb)
	add_child(banner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(hbox)

	var wagon_icon := _StationWagonMiniCanvas.new()
	wagon_icon.set("chassis_tier", new_tier)
	wagon_icon.custom_minimum_size = Vector2(78.0, 32.0)
	hbox.add_child(wagon_icon)

	var tier_lbl := Label.new()
	tier_lbl.text = _format_garage_tier_headline(new_tier, upgraded)
	tier_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tier_lbl.add_theme_font_size_override("font_size", 13)
	tier_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW if (upgraded or new_tier > 0) else ThemeHelper.COLOR_PARCHMENT)
	hbox.add_child(tier_lbl)

	var parts_lbl := Label.new()
	parts_lbl.text = "Run Parts: %d/4  •  Fuel: %d/%d  •  Banked: %d" % [
		parts_run,
		GameState.fuel_cans,
		GameState.fuel_needed,
		banked_total
	]
	parts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parts_lbl.add_theme_font_size_override("font_size", 12)
	parts_lbl.add_theme_color_override("font_color", Color("#9fd878") if parts_run > 0 else Color("#dccba6"))
	hbox.add_child(parts_lbl)

func _build_family_roster(rect: Rect2) -> void:
	var outer := VBoxContainer.new()
	outer.position = rect.position
	outer.size = rect.size
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)

	var hdr_hbox := HBoxContainer.new()
	outer.add_child(hdr_hbox)

	var sec_hdr := Label.new()
	sec_hdr.text = "FAMILY PERSONNEL, RELATIONSHIPS & SURVIVAL / BETRAYAL / LEFT-BEHIND NOTES"
	sec_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec_hdr.add_theme_font_size_override("font_size", 13)
	sec_hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_INK)
	sec_hdr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	hdr_hbox.add_child(sec_hdr)

	var bonds_cnt: int = int(GameState.run_metrics.get("bonds_formed", 0))
	var args_cnt: int = int(GameState.run_metrics.get("arguments_had", 0))
	var left_cnt: int = GameState.left_behind_members.size()
	var rel_meta := Label.new()
	rel_meta.text = "Bonds Formed: %d   •   Arguments: %d   •   Left Behind: %d" % [bonds_cnt, args_cnt, left_cnt]
	rel_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rel_meta.add_theme_font_size_override("font_size", 12)
	rel_meta.add_theme_color_override("font_color", Color("#4e3e28"))
	rel_meta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	hdr_hbox.add_child(rel_meta)

	var cards_row := HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 10)
	outer.add_child(cards_row)

	var members: Array = GameState.family_members
	if members.is_empty():
		GameState.init_default_family()
		members = GameState.family_members

	var card_w: float = maxf(140.0, (rect.size.x - float(maxi(0, members.size() - 1)) * 10.0) / float(maxi(1, members.size())))
	for raw_m in members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		cards_row.add_child(_make_member_card(m, card_w))

func _was_member_left_behind(m_id: String, m_name: String) -> bool:
	for raw_lb in GameState.left_behind_members:
		if raw_lb is Dictionary:
			var lbd: Dictionary = raw_lb
			if str(lbd.get("id", "")) == m_id or str(lbd.get("name", "")) == m_name:
				return true
		else:
			var lbs: String = str(raw_lb)
			if lbs == m_id or lbs == m_name:
				return true
	return false

func _get_member_final_bond_info(member_id: String) -> Dictionary:
	if GameState.family_members.size() <= 1 or member_id == "":
		return {"has_peers": false, "avg": 0, "tier": "Solo Wolf"}
	var sum_rel: int = 0
	var cnt_rel: int = 0
	for raw_o in GameState.family_members:
		if not (raw_o is Dictionary):
			continue
		var od: Dictionary = raw_o
		var oid: String = str(od.get("id", ""))
		if oid == "" or oid == member_id:
			continue
		sum_rel += GameState.get_relationship(member_id, oid)
		cnt_rel += 1
	if cnt_rel == 0:
		return {"has_peers": false, "avg": 0, "tier": "Solo Wolf"}
	var avg_val: int = int(round(float(sum_rel) / float(cnt_rel)))
	return {
		"has_peers": true,
		"avg": avg_val,
		"tier": GameState.get_relationship_tier(avg_val)
	}

func _make_member_card(member: Dictionary, approx_card_w: float) -> PanelContainer:
	var m_id: String = str(member.get("id", ""))
	var m_name: String = str(member.get("name", "Survivor"))
	var alive: bool = bool(member.get("alive", true))
	var in_bunker: bool = bool(member.get("in_bunker", true))
	var betrayed: bool = bool(member.get("betrayed", false))
	var is_mutant: bool = bool(member.get("is_mutant", false))
	var on_exp: bool = bool(member.get("on_expedition", false))
	var run_ended: bool = GameState.game_over or GameState.victory or GameState.day > 1
	var left_behind: bool = _was_member_left_behind(m_id, m_name) or (run_ended and not in_bunker and not betrayed and not on_exp)

	var status_text := "SURVIVED"
	var status_col := Color("#7ec850")
	var border_col := Color("#6a7a5c")

	if betrayed:
		status_text = "BETRAYED SHELTER"
		status_col = Color("#ff6b4a")
		border_col = Color("#b53424")
	elif left_behind and (not in_bunker or not alive):
		status_text = "LEFT BEHIND (60s)"
		status_col = Color("#e8a234")
		border_col = Color("#966c23")
	elif not alive:
		status_text = "DECEASED"
		status_col = Color("#e05a2b")
		border_col = Color("#943c24")
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
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var portrait_ctrl := _MemberPortraitCanvas.new()
	portrait_ctrl.set("member_dict", member)
	portrait_ctrl.custom_minimum_size = Vector2(92.0, 118.0)
	portrait_ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(portrait_ctrl)

	var text_min_w: float = maxf(110.0, approx_card_w - 132.0)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var is_leader: bool = bool(member.get("is_leader", false))
	var name_lbl := Label.new()
	name_lbl.text = ("%s ★" % m_name) if is_leader else m_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", ThemeHelper.COLOR_HAZARD_YELLOW if is_leader else ThemeHelper.COLOR_PARCHMENT)
	vbox.add_child(name_lbl)

	var role_str: String = str(member.get("role", "adult")).to_upper()
	var age_val: int = int(member.get("age", 30))
	var trait_str: String = str(member.get("trait", "")).capitalize()
	var role_lbl := Label.new()
	role_lbl.text = ("%s • %d • %s" % [role_str, age_val, trait_str]) if trait_str != "" else ("%s • AGE %d" % [role_str, age_val])
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.add_theme_color_override("font_color", Color("#b8b09c"))
	vbox.add_child(role_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = "● " + status_text
	badge_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.add_theme_color_override("font_color", status_col)
	vbox.add_child(badge_lbl)

	# Pairwise Relationship Bond Summary
	var bond_info: Dictionary = _get_member_final_bond_info(m_id)
	var bond_lbl := Label.new()
	bond_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bond_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bond_lbl.add_theme_font_size_override("font_size", 10)
	if bool(bond_info.get("has_peers", false)):
		var avg_s: int = int(bond_info.get("avg", 0))
		var tier_s: String = str(bond_info.get("tier", "Neutral"))
		var sign_s: String = "+" if avg_s >= 0 else ""
		bond_lbl.text = "BOND: %s (%s%d)" % [tier_s.to_upper(), sign_s, avg_s]
		if avg_s >= 55:
			bond_lbl.add_theme_color_override("font_color", Color("#9cf06e"))
		elif avg_s >= 20:
			bond_lbl.add_theme_color_override("font_color", Color("#cbe896"))
		elif avg_s <= -50:
			bond_lbl.add_theme_color_override("font_color", Color("#ff6b4a"))
		elif avg_s <= -20:
			bond_lbl.add_theme_color_override("font_color", Color("#f2a644"))
		else:
			bond_lbl.add_theme_color_override("font_color", Color("#d4c8ae"))
	else:
		bond_lbl.text = "BOND: LONE WOLF & PETS"
		bond_lbl.add_theme_color_override("font_color", Color("#9fd878"))
	vbox.add_child(bond_lbl)

	# Survival / Betrayal / Left-Behind Note (AUTOWRAP_WORD_SMART without OVERRUN_TRIM_ELLIPSIS!)
	var detail_str: String = str(member.get("death_reason", "")).strip_edges()
	if betrayed and detail_str.is_empty():
		detail_str = "Stole rations and abandoned the shelter in bitter betrayal."
	elif left_behind and detail_str.is_empty():
		detail_str = "Left outside when the blast hatch sealed; weighed heavily on the family."
	elif detail_str.is_empty():
		if alive and GameState.victory and GameState.ending_route == "vehicle_breakout":
			detail_str = "Rode out of the fallout zone aboard the rebuilt Station Wagon!"
		else:
			detail_str = str(member.get("status_note", "Recorded in shelter log."))

	var note_lbl := Label.new()
	note_lbl.text = detail_str
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.custom_minimum_size = Vector2(text_min_w, 0.0)
	note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_lbl.max_lines_visible = 3
	note_lbl.add_theme_font_size_override("font_size", 10)
	note_lbl.add_theme_color_override("font_color", Color("#dccba6"))
	vbox.add_child(note_lbl)

	return card

func _on_play_again_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = false
	GameState.game_mode = "full_protocol"
	GameState.active_challenge_id = ""
	GameState.reset_to_defaults()
	GameState.request_screen(GameState.SCREEN_FAMILY)

func _on_return_to_title_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.demo_mode = false
	GameState.game_mode = "full_protocol"
	GameState.active_challenge_id = ""
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

	# Manilla / Aged Parchment Civil Defense Dossier Sheet
	var folder_shadow := Rect2(50.0, 42.0, vp.x - 92.0, vp.y - 72.0)
	draw_rect(folder_shadow, Color(0.0, 0.0, 0.0, 0.45), true)

	var folder_rect := Rect2(44.0, 36.0, vp.x - 88.0, vp.y - 72.0)
	var tab_rect := Rect2(56.0, 15.0, 340.0, 21.0)
	draw_rect(folder_rect, Color("#efe3c8"), true)
	draw_rect(Rect2(tab_rect.position, tab_rect.size + Vector2(0.0, 1.0)), Color("#dccba6"), true)
	draw_rect(folder_rect.grow(-5.0), Color("#c9b68f"), false, 1.2)

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
	draw_string(font, Vector2(68.0, 30.0), "DOSSIER FILE #CD-1958-REATOMIZED-V2", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ThemeHelper.COLOR_INK)

	# Subtle ledger horizontal rules across top narrative section
	for line_y in [82.0, 104.0, 126.0, 148.0]:
		draw_line(Vector2(264.0, line_y), Vector2(928.0, line_y), Color(0.55, 0.48, 0.36, 0.18), 1.0)

	# Divider rules between dossier sections
	draw_line(Vector2(66.0, 171.0), Vector2(vp.x - 66.0, 171.0), Color("#8c7b58"), 1.5)
	draw_line(Vector2(66.0, 326.0), Vector2(vp.x - 66.0, 326.0), Color("#8c7b58"), 1.2)
	draw_line(Vector2(66.0, 378.0), Vector2(vp.x - 66.0, 378.0), Color("#8c7b58"), 1.5)
	draw_line(Vector2(66.0, 610.0), Vector2(vp.x - 66.0, 610.0), Color("#8c7b58"), 1.5)


class _OutcomeStampCanvas extends Control:
	var victory: bool = false
	var route_stamp: String = "ROUTE: CIVIL DEFENSE EXTRACTION"
	var days_count: int = 1
	var anim_t: float = 1.0

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var center: Vector2 = size * 0.5
		var pop_scale: float = lerpf(1.10, 1.0, clampf(anim_t / 0.22, 0.0, 1.0))

		var ink_col: Color = Color("#1e6e2b") if victory else Color("#b82918")
		var fill_tint: Color = Color(0.16, 0.52, 0.22, 0.11) if victory else Color(0.78, 0.18, 0.10, 0.11)
		var main_txt: String = "★ VICTORY: SURVIVED ★" if victory else "✖ PERISHED IN FALLOUT ✖"
		var sub_txt: String = ("EXTRACTED ON DAY %d" % days_count) if victory else ("LOST ON DAY %d" % days_count)

		draw_set_transform(center, -0.12, Vector2(pop_scale, pop_scale))
		var outer_r := Rect2(-128.0, -48.0, 256.0, 96.0)
		var inner_r := outer_r.grow(-5.0)
		draw_rect(outer_r, fill_tint, true)
		draw_rect(outer_r, ink_col, false, 3.2)
		draw_rect(inner_r, ink_col, false, 1.4)

		var m_sz: Vector2 = font.get_string_size(main_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, Vector2(-m_sz.x * 0.5, -18.0), main_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink_col)

		draw_line(Vector2(-112.0, -10.0), Vector2(112.0, -10.0), ink_col, 1.1)

		var r_sz: Vector2 = font.get_string_size(route_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, Vector2(-r_sz.x * 0.5, 6.0), route_stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink_col)

		draw_line(Vector2(-112.0, 13.0), Vector2(112.0, 13.0), ink_col, 1.1)

		var s_sz: Vector2 = font.get_string_size(sub_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(font, Vector2(-s_sz.x * 0.5, 30.0), sub_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class _StationWagonMiniCanvas extends Control:
	var chassis_tier: int = 0

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color("#141a15"), true)
		draw_rect(box, Color("#5b6b58"), false, 1.2)

		var body_col: Color = Color("#d99b26") if chassis_tier >= 3 else (Color("#7ec850") if chassis_tier >= 1 else Color("#6e6a5e"))
		var trim_col: Color = Color("#8c4e2b") if chassis_tier >= 2 else Color("#47443c")

		# 1950s Country Squire Station Wagon side silhouette
		var hull := PackedVector2Array([
			Vector2(8.0, 23.0),
			Vector2(10.0, 15.0),
			Vector2(21.0, 14.0),
			Vector2(27.0, 7.0),
			Vector2(62.0, 7.0),
			Vector2(68.0, 14.0),
			Vector2(71.0, 23.0)
		])
		draw_colored_polygon(hull, body_col)
		draw_rect(Rect2(14.0, 16.0, 52.0, 5.0), trim_col, true)
		draw_rect(Rect2(28.0, 9.0, 15.0, 5.0), Color("#1d2b34"), true)
		draw_rect(Rect2(45.0, 9.0, 16.0, 5.0), Color("#1d2b34"), true)
		draw_polyline(hull, ThemeHelper.COLOR_INK, 1.5)

		for wx in [21.0, 57.0]:
			draw_circle(Vector2(wx, 24.0), 5.0, ThemeHelper.COLOR_INK)
			draw_circle(Vector2(wx, 24.0), 2.5, Color("#dcd3bd"))


class _HouseFootprintCanvas extends Control:
	var footprint_points: Array = []

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color("#152028"), true)
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
		var avail: Vector2 = size - Vector2(24.0, 24.0)
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
		draw_circle(center, 3.8, ThemeHelper.COLOR_ATOMIC_ORANGE)


class _GroundZeroMiniCanvas extends Control:
	var distance_km: float = 3.0

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color("#191715"), true)
		draw_rect(box, Color("#96472a"), false, 1.5)

		var gz := Vector2(size.x * 0.38, size.y * 0.54)
		for r in [15.0, 30.0, 45.0]:
			draw_arc(gz, r, 0.0, TAU, 32, Color(0.88, 0.35, 0.17, 0.38), 1.2, true)
		draw_circle(gz, 4.8, ThemeHelper.COLOR_ATOMIC_ORANGE)

		var norm_d: float = clampf(log(1.0 + distance_km) / log(51.0), 0.18, 0.95)
		var house_pos: Vector2 = gz + Vector2(0.82, -0.52).normalized() * (norm_d * 48.0)
		draw_line(gz, house_pos, Color(0.95, 0.74, 0.18, 0.65), 1.4, true)
		draw_circle(house_pos, 4.2, Color("#7ec850"))
		draw_arc(house_pos, 4.2, 0.0, TAU, 16, ThemeHelper.COLOR_INK, 1.2)


class _MemberPortraitCanvas extends Control:
	var member_dict: Dictionary = {}

	func _draw() -> void:
		var p_rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
		CharacterArtist.draw_portrait(self, p_rect, member_dict, true)
