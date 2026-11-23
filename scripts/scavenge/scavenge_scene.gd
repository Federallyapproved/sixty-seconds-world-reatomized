class_name ScavengeScene
extends Node2D

## 3D Isometric Real-World OSM House Scavenge Sequence for "60 Seconds: World Reatomized" (V2).
## Hosts a 1280x720 3D Isometric Cutaway House (SubViewport + Orthographic Camera3D + Dynamic Lighting)
## paired with a crisp projected 2D CONELRAD Callout & Civil Defense HUD Layer.
## Preserves 100% of verified HouseGenerator BFS walkability, sliding circle collisions,
## multi-slot carry rules, Demo Auto-Pilot pathfinding, Difficulty/Drill modes, and Left-Behind tracking.

signal item_picked_up(item_id: String, slots: int)
signal family_picked_up(member_id: String, slots: int)
signal hatch_deposited(items_count: int, family_count: int)
signal scavenge_finished(leader_escaped: bool, survivors_count: int)

enum Phase {
	SCOUT,
	SCAVENGE,
	OUTRO
}

# Mid-Century 1950s CONELRAD Civil Defense Palette
const COL_BG_NIGHT := Color("#161916")
const COL_YARD_GRASS := Color("#2c3827")
const COL_YARD_STRIPE := Color("#263122")
const COL_SIDEWALK := Color("#9b9484")
const COL_FLOOR_BASE := Color("#e4d5b7")
const COL_PARCHMENT := Color("#f2e6ce")
const COL_PARCHMENT_DARK := Color("#dccba6")
const COL_INK := Color("#1b1917")
const COL_SLATE := Color("#232824")
const COL_SLATE_DARK := Color("#181c19")
const COL_WALL_EXT := Color("#25211d")
const COL_WALL_INT := Color("#3f372f")
const COL_WALL_TRIM := Color("#cbbba0")
const COL_HAZARD_YELLOW := Color("#f5be2e")
const COL_HAZARD_GOLD := Color("#c98f18")
const COL_ATOMIC_ORANGE := Color("#e05a2b")
const COL_ALERT_RED := Color("#d94c2a")
const COL_TOXIC_GREEN := Color("#7ec850")
const COL_WATER_BLUE := Color("#3b8ec2")

# Gameplay & Physics Constants
const BASE_MOVE_SPEED: float = 255.0
const SPRINTER_MULT: float = 1.15
const SLOT_SLOW_PER_UNIT: float = 0.06
const PLAYER_ACCEL: float = 2400.0
const PLAYER_RADIUS: float = 14.0
const INTERACT_RADIUS: float = 52.0
const AUTO_PICKUP_RADIUS: float = 42.0
const HATCH_DROP_MARGIN: float = 18.0
const HATCH_END_MARGIN: float = 42.0
const OUTRO_DURATION: float = 1.8

# House Layout Data
var _house_layout: Dictionary = {}
var _house_bounds: Rect2 = Rect2(-360.0, -280.0, 720.0, 560.0)
var _outer_polygon: PackedVector2Array = PackedVector2Array()
var _outer_poly_valid: bool = false
var _rooms: Array = []
var _wall_rects: Array[Rect2] = []
var _wall_segments: Array = []
var _furniture_props: Array = []
var _hatch_pos: Vector2 = Vector2.ZERO
var _hatch_radius: float = 52.0
var _leader_start_pos: Vector2 = Vector2(0.0, 72.0)
var _nav_grid: Dictionary = {}

# Fallback local navigation grid
var _local_grid_origin: Vector2 = Vector2.ZERO
var _local_grid_cell: float = 22.0
var _local_grid_cols: int = 0
var _local_grid_rows: int = 0
var _local_grid_blocked: PackedByteArray = PackedByteArray()

# World Entities
var _leader_member: Dictionary = {}
var _world_items: Array = []
var _world_family: Array = []
var _hovered_target: Dictionary = {}

# Player Physics & Animation
var _player_pos: Vector2 = Vector2.ZERO
var _player_vel: Vector2 = Vector2.ZERO
var _player_facing: Vector2 = Vector2(0.0, 1.0)
var _walk_phase: float = 0.0
var _dust_timer: float = 0.0
var _dust_puffs: Array = []

# Click-to-Move / Click-to-Grab State
var _has_click_target: bool = false
var _click_target_pos: Vector2 = Vector2.ZERO
var _click_pickup_kind: String = ""
var _click_pickup_uid: int = -1

# Carry Inventory & Bunker Chute Tally
var _max_slots: int = 4
var _suitcase_upgraded: bool = false
var _carried_entries: Array = []
var _items_deposited_count: int = 0
var _gear_deposited_count: int = 0
var _family_deposited_count: int = 0
var _non_leader_total: int = 0
var _deposited_by_id: Dictionary = {}
var _secured_gear_order: Array[String] = []
var _auto_pickup: bool = false

# Phase & Timers
var _phase: int = Phase.SCOUT
var _anim_time: float = 0.0
var _scout_total: float = 8.0
var _scout_time_left: float = 8.0
var _scavenge_total: float = 60.0
var _scavenge_time_left: float = 60.0
var _outro_elapsed: float = 0.0
var _outro_transitioned: bool = false
var _leader_caught_outside: bool = false
var _last_whole_sec: int = -1
var _last_half_tick: int = -1
var _siren_15_played: bool = false

# Visual Juice, 3D World & Isometric Camera
var _is_headless: bool = false
var _world_3d_layer: CanvasLayer = null
var _sub_vp_container: SubViewportContainer = null
var _sub_vp: SubViewport = null
var _world_env: WorldEnvironment = null
var _sun_light: DirectionalLight3D = null
var _hatch_light: OmniLight3D = null
var _siren_light: OmniLight3D = null
var _camera_3d: Camera3D = null
var _house_3d_root: Node3D = null
var _entities_3d_root: Node3D = null
var _chute_fx_3d_root: Node3D = null
var _furniture_nodes_3d: Dictionary = {}
var _hatch_nodes_3d: Dictionary = {}
var _player_node_3d: Node3D = null
var _player_ring_3d: MeshInstance3D = null
var _item_nodes_3d: Dictionary = {}
var _family_nodes_3d: Dictionary = {}
var _last_carried_sig: String = ""

var _base_ortho_size: float = 16.8
var _current_ortho_size: float = 17.5
var _cam_focus_2d: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
var _hands_full_timer: float = 0.0
var _suitcase_flash_timer: float = 0.0
var _tally_pop_timer: float = 0.0
var _atomic_flash_alpha: float = 0.0
var _floating_popups: Array = []
var _falling_chute_fx: Array = []

# HUD & Callout Overlay (CanvasLayer 2)
var _hud_layer: CanvasLayer = null
var _hud: _ScavengeHUD = null

# Demo Auto-Pilot State
var _ai_waypoints: Array[Vector2] = []
var _ai_wp_index: int = 0
var _ai_goal_pos: Vector2 = Vector2.ZERO
var _ai_goal_kind: String = ""
var _ai_goal_uid: int = -1
var _ai_repath_timer: float = 0.0
var _ai_progress_timer: float = 0.0
var _ai_progress_anchor: Vector2 = Vector2.ZERO
var _ai_sidestep_timer: float = 0.0
var _ai_sidestep_dir: Vector2 = Vector2.ZERO
var _ai_target_attempt_time: float = 0.0
var _ai_pause_timer: float = 0.0
var _ai_blacklist: Dictionary = {}


func _ready() -> void:
	_is_headless = (DisplayServer.get_name() == "headless")
	_preserve_and_reset_run_state()
	SoundManager.set_ambience("scavenge")

	_house_layout = HouseGenerator.generate_from_osm_house(
		GameState.selected_house,
		GameState.family_members,
		GameState.rng
	)
	_parse_house_layout(_house_layout)
	_build_local_fallback_grid()

	# Difficulty & Demo Timer Configuration
	var diff_cfg: Dictionary = GameState.get_difficulty_config()
	if GameState.demo_mode:
		_scavenge_total = 60.0
		_scout_total = 2.5
	else:
		var diff_scav: float = float(diff_cfg.get("scavenge_seconds", 60.0))
		var nuke_scav: float = float(GameState.nuke_config.get("scavenge_seconds", 60.0))
		var resolved_scav: float = diff_scav if is_equal_approx(nuke_scav, 60.0) else nuke_scav
		_scavenge_total = clampf(resolved_scav, 15.0, 120.0)

		var base_scout: float = float(GameState.nuke_config.get("scout_seconds", 8.0))
		var scout_bonus: float = float(diff_cfg.get("scout_bonus_sec", 0.0))
		_scout_total = clampf(base_scout + scout_bonus, 1.5, 25.0)

	_scavenge_time_left = _scavenge_total
	_scout_time_left = _scout_total
	_last_whole_sec = int(ceil(_scout_time_left))

	_setup_3d_isometric_world()
	_setup_hud()
	_sync_3d_world(0.016)

	SoundManager.play_sfx("tick")
	queue_redraw()


func _exit_tree() -> void:
	_reset_viewport_camera_transform()


func _reset_viewport_camera_transform() -> void:
	if is_instance_valid(_camera_3d):
		_camera_3d.current = false
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.canvas_transform = Transform2D.IDENTITY


func _preserve_and_reset_run_state() -> void:
	var saved_family: Array = GameState.family_members.duplicate(true)
	var saved_rels: Dictionary = GameState.relationships.duplicate(true)
	var saved_house: Dictionary = GameState.selected_house.duplicate(true)
	var saved_pois: Array = GameState.nearby_pois.duplicate(true)
	var saved_mods: Dictionary = GameState.neighborhood_modifiers.duplicate(true)
	var saved_neighborhood: String = GameState.current_neighborhood_label
	var saved_nuke: Dictionary = GameState.nuke_config.duplicate(true)
	var saved_demo: bool = GameState.demo_mode
	var saved_promo: bool = GameState.promo_video_mode
	var saved_fast: bool = GameState.headless_fast_test
	var saved_diff: String = GameState.difficulty
	var saved_mode: String = GameState.game_mode
	var saved_challenge: String = GameState.active_challenge_id
	var saved_cat: bool = GameState.has_cat_sharikov
	var saved_dog: bool = GameState.has_dog_pancake
	var saved_flags: Dictionary = GameState.story_flags.duplicate(true)

	GameState.reset_to_defaults()

	GameState.demo_mode = saved_demo
	GameState.promo_video_mode = saved_promo
	GameState.headless_fast_test = saved_fast
	GameState.difficulty = saved_diff
	GameState.game_mode = saved_mode
	GameState.active_challenge_id = saved_challenge
	if saved_mode == "challenge":
		GameState.has_cat_sharikov = saved_cat
		GameState.has_dog_pancake = saved_dog
		GameState.story_flags = saved_flags
	GameState.current_neighborhood_label = saved_neighborhood
	GameState.neighborhood_modifiers = saved_mods
	if not saved_pois.is_empty():
		GameState.nearby_pois = saved_pois
	for poi_var in GameState.nearby_pois:
		if poi_var is Dictionary:
			var poi_dict: Dictionary = poi_var
			poi_dict["visited_count"] = 0
			poi_dict["depleted"] = false
	if not saved_house.is_empty():
		GameState.selected_house = saved_house
	if not saved_nuke.is_empty():
		GameState.nuke_config = saved_nuke
	if not saved_family.is_empty():
		GameState.family_members = saved_family
		GameState.reset_family_runtime_status()
	if not saved_rels.is_empty():
		GameState.relationships = saved_rels
	else:
		GameState.init_relationships(20)

	GameState.surface_radiation_sv = float(GameState.nuke_config.get("initial_sv_hr", 4.5))
	GameState.bunker_temp_c = float(GameState.nuke_config.get("bunker_temp_c", 20.0))

	# Guarantee exactly one leader exists
	var found_leader: bool = false
	for raw_m in GameState.family_members:
		var m: Dictionary = raw_m
		if bool(m.get("is_leader", false)) and not found_leader:
			found_leader = true
			_leader_member = m
		else:
			m["is_leader"] = false

	if not found_leader and not GameState.family_members.is_empty():
		var first_m: Dictionary = GameState.family_members[0]
		first_m["is_leader"] = true
		_leader_member = first_m

	if saved_mode == "challenge" and saved_challenge == "lone_wolf_pets":
		_max_slots = maxi(_max_slots, 4)
		if not _leader_member.is_empty():
			_leader_member["scavenge_slots"] = 4


func _parse_house_layout(layout: Dictionary) -> void:
	var raw_bounds: Variant = layout.get("bounds", Rect2(-360.0, -280.0, 720.0, 560.0))
	if raw_bounds is Rect2:
		_house_bounds = raw_bounds
	else:
		_house_bounds = Rect2(-360.0, -280.0, 720.0, 560.0)

	# Outer polygon
	_outer_polygon = _to_packed_poly(layout.get("outer_polygon", PackedVector2Array()))
	if _outer_polygon.size() < 3:
		_outer_polygon = PackedVector2Array([
			_house_bounds.position,
			Vector2(_house_bounds.end.x, _house_bounds.position.y),
			_house_bounds.end,
			Vector2(_house_bounds.position.x, _house_bounds.end.y)
		])
	_outer_polygon = _sanitize_polygon(_outer_polygon)
	_outer_poly_valid = _outer_polygon.size() >= 3 and Geometry2D.triangulate_polygon(_outer_polygon).size() >= 3

	# Hatch & Leader Start
	var raw_hatch: Variant = layout.get("hatch_pos", _house_bounds.get_center())
	_hatch_pos = raw_hatch if raw_hatch is Vector2 else _house_bounds.get_center()
	_hatch_radius = clampf(float(layout.get("hatch_radius", 52.0)), 36.0, 72.0)

	var raw_start: Variant = layout.get("leader_start_pos", _hatch_pos + Vector2(0.0, _hatch_radius + 26.0))
	_leader_start_pos = raw_start if raw_start is Vector2 else (_hatch_pos + Vector2(0.0, _hatch_radius + 26.0))
	_player_pos = _leader_start_pos
	_ai_progress_anchor = _player_pos

	# Nav grid
	var raw_nav: Variant = layout.get("nav_grid", {})
	_nav_grid = raw_nav if raw_nav is Dictionary else {}

	# Rooms
	_rooms.clear()
	var raw_rooms: Variant = layout.get("rooms", [])
	if raw_rooms is Array:
		for r_var in raw_rooms:
			if r_var is Dictionary:
				var rd: Dictionary = r_var
				var r_name: String = str(rd.get("name", rd.get("label", rd.get("type", "Room"))))
				var r_rect: Rect2 = _extract_rect(rd, Rect2())
				var r_poly: PackedVector2Array = _to_packed_poly(rd.get("polygon", PackedVector2Array()))
				if r_poly.size() >= 3:
					r_poly = _sanitize_polygon(r_poly)
				var r_poly_ok: bool = r_poly.size() >= 3 and Geometry2D.triangulate_polygon(r_poly).size() >= 3
				var r_center: Vector2 = _hatch_pos
				if rd.get("center") is Vector2:
					r_center = rd["center"]
				elif r_rect.size.x > 1.0 and r_rect.size.y > 1.0:
					r_center = r_rect.get_center()
				elif r_poly.size() > 0:
					r_center = _polygon_centroid(r_poly)
				var r_col: Color = _resolve_room_color(r_name, rd.get("color", null))
				_rooms.append({
					"name": r_name,
					"rect": r_rect,
					"polygon": r_poly,
					"poly_valid": r_poly_ok,
					"center": r_center,
					"color": r_col,
					"kind": r_name.to_lower()
				})

	# Walls (supports Rect2 OR segment Dictionaries)
	_wall_rects.clear()
	_wall_segments.clear()
	var raw_walls: Variant = layout.get("walls", [])
	if raw_walls is Array:
		for w_var in raw_walls:
			if w_var is Rect2:
				var wr: Rect2 = w_var
				if wr.size.x > 0.5 and wr.size.y > 0.5:
					_wall_rects.append(wr)
			elif w_var is Dictionary:
				var wd: Dictionary = w_var
				if wd.get("rect") is Rect2:
					var wr2: Rect2 = wd["rect"]
					if wr2.size.x > 0.5 and wr2.size.y > 0.5:
						_wall_rects.append(wr2)
				elif (wd.get("a") is Vector2 and wd.get("b") is Vector2) or (wd.get("p1") is Vector2 and wd.get("p2") is Vector2) or (wd.get("start") is Vector2 and wd.get("end") is Vector2):
					var pa: Vector2 = wd.get("a", wd.get("p1", wd.get("start", Vector2.ZERO)))
					var pb: Vector2 = wd.get("b", wd.get("p2", wd.get("end", Vector2.ZERO)))
					var thick: float = float(wd.get("thickness", wd.get("width", 12.0)))
					if absf(pa.x - pb.x) < 0.5 or absf(pa.y - pb.y) < 0.5:
						var min_p := Vector2(minf(pa.x, pb.x) - thick * 0.5, minf(pa.y, pb.y) - thick * 0.5)
						var max_p := Vector2(maxf(pa.x, pb.x) + thick * 0.5, maxf(pa.y, pb.y) + thick * 0.5)
						_wall_rects.append(Rect2(min_p, max_p - min_p))
					else:
						_wall_segments.append({
							"a": pa,
							"b": pb,
							"half_thick": maxf(4.0, thick * 0.5),
							"outer": bool(wd.get("outer", wd.get("is_exterior", false)))
						})
				else:
					var wr3: Rect2 = _extract_rect(wd, Rect2())
					if wr3.size.x > 0.5 and wr3.size.y > 0.5:
						_wall_rects.append(wr3)

	# Furniture props
	_furniture_props.clear()
	var raw_furn: Variant = layout.get("furniture", [])
	if raw_furn is Array:
		for f_var in raw_furn:
			if f_var is Rect2:
				var fr: Rect2 = f_var
				_furniture_props.append(_make_furniture_prop(fr, "cabinet", "Cabinet", Color("#855836"), true))
			elif f_var is Dictionary:
				var fd: Dictionary = f_var
				var f_rect: Rect2 = _extract_rect(fd, Rect2())
				if f_rect.size.x <= 1.0 or f_rect.size.y <= 1.0:
					continue
				var kind_str: String = str(fd.get("type", fd.get("kind", fd.get("name", "table")))).to_lower()
				var label_str: String = str(fd.get("label", fd.get("name", kind_str.capitalize())))
				var solid_flag: bool = true
				if kind_str.find("rug") >= 0 or kind_str.find("carpet") >= 0 or kind_str.find("mat") >= 0:
					solid_flag = false
				if fd.has("solid"):
					solid_flag = bool(fd["solid"])
				elif fd.has("collidable"):
					solid_flag = bool(fd["collidable"])
				elif fd.has("walkable"):
					solid_flag = not bool(fd["walkable"])

				if f_rect.grow(10.0).has_point(_hatch_pos) or f_rect.grow(PLAYER_RADIUS + 4.0).has_point(_player_pos):
					solid_flag = false

				var f_col: Color = _resolve_furniture_color(kind_str, fd.get("color", null))
				_furniture_props.append(_make_furniture_prop(f_rect, kind_str, label_str, f_col, solid_flag))

	# Spawned Items
	_world_items.clear()
	var raw_items: Variant = layout.get("items", [])
	var uid_counter: int = 1
	if raw_items is Array:
		for it_var in raw_items:
			if it_var is Dictionary:
				var idict: Dictionary = it_var
				var item_id: String = str(idict.get("item_id", idict.get("id", "soup"))).strip_edges().to_lower()
				var raw_ipos: Variant = idict.get("pos", idict.get("position", _hatch_pos + Vector2(60.0, 0.0)))
				var ipos: Vector2 = raw_ipos if raw_ipos is Vector2 else (_hatch_pos + Vector2(60.0, 0.0))
				var info: Dictionary = ItemDB.get_item_info(item_id)
				var item_name: String = str(info.get("name", item_id.capitalize()))
				var short_name: String = str(info.get("short_name", item_name))
				var slots: int = clampi(int(info.get("slots", 1)), 1, 2)
				var cat: String = str(info.get("category", "gear"))
				var icol: Color = info.get("color", COL_HAZARD_YELLOW) if info.get("color") is Color else COL_HAZARD_YELLOW
				_world_items.append({
					"uid": uid_counter,
					"item_id": item_id,
					"pos": ipos,
					"room": str(idict.get("room", "")),
					"name": item_name,
					"short_name": short_name,
					"slots": slots,
					"category": cat,
					"color": icol,
					"collected": false,
					"bob_phase": float(uid_counter) * 0.83
				})
				uid_counter += 1

	# Non-Leader Family Spawns
	_world_family.clear()
	var raw_spawns: Variant = layout.get("family_spawns", [])
	var spawn_list: Array = raw_spawns if raw_spawns is Array else []
	var used_spawn_indices: Dictionary = {}
	var fam_uid: int = 1000

	for raw_m in GameState.family_members:
		var m: Dictionary = raw_m
		if bool(m.get("is_leader", false)):
			continue
		var mid: String = str(m.get("id", ""))
		var mname: String = str(m.get("name", "Family"))
		var fpos: Vector2 = _hatch_pos + Vector2(float((fam_uid % 3) - 1) * 85.0, -85.0)
		var matched: bool = false

		for idx in range(spawn_list.size()):
			if used_spawn_indices.has(idx):
				continue
			var sp_var: Variant = spawn_list[idx]
			if sp_var is Dictionary:
				var spd: Dictionary = sp_var
				var sp_id: String = str(spd.get("member_id", spd.get("id", "")))
				var sp_name: String = str(spd.get("name", ""))
				if (not mid.is_empty() and sp_id == mid) or (not mname.is_empty() and sp_name == mname):
					var raw_fp: Variant = spd.get("pos", spd.get("position", fpos))
					if raw_fp is Vector2:
						fpos = raw_fp
					used_spawn_indices[idx] = true
					matched = true
					break

		if not matched:
			for idx in range(spawn_list.size()):
				if used_spawn_indices.has(idx):
					continue
				var sp_var2: Variant = spawn_list[idx]
				if sp_var2 is Dictionary:
					var spd2: Dictionary = sp_var2
					var raw_fp2: Variant = spd2.get("pos", spd2.get("position", fpos))
					if raw_fp2 is Vector2:
						fpos = raw_fp2
					used_spawn_indices[idx] = true
					break

		var m_slots: int = clampi(int(m.get("scavenge_slots", 2)), 2, 3)
		_world_family.append({
			"uid": fam_uid,
			"member": m,
			"member_id": mid,
			"name": mname,
			"pos": fpos,
			"slots": m_slots,
			"facing": (_hatch_pos - fpos).normalized() if _hatch_pos.distance_to(fpos) > 1.0 else Vector2(0.0, 1.0),
			"collected": false,
			"bob_phase": float(fam_uid) * 1.17
		})
		fam_uid += 1

	_non_leader_total = _world_family.size()
	_player_pos = _resolve_collisions(_player_pos, false)


