extends SceneTree

## Ruthless OpenStreetMap, Geospatial Floorplan & Nuclear Physics Audit Suite
## Run with:
## godot --headless --path . -s res://tests/critic_osm_audit.gd

var pass_count: int = 0
var fail_count: int = 0
var warn_count: int = 0
var defect_log: Array[String] = []
var info_log: Array[String] = []

var _search_done: bool = false
var _search_err: String = ""
var _search_results: Array = []
var _map_done: bool = false
var _map_err: String = ""
var _map_parsed: Dictionary = {}
var _map_label: String = ""

# Dynamically loaded script classes (loaded after SceneTree registers GameState & SoundManager autoloads)
var OsmServiceScript: GDScript
var OsmSlippyMapScript: GDScript
var HouseSelectScreenScript: GDScript
var ExpeditionEngineScript: GDScript
var HouseGeneratorScript: GDScript
var ScavengeSceneScript: GDScript
var NukePhysicsScript: GDScript
var NukeScreenScript: GDScript
var BunkerSimScript: GDScript

func _init() -> void:
	call_deferred("_run_all_audits")

func _record_pass(msg: String) -> void:
	pass_count += 1
	print("  [PASS] " + msg)

func _record_fail(msg: String) -> void:
	fail_count += 1
	defect_log.append(msg)
	print("  [FAIL] " + msg)

func _record_warn(msg: String) -> void:
	warn_count += 1
	info_log.append(msg)
	print("  [WARN] " + msg)

func _assert_cond(cond: bool, pass_msg: String, fail_msg: String) -> void:
	if cond:
		_record_pass(pass_msg)
	else:
		_record_fail(fail_msg)

func _wait_frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _run_all_audits() -> void:
	await _wait_frames(2)
	print("================================================================================")
	print("RUTHLESS CRITIC AUDIT: OSM, GEOSPATIAL FLOORPLAN & NUCLEAR PHYSICS")
	print("================================================================================")

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		_record_fail("GameState autoload missing from SceneTree root!")
		quit(0)
		return
	gs.set("demo_mode", false)

	OsmServiceScript = load("res://scripts/osm/osm_service.gd")
	OsmSlippyMapScript = load("res://scripts/osm/osm_slippy_map.gd")
	HouseSelectScreenScript = load("res://scripts/ui/house_select_screen.gd")
	ExpeditionEngineScript = load("res://scripts/expedition/expedition_engine.gd")
	HouseGeneratorScript = load("res://scripts/scavenge/house_generator.gd")
	ScavengeSceneScript = load("res://scripts/scavenge/scavenge_scene.gd")
	NukePhysicsScript = load("res://scripts/nuke/nuke_physics.gd")
	NukeScreenScript = load("res://scripts/ui/nuke_screen.gd")
	BunkerSimScript = load("res://scripts/bunker/bunker_sim.gd")

	_assert_cond(
		OsmServiceScript != null and OsmSlippyMapScript != null and HouseSelectScreenScript != null
		and ExpeditionEngineScript != null and HouseGeneratorScript != null and ScavengeSceneScript != null
		and NukePhysicsScript != null and NukeScreenScript != null and BunkerSimScript != null,
		"All 9 target GDScript modules compiled cleanly without errors",
		"One or more target GDScript modules failed to compile!"
	)

	# 1. Preset & Live OSM Integration + Slippy Map Click Audit
	var all_real_houses: Array = await _audit_1_osm_integration(gs)

	# 2. Real-World Neighboring Houses, Churches, Groceries & ExpeditionEngine Audit
	await _audit_2_pois_and_expeditions(gs)

	# 3. 50+ Real OSM Houses -> 60s Scavenge Floorplan Reachability & Geometry Audit
	await _audit_3_floorplan_reachability(gs, all_real_houses)

	# 4. Global Nuke Detonation Physics & Propagation into ScavengeScene + BunkerSim
	await _audit_4_nuke_physics_and_propagation(gs)

	print("\n================================================================================")
	print("AUDIT SUMMARY: %d PASSED | %d FAILED | %d WARNINGS" % [pass_count, fail_count, warn_count])
	print("================================================================================")
	for idx in range(defect_log.size()):
		print("  DEFECT %d: %s" % [idx + 1, defect_log[idx]])
	for idx in range(info_log.size()):
		print("  NOTE   %d: %s" % [idx + 1, info_log[idx]])
	print("AUDIT_COMPLETE")
	await _wait_frames(4)
	quit(0)


