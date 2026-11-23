class_name NukePhysics
extends RefCounted

## Global & Regional Nuclear Detonation Impact Physics Engine for "60 Seconds: World Reatomized".
## Computes great-circle Haversine distance, forward azimuth bearings, cube-root scaled blast &
## thermal overpressure radii, downwind fallout plume alignment, and the 4 Civil Defense survival zones.

const EARTH_RADIUS_KM: float = 6371.0
const PLUME_HALF_ANGLE_DEG: float = 35.0

const COMPASS_DIRS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


static func wrap_lon(lon: float) -> float:
	return fposmod(lon + 180.0, 360.0) - 180.0


static func normalize_deg(deg_val: float) -> float:
	return fposmod(deg_val, 360.0)


static func angle_diff_deg(a_deg: float, b_deg: float) -> float:
	return absf(fposmod(a_deg - b_deg + 540.0, 360.0) - 180.0)


static func compass_label(deg_val: float) -> String:
	var norm: float = normalize_deg(deg_val)
	var idx: int = int( floor((norm + 22.5) / 45.0) ) % 8
	return COMPASS_DIRS[idx]


static func haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var dlat: float = deg_to_rad(lat2 - lat1)
	var dlon: float = deg_to_rad(lon2 - lon1)
	var r_lat1: float = deg_to_rad(lat1)
	var r_lat2: float = deg_to_rad(lat2)

	var sin_dlat: float = sin(dlat * 0.5)
	var sin_dlon: float = sin(dlon * 0.5)
	var a: float = sin_dlat * sin_dlat + cos(r_lat1) * cos(r_lat2) * sin_dlon * sin_dlon
	a = clampf(a, 0.0, 1.0)
	var c: float = 2.0 * atan2(sqrt(a), sqrt(maxf(0.0, 1.0 - a)))
	return EARTH_RADIUS_KM * c


static func bearing_deg(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	if absf(lat2 - lat1) < 1e-7 and absf(lon2 - lon1) < 1e-7:
		return 0.0
	var phi1: float = deg_to_rad(lat1)
	var phi2: float = deg_to_rad(lat2)
	var dlambda: float = deg_to_rad(lon2 - lon1)

	var y: float = sin(dlambda) * cos(phi2)
	var x: float = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dlambda)
	return fposmod(rad_to_deg(atan2(y, x)), 360.0)


static func destination_point(lat: float, lon: float, bearing_degrees: float, distance_km: float) -> Dictionary:
	var delta: float = distance_km / EARTH_RADIUS_KM
	var theta: float = deg_to_rad(bearing_degrees)
	var phi1: float = deg_to_rad(lat)
	var lam1: float = deg_to_rad(lon)

	var sin_phi2: float = clampf(
		sin(phi1) * cos(delta) + cos(phi1) * sin(delta) * cos(theta),
		-1.0,
		1.0
	)
	var phi2: float = asin(sin_phi2)
	var y: float = sin(theta) * sin(delta) * cos(phi1)
	var x: float = cos(delta) - sin(phi1) * sin_phi2
	var lam2: float = lam1 + atan2(y, x)

	return {
		"lat": clampf(rad_to_deg(phi2), -89.9, 89.9),
		"lon": wrap_lon(rad_to_deg(lam2))
	}


static func offset_km_to_latlon(ref_lat: float, ref_lon: float, east_km: float, north_km: float) -> Dictionary:
	var dist_km: float = sqrt(east_km * east_km + north_km * north_km)
	if dist_km < 0.001:
		return {"lat": ref_lat, "lon": ref_lon}
	var brng: float = fposmod(rad_to_deg(atan2(east_km, north_km)), 360.0)
	return destination_point(ref_lat, ref_lon, brng, dist_km)


static func latlon_to_local_km(ref_lat: float, ref_lon: float, target_lat: float, target_lon: float) -> Vector2:
	var dist_km: float = haversine_km(ref_lat, ref_lon, target_lat, target_lon)
	if dist_km < 0.0001:
		return Vector2.ZERO
	var brng_rad: float = deg_to_rad(bearing_deg(ref_lat, ref_lon, target_lat, target_lon))
	# Returns Vector2(east_km, north_km)
	return Vector2(sin(brng_rad) * dist_km, cos(brng_rad) * dist_km)


