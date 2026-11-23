class_name House3DBuilder
extends RefCounted

## Procedural Mid-Century 1950s Isometric 3D House, Furniture, Bunker Hatch,
## Custom Articulated Survivor, and Supply Prop Builder for "60 Seconds: World Reatomized".
## Maps verified 2D HouseGenerator coordinates (px, py) directly to 3D (px * SCALE_3D, y, py * SCALE_3D)
## so 100% of BFS walkability, collision radii, and AI pathfinding remain exact.

const SCALE_3D: float = 0.025 # 46 px = 1.15m
const FLOOR_TOP_Y: float = 0.04
const FLOOR_THICK: float = 0.06
const WALL_TALL_H: float = 2.30
const WALL_CUTAWAY_H: float = 0.52

# Mid-Century CONELRAD Palette
const COL_PARCHMENT := Color("#f2e6ce")
const COL_PARCHMENT_DARK := Color("#d8c6a2")
const COL_HAZARD_YELLOW := Color("#f5be2e")
const COL_ATOMIC_ORANGE := Color("#e05a2b")
const COL_ALERT_RED := Color("#d9442a")
const COL_SLATE := Color("#232824")
const COL_INK := Color("#1b1917")
const COL_OLIVE := Color("#556843")
const COL_STEEL := Color("#9ca6a2")
const COL_STEEL_DARK := Color("#4c5550")
const COL_CHROME := Color("#dde5e7")
const COL_WALNUT := Color("#6e4526")
const COL_WALNUT_LIGHT := Color("#9d6a3e")
const COL_WALNUT_DARK := Color("#442915")
const COL_WATER_BLUE := Color("#3b8ec2")
const COL_TOXIC_GREEN := Color("#7ec850")


static func to_3d(pos_2d: Vector2, y_height: float = FLOOR_TOP_Y) -> Vector3:
	return Vector3(pos_2d.x * SCALE_3D, y_height, pos_2d.y * SCALE_3D)


static func to_2d(pos_3d: Vector3) -> Vector2:
	return Vector2(pos_3d.x / SCALE_3D, pos_3d.z / SCALE_3D)


static func _safe_color(val: Variant, fallback: Color) -> Color:
	if val is Color:
		return val
	if val is String:
		var s: String = val
		if not s.is_empty() and Color.html_is_valid(s):
			return Color(s)
	return fallback


