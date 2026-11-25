class_name ThemeHelper
extends RefCounted

## Global UI theme and widget styling: a present-day emergency-alert / phone look.
## Dark flat panels, rounded corners, thin borders, amber for alerts and primary actions,
## red for danger, green for OK. Every screen goes through these helpers, so the palette
## lives here.

# Palette (section 4: modern emergency-alert / phone UI)
const COLOR_BG := Color("#0f1115")
const COLOR_PANEL := Color("#1a1e24")
const COLOR_PANEL_RAISED := Color("#262c34")
const COLOR_BORDER := Color("#39414b")
const COLOR_TEXT := Color("#e8eaed")
const COLOR_TEXT_MUTED := Color("#9aa3ad")
const COLOR_ALERT_AMBER := Color("#ffb020")
const COLOR_ALERT_RED := Color("#ff4d4f")
const COLOR_OK_GREEN := Color("#4cc38a")
const COLOR_WATER_BLUE := Color("#4aa3ff")
const COLOR_FOOD := Color("#f0a35e")

# Older names kept as aliases so screens written against the first theme still compile.
const COLOR_BG_DARK := COLOR_BG
const COLOR_BUNKER_OLIVE := COLOR_PANEL
const COLOR_PANEL_SLATE := COLOR_PANEL
const COLOR_PARCHMENT := COLOR_TEXT
const COLOR_PARCHMENT_AGED := COLOR_TEXT_MUTED
const COLOR_INK := COLOR_BG
const COLOR_HAZARD_YELLOW := COLOR_ALERT_AMBER
const COLOR_HAZARD_GOLD := COLOR_ALERT_AMBER
const COLOR_TOXIC_GREEN := COLOR_OK_GREEN

const _HOVER_BG := Color("#2f3640")
const _DISABLED_TEXT := Color("#5d6671")
const _CORNER: int = 8

