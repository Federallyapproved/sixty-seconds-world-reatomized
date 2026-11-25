class_name ActorArtist
extends RefCounted

## Standing, acting survivors for shelter cinematics: walking, carrying, aiming, working,
## cheering, cowering. Reuses CharacterArtist's head/torso so every custom family member
## looks the same as in the portraits and on the bench.

const INK := Color("#1d1a16")
const SKIN_SHADE := Color(0, 0, 0, 0.18)


static func _proportions(member: Dictionary) -> Dictionary:
	var age: int = int(member.get("age", 35))
	var role: String = str(member.get("role", CharacterArtist.get_role_for_age(age)))
	if role == "child" or age <= 12:
		return {"body": 0.72, "leg": 30.0, "head": 0.8, "shoulder": 19.0, "jaw": 1.12}
	if role == "teen" or age <= 17:
		return {"body": 0.88, "leg": 40.0, "head": 0.84, "shoulder": 22.5, "jaw": 1.04}
	if role == "elder" or age >= 60:
		return {"body": 0.94, "leg": 42.0, "head": 0.86, "shoulder": 24.0, "jaw": 0.95}
	return {"body": 1.0, "leg": 46.0, "head": 0.88, "shoulder": 26.0, "jaw": 1.0}


## pose: {"walk": float phase, "moving": bool, "arms": "idle|carry|aim|work|cheer|point|cower|give|climb|bandage|slump",
##        "work_t": float, "prop": item_id or "rifle_aim"|"wrench"|"bandage", "expr": "happy|scared|angry|hurt|sad|focused|sick",
##        "lean": float, "flip": bool}
static func draw_standing(canvas: CanvasItem, feet: Vector2, member: Dictionary, pose: Dictionary, s: float = 1.0) -> Dictionary:
	var pr: Dictionary = _proportions(member)
	var body_s: float = float(pr["body"])
	var leg_len: float = float(pr["leg"]) * s
	var head_s: float = float(pr["head"])
	var shoulder_w: float = float(pr["shoulder"]) * s * body_s
	var walk: float = float(pose.get("walk", 0.0))
	var moving: bool = bool(pose.get("moving", false))
	var arms: String = str(pose.get("arms", "idle"))
	var lean: float = float(pose.get("lean", 0.0))
	var t_work: float = float(pose.get("work_t", 0.0))
	var dir: float = -1.0 if bool(pose.get("flip", false)) else 1.0
	var skin: Color = CharacterArtist.get_skin_color(member)
	if int(member.get("sickness", 0)) >= 1:
		skin = skin.lerp(Color("#c9c4bc"), 0.22)
	var outfit: Color = Color(str(member.get("outfit_color", "#c84b31")))
	var shirt_style: int = clampi(int(member.get("shirt_style", 0)), 0, 4)
	var pants: Color = Color("#2f3847") if shirt_style != 2 else skin.darkened(0.06)

	var bob: float = (absf(sin(walk * 2.0)) * 3.0 * s) if moving else 0.0
	var hip := feet + Vector2(lean * 10.0 * s, -leg_len - bob)
	# shadow
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ellipse(canvas, feet + Vector2(0, 3.0 * s), 20.0 * s * body_s, 5.0 * s, Color(0, 0, 0, 0.3))

	# legs
	var swing: float = sin(walk) * 0.42 if moving else 0.0
	for side in [-1.0, 1.0]:
		var hip_p: Vector2 = hip + Vector2(side * 6.5 * s * body_s, 0.0)
		var ang: float = swing * side
		var knee: Vector2 = hip_p + Vector2(sin(ang) * leg_len * 0.5, leg_len * 0.5)
		var foot: Vector2 = knee + Vector2(sin(ang * 0.6) * leg_len * 0.5, leg_len * 0.5 + bob * 0.5)
		if arms == "slump":
			knee = hip_p + Vector2(side * 10.0 * s, leg_len * 0.35)
			foot = feet + Vector2(side * 16.0 * s, 0.0)
		canvas.draw_line(hip_p, knee, INK, 11.0 * s * body_s)
		canvas.draw_line(knee, foot, INK, 9.5 * s * body_s)
		canvas.draw_line(hip_p, knee, pants if shirt_style != 2 else outfit, 7.6 * s * body_s)
		canvas.draw_line(knee, foot, pants, 6.2 * s * body_s)
		var shoe := PackedVector2Array([foot + Vector2(-5.0 * s, -2.0 * s), foot + Vector2(7.0 * s * dir, 0.0), foot + Vector2(7.0 * s * dir, 4.5 * s), foot + Vector2(-5.0 * s, 4.5 * s)])
		canvas.draw_colored_polygon(shoe, Color("#26201c"))

	# torso + head (portrait anatomy)
	var torso_h: float = 40.0 * s * body_s
	var neck_y: float = hip.y - torso_h
	var head_c := Vector2(hip.x + lean * 6.0 * s, neck_y - 24.0 * s * head_s)
	if arms == "cower":
		head_c += Vector2(0.0, 6.0 * s)
	CharacterArtist._draw_character_upper_body(canvas, head_c, neck_y, hip.y + 1.0 * s, shoulder_w, head_s * s * 0.62, float(pr["jaw"]), member, false)

	# arms
	var sh_l := Vector2(hip.x - shoulder_w * 0.88, neck_y + 6.0 * s)
	var sh_r := Vector2(hip.x + shoulder_w * 0.88, neck_y + 6.0 * s)
	var hands: Array = _hand_targets(arms, hip, neck_y, head_c, shoulder_w, s, walk, t_work, dir, moving)
	var sleeve: Color = skin if (shirt_style == 2 or shirt_style == 3) else outfit.darkened(0.08)
	var hand_l: Vector2 = hands[0]
	var hand_r: Vector2 = hands[1]
	for pair in [[sh_l, hand_l], [sh_r, hand_r]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var mid: Vector2 = (a + b) * 0.5 + Vector2(0.0, 4.0 * s)
		canvas.draw_line(a, mid, INK, 8.2 * s * body_s)
		canvas.draw_line(mid, b, INK, 7.2 * s * body_s)
		canvas.draw_line(a, mid, sleeve, 5.4 * s * body_s)
		canvas.draw_line(mid, b, sleeve, 4.6 * s * body_s)
		canvas.draw_circle(b, 4.2 * s * body_s, skin)
		canvas.draw_arc(b, 4.2 * s * body_s, 0.0, TAU, 10, INK, 1.4)

	# prop
	var prop: String = str(pose.get("prop", ""))
	if prop != "":
		_draw_prop(canvas, prop, hand_l, hand_r, s, dir, t_work)

	# injuries / sickness visible on the body
	var hu: float = head_s * s * 0.62
	if int(member.get("injury", 0)) >= 1:
		var band_y: float = head_c.y - 14.0 * hu * 1.6
		canvas.draw_line(head_c + Vector2(-16.0 * hu * 1.4, band_y - head_c.y), head_c + Vector2(16.0 * hu * 1.4, band_y - head_c.y + 2.0), Color("#f4efe6"), 5.0 * s)
		canvas.draw_circle(head_c + Vector2(6.0 * hu * 1.4, band_y - head_c.y), 2.2 * s, Color("#c0392b"))
		if int(member.get("injury", 0)) >= 2:
			canvas.draw_line(sh_r + Vector2(-4.0 * s, 10.0 * s), sh_l + Vector2(4.0 * s, 24.0 * s), Color("#f4efe6"), 6.0 * s)
	_draw_expression(canvas, head_c, hu, str(pose.get("expr", "")), float(pose.get("expr_t", 0.0)))
	return {"head": head_c, "hand_l": hand_l, "hand_r": hand_r, "hip": hip}


static func _hand_targets(arms: String, hip: Vector2, neck_y: float, head_c: Vector2, sw: float, s: float, walk: float, t: float, dir: float, moving: bool) -> Array:
	var swing: float = sin(walk) * 8.0 * s if moving else 0.0
	match arms:
		"carry":
			return [Vector2(hip.x - 8.0 * s, neck_y + 26.0 * s), Vector2(hip.x + 8.0 * s, neck_y + 26.0 * s)]
		"aim":
			return [Vector2(hip.x + dir * 26.0 * s, neck_y + 12.0 * s), Vector2(hip.x + dir * 46.0 * s, neck_y + 8.0 * s)]
		"work":
			var up: float = absf(sin(t * 9.0)) * 16.0 * s
			return [Vector2(hip.x + dir * 20.0 * s, neck_y + 24.0 * s), Vector2(hip.x + dir * 34.0 * s, neck_y + 4.0 * s + up)]
		"cheer":
			var w: float = sin(t * 8.0) * 5.0 * s
			return [Vector2(hip.x - sw - 10.0 * s, head_c.y - 30.0 * s + w), Vector2(hip.x + sw + 10.0 * s, head_c.y - 30.0 * s - w)]
		"point":
			return [Vector2(hip.x - sw * 0.9, hip.y - 4.0 * s), Vector2(hip.x + dir * 52.0 * s, neck_y - 2.0 * s)]
		"give":
			return [Vector2(hip.x - sw * 0.9, hip.y - 4.0 * s), Vector2(hip.x + dir * 44.0 * s, neck_y + 14.0 * s)]
		"cower":
			return [Vector2(head_c.x - 8.0 * s, head_c.y + 6.0 * s), Vector2(head_c.x + 8.0 * s, head_c.y + 4.0 * s)]
		"climb":
			var c: float = sin(t * 7.0) * 10.0 * s
			return [Vector2(hip.x - 10.0 * s, head_c.y - 22.0 * s + c), Vector2(hip.x + 10.0 * s, head_c.y - 22.0 * s - c)]
		"bandage":
			var b: float = sin(t * 6.0) * 6.0 * s
			return [Vector2(hip.x + dir * 30.0 * s, neck_y + 10.0 * s + b), Vector2(hip.x + dir * 38.0 * s, neck_y + 18.0 * s - b)]
		"slump":
			return [Vector2(hip.x - sw - 6.0 * s, hip.y + 8.0 * s), Vector2(hip.x + sw + 6.0 * s, hip.y + 8.0 * s)]
		_:
			return [Vector2(hip.x - sw - 2.0 * s, hip.y + 2.0 * s + swing), Vector2(hip.x + sw + 2.0 * s, hip.y + 2.0 * s - swing)]


static func _draw_prop(c: CanvasItem, prop: String, hl: Vector2, hr: Vector2, s: float, dir: float, t: float) -> void:
	match prop:
		"rifle_aim":
			var stock: Vector2 = hl - Vector2(dir * 18.0 * s, -4.0 * s)
			var muzzle: Vector2 = hr + Vector2(dir * 40.0 * s, -3.0 * s)
			c.draw_line(stock, hl, Color("#5a3a1e"), 9.0 * s)
			c.draw_line(hl, muzzle, INK, 5.0 * s)
			c.draw_line(hl, hr, Color("#6b4426"), 7.0 * s)
		"axe_swing":
			var ang: float = -1.2 + absf(sin(t * 6.0)) * 2.0
			var head_p: Vector2 = hr + Vector2(cos(ang), sin(ang)) * 38.0 * s * Vector2(dir, 1.0)
			c.draw_line(hr, head_p, Color("#7a4a24"), 5.0 * s)
			c.draw_colored_polygon(PackedVector2Array([head_p + Vector2(-8, -6) * s, head_p + Vector2(10 * dir, -2) * s, head_p + Vector2(-6, 8) * s]), Color("#c0392b"))
		"wrench":
			var tip: Vector2 = hr + Vector2(dir * 22.0 * s, -8.0 * s)
			c.draw_line(hr, tip, Color("#9aa4ab"), 5.0 * s)
			c.draw_arc(tip, 5.0 * s, 0.0, PI * 1.5, 8, Color("#9aa4ab"), 3.0 * s)
		"bandage":
			c.draw_rect(Rect2(hr - Vector2(6, 6) * s, Vector2(12, 12) * s), Color("#f4efe6"))
			c.draw_rect(Rect2(hr - Vector2(6, 6) * s, Vector2(12, 12) * s), INK, false, 1.2)
		"flashlight_beam":
			ItemDB.draw_item_icon(c, "flashlight", hr, 22.0 * s, false)
			var beam := PackedVector2Array([hr, hr + Vector2(dir * 160.0, -60.0) * s, hr + Vector2(dir * 160.0, 20.0) * s])
			c.draw_colored_polygon(beam, Color(1.0, 0.95, 0.6, 0.22 + 0.1 * sin(t * 12.0)))
		_:
			# any inventory item carried between both hands
			ItemDB.draw_item_icon(c, prop, (hl + hr) * 0.5 + Vector2(0.0, -6.0 * s), 30.0 * s, false)


static func _draw_expression(c: CanvasItem, head: Vector2, hu: float, expr: String, t: float) -> void:
	var r: float = 30.0 * hu
	match expr:
		"happy":
			c.draw_circle(head + Vector2(-r * 0.45, r * 0.15), r * 0.12, Color(0.95, 0.45, 0.45, 0.55))
			c.draw_circle(head + Vector2(r * 0.45, r * 0.15), r * 0.12, Color(0.95, 0.45, 0.45, 0.55))
			for i in range(3):
				var a: float = t * 2.0 + float(i) * 2.1
				var p: Vector2 = head + Vector2(cos(a), sin(a) * 0.6) * r * 1.4 + Vector2(0, -r * 0.6)
				_sparkle(c, p, r * 0.16, Color("#f5be2e"))
		"scared":
			var drop: Vector2 = head + Vector2(r * 0.75, -r * 0.2 + fmod(t * 20.0, r * 0.6))
			c.draw_circle(drop, r * 0.1, Color("#7fd0f5"))
			c.draw_colored_polygon(PackedVector2Array([drop + Vector2(-r * 0.1, 0), drop + Vector2(0, -r * 0.25), drop + Vector2(r * 0.1, 0)]), Color("#7fd0f5"))
			var font: Font = ThemeDB.fallback_font
			c.draw_string(font, head + Vector2(-r * 0.15, -r * 1.25), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.9), Color("#d94c2a"))
		"angry":
			for k in range(2):
				var v: Vector2 = head + Vector2(r * 0.55 + float(k) * r * 0.12, -r * 0.7)
				c.draw_line(v, v + Vector2(r * 0.2, r * 0.2), Color("#d94c2a"), 2.5)
				c.draw_line(v + Vector2(r * 0.2, 0), v + Vector2(0, r * 0.2), Color("#d94c2a"), 2.5)
		"hurt":
			for k2 in range(3):
				var a2: float = t * 5.0 + float(k2) * 2.0
				var p2: Vector2 = head + Vector2(cos(a2) * r * 0.9, -r * 0.9 + sin(a2) * r * 0.2)
				_sparkle(c, p2, r * 0.12, Color("#f2efe6"))
		"sad":
			var tear_y: float = fmod(t * 14.0, r * 0.7)
			c.draw_circle(head + Vector2(-r * 0.35, r * 0.05 + tear_y), r * 0.08, Color("#7fd0f5"))
		"sick":
			for k3 in range(3):
				var p3: Vector2 = head + Vector2(r * 0.6 + float(k3) * r * 0.25, -r * 0.2 - fmod(t * 10.0 + float(k3) * 4.0, r))
				c.draw_circle(p3, r * (0.08 + 0.03 * float(k3)), Color(0.55, 0.75, 0.35, 0.6))