# ==============================================================================
# AUDIT 1: LIVE & PRESET OPENSTREETMAP INTEGRATION + SLIPPY MAP CLICKING
# ==============================================================================
func _audit_1_osm_integration(gs: Node) -> Array:
	print("\n--- [1] LIVE & PRESET OPENSTREETMAP INTEGRATION ---")
	var collected_houses: Array = []

	# 1A. Test all 3 bundled real neighborhood datasets
	var preset_ids: Array[String] = ["seattle", "concord", "brooklyn"]

	for pid in preset_ids:
		var parsed: Dictionary = OsmServiceScript.load_preset(pid)
		var bldgs: Array = parsed.get("buildings", [])
		var pois: Array = parsed.get("pois", [])
		var roads: Array = parsed.get("roads", [])
		var parks: Array = parsed.get("parks", [])
		var synth: bool = bool(parsed.get("synthesized_rural", true))
		var pref_id: int = int(parsed.get("preferred_osm_id", -1))

		_assert_cond(
			not synth and bldgs.size() >= 30 and pois.size() >= 5 and roads.size() >= 5,
			"Preset '%s' loaded authentic OSM data: %d buildings, %d POIs, %d roads, %d parks" % [
				pid, bldgs.size(), pois.size(), roads.size(), parks.size()
			],
			"Preset '%s' failed or used synthetic fallback (synth=%s, bldgs=%d, pois=%d)" % [
				pid, str(synth), bldgs.size(), pois.size()
			]
		)

		var found_pref: bool = false
		for b in bldgs:
			if int(b.get("osm_id", 0)) == pref_id:
				found_pref = true
				break
		if found_pref:
			_record_pass("Preset '%s' preferred_osm_id=%d exists in parsed buildings" % [pid, pref_id])
		else:
			_record_warn("osm_service.gd:29/38/47 Preset '%s' preferred_osm_id=%d NOT found in parsed buildings" % [pid, pref_id])

		for b in bldgs:
			var b_copy: Dictionary = (b as Dictionary).duplicate(true)
			b_copy["_source"] = pid
			collected_houses.append(b_copy)

	# 1B. Test LIVE HTTP Nominatim Geocoding + Live api.openstreetmap.org/api/0.6/map.json
	var osm_node: Node = OsmServiceScript.new()
	root.add_child(osm_node)
	await _wait_frames(2)

	osm_node.connect("search_completed", func(res: Array, _q: String) -> void:
		_search_results = res
		_search_done = true
	)
	osm_node.connect("search_failed", func(err: String) -> void:
		_search_err = err
		_search_done = true
	)
	osm_node.connect("map_data_loaded", func(pdata: Dictionary, lbl: String) -> void:
		_map_parsed = pdata
		_map_label = lbl
		_map_done = true
	)
	osm_node.connect("map_data_failed", func(err: String) -> void:
		_map_err = err
		_map_done = true
	)

	var live_queries: Array[Dictionary] = [
		{"q": "Harvard Square Cambridge Massachusetts", "exp_lat": 42.373, "exp_lon": -71.119, "tol_deg": 0.15},
		{"q": "Lincoln Park Chicago Illinois", "exp_lat": 41.921, "exp_lon": -87.651, "tol_deg": 0.20}
	]

	for q_idx in range(live_queries.size()):
		if q_idx > 0:
			var pause_start: int = Time.get_ticks_msec()
			while (Time.get_ticks_msec() - pause_start) < 1200:
				await process_frame

		var lq: Dictionary = live_queries[q_idx]
		var q_str: String = str(lq["q"])
		_search_done = false
		_search_err = ""
		_search_results = []
		_map_done = false
		_map_err = ""
		_map_parsed = {}

		osm_node.call("search_nominatim", q_str, true)
		var elapsed: float = 0.0
		var start_ms: int = Time.get_ticks_msec()
		while (not _search_done or not _map_done) and (Time.get_ticks_msec() - start_ms) < 20000:
			await process_frame
			elapsed = float(Time.get_ticks_msec() - start_ms) / 1000.0
			if _search_done and not _search_err.is_empty():
				break
			if _map_done and not _map_err.is_empty():
				break

		if not _search_err.is_empty():
			_record_fail("Live Nominatim search '%s' failed: %s" % [q_str, _search_err])
		elif not _search_done:
			_record_fail("Live Nominatim search '%s' timed out after %.1fs" % [q_str, elapsed])
		else:
			var top: Dictionary = _search_results[0]
			var r_lat: float = float(top.get("lat", 0.0))
			var r_lon: float = float(top.get("lon", 0.0))
			var lat_ok: bool = absf(r_lat - float(lq["exp_lat"])) < float(lq["tol_deg"])
			var lon_ok: bool = absf(r_lon - float(lq["exp_lon"])) < float(lq["tol_deg"])
			_assert_cond(
				lat_ok and lon_ok,
				"Live Nominatim geocoded '%s' -> (%.4f, %.4f) '%s' in %.2fs" % [q_str, r_lat, r_lon, str(top.get("short_name", "")), elapsed],
				"Live Nominatim coordinates mismatch for '%s': got (%.4f, %.4f)" % [q_str, r_lat, r_lon]
			)

		if _map_done and not _map_parsed.is_empty():
			var live_fallback: bool = bool(_map_parsed.get("live_fallback", false))
			var synth_rural: bool = bool(_map_parsed.get("synthesized_rural", false))
			var lbldgs: Array = _map_parsed.get("buildings", [])
			var lpois: Array = _map_parsed.get("pois", [])
			var lroads: Array = _map_parsed.get("roads", [])
			_assert_cond(
				not live_fallback and not synth_rural and lbldgs.size() >= 20 and lpois.size() >= 3,
				"Live OSM 0.6 map.json for '%s' returned %d real buildings, %d POIs, %d roads" % [
					q_str, lbldgs.size(), lpois.size(), lroads.size()
				],
				"Live OSM 0.6 map.json for '%s' fell back or returned sparse data (live_fallback=%s, synth=%s, bldgs=%d, pois=%d)" % [
					q_str, str(live_fallback), str(synth_rural), lbldgs.size(), lpois.size()
				]
			)
			for i in range(mini(15, lbldgs.size())):
				var bc: Dictionary = (lbldgs[i] as Dictionary).duplicate(true)
				bc["_source"] = "live_" + q_str.split(" ")[0].to_lower()
				collected_houses.append(bc)
		else:
			_record_fail("Live OSM 0.6 map.json did not complete for '%s' (err='%s')" % [q_str, _map_err])

	osm_node.queue_free()
	await _wait_frames(2)

	# 1C. Test HouseSelectScreen + OsmSlippyMap live PNG tile streaming & polygon clicking
	var hs_screen: Control = HouseSelectScreenScript.new()
	hs_screen.size = Vector2(1280.0, 720.0)
	root.add_child(hs_screen)
	await _wait_frames(6)

	var slippy: Control = hs_screen.get("_slippy_map")
	_assert_cond(is_instance_valid(slippy), "HouseSelectScreen instantiated OsmSlippyMap", "OsmSlippyMap missing on HouseSelectScreen")

	# Check whether _visible_bldg_hit_cache was populated automatically by _draw() in --headless mode!
	var hit_cache_initial: Array = slippy.get("_visible_bldg_hit_cache")
	var auto_cache_size: int = hit_cache_initial.size()
	if auto_cache_size == 0:
		_record_warn("osm_slippy_map.gd:360-382 & 739-796 _pick_building_at relies on _visible_bldg_hit_cache populated inside _draw(); in Godot --headless dummy renderer _draw() does not fire, so _pick_building_at returns {} unless rendered or _visible_bldg_hit_cache is built on data/view change.")
		# Populate hit cache programmatically (matching lines 740-796 of osm_slippy_map.gd) to test _gui_input click & hit-testing!
		_populate_slippy_hit_cache_headless(slippy)
	else:
		_record_pass("OsmSlippyMap._visible_bldg_hit_cache populated (%d visible parcels)" % auto_cache_size)

	# Test live slippy PNG tile HTTP fetch from tile.openstreetmap.org
	var z_test: int = int(slippy.get("zoom"))
	var wx_center: float = OsmSlippyMapScript._lon_to_world_x(float(slippy.get("center_lon")), z_test)
	var wy_center: float = OsmSlippyMapScript._lat_to_world_y(float(slippy.get("center_lat")), z_test)
	var tx_center: int = int(floor(wx_center / 256.0))
	var ty_center: int = int(floor(wy_center / 256.0))
	var tile_key: String = "%d/%d/%d" % [z_test, tx_center, ty_center]
	slippy.call("_request_tile", z_test, tx_center, ty_center)
	var tile_start_ms: int = Time.get_ticks_msec()
	while not (slippy.get("_tile_textures") as Dictionary).has(tile_key) and not (slippy.get("_failed_tiles") as Dictionary).has(tile_key) and (Time.get_ticks_msec() - tile_start_ms) < 8000:
		slippy.call("_pump_tile_queue")
		await process_frame

	var tile_tex_map: Dictionary = slippy.get("_tile_textures")
	if tile_tex_map.has(tile_key):
		var tex: Texture2D = tile_tex_map[tile_key]
		_assert_cond(
			tex != null and tex.get_width() == 256 and tex.get_height() == 256,
			"OsmSlippyMap streamed & decoded live 256x256 PNG slippy tile (%s) from tile.openstreetmap.org" % tile_key,
			"OsmSlippyMap slippy tile (%s) invalid dimensions" % tile_key
		)
	else:
		_record_fail("OsmSlippyMap failed to fetch live PNG slippy tile (%s) from tile.openstreetmap.org" % tile_key)

	# Test clicking 18 distinct visible building polygons across Seattle, Concord, and Brooklyn
	var click_exact_matches: int = 0
	var click_total: int = 0
	for pid in preset_ids:
		hs_screen.call("_load_preset_neighborhood", pid, false)
		await _wait_frames(3)
		if (slippy.get("_visible_bldg_hit_cache") as Array).is_empty():
			_populate_slippy_hit_cache_headless(slippy)

		var cache_arr: Array = (slippy.get("_visible_bldg_hit_cache") as Array).duplicate()
		var tested_in_preset: int = 0
		for idx in range(0, cache_arr.size(), maxi(1, int(cache_arr.size() / 8))):
			if tested_in_preset >= 6:
				break
			var entry: Dictionary = cache_arr[idx]
			var bldg: Dictionary = entry["bldg"]
			var poly: PackedVector2Array = entry["poly"]
			var click_pt: Vector2 = _find_interior_point_of_screen_poly(poly, entry["center"])
			if not Rect2(Vector2(20, 20), slippy.size - Vector2(40, 40)).has_point(click_pt):
				continue

			var ev_down := InputEventMouseButton.new()
			ev_down.button_index = MOUSE_BUTTON_LEFT
			ev_down.pressed = true
			ev_down.position = click_pt
			slippy.call("_gui_input", ev_down)

			var ev_up := InputEventMouseButton.new()
			ev_up.button_index = MOUSE_BUTTON_LEFT
			ev_up.pressed = false
			ev_up.position = click_pt
			slippy.call("_gui_input", ev_up)

			click_total += 1
			tested_in_preset += 1

			var sel: Dictionary = gs.get("selected_house")
			var nearby: Array = gs.get("nearby_pois")
			var expected_id: int = int(bldg.get("osm_id", -1))
			var got_id: int = int(sel.get("osm_id", -2))
			var fp_m: Array = sel.get("footprint_meters", [])
			if got_id == expected_id and fp_m.size() >= 3 and not str(sel.get("address", "")).is_empty() and nearby.size() >= 5:
				click_exact_matches += 1
			else:
				var hit_other: Dictionary = slippy.call("_pick_building_at", click_pt)
				if not hit_other.is_empty() and int(hit_other.get("osm_id", -3)) == got_id and Geometry2D.is_point_in_polygon(click_pt, poly):
					click_exact_matches += 1
				else:
					_record_fail("Click at %s for OSM #%d selected OSM #%d (fp_size=%d, nearby=%d)" % [
						str(click_pt), expected_id, got_id, fp_m.size(), nearby.size()
					])

	_assert_cond(
		click_total >= 15 and click_exact_matches == click_total,
		"OsmSlippyMap polygon click-selection succeeded on %d/%d real houses, updating GameState.selected_house (address, lat/lon, area_sqm, footprint_meters) & GameState.nearby_pois" % [click_exact_matches, click_total],
		"OsmSlippyMap polygon click-selection only matched %d/%d houses" % [click_exact_matches, click_total]
	)

	hs_screen.queue_free()
	await _wait_frames(2)
	return collected_houses


func _populate_slippy_hit_cache_headless(slippy: Control) -> void:
	# Replicates lines 740-796 of osm_slippy_map.gd without draw_* calls (which error outside _draw() notification)
	var vp_rect := Rect2(Vector2.ZERO, slippy.size)
	var cull_rect: Rect2 = vp_rect.grow(40.0)
	var cache: Array = []
	var bldgs: Array = slippy.get("_buildings")
	for b_v in bldgs:
		var b: Dictionary = b_v
		var poly_ll: Array = b.get("polygon_latlon", [])
		var scr := PackedVector2Array()
		var bounds := Rect2()
		for i in range(poly_ll.size()):
			var ll: Vector2 = poly_ll[i]
			var sp: Vector2 = slippy.call("latlon_to_screen", ll.y, ll.x)
			scr.append(sp)
			bounds = Rect2(sp, Vector2.ZERO) if i == 0 else bounds.expand(sp)
		if scr.size() < 3 or not cull_rect.intersects(bounds):
			continue
		var c_screen: Vector2 = slippy.call("latlon_to_screen", float(b.get("lat", 0.0)), float(b.get("lon", 0.0)))
		cache.append({
			"bldg": b,
			"poly": scr,
			"bounds": bounds,
			"center": c_screen
		})
	slippy.set("_visible_bldg_hit_cache", cache)


func _find_interior_point_of_screen_poly(poly: PackedVector2Array, fallback_center: Vector2) -> Vector2:
	if Geometry2D.is_point_in_polygon(fallback_center, poly):
		return fallback_center
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tris.size() >= 3:
		return (poly[tris[0]] + poly[tris[1]] + poly[tris[2]]) / 3.0
	return fallback_center


