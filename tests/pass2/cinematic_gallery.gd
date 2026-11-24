extends SceneTree

## Renders every cinematic scenario at two moments to a contact sheet for visual review.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --audio-driver Dummy -s res://tests/pass2/cinematic_gallery.gd -- --out=/tmp/gallery

const CASES: Array = [
	["combat", {"tags": ["raid"], "item_used": "rifle", "choice_id": "use_rifle", "outcome_text": "Raiders forced the hatch; the rifle drove them back up the ladder."}],
	["attack", {"tags": ["raid", "injured"], "item_used": "", "choice_id": "hide", "outcome_text": "Two raiders dropped in, hurt Dolores and took a crate of soup."}],
	["repair", {"tags": ["item_repaired"], "item_used": "toolbox", "outcome_text": "The vent fan is turning again."}],
	["radio", {"tags": ["rescue_progress"], "item_used": "radio", "outcome_text": "A National Guard operator answered on 640 kc."}],
	["give", {"tags": ["item_lost"], "item_used": "water", "choice_id": "give_water", "outcome_text": "We passed a bottle of water up to the stranger."}],
	["gain", {"tags": ["item_gained"], "item_used": "", "outcome_text": "The condensation still gave three quarters of a bottle of water."}],
	["medical", {"tags": ["healed"], "item_used": "medkit", "outcome_text": "The medkit stopped the bleeding."}],
	["sickness", {"tags": ["sick"], "item_used": "", "outcome_text": "Timmy is running a fever."}],
	["hazard", {"tags": ["hazard_return"], "item_used": "gas_mask", "outcome_text": "Dust poured from the vent; the gas mask kept the sweeper breathing clean air."}],
	["signal", {"tags": ["rescue_progress"], "item_used": "flashlight", "outcome_text": "Morse flashes from the hatch were answered."}],
	["celebrate", {"tags": ["morale_up"], "item_used": "harmonica", "outcome_text": "A harmonica tune lifted everyone's spirits."}],
	["gloom", {"tags": ["morale_down"], "item_used": "", "outcome_text": "Nobody spoke for hours."}],
	["pet", {"tags": ["companion"], "item_used": "dog", "outcome_text": "The dog curled up between the kids."}],
	["victory", {"tags": ["victory"], "item_used": "radio", "outcome_text": "Rescuers opened the hatch."}],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var out: String = "/tmp/gallery"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.split("=")[1]
	DirAccess.make_dir_recursive_absolute(out)
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var gs: Node = root.get_node("GameState")
	await _frames(6)
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for pair in [["soup", 5], ["water", 6], ["medkit", 1], ["gas_mask", 1], ["radio", 1], ["rifle", 1], ["toolbox", 1]]:
		gs.call("add_scavenged_item", pair[0], pair[1])
	gs.set("has_dog_pancake", true)
	gs.call("request_screen", "bunker")
	await _frames(30)
	var bk: Node = main.get("_active_node")
	var cine: Control = bk.get("_cinematic")
	# dismiss today's dilemma
	while cine.visible:
		if str(cine.get("_mode")) == "dilemma":
			bk.call("_on_dilemma_choice", bk.call("_auto_choice_id"))
		cine.set("_t", 99.0)
		await _frames(2)
		if str(cine.get("_mode")) == "caption":
			cine.call("_on_continue")
		await _frames(2)
	var members: Array = gs.call("get_living_bunker_members")
	var leader: Dictionary = members[0]
	var other: Dictionary = members[mini(1, members.size() - 1)]
	var ok: int = 0
	for c in CASES:
		var oc: Dictionary = (c[1] as Dictionary).duplicate()
		oc["actor_id"] = str(leader.get("id", ""))
		oc["subject_id"] = str(other.get("id", ""))
		var ev: Dictionary = {"title": str(c[0]).capitalize() + " test", "category": "test"}
		var sc: String = cine.call("scenario_for", oc, ev)
		if sc != str(c[0]):
			print("MAPPING_MISMATCH ", c[0], " -> ", sc)
		else:
			ok += 1
		cine.call("play_outcome", oc, ev)
		var dur: float = float(cine.get("_dur"))
		for frac in [0.35, 0.75]:
			cine.set("_t", dur * frac - 0.05)
			await _frames(3)
			await _snap(out, "%s_%02d" % [c[0], int(frac * 100.0)])
		cine.set("_t", 99.0)
		await _frames(2)
		cine.call("_on_continue")
		await _frames(2)
	print("GALLERY_DONE mapping_ok=%d/%d" % [ok, CASES.size()])
	quit(0)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _snap(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(out + "/" + name + ".png")
