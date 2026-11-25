extends SceneTree

## Plays the M1 shelter phase like a player, through the real screen and real input events:
## number keys answer the day's dilemma, SPACE finishes the outcome animation, mouse clicks toggle
## the ration row and plan an expedition in the trip planner (risk preview, gear), ENTER ends the
## day. Screenshots every day and writes a JSON report of what it verified.
## M3: the job button opens a menu (Rest, Trip, Craft, Study); the test takes junk apart at the
## Bench, puts a survivor at the workbench and another on the manual, all with the mouse.
## Needs a display for screenshots (run in a normal no-focus window via override.cfg).
##   godot --path . --rendering-driver opengl3 -s res://tests/pass2/play_shelter.gd -- --out=<dir> [--seed=7] [--days=12]
## (The pre-M1 version drove the old notebook tabs and the garage; both were replaced by the
## one-screen day and the disabled car escape. Its checks map to the ones below.)

var _out: String = "user://play_shelter"
var _main: Control
var _gs: Node
var _bk: Node
var _report: Dictionary = {"checks": [], "days": []}


func _init() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.split("=")[1]
	return fallback


func _check(name: String, ok: bool, detail: String = "") -> void:
	(_report["checks"] as Array).append({"name": name, "ok": ok, "detail": detail})
	print(("PASS " if ok else "FAIL ") + name + ("" if detail == "" else "  — " + detail))


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _snap(name: String) -> void:
	await _frames(2)
	if DisplayServer.get_name() == "headless":
		return
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [_out, name])


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await _frames(1)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	root.push_input(up)
	await _frames(2)


func _click(c: Control) -> void:
	var p: Vector2 = c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	root.push_input(mv)
	await _frames(1)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = p
		ev.global_position = p
		ev.pressed = pressed
		root.push_input(ev)
		await _frames(1)
	await _frames(2)


func _buttons(n: Node, prefix: String, out: Array) -> void:
	if n is Button and (n as Button).is_visible_in_tree() and str((n as Button).text).begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		_buttons(c, prefix, out)


func _named(n: Node, prefix: String, out: Array) -> void:
	if n is Button and (n as Button).is_visible_in_tree() and str(n.name).begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		_named(c, prefix, out)


func _by_name(prefix: String) -> Array:
	var out: Array = []
	_named(root, prefix, out)
	return out


## Opens a survivor's job menu with the mouse and clicks one entry (JobTrip, JobCraft, JobStudy).
func _job(mid: String, entry: String) -> bool:
	var jb: Array = _by_name("Job_" + mid)
	if jb.is_empty() or (jb[0] as Button).disabled:
		return false
	await _click(jb[0])
	await _frames(4)
	var it: Array = _by_name(entry)
	if it.is_empty() or (it[0] as Button).disabled:
		return false
	await _click(it[0])
	await _frames(12)
	return true


func _find(prefix: String) -> Array:
	var out: Array = []
	_buttons(_bk, prefix, out)
	return out


func _finish_cinematic() -> void:
	var cine: Node = _bk.get("_cinematic")
	var guard: int = 0
	while (bool(_bk.get("_busy")) or bool(cine.get("visible"))) and guard < 400:
		if bool(cine.get("visible")):
			await _key(KEY_SPACE)
		await _frames(4)
		guard += 1


