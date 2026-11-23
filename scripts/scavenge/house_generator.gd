class_name HouseGenerator
extends RefCounted

## Procedural real-world OpenStreetMap house floorplan generator for
## "60 Seconds: World Reatomized".
## Converts an OSM building polygon (footprint_meters) into a scaled, centered,
## 6-room mid-century suburban house with wide doorways, thematic props,
## self-healing BFS walkability verification from the Fallout Bunker Hatch,
## A* pathfinding, and authentic 60 Seconds! survival item & family spawns.

const PX_PER_METER: float = 46.0
const MIN_HOUSE_WIDTH_M: float = 14.0
const MAX_HOUSE_WIDTH_M: float = 22.0
const MIN_HOUSE_HEIGHT_M: float = 11.0
const MAX_HOUSE_HEIGHT_M: float = 17.0

const DEFAULT_HATCH_RADIUS: float = 52.0
const DOOR_WIDTH: float = 84.0
const EXTERIOR_WALL_THICK: float = 16.0
const INTERIOR_WALL_THICK: float = 12.0

const NAV_CELL_SIZE: float = 24.0
const PLAYER_COLLISION_RADIUS: float = 18.0

const MIN_FURNITURE_DOOR_DIST: float = 95.0
const MIN_FURNITURE_HATCH_DIST: float = 110.0
const MIN_ITEM_HATCH_DIST: float = 95.0
const MIN_ITEM_SPACING: float = 38.0
const LEADER_TARGET_HATCH_DIST: float = 90.0

const ROOM_CENTRAL_HALL: String = "Central Hall"
const ROOM_KITCHEN: String = "Kitchen"
const ROOM_LIVING: String = "Living Room"
const ROOM_MASTER_BED: String = "Master Bedroom"
const ROOM_KIDS_BED: String = "Kids Bedroom"
const ROOM_BATH_UTILITY: String = "Bathroom & Utility"

const ITEM_META: Dictionary = {
	"soup": {
		"name": "Tomato Soup Can",
		"slots": 1,
		"rooms": [ROOM_KITCHEN, ROOM_BATH_UTILITY]
	},
	"water": {
		"name": "Emergency Water",
		"slots": 1,
		"rooms": [ROOM_KITCHEN, ROOM_BATH_UTILITY]
	},
	"medkit": {
		"name": "First Aid Medkit",
		"slots": 1,
		"rooms": [ROOM_BATH_UTILITY, ROOM_MASTER_BED]
	},
	"gas_mask": {
		"name": "Civil Defense Gas Mask",
		"slots": 1,
		"rooms": [ROOM_BATH_UTILITY, ROOM_MASTER_BED, ROOM_CENTRAL_HALL]
	},
	"radio": {
		"name": "CONELRAD Tube Radio",
		"slots": 1,
		"rooms": [ROOM_LIVING, ROOM_KITCHEN]
	},
	"suitcase": {
		"name": "Leather Suitcase",
		"slots": 2,
		"rooms": [ROOM_MASTER_BED, ROOM_KIDS_BED, ROOM_CENTRAL_HALL]
	},
	"book": {
		"name": "Boy Scout Handbook",
		"slots": 1,
		"rooms": [ROOM_LIVING, ROOM_KIDS_BED, ROOM_MASTER_BED]
	},
	"flashlight": {
		"name": "Heavy Flashlight",
		"slots": 1,
		"rooms": [ROOM_BATH_UTILITY, ROOM_MASTER_BED, ROOM_KITCHEN]
	},
	"map": {
		"name": "Neighborhood Evacuation Map",
		"slots": 1,
		"rooms": [ROOM_LIVING, ROOM_MASTER_BED, ROOM_CENTRAL_HALL]
	},
	"ammo": {
		"name": "Rifle Ammunition",
		"slots": 1,
		"rooms": [ROOM_MASTER_BED, ROOM_BATH_UTILITY, ROOM_LIVING]
	},
	"bug_spray": {
		"name": "Atomic Bug Spray",
		"slots": 1,
		"rooms": [ROOM_BATH_UTILITY, ROOM_KITCHEN]
	},
	"padlock": {
		"name": "Heavy Steel Padlock",
		"slots": 1,
		"rooms": [ROOM_BATH_UTILITY, ROOM_CENTRAL_HALL]
	},
	"cards": {
		"name": "Playing Cards",
		"slots": 1,
		"rooms": [ROOM_LIVING, ROOM_KIDS_BED]
	},
	"checkers": {
		"name": "Checkers Board",
		"slots": 1,
		"rooms": [ROOM_KIDS_BED, ROOM_LIVING]
	},
	"harmonica": {
		"name": "Chrome Harmonica",
		"slots": 1,
		"rooms": [ROOM_KIDS_BED, ROOM_LIVING, ROOM_MASTER_BED]
	},
	"toolbox": {
		"name": "Repair Toolbox",
		"slots": 2,
		"rooms": [ROOM_BATH_UTILITY, ROOM_KITCHEN]
	},
	"axe": {
		"name": "Fireman's Axe",
		"slots": 2,
		"rooms": [ROOM_BATH_UTILITY, ROOM_KITCHEN]
	},
	"rifle": {
		"name": "Hunting Rifle",
		"slots": 2,
		"rooms": [ROOM_MASTER_BED, ROOM_LIVING]
	}
}

const RANDOM_BONUS_POOL: Array[String] = [
	"flashlight", "map", "ammo", "bug_spray", "padlock",
	"cards", "checkers", "harmonica", "toolbox", "axe", "rifle"
]


