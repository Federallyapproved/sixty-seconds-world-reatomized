class_name CharacterArtist
extends RefCounted

## Procedural character illustrator (present-day clothes: hoodies, fleeces, tees, rain jackets).
## Renders consistent custom family members across the Family Creator, the 60-second grab
## (top-down), and the shelter (seated full-body & portraits) with their runtime conditions.

const INK_COLOR := Color("#14171c")
const CARD_LIGHT := Color("#e8eaed")
const CARD_MUTED := Color("#9aa3ad")
const ALERT_AMBER := Color("#ffb020")
const ALERT_RED := Color("#ff4d4f")
const PANEL_SLATE := Color("#262c34")
const CARD_BG := Color("#262c34")
const CARD_BG_DIM := Color("#1a1e24")
const CARD_BORDER := Color("#39414b")
const SICK_SKIN := Color("#c9c4bc")

const SKIN_TONES: Array[String] = [
	"#f7dac4", # 0: Porcelain Warm
	"#ecc19c", # 1: Peach Ivory
	"#d7a176", # 2: Golden Tan
	"#b87b50", # 3: Warm Bronze
	"#8b5433", # 4: Rich Umber
	"#59331e"  # 5: Deep Espresso
]

const HAIR_STYLE_NAMES: Array[String] = [
	"Side Part",
	"Quiff",
	"Bob",
	"High Bun",
	"Pigtails",
	"Curly Afro",
	"Buzz Cut",
	"Spiky"
]

const FACIAL_HAIR_NAMES: Array[String] = [
	"None",
	"Mustache",
	"Full Beard",
	"Stubble"
]

const SHIRT_STYLE_NAMES: Array[String] = [
	"Hoodie",
	"Quarter-Zip Fleece",
	"T-Shirt Dress",
	"Graphic Tee",
	"Rain Jacket"
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
	"#2bc4d8", # Teal Dye
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
	"#c84b31", # Signal Red
	"#3d7a8a", # Teal Blue
	"#d99b26", # Mustard Gold
	"#557a46", # Olive
	"#7b4b94", # Plum Purple
	"#d46a84", # Coral Rose
	"#3b4d6b", # Navy Denim
	"#6e5039"  # Tan Brown
]

static func get_skin_color(member: Dictionary) -> Color:
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
	var on_expedition: bool = bool(member.get("on_expedition", false))

	if show_frame:
		# Shadow + dark contact-card background with a soft backlight behind the head
		canvas.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.30), true)
		canvas.draw_rect(rect, CARD_BG_DIM if not alive else CARD_BG, true)
		var glow_c := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.47)
		var glow_r: float = minf(rect.size.x, rect.size.y) * 0.42
		if alive:
			canvas.draw_circle(glow_c, glow_r, Color("#323a45"))
			canvas.draw_circle(glow_c, glow_r * 0.72, Color("#3b4450"))

	if not alive:
		_draw_deceased_memorial(canvas, rect, member)
		if show_frame:
			canvas.draw_rect(rect, CARD_BORDER, false, 1.5)
		return

	var u: float = minf(rect.size.x, rect.size.y) / 160.0
	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", get_role_for_age(age)))

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

	var center_x: float = rect.position.x + rect.size.x * 0.5
	var bottom_y: float = rect.position.y + rect.size.y - (5.0 * u if show_frame else 0.0)
	var shoulder_y: float = rect.position.y + rect.size.y * 0.72 + y_shift * 0.45
	var head_center := Vector2(center_x, rect.position.y + rect.size.y * 0.43 + y_shift)

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
		canvas.draw_rect(rect, CARD_BORDER, false, 1.5)

