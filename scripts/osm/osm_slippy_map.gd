class_name OsmSlippyMap
extends Control

## Interactive Web Mercator OpenStreetMap slippy tile + vector parcel tactical map.
## Streams & caches 256x256 PNG tiles from tile.openstreetmap.org via 4 async HTTP workers,
## renders crisp vector streets/parks/buildings even offline or on frame 1,
## highlights hovered/selected houses, and displays Civil Defense range rings & POI badges.

signal house_clicked(building_dict: Dictionary)
signal house_hovered(building_dict: Dictionary)
signal view_changed(center_lat: float, center_lon: float, zoom: int)

const MIN_ZOOM := 15
const MAX_ZOOM := 18
const DEFAULT_ZOOM := 17
const TILE_SIZE := 256.0
const TILE_URL_TEMPLATE := "https://tile.openstreetmap.org/%d/%d/%d.png"
const USER_AGENT_HEADER := "User-Agent: TheEndIsNear/1.0 (+https://github.com/Federallyapproved/the-end-is-near)"
const TILE_CACHE_DIR := "user://osm_tiles"
const WORKER_COUNT := 4
const MAX_MEM_TILES := 280

# Mid-century 1950s CONELRAD cartographic palette
const COL_PAPER_BASE := Color("#dfd3b8")
const COL_GRID_LINE := Color(0.18, 0.17, 0.14, 0.08)
const COL_PARK_FILL := Color(0.44, 0.62, 0.38, 0.42)
const COL_WATER_FILL := Color(0.26, 0.54, 0.72, 0.48)
const COL_ROAD_CASE := Color(0.17, 0.15, 0.13, 0.78)
const COL_ROAD_MAIN := Color("#f5e4b3")
const COL_ROAD_LOCAL := Color("#f4ecda")
const COL_BLDG_RES := Color(0.82, 0.63, 0.41, 0.56)
const COL_BLDG_COMM := Color(0.43, 0.51, 0.55, 0.50)
const COL_BLDG_NEIGHBOR := Color(0.92, 0.73, 0.28, 0.62)
const COL_BLDG_OUTLINE := Color(0.13, 0.12, 0.10, 0.85)
const COL_HOVER_FILL := Color(0.96, 0.75, 0.18, 0.72)
const COL_SELECT_FILL := Color(0.88, 0.35, 0.17, 0.82)
const COL_HAZARD_YELLOW := Color("#f5be2e")
const COL_ATOMIC_ORANGE := Color("#e05a2b")
const COL_INK_DARK := Color("#1b1917")
const COL_PARCHMENT := Color("#f2e6ce")
const COL_SAFE_GREEN := Color("#7ec850")

var center_lat: float = 47.6240
var center_lon: float = -122.3195
var zoom: int = DEFAULT_ZOOM

var _roads: Array = []
var _parks: Array = []
var _buildings: Array = []
var _all_pois: Array = []
var _nearby_targets: Array = []
var _neighbor_id_set: Dictionary = {}

var _selected_house: Dictionary = {}
var _hovered_house: Dictionary = {}
var _highlighted_poi_id: int = -1

# Smooth pan animation state
var _pan_active: bool = false
var _pan_from_lat: float = 0.0
var _pan_from_lon: float = 0.0
var _pan_to_lat: float = 0.0
var _pan_to_lon: float = 0.0
var _pan_elapsed: float = 0.0
var _pan_duration: float = 0.8

# Mouse pan & click tracking
var _mouse_down: bool = false
var _is_dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_mouse_pos: Vector2 = Vector2(-1000.0, -1000.0)
var _mouse_inside: bool = false

# Cached screen polygons for fast hit-testing
var _visible_bldg_hit_cache: Array = []

# Async tile workers & caches
var _tile_workers: Array[HTTPRequest] = []
var _worker_tile_keys: Array[String] = []
var _tile_textures: Dictionary = {}
var _tile_order: Array[String] = []
var _queued_keys: Array[String] = []
var _queued_set: Dictionary = {}
var _in_flight_set: Dictionary = {}
var _failed_tiles: Dictionary = {}
var _disk_check_done: Dictionary = {}

# Pulse animation clock
var _anim_time: float = 0.0

# Overlay zoom buttons
var _btn_zoom_in: Button
var _btn_zoom_out: Button

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	DirAccess.make_dir_recursive_absolute(TILE_CACHE_DIR)

	for i in range(WORKER_COUNT):
		var req := HTTPRequest.new()
		req.name = "TileWorker_%d" % i
		req.timeout = 7.0
		add_child(req)
		var worker_idx: int = i
		req.request_completed.connect(
			func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
				_on_tile_worker_completed(worker_idx, result, code, headers, body)
		)
		_tile_workers.append(req)
		_worker_tile_keys.append("")

	_build_zoom_buttons()
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_reposition_zoom_buttons)
	call_deferred("_reposition_zoom_buttons")

func _build_zoom_buttons() -> void:
	_btn_zoom_in = Button.new()
	_btn_zoom_in.text = "+"
	_btn_zoom_in.tooltip_text = "Zoom In (Street Parcel Detail)"
	_btn_zoom_in.custom_minimum_size = Vector2(36.0, 34.0)
	_style_map_button(_btn_zoom_in)
	_btn_zoom_in.pressed.connect(zoom_in)
	add_child(_btn_zoom_in)

	_btn_zoom_out = Button.new()
	_btn_zoom_out.text = "−"
	_btn_zoom_out.tooltip_text = "Zoom Out (Neighborhood Radar)"
	_btn_zoom_out.custom_minimum_size = Vector2(36.0, 34.0)
	_style_map_button(_btn_zoom_out)
	_btn_zoom_out.pressed.connect(zoom_out)
	add_child(_btn_zoom_out)

func _style_map_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.15, 0.13, 0.94)
	normal.border_color = COL_HAZARD_YELLOW
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.27, 0.23, 0.98)
	hover.border_color = Color("#ffe074")

	var pressed_sb := normal.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = COL_ATOMIC_ORANGE
	pressed_sb.border_color = COL_PARCHMENT

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_color_override("font_color", COL_HAZARD_YELLOW)
	btn.add_theme_color_override("font_hover_color", Color("#fff4cf"))
	btn.add_theme_color_override("font_pressed_color", COL_INK_DARK)
	btn.add_theme_font_size_override("font_size", 20)

func _reposition_zoom_buttons() -> void:
	if not is_instance_valid(_btn_zoom_in) or not is_instance_valid(_btn_zoom_out):
		return
	var w: float = maxf(size.x, 400.0)
	var h: float = maxf(size.y, 300.0)
	_btn_zoom_in.position = Vector2(w - 48.0, h - 108.0)
	_btn_zoom_out.position = Vector2(w - 48.0, h - 68.0)

func set_map_data(parsed_data: Dictionary, recenter: bool = true) -> void:
	var b_v: Variant = parsed_data.get("buildings", [])
	_buildings = b_v if typeof(b_v) == TYPE_ARRAY else []
	var r_v: Variant = parsed_data.get("roads", [])
	_roads = r_v if typeof(r_v) == TYPE_ARRAY else []
	var pk_v: Variant = parsed_data.get("parks", [])
	_parks = pk_v if typeof(pk_v) == TYPE_ARRAY else []
	var p_v: Variant = parsed_data.get("pois", [])
	_all_pois = p_v if typeof(p_v) == TYPE_ARRAY else []

	_hovered_house = {}
	_highlighted_poi_id = -1

	if recenter:
		var c_lat: float = float(parsed_data.get("center_lat", center_lat))
		var c_lon: float = float(parsed_data.get("center_lon", center_lon))
		set_center_and_zoom(c_lat, c_lon, DEFAULT_ZOOM, true)
	else:
		queue_redraw()

