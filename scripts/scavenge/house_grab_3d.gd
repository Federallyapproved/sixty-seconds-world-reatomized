class_name HouseGrab3D
extends ScavengeScene

## The first-person house grab (spec section 12).
##
## Every rule is ScavengeScene's: hand slots, the timed grab, depositing at the hatch, carrying
## family to it, the look-around, the timer, the outro and the demo autopilot. Movement and
## collision still run on the floorplan (1 m = 46 px), so the 3D house needs no physics bodies;
## this class adds the 3D house, a first-person camera with mouse look, aim-based targeting with a
## generous reach, and a HUD with a crosshair. The top-down view stays available in Settings.

const PX: float = 46.0
const REACH_PX: float = 98.0        # 2.1 m: what you aim at within this reach can be grabbed
const NEAR_PX: float = 40.0         # anything this close counts even if it isn't under the crosshair
const AIM_CONE_DEG: float = 16.0
const TURN_KEYS_DEG: float = 150.0  # arrow-key turning, degrees per second
const FAMILY_HIDE_PX: float = 14.0   # a figure the camera is inside is hidden (people never block the way)
const OUTLINE_RANGE_PX: float = 230.0 # 5 m: items further away skip their outline pass (draw calls)

var _world: Node3D = null
var _cam: Camera3D = null
var _env: WorldEnvironment = null
var _house3d: Dictionary = {}
var _yaw: float = 0.0
var _pitch: float = -0.08
var _eye_h: float = 1.62
var _item_nodes: Dictionary = {}      # item uid -> Node3D
var _family_nodes: Dictionary = {}    # family uid -> FamilyFigure3D
var _furn_nodes: Array = []           # parallel to _furniture_props (null where nothing is drawn)
var _furn_base: Array = []
var _aimed_key: String = ""
var _room_idx: int = -1
var _hatch_prop_added: bool = false
var _rng := RandomNumberGenerator.new()
var _passed_filters: Array = []       # [Control, original mouse_filter] restored on exit
var _shadow_spot: SpotLight3D = null  # the one shadowed light: over the room the player is in
var show_perf: bool = false           # F3: frames per second and draw calls, for checking the web budget
var _portals: Dictionary = {}         # room index -> [{to, a, b}] doorways out of it (layout px)
var _shown_rooms: Dictionary = {}     # rooms drawn this frame: the player's and those seen through doorways


# ------------------------------------------------------------------------------
# Setup (ScavengeScene._ready calls these two)
# ------------------------------------------------------------------------------

func _setup_camera() -> void:
	_let_mouse_through()
	# Seeded from the house and this run's layout: the 3D view never draws from GameState.rng,
	# so the run's random sequence is the same in first person and top-down.
	_rng.seed = hash(str(GameState.selected_house.get("osm_id", 0)) + str(_leader_start_pos) + str(_hatch_pos))
	_world = Node3D.new()
	_world.name = "World3D"
	add_child(_world)
	_make_environment()
	_house3d = HouseBuilder3D.build(_house_layout)
	_world.add_child(_house3d["root"])
	# Room lights never cast shadows (an omni shadow is six passes on the web); one spot light,
	# moved to the ceiling of whichever room the player is in, does (one pass).
	_shadow_spot = SpotLight3D.new()
	_shadow_spot.name = "RoomShadow"
	_shadow_spot.light_color = Color(1.0, 0.93, 0.83)
	_shadow_spot.light_energy = 0.9
	_shadow_spot.spot_range = 5.0
	_shadow_spot.spot_angle = 68.0
	_shadow_spot.spot_attenuation = 0.8
	_shadow_spot.shadow_enabled = true
	_shadow_spot.shadow_blur = 1.5
	_shadow_spot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_world.add_child(_shadow_spot)
	_add_hatch_collision()
	_place_furniture()
	_place_items()
	_place_family()
	_build_portals()
	_cam = Camera3D.new()
	_cam.name = "Eyes"
	_cam.near = 0.05
	_cam.far = 60.0
	_cam.fov = GameSettings.fov()
	_world.add_child(_cam)
	_cam.make_current()
	if str(_leader_member.get("role", "adult")) == "teen":
		_eye_h = 1.52
	# Start looking at the hatch, so the way down is the first thing you see.
	var to_h: Vector2 = _hatch_pos - _player_pos
	if to_h.length() > 4.0:
		_yaw = atan2(-to_h.x, -to_h.y)
		_pitch = -clampf(atan2(_eye_h, to_h.length() / PX) * 0.7, 0.1, 0.6)
	_update_camera(0.0)


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "ScavengeHUDLayer"
	_hud_layer.layer = 12
	add_child(_hud_layer)
	var h := _Grab3DHUD.new()
	h.name = "ScavengeHUD"
	h.scene_ref = self
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(h)
	_hud = h


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.58, 0.54)
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	_env = WorldEnvironment.new()
	_env.environment = env
	_world.add_child(_env)


