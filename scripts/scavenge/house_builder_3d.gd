class_name HouseBuilder3D
extends RefCounted

## Turns a FloorplanGenerator layout into a 3D house for the first-person grab.
##
## The outer walls are the selected building's real OSM outline extruded to 2.55 m; rooms,
## interior walls, doors and furniture come from the generated floorplan (fictional, regenerated
## every run). 1 m = 46 layout pixels, layout (x, y) -> world (x, z).
##
## Web budget (Compatibility renderer): every room is its own floor, ceiling and wall mesh, so no
## mesh is touched by more than a few of the room lights; one omni light per room, shadows only
## on the room the player is in (HouseGrab3D switches them); no baked lighting.

const PX: float = 46.0
const WALL_H: float = 2.55
const DOOR_H: float = 2.08
const EXT_T: float = 16.0 / PX
const INT_T: float = 10.0 / PX
const SILL: float = 0.92
const WIN_TOP: float = 2.08
const WIN_W: float = 1.1
const HATCH_HALF: float = 0.5
const SHAFT_D: float = 2.7
const SURF: String = "res://assets/textures/surfaces/"

static var _mats: Dictionary = {}
static var _paint_rooms: Array = []

# Wall paint by room (muted, so rooms are easy to tell apart at a glance).
const PAINT: Dictionary = {
	"Living Room": Color("#e9dcc6"), "Kitchen": Color("#dce5cf"), "Master Bedroom": Color("#d3dbe6"),
	"Bedroom": Color("#e2d8e4"), "Kids Bedroom": Color("#f0e0b2"), "Bathroom": Color("#cfe4e4"),
	"Dining Room": Color("#ead3c3"), "Study": Color("#d9d4c3"), "Hallway": Color("#ebe7df"),
	"Central Hall": Color("#ebe7df"), "Utility Room": Color("#d6d7d4"), "Storage": Color("#d6d7d4"),
	"Garage Bay": Color("#cfd0cd"), "Pantry": Color("#e4dccb"), "Sealed Closet": Color("#e0ddd6"),
}


## Headless runs (tests, the .pck smoke) use a dummy renderer that keeps no mesh data: merging and
## baking are skipped there (nothing is drawn anyway).
static func no_mesh_data() -> bool:
	return DisplayServer.get_name() == "headless"


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x / PX, y, p.y / PX)


static func floor_kind(room_name: String) -> String:
	var k: String = FloorplanGenerator.base_room_kind(room_name)
	match k:
		"Kitchen", "Bathroom", "Pantry":
			return "tiles"
		"Kids Bedroom":
			return "carpet"
		"Utility Room", "Storage", "Garage Bay", "Sealed Closet":
			return "concrete"
	return "wood_floor"


