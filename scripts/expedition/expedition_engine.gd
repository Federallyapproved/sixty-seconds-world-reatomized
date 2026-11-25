class_name ExpeditionEngine
extends RefCounted

## The expedition target list for the screens that show real places (the shelter map, the risk
## preview). The rules for trips themselves live in ShelterTrips (section 6); this class keeps
## the OSM-facing helpers: category normalisation, honest names, distances, and the clearly
## labelled fictional places used only when nothing at all is mapped.

const CARRYABLE_GEAR_IDS: Array[String] = ["gas_mask", "map", "rifle", "axe", "flashlight", "medkit", "suitcase"]


static func get_expedition_gear_ids() -> Array[String]:
	return CARRYABLE_GEAR_IDS.duplicate()


## GameState.nearby_pois with display fields filled in (creates honest fictional places only when
## the house has no mapped neighbourhood at all).
static func get_available_targets() -> Array:
	if GameState.nearby_pois.is_empty():
		GameState.nearby_pois = _fictional_targets(GameState.selected_house)
	var house_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var house_lon: float = float(GameState.selected_house.get("lon", 0.0))
	var out: Array = []
	for i in range(GameState.nearby_pois.size()):
		var raw: Variant = GameState.nearby_pois[i]
		if not (raw is Dictionary):
			continue
		var poi: Dictionary = raw
		var cat: String = _normalize_category(poi)
		var dist_m: float = float(poi.get("walk_m", _extract_distance_m(poi, house_lat, house_lon, i)))
		var bearing: String = _extract_bearing(poi, house_lat, house_lon, i)
		var base_name: String = _extract_base_name(poi, cat, i)
		poi["index"] = i
		poi["category"] = cat
		poi["name"] = base_name
		poi["display_name"] = _format_target_display(base_name, dist_m, bearing)
		poi["distance_m"] = roundf(dist_m)
		poi["bearing"] = bearing
		poi["bearing_dir"] = bearing
		var rt_km: float = 2.0 * dist_m / 1000.0
		poi["travel_days"] = clampi(1 + int(ceil(rt_km / 6.0)), 2, 7)
		poi["expected_days"] = poi["travel_days"]
		poi["effective_days_with_map"] = maxi(1, int(poi["travel_days"]) - 1)
		poi["expected_loot"] = LootTables.preview_for_category(cat)
		poi["loot_icons"] = (poi["expected_loot"] as Array).duplicate()
		poi["loot_status"] = LootInventory.status_label(poi)
		poi["sanctuary_site"] = cat == "church" or cat == "school"
		GameState.nearby_pois[i] = poi
		out.append(poi)
	return out


static func _expected_loot_for_category(cat: String) -> Array:
	return LootTables.preview_for_category(cat)


## Trip length by the section 6 rule (see ShelterTrips.base_days); a map takes a day off.
static func compute_trip_days(_member: Dictionary, poi: Dictionary, gear_ids: Array) -> int:
	var rt_km: float = 2.0 * float(poi.get("walk_m", poi.get("distance_m", 300.0))) / 1000.0
	var days: int = clampi(1 + int(ceil(rt_km / 6.0)), 2, 7)
	return maxi(1, days - (1 if gear_ids.has("map") else 0))


static func _normalize_category(poi: Dictionary) -> String:
	var raw_cat: String = str(poi.get("category", poi.get("type", poi.get("poi_type", poi.get("amenity", poi.get("shop", poi.get("building_type", ""))))))).to_lower()
	if raw_cat in ["auto", "fuel", "car_repair", "car_parts", "tyres"]:
		return "auto"
	if raw_cat in ["grocery", "supermarket", "convenience", "bakery", "greengrocer", "deli", "market", "marketplace"]:
		return "grocery"
	if raw_cat in ["restaurant", "cafe", "fast_food", "bar", "diner"]:
		return "restaurant"
	if raw_cat in ["church", "place_of_worship", "chapel", "cathedral", "synagogue", "mosque", "temple"]:
		return "church"
	if raw_cat in ["pharmacy", "chemist", "clinic", "hospital", "doctors", "medical", "dentist"]:
		return "pharmacy"
	if raw_cat in ["hardware", "doityourself", "trade", "industrial", "storage", "garage"]:
		return "hardware"
	if raw_cat in ["school", "library", "college", "university", "kindergarten", "community_centre"]:
		return "school"
	if raw_cat in ["civic", "fire_station", "police", "townhall", "post_office", "government"]:
		return "civic"
	if raw_cat in ["park", "playground", "garden", "recreation_ground"]:
		return "park"
	if raw_cat in ["house", "neighbor_house", "neighbor", "neighbour", "residential", "detached", "apartments", "terrace", "semidetached_house"]:
		return "house"

	# Fallback keyword inference from POI name
	var nm: String = str(poi.get("name", poi.get("label", ""))).to_lower()
	if nm.find("market") != -1 or nm.find("grocery") != -1 or nm.find("qfc") != -1 or nm.find("supermarket") != -1 or nm.find("food") != -1:
		return "grocery"
	if nm.find("church") != -1 or nm.find("parish") != -1 or nm.find("chapel") != -1 or nm.find("st.") != -1 or nm.find("pilgrim") != -1:
		return "church"
	if nm.find("pharm") != -1 or nm.find("walgreens") != -1 or nm.find("cvs") != -1 or nm.find("clinic") != -1 or nm.find("drug") != -1:
		return "pharmacy"
	if nm.find("hardware") != -1 or nm.find("supply") != -1 or nm.find("lumber") != -1 or nm.find("tool") != -1:
		return "hardware"
	if nm.find("school") != -1 or nm.find("library") != -1 or nm.find("elementary") != -1 or nm.find("academy") != -1:
		return "school"
	if nm.find("fire") != -1 or nm.find("station") != -1 or nm.find("precinct") != -1:
		return "civic"
	return "house"


