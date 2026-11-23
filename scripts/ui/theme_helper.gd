class_name ThemeHelper
extends RefCounted

## 1950s Civil Defense CONELRAD UI Theme & Procedural Widget Styling Helper.
## Eliminates default grey Godot controls with tactile bakelite, hazard-amber,
## bunker-olive, and aged-parchment StyleBoxFlat definitions.

const COLOR_BG_DARK := Color("#1a1d1a")
const COLOR_BUNKER_OLIVE := Color("#232824")
const COLOR_PANEL_SLATE := Color("#262b25")
const COLOR_PARCHMENT := Color("#f2e6ce")
const COLOR_PARCHMENT_AGED := Color("#dccba6")
const COLOR_INK := Color("#1b1917")
const COLOR_HAZARD_YELLOW := Color("#f5be2e")
const COLOR_HAZARD_GOLD := Color("#f2b82e")
const COLOR_ATOMIC_ORANGE := Color("#e05a2b")
const COLOR_TOXIC_GREEN := Color("#7ec850")
const COLOR_WATER_BLUE := Color("#3b8ec2")

static func get_game_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16

	# --- Label ---
	t.set_color("font_color", "Label", COLOR_PARCHMENT)
	t.set_color("font_shadow_color", "Label", Color(0.05, 0.05, 0.04, 0.55))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_font_size("font_size", "Label", 16)

	t.set_type_variation("HeaderLarge", "Label")
	t.set_font_size("font_size", "HeaderLarge", 28)
	t.set_color("font_color", "HeaderLarge", COLOR_HAZARD_YELLOW)

	t.set_type_variation("HeaderMedium", "Label")
	t.set_font_size("font_size", "HeaderMedium", 22)
	t.set_color("font_color", "HeaderMedium", COLOR_HAZARD_YELLOW)

	t.set_type_variation("HeaderSmall", "Label")
	t.set_font_size("font_size", "HeaderSmall", 18)
	t.set_color("font_color", "HeaderSmall", COLOR_PARCHMENT)

	# --- Button (Dark Olive / Brass Civil Defense Switch) ---
	var btn_normal := _make_stylebox(
		Color("#2b322a"),
		Color("#d69e2a"),
		2,
		4,
		14.0, 8.0, 14.0, 8.0,
		Color(0.0, 0.0, 0.0, 0.45),
		3,
		Vector2(0, 2)
	)
	var btn_hover := _make_stylebox(
		Color("#394336"),
		COLOR_HAZARD_YELLOW,
		2,
		4,
		14.0, 8.0, 14.0, 8.0,
		Color(0.96, 0.75, 0.18, 0.28),
		5,
		Vector2(0, 1)
	)
	var btn_pressed := _make_stylebox(
		Color("#1e231e"),
		COLOR_ATOMIC_ORANGE,
		2,
		4,
		14.0, 10.0, 14.0, 6.0,
		Color(0.0, 0.0, 0.0, 0.2),
		1,
		Vector2(0, 0)
	)
	var btn_disabled := _make_stylebox(
		Color("#333832"),
		Color("#5a6156"),
		2,
		4,
		14.0, 8.0, 14.0, 8.0,
		Color(0.0, 0.0, 0.0, 0.0),
		0,
		Vector2.ZERO
	)
	var btn_focus := StyleBoxFlat.new()
	btn_focus.draw_center = false
	btn_focus.border_color = COLOR_HAZARD_YELLOW
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(4)

	for btn_type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", btn_type, btn_normal)
		t.set_stylebox("hover", btn_type, btn_hover)
		t.set_stylebox("pressed", btn_type, btn_pressed)
		t.set_stylebox("disabled", btn_type, btn_disabled)
		t.set_stylebox("focus", btn_type, btn_focus)
		t.set_color("font_color", btn_type, COLOR_PARCHMENT)
		t.set_color("font_hover_color", btn_type, Color("#fff8e6"))
		t.set_color("font_pressed_color", btn_type, COLOR_HAZARD_YELLOW)
		t.set_color("font_focus_color", btn_type, COLOR_PARCHMENT)
		t.set_color("font_disabled_color", btn_type, Color("#c5beae"))
		t.set_font_size("font_size", btn_type, 16)

	var chk_icon_off := make_checkbox_icon(false)
	var chk_icon_on := make_checkbox_icon(true)
	for chk_type in ["CheckBox", "CheckButton"]:
		var chk_normal := _make_stylebox(
			Color("#232923"),
			Color("#6e7668"),
			1,
			4,
			10.0, 6.0, 10.0, 6.0
		)
		var chk_hover := _make_stylebox(
			Color("#2f372e"),
			COLOR_HAZARD_YELLOW,
			1,
			4,
			10.0, 6.0, 10.0, 6.0
		)
		t.set_stylebox("normal", chk_type, chk_normal)
		t.set_stylebox("hover", chk_type, chk_hover)
		t.set_stylebox("pressed", chk_type, chk_hover)
		t.set_stylebox("hover_pressed", chk_type, chk_hover)
		t.set_stylebox("disabled", chk_type, btn_disabled)
		t.set_stylebox("focus", chk_type, btn_focus)
		t.set_color("font_color", chk_type, COLOR_PARCHMENT)
		t.set_color("font_hover_color", chk_type, COLOR_HAZARD_YELLOW)
		t.set_color("font_pressed_color", chk_type, COLOR_HAZARD_YELLOW)
		t.set_color("font_hover_pressed_color", chk_type, COLOR_HAZARD_YELLOW)
		t.set_color("font_disabled_color", chk_type, Color("#c5beae"))
		t.set_font_size("font_size", chk_type, 15)
	t.set_icon("checked", "CheckBox", chk_icon_on)
	t.set_icon("unchecked", "CheckBox", chk_icon_off)
	t.set_icon("checked_disabled", "CheckBox", chk_icon_on)
	t.set_icon("unchecked_disabled", "CheckBox", chk_icon_off)

	# --- Panel & PanelContainer ---
	var panel_sb := _make_stylebox(
		COLOR_PANEL_SLATE,
		Color("#5a6354"),
		2,
		4,
		10.0, 10.0, 10.0, 10.0,
		Color(0.0, 0.0, 0.0, 0.35),
		3,
		Vector2(0, 2)
	)
	t.set_stylebox("panel", "Panel", panel_sb)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	# --- PopupPanel / PopupMenu ---
	var popup_sb := _make_stylebox(
		Color("#1e231e"),
		COLOR_HAZARD_GOLD,
		2,
		4,
		8.0, 8.0, 8.0, 8.0,
		Color(0.0, 0.0, 0.0, 0.55),
		6,
		Vector2(0, 3)
	)
	t.set_stylebox("panel", "PopupPanel", popup_sb)
	t.set_stylebox("panel", "PopupMenu", popup_sb)
	var popup_hover := _make_stylebox(Color("#384235"), COLOR_HAZARD_YELLOW, 1, 3, 6.0, 4.0, 6.0, 4.0)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_color("font_color", "PopupMenu", COLOR_PARCHMENT)
	t.set_color("font_hover_color", "PopupMenu", COLOR_HAZARD_YELLOW)

	# --- LineEdit (Recessed Teletype Input) ---
	var le_normal := _make_stylebox(
		Color("#161916"),
		Color("#8d7b54"),
		2,
		4,
		10.0, 6.0, 10.0, 6.0
	)
	var le_focus := _make_stylebox(
		Color("#1c201b"),
		COLOR_HAZARD_YELLOW,
		2,
		4,
		10.0, 6.0, 10.0, 6.0,
		Color(0.96, 0.75, 0.18, 0.22),
		4,
		Vector2.ZERO
	)
	var le_read_only := _make_stylebox(
		Color("#191c19"),
		Color("#484d45"),
		1,
		4,
		10.0, 6.0, 10.0, 6.0
	)
	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le_read_only)
	t.set_color("font_color", "LineEdit", COLOR_PARCHMENT)
	t.set_color("font_placeholder_color", "LineEdit", Color("#8a8372"))
	t.set_color("caret_color", "LineEdit", COLOR_HAZARD_YELLOW)
	t.set_color("selection_color", "LineEdit", Color(0.95, 0.74, 0.18, 0.35))
	t.set_color("font_selected_color", "LineEdit", Color("#ffffff"))
	t.set_font_size("font_size", "LineEdit", 16)

	# --- HSlider (Brass Dial & Recessed Track) ---
	var slider_rail := _make_stylebox(
		Color("#151815"),
		Color("#535b4e"),
		1,
		3,
		0.0, 4.0, 0.0, 4.0
	)
	var slider_fill := _make_stylebox(
		Color("#c98d24"),
		Color("#f2b82e"),
		1,
		3,
		0.0, 4.0, 0.0, 4.0
	)
	var slider_fill_hi := _make_stylebox(
		COLOR_HAZARD_YELLOW,
		Color("#ffe07d"),
		1,
		3,
		0.0, 4.0, 0.0, 4.0
	)
	t.set_stylebox("slider", "HSlider", slider_rail)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill_hi)
	t.set_icon("grabber", "HSlider", _make_knob_icon(COLOR_HAZARD_GOLD, COLOR_INK))
	t.set_icon("grabber_highlight", "HSlider", _make_knob_icon( Color("#ffe07a"), COLOR_INK))
	t.set_icon("grabber_disabled", "HSlider", _make_knob_icon(Color("#6b7066"), COLOR_INK))

	# --- TabContainer & TabBar ---
	var tab_panel := _make_stylebox(
		COLOR_PANEL_SLATE,
		COLOR_HAZARD_GOLD,
		2,
		4,
		12.0, 12.0, 12.0, 12.0
	)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = Color("#343b31")
	tab_sel.border_color = COLOR_HAZARD_YELLOW
	tab_sel.border_width_top = 3
	tab_sel.border_width_left = 2
	tab_sel.border_width_right = 2
	tab_sel.border_width_bottom = 0
	tab_sel.corner_radius_top_left = 4
	tab_sel.corner_radius_top_right = 4
	tab_sel.content_margin_left = 14.0
	tab_sel.content_margin_right = 14.0
	tab_sel.content_margin_top = 7.0
	tab_sel.content_margin_bottom = 7.0

	var tab_hover := StyleBoxFlat.new()
	tab_hover.bg_color = Color("#2a3028")
	tab_hover.border_color = Color("#b88e28")
	tab_hover.border_width_top = 2
	tab_hover.border_width_left = 1
	tab_hover.border_width_right = 1
	tab_hover.corner_radius_top_left = 4
	tab_hover.corner_radius_top_right = 4
	tab_hover.content_margin_left = 14.0
	tab_hover.content_margin_right = 14.0
	tab_hover.content_margin_top = 7.0
	tab_hover.content_margin_bottom = 7.0

	var tab_unsel := StyleBoxFlat.new()
	tab_unsel.bg_color = Color("#1d211d")
	tab_unsel.border_color = Color("#4a5246")
	tab_unsel.border_width_top = 1
	tab_unsel.border_width_left = 1
	tab_unsel.border_width_right = 1
	tab_unsel.corner_radius_top_left = 4
	tab_unsel.corner_radius_top_right = 4
	tab_unsel.content_margin_left = 14.0
	tab_unsel.content_margin_right = 14.0
	tab_unsel.content_margin_top = 7.0
	tab_unsel.content_margin_bottom = 7.0

	t.set_stylebox("panel", "TabContainer", tab_panel)
	for tab_cls in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", tab_cls, tab_sel)
		t.set_stylebox("tab_hovered", tab_cls, tab_hover)
		t.set_stylebox("tab_unselected", tab_cls, tab_unsel)
		t.set_stylebox("tab_focus", tab_cls, btn_focus)
		t.set_color("font_selected_color", tab_cls, COLOR_HAZARD_YELLOW)
		t.set_color("font_hovered_color", tab_cls, COLOR_PARCHMENT)
		t.set_color("font_unselected_color", tab_cls, Color("#a89f8c"))
		t.set_font_size("font_size", tab_cls, 15)

	# --- ScrollContainer & ScrollBars ---
	var empty_sb := StyleBoxEmpty.new()
	t.set_stylebox("panel", "ScrollContainer", empty_sb)

	var scroll_track := _make_stylebox(Color("#161916"), Color("#373d34"), 1, 3, 2.0, 2.0, 2.0, 2.0)
	var scroll_grab := _make_stylebox(Color("#b58626"), COLOR_INK, 1, 3, 2.0, 2.0, 2.0, 2.0)
	var scroll_grab_hi := _make_stylebox(COLOR_HAZARD_YELLOW, COLOR_INK, 1, 3, 2.0, 2.0, 2.0, 2.0)
	var scroll_grab_pr := _make_stylebox(COLOR_ATOMIC_ORANGE, COLOR_INK, 1, 3, 2.0, 2.0, 2.0, 2.0)
	for sb_cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_cls, scroll_track)
		t.set_stylebox("scroll_focus", sb_cls, scroll_track)
		t.set_stylebox("grabber", sb_cls, scroll_grab)
		t.set_stylebox("grabber_highlight", sb_cls, scroll_grab_hi)
		t.set_stylebox("grabber_pressed", sb_cls, scroll_grab_pr)

	# --- ProgressBar & RichTextLabel ---
	var pb_bg := _make_stylebox(Color("#151815"), Color("#565e50"), 1, 3, 2.0, 2.0, 2.0, 2.0)
	var pb_fill := _make_stylebox(COLOR_HAZARD_GOLD, COLOR_INK, 1, 3, 2.0, 2.0, 2.0, 2.0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", COLOR_PARCHMENT)

	t.set_color("default_color", "RichTextLabel", COLOR_PARCHMENT)
	t.set_font_size("normal_font_size", "RichTextLabel", 16)

	return t

static func make_hazard_button(text_str: String, min_size: Vector2 = Vector2(200, 44)) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := _make_stylebox(
		COLOR_HAZARD_YELLOW,
		COLOR_INK,
		2,
		4,
		16.0, 8.0, 16.0, 8.0,
		Color(0.0, 0.0, 0.0, 0.45),
		4,
		Vector2(0, 2)
	)
	var hover := _make_stylebox(
		Color("#ffd24c"),
		COLOR_INK,
		2,
		4,
		16.0, 8.0, 16.0, 8.0,
		Color(0.96, 0.75, 0.18, 0.40),
		6,
		Vector2(0, 1)
	)
	var pressed := _make_stylebox(
		Color("#d6921b"),
		COLOR_INK,
		2,
		4,
		16.0, 10.0, 16.0, 6.0,
		Color(0.0, 0.0, 0.0, 0.2),
		1,
		Vector2.ZERO
	)
	var disabled := _make_stylebox(
		Color("#333832"),
		COLOR_INK,
		2,
		4,
		16.0, 8.0, 16.0, 8.0
	)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COLOR_INK)
	btn.add_theme_color_override("font_hover_color", Color("#12100e"))
	btn.add_theme_color_override("font_pressed_color", Color("#12100e"))
	btn.add_theme_color_override("font_focus_color", COLOR_INK)
	btn.add_theme_color_override("font_disabled_color", Color("#c5beae"))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	btn.add_theme_font_size_override("font_size", 16)
	return btn

