extends SceneTree

## V2 Multi-Ring (0-10 km) OpenStreetMap, 9-Category Landmark Gameplay & 3D Isometric Geospatial Audit
## Run with:
## /home/antigravity/.local/bin/godot --headless --path /home/antigravity/sixty_seconds_world -s res://tests/v2_osm_3d_audit.gd

var pass_count: int = 0
var fail_count: int = 0
var warn_count: int = 0
var defect_log: Array[String] = []
var info_log: Array[String] = []

# Async HTTP tracking for live Nominatim + OSM 0.6 + Wide-Area Multi-Ring POI scanner + Slippy Tiles
var _search_done: bool = false
var _search_err: String = ""
var _search_results: Array = []
var _map_done: bool = false
var _map_err: String = ""
var _map_parsed: Dictionary = {}
var _map_label: String = ""
var _wide_merges: int = 0
var _wide_pois_latest: Array = []
var _wide_ready_status: bool = false

# Loaded Script Classes
var OsmServiceScript: GDScript
var OsmSlippyMapScript: GDScript
var HouseSelectScreenScript: GDScript
var ExpeditionEngineScript: GDScript
var HouseGeneratorScript: GDScript
var House3DBuilderScript: GDScript
var ScavengeSceneScript: GDScript
var NukePhysicsScript: GDScript
var BunkerSimScript: GDScript
var BunkerSceneScript: GDScript
var RelationshipSystemScript: GDScript

const ALL_9_CATEGORIES: Array[String] = [
	"neighbor_house", "grocery", "doctor", "pharmacy",
	"fuel_auto", "hardware", "civic", "church", "school"
]

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
	print("========================================================================================")
	print("V2 CRITIC AUDIT: MULTI-RING OSM (0-10KM), 9 LANDMARK ARCHETYPES & 3D ISOMETRIC GEOSPATIAL")
	print("========================================================================================")

	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		_record_fail("scripts/core/game_state.gd:1 GameState autoload missing from SceneTree root!")
		quit(0)
		return
	gs.set("demo_mode", false)
	gs.set("headless_fast_test", false)

	OsmServiceScript = load("res://scripts/osm/osm_service.gd")
	OsmSlippyMapScript = load("res://scripts/osm/osm_slippy_map.gd")
	HouseSelectScreenScript = load("res://scripts/ui/house_select_screen.gd")
	ExpeditionEngineScript = load("res://scripts/expedition/expedition_engine.gd")
	HouseGeneratorScript = load("res://scripts/scavenge/house_generator.gd")
	House3DBuilderScript = load("res://scripts/scavenge/house_3d_builder.gd")
	ScavengeSceneScript = load("res://scripts/scavenge/scavenge_scene.gd")
	NukePhysicsScript = load("res://scripts/nuke/nuke_physics.gd")
	BunkerSimScript = load("res://scripts/bunker/bunker_sim.gd")
	BunkerSceneScript = load("res://scripts/bunker/bunker_scene.gd")
	RelationshipSystemScript = load("res://scripts/family/relationship_system.gd")

	_assert_cond(
		OsmServiceScript != null and OsmSlippyMapScript != null and HouseSelectScreenScript != null
		and ExpeditionEngineScript != null and HouseGeneratorScript != null and House3DBuilderScript != null
		and ScavengeSceneScript != null and NukePhysicsScript != null and BunkerSimScript != null
		and BunkerSceneScript != null and RelationshipSystemScript != null,
		"All 11 V2 geospatial, expedition, bunker & 3D house GDScript modules compiled cleanly",
		"One or more target GDScript modules failed to compile!"
	)

	# Section 1: Wyndham 6217 Walborough Ct + Seattle/Concord/Brooklyn + Live HTTP Multi-Ring OSM Audit
	var diverse_houses: Array = await _audit_1_wyndham_and_multiring_osm(gs)

	# Section 2: All 9 Landmark Categories Gameplay Differentiation Across Rings 1, 2 & 3
	await _audit_2_nine_landmark_categories_gameplay(gs)

	# Section 3: True 3D Isometric House, Cutaway Walls, 28 Real OSM Houses, Drill & Left-Behind + Nuke Physics
	await _audit_3_house_3d_and_scavenge(gs, diverse_houses)

	print("\n========================================================================================")
	var verdict: String = "PASS" if fail_count == 0 else "FAIL"
	print("VERDICT: %s  |  %d PASSED  |  %d FAILED  |  %d NOTES" % [verdict, pass_count, fail_count, warn_count])
	print("========================================================================================")
	for idx in range(defect_log.size()):
		print("  DEFECT %d: %s" % [idx + 1, defect_log[idx]])
	for idx in range(info_log.size()):
		print("  NOTE   %d: %s" % [idx + 1, info_log[idx]])
	print("V2_OSM_3D_AUDIT_COMPLETE")
	await _wait_frames(3)
	quit(0)