static func sample_geodesic_points(lat1: float, lon1: float, lat2: float, lon2: float, steps: int = 40) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var count: int = maxi(2, steps)
	var p1: Vector3 = _latlon_to_unit_sphere(lat1, lon1)
	var p2: Vector3 = _latlon_to_unit_sphere(lat2, lon2)
	var dot_val: float = clampf(p1.dot(p2), -1.0, 1.0)
	var omega: float = acos(dot_val)

	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var v: Vector3
		if omega < 1e-4:
			v = p1.lerp(p2, t).normalized()
		elif omega > PI - 1e-3:
			# Near-antipodal arc: route cleanly via mid-latitude normal
			var perp: Vector3 = p1.cross(Vector3.UP)
			if perp.length_squared() < 1e-4:
				perp = p1.cross(Vector3.RIGHT)
			perp = perp.normalized()
			var angle: float = t * PI
			v = (p1 * cos(angle) + perp * sin(angle)).normalized()
		else:
			var sin_omega: float = sin(omega)
			var w1: float = sin((1.0 - t) * omega) / sin_omega
			var w2: float = sin(t * omega) / sin_omega
			v = (p1 * w1 + p2 * w2).normalized()

		var lat_deg: float = rad_to_deg(asin(clampf(v.y, -1.0, 1.0)))
		var lon_deg: float = rad_to_deg(atan2(v.z, v.x))
		# Vector2(lon, lat)
		pts.append(Vector2(lon_deg, lat_deg))
	return pts


static func _latlon_to_unit_sphere(lat: float, lon: float) -> Vector3:
	var phi: float = deg_to_rad(lat)
	var lam: float = deg_to_rad(lon)
	var cos_phi: float = cos(phi)
	return Vector3(cos_phi * cos(lam), sin(phi), cos_phi * sin(lam))


static func get_preset_targets(house_lat: float, house_lon: float) -> Array[Dictionary]:
	var local_dt: Dictionary = destination_point(house_lat, house_lon, 225.0, 3.0)
	var reg_base: Dictionary = destination_point(house_lat, house_lon, 115.0, 45.0)
	var anti_lat: float = clampf(-house_lat, -85.0, 85.0)
	var anti_lon: float = wrap_lon(house_lon + 180.0)

	var presets: Array[Dictionary] = [
		{
			"id": "local_3km",
			"button_label": "Local Downtown (3 km)",
			"target_name": "Local Metro Core (3.0 km SW)",
			"lat": float(local_dt.get("lat", house_lat)),
			"lon": float(local_dt.get("lon", house_lon)),
			"prefer_regional": true
		},
		{
			"id": "regional_45km",
			"button_label": "Regional Base (45 km)",
			"target_name": "Regional Strategic Airbase (45 km)",
			"lat": float(reg_base.get("lat", house_lat)),
			"lon": float(reg_base.get("lon", house_lon)),
			"prefer_regional": true
		},
		{
			"id": "dc",
			"button_label": "Washington D.C.",
			"target_name": "Washington D.C., USA",
			"lat": 38.8951,
			"lon": -77.0364,
			"prefer_regional": false
		},
		{
			"id": "moscow",
			"button_label": "Moscow",
			"target_name": "Moscow Strategic Ring",
			"lat": 55.7558,
			"lon": 37.6173,
			"prefer_regional": false
		},
		{
			"id": "tokyo",
			"button_label": "Tokyo",
			"target_name": "Tokyo Bay Metro",
			"lat": 35.6762,
			"lon": 139.6503,
			"prefer_regional": false
		},
		{
			"id": "london",
			"button_label": "London",
			"target_name": "London Thames Sector",
			"lat": 51.5074,
			"lon": -0.1278,
			"prefer_regional": false
		},
		{
			"id": "nevada",
			"button_label": "Nevada Test Site",
			"target_name": "Yucca Flat, Nevada Test Site",
			"lat": 37.1167,
			"lon": -116.0500,
			"prefer_regional": false
		},
		{
			"id": "antipode",
			"button_label": "Antipode Global Winter",
			"target_name": "Antipodal Hemisphere Strike",
			"lat": anti_lat,
			"lon": anti_lon,
			"prefer_regional": false
		}
	]
	return presets