# ==============================================================================
# AUDIT 2: REAL-WORLD NEIGHBORING HOUSES, POIS & EXPEDITION ENGINE
# ==============================================================================
func _audit_2_pois_and_expeditions(gs: Node) -> void:
	print("\n--- [2] REAL-WORLD NEIGHBORS, POIS & EXPEDITION ENGINE ---")

	var preset_ids: Array[String] = ["seattle", "concord", "brooklyn"]
	var max_dist_err_m: float = 0.0
	var bearing_mismatches: int = 0
	var total_targets_checked: int = 0

	for pid in preset_ids:
		var parsed: Dictionary = OsmServiceScript.load_preset(pid)
		var bldgs: Array = parsed.get("buildings", [])
		var pois: Array = parsed.get("pois", [])
		var house: Dictionary = OsmServiceScript.pick_best_house(
			bldgs,
			float(parsed.get("center_lat", 0.0)),
			float(parsed.get("center_lon", 0.0)),
			int(parsed.get("preferred_osm_id", -1))
		)
		var targets: Array = OsmServiceScript.build_nearby_targets_for_house(house, bldgs, pois)
		var h_lat: float = float(house.get("lat", 0.0))
		var h_lon: float = float(house.get("lon", 0.0))

		var local_cats: Dictionary = {}
		for t_v in targets:
			var t: Dictionary = t_v
			var cat: String = str(t.get("category", ""))
			local_cats[cat] = int(local_cats.get(cat, 0)) + 1

			var t_lat: float = float(t.get("lat", 0.0))
			var t_lon: float = float(t.get("lon", 0.0))
			var reported_m: int = int(t.get("distance_m", 0))
			var exact_m: float = NukePhysicsScript.haversine_km(h_lat, h_lon, t_lat, t_lon) * 1000.0
			var err_m: float = absf(float(reported_m) - maxf(8.0, exact_m))
			max_dist_err_m = maxf(max_dist_err_m, err_m)

			var exact_brng_deg: float = NukePhysicsScript.bearing_deg(h_lat, h_lon, t_lat, t_lon)
			var exact_dir: String = NukePhysicsScript.compass_label(exact_brng_deg)
			var rep_dir: String = str(t.get("bearing_dir", ""))
			if rep_dir != exact_dir:
				var oct_mod: float = absf(fposmod(exact_brng_deg + 22.5, 45.0))
				if oct_mod > 1.5 and oct_mod < 43.5:
					bearing_mismatches += 1
			total_targets_checked += 1

		_assert_cond(
			int(local_cats.get("neighbor_house", 0)) >= 5 and int(local_cats.get("grocery", 0)) >= 1 and int(local_cats.get("church", 0)) >= 1,
			"Preset '%s' build_nearby_targets_for_house found %d total targets (neighbors=%d, church=%d, grocery=%d, pharmacy=%d, hardware=%d, school=%d)" % [
				pid, targets.size(),
				int(local_cats.get("neighbor_house", 0)),
				int(local_cats.get("church", 0)),
				int(local_cats.get("grocery", 0)),
				int(local_cats.get("pharmacy", 0)),
				int(local_cats.get("hardware", 0)),
				int(local_cats.get("school", 0))
			],
			"Preset '%s' missing core POI categories: %s" % [pid, str(local_cats)]
		)

	_assert_cond(
		max_dist_err_m <= 4.0 and bearing_mismatches == 0,
		"Geodesic accuracy across %d real POIs/neighbors: max distance error = %.2fm, compass bearing mismatches = %d" % [
			total_targets_checked, max_dist_err_m, bearing_mismatches
		],
		"Geodesic error too high: max_dist_err_m=%.2fm, bearing_mismatches=%d" % [max_dist_err_m, bearing_mismatches]
	)

	# Check 2A: Police/Fire/EMS -> 'civic' classification & post_office/copyshop exclusion from 'hardware'!
	var police_info: Dictionary = OsmServiceScript._classify_poi_tags({"amenity": "police", "name": "10th Precinct"})
	var fire_info: Dictionary = OsmServiceScript._classify_poi_tags({"amenity": "fire_station", "name": "Engine Co. 25"})
	var fire_bldg_info: Dictionary = OsmServiceScript._classify_poi_tags({"building": "fire_station", "name": "Hook & Ladder 8"})
	var ems_info: Dictionary = OsmServiceScript._classify_poi_tags({"emergency": "ambulance_station", "name": "FDNY EMS Station 32"})
	var post_info: Dictionary = OsmServiceScript._classify_poi_tags({"amenity": "post_office", "name": "United States Post Office"})
	var copy_info: Dictionary = OsmServiceScript._classify_poi_tags({"shop": "copyshop", "name": "FedEx Office"})
	var ups_info: Dictionary = OsmServiceScript._classify_poi_tags({"amenity": "post_office", "shop": "copyshop", "name": "The UPS Store"})

	var police_rec: Dictionary = OsmServiceScript._make_poi_record(9991, 47.625, -122.320, {"amenity": "police", "name": "10th Precinct"}, police_info)
	var norm_police_cat: String = ExpeditionEngineScript._normalize_category(police_rec)

	# Verify real Brooklyn FDNY EMS Station 32 is parsed as 'civic' and no post_office/copyshop leaked into Seattle/Concord POIs
	var brooklyn_parsed: Dictionary = OsmServiceScript.load_preset("brooklyn")
	var brooklyn_civic_count: int = 0
	for p_v in brooklyn_parsed.get("pois", []):
		if str((p_v as Dictionary).get("category", "")) == "civic":
			brooklyn_civic_count += 1
	var leaked_mail_or_copy: int = 0
	for pid_chk in ["seattle", "concord", "brooklyn"]:
		var p_chk: Dictionary = OsmServiceScript.load_preset(pid_chk)
		for p_v in p_chk.get("pois", []):
			var pd: Dictionary = p_v
			var ptag: String = str(pd.get("osm_tag", ""))
			if ptag.find("post_office") != -1 or ptag.find("copyshop") != -1:
				leaked_mail_or_copy += 1

	_assert_cond(
		str(police_info.get("category", "")) == "civic"
		and str(fire_info.get("category", "")) == "civic"
		and str(fire_bldg_info.get("category", "")) == "civic"
		and str(ems_info.get("category", "")) == "civic"
		and norm_police_cat == "civic"
		and brooklyn_civic_count >= 1
		and post_info.is_empty() and copy_info.is_empty() and ups_info.is_empty()
		and leaked_mail_or_copy == 0,
		"OsmService classifies Police/Fire/EMS as 'civic' (Brooklyn civic POIs=%d, ExpeditionEngine cat='%s') and excludes post_office/copyshop (0 leaks)" % [
			brooklyn_civic_count, norm_police_cat
		],
		"Civic/PostOffice classification error: police=%s, fire=%s, ems=%s, norm=%s, bk_civic=%d, leaked=%d" % [
			str(police_info), str(fire_info), str(ems_info), norm_police_cat, brooklyn_civic_count, leaked_mail_or_copy
		]
	)

	# Check 2B (pass 2): every category's preview (house-select list AND expedition planner) lists
	# exactly what that kind of building can stock in the finite LootInventory, nothing invented.
	var LootInv: GDScript = load("res://scripts/expedition/loot_inventory.gd")
	var preview_mismatch: Array = []
	var cat_n: int = 0
	gs.set("poi_inventories", {})
	for cat_p in ["grocery", "pharmacy", "hardware", "auto", "church", "school", "civic", "park", "restaurant"]:
		cat_n += 1
		var osm_prev: Array = OsmServiceScript.get_loot_profile_for_category(cat_p)
		var eng_prev: Array = ExpeditionEngineScript._expected_loot_for_category(cat_p)
		var seen: Dictionary = {}
		for k_i in range(160):
			var fake_poi: Dictionary = {"osm_id": 880000 + cat_n * 1000 + k_i, "category": cat_p, "name": "Audit %s %d" % [cat_p, k_i], "area_sqm": 300.0}
			var inv_items: Dictionary = (LootInv.call("get_inventory", fake_poi) as Dictionary).get("items", {})
			for iid_k in inv_items.keys():
				if int(inv_items[iid_k]) > 0:
					seen[str(iid_k)] = true
		var all_ok: bool = osm_prev == eng_prev and not osm_prev.is_empty()
		for pv in osm_prev:
			if not seen.has(str(pv)):
				all_ok = false
		if not all_ok:
			preview_mismatch.append("%s preview=%s stocked=%s" % [cat_p, str(osm_prev), str(seen.keys())])
	var hw_prev: Array = OsmServiceScript.get_loot_profile_for_category("hardware")
	# M1: the stock tables come from data/loot_weights.csv; hardware sells padlocks and tools, rifles
	# only turn up at police/fire stations or (rarely) a neighbour's.
	_assert_cond(
		preview_mismatch.is_empty() and hw_prev.has("padlock") and hw_prev.has("flashlight") and not hw_prev.has("rifle"),
		"Loot previews match the finite stock table for all 9 categories (hardware: %s; rifles only at civic places)" % str(hw_prev),
		"Loot preview mismatch: %s (hardware=%s)" % [str(preview_mismatch), str(hw_prev)]
	)

	# M1: full trips run through ShelterTrips on a real shelter run (the night-by-night risk is set to
	# zero here so the check is about routing and loot, not luck).
	var seattle_parsed: Dictionary = OsmServiceScript.load_preset("seattle")
	var s_bldgs: Array = seattle_parsed["buildings"]
	var s_pois: Array = seattle_parsed["pois"]
	var s_house: Dictionary = OsmServiceScript.pick_best_house(s_bldgs, 47.6240, -122.3195, 206082403)
	var brooklyn_house_pois: Array = brooklyn_parsed["pois"]
	var b_bldgs: Array = brooklyn_parsed["buildings"]
	var b_house: Dictionary = OsmServiceScript.pick_best_house(b_bldgs, 40.6802, -73.9930, 248154036)
	var trip_results: Dictionary = {}
	for cat_want in ["grocery", "church", "pharmacy", "hardware", "school", "neighbor_house", "civic"]:
		var use_bk: bool = cat_want == "civic"
		gs.call("reset_to_defaults")
		gs.set("selected_house", b_house if use_bk else s_house)
		gs.set("nearby_pois", OsmServiceScript.build_nearby_targets_for_house(b_house if use_bk else s_house, b_bldgs if use_bk else s_bldgs, brooklyn_house_pois if use_bk else s_pois))
		for m in gs.get("family_members"):
			m["in_bunker"] = true
			m["alive"] = true
		gs.call("add_scavenged_item", "food", 6)
		gs.call("add_scavenged_item", "water", 6)
		gs.call("add_scavenged_item", "axe", 1)
		BunkerSimScript.start_bunker_run()
		var sh: ShelterState = gs.get("shelter")
		var idx: int = -1
		for p_v in sh.places:
			if str((p_v as Dictionary)["category"]) == cat_want:
				idx = int((p_v as Dictionary)["idx"])
				break
		if idx < 0:
			continue
		var m0: Dictionary = sh.members[0]
		var why: String = ShelterTrips.launch(sh, m0, idx, ["axe"] if cat_want in ["pharmacy", "hardware"] else [])
		for t_v in sh.trips:
			(t_v as Dictionary)["p_day"] = 0.0
		var back: String = ""
		var guard: int = 0
		while str(m0.get("loc", "")) == "away" and guard < 12:
			sh.receipt = []
			ShelterTrips.tick(sh)
			sh.day += 1
			for l_v in sh.receipt:
				if str((l_v as Dictionary).get("kind", "")) == "return":
					back = str((l_v as Dictionary)["text"])
			guard += 1
		trip_results[cat_want] = back
		_assert_cond(why == "" and back != "" and not back.ends_with("with nothing."),
			"Trip to a real '%s' place came home with loot: %s" % [cat_want, back],
			"Trip to '%s' failed (why='%s', back='%s')" % [cat_want, why, back])
	var civic_back: String = str(trip_results.get("civic", ""))
	var civic_table: Array = OsmServiceScript.get_loot_profile_for_category("civic")
	var civic_hit: bool = false
	for civ_id in civic_table:
		if civic_back.find(ShelterData.item_name(str(civ_id))) != -1:
			civic_hit = true
	_assert_cond(civic_back != "" and civic_hit, "A real 'civic' place stocks from the civic table: %s" % civic_back, "Civic trip didn't use the civic table: %s" % civic_back)

	# M1: a trip to a real church after the all-clear opens the neighbourhood rescue (it replaced the
	# old three-visit sanctuary counter).
	gs.call("reset_to_defaults")
	gs.set("selected_house", s_house)
	gs.set("nearby_pois", OsmServiceScript.build_nearby_targets_for_house(s_house, s_bldgs, s_pois))
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	BunkerSimScript.start_bunker_run()
	var shc: ShelterState = gs.get("shelter")
	shc.fallout_clear_day = 1
	var church_idx: int = -1
	for p_v in shc.places:
		if str((p_v as Dictionary)["category"]) == "church":
			church_idx = int((p_v as Dictionary)["idx"])
			break
	if church_idx >= 0:
		var mc: Dictionary = shc.members[0]
		ShelterTrips.launch(shc, mc, church_idx, [])
		for t_v in shc.trips:
			(t_v as Dictionary)["p_day"] = 0.0
		var g2: int = 0
		while str(mc.get("loc", "")) == "away" and g2 < 12:
			ShelterTrips.tick(shc)
			shc.day += 1
			g2 += 1
		ShelterChains.tick(shc)
		var nb_state: String = str((shc.chains["neighbourhood"] as Dictionary)["state"])
		_assert_cond(nb_state == "active",
			"A trip to a real church after the all-clear opens the neighbourhood rescue (%s)" % nb_state,
			"Church trip failed to open the neighbourhood rescue (state %s)" % nb_state)

	# Carried gear comes home unless the receipt says it broke or was lost (never swallowed or
	# overwritten), and anything found adds to it.
	gs.call("reset_to_defaults")
	gs.set("selected_house", s_house)
	gs.set("nearby_pois", OsmServiceScript.build_nearby_targets_for_house(s_house, s_bldgs, s_pois))
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	for gid in ["food", "water", "flashlight", "map", "suitcase", "gas_mask"]:
		gs.call("add_scavenged_item", gid, 3 if gid in ["food", "water"] else 1)
	BunkerSimScript.start_bunker_run()
	var shg: ShelterState = gs.get("shelter")
	var school_idx: int = -1
	for p_v in shg.places:
		if str((p_v as Dictionary)["category"]) in ["school", "grocery"]:
			school_idx = int((p_v as Dictionary)["idx"])
			break
	var swallowed: int = 0
	var trips_done: int = 0
	for _t in range(26):
		var mg: Dictionary = shg.members[0]
		mg["loc"] = "shelter"
		mg["alive"] = true
		mg["tired_until"] = 0
		var gear: Array = []
		for g in ["suitcase", "flashlight", "map", "gas_mask"]:
			if shg.has(g):
				gear.append(g)
		var pre: Dictionary = {}
		for g in ["suitcase", "flashlight", "map", "gas_mask"]:
			pre[g] = shg.count(g) + shg.broken_count(g)
		shg.receipt = []
		if ShelterTrips.launch(shg, mg, school_idx, gear) != "":
			continue
		for t_v in shg.trips:
			(t_v as Dictionary)["p_day"] = 0.0
		var g3: int = 0
		while str(mg.get("loc", "")) == "away" and g3 < 12:
			ShelterTrips.tick(shg)
			shg.day += 1
			g3 += 1
		trips_done += 1
		for g in gear:
			var lost: int = 0
			var found: int = 0
			for l_v in shg.receipt:
				var tx: String = str((l_v as Dictionary).get("text", ""))
				if tx.begins_with(ShelterData.item_name(str(g)) + " was lost"):
					lost += 1
				if (l_v as Dictionary).get("kind", "") == "return" and tx.find(ShelterData.item_name(str(g))) != -1:
					found += 1
			var post: int = shg.count(str(g)) + shg.broken_count(str(g))
			if post < int(pre[g]) - lost:
				swallowed += 1
	_assert_cond(
		trips_done >= 20 and swallowed == 0,
		"Carried gear (suitcase, flashlight, map, gas mask) comes home unless a receipt says it broke or was lost: 0 swallowed across %d trips" % trips_done,
		"Carried gear went missing without a receipt (%d cases over %d trips)" % [swallowed, trips_done]
	)