# ==============================================================================================
# SECTION 1: 6217 WALBOROUGH COURT (WYNDHAM, VA) + PRESETS + LIVE MULTI-RING OSM INTEGRATION
# ==============================================================================================
func _audit_1_wyndham_and_multiring_osm(gs: Node) -> Array:
	print("\n--- [SECTION 1] 6217 WALBOROUGH COURT (WYNDHAM, VA) SUBURBAN CUL-DE-SAC & MULTI-RING OSM ---")
	var sampled_houses: Array = []

	# 1A. Deep audit of "wyndham" preset (6217 Walborough Court, osm_id = 706121395) vs V1 image.png
	var wyndham: Dictionary = OsmServiceScript.load_preset("wyndham")
	var w_bldgs: Array = wyndham.get("buildings", [])
	var w_pois: Array = wyndham.get("pois", [])
	var w_roads: Array = wyndham.get("roads", [])
	var w_synth: bool = bool(wyndham.get("synthesized_rural", true))
	var w_pref_id: int = int(wyndham.get("preferred_osm_id", -1))
	var w_label: String = str(wyndham.get("label", ""))

	_assert_cond(
		not w_synth and w_pref_id == 706121395 and w_bldgs.size() >= 200 and w_pois.size() >= 35 and w_roads.size() >= 15,
		"Wyndham preset loaded authentic OSM neighborhood: %d buildings, %d multi-ring POIs, %d roads (preferred_osm_id=%d)" % [
			w_bldgs.size(), w_pois.size(), w_roads.size(), w_pref_id
		],
		"osm_service.gd:36-44 Wyndham preset failed or lacked real multi-ring POIs (synth=%s, bldgs=%d, pois=%d)" % [
			str(w_synth), w_bldgs.size(), w_pois.size()
		]
	)

	var walborough_house: Dictionary = OsmServiceScript.pick_best_house(
		w_bldgs,
		float(wyndham.get("center_lat", 37.7085)),
		float(wyndham.get("center_lon", -77.6077)),
		w_pref_id
	)
	_assert_cond(
		int(walborough_house.get("osm_id", 0)) == 706121395
		and str(walborough_house.get("short_address", "")) == "6217 Walborough Court",
		"Selected exact V1 reference house: '%s' (osm_id=%d, %.5f, %.5f, %.1f m²)" % [
			str(walborough_house.get("name", "")),
			int(walborough_house.get("osm_id", 0)),
			float(walborough_house.get("lat", 0.0)),
			float(walborough_house.get("lon", 0.0)),
			float(walborough_house.get("area_sqm", 0.0))
		],
		"osm_service.gd:1069 pick_best_house failed to resolve 6217 Walborough Court (osm_id=706121395): got %s" % str(walborough_house)
	)

	# Check raw Wyndham POIs for real Short Pump / Wyndham / Glen Allen chains
	var all_w_poi_names: String = ""
	for wp_v in w_pois:
		var wp: Dictionary = wp_v
		all_w_poi_names += str(wp.get("name", "")) + " | "

	var expected_real_wyndham_brands: Array[Dictionary] = [
		{"sub": "Kroger", "desc": "Grocery (Kroger)"},
		{"sub": "Publix", "desc": "Grocery (Publix)"},
		{"sub": "Vera Whole Health", "desc": "Doctor/Clinic (Vera Whole Health)"},
		{"sub": "Concentra Urgent Care", "desc": "Doctor/Clinic (Concentra Urgent Care)"},
		{"sub": "CVS", "desc": "Pharmacy (CVS)"},
		{"sub": "Wawa", "desc": "Gas/Auto (Wawa)"},
		{"sub": "Sheetz", "desc": "Gas/Auto (Sheetz)"},
		{"sub": "Rockler", "desc": "Hardware (Rockler Woodworking and Hardware)"},
		{"sub": "Fire Station", "desc": "Police/Fire (Henrico Fire Station)"},
		{"sub": "Church", "desc": "Church (Mount Vernon / Saint Matthews)"},
		{"sub": "High School", "desc": "School (Deep Run / Glen Allen High School)"}
	]
	for brand in expected_real_wyndham_brands:
		var b_sub: String = str(brand["sub"])
		_assert_cond(
			all_w_poi_names.findn(b_sub) != -1,
			"Wyndham OSM dataset contains real %s" % str(brand["desc"]),
			"data/osm_presets/wyndham_walborough_va.json missing expected real POI '%s'" % b_sub
		)

	# Build multi-ring nearby targets for 6217 Walborough Court and compare against V1 (only 8 houses <= 48m!)
	var w_targets: Array = OsmServiceScript.build_nearby_targets_for_house(walborough_house, w_bldgs, w_pois, w_label)
	var w_ring_counts: Dictionary = {1: 0, 2: 0, 3: 0}
	var w_cat_counts: Dictionary = {}
	var w_synth_target_count: int = 0
	var w_max_dist_m: int = 0
	var w_target_names: Array[String] = []

	for t_v in w_targets:
		var t: Dictionary = t_v
		var r_id: int = int(t.get("ring", 0))
		var c_id: String = str(t.get("category", ""))
		var d_m: int = int(t.get("distance_m", 0))
		w_ring_counts[r_id] = int(w_ring_counts.get(r_id, 0)) + 1
		w_cat_counts[c_id] = int(w_cat_counts.get(c_id, 0)) + 1
		if bool(t.get("synthesized", false)):
			w_synth_target_count += 1
		w_max_dist_m = maxi(w_max_dist_m, d_m)
		w_target_names.append("[R%d %s %dm %s] %s" % [
			r_id, c_id, d_m, str(t.get("bearing_dir", "")), str(t.get("name", ""))
		])

	print("  -> 6217 Walborough Ct Multi-Ring Targets (%d total, max %dm):" % [w_targets.size(), w_max_dist_m])
	for tn in w_target_names:
		print("     • " + tn)

	_assert_cond(
		w_targets.size() >= 24
		and int(w_ring_counts[1]) >= 6
		and int(w_ring_counts[2]) >= 2
		and int(w_ring_counts[3]) >= 6
		and w_max_dist_m >= 3800
		and w_max_dist_m <= 9500,
		"6217 Walborough Ct upgraded from V1's 8 cul-de-sac houses (48m) -> %d Multi-Ring targets (R1=%d, R2=%d, R3=%d, max=%dm)" % [
			w_targets.size(), int(w_ring_counts[1]), int(w_ring_counts[2]), int(w_ring_counts[3]), w_max_dist_m
		],
		"osm_service.gd:699 build_nearby_targets_for_house failed multi-ring distribution for 6217 Walborough Ct: R1=%d, R2=%d, R3=%d, max=%dm" % [
			int(w_ring_counts[1]), int(w_ring_counts[2]), int(w_ring_counts[3]), w_max_dist_m
		]
	)

	var missing_w_cats: Array[String] = []
	for req_cat in ALL_9_CATEGORIES:
		if int(w_cat_counts.get(req_cat, 0)) <= 0:
			missing_w_cats.append(req_cat)

	_assert_cond(
		missing_w_cats.is_empty() and w_synth_target_count == 0,
		"6217 Walborough Ct has 100%% REAL OpenStreetMap targets across all 9 categories (%s) with 0 synthetic fallbacks" % str(w_cat_counts),
		"osm_service.gd:776 Missing categories %s or unexpected synthesized=%d on Wyndham preset" % [str(missing_w_cats), w_synth_target_count]
	)

	var w_mods: Dictionary = OsmServiceScript.compute_neighborhood_modifiers(w_targets)
	_assert_cond(
		str(w_mods.get("archetype", "")) == "Suburban Cul-de-Sac"
		and float(w_mods.get("early_raider_mod", 0.0)) < 0.0,
		"Neighborhood analyzer classified 6217 Walborough Ct as '%s' (early_raider_mod=%.2f, headline='%s')" % [
			str(w_mods.get("archetype", "")),
			float(w_mods.get("early_raider_mod", 0.0)),
			str(w_mods.get("headline", ""))
		],
		"osm_service.gd:912 compute_neighborhood_modifiers failed Suburban Cul-de-Sac classification: %s" % str(w_mods)
	)

	# Verify BunkerScene Tab 4 (_ExpeditionRadarMap) renders all multi-ring pins for 6217 Walborough Ct
	gs.call("reset_to_defaults")
	gs.set("selected_house", walborough_house.duplicate(true))
	gs.set("nearby_pois", w_targets.duplicate(true))
	gs.set("neighborhood_modifiers", w_mods.duplicate(true))
	for m_v in gs.get("family_members"):
		var md: Dictionary = m_v
		md["in_bunker"] = true
		md["alive"] = true
	BunkerSimScript.start_bunker_run()

	var bunker_ui: Control = BunkerSceneScript.new()
	bunker_ui.size = Vector2(1280.0, 720.0)
	root.add_child(bunker_ui)
	await _wait_frames(2)
	bunker_ui.call("set_active_tab", 3) # TAB_EXPEDITION (4. OSM RADAR)
	await _wait_frames(2)
	var radar_widget: Control = bunker_ui.get("_radar_map_widget")
	var radar_targets: Array = radar_widget.get("targets") if is_instance_valid(radar_widget) else []
	_assert_cond(
		is_instance_valid(radar_widget) and radar_targets.size() == w_targets.size(),
		"BunkerScene Tab 4 ('4. OSM RADAR') binds all %d Multi-Ring Wyndham targets onto _ExpeditionRadarMap" % radar_targets.size(),
		"bunker_scene.gd:1687 _ExpeditionRadarMap failed to bind Wyndham multi-ring targets!"
	)
	bunker_ui.queue_free()
	await _wait_frames(2)

	# Collect 7 diverse houses from Wyndham (starting with 6217 Walborough Ct)
	sampled_houses.append(_tag_house(walborough_house, "wyndham_6217_walborough"))
	for i in range(mini(6, w_bldgs.size())):
		var wb: Dictionary = w_bldgs[(i * 37 + 5) % w_bldgs.size()]
		if int(wb.get("osm_id", 0)) != 706121395:
			sampled_houses.append(_tag_house(wb, "wyndham"))

	# 1B. Audit Seattle, Concord, and Brooklyn presets + HouseSelectScreen + OsmSlippyMap parcel clicking
	for pid in ["seattle", "concord", "brooklyn"]:
		var parsed: Dictionary = OsmServiceScript.load_preset(pid)
		var bldgs: Array = parsed.get("buildings", [])
		var pois: Array = parsed.get("pois", [])
		var pref_id: int = int(parsed.get("preferred_osm_id", -1))
		var lbl: String = str(parsed.get("label", pid))
		var best_h: Dictionary = OsmServiceScript.pick_best_house(
			bldgs,
			float(parsed.get("center_lat", 0.0)),
			float(parsed.get("center_lon", 0.0)),
			pref_id
		)
		var targets: Array = OsmServiceScript.build_nearby_targets_for_house(best_h, bldgs, pois, lbl)
		var r_cnts: Dictionary = {1: 0, 2: 0, 3: 0}
		var c_cnts: Dictionary = {}
		var dist_math_ok: bool = true
		for tv in targets:
			var td: Dictionary = tv
			var r_i: int = int(td.get("ring", 0))
			var dm: int = int(td.get("distance_m", 0))
			r_cnts[r_i] = int(r_cnts.get(r_i, 0)) + 1
			c_cnts[str(td.get("category", ""))] = int(c_cnts.get(str(td.get("category", "")), 0)) + 1
			var exp_r: int = 1 if dm < 500 else (2 if dm < 3500 else 3)
			if r_i != exp_r:
				dist_math_ok = false
			var h_km: float = NukePhysicsScript.haversine_km(
				float(best_h.get("lat", 0.0)), float(best_h.get("lon", 0.0)),
				float(td.get("lat", 0.0)), float(td.get("lon", 0.0))
			)
			if absf(h_km * 1000.0 - float(dm)) > maxf(25.0, float(dm) * 0.04):
				dist_math_ok = false

		var all_9_present: bool = true
		for rc_k in ALL_9_CATEGORIES:
			if int(c_cnts.get(rc_k, 0)) <= 0:
				all_9_present = false

		_assert_cond(
			int(best_h.get("osm_id", 0)) == pref_id
			and bldgs.size() >= 150
			and int(r_cnts[1]) >= 6
			and int(r_cnts[2]) >= 3
			and int(r_cnts[3]) >= 2
			and all_9_present
			and dist_math_ok,
			"Preset '%s' (%s): %d bldgs, %d POIs -> %d targets (R1=%d, R2=%d, R3=%d), all 9 categories & exact ring/meter math" % [
				pid, str(best_h.get("short_address", "")), bldgs.size(), pois.size(),
				targets.size(), int(r_cnts[1]), int(r_cnts[2]), int(r_cnts[3])
			],
			"osm_service.gd:160 Preset '%s' failed multi-ring/9-category check (R1=%d, R2=%d, R3=%d, cats=%s, math_ok=%s)" % [
				pid, int(r_cnts[1]), int(r_cnts[2]), int(r_cnts[3]), str(c_cnts), str(dist_math_ok)
			]
		)

		sampled_houses.append(_tag_house(best_h, pid))
		for k in range(5):
			var sb: Dictionary = bldgs[(k * 41 + 11) % bldgs.size()]
			if int(sb.get("osm_id", 0)) != pref_id:
				sampled_houses.append(_tag_house(sb, pid))

	# Test HouseSelectScreen + OsmSlippyMap interactive polygon clicking & ring filtering
	var hs_screen: Control = HouseSelectScreenScript.new()
	hs_screen.size = Vector2(1280.0, 720.0)
	root.add_child(hs_screen)
	await _wait_frames(3)
	hs_screen.call("_load_preset_neighborhood", "wyndham", false)
	await _wait_frames(2)
	var slippy: Control = hs_screen.get("_slippy_map")
	var alt_wyndham_bldg: Dictionary = {}
	for wb_v in w_bldgs:
		var wb_d: Dictionary = wb_v
		if int(wb_d.get("osm_id", 0)) != 706121395 and bool(wb_d.get("is_residential", false)):
			alt_wyndham_bldg = wb_d
			break
	if is_instance_valid(slippy) and not alt_wyndham_bldg.is_empty():
		slippy.emit_signal("house_clicked", alt_wyndham_bldg)
		await _wait_frames(2)
		var gs_sel: Dictionary = gs.get("selected_house")
		var gs_pois: Array = gs.get("nearby_pois")
		_assert_cond(
			int(gs_sel.get("osm_id", 0)) == int(alt_wyndham_bldg.get("osm_id", -1)) and gs_pois.size() >= 20,
			"Clicking neighbor parcel '%s' (osm_id=%d) on OsmSlippyMap updates GameState.selected_house & rebuilds %d multi-ring POIs" % [
				str(gs_sel.get("short_address", "")), int(gs_sel.get("osm_id", 0)), gs_pois.size()
			],
			"house_select_screen.gd:765 Clicking parcel on OsmSlippyMap failed to update GameState!"
		)
	hs_screen.queue_free()
	await _wait_frames(2)

	# 1C. LIVE HTTP Nominatim + Live api.openstreetmap.org/api/0.6/map.json + Live Wide-Area Multi-Ring POI Scan
	var osm_live: Node = OsmServiceScript.new()
	root.add_child(osm_live)
	await _wait_frames(2)

	osm_live.connect("search_completed", func(res: Array, _q: String) -> void:
		_search_results = res
		_search_done = true
	)
	osm_live.connect("search_failed", func(err: String) -> void:
		_search_err = err
		_search_done = true
	)
	osm_live.connect("map_data_loaded", func(pdata: Dictionary, lbl: String) -> void:
		_map_parsed = pdata
		_map_label = lbl
		_map_done = true
	)
	osm_live.connect("map_data_failed", func(err: String) -> void:
		_map_err = err
		_map_done = true
	)
	osm_live.connect("wide_area_pois_merged", func(all_pois: Array, _added: int) -> void:
		_wide_merges += 1
		_wide_pois_latest = all_pois
	)
	osm_live.connect("status_changed", func(st_txt: String, is_busy: bool) -> void:
		if not is_busy and st_txt.begins_with("LIVE OSM READY:"):
			_wide_ready_status = true
	)

	_search_done = false
	_search_err = ""
	_search_results = []
	_map_done = false
	_map_err = ""
	_map_parsed = {}
	_wide_merges = 0
	_wide_pois_latest = []
	_wide_ready_status = false

	var live_q: String = "6217 Walborough Court, Wyndham, VA"
	osm_live.call("search_nominatim", live_q, true)
	var t0_ms: int = Time.get_ticks_msec()
	while (not _search_done or not _map_done or not _wide_ready_status) and (Time.get_ticks_msec() - t0_ms) < 22000:
		await process_frame
		if _search_done and not _search_err.is_empty():
			break
		if _map_done and not _map_err.is_empty():
			break

	var live_elapsed_s: float = float(Time.get_ticks_msec() - t0_ms) / 1000.0
	if not _search_err.is_empty() or not _search_done:
		_record_fail("osm_service.gd:212 Live Nominatim geocoding for '%s' failed: err='%s' (%.1fs)" % [live_q, _search_err, live_elapsed_s])
	else:
		var top_hit: Dictionary = _search_results[0]
		var l_lat: float = float(top_hit.get("lat", 0.0))
		var l_lon: float = float(top_hit.get("lon", 0.0))
		_assert_cond(
			absf(l_lat - 37.7085) < 0.02 and absf(l_lon - (-77.6077)) < 0.02,
			"Live Nominatim geocoded '%s' -> (%.5f, %.5f) '%s'" % [
				live_q, l_lat, l_lon, str(top_hit.get("short_name", ""))
			],
			"osm_service.gd:282 Live Nominatim coordinates out of range for '%s': (%.5f, %.5f)" % [live_q, l_lat, l_lon]
		)

	if _map_done and not _map_parsed.is_empty():
		var live_bldgs: Array = _map_parsed.get("buildings", [])
		var live_fb: bool = bool(_map_parsed.get("live_fallback", false))
		var found_live_706: Dictionary = {}
		for lb_v in live_bldgs:
			var lb: Dictionary = lb_v
			if int(lb.get("osm_id", 0)) == 706121395:
				found_live_706 = lb
				break
		_assert_cond(
			not live_fb and live_bldgs.size() >= 100 and not found_live_706.is_empty(),
			"Live api.openstreetmap.org/api/0.6/map.json returned %d real buildings including osm_id=706121395 ('%s')" % [
				live_bldgs.size(), str(found_live_706.get("short_address", ""))
			],
			"osm_service.gd:338 Live OSM 0.6 map.json failed or missed osm_id=706121395 (fallback=%s, bldgs=%d)" % [
				str(live_fb), live_bldgs.size()
			]
		)

		var merged_pois: Array = _wide_pois_latest if not _wide_pois_latest.is_empty() else (_map_parsed.get("pois", []) as Array)
		var live_targets: Array = OsmServiceScript.build_nearby_targets_for_house(
			found_live_706 if not found_live_706.is_empty() else walborough_house,
			live_bldgs,
			merged_pois,
			_map_label
		)
		var live_real_r23: int = 0
		for lt_v in live_targets:
			var lt: Dictionary = lt_v
			if int(lt.get("ring", 1)) >= 2 and not bool(lt.get("synthesized", false)):
				live_real_r23 += 1

		_assert_cond(
			_wide_merges >= 1 and merged_pois.size() >= 3 and live_real_r23 >= 3,
			"Live Wide-Area Nominatim Viewbox Scanner merged %d real Ring 2/3 POIs (%d wide merges in %.1fs) -> %d live targets" % [
				merged_pois.size(), _wide_merges, live_elapsed_s, live_targets.size()
			],
			"osm_service.gd:377 Live Wide-Area POI scanner failed to merge distant Ring 2/3 POIs (merges=%d, pois=%d, real_r23=%d)" % [
				_wide_merges, merged_pois.size(), live_real_r23
			]
		)

		for li in range(mini(5, live_bldgs.size())):
			sampled_houses.append(_tag_house(live_bldgs[li * 13 % live_bldgs.size()], "live_wyndham"))
	else:
		_record_fail("osm_service.gd:251 Live OSM map.json did not complete (err='%s')" % _map_err)

	osm_live.queue_free()

	# 1D. Verify Live OsmSlippyMap PNG Tile Streaming from tile.openstreetmap.org at 6217 Walborough Ct (Z17)
	var tile_map: Control = OsmSlippyMapScript.new()
	tile_map.size = Vector2(828.0, 560.0)
	root.add_child(tile_map)
	await _wait_frames(2)
	tile_map.call("set_center_and_zoom", 37.7085, -77.6077, 17, true)
	var wx_t: float = OsmSlippyMapScript._lon_to_world_x(-77.6077, 17)
	var wy_t: float = OsmSlippyMapScript._lat_to_world_y(37.7085, 17)
	var tx_center: int = int(floor(wx_t / 256.0))
	var ty_center: int = int(floor(wy_t / 256.0))
	tile_map.call("_request_tile", 17, tx_center, ty_center)
	tile_map.call("_pump_tile_queue")
	var tile_key: String = "17/%d/%d" % [tx_center, ty_center]
	var t_tile_ms: int = Time.get_ticks_msec()
	while not (tile_map.get("_tile_textures") as Dictionary).has(tile_key) and (Time.get_ticks_msec() - t_tile_ms) < 8000:
		tile_map.call("_pump_tile_queue")
		await process_frame
	var tile_dict: Dictionary = tile_map.get("_tile_textures")
	var loaded_tex: Texture2D = tile_dict.get(tile_key, null)
	_assert_cond(
		loaded_tex != null and loaded_tex.get_width() == 256 and loaded_tex.get_height() == 256,
		"OsmSlippyMap fetched & decoded valid 256x256 PNG slippy tile (%s) for 6217 Walborough Ct" % tile_key,
		"osm_slippy_map.gd:481 Failed to load 256x256 PNG tile %s from tile.openstreetmap.org" % tile_key
	)
	tile_map.queue_free()

	await _wait_frames(2)
	return sampled_houses


