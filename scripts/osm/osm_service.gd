class_name OsmService
extends Node

## Real-world OpenStreetMap geocoding, live 0.6 map.json neighborhood fetcher,
## polite wide-area multi-ring (0-9.5 km) Nominatim POI scanner, bundled preset loader,
## building footprint geometry parser, 9-category V2 POI classifier, and neighborhood modifier engine.

signal search_completed(results: Array, query: String)
signal search_failed(error_message: String)
signal map_data_loaded(parsed_data: Dictionary, label: String)
signal map_data_failed(error_message: String)
signal wide_area_pois_merged(all_pois: Array, added_count: int)
signal status_changed(status_text: String, is_busy: bool)

const USER_AGENT_HEADER := "User-Agent: SixtySecondsWorldReatomized/2.0"
const ACCEPT_JSON_HEADER := "Accept: application/json"
const NOMINATIM_SEARCH_URL := "https://nominatim.openstreetmap.org/search?q=%s&format=json&limit=5"
const NOMINATIM_VIEWBOX_URL := "https://nominatim.openstreetmap.org/search?q=%s&format=json&limit=8&bounded=1&viewbox=%.5f,%.5f,%.5f,%.5f"
const OSM_MAP_BBOX_URL := "https://api.openstreetmap.org/api/0.6/map.json?bbox=%.6f,%.6f,%.6f,%.6f"

const LAT_HALF_SPAN := 0.0040
const LON_HALF_SPAN := 0.0055
const WIDE_VIEWBOX_DEG := 0.070
const WIDE_SCAN_STEP_SEC := 1.20

const PRESET_CONFIGS: Dictionary = {
	"seattle": {
		"id": "seattle",
		"button_label": "Seattle",
		"neighborhood_label": "Capitol Hill, Seattle, WA",
		"path": "res://data/osm_presets/seattle_capitol_hill.json",
		"lat": 47.6240,
		"lon": -122.3195,
		"preferred_osm_id": 206082403
	},
	"wyndham": {
		"id": "wyndham",
		"button_label": "Suburban VA",
		"neighborhood_label": "Suburban VA (Walborough Ct)",
		"path": "res://data/osm_presets/wyndham_walborough_va.json",
		"lat": 37.7085,
		"lon": -77.6077,
		"preferred_osm_id": 706121395
	},
	"concord": {
		"id": "concord",
		"button_label": "Concord",
		"neighborhood_label": "Historic Center, Concord, MA",
		"path": "res://data/osm_presets/concord_massachusetts.json",
		"lat": 42.4603,
		"lon": -71.3490,
		"preferred_osm_id": 212583739
	},
	"brooklyn": {
		"id": "brooklyn",
		"button_label": "Brooklyn",
		"neighborhood_label": "Carroll Gardens, Brooklyn, NY",
		"path": "res://data/osm_presets/brooklyn_carroll_gardens.json",
		"lat": 40.6802,
		"lon": -73.9930,
		"preferred_osm_id": 248154036
	}
}

const DOCTOR_AMENITIES: Array = [
	"doctors", "clinic", "hospital", "dentist", "veterinary"
]
const PHARMACY_SHOPS: Array = [
	"chemist", "medical_supply"
]
const GROCERY_SHOPS: Array = [
	"supermarket", "convenience", "grocery", "greengrocer", "bakery",
	"deli", "butcher", "general", "wholesale", "health_food", "seafood", "farm", "cheese", "pastry"
]
const FUEL_AUTO_AMENITIES: Array = [
	"fuel", "car_wash", "charging_station"
]
const FUEL_AUTO_SHOPS: Array = [
	"car_repair", "car_parts", "tyres", "car"
]
const HARDWARE_SHOPS: Array = [
	"hardware", "doityourself", "outdoor", "sports", "electronics",
	"locksmith", "tools", "garden_centre"
]
const CIVIC_AMENITIES: Array = [
	"fire_station", "police", "ranger_station", "civil_defence"
]
const IGNORED_EMERGENCY_TAGS: Array = [
	"no", "yes", "designated", "permissive", "destination", "private", "official",
	"fire_hydrant", "defibrillator", "phone", "siren", "suction_point", "water_tank",
	"assembly_point", "access_point", "landing_site", "lifebuoy", "fire_extinguisher",
	"fire_hose", "fire_alarm_box", "key_depot"
]
const CHURCH_BUILDINGS: Array = [
	"church", "cathedral", "chapel", "mosque", "synagogue", "temple", "shrine"
]
const SCHOOL_AMENITIES: Array = [
	"school", "library", "college", "university", "community_centre", "kindergarten"
]
const SCHOOL_SHOPS: Array = [
	"books", "stationery"
]
const COMPASS_DIRS: Array = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var _search_http: HTTPRequest
var _map_http: HTTPRequest
var _wide_poi_http: HTTPRequest
var _wide_scan_timer: Timer

var _active_query: String = ""
var _auto_fetch_after_search: bool = true
var _pending_lat: float = 47.6240
var _pending_lon: float = -122.3195
var _pending_label: String = ""

# Multi-Ring Wide-Area Live Nominatim Scanner State
var _wide_scan_queue: Array = []
var _wide_scan_current: Dictionary = {}
var _wide_scan_lat: float = 0.0
var _wide_scan_lon: float = 0.0
var _wide_scan_label: String = ""
var _wide_scan_pois: Array = []
var _wide_scan_generation: int = 0
var _wide_scan_in_flight: bool = false

func _ready() -> void:
	_search_http = HTTPRequest.new()
	_search_http.name = "NominatimSearchHTTP"
	_search_http.timeout = 10.0
	add_child(_search_http)
	_search_http.request_completed.connect(_on_search_request_completed)

	_map_http = HTTPRequest.new()
	_map_http.name = "OsmMapBboxHTTP"
	_map_http.timeout = 14.0
	add_child(_map_http)
	_map_http.request_completed.connect(_on_map_request_completed)

	_wide_poi_http = HTTPRequest.new()
	_wide_poi_http.name = "WideAreaPoiHTTP"
	_wide_poi_http.timeout = 9.0
	add_child(_wide_poi_http)
	_wide_poi_http.request_completed.connect(_on_wide_poi_request_completed)

	_wide_scan_timer = Timer.new()
	_wide_scan_timer.name = "WideAreaScanTimer"
	_wide_scan_timer.one_shot = true
	_wide_scan_timer.wait_time = WIDE_SCAN_STEP_SEC
	add_child(_wide_scan_timer)
	_wide_scan_timer.timeout.connect(_dispatch_next_wide_poi_query)

static func get_preset_list() -> Array:
	return [
		PRESET_CONFIGS["seattle"],
		PRESET_CONFIGS["wyndham"],
		PRESET_CONFIGS["concord"],
		PRESET_CONFIGS["brooklyn"]
	]

static func load_preset(preset_id: String) -> Dictionary:
	var key: String = preset_id if PRESET_CONFIGS.has(preset_id) else "seattle"
	var cfg: Dictionary = PRESET_CONFIGS[key]
	var path: String = str(cfg.get("path", ""))
	var center_lat: float = float(cfg.get("lat", 47.6240))
	var center_lon: float = float(cfg.get("lon", -122.3195))
	var label: String = str(cfg.get("neighborhood_label", "Capitol Hill, Seattle, WA"))

	if not FileAccess.file_exists(path):
		var fallback: Dictionary = parse_osm_json({"elements": []}, center_lat, center_lon)
		fallback["label"] = label
		fallback["preset_id"] = key
		fallback["preferred_osm_id"] = int(cfg.get("preferred_osm_id", -1))
		return fallback

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		var fallback_open: Dictionary = parse_osm_json({"elements": []}, center_lat, center_lon)
		fallback_open["label"] = label
		fallback_open["preset_id"] = key
		fallback_open["preferred_osm_id"] = int(cfg.get("preferred_osm_id", -1))
		return fallback_open

	var raw_text: String = f.get_as_text()
	f.close()

	var json := JSON.new()
	var err: int = json.parse(raw_text)
	var root_dict: Dictionary = {}
	if err == OK and typeof(json.data) == TYPE_DICTIONARY:
		root_dict = json.data

	var parsed: Dictionary = parse_osm_json(root_dict, center_lat, center_lon)
	parsed["label"] = label
	parsed["preset_id"] = key
	parsed["preferred_osm_id"] = int(cfg.get("preferred_osm_id", -1))
	return parsed

func cancel_requests() -> void:
	_wide_scan_generation += 1
	_wide_scan_queue.clear()
	_wide_scan_current.clear()
	_wide_scan_in_flight = false
	if is_instance_valid(_wide_scan_timer):
		_wide_scan_timer.stop()
	if is_instance_valid(_search_http):
		_search_http.cancel_request()
	if is_instance_valid(_map_http):
		_map_http.cancel_request()
	if is_instance_valid(_wide_poi_http):
		_wide_poi_http.cancel_request()