func set_selected_house(bldg: Dictionary, nearby_targets: Array = []) -> void:
	_selected_house = bldg
	_nearby_targets = nearby_targets
	_neighbor_id_set.clear()
	for t_v in _nearby_targets:
		if typeof(t_v) == TYPE_DICTIONARY:
			var t: Dictionary = t_v
			if str(t.get("category", "")) == "neighbor_house":
				_neighbor_id_set[int(t.get("osm_id", -1))] = true
	queue_redraw()

func set_hovered_house_by_id(osm_id: int) -> void:
	if osm_id <= 0:
		_hovered_house = {}
		queue_redraw()
		return
	for b_v in _buildings:
		if typeof(b_v) == TYPE_DICTIONARY:
			var b: Dictionary = b_v
			if int(b.get("osm_id", 0)) == osm_id:
				_hovered_house = b
				house_hovered.emit(_hovered_house)
				queue_redraw()
				return

func set_highlighted_poi_id(osm_id: int) -> void:
	_highlighted_poi_id = osm_id
	queue_redraw()

func set_center_and_zoom(lat: float, lon: float, new_zoom: int = -1, immediate: bool = true) -> void:
	var target_z: int = clampi(new_zoom if new_zoom > 0 else zoom, MIN_ZOOM, MAX_ZOOM)
	zoom = target_z
	if immediate:
		_pan_active = false
		center_lat = clampf(lat, -85.0, 85.0)
		center_lon = clampf(lon, -179.99, 179.99)
		view_changed.emit(center_lat, center_lon, zoom)
		queue_redraw()
	else:
		pan_smooth_to(lat, lon, 0.75)

func pan_smooth_to(lat: float, lon: float, duration: float = 0.85) -> void:
	_pan_from_lat = center_lat
	_pan_from_lon = center_lon
	_pan_to_lat = clampf(lat, -85.0, 85.0)
	_pan_to_lon = clampf(lon, -179.99, 179.99)
	_pan_elapsed = 0.0
	_pan_duration = maxf(0.08, duration)
	_pan_active = true

func zoom_in() -> void:
	if zoom < MAX_ZOOM:
		_play_ui_tick()
		zoom += 1
		view_changed.emit(center_lat, center_lon, zoom)
		queue_redraw()

func zoom_out() -> void:
	if zoom > MIN_ZOOM:
		_play_ui_tick()
		zoom -= 1
		view_changed.emit(center_lat, center_lon, zoom)
		queue_redraw()

