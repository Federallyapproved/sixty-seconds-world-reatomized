class_name FamilyFigure3D
extends Node3D

## A family member as a 3D figure: a Quaternius Universal Base Character body (CC0) wearing
## clothes painted on by assets/shaders/clothed_body.gdshader in the member's outfit colour and
## style, tinted skin and hair, child and teen proportions, and idle animations from the
## Universal Animation Library (assets/characters/family_anims.res).
##
## The free version of the kit has only the athletic ("Superhero") male and female bodies, so a
## child is the body scaled to about 1.15 m with a larger head, and a teen is slightly smaller.

const DIR: String = "res://assets/characters/ubc/"
const BODY_A: String = DIR + "Body_Male.gltf"
const BODY_B: String = DIR + "Body_Female.gltf"
const ANIMS: String = "res://assets/characters/family_anims.res"
const CLOTH_SHADER: String = "res://assets/shaders/clothed_body.gdshader"
const HAIR_SHADER: String = "res://assets/shaders/hair_tint.gdshader"
const SKIN_TEXTURE_AVG := Color("#a57757")
const ARM_PREFIXES: Array[String] = ["upperarm", "lowerarm", "hand", "index", "middle", "pinky", "ring", "thumb"]

# 2D hair style index -> [hair model for body A, for body B]
const HAIR_MODELS: Array = [
	["Hair_SimpleParted", "Hair_Long"],      # Side Part
	["Hair_SimpleParted", "Hair_Long"],      # Quiff
	["Hair_Long", "Hair_Long"],              # Bob
	["Hair_Buns", "Hair_Buns"],              # High Bun
	["Hair_Buns", "Hair_Buns"],              # Pigtails
	["Hair_Buzzed", "Hair_Buns"],            # Curly Afro (closest the free kit has)
	["Hair_Buzzed", "Hair_BuzzedFemale"],    # Buzz Cut
	["Hair_Buzzed", "Hair_BuzzedFemale"],    # Spiky
]
# 2D shirt style -> [sleeve, hem, neckline, dress]
const SHIRTS: Array = [
	[0.93, -0.12, 0.97, 0.0],   # Hoodie
	[0.93, -0.06, 0.95, 0.0],   # Quarter-Zip Fleece
	[0.32, -0.06, 0.88, 1.0],   # T-Shirt Dress
	[0.34, -0.06, 0.90, 0.0],   # Graphic Tee
	[0.95, -0.32, 0.97, 0.0],   # Rain Jacket
]
const TROUSERS: Array[String] = ["#3b4d6b", "#2b2c30", "#7d6f55", "#545a63", "#33415c"]
const SHOES: Array[String] = ["#2a2622", "#e4e1da", "#3a3027", "#22252b"]

static var _mesh_cache: Dictionary = {}
static var _anim_lib: AnimationLibrary = null
static var _cloth_shader: Shader = null
static var _hair_shader: Shader = null

var member: Dictionary = {}
var body_kind: String = "a"
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var _meshes: Array[MeshInstance3D] = []
var _body_mat: ShaderMaterial = null
var _outline: ShaderMaterial = null
var _idle: String = "Idle_Loop"


static func body_for(m: Dictionary) -> String:
	var b: String = str(m.get("body", ""))
	if b == "a" or b == "b":
		return b
	if int(m.get("facial_hair", 0)) > 0:
		return "a"
	var hs: int = int(m.get("hair_style", 0))
	if hs in [2, 3, 4] or int(m.get("shirt_style", 0)) == 2:
		return "b"
	return "a"


static func make(m: Dictionary) -> FamilyFigure3D:
	var f := FamilyFigure3D.new()
	f.member = m
	f.name = "Figure_" + str(m.get("id", "m"))
	f._build()
	return f


func _build() -> void:
	body_kind = body_for(member)
	var ps: PackedScene = load(BODY_A if body_kind == "a" else BODY_B)
	if ps == null:
		return
	var body: Node3D = ps.instantiate()
	add_child(body)
	skeleton = _find_skeleton(body)
	if skeleton == null:
		return
	var role: String = str(member.get("role", "adult"))
	var age: int = int(member.get("age", 35))
	var s: float = 0.97
	var head_s: float = 1.0
	if role == "child":
		s = clampf(0.5 + float(age) * 0.018, 0.56, 0.74)
		head_s = 1.24
	elif role == "teen":
		s = 0.92
		head_s = 1.05
	elif role == "elder":
		s = 0.95
	body.scale = Vector3.ONE * s
	var head: int = skeleton.find_bone("Head")
	if head >= 0 and head_s != 1.0:
		skeleton.set_bone_pose_scale(head, Vector3.ONE * head_s)
	for c in skeleton.get_children():
		if c is MeshInstance3D:
			_meshes.append(c)
	_dress()
	_add_hair()
	_add_animations(role)