static func generate_from_osm_house(
	house_data: Dictionary,
	family_members: Array,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var local_rng: RandomNumberGenerator = rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.seed = 19550601

	# 1. Extract, OBB-align, normalize, and scale OSM footprint to [14..22m] x [11..17m] in pixels.
	var norm_info: Dictionary = _normalize_footprint(house_data)
	var raw_osm_polygon: PackedVector2Array = norm_info["raw_osm_polygon"]
	var raw_osm_bounds: Rect2 = norm_info["outer_bounds"]
	var fill_ratio: float = float(norm_info["fill_ratio"])

	# 2. Subdivide interior into 6 distinct named rooms fitted to the OBB-aligned OSM silhouette.
	var rooms: Array = _build_six_rooms(raw_osm_polygon, raw_osm_bounds, fill_ratio, local_rng)

	# Compute exact outer orthogonal boundary polygon of the generated rooms union
	# (4 corners for rectangular union, 6 corners for notched L-wing union).
	var outer_polygon: PackedVector2Array = _compute_rooms_union_polygon(rooms)

	# Compute exact interior & exterior bounds across all generated rooms.
	var interior_bounds: Rect2 = _compute_rooms_bounds(rooms)
	var total_bounds: Rect2 = interior_bounds.grow(EXTERIOR_WALL_THICK)

	# Locate Central Hall and snap Fallout Bunker Hatch to a clean grid-aligned center.
	var hall_room: Dictionary = _find_room_by_name(rooms, ROOM_CENTRAL_HALL)
	var hall_rect: Rect2 = hall_room["rect"]
	var nav_origin: Vector2 = Vector2(
		floorf((total_bounds.position.x - NAV_CELL_SIZE) / NAV_CELL_SIZE) * NAV_CELL_SIZE,
		floorf((total_bounds.position.y - NAV_CELL_SIZE) / NAV_CELL_SIZE) * NAV_CELL_SIZE
	)
	var raw_hatch: Vector2 = hall_rect.get_center()
	var hatch_cx: int = int(floorf((raw_hatch.x - nav_origin.x) / NAV_CELL_SIZE))
	var hatch_cy: int = int(floorf((raw_hatch.y - nav_origin.y) / NAV_CELL_SIZE))
	var hatch_pos: Vector2 = nav_origin + Vector2((float(hatch_cx) + 0.5) * NAV_CELL_SIZE, (float(hatch_cy) + 0.5) * NAV_CELL_SIZE)
	# Clamp safely inside Central Hall if grid snap drifted slightly.
	var safe_hall: Rect2 = hall_rect.grow(-64.0)
	if safe_hall.size.x > 4.0 and safe_hall.size.y > 4.0:
		hatch_pos.x = clampf(hatch_pos.x, safe_hall.position.x, safe_hall.end.x)
		hatch_pos.y = clampf(hatch_pos.y, safe_hall.position.y, safe_hall.end.y)
	else:
		hatch_pos = hall_rect.get_center()
	var hatch_radius: float = DEFAULT_HATCH_RADIUS

	# 3. Carve wide doorways (DOOR_WIDTH = 84.0 px) and build interior & exterior walls.
	var doorways: Array = _plan_doorways(rooms, DOOR_WIDTH)
	var walls: Array = _build_walls_from_rooms(rooms, doorways, DOOR_WIDTH)

	# 4. Place decorative/collidable furniture strictly along room edges/corners,
	#    NEVER within 95 px of any doorway or within 110 px of hatch_pos.
	var furniture: Array = _place_all_furniture(rooms, doorways, hatch_pos, local_rng)

	# 5. Build discrete navigation grid (24.0 px) & run BFS flood-fill from hatch_pos.
	#    Self-heal doorways and furniture if ANY room center is unreachable!
	var nav_grid: Dictionary = _build_and_verify_nav_grid(
		rooms,
		doorways,
		walls,
		furniture,
		total_bounds,
		nav_origin,
		hatch_pos
	)
	# Refresh walls in case self-healing widened or added any doorway.
	walls = nav_grid.get("_resolved_walls", walls)
	nav_grid.erase("_resolved_walls")

	# 6. Place leader_start_pos (~90 px from hatch_pos), non-leader family_members,
	#    and authentic 60 Seconds! survival items on verified BFS-reachable cells.
	var leader_start_pos: Vector2 = _pick_leader_start_pos(nav_grid, rooms, walls, furniture, hatch_pos)
	var family_spawns: Array = _spawn_family_members(
		family_members,
		rooms,
		walls,
		furniture,
		nav_grid,
		hatch_pos,
		leader_start_pos,
		local_rng
	)
	var items: Array = _spawn_house_items(
		rooms,
		walls,
		furniture,
		nav_grid,
		hatch_pos,
		leader_start_pos,
		family_spawns,
		local_rng
	)

	# 7. Verify via Geometry2D.is_point_in_polygon (with 2px boundary tolerance) that 100%
	#    of room centers, furniture, spawned items, and family spawns lie strictly inside outer_polygon.
	_enforce_inside_outer_polygon(
		outer_polygon,
		rooms,
		furniture,
		items,
		family_spawns,
		nav_grid
	)

	return {
		"bounds": total_bounds,
		"interior_bounds": interior_bounds,
		"outer_polygon": outer_polygon,
		"raw_osm_polygon": raw_osm_polygon,
		"obb_angle_deg": float(norm_info.get("obb_angle_deg", 0.0)),
		"rooms": rooms,
		"doorways": doorways,
		"walls": walls,
		"furniture": furniture,
		"hatch_pos": hatch_pos,
		"hatch_radius": hatch_radius,
		"leader_start_pos": leader_start_pos,
		"items": items,
		"family_spawns": family_spawns,
		"nav_grid": nav_grid
	}


## Pathfinds between any two world positions using the house's verified navigation grid.
## Uses corner-safe 8-directional A* plus walkable line-of-sight smoothing so neither
## the Demo AI nor Critic Agents ever clip doorframes or furniture corners.
static func find_path(nav_grid: Dictionary, from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var cols: int = int(nav_grid.get("cols", 0))
	var rows: int = int(nav_grid.get("rows", 0))
	if cols <= 0 or rows <= 0:
		result.append(to_pos)
		return result

	var reachable: PackedByteArray = nav_grid.get("reachable", PackedByteArray())
	if reachable.size() != cols * rows:
		result.append(to_pos)
		return result

	var start_cell: Vector2i = _nearest_reachable_cell(nav_grid, world_to_cell(nav_grid, from_pos))
	var goal_cell: Vector2i = _nearest_reachable_cell(nav_grid, world_to_cell(nav_grid, to_pos))
	if start_cell.x < 0 or goal_cell.x < 0:
		result.append(to_pos)
		return result

	if start_cell == goal_cell:
		result.append(from_pos)
		if is_walkable(nav_grid, to_pos):
			result.append(to_pos)
		else:
			result.append(cell_to_world(nav_grid, goal_cell))
		return result

	var total_cells: int = cols * rows
	var g_score := PackedFloat32Array()
	g_score.resize(total_cells)
	g_score.fill(1.0e20)

	var came_from := PackedInt32Array()
	came_from.resize(total_cells)
	came_from.fill(-1)

	var closed := PackedByteArray()
	closed.resize(total_cells)
	closed.fill(0)

	var start_idx: int = start_cell.y * cols + start_cell.x
	var goal_idx: int = goal_cell.y * cols + goal_cell.x
	g_score[start_idx] = 0.0

	var open_list: Array[int] = [start_idx]
	var dirs_x: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
	var dirs_y: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]

	while not open_list.is_empty():
		var best_list_pos: int = 0
		var best_idx: int = open_list[0]
		var best_f: float = g_score[best_idx] + _heuristic_cells(best_idx % cols, best_idx / cols, goal_cell.x, goal_cell.y)
		for i in range(1, open_list.size()):
			var cand_idx: int = open_list[i]
			var cand_f: float = g_score[cand_idx] + _heuristic_cells(cand_idx % cols, cand_idx / cols, goal_cell.x, goal_cell.y)
			if cand_f < best_f:
				best_f = cand_f
				best_idx = cand_idx
				best_list_pos = i

		open_list.remove_at(best_list_pos)
		if best_idx == goal_idx:
			break
		if closed[best_idx] == 1:
			continue
		closed[best_idx] = 1

		var cx: int = best_idx % cols
		var cy: int = best_idx / cols
		for d in range(8):
			var nx: int = cx + dirs_x[d]
			var ny: int = cy + dirs_y[d]
			if nx < 0 or nx >= cols or ny < 0 or ny >= rows:
				continue
			var n_idx: int = ny * cols + nx
			if reachable[n_idx] == 0 or closed[n_idx] == 1:
				continue
			var step_cost: float = 1.0
			if d >= 4:
				# Strict corner-safe rule: diagonal step requires BOTH cardinal neighbors walkable.
				var adj1: int = cy * cols + nx
				var adj2: int = ny * cols + cx
				if reachable[adj1] == 0 or reachable[adj2] == 0:
					continue
				step_cost = 1.41421356
			var tentative_g: float = g_score[best_idx] + step_cost
			if tentative_g < g_score[n_idx]:
				came_from[n_idx] = best_idx
				g_score[n_idx] = tentative_g
				if not open_list.has(n_idx):
					open_list.append(n_idx)

	# Reconstruct cell path (fallback to BFS tree via hatch if disconnected, though verified connected).
	var cell_chain: Array[Vector2i] = []
	if came_from[goal_idx] != -1 or goal_idx == start_idx:
		var cur: int = goal_idx
		while cur != -1:
			cell_chain.append(Vector2i(cur % cols, cur / cols))
			if cur == start_idx:
				break
			cur = came_from[cur]
		cell_chain.reverse()
	else:
		result.append(cell_to_world(nav_grid, goal_cell))
		return result

	var raw_pts := PackedVector2Array()
	var can_start_from_exact: bool = _point_clear_of_obstacles(nav_grid, from_pos)
	if can_start_from_exact:
		raw_pts.append(from_pos)
	for c in cell_chain:
		raw_pts.append(cell_to_world(nav_grid, c))
	if is_walkable(nav_grid, to_pos) and _point_clear_of_obstacles(nav_grid, to_pos):
		raw_pts[raw_pts.size() - 1] = to_pos

	# Smooth redundant collinear/clear intermediate waypoints while preserving exact corner safety.
	# Always retain >= 2 waypoints ([start, ..., goal]) so callers checking path.size() >= 2 succeed cleanly.
	var smoothed: PackedVector2Array = _smooth_path(nav_grid, raw_pts)
	if smoothed.size() < 2:
		var pair := PackedVector2Array()
		pair.append(from_pos)
		pair.append(smoothed[0] if smoothed.size() == 1 else to_pos)
		return pair
	return smoothed


static func world_to_cell(nav_grid: Dictionary, world_pos: Vector2) -> Vector2i:
	var origin: Vector2 = nav_grid.get("origin", Vector2.ZERO)
	var csize: float = float(nav_grid.get("cell_size", NAV_CELL_SIZE))
	var cx: int = int(floorf((world_pos.x - origin.x) / csize))
	var cy: int = int(floorf((world_pos.y - origin.y) / csize))
	return Vector2i(cx, cy)


static func cell_to_world(nav_grid: Dictionary, cell: Vector2i) -> Vector2:
	var origin: Vector2 = nav_grid.get("origin", Vector2.ZERO)
	var csize: float = float(nav_grid.get("cell_size", NAV_CELL_SIZE))
	return origin + Vector2((float(cell.x) + 0.5) * csize, (float(cell.y) + 0.5) * csize)


static func is_walkable(nav_grid: Dictionary, world_pos: Vector2) -> bool:
	var cols: int = int(nav_grid.get("cols", 0))
	var rows: int = int(nav_grid.get("rows", 0))
	var c: Vector2i = world_to_cell(nav_grid, world_pos)
	if c.x < 0 or c.x >= cols or c.y < 0 or c.y >= rows:
		return false
	var reachable: PackedByteArray = nav_grid.get("reachable", PackedByteArray())
	var idx: int = c.y * cols + c.x
	if idx < 0 or idx >= reachable.size():
		return false
	return reachable[idx] == 1


# ---------------------------------------------------------------------------
# Step 1: OSM Footprint Extraction, Scaling & Normalization
# ---------------------------------------------------------------------------

static func _default_l_house_meters() -> Array[Vector2]:
	return [
		Vector2(-7.2, -6.0),
		Vector2(7.2, -6.0),
		Vector2(7.2, 1.5),
		Vector2(3.5, 1.5),
		Vector2(3.5, 6.2),
		Vector2(-7.2, 6.2)
	]


static func _extract_footprint_meters(house_data: Dictionary) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var raw_val: Variant = house_data.get("footprint_meters", [])
	if raw_val is Array or raw_val is PackedVector2Array:
		for entry in raw_val:
			var v: Vector2 = Vector2.ZERO
			var ok: bool = false
			if entry is Vector2:
				v = entry
				ok = true
			elif entry is Dictionary:
				var d: Dictionary = entry
				v = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
				ok = true
			elif entry is Array:
				var arr: Array = entry
				if arr.size() >= 2:
					v = Vector2(float(arr[0]), float(arr[1]))
					ok = true
			if ok and is_finite(v.x) and is_finite(v.y):
				if pts.is_empty() or pts[pts.size() - 1].distance_to(v) > 0.02:
					pts.append(v)

	# Remove duplicate closing point if OSM way repeated its first node at the end.
	while pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.03:
		pts.remove_at(pts.size() - 1)

	if pts.size() < 3:
		return _default_l_house_meters()

	var area_m2: float = absf(_polygon_signed_area(pts))
	if area_m2 < 1.0:
		return _default_l_house_meters()

	return pts


static func _orient_footprint_to_obb(raw_pts: Array[Vector2]) -> Dictionary:
	var n: int = raw_pts.size()
	if n < 3:
		return {"points": raw_pts, "angle_rad": 0.0}

	var cand_angles: Array[float] = [0.0]
	for i in range(n):
		var p0: Vector2 = raw_pts[i]
		var p1: Vector2 = raw_pts[(i + 1) % n]
		var diff: Vector2 = p1 - p0
		if diff.length_squared() < 1.0e-5:
			continue
		var edge_ang: float = atan2(diff.y, diff.x)
		# Wrap into [-PI/4, PI/4) to find minimal axis-alignment rotation.
		var norm_ang: float = fposmod(edge_ang + PI * 0.25, PI * 0.5) - PI * 0.25
		cand_angles.append(norm_ang)

	var best_angle: float = 0.0
	var best_area: float = 1.0e30
	for ang in cand_angles:
		var ca: float = cos(-ang)
		var sa: float = sin(-ang)
		var c_min_x: float = 1.0e20
		var c_max_x: float = -1.0e20
		var c_min_y: float = 1.0e20
		var c_max_y: float = -1.0e20
		for p in raw_pts:
			var rx: float = p.x * ca - p.y * sa
			var ry: float = p.x * sa + p.y * ca
			c_min_x = minf(c_min_x, rx)
			c_max_x = maxf(c_max_x, rx)
			c_min_y = minf(c_min_y, ry)
			c_max_y = maxf(c_max_y, ry)
		var bbox_area: float = maxf(c_max_x - c_min_x, 0.05) * maxf(c_max_y - c_min_y, 0.05)
		if bbox_area < best_area - 1.0e-4:
			best_area = bbox_area
			best_angle = ang

	# Check oriented span and rotate 90 deg if portrait so width >= height naturally fits landscape house bounds.
	var ca_best: float = cos(-best_angle)
	var sa_best: float = sin(-best_angle)
	var b_min_x: float = 1.0e20
	var b_max_x: float = -1.0e20
	var b_min_y: float = 1.0e20
	var b_max_y: float = -1.0e20
	for p in raw_pts:
		var rx: float = p.x * ca_best - p.y * sa_best
		var ry: float = p.x * sa_best + p.y * ca_best
		b_min_x = minf(b_min_x, rx)
		b_max_x = maxf(b_max_x, rx)
		b_min_y = minf(b_min_y, ry)
		b_max_y = maxf(b_max_y, ry)

	if (b_max_y - b_min_y) > (b_max_x - b_min_x) * 1.001:
		best_angle += (PI * 0.5) if best_angle <= 0.0 else (-PI * 0.5)
		ca_best = cos(-best_angle)
		sa_best = sin(-best_angle)

	var rot_pts: Array[Vector2] = []
	var r_min_x: float = 1.0e20
	var r_max_x: float = -1.0e20
	var r_min_y: float = 1.0e20
	var r_max_y: float = -1.0e20
	for p in raw_pts:
		var rp := Vector2(p.x * ca_best - p.y * sa_best, p.x * sa_best + p.y * ca_best)
		rot_pts.append(rp)
		r_min_x = minf(r_min_x, rp.x)
		r_max_x = maxf(r_max_x, rp.x)
		r_min_y = minf(r_min_y, rp.y)
		r_max_y = maxf(r_max_y, rp.y)

	var mid := Vector2((r_min_x + r_max_x) * 0.5, (r_min_y + r_max_y) * 0.5)
	var centered_pts: Array[Vector2] = []
	for rp in rot_pts:
		centered_pts.append(rp - mid)

	return {
		"points": centered_pts,
		"angle_rad": best_angle
	}


static func _normalize_footprint(house_data: Dictionary) -> Dictionary:
	var extracted_pts: Array[Vector2] = _extract_footprint_meters(house_data)
	var obb_info: Dictionary = _orient_footprint_to_obb(extracted_pts)
	var raw_pts: Array[Vector2] = obb_info["points"]
	var obb_angle_rad: float = float(obb_info.get("angle_rad", 0.0))

	var min_x: float = raw_pts[0].x
	var max_x: float = raw_pts[0].x
	var min_y: float = raw_pts[0].y
	var max_y: float = raw_pts[0].y
	for p in raw_pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	var raw_w: float = maxf(max_x - min_x, 0.5)
	var raw_h: float = maxf(max_y - min_y, 0.5)
	var poly_area: float = absf(_polygon_signed_area(raw_pts))
	var fill_ratio: float = clampf(poly_area / maxf(raw_w * raw_h, 0.01), 0.15, 1.0)

	# If the OBB-aligned OSM polygon is heavily notched (low bbox fill ratio), raise minimum target
	# within [14..22m] x [11..17m] so the playable rooms sit comfortably inside the silhouette.
	var desired_min_w: float = MIN_HOUSE_WIDTH_M
	var desired_min_h: float = MIN_HOUSE_HEIGHT_M
	if fill_ratio < 0.65:
		desired_min_w = lerpf(19.5, 16.0, (fill_ratio - 0.30) / 0.35)
		desired_min_w = clampf(desired_min_w, MIN_HOUSE_WIDTH_M, 20.5)
		desired_min_h = lerpf(15.6, 13.0, (fill_ratio - 0.30) / 0.35)
		desired_min_h = clampf(desired_min_h, MIN_HOUSE_HEIGHT_M, 16.0)

	var min_s_strict: float = maxf(MIN_HOUSE_WIDTH_M / raw_w, MIN_HOUSE_HEIGHT_M / raw_h)
	var max_s_strict: float = minf(MAX_HOUSE_WIDTH_M / raw_w, MAX_HOUSE_HEIGHT_M / raw_h)
	var min_s_pref: float = maxf(desired_min_w / raw_w, desired_min_h / raw_h)

	var sx: float = 1.0
	var sy: float = 1.0
	if min_s_strict <= max_s_strict:
		# Exact uniform scaling exists: preserves 100% of OSM aspect ratio and silhouette!
		var target_s: float = clampf(maxf(1.0, min_s_pref), min_s_strict, max_s_strict)
		sx = target_s
		sy = target_s
	else:
		# Extreme aspect ratio building (e.g. 5m x 28m rowhouse): stay as uniform as possible
		# while clamping strictly into [14..22m] x [11..17m].
		var mid_s: float = sqrt(min_s_strict * max_s_strict)
		sx = clampf(mid_s, MIN_HOUSE_WIDTH_M / raw_w, MAX_HOUSE_WIDTH_M / raw_w)
		sy = clampf(mid_s, MIN_HOUSE_HEIGHT_M / raw_h, MAX_HOUSE_HEIGHT_M / raw_h)

	var center_m := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var outer_poly := PackedVector2Array()
	var px_min_x: float = 1.0e9
	var px_max_x: float = -1.0e9
	var px_min_y: float = 1.0e9
	var px_max_y: float = -1.0e9

	for p in raw_pts:
		var scaled_px := Vector2(
			(p.x - center_m.x) * sx * PX_PER_METER,
			(p.y - center_m.y) * sy * PX_PER_METER
		)
		outer_poly.append(scaled_px)
		px_min_x = minf(px_min_x, scaled_px.x)
		px_max_x = maxf(px_max_x, scaled_px.x)
		px_min_y = minf(px_min_y, scaled_px.y)
		px_max_y = maxf(px_max_y, scaled_px.y)

	var outer_bounds := Rect2(
		Vector2(px_min_x, px_min_y),
		Vector2(px_max_x - px_min_x, px_max_y - px_min_y)
	)
	return {
		"raw_osm_polygon": outer_poly,
		"outer_polygon": outer_poly,
		"outer_bounds": outer_bounds,
		"fill_ratio": fill_ratio,
		"obb_angle_deg": rad_to_deg(obb_angle_rad)
	}


static func _polygon_signed_area(pts: Array[Vector2]) -> float:
	var n: int = pts.size()
	if n < 3:
		return 0.0
	var acc: float = 0.0
	for i in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		acc += a.x * b.y - b.x * a.y
	return acc * 0.5


# ---------------------------------------------------------------------------
# Step 2: 6-Room Architectural Floorplan Subdivision (L-Wing & Hallway-Centric)
# ---------------------------------------------------------------------------

static func _build_six_rooms(
	outer_polygon: PackedVector2Array,
	outer_bounds: Rect2,
	fill_ratio: float,
	rng: RandomNumberGenerator
) -> Array:
	# Measure polygon coverage in each of the 4 corner quadrants of outer_bounds.
	var q_cov: Array[float] = _measure_quadrant_coverage(outer_polygon, outer_bounds)
	var min_q_idx: int = 0
	var min_q_val: float = q_cov[0]
	var second_min_val: float = 1.0
	for i in range(1, 4):
		if q_cov[i] < min_q_val:
			second_min_val = min_q_val
			min_q_val = q_cov[i]
			min_q_idx = i
		elif q_cov[i] < second_min_val:
			second_min_val = q_cov[i]

	# Detect classic L-shaped house (one corner quadrant notched out while the other 3 are solid).
	var is_l_shape: bool = (min_q_val < 0.52 and second_min_val >= 0.58)

	if is_l_shape:
		return _build_l_wing_six_rooms(outer_polygon, outer_bounds, min_q_idx, rng)
	return _build_rect_six_rooms(outer_bounds, fill_ratio, rng)


static func _measure_quadrant_coverage(poly: PackedVector2Array, bounds: Rect2) -> Array[float]:
	# Quadrant indices: 0 = TL, 1 = TR, 2 = BL, 3 = BR
	var cov: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var half_w: float = bounds.size.x * 0.5
	var half_h: float = bounds.size.y * 0.5
	var origins: Array[Vector2] = [
		bounds.position,
		bounds.position + Vector2(half_w, 0.0),
		bounds.position + Vector2(0.0, half_h),
		bounds.position + Vector2(half_w, half_h)
	]
	var samples_per_axis: int = 5
	for q in range(4):
		var inside_count: int = 0
		var total_count: int = samples_per_axis * samples_per_axis
		for ix in range(samples_per_axis):
			for iy in range(samples_per_axis):
				var fx: float = (float(ix) + 0.5) / float(samples_per_axis)
				var fy: float = (float(iy) + 0.5) / float(samples_per_axis)
				# Focus on the outer 75% of each corner quadrant so courtyard notches register clearly.
				var pt := origins[q] + Vector2(fx * half_w, fy * half_h)
				if Geometry2D.is_point_in_polygon(pt, poly):
					inside_count += 1
		cov[q] = float(inside_count) / float(total_count)
	return cov


static func _snap12(v: float) -> float:
	return roundf(v / 12.0) * 12.0


static func _build_l_wing_six_rooms(
	outer_polygon: PackedVector2Array,
	outer_bounds: Rect2,
	notch_quadrant: int,
	rng: RandomNumberGenerator
) -> Array:
	# Canonicalize into Bottom-Right (quadrant 3) notch space using mirror flags,
	# then mirror final room Rect2s back to match TL (0), TR (1), BL (2), or BR (3)!
	var flip_x: bool = (notch_quadrant == 0 or notch_quadrant == 2)
	var flip_y: bool = (notch_quadrant == 0 or notch_quadrant == 1)

	var inset: float = 8.0
	var half_w: float = maxf(outer_bounds.size.x * 0.5 - inset, 312.0)
	var half_h: float = maxf(outer_bounds.size.y * 0.5 - inset, 244.0)

	var x0: float = _snap12(-half_w + 4.0)
	var x3: float = _snap12(half_w - 4.0)
	var y0: float = _snap12(-half_h + 4.0)
	var y3: float = _snap12(half_h - 4.0)

	# Probe how far the BR notch cuts inward in canonical space so the L-wings hug the OSM polygon.
	var best_notch_x: float = _snap12(x0 + (x3 - x0) * 0.68)
	var best_notch_y: float = _snap12(y0 + (y3 - y0) * 0.58)
	for step_i in range(12):
		var tx: float = lerpf(x3 - 36.0, x0 + (x3 - x0) * 0.56, float(step_i) / 11.0)
		var test_pt := Vector2(-tx if flip_x else tx, -(y3 - 24.0) if flip_y else (y3 - 24.0))
		if Geometry2D.is_point_in_polygon(test_pt, outer_polygon):
			best_notch_x = _snap12(tx - 6.0)
			break
	for step_j in range(12):
		var ty: float = lerpf(y3 - 36.0, y0 + (y3 - y0) * 0.52, float(step_j) / 11.0)
		var test_pt_y := Vector2(-(x3 - 24.0) if flip_x else (x3 - 24.0), -ty if flip_y else ty)
		if Geometry2D.is_point_in_polygon(test_pt_y, outer_polygon):
			best_notch_y = _snap12(ty - 6.0)
			break

	# Enforce spacious minimum room widths & heights across all 6 L-wing rooms (safe on 14m x 11m footprints too!).
	var x2_min: float = x0 + 348.0
	var x2_max: float = maxf(x2_min, x3 - 144.0)
	var x2: float = _snap12(clampf(best_notch_x, x2_min, x2_max))

	var x1_min: float = x0 + 156.0
	var x1_max: float = maxf(x1_min, x2 - 180.0)
	var x1: float = _snap12(clampf(x0 + (x2 - x0) * rng.randf_range(0.37, 0.42), x1_min, x1_max))

	var xb_min: float = x0 + 168.0
	var xb_max: float = maxf(xb_min, x2 - 156.0)
	var x_bot_mid: float = _snap12(clampf(x1 + 108.0, xb_min, xb_max))

	var y2_min: float = y0 + 300.0
	var y2_max: float = maxf(y2_min, y3 - 144.0)
	var y2: float = _snap12(clampf(best_notch_y, y2_min, y2_max))

	var y1_min: float = y0 + 144.0
	var y1_max: float = maxf(y1_min, y2 - 156.0)
	var y1: float = _snap12(clampf(y0 + (y2 - y0) * rng.randf_range(0.47, 0.51), y1_min, y1_max))

	# 6 exact L-wing rooms tiling ([x0, x3] x [y0, y3]) \ ([x2, x3] x [y2, y3]) with zero gaps:
	var raw_defs: Array[Dictionary] = [
		{"name": ROOM_CENTRAL_HALL, "rect": Rect2(x1, y1, x2 - x1, y2 - y1)},
		{"name": ROOM_MASTER_BED, "rect": Rect2(x0, y0, x1 - x0, y2 - y0)},
		{"name": ROOM_KIDS_BED, "rect": Rect2(x1, y0, x2 - x1, y1 - y0)},
		{"name": ROOM_LIVING, "rect": Rect2(x2, y0, x3 - x2, y2 - y0)},
		{"name": ROOM_KITCHEN, "rect": Rect2(x0, y2, x_bot_mid - x0, y3 - y2)},
		{"name": ROOM_BATH_UTILITY, "rect": Rect2(x_bot_mid, y2, x2 - x_bot_mid, y3 - y2)}
	]

	var rooms: Array = []
	for d in raw_defs:
		var r: Rect2 = d["rect"]
		var final_rect: Rect2 = _mirror_rect(r, flip_x, flip_y)
		rooms.append(_make_room_dict(str(d["name"]), final_rect))
	return rooms


static func _build_rect_six_rooms(
	outer_bounds: Rect2,
	fill_ratio: float,
	rng: RandomNumberGenerator
) -> Array:
	# Fit rectangular playable floorplan cleanly inside outer_bounds (tighter inset if angled polygon).
	var inset_factor_x: float = 0.96 if fill_ratio >= 0.72 else lerpf(0.76, 0.92, clampf((fill_ratio - 0.35) / 0.37, 0.0, 1.0))
	var inset_factor_y: float = 0.95 if fill_ratio >= 0.72 else lerpf(0.76, 0.91, clampf((fill_ratio - 0.35) / 0.37, 0.0, 1.0))

	var play_w: float = clampf(outer_bounds.size.x * inset_factor_x, 624.0, outer_bounds.size.x - 16.0)
	var play_h: float = clampf(outer_bounds.size.y * inset_factor_y, 492.0, outer_bounds.size.y - 16.0)

	var x0: float = _snap12(-play_w * 0.5)
	var x3: float = _snap12(play_w * 0.5)
	var y0: float = _snap12(-play_h * 0.5)
	var y3: float = _snap12(play_h * 0.5)

	var total_w: float = x3 - x0
	var total_h: float = y3 - y0

	var x1: float = _snap12(x0 + total_w * rng.randf_range(0.29, 0.33))
	var x2: float = _snap12(x3 - total_w * rng.randf_range(0.29, 0.33))
	if x2 - x1 < 228.0:
		x1 = _snap12(-120.0)
		x2 = _snap12(120.0)

	var y1: float = _snap12(y0 + total_h * rng.randf_range(0.31, 0.34))
	var y2: float = _snap12(y3 - total_h * rng.randf_range(0.31, 0.34))
	if y2 - y1 < 168.0:
		y1 = _snap12(-84.0)
		y2 = _snap12(84.0)

	# Split top-right band [x1, x3] into Kids Bedroom [x1, x_top_mid] and Bathroom & Utility [x_top_mid, x3]
	# ensuring BOTH overlap Central Hall [x1, x2] by >= 108 px for direct hall doorways!
	var x_top_mid: float = _snap12(clampf(x1 + 120.0, x1 + 108.0, x2 - 108.0))
	if x3 - x_top_mid < 168.0:
		x_top_mid = _snap12(x3 - 168.0)

	var flip_x: bool = rng.randf() < 0.5
	var flip_y: bool = rng.randf() < 0.5

	# Pinwheel 6-room zero-gap tiling of [x0, x3] x [y0, y3]:
	var raw_defs: Array[Dictionary] = [
		{"name": ROOM_CENTRAL_HALL, "rect": Rect2(x1, y1, x2 - x1, y2 - y1)},
		{"name": ROOM_MASTER_BED, "rect": Rect2(x0, y0, x1 - x0, y2 - y0)},
		{"name": ROOM_KIDS_BED, "rect": Rect2(x1, y0, x_top_mid - x1, y1 - y0)},
		{"name": ROOM_BATH_UTILITY, "rect": Rect2(x_top_mid, y0, x3 - x_top_mid, y1 - y0)},
		{"name": ROOM_LIVING, "rect": Rect2(x2, y1, x3 - x2, y3 - y1)},
		{"name": ROOM_KITCHEN, "rect": Rect2(x0, y2, x2 - x0, y3 - y2)}
	]

	var rooms: Array = []
	for d in raw_defs:
		var r: Rect2 = d["rect"]
		var final_rect: Rect2 = _mirror_rect(r, flip_x, flip_y)
		rooms.append(_make_room_dict(str(d["name"]), final_rect))
	return rooms


static func _mirror_rect(r: Rect2, flip_x: bool, flip_y: bool) -> Rect2:
	var rx: float = -r.end.x if flip_x else r.position.x
	var ry: float = -r.end.y if flip_y else r.position.y
	return Rect2(Vector2(rx, ry), r.size)


static func _make_room_dict(room_name: String, rect: Rect2) -> Dictionary:
	var floor_style: String = "linoleum_hall"
	var floor_color := Color("#dfd3b8")
	var accent_color := Color("#c8b896")
	var theme_key: String = "hall"

	match room_name:
		ROOM_CENTRAL_HALL:
			floor_style = "linoleum_hall"
			floor_color = Color("#e5d7b9")
			accent_color = Color("#f2b82e")
			theme_key = "hall"
		ROOM_KITCHEN:
			floor_style = "checker_tile"
			floor_color = Color("#efe5cc")
			accent_color = Color("#c8b594")
			theme_key = "kitchen"
		ROOM_LIVING:
			floor_style = "wood_plank"
			floor_color = Color("#be8c56")
			accent_color = Color("#a84a32")
			theme_key = "living"
		ROOM_MASTER_BED:
			floor_style = "warm_carpet"
			floor_color = Color("#c89f78")
			accent_color = Color("#4d6e82")
			theme_key = "master_bedroom"
		ROOM_KIDS_BED:
			floor_style = "pastel_wood"
			floor_color = Color("#d4b483")
			accent_color = Color("#6a9c89")
			theme_key = "kids_bedroom"
		ROOM_BATH_UTILITY:
			floor_style = "cool_tile"
			floor_color = Color("#bdd0cc")
			accent_color = Color("#6f8d88")
			theme_key = "bathroom"

	var rug_rect := Rect2()
	if room_name in [ROOM_LIVING, ROOM_MASTER_BED, ROOM_KIDS_BED]:
		rug_rect = rect.grow(-minf(rect.size.x, rect.size.y) * 0.24)

	return {
		"id": room_name.to_lower().replace(" & ", "_").replace(" ", "_"),
		"name": room_name,
		"theme": theme_key,
		"rect": rect,
		"center": rect.get_center(),
		"floor_style": floor_style,
		"color": floor_color,
		"floor_color": floor_color,
		"accent_color": accent_color,
		"rug_rect": rug_rect
	}


static func _compute_rooms_bounds(rooms: Array) -> Rect2:
	if rooms.is_empty():
		return Rect2(-320.0, -260.0, 640.0, 520.0)
	var merged: Rect2 = rooms[0]["rect"]
	for i in range(1, rooms.size()):
		var r: Rect2 = rooms[i]["rect"]
		merged = merged.merge(r)
	return merged


static func _add_unique_sorted_coord(arr: Array[float], val: float, eps: float = 0.5) -> void:
	for v in arr:
		if absf(v - val) <= eps:
			return
	arr.append(val)
	arr.sort()


## Computes the exact outer orthogonal boundary polygon of the generated rooms union
## (4 corners for a rectangular 6-room union; 6 corners for a notched L-wing room union).
static func _compute_rooms_union_polygon(rooms: Array) -> PackedVector2Array:
	var fallback_b: Rect2 = _compute_rooms_bounds(rooms)
	var fallback_poly := PackedVector2Array([
		fallback_b.position,
		Vector2(fallback_b.end.x, fallback_b.position.y),
		fallback_b.end,
		Vector2(fallback_b.position.x, fallback_b.end.y)
	])
	if rooms.is_empty():
		return fallback_poly

	var xs: Array[float] = []
	var ys: Array[float] = []
	for r_var in rooms:
		var rd: Dictionary = r_var
		var rr: Rect2 = rd["rect"]
		_add_unique_sorted_coord(xs, rr.position.x)
		_add_unique_sorted_coord(xs, rr.end.x)
		_add_unique_sorted_coord(ys, rr.position.y)
		_add_unique_sorted_coord(ys, rr.end.y)

	var nx: int = xs.size() - 1
	var ny: int = ys.size() - 1
	if nx < 1 or ny < 1:
		return fallback_poly

	var filled := PackedByteArray()
	filled.resize(nx * ny)
	filled.fill(0)

	for iy in range(ny):
		var cy: float = (ys[iy] + ys[iy + 1]) * 0.5
		for ix in range(nx):
			var cx: float = (xs[ix] + xs[ix + 1]) * 0.5
			var center_pt := Vector2(cx, cy)
			for r_var in rooms:
				var rd: Dictionary = r_var
				var rr: Rect2 = rd["rect"]
				if rr.grow(0.25).has_point(center_pt):
					filled[iy * nx + ix] = 1
					break

	var stride: int = nx + 1
	var outgoing: Dictionary = {}
	for iy in range(ny):
		for ix in range(nx):
			if filled[iy * nx + ix] == 0:
				continue
			# Top edge (+X, dir 0)
			if iy == 0 or filled[(iy - 1) * nx + ix] == 0:
				_append_boundary_edge(outgoing, iy * stride + ix, iy * stride + (ix + 1), 0)
			# Right edge (+Y, dir 1)
			if ix == nx - 1 or filled[iy * nx + (ix + 1)] == 0:
				_append_boundary_edge(outgoing, iy * stride + (ix + 1), (iy + 1) * stride + (ix + 1), 1)
			# Bottom edge (-X, dir 2)
			if iy == ny - 1 or filled[(iy + 1) * nx + ix] == 0:
				_append_boundary_edge(outgoing, (iy + 1) * stride + (ix + 1), (iy + 1) * stride + ix, 2)
			# Left edge (-Y, dir 3)
			if ix == 0 or filled[iy * nx + (ix - 1)] == 0:
				_append_boundary_edge(outgoing, (iy + 1) * stride + ix, iy * stride + ix, 3)

	if outgoing.is_empty():
		return fallback_poly

	# Pick top-leftmost boundary vertex to guarantee starting on the outer perimeter.
	var start_u: int = -1
	var best_vy: int = 1000000
	var best_vx: int = 1000000
	for k_var in outgoing.keys():
		var u: int = int(k_var)
		var vy: int = u / stride
		var vx: int = u % stride
		if vy < best_vy or (vy == best_vy and vx < best_vx):
			best_vy = vy
			best_vx = vx
			start_u = u

	if start_u < 0:
		return fallback_poly

	var loop_u: Array[int] = [start_u]
	var cur_u: int = start_u
	var cur_dir: int = 3
	var max_steps: int = (nx + 1) * (ny + 1) * 4
	var closed_ok: bool = false

	for _step in range(max_steps):
		var edge_list: Array = outgoing.get(cur_u, [])
		var chosen_edge: Dictionary = {}
		var turn_order: Array[int] = [1, 0, 3, 2]
		for turn in turn_order:
			var want_dir: int = (cur_dir + turn) % 4
			for e_var in edge_list:
				var ed: Dictionary = e_var
				if not bool(ed.get("used", false)) and int(ed.get("dir", -1)) == want_dir:
					chosen_edge = ed
					break
			if not chosen_edge.is_empty():
				break

		if chosen_edge.is_empty():
			break

		chosen_edge["used"] = true
		var nxt_u: int = int(chosen_edge["to"])
		cur_dir = int(chosen_edge["dir"])
		if nxt_u == start_u:
			closed_ok = true
			break
		loop_u.append(nxt_u)
		cur_u = nxt_u

	if not closed_ok or loop_u.size() < 4:
		return fallback_poly

	var raw_poly := PackedVector2Array()
	for u in loop_u:
		var vx: int = u % stride
		var vy: int = u / stride
		raw_poly.append(Vector2(xs[vx], ys[vy]))

	# Remove collinear intermediate grid vertices so only true orthogonal corners remain.
	var simplified := PackedVector2Array()
	var m: int = raw_poly.size()
	for i in range(m):
		var prv: Vector2 = raw_poly[(i - 1 + m) % m]
		var cur: Vector2 = raw_poly[i]
		var nxt: Vector2 = raw_poly[(i + 1) % m]
		var v1: Vector2 = cur - prv
		var v2: Vector2 = nxt - cur
		var cross_mag: float = absf(v1.x * v2.y - v1.y * v2.x)
		if cross_mag > 1.0e-2:
			simplified.append(cur)

	if simplified.size() < 4 or Geometry2D.triangulate_polygon(simplified).size() < 3:
		return fallback_poly
	return simplified


static func _append_boundary_edge(outgoing: Dictionary, u: int, v: int, dir_idx: int) -> void:
	if not outgoing.has(u):
		outgoing[u] = []
	var list_ref: Array = outgoing[u]
	list_ref.append({"to": v, "dir": dir_idx, "used": false})


static func _is_point_inside_or_near_polygon(pt: Vector2, poly: PackedVector2Array, boundary_tol: float = 2.0) -> bool:
	if poly.size() < 3:
		return true
	if Geometry2D.is_point_in_polygon(pt, poly):
		return true
	var n: int = poly.size()
	var tol_sq: float = boundary_tol * boundary_tol
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pt, a, b)
		if pt.distance_squared_to(closest) <= tol_sq:
			return true
	return false