# ==============================================================================
# AUDIT 3: 50+ DIVERSE REAL OSM HOUSES -> 60S SCAVENGE FLOORPLAN REACHABILITY
# ==============================================================================
func _audit_3_floorplan_reachability(gs: Node, all_real_houses: Array) -> void:
	print("\n--- [3] 50+ REAL OSM HOUSES -> 60S FLOORPLAN & REACHABILITY AUDIT ---")

	var diverse_houses: Array = _select_55_diverse_osm_houses(all_real_houses)
	_assert_cond(
		diverse_houses.size() >= 50,
		"Selected %d diverse real-world OSM building footprints (tiny, huge, L-shaped, angled, narrow townhouses)" % diverse_houses.size(),
		"Only found %d real OSM houses (needed >= 50)" % diverse_houses.size()
	)

	gs.call("init_default_family")
	var family: Array = gs.get("family_members")
	var rng := RandomNumberGenerator.new()

	var houses_tested: int = 0
	var houses_all_reachable: int = 0
	var total_items_checked: int = 0
	var unreachable_items: int = 0
	var overlapping_items: int = 0
	var total_family_checked: int = 0
	var unreachable_family: int = 0
	var overlapping_family: int = 0
	var missing_manifest_houses: int = 0

	var items_outside_osm_poly: int = 0
	var rooms_outside_osm_poly: int = 0
	var furn_outside_osm_poly: int = 0
	var poly_area_mismatch_houses: int = 0
	var total_rooms_checked: int = 0
	var total_furn_checked: int = 0
	var houses_with_outside_spawns: int = 0
	var l_shape_count: int = 0
	var rect_shape_count: int = 0
	var obb_rotated_count: int = 0

	for idx in range(diverse_houses.size()):
		var h: Dictionary = diverse_houses[idx]
		rng.seed = 10000 + idx * 137
		var layout: Dictionary = HouseGeneratorScript.generate_from_osm_house(h, family, rng)
		houses_tested += 1

		var rooms: Array = layout.get("rooms", [])
		var walls: Array = layout.get("walls", [])
		var furniture: Array = layout.get("furniture", [])
		var items: Array = layout.get("items", [])
		var fam_spawns: Array = layout.get("family_spawns", [])
		var hatch_pos: Vector2 = layout.get("hatch_pos", Vector2.ZERO)
		var leader_pos: Vector2 = layout.get("leader_start_pos", Vector2.ZERO)
		var nav_grid: Dictionary = layout.get("nav_grid", {})
		var outer_poly: PackedVector2Array = layout.get("outer_polygon", PackedVector2Array())
		var obb_deg: float = absf(float(layout.get("obb_angle_deg", 0.0)))
		if obb_deg > 1.5:
			obb_rotated_count += 1

		var r_bounds: Rect2 = layout.get("interior_bounds", Rect2())
		var sum_room_area: float = 0.0
		var house_had_outside_spawn: bool = false

		# Pass 2: rooms are polygons (BSP cells clipped to the real outline), so they are checked as
		# polygons: every vertex inside the outline and the rooms tiling it (within 1 %).
		var outer_grown: PackedVector2Array = outer_poly
		var grown_list: Array = Geometry2D.offset_polygon(outer_poly, 1.5)
		if not grown_list.is_empty():
			outer_grown = grown_list[0]
		for r_v in rooms:
			var rpoly: PackedVector2Array = (r_v as Dictionary).get("polygon", PackedVector2Array())
			sum_room_area += _compute_packed_poly_area(rpoly)
			total_rooms_checked += 1
			var room_ok: bool = outer_poly.size() >= 3 and rpoly.size() >= 3
			for rpt in rpoly:
				if not Geometry2D.is_point_in_polygon(rpt, outer_grown):
					room_ok = false
					break
			if not room_ok:
				rooms_outside_osm_poly += 1
				house_had_outside_spawn = true

		var outer_area: float = _compute_packed_poly_area(outer_poly)
		if absf(outer_area - sum_room_area) > outer_area * 0.01:
			poly_area_mismatch_houses += 1
			house_had_outside_spawn = true

		if sum_room_area < r_bounds.size.x * r_bounds.size.y * 0.94:
			l_shape_count += 1
		else:
			rect_shape_count += 1

		for f_v in furniture:
			var fr: Rect2 = (f_v as Dictionary)["rect"]
			total_furn_checked += 1
			var fr_in: Rect2 = fr.grow(-0.5)
			var f_pts: Array[Vector2] = [
				fr.get_center(),
				fr_in.position,
				Vector2(fr_in.end.x, fr_in.position.y),
				fr_in.end,
				Vector2(fr_in.position.x, fr_in.end.y)
			]
			var furn_ok: bool = outer_poly.size() >= 4
			for fpt in f_pts:
				if not Geometry2D.is_point_in_polygon(fpt, outer_poly):
					furn_ok = false
					break
			if not furn_ok:
				furn_outside_osm_poly += 1
				house_had_outside_spawn = true

		var soup_n: int = 0
		var water_n: int = 0
		var gear_n: int = 0
		for it_v in items:
			var iid: String = str((it_v as Dictionary).get("item_id", ""))
			if iid == "food":
				soup_n += 1
			elif iid == "water":
				water_n += 1
			else:
				gear_n += 1
		# Pass 2 manifest: room count follows the real floor area (no fixed 6-room template),
		# every non-leader family member spawns, and scarcer food/water (5-8 each) by design.
		var open_rooms: int = 0
		for r_v in rooms:
			if not bool((r_v as Dictionary).get("sealed", false)):
				open_rooms += 1
		# M1: the house stock comes from data/loot_weights.csv ("home"): at least the table's minimum
		# food and water, every always-present item, and a handful of the chance items.
		var home_tbl: Dictionary = ShelterData.loot_for("home")
		var sure_missing: int = 0
		for k in home_tbl.keys():
			if float((home_tbl[k] as Dictionary).get("chance", 1.0)) >= 1.0 and str(k) != "food" and str(k) != "water":
				var found_k: bool = false
				for it2 in items:
					if str((it2 as Dictionary).get("item_id", "")) == str(k):
						found_k = true
				if not found_k:
					sure_missing += 1
		if soup_n < int((home_tbl["food"] as Dictionary)["min"]) or water_n < int((home_tbl["water"] as Dictionary)["min"]) or sure_missing > 0 or gear_n < 8 or fam_spawns.size() != family.size() - 1 or open_rooms < 2:
			missing_manifest_houses += 1
			print("    manifest #%d %.0fm2: soup=%d water=%d gear=%d fam=%d/%d open_rooms=%d" % [idx, float(h.get("area_sqm", 0.0)), soup_n, water_n, gear_n, fam_spawns.size(), family.size() - 1, open_rooms])

		var hatch_room_ok: bool = false
		for r_v in rooms:
			var rd: Dictionary = r_v
			if not bool(rd.get("sealed", false)) and Geometry2D.is_point_in_polygon(hatch_pos, rd.get("polygon", PackedVector2Array())):
				hatch_room_ok = true
		var hatch_ok: bool = hatch_room_ok and Geometry2D.is_point_in_polygon(hatch_pos, outer_poly) and not _circle_hits_walls_or_furn(hatch_pos, 18.0, walls, furniture)

		var house_clean: bool = hatch_ok
		var why: Array[String] = []
		if not hatch_ok:
			why.append("hatch(room=%s)" % str(hatch_room_ok))

		if not Geometry2D.is_point_in_polygon(leader_pos, outer_poly):
			house_had_outside_spawn = true
		if not _verify_continuous_walk_to_hatch(leader_pos, hatch_pos, nav_grid, walls, furniture):
			house_clean = false
			why.append("leader_walk")

		for it_v in items:
			var it: Dictionary = it_v
			var ipos: Vector2 = it["pos"]
			total_items_checked += 1
			if outer_poly.size() >= 3 and not Geometry2D.is_point_in_polygon(ipos, outer_poly):
				items_outside_osm_poly += 1
				house_had_outside_spawn = true
			if _circle_hits_walls_or_furn(ipos, 14.0, walls, furniture):
				overlapping_items += 1
				house_clean = false
				why.append("item_overlap")
			if not HouseGeneratorScript.is_walkable(nav_grid, ipos):
				unreachable_items += 1
				house_clean = false
				why.append("item_cell")
			elif not _verify_continuous_walk_to_hatch(ipos, hatch_pos, nav_grid, walls, furniture):
				unreachable_items += 1
				house_clean = false
				why.append("item_sweep")

		for fs_v in fam_spawns:
			var fs: Dictionary = fs_v
			var fpos: Vector2 = fs["pos"]
			total_family_checked += 1
			if outer_poly.size() >= 3 and not Geometry2D.is_point_in_polygon(fpos, outer_poly):
				items_outside_osm_poly += 1
				house_had_outside_spawn = true
			if _circle_hits_walls_or_furn(fpos, 14.0, walls, furniture):
				overlapping_family += 1
				house_clean = false
			if not HouseGeneratorScript.is_walkable(nav_grid, fpos) or not _verify_continuous_walk_to_hatch(fpos, hatch_pos, nav_grid, walls, furniture):
				unreachable_family += 1
				house_clean = false

		if house_had_outside_spawn:
			houses_with_outside_spawns += 1
		if house_clean:
			houses_all_reachable += 1
		else:
			_record_fail("House #%d (OSM #%d '%s', %.1f m²) failed reachability/collision check! %s" % [
				idx, int(h.get("osm_id", 0)), str(h.get("short_address", "")), float(h.get("area_sqm", 0.0)), str(why.slice(0, 4))
			])

	_assert_cond(
		missing_manifest_houses == 0,
		"All %d real OSM houses spawned >=2 open rooms, the table's minimum food and water, every always-present item, >=8 gear, and every non-leader family member" % houses_tested,
		"%d/%d houses had incomplete room/item/family manifests" % [missing_manifest_houses, houses_tested]
	)

	_assert_cond(
		houses_all_reachable == houses_tested and unreachable_items == 0 and unreachable_family == 0 and overlapping_items == 0 and overlapping_family == 0,
		"100%% Continuous Swept-Circle Walkability verified across %d OSM houses (%d items + %d family spawns tested: 0 wall/furniture overlaps, 0 unreachable spawns!)" % [
			houses_tested, total_items_checked, total_family_checked
		],
		"Walkability/overlap failures: %d/%d houses clean, unreachable_items=%d, overlap_items=%d, unreachable_fam=%d, overlap_fam=%d" % [
			houses_all_reachable, houses_tested, unreachable_items, overlapping_items, unreachable_family, overlapping_family
		]
	)

	_assert_cond(
		houses_with_outside_spawns == 0 and rooms_outside_osm_poly == 0 and furn_outside_osm_poly == 0
		and items_outside_osm_poly == 0 and poly_area_mismatch_houses == 0 and obb_rotated_count >= 10,
		"0/%d houses had rooms (%d), furniture (%d), items (%d), or family (%d) protruding outside orthogonal rooms-union outer_polygon (OBB aligned %d angled parcels; %d rect, %d L-wing)" % [
			houses_tested, total_rooms_checked, total_furn_checked, total_items_checked, total_family_checked,
			obb_rotated_count, rect_shape_count, l_shape_count
		],
		"Outer-polygon protrusion/mismatch: %d/%d houses failed (rooms_out=%d, furn_out=%d, spawns_out=%d, area_mismatch=%d, obb_rot=%d)" % [
			houses_with_outside_spawns, houses_tested, rooms_outside_osm_poly, furn_outside_osm_poly,
			items_outside_osm_poly, poly_area_mismatch_houses, obb_rotated_count
		]
	)

	# Edge-case small L-shaped footprints (14m x 11m) across ALL 4 notch quadrants (TL, TR, BL, BR)!
	var base_br_fp: Array[Vector2] = [
		Vector2(-7.0, -5.5),
		Vector2(7.0, -5.5),
		Vector2(7.0, 0.2),
		Vector2(1.0, 0.2),
		Vector2(1.0, 5.5),
		Vector2(-7.0, 5.5)
	]
	var overlap_rooms: int = 0
	var degenerate_rooms: int = 0
	var l_quads_clean: int = 0
	for q_idx in range(4):
		var sx_m: float = -1.0 if (q_idx == 0 or q_idx == 2) else 1.0
		var sy_m: float = -1.0 if (q_idx == 0 or q_idx == 1) else 1.0
		var q_fp: Array[Vector2] = []
		for v in base_br_fp:
			q_fp.append(Vector2(v.x * sx_m, v.y * sy_m))
		var min_l_house: Dictionary = {
			"osm_id": 777770 + q_idx,
			"short_address": "14x11m Min L-House Q%d" % q_idx,
			"area_sqm": 115.0,
			"footprint_meters": q_fp
		}
		rng.seed = 999 + q_idx
		var min_l_layout: Dictionary = HouseGeneratorScript.generate_from_osm_house(min_l_house, family, rng)
		var min_l_rooms: Array = min_l_layout.get("rooms", [])
		var min_l_poly: PackedVector2Array = min_l_layout.get("outer_polygon", PackedVector2Array())
		var min_l_nav: Dictionary = min_l_layout.get("nav_grid", {})
		var min_l_walls: Array = min_l_layout.get("walls", [])
		var min_l_furn: Array = min_l_layout.get("furniture", [])
		var min_l_hatch: Vector2 = min_l_layout.get("hatch_pos", Vector2.ZERO)
		var q_ok: bool = (min_l_rooms.size() >= 3 and min_l_poly.size() == 6)
		var q_area_sum: float = 0.0
		for i in range(min_l_rooms.size()):
			var rdi: Dictionary = min_l_rooms[i]
			var pi_poly: PackedVector2Array = rdi.get("polygon", PackedVector2Array())
			var a_i: float = _compute_packed_poly_area(pi_poly)
			q_area_sum += a_i
			if not bool(rdi.get("sealed", false)) and a_i < 4000.0:
				degenerate_rooms += 1
				q_ok = false
			for j in range(i + 1, min_l_rooms.size()):
				var pj_poly: PackedVector2Array = (min_l_rooms[j] as Dictionary).get("polygon", PackedVector2Array())
				var ov: float = 0.0
				for inter in Geometry2D.intersect_polygons(pi_poly, pj_poly):
					ov += _compute_packed_poly_area(inter)
				if ov > 50.0:
					overlap_rooms += 1
					q_ok = false
		if absf(_compute_packed_poly_area(min_l_poly) - q_area_sum) > _compute_packed_poly_area(min_l_poly) * 0.01:
			q_ok = false
		for it_v in min_l_layout.get("items", []):
			var ip: Vector2 = (it_v as Dictionary)["pos"]
			if not Geometry2D.is_point_in_polygon(ip, min_l_poly) or not _verify_continuous_walk_to_hatch(ip, min_l_hatch, min_l_nav, min_l_walls, min_l_furn):
				q_ok = false
		if q_ok:
			l_quads_clean += 1

	_assert_cond(
		l_quads_clean == 4 and overlap_rooms == 0 and degenerate_rooms == 0,
		"14m x 11m L-wing houses across all 4 notch quadrants (TL/TR/BL/BR) tile the outline with non-overlapping, non-degenerate rooms & exact 6-vertex outer_polygon",
		"14m x 11m L-wing check failed: quads_clean=%d/4, overlap_rooms=%d, degenerate_rooms=%d" % [
			l_quads_clean, overlap_rooms, degenerate_rooms
		]
	)


