class_name FloorplanGenerator
extends RefCounted

## Real-footprint floorplan generator.
##
## The playable level is built INSIDE the actual OpenStreetMap building outline
## (OBB-aligned, true metres -> pixels). The footprint is recursively split
## (BSP) into rooms and an optional hallway; room count follows the real
## footprint area. Doors come from a spanning tree over room adjacency, then
## the whole level is rasterised into a navigation grid and verified by BFS
## from the bunker hatch so every room, item and family member is reachable.
##
## OSM only knows exterior outlines. Everything inside (rooms, doors, furniture)
## is a generated, fictional approximation and is labelled as such.

const PX_PER_M: float = 46.0
const MAX_SPAN_M: float = 30.0          # very large footprints are uniformly scaled down to this
const MIN_AREA_M2: float = 48.0         # tiny sheds/garages are uniformly scaled up to this
const EXT_WALL: float = 16.0
const INT_WALL: float = 10.0
const DOOR_W: float = 64.0              # 1.4 m clear opening (player is 0.6 m wide)
const DOOR_MARGIN: float = 22.0
const NAV_CELL: float = 16.0
const NAV_CLEAR: float = 15.0           # player radius (14) + 1 px
const HATCH_R: float = 40.0
const HALL_W_M: float = 1.6
const MIN_ROOM_M2: float = 5.5
const ENGINE_TAG: String = "floorplan_v2"

const FURNITURE_SPECS: Dictionary = {
	"Living Room": [["sofa", 2.2, 0.9, true], ["armchair", 0.9, 0.9, true], ["coffee_table", 1.2, 0.6, true], ["bookshelf", 1.2, 0.4, true], ["tv_console", 1.4, 0.5, true], ["rug", 2.2, 1.6, false]],
	"Kitchen": [["counter", 2.4, 0.62, true], ["stove", 0.8, 0.65, true], ["fridge", 0.8, 0.75, true], ["kitchen_table", 1.2, 0.9, true], ["pantry_shelf", 1.0, 0.45, true]],
	"Dining Room": [["dining_table", 1.8, 1.0, true], ["sideboard", 1.4, 0.5, true], ["china_cabinet", 1.0, 0.45, true]],
	"Master Bedroom": [["bed_double", 1.6, 2.0, true], ["dresser", 1.2, 0.5, true], ["wardrobe", 1.2, 0.6, true], ["nightstand", 0.5, 0.45, true]],
	"Bedroom": [["bed_single", 1.0, 2.0, true], ["dresser", 1.0, 0.5, true], ["desk", 1.1, 0.6, true]],
	"Kids Bedroom": [["bed_single", 1.0, 1.9, true], ["toy_chest", 0.9, 0.5, true], ["bunk_shelf", 1.0, 0.4, true], ["rug", 1.4, 1.0, false]],
	"Bathroom": [["bathtub", 1.6, 0.75, true], ["sink", 0.6, 0.45, true], ["linen_shelf", 0.8, 0.4, true]],
	"Utility Room": [["washer", 0.7, 0.65, true], ["water_heater", 0.6, 0.6, true], ["tool_bench", 1.6, 0.6, true], ["boxes", 0.9, 0.7, true]],
	"Study": [["desk", 1.4, 0.7, true], ["bookshelf", 1.4, 0.4, true], ["filing_cabinet", 0.5, 0.6, true]],
	"Pantry": [["pantry_shelf", 1.2, 0.45, true], ["boxes", 0.8, 0.6, true]],
	"Hallway": [["coat_rack", 0.5, 0.4, true], ["umbrella_stand", 0.35, 0.35, true]],
	"Storage": [["boxes", 1.0, 0.8, true], ["boxes", 0.8, 0.7, true], ["old_trunk", 0.9, 0.5, true]],
	"Garage Bay": [["tool_bench", 1.8, 0.6, true], ["boxes", 1.0, 0.8, true], ["paint_cans", 0.6, 0.6, true]],
}

const ITEM_ROOMS: Dictionary = {
	"soup": ["Kitchen", "Pantry", "Dining Room", "Utility Room"],
	"water": ["Kitchen", "Pantry", "Bathroom", "Utility Room"],
	"medkit": ["Bathroom", "Master Bedroom", "Utility Room"],
	"gas_mask": ["Utility Room", "Hallway", "Master Bedroom", "Storage"],
	"radio": ["Living Room", "Kitchen", "Study"],
	"suitcase": ["Master Bedroom", "Bedroom", "Storage"],
	"book": ["Study", "Living Room", "Kids Bedroom", "Bedroom"],
	"flashlight": ["Utility Room", "Kitchen", "Garage Bay", "Hallway"],
	"map": ["Study", "Living Room", "Hallway"],
	"ammo": ["Master Bedroom", "Study", "Storage"],
	"bug_spray": ["Utility Room", "Bathroom", "Garage Bay"],
	"padlock": ["Utility Room", "Garage Bay", "Storage"],
	"cards": ["Living Room", "Dining Room", "Kids Bedroom"],
	"checkers": ["Kids Bedroom", "Living Room", "Study"],
	"harmonica": ["Kids Bedroom", "Bedroom", "Living Room"],
	"toolbox": ["Utility Room", "Garage Bay", "Storage"],
	"axe": ["Utility Room", "Garage Bay", "Storage"],
	"rifle": ["Master Bedroom", "Study", "Storage"],
}

const BONUS_POOL: Array[String] = [
	"flashlight", "map", "ammo", "bug_spray", "padlock", "cards", "checkers",
	"harmonica", "toolbox", "axe", "rifle", "book", "suitcase"
]


# ==============================================================================
# PUBLIC ENTRY
# ==============================================================================