func _process(delta: float) -> void:
	_anim_time += delta
	var needs_draw: bool = not _selected_house.is_empty()

	if _pan_active:
		_pan_elapsed += delta
		var t: float = clampf(_pan_elapsed / _pan_duration, 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		center_lat = lerpf(_pan_from_lat, _pan_to_lat, smooth_t)
		center_lon = lerpf(_pan_from_lon, _pan_to_lon, smooth_t)
		if t >= 1.0:
			_pan_active = false
			view_changed.emit(center_lat, center_lon, zoom)
		needs_draw = true

	_pump_tile_queue()

	if needs_draw:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_screen_pos(mb.position, 1)
			accept_event()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_screen_pos(mb.position, -1)
			accept_event()
			return
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				_is_dragging = false
				_press_pos = mb.position
				_last_mouse_pos = mb.position
				_pan_active = false
			else:
				var was_dragging: bool = _is_dragging
				_mouse_down = false
				_is_dragging = false
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				if not was_dragging:
					_handle_map_click(mb.position)
			accept_event()
			return

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_mouse_inside = true
		_last_mouse_pos = mm.position
		if _mouse_down:
			if not _is_dragging and mm.position.distance_to(_press_pos) > 5.5:
				_is_dragging = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			if _is_dragging:
				_pan_by_pixels(-mm.relative)
				queue_redraw()
		else:
			_update_hover_at(mm.position)

func _on_mouse_exited() -> void:
	_mouse_inside = false
	if not _hovered_house.is_empty():
		_hovered_house = {}
		queue_redraw()

func _zoom_at_screen_pos(cursor_pos: Vector2, delta_z: int) -> void:
	var next_z: int = clampi(zoom + delta_z, MIN_ZOOM, MAX_ZOOM)
	if next_z == zoom:
		return
	var anchor_lonlat: Vector2 = screen_to_latlon(cursor_pos)
	zoom = next_z
	var after_screen: Vector2 = latlon_to_screen(anchor_lonlat.y, anchor_lonlat.x)
	var pixel_err: Vector2 = after_screen - cursor_pos
	_pan_by_pixels(pixel_err)
	_play_ui_tick()
	view_changed.emit(center_lat, center_lon, zoom)
	queue_redraw()

func _pan_by_pixels(pixel_delta: Vector2) -> void:
	var cx: float = _lon_to_world_x(center_lon, zoom) + pixel_delta.x
	var cy: float = _lat_to_world_y(center_lat, zoom) + pixel_delta.y
	var max_world: float = TILE_SIZE * pow(2.0, float(zoom))
	cx = fposmod(cx, max_world)
	cy = clampf(cy, 0.0, max_world)
	center_lon = _world_x_to_lon(cx, zoom)
	center_lat = _world_y_to_lat(cy, zoom)

func _handle_map_click(click_pos: Vector2) -> void:
	var hit: Dictionary = _pick_building_at(click_pos)
	if not hit.is_empty():
		_play_select_sfx()
		house_clicked.emit(hit)

func _update_hover_at(pos: Vector2) -> void:
	var hit: Dictionary = _pick_building_at(pos)
	var old_id: int = int(_hovered_house.get("osm_id", -1))
	var new_id: int = int(hit.get("osm_id", -1))
	if old_id != new_id:
		_hovered_house = hit
		if not _hovered_house.is_empty():
			house_hovered.emit(_hovered_house)
		queue_redraw()
	elif not _hovered_house.is_empty():
		queue_redraw()

func _pick_building_at(pos: Vector2) -> Dictionary:
	# Exact polygon hit test first (reverse order so foreground parcels win)
	for i in range(_visible_bldg_hit_cache.size() - 1, -1, -1):
		var item: Dictionary = _visible_bldg_hit_cache[i]
		var rect_b: Rect2 = item.get("bounds", Rect2())
		if not rect_b.grow(2.0).has_point(pos):
			continue
		var poly: PackedVector2Array = item.get("poly", PackedVector2Array())
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(pos, poly):
			var b_dict: Dictionary = item.get("bldg", {})
			return b_dict

	# Generous 14px proximity fallback for small houses at lower zoom
	var best_dist: float = 14.0
	var best_bldg: Dictionary = {}
	for item_v in _visible_bldg_hit_cache:
		var item: Dictionary = item_v
		var c_scr: Vector2 = item.get("center", Vector2(-999.0, -999.0))
		var d: float = pos.distance_to(c_scr)
		if d < best_dist:
			best_dist = d
			best_bldg = item.get("bldg", {})
	return best_bldg

# --- Web Mercator Projection ---

func latlon_to_screen(lat: float, lon: float) -> Vector2:
	var cx: float = _lon_to_world_x(center_lon, zoom)
	var cy: float = _lat_to_world_y(center_lat, zoom)
	var wx: float = _lon_to_world_x(lon, zoom)
	var wy: float = _lat_to_world_y(lat, zoom)
	return size * 0.5 + Vector2(wx - cx, wy - cy)

func screen_to_latlon(screen_pos: Vector2) -> Vector2:
	var wx: float = _lon_to_world_x(center_lon, zoom) + (screen_pos.x - size.x * 0.5)
	var wy: float = _lat_to_world_y(center_lat, zoom) + (screen_pos.y - size.y * 0.5)
	return Vector2(_world_x_to_lon(wx, zoom), _world_y_to_lat(wy, zoom))

func get_meters_per_pixel() -> float:
	return (156543.03392 * maxf(0.15, cos(deg_to_rad(center_lat)))) / pow(2.0, float(zoom))

static func _lon_to_world_x(lon: float, z: int) -> float:
	return ((lon + 180.0) / 360.0) * TILE_SIZE * pow(2.0, float(z))

static func _lat_to_world_y(lat: float, z: int) -> float:
	var clamped_lat: float = clampf(lat, -85.05112878, 85.05112878)
	var lat_rad: float = deg_to_rad(clamped_lat)
	var merc: float = (1.0 - log(tan(lat_rad) + (1.0 / cos(lat_rad))) / PI) * 0.5
	return merc * TILE_SIZE * pow(2.0, float(z))

static func _world_x_to_lon(wx: float, z: int) -> float:
	var world_span: float = TILE_SIZE * pow(2.0, float(z))
	return (wx / world_span) * 360.0 - 180.0

static func _world_y_to_lat(wy: float, z: int) -> float:
	var world_span: float = TILE_SIZE * pow(2.0, float(z))
	var n: float = PI - (2.0 * PI * wy) / world_span
	return rad_to_deg(atan(sinh(n)))

# --- Async Slippy Tile Pipeline ---

func _request_tile(z: int, tx: int, ty: int) -> void:
	var max_t: int = int(pow(2.0, float(z)))
	if ty < 0 or ty >= max_t:
		return
	var wrapped_x: int = posmod(tx, max_t)
	var key: String = "%d/%d/%d" % [z, wrapped_x, ty]

	if _tile_textures.has(key) or _in_flight_set.has(key) or _queued_set.has(key) or _failed_tiles.has(key):
		return

	# Check disk cache once before queuing network fetch
	if not _disk_check_done.has(key):
		_disk_check_done[key] = true
		var disk_path: String = "%s/z%d_x%d_y%d.png" % [TILE_CACHE_DIR, z, wrapped_x, ty]
		if FileAccess.file_exists(disk_path):
			var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(disk_path)
			if raw_bytes.size() > 64:
				var img := Image.new()
				if img.load_png_from_buffer(raw_bytes) == OK:
					_store_tile_texture(key, ImageTexture.create_from_image(img))
					return

	_queued_set[key] = true
	_queued_keys.append(key)

func _pump_tile_queue() -> void:
	if _queued_keys.is_empty():
		return

	for i in range(WORKER_COUNT):
		if _queued_keys.is_empty():
			break
		if not _worker_tile_keys[i].is_empty():
			continue

		# Prefer queued tiles matching current zoom level
		var pick_idx: int = -1
		var z_prefix: String = "%d/" % zoom
		for q_i in range(_queued_keys.size() - 1, -1, -1):
			if _queued_keys[q_i].begins_with(z_prefix):
				pick_idx = q_i
				break
		if pick_idx == -1:
			pick_idx = _queued_keys.size() - 1

		var key: String = _queued_keys[pick_idx]
		_queued_keys.remove_at(pick_idx)
		_queued_set.erase(key)

		var parts: PackedStringArray = key.split("/")
		if parts.size() != 3:
			continue
		var z: int = int(parts[0])
		var tx: int = int(parts[1])
		var ty: int = int(parts[2])

		var url: String = TILE_URL_TEMPLATE % [z, tx, ty]
		var headers: PackedStringArray = PackedStringArray() if OS.has_feature("web") else PackedStringArray([USER_AGENT_HEADER])
		var err: int = _tile_workers[i].request(url, headers, HTTPClient.METHOD_GET)
		if err == OK:
			_worker_tile_keys[i] = key
			_in_flight_set[key] = true
		else:
			_failed_tiles[key] = true

func _on_tile_worker_completed(worker_idx: int, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var key: String = _worker_tile_keys[worker_idx]
	_worker_tile_keys[worker_idx] = ""
	_in_flight_set.erase(key)

	if key.is_empty():
		return

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and body.size() > 64:
		var img := Image.new()
		if img.load_png_from_buffer(body) == OK:
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			_store_tile_texture(key, tex)
			var parts: PackedStringArray = key.split("/")
			if parts.size() == 3:
				var disk_path: String = "%s/z%s_x%s_y%s.png" % [TILE_CACHE_DIR, parts[0], parts[1], parts[2]]
				var f: FileAccess = FileAccess.open(disk_path, FileAccess.WRITE)
				if f != null:
					f.store_buffer(body)
					f.close()
			queue_redraw()
			return

	_failed_tiles[key] = true

func _store_tile_texture(key: String, tex: Texture2D) -> void:
	if not _tile_textures.has(key):
		_tile_order.append(key)
	_tile_textures[key] = tex
	while _tile_order.size() > MAX_MEM_TILES:
		var oldest: String = _tile_order[0]
		_tile_order.remove_at(0)
		_tile_textures.erase(oldest)

# --- Multi-Layered Cartographic & Tactical Rendering ---

func _draw() -> void:
	var vp_rect := Rect2(Vector2.ZERO, size)
	if vp_rect.size.x < 10.0 or vp_rect.size.y < 10.0:
		return

	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	# 1. Warm Civil Defense survey drafting paper background + grid
	draw_rect(vp_rect, COL_PAPER_BASE, true)
	_draw_survey_grid(vp_rect)

	# 2. Slippy 256x256 OpenStreetMap PNG tiles (with parent zoom fallback)
	var tile_coverage_ratio: float = _draw_slippy_tiles(vp_rect)

	# 3. Architectural vector basemap (parks, water, roads) — stronger alpha before tiles arrive!
	var vector_boost: float = 1.0 - tile_coverage_ratio * 0.65
	_draw_parks_vector(vp_rect, vector_boost)
	_draw_roads_vector(vp_rect, font, tile_coverage_ratio < 0.5)

	# 4. Tactical range rings & sightlines around selected house (underneath badges)
	var has_selected: bool = not _selected_house.is_empty()
	var sel_screen := Vector2.ZERO
	if has_selected:
		sel_screen = latlon_to_screen(
			float(_selected_house.get("lat", center_lat)),
			float(_selected_house.get("lon", center_lon))
		)
		_draw_range_rings_and_links(sel_screen, font)

	# 5. Interactive OSM building polygons
	_draw_building_parcels(vp_rect)

	# 6. Nearby real-world POI badges (Churches, Supermarkets, Pharmacies, Police/Fire, Hardware, Schools, Neighbors)
	_draw_poi_markers(vp_rect, font, has_selected, sel_screen)

	# 7. Selected House Bunker Hatch reticle & banner (drawn prominently on top)
	if has_selected:
		_draw_selected_house_reticle(sel_screen, vp_rect, font)

	# 8. Map HUD furniture (North compass rose, metric scale bar, zoom indicator, OSM attribution, border)
	_draw_map_hud_chrome(vp_rect, font)

	# 9. Floating hover tooltip for building under cursor
	if _mouse_inside and not _is_dragging and not _hovered_house.is_empty():
		_draw_hover_tooltip(vp_rect, font)

func _draw_survey_grid(vp_rect: Rect2) -> void:
	var step: float = 64.0
	var x: float = fposmod(-_lon_to_world_x(center_lon, zoom) + size.x * 0.5, step)
	while x < vp_rect.size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, vp_rect.size.y), COL_GRID_LINE, 1.0)
		x += step
	var y: float = fposmod(-_lat_to_world_y(center_lat, zoom) + size.y * 0.5, step)
	while y < vp_rect.size.y:
		draw_line(Vector2(0.0, y), Vector2(vp_rect.size.x, y), COL_GRID_LINE, 1.0)
		y += step