func _tag_house(b: Dictionary, src: String) -> Dictionary:
	var c: Dictionary = b.duplicate(true)
	c["_audit_source"] = src
	return c


# ==============================================================================================
# SECTION 2: HOW EACH OF THE 9 LANDMARK CATEGORIES CHANGES GAMEPLAY (RINGS 1, 2 & 3)
# ==============================================================================================
func _audit_2_nine_landmark_categories_gameplay(gs: Node) -> void:
	print("\n--- [SECTION 2] 9 LANDMARK CATEGORIES GAMEPLAY DIFFERENTIATION (RINGS 1, 2 & 3) ---")

	# Helper to prepare a clean bunker state with an armed/healthy explorer so tests isolate category mechanics
	var ring_distances: Dictionary = {1: 280.0, 2: 2100.0, 3: 5400.0}

	# 2A. Simulate expeditions across ALL 9 categories x ALL 3 rings (Neighbor House is Ring 1; test R1/R2/R3 for all 8 landmarks!)
	var matrix_ok: bool = true
	for cat in ALL_9_CATEGORIES:
		var rings_to_test: Array = [1] if cat == "neighbor_house" else [1, 2, 3]
		for ring_v in rings_to_test:
			var ring_id: int = int(ring_v)
			var dist_m: float = float(ring_distances[ring_id])
			var res: Dictionary = _simulate_single_expedition(
				gs,
				cat,
				ring_id,
				dist_m,
				["suitcase", "gas_mask", "rifle"],
				1000 + ring_id * 97 + cat.hash() % 500,
				{}
			)
			var ret: Dictionary = res["return_data"]
			if not bool(ret.get("returned", false)) or not bool(ret.get("survived", false)):
				matrix_ok = false
				_record_fail("expedition_engine.gd:355 Expedition failed to return alive for cat=%s ring=%d" % [cat, ring_id])
			elif str(ret.get("category", "")) != cat or int(ret.get("ring", 0)) != ring_id:
				matrix_ok = false
				_record_fail("expedition_engine.gd:681 Category/ring mismatch on return: expected %s/R%d, got %s/R%d" % [
					cat, ring_id, str(ret.get("category", "")), int(ret.get("ring", 0))
				])
	_assert_cond(
		matrix_ok,
		"Simulated 25 full round-trip expeditions across all 9 categories x Rings 1, 2 & 3 cleanly",
		"One or more category x ring expeditions failed round-trip execution!"
	)

	# 2B. Category 1: GROCERY -> bulk soup/water (3..6 base) + higher bandit risk (>= 0.45) + grocery_looted story flag
	var groc_r1: Dictionary = _simulate_single_expedition(gs, "grocery", 1, 310.0, ["rifle", "gas_mask"], 202601, {"no_suitcase": true})
	var groc_r2: Dictionary = _simulate_single_expedition(gs, "grocery", 2, 1950.0, ["rifle"], 202602, {"no_suitcase": true})
	var groc_r3: Dictionary = _simulate_single_expedition(gs, "grocery", 3, 5600.0, ["rifle"], 202603, {"no_suitcase": true})
	var g1_loot: Dictionary = groc_r1["return_data"]["loot"]
	var g2_loot: Dictionary = groc_r2["return_data"]["loot"]
	var g3_loot: Dictionary = groc_r3["return_data"]["loot"]
	var g1_soup: int = int(g1_loot.get("soup", 0))
	var g2_soup: int = int(g2_loot.get("soup", 0))
	var g3_soup: int = int(g3_loot.get("soup", 0))
	var g1_water: int = int(g1_loot.get("water", 0))
	var g3_water: int = int(g3_loot.get("water", 0))
	var groc_risk_osm: float = OsmServiceScript._compute_bandit_risk("grocery", 310)
	var nbr_risk_osm: float = OsmServiceScript._compute_bandit_risk("neighbor_house", 120)
	var groc_risk_eng: float = float(groc_r1["poi_enriched"].get("risk_bandits", 0.0))

	_assert_cond(
		g1_soup >= 3 and g2_soup >= 4 and g3_soup >= 5 and g3_soup <= 8
		and g1_water >= 3 and g3_water >= 4
		and groc_risk_osm >= 0.45 and groc_risk_eng >= 0.45 and groc_risk_osm > nbr_risk_osm
		and bool((gs.get("story_flags") as Dictionary).get("grocery_looted", false)),
		"GROCERY verified: bulk Soup (R1=%d, R2=%d, R3=%d) & Water (R1=%d, R3=%d), bandit risk=%.2f (>=0.45 vs house %.2f), story_flags['grocery_looted']=true" % [
			g1_soup, g2_soup, g3_soup, g1_water, g3_water, groc_risk_eng, nbr_risk_osm
		],
		"expedition_engine.gd:704/801 Grocery mechanics failed: soup=(%d,%d,%d), water=(%d,%d), risk=%.2f" % [
			g1_soup, g2_soup, g3_soup, g1_water, g3_water, groc_risk_eng
		]
	)

	# 2C. Category 2: DOCTOR -> antibiotics + medkit + on-site -1 sickness / -1 injury treatment (+ BunkerSim antibiotics cure)
	var doc_res: Dictionary = _simulate_single_expedition(
		gs, "doctor", 2, 1850.0, ["suitcase", "gas_mask", "rifle"], 30301,
		{"init_sickness": 2, "init_injury": 2, "surface_sv": 2.0}
	)
	var doc_loot: Dictionary = doc_res["return_data"]["loot"]
	var doc_member: Dictionary = doc_res["explorer"]
	_assert_cond(
		int(doc_loot.get("antibiotics", 0)) >= 1
		and int(doc_loot.get("medkit", 0)) >= 1
		and int(gs.get("antibiotics_count")) >= 1
		and int(gs.get("medkit_count")) >= 1
		and int(doc_member.get("sickness", 99)) == 1
		and int(doc_member.get("injury", 99)) == 1,
		"DOCTOR verified: looted %d Antibiotics + %d Medkit AND treated explorer on-site (sickness 2->%d, injury 2->%d)" % [
			int(doc_loot.get("antibiotics", 0)), int(doc_loot.get("medkit", 0)),
			int(doc_member.get("sickness", -1)), int(doc_member.get("injury", -1))
		],
		"expedition_engine.gd:584/713 Doctor mechanics failed: loot=%s, sick=%d, inj=%d" % [
			str(doc_loot), int(doc_member.get("sickness", -1)), int(doc_member.get("injury", -1))
		]
	)
	# Also verify BunkerSim.use_antibiotics_on works on a sick shelter member
	var abx_msg: String = BunkerSimScript.use_antibiotics_on(str(doc_member.get("id", "")))
	_assert_cond(
		not abx_msg.is_empty() and int(doc_member.get("sickness", 99)) == 0 and int(doc_member.get("sepsis_protected_days", 0)) == 3,
		"BunkerSim.use_antibiotics_on cured sickness->0 and applied sepsis_protected_days=3",
		"bunker_sim.gd:362 use_antibiotics_on failed!"
	)

	# 2D. Category 3: PHARMACY -> antirad + medkit + on-site -1 sanity (stress) relief (+ BunkerSim antirad purge)
	var rx_res: Dictionary = _simulate_single_expedition(
		gs, "pharmacy", 2, 1650.0, ["suitcase", "gas_mask", "rifle"], 40401,
		{"init_sanity": 2, "init_radiation": 50.0, "surface_sv": 1.2}
	)
	var rx_loot: Dictionary = rx_res["return_data"]["loot"]
	var rx_member: Dictionary = rx_res["explorer"]
	_assert_cond(
		int(rx_loot.get("antirad", 0)) >= 1
		and int(rx_loot.get("medkit", 0)) >= 1
		and int(gs.get("antirad_count")) >= 1
		and int(rx_member.get("sanity", 99)) == 1,
		"PHARMACY verified: looted %d Anti-Rad + %d Medkit AND relieved explorer stress on-site (sanity 2->%d)" % [
			int(rx_loot.get("antirad", 0)), int(rx_loot.get("medkit", 0)), int(rx_member.get("sanity", -1))
		],
		"expedition_engine.gd:597/720 Pharmacy mechanics failed: loot=%s, sanity=%d" % [
			str(rx_loot), int(rx_member.get("sanity", -1))
		]
	)
	var pre_rad_rx: float = float(rx_member.get("radiation", 0.0))
	var ar_msg: String = BunkerSimScript.use_antirad_on(str(rx_member.get("id", "")))
	_assert_cond(
		not ar_msg.is_empty() and float(rx_member.get("radiation", 999.0)) <= maxf(0.0, pre_rad_rx - 34.9),
		"BunkerSim.use_antirad_on purged 35 Rads (%.1f -> %.1f Rads)" % [pre_rad_rx, float(rx_member.get("radiation", 0.0))],
		"bunker_sim.gd:391 use_antirad_on failed to purge radiation!"
	)

	# 2E. Category 4: FUEL_AUTO -> fuel jerrycans + all 4 missing vehicle_parts (battery, alternator, spark_plugs, radiator_hose) + scrap!
	gs.call("reset_to_defaults")
	gs.set("fuel_cans", 0)
	gs.set("fuel_needed", 3)
	gs.set("scrap_count", 0)
	gs.set("vehicle_parts", {"battery": false, "alternator": false, "spark_plugs": false, "radiator_hose": false})
	for m_v in gs.get("family_members"):
		var md: Dictionary = m_v
		md["in_bunker"] = true
		md["alive"] = true
	BunkerSimScript._grant_working_bunker_gear("suitcase")
	BunkerSimScript._grant_working_bunker_gear("gas_mask")
	BunkerSimScript._grant_working_bunker_gear("rifle")
	BunkerSimScript._grant_working_bunker_gear("toolbox")

	for run_i in range(4):
		var fa_poi: Dictionary = {
			"osm_id": 55000 + run_i,
			"name": "Wawa Fuel & Auto #%d" % (run_i + 1),
			"category": "fuel_auto",
			"distance_m": 1750.0,
			"ring": 2,
			"bearing": "E",
			"travel_days": 2
		}
		gs.set("nearby_pois", [fa_poi])
		gs.set("surface_radiation_sv", 1.0)
		var exp_m_id: String = "member_1"
		var explorer_m: Dictionary = gs.get("family_members")[1]
		explorer_m["hunger"] = 0
		explorer_m["thirst"] = 0
		explorer_m["days_without_water"] = 0
		explorer_m["days_without_food"] = 0
		ExpeditionEngineScript.start_expedition(exp_m_id, 0, ["suitcase", "gas_mask", "rifle"])
		var safety_ticks: int = 0
		while not (gs.get("active_expedition") as Dictionary).is_empty() and safety_ticks < 6:
			ExpeditionEngineScript.tick_active_expedition()
			safety_ticks += 1

	var vp_after: Dictionary = gs.get("vehicle_parts")
	var all_4_parts: bool = (
		bool(vp_after.get("battery", false))
		and bool(vp_after.get("alternator", false))
		and bool(vp_after.get("spark_plugs", false))
		and bool(vp_after.get("radiator_hose", false))
	)
	var fuel_total: int = int(gs.get("fuel_cans"))
	var scrap_total: int = int(gs.get("scrap_count"))
	BunkerSimScript.tune_escape_vehicle()
	var can_esc: bool = bool(gs.call("can_escape_by_vehicle"))
	var did_esc: bool = BunkerSimScript.execute_vehicle_escape()

	_assert_cond(
		all_4_parts and fuel_total >= 4 and scrap_total >= 4 and can_esc and did_esc and str(gs.get("ending_route")) == "vehicle_breakout",
		"FUEL_AUTO verified: 4 expeditions collected all 4 Station Wagon parts (%s), %d Fuel Jerrycans & %d Scrap -> Highway Breakout Victory!" % [
			str(vp_after), fuel_total, scrap_total
		],
		"expedition_engine.gd:537/729 Fuel/Auto vehicle progression failed: parts=%s, fuel=%d, scrap=%d, escaped=%s" % [
			str(vp_after), fuel_total, scrap_total, str(did_esc)
		]
	)

	# 2F. Category 5: HARDWARE -> scrap + tools/weapons + backup vehicle_part (~45%)
	var hw_scrap_sum: int = 0
	var hw_tools_found: Dictionary = {}
	var hw_backup_vp_count: int = 0
	for hw_seed in range(12):
		var hw_res: Dictionary = _simulate_single_expedition(
			gs, "hardware", 3, 4600.0, ["rifle"], 60600 + hw_seed,
			{"clear_durables_except_carried": true, "reset_vehicle_parts": true}
		)
		var hl: Dictionary = hw_res["return_data"]["loot"]
		hw_scrap_sum += int(hl.get("scrap", 0))
		for k_hw in ["toolbox", "axe", "rifle", "ammo", "padlock", "flashlight"]:
			if int(hl.get(k_hw, 0)) > 0:
				hw_tools_found[k_hw] = true
		if int(hl.get("vehicle_part", 0)) > 0:
			hw_backup_vp_count += 1

	_assert_cond(
		hw_scrap_sum >= 12 and hw_tools_found.size() >= 2 and hw_backup_vp_count >= 1,
		"HARDWARE verified: yielded %d Scrap across 12 runs, tools/weapons %s, and %d backup Engine Parts" % [
			hw_scrap_sum, str(hw_tools_found.keys()), hw_backup_vp_count
		],
		"expedition_engine.gd:738 Hardware loot failed: scrap=%d, tools=%s, backup_vp=%d" % [
			hw_scrap_sum, str(hw_tools_found.keys()), hw_backup_vp_count
		]
	)

	# 2G. Category 6: CIVIC (Police/Fire) -> weapons/ammo/gas_mask + Ring 2/3 +1 military intel (and Ring 1 does NOT add military intel)
	var civ_r1: Dictionary = _simulate_single_expedition(
		gs, "civic", 1, 380.0, [], 70701,
		{"clear_durables_except_carried": true, "surface_sv": 0.5}
	)
	var mil_after_r1: int = int((gs.get("rescue_chains") as Dictionary).get("military", -1))

	var civ_r2: Dictionary = _simulate_single_expedition(
		gs, "civic", 2, 2200.0, ["suitcase"], 70702,
		{"clear_durables_except_carried": true, "surface_sv": 0.5}
	)
	var mil_after_r2: int = int((gs.get("rescue_chains") as Dictionary).get("military", -1))
	var civ_loot: Dictionary = civ_r2["return_data"]["loot"]
	var has_civic_gear: bool = (
		int(civ_loot.get("rifle", 0)) > 0
		or int(civ_loot.get("gas_mask", 0)) > 0
		or int(civ_loot.get("radio", 0)) > 0
	)

	_assert_cond(
		int(civ_loot.get("ammo", 0)) >= 1
		and has_civic_gear
		and mil_after_r1 == 0
		and mil_after_r2 == 1,
		"CIVIC verified: looted Ammo (%d packs) + armory gear (%s); Ring 1 military=%d, Ring 2 military=+1 (->%d)" % [
			int(civ_loot.get("ammo", 0)), str(civ_loot.keys()), mil_after_r1, mil_after_r2
		],
		"expedition_engine.gd:633/751 Civic mechanics failed: loot=%s, mil_r1=%d, mil_r2=%d" % [
			str(civ_loot), mil_after_r1, mil_after_r2
		]
	)

	# 2H. Category 7: CHURCH -> water + medkit + +1 sanctuary + +10 family relationship harmony across ALL shelter pairs!
	var church_res: Dictionary = _simulate_single_expedition(
		gs, "church", 2, 1800.0, ["gas_mask"], 80801,
		{"base_rel": 20, "surface_sv": 0.8}
	)
	var ch_loot: Dictionary = church_res["return_data"]["loot"]
	var sanc_stage: int = int((gs.get("rescue_chains") as Dictionary).get("sanctuary", 0))
	# Explorer was member_1; check non-explorer pair (member_0 <-> member_2) for +10 church harmony,
	# AND explorer pair (member_1 <-> member_0) for +10 church harmony + +10 explorer gratitude = +20 (20 -> 40)!
	var rel_non_exp: int = int(gs.call("get_relationship", "member_0", "member_2"))
	var rel_with_exp: int = int(gs.call("get_relationship", "member_1", "member_0"))

	_assert_cond(
		int(ch_loot.get("water", 0)) >= 1
		and int(ch_loot.get("medkit", 0)) >= 1
		and sanc_stage == 1
		and rel_non_exp == 30
		and rel_with_exp == 40,
		"CHURCH verified: Water (%d) + Medkit (%d), sanctuary 0->%d, +10 shelter harmony (non-explorer pair 20->%d, explorer pair 20->%d)" % [
			int(ch_loot.get("water", 0)), int(ch_loot.get("medkit", 0)), sanc_stage, rel_non_exp, rel_with_exp
		],
		"expedition_engine.gd:608/622 Church mechanics failed: loot=%s, sanctuary=%d, rel_non_exp=%d, rel_exp=%d" % [
			str(ch_loot), sanc_stage, rel_non_exp, rel_with_exp
		]
	)

	# 2I. Category 8: SCHOOL -> book + map AND verify working map reduces Ring 2 & Ring 3 trip duration by -1 day!
	var sch_found_book: bool = false
	var sch_found_map: bool = false
	for sch_i in range(8):
		var sch_res: Dictionary = _simulate_single_expedition(
			gs, "school", 2, 2100.0, ["suitcase"], 90900 + sch_i,
			{"own_non_book_map_school_items": true, "surface_sv": 0.5}
		)
		var sloot: Dictionary = sch_res["return_data"]["loot"]
		if int(sloot.get("book", 0)) > 0:
			sch_found_book = true
		if int(sloot.get("map", 0)) > 0:
			sch_found_map = true

	# Verify Map -1 day travel reduction on Ring 2 (3d -> 2d) and Ring 3 (4d -> 3d) for a non-scout/non-sprinter member!
	gs.call("reset_to_defaults")
	for m_v in gs.get("family_members"):
		var md: Dictionary = m_v
		md["in_bunker"] = true
		md["alive"] = true
	var handy_ted: Dictionary = gs.get("family_members")[0] # Ted has trait "handy" (not scout/sprinter)
	handy_ted["trait"] = "handy"
	BunkerSimScript._grant_working_bunker_gear("map")

	var r2_poi_test: Dictionary = {"name": "Kroger Supermarket", "category": "grocery", "distance_m": 2400.0, "ring": 2, "travel_days": 3}
	var r3_poi_test: Dictionary = {"name": "Regional Hospital", "category": "doctor", "distance_m": 6800.0, "ring": 3, "travel_days": 4}
	var r2_no_map: int = ExpeditionEngineScript.compute_trip_days(handy_ted, r2_poi_test, [])
	var r2_with_map: int = ExpeditionEngineScript.compute_trip_days(handy_ted, r2_poi_test, ["map"])
	var r3_no_map: int = ExpeditionEngineScript.compute_trip_days(handy_ted, r3_poi_test, [])
	var r3_with_map: int = ExpeditionEngineScript.compute_trip_days(handy_ted, r3_poi_test, ["map"])

	# Also verify broken map does NOT reduce travel days
	gs.get("bunker_items")["map"]["broken"] = true
	var r3_broken_map: int = ExpeditionEngineScript.compute_trip_days(handy_ted, r3_poi_test, ["map"])
	gs.get("bunker_items")["map"]["broken"] = false

	# Also verify live start_expedition sets days_total = 3 (instead of 4) when carrying working map to Ring 3!
	gs.set("nearby_pois", [r3_poi_test.duplicate(true)])
	ExpeditionEngineScript.start_expedition(str(handy_ted["id"]), 0, ["map"])
	var live_r3_days: int = int((gs.get("active_expedition") as Dictionary).get("days_total", -1))

	_assert_cond(
		sch_found_book and sch_found_map
		and r2_no_map == 3 and r2_with_map == 2
		and r3_no_map == 4 and r3_with_map == 3
		and r3_broken_map == 4 and live_r3_days == 3,
		"SCHOOL & MAP verified: drops Book & Map; working Map cuts Ring 2 (%dd->%dd) & Ring 3 (%dd->%dd, live=%dd, broken=%dd) by -1 day!" % [
			r2_no_map, r2_with_map, r3_no_map, r3_with_map, live_r3_days, r3_broken_map
		],
		"expedition_engine.gd:164/771 School/Map failed: book=%s, map=%s, R2=%d->%d, R3=%d->%d (broken=%d, live=%d)" % [
			str(sch_found_book), str(sch_found_map), r2_no_map, r2_with_map, r3_no_map, r3_with_map, r3_broken_map, live_r3_days
		]
	)

	# 2J. Returning Explorer Post-Expedition Effects: soot_days=2, fatigue+1, expedition_scars (+0 R1, +1 R2/R3), +10 gratitude!
	var r1_ret_check: Dictionary = _simulate_single_expedition(gs, "neighbor_house", 1, 95.0, ["rifle"], 99001, {"base_rel": 15, "surface_sv": 0.5})
	var m_r1: Dictionary = r1_ret_check["explorer"]
	var scars_r1: int = int(m_r1.get("expedition_scars", -1))
	var soot_r1: int = int(m_r1.get("soot_days", -1))
	var fat_r1: int = int(m_r1.get("fatigue", -1))
	var rel_r1: int = int(gs.call("get_relationship", "member_1", "member_0")) # 15 -> 25 (+10 gratitude)
	var rel_other_r1: int = int(gs.call("get_relationship", "member_0", "member_2")) # stays 15

	var r3_ret_check: Dictionary = _simulate_single_expedition(gs, "grocery", 3, 5200.0, ["rifle", "gas_mask", "suitcase"], 99002, {"base_rel": 15, "surface_sv": 0.5})
	var m_r3: Dictionary = r3_ret_check["explorer"]
	var scars_r3: int = int(m_r3.get("expedition_scars", -1))
	var soot_r3: int = int(m_r3.get("soot_days", -1))
	var fat_r3: int = int(m_r3.get("fatigue", -1))
	var rel_r3: int = int(gs.call("get_relationship", "member_1", "member_0"))

	_assert_cond(
		soot_r1 == 2 and soot_r3 == 2
		and fat_r1 == 1 and fat_r3 == 1
		and scars_r1 == 0 and scars_r3 == 1
		and rel_r1 == 25 and rel_r3 == 25 and rel_other_r1 == 15,
		"Returning Explorer state verified: soot_days=2, fatigue=0->1, expedition_scars=(R1:%d, R3:%d), +10 family gratitude (15->%d)" % [
			scars_r1, scars_r3, rel_r3
		],
		"expedition_engine.gd:655-669 Explorer return state mismatch: soot=(%d,%d), fat=(%d,%d), scars=(%d,%d), rel=%d" % [
			soot_r1, soot_r3, fat_r1, fat_r3, scars_r1, scars_r3, rel_r3
		]
	)


