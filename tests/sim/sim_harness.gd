extends Node

## Balance harness (section 6): plays the whole shelter phase headless with the game's own rules,
## RUNS per policy, sweeping the cached OSM home fixtures (tests/fixtures/sim_homes, no network).
##
## godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/sim_harness.gd \
##     [--runs=10000] [--policies=random,naive,expert] [--difficulty=normal] [--shard=0 --shards=1] \
##     [--out=user://sim_shard0.json]
## Shards write raw results; tests/sim/sim_report.gd merges them and checks the targets.

const FIXTURE_DIR: String = "res://tests/fixtures/sim_homes"
const MAX_DAYS: int = 120

var runs: int = 1000
var policies: Array[String] = ["random", "naive", "expert"]
var difficulty: String = "normal"
var shard: int = 0
var shards: int = 1
var out_path: String = "user://sim_results.json"
var base_seed: int = 9000


func run() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--policies="):
			policies.assign(a.substr(11).split(",", false))
		elif a.begins_with("--difficulty="):
			difficulty = a.substr(13)
		elif a.begins_with("--shard="):
			shard = int(a.substr(8))
		elif a.begins_with("--shards="):
			shards = int(a.substr(9))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--seed="):
			base_seed = int(a.substr(7))
	var fixtures: Array = load_fixtures()
	if fixtures.is_empty():
		push_error("no fixtures in " + FIXTURE_DIR)
		return 1
	var results: Array = []
	var t0: int = Time.get_ticks_msec()
	for policy in policies:
		for i in range(runs):
			if i % shards != shard:
				continue
			var fx: Dictionary = fixtures[i % fixtures.size()]
			results.append(run_one(fx, policy, base_seed + i * 7919 + policy.length() * 104729, difficulty))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"difficulty": difficulty, "results": results}))
	print("SIM_SHARD %d/%d: %d runs in %.1f s -> %s" % [shard, shards, results.size(), float(Time.get_ticks_msec() - t0) / 1000.0, ProjectSettings.globalize_path(out_path)])
	return 0


static func load_fixtures() -> Array:
	var out: Array = []
	var dir := DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return out
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	for f in files:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_DIR + "/" + str(f)))
		if d is Dictionary:
			out.append(d)
	return out


static func run_one(fx: Dictionary, policy: String, seed_v: int, diff: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var haul: Dictionary = SimPolicies.grab(policy, rng, SimPolicies.grab_budget(diff))
	var s: ShelterState = ShelterSim.new_run({
		"members": SimPolicies.default_family(), "haul": haul, "places": fx.get("targets", []),
		"rad_factors": fx.get("rad_factors", []), "h1_home_msv": float(fx.get("h1_home_msv", 5000.0)),
		"difficulty": diff, "seed": seed_v ^ 0x51F7,
		"temp_c": float((fx.get("nuke", {}) as Dictionary).get("bunker_temp_c", 19.0)), "zone": str((fx.get("nuke", {}) as Dictionary).get("zone", "")),
	})
	while not s.is_over() and s.day < MAX_DAYS:
		ShelterSim.begin_day(s)
		if s.is_over():
			break
		if not s.today_event.is_empty():
			var oid: String = SimPolicies.pick_option(s, policy, rng)
			if oid != "":
				ShelterSim.choose(s, oid)
			if s.is_over():
				break
		ShelterSim.end_day(s, SimPolicies.make_plan(s, policy, rng))
	var ending: String = s.ending if s.is_over() else "timeout"
	var deaths: Array = []
	for d_v in s.stats["deaths"]:
		var d: Dictionary = d_v
		var why: String = ""
		for c_v in d.get("chain", []):
			var t: String = str((c_v as Dictionary).get("text", ""))
			if t.begins_with("got sick") or t.begins_with("injured"):
				why = t.get_slice("(", 0).substr(0, 40)
		deaths.append({"c": str(d["cause"]), "r": str(d["root"]), "d": int(d["day"]), "w": why})
	var mk: Dictionary = {}
	for m_v in s.stats["mistakes"]:
		mk[str((m_v as Dictionary)["kind"])] = int(mk.get(str((m_v as Dictionary)["kind"]), 0)) + 1
	return {
		"p": policy, "f": str(fx.get("id", "")), "g": str(fx.get("group", "")), "ne": float(fx.get("nearest_essential_m", 99999.0)),
		"e": ending, "k": (s.ending_kind if s.is_over() else "loss"), "d": (s.ending_day if s.is_over() else s.day),
		"deaths": deaths, "t": int(s.stats["trips"]), "td": int(s.stats["trip_deaths"]), "mk": mk,
		"cr": int(s.stats["credits_total"]), "cm": int(s.stats["credits_makeshift"]), "ev": int(s.stats["events"]),
		"io": int(s.stats["item_options_used"]), "raids": int(s.stats["raids"]), "fol": int(s.stats["followed_count"]),
		"alive": s.living().size(), "clear": s.fallout_clear_day,
		"rules": s.rules.size(), "aff": int(s.stats["afflictions"]), "maybe": s.ending_kind == "maybe",
		"guilt": int(s.stats["stole"]) > 0, "stranger": str(s.stats["stranger"]) != "",
	}