func _draw_slippy_tiles(vp_rect: Rect2) -> float:
	var cx: float = _lon_to_world_x(center_lon, zoom)
	var cy: float = _lat_to_world_y(center_lat, zoom)
	var left_wx: float = cx - vp_rect.size.x * 0.5
	var top_wy: float = cy - vp_rect.size.y * 0.5

	var min_tx: int = int(floor(left_wx / TILE_SIZE))
	var max_tx: int = int(floor((left_wx + vp_rect.size.x) / TILE_SIZE))
	var min_ty: int = int(floor(top_wy / TILE_SIZE))
	var max_ty: int = int(floor((top_wy + vp_rect.size.y) / TILE_SIZE))
	var max_tile_index: int = int(pow(2.0, float(zoom)))

	var total_visible: int = 0
	var loaded_visible: int = 0
	var tile_modulate := Color(0.97, 0.94, 0.87, 0.90)

	for ty in range(min_ty, max_ty + 1):
		if ty < 0 or ty >= max_tile_index:
			continue
		for tx in range(min_tx, max_tx + 1):
			total_visible += 1
			var wrapped_tx: int = posmod(tx, max_tile_index)
			var key: String = "%d/%d/%d" % [zoom, wrapped_tx, ty]
			var screen_pos := Vector2(
				float(tx) * TILE_SIZE - left_wx,
				float(ty) * TILE_SIZE - top_wy
			)
			var dst_rect := Rect2(screen_pos, Vector2(TILE_SIZE, TILE_SIZE))

			if _tile_textures.has(key):
				var tex: Texture2D = _tile_textures[key]
				draw_texture_rect(tex, dst_rect, false, tile_modulate)
				loaded_visible += 1
			else:
				# Try parent z-1 tile quadrant while sharper tile streams in
				if zoom > MIN_ZOOM:
					var parent_key: String = "%d/%d/%d" % [zoom - 1, int(wrapped_tx / 2), int(ty / 2)]
					if _tile_textures.has(parent_key):
						var p_tex: Texture2D = _tile_textures[parent_key]
						var sub_x: float = float(wrapped_tx % 2) * 128.0
						var sub_y: float = float(ty % 2) * 128.0
						draw_texture_rect_region(p_tex, dst_rect, Rect2(sub_x, sub_y, 128.0, 128.0), Color(0.96, 0.93, 0.85, 0.78))
				_request_tile(zoom, wrapped_tx, ty)

	if total_visible <= 0:
		return 0.0
	return float(loaded_visible) / float(total_visible)

func _draw_parks_vector(vp_rect: Rect2, alpha_scale: float) -> void:
	var cull_rect: Rect2 = vp_rect.grow(90.0)
	for pk_v in _parks:
		var pk: Dictionary = pk_v
		var pts_ll_v: Variant = pk.get("polygon_latlon", [])
		var pts_ll: Array = pts_ll_v if typeof(pts_ll_v) == TYPE_ARRAY else []
		if pts_ll.size() < 3:
			continue

		var scr := PackedVector2Array()
		var bounds := Rect2()
		for i in range(pts_ll.size()):
			var ll: Vector2 = pts_ll[i]
			var sp: Vector2 = latlon_to_screen(ll.y, ll.x)
			scr.append(sp)
			if i == 0:
				bounds = Rect2(sp, Vector2.ZERO)
			else:
				bounds = bounds.expand(sp)

		if not cull_rect.intersects(bounds):
			continue

		var kind: String = str(pk.get("kind", "park"))
		var fill_col: Color = COL_WATER_FILL if kind == "water" else COL_PARK_FILL
		fill_col.a *= clampf(alpha_scale, 0.35, 1.0)
		_safe_draw_filled_polygon(scr, fill_col)

func _draw_roads_vector(vp_rect: Rect2, font: Font, draw_labels: bool) -> void:
	var cull_rect: Rect2 = vp_rect.grow(80.0)
	var zoom_scale: float = pow(1.45, float(zoom - 16))
	var alpha_mult: float = 0.92 if draw_labels else 0.34

	var labeled_names: Dictionary = {}

	# Pass 1: Dark road casings
	var visible_roads: Array = []
	for r_v in _roads:
		var r: Dictionary = r_v
		var kind: String = str(r.get("kind", "residential"))
		if kind in ["footway", "path", "steps", "cycleway", "service"] and zoom < 17 and not draw_labels:
			continue

		var pts_ll_v: Variant = r.get("points_latlon", [])
		var pts_ll: Array = pts_ll_v if typeof(pts_ll_v) == TYPE_ARRAY else []
		if pts_ll.size() < 2:
			continue

		var scr := PackedVector2Array()
		var bounds := Rect2()
		for i in range(pts_ll.size()):
			var ll: Vector2 = pts_ll[i]
			var sp: Vector2 = latlon_to_screen(ll.y, ll.x)
			scr.append(sp)
			if i == 0:
				bounds = Rect2(sp, Vector2.ZERO)
			else:
				bounds = bounds.expand(sp)

		if not cull_rect.intersects(bounds):
			continue

		var base_w: float = _road_base_width(kind) * zoom_scale
		visible_roads.append({"scr": scr, "kind": kind, "width": base_w, "name": str(r.get("name", ""))})

		if base_w >= 3.0:
			var case_col := COL_ROAD_CASE
			case_col.a *= alpha_mult
			draw_polyline(scr, case_col, base_w + 2.2, true)

	# Pass 2: Warm roadway fills + crisp street labels when PNG tiles haven't arrived yet
	for vr_v in visible_roads:
		var vr: Dictionary = vr_v
		var scr_pts: PackedVector2Array = vr.get("scr", PackedVector2Array())
		var kind_s: String = str(vr.get("kind", "residential"))
		var w: float = float(vr.get("width", 4.0))
		var is_major: bool = kind_s in ["motorway", "trunk", "primary", "secondary", "tertiary"]
		var fill_col: Color = COL_ROAD_MAIN if is_major else COL_ROAD_LOCAL
		fill_col.a = alpha_mult
		draw_polyline(scr_pts, fill_col, maxf(1.2, w), true)

		if draw_labels:
			var rname: String = str(vr.get("name", ""))
			if not rname.is_empty() and not labeled_names.has(rname) and scr_pts.size() >= 2 and w >= 4.0:
				var mid_idx: int = int(scr_pts.size() / 2)
				var p_a: Vector2 = scr_pts[maxi(0, mid_idx - 1)]
				var p_b: Vector2 = scr_pts[mini(scr_pts.size() - 1, mid_idx)]
				if p_a.distance_to(p_b) > 48.0 and vp_rect.grow(-50.0).has_point((p_a + p_b) * 0.5):
					labeled_names[rname] = true
					var label_pos: Vector2 = (p_a + p_b) * 0.5 + Vector2(-float(rname.length()) * 2.8, 4.0)
					draw_string_outline(font, label_pos, rname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.96, 0.92, 0.82, 0.92))
					draw_string(font, label_pos, rname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.18, 0.16, 0.13, 0.92))