func _make_furniture_prop(rect: Rect2, kind: String, label: String, col: Color, solid: bool) -> Dictionary:
	return {
		"rect": rect,
		"kind": kind,
		"label": label,
		"color": col,
		"solid": solid,
		"bump_offset": Vector2.ZERO,
		"bump_vel": Vector2.ZERO,
		"bump_rot": 0.0,
		"bump_rot_vel": 0.0,
		"bump_cd": 0.0
	}


# ==============================================================================
# TRUE 3D ISOMETRIC SUBVIEWPORT, LIGHTING & CAMERA SETUP
# ==============================================================================

func _setup_3d_isometric_world() -> void:
	# Compute fitted orthographic size (~16.2 .. 19.2) from house bounds
	var hx_m: float = maxf(12.0, _house_bounds.size.x * House3DBuilder.SCALE_3D)
	var hz_m: float = maxf(10.0, _house_bounds.size.y * House3DBuilder.SCALE_3D)
	var iso_span_w: float = hx_m * 0.848 + hz_m * 0.530
	var iso_span_h: float = (hx_m * 0.530 + hz_m * 0.848) * 0.743 + 2.3
	var fit_w: float = (iso_span_w / (1280.0 / 720.0)) * 1.18
	var fit_h: float = iso_span_h * 1.10
	_base_ortho_size = clampf(maxf(fit_w, fit_h), 16.2, 19.2)
	_current_ortho_size = clampf(_base_ortho_size * 1.05, 16.4, 20.4)
	_cam_focus_2d = _player_pos.lerp(_house_bounds.get_center(), 0.55)

	# Headless fast-test guard: skip heavy GPU SubViewport/MSAA/shadow allocation
	if _is_headless:
		return

	_world_3d_layer = CanvasLayer.new()
	_world_3d_layer.name = "Scavenge3DViewportLayer"
	_world_3d_layer.layer = 0
	add_child(_world_3d_layer)

	_sub_vp_container = SubViewportContainer.new()
	_sub_vp_container.name = "ScavengeSubViewportContainer"
	_sub_vp_container.position = Vector2.ZERO
	_sub_vp_container.size = Vector2(1280.0, 720.0)
	_sub_vp_container.stretch = true
	_sub_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_3d_layer.add_child(_sub_vp_container)

	var is_software_gl: bool = RenderingServer.get_video_adapter_name().to_lower().contains("llvmpipe") or RenderingServer.get_video_adapter_name().to_lower().contains("softpipe")

	_sub_vp = SubViewport.new()
	_sub_vp.name = "ScavengeSubViewport"
	_sub_vp.size = Vector2i(1280, 720)
	_sub_vp.own_world_3d = true
	_sub_vp.msaa_3d = Viewport.MSAA_DISABLED if is_software_gl else Viewport.MSAA_2X
	_sub_vp.handle_input_locally = false
	_sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_vp_container.add_child(_sub_vp)

	# 1950s Atomic Twilight Environment (balanced exposure so floors & 3D props stay crisp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#181b18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#eddac0")
	env.ambient_light_energy = 0.52
	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment3D"
	_world_env.environment = env
	_sub_vp.add_child(_world_env)

	# Warm Golden Afternoon Sun (shifts toward ominous atomic orange as countdown nears 0!)
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "AtomicTwilightSun"
	_sun_light.rotation_degrees = Vector3(-54.0, 42.0, 0.0)
	_sun_light.light_color = Color("#ffdfab")
	_sun_light.light_energy = 0.86
	_sun_light.shadow_enabled = not is_software_gl
	_sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun_light.directional_shadow_max_distance = 58.0
	_sun_light.shadow_opacity = 0.58
	_sub_vp.add_child(_sun_light)

	# Warm Subterranean Glow rising out of the Fallout Bunker Hatch
	_hatch_light = OmniLight3D.new()
	_hatch_light.name = "BunkerHatchGlow"
	_hatch_light.position = House3DBuilder.to_3d(_hatch_pos, 0.52)
	_hatch_light.light_color = Color("#ffaa3b")
	_hatch_light.omni_range = 4.6
	_hatch_light.light_energy = 1.20
	_sub_vp.add_child(_hatch_light)

	# Emergency Red CONELRAD Siren Light (pulses urgently in final 15 seconds)
	_siren_light = OmniLight3D.new()
	_siren_light.name = "ConelradSirenLight"
	_siren_light.position = House3DBuilder.to_3d(_hatch_pos, 3.6)
	_siren_light.light_color = Color("#ff2b1c")
	_siren_light.omni_range = 28.0
	_siren_light.light_energy = 0.0
	_sub_vp.add_child(_siren_light)

	# Orthographic Isometric Camera3D (-48 deg pitch, +32 deg yaw)
	_camera_3d = Camera3D.new()
	_camera_3d.name = "IsometricCamera3D"
	_camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera_3d.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	_camera_3d.size = _current_ortho_size
	_camera_3d.near = 0.5
	_camera_3d.far = 140.0
	_camera_3d.current = true
	_sub_vp.add_child(_camera_3d)
	_position_camera_3d(_cam_focus_2d, Vector2.ZERO)

	# Build 3D House, Cutaway Walls, Furniture & Bunker Hatch
	var built: Dictionary = House3DBuilder.build_house_world(_house_layout, false)
	_house_3d_root = built["root"]
	_furniture_nodes_3d = built["furniture_nodes"]
	_hatch_nodes_3d = built["hatch_nodes"]
	_sub_vp.add_child(_house_3d_root)

	_entities_3d_root = Node3D.new()
	_entities_3d_root.name = "Entities3D"
	_sub_vp.add_child(_entities_3d_root)

	_chute_fx_3d_root = Node3D.new()
	_chute_fx_3d_root.name = "ChuteFX3D"
	_sub_vp.add_child(_chute_fx_3d_root)

	# Build Articulated 3D Player Leader + Green Ground Ring
	_player_node_3d = House3DBuilder.build_character_3d(_leader_member)
	_player_node_3d.name = "Leader3D"
	_entities_3d_root.add_child(_player_node_3d)

	_player_ring_3d = MeshInstance3D.new()
	var pr_torus := TorusMesh.new()
	pr_torus.inner_radius = 0.36
	pr_torus.outer_radius = 0.44
	pr_torus.rings = 24
	pr_torus.ring_segments = 8
	_player_ring_3d.mesh = pr_torus
	_player_ring_3d.material_override = House3DBuilder._make_mat(
		COL_TOXIC_GREEN, 0.35, 0.1, COL_TOXIC_GREEN, 0.85, 0.88
	)
	_player_ring_3d.position = Vector3(0.0, 0.02, 0.0)
	_player_ring_3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player_node_3d.add_child(_player_ring_3d)

	# Build Articulated 3D Waiting Family Members
	_family_nodes_3d.clear()
	for f_var in _world_family:
		var fam: Dictionary = f_var
		var f_uid: int = int(fam["uid"])
		var m_dict: Dictionary = fam["member"]
		var f_node: Node3D = House3DBuilder.build_character_3d(m_dict)
		f_node.position = House3DBuilder.to_3d(fam["pos"], House3DBuilder.FLOOR_TOP_Y)
		var fam_ring := MeshInstance3D.new()
		var fr_torus := TorusMesh.new()
		fr_torus.inner_radius = 0.40
		fr_torus.outer_radius = 0.48
		fr_torus.rings = 24
		fr_torus.ring_segments = 8
		fam_ring.mesh = fr_torus
		var fr_mat: StandardMaterial3D = House3DBuilder._make_mat(
			COL_WATER_BLUE, 0.35, 0.1, COL_WATER_BLUE, 0.75, 0.85
		)
		fam_ring.material_override = fr_mat
		fam_ring.position = Vector3(0.0, 0.02, 0.0)
		fam_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f_node.add_child(fam_ring)
		f_node.set_meta("ring_mat", fr_mat)
		_entities_3d_root.add_child(f_node)
		_family_nodes_3d[f_uid] = f_node

	# Build 3D Supply Models
	_item_nodes_3d.clear()
	for it_var in _world_items:
		var it: Dictionary = it_var
		_ensure_item_node_3d(it)


func _ensure_item_node_3d(it: Dictionary) -> Node3D:
	var uid: int = int(it.get("uid", -1))
	if _item_nodes_3d.has(uid):
		return _item_nodes_3d[uid]
	if not is_instance_valid(_entities_3d_root):
		return null
	var iid: String = str(it.get("item_id", "soup"))
	var inode: Node3D = House3DBuilder.build_item_3d(iid, false)
	var ipos: Vector2 = it.get("pos", Vector2.ZERO) if it.get("pos") is Vector2 else Vector2.ZERO
	inode.position = House3DBuilder.to_3d(ipos, House3DBuilder.FLOOR_TOP_Y)
	_entities_3d_root.add_child(inode)
	_item_nodes_3d[uid] = inode
	return inode


func _position_camera_3d(focus_2d: Vector2, screen_shake_m: Vector2) -> void:
	if not is_instance_valid(_camera_3d):
		return
	var cam_basis: Basis = _camera_3d.transform.basis
	var cam_forward: Vector3 = -cam_basis.z
	# Shift camera look target slightly upward in screen space (+cam_basis.y * 0.68m)
	# so the 3D house frames cleanly below the top Stopwatch Banner and above the Carry Bar!
	var target_3d: Vector3 = House3DBuilder.to_3d(focus_2d, 0.36) + cam_basis.y * 0.68
	var shake_world: Vector3 = cam_basis.x * screen_shake_m.x + cam_basis.y * screen_shake_m.y
	_camera_3d.position = target_3d - cam_forward * 44.0 + shake_world


func project_2d_to_screen(pos_2d: Vector2, y_height: float = House3DBuilder.FLOOR_TOP_Y) -> Vector2:
	if not is_instance_valid(_camera_3d):
		return Vector2(-9999.0, -9999.0)
	var p3: Vector3 = House3DBuilder.to_3d(pos_2d, y_height)
	if _camera_3d.is_position_behind(p3):
		return Vector2(-9999.0, -9999.0)
	return _camera_3d.unproject_position(p3)


func _screen_to_floor_2d(screen_pos: Vector2) -> Vector2:
	if not is_instance_valid(_camera_3d):
		return _player_pos
	var ray_origin: Vector3 = _camera_3d.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = _camera_3d.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.0001:
		return _player_pos
	var t: float = (House3DBuilder.FLOOR_TOP_Y - ray_origin.y) / ray_dir.y
	var hit_3d: Vector3 = ray_origin + ray_dir * t
	return House3DBuilder.to_2d(hit_3d)


func _find_target_near_screen_click(screen_pos: Vector2, max_screen_px: float = 36.0) -> Dictionary:
	if not is_instance_valid(_camera_3d):
		return {}
	var best_d2: float = max_screen_px * max_screen_px
	var best: Dictionary = {}

	for f_var in _world_family:
		var fam: Dictionary = f_var
		if bool(fam.get("collected", false)):
			continue
		var fpos: Vector2 = fam["pos"]
		var sp_body: Vector2 = project_2d_to_screen(fpos, 0.65)
		var sp_badge: Vector2 = project_2d_to_screen(fpos, 1.35)
		var d2: float = minf(screen_pos.distance_squared_to(sp_body), screen_pos.distance_squared_to(sp_badge))
		if d2 <= best_d2:
			best_d2 = d2
			best = {
				"kind": "family",
				"uid": int(fam["uid"]),
				"pos": fpos,
				"slots": int(fam["slots"]),
				"label": "%s [%d Slots]" % [str(fam["name"]), int(fam["slots"])],
				"name": str(fam["name"]),
				"ref": fam
			}

	for it_var in _world_items:
		var it: Dictionary = it_var
		if bool(it.get("collected", false)):
			continue
		var ipos: Vector2 = it["pos"]
		var sp_it: Vector2 = project_2d_to_screen(ipos, 0.25)
		var sp_icon: Vector2 = project_2d_to_screen(ipos, 0.72)
		var d2_i: float = minf(screen_pos.distance_squared_to(sp_it), screen_pos.distance_squared_to(sp_icon))
		if d2_i <= best_d2:
			best_d2 = d2_i
			var sl: int = int(it["slots"])
			var sl_word: String = "Slot" if sl == 1 else "Slots"
			best = {
				"kind": "item",
				"uid": int(it["uid"]),
				"pos": ipos,
				"slots": sl,
				"label": "%s [%d %s]" % [str(it["name"]), sl, sl_word],
				"name": str(it["name"]),
				"item_id": str(it["item_id"]),
				"ref": it
			}

	return best


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "ScavengeHUDLayer"
	_hud_layer.layer = 2
	add_child(_hud_layer)

	_hud = _ScavengeHUD.new()
	_hud.name = "ScavengeHUD"
	_hud.scene_ref = self
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(_hud)


# ==============================================================================
# INPUT & MAIN GAMEPLAY LOOP
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.OUTRO:
		return

	if event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_TAB and _phase == Phase.SCOUT:
				_start_scavenge_phase()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_G:
				_toggle_auto_pickup()
				get_viewport().set_input_as_handled()
				return
			elif (ke.keycode == KEY_E or ke.keycode == KEY_SPACE) and _phase == Phase.SCAVENGE and not GameState.demo_mode:
				_try_interact_nearest()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_F and _phase == Phase.SCAVENGE and not GameState.demo_mode:
				if _can_dive_into_bunker():
					_dive_into_bunker()
					get_viewport().set_input_as_handled()
					return

	if event is InputEventMouseButton and not GameState.demo_mode:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var screen_click: Vector2 = mb.position
			var world_click: Vector2 = _screen_to_floor_2d(screen_click)
			_handle_world_left_click(world_click, screen_click)


func _handle_world_left_click(world_click: Vector2, screen_click: Vector2 = Vector2(-9999.0, -9999.0)) -> void:
	if _phase == Phase.SCOUT:
		_has_click_target = true
		var offset_from_start: Vector2 = world_click - _leader_start_pos
		if offset_from_start.length() > 110.0:
			offset_from_start = offset_from_start.normalized() * 110.0
		_click_target_pos = _leader_start_pos + offset_from_start
		_click_pickup_kind = ""
		_click_pickup_uid = -1
		return

	if _phase != Phase.SCAVENGE:
		return

	var clicked_target: Dictionary = {}
	if screen_click.x > -9000.0:
		clicked_target = _find_target_near_screen_click(screen_click, 36.0)
	if clicked_target.is_empty():
		clicked_target = _find_target_near_point(world_click, 44.0)

	if not clicked_target.is_empty():
		var tpos: Vector2 = clicked_target["pos"]
		if _player_pos.distance_to(tpos) <= INTERACT_RADIUS + 4.0:
			_attempt_pickup_target(clicked_target)
			_has_click_target = false
			return
		_has_click_target = true
		_click_target_pos = tpos
		_click_pickup_kind = str(clicked_target.get("kind", ""))
		_click_pickup_uid = int(clicked_target.get("uid", -1))
		return

	_has_click_target = true
	_click_target_pos = world_click
	_click_pickup_kind = ""
	_click_pickup_uid = -1


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	_anim_time += dt

	_update_timers_and_fx(dt)

	match _phase:
		Phase.SCOUT:
			_process_scout_phase(dt)
		Phase.SCAVENGE:
			_process_scavenge_phase(dt)
		Phase.OUTRO:
			_process_outro_phase(dt)

	_update_camera_and_lighting(dt)
	_sync_3d_world(dt)
	if is_instance_valid(_hud):
		_hud.sync_state()
		_hud.queue_redraw()


func _process_scout_phase(dt: float) -> void:
	_scout_time_left = maxf(0.0, _scout_time_left - dt)
	var whole_now: int = int(ceil(_scout_time_left))
	if whole_now < _last_whole_sec and whole_now > 0:
		_last_whole_sec = whole_now
		SoundManager.play_sfx("tick")

	if GameState.demo_mode:
		var scan_angle: float = _anim_time * 2.4
		_player_facing = Vector2(cos(scan_angle), sin(scan_angle))
		var gentle_orbit: Vector2 = _leader_start_pos + Vector2(cos(scan_angle), sin(scan_angle)) * 18.0
		var move_vec: Vector2 = (gentle_orbit - _player_pos) * 4.0
		_apply_player_movement(move_vec, dt, true)
	else:
		var input_dir: Vector2 = _read_manual_move_vector()
		if input_dir.length_squared() > 0.001:
			_has_click_target = false
			_apply_player_movement(input_dir * (BASE_MOVE_SPEED * 0.85), dt, true)
		elif _has_click_target:
			var to_click: Vector2 = _click_target_pos - _player_pos
			if to_click.length() <= 8.0:
				_has_click_target = false
				_apply_player_movement(Vector2.ZERO, dt, true)
			else:
				_apply_player_movement(to_click.normalized() * (BASE_MOVE_SPEED * 0.85), dt, true)
		else:
			_apply_player_movement(Vector2.ZERO, dt, true)

	_hovered_target = _find_target_near_point(_player_pos, INTERACT_RADIUS)

	if _scout_time_left <= 0.0:
		_start_scavenge_phase()


