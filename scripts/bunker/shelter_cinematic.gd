class_name ShelterCinematic
extends Control

## Full-screen shelter stage used for:
##  * the daily dilemma (a modal card over the live shelter – the player MUST choose),
##  * the animated outcome of that choice (camera moves, lighting, sound, props, expressions,
##    injuries, gunfire, repairs, celebrations),
##  * expedition returns (survivor climbs down, recovered items go onto the storage rack),
##  * garage work (installing a part into the car) and the drive-out escape.
## Every outcome keeps a concise text explanation; the scene owner records it in the journal.

signal choice_made(choice_id: String)
signal sequence_finished(kind: String)

const FLOOR_Y: float = 520.0
const LADDER_X: float = 190.0
const HATCH_Y: float = 70.0
const RACK_X0: float = 930.0
const RACK_X1: float = 1200.0
const SHELF_YS: Array[float] = [228.0, 330.0, 432.0]
const BENCH_SEATS: Array[float] = [470.0, 560.0, 650.0, 740.0]
const RADIO_POS: Vector2 = Vector2(830.0, 452.0)
const VENT_POS: Vector2 = Vector2(1040.0, 96.0)
const STAGE_CENTER: Vector2 = Vector2(640.0, 300.0)
const SOLO_X: float = 330.0   # clear floor between the ladder and the bench

var _mode: String = "idle"          # idle | dilemma | playing | caption
var _kind: String = ""
var _scenario: String = ""
var _t: float = 0.0
var _dur: float = 3.5
var _actor: Dictionary = {}
var _subject: Dictionary = {}
var _params: Dictionary = {}
var _fired: Dictionary = {}
var _shake: float = 0.0
var _flash: float = 0.0
var _particles: Array = []
var _caption_title: String = ""
var _caption_body: String = ""
var _caption_meta: String = ""
var _auto_continue: float = -1.0

var _title_lbl: Label
var _body_lbl: Label
var _meta_lbl: Label
var _continue_btn: Button
var _card: PanelContainer
var _card_vbox: VBoxContainer


class _Painter extends Node2D:
	var cb: Callable
	func _draw() -> void:
		if cb.is_valid():
			cb.call(self)


var _stage: _Painter
var _fx: _Painter
var _c: CanvasItem


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# Stage is a child node so the camera is its transform; character artists may set their
	# own draw transforms, which are relative to this node and therefore keep the camera.
	_stage = _Painter.new()
	_stage.cb = _paint_stage
	add_child(_stage)
	_fx = _Painter.new()
	_fx.cb = _paint_fx
	add_child(_fx)
	_title_lbl = _mk_label(20, Color("#f2b82e"))
	_title_lbl.position = Vector2(40, 572)
	_title_lbl.size = Vector2(1000, 28)
	add_child(_title_lbl)
	_meta_lbl = _mk_label(13, Color("#9fb59a"))
	_meta_lbl.position = Vector2(40, 600)
	_meta_lbl.size = Vector2(1000, 20)
	add_child(_meta_lbl)
	_body_lbl = _mk_label(15, Color("#efe3c8"))
	_body_lbl.position = Vector2(40, 622)
	_body_lbl.size = Vector2(1000, 92)
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_body_lbl)
	_continue_btn = Button.new()
	_continue_btn.text = "CONTINUE  [SPACE]"
	_continue_btn.position = Vector2(1070, 660)
	_continue_btn.size = Vector2(180, 40)
	_continue_btn.focus_mode = Control.FOCUS_NONE
	_style_btn(_continue_btn, Color("#d94c2a"), Color("#fff3db"))
	_continue_btn.pressed.connect(_on_continue)
	_continue_btn.visible = false
	add_child(_continue_btn)