static func get_game_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16

	# --- Label ---
	t.set_color("font_color", "Label", COLOR_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.0))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 0)
	t.set_font_size("font_size", "Label", 16)

	t.set_type_variation("HeaderLarge", "Label")
	t.set_font_size("font_size", "HeaderLarge", 28)
	t.set_color("font_color", "HeaderLarge", COLOR_TEXT)

	t.set_type_variation("HeaderMedium", "Label")
	t.set_font_size("font_size", "HeaderMedium", 22)
	t.set_color("font_color", "HeaderMedium", COLOR_TEXT)

	t.set_type_variation("HeaderSmall", "Label")
	t.set_font_size("font_size", "HeaderSmall", 18)
	t.set_color("font_color", "HeaderSmall", COLOR_TEXT_MUTED)

	# --- Button (flat, rounded, thin border; amber ring on hover/focus) ---
	var btn_normal := _make_stylebox(
		COLOR_PANEL_RAISED,
		COLOR_BORDER,
		1,
		_CORNER,
		14.0, 8.0, 14.0, 8.0
	)
	var btn_hover := _make_stylebox(
		_HOVER_BG,
		COLOR_ALERT_AMBER,
		1,
		_CORNER,
		14.0, 8.0, 14.0, 8.0
	)
	var btn_pressed := _make_stylebox(
		COLOR_PANEL,
		COLOR_ALERT_AMBER,
		2,
		_CORNER,
		14.0, 9.0, 14.0, 7.0
	)
	var btn_disabled := _make_stylebox(
		COLOR_PANEL,
		Color("#2a3039"),
		1,
		_CORNER,
		14.0, 8.0, 14.0, 8.0
	)
	var btn_focus := StyleBoxFlat.new()
	btn_focus.draw_center = false
	btn_focus.border_color = COLOR_ALERT_AMBER
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(_CORNER)

	for btn_type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", btn_type, btn_normal)
		t.set_stylebox("hover", btn_type, btn_hover)
		t.set_stylebox("pressed", btn_type, btn_pressed)
		t.set_stylebox("disabled", btn_type, btn_disabled)
		t.set_stylebox("focus", btn_type, btn_focus)
		t.set_color("font_color", btn_type, COLOR_TEXT)
		t.set_color("font_hover_color", btn_type, Color("#ffffff"))
		t.set_color("font_pressed_color", btn_type, COLOR_ALERT_AMBER)
		t.set_color("font_focus_color", btn_type, COLOR_TEXT)
		t.set_color("font_disabled_color", btn_type, _DISABLED_TEXT)
		t.set_font_size("font_size", btn_type, 16)

	var chk_icon_off := make_checkbox_icon(false)
	var chk_icon_on := make_checkbox_icon(true)
	for chk_type in ["CheckBox", "CheckButton"]:
		var chk_normal := _make_stylebox(
			COLOR_PANEL,
			COLOR_BORDER,
			1,
			_CORNER,
			10.0, 6.0, 10.0, 6.0
		)
		var chk_hover := _make_stylebox(
			COLOR_PANEL_RAISED,
			COLOR_ALERT_AMBER,
			1,
			_CORNER,
			10.0, 6.0, 10.0, 6.0
		)
		t.set_stylebox("normal", chk_type, chk_normal)
		t.set_stylebox("hover", chk_type, chk_hover)
		t.set_stylebox("pressed", chk_type, chk_hover)
		t.set_stylebox("hover_pressed", chk_type, chk_hover)
		t.set_stylebox("disabled", chk_type, btn_disabled)
		t.set_stylebox("focus", chk_type, btn_focus)
		t.set_color("font_color", chk_type, COLOR_TEXT)
		t.set_color("font_hover_color", chk_type, Color("#ffffff"))
		t.set_color("font_pressed_color", chk_type, COLOR_ALERT_AMBER)
		t.set_color("font_hover_pressed_color", chk_type, COLOR_ALERT_AMBER)
		t.set_color("font_disabled_color", chk_type, _DISABLED_TEXT)
		t.set_font_size("font_size", chk_type, 15)
	t.set_icon("checked", "CheckBox", chk_icon_on)
	t.set_icon("unchecked", "CheckBox", chk_icon_off)
	t.set_icon("checked_disabled", "CheckBox", chk_icon_on)
	t.set_icon("unchecked_disabled", "CheckBox", chk_icon_off)

	# --- Panel & PanelContainer ---
	var panel_sb := _make_stylebox(
		COLOR_PANEL,
		COLOR_BORDER,
		1,
		_CORNER + 2,
		12.0, 10.0, 12.0, 10.0,
		Color(0.0, 0.0, 0.0, 0.30),
		6,
		Vector2(0, 2)
	)
	t.set_stylebox("panel", "Panel", panel_sb)
	t.set_stylebox("panel", "PanelContainer", panel_sb)

	# --- PopupPanel / PopupMenu ---
	var popup_sb := _make_stylebox(
		COLOR_PANEL,
		COLOR_BORDER,
		1,
		_CORNER + 2,
		8.0, 8.0, 8.0, 8.0,
		Color(0.0, 0.0, 0.0, 0.50),
		10,
		Vector2(0, 4)
	)
	t.set_stylebox("panel", "PopupPanel", popup_sb)
	t.set_stylebox("panel", "PopupMenu", popup_sb)
	var popup_hover := _make_stylebox(COLOR_PANEL_RAISED, COLOR_PANEL_RAISED, 1, 6, 6.0, 4.0, 6.0, 4.0)
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_color("font_color", "PopupMenu", COLOR_TEXT)
	t.set_color("font_hover_color", "PopupMenu", COLOR_ALERT_AMBER)

	# --- LineEdit (search-field style input) ---
	var le_normal := _make_stylebox(
		COLOR_BG,
		COLOR_BORDER,
		1,
		_CORNER,
		10.0, 6.0, 10.0, 6.0
	)
	var le_focus := _make_stylebox(
		COLOR_BG,
		COLOR_ALERT_AMBER,
		2,
		_CORNER,
		10.0, 6.0, 10.0, 6.0
	)
	var le_read_only := _make_stylebox(
		COLOR_PANEL,
		Color("#2a3039"),
		1,
		_CORNER,
		10.0, 6.0, 10.0, 6.0
	)
	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le_read_only)
	t.set_color("font_color", "LineEdit", COLOR_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color("#6b7580"))
	t.set_color("caret_color", "LineEdit", COLOR_ALERT_AMBER)
	t.set_color("selection_color", "LineEdit", Color(1.0, 0.69, 0.13, 0.32))
	t.set_color("font_selected_color", "LineEdit", Color("#ffffff"))
	t.set_font_size("font_size", "LineEdit", 16)

	# --- HSlider (thin track, round thumb) ---
	var slider_rail := _make_stylebox(
		COLOR_PANEL_RAISED,
		COLOR_PANEL_RAISED,
		1,
		3,
		0.0, 3.0, 0.0, 3.0
	)
	var slider_fill := _make_stylebox(
		COLOR_ALERT_AMBER,
		COLOR_ALERT_AMBER,
		1,
		3,
		0.0, 3.0, 0.0, 3.0
	)
	var slider_fill_hi := _make_stylebox(
		Color("#ffc45c"),
		Color("#ffc45c"),
		1,
		3,
		0.0, 3.0, 0.0, 3.0
	)
	t.set_stylebox("slider", "HSlider", slider_rail)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill_hi)
	t.set_icon("grabber", "HSlider", _make_knob_icon(COLOR_TEXT, COLOR_BG))
	t.set_icon("grabber_highlight", "HSlider", _make_knob_icon(Color("#ffffff"), COLOR_ALERT_AMBER))
	t.set_icon("grabber_disabled", "HSlider", _make_knob_icon(Color("#5d6671"), COLOR_BG))

	# --- TabContainer & TabBar (segmented control) ---
	var tab_panel := _make_stylebox(
		COLOR_PANEL,
		COLOR_BORDER,
		1,
		_CORNER,
		12.0, 12.0, 12.0, 12.0
	)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = COLOR_PANEL_RAISED
	tab_sel.border_color = COLOR_ALERT_AMBER
	tab_sel.border_width_top = 0
	tab_sel.border_width_left = 0
	tab_sel.border_width_right = 0
	tab_sel.border_width_bottom = 2
	tab_sel.corner_radius_top_left = 6
	tab_sel.corner_radius_top_right = 6
	tab_sel.content_margin_left = 14.0
	tab_sel.content_margin_right = 14.0
	tab_sel.content_margin_top = 7.0
	tab_sel.content_margin_bottom = 7.0

	var tab_hover := StyleBoxFlat.new()
	tab_hover.bg_color = Color("#20252c")
	tab_hover.border_color = COLOR_BORDER
	tab_hover.border_width_bottom = 2
	tab_hover.corner_radius_top_left = 6
	tab_hover.corner_radius_top_right = 6
	tab_hover.content_margin_left = 14.0
	tab_hover.content_margin_right = 14.0
	tab_hover.content_margin_top = 7.0
	tab_hover.content_margin_bottom = 7.0

	var tab_unsel := StyleBoxFlat.new()
	tab_unsel.bg_color = COLOR_PANEL
	tab_unsel.border_color = COLOR_PANEL
	tab_unsel.border_width_bottom = 2
	tab_unsel.corner_radius_top_left = 6
	tab_unsel.corner_radius_top_right = 6
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
		t.set_color("font_selected_color", tab_cls, COLOR_TEXT)
		t.set_color("font_hovered_color", tab_cls, COLOR_TEXT)
		t.set_color("font_unselected_color", tab_cls, COLOR_TEXT_MUTED)
		t.set_font_size("font_size", tab_cls, 15)

	# --- ScrollContainer & ScrollBars (thin, phone-style) ---
	var empty_sb := StyleBoxEmpty.new()
	t.set_stylebox("panel", "ScrollContainer", empty_sb)

	var scroll_track := _make_stylebox(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 4, 2.0, 2.0, 2.0, 2.0)
	var scroll_grab := _make_stylebox(COLOR_BORDER, COLOR_BORDER, 0, 4, 2.0, 2.0, 2.0, 2.0)
	var scroll_grab_hi := _make_stylebox(COLOR_TEXT_MUTED, COLOR_TEXT_MUTED, 0, 4, 2.0, 2.0, 2.0, 2.0)
	var scroll_grab_pr := _make_stylebox(COLOR_ALERT_AMBER, COLOR_ALERT_AMBER, 0, 4, 2.0, 2.0, 2.0, 2.0)
	for sb_cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_cls, scroll_track)
		t.set_stylebox("scroll_focus", sb_cls, scroll_track)
		t.set_stylebox("grabber", sb_cls, scroll_grab)
		t.set_stylebox("grabber_highlight", sb_cls, scroll_grab_hi)
		t.set_stylebox("grabber_pressed", sb_cls, scroll_grab_pr)

	# --- ProgressBar & RichTextLabel ---
	var pb_bg := _make_stylebox(COLOR_PANEL_RAISED, COLOR_PANEL_RAISED, 0, 4, 2.0, 2.0, 2.0, 2.0)
	var pb_fill := _make_stylebox(COLOR_ALERT_AMBER, COLOR_ALERT_AMBER, 0, 4, 2.0, 2.0, 2.0, 2.0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", COLOR_TEXT)

	t.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 16)

	return t

