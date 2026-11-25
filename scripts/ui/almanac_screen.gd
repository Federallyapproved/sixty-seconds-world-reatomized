class_name AlmanacScreen
extends Control

## The Survival Almanac (section 8): every core item as a card, greyed out until discovered;
## clicking one opens its page with the effects seen so far and the item options unlocked. Junk
## and makeshift items (M3) have their own tabs; a makeshift page also shows its recipe.
## Below the items: endings, House Rules, strangers and kinds of place found over all runs.

var _page: RichTextLabel = null
var _grid: GridContainer = null
var _transitioning: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme == null:
		theme = ThemeHelper.get_game_theme()
	var d: Dictionary = GameState.almanac
	var bg := ColorRect.new()
	bg.color = ThemeHelper.COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var hdr := Label.new()
	hdr.text = "SURVIVAL ALMANAC"
	hdr.position = Vector2(48.0, 28.0)
	hdr.add_theme_font_size_override("font_size", 24)
	hdr.add_theme_color_override("font_color", ThemeHelper.COLOR_ALERT_AMBER)
	add_child(hdr)

	var prog: Dictionary = Almanac.progress(d)
	var sub := Label.new()
	sub.name = "Progress"
	sub.text = "Runs %d   ·   Items %d/%d   ·   Events %d/%d   ·   Endings %d/%d   ·   House Rules %d/%d" % [
		int(d.get("runs", 0)), prog["items"][0], prog["items"][1], prog["events"][0], prog["events"][1],
		prog["endings"][0], prog["endings"][1], prog["rules"][0], prog["rules"][1]]
	sub.position = Vector2(48.0, 64.0)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", ThemeHelper.COLOR_TEXT_MUTED)
	add_child(sub)

	# Core items, junk and makeshift items (M3) each have their own tab.
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.position = Vector2(48.0, 94.0)
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for cat in ["core", "junk", "makeshift"]:
		var tb := Button.new()
		tb.name = "Tab_" + cat
		var seen: int = 0
		for iid in ShelterData.ids_in(cat):
			if Almanac.is_known(d, iid):
				seen += 1
		tb.text = "%s %d/%d" % [{"core": "Items", "junk": "Junk", "makeshift": "Makeshift"}[cat], seen, ShelterData.ids_in(cat).size()]
		tb.toggle_mode = true
		tb.button_pressed = cat == "core"
		tb.custom_minimum_size = Vector2(140.0, 32.0)
		var c: String = cat
		tb.pressed.connect(func() -> void: _fill_grid(c))
		tabs.add_child(tb)
	_grid = GridContainer.new()
	_grid.name = "ItemGrid"
	_grid.columns = 4
	_grid.position = Vector2(48.0, 136.0)
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	add_child(_grid)
	_fill_grid("core")

	var page_card := ThemeHelper.make_card_panel(ThemeHelper.COLOR_PANEL, ThemeHelper.COLOR_BORDER)
	page_card.position = Vector2(660.0, 100.0)
	page_card.size = Vector2(572.0, 330.0)
	add_child(page_card)
	_page = RichTextLabel.new()
	_page.name = "ItemPage"
	_page.bbcode_enabled = true
	_page.add_theme_font_size_override("normal_font_size", 14)
	_page.add_theme_font_size_override("bold_font_size", 16)
	page_card.add_child(_page)
	_page.text = "Pick an item. Items you have never seen in a run stay greyed out; their options stay hidden in the shelter until you find one."

	var lists_card := ThemeHelper.make_card_panel(ThemeHelper.COLOR_PANEL, ThemeHelper.COLOR_BORDER)
	lists_card.position = Vector2(660.0, 442.0)
	lists_card.size = Vector2(572.0, 190.0)
	add_child(lists_card)
	var lists := RichTextLabel.new()
	lists.name = "Lists"
	lists.bbcode_enabled = true
	lists.add_theme_font_size_override("normal_font_size", 13)
	lists_card.add_child(lists)
	lists.text = _lists_text(d)

	var back := ThemeHelper.make_hazard_button("BACK", Vector2(220.0, 44.0))
	back.position = Vector2(48.0, 644.0)
	back.pressed.connect(_on_back)
	add_child(back)