func search_nominatim(query: String, auto_fetch_top: bool = true) -> void:
	var trimmed: String = query.strip_edges()
	if trimmed.is_empty():
		status_changed.emit("Enter a street address, neighborhood, or city first.", false)
		search_failed.emit("Empty search query.")
		return

	cancel_requests()
	_active_query = trimmed
	_auto_fetch_after_search = auto_fetch_top

	# Support direct "lat, lon" coordinate entry for power users as well!
	var coord_pair: Dictionary = _try_parse_latlon_input(trimmed)
	if bool(coord_pair.get("valid", false)):
		var direct_lat: float = float(coord_pair.get("lat", 0.0))
		var direct_lon: float = float(coord_pair.get("lon", 0.0))
		var direct_label: String = "%.4f, %.4f" % [direct_lat, direct_lon]
		var synthetic_results: Array = [{
			"display_name": "Coordinates " + direct_label,
			"short_name": direct_label,
			"lat": direct_lat,
			"lon": direct_lon
		}]
		search_completed.emit(synthetic_results, trimmed)
		if auto_fetch_top:
			fetch_live_osm_bbox(direct_lat, direct_lon, direct_label)
		return

	var encoded: String = trimmed.uri_encode()
	var url: String = NOMINATIM_SEARCH_URL % encoded
	var headers: PackedStringArray = PackedStringArray() if OS.has_feature("web") else PackedStringArray([USER_AGENT_HEADER, ACCEPT_JSON_HEADER])

	status_changed.emit("GEOCODING \"%s\" VIA NOMINATIM..." % trimmed.to_upper(), true)
	var req_err: int = _search_http.request(url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		var msg: String = "Nominatim HTTP start error (%d)." % req_err
		status_changed.emit(msg, false)
		search_failed.emit(msg)

func fetch_live_osm_bbox(lat: float, lon: float, label: String = "") -> void:
	_wide_scan_generation += 1
	_wide_scan_queue.clear()
	_wide_scan_current.clear()
	_wide_scan_in_flight = false
	if is_instance_valid(_wide_scan_timer):
		_wide_scan_timer.stop()
	if is_instance_valid(_wide_poi_http):
		_wide_poi_http.cancel_request()
	if is_instance_valid(_map_http):
		_map_http.cancel_request()

	_pending_lat = clampf(lat, -84.5, 84.5)
	_pending_lon = clampf(lon, -179.9, 179.9)
	_pending_label = label if not label.strip_edges().is_empty() else ("%.4f, %.4f" % [_pending_lat, _pending_lon])

	var min_lon: float = _pending_lon - LON_HALF_SPAN
	var min_lat: float = _pending_lat - LAT_HALF_SPAN
	var max_lon: float = _pending_lon + LON_HALF_SPAN
	var max_lat: float = _pending_lat + LAT_HALF_SPAN

	var url: String = OSM_MAP_BBOX_URL % [min_lon, min_lat, max_lon, max_lat]
	var headers: PackedStringArray = PackedStringArray() if OS.has_feature("web") else PackedStringArray([USER_AGENT_HEADER, ACCEPT_JSON_HEADER])

	status_changed.emit("FETCHING LIVE OSM BUILDINGS & POIS AT %s..." % _pending_label.to_upper(), true)
	var req_err: int = _map_http.request(url, headers, HTTPClient.METHOD_GET)
	if req_err != OK:
		var msg: String = "OSM API 0.6 request failed (%d)." % req_err
		status_changed.emit(msg, false)
		map_data_failed.emit(msg)

func _on_search_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var err_msg: String = "Nominatim lookup unavailable (HTTP %d). Try a preset or check connection." % response_code
		status_changed.emit(err_msg, false)
		search_failed.emit(err_msg)
		return

	var text: String = body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_ARRAY:
		var parse_msg: String = "Invalid Nominatim response JSON."
		status_changed.emit(parse_msg, false)
		search_failed.emit(parse_msg)
		return

	var raw_arr: Array = json.data
	if raw_arr.is_empty():
		var none_msg: String = "No OpenStreetMap location found for \"%s\"." % _active_query
		status_changed.emit(none_msg, false)
		search_failed.emit(none_msg)
		return

	var clean_results: Array = []
	for entry_v in raw_arr:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v
		var r_lat: float = float(entry.get("lat", 0.0))
		var r_lon: float = float(entry.get("lon", 0.0))
		var disp: String = str(entry.get("display_name", "")).strip_edges()
		if disp.is_empty():
			disp = "%.4f, %.4f" % [r_lat, r_lon]
		clean_results.append({
			"display_name": disp,
			"short_name": _shorten_display_name(disp),
			"lat": r_lat,
			"lon": r_lon
		})

	if clean_results.is_empty():
		status_changed.emit("No valid coordinates returned for \"%s\"." % _active_query, false)
		search_failed.emit("No valid results.")
		return

	search_completed.emit(clean_results, _active_query)

	if _auto_fetch_after_search:
		var top: Dictionary = clean_results[0]
		fetch_live_osm_bbox(
			float(top.get("lat", 0.0)),
			float(top.get("lon", 0.0)),
			str(top.get("short_name", _active_query))
		)
	else:
		status_changed.emit("Found %d locations for \"%s\"." % [clean_results.size(), _active_query], false)

func _on_map_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Synthesize rural/emergency neighborhood at requested coordinates so player is never softlocked!
		var fallback_parsed: Dictionary = parse_osm_json({"elements": []}, _pending_lat, _pending_lon)
		fallback_parsed["label"] = _pending_label
		fallback_parsed["live_fallback"] = true
		var warn_msg: String = "OSM API HTTP %d — synthesized roadside parcels at %s." % [response_code, _pending_label]
		status_changed.emit(warn_msg, false)
		map_data_loaded.emit(fallback_parsed, _pending_label)
		var fb_pois_v: Variant = fallback_parsed.get("pois", [])
		var fb_pois: Array = fb_pois_v if typeof(fb_pois_v) == TYPE_ARRAY else []
		_start_wide_area_poi_scan(_pending_lat, _pending_lon, _pending_label, fb_pois)
		return

	var text: String = body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		var err_msg: String = "Failed to parse OSM 0.6 map.json payload."
		status_changed.emit(err_msg, false)
		map_data_failed.emit(err_msg)
		return

	var root_dict: Dictionary = json.data
	var parsed: Dictionary = parse_osm_json(root_dict, _pending_lat, _pending_lon)
	parsed["label"] = _pending_label
	var b_v: Variant = parsed.get("buildings", [])
	var p_v: Variant = parsed.get("pois", [])
	var b_count: int = (b_v as Array).size() if typeof(b_v) == TYPE_ARRAY else 0
	var base_pois: Array = (p_v as Array) if typeof(p_v) == TYPE_ARRAY else []
	var p_count: int = base_pois.size()
	status_changed.emit(
		"LIVE OSM: %s • %d BLDGS • %d LOCAL POIS (SCANNING 1-8KM DISTRICT...)" % [_pending_label.to_upper(), b_count, p_count],
		false
	)
	map_data_loaded.emit(parsed, _pending_label)
	_start_wide_area_poi_scan(_pending_lat, _pending_lon, _pending_label, base_pois)

# --- Polite Non-Blocking Multi-Ring (0.5-9.5km) Nominatim Viewbox POI Scanner ---

func _start_wide_area_poi_scan(lat: float, lon: float, label: String, initial_pois: Array) -> void:
	_wide_scan_generation += 1
	_wide_scan_lat = lat
	_wide_scan_lon = lon
	_wide_scan_label = label
	_wide_scan_pois = initial_pois.duplicate(true)
	_wide_scan_in_flight = false
	_wide_scan_current.clear()
	_wide_scan_queue = [
		{"query": "supermarket", "category": "grocery", "osm_tag": "shop=supermarket", "subkind": "supermarket", "gen": _wide_scan_generation},
		{"query": "clinic", "category": "doctor", "osm_tag": "amenity=clinic", "subkind": "clinic", "gen": _wide_scan_generation},
		{"query": "fuel", "category": "fuel_auto", "osm_tag": "amenity=fuel", "subkind": "fuel", "gen": _wide_scan_generation}
	]
	if is_instance_valid(_wide_scan_timer):
		_wide_scan_timer.wait_time = WIDE_SCAN_STEP_SEC
		_wide_scan_timer.start()

func _dispatch_next_wide_poi_query() -> void:
	if _wide_scan_in_flight or _wide_scan_queue.is_empty() or not is_instance_valid(_wide_poi_http):
		return

	var next_v: Variant = _wide_scan_queue.pop_front()
	if typeof(next_v) != TYPE_DICTIONARY:
		return
	var spec: Dictionary = next_v
	if int(spec.get("gen", -1)) != _wide_scan_generation:
		return

	_wide_scan_current = spec
	var q_term: String = str(spec.get("query", "supermarket")).uri_encode()
	var min_lon: float = clampf(_wide_scan_lon - WIDE_VIEWBOX_DEG, -179.9, 179.9)
	var max_lat: float = clampf(_wide_scan_lat + WIDE_VIEWBOX_DEG, -84.9, 84.9)
	var max_lon: float = clampf(_wide_scan_lon + WIDE_VIEWBOX_DEG, -179.9, 179.9)
	var min_lat: float = clampf(_wide_scan_lat - WIDE_VIEWBOX_DEG, -84.9, 84.9)

	var url: String = NOMINATIM_VIEWBOX_URL % [q_term, min_lon, max_lat, max_lon, min_lat]
	var headers: PackedStringArray = PackedStringArray() if OS.has_feature("web") else PackedStringArray([USER_AGENT_HEADER, ACCEPT_JSON_HEADER])
	var err: int = _wide_poi_http.request(url, headers, HTTPClient.METHOD_GET)
	if err == OK:
		_wide_scan_in_flight = true
	elif not _wide_scan_queue.is_empty() and is_instance_valid(_wide_scan_timer):
		_wide_scan_timer.wait_time = WIDE_SCAN_STEP_SEC
		_wide_scan_timer.start()

func _on_wide_poi_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_wide_scan_in_flight = false
	var spec: Dictionary = _wide_scan_current
	_wide_scan_current = {}

	if int(spec.get("gen", -1)) != _wide_scan_generation:
		return

	var added_count: int = 0
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and body.size() > 2:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_ARRAY:
			var arr: Array = json.data
			var fallback_cat: String = str(spec.get("category", "grocery"))
			var fallback_tag: String = str(spec.get("osm_tag", "shop=supermarket"))
			var fallback_sub: String = str(spec.get("subkind", "supermarket"))
			var before_count: int = _wide_scan_pois.size()

			for item_v in arr:
				if typeof(item_v) != TYPE_DICTIONARY:
					continue
				var item: Dictionary = item_v
				var p_lat: float = float(item.get("lat", 0.0))
				var p_lon: float = float(item.get("lon", 0.0))
				var db: Dictionary = distance_and_bearing(_wide_scan_lat, _wide_scan_lon, p_lat, p_lon)
				var dist_m: float = float(db.get("distance_m", 99999.0))
				if dist_m > 9500.0:
					continue

				var osm_id_val: int = int(item.get("osm_id", int(item.get("place_id", 0))))
				if osm_id_val <= 0:
					osm_id_val = 8000000 + int(absf(p_lat * 10000.0)) + int(absf(p_lon * 10000.0))

				var disp_full: String = str(item.get("display_name", "")).strip_edges()
				var explicit_name: String = str(item.get("name", "")).strip_edges()
				if explicit_name.is_empty() and not disp_full.is_empty():
					var comma_parts: PackedStringArray = disp_full.split(",", false)
					if comma_parts.size() > 0:
						explicit_name = comma_parts[0].strip_edges()

				var addr_guess: String = ""
				if not disp_full.is_empty():
					var addr_parts: PackedStringArray = disp_full.split(",", false)
					if addr_parts.size() >= 3:
						addr_guess = ("%s %s" % [addr_parts[1].strip_edges(), addr_parts[2].strip_edges()]).strip_edges()

				var synth_tags: Dictionary = {
					"name": explicit_name,
					"addr:street": addr_guess
				}
				var poi_info: Dictionary = {
					"category": fallback_cat,
					"osm_tag": fallback_tag,
					"subkind": fallback_sub
				}
				var rec: Dictionary = _make_poi_record(osm_id_val, p_lat, p_lon, synth_tags, poi_info)
				_wide_scan_pois.append(rec)

			_wide_scan_pois = _deduplicate_pois(_wide_scan_pois)
			added_count = maxi(0, _wide_scan_pois.size() - before_count)

	if added_count > 0:
		wide_area_pois_merged.emit(_wide_scan_pois.duplicate(true), added_count)

	if not _wide_scan_queue.is_empty() and is_instance_valid(_wide_scan_timer):
		_wide_scan_timer.wait_time = WIDE_SCAN_STEP_SEC
		_wide_scan_timer.start()
	else:
		status_changed.emit(
			"LIVE OSM READY: %s • %d MULTI-RING POIS MAPPED (0-9KM)" % [_wide_scan_label.to_upper(), _wide_scan_pois.size()],
			false
		)

# --- OpenStreetMap 0.6 JSON Parser ---

static func parse_osm_json(data: Dictionary, ref_lat: float, ref_lon: float) -> Dictionary:
	var elements_v: Variant = data.get("elements", [])
	var elements: Array = elements_v if typeof(elements_v) == TYPE_ARRAY else []

	var node_coords: Dictionary = {}
	var roads: Array = []
	var parks: Array = []
	var buildings: Array = []
	var raw_pois: Array = []

	# Pass 1: Index all nodes and extract point POIs
	for elem_v in elements:
		if typeof(elem_v) != TYPE_DICTIONARY:
			continue
		var elem: Dictionary = elem_v
		if str(elem.get("type", "")) != "node":
			continue
		var nid: int = int(elem.get("id", 0))
		var nlat: float = float(elem.get("lat", 0.0))
		var nlon: float = float(elem.get("lon", 0.0))
		node_coords[nid] = Vector2(nlon, nlat)

		var tags_v: Variant = elem.get("tags", null)
		if typeof(tags_v) == TYPE_DICTIONARY:
			var tags: Dictionary = tags_v
			var poi_info: Dictionary = _classify_poi_tags(tags)
			if not poi_info.is_empty():
				var poi_entry: Dictionary = _make_poi_record(nid, nlat, nlon, tags, poi_info)
				raw_pois.append(poi_entry)

	# Pass 2: Extract roads, parks/landuse, building footprints, and area POIs
	var raw_buildings_without_street: Array = []
	for elem_v in elements:
		if typeof(elem_v) != TYPE_DICTIONARY:
			continue
		var elem: Dictionary = elem_v
		if str(elem.get("type", "")) != "way":
			continue

		var wid: int = int(elem.get("id", 0))
		var tags_v: Variant = elem.get("tags", null)
		var tags: Dictionary = tags_v if typeof(tags_v) == TYPE_DICTIONARY else {}
		if tags.is_empty():
			continue

		var nds_v: Variant = elem.get("nodes", [])
		var nds: Array = nds_v if typeof(nds_v) == TYPE_ARRAY else []
		if nds.size() < 2:
			continue

		var pts_latlon: Array[Vector2] = []
		for nid_v in nds:
			var nid_lookup: int = int(nid_v)
			if node_coords.has(nid_lookup):
				var pt: Vector2 = node_coords[nid_lookup]
				pts_latlon.append(pt)

		if pts_latlon.size() < 2:
			continue

		# Highway / road network
		if tags.has("highway"):
			var hw_kind: String = str(tags.get("highway", "residential"))
			var road_name: String = str(tags.get("name", "")).strip_edges()
			roads.append({
				"osm_id": wid,
				"name": road_name,
				"kind": hw_kind,
				"points_latlon": pts_latlon
			})

		# Polygon vertices (strip duplicate closing vertex for area math)
		var poly_pts: Array[Vector2] = []
		for pt in pts_latlon:
			poly_pts.append(pt)
		if poly_pts.size() >= 4 and poly_pts[0].distance_to(poly_pts[poly_pts.size() - 1]) < 0.0000008:
			poly_pts.remove_at(poly_pts.size() - 1)

		# Parks, gardens, water & green space polygons for vector basemap
		var leisure_val: String = str(tags.get("leisure", ""))
		var landuse_val: String = str(tags.get("landuse", ""))
		var natural_val: String = str(tags.get("natural", ""))
		if poly_pts.size() >= 3 and (
			leisure_val in ["park", "garden", "playground", "pitch", "nature_reserve"]
			or landuse_val in ["grass", "recreation_ground", "village_green", "cemetery", "meadow", "forest"]
			or natural_val in ["water", "wood", "scrub"]
		):
			var area_kind: String = "water" if natural_val == "water" else "park"
			parks.append({
				"osm_id": wid,
				"name": str(tags.get("name", "")).strip_edges(),
				"kind": area_kind,
				"polygon_latlon": poly_pts
			})

		# Check if this way is a scavengeable V2 POI
		if poly_pts.size() >= 3:
			var way_center: Vector2 = _compute_polygon_centroid_lonlat(poly_pts)
			var poi_info_way: Dictionary = _classify_poi_tags(tags)
			if not poi_info_way.is_empty():
				var way_poi: Dictionary = _make_poi_record(wid, way_center.y, way_center.x, tags, poi_info_way)
				raw_pois.append(way_poi)

		# Building ways
		if tags.has("building") and poly_pts.size() >= 3:
			var btype: String = str(tags.get("building", "yes")).strip_edges().to_lower()
			if btype == "no" or btype == "roof" or btype == "carport":
				continue

			var centroid_lonlat: Vector2 = _compute_polygon_centroid_lonlat(poly_pts)
			var c_lon: float = centroid_lonlat.x
			var c_lat: float = centroid_lonlat.y
			var cos_lat: float = cos(deg_to_rad(c_lat))

			var footprint_meters: Array[Vector2] = []
			for v_pt in poly_pts:
				var dx: float = (v_pt.x - c_lon) * 111320.0 * cos_lat
				var dy: float = -(v_pt.y - c_lat) * 110540.0
				footprint_meters.append(Vector2(dx, dy))

			var area_sqm: float = _compute_polygon_area_sqm(footprint_meters)
			if area_sqm < 16.0:
				continue

			var housenumber: String = _clean_housenumber(str(tags.get("addr:housenumber", "")))
			var street: String = str(tags.get("addr:street", "")).strip_edges()
			var city: String = str(tags.get("addr:city", "")).strip_edges()
			var bldg_name: String = str(tags.get("name", "")).strip_edges()

			var has_explicit_street: bool = not street.is_empty()
			var short_addr: String = ""
			if not housenumber.is_empty() and not street.is_empty():
				short_addr = "%s %s" % [housenumber, street]
			elif not street.is_empty():
				short_addr = "%s #%d" % [street, (wid % 899) + 101]
			elif not bldg_name.is_empty():
				short_addr = bldg_name
			else:
				var pretty_type: String = _pretty_building_type(btype)
				short_addr = "House #%d (%s)" % [wid % 1000, pretty_type]

			var full_addr: String = short_addr
			if not city.is_empty() and full_addr.find(city) == -1:
				full_addr += ", " + city

			var disp_name: String = bldg_name if not bldg_name.is_empty() else (short_addr + " Residence")
			var est_rooms: int = clampi(int(round(area_sqm / 28.0)), 4, 8)
			var is_res: bool = _is_residential_building(btype, tags)

			var bldg_dict: Dictionary = {
				"osm_id": wid,
				"name": disp_name,
				"address": full_addr,
				"short_address": short_addr,
				"lat": c_lat,
				"lon": c_lon,
				"building_type": btype,
				"is_residential": is_res,
				"area_sqm": snappedf(area_sqm, 0.1),
				"estimated_rooms": est_rooms,
				"polygon_latlon": poly_pts,
				"footprint_meters": footprint_meters
			}
			buildings.append(bldg_dict)
			if not has_explicit_street and bldg_name.is_empty():
				raw_buildings_without_street.append(bldg_dict)

	# Enrich unaddressed buildings with nearest named OSM street if within 75m!
	if not raw_buildings_without_street.is_empty() and not roads.is_empty():
		_assign_nearest_street_names(raw_buildings_without_street, roads)

	# Deduplicate POIs (e.g. a node inside a building way sharing the same name & category)
	var pois: Array = _deduplicate_pois(raw_pois)

	# Rural / Unmapped location safety net: guarantee 8 realistic houses + village POIs if 0 mapped!
	var synthesized_rural: bool = false
	if buildings.is_empty():
		synthesized_rural = true
		var synth: Dictionary = _synthesize_rural_settlement(ref_lat, ref_lon, roads)
		var sb_v: Variant = synth.get("buildings", [])
		buildings = sb_v if typeof(sb_v) == TYPE_ARRAY else []
		var sr_v: Variant = synth.get("roads", [])
		var synth_roads: Array = sr_v if typeof(sr_v) == TYPE_ARRAY else []
		for r in synth_roads:
			roads.append(r)
		var sp_v: Variant = synth.get("pois", [])
		var synth_pois: Array = sp_v if typeof(sp_v) == TYPE_ARRAY else []
		for sp in synth_pois:
			pois.append(sp)
		pois = _deduplicate_pois(pois)

	return {
		"center_lat": ref_lat,
		"center_lon": ref_lon,
		"buildings": buildings,
		"pois": pois,
		"roads": roads,
		"parks": parks,
		"synthesized_rural": synthesized_rural
	}

# --- Multi-Ring (Ring 1: 0-500m, Ring 2: 500-3500m, Ring 3: 3500m+) Scavenge Target Builder ---

static func build_nearby_targets_for_house(
	selected_bldg: Dictionary,
	all_buildings: Array,
	all_pois: Array,
	area_label: String = ""
) -> Array:
	var h_lat: float = float(selected_bldg.get("lat", 47.6240))
	var h_lon: float = float(selected_bldg.get("lon", -122.3195))
	var selected_id: int = int(selected_bldg.get("osm_id", -1))
	var local_prefix: String = _extract_area_prefix(selected_bldg, area_label)

	# 1. Enrich all candidate real-world POIs with distance, bearing, ring, travel_days & gameplay_impact
	var scored_pois: Array = []
	for p_v in all_pois:
		if typeof(p_v) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_v
		var p_id: int = int(p.get("osm_id", 0))
		if p_id == selected_id:
			continue
		var p_lat: float = float(p.get("lat", 0.0))
		var p_lon: float = float(p.get("lon", 0.0))
		var db: Dictionary = distance_and_bearing(h_lat, h_lon, p_lat, p_lon)
		var dist_m: int = maxi(12, int(round(float(db.get("distance_m", 60.0)))))
		if dist_m > 12000:
			continue
		var cat: String = str(p.get("category", "grocery"))
		var ring_id: int = compute_ring_for_distance(dist_m)
		var travel_d: int = _compute_travel_days(dist_m)

		var item: Dictionary = {
			"osm_id": p_id,
			"name": str(p.get("name", "Local Landmark")),
			"address": str(p.get("address", "")),
			"category": cat,
			"osm_tag": str(p.get("osm_tag", "")),
			"lat": p_lat,
			"lon": p_lon,
			"distance_m": dist_m,
			"ring": ring_id,
			"bearing_dir": str(db.get("bearing_dir", "N")),
			"travel_days": travel_d,
			"risk_bandits": _compute_bandit_risk(cat, dist_m),
			"loot_profile": get_loot_profile_for_category(cat),
			"gameplay_impact": get_gameplay_impact_for_category(cat, ring_id),
			"named": bool(p.get("has_explicit_name", true)),
			"synthesized": false,
			"visited_count": 0,
			"depleted": false
		}
		scored_pois.append(item)

	# 2. Guarantee multi-ring expedition variety for EVERY house on Earth (offline or住宅-only suburbs):
	# If any key distant Ring 2/3 archetype (grocery, doctor, pharmacy, fuel_auto, hardware, civic, church)
	# or school is missing from real POIs (or if Ring 2 / Ring 3 district landmarks are absent), synthesize
	# realistic regional Ring 2 (1.4-3.2 km) & Ring 3 (4.2-7.5 km) landmarks along main compass corridors!
	var regional_fallbacks: Array = _build_missing_regional_landmarks(h_lat, h_lon, local_prefix, scored_pois)
	for rf_v in regional_fallbacks:
		scored_pois.append(rf_v)

	# Sort real explicitly-named POIs ahead of unnamed/synthesized ones, then by distance ascending
	scored_pois.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_real: bool = not bool(a.get("synthesized", false))
		var b_real: bool = not bool(b.get("synthesized", false))
		if a_real != b_real:
			return a_real
		var a_named: bool = bool(a.get("named", true))
		var b_named: bool = bool(b.get("named", true))
		if a_named != b_named:
			return a_named
		return int(a.get("distance_m", 99999)) < int(b.get("distance_m", 99999))
	)

	# 3. Pick up to 20 diverse Ring 1 / Ring 2 / Ring 3 landmarks across all 8 non-house categories
	var max_pois: int = 20
	var chosen_pois: Array = []
	var used_poi_ids: Dictionary = {}
	var category_quotas: Array = [
		{"category": "grocery", "quota": 3},
		{"category": "doctor", "quota": 3},
		{"category": "fuel_auto", "quota": 3},
		{"category": "pharmacy", "quota": 2},
		{"category": "hardware", "quota": 2},
		{"category": "civic", "quota": 2},
		{"category": "church", "quota": 2},
		{"category": "school", "quota": 2}
	]

	for pq_v in category_quotas:
		var pq: Dictionary = pq_v
		var target_cat: String = str(pq.get("category", ""))
		var quota: int = int(pq.get("quota", 2))
		var cat_cands: Array = []
		for cand_v in scored_pois:
			var cand: Dictionary = cand_v
			var cid: int = int(cand.get("osm_id", 0))
			if not used_poi_ids.has(cid) and str(cand.get("category", "")) == target_cat:
				cat_cands.append(cand)

		if cat_cands.is_empty():
			continue

		# Spread selections across rings when available (closest first, then a distant Ring 2/3 option)
		var added: int = 0
		var represented_rings: Dictionary = {}
		for pass_idx in range(2):
			for cc_v in cat_cands:
				if chosen_pois.size() >= max_pois or added >= quota:
					break
				var cc: Dictionary = cc_v
				var cc_id: int = int(cc.get("osm_id", 0))
				if used_poi_ids.has(cc_id):
					continue
				var cc_ring: int = int(cc.get("ring", 1))
				if pass_idx == 0 and represented_rings.has(cc_ring):
					continue
				used_poi_ids[cc_id] = true
				represented_rings[cc_ring] = true
				chosen_pois.append(cc)
				added += 1

	# Fill any remaining non-house landmark slots up to 20
	for cand_v in scored_pois:
		if chosen_pois.size() >= max_pois:
			break
		var cand: Dictionary = cand_v
		var cid: int = int(cand.get("osm_id", 0))
		if not used_poi_ids.has(cid):
			used_poi_ids[cid] = true
			chosen_pois.append(cand)

	# Order chosen landmarks cleanly by Ring (1 -> 2 -> 3), then distance ascending
	chosen_pois.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: int = int(a.get("ring", 1))
		var rb: int = int(b.get("ring", 1))
		if ra != rb:
			return ra < rb
		return int(a.get("distance_m", 99999)) < int(b.get("distance_m", 99999))
	)

	# 4. Find the 6 closest Neighboring Residential Houses (Ring 1, <500m)
	var neighbor_candidates: Array = []
	for b_v in all_buildings:
		if typeof(b_v) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_v
		var bid: int = int(b.get("osm_id", 0))
		if bid == selected_id or used_poi_ids.has(bid):
			continue
		var area_val: float = float(b.get("area_sqm", 0.0))
		if area_val < 32.0:
			continue
		var b_lat: float = float(b.get("lat", 0.0))
		var b_lon: float = float(b.get("lon", 0.0))
		var db_n: Dictionary = distance_and_bearing(h_lat, h_lon, b_lat, b_lon)
		var dist_n: int = maxi(10, int(round(float(db_n.get("distance_m", 30.0)))))
		if dist_n < 8 or dist_n >= 500:
			continue

		var short_addr: String = str(b.get("short_address", str(b.get("address", "Neighbor House"))))
		var btype_str: String = str(b.get("building_type", "house"))
		var n_name: String = short_addr
		if n_name.find("House") == -1 and n_name.find("Residence") == -1 and n_name.find("Apartments") == -1:
			n_name = "%s House" % short_addr

		neighbor_candidates.append({
			"osm_id": bid,
			"name": n_name,
			"address": str(b.get("address", short_addr)),
			"category": "neighbor_house",
			"osm_tag": "building=" + btype_str,
			"lat": b_lat,
			"lon": b_lon,
			"distance_m": dist_n,
			"ring": 1,
			"bearing_dir": str(db_n.get("bearing_dir", "N")),
			"travel_days": 1,
			"risk_bandits": _compute_bandit_risk("neighbor_house", dist_n),
			"loot_profile": get_loot_profile_for_category("neighbor_house"),
			"gameplay_impact": get_gameplay_impact_for_category("neighbor_house", 1),
			"is_res": bool(b.get("is_residential", true)),
			"synthesized": false,
			"visited_count": 0,
			"depleted": false
		})

	neighbor_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_res: bool = bool(a.get("is_res", true))
		var b_res: bool = bool(b.get("is_res", true))
		if a_res != b_res:
			return a_res
		return int(a.get("distance_m", 99999)) < int(b.get("distance_m", 99999))
	)

	var combined: Array = []
	for p_item in chosen_pois:
		combined.append(p_item)
	var neighbor_limit: int = mini(6, neighbor_candidates.size())
	for i in range(neighbor_limit):
		combined.append(neighbor_candidates[i])

	# Automatically sync GameState.neighborhood_modifiers if SceneTree is active
	var mods: Dictionary = compute_neighborhood_modifiers(combined)
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree:
		var gs: Node = (ml as SceneTree).root.get_node_or_null("GameState")
		if gs != null:
			gs.set("neighborhood_modifiers", mods)

	return combined