## The body mesh with UV2 baked from the bind pose (cached per body).
func _dress() -> void:
	var hair_col := Color(str(member.get("hair_color", "#4a2e1b")))
	for mi in _meshes:
		var mat0: Material = mi.mesh.surface_get_material(0) if mi.mesh.get_surface_count() > 0 else null
		var mname: String = str(mi.name).to_lower()
		if mname.find("hero") >= 0:
			if not HouseBuilder3D.no_mesh_data():
				mi.mesh = _baked_body_mesh(mi)
			_body_mat = ShaderMaterial.new()
			_body_mat.shader = _cloth()
			if mat0 is StandardMaterial3D:
				_body_mat.set_shader_parameter("body_tex", (mat0 as StandardMaterial3D).albedo_texture)
				_body_mat.set_shader_parameter("normal_tex", (mat0 as StandardMaterial3D).normal_texture)
			_apply_outfit(_body_mat)
			mi.material_override = _body_mat
		elif mname.find("eyebrow") >= 0:
			mi.material_override = _hair_material(mat0, hair_col)


func _apply_outfit(mat: ShaderMaterial) -> void:
	var skin: Color = skin_color(member)
	mat.set_shader_parameter("skin_color", Vector3(skin.r, skin.g, skin.b))
	mat.set_shader_parameter("top_color", outfit_color(member))
	var h: int = absi(hash(str(member.get("id", "")) + str(member.get("name", ""))))
	mat.set_shader_parameter("bottom_color", _away_from(Color(TROUSERS[h % TROUSERS.size()]), skin))
	mat.set_shader_parameter("shoe_color", Color(SHOES[(h / 7) % SHOES.size()]))
	var sh: Array = SHIRTS[clampi(int(member.get("shirt_style", 0)), 0, SHIRTS.size() - 1)]
	mat.set_shader_parameter("sleeve", float(sh[0]))
	mat.set_shader_parameter("hem", float(sh[1]))
	mat.set_shader_parameter("collar", float(sh[2]))
	mat.set_shader_parameter("dress", float(sh[3]))


static func skin_color(m: Dictionary) -> Color:
	var skin_idx: int = clampi(int(m.get("skin_tone", 1)), 0, CharacterArtist.SKIN_TONES.size() - 1)
	return Color(CharacterArtist.SKIN_TONES[skin_idx])


## The member's outfit colour, nudged away from their skin tone when the two are close, so
## painted-on clothes never read as bare skin.
static func outfit_color(m: Dictionary) -> Color:
	return _away_from(Color(str(m.get("outfit_color", "#3d7a8a"))), skin_color(m))


static func _away_from(c: Color, skin: Color) -> Color:
	var d: float = Vector3(c.r - skin.r, c.g - skin.g, c.b - skin.b).length()
	if d >= 0.28:
		return c
	# Too close: shift darker (or lighter for very dark skin) and a little more saturated.
	var out: Color = c.darkened(0.42) if skin.get_luminance() > 0.3 else c.lightened(0.45)
	out.s = minf(1.0, out.s * 1.25)
	return out


func _add_hair() -> void:
	var hs: int = clampi(int(member.get("hair_style", 0)), 0, HAIR_MODELS.size() - 1)
	var models: Array[String] = [str(HAIR_MODELS[hs][0 if body_kind == "a" else 1])]
	if int(member.get("facial_hair", 0)) in [1, 2]:
		models.append("Hair_Beard")
	var col := Color(str(member.get("hair_color", "#4a2e1b")))
	for m in models:
		var ps: PackedScene = load(DIR + m + ".gltf")
		if ps == null:
			continue
		var inst: Node = ps.instantiate()
		var src: MeshInstance3D = _find_mesh(inst)
		if src != null:
			var mi := MeshInstance3D.new()
			mi.name = m
			mi.mesh = src.mesh
			mi.skin = src.skin
			skeleton.add_child(mi)
			mi.skeleton = NodePath("..")
			mi.material_override = _hair_material(src.mesh.surface_get_material(0), col)
			_meshes.append(mi)
		inst.free()


func _add_animations(role: String) -> void:
	if _anim_lib == null and ResourceLoader.exists(ANIMS):
		_anim_lib = load(ANIMS)
	if _anim_lib == null:
		return
	anim_player = AnimationPlayer.new()
	anim_player.name = "Anim"
	skeleton.get_parent().add_child(anim_player)
	anim_player.root_node = NodePath("..")
	anim_player.add_animation_library("", _anim_lib)
	match role:
		"child":
			_idle = "Crouch_Idle_Loop"
		"teen":
			_idle = "Idle_FoldArms_Loop"
		"elder":
			_idle = "Idle_Loop"
		_:
			_idle = "Idle_TalkingPhone_Loop"
	play(_idle)
	if anim_player.has_animation(_idle):
		anim_player.seek(randf() * anim_player.get_animation(_idle).length, true)


