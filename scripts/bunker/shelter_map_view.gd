class_name ShelterMapView
extends Control

## Geographically correct shelter map drawn from the same OSM data as the house picker:
## real road geometry and names, parks/water, building outlines, every expedition target at its
## true position, the actual walking route to the selected target, fallout direction and
## re-contamination hotspots. Zoom (wheel / buttons), drag to pan, Nearby vs Extended views.

signal target_clicked(poi_index: int)

const COL_PAPER := Color("#e4e7eb")
const COL_PAPER_DARK := Color("#d3d8de")
const COL_INK := Color("#14171c")
const COL_ROAD_CASE := Color(0.22, 0.25, 0.29, 0.85)
const COL_ROAD_MAJOR := Color("#ffffff")
const COL_ROAD_MINOR := Color("#f4f5f7")
const COL_PATH := Color(0.40, 0.44, 0.50, 0.70)
const COL_PARK := Color(0.47, 0.64, 0.38, 0.45)
const COL_WATER := Color(0.3, 0.55, 0.74, 0.55)
const COL_BLDG := Color(0.60, 0.64, 0.68, 0.40)
const COL_HOME := Color("#ff4d4f")
const COL_ROUTE := Color("#e0383a")
const NEARBY_RADIUS_M: float = 320.0

var targets: Array = []
var selected_index: int = 0
var view_mode: String = "nearby"       # "nearby" | "extended"
var compact: bool = false               # small widget (fewer labels, no tooltips)
var show_controls: bool = true

var _zoom: float = 1.0
var _pan_m: Vector2 = Vector2.ZERO     # map centre offset from home in metres (x east, y north)
var _drag: bool = false
var _drag_from: Vector2 = Vector2.ZERO
var _hover_idx: int = -1
var _pin_screen: Array[Vector2] = []
var _net: Dictionary = {}
var _dists: Dictionary = {}
var _route: PackedVector2Array = PackedVector2Array()
var _route_for: int = -2
var _anim_t: float = 0.0
var _btns: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_network()
	if show_controls:
		_make_button("+", Vector2(-34, 8), func() -> void: _set_zoom(_zoom * 1.4))
		_make_button("−", Vector2(-34, 40), func() -> void: _set_zoom(_zoom / 1.4))
		_make_button("NEARBY", Vector2(8, -30), func() -> void: set_view_mode("nearby"), 74.0)
		_make_button("EXTENDED", Vector2(86, -30), func() -> void: set_view_mode("extended"), 86.0)
	resized.connect(_place_buttons)
	_place_buttons()


func _make_button(txt: String, anchor_off: Vector2, cb: Callable, w: float = 28.0) -> void:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(w, 26.0)
	b.add_theme_font_size_override("font_size", 11 if w > 30.0 else 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1a1e24")
	sb.border_color = Color("#39414b")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color("#2f3640")
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_color_override("font_color", Color("#e8eaed"))
	b.pressed.connect(func() -> void:
		SoundManager.play_sfx("button_click")
		cb.call()
	)
	add_child(b)
	_btns.append([b, anchor_off])


func _place_buttons() -> void:
	for pair in _btns:
		var b: Button = pair[0]
		var off: Vector2 = pair[1]
		b.position = Vector2(size.x + off.x if off.x < 0.0 else off.x, size.y + off.y if off.y < 0.0 else off.y)


func set_view_mode(mode: String) -> void:
	view_mode = mode
	_zoom = 1.0
	_pan_m = Vector2.ZERO
	queue_redraw()


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, 0.35, 6.0)
	queue_redraw()


func _build_network() -> void:
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	_net = WalkNetwork.build(GameState.map_roads, h_lat, h_lon)
	if (_net["pos"] as PackedVector2Array).size() > 1:
		_dists = WalkNetwork.distances_from(_net, h_lat, h_lon)
	else:
		_dists = {"ok": false}