static func _sparkle(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_line(p - Vector2(r, 0), p + Vector2(r, 0), col, 2.0)
	c.draw_line(p - Vector2(0, r), p + Vector2(0, r), col, 2.0)


static func _ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)


## Dark silhouette for raiders / rescuers / traders at the hatch.
static func draw_silhouette(c: CanvasItem, feet: Vector2, s: float, col: Color, armed: bool, t: float) -> void:
	var hip: Vector2 = feet + Vector2(0, -46.0 * s)
	var neck: Vector2 = hip + Vector2(0, -40.0 * s)
	var head: Vector2 = neck + Vector2(0, -16.0 * s)
	for side in [-1.0, 1.0]:
		c.draw_line(hip + Vector2(side * 6.0 * s, 0), feet + Vector2(side * 9.0 * s, 0), col, 11.0 * s)
	c.draw_colored_polygon(PackedVector2Array([neck + Vector2(-20, 4) * s, neck + Vector2(20, 4) * s, hip + Vector2(14, 0) * s, hip + Vector2(-14, 0) * s]), col)
	c.draw_circle(head, 13.0 * s, col)
	# gas-mask snout
	c.draw_circle(head + Vector2(0, 6.0 * s), 6.0 * s, col.lightened(0.1))
	c.draw_line(neck + Vector2(-18, 8) * s, hip + Vector2(-24, -8) * s, col, 8.0 * s)
	if armed:
		var a: float = sin(t * 3.0) * 0.2
		c.draw_line(neck + Vector2(18, 8) * s, neck + Vector2(46, 12 + 20 * a) * s, col, 8.0 * s)
		c.draw_line(neck + Vector2(34, 10 + 20 * a) * s, neck + Vector2(72, 4 + 30 * a) * s, col.darkened(0.3), 5.0 * s)
	else:
		c.draw_line(neck + Vector2(18, 8) * s, hip + Vector2(24, -8) * s, col, 8.0 * s)