# --- Neighborhood Gameplay Modifiers Analyzer ---

static func compute_neighborhood_modifiers(nearby_targets: Array) -> Dictionary:
	var ring1_landmarks: int = 0
	var ring2_landmarks: int = 0
	var ring3_landmarks: int = 0
	var neighbor_houses: int = 0

	var counts: Dictionary = {
		"grocery": 0,
		"doctor": 0,
		"pharmacy": 0,
		"fuel_auto": 0,
		"hardware": 0,
		"civic": 0,
		"church": 0,
		"school": 0,
		"neighbor_house": 0
	}
	var nearest_dist: Dictionary = {
		"grocery": 99999,
		"doctor": 99999,
		"pharmacy": 99999,
		"fuel_auto": 99999,
		"hardware": 99999,
		"civic": 99999,
		"church": 99999,
		"school": 99999
	}
	var nearest_name: Dictionary = {}

	for t_v in nearby_targets:
		if typeof(t_v) != TYPE_DICTIONARY:
			continue
		var t: Dictionary = t_v
		var cat: String = str(t.get("category", ""))
		var d_m: int = int(t.get("distance_m", 1000))
		var r_id: int = int(t.get("ring", compute_ring_for_distance(d_m)))

		if counts.has(cat):
			counts[cat] = int(counts[cat]) + 1
		if nearest_dist.has(cat) and d_m < int(nearest_dist[cat]):
			nearest_dist[cat] = d_m
			nearest_name[cat] = str(t.get("name", get_category_label(cat)))

		if cat == "neighbor_house":
			neighbor_houses += 1
		else:
			if r_id == 1:
				ring1_landmarks += 1
			elif r_id == 2:
				ring2_landmarks += 1
			else:
				ring3_landmarks += 1

	var groc_n: int = int(counts["grocery"])
	var doc_n: int = int(counts["doctor"])
	var rx_n: int = int(counts["pharmacy"])
	var fuel_n: int = int(counts["fuel_auto"])
	var hw_n: int = int(counts["hardware"])
	var civ_n: int = int(counts["civic"])
	var chr_n: int = int(counts["church"])
	var sch_n: int = int(counts["school"])

	var min_groc_m: int = int(nearest_dist["grocery"])
	var min_doc_m: int = mini(int(nearest_dist["doctor"]), int(nearest_dist["pharmacy"]))
	var min_fuel_m: int = mini(int(nearest_dist["fuel_auto"]), int(nearest_dist["hardware"]))

	var archetype: String = "Mixed Residential District"
	var early_raider_mod: float = 0.0

	if ring1_landmarks == 0 or (ring1_landmarks <= 1 and (ring2_landmarks + ring3_landmarks) >= 6):
		archetype = "Suburban Cul-de-Sac"
		early_raider_mod = -0.12
	elif (doc_n + rx_n + civ_n) >= 7 and ring1_landmarks >= 2:
		archetype = "Medical & Civic District"
		early_raider_mod = 0.04
	elif ring1_landmarks >= 5 and groc_n >= 2:
		archetype = "Urban Commercial Core"
		early_raider_mod = 0.12
	elif (fuel_n + hw_n) >= 5 and ring2_landmarks >= 3:
		archetype = "Highway Service Corridor"
		early_raider_mod = 0.05
	elif (chr_n + sch_n) >= 4 and ring1_landmarks >= 2:
		archetype = "Historic Parish Commons"
		early_raider_mod = -0.06

	var ration_abundance: float = clampf(
		0.85 + float(groc_n) * 0.09 + (0.18 if min_groc_m < 550 else (-0.08 if min_groc_m > 2500 else 0.04)),
		0.72,
		1.35
	)
	var medical_access: float = clampf(
		0.82 + float(doc_n) * 0.10 + float(rx_n) * 0.07 + (0.16 if int(nearest_dist["doctor"]) < 1200 else -0.05),
		0.72,
		1.40
	)
	var vehicle_escape_rating: float = clampf(
		0.80 + float(fuel_n) * 0.12 + float(hw_n) * 0.08 + (0.14 if min_fuel_m < 2200 else -0.04),
		0.72,
		1.40
	)

	var groc_disp: String = _short_poi_title(str(nearest_name.get("grocery", "Grocery Store")))
	var doc_disp: String = _short_poi_title(str(nearest_name.get("doctor", str(nearest_name.get("pharmacy", "Clinic")))))
	var fuel_disp: String = _short_poi_title(str(nearest_name.get("fuel_auto", str(nearest_name.get("hardware", "Auto Shop")))))

	var bullets: Array[String] = []
	if min_groc_m < 500:
		bullets.append("Walkable Rations: %s (%dm, 1d) gives fast early Soup/Water hauls (+%d%% street looters)." % [groc_disp, min_groc_m, maxi(4, int(round(absf(early_raider_mod) * 100.0)))])
	else:
		bullets.append("Distant Rations: Nearest market %s is %s away (%dd trek) — scavenge Neighbor Houses early & grab a Map!" % [groc_disp, _fmt_dist_short(min_groc_m), _compute_travel_days(min_groc_m)])

	if int(nearest_dist["doctor"]) < 99999:
		var dm: int = int(nearest_dist["doctor"])
		bullets.append("Medical Care: %s (%s, %dd) supplies Antibiotics, Anti-Rad KI & treats explorer injuries on-site." % [doc_disp, _fmt_dist_short(dm), _compute_travel_days(dm)])
	else:
		bullets.append("Medical Care: Nearest Pharmacy (%s) provides Medkits & Anti-Rad pills." % _fmt_dist_short(min_doc_m))

	if int(nearest_dist["fuel_auto"]) < 99999:
		var fm: int = int(nearest_dist["fuel_auto"])
		bullets.append("Vehicle Escape: %s (%s, %dd) & %d Hardware/Auto sites supply Fuel & Engine Parts for the Station Wagon!" % [fuel_disp, _fmt_dist_short(fm), _compute_travel_days(fm), fuel_n + hw_n])

	var headline: String = ""
	if archetype == "Suburban Cul-de-Sac":
		headline = "Quiet cul-de-sac (-12%% early raiders); %s (%s), %s (%s) & %s (%s) require 2-4d Ring 2/3 expeditions — prioritize Map & Station Wagon!" % [
			groc_disp, _fmt_dist_short(min_groc_m),
			doc_disp, _fmt_dist_short(int(nearest_dist["doctor"])),
			fuel_disp, _fmt_dist_short(int(nearest_dist["fuel_auto"]))
		]
	elif archetype == "Urban Commercial Core":
		headline = "%d walkable Ring 1 shops (<0.5km) yield 1d rations & meds (+12%% urban raiders), backed by %s (%s) & %s (%s) for Antibiotics & Fuel!" % [
			ring1_landmarks,
			doc_disp, _fmt_dist_short(int(nearest_dist["doctor"])),
			fuel_disp, _fmt_dist_short(int(nearest_dist["fuel_auto"]))
		]
	else:
		headline = "%d Near (<0.5km) + %d District/Deep (0.5-8km) sites: %s (%s) for rations, %s (%s) for Antibiotics & %s (%s) for Vehicle Fuel!" % [
			ring1_landmarks,
			ring2_landmarks + ring3_landmarks,
			groc_disp, _fmt_dist_short(min_groc_m),
			doc_disp, _fmt_dist_short(min_doc_m),
			fuel_disp, _fmt_dist_short(min_fuel_m)
		]

	return {
		"archetype": archetype,
		"ring1_landmarks": ring1_landmarks,
		"ring2_landmarks": ring2_landmarks,
		"ring3_landmarks": ring3_landmarks,
		"neighbor_houses": neighbor_houses,
		"early_raider_mod": snappedf(early_raider_mod, 0.01),
		"ration_abundance": snappedf(ration_abundance, 0.01),
		"medical_access": snappedf(medical_access, 0.01),
		"vehicle_escape_rating": snappedf(vehicle_escape_rating, 0.01),
		"headline": headline,
		"summary_bullets": bullets
	}

