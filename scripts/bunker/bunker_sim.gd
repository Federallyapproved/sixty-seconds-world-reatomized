class_name BunkerSim
extends RefCounted

## Starts the shelter phase from what the grab produced and drives it for the screens. The rules
## are ShelterSim / ShelterTrips / ShelterEvents / ShelterChains (pure, headless-testable).


## Seals the hatch: builds the ShelterState from the family, the grab haul, the real places nearby
## and the strike, and stores it in GameState.shelter.
static func start_bunker_run() -> void:
	GameState.game_over = false
	GameState.victory = false
	GameState.ending_title = ""
	GameState.ending_description = ""
	if GameState.demo_mode:
		var anyone_in: bool = false
		for m_v in GameState.family_members:
			if bool((m_v as Dictionary).get("in_bunker", false)):
				anyone_in = true
		if not anyone_in:
			for m_v in GameState.family_members:
				(m_v as Dictionary)["in_bunker"] = true
	var targets: Array = ExpeditionEngine.get_available_targets()
	var factors: Array = []
	for t_v in targets:
		var t: Dictionary = t_v
		factors.append(RadiationModel.location_factor(float(t.get("lat", 0.0)), float(t.get("lon", 0.0))))
	var nuke: Dictionary = GameState.nuke_config
	GameState.bunker_structural_integrity = clampf(100.0 - clampf(float(nuke.get("structural_damage", 0.25)), 0.0, 1.0) * 45.0, 25.0, 100.0)
	GameState.bunker_temp_c = float(nuke.get("bunker_temp_c", 19.0))
	GameState.surface_radiation_sv = maxf(0.15, float(nuke.get("initial_sv_hr", GameState.surface_radiation_sv)))
	var s: ShelterState = ShelterSim.new_run({
		"members": GameState.family_members, "haul": GameState.grab_haul.duplicate(), "places": targets,
		"rad_factors": factors, "h1_home_msv": RadiationModel.h1_home_msv(), "difficulty": GameState.difficulty,
		"seed": GameState.rng.randi(), "temp_c": GameState.bunker_temp_c, "zone": str(nuke.get("zone", "")),
	})
	GameState.shelter = s
	if GameState.FEATURE_CAR_ESCAPE:
		VehicleSystem.init_for_run()
	sync_outcome()
	GameState.inventory_changed.emit()
	GameState.family_changed.emit()


## Mirrors the outdoor dose rate and the shelter air into GameState for the artwork and gauges.
static func sync_world() -> void:
	var s: ShelterState = GameState.shelter
	if s == null:
		return
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	GameState.surface_radiation_sv = RadiationModel.dose_rate_msv_h(h_lat, h_lon, RadiationModel.hours_since_detonation(s.day), s.day) / 1000.0
	GameState.bunker_temp_c = s.temp_c


## Mirrors the run's ending into the GameState fields the summary screen reads.
static func sync_outcome() -> void:
	var s: ShelterState = GameState.shelter
	if s == null or not s.is_over():
		return
	var info: Dictionary = ShelterSim.ending_info(s)
	GameState.game_over = true
	GameState.victory = s.ending_kind == "win"
	GameState.ending_title = str(info.get("title", ""))
	GameState.ending_description = str(info.get("text", ""))


## One whole day for scripts and tests: answers today's dilemma (first available option unless
## `choice_id` is given), applies the plan and starts the next day. Returns the next morning's lines.
static func advance_day(plan: Dictionary = {}, choice_id: String = "") -> Array[String]:
	var s: ShelterState = GameState.shelter
	var lines: Array[String] = []
	if s == null or s.is_over():
		return lines
	if not s.today_resolved and choice_id != "":
		ShelterSim.choose(s, choice_id)
	var p: Dictionary = plan if not plan.is_empty() else ShelterSim.default_plan(s)
	ShelterSim.end_day(s, p)
	sync_world()
	var morning: Dictionary = ShelterSim.begin_day(s)
	for l_v in morning.get("morning", []):
		lines.append(str((l_v as Dictionary).get("text", "")))
	sync_outcome()
	GameState.inventory_changed.emit()
	GameState.family_changed.emit()
	GameState.day_advanced.emit(s.day)
	return lines


static func get_condition_labels(member: Dictionary) -> Array[String]:
	return ShelterSim.status_labels(member, GameState.day)