func _process(delta: float) -> void:
	_anim_t += delta
	if is_visible_in_tree():
		queue_redraw()


# --- projection -------------------------------------------------------------

func _extent_m() -> float:
	if view_mode == "nearby":
		return NEARBY_RADIUS_M
	var far: float = NEARBY_RADIUS_M
	for t_v in targets:
		far = maxf(far, float((t_v as Dictionary).get("distance_m", 0.0)) * 1.15)
	var b: Dictionary = GameState.map_bounds
	if not b.is_empty():
		var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
		far = maxf(far, (float(b.get("maxlat", h_lat)) - float(b.get("minlat", h_lat))) * 110540.0 * 0.55)
	return clampf(far, NEARBY_RADIUS_M, 2600.0)


func _px_per_m() -> float:
	return (minf(size.x, size.y) * 0.5 - 14.0) / _extent_m() * _zoom


func _ll_to_m(lat: float, lon: float) -> Vector2:
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	return Vector2((lon - h_lon) * 111320.0 * cos(deg_to_rad(h_lat)), (lat - h_lat) * 110540.0)


func _m_to_screen(m: Vector2) -> Vector2:
	var k: float = _px_per_m()
	return size * 0.5 + Vector2((m.x - _pan_m.x) * k, -(m.y - _pan_m.y) * k)


func _ll_to_screen(lat: float, lon: float) -> Vector2:
	return _m_to_screen(_ll_to_m(lat, lon))


# --- input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom * 1.15)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom / 1.15)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_drag_from = mb.position
			else:
				var moved: float = mb.position.distance_to(_drag_from)
				_drag = false
				if moved < 5.0:
					var hit: int = _pick(mb.position)
					if hit >= 0:
						selected_index = hit
						target_clicked.emit(hit)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _drag:
			var k: float = _px_per_m()
			_pan_m += Vector2(-mm.relative.x / k, mm.relative.y / k)
		_hover_idx = _pick(mm.position)