static func _make_mat(
	albedo: Color,
	rough: float = 0.76,
	metal: float = 0.04,
	emit_col: Color = Color.BLACK,
	emit_energy: float = 0.0,
	alpha: float = 1.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var c := albedo
	c.a = alpha
	mat.albedo_color = c
	mat.roughness = clampf(rough, 0.05, 1.0)
	mat.metallic = clampf(metal, 0.0, 1.0)
	if alpha < 0.995:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_energy > 0.001:
		mat.emission_enabled = true
		mat.emission = emit_col
		mat.emission_energy_multiplier = emit_energy
	return mat


static func _is_dummy_renderer() -> bool:
	return DisplayServer.get_name() == "headless"


static func _add_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	cast_shad: bool = true
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not _is_dummy_renderer():
		var bm := BoxMesh.new()
		bm.size = Vector3(maxf(0.004, size.x), maxf(0.004, size.y), maxf(0.004, size.z))
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shad else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _add_cyl(
	parent: Node3D,
	top_r: float,
	bot_r: float,
	height: float,
	pos: Vector3,
	mat: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	radial_segs: int = 18,
	cast_shad: bool = true
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not _is_dummy_renderer():
		var cm := CylinderMesh.new()
		cm.top_radius = maxf(0.002, top_r)
		cm.bottom_radius = maxf(0.002, bot_r)
		cm.height = maxf(0.004, height)
		cm.radial_segments = maxi(6, radial_segs)
		mi.mesh = cm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shad else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _add_sphere(
	parent: Node3D,
	radius: float,
	pos: Vector3,
	mat: Material,
	scale_vec: Vector3 = Vector3.ONE,
	cast_shad: bool = true
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not _is_dummy_renderer():
		var sm := SphereMesh.new()
		sm.radius = maxf(0.004, radius)
		sm.height = maxf(0.008, radius * 2.0)
		sm.radial_segments = 16
		sm.rings = 10
		mi.mesh = sm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shad else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = scale_vec
	parent.add_child(mi)
	return mi


static func _add_capsule(
	parent: Node3D,
	radius: float,
	height: float,
	pos: Vector3,
	mat: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	cast_shad: bool = true
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not _is_dummy_renderer():
		var cap := CapsuleMesh.new()
		cap.radius = maxf(0.004, radius)
		cap.height = maxf(cap.radius * 2.02, height)
		cap.radial_segments = 14
		cap.rings = 6
		mi.mesh = cap
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shad else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _add_prism(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	rot_deg: Vector3 = Vector3.ZERO,
	left_to_right: float = 0.5,
	cast_shad: bool = true
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not _is_dummy_renderer():
		var pm := PrismMesh.new()
		pm.size = Vector3(maxf(0.004, size.x), maxf(0.004, size.y), maxf(0.004, size.z))
		pm.left_to_right = left_to_right
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shad else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


# ==============================================================================
# PROCEDURAL FLOOR TEXTURES (1950s MID-CENTURY TILES, PLANKS & LINOLEUM)
# ==============================================================================

static func _get_floor_texture(style_key: String, headless: bool, tex_cache: Dictionary) -> Texture2D:
	if headless or _is_dummy_renderer():
		return null
	if tex_cache.has(style_key):
		return tex_cache[style_key]

	var sz: int = 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)

	match style_key:
		"kitchen":
			var c_cream := Color("#ece0c5")
			var c_terra := Color("#c05034")
			var c_grout := Color("#9e8f76")
			var tile_px: int = 32
			for y in range(sz):
				for x in range(sz):
					var tx: int = x / tile_px
					var ty: int = y / tile_px
					var edge: bool = (x % tile_px == 0) or (y % tile_px == 0)
					if edge:
						img.set_pixel(x, y, c_grout)
					else:
						var base_c: Color = c_cream if ((tx + ty) % 2 == 0) else c_terra
						if ((x + y * 3) % 19) == 0:
							base_c = base_c.darkened(0.05)
						img.set_pixel(x, y, base_c)

		"bathroom":
			var c_aqua_a := Color("#b6dad4")
			var c_aqua_b := Color("#98c4bd")
			var c_grout_b := Color("#628a84")
			var c_dot := Color("#3f726c")
			var step_b: int = 16
			for y in range(sz):
				for x in range(sz):
					var gx: int = x % step_b
					var gy: int = y % step_b
					if gx == 0 or gy == 0:
						img.set_pixel(x, y, c_grout_b)
					elif gx <= 2 and gy <= 2:
						img.set_pixel(x, y, c_dot)
					else:
						var bx: int = x / step_b
						var by: int = y / step_b
						img.set_pixel(x, y, c_aqua_a if ((bx + by) % 2 == 0) else c_aqua_b)

		"living":
			var planks: Array[Color] = [
				Color("#c9935b"),
				Color("#bc844c"),
				Color("#d39f67"),
				Color("#b57d46")
			]
			var seam_c := Color("#784d27")
			var plank_h: int = 16
			for y in range(sz):
				var row: int = y / plank_h
				var py: int = y % plank_h
				var joint_x: int = (row * 47) % sz
				for x in range(sz):
					if py == 0 or x == joint_x:
						img.set_pixel(x, y, seam_c)
					else:
						var col_idx: int = (row + (1 if x > joint_x else 0)) % planks.size()
						var grain: float = sin(float(x) * 0.22 + float(row) * 1.7) * 0.03
						var pc: Color = planks[col_idx]
						img.set_pixel(x, y, Color(
							clampf(pc.r + grain, 0.0, 1.0),
							clampf(pc.g + grain, 0.0, 1.0),
							clampf(pc.b + grain * 0.6, 0.0, 1.0),
							1.0
						))

		"master_bed":
			var base_mb := Color("#ccb094")
			var weave_mb := Color("#bfa183")
			for y in range(sz):
				for x in range(sz):
					var pat: bool = ((x / 2 + y / 2) % 2 == 0)
					var c_m: Color = base_mb if pat else weave_mb
					if (x % 8 == 0) and (y % 4 == 0):
						c_m = c_m.lightened(0.05)
					img.set_pixel(x, y, c_m)

		"kids_bed":
			var base_kb := Color("#d8be92")
			var weave_kb := Color("#cbb082")
			for y in range(sz):
				for x in range(sz):
					var pat_k: bool = (((x + y) / 3) % 2 == 0)
					img.set_pixel(x, y, base_kb if pat_k else weave_kb)

		"lawn":
			var g_a := Color("#2d3c27")
			var g_b := Color("#263321")
			for y in range(sz):
				for x in range(sz):
					var stripe: bool = ((x / 32) % 2 == 0)
					var gc: Color = g_a if stripe else g_b
					if ((x * 7 + y * 13) % 17) == 0:
						gc = gc.lightened(0.06)
					img.set_pixel(x, y, gc)

		_:
			# Central Hall terrazzo linoleum
			var hall_base := Color("#d8c8a6")
			var hall_grid := Color("#b4a282")
			var fleck_gold := Color("#c99124")
			var fleck_red := Color("#bf5232")
			for y in range(sz):
				for x in range(sz):
					if (x % 32 == 0) or (y % 32 == 0):
						img.set_pixel(x, y, hall_grid)
					else:
						var h: int = (x * 37 + y * 91) % 97
						if h == 3:
							img.set_pixel(x, y, fleck_gold)
						elif h == 19:
							img.set_pixel(x, y, fleck_red)
						else:
							img.set_pixel(x, y, hall_base)

	var tex := ImageTexture.create_from_image(img)
	tex_cache[style_key] = tex
	return tex


static func _make_floor_mat(style_key: String, tint: Color, size_x_m: float, size_z_m: float, repeat_m: float, headless: bool, tex_cache: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = _get_floor_texture(style_key, headless, tex_cache)
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE.lerp(tint, 0.18)
		mat.uv1_scale = Vector3(maxf(1.0, size_x_m / repeat_m), maxf(1.0, size_z_m / repeat_m), 1.0)
	else:
		mat.albedo_color = tint
	mat.roughness = 0.72 if style_key in ["kitchen", "bathroom", "hall"] else 0.88
	mat.metallic = 0.04
	return mat


# ==============================================================================
# FULL 3D HOUSE DIORAMA BUILDER
# ==============================================================================

static func build_house_world(layout: Dictionary, headless: bool = false) -> Dictionary:
	var root := Node3D.new()
	root.name = "HouseWorld3D"

	var raw_bounds: Variant = layout.get("bounds", Rect2(-360.0, -280.0, 720.0, 560.0))
	var bounds: Rect2 = raw_bounds if raw_bounds is Rect2 else Rect2(-360.0, -280.0, 720.0, 560.0)
	var raw_int_bounds: Variant = layout.get("interior_bounds", bounds.grow(-16.0))
	var interior_bounds: Rect2 = raw_int_bounds if raw_int_bounds is Rect2 else bounds.grow(-16.0)

	var tex_cache: Dictionary = {}

	# 1. Suburban Exterior Yard, Sidewalk Plinth & Curb Landscaping
	_build_exterior_yard(root, bounds, layout.get("rooms", []), headless, tex_cache)

	# 2. Thematic Room Floors & Woven Area Rugs
	_build_room_floors(root, layout.get("rooms", []), layout.get("hatch_pos", Vector2.ZERO), headless, tex_cache)

	# 3. Smart Isometric Cutaway Walls & Doorway Thresholds
	_build_cutaway_walls(
		root,
		layout.get("walls", []),
		layout.get("doorways", []),
		interior_bounds
	)

	# 4. Mid-Century 3D Furniture Props (indexed so bumping physically shakes/tilts them)
	var furniture_nodes: Dictionary = {}
	var furn_root := Node3D.new()
	furn_root.name = "FurnitureRoot"
	root.add_child(furn_root)

	var raw_furn: Variant = layout.get("furniture", [])
	if raw_furn is Array:
		var furn_arr: Array = raw_furn
		for idx in range(furn_arr.size()):
			var f_var: Variant = furn_arr[idx]
			if f_var is Dictionary:
				var f_node: Node3D = build_furniture_prop(f_var)
				furn_root.add_child(f_node)
				furniture_nodes[idx] = f_node

	# 5. Central Fallout Bunker Hatch
	var raw_hp: Variant = layout.get("hatch_pos", bounds.get_center())
	var hatch_pos: Vector2 = raw_hp if raw_hp is Vector2 else bounds.get_center()
	var hatch_radius: float = float(layout.get("hatch_radius", 52.0))
	var hatch_nodes: Dictionary = build_bunker_hatch(hatch_pos, hatch_radius)
	var h_root: Node3D = hatch_nodes["root"]
	root.add_child(h_root)

	return {
		"root": root,
		"furniture_nodes": furniture_nodes,
		"hatch_nodes": hatch_nodes
	}


static func _build_exterior_yard(root: Node3D, bounds: Rect2, rooms: Array, headless: bool, tex_cache: Dictionary) -> void:
	var yard_node := Node3D.new()
	yard_node.name = "ExteriorYard"
	root.add_child(yard_node)

	var yard_rect: Rect2 = bounds.grow(1100.0)
	var y_w: float = yard_rect.size.x * SCALE_3D
	var y_d: float = yard_rect.size.y * SCALE_3D
	var y_c: Vector2 = yard_rect.get_center()

	var lawn_mat: StandardMaterial3D = _make_floor_mat("lawn", Color("#2a3825"), y_w, y_d, 4.2, headless, tex_cache)
	_add_box(
		yard_node,
		Vector3(y_w, 0.12, y_d),
		Vector3(y_c.x * SCALE_3D, -0.09, y_c.y * SCALE_3D),
		lawn_mat,
		Vector3.ZERO,
		false
	)

	# Concrete perimeter sidewalk & foundation slab under each room
	var concrete_mat: StandardMaterial3D = _make_mat(Color("#8c8577"), 0.90, 0.02)
	var curb_mat: StandardMaterial3D = _make_mat(Color("#aba393"), 0.86, 0.02)
	if rooms.is_empty():
		var b_pad: Rect2 = bounds.grow(24.0)
		_add_box(
			yard_node,
			Vector3(b_pad.size.x * SCALE_3D, 0.06, b_pad.size.y * SCALE_3D),
			Vector3(b_pad.get_center().x * SCALE_3D, -0.02, b_pad.get_center().y * SCALE_3D),
			concrete_mat,
			Vector3.ZERO,
			false
		)
	else:
		for r_var in rooms:
			if not (r_var is Dictionary):
				continue
			var rd: Dictionary = r_var
			var rr: Rect2 = rd.get("rect", Rect2()) if rd.get("rect") is Rect2 else Rect2()
			if rr.size.x <= 1.0 or rr.size.y <= 1.0:
				continue
			var apron: Rect2 = rr.grow(28.0)
			_add_box(
				yard_node,
				Vector3(apron.size.x * SCALE_3D, 0.055, apron.size.y * SCALE_3D),
				Vector3(apron.get_center().x * SCALE_3D, -0.022, apron.get_center().y * SCALE_3D),
				concrete_mat,
				Vector3.ZERO,
				false
			)

	# Front concrete garden walkway stepping stones on South (+Z) side
	var south_z: float = (bounds.end.y + 42.0) * SCALE_3D
	var walk_x: float = bounds.get_center().x * SCALE_3D
	for s_i in range(6):
		_add_box(
			yard_node,
			Vector3(1.15, 0.04, 0.62),
			Vector3(walk_x, -0.015, south_z + float(s_i) * 0.85),
			curb_mat,
			Vector3.ZERO,
			false
		)

	# Subtle suburban shrubs & retro mailbox outside perimeter (never blocking interior)
	var shrub_mat: StandardMaterial3D = _make_mat(Color("#3b5531"), 0.88, 0.0)
	var shrub_light_mat: StandardMaterial3D = _make_mat(Color("#4c6b3d"), 0.86, 0.0)
	var flower_mat: StandardMaterial3D = _make_mat(COL_HAZARD_YELLOW, 0.7, 0.0)
	var corner_pts: Array[Vector2] = [
		Vector2(bounds.position.x - 46.0, bounds.position.y - 36.0),
		Vector2(bounds.end.x + 46.0, bounds.position.y - 36.0),
		Vector2(bounds.position.x - 46.0, bounds.end.y + 44.0),
		Vector2(bounds.end.x + 46.0, bounds.end.y + 44.0)
	]
	for cp in corner_pts:
		var p3: Vector3 = to_3d(cp, 0.18)
		_add_sphere(yard_node, 0.34, p3, shrub_mat, Vector3(1.2, 0.85, 1.1))
		_add_sphere(yard_node, 0.24, p3 + Vector3(0.28, -0.03, 0.14), shrub_light_mat)
		_add_sphere(yard_node, 0.07, p3 + Vector3(0.08, 0.22, 0.08), flower_mat, Vector3.ONE, false)

	# 1950s US Mail Postbox by front walkway
	var mb_pos := Vector3(walk_x + 1.15, 0.0, south_z + 1.6)
	var wood_post_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.8, 0.02)
	var steel_box_mat: StandardMaterial3D = _make_mat(Color("#384c5e"), 0.45, 0.45)
	var flag_mat: StandardMaterial3D = _make_mat(COL_ALERT_RED, 0.5, 0.1)
	_add_box(yard_node, Vector3(0.09, 0.78, 0.09), mb_pos + Vector3(0.0, 0.39, 0.0), wood_post_mat)
	_add_box(yard_node, Vector3(0.24, 0.18, 0.42), mb_pos + Vector3(0.0, 0.82, 0.0), steel_box_mat)
	_add_cyl(yard_node, 0.12, 0.12, 0.42, mb_pos + Vector3(0.0, 0.91, 0.0), steel_box_mat, Vector3(90.0, 0.0, 0.0), 12)
	_add_box(yard_node, Vector3(0.025, 0.16, 0.06), mb_pos + Vector3(0.13, 0.92, 0.08), flag_mat)


static func _build_room_floors(root: Node3D, rooms: Array, hatch_pos: Vector2, headless: bool, tex_cache: Dictionary) -> void:
	var floors_node := Node3D.new()
	floors_node.name = "RoomFloors"
	root.add_child(floors_node)

	for r_var in rooms:
		if not (r_var is Dictionary):
			continue
		var rd: Dictionary = r_var
		var r_rect: Rect2 = rd.get("rect", Rect2()) if rd.get("rect") is Rect2 else Rect2()
		if r_rect.size.x <= 1.0 or r_rect.size.y <= 1.0:
			continue

		var r_name: String = str(rd.get("name", "Room"))
		var low_name: String = r_name.to_lower()
		var style_key: String = "hall"
		var repeat_m: float = 1.6
		var base_col := Color("#dfd2b5")

		if low_name.find("kitchen") >= 0:
			style_key = "kitchen"
			repeat_m = 1.45
			base_col = Color("#eee4cc")
		elif low_name.find("bath") >= 0:
			style_key = "bathroom"
			repeat_m = 1.25
			base_col = Color("#c5deda")
		elif low_name.find("living") >= 0:
			style_key = "living"
			repeat_m = 1.9
			base_col = Color("#c49058")
		elif low_name.find("master") >= 0:
			style_key = "master_bed"
			repeat_m = 1.6
			base_col = Color("#cbb094")
		elif low_name.find("kid") >= 0 or low_name.find("bed") >= 0:
			style_key = "kids_bed"
			repeat_m = 1.6
			base_col = Color("#d8be92")

		var sx: float = r_rect.size.x * SCALE_3D
		var sz: float = r_rect.size.y * SCALE_3D
		var rc: Vector2 = r_rect.get_center()
		var f_mat: StandardMaterial3D = _make_floor_mat(style_key, base_col, sx, sz, repeat_m, headless, tex_cache)

		_add_box(
			floors_node,
			Vector3(sx, FLOOR_THICK, sz),
			Vector3(rc.x * SCALE_3D, FLOOR_TOP_Y - FLOOR_THICK * 0.5, rc.y * SCALE_3D),
			f_mat,
			Vector3.ZERO,
			false
		)

		# Decorative 3D woven mid-century area rug if room has rug_rect clear of Bunker Hatch
		var raw_rug: Variant = rd.get("rug_rect", Rect2())
		if raw_rug is Rect2:
			var rug_r: Rect2 = raw_rug
			if rug_r.size.x > 36.0 and rug_r.size.y > 36.0 and not rug_r.grow(36.0).has_point(hatch_pos):
				var accent_c: Color = _safe_color(rd.get("accent_color", null), Color("#a84a32"))
				var rug_mat: StandardMaterial3D = _make_mat(accent_c, 0.94, 0.0)
				var rug_trim_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.92, 0.0)
				var rug_center: Vector2 = rug_r.get_center()
				var rw: float = rug_r.size.x * SCALE_3D
				var rdz: float = rug_r.size.y * SCALE_3D
				_add_box(
					floors_node,
					Vector3(rw + 0.08, 0.008, rdz + 0.08),
					Vector3(rug_center.x * SCALE_3D, FLOOR_TOP_Y + 0.004, rug_center.y * SCALE_3D),
					rug_trim_mat,
					Vector3.ZERO,
					false
				)
				_add_box(
					floors_node,
					Vector3(rw, 0.011, rdz),
					Vector3(rug_center.x * SCALE_3D, FLOOR_TOP_Y + 0.006, rug_center.y * SCALE_3D),
					rug_mat,
					Vector3.ZERO,
					false
				)


# ==============================================================================
# TRUE ISOMETRIC CUTAWAY WALLS + DOORWAYS
# ==============================================================================

static func _build_cutaway_walls(
	root: Node3D,
	walls: Array,
	doorways: Array,
	interior_bounds: Rect2
) -> void:
	var walls_node := Node3D.new()
	walls_node.name = "CutawayWalls"
	root.add_child(walls_node)

	var ext_tall_mat: StandardMaterial3D = _make_mat(Color("#ded1b6"), 0.84, 0.02)
	var ext_siding_mat: StandardMaterial3D = _make_mat(Color("#5c4a3c"), 0.86, 0.02)
	var cutaway_body_mat: StandardMaterial3D = _make_mat(Color("#cfc0a3"), 0.82, 0.02)
	var cutaway_ext_mat: StandardMaterial3D = _make_mat(Color("#4c433a"), 0.85, 0.02)
	var cap_dark_mat: StandardMaterial3D = _make_mat(COL_INK, 0.70, 0.05)
	var trim_wood_mat: StandardMaterial3D = _make_mat(COL_WALNUT, 0.68, 0.04)
	var baseboard_mat: StandardMaterial3D = _make_mat(COL_WALNUT_DARK, 0.72, 0.04)
	var window_frame_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.65, 0.04)
	var window_glass_mat: StandardMaterial3D = _make_mat(
		Color("#6898b8"), 0.22, 0.25, Color("#ffd599"), 0.35, 0.88
	)
	var curtain_mat: StandardMaterial3D = _make_mat(COL_ATOMIC_ORANGE, 0.88, 0.0)

	var north_y: float = interior_bounds.position.y
	var west_x: float = interior_bounds.position.x
	var poster_placed: bool = false

	for w_var in walls:
		var w_rect := Rect2()
		var is_ext: bool = false
		if w_var is Rect2:
			w_rect = w_var
		elif w_var is Dictionary:
			var wd: Dictionary = w_var
			if wd.get("rect") is Rect2:
				w_rect = wd["rect"]
			is_ext = bool(wd.get("is_exterior", wd.get("outer", false)))

		if w_rect.size.x <= 0.5 or w_rect.size.y <= 0.5:
			continue

		var wc: Vector2 = w_rect.get_center()
		var is_horiz: bool = w_rect.size.x >= w_rect.size.y

		# Mathematical non-occlusion rule for Camera3D(-48, +32, 0):
		# Camera sits in South-East (+X, +Y, +Z) looking North-West (-X, -Y, -Z).
		# ONLY outer perimeter walls on the true Northmost (min_y) or Westmost (min_x) edges
		# stand tall (2.30m); all interior partitions and South/East/L-notch walls use 0.52m cutaway!
		var is_tall_back: bool = false
		if is_ext:
			if is_horiz and absf(wc.y - north_y) <= 18.0:
				is_tall_back = true
			elif (not is_horiz) and absf(wc.x - west_x) <= 18.0:
				is_tall_back = true

		var sx: float = w_rect.size.x * SCALE_3D
		var sz: float = w_rect.size.y * SCALE_3D
		var cx: float = wc.x * SCALE_3D
		var cz: float = wc.y * SCALE_3D

		if is_tall_back:
			var body_h: float = WALL_TALL_H - 0.06
			_add_box(
				walls_node,
				Vector3(sx, body_h, sz),
				Vector3(cx, FLOOR_TOP_Y + body_h * 0.5, cz),
				ext_tall_mat
			)
			# Outer brick/clapboard backing strip
			if is_horiz:
				_add_box(
					walls_node,
					Vector3(sx + 0.01, body_h, 0.06),
					Vector3(cx, FLOOR_TOP_Y + body_h * 0.5, cz - sz * 0.42),
					ext_siding_mat
				)
			else:
				_add_box(
					walls_node,
					Vector3(0.06, body_h, sz + 0.01),
					Vector3(cx - sx * 0.42, FLOOR_TOP_Y + body_h * 0.5, cz),
					ext_siding_mat
				)

			# Baseboard + Mid-wall Wainscot Chair Rail + Architectural Cut-Top Cap
			_add_box(
				walls_node,
				Vector3(sx + 0.025, 0.11, sz + 0.025),
				Vector3(cx, FLOOR_TOP_Y + 0.055, cz),
				baseboard_mat,
				Vector3.ZERO,
				false
			)
			_add_box(
				walls_node,
				Vector3(sx + 0.02, 0.05, sz + 0.02),
				Vector3(cx, FLOOR_TOP_Y + 0.88, cz),
				trim_wood_mat,
				Vector3.ZERO,
				false
			)
			_add_box(
				walls_node,
				Vector3(sx + 0.03, 0.06, sz + 0.03),
				Vector3(cx, FLOOR_TOP_Y + WALL_TALL_H - 0.03, cz),
				cap_dark_mat
			)

			# Add 1950s framed window or CONELRAD poster on long back wall segments
			var span_m: float = sx if is_horiz else sz
			if span_m >= 2.4:
				var win_w: float = minf(1.45, span_m * 0.44)
				var win_h: float = 0.86
				var win_y: float = FLOOR_TOP_Y + 1.42
				if is_horiz:
					var iz: float = cz + sz * 0.5 + 0.012
					_add_box(walls_node, Vector3(win_w + 0.12, win_h + 0.12, 0.04), Vector3(cx, win_y, iz), window_frame_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(win_w, win_h, 0.05), Vector3(cx, win_y, iz + 0.005), window_glass_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(win_w, 0.035, 0.06), Vector3(cx, win_y, iz + 0.01), window_frame_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(0.035, win_h, 0.06), Vector3(cx, win_y, iz + 0.01), window_frame_mat, Vector3.ZERO, false)
					# Curtains
					_add_box(walls_node, Vector3(0.16, win_h + 0.14, 0.065), Vector3(cx - win_w * 0.5 - 0.05, win_y, iz + 0.015), curtain_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(0.16, win_h + 0.14, 0.065), Vector3(cx + win_w * 0.5 + 0.05, win_y, iz + 0.015), curtain_mat, Vector3.ZERO, false)
				else:
					var ix: float = cx + sx * 0.5 + 0.012
					_add_box(walls_node, Vector3(0.04, win_h + 0.12, win_w + 0.12), Vector3(ix, win_y, cz), window_frame_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(0.05, win_h, win_w), Vector3(ix + 0.005, win_y, cz), window_glass_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(0.06, 0.035, win_w), Vector3(ix + 0.01, win_y, cz), window_frame_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(0.06, win_h, 0.035), Vector3(ix + 0.01, win_y, cz), window_frame_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(0.065, win_h + 0.14, 0.16), Vector3(ix + 0.015, win_y, cz - win_w * 0.5 - 0.05), curtain_mat, Vector3.ZERO, false)
					_add_box(walls_node, Vector3(0.065, win_h + 0.14, 0.16), Vector3(ix + 0.015, win_y, cz + win_w * 0.5 + 0.05), curtain_mat, Vector3.ZERO, false)
			elif not poster_placed and span_m >= 1.3 and is_horiz:
				poster_placed = true
				var post_z: float = cz + sz * 0.5 + 0.015
				var yel_mat: StandardMaterial3D = _make_mat(COL_HAZARD_YELLOW, 0.65, 0.02)
				_add_box(walls_node, Vector3(0.52, 0.68, 0.025), Vector3(cx, FLOOR_TOP_Y + 1.45, post_z), cap_dark_mat, Vector3.ZERO, false)
				_add_box(walls_node, Vector3(0.44, 0.58, 0.03), Vector3(cx, FLOOR_TOP_Y + 1.45, post_z + 0.004), yel_mat, Vector3.ZERO, false)
		else:
			# Smart 0.52m Cutaway Wainscot Wall
			var cut_h: float = WALL_CUTAWAY_H - 0.045
			var body_m: StandardMaterial3D = cutaway_ext_mat if is_ext else cutaway_body_mat
			_add_box(
				walls_node,
				Vector3(sx, cut_h, sz),
				Vector3(cx, FLOOR_TOP_Y + cut_h * 0.5, cz),
				body_m
			)
			_add_box(
				walls_node,
				Vector3(sx + 0.02, 0.075, sz + 0.02),
				Vector3(cx, FLOOR_TOP_Y + 0.038, cz),
				baseboard_mat,
				Vector3.ZERO,
				false
			)
			# Crisp architectural cross-section top cap (wood trim + dark ink core)
			_add_box(
				walls_node,
				Vector3(sx + 0.026, 0.032, sz + 0.026),
				Vector3(cx, FLOOR_TOP_Y + WALL_CUTAWAY_H - 0.028, cz),
				trim_wood_mat,
				Vector3.ZERO,
				false
			)
			_add_box(
				walls_node,
				Vector3(maxf(0.02, sx - 0.03), 0.024, maxf(0.02, sz - 0.03)),
				Vector3(cx, FLOOR_TOP_Y + WALL_CUTAWAY_H - 0.008, cz),
				cap_dark_mat,
				Vector3.ZERO,
				false
			)

	# Doorway brass/oak thresholds & crisp jamb posts so every doorway gap reads cleanly
	var thresh_mat: StandardMaterial3D = _make_mat(Color("#c49a52"), 0.52, 0.32)
	for dw_var in doorways:
		if not (dw_var is Dictionary):
			continue
		var dw: Dictionary = dw_var
		var d_rect: Rect2 = dw.get("rect", Rect2()) if dw.get("rect") is Rect2 else Rect2()
		if d_rect.size.x <= 1.0 or d_rect.size.y <= 1.0:
			continue
		var dc: Vector2 = d_rect.get_center()
		var dsx: float = d_rect.size.x * SCALE_3D
		var dsz: float = d_rect.size.y * SCALE_3D
		_add_box(
			walls_node,
			Vector3(dsx, 0.012, dsz),
			Vector3(dc.x * SCALE_3D, FLOOR_TOP_Y + 0.006, dc.y * SCALE_3D),
			thresh_mat,
			Vector3.ZERO,
			false
		)
		var horiz_dw: bool = bool(dw.get("horizontal", dsx >= dsz))
		if horiz_dw:
			_add_box(walls_node, Vector3(0.06, WALL_CUTAWAY_H + 0.02, dsz + 0.05), Vector3((dc.x - d_rect.size.x * 0.5) * SCALE_3D, FLOOR_TOP_Y + WALL_CUTAWAY_H * 0.5, dc.y * SCALE_3D), trim_wood_mat, Vector3.ZERO, false)
			_add_box(walls_node, Vector3(0.06, WALL_CUTAWAY_H + 0.02, dsz + 0.05), Vector3((dc.x + d_rect.size.x * 0.5) * SCALE_3D, FLOOR_TOP_Y + WALL_CUTAWAY_H * 0.5, dc.y * SCALE_3D), trim_wood_mat, Vector3.ZERO, false)
		else:
			_add_box(walls_node, Vector3(dsx + 0.05, WALL_CUTAWAY_H + 0.02, 0.06), Vector3(dc.x * SCALE_3D, FLOOR_TOP_Y + WALL_CUTAWAY_H * 0.5, (dc.y - d_rect.size.y * 0.5) * SCALE_3D), trim_wood_mat, Vector3.ZERO, false)
			_add_box(walls_node, Vector3(dsx + 0.05, WALL_CUTAWAY_H + 0.02, 0.06), Vector3(dc.x * SCALE_3D, FLOOR_TOP_Y + WALL_CUTAWAY_H * 0.5, (dc.y + d_rect.size.y * 0.5) * SCALE_3D), trim_wood_mat, Vector3.ZERO, false)


# ==============================================================================
# 3D MID-CENTURY FURNITURE PROPS
# ==============================================================================

static func build_furniture_prop(prop: Dictionary) -> Node3D:
	var pivot := Node3D.new()
	var f_rect: Rect2 = prop.get("rect", Rect2(0, 0, 48, 32)) if prop.get("rect") is Rect2 else Rect2(0, 0, 48, 32)
	var kind: String = str(prop.get("kind", prop.get("type", "table"))).to_lower()
	var col: Color = _safe_color(prop.get("color", null), Color("#8c5c38"))
	var accent: Color = _safe_color(prop.get("accent_color", null), COL_PARCHMENT)

	var center_2d: Vector2 = f_rect.get_center()
	pivot.position = to_3d(center_2d, FLOOR_TOP_Y)

	# Align local X along longer horizontal dimension so rotated wall placements look natural
	var raw_w: float = f_rect.size.x * SCALE_3D
	var raw_d: float = f_rect.size.y * SCALE_3D
	var rotated_90: bool = raw_d > raw_w * 1.08
	var w: float = raw_d if rotated_90 else raw_w
	var d: float = raw_w if rotated_90 else raw_d
	var base_yaw_rad: float = PI * 0.5 if rotated_90 else 0.0
	pivot.rotation.y = base_yaw_rad
	pivot.set_meta("base_yaw", base_yaw_rad)

	var main_mat: StandardMaterial3D = _make_mat(col, 0.72, 0.05)
	var accent_mat: StandardMaterial3D = _make_mat(accent, 0.68, 0.06)
	var wood_mat: StandardMaterial3D = _make_mat(COL_WALNUT, 0.74, 0.04)
	var chrome_mat: StandardMaterial3D = _make_mat(COL_CHROME, 0.25, 0.78)
	var dark_mat: StandardMaterial3D = _make_mat(COL_INK, 0.80, 0.05)
	var cream_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.82, 0.02)

	if not bool(prop.get("solid", true)) or kind.find("rug") >= 0:
		_add_box(pivot, Vector3(w, 0.015, d), Vector3(0.0, 0.008, 0.0), main_mat, Vector3.ZERO, false)
		return pivot

	if kind.find("fridge") >= 0:
		var fh: float = 1.32
		var enamel_mat: StandardMaterial3D = _make_mat(col.lightened(0.05), 0.32, 0.18)
		_add_box(pivot, Vector3(w * 0.92, fh - 0.14, d * 0.90), Vector3(0.0, (fh - 0.14) * 0.5 + 0.04, 0.0), enamel_mat)
		# Classic 1950s rounded refrigerator crown
		_add_sphere(pivot, minf(w, d) * 0.45, Vector3(0.0, fh - 0.12, 0.0), enamel_mat, Vector3(1.0, 0.42, 0.95))
		# Freezer & main door seam + chrome handle
		_add_box(pivot, Vector3(w * 0.84, 0.30, 0.03), Vector3(0.0, fh - 0.34, d * 0.46), enamel_mat)
		_add_box(pivot, Vector3(w * 0.86, 0.02, 0.04), Vector3(0.0, fh - 0.52, d * 0.46), chrome_mat)
		_add_box(pivot, Vector3(0.04, 0.26, 0.06), Vector3(w * 0.30, fh * 0.55, d * 0.48), chrome_mat)
		_add_box(pivot, Vector3(0.14, 0.035, 0.05), Vector3(0.0, fh - 0.26, d * 0.48), accent_mat)

	elif kind.find("counter") >= 0:
		var ch: float = 0.78
		var formica_mat: StandardMaterial3D = _make_mat(COL_ALERT_RED.lerp(accent, 0.35), 0.38, 0.12)
		_add_box(pivot, Vector3(w * 0.96, ch - 0.06, d * 0.92), Vector3(0.0, (ch - 0.06) * 0.5, 0.0), main_mat)
		_add_box(pivot, Vector3(w, 0.06, d), Vector3(0.0, ch - 0.03, 0.0), formica_mat)
		_add_box(pivot, Vector3(w, 0.09, 0.04), Vector3(0.0, ch + 0.04, -d * 0.46), formica_mat)
		# Sink basin + 2 stove burners + chrome pulls
		_add_box(pivot, Vector3(w * 0.30, 0.03, d * 0.56), Vector3(-w * 0.22, ch + 0.005, 0.0), chrome_mat)
		_add_cyl(pivot, 0.025, 0.025, 0.14, Vector3(-w * 0.22, ch + 0.07, -d * 0.26), chrome_mat)
		for bi in [-1, 1]:
			_add_cyl(pivot, 0.09, 0.09, 0.02, Vector3(w * 0.24 + float(bi) * 0.13, ch + 0.01, 0.0), dark_mat)
		for di in [-1, 0, 1]:
			_add_box(pivot, Vector3(0.10, 0.025, 0.03), Vector3(float(di) * w * 0.28, ch * 0.62, d * 0.47), chrome_mat)

	elif kind.find("dining") >= 0 or kind.find("coffee") >= 0 or kind == "table":
		var is_coffee: bool = kind.find("coffee") >= 0
		var th: float = 0.44 if is_coffee else 0.68
		_add_box(pivot, Vector3(w, 0.06, d), Vector3(0.0, th, 0.0), main_mat)
		_add_box(pivot, Vector3(w + 0.02, 0.025, d + 0.02), Vector3(0.0, th - 0.01, 0.0), chrome_mat if not is_coffee else wood_mat)
		var lx: float = w * 0.40
		var lz: float = d * 0.38
		for sx_s in [-1.0, 1.0]:
			for sz_s in [-1.0, 1.0]:
				_add_cyl(pivot, 0.032, 0.020, th, Vector3(sx_s * lx, th * 0.5, sz_s * lz), chrome_mat if not is_coffee else wood_mat)
		# Mid-century fruit bowl or magazine prop on table
		_add_cyl(pivot, 0.11, 0.07, 0.05, Vector3(0.0, th + 0.05, 0.0), accent_mat)

	elif kind.find("sofa") >= 0 or kind.find("couch") >= 0:
		var seat_h: float = 0.34
		var back_h: float = 0.74
		_add_box(pivot, Vector3(w * 0.88, seat_h - 0.08, d * 0.82), Vector3(0.0, (seat_h - 0.08) * 0.5 + 0.08, 0.04), main_mat)
		# Twin seat cushions
		_add_box(pivot, Vector3(w * 0.40, 0.10, d * 0.68), Vector3(-w * 0.21, seat_h + 0.03, 0.06), accent_mat)
		_add_box(pivot, Vector3(w * 0.40, 0.10, d * 0.68), Vector3(w * 0.21, seat_h + 0.03, 0.06), accent_mat)
		# Tufted backrest & armrests
		_add_box(pivot, Vector3(w * 0.92, back_h - 0.10, d * 0.26), Vector3(0.0, back_h * 0.5 + 0.04, -d * 0.34), main_mat)
		_add_box(pivot, Vector3(w * 0.12, 0.46, d * 0.86), Vector3(-w * 0.44, 0.30, 0.0), main_mat)
		_add_box(pivot, Vector3(w * 0.12, 0.46, d * 0.86), Vector3(w * 0.44, 0.30, 0.0), main_mat)
		for sx_l in [-1.0, 1.0]:
			for sz_l in [-1.0, 1.0]:
				_add_cyl(pivot, 0.025, 0.015, 0.12, Vector3(sx_l * w * 0.42, 0.06, sz_l * d * 0.36), wood_mat)

	elif kind.find("tv") >= 0:
		var cab_h: float = 0.46
		_add_box(pivot, Vector3(w, cab_h - 0.10, d), Vector3(0.0, (cab_h - 0.10) * 0.5 + 0.10, 0.0), wood_mat)
		for sx_t in [-1.0, 1.0]:
			_add_cyl(pivot, 0.025, 0.015, 0.12, Vector3(sx_t * w * 0.40, 0.06, 0.0), wood_mat)
		# 1950s CRT Television Box + Glowing CONELRAD Test Screen + Rabbit Ears
		var tv_w: float = minf(w * 0.68, 0.72)
		var tv_h: float = 0.44
		var crt_mat: StandardMaterial3D = _make_mat(Color("#9be870"), 0.22, 0.1, Color("#7ec850"), 0.85)
		_add_box(pivot, Vector3(tv_w, tv_h, d * 0.78), Vector3(0.0, cab_h + tv_h * 0.5, 0.0), main_mat)
		_add_box(pivot, Vector3(tv_w * 0.68, tv_h * 0.72, 0.03), Vector3(-tv_w * 0.08, cab_h + tv_h * 0.5, d * 0.40), crt_mat)
		_add_cyl(pivot, 0.008, 0.012, 0.38, Vector3(-0.09, cab_h + tv_h + 0.15, 0.0), chrome_mat, Vector3(0.0, 0.0, 26.0), 8, false)
		_add_cyl(pivot, 0.008, 0.012, 0.38, Vector3(0.09, cab_h + tv_h + 0.15, 0.0), chrome_mat, Vector3(0.0, 0.0, -26.0), 8, false)

	elif kind.find("bed") >= 0:
		var is_double: bool = kind.find("double") >= 0 or d > 1.15
		var frame_h: float = 0.24
		var matt_h: float = 0.18
		_add_box(pivot, Vector3(w, frame_h - 0.08, d), Vector3(0.0, frame_h * 0.5 + 0.03, 0.0), wood_mat)
		# Headboard at -X end
		_add_box(pivot, Vector3(0.08, 0.68, d), Vector3(-w * 0.47, 0.34, 0.0), wood_mat)
		# Cream mattress + colorful mid-century quilt + plump pillows
		_add_box(pivot, Vector3(w * 0.92, matt_h, d * 0.92), Vector3(0.02, frame_h + matt_h * 0.5, 0.0), cream_mat)
		_add_box(pivot, Vector3(w * 0.64, matt_h + 0.03, d * 0.94), Vector3(w * 0.15, frame_h + matt_h * 0.5 + 0.01, 0.0), main_mat)
		if is_double:
			_add_box(pivot, Vector3(w * 0.20, 0.09, d * 0.36), Vector3(-w * 0.30, frame_h + matt_h + 0.04, -d * 0.22), cream_mat)
			_add_box(pivot, Vector3(w * 0.20, 0.09, d * 0.36), Vector3(-w * 0.30, frame_h + matt_h + 0.04, d * 0.22), cream_mat)
		else:
			_add_box(pivot, Vector3(w * 0.22, 0.09, d * 0.56), Vector3(-w * 0.30, frame_h + matt_h + 0.04, 0.0), cream_mat)

	elif kind.find("bathtub") >= 0 or kind.find("tub") >= 0:
		var tub_h: float = 0.50
		var porc_mat: StandardMaterial3D = _make_mat(Color("#eef5f3"), 0.25, 0.12)
		var water_mat: StandardMaterial3D = _make_mat(Color("#6ac4db"), 0.18, 0.1, Color("#3b8ec2"), 0.15, 0.85)
		_add_box(pivot, Vector3(w, tub_h, d), Vector3(0.0, tub_h * 0.5, 0.0), porc_mat)
		_add_box(pivot, Vector3(w * 0.82, 0.08, d * 0.74), Vector3(0.0, tub_h - 0.02, 0.0), water_mat)
		_add_cyl(pivot, 0.025, 0.025, 0.16, Vector3(-w * 0.43, tub_h + 0.07, 0.0), chrome_mat)

	elif kind.find("workbench") >= 0:
		var wb_h: float = 0.74
		var top_wood: StandardMaterial3D = _make_mat(COL_WALNUT_LIGHT, 0.78, 0.04)
		var vise_mat: StandardMaterial3D = _make_mat(COL_ALERT_RED, 0.48, 0.35)
		_add_box(pivot, Vector3(w, 0.07, d), Vector3(0.0, wb_h, 0.0), top_wood)
		for sx_w in [-1.0, 1.0]:
			for sz_w in [-1.0, 1.0]:
				_add_box(pivot, Vector3(0.07, wb_h, 0.07), Vector3(sx_w * w * 0.43, wb_h * 0.5, sz_w * d * 0.40), dark_mat)
		_add_box(pivot, Vector3(w * 0.88, 0.04, d * 0.78), Vector3(0.0, 0.22, 0.0), main_mat)
		# Bench vise + hazard stripe tool lip
		_add_box(pivot, Vector3(0.16, 0.12, 0.14), Vector3(w * 0.32, wb_h + 0.09, d * 0.32), vise_mat)
		_add_box(pivot, Vector3(w * 0.94, 0.22, 0.04), Vector3(0.0, wb_h + 0.14, -d * 0.45), accent_mat)

	elif kind.find("book") >= 0 or kind.find("shelf") >= 0:
		var bs_h: float = 0.96
		_add_box(pivot, Vector3(w, bs_h, d), Vector3(0.0, bs_h * 0.5, 0.0), wood_mat)
		var book_cols: Array[Color] = [COL_ALERT_RED, COL_HAZARD_YELLOW, COL_WATER_BLUE, COL_TOXIC_GREEN, COL_PARCHMENT]
		for row_i in range(2):
			var sy_b: float = 0.24 + float(row_i) * 0.38
			var num_b: int = maxi(3, int(w / 0.14))
			for bi in range(num_b):
				var bx: float = -w * 0.38 + float(bi) * (w * 0.76 / float(maxi(1, num_b - 1)))
				var bm_c: StandardMaterial3D = _make_mat(book_cols[(bi + row_i * 2) % book_cols.size()], 0.7, 0.02)
				_add_box(pivot, Vector3(0.07, 0.24, d * 0.65), Vector3(bx, sy_b, 0.06), bm_c)

	elif kind.find("sink") >= 0 or kind.find("vanity") >= 0:
		var vh: float = 0.74
		_add_box(pivot, Vector3(w, vh, d), Vector3(0.0, vh * 0.5, 0.0), main_mat)
		_add_box(pivot, Vector3(w * 0.72, 0.05, d * 0.66), Vector3(0.0, vh + 0.01, 0.0), chrome_mat)
		_add_cyl(pivot, 0.022, 0.022, 0.14, Vector3(0.0, vh + 0.08, -d * 0.25), chrome_mat)

	else:
		# Dresser / Credenza / Low Closet Chest (with brass drawer pulls + warm table lamp)
		var dh: float = 0.80 if kind.find("dresser") >= 0 else 0.98
		_add_box(pivot, Vector3(w, dh - 0.08, d), Vector3(0.0, (dh - 0.08) * 0.5 + 0.08, 0.0), main_mat)
		_add_box(pivot, Vector3(w + 0.03, 0.05, d + 0.03), Vector3(0.0, dh, 0.0), wood_mat)
		for dr_i in range(3):
			var dy: float = 0.22 + float(dr_i) * ((dh - 0.26) / 2.6)
			_add_box(pivot, Vector3(w * 0.82, 0.03, 0.04), Vector3(0.0, dy, d * 0.49), accent_mat)
		if kind.find("dresser") >= 0:
			var shade_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.6, 0.0, COL_HAZARD_YELLOW, 0.35)
			_add_cyl(pivot, 0.05, 0.08, 0.14, Vector3(w * 0.26, dh + 0.09, 0.0), accent_mat)
			_add_cyl(pivot, 0.09, 0.15, 0.16, Vector3(w * 0.26, dh + 0.22, 0.0), shade_mat)

	return pivot