static func _draw_deceased_memorial(canvas: CanvasItem, rect: Rect2, member: Dictionary) -> void:
	var u: float = minf(rect.size.x, rect.size.y) / 160.0
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.52
	var grey_dark := Color("#2b313a")
	var grey_mid := Color("#4b5560")
	var grey_light := Color("#7d8794")

	# Faded silhouette behind the stone
	_draw_ellipse(canvas, Vector2(cx, rect.end.y - 22.0 * u), 38.0 * u, 20.0 * u, Color(grey_mid.r, grey_mid.g, grey_mid.b, 0.42))
	canvas.draw_circle(Vector2(cx + 4.0 * u, cy - 18.0 * u), 20.0 * u, Color(grey_mid.r, grey_mid.g, grey_mid.b, 0.35))

	# Plain rounded headstone
	var stone_w: float = 46.0 * u
	var stone_top: float = cy - 38.0 * u
	var stone_bot: float = cy + 34.0 * u
	var stone_pts := PackedVector2Array()
	for i in range(13):
		var a: float = PI + PI * float(i) / 12.0
		stone_pts.append(Vector2(cx, stone_top + stone_w * 0.5) + Vector2(cos(a), sin(a)) * stone_w * 0.5)
	stone_pts.append(Vector2(cx + stone_w * 0.5, stone_bot))
	stone_pts.append(Vector2(cx - stone_w * 0.5, stone_bot))
	var shadow_pts := PackedVector2Array()
	for sp in stone_pts:
		shadow_pts.append(sp + Vector2(2.0, 3.0) * u)
	canvas.draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.22))
	_draw_poly_outlined(canvas, stone_pts, grey_light, grey_dark, 2.2 * u)

	# A small flower laid at the stone
	var fl := Vector2(cx - 10.0 * u, stone_bot - 2.0 * u)
	canvas.draw_line(fl, fl + Vector2(6.0, -10.0) * u, Color("#4cc38a"), 1.6 * u)
	canvas.draw_circle(fl + Vector2(6.0, -11.0) * u, 3.0 * u, Color("#f0a35e"))

	# Ground at base
	_draw_ellipse(canvas, Vector2(cx, cy + 36.0 * u), 34.0 * u, 9.0 * u, grey_dark)

	# R.I.P. banner (90% portrait width with dynamic font step-down so multi-word names never truncate)
	var tag_h: float = maxf(15.0, 18.0 * u)
	var tag_y: float = rect.end.y - tag_h - maxf(5.0, 7.0 * u)
	var tag_rect := Rect2(rect.position.x + rect.size.x * 0.05, tag_y, rect.size.x * 0.90, tag_h)
	canvas.draw_rect(tag_rect, grey_dark, true)
	canvas.draw_rect(tag_rect, CARD_BORDER, false, 1.0)
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
			canvas.draw_string(font, Vector2(draw_x, baseline_y), chosen_label, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen_fsize, CARD_LIGHT)
		else:
			canvas.draw_string(font, Vector2(tag_rect.position.x + pad_x * 0.5, baseline_y), chosen_label, HORIZONTAL_ALIGNMENT_CENTER, avail_w, chosen_fsize, CARD_LIGHT)

