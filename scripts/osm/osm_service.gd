class_name OsmService
extends Node

## Real-world OpenStreetMap geocoding, live 0.6 map.json neighborhood fetcher,
## bundled preset loader, building footprint geometry parser, and scavenge POI builder.

signal search_completed(results: Array, query: String)
signal search_failed(error_message: String)
signal map_data_loaded(parsed_data: Dictionary, label: String)
signal map_data_failed(error_message: String)
signal status_changed(status_text: String, is_busy: bool)
signal extended_data_loaded(extended: Dictionary)

const USER_AGENT_HEADER := "User-Agent: SixtySecondsWorldReatomized/1.0"
const ACCEPT_JSON_HEADER := "Accept: application/json"
const NOMINATIM_SEARCH_URL := "https://nominatim.openstreetmap.org/search?q=%s&format=json&limit=5&addressdetails=1"
const OSM_MAP_BBOX_URL := "https://api.openstreetmap.org/api/0.6/map.json?bbox=%.6f,%.6f,%.6f,%.6f"
const OVERPASS_URL := "https://overpass-api.de/api/interpreter"
const EXTENDED_RADIUS_M := 2200

const LAT_HALF_SPAN := 0.0040
const LON_HALF_SPAN := 0.0055

const PRESET_CONFIGS: Dictionary = {
	"seattle": {
		"id": "seattle",
		"button_label": "Seattle: Capitol Hill",
		"neighborhood_label": "Capitol Hill, Seattle, WA",
		"place_names": {"neighborhood": "Capitol Hill", "city": "Seattle", "region": "WA", "country": "USA"},
		"landmarks": [
			{"name": "Colman Dock ferry terminal", "lat": 47.6028956, "lon": -122.3398400, "source": "OSM node 668442224 (amenity=ferry_terminal)"},
			{"name": "King Street Station", "lat": 47.5975188, "lon": -122.3297295, "source": "OSM node 3413447903"}
		],
		"path": "res://data/osm_presets/seattle_capitol_hill.json",
		"lat": 47.6240,
		"lon": -122.3195,
		"preferred_osm_id": 206082403
	},
	"concord": {
		"id": "concord",
		"button_label": "Concord, MA",
		"neighborhood_label": "Historic Center, Concord, MA",
		"place_names": {"neighborhood": "Concord Center", "city": "Concord", "region": "MA", "country": "USA"},
		"landmarks": [
			{"name": "Old North Bridge", "lat": 42.4690, "lon": -71.3510, "source": "Wikipedia: Old North Bridge (42°28′08″N 71°21′04″W)"}
		],
		"path": "res://data/osm_presets/concord_massachusetts.json",
		"lat": 42.4603,
		"lon": -71.3490,
		"preferred_osm_id": 212583739
	},
	"brooklyn": {
		"id": "brooklyn",
		"button_label": "Brooklyn, NY",
		"neighborhood_label": "Carroll Gardens, Brooklyn, NY",
		"place_names": {"neighborhood": "Carroll Gardens", "city": "Brooklyn", "region": "NY", "country": "USA"},
		"landmarks": [
			{"name": "Brooklyn Borough Hall", "lat": 40.69278, "lon": -73.99000, "source": "Wikipedia / NYC DCAS: 209 Joralemon St (40°41′34″N 73°59′24″W)"}
		],
		"path": "res://data/osm_presets/brooklyn_carroll_gardens.json",
		"lat": 40.6802,
		"lon": -73.9930,
		"preferred_osm_id": 248154036
	}
}