## Returns {"root", "rooms": [{name, poly (px), center (px), light, node, sealed}], "hatch"}.
static func build(layout: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "House3D"
	var outer: PackedVector2Array = layout.get("outer_polygon", PackedVector2Array())
	var hatch: Vector2 = layout.get("hatch_pos", Vector2.ZERO)
	var rooms_in: Array = layout.get("rooms", [])
	var rooms: Array = []
	for r_v in rooms_in:
		var r: Dictionary = r_v
		var node := Node3D.new()
		node.name = "Room_" + str(r.get("name", "")).replace(" ", "_")
		root.add_child(node)
		rooms.append({"name": str(r.get("name", "")), "poly": r.get("polygon", PackedVector2Array()),
			"center": r.get("center", Vector2.ZERO), "sealed": bool(r.get("sealed", false)), "node": node,
			"light": null, "walls": SurfaceTool.new(), "trim": SurfaceTool.new(), "walls_n": 0, "trim_n": 0})
	for rm in rooms:
		(rm["walls"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
		(rm["trim"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)

	_paint_rooms = rooms
	var hub: int = _room_at(rooms, hatch)
	# Floors and ceilings.
	for i in range(rooms.size()):
		var rm: Dictionary = rooms[i]
		var poly: PackedVector2Array = rm["poly"]
		if poly.size() < 3:
			continue
		var pieces: Array = [poly]
		if i == hub:
			pieces = _cut_hatch(poly, hatch)
		var fl := _flat_mesh(pieces, 0.0, true, 2.2)
		var fmi := MeshInstance3D.new()
		fmi.name = "Floor"
		fmi.mesh = fl
		fmi.material_override = surface_material(floor_kind(str(rm["name"])))
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(rm["node"] as Node3D).add_child(fmi)
		var ce := _flat_mesh([poly], WALL_H, false, 3.0)
		var cmi := MeshInstance3D.new()
		cmi.name = "Ceiling"
		cmi.mesh = ce
		cmi.material_override = ceiling_material()
		cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(rm["node"] as Node3D).add_child(cmi)

	# Walls.
	var walls: Array = layout.get("walls", [])
	var doorways: Array = layout.get("doorways", [])
	var entrances: Array = layout.get("entrances", [])
	var furniture: Array = layout.get("furniture", [])
	var interior_rects: Array = []
	for w_v in walls:
		var w: Dictionary = w_v
		if w.get("rect") is Rect2:
			interior_rects.append(w["rect"])
	for w_v in walls:
		var w: Dictionary = w_v
		if w.get("a") is Vector2 and w.get("b") is Vector2:
			_exterior_wall(rooms, w["a"], w["b"], entrances, interior_rects, furniture, outer)
		elif w.get("rect") is Rect2:
			var r: Rect2 = w["rect"]
			var c: Vector2 = r.get_center()
			var rm: Dictionary = _room_for_wall(rooms, c, r.size.x >= r.size.y)
			_box(rm, "walls", to3(c, WALL_H * 0.5), Vector3(r.size.x / PX, WALL_H, r.size.y / PX), 0.0)
	# Door openings in interior walls: lintel and frame.
	for d_v in doorways:
		var d: Dictionary = d_v
		var a: Vector2 = d["a"]
		var b: Vector2 = d["b"]
		var c2: Vector2 = d["center"]
		var horiz: bool = bool(d.get("horizontal", absf(a.y - b.y) < 0.5))
		var rm2: Dictionary = _room_for_wall(rooms, c2, horiz)
		var len_m: float = a.distance_to(b) / PX
		var yaw: float = 0.0 if horiz else PI * 0.5
		_box(rm2, "walls", to3(c2, (DOOR_H + WALL_H) * 0.5), Vector3(len_m + 0.02, WALL_H - DOOR_H, INT_T), yaw)
		var along: Vector3 = (to3(b) - to3(a)).normalized()
		for s in [-1.0, 1.0]:
			_box(rm2, "trim", to3(c2, DOOR_H * 0.5) + along * (len_m * 0.5 + 0.03) * s, Vector3(0.07, DOOR_H, INT_T + 0.04), yaw)
		_box(rm2, "trim", to3(c2, DOOR_H + 0.035), Vector3(len_m + 0.2, 0.07, INT_T + 0.04), yaw)

	# Walls and trim are never culled with a room: a wall between two rooms belongs to one of them,
	# and hiding it with that room would open a hole in the other. One mesh each per room is cheap.
	var shell := Node3D.new()
	shell.name = "Shell"
	root.add_child(shell)
	for rm in rooms:
		var node: Node3D = rm["node"]
		if int(rm["walls_n"]) > 0:
			var wmi := MeshInstance3D.new()
			wmi.name = "Walls_" + str(node.name)
			wmi.mesh = null if no_mesh_data() else (rm["walls"] as SurfaceTool).commit()
			wmi.material_override = wall_material()
			shell.add_child(wmi)
		if int(rm["trim_n"]) > 0:
			var tmi := MeshInstance3D.new()
			tmi.name = "Trim_" + str(node.name)
			tmi.mesh = null if no_mesh_data() else (rm["trim"] as SurfaceTool).commit()
			tmi.material_override = trim_material()
			tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shell.add_child(tmi)
		rm.erase("walls")
		rm.erase("trim")

	# One warm ceiling light per open room, with a fixture.
	for rm in rooms:
		if bool(rm["sealed"]) or (rm["poly"] as PackedVector2Array).size() < 3:
			continue
		var bb: Rect2 = FloorplanGenerator._poly_bounds(rm["poly"])
		var c3: Vector2 = rm["center"]
		var lamp := OmniLight3D.new()
		lamp.name = "Light"
		lamp.position = to3(c3, WALL_H - 0.3)
		lamp.light_color = Color(1.0, 0.93, 0.83)
		lamp.light_energy = 1.0
		lamp.omni_range = clampf(maxf(bb.size.x, bb.size.y) / PX * 0.85, 3.2, 8.0)
		lamp.omni_attenuation = 0.9
		lamp.shadow_enabled = false
		# Lights hang off the house, not the room: hiding a room (culling) never changes the light.
		root.add_child(lamp)
		rm["light"] = lamp
		var fix: Node3D = PropLibrary.fitted(PropLibrary.model_path("lampSquareCeiling"), Vector3(0.45, 0.18, 0.45))
		fix.position = to3(c3, WALL_H - 0.18)
		(rm["node"] as Node3D).add_child(fix)

	var hatch_node: Node3D = _build_hatch(hatch)
	# Turn the hatch so its lid and ladder are on the far side from where the leader starts.
	var start: Vector2 = layout.get("leader_start_pos", hatch + Vector2(0.0, 60.0))
	var to_start: Vector2 = start - hatch
	if to_start.length() > 4.0:
		hatch_node.rotation.y = atan2(to_start.x, to_start.y)
	root.add_child(hatch_node)
	return {"root": root, "rooms": rooms, "hatch": hatch_node, "hub": hub}


# ------------------------------------------------------------------------------
# Walls
# ------------------------------------------------------------------------------

static func _exterior_wall(rooms: Array, a: Vector2, b: Vector2, entrances: Array, interior_rects: Array, furniture: Array, outer: PackedVector2Array) -> void:
	var len_px: float = a.distance_to(b)
	if len_px < 1.0:
		return
	var dir: Vector2 = (b - a) / len_px
	var nrm := Vector2(-dir.y, dir.x)
	var mid: Vector2 = (a + b) * 0.5
	if not Geometry2D.is_point_in_polygon(mid + nrm * 20.0, outer):
		nrm = -nrm   # nrm points into the house
	var rm: Dictionary = _room_for_point(rooms, mid + nrm * 18.0)
	var len_m: float = len_px / PX
	var yaw: float = atan2(-(b - a).y, (b - a).x)   # rotation about Y so local X runs a -> b
	# Openings along the edge, as [from_m, to_m, kind].
	var openings: Array = []
	for e_v in entrances:
		var e: Dictionary = e_v
		var ec: Vector2 = e["center"]
		if _dist_point_segment(ec, a, b) < 4.0:
			var t: float = (ec - a).dot(dir) / PX
			var ew: float = float(e.get("width", 58.0)) / PX
			openings.append([t - ew * 0.5, t + ew * 0.5, "door"])
	if len_m >= 1.9:
		var n: int = clampi(int(floor((len_m - 0.8) / 2.7)), 1, 4)
		for k in range(n):
			var t2: float = len_m * (float(k) + 0.5) / float(n)
			var lo: float = t2 - WIN_W * 0.5
			var hi: float = t2 + WIN_W * 0.5
			if lo < 0.45 or hi > len_m - 0.45:
				continue
			var ok: bool = true
			for o in openings:
				if hi > float(o[0]) - 0.4 and lo < float(o[1]) + 0.4:
					ok = false
			for r_v in interior_rects:
				var r: Rect2 = r_v
				var p0: Vector2 = a + dir * (lo - 0.25) * PX
				var p1: Vector2 = a + dir * (hi + 0.25) * PX
				if _segment_hits_rect(p0 + nrm * 6.0, p1 + nrm * 6.0, r.grow(2.0)):
					ok = false
			for f_v in furniture:
				var f: Dictionary = f_v
				if not (f.get("rect") is Rect2):
					continue
				var kind: String = str(f.get("type", ""))
				if kind in ["rug", "coffee_table", "kitchen_table", "dining_table", "armchair", "nightstand", "boxes", "paint_cans", "toy_chest"]:
					continue
				var p0f: Vector2 = a + dir * lo * PX + nrm * 14.0
				var p1f: Vector2 = a + dir * hi * PX + nrm * 14.0
				if _segment_hits_rect(p0f, p1f, (f["rect"] as Rect2).grow(6.0)):
					ok = false
			if ok:
				openings.append([lo, hi, "window"])
	openings.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var cursor: float = -EXT_T * 0.5
	var origin: Vector3 = to3(a)
	var along := Vector3(dir.x, 0.0, dir.y)
	var inward := Vector3(nrm.x, 0.0, nrm.y)
	for o in openings:
		var lo2: float = float(o[0])
		var hi2: float = float(o[1])
		_wall_piece(rm, origin, along, yaw, cursor, lo2, 0.0, WALL_H)
		if str(o[2]) == "window":
			_wall_piece(rm, origin, along, yaw, lo2, hi2, 0.0, SILL)
			_wall_piece(rm, origin, along, yaw, lo2, hi2, WIN_TOP, WALL_H)
			_window(rm, origin + along * (lo2 + hi2) * 0.5, along, inward, yaw, hi2 - lo2)
		else:
			_wall_piece(rm, origin, along, yaw, lo2, hi2, DOOR_H, WALL_H)
			_front_door(rm, origin + along * (lo2 + hi2) * 0.5, inward, yaw, hi2 - lo2)
		cursor = hi2
	_wall_piece(rm, origin, along, yaw, cursor, len_m + EXT_T * 0.5, 0.0, WALL_H)


static func _wall_piece(rm: Dictionary, origin: Vector3, along: Vector3, yaw: float, t0: float, t1: float, y0: float, y1: float) -> void:
	if t1 - t0 < 0.01 or y1 - y0 < 0.01:
		return
	var c: Vector3 = origin + along * (t0 + t1) * 0.5
	c.y = (y0 + y1) * 0.5
	_box(rm, "walls", c, Vector3(t1 - t0, y1 - y0, EXT_T), yaw)


static func _window(rm: Dictionary, center: Vector3, along: Vector3, inward: Vector3, yaw: float, width: float) -> void:
	var node: Node3D = rm["node"]
	var glass := MeshInstance3D.new()
	glass.mesh = PropLibrary.merged_mesh([["quad", Vector3(width, WIN_TOP - SILL, 0), Vector3.ZERO, Color.WHITE]])
	glass.material_override = window_material()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# QuadMesh faces +Z; turn it to face into the room.
	glass.transform = Transform3D(Basis.looking_at(-inward, Vector3.UP), center + Vector3(0.0, (SILL + WIN_TOP) * 0.5, 0.0) - inward * 0.02)
	node.add_child(glass)
	var y_mid: float = (SILL + WIN_TOP) * 0.5
	var c: Vector3 = center + inward * (EXT_T * 0.5 - 0.02)
	_box(rm, "trim", c + Vector3(0, SILL - 0.03, 0) + inward * 0.04, Vector3(width + 0.16, 0.05, 0.14), yaw)
	_box(rm, "trim", c + Vector3(0, WIN_TOP + 0.03, 0), Vector3(width + 0.16, 0.06, 0.06), yaw)
	_box(rm, "trim", c + Vector3(0, y_mid, 0) + along * (width * 0.5 + 0.04), Vector3(0.07, WIN_TOP - SILL + 0.12, 0.06), yaw)
	_box(rm, "trim", c + Vector3(0, y_mid, 0) - along * (width * 0.5 + 0.04), Vector3(0.07, WIN_TOP - SILL + 0.12, 0.06), yaw)
	_box(rm, "trim", center + Vector3(0, y_mid, 0), Vector3(0.04, WIN_TOP - SILL, 0.05), yaw)
	_box(rm, "trim", center + Vector3(0, y_mid + 0.12, 0), Vector3(width, 0.04, 0.05), yaw)


static func _front_door(rm: Dictionary, center: Vector3, inward: Vector3, yaw: float, width: float) -> void:
	var node: Node3D = rm["node"]
	var door := MeshInstance3D.new()
	door.mesh = PropLibrary.merged_mesh([
		["box", Vector3(width - 0.04, DOOR_H - 0.02, 0.05), Vector3(0, (DOOR_H - 0.02) * 0.5, 0), Color("#6e4b32")],
		["box", Vector3(width * 0.36, DOOR_H * 0.34, 0.012), Vector3(-width * 0.2, DOOR_H * 0.72, 0.03), Color("#5e3f2a")],
		["box", Vector3(width * 0.36, DOOR_H * 0.34, 0.012), Vector3(width * 0.2, DOOR_H * 0.72, 0.03), Color("#5e3f2a")],
		["box", Vector3(width * 0.36, DOOR_H * 0.34, 0.012), Vector3(-width * 0.2, DOOR_H * 0.3, 0.03), Color("#5e3f2a")],
		["box", Vector3(width * 0.36, DOOR_H * 0.34, 0.012), Vector3(width * 0.2, DOOR_H * 0.3, 0.03), Color("#5e3f2a")],
		["sphere", Vector3(0.035, 0.07, 0), Vector3(width * 0.38, 1.0, 0.06), Color("#c9a13d")],
		["box", Vector3(0.05, 0.1, 0.03), Vector3(width * 0.38, 1.12, 0.045), Color("#c9a13d")],
	])
	door.material_override = PropLibrary.vertex_color_material()
	# The panelled side (+Z) faces into the room.
	door.transform = Transform3D(Basis.looking_at(-inward, Vector3.UP), center + inward * 0.02)
	node.add_child(door)
	var c: Vector3 = center + inward * (EXT_T * 0.5)
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	_box(rm, "trim", c + Vector3(0, DOOR_H * 0.5, 0) + along * (width * 0.5 + 0.04), Vector3(0.08, DOOR_H, 0.06), yaw)
	_box(rm, "trim", c + Vector3(0, DOOR_H * 0.5, 0) - along * (width * 0.5 + 0.04), Vector3(0.08, DOOR_H, 0.06), yaw)
	_box(rm, "trim", c + Vector3(0, DOOR_H + 0.04, 0), Vector3(width + 0.24, 0.08, 0.06), yaw)


## Merges every static prop under a room node (furniture, fixtures, windows, doors) into one
## mesh with one surface per material, so a room costs a handful of draw calls on the web.
## Children named in `keep` (floor, ceiling, walls, trim) and lights are left alone.
static func merge_statics(room_node: Node3D, keep: Array) -> MeshInstance3D:
	if no_mesh_data():
		return null
	var groups: Dictionary = {}
	var order: Array = []
	var gone: Array = []
	for c in room_node.get_children():
		if c is Light3D or str(c.name) in keep:
			continue
		if c is Node3D:
			_collect_meshes(c, (c as Node3D).transform, groups, order)
			gone.append(c)
	if order.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for mat in order:
		var st: SurfaceTool = groups[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	for g in gone:
		room_node.remove_child(g)
		g.free()
	var mi := MeshInstance3D.new()
	mi.name = "Props"
	mi.mesh = mesh
	room_node.add_child(mi)
	return mi


static func _collect_meshes(n: Node, xf: Transform3D, groups: Dictionary, order: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
		var mi: MeshInstance3D = n
		for i in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			if mat == null:
				mat = PropLibrary.vertex_color_material()
			if not groups.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[mat] = st
				order.append(mat)
			(groups[mat] as SurfaceTool).append_from(mi.mesh, i, xf)
	for c in n.get_children():
		if c is Node3D:
			_collect_meshes(c, xf * (c as Node3D).transform, groups, order)


## Adds an axis box (size along its local X/Y/Z, turned by yaw about Y) to a room's wall or trim mesh.
static func _box(rm: Dictionary, which: String, center: Vector3, size: Vector3, yaw: float) -> void:
	# Trim (door and window frames) goes into the walls mesh in white: one draw call per room.
	var st: SurfaceTool = rm["walls"]
	var basis := Basis(Vector3.UP, yaw)
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var faces: Array = [
		[Vector3(0, 0, 1), [Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz)]],
		[Vector3(0, 0, -1), [Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz)]],
		[Vector3(1, 0, 0), [Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz)]],
		[Vector3(-1, 0, 0), [Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz)]],
		[Vector3(0, 1, 0), [Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz)]],
		[Vector3(0, -1, 0), [Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz)]],
	]
	for f in faces:
		var n: Vector3 = basis * (f[0] as Vector3)
		var q: Array = []
		for v in f[1]:
			q.append(center + basis * (v as Vector3))
		var uvs: Array = []
		for p in q:
			var pp: Vector3 = p
			if absf(n.y) > 0.5:
				uvs.append(Vector2(pp.x, pp.z) / 2.0)
			elif absf(n.x) > absf(n.z):
				uvs.append(Vector2(pp.z, -pp.y) / 2.0)
			else:
				uvs.append(Vector2(pp.x, -pp.y) / 2.0)
		# Godot treats clockwise triangles as front faces; the quads above are listed counter-clockwise.
		var paint := Color(1.08, 1.07, 1.04) if which == "trim" else Color.WHITE
		if which == "walls" and absf(n.y) < 0.5:
			var fc: Vector3 = ((q[0] as Vector3) + (q[2] as Vector3)) * 0.5 + n * 0.12
			var ri: int = _room_at(_paint_rooms, Vector2(fc.x, fc.z) * PX)
			if ri >= 0:
				paint = PAINT.get(FloorplanGenerator.base_room_kind(str(_paint_rooms[ri]["name"])), Color("#e6e2da"))
		for k in [0, 2, 1, 0, 3, 2]:
			var p2: Vector3 = q[k]
			# Fake ambient occlusion: walls darken toward the floor.
			var shade: float = clampf(0.66 + 0.34 * smoothstep(0.0, 1.1, p2.y), 0.6, 1.0) if which == "walls" else 1.0
			st.set_color(Color(paint.r * shade, paint.g * shade, paint.b * shade))
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.add_vertex(p2)
	rm["walls_n"] = int(rm["walls_n"]) + 1