static func generate(house_data: Dictionary, family_members: Array, rng: RandomNumberGenerator, road_hint_m: Vector2 = Vector2.ZERO) -> Dictionary:
	var local_rng: RandomNumberGenerator = rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.seed = 19550601

	# 1. Footprint: real OSM polygon, simplified, OBB-aligned, true scale.
	var raw_pts: Array[Vector2] = HouseGenerator._extract_footprint_meters(house_data)
	raw_pts = _simplify_polygon(raw_pts, 0.35, 0.05)
	var obb: Dictionary = HouseGenerator._orient_footprint_to_obb(raw_pts)
	var obb_pts: Array[Vector2] = obb["points"]
	var obb_angle: float = float(obb.get("angle_rad", 0.0))
	var real_area: float = absf(HouseGenerator._polygon_signed_area(obb_pts))
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in obb_pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	var span_m: float = maxf(mx.x - mn.x, mx.y - mn.y)
	var scale: float = 1.0
	if span_m > MAX_SPAN_M:
		scale = MAX_SPAN_M / span_m
	if real_area * scale * scale < MIN_AREA_M2:
		scale = minf(sqrt(MIN_AREA_M2 / maxf(real_area, 1.0)), MAX_SPAN_M / maxf(span_m, 0.1))
	var poly := PackedVector2Array()
	for p in obb_pts:
		poly.append(p * scale * PX_PER_M)
	if _signed_area_packed(poly) < 0.0:
		poly.reverse()
	var bounds: Rect2 = _poly_bounds(poly)
	var play_area_m2: float = real_area * scale * scale

	# 2. Room programme from real area.
	var n_rooms: int = clampi(int(round(real_area / 18.0)), 3, 14)
	n_rooms = mini(n_rooms, maxi(3, int(floor(play_area_m2 / 7.0))))

	# 3. BSP subdivision (optional central hallway along the long axis).
	var leaves: Array = []      # Array of Rect2
	var splits: Array = []      # Array of {a, b} segments in px
	var hallway_rect := Rect2()
	var short_span_m: float = bounds.size.y / PX_PER_M
	var use_hall: bool = n_rooms >= 6 and short_span_m >= 7.5
	if use_hall:
		var hall_h: float = HALL_W_M * PX_PER_M
		var off: float = local_rng.randf_range(-0.12, 0.12) * bounds.size.y
		var hy: float = bounds.get_center().y + off - hall_h * 0.5
		hallway_rect = Rect2(bounds.position.x, hy, bounds.size.x, hall_h)
		var top_r := Rect2(bounds.position.x, bounds.position.y, bounds.size.x, hy - bounds.position.y)
		var bot_r := Rect2(bounds.position.x, hy + hall_h, bounds.size.x, bounds.end.y - (hy + hall_h))
		splits.append({"a": Vector2(bounds.position.x, hy), "b": Vector2(bounds.end.x, hy)})
		splits.append({"a": Vector2(bounds.position.x, hy + hall_h), "b": Vector2(bounds.end.x, hy + hall_h)})
		var top_area: float = _clip_area(poly, top_r)
		var bot_area: float = _clip_area(poly, bot_r)
		var rem: int = n_rooms - 1
		var top_n: int = clampi(int(round(float(rem) * top_area / maxf(1.0, top_area + bot_area))), 1, rem - 1)
		_bsp(poly, top_r, top_n, leaves, splits, local_rng, 0)
		_bsp(poly, bot_r, rem - top_n, leaves, splits, local_rng, 0)
		leaves.append(hallway_rect)
	else:
		_bsp(poly, bounds, n_rooms, leaves, splits, local_rng, 0)

	# 4. Leaves -> room polygons (a leaf may split into several components on concave footprints).
	var rooms: Array = []
	var min_room_px: float = MIN_ROOM_M2 * PX_PER_M * PX_PER_M * 0.55
	for leaf_v in leaves:
		var leaf: Rect2 = leaf_v
		var is_hall_leaf: bool = use_hall and leaf == hallway_rect
		var comps: Array = Geometry2D.intersect_polygons(poly, _rect_poly(leaf))
		for c_v in comps:
			var comp: PackedVector2Array = c_v
			var a: float = absf(_signed_area_packed(comp))
			if a < 400.0:
				continue
			rooms.append({
				"name": "Hallway" if is_hall_leaf else "",
				"polygon": comp,
				"rect": _poly_bounds(comp),
				"area_px": a,
				"center": _poly_centroid(comp),
				"is_hall": is_hall_leaf,
				"solid": a < min_room_px,
			})

	# 5. Shared-wall intervals between rooms along every split line.
	var intervals: Array = _find_shared_intervals(splits, rooms, poly)

	# 6. Hatch room = most central non-solid room (hallway only if wide enough).
	var fp_center: Vector2 = _poly_centroid(poly)
	var hub_idx: int = -1
	var best_score: float = 1e20
	var hub_cands: Array = []
	for i in range(rooms.size()):
		var r: Dictionary = rooms[i]
		if bool(r["solid"]):
			continue
		var rr: Rect2 = r["rect"]
		if bool(r["is_hall"]) and minf(rr.size.x, rr.size.y) < (HATCH_R + 24.0) * 2.0:
			continue
		if minf(rr.size.x, rr.size.y) < (HATCH_R + 20.0) * 2.0:
			continue
		var sc: float = (r["center"] as Vector2).distance_to(fp_center) - sqrt(float(r["area_px"])) * 0.15
		hub_cands.append([sc, i])
		if sc < best_score:
			best_score = sc
			hub_idx = i
	# The shelter hatch is not always in the most central room: pick among the 3 most central.
	if hub_cands.size() >= 2:
		hub_cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var pick: int = local_rng.randi_range(0, mini(2, hub_cands.size() - 1))
		hub_idx = int(hub_cands[pick][1])
	if hub_idx < 0:
		for i in range(rooms.size()):
			if not bool(rooms[i]["solid"]):
				hub_idx = i
				break

	# 7. Doors: Prim spanning tree from hub + a few loop doors.
	var doorways: Array = _plan_doors(rooms, intervals, hub_idx, local_rng)

	# Rooms with no door at all become sealed built-ins (never hold loot or family).
	for i in range(rooms.size()):
		var has_door: bool = i == hub_idx
		for d_v in doorways:
			var d: Dictionary = d_v
			if int(d["room_a"]) == i or int(d["room_b"]) == i:
				has_door = true
				break
		if not has_door:
			rooms[i]["solid"] = true

	# 8. Room names from size, adjacency and footprint size.
	_assign_room_names(rooms, hub_idx, doorways, real_area)

	# 9. Walls.
	var walls: Array = _build_walls(poly, splits, doorways)

	# 10. Entrances (decorative closed doors in the exterior wall, front faces the road).
	var entrances: Array = _plan_entrances(poly, rooms, road_hint_m, obb_angle, real_area)

	# 11. Hatch position: deepest point of the hub room near its centroid.
	var hatch_pos: Vector2 = _pick_hatch_pos(rooms[hub_idx] if hub_idx >= 0 else {}, walls, poly)

	# 11b. Self-heal: BFS from the hatch must reach every open room before furniture goes in.
	var heal_log: Array = []
	walls = _heal_connectivity(rooms, intervals, doorways, splits, poly, bounds, hatch_pos, local_rng, heal_log)

	# 12. Furniture + navigation grid with incremental connectivity checks.
	var nav_base: Dictionary = _nav_base(poly, walls, rooms, bounds)
	var nav: Dictionary = _nav_finalize(nav_base, [], hatch_pos)
	var furniture: Array = _place_furniture(rooms, doorways, hatch_pos, nav_base, nav, local_rng)
	nav = _nav_finalize(nav_base, furniture, hatch_pos)
	nav.erase("base_walkable")
	nav.erase("room_index")

	# 13. Leader start, family and items on BFS-reachable cells.
	var leader_start: Vector2 = _pick_leader_start(nav, hatch_pos)
	var family_spawns: Array = _spawn_family(family_members, rooms, nav, hatch_pos, local_rng)
	var items: Array = _spawn_items(rooms, furniture, nav, hatch_pos, family_spawns, real_area, local_rng)

	var out_rooms: Array = []
	for r_v in rooms:
		var r: Dictionary = r_v
		out_rooms.append({
			"name": str(r["name"]),
			"polygon": r["polygon"],
			"rect": Rect2(),
			"center": r["center"],
			"area_m2": snappedf(float(r["area_px"]) / (PX_PER_M * PX_PER_M) / (scale * scale), 0.1),
			"sealed": bool(r["solid"]),
		})
	# Sealed built-ins are solid blocks for collision/visuals.
	for r_v2 in rooms:
		var rs: Dictionary = r_v2
		if bool(rs["solid"]):
			furniture.append({"rect": _poly_bounds(rs["polygon"]).grow(-INT_WALL * 0.5), "type": "built_in", "label": "Built-in closet", "solid": true, "sealed_room": true})

	return {
		"engine": ENGINE_TAG,
		"bounds": bounds.grow(EXT_WALL),
		"interior_bounds": bounds,
		"outer_polygon": poly,
		"raw_osm_polygon": poly,
		"obb_angle_deg": rad_to_deg(obb_angle),
		"rooms": out_rooms,
		"doorways": doorways,
		"walls": walls,
		"entrances": entrances,
		"furniture": furniture,
		"hatch_pos": hatch_pos,
		"hatch_radius": HATCH_R,
		"leader_start_pos": leader_start,
		"items": items,
		"family_spawns": family_spawns,
		"nav_grid": nav,
		"meta": {
			"osm_id": int(house_data.get("osm_id", 0)),
			"real_area_m2": snappedf(real_area, 0.1),
			"real_span_m": snappedf(span_m, 0.1),
			"scale": snappedf(scale, 0.001),
			"room_count": _count_open_rooms(rooms),
			"has_hallway": use_hall,
			"vertex_count": poly.size(),
			"door_count": doorways.size(),
			"heal_steps": heal_log,
			"fictional_interior": true,
		}
	}


