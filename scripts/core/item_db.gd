class_name ItemDB
extends RefCounted

## Item metadata and icons for The End Is Near. Everything about an item (name, slots, purpose
## line, rooms it turns up in, icon) comes from data/items.csv via data/build/items.json, so a
## new item is a new row plus an icon (see docs/ADDING_CONTENT.md). Icons are game-icons.net
## SVGs recoloured to the palette (tools/recolor_icons.gd). Pets and the (disabled) car-escape
## parts keep small procedural drawings.

const COL_INK := Color("#14171c")
const COL_PAPER := Color("#e8eaed")
# Palette used by the remaining procedural drawings (pets, car-escape parts, the broken badge).
const COL_PARCHMENT := Color("#f2e6ce")
const COL_PARCHMENT_DARK := Color("#dccba6")
const COL_CREAM := Color("#faf3e3")
const COL_HAZARD_YELLOW := Color("#f5be2e")
const COL_HAZARD_GOLD := Color("#c98f18")
const COL_ATOMIC_RED := Color("#d9442a")
const COL_ATOMIC_DARK := Color("#992816")
const COL_OLIVE := Color("#55663e")
const COL_OLIVE_DARK := Color("#384428")
const COL_SLATE := Color("#232824")
const COL_STEEL := Color("#aeb8c0")
const COL_STEEL_LIGHT := Color("#dde5ec")
const COL_STEEL_DARK := Color("#6e7982")
const COL_WATER_BLUE := Color("#3b8ec2")
const COL_WATER_LIGHT := Color("#7fd0f5")
const COL_WALNUT := Color("#854c24")
const COL_WALNUT_LIGHT := Color("#ab6839")
const COL_WALNUT_DARK := Color("#573015")
const COL_TOXIC_GREEN := Color("#74bf44")

static var _tex_cache: Dictionary = {}


## Every item in the data tables (core, junk and makeshift).
static func get_all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in ShelterData.items().keys():
		ids.append(str(k))
	ids.sort()
	return ids


## Durable items that can turn up once per house in the grab (food and water are stacked separately).
static func get_scavenge_pool_ids() -> Array[String]:
	var pool: Array[String] = []
	for k in ShelterData.loot_for("home").keys():
		var id: String = str(k)
		if id != "food" and id != "water":
			pool.append(id)
	pool.sort()
	return pool


static func get_companion_ids() -> Array[String]:
	var companions: Array[String] = ["cat", "dog"]
	return companions


static func _normalize_id(item_id: String) -> String:
	var clean: String = item_id.strip_edges().to_lower()
	match clean:
		"soup":
			return "food"
		"book":
			return "manual"
	return clean


static func get_item_slots(item_id: String) -> int:
	return int(get_item_info(item_id).get("slots", 1))


static func is_two_slot_item(item_id: String) -> bool:
	return get_item_slots(item_id) == 2


## {id, name, short_name, slots, category, description, purpose, preferred_rooms, color}
static func get_item_info(item_id: String) -> Dictionary:
	var key: String = _normalize_id(item_id)
	var it: Dictionary = ShelterData.item(key)
	if it.is_empty():
		var label: String = key.replace("_", " ").capitalize()
		match key:
			"cat":
				label = "Cat"
			"dog":
				label = "Dog"
		return {"id": key, "name": label, "short_name": label, "slots": 1, "category": "other",
			"description": "", "purpose": "", "preferred_rooms": [], "color": COL_PAPER}
	return {
		"id": key, "name": str(it.get("name", key)), "short_name": str(it.get("short_name", it.get("name", key))),
		"slots": int(it.get("slots", 1)), "category": str(it.get("category", "core")),
		"description": str(it.get("purpose", "")), "purpose": str(it.get("purpose", "")),
		"preferred_rooms": it.get("grab_rooms", []), "color": Color(str(it.get("icon_color", "#e8eaed"))),
		"almanac": str(it.get("almanac", "")),
	}


## "Medkit [2] — cures one sick or injured person" (the grab and every tooltip use this line).
static func tooltip_line(item_id: String) -> String:
	var info: Dictionary = get_item_info(item_id)
	var purpose: String = str(info.get("purpose", ""))
	if purpose == "":
		return "%s [%d]" % [str(info["name"]), int(info["slots"])]
	return "%s [%d] — %s" % [str(info["name"]), int(info["slots"]), purpose.substr(0, 1).to_lower() + purpose.substr(1)]


