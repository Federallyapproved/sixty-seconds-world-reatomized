class_name PropLibrary
extends RefCounted

## 3D furniture and item props for the first-person grab.
##
## Furniture comes from Kenney's Furniture and Survival kits (CC0); items use Kenney's Food,
## Survival and Furniture models where one fits, and otherwise a small prop built here from
## primitives (box, cylinder, sphere, torus) with vertex colours, merged into one mesh so each
## item is a single draw call. Every model is fitted to a target size in metres, so the kits'
## own scales don't matter.

const FURN: String = "res://assets/models/furniture/"
const SURV: String = "res://assets/models/survival/"
const FOOD: String = "res://assets/models/food/"
const OUTLINE_SHADER: String = "res://assets/shaders/outline.gdshader"

const OUTLINE_IDLE := Color(1.0, 0.86, 0.55)
const OUTLINE_AIM := Color(1.0, 0.69, 0.13)
const OUTLINE_NEED := Color(1.0, 0.55, 0.1)

static var _scenes: Dictionary = {}
static var _aabbs: Dictionary = {}
static var _tuned: Dictionary = {}
static var _vc_mat: StandardMaterial3D = null
static var _glow_tex: Texture2D = null

# ------------------------------------------------------------------------------
# Furniture: kind -> list of parts. Each part: [model, x, z, w, h, d, y, yaw_deg] in the
# piece's local frame (front faces +Z, footprint centred on 0). Sizes < 0 are fractions of the
# footprint (-1 = full width or depth). "@" models are built here.
# ------------------------------------------------------------------------------
const FURNITURE: Dictionary = {
	"sofa": [["loungeSofa", 0, 0, -1, 0.85, -1, 0, 0]],
	"armchair": [["loungeChair", 0, 0, -1, 0.85, -1, 0, 0]],
	"coffee_table": [["tableCoffee", 0, 0, -1, 0.42, -1, 0, 0], ["books", 0.2, 0, 0.22, 0.08, 0.16, 0.42, 20]],
	"bookshelf": [["bookcaseOpen", 0, 0, -1, 1.85, -1, 0, 0], ["books", -0.15, 0, 0.3, 0.12, 0.2, 0.92, 0]],
	"tv_console": [["cabinetTelevision", 0, 0, -1, 0.5, -1, 0, 0], ["televisionModern", 0, -0.05, -0.75, 0.55, 0.18, 0.5, 0]],
	"rug": [["rugRectangle", 0, 0, -1, 0.02, -1, 0, 0]],
	"counter": [["@counter", 0, 0, -1, 0.92, -1, 0, 0]],
	"stove": [["kitchenStove", 0, 0, -1, 0.92, -1, 0, 0], ["hoodModern", 0, -0.1, -0.9, 0.5, 0.5, 1.55, 0]],
	"fridge": [["kitchenFridgeLarge", 0, 0, -1, 1.85, -1, 0, 0]],
	"kitchen_table": [["table", 0, 0, -0.8, 0.76, -0.8, 0, 0], ["chair", -0.32, 0.42, 0.45, 0.9, 0.45, 0, 180], ["chair", 0.32, -0.42, 0.45, 0.9, 0.45, 0, 0]],
	"pantry_shelf": [["bookcaseOpen", 0, 0, -1, 1.8, -1, 0, 0], ["cardboardBoxOpen", 0.2, 0, 0.3, 0.22, 0.25, 0.42, 10]],
	"dining_table": [["tableCloth", 0, 0, -0.85, 0.76, -0.8, 0, 0], ["chair", -0.4, 0.55, 0.45, 0.9, 0.45, 0, 180], ["chair", 0.4, 0.55, 0.45, 0.9, 0.45, 0, 180], ["chair", -0.4, -0.55, 0.45, 0.9, 0.45, 0, 0], ["chair", 0.4, -0.55, 0.45, 0.9, 0.45, 0, 0]],
	"sideboard": [["sideTableDrawers", 0, 0, -1, 0.85, -1, 0, 0], ["lampRoundTable", 0.4, 0, 0.25, 0.45, 0.25, 0.85, 0]],
	"china_cabinet": [["bookcaseClosedWide", 0, 0, -1, 1.9, -1, 0, 0]],
	"bed_double": [["bedDouble", 0, 0, -1, 0.95, -1, 0, 0]],
	"dresser": [["cabinetBedDrawer", 0, 0, -1, 0.9, -1, 0, 0]],
	"wardrobe": [["bookcaseClosedDoors", 0, 0, -1, 2.0, -1, 0, 0]],
	"nightstand": [["cabinetBedDrawerTable", 0, 0, -1, 0.55, -1, 0, 0], ["lampRoundTable", 0, 0, 0.22, 0.4, 0.22, 0.55, 0]],
	"bed_single": [["bedSingle", 0, 0, -1, 0.9, -1, 0, 0]],
	"desk": [["desk", 0, 0, -1, 0.76, -1, 0, 0], ["chairDesk", 0, 0.45, 0.5, 0.95, 0.5, 0, 180], ["laptop", 0.1, -0.05, 0.34, 0.24, 0.26, 0.76, 0]],
	"toy_chest": [["S:chest", 0, 0, -1, 0.5, -1, 0, 0]],
	"bunk_shelf": [["bookcaseOpenLow", 0, 0, -1, 1.1, -1, 0, 0]],
	"bathtub": [["bathtub", 0, 0, -1, 0.6, -1, 0, 0]],
	"sink": [["bathroomSink", 0, 0, -1, 0.9, -1, 0, 0], ["bathroomMirror", 0, -0.48, -0.8, 0.7, 0.06, 1.25, 0]],
	"linen_shelf": [["bathroomCabinet", 0, 0, -1, 1.6, -1, 0, 0]],
	"washer": [["washer", 0, 0, -1, 0.9, -1, 0, 0]],
	"water_heater": [["@heater", 0, 0, -1, 1.5, -1, 0, 0]],
	"tool_bench": [["S:workbench", 0, 0, -1, 0.95, -1, 0, 0]],
	"boxes": [["cardboardBoxClosed", -0.15, 0.05, -0.55, 0.5, -0.7, 0, 8], ["cardboardBoxClosed", 0.2, -0.1, -0.45, 0.42, -0.6, 0, -14], ["cardboardBoxOpen", -0.1, 0, -0.4, 0.34, -0.5, 0.5, 30]],
	"filing_cabinet": [["sideTableDrawers", 0, 0, -1, 1.2, -1, 0, 0]],
	"coat_rack": [["coatRackStanding", 0, 0, -1, 1.8, -1, 0, 0]],
	"umbrella_stand": [["trashcan", 0, 0, -1, 0.6, -1, 0, 0]],
	"old_trunk": [["S:chest", 0, 0, -1, 0.55, -1, 0, 0]],
	"paint_cans": [["S:bucket", -0.12, 0, -0.5, 0.35, -0.5, 0, 0], ["S:bucket", 0.14, 0.08, -0.45, 0.3, -0.45, 0, 40]],
	"built_in": [["@closet", 0, 0, -1, 2.35, -1, 0, 0]],
	# Knocked over in the rush: [.., roll_deg] lays it on its side.
	"toppled_chair": [["chair", 0, 0, 0.45, 0.9, 0.45, 0.23, 25, 90]],
}

