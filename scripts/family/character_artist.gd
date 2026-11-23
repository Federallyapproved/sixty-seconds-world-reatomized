class_name CharacterArtist
extends RefCounted

## Procedural 1950s CONELRAD Civil Defense character illustrator.
## Renders consistent custom family members across Family Creator, 60s Scavenge (top-down),
## and Bunker Survival (seated full-body & portraits) with full runtime survival conditions.

const INK_COLOR := Color("#1b1917")
const PARCHMENT_LIGHT := Color("#f2e6ce")
const PARCHMENT_DARK := Color("#dccba6")
const HAZARD_YELLOW := Color("#f5be2e")
const ATOMIC_ORANGE := Color("#e05a2b")
const BUNKER_SLATE := Color("#232824")
const MUTANT_GREEN := Color("#7ec850")
const MUTANT_PURPLE := Color("#884ca8")

const SKIN_TONES: Array[String] = [
	"#f7dac4", # 0: Porcelain Warm
	"#ecc19c", # 1: Peach Ivory
	"#d7a176", # 2: Golden Tan
	"#b87b50", # 3: Warm Bronze
	"#8b5433", # 4: Rich Umber
	"#59331e"  # 5: Deep Espresso
]

const HAIR_STYLE_NAMES: Array[String] = [
	"Classic Side Part",
	"50s Pompadour",
	"Chin Bob",
	"High Beehive",
	"Twin Pigtails",
	"Voluminous Afro",
	"Buzz / Bald",
	"Spiky Punk"
]

const FACIAL_HAIR_NAMES: Array[String] = [
	"None",
	"50s Mustache",
	"Full Beard",
	"Stubble"
]

const SHIRT_STYLE_NAMES: Array[String] = [
	"Shirt & Tie",
	"Knit Sweater",
	"Retro Polka Dress",
	"Ringer Tee",
	"Utility Jacket"
]

const HAIR_COLOR_SWATCHES: Array[String] = [
	"#1e1a18", # Jet Black
	"#4a2e1b", # Espresso Brown
	"#7a4b2a", # Chestnut
	"#d8a438", # Golden Blonde
	"#f0d58c", # Platinum Blonde
	"#e06d2b", # Ginger Orange
	"#8c2d25", # Auburn Red
	"#9aa0a6", # Silver Gray
	"#2bc4d8", # Atomic Cyan
	"#e85ca8"  # Bubblegum Pink
]

const EYE_COLOR_SWATCHES: Array[String] = [
	"#2f5d8a", # Classic Blue
	"#3a7d5c", # Emerald Green
	"#5c3c24", # Warm Brown
	"#7d6834", # Amber Hazel
	"#5d6b78", # Steel Gray
	"#7b4b94"  # Violet
]

const OUTFIT_COLOR_SWATCHES: Array[String] = [
	"#c84b31", # Atomic Red
	"#3d7a8a", # Teal Blue
	"#d99b26", # Mustard Gold
	"#557a46", # Civil Olive
	"#7b4b94", # Plum Purple
	"#d46a84", # Coral Rose
	"#3b4d6b", # Navy Denim
	"#6e5039"  # Bomber Brown
]

const HAT_IDS: Array[String] = [
	"none",
	"cd_helmet",
	"ushanka",
	"medic_cap",
	"aviator"
]

const HAT_NAMES: Dictionary = {
	"none": "No Headgear",
	"cd_helmet": "CD Brodie Helmet",
	"ushanka": "Winter Fur Ushanka",
	"medic_cap": "Field Medic Cap",
	"aviator": "Aviator Bomber Cap"
}

static func get_hat_name(hat_id: String) -> String:
	return str(HAT_NAMES.get(hat_id, "No Headgear"))

static func get_skin_color(member: Dictionary) -> Color:
	var is_mutant: bool = bool(member.get("is_mutant", false))
	if is_mutant:
		return MUTANT_GREEN
	var idx: int = clampi(int(member.get("skin_tone", 1)), 0, SKIN_TONES.size() - 1)
	return Color(SKIN_TONES[idx])

static func get_role_for_age(age: int) -> String:
	if age <= 12:
		return "child"
	elif age <= 17:
		return "teen"
	elif age <= 59:
		return "adult"
	return "elder"

static func _safe_color(hex_str: String, fallback: Color) -> Color:
	if hex_str.is_empty():
		return fallback
	if Color.html_is_valid(hex_str):
		return Color(hex_str)
	return fallback

static func _draw_ellipse(canvas: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, points: int = 24) -> void:
	var pts := PackedVector2Array()
	pts.resize(points)
	for i in range(points):
		var ang: float = TAU * float(i) / float(points)
		pts[i] = center + Vector2(cos(ang) * rx, sin(ang) * ry)
	canvas.draw_colored_polygon(pts, col)

static func _draw_ellipse_outline(canvas: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, width: float = 2.0, points: int = 24) -> void:
	var pts := PackedVector2Array()
	pts.resize(points + 1)
	for i in range(points + 1):
		var ang: float = TAU * float(i) / float(points)
		pts[i] = center + Vector2(cos(ang) * rx, sin(ang) * ry)
	canvas.draw_polyline(pts, col, width)

static func _draw_poly_outlined(canvas: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color = INK_COLOR, width: float = 2.0) -> void:
	if pts.size() < 3:
		return
	canvas.draw_colored_polygon(pts, fill)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	canvas.draw_polyline(closed, outline, width)

# ==============================================================================
# 1. PORTRAIT RENDERER (Family Creator, Bunker HUD, Event Cards, Summary)
# ==============================================================================
static func draw_portrait(canvas: CanvasItem, rect: Rect2, member: Dictionary, show_frame: bool = true) -> void:
	var alive: bool = bool(member.get("alive", true))
	var betrayed: bool = bool(member.get("betrayed", false))
	var on_expedition: bool = bool(member.get("on_expedition", false))

	if show_frame:
		# Shadow + aged dossier card background
		canvas.draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.35), true)
		var bg_col: Color = Color("#c8bcb0") if betrayed else (Color("#d5ccb8") if not alive else PARCHMENT_LIGHT)
		canvas.draw_rect(rect, bg_col, true)
		var inner_rect := rect.grow(-4.0)
		var in_col: Color = Color("#bfb2a5") if betrayed else (Color("#cfc3ab") if not alive else PARCHMENT_DARK.lerp(PARCHMENT_LIGHT, 0.45))
		canvas.draw_rect(inner_rect, in_col, true)

		# Subtle 1950s CONELRAD sunburst rays inside frame
		var burst_center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.58)
		var ray_col: Color = Color(0.55, 0.25, 0.22, 0.14) if betrayed else (Color(1.0, 0.94, 0.78, 0.26) if alive else Color(0.5, 0.46, 0.4, 0.16))
		var max_r: float = minf(rect.size.x, rect.size.y) * 0.46
		for r_idx in range(8):
			var a0: float = float(r_idx) * (TAU / 8.0)
			var a1: float = a0 + (TAU / 16.0)
			var ray_pts := PackedVector2Array([
				burst_center,
				burst_center + Vector2(cos(a0), sin(a0)) * max_r,
				burst_center + Vector2(cos(a1), sin(a1)) * max_r
			])
			canvas.draw_colored_polygon(ray_pts, ray_col)

	if betrayed:
		_draw_betrayed_portrait(canvas, rect, member)
		if show_frame:
			canvas.draw_rect(rect, INK_COLOR, false, 2.5)
			canvas.draw_rect(rect.grow(-4.0), Color(0.72, 0.12, 0.10, 0.65), false, 1.2)
		return

	if not alive:
		_draw_deceased_memorial(canvas, rect, member)
		if show_frame:
			canvas.draw_rect(rect, INK_COLOR, false, 2.5)
			canvas.draw_rect(rect.grow(-4.0), Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.45), false, 1.0)
		return

	var u: float = minf(rect.size.x, rect.size.y) / 160.0
	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", get_role_for_age(age)))
	var fatigue: int = int(member.get("fatigue", 0))

	# Proportions driven by age & role
	var head_scale: float = 1.0
	var shoulder_w: float = 48.0 * u
	var y_shift: float = 0.0
	var jaw_round: float = 1.0
	if role == "child" or age <= 12:
		head_scale = 0.92
		shoulder_w = 32.0 * u
		y_shift = 15.0 * u
		jaw_round = 1.12
	elif role == "teen" or age <= 17:
		head_scale = 0.96
		shoulder_w = 40.0 * u
		y_shift = 7.0 * u
		jaw_round = 1.04
	elif role == "elder" or age >= 60:
		head_scale = 0.98
		shoulder_w = 44.0 * u
		y_shift = 5.0 * u
		jaw_round = 0.95

	var fatigue_slump: float = minf(float(fatigue), 2.0) * 2.8 * u if fatigue >= 1 else 0.0
	var center_x: float = rect.position.x + rect.size.x * 0.5
	var bottom_y: float = rect.position.y + rect.size.y - (5.0 * u if show_frame else 0.0)
	var shoulder_y: float = rect.position.y + rect.size.y * 0.72 + y_shift * 0.45 + fatigue_slump
	var head_center := Vector2(center_x, rect.position.y + rect.size.y * 0.43 + y_shift + fatigue_slump * 0.55)

	_draw_character_upper_body(
		canvas,
		head_center,
		shoulder_y,
		bottom_y,
		shoulder_w,
		head_scale * u,
		jaw_round,
		member,
		on_expedition
	)

	if on_expedition:
		_draw_expedition_stamp(canvas, rect, u)

	if show_frame:
		canvas.draw_rect(rect, INK_COLOR, false, 2.5)
		canvas.draw_rect(rect.grow(-4.0), Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.5), false, 1.0)
		# Corner rivets
		var c_off: float = 7.0
		for corner in [
			rect.position + Vector2(c_off, c_off),
			Vector2(rect.end.x - c_off, rect.position.y + c_off),
			Vector2(rect.position.x + c_off, rect.end.y - c_off),
			rect.end - Vector2(c_off, c_off)
		]:
			canvas.draw_circle(corner, 2.0, INK_COLOR)

static func _draw_betrayed_portrait(canvas: CanvasItem, rect: Rect2, member: Dictionary) -> void:
	var u: float = minf(rect.size.x, rect.size.y) / 160.0
	var cx: float = rect.position.x + rect.size.x * 0.5
	var bottom_y: float = rect.end.y - 5.0 * u
	var shoulder_y: float = rect.position.y + rect.size.y * 0.74
	var head_center := Vector2(cx, rect.position.y + rect.size.y * 0.45)

	# Darkened traitor silhouette in background
	var hair_style: int = clampi(int(member.get("hair_style", 0)), 0, 7)
	var shirt_style: int = clampi(int(member.get("shirt_style", 0)), 0, 4)
	var sil_col := Color("#3d3330")
	var sil_rim := Color("#66554e")
	_draw_hair_back(canvas, head_center, u * 0.95, hair_style, sil_col, sil_rim)
	_draw_torso_shirt(canvas, Vector2(cx, shoulder_y), bottom_y, 44.0 * u, u * 0.95, shirt_style, sil_col, sil_col.lightened(0.06), sil_rim)
	_draw_ellipse(canvas, head_center, 25.5 * u, 31.0 * u, sil_col)
	_draw_ellipse_outline(canvas, head_center, 25.5 * u, 31.0 * u, sil_rim, 1.8)
	_draw_hair_front(canvas, head_center, u * 0.95, hair_style, sil_col, sil_rim)

	# Jagged diagonal torn portrait slash across the dossier card
	var s_top := Vector2(rect.end.x - 14.0 * u, rect.position.y + 12.0 * u)
	var s_bot := Vector2(rect.position.x + 14.0 * u, rect.end.y - 24.0 * u)
	var slash_dir: Vector2 = (s_bot - s_top).normalized()
	var slash_perp := Vector2(-slash_dir.y, slash_dir.x)

	var tear_outer := PackedVector2Array([
		s_top - slash_perp * (3.5 * u),
		s_top.lerp(s_bot, 0.28) - slash_perp * (9.5 * u),
		s_top.lerp(s_bot, 0.52) - slash_perp * (5.5 * u),
		s_top.lerp(s_bot, 0.78) - slash_perp * (10.0 * u),
		s_bot - slash_perp * (3.0 * u),
		s_bot + slash_perp * (3.0 * u),
		s_top.lerp(s_bot, 0.72) + slash_perp * (9.0 * u),
		s_top.lerp(s_bot, 0.48) + slash_perp * (5.0 * u),
		s_top.lerp(s_bot, 0.22) + slash_perp * (8.5 * u),
		s_top + slash_perp * (3.5 * u)
	])
	canvas.draw_colored_polygon(tear_outer, PARCHMENT_LIGHT)

	var tear_gap := PackedVector2Array([
		s_top,
		s_top.lerp(s_bot, 0.30) - slash_perp * (5.2 * u),
		s_top.lerp(s_bot, 0.50) - slash_perp * (2.2 * u),
		s_top.lerp(s_bot, 0.76) - slash_perp * (5.6 * u),
		s_bot,
		s_top.lerp(s_bot, 0.74) + slash_perp * (4.8 * u),
		s_top.lerp(s_bot, 0.50) + slash_perp * (2.0 * u),
		s_top.lerp(s_bot, 0.24) + slash_perp * (4.6 * u)
	])
	_draw_poly_outlined(canvas, tear_gap, Color("#171110"), Color("#a61b1b"), 1.6)

	# Crimson angled "DESERTED" rubber stamp
	var crimson := Color("#b81b1a")
	var stamp_bg := Color(0.96, 0.89, 0.84, 0.92)
	var st_c := Vector2(cx, rect.position.y + rect.size.y * 0.48)
	var st_ang: float = -0.20
	var cr: float = cos(st_ang)
	var sr: float = sin(st_ang)
	var hw: float = minf(rect.size.x * 0.44, 64.0 * u)
	var hh: float = maxf(11.0, 14.5 * u)
	var st_pts := PackedVector2Array([
		st_c + Vector2(-hw * cr + hh * sr, -hw * sr - hh * cr),
		st_c + Vector2(hw * cr + hh * sr, hw * sr - hh * cr),
		st_c + Vector2(hw * cr - hh * sr, hw * sr + hh * cr),
		st_c + Vector2(-hw * cr - hh * sr, -hw * sr + hh * cr)
	])
	_draw_poly_outlined(canvas, st_pts, stamp_bg, crimson, maxf(2.0, 2.4 * u))

	var font: Font = ThemeDB.fallback_font
	if font != null:
		var st_fsize: int = maxi(9, int(round(13.0 * u)))
		var st_txt: String = "DESERTED"
		var st_sz: Vector2 = font.get_string_size(st_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, st_fsize)
		canvas.draw_set_transform(st_c, st_ang, Vector2.ONE)
		canvas.draw_string(
			font,
			Vector2(-st_sz.x * 0.5, (font.get_ascent(st_fsize) - font.get_descent(st_fsize)) * 0.5),
			st_txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			st_fsize,
			crimson
		)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Bottom traitor tag
		var tag_h: float = maxf(15.0, 18.0 * u)
		var tag_rect := Rect2(rect.position.x + rect.size.x * 0.05, rect.end.y - tag_h - maxf(5.0, 7.0 * u), rect.size.x * 0.90, tag_h)
		canvas.draw_rect(tag_rect, crimson.darkened(0.22), true)
		canvas.draw_rect(tag_rect, INK_COLOR, false, 1.5)
		var nm: String = str(member.get("name", "SURVIVOR")).strip_edges().to_upper()
		var lbl: String = nm + " • FLED"
		var fsz: int = maxi(8, int(round(10.0 * u)))
		var base_y: float = tag_rect.position.y + (tag_rect.size.y + font.get_ascent(fsz) - font.get_descent(fsz)) * 0.5
		canvas.draw_string(font, Vector2(tag_rect.position.x + 3.0, base_y), lbl, HORIZONTAL_ALIGNMENT_CENTER, tag_rect.size.x - 6.0, fsz, PARCHMENT_LIGHT)