static func make_alert_button(text_str: String, min_size: Vector2 = Vector2(200, 44)) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := _make_stylebox(
		COLOR_ATOMIC_ORANGE,
		COLOR_INK,
		2,
		4,
		16.0, 8.0, 16.0, 8.0,
		Color(0.0, 0.0, 0.0, 0.45),
		4,
		Vector2(0, 2)
	)
	var hover := _make_stylebox(
		Color("#f06b3b"),
		COLOR_HAZARD_YELLOW,
		2,
		4,
		16.0, 8.0, 16.0, 8.0,
		Color(0.88, 0.35, 0.17, 0.42),
		6,
		Vector2(0, 1)
	)
	var pressed := _make_stylebox(
		Color("#b53e1d"),
		COLOR_INK,
		2,
		4,
		16.0, 10.0, 16.0, 6.0
	)
	var disabled := _make_stylebox(
		Color("#333832"),
		COLOR_INK,
		2,
		4,
		16.0, 8.0, 16.0, 8.0
	)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COLOR_PARCHMENT)
	btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	btn.add_theme_color_override("font_pressed_color", COLOR_HAZARD_YELLOW)
	btn.add_theme_color_override("font_focus_color", COLOR_PARCHMENT)
	btn.add_theme_color_override("font_disabled_color", Color("#c5beae"))
	btn.add_theme_font_size_override("font_size", 16)
	return btn

