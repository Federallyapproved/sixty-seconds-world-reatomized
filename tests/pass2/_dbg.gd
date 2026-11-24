extends Node
func run() -> int:
	for pid in ["seattle", "concord", "brooklyn"]:
		var parsed: Dictionary = OsmService.load_preset(pid)
		var house: Dictionary = OsmService.pick_best_house(parsed["buildings"], float(parsed["center_lat"]), float(parsed["center_lon"]), int(parsed["preferred_osm_id"]))
		GameState.map_landmarks = parsed["landmarks"]
		var t: Array = OsmService.build_nearby_targets_for_house(house, parsed["buildings"], parsed["pois"], parsed["roads"])
		print(pid, " house=", house["short_address"], " targets=", t.size(), " local=", NukePhysics.pick_local_target(float(house["lat"]), float(house["lon"]))["target_name"])
		var cats: Dictionary = {}
		for x in t:
			cats[x["category"]] = int(cats.get(x["category"], 0)) + 1
		print("   cats ", cats)
		for x in t.slice(0, 7):
			print("   - %s [%s/%s] straight %dm walk %dm (%s)" % [x["name"], x["category"], x.get("kind_label",""), x["distance_m"], x["walk_m"], x["walk_source"]])
	return 0