func _pick(p: Vector2) -> int:
	var best: int = -1
	var best_d: float = 14.0
	for i in range(_pin_screen.size()):
		var d: float = _pin_screen[i].distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, COL_PAPER)
	_draw_grid(r)
	var k: float = _px_per_m()
	# parks & water
	for pk_v in GameState.map_parks:
		var pk: Dictionary = pk_v
		var poly := PackedVector2Array()
		for p in pk.get("polygon_latlon", []):
			poly.append(_ll_to_screen((p as Vector2).y, (p as Vector2).x))
		if poly.size() >= 3 and _poly_visible(poly, r):
			var col: Color = COL_WATER if str(pk.get("kind", "")) == "water" else COL_PARK
			_safe_poly(poly, col)
	# buildings (only when zoomed in enough to read them)
	if k > 0.45:
		for b_v in GameState.map_buildings:
			var b: Dictionary = b_v
			var bp := PackedVector2Array()
			for p2 in b.get("polygon_latlon", []):
				bp.append(_ll_to_screen((p2 as Vector2).y, (p2 as Vector2).x))
			if bp.size() >= 3 and _poly_visible(bp, r):
				_safe_poly(bp, COL_BLDG)
	# roads: casing, fill, then labels
	var labels: Array = []
	for pass_i in range(2):
		for rd_v in GameState.map_roads:
			var rd: Dictionary = rd_v
			var kind: String = str(rd.get("kind", ""))
			var w: float = _road_width(kind) * clampf(k * 1.2, 0.5, 2.6)
			if w <= 0.0:
				continue
			var pts := PackedVector2Array()
			for p3 in rd.get("points_latlon", []):
				pts.append(_ll_to_screen((p3 as Vector2).y, (p3 as Vector2).x))
			if pts.size() < 2 or not _poly_visible(pts, r.grow(40.0)):
				continue
			if kind in ["footway", "path", "steps", "cycleway", "track", "corridor"]:
				if pass_i == 1 and k > 0.35:
					draw_polyline(pts, COL_PATH, 1.2)
				continue
			if pass_i == 0:
				draw_polyline(pts, COL_ROAD_CASE, w + 2.0)
			else:
				draw_polyline(pts, COL_ROAD_MAJOR if kind in ["primary", "secondary", "tertiary", "trunk"] else COL_ROAD_MINOR, w)
				var nm: String = str(rd.get("name", ""))
				if nm != "" and w >= 3.0:
					labels.append([nm, pts])
	var occupied: Array[Rect2] = []
	var drawn_names: Dictionary = {}
	for lb in labels:
		var nm2: String = lb[0]
		if drawn_names.has(nm2):
			continue
		var placed: bool = _draw_road_label(font, nm2, lb[1], occupied, r)
		if placed:
			drawn_names[nm2] = true
	# fallout direction + hotspots
	_draw_fallout(font, r)
	# route to the selected target
	_draw_route()
	# home footprint
	var fp: Array = GameState.selected_house.get("polygon_latlon", [])
	var home_scr: Vector2 = _m_to_screen(Vector2.ZERO)
	if fp.size() >= 3 and k > 0.25:
		var hp := PackedVector2Array()
		for p4 in fp:
			hp.append(_ll_to_screen((p4 as Vector2).y, (p4 as Vector2).x))
		_safe_poly(hp, COL_HOME)
		hp.append(hp[0])
		draw_polyline(hp, COL_INK, 1.5)
	draw_circle(home_scr, 7.0, COL_HOME)
	draw_arc(home_scr, 7.0, 0.0, TAU, 16, COL_INK, 1.6)
	draw_arc(home_scr, 12.0 + sin(_anim_t * 3.0) * 2.0, 0.0, TAU, 20, Color(COL_HOME.r, COL_HOME.g, COL_HOME.b, 0.5), 1.4)
	occupied.append(Rect2(home_scr - Vector2(20, 10), Vector2(40, 20)))
	if not compact:
		_text_box(font, home_scr + Vector2(10, -12), "HOME", 11, COL_HOME, occupied, true)
	# targets
	_pin_screen.clear()
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var sp: Vector2 = _ll_to_screen(float(t.get("lat", 0.0)), float(t.get("lon", 0.0)))
		_pin_screen.append(sp)
		if not r.grow(-4.0).has_point(sp):
			_draw_edge_arrow(sp, r, i == selected_index)
			continue
		var cat: String = str(t.get("category", ""))
		var depleted: bool = bool(t.get("depleted", false))
		var rad: float = 7.0 if compact else 9.0
		if i == selected_index:
			draw_circle(sp, rad + 5.0, Color(0.85, 0.2, 0.1, 0.25 + 0.15 * sin(_anim_t * 5.0)))
		OsmSlippyMap.draw_poi_badge(self, sp, rad, "house" if cat == "neighbor_house" else cat, i == selected_index or i == _hover_idx)
		if depleted:
			draw_line(sp + Vector2(-rad, -rad), sp + Vector2(rad, rad), COL_INK, 2.0)
		if bool(t.get("fictional", false)):
			_text_box(font, sp + Vector2(rad + 2, 4), "FICTIONAL", 9, Color("#7b4b94"), occupied, false)
		var show_label: bool = (not compact) or i == selected_index
		if show_label and cat != "neighbor_house" or i == selected_index:
			var nm3: String = str(t.get("name", ""))
			if nm3.length() > 26:
				nm3 = nm3.substr(0, 24) + "…"
			_text_box(font, sp + Vector2(rad + 3.0, -rad - 2.0), nm3, 10 if compact else 11, COL_INK, occupied, i == selected_index)
	_draw_chrome(font, r)
	if _hover_idx >= 0 and _hover_idx < targets.size() and not compact:
		_draw_tooltip(font, targets[_hover_idx], _pin_screen[_hover_idx], r)


