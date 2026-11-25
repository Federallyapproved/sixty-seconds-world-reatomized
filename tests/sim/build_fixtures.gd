extends Node

## Builds the balance harness's home fixtures (tests/fixtures/sim_homes/*.json) from cached OSM
## extracts (tests/fixtures/osm_raw/, fetched by tools/fetch_sim_osm.py) using the game's own
## parsers, target picker and walking network, so the harness sees exactly the places the game
## would offer. No network access.
## Usage: godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/build_fixtures.gd

const RAW: String = "res://tests/fixtures/osm_raw"
const OUT: String = "res://tests/fixtures/sim_homes"
const HOUSES_PER_LOCATION: int = 4
const STRIKE_KM: Array[float] = [4.0, 8.0, 14.0, 6.0]


func run() -> int:
	var dir := DirAccess.open(RAW)
	if dir == null:
		push_error("no raw OSM data; run tools/fetch_sim_osm.py first")
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n: int = 0
	var metas: Array[String] = []
	for f in dir.get_files():
		if f.ends_with("_meta.json"):
			metas.append(f)
	metas.sort()
	for f in metas:
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAW + "/" + f))
		n += _build_location(meta)
	print("BUILD_FIXTURES wrote %d home fixtures" % n)
	return 0


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _build_location(meta: Dictionary) -> int:
	var lid: String = str(meta["id"])
	var lat: float = float(meta["lat"])
	var lon: float = float(meta["lon"])
	var local: Dictionary
	var landmarks: Array = []
	if lid.begins_with("preset_"):
		local = OsmService.load_preset(lid.substr(7))
		landmarks = local.get("landmarks", [])
	else:
		local = OsmService.parse_osm_json(_read("%s/%s_local.json" % [RAW, lid]), lat, lon)
	var ext_pois: Array = []
	var ext_roads: Array = []
	var seen: Dictionary = {}
	for p_v in local.get("pois", []):
		seen[int((p_v as Dictionary).get("osm_id", 0))] = true
	for r in [2200, 6000]:
		var raw: Dictionary = _read("%s/%s_ext%d.json" % [RAW, lid, r])
		if raw.is_empty():
			continue
		var ext: Dictionary = OsmService.parse_overpass_extended(raw)
		for p_v in ext.get("pois", []):
			var pid: int = int((p_v as Dictionary).get("osm_id", 0))
			if seen.has(pid):
				continue
			seen[pid] = true
			(p_v as Dictionary)["extended"] = true
			ext_pois.append(p_v)
		if r == 2200:
			ext_roads = ext.get("roads", [])
	var buildings: Array = local.get("buildings", [])
	var houses: Array = _pick_houses(buildings, lat, lon)
	if houses.is_empty():
		houses = [OsmService.make_fictional_homestead(lat, lon)]
	var written: int = 0
	for i in range(houses.size()):
		var house: Dictionary = houses[i]
		var all_pois: Array = (local.get("pois", []) as Array).duplicate()
		all_pois.append_array(ext_pois)
		var roads: Array = (local.get("roads", []) as Array).duplicate()
		roads.append_array(ext_roads)
		var targets: Array = OsmService.build_nearby_targets_for_house(house, buildings, all_pois, roads)
		# Strike: a 250 kt burst at a varying distance, wind blowing toward the house (worst case).
		var tgt: Dictionary
		if not landmarks.is_empty() and i == 0:
			tgt = NukePhysics.pick_local_target(float(house["lat"]), float(house["lon"]), landmarks)
		else:
			var pt: Dictionary = NukePhysics.destination_point(float(house["lat"]), float(house["lon"]), 225.0 + 40.0 * float(i), STRIKE_KM[i % STRIKE_KM.size()])
			tgt = {"lat": float(pt["lat"]), "lon": float(pt["lon"]), "target_name": "fixture strike"}
		var wind: float = NukePhysics.bearing_deg(float(tgt["lat"]), float(tgt["lon"]), float(house["lat"]), float(house["lon"]))
		GameState.selected_house = house.duplicate(true)
		GameState.nuke_config = NukePhysics.compute_impact(float(house["lat"]), float(house["lon"]), float(tgt["lat"]), float(tgt["lon"]), 250, wind, str(tgt.get("target_name", "")))
		GameState.rad_hotspots = []
		GameState.extra_strikes = []
		var factors: Array = []
		var slim: Array = []
		var nearest: float = 99999.0
		for t_v in targets:
			var t: Dictionary = t_v
			factors.append(RadiationModel.location_factor(float(t.get("lat", 0.0)), float(t.get("lon", 0.0))))
			var walk: float = float(t.get("walk_m", t.get("distance_m", 0.0)))
			slim.append({
				"osm_id": int(t.get("osm_id", 0)), "name": str(t.get("name", "")), "category": str(t.get("category", "")),
				"subkind": str(t.get("subkind", "")), "lat": float(t.get("lat", 0.0)), "lon": float(t.get("lon", 0.0)),
				"walk_m": walk, "walk_source": str(t.get("walk_source", "")), "distance_m": float(t.get("distance_m", 0.0)),
				"area_sqm": float(t.get("area_sqm", 0.0)), "fictional": bool(t.get("fictional", false)),
			})
			if str(t.get("category", "")) in ["grocery", "pharmacy"]:
				nearest = minf(nearest, walk)
		var fx: Dictionary = {
			"id": "%s_%d" % [lid, i], "location": lid, "group": str(meta.get("group", "")),
			"house": {"osm_id": int(house.get("osm_id", 0)), "lat": float(house["lat"]), "lon": float(house["lon"]), "area_sqm": float(house.get("area_sqm", 120.0))},
			"targets": slim, "rad_factors": factors, "h1_home_msv": RadiationModel.h1_home_msv(),
			"nuke": {"distance_km": float(GameState.nuke_config.get("distance_km", 0.0)), "yield_kt": 250, "zone": str(GameState.nuke_config.get("zone", "")), "bunker_temp_c": float(GameState.nuke_config.get("bunker_temp_c", 19.0))},
			"nearest_essential_m": nearest,
		}
		var f := FileAccess.open("%s/%s.json" % [OUT, str(fx["id"])], FileAccess.WRITE)
		f.store_string(JSON.stringify(fx, "\t"))
		written += 1
		print("  %s: %d targets, nearest grocery/pharmacy %s, H1 %.0f mSv/h" % [str(fx["id"]), slim.size(), ("%.0f m" % nearest) if nearest < 99999.0 else "none", float(fx["h1_home_msv"])])
	return written


## A spread of homes: the one nearest the centre, then others at increasing distance.
func _pick_houses(buildings: Array, lat: float, lon: float) -> Array:
	var res: Array = []
	for b_v in buildings:
		var b: Dictionary = b_v
		if bool(b.get("is_residential", false)) and float(b.get("area_sqm", 0.0)) >= 50.0 and float(b.get("area_sqm", 0.0)) <= 600.0:
			res.append(b)
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return NukePhysics.haversine_km(lat, lon, float(a["lat"]), float(a["lon"])) < NukePhysics.haversine_km(lat, lon, float(b["lat"]), float(b["lon"])))
	if res.size() <= HOUSES_PER_LOCATION:
		return res
	var out: Array = []
	for k in range(HOUSES_PER_LOCATION):
		out.append(res[int(float(k) / float(HOUSES_PER_LOCATION) * float(res.size()) * 0.8)])
	return out
