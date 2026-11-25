extends SceneTree

## Builds assets/characters/family_anims.res: the few clips the family uses, cut from Quaternius'
## Universal Animation Library 1 and 2 (CC0, free "Standard" versions). The source GLBs are large
## (15–19 MB each) and are not kept in the repo; download them from quaternius.itch.io and pass
## their paths:
##   godot --headless --path . -s res://tools/build_family_anims.gd -- --ual1=<UAL1_Standard.glb> --ual2=<UAL2_Standard.glb>
## Track paths are rewritten to "Skeleton3D:<bone>" so the library plays on any Universal Base
## Character whose AnimationPlayer root is the node holding its Skeleton3D.

const KEEP_UAL1: Array[String] = [
	"Idle_Loop", "Crouch_Idle_Loop", "Sitting_Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Interact",
	"PickUp_Table", "Hit_Chest", "Death01", "Dance_Loop", "Fixing_Kneeling", "Idle_Talking_Loop",
]
const KEEP_UAL2: Array[String] = [
	"Idle_FoldArms_Loop", "Idle_TalkingPhone_Loop", "Walk_Carry_Loop", "Yes", "Idle_No_Loop", "Consume", "LayToIdle",
]
const OUT: String = "res://assets/characters/family_anims.res"


func _init() -> void:
	var ual1: String = ""
	var ual2: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ual1="):
			ual1 = a.substr(7)
		elif a.begins_with("--ual2="):
			ual2 = a.substr(7)
	var lib := AnimationLibrary.new()
	var n: int = _take(ual1, KEEP_UAL1, lib) + _take(ual2, KEEP_UAL2, lib)
	if n < KEEP_UAL1.size() + KEEP_UAL2.size():
		printerr("FAMILY_ANIMS missing clips: got %d" % n)
		quit(1)
		return
	var err: int = ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("FAMILY_ANIMS clips=%d saved=%s err=%d" % [n, OUT, err])
	quit(0 if err == OK else 1)


func _take(path: String, names: Array[String], lib: AnimationLibrary) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		printerr("not found: " + path)
		return 0
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		printerr("could not read " + path)
		return 0
	var scene: Node = doc.generate_scene(state)
	var ap: AnimationPlayer = _find_player(scene)
	if ap == null:
		printerr("no AnimationPlayer in " + path)
		return 0
	var skel: Skeleton3D = _find_skeleton(scene)
	var skel_path: String = str(ap.get_node(ap.root_node).get_path_to(skel)) if skel != null else "Skeleton3D"
	var got: int = 0
	for nm in names:
		if not ap.has_animation(nm):
			printerr("clip missing: %s in %s" % [nm, path.get_file()])
			continue
		var src: Animation = ap.get_animation(nm)
		var dst: Animation = src.duplicate(true)
		for t in range(dst.get_track_count()):
			var p: String = str(dst.track_get_path(t))
			var colon: int = p.find(":")
			if colon < 0:
				continue
			var node_part: String = p.substr(0, colon)
			if node_part == skel_path or node_part.ends_with("Skeleton3D") or node_part.ends_with(str(skel.name) if skel != null else "Skeleton3D"):
				dst.track_set_path(t, NodePath("Skeleton3D" + p.substr(colon)))
		# Root motion off: the hips may sway, but the figure stays where the game puts it.
		dst.loop_mode = Animation.LOOP_LINEAR if nm.ends_with("_Loop") else Animation.LOOP_NONE
		lib.add_animation(nm, dst)
		got += 1
	print("  %s: %d clips (skeleton at %s, %d bones)" % [path.get_file(), got, skel_path, skel.get_bone_count() if skel != null else 0])
	scene.free()
	return got


func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r: AnimationPlayer = _find_player(c)
		if r != null:
			return r
	return null


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_skeleton(c)
		if r != null:
			return r
	return null