func _fill_grid(cat: String) -> void:
	for c in _grid.get_children():
		c.queue_free()
	var tabs: Node = get_node_or_null("Tabs")
	if tabs != null:
		for tb in tabs.get_children():
			(tb as Button).button_pressed = str(tb.name) == "Tab_" + cat
	for iid in ShelterData.ids_in(cat):
		_grid.add_child(_item_button(GameState.almanac, str(iid)))


func _item_button(d: Dictionary, iid: String) -> Button:
	var known: bool = Almanac.is_known(d, iid)
	var b := Button.new()
	b.name = "Item_" + iid
	b.custom_minimum_size = Vector2(144.0, 56.0)
	var short: String = str(ShelterData.item(iid).get("short_name", ""))
	b.text = (short if short != "" else ShelterData.item_name(iid)) if known else "???"
	b.tooltip_text = ShelterData.item_name(iid) if known else "Not discovered yet"
	b.icon = ItemDB.get_icon_texture(iid) if known else null
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 28)
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.modulate = Color.WHITE if known else Color(1, 1, 1, 0.45)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_show_item.bind(iid))
	return b


func _show_item(iid: String) -> void:
	SoundManager.play_sfx("page_turn")
	var pg: Dictionary = Almanac.item_page(GameState.almanac, iid)
	var muted: String = "#" + ThemeHelper.COLOR_TEXT_MUTED.to_html(false)
	var amber: String = "#" + ThemeHelper.COLOR_ALERT_AMBER.to_html(false)
	if not bool(pg["known"]):
		_page.text = "[b]???[/b]\n\nNot discovered yet. Look at it in the grab, or bring one into the shelter, and its page fills in."
		return
	var t: String = "[b]%s[/b]  [color=%s][%d slot%s][/color]\n%s\n" % [str(pg["name"]), muted, int(pg["slots"]), "" if int(pg["slots"]) == 1 else "s", str(pg["purpose"])]
	if str(pg["almanac"]) != "":
		t += "[color=%s]%s[/color]\n" % [muted, str(pg["almanac"])]
	if str(pg.get("recipe", "")) != "":
		t += "[color=%s]%s[/color]\n" % [amber, str(pg["recipe"])]
	t += "\n[color=%s]Seen doing:[/color]\n" % amber
	if (pg["effects"] as Array).is_empty():
		t += "  nothing yet\n"
	for e in pg["effects"]:
		t += "  • %s\n" % str(e)
	t += "[color=%s]Options it opened:[/color]\n" % amber
	if (pg["options"] as Array).is_empty():
		t += "  none yet\n"
	for o in pg["options"]:
		t += "  • %s\n" % str(o)
	_page.text = t


func _lists_text(d: Dictionary) -> String:
	var muted: String = "#" + ThemeHelper.COLOR_TEXT_MUTED.to_html(false)
	var endings: Array = []
	for eid in ShelterSim.ENDINGS.keys():
		var e: Dictionary = ShelterSim.ENDINGS[eid]
		endings.append(str(e["title"]) if (d["endings"] as Dictionary).has(eid) else "???")
	var rules: Array = []
	for rid in ShelterData.house_rule_ids():
		rules.append(str(ShelterData.house_rule(str(rid)).get("name", rid)) if (d["rules"] as Dictionary).has(rid) else "???")
	var places: Array = []
	for c in (d["places_looted"] as Dictionary).keys():
		places.append(ShelterTrips.category_word(str(c)))
	return "[color=%s]Endings:[/color] %s\n[color=%s]House Rules:[/color] %s\n[color=%s]Strangers met:[/color] %d\n[color=%s]Places looted:[/color] %s" % [
		muted, ", ".join(endings), muted, ", ".join(rules), muted, (d["strangers"] as Dictionary).size(),
		muted, "none yet" if places.is_empty() else ", ".join(places)]


func _on_back() -> void:
	if _transitioning:
		return
	_transitioning = true
	SoundManager.play_sfx("button_click")
	GameState.request_screen(GameState.SCREEN_TITLE)