static func _draw_deceased_memorial(canvas: CanvasItem, rect: Rect2, member: Dictionary) -> void:
	var u: float = minf(rect.size.x, rect.size.y) / 160.0
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.52
	var sepia_dark := Color("#594d3e")
	var sepia_mid := Color("#8a7b66")
	var sepia_light := Color("#b8aa94")

	# Faded slumped silhouette behind cross
	_draw_ellipse(canvas, Vector2(cx, rect.end.y - 22.0 * u), 38.0 * u, 20.0 * u, Color(sepia_mid.r, sepia_mid.g, sepia_mid.b, 0.42))
	canvas.draw_circle(Vector2(cx + 4.0 * u, cy - 18.0 * u), 20.0 * u, Color(sepia_mid.r, sepia_mid.g, sepia_mid.b, 0.35))

	# Sepia memorial cross
	var v_bar := Rect2(cx - 7.5 * u, cy - 40.0 * u, 15.0 * u, 76.0 * u)
	var h_bar := Rect2(cx - 26.0 * u, cy - 20.0 * u, 52.0 * u, 14.0 * u)
	canvas.draw_rect(Rect2(v_bar.position + Vector2(2, 3) * u, v_bar.size), Color(0, 0, 0, 0.22), true)
	canvas.draw_rect(Rect2(h_bar.position + Vector2(2, 3) * u, h_bar.size), Color(0, 0, 0, 0.22), true)
	canvas.draw_rect(v_bar, sepia_light, true)
	canvas.draw_rect(h_bar, sepia_light, true)
	canvas.draw_rect(v_bar, sepia_dark, false, 2.2 * u)
	canvas.draw_rect(h_bar, sepia_dark, false, 2.2 * u)

	# Small dogtag / flower emblem at center of cross
	canvas.draw_circle(Vector2(cx, cy - 13.0 * u), 5.0 * u, sepia_dark)
	canvas.draw_circle(Vector2(cx, cy - 13.0 * u), 2.5 * u, PARCHMENT_LIGHT)

	# Mound at base
	_draw_ellipse(canvas, Vector2(cx, cy + 36.0 * u), 34.0 * u, 9.0 * u, sepia_dark)

	# R.I.P. banner (90% portrait width with dynamic font step-down so multi-word names never truncate)
	var tag_h: float = maxf(15.0, 18.0 * u)
	var tag_y: float = rect.end.y - tag_h - maxf(5.0, 7.0 * u)
	var tag_rect := Rect2(rect.position.x + rect.size.x * 0.05, tag_y, rect.size.x * 0.90, tag_h)
	canvas.draw_rect(tag_rect, sepia_dark, true)
	canvas.draw_rect(tag_rect, INK_COLOR, false, 1.5)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var upper_name: String = str(member.get("name", "")).strip_edges().to_upper()
		if upper_name.is_empty():
			upper_name = "SURVIVOR"
		var full_label: String = "R.I.P. " + upper_name
		var pad_x: float = 6.0
		var avail_w: float = maxf(16.0, tag_rect.size.x - pad_x)
		var max_fsize: int = maxi(10, int(round(11.0 * u)))
		var chosen_fsize: int = 8
		var chosen_label: String = full_label
		var fits_full: bool = false
		var fsz: int = max_fsize
		while fsz >= 8:
			var full_sz: Vector2 = font.get_string_size(full_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
			if full_sz.x <= avail_w:
				chosen_fsize = fsz
				chosen_label = full_label
				fits_full = true
				break
			fsz -= 1
		if not fits_full:
			var parts: PackedStringArray = upper_name.split(" ", false)
			var first_word: String = parts[0] if parts.size() > 0 else upper_name
			var short_label: String = "R.I.P. " + first_word
			chosen_label = short_label
			chosen_fsize = 8
			fsz = max_fsize
			while fsz >= 8:
				var short_sz: Vector2 = font.get_string_size(short_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
				if short_sz.x <= avail_w:
					chosen_fsize = fsz
					break
				fsz -= 1
		var final_sz: Vector2 = font.get_string_size(chosen_label, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen_fsize)
		var ascent: float = font.get_ascent(chosen_fsize)
		var descent: float = font.get_descent(chosen_fsize)
		var baseline_y: float = tag_rect.position.y + (tag_rect.size.y + ascent - descent) * 0.5
		if final_sz.x <= avail_w + 1.0:
			var draw_x: float = tag_rect.position.x + (tag_rect.size.x - final_sz.x) * 0.5
			canvas.draw_string(font, Vector2(draw_x, baseline_y), chosen_label, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen_fsize, PARCHMENT_LIGHT)
		else:
			canvas.draw_string(font, Vector2(tag_rect.position.x + pad_x * 0.5, baseline_y), chosen_label, HORIZONTAL_ALIGNMENT_CENTER, avail_w, chosen_fsize, PARCHMENT_LIGHT)

static func _draw_expedition_stamp(canvas: CanvasItem, rect: Rect2, u: float) -> void:
	var band_h: float = clampf(22.0 * u, 16.0, 32.0)
	var band_rect := Rect2(rect.position.x + 4.0, rect.end.y - band_h - 6.0, rect.size.x - 8.0, band_h)
	canvas.draw_rect(band_rect, HAZARD_YELLOW, true)
	canvas.draw_rect(band_rect, INK_COLOR, false, 2.0)
	# Hazard diagonal ticks on left & right
	canvas.draw_line(band_rect.position + Vector2(6, band_h - 2), band_rect.position + Vector2(14, 2), INK_COLOR, 2.5)
	canvas.draw_line(Vector2(band_rect.end.x - 14, band_rect.end.y - 2), Vector2(band_rect.end.x - 6, band_rect.position.y + 2), INK_COLOR, 2.5)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var fsize: int = maxi(8, int(11.0 * u))
		canvas.draw_string(
			font,
			Vector2(band_rect.position.x + 4.0, band_rect.position.y + band_h * 0.72),
			"OUT SCAVENGING",
			HORIZONTAL_ALIGNMENT_CENTER,
			band_rect.size.x - 8.0,
			fsize,
			INK_COLOR
		)

static func _draw_character_upper_body(
	canvas: CanvasItem,
	head_center: Vector2,
	shoulder_y: float,
	bottom_y: float,
	shoulder_w: float,
	hu: float,
	jaw_round: float,
	member: Dictionary,
	silhouette_mode: bool
) -> void:
	var is_mutant: bool = bool(member.get("is_mutant", false))
	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", get_role_for_age(age)))
	var hair_style: int = clampi(int(member.get("hair_style", 0)), 0, 7)
	var hair_col: Color = _safe_color(str(member.get("hair_color", "#4a2e1b")), Color("#4a2e1b"))
	var eye_col: Color = _safe_color(str(member.get("eye_color", "#2f5d8a")), Color("#2f5d8a"))
	var outfit_col: Color = _safe_color(str(member.get("outfit_color", "#c84b31")), Color("#c84b31"))
	var shirt_style: int = clampi(int(member.get("shirt_style", 0)), 0, 4)
	var facial_hair: int = clampi(int(member.get("facial_hair", 0)), 0, 3)
	var has_glasses: bool = bool(member.get("glasses", false))

	var hunger: int = int(member.get("hunger", 0))
	var thirst: int = int(member.get("thirst", 0))
	var sanity: int = int(member.get("sanity", 0))
	var sickness: int = int(member.get("sickness", 0))
	var injury: int = int(member.get("injury", 0))
	var fatigue: int = int(member.get("fatigue", 0))
	var soot_days: int = int(member.get("soot_days", 0))
	var breakdown_days: int = int(member.get("breakdown_days", 0))
	var hat_id: String = str(member.get("hat_id", "none"))

	var skin_col: Color = get_skin_color(member)
	if sickness >= 1 and not is_mutant:
		skin_col = skin_col.lerp(Color("#b6c98b"), 0.25)

	if silhouette_mode:
		var sil_col := Color("#2a2f2a")
		var sil_rim := Color("#555e52")
		_draw_hair_back(canvas, head_center, hu, hair_style, sil_col, sil_rim)
		_draw_torso_shirt(canvas, Vector2(head_center.x, shoulder_y), bottom_y, shoulder_w, hu, shirt_style, sil_col, sil_col.lightened(0.08), sil_rim)
		_draw_ellipse(canvas, head_center, 27.0 * hu * jaw_round, 33.0 * hu, sil_col)
		_draw_ellipse_outline(canvas, head_center, 27.0 * hu * jaw_round, 33.0 * hu, sil_rim, 2.0)
		_draw_hair_front(canvas, head_center, hu, hair_style, sil_col, sil_rim)
		# Stencil gas mask / binoculars icon hint on silhouette head
		canvas.draw_circle(head_center + Vector2(-9.0 * hu, -2.0 * hu), 5.5 * hu, HAZARD_YELLOW.darkened(0.2))
		canvas.draw_circle(head_center + Vector2(9.0 * hu, -2.0 * hu), 5.5 * hu, HAZARD_YELLOW.darkened(0.2))
		return

	# 1. Back hair layer
	_draw_hair_back(canvas, head_center, hu, hair_style, hair_col, INK_COLOR)

	# 2. Neck + Shoulders/Shirt (with fatigue droop & expedition soot/strap)
	var neck_w: float = (8.5 if (role == "child" or age <= 12) else 11.0) * hu
	var neck_rect := Rect2(head_center.x - neck_w, head_center.y + 22.0 * hu, neck_w * 2.0, maxf(12.0 * hu, shoulder_y - head_center.y - 16.0 * hu))
	canvas.draw_rect(neck_rect, skin_col.darkened(0.1), true)
	canvas.draw_line(neck_rect.position, Vector2(neck_rect.position.x, neck_rect.end.y), INK_COLOR, 2.0)
	canvas.draw_line(Vector2(neck_rect.end.x, neck_rect.position.y), neck_rect.end, INK_COLOR, 2.0)

	_draw_torso_shirt(canvas, Vector2(head_center.x, shoulder_y), bottom_y, shoulder_w, hu, shirt_style, outfit_col, skin_col, INK_COLOR, soot_days, fatigue)

	# 3. Mutant Antennae (behind upper head rim)
	if is_mutant:
		_draw_mutant_antennae(canvas, head_center, hu)

	# 4. Ears
	var ear_rx: float = 5.5 * hu
	var ear_ry: float = 8.5 * hu
	var head_rx: float = 27.0 * hu * jaw_round
	var head_ry: float = 33.0 * hu
	for side in [-1.0, 1.0]:
		var ear_pos := head_center + Vector2(side * (head_rx - 1.5 * hu), 2.0 * hu)
		_draw_ellipse(canvas, ear_pos, ear_rx, ear_ry, skin_col.darkened(0.06))
		_draw_ellipse_outline(canvas, ear_pos, ear_rx, ear_ry, INK_COLOR, 1.8)

	# 5. Head Shape (sculpted polygon for authentic 1950s jaw vs youthful roundness)
	var head_pts := PackedVector2Array()
	var segs: int = 28
	for i in range(segs):
		var ang: float = TAU * float(i) / float(segs)
		var ca: float = cos(ang)
		var sa: float = sin(ang)
		var rx_mod: float = head_rx
		if sa > 0.25 and role != "child" and age > 12:
			# Taper chin slightly for teens/adults/elders
			rx_mod *= lerpf(1.0, 0.84, (sa - 0.25) / 0.75)
		head_pts.append(head_center + Vector2(ca * rx_mod, sa * head_ry))
	_draw_poly_outlined(canvas, head_pts, skin_col, INK_COLOR, 2.2)

	# Mutant purple patches & glowing veins
	if is_mutant:
		_draw_ellipse(canvas, head_center + Vector2(-13.0 * hu, -10.0 * hu), 8.0 * hu, 6.0 * hu, Color(MUTANT_PURPLE.r, MUTANT_PURPLE.g, MUTANT_PURPLE.b, 0.55))
		_draw_ellipse(canvas, head_center + Vector2(14.0 * hu, 9.0 * hu), 7.0 * hu, 5.5 * hu, Color(MUTANT_PURPLE.r, MUTANT_PURPLE.g, MUTANT_PURPLE.b, 0.5))
		canvas.draw_line(head_center + Vector2(-17.0 * hu, -12.0 * hu), head_center + Vector2(-10.0 * hu, -6.0 * hu), MUTANT_PURPLE.lightened(0.15), 1.5)

	# 6. Condition overlays on cheeks/skin: Hunger gaunt hollows, Sickness green blush, Wasteland Soot, Youthful rosy blush, Elder wrinkles
	if hunger >= 2:
		var gaunt_col := Color(0.12, 0.09, 0.08, 0.34 if hunger == 2 else 0.48)
		for side in [-1.0, 1.0]:
			var gp := PackedVector2Array([
				head_center + Vector2(side * 19.0 * hu, 5.0 * hu),
				head_center + Vector2(side * 10.0 * hu, 10.0 * hu),
				head_center + Vector2(side * 14.0 * hu, 21.0 * hu),
				head_center + Vector2(side * 21.0 * hu, 15.0 * hu)
			])
			canvas.draw_colored_polygon(gp, gaunt_col)
			canvas.draw_line(head_center + Vector2(side * 18.0 * hu, 6.5 * hu), head_center + Vector2(side * 12.0 * hu, 18.0 * hu), Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.45), 1.4)

	if sickness >= 1:
		var sick_blush := Color(0.42, 0.78, 0.28, 0.42)
		_draw_ellipse(canvas, head_center + Vector2(-13.0 * hu, 7.0 * hu), 8.5 * hu, 5.0 * hu, sick_blush)
		_draw_ellipse(canvas, head_center + Vector2(13.0 * hu, 7.0 * hu), 8.5 * hu, 5.0 * hu, sick_blush)
		_draw_ellipse(canvas, head_center + Vector2(0.0, 3.5 * hu), 5.5 * hu, 3.5 * hu, sick_blush)
	elif (role == "child" or age <= 12) and not is_mutant:
		var warm_blush := Color(0.92, 0.42, 0.36, 0.24)
		_draw_ellipse(canvas, head_center + Vector2(-13.5 * hu, 6.5 * hu), 6.5 * hu, 3.8 * hu, warm_blush)
		_draw_ellipse(canvas, head_center + Vector2(13.5 * hu, 6.5 * hu), 6.5 * hu, 3.8 * hu, warm_blush)

	# Wasteland Expedition Wear: charcoal ash & soot smudges across cheeks, nose & brow
	if soot_days > 0:
		var soot_soft := Color(0.12, 0.11, 0.10, 0.42)
		var soot_streak := Color(0.10, 0.09, 0.08, 0.56)
		_draw_ellipse(canvas, head_center + Vector2(-15.0 * hu, 8.8 * hu), 7.2 * hu, 3.8 * hu, soot_soft)
		_draw_ellipse(canvas, head_center + Vector2(14.5 * hu, 10.5 * hu), 6.8 * hu, 3.5 * hu, soot_soft)
		_draw_ellipse(canvas, head_center + Vector2(1.0 * hu, 2.5 * hu), 4.6 * hu, 2.2 * hu, soot_soft)
		canvas.draw_line(head_center + Vector2(-19.5 * hu, 8.0 * hu), head_center + Vector2(-11.0 * hu, 10.2 * hu), soot_streak, 1.6 * maxf(hu, 0.65))
		canvas.draw_line(head_center + Vector2(11.5 * hu, 11.8 * hu), head_center + Vector2(19.0 * hu, 9.5 * hu), soot_streak, 1.5 * maxf(hu, 0.65))
		canvas.draw_line(head_center + Vector2(-11.0 * hu, -15.0 * hu), head_center + Vector2(-4.0 * hu, -13.5 * hu), soot_streak, 1.4 * maxf(hu, 0.65))

	if role == "elder" or age >= 60:
		var wr_col := Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.42)
		canvas.draw_line(head_center + Vector2(-10.0 * hu, -17.5 * hu), head_center + Vector2(10.0 * hu, -17.5 * hu), wr_col, 1.3)
		canvas.draw_line(head_center + Vector2(-8.0 * hu, -14.0 * hu), head_center + Vector2(8.0 * hu, -14.0 * hu), wr_col, 1.2)
		for side in [-1.0, 1.0]:
			# Crow's feet + nasolabial smile lines
			canvas.draw_line(head_center + Vector2(side * 17.5 * hu, -3.5 * hu), head_center + Vector2(side * 21.5 * hu, -5.0 * hu), wr_col, 1.2)
			canvas.draw_line(head_center + Vector2(side * 17.5 * hu, -1.5 * hu), head_center + Vector2(side * 21.5 * hu, -1.0 * hu), wr_col, 1.2)
			canvas.draw_line(head_center + Vector2(side * 7.5 * hu, 8.0 * hu), head_center + Vector2(side * 11.5 * hu, 16.5 * hu), wr_col, 1.3)

	# 7. Eyes, Under-Eye Fatigue Bags, Drooped Eyelids & Eyebrows
	var eye_y: float = head_center.y - 2.5 * hu
	var eye_sep: float = (9.5 if (role == "child" or age <= 12) else 10.5) * hu
	var base_eye_r: float = (5.3 if (role == "child" or age <= 12) else 4.6) * hu

	for idx in range(2):
		var side: float = -1.0 if idx == 0 else 1.0
		var epos := Vector2(head_center.x + side * eye_sep, eye_y)
		var er: float = base_eye_r
		if sanity >= 2:
			er = base_eye_r * (1.32 if idx == 0 else 0.92)

		# Heavy dark under-eye bags when fatigued (drawn slightly beneath sclera rim)
		if fatigue >= 1:
			var bag_alpha: float = 0.46 if fatigue == 1 else 0.60
			_draw_ellipse(canvas, epos + Vector2(0.0, er * 0.78), er * 1.15, er * 0.62, Color(0.17, 0.10, 0.17, bag_alpha))
			canvas.draw_arc(epos + Vector2(0.0, 0.8 * hu), er + 1.6 * hu, 0.20, PI - 0.20, 10, Color(0.15, 0.09, 0.14, 0.62), 1.5 * maxf(hu, 0.65))
			if fatigue >= 2:
				canvas.draw_arc(epos + Vector2(0.0, 2.2 * hu), er + 2.4 * hu, 0.30, PI - 0.30, 8, Color(0.15, 0.09, 0.14, 0.44), 1.2 * maxf(hu, 0.65))

		var sclera_col: Color = Color("#e8ff7a") if is_mutant else Color("#fbf8f1")
		canvas.draw_circle(epos, er, sclera_col)
		canvas.draw_arc(epos, er, 0.0, TAU, 18, INK_COLOR, 1.6)

		if sanity >= 2:
			# Mismatched spiral crazy pupils
			var p_off := Vector2(side * 1.0 * hu, (-1.0 if idx == 0 else 1.2) * hu)
			canvas.draw_arc(epos + p_off, er * 0.62, 0.0, PI * 1.65, 12, INK_COLOR, 1.5)
			canvas.draw_circle(epos + p_off, 1.6 * hu, ATOMIC_ORANGE if is_mutant else INK_COLOR)
		elif is_mutant:
			# Glowing mutant slit/compound eyes
			canvas.draw_circle(epos, er * 0.65, Color("#b829d9"))
			canvas.draw_rect(Rect2(epos.x - 1.1 * hu, epos.y - er * 0.6, 2.2 * hu, er * 1.2), INK_COLOR, true)
			canvas.draw_circle(epos + Vector2(-1.4 * hu, -1.4 * hu), 1.3 * hu, Color.WHITE)
		else:
			canvas.draw_circle(epos, er * 0.62, eye_col)
			canvas.draw_circle(epos, er * 0.32, INK_COLOR)
			canvas.draw_circle(epos + Vector2(-1.2 * hu, -1.3 * hu), 1.2 * hu, Color.WHITE)

		# Slightly drooped upper eyelids when fatigued
		if fatigue >= 1 and sanity < 2:
			var lid_col: Color = skin_col.darkened(0.12)
			var lid_pts := PackedVector2Array([
				epos + Vector2(-er * 1.02, -er * 0.16),
				epos + Vector2(-er * 0.72, -er * 0.92),
				epos + Vector2(0.0, -er * 1.04),
				epos + Vector2(er * 0.72, -er * 0.92),
				epos + Vector2(er * 1.02, -er * 0.10 + side * 0.35 * hu)
			])
			canvas.draw_colored_polygon(lid_pts, lid_col)
			canvas.draw_arc(epos, er, PI, TAU, 10, INK_COLOR, 1.4)
			canvas.draw_line(
				epos + Vector2(-er * 1.02, -er * 0.14),
				epos + Vector2(er * 1.02, -er * 0.08 + side * 0.35 * hu),
				INK_COLOR,
				1.7 * maxf(hu, 0.65)
			)

		# Eyebrows (distressed anguish angle during emotional breakdown!)
		var brow_col: Color = Color("#ececec") if (role == "elder" and hair_col.get_luminance() > 0.55) else hair_col.darkened(0.18)
		var left_pt: Vector2
		var right_pt: Vector2
		if breakdown_days > 0:
			# Inner corner raised sharply, outer corner dropped in distress
			var inner_y: float = eye_y - er - 5.4 * hu
			var outer_y: float = eye_y - er - 0.6 * hu
			if idx == 0:
				left_pt = Vector2(epos.x - 5.8 * hu, outer_y)
				right_pt = Vector2(epos.x + 5.6 * hu, inner_y)
			else:
				left_pt = Vector2(epos.x - 5.6 * hu, inner_y)
				right_pt = Vector2(epos.x + 5.8 * hu, outer_y)
		else:
			var brow_y0: float = eye_y - er - 3.2 * hu + (-2.5 * hu if (sanity >= 2 and idx == 0) else 0.0)
			var brow_y1: float = eye_y - er - 2.2 * hu + (2.0 * hu if (sanity >= 2 and idx == 1) else 0.0)
			if fatigue >= 1 and sanity < 2:
				if idx == 0:
					brow_y0 += 1.5 * hu
				else:
					brow_y1 += 1.5 * hu
			left_pt = Vector2(epos.x - 5.5 * hu, brow_y0)
			right_pt = Vector2(epos.x + 5.5 * hu, brow_y1)
		canvas.draw_line(left_pt, right_pt, brow_col, 2.3 * maxf(hu, 0.65))

		# Emotional Breakdown: trembling tear droplets welling & trickling down cheeks
		if breakdown_days > 0:
			var tear_fill := Color("#6ec8f7")
			var well_p := epos + Vector2(side * er * 0.72, er * 0.85)
			canvas.draw_circle(well_p, 1.9 * hu, tear_fill)
			var t1 := epos + Vector2(side * (er * 0.55 + 1.0 * hu), er + 5.4 * hu)
			var td1 := PackedVector2Array([
				t1 + Vector2(0.0, -3.6 * hu),
				t1 + Vector2(2.3 * hu, 1.2 * hu),
				t1 + Vector2(0.0, 3.0 * hu),
				t1 + Vector2(-2.3 * hu, 1.2 * hu)
			])
			_draw_poly_outlined(canvas, td1, tear_fill, INK_COLOR, 1.1)
			canvas.draw_circle(t1 + Vector2(-0.5 * hu, 0.6 * hu), maxf(0.8 * hu, 0.7), Color.WHITE)
			if idx == 1 or breakdown_days >= 2:
				var t2 := epos + Vector2(side * (er * 0.85 + 2.2 * hu), er + 12.6 * hu)
				var td2 := PackedVector2Array([
					t2 + Vector2(0.0, -2.8 * hu),
					t2 + Vector2(1.8 * hu, 1.0 * hu),
					t2 + Vector2(0.0, 2.4 * hu),
					t2 + Vector2(-1.8 * hu, 1.0 * hu)
				])
				_draw_poly_outlined(canvas, td2, tear_fill, INK_COLOR, 1.0)

	if breakdown_days > 0:
		# Furrowed grief lines between eyebrows
		var fur_col := Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.50)
		canvas.draw_line(head_center + Vector2(-2.0 * hu, -12.0 * hu), head_center + Vector2(-1.4 * hu, -7.8 * hu), fur_col, 1.3)
		canvas.draw_line(head_center + Vector2(2.0 * hu, -12.0 * hu), head_center + Vector2(1.4 * hu, -7.8 * hu), fur_col, 1.3)

	# 8. Nose
	var nose_pts := PackedVector2Array([
		head_center + Vector2(-0.5 * hu, -1.5 * hu),
		head_center + Vector2(3.8 * hu, 6.0 * hu),
		head_center + Vector2(-1.8 * hu, 7.2 * hu)
	])
	canvas.draw_polyline(nose_pts, INK_COLOR, 1.7)

	# 9. Facial Hair (under/around mouth)
	var mouth_y: float = head_center.y + 15.5 * hu
	if facial_hair == 3:
		# 5-o'clock Stubble dots
		var stub_col := Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.32)
		for sx in [-14, -10, -6, -2, 2, 6, 10, 14]:
			for sy in [11, 15, 19, 23]:
				if abs(sx) + (sy - 11) < 23:
					canvas.draw_circle(head_center + Vector2(float(sx) * hu, float(sy) * hu), 0.9 * hu, stub_col)
	elif facial_hair == 2:
		# Full Sculpted Beard
		var beard_pts := PackedVector2Array([
			head_center + Vector2(-22.0 * hu, 6.0 * hu),
			head_center + Vector2(-15.0 * hu, 12.0 * hu),
			head_center + Vector2(0.0, 11.5 * hu),
			head_center + Vector2(15.0 * hu, 12.0 * hu),
			head_center + Vector2(22.0 * hu, 6.0 * hu),
			head_center + Vector2(20.0 * hu, 22.0 * hu),
			head_center + Vector2(11.0 * hu, 33.5 * hu),
			head_center + Vector2(0.0, 36.0 * hu),
			head_center + Vector2(-11.0 * hu, 33.5 * hu),
			head_center + Vector2(-20.0 * hu, 22.0 * hu)
		])
		_draw_poly_outlined(canvas, beard_pts, hair_col, INK_COLOR, 1.9)

	# 10. Mouth + Parched Thirst Lips + Mutant Smirk + Breakdown Tremble + Sickness Thermometer
	if thirst >= 2:
		# Pale cracked parched lips + brow sweat drop
		var lip_col := Color("#dfd4c8")
		_draw_ellipse(canvas, Vector2(head_center.x, mouth_y), 7.5 * hu, 3.2 * hu, lip_col)
		_draw_ellipse_outline(canvas, Vector2(head_center.x, mouth_y), 7.5 * hu, 3.2 * hu, INK_COLOR, 1.4)
		canvas.draw_line(Vector2(head_center.x - 3.0 * hu, mouth_y - 2.5 * hu), Vector2(head_center.x - 2.0 * hu, mouth_y + 2.5 * hu), INK_COLOR, 1.0)
		canvas.draw_line(Vector2(head_center.x + 2.5 * hu, mouth_y - 2.5 * hu), Vector2(head_center.x + 1.8 * hu, mouth_y + 2.5 * hu), INK_COLOR, 1.0)
		# Sweat droplet on temple
		var sw := head_center + Vector2(17.5 * hu, -11.0 * hu)
		var sw_pts := PackedVector2Array([sw + Vector2(0, -4.5 * hu), sw + Vector2(3.0 * hu, 1.5 * hu), sw + Vector2(0, 4.0 * hu), sw + Vector2(-3.0 * hu, 1.5 * hu)])
		_draw_poly_outlined(canvas, sw_pts, Color("#6ec6f5"), INK_COLOR, 1.2)
	elif is_mutant:
		# Mischievous mutant smirk + little white fang
		canvas.draw_arc(Vector2(head_center.x, mouth_y - 3.0 * hu), 9.5 * hu, 0.15, PI - 0.25, 14, INK_COLOR, 2.2)
		var fang := PackedVector2Array([
			Vector2(head_center.x + 5.0 * hu, mouth_y + 3.2 * hu),
			Vector2(head_center.x + 7.2 * hu, mouth_y + 8.5 * hu),
			Vector2(head_center.x + 9.0 * hu, mouth_y + 2.2 * hu)
		])
		_draw_poly_outlined(canvas, fang, Color.WHITE, INK_COLOR, 1.3)
	elif sanity >= 2:
		# Zigzag unhinged grin
		var grin := PackedVector2Array([
			Vector2(head_center.x - 9.0 * hu, mouth_y - 1.0 * hu),
			Vector2(head_center.x - 4.0 * hu, mouth_y + 2.5 * hu),
			Vector2(head_center.x + 0.5 * hu, mouth_y - 0.5 * hu),
			Vector2(head_center.x + 5.0 * hu, mouth_y + 2.8 * hu),
			Vector2(head_center.x + 9.5 * hu, mouth_y - 2.0 * hu)
		])
		canvas.draw_polyline(grin, INK_COLOR, 2.0)
	elif breakdown_days > 0:
		# Quivering distressed sobbing frown
		var sob := PackedVector2Array([
			Vector2(head_center.x - 7.8 * hu, mouth_y + 3.2 * hu),
			Vector2(head_center.x - 3.5 * hu, mouth_y + 0.2 * hu),
			Vector2(head_center.x, mouth_y + 1.4 * hu),
			Vector2(head_center.x + 3.5 * hu, mouth_y + 0.2 * hu),
			Vector2(head_center.x + 7.8 * hu, mouth_y + 3.2 * hu)
		])
		canvas.draw_polyline(sob, Color("#f5eee6") if facial_hair == 2 else INK_COLOR, 2.0)
	elif hunger >= 2 or sickness >= 1 or fatigue >= 2:
		# Weak downturn frown
		canvas.draw_arc(Vector2(head_center.x, mouth_y + 5.5 * hu), 7.5 * hu, PI + 0.35, TAU - 0.35, 12, INK_COLOR, 2.0)
	else:
		# Classic warm 50s slight smile
		var mouth_fill: Color = Color("#f5eee6") if facial_hair == 2 else INK_COLOR
		canvas.draw_arc(Vector2(head_center.x, mouth_y - 2.5 * hu), 7.5 * hu, 0.25, PI - 0.25, 12, mouth_fill, 2.0)

	# 50s Mustache (drawn cleanly above upper lip for facial_hair 1 or 2)
	if facial_hair == 1 or facial_hair == 2:
		var stache_pts := PackedVector2Array([
			Vector2(head_center.x, mouth_y - 5.8 * hu),
			Vector2(head_center.x + 11.5 * hu, mouth_y - 2.5 * hu),
			Vector2(head_center.x + 9.5 * hu, mouth_y - 0.2 * hu),
			Vector2(head_center.x, mouth_y - 2.2 * hu),
			Vector2(head_center.x - 9.5 * hu, mouth_y - 0.2 * hu),
			Vector2(head_center.x - 11.5 * hu, mouth_y - 2.5 * hu)
		])
		_draw_poly_outlined(canvas, stache_pts, hair_col.darkened(0.06), INK_COLOR, 1.5)

	# Sickness Thermometer sticking out of mouth!
	if sickness >= 1:
		var th_start := Vector2(head_center.x + 3.0 * hu, mouth_y + 0.5 * hu)
		var th_end := Vector2(head_center.x + 22.0 * hu, mouth_y + 9.5 * hu)
		canvas.draw_line(th_start, th_end, INK_COLOR, 5.2 * hu)
		canvas.draw_line(th_start, th_end, Color.WHITE, 3.2 * hu)
		canvas.draw_line(th_start.lerp(th_end, 0.35), th_end, Color("#d93829"), 1.6 * hu)
		canvas.draw_circle(th_end, 2.8 * hu, Color("#d93829"))
		canvas.draw_arc(th_end, 2.8 * hu, 0.0, TAU, 10, INK_COLOR, 1.2)

	# 11. Retro 1950s Horn-Rimmed Glasses
	if has_glasses:
		_draw_horn_rimmed_glasses(canvas, head_center, eye_y, eye_sep, hu)

	# 12. Injury Cheek Plaster + Head Gauze Bandage
	if injury >= 1:
		# Cheek plaster with red spot
		var pl_rect := Rect2(head_center.x - 20.0 * hu, head_center.y + 6.5 * hu, 12.0 * hu, 5.2 * hu)
		canvas.draw_rect(pl_rect, Color("#f5f1e6"), true)
		canvas.draw_rect(pl_rect, INK_COLOR, false, 1.3)
		canvas.draw_circle(pl_rect.get_center(), 1.6 * hu, Color("#d93829"))

	# 13. Front Hair Layer
	_draw_hair_front(canvas, head_center, hu, hair_style, hair_col, INK_COLOR)

	# Injury forehead gauze wrap (drawn over forehead/hairline so it's unmistakable!)
	if injury >= 1:
		var gz_pts := PackedVector2Array([
			head_center + Vector2(-head_rx - 1.5 * hu, -14.0 * hu),
			head_center + Vector2(head_rx + 1.5 * hu, -19.0 * hu),
			head_center + Vector2(head_rx + 1.0 * hu, -9.0 * hu),
			head_center + Vector2(-head_rx - 1.0 * hu, -5.0 * hu)
		])
		_draw_poly_outlined(canvas, gz_pts, Color("#f7f4eb"), INK_COLOR, 1.8)
		canvas.draw_line(head_center + Vector2(-16.0 * hu, -10.0 * hu), head_center + Vector2(16.0 * hu, -14.0 * hu), Color("#d8d0c0"), 1.2)
		canvas.draw_circle(head_center + Vector2(9.0 * hu, -13.0 * hu), 3.4 * hu, Color("#d63629"))

	# 14. Sanity >= 3 Crooked Aluminum Tinfoil Hat OR Unlockable Survivor Hat!
	if sanity >= 3:
		_draw_tinfoil_hat(canvas, head_center, hu)
	elif hat_id != "" and hat_id != "none":
		_draw_survivor_hat(canvas, head_center, hu, jaw_round, hat_id)