static func _enforce_inside_outer_polygon(
	outer_polygon: PackedVector2Array,
	rooms: Array,
	furniture: Array,
	items: Array,
	family_spawns: Array,
	nav_grid: Dictionary
) -> void:
	if outer_polygon.size() < 3:
		return

	# 1. Verify all room centers lie inside outer_polygon.
	for r_var in rooms:
		var rd: Dictionary = r_var
		var rc: Vector2 = rd["center"]
		if not _is_point_inside_or_near_polygon(rc, outer_polygon, 2.0):
			rd["center"] = (rd["rect"] as Rect2).get_center()

	# 2. Verify all furniture props lie strictly inside outer_polygon.
	for f_idx in range(furniture.size() - 1, -1, -1):
		var fd: Dictionary = furniture[f_idx]
		var fr: Rect2 = fd["rect"]
		var corners: Array[Vector2] = [
			fr.position,
			Vector2(fr.end.x, fr.position.y),
			fr.end,
			Vector2(fr.position.x, fr.end.y),
			fr.get_center()
		]
		var all_in: bool = true
		for cp in corners:
			if not _is_point_inside_or_near_polygon(cp, outer_polygon, 2.0):
				all_in = false
				break
		if not all_in:
			furniture.remove_at(f_idx)

	# Collect strictly interior reachable points for snapping any borderline spawn.
	var interior_walkable: Array[Vector2] = []
	for wc in nav_grid.get("walkable_cells", []):
		var w_cell: Vector2i = wc
		var w_pt: Vector2 = cell_to_world(nav_grid, w_cell)
		if Geometry2D.is_point_in_polygon(w_pt, outer_polygon):
			interior_walkable.append(w_pt)

	# 3. Verify 100% of spawned items lie strictly inside outer_polygon.
	for it_var in items:
		var it: Dictionary = it_var
		var ipos: Vector2 = it["pos"]
		if not Geometry2D.is_point_in_polygon(ipos, outer_polygon):
			var snapped_i: Vector2 = _nearest_point_in_list(ipos, interior_walkable)
			it["pos"] = snapped_i
			it["position"] = snapped_i

	# 4. Verify 100% of family spawns lie strictly inside outer_polygon.
	for fs_var in family_spawns:
		var fs: Dictionary = fs_var
		var fpos: Vector2 = fs["pos"]
		if not Geometry2D.is_point_in_polygon(fpos, outer_polygon):
			var snapped_f: Vector2 = _nearest_point_in_list(fpos, interior_walkable)
			fs["pos"] = snapped_f
			fs["position"] = snapped_f