func _mk_label(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _style_btn(b: Button, bg: Color, fg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color("#1d1a16")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = bg.lightened(0.12)
	var sbd: StyleBoxFlat = sb.duplicate()
	sbd.bg_color = bg.darkened(0.35)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_disabled_color", fg.darkened(0.4))
	b.add_theme_font_size_override("font_size", 14)


# ==============================================================================
# PUBLIC API
# ==============================================================================

## Presents the day's dilemma. Options: [{id, label, available, status}]
func show_dilemma(ev: Dictionary, options: Array, actor: Dictionary) -> void:
	_reset("dilemma", "tension")
	_actor = actor
	_mode = "dilemma"
	_title_lbl.text = ""
	_body_lbl.text = ""
	_meta_lbl.text = ""
	_build_card(ev, options, actor)
	visible = true


func play_outcome(outcome: Dictionary, ev: Dictionary) -> void:
	_clear_card()
	_reset("outcome", scenario_for(outcome, ev))
	_actor = _member(str(outcome.get("actor_id", "")))
	_subject = _member(str(outcome.get("subject_id", "")))
	if _subject.is_empty():
		_subject = _actor
	_params = {"item": str(outcome.get("item_used", "")), "tags": outcome.get("tags", [])}
	_dur = float(SCENARIO_DURATIONS.get(_scenario, 3.6))
	_caption_title = str(ev.get("title", "Shelter dilemma")).replace("**", "")
	_caption_body = str(outcome.get("outcome_text", "")).replace("**", "")
	var role_txt: String = "leader" if bool(_actor.get("is_leader", false)) else "oldest able survivor"
	_caption_meta = "Acting for the household: %s (%s)" % [str(_actor.get("name", "")), role_txt] if not _actor.is_empty() else ""
	_mode = "playing"
	visible = true


func play_return(arrival: Dictionary, explorer: Dictionary) -> void:
	_clear_card()
	_reset("return", "return")
	_actor = explorer
	_params = {"items": arrival.get("items", []), "from": str(arrival.get("from", ""))}
	var n: int = (arrival.get("items", []) as Array).size()
	_dur = 3.0 + 0.45 * float(n)
	_caption_title = "%s is back from %s" % [str(arrival.get("member_name", "")), str(arrival.get("from", ""))]
	var parts: Array[String] = []
	for it_v in arrival.get("items", []):
		var it: Dictionary = it_v
		parts.append("%d× %s" % [int(it.get("count", 1)), str(ItemDB.get_item_info(str(it.get("item_id", ""))).get("short_name", it.get("item_id", "")))])
	_caption_body = ("Recovered and stored on the rack: " + ", ".join(parts) + ".") if not parts.is_empty() else "Came back empty-handed."
	_caption_meta = "Dose on this trip is in the journal."
	_mode = "playing"
	visible = true


func play_install(result: Dictionary) -> void:
	_clear_card()
	_reset("install", "install")
	_actor = _member(str(result.get("worker_id", "")))
	_params = {"part": str(result.get("part", "")), "before": result.get("vehicle_before", {})}
	_dur = 5.2
	_caption_title = "Garage work: %s" % str(ItemDB.get_item_info(str(result.get("part", ""))).get("name", ""))
	_caption_body = str(result.get("text", ""))
	_caption_meta = "Above ground: the worker absorbs real dose while working."
	_mode = "playing"
	visible = true


func play_drive_out(text: String) -> void:
	_clear_card()
	_reset("drive", "drive")
	_dur = 5.0
	_caption_title = GameState.ending_title
	_caption_body = text
	_caption_meta = ""
	_mode = "playing"
	visible = true


# ==============================================================================
# SCENARIO SELECTION
# ==============================================================================

const SCENARIO_DURATIONS: Dictionary = {
	"combat": 4.2, "attack": 4.2, "repair": 4.0, "radio": 3.8, "give": 3.8, "gain": 3.8, "medical": 3.8,
	"celebrate": 3.6, "gloom": 3.4, "sickness": 3.6, "hazard": 4.0, "signal": 4.0, "victory": 4.8,
	"doom": 4.0, "shrug": 3.0, "pet": 3.6, "mutant": 3.8,
}


static func scenario_for(outcome: Dictionary, ev: Dictionary) -> String:
	var tags: Array = outcome.get("tags", [])
	var choice: String = str(outcome.get("choice_id", ""))
	var item: String = str(outcome.get("item_used", ""))
	var cat: String = str(ev.get("category", ""))
	if tags.has("victory"):
		return "victory"
	if tags.has("gameover"):
		return "doom"
	if tags.has("raid"):
		if item in ["rifle", "axe"] or choice in ["use_rifle", "use_axe", "use_dog", "use_mutant"]:
			return "combat"
		return "attack"
	if tags.has("injured"):
		return "attack"
	if tags.has("hazard_return"):
		return "hazard"
	if tags.has("sick"):
		return "sickness"
	if item == "gas_mask":
		return "hazard"
	if tags.has("healed") or item == "medkit":
		return "medical"
	if tags.has("mutant"):
		return "mutant"
	if tags.has("companion") or item in ["cat", "dog"]:
		return "pet"
	if tags.has("item_repaired") or item == "toolbox":
		return "repair"
	if tags.has("rescue_progress"):
		return "radio" if item == "radio" else "signal"
	if item == "radio":
		return "radio"
	if choice.begins_with("give_") or tags.has("item_lost"):
		return "give"
	if tags.has("item_gained"):
		return "gain"
	if item in ["harmonica", "cards", "checkers", "book"] and tags.has("morale_up"):
		return "celebrate"
	if item in ["flashlight", "map"]:
		return "signal"
	if tags.has("morale_down"):
		return "gloom"
	if tags.has("morale_up"):
		return "celebrate"
	if cat == "nuke_zone":
		return "hazard"
	return "shrug"


# ==============================================================================
# FLOW
# ==============================================================================

func _reset(kind: String, scenario: String) -> void:
	_kind = kind
	_scenario = scenario
	_t = 0.0
	_fired = {}
	_particles = []
	_shake = 0.0
	_flash = 0.0
	_continue_btn.visible = false
	_title_lbl.text = ""
	_body_lbl.text = ""
	_meta_lbl.text = ""
	_auto_continue = -1.0
	if is_inside_tree():
		get_viewport().gui_release_focus()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta * (1.5 if GameState.demo_mode else 1.0)
	_shake = maxf(0.0, _shake - delta * 18.0)
	_flash = maxf(0.0, _flash - delta * 2.4)
	_tick_particles(delta)
	if _mode == "playing":
		_fire_scenario_events()
		_title_lbl.text = _caption_title
		_meta_lbl.text = _caption_meta
		var chars: int = int(_t * 90.0)
		_body_lbl.text = _caption_body.substr(0, mini(chars, _caption_body.length()))
		if _t >= _dur:
			_mode = "caption"
			_body_lbl.text = _caption_body
			_continue_btn.visible = true
			if GameState.demo_mode or GameState.headless_fast_test:
				_auto_continue = 0.8
	elif _mode == "caption" and _auto_continue > 0.0:
		_auto_continue -= delta
		if _auto_continue <= 0.0:
			_on_continue()
	var cam: Array = _camera()
	var z: float = float(cam[0])
	var sh: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_stage.position = STAGE_CENTER - (cam[1] as Vector2) * z + sh
	_stage.scale = Vector2(z, z)
	_stage.queue_redraw()
	_fx.queue_redraw()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kc: int = (event as InputEventKey).keycode
		if kc == KEY_SPACE or kc == KEY_ENTER:
			if _mode == "caption":
				_on_continue()
			elif _mode == "playing" and _t > 0.6:
				_t = _dur  # fast-forward to the end of the animation, text stays
			get_viewport().set_input_as_handled()
		elif _mode == "dilemma" and kc >= KEY_1 and kc <= KEY_9:
			var idx: int = int(kc - KEY_1)
			var btns: Array = _option_buttons()
			if idx < btns.size() and not (btns[idx] as Button).disabled:
				(btns[idx] as Button).emit_signal("pressed")
			get_viewport().set_input_as_handled()


func _on_continue() -> void:
	if _mode != "caption":
		return
	_mode = "idle"
	_continue_btn.visible = false
	visible = false
	sequence_finished.emit(_kind)


func is_busy() -> bool:
	return visible


# ==============================================================================
# DILEMMA CARD
# ==============================================================================

func _clear_card() -> void:
	if is_instance_valid(_card):
		_card.queue_free()
	_card = null


func _option_buttons() -> Array:
	var out: Array = []
	if is_instance_valid(_card_vbox) and is_instance_valid(_card):
		for c in _card_vbox.get_children():
			if c is HBoxContainer:
				for cc in c.get_children():
					if cc is Button:
						out.append(cc)
	return out


func _build_card(ev: Dictionary, options: Array, actor: Dictionary) -> void:
	_clear_card()
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#efe3c8")
	sb.border_color = Color("#1d1a16")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	_card.add_theme_stylebox_override("panel", sb)
	_card.position = Vector2(170, 336)
	_card.size = Vector2(940, 366)
	add_child(_card)
	_card_vbox = VBoxContainer.new()
	_card_vbox.add_theme_constant_override("separation", 6)
	_card.add_child(_card_vbox)
	var hdr := Label.new()
	hdr.text = "DAY %d — %s" % [GameState.day, str(ev.get("title", "Dilemma")).replace("**", "").to_upper()]
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", Color("#b8321e"))
	_card_vbox.add_child(hdr)
	var desc := Label.new()
	desc.text = str(ev.get("description", "")).replace("**", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(900, 0)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#1d1a16"))
	_card_vbox.add_child(desc)
	var who := Label.new()
	var lead_txt: String = "leader" if bool(actor.get("is_leader", false)) else "oldest able survivor — the leader cannot act"
	who.text = "%s (%s) will carry out the decision. Choose before the day goes on:" % [str(actor.get("name", "Someone")), lead_txt]
	who.add_theme_font_size_override("font_size", 12)
	who.add_theme_color_override("font_color", Color("#544c3f"))
	_card_vbox.add_child(who)
	var n: int = 0
	for o_v in options:
		var o: Dictionary = o_v
		n += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_card_vbox.add_child(row)
		var b := Button.new()
		b.text = "%d.  %s" % [n, str(o.get("label", o.get("id", ""))).replace("**", "")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(760, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not bool(o.get("available", false))
		_style_btn(b, Color("#2c322d") if not b.disabled else Color("#8a8478"), Color("#f2e6ce"))
		var cid: String = str(o.get("id", ""))
		b.pressed.connect(func() -> void:
			SoundManager.play_sfx("button_click")
			choice_made.emit(cid)
		)
		row.add_child(b)
		var st := Label.new()
		st.text = str(o.get("status", ""))
		st.add_theme_font_size_override("font_size", 12)
		st.add_theme_color_override("font_color", Color("#4f8f32") if not b.disabled else Color("#b8321e"))
		row.add_child(st)


# ==============================================================================
# SCENARIO EVENTS (sound, shake, particles at fixed beats)
# ==============================================================================

func _beat(name: String, at: float) -> bool:
	if _t >= at and not _fired.has(name):
		_fired[name] = true
		return true
	return false


func _fire_scenario_events() -> void:
	match _scenario:
		"combat":
			if _beat("alarm", 0.1):
				SoundManager.play_sfx("knock", -2.0)
			var gun: bool = str(_params.get("item", "")) == "rifle"
			if _beat("hit", 1.45):
				SoundManager.play_sfx("gunshot" if gun else "thud")
				_shake = 12.0
				_flash = 1.0 if gun else 0.4
				_burst(_muzzle_point(), Color("#ffd76a"), 18, 260.0)
		"attack":
			if _beat("bang", 0.4):
				SoundManager.play_sfx("hatch_slam")
				_shake = 10.0
			if _beat("hit", 1.6):
				SoundManager.play_sfx("thud")
				_shake = 14.0
				_flash = 0.6
				_burst(Vector2(420, 420), Color("#c0392b"), 14, 160.0)
		"repair":
			for i in range(4):
				if _beat("w%d" % i, 1.2 + float(i) * 0.55):
					SoundManager.play_sfx("wrench", -3.0, 0.9 + 0.1 * float(i))
					_burst(Vector2(LADDER_X + 100.0, FLOOR_Y - 110.0), Color("#ffd76a"), 8, 140.0)
			if _beat("ok", 3.4):
				SoundManager.play_sfx("pickup")
		"radio":
			if _beat("static", 1.0):
				SoundManager.play_sfx("geiger", -6.0, 0.6)
			if _beat("click", 2.4):
				SoundManager.play_sfx("button_click")
		"give":
			if _beat("hatch", 0.3):
				SoundManager.play_sfx("hatch_drop", -3.0)
			if _beat("item", 1.8):
				SoundManager.play_sfx("pickup")
		"gain":
			if _beat("work", 1.0):
				SoundManager.play_sfx("wrench", -6.0, 1.3)
			if _beat("item", 1.8):
				SoundManager.play_sfx("pickup")
				_burst(Vector2(520, FLOOR_Y - 110.0), Color("#efe3c8"), 10, 110.0)
		"medical":
			if _beat("heal", 2.2):
				SoundManager.play_sfx("pickup", 0.0, 1.2)
				_burst(Vector2(SOLO_X, 420), Color("#7ec850"), 12, 90.0)
		"celebrate":
			if _beat("cheer", 0.8):
				SoundManager.play_sfx("cheer")
				_confetti()
		"gloom":
			if _beat("rumble", 0.5):
				SoundManager.play_sfx("thud", -8.0, 0.6)
				_shake = 4.0
		"sickness":
			if _beat("cough", 0.8):
				SoundManager.play_sfx("thud", -10.0, 1.6)
		"hazard":
			for i2 in range(5):
				if _beat("g%d" % i2, 0.3 + float(i2) * 0.5):
					SoundManager.play_sfx("geiger", -2.0, 1.0 + 0.15 * float(i2))
		"signal":
			if _beat("flash", 1.2):
				SoundManager.play_sfx("button_click", 0.0, 0.6)
		"victory":
			if _beat("open", 0.4):
				SoundManager.play_sfx("hatch_slam")
			if _beat("fanfare", 1.4):
				SoundManager.play_sfx("victory")
				_confetti()
		"doom":
			if _beat("boom", 0.5):
				SoundManager.play_sfx("gameover")
		"pet":
			if _beat("pet", 0.6):
				SoundManager.play_sfx("pickup", -2.0, 1.4)
		"mutant":
			if _beat("glow", 0.8):
				SoundManager.play_sfx("sparks")
		"return":
			if _beat("hatch", 0.2):
				SoundManager.play_sfx("knock")
			if _beat("ladder", 0.8):
				SoundManager.play_sfx("ladder")
			var items: Array = _params.get("items", [])
			for i3 in range(items.size()):
				if _beat("item%d" % i3, 2.8 + float(i3) * 0.45):
					SoundManager.play_sfx("pickup", -2.0, 1.0 + 0.08 * float(i3))
		"install":
			if _beat("w1", 2.2):
				SoundManager.play_sfx("wrench")
			if _beat("w2", 2.9):
				SoundManager.play_sfx("wrench", -2.0, 1.1)
			if _beat("done", 3.6):
				var part: String = str(_params.get("part", ""))
				if part == "car_battery":
					SoundManager.play_sfx("sparks")
					_burst(Vector2(980, 420), Color("#ffd76a"), 16, 200.0)
				else:
					SoundManager.play_sfx("pickup")
		"drive":
			if _beat("engine", 0.5):
				SoundManager.play_sfx("engine_start")
			if _beat("cheer", 3.2):
				SoundManager.play_sfx("victory")


func _burst(at: Vector2, col: Color, n: int, speed: float) -> void:
	for i in range(n):
		var a: float = randf() * TAU
		_particles.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * speed, "life": randf_range(0.3, 0.8), "col": col, "r": randf_range(2.0, 4.0), "g": 300.0})


func _confetti() -> void:
	var cols: Array[Color] = [Color("#f2b82e"), Color("#d94c2a"), Color("#7ec850"), Color("#3b8ec2"), Color("#efe3c8")]
	for i in range(60):
		_particles.append({"p": Vector2(randf_range(380, 900), randf_range(80, 160)), "v": Vector2(randf_range(-60, 60), randf_range(20, 120)), "life": randf_range(1.2, 2.4), "col": cols[i % cols.size()], "r": randf_range(2.5, 4.5), "g": 60.0, "rect": true})


func _tick_particles(dt: float) -> void:
	var keep: Array = []
	for p_v in _particles:
		var p: Dictionary = p_v
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			continue
		p["v"] = (p["v"] as Vector2) + Vector2(0.0, float(p.get("g", 200.0)) * dt)
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * dt
		keep.append(p)
	_particles = keep


# ==============================================================================
# DRAWING
# ==============================================================================

func _ease(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _seg(t: float, a: float, b: float) -> float:
	return _ease((t - a) / maxf(0.001, b - a))


func _camera() -> Array:
	# [zoom, focus]. The floor is kept in frame so feet never disappear under the caption bar.
	var t: float = _t if _mode != "dilemma" else 0.0
	var z: float = 1.0
	var fx: float = 640.0
	var fy: float = -1.0
	match _scenario:
		"tension":
			z = 0.85 + 0.01 * sin(_t * 0.8)
			fx = 640.0
			fy = 496.0
		"combat", "attack":
			z = lerpf(1.0, 1.3, _seg(t, 0.0, 1.0))
			fx = lerpf(600.0, 440.0, _seg(t, 0.0, 1.2))
		"repair":
			z = lerpf(1.0, 1.3, _seg(t, 0.2, 1.0))
			fx = 400.0
		"radio":
			z = lerpf(1.0, 1.35, _seg(t, 0.2, 1.0))
			fx = RADIO_POS.x - 60.0
		"give", "gain", "signal", "victory", "celebrate", "pet", "drive":
			z = 1.0
			fx = 600.0
		"medical", "sickness", "mutant":
			z = lerpf(1.0, 1.3, _seg(t, 0.0, 1.0))
			fx = SOLO_X + 160.0
		"hazard":
			z = lerpf(1.0, 1.15, _seg(t, 0.0, 1.5))
			fx = 840.0
		"return":
			z = 1.0
			fx = lerpf(560.0, 720.0, _seg(t, 2.0, 3.0))
		"install":
			z = lerpf(1.0, 1.25, _seg(t, 1.6, 2.4))
			fx = lerpf(640.0, 860.0, _seg(t, 1.6, 2.4))
		_:
			z = 1.0 + 0.1 * _seg(t, 0.0, 1.5)
			fx = 600.0
	if fy < 0.0:
		fy = FLOOR_Y + 10.0 - 230.0 / z
	var half_w: float = 640.0 / z
	fx = clampf(fx, -200.0 + half_w, 1500.0 - half_w)
	return [z, Vector2(fx, fy)]


func _draw() -> void:
	if visible:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0d0f0d"))


func _paint_stage(c: CanvasItem) -> void:
	if not visible:
		return
	_c = c
	var font: Font = ThemeDB.fallback_font
	if _scenario == "install" or _scenario == "drive":
		_draw_garage_scene(font)
	else:
		_draw_shelter_scene(font)
	for p_v in _particles:
		var p: Dictionary = p_v
		var a: float = clampf(float(p["life"]) * 2.0, 0.0, 1.0)
		var col: Color = Color(p["col"], a)
		if bool(p.get("rect", false)):
			c.draw_rect(Rect2(p["p"], Vector2(float(p["r"]) * 1.4, float(p["r"]))), col)
		else:
			c.draw_circle(p["p"], float(p["r"]), col)


func _paint_fx(c: CanvasItem) -> void:
	if not visible:
		return
	_c = c
	var font: Font = ThemeDB.fallback_font
	_draw_lighting()
	if _flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.95, 0.8, _flash * 0.55))
	c.draw_rect(Rect2(0, 0, size.x, 44), Color(0, 0, 0, 0.92))
	c.draw_rect(Rect2(0, 560, size.x, 160), Color(0.07, 0.08, 0.07, 0.96))
	c.draw_line(Vector2(0, 560), Vector2(size.x, 560), Color("#f2b82e"), 2.0)
	var head: String = {"dilemma": "TODAY'S DILEMMA", "outcome": "WHAT HAPPENED", "return": "EXPEDITION RETURN", "install": "GARAGE", "drive": "ESCAPE"}.get(_kind, "")
	c.draw_string(font, Vector2(24, 29), "DAY %d  •  %s" % [GameState.day, head], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#f2b82e"))
	if _mode == "playing":
		c.draw_string(font, Vector2(size.x - 280, 29), "SPACE: skip animation", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.78, 0.7, 0.6))
	elif _mode == "dilemma":
		c.draw_string(font, Vector2(size.x - 330, 29), "Press 1–%d or click an answer" % _option_buttons().size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.78, 0.7, 0.75))


func _draw_lighting() -> void:
	var t: float = _t
	match _scenario:
		"combat", "attack":
			var a: float = 0.12 + 0.1 * (0.5 + 0.5 * sin(t * 9.0))
			_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.08, 0.04, a * (1.0 - _seg(t, 2.6, 3.6))))
		"gloom", "doom":
			_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45 * _seg(t, 0.0, 1.5)))
		"hazard", "sickness", "mutant":
			_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.7, 0.1, 0.10 + 0.06 * sin(t * 4.0)))
		"victory":
			_c.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.85, 0.35 * _seg(t, 0.3, 1.2) * (1.0 - _seg(t, 3.0, 4.6))))
		"tension":
			_c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	# vignette
	for i in range(6):
		var w: float = 18.0 * float(i + 1)
		_c.draw_rect(Rect2(0, 44, w, 516), Color(0, 0, 0, 0.05))
		_c.draw_rect(Rect2(size.x - w, 44, w, 516), Color(0, 0, 0, 0.05))


