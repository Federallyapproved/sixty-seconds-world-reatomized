extends Node
## Loads every game script so any parse/compile error fails fast.
func run() -> int:
	var bad: int = 0
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".gd"):
				var scr: Script = load(dir_path + "/" + f)
				if scr == null or not scr.can_instantiate():
					print("COMPILE FAIL: ", dir_path + "/" + f)
					bad += 1
		for sub in d.get_directories():
			stack.append(dir_path + "/" + sub)
	print("COMPILE_ALL bad=%d" % bad)
	return 1 if bad > 0 else 0