func _draw_grid(r: Rect2) -> void:
	var k: float = _px_per_m()
	var step_m: float = 100.0 if _extent_m() < 900.0 else 500.0
	var step_px: float = step_m * k
	if step_px < 18.0:
		return
	var origin: Vector2 = _m_to_screen(Vector2.ZERO)
	var x: float = fposmod(origin.x, step_px)
	while x < r.size.x:
		draw_line(Vector2(x, 0), Vector2(x, r.size.y), Color(0.3, 0.25, 0.18, 0.08), 1.0)
		x += step_px
	var y: float = fposmod(origin.y, step_px)
	while y < r.size.y:
		draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(0.3, 0.25, 0.18, 0.08), 1.0)
		y += step_px


func _road_width(kind: String) -> float:
	match kind:
		"motorway", "trunk":
			return 7.0
		"primary":
			return 6.0
		"secondary":
			return 5.0
		"tertiary":
			return 4.4
		"residential", "unclassified", "living_street", "road":
			return 3.6
		"service":
			return 2.2
		"pedestrian":
			return 3.0
		"footway", "path", "steps", "cycleway", "track", "corridor":
			return 1.0
		_:
			return 2.0


func _draw_road_label(font: Font, nm: String, pts: PackedVector2Array, occupied: Array[Rect2], r: Rect2) -> bool:
	# longest visible segment, text rotated along it (kept upright)
	var best_i: int = -1
	var best_len: float = 0.0
	for i in range(pts.size() - 1):
		var mid: Vector2 = (pts[i] + pts[i + 1]) * 0.5
		if not r.grow(-20.0).has_point(mid):
			continue
		var l: float = pts[i].distance_to(pts[i + 1])
		if l > best_len:
			best_len = l
			best_i = i
	var fs: int = 10
	var tw: float = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if best_i < 0 or best_len < tw + 10.0:
		return false
	var a: Vector2 = pts[best_i]
	var b: Vector2 = pts[best_i + 1]
	if b.x < a.x:
		var tmp: Vector2 = a
		a = b
		b = tmp
	var ang: float = (b - a).angle()
	var mid2: Vector2 = (a + b) * 0.5
	var box := Rect2(mid2 - Vector2(tw * 0.5 + 2.0, 8.0), Vector2(tw + 4.0, 14.0))
	for o in occupied:
		if o.intersects(box):
			return false
	occupied.append(box)
	draw_set_transform(mid2, ang, Vector2.ONE)
	draw_string_outline(font, Vector2(-tw * 0.5, 4.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(COL_PAPER, 0.95))
	draw_string(font, Vector2(-tw * 0.5, 4.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.16, 0.18, 0.21))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _text_box(font: Font, pos: Vector2, txt: String, fs: int, col: Color, occupied: Array[Rect2], force: bool) -> void:
	var sz: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var box := Rect2(pos - Vector2(1.0, sz.y * 0.8), sz + Vector2(2.0, 2.0))
	if not force:
		for o in occupied:
			if o.intersects(box):
				return
	occupied.append(box)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(COL_PAPER, 0.92))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_route() -> void:
	if selected_index < 0 or selected_index >= targets.size():
		return
	if _route_for != selected_index:
		_route_for = selected_index
		var t: Dictionary = targets[selected_index]
		_route = WalkNetwork.route_to(_net, _dists, float(t.get("lat", 0.0)), float(t.get("lon", 0.0)))
	if _route.size() < 2:
		var t2: Dictionary = targets[selected_index]
		var a: Vector2 = _m_to_screen(Vector2.ZERO)
		var b: Vector2 = _ll_to_screen(float(t2.get("lat", 0.0)), float(t2.get("lon", 0.0)))
		_dashed(a, b, Color(COL_ROUTE, 0.7), 2.0)
		return
	var sp := PackedVector2Array()
	for m in _route:
		sp.append(_m_to_screen(m))
	draw_polyline(sp, Color(1, 1, 1, 0.8), 5.0)
	draw_polyline(sp, COL_ROUTE, 2.6)
	# marching dot along the route
	var total: float = 0.0
	for i in range(sp.size() - 1):
		total += sp[i].distance_to(sp[i + 1])
	var at: float = fmod(_anim_t * 60.0, maxf(1.0, total))
	for i2 in range(sp.size() - 1):
		var seg: float = sp[i2].distance_to(sp[i2 + 1])
		if at <= seg:
			draw_circle(sp[i2].lerp(sp[i2 + 1], at / maxf(0.01, seg)), 3.5, COL_ROUTE)
			break
		at -= seg


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d: float = a.distance_to(b)
	var n: int = int(d / 8.0)
	for i in range(0, n, 2):
		draw_line(a.lerp(b, float(i) / float(n)), a.lerp(b, float(i + 1) / float(n)), col, w)