# ==============================================================================
# GEOMETRY HELPERS
# ==============================================================================

static func _simplify_polygon(pts: Array[Vector2], min_edge_m: float, collinear_tol: float) -> Array[Vector2]:
	var out: Array[Vector2] = pts.duplicate()
	var changed: bool = true
	var guard: int = 0
	while changed and out.size() > 4 and guard < 200:
		changed = false
		guard += 1
		for i in range(out.size()):
			var prev: Vector2 = out[(i - 1 + out.size()) % out.size()]
			var cur: Vector2 = out[i]
			var nxt: Vector2 = out[(i + 1) % out.size()]
			var e1: Vector2 = cur - prev
			var e2: Vector2 = nxt - cur
			var cross: float = absf(e1.cross(e2)) / maxf(0.001, e1.length() * e2.length())
			if e1.length() < min_edge_m or cross < collinear_tol:
				out.remove_at(i)
				changed = true
				break
	return out


static func _signed_area_packed(poly: PackedVector2Array) -> float:
	var acc: float = 0.0
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		acc += a.x * b.y - b.x * a.y
	return acc * 0.5


static func _poly_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var mn: Vector2 = poly[0]
	var mx: Vector2 = poly[0]
	for p in poly:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	return Rect2(mn, mx - mn)


static func _poly_centroid(poly: PackedVector2Array) -> Vector2:
	var a2: float = 0.0
	var cx: float = 0.0
	var cy: float = 0.0
	for i in range(poly.size()):
		var p0: Vector2 = poly[i]
		var p1: Vector2 = poly[(i + 1) % poly.size()]
		var cr: float = p0.x * p1.y - p1.x * p0.y
		a2 += cr
		cx += (p0.x + p1.x) * cr
		cy += (p0.y + p1.y) * cr
	if absf(a2) < 1e-6:
		return _poly_bounds(poly).get_center()
	return Vector2(cx / (3.0 * a2), cy / (3.0 * a2))


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _clip_area(poly: PackedVector2Array, r: Rect2) -> float:
	var total: float = 0.0
	for c_v in Geometry2D.intersect_polygons(poly, _rect_poly(r)):
		var c: PackedVector2Array = c_v
		total += absf(_signed_area_packed(c))
	return total


static func _clip_bounds(poly: PackedVector2Array, r: Rect2) -> Rect2:
	var res := Rect2()
	var first: bool = true
	for c_v in Geometry2D.intersect_polygons(poly, _rect_poly(r)):
		var c: PackedVector2Array = c_v
		var b: Rect2 = _poly_bounds(c)
		res = b if first else res.merge(b)
		first = false
	return res


static func _room_at(rooms: Array, pt: Vector2) -> int:
	for i in range(rooms.size()):
		if Geometry2D.is_point_in_polygon(pt, rooms[i]["polygon"]):
			return i
	return -1


# ==============================================================================
# BSP SUBDIVISION
# ==============================================================================

static func _bsp(poly: PackedVector2Array, rect: Rect2, target: int, leaves: Array, splits: Array, rng: RandomNumberGenerator, depth: int) -> void:
	var area: float = _clip_area(poly, rect)
	var min_px: float = MIN_ROOM_M2 * PX_PER_M * PX_PER_M
	if target <= 1 or area < min_px * 2.0 or depth > 8:
		leaves.append(rect)
		return
	var ib: Rect2 = _clip_bounds(poly, rect)
	if ib.size.x < 4.0 or ib.size.y < 4.0:
		leaves.append(rect)
		return
	var split_x: bool = ib.size.x >= ib.size.y
	if ib.size.x > ib.size.y * 0.8 and ib.size.x < ib.size.y * 1.25:
		split_x = rng.randf() < 0.5
	var k: int = target / 2
	var best_t: float = 0.0
	var found: bool = false
	var best_err: float = 1e20
	for attempt in range(9):
		var frac: float = float(k) / float(target) + rng.randf_range(-0.14, 0.14)
		frac = clampf(frac, 0.22, 0.78)
		var t: float
		var ra: Rect2
		var rb: Rect2
		if split_x:
			t = snappedf(ib.position.x + ib.size.x * frac, 0.25 * PX_PER_M)
			ra = Rect2(rect.position, Vector2(t - rect.position.x, rect.size.y))
			rb = Rect2(Vector2(t, rect.position.y), Vector2(rect.end.x - t, rect.size.y))
		else:
			t = snappedf(ib.position.y + ib.size.y * frac, 0.25 * PX_PER_M)
			ra = Rect2(rect.position, Vector2(rect.size.x, t - rect.position.y))
			rb = Rect2(Vector2(rect.position.x, t), Vector2(rect.size.x, rect.end.y - t))
		if ra.size.x < 2.4 * PX_PER_M and split_x or ra.size.y < 2.4 * PX_PER_M and not split_x:
			continue
		if rb.size.x < 2.4 * PX_PER_M and split_x or rb.size.y < 2.4 * PX_PER_M and not split_x:
			continue
		var aa: float = _clip_area(poly, ra)
		var ab: float = _clip_area(poly, rb)
		if aa < min_px or ab < min_px:
			continue
		var want: float = float(k) / float(target)
		var err: float = absf(aa / maxf(1.0, aa + ab) - want)
		if err < best_err:
			best_err = err
			best_t = t
			found = true
	if not found:
		leaves.append(rect)
		return
	var r1: Rect2
	var r2: Rect2
	if split_x:
		r1 = Rect2(rect.position, Vector2(best_t - rect.position.x, rect.size.y))
		r2 = Rect2(Vector2(best_t, rect.position.y), Vector2(rect.end.x - best_t, rect.size.y))
		splits.append({"a": Vector2(best_t, rect.position.y), "b": Vector2(best_t, rect.end.y)})
	else:
		r1 = Rect2(rect.position, Vector2(rect.size.x, best_t - rect.position.y))
		r2 = Rect2(Vector2(rect.position.x, best_t), Vector2(rect.size.x, rect.end.y - best_t))
		splits.append({"a": Vector2(rect.position.x, best_t), "b": Vector2(rect.end.x, best_t)})
	_bsp(poly, r1, k, leaves, splits, rng, depth + 1)
	_bsp(poly, r2, target - k, leaves, splits, rng, depth + 1)


# ==============================================================================
# ADJACENCY / DOORS / WALLS
# ==============================================================================

static func _find_shared_intervals(splits: Array, rooms: Array, poly: PackedVector2Array) -> Array:
	var out: Array = []
	var step: float = 6.0
	var probe: float = 9.0
	for s_v in splits:
		var s: Dictionary = s_v
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var horiz: bool = absf(a.y - b.y) < 0.5
		var dir: Vector2 = (b - a).normalized()
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		var length: float = a.distance_to(b)
		var cur_pair: Vector2i = Vector2i(-1, -1)
		var start_t: float = 0.0
		var t: float = 0.0
		while t <= length + 0.01:
			var p: Vector2 = a + dir * t
			var ra: int = _room_at(rooms, p - nrm * probe)
			var rb: int = _room_at(rooms, p + nrm * probe)
			var pair: Vector2i = Vector2i(mini(ra, rb), maxi(ra, rb)) if (ra >= 0 and rb >= 0 and ra != rb) else Vector2i(-1, -1)
			if pair != cur_pair:
				if cur_pair.x >= 0:
					_push_interval(out, cur_pair, a + dir * start_t, a + dir * (t - step), horiz)
				cur_pair = pair
				start_t = t
			t += step
		if cur_pair.x >= 0:
			_push_interval(out, cur_pair, a + dir * start_t, a + dir * minf(t - step, length), horiz)
	return out


static func _push_interval(out: Array, pair: Vector2i, p0: Vector2, p1: Vector2, horiz: bool) -> void:
	var len_px: float = p0.distance_to(p1)
	if len_px < 4.0:
		return
	out.append({"room_a": pair.x, "room_b": pair.y, "p0": p0, "p1": p1, "length": len_px, "horizontal": horiz})