static func pick_best_house(buildings: Array, target_lat: float, target_lon: float, preferred_osm_id: int = -1) -> Dictionary:
	if buildings.is_empty():
		return {}

	if preferred_osm_id > 0:
		for b_v in buildings:
			if typeof(b_v) == TYPE_DICTIONARY:
				var b_pref: Dictionary = b_v
				if int(b_pref.get("osm_id", 0)) == preferred_osm_id:
					return b_pref

	var best_bldg: Dictionary = buildings[0]
	var best_score: float = -1.0e9

	for b_v in buildings:
		if typeof(b_v) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_v
		var b_lat: float = float(b.get("lat", target_lat))
		var b_lon: float = float(b.get("lon", target_lon))
		var db: Dictionary = distance_and_bearing(target_lat, target_lon, b_lat, b_lon)
		var dist_m: float = float(db.get("distance_m", 500.0))
		var area_sqm: float = float(b.get("area_sqm", 100.0))
		var is_res: bool = bool(b.get("is_residential", true))
		var short_addr: String = str(b.get("short_address", ""))
		var poly_v: Variant = b.get("footprint_meters", [])
		var v_count: int = (poly_v as Array).size() if typeof(poly_v) == TYPE_ARRAY else 4

		var score: float = -dist_m * 1.15
		if is_res:
			score += 180.0
		if area_sqm >= 75.0 and area_sqm <= 260.0:
			score += 140.0
		elif area_sqm >= 48.0 and area_sqm <= 420.0:
			score += 65.0
		else:
			score -= 90.0

		if not short_addr.begins_with("House #"):
			score += 85.0
		if v_count >= 5 and v_count <= 14:
			score += 35.0

		if score > best_score:
			best_score = score
			best_bldg = b

	return best_bldg