# --- shelter backdrop ---------------------------------------------------------

func _draw_shelter_scene(font: Font) -> void:
	# walls & floor
	_c.draw_rect(Rect2(-200, 0, 1700, FLOOR_Y), Color("#2a302b"))
	for x in range(-200, 1500, 96):
		_c.draw_line(Vector2(x, 40), Vector2(x, FLOOR_Y), Color("#232823"), 3.0)
	for y in range(80, int(FLOOR_Y), 64):
		_c.draw_line(Vector2(-200, y), Vector2(1500, y), Color("#262b26"), 2.0)
	_c.draw_rect(Rect2(-200, FLOOR_Y, 1700, 260), Color("#1b1e1a"))
	_c.draw_line(Vector2(-200, FLOOR_Y), Vector2(1500, FLOOR_Y), Color("#3a423b"), 3.0)
	# ceiling lamp
	var sway: float = sin(_t * 1.3) * (6.0 if _scenario in ["tension", "gloom", "attack", "combat"] else 2.0)
	var lamp := Vector2(640 + sway, 120)
	_c.draw_line(Vector2(640, 40), lamp, Color("#111"), 2.0)
	_c.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-22, 0), lamp + Vector2(22, 0), lamp + Vector2(12, -12), lamp + Vector2(-12, -12)]), Color("#3b423d"))
	var flick: float = 1.0 if _scenario != "gloom" else (0.6 + 0.4 * absf(sin(_t * 17.0)))
	_c.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-18, 2), lamp + Vector2(18, 2), lamp + Vector2(220, FLOOR_Y - 120), lamp + Vector2(-220, FLOOR_Y - 120)]), Color(1.0, 0.86, 0.5, 0.07 * flick))
	_c.draw_circle(lamp + Vector2(0, 4), 7.0, Color(1.0, 0.9, 0.6, 0.9 * flick))
	# vent
	_c.draw_rect(Rect2(VENT_POS - Vector2(36, 18), Vector2(72, 36)), Color("#3b423d"))
	for i in range(5):
		_c.draw_line(VENT_POS + Vector2(-30, -12 + i * 6), VENT_POS + Vector2(30, -12 + i * 6), Color("#1b1e1a"), 2.0)
	_c.draw_line(VENT_POS + Vector2(0, -18), VENT_POS + Vector2(0, -60), Color("#3b423d"), 14.0)
	# hatch + ladder
	var open_amt: float = _hatch_open()
	_c.draw_circle(Vector2(LADDER_X, HATCH_Y), 46.0, Color("#3b423d"))
	_c.draw_circle(Vector2(LADDER_X, HATCH_Y), 40.0, Color(0.9, 0.9, 0.75, 0.9) if open_amt > 0.05 else Color("#232823"))
	if open_amt > 0.05:
		_c.draw_colored_polygon(PackedVector2Array([Vector2(LADDER_X - 38, HATCH_Y), Vector2(LADDER_X + 38, HATCH_Y), Vector2(LADDER_X + 150, FLOOR_Y), Vector2(LADDER_X - 150, FLOOR_Y)]), Color(1.0, 0.95, 0.75, 0.16 * open_amt))
	_c.draw_rect(Rect2(LADDER_X - 46 + 92.0 * open_amt * 0.0, HATCH_Y - 8, 92.0 * (1.0 - open_amt), 16), Color("#555e57"))
	for side in [-1.0, 1.0]:
		_c.draw_line(Vector2(LADDER_X + side * 22.0, HATCH_Y + 30), Vector2(LADDER_X + side * 22.0, FLOOR_Y), Color("#6e7982"), 5.0)
	for ry in range(int(HATCH_Y) + 50, int(FLOOR_Y), 34):
		_c.draw_line(Vector2(LADDER_X - 22, ry), Vector2(LADDER_X + 22, ry), Color("#6e7982"), 4.0)
	# storage rack with real stock
	_draw_rack(font)
	# radio table
	_c.draw_rect(Rect2(RADIO_POS + Vector2(-50, 18), Vector2(100, 10)), Color("#5a4632"))
	_c.draw_line(RADIO_POS + Vector2(-42, 28), RADIO_POS + Vector2(-42, FLOOR_Y - RADIO_POS.y), Color("#4a3a28"), 5.0)
	_c.draw_line(RADIO_POS + Vector2(42, 28), RADIO_POS + Vector2(42, FLOOR_Y - RADIO_POS.y), Color("#4a3a28"), 5.0)
	if GameState.has_working_item("radio") or _scenario == "radio":
		ItemDB.draw_item_icon(_c, "radio", RADIO_POS, 44.0, false)
	# bench
	_c.draw_rect(Rect2(420, 478, 360, 14), Color("#5a4632"))
	_c.draw_line(Vector2(440, 492), Vector2(440, FLOOR_Y), Color("#4a3a28"), 6.0)
	_c.draw_line(Vector2(760, 492), Vector2(760, FLOOR_Y), Color("#4a3a28"), 6.0)
	_draw_people_and_action(font)