func _road_base_width(kind: String) -> float:
	match kind:
		"motorway", "trunk":
			return 9.5
		"primary":
			return 8.0
		"secondary":
			return 6.8
		"tertiary":
			return 5.8
		"residential", "unclassified", "living_street":
			return 4.6
		"service":
			return 2.6
		_:
			return 1.8

func _draw_building_parcels(vp_rect: Rect2) -> void:
	_visible_bldg_hit_cache.clear()
	var cull_rect: Rect2 = vp_rect.grow(40.0)
	var sel_id: int = int(_selected_house.get("osm_id", -1))
	var hov_id: int = int(_hovered_house.get("osm_id", -1))
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 5.2)

	var selected_draw_entry: Dictionary = {}
	var hovered_draw_entry: Dictionary = {}

	for b_v in _buildings:
		var b: Dictionary = b_v
		var bid: int = int(b.get("osm_id", 0))
		var poly_ll_v: Variant = b.get("polygon_latlon", [])
		var poly_ll: Array = poly_ll_v if typeof(poly_ll_v) == TYPE_ARRAY else []

		var scr := PackedVector2Array()
		var bounds := Rect2()

		if poly_ll.size() >= 3:
			for i in range(poly_ll.size()):
				var ll: Vector2 = poly_ll[i]
				var sp: Vector2 = latlon_to_screen(ll.y, ll.x)
				scr.append(sp)
				if i == 0:
					bounds = Rect2(sp, Vector2.ZERO)
				else:
					bounds = bounds.expand(sp)
		else:
			# Reconstruct from footprint_meters if polygon_latlon wasn't supplied
			var blat: float = float(b.get("lat", center_lat))
			var blon: float = float(b.get("lon", center_lon))
			var c_sp: Vector2 = latlon_to_screen(blat, blon)
			var mpp: float = maxf(0.1, get_meters_per_pixel())
			var fp_v: Variant = b.get("footprint_meters", [])
			if typeof(fp_v) == TYPE_ARRAY:
				var fp_arr: Array = fp_v
				for i in range(fp_arr.size()):
					var mv: Vector2 = fp_arr[i]
					var sp_m: Vector2 = c_sp + mv / mpp
					scr.append(sp_m)
					if i == 0:
						bounds = Rect2(sp_m, Vector2.ZERO)
					else:
						bounds = bounds.expand(sp_m)

		if scr.size() < 3 or not cull_rect.intersects(bounds):
			continue

		var c_screen: Vector2 = latlon_to_screen(float(b.get("lat", center_lat)), float(b.get("lon", center_lon)))
		var entry: Dictionary = {
			"bldg": b,
			"poly": scr,
			"bounds": bounds,
			"center": c_screen
		}
		_visible_bldg_hit_cache.append(entry)

		if bid == sel_id:
			selected_draw_entry = entry
			continue
		if bid == hov_id:
			hovered_draw_entry = entry
			continue

		var is_res: bool = bool(b.get("is_residential", true))
		var is_neighbor: bool = _neighbor_id_set.has(bid)
		var fill_col: Color = COL_BLDG_NEIGHBOR if is_neighbor else (COL_BLDG_RES if is_res else COL_BLDG_COMM)
		_safe_draw_filled_polygon(scr, fill_col)
		_draw_closed_outline(scr, COL_BLDG_OUTLINE, 1.4 if is_neighbor else 1.1)

	# Draw hovered house on top in bright translucent CONELRAD hazard yellow
	if not hovered_draw_entry.is_empty():
		var h_poly: PackedVector2Array = hovered_draw_entry.get("poly", PackedVector2Array())
		_safe_draw_filled_polygon(h_poly, COL_HOVER_FILL)
		_draw_closed_outline(h_poly, COL_INK_DARK, 3.4)
		_draw_closed_outline(h_poly, COL_HAZARD_YELLOW, 2.0)

	# Draw selected house ("YOUR HOUSE") with bold pulsing orange/yellow Civil Defense highlight
	if not selected_draw_entry.is_empty():
		var s_poly: PackedVector2Array = selected_draw_entry.get("poly", PackedVector2Array())
		var glow_col := Color(0.96, 0.75, 0.18, 0.35 + 0.30 * pulse)
		_draw_closed_outline(s_poly, glow_col, 7.5 + 2.5 * pulse)
		_safe_draw_filled_polygon(s_poly, COL_SELECT_FILL)
		_draw_closed_outline(s_poly, COL_INK_DARK, 4.0)
		_draw_closed_outline(s_poly, COL_HAZARD_YELLOW.lerp(Color.WHITE, 0.25 * pulse), 2.3)

func _draw_range_rings_and_links(sel_screen: Vector2, font: Font) -> void:
	var mpp: float = maxf(0.12, get_meters_per_pixel())
	var r_150: float = 150.0 / mpp
	var r_300: float = 300.0 / mpp

	_draw_dashed_circle(sel_screen, r_150, Color(0.32, 0.62, 0.24, 0.72), 1.8, 44)
	_draw_dashed_circle(sel_screen, r_300, Color(0.86, 0.34, 0.16, 0.65), 1.8, 64)

	# Range ring pill tags
	if r_150 > 38.0:
		_draw_micro_pill(font, sel_screen + Vector2(r_150 * 0.707 - 26.0, -r_150 * 0.707 - 8.0), "150m", Color(0.14, 0.22, 0.13, 0.88), COL_SAFE_GREEN)
	if r_300 > 70.0:
		_draw_micro_pill(font, sel_screen + Vector2(r_300 * 0.707 - 26.0, -r_300 * 0.707 - 8.0), "300m", Color(0.24, 0.13, 0.10, 0.88), COL_ATOMIC_ORANGE)

	# Dashed tactical bearing lines to key POIs (Churches, Groceries, Pharmacies, Hardware, Schools)
	var drawn_links: int = 0
	for t_v in _nearby_targets:
		var t: Dictionary = t_v
		var cat: String = str(t.get("category", ""))
		var tid: int = int(t.get("osm_id", -1))
		var is_hi: bool = (tid == _highlighted_poi_id)
		if cat == "neighbor_house" and not is_hi:
			continue
		if drawn_links >= 6 and not is_hi:
			continue
		var p_scr: Vector2 = latlon_to_screen(float(t.get("lat", 0.0)), float(t.get("lon", 0.0)))
		if p_scr.distance_to(sel_screen) < 12.0:
			continue
		var line_col: Color = _category_accent_color(cat)
		line_col.a = 0.88 if is_hi else 0.44
		draw_dashed_line(sel_screen, p_scr, line_col, 2.4 if is_hi else 1.4, 6.0, true, true)
		drawn_links += 1