func _start_scavenge_phase() -> void:
	if _phase != Phase.SCOUT:
		return
	_phase = Phase.SCAVENGE
	_scout_time_left = 0.0
	_scavenge_time_left = _scavenge_total
	_last_whole_sec = int(ceil(_scavenge_time_left))
	_last_half_tick = -1
	_has_click_target = false
	_shake_strength = 7.5
	SoundManager.play_sfx("siren")
	_spawn_popup(
		_player_pos + Vector2(0.0, -34.0),
		"CONELRAD ALERT! %d SECONDS!" % int(round(_scavenge_total)),
		COL_HAZARD_YELLOW,
		1.55
	)


func _process_scavenge_phase(dt: float) -> void:
	_scavenge_time_left = maxf(0.0, _scavenge_time_left - dt)

	# Stopwatch tick & 15s klaxon audio cues
	var whole_sec: int = int(ceil(_scavenge_time_left))
	if whole_sec < _last_whole_sec and whole_sec > 0:
		_last_whole_sec = whole_sec
		if _scavenge_time_left <= 15.0:
			SoundManager.play_sfx("urgent_tick")
			_shake_strength = maxf(_shake_strength, 2.2 if _scavenge_time_left > 5.0 else 4.2)
		else:
			SoundManager.play_sfx("tick", -4.0)

	if _scavenge_time_left <= 5.0 and _scavenge_time_left > 0.0:
		var half_idx: int = int(floor(_scavenge_time_left * 2.0))
		if half_idx != _last_half_tick and (half_idx % 2 == 0):
			_last_half_tick = half_idx
			SoundManager.play_sfx("urgent_tick", -2.0, 1.14)

	if not _siren_15_played and _scavenge_time_left <= 15.0 and _scavenge_time_left > 0.0:
		_siren_15_played = true
		_shake_strength = maxf(_shake_strength, 6.0)
		SoundManager.play_sfx("siren")
		_spawn_popup(_hatch_pos + Vector2(0.0, -40.0), "15 SECONDS! GET TO THE HATCH!", COL_ALERT_RED, 1.8)

	# Movement (Demo Auto-Pilot vs Player Control)
	var cur_speed: float = _compute_move_speed()
	if GameState.demo_mode:
		_process_demo_autopilot(dt, cur_speed)
	else:
		_process_manual_scavenge_control(dt, cur_speed)

	# Refresh closest highlightable target within 52 px
	_hovered_target = _find_target_near_point(_player_pos, INTERACT_RADIUS)

	# Auto-pickup check (manual toggle)
	if not GameState.demo_mode and _auto_pickup:
		var auto_t: Dictionary = _find_fitting_target_near_point(_player_pos, AUTO_PICKUP_RADIUS)
		if not auto_t.is_empty():
			_attempt_pickup_target(auto_t)
			_hovered_target = _find_target_near_point(_player_pos, INTERACT_RADIUS)

	# Automatic Bunker Hatch chute deposit when stepping within hatch_radius + 18.0
	if not _carried_entries.is_empty() and _player_pos.distance_to(_hatch_pos) <= _hatch_radius + HATCH_DROP_MARGIN:
		_deposit_carried_into_hatch()

	# Check 0.0s detonation!
	if _scavenge_time_left <= 0.0 and _phase == Phase.SCAVENGE:
		_resolve_timer_expired()


func _process_manual_scavenge_control(dt: float, cur_speed: float) -> void:
	var key_dir: Vector2 = _read_manual_move_vector()
	if key_dir.length_squared() > 0.001:
		_has_click_target = false
		_apply_player_movement(key_dir * cur_speed, dt, false)
		return

	if _has_click_target:
		if not _click_pickup_kind.is_empty():
			var tracked: Dictionary = _get_target_by_uid(_click_pickup_kind, _click_pickup_uid)
			if tracked.is_empty():
				_has_click_target = false
			else:
				var tpos: Vector2 = tracked["pos"]
				_click_target_pos = tpos
				if _player_pos.distance_to(tpos) <= INTERACT_RADIUS - 4.0:
					_attempt_pickup_target(tracked)
					_has_click_target = false
					_apply_player_movement(Vector2.ZERO, dt, false)
					return

		var to_dest: Vector2 = _click_target_pos - _player_pos
		if to_dest.length() <= 10.0:
			_has_click_target = false
			_apply_player_movement(Vector2.ZERO, dt, false)
		else:
			var steer_dir: Vector2 = _compute_whisker_steer(to_dest.normalized())
			_apply_player_movement(steer_dir * cur_speed, dt, false)
	else:
		_apply_player_movement(Vector2.ZERO, dt, false)


func _has_capable_guardian_in_bunker() -> bool:
	for raw_m in GameState.family_members:
		if not (raw_m is Dictionary):
			continue
		var m: Dictionary = raw_m
		if bool(m.get("in_bunker", false)) and bool(m.get("alive", false)):
			if str(m.get("role", "adult")) != "child" and int(m.get("age", 30)) >= 13:
				return true
	return false


func _process_outro_phase(dt: float) -> void:
	_outro_elapsed += dt
	_apply_player_movement(Vector2.ZERO, dt, false)
	if _atomic_flash_alpha > 0.0:
		_atomic_flash_alpha = maxf(0.0, _atomic_flash_alpha - dt * 0.72)

	if _outro_elapsed >= OUTRO_DURATION and not _outro_transitioned:
		_outro_transitioned = true
		_reset_viewport_camera_transform()

		if GameState.game_mode == "scavenge_drill":
			GameState.request_screen(GameState.SCREEN_SUMMARY)
			return

		var living_survivors: Array = GameState.get_all_living_members()
		if living_survivors.is_empty():
			GameState.game_over = true
			GameState.victory = false
			if GameState.ending_title.is_empty():
				GameState.ending_title = "CAUGHT IN THE ATOMIC BLAST"
			if GameState.ending_description.is_empty():
				GameState.ending_description = "Nobody made it inside the fallout shelter before the CONELRAD countdown hit zero."
			GameState.request_screen(GameState.SCREEN_SUMMARY)
		elif not _has_capable_guardian_in_bunker():
			GameState.game_over = true
			GameState.victory = false
			GameState.ending_title = "NO ADULT GUARDIAN IN SHELTER"
			GameState.ending_description = "Though young family members tumbled safely down the chute, no adult or teenager made it inside to operate the blast seal and survival systems before Civil Defense rescue arrived."
			GameState.request_screen(GameState.SCREEN_SUMMARY)
		else:
			GameState.request_screen(GameState.SCREEN_BUNKER)


# ==============================================================================
# MOVEMENT, COLLISION & FURNITURE BUMP PHYSICS
# ==============================================================================

func _read_manual_move_vector() -> Vector2:
	var raw := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		raw.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		raw.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		raw.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		raw.y += 1.0
	if raw.length_squared() < 0.0001:
		return Vector2.ZERO

	if is_instance_valid(_camera_3d):
		var cam_basis: Basis = _camera_3d.global_transform.basis
		var right_2d: Vector2 = Vector2(cam_basis.x.x, cam_basis.x.z).normalized()
		var down_2d: Vector2 = Vector2(-cam_basis.y.x, -cam_basis.y.z).normalized()
		var world_dir: Vector2 = right_2d * raw.x + down_2d * raw.y
		return world_dir.normalized() if world_dir.length_squared() > 0.0001 else Vector2.ZERO

	return raw.normalized()


func _compute_move_speed() -> float:
	var speed: float = BASE_MOVE_SPEED
	var trait_id: String = str(_leader_member.get("trait", "")).to_lower()
	if trait_id == "sprinter":
		speed *= SPRINTER_MULT
	var used_slots: int = _get_used_slots()
	var encumbrance: float = maxf(0.56, 1.0 - SLOT_SLOW_PER_UNIT * float(used_slots))
	return speed * encumbrance


func _apply_player_movement(desired_vel: Vector2, dt: float, scout_leash: bool) -> void:
	_player_vel = _player_vel.move_toward(desired_vel, PLAYER_ACCEL * dt)
	if _player_vel.length_squared() > 9.0:
		_player_facing = _player_vel.normalized()

	var delta_move: Vector2 = _player_vel * dt
	var move_len: float = delta_move.length()
	if move_len > 0.001:
		var steps: int = maxi(1, int(ceil(move_len / 7.5)))
		var step_vec: Vector2 = delta_move / float(steps)
		for _i in range(steps):
			_player_pos += step_vec
			_player_pos = _resolve_collisions(_player_pos, true)
			if scout_leash:
				var from_anchor: Vector2 = _player_pos - _leader_start_pos
				if from_anchor.length() > 115.0:
					_player_pos = _leader_start_pos + from_anchor.normalized() * 115.0
					_player_pos = _resolve_collisions(_player_pos, false)

		_walk_phase += move_len * 0.11
		_dust_timer += dt
		if _dust_timer >= 0.14 and _player_vel.length() > 130.0:
			_dust_timer = 0.0
			_dust_puffs.append({
				"pos": _player_pos - _player_facing * 10.0 + Vector2(GameState.rng.randf_range(-4.0, 4.0), GameState.rng.randf_range(-4.0, 4.0)),
				"life": 0.36,
				"max_life": 0.36,
				"radius": GameState.rng.randf_range(3.5, 6.0)
			})
	else:
		_walk_phase = lerpf(_walk_phase, roundf(_walk_phase), minf(1.0, dt * 10.0))


func _resolve_collisions(pos: Vector2, apply_furniture_impulse: bool) -> Vector2:
	var p: Vector2 = pos
	for pass_idx in range(3):
		for f_var in _furniture_props:
			var prop: Dictionary = f_var
			if not bool(prop.get("solid", true)):
				continue
			var f_rect: Rect2 = prop["rect"]
			var pushed: Vector2 = _push_circle_out_of_rect(p, PLAYER_RADIUS, f_rect)
			if pushed != p:
				if apply_furniture_impulse and pass_idx == 0 and float(prop.get("bump_cd", 0.0)) <= 0.0:
					var push_dir: Vector2 = (p - pushed).normalized()
					prop["bump_vel"] = (prop["bump_vel"] as Vector2) + push_dir * 72.0
					prop["bump_rot_vel"] = float(prop.get("bump_rot_vel", 0.0)) + GameState.rng.randf_range(-3.6, 3.6)
					prop["bump_cd"] = 0.18
				p = pushed

		for w_rect in _wall_rects:
			p = _push_circle_out_of_rect(p, PLAYER_RADIUS, w_rect)

		for seg_var in _wall_segments:
			var seg: Dictionary = seg_var
			var sa: Vector2 = seg["a"]
			var sb: Vector2 = seg["b"]
			var hthick: float = float(seg.get("half_thick", 6.0))
			p = _push_circle_out_of_segment(p, PLAYER_RADIUS, sa, sb, hthick)

	var safe_bounds: Rect2 = _house_bounds.grow(-4.0)
	if safe_bounds.size.x > 32.0 and safe_bounds.size.y > 32.0:
		p.x = clampf(p.x, safe_bounds.position.x, safe_bounds.end.x)
		p.y = clampf(p.y, safe_bounds.position.y, safe_bounds.end.y)

	return p


func _push_circle_out_of_rect(center: Vector2, radius: float, rect: Rect2) -> Vector2:
	var cx: float = clampf(center.x, rect.position.x, rect.end.x)
	var cy: float = clampf(center.y, rect.position.y, rect.end.y)
	var diff: Vector2 = center - Vector2(cx, cy)
	var d_sq: float = diff.length_squared()
	if d_sq >= radius * radius:
		return center
	if d_sq > 0.0001:
		var d: float = sqrt(d_sq)
		return center + (diff / d) * (radius - d)

	var left_p: float = (center.x - rect.position.x) + radius
	var right_p: float = (rect.end.x - center.x) + radius
	var top_p: float = (center.y - rect.position.y) + radius
	var bot_p: float = (rect.end.y - center.y) + radius
	var best: float = minf(minf(left_p, right_p), minf(top_p, bot_p))
	var out: Vector2 = center
	if best == left_p:
		out.x -= left_p
	elif best == right_p:
		out.x += right_p
	elif best == top_p:
		out.y -= top_p
	else:
		out.y += bot_p
	return out


func _push_circle_out_of_segment(center: Vector2, radius: float, a: Vector2, b: Vector2, half_thick: float) -> Vector2:
	var ab: Vector2 = b - a
	var ab_sq: float = ab.length_squared()
	var t: float = clampf((center - a).dot(ab) / ab_sq, 0.0, 1.0) if ab_sq > 0.0001 else 0.0
	var closest: Vector2 = a + ab * t
	var diff: Vector2 = center - closest
	var min_dist: float = radius + half_thick
	var d_sq: float = diff.length_squared()
	if d_sq >= min_dist * min_dist:
		return center
	if d_sq > 0.0001:
		var d: float = sqrt(d_sq)
		return center + (diff / d) * (min_dist - d)
	var perp := Vector2(-ab.y, ab.x).normalized()
	return center + perp * min_dist


# ==============================================================================
# PICKUP, CHUTE DEPOSIT, BUNKER ENTRY & DRILL / LEFT-BEHIND CONSEQUENCES
# ==============================================================================

func _get_used_slots() -> int:
	var used: int = 0
	for entry_var in _carried_entries:
		var entry: Dictionary = entry_var
		used += int(entry.get("slots", 1))
	return used


func _find_target_near_point(origin: Vector2, max_dist: float) -> Dictionary:
	var best_d_sq: float = max_dist * max_dist
	var best: Dictionary = {}

	for f_var in _world_family:
		var fam: Dictionary = f_var
		if bool(fam.get("collected", false)):
			continue
		var fpos: Vector2 = fam["pos"]
		var d_sq: float = origin.distance_squared_to(fpos)
		if d_sq <= best_d_sq:
			best_d_sq = d_sq
			best = {
				"kind": "family",
				"uid": int(fam["uid"]),
				"pos": fpos,
				"slots": int(fam["slots"]),
				"label": "%s [%d Slots]" % [str(fam["name"]), int(fam["slots"])],
				"name": str(fam["name"]),
				"ref": fam
			}

	for it_var in _world_items:
		var it: Dictionary = it_var
		if bool(it.get("collected", false)):
			continue
		var ipos: Vector2 = it["pos"]
		var d_sq2: float = origin.distance_squared_to(ipos)
		if d_sq2 <= best_d_sq:
			best_d_sq = d_sq2
			var sl: int = int(it["slots"])
			var sl_word: String = "Slot" if sl == 1 else "Slots"
			best = {
				"kind": "item",
				"uid": int(it["uid"]),
				"pos": ipos,
				"slots": sl,
				"label": "%s [%d %s]" % [str(it["name"]), sl, sl_word],
				"name": str(it["name"]),
				"item_id": str(it["item_id"]),
				"ref": it
			}

	return best


func _find_fitting_target_near_point(origin: Vector2, max_dist: float) -> Dictionary:
	var free_slots: int = _max_slots - _get_used_slots()
	if free_slots <= 0:
		return {}
	var best_d_sq: float = max_dist * max_dist
	var best: Dictionary = {}

	for f_var in _world_family:
		var fam: Dictionary = f_var
		if bool(fam.get("collected", false)) or int(fam["slots"]) > free_slots:
			continue
		var fpos: Vector2 = fam["pos"]
		var d_sq: float = origin.distance_squared_to(fpos)
		if d_sq <= best_d_sq:
			best_d_sq = d_sq
			best = {"kind": "family", "uid": int(fam["uid"]), "pos": fpos, "slots": int(fam["slots"]), "name": str(fam["name"]), "ref": fam}

	for it_var in _world_items:
		var it: Dictionary = it_var
		if bool(it.get("collected", false)) or int(it["slots"]) > free_slots:
			continue
		var ipos: Vector2 = it["pos"]
		var d_sq2: float = origin.distance_squared_to(ipos)
		if d_sq2 <= best_d_sq:
			best_d_sq = d_sq2
			best = {"kind": "item", "uid": int(it["uid"]), "pos": ipos, "slots": int(it["slots"]), "name": str(it["name"]), "item_id": str(it["item_id"]), "ref": it}

	return best


func _get_target_by_uid(kind: String, uid: int) -> Dictionary:
	if kind == "family":
		for f_var in _world_family:
			var fam: Dictionary = f_var
			if int(fam["uid"]) == uid and not bool(fam.get("collected", false)):
				return {"kind": "family", "uid": uid, "pos": fam["pos"], "slots": int(fam["slots"]), "name": str(fam["name"]), "ref": fam}
	elif kind == "item":
		for it_var in _world_items:
			var it: Dictionary = it_var
			if int(it["uid"]) == uid and not bool(it.get("collected", false)):
				return {"kind": "item", "uid": uid, "pos": it["pos"], "slots": int(it["slots"]), "name": str(it["name"]), "item_id": str(it["item_id"]), "ref": it}
	return {}


func _try_interact_nearest() -> void:
	var target: Dictionary = _find_target_near_point(_player_pos, INTERACT_RADIUS)
	if target.is_empty():
		return
	_attempt_pickup_target(target)


func _attempt_pickup_target(target: Dictionary) -> bool:
	if target.is_empty() or _phase != Phase.SCAVENGE:
		return false

	var needed_slots: int = int(target.get("slots", 1))
	var used_slots: int = _get_used_slots()
	if used_slots + needed_slots > _max_slots:
		if _hands_full_timer <= 0.45:
			SoundManager.play_sfx("button_click", -2.0, 0.72)
			_spawn_popup(_player_pos + Vector2(0.0, -32.0), "HANDS FULL! RUN TO HATCH!", COL_ATOMIC_ORANGE, 1.35)
		_hands_full_timer = 1.55
		return false

	var kind: String = str(target.get("kind", ""))
	var entity_ref: Dictionary = target.get("ref", {})
	if entity_ref.is_empty() or bool(entity_ref.get("collected", false)):
		return false

	entity_ref["collected"] = true
	SoundManager.play_sfx("pickup", 0.0, GameState.rng.randf_range(0.96, 1.07))

	if kind == "family":
		var m: Dictionary = entity_ref["member"]
		var fname: String = str(entity_ref.get("name", "Family"))
		_carried_entries.append({
			"kind": "family",
			"member": m,
			"name": fname,
			"slots": needed_slots
		})
		var fpos_p: Vector2 = entity_ref.get("pos", _player_pos) if entity_ref.get("pos") is Vector2 else _player_pos
		_spawn_popup(fpos_p + Vector2(0.0, -24.0), "+%s [%d SLOTS]" % [fname.to_upper(), needed_slots], COL_HAZARD_YELLOW, 1.25)
		family_picked_up.emit(str(m.get("id", "")), needed_slots)
	else:
		var iid: String = str(entity_ref.get("item_id", "soup"))
		var sname: String = str(entity_ref.get("short_name", entity_ref.get("name", iid)))
		_carried_entries.append({
			"kind": "item",
			"item_id": iid,
			"name": str(entity_ref.get("name", sname)),
			"short_name": sname,
			"slots": needed_slots
		})
		var ipos_p: Vector2 = entity_ref.get("pos", _player_pos) if entity_ref.get("pos") is Vector2 else _player_pos
		_spawn_popup(ipos_p + Vector2(0.0, -20.0), "+%s" % sname.to_upper(), COL_PARCHMENT, 1.1)
		item_picked_up.emit(iid, needed_slots)

	if GameState.demo_mode:
		_ai_pause_timer = 0.16
	return true