func _hatch_open() -> float:
	match _scenario:
		"return":
			return _seg(_t, 0.1, 0.6) * (1.0 - _seg(_t, 2.2, 2.6))
		"give":
			return _seg(_t, 0.2, 0.6) * (1.0 - _seg(_t, 2.8, 3.3))
		"victory":
			return _seg(_t, 0.3, 1.0)
		"attack":
			return _seg(_t, 0.3, 0.6) * (1.0 - _seg(_t, 3.0, 3.6))
		"combat":
			return _seg(_t, 0.0, 0.4) * (1.0 - _seg(_t, 2.6, 3.2))
	return 0.0


func _draw_rack(font: Font) -> void:
	_c.draw_rect(Rect2(RACK_X0, 150, RACK_X1 - RACK_X0, FLOOR_Y - 150), Color("#1b1f1c"))
	for sy in SHELF_YS:
		_c.draw_rect(Rect2(RACK_X0, sy, RACK_X1 - RACK_X0, 10), Color("#4c3e2e"))
	_c.draw_rect(Rect2(RACK_X0, 150, 8, FLOOR_Y - 150), Color("#3b423d"))
	_c.draw_rect(Rect2(RACK_X1 - 8, 150, 8, FLOOR_Y - 150), Color("#3b423d"))
	# food & water
	var soup: int = mini(8, int(ceil(float(GameState.soup_quarters) / 4.0)))
	for i in range(soup):
		ItemDB.draw_item_icon(_c, "soup", Vector2(RACK_X0 + 26 + i * 28, SHELF_YS[0] - 16), 26.0, false)
	var water: int = mini(8, int(ceil(float(GameState.water_quarters) / 4.0)))
	for j in range(water):
		ItemDB.draw_item_icon(_c, "water", Vector2(RACK_X0 + 26 + j * 28, SHELF_YS[1] - 16), 26.0, false)
	# gear
	var gx: float = RACK_X0 + 26
	for gid in ["medkit", "gas_mask", "radio", "toolbox", "map", "flashlight", "rifle", "axe"]:
		if GameState.has_working_item(gid) and gx < RACK_X1 - 20:
			ItemDB.draw_item_icon(_c, gid, Vector2(gx, SHELF_YS[2] - 16), 28.0, false)
			gx += 32
	# vehicle parts on the floor shelf
	var px: float = RACK_X0 + 30
	for part in ["car_battery", "spark_plugs", "fan_belt", "tire_patch"]:
		var n: int = int(GameState.parts.get(part, 0))
		for _k in range(mini(n, 2)):
			ItemDB.draw_item_icon(_c, part, Vector2(px, FLOOR_Y - 18), 30.0, false)
			px += 34
	var cans: int = int(float(GameState.parts.get("fuel_l", 0.0)) / 10.0)
	for _k2 in range(mini(cans, 3)):
		ItemDB.draw_item_icon(_c, "fuel_can", Vector2(px, FLOOR_Y - 18), 32.0, false)
		px += 34
	_c.draw_string(font, Vector2(RACK_X0 + 10, 168), "STORAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f2b82e"))