static func _draw_mutant_antennae(canvas: CanvasItem, head_center: Vector2, hu: float) -> void:
	for side in [-1.0, 1.0]:
		var base := head_center + Vector2(side * 12.0 * hu, -29.0 * hu)
		var mid := head_center + Vector2(side * 20.0 * hu, -43.0 * hu)
		var tip := head_center + Vector2(side * 26.0 * hu, -48.0 * hu)
		canvas.draw_polyline(PackedVector2Array([base, mid, tip]), INK_COLOR, 4.4 * hu)
		canvas.draw_polyline(PackedVector2Array([base, mid, tip]), MUTANT_GREEN, 2.4 * hu)
		canvas.draw_circle(tip, 4.8 * hu, INK_COLOR)
		canvas.draw_circle(tip, 3.4 * hu, Color("#d8ff4a"))

static func _draw_horn_rimmed_glasses(canvas: CanvasItem, head_center: Vector2, eye_y: float, eye_sep: float, hu: float) -> void:
	var frame_col := Color("#211b18")
	var lens_tint := Color(0.82, 0.93, 0.98, 0.24)
	var gw: float = 15.0 * hu
	var gh: float = 11.5 * hu
	for side in [-1.0, 1.0]:
		var gx: float = head_center.x + side * eye_sep - gw * 0.5
		var gy: float = eye_y - gh * 0.52
		var grect := Rect2(gx, gy, gw, gh)
		canvas.draw_rect(grect, lens_tint, true)
		canvas.draw_rect(grect, frame_col, false, 2.0 * maxf(hu, 0.65))
		# Thick iconic 1950s browline upper bar with slight cat-eye outer wing
		var brow_bar := PackedVector2Array([
			Vector2(gx - (2.0 * hu if side < 0.0 else 0.0), gy - 1.5 * hu),
			Vector2(gx + gw + (2.0 * hu if side > 0.0 else 0.0), gy - 1.5 * hu),
			Vector2(gx + gw, gy + 2.4 * hu),
			Vector2(gx, gy + 2.4 * hu)
		])
		canvas.draw_colored_polygon(brow_bar, frame_col)
		# Lens diagonal glint
		canvas.draw_line(Vector2(gx + 3.0 * hu, gy + gh - 2.5 * hu), Vector2(gx + 7.5 * hu, gy + 3.0 * hu), Color(1, 1, 1, 0.6), 1.4)
	# Bridge
	canvas.draw_line(
		Vector2(head_center.x - eye_sep + gw * 0.5, eye_y - 1.5 * hu),
		Vector2(head_center.x + eye_sep - gw * 0.5, eye_y - 1.5 * hu),
		frame_col,
		2.2 * maxf(hu, 0.65)
	)