static func make_card_panel(bg_color: Color = Color("#262b25"), border_color: Color = Color("#f2b82e")) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := _make_stylebox(
		bg_color,
		border_color,
		2,
		4,
		14.0, 12.0, 14.0, 12.0,
		Color(0.0, 0.0, 0.0, 0.42),
		4,
		Vector2(0, 2)
	)
	panel.add_theme_stylebox_override("panel", sb)
	return panel

static func draw_hazard_stripes(canvas: CanvasItem, rect: Rect2, stripe_w: float = 18.0) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var ink := COLOR_INK
	var yellow := COLOR_HAZARD_GOLD
	canvas.draw_rect(rect, ink, true)

	var w: float = rect.size.x
	var h: float = rect.size.y
	var sw: float = maxf(4.0, stripe_w)
	var period: float = sw * 2.0
	var max_d: float = w + h
	var base_quad := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(w, 0.0),
		Vector2(w, h),
		Vector2(0.0, h)
	])

	var s0: float = 0.0
	while s0 < max_d:
		var s1: float = s0 + sw
		var clipped: PackedVector2Array = _clip_diag_min(base_quad, s0)
		if clipped.size() >= 3:
			clipped = _clip_diag_max(clipped, s1)
			if clipped.size() >= 3:
				var world_poly := PackedVector2Array()
				world_poly.resize(clipped.size())
				for idx in range(clipped.size()):
					world_poly[idx] = rect.position + clipped[idx]
				canvas.draw_colored_polygon(world_poly, yellow)
		s0 += period

	canvas.draw_rect(rect, ink, false, 1.5)