## The hatch is an opening in the floor: you stand at its rim, not over it.
func _add_hatch_collision() -> void:
	var h: float = HouseBuilder3D.HATCH_HALF * PX - 2.0
	var prop: Dictionary = _make_furniture_prop(Rect2(_hatch_pos - Vector2(h, h), Vector2(h, h) * 2.0), "hatch_hole", "Shelter hatch", COL_AMBER, true)
	prop["bump_cd"] = 1e9
	_furniture_props.append(prop)
	_hatch_prop_added = true
	_player_pos = _resolve_collisions(_player_pos, false)


## Furniture goes into its room and is merged with the room's other static props (draw calls).
func _place_furniture() -> void:
	_furn_nodes.clear()
	_furn_base.clear()
	var rooms: Array = _house3d.get("rooms", [])
	var holder := Node3D.new()
	holder.name = "Furniture"
	_world.add_child(holder)
	for prop_v in _furniture_props:
		var prop: Dictionary = prop_v
		var kind: String = str(prop.get("kind", ""))
		if kind == "hatch_hole":
			_furn_nodes.append(null)
			_furn_base.append(Transform3D.IDENTITY)
			continue
		var r: Rect2 = prop["rect"]
		var yaw: float = _furniture_yaw(r, kind)
		var turned: bool = absf(sin(yaw)) > 0.5
		var w: float = (r.size.y if turned else r.size.x) / PX
		var d: float = (r.size.x if turned else r.size.y) / PX
		var node: Node3D = PropLibrary.furniture(kind, w, d, _rng)
		node.transform = Transform3D(Basis(Vector3.UP, yaw), HouseBuilder3D.to3(r.get_center()))
		var ri: int = HouseBuilder3D._room_at(rooms, r.get_center())
		if ri >= 0:
			(rooms[ri]["node"] as Node3D).add_child(node)
		else:
			holder.add_child(node)
		_furn_nodes.append(null)
		_furn_base.append(node.transform)
	for rm in rooms:
		var merged: MeshInstance3D = HouseBuilder3D.merge_statics(rm["node"], ["Floor", "Ceiling", "Walls", "Trim"])
		if merged != null:
			merged.visibility_range_end = 26.0


func _place_items() -> void:
	var holder := Node3D.new()
	holder.name = "Items"
	_world.add_child(holder)
	for it_v in _world_items:
		var it: Dictionary = it_v
		var node: Node3D = PropLibrary.item(str(it["item_id"]), bool(it.get("needed", false)))
		node.position = HouseBuilder3D.to3(it["pos"])
		node.rotation.y = _rng.randf_range(-PI, PI)
		_set_visibility_range(node, 14.0)
		_no_shadows(node)
		holder.add_child(node)
		_item_nodes[int(it["uid"])] = node


func _place_family() -> void:
	var holder := Node3D.new()
	holder.name = "Family"
	_world.add_child(holder)
	for f_v in _world_family:
		var fam: Dictionary = f_v
		var fig: FamilyFigure3D = FamilyFigure3D.make(fam["member"])
		fig.position = HouseBuilder3D.to3(fam["pos"])
		var to_p: Vector2 = _leader_start_pos - (fam["pos"] as Vector2)
		fig.rotation.y = atan2(to_p.x, to_p.y)
		holder.add_child(fig)
		_family_nodes[int(fam["uid"])] = fig


## The doorways between rooms, as portals for culling.
func _build_portals() -> void:
	_portals.clear()
	for d_v in _house_layout.get("doorways", []):
		var d: Dictionary = d_v
		var ra: int = int(d.get("room_a", -1))
		var rb: int = int(d.get("room_b", -1))
		if ra < 0 or rb < 0 or not (d.get("a") is Vector2) or not (d.get("b") is Vector2):
			continue
		for pair in [[ra, rb], [rb, ra]]:
			if not _portals.has(pair[0]):
				_portals[pair[0]] = []
			(_portals[pair[0]] as Array).append({"to": int(pair[1]), "a": d["a"], "b": d["b"]})