static func distance_and_bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> Dictionary:
	var mid_lat_rad: float = deg_to_rad((lat1 + lat2) * 0.5)
	var dx_east: float = (lon2 - lon1) * 111320.0 * cos(mid_lat_rad)
	var dy_north: float = (lat2 - lat1) * 110540.0
	var dist_m: float = sqrt(dx_east * dx_east + dy_north * dy_north)
	var angle_deg: float = fposmod(rad_to_deg(atan2(dx_east, dy_north)), 360.0)
	var dir_idx: int = int(round(angle_deg / 45.0)) % 8
	return {
		"distance_m": dist_m,
		"bearing_deg": angle_deg,
		"bearing_dir": str(COMPASS_DIRS[dir_idx])
	}

static func compute_ring_for_distance(distance_m: int) -> int:
	if distance_m < 500:
		return 1
	if distance_m < 3500:
		return 2
	return 3

static func get_category_label(category: String) -> String:
	match category:
		"doctor":
			return "Doctor / Clinic"
		"pharmacy":
			return "Pharmacy"
		"grocery":
			return "Grocery / Market"
		"fuel_auto":
			return "Gas / Auto Shop"
		"hardware":
			return "Hardware Store"
		"civic":
			return "Police / Fire"
		"church":
			return "Church / Sanctuary"
		"school":
			return "School / Library"
		"neighbor_house":
			return "Neighbor House"
		_:
			return "Landmark"

static func get_loot_profile_for_category(category: String) -> Array:
	match category:
		"doctor":
			return ["antibiotics", "medkit", "antirad"]
		"pharmacy":
			return ["antirad", "medkit", "bug_spray"]
		"grocery":
			return ["soup", "water"]
		"fuel_auto":
			return ["fuel", "vehicle_part", "scrap"]
		"hardware":
			return ["scrap", "toolbox", "axe", "rifle", "padlock"]
		"civic":
			return ["rifle", "ammo", "gas_mask", "radio"]
		"church":
			return ["water", "medkit", "book"]
		"school":
			return ["book", "map", "checkers", "flashlight"]
		"neighbor_house":
			return ["soup", "water", "cards", "padlock"]
		_:
			return ["soup", "water"]

static func get_gameplay_impact_for_category(category: String, ring: int = 1) -> String:
	var scale_prefix: String = "Major " if ring >= 3 else ("District " if ring == 2 else "")
	match category:
		"doctor":
			return scale_prefix + "Antibiotics & Medkits; treats explorer -1 Injury/-1 Sickness on-site"
		"pharmacy":
			return scale_prefix + "Anti-Rad KI pills (-35 Rads), Medkits & calming tonics (-1 Stress)"
		"grocery":
			return scale_prefix + "Heavy Soup & Water haul (3-6 cans); high looters, unlocks Traders"
		"fuel_auto":
			return scale_prefix + "Fuel Jerrycans & Engine Parts for Station Wagon Highway Escape"
		"hardware":
			return scale_prefix + "Salvaged Scrap (+12% hull), Tools, Weapons & backup Engine Parts"
		"civic":
			return scale_prefix + "Rifle, Ammo, Gas Mask & +1 U.S. Civil Defense Military Intel"
		"church":
			return "Peaceful sanctuary: Water, Medkit, +1 Sanctuary Rescue & +10 Family Bond"
		"school":
			return "Maps (-1d travel on Ring 2/3 treks!), Books & morale board games"
		"neighbor_house":
			return "Quick 1-day doorstep sweep for light Soup, Water, Cards & Padlock"
		_:
			return "Scavengeable surface landmark"

