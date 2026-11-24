class_name BunkerBackdrop
extends Control

## Full-screen (1280x720) procedurally illustrated 1950s Civil Defense fallout shelter interior.
## Dynamically reflects exact physical inventory (individual soup cans, water bottles, durable gear,
## broken states, padlock on hatch, Sharikov & Pancake), real-world OSM neighborhood map,
## radiation/temperature gauges, frost/heat overlays, and seated custom family members.

signal hotspot_selected(hotspot_info: Dictionary)

const COL_BG_DEEP := Color("#161916")
const COL_WALL_DARK := Color("#232824")
const COL_WALL_MID := Color("#2c322d")
const COL_WALL_LIGHT := Color("#363d37")
const COL_FLOOR_TOP := Color("#222521")
const COL_FLOOR_BOT := Color("#151714")
const COL_STEEL := Color("#3b423d")
const COL_STEEL_HI := Color("#555e57")
const COL_INK := Color("#1b1917")
const COL_PARCHMENT := Color("#f2e6ce")
const COL_PARCHMENT_DIM := Color("#dccba6")
const COL_HAZARD := Color("#f5be2e")
const COL_ORANGE := Color("#e05a2b")
const COL_RED := Color("#d94c2a")
const COL_GREEN := Color("#7ec850")
const COL_WATER := Color("#3b8ec2")
const COL_FROST := Color("#8ad8ff")

var _anim_time: float = 0.0
var _hotspots: Array = []
var _hovered_hotspot: Dictionary = {}
var _pinned_hotspot: Dictionary = {}
var _pinned_timer: float = 0.0
var _mouse_pos: Vector2 = Vector2(-1000.0, -1000.0)
var _notebook_occluding: bool = true
var _sanity_hundred_scale: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280.0, 720.0)

	if not GameState.inventory_changed.is_connected(_on_state_changed):
		GameState.inventory_changed.connect(_on_state_changed)
	if not GameState.family_changed.is_connected(_on_state_changed):
		GameState.family_changed.connect(_on_state_changed)
	if not GameState.day_advanced.is_connected(_on_day_changed):
		GameState.day_advanced.connect(_on_day_changed)
	if not GameState.osm_house_selected.is_connected(_on_dict_changed):
		GameState.osm_house_selected.connect(_on_dict_changed)
	if not GameState.nuke_configured.is_connected(_on_dict_changed):
		GameState.nuke_configured.connect(_on_dict_changed)

	_detect_sanity_scale()
	queue_redraw()

func refresh_bunker() -> void:
	_detect_sanity_scale()
	queue_redraw()

func set_notebook_occluding(is_open: bool) -> void:
	_notebook_occluding = is_open
	queue_redraw()

func _detect_sanity_scale() -> void:
	for m in GameState.family_members:
		if m is Dictionary:
			var md: Dictionary = m
			if int(md.get("sanity", 0)) > 10:
				_sanity_hundred_scale = true
				return

func _on_state_changed() -> void:
	_detect_sanity_scale()
	queue_redraw()

func _on_day_changed(_new_day: int) -> void:
	_detect_sanity_scale()
	queue_redraw()

func _on_dict_changed(_data: Dictionary) -> void:
	queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	if _pinned_timer > 0.0:
		_pinned_timer = maxf(0.0, _pinned_timer - delta)
		if _pinned_timer <= 0.0:
			_pinned_hotspot = {}
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_mouse_pos = mm.position
		_hovered_hotspot = _find_hotspot_at(_mouse_pos)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: Dictionary = _find_hotspot_at(mb.position)
			if not hit.is_empty():
				_pinned_hotspot = hit
				_pinned_timer = 4.0
				SoundManager.play_sfx("button_click")
				hotspot_selected.emit(hit)
			else:
				_pinned_hotspot = {}
				_pinned_timer = 0.0

func _find_hotspot_at(pt: Vector2) -> Dictionary:
	# Prevent picking hotspots hidden directly behind the open notebook
	if _notebook_occluding and Rect2(506.0, 56.0, 756.0, 596.0).has_point(pt):
		return {}
	for i in range(_hotspots.size() - 1, -1, -1):
		var hs: Dictionary = _hotspots[i]
		var r: Rect2 = hs.get("rect", Rect2())
		if r.has_point(pt):
			return hs
	return {}

func _register_hotspot(rect: Rect2, title: String, subtitle: String, body: String, accent: Color = COL_HAZARD) -> void:
	_hotspots.append({
		"rect": rect,
		"title": title,
		"subtitle": subtitle,
		"body": body,
		"accent": accent
	})

func _draw() -> void:
	_hotspots.clear()
	var font: Font = ThemeDB.fallback_font

	_draw_bunker_architecture(font)
	_draw_back_wall_pipes_and_stencils(font)
	_draw_blast_hatch_and_ladder(font)
	_draw_wall_instruments_and_map(font)
	_draw_supply_shelving_and_gear(font)
	_draw_companions(font)
	_draw_family_bench_and_members(font)
	_draw_overhead_swinging_lamp()
	_draw_temperature_and_radiation_atmosphere()
	_draw_active_tooltip(font)

# ---------------------------------------------------------------------------
# 1. BUNKER ARCHITECTURE (RIBBED STEEL CEILING, CONCRETE WALLS, SLAB FLOOR)
# ---------------------------------------------------------------------------
func _draw_bunker_architecture(_font: Font) -> void:
	# Base fill
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), COL_BG_DEEP, true)

	# Ribbed Blast Ceiling (y = 50..124)
	var ceil_poly := PackedVector2Array([
		Vector2(0.0, 48.0), Vector2(1280.0, 48.0),
		Vector2(1224.0, 124.0), Vector2(56.0, 124.0)
	])
	draw_colored_polygon(ceil_poly, Color("#1d221e"))

	# Corrugated ceiling ribs converging toward back wall
	for i in range(9):
		var t: float = float(i) / 8.0
		var top_x: float = lerpf(16.0, 1264.0, t)
		var bot_x: float = lerpf(64.0, 1216.0, t)
		var beam_pts := PackedVector2Array([
			Vector2(top_x - 12.0, 48.0),
			Vector2(top_x + 12.0, 48.0),
			Vector2(bot_x + 8.0, 124.0),
			Vector2(bot_x - 8.0, 124.0)
		])
		draw_colored_polygon(beam_pts, COL_STEEL)
		draw_line(Vector2(top_x - 12.0, 48.0), Vector2(bot_x - 8.0, 124.0), COL_INK, 2.0)
		draw_line(Vector2(top_x + 12.0, 48.0), Vector2(bot_x + 8.0, 124.0), COL_INK, 2.0)
		# Rivets along ceiling ribs
		for r_idx in range(3):
			var rt: float = 0.22 + float(r_idx) * 0.28
			var rx: float = lerpf(top_x, bot_x, rt)
			var ry: float = lerpf(48.0, 124.0, rt)
			draw_circle(Vector2(rx, ry), 2.2, COL_STEEL_HI)

	# Left & Right Angled Concrete Side Walls
	var left_wall := PackedVector2Array([
		Vector2(0.0, 48.0), Vector2(56.0, 124.0),
		Vector2(56.0, 566.0), Vector2(0.0, 648.0)
	])
	draw_colored_polygon(left_wall, Color("#1e231f"))
	var right_wall := PackedVector2Array([
		Vector2(1280.0, 48.0), Vector2(1224.0, 124.0),
		Vector2(1224.0, 566.0), Vector2(1280.0, 648.0)
	])
	draw_colored_polygon(right_wall, Color("#1c201c"))

	# Main Poured Concrete Back Wall
	var wall_rect := Rect2(56.0, 124.0, 1168.0, 442.0)
	draw_rect(wall_rect, COL_WALL_DARK, true)
	draw_rect(Rect2(64.0, 132.0, 1152.0, 426.0), COL_WALL_MID, true)

	# Horizontal concrete form seams & vertical slab joints
	for sy in [205.0, 295.0, 385.0, 475.0]:
		draw_line(Vector2(56.0, sy), Vector2(1224.0, sy), Color(0.10, 0.11, 0.10, 0.55), 1.5)
		draw_line(Vector2(56.0, sy + 2.0), Vector2(1224.0, sy + 2.0), Color(0.28, 0.31, 0.28, 0.32), 1.0)
	for sx in [332.0, 640.0, 968.0]:
		draw_line(Vector2(sx, 124.0), Vector2(sx, 566.0), Color(0.11, 0.12, 0.11, 0.45), 1.5)

	# Subtle moisture grime bands at wall top & baseboard
	draw_rect(Rect2(56.0, 124.0, 1168.0, 18.0), Color(0.07, 0.08, 0.07, 0.42), true)
	draw_rect(Rect2(56.0, 544.0, 1168.0, 22.0), Color(0.08, 0.09, 0.08, 0.52), true)
	draw_rect(wall_rect, COL_INK, false, 3.0)

	# Perspective Concrete Bunker Floor
	var floor_poly := PackedVector2Array([
		Vector2(56.0, 566.0), Vector2(1224.0, 566.0),
		Vector2(1280.0, 650.0), Vector2(1280.0, 720.0),
		Vector2(0.0, 720.0), Vector2(0.0, 650.0)
	])
	draw_colored_polygon(floor_poly, COL_FLOOR_TOP)
	draw_rect(Rect2(0.0, 654.0, 1280.0, 66.0), COL_FLOOR_BOT, true)
	draw_line(Vector2(56.0, 566.0), Vector2(1224.0, 566.0), COL_INK, 3.0)
	draw_line(Vector2(56.0, 566.0), Vector2(0.0, 650.0), COL_INK, 2.5)
	draw_line(Vector2(1224.0, 566.0), Vector2(1280.0, 650.0), COL_INK, 2.5)

	# Floor Drainage Grate in foreground center
	var grate_rect := Rect2(576.0, 658.0, 128.0, 26.0)
	draw_rect(grate_rect, Color("#111311"), true)
	draw_rect(grate_rect, COL_STEEL, false, 2.0)
	for gx in range(586, 700, 12):
		draw_line(Vector2(float(gx), 660.0), Vector2(float(gx), 682.0), COL_STEEL, 2.0)