static func _draw_expedition_stamp(canvas: CanvasItem, rect: Rect2, u: float) -> void:
	var band_h: float = clampf(22.0 * u, 16.0, 32.0)
	var band_rect := Rect2(rect.position.x + 4.0, rect.end.y - band_h - 6.0, rect.size.x - 8.0, band_h)
	canvas.draw_rect(band_rect, ALERT_AMBER, true)
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
			"AWAY",
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

	var skin_col: Color = get_skin_color(member)
	if sickness >= 1:
		skin_col = skin_col.lerp(SICK_SKIN, 0.22)
	# "Withdrawn" (low morale) shows as tired, downcast eyes and a flat mouth.
	var withdrawn: bool = sanity >= 2

	if silhouette_mode:
		var sil_col := Color("#2b323b")
		var sil_rim := Color("#4b5560")
		_draw_hair_back(canvas, head_center, hu, hair_style, sil_col, sil_rim)
		_draw_torso_shirt(canvas, Vector2(head_center.x, shoulder_y), bottom_y, shoulder_w, hu, shirt_style, sil_col, sil_col.lightened(0.08), sil_rim)
		_draw_ellipse(canvas, head_center, 27.0 * hu * jaw_round, 33.0 * hu, sil_col)
		_draw_ellipse_outline(canvas, head_center, 27.0 * hu * jaw_round, 33.0 * hu, sil_rim, 2.0)
		_draw_hair_front(canvas, head_center, hu, hair_style, sil_col, sil_rim)
		# Gas-mask eyepiece hint on the silhouette head
		canvas.draw_circle(head_center + Vector2(-9.0 * hu, -2.0 * hu), 5.5 * hu, ALERT_AMBER.darkened(0.2))
		canvas.draw_circle(head_center + Vector2(9.0 * hu, -2.0 * hu), 5.5 * hu, ALERT_AMBER.darkened(0.2))
		return

	# 1. Back hair layer
	_draw_hair_back(canvas, head_center, hu, hair_style, hair_col, INK_COLOR)

	# 2. Neck + Shoulders/Shirt
	var neck_w: float = (8.5 if (role == "child" or age <= 12) else 11.0) * hu
	var neck_rect := Rect2(head_center.x - neck_w, head_center.y + 22.0 * hu, neck_w * 2.0, maxf(12.0 * hu, shoulder_y - head_center.y - 16.0 * hu))
	canvas.draw_rect(neck_rect, skin_col.darkened(0.1), true)
	canvas.draw_line(neck_rect.position, Vector2(neck_rect.position.x, neck_rect.end.y), INK_COLOR, 2.0)
	canvas.draw_line(Vector2(neck_rect.end.x, neck_rect.position.y), neck_rect.end, INK_COLOR, 2.0)

	_draw_torso_shirt(canvas, Vector2(head_center.x, shoulder_y), bottom_y, shoulder_w, hu, shirt_style, outfit_col, skin_col, INK_COLOR)

	# 4. Ears
	var ear_rx: float = 5.5 * hu
	var ear_ry: float = 8.5 * hu
	var head_rx: float = 27.0 * hu * jaw_round
	var head_ry: float = 33.0 * hu
	for side in [-1.0, 1.0]:
		var ear_pos := head_center + Vector2(side * (head_rx - 1.5 * hu), 2.0 * hu)
		_draw_ellipse(canvas, ear_pos, ear_rx, ear_ry, skin_col.darkened(0.06))
		_draw_ellipse_outline(canvas, ear_pos, ear_rx, ear_ry, INK_COLOR, 1.8)

	# 5. Head shape (sculpted polygon: adult jaw vs youthful roundness)
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

	# 6. Condition overlays on cheeks/skin: hunger hollows, fever flush, youthful blush, elder wrinkles
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
		var fever_flush := Color(0.86, 0.42, 0.38, 0.30)
		_draw_ellipse(canvas, head_center + Vector2(-13.0 * hu, 7.0 * hu), 8.5 * hu, 5.0 * hu, fever_flush)
		_draw_ellipse(canvas, head_center + Vector2(13.0 * hu, 7.0 * hu), 8.5 * hu, 5.0 * hu, fever_flush)
	elif role == "child" or age <= 12:
		var warm_blush := Color(0.92, 0.42, 0.36, 0.24)
		_draw_ellipse(canvas, head_center + Vector2(-13.5 * hu, 6.5 * hu), 6.5 * hu, 3.8 * hu, warm_blush)
		_draw_ellipse(canvas, head_center + Vector2(13.5 * hu, 6.5 * hu), 6.5 * hu, 3.8 * hu, warm_blush)

	if role == "elder" or age >= 60:
		var wr_col := Color(INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, 0.42)
		canvas.draw_line(head_center + Vector2(-10.0 * hu, -17.5 * hu), head_center + Vector2(10.0 * hu, -17.5 * hu), wr_col, 1.3)
		canvas.draw_line(head_center + Vector2(-8.0 * hu, -14.0 * hu), head_center + Vector2(8.0 * hu, -14.0 * hu), wr_col, 1.2)
		for side in [-1.0, 1.0]:
			# Crow's feet + nasolabial smile lines
			canvas.draw_line(head_center + Vector2(side * 17.5 * hu, -3.5 * hu), head_center + Vector2(side * 21.5 * hu, -5.0 * hu), wr_col, 1.2)
			canvas.draw_line(head_center + Vector2(side * 17.5 * hu, -1.5 * hu), head_center + Vector2(side * 21.5 * hu, -1.0 * hu), wr_col, 1.2)
			canvas.draw_line(head_center + Vector2(side * 7.5 * hu, 8.0 * hu), head_center + Vector2(side * 11.5 * hu, 16.5 * hu), wr_col, 1.3)

	# 7. Eyes & Eyebrows
	var eye_y: float = head_center.y - 2.5 * hu
	var eye_sep: float = (9.5 if (role == "child" or age <= 12) else 10.5) * hu
	var base_eye_r: float = (5.3 if (role == "child" or age <= 12) else 4.6) * hu

	for idx in range(2):
		var side: float = -1.0 if idx == 0 else 1.0
		var epos := Vector2(head_center.x + side * eye_sep, eye_y)
		var er: float = base_eye_r
		canvas.draw_circle(epos, er, Color("#fbf8f1"))
		canvas.draw_arc(epos, er, 0.0, TAU, 18, INK_COLOR, 1.6)
		var look: Vector2 = Vector2(0.0, 1.2 * hu) if withdrawn else Vector2.ZERO
		canvas.draw_circle(epos + look, er * 0.62, eye_col)
		canvas.draw_circle(epos + look, er * 0.32, INK_COLOR)
		canvas.draw_circle(epos + look + Vector2(-1.2 * hu, -1.3 * hu), 1.2 * hu, Color.WHITE)
		if withdrawn:
			# Heavy, half-lowered lids
			var lid := PackedVector2Array()
			for li in range(9):
				var la: float = PI + PI * float(li) / 8.0
				lid.append(epos + Vector2(cos(la) * (er + 0.6 * hu), sin(la) * (er + 0.6 * hu)))
			lid.append(epos + Vector2(er + 0.6 * hu, 0.4 * hu))
			lid.append(epos + Vector2(-er - 0.6 * hu, 0.4 * hu))
			canvas.draw_colored_polygon(lid, skin_col.darkened(0.08))
			canvas.draw_line(epos + Vector2(-er, 0.4 * hu), epos + Vector2(er, 0.4 * hu), INK_COLOR, 1.4)

		# Eyebrows
		var brow_col: Color = Color("#ececec") if (role == "elder" and hair_col.get_luminance() > 0.55) else hair_col.darkened(0.18)
		var brow_y0: float = eye_y - er - 3.2 * hu
		var brow_y1: float = eye_y - er - 2.2 * hu
		canvas.draw_line(
			Vector2(epos.x - 5.5 * hu, brow_y0),
			Vector2(epos.x + 5.5 * hu, brow_y1),
			brow_col,
			2.3 * maxf(hu, 0.65)
		)

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

	# 10. Mouth: parched lips, flat (withdrawn), frown (hungry/sick) or a small smile
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
	elif withdrawn:
		# Flat, quiet mouth
		canvas.draw_line(Vector2(head_center.x - 6.0 * hu, mouth_y + 1.0 * hu), Vector2(head_center.x + 6.0 * hu, mouth_y + 1.0 * hu), INK_COLOR, 2.0)
	elif hunger >= 2 or sickness >= 1:
		# Weak downturn frown
		canvas.draw_arc(Vector2(head_center.x, mouth_y + 5.5 * hu), 7.5 * hu, PI + 0.35, TAU - 0.35, 12, INK_COLOR, 2.0)
	else:
		# Warm slight smile
		var mouth_fill: Color = Color("#f5eee6") if facial_hair == 2 else INK_COLOR
		canvas.draw_arc(Vector2(head_center.x, mouth_y - 2.5 * hu), 7.5 * hu, 0.25, PI - 0.25, 12, mouth_fill, 2.0)

	# Mustache (drawn above the upper lip for facial_hair 1 or 2)
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

	# Sick: a thermometer
	if sickness >= 1:
		var th_start := Vector2(head_center.x + 3.0 * hu, mouth_y + 0.5 * hu)
		var th_end := Vector2(head_center.x + 22.0 * hu, mouth_y + 9.5 * hu)
		canvas.draw_line(th_start, th_end, INK_COLOR, 5.2 * hu)
		canvas.draw_line(th_start, th_end, Color.WHITE, 3.2 * hu)
		canvas.draw_line(th_start.lerp(th_end, 0.35), th_end, Color("#d93829"), 1.6 * hu)
		canvas.draw_circle(th_end, 2.8 * hu, Color("#d93829"))
		canvas.draw_arc(th_end, 2.8 * hu, 0.0, TAU, 10, INK_COLOR, 1.2)

	# 11. Glasses (thin modern frames)
	if has_glasses:
		_draw_glasses(canvas, head_center, eye_y, eye_sep, hu)

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