# ==============================================================================
# 3D CENTRAL FALLOUT BUNKER HATCH
# ==============================================================================

static func build_bunker_hatch(hatch_pos: Vector2, hatch_radius: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "BunkerHatch3D"
	root.position = to_3d(hatch_pos, FLOOR_TOP_Y)

	var hr: float = hatch_radius * SCALE_3D
	var concrete_mat: StandardMaterial3D = _make_mat(Color("#767b74"), 0.88, 0.05)
	var steel_rim_mat: StandardMaterial3D = _make_mat(COL_STEEL_DARK, 0.42, 0.68)
	var steel_light_mat: StandardMaterial3D = _make_mat(COL_STEEL, 0.35, 0.75)
	var yellow_mat: StandardMaterial3D = _make_mat(COL_HAZARD_YELLOW, 0.55, 0.08)
	var black_mat: StandardMaterial3D = _make_mat(COL_INK, 0.72, 0.08)
	var shaft_wall_mat: StandardMaterial3D = _make_mat(Color("#121513"), 0.95, 0.1)
	var shaft_glow_mat: StandardMaterial3D = _make_mat(
		Color("#f5a638"), 0.35, 0.0, Color("#ff9d2e"), 1.65
	)
	var beacon_mat: StandardMaterial3D = _make_mat(
		COL_HAZARD_YELLOW, 0.35, 0.1, COL_HAZARD_YELLOW, 0.95, 0.78
	)

	# Outer concrete blast apron
	_add_cyl(root, hr + 0.26, hr + 0.30, 0.04, Vector3(0.0, 0.015, 0.0), concrete_mat, Vector3.ZERO, 28, false)

	# 16 alternating Yellow & Black 3D hazard wedge blocks around perimeter
	var seg_n: int = 16
	var ring_r: float = hr + 0.10
	for i in range(seg_n):
		var ang: float = (float(i) + 0.5) * TAU / float(seg_n)
		var seg_mat: StandardMaterial3D = yellow_mat if (i % 2 == 0) else black_mat
		var seg_pos := Vector3(cos(ang) * ring_r, 0.045, sin(ang) * ring_r)
		_add_box(
			root,
			Vector3(0.18, 0.05, (TAU * ring_r / float(seg_n)) * 0.92),
			seg_pos,
			seg_mat,
			Vector3(0.0, -rad_to_deg(ang), 0.0),
			false
		)

	# Bolted steel collar + 8 rivets
	_add_cyl(root, hr, hr + 0.02, 0.08, Vector3(0.0, 0.04, 0.0), steel_rim_mat, Vector3.ZERO, 28)
	for ri in range(8):
		var ra: float = float(ri) * TAU / 8.0
		_add_sphere(
			root,
			0.038,
			Vector3(cos(ra) * (hr - 0.09), 0.085, sin(ra) * (hr - 0.09)),
			steel_light_mat,
			Vector3(1.0, 0.6, 1.0),
			false
		)

	# Subterranean recessed stairwell shaft & glowing warm shelter disc
	var shaft_r: float = maxf(0.45, hr - 0.18)
	_add_cyl(root, shaft_r, shaft_r, 0.09, Vector3(0.0, 0.045, 0.0), shaft_wall_mat, Vector3.ZERO, 24, false)
	_add_cyl(root, shaft_r * 0.84, shaft_r * 0.84, 0.02, Vector3(0.0, 0.085, 0.0), shaft_glow_mat, Vector3.ZERO, 24, false)

	# Steel ladder rails & rungs rising into shaft opening
	var rail_x: float = shaft_r * 0.36
	var rail_z: float = -shaft_r * 0.42
	_add_cyl(root, 0.026, 0.026, 0.36, Vector3(-rail_x, 0.06, rail_z), steel_light_mat, Vector3.ZERO, 10)
	_add_cyl(root, 0.026, 0.026, 0.36, Vector3(rail_x, 0.06, rail_z), steel_light_mat, Vector3.ZERO, 10)
	for rg in range(3):
		_add_cyl(
			root,
			0.018,
			0.018,
			rail_x * 2.0,
			Vector3(0.0, 0.08 + float(rg) * 0.07, rail_z),
			COL_CHROME_MAT(),
			Vector3(0.0, 0.0, 90.0),
			8,
			false
		)

	# Heavy hinged circular steel blast lid (reclined flat at -174 deg so back doorways & items stay unobstructed!)
	var lid_pivot := Node3D.new()
	lid_pivot.name = "HatchLidPivot"
	var hinge_offset := Vector3(0.0, 0.085, -hr * 0.84)
	lid_pivot.position = hinge_offset
	lid_pivot.rotation_degrees = Vector3(-174.0, 0.0, 0.0) # Reclined flat!
	root.add_child(lid_pivot)

	var lid_r: float = hr * 0.76
	var lid_local_c := Vector3(0.0, 0.03, hr * 0.84)
	_add_cyl(lid_pivot, lid_r, lid_r, 0.07, lid_local_c, steel_rim_mat, Vector3.ZERO, 24)
	_add_cyl(lid_pivot, lid_r * 0.78, lid_r * 0.78, 0.085, lid_local_c, steel_light_mat, Vector3.ZERO, 20)
	# Hinge knuckle block
	_add_box(lid_pivot, Vector3(0.28, 0.09, 0.14), Vector3(0.0, 0.03, 0.04), steel_light_mat)

	# Iconic red/yellow blast valve wheel on both sides of lid
	var wheel_mat: StandardMaterial3D = _make_mat(COL_ATOMIC_ORANGE, 0.38, 0.45)
	for side_y in [-0.055, 0.055]:
		var wc := lid_local_c + Vector3(0.0, float(side_y), 0.0)
		_add_cyl(lid_pivot, 0.24, 0.24, 0.025, wc, wheel_mat, Vector3.ZERO, 16)
		_add_box(lid_pivot, Vector3(0.44, 0.03, 0.035), wc, yellow_mat)
		_add_box(lid_pivot, Vector3(0.035, 0.03, 0.44), wc, yellow_mat)

	# Pulsing outer chute drop zone beacon ring (18.0 px margin)
	var beacon_ring := MeshInstance3D.new()
	if not _is_dummy_renderer():
		var torus := TorusMesh.new()
		var drop_r: float = (hatch_radius + 18.0) * SCALE_3D
		torus.inner_radius = maxf(0.1, drop_r - 0.06)
		torus.outer_radius = drop_r + 0.06
		torus.rings = 28
		torus.ring_segments = 10
		beacon_ring.mesh = torus
		beacon_ring.material_override = beacon_mat
		beacon_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon_ring.position = Vector3(0.0, 0.025, 0.0)
	root.add_child(beacon_ring)

	return {
		"root": root,
		"lid_pivot": lid_pivot,
		"beacon_ring": beacon_ring,
		"beacon_mat": beacon_mat,
		"shaft_glow_mat": shaft_glow_mat
	}


static func COL_CHROME_MAT() -> StandardMaterial3D:
	return _make_mat(COL_CHROME, 0.22, 0.80)


# ==============================================================================
# 3D ARTICULATED CUSTOM SURVIVORS
# ==============================================================================

static func build_character_3d(member: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Survivor3D"

	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", CharacterArtist.get_role_for_age(age)))
	var h_scale: float = 1.0
	if role == "child" or age <= 12:
		h_scale = 0.72
	elif role == "teen" or age <= 17:
		h_scale = 0.88
	elif role == "elder" or age >= 60:
		h_scale = 0.95

	var skin_col: Color = CharacterArtist.get_skin_color(member)
	var hair_col: Color = _safe_color(member.get("hair_color", "#4a2e1b"), Color("#4a2e1b"))
	var eye_col: Color = _safe_color(member.get("eye_color", "#2f5d8a"), Color("#2f5d8a"))
	var outfit_col: Color = _safe_color(member.get("outfit_color", "#c84b31"), Color("#c84b31"))
	var hair_style: int = clampi(int(member.get("hair_style", 0)), 0, 7)
	var facial_hair: int = clampi(int(member.get("facial_hair", 0)), 0, 3)
	var shirt_style: int = clampi(int(member.get("shirt_style", 0)), 0, 4)
	var has_glasses: bool = bool(member.get("glasses", false))
	var hat_id: String = str(member.get("hat_id", "none")).to_lower()

	var skin_mat: StandardMaterial3D = _make_mat(skin_col, 0.75, 0.02)
	var hair_mat: StandardMaterial3D = _make_mat(hair_col, 0.80, 0.04)
	var outfit_mat: StandardMaterial3D = _make_mat(outfit_col, 0.82, 0.03)
	var pants_mat: StandardMaterial3D = _make_mat(Color("#323942"), 0.86, 0.02)
	var shoe_mat: StandardMaterial3D = _make_mat(Color("#251c17"), 0.72, 0.08)
	var eye_white_mat: StandardMaterial3D = _make_mat(Color("#faf8f2"), 0.4, 0.0)
	var iris_mat: StandardMaterial3D = _make_mat(eye_col, 0.35, 0.05)
	var ink_mat: StandardMaterial3D = _make_mat(COL_INK, 0.45, 0.1)
	var cream_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.78, 0.02)

	var body_pivot := Node3D.new()
	body_pivot.name = "BodyPivot"
	body_pivot.scale = Vector3(h_scale, h_scale, h_scale)
	root.add_child(body_pivot)

	# Articulated Left & Right Legs (hip pivots at y = 0.46)
	var leg_l := Node3D.new()
	leg_l.name = "LegLPivot"
	leg_l.position = Vector3(-0.105, 0.46, 0.0)
	body_pivot.add_child(leg_l)
	_add_capsule(leg_l, 0.068, 0.42, Vector3(0.0, -0.20, 0.0), pants_mat)
	_add_box(leg_l, Vector3(0.13, 0.09, 0.21), Vector3(0.0, -0.41, 0.035), shoe_mat)

	var leg_r := Node3D.new()
	leg_r.name = "LegRPivot"
	leg_r.position = Vector3(0.105, 0.46, 0.0)
	body_pivot.add_child(leg_r)
	_add_capsule(leg_r, 0.068, 0.42, Vector3(0.0, -0.20, 0.0), pants_mat)
	_add_box(leg_r, Vector3(0.13, 0.09, 0.21), Vector3(0.0, -0.41, 0.035), shoe_mat)

	# Torso & 1950s Outfit Styling (y = 0.46 .. 0.94)
	_add_box(body_pivot, Vector3(0.36, 0.46, 0.22), Vector3(0.0, 0.69, 0.0), outfit_mat)
	match shirt_style:
		0: # Shirt & Tie
			var tie_mat: StandardMaterial3D = _make_mat(COL_ALERT_RED, 0.65, 0.04)
			_add_box(body_pivot, Vector3(0.16, 0.08, 0.23), Vector3(0.0, 0.89, 0.0), cream_mat)
			_add_box(body_pivot, Vector3(0.06, 0.28, 0.03), Vector3(0.0, 0.73, 0.115), tie_mat)
		1: # Knit Sweater
			_add_box(body_pivot, Vector3(0.375, 0.07, 0.235), Vector3(0.0, 0.49, 0.0), _make_mat(outfit_col.darkened(0.22), 0.9, 0.0))
		2: # Retro Polka Dress (flared A-line skirt)
			_add_cyl(body_pivot, 0.17, 0.28, 0.26, Vector3(0.0, 0.45, 0.0), outfit_mat, Vector3.ZERO, 16)
			_add_box(body_pivot, Vector3(0.37, 0.045, 0.23), Vector3(0.0, 0.56, 0.0), cream_mat)
		3: # Ringer Tee
			_add_box(body_pivot, Vector3(0.18, 0.06, 0.235), Vector3(0.0, 0.90, 0.0), cream_mat)
		4: # Utility Jacket
			_add_box(body_pivot, Vector3(0.04, 0.45, 0.235), Vector3(0.0, 0.69, 0.0), ink_mat)
			_add_box(body_pivot, Vector3(0.09, 0.09, 0.03), Vector3(-0.10, 0.74, 0.115), _make_mat(outfit_col.darkened(0.18), 0.8, 0.0))
			_add_box(body_pivot, Vector3(0.09, 0.09, 0.03), Vector3(0.10, 0.74, 0.115), _make_mat(outfit_col.darkened(0.18), 0.8, 0.0))

	# Articulated Left & Right Arms (shoulder pivots at y = 0.88)
	var arm_l := Node3D.new()
	arm_l.name = "ArmLPivot"
	arm_l.position = Vector3(-0.24, 0.88, 0.0)
	body_pivot.add_child(arm_l)
	_add_capsule(arm_l, 0.056, 0.36, Vector3(0.0, -0.15, 0.0), outfit_mat)
	_add_sphere(arm_l, 0.06, Vector3(0.0, -0.34, 0.0), skin_mat)

	var arm_r := Node3D.new()
	arm_r.name = "ArmRPivot"
	arm_r.position = Vector3(0.24, 0.88, 0.0)
	body_pivot.add_child(arm_r)
	_add_capsule(arm_r, 0.056, 0.36, Vector3(0.0, -0.15, 0.0), outfit_mat)
	_add_sphere(arm_r, 0.06, Vector3(0.0, -0.34, 0.0), skin_mat)

	# Head & Expressive 1950s Features (pivot at y = 0.96, facing +Z in local space)
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.96, 0.0)
	body_pivot.add_child(head_pivot)

	var head_r: float = 0.21 if (role != "child") else 0.235
	_add_sphere(head_pivot, head_r, Vector3(0.0, head_r * 0.92, 0.0), skin_mat, Vector3(1.0, 1.06, 0.98))
	# Nose & ears
	_add_sphere(head_pivot, 0.035, Vector3(0.0, head_r * 0.88, head_r * 0.96), skin_mat)
	_add_sphere(head_pivot, 0.042, Vector3(-head_r * 0.96, head_r * 0.90, 0.0), skin_mat, Vector3(0.5, 0.9, 0.7), false)
	_add_sphere(head_pivot, 0.042, Vector3(head_r * 0.96, head_r * 0.90, 0.0), skin_mat, Vector3(0.5, 0.9, 0.7), false)

	# Crisp Eyes
	var ey: float = head_r * 0.98
	var ez: float = head_r * 0.88
	for side_s in [-1.0, 1.0]:
		_add_sphere(head_pivot, 0.038, Vector3(side_s * 0.072, ey, ez), eye_white_mat, Vector3(1.0, 1.1, 0.55), false)
		_add_sphere(head_pivot, 0.022, Vector3(side_s * 0.072, ey, ez + 0.018), iris_mat, Vector3(1.0, 1.1, 0.5), false)

	# 3D Horn-Rimmed Glasses
	if has_glasses:
		var lens_mat: StandardMaterial3D = _make_mat(Color("#d9f0f7"), 0.15, 0.2, Color.BLACK, 0.0, 0.45)
		for side_g in [-1.0, 1.0]:
			var gx: float = side_g * 0.076
			_add_box(head_pivot, Vector3(0.095, 0.072, 0.022), Vector3(gx, ey, ez + 0.03), lens_mat, Vector3.ZERO, false)
			_add_box(head_pivot, Vector3(0.105, 0.018, 0.028), Vector3(gx, ey + 0.034, ez + 0.032), ink_mat, Vector3.ZERO, false)
			_add_box(head_pivot, Vector3(0.105, 0.014, 0.026), Vector3(gx, ey - 0.034, ez + 0.032), ink_mat, Vector3.ZERO, false)
			_add_box(head_pivot, Vector3(0.016, 0.072, 0.026), Vector3(gx + side_g * 0.046, ey, ez + 0.032), ink_mat, Vector3.ZERO, false)
			_add_box(head_pivot, Vector3(0.016, 0.016, 0.18), Vector3(side_g * (head_r * 0.94), ey + 0.01, ez * 0.35), ink_mat, Vector3.ZERO, false)
		_add_box(head_pivot, Vector3(0.045, 0.016, 0.028), Vector3(0.0, ey + 0.014, ez + 0.034), ink_mat, Vector3.ZERO, false)

	# Facial Hair (1: Mustache, 2: Full Beard, 3: Stubble)
	if facial_hair == 1:
		_add_box(head_pivot, Vector3(0.12, 0.034, 0.04), Vector3(0.0, head_r * 0.66, head_r * 0.93), hair_mat, Vector3.ZERO, false)
	elif facial_hair == 2:
		_add_sphere(head_pivot, head_r * 0.86, Vector3(0.0, head_r * 0.56, head_r * 0.26), hair_mat, Vector3(1.02, 0.72, 1.02))
	elif facial_hair == 3:
		var stub_mat: StandardMaterial3D = _make_mat(skin_col.lerp(hair_col, 0.38), 0.9, 0.0)
		_add_sphere(head_pivot, head_r * 0.80, Vector3(0.0, head_r * 0.56, head_r * 0.22), stub_mat, Vector3(0.98, 0.62, 0.98), false)

	# 8 Distinct 3D Hair Styles (0..7)
	var hy: float = head_r * 0.96
	match hair_style:
		0: # Classic Side Part
			_add_sphere(head_pivot, head_r * 1.04, Vector3(0.0, hy + 0.06, -0.02), hair_mat, Vector3(1.04, 0.85, 1.05))
			_add_box(head_pivot, Vector3(head_r * 1.4, 0.08, 0.14), Vector3(0.03, hy + head_r * 0.78, head_r * 0.55), hair_mat, Vector3(0.0, 0.0, -8.0))
		1: # 50s Pompadour
			_add_sphere(head_pivot, head_r * 1.03, Vector3(0.0, hy + 0.06, -0.03), hair_mat, Vector3(1.02, 0.88, 1.06))
			_add_capsule(head_pivot, 0.11, 0.30, Vector3(0.0, hy + head_r * 0.94, head_r * 0.42), hair_mat, Vector3(68.0, 0.0, 0.0))
		2: # Chin Bob
			_add_sphere(head_pivot, head_r * 1.08, Vector3(0.0, hy + 0.05, -0.02), hair_mat, Vector3(1.10, 0.95, 1.08))
			_add_capsule(head_pivot, 0.075, 0.28, Vector3(-head_r * 0.88, hy - 0.02, 0.02), hair_mat)
			_add_capsule(head_pivot, 0.075, 0.28, Vector3(head_r * 0.88, hy - 0.02, 0.02), hair_mat)
		3: # High Beehive
			_add_sphere(head_pivot, head_r * 1.06, Vector3(0.0, hy + 0.08, -0.01), hair_mat, Vector3(1.06, 0.95, 1.06))
			_add_capsule(head_pivot, head_r * 0.82, 0.42, Vector3(0.0, hy + head_r * 1.18, -0.02), hair_mat)
		4: # Twin Pigtails
			_add_sphere(head_pivot, head_r * 1.04, Vector3(0.0, hy + 0.06, -0.02), hair_mat, Vector3(1.04, 0.86, 1.04))
			_add_sphere(head_pivot, 0.115, Vector3(-head_r * 1.22, hy + 0.08, -0.02), hair_mat, Vector3(0.9, 1.25, 0.9))
			_add_sphere(head_pivot, 0.115, Vector3(head_r * 1.22, hy + 0.08, -0.02), hair_mat, Vector3(0.9, 1.25, 0.9))
		5: # Voluminous Afro
			_add_sphere(head_pivot, head_r * 1.48, Vector3(0.0, hy + 0.12, -0.02), hair_mat)
		6: # Buzz / Bald
			var buzz_mat: StandardMaterial3D = _make_mat(skin_col.lerp(hair_col, 0.52), 0.85, 0.02)
			_add_sphere(head_pivot, head_r * 1.01, Vector3(0.0, hy + 0.04, -0.02), buzz_mat, Vector3(1.0, 0.82, 1.0))
		7: # Spiky Punk
			_add_sphere(head_pivot, head_r * 1.01, Vector3(0.0, hy + 0.04, -0.02), hair_mat, Vector3(0.96, 0.80, 1.0))
			for sp_i in range(-2, 3):
				var sp_ang: float = float(sp_i) * 20.0
				var sp_z: float = -float(sp_i) * 0.065
				_add_prism(
					head_pivot,
					Vector3(0.09, 0.21, 0.11),
					Vector3(0.0, hy + head_r * 1.12, sp_z),
					hair_mat,
					Vector3(-sp_ang, 0.0, 0.0)
				)

	# Unlockable Hats ("cd_helmet", "aviator", "ushanka", "medic_cap")
	if hat_id != "none" and not hat_id.is_empty():
		var hat_y: float = hy + head_r * 0.95
		match hat_id:
			"cd_helmet":
				var helm_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.35, 0.35)
				_add_cyl(head_pivot, head_r * 1.38, head_r * 1.46, 0.035, Vector3(0.0, hat_y - 0.02, 0.0), helm_mat)
				_add_sphere(head_pivot, head_r * 1.08, Vector3(0.0, hat_y + 0.03, 0.0), helm_mat, Vector3(1.05, 0.65, 1.08))
				_add_box(head_pivot, Vector3(0.09, 0.09, 0.03), Vector3(0.0, hat_y + 0.05, head_r * 1.08), _make_mat(COL_ALERT_RED, 0.5, 0.1))
			"aviator":
				var leath_mat: StandardMaterial3D = _make_mat(COL_WALNUT, 0.68, 0.08)
				_add_sphere(head_pivot, head_r * 1.12, Vector3(0.0, hat_y, -0.01), leath_mat, Vector3(1.06, 0.82, 1.08))
				_add_cyl(head_pivot, 0.055, 0.055, 0.05, Vector3(-0.075, hat_y + 0.02, head_r * 1.02), COL_CHROME_MAT(), Vector3(90.0, 0.0, 0.0), 12)
				_add_cyl(head_pivot, 0.055, 0.055, 0.05, Vector3(0.075, hat_y + 0.02, head_r * 1.02), COL_CHROME_MAT(), Vector3(90.0, 0.0, 0.0), 12)
			"ushanka":
				var fur_mat: StandardMaterial3D = _make_mat(Color("#6b5c4d"), 0.95, 0.0)
				_add_box(head_pivot, Vector3(head_r * 2.2, 0.20, head_r * 2.1), Vector3(0.0, hat_y + 0.04, 0.0), fur_mat)
				_add_box(head_pivot, Vector3(0.08, 0.22, 0.16), Vector3(-head_r * 1.08, hat_y - 0.08, 0.02), fur_mat)
				_add_box(head_pivot, Vector3(0.08, 0.22, 0.16), Vector3(head_r * 1.08, hat_y - 0.08, 0.02), fur_mat)
			"medic_cap":
				_add_cyl(head_pivot, head_r * 1.02, head_r * 1.04, 0.16, Vector3(0.0, hat_y + 0.05, 0.0), cream_mat)
				var red_m: StandardMaterial3D = _make_mat(COL_ALERT_RED, 0.5, 0.05)
				_add_box(head_pivot, Vector3(0.09, 0.03, 0.03), Vector3(0.0, hat_y + 0.06, head_r * 1.03), red_m)
				_add_box(head_pivot, Vector3(0.03, 0.09, 0.03), Vector3(0.0, hat_y + 0.06, head_r * 1.03), red_m)

	# Overhead Carry Stack Mount (above raised hands!)
	var carry_mount := Node3D.new()
	carry_mount.name = "CarryMount"
	carry_mount.position = Vector3(0.0, 1.52, 0.06)
	body_pivot.add_child(carry_mount)

	root.set_meta("height_scale", h_scale)
	return root