func _simulate_single_expedition(
	gs: Node,
	cat: String,
	ring_id: int,
	dist_m: float,
	gear_ids: Array,
	rng_seed: int,
	opts: Dictionary
) -> Dictionary:
	gs.call("reset_to_defaults")
	var rng: RandomNumberGenerator = gs.get("rng")
	rng.seed = rng_seed
	gs.set("surface_radiation_sv", float(opts.get("surface_sv", 1.2)))
	gs.call("init_relationships", int(opts.get("base_rel", 20)))

	if bool(opts.get("reset_vehicle_parts", false)):
		gs.set("vehicle_parts", {"battery": false, "alternator": false, "spark_plugs": false, "radiator_hose": false})

	for m_v in gs.get("family_members"):
		var md: Dictionary = m_v
		md["in_bunker"] = true
		md["alive"] = true

	var explorer: Dictionary = gs.get("family_members")[1] # Dolores (adult, member_1)
	explorer["sickness"] = int(opts.get("init_sickness", 0))
	explorer["injury"] = int(opts.get("init_injury", 0))
	explorer["sanity"] = int(opts.get("init_sanity", 0))
	explorer["radiation"] = float(opts.get("init_radiation", 0.0))
	explorer["fatigue"] = 0
	explorer["soot_days"] = 0
	explorer["expedition_scars"] = 0

	if not bool(opts.get("clear_durables_except_carried", false)):
		for g_all in ["gas_mask", "rifle", "axe", "flashlight", "map", "suitcase"]:
			if not bool(opts.get("no_suitcase", false)) or g_all != "suitcase":
				BunkerSimScript._grant_working_bunker_gear(g_all)
	else:
		for g_req in gear_ids:
			BunkerSimScript._grant_working_bunker_gear(str(g_req))

	if bool(opts.get("own_non_book_map_school_items", false)):
		for g_sch in ["flashlight", "checkers", "cards"]:
			BunkerSimScript._grant_working_bunker_gear(g_sch)
		gs.get("bunker_items")["book"]["owned"] = false
		gs.get("bunker_items")["book"]["count"] = 0
		gs.get("bunker_items")["map"]["owned"] = false
		gs.get("bunker_items")["map"]["count"] = 0

	var base_days: int = 1 if ring_id == 1 else (2 if ring_id == 2 else 3)
	var poi: Dictionary = {
		"osm_id": 70000 + ring_id * 100 + abs(cat.hash() % 90),
		"name": "Audit %s R%d" % [cat.capitalize(), ring_id],
		"category": cat,
		"distance_m": dist_m,
		"ring": ring_id,
		"bearing": "NE",
		"travel_days": base_days,
		"visited_count": 0,
		"depleted": false
	}
	gs.set("nearby_pois", [poi])
	var enriched_list: Array = ExpeditionEngineScript.get_available_targets()
	var poi_enriched: Dictionary = enriched_list[0]

	var start_msg: String = ExpeditionEngineScript.start_expedition(str(explorer["id"]), 0, gear_ids)
	var ret_data: Dictionary = {}
	var guard: int = 0
	while not (gs.get("active_expedition") as Dictionary).is_empty() and guard < 8:
		ret_data = ExpeditionEngineScript.tick_active_expedition()
		guard += 1

	return {
		"start_msg": start_msg,
		"poi_enriched": poi_enriched,
		"return_data": ret_data,
		"explorer": explorer
	}