static func get_icon_texture(item_id: String) -> Texture2D:
	var key: String = _normalize_id(item_id)
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path: String = str(ShelterData.item(key).get("icon", ""))
	if path == "" and key in ["cat", "dog", "radioactive", "tombstone", "hatch"]:
		path = "res://assets/icons/ui/%s.svg" % key
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	_tex_cache[key] = tex
	return tex


static func draw_item_icon(
	canvas: CanvasItem,
	item_id: String,
	center: Vector2,
	size: float,
	broken: bool = false
) -> void:
	if canvas == null or size <= 2.0:
		return
	var key: String = _normalize_id(item_id)
	var s: float = maxf(size, 10.0)
	var u: float = s * 0.5
	var ol: float = clampf(s * 0.046, 1.2, 3.2)
	var thin: float = clampf(s * 0.028, 1.0, 2.0)
	match key:
		"car_battery":
			_draw_car_battery(canvas, center, u, ol)
		"fuel_can":
			_draw_fuel_can(canvas, center, u, ol)
		"spark_plugs":
			_draw_spark_plugs(canvas, center, u, ol)
		"fan_belt":
			_draw_fan_belt(canvas, center, u, ol)
		"tire_patch":
			_draw_tire_patch(canvas, center, u, ol)
		"cat":
			_draw_cat(canvas, center, u, ol, thin)
		"dog":
			_draw_dog(canvas, center, u, ol, thin)
		_:
			var tex: Texture2D = get_icon_texture(key)
			if tex != null:
				# A dark disc behind the glyph keeps light icons readable on light paper too.
				canvas.draw_circle(center, u * 0.98, Color(0.08, 0.09, 0.11, 0.55))
				var r := Rect2(center - Vector2(u, u) * 0.82, Vector2(u, u) * 1.64)
				canvas.draw_texture_rect(tex, r, false, Color(0.55, 0.55, 0.55, 1.0) if broken else Color.WHITE)
			else:
				_draw_fallback_crate(canvas, center, u, ol, thin)
	if broken:
		_draw_broken_overlay(canvas, center, u, ol, thin)


# ---------------------------------------------------------------------------
# Safe polygon & curve helpers (used by the remaining procedural drawings)
# ---------------------------------------------------------------------------

static func _poly(
	canvas: CanvasItem,
	pts: PackedVector2Array,
	fill: Color,
	stroke: Color = Color(0.0, 0.0, 0.0, 0.0),
	stroke_w: float = 1.5
) -> void:
	var n: int = pts.size()
	if n < 3:
		return
	var area2: float = 0.0
	for i in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		area2 += a.x * b.y - b.x * a.y
	if absf(area2) <= 0.04:
		return
	if fill.a > 0.005:
		canvas.draw_colored_polygon(pts, fill)
	if stroke.a > 0.005 and stroke_w > 0.0:
		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		canvas.draw_polyline(closed, stroke, stroke_w)