# ---------------------------------------------------------------------------
# 2. INDUSTRIAL PIPES, VENTILATION DUCT, CRACKS & CIVIL DEFENSE STENCILS
# ---------------------------------------------------------------------------
func _draw_back_wall_pipes_and_stencils(font: Font) -> void:
	# Overhead horizontal air-scrubber pipe across back wall top
	draw_rect(Rect2(62.0, 128.0, 965.0, 11.0), Color("#464e47"), true)
	draw_rect(Rect2(62.0, 128.0, 965.0, 4.0), Color("#636d64"), true)
	draw_rect(Rect2(62.0, 128.0, 965.0, 11.0), COL_INK, false, 1.5)
	for px in [180.0, 420.0, 680.0, 910.0]:
		draw_rect(Rect2(px - 4.0, 125.0, 8.0, 17.0), COL_STEEL_HI, true)
		draw_rect(Rect2(px - 4.0, 125.0, 8.0, 17.0), COL_INK, false, 1.2)

	# Right-side vertical filtration pipes + red pressure handwheel
	draw_rect(Rect2(1182.0, 134.0, 14.0, 430.0), Color("#444c45"), true)
	draw_rect(Rect2(1182.0, 134.0, 14.0, 430.0), COL_INK, false, 1.5)
	draw_rect(Rect2(1202.0, 150.0, 10.0, 414.0), Color("#594738"), true)
	draw_rect(Rect2(1202.0, 150.0, 10.0, 414.0), COL_INK, false, 1.5)

	var valve_c := Vector2(1189.0, 336.0)
	draw_circle(valve_c, 15.0, COL_RED)
	draw_arc(valve_c, 15.0, 0.0, TAU, 24, COL_INK, 2.2)
	draw_circle(valve_c, 9.0, COL_WALL_MID)
	draw_line(valve_c + Vector2(-13.0, 0.0), valve_c + Vector2(13.0, 0.0), COL_RED, 3.0)
	draw_line(valve_c + Vector2(0.0, -13.0), valve_c + Vector2(0.0, 13.0), COL_RED, 3.0)
	draw_circle(valve_c, 3.5, COL_HAZARD)

	# Faded Civil Defense CD Emblem painted on right-center concrete wall
	var cd_c := Vector2(986.0, 328.0)
	draw_circle(cd_c, 36.0, Color(0.95, 0.75, 0.18, 0.16))
	draw_arc(cd_c, 36.0, 0.0, TAU, 32, Color(0.11, 0.10, 0.09, 0.28), 2.5)
	var tri := PackedVector2Array([
		cd_c + Vector2(0.0, -26.0),
		cd_c + Vector2(24.0, 17.0),
		cd_c + Vector2(-24.0, 17.0)
	])
	draw_colored_polygon(tri, Color(0.92, 0.88, 0.78, 0.18))
	draw_string(font, cd_c + Vector2(-11.0, 11.0), "CD", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.31, 0.18, 0.30))

	# Dynamic Structural Damage Cracks based on GameState.bunker_structural_integrity
	var dmg: float = clampf((100.0 - GameState.bunker_structural_integrity) / 100.0, 0.05, 1.0)
	var crack_pts_1 := PackedVector2Array([
		Vector2(604.0, 140.0), Vector2(612.0, 168.0),
		Vector2(598.0, 192.0), Vector2(607.0, 218.0)
	])
	draw_polyline(crack_pts_1, Color(0.09, 0.09, 0.08, 0.35 + dmg * 0.55), 1.5 + dmg * 1.5)
	if dmg > 0.25:
		var crack_pts_2 := PackedVector2Array([
			Vector2(920.0, 290.0), Vector2(936.0, 322.0),
			Vector2(926.0, 354.0), Vector2(946.0, 384.0), Vector2(939.0, 412.0)
		])
		draw_polyline(crack_pts_2, Color(0.08, 0.08, 0.07, 0.65), 2.2)

# ---------------------------------------------------------------------------
# 3. CEILING BLAST HATCH, PADLOCK & STEEL RUNG ACCESS LADDER
# ---------------------------------------------------------------------------
func _draw_blast_hatch_and_ladder(font: Font) -> void:
	# Floor hazard stripe zone beneath ladder
	var stripe_rect := Rect2(1042.0, 574.0, 118.0, 18.0)
	draw_rect(stripe_rect, COL_HAZARD, true)
	for sx in range(0, 118, 18):
		var poly := PackedVector2Array([
			Vector2(1042.0 + float(sx), 574.0),
			Vector2(1042.0 + float(sx) + 9.0, 574.0),
			Vector2(1042.0 + float(sx) + 3.0, 592.0),
			Vector2(1042.0 + float(sx) - 6.0, 592.0)
		])
		draw_colored_polygon(poly, COL_INK)
	draw_rect(stripe_rect, COL_INK, false, 2.0)

	# Ladder shadow on concrete wall
	draw_rect(Rect2(1082.0, 116.0, 58.0, 456.0), Color(0.07, 0.08, 0.07, 0.42), true)

	# Wall mounting brackets
	for by in [160.0, 285.0, 410.0, 525.0]:
		draw_rect(Rect2(1066.0, by, 70.0, 8.0), COL_STEEL, true)
		draw_rect(Rect2(1066.0, by, 70.0, 8.0), COL_INK, false, 1.4)

	# Vertical steel side rails
	draw_rect(Rect2(1073.0, 104.0, 9.0, 474.0), COL_STEEL_HI, true)
	draw_rect(Rect2(1073.0, 104.0, 9.0, 474.0), COL_INK, false, 1.8)
	draw_rect(Rect2(1120.0, 104.0, 9.0, 474.0), COL_STEEL_HI, true)
	draw_rect(Rect2(1120.0, 104.0, 9.0, 474.0), COL_INK, false, 1.8)

	# Steel rungs
	for ry in range(132, 572, 36):
		var rung_r := Rect2(1080.0, float(ry), 42.0, 6.0)
		draw_rect(rung_r, Color("#737d75"), true)
		draw_rect(rung_r, COL_INK, false, 1.4)

	# Circular Blast Hatch recessed into ceiling
	var hc := Vector2(1101.0, 86.0)
	_draw_ellipse(hc, Vector2(74.0, 27.0), Color("#151815"), COL_INK, 3.0)
	_draw_ellipse(hc, Vector2(64.0, 22.0), COL_HAZARD, COL_INK, 2.0)
	_draw_ellipse(hc, Vector2(56.0, 18.5), Color("#464f49"), COL_INK, 2.5)
	_draw_ellipse(hc + Vector2(0.0, -2.0), Vector2(44.0, 13.5), Color("#58625b"), COL_INK, 1.8)

	# Submarine locking wheel crank on hatch underside
	var wc := hc + Vector2(0.0, -1.0)
	_draw_ellipse(wc, Vector2(18.0, 7.5), Color("#262a27"), COL_HAZARD, 2.0)
	draw_line(wc + Vector2(-17.0, 0.0), wc + Vector2(17.0, 0.0), COL_HAZARD, 2.2)
	draw_line(wc + Vector2(-9.0, -6.0), wc + Vector2(9.0, 6.0), COL_HAZARD, 2.0)
	draw_line(wc + Vector2(9.0, -6.0), wc + Vector2(-9.0, 6.0), COL_HAZARD, 2.0)
	draw_circle(wc, 4.0, COL_ORANGE)

	# Heavy Steel Padlock when GameState.padlock_active is true
	if GameState.padlock_active:
		# Steel chain/hasp bar across hatch latch
		draw_line(hc + Vector2(18.0, 4.0), hc + Vector2(46.0, 18.0), Color("#b8c2bc"), 4.5)
		draw_line(hc + Vector2(18.0, 4.0), hc + Vector2(46.0, 18.0), COL_INK, 1.5)
		var lock_pos := hc + Vector2(48.0, 28.0)
		draw_circle(lock_pos, 20.0, Color(0.11, 0.12, 0.10, 0.85))
		draw_arc(lock_pos, 20.0, 0.0, TAU, 24, COL_HAZARD, 2.0)
		ItemDB.draw_item_icon(self, "padlock", lock_pos, 30.0, false)
		var tag_r := Rect2(hc.x - 42.0, hc.y + 20.0, 76.0, 16.0)
		draw_rect(tag_r, COL_INK, true)
		draw_rect(tag_r, COL_HAZARD, false, 1.2)
		draw_string(font, tag_r.position + Vector2(6.0, 12.0), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_HAZARD)
		_register_hotspot(
			Rect2(hc.x - 74.0, hc.y - 28.0, 152.0, 78.0),
			"ARMORED BLAST HATCH [PADLOCKED]",
			"Heavy Steel Padlock Engaged",
			"Sealed tight against fallout & surface raiders. The heavy padlock will automatically block the next forced entry attempt!",
			COL_HAZARD
		)
	else:
		_register_hotspot(
			Rect2(hc.x - 74.0, hc.y - 28.0, 148.0, 60.0),
			"ARMORED BLAST HATCH",
			"Standard Pressure Seal (No Padlock)",
			"Leads up the vertical access shaft to your ruined house above. Find or craft a Padlock to reinforce against surface raiders.",
			COL_STEEL_HI
		)