# ==============================================================================================
# SECTION 3: TRUE 3D ISOMETRIC HOUSE, CUTAWAY WALLS, 28 OSM HOUSES, DRILL & LEFT-BEHIND + NUKE
# ==============================================================================================
func _audit_3_house_3d_and_scavenge(gs: Node, candidate_houses: Array) -> void:
	print("\n--- [SECTION 3] TRUE 3D ISOMETRIC HOUSE, CUTAWAY WALLS, DRILL & LEFT-BEHIND AUDIT ---")

	# 3A. Coordinate Mapping Round-Trip (to_3d / to_2d)
	var max_rt_err: float = 0.0
	var scale_ok: bool = is_equal_approx(House3DBuilderScript.SCALE_3D, 0.025)
	for i in range(50):
		var p2 := Vector2(float(i * 37 - 900) * 0.73, float((i * 53) % 700 - 350) * 0.91)
		var y_h: float = 0.04 + float(i % 7) * 0.31
		var p3: Vector3 = House3DBuilderScript.to_3d(p2, y_h)
		var back_2d: Vector2 = House3DBuilderScript.to_2d(p3)
		max_rt_err = maxf(max_rt_err, p2.distance_to(back_2d))
		if not is_equal_approx(p3.y, y_h):
			scale_ok = false

	_assert_cond(
		scale_ok and max_rt_err < 1.0e-4,
		"House3DBuilder.to_3d / to_2d round-trip exact across 50 points (SCALE_3D=0.025, max_err=%.7f px)" % max_rt_err,
		"house_3d_builder.gd:34-40 to_3d/to_2d round-trip error too large: %.6f" % max_rt_err
	)

	# 3B. Audit >= 25 (28) Diverse Real-World OSM Houses -> Floorplan BFS + 3D Cutaway Wall Heights + 3D Hierarchy
	var houses_to_test: Array = []
	var seen_ids: Dictionary = {}
	for h_v in candidate_houses:
		var hd: Dictionary = h_v
		var hid: int = int(hd.get("osm_id", 0))
		if hid > 0 and not seen_ids.has(hid):
			seen_ids[hid] = true
			houses_to_test.append(hd)
		if houses_to_test.size() >= 28:
			break

	gs.call("init_default_family")
	var fam_template: Array = gs.get("family_members")
	var rng := RandomNumberGenerator.new()
	rng.seed = 19551123

	var houses_passed_all: int = 0
	var total_tall_walls_checked: int = 0
	var total_cutaway_walls_checked: int = 0
	var wall_height_violations: int = 0
	var reachability_violations: int = 0
	var hierarchy_violations: int = 0

	for idx in range(houses_to_test.size()):
		var h_dict: Dictionary = houses_to_test[idx]
		var layout: Dictionary = HouseGeneratorScript.generate_from_osm_house(h_dict, fam_template, rng)
		var rooms: Array = layout.get("rooms", [])
		var walls: Array = layout.get("walls", [])
		var furn: Array = layout.get("furniture", [])
		var items: Array = layout.get("items", [])
		var f_spawns: Array = layout.get("family_spawns", [])
		var nav_grid: Dictionary = layout.get("nav_grid", {})
		var hatch_pos: Vector2 = layout.get("hatch_pos", Vector2.ZERO)
		var leader_start: Vector2 = layout.get("leader_start_pos", Vector2.ZERO)
		var outer_poly: PackedVector2Array = layout.get("outer_polygon", PackedVector2Array())
		var int_bounds: Rect2 = layout.get("interior_bounds", Rect2())

		var this_ok: bool = true

		# 1. Verify 6 rooms + unobstructed walkable paths for EVERY Soup, Water, gear item & family member to Bunker Hatch
		var soup_n: int = 0
		var water_n: int = 0
		if rooms.size() < 6 or items.size() < 12 or f_spawns.size() != 3:
			this_ok = false
			reachability_violations += 1
		for it_v in items:
			var it: Dictionary = it_v
			var iid: String = str(it.get("item_id", ""))
			if iid == "soup":
				soup_n += 1
			elif iid == "water":
				water_n += 1
			var ipos: Vector2 = it.get("pos", Vector2.ZERO)
			var p_to_hatch: PackedVector2Array = HouseGeneratorScript.find_path(nav_grid, ipos, hatch_pos)
			var p_from_ldr: PackedVector2Array = HouseGeneratorScript.find_path(nav_grid, leader_start, ipos)
			if not HouseGeneratorScript.is_walkable(nav_grid, ipos) or p_to_hatch.size() < 2 or p_from_ldr.size() < 2 or not Geometry2D.is_point_in_polygon(ipos, outer_poly):
				this_ok = false
				reachability_violations += 1
		if soup_n < 3 or water_n < 3:
			this_ok = false
			reachability_violations += 1
		for fs_v in f_spawns:
			var fs: Dictionary = fs_v
			var fpos: Vector2 = fs.get("pos", Vector2.ZERO)
			var fp_hatch: PackedVector2Array = HouseGeneratorScript.find_path(nav_grid, fpos, hatch_pos)
			if not HouseGeneratorScript.is_walkable(nav_grid, fpos) or fp_hatch.size() < 2 or not Geometry2D.is_point_in_polygon(fpos, outer_poly):
				this_ok = false
				reachability_violations += 1

		# 2. Build 3D House World & audit hierarchy + cutaway wall heights
		var built_3d: Dictionary = House3DBuilderScript.build_house_world(layout, false)
		var root_3d: Node3D = built_3d.get("root", null)
		var furn_nodes: Dictionary = built_3d.get("furniture_nodes", {})
		var hatch_nodes: Dictionary = built_3d.get("hatch_nodes", {})

		if root_3d == null:
			this_ok = false
			hierarchy_violations += 1
			continue

		var yard_n: Node3D = root_3d.get_node_or_null("ExteriorYard")
		var floors_n: Node3D = root_3d.get_node_or_null("RoomFloors")
		var walls_n: Node3D = root_3d.get_node_or_null("CutawayWalls")
		var froot_n: Node3D = root_3d.get_node_or_null("FurnitureRoot")
		var hatch_n: Node3D = root_3d.get_node_or_null("BunkerHatch3D")
		var lid_piv: Node3D = hatch_nodes.get("lid_pivot", null)

		if yard_n == null or floors_n == null or walls_n == null or froot_n == null or hatch_n == null or lid_piv == null:
			this_ok = false
			hierarchy_violations += 1
		elif furn_nodes.size() != furn.size() or not is_equal_approx(lid_piv.rotation_degrees.x, -174.0):
			this_ok = false
			hierarchy_violations += 1

		# Audit every wall child MeshInstance3D inside CutawayWalls:
		# Any MeshInstance3D with center Y > FLOOR_TOP_Y + 0.60m MUST belong to a true North (min_y) or West (min_x) exterior back wall!
		var north_y_m: float = int_bounds.position.y * House3DBuilderScript.SCALE_3D
		var west_x_m: float = int_bounds.position.x * House3DBuilderScript.SCALE_3D
		var tol_m: float = 18.5 * House3DBuilderScript.SCALE_3D # 18 px = 0.45m

		if walls_n != null:
			var house_saw_tall: bool = false
			var house_saw_cutaway: bool = false
			for ch in walls_n.get_children():
				if not (ch is MeshInstance3D):
					continue
				var mi: MeshInstance3D = ch
				var top_above_floor: float = mi.position.y - House3DBuilderScript.FLOOR_TOP_Y
				# If mesh resource exists (non-headless), include half-height; in headless, cap meshes sit at WALL_CUTAWAY_H - 0.008 (0.512) vs WALL_TALL_H - 0.03 (2.27)
				if mi.mesh is BoxMesh:
					top_above_floor += (mi.mesh as BoxMesh).size.y * 0.5
				else:
					# Account for max half-thickness of top cap (0.03m on tall wall, 0.012m on cutaway wall)
					top_above_floor += 0.03 if (mi.position.y - House3DBuilderScript.FLOOR_TOP_Y) > 0.65 else 0.016

				var on_north_back: bool = absf(mi.position.z - north_y_m) <= (tol_m + 0.25)
				var on_west_back: bool = absf(mi.position.x - west_x_m) <= (tol_m + 0.25)

				if top_above_floor > 0.60:
					total_tall_walls_checked += 1
					house_saw_tall = true
					if (not on_north_back and not on_west_back) or top_above_floor > 2.36:
						wall_height_violations += 1
						this_ok = false
						_record_fail("house_3d_builder.gd:635 Interior/South/East wall exceeded 0.60m cutaway! pos=%s top_h=%.2fm (north_z=%.2f, west_x=%.2f)" % [
							str(mi.position), top_above_floor, north_y_m, west_x_m
						])
				else:
					total_cutaway_walls_checked += 1
					house_saw_cutaway = true

			if not house_saw_tall or not house_saw_cutaway:
				this_ok = false
				wall_height_violations += 1

		root_3d.free()
		if this_ok:
			houses_passed_all += 1

	_assert_cond(
		houses_to_test.size() >= 25
		and houses_passed_all == houses_to_test.size()
		and wall_height_violations == 0
		and reachability_violations == 0
		and hierarchy_violations == 0,
		"All %d/%d diverse real OSM houses passed 6-room BFS reachability, 3D hierarchy, and isometric cutaway wall heights (%d tall North/West meshes=2.30m, %d South/East/interior cutaway meshes<=0.60m)" % [
			houses_passed_all, houses_to_test.size(), total_tall_walls_checked, total_cutaway_walls_checked
		],
		"house_3d_builder.gd:587 / house_generator.gd:137 3D house audit failed: passed=%d/%d, wall_violations=%d, reach_violations=%d, hier_violations=%d" % [
			houses_passed_all, houses_to_test.size(), wall_height_violations, reachability_violations, hierarchy_violations
		]
	)

	# 3C. Audit 3D Articulated Survivors, 18+ 3D Item Props, and Live ScavengeScene SubViewport + Camera3D Projection
	var roles_hats_ok: bool = true
	var hat_ids: Array[String] = ["cd_helmet", "aviator", "ushanka", "medic_cap"]
	for r_i in range(4):
		var m_test: Dictionary = fam_template[r_i].duplicate(true)
		m_test["hat_id"] = hat_ids[r_i]
		m_test["hair_style"] = (r_i * 2 + 1) % 8
		m_test["glasses"] = (r_i % 2 == 0)
		var char_3d: Node3D = House3DBuilderScript.build_character_3d(m_test)
		var bp: Node3D = char_3d.get_node_or_null("BodyPivot")
		if bp == null or bp.get_node_or_null("LegLPivot") == null or bp.get_node_or_null("ArmRPivot") == null or bp.get_node_or_null("HeadPivot") == null or bp.get_node_or_null("CarryMount") == null:
			roles_hats_ok = false
		House3DBuilderScript.animate_character_3d(char_3d, 1.2, 0.9, 2, 0.5, false)
		House3DBuilderScript.sync_carried_stack_3d(char_3d, [
			{"kind": "item", "item_id": "soup"},
			{"kind": "family", "member": fam_template[3]}
		])
		var cm: Node3D = bp.get_node_or_null("CarryMount") if bp != null else null
		if cm == null or cm.get_child_count() != 2:
			roles_hats_ok = false
		char_3d.free()

	var items_3d_ok: bool = true
	for iid in [
		"soup", "water", "medkit", "gas_mask", "radio", "flashlight", "map", "book",
		"ammo", "bug_spray", "padlock", "cards", "checkers", "harmonica", "axe",
		"rifle", "suitcase", "toolbox", "antibiotics", "antirad", "fuel", "scrap"
	]:
		var inode: Node3D = House3DBuilderScript.build_item_3d(iid, false)
		if inode == null or inode.get_node_or_null("ModelPivot") == null or inode.get_node_or_null("HighlightDisc") == null or inode.get_node_or_null("HoverRing") == null:
			items_3d_ok = false
		inode.free()

	_assert_cond(
		roles_hats_ok and items_3d_ok,
		"All 4 articulated 3D survivor roles (with hats & CarryMount stack) + 22 3D item models built cleanly",
		"house_3d_builder.gd:1096/1396 3D survivor or item prop hierarchy missing required pivots!"
	)

	# Instantiate ScavengeScene cleanly (verifying zero engine errors) + verify IsometricCamera3D(-48,+32,0) screen<->floor raycast math
	gs.call("reset_to_defaults")
	gs.set("selected_house", houses_to_test[0].duplicate(true))
	var scav_3d: Node2D = ScavengeSceneScript.new()
	root.add_child(scav_3d)
	await _wait_frames(2)

	var vp_test := SubViewport.new()
	vp_test.size = Vector2i(1280, 720)
	vp_test.own_world_3d = true
	scav_3d.add_child(vp_test)
	var cam_3d := Camera3D.new()
	cam_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam_3d.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	cam_3d.size = float(scav_3d.get("_current_ortho_size"))
	cam_3d.near = 0.5
	cam_3d.far = 140.0
	cam_3d.current = true
	vp_test.add_child(cam_3d)
	scav_3d.set("_camera_3d", cam_3d)
	scav_3d.call("_position_camera_3d", scav_3d.get("_cam_focus_2d"), Vector2.ZERO)
	await _wait_frames(2)

	var world_items_arr: Array = scav_3d.get("_world_items")
	var world_fam_arr: Array = scav_3d.get("_world_family")
	var test_floor_pt: Vector2 = scav_3d.get("_hatch_pos") + Vector2(64.0, -48.0)
	var scr_pt: Vector2 = scav_3d.call("project_2d_to_screen", test_floor_pt, House3DBuilderScript.FLOOR_TOP_Y)
	var unproj_2d: Vector2 = scav_3d.call("_screen_to_floor_2d", scr_pt)
	var proj_err_px: float = test_floor_pt.distance_to(unproj_2d)

	_assert_cond(
		is_instance_valid(cam_3d)
		and cam_3d.projection == Camera3D.PROJECTION_ORTHOGONAL
		and cam_3d.rotation_degrees.is_equal_approx(Vector3(-48.0, 32.0, 0.0))
		and world_fam_arr.size() == 3
		and world_items_arr.size() >= 12
		and proj_err_px < 0.25,
		"ScavengeScene IsometricCamera3D(-48,+32,0) & entity spawns verified: %d waiting family, %d items, screen<->floor raycast err=%.5f px" % [
			world_fam_arr.size(), world_items_arr.size(), proj_err_px
		],
		"scavenge_scene.gd:531/717 ScavengeScene camera or screen raycast failed (fam=%d, items=%d, err=%.3f)" % [
			world_fam_arr.size(), world_items_arr.size(), proj_err_px
		]
	)
	scav_3d.queue_free()
	await _wait_frames(2)

	# 3D. Audit scavenge_drill Mode Scoring AND left_behind_members Recording!
	gs.call("reset_to_defaults")
	gs.set("game_mode", "scavenge_drill")
	gs.set("selected_house", houses_to_test[0].duplicate(true))

	var drill_scav: Node2D = ScavengeSceneScript.new()
	root.add_child(drill_scav)
	await _wait_frames(2)

	# Skip scout phase into active 60s scavenge
	drill_scav.call("_start_scavenge_phase")
	var w_fam: Array = drill_scav.get("_world_family")
	var w_it: Array = drill_scav.get("_world_items")
	var h_pos: Vector2 = drill_scav.get("_hatch_pos")

	# Rescue 2 of the 3 non-leader family members (Dolores & Mary Jane), intentionally leaving Timmy behind!
	var expected_left_behind_name: String = ""
	for fi in range(w_fam.size()):
		var f_entry: Dictionary = w_fam[fi]
		if fi < 2:
			drill_scav.set("_player_pos", f_entry["pos"])
			drill_scav.call("_attempt_pickup_target", {
				"kind": "family",
				"uid": int(f_entry["uid"]),
				"pos": f_entry["pos"],
				"slots": int(f_entry["slots"]),
				"name": str(f_entry["name"]),
				"ref": f_entry
			})
			drill_scav.set("_player_pos", h_pos)
			drill_scav.call("_deposit_carried_into_hatch")
		else:
			expected_left_behind_name = str(f_entry["name"])

	# Grab & deposit 10 single-slot supplies in batches of 4
	var grabbed_items: int = 0
	for ii in range(w_it.size()):
		if grabbed_items >= 10:
			break
		var it_e: Dictionary = w_it[ii]
		if int(it_e.get("slots", 1)) == 1:
			drill_scav.set("_player_pos", it_e["pos"])
			if bool(drill_scav.call("_attempt_pickup_target", {
				"kind": "item",
				"uid": int(it_e["uid"]),
				"pos": it_e["pos"],
				"slots": 1,
				"name": str(it_e["name"]),
				"item_id": str(it_e["item_id"]),
				"ref": it_e
			})):
				grabbed_items += 1
				if (drill_scav.get("_carried_entries") as Array).size() >= 4:
					drill_scav.set("_player_pos", h_pos)
					drill_scav.call("_deposit_carried_into_hatch")
	drill_scav.set("_player_pos", h_pos)
	drill_scav.call("_deposit_carried_into_hatch")

	# Set 12.0s remaining and dive into bunker!
	drill_scav.set("_scavenge_time_left", 12.0)
	drill_scav.call("_dive_into_bunker")

	var lb_list: Array = gs.get("left_behind_members")
	var s_stats: Dictionary = gs.get("scavenge_stats")
	var expected_pts: int = 10 * 100 + 3 * 250 + 400 + int(round(12.0 * 15.0)) # 1000 + 750 + 400 + 180 = 2330
	_assert_cond(
		bool(gs.get("game_over"))
		and bool(gs.get("victory"))
		and str(gs.get("ending_route")) == "scavenge_drill"
		and int(s_stats.get("drill_score", 0)) == expected_pts
		and str(s_stats.get("drill_grade", "")) == "A"
		and lb_list.size() == 1
		and str(lb_list[0]) == expected_left_behind_name,
		"scavenge_drill & left_behind_members verified: Grade=%s, Score=%d pts (expected %d), left_behind=%s" % [
			str(s_stats.get("drill_grade", "")), int(s_stats.get("drill_score", 0)), expected_pts, str(lb_list)
		],
		"scavenge_scene.gd:1547-1606 scavenge_drill or left_behind_members failed: stats=%s, left_behind=%s (expected ['%s'])" % [
			str(s_stats), str(lb_list), expected_left_behind_name
		]
	)
	drill_scav.queue_free()
	await _wait_frames(2)

	# Verify left_behind_members propagates tangible Day 1 survivor guilt (-22 relationship with leader, +1 grief stress) in BunkerSim!
	gs.set("game_mode", "full_protocol")
	gs.set("game_over", false)
	gs.set("victory", false)
	gs.call("init_relationships", 20)
	BunkerSimScript.start_bunker_run()
	var rel_after_left_behind: int = int(gs.call("get_relationship", "member_1", "member_0")) # 20 - 22 = -2
	var dolores_sanity_grief: int = int((gs.get("family_members")[1] as Dictionary).get("sanity", 0))
	_assert_cond(
		rel_after_left_behind == -2 and dolores_sanity_grief >= 1,
		"left_behind_members (['%s']) propagated into BunkerSim Day 1: -22 relationship with Leader (20->%d) & +%d grief stress" % [
			expected_left_behind_name, rel_after_left_behind, dolores_sanity_grief
		],
		"relationship_system.gd:12 left_behind_members failed to apply Day 1 trauma: rel=%d, sanity=%d" % [
			rel_after_left_behind, dolores_sanity_grief
		]
	)

	# Also verify scavenge_drill failure (caught outside at 0.0s -> Grade F, victory=false)
	gs.call("reset_to_defaults")
	gs.set("game_mode", "scavenge_drill")
	gs.set("selected_house", houses_to_test[0].duplicate(true))
	var drill_fail: Node2D = ScavengeSceneScript.new()
	root.add_child(drill_fail)
	await _wait_frames(2)
	drill_fail.call("_start_scavenge_phase")
	drill_fail.set("_player_pos", (drill_fail.get("_hatch_pos") as Vector2) + Vector2(260.0, 180.0))
	drill_fail.set("_scavenge_time_left", 0.0)
	drill_fail.call("_resolve_timer_expired")
	var fail_stats: Dictionary = gs.get("scavenge_stats")
	_assert_cond(
		bool(gs.get("game_over"))
		and not bool(gs.get("victory"))
		and str(fail_stats.get("drill_grade", "")) == "F"
		and not bool(fail_stats.get("leader_escaped", true))
		and (gs.get("left_behind_members") as Array).size() == 4,
		"scavenge_drill timeout failure verified: Grade=%s, victory=%s, left_behind=%d/4" % [
			str(fail_stats.get("drill_grade", "")), str(gs.get("victory")), (gs.get("left_behind_members") as Array).size()
		],
		"scavenge_scene.gd:1512 scavenge_drill timeout failure did not record Grade F / left_behind!"
	)
	drill_fail.queue_free()
	await _wait_frames(2)

	# 3E. Global Nuke Detonation Physics & Tangible Bunker/Scavenge Propagation
	gs.set("game_mode", "full_protocol")
	var gz_impact: Dictionary = NukePhysicsScript.compute_impact(37.7085, -77.6077, 37.6900, -77.6200, 800, 30.0, "Short Pump Strike")
	var winter_impact: Dictionary = NukePhysicsScript.compute_impact(37.7085, -77.6077, 55.7558, 37.6173, 5000, 90.0, "Moscow Strategic Ring")

	_assert_cond(
		str(gz_impact.get("zone", "")) == "ground_zero_edge"
		and float(gz_impact.get("initial_sv_hr", 0.0)) > 9.0
		and float(gz_impact.get("bunker_temp_c", 0.0)) >= 30.0
		and str(winter_impact.get("zone", "")) == "nuclear_winter"
		and float(winter_impact.get("bunker_temp_c", 20.0)) < -5.0
		and float(winter_impact.get("scout_seconds", 0.0)) > float(gz_impact.get("scout_seconds", 99.0)),
		"NukePhysics verified from 6217 Walborough Ct: Local GZ (%.2f km, %.1f Sv/hr, %.1f°C, %.0fs scout) vs Global Winter (%.0f km, %.2f Sv/hr, %.1f°C, %.0fs scout)" % [
			float(gz_impact["distance_km"]), float(gz_impact["initial_sv_hr"]), float(gz_impact["bunker_temp_c"]), float(gz_impact["scout_seconds"]),
			float(winter_impact["distance_km"]), float(winter_impact["initial_sv_hr"]), float(winter_impact["bunker_temp_c"]), float(winter_impact["scout_seconds"])
		],
		"nuke_physics.gd:213 NukePhysics failed impact differentiation!"
	)