# ------------------------------------------------------------------------------
# Floors, ceilings, hatch
# ------------------------------------------------------------------------------

static func _flat_mesh(polys: Array, y: float, up: bool, tile_m: float) -> ArrayMesh:
	if no_mesh_data():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p_v in polys:
		var poly: PackedVector2Array = p_v
		if poly.size() < 3:
			continue
		var tri: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		var nrm := Vector3.UP if up else Vector3.DOWN
		for i in range(0, tri.size(), 3):
			var order: Array = [tri[i], tri[i + 1], tri[i + 2]]
			var a3: Vector3 = to3(poly[order[0]], y)
			var b3: Vector3 = to3(poly[order[1]], y)
			var c3: Vector3 = to3(poly[order[2]], y)
			# Clockwise seen from the side it faces (Godot's front-face winding).
			var faces_up: bool = (b3 - a3).cross(c3 - a3).y < 0.0
			if faces_up != up:
				order = [order[0], order[2], order[1]]
			for k in order:
				var v: Vector3 = to3(poly[k], y)
				st.set_normal(nrm)
				st.set_color(Color.WHITE)
				st.set_uv(Vector2(v.x, v.z) / tile_m)
				st.add_vertex(v)
	st.generate_tangents()
	return st.commit()


## The hub room's floor in pieces, cut around the hatch opening (no polygons with holes).
static func _cut_hatch(poly: PackedVector2Array, hatch: Vector2) -> Array:
	var h: float = HATCH_HALF * PX
	var sq := PackedVector2Array([hatch + Vector2(-h, -h), hatch + Vector2(h, -h), hatch + Vector2(h, h), hatch + Vector2(-h, h)])
	var big: float = 100000.0
	var halves: Array = [
		PackedVector2Array([Vector2(-big, -big), Vector2(hatch.x, -big), Vector2(hatch.x, big), Vector2(-big, big)]),
		PackedVector2Array([Vector2(hatch.x, -big), Vector2(big, -big), Vector2(big, big), Vector2(hatch.x, big)]),
	]
	var out: Array = []
	for half in halves:
		for part in Geometry2D.intersect_polygons(poly, half):
			for piece in Geometry2D.clip_polygons(part, sq):
				out.append(piece)
	return out if not out.is_empty() else [poly]