func _bench_members() -> Array:
	var out: Array = []
	for m_v in GameState.get_living_bunker_members():
		out.append(m_v)
	return out


func _draw_people_and_action(font: Font) -> void:
	var members: Array = _bench_members()
	var actor_id: String = str(_actor.get("id", ""))
	var subject_id: String = str(_subject.get("id", ""))
	var seat_i: int = 0
	for m_v in members:
		var m: Dictionary = m_v
		var mid: String = str(m.get("id", ""))
		var acting: bool = (mid == actor_id and _scenario not in ["tension", "gloom", "doom"]) or (mid == subject_id and _scenario in ["medical", "sickness"] and mid != actor_id)
		if _scenario == "return" and mid == actor_id:
			acting = true
		if _scenario in ["celebrate", "victory"]:
			acting = true
		if acting:
			seat_i += 1
			continue
		var seat := Vector2(BENCH_SEATS[mini(seat_i, 3)], 478)
		seat_i += 1
		CharacterArtist.draw_bunker_seated_character(_c, seat, m, _t, 1.0)
		var expr: String = _bench_expression()
		if expr != "":
			ActorArtist._draw_expression(_c, seat + Vector2(0, -78), 0.55, expr, _t)
	_draw_scenario_action(font, members)


func _bench_expression() -> String:
	match _scenario:
		"tension", "attack", "hazard":
			return "scared"
		"gloom", "doom":
			return "sad"
		"combat":
			return "scared" if _t < 1.6 else "happy"
		"gain", "celebrate", "victory", "pet":
			return "happy" if _t > 1.2 else ""
	return ""


func _walk_pose(from: Vector2, to: Vector2, a: float, b: float) -> Array:
	var k: float = _seg(_t, a, b)
	var moving: bool = _t > a and _t < b
	return [from.lerp(to, k), moving, (to.x < from.x)]