static func _nearest_point_in_list(target: Vector2, pts: Array[Vector2]) -> Vector2:
	if pts.is_empty():
		return target
	var best_p: Vector2 = pts[0]
	var best_d2: float = target.distance_squared_to(best_p)
	for i in range(1, pts.size()):
		var d2: float = target.distance_squared_to(pts[i])
		if d2 < best_d2:
			best_d2 = d2
			best_p = pts[i]
	return best_p


static func _find_room_by_name(rooms: Array, target_name: String) -> Dictionary:
	for room in rooms:
		var rd: Dictionary = room
		if str(rd.get("name", "")) == target_name:
			return rd
	return rooms[0]


# ---------------------------------------------------------------------------
# Step 3: Doorways (84 px wide) & Exterior / Interior Wall Segments
# ---------------------------------------------------------------------------

static func _shared_wall_segment(a: Rect2, b: Rect2) -> Dictionary:
	var eps: float = 2.0
	# Vertical shared wall (a.end.x == b.position.x or b.end.x == a.position.x)
	if absf(a.end.x - b.position.x) <= eps or absf(b.end.x - a.position.x) <= eps:
		var wx: float = a.end.x if absf(a.end.x - b.position.x) <= eps else b.end.x
		var y_start: float = maxf(a.position.y, b.position.y)
		var y_end: float = minf(a.end.y, b.end.y)
		if y_end - y_start > 12.0:
			return {
				"valid": true,
				"horizontal": false,
				"axis_pos": wx,
				"start": y_start,
				"end": y_end,
				"length": y_end - y_start
			}
	# Horizontal shared wall (a.end.y == b.position.y or b.end.y == a.position.y)
	if absf(a.end.y - b.position.y) <= eps or absf(b.end.y - a.position.y) <= eps:
		var wy: float = a.end.y if absf(a.end.y - b.position.y) <= eps else b.end.y
		var x_start: float = maxf(a.position.x, b.position.x)
		var x_end: float = minf(a.end.x, b.end.x)
		if x_end - x_start > 12.0:
			return {
				"valid": true,
				"horizontal": true,
				"axis_pos": wy,
				"start": x_start,
				"end": x_end,
				"length": x_end - x_start
			}
	return {"valid": false}


