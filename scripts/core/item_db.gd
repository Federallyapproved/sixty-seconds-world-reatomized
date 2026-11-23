class_name ItemDB
extends RefCounted

## Canonical Item Database and Procedural Mid-Century CONELRAD Illustrator
## for "60 Seconds: World Reatomized".
## Provides metadata, slot rules, room affinities, and crisp multi-layered 2D
## vector illustrations for all 18 scavenge/bunker items plus companions.

const COL_INK := Color("#1b1917")
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


static func get_all_item_ids() -> Array[String]:
	var ids: Array[String] = [
		"soup",
		"water",
		"medkit",
		"gas_mask",
		"radio",
		"flashlight",
		"map",
		"book",
		"ammo",
		"bug_spray",
		"padlock",
		"cards",
		"checkers",
		"harmonica",
		"axe",
		"rifle",
		"suitcase",
		"toolbox"
	]
	return ids


static func get_scavenge_pool_ids() -> Array[String]:
	var pool: Array[String] = [
		"suitcase",
		"book",
		"flashlight",
		"map",
		"axe",
		"rifle",
		"padlock",
		"cards",
		"checkers",
		"bug_spray",
		"ammo",
		"toolbox",
		"harmonica"
	]
	return pool


static func get_companion_ids() -> Array[String]:
	var companions: Array[String] = ["cat", "dog"]
	return companions


static func get_specialty_item_ids() -> Array[String]:
	var spec: Array[String] = [
		"antibiotics",
		"antirad",
		"scrap",
		"fuel",
		"battery",
		"alternator",
		"spark_plugs",
		"radiator_hose"
	]
	return spec


static func _normalize_id(item_id: String) -> String:
	var clean: String = item_id.strip_edges().to_lower()
	if clean == "sharikov":
		return "cat"
	if clean == "pancake":
		return "dog"
	if clean == "anti_rad" or clean == "anti-rad":
		return "antirad"
	if clean == "fuel_can" or clean == "jerrycan":
		return "fuel"
	if clean == "spark_plug":
		return "spark_plugs"
	return clean


static func get_item_slots(item_id: String) -> int:
	var info: Dictionary = get_item_info(item_id)
	return int(info.get("slots", 1))


static func is_two_slot_item(item_id: String) -> bool:
	return get_item_slots(item_id) == 2


static func get_item_info(item_id: String) -> Dictionary:
	var key: String = _normalize_id(item_id)
	match key:
		"soup":
			return {
				"id": "soup",
				"name": "Tomato Soup Tin",
				"short_name": "Soup",
				"slots": 1,
				"category": "ration",
				"description": "Civil Defense shelf-stable condensed tomato soup (4 quarter-can rations). Keeps starvation at bay indefinitely.",
				"preferred_rooms": ["Kitchen", "Garage / Study", "Living Room"],
				"color": Color("#d9442a")
			}
		"water":
			return {
				"id": "water",
				"name": "Emergency Water Bottle",
				"short_name": "Water",
				"slots": 1,
				"category": "ration",
				"description": "Purified Civil Defense drinking water (4 quarter-bottle rations). Essential for surviving fallout heat.",
				"preferred_rooms": ["Kitchen", "Bathroom", "Garage / Study"],
				"color": Color("#3b8ec2")
			}
		"medkit":
			return {
				"id": "medkit",
				"name": "First Aid Medkit",
				"short_name": "Medkit",
				"slots": 1,
				"category": "medical",
				"description": "Sterile bandages, iodine, and antibiotics. Treats sickness, radiation burns, and expedition injuries.",
				"preferred_rooms": ["Bathroom", "Master Bedroom", "Kitchen"],
				"color": Color("#e04838")
			}
		"gas_mask":
			return {
				"id": "gas_mask",
				"name": "Civil Defense Gas Mask",
				"short_name": "Gas Mask",
				"slots": 1,
				"category": "survival",
				"description": "Dual-canister rubber respirator that shields wasteland explorers from lethal surface fallout.",
				"preferred_rooms": ["Garage / Study", "Hallway", "Master Bedroom"],
				"color": Color("#637847")
			}
		"radio":
			return {
				"id": "radio",
				"name": "CONELRAD Tube Radio",
				"short_name": "Radio",
				"slots": 1,
				"category": "survival",
				"description": "Vacuum-tube receiver tuned to 640 & 1240 kHz emergency broadcasts, weather reports, and military rescue signals.",
				"preferred_rooms": ["Living Room", "Master Bedroom", "Kitchen"],
				"color": Color("#d99a2b")
			}
		"flashlight":
			return {
				"id": "flashlight",
				"name": "Heavy-Duty Flashlight",
				"short_name": "Flashlight",
				"slots": 1,
				"category": "survival",
				"description": "Chrome and hazard-yellow angled Civil Defense torch for dark bunker vents and night scavenging.",
				"preferred_rooms": ["Hallway", "Garage / Study", "Master Bedroom"],
				"color": Color("#f5be2e")
			}
		"map":
			return {
				"id": "map",
				"name": "Neighborhood Street Map",
				"short_name": "Map",
				"slots": 1,
				"category": "survival",
				"description": "Folded local street survey marking nearby churches, grocery stores, pharmacies, and safe routes.",
				"preferred_rooms": ["Living Room", "Garage / Study", "Master Bedroom"],
				"color": Color("#e3c994")
			}
		"book":
			return {
				"id": "book",
				"name": "Boy Scout Handbook",
				"short_name": "Handbook",
				"slots": 1,
				"category": "survival",
				"description": "Indispensable field manual covering shelter repair, first aid, morale, and wasteland survival.",
				"preferred_rooms": ["Living Room", "Bedroom", "Master Bedroom"],
				"color": Color("#578247")
			}
		"ammo":
			return {
				"id": "ammo",
				"name": "Rifle Cartridges",
				"short_name": "Ammo",
				"slots": 1,
				"category": "defense",
				"description": "Box of brass .30-06 cartridges for loading the hunting rifle or trading with wasteland patrols.",
				"preferred_rooms": ["Garage / Study", "Master Bedroom"],
				"color": Color("#d9a738")
			}
		"bug_spray":
			return {
				"id": "bug_spray",
				"name": "Roach Bug Spray",
				"short_name": "Bug Spray",
				"slots": 1,
				"category": "defense",
				"description": "Industrial DDT aerosol canister that eradicates mutant cockroach infestations and fungal mold.",
				"preferred_rooms": ["Bathroom", "Kitchen", "Garage / Study"],
				"color": Color("#7ec850")
			}
		"padlock":
			return {
				"id": "padlock",
				"name": "Heavy Brass Padlock",
				"short_name": "Padlock",
				"slots": 1,
				"category": "defense",
				"description": "Hardened steel-shackle padlock that reinforces the bunker hatch against a raider break-in.",
				"preferred_rooms": ["Garage / Study", "Hallway"],
				"color": Color("#dba32e")
			}
		"cards":
			return {
				"id": "cards",
				"name": "Playing Cards",
				"short_name": "Cards",
				"slots": 1,
				"category": "morale",
				"description": "Standard 52-card deck for passing endless fallout evenings—just avoid high-stakes soup bets.",
				"preferred_rooms": ["Living Room", "Bedroom"],
				"color": Color("#ebe0c8")
			}
		"checkers":
			return {
				"id": "checkers",
				"name": "Checkerboard Set",
				"short_name": "Checkers",
				"slots": 1,
				"category": "morale",
				"description": "Classic red-and-black wooden checkerboard that keeps cabin fever away inside the shelter.",
				"preferred_rooms": ["Living Room", "Bedroom"],
				"color": Color("#c9422e")
			}
		"harmonica":
			return {
				"id": "harmonica",
				"name": "Blues Harmonica",
				"short_name": "Harmonica",
				"slots": 1,
				"category": "morale",
				"description": "Brushed-chrome pocket harp that lifts bunker spirits and charms friendly strangers.",
				"preferred_rooms": ["Bedroom", "Living Room"],
				"color": Color("#aebac4")
			}
		"axe":
			return {
				"id": "axe",
				"name": "Fireman's Axe",
				"short_name": "Axe",
				"slots": 2,
				"category": "defense",
				"description": "Heavy 2-slot rescue axe for repelling raiders, chopping barricades, and clearing rubble (risks minor scrapes).",
				"preferred_rooms": ["Garage / Study", "Hallway"],
				"color": Color("#d63b29")
			}
		"rifle":
			return {
				"id": "rifle",
				"name": "Hunting Rifle",
				"short_name": "Rifle",
				"slots": 2,
				"category": "defense",
				"description": "Classic 2-slot walnut-stock bolt-action rifle. Unmatched protection against bandits when loaded with ammo.",
				"preferred_rooms": ["Master Bedroom", "Garage / Study"],
				"color": Color("#9c5c31")
			}
		"suitcase":
			return {
				"id": "suitcase",
				"name": "Leather Suitcase",
				"short_name": "Suitcase",
				"slots": 2,
				"category": "utility",
				"description": "Vintage 2-slot leather luggage: expands scavenge carry capacity to 5 slots and lets explorers carry extra gear!",
				"preferred_rooms": ["Master Bedroom", "Hallway", "Bedroom"],
				"color": Color("#94552b")
			}
		"toolbox":
			return {
				"id": "toolbox",
				"name": "Mechanic's Toolbox",
				"short_name": "Toolbox",
				"slots": 2,
				"category": "utility",
				"description": "Heavy 2-slot steel chest of wrenches and soldering irons capable of repairing broken bunker gear.",
				"preferred_rooms": ["Garage / Study", "Hallway"],
				"color": Color("#cf3a2b")
			}
		"cat":
			return {
				"id": "cat",
				"name": "Sharikov the Cat",
				"short_name": "Sharikov",
				"slots": 1,
				"category": "companion",
				"description": "Clever grey-striped tabby with a cosmonaut collar. Hunts pests, boosts sanity, and hides secret lab cables.",
				"preferred_rooms": ["Living Room", "Kitchen"],
				"color": Color("#8d949c")
			}
		"dog":
			return {
				"id": "dog",
				"name": "Pancake the Dog",
				"short_name": "Pancake",
				"slots": 1,
				"category": "companion",
				"description": "Loyal scruffy golden mutt who guards the hatch against raiders and sniffs out buried caches.",
				"preferred_rooms": ["Living Room", "Hallway"],
				"color": Color("#d89c42")
			}
		"antibiotics":
			return {
				"id": "antibiotics",
				"name": "Prescription Antibiotics",
				"short_name": "Antibiotics",
				"slots": 1,
				"category": "medical",
				"description": "Amber-glass prescription capsules from a Doctor's Office. Cures Stage-1/2 sickness & infection and prevents wound sepsis.",
				"preferred_rooms": ["Bathroom", "Master Bedroom"],
				"color": Color("#cf6a17")
			}
		"antirad":
			return {
				"id": "antirad",
				"name": "Potassium Iodide Anti-Rad",
				"short_name": "Anti-Rad",
				"slots": 1,
				"category": "medical",
				"description": "CONELRAD foil blister pack of Potassium Iodide tablets. Purges -35.0 Rads and blocks fallout radiation sickness.",
				"preferred_rooms": ["Bathroom", "Kitchen"],
				"color": Color("#f5be2e")
			}
		"scrap":
			return {
				"id": "scrap",
				"name": "Salvaged Scrap & Hardware",
				"short_name": "Scrap",
				"slots": 1,
				"category": "utility",
				"description": "Assorted steel hull plates, brass gears, and hardware. Repairs broken gear or reinforces shelter integrity (+12%).",
				"preferred_rooms": ["Garage / Study", "Hallway"],
				"color": Color("#8f9ba6")
			}
		"fuel":
			return {
				"id": "fuel",
				"name": "Gasoline Jerrycan",
				"short_name": "Fuel Can",
				"slots": 1,
				"category": "vehicle",
				"description": "Heavy red 5-gallon military steel jerrycan of stabilized gasoline for the Station Wagon highway escape.",
				"preferred_rooms": ["Garage / Study"],
				"color": Color("#cf3526")
			}
		"battery":
			return {
				"id": "battery",
				"name": "12V Lead-Acid Battery",
				"short_name": "Battery",
				"slots": 1,
				"category": "vehicle",
				"description": "Heavy-duty 12V automotive starter battery with intact lead cells for cranking the escape Station Wagon.",
				"preferred_rooms": ["Garage / Study"],
				"color": Color("#384047")
			}
		"alternator":
			return {
				"id": "alternator",
				"name": "Copper-Wound Alternator",
				"short_name": "Alternator",
				"slots": 1,
				"category": "vehicle",
				"description": "Finned aluminum dynamo alternator with copper windings and V-belt pulley for the Station Wagon engine.",
				"preferred_rooms": ["Garage / Study"],
				"color": Color("#d96b27")
			}
		"spark_plugs":
			return {
				"id": "spark_plugs",
				"name": "Ceramic Spark Plugs",
				"short_name": "Spark Plugs",
				"slots": 1,
				"category": "vehicle",
				"description": "Ribbed white ceramic ignition spark plugs with brass hex shells to fire the Station Wagon V8.",
				"preferred_rooms": ["Garage / Study"],
				"color": Color("#eef4f8")
			}
		"radiator_hose":
			return {
				"id": "radiator_hose",
				"name": "Reinforced Radiator Hose",
				"short_name": "Rad. Hose",
				"slots": 1,
				"category": "vehicle",
				"description": "Heavy curved reinforced rubber coolant hose with stainless steel clamps for the Station Wagon.",
				"preferred_rooms": ["Garage / Study"],
				"color": Color("#4a5258")
			}
		"vehicle_part":
			return {
				"id": "vehicle_part",
				"name": "Station Wagon Engine Part",
				"short_name": "Engine Part",
				"slots": 1,
				"category": "vehicle",
				"description": "Salvaged automotive engine component required to rebuild the shelter's escape Station Wagon.",
				"preferred_rooms": ["Garage / Study"],
				"color": Color("#5d6870")
			}
		_:
			return {
				"id": key,
				"name": key.capitalize(),
				"short_name": key.capitalize(),
				"slots": 1,
				"category": "utility",
				"description": "Salvaged Civil Defense household item.",
				"preferred_rooms": ["Living Room", "Garage / Study"],
				"color": COL_PARCHMENT
			}


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

	# Subtle warm rim / drop shadow so dark ink silhouettes read crisply on both dark bunker slate and light parchment
	_draw_ground_shadow(canvas, center, u)

	match key:
		"soup":
			_draw_soup(canvas, center, u, ol, thin)
		"water":
			_draw_water(canvas, center, u, ol, thin)
		"medkit":
			_draw_medkit(canvas, center, u, ol, thin)
		"gas_mask":
			_draw_gas_mask(canvas, center, u, ol, thin)
		"radio":
			_draw_radio(canvas, center, u, ol, thin)
		"flashlight":
			_draw_flashlight(canvas, center, u, ol, thin)
		"map":
			_draw_map(canvas, center, u, ol, thin)
		"book":
			_draw_book(canvas, center, u, ol, thin)
		"axe":
			_draw_axe(canvas, center, u, ol, thin)
		"rifle":
			_draw_rifle(canvas, center, u, ol, thin)
		"ammo":
			_draw_ammo(canvas, center, u, ol, thin)
		"bug_spray":
			_draw_bug_spray(canvas, center, u, ol, thin)
		"padlock":
			_draw_padlock(canvas, center, u, ol, thin)
		"cards":
			_draw_cards(canvas, center, u, ol, thin)
		"checkers":
			_draw_checkers(canvas, center, u, ol, thin)
		"suitcase":
			_draw_suitcase(canvas, center, u, ol, thin)
		"harmonica":
			_draw_harmonica(canvas, center, u, ol, thin)
		"toolbox":
			_draw_toolbox(canvas, center, u, ol, thin)
		"cat":
			_draw_cat(canvas, center, u, ol, thin)
		"dog":
			_draw_dog(canvas, center, u, ol, thin)
		"antibiotics":
			_draw_antibiotics(canvas, center, u, ol, thin)
		"antirad":
			_draw_antirad(canvas, center, u, ol, thin)
		"scrap":
			_draw_scrap(canvas, center, u, ol, thin)
		"fuel":
			_draw_fuel(canvas, center, u, ol, thin)
		"battery":
			_draw_battery(canvas, center, u, ol, thin)
		"alternator":
			_draw_alternator(canvas, center, u, ol, thin)
		"spark_plugs":
			_draw_spark_plugs(canvas, center, u, ol, thin)
		"radiator_hose", "vehicle_part":
			_draw_radiator_hose(canvas, center, u, ol, thin)
		_:
			_draw_fallback_crate(canvas, center, u, ol, thin)

	if broken:
		_draw_broken_overlay(canvas, center, u, ol, thin)