static func _draw_tinfoil_hat(canvas: CanvasItem, head_center: Vector2, hu: float) -> void:
	var brim_l := head_center + Vector2(-33.0 * hu, -17.0 * hu)
	var brim_r := head_center + Vector2(31.0 * hu, -23.0 * hu)
	var peak := head_center + Vector2(6.0 * hu, -56.0 * hu)
	var spire := head_center + Vector2(9.0 * hu, -66.0 * hu)
	var foil_pts := PackedVector2Array([
		brim_l,
		head_center + Vector2(-18.0 * hu, -40.0 * hu),
		peak,
		head_center + Vector2(21.0 * hu, -38.0 * hu),
		brim_r,
		head_center + Vector2(0.0, -22.0 * hu)
	])
	_draw_poly_outlined(canvas, foil_pts, Color("#cfd6dc"), INK_COLOR, 2.0)
	# Highlight facet + crinkle lines + crooked foil antenna twist
	var shine_pts := PackedVector2Array([
		brim_l,
		head_center + Vector2(-18.0 * hu, -40.0 * hu),
		peak,
		head_center + Vector2(-4.0 * hu, -20.0 * hu)
	])
	canvas.draw_colored_polygon(shine_pts, Color("#eef3f7"))
	canvas.draw_line(peak, spire, INK_COLOR, 3.2 * hu)
	canvas.draw_line(peak, spire, Color("#eef3f7"), 1.6 * hu)
	canvas.draw_line(head_center + Vector2(-14.0 * hu, -26.0 * hu), head_center + Vector2(8.0 * hu, -36.0 * hu), Color("#8d969e"), 1.4)
	canvas.draw_line(head_center + Vector2(-4.0 * hu, -21.0 * hu), head_center + Vector2(18.0 * hu, -28.0 * hu), Color("#8d969e"), 1.4)