func play(clip: String, blend: float = 0.25) -> void:
	if anim_player != null and anim_player.has_animation(clip):
		anim_player.play(clip, blend)


func idle_clip() -> String:
	return _idle


## Amber outline while aimed at, none otherwise.
func set_highlight(on: bool) -> void:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = load(PropLibrary.OUTLINE_SHADER)
		_outline.set_shader_parameter("mode", 0)
		_outline.set_shader_parameter("width", 0.01)
		_outline.set_shader_parameter("color", PropLibrary.OUTLINE_AIM)
	for mi in _meshes:
		# Hair is alpha-tested cards: an inverted hull around them is a blob, so only the body.
		if str(mi.name).to_lower().find("hero") >= 0:
			mi.material_overlay = _outline if on else null
	if _body_mat != null:
		_body_mat.set_shader_parameter("tint_flash", 0.6 if on else 0.0)


func height_m() -> float:
	var s: float = 1.0
	for c in get_children():
		if c is Node3D:
			s = (c as Node3D).scale.y
	return (1.8 if body_kind == "a" else 1.75) * s


# ------------------------------------------------------------------------------

static func _cloth() -> Shader:
	if _cloth_shader == null:
		_cloth_shader = load(CLOTH_SHADER)
	return _cloth_shader


static func _hair_material(src: Material, col: Color) -> ShaderMaterial:
	if _hair_shader == null:
		_hair_shader = load(HAIR_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _hair_shader
	if src is StandardMaterial3D:
		m.set_shader_parameter("hair_tex", (src as StandardMaterial3D).albedo_texture)
		m.set_shader_parameter("normal_tex", (src as StandardMaterial3D).normal_texture)
	m.set_shader_parameter("hair_color", col)
	return m


## Bakes UV2 = (height on the torso scale, distance along the arm) from the bind pose.
func _baked_body_mesh(mi: MeshInstance3D) -> Mesh:
	var key: String = body_kind
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var src: Mesh = mi.mesh
	var arrays: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var nv: int = verts.size()
	var per: int = bones.size() / maxi(1, nv)
	var skin: Skin = mi.skin
	var arm_side: Dictionary = {}   # bind index -> "l" / "r"
	for b in range(skin.get_bind_count()):
		var bn: String = str(skin.get_bind_name(b))
		for pre in ARM_PREFIXES:
			if bn.begins_with(pre):
				arm_side[b] = "l" if bn.ends_with("_l") else "r"
				break
	var hip_y: float = skeleton.get_bone_global_rest(skeleton.find_bone("pelvis")).origin.y
	var neck_y: float = skeleton.get_bone_global_rest(skeleton.find_bone("neck_01")).origin.y
	var span: float = maxf(0.1, neck_y - hip_y)
	var shoulder := {
		"l": skeleton.get_bone_global_rest(skeleton.find_bone("upperarm_l")).origin,
		"r": skeleton.get_bone_global_rest(skeleton.find_bone("upperarm_r")).origin}
	var wrist := {
		"l": skeleton.get_bone_global_rest(skeleton.find_bone("hand_l")).origin,
		"r": skeleton.get_bone_global_rest(skeleton.find_bone("hand_r")).origin}
	var uv2 := PackedVector2Array()
	uv2.resize(nv)
	for i in range(nv):
		var v: Vector3 = verts[i]
		var wl: float = 0.0
		var wr: float = 0.0
		for k in range(per):
			var bi: int = bones[i * per + k]
			var w: float = weights[i * per + k]
			if arm_side.has(bi):
				if arm_side[bi] == "l":
					wl += w
				else:
					wr += w
		var t: float = 0.0
		if wl + wr > 0.5:
			var sd: String = "l" if wl >= wr else "r"
			var a: Vector3 = shoulder[sd]
			var ab: Vector3 = (wrist[sd] as Vector3) - a
			t = clampf((v - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.003, 1.4)
		else:
			# Torso and legs: minus the distance from the centre line (the neckline rises with it).
			t = -absf(v.x) / span
		uv2[i] = Vector2((v.y - hip_y) / span, t)
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	# Custom channels come back unpacked and can't be fed straight back in; the body doesn't use them.
	for ch in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[ch] = null
	var out := ArrayMesh.new()
	var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_mesh_cache[key] = out
	return out


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_skeleton(c)
		if r != null:
			return r
	return null


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r: MeshInstance3D = _find_mesh(c)
		if r != null:
			return r
	return null