static func _draw_glasses(canvas: CanvasItem, head_center: Vector2, eye_y: float, eye_sep: float, hu: float) -> void:
	var frame_col := Color("#2a2f36")
	var lens_tint := Color(0.82, 0.93, 0.98, 0.20)
	var gw: float = 14.5 * hu
	var gh: float = 10.5 * hu
	for side in [-1.0, 1.0]:
		var gx: float = head_center.x + side * eye_sep - gw * 0.5
		var gy: float = eye_y - gh * 0.52
		var grect := Rect2(gx, gy, gw, gh)
		canvas.draw_rect(grect, lens_tint, true)
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = frame_col
		sb.set_border_width_all(maxi(1, int(round(1.4 * maxf(hu, 0.7)))))
		sb.set_corner_radius_all(maxi(1, int(round(3.0 * hu))))
		canvas.draw_style_box(sb, grect)
		# Lens glint
		canvas.draw_line(Vector2(gx + 3.0 * hu, gy + gh - 2.5 * hu), Vector2(gx + 7.0 * hu, gy + 2.5 * hu), Color(1, 1, 1, 0.5), 1.2)
	# Bridge
	canvas.draw_line(
		Vector2(head_center.x - eye_sep + gw * 0.5, eye_y - 1.5 * hu),
		Vector2(head_center.x + eye_sep - gw * 0.5, eye_y - 1.5 * hu),
		frame_col,
		1.6 * maxf(hu, 0.65)
	)

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
		3: # High bun
			var cap_pts := PackedVector2Array([
				head_center + Vector2(-28.0 * hu, -10.0 * hu),
				head_center + Vector2(-22.0 * hu, -32.0 * hu),
				head_center + Vector2(0.0, -38.0 * hu),
				head_center + Vector2(22.0 * hu, -32.0 * hu),
				head_center + Vector2(28.0 * hu, -10.0 * hu),
				head_center + Vector2(24.0 * hu, 8.0 * hu),
				head_center + Vector2(-24.0 * hu, 8.0 * hu)
			])
			_draw_poly_outlined(canvas, cap_pts, dark_hair, outline, 2.0)
			var bun_c := head_center + Vector2(2.0 * hu, -45.0 * hu)
			canvas.draw_circle(bun_c, 12.5 * hu, outline)
			canvas.draw_circle(bun_c, 11.0 * hu, hair_col)
			canvas.draw_arc(bun_c, 6.5 * hu, 0.4, PI + 0.9, 10, dark_hair, 1.8)
			# Hair tie
			canvas.draw_line(bun_c + Vector2(-8.0 * hu, 9.0 * hu), bun_c + Vector2(8.0 * hu, 9.0 * hu), Color("#3b4450"), 2.4 * hu)
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
				# Hair tie
				canvas.draw_circle(head_center + Vector2(side * 28.0 * hu, -11.0 * hu), 4.2 * hu, Color("#4aa3ff"))
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
		0: # Side part
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
		1: # Quiff
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
		3: # High bun: swept-back front
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
	outline: Color
) -> void:
	var h: float = maxf(18.0 * hu, bottom_y - neck_base.y)
	var torso_pts := PackedVector2Array([
		neck_base + Vector2(-12.0 * hu, -2.0 * hu),
		neck_base + Vector2(12.0 * hu, -2.0 * hu),
		neck_base + Vector2(shoulder_w, 10.0 * hu),
		Vector2(neck_base.x + shoulder_w + 5.0 * hu, bottom_y),
		Vector2(neck_base.x - shoulder_w - 5.0 * hu, bottom_y),
		neck_base + Vector2(-shoulder_w, 10.0 * hu)
	])
	_draw_poly_outlined(canvas, torso_pts, outfit_col, outline, 2.2)

	match shirt_style:
		0: # Hoodie: hood folded behind the neck, drawstrings, front pocket
			var hood_pts := PackedVector2Array([
				neck_base + Vector2(-17.0 * hu, -4.0 * hu),
				neck_base + Vector2(-9.0 * hu, -9.0 * hu),
				neck_base + Vector2(9.0 * hu, -9.0 * hu),
				neck_base + Vector2(17.0 * hu, -4.0 * hu),
				neck_base + Vector2(12.0 * hu, 6.0 * hu),
				neck_base + Vector2(-12.0 * hu, 6.0 * hu)
			])
			_draw_poly_outlined(canvas, hood_pts, outfit_col.darkened(0.18), outline, 1.6)
			_draw_ellipse(canvas, neck_base + Vector2(0, 0.5 * hu), 9.0 * hu, 3.6 * hu, skin_col.darkened(0.08))
			var cord_col := Color("#eef0f2")
			for side in [-1.0, 1.0]:
				var c0 := neck_base + Vector2(side * 4.5 * hu, 5.0 * hu)
				var c1 := neck_base + Vector2(side * 5.5 * hu, minf(h * 0.55, 19.0 * hu))
				canvas.draw_line(c0, c1, cord_col, 1.6 * hu)
				canvas.draw_circle(c1, 1.4 * hu, cord_col)
			var pocket_top: float = neck_base.y + minf(h * 0.62, 26.0 * hu)
			if pocket_top + 6.0 * hu < bottom_y:
				var pk := PackedVector2Array([
					Vector2(neck_base.x - 15.0 * hu, pocket_top),
					Vector2(neck_base.x + 15.0 * hu, pocket_top),
					Vector2(neck_base.x + 19.0 * hu, bottom_y),
					Vector2(neck_base.x - 19.0 * hu, bottom_y)
				])
				_draw_poly_outlined(canvas, pk, outfit_col.darkened(0.08), outline, 1.3)
		1: # Quarter-zip fleece: stand collar, short zip, soft texture
			_draw_ellipse(canvas, neck_base + Vector2(0, 1.5 * hu), 12.5 * hu, 5.5 * hu, outfit_col.darkened(0.2))
			_draw_ellipse_outline(canvas, neck_base + Vector2(0, 1.5 * hu), 12.5 * hu, 5.5 * hu, outline, 1.6)
			var zip_end: float = minf(bottom_y - 2.0, neck_base.y + minf(h * 0.5, 20.0 * hu))
			canvas.draw_line(neck_base + Vector2(0.0, 4.0 * hu), Vector2(neck_base.x, zip_end), outline, 1.8)
			canvas.draw_circle(Vector2(neck_base.x + 1.5 * hu, neck_base.y + 9.0 * hu), 1.5 * hu, Color("#c9ced4"))
			for kx in [-22, -11, 11, 22]:
				var lx: float = neck_base.x + float(kx) * hu
				if abs(float(kx) * hu) < shoulder_w * 0.82:
					canvas.draw_line(Vector2(lx, neck_base.y + 12.0 * hu), Vector2(lx + 2.0 * hu, bottom_y - 2.0), outfit_col.darkened(0.10), 1.1)
		2: # T-shirt dress: plain crew neck
			_draw_ellipse(canvas, neck_base + Vector2(0, 1.5 * hu), 11.5 * hu, 4.8 * hu, outfit_col.darkened(0.15))
			_draw_ellipse_outline(canvas, neck_base + Vector2(0, 1.5 * hu), 11.5 * hu, 4.8 * hu, outline, 1.4)
			_draw_ellipse(canvas, neck_base + Vector2(0, 0.5 * hu), 9.0 * hu, 3.4 * hu, skin_col.darkened(0.06))
		3: # Graphic tee: crew neck and a small mountain print
			var trim_col := outfit_col.lightened(0.22)
			_draw_ellipse(canvas, neck_base + Vector2(0, 2.0 * hu), 13.5 * hu, 5.5 * hu, trim_col)
			_draw_ellipse_outline(canvas, neck_base + Vector2(0, 2.0 * hu), 13.5 * hu, 5.5 * hu, outline, 1.6)
			_draw_ellipse(canvas, neck_base + Vector2(0, 0.8 * hu), 9.5 * hu, 3.5 * hu, skin_col.darkened(0.08))
			var print_c := neck_base + Vector2(0.0, minf(19.0 * hu, h * 0.55))
			if print_c.y + 7.0 * hu < bottom_y:
				var mtn := PackedVector2Array([
					print_c + Vector2(-8.0 * hu, 5.0 * hu),
					print_c + Vector2(-2.0 * hu, -5.0 * hu),
					print_c + Vector2(1.5 * hu, 0.0),
					print_c + Vector2(4.0 * hu, -3.0 * hu),
					print_c + Vector2(8.0 * hu, 5.0 * hu)
				])
				canvas.draw_colored_polygon(mtn, Color(1, 1, 1, 0.75))
				canvas.draw_circle(print_c + Vector2(5.0 * hu, -6.0 * hu), 1.8 * hu, Color(1, 1, 1, 0.75))
		4: # Rain jacket: hood collar, full zip, two pockets
			var hood_col := outfit_col.darkened(0.16)
			var hood := PackedVector2Array([
				neck_base + Vector2(-16.0 * hu, -3.0 * hu),
				neck_base + Vector2(-8.0 * hu, -8.0 * hu),
				neck_base + Vector2(8.0 * hu, -8.0 * hu),
				neck_base + Vector2(16.0 * hu, -3.0 * hu),
				neck_base + Vector2(9.0 * hu, 9.0 * hu),
				neck_base + Vector2(-9.0 * hu, 9.0 * hu)
			])
			_draw_poly_outlined(canvas, hood, hood_col, outline, 1.5)
			_draw_ellipse(canvas, neck_base + Vector2(0, 0.5 * hu), 8.0 * hu, 3.4 * hu, skin_col.darkened(0.08))
			canvas.draw_line(neck_base + Vector2(0, 9.0 * hu), Vector2(neck_base.x, bottom_y), outline, 2.0)
			if neck_base.y + 30.0 * hu < bottom_y:
				for side in [-1.0, 1.0]:
					var flap := Rect2(neck_base.x + (side * 18.0 - 7.0) * hu, neck_base.y + 22.0 * hu, 14.0 * hu, 3.0 * hu)
					canvas.draw_rect(flap, hood_col, true)
					canvas.draw_rect(flap, outline, false, 1.2)

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
	var injury: int = int(member.get("injury", 0))

	# 1. Soft drop shadow
	canvas.draw_circle(pos + Vector2(2.0, 3.0) * s, 16.5 * s, Color(0, 0, 0, 0.28))

	# 2. Animated feet
	var stride: float = sin(walk_phase) * 6.5 * s
	for side in [-1.0, 1.0]:
		var foot_pos: Vector2 = pos + right * (side * 7.5 * s) + fwd * (side * stride + 3.0 * s)
		canvas.draw_circle(foot_pos, 4.8 * s, Color("#2c2520"))
		canvas.draw_arc(foot_pos, 4.8 * s, 0.0, TAU, 10, INK_COLOR, 1.3)

	# 3. Dress hem if shirt_style == 2
	if shirt_style == 2:
		canvas.draw_circle(pos - fwd * 1.5 * s, 16.8 * s, outfit_col.darkened(0.08))
		canvas.draw_arc(pos - fwd * 1.5 * s, 16.8 * s, 0.0, TAU, 20, INK_COLOR, 1.6)

	# 4. Shoulders / Torso oriented capsule
	var sh_pts := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		sh_pts.append(pos + right * (cos(a) * 16.5 * s) + fwd * (sin(a) * 10.5 * s))
	_draw_poly_outlined(canvas, sh_pts, outfit_col, INK_COLOR, 2.0)

	# Top-down outfit details
	match shirt_style:
		0: # Hoodie: hood lying on the back + drawstrings
			canvas.draw_circle(pos - fwd * 6.5 * s, 7.0 * s, outfit_col.darkened(0.18))
			canvas.draw_arc(pos - fwd * 6.5 * s, 7.0 * s, 0.0, TAU, 12, INK_COLOR, 1.2)
			for side in [-1.0, 1.0]:
				canvas.draw_line(pos + right * (side * 2.5 * s) + fwd * 6.0 * s, pos + right * (side * 2.5 * s) + fwd * 10.5 * s, Color("#eef0f2"), 1.4 * s)
		1: # Fleece: collar ring
			canvas.draw_arc(pos + fwd * 2.0 * s, 9.0 * s, fwd.angle() - 1.2, fwd.angle() + 1.2, 10, outfit_col.darkened(0.22), 2.6 * s)
		2: # Dress: nothing extra on the shoulders
			pass
		3: # Tee: lighter sleeve hems
			for side in [-1.0, 1.0]:
				canvas.draw_line(pos + right * (side * 13.5 * s) - fwd * 5.0 * s, pos + right * (side * 13.5 * s) + fwd * 5.0 * s, outfit_col.lightened(0.22), 2.6 * s)
		4: # Rain jacket: hood + zip line
			canvas.draw_circle(pos - fwd * 6.5 * s, 6.5 * s, outfit_col.darkened(0.16))
			canvas.draw_line(pos + fwd * 4.0 * s, pos + fwd * 10.5 * s, INK_COLOR, 1.6 * s)

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
		canvas.draw_circle(ep, 2.1 * s, Color.WHITE)
		canvas.draw_circle(ep + fwd * 0.5 * s, 1.2 * s, eye_col)

	# Glasses visible from top-down
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
		1: # Quiff (projecting forward)
			canvas.draw_circle(head_p - fwd * 2.0 * s, head_r * 0.94, hair_col)
			var quiff: Vector2 = head_p + fwd * 5.2 * s
			canvas.draw_circle(quiff, 6.8 * s, hair_col.lightened(0.12))
			canvas.draw_arc(quiff, 6.8 * s, 0.0, TAU, 12, INK_COLOR, 1.6)
		2: # Chin Bob
			var b_ang2: float = (-fwd).angle()
			canvas.draw_arc(head_p, head_r * 0.95, b_ang2 - 2.1, b_ang2 + 2.1, 16, hair_col, 5.5 * s)
			canvas.draw_circle(head_p - fwd * 2.5 * s, head_r * 0.85, hair_col)
		3: # High bun
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

	if injury >= 1:
		canvas.draw_line(head_p - right * head_r, head_p + right * head_r, Color("#f7f4eb"), 3.4 * s)
		canvas.draw_circle(head_p + right * 3.5 * s, 1.8 * s, Color("#d63629"))

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
	var on_expedition: bool = bool(member.get("on_expedition", false))
	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", get_role_for_age(age)))

	var s: float = scale_f
	if not alive:
		# Empty seat: their folded clothes and a candle
		canvas.draw_circle(seat_pos + Vector2(0, 26.0 * s), 22.0 * s, Color(0, 0, 0, 0.28))
		var fold_rect := Rect2(seat_pos.x - 18.0 * s, seat_pos.y - 6.0 * s, 36.0 * s, 10.0 * s)
		var out_c: Color = _safe_color(str(member.get("outfit_color", "#6e5039")), Color("#6e5039")).lerp(Color("#5d6671"), 0.55)
		canvas.draw_rect(fold_rect, out_c, true)
		canvas.draw_rect(fold_rect, INK_COLOR, false, 1.8)
		var candle := Rect2(seat_pos.x - 4.0 * s, seat_pos.y - 22.0 * s, 8.0 * s, 16.0 * s)
		canvas.draw_rect(candle, Color("#e8eaed"), true)
		canvas.draw_rect(candle, INK_COLOR, false, 1.4)
		canvas.draw_line(Vector2(seat_pos.x, candle.position.y), Vector2(seat_pos.x, candle.position.y - 3.0 * s), INK_COLOR, 1.2)
		_draw_ellipse(canvas, Vector2(seat_pos.x, candle.position.y - 7.0 * s), 2.6 * s, 4.6 * s, Color("#ffb020"))
		return

	if on_expedition:
		# Faint marker on the empty seat: this member is away
		var st_col := Color(ALERT_AMBER.r, ALERT_AMBER.g, ALERT_AMBER.b, 0.22)
		_draw_ellipse(canvas, seat_pos + Vector2(0, -24.0 * s), 20.0 * s, 24.0 * s, st_col)
		canvas.draw_circle(seat_pos + Vector2(0, -64.0 * s), 16.0 * s, st_col)
		var sign_r := Rect2(seat_pos.x - 28.0 * s, seat_pos.y - 34.0 * s, 56.0 * s, 16.0 * s)
		canvas.draw_rect(sign_r, ALERT_AMBER, true)
		canvas.draw_rect(sign_r, INK_COLOR, false, 1.6)
		var font: Font = ThemeDB.fallback_font
		if font != null:
			canvas.draw_string(font, Vector2(sign_r.position.x + 2, sign_r.position.y + 12.0 * s), "AWAY", HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x - 4, maxi(8, int(9.5 * s)), INK_COLOR)
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

	var sickness: int = int(member.get("sickness", 0))
	var id_hash: float = float(str(member.get("id", "0")).hash() % 100) * 0.07
	var breath: float = sin(anim_time * 2.1 + id_hash) * 1.6 * s
	# A slight shiver when sick
	var jitter_x: float = (sin(anim_time * 19.0 + id_hash) * 0.8 * s) if sickness >= 1 else 0.0

	var skin_col: Color = get_skin_color(member)
	if sickness >= 1:
		skin_col = skin_col.lerp(SICK_SKIN, 0.22)
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
		# Sneaker with a white sole
		var shoe_pts := PackedVector2Array([
			ankle_p + Vector2(-4.5 * s, -2.0 * s),
			ankle_p + Vector2(5.5 * s * side + 3.0 * s, 0.5 * s),
			ankle_p + Vector2(5.5 * s * side + 3.0 * s, 4.8 * s),
			ankle_p + Vector2(-4.5 * s, 4.8 * s)
		])
		_draw_poly_outlined(canvas, shoe_pts, Color("#2f3640"), INK_COLOR, 1.5)
		canvas.draw_line(ankle_p + Vector2(-4.0 * s, 3.8 * s), ankle_p + Vector2(5.5 * s * side + 2.5 * s, 3.8 * s), Color("#e8eaed"), 1.6 * s)

	if shirt_style == 2:
		# Dress hem draped over the knees
		var sk_pts := PackedVector2Array([
			Vector2(seat_pos.x - 16.0 * s * body_s, hip_y - 4.0 * s),
			Vector2(seat_pos.x + 16.0 * s * body_s, hip_y - 4.0 * s),
			Vector2(seat_pos.x + 20.0 * s * body_s, hip_y + 11.0 * s),
			Vector2(seat_pos.x - 20.0 * s * body_s, hip_y + 11.0 * s)
		])
		_draw_poly_outlined(canvas, sk_pts, outfit_col, INK_COLOR, 1.8)

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
	for side in [-1.0, 1.0]:
		var sh_p := Vector2(seat_pos.x + jitter_x + side * (shoulder_w * 0.88 * s), neck_y + 6.0 * s)
		var elbow_p := Vector2(seat_pos.x + side * (shoulder_w * 1.02 * s), hip_y - 9.0 * s + breath * 0.5)
		var hand_p := Vector2(seat_pos.x + side * (knee_sep + 1.5 * s), hip_y + 3.0 * s)
		var sl_col: Color = skin_col if (shirt_style == 2 or shirt_style == 3) else outfit_col.darkened(0.08)
		canvas.draw_line(sh_p, elbow_p, INK_COLOR, 8.2 * s * body_s)
		canvas.draw_line(sh_p, elbow_p, sl_col, 5.4 * s * body_s)
		canvas.draw_line(elbow_p, hand_p, INK_COLOR, 7.2 * s * body_s)
		canvas.draw_line(elbow_p, hand_p, skin_col if shirt_style == 3 else sl_col, 4.6 * s * body_s)
		canvas.draw_circle(hand_p, 4.2 * s * body_s, skin_col)
		canvas.draw_arc(hand_p, 4.2 * s * body_s, 0.0, TAU, 10, INK_COLOR, 1.4)