func _deposit_carried_into_hatch() -> void:
	if _carried_entries.is_empty():
		return

	SoundManager.play_sfx("hatch_drop")
	var dropped_items_batch: int = 0
	var dropped_family_batch: int = 0
	var unlocked_suitcase_now: bool = false
	var idx_offset: int = 0

	for entry_var in _carried_entries:
		var entry: Dictionary = entry_var
		var kind: String = str(entry.get("kind", "item"))
		var start_p: Vector2 = _player_pos.lerp(_hatch_pos, 0.35) + Vector2(float((idx_offset % 3) - 1) * 14.0, -10.0 * float(idx_offset))

		if kind == "family":
			var m: Dictionary = entry["member"]
			m["in_bunker"] = true
			m["alive"] = true
			m["status_note"] = "Dropped safely into the fallout shelter."
			_family_deposited_count += 1
			dropped_family_batch += 1
			var fx_node_f: Node3D = null
			if is_instance_valid(_chute_fx_3d_root):
				fx_node_f = House3DBuilder.build_character_3d(m)
				_chute_fx_3d_root.add_child(fx_node_f)
			_falling_chute_fx.append({
				"kind": "family",
				"member": m,
				"pos": start_p,
				"t": 0.0,
				"dur": 0.46,
				"node_3d": fx_node_f
			})
			_spawn_popup(_hatch_pos + Vector2(0.0, -34.0 - float(idx_offset) * 18.0), "%s SAFE IN BUNKER!" % str(m.get("name", "Family")).to_upper(), COL_TOXIC_GREEN, 1.55)
		else:
			var iid: String = str(entry.get("item_id", "soup"))
			GameState.add_scavenged_item(iid, 1)
			_items_deposited_count += 1
			dropped_items_batch += 1
			_deposited_by_id[iid] = int(_deposited_by_id.get(iid, 0)) + 1

			if iid != "soup" and iid != "water":
				_gear_deposited_count += 1
				if not _secured_gear_order.has(iid):
					_secured_gear_order.append(iid)

			if iid == "suitcase" and not _suitcase_upgraded:
				_suitcase_upgraded = true
				_max_slots = 5
				_suitcase_flash_timer = 2.8
				unlocked_suitcase_now = true

			var fx_node_i: Node3D = null
			if is_instance_valid(_chute_fx_3d_root):
				fx_node_i = House3DBuilder.build_item_3d(iid, true)
				_chute_fx_3d_root.add_child(fx_node_i)
			_falling_chute_fx.append({
				"kind": "item",
				"item_id": iid,
				"pos": start_p,
				"t": 0.0,
				"dur": 0.42,
				"node_3d": fx_node_i
			})
		idx_offset += 1

	_carried_entries.clear()
	_hands_full_timer = 0.0
	_tally_pop_timer = 0.5

	GameState.scavenge_stats = {
		"items_collected": _items_deposited_count,
		"soup_cans": GameState.soup_quarters / 4,
		"water_bottles": GameState.water_quarters / 4,
		"gear_collected": _gear_deposited_count,
		"family_saved": _family_deposited_count,
		"leader_escaped": bool(_leader_member.get("in_bunker", false)) and bool(_leader_member.get("alive", false)),
		"time_remaining": maxf(0.0, snappedf(_scavenge_time_left, 0.1))
	}

	if _items_deposited_count >= 18:
		GameState.unlock_achievement("pack_mule")

	if unlocked_suitcase_now:
		_spawn_popup(_hatch_pos + Vector2(0.0, -56.0), "+1 CARRY SLOT (SUITCASE)!", COL_HAZARD_YELLOW, 2.1)
	elif dropped_items_batch > 0 and dropped_family_batch == 0:
		_spawn_popup(_hatch_pos + Vector2(0.0, -28.0), "CHUTE +%d SUPPLIES!" % dropped_items_batch, COL_TOXIC_GREEN, 1.25)

	if GameState.demo_mode:
		_ai_pause_timer = 0.26
	hatch_deposited.emit(dropped_items_batch, dropped_family_batch)


func _can_dive_into_bunker() -> bool:
	if _phase != Phase.SCAVENGE:
		return false
	var near_hatch: bool = _player_pos.distance_to(_hatch_pos) <= _hatch_radius + HATCH_END_MARGIN
	if not near_hatch:
		return false
	var time_elapsed: float = _scavenge_total - _scavenge_time_left
	var everything_cleared: bool = (_count_remaining_world_items() == 0 and _count_remaining_world_family() == 0)
	if _scavenge_time_left <= 20.0 or everything_cleared or (_items_deposited_count + _family_deposited_count > 0 and time_elapsed >= 3.0):
		return _carried_entries.is_empty() or _player_pos.distance_to(_hatch_pos) <= _hatch_radius + HATCH_END_MARGIN
	return false


func _dive_into_bunker() -> void:
	if _phase != Phase.SCAVENGE:
		return
	if not _carried_entries.is_empty():
		_deposit_carried_into_hatch()

	_leader_member["in_bunker"] = true
	_leader_member["alive"] = true
	_leader_member["status_note"] = "Dived through the fallout hatch in time!"
	_leader_caught_outside = false
	_shake_strength = 6.5
	SoundManager.play_sfx("hatch_slam")
	_finalize_scavenge_and_enter_outro(false)


func _resolve_timer_expired() -> void:
	if _phase != Phase.SCAVENGE:
		return

	var dist_to_hatch: float = _player_pos.distance_to(_hatch_pos)
	if dist_to_hatch <= _hatch_radius + HATCH_END_MARGIN:
		if not _carried_entries.is_empty():
			_deposit_carried_into_hatch()
		_leader_member["in_bunker"] = true
		_leader_member["alive"] = true
		_leader_member["status_note"] = "Tumbled into the bunker just as the blast wave struck!"
		_leader_caught_outside = false
		_shake_strength = 12.0
		SoundManager.play_sfx("hatch_slam")
		SoundManager.play_sfx("nuke_boom")
		_atomic_flash_alpha = 0.55
		_finalize_scavenge_and_enter_outro(false)
	else:
		_carried_entries.clear()
		_leader_member["in_bunker"] = false
		_leader_member["alive"] = false
		_leader_member["death_reason"] = "Caught upstairs when the nuclear shockwave vaporized the neighborhood."
		_leader_member["status_note"] = "Perished outside the shelter."
		_leader_caught_outside = true
		_shake_strength = 18.0
		_atomic_flash_alpha = 1.0
		SoundManager.play_sfx("nuke_boom")
		_finalize_scavenge_and_enter_outro(true)


func _finalize_scavenge_and_enter_outro(caught_outside: bool) -> void:
	_phase = Phase.OUTRO
	_outro_elapsed = 0.0

	# Mark any non-bunker family members as lost AND record GameState.left_behind_members
	var left_behind: Array = []
	for raw_m in GameState.family_members:
		var m: Dictionary = raw_m
		if not bool(m.get("in_bunker", false)):
			m["alive"] = false
			m["in_bunker"] = false
			if str(m.get("death_reason", "")).is_empty():
				m["death_reason"] = "Left behind upstairs when the CONELRAD siren ended."
			m["status_note"] = "Did not reach the fallout bunker."
			var lost_name: String = str(m.get("name", ""))
			if not lost_name.is_empty() and not left_behind.has(lost_name):
				left_behind.append(lost_name)
		elif not bool(m.get("alive", false)):
			var lost_name2: String = str(m.get("name", ""))
			if not lost_name2.is_empty() and not left_behind.has(lost_name2):
				left_behind.append(lost_name2)

	GameState.left_behind_members = left_behind

	if _items_deposited_count >= 18:
		GameState.unlock_achievement("pack_mule")
	if GameState.family_members.size() >= 4 and left_behind.is_empty():
		GameState.unlock_achievement("full_house")

	var survivors: Array = GameState.get_all_living_members()
	var leader_safe: bool = (not caught_outside) and bool(_leader_member.get("in_bunker", false)) and bool(_leader_member.get("alive", false))
	var drill_pts: int = _items_deposited_count * 100 + survivors.size() * 250 + (400 if leader_safe else 0) + int(round(maxf(0.0, _scavenge_time_left) * 15.0))
	var drill_grade: String = "S" if (leader_safe and left_behind.is_empty() and _items_deposited_count >= 14) else ("A" if (leader_safe and _items_deposited_count >= 10) else ("B" if leader_safe else "F"))

	GameState.scavenge_stats = {
		"items_collected": _items_deposited_count,
		"soup_cans": GameState.soup_quarters / 4,
		"water_bottles": GameState.water_quarters / 4,
		"gear_collected": _gear_deposited_count,
		"family_saved": survivors.size(),
		"leader_escaped": leader_safe,
		"time_remaining": maxf(0.0, snappedf(_scavenge_time_left, 0.1)),
		"drill_score": drill_pts,
		"drill_grade": drill_grade
	}

	if GameState.game_mode == "scavenge_drill":
		GameState.game_over = true
		GameState.victory = leader_safe
		GameState.ending_route = "scavenge_drill"
		var house_label: String = str(GameState.selected_house.get("name", "Selected Residence"))
		var ldr_name: String = str(_leader_member.get("name", "Leader"))
		if leader_safe:
			GameState.ending_title = "CIVIL DEFENSE DRILL COMPLETE — GRADE %s (%d PTS)" % [drill_grade, drill_pts]
			GameState.ending_description = "60-Second CONELRAD Readiness Drill completed at %s! %s sealed the blast hatch with %.1fs to spare, evacuating %d/%d household members and %d supplies (%d Soup, %d Water, %d Survival Gear)." % [
				house_label, ldr_name, maxf(0.0, _scavenge_time_left),
				survivors.size(), GameState.family_members.size(),
				_items_deposited_count, GameState.soup_quarters / 4,
				GameState.water_quarters / 4, _gear_deposited_count
			]
		else:
			GameState.ending_title = "SCAVENGE DRILL FAILED — CAUGHT ABOVE GROUND (%d PTS)" % drill_pts
			GameState.ending_description = "The CONELRAD countdown hit 0.0s before %s reached the fallout hatch at %s! Prior chute haul: %d/%d household members and %d supplies." % [
				ldr_name, house_label, survivors.size(), GameState.family_members.size(), _items_deposited_count
			]
	elif survivors.is_empty():
		GameState.game_over = true
		GameState.victory = false
		if GameState.ending_title.is_empty():
			GameState.ending_title = "CAUGHT IN THE ATOMIC BLAST"
		if GameState.ending_description.is_empty():
			GameState.ending_description = "Nobody made it inside the fallout shelter before the CONELRAD countdown hit zero."
	elif not _has_capable_guardian_in_bunker():
		GameState.game_over = true
		GameState.victory = false
		GameState.ending_title = "NO ADULT GUARDIAN IN SHELTER"
		GameState.ending_description = "Though young family members tumbled safely down the chute, no adult or teenager made it inside to operate the blast seal and survival systems before Civil Defense rescue arrived."

	scavenge_finished.emit(leader_safe, survivors.size())


func _toggle_auto_pickup() -> void:
	_auto_pickup = not _auto_pickup
	SoundManager.play_sfx("button_click")


func trigger_hud_skip_scout() -> void:
	if _phase == Phase.SCOUT:
		_start_scavenge_phase()


func trigger_hud_dive_in() -> void:
	if _can_dive_into_bunker():
		_dive_into_bunker()


# ==============================================================================
# SMART DEMO AUTO-PILOT (PATHFINDING + PRIORITY SCAVENGING)
# ==============================================================================

func _process_demo_autopilot(dt: float, cur_speed: float) -> void:
	if _ai_pause_timer > 0.0:
		_ai_pause_timer = maxf(0.0, _ai_pause_timer - dt)
		_apply_player_movement(Vector2.ZERO, dt, false)
		return

	var expired_keys: Array = []
	for k in _ai_blacklist.keys():
		var rem: float = float(_ai_blacklist[k]) - dt
		if rem <= 0.0:
			expired_keys.append(k)
		else:
			_ai_blacklist[k] = rem
	for ek in expired_keys:
		_ai_blacklist.erase(ek)

	var free_slots: int = _max_slots - _get_used_slots()
	var reserved_for_goal: int = 0
	if _ai_goal_kind == "family" or _ai_goal_kind == "item":
		var goal_t: Dictionary = _get_target_by_uid(_ai_goal_kind, _ai_goal_uid)
		if not goal_t.is_empty():
			reserved_for_goal = int(goal_t.get("slots", 1))

	if free_slots > reserved_for_goal:
		var spare_slots: int = free_slots - reserved_for_goal
		for it_var in _world_items:
			var it: Dictionary = it_var
			if bool(it.get("collected", false)):
				continue
			var sl: int = int(it["slots"])
			if sl <= spare_slots and _player_pos.distance_to(it["pos"]) <= INTERACT_RADIUS - 6.0:
				_attempt_pickup_target({
					"kind": "item",
					"uid": int(it["uid"]),
					"pos": it["pos"],
					"slots": sl,
					"name": str(it["name"]),
					"item_id": str(it["item_id"]),
					"ref": it
				})
				break

	free_slots = _max_slots - _get_used_slots()

	var home_dist: float = _player_pos.distance_to(_hatch_pos)
	var return_budget_sec: float = (home_dist / maxf(cur_speed, 130.0)) * 1.55 + 3.1
	var house_empty: bool = (_count_remaining_world_items() == 0 and _count_remaining_world_family() == 0)
	var must_head_home: bool = (_scavenge_time_left <= maxf(4.2, return_budget_sec)) or house_empty

	if must_head_home:
		if _player_pos.distance_to(_hatch_pos) <= _hatch_radius + 14.0 and _carried_entries.is_empty():
			if _scavenge_time_left <= 2.7 or house_empty:
				_dive_into_bunker()
				return
			_apply_player_movement(Vector2.ZERO, dt, false)
			return
		_ai_steer_toward(_hatch_pos, "hatch", -1, dt, cur_speed)
		return

	var has_carried_suitcase: bool = _is_carrying_item("suitcase")
	var best_next: Dictionary = _pick_best_demo_target(free_slots)

	if free_slots <= 0 or best_next.is_empty() or (has_carried_suitcase and _get_used_slots() >= 3):
		_ai_steer_toward(_hatch_pos, "hatch", -1, dt, cur_speed)
		return

	var active_goal: Dictionary = _get_target_by_uid(_ai_goal_kind, _ai_goal_uid)
	if active_goal.is_empty() or int(active_goal.get("slots", 1)) > free_slots or _ai_blacklist.has(_ai_goal_uid):
		active_goal = best_next
		_ai_goal_kind = str(active_goal["kind"])
		_ai_goal_uid = int(active_goal["uid"])
		_ai_target_attempt_time = 0.0
		_ai_repath_timer = 0.0

	var gpos: Vector2 = active_goal["pos"]
	if _player_pos.distance_to(gpos) <= INTERACT_RADIUS - 6.0:
		if _attempt_pickup_target(active_goal):
			_ai_goal_kind = ""
			_ai_goal_uid = -1
			_ai_waypoints.clear()
			return

	_ai_target_attempt_time += dt
	if _ai_target_attempt_time > 4.2:
		_ai_blacklist[_ai_goal_uid] = 7.0
		_ai_goal_kind = ""
		_ai_goal_uid = -1
		_ai_waypoints.clear()
		return

	_ai_steer_toward(gpos, _ai_goal_kind, _ai_goal_uid, dt, cur_speed)


func _pick_best_demo_target(free_slots: int) -> Dictionary:
	if free_slots <= 0:
		return {}

	var best_score: float = -999999.0
	var best_target: Dictionary = {}

	for f_var in _world_family:
		var fam: Dictionary = f_var
		var uid: int = int(fam["uid"])
		if bool(fam.get("collected", false)) or _ai_blacklist.has(uid):
			continue
		var f_slots: int = int(fam["slots"])
		if f_slots > free_slots:
			continue
		var fpos: Vector2 = fam["pos"]
		var score: float = 232.0 + (8.0 if f_slots == 3 else 0.0) - _player_pos.distance_to(fpos) * 0.14
		if score > best_score:
			best_score = score
			best_target = {"kind": "family", "uid": uid, "pos": fpos, "slots": f_slots, "name": str(fam["name"]), "ref": fam}

	var soup_total: int = _count_total_secured_or_carried("soup")
	var water_total: int = _count_total_secured_or_carried("water")
	var has_weapon: bool = _count_total_secured_or_carried("rifle") > 0 or _count_total_secured_or_carried("axe") > 0

	for it_var in _world_items:
		var it: Dictionary = it_var
		var uid2: int = int(it["uid"])
		if bool(it.get("collected", false)) or _ai_blacklist.has(uid2):
			continue
		var i_slots: int = int(it["slots"])
		if i_slots > free_slots:
			continue

		var iid: String = str(it["item_id"])
		var ipos: Vector2 = it["pos"]
		var owned_n: int = _count_total_secured_or_carried(iid)
		var base_priority: float = 110.0

		match iid:
			"suitcase":
				base_priority = 275.0 if (not _suitcase_upgraded and owned_n == 0) else 80.0
			"gas_mask":
				base_priority = 205.0 if owned_n == 0 else 95.0
			"medkit":
				base_priority = 198.0 if owned_n == 0 else 132.0
			"radio":
				base_priority = 194.0 if owned_n == 0 else 90.0
			"soup":
				base_priority = (190.0 - float(soup_total) * 7.0) if soup_total < 4 else 128.0
			"water":
				base_priority = (190.0 - float(water_total) * 7.0) if water_total < 4 else 128.0
			"rifle", "axe":
				base_priority = 176.0 if not has_weapon else 108.0
			"book":
				base_priority = 168.0 if owned_n == 0 else 92.0
			"flashlight", "map", "toolbox", "padlock":
				base_priority = 146.0 if owned_n == 0 else 90.0
			"ammo", "bug_spray":
				base_priority = 136.0
			_:
				base_priority = 112.0 if owned_n == 0 else 85.0

		var score2: float = base_priority - _player_pos.distance_to(ipos) * 0.17
		if score2 > best_score:
			best_score = score2
			best_target = {"kind": "item", "uid": uid2, "pos": ipos, "slots": i_slots, "name": str(it["name"]), "item_id": iid, "ref": it}

	return best_target


func _ai_steer_toward(goal_pos: Vector2, goal_kind: String, goal_uid: int, dt: float, cur_speed: float) -> void:
	_ai_repath_timer -= dt
	var goal_shifted: bool = _ai_goal_pos.distance_to(goal_pos) > 20.0
	if goal_shifted or _ai_repath_timer <= 0.0 or _ai_waypoints.is_empty():
		_ai_goal_pos = goal_pos
		_ai_goal_kind = goal_kind
		_ai_goal_uid = goal_uid
		_ai_waypoints = _compute_nav_path(_player_pos, goal_pos)
		_ai_wp_index = 0
		_ai_repath_timer = 0.35

	while _ai_wp_index < _ai_waypoints.size() - 1:
		if _player_pos.distance_to(_ai_waypoints[_ai_wp_index]) <= 20.0:
			_ai_wp_index += 1
		else:
			break

	var desired_point: Vector2 = goal_pos
	if _ai_wp_index >= 0 and _ai_wp_index < _ai_waypoints.size():
		desired_point = _ai_waypoints[_ai_wp_index]

	_ai_progress_timer += dt
	if _ai_progress_timer >= 0.38:
		var moved: float = _player_pos.distance_to(_ai_progress_anchor)
		_ai_progress_anchor = _player_pos
		_ai_progress_timer = 0.0
		if moved < 14.0:
			_ai_waypoints = _fallback_find_path(_player_pos, goal_pos)
			_ai_wp_index = 0
			var to_g: Vector2 = (goal_pos - _player_pos).normalized()
			var side_sign: float = 1.0 if GameState.rng.randf() > 0.5 else -1.0
			_ai_sidestep_dir = Vector2(-to_g.y, to_g.x) * side_sign
			_ai_sidestep_timer = 0.24

	var raw_dir: Vector2 = (desired_point - _player_pos)
	if raw_dir.length_squared() < 1.0:
		raw_dir = goal_pos - _player_pos
	var move_dir: Vector2 = raw_dir.normalized() if raw_dir.length_squared() > 0.001 else Vector2.ZERO

	if _ai_sidestep_timer > 0.0:
		_ai_sidestep_timer -= dt
		move_dir = (move_dir * 0.45 + _ai_sidestep_dir * 0.85).normalized()

	var steered: Vector2 = _compute_whisker_steer(move_dir)
	_apply_player_movement(steered * cur_speed, dt, false)