func _compute_packed_poly_area(poly: PackedVector2Array) -> float:
	var n: int = poly.size()
	if n < 3:
		return 0.0
	var acc: float = 0.0
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		acc += a.x * b.y - b.x * a.y
	return absf(acc) * 0.5


func _select_55_diverse_osm_houses(pool: Array) -> Array:
	if pool.size() <= 55:
		return pool.duplicate()

	var picked: Array = []
	var used_ids: Dictionary = {}

	var sorted_area_asc: Array = pool.duplicate()
	sorted_area_asc.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("area_sqm", 0.0)) < float(b.get("area_sqm", 0.0))
	)

	# 1. 10 Tiny houses
	for b in sorted_area_asc:
		if picked.size() >= 10:
			break
		var bid: int = int(b.get("osm_id", 0))
		if not used_ids.has(bid):
			used_ids[bid] = true
			picked.append(b)

	# 2. 10 Huge apartment / civic / multi-wing buildings
	for idx in range(sorted_area_asc.size() - 1, -1, -1):
		if picked.size() >= 20:
			break
		var b: Dictionary = sorted_area_asc[idx]
		var bid: int = int(b.get("osm_id", 0))
		if not used_ids.has(bid):
			used_ids[bid] = true
			picked.append(b)

	# 3. 12 Complex L-shaped / multi-vertex buildings
	var complex_sorted: Array = pool.duplicate()
	complex_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("footprint_meters", []) as Array).size() > (b.get("footprint_meters", []) as Array).size()
	)
	for b in complex_sorted:
		if picked.size() >= 32:
			break
		var bid: int = int(b.get("osm_id", 0))
		var vcnt: int = (b.get("footprint_meters", []) as Array).size()
		if not used_ids.has(bid) and vcnt >= 6:
			used_ids[bid] = true
			picked.append(b)

	# 4. 12 Narrow / angled Brooklyn brownstones & townhouses
	for b in pool:
		if picked.size() >= 44:
			break
		var bid: int = int(b.get("osm_id", 0))
		if not used_ids.has(bid) and str(b.get("_source", "")) == "brooklyn":
			used_ids[bid] = true
			picked.append(b)

	# 5. Fill remaining up to 55 across Concord, Seattle, and Live OSM
	var step: int = maxi(1, int(pool.size() / 20))
	var cursor: int = 0
	while picked.size() < 55 and cursor < pool.size():
		var b: Dictionary = pool[cursor]
		var bid: int = int(b.get("osm_id", 0))
		if not used_ids.has(bid):
			used_ids[bid] = true
			picked.append(b)
		cursor += step
	for b in pool:
		if picked.size() >= 55:
			break
		var bid: int = int(b.get("osm_id", 0))
		if not used_ids.has(bid):
			used_ids[bid] = true
			picked.append(b)

	return picked


