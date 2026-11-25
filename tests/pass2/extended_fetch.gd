extends Node

## Offline checks for ExtendedAreaFetcher (the wider-area store search), using canned Overpass
## responses: suburb with almost nothing inside 2.2 km -> widens to 6 km, mirror fallback,
## total failure, survival across screen changes, and the guards that keep targets stable.

var _fails: int = 0
var _passes: int = 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		print("FAIL ", label)


func _node(id: int, lat: float, lon: float, tags: Dictionary) -> Dictionary:
	return {"type": "node", "id": id, "lat": lat, "lon": lon, "tags": tags}


func _json(elements: Array) -> String:
	return JSON.stringify({"elements": elements})


func _wait(f: ExtendedAreaFetcher) -> void:
	for _i in range(120):
		await get_tree().process_frame
		if f.state != "loading":
			return


func run() -> int:
	var h_lat: float = 37.6600
	var h_lon: float = -77.6200
	var house: Dictionary = {"osm_id": 9100001, "lat": h_lat, "lon": h_lon, "name": "Home", "is_residential": true, "street": "Walborough Court",
		"polygon_latlon": [Vector2(h_lon - 0.0001, h_lat - 0.0001), Vector2(h_lon + 0.0001, h_lat - 0.0001), Vector2(h_lon + 0.0001, h_lat + 0.0001), Vector2(h_lon - 0.0001, h_lat + 0.0001)]}
	var bldgs: Array = [house]
	for k in range(6):
		var la: float = h_lat + 0.0005 * float(k + 1)
		bldgs.append({"osm_id": 9100010 + k, "lat": la, "lon": h_lon, "name": "", "is_residential": true, "area_sqm": 160.0, "street": "Walborough Court", "housenumber": str(6200 + k),
			"polygon_latlon": [Vector2(h_lon - 0.0001, la - 0.0001), Vector2(h_lon + 0.0001, la - 0.0001), Vector2(h_lon + 0.0001, la + 0.0001), Vector2(h_lon - 0.0001, la + 0.0001)]})
	GameState.selected_house = house
	GameState.osm_local_buildings = bldgs
	GameState.osm_local_pois = []
	GameState.osm_local_roads = [{"osm_id": 1, "name": "Walborough Court", "kind": "residential", "points_latlon": [Vector2(h_lon, h_lat - 0.003), Vector2(h_lon, h_lat + 0.004)]}]
	GameState.active_expedition = {}
	GameState.nearby_pois = OsmService.build_nearby_targets_for_house(house, bldgs, [], GameState.osm_local_roads)
	var only_houses: bool = true
	for t in GameState.nearby_pois:
		if str(t.get("category", "")) not in ["house", "neighbor_house"]:
			only_houses = false
	_ok(only_houses and not GameState.nearby_pois.is_empty(), "before the wider search: suburban house sees only neighbouring homes (%d)" % GameState.nearby_pois.size())

	var f: ExtendedAreaFetcher = GameState.get_extended_fetcher()
	_ok(f.get_parent() == GameState, "store search lives under the GameState autoload (survives screen changes)")

	# 1) 2.2 km: one grocery + a main road -> too few essentials -> widen; 6 km: main server 503 -> mirror.
	var stage0: String = _json([
		_node(501, h_lat + 0.0135, h_lon, {"shop": "convenience", "name": "7-Eleven"}),
		{"type": "way", "id": 601, "tags": {"highway": "primary", "name": "Pouncey Tract Road"}, "geometry": [{"lat": h_lat - 0.01, "lon": h_lon + 0.004}, {"lat": h_lat + 0.02, "lon": h_lon + 0.004}]},
	])
	var stage1: String = _json([
		_node(502, h_lat + 0.031, h_lon + 0.004, {"shop": "supermarket", "name": "Food Lion"}),
		_node(503, h_lat - 0.034, h_lon - 0.01, {"shop": "supermarket", "name": "Kroger"}),
		_node(504, h_lat + 0.030, h_lon + 0.006, {"amenity": "pharmacy", "name": "CVS Pharmacy"}),
		_node(505, h_lat - 0.036, h_lon + 0.002, {"shop": "hardware", "name": "Ace Hardware"}),
		_node(506, h_lat + 0.029, h_lon + 0.008, {"amenity": "fuel", "name": "Exxon"}),
		_node(501, h_lat + 0.0135, h_lon, {"shop": "convenience", "name": "7-Eleven"}),
	])
	f.test_responses = [{"code": 200, "body": stage0}, {"code": 503, "body": ""}, {"code": 200, "body": stage1}]
	f.start(h_lat, h_lon)
	_ok(f.state == "loading" and f.message.contains("2.2 km"), "search starts at 2.2 km and says so: '%s'" % f.message)
	await _wait(f)
	_ok(f.state == "loaded" and f.radius_searched_m == 6000, "too few essentials within 2.2 km -> widened to 6 km (%s, %d m)" % [f.state, f.radius_searched_m])
	_ok(f.last_query.contains("around:6000") and not f.last_query.contains("highway"), "6 km request asks for places only (no road geometry)")
	_ok(f.last_endpoint == ExtendedAreaFetcher.ENDPOINTS[1], "main server failure falls back to the mirror")
	_ok(f.pois.size() == 6, "results merged without duplicates (%d places)" % f.pois.size())
	var cats: Dictionary = {}
	var first_service_index: int = -1
	var max_days: int = 0
	for i in range(GameState.nearby_pois.size()):
		var t: Dictionary = GameState.nearby_pois[i]
		var c: String = str(t.get("category", ""))
		cats[c] = int(cats.get(c, 0)) + 1
		if c not in ["house", "neighbor_house"] and first_service_index < 0:
			first_service_index = i
		max_days = maxi(max_days, int(t.get("travel_days", 0)))
	_ok(int(cats.get("grocery", 0)) >= 2 and int(cats.get("pharmacy", 0)) == 1 and int(cats.get("hardware", 0)) == 1 and int(cats.get("auto", 0)) == 1,
		"expedition targets now include the real stores: %s" % str(cats))
	_ok(first_service_index == 0, "stores are listed before neighbouring homes")
	_ok(max_days >= 2, "a store ~3.5 km away is a multi-day trip (max %d days)" % max_days)
	var has_road: bool = false
	for r in GameState.map_roads:
		if str(r.get("name", "")) == "Pouncey Tract Road":
			has_road = true
	_ok(has_road, "main roads from the wider search are added to the shelter map")
	_ok(f.message.contains("6.0 km") and f.message.contains("2 food") or f.message.contains("3 food"), "status reports what was found and how far: '%s'" % f.message)

	# 2) Total failure: honest message, local targets only.
	f.test_responses = [{"code": 504, "body": ""}, {"code": 429, "body": ""}]
	f.start(h_lat, h_lon)
	await _wait(f)
	_ok(f.state == "failed" and f.message.contains("unavailable"), "both servers down -> failed with an honest message")
	var all_houses: bool = true
	for t2 in GameState.nearby_pois:
		if str(t2.get("category", "")) not in ["house", "neighbor_house"]:
			all_houses = false
	_ok(all_houses, "after a failed search nothing is invented: only real homes remain")

	# 3) Nothing mapped even at 6 km.
	f.test_responses = [{"code": 200, "body": _json([])}, {"code": 200, "body": _json([])}]
	f.start(h_lat, h_lon)
	await _wait(f)
	_ok(f.state == "loaded" and f.message.contains("No stores") and f.message.contains("6.0 km"), "nothing within 6 km -> says so: '%s'" % f.message)

	# 4) Guards: an expedition under way keeps its target list; a stale result for another area is ignored.
	# M1: once the hatch has closed the run refers to places by index, so late results may only add
	# places at the end, never reshuffle the existing ones.
	f.test_responses = [{"code": 200, "body": stage1}]
	BunkerSim.start_bunker_run()
	var ids_before: Array = []
	for t0 in GameState.nearby_pois:
		ids_before.append(int((t0 as Dictionary).get("osm_id", 0)))
	var places_before: int = GameState.shelter.places.size()
	f.start(h_lat, h_lon)
	await _wait(f)
	var ids_after: Array = []
	for t1 in GameState.nearby_pois:
		ids_after.append(int((t1 as Dictionary).get("osm_id", 0)))
	_ok(ids_after.slice(0, ids_before.size()) == ids_before and GameState.shelter.places.size() == GameState.nearby_pois.size() and GameState.shelter.places.size() >= places_before, "results arriving mid-run never reshuffle targets (new stores are appended to the run)")
	GameState.shelter = null
	var before: int = GameState.nearby_pois.size()
	f.test_responses = [{"code": 200, "body": stage1}]
	f.start(h_lat + 0.2, h_lon)
	await _wait(f)
	_ok(GameState.nearby_pois.size() == before, "results for an area far from the chosen house are ignored")

	print("EXTENDED_FETCH pass=%d fail=%d" % [_passes, _fails])
	return _fails