func _run() -> void:
	_out = _arg("out", "user://play_shelter")
	DirAccess.make_dir_recursive_absolute(_out)
	var days: int = int(_arg("days", "12"))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_gs = root.get_node("GameState")
	(_gs.get("rng") as RandomNumberGenerator).seed = int(_arg("seed", "7"))
	await _frames(8)
	# Choose the real default house through the actual house-select screen.
	_gs.call("request_screen", "osm_house")
	await _frames(30)
	var hs: Node = _main.get("_active_node")
	var picked: bool = false
	for b in hs.get("_current_buildings"):
		if int(b.get("osm_id", 0)) == 206082403:
			hs.call("_select_house", b, false)
			picked = true
			break
	_check("house_select_real_osm_way", picked, "way 206082403")
	_gs.call("reset_to_defaults")
	for m in _gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for pair in [["food", 4], ["water", 5], ["medkit", 1], ["gas_mask", 1], ["radio", 1], ["rifle", 1], ["ammo", 1], ["map", 1], ["flashlight", 1], ["suitcase", 1],
			["manual", 1], ["bedsheet", 1], ["sanitizer", 1], ["toaster", 1]]:
		_gs.call("add_scavenged_item", pair[0], pair[1])
	var alm: Dictionary = _gs.get("almanac")
	for iid in ShelterData.core_ids():
		if iid != "console":
			Almanac.mark_seen(alm, iid)
	_gs.call("request_screen", "bunker")
	await _frames(40)
	_bk = _main.get("_active_node")
	var s: ShelterState = _gs.get("shelter")
	_check("shelter_run_started", s != null and s.day == 1)
	_check("one_screen_day_panel", _bk.get("_panel") != null and _bk.get("_receipt_box") != null and _bk.get("_family_box") != null)
	await _snap("p00_day1")
	var planned_trip: bool = false
	var trip_member: String = ""
	var saw_away: bool = false
	var saw_return: bool = false
	var saw_used: bool = false
	var saw_end_locked: bool = false
	var saw_needs: bool = false
	var saw_meeting: bool = false
	var saw_console_option: bool = false
	var saw_toast: bool = false
	var aff_member: Dictionary = {}
	var bench_done: bool = false
	var crafter: String = ""
	var studier: String = ""
	for d in range(days):
		if s.is_over():
			break
		# M2: on day 5 Maya hits the bottom (as a run of bad days would do); the warning comes first.
		if s.day == 5 and aff_member.is_empty():
			aff_member = s.members[2]   # Maya
			aff_member["morale_cap"] = 0   # nothing lifts her tonight (no cards, no quiet-day recovery)
			# Outside an event, a drop happens at night: its warning is read tomorrow morning and the
			# affliction can only take hold the morning after that.
			s.night = true
			ShelterSim.add_morale(s, aff_member, -10, "")
			s.night = false
		if not aff_member.is_empty() and ShelterState.affliction(aff_member) != "" and int(aff_member.get("morale_cap", 10)) == 0:
			aff_member["morale_cap"] = 10
		var day_rec: Dictionary = {"day": s.day, "event": str(s.today_event.get("id", ""))}
		# The End Day button is locked until the dilemma is answered.
		if not s.today_event.is_empty() and not s.today_resolved:
			saw_end_locked = saw_end_locked or bool((_bk.get("_end_btn") as Button).disabled)
			for o_v in s.today_options:
				if str((o_v as Dictionary).get("needs", "")) != "":
					saw_needs = true
				if str((o_v as Dictionary).get("item", "")) == "console":
					saw_console_option = true
			var pick: int = -1
			for i in range(s.today_options.size()):
				var o: Dictionary = s.today_options[i]
				if bool(o.get("available", false)) and (pick < 0 or str(o.get("item", "")) != ""):
					pick = i
			if d == 1:
				await _snap("p10_dilemma")
			var is_meeting: bool = str(s.today_event.get("id", "")) == "house_meeting"
			if is_meeting:
				await _snap("p50_house_meeting")
			await _key(KEY_1 + pick)
			if is_meeting:
				saw_meeting = true
				_check("house_meeting_answered_with_keys", not s.rules.is_empty() or int(s.stats["rules_declined"]) > 0, str(s.rules))
			day_rec["choice"] = str((s.today_options[pick] as Dictionary)["id"])
			await _frames(20)
			await _finish_cinematic()
			day_rec["outcome"] = str((_bk.get("_outcome") as Dictionary).get("text", ""))
			for l_v in (_bk.get("_outcome") as Dictionary).get("lines", []):
				if str((l_v as Dictionary).get("text", "")).begins_with("Used:"):
					saw_used = true
		# Water anyone who would be thirsty tomorrow, by clicking their ration toggles.
		var plan: Dictionary = _bk.get("_plan")
		for m_v in s.home():
			var m: Dictionary = m_v
			var idx: int = s.members.find(m)
			var want: bool = int(m.get("dww", 0)) >= 2 and s.water() > 0
			var have: bool = bool(((plan["rations"] as Dictionary).get(str(m["id"]), {}) as Dictionary).get("water", false))
			if want != have:
				var rows: Array = (_bk.get("_family_box") as Node).get_children()
				if idx >= 0 and idx < rows.size():
					var row_btns: Array = []
					_buttons(rows[idx], "", row_btns)
					# [food toggle, water toggle, treat, job]
					if row_btns.size() >= 2:
						await _click(row_btns[1])
			var want_f: bool = int(m.get("dwf", 0)) >= 5 and s.food() > 0
			var have_f: bool = bool(((plan["rations"] as Dictionary).get(str(m["id"]), {}) as Dictionary).get("food", false))
			if want_f != have_f:
				var rows2: Array = (_bk.get("_family_box") as Node).get_children()
				if idx >= 0 and idx < rows2.size():
					var fb: Array = []
					_buttons(rows2[idx], "", fb)
					if not fb.is_empty():
						await _click(fb[0])
		# M3, day 1: take junk apart at the Bench, then a day at the workbench and a day with the manual.
		if not bench_done and s.day == 1:
			bench_done = true
			var parts_before: int = ShelterCraft.parts_total(s)
			await _click(_by_name("BenchButton")[0])
			await _frames(12)
			var ta: Array = _by_name("TakeApart_toaster")
			if not ta.is_empty():
				await _click(ta[0])
				await _frames(8)
			await _snap("p15_bench")
			_check("bench_takes_junk_apart_with_a_click", ShelterCraft.parts_total(s) == parts_before + 3 and not s.has("toaster"), "parts %d -> %d" % [parts_before, ShelterCraft.parts_total(s)])
			await _click(_by_name("Back")[0])
			await _frames(8)
			for m_v in s.home():
				var m: Dictionary = m_v
				if not bool(m.get("is_leader", false)) and not ShelterState.is_child(m) and crafter == "":
					crafter = str(m["id"])
				elif bool(m.get("is_leader", false)):
					studier = str(m["id"])
			var opened_c: bool = false
			if crafter != "":
				opened_c = await _job(crafter, "JobCraft")
			if opened_c:
				var make: Array = _by_name("Make_rag_bandage")
				if not make.is_empty() and not (make[0] as Button).disabled:
					await _click(make[0])
					await _frames(6)
				await _snap("p16_workbench")
				var conf: Array = _by_name("Confirm")
				if not conf.is_empty() and not (conf[0] as Button).disabled:
					await _click(conf[0])
					await _frames(10)
			var cj: Dictionary = ((_bk.get("_plan") as Dictionary)["jobs"] as Dictionary).get(crafter, {})
			_check("workbench_job_set_with_the_mouse", str(cj.get("job", "")) == "craft", str(cj))
			var opened_s: bool = false
			if studier != "":
				opened_s = await _job(studier, "JobStudy")
			if opened_s:
				var st: Array = _by_name("Study_ch1")
				if not st.is_empty():
					await _click(st[0])
					await _frames(10)
			var sj: Dictionary = ((_bk.get("_plan") as Dictionary)["jobs"] as Dictionary).get(studier, {})
			_check("study_job_set_with_the_mouse", str(sj.get("job", "")) == "study", str(sj))
			await _snap("p17_jobs")
		if s.day == 2 and crafter != "" and not bool(_report.get("bench_checked", false)):
			_report["bench_checked"] = true
			var made_txt: String = ""
			for l_v in (_bk.get("_morning") as Dictionary).get("morning", []):
				made_txt += str((l_v as Dictionary).get("text", "")) + " | "
			_check("crafted_overnight_with_a_receipt", made_txt.find("made a rag bandage") != -1 or made_txt.find("fell apart on the bench") != -1, made_txt.substr(0, 240))
			_check("chapter_learned_overnight", s.chapters.has("ch1"), str(s.chapters))
		# Day 2 onwards: plan an expedition through the planner with the mouse.
		if not planned_trip and s.day >= 2:
			var trip_btns: Array = []
			for m_v in s.home():
				if ShelterTrips.can_go(s, m_v as Dictionary) == "":
					trip_btns.append(str((m_v as Dictionary)["id"]))
			for tmid in trip_btns:
				var opened_t: bool = await _job(str(tmid), "JobTrip")
				if not opened_t:
					continue
				var tp: Node = _bk.get("_planner")
				if tp == null:
					break
				var list: Array = []
				_buttons(tp, "", list)
				var place_btn: Button = null
				for b2 in list:
					if str((b2 as Button).text).find(" min walk · risk ") != -1:
						place_btn = b2
						break
				if place_btn != null:
					await _click(place_btn)
					await _frames(8)
					await _snap("p20_trip_preview")
					var preview_txt: String = ""
					for c in (tp.get("_preview") as Node).get_children():
						if c is Label:
							preview_txt += str((c as Label).text) + " | "
					_check("risk_preview_shows_days_risk_dose_loot", preview_txt.find("Trip:") != -1 and preview_txt.find("Chance of not coming back:") != -1 and preview_txt.find("Dose:") != -1 and preview_txt.find("Last stocked:") != -1, preview_txt.substr(0, 200))
					var send: Array = []
					_buttons(tp, "Send them tonight", send)
					if not send.is_empty() and not (send[0] as Button).disabled:
						await _click(send[0])
						for k in ((_bk.get("_plan") as Dictionary)["jobs"] as Dictionary).keys():
							trip_member = str(k)
						planned_trip = trip_member != ""
				break
			if planned_trip:
				await _snap("p30_trip_planned")
		if not aff_member.is_empty() and ShelterState.affliction(aff_member) != "" and not bool(_report.get("aff_shot", false)):
			_report["aff_shot"] = true
			var aff_name: String = str(ShelterData.affliction(ShelterState.affliction(aff_member)).get("name", ""))
			var row_txt: String = ""
			for lbl in (_bk.get("_family_box") as Node).find_children("*", "Label", true, false):
				row_txt += str((lbl as Label).text) + " | "
			_check("affliction_shown_in_family_row", row_txt.find(aff_name) != -1, "%s: %s" % [aff_name, row_txt.substr(0, 160)])
			await _snap("p60_affliction")
		var toast: Node = root.find_child("AchievementToast", true, false)
		if toast != null and (toast.get("_panel") as Control).visible:
			saw_toast = true
			if not bool(_report.get("toast_shot", false)):
				_report["toast_shot"] = true
				await _snap("p70_achievement_toast")
		await _snap("p40_day%02d" % s.day)
		var day_before: int = s.day
		await _key(KEY_ENTER)
		await _frames(50)
		await _finish_cinematic()
		_check("day_%d_advanced" % day_before, s.day == day_before + 1 or s.is_over())
		for m_v in s.members:
			if str((m_v as Dictionary).get("loc", "")) == "away":
				saw_away = true
		for l_v in (_bk.get("_morning") as Dictionary).get("morning", []):
			if str((l_v as Dictionary).get("kind", "")) == "trip":
				saw_away = true
			if str((l_v as Dictionary).get("kind", "")) == "return":
				saw_return = true
			if str((l_v as Dictionary).get("text", "")).begins_with("Used:"):
				saw_used = true
		(_report["days"] as Array).append(day_rec)
	_check("end_day_locked_until_dilemma_answered", saw_end_locked)
	_check("trip_planned_with_mouse_in_planner", planned_trip, trip_member)
	_check("explorer_left_the_shelter", saw_away)
	_check("explorer_came_back_with_a_receipt", saw_return or s.is_over())
	_check("receipts_name_what_items_did", saw_used)
	_check("item_options_show_needs_when_missing", saw_needs)
	_check("undiscovered_item_options_stay_hidden", not saw_console_option, "the console was never found")
	_check("house_meeting_came_up", saw_meeting)
	var warn_day: int = -1
	var onset_day: int = -1
	for j in s.journal:
		for l_v in (j as Dictionary)["lines"]:
			var tx: String = str((l_v as Dictionary).get("text", ""))
			if tx.begins_with("Maya") and tx.find(" now:") == -1 and str((l_v as Dictionary).get("kind", "")) == "warn" and warn_day < 0:
				warn_day = int((j as Dictionary)["day"])
			if tx.begins_with("Maya is ") and tx.find(" now:") != -1 and onset_day < 0:
				onset_day = int((j as Dictionary)["day"])
	_check("affliction_took_hold_after_a_warning", warn_day > 0 and onset_day > warn_day, "warning read on day %d, affliction on day %d" % [warn_day, onset_day])
	_check("achievement_unlocked_with_a_toast", saw_toast or not (_gs.get("run_new_achievements") as Array).is_empty(), str(_gs.get("run_new_achievements")))
	await _snap("p90_last")
	var f := FileAccess.open("%s/play_shelter_report.json" % _out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "\t"))
	var fails: int = 0
	for c_v in _report["checks"]:
		if not bool((c_v as Dictionary)["ok"]):
			fails += 1
	print("PLAY_SHELTER checks=%d fails=%d" % [(_report["checks"] as Array).size(), fails])
	quit(0 if fails == 0 else 1)