func _draw_scenario_action(font: Font, members: Array) -> void:
	var start := Vector2(560, FLOOR_Y)
	var t: float = _t
	match _scenario:
		"tension":
			if not _actor.is_empty():
				ActorArtist.draw_standing(_c, Vector2(SOLO_X, FLOOR_Y), _actor, {"arms": "point" if fmod(_t, 4.0) > 2.0 else "idle", "expr": "scared", "expr_t": _t}, 1.15)
		"combat":
			var w: Array = _walk_pose(start, Vector2(380, FLOOR_Y), 0.3, 1.1)
			var item: String = str(_params.get("item", ""))
			var prop: String = "rifle_aim" if item == "rifle" else ("axe_swing" if item == "axe" else "")
			var arms: String = "aim" if (t > 1.0 and t < 2.6 and prop != "") else ("point" if t > 1.0 and t < 2.6 else "idle")
			ActorArtist.draw_standing(_c, w[0], _actor, {"walk": t * 9.0, "moving": w[1], "flip": true, "arms": arms, "prop": prop if t > 1.0 and t < 2.6 else "", "work_t": t, "expr": "angry" if t < 2.6 else "happy", "expr_t": t}, 1.15)
			var flee: float = _seg(t, 1.6, 2.6)
			for k in range(2):
				var feet := Vector2(LADDER_X - 10.0 + float(k) * 50.0, FLOOR_Y - 40.0 - 260.0 * flee - float(k) * 30.0)
				if flee < 0.98:
					ActorArtist.draw_silhouette(_c, feet, 1.1, Color(0.06, 0.06, 0.06, 1.0 - flee), true, t)
			if item in ["dog", "cat"] or str(_params.get("item", "")) == "":
				if GameState.has_dog_pancake:
					ItemDB.draw_item_icon(_c, "dog", Vector2(lerpf(560, 320, _seg(t, 0.8, 1.6)), FLOOR_Y - 18 - absf(sin(t * 12.0)) * 10.0), 40.0, false)
		"attack":
			var come: float = _seg(t, 0.4, 1.3)
			var leave: float = _seg(t, 2.6, 3.6)
			for k2 in range(2):
				var y: float = lerpf(HATCH_Y + 20.0, FLOOR_Y, come) - 300.0 * leave
				var feet2 := Vector2(LADDER_X + 40.0 + float(k2) * 70.0 * come, y)
				ActorArtist.draw_silhouette(_c, feet2, 1.15, Color(0.06, 0.06, 0.06, 1.0 - leave), k2 == 0, t)
			var hurt: bool = t > 1.6
			var victim: Dictionary = _subject if not _subject.is_empty() else _actor
			var ppos: Vector2 = Vector2(420, FLOOR_Y)
			ActorArtist.draw_standing(_c, ppos, _with_injury(victim, hurt), {"arms": "cower" if t > 1.0 else "idle", "flip": true, "expr": "hurt" if hurt else "scared", "expr_t": t, "lean": -0.4 if hurt and t < 2.2 else 0.0}, 1.15)
			# a crate of supplies is dragged off
			if t > 2.0:
				var crate: Vector2 = Vector2(RACK_X0 - 40.0, FLOOR_Y - 20.0).lerp(Vector2(LADDER_X, HATCH_Y), _seg(t, 2.2, 3.4))
				ItemDB.draw_item_icon(_c, "soup", crate, 34.0, false)
		"repair":
			var w2: Array = _walk_pose(start, Vector2(LADDER_X + 70.0, FLOOR_Y), 0.2, 1.1)
			ActorArtist.draw_standing(_c, w2[0], _actor, {"walk": t * 9.0, "moving": w2[1], "flip": true, "arms": "work" if t > 1.1 else "idle", "prop": "wrench" if t > 1.0 else "", "work_t": t, "expr": "happy" if t > 3.3 else "", "expr_t": t}, 1.15)
			if t > 3.3:
				_check_mark((w2[0] as Vector2) + Vector2(0, -215))
		"radio":
			var w3: Array = _walk_pose(start, RADIO_POS + Vector2(-70, FLOOR_Y - RADIO_POS.y), 0.2, 1.0)
			ActorArtist.draw_standing(_c, w3[0], _actor, {"walk": t * 9.0, "moving": w3[1], "arms": "work" if t > 1.0 else "idle", "work_t": t * 0.3, "expr": "happy" if t > 2.6 else "", "expr_t": t}, 1.15)
			if t > 1.0:
				for i in range(3):
					var rr: float = fmod(t * 60.0 + float(i) * 30.0, 90.0)
					_c.draw_arc(RADIO_POS + Vector2(0, -10), rr, -2.4, -0.7, 16, Color(0.95, 0.85, 0.5, 1.0 - rr / 90.0), 2.0)
		"give":
			var w4: Array = _walk_pose(start, Vector2(LADDER_X + 50.0, FLOOR_Y), 0.2, 1.0)
			var item2: String = str(_params.get("item", ""))
			if item2 == "":
				item2 = "water"
			ActorArtist.draw_standing(_c, w4[0], _actor, {"walk": t * 9.0, "moving": w4[1], "flip": true, "arms": "give" if t > 1.0 else "carry", "prop": item2 if t < 1.6 else "", "expr": "", "expr_t": t}, 1.15)
			if t > 1.6:
				var up: Vector2 = Vector2(LADDER_X + 10.0, FLOOR_Y - 120.0).lerp(Vector2(LADDER_X, HATCH_Y), _seg(t, 1.6, 2.4))
				if t < 2.4:
					ItemDB.draw_item_icon(_c, item2, up, 34.0, false)
				var arm_y: float = lerpf(HATCH_Y - 30.0, HATCH_Y + 60.0, _seg(t, 1.4, 1.9)) - 90.0 * _seg(t, 2.4, 2.9)
				_c.draw_line(Vector2(LADDER_X + 6.0, HATCH_Y - 40.0), Vector2(LADDER_X + 6.0, arm_y), Color(0.06, 0.06, 0.06), 10.0)
		"gain":
			# Found or made inside the shelter: the actor works at it, holds it up, shelves it.
			var it_id: String = str(_params.get("item", ""))
			if it_id == "" or it_id in ["cards", "checkers", "harmonica", "toolbox"]:
				it_id = "water" if str(_caption_body).to_lower().contains("water") else "soup"
			var w5: Array = _walk_pose(start, Vector2(520.0, FLOOR_Y), 0.2, 0.9)
			var to_rack: Array = _walk_pose(Vector2(520.0, FLOOR_Y), Vector2(RACK_X0 - 40.0, FLOOR_Y), 2.3, 3.3)
			var pos5: Vector2 = w5[0] if t < 2.3 else to_rack[0]
			var arms5: String = "work" if t > 0.9 and t < 1.8 else ("cheer" if t < 2.3 and t >= 1.8 else ("carry" if t >= 2.3 else "idle"))
			ActorArtist.draw_standing(_c, pos5, _actor, {"walk": t * 9.0, "moving": bool(w5[1]) or bool(to_rack[1]), "flip": t < 0.9, "arms": arms5, "prop": it_id if t >= 1.8 and t < 3.3 else "", "work_t": t, "expr": "happy" if t > 1.8 else "focused", "expr_t": t}, 1.15)
			if t >= 3.3:
				ItemDB.draw_item_icon(_c, it_id, _rack_slot_for(it_id, 6), 30.0, false)
		"medical":
			var pat: Dictionary = _subject
			ActorArtist.draw_standing(_c, Vector2(SOLO_X, FLOOR_Y), _with_injury(pat, t < 2.2), {"arms": "slump" if t < 2.2 else "cheer", "work_t": t, "expr": "hurt" if t < 2.2 else "happy", "expr_t": t}, 1.1)
			if str(pat.get("id", "")) != str(_actor.get("id", "")):
				var w6: Array = _walk_pose(Vector2(560, FLOOR_Y), Vector2(SOLO_X + 75.0, FLOOR_Y), 0.2, 0.9)
				ActorArtist.draw_standing(_c, w6[0], _actor, {"walk": t * 9.0, "moving": w6[1], "flip": true, "arms": "bandage" if t > 0.9 else "idle", "prop": "bandage" if t > 0.9 and t < 2.2 else "", "work_t": t, "expr": "happy" if t > 2.2 else "", "expr_t": t}, 1.15)
		"sickness":
			var pat2: Dictionary = _subject
			ActorArtist.draw_standing(_c, Vector2(SOLO_X, FLOOR_Y), pat2, {"arms": "slump", "expr": "sick", "expr_t": t, "lean": 0.2 * sin(t * 3.0)}, 1.1)
			if str(pat2.get("id", "")) != str(_actor.get("id", "")):
				ActorArtist.draw_standing(_c, Vector2(SOLO_X + 80.0, FLOOR_Y), _actor, {"arms": "give", "flip": true, "prop": "water" if t > 1.0 else "", "expr": "scared", "expr_t": t}, 1.15)
		"hazard":
			for i2 in range(16):
				var phase: float = fmod(t * 0.6 + float(i2) * 0.13, 1.0)
				var pp: Vector2 = VENT_POS + Vector2(-20.0 + float(i2 % 5) * 10.0 - phase * 380.0, phase * 380.0)
				_c.draw_circle(pp, 6.0 + phase * 10.0, Color(0.55, 0.75, 0.25, 0.35 * (1.0 - phase)))
			if not _actor.is_empty():
				var masked: bool = str(_params.get("item", "")) == "gas_mask"
				var hp: Vector2 = Vector2(820, FLOOR_Y)
				ActorArtist.draw_standing(_c, hp, _actor, {"arms": "work" if masked else "cower", "work_t": t, "expr": "focused" if masked else "scared", "expr_t": t}, 1.15)
				if masked:
					ItemDB.draw_item_icon(_c, "gas_mask", hp + Vector2(0, -150), 46.0, false)
		"signal":
			var w7: Array = _walk_pose(start, Vector2(LADDER_X + 4.0, FLOOR_Y - 260.0), 0.2, 1.2)
			var item3: String = str(_params.get("item", ""))
			ActorArtist.draw_standing(_c, w7[0], _actor, {"walk": t * 9.0, "moving": w7[1], "flip": true, "arms": "climb" if t < 1.2 else "point", "prop": "flashlight_beam" if (item3 == "flashlight" and t > 1.2) else (item3 if item3 != "" and t > 1.2 else ""), "work_t": t, "expr": "focused", "expr_t": t}, 1.1)
		"victory":
			var idx: int = 0
			for m_v in members:
				var climb: float = _seg(t, 1.4 + float(idx) * 0.5, 2.6 + float(idx) * 0.5)
				var feet3: Vector2 = Vector2(LADDER_X + 60.0 + float(idx) * 70.0, FLOOR_Y).lerp(Vector2(LADDER_X, HATCH_Y + 20.0), climb)
				ActorArtist.draw_standing(_c, feet3, m_v as Dictionary, {"arms": "cheer" if climb < 0.1 else "climb", "work_t": t, "expr": "happy", "expr_t": t}, 1.05)
				idx += 1
			for k3 in range(2):
				ActorArtist.draw_silhouette(_c, Vector2(LADDER_X - 70.0 + float(k3) * 30.0, HATCH_Y + 40.0 + 60.0 * _seg(t, 0.6, 1.4)), 0.9, Color(0.9, 0.9, 0.82, 0.6), false, t)
		"celebrate", "pet":
			var idx2: int = 0
			for m_v2 in members:
				ActorArtist.draw_standing(_c, Vector2(440.0 + float(idx2) * 110.0, FLOOR_Y), m_v2 as Dictionary, {"arms": "cheer" if t > 0.8 else "idle", "work_t": t + float(idx2), "expr": "happy", "expr_t": t}, 1.05)
				idx2 += 1
			if _scenario == "pet":
				var pet_id: String = "dog" if GameState.has_dog_pancake else "cat"
				ItemDB.draw_item_icon(_c, pet_id, Vector2(fmod(t * 160.0, 900.0) + 200.0, FLOOR_Y - 18.0 - absf(sin(t * 10.0)) * 14.0), 42.0, false)
			else:
				var note_item: String = str(_params.get("item", ""))
				if note_item != "":
					ItemDB.draw_item_icon(_c, note_item, Vector2(600, 300 - sin(t * 3.0) * 8.0), 46.0, false)
				for n2 in range(4):
					var nt: float = fmod(t * 0.8 + float(n2) * 0.25, 1.0)
					var np: Vector2 = Vector2(560.0 + float(n2) * 40.0, 330.0 - nt * 140.0)
					var ncol := Color(0.95, 0.85, 0.5, 1.0 - nt)
					_c.draw_circle(np, 6.0, ncol)
					_c.draw_line(np + Vector2(5, 0), np + Vector2(5, -20), ncol, 2.0)
					_c.draw_line(np + Vector2(5, -20), np + Vector2(13, -14), ncol, 2.0)
		"mutant":
			ActorArtist.draw_standing(_c, Vector2(SOLO_X, FLOOR_Y), _subject, {"arms": "cheer", "work_t": t, "expr": "happy", "expr_t": t}, 1.15)
			_c.draw_circle(Vector2(SOLO_X, FLOOR_Y - 70), 70.0 + sin(t * 5.0) * 8.0, Color(0.5, 1.0, 0.3, 0.12))
		"gloom", "doom":
			if not _actor.is_empty() and _scenario == "gloom":
				ActorArtist.draw_standing(_c, Vector2(SOLO_X, FLOOR_Y), _actor, {"arms": "slump", "expr": "sad", "expr_t": t}, 1.15)
			for d in range(12):
				var dy: float = fmod(t * 120.0 + float(d) * 47.0, FLOOR_Y)
				_c.draw_circle(Vector2(300.0 + float(d) * 60.0, dy), 2.0, Color(0.7, 0.68, 0.6, 0.5))
		"return":
			var down: float = _seg(t, 0.7, 2.0)
			var feet4: Vector2 = Vector2(LADDER_X, HATCH_Y + 30.0).lerp(Vector2(LADDER_X + 40.0, FLOOR_Y), down)
			var walk_rack: Array = _walk_pose(Vector2(LADDER_X + 40.0, FLOOR_Y), Vector2(RACK_X0 - 60.0, FLOOR_Y), 2.0, 2.8)
			var pos6: Vector2 = feet4 if t < 2.0 else walk_rack[0]
			var injured: bool = int(_actor.get("injury", 0)) > 0
			ActorArtist.draw_standing(_c, pos6, _actor, {"walk": t * 9.0, "moving": bool(walk_rack[1]), "arms": "climb" if t < 2.0 else ("give" if t > 2.8 else "carry"), "work_t": t, "expr": ("hurt" if injured else "happy") if t > 2.8 else "focused", "expr_t": t}, 1.15)
			# backpack items fly onto the rack one by one
			var items: Array = _params.get("items", [])
			for i4 in range(items.size()):
				var it: Dictionary = items[i4]
				var t0: float = 2.8 + float(i4) * 0.45
				var dest: Vector2 = _rack_slot_for(str(it.get("item_id", "")), i4)
				var src: Vector2 = Vector2(RACK_X0 - 30.0, FLOOR_Y - 70.0)
				if t < t0:
					continue
				var k4: float = _seg(t, t0, t0 + 0.4)
				var arc: Vector2 = src.lerp(dest, k4) + Vector2(0, -sin(k4 * PI) * 70.0)
				ItemDB.draw_item_icon(_c, str(it.get("item_id", "")), arc, 34.0, false)
				if k4 >= 1.0:
					_c.draw_string(font, dest + Vector2(-20, -24), "+%d" % int(it.get("count", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#7ec850"))
		"shrug":
			if not _actor.is_empty():
				ActorArtist.draw_standing(_c, Vector2(SOLO_X, FLOOR_Y), _actor, {"arms": "point" if t > 0.8 and t < 1.8 else "idle", "expr": "", "expr_t": t}, 1.15)


func _with_injury(m: Dictionary, hurt: bool) -> Dictionary:
	if not hurt:
		return m
	var c: Dictionary = m.duplicate()
	c["injury"] = maxi(1, int(m.get("injury", 0)))
	return c


func _rack_slot_for(item_id: String, i: int) -> Vector2:
	match item_id:
		"soup":
			return Vector2(RACK_X0 + 30.0 + float(i % 6) * 30.0, SHELF_YS[0] - 16.0)
		"water":
			return Vector2(RACK_X0 + 30.0 + float(i % 6) * 30.0, SHELF_YS[1] - 16.0)
		"car_battery", "spark_plugs", "fan_belt", "tire_patch", "fuel_can":
			return Vector2(RACK_X0 + 40.0 + float(i % 5) * 36.0, FLOOR_Y - 18.0)
		_:
			return Vector2(RACK_X0 + 30.0 + float(i % 7) * 32.0, SHELF_YS[2] - 16.0)


func _check_mark(p: Vector2) -> void:
	_c.draw_circle(p, 16.0, Color("#4f8f32"))
	_c.draw_polyline(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-2, 7), p + Vector2(9, -7)]), Color.WHITE, 3.0)