static func _build_hatch(hatch: Vector2) -> Node3D:
	var n := Node3D.new()
	n.name = "Hatch"
	n.position = to3(hatch)
	var h: float = HATCH_HALF
	var metal := Color("#5d646c")
	var dark := Color("#2a2e33")
	var hazard := Color("#d99b26")
	var parts: Array = [
		# Frame around the opening.
		["box", Vector3(2 * h + 0.16, 0.05, 0.08), Vector3(0, 0.025, -h - 0.04), hazard],
		["box", Vector3(2 * h + 0.16, 0.05, 0.08), Vector3(0, 0.025, h + 0.04), hazard],
		["box", Vector3(0.08, 0.05, 2 * h), Vector3(-h - 0.04, 0.025, 0), hazard],
		["box", Vector3(0.08, 0.05, 2 * h), Vector3(h + 0.04, 0.025, 0), hazard],
		# Shaft walls (seen from above, facing in).
		["box", Vector3(2 * h, SHAFT_D, 0.04), Vector3(0, -SHAFT_D * 0.5, -h - 0.02), dark],
		["box", Vector3(2 * h, SHAFT_D, 0.04), Vector3(0, -SHAFT_D * 0.5, h + 0.02), dark],
		["box", Vector3(0.04, SHAFT_D, 2 * h), Vector3(-h - 0.02, -SHAFT_D * 0.5, 0), dark],
		["box", Vector3(0.04, SHAFT_D, 2 * h), Vector3(h + 0.02, -SHAFT_D * 0.5, 0), dark],
		["box", Vector3(2 * h, 0.04, 2 * h), Vector3(0, -SHAFT_D, 0), Color("#3b3328")],
		# Ladder on the far side.
		["box", Vector3(0.04, SHAFT_D, 0.04), Vector3(-0.2, -SHAFT_D * 0.5 + 0.1, -h + 0.08), metal],
		["box", Vector3(0.04, SHAFT_D, 0.04), Vector3(0.2, -SHAFT_D * 0.5 + 0.1, -h + 0.08), metal],
	]
	for k in range(8):
		parts.append(["box", Vector3(0.4, 0.03, 0.03), Vector3(0, -0.15 - float(k) * 0.32, -h + 0.08), metal])
	var mi := MeshInstance3D.new()
	mi.name = "HatchFrame"
	mi.mesh = PropLibrary.merged_mesh(parts)
	mi.material_override = PropLibrary.vertex_color_material()
	n.add_child(mi)
	# The lid, propped open on its hinge at the far edge, with the wheel.
	var lid := MeshInstance3D.new()
	lid.name = "HatchLid"
	lid.mesh = PropLibrary.merged_mesh([
		["box", Vector3(2 * h + 0.06, 0.06, 2 * h + 0.06), Vector3(0, 0.03, h + 0.03), Color("#6f7780")],
		["torus", Vector3(0.14, 0.18, 0), Vector3(0, 0.08, h + 0.03), Color("#c84b31")],
		["box", Vector3(0.36, 0.02, 0.03), Vector3(0, 0.08, h + 0.03), Color("#c84b31")],
		["box", Vector3(0.03, 0.02, 0.36), Vector3(0, 0.08, h + 0.03), Color("#c84b31")],
		["torus", Vector3(0.14, 0.18, 0), Vector3(0, -0.02, h + 0.03), Color("#c84b31")],
		["box", Vector3(0.36, 0.02, 0.03), Vector3(0, -0.02, h + 0.03), Color("#c84b31")],
	])
	lid.material_override = PropLibrary.vertex_color_material()
	lid.position = Vector3(0, 0.05, -h - 0.03)
	lid.rotation.x = deg_to_rad(-100.0)
	n.add_child(lid)
	var glow := OmniLight3D.new()
	glow.name = "ShelterGlow"
	glow.position = Vector3(0, -SHAFT_D + 0.5, 0)
	glow.light_color = Color(1.0, 0.7, 0.35)
	glow.light_energy = 2.2
	glow.omni_range = 3.6
	n.add_child(glow)
	return n