static func _draw_survivor_hat(canvas: CanvasItem, head_center: Vector2, hu: float, jaw_round: float, hat_id: String) -> void:
	var hrx: float = 27.0 * hu * jaw_round
	match hat_id:
		"cd_helmet":
			# White 1950s Civil Defense steel Brodie helmet with red/blue CD triangle emblem
			var dome_pts := PackedVector2Array([
				head_center + Vector2(-hrx * 1.12, -19.0 * hu),
				head_center + Vector2(-hrx * 0.92, -37.0 * hu),
				head_center + Vector2(-hrx * 0.44, -47.0 * hu),
				head_center + Vector2(hrx * 0.44, -47.0 * hu),
				head_center + Vector2(hrx * 0.92, -37.0 * hu),
				head_center + Vector2(hrx * 1.12, -19.0 * hu)
			])
			_draw_poly_outlined(canvas, dome_pts, Color("#f2efe6"), INK_COLOR, 2.0)
			# Right dome steel shading + left specular gleam
			var dome_shade := PackedVector2Array([
				head_center + Vector2(hrx * 0.25, -46.0 * hu),
				head_center + Vector2(hrx * 0.90, -36.5 * hu),
				head_center + Vector2(hrx * 1.08, -19.5 * hu),
				head_center + Vector2(hrx * 0.35, -19.5 * hu)
			])
			canvas.draw_colored_polygon(dome_shade, Color("#cfd5da"))
			canvas.draw_line(head_center + Vector2(-hrx * 0.65, -36.0 * hu), head_center + Vector2(-hrx * 0.22, -43.0 * hu), Color.WHITE, 2.2 * hu)
			# Wide flared Brodie steel brim
			var brim_pts := PackedVector2Array([
				head_center + Vector2(-hrx * 1.44, -15.5 * hu),
				head_center + Vector2(-hrx * 0.85, -21.5 * hu),
				head_center + Vector2(hrx * 0.85, -21.5 * hu),
				head_center + Vector2(hrx * 1.44, -15.5 * hu),
				head_center + Vector2(hrx * 0.95, -14.0 * hu),
				head_center + Vector2(-hrx * 0.95, -14.0 * hu)
			])
			_draw_poly_outlined(canvas, brim_pts, Color("#e4e1d8"), INK_COLOR, 2.0)
			# Iconic Blue Circle + White Triangle + Red CD Mark on front dome
			var emb_c := head_center + Vector2(0.0, -32.5 * hu)
			var emb_r: float = 8.4 * hu
			canvas.draw_circle(emb_c, emb_r + 1.0 * hu, INK_COLOR)
			canvas.draw_circle(emb_c, emb_r, Color("#1f4e8c"))
			var tri := PackedVector2Array([
				emb_c + Vector2(0.0, -emb_r * 0.72),
				emb_c + Vector2(emb_r * 0.68, emb_r * 0.48),
				emb_c + Vector2(-emb_r * 0.68, emb_r * 0.48)
			])
			canvas.draw_colored_polygon(tri, Color("#faf8f2"))
			canvas.draw_circle(emb_c + Vector2(0.0, emb_r * 0.12), emb_r * 0.24, Color("#d93426"))

		"ushanka":
			# Warm brown/grey fur winter ear-flap hat
			var crown_pts := PackedVector2Array([
				head_center + Vector2(-hrx * 1.02, -22.0 * hu),
				head_center + Vector2(-hrx * 0.86, -44.0 * hu),
				head_center + Vector2(0.0, -48.0 * hu),
				head_center + Vector2(hrx * 0.86, -44.0 * hu),
				head_center + Vector2(hrx * 1.02, -22.0 * hu)
			])
			_draw_poly_outlined(canvas, crown_pts, Color("#6e4c30"), INK_COLOR, 2.0)
			# Furry grey-brown ear flaps hanging beside temples
			for side in [-1.0, 1.0]:
				var flap_pts := PackedVector2Array([
					head_center + Vector2(side * hrx * 0.90, -24.0 * hu),
					head_center + Vector2(side * hrx * 1.24, -18.0 * hu),
					head_center + Vector2(side * hrx * 1.20, 11.0 * hu),
					head_center + Vector2(side * hrx * 0.92, 13.0 * hu),
					head_center + Vector2(side * hrx * 0.84, -8.0 * hu)
				])
				_draw_poly_outlined(canvas, flap_pts, Color("#8a7d6f"), INK_COLOR, 1.9)
				canvas.draw_line(
					head_center + Vector2(side * hrx * 1.06, 12.5 * hu),
					head_center + Vector2(side * hrx * 1.12, 20.0 * hu),
					INK_COLOR,
					1.5
				)
			# Thick plush front shearling fur visor cuff
			var fur_rect := Rect2(head_center.x - hrx * 1.04, head_center.y - 36.5 * hu, hrx * 2.08, 18.5 * hu)
			canvas.draw_rect(fur_rect, Color("#9e9080"), true)
			canvas.draw_rect(fur_rect.grow(-2.2 * hu), Color("#b5a796"), true)
			canvas.draw_rect(fur_rect, INK_COLOR, false, 2.0)
			# Cozy Civil Defense / winter enamel star pin in center
			var pin_c := head_center + Vector2(0.0, -27.2 * hu)
			canvas.draw_circle(pin_c, 4.6 * hu, INK_COLOR)
			canvas.draw_circle(pin_c, 3.4 * hu, ATOMIC_ORANGE)
			canvas.draw_circle(pin_c, 1.4 * hu, HAZARD_YELLOW)

		"medic_cap":
			# Crisp white field medic cap with red medical cross
			var cap_pts := PackedVector2Array([
				head_center + Vector2(-hrx * 1.04, -18.0 * hu),
				head_center + Vector2(-hrx * 0.98, -39.0 * hu),
				head_center + Vector2(-hrx * 0.42, -46.5 * hu),
				head_center + Vector2(hrx * 0.42, -46.5 * hu),
				head_center + Vector2(hrx * 0.98, -39.0 * hu),
				head_center + Vector2(hrx * 1.04, -18.0 * hu)
			])
			_draw_poly_outlined(canvas, cap_pts, Color("#faf7f0"), INK_COLOR, 2.0)
			# Subtle visor bill & clean grey fold crease
			var bill_pts := PackedVector2Array([
				head_center + Vector2(-hrx * 0.96, -18.5 * hu),
				head_center + Vector2(hrx * 0.96, -18.5 * hu),
				head_center + Vector2(hrx * 0.78, -13.5 * hu),
				head_center + Vector2(-hrx * 0.78, -13.5 * hu)
			])
			_draw_poly_outlined(canvas, bill_pts, Color("#ded8ca"), INK_COLOR, 1.8)
			# Bold Red Medical Cross on front crown
			var mc := head_center + Vector2(0.0, -31.5 * hu)
			var al: float = 7.2 * hu
			var at: float = 2.8 * hu
			canvas.draw_circle(mc, 9.2 * hu, Color("#ffffff"))
			canvas.draw_arc(mc, 9.2 * hu, 0.0, TAU, 14, INK_COLOR, 1.3)
			canvas.draw_rect(Rect2(mc.x - at, mc.y - al, at * 2.0, al * 2.0), Color("#d93426"), true)
			canvas.draw_rect(Rect2(mc.x - al, mc.y - at, al * 2.0, at * 2.0), Color("#d93426"), true)

		"aviator":
			# Vintage brown leather bomber cap with brass flight goggles on forehead
			var av_pts := PackedVector2Array([
				head_center + Vector2(-hrx * 1.06, -16.0 * hu),
				head_center + Vector2(-hrx * 0.96, -38.0 * hu),
				head_center + Vector2(-hrx * 0.42, -46.0 * hu),
				head_center + Vector2(hrx * 0.42, -46.0 * hu),
				head_center + Vector2(hrx * 0.96, -38.0 * hu),
				head_center + Vector2(hrx * 1.06, -16.0 * hu)
			])
			_draw_poly_outlined(canvas, av_pts, Color("#6e4123"), INK_COLOR, 2.0)
			# Leather center seam & side ear tabs
			canvas.draw_line(head_center + Vector2(0.0, -46.0 * hu), head_center + Vector2(0.0, -18.0 * hu), Color("#4a2914"), 1.6)
			for side in [-1.0, 1.0]:
				var tab_pts := PackedVector2Array([
					head_center + Vector2(side * hrx * 0.90, -18.0 * hu),
					head_center + Vector2(side * hrx * 1.15, -12.0 * hu),
					head_center + Vector2(side * hrx * 1.10, 8.0 * hu),
					head_center + Vector2(side * hrx * 0.88, 5.0 * hu)
				])
				_draw_poly_outlined(canvas, tab_pts, Color("#5c351b"), INK_COLOR, 1.8)
			# Warm shearling fur brow trim
			canvas.draw_line(head_center + Vector2(-hrx * 0.96, -17.0 * hu), head_center + Vector2(hrx * 0.96, -17.0 * hu), Color("#dfd1b8"), 4.2 * hu)
			# Brass Flight Goggles resting on forehead!
			canvas.draw_line(head_center + Vector2(-hrx * 1.02, -26.5 * hu), head_center + Vector2(hrx * 1.02, -26.5 * hu), Color("#2b211b"), 3.6 * hu)
			for side in [-1.0, 1.0]:
				var gc := head_center + Vector2(side * 11.5 * hu, -27.5 * hu)
				_draw_ellipse(canvas, gc, 9.2 * hu, 6.8 * hu, INK_COLOR)
				_draw_ellipse(canvas, gc, 7.8 * hu, 5.5 * hu, HAZARD_YELLOW)
				_draw_ellipse(canvas, gc, 5.8 * hu, 3.9 * hu, Color("#5dbad9"))
				canvas.draw_line(gc + Vector2(-3.2 * hu, 1.5 * hu), gc + Vector2(1.8 * hu, -2.5 * hu), Color.WHITE, 1.4)
			canvas.draw_rect(Rect2(head_center.x - 3.0 * hu, head_center.y - 29.5 * hu, 6.0 * hu, 4.0 * hu), HAZARD_YELLOW, true)
			canvas.draw_rect(Rect2(head_center.x - 3.0 * hu, head_center.y - 29.5 * hu, 6.0 * hu, 4.0 * hu), INK_COLOR, false, 1.2)

static func _draw_hair_back(canvas: CanvasItem, head_center: Vector2, hu: float, style: int, hair_col: Color, outline: Color) -> void:
	var dark_hair := hair_col.darkened(0.18)
	match style:
		2: # Chin Bob
			var bob_pts := PackedVector2Array([
				head_center + Vector2(-31.0 * hu, -14.0 * hu),
				head_center + Vector2(0.0, -37.0 * hu),
				head_center + Vector2(31.0 * hu, -14.0 * hu),
				head_center + Vector2(34.0 * hu, 18.0 * hu),
				head_center + Vector2(22.0 * hu, 27.0 * hu),
				head_center + Vector2(-22.0 * hu, 27.0 * hu),
				head_center + Vector2(-34.0 * hu, 18.0 * hu)
			])
			_draw_poly_outlined(canvas, bob_pts, dark_hair, outline, 2.2)
		3: # High 1950s Beehive
			var hive_pts := PackedVector2Array([
				head_center + Vector2(-28.0 * hu, -12.0 * hu),
				head_center + Vector2(-24.0 * hu, -44.0 * hu),
				head_center + Vector2(-10.0 * hu, -56.0 * hu),
				head_center + Vector2(10.0 * hu, -56.0 * hu),
				head_center + Vector2(24.0 * hu, -44.0 * hu),
				head_center + Vector2(28.0 * hu, -12.0 * hu),
				head_center + Vector2(24.0 * hu, 10.0 * hu),
				head_center + Vector2(-24.0 * hu, 10.0 * hu)
			])
			_draw_poly_outlined(canvas, hive_pts, hair_col, outline, 2.2)
			# Beehive horizontal wrap lines
			canvas.draw_arc(head_center + Vector2(0, -34.0 * hu), 21.0 * hu, PI + 0.3, TAU - 0.3, 14, dark_hair, 2.0)
			canvas.draw_arc(head_center + Vector2(0, -44.0 * hu), 16.0 * hu, PI + 0.3, TAU - 0.3, 14, dark_hair, 2.0)
		4: # Twin Pigtails
			for side in [-1.0, 1.0]:
				var tail_pts := PackedVector2Array([
					head_center + Vector2(side * 25.0 * hu, -14.0 * hu),
					head_center + Vector2(side * 41.0 * hu, -6.0 * hu),
					head_center + Vector2(side * 45.0 * hu, 15.0 * hu),
					head_center + Vector2(side * 34.0 * hu, 24.0 * hu),
					head_center + Vector2(side * 25.0 * hu, 8.0 * hu)
				])
				_draw_poly_outlined(canvas, tail_pts, hair_col, outline, 2.0)
				# Ribbon tie
				canvas.draw_circle(head_center + Vector2(side * 28.0 * hu, -11.0 * hu), 4.2 * hu, HAZARD_YELLOW)
				canvas.draw_arc(head_center + Vector2(side * 28.0 * hu, -11.0 * hu), 4.2 * hu, 0.0, TAU, 10, outline, 1.4)
		5: # Voluminous Curly / Afro
			var puffs := [
				Vector2(0.0, -35.0), Vector2(-20.0, -30.0), Vector2(20.0, -30.0),
				Vector2(-31.0, -14.0), Vector2(31.0, -14.0), Vector2(-30.0, 4.0), Vector2(30.0, 4.0)
			]
			for p in puffs:
				canvas.draw_circle(head_center + p * hu, 16.5 * hu, outline)
			for p in puffs:
				canvas.draw_circle(head_center + p * hu, 14.5 * hu, hair_col)

static func _draw_hair_front(canvas: CanvasItem, head_center: Vector2, hu: float, style: int, hair_col: Color, outline: Color) -> void:
	var shine := hair_col.lightened(0.24)
	match style:
		0: # Classic 50s Side Part
			var pts := PackedVector2Array([
				head_center + Vector2(-28.0 * hu, -8.0 * hu),
				head_center + Vector2(-26.0 * hu, -27.0 * hu),
				head_center + Vector2(-8.0 * hu, -36.0 * hu),
				head_center + Vector2(16.0 * hu, -35.0 * hu),
				head_center + Vector2(28.0 * hu, -22.0 * hu),
				head_center + Vector2(28.0 * hu, -7.0 * hu),
				head_center + Vector2(23.0 * hu, -17.0 * hu),
				head_center + Vector2(-10.0 * hu, -19.0 * hu),
				head_center + Vector2(-15.0 * hu, -26.0 * hu),
				head_center + Vector2(-23.0 * hu, -16.0 * hu)
			])
			_draw_poly_outlined(canvas, pts, hair_col, outline, 2.0)
			canvas.draw_line(head_center + Vector2(-8.0 * hu, -30.0 * hu), head_center + Vector2(12.0 * hu, -28.0 * hu), shine, 2.2 * hu)
		1: # 50s Pompadour
			var pts := PackedVector2Array([
				head_center + Vector2(-28.0 * hu, -6.0 * hu),
				head_center + Vector2(-29.0 * hu, -28.0 * hu),
				head_center + Vector2(-14.0 * hu, -46.0 * hu),
				head_center + Vector2(14.0 * hu, -48.0 * hu),
				head_center + Vector2(30.0 * hu, -34.0 * hu),
				head_center + Vector2(28.0 * hu, -7.0 * hu),
				head_center + Vector2(22.0 * hu, -19.0 * hu),
				head_center + Vector2(4.0 * hu, -22.0 * hu),
				head_center + Vector2(-20.0 * hu, -18.0 * hu)
			])
			_draw_poly_outlined(canvas, pts, hair_col, outline, 2.1)
			canvas.draw_arc(head_center + Vector2(2.0 * hu, -32.0 * hu), 14.0 * hu, PI + 0.4, TAU - 0.5, 12, shine, 2.6 * hu)
		2: # Chin Bob Bangs
			var pts := PackedVector2Array([
				head_center + Vector2(-29.0 * hu, -12.0 * hu),
				head_center + Vector2(-22.0 * hu, -33.0 * hu),
				head_center + Vector2(0.0, -37.0 * hu),
				head_center + Vector2(22.0 * hu, -33.0 * hu),
				head_center + Vector2(29.0 * hu, -12.0 * hu),
				head_center + Vector2(18.0 * hu, -16.0 * hu),
				head_center + Vector2(2.0 * hu, -15.0 * hu),
				head_center + Vector2(-6.0 * hu, -21.0 * hu),
				head_center + Vector2(-18.0 * hu, -15.0 * hu)
			])
			_draw_poly_outlined(canvas, pts, hair_col, outline, 2.0)
			canvas.draw_line(head_center + Vector2(-12.0 * hu, -28.0 * hu), head_center + Vector2(12.0 * hu, -28.0 * hu), shine, 2.2 * hu)
		3: # High Beehive Swoop Bangs
			var pts := PackedVector2Array([
				head_center + Vector2(-28.0 * hu, -10.0 * hu),
				head_center + Vector2(-22.0 * hu, -30.0 * hu),
				head_center + Vector2(0.0, -34.0 * hu),
				head_center + Vector2(22.0 * hu, -30.0 * hu),
				head_center + Vector2(28.0 * hu, -10.0 * hu),
				head_center + Vector2(10.0 * hu, -19.0 * hu),
				head_center + Vector2(-14.0 * hu, -16.0 * hu)
			])
			_draw_poly_outlined(canvas, pts, hair_col, outline, 2.0)
		4: # Twin Pigtails Center-Part Bangs
			var pts := PackedVector2Array([
				head_center + Vector2(-28.0 * hu, -11.0 * hu),
				head_center + Vector2(-22.0 * hu, -32.0 * hu),
				head_center + Vector2(0.0, -35.0 * hu),
				head_center + Vector2(22.0 * hu, -32.0 * hu),
				head_center + Vector2(28.0 * hu, -11.0 * hu),
				head_center + Vector2(14.0 * hu, -16.0 * hu),
				head_center + Vector2(0.0, -24.0 * hu),
				head_center + Vector2(-14.0 * hu, -16.0 * hu)
			])
			_draw_poly_outlined(canvas, pts, hair_col, outline, 2.0)
		5: # Voluminous Curly Forehead Curls
			for cx_off in [-16.0, -5.0, 6.0, 17.0]:
				canvas.draw_circle(head_center + Vector2(cx_off * hu, -24.0 * hu), 8.2 * hu, hair_col)
				canvas.draw_arc(head_center + Vector2(cx_off * hu, -24.0 * hu), 8.2 * hu, 0.2, PI - 0.2, 8, outline, 1.6)
		6: # Buzz / Bald (subtle scalp hairline stipple + head shine)
			var buzz_col := Color(hair_col.r, hair_col.g, hair_col.b, 0.34)
			canvas.draw_arc(head_center + Vector2(0.0, -6.0 * hu), 23.0 * hu, PI + 0.35, TAU - 0.35, 16, buzz_col, 4.5 * hu)
			_draw_ellipse(canvas, head_center + Vector2(-8.0 * hu, -23.0 * hu), 6.0 * hu, 2.8 * hu, Color(1, 1, 1, 0.35))
		7: # Spiky Punk
			var pts := PackedVector2Array([
				head_center + Vector2(-27.0 * hu, -12.0 * hu),
				head_center + Vector2(-34.0 * hu, -30.0 * hu),
				head_center + Vector2(-19.0 * hu, -28.0 * hu),
				head_center + Vector2(-22.0 * hu, -48.0 * hu),
				head_center + Vector2(-7.0 * hu, -33.0 * hu),
				head_center + Vector2(1.0 * hu, -53.0 * hu),
				head_center + Vector2(10.0 * hu, -33.0 * hu),
				head_center + Vector2(24.0 * hu, -46.0 * hu),
				head_center + Vector2(20.0 * hu, -27.0 * hu),
				head_center + Vector2(34.0 * hu, -28.0 * hu),
				head_center + Vector2(27.0 * hu, -12.0 * hu),
				head_center + Vector2(10.0 * hu, -19.0 * hu),
				head_center + Vector2(-10.0 * hu, -19.0 * hu)
			])
			_draw_poly_outlined(canvas, pts, hair_col, outline, 2.0)