static func animate_character_3d(
	char_node: Node3D,
	walk_phase: float,
	speed_ratio: float,
	carrying_count: int,
	idle_time: float = 0.0,
	is_waiting_family: bool = false
) -> void:
	if not is_instance_valid(char_node):
		return
	var body_p: Node3D = char_node.get_node_or_null("BodyPivot")
	if body_p == null:
		return
	var leg_l: Node3D = body_p.get_node_or_null("LegLPivot")
	var leg_r: Node3D = body_p.get_node_or_null("LegRPivot")
	var arm_l: Node3D = body_p.get_node_or_null("ArmLPivot")
	var arm_r: Node3D = body_p.get_node_or_null("ArmRPivot")
	var head_p: Node3D = body_p.get_node_or_null("HeadPivot")

	var h_scale: float = float(char_node.get_meta("height_scale", 1.0))
	var stride_amp: float = clampf(speed_ratio, 0.0, 1.25) * 0.78
	var s_val: float = sin(walk_phase * 2.2)

	if leg_l != null and leg_r != null:
		leg_l.rotation.x = s_val * stride_amp
		leg_r.rotation.x = -s_val * stride_amp

	# Energetic run bob
	var bob_y: float = absf(sin(walk_phase * 2.2)) * 0.06 * clampf(speed_ratio, 0.0, 1.0) * h_scale
	body_p.position.y = bob_y
	body_p.rotation.x = clampf(speed_ratio, 0.0, 1.0) * 0.10 # Lean forward into sprint

	if arm_l != null and arm_r != null:
		if carrying_count > 0:
			# Hoist arms overhead to carry supplies & family!
			var wobble: float = sin(walk_phase * 2.2) * 0.08 * clampf(speed_ratio, 0.2, 1.0)
			arm_l.rotation = Vector3(deg_to_rad(-152.0) + wobble, 0.0, deg_to_rad(10.0))
			arm_r.rotation = Vector3(deg_to_rad(-152.0) - wobble, 0.0, deg_to_rad(-10.0))
		elif is_waiting_family:
			# Nervous waving to get leader's attention!
			var wave: float = sin(idle_time * 7.5) * 0.38
			arm_l.rotation = Vector3(deg_to_rad(-28.0), 0.0, deg_to_rad(14.0))
			arm_r.rotation = Vector3(deg_to_rad(-135.0) + wave, 0.0, deg_to_rad(-22.0) + wave * 0.4)
		else:
			arm_l.rotation = Vector3(-s_val * stride_amp * 0.9, 0.0, deg_to_rad(6.0))
			arm_r.rotation = Vector3(s_val * stride_amp * 0.9, 0.0, deg_to_rad(-6.0))

	if head_p != null:
		if is_waiting_family:
			head_p.rotation.y = sin(idle_time * 3.1) * 0.28
		else:
			head_p.rotation.y = 0.0