func _muzzle_point() -> Vector2:
	return Vector2(380.0 - 86.0, FLOOR_Y - 118.0)


func _member(id: String) -> Dictionary:
	for m_v in GameState.family_members:
		var m: Dictionary = m_v
		if str(m.get("id", "")) == id:
			return m
	return {}


# --- garage -------------------------------------------------------------------

func _draw_garage_scene(font: Font) -> void:
	_c.draw_rect(Rect2(-200, 0, 1700, FLOOR_Y), Color("#2e2a24"))
	for x in range(-200, 1500, 120):
		_c.draw_rect(Rect2(x, 40, 116, FLOOR_Y - 40), Color("#332e27"))
	_c.draw_rect(Rect2(-200, FLOOR_Y, 1700, 260), Color("#24211c"))
	for x2 in range(-200, 1500, 80):
		_c.draw_line(Vector2(x2, FLOOR_Y), Vector2(x2 - 40, FLOOR_Y + 200), Color("#2b2721"), 2.0)
	# garage door (right) lifts during the drive-out
	var lift: float = _seg(_t, 1.6, 2.6) if _scenario == "drive" else 0.0
	var door := Rect2(1120, 140 - 300.0 * lift, 300, FLOOR_Y - 140)
	_c.draw_rect(door, Color("#5b5348"))
	for i in range(6):
		_c.draw_line(Vector2(door.position.x, door.position.y + 60.0 * float(i)), Vector2(door.end.x, door.position.y + 60.0 * float(i)), Color("#463f36"), 3.0)
	if lift > 0.05:
		_c.draw_rect(Rect2(1120, door.end.y, 300, FLOOR_Y - door.end.y), Color(0.85, 0.83, 0.7, 0.35 * lift))
	# workbench + parts rack (left)
	_c.draw_rect(Rect2(40, 390, 260, 14), Color("#5a4632"))
	_c.draw_rect(Rect2(60, 160, 220, 220), Color("#1b1f1c"))
	for sy in [240.0, 320.0]:
		_c.draw_rect(Rect2(60, sy, 220, 8), Color("#4c3e2e"))
	var x3: float = 84.0
	for part in ["car_battery", "spark_plugs", "fan_belt", "tire_patch"]:
		if int(GameState.parts.get(part, 0)) > 0:
			ItemDB.draw_item_icon(_c, part, Vector2(x3, 222), 32.0, false)
			x3 += 44.0
	var cans: int = int(float(GameState.parts.get("fuel_l", 0.0)) / 10.0)
	for c in range(mini(4, cans)):
		ItemDB.draw_item_icon(_c, "fuel_can", Vector2(90.0 + float(c) * 46.0, 300), 34.0, false)
	_c.draw_string(font, Vector2(70, 182), "PARTS RACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f2b82e"))
	# the car
	var car_x: float = 560.0
	var state: Dictionary = GameState.vehicle.duplicate()
	if _scenario == "install":
		var part2: String = str(_params.get("part", ""))
		var before: Dictionary = _params.get("before", {})
		if _t < 3.6 and not before.is_empty():
			state = before.duplicate()
		state["hood_open"] = _t > 1.9 and _t < 4.6
		if part2 == "car_battery" and _t > 3.6:
			state["lights"] = 0.5 + 0.5 * absf(sin(_t * 6.0)) if _t < 4.4 else 1.0
	if _scenario == "drive":
		car_x += 900.0 * _seg(_t, 2.4, 4.6)
		state["lights"] = 1.0
		state["running"] = true
		state["passenger_list"] = GameState.get_living_bunker_members()
	draw_car(_c, Vector2(car_x, FLOOR_Y), 1.0, state, _t)
	if _scenario == "install":
		var part3: String = str(_params.get("part", ""))
		var walk: Array = _walk_pose(Vector2(200, FLOOR_Y), Vector2(car_x + 380.0, FLOOR_Y), 0.4, 1.9)
		ActorArtist.draw_standing(_c, walk[0], _actor, {"walk": _t * 9.0, "moving": walk[1], "arms": "carry" if _t < 1.9 else "work", "prop": part3 if _t < 2.0 else "wrench", "work_t": _t, "expr": "happy" if _t > 3.8 else "focused", "expr_t": _t}, 1.15)
		if _t > 3.6:
			_check_mark(Vector2(car_x + 520.0, FLOOR_Y - 200.0))


