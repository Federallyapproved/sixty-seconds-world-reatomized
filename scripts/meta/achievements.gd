class_name Achievements
extends RefCounted

## Achievements (section 14): data/achievements.csv lists them; each row's `condition` is one of
## the checks below. Every check reads decisions the player made (what they grabbed, rationed,
## repaired, voted for, where they went), never a lucky drop, and none rewards hiding in the
## shelter for N days. Unlocks are saved in user://achievements.json.
##
## ctx (from the game): {"grab_all_down_left": float (-1 if someone was left behind),
##                       "nearest_store_m": float, "address_key": String}
## meta: the Almanac dictionary, already updated with this run, for the "over all your runs" ones.

const PATH: String = "user://achievements.json"

## Every condition key `met` understands (the validator checks achievements.csv against it).
const CONDITIONS: Array[String] = [
	"place_types", "addresses_won", "maybe_endings", "grab_all_down_left", "item_options", "pharmacy_medkit",
	"afflicted_all", "takeover_stopped", "radio_all_clear", "stranger_helped", "rules_all", "rules",
	"padlock_stops", "cures", "map_trips", "heavy_clean", "gang_shaken", "repairs", "occupied_left_alone",
	"credit_items", "ending", "ending_kind", "win_far_store", "win_no_guilt", "win_all_alive",
	"win_rules_declined", "win_difficulty", "win_never_thirsty", "win_never_hungry", "trips_all_back",
]


static func load_unlocked(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func save_unlocked(d: Dictionary, path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


## Rows in display order (by name).
static func rows() -> Array:
	var out: Array = []
	for aid in ShelterData.achievements().keys():
		var r: Dictionary = (ShelterData.achievements()[aid] as Dictionary).duplicate()
		r["id"] = str(aid)
		out.append(r)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return out


## Checks every locked achievement; unlocks (in `unlocked`) and returns the ids that just unlocked.
static func evaluate(s: ShelterState, ctx: Dictionary, meta: Dictionary, unlocked: Dictionary) -> Array:
	var fresh: Array = []
	for aid in ShelterData.achievements().keys():
		if unlocked.has(aid):
			continue
		var cond: String = str((ShelterData.achievements()[aid] as Dictionary).get("condition", ""))
		if met(cond, s, ctx, meta):
			unlocked[aid] = {"run": int(meta.get("runs", 0)), "day": s.day if s != null else 0, "time": int(Time.get_unix_time_from_system())}
			fresh.append(str(aid))
	return fresh


static func _stat(s: ShelterState, k: String) -> Variant:
	return s.stats.get(k, 0)


static func met(cond: String, s: ShelterState, ctx: Dictionary, meta: Dictionary) -> bool:
	var key: String = cond
	var arg: String = ""
	if cond.find(":") != -1:
		key = cond.get_slice(":", 0)
		arg = cond.get_slice(":", 1)
	# Checks that need no run at all (over all your runs, or the grab).
	match key:
		"place_types":
			return (meta.get("places_looted", {}) as Dictionary).size() >= int(arg)
		"addresses_won":
			return (meta.get("addresses_won", {}) as Dictionary).size() >= int(arg)
		"maybe_endings":
			var n: int = 0
			for e in (meta.get("endings", {}) as Dictionary).keys():
				if str((ShelterSim.ENDINGS.get(str(e), {}) as Dictionary).get("kind", "")) == "maybe":
					n += 1
			return n >= int(arg)
		"grab_all_down_left":
			var left: float = float(ctx.get("grab_all_down_left", -1.0))
			return left > 0.0 and left <= float(arg)
	if s == null:
		return false
	var win: bool = s.ending_kind == "win"
	match key:
		"item_options":
			return int(_stat(s, "item_options_used")) >= int(arg)
		"pharmacy_medkit", "afflicted_all", "takeover_stopped", "radio_all_clear", "stranger_helped":
			return bool(_stat(s, key))
		"rules_all":
			return not ShelterData.house_rules().is_empty() and s.rules.size() >= ShelterData.house_rules().size()
		"rules":
			return s.rules.size() >= int(arg)
		"padlock_stops", "cures", "map_trips", "heavy_clean", "gang_shaken", "repairs", "occupied_left_alone":
			return int(_stat(s, key)) >= int(arg)
		"credit_items":
			return (s.stats["credits"] as Dictionary).size() >= int(arg)
		"ending":
			return s.ending == arg
		"ending_kind":
			return s.ending_kind == arg
		"win_far_store":
			return win and float(ctx.get("nearest_store_m", 0.0)) > float(arg)
		"win_no_guilt":
			return win and not s.members.any(func(m: Dictionary) -> bool: return bool(m.get("guilt", false)))
		"win_all_alive":
			return win and s.start_count >= 2 and s.living().size() >= s.start_count
		"win_rules_declined":
			return win and s.rules.is_empty() and int(_stat(s, "rules_declined")) >= int(arg)
		"win_difficulty":
			return win and s.difficulty == arg
		"win_never_thirsty":
			return win and not bool(_stat(s, "thirsty_ever"))
		"win_never_hungry":
			return win and not bool(_stat(s, "hungry_ever"))
		"trips_all_back":
			return s.is_over() and int(_stat(s, "trips")) >= int(arg) and int(_stat(s, "trip_deaths")) == 0
	push_warning("Achievements: unknown condition '%s'" % cond)
	return false


## The nearest grocery or pharmacy on foot (for "Long Haul").
static func nearest_store_m(s: ShelterState) -> float:
	var best: float = INF
	for p_v in s.places:
		var p: Dictionary = p_v
		if str(p["category"]) in ["grocery", "pharmacy"] and not bool(p.get("fictional", false)):
			best = minf(best, float(p["walk_m"]))
	return best if best < INF else 99999.0
