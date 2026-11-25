class_name RadiationModel
extends RefCounted

## Fallout radiation model (units: dose rate in mSv/h, dose in mSv).
##
## * Decay: Way–Wigner t^-1.2 law ("7–10 rule": 7x time -> 1/10 dose rate), integrated exactly
##   over each day: ∫ H1·t^-1.2 dt = 5·H1·(t1^-0.2 − t2^-0.2).
## * Location: a downwind plume from ground zero. Dose rate scales with how well a place lines up
##   with the plume axis and how far downwind it is; upwind / crosswind places get far less.
## * Localized returns: rain-out, wind-blown dust and additional strikes add hotspots with their
##   own decay, so a place can get worse again after the general level has dropped.
## * Shelter: protection factor (PF) of the basement shelter scales with structural integrity.
## * Health: acute radiation syndrome (ARS) severity follows the dose received over the last
##   7 days (protracted dose is far less harmful than the same dose at once); cumulative dose is
##   tracked separately for the record.
##
## Reference thresholds (whole-body, acute): <250 mSv no symptoms; 0.25–1 Sv blood changes;
## 1–2 Sv mild ARS; 2–4 Sv moderate; 4–6 Sv severe (LD50/60 ≈ 4–5 Sv untreated); >6 Sv usually fatal.

const BASE_SHELTER_PF: float = 200.0     # basement fallout shelter with intact hatch/earth cover
const MIN_SHELTER_PF: float = 15.0
const BUILDING_PF_WHILE_SCAVENGING: float = 4.0
const HOURS_OUTSIDE_PER_TRIP_DAY: float = 5.0
const GAS_MASK_FACTOR: float = 0.85      # filters inhaled particles (~15% of fallout dose), not gamma
const ACUTE_WINDOW_DAYS: float = 7.0
const PLUME_HALF_ANGLE_DEG: float = 35.0


static func hours_since_detonation(day: int) -> float:
	# Day 1 starts ~1 h after the blast (the scavenge minute + sealing the hatch).
	return 1.0 + float(maxi(0, day - 1)) * 24.0


## Reference dose rate at 1 h after the burst at HOME (mSv/h), from the impact model.
static func h1_home_msv() -> float:
	return maxf(0.0, float(GameState.nuke_config.get("initial_sv_hr", 0.5))) * 1000.0


static func _gz() -> Vector2:
	return Vector2(float(GameState.nuke_config.get("lon", 0.0)), float(GameState.nuke_config.get("lat", 0.0)))


## Relative plume intensity at a location (1.0 on the axis close to GZ).
static func plume_intensity(lat: float, lon: float) -> float:
	var gz: Vector2 = _gz()
	var d_km: float = NukePhysics.haversine_km(gz.y, gz.x, lat, lon)
	var wind: float = float(GameState.nuke_config.get("wind_bearing_deg", 45.0))
	var brg: float = NukePhysics.bearing_deg(gz.y, gz.x, lat, lon)
	var ang: float = absf(NukePhysics.angle_diff_deg(wind, brg))
	var yield_kt: float = maxf(1.0, float(GameState.nuke_config.get("yield_kt", 250)))
	var plume_len_km: float = clampf(18.0 * pow(yield_kt / 100.0, 0.45), 8.0, 400.0)
	var along: float = exp(-d_km / plume_len_km)
	var width_deg: float = PLUME_HALF_ANGLE_DEG * (1.0 + 0.4 / maxf(0.3, d_km))
	var cross: float = exp(-pow(ang / width_deg, 2.0))
	var local_deposit: float = 0.08 * exp(-d_km / 6.0)   # close-in deposition in every direction
	return maxf(0.002, along * cross + local_deposit)


## Location factor relative to home (home = 1.0). Clamped so a few hundred metres never makes an
## absurd difference, but the extended 2 km view and upwind/downwind places do diverge.
static func location_factor(lat: float, lon: float) -> float:
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	var home_i: float = plume_intensity(h_lat, h_lon)
	return clampf(plume_intensity(lat, lon) / maxf(0.0001, home_i), 0.15, 4.0)