# ---------------------------------------------------------------------------
# 4. BACK WALL INSTRUMENTS & PINNED REAL-WORLD OSM NEIGHBORHOOD STREET MAP
# ---------------------------------------------------------------------------
func _draw_wall_instruments_and_map(font: Font) -> void:
	# --- A. Pinned Real-World Neighborhood Street Map (Rect2(304, 148, 190, 142)) ---
	var map_r := Rect2(304.0, 148.0, 190.0, 142.0)
	draw_rect(Rect2(map_r.position + Vector2(4.0, 5.0), map_r.size), Color(0.06, 0.07, 0.06, 0.55), true)
	draw_rect(map_r, COL_PARCHMENT, true)
	draw_rect(Rect2(map_r.position + Vector2(5.0, 24.0), map_r.size - Vector2(10.0, 29.0)), Color("#e4d5b4"), true)
	draw_rect(map_r, COL_INK, false, 2.2)

	# Title strip on map (inset x + 16, width size.x - 32 to clear corner pushpins)
	draw_rect(Rect2(map_r.position, Vector2(map_r.size.x, 22.0)), COL_INK, true)
	var house_name: String = str(GameState.selected_house.get("name", "Civil Defense Shelter"))
	var map_txt_w: float = map_r.size.x - 32.0
	var fitted_title: String = _fit_string_ellipsis(font, house_name, 10, map_txt_w)
	draw_string(font, map_r.position + Vector2(16.0, 15.0), fitted_title, HORIZONTAL_ALIGNMENT_LEFT, map_txt_w, 10, COL_HAZARD)

	# Map inner plot
	var plot_r := Rect2(map_r.position.x + 8.0, map_r.position.y + 26.0, map_r.size.x - 16.0, map_r.size.y - 44.0)
	# Subtle survey grid + local streets
	for gx in range(1, 6):
		var lx: float = plot_r.position.x + plot_r.size.x * (float(gx) / 6.0)
		draw_line(Vector2(lx, plot_r.position.y), Vector2(lx, plot_r.end.y), Color(0.45, 0.41, 0.33, 0.35), 1.0)
	for gy in range(1, 4):
		var ly: float = plot_r.position.y + plot_r.size.y * (float(gy) / 4.0)
		draw_line(Vector2(plot_r.position.x, ly), Vector2(plot_r.end.x, ly), Color(0.45, 0.41, 0.33, 0.35), 1.0)

	# Main street cross-roads
	var mc := plot_r.get_center()
	draw_line(Vector2(plot_r.position.x, mc.y + 6.0), Vector2(plot_r.end.x, mc.y - 4.0), Color("#cbb894"), 5.0)
	draw_line(Vector2(mc.x - 16.0, plot_r.position.y), Vector2(mc.x - 10.0, plot_r.end.y), Color("#cbb894"), 4.0)

	# Plot real nearby POIs around center
	var h_lat: float = float(GameState.selected_house.get("lat", 47.6242))
	var h_lon: float = float(GameState.selected_house.get("lon", -122.3195))
	var cos_lat: float = maxf(0.25, cos(deg_to_rad(h_lat)))
	for p_var in GameState.nearby_pois:
		if p_var is Dictionary:
			var pd: Dictionary = p_var
			var plat: float = float(pd.get("lat", h_lat))
			var plon: float = float(pd.get("lon", h_lon))
			var dx_m: float = (plon - h_lon) * 111320.0 * cos_lat
			var dy_m: float = -(plat - h_lat) * 111320.0
			var px: float = clampf(mc.x + dx_m * 0.14, plot_r.position.x + 6.0, plot_r.end.x - 6.0)
			var py: float = clampf(mc.y + dy_m * 0.12, plot_r.position.y + 6.0, plot_r.end.y - 6.0)
			var cat: String = str(pd.get("category", pd.get("poi_type", pd.get("type", "house")))).to_lower()
			var pcol := COL_WATER
			if cat.contains("church"):
				pcol = COL_HAZARD
			elif cat.contains("groc") or cat.contains("super") or cat.contains("shop"):
				pcol = COL_GREEN
			elif cat.contains("pharm") or cat.contains("med") or cat.contains("clin"):
				pcol = COL_RED
			draw_circle(Vector2(px, py), 3.0, pcol)
			draw_arc(Vector2(px, py), 3.0, 0.0, TAU, 10, COL_INK, 1.0)

	# Selected House Footprint Polygon at center
	var fp_raw: Array = GameState.selected_house.get("footprint_meters", [])
	if fp_raw.size() >= 3:
		var fp_pts := PackedVector2Array()
		for pt_v in fp_raw:
			if pt_v is Vector2:
				var v: Vector2 = pt_v
				var p_pt: Vector2 = mc + v * 1.35
				p_pt.x = clampf(p_pt.x, plot_r.position.x + 4.0, plot_r.end.x - 4.0)
				p_pt.y = clampf(p_pt.y, plot_r.position.y + 4.0, plot_r.end.y - 4.0)
				fp_pts.append(p_pt)
		if fp_pts.size() >= 3:
			draw_colored_polygon(fp_pts, COL_ORANGE)
			fp_pts.append(fp_pts[0])
			draw_polyline(fp_pts, COL_INK, 1.6)
	else:
		draw_rect(Rect2(mc - Vector2(8.0, 6.0), Vector2(16.0, 12.0)), COL_ORANGE, true)
		draw_rect(Rect2(mc - Vector2(8.0, 6.0), Vector2(16.0, 12.0)), COL_INK, false, 1.5)

	# Footer address line (inset x + 16, width size.x - 32 with ellipsis) & 4 corner pushpins
	var addr_str: String = str(GameState.selected_house.get("address", GameState.current_neighborhood_label))
	var fitted_addr: String = _fit_string_ellipsis(font, addr_str, 9, map_txt_w)
	draw_string(font, Vector2(map_r.position.x + 16.0, map_r.end.y - 5.0), fitted_addr, HORIZONTAL_ALIGNMENT_LEFT, map_txt_w, 9, COL_INK)
	for pin_pt in [
		map_r.position + Vector2(7.0, 7.0),
		Vector2(map_r.end.x - 7.0, map_r.position.y + 7.0),
		Vector2(map_r.position.x + 7.0, map_r.end.y - 7.0),
		map_r.end - Vector2(7.0, 7.0)
	]:
		draw_circle(pin_pt, 3.6, COL_RED)
		draw_arc(pin_pt, 3.6, 0.0, TAU, 10, COL_INK, 1.0)

	var area_sqm: float = float(GameState.selected_house.get("area_sqm", 160.0))
	_register_hotspot(
		map_r,
		"PINNED NEIGHBORHOOD SURVEY MAP",
		house_name,
		"%s (%.0f m² footprint). %d real-world landmarks charted for surface scavenging." % [addr_str, area_sqm, GameState.nearby_pois.size()],
		COL_ORANGE
	)

	# --- B. Analog Geiger-Müller Radiation Dial (center = (642, 206)) ---
	var gc := Vector2(642.0, 206.0)
	var gr: float = 46.0
	draw_circle(gc + Vector2(3.0, 4.0), gr + 5.0, Color(0.06, 0.07, 0.06, 0.55))
	draw_circle(gc, gr + 5.0, Color("#2a2d28"))
	draw_arc(gc, gr + 5.0, 0.0, TAU, 36, COL_INK, 2.5)
	draw_circle(gc, gr - 2.0, COL_PARCHMENT)

	# Colored danger zones arc (from PI*0.80 to PI*2.20)
	var a_start: float = PI * 0.80
	var a_end: float = PI * 2.20
	draw_arc(gc, gr - 10.0, a_start, lerpf(a_start, a_end, 0.30), 16, COL_GREEN, 6.0)
	draw_arc(gc, gr - 10.0, lerpf(a_start, a_end, 0.30), lerpf(a_start, a_end, 0.65), 16, COL_HAZARD, 6.0)
	draw_arc(gc, gr - 10.0, lerpf(a_start, a_end, 0.65), a_end, 16, COL_RED, 6.0)

	# Tick marks
	for ti in range(9):
		var tf: float = float(ti) / 8.0
		var ta: float = lerpf(a_start, a_end, tf)
		var dir := Vector2(cos(ta), sin(ta))
		draw_line(gc + dir * (gr - 16.0), gc + dir * (gr - 5.0), COL_INK, 1.5)

	# Radiation trefoil mini-badge
	var tref_c := gc + Vector2(0.0, 14.0)
	draw_circle(tref_c, 9.5, COL_HAZARD)
	for bi in range(3):
		var ba: float = float(bi) * TAU / 3.0 - PI * 0.5
		draw_arc(tref_c, 5.5, ba - 0.42, ba + 0.42, 8, COL_INK, 4.5)
	draw_circle(tref_c, 2.2, COL_HAZARD)

	# Sweeping Geiger needle with micro-tremor proportional to Sv/hr
	var sv: float = maxf(0.0, GameState.surface_radiation_sv)
	var sv_norm: float = clampf(sv / 12.0, 0.0, 1.0)
	var jitter: float = sin(_anim_time * 29.0) * 0.025 * clampf(sv / 5.0, 0.15, 1.4)
	var needle_ang: float = lerpf(a_start, a_end, sv_norm) + jitter
	var needle_tip := gc + Vector2(cos(needle_ang), sin(needle_ang)) * (gr - 9.0)
	draw_line(gc, needle_tip, COL_RED, 2.5)
	draw_circle(gc, 4.5, COL_INK)

	# Brass readout plaque beneath Geiger dial
	var g_plate := Rect2(gc.x - 48.0, gc.y + 48.0, 96.0, 22.0)
	draw_rect(g_plate, COL_INK, true)
	var sv_col := COL_GREEN if sv < 2.0 else (COL_HAZARD if sv < 5.5 else COL_RED)
	draw_rect(g_plate, sv_col, false, 1.5)
	draw_string(font, g_plate.position + Vector2(0.0, 15.0), RadiationModel.format_rate(sv * 1000.0), HORIZONTAL_ALIGNMENT_CENTER, g_plate.size.x, 11, sv_col)

	_register_hotspot(
		Rect2(gc.x - 52.0, gc.y - 52.0, 104.0, 124.0),
		"GEIGER-MÜLLER RADIATION COUNTER",
		"Outdoor dose rate: %s (%s) · shelter PF %d" % [RadiationModel.format_rate(sv * 1000.0), RadiationModel.risk_label(sv * 1000.0), int(round(RadiationModel.shelter_pf()))],
		"High surface radiation requires a working Gas Mask on expeditions to avoid severe fallout sickness.",
		sv_col
	)

	# --- C. Wall Mercury Thermometer (Rect2(718, 148, 66, 142)) ---
	var th_r := Rect2(718.0, 148.0, 66.0, 142.0)
	draw_rect(Rect2(th_r.position + Vector2(3.0, 4.0), th_r.size), Color(0.06, 0.07, 0.06, 0.5), true)
	draw_rect(th_r, Color("#2c312c"), true)
	draw_rect(Rect2(th_r.position + Vector2(4.0, 4.0), th_r.size - Vector2(8.0, 28.0)), COL_PARCHMENT, true)
	draw_rect(th_r, COL_INK, false, 2.0)

	var temp_c: float = GameState.bunker_temp_c
	var temp_norm: float = clampf((temp_c + 15.0) / 60.0, 0.05, 1.0)
	var merc_col := COL_FROST if temp_c < 2.0 else (COL_WATER if temp_c < 14.0 else (COL_HAZARD if temp_c <= 28.0 else COL_ORANGE))

	var tube_x: float = th_r.position.x + 33.0
	var tube_top: float = th_r.position.y + 14.0
	var tube_bot: float = th_r.position.y + 92.0
	draw_rect(Rect2(tube_x - 5.0, tube_top, 10.0, tube_bot - tube_top), Color("#c6ba9c"), true)
	var fill_h: float = (tube_bot - tube_top) * temp_norm
	draw_rect(Rect2(tube_x - 3.5, tube_bot - fill_h, 7.0, fill_h + 6.0), merc_col, true)
	draw_rect(Rect2(tube_x - 5.0, tube_top, 10.0, tube_bot - tube_top), COL_INK, false, 1.4)
	draw_circle(Vector2(tube_x, tube_bot + 8.0), 10.0, merc_col)
	draw_arc(Vector2(tube_x, tube_bot + 8.0), 10.0, 0.0, TAU, 20, COL_INK, 1.8)

	# Degree tick marks
	for ty_i in range(6):
		var ty: float = lerpf(tube_top + 4.0, tube_bot - 4.0, float(ty_i) / 5.0)
		draw_line(Vector2(tube_x - 13.0, ty), Vector2(tube_x - 6.0, ty), COL_INK, 1.2)
		draw_line(Vector2(tube_x + 6.0, ty), Vector2(tube_x + 13.0, ty), COL_INK, 1.2)

	# Temp digital plate
	var t_plate := Rect2(th_r.position.x + 3.0, th_r.end.y - 22.0, th_r.size.x - 6.0, 19.0)
	draw_rect(t_plate, COL_INK, true)
	draw_string(font, t_plate.position + Vector2(0.0, 14.0), "%.0f °C" % temp_c, HORIZONTAL_ALIGNMENT_CENTER, t_plate.size.x, 11, merc_col)

	var temp_desc: String = "Comfortable shelter climate."
	if temp_c < 2.0:
		temp_desc = "NUCLEAR WINTER FREEZE! Frost is creeping across the shelter walls — sickness risk elevated."
	elif temp_c > 28.0:
		temp_desc = "NEAR-BLAST THERMAL HEATWAVE! Sweltering bunker air accelerates family dehydration."
	_register_hotspot(th_r, "SHELTER WALL THERMOMETER", "Interior Temp: %.1f °C" % temp_c, temp_desc, merc_col)

	# --- D. Civil Defense Hull & Rescue Telemetry Plaque (Rect2(802, 148, 152, 142)) ---
	var cd_r := Rect2(802.0, 148.0, 152.0, 142.0)
	draw_rect(Rect2(cd_r.position + Vector2(3.0, 4.0), cd_r.size), Color(0.06, 0.07, 0.06, 0.5), true)
	draw_rect(cd_r, Color("#262b26"), true)
	draw_rect(cd_r, COL_INK, false, 2.0)
	draw_rect(Rect2(cd_r.position, Vector2(cd_r.size.x, 22.0)), COL_HAZARD, true)
	draw_string(font, cd_r.position + Vector2(7.0, 15.0), "CONELRAD STATUS", HORIZONTAL_ALIGNMENT_LEFT, cd_r.size.x - 14.0, 11, COL_INK)

	var integ: float = clampf(GameState.bunker_structural_integrity, 0.0, 100.0)
	draw_string(font, cd_r.position + Vector2(8.0, 40.0), "HULL: %.0f%%" % integ, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_PARCHMENT)
	var bar_bg := Rect2(cd_r.position.x + 8.0, cd_r.position.y + 46.0, cd_r.size.x - 16.0, 10.0)
	draw_rect(bar_bg, COL_INK, true)
	var hull_col := COL_GREEN if integ >= 65.0 else (COL_HAZARD if integ >= 35.0 else COL_RED)
	draw_rect(Rect2(bar_bg.position + Vector2(1.0, 1.0), Vector2((bar_bg.size.x - 2.0) * (integ / 100.0), 8.0)), hull_col, true)

	# Rescue chain progress lamps (0..3)
	var chains := [
		{"key": "military", "label": "MILITARY"},
		{"key": "sanctuary", "label": "SANCTUARY"},
		{"key": "scientist", "label": "SCIENTIST"}
	]
	for ci in range(chains.size()):
		var cinfo: Dictionary = chains[ci]
		var ckey: String = str(cinfo["key"])
		var clabel: String = str(cinfo["label"])
		var steps: int = int(GameState.rescue_chains.get(ckey, 0))
		var row_y: float = cd_r.position.y + 74.0 + float(ci) * 21.0
		draw_string(font, Vector2(cd_r.position.x + 8.0, row_y + 9.0), clabel, HORIZONTAL_ALIGNMENT_LEFT, 82.0, 10, COL_PARCHMENT_DIM)
		for si in range(3):
			var lamp_c := Vector2(cd_r.position.x + 102.0 + float(si) * 16.0, row_y + 5.0)
			var lit: bool = si < steps
			draw_circle(lamp_c, 5.0, COL_GREEN if lit else Color("#181a17"))
			draw_arc(lamp_c, 5.0, 0.0, TAU, 12, COL_HAZARD if lit else COL_STEEL, 1.2)

	_register_hotspot(
		cd_r,
		"CONELRAD RESCUE TELEMETRY",
		"Structural Integrity: %.0f%%" % integ,
		"Complete all 3 signal stages on Military, Sanctuary, or Scientist rescue tracks to win evacuation!",
		COL_GREEN
	)

