class_name VehicleSystem
extends RefCounted

## The family car in the garage/driveway: a real repair-and-escape route.
##
## Condition is set by the blast (distance, overpressure). Parts must be scavenged from real
## places (fuel stations, auto/hardware shops, neighbours' driveways), carried home, stored on
## the shelter rack, then installed BY HAND by a survivor (radiation exposure in the garage).
## When the car runs and has fuel for the route, the household can drive out crosswind, away from ground zero.
##
## Disabled: GameState.FEATURE_CAR_ESCAPE is false, so the run starts with no vehicle and every
## entry point below reports "no car". The code is kept compiling for a later return.

const NEEDED_FUEL_L: float = 25.0
const L_PER_KM: float = 0.11
const INSTALL_HOURS: Dictionary = {"car_battery": 0.6, "spark_plugs": 1.0, "fan_belt": 0.8, "tire_patch": 1.2, "fuel_can": 0.3}
const GARAGE_PF: float = 2.0


## Tests switch the disabled car escape on to keep its logic covered.
static var test_override: bool = false


static func enabled() -> bool:
	return GameState.FEATURE_CAR_ESCAPE or test_override


static func init_for_run() -> void:
	if not enabled():
		GameState.vehicle = {}
		return
	var nuke: Dictionary = GameState.nuke_config
	var dmg: float = clampf(float(nuke.get("structural_damage", 0.25)), 0.0, 1.0)
	var dist_km: float = float(nuke.get("distance_km", 5.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(GameState.selected_house.get("osm_id", 0))) ^ int(dist_km * 100.0)
	var wrecked: bool = dmg >= 0.55 and dist_km < 2.5
	GameState.vehicle = {
		"exists": true,
		"wrecked": wrecked,
		"battery_installed": false,          # the old battery cracked in the blast / was drained
		"plugs_ok": rng.randf() > 0.6,
		"belt_ok": dmg < 0.35 or rng.randf() > 0.5,
		"tires_ok": dmg < 0.3,
		"fuel_l": snappedf(rng.randf_range(3.0, 12.0), 0.5),
		"hood_open": false,
		"history": [],
		"escaped": false,
	}
	if wrecked:
		GameState.vehicle["history"].append("Day 1: the blast flipped debris onto the car — it is crushed beyond repair.")


static func is_ready() -> bool:
	if not enabled() or GameState.vehicle.is_empty():
		return false
	return missing_parts().is_empty() and not bool(GameState.vehicle.get("wrecked", false))


## Parts still needed (item ids), fuel counted as jerry cans.
static func missing_parts() -> Array:
	var v: Dictionary = GameState.vehicle
	var out: Array = []
	if not enabled() or v.is_empty() or bool(v.get("wrecked", false)):
		return out
	if not bool(v.get("battery_installed", false)):
		out.append("car_battery")
	if not bool(v.get("plugs_ok", true)):
		out.append("spark_plugs")
	if not bool(v.get("belt_ok", true)):
		out.append("fan_belt")
	if not bool(v.get("tires_ok", true)):
		out.append("tire_patch")
	if float(v.get("fuel_l", 0.0)) < NEEDED_FUEL_L:
		out.append("fuel_can")
	return out


static func part_in_storage(part: String) -> bool:
	if part == "fuel_can":
		return float(GameState.parts.get("fuel_l", 0.0)) >= 10.0
	return int(GameState.parts.get(part, 0)) > 0


static func needs_tools(part: String) -> bool:
	return part == "spark_plugs" or part == "fan_belt"


## Who does the work: capable leader first, otherwise the oldest capable adult/teen in the shelter.
static func pick_worker() -> Dictionary:
	return EventDeck.pick_actor()


static func can_install(part: String) -> Dictionary:
	if not enabled() or GameState.vehicle.is_empty():
		return {"ok": false, "why": "No car this time."}
	if bool(GameState.vehicle.get("wrecked", false)):
		return {"ok": false, "why": "The car is wrecked."}
	if not missing_parts().has(part):
		return {"ok": false, "why": "Not needed."}
	if not part_in_storage(part):
		return {"ok": false, "why": "None in storage — scavenge one first."}
	if needs_tools(part):
		var handy: bool = false
		for m_v in GameState.get_living_bunker_members():
			if str((m_v as Dictionary).get("trait", "")) == "handy":
				handy = true
		if not handy:
			return {"ok": false, "why": "Needs someone handy with tools."}
	var worker: Dictionary = pick_worker()
	if worker.is_empty():
		return {"ok": false, "why": "Nobody fit to work on the car right now."}
	return {"ok": true, "worker": worker}


## Installs a part by hand. Applies the garage dose to the worker and logs to the journal.
static func install(part: String) -> Dictionary:
	var chk: Dictionary = can_install(part)
	if not bool(chk.get("ok", false)):
		return {"ok": false, "text": str(chk.get("why", ""))}
	var worker: Dictionary = chk["worker"]
	var v: Dictionary = GameState.vehicle
	var w_name: String = str(worker.get("name", "Someone"))
	var text: String = ""
	match part:
		"car_battery":
			GameState.parts["car_battery"] = int(GameState.parts.get("car_battery", 0)) - 1
			v["battery_installed"] = true
			text = "%s carried the 12-volt battery up to the garage, bolted it into the tray and clamped the terminals — the dash lights flickered on." % w_name
		"spark_plugs":
			GameState.parts["spark_plugs"] = int(GameState.parts.get("spark_plugs", 0)) - 1
			v["plugs_ok"] = true
			text = "%s pulled the fouled spark plugs and threaded in the new set." % w_name
		"fan_belt":
			GameState.parts["fan_belt"] = int(GameState.parts.get("fan_belt", 0)) - 1
			v["belt_ok"] = true
			text = "%s fitted the new fan belt and tensioned it." % w_name
		"tire_patch":
			GameState.parts["tire_patch"] = int(GameState.parts.get("tire_patch", 0)) - 1
			v["tires_ok"] = true
			text = "%s patched the flat tire and pumped it back up." % w_name
		"fuel_can":
			GameState.parts["fuel_l"] = float(GameState.parts.get("fuel_l", 0.0)) - 10.0
			v["fuel_l"] = float(v.get("fuel_l", 0.0)) + 10.0
			text = "%s emptied a 10-litre jerry can into the tank (%.0f L now)." % [w_name, float(v["fuel_l"])]
	# Garage work happens above ground: real exposure.
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	var hours: float = float(INSTALL_HOURS.get(part, 1.0))
	var start_h: float = RadiationModel.hours_since_detonation(GameState.day) + 10.0
	var dose: float = RadiationModel.outdoor_dose_msv(h_lat, h_lon, start_h, hours, GameState.day) / GARAGE_PF
	RadiationModel.add_dose(worker, dose, GameState.day)
	text += " (%s in the garage: %s)" % [_hours_label(hours), RadiationModel.format_dose(dose)]
	(v["history"] as Array).append("Day %d: %s" % [GameState.day, text])
	GameState.daily_log_entries.append({"day": GameState.day, "title": "DAY %d — WORK ON THE CAR" % GameState.day, "lines": [text]})
	GameState.inventory_changed.emit()
	return {"ok": true, "text": text, "worker_id": str(worker.get("id", "")), "worker_name": w_name, "dose_msv": dose, "part": part}


static func _hours_label(h: float) -> String:
	if h < 1.0:
		return "%d min" % int(round(h * 60.0))
	return "%.1f h" % h


## Upwind escape: away from the fallout plume, toward the verified landmark/area in that direction.
## Escape crosswind (emergency-management advice: leave at right angles to the plume), on the side that
## points away from ground zero — never "upwind", which from a downwind house means toward GZ.
static func escape_plan() -> Dictionary:
	var downwind: float = LocationText.downwind_bearing()
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	var to_gz: float = NukePhysics.bearing_deg(h_lat, h_lon, float(GameState.nuke_config.get("lat", h_lat)), float(GameState.nuke_config.get("lon", h_lon)))
	var c1: float = fposmod(downwind + 90.0, 360.0)
	var c2: float = fposmod(downwind - 90.0, 360.0)
	var heading: float = c1 if absf(NukePhysics.angle_diff_deg(c1, to_gz)) >= absf(NukePhysics.angle_diff_deg(c2, to_gz)) else c2
	var dir_word: String = LocationText.compass_word(heading)
	var route_km: float = 40.0
	var fuel_need: float = route_km * L_PER_KM
	var lm: Dictionary = LocationText.landmark_toward(heading, 60.0, 200.0)
	var via: String = ("past %s" % str(lm["name"])) if not lm.is_empty() else ""
	return {"bearing": heading, "dir_word": dir_word, "route_km": route_km, "fuel_needed_l": fuel_need, "via": via}


static func status_lines() -> Array[String]:
	var v: Dictionary = GameState.vehicle
	var out: Array[String] = []
	if not enabled() or v.is_empty():
		out.append("No vehicle.")
		return out
	if bool(v.get("wrecked", false)):
		out.append("Crushed by blast debris — beyond repair.")
		return out
	out.append("Battery: %s" % ("installed" if bool(v.get("battery_installed", false)) else "MISSING (blast cracked the old one)"))
	out.append("Spark plugs: %s" % ("good" if bool(v.get("plugs_ok", true)) else "fouled — need new plugs and someone handy"))
	out.append("Fan belt: %s" % ("good" if bool(v.get("belt_ok", true)) else "snapped — need a belt and someone handy"))
	out.append("Tires: %s" % ("inflated" if bool(v.get("tires_ok", true)) else "flat — need a patch kit"))
	out.append("Fuel: %.0f / %.0f L needed" % [float(v.get("fuel_l", 0.0)), NEEDED_FUEL_L])
	return out


## Where could the missing parts come from in the REAL neighbourhood? Drives the UI and endings.
static func part_sources(part: String) -> Array:
	var out: Array = []
	for p_v in GameState.nearby_pois:
		var p: Dictionary = p_v
		var inv: Dictionary = LootInventory.get_inventory(p)
		var n: int = int((inv["items"] as Dictionary).get(part, 0))
		if n > 0:
			out.append({"name": str(p.get("name", "")), "count": n, "category": str(p.get("category", "")), "kind_label": str(p.get("kind_label", ""))})
	return out


static func route_available() -> bool:
	var v: Dictionary = GameState.vehicle
	if not enabled() or v.is_empty() or bool(v.get("wrecked", false)):
		return false
	for part in missing_parts():
		if part_in_storage(str(part)):
			continue
		if part_sources(str(part)).is_empty():
			return false
	return true


## Drives out. Requires everyone in the shelter (nobody left behind on an expedition).
static func drive_out() -> Dictionary:
	if not enabled():
		return {"ok": false, "text": "No car this time."}
	if not is_ready():
		return {"ok": false, "text": "The car is not ready."}
	if not GameState.active_expedition.is_empty():
		return {"ok": false, "text": "Wait until %s is back from the expedition." % str(GameState.active_expedition.get("member_name", "the explorer"))}
	var plan: Dictionary = escape_plan()
	var fuel: float = float(GameState.vehicle.get("fuel_l", 0.0))
	if fuel < float(plan["fuel_needed_l"]):
		return {"ok": false, "text": "Not enough fuel for the route."}
	var h_lat: float = float(GameState.selected_house.get("lat", 0.0))
	var h_lon: float = float(GameState.selected_house.get("lon", 0.0))
	var start_h: float = RadiationModel.hours_since_detonation(GameState.day) + 8.0
	var drive_dose: float = RadiationModel.outdoor_dose_msv(h_lat, h_lon, start_h, 0.75, GameState.day) * 0.6
	var names: Array[String] = []
	for m_v in GameState.get_living_bunker_members():
		var m: Dictionary = m_v
		RadiationModel.add_dose(m, drive_dose, GameState.day)
		names.append(str(m.get("name", "")))
	GameState.vehicle["fuel_l"] = fuel - float(plan["fuel_needed_l"])
	GameState.vehicle["escaped"] = true
	var area: String = LocationText.area_name()
	var via: String = str(plan.get("via", ""))
	var via_txt: String = (" " + via) if not via.is_empty() else ""
	GameState.victory = true
	GameState.game_over = true
	GameState.ending_title = "VICTORY: DROVE OUT OF %s" % area.to_upper()
	GameState.ending_description = "On day %d the repaired car coughed to life. %s piled in and drove %s%s, crosswind out of the fallout plume and away from ground zero, absorbing about %s each on the way out of %s." % [
		GameState.day, ", ".join(names), str(plan["dir_word"]), via_txt, RadiationModel.format_dose(drive_dose), area
	]
	GameState.daily_log_entries.append({"day": GameState.day, "title": "DAY %d — WE DROVE OUT" % GameState.day, "lines": [GameState.ending_description]})
	return {"ok": true, "text": GameState.ending_description}