static func _ellipse_pts(
	c: Vector2,
	rx: float,
	ry: float,
	rot: float = 0.0,
	segs: int = 16
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var count: int = maxi(segs, 6)
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	for i in range(count):
		var ang: float = TAU * float(i) / float(count)
		var lx: float = cos(ang) * rx
		var ly: float = sin(ang) * ry
		pts.append(Vector2(c.x + lx * cr - ly * sr, c.y + lx * sr + ly * cr))
	return pts


static func _round_rect_pts(rect: Rect2, radius: float, segs_corner: int = 3) -> PackedVector2Array:
	var w: float = rect.size.x
	var h: float = rect.size.y
	if w <= 0.5 or h <= 0.5:
		return PackedVector2Array()
	var r: float = clampf(radius, 0.0, minf(w, h) * 0.46)
	if r <= 0.4:
		return PackedVector2Array([
			rect.position,
			Vector2(rect.position.x + w, rect.position.y),
			rect.position + rect.size,
			Vector2(rect.position.x, rect.position.y + h)
		])
	var pts := PackedVector2Array()
	var steps: int = maxi(segs_corner, 2)
	var corners: Array[Vector2] = [
		Vector2(rect.position.x + w - r, rect.position.y + r),
		Vector2(rect.position.x + w - r, rect.position.y + h - r),
		Vector2(rect.position.x + r, rect.position.y + h - r),
		Vector2(rect.position.x + r, rect.position.y + r)
	]
	var base_angles: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for ci in range(4):
		var cc: Vector2 = corners[ci]
		var a0: float = base_angles[ci]
		for s_idx in range(steps + 1):
			var ang: float = a0 + (PI * 0.5) * (float(s_idx) / float(steps))
			pts.append(cc + Vector2(cos(ang) * r, sin(ang) * r))
	return pts


static func _rot_rect_pts(c: Vector2, half_extents: Vector2, angle: float) -> PackedVector2Array:
	var cr: float = cos(angle)
	var sr: float = sin(angle)
	var hx: float = half_extents.x
	var hy: float = half_extents.y
	var raw: Array[Vector2] = [
		Vector2(-hx, -hy),
		Vector2(hx, -hy),
		Vector2(hx, hy),
		Vector2(-hx, hy)
	]
	var pts := PackedVector2Array()
	for v in raw:
		pts.append(Vector2(c.x + v.x * cr - v.y * sr, c.y + v.x * sr + v.y * cr))
	return pts


static func _draw_ground_shadow(canvas: CanvasItem, c: Vector2, u: float) -> void:
	# Soft grounded contact shadow under the item without any artificial circular halo
	var sh_pts: PackedVector2Array = _ellipse_pts(c + Vector2(0.0, u * 0.75), u * 0.58, u * 0.14, 0.0, 14)
	_poly(canvas, sh_pts, Color(0.05, 0.05, 0.04, 0.26))


static func _draw_cat(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var hc: Vector2 = c + Vector2(0.0, u * 0.10)

	# Cosmonaut collar & shiny cyan/gold charm below chin
	var col_rect := Rect2(hc.x - u * 0.36, hc.y + u * 0.44, u * 0.72, u * 0.14)
	canvas.draw_rect(col_rect, COL_ATOMIC_RED, true)
	canvas.draw_rect(col_rect, COL_INK, false, thin)
	canvas.draw_circle(hc + Vector2(0.0, u * 0.58), maxf(u * 0.11, 1.4), COL_INK)
	canvas.draw_circle(hc + Vector2(0.0, u * 0.58), maxf(u * 0.08, 1.0), COL_HAZARD_YELLOW)

	# Pointed grey cat ears with pink inner triangles
	for sgn in [-1.0, 1.0]:
		var es: float = float(sgn)
		var ear_pts := PackedVector2Array([
			hc + Vector2(es * u * 0.18, -u * 0.42),
			hc + Vector2(es * u * 0.58, -u * 0.82),
			hc + Vector2(es * u * 0.56, -u * 0.20)
		])
		_poly(canvas, ear_pts, Color("#7e868f"), COL_INK, ol)
		var inner_ear := PackedVector2Array([
			hc + Vector2(es * u * 0.26, -u * 0.42),
			hc + Vector2(es * u * 0.50, -u * 0.68),
			hc + Vector2(es * u * 0.48, -u * 0.28)
		])
		_poly(canvas, inner_ear, Color("#d98b8b"))

	# Plump grey-striped tabby head
	_poly(canvas, _ellipse_pts(hc, u * 0.58, u * 0.50, 0.0, 16), Color("#8d949c"), COL_INK, ol)
	# Tabby cheek stripes
	for sgn in [-1.0, 1.0]:
		var cs: float = float(sgn)
		canvas.draw_line(hc + Vector2(cs * u * 0.36, u * 0.02), hc + Vector2(cs * u * 0.54, -u * 0.02), Color("#464c54"), thin * 1.3)
		canvas.draw_line(hc + Vector2(cs * u * 0.34, u * 0.14), hc + Vector2(cs * u * 0.52, u * 0.14), Color("#464c54"), thin * 1.3)

	# Cozy fur ushanka crown visor between ears with red cosmonaut star
	var hat_rect := Rect2(hc.x - u * 0.36, hc.y - u * 0.66, u * 0.72, u * 0.30)
	_poly(canvas, _round_rect_pts(hat_rect, u * 0.09, 2), Color("#6e5b46"), COL_INK, ol * 0.9)
	canvas.draw_circle(Vector2(hc.x, hat_rect.position.y + hat_rect.size.y * 0.5), maxf(u * 0.08, 1.2), COL_ATOMIC_RED)

	# Piercing glowing yellow feline eyes with slit pupils
	for sgn in [-1.0, 1.0]:
		var ec: Vector2 = hc + Vector2(float(sgn) * u * 0.23, -u * 0.06)
		_poly(canvas, _ellipse_pts(ec, u * 0.13, u * 0.11, 0.0, 10), COL_HAZARD_YELLOW, COL_INK, thin)
		canvas.draw_line(ec + Vector2(0.0, -u * 0.08), ec + Vector2(0.0, u * 0.08), COL_INK, thin * 1.2)

	# Lighter muzzle pads, pink nose & crisp white whiskers
	canvas.draw_circle(hc + Vector2(-u * 0.10, u * 0.18), u * 0.11, Color("#d4dae0"))
	canvas.draw_circle(hc + Vector2(u * 0.10, u * 0.18), u * 0.11, Color("#d4dae0"))
	var nose_pts := PackedVector2Array([
		hc + Vector2(-u * 0.08, u * 0.08),
		hc + Vector2(u * 0.08, u * 0.08),
		hc + Vector2(0.0, u * 0.17)
	])
	_poly(canvas, nose_pts, Color("#e07b7b"))
	for sgn in [-1.0, 1.0]:
		var ws: float = float(sgn)
		canvas.draw_line(hc + Vector2(ws * u * 0.18, u * 0.16), hc + Vector2(ws * u * 0.68, u * 0.10), COL_CREAM, thin)
		canvas.draw_line(hc + Vector2(ws * u * 0.18, u * 0.22), hc + Vector2(ws * u * 0.66, u * 0.26), COL_CREAM, thin)


# ---------------------------------------------------------------------------
# DOG — a scruffy golden dog with floppy ears (pets only arrive through events)
# ---------------------------------------------------------------------------

static func _draw_dog(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var hc: Vector2 = c + Vector2(0.0, -u * 0.02)

	# Red collar + gold dog tag at neck
	var col_rect := Rect2(hc.x - u * 0.34, hc.y + u * 0.50, u * 0.68, u * 0.14)
	canvas.draw_rect(col_rect, COL_ATOMIC_RED, true)
	canvas.draw_rect(col_rect, COL_INK, false, thin)
	canvas.draw_circle(hc + Vector2(0.0, u * 0.64), maxf(u * 0.09, 1.2), COL_HAZARD_YELLOW)

	# Two floppy dark-brown mutt ears (left drooping, right folded perkily)
	var ear_l := PackedVector2Array([
		hc + Vector2(-u * 0.44, -u * 0.36),
		hc + Vector2(-u * 0.76, -u * 0.10),
		hc + Vector2(-u * 0.70, u * 0.36),
		hc + Vector2(-u * 0.42, u * 0.18)
	])
	_poly(canvas, ear_l, COL_WALNUT, COL_INK, ol)

	var ear_r := PackedVector2Array([
		hc + Vector2(u * 0.36, -u * 0.44),
		hc + Vector2(u * 0.78, -u * 0.30),
		hc + Vector2(u * 0.64, u * 0.10),
		hc + Vector2(u * 0.40, -u * 0.06)
	])
	_poly(canvas, ear_r, COL_WALNUT, COL_INK, ol)

	# Scruffy golden-tan head + crown fur tuft
	_poly(canvas, _ellipse_pts(hc, u * 0.54, u * 0.52, 0.0, 16), Color("#d89c42"), COL_INK, ol)
	var tuft := PackedVector2Array([
		hc + Vector2(-u * 0.16, -u * 0.48),
		hc + Vector2(-u * 0.02, -u * 0.72),
		hc + Vector2(u * 0.16, -u * 0.48)
	])
	_poly(canvas, tuft, Color("#d89c42"), COL_INK, ol * 0.85)

	# Cream snout muzzle + happy pink tongue sticking out
	var muz_c: Vector2 = hc + Vector2(0.0, u * 0.18)
	_poly(canvas, _ellipse_pts(muz_c, u * 0.34, u * 0.24, 0.0, 12), Color("#f2dbb3"), COL_INK, thin)
	var tongue_c: Vector2 = muz_c + Vector2(u * 0.08, u * 0.20)
	_poly(canvas, _ellipse_pts(tongue_c, u * 0.11, u * 0.15, 0.12, 10), Color("#eb6c80"), COL_INK, thin)

	# Big shiny dark truffle nose
	_poly(canvas, _ellipse_pts(muz_c + Vector2(0.0, -u * 0.08), u * 0.15, u * 0.10, 0.0, 10), COL_INK)
	canvas.draw_circle(muz_c + Vector2(-u * 0.04, -u * 0.10), maxf(u * 0.035, 0.9), COL_CREAM)

	# Warm expressive dark eyes with white catchlights
	for sgn in [-1.0, 1.0]:
		var ec: Vector2 = hc + Vector2(float(sgn) * u * 0.22, -u * 0.12)
		canvas.draw_circle(ec, maxf(u * 0.09, 1.3), COL_INK)
		canvas.draw_circle(ec + Vector2(-u * 0.025, -u * 0.025), maxf(u * 0.03, 0.8), Color.WHITE)


# ---------------------------------------------------------------------------
# Fallback Crate & Broken Item Overlay (Jagged Cracks + Red Corner X Badge)
# ---------------------------------------------------------------------------

static func _draw_fallback_crate(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var r := Rect2(c.x - u * 0.62, c.y - u * 0.62, u * 1.24, u * 1.24)
	_poly(canvas, _round_rect_pts(r, u * 0.10, 2), COL_PARCHMENT_DARK, COL_INK, ol)
	canvas.draw_line(r.position, r.end, COL_INK, thin)
	canvas.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), COL_INK, thin)


static func _draw_broken_overlay(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# Subtle damaged soot veil
	canvas.draw_circle(c, u * 0.72, Color(0.10, 0.09, 0.08, 0.20))

	# Jagged fracture lines (pale highlight edge + bold dark crack core for visibility on any item)
	var main_crack := PackedVector2Array([
		c + Vector2(-u * 0.48, -u * 0.52),
		c + Vector2(-u * 0.14, -u * 0.16),
		c + Vector2(u * 0.08, -u * 0.24),
		c + Vector2(-u * 0.06, u * 0.12),
		c + Vector2(u * 0.34, u * 0.44)
	])
	var branch_crack := PackedVector2Array([
		c + Vector2(-u * 0.14, -u * 0.16),
		c + Vector2(-u * 0.38, u * 0.08),
		c + Vector2(-u * 0.30, u * 0.34)
	])
	var hi_offset := Vector2(thin * 0.75, 0.0)
	var main_hi := PackedVector2Array()
	for pt in main_crack:
		main_hi.append(pt + hi_offset)
	canvas.draw_polyline(main_hi, Color(0.98, 0.94, 0.84, 0.75), thin)
	canvas.draw_polyline(main_crack, COL_INK, ol * 1.15)
	canvas.draw_polyline(branch_crack, COL_INK, thin * 1.25)

	# Bold Red Corner X Badge at bottom-right
	var bc: Vector2 = c + Vector2(u * 0.54, u * 0.54)
	var br: float = maxf(u * 0.30, 4.0)
	canvas.draw_circle(bc, br + ol * 0.7, COL_INK)
	canvas.draw_circle(bc, br, Color("#d92b22"))
	var xr: float = br * 0.48
	var xw: float = maxf(ol * 1.1, 1.5)
	canvas.draw_line(bc + Vector2(-xr, -xr), bc + Vector2(xr, xr), COL_CREAM, xw)
	canvas.draw_line(bc + Vector2(xr, -xr), bc + Vector2(-xr, xr), COL_CREAM, xw)



# --- Vehicle parts (pass 2) ---

static func _draw_car_battery(c: CanvasItem, p: Vector2, u: float, ol: float) -> void:
	var body := Rect2(p + Vector2(-u * 0.78, -u * 0.45), Vector2(u * 1.56, u * 1.05))
	c.draw_rect(body.grow(ol), COL_INK)
	c.draw_rect(body, Color("#2f3a42"))
	c.draw_rect(Rect2(body.position, Vector2(body.size.x, u * 0.22)), Color("#46545e"))
	for sx in [-0.48, 0.48]:
		var post := Rect2(p + Vector2(u * sx - u * 0.12, -u * 0.66), Vector2(u * 0.24, u * 0.22))
		c.draw_rect(post.grow(ol * 0.6), COL_INK)
		c.draw_rect(post, COL_ATOMIC_RED if sx > 0.0 else Color("#3c3c3c"))
	c.draw_line(p + Vector2(u * 0.36, -u * 0.12), p + Vector2(u * 0.6, -u * 0.12), COL_HAZARD_YELLOW, ol)
	c.draw_line(p + Vector2(u * 0.48, -u * 0.24), p + Vector2(u * 0.48, 0.0), COL_HAZARD_YELLOW, ol)
	c.draw_line(p + Vector2(-u * 0.6, -u * 0.12), p + Vector2(-u * 0.36, -u * 0.12), COL_STEEL_LIGHT, ol)
	c.draw_rect(Rect2(p + Vector2(-u * 0.5, u * 0.18), Vector2(u * 1.0, u * 0.18)), COL_HAZARD_YELLOW)


static func _draw_fuel_can(c: CanvasItem, p: Vector2, u: float, ol: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-u * 0.6, -u * 0.45), p + Vector2(u * 0.35, -u * 0.45), p + Vector2(u * 0.62, -u * 0.18), p + Vector2(u * 0.62, u * 0.75), p + Vector2(-u * 0.6, u * 0.75)])
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(p + (q - p) * 1.08)
	c.draw_colored_polygon(outline, COL_INK)
	c.draw_colored_polygon(pts, Color("#b8321e"))
	c.draw_line(p + Vector2(-u * 0.45, -u * 0.25), p + Vector2(u * 0.4, u * 0.6), Color("#8c2414"), ol)
	c.draw_line(p + Vector2(u * 0.4, -u * 0.25), p + Vector2(-u * 0.45, u * 0.6), Color("#8c2414"), ol)
	c.draw_rect(Rect2(p + Vector2(-u * 0.5, -u * 0.72), Vector2(u * 0.55, u * 0.2)), COL_INK)
	c.draw_rect(Rect2(p + Vector2(u * 0.3, -u * 0.72), Vector2(u * 0.18, u * 0.3)), COL_STEEL_DARK)


static func _draw_spark_plugs(c: CanvasItem, p: Vector2, u: float, ol: float) -> void:
	c.draw_rect(Rect2(p + Vector2(-u * 0.75, -u * 0.1), Vector2(u * 1.5, u * 0.75)).grow(ol), COL_INK)
	c.draw_rect(Rect2(p + Vector2(-u * 0.75, -u * 0.1), Vector2(u * 1.5, u * 0.75)), Color("#d8a438"))
	for i in range(3):
		var x: float = -u * 0.45 + float(i) * u * 0.45
		c.draw_rect(Rect2(p + Vector2(x - u * 0.09, -u * 0.72), Vector2(u * 0.18, u * 0.42)), Color("#f2efe6"))
		c.draw_rect(Rect2(p + Vector2(x - u * 0.13, -u * 0.32), Vector2(u * 0.26, u * 0.22)), COL_STEEL_DARK)
		c.draw_line(p + Vector2(x, -u * 0.72), p + Vector2(x, -u * 0.86), COL_INK, ol)


static func _draw_fan_belt(c: CanvasItem, p: Vector2, u: float, ol: float) -> void:
	c.draw_arc(p, u * 0.66, 0.0, TAU, 36, COL_INK, u * 0.3)
	c.draw_arc(p, u * 0.66, 0.0, TAU, 36, Color("#3a3532"), u * 0.2)
	c.draw_arc(p, u * 0.66, 0.4, 1.4, 12, Color("#6b625a"), ol)


static func _draw_tire_patch(c: CanvasItem, p: Vector2, u: float, ol: float) -> void:
	c.draw_circle(p + Vector2(-u * 0.12, u * 0.05), u * 0.66, COL_INK)
	c.draw_circle(p + Vector2(-u * 0.12, u * 0.05), u * 0.6, Color("#4a4a48"))
	c.draw_circle(p + Vector2(-u * 0.12, u * 0.05), u * 0.26, COL_STEEL)
	c.draw_rect(Rect2(p + Vector2(u * 0.3, -u * 0.8), Vector2(u * 0.22, u * 0.9)).grow(ol * 0.6), COL_INK)
	c.draw_rect(Rect2(p + Vector2(u * 0.3, -u * 0.8), Vector2(u * 0.22, u * 0.9)), COL_HAZARD_YELLOW)