# ------------------------------------------------------------------------------
# Materials (shared)
# ------------------------------------------------------------------------------

static func surface_material(kind: String) -> StandardMaterial3D:
	var key: String = "floor_" + kind
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var tex: String = SURF + kind + "_color.jpg"
	var nrm: String = SURF + kind + "_normal.jpg"
	if ResourceLoader.exists(tex):
		m.albedo_texture = load(tex)
	if ResourceLoader.exists(nrm):
		m.normal_enabled = true
		m.normal_texture = load(nrm)
		m.normal_scale = 0.6
	m.roughness = 0.72 if kind != "tiles" else 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


static func wall_material() -> StandardMaterial3D:
	if _mats.has("wall"):
		return _mats["wall"]
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(SURF + "plaster_color.jpg"):
		m.albedo_texture = load(SURF + "plaster_color.jpg")
	m.albedo_color = Color(1.0, 1.0, 1.0)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats["wall"] = m
	return m


static func trim_material() -> StandardMaterial3D:
	if _mats.has("trim"):
		return _mats["trim"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.94, 0.9)
	m.roughness = 0.55
	_mats["trim"] = m
	return m


static func ceiling_material() -> StandardMaterial3D:
	if _mats.has("ceiling"):
		return _mats["ceiling"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.85, 0.82)
	m.roughness = 0.95
	_mats["ceiling"] = m
	return m