static func _plan_doors(rooms: Array, intervals: Array, hub_idx: int, rng: RandomNumberGenerator) -> Array:
	var need: float = DOOR_W + DOOR_MARGIN * 2.0
	# best interval per room pair
	var best_for_pair: Dictionary = {}
	for iv_v in intervals:
		var iv: Dictionary = iv_v
		if float(iv["length"]) < need:
			continue
		var ra: int = int(iv["room_a"])
		var rb: int = int(iv["room_b"])
		if bool(rooms[ra]["solid"]) or bool(rooms[rb]["solid"]):
			continue
		var key: String = "%d_%d" % [ra, rb]
		if not best_for_pair.has(key) or float(best_for_pair[key]["length"]) < float(iv["length"]):
			best_for_pair[key] = iv
	var edges: Array = best_for_pair.values()
	var doors: Array = []
	if hub_idx < 0:
		return doors
	var in_tree: Dictionary = {hub_idx: true}
	var used: Dictionary = {}
	var progress: bool = true
	while progress:
		progress = false
		var best_e: Dictionary = {}
		var best_w: float = 1e20
		for e_v in edges:
			var e: Dictionary = e_v
			var a: int = int(e["room_a"])
			var b: int = int(e["room_b"])
			if in_tree.has(a) == in_tree.has(b):
				continue
			var w: float = 1.0 + rng.randf() * 0.6
			if bool(rooms[a]["is_hall"]) or bool(rooms[b]["is_hall"]):
				w -= 0.6
			if w < best_w:
				best_w = w
				best_e = e
		if not best_e.is_empty():
			in_tree[int(best_e["room_a"])] = true
			in_tree[int(best_e["room_b"])] = true
			used["%d_%d" % [int(best_e["room_a"]), int(best_e["room_b"])]] = true
			doors.append(_make_door(best_e, rng))
			progress = true
	# Loop doors: one per ~4 rooms, so routes are not purely tree-like.
	var extra: int = rooms.size() / 4
	edges.shuffle()
	for e_v in edges:
		if extra <= 0:
			break
		var e: Dictionary = e_v
		var key: String = "%d_%d" % [int(e["room_a"]), int(e["room_b"])]
		if used.has(key):
			continue
		if rng.randf() < 0.55:
			used[key] = true
			doors.append(_make_door(e, rng))
			extra -= 1
	return doors


static func _heal_connectivity(rooms: Array, intervals: Array, doors: Array, splits: Array, poly: PackedVector2Array, bounds: Rect2, hatch: Vector2, rng: RandomNumberGenerator, log: Array) -> Array:
	var walls: Array = _build_walls(poly, splits, doors)
	for iter in range(8):
		var base: Dictionary = _nav_base(poly, walls, rooms, bounds)
		var nav: Dictionary = _nav_finalize(base, [], hatch)
		var counts: Array = nav["room_reachable_cells"]
		var cut_off: Array = []
		for i in range(rooms.size()):
			if not bool(rooms[i]["solid"]) and int(counts[i]) == 0:
				cut_off.append(i)
		if cut_off.is_empty():
			return walls
		for i in cut_off:
			# 1) add a door on the longest unused shared wall towards a reachable room
			var best_iv: Dictionary = {}
			for iv_v in intervals:
				var iv: Dictionary = iv_v
				var a: int = int(iv["room_a"])
				var b: int = int(iv["room_b"])
				if a != i and b != i:
					continue
				var other: int = b if a == i else a
				if bool(rooms[other]["solid"]) or int(counts[other]) == 0:
					continue
				if float(iv["length"]) < DOOR_W + 16.0:
					continue
				var dup: bool = false
				for d_v in doors:
					var d: Dictionary = d_v
					if (d["center"] as Vector2).distance_to(((iv["p0"] as Vector2) + (iv["p1"] as Vector2)) * 0.5) < 4.0:
						dup = true
				if dup:
					continue
				if best_iv.is_empty() or float(iv["length"]) > float(best_iv["length"]):
					best_iv = iv
			if not best_iv.is_empty():
				var nd: Dictionary = _make_door(best_iv, rng)
				var mid: Vector2 = ((best_iv["p0"] as Vector2) + (best_iv["p1"] as Vector2)) * 0.5
				var dir: Vector2 = ((best_iv["p1"] as Vector2) - (best_iv["p0"] as Vector2)).normalized()
				nd["center"] = mid
				nd["a"] = mid - dir * DOOR_W * 0.5
				nd["b"] = mid + dir * DOOR_W * 0.5
				doors.append(nd)
				log.append("added door to %s" % str(rooms[i]["name"]))
			else:
				# 2) widen this room's existing doors
				var widened: bool = false
				for d_v2 in doors:
					var d2: Dictionary = d_v2
					if int(d2["room_a"]) == i or int(d2["room_b"]) == i:
						var dir2: Vector2 = ((d2["b"] as Vector2) - (d2["a"] as Vector2)).normalized()
						var w2: float = float(d2["width"]) + 16.0
						d2["width"] = w2
						d2["a"] = (d2["center"] as Vector2) - dir2 * w2 * 0.5
						d2["b"] = (d2["center"] as Vector2) + dir2 * w2 * 0.5
						widened = true
				if widened:
					log.append("widened doors of %s" % str(rooms[i]["name"]))
		walls = _build_walls(poly, splits, doors)
	# Still cut off after healing: seal it (it will never hold loot or people).
	var base2: Dictionary = _nav_base(poly, walls, rooms, bounds)
	var nav2: Dictionary = _nav_finalize(base2, [], hatch)
	var counts2: Array = nav2["room_reachable_cells"]
	for i2 in range(rooms.size()):
		if not bool(rooms[i2]["solid"]) and int(counts2[i2]) == 0:
			rooms[i2]["solid"] = true
			rooms[i2]["name"] = "Sealed Closet"
			log.append("sealed unreachable room")
	return walls


static func _make_door(iv: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var p0: Vector2 = iv["p0"]
	var p1: Vector2 = iv["p1"]
	var length: float = float(iv["length"])
	var dir: Vector2 = (p1 - p0).normalized()
	var lo: float = DOOR_MARGIN + DOOR_W * 0.5
	var hi: float = length - DOOR_MARGIN - DOOR_W * 0.5
	var c_t: float = rng.randf_range(lo, maxf(lo, hi))
	var c: Vector2 = p0 + dir * c_t
	return {
		"room_a": int(iv["room_a"]),
		"room_b": int(iv["room_b"]),
		"center": c,
		"a": c - dir * DOOR_W * 0.5,
		"b": c + dir * DOOR_W * 0.5,
		"width": DOOR_W,
		"horizontal": bool(iv["horizontal"]),
	}


static func _build_walls(poly: PackedVector2Array, splits: Array, doors: Array) -> Array:
	var walls: Array = []
	# Exterior: true footprint edges (diagonals stay diagonal).
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		walls.append({"a": a, "b": b, "thickness": EXT_WALL, "outer": true})
	# Interior: split lines clipped to footprint, minus door openings.
	var seen: Dictionary = {}
	for s_v in splits:
		var s: Dictionary = s_v
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var key: String = "%d_%d_%d_%d" % [int(a.x), int(a.y), int(b.x), int(b.y)]
		if seen.has(key):
			continue
		seen[key] = true
		var horiz: bool = absf(a.y - b.y) < 0.5
		var clipped: Array = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly)
		for seg_v in clipped:
			var seg: PackedVector2Array = seg_v
			if seg.size() < 2:
				continue
			var s0: Vector2 = seg[0]
			var s1: Vector2 = seg[seg.size() - 1]
			var lo: float = minf(s0.x, s1.x) if horiz else minf(s0.y, s1.y)
			var hi: float = maxf(s0.x, s1.x) if horiz else maxf(s0.y, s1.y)
			var fixed: float = s0.y if horiz else s0.x
			var pieces: Array[Vector2] = [Vector2(lo, hi)]
			for d_v in doors:
				var d: Dictionary = d_v
				if bool(d["horizontal"]) != horiz:
					continue
				var dc: Vector2 = d["center"]
				if absf((dc.y if horiz else dc.x) - fixed) > 1.5:
					continue
				var d_lo: float = minf((d["a"] as Vector2).x, (d["b"] as Vector2).x) if horiz else minf((d["a"] as Vector2).y, (d["b"] as Vector2).y)
				var d_hi: float = maxf((d["a"] as Vector2).x, (d["b"] as Vector2).x) if horiz else maxf((d["a"] as Vector2).y, (d["b"] as Vector2).y)
				pieces = _cut_interval(pieces, d_lo, d_hi)
			for pc in pieces:
				if pc.y - pc.x < 3.0:
					continue
				var r: Rect2
				if horiz:
					r = Rect2(pc.x, fixed - INT_WALL * 0.5, pc.y - pc.x, INT_WALL)
				else:
					r = Rect2(fixed - INT_WALL * 0.5, pc.x, INT_WALL, pc.y - pc.x)
				walls.append({"rect": r, "outer": false})
	return walls