static func format_building_type(raw_type: String) -> String:
	var key: String = raw_type.strip_edges().to_lower()
	match key:
		"", "yes":
			return "Residence"
		"house":
			return "House"
		"detached":
			return "Detached"
		"semidetached_house", "semidetached":
			return "Duplex"
		"terrace":
			return "Rowhouse"
		"apartments":
			return "Apartments"
		"residential":
			return "Residential"
		"bungalow":
			return "Bungalow"
		"static_caravan":
			return "Mobile Home"
		"dormitory":
			return "Dormitory"
		"cabin":
			return "Cabin"
		"farm", "farmhouse":
			return "Farmhouse"
		_:
			return key.replace("_", " ").capitalize()

# --- Internal Helpers ---

static func _compute_travel_days(distance_m: int) -> int:
	if distance_m < 500:
		return 1
	if distance_m < 1800:
		return 2
	if distance_m < 4200:
		return 3
	return 4

static func _compute_bandit_risk(category: String, distance_m: int) -> float:
	var base_risk: float = 0.24
	match category:
		"church":
			base_risk = 0.12
		"school":
			base_risk = 0.18
		"neighbor_house":
			base_risk = 0.22
		"doctor":
			base_risk = 0.32
		"pharmacy":
			base_risk = 0.34
		"fuel_auto":
			base_risk = 0.36
		"hardware":
			base_risk = 0.38
		"civic":
			base_risk = 0.39
		"grocery":
			base_risk = 0.45
	var dist_bonus: float = clampf(float(distance_m) / 5500.0 * 0.15, 0.0, 0.15)
	return snappedf(clampf(base_risk + dist_bonus, 0.08, 0.62), 0.01)

static func _classify_poi_tags(tags: Dictionary) -> Dictionary:
	var amenity: String = str(tags.get("amenity", "")).strip_edges().to_lower()
	var shop_raw: String = str(tags.get("shop", "")).strip_edges().to_lower()
	var bldg: String = str(tags.get("building", "")).strip_edges().to_lower()
	var healthcare: String = str(tags.get("healthcare", "")).strip_edges().to_lower()
	var emergency_tag: String = str(tags.get("emergency", "")).strip_edges().to_lower()
	var has_highway: bool = tags.has("highway")

	var shop_tokens: PackedStringArray = shop_raw.split(";", false)

	# 1. Church / Place of worship
	if amenity == "place_of_worship" or bldg in CHURCH_BUILDINGS:
		var tag_str: String = "amenity=place_of_worship" if amenity == "place_of_worship" else ("building=" + bldg)
		return {"category": "church", "osm_tag": tag_str, "subkind": bldg if bldg in CHURCH_BUILDINGS else "church"}

	# 2. Pharmacy (checked before generic healthcare so healthcare=pharmacy stays in "pharmacy")
	if amenity == "pharmacy" or healthcare == "pharmacy":
		return {"category": "pharmacy", "osm_tag": "amenity=pharmacy", "subkind": "pharmacy"}
	for tok in shop_tokens:
		var st_rx: String = tok.strip_edges()
		if st_rx in PHARMACY_SHOPS:
			return {"category": "pharmacy", "osm_tag": "shop=" + st_rx, "subkind": st_rx}

	# 3. Doctor / Clinic / Hospital / Urgent Care
	if amenity in DOCTOR_AMENITIES or not healthcare.is_empty() or bldg == "hospital":
		var doc_kind: String = amenity if amenity in DOCTOR_AMENITIES else (healthcare if not healthcare.is_empty() else "hospital")
		var doc_prefix: String = "amenity=" if amenity in DOCTOR_AMENITIES else ("healthcare=" if not healthcare.is_empty() else "building=")
		return {"category": "doctor", "osm_tag": doc_prefix + doc_kind, "subkind": doc_kind}

	# 4. Civic Emergency Stations (Police / Fire / Ranger / Civil Defense / EMS)
	if amenity in CIVIC_AMENITIES or bldg in ["fire_station", "police"]:
		var civ_kind: String = amenity if amenity in CIVIC_AMENITIES else bldg
		var civ_prefix: String = "amenity=" if amenity in CIVIC_AMENITIES else "building="
		return {"category": "civic", "osm_tag": civ_prefix + civ_kind, "subkind": civ_kind}
	if not emergency_tag.is_empty() and not has_highway and not (emergency_tag in IGNORED_EMERGENCY_TAGS):
		return {"category": "civic", "osm_tag": "emergency=" + emergency_tag, "subkind": emergency_tag}

	# Never misclassify post offices or copyshops as hardware/supply stores
	if amenity == "post_office":
		return {}
	for tok in shop_tokens:
		if tok.strip_edges() == "copyshop":
			return {}

	# 5. Gas Stations / Auto Repair / Parts ("fuel_auto")
	if amenity in FUEL_AUTO_AMENITIES:
		return {"category": "fuel_auto", "osm_tag": "amenity=" + amenity, "subkind": amenity}
	for tok in shop_tokens:
		var st_auto: String = tok.strip_edges()
		if st_auto in FUEL_AUTO_SHOPS:
			return {"category": "fuel_auto", "osm_tag": "shop=" + st_auto, "subkind": st_auto}

	# 6. Grocery / Supermarket / Bakery / Market
	for tok in shop_tokens:
		var st_g: String = tok.strip_edges()
		if st_g in GROCERY_SHOPS:
			return {"category": "grocery", "osm_tag": "shop=" + st_g, "subkind": st_g}
	if amenity == "marketplace":
		return {"category": "grocery", "osm_tag": "amenity=marketplace", "subkind": "market"}

	# 7. Hardware Store / Tools / Outdoor Supply
	for tok in shop_tokens:
		var st_h: String = tok.strip_edges()
		if st_h in HARDWARE_SHOPS:
			return {"category": "hardware", "osm_tag": "shop=" + st_h, "subkind": st_h}

	# 8. School / Library / College / Community Center
	if amenity in SCHOOL_AMENITIES or bldg in ["school", "university", "college"]:
		var sch_kind: String = amenity if not amenity.is_empty() else bldg
		return {"category": "school", "osm_tag": "amenity=" + sch_kind, "subkind": sch_kind}
	for tok in shop_tokens:
		var st_s: String = tok.strip_edges()
		if st_s in SCHOOL_SHOPS:
			return {"category": "school", "osm_tag": "shop=" + st_s, "subkind": st_s}

	return {}

static func _make_poi_record(osm_id: int, lat: float, lon: float, tags: Dictionary, poi_info: Dictionary) -> Dictionary:
	var cat: String = str(poi_info.get("category", "grocery"))
	var subkind: String = str(poi_info.get("subkind", ""))
	var raw_name: String = str(tags.get("name", "")).strip_edges()
	var hnum: String = _clean_housenumber(str(tags.get("addr:housenumber", "")))
	var street: String = str(tags.get("addr:street", "")).strip_edges()
	var addr: String = ("%s %s" % [hnum, street]).strip_edges()

	var has_explicit_name: bool = not raw_name.is_empty()
	var display_name: String = raw_name

	if has_explicit_name:
		var lower_name: String = raw_name.to_lower()
		if lower_name == "fuel":
			display_name = ("%s Fuel & Auto" % addr) if not addr.is_empty() else "Local Fuel & Auto Station"
		elif lower_name == "hardware":
			display_name = ("%s Hardware Store" % addr) if not addr.is_empty() else "Neighborhood Hardware Store"
		elif subkind == "supermarket" and raw_name.length() <= 8 and lower_name.find("market") == -1 and lower_name.find("grocery") == -1 and lower_name.find("food") == -1:
			display_name = raw_name + " Supermarket"
		elif subkind == "charging_station" and lower_name.find("station") == -1 and lower_name.find("charging") == -1:
			display_name = raw_name + " Auto & Battery Station"
		elif subkind == "fuel" and raw_name.length() <= 8 and lower_name.find("fuel") == -1 and lower_name.find("gas") == -1 and lower_name.find("station") == -1:
			display_name = raw_name + " Fuel Station"
		elif cat == "doctor" and raw_name.length() <= 12 and lower_name.find("clinic") == -1 and lower_name.find("medical") == -1 and lower_name.find("health") == -1 and lower_name.find("care") == -1 and lower_name.find("dr") == -1:
			display_name = raw_name + " Medical Clinic"
		elif subkind == "pharmacy" and raw_name.length() <= 10 and lower_name.find("pharmacy") == -1 and lower_name.find("drug") == -1:
			display_name = raw_name + " Pharmacy"
	else:
		var suffix: String = _pretty_subkind(cat, subkind)
		if not addr.is_empty():
			display_name = "%s %s" % [addr, suffix]
		else:
			display_name = "Local %s" % suffix

	return {
		"osm_id": osm_id,
		"name": display_name,
		"raw_name": raw_name,
		"has_explicit_name": has_explicit_name,
		"address": addr,
		"category": cat,
		"osm_tag": str(poi_info.get("osm_tag", "")),
		"lat": lat,
		"lon": lon
	}

static func _pretty_subkind(category: String, subkind: String) -> String:
	match subkind:
		"supermarket":
			return "Supermarket"
		"bakery":
			return "Bakery"
		"convenience":
			return "Corner Market"
		"deli":
			return "Delicatessen"
		"butcher":
			return "Butcher Shop"
		"pharmacy", "chemist":
			return "Pharmacy"
		"clinic", "doctors", "doctor":
			return "Medical Clinic"
		"hospital":
			return "Hospital"
		"dentist":
			return "Dental Clinic"
		"veterinary":
			return "Vet Clinic"
		"library":
			return "Public Library"
		"school":
			return "School"
		"books":
			return "Bookshop"
		"fuel":
			return "Fuel Station"
		"car_repair", "car_parts", "tyres":
			return "Auto Repair & Parts"
		"fire_station":
			return "Fire Station"
		"police":
			return "Police Precinct"
		"ranger_station":
			return "Ranger Station"
		"civil_defence":
			return "Civil Defense Station"
		"ambulance_station", "disaster_response":
			return "EMS Station"
		"hardware", "doityourself":
			return "Hardware Store"
	match category:
		"doctor":
			return "Doctor's Office"
		"pharmacy":
			return "Pharmacy"
		"grocery":
			return "Grocery Market"
		"fuel_auto":
			return "Gas & Auto Shop"
		"hardware":
			return "Hardware Store"
		"civic":
			return "Emergency Station"
		"church":
			return "Church"
		"school":
			return "School"
		_:
			return "Landmark"