static func compute_impact(
	house_lat: float,
	house_lon: float,
	nuke_lat: float,
	nuke_lon: float,
	yield_kt: int,
	wind_deg: float,
	target_name: String = ""
) -> Dictionary:
	var safe_yield_kt: int = maxi(1, yield_kt)
	var norm_wind: float = normalize_deg(wind_deg)
	var wind_dir_str: String = compass_label(norm_wind)

	var distance_km: float = haversine_km(house_lat, house_lon, nuke_lat, nuke_lon)
	var bearing_gz_to_house: float = bearing_deg(nuke_lat, nuke_lon, house_lat, house_lon)
	var bearing_house_to_gz: float = bearing_deg(house_lat, house_lon, nuke_lat, nuke_lon)

	# Nuclear cube-root blast/thermal scaling relative to a 100 kt reference warhead
	var scale: float = pow(float(safe_yield_kt) / 100.0, 0.3333)
	var fireball_radius_km: float = 0.55 * scale
	var heavy_blast_radius_km: float = 1.80 * scale
	var blast_5psi_radius_km: float = 4.60 * scale
	var thermal_radius_km: float = 7.80 * scale
	var light_blast_radius_km: float = 13.50 * scale
	var fallout_plume_length_km: float = clampf(42.0 * scale, 18.0, 340.0)

	# Angular alignment between wind vector from Ground Zero and vector toward player's house
	var plume_angle_diff: float = 0.0
	var in_fallout_plume: bool = true
	var plume_alignment: float = 1.0
	if distance_km >= 0.20:
		plume_angle_diff = angle_diff_deg(norm_wind, bearing_gz_to_house)
		in_fallout_plume = plume_angle_diff <= PLUME_HALF_ANGLE_DEG
		plume_alignment = clampf(1.0 - (plume_angle_diff / 45.0), 0.0, 1.0)

	var zone: String = ""
	var zone_title: String = ""
	var bunker_temp_c: float = 20.0
	var initial_sv_hr: float = 4.5
	var tremor_intensity: float = 0.5
	var structural_damage: float = 0.2
	var fallout_days: int = 10
	var raider_aggression: float = 0.5
	var scout_seconds: float = 8.0
	var scavenge_seconds: float = 60.0
	var summary: String = ""
	var bullets: Array[String] = []

	var dist_label: String = _format_km(distance_km)
	var yield_t: float = clampf(
		(log(float(safe_yield_kt)) - log(15.0)) / (log(50000.0) - log(15.0)),
		0.0,
		1.0
	)
	var hull_integrity_pct: int = 100
	var hull_loss_pct: int = 0
	var tremor_pct: int = 0
	var raider_pct: int = 0

	if distance_km <= 6.0 * scale:
		zone = "ground_zero_edge"
		zone_title = "GROUND ZERO EDGE"
		var gz_edge_km: float = maxf(0.1, 6.0 * scale)
		var prox_t: float = clampf(1.0 - (distance_km / gz_edge_km), 0.0, 1.0)
		var gz_stress_t: float = clampf(0.45 * prox_t + 0.55 * yield_t, 0.0, 1.0)

		bunker_temp_c = snappedf(lerpf(30.0, 36.0, yield_t), 0.1)
		initial_sv_hr = snappedf(lerpf(8.2, 12.5, yield_t) + (1.8 if in_fallout_plume else 0.0), 0.1)
		tremor_intensity = 1.0
		structural_damage = snappedf(lerpf(0.42, 0.62, gz_stress_t), 0.01)
		fallout_days = 16 + int(round(yield_t * 4.0))
		raider_aggression = 0.75
		scout_seconds = 6.0

		hull_integrity_pct = int(round(clampf(100.0 - structural_damage * 45.0, 25.0, 100.0)))
		hull_loss_pct = 100 - hull_integrity_pct
		tremor_pct = int(round(tremor_intensity * 100.0))
		raider_pct = int(round(raider_aggression * 100.0))

		if in_fallout_plume:
			summary = "Direct inner-ring blast (%s) with %s wind driving lethal fallout over the block!" % [dist_label, wind_dir_str]
			bullets.append("SCORCHING BUNKER (%+.1f C): Intense thermal heat drives faster family thirst." % bunker_temp_c)
			bullets.append("EXTREME FALLOUT PLUME (%.1f Sv/hr): Downwind ash for %d days; Gas Mask vital." % [initial_sv_hr, fallout_days])
		else:
			summary = "Direct inner-ring blast (%s)! Scorching thermal wave and 5-psi overpressure engulf the block." % dist_label
			bullets.append("SCORCHING BUNKER (%+.1f C): Intense thermal heat drives faster family thirst." % bunker_temp_c)
			bullets.append("EXTREME FALLOUT (%.1f Sv/hr): Deadly surface ash for %d days; Gas Mask vital." % [initial_sv_hr, fallout_days])
		bullets.append("VIOLENT SHOCKWAVE (%d%%): Maximum tremor & %d%% hull loss (%d%% shelter integrity)." % [tremor_pct, hull_loss_pct, hull_integrity_pct])
		bullets.append("FLASH SIREN (%.1fs Recon + %.1fs Grab): Minimal radar warning before impact!" % [scout_seconds, scavenge_seconds])
		bullets.append("INNER-RING PANIC (%d%% Raiders): Desperate looters target intact shelters." % raider_pct)
	elif distance_km <= 35.0 * scale:
		zone = "near_blast"
		zone_title = "NEAR-BLAST METRO STRIKE"
		bunker_temp_c = 25.0
		initial_sv_hr = 5.8 + (3.0 if in_fallout_plume else 0.0)
		tremor_intensity = 0.65
		structural_damage = 0.30
		fallout_days = 13
		raider_aggression = 0.60
		scout_seconds = 8.0

		hull_integrity_pct = int(round(clampf(100.0 - structural_damage * 45.0, 25.0, 100.0)))
		hull_loss_pct = 100 - hull_integrity_pct
		tremor_pct = int(round(tremor_intensity * 100.0))
		raider_pct = int(round(raider_aggression * 100.0))

		if in_fallout_plume:
			summary = "Classic metro strike (%s) with %s wind blowing the primary fallout plume directly over your house!" % [dist_label, wind_dir_str]
			bullets.append("DIRECT FALLOUT PLUME (%.1f Sv/hr): Downwind ash cloud spikes surface radiation!" % initial_sv_hr)
		else:
			summary = "Classic metro strike (%s). Heavy airblast shatters windows while crosswind deflects peak ash." % dist_label
			bullets.append("HEAVY FALLOUT (%.1f Sv/hr): Dangerous radiation persists for %d days outside." % [initial_sv_hr, fallout_days])
		bullets.append("WARM BUNKER (%+.1f C): Residual blast warmth raises daily water demand." % bunker_temp_c)
		bullets.append("METRO SHOCKWAVE (%d%%): Heavy house tremors & %d%% hull loss (%d%% shelter integrity)." % [tremor_pct, hull_loss_pct, hull_integrity_pct])
		bullets.append("CONELRAD ALERT (%.1fs Recon + %.1fs Grab): Classic Civil Defense scavenge run." % [scout_seconds, scavenge_seconds])
		bullets.append("URBAN MARAUDERS (%d%% Raiders): Secure bunker door with Padlock, Axe, or Rifle." % raider_pct)
	elif distance_km <= 350.0:
		zone = "regional_fallout"
		zone_title = "REGIONAL FALLOUT CLOUD"
		bunker_temp_c = 11.0
		initial_sv_hr = 5.2 if in_fallout_plume else 2.6
		tremor_intensity = 0.25
		structural_damage = 0.12
		fallout_days = 9
		raider_aggression = 0.50
		scout_seconds = 10.0

		hull_integrity_pct = int(round(clampf(100.0 - structural_damage * 45.0, 25.0, 100.0)))
		hull_loss_pct = 100 - hull_integrity_pct
		tremor_pct = int(round(tremor_intensity * 100.0))
		raider_pct = int(round(raider_aggression * 100.0))

		if in_fallout_plume:
			summary = "Regional strike (%s). %s upper-level winds funnel a dense ash cloud over your neighborhood." % [dist_label, wind_dir_str]
			bullets.append("DOWNWIND ASH CORRIDOR (%.1f Sv/hr): Regional plume doubles early radiation!" % initial_sv_hr)
		else:
			summary = "Regional strike (%s). Soot haze dims daylight into a cool nuclear dusk." % dist_label
			bullets.append("MODERATE FALLOUT (%.1f Sv/hr): Clears over %d days for earlier neighborhood scouting." % [initial_sv_hr, fallout_days])
		bullets.append("NUCLEAR DUSK (%+.1f C): Chilly shelter air; steady rations prevent sickness." % bunker_temp_c)
		bullets.append("DISTANT SHOCKWAVE (%d%%): Light ground roll & %d%% hull loss (%d%% shelter integrity)." % [tremor_pct, hull_loss_pct, hull_integrity_pct])
		bullets.append("REGIONAL RADAR (%.1fs Recon + %.1fs Grab): Extra seconds to plan your route!" % [scout_seconds, scavenge_seconds])
		bullets.append("HIGHWAY SCAVENGERS (%d%% Raiders): Evacuee gangs sweep suburban streets." % raider_pct)
	else:
		zone = "nuclear_winter"
		tremor_intensity = 0.05
		structural_damage = 0.05
		scout_seconds = 12.0

		hull_integrity_pct = int(round(clampf(100.0 - structural_damage * 45.0, 25.0, 100.0)))
		hull_loss_pct = 100 - hull_integrity_pct
		tremor_pct = int(round(tremor_intensity * 100.0))

		if safe_yield_kt >= 800:
			var high_t: float = clampf(
				(log(float(safe_yield_kt)) - log(800.0)) / (log(50000.0) - log(800.0)),
				0.0,
				1.0
			)
			zone_title = "GLOBAL NUCLEAR WINTER"
			bunker_temp_c = snappedf(lerpf(-5.0, -12.5, high_t) - absf(house_lat) * 0.12, 0.1)
			initial_sv_hr = snappedf(lerpf(0.45, 0.58, high_t), 0.01)
			fallout_days = 4 + int(round(high_t * 2.0))
			raider_aggression = snappedf(lerpf(0.70, 0.80, high_t), 0.01)
			raider_pct = int(round(raider_aggression * 100.0))
			summary = "Distant strategic detonation (%s, %d kt). Stratospheric soot triggers a brutal Freezing Nuclear Winter!" % [dist_label, safe_yield_kt]
			bullets.append("FREEZING WINTER (%+.1f C): Bitter bunker cold causes sickness unless heated & fed!" % bunker_temp_c)
			bullets.append("LOW EARLY FALLOUT (%.2f Sv/hr): Safe early scavenging across intact neighbors!" % initial_sv_hr)
			bullets.append("FAINT SEISMIC WAVE (%d%%): Virtually no tremor (%d%% hull loss, %d%% shelter integrity)." % [tremor_pct, hull_loss_pct, hull_integrity_pct])
			bullets.append("BMEWS EARLY WARNING (%.1fs Recon + %.1fs Grab): Maximum scout preparation time!" % [scout_seconds, scavenge_seconds])
			bullets.append("FAMINE BANDITS (%d%% Raiders): Starving winter militias relentlessly hunt food." % raider_pct)
		elif safe_yield_kt >= 100:
			zone_title = "GLOBAL NUCLEAR AUTUMN"
			if safe_yield_kt <= 250:
				var mid_low_t: float = clampf(
					(log(float(safe_yield_kt)) - log(100.0)) / (log(250.0) - log(100.0)),
					0.0,
					1.0
				)
				bunker_temp_c = snappedf(lerpf(6.5, 2.0, mid_low_t) - absf(house_lat) * 0.04, 0.1)
				initial_sv_hr = snappedf(lerpf(0.32, 0.35, mid_low_t), 0.01)
				raider_aggression = snappedf(lerpf(0.52, 0.58, mid_low_t), 0.01)
			else:
				var mid_high_t: float = clampf(
					(log(float(safe_yield_kt)) - log(250.0)) / (log(800.0) - log(250.0)),
					0.0,
					1.0
				)
				var lat_k: float = lerpf(0.04, 0.12, mid_high_t)
				bunker_temp_c = snappedf(lerpf(2.0, -5.0, mid_high_t) - absf(house_lat) * lat_k, 0.1)
				initial_sv_hr = snappedf(lerpf(0.35, 0.45, mid_high_t), 0.01)
				raider_aggression = snappedf(lerpf(0.58, 0.70, mid_high_t), 0.01)
			fallout_days = 4
			raider_pct = int(round(raider_aggression * 100.0))
			summary = "Distant urban detonation (%s, %d kt). Upper-tropospheric soot triggers a chilly Global Nuclear Autumn." % [dist_label, safe_yield_kt]
			bullets.append("NUCLEAR AUTUMN (%+.1f C): Frosty bunker chill raises sickness risk without warm rations." % bunker_temp_c)
			bullets.append("LOW EARLY FALLOUT (%.2f Sv/hr): Minimal local ash allows safe early scouting." % initial_sv_hr)
			bullets.append("FAINT SEISMIC WAVE (%d%%): Virtually no tremor (%d%% hull loss, %d%% shelter integrity)." % [tremor_pct, hull_loss_pct, hull_integrity_pct])
			bullets.append("BMEWS EARLY WARNING (%.1fs Recon + %.1fs Grab): Maximum scout preparation time!" % [scout_seconds, scavenge_seconds])
			bullets.append("RATION HOARDERS (%d%% Raiders): Panic-buying militias raid stocked shelters." % raider_pct)
		else:
			var low_t: float = clampf(
				(log(float(safe_yield_kt)) - log(15.0)) / (log(100.0) - log(15.0)),
				0.0,
				1.0
			)
			zone_title = "GLOBAL CIVIL DEFENSE DUSK"
			bunker_temp_c = snappedf(lerpf(11.0, 6.5, low_t) - absf(house_lat) * 0.04, 0.1)
			initial_sv_hr = snappedf(lerpf(0.25, 0.32, low_t), 0.01)
			fallout_days = 3
			raider_aggression = snappedf(lerpf(0.45, 0.52, low_t), 0.01)
			raider_pct = int(round(raider_aggression * 100.0))
			summary = "Distant tactical detonation (%s, %d kt). High-altitude haze cools skies into a Global Civil Defense Dusk." % [dist_label, safe_yield_kt]
			bullets.append("CIVIL DEFENSE DUSK (%+.1f C): Cool shelter air without severe stratospheric freeze." % bunker_temp_c)
			bullets.append("TRACE GLOBAL FALLOUT (%.2f Sv/hr): Negligible local ash; safe early scavenging!" % initial_sv_hr)
			bullets.append("FAINT SEISMIC WAVE (%d%%): Virtually no tremor (%d%% hull loss, %d%% shelter integrity)." % [tremor_pct, hull_loss_pct, hull_integrity_pct])
			bullets.append("BMEWS EARLY WARNING (%.1fs Recon + %.1fs Grab): Maximum scout preparation time!" % [scout_seconds, scavenge_seconds])
			bullets.append("CIVIL UNREST (%d%% Raiders): Moderate blackout looting across intact blocks." % raider_pct)

	summary = summary.replace("%%", "%")
	for b_idx in range(bullets.size()):
		bullets[b_idx] = bullets[b_idx].replace("%%", "%")

	var resolved_name: String = target_name.strip_edges()
	if resolved_name.is_empty():
		if distance_km < 1.5:
			resolved_name = "Direct Neighborhood Ground Zero (%s)" % dist_label
		elif distance_km <= 60.0:
			resolved_name = "Metro Sector %s (%s)" % [compass_label(bearing_house_to_gz), dist_label]
		else:
			resolved_name = "Global Coordinates (%.1f, %.1f)" % [nuke_lat, nuke_lon]
	resolved_name = resolved_name.replace("%%", "%")

	return {
		"target_name": resolved_name,
		"lat": nuke_lat,
		"lon": nuke_lon,
		"house_lat": house_lat,
		"house_lon": house_lon,
		"yield_kt": safe_yield_kt,
		"wind_bearing_deg": norm_wind,
		"wind_compass": wind_dir_str,
		"distance_km": distance_km,
		"bearing_from_nuke_deg": bearing_gz_to_house,
		"bearing_to_nuke_deg": bearing_house_to_gz,
		"scale": scale,
		"fireball_radius_km": fireball_radius_km,
		"heavy_blast_radius_km": heavy_blast_radius_km,
		"blast_5psi_radius_km": blast_5psi_radius_km,
		"thermal_radius_km": thermal_radius_km,
		"light_blast_radius_km": light_blast_radius_km,
		"fallout_plume_length_km": fallout_plume_length_km,
		"plume_angle_diff_deg": plume_angle_diff,
		"in_fallout_plume": in_fallout_plume,
		"plume_alignment": plume_alignment,
		"zone": zone,
		"zone_title": zone_title,
		"initial_sv_hr": initial_sv_hr,
		"bunker_temp_c": bunker_temp_c,
		"tremor_intensity": tremor_intensity,
		"structural_damage": structural_damage,
		"hull_integrity_pct": hull_integrity_pct,
		"hull_loss_pct": hull_loss_pct,
		"raider_aggression": raider_aggression,
		"fallout_days": fallout_days,
		"scavenge_seconds": scavenge_seconds,
		"scout_seconds": scout_seconds,
		"summary": summary,
		"condition_bullets": bullets
	}


static func _format_km(dist_km: float) -> String:
	if dist_km < 10.0:
		return "%.2f km" % dist_km
	elif dist_km < 100.0:
		return "%.1f km" % dist_km
	return "%d km" % int(round(dist_km))