static func _draw_torso_shirt(
	canvas: CanvasItem,
	neck_base: Vector2,
	bottom_y: float,
	shoulder_w: float,
	hu: float,
	shirt_style: int,
	outfit_col: Color,
	skin_col: Color,
	outline: Color,
	soot_days: int = 0,
	fatigue: int = 0
) -> void:
	var h: float = maxf(18.0 * hu, bottom_y - neck_base.y)
	var sh_droop: float = (3.4 * hu) if fatigue >= 1 else 0.0
	var torso_pts := PackedVector2Array([
		neck_base + Vector2(-12.0 * hu, -2.0 * hu),
		neck_base + Vector2(12.0 * hu, -2.0 * hu),
		neck_base + Vector2(shoulder_w, 10.0 * hu + sh_droop),
		Vector2(neck_base.x + shoulder_w + 5.0 * hu, bottom_y),
		Vector2(neck_base.x - shoulder_w - 5.0 * hu, bottom_y),
		neck_base + Vector2(-shoulder_w, 10.0 * hu + sh_droop)
	])
	_draw_poly_outlined(canvas, torso_pts, outfit_col, outline, 2.2)

	match shirt_style:
		0: # Collared Shirt & Tie
			var v_pts := PackedVector2Array([
				neck_base + Vector2(-10.0 * hu, -2.0 * hu),
				neck_base + Vector2(10.0 * hu, -2.0 * hu),
				neck_base + Vector2(0.0, minf(bottom_y - neck_base.y, 20.0 * hu))
			])
			_draw_poly_outlined(canvas, v_pts, Color("#f5f0e4"), outline, 1.5)
			# Pointed collar wings
			for side in [-1.0, 1.0]:
				var col_pts := PackedVector2Array([
					neck_base + Vector2(side * 10.5 * hu, -2.5 * hu),
					neck_base + Vector2(side * 18.0 * hu, 9.0 * hu),
					neck_base + Vector2(side * 6.0 * hu, 12.0 * hu),
					neck_base + Vector2(0.0, 5.0 * hu)
				])
				_draw_poly_outlined(canvas, col_pts, outfit_col.lightened(0.28), outline, 1.5)
			# Tie
			var tie_col: Color = Color("#232824") if outfit_col.r > 0.55 else Color("#b8332a")
			var tie_end_y: float = minf(bottom_y, neck_base.y + h)
			var tie_pts := PackedVector2Array([
				neck_base + Vector2(-3.5 * hu, 5.0 * hu),
				neck_base + Vector2(3.5 * hu, 5.0 * hu),
				Vector2(neck_base.x + 5.5 * hu, tie_end_y),
				Vector2(neck_base.x - 5.5 * hu, tie_end_y)
			])
			_draw_poly_outlined(canvas, tie_pts, tie_col, outline, 1.4)
		1: # Knit Sweater
			# Thick ribbed crew collar + vertical cable-knit texture + chest stripe
			_draw_ellipse(canvas, neck_base + Vector2(0, 2.0 * hu), 13.5 * hu, 5.5 * hu, outfit_col.darkened(0.2))
			_draw_ellipse_outline(canvas, neck_base + Vector2(0, 2.0 * hu), 13.5 * hu, 5.5 * hu, outline, 1.6)
			var stripe_y: float = neck_base.y + minf(h * 0.52, 20.0 * hu)
			if stripe_y + 5.0 * hu < bottom_y:
				canvas.draw_line(
					Vector2(neck_base.x - shoulder_w * 0.88, stripe_y),
					Vector2(neck_base.x + shoulder_w * 0.88, stripe_y),
					HAZARD_YELLOW.lerp(Color.WHITE, 0.35),
					4.2 * hu
				)
			for kx in [-24, -12, 0, 12, 24]:
				var lx: float = neck_base.x + float(kx) * hu
				if abs(float(kx) * hu) < shoulder_w * 0.82:
					canvas.draw_line(Vector2(lx, neck_base.y + 9.0 * hu), Vector2(lx, bottom_y - 2.0), outfit_col.darkened(0.16), 1.3)
		2: # Polka / Retro 1950s Dress
			# Rounded Peter Pan white collar + cheerful polka dots
			_draw_ellipse(canvas, neck_base + Vector2(0, 1.5 * hu), 11.0 * hu, 4.5 * hu, skin_col.darkened(0.05))
			for side in [-1.0, 1.0]:
				_draw_ellipse(canvas, neck_base + Vector2(side * 9.0 * hu, 5.5 * hu), 9.5 * hu, 5.0 * hu, Color("#faf5ea"))
				_draw_ellipse_outline(canvas, neck_base + Vector2(side * 9.0 * hu, 5.5 * hu), 9.5 * hu, 5.0 * hu, outline, 1.5)
			var dot_col := Color(1, 1, 1, 0.72)
			var dot_offsets: Array[Vector2] = [
				Vector2(-22, 16), Vector2(-7, 19), Vector2(9, 17), Vector2(23, 16),
				Vector2(-15, 29), Vector2(0, 30), Vector2(16, 28), Vector2(-28, 28), Vector2(28, 28)
			]
			for dpos in dot_offsets:
				var dp: Vector2 = neck_base + dpos * hu
				if dp.y < bottom_y - 3.0 and absf(dpos.x * hu) < shoulder_w * 0.88:
					canvas.draw_circle(dp, 2.5 * hu, dot_col)
		3: # Ringer Tee
			var trim_col := Color("#f5efe2")
			_draw_ellipse(canvas, neck_base + Vector2(0, 2.0 * hu), 13.5 * hu, 5.5 * hu, trim_col)
			_draw_ellipse_outline(canvas, neck_base + Vector2(0, 2.0 * hu), 13.5 * hu, 5.5 * hu, outline, 1.6)
			_draw_ellipse(canvas, neck_base + Vector2(0, 0.8 * hu), 9.5 * hu, 3.5 * hu, skin_col.darkened(0.08))
			# Sleeve ringer bands + small CONELRAD chest atom badge
			canvas.draw_line(neck_base + Vector2(-shoulder_w + 4.0 * hu, 8.0 * hu), Vector2(neck_base.x - shoulder_w - 3.0 * hu, bottom_y), trim_col, 3.5 * hu)
			canvas.draw_line(neck_base + Vector2(shoulder_w - 4.0 * hu, 8.0 * hu), Vector2(neck_base.x + shoulder_w + 3.0 * hu, bottom_y), trim_col, 3.5 * hu)
			var badge_c := neck_base + Vector2(0.0, minf(19.0 * hu, h * 0.55))
			if badge_c.y + 6.0 * hu < bottom_y:
				canvas.draw_circle(badge_c, 6.0 * hu, HAZARD_YELLOW)
				canvas.draw_arc(badge_c, 6.0 * hu, 0.0, TAU, 12, outline, 1.4)
				canvas.draw_circle(badge_c, 2.0 * hu, outline)
		4: # Civil Defense Utility Jacket
			var lapel_col := outfit_col.darkened(0.22)
			for side in [-1.0, 1.0]:
				var lp := PackedVector2Array([
					neck_base + Vector2(side * 11.0 * hu, -2.0 * hu),
					neck_base + Vector2(side * 20.0 * hu, 8.0 * hu),
					neck_base + Vector2(side * 8.0 * hu, 18.0 * hu),
					neck_base + Vector2(0.0, 10.0 * hu)
				])
				_draw_poly_outlined(canvas, lp, lapel_col, outline, 1.5)
				# Epaulets
				var ep_rect := Rect2(neck_base.x + (side * 26.0 - 7.0) * hu, neck_base.y + 4.0 * hu, 14.0 * hu, 4.2 * hu)
				canvas.draw_rect(ep_rect, HAZARD_YELLOW.darkened(0.1), true)
				canvas.draw_rect(ep_rect, outline, false, 1.2)
			# Center zipper + utility chest pockets
			canvas.draw_line(neck_base + Vector2(0, 10.0 * hu), Vector2(neck_base.x, bottom_y), outline, 2.2)
			if neck_base.y + 27.0 * hu < bottom_y:
				for side in [-1.0, 1.0]:
					var pk := Rect2(neck_base.x + (side * 18.0 - 7.0) * hu, neck_base.y + 16.0 * hu, 14.0 * hu, 10.0 * hu)
					canvas.draw_rect(pk, lapel_col, true)
					canvas.draw_rect(pk, outline, false, 1.3)

	# Wasteland Expedition Wear: shoulder ash/soot smudges + rugged canvas expedition strap!
	if soot_days > 0:
		var ash_col := Color(0.11, 0.10, 0.09, 0.44)
		for side in [-1.0, 1.0]:
			var sm_c := neck_base + Vector2(side * shoulder_w * 0.68, 9.5 * hu + sh_droop * 0.6)
			if sm_c.y + 3.0 * hu < bottom_y:
				_draw_ellipse(canvas, sm_c, 9.5 * hu, 4.2 * hu, ash_col)
				canvas.draw_line(sm_c + Vector2(-5.5 * hu, -1.0 * hu), sm_c + Vector2(5.5 * hu, 1.4 * hu), Color(0.08, 0.08, 0.07, 0.55), 1.5 * maxf(hu, 0.65))

		var st_a := neck_base + Vector2(-shoulder_w * 0.62, 3.0 * hu + sh_droop * 0.4)
		var st_b := Vector2(neck_base.x + shoulder_w * 0.44, bottom_y)
		if st_b.y > st_a.y + 6.0 * hu:
			canvas.draw_line(st_a, st_b, outline, 7.6 * hu)
			canvas.draw_line(st_a, st_b, Color("#96825c"), 5.0 * hu)
			# Brass strap buckle on chest
			var bk_c: Vector2 = st_a.lerp(st_b, 0.46)
			var bk_r := Rect2(bk_c.x - 4.2 * hu, bk_c.y - 3.6 * hu, 8.4 * hu, 7.2 * hu)
			canvas.draw_rect(bk_r, HAZARD_YELLOW, true)
			canvas.draw_rect(bk_r, outline, false, 1.3)