# ---------------------------------------------------------------------------
# Safe Polygon & Curve Geometry Helpers (strictly >= 3 non-collinear points)
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


# ---------------------------------------------------------------------------
# 1. SOUP — Campbell / CONELRAD Red-and-White Soup Tin
# ---------------------------------------------------------------------------

static func _draw_soup(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var cw: float = u * 0.54
	var top_y: float = c.y - u * 0.62
	var bot_y: float = c.y + u * 0.64
	var mid_y: float = c.y + u * 0.03
	var rim_ry: float = u * 0.16

	# Bottom steel rim base
	_poly(canvas, _ellipse_pts(Vector2(c.x, bot_y), cw * 1.03, rim_ry * 1.08, 0.0, 18), COL_STEEL_DARK, COL_INK, ol)

	# Lower white/cream label half with smooth elliptical bottom contour
	_poly(canvas, _ellipse_pts(Vector2(c.x, bot_y - rim_ry * 0.18), cw, rim_ry * 0.92, 0.0, 16), COL_CREAM)
	var lower_pts := PackedVector2Array([
		Vector2(c.x - cw, mid_y),
		Vector2(c.x + cw, mid_y),
		Vector2(c.x + cw, bot_y - rim_ry * 0.18),
		Vector2(c.x - cw, bot_y - rim_ry * 0.18)
	])
	_poly(canvas, lower_pts, COL_CREAM)

	# Upper iconic red label half
	var upper_pts := PackedVector2Array([
		Vector2(c.x - cw, top_y),
		Vector2(c.x + cw, top_y),
		Vector2(c.x + cw, mid_y),
		Vector2(c.x - cw, mid_y)
	])
	_poly(canvas, upper_pts, COL_ATOMIC_RED)

	# Cylindrical specular highlight & right-edge shadow
	var hi_x0: float = c.x - cw * 0.72
	var hi_w: float = cw * 0.26
	canvas.draw_rect(Rect2(hi_x0, top_y, hi_w, mid_y - top_y), Color(1.0, 0.62, 0.50, 0.38), true)
	canvas.draw_rect(Rect2(hi_x0, mid_y, hi_w, bot_y - mid_y), Color(1.0, 1.0, 1.0, 0.55), true)
	var sh_x0: float = c.x + cw * 0.56
	var sh_w: float = cw * 0.44
	canvas.draw_rect(Rect2(sh_x0, top_y, sh_w, mid_y - top_y), Color(0.25, 0.04, 0.02, 0.28), true)
	canvas.draw_rect(Rect2(sh_x0, mid_y, sh_w, bot_y - mid_y), Color(0.45, 0.38, 0.25, 0.25), true)

	# Bold label accent stripe near bottom + seam rule
	var band_y: float = bot_y - u * 0.16
	canvas.draw_line(Vector2(c.x - cw * 0.96, band_y), Vector2(c.x + cw * 0.96, band_y), COL_ATOMIC_RED, thin * 1.4)
	canvas.draw_line(Vector2(c.x - cw, mid_y), Vector2(c.x + cw, mid_y), COL_INK, thin)

	# Faux typography bars on upper red & lower cream bands
	canvas.draw_line(Vector2(c.x - cw * 0.52, top_y + u * 0.28), Vector2(c.x + cw * 0.52, top_y + u * 0.28), COL_CREAM, thin * 1.35)
	canvas.draw_line(Vector2(c.x - cw * 0.42, bot_y - u * 0.29), Vector2(c.x + cw * 0.42, bot_y - u * 0.29), COL_INK, thin)

	# Gold CONELRAD / Campbell medallion seal straddling the seam
	var med_c := Vector2(c.x, mid_y)
	var med_r: float = u * 0.22
	canvas.draw_circle(med_c, med_r + thin * 0.8, COL_INK)
	canvas.draw_circle(med_c, med_r, COL_HAZARD_YELLOW)
	canvas.draw_circle(med_c, med_r * 0.72, COL_HAZARD_GOLD)
	var cd_tri := PackedVector2Array([
		med_c + Vector2(0.0, -med_r * 0.54),
		med_c + Vector2(med_r * 0.48, med_r * 0.34),
		med_c + Vector2(-med_r * 0.48, med_r * 0.34)
	])
	_poly(canvas, cd_tri, COL_CREAM)

	# Outer ink walls of tin body
	canvas.draw_line(Vector2(c.x - cw, top_y), Vector2(c.x - cw, bot_y), COL_INK, ol)
	canvas.draw_line(Vector2(c.x + cw, top_y), Vector2(c.x + cw, bot_y), COL_INK, ol)

	# Top steel lid with concentric rim highlight
	_poly(canvas, _ellipse_pts(Vector2(c.x, top_y), cw * 1.04, rim_ry, 0.0, 16), COL_STEEL_LIGHT, COL_INK, ol)
	_poly(canvas, _ellipse_pts(Vector2(c.x, top_y), cw * 0.78, rim_ry * 0.66, 0.0, 14), COL_STEEL, COL_INK, thin * 0.85)
	canvas.draw_arc(Vector2(c.x, top_y), cw * 0.46, PI * 0.15, PI * 0.85, 8, COL_STEEL_LIGHT, thin)


# ---------------------------------------------------------------------------
# 2. WATER — Clear/Cyan Ribbed Civil Defense Water Bottle with Droplet Emblem
# ---------------------------------------------------------------------------

static func _draw_water(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var bw: float = u * 0.52
	var nw: float = u * 0.22
	var cap_top: float = c.y - u * 0.80
	var neck_top: float = c.y - u * 0.62
	var sh_y: float = c.y - u * 0.40
	var bot_y: float = c.y + u * 0.74

	# Bottle outer plastic silhouette (pale clear-cyan tint)
	var body_pts := PackedVector2Array([
		Vector2(c.x - nw, neck_top),
		Vector2(c.x + nw, neck_top),
		Vector2(c.x + bw, sh_y),
		Vector2(c.x + bw, bot_y - u * 0.10),
		Vector2(c.x + bw * 0.82, bot_y),
		Vector2(c.x - bw * 0.82, bot_y),
		Vector2(c.x - bw, bot_y - u * 0.10),
		Vector2(c.x - bw, sh_y)
	])
	_poly(canvas, body_pts, Color("#d4f1fc"))

	# Liquid water fill (~75% up to shoulder)
	var wl_y: float = c.y - u * 0.24
	var water_pts := PackedVector2Array([
		Vector2(c.x - bw * 0.92, wl_y),
		Vector2(c.x + bw * 0.92, wl_y),
		Vector2(c.x + bw * 0.92, bot_y - u * 0.10),
		Vector2(c.x + bw * 0.76, bot_y - u * 0.04),
		Vector2(c.x - bw * 0.76, bot_y - u * 0.04),
		Vector2(c.x - bw * 0.92, bot_y - u * 0.10)
	])
	_poly(canvas, water_pts, COL_WATER_BLUE)
	# Bright upper liquid meniscus ellipse
	_poly(canvas, _ellipse_pts(Vector2(c.x, wl_y), bw * 0.90, u * 0.08, 0.0, 12), COL_WATER_LIGHT)

	# Horizontal molded Civil Defense ribs
	for rib_frac in [-0.10, 0.42, 0.58]:
		var ry_pos: float = c.y + u * float(rib_frac)
		canvas.draw_line(Vector2(c.x - bw * 0.94, ry_pos), Vector2(c.x + bw * 0.94, ry_pos), Color(0.10, 0.32, 0.50, 0.45), thin)

	# White parchment Civil Defense label band across middle
	var lbl_rect := Rect2(c.x - bw * 0.98, c.y - u * 0.04, bw * 1.96, u * 0.40)
	canvas.draw_rect(lbl_rect, COL_CREAM, true)
	canvas.draw_line(lbl_rect.position, Vector2(lbl_rect.end.x, lbl_rect.position.y), COL_INK, thin)
	canvas.draw_line(Vector2(lbl_rect.position.x, lbl_rect.end.y), lbl_rect.end, COL_INK, thin)

	# Bold cyan-blue Water Droplet emblem on the label
	var dc := Vector2(c.x, c.y + u * 0.19)
	var dr: float = u * 0.11
	canvas.draw_circle(dc, dr, Color("#1b6ca8"))
	var drop_tip := PackedVector2Array([
		dc + Vector2(0.0, -dr * 1.65),
		dc + Vector2(dr * 0.92, -dr * 0.25),
		dc + Vector2(-dr * 0.92, -dr * 0.25)
	])
	_poly(canvas, drop_tip, Color("#1b6ca8"))
	canvas.draw_circle(dc + Vector2(-dr * 0.30, -dr * 0.15), maxf(dr * 0.26, 1.0), Color("#d8f6ff"))

	# Vertical clear glass reflection streak on left
	canvas.draw_line(
		Vector2(c.x - bw * 0.66, sh_y + u * 0.06),
		Vector2(c.x - bw * 0.66, bot_y - u * 0.16),
		Color(1.0, 1.0, 1.0, 0.65),
		thin * 1.4
	)

	# Crisp bottle ink outline
	_poly(canvas, body_pts, Color(0, 0, 0, 0), COL_INK, ol)

	# Royal-blue ribbed screw cap
	var cap_rect := Rect2(c.x - nw * 1.18, cap_top, nw * 2.36, neck_top - cap_top + u * 0.04)
	_poly(canvas, _round_rect_pts(cap_rect, u * 0.05, 2), Color("#1e5ca6"), COL_INK, ol)
	canvas.draw_line(
		Vector2(cap_rect.position.x + u * 0.06, cap_rect.position.y + cap_rect.size.y * 0.5),
		Vector2(cap_rect.end.x - u * 0.06, cap_rect.position.y + cap_rect.size.y * 0.5),
		Color("#5fa4eb"),
		thin
	)


# ---------------------------------------------------------------------------
# 3. MEDKIT — White Metal Case with Handle, Latches & Crisp Red Cross
# ---------------------------------------------------------------------------

static func _draw_medkit(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var box_w: float = u * 1.52
	var box_h: float = u * 1.14
	var box_rect := Rect2(c.x - box_w * 0.5, c.y - box_h * 0.42, box_w, box_h)

	# Carrying U-handle on top
	var hw: float = u * 0.52
	var hh: float = u * 0.24
	var h_rect := Rect2(c.x - hw * 0.5, box_rect.position.y - hh, hw, hh + u * 0.06)
	canvas.draw_rect(h_rect, COL_INK, false, ol * 1.15)
	canvas.draw_line(
		Vector2(h_rect.position.x + u * 0.05, h_rect.position.y + ol * 0.4),
		Vector2(h_rect.end.x - u * 0.05, h_rect.position.y + ol * 0.4),
		COL_STEEL_LIGHT,
		thin
	)

	# Enameled white steel body + warm shaded lower lip
	var body_pts: PackedVector2Array = _round_rect_pts(box_rect, u * 0.14, 3)
	_poly(canvas, body_pts, COL_CREAM)
	var shade_rect := Rect2(box_rect.position.x + ol * 0.5, box_rect.end.y - box_h * 0.22, box_w - ol, box_h * 0.19)
	canvas.draw_rect(shade_rect, Color("#ded2ba"), true)

	# Upper lid seam line + twin silver snap latches
	var lid_y: float = box_rect.position.y + box_h * 0.20
	canvas.draw_line(Vector2(box_rect.position.x, lid_y), Vector2(box_rect.end.x, lid_y), COL_INK, thin)
	for side in [-1.0, 1.0]:
		var lx: float = c.x + float(side) * box_w * 0.27
		var l_rect := Rect2(lx - u * 0.08, lid_y - u * 0.07, u * 0.16, u * 0.15)
		canvas.draw_rect(l_rect, COL_STEEL_LIGHT, true)
		canvas.draw_rect(l_rect, COL_INK, false, thin)

	# Crisp Red Medical Cross centered on lower panel
	var cc := Vector2(c.x, box_rect.position.y + box_h * 0.58)
	var arm_l: float = u * 0.34
	var arm_t: float = u * 0.13
	# Dark outline backing for cross
	canvas.draw_rect(Rect2(cc.x - arm_t - thin * 0.7, cc.y - arm_l - thin * 0.7, (arm_t + thin * 0.7) * 2.0, (arm_l + thin * 0.7) * 2.0), COL_INK, true)
	canvas.draw_rect(Rect2(cc.x - arm_l - thin * 0.7, cc.y - arm_t - thin * 0.7, (arm_l + thin * 0.7) * 2.0, (arm_t + thin * 0.7) * 2.0), COL_INK, true)
	# Vivid medical red cross
	var med_red := Color("#d93426")
	canvas.draw_rect(Rect2(cc.x - arm_t, cc.y - arm_l, arm_t * 2.0, arm_l * 2.0), med_red, true)
	canvas.draw_rect(Rect2(cc.x - arm_l, cc.y - arm_t, arm_l * 2.0, arm_t * 2.0), med_red, true)

	# Outer steel case outline
	_poly(canvas, body_pts, Color(0, 0, 0, 0), COL_INK, ol)


# ---------------------------------------------------------------------------
# 4. GAS MASK — Olive Rubber Mask, Twin Glass Eyepieces & Dual Cheek Filters
# ---------------------------------------------------------------------------

static func _draw_gas_mask(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# Elastic head straps peeking top-left and top-right
	canvas.draw_line(c + Vector2(-u * 0.45, -u * 0.52), c + Vector2(-u * 0.72, -u * 0.70), COL_OLIVE_DARK, ol * 1.1)
	canvas.draw_line(c + Vector2(u * 0.45, -u * 0.52), c + Vector2(u * 0.72, -u * 0.70), COL_OLIVE_DARK, ol * 1.1)

	# Dual angled cheek canister filters (left and right)
	for side in [-1.0, 1.0]:
		var sgn: float = float(side)
		var fc: Vector2 = c + Vector2(sgn * u * 0.54, u * 0.34)
		var fang: float = sgn * 0.52
		var can_pts: PackedVector2Array = _rot_rect_pts(fc, Vector2(u * 0.25, u * 0.20), fang)
		_poly(canvas, can_pts, COL_OLIVE_DARK, COL_INK, ol)
		# Hazard-yellow filter warning stripe
		var band_pts: PackedVector2Array = _rot_rect_pts(fc + Vector2(sgn * u * 0.05, u * 0.04), Vector2(u * 0.06, u * 0.18), fang)
		_poly(canvas, band_pts, COL_HAZARD_YELLOW)

	# Molded olive-drab rubber facepiece
	var mask_pts := PackedVector2Array([
		c + Vector2(-u * 0.42, -u * 0.66),
		c + Vector2(0.0, -u * 0.76),
		c + Vector2(u * 0.42, -u * 0.66),
		c + Vector2(u * 0.62, -u * 0.22),
		c + Vector2(u * 0.48, u * 0.30),
		c + Vector2(u * 0.24, u * 0.72),
		c + Vector2(-u * 0.24, u * 0.72),
		c + Vector2(-u * 0.48, u * 0.30),
		c + Vector2(-u * 0.62, -u * 0.22)
	])
	_poly(canvas, mask_pts, COL_OLIVE, COL_INK, ol)

	# Forehead rubber highlight crest
	_poly(canvas, _ellipse_pts(c + Vector2(0.0, -u * 0.52), u * 0.28, u * 0.10, 0.0, 10), Color("#788f56"))

	# Twin circular glass eyepieces with steel rims & reflections
	for side in [-1.0, 1.0]:
		var ec: Vector2 = c + Vector2(float(side) * u * 0.27, -u * 0.16)
		var er: float = u * 0.22
		canvas.draw_circle(ec, er + thin * 0.9, COL_INK)
		canvas.draw_circle(ec, er, COL_STEEL)
		canvas.draw_circle(ec, er * 0.76, Color("#2b5669"))
		canvas.draw_circle(ec + Vector2(-er * 0.16, -er * 0.16), er * 0.42, Color("#6fc2de"))
		canvas.draw_line(ec + Vector2(-er * 0.38, -er * 0.10), ec + Vector2(-er * 0.05, -er * 0.42), Color.WHITE, thin)

	# Central snout exhale valve grille
	var vc: Vector2 = c + Vector2(0.0, u * 0.36)
	var vr: float = u * 0.23
	canvas.draw_circle(vc, vr + thin * 0.8, COL_INK)
	canvas.draw_circle(vc, vr, COL_STEEL_DARK)
	canvas.draw_circle(vc, vr * 0.78, Color("#2a3028"))
	for slot_y in [-0.42, 0.0, 0.42]:
		var sy: float = vc.y + vr * float(slot_y)
		canvas.draw_line(Vector2(vc.x - vr * 0.52, sy), Vector2(vc.x + vr * 0.52, sy), COL_STEEL, thin)


# ---------------------------------------------------------------------------
# 5. RADIO — 1950s Walnut/Brass Tube Radio with Dial, Grille & Antenna
# ---------------------------------------------------------------------------

static func _draw_radio(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var cab_w: float = u * 1.56
	var cab_h: float = u * 1.04
	var cab_rect := Rect2(c.x - cab_w * 0.5, c.y - cab_h * 0.28, cab_w, cab_h)

	# Telescoping chrome whip antenna rising diagonally from top-right
	var ant_base := Vector2(cab_rect.end.x - u * 0.24, cab_rect.position.y + u * 0.02)
	var ant_tip := Vector2(c.x - u * 0.22, c.y - u * 0.82)
	canvas.draw_line(ant_base, ant_tip, COL_INK, ol * 1.35)
	canvas.draw_line(ant_base, ant_tip, COL_STEEL_LIGHT, thin * 1.2)
	canvas.draw_circle(ant_tip, maxf(u * 0.08, 1.5), COL_INK)
	canvas.draw_circle(ant_tip, maxf(u * 0.055, 1.0), COL_ATOMIC_RED)

	# Little wooden feet at bottom
	for fx in [-0.52, 0.52]:
		canvas.draw_rect(Rect2(c.x + cab_w * float(fx) * 0.5 - u * 0.10, cab_rect.end.y - u * 0.02, u * 0.20, u * 0.10), COL_INK, true)

	# Rounded mid-century walnut wood cabinet
	var outer_pts: PackedVector2Array = _round_rect_pts(cab_rect, u * 0.16, 3)
	_poly(canvas, outer_pts, COL_WALNUT, COL_INK, ol)

	# Warm lighter inner walnut faceplate
	var inner_rect: Rect2 = cab_rect.grow(-u * 0.10)
	_poly(canvas, _round_rect_pts(inner_rect, u * 0.10, 2), COL_WALNUT_LIGHT, COL_INK, thin)

	# Left speaker grille (woven cream cloth + brass horizontal louvers)
	var gr_rect := Rect2(inner_rect.position.x + u * 0.08, inner_rect.position.y + u * 0.08, inner_rect.size.x * 0.48, inner_rect.size.y - u * 0.16)
	_poly(canvas, _round_rect_pts(gr_rect, u * 0.07, 2), Color("#ead8b3"), COL_INK, thin)
	for li in range(4):
		var ly: float = gr_rect.position.y + gr_rect.size.y * (0.22 + float(li) * 0.19)
		canvas.draw_line(Vector2(gr_rect.position.x + u * 0.06, ly), Vector2(gr_rect.end.x - u * 0.06, ly), COL_HAZARD_GOLD, thin)

	# Right illuminated CONELRAD tube tuning dial
	var dial_cx: float = inner_rect.position.x + inner_rect.size.x * 0.77
	var dial_cy: float = inner_rect.position.y + inner_rect.size.y * 0.36
	var dial_r: float = u * 0.23
	canvas.draw_circle(Vector2(dial_cx, dial_cy), dial_r + thin * 0.8, COL_INK)
	canvas.draw_circle(Vector2(dial_cx, dial_cy), dial_r, COL_HAZARD_YELLOW)
	canvas.draw_circle(Vector2(dial_cx, dial_cy), dial_r * 0.72, Color("#fff0a8"))
	# Red tuning needle + scale ticks
	canvas.draw_line(Vector2(dial_cx, dial_cy + dial_r * 0.25), Vector2(dial_cx + dial_r * 0.45, dial_cy - dial_r * 0.52), COL_ATOMIC_RED, thin * 1.2)

	# Twin brass rotary knobs below dial
	for kside in [-1.0, 1.0]:
		var kc := Vector2(dial_cx + float(kside) * u * 0.15, inner_rect.end.y - u * 0.17)
		canvas.draw_circle(kc, maxf(u * 0.09, 1.4), COL_INK)
		canvas.draw_circle(kc, maxf(u * 0.065, 1.0), COL_HAZARD_YELLOW)


# ---------------------------------------------------------------------------
# 6. FLASHLIGHT — Chrome & Hazard-Yellow Angled Torch with Lens Glow
# ---------------------------------------------------------------------------

static func _draw_flashlight(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var ang: float = -PI * 0.25
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)

	# Warm golden lens beam cone radiating toward upper-right
	var head_c: Vector2 = c + dir * (u * 0.26) + Vector2(-u * 0.06, u * 0.06)
	var beam_outer := PackedVector2Array([
		head_c - perp * (u * 0.24),
		head_c + dir * (u * 0.64) - perp * (u * 0.56),
		head_c + dir * (u * 0.64) + perp * (u * 0.56),
		head_c + perp * (u * 0.24)
	])
	_poly(canvas, beam_outer, Color(0.98, 0.84, 0.30, 0.32))
	var beam_inner := PackedVector2Array([
		head_c - perp * (u * 0.14),
		head_c + dir * (u * 0.52) - perp * (u * 0.30),
		head_c + dir * (u * 0.52) + perp * (u * 0.30),
		head_c + perp * (u * 0.14)
	])
	_poly(canvas, beam_inner, Color(1.0, 0.96, 0.68, 0.52))

	# Torch center shifted slightly down-left so beam + handle stay centered
	var body_c: Vector2 = c - dir * (u * 0.20) + Vector2(-u * 0.06, u * 0.06)

	# Chrome tailcap at bottom-left
	var tail_c: Vector2 = body_c - dir * (u * 0.42)
	_poly(canvas, _rot_rect_pts(tail_c, Vector2(u * 0.10, u * 0.18), ang), COL_STEEL, COL_INK, ol)

	# Ribbed hazard-yellow cylindrical barrel
	_poly(canvas, _rot_rect_pts(body_c, Vector2(u * 0.36, u * 0.18), ang), COL_HAZARD_YELLOW, COL_INK, ol)
	# Barrel highlight & grip ribs
	var hi_a: Vector2 = body_c - dir * (u * 0.28) - perp * (u * 0.09)
	var hi_b: Vector2 = body_c + dir * (u * 0.26) - perp * (u * 0.09)
	canvas.draw_line(hi_a, hi_b, Color("#fff0a0"), thin * 1.3)
	# Dark slide switch on top edge
	var sw_c: Vector2 = body_c + dir * (u * 0.04) - perp * (u * 0.20)
	_poly(canvas, _rot_rect_pts(sw_c, Vector2(u * 0.10, u * 0.05), ang), COL_INK)

	# Flared chrome reflector head
	var bell_a: Vector2 = body_c + dir * (u * 0.34)
	var bell_b: Vector2 = body_c + dir * (u * 0.56)
	var bell_pts := PackedVector2Array([
		bell_a - perp * (u * 0.19),
		bell_b - perp * (u * 0.30),
		bell_b + perp * (u * 0.30),
		bell_a + perp * (u * 0.19)
	])
	_poly(canvas, bell_pts, COL_STEEL_LIGHT, COL_INK, ol)

	# Glowing pale-yellow glass lens ellipse
	_poly(canvas, _ellipse_pts(bell_b, u * 0.09, u * 0.27, ang, 12), Color("#fff9bd"), COL_INK, thin)


# ---------------------------------------------------------------------------
# 7. MAP — Folded 3-Panel Parchment Street Map with Red Route & X Pin
# ---------------------------------------------------------------------------

static func _draw_map(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var pw: float = u * 0.50
	var ph: float = u * 1.24
	var skew: float = u * 0.14
	var x0: float = c.x - pw * 1.5
	var x1: float = c.x - pw * 0.5
	var x2: float = c.x + pw * 0.5
	var x3: float = c.x + pw * 1.5
	var yt: float = c.y - ph * 0.48
	var yb: float = c.y + ph * 0.48

	var p_left := PackedVector2Array([
		Vector2(x0, yt + skew),
		Vector2(x1, yt - skew),
		Vector2(x1, yb - skew),
		Vector2(x0, yb + skew)
	])
	var p_mid := PackedVector2Array([
		Vector2(x1, yt - skew),
		Vector2(x2, yt + skew),
		Vector2(x2, yb + skew),
		Vector2(x1, yb - skew)
	])
	var p_right := PackedVector2Array([
		Vector2(x2, yt + skew),
		Vector2(x3, yt - skew),
		Vector2(x3, yb - skew),
		Vector2(x2, yb + skew)
	])

	_poly(canvas, p_left, COL_PARCHMENT)
	_poly(canvas, p_mid, COL_PARCHMENT_DARK)
	_poly(canvas, p_right, COL_PARCHMENT)

	# Cyan waterway & street grid lines across map folds
	var river := PackedVector2Array([
		Vector2(x0 + pw * 0.18, yt + ph * 0.26),
		Vector2(x1 + pw * 0.35, c.y + u * 0.08),
		Vector2(x3 - pw * 0.16, yb - ph * 0.22)
	])
	canvas.draw_polyline(river, Color("#73b4cf"), thin * 1.6)
	canvas.draw_line(Vector2(x0 + u * 0.08, c.y - u * 0.18), Vector2(x3 - u * 0.08, c.y - u * 0.24), Color("#b59f76"), thin)
	canvas.draw_line(Vector2(x0 + u * 0.08, c.y + u * 0.26), Vector2(x3 - u * 0.08, c.y + u * 0.20), Color("#b59f76"), thin)

	# Winding Atomic Red route line from start dot to X destination
	var start_pt := Vector2(x0 + pw * 0.45, yb - ph * 0.24)
	var mid_pt1 := Vector2(x1 + pw * 0.32, c.y + u * 0.04)
	var mid_pt2 := Vector2(x1 + pw * 0.78, c.y - u * 0.20)
	var dest_pt := Vector2(x2 + pw * 0.54, yt + ph * 0.28)
	canvas.draw_polyline(PackedVector2Array([start_pt, mid_pt1, mid_pt2, dest_pt]), COL_ATOMIC_RED, thin * 1.45)
	canvas.draw_circle(start_pt, maxf(u * 0.07, 1.3), COL_ATOMIC_RED)

	# Bold Red X + pinhead at destination
	var xr: float = u * 0.13
	canvas.draw_line(dest_pt + Vector2(-xr, -xr), dest_pt + Vector2(xr, xr), COL_INK, ol)
	canvas.draw_line(dest_pt + Vector2(xr, -xr), dest_pt + Vector2(-xr, xr), COL_INK, ol)
	canvas.draw_line(dest_pt + Vector2(-xr, -xr), dest_pt + Vector2(xr, xr), COL_ATOMIC_RED, thin * 1.3)
	canvas.draw_line(dest_pt + Vector2(xr, -xr), dest_pt + Vector2(-xr, xr), COL_ATOMIC_RED, thin * 1.3)

	# Fold crease lines and outer map border
	canvas.draw_line(Vector2(x1, yt - skew), Vector2(x1, yb - skew), Color(0.12, 0.10, 0.08, 0.55), thin)
	canvas.draw_line(Vector2(x2, yt + skew), Vector2(x2, yb + skew), Color(0.12, 0.10, 0.08, 0.55), thin)
	var outer_map := PackedVector2Array([
		Vector2(x0, yt + skew),
		Vector2(x1, yt - skew),
		Vector2(x2, yt + skew),
		Vector2(x3, yt - skew),
		Vector2(x3, yb - skew),
		Vector2(x2, yb + skew),
		Vector2(x1, yb - skew),
		Vector2(x0, yb + skew)
	])
	_poly(canvas, outer_map, Color(0, 0, 0, 0), COL_INK, ol)


# ---------------------------------------------------------------------------
# 8. BOOK — Green/Tan Boy Scout Handbook with Fleur-de-Lis / Compass Emblem
# ---------------------------------------------------------------------------

static func _draw_book(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var bw: float = u * 1.18
	var bh: float = u * 1.44
	var x0: float = c.x - bw * 0.52
	var y0: float = c.y - bh * 0.52
	var off := Vector2(u * 0.12, u * 0.10)

	# Cream page block visible along right & bottom edges
	var pages_pts := PackedVector2Array([
		Vector2(x0 + off.x, y0 + off.y),
		Vector2(x0 + bw + off.x, y0 + off.y),
		Vector2(x0 + bw + off.x, y0 + bh + off.y),
		Vector2(x0 + off.x, y0 + bh + off.y)
	])
	_poly(canvas, pages_pts, COL_CREAM, COL_INK, ol)

	# Forest-olive front hardcover
	var cov_rect := Rect2(x0, y0, bw, bh)
	_poly(canvas, _round_rect_pts(cov_rect, u * 0.08, 2), Color("#4c7840"), COL_INK, ol)

	# Tan bound book spine along left edge
	var sp_w: float = bw * 0.22
	var sp_rect := Rect2(x0, y0, sp_w, bh)
	canvas.draw_rect(sp_rect, Color("#9e6b3b"), true)
	canvas.draw_rect(sp_rect, COL_INK, false, ol)
	for ry in [0.20, 0.50, 0.80]:
		var sy: float = y0 + bh * float(ry)
		canvas.draw_line(Vector2(x0 + thin, sy), Vector2(x0 + sp_w - thin, sy), COL_INK, thin)

	# Gold inset border frame on cover
	var face_cx: float = x0 + sp_w + (bw - sp_w) * 0.5
	var frame_rect := Rect2(x0 + sp_w + u * 0.10, y0 + u * 0.14, bw - sp_w - u * 0.20, bh - u * 0.28)
	canvas.draw_rect(frame_rect, COL_HAZARD_YELLOW, false, thin)

	# Golden Fleur-de-Lis / Compass emblem centered on cover
	var ec := Vector2(face_cx, c.y - u * 0.04)
	var er: float = u * 0.26
	canvas.draw_circle(ec, er, Color(0.18, 0.30, 0.15, 0.55))
	canvas.draw_arc(ec, er, 0.0, TAU, 16, COL_HAZARD_YELLOW, thin)
	# Central diamond spear petal
	var spear := PackedVector2Array([
		ec + Vector2(0.0, -er * 0.95),
		ec + Vector2(er * 0.28, 0.0),
		ec + Vector2(0.0, er * 0.82),
		ec + Vector2(-er * 0.28, 0.0)
	])
	_poly(canvas, spear, COL_HAZARD_YELLOW)
	# Side fleur-de-lis petals + horizontal tie bar
	for sgn in [-1.0, 1.0]:
		var fs: float = float(sgn)
		var petal := PackedVector2Array([
			ec + Vector2(fs * er * 0.15, er * 0.15),
			ec + Vector2(fs * er * 0.78, -er * 0.32),
			ec + Vector2(fs * er * 0.65, er * 0.22)
		])
		_poly(canvas, petal, COL_HAZARD_YELLOW)
	canvas.draw_line(ec + Vector2(-er * 0.52, er * 0.22), ec + Vector2(er * 0.52, er * 0.22), COL_CREAM, thin * 1.1)


# ---------------------------------------------------------------------------
# 9. AXE — Red Fireman's Axe Head with Curved Wooden Handle & Steel Glint
# ---------------------------------------------------------------------------

static func _draw_axe(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# Curved hickory wooden handle running bottom-left to top-right
	var h_pts := PackedVector2Array([
		c + Vector2(-u * 0.74, u * 0.64),
		c + Vector2(-u * 0.22, u * 0.14),
		c + Vector2(u * 0.36, -u * 0.68),
		c + Vector2(u * 0.50, -u * 0.56),
		c + Vector2(-u * 0.06, u * 0.26),
		c + Vector2(-u * 0.58, u * 0.78)
	])
	_poly(canvas, h_pts, COL_WALNUT_LIGHT, COL_INK, ol)
	canvas.draw_line(c + Vector2(-u * 0.64, u * 0.68), c + Vector2(u * 0.38, -u * 0.58), Color("#d99c62"), thin)

	# Fireman's Red axe head with rear pick spike & flared forward blade
	var head_pts := PackedVector2Array([
		c + Vector2(u * 0.02, -u * 0.76),
		c + Vector2(u * 0.32, -u * 0.56),
		c + Vector2(u * 0.80, -u * 0.42),
		c + Vector2(u * 0.66, u * 0.18),
		c + Vector2(u * 0.16, -u * 0.24),
		c + Vector2(-u * 0.14, -u * 0.52)
	])
	_poly(canvas, head_pts, COL_ATOMIC_RED, COL_INK, ol)

	# Polished steel cutting edge bevel + white edge glint
	var edge_pts := PackedVector2Array([
		c + Vector2(u * 0.64, -u * 0.46),
		c + Vector2(u * 0.80, -u * 0.42),
		c + Vector2(u * 0.66, u * 0.18),
		c + Vector2(u * 0.50, u * 0.06)
	])
	_poly(canvas, edge_pts, COL_STEEL_LIGHT, COL_INK, thin)
	canvas.draw_line(c + Vector2(u * 0.74, -u * 0.36), c + Vector2(u * 0.63, u * 0.08), Color.WHITE, thin * 1.2)


# ---------------------------------------------------------------------------
# 10. RIFLE — Classic Wooden-Stock Hunting Rifle with Steel Barrel & Sight
# ---------------------------------------------------------------------------

static func _draw_rifle(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# Trigger guard loop under receiver
	canvas.draw_arc(c + Vector2(-u * 0.04, u * 0.20), u * 0.14, -0.1, PI + 0.1, 8, COL_INK, ol)

	# Blued-steel barrel extending cleanly to upper-right + front blade sight
	var b_start: Vector2 = c + Vector2(-u * 0.12, u * 0.02)
	var b_end: Vector2 = c + Vector2(u * 0.80, -u * 0.74)
	canvas.draw_line(b_start, b_end, COL_INK, ol * 2.55)
	canvas.draw_line(b_start, b_end, Color("#606f7c"), ol * 1.45)
	canvas.draw_line(b_start + Vector2(-u * 0.02, -u * 0.03), b_end + Vector2(-u * 0.02, -u * 0.03), COL_STEEL_LIGHT, thin)
	# Front sight post near muzzle & rear notch sight
	var sight_base: Vector2 = b_end + Vector2(-u * 0.08, u * 0.07)
	canvas.draw_line(sight_base, sight_base + Vector2(-u * 0.08, -u * 0.12), COL_INK, ol)
	canvas.draw_line(c + Vector2(u * 0.18, -u * 0.24), c + Vector2(u * 0.12, -u * 0.35), COL_INK, ol)

	# Classic carved walnut buttstock, pistol grip & forend
	var stock_pts := PackedVector2Array([
		c + Vector2(-u * 0.84, u * 0.44),
		c + Vector2(-u * 0.34, u * 0.12),
		c + Vector2(u * 0.34, -u * 0.36),
		c + Vector2(u * 0.42, -u * 0.22),
		c + Vector2(-u * 0.08, u * 0.22),
		c + Vector2(-u * 0.16, u * 0.40),
		c + Vector2(-u * 0.56, u * 0.80)
	])
	_poly(canvas, stock_pts, COL_WALNUT, COL_INK, ol)
	canvas.draw_line(c + Vector2(-u * 0.70, u * 0.50), c + Vector2(u * 0.24, -u * 0.22), COL_WALNUT_LIGHT, thin * 1.15)

	# Dark rubber buttpad + silver bolt-action receiver & handle knob
	canvas.draw_line(c + Vector2(-u * 0.84, u * 0.44), c + Vector2(-u * 0.56, u * 0.80), COL_INK, ol * 1.6)
	var bolt_a: Vector2 = c + Vector2(-u * 0.06, u * 0.01)
	var bolt_b: Vector2 = c + Vector2(u * 0.07, u * 0.16)
	canvas.draw_line(bolt_a, bolt_b, COL_STEEL_LIGHT, thin * 1.35)
	canvas.draw_circle(bolt_b, maxf(u * 0.07, 1.3), COL_INK)
	canvas.draw_circle(bolt_b, maxf(u * 0.048, 0.9), COL_STEEL_LIGHT)


# ---------------------------------------------------------------------------
# 11. AMMO — Brass-Tipped Cartridges Peeking from Olive Ammo Box
# ---------------------------------------------------------------------------

static func _draw_ammo(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# Three gleaming brass cartridges standing out of the top of the box
	var cw: float = u * 0.24
	for idx in [-1, 0, 1]:
		var cx: float = c.x + float(idx) * (cw * 1.38)
		var tip_y: float = c.y - u * 0.78 + absf(float(idx)) * u * 0.05
		var neck_y: float = tip_y + u * 0.30
		var base_y: float = c.y + u * 0.08

		# Pointed copper bullet tip
		var tip_pts := PackedVector2Array([
			Vector2(cx, tip_y),
			Vector2(cx + cw * 0.44, neck_y),
			Vector2(cx - cw * 0.44, neck_y)
		])
		_poly(canvas, tip_pts, Color("#cc6533"), COL_INK, ol * 0.9)

		# Gleaming brass casing
		var case_rect := Rect2(cx - cw * 0.5, neck_y, cw, base_y - neck_y)
		canvas.draw_rect(case_rect, COL_HAZARD_YELLOW, true)
		canvas.draw_line(Vector2(cx - cw * 0.22, neck_y + thin), Vector2(cx - cw * 0.22, base_y), Color("#fff4b3"), thin)
		canvas.draw_rect(case_rect, COL_INK, false, ol * 0.9)

	# Olive-drab steel/cardboard ammunition box in foreground
	var box_rect := Rect2(c.x - u * 0.68, c.y - u * 0.06, u * 1.36, u * 0.80)
	_poly(canvas, _round_rect_pts(box_rect, u * 0.08, 2), COL_OLIVE, COL_INK, ol)

	# Darker top rim shadow + hazard-yellow military stencil band
	canvas.draw_rect(Rect2(box_rect.position.x + ol * 0.5, box_rect.position.y + ol * 0.5, box_rect.size.x - ol, u * 0.14), COL_OLIVE_DARK, true)
	var st_y: float = box_rect.position.y + box_rect.size.y * 0.52
	canvas.draw_rect(Rect2(box_rect.position.x + u * 0.12, st_y - u * 0.10, box_rect.size.x - u * 0.24, u * 0.22), COL_HAZARD_YELLOW, true)
	canvas.draw_line(Vector2(c.x - u * 0.36, st_y), Vector2(c.x + u * 0.36, st_y), COL_INK, thin * 1.3)


# ---------------------------------------------------------------------------
# 12. BUG SPRAY — Toxic Green/Yellow Aerosol Can with Roach Silhouette & Nozzle
# ---------------------------------------------------------------------------

static func _draw_bug_spray(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var cw: float = u * 0.44
	var cx: float = c.x - u * 0.06
	var sh_y: float = c.y - u * 0.38
	var bot_y: float = c.y + u * 0.74

	# Aerosol mist puffs spraying right from nozzle (outlined so visible on light & dark BG)
	var mist_o := Vector2(cx + u * 0.24, c.y - u * 0.65)
	for mi in range(3):
		var mp: Vector2 = mist_o + Vector2(float(mi) * u * 0.16, (float(mi) - 1.0) * u * 0.09)
		canvas.draw_circle(mp, maxf(u * 0.06, 1.3), COL_OLIVE_DARK)
		canvas.draw_circle(mp, maxf(u * 0.04, 0.9), Color("#9ef065"))

	# Spray nozzle button + metallic domed shoulder flush with can top
	var noz_rect := Rect2(cx - u * 0.14, c.y - u * 0.76, u * 0.28, u * 0.24)
	canvas.draw_rect(noz_rect, COL_CREAM, true)
	canvas.draw_rect(noz_rect, COL_INK, false, ol * 0.9)
	canvas.draw_circle(Vector2(noz_rect.end.x - u * 0.03, noz_rect.position.y + noz_rect.size.y * 0.38), maxf(u * 0.04, 1.0), COL_ATOMIC_RED)

	canvas.draw_circle(Vector2(cx, sh_y + u * 0.02), cw * 0.98, COL_STEEL_LIGHT)
	canvas.draw_arc(Vector2(cx, sh_y + u * 0.02), cw * 0.98, PI, TAU, 14, COL_INK, ol)

	# Cylindrical toxic-green aerosol body
	var body_rect := Rect2(cx - cw, sh_y, cw * 2.0, bot_y - sh_y)
	_poly(canvas, _round_rect_pts(body_rect, u * 0.07, 2), COL_TOXIC_GREEN, COL_INK, ol)

	# Bold hazard-yellow center warning label
	var lbl_rect := Rect2(cx - cw + ol * 0.5, c.y - u * 0.14, cw * 2.0 - ol, u * 0.58)
	canvas.draw_rect(lbl_rect, COL_HAZARD_YELLOW, true)
	canvas.draw_line(lbl_rect.position, Vector2(lbl_rect.end.x, lbl_rect.position.y), COL_INK, thin)
	canvas.draw_line(Vector2(lbl_rect.position.x, lbl_rect.end.y), lbl_rect.end, COL_INK, thin)

	# Unmistakable dark Cockroach silhouette on yellow band
	var rc := Vector2(cx, c.y + u * 0.16)
	_poly(canvas, _ellipse_pts(rc, u * 0.13, u * 0.20, 0.0, 10), COL_INK)
	canvas.draw_circle(rc + Vector2(0.0, -u * 0.20), maxf(u * 0.07, 1.1), COL_INK)
	# 6 bent roach legs + 2 curved antennae
	for lside in [-1.0, 1.0]:
		var ls: float = float(lside)
		for ly in [-0.10, 0.02, 0.14]:
			canvas.draw_line(rc + Vector2(ls * u * 0.10, u * float(ly)), rc + Vector2(ls * u * 0.27, u * (float(ly) + 0.06)), COL_INK, thin)
		canvas.draw_line(rc + Vector2(ls * u * 0.04, -u * 0.24), rc + Vector2(ls * u * 0.20, -u * 0.36), COL_INK, thin * 0.9)


# ---------------------------------------------------------------------------
# 13. PADLOCK — Heavy Steel U-Shackle Brass Padlock with Keyhole
# ---------------------------------------------------------------------------

static func _draw_padlock(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var sh_r: float = u * 0.38
	var sh_cy: float = c.y - u * 0.24

	# Hardened steel U-shackle (ink outer stroke + steel core + bright highlight)
	var leg_bot: float = c.y + u * 0.05
	canvas.draw_line(Vector2(c.x - sh_r, sh_cy), Vector2(c.x - sh_r, leg_bot), COL_INK, ol * 3.1)
	canvas.draw_line(Vector2(c.x + sh_r, sh_cy), Vector2(c.x + sh_r, leg_bot), COL_INK, ol * 3.1)
	canvas.draw_arc(Vector2(c.x, sh_cy), sh_r, PI, TAU, 16, COL_INK, ol * 3.1)

	canvas.draw_line(Vector2(c.x - sh_r, sh_cy), Vector2(c.x - sh_r, leg_bot), COL_STEEL, ol * 1.7)
	canvas.draw_line(Vector2(c.x + sh_r, sh_cy), Vector2(c.x + sh_r, leg_bot), COL_STEEL, ol * 1.7)
	canvas.draw_arc(Vector2(c.x, sh_cy), sh_r, PI, TAU, 16, COL_STEEL, ol * 1.7)
	canvas.draw_arc(Vector2(c.x, sh_cy), sh_r, PI * 1.15, PI * 1.75, 10, COL_STEEL_LIGHT, thin)

	# Heavy brass padlock body
	var bw: float = u * 1.18
	var bh: float = u * 0.92
	var b_rect := Rect2(c.x - bw * 0.5, c.y - u * 0.14, bw, bh)
	var body_pts: PackedVector2Array = _round_rect_pts(b_rect, u * 0.14, 3)
	_poly(canvas, body_pts, COL_HAZARD_YELLOW)
	# Brass bevel shading + left highlight
	canvas.draw_rect(Rect2(b_rect.position.x + bw * 0.68, b_rect.position.y + ol, bw * 0.28, bh - ol * 2.0), COL_HAZARD_GOLD, true)
	canvas.draw_rect(Rect2(b_rect.position.x + ol, b_rect.position.y + ol, bw * 0.18, bh - ol * 2.0), Color("#ffe285"), true)
	_poly(canvas, body_pts, Color(0, 0, 0, 0), COL_INK, ol)

	# Four brass corner rivets
	for rx in [-0.36, 0.36]:
		for ry in [0.18, 0.82]:
			var rp := Vector2(c.x + bw * float(rx), b_rect.position.y + bh * float(ry))
			canvas.draw_circle(rp, maxf(u * 0.045, 1.0), COL_INK)

	# Classic central keyhole (circle + downward trapezoid slot)
	var kc := Vector2(c.x, b_rect.position.y + bh * 0.42)
	var kr: float = u * 0.11
	canvas.draw_circle(kc, kr, COL_INK)
	var slot_pts := PackedVector2Array([
		kc + Vector2(-kr * 0.45, 0.0),
		kc + Vector2(kr * 0.45, 0.0),
		kc + Vector2(kr * 0.78, u * 0.28),
		kc + Vector2(-kr * 0.78, u * 0.28)
	])
	_poly(canvas, slot_pts, COL_INK)


# ---------------------------------------------------------------------------
# 14. CARDS — Fanned White Playing Cards with Red Diamond & Black Spade Pips
# ---------------------------------------------------------------------------

static func _draw_cards(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var half_card := Vector2(u * 0.42, u * 0.60)

	# Back-left card (-22 deg) showing Black Spade corner
	var c_left: Vector2 = c + Vector2(-u * 0.26, u * 0.02)
	_poly(canvas, _rot_rect_pts(c_left, half_card, -0.36), COL_CREAM, COL_INK, ol)
	var sp_c: Vector2 = c_left + Vector2(-u * 0.22, -u * 0.24)
	var sp_pts := PackedVector2Array([
		sp_c + Vector2(0.0, -u * 0.15),
		sp_c + Vector2(u * 0.12, u * 0.04),
		sp_c + Vector2(-u * 0.12, u * 0.04)
	])
	_poly(canvas, sp_pts, COL_INK)
	canvas.draw_line(sp_c + Vector2(0.0, u * 0.02), sp_c + Vector2(0.0, u * 0.12), COL_INK, thin * 1.2)

	# Center card (-2 deg) slightly taller
	var c_mid: Vector2 = c + Vector2(-u * 0.02, -u * 0.08)
	_poly(canvas, _rot_rect_pts(c_mid, half_card, -0.04), Color("#f5ebd4"), COL_INK, ol)
	canvas.draw_circle(c_mid + Vector2(-u * 0.24, -u * 0.36), maxf(u * 0.06, 1.0), COL_INK)

	# Front-right card (+18 deg) featuring bold Red Diamond centerpiece + corner pip
	var c_right: Vector2 = c + Vector2(u * 0.24, u * 0.04)
	var ang_r: float = 0.30
	_poly(canvas, _rot_rect_pts(c_right, half_card, ang_r), Color("#fffaf0"), COL_INK, ol)

	var cr: float = cos(ang_r)
	var sr: float = sin(ang_r)
	var dx := Vector2(cr, sr)
	var dy := Vector2(-sr, cr)
	var dm: float = u * 0.24
	var diamond_pts := PackedVector2Array([
		c_right - dy * dm,
		c_right + dx * (dm * 0.72),
		c_right + dy * dm,
		c_right - dx * (dm * 0.72)
	])
	_poly(canvas, diamond_pts, Color("#d93426"))
	# Tiny top-left & bottom-right red corner pips
	canvas.draw_circle(c_right - dx * (u * 0.26) - dy * (u * 0.40), maxf(u * 0.055, 1.0), Color("#d93426"))
	canvas.draw_circle(c_right + dx * (u * 0.26) + dy * (u * 0.40), maxf(u * 0.055, 1.0), Color("#d93426"))


# ---------------------------------------------------------------------------
# 15. CHECKERS — Red-and-Black Checkerboard with Stacked Pieces
# ---------------------------------------------------------------------------

static func _draw_checkers(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var bs: float = u * 1.38
	var b_rect := Rect2(c.x - bs * 0.52, c.y - bs * 0.52, bs, bs)

	# Walnut wooden frame
	_poly(canvas, _round_rect_pts(b_rect, u * 0.10, 2), COL_WALNUT, COL_INK, ol)

	# 4x4 alternating Red and Charcoal checkerboard grid
	var inner: Rect2 = b_rect.grow(-u * 0.12)
	var cell: float = inner.size.x * 0.25
	for r in range(4):
		for col in range(4):
			var sq := Rect2(inner.position.x + float(col) * cell, inner.position.y + float(r) * cell, cell, cell)
			var sq_col: Color = COL_ATOMIC_RED if ((r + col) % 2 == 0) else Color("#242220")
			canvas.draw_rect(sq, sq_col, true)
	canvas.draw_rect(inner, COL_INK, false, thin)

	# Dark checker disc on upper-left square
	var blk_c := Vector2(inner.position.x + cell * 1.5, inner.position.y + cell * 1.5)
	_poly(canvas, _ellipse_pts(blk_c, u * 0.18, u * 0.13, 0.0, 12), Color("#333633"), COL_CREAM, thin * 0.85)

	# Stacked kinged Red checker pucks in foreground bottom-right
	var stack_x: float = c.x + u * 0.34
	var stack_y: float = c.y + u * 0.44
	var prx: float = u * 0.28
	var pry: float = u * 0.17
	for layer in range(2):
		var pc := Vector2(stack_x, stack_y - float(layer) * u * 0.14)
		_poly(canvas, _ellipse_pts(pc + Vector2(0.0, u * 0.06), prx, pry, 0.0, 12), COL_ATOMIC_DARK, COL_INK, ol * 0.9)
		_poly(canvas, _ellipse_pts(pc, prx, pry, 0.0, 12), Color("#e64835"), COL_INK, ol * 0.9)
	# Gold crown ring on top kinged checker
	_poly(canvas, _ellipse_pts(Vector2(stack_x, stack_y - u * 0.14), prx * 0.52, pry * 0.52, 0.0, 10), COL_HAZARD_YELLOW)


# ---------------------------------------------------------------------------
# 16. SUITCASE — Vintage Brown Leather Suitcase with Brass Buckles & Corner Guards
# ---------------------------------------------------------------------------

static func _draw_suitcase(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var sw: float = u * 1.60
	var sh: float = u * 1.12
	var s_rect := Rect2(c.x - sw * 0.5, c.y - sh * 0.40, sw, sh)

	# Arched leather carrying handle on top + brass rings
	var hw: float = u * 0.50
	var hh: float = u * 0.24
	var h_rect := Rect2(c.x - hw * 0.5, s_rect.position.y - hh, hw, hh + u * 0.05)
	canvas.draw_rect(h_rect, COL_WALNUT_DARK, false, ol * 1.3)
	for side in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(c.x + float(side) * hw * 0.5, s_rect.position.y), maxf(u * 0.055, 1.0), COL_HAZARD_YELLOW)

	# Saddle-brown vintage leather case
	var body_pts: PackedVector2Array = _round_rect_pts(s_rect, u * 0.14, 3)
	_poly(canvas, body_pts, COL_WALNUT)
	canvas.draw_rect(Rect2(s_rect.position.x + ol, s_rect.end.y - sh * 0.24, sw - ol * 2.0, sh * 0.20), COL_WALNUT_DARK, true)

	# Small tilted CONELRAD travel sticker patch
	_poly(canvas, _rot_rect_pts(c + Vector2(u * 0.02, -u * 0.06), Vector2(u * 0.15, u * 0.10), -0.22), COL_WATER_BLUE, COL_CREAM, thin * 0.8)

	# Four dark leather/brass corner guards
	var cg: float = u * 0.24
	var corners: Array[Rect2] = [
		Rect2(s_rect.position.x, s_rect.position.y, cg, cg),
		Rect2(s_rect.end.x - cg, s_rect.position.y, cg, cg),
		Rect2(s_rect.position.x, s_rect.end.y - cg, cg, cg),
		Rect2(s_rect.end.x - cg, s_rect.end.y - cg, cg, cg)
	]
	for cr_rect in corners:
		canvas.draw_rect(cr_rect, Color("#4a2711"), true)

	# Twin vertical tan leather straps + gleaming square brass buckles
	for sgn in [-1.0, 1.0]:
		var sx: float = c.x + float(sgn) * sw * 0.27
		var st_rect := Rect2(sx - u * 0.08, s_rect.position.y, u * 0.16, sh)
		canvas.draw_rect(st_rect, Color("#b8743e"), true)
		canvas.draw_rect(st_rect, COL_INK, false, thin)
		var bk_rect := Rect2(sx - u * 0.12, c.y + u * 0.06, u * 0.24, u * 0.20)
		canvas.draw_rect(bk_rect, COL_HAZARD_YELLOW, true)
		canvas.draw_rect(bk_rect, COL_INK, false, thin)

	# Outer ink border
	_poly(canvas, body_pts, Color(0, 0, 0, 0), COL_INK, ol)


# ---------------------------------------------------------------------------
# 17. HARMONICA — Brushed Silver Blues Harmonica with Air Vents
# ---------------------------------------------------------------------------

static func _draw_harmonica(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var ang: float = -0.24
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)
	var hc: Vector2 = c + Vector2(0.0, u * 0.08)

	# Tiny floating musical note above harmonica
	var nc: Vector2 = c + Vector2(u * 0.16, -u * 0.56)
	canvas.draw_circle(nc, maxf(u * 0.075, 1.2), COL_HAZARD_YELLOW)
	canvas.draw_line(nc + Vector2(u * 0.06, 0.0), nc + Vector2(u * 0.06, -u * 0.24), COL_HAZARD_YELLOW, thin * 1.2)
	canvas.draw_line(nc + Vector2(u * 0.06, -u * 0.24), nc + Vector2(u * 0.22, -u * 0.18), COL_HAZARD_YELLOW, thin * 1.2)

	# 3-layer Marine Band harmonica sandwich: bottom chrome lip + center comb vents + top chrome cover
	var bot_plate_c: Vector2 = hc + perp * (u * 0.18)
	_poly(canvas, _rot_rect_pts(bot_plate_c, Vector2(u * 0.74, u * 0.07), ang), COL_STEEL_DARK, COL_INK, ol * 0.9)

	var comb_c: Vector2 = hc + perp * (u * 0.05)
	_poly(canvas, _rot_rect_pts(comb_c, Vector2(u * 0.80, u * 0.13), ang), Color("#9c4427"), COL_INK, ol)
	for vi in range(-3, 4):
		var vc: Vector2 = comb_c + dir * (float(vi) * u * 0.20)
		_poly(canvas, _rot_rect_pts(vc, Vector2(u * 0.058, u * 0.068), ang), COL_INK)

	# Brushed chrome top cover plate with metallic sheen & end screws
	var plate_c: Vector2 = hc - perp * (u * 0.13)
	_poly(canvas, _rot_rect_pts(plate_c, Vector2(u * 0.74, u * 0.14), ang), COL_STEEL, COL_INK, ol)
	_poly(canvas, _rot_rect_pts(plate_c - dir * (u * 0.14), Vector2(u * 0.18, u * 0.11), ang), COL_STEEL_LIGHT)
	for sgn in [-1.0, 1.0]:
		var sc: Vector2 = plate_c + dir * (float(sgn) * u * 0.60)
		canvas.draw_circle(sc, maxf(u * 0.045, 1.0), COL_INK)


# ---------------------------------------------------------------------------
# 18. TOOLBOX — Red Steel Mechanic's Gabled Toolbox with Silver Clasp
# ---------------------------------------------------------------------------

static func _draw_toolbox(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var tw: float = u * 1.56
	var seam_y: float = c.y - u * 0.04
	var top_y: float = c.y - u * 0.42
	var bot_y: float = c.y + u * 0.68

	# Top steel grab handle on gable ridge
	var h_rect := Rect2(c.x - u * 0.28, top_y - u * 0.22, u * 0.56, u * 0.24)
	canvas.draw_rect(h_rect, COL_INK, false, ol * 1.15)

	# Lower red steel mechanic's chest
	var base_pts := PackedVector2Array([
		Vector2(c.x - tw * 0.5, seam_y),
		Vector2(c.x + tw * 0.5, seam_y),
		Vector2(c.x + tw * 0.5, bot_y),
		Vector2(c.x - tw * 0.5, bot_y)
	])
	_poly(canvas, base_pts, Color("#c73526"), COL_INK, ol)
	canvas.draw_rect(Rect2(c.x - tw * 0.5 + ol, bot_y - u * 0.18, tw - ol * 2.0, u * 0.14), COL_ATOMIC_DARK, true)

	# Pitched trapezoidal gabled lid
	var lid_pts := PackedVector2Array([
		Vector2(c.x - tw * 0.34, top_y),
		Vector2(c.x + tw * 0.34, top_y),
		Vector2(c.x + tw * 0.52, seam_y),
		Vector2(c.x - tw * 0.52, seam_y)
	])
	_poly(canvas, lid_pts, Color("#e34b38"), COL_INK, ol)
	canvas.draw_line(Vector2(c.x - tw * 0.30, top_y + ol), Vector2(c.x + tw * 0.30, top_y + ol), Color("#ff8b78"), thin)

	# Brushed silver center clasp / hasp straddling seam
	var cl_rect := Rect2(c.x - u * 0.15, seam_y - u * 0.14, u * 0.30, u * 0.34)
	_poly(canvas, _round_rect_pts(cl_rect, u * 0.04, 2), COL_STEEL_LIGHT, COL_INK, ol * 0.9)
	canvas.draw_circle(Vector2(c.x, seam_y + u * 0.08), maxf(u * 0.055, 1.0), COL_INK)


# ---------------------------------------------------------------------------
# 19. CAT — Sharikov the Grey-Striped Cat with Yellow Eyes & Ushanka Charm
# ---------------------------------------------------------------------------

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
# 20. DOG — Pancake the Scruffy Golden Mutt with Floppy Ears
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
# 21. ANTIBIOTICS — Amber Glass Prescription Pill Bottle with White Cap & Rx Cross Label
# ---------------------------------------------------------------------------

static func _draw_antibiotics(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var bw: float = u * 0.48
	var top_y: float = c.y - u * 0.44
	var bot_y: float = c.y + u * 0.74

	# Amber glass cylindrical bottle body
	var body_rect := Rect2(c.x - bw, top_y, bw * 2.0, bot_y - top_y)
	var body_pts: PackedVector2Array = _round_rect_pts(body_rect, u * 0.11, 3)
	_poly(canvas, body_pts, Color("#cf6a17"))

	# Deeper amber right bevel shadow + golden translucent left specular streak
	canvas.draw_rect(Rect2(c.x + bw * 0.45, top_y + ol, bw * 0.50, bot_y - top_y - ol * 2.0), Color("#8c3e08"), true)
	canvas.draw_rect(Rect2(c.x - bw * 0.80, top_y + ol, bw * 0.26, bot_y - top_y - ol * 2.0), Color("#f7ae3e"), true)

	# Capsules peeking inside bottom of amber glass
	for cap_data in [Vector3(-0.22, 0.56, -0.32), Vector3(0.20, 0.58, 0.28)]:
		var v: Vector3 = cap_data
		var pc := Vector2(c.x + u * v.x, c.y + u * v.y)
		_poly(canvas, _rot_rect_pts(pc, Vector2(u * 0.14, u * 0.065), v.z), COL_CREAM, COL_INK, thin * 0.75)
		_poly(canvas, _rot_rect_pts(pc - Vector2(cos(v.z), sin(v.z)) * (u * 0.06), Vector2(u * 0.07, u * 0.06), v.z), COL_ATOMIC_RED)

	# Wrap-around white prescription pharmacy label
	var lbl_rect := Rect2(c.x - bw + ol * 0.35, c.y - u * 0.18, bw * 2.0 - ol * 0.70, u * 0.58)
	canvas.draw_rect(lbl_rect, COL_CREAM, true)
	canvas.draw_rect(Rect2(lbl_rect.position.x, lbl_rect.position.y, lbl_rect.size.x, u * 0.10), Color("#2b6ca3"), true)
	canvas.draw_line(lbl_rect.position, Vector2(lbl_rect.end.x, lbl_rect.position.y), COL_INK, thin)
	canvas.draw_line(Vector2(lbl_rect.position.x, lbl_rect.end.y), lbl_rect.end, COL_INK, thin)

	# Crisp "Rx" glyph on left of label + red medical cross on right
	var rx_o := Vector2(c.x - bw * 0.68, c.y + u * 0.02)
	canvas.draw_line(rx_o, rx_o + Vector2(0.0, u * 0.26), COL_INK, thin * 1.25)
	canvas.draw_arc(rx_o + Vector2(u * 0.06, u * 0.07), u * 0.075, -PI * 0.5, PI * 0.5, 8, COL_INK, thin * 1.15)
	canvas.draw_line(rx_o + Vector2(u * 0.04, u * 0.13), rx_o + Vector2(u * 0.22, u * 0.30), COL_INK, thin * 1.2)
	canvas.draw_line(rx_o + Vector2(u * 0.22, u * 0.16), rx_o + Vector2(u * 0.08, u * 0.30), COL_INK, thin * 1.15)

	var cc := Vector2(c.x + bw * 0.38, c.y + u * 0.16)
	var arm_l: float = u * 0.15
	var arm_t: float = u * 0.055
	canvas.draw_rect(Rect2(cc.x - arm_t, cc.y - arm_l, arm_t * 2.0, arm_l * 2.0), Color("#d93426"), true)
	canvas.draw_rect(Rect2(cc.x - arm_l, cc.y - arm_t, arm_l * 2.0, arm_t * 2.0), Color("#d93426"), true)

	# Outer bottle ink contour
	_poly(canvas, body_pts, Color(0, 0, 0, 0), COL_INK, ol)

	# Ribbed white child-safe prescription cap
	var cap_rect := Rect2(c.x - bw * 1.12, c.y - u * 0.76, bw * 2.24, u * 0.34)
	_poly(canvas, _round_rect_pts(cap_rect, u * 0.06, 2), COL_CREAM, COL_INK, ol)
	for rx_f in [-0.72, -0.36, 0.0, 0.36, 0.72]:
		var gx: float = c.x + bw * float(rx_f)
		canvas.draw_line(Vector2(gx, cap_rect.position.y + ol), Vector2(gx, cap_rect.end.y - ol), COL_STEEL, thin * 0.9)


# ---------------------------------------------------------------------------
# 22. ANTIRAD — CONELRAD Yellow/Black Potassium Iodide Foil Blister Pack with Radiation Trefoil
# ---------------------------------------------------------------------------

static func _draw_antirad(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var pw: float = u * 1.26
	var ph: float = u * 1.50
	var card_rect := Rect2(c.x - pw * 0.5, c.y - ph * 0.5, pw, ph)
	var card_pts: PackedVector2Array = _round_rect_pts(card_rect, u * 0.12, 3)

	# Brushed silver foil blister pack base + diagonal metallic sheen
	_poly(canvas, card_pts, COL_STEEL_LIGHT)
	var sheen := PackedVector2Array([
		card_rect.position + Vector2(pw * 0.12, 0.0),
		card_rect.position + Vector2(pw * 0.48, 0.0),
		Vector2(card_rect.position.x + pw * 0.22, card_rect.end.y),
		Vector2(card_rect.position.x, card_rect.end.y - ph * 0.18)
	])
	_poly(canvas, sheen, Color(1.0, 1.0, 1.0, 0.45))

	# Top CONELRAD black-and-yellow hazard strip
	var hdr_h: float = u * 0.32
	var hdr_rect := Rect2(card_rect.position.x, card_rect.position.y, pw, hdr_h)
	canvas.draw_rect(hdr_rect, COL_INK, true)
	for sx in [-0.38, 0.0, 0.38]:
		var stripe_c := Vector2(c.x + pw * float(sx), hdr_rect.position.y + hdr_h * 0.5)
		_poly(canvas, _rot_rect_pts(stripe_c, Vector2(u * 0.11, hdr_h * 0.36), 0.35), COL_HAZARD_YELLOW)
	canvas.draw_line(Vector2(card_rect.position.x, hdr_rect.end.y), Vector2(card_rect.end.x, hdr_rect.end.y), COL_HAZARD_YELLOW, thin * 1.2)

	# Central CONELRAD Hazard Yellow disc with 3-blade black Radiation Trefoil
	var tc := Vector2(c.x, c.y - u * 0.06)
	var tr: float = u * 0.34
	canvas.draw_circle(tc, tr + thin * 0.9, COL_INK)
	canvas.draw_circle(tc, tr, COL_HAZARD_YELLOW)

	for blade_ang in [-PI * 5.0 / 6.0, -PI / 6.0, PI * 0.5]:
		var a0: float = float(blade_ang) - PI / 6.0
		var a1: float = float(blade_ang) + PI / 6.0
		var r_in: float = tr * 0.28
		var r_out: float = tr * 0.86
		var am: float = (a0 + a1) * 0.5
		var wedge := PackedVector2Array([
			tc + Vector2(cos(a0) * r_in, sin(a0) * r_in),
			tc + Vector2(cos(a0) * r_out, sin(a0) * r_out),
			tc + Vector2(cos(am) * r_out * 1.03, sin(am) * r_out * 1.03),
			tc + Vector2(cos(a1) * r_out, sin(a1) * r_out),
			tc + Vector2(cos(a1) * r_in, sin(a1) * r_in)
		])
		_poly(canvas, wedge, COL_INK)
	canvas.draw_circle(tc, tr * 0.17, COL_INK)

	# Row of 3 raised KI tablet blisters along bottom of foil pack
	for bx in [-0.36, 0.0, 0.36]:
		var bc := Vector2(c.x + pw * float(bx) * 0.88, c.y + u * 0.49)
		var br: float = u * 0.13
		canvas.draw_circle(bc, br + thin * 0.7, COL_INK)
		canvas.draw_circle(bc, br, COL_CREAM)
		canvas.draw_arc(bc, br * 0.62, PI * 1.1, PI * 1.85, 6, COL_HAZARD_YELLOW, thin)
		canvas.draw_line(bc + Vector2(-br * 0.65, 0.0), bc + Vector2(br * 0.65, 0.0), COL_STEEL_DARK, thin * 0.8)

	# Crisp outer foil pack border
	_poly(canvas, card_pts, Color(0, 0, 0, 0), COL_INK, ol)


# ---------------------------------------------------------------------------
# 23. SCRAP — Crossed Steel Wrench, Brass Gear & Riveted Hull Repair Plate
# ---------------------------------------------------------------------------

static func _draw_scrap(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# 1. Riveted steel hull repair plate in background
	var pl_c: Vector2 = c + Vector2(-u * 0.10, -u * 0.06)
	var pl_ang: float = 0.14
	var pl_pts: PackedVector2Array = _rot_rect_pts(pl_c, Vector2(u * 0.56, u * 0.46), pl_ang)
	_poly(canvas, pl_pts, COL_STEEL, COL_INK, ol)
	_poly(canvas, _rot_rect_pts(pl_c + Vector2(-u * 0.05, -u * 0.05), Vector2(u * 0.42, u * 0.32), pl_ang), COL_STEEL_LIGHT)
	var cr_p: float = cos(pl_ang)
	var sr_p: float = sin(pl_ang)
	for rx in [-0.42, 0.42]:
		for ry in [-0.32, 0.32]:
			var lx: float = float(rx) * u
			var ly: float = float(ry) * u
			var rv := Vector2(pl_c.x + lx * cr_p - ly * sr_p, pl_c.y + lx * sr_p + ly * cr_p)
			canvas.draw_circle(rv, maxf(u * 0.05, 1.0), COL_INK)

	# 2. 8-tooth brass gear wheel overlapping lower-right
	var gc: Vector2 = c + Vector2(u * 0.28, u * 0.24)
	var teeth: int = 8
	var r_tip: float = u * 0.42
	var r_root: float = u * 0.30
	var gear_pts := PackedVector2Array()
	for i in range(teeth * 2):
		var a0: float = TAU * float(i) / float(teeth * 2)
		var a1: float = TAU * (float(i) + 0.45) / float(teeth * 2)
		var rad: float = r_tip if (i % 2 == 0) else r_root
		gear_pts.append(gc + Vector2(cos(a0) * rad, sin(a0) * rad))
		gear_pts.append(gc + Vector2(cos(a1) * rad, sin(a1) * rad))
	_poly(canvas, gear_pts, COL_HAZARD_YELLOW, COL_INK, ol * 0.95)
	canvas.draw_circle(gc, u * 0.20, COL_HAZARD_GOLD)
	canvas.draw_circle(gc, u * 0.11, COL_SLATE)
	canvas.draw_arc(gc, u * 0.11, 0.0, TAU, 10, COL_INK, thin)

	# 3. Crossed open-end steel mechanic's wrench diagonally across foreground
	var w_ang: float = -PI * 0.25
	var w_dir := Vector2(cos(w_ang), sin(w_ang))
	var w_perp := Vector2(-w_dir.y, w_dir.x)
	var wc: Vector2 = c + Vector2(-u * 0.02, -u * 0.02)
	_poly(canvas, _rot_rect_pts(wc, Vector2(u * 0.56, u * 0.11), w_ang), COL_STEEL_LIGHT, COL_INK, ol)
	canvas.draw_line(wc - w_dir * (u * 0.36), wc + w_dir * (u * 0.36), COL_STEEL_DARK, thin * 1.1)

	for end_sgn in [-1.0, 1.0]:
		var es: float = float(end_sgn)
		var hc: Vector2 = wc + w_dir * (es * u * 0.58)
		canvas.draw_circle(hc, u * 0.23 + ol * 0.5, COL_INK)
		canvas.draw_circle(hc, u * 0.21, COL_STEEL_LIGHT)
		# Open jaw notch
		var notch_c: Vector2 = hc + w_dir * (es * u * 0.11) + w_perp * (es * u * 0.02)
		_poly(canvas, _rot_rect_pts(notch_c, Vector2(u * 0.15, u * 0.095), w_ang), COL_SLATE)


# ---------------------------------------------------------------------------
# 24. FUEL — Red Steel Military Jerrycan with Embossed X Ribs & Yellow Spout
# ---------------------------------------------------------------------------

static func _draw_fuel(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# Flexible yellow metal pour spout protruding from top-left
	var sp_base: Vector2 = c + Vector2(-u * 0.30, -u * 0.52)
	var sp_tip: Vector2 = c + Vector2(-u * 0.68, -u * 0.80)
	canvas.draw_line(sp_base, sp_tip, COL_INK, ol * 3.1)
	canvas.draw_line(sp_base, sp_tip, COL_HAZARD_YELLOW, ol * 1.8)
	_poly(canvas, _rot_rect_pts(sp_base, Vector2(u * 0.13, u * 0.08), -0.65), COL_HAZARD_GOLD, COL_INK, thin)

	# Red steel 5-gallon jerrycan body with beveled spout shoulder
	var x_l: float = c.x - u * 0.56
	var x_r: float = c.x + u * 0.60
	var y_t: float = c.y - u * 0.58
	var y_b: float = c.y + u * 0.74
	var can_pts := PackedVector2Array([
		Vector2(x_l + u * 0.26, y_t),
		Vector2(x_r - u * 0.08, y_t),
		Vector2(x_r, y_t + u * 0.08),
		Vector2(x_r, y_b - u * 0.08),
		Vector2(x_r - u * 0.08, y_b),
		Vector2(x_l + u * 0.08, y_b),
		Vector2(x_l, y_b - u * 0.08),
		Vector2(x_l, y_t + u * 0.26)
	])
	_poly(canvas, can_pts, Color("#cf3526"))

	# Right-side shadow & left highlight edge
	canvas.draw_rect(Rect2(x_r - u * 0.18, y_t + u * 0.10, u * 0.14, y_b - y_t - u * 0.20), COL_ATOMIC_DARK, true)
	canvas.draw_line(Vector2(x_l + u * 0.09, y_t + u * 0.30), Vector2(x_l + u * 0.09, y_b - u * 0.12), Color("#f26b57"), thin * 1.3)

	# Military triple-bar carry handle cutout at top-right
	var h_rect := Rect2(c.x - u * 0.08, y_t + u * 0.10, u * 0.54, u * 0.15)
	canvas.draw_rect(h_rect, COL_SLATE, true)
	canvas.draw_rect(h_rect, COL_INK, false, thin)
	canvas.draw_line(Vector2(h_rect.position.x, h_rect.position.y + h_rect.size.y * 0.5), Vector2(h_rect.end.x, h_rect.position.y + h_rect.size.y * 0.5), Color("#e64a38"), thin * 1.1)

	# Recessed side panel with embossed X stiffening ribs
	var p_rect := Rect2(x_l + u * 0.16, y_t + u * 0.34, (x_r - x_l) - u * 0.32, (y_b - y_t) - u * 0.48)
	_poly(canvas, _round_rect_pts(p_rect, u * 0.07, 2), COL_ATOMIC_DARK, COL_INK, thin)

	canvas.draw_line(p_rect.position + Vector2(u * 0.07, u * 0.07), p_rect.end - Vector2(u * 0.07, u * 0.07), COL_INK, ol * 1.35)
	canvas.draw_line(Vector2(p_rect.end.x - u * 0.07, p_rect.position.y + u * 0.07), Vector2(p_rect.position.x + u * 0.07, p_rect.end.y - u * 0.07), COL_INK, ol * 1.35)
	canvas.draw_line(p_rect.position + Vector2(u * 0.07, u * 0.07), p_rect.end - Vector2(u * 0.07, u * 0.07), Color("#f06651"), thin * 1.45)
	canvas.draw_line(Vector2(p_rect.end.x - u * 0.07, p_rect.position.y + u * 0.07), Vector2(p_rect.position.x + u * 0.07, p_rect.end.y - u * 0.07), Color("#f06651"), thin * 1.45)

	# Central stamped hub square with yellow fuel hazard diamond
	var hub_c: Vector2 = p_rect.get_center()
	var hub_r := Rect2(hub_c.x - u * 0.15, hub_c.y - u * 0.15, u * 0.30, u * 0.30)
	canvas.draw_rect(hub_r, Color("#cf3526"), true)
	canvas.draw_rect(hub_r, COL_INK, false, thin)
	_poly(canvas, _rot_rect_pts(hub_c, Vector2(u * 0.08, u * 0.08), PI * 0.25), COL_HAZARD_YELLOW)

	# Outer ink contour
	_poly(canvas, can_pts, Color(0, 0, 0, 0), COL_INK, ol)


# ---------------------------------------------------------------------------
# 25. BATTERY — 12V Lead-Acid Car Battery with + Red and - Black Posts & Lightning Bolt
# ---------------------------------------------------------------------------

static func _draw_battery(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var bw: float = u * 1.38
	var lid_y: float = c.y - u * 0.42
	var lid_h: float = u * 0.22
	var bot_y: float = c.y + u * 0.72

	# Left (+) Red & Right (-) Black/Steel lead terminal posts on top
	var pos_post := Rect2(c.x - bw * 0.38, lid_y - u * 0.24, u * 0.24, u * 0.26)
	_poly(canvas, _round_rect_pts(pos_post, u * 0.04, 2), COL_ATOMIC_RED, COL_INK, ol * 0.9)
	canvas.draw_rect(Rect2(pos_post.position.x + u * 0.05, pos_post.position.y - u * 0.06, u * 0.14, u * 0.08), COL_STEEL_LIGHT, true)

	var neg_post := Rect2(c.x + bw * 0.38 - u * 0.24, lid_y - u * 0.24, u * 0.24, u * 0.26)
	_poly(canvas, _round_rect_pts(neg_post, u * 0.04, 2), Color("#262b30"), COL_INK, ol * 0.9)
	canvas.draw_rect(Rect2(neg_post.position.x + u * 0.05, neg_post.position.y - u * 0.06, u * 0.14, u * 0.08), COL_STEEL, true)

	# Three yellow acid-cell filler caps between terminals
	for vx in [-0.14, 0.0, 0.14]:
		var vc := Vector2(c.x + bw * float(vx), lid_y - u * 0.05)
		canvas.draw_circle(vc, maxf(u * 0.06, 1.1), COL_INK)
		canvas.draw_circle(vc, maxf(u * 0.042, 0.8), COL_HAZARD_YELLOW)

	# Heavy dark slate ebonite casing
	var body_rect := Rect2(c.x - bw * 0.48, lid_y + lid_h - u * 0.02, bw * 0.96, bot_y - (lid_y + lid_h))
	_poly(canvas, _round_rect_pts(body_rect, u * 0.08, 2), Color("#2a3036"), COL_INK, ol)
	canvas.draw_rect(Rect2(body_rect.position.x + ol, body_rect.position.y + ol, u * 0.18, body_rect.size.y - ol * 2.0), Color("#3c464f"), true)

	# Molded battery top cover lip
	var lid_rect := Rect2(c.x - bw * 0.52, lid_y, bw * 1.04, lid_h)
	_poly(canvas, _round_rect_pts(lid_rect, u * 0.06, 2), Color("#465059"), COL_INK, ol)

	# Crisp (+) Red and (-) Steel polarity symbols on upper face
	var pc := Vector2(c.x - bw * 0.28, body_rect.position.y + u * 0.20)
	var sym_r: float = u * 0.10
	canvas.draw_line(pc + Vector2(-sym_r, 0.0), pc + Vector2(sym_r, 0.0), COL_ATOMIC_RED, thin * 1.6)
	canvas.draw_line(pc + Vector2(0.0, -sym_r), pc + Vector2(0.0, sym_r), COL_ATOMIC_RED, thin * 1.6)

	var nc := Vector2(c.x + bw * 0.28, body_rect.position.y + u * 0.20)
	canvas.draw_line(nc + Vector2(-sym_r, 0.0), nc + Vector2(sym_r, 0.0), COL_STEEL_LIGHT, thin * 1.6)

	# High-voltage CONELRAD yellow lightning bolt emblem in center
	var bc := Vector2(c.x, body_rect.position.y + body_rect.size.y * 0.54)
	var bolt_pts := PackedVector2Array([
		bc + Vector2(u * 0.08, -u * 0.34),
		bc + Vector2(-u * 0.22, u * 0.04),
		bc + Vector2(-u * 0.02, u * 0.04),
		bc + Vector2(-u * 0.12, u * 0.36),
		bc + Vector2(u * 0.22, -u * 0.04),
		bc + Vector2(u * 0.02, -u * 0.04)
	])
	_poly(canvas, bolt_pts, COL_HAZARD_YELLOW, COL_INK, thin * 1.1)


# ---------------------------------------------------------------------------
# 26. ALTERNATOR — Finned Copper-Wound Dynamo Alternator Pulley
# ---------------------------------------------------------------------------

static func _draw_alternator(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var hc: Vector2 = c + Vector2(-u * 0.10, u * 0.06)
	var hr: float = u * 0.56

	# Cast-aluminum mounting bracket ears with bolt holes
	for ear_ang in [-PI * 0.68, PI * 0.42]:
		var ea: float = float(ear_ang)
		var ep: Vector2 = hc + Vector2(cos(ea), sin(ea)) * (hr * 1.12)
		canvas.draw_circle(ep, u * 0.18, COL_INK)
		canvas.draw_circle(ep, u * 0.15, COL_STEEL_DARK)
		canvas.draw_circle(ep, u * 0.065, COL_SLATE)

	# Finned cast-aluminum stator housing
	canvas.draw_circle(hc, hr + ol * 0.7, COL_INK)
	canvas.draw_circle(hc, hr, COL_STEEL)
	canvas.draw_arc(hc, hr * 0.88, PI * 0.95, PI * 1.75, 12, COL_STEEL_LIGHT, thin * 1.4)

	# Radial cooling fins around rim
	for fi in range(10):
		var fa: float = TAU * float(fi) / 10.0
		canvas.draw_line(hc + Vector2(cos(fa), sin(fa)) * (hr * 0.78), hc + Vector2(cos(fa), sin(fa)) * (hr * 0.98), COL_INK, thin)

	# Ventilation cutouts revealing bright copper-wound stator coils!
	for ci in range(5):
		var ca: float = TAU * float(ci) / 5.0 + 0.3
		var slot_c: Vector2 = hc + Vector2(cos(ca), sin(ca)) * (hr * 0.52)
		_poly(canvas, _rot_rect_pts(slot_c, Vector2(u * 0.14, u * 0.085), ca), COL_INK)
		_poly(canvas, _rot_rect_pts(slot_c, Vector2(u * 0.11, u * 0.06), ca), Color("#d96b27"))
		canvas.draw_line(slot_c - Vector2(cos(ca), sin(ca)) * (u * 0.08), slot_c + Vector2(cos(ca), sin(ca)) * (u * 0.08), Color("#f79f4a"), thin * 0.9)

	# Front radial cooling fan + V-belt pulley wheel on upper-right shaft
	var pc: Vector2 = c + Vector2(u * 0.24, -u * 0.14)
	var fan_r: float = u * 0.42
	var fan_pts := PackedVector2Array()
	for bi in range(16):
		var ba: float = TAU * float(bi) / 16.0
		var rad: float = fan_r if (bi % 2 == 0) else (fan_r * 0.80)
		fan_pts.append(pc + Vector2(cos(ba) * rad, sin(ba) * rad))
	_poly(canvas, fan_pts, COL_STEEL_DARK, COL_INK, ol * 0.85)

	# Stepped V-belt pulley groove & brass center hex shaft nut
	var pul_r: float = u * 0.28
	canvas.draw_circle(pc, pul_r + thin * 0.8, COL_INK)
	canvas.draw_circle(pc, pul_r, COL_STEEL_LIGHT)
	canvas.draw_circle(pc, pul_r * 0.66, Color("#2c3238"))
	canvas.draw_circle(pc, pul_r * 0.36, COL_HAZARD_YELLOW)
	canvas.draw_arc(pc, pul_r * 0.36, 0.0, TAU, 8, COL_INK, thin * 0.9)


# ---------------------------------------------------------------------------
# 27. SPARK PLUGS — White Ceramic Ribbed Spark Plug with Brass Hex Nut & Electrode Spark
# ---------------------------------------------------------------------------

static func _draw_spark_plugs(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	var ang: float = -PI * 0.24
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)

	# Top brass ignition terminal stud
	var stud_c: Vector2 = c + dir * (u * 0.68)
	_poly(canvas, _rot_rect_pts(stud_c, Vector2(u * 0.11, u * 0.08), ang), COL_HAZARD_YELLOW, COL_INK, ol * 0.85)

	# White alumina-ceramic insulator with 3 corrugated ribs
	var cer_c: Vector2 = c + dir * (u * 0.30)
	_poly(canvas, _rot_rect_pts(cer_c, Vector2(u * 0.32, u * 0.17), ang), Color("#f2f7fa"), COL_INK, ol)
	for rib_off in [-0.14, 0.02, 0.18]:
		var rc: Vector2 = cer_c + dir * (u * float(rib_off))
		_poly(canvas, _rot_rect_pts(rc, Vector2(u * 0.055, u * 0.21), ang), COL_CREAM, COL_INK, thin * 0.85)
	# Manufacturer cyan-blue insulator stripe
	var band_c: Vector2 = cer_c - dir * (u * 0.23)
	_poly(canvas, _rot_rect_pts(band_c, Vector2(u * 0.035, u * 0.155), ang), COL_WATER_BLUE)

	# Brass hex wrench nut (3 faceted panels)
	var hex_c: Vector2 = c - dir * (u * 0.07)
	_poly(canvas, _rot_rect_pts(hex_c, Vector2(u * 0.15, u * 0.27), ang), COL_HAZARD_YELLOW, COL_INK, ol)
	_poly(canvas, _rot_rect_pts(hex_c - perp * (u * 0.16), Vector2(u * 0.13, u * 0.08), ang), Color("#ffe484"))
	_poly(canvas, _rot_rect_pts(hex_c + perp * (u * 0.16), Vector2(u * 0.13, u * 0.08), ang), COL_HAZARD_GOLD)
	canvas.draw_line(hex_c - dir * (u * 0.14) - perp * (u * 0.08), hex_c + dir * (u * 0.14) - perp * (u * 0.08), COL_INK, thin * 0.85)
	canvas.draw_line(hex_c - dir * (u * 0.14) + perp * (u * 0.08), hex_c + dir * (u * 0.14) + perp * (u * 0.08), COL_INK, thin * 0.85)

	# Threaded dark-steel reach barrel
	var thr_c: Vector2 = c - dir * (u * 0.36)
	_poly(canvas, _rot_rect_pts(thr_c, Vector2(u * 0.17, u * 0.18), ang), COL_STEEL_DARK, COL_INK, ol)
	for ti in [-0.09, 0.0, 0.09]:
		var tp: Vector2 = thr_c + dir * (u * float(ti))
		canvas.draw_line(tp - perp * (u * 0.19), tp + perp * (u * 0.19), COL_STEEL_LIGHT, thin)

	# Center tip & L-shaped ground electrode hook + bright blue/yellow ignition spark!
	var tip_base: Vector2 = c - dir * (u * 0.54)
	canvas.draw_line(tip_base, tip_base - dir * (u * 0.10), COL_HAZARD_YELLOW, thin * 1.4)
	var hook_pts := PackedVector2Array([
		tip_base + perp * (u * 0.13),
		tip_base - dir * (u * 0.20) + perp * (u * 0.13),
		tip_base - dir * (u * 0.20) - perp * (u * 0.04)
	])
	canvas.draw_polyline(hook_pts, COL_INK, ol * 1.35)
	canvas.draw_polyline(hook_pts, COL_STEEL_LIGHT, thin * 1.2)

	var spk_c: Vector2 = tip_base - dir * (u * 0.14)
	for sa in [0.0, PI * 0.33, PI * 0.66]:
		var sv := Vector2(cos(float(sa)), sin(float(sa))) * (u * 0.20)
		canvas.draw_line(spk_c - sv, spk_c + sv, Color("#70d6ff"), thin * 1.35)
	canvas.draw_circle(spk_c, maxf(u * 0.075, 1.3), COL_HAZARD_YELLOW)
	canvas.draw_circle(spk_c, maxf(u * 0.04, 0.9), Color.WHITE)


# ---------------------------------------------------------------------------
# 28. RADIATOR HOSE / VEHICLE PART — Curved Reinforced Rubber Hose with Steel Clamps
# ---------------------------------------------------------------------------

static func _draw_radiator_hose(canvas: CanvasItem, c: Vector2, u: float, ol: float, thin: float) -> void:
	# Smooth S-curved coolant hose spine sampled via cubic Bezier
	var p0: Vector2 = c + Vector2(-u * 0.54, -u * 0.52)
	var p1: Vector2 = c + Vector2(u * 0.42, -u * 0.54)
	var p2: Vector2 = c + Vector2(-u * 0.42, u * 0.54)
	var p3: Vector2 = c + Vector2(u * 0.54, u * 0.52)

	var steps: int = 16
	var hw: float = u * 0.23
	var left_side := PackedVector2Array()
	var right_side := PackedVector2Array()
	var spine := PackedVector2Array()

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var omt: float = 1.0 - t
		var pt: Vector2 = (omt * omt * omt) * p0 + (3.0 * omt * omt * t) * p1 + (3.0 * omt * t * t) * p2 + (t * t * t) * p3
		var tang: Vector2 = 3.0 * omt * omt * (p1 - p0) + 6.0 * omt * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)
		var dir: Vector2 = tang.normalized() if tang.length_squared() > 0.0001 else Vector2.RIGHT
		var nrm := Vector2(-dir.y, dir.x)
		spine.append(pt - nrm * (hw * 0.34))
		left_side.append(pt + nrm * hw)
		right_side.append(pt - nrm * hw)

	var hose_poly := PackedVector2Array()
	for pt_l in left_side:
		hose_poly.append(pt_l)
	for idx in range(right_side.size() - 1, -1, -1):
		hose_poly.append(right_side[idx])

	# Vulcanized charcoal rubber body + glossy highlight + braided reinforcement ribs
	_poly(canvas, hose_poly, Color("#2b3136"), COL_INK, ol)
	canvas.draw_polyline(spine, Color("#606c76"), thin * 1.45)

	for rib_idx in [4, 8, 12]:
		var rl: Vector2 = left_side[rib_idx]
		var rr: Vector2 = right_side[rib_idx]
		canvas.draw_line(rl.lerp(rr, 0.12), rl.lerp(rr, 0.88), Color("#191d20"), thin * 1.1)

	# Stainless-steel worm-gear clamps near both cuffs
	for clamp_idx in [2, 14]:
		var cl_a: Vector2 = left_side[clamp_idx]
		var cl_b: Vector2 = right_side[clamp_idx]
		var cl_mid: Vector2 = (cl_a + cl_b) * 0.5
		var cl_nrm: Vector2 = (cl_a - cl_b).normalized()
		var cl_ang: float = Vector2(-cl_nrm.y, cl_nrm.x).angle()
		_poly(canvas, _rot_rect_pts(cl_mid, Vector2(u * 0.065, hw * 1.18), cl_ang), COL_STEEL_LIGHT, COL_INK, ol * 0.85)
		# Brass tensioner screw head on outer clamp edge
		var screw_pos: Vector2 = cl_a + cl_nrm * (u * 0.07)
		canvas.draw_circle(screw_pos, maxf(u * 0.07, 1.2), COL_INK)
		canvas.draw_circle(screw_pos, maxf(u * 0.048, 0.9), COL_HAZARD_YELLOW)

	# Open reinforced red-lined rubber mouths at upper-left & lower-right ends
	_poly(canvas, _ellipse_pts(p0, u * 0.10, hw, 0.04, 12), Color("#b83d28"), COL_INK, ol * 0.9)
	_poly(canvas, _ellipse_pts(p0, u * 0.055, hw * 0.58, 0.04, 10), COL_INK)

	_poly(canvas, _ellipse_pts(p3, u * 0.10, hw, 0.04, 12), Color("#b83d28"), COL_INK, ol * 0.9)
	_poly(canvas, _ellipse_pts(p3, u * 0.055, hw * 0.58, 0.04, 10), COL_INK)


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
