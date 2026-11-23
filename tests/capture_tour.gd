extends SceneTree

## Automated Visual Tour & Smoke Verification Runner for Critic Sub-Agents.
## Usage:
## xvfb-run -a -s "-screen 0 1280x720x24" /home/antigravity/.local/bin/godot --path /home/antigravity/sixty_seconds_world --rendering-driver opengl3 -s res://tests/capture_tour.gd

func _init() -> void:
	call_deferred("_run_tour")

func _run_tour() -> void:
	var out_dir := "/home/antigravity/sixty_seconds_world/screenshots"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var main_packed: PackedScene = load("res://scenes/main.tscn")
	var main_inst: Control = main_packed.instantiate()
	root.add_child(main_inst)

	await _wait_frames(8)
	await _snap(out_dir + "/01_title_screen.png")

	var gs: Node = root.get_node("GameState")
	gs.call("request_screen", "family")
	await _wait_frames(10)
	await _snap(out_dir + "/02_family_creator.png")

	gs.call("request_screen", "osm_house")
	await _wait_frames(25)
	await _snap(out_dir + "/03_osm_house_picker.png")

	gs.call("request_screen", "nuke")
	await _wait_frames(12)
	await _snap(out_dir + "/04_nuke_ground_zero.png")

	gs.call("request_screen", "scavenge")
	await _wait_frames(20)
	await _snap(out_dir + "/05_scavenge_house.png")

	# Populate sample bunker inventory & rescued family for bunker visual audit
	var members: Array = gs.get("family_members")
	for m in members:
		m["in_bunker"] = true
		m["alive"] = true
	gs.call("add_scavenged_item", "soup", 5)
	gs.call("add_scavenged_item", "water", 6)
	gs.call("add_scavenged_item", "medkit", 2)
	gs.call("add_scavenged_item", "gas_mask", 1)
	gs.call("add_scavenged_item", "radio", 1)
	gs.call("add_scavenged_item", "rifle", 1)
	gs.call("add_scavenged_item", "book", 1)
	gs.call("add_scavenged_item", "suitcase", 1)
	gs.call("add_scavenged_item", "padlock", 1)

	gs.call("request_screen", "bunker")
	await _wait_frames(15)
	await _snap(out_dir + "/06_bunker_survival.png")

	gs.set("victory", true)
	gs.set("game_over", true)
	gs.set("ending_title", "RESCUED BY NEIGHBORHOOD SANCTUARY!")
	gs.set("ending_description", "Guided by their neighborhood map and radio, the family linked up with survivors at All Pilgrims Christian Church and rebuilt a thriving community.")
	gs.call("request_screen", "summary")
	await _wait_frames(10)
	await _snap(out_dir + "/07_summary_screen.png")

	print("SCREENSHOT_TOUR_COMPLETE")
	quit(0)

func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(path)
		print("Saved screenshot: " + path)
