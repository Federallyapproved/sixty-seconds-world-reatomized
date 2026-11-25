class_name ExtendedAreaFetcher
extends Node

## Finds the real stores, pharmacies, garages, churches, schools and police/fire stations around
## the chosen house (Overpass API). Lives under the GameState autoload, so the search keeps
## running after the player leaves the house-select screen, and its results are folded into the
## expedition targets whenever they arrive (before any expedition is under way).
##
## Suburbs often have nothing within 2.2 km, so when fewer than MIN_ESSENTIALS food / medicine /
## hardware / auto places turn up, the search widens to 6 km (POIs only). Each request falls back
## to a mirror if the main Overpass server fails. Nothing is ever invented: if nothing is mapped,
## the status says so and the expedition list stays honest.

signal status_changed(text: String, busy: bool)
signal updated()

const RADII_M: Array[int] = [2200, 6000]
const ENDPOINTS: Array[String] = [
	"https://overpass-api.de/api/interpreter",
	"https://overpass.kumi.systems/api/interpreter",
]
const ESSENTIAL_CATEGORIES: Array[String] = ["grocery", "pharmacy", "hardware", "auto"]
const MIN_ESSENTIALS: int = 3

var state: String = "idle"          # idle | loading | loaded | failed
var radius_searched_m: int = 0
var pois: Array = []
var roads: Array = []
var message: String = ""
var center_lat: float = 0.0
var center_lon: float = 0.0

## Tests: queue {"code": int, "body": String} here to answer requests without the network.
var test_responses: Array = []
var last_query: String = ""
var last_endpoint: String = ""

var _http: HTTPRequest
var _stage: int = 0
var _endpoint_i: int = 0
var _token: int = 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 50.0
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)


func start(lat: float, lon: float) -> void:
	_token += 1
	center_lat = lat
	center_lon = lon
	state = "loading"
	radius_searched_m = 0
	pois = []
	roads = []
	_stage = 0
	_endpoint_i = 0
	_set_status("Searching OpenStreetMap for stores and services within %.1f km…" % (RADII_M[0] / 1000.0), true)
	_request()


func reset() -> void:
	_token += 1
	if _http != null:
		_http.cancel_request()
	state = "idle"
	radius_searched_m = 0
	pois = []
	roads = []
	message = ""


static func build_query(lat: float, lon: float, radius_m: int, with_roads: bool) -> String:
	var a: String = "(around:%d,%.6f,%.6f)" % [radius_m, lat, lon]
	var q: String = "[out:json][timeout:40];("
	q += "nwr%s[shop~\"^(supermarket|convenience|grocery|general|greengrocer|bakery|butcher|hardware|doityourself|trade|car_repair|car_parts|tyres|chemist|medical_supply|outdoor)$\"];" % a
	q += "nwr%s[amenity~\"^(pharmacy|hospital|clinic|doctors|fire_station|police|fuel|place_of_worship|school|library|community_centre|townhall)$\"];" % a
	if with_roads:
		q += "way%s[highway~\"^(motorway|trunk|primary|secondary|tertiary)$\"];" % a
	q += ");out geom tags qt;"
	return q


func _request() -> void:
	var tok: int = _token
	last_query = build_query(center_lat, center_lon, RADII_M[_stage], _stage == 0)
	last_endpoint = ENDPOINTS[_endpoint_i]
	if not test_responses.is_empty():
		var r: Dictionary = test_responses.pop_front()
		_finish_request.call_deferred(tok, HTTPRequest.RESULT_SUCCESS, int(r.get("code", 200)), str(r.get("body", "")).to_utf8_buffer())
		return
	_http.cancel_request()
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	if not OS.has_feature("web"):
		headers.append(OsmService.USER_AGENT_HEADER)
	var err: int = _http.request(last_endpoint, headers, HTTPClient.METHOD_POST, "data=" + last_query.uri_encode())
	if err != OK:
		_finish_request.call_deferred(tok, HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())


func _on_http_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_finish_request(_token, result, code, body)