# ---------------------------------------------------------------------------
# 5. LEFT SUPPLY SHELVING UNIT & WALL PEGBOARD (EXACT PHYSICAL INVENTORY!)
# ---------------------------------------------------------------------------
func _draw_supply_shelving_and_gear(font: Font) -> void:
	var rack_r := Rect2(26.0, 144.0, 274.0, 444.0)
	# Drop shadow behind rack
	draw_rect(Rect2(rack_r.position + Vector2(6.0, 6.0), rack_r.size), Color(0.05, 0.06, 0.05, 0.58), true)
	# Back cross-bracing X-wires
	draw_rect(rack_r, Color("#1b1f1c"), true)
	draw_line(rack_r.position + Vector2(8.0, 8.0), rack_r.end - Vector2(8.0, 8.0), Color("#2f3530"), 2.5)
	draw_line(Vector2(rack_r.end.x - 8.0, rack_r.position.y + 8.0), Vector2(rack_r.position.x + 8.0, rack_r.end.y - 8.0), Color("#2f3530"), 2.5)

	# 4 Shelf Y levels (plank surfaces)
	var shelf_ys := [236.0, 340.0, 452.0, 566.0]
	for sy in shelf_ys:
		draw_rect(Rect2(rack_r.position.x, sy, rack_r.size.x, 12.0), Color("#4c3e2e"), true)
		draw_rect(Rect2(rack_r.position.x, sy, rack_r.size.x, 4.0), Color("#695640"), true)
		draw_rect(Rect2(rack_r.position.x, sy, rack_r.size.x, 12.0), COL_INK, false, 1.8)

	# Top cap & vertical bolted steel angle-iron uprights
	draw_rect(Rect2(rack_r.position.x, rack_r.position.y, rack_r.size.x, 10.0), COL_STEEL, true)
	draw_rect(Rect2(rack_r.position.x, rack_r.position.y, 10.0, rack_r.size.y), COL_STEEL, true)
	draw_rect(Rect2(rack_r.end.x - 10.0, rack_r.position.y, 10.0, rack_r.size.y), COL_STEEL, true)
	draw_rect(rack_r, COL_INK, false, 2.2)
	for by in range(158, 582, 26):
		draw_circle(Vector2(rack_r.position.x + 5.0, float(by)), 1.8, COL_STEEL_HI)
		draw_circle(Vector2(rack_r.end.x - 5.0, float(by)), 1.8, COL_STEEL_HI)

	# --- TOP SHELF (Shelf 1: Individual Soup Cans) ---
	var soup_q: int = maxi(0, GameState.soup_quarters)
	var soup_cans: int = int(ceil(float(soup_q) / 4.0)) if soup_q > 0 else 0
	var soup_rem: int = soup_q % 4
	var max_drawn_cans: int = mini(soup_cans, 14)
	for i in range(max_drawn_cans):
		var row: int = i / 7
		var col: int = i % 7
		var cx: float = 54.0 + float(col) * 33.0 + (8.0 if row == 1 else 0.0)
		var cy: float = 219.0 - float(row) * 28.0
		ItemDB.draw_item_icon(self, "soup", Vector2(cx, cy), 30.0, false)
	if soup_cans > 14:
		var extra_r := Rect2(252.0, 162.0, 38.0, 22.0)
		draw_rect(extra_r, COL_ORANGE, true)
		draw_rect(extra_r, COL_INK, false, 1.5)
		draw_string(font, extra_r.position + Vector2(3.0, 15.0), "+%d" % (soup_cans - 14), HORIZONTAL_ALIGNMENT_CENTER, 32.0, 11, COL_PARCHMENT)

	# Fractional Soup Fill Indicator (if an opened can has 1/4, 2/4, or 3/4 left)
	if soup_rem > 0:
		var fg_r := Rect2(42.0, 158.0, 48.0, 16.0)
		draw_rect(fg_r, COL_INK, true)
		draw_rect(fg_r, COL_HAZARD, false, 1.2)
		for seg in range(4):
			var seg_r := Rect2(fg_r.position.x + 3.0 + float(seg) * 11.0, fg_r.position.y + 3.0, 9.0, 10.0)
			draw_rect(seg_r, COL_ORANGE if seg < soup_rem else Color("#2a2622"), true)

	# Bold Soup Stencil Tag
	var soup_tag := Rect2(44.0, 237.0, 238.0, 17.0)
	draw_rect(soup_tag, COL_INK, true)
	draw_rect(soup_tag, COL_ORANGE, false, 1.2)
	var soup_txt: String = "SOUP: %s CANS (%d/4)" % [GameState.format_quarters_as_cans(soup_q), soup_q]
	draw_string(font, soup_tag.position + Vector2(6.0, 13.0), soup_txt, HORIZONTAL_ALIGNMENT_LEFT, soup_tag.size.x - 10.0, 10, COL_HAZARD)
	_register_hotspot(
		Rect2(36.0, 154.0, 254.0, 100.0),
		"TOMATO SOUP STOCKPILE",
		"%s Cans (%d quarter-rations)" % [GameState.format_quarters_as_cans(soup_q), soup_q],
		"Hearty Civil Defense canned tomato soup. 1/4 can feeds one survivor for several days.",
		COL_ORANGE
	)

	# --- MIDDLE SHELF (Shelf 2: Individual Water Bottles) ---
	var water_q: int = maxi(0, GameState.water_quarters)
	var water_bottles: int = int(ceil(float(water_q) / 4.0)) if water_q > 0 else 0
	var water_rem: int = water_q % 4
	var max_drawn_bottles: int = mini(water_bottles, 14)
	for i in range(max_drawn_bottles):
		var row: int = i / 7
		var col: int = i % 7
		var bx: float = 54.0 + float(col) * 33.0 + (8.0 if row == 1 else 0.0)
		var by: float = 322.0 - float(row) * 28.0
		ItemDB.draw_item_icon(self, "water", Vector2(bx, by), 30.0, false)
	if water_bottles > 14:
		var extra_w := Rect2(252.0, 264.0, 38.0, 22.0)
		draw_rect(extra_w, COL_WATER, true)
		draw_rect(extra_w, COL_INK, false, 1.5)
		draw_string(font, extra_w.position + Vector2(3.0, 15.0), "+%d" % (water_bottles - 14), HORIZONTAL_ALIGNMENT_CENTER, 32.0, 11, COL_PARCHMENT)

	if water_rem > 0:
		var wg_r := Rect2(42.0, 260.0, 48.0, 16.0)
		draw_rect(wg_r, COL_INK, true)
		draw_rect(wg_r, COL_WATER, false, 1.2)
		for seg in range(4):
			var seg_r := Rect2(wg_r.position.x + 3.0 + float(seg) * 11.0, wg_r.position.y + 3.0, 9.0, 10.0)
			draw_rect(seg_r, COL_WATER if seg < water_rem else Color("#20282e"), true)

	var water_tag := Rect2(44.0, 341.0, 238.0, 17.0)
	draw_rect(water_tag, COL_INK, true)
	draw_rect(water_tag, COL_WATER, false, 1.2)
	var water_txt: String = "WATER: %s BOTTLES (%d/4)" % [GameState.format_quarters_as_cans(water_q), water_q]
	draw_string(font, water_tag.position + Vector2(6.0, 13.0), water_txt, HORIZONTAL_ALIGNMENT_LEFT, water_tag.size.x - 10.0, 10, Color("#8ad8ff"))
	_register_hotspot(
		Rect2(36.0, 258.0, 254.0, 100.0),
		"EMERGENCY DRINKING WATER",
		"%s Bottles (%d quarter-rations)" % [GameState.format_quarters_as_cans(water_q), water_q],
		"Critical purified water! Survivors perish after ~4 days without water — ration 1/4 bottle regularly.",
		COL_WATER
	)

	# --- LOWER SHELVES (Shelf 3 & Shelf 4) + ADJACENT WALL HOOK PEGBOARD ---
	var peg_r := Rect2(308.0, 304.0, 92.0, 206.0)
	draw_rect(Rect2(peg_r.position + Vector2(3.0, 4.0), peg_r.size), Color(0.05, 0.06, 0.05, 0.45), true)
	draw_rect(peg_r, Color("#342d24"), true)
	draw_rect(peg_r, COL_INK, false, 2.0)
	for py in range(318, 502, 22):
		for px in range(320, 394, 22):
			draw_circle(Vector2(float(px), float(py)), 1.6, Color("#1b1712"))
	draw_string(font, peg_r.position + Vector2(6.0, 14.0), "GEAR HOOKS", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 9, COL_PARCHMENT_DIM)

	# Collect every owned consumable & durable item to place across Shelf 3, Shelf 4, and Pegboard Hooks
	var carried_out: Array = _get_active_expedition_gear()
	var shelf_entries: Array = []

	if GameState.medkit_count > 0:
		shelf_entries.append({"id": "medkit", "broken": false, "count": GameState.medkit_count, "out": false})
	if GameState.bug_spray_count > 0:
		shelf_entries.append({"id": "bug_spray", "broken": false, "count": GameState.bug_spray_count, "out": false})
	if GameState.ammo_count > 0:
		shelf_entries.append({"id": "ammo", "broken": false, "count": GameState.ammo_count, "out": false})

	for gid_v in GameState.DURABLE_GEAR_IDS:
		var gid: String = str(gid_v)
		var g_entry: Dictionary = GameState.bunker_items.get(gid, {})
		var is_out: bool = carried_out.has(gid) or bool(g_entry.get("checked_out", false))
		if bool(g_entry.get("owned", false)) or is_out:
			shelf_entries.append({
				"id": gid,
				"broken": bool(g_entry.get("broken", false)),
				"count": int(g_entry.get("count", 1)),
				"out": is_out and not bool(g_entry.get("owned", false))
			})

	# Pre-computed clean physical slots across Shelf 3 (6 slots), Shelf 4 (6 slots), and Wall Pegboard (6 hooks)
	var gear_slots := [
		# Shelf 3 (y = 428)
		Vector2(58.0, 424.0), Vector2(98.0, 424.0), Vector2(138.0, 424.0),
		Vector2(178.0, 424.0), Vector2(218.0, 424.0), Vector2(258.0, 424.0),
		# Shelf 4 (y = 540)
		Vector2(58.0, 536.0), Vector2(98.0, 536.0), Vector2(138.0, 536.0),
		Vector2(178.0, 536.0), Vector2(218.0, 536.0), Vector2(258.0, 536.0),
		# Wall Pegboard Hooks
		Vector2(332.0, 348.0), Vector2(376.0, 348.0),
		Vector2(332.0, 408.0), Vector2(376.0, 408.0),
		Vector2(332.0, 468.0), Vector2(376.0, 468.0)
	]

	for idx in range(mini(shelf_entries.size(), gear_slots.size())):
		var item_d: Dictionary = shelf_entries[idx]
		var iid: String = str(item_d.get("id", ""))
		var broken: bool = bool(item_d.get("broken", false))
		var cnt: int = int(item_d.get("count", 1))
		var is_out: bool = bool(item_d.get("out", false))
		var pos: Vector2 = gear_slots[idx]

		if idx >= 12:
			# Metal hook above pegboard item
			draw_line(pos + Vector2(0.0, -20.0), pos + Vector2(0.0, -12.0), COL_STEEL_HI, 2.5)
			draw_circle(pos + Vector2(0.0, -20.0), 3.0, COL_HAZARD)

		if is_out:
			draw_rect(Rect2(pos - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), Color(0.12, 0.14, 0.12, 0.72), true)
			draw_rect(Rect2(pos - Vector2(16.0, 16.0), Vector2(32.0, 32.0)), COL_HAZARD, false, 1.2)
			draw_string(font, pos + Vector2(-13.0, 4.0), "OUT", HORIZONTAL_ALIGNMENT_CENTER, 26.0, 9, COL_HAZARD)
		else:
			ItemDB.draw_item_icon(self, iid, pos, 34.0, broken)
			if cnt > 1 or iid == "ammo":
				var badge_r := Rect2(pos.x + 2.0, pos.y + 4.0, 20.0, 13.0)
				draw_rect(badge_r, COL_INK, true)
				draw_rect(badge_r, COL_HAZARD, false, 1.0)
				var b_lbl: String = "%d" % cnt if iid == "ammo" else "x%d" % cnt
				draw_string(font, badge_r.position + Vector2(1.0, 10.0), b_lbl, HORIZONTAL_ALIGNMENT_CENTER, 18.0, 8, COL_PARCHMENT)

		var info: Dictionary = ItemDB.get_item_info(iid)
		var iname: String = str(info.get("name", iid.capitalize()))
		var idesc: String = str(info.get("description", "Shelter survival equipment."))
		var cond_str: String = "Carried on Active Expedition" if is_out else ("BROKEN — Needs Repair!" if broken else "Working Condition")
		if iid == "ammo":
			cond_str = "%d Rounds Available" % cnt
		elif cnt > 1:
			cond_str += " (x%d)" % cnt
		_register_hotspot(
			Rect2(pos - Vector2(18.0, 18.0), Vector2(36.0, 36.0)),
			iname.to_upper(),
			cond_str,
			idesc,
			COL_RED if broken else COL_HAZARD
		)