func _draw_fallout(font: Font, r: Rect2) -> void:
	var home: Vector2 = _m_to_screen(Vector2.ZERO)
	var dw: float = deg_to_rad(LocationText.downwind_bearing())
	var dir := Vector2(sin(dw), -cos(dw))
	var start: Vector2 = home - dir * minf(r.size.x, r.size.y) * 0.42
	var end: Vector2 = home + dir * minf(r.size.x, r.size.y) * 0.42
	var col := Color(0.45, 0.62, 0.2, 0.22)
	draw_line(start, end, col, 18.0)
	var tip: Vector2 = end
	var nrm := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip + dir * 10.0, tip - dir * 10.0 + nrm * 14.0, tip - dir * 10.0 - nrm * 14.0]), Color(0.45, 0.62, 0.2, 0.45))
	if not compact:
		draw_string(font, end - dir * 30.0 + nrm * 16.0, "FALLOUT DRIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.42, 0.12))
	for h_v in GameState.rad_hotspots:
		var h: Dictionary = h_v
		var age: int = GameState.day - int(h.get("start_day", 0))
		if age > int(float(h.get("decay_days", 4.0)) * 2.0):
			continue
		var c: Vector2 = _ll_to_screen(float(h["lat"]), float(h["lon"]))
		var rad_px: float = float(h.get("radius_m", 300.0)) * _px_per_m()
		draw_circle(c, rad_px, Color(0.5, 0.85, 0.2, 0.12 + 0.05 * sin(_anim_t * 2.0)))
		draw_arc(c, rad_px, 0.0, TAU, 40, Color(0.35, 0.6, 0.1, 0.6), 1.5)
		if not compact:
			draw_string(font, c + Vector2(-rad_px * 0.5, -rad_px - 4.0), "HOTSPOT (%s)" % str(h.get("cause", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.25, 0.45, 0.05))


func _draw_edge_arrow(sp: Vector2, r: Rect2, sel: bool) -> void:
	var c: Vector2 = r.get_center()
	var d: Vector2 = (sp - c).normalized()
	var edge: Vector2 = c + d * (minf(r.size.x, r.size.y) * 0.5 - 10.0)
	var col: Color = COL_ROUTE if sel else Color(0.3, 0.26, 0.2, 0.7)
	var nrm := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([edge + d * 7.0, edge - d * 5.0 + nrm * 5.0, edge - d * 5.0 - nrm * 5.0]), col)


func _draw_chrome(font: Font, r: Rect2) -> void:
	draw_rect(r, COL_INK, false, 2.0)
	# north arrow
	var n_c := Vector2(r.size.x - 18.0, r.size.y - (52.0 if show_controls else 20.0))
	draw_colored_polygon(PackedVector2Array([n_c + Vector2(0, -12), n_c + Vector2(6, 6), n_c + Vector2(0, 2), n_c + Vector2(-6, 6)]), COL_INK)
	draw_string(font, n_c + Vector2(-4, -15), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_INK)
	# scale bar
	var k: float = _px_per_m()
	var nice: Array = [25.0, 50.0, 100.0, 200.0, 250.0, 500.0, 1000.0, 2000.0]
	var bar_m: float = 50.0
	for nv in nice:
		if float(nv) * k <= r.size.x * 0.28:
			bar_m = float(nv)
	var bar_px: float = bar_m * k
	var y0: float = r.size.y - (40.0 if show_controls else 10.0)
	var x0: float = r.size.x - bar_px - 36.0
	draw_rect(Rect2(x0, y0, bar_px, 4.0), COL_INK)
	draw_rect(Rect2(x0, y0, bar_px * 0.5, 4.0), COL_PAPER)
	draw_rect(Rect2(x0, y0, bar_px, 4.0), COL_INK, false, 1.0)
	draw_string(font, Vector2(x0, y0 - 3.0), ("%d m" % int(bar_m)) if bar_m < 1000.0 else ("%.0f km" % (bar_m / 1000.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_INK)
	if not compact:
		var mode_txt: String = "NEARBY (%d m)" % int(NEARBY_RADIUS_M) if view_mode == "nearby" else "EXTENDED (%.1f km)" % (_extent_m() / 1000.0)
		draw_string(font, Vector2(8, 16), mode_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_INK)
	var attrib: String = "© OpenStreetMap contributors"
	draw_string(font, Vector2(8, r.size.y - (38.0 if show_controls else 6.0)), attrib, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.25, 0.28, 0.32, 0.8))


func _draw_tooltip(font: Font, t: Dictionary, at: Vector2, r: Rect2) -> void:
	var lines: Array[String] = []
	lines.append(str(t.get("name", "")))
	var kind: String = str(t.get("kind_label", OsmService.get_category_label(str(t.get("category", "")))))
	lines.append("%s · OSM %s %d" % [kind, str(t.get("osm_type", "")), int(t.get("osm_id", 0))] if not bool(t.get("fictional", false)) else "FICTIONAL placeholder (nothing mapped)")
	var walk_src: String = "on mapped paths" if str(t.get("walk_source", "")) == "network" else "estimated"
	lines.append("%d m walk (%s) · %d m straight %s" % [int(t.get("walk_m", t.get("distance_m", 0))), walk_src, int(t.get("distance_m", 0)), str(t.get("bearing_dir", ""))])
	lines.append("Loot: %s" % str(t.get("loot_status", LootInventory.status_label(t))))
	if t.has("dose_rate_msv_h"):
		lines.append("Outside now: %s (%s)" % [RadiationModel.format_rate(float(t["dose_rate_msv_h"])), str(t.get("radiation_risk", ""))])
	var w: float = 0.0
	for ln in lines:
		w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var box := Rect2(at + Vector2(14, 8), Vector2(w + 16.0, float(lines.size()) * 15.0 + 10.0))
	if box.end.x > r.size.x:
		box.position.x = at.x - box.size.x - 14.0
	if box.end.y > r.size.y:
		box.position.y = at.y - box.size.y - 8.0
	draw_rect(box, Color("#1a1e24"))
	draw_rect(box, Color("#39414b"), false, 1.0)
	for i in range(lines.size()):
		draw_string(font, box.position + Vector2(8, 16 + i * 15), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffb020") if i == 0 else Color("#e8eaed"))


func _poly_visible(pts: PackedVector2Array, r: Rect2) -> bool:
	for p in pts:
		if r.has_point(p):
			return true
	if pts.size() >= 2:
		var mn: Vector2 = pts[0]
		var mx: Vector2 = pts[0]
		for p2 in pts:
			mn = Vector2(minf(mn.x, p2.x), minf(mn.y, p2.y))
			mx = Vector2(maxf(mx.x, p2.x), maxf(mx.y, p2.y))
		return Rect2(mn, mx - mn).intersects(r)
	return false


func _safe_poly(poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 3:
		return
	if Geometry2D.triangulate_polygon(poly).size() < 3:
		return
	draw_colored_polygon(poly, col)