static func _plan_doorways(rooms: Array, door_width: float) -> Array:
	var doorways: Array = []
	var n: int = rooms.size()

	# Connect every room that touches Central Hall directly to Central Hall,
	# plus connect key adjacent outer rooms with long shared walls (>= 160 px) for smooth loops!
	for i in range(n):
		var ri: Dictionary = rooms[i]
		var name_i: String = str(ri["name"])
		var rect_i: Rect2 = ri["rect"]
		for j in range(i + 1, n):
			var rj: Dictionary = rooms[j]
			var name_j: String = str(rj["name"])
			var rect_j: Rect2 = rj["rect"]

			var seg: Dictionary = _shared_wall_segment(rect_i, rect_j)
			if not bool(seg.get("valid", false)):
				continue

			var seg_len: float = float(seg["length"])
			var touches_hall: bool = (name_i == ROOM_CENTRAL_HALL or name_j == ROOM_CENTRAL_HALL)
			var want_secondary: bool = (not touches_hall) and seg_len >= 164.0 and (
				(name_i == ROOM_KITCHEN or name_j == ROOM_KITCHEN) or
				(name_i == ROOM_LIVING or name_j == ROOM_LIVING)
			)

			if touches_hall and seg_len >= door_width + 12.0:
				doorways.append(_make_doorway_from_seg(seg, name_i, name_j, door_width))
			elif want_secondary and seg_len >= door_width + 40.0:
				doorways.append(_make_doorway_from_seg(seg, name_i, name_j, door_width))

	# Guarantee every room has at least one doorway even if it didn't touch Central Hall directly.
	for i in range(n):
		var rname: String = str(rooms[i]["name"])
		var has_door: bool = false
		for dw in doorways:
			var dwd: Dictionary = dw
			if str(dwd["from_room"]) == rname or str(dwd["to_room"]) == rname:
				has_door = true
				break
		if not has_door:
			var best_j: int = -1
			var best_seg: Dictionary = {}
			var best_len: float = 0.0
			for j in range(n):
				if i == j:
					continue
				var seg2: Dictionary = _shared_wall_segment(rooms[i]["rect"], rooms[j]["rect"])
				if bool(seg2.get("valid", false)) and float(seg2["length"]) > best_len:
					best_len = float(seg2["length"])
					best_seg = seg2
					best_j = j
			if best_j >= 0 and best_len >= door_width:
				doorways.append(_make_doorway_from_seg(best_seg, rname, str(rooms[best_j]["name"]), door_width))

	return doorways


static func _make_doorway_from_seg(
	seg: Dictionary,
	from_room: String,
	to_room: String,
	door_width: float
) -> Dictionary:
	var horiz: bool = bool(seg["horizontal"])
	var axis_pos: float = float(seg["axis_pos"])
	var s0: float = float(seg["start"])
	var s1: float = float(seg["end"])
	var mid: float = (s0 + s1) * 0.5
	# Snap doorway midpoint to 24 px grid so at least two 24 px nav cells pass cleanly through!
	var snapped_mid: float = roundf(mid / NAV_CELL_SIZE) * NAV_CELL_SIZE
	var half_dw: float = door_width * 0.5
	var margin: float = minf(12.0, maxf((s1 - s0 - door_width) * 0.5, 0.0))
	var d_center_1d: float = clampf(snapped_mid, s0 + half_dw + margin, s1 - half_dw - margin)

	var d_rect: Rect2
	var center_pt: Vector2
	if horiz:
		d_rect = Rect2(
			Vector2(d_center_1d - half_dw, axis_pos - INTERIOR_WALL_THICK * 0.5),
			Vector2(door_width, INTERIOR_WALL_THICK)
		)
		center_pt = Vector2(d_center_1d, axis_pos)
	else:
		d_rect = Rect2(
			Vector2(axis_pos - INTERIOR_WALL_THICK * 0.5, d_center_1d - half_dw),
			Vector2(INTERIOR_WALL_THICK, door_width)
		)
		center_pt = Vector2(axis_pos, d_center_1d)

	return {
		"rect": d_rect,
		"center": center_pt,
		"horizontal": horiz,
		"axis_pos": axis_pos,
		"span_start": d_center_1d - half_dw,
		"span_end": d_center_1d + half_dw,
		"width": door_width,
		"from_room": from_room,
		"to_room": to_room
	}


static func _build_walls_from_rooms(rooms: Array, doorways: Array, _door_width: float) -> Array:
	var walls: Array = []
	var n: int = rooms.size()

	# 1. Exterior walls: for each room's 4 edges, subtract intervals shared with any neighbor room.
	for i in range(n):
		var ri: Rect2 = rooms[i]["rect"]
		# Top (horiz at ri.position.y), Bottom (horiz at ri.end.y), Left (vert at ri.position.x), Right (vert at ri.end.x)
		var edges: Array[Dictionary] = [
			{"horizontal": true, "axis": ri.position.y, "s0": ri.position.x, "s1": ri.end.x, "outward": -1.0},
			{"horizontal": true, "axis": ri.end.y, "s0": ri.position.x, "s1": ri.end.x, "outward": 1.0},
			{"horizontal": false, "axis": ri.position.x, "s0": ri.position.y, "s1": ri.end.y, "outward": -1.0},
			{"horizontal": false, "axis": ri.end.x, "s0": ri.position.y, "s1": ri.end.y, "outward": 1.0}
		]
		for edge in edges:
			var horiz: bool = bool(edge["horizontal"])
			var axis_val: float = float(edge["axis"])
			var intervals: Array[Vector2] = [Vector2(float(edge["s0"]), float(edge["s1"]))]

			for j in range(n):
				if i == j:
					continue
				var seg: Dictionary = _shared_wall_segment(ri, rooms[j]["rect"])
				if bool(seg.get("valid", false)) and bool(seg["horizontal"]) == horiz:
					if absf(float(seg["axis_pos"]) - axis_val) <= 2.0:
						intervals = _subtract_interval(intervals, float(seg["start"]), float(seg["end"]))

			for iv in intervals:
				if iv.y - iv.x <= 2.0:
					continue
				var out_dir: float = float(edge["outward"])
				var w_rect: Rect2
				if horiz:
					var wy: float = (axis_val - EXTERIOR_WALL_THICK * 0.75) if out_dir < 0.0 else (axis_val - EXTERIOR_WALL_THICK * 0.25)
					w_rect = Rect2(
						Vector2(iv.x - EXTERIOR_WALL_THICK * 0.5, wy),
						Vector2((iv.y - iv.x) + EXTERIOR_WALL_THICK, EXTERIOR_WALL_THICK)
					)
				else:
					var wx: float = (axis_val - EXTERIOR_WALL_THICK * 0.75) if out_dir < 0.0 else (axis_val - EXTERIOR_WALL_THICK * 0.25)
					w_rect = Rect2(
						Vector2(wx, iv.x - EXTERIOR_WALL_THICK * 0.5),
						Vector2(EXTERIOR_WALL_THICK, (iv.y - iv.x) + EXTERIOR_WALL_THICK)
					)
				walls.append({
					"rect": w_rect,
					"is_exterior": true,
					"color": Color("#232824")
				})

	# 2. Interior walls: for each pair (i < j) with a shared boundary, subtract carved doorways.
	for i in range(n):
		for j in range(i + 1, n):
			var seg: Dictionary = _shared_wall_segment(rooms[i]["rect"], rooms[j]["rect"])
			if not bool(seg.get("valid", false)):
				continue
			var horiz: bool = bool(seg["horizontal"])
			var axis_val: float = float(seg["axis_pos"])
			var intervals: Array[Vector2] = [Vector2(float(seg["start"]), float(seg["end"]))]

			for dw in doorways:
				var dwd: Dictionary = dw
				if bool(dwd["horizontal"]) == horiz and absf(float(dwd["axis_pos"]) - axis_val) <= 2.5:
					intervals = _subtract_interval(intervals, float(dwd["span_start"]), float(dwd["span_end"]))

			for iv in intervals:
				if iv.y - iv.x <= 3.0:
					continue
				var w_rect: Rect2
				if horiz:
					w_rect = Rect2(
						Vector2(iv.x, axis_val - INTERIOR_WALL_THICK * 0.5),
						Vector2(iv.y - iv.x, INTERIOR_WALL_THICK)
					)
				else:
					w_rect = Rect2(
						Vector2(axis_val - INTERIOR_WALL_THICK * 0.5, iv.x),
						Vector2(INTERIOR_WALL_THICK, iv.y - iv.x)
					)
				walls.append({
					"rect": w_rect,
					"is_exterior": false,
					"color": Color("#463f36")
				})

	return walls