static func sync_carried_stack_3d(char_node: Node3D, carried_entries: Array) -> void:
	if not is_instance_valid(char_node):
		return
	var body_p: Node3D = char_node.get_node_or_null("BodyPivot")
	if body_p == null:
		return
	var mount: Node3D = body_p.get_node_or_null("CarryMount")
	if mount == null:
		return

	for ch in mount.get_children():
		ch.queue_free()

	if carried_entries.is_empty():
		return

	var y_cursor: float = 0.0
	for idx in range(carried_entries.size()):
		var entry_v: Variant = carried_entries[idx]
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var kind: String = str(entry.get("kind", "item"))
		if kind == "family":
			var m_dict: Dictionary = entry.get("member", {}) if entry.get("member") is Dictionary else {}
			var carried_fam: Node3D = build_character_3d(m_dict)
			carried_fam.scale = Vector3(0.68, 0.68, 0.68)
			carried_fam.position = Vector3(-0.28, y_cursor + 0.14, 0.0)
			carried_fam.rotation_degrees = Vector3(0.0, 0.0, -90.0)
			mount.add_child(carried_fam)
			y_cursor += 0.30
		else:
			var iid: String = str(entry.get("item_id", "soup"))
			var mini_item: Node3D = build_item_3d(iid, true)
			var x_off: float = float((idx % 2) * 2 - 1) * 0.11 if carried_entries.size() > 1 else 0.0
			mini_item.position = Vector3(x_off, y_cursor, 0.0)
			mount.add_child(mini_item)
			y_cursor += 0.24