# ---------------------------------------------------------------------------
# 6. COMPANIONS: SHARIKOV THE CAT (CRATE) & PANCAKE THE DOG (BY LADDER)
# ---------------------------------------------------------------------------
func _draw_companions(font: Font) -> void:
	# Military wooden crate beside shelf
	var crate_r := Rect2(308.0, 524.0, 88.0, 62.0)
	draw_rect(Rect2(crate_r.position + Vector2(4.0, 4.0), crate_r.size), Color(0.05, 0.06, 0.05, 0.5), true)
	draw_rect(crate_r, Color("#5b4832"), true)
	draw_line(Vector2(crate_r.position.x, crate_r.position.y + 20.0), Vector2(crate_r.end.x, crate_r.position.y + 20.0), COL_INK, 1.5)
	draw_line(Vector2(crate_r.position.x, crate_r.position.y + 42.0), Vector2(crate_r.end.x, crate_r.position.y + 42.0), COL_INK, 1.5)
	draw_line(crate_r.position, crate_r.end, Color("#463624"), 3.0)
	draw_rect(crate_r, COL_INK, false, 2.0)
	draw_string(font, crate_r.position + Vector2(10.0, 35.0), "U.S.C.D.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#241d15"))

	if GameState.has_cat_sharikov:
		# Folded red blanket + curled Sharikov on top of crate
		draw_rect(Rect2(316.0, 517.0, 72.0, 9.0), Color("#8f3428"), true)
		draw_rect(Rect2(316.0, 517.0, 72.0, 9.0), COL_INK, false, 1.2)
		var purr_bob: float = sin(_anim_time * 2.8) * 1.4
		var cat_pos := Vector2(352.0, 498.0 + purr_bob)
		ItemDB.draw_item_icon(self, "cat", cat_pos, 42.0, false)
		draw_string(font, cat_pos + Vector2(18.0, -10.0 + sin(_anim_time * 2.0) * 2.0), "purr~", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_PARCHMENT_DIM)
		_register_hotspot(
			Rect2(312.0, 474.0, 82.0, 56.0),
			"SHARIKOV THE CAT",
			"Bunker Feline Companion",
			"Curled comfortably on the supply crate. Boosts family sanity, hunts roaches, and may unlock mysterious cables!",
			COL_HAZARD
		)

	if GameState.has_dog_pancake:
		# Olive mat + food bowl + Pancake the Dog shifted 24px left clear of ladder hazard stripes (x = 1042)
		var dog_base := Vector2(982.0, 566.0)
		_draw_ellipse(dog_base + Vector2(0.0, 14.0), Vector2(44.0, 11.0), Color("#3d4a35"), COL_INK, 1.5)
		var wag: float = sin(_anim_time * 5.4) * 2.0
		ItemDB.draw_item_icon(self, "dog", dog_base + Vector2(wag * 0.4, -10.0 + absf(wag) * 0.3), 48.0, false)
		# Red dog bowl (x = 1014..1038, cleanly left of x = 1042 hazard stripes)
		var bowl_r := Rect2(1014.0, 574.0, 24.0, 10.0)
		draw_rect(bowl_r, COL_RED, true)
		draw_rect(bowl_r, COL_INK, false, 1.3)
		_register_hotspot(
			Rect2(950.0, 526.0, 88.0, 62.0),
			"PANCAKE THE DOG",
			"Loyal Shelter Watchdog",
			"Guards the blast hatch ladder against raiders and lifts everyone's spirits in the dark.",
			COL_HAZARD
		)