## Occlusion culling doesn't work on the web, so whole rooms are shown and hidden here (portal
## culling on the floorplan): the room you're in, and every room you can see into through a chain of
## doorways inside your view. Hidden rooms take their furniture, items and family with them; room
## lights stay on, so turning around never changes the lighting.
func _update_room_visibility() -> void:
	var rooms: Array = _house3d.get("rooms", [])
	_shown_rooms.clear()
	var here: int = HouseBuilder3D._room_at(rooms, _player_pos)
	if here < 0 or not is_instance_valid(_cam):
		for i in range(rooms.size()):
			_shown_rooms[i] = true
	else:
		var fwd := Vector2(-sin(_yaw), -cos(_yaw))
		var aspect: float = 16.0 / 9.0
		var vp: Viewport = get_viewport()
		if vp != null and vp.get_visible_rect().size.y > 0.0:
			aspect = vp.get_visible_rect().size.x / vp.get_visible_rect().size.y
		var half_h: float = atan(tan(deg_to_rad(_cam.fov) * 0.5) * aspect) + deg_to_rad(18.0)
		_shown_rooms[here] = true
		var stack: Array = [[here, -half_h, half_h, 0]]
		while not stack.is_empty():
			var cur: Array = stack.pop_back()
			if int(cur[3]) >= 6:
				continue
			for p in _portals.get(int(cur[0]), []):
				var a: Vector2 = p["a"]
				var b: Vector2 = p["b"]
				var lo: float = float(cur[1])
				var hi: float = float(cur[2])
				if HouseBuilder3D._dist_point_segment(_player_pos, a, b) > 40.0:
					var ta: float = _rel_angle(fwd, a - _player_pos)
					var tb: float = _rel_angle(fwd, b - _player_pos)
					if absf(ta - tb) < PI:
						lo = maxf(lo, minf(ta, tb))
						hi = minf(hi, maxf(ta, tb))
				if hi <= lo:
					continue
				_shown_rooms[int(p["to"])] = true
				stack.append([int(p["to"]), lo, hi, int(cur[3]) + 1])
	for i in range(rooms.size()):
		(rooms[i]["node"] as Node3D).visible = _shown_rooms.has(i)


static func _rel_angle(fwd: Vector2, v: Vector2) -> float:
	return atan2(fwd.x * v.y - fwd.y * v.x, fwd.dot(v))


func _room_shown(pos: Vector2) -> bool:
	if _shown_rooms.is_empty():
		return true
	var ri: int = HouseBuilder3D._room_at(_house3d.get("rooms", []), pos)
	return ri < 0 or _shown_rooms.has(ri)


## Furniture backs onto the nearest wall; beds put a short side (the headboard) there, everything
## else a long side.
func _furniture_yaw(r: Rect2, kind: String) -> float:
	var sides: Array = [
		["top", Vector2(r.get_center().x, r.position.y - 2.0), 0.0],
		["bottom", Vector2(r.get_center().x, r.end.y + 2.0), PI],
		["left", Vector2(r.position.x - 2.0, r.get_center().y), PI * 0.5],
		["right", Vector2(r.end.x + 2.0, r.get_center().y), -PI * 0.5],
	]
	var long_x: bool = r.size.x >= r.size.y
	var ratio: float = maxf(r.size.x, r.size.y) / maxf(1.0, minf(r.size.x, r.size.y))
	var want_short: bool = kind.begins_with("bed")
	var best_yaw: float = 0.0
	var best_d: float = 1e20
	for s in sides:
		var is_x_side: bool = str(s[0]) == "top" or str(s[0]) == "bottom"   # runs along x
		var is_long: bool = (is_x_side == long_x)
		if ratio > 1.15 and is_long == want_short:
			continue
		var d: float = _dist_to_walls(s[1])
		if d < best_d:
			best_d = d
			best_yaw = float(s[2])
	return best_yaw


func _dist_to_walls(p: Vector2) -> float:
	var best: float = 1e20
	for wr in _wall_rects:
		var cx: float = clampf(p.x, wr.position.x, wr.end.x)
		var cy: float = clampf(p.y, wr.position.y, wr.end.y)
		best = minf(best, p.distance_to(Vector2(cx, cy)))
	for seg_v in _wall_segments:
		var seg: Dictionary = seg_v
		best = minf(best, HouseBuilder3D._dist_point_segment(p, seg["a"], seg["b"]) - float(seg.get("half_thick", 6.0)))
	return best


static func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