func _circle_hits_walls_or_furn(pos: Vector2, radius: float, walls: Array, furniture: Array) -> bool:
	var r2: float = radius * radius
	for w_v in walls:
		var wd: Dictionary = w_v
		if wd.has("a"):
			# Pass 2 exterior walls are thick segments along the real outline.
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(pos, wd["a"], wd["b"])
			var lim: float = radius + float(wd.get("thickness", 16.0)) * 0.5
			if pos.distance_squared_to(cp) < lim * lim:
				return true
			continue
		var wr: Rect2 = wd["rect"]
		var cx: float = clampf(pos.x, wr.position.x, wr.end.x)
		var cy: float = clampf(pos.y, wr.position.y, wr.end.y)
		if pos.distance_squared_to(Vector2(cx, cy)) < r2:
			return true
	for f_v in furniture:
		var fd: Dictionary = f_v
		if not bool(fd.get("solid", true)):
			continue
		var fr: Rect2 = fd["rect"]
		var fx: float = clampf(pos.x, fr.position.x, fr.end.x)
		var fy: float = clampf(pos.y, fr.position.y, fr.end.y)
		if pos.distance_squared_to(Vector2(fx, fy)) < r2:
			return true
	return false


func _verify_continuous_walk_to_hatch(
	start_pos: Vector2,
	hatch_pos: Vector2,
	nav_grid: Dictionary,
	walls: Array,
	furniture: Array
) -> bool:
	var path: PackedVector2Array = HouseGeneratorScript.find_path(nav_grid, start_pos, hatch_pos)
	if path.size() < 2:
		return start_pos.distance_to(hatch_pos) <= 68.0

	var cur: Vector2 = path[0]
	if cur.distance_to(start_pos) > 36.0:
		return false

	for i in range(1, path.size()):
		var target: Vector2 = path[i]
		var dist: float = cur.distance_to(target)
		var steps: int = maxi(1, int(ceilf(dist / 4.0)))
		for s in range(1, steps + 1):
			var probe: Vector2 = cur.lerp(target, float(s) / float(steps))
			if _circle_hits_walls_or_furn(probe, 13.5, walls, furniture):
				return false
		cur = target

	return cur.distance_to(hatch_pos) <= 56.0