## Dusk sky through the glass: an emissive gradient, no transparency (cheap on the web).
static func window_material() -> StandardMaterial3D:
	if _mats.has("window"):
		return _mats["window"]
	var g := Gradient.new()
	g.set_color(0, Color(0.16, 0.22, 0.36))
	g.set_color(1, Color(0.78, 0.5, 0.34))
	g.add_point(0.7, Color(0.45, 0.42, 0.5))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 8
	t.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = t
	m.albedo_color = Color(0.9, 0.9, 0.95)
	_mats["window"] = m
	return m


# ------------------------------------------------------------------------------
# Geometry helpers
# ------------------------------------------------------------------------------

static func _room_at(rooms: Array, p: Vector2) -> int:
	for i in range(rooms.size()):
		var poly: PackedVector2Array = rooms[i]["poly"]
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
			return i
	return -1


static func _room_for_point(rooms: Array, p: Vector2) -> Dictionary:
	var i: int = _room_at(rooms, p)
	if i >= 0:
		return rooms[i]
	var best: int = 0
	var best_d: float = 1e20
	for k in range(rooms.size()):
		var d: float = p.distance_to(rooms[k]["center"])
		if d < best_d:
			best_d = d
			best = k
	return rooms[best]


## Interior walls belong to the room on one side (the first room found probing either side).
static func _room_for_wall(rooms: Array, c: Vector2, horiz: bool) -> Dictionary:
	var off: Vector2 = Vector2(0.0, 12.0) if horiz else Vector2(12.0, 0.0)
	for p in [c + off, c - off]:
		var i: int = _room_at(rooms, p)
		if i >= 0 and not bool(rooms[i]["sealed"]):
			return rooms[i]
	return _room_for_point(rooms, c + off)


static func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _segment_hits_rect(p0: Vector2, p1: Vector2, r: Rect2) -> bool:
	if r.has_point(p0) or r.has_point(p1):
		return true
	var corners: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(p0, p1, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false