# ---------------------------------------------------------------------------
# 7. CENTER BENCH / FOLDING CHAIRS — CUSTOM SEATED FAMILY MEMBERS!
# ---------------------------------------------------------------------------
func _draw_family_bench_and_members(font: Font) -> void:
	# Rugged 4-seat Civil Defense wooden & iron bench
	var bench_seat := Rect2(404.0, 494.0, 548.0, 16.0)
	var bench_back := Rect2(410.0, 434.0, 536.0, 26.0)

	# Shadow pool beneath bench
	_draw_ellipse(Vector2(678.0, 582.0), Vector2(285.0, 18.0), Color(0.05, 0.06, 0.05, 0.55), Color.TRANSPARENT, 0.0)

	# Steel bench legs & crossbars
	for lx in [426.0, 592.0, 762.0, 924.0]:
		draw_rect(Rect2(lx, 434.0, 10.0, 146.0), COL_STEEL, true)
		draw_rect(Rect2(lx, 434.0, 10.0, 146.0), COL_INK, false, 1.5)
	draw_rect(bench_back, Color("#5a4631"), true)
	draw_rect(bench_back, COL_INK, false, 2.0)
	draw_rect(bench_seat, Color("#6d553c"), true)
	draw_rect(bench_seat, COL_INK, false, 2.0)

	var seat_xs := [468.0, 608.0, 748.0, 888.0]
	var seat_y: float = 496.0
	var count: int = mini(GameState.family_members.size(), 4)

	for i in range(count):
		var m_var: Variant = GameState.family_members[i]
		if not (m_var is Dictionary):
			continue
		var member: Dictionary = m_var
		var sx: float = seat_xs[i]
		var m_name: String = str(member.get("name", "Survivor"))
		var alive: bool = bool(member.get("alive", true))
		var in_bunker: bool = bool(member.get("in_bunker", false))
		var on_exp: bool = bool(member.get("on_expedition", false))

		if not in_bunker:
			# Left behind during 60s scavenge
			var tag_empty := Rect2(sx - 52.0, seat_y - 44.0, 104.0, 24.0)
			draw_rect(tag_empty, Color(0.12, 0.12, 0.11, 0.82), true)
			draw_rect(tag_empty, COL_STEEL, false, 1.2)
			draw_string(font, tag_empty.position + Vector2(0.0, 16.0), "NOT IN SHELTER", HORIZONTAL_ALIGNMENT_CENTER, tag_empty.size.x, 9, COL_PARCHMENT_DIM)
			_draw_seat_nameplate(font, Vector2(sx, 592.0), m_name, Color("#77746b"))
			_register_hotspot(
				Rect2(sx - 54.0, seat_y - 80.0, 108.0, 160.0),
				m_name.to_upper() + " — MISSING",
				"Did not reach the bunker hatch in time",
				"Left on the surface when the blast door sealed.",
				COL_STEEL_HI
			)
		elif not alive:
			# Fallen survivor memorial folded blanket
			var mem_r := Rect2(sx - 34.0, seat_y - 22.0, 68.0, 22.0)
			draw_rect(mem_r, Color("#3f473c"), true)
			draw_rect(mem_r, COL_INK, false, 1.6)
			var rip_r := Rect2(sx - 44.0, seat_y - 48.0, 88.0, 20.0)
			draw_rect(rip_r, COL_INK, true)
			draw_rect(rip_r, COL_RED, false, 1.2)
			draw_string(font, rip_r.position + Vector2(0.0, 14.0), "FALLEN", HORIZONTAL_ALIGNMENT_CENTER, rip_r.size.x, 10, COL_RED)
			_draw_seat_nameplate(font, Vector2(sx, 592.0), m_name, COL_RED)
			var reason: String = str(member.get("death_reason", "Perished in the shelter."))
			_register_hotspot(
				Rect2(sx - 54.0, seat_y - 80.0, 108.0, 160.0),
				m_name.to_upper() + " — DECEASED",
				"Fallen Family Member",
				reason if reason != "" else "Did not survive the atomic aftermath.",
				COL_RED
			)
		elif on_exp:
			# Empty chair with expedition rucksack/tag ("OUT SCAVENGING")
			var pack_r := Rect2(sx - 24.0, seat_y - 42.0, 48.0, 42.0)
			draw_rect(pack_r, Color("#6a5b3e"), true)
			draw_rect(Rect2(pack_r.position + Vector2(4.0, 6.0), Vector2(40.0, 14.0)), Color("#82704d"), true)
			draw_rect(pack_r, COL_INK, false, 2.0)
			draw_line(pack_r.position + Vector2(12.0, 0.0), pack_r.position + Vector2(12.0, 42.0), Color("#3d3122"), 3.0)
			draw_line(pack_r.position + Vector2(36.0, 0.0), pack_r.position + Vector2(36.0, 42.0), Color("#3d3122"), 3.0)

			var out_tag := Rect2(sx - 58.0, seat_y - 72.0, 116.0, 24.0)
			draw_rect(out_tag, COL_HAZARD, true)
			draw_rect(out_tag, COL_INK, false, 1.8)
			draw_string(font, out_tag.position + Vector2(0.0, 16.0), "OUT SCAVENGING", HORIZONTAL_ALIGNMENT_CENTER, out_tag.size.x, 10, COL_INK)
			_draw_seat_nameplate(font, Vector2(sx, 592.0), m_name, COL_HAZARD)

			var exp_dest: String = _get_active_expedition_target_name()
			_register_hotspot(
				Rect2(sx - 58.0, seat_y - 86.0, 116.0, 174.0),
				m_name.to_upper() + " — ON EXPEDITION",
				"Scavenging: " + exp_dest,
				"Exploring the irradiated neighborhood outside. Check Tab 4 in the Survival Notebook for return ETA!",
				COL_HAZARD
			)
		else:
			# Living seated custom character with gentle breathing bob!
			var bob_y: float = sin(_anim_time * 2.15 + float(i) * 1.35) * 1.8
			CharacterArtist.draw_bunker_seated_character(self, Vector2(sx, seat_y + bob_y), member, _anim_time + float(i) * 0.7, 1.0)
			_draw_seat_nameplate(font, Vector2(sx, 592.0), m_name, COL_PARCHMENT)

			var badges: Array = _collect_member_status_badges(member)
			var bx_start: float = sx - (float(badges.size()) * 27.0) * 0.5
			for bi in range(badges.size()):
				var bd: Dictionary = badges[bi]
				var pill_r := Rect2(bx_start + float(bi) * 27.0, seat_y - 122.0 + bob_y * 0.5, 25.0, 15.0)
				var bcol: Color = bd.get("color", COL_HAZARD)
				draw_rect(pill_r, COL_INK, true)
				draw_rect(pill_r, bcol, false, 1.3)
				draw_string(font, pill_r.position + Vector2(0.0, 11.0), str(bd.get("short", "!")), HORIZONTAL_ALIGNMENT_CENTER, pill_r.size.x, 8, bcol)

			var role_str: String = str(member.get("role", "adult")).capitalize()
			var age_val: int = int(member.get("age", 30))
			var trait_str: String = str(member.get("trait", "survivor")).capitalize()
			var note_str: String = _build_member_tooltip_summary(member)
			_register_hotspot(
				Rect2(sx - 52.0, seat_y - 126.0, 104.0, 218.0),
				"%s (%s, %d)" % [m_name.to_upper(), role_str, age_val],
				"Trait: %s" % trait_str,
				note_str,
				COL_GREEN if badges.is_empty() else COL_HAZARD
			)