# ==============================================================================
# 2. TOP-DOWN RENDERER (60-Second OSM House Scavenge & Family Screen Preview)
# ==============================================================================
static func draw_topdown_character(
	canvas: CanvasItem,
	pos: Vector2,
	facing: Vector2,
	member: Dictionary,
	walk_phase: float = 0.0,
	scale_f: float = 1.0
) -> void:
	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", get_role_for_age(age)))
	var role_scale: float = 1.0
	if role == "child" or age <= 12:
		role_scale = 0.74
	elif role == "teen" or age <= 17:
		role_scale = 0.88
	elif role == "elder" or age >= 60:
		role_scale = 0.94

	var s: float = scale_f * role_scale
	var fwd: Vector2 = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
	var right := Vector2(-fwd.y, fwd.x)

	var skin_col: Color = get_skin_color(member)
	var hair_style: int = clampi(int(member.get("hair_style", 0)), 0, 7)
	var hair_col: Color = _safe_color(str(member.get("hair_color", "#4a2e1b")), Color("#4a2e1b"))
	var eye_col: Color = _safe_color(str(member.get("eye_color", "#2f5d8a")), Color("#2f5d8a"))
	var outfit_col: Color = _safe_color(str(member.get("outfit_color", "#c84b31")), Color("#c84b31"))
	var shirt_style: int = clampi(int(member.get("shirt_style", 0)), 0, 4)
	var facial_hair: int = clampi(int(member.get("facial_hair", 0)), 0, 3)
	var has_glasses: bool = bool(member.get("glasses", false))
	var is_mutant: bool = bool(member.get("is_mutant", false))
	var sanity: int = int(member.get("sanity", 0))
	var injury: int = int(member.get("injury", 0))

	# 1. Soft drop shadow
	canvas.draw_circle(pos + Vector2(2.0, 3.0) * s, 16.5 * s, Color(0, 0, 0, 0.28))

	# 2. Animated feet
	var stride: float = sin(walk_phase) * 6.5 * s
	for side in [-1.0, 1.0]:
		var foot_pos: Vector2 = pos + right * (side * 7.5 * s) + fwd * (side * stride + 3.0 * s)
		canvas.draw_circle(foot_pos, 4.8 * s, Color("#2c2520"))
		canvas.draw_arc(foot_pos, 4.8 * s, 0.0, TAU, 10, INK_COLOR, 1.3)

	# 3. Retro Polka Dress flared hem if shirt_style == 2
	if shirt_style == 2:
		canvas.draw_circle(pos - fwd * 1.5 * s, 16.8 * s, outfit_col.darkened(0.08))
		canvas.draw_arc(pos - fwd * 1.5 * s, 16.8 * s, 0.0, TAU, 20, INK_COLOR, 1.6)

	# 4. Shoulders / Torso oriented capsule
	var sh_pts := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		sh_pts.append(pos + right * (cos(a) * 16.5 * s) + fwd * (sin(a) * 10.5 * s))
	_draw_poly_outlined(canvas, sh_pts, outfit_col, INK_COLOR, 2.0)

	# Top-down Shirt Style details
	match shirt_style:
		0: # Shirt & Tie (white collar + front tie strip)
			canvas.draw_line(pos + fwd * 4.0 * s, pos + fwd * 11.0 * s, Color("#232824") if outfit_col.r > 0.55 else Color("#b8332a"), 3.2 * s)
			canvas.draw_circle(pos + right * 5.0 * s + fwd * 4.0 * s, 2.5 * s, Color("#f5f0e4"))
			canvas.draw_circle(pos - right * 5.0 * s + fwd * 4.0 * s, 2.5 * s, Color("#f5f0e4"))
		1: # Knit Sweater (shoulder stripe)
			canvas.draw_line(pos - right * 14.0 * s, pos + right * 14.0 * s, HAZARD_YELLOW.lerp(Color.WHITE, 0.35), 3.0 * s)
		2: # Polka Dress dots on shoulders
			for side in [-1.0, 1.0]:
				canvas.draw_circle(pos + right * (side * 11.5 * s), 2.0 * s, Color.WHITE)
				canvas.draw_circle(pos + right * (side * 9.0 * s) - fwd * 6.0 * s, 1.8 * s, Color.WHITE)
		3: # Ringer Tee white shoulder bands
			for side in [-1.0, 1.0]:
				canvas.draw_line(pos + right * (side * 13.5 * s) - fwd * 5.0 * s, pos + right * (side * 13.5 * s) + fwd * 5.0 * s, Color("#f5efe2"), 2.6 * s)
		4: # Utility Jacket yellow epaulets
			for side in [-1.0, 1.0]:
				canvas.draw_line(pos + right * (side * 9.0 * s), pos + right * (side * 15.0 * s), HAZARD_YELLOW, 3.0 * s)

	# 5. Swinging arms & hands
	for side in [-1.0, 1.0]:
		var arm_swing: float = -side * sin(walk_phase) * 6.5 * s
		var shoulder_p: Vector2 = pos + right * (side * 15.0 * s)
		var hand_p: Vector2 = shoulder_p + fwd * (4.5 * s + arm_swing)
		var sleeve_col: Color = skin_col if (shirt_style == 2 or shirt_style == 3) else outfit_col.darkened(0.08)
		canvas.draw_line(shoulder_p, shoulder_p.lerp(hand_p, 0.65), INK_COLOR, 6.8 * s)
		canvas.draw_line(shoulder_p, shoulder_p.lerp(hand_p, 0.65), sleeve_col, 4.4 * s)
		canvas.draw_circle(hand_p, 3.8 * s, skin_col)
		canvas.draw_arc(hand_p, 3.8 * s, 0.0, TAU, 10, INK_COLOR, 1.3)

	# 6. Head circle + Facial Hair Chin Rim + Eyes + Glasses
	var head_p: Vector2 = pos + fwd * 1.5 * s
	var head_r: float = (12.2 if (role == "child" or age <= 12) else 11.4) * s

	# Twin pigtails or bob visible around head
	if hair_style == 4:
		for side in [-1.0, 1.0]:
			var tp: Vector2 = head_p + right * (side * 13.5 * s) - fwd * 3.0 * s
			canvas.draw_circle(tp, 5.2 * s, hair_col)
			canvas.draw_arc(tp, 5.2 * s, 0.0, TAU, 10, INK_COLOR, 1.5)
	elif hair_style == 5:
		canvas.draw_circle(head_p - fwd * 2.0 * s, head_r + 4.2 * s, hair_col)
		canvas.draw_arc(head_p - fwd * 2.0 * s, head_r + 4.2 * s, 0.0, TAU, 18, INK_COLOR, 1.8)

	canvas.draw_circle(head_p, head_r, skin_col)
	canvas.draw_arc(head_p, head_r, 0.0, TAU, 20, INK_COLOR, 2.0)

	# Facial hair visible on front chin edge
	if facial_hair == 2:
		var b_ang: float = fwd.angle()
		canvas.draw_arc(head_p, head_r - 1.2 * s, b_ang - 0.85, b_ang + 0.85, 10, hair_col, 3.6 * s)
	elif facial_hair == 1:
		canvas.draw_line(head_p + fwd * (head_r - 1.5 * s) - right * 4.5 * s, head_p + fwd * (head_r - 1.5 * s) + right * 4.5 * s, hair_col.darkened(0.1), 2.4 * s)
	elif facial_hair == 3:
		var st_ang: float = fwd.angle()
		canvas.draw_arc(head_p, head_r - 1.2 * s, st_ang - 0.75, st_ang + 0.75, 8, Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.35), 2.2 * s)

	# Elder wrinkle line on brow
	if role == "elder" or age >= 60:
		canvas.draw_line(head_p + fwd * (head_r * 0.45) - right * 4.5 * s, head_p + fwd * (head_r * 0.45) + right * 4.5 * s, Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.45), 1.1)

	# Eyes along facing vector
	for side in [-1.0, 1.0]:
		var ep: Vector2 = head_p + fwd * (head_r * 0.62) + right * (side * 4.2 * s)
		canvas.draw_circle(ep, 2.1 * s, Color("#e8ff7a") if is_mutant else Color.WHITE)
		canvas.draw_circle(ep + fwd * 0.5 * s, 1.2 * s, Color("#b829d9") if is_mutant else eye_col)

	# Horn-rimmed glasses visible from top-down
	if has_glasses:
		var gl_l: Vector2 = head_p + fwd * (head_r * 0.78) - right * 7.5 * s
		var gl_r: Vector2 = head_p + fwd * (head_r * 0.78) + right * 7.5 * s
		canvas.draw_line(gl_l, gl_r, Color("#1f1a17"), 2.5 * s)
		for side in [-1.0, 1.0]:
			canvas.draw_circle(head_p + fwd * (head_r * 0.72) + right * (side * 4.3 * s), 2.8 * s, Color(0.85, 0.95, 1.0, 0.35))

	# Top-down Hair Cap by hair_style
	match hair_style:
		0: # Side Part
			var cap_c: Vector2 = head_p - fwd * 2.2 * s
			canvas.draw_circle(cap_c, head_r * 0.92, hair_col)
			canvas.draw_arc(cap_c, head_r * 0.92, 0.0, TAU, 16, INK_COLOR, 1.6)
			canvas.draw_line(head_p - right * 5.0 * s - fwd * 7.0 * s, head_p - right * 4.0 * s + fwd * 4.0 * s, skin_col.darkened(0.1), 1.5 * s)
		1: # 50s Pompadour (prominent quiff projecting forward!)
			canvas.draw_circle(head_p - fwd * 2.0 * s, head_r * 0.94, hair_col)
			var quiff: Vector2 = head_p + fwd * 5.2 * s
			canvas.draw_circle(quiff, 6.8 * s, hair_col.lightened(0.12))
			canvas.draw_arc(quiff, 6.8 * s, 0.0, TAU, 12, INK_COLOR, 1.6)
		2: # Chin Bob
			var b_ang2: float = (-fwd).angle()
			canvas.draw_arc(head_p, head_r * 0.95, b_ang2 - 2.1, b_ang2 + 2.1, 16, hair_col, 5.5 * s)
			canvas.draw_circle(head_p - fwd * 2.5 * s, head_r * 0.85, hair_col)
		3: # High Beehive (concentric layered bun)
			canvas.draw_circle(head_p - fwd * 2.0 * s, head_r * 0.96, hair_col)
			canvas.draw_circle(head_p - fwd * 3.5 * s, head_r * 0.66, hair_col.lightened(0.14))
			canvas.draw_arc(head_p - fwd * 3.5 * s, head_r * 0.66, 0.0, TAU, 14, INK_COLOR, 1.6)
		4: # Twin Pigtails cap
			canvas.draw_circle(head_p - fwd * 2.2 * s, head_r * 0.88, hair_col)
			canvas.draw_line(head_p - fwd * 10.0 * s, head_p + fwd * 3.0 * s, INK_COLOR, 1.3)
		5: # Afro inner curl texture
			canvas.draw_circle(head_p - fwd * 1.5 * s, head_r * 0.95, hair_col.lightened(0.08))
		6: # Buzz / Bald
			canvas.draw_circle(head_p - fwd * 2.5 * s, head_r * 0.72, Color(hair_col.r, hair_col.g, hair_col.b, 0.28))
			canvas.draw_circle(head_p - fwd * 3.0 * s - right * 2.5 * s, 2.6 * s, Color(1, 1, 1, 0.35))
		7: # Spiky Punk star spikes
			var sp_pts := PackedVector2Array()
			for i in range(12):
				var a2: float = TAU * float(i) / 12.0
				var rad: float = (head_r + 4.8 * s) if (i % 2 == 0) else (head_r * 0.68)
				sp_pts.append(head_p - fwd * 1.5 * s + Vector2(cos(a2), sin(a2)) * rad)
			_draw_poly_outlined(canvas, sp_pts, hair_col, INK_COLOR, 1.5)

	if is_mutant:
		for side in [-1.0, 1.0]:
			var tip_p: Vector2 = head_p + right * (side * 11.5 * s) - fwd * 6.0 * s
			canvas.draw_line(head_p + right * (side * 5.0 * s), tip_p, MUTANT_GREEN, 2.0 * s)
			canvas.draw_circle(tip_p, 2.6 * s, Color("#d8ff4a"))

	if injury >= 1:
		canvas.draw_line(head_p - right * head_r, head_p + right * head_r, Color("#f7f4eb"), 3.4 * s)
		canvas.draw_circle(head_p + right * 3.5 * s, 1.8 * s, Color("#d63629"))

	if sanity >= 3:
		var hat_pts := PackedVector2Array([
			head_p - right * 11.0 * s,
			head_p - fwd * 12.0 * s,
			head_p + right * 11.0 * s,
			head_p + fwd * 4.0 * s
		])
		_draw_poly_outlined(canvas, hat_pts, Color("#dde4ea"), INK_COLOR, 1.5)
	else:
		var td_hat: String = str(member.get("hat_id", "none"))
		match td_hat:
			"cd_helmet":
				canvas.draw_circle(head_p - fwd * 0.5 * s, head_r * 1.18, Color("#f2efe6"))
				canvas.draw_arc(head_p - fwd * 0.5 * s, head_r * 1.18, 0.0, TAU, 18, INK_COLOR, 1.8)
				canvas.draw_circle(head_p + fwd * 2.5 * s, 3.6 * s, Color("#1f4e8c"))
				canvas.draw_circle(head_p + fwd * 2.5 * s, 1.6 * s, Color("#d93426"))
			"ushanka":
				canvas.draw_circle(head_p - fwd * 1.0 * s, head_r * 1.06, Color("#6e4c30"))
				canvas.draw_arc(head_p - fwd * 1.0 * s, head_r * 1.06, 0.0, TAU, 16, INK_COLOR, 1.7)
				canvas.draw_line(head_p + fwd * (head_r * 0.65) - right * 8.5 * s, head_p + fwd * (head_r * 0.65) + right * 8.5 * s, Color("#9e9080"), 4.2 * s)
			"medic_cap":
				canvas.draw_circle(head_p - fwd * 0.8 * s, head_r * 1.02, Color("#faf7f0"))
				canvas.draw_arc(head_p - fwd * 0.8 * s, head_r * 1.02, 0.0, TAU, 16, INK_COLOR, 1.7)
				var mc_td: Vector2 = head_p + fwd * 2.0 * s
				canvas.draw_line(mc_td - fwd * 3.2 * s, mc_td + fwd * 3.2 * s, Color("#d93426"), 2.2 * s)
				canvas.draw_line(mc_td - right * 3.2 * s, mc_td + right * 3.2 * s, Color("#d93426"), 2.2 * s)
			"aviator":
				canvas.draw_circle(head_p - fwd * 1.0 * s, head_r * 1.04, Color("#6e4123"))
				canvas.draw_arc(head_p - fwd * 1.0 * s, head_r * 1.04, 0.0, TAU, 16, INK_COLOR, 1.7)
				for side in [-1.0, 1.0]:
					var gp_td: Vector2 = head_p + fwd * (head_r * 0.56) + right * (side * 4.4 * s)
					canvas.draw_circle(gp_td, 2.8 * s, HAZARD_YELLOW)
					canvas.draw_circle(gp_td, 1.7 * s, Color("#5dbad9"))