func _compute_nav_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	if not _nav_grid.is_empty():
		var raw_path: PackedVector2Array = HouseGenerator.find_path(_nav_grid, from_pos, to_pos)
		for p_pt in raw_path:
			pts.append(p_pt)

	if pts.size() < 2:
		pts = _fallback_find_path(from_pos, to_pos)
	if pts.is_empty():
		pts.append(to_pos)
	return pts


func _compute_whisker_steer(desired_dir: Vector2) -> Vector2:
	if desired_dir.length_squared() < 0.0001:
		return Vector2.ZERO
	var probe_dist: float = 20.0
	if not _is_circle_blocked(_player_pos + desired_dir * probe_dist, PLAYER_RADIUS * 0.92):
		return desired_dir

	var angles: Array[float] = [0.38, -0.38, 0.78, -0.78, 1.18, -1.18, 1.57, -1.57]
	for ang in angles:
		var cand: Vector2 = desired_dir.rotated(ang)
		if not _is_circle_blocked(_player_pos + cand * probe_dist, PLAYER_RADIUS * 0.88):
			return cand
	return desired_dir


func _is_circle_blocked(pos: Vector2, radius: float) -> bool:
	for w_rect in _wall_rects:
		if _circle_hits_rect(pos, radius, w_rect):
			return true
	for seg_var in _wall_segments:
		var seg: Dictionary = seg_var
		var sa: Vector2 = seg["a"]
		var sb: Vector2 = seg["b"]
		var ht: float = float(seg.get("half_thick", 6.0))
		if _push_circle_out_of_segment(pos, radius, sa, sb, ht) != pos:
			return true
	for f_var in _furniture_props:
		var prop: Dictionary = f_var
		if bool(prop.get("solid", true)) and _circle_hits_rect(pos, radius, prop["rect"]):
			return true
	return false


func _circle_hits_rect(pos: Vector2, radius: float, rect: Rect2) -> bool:
	var cx: float = clampf(pos.x, rect.position.x, rect.end.x)
	var cy: float = clampf(pos.y, rect.position.y, rect.end.y)
	return pos.distance_squared_to(Vector2(cx, cy)) < radius * radius


func _build_local_fallback_grid() -> void:
	var padded: Rect2 = _house_bounds.grow(24.0)
	_local_grid_origin = padded.position
	_local_grid_cell = 20.0
	_local_grid_cols = clampi(int(ceil(padded.size.x / _local_grid_cell)), 8, 120)
	_local_grid_rows = clampi(int(ceil(padded.size.y / _local_grid_cell)), 8, 120)
	_local_grid_blocked.resize(_local_grid_cols * _local_grid_rows)

	for ry in range(_local_grid_rows):
		for cx in range(_local_grid_cols):
			var world_p := _local_grid_origin + Vector2((float(cx) + 0.5) * _local_grid_cell, (float(ry) + 0.5) * _local_grid_cell)
			var blocked: bool = _is_circle_blocked(world_p, PLAYER_RADIUS * 0.78)
			_local_grid_blocked[ry * _local_grid_cols + cx] = 1 if blocked else 0


func _fallback_find_path(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if _local_grid_cols <= 0 or _local_grid_rows <= 0:
		result.append(to_pos)
		return result

	var s_cell: Vector2i = _world_to_local_cell(from_pos)
	var g_cell: Vector2i = _world_to_local_cell(to_pos)
	s_cell = _nearest_unblocked_cell(s_cell)
	g_cell = _nearest_unblocked_cell(g_cell)
	if s_cell == g_cell:
		result.append(to_pos)
		return result

	var total: int = _local_grid_cols * _local_grid_rows
	var came_from := PackedInt32Array()
	came_from.resize(total)
	came_from.fill(-1)

	var start_idx: int = s_cell.y * _local_grid_cols + s_cell.x
	var goal_idx: int = g_cell.y * _local_grid_cols + g_cell.x
	var queue: Array[int] = [start_idx]
	came_from[start_idx] = start_idx
	var head: int = 0
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	var found: bool = false
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		if cur == goal_idx:
			found = true
			break
		var cx: int = cur % _local_grid_cols
		var cy: int = cur / _local_grid_cols
		for d in dirs:
			var nx: int = cx + d.x
			var ny: int = cy + d.y
			if nx < 0 or nx >= _local_grid_cols or ny < 0 or ny >= _local_grid_rows:
				continue
			var nidx: int = ny * _local_grid_cols + nx
			if came_from[nidx] != -1 or _local_grid_blocked[nidx] != 0:
				continue
			if d.x != 0 and d.y != 0:
				if _local_grid_blocked[cy * _local_grid_cols + nx] != 0 or _local_grid_blocked[ny * _local_grid_cols + cx] != 0:
					continue
			came_from[nidx] = cur
			queue.append(nidx)

	if not found:
		result.append(to_pos)
		return result

	var rev: Array[Vector2] = [to_pos]
	var walk: int = goal_idx
	var guard: int = 0
	while walk != start_idx and guard < total:
		var wx: int = walk % _local_grid_cols
		var wy: int = walk / _local_grid_cols
		rev.append(_local_grid_origin + Vector2((float(wx) + 0.5) * _local_grid_cell, (float(wy) + 0.5) * _local_grid_cell))
		walk = came_from[walk]
		guard += 1

	rev.reverse()
	return rev


func _world_to_local_cell(p: Vector2) -> Vector2i:
	var gx: int = clampi(int(floor((p.x - _local_grid_origin.x) / _local_grid_cell)), 0, _local_grid_cols - 1)
	var gy: int = clampi(int(floor((p.y - _local_grid_origin.y) / _local_grid_cell)), 0, _local_grid_rows - 1)
	return Vector2i(gx, gy)


func _nearest_unblocked_cell(cell: Vector2i) -> Vector2i:
	if _local_grid_blocked[cell.y * _local_grid_cols + cell.x] == 0:
		return cell
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var nx: int = clampi(cell.x + dx, 0, _local_grid_cols - 1)
				var ny: int = clampi(cell.y + dy, 0, _local_grid_rows - 1)
				if _local_grid_blocked[ny * _local_grid_cols + nx] == 0:
					return Vector2i(nx, ny)
	return cell


# ==============================================================================
# HELPERS, QUERIES, 3D CAMERA/LIGHTING & FX SYNC
# ==============================================================================

func _is_carrying_item(item_id: String) -> bool:
	for e_var in _carried_entries:
		var e: Dictionary = e_var
		if str(e.get("kind", "")) == "item" and str(e.get("item_id", "")) == item_id:
			return true
	return false


func _count_total_secured_or_carried(item_id: String) -> int:
	var total: int = int(_deposited_by_id.get(item_id, 0))
	for e_var in _carried_entries:
		var e: Dictionary = e_var
		if str(e.get("kind", "")) == "item" and str(e.get("item_id", "")) == item_id:
			total += 1
	return total


func _count_remaining_world_items() -> int:
	var c: int = 0
	for it_var in _world_items:
		var it: Dictionary = it_var
		if not bool(it.get("collected", false)):
			c += 1
	return c


func _count_remaining_world_family() -> int:
	var c: int = 0
	for f_var in _world_family:
		var fam: Dictionary = f_var
		if not bool(fam.get("collected", false)):
			c += 1
	return c


func _spawn_popup(pos: Vector2, text: String, col: Color, dur: float = 1.25) -> void:
	_floating_popups.append({
		"pos": pos,
		"text": text,
		"color": col,
		"t": 0.0,
		"dur": dur
	})


func _update_timers_and_fx(dt: float) -> void:
	_hands_full_timer = maxf(0.0, _hands_full_timer - dt)
	_suitcase_flash_timer = maxf(0.0, _suitcase_flash_timer - dt)
	_tally_pop_timer = maxf(0.0, _tally_pop_timer - dt)
	_shake_strength = maxf(0.0, _shake_strength - dt * 18.0)

	# Spring-damper physics on bumped furniture
	for f_var in _furniture_props:
		var prop: Dictionary = f_var
		prop["bump_cd"] = maxf(0.0, float(prop.get("bump_cd", 0.0)) - dt)
		var b_off: Vector2 = prop["bump_offset"]
		var b_vel: Vector2 = prop["bump_vel"]
		if b_off.length_squared() > 0.001 or b_vel.length_squared() > 0.001:
			b_vel += (-b_off * 180.0 - b_vel * 16.0) * dt
			b_off += b_vel * dt
			if b_off.length() > 6.5:
				b_off = b_off.normalized() * 6.5
			prop["bump_offset"] = b_off
			prop["bump_vel"] = b_vel

		var r_off: float = float(prop.get("bump_rot", 0.0))
		var r_vel: float = float(prop.get("bump_rot_vel", 0.0))
		if absf(r_off) > 0.0001 or absf(r_vel) > 0.0001:
			r_vel += (-r_off * 190.0 - r_vel * 16.0) * dt
			r_off = clampf(r_off + r_vel * dt, -0.09, 0.09)
			prop["bump_rot"] = r_off
			prop["bump_rot_vel"] = r_vel

	# Update dust puffs
	var idx: int = _dust_puffs.size() - 1
	while idx >= 0:
		var puff: Dictionary = _dust_puffs[idx]
		var life: float = float(puff["life"]) - dt
		if life <= 0.0:
			_dust_puffs.remove_at(idx)
		else:
			puff["life"] = life
		idx -= 1

	# Update falling chute animations (and free 3D FX node when done)
	idx = _falling_chute_fx.size() - 1
	while idx >= 0:
		var fx: Dictionary = _falling_chute_fx[idx]
		var t_val: float = float(fx["t"]) + dt
		if t_val >= float(fx["dur"]):
			var fx_n: Variant = fx.get("node_3d", null)
			if fx_n is Node and is_instance_valid(fx_n):
				(fx_n as Node).queue_free()
			_falling_chute_fx.remove_at(idx)
		else:
			fx["t"] = t_val
		idx -= 1

	# Update floating popups
	idx = _floating_popups.size() - 1
	while idx >= 0:
		var pop: Dictionary = _floating_popups[idx]
		var pt: float = float(pop["t"]) + dt
		if pt >= float(pop["dur"]):
			_floating_popups.remove_at(idx)
		else:
			pop["t"] = pt
			pop["pos"] = (pop["pos"] as Vector2) + Vector2(0.0, -24.0 * dt)
		idx -= 1


func _update_camera_and_lighting(dt: float) -> void:
	if _is_headless or not is_instance_valid(_camera_3d):
		return

	var target_ortho: float = _base_ortho_size
	if _phase == Phase.SCOUT:
		target_ortho = clampf(_base_ortho_size * 1.06, 15.8, 20.2)
	elif _phase == Phase.OUTRO:
		target_ortho = clampf(_base_ortho_size * 0.88, 13.8, 16.5)

	_current_ortho_size = lerpf(_current_ortho_size, target_ortho, minf(1.0, dt * 4.5))
	_camera_3d.size = _current_ortho_size

	var house_mid: Vector2 = _house_bounds.get_center()
	var desired_focus: Vector2 = house_mid.lerp(_player_pos, 0.38)
	if _phase == Phase.SCOUT:
		desired_focus = house_mid.lerp(_player_pos, 0.16)
	elif _phase == Phase.OUTRO and not _leader_caught_outside:
		desired_focus = house_mid.lerp(_hatch_pos, 0.65)

	var clamp_pad: Rect2 = _house_bounds.grow(-110.0)
	if clamp_pad.size.x > 20.0 and clamp_pad.size.y > 20.0:
		desired_focus.x = clampf(desired_focus.x, clamp_pad.position.x, clamp_pad.end.x)
		desired_focus.y = clampf(desired_focus.y, clamp_pad.position.y, clamp_pad.end.y)

	_cam_focus_2d = _cam_focus_2d.lerp(desired_focus, minf(1.0, dt * 7.5))

	var total_shake: float = _shake_strength
	if _phase == Phase.SCAVENGE and _scavenge_time_left <= 4.5:
		var tremor: float = float(GameState.nuke_config.get("tremor_intensity", 0.6))
		total_shake = maxf(total_shake, (4.5 - _scavenge_time_left) * 0.72 * tremor)

	var shake_m := Vector2.ZERO
	if total_shake > 0.05:
		var m_amp: float = total_shake * 0.022
		shake_m = Vector2(
			GameState.rng.randf_range(-m_amp, m_amp),
			GameState.rng.randf_range(-m_amp, m_amp)
		)

	_position_camera_3d(_cam_focus_2d, shake_m)

	# Dynamic Sunlight & CONELRAD Siren Lighting
	if is_instance_valid(_sun_light):
		var urgency_t: float = 0.0
		if _phase == Phase.SCAVENGE:
			urgency_t = clampf(1.0 - (_scavenge_time_left / maxf(1.0, _scavenge_total)), 0.0, 1.0)
		elif _phase == Phase.OUTRO:
			urgency_t = 1.0
		var golden_sun := Color("#ffdfab")
		var atomic_sun := Color("#ff7c3b")
		_sun_light.light_color = golden_sun.lerp(atomic_sun, pow(urgency_t, 1.6))
		_sun_light.light_energy = 0.86 + urgency_t * 0.24 + _atomic_flash_alpha * 1.8

	if is_instance_valid(_siren_light):
		if _phase == Phase.SCAVENGE and _scavenge_time_left <= 15.0:
			var klaxon_p: float = 0.5 + 0.5 * sin(_anim_time * 10.5)
			_siren_light.light_energy = 0.35 + klaxon_p * 1.85
			_siren_light.position = House3DBuilder.to_3d(
				_hatch_pos + Vector2(cos(_anim_time * 4.5), sin(_anim_time * 4.5)) * 90.0,
				3.4
			)
		else:
			_siren_light.light_energy = 0.0

	if is_instance_valid(_hatch_light):
		var hpulse: float = 0.5 + 0.5 * sin(_anim_time * 5.2)
		var has_loot: bool = not _carried_entries.is_empty()
		_hatch_light.light_color = COL_TOXIC_GREEN if has_loot else Color("#ffaa3b")
		_hatch_light.light_energy = (1.55 if has_loot else 1.15) + 0.35 * hpulse


func _sync_3d_world(dt: float) -> void:
	if _is_headless:
		return

	# 1. Sync bumped 3D furniture props
	for idx in range(_furniture_props.size()):
		if not _furniture_nodes_3d.has(idx):
			continue
		var prop: Dictionary = _furniture_props[idx]
		var f_node: Node3D = _furniture_nodes_3d[idx]
		if not is_instance_valid(f_node):
			continue
		var base_r: Rect2 = prop["rect"]
		var b_off: Vector2 = prop["bump_offset"]
		var b_rot: float = float(prop.get("bump_rot", 0.0))
		var base_yaw: float = float(f_node.get_meta("base_yaw", 0.0))
		f_node.position = House3DBuilder.to_3d(base_r.get_center() + b_off, House3DBuilder.FLOOR_TOP_Y)
		f_node.rotation = Vector3(b_off.y * 0.018, base_yaw + b_rot, -b_off.x * 0.018)

	# 2. Sync Bunker Hatch Beacon Ring & Slamming Steel Lid
	if not _hatch_nodes_3d.is_empty():
		var lid_p: Node3D = _hatch_nodes_3d.get("lid_pivot", null)
		if is_instance_valid(lid_p):
			var target_lid_x: float = -174.0
			if _phase == Phase.OUTRO and not _leader_caught_outside:
				target_lid_x = 0.0
			lid_p.rotation_degrees.x = lerpf(lid_p.rotation_degrees.x, target_lid_x, minf(1.0, dt * 14.0))

		var b_mat: StandardMaterial3D = _hatch_nodes_3d.get("beacon_mat", null)
		var b_ring: MeshInstance3D = _hatch_nodes_3d.get("beacon_ring", null)
		if b_mat != null and is_instance_valid(b_ring):
			var pulse: float = 0.5 + 0.5 * sin(_anim_time * 5.4)
			var urgent: bool = (_phase == Phase.SCAVENGE and _scavenge_time_left <= 15.0)
			var z_col: Color = COL_ALERT_RED if urgent else (COL_TOXIC_GREEN if not _carried_entries.is_empty() else COL_HAZARD_YELLOW)
			b_mat.albedo_color = Color(z_col.r, z_col.g, z_col.b, 0.65 + 0.25 * pulse)
			b_mat.emission = z_col
			b_mat.emission_energy_multiplier = 0.75 + 0.75 * pulse
			var s_pulse: float = 1.0 + 0.025 * pulse
			b_ring.scale = Vector3(s_pulse, 1.0, s_pulse)

	# 3. Sync 3D Player Leader + Articulated Limbs + Overhead Carried Stack
	if is_instance_valid(_player_node_3d):
		var hide_leader: bool = (_phase == Phase.OUTRO and not _leader_caught_outside)
		_player_node_3d.visible = not hide_leader
		if not hide_leader:
			_player_node_3d.position = House3DBuilder.to_3d(_player_pos, House3DBuilder.FLOOR_TOP_Y)
			var target_yaw: float = atan2(_player_facing.x, _player_facing.y)
			_player_node_3d.rotation.y = lerp_angle(_player_node_3d.rotation.y, target_yaw, minf(1.0, dt * 16.0))
			var spd_ratio: float = _player_vel.length() / BASE_MOVE_SPEED
			House3DBuilder.animate_character_3d(
				_player_node_3d,
				_walk_phase,
				spd_ratio,
				_carried_entries.size(),
				_anim_time,
				false
			)

			var sig_parts: PackedStringArray = PackedStringArray()
			for ce_var in _carried_entries:
				var ce: Dictionary = ce_var
				sig_parts.append(str(ce.get("kind", "")) + ":" + str(ce.get("item_id", ce.get("name", ""))))
			var cur_sig: String = "|".join(sig_parts)
			if cur_sig != _last_carried_sig:
				_last_carried_sig = cur_sig
				House3DBuilder.sync_carried_stack_3d(_player_node_3d, _carried_entries)

	# 4. Sync 3D Waiting Family Members
	var hovered_kind: String = str(_hovered_target.get("kind", ""))
	var hovered_uid: int = int(_hovered_target.get("uid", -1))

	for f_var in _world_family:
		var fam: Dictionary = f_var
		var f_uid: int = int(fam["uid"])
		if not _family_nodes_3d.has(f_uid):
			continue
		var f_node: Node3D = _family_nodes_3d[f_uid]
		if not is_instance_valid(f_node):
			continue
		var collected_f: bool = bool(fam.get("collected", false))
		f_node.visible = not collected_f
		if collected_f:
			continue
		var fpos: Vector2 = fam["pos"]
		f_node.position = House3DBuilder.to_3d(fpos, House3DBuilder.FLOOR_TOP_Y)
		var look_v: Vector2 = (_player_pos - fpos).normalized() if _player_pos.distance_to(fpos) > 2.0 else Vector2(0.0, 1.0)
		f_node.rotation.y = lerp_angle(f_node.rotation.y, atan2(look_v.x, look_v.y), minf(1.0, dt * 8.0))
		House3DBuilder.animate_character_3d(f_node, 0.0, 0.0, 0, _anim_time + float(fam.get("bob_phase", 0.0)), true)

		var fr_mat: StandardMaterial3D = f_node.get_meta("ring_mat", null)
		if fr_mat != null:
			var is_hov_f: bool = (hovered_kind == "family" and hovered_uid == f_uid)
			var rc_f: Color = COL_HAZARD_YELLOW if is_hov_f else COL_WATER_BLUE
			fr_mat.albedo_color = rc_f
			fr_mat.emission = rc_f
			fr_mat.emission_energy_multiplier = 1.45 if is_hov_f else 0.65

	# 5. Sync 3D Supply Items (bobbing, rotating, highlight ring)
	for it_var in _world_items:
		var it: Dictionary = it_var
		var i_uid: int = int(it["uid"])
		var collected_i: bool = bool(it.get("collected", false))
		var inode: Node3D = _ensure_item_node_3d(it)
		if not is_instance_valid(inode):
			continue
		inode.visible = not collected_i
		if collected_i:
			continue

		var ipos: Vector2 = it["pos"]
		inode.position = House3DBuilder.to_3d(ipos, House3DBuilder.FLOOR_TOP_Y)
		var mpivot: Node3D = inode.get_node_or_null("ModelPivot")
		var phase_off: float = float(it.get("bob_phase", 0.0))
		if mpivot != null:
			mpivot.position.y = 0.25 + sin(_anim_time * 3.4 + phase_off) * 0.045
			mpivot.rotation.y = _anim_time * 1.35 + phase_off

		var is_hov_i: bool = (hovered_kind == "item" and hovered_uid == i_uid)
		var rmat: StandardMaterial3D = inode.get_meta("ring_mat", null)
		var hring: Node3D = inode.get_node_or_null("HoverRing")
		if rmat != null and hring != null:
			var base_rc: Color = inode.get_meta("base_ring_col", COL_HAZARD_YELLOW)
			var active_rc: Color = COL_HAZARD_YELLOW if (is_hov_i or _phase == Phase.SCOUT) else base_rc
			rmat.albedo_color = active_rc
			rmat.emission = active_rc
			rmat.emission_energy_multiplier = 1.55 if is_hov_i else (0.95 if _phase == Phase.SCOUT else 0.45)
			var sc_r: float = 1.18 + 0.06 * sin(_anim_time * 8.5) if is_hov_i else 1.0
			hring.scale = Vector3(sc_r, 1.0, sc_r)

	# 6. Sync 3D Tumbling Chute Drop Props
	for fx_var in _falling_chute_fx:
		var fx: Dictionary = fx_var
		var fx_node: Variant = fx.get("node_3d", null)
		if not (fx_node is Node3D) or not is_instance_valid(fx_node):
			continue
		var n3: Node3D = fx_node
		var prog: float = clampf(float(fx["t"]) / maxf(0.01, float(fx["dur"])), 0.0, 1.0)
		var pos_2d_cur: Vector2 = (fx["pos"] as Vector2).lerp(_hatch_pos, ease(prog, 0.5))
		var arc_y: float = lerpf(1.05, -0.35, prog * prog) + sin(prog * PI) * 0.35
		var sc_3d: float = lerpf(0.85, 0.22, prog)
		n3.position = House3DBuilder.to_3d(pos_2d_cur, arc_y)
		n3.rotation = Vector3(prog * 3.2, prog * 5.4, prog * 2.1)
		n3.scale = Vector3(sc_3d, sc_3d, sc_3d)


# ==============================================================================
# GEOMETRY & COLOR UTILITIES
# ==============================================================================

func _to_packed_poly(raw: Variant) -> PackedVector2Array:
	if raw is PackedVector2Array:
		return raw
	var res := PackedVector2Array()
	if raw is Array:
		for v in raw:
			if v is Vector2:
				res.append(v)
	return res


func _sanitize_polygon(poly: PackedVector2Array) -> PackedVector2Array:
	var cleaned := PackedVector2Array()
	for pt in poly:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(pt) > 0.6:
			cleaned.append(pt)
	if cleaned.size() >= 2 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) <= 0.6:
		cleaned.remove_at(cleaned.size() - 1)
	return cleaned