static func _cut_interval(pieces: Array[Vector2], c0: float, c1: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in pieces:
		if c1 <= p.x or c0 >= p.y:
			out.append(p)
			continue
		if c0 > p.x:
			out.append(Vector2(p.x, c0))
		if c1 < p.y:
			out.append(Vector2(c1, p.y))
	return out


static func _plan_entrances(poly: PackedVector2Array, rooms: Array, road_hint_m: Vector2, obb_angle: float, real_area: float) -> Array:
	var out: Array = []
	if poly.size() < 3:
		return out
	# Road direction in the OBB frame (road_hint_m is metres east/south of the centroid).
	var road_dir := Vector2(0.0, 1.0)
	if road_hint_m.length() > 0.5:
		var ca: float = cos(-obb_angle)
		var sa: float = sin(-obb_angle)
		road_dir = Vector2(road_hint_m.x * ca - road_hint_m.y * sa, road_hint_m.x * sa + road_hint_m.y * ca).normalized()
	var c: Vector2 = _poly_centroid(poly)
	var best_i: int = -1
	var best_s: float = -1e20
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if a.distance_to(b) < DOOR_W + 40.0:
			continue
		var mid: Vector2 = (a + b) * 0.5
		var s: float = (mid - c).normalized().dot(road_dir) * 2.0 + a.distance_to(b) / 400.0
		if s > best_s:
			best_s = s
			best_i = i
	if best_i >= 0:
		out.append(_entrance_on_edge(poly, best_i, c, "FRONT DOOR"))
	if real_area > 90.0:
		var worst_i: int = -1
		var worst_s: float = 1e20
		for i in range(poly.size()):
			var a2: Vector2 = poly[i]
			var b2: Vector2 = poly[(i + 1) % poly.size()]
			if i == best_i or a2.distance_to(b2) < DOOR_W + 40.0:
				continue
			var s2: float = ((a2 + b2) * 0.5 - c).normalized().dot(road_dir)
			if s2 < worst_s:
				worst_s = s2
				worst_i = i
		if worst_i >= 0:
			out.append(_entrance_on_edge(poly, worst_i, c, "BACK DOOR"))
	return out


static func _entrance_on_edge(poly: PackedVector2Array, i: int, c: Vector2, label: String) -> Dictionary:
	var a: Vector2 = poly[i]
	var b: Vector2 = poly[(i + 1) % poly.size()]
	var mid: Vector2 = (a + b) * 0.5
	var dir: Vector2 = (b - a).normalized()
	var nrm: Vector2 = Vector2(-dir.y, dir.x)
	if nrm.dot(mid - c) < 0.0:
		nrm = -nrm
	return {"center": mid, "dir": dir, "normal": nrm, "width": DOOR_W * 0.9, "label": label, "locked": true}


# ==============================================================================
# ROOM NAMES
# ==============================================================================

static func _count_open_rooms(rooms: Array) -> int:
	var n: int = 0
	for r in rooms:
		if not bool(r["solid"]):
			n += 1
	return n


static func _assign_room_names(rooms: Array, hub_idx: int, doors: Array, real_area: float) -> void:
	var order: Array = []
	for i in range(rooms.size()):
		if bool(rooms[i]["solid"]):
			rooms[i]["name"] = "Sealed Closet"
			continue
		if bool(rooms[i]["is_hall"]):
			continue
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool: return float(rooms[x]["area_px"]) > float(rooms[y]["area_px"]))
	var n: int = order.size()
	if n == 0:
		return
	var names: Array[String] = []
	# Largest: living room. Next largest adjacent-ish: kitchen. Smallest: bathroom.
	var seq: Array[String] = ["Living Room", "Kitchen", "Master Bedroom", "Bedroom", "Dining Room", "Kids Bedroom", "Study", "Utility Room", "Bedroom", "Pantry", "Storage", "Bedroom", "Study", "Storage"]
	if real_area > 350.0:
		seq = ["Living Room", "Kitchen", "Master Bedroom", "Bedroom", "Dining Room", "Garage Bay", "Kids Bedroom", "Study", "Utility Room", "Bedroom", "Storage", "Pantry", "Bedroom", "Storage"]
	var bath_idx: int = order[n - 1] if n >= 4 else -1
	var util_idx: int = order[n - 2] if n >= 7 else -1
	var k: int = 0
	var used_counts: Dictionary = {}
	for idx in order:
		var nm: String
		if idx == bath_idx:
			nm = "Bathroom"
		elif idx == util_idx:
			nm = "Utility Room"
		else:
			nm = seq[mini(k, seq.size() - 1)]
			k += 1
			if nm == "Utility Room" and util_idx >= 0:
				nm = "Storage"
		used_counts[nm] = int(used_counts.get(nm, 0)) + 1
		if int(used_counts[nm]) > 1 and nm in ["Bedroom", "Study", "Storage"]:
			nm = "%s %d" % [nm, int(used_counts[nm])]
		rooms[idx]["name"] = nm


static func base_room_kind(room_name: String) -> String:
	var s: String = room_name
	for d in ["2", "3", "4", "5"]:
		s = s.trim_suffix(" " + d)
	return s


# ==============================================================================
# HATCH / NAV GRID
# ==============================================================================

static func _pick_hatch_pos(room: Dictionary, walls: Array, poly: PackedVector2Array) -> Vector2:
	if room.is_empty():
		return _poly_centroid(poly)
	var rpoly: PackedVector2Array = room["polygon"]
	var c: Vector2 = room["center"]
	var rb: Rect2 = _poly_bounds(rpoly)
	var best: Vector2 = c
	var best_s: float = -1e20
	var y: float = rb.position.y + 8.0
	while y < rb.end.y:
		var x: float = rb.position.x + 8.0
		while x < rb.end.x:
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, rpoly):
				var clear: float = _clearance(p, walls)
				if clear >= HATCH_R + 22.0:
					var s: float = minf(clear, HATCH_R + 60.0) * 2.0 - p.distance_to(c)
					if s > best_s:
						best_s = s
						best = p
			x += 8.0
		y += 8.0
	return best


static func _clearance(p: Vector2, walls: Array) -> float:
	var best: float = 1e9
	for w_v in walls:
		var w: Dictionary = w_v
		if w.has("rect"):
			var r: Rect2 = w["rect"]
			var cx: float = clampf(p.x, r.position.x, r.end.x)
			var cy: float = clampf(p.y, r.position.y, r.end.y)
			best = minf(best, p.distance_to(Vector2(cx, cy)))
		else:
			var a: Vector2 = w["a"]
			var b: Vector2 = w["b"]
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - float(w.get("thickness", EXT_WALL)) * 0.5)
	return best