static func _set_visibility_range(n: Node, end_m: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = end_m
		(n as GeometryInstance3D).visibility_range_end_margin = 1.5
	for c in n.get_children():
		_set_visibility_range(c, end_m)


# ------------------------------------------------------------------------------
# Frame
# ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if _phase != Phase.OUTRO and not GameState.demo_mode:
		var turn: float = 0.0
		if Input.is_key_pressed(KEY_LEFT):
			turn += 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			turn -= 1.0
		_yaw += deg_to_rad(TURN_KEYS_DEG) * turn * dt
	super._process(delta)
	if _phase != Phase.OUTRO and not GameState.demo_mode:
		_player_facing = Vector2(-sin(_yaw), -cos(_yaw))
	_sync_world(dt)
	_update_aim()


func _draw() -> void:
	pass


func _exit_tree() -> void:
	_release_mouse()
	for pair in _passed_filters:
		if is_instance_valid(pair[0]):
			(pair[0] as Control).mouse_filter = int(pair[1])
	_passed_filters.clear()
	super._exit_tree()


## The screen holders above this scene are full-window Controls that would swallow mouse motion
## and clicks; while the grab runs they let them through to _unhandled_input.
func _let_mouse_through() -> void:
	var n: Node = get_parent()
	while n != null:
		if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_passed_filters.append([n, (n as Control).mouse_filter])
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		n = n.get_parent()


func _read_manual_move_vector() -> Vector2:
	var fwd: float = 0.0
	var side: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		fwd += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		fwd -= 1.0
	if Input.is_key_pressed(KEY_D):
		side += 1.0
	if Input.is_key_pressed(KEY_A):
		side -= 1.0
	var forward2 := Vector2(-sin(_yaw), -cos(_yaw))
	var right2 := Vector2(cos(_yaw), -sin(_yaw))
	var v: Vector2 = forward2 * fwd + right2 * side
	return v.normalized() if v.length_squared() > 1.0 else v


func _update_camera(dt: float) -> void:
	if not is_instance_valid(_cam):
		return
	if GameState.demo_mode or _phase == Phase.OUTRO:
		if _player_facing.length_squared() > 0.01:
			var target: float = atan2(-_player_facing.x, -_player_facing.y)
			_yaw = lerp_angle(_yaw, target, minf(1.0, dt * 5.0))
		_pitch = lerpf(_pitch, -0.22 if GameState.demo_mode else _pitch, minf(1.0, dt * 2.0))
	var bob: float = sin(_walk_phase) * 0.03 if _player_vel.length() > 30.0 else 0.0
	var pos: Vector3 = HouseBuilder3D.to3(_player_pos, _eye_h + bob)
	if _phase == Phase.OUTRO and not _leader_caught_outside:
		# Climbing down: the camera drops into the hatch.
		var k: float = clampf(_outro_elapsed / 0.9, 0.0, 1.0)
		pos = pos.lerp(HouseBuilder3D.to3(_hatch_pos, -1.6), k * k)
		_pitch = lerpf(_pitch, -1.2, minf(1.0, dt * 3.0))
	var shake: float = _shake_strength
	if _phase == Phase.SCAVENGE and _scavenge_time_left <= 4.5:
		shake = maxf(shake, (4.5 - _scavenge_time_left) * 0.65 * float(GameState.nuke_config.get("tremor_intensity", 0.6)))
	var sx: float = 0.0
	var sy: float = 0.0
	if shake > 0.05:
		sx = GameState.rng.randf_range(-1.0, 1.0) * shake * 0.0022
		sy = GameState.rng.randf_range(-1.0, 1.0) * shake * 0.0022
	_cam.transform = Transform3D(Basis.from_euler(Vector3(_pitch + sx, _yaw + sy, 0.0)), pos)
	_cam.fov = GameSettings.fov()


func _sync_world(dt: float) -> void:
	_update_room_visibility()
	for it_v in _world_items:
		var it: Dictionary = it_v
		var node: Node3D = _item_nodes.get(int(it["uid"]))
		if node == null:
			continue
		var gone: bool = bool(it.get("collected", false))
		node.visible = not gone and _room_shown(it["pos"])
		if node.visible:
			# The outline is an extra pass per item: only for items within 7 m (and the aimed one).
			var near: bool = _player_pos.distance_to(it["pos"]) <= OUTLINE_RANGE_PX
			if bool(node.get_meta("outlined", true)) != near:
				node.set_meta("outlined", near)
				PropLibrary._apply_overlay(node, node.get_meta("outline") if near else null)
		if not gone:
			var p: Vector3 = HouseBuilder3D.to3(it["pos"])
			if node.position.distance_squared_to(p) > 0.0001:
				node.position = p
	for f_v in _world_family:
		var fam: Dictionary = f_v
		var fig: FamilyFigure3D = _family_nodes.get(int(fam["uid"]))
		if fig == null:
			continue
		var gone2: bool = bool(fam.get("collected", false))
		# People don't block the way (as in the top-down grab); walking through someone hides them.
		fig.visible = not gone2 and _room_shown(fam["pos"]) and _player_pos.distance_to(fam["pos"]) > FAMILY_HIDE_PX
		if not gone2:
			fig.position = HouseBuilder3D.to3(fam["pos"])
	# Furniture you bump into rocks a little (ScavengeScene's spring), in metres.
	for i in range(mini(_furn_nodes.size(), _furniture_props.size())):
		var node2: Node3D = _furn_nodes[i]
		if node2 == null:
			continue
		var prop: Dictionary = _furniture_props[i]
		var off: Vector2 = prop.get("bump_offset", Vector2.ZERO)
		var base: Transform3D = _furn_base[i]
		node2.transform = Transform3D(base.basis.rotated(Vector3.UP, float(prop.get("bump_rot", 0.0)) * 0.5), base.origin + Vector3(off.x, 0.0, off.y) / PX * 0.6)
	# One shadowed light: a spot under the ceiling of the room the player is in.
	var rooms: Array = _house3d.get("rooms", [])
	var here: int = HouseBuilder3D._room_at(rooms, _player_pos)
	if here != _room_idx:
		_room_idx = here
		if is_instance_valid(_shadow_spot):
			var l: OmniLight3D = rooms[here].get("light") if here >= 0 else null
			_shadow_spot.visible = l != null
			if l != null:
				_shadow_spot.position = l.position + Vector3(0.0, 0.1, 0.0)
				var poly: PackedVector2Array = rooms[here]["poly"]
				var bb: Rect2 = FloorplanGenerator._poly_bounds(poly)
				_shadow_spot.spot_range = clampf(maxf(bb.size.x, bb.size.y) / PX * 0.9, 3.5, 7.5)
	# Things dropped down the hatch fall into the shaft.
	for fx_v in _falling_chute_fx:
		var fx: Dictionary = fx_v
		if bool(fx.get("_3d", false)):
			continue
		fx["_3d"] = true
		if str(fx.get("kind", "")) == "item":
			_drop_into_shaft(str(fx.get("item_id", "food")))
	if _phase == Phase.OUTRO:
		_release_mouse()


func _drop_into_shaft(item_id: String) -> void:
	var n: Node3D = PropLibrary.item(item_id)
	var g: Node = n.get_node_or_null("Glow")
	if g != null:
		g.queue_free()
	n.position = HouseBuilder3D.to3(_hatch_pos, 0.35) + Vector3(_rng.randf_range(-0.15, 0.15), 0.0, _rng.randf_range(-0.15, 0.15))
	_world.add_child(n)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(n, "position:y", -2.4, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(n, "rotation", Vector3(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0)), 0.55)
	tw.chain().tween_callback(n.queue_free)


# ------------------------------------------------------------------------------
# Aiming and the hands
# ------------------------------------------------------------------------------

func _update_aim() -> void:
	if not GameState.demo_mode and _phase != Phase.OUTRO:
		_hovered_target = _aim_target()
	var key: String = ""
	if not _hovered_target.is_empty():
		key = "%s:%d" % [str(_hovered_target.get("kind", "")), int(_hovered_target.get("uid", -1))]
	if key == _aimed_key:
		return
	_set_aim_highlight(_aimed_key, false)
	_set_aim_highlight(key, true)
	_aimed_key = key


func _set_aim_highlight(key: String, on: bool) -> void:
	if key.is_empty():
		return
	var parts: PackedStringArray = key.split(":")
	var uid: int = int(parts[1])
	if parts[0] == "item":
		var n: Node3D = _item_nodes.get(uid)
		var needed: bool = false
		for it in _world_items:
			if int(it["uid"]) == uid:
				needed = bool(it.get("needed", false))
		PropLibrary.set_aimed(n, on, needed)
	else:
		var fig: FamilyFigure3D = _family_nodes.get(uid)
		if fig != null:
			fig.set_highlight(on)


## What the crosshair is on: the closest-to-centre item or family member within reach, with
## nothing solid in between. Anything right at your feet counts even if you aren't aiming at it.
func _aim_target() -> Dictionary:
	if not is_instance_valid(_cam):
		return {}
	var origin: Vector3 = _cam.global_transform.origin
	var fwd: Vector3 = -_cam.global_transform.basis.z
	var best: Dictionary = {}
	var best_score: float = 1e20
	for f_v in _world_family:
		var fam: Dictionary = f_v
		if bool(fam.get("collected", false)):
			continue
		var fig: FamilyFigure3D = _family_nodes.get(int(fam["uid"]))
		var h: float = fig.height_m() * 0.55 if fig != null else 0.9
		var s: float = _aim_score(origin, fwd, fam["pos"], h, 0.45)
		if s < best_score:
			best_score = s
			best = {"kind": "family", "uid": int(fam["uid"]), "pos": fam["pos"], "slots": int(fam["slots"]),
				"label": "%s [%d Slots]" % [str(fam["name"]), int(fam["slots"])], "name": str(fam["name"]), "ref": fam}
	for it_v in _world_items:
		var it: Dictionary = it_v
		if bool(it.get("collected", false)):
			continue
		var s2: float = _aim_score(origin, fwd, it["pos"], 0.14, 0.22)
		if s2 < best_score:
			best_score = s2
			var sl: int = int(it["slots"])
			best = {"kind": "item", "uid": int(it["uid"]), "pos": it["pos"], "slots": sl,
				"label": "%s [%d %s]" % [str(it["name"]), sl, "Slot" if sl == 1 else "Slots"],
				"name": str(it["name"]), "item_id": str(it["item_id"]), "ref": it}
	return best


func _aim_score(origin: Vector3, fwd: Vector3, pos2: Vector2, h: float, radius: float) -> float:
	var d_px: float = _player_pos.distance_to(pos2)
	if d_px > REACH_PX:
		return 1e20
	var to: Vector3 = HouseBuilder3D.to3(pos2, h) - origin
	var dist: float = maxf(0.05, to.length())
	var ang: float = rad_to_deg(fwd.angle_to(to))
	var cone: float = maxf(AIM_CONE_DEG, rad_to_deg(atan2(radius, dist)))
	if ang > cone and d_px > NEAR_PX:
		return 1e20
	if _wall_between(_player_pos, pos2):
		return 1e20
	return ang + d_px * 0.04 + (40.0 if ang > cone else 0.0)


func _wall_between(a: Vector2, b: Vector2) -> bool:
	var len: float = a.distance_to(b)
	if len < 12.0:
		return false
	var steps: int = int(ceil(len / 7.0))
	for i in range(1, steps):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		if p.distance_to(b) < 10.0:
			break
		for wr in _wall_rects:
			if wr.grow(-1.5).has_point(p):
				return true
		for seg_v in _wall_segments:
			var seg: Dictionary = seg_v
			if HouseBuilder3D._dist_point_segment(p, seg["a"], seg["b"]) < float(seg.get("half_thick", 6.0)) - 1.5:
				return true
	return false


func _tooltip_target() -> Dictionary:
	return _hovered_target


func _pickup_hint() -> String:
	return "E or click: pick up"


func _grab_banner() -> String:
	return "GRAB SUPPLIES & FAMILY — E OR CLICK TO PICK UP"


func _hands_full_text() -> String:
	return "HANDS FULL — E AT THE HATCH DROPS EVERYTHING"


## E / SPACE / left click: drop everything down the hatch when you're at it with full hands,
## otherwise grab what you're aiming at.
func _context_action() -> void:
	if _phase != Phase.SCAVENGE or not _pending_action.is_empty():
		return
	if _is_at_hatch() and not _carried_entries.is_empty() and (_hovered_target.is_empty() or _get_used_slots() + int(_hovered_target.get("slots", 1)) > _max_slots):
		_begin_deposit()
		return
	if not _hovered_target.is_empty():
		_attempt_pickup_target(_hovered_target)
		return
	if _is_at_hatch() and not _carried_entries.is_empty():
		_begin_deposit()


func _process_pending_action(dt: float) -> void:
	_apply_player_movement(Vector2.ZERO, dt, false)
	_pending_action["t"] = float(_pending_action.get("t", 0.0)) + dt
	if float(_pending_action["t"]) < float(_pending_action.get("dur", 0.3)):
		return
	var act: Dictionary = _pending_action
	_pending_action = {}
	match str(act.get("type", "")):
		"grab":
			var tgt: Dictionary = act.get("target", {})
			var tpos: Vector2 = tgt.get("pos", _player_pos)
			if _player_pos.distance_to(tpos) <= REACH_PX + 12.0:
				_complete_pickup(tgt)
		"deposit":
			if _is_at_hatch():
				_deposit_carried_into_hatch(true)


# ------------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.OUTRO:
		return
	if event is InputEventMouseMotion:
		if _mouse_captured() or GameSettings.automation:
			var mm: InputEventMouseMotion = event
			var sens: float = deg_to_rad(GameSettings.mouse_sensitivity())
			# screen_relative is in real screen pixels: the 1280x720 stretch doesn't change how far
			# a turn goes, so sensitivity feels the same at any window size.
			var rel: Vector2 = mm.screen_relative
			_yaw -= rel.x * sens
			var dy: float = rel.y * sens * (-1.0 if GameSettings.invert_y() else 1.0)
			_pitch = clampf(_pitch - dy, deg_to_rad(-80.0), deg_to_rad(75.0))
		return
	if event is InputEventKey:
		var ke: InputEventKey = event
		if not ke.pressed or ke.echo:
			return
		match ke.keycode:
			KEY_TAB:
				if _phase == Phase.SCOUT:
					_start_scavenge_phase()
			KEY_ESCAPE:
				_release_mouse()
			KEY_F3:
				show_perf = not show_perf
			KEY_E, KEY_SPACE, KEY_ENTER:
				if _phase == Phase.SCAVENGE and not GameState.demo_mode:
					_context_action()
			KEY_Q:
				if _phase == Phase.SCAVENGE:
					_cycle_selected_slot(1)
			KEY_G, KEY_X:
				if _phase == Phase.SCAVENGE and not GameState.demo_mode:
					_drop_selected_entry()
			KEY_F:
				if _can_dive_into_bunker() and not GameState.demo_mode:
					_dive_into_bunker()
			_:
				if ke.keycode >= KEY_1 and ke.keycode <= KEY_7 and _phase == Phase.SCAVENGE:
					_select_entry_at_slot(int(ke.keycode - KEY_1))
				else:
					return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not GameState.demo_mode:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if not _mouse_captured() and _try_capture_mouse():
					pass
				elif _phase == Phase.SCAVENGE:
					_context_action()
			MOUSE_BUTTON_RIGHT:
				if _phase == Phase.SCAVENGE:
					_drop_selected_entry()
			MOUSE_BUTTON_WHEEL_UP:
				_cycle_selected_slot(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_selected_slot(1)
		get_viewport().set_input_as_handled()


func _mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Locks the pointer for mouse look on a real click. Never in the demo or under test tools, and
## only when this window has focus, so a test run can't grab the cursor.
func _try_capture_mouse() -> bool:
	if GameState.demo_mode or GameSettings.automation or DisplayServer.get_name() == "headless":
		return false
	if not get_window().has_focus():
		return false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true


func _release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func look_hint_visible() -> bool:
	return not GameState.demo_mode and not _mouse_captured() and not GameSettings.automation and _phase != Phase.OUTRO


func camera_3d() -> Camera3D:
	return _cam


func view_yaw() -> float:
	return _yaw


# ==============================================================================
# HUD: ScavengeScene's, plus a crosshair, popups in 3D and first-person controls
# ==============================================================================

class _Grab3DHUD extends ScavengeScene._ScavengeHUD:
	func _draw() -> void:
		super._draw()
		if not is_instance_valid(scene_ref):
			return
		var s: HouseGrab3D = scene_ref as HouseGrab3D
		if s == null or s._phase == ScavengeScene.Phase.OUTRO:
			return
		var font: Font = ThemeDB.fallback_font
		_draw_popups_3d(s, font)
		_draw_crosshair(s)
		if s.show_perf:
			var txt: String = "%d FPS · %d draw calls · %dk triangles" % [Engine.get_frames_per_second(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
			ScavengeScene._draw_badge_pill(self, font, Vector2(640.0, 118.0), txt, 12, ScavengeScene.COL_INK, ScavengeScene.COL_OK_GREEN)
		if s.look_hint_visible():
			ScavengeScene._draw_badge_pill(self, font, Vector2(640.0, 420.0), "CLICK TO LOOK AROUND WITH THE MOUSE  ·  ESC FREES IT  ·  ← → ALSO TURN", 13, ScavengeScene.COL_INK, ScavengeScene.COL_AMBER)

	func _draw_crosshair(s: HouseGrab3D) -> void:
		var c := Vector2(640.0, 360.0)
		var aimed: bool = not s._hovered_target.is_empty()
		var col: Color = ScavengeScene.COL_AMBER if aimed else Color(1, 1, 1, 0.75)
		draw_circle(c, 2.6, Color(0, 0, 0, 0.6))
		draw_circle(c, 1.8, col)
		if aimed:
			draw_arc(c, 13.0, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 4.0, true)
			draw_arc(c, 13.0, 0.0, TAU, 32, col, 2.0, true)
		if not s._pending_action.is_empty():
			var f: float = clampf(float(s._pending_action.get("t", 0.0)) / maxf(0.01, float(s._pending_action.get("dur", 0.3))), 0.0, 1.0)
			draw_arc(c, 19.0, -PI * 0.5, -PI * 0.5 + TAU * f, 40, ScavengeScene.COL_OK_GREEN, 4.0, true)

	func _draw_popups_3d(s: HouseGrab3D, font: Font) -> void:
		var cam: Camera3D = s.camera_3d()
		if cam == null:
			return
		for pop_v in s._floating_popups:
			var pop: Dictionary = pop_v
			var w: Vector3 = HouseBuilder3D.to3(pop["pos"], 1.25)
			if cam.is_position_behind(w):
				continue
			var sp: Vector2 = cam.unproject_position(w)
			var a: float = clampf(1.0 - float(pop["t"]) / maxf(0.01, float(pop["dur"])), 0.0, 1.0)
			var col: Color = pop["color"]
			col.a = a
			ScavengeScene._draw_text_centered_outlined(self, font, sp, str(pop["text"]), 16, col, Color(0.06, 0.07, 0.08, a))

	func _draw_controls_and_compass(font: Font) -> void:
		var s: HouseGrab3D = scene_ref as HouseGrab3D
		var hint_r := Rect2(14.0, 646.0, 396.0, 64.0)
		draw_rect(hint_r, Color(0.10, 0.12, 0.14, 0.9), true)
		draw_rect(hint_r, ScavengeScene.COL_BORDER, false, 1.0)
		draw_string(font, Vector2(22.0, 666.0), "WASD: move   Mouse: look   E / click: grab   F: climb down", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_TEXT)
		draw_string(font, Vector2(22.0, 684.0), "E at the hatch: drop everything down", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_AMBER)
		draw_string(font, Vector2(22.0, 701.0), "Q / 1-7 / wheel: select   Right-click or G: drop selected", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_TEXT_MUTED)
		var comp_r := Rect2(922.0, 646.0, 344.0, 64.0)
		draw_rect(comp_r, Color(0.10, 0.12, 0.14, 0.9), true)
		draw_rect(comp_r, ScavengeScene.COL_BORDER, false, 1.0)
		var to_hatch: Vector2 = s._hatch_pos - s._player_pos
		var dist_m: float = to_hatch.length() / 46.0
		var cc := Vector2(comp_r.position.x + 32.0, comp_r.get_center().y)
		draw_circle(cc, 20.0, ScavengeScene.COL_SLATE_DARK)
		draw_arc(cc, 20.0, 0.0, TAU, 24, ScavengeScene.COL_AMBER, 1.8, true)
		if s._is_at_hatch():
			draw_circle(cc, 8.0, ScavengeScene.COL_OK_GREEN)
			draw_string(font, Vector2(comp_r.position.x + 62.0, 671.0), "AT THE HATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ScavengeScene.COL_OK_GREEN)
		else:
			var yaw: float = s.view_yaw()
			var fwd := Vector2(-sin(yaw), -cos(yaw))
			var right := Vector2(cos(yaw), -sin(yaw))
			var dir_h := Vector2(to_hatch.dot(right), -to_hatch.dot(fwd)).normalized()
			var tip: Vector2 = cc + dir_h * 14.0
			var wing_l: Vector2 = cc - dir_h * 8.0 + Vector2(-dir_h.y, dir_h.x) * 6.5
			var wing_r: Vector2 = cc - dir_h * 8.0 - Vector2(-dir_h.y, dir_h.x) * 6.5
			draw_colored_polygon(PackedVector2Array([tip, wing_l, wing_r]), ScavengeScene.COL_AMBER)
			draw_string(font, Vector2(comp_r.position.x + 62.0, 671.0), "HATCH: %.1f m" % dist_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ScavengeScene.COL_AMBER)
		var spd_pct: int = int(round((s._compute_move_speed() / ScavengeScene.BASE_MOVE_SPEED) * 100.0))
		draw_string(font, Vector2(comp_r.position.x + 62.0, 695.0), "MOVE SPEED: %d%%" % spd_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ScavengeScene.COL_OK_GREEN if spd_pct >= 100 else ScavengeScene.COL_TEXT_MUTED)