func _finish_request(tok: int, result: int, code: int, body: PackedByteArray) -> void:
	if tok != _token:
		return
	var parsed: Variant = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
			parsed = json.data
	if parsed == null:
		if _endpoint_i < ENDPOINTS.size() - 1:
			_endpoint_i += 1
			_set_status("Store search: main server busy (HTTP %d) — trying a mirror…" % code, true)
			_request()
			return
		if pois.is_empty():
			state = "failed"
			_set_status("Store search unavailable right now (HTTP %d) — only places within ~450 m are listed. Pick the house again later to retry." % code, false)
			_publish()
			return
		_complete()
		return
	var ext: Dictionary = OsmService.parse_overpass_extended(parsed as Dictionary)
	var seen: Dictionary = {}
	for p_v in pois:
		seen[int((p_v as Dictionary).get("osm_id", 0))] = true
	for p_v in ext.get("pois", []):
		var p: Dictionary = p_v
		var pid: int = int(p.get("osm_id", 0))
		if seen.has(pid):
			continue
		seen[pid] = true
		p["extended"] = true
		pois.append(p)
	if _stage == 0:
		roads = ext.get("roads", [])
	radius_searched_m = RADII_M[_stage]
	if essential_count() < MIN_ESSENTIALS and _stage < RADII_M.size() - 1:
		_stage += 1
		_endpoint_i = 0
		_set_status("Only %d food/medicine/hardware/auto places within %.1f km — widening the search to %.0f km…" % [essential_count(), RADII_M[_stage - 1] / 1000.0, RADII_M[_stage] / 1000.0], true)
		_request()
		return
	_complete()


func essential_count() -> int:
	var n: int = 0
	for p_v in pois:
		if str((p_v as Dictionary).get("category", "")) in ESSENTIAL_CATEGORIES:
			n += 1
	return n


func _complete() -> void:
	state = "loaded"
	var by_cat: Dictionary = {}
	for p_v in pois:
		var c: String = str((p_v as Dictionary).get("category", ""))
		by_cat[c] = int(by_cat.get(c, 0)) + 1
	var km: String = "%.1f km" % (radius_searched_m / 1000.0)
	if pois.is_empty():
		_set_status("No stores or services are mapped in OpenStreetMap within %s — expeditions are limited to neighbouring homes." % km, false)
	else:
		_set_status("Found within %s: %d food · %d medical · %d hardware · %d fuel/auto · %d other" % [
			km, int(by_cat.get("grocery", 0)), int(by_cat.get("pharmacy", 0)), int(by_cat.get("hardware", 0)), int(by_cat.get("auto", 0)),
			pois.size() - int(by_cat.get("grocery", 0)) - int(by_cat.get("pharmacy", 0)) - int(by_cat.get("hardware", 0)) - int(by_cat.get("auto", 0))], false)
	_publish()


## Folds the results into GameState: map roads and (if no expedition is under way, since targets
## are referenced by index) the expedition target list for the chosen house.
func _publish() -> void:
	GameState.extended_pois = pois.duplicate(true)
	GameState.extended_roads = roads.duplicate(true)
	GameState.extended_status = message
	GameState.extended_radius_m = radius_searched_m
	var house: Dictionary = GameState.selected_house
	var near_center: bool = not house.is_empty() and float(OsmService.distance_and_bearing(center_lat, center_lon, float(house.get("lat", 0.0)), float(house.get("lon", 0.0)))["distance_m"]) < 3000.0
	if near_center:
		var all_roads: Array = GameState.osm_local_roads.duplicate()
		all_roads.append_array(roads)
		GameState.map_roads = all_roads
		if GameState.shelter == null:
			var all_pois: Array = GameState.osm_local_pois.duplicate()
			all_pois.append_array(pois)
			GameState.nearby_pois = OsmService.build_nearby_targets_for_house(GameState.selected_house, GameState.osm_local_buildings, all_pois, all_roads)
		else:
			_append_to_running_shelter(all_roads)
	updated.emit()


## The hatch is already closed: existing targets keep their places (the run refers to them by
## index); stores found now are added at the end, to the target list and to the run.
func _append_to_running_shelter(all_roads: Array) -> void:
	var s: ShelterState = GameState.shelter
	var known: Dictionary = {}
	for p_v in GameState.nearby_pois:
		known[int((p_v as Dictionary).get("osm_id", 0))] = true
	var fresh: Array = []
	for p_v in pois:
		var p: Dictionary = p_v
		if str(p.get("category", "")) in ESSENTIAL_CATEGORIES and not known.has(int(p.get("osm_id", 0))):
			fresh.append(p)
	if fresh.is_empty():
		return
	var built: Array = OsmService.build_nearby_targets_for_house(GameState.selected_house, [], fresh, all_roads)
	var stock_mult: float = ShelterData.B("story_stock_mult", 1.5) if s.difficulty == "story" else 1.0
	for t_v in built:
		var t: Dictionary = t_v
		if str(t.get("category", "")) == "neighbor_house":
			continue
		var idx: int = GameState.nearby_pois.size()
		GameState.nearby_pois.append(t)
		s.places.append(ShelterTrips.make_place(t, idx, RadiationModel.location_factor(float(t.get("lat", 0.0)), float(t.get("lon", 0.0))), stock_mult))


func _set_status(t: String, busy: bool) -> void:
	message = t
	status_changed.emit(t, busy)