static func _subtract_interval(intervals: Array[Vector2], cut_a: float, cut_b: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for iv in intervals:
		if cut_b <= iv.x or cut_a >= iv.y:
			out.append(iv)
		else:
			if cut_a > iv.x:
				out.append(Vector2(iv.x, cut_a))
			if cut_b < iv.y:
				out.append(Vector2(cut_b, iv.y))
	return out


# ---------------------------------------------------------------------------
# Step 4: Thematic Mid-Century Furniture Placement Along Room Edges/Corners
# ---------------------------------------------------------------------------

static func _place_all_furniture(
	rooms: Array,
	doorways: Array,
	hatch_pos: Vector2,
	rng: RandomNumberGenerator
) -> Array:
	var furniture: Array = []

	for room in rooms:
		var rd: Dictionary = room
		var rname: String = str(rd["name"])
		if rname == ROOM_CENTRAL_HALL:
			# Keep Central Hall completely clear around the Fallout Bunker Hatch and hub doorways!
			continue

		var rrect: Rect2 = rd["rect"]
		var specs: Array[Dictionary] = _get_room_furniture_specs(rname)
		for spec in specs:
			var placed_rect: Rect2 = _try_place_furniture_along_wall(
				rrect,
				Vector2(float(spec["w"]), float(spec["h"])),
				doorways,
				hatch_pos,
				furniture,
				rng
			)
			if placed_rect.size.x > 1.0:
				furniture.append({
					"rect": placed_rect,
					"kind": str(spec["kind"]),
					"color": spec["color"],
					"accent_color": spec["accent_color"],
					"room": rname,
					"solid": true
				})

	return furniture


static func _get_room_furniture_specs(room_name: String) -> Array[Dictionary]:
	match room_name:
		ROOM_KITCHEN:
			return [
				{"kind": "counter", "w": 86.0, "h": 30.0, "color": Color("#d8cbb0"), "accent_color": Color("#c84b31")},
				{"kind": "fridge", "w": 38.0, "h": 36.0, "color": Color("#eef2ef"), "accent_color": Color("#8ca3a0")},
				{"kind": "dining_table", "w": 56.0, "h": 42.0, "color": Color("#9c6b3e"), "accent_color": Color("#f2b82e")}
			]
		ROOM_LIVING:
			return [
				{"kind": "sofa", "w": 84.0, "h": 34.0, "color": Color("#b84b31"), "accent_color": Color("#e07b54")},
				{"kind": "tv_cabinet", "w": 52.0, "h": 28.0, "color": Color("#5c3d28"), "accent_color": Color("#7ec850")},
				{"kind": "coffee_table", "w": 46.0, "h": 28.0, "color": Color("#7d5233"), "accent_color": Color("#efe3c8")}
			]
		ROOM_MASTER_BED:
			return [
				{"kind": "double_bed", "w": 72.0, "h": 58.0, "color": Color("#466982"), "accent_color": Color("#efe3c8")},
				{"kind": "dresser", "w": 58.0, "h": 28.0, "color": Color("#6e472b"), "accent_color": Color("#d99b26")},
				{"kind": "closet", "w": 48.0, "h": 28.0, "color": Color("#593a24"), "accent_color": Color("#b89c78")}
			]
		ROOM_KIDS_BED:
			return [
				{"kind": "twin_bed", "w": 64.0, "h": 38.0, "color": Color("#d98a3c"), "accent_color": Color("#efe3c8")},
				{"kind": "bookshelf", "w": 54.0, "h": 26.0, "color": Color("#7a5230"), "accent_color": Color("#3b8ec2")}
			]
		ROOM_BATH_UTILITY:
			return [
				{"kind": "bathtub", "w": 72.0, "h": 34.0, "color": Color("#e8f0ee"), "accent_color": Color("#3b8ec2")},
				{"kind": "workbench", "w": 62.0, "h": 30.0, "color": Color("#6b5842"), "accent_color": Color("#f2b82e")},
				{"kind": "sink_vanity", "w": 42.0, "h": 26.0, "color": Color("#dce8e5"), "accent_color": Color("#7a9490")}
			]
	return []


static func _try_place_furniture_along_wall(
	room_rect: Rect2,
	base_size: Vector2,
	doorways: Array,
	hatch_pos: Vector2,
	existing_furniture: Array,
	rng: RandomNumberGenerator
) -> Rect2:
	var wall_pad: float = 12.0
	var inner: Rect2 = room_rect.grow(-wall_pad)
	if inner.size.x < 48.0 or inner.size.y < 48.0:
		return Rect2()

	# Try full size first, then compact corner scale if the room is cozy.
	var scales: Array[float] = [1.0, 0.76]
	for sc in scales:
		var w: float = roundf(base_size.x * sc)
		var h: float = roundf(base_size.y * sc)
		var candidates: Array[Rect2] = []

		if w <= inner.size.x - 16.0 and h <= inner.size.y - 16.0:
			# 4 corners flush to walls (horizontal orientation)
			candidates.append(Rect2(Vector2(inner.position.x, inner.position.y), Vector2(w, h)))
			candidates.append(Rect2(Vector2(inner.end.x - w, inner.position.y), Vector2(w, h)))
			candidates.append(Rect2(Vector2(inner.position.x, inner.end.y - h), Vector2(w, h)))
			candidates.append(Rect2(Vector2(inner.end.x - w, inner.end.y - h), Vector2(w, h)))
			# Mid-wall edge anchors
			candidates.append(Rect2(Vector2(inner.get_center().x - w * 0.5, inner.position.y), Vector2(w, h)))
			candidates.append(Rect2(Vector2(inner.get_center().x - w * 0.5, inner.end.y - h), Vector2(w, h)))

		# Rotated 90 deg along left/right walls
		if h <= inner.size.x - 16.0 and w <= inner.size.y - 16.0:
			candidates.append(Rect2(Vector2(inner.position.x, inner.position.y), Vector2(h, w)))
			candidates.append(Rect2(Vector2(inner.end.x - h, inner.position.y), Vector2(h, w)))
			candidates.append(Rect2(Vector2(inner.position.x, inner.end.y - w), Vector2(h, w)))
			candidates.append(Rect2(Vector2(inner.end.x - h, inner.end.y - w), Vector2(h, w)))
			candidates.append(Rect2(Vector2(inner.position.x, inner.get_center().y - w * 0.5), Vector2(h, w)))
			candidates.append(Rect2(Vector2(inner.end.x - h, inner.get_center().y - w * 0.5), Vector2(h, w)))

		# Deterministic shuffle using rng so furniture varies naturally across houses.
		for idx in range(candidates.size() - 1, 0, -1):
			var swap_idx: int = rng.randi_range(0, idx)
			var tmp: Rect2 = candidates[idx]
			candidates[idx] = candidates[swap_idx]
			candidates[swap_idx] = tmp

		for cand in candidates:
			if _is_furniture_rect_valid(cand, room_rect, doorways, hatch_pos, existing_furniture):
				return cand

	return Rect2()


static func _is_furniture_rect_valid(
	cand: Rect2,
	room_rect: Rect2,
	doorways: Array,
	hatch_pos: Vector2,
	existing_furniture: Array
) -> bool:
	# Keep room center open so room-center BFS check always has generous breathing room.
	if cand.grow(28.0).has_point(room_rect.get_center()):
		return false

	# Strict rule: NEVER within 110 px of hatch_pos (checked from closest point on furniture rect!).
	if _dist_point_to_rect(hatch_pos, cand) < MIN_FURNITURE_HATCH_DIST + 2.0:
		return false

	# Strict rule: NEVER within 95 px of any doorway!
	for dw in doorways:
		var dwd: Dictionary = dw
		var dw_center: Vector2 = dwd["center"]
		var dw_rect: Rect2 = dwd["rect"]
		if _dist_point_to_rect(dw_center, cand) < MIN_FURNITURE_DOOR_DIST + 2.0:
			return false
		if _dist_rect_to_rect(dw_rect, cand) < MIN_FURNITURE_DOOR_DIST * 0.68:
			return false

	# Keep clear spacing from already placed furniture so player never wedges between two props.
	for existing in existing_furniture:
		var ex_d: Dictionary = existing
		var ex_rect: Rect2 = ex_d["rect"]
		if cand.grow(20.0).intersects(ex_rect):
			return false

	return true


static func _dist_point_to_rect(pt: Vector2, rect: Rect2) -> float:
	var cx: float = clampf(pt.x, rect.position.x, rect.end.x)
	var cy: float = clampf(pt.y, rect.position.y, rect.end.y)
	return pt.distance_to(Vector2(cx, cy))


static func _dist_rect_to_rect(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy: float = maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dy * dy)


# ---------------------------------------------------------------------------
# Step 5: Discrete Nav Grid (24 px), BFS Flood-Fill & Self-Healing Guarantee
# ---------------------------------------------------------------------------

static func _build_and_verify_nav_grid(
	rooms: Array,
	doorways: Array,
	initial_walls: Array,
	furniture: Array,
	total_bounds: Rect2,
	nav_origin: Vector2,
	hatch_pos: Vector2
) -> Dictionary:
	var current_walls: Array = initial_walls
	var nav_grid: Dictionary = {}

	for attempt in range(8):
		nav_grid = _rasterize_and_bfs(rooms, current_walls, furniture, total_bounds, nav_origin, hatch_pos)
		var unreachable_rooms: Array[int] = _find_unreachable_rooms(rooms, nav_grid)
		if unreachable_rooms.is_empty():
			break

		# Self-healing pass: remove blocking furniture in/near unreachable rooms and widen/add doorways!
		for r_idx in unreachable_rooms:
			var u_room: Dictionary = rooms[r_idx]
			var u_name: String = str(u_room["name"])
			var u_rect: Rect2 = u_room["rect"]

			# Remove furniture inside the unreachable room that might block its center or doorway.
			for f_i in range(furniture.size() - 1, -1, -1):
				var fd: Dictionary = furniture[f_i]
				if str(fd.get("room", "")) == u_name:
					furniture.remove_at(f_i)

			# Widen existing doorway for this room or carve a new wide doorway (104 px) to a reachable room.
			var widened_existing: bool = false
			for dw in doorways:
				var dwd: Dictionary = dw
				if str(dwd["from_room"]) == u_name or str(dwd["to_room"]) == u_name:
					var new_w: float = float(dwd["width"]) + 24.0
					var seg_check: Dictionary = _find_shared_seg_by_names(rooms, str(dwd["from_room"]), str(dwd["to_room"]))
					if bool(seg_check.get("valid", false)):
						new_w = minf(new_w, float(seg_check["length"]) - 8.0)
						var rebuilt: Dictionary = _make_doorway_from_seg(
							seg_check,
							str(dwd["from_room"]),
							str(dwd["to_room"]),
							maxf(new_w, DOOR_WIDTH)
						)
						for k in rebuilt.keys():
							dwd[k] = rebuilt[k]
						widened_existing = true

			if not widened_existing:
				for j in range(rooms.size()):
					if j == r_idx:
						continue
					var seg_new: Dictionary = _shared_wall_segment(u_rect, rooms[j]["rect"])
					if bool(seg_new.get("valid", false)) and float(seg_new["length"]) >= DOOR_WIDTH:
						var carve_w: float = minf(104.0, float(seg_new["length"]) - 8.0)
						doorways.append(_make_doorway_from_seg(seg_new, u_name, str(rooms[j]["name"]), carve_w))
						break

		current_walls = _build_walls_from_rooms(rooms, doorways, DOOR_WIDTH)
		if attempt >= 4:
			# Final fallback safety: clear remaining furniture if any tiny corner room still blocked.
			furniture.clear()

	nav_grid["_resolved_walls"] = current_walls
	return nav_grid


static func _find_shared_seg_by_names(rooms: Array, name_a: String, name_b: String) -> Dictionary:
	var ra: Dictionary = _find_room_by_name(rooms, name_a)
	var rb: Dictionary = _find_room_by_name(rooms, name_b)
	return _shared_wall_segment(ra["rect"], rb["rect"])


static func _rasterize_and_bfs(
	rooms: Array,
	walls: Array,
	furniture: Array,
	total_bounds: Rect2,
	nav_origin: Vector2,
	hatch_pos: Vector2
) -> Dictionary:
	var span_x: float = (total_bounds.end.x + NAV_CELL_SIZE) - nav_origin.x
	var span_y: float = (total_bounds.end.y + NAV_CELL_SIZE) - nav_origin.y
	var cols: int = maxi(8, int(ceilf(span_x / NAV_CELL_SIZE)))
	var rows: int = maxi(8, int(ceilf(span_y / NAV_CELL_SIZE)))
	var total_cells: int = cols * rows

	var raw_walkable := PackedByteArray()
	raw_walkable.resize(total_cells)
	raw_walkable.fill(0)

	# Pre-inflate walls and furniture by player collision radius (18.0 px),
	# plus slightly wider margin (20.5 px) for continuous straight-line path smoothing.
	var blocked_rects: Array[Rect2] = []
	var smooth_blocked_rects: Array[Rect2] = []
	for w in walls:
		var wd: Dictionary = w
		var wr: Rect2 = wd["rect"]
		blocked_rects.append(wr.grow(PLAYER_COLLISION_RADIUS))
		smooth_blocked_rects.append(wr.grow(PLAYER_COLLISION_RADIUS + 2.5))
	for f in furniture:
		var fd: Dictionary = f
		var fr: Rect2 = fd["rect"]
		blocked_rects.append(fr.grow(PLAYER_COLLISION_RADIUS))
		smooth_blocked_rects.append(fr.grow(PLAYER_COLLISION_RADIUS + 2.5))

	for cy in range(rows):
		var py: float = nav_origin.y + (float(cy) + 0.5) * NAV_CELL_SIZE
		for cx in range(cols):
			var px: float = nav_origin.x + (float(cx) + 0.5) * NAV_CELL_SIZE
			var pt := Vector2(px, py)

			var inside_room: bool = false
			for r in rooms:
				var rd: Dictionary = r
				var rr: Rect2 = rd["rect"]
				if rr.has_point(pt):
					inside_room = true
					break
			if not inside_room:
				continue

			var hit_obstacle: bool = false
			for br in blocked_rects:
				if br.has_point(pt):
					hit_obstacle = true
					break
			if not hit_obstacle:
				raw_walkable[cy * cols + cx] = 1

	var hatch_cx: int = clampi(int(floorf((hatch_pos.x - nav_origin.x) / NAV_CELL_SIZE)), 0, cols - 1)
	var hatch_cy: int = clampi(int(floorf((hatch_pos.y - nav_origin.y) / NAV_CELL_SIZE)), 0, rows - 1)
	var hatch_idx: int = hatch_cy * cols + hatch_cx
	raw_walkable[hatch_idx] = 1

	# 4-connected BFS flood-fill starting from hatch_cell!
	var reachable := PackedByteArray()
	reachable.resize(total_cells)
	reachable.fill(0)

	var bfs_dist := PackedInt32Array()
	bfs_dist.resize(total_cells)
	bfs_dist.fill(-1)

	var bfs_parent := PackedInt32Array()
	bfs_parent.resize(total_cells)
	bfs_parent.fill(-1)

	var queue: Array[int] = [hatch_idx]
	reachable[hatch_idx] = 1
	bfs_dist[hatch_idx] = 0

	var head: int = 0
	var dx4: Array[int] = [1, -1, 0, 0]
	var dy4: Array[int] = [0, 0, 1, -1]
	var walkable_cells: Array[Vector2i] = []

	while head < queue.size():
		var cur_idx: int = queue[head]
		head += 1
		var cx: int = cur_idx % cols
		var cy: int = cur_idx / cols
		walkable_cells.append(Vector2i(cx, cy))
		var next_d: int = bfs_dist[cur_idx] + 1

		for dir_i in range(4):
			var nx: int = cx + dx4[dir_i]
			var ny: int = cy + dy4[dir_i]
			if nx < 0 or nx >= cols or ny < 0 or ny >= rows:
				continue
			var n_idx: int = ny * cols + nx
			if raw_walkable[n_idx] == 1 and reachable[n_idx] == 0:
				reachable[n_idx] = 1
				bfs_dist[n_idx] = next_d
				bfs_parent[n_idx] = cur_idx
				queue.append(n_idx)

	return {
		"cell_size": NAV_CELL_SIZE,
		"origin": nav_origin,
		"cols": cols,
		"rows": rows,
		"width": cols,
		"height": rows,
		"hatch_cell": Vector2i(hatch_cx, hatch_cy),
		"walkable": reachable.duplicate(),
		"reachable": reachable,
		"bfs_dist": bfs_dist,
		"bfs_parent": bfs_parent,
		"walkable_cells": walkable_cells,
		"inflated_obstacles": smooth_blocked_rects
	}


static func _find_unreachable_rooms(rooms: Array, nav_grid: Dictionary) -> Array[int]:
	var unreachable: Array[int] = []
	var cols: int = int(nav_grid["cols"])
	var rows: int = int(nav_grid["rows"])
	var reachable: PackedByteArray = nav_grid["reachable"]

	for i in range(rooms.size()):
		var rd: Dictionary = rooms[i]
		var rrect: Rect2 = rd["rect"]
		var center_pt: Vector2 = rd["center"]
		var c_cell: Vector2i = world_to_cell(nav_grid, center_pt)

		# Verify room center (or an immediate neighbor cell inside the room within 1 cell of center) is BFS-reachable,
		# AND that the room has at least 6 reachable floor cells for items/family!
		var center_ok: bool = false
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var tx: int = c_cell.x + ox
				var ty: int = c_cell.y + oy
				if tx >= 0 and tx < cols and ty >= 0 and ty < rows:
					var wpt: Vector2 = cell_to_world(nav_grid, Vector2i(tx, ty))
					if rrect.grow(-16.0).has_point(wpt) and reachable[ty * cols + tx] == 1:
						center_ok = true
						break
			if center_ok:
				break

		var room_reach_count: int = 0
		for wc in nav_grid["walkable_cells"]:
			var w_cell: Vector2i = wc
			if rrect.has_point(cell_to_world(nav_grid, w_cell)):
				room_reach_count += 1

		if not center_ok or room_reach_count < 6:
			unreachable.append(i)

	return unreachable


# ---------------------------------------------------------------------------
# Step 6: Leader Start, Family Spawns & Authentic 60 Seconds! Item Spawning
# ---------------------------------------------------------------------------

static func _collect_room_reachable_points(
	nav_grid: Dictionary,
	rooms: Array,
	walls: Array,
	furniture: Array,
	min_hatch_dist: float,
	hatch_pos: Vector2
) -> Dictionary:
	var by_room: Dictionary = {}
	for r in rooms:
		var rd: Dictionary = r
		by_room[str(rd["name"])] = []

	var clear_wall_pad: float = PLAYER_COLLISION_RADIUS + 3.0
	for wc in nav_grid["walkable_cells"]:
		var cell: Vector2i = wc
		var pt: Vector2 = cell_to_world(nav_grid, cell)
		if pt.distance_to(hatch_pos) < min_hatch_dist:
			continue

		var blocked_near: bool = false
		for w in walls:
			var wd: Dictionary = w
			var wr: Rect2 = wd["rect"]
			if wr.grow(clear_wall_pad).has_point(pt):
				blocked_near = true
				break
		if blocked_near:
			continue

		for f in furniture:
			var fd: Dictionary = f
			var fr: Rect2 = fd["rect"]
			if fr.grow(clear_wall_pad).has_point(pt):
				blocked_near = true
				break
		if blocked_near:
			continue

		for r in rooms:
			var rd: Dictionary = r
			var rr: Rect2 = rd["rect"]
			if rr.grow(-18.0).has_point(pt):
				var arr: Array = by_room[str(rd["name"])]
				arr.append(pt)
				break

	return by_room


static func _pick_leader_start_pos(
	nav_grid: Dictionary,
	rooms: Array,
	walls: Array,
	furniture: Array,
	hatch_pos: Vector2
) -> Vector2:
	var best_pt: Vector2 = hatch_pos + Vector2(0.0, LEADER_TARGET_HATCH_DIST)
	var best_score: float = 1.0e9
	var hall_room: Dictionary = _find_room_by_name(rooms, ROOM_CENTRAL_HALL)
	var hall_rect: Rect2 = hall_room["rect"]

	for wc in nav_grid["walkable_cells"]:
		var cell: Vector2i = wc
		var pt: Vector2 = cell_to_world(nav_grid, cell)
		var d: float = pt.distance_to(hatch_pos)
		if d < 66.0 or d > 135.0:
			continue

		var hit_obs: bool = false
		for w in walls:
			var wd: Dictionary = w
			if (wd["rect"] as Rect2).grow(PLAYER_COLLISION_RADIUS + 2.0).has_point(pt):
				hit_obs = true
				break
		if hit_obs:
			continue
		for f in furniture:
			var fd: Dictionary = f
			if (fd["rect"] as Rect2).grow(PLAYER_COLLISION_RADIUS + 2.0).has_point(pt):
				hit_obs = true
				break
		if hit_obs:
			continue

		var dist_err: float = absf(d - LEADER_TARGET_HATCH_DIST)
		if not hall_rect.has_point(pt):
			dist_err += 18.0
		if dist_err < best_score:
			best_score = dist_err
			best_pt = pt

	if best_score < 1.0e8:
		return best_pt

	# Fallback: pick any reachable cell closest to 90 px from hatch_pos.
	for wc in nav_grid["walkable_cells"]:
		var cell2: Vector2i = wc
		var pt2: Vector2 = cell_to_world(nav_grid, cell2)
		var d2: float = pt2.distance_to(hatch_pos)
		if d2 >= 56.0 and absf(d2 - LEADER_TARGET_HATCH_DIST) < best_score:
			best_score = absf(d2 - LEADER_TARGET_HATCH_DIST)
			best_pt = pt2
	return best_pt


static func _spawn_family_members(
	family_members: Array,
	rooms: Array,
	walls: Array,
	furniture: Array,
	nav_grid: Dictionary,
	hatch_pos: Vector2,
	leader_start_pos: Vector2,
	rng: RandomNumberGenerator
) -> Array:
	var spawns: Array = []
	if family_members.is_empty():
		return spawns

	var leader_idx: int = -1
	for i in range(family_members.size()):
		if family_members[i] is Dictionary:
			var md: Dictionary = family_members[i]
			if bool(md.get("is_leader", false)):
				leader_idx = i
				break
	if leader_idx < 0:
		leader_idx = 0

	var by_room: Dictionary = _collect_room_reachable_points(
		nav_grid,
		rooms,
		walls,
		furniture,
		MIN_ITEM_HATCH_DIST + 4.0,
		hatch_pos
	)
	var occupied: Array[Vector2] = [leader_start_pos]

	for i in range(family_members.size()):
		if i == leader_idx:
			continue
		if not (family_members[i] is Dictionary):
			continue
		var m: Dictionary = family_members[i]
		var role_str: String = str(m.get("role", "adult"))
		var age_val: int = int(m.get("age", 30))
		var slots_val: int = int(m.get("scavenge_slots", 2 if (role_str == "child" or role_str == "teen" or age_val < 18) else 3))
		var member_id: String = str(m.get("id", "member_%d" % i))

		var pref_rooms: Array[String]
		if role_str == "child" or role_str == "teen" or age_val < 18:
			pref_rooms = [ROOM_KIDS_BED, ROOM_LIVING, ROOM_MASTER_BED]
		else:
			pref_rooms = [ROOM_MASTER_BED, ROOM_LIVING, ROOM_KIDS_BED]

		var chosen: Dictionary = _pick_spawn_point(by_room, pref_rooms, occupied, 44.0, rng)
		var spawn_pos: Vector2 = chosen["pos"]
		occupied.append(spawn_pos)

		spawns.append({
			"member_index": i,
			"member_id": member_id,
			"name": str(m.get("name", "Family")),
			"role": role_str,
			"pos": spawn_pos,
			"position": spawn_pos,
			"slots": slots_val,
			"room": str(chosen["room"]),
			"rescued": false
		})

	return spawns


static func _spawn_house_items(
	rooms: Array,
	walls: Array,
	furniture: Array,
	nav_grid: Dictionary,
	hatch_pos: Vector2,
	leader_start_pos: Vector2,
	family_spawns: Array,
	rng: RandomNumberGenerator
) -> Array:
	var by_room: Dictionary = _collect_room_reachable_points(
		nav_grid,
		rooms,
		walls,
		furniture,
		MIN_ITEM_HATCH_DIST + 2.0,
		hatch_pos
	)

	var occupied_items: Array[Vector2] = []
	var occupied_family: Array[Vector2] = [leader_start_pos]
	for fs in family_spawns:
		var fsd: Dictionary = fs
		occupied_family.append(fsd["pos"])

	# Build exact 60 Seconds! spawn manifest (scaled by GameState difficulty ration bonus/penalty):
	# - 6..8 base "soup" cans (+2 on Little Boy = 8..10, -2 on Tsar Bomba = 4..6)
	# - 6..8 base "water" bottles (+2 on Little Boy = 8..10, -2 on Tsar Bomba = 4..6)
	# - Guaranteed core survival items: 1 "medkit", 1 "gas_mask", 1 "radio", 1 "suitcase", 1 "book", 1 weapon ("rifle" or "axe")
	# - Plus 6..8 randomized bonus items from RANDOM_BONUS_POOL placed by room theme!
	var spawn_requests: Array[Dictionary] = []

	var soup_bonus: int = 0
	var water_bonus: int = 0
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node_or_null("GameState") if tree != null else null
	if gs != null and gs.has_method("get_difficulty_config"):
		var diff_raw: Variant = gs.call("get_difficulty_config")
		if diff_raw is Dictionary:
			var diff_cfg: Dictionary = diff_raw
			soup_bonus = int(diff_cfg.get("spawn_soup_bonus", 0))
			water_bonus = int(diff_cfg.get("spawn_water_bonus", 0))

	var soup_count: int = clampi(rng.randi_range(6, 8) + soup_bonus, 3, 12)
	for s_i in range(soup_count):
		var soup_rooms: Array[String] = [ROOM_KITCHEN, ROOM_BATH_UTILITY]
		if s_i >= soup_count - 2:
			soup_rooms = [ROOM_LIVING, ROOM_MASTER_BED, ROOM_KIDS_BED, ROOM_KITCHEN]
		spawn_requests.append({"item_id": "soup", "pref": soup_rooms})

	var water_count: int = clampi(rng.randi_range(6, 8) + water_bonus, 3, 12)
	for w_i in range(water_count):
		var water_rooms: Array[String] = [ROOM_KITCHEN, ROOM_BATH_UTILITY]
		if w_i >= water_count - 2:
			water_rooms = [ROOM_MASTER_BED, ROOM_LIVING, ROOM_KIDS_BED, ROOM_BATH_UTILITY]
		spawn_requests.append({"item_id": "water", "pref": water_rooms})

	var primary_weapon: String = "rifle" if rng.randf() < 0.5 else "axe"
	var guaranteed_ids: Array[String] = [
		"medkit", "gas_mask", "radio", "suitcase", "book", primary_weapon
	]
	for gid in guaranteed_ids:
		var g_meta: Dictionary = ITEM_META[gid]
		var g_rooms: Array[String] = []
		for rn in g_meta["rooms"]:
			g_rooms.append(str(rn))
		spawn_requests.append({"item_id": gid, "pref": g_rooms})

	# Shuffle bonus pool so durable gear appears cleanly without excessive duplicates.
	var bonus_candidates: Array[String] = []
	for bid in RANDOM_BONUS_POOL:
		if bid != primary_weapon:
			bonus_candidates.append(bid)
	for idx in range(bonus_candidates.size() - 1, 0, -1):
		var sw: int = rng.randi_range(0, idx)
		var tmp_s: String = bonus_candidates[idx]
		bonus_candidates[idx] = bonus_candidates[sw]
		bonus_candidates[sw] = tmp_s

	var bonus_count: int = rng.randi_range(6, 8)
	for b_i in range(bonus_count):
		var chosen_id: String = bonus_candidates[b_i % bonus_candidates.size()]
		var b_meta: Dictionary = ITEM_META[chosen_id]
		var b_rooms: Array[String] = []
		for rn2 in b_meta["rooms"]:
			b_rooms.append(str(rn2))
		spawn_requests.append({"item_id": chosen_id, "pref": b_rooms})

	var items: Array = []
	for req_idx in range(spawn_requests.size()):
		var req: Dictionary = spawn_requests[req_idx]
		var item_id: String = str(req["item_id"])
		var pref: Array[String] = req["pref"]

		var picked: Dictionary = _pick_item_spawn_point(
			by_room,
			pref,
			occupied_items,
			occupied_family,
			MIN_ITEM_SPACING + 1.0,
			rng
		)
		if not bool(picked.get("ok", false)):
			# Fallback over all raw walkable cells >= 95 px from hatch and >= 38 px from all items.
			picked = _pick_fallback_walkable_item_point(
				nav_grid,
				rooms,
				hatch_pos,
				occupied_items,
				MIN_ITEM_HATCH_DIST + 0.5,
				MIN_ITEM_SPACING + 0.25,
				rng
			)
		if not bool(picked.get("ok", false)):
			continue

		var pos: Vector2 = picked["pos"]
		occupied_items.append(pos)
		var meta: Dictionary = ITEM_META.get(item_id, {"name": item_id.capitalize(), "slots": 1})
		items.append({
			"uid": req_idx,
			"id": item_id,
			"item_id": item_id,
			"name": str(meta.get("name", item_id)),
			"slots": int(meta.get("slots", 1)),
			"pos": pos,
			"position": pos,
			"room": str(picked.get("room", ROOM_CENTRAL_HALL)),
			"collected": false
		})

	return items


static func _pick_spawn_point(
	by_room: Dictionary,
	pref_rooms: Array[String],
	occupied: Array[Vector2],
	min_spacing: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var search_order: Array[String] = []
	for pr in pref_rooms:
		if not search_order.has(pr):
			search_order.append(pr)
	for k in by_room.keys():
		var ks: String = str(k)
		if ks != ROOM_CENTRAL_HALL and not search_order.has(ks):
			search_order.append(ks)
	if not search_order.has(ROOM_CENTRAL_HALL):
		search_order.append(ROOM_CENTRAL_HALL)

	for spacing_scale in [1.0, 0.8, 0.5]:
		var req_dist: float = min_spacing * float(spacing_scale)
		for rname in search_order:
			var pts: Array = by_room.get(rname, [])
			if pts.is_empty():
				continue
			var valid_pts: Array[Vector2] = []
			for p in pts:
				var pv: Vector2 = p
				var too_close: bool = false
				for occ in occupied:
					if pv.distance_to(occ) < req_dist:
						too_close = true
						break
				if not too_close:
					valid_pts.append(pv)
			if not valid_pts.is_empty():
				var pick_i: int = rng.randi_range(0, valid_pts.size() - 1)
				return {"pos": valid_pts[pick_i], "room": rname}

	# Last-resort reachable cell in any room.
	for k2 in by_room.keys():
		var pts2: Array = by_room[k2]
		if not pts2.is_empty():
			return {"pos": pts2[0], "room": str(k2)}
	return {"pos": Vector2(0.0, -96.0), "room": ROOM_CENTRAL_HALL}


static func _pick_item_spawn_point(
	by_room: Dictionary,
	pref_rooms: Array[String],
	occupied_items: Array[Vector2],
	occupied_family: Array[Vector2],
	min_item_spacing: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	# 75% chance to prioritize thematic preferred rooms first; 25% chance to scatter into any outer room.
	var search_order: Array[String] = []
	var all_outer: Array[String] = [
		ROOM_KITCHEN, ROOM_LIVING, ROOM_MASTER_BED, ROOM_KIDS_BED, ROOM_BATH_UTILITY
	]
	if rng.randf() < 0.78:
		for pr in pref_rooms:
			if not search_order.has(pr):
				search_order.append(pr)
	for idx in range(all_outer.size() - 1, 0, -1):
		var sw: int = rng.randi_range(0, idx)
		var tmp: String = all_outer[idx]
		all_outer[idx] = all_outer[sw]
		all_outer[sw] = tmp
	for rname in all_outer:
		if not search_order.has(rname):
			search_order.append(rname)
	if not search_order.has(ROOM_CENTRAL_HALL):
		search_order.append(ROOM_CENTRAL_HALL)

	for rname in search_order:
		var pts: Array = by_room.get(rname, [])
		if pts.is_empty():
			continue
		var candidates: Array[Vector2] = []
		for p in pts:
			var pv: Vector2 = p
			# Add gentle sub-cell jitter (+/- 3 px) only if still >= min_item_spacing from all items.
			var ok_item: bool = true
			for oi in occupied_items:
				if pv.distance_to(oi) < min_item_spacing:
					ok_item = false
					break
			if not ok_item:
				continue
			var ok_fam: bool = true
			for ofam in occupied_family:
				if pv.distance_to(ofam) < 28.0:
					ok_fam = false
					break
			if ok_fam:
				candidates.append(pv)

		if not candidates.is_empty():
			var pick_i: int = rng.randi_range(0, candidates.size() - 1)
			return {"ok": true, "pos": candidates[pick_i], "room": rname}

	return {"ok": false}


static func _pick_fallback_walkable_item_point(
	nav_grid: Dictionary,
	rooms: Array,
	hatch_pos: Vector2,
	occupied_items: Array[Vector2],
	min_hatch_d: float,
	min_item_d: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var valid: Array[Vector2] = []
	for wc in nav_grid["walkable_cells"]:
		var c: Vector2i = wc
		var pt: Vector2 = cell_to_world(nav_grid, c)
		if pt.distance_to(hatch_pos) < min_hatch_d:
			continue
		var clash: bool = false
		for oi in occupied_items:
			if pt.distance_to(oi) < min_item_d:
				clash = true
				break
		if not clash:
			valid.append(pt)

	if valid.is_empty():
		return {"ok": false}

	var chosen_pt: Vector2 = valid[rng.randi_range(0, valid.size() - 1)]
	var rname: String = ROOM_CENTRAL_HALL
	for r in rooms:
		var rd: Dictionary = r
		if (rd["rect"] as Rect2).has_point(chosen_pt):
			rname = str(rd["name"])
			break
	return {"ok": true, "pos": chosen_pt, "room": rname}


# ---------------------------------------------------------------------------
# Internal Pathfinding Helpers
# ---------------------------------------------------------------------------

static func _nearest_reachable_cell(nav_grid: Dictionary, target: Vector2i) -> Vector2i:
	var cols: int = int(nav_grid.get("cols", 0))
	var rows: int = int(nav_grid.get("rows", 0))
	var reachable: PackedByteArray = nav_grid.get("reachable", PackedByteArray())
	if cols <= 0 or rows <= 0 or reachable.size() != cols * rows:
		return Vector2i(-1, -1)

	var cx: int = clampi(target.x, 0, cols - 1)
	var cy: int = clampi(target.y, 0, rows - 1)
	if reachable[cy * cols + cx] == 1:
		return Vector2i(cx, cy)

	var best_cell := Vector2i(-1, -1)
	var best_d2: int = 100000000
	for radius in range(1, maxi(cols, rows)):
		var y_min: int = maxi(0, cy - radius)
		var y_max: int = mini(rows - 1, cy + radius)
		var x_min: int = maxi(0, cx - radius)
		var x_max: int = mini(cols - 1, cx + radius)
		for ty in range(y_min, y_max + 1):
			for tx in range(x_min, x_max + 1):
				if reachable[ty * cols + tx] == 1:
					var d2: int = (tx - cx) * (tx - cx) + (ty - cy) * (ty - cy)
					if d2 < best_d2:
						best_d2 = d2
						best_cell = Vector2i(tx, ty)
		if best_cell.x >= 0:
			return best_cell
	return best_cell


static func _heuristic_cells(x1: int, y1: int, x2: int, y2: int) -> float:
	var dx: float = absf(float(x2 - x1))
	var dy: float = absf(float(y2 - y1))
	return (dx + dy) + (1.41421356 - 2.0) * minf(dx, dy)


static func _point_clear_of_obstacles(nav_grid: Dictionary, pt: Vector2) -> bool:
	var obs_list: Array = nav_grid.get("inflated_obstacles", [])
	for ob in obs_list:
		var r: Rect2 = ob
		if r.has_point(pt):
			return false
	return true


static func _segment_intersects_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var d: Vector2 = b - a
	var t_min: float = 0.0
	var t_max: float = 1.0

	if absf(d.x) < 1.0e-6:
		if a.x < r.position.x or a.x > r.end.x:
			return false
	else:
		var inv_x: float = 1.0 / d.x
		var tx1: float = (r.position.x - a.x) * inv_x
		var tx2: float = (r.end.x - a.x) * inv_x
		if tx1 > tx2:
			var tmp_x: float = tx1
			tx1 = tx2
			tx2 = tmp_x
		t_min = maxf(t_min, tx1)
		t_max = minf(t_max, tx2)
		if t_min > t_max:
			return false

	if absf(d.y) < 1.0e-6:
		if a.y < r.position.y or a.y > r.end.y:
			return false
	else:
		var inv_y: float = 1.0 / d.y
		var ty1: float = (r.position.y - a.y) * inv_y
		var ty2: float = (r.end.y - a.y) * inv_y
		if ty1 > ty2:
			var tmp_y: float = ty1
			ty1 = ty2
			ty2 = tmp_y
		t_min = maxf(t_min, ty1)
		t_max = minf(t_max, ty2)
		if t_min > t_max:
			return false

	return true


static func _has_clear_walkable_sight(nav_grid: Dictionary, a: Vector2, b: Vector2) -> bool:
	var dist: float = a.distance_to(b)
	if dist < 2.0:
		return true
	var obs_list: Array = nav_grid.get("inflated_obstacles", [])
	for ob in obs_list:
		var r: Rect2 = ob
		if _segment_intersects_rect(a, b, r):
			return false

	var csize: float = float(nav_grid.get("cell_size", NAV_CELL_SIZE))
	var steps: int = maxi(2, int(ceilf(dist / (csize * 0.4))))
	for s in range(steps + 1):
		var t: float = float(s) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		if not is_walkable(nav_grid, p):
			return false
	return true


static func _smooth_path(nav_grid: Dictionary, pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector2Array()
	var anchor: int = 0
	out.append(pts[0])
	while anchor < pts.size() - 1:
		var furthest: int = anchor + 1
		for probe in range(pts.size() - 1, anchor + 1, -1):
			if _has_clear_walkable_sight(nav_grid, pts[anchor], pts[probe]):
				furthest = probe
				break
		out.append(pts[furthest])
		anchor = furthest
	return out