static func _clip_diag_min(poly: PackedVector2Array, min_sum: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count: int = poly.size()
	if count == 0:
		return out
	for i in range(count):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var da: float = (a.x + a.y) - min_sum
		var db: float = (b.x + b.y) - min_sum
		var a_in: bool = da >= 0.0
		var b_in: bool = db >= 0.0
		if a_in:
			out.append(a)
		if a_in != b_in and absf(db - da) > 0.0001:
			var t: float = -da / (db - da)
			out.append(a.lerp(b, clampf(t, 0.0, 1.0)))
	return out

static func _clip_diag_max(poly: PackedVector2Array, max_sum: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count: int = poly.size()
	if count == 0:
		return out
	for i in range(count):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var da: float = max_sum - (a.x + a.y)
		var db: float = max_sum - (b.x + b.y)
		var a_in: bool = da >= 0.0
		var b_in: bool = db >= 0.0
		if a_in:
			out.append(a)
		if a_in != b_in and absf(db - da) > 0.0001:
			var t: float = -da / (db - da)
			out.append(a.lerp(b, clampf(t, 0.0, 1.0)))
	return out

static func _make_stylebox(
	bg: Color,
	border: Color,
	border_w: int,
	corner_r: int,
	pad_l: float,
	pad_t: float,
	pad_r: float,
	pad_b: float,
	sh_col: Color = Color(0, 0, 0, 0),
	sh_size: int = 0,
	sh_off: Vector2 = Vector2.ZERO
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner_r)
	sb.content_margin_left = pad_l
	sb.content_margin_top = pad_t
	sb.content_margin_right = pad_r
	sb.content_margin_bottom = pad_b
	sb.shadow_color = sh_col
	sb.shadow_size = sh_size
	sb.shadow_offset = sh_off
	return sb

static func _make_knob_icon(fill_color: Color, rim_color: Color) -> ImageTexture:
	var sz: int = 16
	var img: Image = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(sz - 1) * 0.5, float(sz - 1) * 0.5)
	var r_outer: float = 7.0
	var r_inner: float = 5.0
	var r_pip: float = 1.8
	for y in range(sz):
		for x in range(sz):
			var d: float = Vector2(float(x), float(y)).distance_to(center)
			if d <= r_pip:
				img.set_pixel(x, y, rim_color)
			elif d <= r_inner:
				img.set_pixel(x, y, fill_color)
			elif d <= r_outer:
				img.set_pixel(x, y, rim_color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static func make_checkbox_icon(checked: bool) -> ImageTexture:
	var sz: int = 16
	var img: Image = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var bg_fill := Color("#faf5e8")
	var rim := COLOR_INK
	for y in range(sz):
		for x in range(sz):
			if x == 0 or y == 0 or x == sz - 1 or y == sz - 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif x <= 2 or y <= 2 or x >= sz - 3 or y >= sz - 3:
				img.set_pixel(x, y, rim)
			else:
				img.set_pixel(x, y, bg_fill)
	if checked:
		# Crisp 2px bold checkmark inside 3..12 box
		var check_pts: Array[Vector2i] = [
			Vector2i(4, 8), Vector2i(4, 9),
			Vector2i(5, 9), Vector2i(5, 10),
			Vector2i(6, 10), Vector2i(6, 11),
			Vector2i(7, 9), Vector2i(7, 10), Vector2i(7, 11),
			Vector2i(8, 8), Vector2i(8, 9),
			Vector2i(9, 7), Vector2i(9, 8),
			Vector2i(10, 6), Vector2i(10, 7),
			Vector2i(11, 5), Vector2i(11, 6),
			Vector2i(12, 4), Vector2i(12, 5)
		]
		for pt in check_pts:
			img.set_pixel(pt.x, pt.y, rim)
	return ImageTexture.create_from_image(img)