## Primary action: solid amber, dark text (the "take action" button of an alert).
static func make_hazard_button(text_str: String, min_size: Vector2 = Vector2(200, 44)) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := _make_stylebox(
		COLOR_ALERT_AMBER,
		COLOR_ALERT_AMBER,
		1,
		_CORNER,
		16.0, 8.0, 16.0, 8.0
	)
	var hover := _make_stylebox(
		Color("#ffc45c"),
		Color("#ffc45c"),
		1,
		_CORNER,
		16.0, 8.0, 16.0, 8.0,
		Color(1.0, 0.69, 0.13, 0.30),
		8,
		Vector2.ZERO
	)
	var pressed := _make_stylebox(
		Color("#e09600"),
		Color("#e09600"),
		1,
		_CORNER,
		16.0, 9.0, 16.0, 7.0
	)
	var disabled := _make_stylebox(
		COLOR_PANEL,
		Color("#2a3039"),
		1,
		_CORNER,
		16.0, 8.0, 16.0, 8.0
	)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COLOR_BG)
	btn.add_theme_color_override("font_hover_color", COLOR_BG)
	btn.add_theme_color_override("font_pressed_color", COLOR_BG)
	btn.add_theme_color_override("font_focus_color", COLOR_BG)
	btn.add_theme_color_override("font_disabled_color", _DISABLED_TEXT)
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	btn.add_theme_font_size_override("font_size", 16)
	return btn