func _get_selected_house_pill_rect(sel_screen: Vector2, vp_rect: Rect2, font: Font) -> Rect2:
	var label_str := "★ YOUR HOUSE"
	var text_w: float = font.get_string_size(label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var pill_w: float = maxf(98.0, ceilf(text_w + 16.0))
	var pill_h: float = 18.0
	var px: float = clampf(sel_screen.x - pill_w * 0.5, 8.0, maxf(8.0, vp_rect.size.x - pill_w - 8.0))
	var py: float = sel_screen.y - 34.0
	if py < 40.0:
		py = sel_screen.y + 16.0
	return Rect2(px, py, pill_w, pill_h)

func _rect_intersects_any(cand: Rect2, occupied: Array[Rect2]) -> bool:
	for occ in occupied:
		if cand.intersects(occ):
			return true
	return false

func _draw_poi_markers(vp_rect: Rect2, font: Font, has_selected: bool = false, sel_screen: Vector2 = Vector2.ZERO) -> void:
	var cull_rect: Rect2 = vp_rect.grow(32.0)
	var source_list: Array = _nearby_targets if not _nearby_targets.is_empty() else _all_pois

	# Seed screen-space occupied_rects so POI labels never overlap HUD chrome, YOUR HOUSE, or badges
	var occupied_rects: Array[Rect2] = []
	occupied_rects.append(Rect2(0.0, 0.0, vp_rect.size.x, 40.0))
	occupied_rects.append(Rect2(4.0, 8.0, 50.0, 48.0))
	occupied_rects.append(Rect2(0.0, maxf(0.0, vp_rect.size.y - 32.0), vp_rect.size.x, 32.0))
	occupied_rects.append(Rect2(8.0, maxf(0.0, vp_rect.size.y - 46.0), 175.0, 40.0))
	occupied_rects.append(Rect2(maxf(0.0, vp_rect.size.x - 52.0), maxf(0.0, vp_rect.size.y - 138.0), 46.0, 110.0))

	var house_reticle_rect := Rect2()
	var house_pill_rect := Rect2()
	if has_selected:
		house_reticle_rect = Rect2(sel_screen - Vector2(20.0, 20.0), Vector2(40.0, 40.0))
		house_pill_rect = _get_selected_house_pill_rect(sel_screen, vp_rect, font).grow(3.0)
		occupied_rects.append(house_reticle_rect)
		occupied_rects.append(house_pill_rect)

		var mpp: float = maxf(0.12, get_meters_per_pixel())
		var r_150: float = 150.0 / mpp
		var r_300: float = 300.0 / mpp
		if r_150 > 38.0:
			occupied_rects.append(Rect2(sel_screen + Vector2(r_150 * 0.707 - 26.0, -r_150 * 0.707 - 8.0), Vector2(40.0, 16.0)))
		if r_300 > 70.0:
			occupied_rects.append(Rect2(sel_screen + Vector2(r_300 * 0.707 - 26.0, -r_300 * 0.707 - 8.0), Vector2(40.0, 16.0)))

	# Pass 1: Project visible POIs, reserve all badge circles, and draw non-highlighted badges
	var visible_entries: Array = []
	var highlighted_entry: Dictionary = {}
	for p_v in source_list:
		var p: Dictionary = p_v
		var cat: String = str(p.get("category", "grocery"))
		var pid: int = int(p.get("osm_id", -2))
		var sp: Vector2 = latlon_to_screen(float(p.get("lat", 0.0)), float(p.get("lon", 0.0)))
		if not cull_rect.has_point(sp):
			continue

		occupied_rects.append(Rect2(sp - Vector2(11.0, 11.0), Vector2(22.0, 22.0)))

		var is_hi: bool = (pid == _highlighted_poi_id)
		var entry: Dictionary = {"poi": p, "cat": cat, "sp": sp, "is_hi": is_hi}
		if is_hi:
			highlighted_entry = entry
		else:
			if cat == "neighbor_house":
				draw_poi_badge(self, sp, 7.0, cat, false)
			else:
				draw_poi_badge(self, sp, 10.5, cat, false)
			visible_entries.append(entry)

	if not highlighted_entry.is_empty():
		var h_cat: String = str(highlighted_entry.get("cat", "grocery"))
		var h_sp: Vector2 = highlighted_entry.get("sp", Vector2.ZERO)
		draw_poi_badge(self, h_sp, 10.5 if h_cat == "neighbor_house" else 13.5, h_cat, true)

	# Pass 2: Place non-overlapping POI callout pills (highlighted POI gets top priority)
	var label_queue: Array = []
	if not highlighted_entry.is_empty():
		label_queue.append(highlighted_entry)
	for ve_v in visible_entries:
		var ve: Dictionary = ve_v
		var v_cat: String = str(ve.get("cat", ""))
		if v_cat in ["church", "grocery", "pharmacy", "civic", "school", "hardware"]:
			label_queue.append(ve)

	var safe_map_rect := Rect2(
		6.0,
		40.0,
		maxf(20.0, vp_rect.size.x - 12.0),
		maxf(20.0, vp_rect.size.y - 72.0)
	)
	var font_size: int = 10
	var font_h: float = font.get_height(font_size)
	var font_ascent: float = font.get_ascent(font_size)
	var pill_h: float = 16.0
	var labeled_count: int = 0

	for lq_v in label_queue:
		var item: Dictionary = lq_v
		var is_hi: bool = bool(item.get("is_hi", false))
		if not is_hi and labeled_count >= 6:
			continue

		var p: Dictionary = item.get("poi", {})
		var sp: Vector2 = item.get("sp", Vector2.ZERO)
		var pname: String = str(p.get("name", ""))
		if pname.length() > 24:
			pname = pname.substr(0, 22) + ".."
		var dist_val: int = int(p.get("distance_m", 0))
		var tag_txt: String = ("%s (%dm)" % [pname, dist_val]) if dist_val > 0 else pname

		var text_w: float = font.get_string_size(tag_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pad_x: float = 5.0
		var w: float = ceilf(text_w + pad_x * 2.0)

		# Priority order: Right, Below, Above (-13 - pill_h clears sp.y - 11 badge box), Left
		var candidates: Array[Rect2] = [
			Rect2(sp + Vector2(13.0, -8.0), Vector2(w, pill_h)),
			Rect2(sp + Vector2(-w * 0.5, 13.0), Vector2(w, pill_h)),
			Rect2(sp + Vector2(-w * 0.5, -13.0 - pill_h), Vector2(w, pill_h)),
			Rect2(sp + Vector2(-w - 13.0, -8.0), Vector2(w, pill_h))
		]

		var chosen_rect := Rect2()
		var found: bool = false
		for cand in candidates:
			if safe_map_rect.encloses(cand) and not _rect_intersects_any(cand, occupied_rects):
				chosen_rect = cand
				found = true
				break

		# Only force-draw a fallback callout if actively hovered/highlighted by the player
		if not found and is_hi:
			for cand_hi in candidates:
				var clamped_pos := Vector2(
					clampf(cand_hi.position.x, 6.0, maxf(6.0, vp_rect.size.x - w - 6.0)),
					clampf(cand_hi.position.y, 40.0, maxf(40.0, vp_rect.size.y - pill_h - 32.0))
				)
				var clamped_rect := Rect2(clamped_pos, Vector2(w, pill_h))
				if not has_selected or (not clamped_rect.intersects(house_pill_rect) and not clamped_rect.intersects(house_reticle_rect)):
					chosen_rect = clamped_rect
					found = true
					break

		if not found:
			continue

		var bg_col: Color = Color(0.13, 0.14, 0.11, 0.95) if is_hi else Color(0.09, 0.10, 0.09, 0.84)
		var border_col: Color = COL_HAZARD_YELLOW if is_hi else Color(0.92, 0.86, 0.72, 0.42)
		var text_col: Color = COL_HAZARD_YELLOW if is_hi else COL_PARCHMENT
		draw_rect(chosen_rect, bg_col, true)
		draw_rect(chosen_rect, border_col, false, 1.4 if is_hi else 1.0)

		var baseline_y: float = chosen_rect.position.y + (pill_h - font_h) * 0.5 + font_ascent
		draw_string(font, Vector2(chosen_rect.position.x + pad_x, baseline_y), tag_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

		occupied_rects.append(chosen_rect.grow(2.0))
		if not is_hi:
			labeled_count += 1

func _draw_selected_house_reticle(sel_screen: Vector2, vp_rect: Rect2, font: Font) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 5.0)
	var ring_r: float = 13.0 + 2.5 * pulse

	# Bunker Hatch wheel icon at selected house centroid
	draw_circle(sel_screen, 10.5, COL_INK_DARK)
	draw_circle(sel_screen, 8.5, COL_HAZARD_YELLOW)
	draw_circle(sel_screen, 6.2, COL_INK_DARK)
	for spoke in range(3):
		var ang: float = float(spoke) * TAU / 3.0 + _anim_time * 0.9
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(sel_screen - dir * 5.5, sel_screen + dir * 5.5, COL_HAZARD_YELLOW, 1.8, true)
	draw_circle(sel_screen, 2.2, COL_ATOMIC_ORANGE)
	draw_arc(sel_screen, ring_r, 0.0, TAU, 32, COL_HAZARD_YELLOW, 2.0, true)

	# Bold "★ YOUR HOUSE" callout tag prominently on top
	var label_str := "★ YOUR HOUSE"
	var pill_rect: Rect2 = _get_selected_house_pill_rect(sel_screen, vp_rect, font)
	var text_w: float = font.get_string_size(label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var text_x: float = pill_rect.position.x + (pill_rect.size.x - text_w) * 0.5
	var text_y: float = pill_rect.position.y + (pill_rect.size.y - font.get_height(11)) * 0.5 + font.get_ascent(11)
	draw_rect(pill_rect, COL_INK_DARK, true)
	draw_rect(pill_rect, COL_HAZARD_YELLOW, false, 1.6)
	draw_string(font, Vector2(text_x, text_y), label_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_HAZARD_YELLOW)

func _draw_map_hud_chrome(vp_rect: Rect2, font: Font) -> void:
	# Outer tactical map bezel
	draw_rect(vp_rect, COL_INK_DARK, false, 3.0)
	draw_rect(vp_rect.grow(-2.0), Color(0.95, 0.74, 0.18, 0.55), false, 1.0)

	# Top-left North Compass Rose badge
	var comp_c := Vector2(30.0, 32.0)
	draw_circle(comp_c, 19.0, Color(0.11, 0.12, 0.11, 0.90))
	draw_arc(comp_c, 19.0, 0.0, TAU, 28, COL_HAZARD_YELLOW, 1.6, true)
	var north_tri := PackedVector2Array([
		comp_c + Vector2(0.0, -14.0),
		comp_c + Vector2(5.0, 2.0),
		comp_c + Vector2(-5.0, 2.0)
	])
	var south_tri := PackedVector2Array([
		comp_c + Vector2(0.0, 13.0),
		comp_c + Vector2(4.5, 2.0),
		comp_c + Vector2(-4.5, 2.0)
	])
	draw_colored_polygon(north_tri, COL_ATOMIC_ORANGE)
	draw_colored_polygon(south_tri, COL_PARCHMENT)
	draw_string(font, comp_c + Vector2(-4.0, -3.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_HAZARD_YELLOW)

	# Zoom badge above +/- buttons
	var z_box := Rect2(vp_rect.size.x - 48.0, vp_rect.size.y - 134.0, 36.0, 22.0)
	draw_rect(z_box, Color(0.11, 0.12, 0.11, 0.92), true)
	draw_rect(z_box, COL_HAZARD_YELLOW, false, 1.2)
	draw_string(font, z_box.position + Vector2(6.0, 15.0), "Z%d" % zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_PARCHMENT)

	# Bottom-left Metric Scale Bar
	var mpp: float = maxf(0.1, get_meters_per_pixel())
	var scale_meters: int = 50 if (100.0 / mpp > 165.0) else (100 if (100.0 / mpp > 55.0) else 200)
	var bar_px: float = float(scale_meters) / mpp
	var bar_origin := Vector2(14.0, vp_rect.size.y - 26.0)
	var scale_bg := Rect2(10.0, vp_rect.size.y - 44.0, bar_px + 54.0, 24.0)
	draw_rect(scale_bg, Color(0.11, 0.12, 0.11, 0.86), true)
	draw_line(bar_origin, bar_origin + Vector2(bar_px, 0.0), COL_HAZARD_YELLOW, 2.2)
	draw_line(bar_origin + Vector2(0.0, -5.0), bar_origin + Vector2(0.0, 3.0), COL_HAZARD_YELLOW, 2.0)
	draw_line(bar_origin + Vector2(bar_px, -5.0), bar_origin + Vector2(bar_px, 3.0), COL_HAZARD_YELLOW, 2.0)
	draw_string(font, bar_origin + Vector2(bar_px + 6.0, 2.0), "%dm" % scale_meters, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_PARCHMENT)

	# Bottom-right OpenStreetMap attribution strip
	var attr_text := "© OpenStreetMap contributors"
	var attr_w: float = 176.0
	var attr_rect := Rect2(vp_rect.size.x - attr_w - 8.0, vp_rect.size.y - 22.0, attr_w, 16.0)
	draw_rect(attr_rect, Color(0.10, 0.11, 0.10, 0.82), true)
	draw_string(font, attr_rect.position + Vector2(6.0, 12.0), attr_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.80, 0.68, 0.90))

func _draw_hover_tooltip(vp_rect: Rect2, font: Font) -> void:
	var addr: String = str(_hovered_house.get("short_address", str(_hovered_house.get("address", "Parcel"))))
	var area_val: int = int(round(float(_hovered_house.get("area_sqm", 110.0))))
	var rooms_val: int = int(_hovered_house.get("estimated_rooms", 5))
	var line1: String = "%s  |  %d m² (~%d rooms)" % [addr, area_val, rooms_val]
	var is_sel: bool = int(_hovered_house.get("osm_id", -1)) == int(_selected_house.get("osm_id", -2))
	var line2: String = "SELECTED AS YOUR HOUSE" if is_sel else "Click polygon to claim as YOUR HOUSE"

	var box_w: float = maxf(235.0, float(line1.length()) * 6.8 + 22.0)
	var box_h: float = 40.0
	var pos: Vector2 = _last_mouse_pos + Vector2(16.0, -46.0)
	pos.x = clampf(pos.x, 8.0, vp_rect.size.x - box_w - 8.0)
	pos.y = clampf(pos.y, 8.0, vp_rect.size.y - box_h - 8.0)

	var r := Rect2(pos, Vector2(box_w, box_h))
	draw_rect(r.grow(1.5), COL_INK_DARK, true)
	draw_rect(r, Color(0.14, 0.15, 0.13, 0.96), true)
	draw_rect(r, COL_HAZARD_YELLOW, false, 1.8)
	draw_string(font, pos + Vector2(9.0, 16.0), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_PARCHMENT)
	draw_string(font, pos + Vector2(9.0, 32.0), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_SAFE_GREEN if is_sel else COL_HAZARD_YELLOW)

static func draw_poi_badge(canvas: CanvasItem, center: Vector2, radius: float, category: String, highlighted: bool = false) -> void:
	var bg_col: Color = _category_accent_color(category)
	var rim_col: Color = COL_HAZARD_YELLOW if highlighted else COL_PARCHMENT

	if category == "neighbor_house":
		var pts := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.9, -radius * 0.15),
			center + Vector2(radius * 0.68, radius * 0.85),
			center + Vector2(-radius * 0.68, radius * 0.85),
			center + Vector2(-radius * 0.9, -radius * 0.15)
		])
		canvas.draw_colored_polygon(pts, COL_INK_DARK)
		var inner_pts := PackedVector2Array()
		for p in pts:
			inner_pts.append(center + (p - center) * 0.76)
		canvas.draw_colored_polygon(inner_pts, Color("#e8c872") if not highlighted else COL_HAZARD_YELLOW)
		return

	if highlighted:
		canvas.draw_circle(center, radius + 3.5, Color(0.96, 0.75, 0.18, 0.42))
	canvas.draw_circle(center, radius + 1.6, COL_INK_DARK)
	canvas.draw_circle(center, radius, bg_col)
	canvas.draw_arc(center, radius, 0.0, TAU, 24, rim_col, 1.5, true)

	var s: float = radius * 0.56
	var icon_col := Color("#fff8e8")

	match category:
		"church":
			# Crisp Sanctuary Latin Cross
			canvas.draw_line(center + Vector2(0.0, -s * 1.15), center + Vector2(0.0, s * 1.15), icon_col, 2.3)
			canvas.draw_line(center + Vector2(-s * 0.82, -s * 0.32), center + Vector2(s * 0.82, -s * 0.32), icon_col, 2.3)
		"grocery":
			# Crisp Supply Can / Basket icon
			var basket := Rect2(center - Vector2(s * 0.85, s * 0.45), Vector2(s * 1.7, s * 1.15))
			canvas.draw_rect(basket, icon_col, false, 1.8)
			canvas.draw_line(center + Vector2(-s * 0.55, -s * 0.45), center + Vector2(0.0, -s * 1.05), icon_col, 1.7)
			canvas.draw_line(center + Vector2(s * 0.55, -s * 0.45), center + Vector2(0.0, -s * 1.05), icon_col, 1.7)
			canvas.draw_line(center + Vector2(-s * 0.45, s * 0.12), center + Vector2(s * 0.45, s * 0.12), icon_col, 1.6)
		"pharmacy":
			# Crisp Medical '+' Cross
			canvas.draw_rect(Rect2(center.x - s * 0.28, center.y - s * 0.95, s * 0.56, s * 1.9), icon_col, true)
			canvas.draw_rect(Rect2(center.x - s * 0.95, center.y - s * 0.28, s * 1.9, s * 0.56), icon_col, true)
		"civic":
			# Crisp Police / Fire Emergency Shield emblem
			var shield := PackedVector2Array([
				center + Vector2(0.0, -s * 1.08),
				center + Vector2(s * 0.88, -s * 0.62),
				center + Vector2(s * 0.72, s * 0.28),
				center + Vector2(0.0, s * 1.08),
				center + Vector2(-s * 0.72, s * 0.28),
				center + Vector2(-s * 0.88, -s * 0.62)
			])
			canvas.draw_polyline(shield, icon_col, 1.7, true)
			canvas.draw_line(shield[shield.size() - 1], shield[0], icon_col, 1.7, true)
			canvas.draw_circle(center + Vector2(0.0, -s * 0.05), s * 0.30, COL_HAZARD_YELLOW)
		"hardware":
			# Diagonal Wrench / Tool bar
			canvas.draw_line(center + Vector2(-s * 0.8, s * 0.8), center + Vector2(s * 0.65, -s * 0.65), icon_col, 2.4)
			canvas.draw_arc(center + Vector2(s * 0.65, -s * 0.65), s * 0.45, 0.3, 4.9, 10, icon_col, 1.8, true)
		"school":
			# Open Book pages
			canvas.draw_rect(Rect2(center.x - s * 0.95, center.y - s * 0.68, s * 0.92, s * 1.35), icon_col, false, 1.6)
			canvas.draw_rect(Rect2(center.x + s * 0.03, center.y - s * 0.68, s * 0.92, s * 1.35), icon_col, false, 1.6)
		"restaurant":
			# Cup / bowl silhouette
			canvas.draw_arc(center + Vector2(0.0, s * 0.05), s * 0.72, 0.0, PI, 12, icon_col, 2.0, true)
			canvas.draw_line(center + Vector2(-s * 0.78, s * 0.05), center + Vector2(s * 0.78, s * 0.05), icon_col, 1.8)
		"park":
			# Pine tree triangle
			var tree := PackedVector2Array([
				center + Vector2(0.0, -s * 1.05),
				center + Vector2(s * 0.85, s * 0.55),
				center + Vector2(-s * 0.85, s * 0.55)
			])
			canvas.draw_colored_polygon(tree, icon_col)
			canvas.draw_line(center + Vector2(0.0, s * 0.55), center + Vector2(0.0, s * 1.05), icon_col, 2.0)
		_:
			canvas.draw_circle(center, s * 0.45, icon_col)