static func _build_missing_regional_landmarks(
	h_lat: float,
	h_lon: float,
	area_prefix: String,
	existing_scored: Array
) -> Array:
	var has_any_cat: Dictionary = {}
	var has_distant_cat: Dictionary = {}
	var ring2_count: int = 0
	var ring3_count: int = 0

	for p_v in existing_scored:
		var p: Dictionary = p_v
		var c: String = str(p.get("category", ""))
		var r: int = int(p.get("ring", 1))
		has_any_cat[c] = true
		if r >= 2:
			has_distant_cat[c] = true
		if r == 2:
			ring2_count += 1
		elif r >= 3:
			ring3_count += 1

	var cos_lat: float = maxf(0.2, cos(deg_to_rad(h_lat)))
	var m_to_lon: float = 1.0 / (111320.0 * cos_lat)
	var m_to_lat: float = 1.0 / 110540.0
	var seed_hash: int = abs(int(round(h_lat * 1000.0)) * 73856093 ^ int(round(h_lon * 1000.0)) * 19349663)
	var rot_deg: float = float(seed_hash % 360)

	# Blueprints for key Ring 2 (1.4-3.2 km) & Ring 3 (4.2-7.5 km) regional district landmarks
	var blueprints: Array = [
		{"cat": "grocery", "dist_m": 1850, "ang": 22.0, "title": "%s District Supermarket", "tag": "shop=supermarket"},
		{"cat": "doctor", "dist_m": 2150, "ang": 115.0, "title": "%s Family Urgent Care & Clinic", "tag": "amenity=clinic"},
		{"cat": "fuel_auto", "dist_m": 1620, "ang": 208.0, "title": "%s Service Station & Auto Parts", "tag": "amenity=fuel"},
		{"cat": "pharmacy", "dist_m": 2480, "ang": 295.0, "title": "%s Rexall Drug & Pharmacy", "tag": "amenity=pharmacy"},
		{"cat": "church", "dist_m": 2820, "ang": 68.0, "title": "%s Community Parish Church", "tag": "amenity=place_of_worship"},
		{"cat": "school", "dist_m": 1960, "ang": 340.0, "title": "%s High School & Map Library", "tag": "amenity=school"},
		{"cat": "hardware", "dist_m": 4650, "ang": 158.0, "title": "%s Builders Hardware & Supply", "tag": "shop=hardware"},
		{"cat": "civic", "dist_m": 5250, "ang": 252.0, "title": "%s Civil Defense Fire & Police HQ", "tag": "amenity=fire_station"},
		{"cat": "doctor", "dist_m": 6100, "ang": 12.0, "title": "%s Regional General Hospital", "tag": "amenity=hospital"},
		{"cat": "grocery", "dist_m": 6650, "ang": 192.0, "title": "%s Wholesale Food Commissary", "tag": "shop=wholesale"},
		{"cat": "fuel_auto", "dist_m": 5850, "ang": 98.0, "title": "%s Highway Truck Stop & Garage", "tag": "shop=car_repair"}
	]

	var synth_out: Array = []
	for idx in range(blueprints.size()):
		var bp: Dictionary = blueprints[idx]
		var cat: String = str(bp.get("cat", "grocery"))
		var target_dist: int = int(bp.get("dist_m", 2000))
		var target_ring: int = compute_ring_for_distance(target_dist)

		var missing_cat_entirely: bool = not has_any_cat.has(cat)
		var missing_distant_cat: bool = not has_distant_cat.has(cat)
		var need_ring_fill: bool = (target_ring == 2 and ring2_count < 4) or (target_ring == 3 and ring3_count < 3)

		if not missing_cat_entirely and not (missing_distant_cat and need_ring_fill):
			continue

		var jitter_m: int = ((seed_hash + idx * 137) % 260) - 130
		var dist_m: int = clampi(target_dist + jitter_m, 1400, 7500)
		var bearing_rad: float = deg_to_rad(fposmod(rot_deg + float(bp.get("ang", 0.0)), 360.0))
		var p_lat: float = h_lat + cos(bearing_rad) * float(dist_m) * m_to_lat
		var p_lon: float = h_lon + sin(bearing_rad) * float(dist_m) * m_to_lon
		var db: Dictionary = distance_and_bearing(h_lat, h_lon, p_lat, p_lon)
		var final_dist: int = maxi(550, int(round(float(db.get("distance_m", float(dist_m))))))
		var ring_id: int = compute_ring_for_distance(final_dist)
		var travel_d: int = _compute_travel_days(final_dist)
		var osm_id_synth: int = 9700000 + (seed_hash % 90000) + idx * 17
		var full_title: String = str(bp.get("title", "%s Landmark")) % area_prefix

		synth_out.append({
			"osm_id": osm_id_synth,
			"name": full_title,
			"address": "%s Corridor (%s)" % [area_prefix, str(db.get("bearing_dir", "N"))],
			"category": cat,
			"osm_tag": str(bp.get("tag", "")),
			"lat": p_lat,
			"lon": p_lon,
			"distance_m": final_dist,
			"ring": ring_id,
			"bearing_dir": str(db.get("bearing_dir", "N")),
			"travel_days": travel_d,
			"risk_bandits": _compute_bandit_risk(cat, final_dist),
			"loot_profile": get_loot_profile_for_category(cat),
			"gameplay_impact": get_gameplay_impact_for_category(cat, ring_id),
			"named": true,
			"synthesized": true,
			"visited_count": 0,
			"depleted": false
		})

		has_any_cat[cat] = true
		has_distant_cat[cat] = true
		if ring_id == 2:
			ring2_count += 1
		elif ring_id >= 3:
			ring3_count += 1

	return synth_out

static func _extract_area_prefix(selected_bldg: Dictionary, area_label: String) -> String:
	var candidate: String = area_label.strip_edges()
	if candidate.is_empty():
		var addr: String = str(selected_bldg.get("address", "")).strip_edges()
		var parts: PackedStringArray = addr.split(",", false)
		if parts.size() >= 2:
			candidate = parts[1].strip_edges()
		elif parts.size() == 1:
			candidate = parts[0].strip_edges()
	else:
		var lparts: PackedStringArray = candidate.split(",", false)
		if lparts.size() >= 2 and lparts[0].strip_edges().to_lower() in ["historic center", "downtown", "old town", "city center"]:
			candidate = lparts[1].strip_edges()
		elif lparts.size() > 0:
			candidate = lparts[0].strip_edges()

	if candidate.to_lower().begins_with("suburban va"):
		return "Wyndham"

	var paren_idx: int = candidate.find("(")
	if paren_idx > 0:
		candidate = candidate.substr(0, paren_idx).strip_edges()

	# Strip leading house numbers if fallback fell onto a street address
	var words: PackedStringArray = candidate.split(" ", false)
	if words.size() >= 2 and words[0].is_valid_int():
		words.remove_at(0)
		candidate = " ".join(words)

	if candidate.is_empty() or candidate.begins_with("House #"):
		return "County"
	if candidate.length() > 18:
		candidate = candidate.substr(0, 18).strip_edges()
	return candidate

static func _fmt_dist_short(dist_m: int) -> String:
	if dist_m >= 99999:
		return "N/A"
	if dist_m >= 1000:
		return "%.1fkm" % (float(dist_m) / 1000.0)
	return "%dm" % dist_m

static func _short_poi_title(raw: String) -> String:
	var s: String = raw.strip_edges()
	var dash_idx: int = s.find(" - ")
	if dash_idx > 3:
		s = s.substr(0, dash_idx).strip_edges()
	if s.length() <= 22:
		return s
	return s.substr(0, 20).strip_edges() + ".."

static func _deduplicate_pois(raw_pois: Array) -> Array:
	var ordered: Array = raw_pois.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_named: bool = bool(a.get("has_explicit_name", false))
		var b_named: bool = bool(b.get("has_explicit_name", false))
		if a_named != b_named:
			return a_named
		return int(a.get("osm_id", 0)) < int(b.get("osm_id", 0))
	)

	var result: Array = []
	for p_v in ordered:
		var p: Dictionary = p_v
		var p_name: String = str(p.get("name", "")).to_lower()
		var p_named: bool = bool(p.get("has_explicit_name", false))
		var p_cat: String = str(p.get("category", ""))
		var p_lat: float = float(p.get("lat", 0.0))
		var p_lon: float = float(p.get("lon", 0.0))

		var duplicate: bool = false
		for ex_v in result:
			var ex: Dictionary = ex_v
			if str(ex.get("category", "")) != p_cat:
				continue
			var ex_name: String = str(ex.get("name", "")).to_lower()
			var db: Dictionary = distance_and_bearing(p_lat, p_lon, float(ex.get("lat", 0.0)), float(ex.get("lon", 0.0)))
			var dist_m: float = float(db.get("distance_m", 999.0))
			if ex_name == p_name and dist_m < 95.0:
				duplicate = true
				break
			if not p_named and bool(ex.get("has_explicit_name", false)) and dist_m < 55.0:
				duplicate = true
				break
		if not duplicate:
			result.append(p)
	return result

static func _compute_polygon_centroid_lonlat(poly_pts: Array[Vector2]) -> Vector2:
	if poly_pts.is_empty():
		return Vector2.ZERO
	var ref: Vector2 = poly_pts[0]
	var n: int = poly_pts.size()
	var signed_area2: float = 0.0
	var cx_acc: float = 0.0
	var cy_acc: float = 0.0

	for i in range(n):
		var p0: Vector2 = poly_pts[i] - ref
		var p1: Vector2 = poly_pts[(i + 1) % n] - ref
		var cross: float = p0.x * p1.y - p1.x * p0.y
		signed_area2 += cross
		cx_acc += (p0.x + p1.x) * cross
		cy_acc += (p0.y + p1.y) * cross

	if absf(signed_area2) > 1.0e-11:
		var factor: float = 1.0 / (3.0 * signed_area2)
		return ref + Vector2(cx_acc * factor, cy_acc * factor)

	var sum_v := Vector2.ZERO
	for pt in poly_pts:
		sum_v += pt
	return sum_v / float(n)

static func _compute_polygon_area_sqm(footprint_meters: Array[Vector2]) -> float:
	var n: int = footprint_meters.size()
	if n < 3:
		return 0.0
	var accum: float = 0.0
	for i in range(n):
		var a: Vector2 = footprint_meters[i]
		var b: Vector2 = footprint_meters[(i + 1) % n]
		accum += a.x * b.y - b.x * a.y
	return absf(accum) * 0.5