func _draw_seat_nameplate(font: Font, center: Vector2, text: String, text_col: Color) -> void:
	var pr := Rect2(center.x - 50.0, center.y - 10.0, 100.0, 20.0)
	draw_rect(pr, COL_INK, true)
	draw_rect(pr, COL_STEEL_HI, false, 1.3)
	draw_string(font, pr.position + Vector2(4.0, 14.0), text, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x - 8.0, 11, text_col)

func _collect_member_status_badges(member: Dictionary) -> Array:
	var res: Array = []
	var h: int = int(member.get("hunger", 0))
	var dwf: int = int(member.get("days_without_food", 0))
	if (h <= 10 and h >= 1) or h >= 25 or dwf >= 3:
		res.append({"short": "HNG", "label": "Hungry", "color": COL_ORANGE})

	var t: int = int(member.get("thirst", 0))
	var dww: int = int(member.get("days_without_water", 0))
	if (t <= 10 and t >= 1) or t >= 25 or dww >= 2:
		res.append({"short": "THR", "label": "Thirsty", "color": COL_WATER})

	if int(member.get("sickness", 0)) > 0:
		res.append({"short": "SCK", "label": "Sick", "color": COL_GREEN})
	if int(member.get("injury", 0)) > 0:
		res.append({"short": "INJ", "label": "Injured", "color": COL_RED})

	var san: int = int(member.get("sanity", 0))
	var is_crazy: bool = (san <= 35) if _sanity_hundred_scale else (san >= 2)
	if is_crazy:
		res.append({"short": "CRZ", "label": "Crazy", "color": Color("#c96be8")})
	if bool(member.get("is_mutant", false)):
		res.append({"short": "MUT", "label": "Mutant", "color": COL_GREEN})
	return res

func _build_member_tooltip_summary(member: Dictionary) -> String:
	var parts: Array[String] = []
	var badges: Array = _collect_member_status_badges(member)
	if badges.is_empty():
		parts.append("Condition: Healthy & Steady")
	else:
		var names: Array[String] = []
		for b in badges:
			var bd: Dictionary = b
			names.append(str(bd.get("label", "")))
		parts.append("Conditions: " + ", ".join(names))
	var note: String = str(member.get("status_note", ""))
	if note != "":
		parts.append(note)
	return "\n".join(parts)