func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var acc := Vector2.ZERO
	for pt in poly:
		acc += pt
	return acc / float(poly.size())


func _extract_rect(d: Dictionary, fallback: Rect2) -> Rect2:
	if d.get("rect") is Rect2:
		return d["rect"]
	if d.get("pos") is Vector2 and d.get("size") is Vector2:
		return Rect2(d["pos"], d["size"])
	if d.has("x") and d.has("y"):
		return Rect2(
			float(d.get("x", 0.0)),
			float(d.get("y", 0.0)),
			float(d.get("w", d.get("width", 0.0))),
			float(d.get("h", d.get("height", 0.0)))
		)
	return fallback


func _resolve_room_color(room_name: String, raw_col: Variant) -> Color:
	if raw_col is Color:
		return raw_col
	if raw_col is String and not (raw_col as String).is_empty():
		return Color.from_string(raw_col, COL_FLOOR_BASE)
	var low: String = room_name.to_lower()
	if low.find("kitchen") >= 0:
		return Color("#eadbc0")
	if low.find("bath") >= 0:
		return Color("#cde0dc")
	if low.find("living") >= 0:
		return Color("#dfc69e")
	if low.find("master") >= 0 or low.find("bed") >= 0:
		return Color("#d9ccb8")
	if low.find("garage") >= 0 or low.find("study") >= 0:
		return Color("#c2c0b6")
	return Color("#dfd0b2")


func _resolve_furniture_color(kind: String, raw_col: Variant) -> Color:
	if raw_col is Color:
		return raw_col
	if raw_col is String and not (raw_col as String).is_empty():
		return Color.from_string(raw_col, Color("#8c5c38"))
	if kind.find("bed") >= 0:
		return Color("#b56345")
	if kind.find("sofa") >= 0 or kind.find("couch") >= 0:
		return Color("#5b7a62")
	if kind.find("fridge") >= 0 or kind.find("stove") >= 0 or kind.find("sink") >= 0 or kind.find("tub") >= 0 or kind.find("toilet") >= 0:
		return Color("#dfe4e0")
	if kind.find("counter") >= 0:
		return Color("#c9b591")
	if kind.find("rug") >= 0:
		return Color("#a84d38")
	return Color("#8b5a34")