static func hotspot_multiplier(lat: float, lon: float, day: int) -> float:
	var mult: float = 1.0
	for h_v in GameState.rad_hotspots:
		var h: Dictionary = h_v
		var age: int = day - int(h.get("start_day", day))
		if age < 0:
			continue
		var d_m: float = NukePhysics.haversine_km(lat, lon, float(h.get("lat", 0.0)), float(h.get("lon", 0.0))) * 1000.0
		var r: float = maxf(50.0, float(h.get("radius_m", 300.0)))
		if d_m > r * 2.0:
			continue
		var fall: float = exp(-pow(d_m / r, 2.0))
		var decay: float = exp(-float(age) / maxf(0.5, float(h.get("decay_days", 4.0))))
		mult += (float(h.get("mult", 2.0)) - 1.0) * fall * decay
	return mult


## Outdoor dose rate (mSv/h) at a place at a given hour after the first detonation.
static func dose_rate_msv_h(lat: float, lon: float, hours: float, day: int) -> float:
	var t: float = maxf(1.0, hours)
	var rate: float = h1_home_msv() * pow(t, -1.2) * location_factor(lat, lon) * hotspot_multiplier(lat, lon, day)
	rate += _second_strike_rate(lat, lon, hours)
	return rate + 0.0003  # natural background ~0.0003 mSv/h


static func _second_strike_rate(lat: float, lon: float, hours: float) -> float:
	var extra: float = 0.0
	for s_v in GameState.extra_strikes:
		var s: Dictionary = s_v
		var dt: float = hours - float(s.get("hour", 0.0))
		if dt < 0.0:
			continue
		var d_km: float = NukePhysics.haversine_km(lat, lon, float(s.get("lat", lat)), float(s.get("lon", lon)))
		extra += float(s.get("h1_msv", 0.0)) * pow(maxf(1.0, dt), -1.2) * exp(-d_km / 25.0)
	return extra


## Exact integral of the t^-1.2 decay between two times (hours) for a 1 mSv/h-at-1h source.
static func decay_integral(t1: float, t2: float) -> float:
	var a: float = maxf(1.0, t1)
	var b: float = maxf(a, t2)
	return 5.0 * (pow(a, -0.2) - pow(b, -0.2))


## Outdoor dose (mSv) accumulated at a place for `hours_outside` hours starting at `start_hour`.
static func outdoor_dose_msv(lat: float, lon: float, start_hour: float, hours_outside: float, day: int) -> float:
	var base: float = h1_home_msv() * decay_integral(start_hour, start_hour + hours_outside) * location_factor(lat, lon) * hotspot_multiplier(lat, lon, day)
	var extra: float = 0.0
	for s_v in GameState.extra_strikes:
		var s: Dictionary = s_v
		var t0: float = start_hour - float(s.get("hour", 0.0))
		var t1: float = t0 + hours_outside
		if t1 <= 0.0:
			continue
		var d_km: float = NukePhysics.haversine_km(lat, lon, float(s.get("lat", lat)), float(s.get("lon", lon)))
		extra += float(s.get("h1_msv", 0.0)) * decay_integral(maxf(1.0, t0), t1) * exp(-d_km / 25.0)
	return base + extra + 0.0003 * hours_outside


static func shelter_pf() -> float:
	var integ: float = clampf(GameState.bunker_structural_integrity / 100.0, 0.0, 1.0)
	return maxf(MIN_SHELTER_PF, BASE_SHELTER_PF * integ * integ)


## Advances the radiation state to `day`: updates the home outdoor reading and gives every
## sheltered survivor their in-shelter dose for the day. Returns a short log line.
static func tick_day(day: int) -> String:
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	var t_start: float = hours_since_detonation(day - 1)
	var t_end: float = hours_since_detonation(day)
	var outdoor_day_dose: float = outdoor_dose_msv(h_lat, h_lon, t_start, t_end - t_start, day)
	var shelter_dose: float = outdoor_day_dose / shelter_pf()
	for m_v in GameState.get_living_bunker_members():
		add_dose(m_v as Dictionary, shelter_dose, day)
	var rate_now: float = dose_rate_msv_h(h_lat, h_lon, t_end, day)
	GameState.surface_radiation_sv = rate_now / 1000.0
	GameState.shelter_dose_today_msv = shelter_dose
	return "Geiger counter topside: %s (%s). Inside the shelter (PF %d): %s today." % [
		format_rate(rate_now), risk_label(rate_now), int(round(shelter_pf())), format_dose(shelter_dose)
	]