# ---------------------------------------------------------------------------
# 8. SWINGING WARM OVERHEAD WORK-LAMP & SOFT GOLDEN LIGHT CONE
# ---------------------------------------------------------------------------
func _draw_overhead_swinging_lamp() -> void:
	var pivot := Vector2(656.0, 50.0)
	var swing: float = sin(_anim_time * 1.35) * 0.065
	var cord_len: float = 48.0
	var dir := Vector2(sin(swing), cos(swing))
	var perp := Vector2(cos(swing), -sin(swing))
	var bulb_pos: Vector2 = pivot + dir * cord_len

	# Subtle flicker if hull damaged
	var flicker: float = 1.0
	if GameState.bunker_structural_integrity < 55.0 and sin(_anim_time * 19.0) > 0.92:
		flicker = 0.68

	# Soft multi-layered golden light cone cast across center bunker
	var cone_outer := PackedVector2Array([
		bulb_pos - perp * 16.0,
		bulb_pos + perp * 16.0,
		bulb_pos + dir * 560.0 + perp * 410.0,
		bulb_pos + dir * 560.0 - perp * 410.0
	])
	draw_colored_polygon(cone_outer, Color(0.99, 0.84, 0.42, 0.055 * flicker))

	var cone_inner := PackedVector2Array([
		bulb_pos - perp * 9.0,
		bulb_pos + perp * 9.0,
		bulb_pos + dir * 540.0 + perp * 230.0,
		bulb_pos + dir * 540.0 - perp * 230.0
	])
	draw_colored_polygon(cone_inner, Color(1.0, 0.91, 0.58, 0.062 * flicker))

	# Warm floor light pool
	_draw_ellipse(Vector2(656.0 + sin(swing) * 120.0, 596.0), Vector2(260.0, 26.0), Color(1.0, 0.86, 0.45, 0.05 * flicker), Color.TRANSPARENT, 0.0)

	# Electrical cord & Industrial enameled shade
	draw_line(pivot, bulb_pos - dir * 8.0, COL_INK, 3.0)
	draw_circle(bulb_pos + dir * 4.0, 9.0, Color(1.0, 0.94, 0.68, 0.95 * flicker))
	draw_circle(bulb_pos + dir * 4.0, 18.0, Color(1.0, 0.85, 0.35, 0.24 * flicker))

	var shade := PackedVector2Array([
		bulb_pos - dir * 10.0 - perp * 9.0,
		bulb_pos - dir * 10.0 + perp * 9.0,
		bulb_pos + dir * 3.0 + perp * 26.0,
		bulb_pos + dir * 3.0 - perp * 26.0
	])
	draw_colored_polygon(shade, Color("#2f3831"))
	draw_polyline(PackedVector2Array([shade[0], shade[1], shade[2], shade[3], shade[0]]), COL_INK, 2.0)
	draw_line(shade[3], shade[2], COL_HAZARD, 2.0)

# ---------------------------------------------------------------------------
# 9. NUCLEAR WINTER FROST (< 2°C) & NEAR-BLAST HEAT HAZE (> 28°C)
# ---------------------------------------------------------------------------
func _draw_temperature_and_radiation_atmosphere() -> void:
	var temp_c: float = GameState.bunker_temp_c
	if temp_c < 2.0:
		var intensity: float = clampf((2.0 - temp_c) / 14.0, 0.35, 1.0)
		var frost_col := Color(0.58, 0.88, 1.0, 0.34 * intensity)
		var frost_hi := Color(0.86, 0.97, 1.0, 0.55 * intensity)
		var corners := [
			{"origin": Vector2(0.0, 52.0), "dx": 1.0, "dy": 1.0},
			{"origin": Vector2(1280.0, 52.0), "dx": -1.0, "dy": 1.0},
			{"origin": Vector2(0.0, 720.0), "dx": 1.0, "dy": -1.0},
			{"origin": Vector2(1280.0, 720.0), "dx": -1.0, "dy": -1.0}
		]
		for c_var in corners:
			var cd: Dictionary = c_var
			var o: Vector2 = cd["origin"]
			var dx: float = float(cd["dx"])
			var dy: float = float(cd["dy"])
			var corner_poly := PackedVector2Array([
				o,
				o + Vector2(dx * 165.0, 0.0),
				o + Vector2(dx * 68.0, dy * 64.0),
				o + Vector2(0.0, dy * 155.0)
			])
			draw_colored_polygon(corner_poly, frost_col)
			# Crystalline frost needles
			for ni in range(6):
				var ang: float = (0.12 + float(ni) * 0.24) * PI * 0.5
				var len_f: float = 82.0 + float(ni % 3) * 34.0
				var tip := o + Vector2(cos(ang) * dx * len_f, sin(ang) * dy * len_f)
				draw_line(o, tip, frost_hi, 2.0)
				var mid := o.lerp(tip, 0.62)
				draw_line(mid, mid + Vector2(dx * 18.0, dy * 6.0), frost_hi, 1.4)
				draw_line(mid, mid + Vector2(dx * 6.0, dy * 18.0), frost_hi, 1.4)
		# Icicles along overhead pipe
		for ix in range(110, 960, 68):
			var ih: float = 14.0 + float((ix * 13) % 14)
			var icy := PackedVector2Array([
				Vector2(float(ix) - 4.0, 139.0),
				Vector2(float(ix) + 4.0, 139.0),
				Vector2(float(ix), 139.0 + ih)
			])
			draw_colored_polygon(icy, frost_hi)

	elif temp_c > 28.0:
		var pulse: float = 0.78 + 0.22 * sin(_anim_time * 2.4)
		var heat_a: float = clampf((temp_c - 28.0) / 18.0, 0.28, 0.85) * 0.14 * pulse
		draw_rect(Rect2(0.0, 50.0, 1280.0, 90.0), Color(0.92, 0.36, 0.14, heat_a), true)
		draw_rect(Rect2(0.0, 620.0, 1280.0, 100.0), Color(0.90, 0.32, 0.12, heat_a * 0.85), true)
		# Glowing thermal shimmer waves near pipes
		for wy in range(180, 520, 64):
			var sx_off: float = sin(_anim_time * 3.2 + float(wy) * 0.05) * 5.0
			draw_line(Vector2(1174.0 + sx_off, float(wy)), Vector2(1218.0 - sx_off, float(wy) - 14.0), Color(0.96, 0.48, 0.20, heat_a * 1.8), 2.0)

# ---------------------------------------------------------------------------
# 10. INTERACTIVE BUNKER INSPECTOR TOOLTIP
# ---------------------------------------------------------------------------
func _draw_active_tooltip(font: Font) -> void:
	var active: Dictionary = _pinned_hotspot if not _pinned_hotspot.is_empty() else _hovered_hotspot
	if active.is_empty():
		return

	var title: String = str(active.get("title", ""))
	var sub: String = str(active.get("subtitle", ""))
	var body: String = str(active.get("body", ""))
	var accent: Color = active.get("accent", COL_HAZARD)
	var hs_rect: Rect2 = active.get("rect", Rect2())

	# Highlight frame around active bunker element
	draw_rect(hs_rect.grow(3.0), Color(accent.r, accent.g, accent.b, 0.72), false, 2.0)

	var box_w: float = 304.0
	var box_h: float = 96.0
	var anchor_pt: Vector2 = hs_rect.get_center() + Vector2(0.0, -hs_rect.size.y * 0.5 - box_h - 10.0)
	var max_x: float = 496.0 - box_w if _notebook_occluding else 1264.0 - box_w
	var bx: float = clampf(anchor_pt.x - box_w * 0.5, 16.0, maxf(16.0, max_x))
	var by: float = clampf(anchor_pt.y, 62.0, 610.0)
	var tip_r := Rect2(bx, by, box_w, box_h)

	draw_rect(Rect2(tip_r.position + Vector2(4.0, 5.0), tip_r.size), Color(0.04, 0.05, 0.04, 0.72), true)
	draw_rect(tip_r, Color("#1d201d"), true)
	draw_rect(Rect2(tip_r.position, Vector2(tip_r.size.x, 22.0)), accent, true)
	draw_rect(tip_r, COL_PARCHMENT, false, 1.8)

	draw_string(font, tip_r.position + Vector2(8.0, 15.0), title, HORIZONTAL_ALIGNMENT_LEFT, box_w - 16.0, 11, COL_INK)
	draw_string(font, tip_r.position + Vector2(8.0, 38.0), sub, HORIZONTAL_ALIGNMENT_LEFT, box_w - 16.0, 11, accent)
	draw_multiline_string(font, tip_r.position + Vector2(8.0, 55.0), body, HORIZONTAL_ALIGNMENT_LEFT, box_w - 16.0, 10, 3, COL_PARCHMENT)

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _fit_string_ellipsis(font: Font, text: String, font_size: int, max_w: float) -> String:
	# Equivalent to TextServer.OVERRUN_TRIM_ELLIPSIS without per-frame TextLine RID churn
	if max_w <= 0.0 or text == "":
		return ""
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
		return text
	var ell: String = "..."
	var trimmed: String = text
	while trimmed.length() > 1:
		trimmed = trimmed.substr(0, trimmed.length() - 1).strip_edges(false, true)
		var candidate: String = trimmed + ell
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
			return candidate
	return ell

func _draw_ellipse(center: Vector2, radii: Vector2, fill_col: Color, line_col: Color, line_w: float) -> void:
	var pts := PackedVector2Array()
	var steps: int = 28
	for i in range(steps):
		var a: float = float(i) / float(steps) * TAU
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	if fill_col.a > 0.0:
		draw_colored_polygon(pts, fill_col)
	if line_w > 0.0 and line_col.a > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, line_col, line_w)

func _get_active_expedition_gear() -> Array:
	if GameState.active_expedition.is_empty():
		return []
	var g1: Variant = GameState.active_expedition.get("gear_ids", [])
	if g1 is Array and not (g1 as Array).is_empty():
		return g1 as Array
	var g2: Variant = GameState.active_expedition.get("gear", [])
	if g2 is Array:
		return g2 as Array
	return []

func _get_active_expedition_target_name() -> String:
	if GameState.active_expedition.is_empty():
		return "Irradiated Neighborhood"
	var direct: String = str(GameState.active_expedition.get("target_name", GameState.active_expedition.get("poi_name", "")))
	if direct != "":
		return direct
	var t_var: Variant = GameState.active_expedition.get("target", {})
	if t_var is Dictionary:
		var td: Dictionary = t_var
		return str(td.get("name", "Nearby Landmark"))
	return "Nearby Landmark"