# Items: id -> [model or "@recipe", target height m, lying flat?]
const ITEMS: Dictionary = {
	"food": ["F:can", 0.2, false],
	"water": ["@water_jug", 0.34, false],
	"axe": ["S:tool-axe", 0.62, true],
	"radio": ["radio", 0.26, false],
	"manual": ["books", 0.16, false],
	"toaster": ["toaster", 0.24, false],
	"smart_speaker": ["speakerSmall", 0.22, false],
	"pots_pans": ["F:pot", 0.2, false],
	"bottles": ["@bottles", 0.34, false],
	"medkit": ["@medkit", 0.2, false],
	"flashlight": ["@flashlight", 0.1, false],
	"gas_mask": ["@gas_mask", 0.26, false],
	"rifle": ["@rifle", 0.12, false],
	"ammo": ["@ammo", 0.16, false],
	"padlock": ["@padlock", 0.16, false],
	"map": ["@map", 0.06, false],
	"cards": ["@cards", 0.06, false],
	"console": ["@console", 0.06, false],
	"bug_spray": ["@spray_can", 0.26, false],
	"suitcase": ["@suitcase", 0.5, false],
	"old_phone": ["@phone", 0.03, false],
	"bedsheet": ["@bedsheet", 0.16, false],
	"umbrella": ["@umbrella", 0.1, false],
	"cleaning_spray": ["@cleaning_spray", 0.3, false],
	"sanitizer": ["@sanitizer", 0.22, false],
	"duct_tape": ["@duct_tape", 0.07, false],
	"extension_cord": ["@cord", 0.1, false],
}