# ==============================================================================
# 3D SUPPLY PROP MODELS (ALL 18 CANONICAL ITEMS + SPECIALTY ITEMS)
# ==============================================================================

static func build_item_3d(item_id: String, is_carried_mini: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Item3D_" + item_id

	var key: String = item_id.strip_edges().to_lower()
	var info: Dictionary = ItemDB.get_item_info(key)
	var slots: int = int(info.get("slots", 1))
	var item_col: Color = _safe_color(info.get("color", COL_HAZARD_YELLOW), COL_HAZARD_YELLOW)

	if not is_carried_mini:
		# Glowing floor highlight disc + outer rim for 10/10 isometric floor readability
		var disc_mat: StandardMaterial3D = _make_mat(
			COL_PARCHMENT, 0.55, 0.05, item_col, 0.22, 0.88
		)
		var ring_col: Color = COL_HAZARD_YELLOW if slots == 2 else item_col.lightened(0.18)
		var ring_mat: StandardMaterial3D = _make_mat(
			ring_col, 0.40, 0.1, ring_col, 0.55, 0.85
		)
		var disc_mi: MeshInstance3D = _add_cyl(root, 0.36, 0.38, 0.02, Vector3(0.0, 0.012, 0.0), disc_mat, Vector3.ZERO, 20, false)
		disc_mi.name = "HighlightDisc"

		var hover_ring := MeshInstance3D.new()
		hover_ring.name = "HoverRing"
		if not _is_dummy_renderer():
			var tm := TorusMesh.new()
			tm.inner_radius = 0.37
			tm.outer_radius = 0.44
			tm.rings = 20
			tm.ring_segments = 8
			hover_ring.mesh = tm
			hover_ring.material_override = ring_mat
			hover_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hover_ring.position = Vector3(0.0, 0.02, 0.0)
		root.add_child(hover_ring)
		root.set_meta("ring_mat", ring_mat)
		root.set_meta("base_ring_col", ring_col)

	var model_pivot := Node3D.new()
	model_pivot.name = "ModelPivot"
	model_pivot.position = Vector3(0.0, 0.04 if is_carried_mini else 0.25, 0.0)
	if is_carried_mini:
		model_pivot.scale = Vector3(0.78, 0.78, 0.78)
	else:
		model_pivot.scale = Vector3(1.26, 1.26, 1.26)
	root.add_child(model_pivot)

	var red_mat: StandardMaterial3D = _make_mat(COL_ALERT_RED, 0.48, 0.08)
	var cream_mat: StandardMaterial3D = _make_mat(COL_PARCHMENT, 0.62, 0.04)
	var chrome_mat: StandardMaterial3D = COL_CHROME_MAT()
	var brass_mat: StandardMaterial3D = _make_mat(Color("#dba32e"), 0.34, 0.68)
	var wood_mat: StandardMaterial3D = _make_mat(COL_WALNUT, 0.68, 0.05)
	var olive_mat: StandardMaterial3D = _make_mat(COL_OLIVE, 0.72, 0.08)
	var dark_mat: StandardMaterial3D = _make_mat(COL_INK, 0.65, 0.15)
	var yel_mat: StandardMaterial3D = _make_mat(COL_HAZARD_YELLOW, 0.48, 0.08)

	match key:
		"soup":
			_add_cyl(model_pivot, 0.15, 0.15, 0.18, Vector3(0.0, 0.09, 0.0), red_mat)
			_add_cyl(model_pivot, 0.151, 0.151, 0.16, Vector3(0.0, -0.08, 0.0), cream_mat)
			_add_cyl(model_pivot, 0.158, 0.158, 0.025, Vector3(0.0, 0.18, 0.0), chrome_mat)
			_add_cyl(model_pivot, 0.158, 0.158, 0.025, Vector3(0.0, -0.16, 0.0), chrome_mat)
			_add_sphere(model_pivot, 0.042, Vector3(0.0, 0.0, 0.145), brass_mat, Vector3(1.0, 1.0, 0.35), false)

		"water":
			var water_jug_mat: StandardMaterial3D = _make_mat(
				Color("#4cb3e8"), 0.20, 0.08, Color("#3b8ec2"), 0.18, 0.86
			)
			_add_cyl(model_pivot, 0.15, 0.165, 0.32, Vector3(0.0, -0.02, 0.0), water_jug_mat)
			_add_cyl(model_pivot, 0.06, 0.09, 0.08, Vector3(0.0, 0.17, 0.0), water_jug_mat)
			_add_cyl(model_pivot, 0.068, 0.068, 0.045, Vector3(0.0, 0.22, 0.0), cream_mat)

		"medkit":
			var white_case: StandardMaterial3D = _make_mat(Color("#f7f4ec"), 0.42, 0.08)
			_add_box(model_pivot, Vector3(0.38, 0.26, 0.16), Vector3.ZERO, white_case)
			_add_box(model_pivot, Vector3(0.14, 0.05, 0.175), Vector3.ZERO, red_mat)
			_add_box(model_pivot, Vector3(0.05, 0.14, 0.175), Vector3.ZERO, red_mat)
			_add_box(model_pivot, Vector3(0.14, 0.05, 0.04), Vector3(0.0, 0.135, 0.0), dark_mat)

		"gas_mask":
			_add_sphere(model_pivot, 0.17, Vector3(0.0, 0.03, 0.0), olive_mat, Vector3(0.95, 1.12, 0.92))
			_add_cyl(model_pivot, 0.055, 0.055, 0.05, Vector3(-0.07, 0.07, 0.14), dark_mat, Vector3(90.0, 0.0, 0.0), 12)
			_add_cyl(model_pivot, 0.055, 0.055, 0.05, Vector3(0.07, 0.07, 0.14), dark_mat, Vector3(90.0, 0.0, 0.0), 12)
			_add_cyl(model_pivot, 0.068, 0.068, 0.12, Vector3(-0.11, -0.08, 0.12), dark_mat, Vector3(55.0, -25.0, 0.0), 12)
			_add_cyl(model_pivot, 0.068, 0.068, 0.12, Vector3(0.11, -0.08, 0.12), dark_mat, Vector3(55.0, 25.0, 0.0), 12)

		"radio":
			_add_box(model_pivot, Vector3(0.38, 0.25, 0.18), Vector3.ZERO, wood_mat)
			_add_box(model_pivot, Vector3(0.22, 0.14, 0.03), Vector3(-0.04, 0.02, 0.09), cream_mat)
			_add_cyl(model_pivot, 0.032, 0.032, 0.04, Vector3(0.12, 0.05, 0.09), brass_mat, Vector3(90.0, 0.0, 0.0), 10)
			_add_cyl(model_pivot, 0.032, 0.032, 0.04, Vector3(0.12, -0.04, 0.09), brass_mat, Vector3(90.0, 0.0, 0.0), 10)
			_add_cyl(model_pivot, 0.008, 0.012, 0.30, Vector3(0.13, 0.24, -0.03), chrome_mat, Vector3(0.0, 0.0, -14.0), 8, false)

		"flashlight":
			var beam_mat: StandardMaterial3D = _make_mat(Color("#fff2b2"), 0.15, 0.1, COL_HAZARD_YELLOW, 1.1)
			_add_cyl(model_pivot, 0.065, 0.065, 0.34, Vector3.ZERO, yel_mat, Vector3(0.0, 0.0, 65.0), 14)
			_add_cyl(model_pivot, 0.10, 0.07, 0.10, Vector3(-0.16, 0.075, 0.0), chrome_mat, Vector3(0.0, 0.0, 65.0), 14)
			_add_cyl(model_pivot, 0.088, 0.088, 0.02, Vector3(-0.20, 0.095, 0.0), beam_mat, Vector3(0.0, 0.0, 65.0), 14)

		"map":
			_add_box(model_pivot, Vector3(0.38, 0.03, 0.28), Vector3(0.0, -0.04, 0.0), cream_mat, Vector3(14.0, 0.0, -8.0))
			_add_box(model_pivot, Vector3(0.28, 0.036, 0.05), Vector3(0.0, -0.035, 0.0), red_mat, Vector3(14.0, 18.0, -8.0))
			_add_cyl(model_pivot, 0.045, 0.045, 0.29, Vector3(-0.18, -0.01, 0.0), _make_mat(COL_PARCHMENT_DARK, 0.75, 0.0), Vector3(90.0, 0.0, 0.0), 12)

		"book":
			var green_cov: StandardMaterial3D = _make_mat(Color("#4c7c40"), 0.72, 0.04)
			_add_box(model_pivot, Vector3(0.28, 0.09, 0.36), Vector3.ZERO, green_cov, Vector3(12.0, 18.0, 0.0))
			_add_box(model_pivot, Vector3(0.25, 0.07, 0.33), Vector3(0.015, 0.0, 0.0), cream_mat, Vector3(12.0, 18.0, 0.0))
			_add_sphere(model_pivot, 0.048, Vector3(0.0, 0.05, 0.0), yel_mat, Vector3(1.0, 0.3, 1.0), false)

		"ammo":
			_add_box(model_pivot, Vector3(0.32, 0.18, 0.20), Vector3(0.0, -0.03, 0.0), olive_mat)
			_add_box(model_pivot, Vector3(0.33, 0.045, 0.21), Vector3(0.0, 0.01, 0.0), yel_mat)
			for ai in range(-2, 3):
				_add_cyl(model_pivot, 0.016, 0.024, 0.11, Vector3(float(ai) * 0.052, 0.10, 0.0), brass_mat, Vector3.ZERO, 8)

		"bug_spray":
			var bug_green: StandardMaterial3D = _make_mat(COL_TOXIC_GREEN, 0.42, 0.18)
			_add_cyl(model_pivot, 0.105, 0.105, 0.34, Vector3(0.0, -0.02, 0.0), bug_green)
			_add_cyl(model_pivot, 0.108, 0.108, 0.09, Vector3(0.0, 0.02, 0.0), yel_mat)
			_add_cyl(model_pivot, 0.045, 0.055, 0.07, Vector3(0.0, 0.18, 0.0), red_mat)

		"padlock":
			_add_box(model_pivot, Vector3(0.26, 0.24, 0.10), Vector3(0.0, -0.05, 0.0), brass_mat)
			_add_box(model_pivot, Vector3(0.04, 0.09, 0.11), Vector3(0.0, -0.05, 0.0), dark_mat)
			_add_cyl(model_pivot, 0.026, 0.026, 0.16, Vector3(-0.075, 0.12, 0.0), chrome_mat, Vector3.ZERO, 8)
			_add_cyl(model_pivot, 0.026, 0.026, 0.16, Vector3(0.075, 0.12, 0.0), chrome_mat, Vector3.ZERO, 8)
			_add_cyl(model_pivot, 0.026, 0.026, 0.17, Vector3(0.0, 0.19, 0.0), chrome_mat, Vector3(0.0, 0.0, 90.0), 8)

		"cards":
			_add_box(model_pivot, Vector3(0.22, 0.06, 0.30), Vector3(-0.04, -0.04, 0.0), red_mat, Vector3(0.0, -14.0, 0.0))
			_add_box(model_pivot, Vector3(0.21, 0.025, 0.29), Vector3(0.05, 0.01, 0.0), cream_mat, Vector3(8.0, 18.0, -6.0))
			_add_sphere(model_pivot, 0.045, Vector3(0.05, 0.03, 0.0), red_mat, Vector3(1.0, 0.3, 1.0), false)

		"checkers":
			_add_box(model_pivot, Vector3(0.36, 0.05, 0.36), Vector3(0.0, -0.04, 0.0), red_mat)
			_add_box(model_pivot, Vector3(0.16, 0.055, 0.16), Vector3(-0.08, -0.04, -0.08), dark_mat)
			_add_box(model_pivot, Vector3(0.16, 0.055, 0.16), Vector3(0.08, -0.04, 0.08), dark_mat)
			_add_cyl(model_pivot, 0.055, 0.055, 0.035, Vector3(-0.07, 0.01, 0.06), red_mat, Vector3.ZERO, 12)
			_add_cyl(model_pivot, 0.055, 0.055, 0.035, Vector3(0.07, 0.01, -0.06), dark_mat, Vector3.ZERO, 12)

		"harmonica":
			_add_box(model_pivot, Vector3(0.38, 0.08, 0.13), Vector3.ZERO, chrome_mat, Vector3(10.0, 20.0, 0.0))
			_add_box(model_pivot, Vector3(0.39, 0.032, 0.138), Vector3.ZERO, wood_mat, Vector3(10.0, 20.0, 0.0))

		"axe":
			var hickory_mat: StandardMaterial3D = _make_mat(Color("#b57d44"), 0.72, 0.04)
			_add_cyl(model_pivot, 0.030, 0.036, 0.62, Vector3.ZERO, hickory_mat, Vector3(0.0, 0.0, 52.0), 10)
			_add_box(model_pivot, Vector3(0.18, 0.22, 0.055), Vector3(-0.18, 0.14, 0.0), red_mat, Vector3(0.0, 0.0, 52.0))
			_add_box(model_pivot, Vector3(0.05, 0.23, 0.045), Vector3(-0.24, 0.19, 0.0), chrome_mat, Vector3(0.0, 0.0, 52.0))

		"rifle":
			_add_box(model_pivot, Vector3(0.34, 0.10, 0.065), Vector3(0.14, -0.05, 0.0), wood_mat, Vector3(0.0, 0.0, 22.0))
			_add_cyl(model_pivot, 0.022, 0.024, 0.56, Vector3(-0.08, 0.05, 0.0), dark_mat, Vector3(0.0, 0.0, 112.0), 10)
			_add_cyl(model_pivot, 0.026, 0.026, 0.18, Vector3(-0.02, 0.09, 0.0), chrome_mat, Vector3(0.0, 0.0, 112.0), 10)

		"suitcase":
			var leather_mat: StandardMaterial3D = _make_mat(Color("#8c4f27"), 0.68, 0.06)
			var strap_mat: StandardMaterial3D = _make_mat(Color("#4f2a13"), 0.78, 0.05)
			_add_box(model_pivot, Vector3(0.48, 0.32, 0.18), Vector3.ZERO, leather_mat)
			_add_box(model_pivot, Vector3(0.045, 0.33, 0.195), Vector3(-0.13, 0.0, 0.0), strap_mat)
			_add_box(model_pivot, Vector3(0.045, 0.33, 0.195), Vector3(0.13, 0.0, 0.0), strap_mat)
			_add_box(model_pivot, Vector3(0.15, 0.055, 0.045), Vector3(0.0, 0.185, 0.0), strap_mat)
			for sx_c in [-1.0, 1.0]:
				for sy_c in [-1.0, 1.0]:
					_add_box(model_pivot, Vector3(0.06, 0.06, 0.195), Vector3(sx_c * 0.215, sy_c * 0.135, 0.0), brass_mat)

		"toolbox":
			_add_box(model_pivot, Vector3(0.44, 0.20, 0.22), Vector3(0.0, -0.04, 0.0), red_mat)
			_add_prism(model_pivot, Vector3(0.44, 0.10, 0.22), Vector3(0.0, 0.11, 0.0), red_mat)
			_add_box(model_pivot, Vector3(0.20, 0.04, 0.04), Vector3(0.0, 0.18, 0.0), chrome_mat)
			_add_box(model_pivot, Vector3(0.07, 0.07, 0.235), Vector3(0.0, 0.04, 0.0), brass_mat)

		_:
			# Specialty items fallback (antibiotics, antirad, scrap, fuel, vehicle parts)
			var spec_mat: StandardMaterial3D = _make_mat(item_col, 0.55, 0.15)
			_add_box(model_pivot, Vector3(0.30, 0.24, 0.20), Vector3.ZERO, spec_mat)
			_add_box(model_pivot, Vector3(0.31, 0.05, 0.21), Vector3.ZERO, yel_mat)

	return root