const GROCERY_SHOPS: Array = [
	"supermarket", "convenience", "grocery", "greengrocer", "bakery",
	"deli", "butcher", "general", "health_food", "seafood", "farm", "cheese", "pastry"
]
const CHURCH_BUILDINGS: Array = [
	"church", "cathedral", "chapel", "mosque", "synagogue", "temple", "shrine"
]
const PHARMACY_AMENITIES: Array = [
	"pharmacy", "hospital", "clinic", "doctors", "dentist", "veterinary"
]
const PHARMACY_SHOPS: Array = [
	"chemist", "medical_supply"
]
const CIVIC_AMENITIES: Array = [
	"fire_station", "police", "ranger_station", "civil_defence"
]
const CIVIC_EMERGENCIES: Array = [
	"ambulance_station", "disaster_response"
]
const HARDWARE_SHOPS: Array = [
	"hardware", "doityourself", "outdoor", "sports", "electronics",
	"locksmith", "tools", "garden_centre", "trade", "builders_merchant"
]
const HARDWARE_AMENITIES: Array = []
## Vehicle-related places: the only real sources of car batteries, fuel and engine parts.
const AUTO_SHOPS: Array = [
	"car_repair", "car_parts", "car", "tyres", "motorcycle", "motorcycle_repair", "battery"
]
const AUTO_AMENITIES: Array = [
	"fuel", "car_wash"
]
const SCHOOL_AMENITIES: Array = [
	"school", "library", "college", "university", "community_centre",
	"kindergarten", "arts_centre"
]
const SCHOOL_SHOPS: Array = [
	"books", "stationery"
]
const RESTAURANT_AMENITIES: Array = [
	"restaurant", "cafe", "fast_food", "pub", "bar", "ice_cream", "food_court"
]
const PARK_LEISURES: Array = [
	"park", "garden", "playground", "nature_reserve"
]
const COMPASS_DIRS: Array = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var _search_http: HTTPRequest
var _map_http: HTTPRequest
var _active_query: String = ""
var _auto_fetch_after_search: bool = true
var _pending_lat: float = 47.6240
var _pending_lon: float = -122.3195
var _pending_label: String = ""
var _pending_address: Dictionary = {}
var _extended_http: HTTPRequest

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

static func get_preset_list() -> Array:
	return [
		PRESET_CONFIGS["seattle"],
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
	parsed["place_names"] = (cfg.get("place_names", {}) as Dictionary).duplicate()
	parsed["landmarks"] = (cfg.get("landmarks", []) as Array).duplicate(true)
	parsed["source"] = "preset:" + key
	var bnd_v: Variant = root_dict.get("bounds", {})
	if bnd_v is Dictionary:
		parsed["bounds"] = bnd_v
	parsed["preferred_osm_id"] = int(cfg.get("preferred_osm_id", -1))
	return parsed

func cancel_requests() -> void:
	if is_instance_valid(_search_http):
		_search_http.cancel_request()
	if is_instance_valid(_map_http):
		_map_http.cancel_request()

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
		var addr_v: Variant = entry.get("address", {})
		clean_results.append({
			"display_name": disp,
			"short_name": _shorten_display_name(disp),
			"lat": r_lat,
			"lon": r_lon,
			"address": addr_v if addr_v is Dictionary else {}
		})

	if clean_results.is_empty():
		status_changed.emit("No valid coordinates returned for \"%s\"." % _active_query, false)
		search_failed.emit("No valid results.")
		return

	search_completed.emit(clean_results, _active_query)

	if _auto_fetch_after_search:
		var top: Dictionary = clean_results[0]
		_pending_address = top.get("address", {})
		fetch_live_osm_bbox(
			float(top.get("lat", 0.0)),
			float(top.get("lon", 0.0)),
			str(top.get("short_name", _active_query))
		)
	else:
		status_changed.emit("Found %d locations for \"%s\"." % [clean_results.size(), _active_query], false)

func _on_map_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# No data: offer a clearly fictional homestead at these coordinates (no invented businesses).
		var fallback_parsed: Dictionary = parse_osm_json({"elements": []}, _pending_lat, _pending_lon)
		fallback_parsed["label"] = _pending_label
		fallback_parsed["live_fallback"] = true
		fallback_parsed["place_names"] = place_names_from_nominatim(_pending_address)
		fallback_parsed["source"] = "unmapped"
		var warn_msg: String = "OSM API HTTP %d — no map data; a FICTIONAL homestead stands in at %s." % [response_code, _pending_label]
		status_changed.emit(warn_msg, false)
		map_data_loaded.emit(fallback_parsed, _pending_label)
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
	parsed["place_names"] = place_names_from_nominatim(_pending_address)
	parsed["source"] = "live"
	var bnd_v2: Variant = root_dict.get("bounds", {})
	if bnd_v2 is Dictionary:
		parsed["bounds"] = bnd_v2
	var b_count: int = (parsed.get("buildings", []) as Array).size()
	var p_count: int = (parsed.get("pois", []) as Array).size()
	status_changed.emit(
		"LIVE OSM LOADED: %s • %d BUILDINGS • %d POIS" % [_pending_label, b_count, p_count],
		false
	)
	map_data_loaded.emit(parsed, _pending_label)

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
				poi_entry["osm_type"] = "node"
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

		#Polygon vertices (strip duplicate closing vertex for area math)
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
				"polygon_latlon": poly_pts,
				"centroid": _compute_polygon_centroid_lonlat(poly_pts)
			})

		# Check if this way is a scavengeable POI (church, supermarket, pharmacy, library, school, park...)
		if poly_pts.size() >= 3:
			var way_center: Vector2 = _compute_polygon_centroid_lonlat(poly_pts)
			var poi_info_way: Dictionary = _classify_poi_tags(tags)
			if not poi_info_way.is_empty():
				var way_poi: Dictionary = _make_poi_record(wid, way_center.y, way_center.x, tags, poi_info_way)
				way_poi["osm_type"] = "way"
				way_poi["area_sqm"] = _compute_polygon_area_sqm(_latlon_to_local_m(poly_pts))
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
				short_addr = "Building on %s" % street
			elif not bldg_name.is_empty():
				short_addr = bldg_name
			else:
				short_addr = "Unaddressed %s" % _pretty_building_type(btype).to_lower()

			var full_addr: String = short_addr
			if not city.is_empty() and full_addr.find(city) == -1:
				full_addr += ", " + city

			var disp_name: String = bldg_name if not bldg_name.is_empty() else short_addr
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
				"estimated_rooms": clampi(int(round(area_sqm / 18.0)), 3, 14),
				"polygon_latlon": poly_pts,
				"footprint_meters": footprint_meters,
				"housenumber": housenumber,
				"street": street,
				"city": city,
				"postcode": str(tags.get("addr:postcode", "")).strip_edges(),
				"source": "osm",
				"osm_type": "way"
			}
			buildings.append(bldg_dict)
			if not has_explicit_street and bldg_name.is_empty():
				raw_buildings_without_street.append(bldg_dict)

	# Enrich unaddressed buildings with nearest named OSM street if within 75m!
	if not raw_buildings_without_street.is_empty() and not roads.is_empty():
		_assign_nearest_street_names(raw_buildings_without_street, roads)

	# Deduplicate POIs (e.g. a node inside a building way sharing the same name & category)
	var pois: Array = _deduplicate_pois(raw_pois)

	# Unmapped location: never invent businesses or roads. Offer one clearly FICTIONAL homestead
	# so the player can still play at these coordinates; it is labelled fictional everywhere.
	var synthesized_rural: bool = false
	if buildings.is_empty():
		synthesized_rural = true
		buildings = [make_fictional_homestead(ref_lat, ref_lon)]

	return {
		"center_lat": ref_lat,
		"center_lon": ref_lon,
		"buildings": buildings,
		"pois": pois,
		"roads": roads,
		"parks": parks,
		"synthesized_rural": synthesized_rural
	}

