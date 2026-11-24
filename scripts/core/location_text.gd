class_name LocationText
extends RefCounted

## Natural-language references to the player's real location.
##
## Gameplay text says "home", "the house on East Republican Street", "Capitol Hill"
## or "Seattle" – never the full postal address. The exact address (house number,
## postcode, country) is only for the property-information panels, via full_address().

static var _rotation: int = 0

const COMPASS_WORDS: Array[String] = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]


static func place_names() -> Dictionary:
	return GameState.place_names if GameState.place_names is Dictionary else {}


static func street() -> String:
	var s: String = str(place_names().get("street", "")).strip_edges()
	if s.is_empty():
		s = str(GameState.selected_house.get("street", "")).strip_edges()
	return s


static func neighborhood() -> String:
	return str(place_names().get("neighborhood", "")).strip_edges()


static func city() -> String:
	var c: String = str(place_names().get("city", "")).strip_edges()
	if c.is_empty():
		c = str(GameState.selected_house.get("city", "")).strip_edges()
	return c


## Short area name used in prose: neighbourhood if known, else city, else "the neighborhood".
static func area_name() -> String:
	var n: String = neighborhood()
	if not n.is_empty():
		return n
	var c: String = city()
	if not c.is_empty():
		return c
	return "the neighborhood"


## "Capitol Hill, Seattle" style label for headers (no state/country/postcode).
static func area_header() -> String:
	var n: String = neighborhood()
	var c: String = city()
	if not n.is_empty() and not c.is_empty() and n != c:
		return "%s, %s" % [n, c]
	if not n.is_empty():
		return n
	if not c.is_empty():
		return c
	return "Home"


## A rotating noun phrase for the player's house that reads naturally after any preposition:
## "the house", "our place", "the house on East Republican Street", ...
static func home_ref() -> String:
	_rotation += 1
	var st: String = street()
	var opts: Array[String] = ["the house", "our place", "home base"]
	if not st.is_empty():
		opts = ["the house", "the house on %s" % st, "our place", "our place on %s" % st, "the house"]
	return opts[_rotation % opts.size()]


## Short label for HUDs/headers: "Home · East Republican Street" or "Home".
static func home_label() -> String:
	var st: String = street()
	return ("Home · %s" % st) if not st.is_empty() else "Home"


## Exact postal address. Use ONLY in property-information panels.
static func full_address() -> String:
	var pn: Dictionary = place_names()
	var parts: Array[String] = []
	var hn: String = str(pn.get("housenumber", GameState.selected_house.get("housenumber", ""))).strip_edges()
	var st: String = street()
	if not st.is_empty():
		parts.append(("%s %s" % [hn, st]).strip_edges())
	elif not str(GameState.selected_house.get("short_address", "")).is_empty():
		parts.append(str(GameState.selected_house.get("short_address", "")))
	for key in ["neighborhood", "city", "region", "postcode", "country"]:
		var v: String = str(pn.get(key, "")).strip_edges()
		if not v.is_empty() and not parts.has(v):
			parts.append(v)
	if parts.is_empty():
		return str(GameState.selected_house.get("address", "Unknown address"))
	return ", ".join(parts)


static func compass_word(bearing_deg: float) -> String:
	return COMPASS_WORDS[int(round(fposmod(bearing_deg, 360.0) / 45.0)) % 8]


## Human label for a POI: real OSM name plus its kind, or an honest description when unnamed.
static func poi_label(poi: Dictionary) -> String:
	var nm: String = str(poi.get("raw_name", poi.get("name", ""))).strip_edges()
	var kind: String = str(poi.get("kind_label", "")).strip_edges()
	if bool(poi.get("fictional", false)):
		return "%s (fictional)" % str(poi.get("name", "Abandoned homestead"))
	if str(poi.get("category", "")) == "neighbor_house":
		return str(poi.get("name", "a neighbor's house"))
	if nm.is_empty() or not bool(poi.get("has_explicit_name", poi.get("named", true))):
		var on_street: String = str(poi.get("street", "")).strip_edges()
		if kind.is_empty():
			kind = "building"
		return ("unnamed %s on %s" % [kind.to_lower(), on_street]) if not on_street.is_empty() else ("unnamed %s" % kind.to_lower())
	return nm


## The nearest real, named feature (POI or named park) roughly in a compass direction from home.
## Returns {} when nothing suitable is mapped – callers must then avoid naming a place.
static func landmark_toward(bearing_deg: float, max_angle_deg: float = 50.0, min_dist_m: float = 60.0) -> Dictionary:
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	var best: Dictionary = {}
	var best_score: float = -1e20
	var cands: Array = []
	for p_v in GameState.nearby_pois:
		var p: Dictionary = p_v
		if str(p.get("category", "")) == "neighbor_house" or bool(p.get("fictional", false)):
			continue
		if not bool(p.get("named", p.get("has_explicit_name", false))):
			continue
		cands.append({"name": str(p.get("name", "")), "lat": float(p.get("lat", 0.0)), "lon": float(p.get("lon", 0.0)), "osm_id": int(p.get("osm_id", 0))})
	for pk_v in GameState.map_parks:
		var pk: Dictionary = pk_v
		var pname: String = str(pk.get("name", "")).strip_edges()
		if pname.is_empty():
			continue
		var c: Vector2 = pk.get("centroid", Vector2.ZERO)
		if c == Vector2.ZERO:
			continue
		cands.append({"name": pname, "lat": c.y, "lon": c.x, "osm_id": int(pk.get("osm_id", 0))})
	for c_v in cands:
		var c2: Dictionary = c_v
		var db: Dictionary = OsmService.distance_and_bearing(h_lat, h_lon, float(c2["lat"]), float(c2["lon"]))
		var d: float = float(db["distance_m"])
		if d < min_dist_m:
			continue
		var diff: float = absf(fposmod(float(db["bearing_deg"]) - bearing_deg + 180.0, 360.0) - 180.0)
		if diff > max_angle_deg:
			continue
		var score: float = d * 0.004 - diff * 0.05
		if score > best_score:
			best_score = score
			best = c2.duplicate()
			best["distance_m"] = d
			best["bearing_deg"] = float(db["bearing_deg"])
	return best


## Downwind direction (where fallout travels). In this game `wind_bearing_deg` is the
## direction the plume is carried TOWARD (NukePhysics aligns the plume with it from ground zero).
static func downwind_bearing() -> float:
	return fposmod(float(GameState.nuke_config.get("wind_bearing_deg", 45.0)), 360.0)


## Meteorological wind name (winds are named for where they come FROM): plume toward NE = "southwest wind".
static func wind_name() -> String:
	return "%s wind" % compass_word(downwind_bearing() + 180.0)