static func _nav_base(poly: PackedVector2Array, walls: Array, rooms: Array, bounds: Rect2) -> Dictionary:
	var origin: Vector2 = (bounds.position - Vector2(NAV_CELL * 2.0, NAV_CELL * 2.0)).snapped(Vector2(NAV_CELL, NAV_CELL))
	var cols: int = int(ceil((bounds.size.x + NAV_CELL * 4.0) / NAV_CELL)) + 1
	var rows: int = int(ceil((bounds.size.y + NAV_CELL * 4.0) / NAV_CELL)) + 1
	var nav: Dictionary = {"engine": ENGINE_TAG, "origin": origin, "cell_size": NAV_CELL, "cols": cols, "rows": rows}
	var inner_list: Array = Geometry2D.offset_polygon(poly, -(EXT_WALL * 0.5 + NAV_CLEAR))
	var walk := PackedByteArray()
	walk.resize(cols * rows)
	walk.fill(0)
	for ip_v in inner_list:
		var ip: PackedVector2Array = ip_v
		var ib: Rect2 = _poly_bounds(ip)
		var c0: Vector2i = HouseGenerator.world_to_cell(nav, ib.position)
		var c1: Vector2i = HouseGenerator.world_to_cell(nav, ib.end)
		for y in range(maxi(0, c0.y), mini(rows, c1.y + 1)):
			for x in range(maxi(0, c0.x), mini(cols, c1.x + 1)):
				if Geometry2D.is_point_in_polygon(HouseGenerator.cell_to_world(nav, Vector2i(x, y)), ip):
					walk[y * cols + x] = 1
	for w_v in walls:
		var w: Dictionary = w_v
		if w.has("rect"):
			_stamp(nav, walk, (w["rect"] as Rect2).grow(NAV_CLEAR))
	var room_index := PackedInt32Array()
	room_index.resize(cols * rows)
	room_index.fill(-1)
	for ri in range(rooms.size()):
		var rp: PackedVector2Array = rooms[ri]["polygon"]
		var rb: Rect2 = _poly_bounds(rp)
		var d0: Vector2i = HouseGenerator.world_to_cell(nav, rb.position)
		var d1: Vector2i = HouseGenerator.world_to_cell(nav, rb.end)
		for y in range(maxi(0, d0.y), mini(rows, d1.y + 1)):
			for x in range(maxi(0, d0.x), mini(cols, d1.x + 1)):
				if room_index[y * cols + x] == -1 and Geometry2D.is_point_in_polygon(HouseGenerator.cell_to_world(nav, Vector2i(x, y)), rp):
					room_index[y * cols + x] = ri
	nav["base_walkable"] = walk
	nav["room_index"] = room_index
	nav["room_count_total"] = rooms.size()
	return nav