static func build_nearby_targets_for_house(selected_bldg: Dictionary, all_buildings: Array, all_pois: Array, roads: Array = []) -> Array:
	var h_lat: float = float(selected_bldg.get("lat", 47.6240))
	var h_lon: float = float(selected_bldg.get("lon", -122.3195))
	var selected_id: int = int(selected_bldg.get("osm_id", -1))

	# Enrich all candidate real-world POIs with exact distance & compass bearing from selected house
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
		var dist_m: int = maxi(8, int(round(float(db.get("distance_m", 50.0)))))
		var cat: String = str(p.get("category", "grocery"))

		var item: Dictionary = {
			"osm_id": p_id,
			"name": str(p.get("name", "Local Landmark")),
			"address": str(p.get("address", "")),
			"category": cat,
			"osm_tag": str(p.get("osm_tag", "")),
			"lat": p_lat,
			"lon": p_lon,
			"distance_m": dist_m,
			"bearing_dir": str(db.get("bearing_dir", "N")),
			"travel_days": _compute_travel_days(dist_m),
			"risk_bandits": _compute_bandit_risk(cat, dist_m),
			"loot_profile": get_loot_profile_for_category(cat),
			"named": bool(p.get("has_explicit_name", true)),
			"has_explicit_name": bool(p.get("has_explicit_name", true)),
			"raw_name": str(p.get("raw_name", "")),
			"kind_label": str(p.get("kind_label", "")),
			"subkind": str(p.get("subkind", "")),
			"street": str(p.get("street", "")),
			"osm_type": str(p.get("osm_type", "node")),
			"tags": p.get("tags", {}),
			"area_sqm": float(p.get("area_sqm", 0.0)),
			"source": str(p.get("source", "osm")),
			"extended": bool(p.get("extended", false)),
			"visited_count": 0,
			"depleted": false
		}
		scored_pois.append(item)

	scored_pois.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_named: bool = bool(a.get("named", true))
		var b_named: bool = bool(b.get("named", true))
		if a_named != b_named:
			return a_named
		return int(a.get("distance_m", 99999)) < int(b.get("distance_m", 99999))
	)

	# Pick up to 14 diverse real-world POIs prioritizing essential survival categories
	var max_pois: int = 14
	var chosen_pois: Array = []
	var used_poi_ids: Dictionary = {}
	var priority_quotas: Array = [
		{"category": "church", "quota": 2},
		{"category": "grocery", "quota": 3},
		{"category": "pharmacy", "quota": 2},
		{"category": "civic", "quota": 2},
		{"category": "hardware", "quota": 2},
		{"category": "auto", "quota": 2},
		{"category": "school", "quota": 2},
		{"category": "restaurant", "quota": 1},
		{"category": "park", "quota": 1}
	]

	for pq_v in priority_quotas:
		var pq: Dictionary = pq_v
		var target_cat: String = str(pq.get("category", ""))
		var quota: int = int(pq.get("quota", 1))
		var added: int = 0
		for cand_v in scored_pois:
			if chosen_pois.size() >= max_pois or added >= quota:
				break
			var cand: Dictionary = cand_v
			var cid: int = int(cand.get("osm_id", 0))
			if used_poi_ids.has(cid):
				continue
			if str(cand.get("category", "")) == target_cat:
				used_poi_ids[cid] = true
				chosen_pois.append(cand)
				added += 1

	# Fill remaining POI slots up to max_pois sorted purely by closeness
	scored_pois.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("distance_m", 99999)) < int(b.get("distance_m", 99999))
	)
	for cand_v in scored_pois:
		if chosen_pois.size() >= max_pois:
			break
		var cand: Dictionary = cand_v
		var cid: int = int(cand.get("osm_id", 0))
		if not used_poi_ids.has(cid):
			used_poi_ids[cid] = true
			chosen_pois.append(cand)

	# Find the 8 closest Neighboring Residential Houses (excluding selected_bldg & POI buildings)
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
		if dist_n < 8:
			continue

		var btype_str: String = str(b.get("building_type", "house"))
		var hn: String = str(b.get("housenumber", ""))
		var stn: String = str(b.get("street", ""))
		var n_name: String
		if not hn.is_empty() and not stn.is_empty():
			n_name = "Neighbors at %s %s" % [hn, stn]
		elif not stn.is_empty():
			n_name = "Neighbor's house on %s" % stn
		else:
			n_name = "Neighbor's house %d m %s" % [dist_n, str(db_n.get("bearing_dir", "N"))]
		var short_addr: String = str(b.get("short_address", n_name))

		neighbor_candidates.append({
			"osm_id": bid,
			"name": n_name,
			"address": str(b.get("address", short_addr)),
			"category": "neighbor_house",
			"osm_tag": "building=" + btype_str,
			"lat": b_lat,
			"lon": b_lon,
			"distance_m": dist_n,
			"bearing_dir": str(db_n.get("bearing_dir", "N")),
			"travel_days": _compute_travel_days(dist_n),
			"risk_bandits": _compute_bandit_risk("neighbor_house", dist_n),
			"loot_profile": get_loot_profile_for_category("neighbor_house"),
			"is_res": bool(b.get("is_residential", true)),
			"named": false,
			"has_explicit_name": false,
			"kind_label": "Neighbor's house",
			"street": stn,
			"osm_type": "way",
			"area_sqm": area_val,
			"source": "osm",
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

	chosen_pois.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_cat: String = str(a.get("category", ""))
		var b_cat: String = str(b.get("category", ""))
		var a_pri: int = 0 if (a_cat in ["church", "grocery", "pharmacy", "civic"] and bool(a.get("named", true))) else 1
		var b_pri: int = 0 if (b_cat in ["church", "grocery", "pharmacy", "civic"] and bool(b.get("named", true))) else 1
		if a_pri != b_pri:
			return a_pri < b_pri
		return int(a.get("distance_m", 99999)) < int(b.get("distance_m", 99999))
	)

	var combined: Array = []
	for p_item in chosen_pois:
		combined.append(p_item)
	var neighbor_limit: int = mini(8, neighbor_candidates.size())
	for i in range(neighbor_limit):
		combined.append(neighbor_candidates[i])

	# Real walking distances over the mapped street/footpath network.
	WalkNetwork.annotate_targets(combined, roads, selected_bldg)
	for t_v in combined:
		var t: Dictionary = t_v
		t["travel_days"] = _compute_travel_days(int(t.get("walk_m", t.get("distance_m", 100))))
		t["risk_bandits"] = _compute_bandit_risk(str(t.get("category", "")), int(t.get("walk_m", t.get("distance_m", 100))))
	return combined

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

		if not short_addr.begins_with("Unaddressed") and not bool(b.get("fictional", false)):
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

static func get_category_label(category: String) -> String:
	match category:
		"grocery":
			return "Grocery / Market"
		"church":
			return "Church / Sanctuary"
		"pharmacy":
			return "Pharmacy / Clinic"
		"civic":
			return "Police / Fire"
		"hardware":
			return "Hardware / Supply"
		"auto":
			return "Fuel / Auto"
		"school":
			return "School / Library"
		"restaurant":
			return "Diner / Cafe"
		"park":
			return "Park / Grounds"
		"neighbor_house":
			return "Neighbor House"
		_:
			return "Landmark"

static func get_loot_profile_for_category(category: String) -> Array:
	match category:
		"grocery":
			return ["soup", "water"]
		"church":
			return ["water", "medkit", "book"]
		"pharmacy":
			return ["medkit", "gas_mask", "water"]
		"civic":
			return ["rifle", "ammo", "gas_mask", "radio"]
		"hardware":
			return ["toolbox", "axe", "padlock", "flashlight", "spark_plugs"]
		"auto":
			return ["car_battery", "fuel_can", "spark_plugs", "toolbox"]
		"school":
			return ["book", "map", "flashlight", "checkers"]
		"restaurant":
			return ["soup", "water", "cards"]
		"park":
			return ["water", "flashlight", "harmonica"]
		"neighbor_house":
			return ["soup", "water", "cards", "padlock", "bug_spray"]
		_:
			return ["soup", "water"]

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
	if distance_m < 220:
		return 1
	if distance_m < 500:
		return 2
	return 3

static func _compute_bandit_risk(category: String, distance_m: int) -> float:
	var base_risk: float = 0.22
	match category:
		"church":
			base_risk = 0.12
		"park":
			base_risk = 0.14
		"school":
			base_risk = 0.18
		"neighbor_house":
			base_risk = 0.22
		"restaurant":
			base_risk = 0.26
		"grocery":
			base_risk = 0.30
		"pharmacy":
			base_risk = 0.34
		"civic":
			base_risk = 0.36
		"hardware":
			base_risk = 0.38
		"auto":
			base_risk = 0.4
	var dist_bonus: float = clampf(float(distance_m) / 2200.0, 0.0, 0.16)
	return snappedf(clampf(base_risk + dist_bonus, 0.08, 0.65), 0.01)

static func _classify_poi_tags(tags: Dictionary) -> Dictionary:
	var amenity: String = str(tags.get("amenity", "")).strip_edges().to_lower()
	var shop_raw: String = str(tags.get("shop", "")).strip_edges().to_lower()
	var bldg: String = str(tags.get("building", "")).strip_edges().to_lower()
	var leisure: String = str(tags.get("leisure", "")).strip_edges().to_lower()
	var healthcare: String = str(tags.get("healthcare", "")).strip_edges().to_lower()
	var emergency_tag: String = str(tags.get("emergency", "")).strip_edges().to_lower()

	var shop_tokens: PackedStringArray = shop_raw.split(";", false)

	# 1. Church / Place of worship
	if amenity == "place_of_worship" or bldg in CHURCH_BUILDINGS:
		var tag_str: String = "amenity=place_of_worship" if amenity == "place_of_worship" else ("building=" + bldg)
		return {"category": "church", "osm_tag": tag_str, "subkind": bldg if bldg in CHURCH_BUILDINGS else "church"}

	# 2. Pharmacy / Clinic / Medical
	if amenity in PHARMACY_AMENITIES or not healthcare.is_empty():
		if amenity in PHARMACY_AMENITIES:
			return {"category": "pharmacy", "osm_tag": "amenity=" + amenity, "subkind": amenity}
		return {"category": "pharmacy", "osm_tag": "healthcare=" + healthcare, "subkind": healthcare}
	for tok in shop_tokens:
		var st: String = tok.strip_edges()
		if st in PHARMACY_SHOPS:
			return {"category": "pharmacy", "osm_tag": "shop=" + st, "subkind": st}

	# 3. Civic Emergency Stations (Police / Fire / Ranger / Civil Defense / EMS)
	if amenity in CIVIC_AMENITIES or bldg in ["fire_station", "police"] or emergency_tag in CIVIC_EMERGENCIES:
		var civ_kind: String = amenity if amenity in CIVIC_AMENITIES else (bldg if bldg in ["fire_station", "police"] else emergency_tag)
		var civ_prefix: String = "amenity=" if amenity in CIVIC_AMENITIES else ("building=" if bldg in ["fire_station", "police"] else "emergency=")
		return {"category": "civic", "osm_tag": civ_prefix + civ_kind, "subkind": civ_kind}

	# Never misclassify post offices or copyshops as hardware/supply stores
	if amenity == "post_office":
		return {}
	for tok in shop_tokens:
		if tok.strip_edges() == "copyshop":
			return {}

	# 4. Grocery / Supermarket / Bakery / Market
	for tok in shop_tokens:
		var st_g: String = tok.strip_edges()
		if st_g in GROCERY_SHOPS:
			return {"category": "grocery", "osm_tag": "shop=" + st_g, "subkind": st_g}
	if amenity == "marketplace":
		return {"category": "grocery", "osm_tag": "amenity=marketplace", "subkind": "market"}

	# 5a. Vehicle services: fuel stations, garages, parts dealers
	for tok in shop_tokens:
		var st_a: String = tok.strip_edges()
		if st_a in AUTO_SHOPS:
			return {"category": "auto", "osm_tag": "shop=" + st_a, "subkind": st_a}
	if amenity in AUTO_AMENITIES:
		return {"category": "auto", "osm_tag": "amenity=" + amenity, "subkind": amenity}

	# 5b. Hardware / Supply
	for tok in shop_tokens:
		var st_h: String = tok.strip_edges()
		if st_h in HARDWARE_SHOPS:
			return {"category": "hardware", "osm_tag": "shop=" + st_h, "subkind": st_h}
	if amenity in HARDWARE_AMENITIES:
		return {"category": "hardware", "osm_tag": "amenity=" + amenity, "subkind": amenity}

	# 6. School / Library / Books
	if amenity in SCHOOL_AMENITIES or bldg in ["school", "university", "college"]:
		var sch_kind: String = amenity if not amenity.is_empty() else bldg
		return {"category": "school", "osm_tag": "amenity=" + sch_kind, "subkind": sch_kind}
	for tok in shop_tokens:
		var st_s: String = tok.strip_edges()
		if st_s in SCHOOL_SHOPS:
			return {"category": "school", "osm_tag": "shop=" + st_s, "subkind": st_s}

	# 7. Restaurant / Cafe / Diner
	if amenity in RESTAURANT_AMENITIES:
		return {"category": "restaurant", "osm_tag": "amenity=" + amenity, "subkind": amenity}

	# 8. Park / Garden (require a name so tiny backyard patches don't clutter POIs)
	if leisure in PARK_LEISURES and not str(tags.get("name", "")).strip_edges().is_empty():
		return {"category": "park", "osm_tag": "leisure=" + leisure, "subkind": leisure}

	return {}

static func _make_poi_record(osm_id: int, lat: float, lon: float, tags: Dictionary, poi_info: Dictionary) -> Dictionary:
	var cat: String = str(poi_info.get("category", "grocery"))
	var subkind: String = str(poi_info.get("subkind", ""))
	var raw_name: String = str(tags.get("name", "")).strip_edges()
	var hnum: String = _clean_housenumber(str(tags.get("addr:housenumber", "")))
	var street: String = str(tags.get("addr:street", "")).strip_edges()
	var addr: String = ("%s %s" % [hnum, street]).strip_edges()

	var has_explicit_name: bool = not raw_name.is_empty()
	var kind_label: String = _pretty_subkind(cat, subkind)
	# Names are exactly the OSM `name` tag. Unnamed features are described, never named.
	var display_name: String = raw_name
	if not has_explicit_name:
		if not street.is_empty():
			display_name = "Unnamed %s on %s" % [kind_label.to_lower(), street]
		else:
			display_name = "Unnamed %s" % kind_label.to_lower()

	var kept_tags: Dictionary = {}
	for tk in ["name", "shop", "amenity", "building", "healthcare", "emergency", "leisure", "brand", "addr:street", "addr:housenumber", "opening_hours"]:
		if tags.has(tk):
			kept_tags[tk] = str(tags[tk])
	return {
		"osm_id": osm_id,
		"name": display_name,
		"raw_name": raw_name,
		"kind_label": kind_label,
		"has_explicit_name": has_explicit_name,
		"address": addr,
		"street": street,
		"category": cat,
		"subkind": subkind,
		"osm_tag": str(poi_info.get("osm_tag", "")),
		"tags": kept_tags,
		"source": "osm",
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
		"clinic", "doctors":
			return "Medical Clinic"
		"hospital":
			return "Hospital"
		"dentist":
			return "Dental Clinic"
		"library":
			return "Public Library"
		"school":
			return "School"
		"books":
			return "Bookshop"
		"fuel":
			return "Fuel Station"
		"fire_station":
			return "Fire Station"
		"police":
			return "Police Precinct"
		"ranger_station":
			return "Ranger Station"
		"civil_defence":
			return "Civil Defense Station"
		"ambulance_station", "disaster_response":
			return "Emergency Station"
		"hardware", "doityourself":
			return "Hardware Store"
		"car_repair":
			return "Auto Repair Shop"
		"car_parts":
			return "Auto Parts Store"
		"car":
			return "Car Dealer"
		"tyres":
			return "Tire Shop"
		"car_wash":
			return "Car Wash"
		"convenience":
			return "Corner Store"
		"place_of_worship":
			return "Place of Worship"
		"restaurant":
			return "Restaurant"
		"cafe":
			return "Cafe"
		"bar", "pub":
			return "Bar"
		"fast_food":
			return "Fast Food"
	match category:
		"church":
			return "Church"
		"grocery":
			return "Grocery"
		"pharmacy":
			return "Clinic"
		"civic":
			return "Emergency Station"
		"hardware":
			return "Hardware Store"
		"auto":
			return "Auto Service"
		"school":
			return "School"
		"restaurant":
			return "Diner"
		"park":
			return "Park"
		_:
			return "Landmark"

static func _deduplicate_pois(raw_pois: Array) -> Array:
	# Process explicitly named POIs first so co-located unnamed building ways merge cleanly into them
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
			if ex_name == p_name and dist_m < 75.0:
				duplicate = true
				break
			if not p_named and bool(ex.get("has_explicit_name", false)) and dist_m < 50.0:
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
			# OSM has no house number for this building: say where it is, never invent a number.
			var new_short: String = "Building on %s" % best_street
			b["short_address"] = new_short
			b["address"] = new_short
			b["name"] = new_short
			b["street"] = best_street
			b["street_inferred"] = true

## A single clearly-fictional homestead for coordinates with no mapped buildings.
static func make_fictional_homestead(ref_lat: float, ref_lon: float) -> Dictionary:
	var cos_lat: float = maxf(0.2, cos(deg_to_rad(ref_lat)))
	var fp: Array[Vector2] = [Vector2(-6.5, -5.0), Vector2(6.5, -5.0), Vector2(6.5, 1.5), Vector2(2.5, 1.5), Vector2(2.5, 5.0), Vector2(-6.5, 5.0)]
	var ll: Array[Vector2] = []
	for v in fp:
		ll.append(Vector2(ref_lon + v.x / (111320.0 * cos_lat), ref_lat - v.y / 110540.0))
	return {
		"osm_id": -1,
		"name": "Fictional homestead (nothing mapped here)",
		"address": "Unmapped location %.4f, %.4f" % [ref_lat, ref_lon],
		"short_address": "Fictional homestead",
		"lat": ref_lat,
		"lon": ref_lon,
		"building_type": "house",
		"is_residential": true,
		"area_sqm": _compute_polygon_area_sqm(fp),
		"estimated_rooms": 4,
		"polygon_latlon": ll,
		"footprint_meters": fp,
		"housenumber": "",
		"street": "",
		"city": "",
		"fictional": true,
		"source": "fictional"
	}


static func place_names_from_nominatim(addr: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	out["street"] = str(addr.get("road", addr.get("pedestrian", ""))).strip_edges()
	out["housenumber"] = str(addr.get("house_number", "")).strip_edges()
	out["neighborhood"] = str(addr.get("neighbourhood", addr.get("suburb", addr.get("quarter", addr.get("hamlet", ""))))).strip_edges()
	out["city"] = str(addr.get("city", addr.get("town", addr.get("village", addr.get("municipality", ""))))).strip_edges()
	out["region"] = str(addr.get("state", "")).strip_edges()
	out["postcode"] = str(addr.get("postcode", "")).strip_edges()
	out["country"] = str(addr.get("country", "")).strip_edges()
	return out


static func _latlon_to_local_m(poly_pts: Array[Vector2]) -> Array[Vector2]:
	var c: Vector2 = _compute_polygon_centroid_lonlat(poly_pts)
	var cos_lat: float = cos(deg_to_rad(c.y))
	var out: Array[Vector2] = []
	for p in poly_pts:
		out.append(Vector2((p.x - c.x) * 111320.0 * cos_lat, -(p.y - c.y) * 110540.0))
	return out


# ---------------------------------------------------------------------------
# Extended area (live searches only): named survival-relevant places within ~2 km via Overpass.
# ---------------------------------------------------------------------------

static func build_overpass_query(lat: float, lon: float, radius_m: int) -> String:
	var a: String = "(around:%d,%.6f,%.6f)" % [radius_m, lat, lon]
	var q: String = "[out:json][timeout:25];("
	q += "nwr%s[shop~\"^(supermarket|convenience|grocery|general|greengrocer|bakery|butcher|hardware|doityourself|trade|car_repair|car_parts|tyres|chemist|medical_supply|outdoor)$\"];" % a
	q += "nwr%s[amenity~\"^(pharmacy|hospital|clinic|doctors|fire_station|police|fuel|place_of_worship|school|library|community_centre|townhall)$\"];" % a
	q += "way%s[highway~\"^(motorway|trunk|primary|secondary|tertiary)$\"];" % a
	q += ");out geom tags qt;"
	return q


func fetch_extended_area(lat: float, lon: float) -> void:
	if _extended_http == null:
		_extended_http = HTTPRequest.new()
		_extended_http.timeout = 30.0
		add_child(_extended_http)
		_extended_http.request_completed.connect(_on_extended_completed)
	_extended_http.cancel_request()
	var body: String = "data=" + build_overpass_query(lat, lon, EXTENDED_RADIUS_M).uri_encode()
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	if not OS.has_feature("web"):
		headers.append(USER_AGENT_HEADER)
	_extended_http.request(OVERPASS_URL, headers, HTTPClient.METHOD_POST, body)


func _on_extended_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_changed.emit("Extended area (2 km) unavailable (HTTP %d) — nearby view only." % response_code, false)
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return
	var ext: Dictionary = parse_overpass_extended(json.data as Dictionary)
	status_changed.emit("EXTENDED AREA: %d named places, %d main roads within 2.2 km" % [(ext["pois"] as Array).size(), (ext["roads"] as Array).size()], false)
	extended_data_loaded.emit(ext)


## Parses an Overpass `out geom tags` response into the same POI/road records as parse_osm_json.
static func parse_overpass_extended(data: Dictionary) -> Dictionary:
	var pois: Array = []
	var roads: Array = []
	for e_v in data.get("elements", []):
		if not (e_v is Dictionary):
			continue
		var e: Dictionary = e_v
		var tags: Dictionary = e.get("tags", {}) if e.get("tags", {}) is Dictionary else {}
		var etype: String = str(e.get("type", ""))
		var geom: Array = e.get("geometry", []) if e.get("geometry", []) is Array else []
		var pts: Array[Vector2] = []
		for g_v in geom:
			if g_v is Dictionary:
				pts.append(Vector2(float((g_v as Dictionary).get("lon", 0.0)), float((g_v as Dictionary).get("lat", 0.0))))
		if tags.has("highway") and etype == "way" and pts.size() >= 2:
			roads.append({"osm_id": int(e.get("id", 0)), "name": str(tags.get("name", "")).strip_edges(), "kind": str(tags.get("highway", "")), "points_latlon": pts, "extended": true})
			continue
		var info: Dictionary = _classify_poi_tags(tags)
		if info.is_empty():
			continue
		var lat: float = float(e.get("lat", 0.0))
		var lon: float = float(e.get("lon", 0.0))
		if etype != "node" and pts.size() >= 3:
			var c: Vector2 = _compute_polygon_centroid_lonlat(pts)
			lat = c.y
			lon = c.x
		if lat == 0.0 and lon == 0.0:
			continue
		var rec: Dictionary = _make_poi_record(int(e.get("id", 0)), lat, lon, tags, info)
		rec["osm_type"] = etype
		rec["extended"] = true
		pois.append(rec)
	return {"pois": _deduplicate_pois(pois), "roads": roads}


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