static func _category_accent_color(category: String) -> Color:
	match category:
		"church":
			return Color("#6d469c")
		"grocery":
			return Color("#2f8244")
		"pharmacy":
			return Color("#c93b2b")
		"civic":
			return Color("#28558c")
		"hardware":
			return Color("#c46821")
		"school":
			return Color("#2e6f9e")
		"restaurant":
			return Color("#9e5432")
		"park":
			return Color("#497a38")
		"neighbor_house":
			return Color("#b88d32")
		_:
			return Color("#5c635a")

# --- Safe Polygon & Geometry Drawing Helpers ---

func _safe_draw_filled_polygon(poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 3:
		return
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if not tris.is_empty():
		draw_colored_polygon(poly, col)
		return
	var hull: PackedVector2Array = Geometry2D.convex_hull(poly)
	if hull.size() >= 3:
		var hull_tris: PackedInt32Array = Geometry2D.triangulate_polygon(hull)
		if not hull_tris.is_empty():
			draw_colored_polygon(hull, col)

func _draw_closed_outline(poly: PackedVector2Array, col: Color, width: float) -> void:
	if poly.size() < 2:
		return
	var closed := PackedVector2Array()
	closed.append_array(poly)
	closed.append(poly[0])
	draw_polyline(closed, col, width, true)

func _draw_dashed_circle(center: Vector2, radius: float, col: Color, width: float, segments: int) -> void:
	if radius < 6.0 or radius > 2800.0:
		return
	var step_ang: float = TAU / float(segments)
	for i in range(segments):
		if i % 2 == 0:
			var a0: float = float(i) * step_ang
			var a1: float = a0 + step_ang * 0.65
			draw_arc(center, radius, a0, a1, 5, col, width, true)

func _draw_micro_pill(font: Font, pos: Vector2, txt: String, bg: Color, fg: Color) -> void:
	var w: float = float(txt.length()) * 6.5 + 10.0
	var r := Rect2(pos, Vector2(w, 15.0))
	draw_rect(r, bg, true)
	draw_rect(r, fg, false, 1.1)
	draw_string(font, pos + Vector2(5.0, 11.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fg)

func _play_ui_tick() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("tick")

func _play_select_sfx() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("button_click")