static func _stamp(nav: Dictionary, mask: PackedByteArray, r: Rect2) -> void:
	var cols: int = int(nav["cols"])
	var rows: int = int(nav["rows"])
	var cs: float = float(nav["cell_size"])
	var origin: Vector2 = nav["origin"]
	var x0: int = maxi(0, int(ceil((r.position.x - origin.x) / cs - 0.5)))
	var x1: int = mini(cols - 1, int(floor((r.end.x - origin.x) / cs - 0.5)))
	var y0: int = maxi(0, int(ceil((r.position.y - origin.y) / cs - 0.5)))
	var y1: int = mini(rows - 1, int(floor((r.end.y - origin.y) / cs - 0.5)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			mask[y * cols + x] = 0


static func _nav_finalize(base: Dictionary, furniture: Array, hatch: Vector2) -> Dictionary:
	var nav: Dictionary = base.duplicate()
	var cols: int = int(nav["cols"])
	var rows: int = int(nav["rows"])
	var walk: PackedByteArray = (base["base_walkable"] as PackedByteArray).duplicate()
	for f_v in furniture:
		var f: Dictionary = f_v
		if bool(f.get("solid", true)):
			_stamp(nav, walk, (f["rect"] as Rect2).grow(NAV_CLEAR))
	nav["walkable"] = walk
	var start: Vector2i = _nearest_cell(nav, walk, HouseGenerator.world_to_cell(nav, hatch))
	var reachable := PackedByteArray()
	reachable.resize(cols * rows)
	reachable.fill(0)
	var walkable_cells: Array = []
	var room_index: PackedInt32Array = base["room_index"]
	var counts: Array = []
	counts.resize(int(base["room_count_total"]))
	counts.fill(0)
	if start.x >= 0:
		var queue := PackedInt32Array([start.y * cols + start.x])
		reachable[queue[0]] = 1
		var head: int = 0
		while head < queue.size():
			var idx: int = queue[head]
			head += 1
			var x: int = idx % cols
			var y: int = idx / cols
			walkable_cells.append(Vector2i(x, y))
			var ri: int = room_index[idx]
			if ri >= 0:
				counts[ri] = int(counts[ri]) + 1
			if x + 1 < cols and walk[idx + 1] == 1 and reachable[idx + 1] == 0:
				reachable[idx + 1] = 1
				queue.append(idx + 1)
			if x > 0 and walk[idx - 1] == 1 and reachable[idx - 1] == 0:
				reachable[idx - 1] = 1
				queue.append(idx - 1)
			if y + 1 < rows and walk[idx + cols] == 1 and reachable[idx + cols] == 0:
				reachable[idx + cols] = 1
				queue.append(idx + cols)
			if y > 0 and walk[idx - cols] == 1 and reachable[idx - cols] == 0:
				reachable[idx - cols] = 1
				queue.append(idx - cols)
	nav["reachable"] = reachable
	nav["walkable_cells"] = walkable_cells
	nav["hatch_cell"] = start
	nav["room_reachable_cells"] = counts
	return nav


static func _nearest_cell(nav: Dictionary, mask: PackedByteArray, c: Vector2i) -> Vector2i:
	var cols: int = int(nav["cols"])
	var rows: int = int(nav["rows"])
	for r in range(0, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x: int = c.x + dx
				var y: int = c.y + dy
				if x >= 0 and y >= 0 and x < cols and y < rows and mask[y * cols + x] == 1:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


static func is_reachable(nav: Dictionary, p: Vector2) -> bool:
	var c: Vector2i = HouseGenerator.world_to_cell(nav, p)
	var cols: int = int(nav.get("cols", 0))
	var rows: int = int(nav.get("rows", 0))
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return false
	var reach: PackedByteArray = nav["reachable"]
	return reach[c.y * cols + c.x] == 1


static func reachable_near(nav: Dictionary, p: Vector2, radius: float) -> bool:
	var cs: float = float(nav["cell_size"])
	var steps: int = int(ceil(radius / cs))
	for dy in range(-steps, steps + 1):
		for dx in range(-steps, steps + 1):
			var q: Vector2 = p + Vector2(float(dx), float(dy)) * cs
			if q.distance_to(p) <= radius and is_reachable(nav, q):
				return true
	return false


# ==============================================================================
# FURNITURE
# ==============================================================================

static func _place_furniture(rooms: Array, doors: Array, hatch: Vector2, nav_base: Dictionary, nav: Dictionary, rng: RandomNumberGenerator) -> Array:
	var placed: Array = []
	for ri in range(rooms.size()):
		var room: Dictionary = rooms[ri]
		if bool(room["solid"]):
			continue
		var nm: String = base_room_kind(str(room["name"]))
		var specs: Array = FURNITURE_SPECS.get(nm, FURNITURE_SPECS["Storage"])
		var rpoly: PackedVector2Array = room["polygon"]
		var inner_list: Array = Geometry2D.offset_polygon(rpoly, -(INT_WALL * 0.5 + 3.0))
		if inner_list.is_empty():
			continue
		var inner: PackedVector2Array = inner_list[0]
		var ib: Rect2 = _poly_bounds(inner)
		var room_area_m2: float = float(room["area_px"]) / (PX_PER_M * PX_PER_M)
		var budget: int = clampi(int(room_area_m2 / 4.0), 1, specs.size())
		var obstacles_extra: int = 1 if room_area_m2 > 14.0 else 0
		var to_place: Array = []
		for s_i in range(budget):
			to_place.append(specs[s_i])
		for _e in range(obstacles_extra):
			to_place.append(["boxes" if rng.randf() < 0.5 else "toppled_chair", 0.8, 0.7, true])
		for spec_v in to_place:
			var spec: Array = spec_v
			var kind: String = str(spec[0])
			var w: float = float(spec[1]) * PX_PER_M
			var h: float = float(spec[2]) * PX_PER_M
			var solid: bool = bool(spec[3])
			var ok: bool = false
			for attempt in range(40):
				var rot: bool = rng.randf() < 0.5
				var fw: float = h if rot else w
				var fh: float = w if rot else h
				if fw > ib.size.x - 4.0 or fh > ib.size.y - 4.0:
					continue
				var along_wall: bool = kind != "rug" and kind != "boxes" and kind != "toppled_chair" and kind != "dining_table" and kind != "kitchen_table" and kind != "coffee_table"
				var pos := Vector2(rng.randf_range(ib.position.x, ib.end.x - fw), rng.randf_range(ib.position.y, ib.end.y - fh))
				if along_wall:
					var side: int = rng.randi_range(0, 3)
					match side:
						0: pos.y = ib.position.y
						1: pos.y = ib.end.y - fh
						2: pos.x = ib.position.x
						_: pos.x = ib.end.x - fw
				var fr := Rect2(pos, Vector2(fw, fh))
				if not _rect_inside_poly(fr, inner):
					continue
				if fr.grow(HATCH_R + 26.0).has_point(hatch):
					continue
				var near_door: bool = false
				for d_v in doors:
					var dc: Vector2 = (d_v as Dictionary)["center"]
					if _dist_point_rect(dc, fr) < DOOR_W * 0.5 + 30.0:
						near_door = true
						break
				if near_door:
					continue
				var overlap: bool = false
				for p_v in placed:
					var pr: Rect2 = (p_v as Dictionary)["rect"]
					if pr.grow(6.0).intersects(fr) and (bool((p_v as Dictionary)["solid"]) and solid):
						overlap = true
						break
				if overlap:
					continue
				var cand: Dictionary = {"rect": fr, "type": kind, "label": kind.replace("_", " ").capitalize(), "solid": solid, "room": str(room["name"])}
				if solid:
					var test: Array = placed.duplicate()
					test.append(cand)
					var tnav: Dictionary = _nav_finalize(nav_base, test, hatch)
					if not _all_rooms_ok(rooms, tnav, nav):
						continue
				placed.append(cand)
				ok = true
				break
			if not ok:
				continue
	return placed


static func _rect_inside_poly(r: Rect2, poly: PackedVector2Array) -> bool:
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center()]:
		if not Geometry2D.is_point_in_polygon(p, poly):
			return false
	return true


static func _dist_point_rect(p: Vector2, r: Rect2) -> float:
	var cx: float = clampf(p.x, r.position.x, r.end.x)
	var cy: float = clampf(p.y, r.position.y, r.end.y)
	return p.distance_to(Vector2(cx, cy))


static func _all_rooms_ok(rooms: Array, tnav: Dictionary, base_nav: Dictionary) -> bool:
	var t_counts: Array = tnav["room_reachable_cells"]
	var b_counts: Array = base_nav["room_reachable_cells"]
	for i in range(rooms.size()):
		if bool(rooms[i]["solid"]):
			continue
		var tb: int = int(t_counts[i])
		var bb: int = int(b_counts[i])
		# every open room must stay reachable and keep at least 45% of its free floor
		if bb > 0 and (tb == 0 or float(tb) < float(bb) * 0.45):
			return false
	return true


# ==============================================================================
# SPAWNS
# ==============================================================================

static func _reachable_points_in_room(nav: Dictionary, room: Dictionary) -> Array:
	var pts: Array = []
	var rp: PackedVector2Array = room["polygon"]
	var rb: Rect2 = _poly_bounds(rp)
	var cols: int = int(nav["cols"])
	var rows: int = int(nav["rows"])
	var reach: PackedByteArray = nav["reachable"]
	var c0: Vector2i = HouseGenerator.world_to_cell(nav, rb.position)
	var c1: Vector2i = HouseGenerator.world_to_cell(nav, rb.end)
	for y in range(maxi(0, c0.y), mini(rows, c1.y + 1)):
		for x in range(maxi(0, c0.x), mini(cols, c1.x + 1)):
			if reach[y * cols + x] == 1:
				var w: Vector2 = HouseGenerator.cell_to_world(nav, Vector2i(x, y))
				if Geometry2D.is_point_in_polygon(w, rp):
					pts.append(w)
	return pts


static func _pick_leader_start(nav: Dictionary, hatch: Vector2) -> Vector2:
	var best: Vector2 = hatch + Vector2(0.0, HATCH_R + 34.0)
	var best_err: float = 1e20
	for c_v in nav["walkable_cells"]:
		var w: Vector2 = HouseGenerator.cell_to_world(nav, c_v)
		var err: float = absf(w.distance_to(hatch) - (HATCH_R + 36.0))
		if err < best_err:
			best_err = err
			best = w
	return best


static func _spawn_family(family_members: Array, rooms: Array, nav: Dictionary, hatch: Vector2, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var taken: Array = []
	for m_v in family_members:
		var m: Dictionary = m_v
		if bool(m.get("is_leader", false)):
			continue
		var role: String = str(m.get("role", "adult"))
		var prefs: Array[String] = ["Master Bedroom", "Bedroom", "Living Room", "Study", "Dining Room"]
		if role == "child":
			prefs = ["Kids Bedroom", "Bedroom", "Living Room", "Study"]
		elif role == "teen":
			prefs = ["Bedroom", "Kids Bedroom", "Study", "Living Room"]
		elif role == "elder":
			prefs = ["Living Room", "Master Bedroom", "Bedroom", "Study"]
		var cands: Array = []
		for pref in prefs:
			for r_v in rooms:
				var r: Dictionary = r_v
				if not bool(r["solid"]) and base_room_kind(str(r["name"])) == pref:
					cands.append_array(_reachable_points_in_room(nav, r))
			if cands.size() > 6:
				break
		if cands.is_empty():
			for c_v in nav["walkable_cells"]:
				cands.append(HouseGenerator.cell_to_world(nav, c_v))
		# Prefer far from hatch and from other family members.
		var best: Vector2 = cands[0]
		var best_s: float = -1e20
		for _t in range(30):
			var p: Vector2 = cands[rng.randi_range(0, cands.size() - 1)]
			var s: float = p.distance_to(hatch)
			for q in taken:
				s = minf(s, (q as Vector2).distance_to(p) * 1.6)
			s += rng.randf() * 40.0
			if s > best_s:
				best_s = s
				best = p
		taken.append(best)
		out.append({"member_id": str(m.get("id", "")), "name": str(m.get("name", "")), "pos": best, "room": _room_name_at(rooms, best)})
	return out


static func _room_name_at(rooms: Array, p: Vector2) -> String:
	var i: int = _room_at(rooms, p)
	return str(rooms[i]["name"]) if i >= 0 else ""


static func _spawn_items(rooms: Array, furniture: Array, nav: Dictionary, hatch: Vector2, family_spawns: Array, real_area: float, rng: RandomNumberGenerator) -> Array:
	var ids: Array[String] = []
	for _i in range(rng.randi_range(5, 8)):
		ids.append("soup")
	for _i in range(rng.randi_range(5, 8)):
		ids.append("water")
	ids.append_array(["medkit", "gas_mask", "radio", "suitcase"])
	var bonus: int = rng.randi_range(10, 12) + clampi(int((real_area - 100.0) / 40.0), 0, 7)
	var pool: Array[String] = BONUS_POOL.duplicate()
	for i in range(bonus):
		if pool.is_empty():
			pool = BONUS_POOL.duplicate()
		var pick: int = rng.randi_range(0, pool.size() - 1)
		var iid: String = pool[pick]
		pool.remove_at(pick)
		if iid == "suitcase" and ids.has("suitcase"):
			iid = "map"
		ids.append(iid)

	# Candidate spots: reachable floor + furniture tops reachable within arm's reach.
	var room_spots: Dictionary = {}
	for r_v in rooms:
		var r: Dictionary = r_v
		if bool(r["solid"]):
			continue
		var spots: Array = []
		for p in _reachable_points_in_room(nav, r):
			if (p as Vector2).distance_to(hatch) > HATCH_R + 70.0:
				spots.append(p)
		for f_v in furniture:
			var f: Dictionary = f_v
			if str(f.get("room", "")) != str(r["name"]) or not bool(f.get("solid", true)):
				continue
			var fc: Vector2 = (f["rect"] as Rect2).get_center()
			if reachable_near(nav, fc, 40.0) and fc.distance_to(hatch) > HATCH_R + 70.0:
				spots.append(fc)
				spots.append(fc)
		room_spots[str(r["name"])] = spots
	var out: Array = []
	var taken: Array = []
	for f in family_spawns:
		taken.append((f as Dictionary)["pos"])
	var all_names: Array = room_spots.keys()
	# Spread loot: no room may hold more than ~1.7x its fair share.
	var per_room_cap: int = maxi(3, int(ceil(float(ids.size()) / maxf(1.0, float(all_names.size())) * 1.7)))
	var room_load: Dictionary = {}
	for iid in ids:
		var prefs: Array = ITEM_ROOMS.get(iid, [])
		var cands: Array = []
		for pref in prefs:
			for rn in all_names:
				if base_room_kind(str(rn)) == pref and int(room_load.get(rn, 0)) < per_room_cap:
					cands.append_array(room_spots[rn])
		if cands.size() < 4:
			for rn in all_names:
				if int(room_load.get(rn, 0)) < per_room_cap:
					cands.append_array(room_spots[rn])
		if cands.is_empty():
			for rn in all_names:
				cands.append_array(room_spots[rn])
		if cands.is_empty():
			continue
		# Distance-weighted choice: far rooms are favoured, which makes full clears costly.
		var best: Vector2 = Vector2.INF
		var best_s: float = -1e20
		for _t in range(18):
			var p: Vector2 = cands[rng.randi_range(0, cands.size() - 1)]
			var clash: bool = false
			for q in taken:
				if (q as Vector2).distance_to(p) < 30.0:
					clash = true
					break
			if clash:
				continue
			var s: float = p.distance_to(hatch) * rng.randf_range(0.6, 1.0)
			if s > best_s:
				best_s = s
				best = p
		if best == Vector2.INF:
			continue
		taken.append(best)
		var rname: String = _room_name_at(rooms, best)
		room_load[rname] = int(room_load.get(rname, 0)) + 1
		out.append({"item_id": iid, "pos": best, "room": rname})
	return out


# ==============================================================================
# PATHFINDING (binary-heap A* on the verified grid)
# ==============================================================================

static func find_path(nav: Dictionary, from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cols: int = int(nav.get("cols", 0))
	var rows: int = int(nav.get("rows", 0))
	var reach: PackedByteArray = nav.get("reachable", PackedByteArray())
	if cols <= 0 or reach.size() != cols * rows:
		out.append(to_pos)
		return out
	var s: Vector2i = _nearest_cell(nav, reach, HouseGenerator.world_to_cell(nav, from_pos))
	var g: Vector2i = _nearest_cell(nav, reach, HouseGenerator.world_to_cell(nav, to_pos))
	if s.x < 0 or g.x < 0:
		out.append(to_pos)
		return out
	var n: int = cols * rows
	var gs := PackedFloat32Array()
	gs.resize(n)
	gs.fill(1e20)
	var came := PackedInt32Array()
	came.resize(n)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	closed.fill(0)
	var si: int = s.y * cols + s.x
	var gi: int = g.y * cols + g.x
	gs[si] = 0.0
	var heap_f: Array[float] = [0.0]
	var heap_i: Array[int] = [si]
	var dxs: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
	var dys: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]
	while not heap_i.is_empty():
		var cur: int = heap_i[0]
		_heap_pop(heap_f, heap_i)
		if cur == gi:
			break
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		var cx: int = cur % cols
		var cy: int = cur / cols
		for d in range(8):
			var nx: int = cx + dxs[d]
			var ny: int = cy + dys[d]
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var ni: int = ny * cols + nx
			if reach[ni] == 0 or closed[ni] == 1:
				continue
			var cost: float = 1.0
			if d >= 4:
				if reach[cy * cols + nx] == 0 or reach[ny * cols + cx] == 0:
					continue
				cost = 1.41421356
			var tg: float = gs[cur] + cost
			if tg < gs[ni]:
				gs[ni] = tg
				came[ni] = cur
				var h: float = Vector2(float(nx - g.x), float(ny - g.y)).length()
				_heap_push(heap_f, heap_i, tg + h, ni)
	if came[gi] == -1 and gi != si:
		out.append(to_pos)
		return out
	var chain: Array[int] = []
	var c: int = gi
	while c != -1:
		chain.append(c)
		if c == si:
			break
		c = came[c]
	chain.reverse()
	var raw := PackedVector2Array()
	raw.append(from_pos)
	for idx in chain:
		raw.append(HouseGenerator.cell_to_world(nav, Vector2i(idx % cols, idx / cols)))
	if is_reachable(nav, to_pos):
		raw.append(to_pos)
	# line-of-sight smoothing
	var sm := PackedVector2Array()
	sm.append(raw[0])
	var anchor: int = 0
	var i: int = 1
	while i < raw.size():
		if i + 1 < raw.size() and _los(nav, raw[anchor], raw[i + 1]):
			i += 1
			continue
		sm.append(raw[i])
		anchor = i
		i += 1
	if sm.size() < 2:
		sm.append(to_pos)
	return sm


static func _los(nav: Dictionary, a: Vector2, b: Vector2) -> bool:
	var cs: float = float(nav["cell_size"]) * 0.4
	var d: float = a.distance_to(b)
	var steps: int = maxi(1, int(ceil(d / cs)))
	for k in range(1, steps):
		var p: Vector2 = a.lerp(b, float(k) / float(steps))
		if not is_reachable(nav, p):
			return false
	return true


static func _heap_push(hf: Array[float], hi: Array[int], f: float, idx: int) -> void:
	hf.append(f)
	hi.append(idx)
	var k: int = hf.size() - 1
	while k > 0:
		var p: int = (k - 1) / 2
		if hf[p] <= hf[k]:
			break
		var tf: float = hf[p]
		hf[p] = hf[k]
		hf[k] = tf
		var ti: int = hi[p]
		hi[p] = hi[k]
		hi[k] = ti
		k = p


static func _heap_pop(hf: Array[float], hi: Array[int]) -> void:
	var last: int = hf.size() - 1
	hf[0] = hf[last]
	hi[0] = hi[last]
	hf.remove_at(last)
	hi.remove_at(last)
	var k: int = 0
	var n: int = hf.size()
	while true:
		var l: int = k * 2 + 1
		var r: int = l + 1
		var m: int = k
		if l < n and hf[l] < hf[m]:
			m = l
		if r < n and hf[r] < hf[m]:
			m = r
		if m == k:
			break
		var tf: float = hf[m]
		hf[m] = hf[k]
		hf[k] = tf
		var ti: int = hi[m]
		hi[m] = hi[k]
		hi[k] = ti
		k = m