static func model_path(name: String) -> String:
	if name.begins_with("S:"):
		return SURV + name.substr(2) + ".glb"
	if name.begins_with("F:"):
		return FOOD + name.substr(2) + ".glb"
	return FURN + name + ".glb"


static func packed(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


## Merged AABB of a model's meshes in its own space (cached).
static func model_aabb(path: String) -> AABB:
	if _aabbs.has(path):
		return _aabbs[path]
	var ps: PackedScene = packed(path)
	var box := AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
	if ps != null:
		var n: Node3D = ps.instantiate()
		var acc: Array = [false, AABB()]
		_accum_aabb(n, Transform3D.IDENTITY, acc)
		if bool(acc[0]):
			box = acc[1]
		n.free()
	_aabbs[path] = box
	return box


static func _accum_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var here: Transform3D = xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = here * (n as MeshInstance3D).mesh.get_aabb()
		if bool(acc[0]):
			acc[1] = (acc[1] as AABB).merge(b)
		else:
			acc[0] = true
			acc[1] = b
	for c in n.get_children():
		_accum_aabb(c, here, acc)


## An instance of `path` scaled to exactly `size` (w, h, d), base at y = 0, centred on x/z.
static func fitted(path: String, size: Vector3) -> Node3D:
	var ps: PackedScene = packed(path)
	var holder := Node3D.new()
	if ps == null:
		return holder
	var inst: Node3D = ps.instantiate()
	_tune_materials(inst)
	var box: AABB = model_aabb(path)
	var sc := Vector3(
		size.x / maxf(0.001, box.size.x),
		size.y / maxf(0.001, box.size.y),
		size.z / maxf(0.001, box.size.z))
	var c: Vector3 = box.get_center()
	inst.transform = Transform3D(Basis.from_scale(sc), Vector3(-c.x * sc.x, -box.position.y * sc.y, -c.z * sc.z))
	holder.add_child(inst)
	return holder


## Kenney's pastel palette reads washed out under room lights: deepen it a little and share one
## material per colour across every model (fewer state changes on the web).
static func _tune_materials(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi: MeshInstance3D = n
		for i in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				mi.set_surface_override_material(i, _tuned_material(m))
	for c in n.get_children():
		_tune_materials(c)


static func _tuned_material(m: StandardMaterial3D) -> StandardMaterial3D:
	var key: String = "%s|%s|%s" % [m.resource_name, m.albedo_color.to_html(), str(m.albedo_texture.resource_path if m.albedo_texture != null else "")]
	if _tuned.has(key):
		return _tuned[key]
	var t: StandardMaterial3D = m.duplicate()
	var c: Color = m.albedo_color
	var lum: float = c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	if m.albedo_texture == null:
		# Deeper, slightly more saturated; near-whites (sheets, appliances) only a touch.
		var k: float = 0.9 if lum > 0.85 else 0.74
		var gray: float = lum * k
		t.albedo_color = Color(lerpf(gray, c.r * k, 1.15), lerpf(gray, c.g * k, 1.15), lerpf(gray, c.b * k, 1.15), c.a)
	else:
		t.albedo_color = c.darkened(0.08)
	t.roughness = maxf(m.roughness, 0.62)
	_tuned[key] = t
	return t


## Builds one piece of furniture of `kind` with footprint w x d (metres), front facing +Z.
static func furniture(kind: String, w: float, d: float, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "F_" + kind
	var parts: Array = FURNITURE.get(kind, [["cardboardBoxClosed", 0, 0, -0.8, 0.5, -0.8, 0, 0]])
	for p_v in parts:
		var p: Array = p_v
		var model: String = str(p[0])
		var pw: float = float(p[3])
		var ph: float = float(p[4])
		var pd: float = float(p[5])
		pw = -pw * w if pw < 0.0 else pw
		pd = -pd * d if pd < 0.0 else pd
		var px: float = float(p[1]) * (w if absf(float(p[1])) <= 1.0 else 1.0)
		var pz: float = float(p[2]) * (d if absf(float(p[2])) <= 1.0 else 1.0)
		var node: Node3D
		if model.begins_with("@"):
			node = _builtin_furniture(model.substr(1), pw, ph, pd, rng)
		else:
			node = fitted(model_path(model), Vector3(pw, ph, pd))
		node.position = Vector3(px, float(p[6]), pz)
		node.rotation.y = deg_to_rad(float(p[7]))
		if p.size() > 8:
			node.rotation.z = deg_to_rad(float(p[8]))
		root.add_child(node)
	return root


static func _builtin_furniture(kind: String, w: float, h: float, d: float, rng: RandomNumberGenerator) -> Node3D:
	match kind:
		"counter":
			var n := Node3D.new()
			var mods: int = maxi(1, int(round(w / 0.6)))
			var mw: float = w / float(mods)
			var sink_at: int = mods / 2 if mods >= 3 else -1
			for i in range(mods):
				var m: String = "kitchenSink" if i == sink_at else ("kitchenCabinetDrawer" if i % 2 == 0 else "kitchenCabinet")
				var piece: Node3D = fitted(model_path(m), Vector3(mw, h, d))
				piece.position.x = -w * 0.5 + mw * (float(i) + 0.5)
				n.add_child(piece)
				var up: Node3D = fitted(model_path("kitchenCabinetUpper"), Vector3(mw, 0.7, minf(0.35, d * 0.6)))
				up.position = Vector3(piece.position.x, 1.45, -d * 0.5 + minf(0.35, d * 0.6) * 0.5)
				n.add_child(up)
			var extra: String = "kitchenMicrowave" if rng.randf() < 0.5 else "kitchenCoffeeMachine"
			var app: Node3D = fitted(model_path(extra), Vector3(0.45, 0.3, 0.35) if extra == "kitchenMicrowave" else Vector3(0.22, 0.32, 0.24))
			app.position = Vector3(w * 0.5 - 0.35, h, -d * 0.15)
			n.add_child(app)
			return n
		"heater":
			var mi := MeshInstance3D.new()
			mi.mesh = merged_mesh([["cyl", Vector3(minf(w, d) * 0.45, h, 0), Vector3(0, h * 0.5, 0), Color("#e8e6e1")], ["cyl", Vector3(0.04, 0.25, 0), Vector3(0, h + 0.12, 0), Color("#9aa0a6")]])
			mi.material_override = vertex_color_material()
			var n2 := Node3D.new()
			n2.add_child(mi)
			return n2
		"closet":
			var mi2 := MeshInstance3D.new()
			mi2.mesh = merged_mesh([
				["box", Vector3(w, h, d), Vector3(0, h * 0.5, 0), Color("#e9e4da")],
				["box", Vector3(0.02, h * 0.86, 0.012), Vector3(0, h * 0.47, d * 0.5 + 0.006), Color("#b9b2a6")],
				["box", Vector3(0.03, 0.18, 0.03), Vector3(-0.06, h * 0.48, d * 0.5 + 0.02), Color("#6f6a62")],
				["box", Vector3(0.03, 0.18, 0.03), Vector3(0.06, h * 0.48, d * 0.5 + 0.02), Color("#6f6a62")],
			])
			mi2.material_override = vertex_color_material()
			var n3 := Node3D.new()
			n3.add_child(mi2)
			return n3
	return Node3D.new()


# ------------------------------------------------------------------------------
# Items
# ------------------------------------------------------------------------------

## The 3D prop for an item, base on the floor at the origin. `needed` items (junk holding parts the
## workbench asked for) get an orange ring under them.
static func item(item_id: String, needed: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "I_" + item_id
	var spec: Array = ITEMS.get(item_id, ["@box", 0.2, false])
	var model: String = str(spec[0])
	var h: float = float(spec[1])
	var body: Node3D
	if model.begins_with("@"):
		var mi := MeshInstance3D.new()
		mi.mesh = merged_mesh(_recipe(model.substr(1)))
		mi.material_override = vertex_color_material()
		body = Node3D.new()
		body.add_child(mi)
	else:
		var path: String = model_path(model)
		var box: AABB = model_aabb(path)
		var lying: bool = bool(spec[2])
		# Standing: h is the height. Lying on the floor: h is the length of the longest side.
		var s: float = h / maxf(0.001, box.size.y if not lying else maxf(box.size.x, maxf(box.size.y, box.size.z)))
		var fit: Node3D = fitted(path, box.size * s)
		if lying and box.size.y >= maxf(box.size.x, box.size.z):
			var pivot := Node3D.new()
			fit.position.y = -box.size.y * s * 0.5
			pivot.add_child(fit)
			pivot.rotation.z = PI * 0.5
			pivot.position.y = box.size.x * s * 0.5
			body = Node3D.new()
			body.add_child(pivot)
		else:
			body = fit
	root.add_child(body)
	if not needed:
		add_outline(root, OUTLINE_IDLE, 0.012, 1, Vector3(0.0, h * 0.5, 0.0))
		return root
	# Junk the workbench asked for gets an orange ring under it.
	var disc := MeshInstance3D.new()
	var r: float = (0.55 if item_id == "suitcase" else 0.42) * 1.5
	disc.mesh = merged_mesh([["quad", Vector3(r, r, 0), Vector3.ZERO, Color.WHITE, Vector3(-90, 0, 0)]])
	disc.position.y = 0.012
	disc.material_override = _disc_material(item_id, needed)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.name = "Glow"
	root.add_child(disc)
	add_outline(root, OUTLINE_NEED, 0.012, 1, Vector3(0.0, h * 0.5, 0.0))
	return root


## Gives every mesh under `n` the outline as a material overlay (one material per call, so the
## caller can recolour it, e.g. when the item is aimed at).
static func add_outline(n: Node, col: Color, width: float, mode: int, center: Vector3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(OUTLINE_SHADER)
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("center", center)
	_apply_overlay(n, mat)
	n.set_meta("outline", mat)
	return mat


static func _apply_overlay(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D and n.name != "Glow":
		(n as GeometryInstance3D).material_overlay = mat
	for c in n.get_children():
		_apply_overlay(c, mat)


static func set_aimed(item_node: Node, aimed: bool, needed: bool = false) -> void:
	if item_node == null or not item_node.has_meta("outline"):
		return
	var mat: ShaderMaterial = item_node.get_meta("outline")
	if aimed:
		_apply_overlay(item_node, mat)
		item_node.set_meta("outlined", true)
	mat.set_shader_parameter("color", OUTLINE_AIM if aimed else (OUTLINE_NEED if needed else OUTLINE_IDLE))
	mat.set_shader_parameter("width", 0.022 if aimed else 0.012)
	mat.set_shader_parameter("pulse", 1.0 if aimed else 0.0)


static func _disc_material(item_id: String, needed: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = glow_texture()
	var c := Color(1.0, 0.72, 0.25, 0.55)
	if item_id == "water":
		c = Color(0.35, 0.65, 1.0, 0.55)
	elif item_id == "food":
		c = Color(1.0, 0.6, 0.3, 0.55)
	if needed:
		c = Color(1.0, 0.45, 0.08, 0.8)
	m.albedo_color = c
	m.no_depth_test = false
	return m


static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.35))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_glow_tex = t
	return _glow_tex


static func vertex_color_material() -> StandardMaterial3D:
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.roughness = 0.72
	return _vc_mat


# Recipes: [shape, size, position, colour, (rotation degrees)]. Sizes: box (w,h,d); cyl (radius,
# height, top radius or 0 = same); sphere (radius, height); torus (inner, outer). Base at y = 0.
static func _recipe(id: String) -> Array:
	match id:
		"water_jug":
			return [["box", Vector3(0.2, 0.26, 0.2), Vector3(0, 0.13, 0), Color("#8fc4e8")],
				["box", Vector3(0.17, 0.02, 0.17), Vector3(0, 0.27, 0), Color("#a9d3ee")],
				["cyl", Vector3(0.035, 0.05, 0), Vector3(0.0, 0.3, 0.0), Color("#2f6fb0")],
				["box", Vector3(0.03, 0.12, 0.08), Vector3(0.1, 0.2, 0.0), Color("#a9d3ee")],
				["box", Vector3(0.202, 0.08, 0.202), Vector3(0, 0.11, 0), Color("#f2f2f2")],
				["box", Vector3(0.204, 0.025, 0.204), Vector3(0, 0.11, 0), Color("#2f6fb0")]]
		"medkit":
			return [["box", Vector3(0.34, 0.16, 0.24), Vector3(0, 0.08, 0), Color("#c8312b")],
				["box", Vector3(0.16, 0.012, 0.05), Vector3(0, 0.166, 0), Color("#f4f1ea")],
				["box", Vector3(0.05, 0.012, 0.16), Vector3(0, 0.166, 0), Color("#f4f1ea")],
				["box", Vector3(0.12, 0.035, 0.03), Vector3(0, 0.19, -0.1), Color("#2a2a2a")]]
		"flashlight":
			return [["cyl", Vector3(0.035, 0.2, 0), Vector3(0, 0.04, 0), Color("#222326"), Vector3(0, 0, 90)],
				["cyl", Vector3(0.05, 0.07, 0.036), Vector3(0.13, 0.05, 0), Color("#3a3d42"), Vector3(0, 0, -90)],
				["cyl", Vector3(0.042, 0.006, 0), Vector3(0.168, 0.05, 0), Color("#fff4c2"), Vector3(0, 0, 90)],
				["box", Vector3(0.03, 0.02, 0.025), Vector3(-0.02, 0.08, 0), Color("#c84b31")]]
		"gas_mask":
			return [["sphere", Vector3(0.12, 0.2, 0), Vector3(0, 0.12, 0), Color("#3b4238")],
				["cyl", Vector3(0.055, 0.08, 0), Vector3(0, 0.07, 0.12), Color("#5a5f52"), Vector3(90, 0, 0)],
				["cyl", Vector3(0.035, 0.02, 0), Vector3(-0.05, 0.16, 0.1), Color("#9bc6d8"), Vector3(70, 0, 0)],
				["cyl", Vector3(0.035, 0.02, 0), Vector3(0.05, 0.16, 0.1), Color("#9bc6d8"), Vector3(70, 0, 0)],
				["torus", Vector3(0.1, 0.12, 0), Vector3(0, 0.14, -0.04), Color("#1f211e"), Vector3(80, 0, 0)]]
		"rifle":
			return [["box", Vector3(0.36, 0.08, 0.05), Vector3(-0.32, 0.05, 0), Color("#6e4a2c")],
				["box", Vector3(0.3, 0.07, 0.05), Vector3(0.0, 0.06, 0), Color("#2b2d30")],
				["cyl", Vector3(0.014, 0.42, 0), Vector3(0.36, 0.07, 0), Color("#1d1f22"), Vector3(0, 0, 90)],
				["box", Vector3(0.12, 0.05, 0.04), Vector3(0.04, 0.12, 0), Color("#1d1f22")]]
		"ammo":
			return [["box", Vector3(0.26, 0.15, 0.13), Vector3(0, 0.075, 0), Color("#55603d")],
				["box", Vector3(0.262, 0.03, 0.132), Vector3(0, 0.11, 0), Color("#d9b43c")],
				["box", Vector3(0.1, 0.02, 0.03), Vector3(0, 0.16, 0), Color("#2f3324")]]
		"padlock":
			return [["box", Vector3(0.12, 0.1, 0.05), Vector3(0, 0.05, 0), Color("#c9a13d")],
				["torus", Vector3(0.03, 0.045, 0), Vector3(0, 0.11, 0), Color("#b7bcc2"), Vector3(90, 0, 0)],
				["cyl", Vector3(0.012, 0.012, 0), Vector3(0, 0.05, 0.026), Color("#3a2e14"), Vector3(90, 0, 0)]]
		"map":
			return [["box", Vector3(0.3, 0.012, 0.22), Vector3(0, 0.006, 0), Color("#e8dfc6"), Vector3(0, 12, 0)],
				["box", Vector3(0.12, 0.013, 0.08), Vector3(-0.04, 0.012, 0.02), Color("#7fa776"), Vector3(0, 12, 0)],
				["box", Vector3(0.2, 0.014, 0.02), Vector3(0.02, 0.014, -0.04), Color("#4a86b8"), Vector3(0, 30, 0)],
				["box", Vector3(0.15, 0.012, 0.22), Vector3(0.06, 0.03, 0), Color("#e1d6b8"), Vector3(0, 12, 14)]]
		"cards":
			return [["box", Vector3(0.1, 0.035, 0.07), Vector3(0, 0.018, 0), Color("#b8312b")],
				["box", Vector3(0.09, 0.006, 0.062), Vector3(0, 0.038, 0), Color("#f3efe4")],
				["box", Vector3(0.09, 0.004, 0.062), Vector3(0.11, 0.003, 0.02), Color("#f3efe4"), Vector3(0, 25, 0)]]
		"console":
			return [["box", Vector3(0.22, 0.03, 0.1), Vector3(0, 0.015, 0), Color("#2c2f36")],
				["box", Vector3(0.1, 0.004, 0.065), Vector3(0, 0.032, 0), Color("#5ec4d8")],
				["cyl", Vector3(0.012, 0.012, 0), Vector3(0.08, 0.034, 0.01), Color("#d94a3a")],
				["cyl", Vector3(0.012, 0.012, 0), Vector3(-0.08, 0.034, 0.0), Color("#e8eaed")]]
		"spray_can":
			return [["cyl", Vector3(0.045, 0.2, 0), Vector3(0, 0.1, 0), Color("#5a8a3a")],
				["box", Vector3(0.092, 0.06, 0.004), Vector3(0, 0.11, 0.045), Color("#e9e3c8")],
				["cyl", Vector3(0.035, 0.05, 0.02), Vector3(0, 0.225, 0), Color("#f0f0f0")]]
		"suitcase":
			return [["box", Vector3(0.6, 0.42, 0.24), Vector3(0, 0.25, 0), Color("#2f4f73")],
				["box", Vector3(0.62, 0.03, 0.25), Vector3(0, 0.25, 0), Color("#22384f")],
				["box", Vector3(0.16, 0.03, 0.03), Vector3(0, 0.48, 0), Color("#1b1b1b")],
				["cyl", Vector3(0.025, 0.02, 0), Vector3(-0.25, 0.025, 0.08), Color("#1b1b1b"), Vector3(90, 0, 0)],
				["cyl", Vector3(0.025, 0.02, 0), Vector3(0.25, 0.025, 0.08), Color("#1b1b1b"), Vector3(90, 0, 0)]]
		"phone":
			return [["box", Vector3(0.08, 0.012, 0.16), Vector3(0, 0.006, 0), Color("#1c1d20"), Vector3(0, 20, 0)],
				["box", Vector3(0.068, 0.003, 0.14), Vector3(0, 0.013, 0), Color("#39495c"), Vector3(0, 20, 0)]]
		"bedsheet":
			return [["box", Vector3(0.42, 0.06, 0.32), Vector3(0, 0.03, 0), Color("#a8c4dc")],
				["box", Vector3(0.4, 0.05, 0.3), Vector3(0.01, 0.085, 0), Color("#b9d1e5"), Vector3(0, 6, 0)],
				["box", Vector3(0.38, 0.05, 0.29), Vector3(-0.01, 0.135, 0), Color("#a8c4dc"), Vector3(0, -4, 0)]]
		"umbrella":
			return [["cyl", Vector3(0.05, 0.62, 0.012), Vector3(0, 0.05, 0), Color("#25334a"), Vector3(0, 0, 90)],
				["cyl", Vector3(0.01, 0.25, 0), Vector3(-0.42, 0.05, 0), Color("#4a3a2a"), Vector3(0, 0, 90)],
				["torus", Vector3(0.025, 0.04, 0), Vector3(-0.56, 0.05, 0.03), Color("#4a3a2a"), Vector3(90, 0, 0)]]
		"cleaning_spray":
			return [["cyl", Vector3(0.045, 0.2, 0.04), Vector3(0, 0.1, 0), Color("#3fa7d6")],
				["box", Vector3(0.05, 0.05, 0.09), Vector3(0, 0.225, 0.02), Color("#f2f2f2")],
				["box", Vector3(0.015, 0.05, 0.02), Vector3(0, 0.19, 0.055), Color("#f2f2f2")]]
		"sanitizer":
			return [["cyl", Vector3(0.045, 0.15, 0.04), Vector3(0, 0.075, 0), Color("#d6eef2")],
				["cyl", Vector3(0.015, 0.04, 0), Vector3(0, 0.17, 0), Color("#ffffff")],
				["box", Vector3(0.05, 0.015, 0.015), Vector3(0, 0.195, 0.02), Color("#ffffff")]]
		"duct_tape":
			return [["torus", Vector3(0.04, 0.075, 0), Vector3(0, 0.035, 0), Color("#a9adb2")],
				["box", Vector3(0.08, 0.002, 0.05), Vector3(0.09, 0.001, 0), Color("#a9adb2")]]
		"cord":
			return [["torus", Vector3(0.07, 0.1, 0), Vector3(0, 0.02, 0), Color("#e07a2b")],
				["torus", Vector3(0.06, 0.09, 0), Vector3(0.01, 0.05, 0.01), Color("#e07a2b"), Vector3(0, 0, 8)],
				["box", Vector3(0.08, 0.05, 0.05), Vector3(0.15, 0.025, 0.05), Color("#f2efe8")],
				["box", Vector3(0.05, 0.035, 0.035), Vector3(-0.14, 0.02, -0.06), Color("#2b2b2b")]]
		"bottles":
			return [["cyl", Vector3(0.04, 0.22, 0.03), Vector3(-0.06, 0.11, 0), Color("#7fbf8f")],
				["cyl", Vector3(0.015, 0.06, 0), Vector3(-0.06, 0.25, 0), Color("#7fbf8f")],
				["cyl", Vector3(0.04, 0.2, 0.03), Vector3(0.06, 0.1, 0.03), Color("#c8d8e8")],
				["cyl", Vector3(0.015, 0.06, 0), Vector3(0.06, 0.23, 0.03), Color("#c8d8e8")],
				["cyl", Vector3(0.035, 0.18, 0.03), Vector3(0.0, 0.09, -0.07), Color("#8a5a2b")],
				["cyl", Vector3(0.013, 0.05, 0), Vector3(0.0, 0.205, -0.07), Color("#8a5a2b")],
				["box", Vector3(0.28, 0.12, 0.22), Vector3(0.0, 0.06, 0.0), Color("#d9cfae")]]
	return [["box", Vector3(0.25, 0.2, 0.2), Vector3(0, 0.1, 0), Color("#8a6a48")]]


## Merges primitive parts into one ArrayMesh with vertex colours.
static func merged_mesh(parts: Array) -> ArrayMesh:
	# Headless (dummy renderer) keeps no mesh data: no mesh at all (an empty one with a material
	# prints renderer errors when freed).
	if HouseBuilder3D.no_mesh_data():
		return null
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for p_v in parts:
		var p: Array = p_v
		var shape: String = str(p[0])
		var size: Vector3 = p[1]
		var pos: Vector3 = p[2]
		var col: Color = p[3]
		var rot: Vector3 = p[4] if p.size() > 4 else Vector3.ZERO
		var prim: PrimitiveMesh
		match shape:
			"box":
				var b := BoxMesh.new()
				b.size = size
				prim = b
			"cyl":
				var c := CylinderMesh.new()
				c.bottom_radius = size.x
				c.top_radius = size.z if size.z > 0.0 else size.x
				c.height = size.y
				c.radial_segments = 14
				c.rings = 1
				prim = c
			"sphere":
				var s := SphereMesh.new()
				s.radius = size.x
				s.height = size.y
				s.radial_segments = 14
				s.rings = 8
				prim = s
			"quad":
				# Built here rather than as a QuadMesh: headless runs keep no data for primitive meshes.
				var qm := QuadMesh.new()
				qm.size = Vector2(size.x, size.y)
				prim = qm
			"torus":
				var t := TorusMesh.new()
				t.inner_radius = size.x
				t.outer_radius = size.y
				t.rings = 16
				t.ring_segments = 8
				prim = t
			_:
				continue
		var arr: Array = prim.get_mesh_arrays()
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var puv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
		var base: int = verts.size()
		for i in range(pv.size()):
			verts.append(basis * pv[i] + pos)
			norms.append((basis * pn[i]).normalized())
			cols.append(col)
			uvs.append(puv[i] if i < puv.size() else Vector2.ZERO)
		for k in pi:
			idx.append(base + k)
	var out := ArrayMesh.new()
	if verts.is_empty():
		return out
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