## Danger action: solid red, white text.
static func make_alert_button(text_str: String, min_size: Vector2 = Vector2(200, 44)) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := _make_stylebox(
		COLOR_ALERT_RED,
		COLOR_ALERT_RED,
		1,
		_CORNER,
		16.0, 8.0, 16.0, 8.0
	)
	var hover := _make_stylebox(
		Color("#ff6b6d"),
		Color("#ff6b6d"),
		1,
		_CORNER,
		16.0, 8.0, 16.0, 8.0,
		Color(1.0, 0.30, 0.31, 0.30),
		8,
		Vector2.ZERO
	)
	var pressed := _make_stylebox(
		Color("#d93638"),
		Color("#d93638"),
		1,
		_CORNER,
		16.0, 9.0, 16.0, 7.0
	)
	var disabled := _make_stylebox(
		COLOR_PANEL,
		Color("#2a3039"),
		1,
		_CORNER,
		16.0, 8.0, 16.0, 8.0
	)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color("#ffffff"))
	btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	btn.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	btn.add_theme_color_override("font_focus_color", Color("#ffffff"))
	btn.add_theme_color_override("font_disabled_color", _DISABLED_TEXT)
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	btn.add_theme_font_size_override("font_size", 16)
	return btn

static func make_card_panel(bg_color: Color = COLOR_PANEL, border_color: Color = COLOR_BORDER) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := _make_stylebox(
		bg_color,
		border_color,
		1,
		_CORNER + 4,
		14.0, 12.0, 14.0, 12.0,
		Color(0.0, 0.0, 0.0, 0.35),
		8,
		Vector2(0, 3)
	)
	panel.add_theme_stylebox_override("panel", sb)
	return panel

## Amber-and-black hazard tape (still on every barrier and site fence).
static func draw_hazard_stripes(canvas: CanvasItem, rect: Rect2, stripe_w: float = 18.0) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var ink := COLOR_BG
	var yellow := COLOR_ALERT_AMBER
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
	var r_inner: float = 6.0
	var r_pip: float = 1.8
	for y in range(sz):
		for x in range(sz):
			var d: float = Vector2(float(x), float(y)).distance_to(center)
			if d <= r_pip:
				img.set_pixel(x, y, fill_color)
			elif d <= r_inner:
				img.set_pixel(x, y, fill_color)
			elif d <= r_outer:
				img.set_pixel(x, y, rim_color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

static func make_checkbox_icon(checked: bool) -> ImageTexture:
	# Rounded square: outlined when off, amber with a dark tick when on.
	var sz: int = 16
	var img: Image = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var fill: Color = COLOR_ALERT_AMBER if checked else COLOR_BG
	var rim: Color = COLOR_ALERT_AMBER if checked else COLOR_TEXT_MUTED
	for y in range(sz):
		for x in range(sz):
			var corner: bool = (x <= 1 or x >= sz - 2) and (y <= 1 or y >= sz - 2)
			if x == 0 or y == 0 or x == sz - 1 or y == sz - 1 or corner:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif x <= 2 or y <= 2 or x >= sz - 3 or y >= sz - 3:
				img.set_pixel(x, y, rim)
			else:
				img.set_pixel(x, y, fill)
	if checked:
		# Crisp 2px tick inside the 3..12 box
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
			img.set_pixel(pt.x, pt.y, COLOR_BG)
	return ImageTexture.create_from_image(img)