# ==============================================================================
# 3. BUNKER SEATED FULL-BODY RENDERER (Bunker Survival Scene & Family Preview)
# ==============================================================================
static func draw_bunker_seated_character(
	canvas: CanvasItem,
	seat_pos: Vector2,
	member: Dictionary,
	anim_time: float = 0.0,
	scale_f: float = 1.0
) -> void:
	var alive: bool = bool(member.get("alive", true))
	var betrayed: bool = bool(member.get("betrayed", false))
	var on_expedition: bool = bool(member.get("on_expedition", false))
	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", get_role_for_age(age)))

	var s: float = scale_f
	if betrayed:
		# Betrayed empty seat: slashed cloth & crimson DESERTED placard
		canvas.draw_circle(seat_pos + Vector2(0, 26.0 * s), 22.0 * s, Color(0, 0, 0, 0.28))
		var rag_rect := Rect2(seat_pos.x - 19.0 * s, seat_pos.y - 6.0 * s, 38.0 * s, 9.0 * s)
		canvas.draw_rect(rag_rect, Color("#4a3834"), true)
		canvas.draw_rect(rag_rect, INK_COLOR, false, 1.6)
		canvas.draw_line(seat_pos + Vector2(-12.0 * s, -9.0 * s), seat_pos + Vector2(10.0 * s, 5.0 * s), Color("#b81b1a"), 2.4 * s)

		var post_a := seat_pos + Vector2(0.0, -6.0 * s)
		var post_b := seat_pos + Vector2(2.0 * s, -44.0 * s)
		canvas.draw_line(post_a, post_b, INK_COLOR, 4.0 * s)
		var sign_r := Rect2(seat_pos.x - 30.0 * s, seat_pos.y - 46.0 * s, 60.0 * s, 18.0 * s)
		canvas.draw_rect(sign_r, Color("#f2e4dc"), true)
		canvas.draw_rect(sign_r, Color("#b81b1a"), false, 2.2)
		var font_b: Font = ThemeDB.fallback_font
		if font_b != null:
			canvas.draw_string(font_b, Vector2(sign_r.position.x + 2, sign_r.position.y + 13.0 * s), "DESERTED", HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x - 4, maxi(8, int(9.5 * s)), Color("#b81b1a"))
		return

	if not alive:
		# Seated crate memorial: folded outfit + sepia wooden cross + name tag
		canvas.draw_circle(seat_pos + Vector2(0, 26.0 * s), 22.0 * s, Color(0, 0, 0, 0.28))
		var fold_rect := Rect2(seat_pos.x - 18.0 * s, seat_pos.y - 6.0 * s, 36.0 * s, 10.0 * s)
		var out_c: Color = _safe_color(str(member.get("outfit_color", "#6e5039")), Color("#6e5039")).lerp(Color("#6b6052"), 0.65)
		canvas.draw_rect(fold_rect, out_c, true)
		canvas.draw_rect(fold_rect, INK_COLOR, false, 1.8)
		var v_cross := Rect2(seat_pos.x - 4.5 * s, seat_pos.y - 54.0 * s, 9.0 * s, 48.0 * s)
		var h_cross := Rect2(seat_pos.x - 16.0 * s, seat_pos.y - 40.0 * s, 32.0 * s, 8.5 * s)
		canvas.draw_rect(v_cross, Color("#b8aa94"), true)
		canvas.draw_rect(h_cross, Color("#b8aa94"), true)
		canvas.draw_rect(v_cross, INK_COLOR, false, 1.8)
		canvas.draw_rect(h_cross, INK_COLOR, false, 1.8)
		return

	if on_expedition:
		# Ghostly stencil marker on empty seat showing member is outside scavenging
		var st_col := Color(HAZARD_YELLOW.r, HAZARD_YELLOW.g, HAZARD_YELLOW.b, 0.22)
		_draw_ellipse(canvas, seat_pos + Vector2(0, -24.0 * s), 20.0 * s, 24.0 * s, st_col)
		canvas.draw_circle(seat_pos + Vector2(0, -64.0 * s), 16.0 * s, st_col)
		var sign_r := Rect2(seat_pos.x - 28.0 * s, seat_pos.y - 34.0 * s, 56.0 * s, 16.0 * s)
		canvas.draw_rect(sign_r, HAZARD_YELLOW, true)
		canvas.draw_rect(sign_r, INK_COLOR, false, 1.6)
		var font: Font = ThemeDB.fallback_font
		if font != null:
			canvas.draw_string(font, Vector2(sign_r.position.x + 2, sign_r.position.y + 12.0 * s), "OUTSIDE", HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x - 4, maxi(8, int(9.5 * s)), INK_COLOR)
		return

	# Role proportions
	var body_s: float = 1.0
	var leg_len: float = 28.0
	var head_s: float = 0.88
	var shoulder_w: float = 26.0
	var jaw_round: float = 1.0
	var stoop_y: float = 0.0
	if role == "child" or age <= 12:
		body_s = 0.72
		leg_len = 17.0
		head_s = 0.80
		shoulder_w = 19.0
		jaw_round = 1.12
	elif role == "teen" or age <= 17:
		body_s = 0.88
		leg_len = 24.0
		head_s = 0.84
		shoulder_w = 22.5
		jaw_round = 1.04
	elif role == "elder" or age >= 60:
		body_s = 0.94
		leg_len = 26.0
		head_s = 0.86
		shoulder_w = 24.0
		jaw_round = 0.95
		stoop_y = 4.5

	var sanity: int = int(member.get("sanity", 0))
	var sickness: int = int(member.get("sickness", 0))
	var fatigue: int = int(member.get("fatigue", 0))
	var soot_days: int = int(member.get("soot_days", 0))
	var breakdown_days: int = int(member.get("breakdown_days", 0))
	if fatigue >= 1:
		stoop_y += minf(float(fatigue), 2.0) * 3.5

	var id_hash: float = float(str(member.get("id", "0")).hash() % 100) * 0.07
	var breath: float = sin(anim_time * 2.1 + id_hash) * 1.6 * s
	var jitter_x: float = 0.0
	if breakdown_days > 0:
		jitter_x = sin(anim_time * 24.0 + id_hash) * 1.5 * s
	elif sanity >= 2 or sickness >= 1:
		jitter_x = sin(anim_time * 19.0 + id_hash) * 1.2 * s

	var skin_col: Color = get_skin_color(member)
	if sickness >= 1 and not bool(member.get("is_mutant", false)):
		skin_col = skin_col.lerp(Color("#b6c98b"), 0.25)
	var outfit_col: Color = _safe_color(str(member.get("outfit_color", "#c84b31")), Color("#c84b31"))
	var shirt_style: int = clampi(int(member.get("shirt_style", 0)), 0, 4)
	var pants_col: Color = Color("#2f3847") if shirt_style != 2 else skin_col.darkened(0.06)

	# 1. Floor shadow under feet
	var foot_base_y: float = seat_pos.y + leg_len * s
	_draw_ellipse(canvas, Vector2(seat_pos.x, foot_base_y + 4.0 * s), 22.0 * s * body_s, 5.5 * s, Color(0, 0, 0, 0.32))

	# 2. Seated thighs, calves & shoes
	var hip_y: float = seat_pos.y
	var knee_sep: float = 9.5 * s * body_s
	for side in [-1.0, 1.0]:
		var hip_p := Vector2(seat_pos.x + side * 7.0 * s * body_s, hip_y - 2.0 * s)
		var knee_p := Vector2(seat_pos.x + side * knee_sep, hip_y + 5.0 * s)
		var ankle_p := Vector2(seat_pos.x + side * (knee_sep + 1.0 * s), foot_base_y)
		canvas.draw_line(hip_p, knee_p, INK_COLOR, 11.0 * s * body_s)
		canvas.draw_line(knee_p, ankle_p, INK_COLOR, 9.5 * s * body_s)
		canvas.draw_line(hip_p, knee_p, outfit_col if shirt_style == 2 else pants_col, 7.6 * s * body_s)
		canvas.draw_line(knee_p, ankle_p, pants_col, 6.2 * s * body_s)
		if soot_days > 0:
			_draw_ellipse(canvas, knee_p, 3.6 * s * body_s, 2.4 * s * body_s, Color(0.10, 0.09, 0.08, 0.45))
		# Classic 1950s saddle shoe / boot
		var shoe_pts := PackedVector2Array([
			ankle_p + Vector2(-4.5 * s, -2.0 * s),
			ankle_p + Vector2(5.5 * s * side + 3.0 * s, 0.5 * s),
			ankle_p + Vector2(5.5 * s * side + 3.0 * s, 4.8 * s),
			ankle_p + Vector2(-4.5 * s, 4.8 * s)
		])
		_draw_poly_outlined(canvas, shoe_pts, Color("#26201c"), INK_COLOR, 1.5)

	if shirt_style == 2:
		# Retro polka skirt draped over knees
		var sk_pts := PackedVector2Array([
			Vector2(seat_pos.x - 16.0 * s * body_s, hip_y - 4.0 * s),
			Vector2(seat_pos.x + 16.0 * s * body_s, hip_y - 4.0 * s),
			Vector2(seat_pos.x + 20.0 * s * body_s, hip_y + 11.0 * s),
			Vector2(seat_pos.x - 20.0 * s * body_s, hip_y + 11.0 * s)
		])
		_draw_poly_outlined(canvas, sk_pts, outfit_col, INK_COLOR, 1.8)
		canvas.draw_circle(Vector2(seat_pos.x - 8.0 * s, hip_y + 4.0 * s), 1.8 * s, Color.WHITE)
		canvas.draw_circle(Vector2(seat_pos.x + 7.0 * s, hip_y + 5.0 * s), 1.8 * s, Color.WHITE)

	# 3. Torso + Upper Body + Head (reusing exact portrait anatomy scaled cleanly!)
	var torso_h: float = 36.0 * s * body_s
	var neck_y: float = hip_y - torso_h + stoop_y * s + breath
	var head_c := Vector2(seat_pos.x + jitter_x, neck_y - 24.0 * s * head_s)

	_draw_character_upper_body(
		canvas,
		head_c,
		neck_y,
		hip_y + 1.0 * s,
		shoulder_w * s,
		head_s * s * 0.62,
		jaw_round,
		member,
		false
	)

	# 4. Seated Arms & Hands resting on knees
	var arm_slump: float = (2.2 * s) if fatigue >= 1 else 0.0
	for side in [-1.0, 1.0]:
		var sh_p := Vector2(seat_pos.x + jitter_x + side * (shoulder_w * 0.88 * s), neck_y + 6.0 * s + arm_slump)
		var elbow_p := Vector2(seat_pos.x + side * (shoulder_w * 1.02 * s), hip_y - 9.0 * s + breath * 0.5)
		var hand_p := Vector2(seat_pos.x + side * (knee_sep + 1.5 * s), hip_y + 3.0 * s)
		var sl_col: Color = skin_col if (shirt_style == 2 or shirt_style == 3) else outfit_col.darkened(0.08)
		canvas.draw_line(sh_p, elbow_p, INK_COLOR, 8.2 * s * body_s)
		canvas.draw_line(sh_p, elbow_p, sl_col, 5.4 * s * body_s)
		canvas.draw_line(elbow_p, hand_p, INK_COLOR, 7.2 * s * body_s)
		canvas.draw_line(elbow_p, hand_p, skin_col if shirt_style == 3 else sl_col, 4.6 * s * body_s)
		canvas.draw_circle(hand_p, 4.2 * s * body_s, skin_col)
		canvas.draw_arc(hand_p, 4.2 * s * body_s, 0.0, TAU, 10, INK_COLOR, 1.4)

# ==============================================================================
# 4. RELATIONSHIP SPEECH BUBBLE RENDERER (Heart, Lightning Bolt, Question, Wrench)
# ==============================================================================
static func draw_relationship_bubble(canvas: CanvasItem, center: Vector2, symbol: String, accent: Color) -> void:
	if canvas == null:
		return

	var bw: float = 36.0
	var bh: float = 28.0
	var bx: float = center.x - bw * 0.5
	var by: float = center.y - bh * 0.5

	# Soft comic drop shadow
	_draw_ellipse(canvas, center + Vector2(2.0, 3.0), bw * 0.52, bh * 0.52, Color(0.0, 0.0, 0.0, 0.30), 18)

	# Rounded comic speech bubble polygon with downward pointer tail
	var r: float = 8.0
	var bub_pts := PackedVector2Array([
		Vector2(bx + r, by),
		Vector2(bx + bw - r, by),
		Vector2(bx + bw, by + r),
		Vector2(bx + bw, by + bh - r),
		Vector2(bx + bw - r, by + bh),
		Vector2(center.x + 5.5, by + bh),
		Vector2(center.x - 1.5, by + bh + 8.5),
		Vector2(center.x - 5.5, by + bh),
		Vector2(bx + r, by + bh),
		Vector2(bx, by + bh - r),
		Vector2(bx, by + r)
	])
	_draw_poly_outlined(canvas, bub_pts, Color("#faf4e6"), INK_COLOR, 2.2)

	# Subtle accent inner rim along top/sides
	var inner_rim := Color(accent.r, accent.g, accent.b, 0.55)
	canvas.draw_line(Vector2(bx + r, by + 2.5), Vector2(bx + bw - r, by + 2.5), inner_rim, 1.5)

	var clean_sym: String = symbol.strip_edges().to_lower()
	var ic: Vector2 = center

	if clean_sym in ["heart", "bond", "love", "cooperate", "+", "♥", "<3"]:
		# Plump comic Heart icon
		var l_lobe := ic + Vector2(-3.8, -2.5)
		var r_lobe := ic + Vector2(3.8, -2.5)
		canvas.draw_circle(l_lobe, 5.2, INK_COLOR)
		canvas.draw_circle(r_lobe, 5.2, INK_COLOR)
		var tip_bg := PackedVector2Array([
			ic + Vector2(-8.6, -0.8),
			ic + Vector2(8.6, -0.8),
			ic + Vector2(0.0, 8.8)
		])
		canvas.draw_colored_polygon(tip_bg, INK_COLOR)
		canvas.draw_circle(l_lobe, 3.8, accent)
		canvas.draw_circle(r_lobe, 3.8, accent)
		var tip_fg := PackedVector2Array([
			ic + Vector2(-7.0, -0.5),
			ic + Vector2(7.0, -0.5),
			ic + Vector2(0.0, 7.0)
		])
		canvas.draw_colored_polygon(tip_fg, accent)
		canvas.draw_circle(l_lobe + Vector2(-1.2, -1.2), 1.2, Color.WHITE)

	elif clean_sym in ["bolt", "lightning", "argument", "fight", "anger", "conflict", "!", "⚡"]:
		# Jagged Lightning Bolt icon
		var bolt := PackedVector2Array([
			ic + Vector2(2.2, -9.0),
			ic + Vector2(-6.2, 0.8),
			ic + Vector2(-0.8, 0.8),
			ic + Vector2(-3.0, 9.2),
			ic + Vector2(6.2, -1.0),
			ic + Vector2(0.8, -1.0)
		])
		_draw_poly_outlined(canvas, bolt, accent, INK_COLOR, 1.6)

	elif clean_sym in ["wrench", "repair", "tool", "fix", "work", "craft"]:
		# Crossed Mechanic's Wrench icon
		var dir := Vector2(0.7071, -0.7071)
		var perp := Vector2(0.7071, 0.7071)
		var sh_pts := PackedVector2Array([
			ic - dir * 5.5 - perp * 2.0,
			ic + dir * 5.5 - perp * 2.0,
			ic + dir * 5.5 + perp * 2.0,
			ic - dir * 5.5 + perp * 2.0
		])
		_draw_poly_outlined(canvas, sh_pts, accent, INK_COLOR, 1.5)
		for sgn in [-1.0, 1.0]:
			var hc: Vector2 = ic + dir * (float(sgn) * 6.2)
			canvas.draw_circle(hc, 4.2, INK_COLOR)
			canvas.draw_circle(hc, 2.9, accent)
			canvas.draw_circle(hc + dir * (float(sgn) * 1.8), 1.5, Color("#faf4e6"))

	else:
		# Crisp Question Mark icon ("question", "?", or fallback)
		canvas.draw_arc(ic + Vector2(0.0, -3.5), 4.6, PI * 0.92, TAU + PI * 0.30, 14, INK_COLOR, 4.4)
		canvas.draw_arc(ic + Vector2(0.0, -3.5), 4.6, PI * 0.92, TAU + PI * 0.30, 14, accent, 2.4)
		canvas.draw_line(ic + Vector2(2.5, -0.2), ic + Vector2(0.0, 3.2), INK_COLOR, 4.2)
		canvas.draw_line(ic + Vector2(2.5, -0.2), ic + Vector2(0.0, 3.2), accent, 2.2)
		canvas.draw_circle(ic + Vector2(0.0, 7.2), 2.3, INK_COLOR)
		canvas.draw_circle(ic + Vector2(0.0, 7.2), 1.3, accent)