## 1950s station wagon, side view. state: battery_installed, tires_ok, plugs_ok, belt_ok, fuel_l,
## hood_open, lights (0..1), running, wrecked. Condition is visible on the body.
static func draw_car(c: CanvasItem, base: Vector2, s: float, state: Dictionary, t: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var wrecked: bool = bool(state.get("wrecked", false))
	var body_col: Color = Color("#6c8a8f") if not wrecked else Color("#4b4a46")
	var tires_ok: bool = bool(state.get("tires_ok", true))
	var running: bool = bool(state.get("running", false))
	var shake_y: float = sin(t * 40.0) * 1.2 if running else 0.0
	var b: Vector2 = base + Vector2(0, shake_y)
	var wheel_r: float = 34.0 * s
	var ride: float = 0.0 if tires_ok else 12.0 * s
	var y_body: float = b.y - wheel_r * 1.25 + ride
	# shadow
	c.draw_rect(Rect2(b + Vector2(-20, -4) * s, Vector2(500, 10) * s), Color(0, 0, 0, 0.35))
	# body
	var body := PackedVector2Array([
		Vector2(b.x, y_body), Vector2(b.x + 12 * s, y_body - 60 * s), Vector2(b.x + 110 * s, y_body - 66 * s),
		Vector2(b.x + 150 * s, y_body - 118 * s), Vector2(b.x + 330 * s, y_body - 120 * s), Vector2(b.x + 360 * s, y_body - 70 * s),
		Vector2(b.x + 450 * s, y_body - 62 * s), Vector2(b.x + 460 * s, y_body - 10 * s), Vector2(b.x + 450 * s, y_body)
	])
	c.draw_colored_polygon(body, body_col)
	c.draw_polyline(body + PackedVector2Array([body[0]]), Color("#1d1a16"), 3.0 * s)
	# chrome stripe + windows
	c.draw_line(Vector2(b.x + 10 * s, y_body - 34 * s), Vector2(b.x + 455 * s, y_body - 34 * s), Color("#dde5ec"), 3.0 * s)
	var win_col: Color = Color(0.55, 0.7, 0.78) if not wrecked else Color(0.25, 0.25, 0.25)
	c.draw_colored_polygon(PackedVector2Array([Vector2(b.x + 160 * s, y_body - 110 * s), Vector2(b.x + 240 * s, y_body - 112 * s), Vector2(b.x + 240 * s, y_body - 72 * s), Vector2(b.x + 128 * s, y_body - 70 * s)]), win_col)
	c.draw_colored_polygon(PackedVector2Array([Vector2(b.x + 250 * s, y_body - 112 * s), Vector2(b.x + 325 * s, y_body - 112 * s), Vector2(b.x + 350 * s, y_body - 72 * s), Vector2(b.x + 250 * s, y_body - 72 * s)]), win_col)
	if wrecked:
		c.draw_polyline(PackedVector2Array([Vector2(b.x + 140 * s, y_body - 110 * s), Vector2(b.x + 220 * s, y_body - 60 * s), Vector2(b.x + 300 * s, y_body - 100 * s)]), Color("#1d1a16"), 4.0 * s)
		c.draw_rect(Rect2(Vector2(b.x + 120 * s, y_body - 160 * s), Vector2(220 * s, 50 * s)), Color("#5b5348"))
	# passengers: each survivor's head (skin tone + hair colour) framed in the windows
	var pax_list: Array = state.get("passenger_list", [])
	for pi in range(mini(pax_list.size(), 4)):
		var pm: Dictionary = pax_list[pi]
		var hx: float = b.x + (172.0 + float(pi) * 46.0) * s
		var hc := Vector2(hx, y_body - 84 * s)
		var skin_i: int = clampi(int(pm.get("skin_tone", 1)), 0, CharacterArtist.SKIN_TONES.size() - 1)
		c.draw_circle(hc, 11.0 * s, Color(CharacterArtist.SKIN_TONES[skin_i]))
		c.draw_arc(hc, 11.0 * s, PI, TAU, 12, Color(str(pm.get("hair_color", "#3b2a1e"))), 7.0 * s)
		c.draw_circle(hc + Vector2(4, -1) * s, 1.6 * s, Color("#1d1a16"))
	# wheels
	for wx in [80.0, 380.0]:
		var wc := Vector2(b.x + wx * s, b.y - wheel_r + ride * 0.3)
		if tires_ok:
			c.draw_circle(wc, wheel_r, Color("#1b1917"))
		else:
			var pts := PackedVector2Array()
			for i in range(24):
				var a: float = TAU * float(i) / 24.0
				var r: float = wheel_r * (0.75 if sin(a) > 0.3 else 1.0)
				pts.append(wc + Vector2(cos(a) * wheel_r * 1.12, sin(a) * r))
			c.draw_colored_polygon(pts, Color("#1b1917"))
		c.draw_circle(wc, wheel_r * 0.45, Color("#dde5ec"))
		var spin: float = t * 12.0 if running else 0.0
		c.draw_line(wc, wc + Vector2(cos(spin), sin(spin)) * wheel_r * 0.4, Color("#6e7982"), 3.0 * s)
	# headlight (front = right)
	var lights: float = float(state.get("lights", 0.0))
	var hl := Vector2(b.x + 452 * s, y_body - 40 * s)
	c.draw_circle(hl, 9.0 * s, Color(1.0, 0.95, 0.7, 0.4 + 0.6 * lights) if lights > 0.0 else Color("#8a8a7a"))
	if lights > 0.05:
		c.draw_colored_polygon(PackedVector2Array([hl, hl + Vector2(260, -50) * s, hl + Vector2(260, 60) * s]), Color(1.0, 0.95, 0.7, 0.12 * lights))
	# engine bay / hood
	var hood_open: bool = bool(state.get("hood_open", false))
	var bay := Rect2(Vector2(b.x + 362 * s, y_body - 66 * s), Vector2(86 * s, 30 * s))
	if hood_open:
		c.draw_rect(bay, Color("#1d1a16"))
		c.draw_line(Vector2(b.x + 362 * s, y_body - 66 * s), Vector2(b.x + 410 * s, y_body - 130 * s), body_col.darkened(0.2), 7.0 * s)
		if bool(state.get("battery_installed", false)):
			ItemDB.draw_item_icon(c, "car_battery", bay.get_center(), 26.0 * s, false)
	# condition tags pinned to the car (visible state)
	var tags: Array = []
	if not wrecked:
		tags.append(["BATTERY", bool(state.get("battery_installed", false))])
		tags.append(["PLUGS", bool(state.get("plugs_ok", true))])
		tags.append(["BELT", bool(state.get("belt_ok", true))])
		tags.append(["TIRES", tires_ok])
		tags.append(["FUEL %d L" % int(float(state.get("fuel_l", 0.0))), float(state.get("fuel_l", 0.0)) >= VehicleSystem.NEEDED_FUEL_L])
	else:
		tags.append(["WRECKED", false])
	for i2 in range(tags.size()):
		var tg: Array = tags[i2]
		var tp := Vector2(b.x + (20.0 + float(i2) * 88.0) * s, y_body - 170 * s)
		var ok: bool = bool(tg[1])
		c.draw_rect(Rect2(tp, Vector2(82, 22) * s), Color("#efe3c8"))
		c.draw_rect(Rect2(tp, Vector2(82, 22) * s), Color("#4f8f32") if ok else Color("#b8321e"), false, 2.0)
		c.draw_circle(tp + Vector2(10, 11) * s, 5.0 * s, Color("#4f8f32") if ok else Color("#b8321e"))
		c.draw_string(font, tp + Vector2(19, 16) * s, str(tg[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * s), Color("#1d1a16"))
	# exhaust when running
	if running:
		for k in range(5):
			var ph: float = fmod(t * 1.5 + float(k) * 0.2, 1.0)
			c.draw_circle(Vector2(b.x - 10 * s - ph * 80.0, y_body - 8 * s - ph * 30.0), (6.0 + ph * 14.0) * s, Color(0.6, 0.6, 0.58, 0.35 * (1.0 - ph)))