static func _extract_distance_m(poi: Dictionary, house_lat: float, house_lon: float, idx: int) -> float:
	if poi.has("distance_m") and float(poi.get("distance_m", 0.0)) > 1.0:
		return float(poi.get("distance_m", 150.0))
	if poi.has("dist_m") and float(poi.get("dist_m", 0.0)) > 1.0:
		return float(poi.get("dist_m", 150.0))
	if poi.has("distance") and float(poi.get("distance", 0.0)) > 1.0:
		return float(poi.get("distance", 150.0))
	if poi.has("lat") and poi.has("lon"):
		var p_lat: float = float(poi.get("lat", house_lat))
		var p_lon: float = float(poi.get("lon", house_lon))
		var d_lat_m: float = (p_lat - house_lat) * 111320.0
		var d_lon_m: float = (p_lon - house_lon) * 111320.0 * cos(deg_to_rad(house_lat))
		var computed: float = sqrt(d_lat_m * d_lat_m + d_lon_m * d_lon_m)
		if computed > 5.0:
			return clampf(computed, 25.0, 1500.0)
	return float(85 + idx * 55)


static func _extract_bearing(poi: Dictionary, house_lat: float, house_lon: float, idx: int) -> String:
	var raw_b: String = str(poi.get("bearing", poi.get("bearing_dir", poi.get("direction", poi.get("compass", ""))))).strip_edges().to_upper()
	if raw_b in ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]:
		return raw_b
	if poi.has("lat") and poi.has("lon"):
		var p_lat: float = float(poi.get("lat", house_lat))
		var p_lon: float = float(poi.get("lon", house_lon))
		var dy: float = p_lat - house_lat
		var dx: float = (p_lon - house_lon) * cos(deg_to_rad(house_lat))
		if absf(dx) > 0.00001 or absf(dy) > 0.00001:
			var angle_deg: float = fposmod(rad_to_deg(atan2(dx, dy)), 360.0)
			var dirs: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
			var dir_idx: int = int(round(angle_deg / 45.0)) % 8
			return dirs[dir_idx]
	var fallback_dirs: Array[String] = ["E", "SE", "SW", "N", "NE", "NW", "S", "W"]
	return fallback_dirs[idx % fallback_dirs.size()]


static func _extract_base_name(poi: Dictionary, cat: String, _idx: int) -> String:
	var nm: String = str(poi.get("name", "")).strip_edges()
	if nm != "":
		var paren_pos: int = nm.rfind("(")
		if paren_pos > 2 and nm.ends_with(")") and nm.substr(paren_pos).find("m ") != -1:
			nm = nm.substr(0, paren_pos).strip_edges()
		return nm
	# Never invent a name: describe what OSM says the place is.
	if not str(poi.get("kind_label", "")).is_empty():
		return LocationText.poi_label(poi)
	return "Unnamed %s" % OsmService.get_category_label(cat).to_lower()


static func _format_target_display(base_name: String, dist_m: float, bearing: String) -> String:
	return "%s (%dm walk %s)" % [base_name, int(round(dist_m)), bearing]


static func _fictional_targets(house: Dictionary) -> Array:
	var h_lat: float = float(house.get("lat", 0.0))
	var h_lon: float = float(house.get("lon", 0.0))
	var out: Array = []
	var specs: Array = [["Abandoned farmstead", 0.0, 380.0], ["Roadside barn", 120.0, 520.0], ["Empty cottage", 250.0, 300.0]]
	for i in range(specs.size()):
		var sp: Array = specs[i]
		var pt: Dictionary = NukePhysics.destination_point(h_lat, h_lon, float(sp[1]), float(sp[2]) / 1000.0)
		out.append({
			"osm_id": -100 - i, "name": "%s (fictional)" % str(sp[0]), "category": "neighbor_house", "fictional": true,
			"source": "fictional", "lat": float(pt["lat"]), "lon": float(pt["lon"]), "distance_m": float(sp[2]),
			"walk_m": int(float(sp[2]) * 1.35), "walk_source": "estimate", "bearing_dir": NukePhysics.compass_label(float(sp[1])),
			"travel_days": 2, "named": false, "visited_count": 0, "depleted": false
		})
	return out