static func add_dose(member: Dictionary, dose_msv: float, day: int) -> void:
	if dose_msv <= 0.0 or member.is_empty():
		return
	member["dose_msv"] = float(member.get("dose_msv", 0.0)) + dose_msv
	var hist: Array = member.get("dose_history", [])
	hist.append([day, dose_msv])
	while hist.size() > 0 and day - int((hist[0] as Array)[0]) >= int(ACUTE_WINDOW_DAYS):
		hist.remove_at(0)
	member["dose_history"] = hist
	member["dose_recent_msv"] = recent_dose(member, day)
	# Legacy 0..100+ "radiation" meter used by visuals: 1 point = 50 mSv of recent dose.
	member["radiation"] = float(member["dose_recent_msv"]) / 50.0


static func recent_dose(member: Dictionary, day: int) -> float:
	var total: float = 0.0
	for e_v in member.get("dose_history", []):
		var e: Array = e_v
		if day - int(e[0]) < int(ACUTE_WINDOW_DAYS):
			total += float(e[1])
	return total


## ARS stage 0..5 from the 7-day dose (the shelter engine owns the table).
static func ars_stage(recent_msv: float) -> int:
	return ShelterSim.ars_stage(recent_msv)


static func ars_label(stage: int) -> String:
	return ShelterSim.ars_label(stage)


## Dose-rate risk wording keyed to what a few hours outside would do.
static func risk_label(rate_msv_h: float) -> String:
	if rate_msv_h < 0.01:
		return "near background"
	if rate_msv_h < 0.1:
		return "low"
	if rate_msv_h < 1.0:
		return "elevated"
	if rate_msv_h < 10.0:
		return "high — hours outside add tens of mSv"
	if rate_msv_h < 100.0:
		return "very high — a long trip can mean hundreds of mSv"
	if rate_msv_h < 1000.0:
		return "severe — hours outside can cause radiation sickness"
	return "lethal — an hour outside can be fatal"


static func risk_short(rate_msv_h: float) -> String:
	if rate_msv_h < 0.1:
		return "LOW"
	if rate_msv_h < 1.0:
		return "ELEVATED"
	if rate_msv_h < 10.0:
		return "HIGH"
	if rate_msv_h < 100.0:
		return "VERY HIGH"
	if rate_msv_h < 1000.0:
		return "SEVERE"
	return "LETHAL"


static func format_rate(rate_msv_h: float) -> String:
	return DoseFormat.rate(rate_msv_h)


static func format_dose(dose_msv: float) -> String:
	return DoseFormat.dose(dose_msv)


## Expected dose (mSv) for a scavenging trip to a place, starting tonight.
## Expeditions planned today leave at the start of tomorrow, so the estimate starts there.
static func expedition_dose_estimate(lat: float, lon: float, days: int, has_gas_mask: bool) -> float:
	var total: float = 0.0
	for d in range(maxi(1, days)):
		var day_n: int = GameState.day + 1 + d
		var start_h: float = hours_since_detonation(day_n) + 4.0
		var outside: float = outdoor_dose_msv(lat, lon, start_h, HOURS_OUTSIDE_PER_TRIP_DAY, day_n)
		var inside_hours: float = 24.0 - HOURS_OUTSIDE_PER_TRIP_DAY
		var inside: float = outdoor_dose_msv(lat, lon, start_h + HOURS_OUTSIDE_PER_TRIP_DAY, inside_hours, day_n) / BUILDING_PF_WHILE_SCAVENGING
		total += outside + inside
	return total * (GAS_MASK_FACTOR if has_gas_mask else 1.0)


## Adds a localized hotspot (rain-out, dust, debris) around a place.
static func add_hotspot(lat: float, lon: float, radius_m: float, mult: float, decay_days: float, cause: String) -> void:
	GameState.rad_hotspots.append({"lat": lat, "lon": lon, "radius_m": radius_m, "mult": mult, "decay_days": decay_days, "start_day": GameState.day, "cause": cause})


## A further detonation (fresh fallout with its own t^-1.2 clock).
static func add_strike(lat: float, lon: float, h1_msv: float) -> void:
	GameState.extra_strikes.append({"lat": lat, "lon": lon, "h1_msv": h1_msv, "hour": hours_since_detonation(GameState.day) + 6.0})