# ==============================================================================
# AUDIT 4: GLOBAL NUKE DETONATION PHYSICS & PROPAGATION (SCAVENGE + BUNKER)
# ==============================================================================
func _audit_4_nuke_physics_and_propagation(gs: Node) -> void:
	print("\n--- [4] GLOBAL NUKE DETONATION PHYSICS & PROPAGATION ---")

	var h_lat: float = 47.6242
	var h_lon: float = -122.3195

	# 4A. Test distances: Ground Zero (1 km), Metro (15 km), Regional (120 km), Global Antipode (8,000 km)
	var test_dists_km: Array[float] = [1.0, 15.0, 120.0, 8000.0]
	for d_km in test_dists_km:
		var pt: Dictionary = NukePhysicsScript.destination_point(h_lat, h_lon, 225.0, d_km)
		var n_lat: float = float(pt["lat"])
		var n_lon: float = float(pt["lon"])
		var calc_d: float = NukePhysicsScript.haversine_km(h_lat, h_lon, n_lat, n_lon)
		var rel_err: float = absf(calc_d - d_km) / d_km
		_assert_cond(
			rel_err < 0.002,
			"Haversine & destination_point round-trip at %.0f km -> %.3f km (err %.4f%%)" % [d_km, calc_d, rel_err * 100.0],
			"Haversine round-trip error at %.0f km: got %.3f km" % [d_km, calc_d]
		)

	# 4B. Test all 4 zones with 800 kt warhead (scale = 2.0)
	var gz_pt: Dictionary = NukePhysicsScript.destination_point(h_lat, h_lon, 225.0, 1.0)
	var metro_pt: Dictionary = NukePhysicsScript.destination_point(h_lat, h_lon, 225.0, 15.0)
	var reg_pt: Dictionary = NukePhysicsScript.destination_point(h_lat, h_lon, 225.0, 120.0)
	var glob_pt: Dictionary = NukePhysicsScript.destination_point(h_lat, h_lon, 225.0, 8000.0)

	var brng_gz_to_house_15: float = NukePhysicsScript.bearing_deg(float(metro_pt["lat"]), float(metro_pt["lon"]), h_lat, h_lon)
	var upwind_brng_15: float = NukePhysicsScript.normalize_deg(brng_gz_to_house_15 + 180.0)

	var imp_gz: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(gz_pt["lat"]), float(gz_pt["lon"]), 800, 45.0, "GZ 1km")
	var imp_metro_down: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(metro_pt["lat"]), float(metro_pt["lon"]), 800, brng_gz_to_house_15, "Metro 15km Downwind")
	var imp_metro_up: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(metro_pt["lat"]), float(metro_pt["lon"]), 800, upwind_brng_15, "Metro 15km Upwind")

	var brng_reg: float = NukePhysicsScript.bearing_deg(float(reg_pt["lat"]), float(reg_pt["lon"]), h_lat, h_lon)
	var imp_reg_down: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(reg_pt["lat"]), float(reg_pt["lon"]), 800, brng_reg, "Regional 120km Downwind")
	var imp_reg_up: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(reg_pt["lat"]), float(reg_pt["lon"]), 800, NukePhysicsScript.normalize_deg(brng_reg + 180.0), "Regional 120km Upwind")

	var imp_winter: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(glob_pt["lat"]), float(glob_pt["lon"]), 800, 90.0, "Global 8000km")

	_assert_cond(
		str(imp_gz["zone"]) == "ground_zero_edge"
		and str(imp_metro_down["zone"]) == "near_blast"
		and str(imp_reg_down["zone"]) == "regional_fallout"
		and str(imp_winter["zone"]) == "nuclear_winter",
		"4 Nuke Zones classified accurately: 1km=%s, 15km=%s, 120km=%s, 8000km=%s" % [
			str(imp_gz["zone"]), str(imp_metro_down["zone"]), str(imp_reg_down["zone"]), str(imp_winter["zone"])
		],
		"Zone classification mismatch across 1km/15km/120km/8000km"
	)

	_assert_cond(
		bool(imp_metro_down["in_fallout_plume"]) and not bool(imp_metro_up["in_fallout_plume"])
		and float(imp_metro_down["initial_sv_hr"]) > float(imp_metro_up["initial_sv_hr"])
		and float(imp_reg_down["initial_sv_hr"]) > float(imp_reg_up["initial_sv_hr"]),
		"Downwind vs Upwind fallout plume verified: Metro %.1f vs %.1f Sv/hr, Regional %.1f vs %.1f Sv/hr" % [
			float(imp_metro_down["initial_sv_hr"]), float(imp_metro_up["initial_sv_hr"]),
			float(imp_reg_down["initial_sv_hr"]), float(imp_reg_up["initial_sv_hr"])
		],
		"Downwind fallout plume failed to increase radiation Sv/hr"
	)

	# 4C. Test Warhead Yields (15 kt, 250 kt, 800 kt, 50,000 kt) & Plume Scaling in GZ + Nuclear Winter!
	var brng_gz_1km: float = NukePhysicsScript.bearing_deg(float(gz_pt["lat"]), float(gz_pt["lon"]), h_lat, h_lon)
	var upwind_gz_1km: float = NukePhysicsScript.normalize_deg(brng_gz_1km + 180.0)
	var imp_15kt_1km_up: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(gz_pt["lat"]), float(gz_pt["lon"]), 15, upwind_gz_1km)
	var imp_15kt_1km_down: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(gz_pt["lat"]), float(gz_pt["lon"]), 15, brng_gz_1km)
	var imp_50mt_1km_down: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(gz_pt["lat"]), float(gz_pt["lon"]), 50000, brng_gz_1km)

	var imp_15kt_8000km: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(glob_pt["lat"]), float(glob_pt["lon"]), 15, 45.0)
	var imp_250kt_8000km: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(glob_pt["lat"]), float(glob_pt["lon"]), 250, 45.0)
	var imp_800kt_8000km: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(glob_pt["lat"]), float(glob_pt["lon"]), 800, 45.0)
	var imp_50mt_8000km: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(glob_pt["lat"]), float(glob_pt["lon"]), 50000, 45.0)
	var imp_50mt_120km: Dictionary = NukePhysicsScript.compute_impact(h_lat, h_lon, float(reg_pt["lat"]), float(reg_pt["lon"]), 50000, brng_reg)

	_assert_cond(
		float(imp_50mt_1km_down["blast_5psi_radius_km"]) > float(imp_15kt_1km_up["blast_5psi_radius_km"]) * 14.0
		and str(imp_50mt_120km["zone"]) == "near_blast",
		"Cube-root blast radius scaling verified: 15kt 5psi=%.2fkm vs 50,000kt 5psi=%.2fkm (120km shifts to '%s' under 50Mt)" % [
			float(imp_15kt_1km_up["blast_5psi_radius_km"]), float(imp_50mt_1km_down["blast_5psi_radius_km"]), str(imp_50mt_120km["zone"])
		],
		"Warhead yield cube-root scaling failed"
	)

	_assert_cond(
		is_equal_approx(float(imp_15kt_1km_up["bunker_temp_c"]), 30.0)
		and is_equal_approx(float(imp_50mt_1km_down["bunker_temp_c"]), 36.0)
		and float(imp_15kt_1km_down["initial_sv_hr"]) > float(imp_15kt_1km_up["initial_sv_hr"]) + 1.5
		and float(imp_50mt_1km_down["initial_sv_hr"]) > float(imp_15kt_1km_down["initial_sv_hr"]) + 4.0
		and float(imp_50mt_1km_down["structural_damage"]) > float(imp_15kt_1km_up["structural_damage"]),
		"Ground Zero Edge scales continuously with yield_kt & in_fallout_plume: 15kt upwind=(+%.1fC, %.1f Sv/hr), 15kt downwind=%.1f Sv/hr, 50Mt downwind=(+%.1fC, %.1f Sv/hr)" % [
			float(imp_15kt_1km_up["bunker_temp_c"]), float(imp_15kt_1km_up["initial_sv_hr"]),
			float(imp_15kt_1km_down["initial_sv_hr"]),
			float(imp_50mt_1km_down["bunker_temp_c"]), float(imp_50mt_1km_down["initial_sv_hr"])
		],
		"Ground Zero Edge failed to scale with yield_kt or in_fallout_plume"
	)

	_assert_cond(
		float(imp_15kt_8000km["bunker_temp_c"]) > 7.0
		and float(imp_250kt_8000km["bunker_temp_c"]) < float(imp_15kt_8000km["bunker_temp_c"]) - 5.0
		and float(imp_800kt_8000km["bunker_temp_c"]) < -9.0
		and float(imp_50mt_8000km["bunker_temp_c"]) < float(imp_800kt_8000km["bunker_temp_c"]) - 6.0,
		"Distant Global Detonation scales across yields: 15kt=%+.1fC ('%s'), 250kt=%+.1fC ('%s'), 800kt=%+.1fC, 50Mt=%+.1fC" % [
			float(imp_15kt_8000km["bunker_temp_c"]), str(imp_15kt_8000km["zone_title"]),
			float(imp_250kt_8000km["bunker_temp_c"]), str(imp_250kt_8000km["zone_title"]),
			float(imp_800kt_8000km["bunker_temp_c"]), float(imp_50mt_8000km["bunker_temp_c"])
		],
		"Distant Global Detonation failed to scale temperature with yield_kt"
	)

	# 4D. Verify Propagation into ScavengeScene (scout_seconds & tremor_intensity)
	gs.set("demo_mode", false)
	gs.set("nuke_config", imp_gz.duplicate(true))
	var scav_gz: Node2D = ScavengeSceneScript.new()
	root.add_child(scav_gz)
	await _wait_frames(2)
	var gz_scout_sec: float = float(scav_gz.get("_scout_total"))
	scav_gz.set("_phase", 1) # Phase.SCAVENGE
	scav_gz.set("_shake_strength", 0.0)
	scav_gz.set("_scavenge_time_left", 0.5)
	var gz_cam_offset_max: float = 0.0
	for _s in range(25):
		scav_gz.call("_update_camera", 0.016)
		var cam_gz: Camera2D = scav_gz.get("_camera")
		gz_cam_offset_max = maxf(gz_cam_offset_max, cam_gz.offset.length())
	scav_gz.queue_free()
	await _wait_frames(2)

	gs.set("nuke_config", imp_winter.duplicate(true))
	var scav_win: Node2D = ScavengeSceneScript.new()
	root.add_child(scav_win)
	await _wait_frames(2)
	var win_scout_sec: float = float(scav_win.get("_scout_total"))
	scav_win.set("_phase", 1) # Phase.SCAVENGE
	scav_win.set("_shake_strength", 0.0)
	scav_win.set("_scavenge_time_left", 0.5)
	var win_cam_offset_max: float = 0.0
	for _s in range(25):
		scav_win.call("_update_camera", 0.016)
		var cam_win: Camera2D = scav_win.get("_camera")
		win_cam_offset_max = maxf(win_cam_offset_max, cam_win.offset.length())
	scav_win.queue_free()
	await _wait_frames(2)

	# M1 (section 3): the recon look-around follows the difficulty (Story 20 s, Normal 10 s, Hard 3 s),
	# not the strike zone; the tremor still follows the strike.
	_assert_cond(
		is_equal_approx(gz_scout_sec, float(gs.call("recon_seconds"))) and is_equal_approx(win_scout_sec, float(gs.call("recon_seconds"))) and gz_cam_offset_max > win_cam_offset_max * 4.0,
		"ScavengeScene: recon follows difficulty (GZ %.1fs, tremor %.2fpx; winter %.1fs, tremor %.2fpx)" % [
			gz_scout_sec, gz_cam_offset_max, win_scout_sec, win_cam_offset_max
		],
		"ScavengeScene failed to apply scout_seconds or tremor_intensity (gz_scout=%.1f, win_scout=%.1f, gz_shake=%.2f, win_shake=%.2f)" % [
			gz_scout_sec, win_scout_sec, gz_cam_offset_max, win_cam_offset_max
		]
	)

	# 4E. Verify Hull Integrity % alignment across ALL 4 zones + Scorching/Warm Bunker Thirst + Nuclear Winter Freeze!
	var hull_aligned_zones: int = 0
	for z_imp in [imp_gz, imp_metro_down, imp_reg_down, imp_winter]:
		gs.call("reset_to_defaults")
		gs.set("nuke_config", (z_imp as Dictionary).duplicate(true))
		for m in gs.get("family_members"):
			m["in_bunker"] = true
			m["alive"] = true
		BunkerSimScript.start_bunker_run()
		var sim_integ_pct: int = int(round(float(gs.get("bunker_structural_integrity"))))
		var forecast_integ_pct: int = int((z_imp as Dictionary).get("hull_integrity_pct", -1))
		var bullets_str: String = " | ".join((z_imp as Dictionary).get("condition_bullets", []))
		if sim_integ_pct == forecast_integ_pct and bullets_str.find("%d%% shelter integrity" % forecast_integ_pct) != -1:
			hull_aligned_zones += 1

	_assert_cond(
		hull_aligned_zones == 4,
		"Hull integrity %% in NukePhysics forecast bullets matches BunkerSim.bunker_structural_integrity across all 4 zones (GZ=%d%%, Metro=%d%%, Reg=%d%%, Winter=%d%%)" % [
			int(imp_gz["hull_integrity_pct"]), int(imp_metro_down["hull_integrity_pct"]),
			int(imp_reg_down["hull_integrity_pct"]), int(imp_winter["hull_integrity_pct"])
		],
		"Hull integrity mismatch between NukePhysics and BunkerSim (%d/4 zones aligned)" % hull_aligned_zones
	)

	# Run 1: +32.9 C Scorching Bunker (GZ 800kt) — advance 3 dry days
	gs.call("reset_to_defaults")
	gs.set("nuke_config", imp_gz.duplicate(true))
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	BunkerSimScript.start_bunker_run()
	var gz_day1_sv: float = float(gs.get("surface_radiation_sv"))
	gs.get("rng").seed = 55555
	for _d in range(3):
		BunkerSimScript.advance_day({}, "")
	var gz_m0: Dictionary = gs.get("family_members")[0]
	var gz_thirst_3d: int = int(gz_m0.get("thirst", 0))
	var gz_dww_3d: int = int(gz_m0.get("dww", 0))
	var gz_day4_sv: float = float(gs.get("surface_radiation_sv"))

	# Run 2: +25.0 C Warm Metro Bunker — advance 3 dry days
	gs.call("reset_to_defaults")
	gs.set("nuke_config", imp_metro_up.duplicate(true))
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	BunkerSimScript.start_bunker_run()
	gs.get("rng").seed = 55555
	for _d in range(3):
		BunkerSimScript.advance_day({}, "")
	var warm_m0: Dictionary = gs.get("family_members")[0]
	var warm_thirst_3d: int = int(warm_m0.get("thirst", 0))
	var warm_dww_3d: int = int(warm_m0.get("dww", 0))

	# Run 3: Cool Regional Fallout (+11.0 C, 2.6 Sv/hr) — advance 3 dry days with identical seed
	gs.call("reset_to_defaults")
	gs.set("nuke_config", imp_reg_up.duplicate(true))
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	BunkerSimScript.start_bunker_run()
	gs.get("rng").seed = 55555
	for _d in range(3):
		BunkerSimScript.advance_day({}, "")
	var reg_m0: Dictionary = gs.get("family_members")[0]
	var reg_thirst_3d: int = int(reg_m0.get("thirst", 0))
	var reg_dww_3d: int = int(reg_m0.get("dww", 0))

	_assert_cond(
		gz_thirst_3d > reg_thirst_3d and gz_dww_3d > reg_dww_3d
		and warm_thirst_3d > reg_thirst_3d and warm_dww_3d > reg_dww_3d,
		"Scorching (+%.1f C) & Warm (+25.0 C) bunker heat accelerates thirst in BunkerSim: 3 dry days -> thirst=%d/%d (dww=%d/%d) vs Cool +11C thirst=%d (dww=%d)" % [
			float(imp_gz["bunker_temp_c"]), gz_thirst_3d, warm_thirst_3d, gz_dww_3d, warm_dww_3d, reg_thirst_3d, reg_dww_3d
		],
		"Bunker heat failed to accelerate thirst (gz=%d/%d, warm=%d/%d, cool=%d/%d)" % [
			gz_thirst_3d, gz_dww_3d, warm_thirst_3d, warm_dww_3d, reg_thirst_3d, reg_dww_3d
		]
	)

	# Run 3: Global Nuclear Winter (-11.7 C, 0.45 Sv/hr) — verify sub-zero freeze & cold sickness!
	gs.call("reset_to_defaults")
	gs.set("nuke_config", imp_winter.duplicate(true))
	for m in gs.get("family_members"):
		m["in_bunker"] = true
		m["alive"] = true
	BunkerSimScript.start_bunker_run()
	var win_day1_temp: float = float(gs.get("bunker_temp_c"))
	var win_day1_sv: float = float(gs.get("surface_radiation_sv"))
	gs.get("rng").seed = 77777
	var cold_sickness_triggered: bool = false
	for _d in range(6):
		var sh: ShelterState = gs.get("shelter")
		sh.add("water", maxi(0, 20 - sh.water()))
		var rplan: Dictionary = {"rations": {
			"member_0": {"water": true, "food": false},
			"member_1": {"water": true, "food": false},
			"member_2": {"water": true, "food": false},
			"member_3": {"water": true, "food": false}
		}, "treat": {}, "jobs": {}}
		BunkerSimScript.advance_day(rplan, "")
		for m in gs.get("family_members"):
			if int((m as Dictionary).get("sickness", 0)) >= 1:
				cold_sickness_triggered = true

	var win_day7_temp: float = float(gs.get("bunker_temp_c"))
	_assert_cond(
		gz_day1_sv > 9.0 and gz_day4_sv < gz_day1_sv
		and win_day1_sv < 0.6 and win_day1_temp < -10.0 and win_day7_temp <= -14.0 and cold_sickness_triggered,
		"BunkerSim Nuclear Winter & Fallout physics verified: GZ Sv/hr decayed %.2f -> %.2f; Nuclear Winter plunged %.1f C -> %.1f C and triggered freezing sickness!" % [
			gz_day1_sv, gz_day4_sv, win_day1_temp, win_day7_temp
		],
		"BunkerSim Nuclear Winter / Fallout failed (gz_sv=%.2f->%.2f, win_temp=%.1f->%.1f, cold_sick=%s)" % [
			gz_day1_sv, gz_day4_sv, win_day1_temp, win_day7_temp, str(cold_sickness_triggered)
		]
	)