static func _is_residential_building(btype: String, tags: Dictionary) -> bool:
	if tags.has("shop") or tags.has("amenity"):
		var am: String = str(tags.get("amenity", ""))
		if am != "" and am != "parking":
			return false
		if str(tags.get("shop", "")) != "":
			return false
	if btype in ["commercial", "retail", "industrial", "warehouse", "church", "cathedral", "chapel", "school", "hospital", "civic", "office", "supermarket", "garage", "garages", "shed"]:
		return false
	return true

static func _pretty_building_type(btype: String) -> String:
	return format_building_type(btype)

static func _clean_housenumber(raw_num: String) -> String:
	var trimmed: String = raw_num.strip_edges()
	if trimmed.find(";") != -1:
		var parts: PackedStringArray = trimmed.split(";", false)
		if parts.size() > 0:
			return parts[0].strip_edges()
	return trimmed

static func _assign_nearest_street_names(unaddressed_bldgs: Array, roads: Array) -> void:
	var named_roads: Array = []
	for r_v in roads:
		var r: Dictionary = r_v
		var rname: String = str(r.get("name", "")).strip_edges()
		if not rname.is_empty():
			named_roads.append(r)
	if named_roads.is_empty():
		return

	for b_v in unaddressed_bldgs:
		var b: Dictionary = b_v
		var blat: float = float(b.get("lat", 0.0))
		var blon: float = float(b.get("lon", 0.0))
		var cos_lat: float = cos(deg_to_rad(blat))
		var best_dist: float = 78.0
		var best_street: String = ""

		for r_v in named_roads:
			var r: Dictionary = r_v
			var pts_v: Variant = r.get("points_latlon", [])
			var pts: Array = pts_v if typeof(pts_v) == TYPE_ARRAY else []
			for pt_v in pts:
				var pt: Vector2 = pt_v
				var dx: float = (pt.x - blon) * 111320.0 * cos_lat
				var dy: float = (pt.y - blat) * 110540.0
				var d: float = sqrt(dx * dx + dy * dy)
				if d < best_dist:
					best_dist = d
					best_street = str(r.get("name", ""))

		if not best_street.is_empty():
			var wid: int = int(b.get("osm_id", 100))
			var house_no: int = (wid % 880) + 102
			var new_short: String = "%d %s" % [house_no, best_street]
			b["short_address"] = new_short
			b["address"] = new_short
			b["name"] = new_short + " Residence"

static func _synthesize_rural_settlement(ref_lat: float, ref_lon: float, existing_roads: Array) -> Dictionary:
	var cos_lat: float = maxf(0.2, cos(deg_to_rad(ref_lat)))
	var m_to_lon: float = 1.0 / (111320.0 * cos_lat)
	var m_to_lat: float = 1.0 / 110540.0

	var synth_roads: Array = []
	if existing_roads.is_empty():
		var main_road_pts: Array[Vector2] = [
			Vector2(ref_lon - 320.0 * m_to_lon, ref_lat - 35.0 * m_to_lat),
			Vector2(ref_lon, ref_lat),
			Vector2(ref_lon + 320.0 * m_to_lon, ref_lat + 35.0 * m_to_lat)
		]
		var cross_road_pts: Array[Vector2] = [
			Vector2(ref_lon - 25.0 * m_to_lon, ref_lat - 260.0 * m_to_lat),
			Vector2(ref_lon, ref_lat),
			Vector2(ref_lon + 25.0 * m_to_lon, ref_lat + 260.0 * m_to_lat)
		]
		synth_roads.append({"osm_id": 990001, "name": "County Route 60", "kind": "secondary", "points_latlon": main_road_pts})
		synth_roads.append({"osm_id": 990002, "name": "Homestead Lane", "kind": "residential", "points_latlon": cross_road_pts})

	var templates: Array = [
		{"offset": Vector2(-28.0, 26.0), "addr": "104 County Route 60", "fp": [Vector2(-7.4, -5.8), Vector2(7.4, -5.8), Vector2(7.4, 1.6), Vector2(2.8, 1.6), Vector2(2.8, 5.8), Vector2(-7.4, 5.8)]},
		{"offset": Vector2(34.0, 30.0), "addr": "112 County Route 60", "fp": [Vector2(-6.8, -5.4), Vector2(6.8, -5.4), Vector2(6.8, 5.4), Vector2(-6.8, 5.4)]},
		{"offset": Vector2(-76.0, 20.0), "addr": "92 County Route 60", "fp": [Vector2(-8.0, -5.2), Vector2(8.0, -5.2), Vector2(8.0, 5.2), Vector2(-2.0, 5.2), Vector2(-2.0, 2.2), Vector2(-8.0, 2.2)]},
		{"offset": Vector2(86.0, 38.0), "addr": "128 County Route 60", "fp": [Vector2(-6.5, -6.2), Vector2(6.5, -6.2), Vector2(6.5, 6.2), Vector2(-6.5, 6.2)]},
		{"offset": Vector2(-38.0, -32.0), "addr": "105 County Route 60", "fp": [Vector2(-7.0, -5.0), Vector2(7.0, -5.0), Vector2(7.0, 5.0), Vector2(-7.0, 5.0)]},
		{"offset": Vector2(30.0, -26.0), "addr": "115 County Route 60", "fp": [Vector2(-7.6, -5.5), Vector2(4.2, -5.5), Vector2(4.2, -1.5), Vector2(7.6, -1.5), Vector2(7.6, 5.5), Vector2(-7.6, 5.5)]},
		{"offset": Vector2(-18.0, 82.0), "addr": "14 Homestead Lane", "fp": [Vector2(-6.2, -6.8), Vector2(6.2, -6.8), Vector2(6.2, 6.8), Vector2(-6.2, 6.8)]},
		{"offset": Vector2(26.0, -88.0), "addr": "22 Homestead Lane", "fp": [Vector2(-7.2, -5.6), Vector2(7.2, -5.6), Vector2(7.2, 5.6), Vector2(-7.2, 5.6)]}
	]

	var synth_buildings: Array = []
	for idx in range(templates.size()):
		var tpl: Dictionary = templates[idx]
		var off: Vector2 = tpl.get("offset", Vector2.ZERO)
		var c_lon: float = ref_lon + off.x * m_to_lon
		var c_lat: float = ref_lat + off.y * m_to_lat
		var fp_v: Variant = tpl.get("fp", [])
		var fp_raw: Array = fp_v if typeof(fp_v) == TYPE_ARRAY else []
		var fp_meters: Array[Vector2] = []
		var poly_ll: Array[Vector2] = []
		for v_v in fp_raw:
			var v: Vector2 = v_v
			fp_meters.append(v)
			poly_ll.append(Vector2(c_lon + v.x * m_to_lon, c_lat - v.y * m_to_lat))
		var area_val: float = _compute_polygon_area_sqm(fp_meters)
		var addr_str: String = str(tpl.get("addr", "100 Homestead Rd"))
		synth_buildings.append({
			"osm_id": 980100 + idx,
			"name": addr_str + " Farmhouse",
			"address": addr_str,
			"short_address": addr_str,
			"lat": c_lat,
			"lon": c_lon,
			"building_type": "house",
			"is_residential": true,
			"area_sqm": snappedf(area_val, 0.1),
			"estimated_rooms": clampi(int(round(area_val / 28.0)), 4, 8),
			"polygon_latlon": poly_ll,
			"footprint_meters": fp_meters
		})

	var synth_pois: Array = [
		{
			"osm_id": 985001,
			"name": "Crossroads General Store",
			"raw_name": "Crossroads General Store",
			"has_explicit_name": true,
			"address": "140 County Route 60",
			"category": "grocery",
			"osm_tag": "shop=general",
			"lat": ref_lat + 42.0 * m_to_lat,
			"lon": ref_lon + 138.0 * m_to_lon
		},
		{
			"osm_id": 985002,
			"name": "St. Jude Wayside Chapel",
			"raw_name": "St. Jude Wayside Chapel",
			"has_explicit_name": true,
			"address": "48 Homestead Lane",
			"category": "church",
			"osm_tag": "amenity=place_of_worship",
			"lat": ref_lat + 145.0 * m_to_lat,
			"lon": ref_lon - 32.0 * m_to_lon
		},
		{
			"osm_id": 985003,
			"name": "County Doctor's Dispensary",
			"raw_name": "County Doctor's Dispensary",
			"has_explicit_name": true,
			"address": "74 County Route 60",
			"category": "doctor",
			"osm_tag": "amenity=doctors",
			"lat": ref_lat - 28.0 * m_to_lat,
			"lon": ref_lon - 135.0 * m_to_lon
		},
		{
			"osm_id": 985004,
			"name": "Route 60 Fuel & Auto Garage",
			"raw_name": "Route 60 Fuel & Auto Garage",
			"has_explicit_name": true,
			"address": "168 County Route 60",
			"category": "fuel_auto",
			"osm_tag": "amenity=fuel",
			"lat": ref_lat - 54.0 * m_to_lat,
			"lon": ref_lon + 178.0 * m_to_lon
		},
		{
			"osm_id": 985005,
			"name": "Township Reading Room & Schoolhouse",
			"raw_name": "Township Reading Room & Schoolhouse",
			"has_explicit_name": true,
			"address": "60 Homestead Lane",
			"category": "school",
			"osm_tag": "amenity=library",
			"lat": ref_lat - 152.0 * m_to_lat,
			"lon": ref_lon + 22.0 * m_to_lon
		}
	]

	return {
		"buildings": synth_buildings,
		"roads": synth_roads,
		"pois": synth_pois
	}

static func _shorten_display_name(full_name: String) -> String:
	var parts: PackedStringArray = full_name.split(",", false)
	if parts.size() <= 2:
		return full_name.strip_edges()
	var p0: String = parts[0].strip_edges()
	var p1: String = parts[1].strip_edges()
	var p_last: String = parts[parts.size() - 1].strip_edges()
	return "%s, %s, %s" % [p0, p1, p_last]

static func _try_parse_latlon_input(text: String) -> Dictionary:
	var parts: PackedStringArray = text.split(",", false)
	if parts.size() != 2:
		return {"valid": false}
	var s0: String = parts[0].strip_edges()
	var s1: String = parts[1].strip_edges()
	if not s0.is_valid_float() or not s1.is_valid_float():
		return {"valid": false}
	var lat: float = float(s0)
	var lon: float = float(s1)
	if lat < -85.0 or lat > 85.0 or lon < -180.0 or lon > 180.0:
		return {"valid": false}
	return {"valid": true, "lat": lat, "lon": lon}