static func _draw_text_centered(canvas: CanvasItem, font: Font, center: Vector2, text: String, fsize: int, col: Color) -> void:
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var draw_p := Vector2(center.x - sz.x * 0.5, center.y + sz.y * 0.32)
	canvas.draw_string(font, draw_p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


static func _draw_text_centered_outlined(canvas: CanvasItem, font: Font, center: Vector2, text: String, fsize: int, col: Color, outline_col: Color) -> void:
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var draw_p := Vector2(center.x - sz.x * 0.5, center.y + sz.y * 0.32)
	canvas.draw_string_outline(font, draw_p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 3, outline_col)
	canvas.draw_string(font, draw_p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


static func _draw_badge_pill(canvas: CanvasItem, font: Font, center: Vector2, text: String, fsize: int, bg_col: Color, fg_col: Color) -> void:
	var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var pad := Vector2(10.0, 5.0)
	var rect := Rect2(center.x - sz.x * 0.5 - pad.x, center.y - sz.y * 0.5 - pad.y * 0.5, sz.x + pad.x * 2.0, sz.y + pad.y)
	canvas.draw_rect(rect, bg_col, true)
	canvas.draw_rect(rect, fg_col, false, 1.5)
	var draw_p := Vector2(center.x - sz.x * 0.5, rect.position.y + rect.size.y * 0.72)
	canvas.draw_string(font, draw_p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, fg_col)


# ==============================================================================
# FLOATING 3D->2D CALLOUTS + 1280x720 CIVIL DEFENSE CONELRAD HUD (_ScavengeHUD)
# ==============================================================================

class _ScavengeHUD extends Control:
	var scene_ref: ScavengeScene = null
	var _skip_btn: Button = null
	var _dive_btn: Button = null
	var _auto_btn: Button = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_skip_btn = Button.new()
		_skip_btn.text = "SKIP RECON — SOUND SIREN [TAB]"
		_skip_btn.position = Vector2(495.0, 582.0)
		_skip_btn.size = Vector2(290.0, 34.0)
		_skip_btn.focus_mode = Control.FOCUS_NONE
		_style_hud_button(_skip_btn, ScavengeScene.COL_HAZARD_YELLOW, ScavengeScene.COL_INK)
		_skip_btn.pressed.connect(_on_skip_pressed)
		add_child(_skip_btn)

		_dive_btn = Button.new()
		_dive_btn.text = "[ DIVE INTO BUNKER NOW (F) ]"
		_dive_btn.position = Vector2(485.0, 580.0)
		_dive_btn.size = Vector2(310.0, 36.0)
		_dive_btn.focus_mode = Control.FOCUS_NONE
		_style_hud_button(_dive_btn, ScavengeScene.COL_ATOMIC_ORANGE, ScavengeScene.COL_PARCHMENT)
		_dive_btn.pressed.connect(_on_dive_pressed)
		_dive_btn.visible = false
		add_child(_dive_btn)

		_auto_btn = Button.new()
		_auto_btn.text = "Auto-Grab: OFF [G]"
		_auto_btn.position = Vector2(262.0, 650.0)
		_auto_btn.size = Vector2(140.0, 26.0)
		_auto_btn.focus_mode = Control.FOCUS_NONE
		_style_hud_button(_auto_btn, ScavengeScene.COL_SLATE, ScavengeScene.COL_PARCHMENT)
		_auto_btn.pressed.connect(_on_auto_pressed)
		add_child(_auto_btn)

	func _style_hud_button(btn: Button, bg: Color, fg: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = ScavengeScene.COL_INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		var sb_hover: StyleBoxFlat = sb.duplicate()
		sb_hover.bg_color = bg.lightened(0.14)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)
		btn.add_theme_color_override("font_color", fg)
		btn.add_theme_color_override("font_hover_color", fg)
		btn.add_theme_color_override("font_pressed_color", fg)
		btn.add_theme_font_size_override("font_size", 12)

	func _on_skip_pressed() -> void:
		if is_instance_valid(scene_ref):
			scene_ref.trigger_hud_skip_scout()

	func _on_dive_pressed() -> void:
		if is_instance_valid(scene_ref):
			scene_ref.trigger_hud_dive_in()

	func _on_auto_pressed() -> void:
		if is_instance_valid(scene_ref):
			scene_ref._toggle_auto_pickup()

	func sync_state() -> void:
		if not is_instance_valid(scene_ref):
			return
		var in_outro: bool = (scene_ref._phase == ScavengeScene.Phase.OUTRO)
		_skip_btn.visible = (scene_ref._phase == ScavengeScene.Phase.SCOUT and not GameState.demo_mode and not in_outro)
		_dive_btn.visible = (not in_outro and not GameState.demo_mode and scene_ref._can_dive_into_bunker())
		_auto_btn.visible = not in_outro
		_auto_btn.text = "Auto-Grab: ON [G]" if scene_ref._auto_pickup else "Auto-Grab: OFF [G]"

	func _draw() -> void:
		if not is_instance_valid(scene_ref):
			return
		var font: Font = ThemeDB.fallback_font

		if scene_ref._phase != ScavengeScene.Phase.OUTRO and not scene_ref._is_headless:
			_draw_projected_3d_callouts(font)

		# Urgent final-15s Civil Defense red siren vignette
		if scene_ref._phase == ScavengeScene.Phase.SCAVENGE and scene_ref._scavenge_time_left <= 15.0:
			var klaxon: float = 0.5 + 0.5 * sin(scene_ref._anim_time * 9.5)
			var edge_col := Color(0.86, 0.16, 0.08, 0.06 + 0.13 * klaxon)
			draw_rect(Rect2(0.0, 0.0, 1280.0, 26.0), edge_col, true)
			draw_rect(Rect2(0.0, 694.0, 1280.0, 26.0), edge_col, true)
			draw_rect(Rect2(0.0, 26.0, 26.0, 668.0), edge_col, true)
			draw_rect(Rect2(1254.0, 26.0, 26.0, 668.0), edge_col, true)

		_draw_minimap_panel(font)
		_draw_stopwatch_and_banner(font)
		_draw_chute_tally_panel(font)
		_draw_carry_capacity_bar(font)
		_draw_controls_and_compass(font)

		if scene_ref._phase == ScavengeScene.Phase.OUTRO:
			_draw_outro_transition_overlay(font)

	func _draw_projected_3d_callouts(font: Font) -> void:
		if not is_instance_valid(scene_ref._camera_3d):
			return

		# 1. Tactical Demo Path or Click-to-Run Reticle projected onto 3D floor
		if GameState.demo_mode and not GameState.promo_video_mode and scene_ref._phase == ScavengeScene.Phase.SCAVENGE and scene_ref._ai_waypoints.size() > 0:
			var prev_scr: Vector2 = scene_ref.project_2d_to_screen(scene_ref._player_pos, 0.08)
			for wi in range(scene_ref._ai_wp_index, mini(scene_ref._ai_waypoints.size(), scene_ref._ai_wp_index + 8)):
				var wp_scr: Vector2 = scene_ref.project_2d_to_screen(scene_ref._ai_waypoints[wi], 0.08)
				if prev_scr.x > -9000.0 and wp_scr.x > -9000.0:
					draw_line(prev_scr, wp_scr, Color(ScavengeScene.COL_HAZARD_YELLOW.r, ScavengeScene.COL_HAZARD_YELLOW.g, ScavengeScene.COL_HAZARD_YELLOW.b, 0.36), 2.2)
				prev_scr = wp_scr
		elif scene_ref._has_click_target and not GameState.demo_mode:
			var click_scr: Vector2 = scene_ref.project_2d_to_screen(scene_ref._click_target_pos, 0.08)
			if click_scr.x > -9000.0:
				var r_pulse: float = 9.0 + 2.5 * sin(scene_ref._anim_time * 8.0)
				draw_arc(click_scr, r_pulse, 0.0, TAU, 20, ScavengeScene.COL_HAZARD_YELLOW, 2.0, true)

		# 2. Subtle Architectural Room Labels on 3D floors (de-collided against items & family!)
		var occupied_scr_pts: Array[Vector2] = []
		for it_occ_var in scene_ref._world_items:
			var it_occ: Dictionary = it_occ_var
			if bool(it_occ.get("collected", false)):
				continue
			var ipos_occ: Vector2 = it_occ["pos"]
			var s_flr: Vector2 = scene_ref.project_2d_to_screen(ipos_occ, 0.08)
			var s_bdg: Vector2 = scene_ref.project_2d_to_screen(ipos_occ, 0.90)
			if s_flr.x > -9000.0:
				occupied_scr_pts.append(s_flr)
			if s_bdg.x > -9000.0:
				occupied_scr_pts.append(s_bdg)
		for f_occ_var in scene_ref._world_family:
			var fam_occ: Dictionary = f_occ_var
			if bool(fam_occ.get("collected", false)):
				continue
			var fpos_occ: Vector2 = fam_occ["pos"]
			var sf_flr: Vector2 = scene_ref.project_2d_to_screen(fpos_occ, 0.08)
			var sf_bdg: Vector2 = scene_ref.project_2d_to_screen(fpos_occ, 1.38)
			if sf_flr.x > -9000.0:
				occupied_scr_pts.append(sf_flr)
			if sf_bdg.x > -9000.0:
				occupied_scr_pts.append(sf_bdg)
		var hatch_occ_scr: Vector2 = scene_ref.project_2d_to_screen(
			scene_ref._hatch_pos + Vector2(0.0, scene_ref._hatch_radius * 0.72), 0.16
		)
		if hatch_occ_scr.x > -9000.0:
			occupied_scr_pts.append(hatch_occ_scr)

		var cand_offsets: Array[Vector2] = [
			Vector2(0.0, -28.0),
			Vector2(0.0, 28.0),
			Vector2(-36.0, 0.0),
			Vector2(36.0, 0.0)
		]
		for r_var in scene_ref._rooms:
			var rm: Dictionary = r_var
			var r_title: String = str(rm.get("name", "")).to_upper()
			if r_title.is_empty():
				continue
			var cpos: Vector2 = rm["center"]
			if cpos.distance_to(scene_ref._hatch_pos) < scene_ref._hatch_radius + 30.0:
				cpos += Vector2(0.0, scene_ref._hatch_radius + 32.0)
			var base_scr: Vector2 = scene_ref.project_2d_to_screen(cpos, 0.06)
			if base_scr.x <= -9000.0:
				continue
			var r_scr: Vector2 = base_scr
			var min_d_sq: float = 99999999.0
			for occ_p in occupied_scr_pts:
				var d_sq: float = r_scr.distance_squared_to(occ_p)
				if d_sq < min_d_sq:
					min_d_sq = d_sq
			if min_d_sq < 36.0 * 36.0:
				var best_scr: Vector2 = r_scr
				var best_d_sq: float = min_d_sq
				var rm_rect: Rect2 = rm.get("rect", Rect2()) if rm.get("rect") is Rect2 else Rect2()
				for off in cand_offsets:
					var cand_scr: Vector2 = base_scr + off
					if cand_scr.x <= 40.0 or cand_scr.x >= 1240.0 or cand_scr.y <= 105.0 or cand_scr.y >= 615.0:
						continue
					if rm_rect.size.x > 24.0 and rm_rect.size.y > 24.0:
						var cand_flr_2d: Vector2 = scene_ref._screen_to_floor_2d(cand_scr)
						if not rm_rect.grow(-8.0).has_point(cand_flr_2d):
							continue
					var cand_min_sq: float = 99999999.0
					for occ_p2 in occupied_scr_pts:
						var d2: float = cand_scr.distance_squared_to(occ_p2)
						if d2 < cand_min_sq:
							cand_min_sq = d2
					if cand_min_sq >= 36.0 * 36.0:
						best_scr = cand_scr
						best_d_sq = cand_min_sq
						break
					elif cand_min_sq > best_d_sq:
						best_scr = cand_scr
						best_d_sq = cand_min_sq
				r_scr = best_scr

			if r_scr.x > 40.0 and r_scr.x < 1240.0 and r_scr.y > 105.0 and r_scr.y < 615.0:
				occupied_scr_pts.append(r_scr)
				var lbl_a: float = 0.72 if scene_ref._phase == ScavengeScene.Phase.SCOUT else 0.42
				ScavengeScene._draw_text_centered_outlined(
					self, font, r_scr, r_title, 11,
					Color(ScavengeScene.COL_PARCHMENT.r, ScavengeScene.COL_PARCHMENT.g, ScavengeScene.COL_PARCHMENT.b, lbl_a),
					Color(0.08, 0.08, 0.07, lbl_a * 0.85)
				)

		# 3. Dust puffs behind running leader
		for puff_var in scene_ref._dust_puffs:
			var puff: Dictionary = puff_var
			var p_scr: Vector2 = scene_ref.project_2d_to_screen(puff["pos"], 0.12)
			if p_scr.x > -9000.0:
				var ratio: float = clampf(float(puff["life"]) / float(puff["max_life"]), 0.0, 1.0)
				draw_circle(p_scr, float(puff["radius"]) * (1.2 - 0.25 * ratio), Color(0.92, 0.86, 0.74, 0.34 * ratio))

		# 4. Crisp Floating 2D Item Icon Badges above 3D Supply Models (leaving 3D floor prop clearly visible!)
		var hovered_kind: String = str(scene_ref._hovered_target.get("kind", ""))
		var hovered_uid: int = int(scene_ref._hovered_target.get("uid", -1))
		var scout_label_pts: Array[Vector2] = []

		for it_var in scene_ref._world_items:
			var it: Dictionary = it_var
			if bool(it.get("collected", false)):
				continue
			var ipos: Vector2 = it["pos"]
			var uid: int = int(it["uid"])
			var is_hovered: bool = (hovered_kind == "item" and hovered_uid == uid)
			var bob_y: float = 0.90 + sin(scene_ref._anim_time * 3.4 + float(it["bob_phase"])) * 0.045
			var badge_p: Vector2 = scene_ref.project_2d_to_screen(ipos, bob_y)
			var prop_p: Vector2 = scene_ref.project_2d_to_screen(ipos, 0.34)
			if badge_p.x < -20.0 or badge_p.x > 1300.0 or badge_p.y < -20.0 or badge_p.y > 740.0:
				continue

			var slots: int = int(it["slots"])
			var icol: Color = it["color"]
			var rad: float = 15.5 if is_hovered else 11.4

			# Subtle pointer tether down to the 3D supply prop on the floor
			if prop_p.y > badge_p.y + rad + 2.0:
				draw_line(
					badge_p + Vector2(0.0, rad),
					Vector2(badge_p.x, minf(prop_p.y - 4.0, badge_p.y + rad + 10.0)),
					Color(0.11, 0.10, 0.09, 0.55),
					1.4
				)
			draw_circle(badge_p + Vector2(1.2, 1.8), rad, Color(0.05, 0.05, 0.04, 0.38))
			draw_circle(badge_p, rad, ScavengeScene.COL_PARCHMENT)
			var rim_c: Color = ScavengeScene.COL_HAZARD_YELLOW if is_hovered else (icol if slots == 2 else ScavengeScene.COL_INK)
			draw_arc(badge_p, rad, 0.0, TAU, 22, rim_c, 2.5 if is_hovered else 1.6, true)

			ItemDB.draw_item_icon(self, str(it["item_id"]), badge_p, 22.0 if is_hovered else 16.8, false)

			if slots == 2:
				var tag_2s: Vector2 = badge_p + Vector2(rad * 0.76, -rad * 0.70)
				draw_circle(tag_2s, 5.8, ScavengeScene.COL_HAZARD_YELLOW)
				draw_arc(tag_2s, 5.8, 0.0, TAU, 14, ScavengeScene.COL_INK, 1.2)
				ScavengeScene._draw_text_centered(self, font, tag_2s, "2", 8, ScavengeScene.COL_INK)

			if scene_ref._phase == ScavengeScene.Phase.SCOUT and not is_hovered:
				var lbl_pt: Vector2 = badge_p + Vector2(0.0, -rad - 8.0)
				var crowded: bool = false
				for prev_lp in scout_label_pts:
					if absf(prev_lp.x - lbl_pt.x) < 42.0 and absf(prev_lp.y - lbl_pt.y) < 15.0:
						crowded = true
						break
				if not crowded:
					scout_label_pts.append(lbl_pt)
					ScavengeScene._draw_text_centered_outlined(
						self, font, lbl_pt,
						str(it["short_name"]), 10, ScavengeScene.COL_PARCHMENT, ScavengeScene.COL_INK
					)

		# 5. Bunker Hatch Status Callout Badge (drawn above floor tokens so it is never obscured)
		var hatch_scr: Vector2 = scene_ref.project_2d_to_screen(
			scene_ref._hatch_pos + Vector2(0.0, scene_ref._hatch_radius * 0.72), 0.16
		)
		if hatch_scr.x > -9000.0:
			var urgent_h: bool = (scene_ref._phase == ScavengeScene.Phase.SCAVENGE and scene_ref._scavenge_time_left <= 15.0)
			var h_col: Color = ScavengeScene.COL_ALERT_RED if urgent_h else (ScavengeScene.COL_TOXIC_GREEN if not scene_ref._carried_entries.is_empty() else ScavengeScene.COL_HAZARD_YELLOW)
			var hatch_tag: String = "BUNKER HATCH"
			if not scene_ref._carried_entries.is_empty():
				hatch_tag = "STEP HERE TO DROP LOOT!"
			elif scene_ref._can_dive_into_bunker() and scene_ref._scavenge_time_left <= 20.0:
				hatch_tag = "PRESS [F] — DIVE IN!"
			ScavengeScene._draw_badge_pill(self, font, hatch_scr, hatch_tag, 11, ScavengeScene.COL_SLATE_DARK, h_col)

		# 6. Floating Family Member Rescue Name & Slot Tags
		for f_var in scene_ref._world_family:
			var fam: Dictionary = f_var
			if bool(fam.get("collected", false)):
				continue
			var fuid: int = int(fam["uid"])
			var is_hov_f: bool = (hovered_kind == "family" and hovered_uid == fuid)
			if is_hov_f:
				continue
			var m_d: Dictionary = fam["member"]
			var age_f: int = int(m_d.get("age", 30))
			var h_sc: float = 0.72 if age_f <= 12 else (0.88 if age_f <= 17 else 1.0)
			var f_scr: Vector2 = scene_ref.project_2d_to_screen(fam["pos"], 1.56 * h_sc)
			if f_scr.x > -9000.0:
				var ftag: String = "%s [%d]" % [str(fam["name"]), int(fam["slots"])]
				ScavengeScene._draw_badge_pill(self, font, f_scr, ftag, 11, ScavengeScene.COL_SLATE_DARK, ScavengeScene.COL_HAZARD_YELLOW)

		# 7. Player Overhead Carry Slot Indicator
		var used_slots: int = scene_ref._get_used_slots()
		if used_slots > 0:
			var carry_h: float = 2.12 + float(scene_ref._carried_entries.size()) * 0.28
			var p_scr_top: Vector2 = scene_ref.project_2d_to_screen(scene_ref._player_pos, carry_h)
			if p_scr_top.x > -9000.0:
				var carry_tag: String = "%d/%d" % [used_slots, scene_ref._max_slots]
				var tag_col: Color = ScavengeScene.COL_ATOMIC_ORANGE if used_slots >= scene_ref._max_slots else ScavengeScene.COL_PARCHMENT
				ScavengeScene._draw_badge_pill(self, font, p_scr_top, carry_tag, 11, ScavengeScene.COL_SLATE_DARK, tag_col)

		# 8. Nearest-Pickup Highlight Prompt Callout
		if not scene_ref._hovered_target.is_empty():
			var hpos: Vector2 = scene_ref._hovered_target["pos"]
			var hkind: String = str(scene_ref._hovered_target.get("kind", "item"))
			var hslots: int = int(scene_ref._hovered_target.get("slots", 1))
			var fits: bool = (used_slots + hslots <= scene_ref._max_slots)
			var label_str: String = str(scene_ref._hovered_target.get("label", "Item"))
			if scene_ref._phase == ScavengeScene.Phase.SCAVENGE:
				label_str = ("[E] " + label_str) if fits else ("FULL! " + label_str)
			var pill_fg: Color = ScavengeScene.COL_HAZARD_YELLOW if fits else ScavengeScene.COL_ATOMIC_ORANGE
			var prompt_y: float = 1.62 if hkind == "family" else 1.22
			var prompt_scr: Vector2 = scene_ref.project_2d_to_screen(hpos, prompt_y)
			if prompt_scr.x > -9000.0:
				ScavengeScene._draw_badge_pill(self, font, prompt_scr, label_str, 12, ScavengeScene.COL_INK, pill_fg)

		# 9. Floating World Popups (+SOUP, HANDS FULL, SAFE IN BUNKER)
		for pop_var in scene_ref._floating_popups:
			var pop: Dictionary = pop_var
			var prog_p: float = clampf(float(pop["t"]) / maxf(0.01, float(pop["dur"])), 0.0, 1.0)
			var alpha: float = clampf(1.0 - prog_p, 0.0, 1.0)
			var pop_scr: Vector2 = scene_ref.project_2d_to_screen(pop["pos"], 1.15 + prog_p * 0.55)
			if pop_scr.x > -9000.0:
				var col: Color = pop["color"]
				col.a = alpha
				var out_col := Color(ScavengeScene.COL_INK.r, ScavengeScene.COL_INK.g, ScavengeScene.COL_INK.b, alpha)
				ScavengeScene._draw_text_centered_outlined(self, font, pop_scr, str(pop["text"]), 14, col, out_col)

	func _draw_minimap_panel(font: Font) -> void:
		var panel_r := Rect2(14.0, 12.0, 224.0, 154.0)
		draw_rect(Rect2(panel_r.position + Vector2(3.0, 4.0), panel_r.size), Color(0.0, 0.0, 0.0, 0.45), true)
		draw_rect(panel_r, Color(0.11, 0.14, 0.12, 0.93), true)
		draw_rect(Rect2(panel_r.position.x, panel_r.position.y, panel_r.size.x, 22.0), ScavengeScene.COL_SLATE, true)
		draw_rect(panel_r, ScavengeScene.COL_HAZARD_YELLOW, false, 2.0)

		var radar_hdr: String = "OSM 3D DRILL RADAR" if GameState.game_mode == "scavenge_drill" else "OSM HOUSE RADAR"
		draw_string(font, panel_r.position + Vector2(8.0, 16.0), radar_hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_HAZARD_YELLOW)
		draw_circle(panel_r.position + Vector2(panel_r.size.x - 12.0, 11.0), 4.0, ScavengeScene.COL_TOXIC_GREEN)

		var map_area := Rect2(panel_r.position.x + 10.0, panel_r.position.y + 28.0, panel_r.size.x - 20.0, panel_r.size.y - 46.0)
		var hb: Rect2 = scene_ref._house_bounds
		var scale_f: float = minf(map_area.size.x / maxf(1.0, hb.size.x), map_area.size.y / maxf(1.0, hb.size.y)) * 0.92
		var map_center: Vector2 = map_area.get_center()
		var world_center: Vector2 = hb.get_center()

		if scene_ref._outer_polygon.size() >= 3:
			var mini_poly := PackedVector2Array()
			for pt in scene_ref._outer_polygon:
				mini_poly.append(map_center + (pt - world_center) * scale_f)
			if scene_ref._outer_poly_valid:
				draw_colored_polygon(mini_poly, Color("#263029"))
			mini_poly.append(mini_poly[0])
			draw_polyline(mini_poly, ScavengeScene.COL_HAZARD_YELLOW, 1.5, true)

		for r_var in scene_ref._rooms:
			var rm: Dictionary = r_var
			var rr: Rect2 = rm["rect"]
			if rr.size.x > 1.0 and rr.size.y > 1.0:
				var mr := Rect2(map_center + (rr.position - world_center) * scale_f, rr.size * scale_f)
				draw_rect(mr, Color(0.55, 0.62, 0.55, 0.35), false, 1.0)
			var rc: Vector2 = map_center + ((rm["center"] as Vector2) - world_center) * scale_f
			var short_lbl: String = str(rm.get("name", "")).substr(0, 3).to_upper()
			ScavengeScene._draw_text_centered(self, font, rc, short_lbl, 8, Color(0.85, 0.84, 0.75, 0.55))

		for it_var in scene_ref._world_items:
			var it: Dictionary = it_var
			if bool(it.get("collected", false)):
				continue
			var mp: Vector2 = map_center + ((it["pos"] as Vector2) - world_center) * scale_f
			var iid: String = str(it["item_id"])
			var dot_c: Color = ScavengeScene.COL_PARCHMENT
			if iid == "soup":
				dot_c = ScavengeScene.COL_ATOMIC_ORANGE
			elif iid == "water":
				dot_c = ScavengeScene.COL_WATER_BLUE
			elif iid == "suitcase":
				dot_c = ScavengeScene.COL_HAZARD_YELLOW
			draw_circle(mp, 2.3, dot_c)

		for f_var in scene_ref._world_family:
			var fam: Dictionary = f_var
			if bool(fam.get("collected", false)):
				continue
			var fp: Vector2 = map_center + ((fam["pos"] as Vector2) - world_center) * scale_f
			draw_circle(fp, 4.0, Color("#ff6670"))
			draw_arc(fp, 5.5, 0.0, TAU, 12, ScavengeScene.COL_HAZARD_YELLOW, 1.2)

		var hp_mini: Vector2 = map_center + (scene_ref._hatch_pos - world_center) * scale_f
		draw_circle(hp_mini, 4.5, ScavengeScene.COL_HAZARD_YELLOW)
		draw_circle(hp_mini, 2.2, ScavengeScene.COL_INK)

		var pp_mini: Vector2 = map_center + (scene_ref._player_pos - world_center) * scale_f
		draw_line(pp_mini, pp_mini + scene_ref._player_facing * 7.5, ScavengeScene.COL_TOXIC_GREEN, 2.0)
		draw_circle(pp_mini, 3.6, Color.WHITE)
		draw_arc(pp_mini, 3.6, 0.0, TAU, 12, ScavengeScene.COL_INK, 1.2)

		var addr: String = str(GameState.selected_house.get("name", "Selected OSM House"))
		if addr.length() > 28:
			addr = addr.substr(0, 26) + ".."
		draw_string(font, Vector2(panel_r.position.x + 8.0, panel_r.end.y - 5.0), addr, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ScavengeScene.COL_PARCHMENT_DARK)

	func _draw_stopwatch_and_banner(font: Font) -> void:
		var is_scout: bool = (scene_ref._phase == ScavengeScene.Phase.SCOUT)
		var t_left: float = scene_ref._scout_time_left if is_scout else scene_ref._scavenge_time_left
		var urgent: bool = (not is_scout and t_left <= 15.0)

		var jitter := Vector2.ZERO
		if urgent and t_left > 0.0 and fmod(t_left, 1.0) > 0.86:
			jitter = Vector2(sin(scene_ref._anim_time * 55.0) * 2.5, cos(scene_ref._anim_time * 48.0) * 2.0)

		var plaque := Rect2(506.0, 14.0, 482.0, 84.0)
		draw_rect(Rect2(plaque.position + Vector2(3.0, 4.0), plaque.size), Color(0.0, 0.0, 0.0, 0.45), true)
		draw_rect(plaque, ScavengeScene.COL_SLATE_DARK, true)
		var border_c: Color = ScavengeScene.COL_HAZARD_YELLOW if is_scout else (ScavengeScene.COL_ALERT_RED if urgent else ScavengeScene.COL_ATOMIC_ORANGE)
		draw_rect(plaque, border_c, false, 2.5)

		# Analog Civil Defense Stopwatch
		var sw_c: Vector2 = Vector2(462.0, 58.0) + jitter
		var sw_r: float = 43.0
		draw_rect(Rect2(sw_c.x - 5.0, sw_c.y - sw_r - 9.0, 10.0, 9.0), Color("#c6a664"), true)
		draw_rect(Rect2(sw_c.x - 8.0, sw_c.y - sw_r - 13.0, 16.0, 5.0), Color("#dfc282"), true)
		draw_arc(sw_c + Vector2(0.0, -sw_r - 14.0), 6.0, PI, TAU, 12, Color("#c6a664"), 2.2)
		var side_p: Vector2 = sw_c + Vector2(cos(-0.85), sin(-0.85)) * (sw_r + 4.0)
		draw_circle(side_p, 4.5, ScavengeScene.COL_ALERT_RED)

		draw_circle(sw_c + Vector2(3.0, 4.0), sw_r + 4.0, Color(0.0, 0.0, 0.0, 0.5))
		draw_circle(sw_c, sw_r + 4.0, Color("#b99858"))
		draw_arc(sw_c, sw_r + 4.0, 0.0, TAU, 44, ScavengeScene.COL_INK, 2.5, true)
		draw_circle(sw_c, sw_r - 1.0, ScavengeScene.COL_PARCHMENT)

		var wedge_pts := PackedVector2Array([sw_c])
		var w_steps: int = 16
		for wi in range(w_steps + 1):
			var wa: float = -PI + (PI * 0.5) * (float(wi) / float(w_steps))
			wedge_pts.append(sw_c + Vector2(cos(wa), sin(wa)) * (sw_r - 3.0))
		var danger_a: float = 0.52 if (urgent and sin(scene_ref._anim_time * 12.0) > 0.0) else 0.28
		draw_colored_polygon(wedge_pts, Color(ScavengeScene.COL_ALERT_RED.r, ScavengeScene.COL_ALERT_RED.g, ScavengeScene.COL_ALERT_RED.b, danger_a))

		for ti in range(60):
			var ta: float = -PI * 0.5 + (float(ti) / 60.0) * TAU
			var dir := Vector2(cos(ta), sin(ta))
			var major: bool = (ti % 5 == 0)
			var inner_r: float = (sw_r - 9.5) if major else (sw_r - 5.5)
			var t_col: Color = ScavengeScene.COL_ALERT_RED if ti >= 45 else ScavengeScene.COL_INK
			draw_line(sw_c + dir * inner_r, sw_c + dir * (sw_r - 2.0), t_col, 2.0 if major else 1.0)

		var top_num: String = str(int(round(scene_ref._scavenge_total)))
		ScavengeScene._draw_text_centered(self, font, sw_c + Vector2(0.0, -sw_r + 16.0), top_num, 10, ScavengeScene.COL_INK)
		ScavengeScene._draw_text_centered(self, font, sw_c + Vector2(sw_r - 15.0, 0.0), "15", 10, ScavengeScene.COL_INK)
		ScavengeScene._draw_text_centered(self, font, sw_c + Vector2(0.0, sw_r - 15.0), "30", 10, ScavengeScene.COL_INK)
		ScavengeScene._draw_text_centered(self, font, sw_c + Vector2(-sw_r + 15.0, 0.0), "45", 10, ScavengeScene.COL_ALERT_RED)
		ScavengeScene._draw_text_centered(self, font, sw_c + Vector2(0.0, 11.0), "CONELRAD", 7, Color(0.2, 0.18, 0.15, 0.75))

		var hand_frac: float = 0.0
		if is_scout:
			hand_frac = 1.0 - (scene_ref._scout_time_left / maxf(0.1, scene_ref._scout_total))
		else:
			hand_frac = 1.0 - (scene_ref._scavenge_time_left / maxf(1.0, scene_ref._scavenge_total))
		var hand_ang: float = -PI * 0.5 + clampf(hand_frac, 0.0, 1.0) * TAU
		var hand_dir := Vector2(cos(hand_ang), sin(hand_ang))
		var needle_c: Color = ScavengeScene.COL_HAZARD_GOLD if is_scout else ScavengeScene.COL_ALERT_RED
		draw_line(sw_c - hand_dir * 9.0, sw_c + hand_dir * (sw_r - 6.0), ScavengeScene.COL_INK, 4.0)
		draw_line(sw_c - hand_dir * 9.0, sw_c + hand_dir * (sw_r - 6.0), needle_c, 2.2)
		draw_circle(sw_c, 4.5, ScavengeScene.COL_INK)
		draw_circle(sw_c, 2.4, ScavengeScene.COL_HAZARD_YELLOW)
		draw_arc(sw_c, sw_r - 1.0, 0.0, TAU, 44, ScavengeScene.COL_INK, 2.2, true)

		var digital_str: String = ("RECON %04.1fs" % t_left) if is_scout else ("%04.1f SEC" % t_left)
		var dig_col: Color = ScavengeScene.COL_HAZARD_YELLOW if is_scout else (ScavengeScene.COL_ALERT_RED if (urgent and sin(scene_ref._anim_time * 14.0) > 0.0) else ScavengeScene.COL_PARCHMENT)
		draw_string(font, Vector2(522.0, 46.0), digital_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, dig_col)

		var leader_name: String = str(scene_ref._leader_member.get("name", "Leader")).to_upper()
		var leader_trait: String = str(scene_ref._leader_member.get("trait", "")).to_upper()
		var leader_lbl: String = ("LEADER: %s (%s)" % [leader_name, leader_trait]) if not leader_trait.is_empty() else ("LEADER: %s" % leader_name)
		var show_demo_lbl: bool = GameState.demo_mode and not GameState.promo_video_mode
		var right_tag: String = "AUTO-PILOT DEMO" if show_demo_lbl else leader_lbl
		var tag_c: Color = ScavengeScene.COL_TOXIC_GREEN if show_demo_lbl else ScavengeScene.COL_PARCHMENT_DARK
		draw_string(font, Vector2(734.0, 42.0), right_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tag_c)

		var banner_r := Rect2(516.0, 56.0, 462.0, 34.0)
		var banner_bg: Color = ScavengeScene.COL_HAZARD_YELLOW if is_scout else (ScavengeScene.COL_ALERT_RED if urgent else ScavengeScene.COL_ATOMIC_ORANGE)
		var banner_fg: Color = ScavengeScene.COL_INK if is_scout else ScavengeScene.COL_PARCHMENT
		var banner_txt: String = "3D RECON — MEMORIZE YOUR HOUSE! [TAB to Skip]"
		if not is_scout:
			if urgent:
				banner_txt = "IMPENDING IMPACT! GET TO THE HATCH!"
			elif GameState.game_mode == "scavenge_drill":
				banner_txt = "CIVIL DEFENSE DRILL! MAXIMIZE CHUTE SCORE!"
			else:
				banner_txt = "CONELRAD ALERT! GRAB SUPPLIES & FAMILY!"

		draw_rect(banner_r, banner_bg, true)
		draw_rect(banner_r, ScavengeScene.COL_INK, false, 1.5)
		ScavengeScene._draw_text_centered(self, font, banner_r.get_center(), banner_txt, 13, banner_fg)

	func _draw_chute_tally_panel(font: Font) -> void:
		var pop: float = sin((scene_ref._tally_pop_timer / 0.5) * PI) * 3.0 if scene_ref._tally_pop_timer > 0.0 else 0.0
		var pr := Rect2(1010.0 - pop, 12.0 - pop * 0.5, 256.0 + pop * 2.0, 152.0 + pop)
		draw_rect(Rect2(pr.position + Vector2(3.0, 4.0), pr.size), Color(0.0, 0.0, 0.0, 0.45), true)
		draw_rect(pr, Color(0.14, 0.16, 0.14, 0.94), true)
		draw_rect(Rect2(pr.position.x, pr.position.y, pr.size.x, 24.0), ScavengeScene.COL_HAZARD_YELLOW, true)
		draw_rect(pr, ScavengeScene.COL_INK, false, 2.2)

		ScavengeScene._draw_text_centered(self, font, Vector2(pr.get_center().x, pr.position.y + 12.0), "BUNKER CHUTE TALLY", 12, ScavengeScene.COL_INK)

		var soup_cans: int = GameState.soup_quarters / 4
		var water_btls: int = GameState.water_quarters / 4
		var row1_y: float = pr.position.y + 44.0
		ItemDB.draw_item_icon(self, "soup", Vector2(pr.position.x + 22.0, row1_y), 24.0, false)
		draw_string(font, Vector2(pr.position.x + 38.0, row1_y + 5.0), "Soup: %d" % soup_cans, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ScavengeScene.COL_PARCHMENT)

		ItemDB.draw_item_icon(self, "water", Vector2(pr.position.x + 140.0, row1_y), 24.0, false)
		draw_string(font, Vector2(pr.position.x + 156.0, row1_y + 5.0), "Water: %d" % water_btls, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ScavengeScene.COL_PARCHMENT)

		var row2_y: float = pr.position.y + 76.0
		ItemDB.draw_item_icon(self, "toolbox", Vector2(pr.position.x + 22.0, row2_y), 22.0, false)
		draw_string(font, Vector2(pr.position.x + 38.0, row2_y + 5.0), "Gear: %d" % scene_ref._gear_deposited_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ScavengeScene.COL_PARCHMENT)

		var gx: float = pr.position.x + 122.0
		var shown: int = 0
		for gid in scene_ref._secured_gear_order:
			if shown >= 5:
				break
			draw_circle(Vector2(gx, row2_y), 11.0, ScavengeScene.COL_PARCHMENT)
			draw_arc(Vector2(gx, row2_y), 11.0, 0.0, TAU, 16, ScavengeScene.COL_INK, 1.2)
			ItemDB.draw_item_icon(self, gid, Vector2(gx, row2_y), 17.0, false)
			gx += 25.0
			shown += 1

		var row3_y: float = pr.position.y + 105.0
		var fam_saved: int = scene_ref._family_deposited_count
		var fam_tot: int = scene_ref._non_leader_total
		var fam_col: Color = ScavengeScene.COL_TOXIC_GREEN if (fam_saved >= fam_tot) else ScavengeScene.COL_HAZARD_YELLOW
		draw_string(font, Vector2(pr.position.x + 12.0, row3_y), "Family Rescued: %d / %d" % [fam_saved, fam_tot], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, fam_col)

		var px: float = pr.position.x + 12.0
		var py: float = pr.position.y + 112.0
		for raw_m in GameState.family_members:
			var m: Dictionary = raw_m
			var p_rect := Rect2(px, py, 32.0, 32.0)
			var in_bunk: bool = bool(m.get("in_bunker", false))
			var is_ldr: bool = bool(m.get("is_leader", false))
			CharacterArtist.draw_portrait(self, p_rect, m, true)
			if in_bunk:
				draw_rect(p_rect, ScavengeScene.COL_TOXIC_GREEN, false, 2.2)
				draw_circle(p_rect.end - Vector2(5.0, 5.0), 5.5, ScavengeScene.COL_TOXIC_GREEN)
				ScavengeScene._draw_text_centered(self, font, p_rect.end - Vector2(5.0, 5.0), "V", 8, ScavengeScene.COL_INK)
			elif is_ldr:
				draw_rect(p_rect, ScavengeScene.COL_HAZARD_YELLOW, false, 1.6)
			else:
				draw_rect(p_rect, Color(0.0, 0.0, 0.0, 0.42), true)
			px += 40.0

	func _draw_carry_capacity_bar(font: Font) -> void:
		var max_s: int = scene_ref._max_slots
		var used_s: int = scene_ref._get_used_slots()

		if scene_ref._suitcase_flash_timer > 0.0:
			ScavengeScene._draw_badge_pill(self, font, Vector2(640.0, 554.0), "+1 CARRY SLOT UNLOCKED (SUITCASE)!", 14, ScavengeScene.COL_INK, ScavengeScene.COL_HAZARD_YELLOW)
		elif scene_ref._hands_full_timer > 0.0:
			ScavengeScene._draw_badge_pill(self, font, Vector2(640.0, 554.0), "HANDS FULL! RUN TO HATCH!", 14, ScavengeScene.COL_INK, ScavengeScene.COL_ATOMIC_ORANGE)

		var cell_w: float = 82.0 if max_s == 4 else 74.0
		var cell_h: float = 56.0
		var gap: float = 8.0
		var total_w: float = float(max_s) * cell_w + float(max_s - 1) * gap
		var rack_rect := Rect2(640.0 - total_w * 0.5 - 14.0, 622.0, total_w + 28.0, 88.0)

		draw_rect(Rect2(rack_rect.position + Vector2(3.0, 4.0), rack_rect.size), Color(0.0, 0.0, 0.0, 0.48), true)
		draw_rect(rack_rect, Color(0.13, 0.15, 0.13, 0.95), true)
		var border_col: Color = ScavengeScene.COL_ATOMIC_ORANGE if used_s >= max_s else (ScavengeScene.COL_HAZARD_YELLOW if scene_ref._suitcase_upgraded else ScavengeScene.COL_PARCHMENT_DARK)
		draw_rect(rack_rect, border_col, false, 2.2)

		var hdr_text: String = "CARRY HANDS: %d / %d SLOTS" % [used_s, max_s]
		draw_string(font, Vector2(rack_rect.position.x + 12.0, rack_rect.position.y + 18.0), hdr_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ScavengeScene.COL_PARCHMENT)

		if scene_ref._suitcase_upgraded:
			var badge_r := Rect2(rack_rect.end.x - 134.0, rack_rect.position.y + 4.0, 124.0, 18.0)
			draw_rect(badge_r, ScavengeScene.COL_HAZARD_YELLOW, true)
			draw_rect(badge_r, ScavengeScene.COL_INK, false, 1.2)
			ScavengeScene._draw_text_centered(self, font, badge_r.get_center(), "SUITCASE +1 SLOT", 10, ScavengeScene.COL_INK)

		var slots_x0: float = 640.0 - total_w * 0.5
		var slots_y0: float = rack_rect.position.y + 24.0
		for si in range(max_s):
			var sr := Rect2(slots_x0 + float(si) * (cell_w + gap), slots_y0, cell_w, cell_h)
			var is_bonus: bool = (si == 4)
			draw_rect(sr, Color(0.2, 0.22, 0.19, 0.85), true)
			draw_rect(sr, ScavengeScene.COL_HAZARD_YELLOW if is_bonus else Color(0.45, 0.44, 0.38, 0.8), false, 1.5)
			ScavengeScene._draw_text_centered(self, font, sr.get_center(), "+1" if is_bonus else ("SLOT %d" % (si + 1)), 10, Color(0.65, 0.63, 0.56, 0.45))

		var cur_slot: int = 0
		for entry_var in scene_ref._carried_entries:
			var entry: Dictionary = entry_var
			var span: int = clampi(int(entry.get("slots", 1)), 1, max_s - cur_slot)
			var card_w: float = float(span) * cell_w + float(span - 1) * gap
			var card_r := Rect2(slots_x0 + float(cur_slot) * (cell_w + gap), slots_y0, card_w, cell_h)

			draw_rect(card_r, ScavengeScene.COL_PARCHMENT, true)
			draw_rect(card_r, ScavengeScene.COL_INK, false, 2.2)

			var kind: String = str(entry.get("kind", "item"))
			if kind == "family":
				var m: Dictionary = entry["member"]
				var port_r := Rect2(card_r.position.x + 6.0, card_r.position.y + 5.0, 46.0, 46.0)
				CharacterArtist.draw_portrait(self, port_r, m, true)
				draw_string(font, Vector2(port_r.end.x + 8.0, card_r.position.y + 24.0), str(entry.get("name", "Family")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ScavengeScene.COL_INK)
				draw_string(font, Vector2(port_r.end.x + 8.0, card_r.position.y + 43.0), "[%d SLOTS]" % span, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_ATOMIC_ORANGE)
			else:
				var iid: String = str(entry.get("item_id", "soup"))
				if span == 1:
					ItemDB.draw_item_icon(self, iid, card_r.position + Vector2(card_r.size.x * 0.5, 22.0), 32.0, false)
					ScavengeScene._draw_text_centered(self, font, card_r.position + Vector2(card_r.size.x * 0.5, 47.0), str(entry.get("short_name", iid)), 10, ScavengeScene.COL_INK)
				else:
					ItemDB.draw_item_icon(self, iid, card_r.position + Vector2(32.0, 28.0), 40.0, false)
					draw_string(font, Vector2(card_r.position.x + 58.0, card_r.position.y + 25.0), str(entry.get("short_name", iid)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ScavengeScene.COL_INK)
					draw_string(font, Vector2(card_r.position.x + 58.0, card_r.position.y + 43.0), "[2 SLOTS]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_HAZARD_GOLD)

			cur_slot += span

	func _draw_controls_and_compass(font: Font) -> void:
		# Unclipped 396px Bottom-Left Controls Hint
		var hint_r := Rect2(14.0, 646.0, 396.0, 64.0)
		draw_rect(hint_r, Color(0.12, 0.14, 0.12, 0.9), true)
		draw_rect(hint_r, Color(0.45, 0.44, 0.36, 0.85), false, 1.5)
		draw_string(font, Vector2(22.0, 666.0), "WASD / Arrows / Click: Run", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_PARCHMENT)
		draw_string(font, Vector2(22.0, 684.0), "E / Space / Click: Grab Item", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_HAZARD_YELLOW)
		draw_string(font, Vector2(22.0, 701.0), "Walk onto Hatch: Drop Loot  |  F: Dive In", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ScavengeScene.COL_PARCHMENT_DARK)

		# Bottom-Right Hatch Compass & Speed Readout
		var comp_r := Rect2(922.0, 646.0, 344.0, 64.0)
		draw_rect(comp_r, Color(0.12, 0.14, 0.12, 0.9), true)
		draw_rect(comp_r, Color(0.45, 0.44, 0.36, 0.85), false, 1.5)

		var to_hatch: Vector2 = scene_ref._hatch_pos - scene_ref._player_pos
		var dist_px: float = to_hatch.length()
		var dist_m: float = dist_px / 46.0
		var cc := Vector2(comp_r.position.x + 32.0, comp_r.get_center().y)
		draw_circle(cc, 20.0, ScavengeScene.COL_SLATE_DARK)
		draw_arc(cc, 20.0, 0.0, TAU, 24, ScavengeScene.COL_HAZARD_YELLOW, 1.8, true)

		if dist_px <= scene_ref._hatch_radius + ScavengeScene.HATCH_DROP_MARGIN:
			draw_circle(cc, 8.0, ScavengeScene.COL_TOXIC_GREEN)
			draw_string(font, Vector2(comp_r.position.x + 62.0, 671.0), "AT BUNKER HATCH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ScavengeScene.COL_TOXIC_GREEN)
		else:
			# Rotate compass needle into screen space if 3D camera is active so arrow points straight at hatch on screen!
			var dir_h: Vector2 = to_hatch.normalized()
			if is_instance_valid(scene_ref._camera_3d):
				var p_scr: Vector2 = scene_ref.project_2d_to_screen(scene_ref._player_pos, 0.1)
				var h_scr: Vector2 = scene_ref.project_2d_to_screen(scene_ref._hatch_pos, 0.1)
				if p_scr.distance_to(h_scr) > 1.0:
					dir_h = (h_scr - p_scr).normalized()
			var tip: Vector2 = cc + dir_h * 14.0
			var wing_l: Vector2 = cc - dir_h * 8.0 + Vector2(-dir_h.y, dir_h.x) * 6.5
			var wing_r: Vector2 = cc - dir_h * 8.0 - Vector2(-dir_h.y, dir_h.x) * 6.5
			draw_colored_polygon(PackedVector2Array([tip, wing_l, wing_r]), ScavengeScene.COL_HAZARD_YELLOW)
			draw_string(font, Vector2(comp_r.position.x + 62.0, 671.0), "HATCH BEARING: %.1f m" % dist_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ScavengeScene.COL_HAZARD_YELLOW)

		var spd_pct: int = int(round((scene_ref._compute_move_speed() / ScavengeScene.BASE_MOVE_SPEED) * 100.0))
		var spd_col: Color = ScavengeScene.COL_TOXIC_GREEN if spd_pct >= 100 else ScavengeScene.COL_PARCHMENT_DARK
		draw_string(font, Vector2(comp_r.position.x + 62.0, 695.0), "MOVE SPEED: %d%%" % spd_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, spd_col)

	func _draw_outro_transition_overlay(font: Font) -> void:
		draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.05, 0.05, 0.04, 0.78), true)

		if scene_ref._atomic_flash_alpha > 0.0:
			draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(1.0, 0.96, 0.86, scene_ref._atomic_flash_alpha), true)

		var card := Rect2(250.0, 146.0, 780.0, 428.0)
		draw_rect(Rect2(card.position + Vector2(6.0, 8.0), card.size), Color(0.0, 0.0, 0.0, 0.55), true)
		draw_rect(card, ScavengeScene.COL_PARCHMENT, true)
		var hdr_r := Rect2(card.position.x, card.position.y, card.size.x, 58.0)
		var hdr_bg: Color = ScavengeScene.COL_ALERT_RED if scene_ref._leader_caught_outside else ScavengeScene.COL_SLATE_DARK
		draw_rect(hdr_r, hdr_bg, true)
		draw_rect(card, ScavengeScene.COL_INK, false, 3.5)

		var survivors: Array = GameState.get_all_living_members()
		var no_guardian: bool = (not survivors.is_empty()) and (not scene_ref._has_capable_guardian_in_bunker())
		var title_txt: String = "HATCH SEALED — ENTERING FALLOUT SHELTER..."
		if GameState.game_mode == "scavenge_drill":
			title_txt = "DRILL COMPLETE — TALLYING CIVIL DEFENSE DOSSIER..." if not scene_ref._leader_caught_outside else "DRILL FAILED — CAUGHT ABOVE GROUND"
		elif scene_ref._leader_caught_outside:
			if survivors.is_empty():
				title_txt = "ATOMIC DETONATION — NO SURVIVORS IN BUNKER"
			elif no_guardian:
				title_txt = "NO ADULT GUARDIAN IN SHELTER — EMERGENCY SEAL FAILED"
			else:
				title_txt = "LEADER CAUGHT OUTSIDE — SEALING EMERGENCY HATCH..."

		ScavengeScene._draw_text_centered(self, font, hdr_r.get_center(), title_txt, 19, ScavengeScene.COL_HAZARD_YELLOW if not scene_ref._leader_caught_outside else ScavengeScene.COL_PARCHMENT)

		var soup_n: int = GameState.soup_quarters / 4
		var water_n: int = GameState.water_quarters / 4
		var gear_n: int = scene_ref._gear_deposited_count
		var fam_n: int = survivors.size()
		var fam_tot: int = GameState.family_members.size()

		var tile_y: float = card.position.y + 84.0
		var tile_w: float = 166.0
		var tile_h: float = 112.0
		var tile_gap: float = 20.0
		var tx0: float = card.get_center().x - (tile_w * 4.0 + tile_gap * 3.0) * 0.5

		var tiles_data: Array = [
			{"icon": "soup", "val": "%d CANS" % soup_n, "lbl": "TOMATO SOUP"},
			{"icon": "water", "val": "%d BOTTLES" % water_n, "lbl": "DRINKING WATER"},
			{"icon": "suitcase", "val": "%d ITEMS" % gear_n, "lbl": "SURVIVAL GEAR"},
			{"icon": "medkit", "val": "%d / %d" % [fam_n, fam_tot], "lbl": "SURVIVORS"}
		]

		for ti in range(4):
			var td: Dictionary = tiles_data[ti]
			var tr := Rect2(tx0 + float(ti) * (tile_w + tile_gap), tile_y, tile_w, tile_h)
			draw_rect(tr, ScavengeScene.COL_PARCHMENT_DARK, true)
			draw_rect(tr, ScavengeScene.COL_INK, false, 2.0)
			ItemDB.draw_item_icon(self, str(td["icon"]), tr.position + Vector2(tile_w * 0.5, 34.0), 38.0, false)
			ScavengeScene._draw_text_centered(self, font, tr.position + Vector2(tile_w * 0.5, 74.0), str(td["val"]), 16, ScavengeScene.COL_INK)
			ScavengeScene._draw_text_centered(self, font, tr.position + Vector2(tile_w * 0.5, 96.0), str(td["lbl"]), 11, ScavengeScene.COL_SLATE)

		var fam_count: int = GameState.family_members.size()
		var p_size: float = 78.0
		var p_gap: float = 34.0
		var px0: float = card.get_center().x - (float(fam_count) * p_size + float(maxi(0, fam_count - 1)) * p_gap) * 0.5
		var py0: float = card.position.y + 224.0

		for fi in range(fam_count):
			var fm: Dictionary = GameState.family_members[fi]
			var pr := Rect2(px0 + float(fi) * (p_size + p_gap), py0, p_size, p_size)
			var safe: bool = bool(fm.get("in_bunker", false)) and bool(fm.get("alive", false))
			CharacterArtist.draw_portrait(self, pr, fm, true)
			if not safe:
				draw_rect(pr, Color(0.15, 0.05, 0.05, 0.55), true)
			draw_rect(pr, ScavengeScene.COL_TOXIC_GREEN if safe else ScavengeScene.COL_ALERT_RED, false, 3.0)
			ScavengeScene._draw_text_centered(self, font, Vector2(pr.get_center().x, pr.end.y + 16.0), str(fm.get("name", "Member")), 13, ScavengeScene.COL_INK)
			ScavengeScene._draw_badge_pill(
				self,
				font,
				Vector2(pr.get_center().x, pr.end.y + 36.0),
				"SAFE" if safe else "LOST",
				10,
				ScavengeScene.COL_SLATE_DARK,
				ScavengeScene.COL_TOXIC_GREEN if safe else ScavengeScene.COL_ALERT_RED
			)

		var bar_r := Rect2(card.position.x + 40.0, card.end.y - 34.0, card.size.x - 80.0, 14.0)
		var fill_p: float = clampf(scene_ref._outro_elapsed / ScavengeScene.OUTRO_DURATION, 0.0, 1.0)
		draw_rect(bar_r, ScavengeScene.COL_SLATE_DARK, true)
		draw_rect(Rect2(bar_r.position.x + 2.0, bar_r.position.y + 2.0, (bar_r.size.x - 4.0) * fill_p, bar_r.size.y - 4.0), ScavengeScene.COL_HAZARD_YELLOW, true)
		draw_rect(bar_r, ScavengeScene.COL_INK, false, 1.5)
