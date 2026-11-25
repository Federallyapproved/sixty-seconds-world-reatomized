extends Node

## Merges the harness shards, measures everything section 6 asks for, checks the targets and
## writes docs/balance/sim_summary.json + the tables of docs/BALANCE_REPORT.md.
## godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/sim_report.gd \
##     --in=user://sim_shard*.json [--report=res://docs/BALANCE_REPORT.md] [--no-write]
## Exit code 1 when a target is missed (so CI can gate a merge on it).

const TARGETS: Dictionary = {
	"random_win_max": 0.05, "random_median_death_min": 15, "random_median_death_max": 25,
	"naive_win_min": 0.10, "naive_win_max": 0.20, "expert_win_min": 0.45, "expert_win_max": 0.60,
	"gap_min": 0.40, "expert_wipe_before_15_max": 0.10, "cause_share_max": 0.40,
	"expert_trips_min": 3.0, "expert_trips_max": 6.0, "dice_losses_max": 0.10,
	"quartile_spread_max": 0.20, "crafted_share_max": 0.25,
	"win_day_median_min": 30, "win_day_median_max": 45,
}

var summary: Dictionary = {}
var checks: Array = []


func run() -> int:
	var pattern: String = "user://sim_shard*.json"
	var report_path: String = "res://docs/BALANCE_REPORT.md"
	var write: bool = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			pattern = a.substr(5)
		elif a.begins_with("--report="):
			report_path = a.substr(9)
		elif a == "--no-write":
			write = false
	var results: Array = []
	var diff: String = "normal"
	var dir_path: String = pattern.get_base_dir()
	var mask: String = pattern.get_file()
	var dir := DirAccess.open(dir_path)
	for f in dir.get_files():
		if f.match(mask):
			var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir_path + "/" + f))
			results.append_array(d.get("results", []))
			diff = str(d.get("difficulty", diff))
	if results.is_empty():
		push_error("no results matching " + pattern)
		return 1
	summary = analyse(results)
	summary["difficulty"] = diff
	var ok: bool = _check_targets()
	_print()
	if write:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/balance"))
		var f := FileAccess.open("res://docs/balance/sim_summary_%s.json" % diff, FileAccess.WRITE)
		f.store_string(JSON.stringify({"summary": summary, "checks": checks}, "\t"))
		if diff == "normal":
			_write_report(report_path)
	return 0 if ok else 1


static func _median(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var a: Array = arr.duplicate()
	a.sort()
	var n: int = a.size()
	return float(a[n / 2]) if n % 2 == 1 else (float(a[n / 2 - 1]) + float(a[n / 2])) * 0.5


static func analyse(results: Array) -> Dictionary:
	var by_p: Dictionary = {}
	# Distance quartiles over the fixtures actually used.
	var dists: Array = []
	var seen_f: Dictionary = {}
	for r_v in results:
		var r: Dictionary = r_v
		if not seen_f.has(str(r["f"])):
			seen_f[str(r["f"])] = float(r["ne"])
			dists.append(float(r["ne"]))
	# Quartiles by rank over the fixtures (ties broken by fixture id), so each holds a quarter.
	var fx_rank: Array = []
	for fid in seen_f.keys():
		fx_rank.append([float(seen_f[fid]), str(fid)])
	fx_rank.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var fx_q: Dictionary = {}
	for i in range(fx_rank.size()):
		fx_q[str(fx_rank[i][1])] = mini(3, int(float(i) * 4.0 / float(fx_rank.size())))
	dists.sort()
	var q_edges: Array = [dists[int(dists.size() * 0.25)], dists[int(dists.size() * 0.5)], dists[int(dists.size() * 0.75)]]
	for r_v in results:
		var r: Dictionary = r_v
		var p: String = str(r["p"])
		if not by_p.has(p):
			by_p[p] = {"n": 0, "wins": 0, "endings": {}, "loss_days": [], "win_days": [], "death_causes": {}, "deaths": 0,
				"death_days": {}, "wipe_before_15": 0, "trips": [], "trip_deaths": 0, "dice_losses": 0, "zero_mistake_losses": 0,
				"q": [[0, 0], [0, 0], [0, 0], [0, 0]], "groups": {}, "cr": 0, "cm": 0, "mistakes": {}, "item_opts": 0, "events": 0,
				"followed": 0, "raids": 0, "end_days": [], "rules": 0, "aff": 0, "maybe": 0, "guilt": 0, "stranger": 0}
		var s: Dictionary = by_p[p]
		s["n"] = int(s["n"]) + 1
		var win: bool = str(r["k"]) == "win"
		var endings: Dictionary = s["endings"]
		endings[str(r["e"])] = int(endings.get(str(r["e"]), 0)) + 1
		(s["end_days"] as Array).append(int(r["d"]))
		if win:
			s["wins"] = int(s["wins"]) + 1
			(s["win_days"] as Array).append(int(r["d"]))
		else:
			(s["loss_days"] as Array).append(int(r["d"]))
			if int(r["d"]) < 15:
				s["wipe_before_15"] = int(s["wipe_before_15"]) + 1
			var mk_total: int = 0
			for v in (r["mk"] as Dictionary).values():
				mk_total += int(v)
			if mk_total == 0:
				s["zero_mistake_losses"] = int(s["zero_mistake_losses"]) + 1
				var all_chance: bool = true
				for d_v in r["deaths"]:
					if str((d_v as Dictionary)["r"]) != "chance":
						all_chance = false
				if all_chance:
					s["dice_losses"] = int(s["dice_losses"]) + 1
		for d_v in r["deaths"]:
			var d: Dictionary = d_v
			var dc: Dictionary = s["death_causes"]
			dc[str(d["c"])] = int(dc.get(str(d["c"]), 0)) + 1
			s["deaths"] = int(s["deaths"]) + 1
			var bin: String = "%02d-%02d" % [(int(d["d"]) / 5) * 5, (int(d["d"]) / 5) * 5 + 4]
			var dd: Dictionary = s["death_days"]
			dd[bin] = int(dd.get(bin, 0)) + 1
		(s["trips"] as Array).append(int(r["t"]))
		s["trip_deaths"] = int(s["trip_deaths"]) + int(r["td"])
		var qi: int = int(fx_q.get(str(r["f"]), 0))
		var qa: Array = (s["q"] as Array)[qi]
		qa[0] = int(qa[0]) + 1
		qa[1] = int(qa[1]) + (1 if win else 0)
		var g: Dictionary = s["groups"]
		if not g.has(str(r["g"])):
			g[str(r["g"])] = [0, 0]
		(g[str(r["g"])] as Array)[0] = int((g[str(r["g"])] as Array)[0]) + 1
		(g[str(r["g"])] as Array)[1] = int((g[str(r["g"])] as Array)[1]) + (1 if win else 0)
		s["cr"] = int(s["cr"]) + int(r["cr"])
		s["cm"] = int(s["cm"]) + int(r["cm"])
		s["item_opts"] = int(s["item_opts"]) + int(r["io"])
		s["events"] = int(s["events"]) + int(r["ev"])
		s["followed"] = int(s["followed"]) + (1 if int(r["fol"]) > 0 else 0)
		s["raids"] = int(s["raids"]) + int(r["raids"])
		s["rules"] = int(s["rules"]) + int(r.get("rules", 0))
		s["aff"] = int(s["aff"]) + int(r.get("aff", 0))
		s["maybe"] = int(s["maybe"]) + (1 if bool(r.get("maybe", false)) else 0)
		s["guilt"] = int(s["guilt"]) + (1 if bool(r.get("guilt", false)) else 0)
		s["stranger"] = int(s["stranger"]) + (1 if bool(r.get("stranger", false)) else 0)
		var mks: Dictionary = s["mistakes"]
		for k in (r["mk"] as Dictionary).keys():
			mks[k] = int(mks.get(k, 0)) + int(r["mk"][k])
	var out: Dictionary = {"quartile_edges_m": q_edges, "fixtures": seen_f.size(), "policies": {}}
	for p in by_p.keys():
		var s: Dictionary = by_p[p]
		var n: float = float(s["n"])
		var qr: Array = []
		for qa in s["q"]:
			qr.append(float(qa[1]) / maxf(1.0, float(qa[0])))
		var causes: Dictionary = {}
		for c in (s["death_causes"] as Dictionary).keys():
			causes[c] = float(s["death_causes"][c]) / maxf(1.0, float(s["deaths"]))
		var gr: Dictionary = {}
		for gk in (s["groups"] as Dictionary).keys():
			var ga: Array = s["groups"][gk]
			gr[gk] = {"n": int(ga[0]), "win": float(ga[1]) / maxf(1.0, float(ga[0]))}
		(out["policies"] as Dictionary)[p] = {
			"runs": int(n), "win_rate": float(s["wins"]) / n, "endings": s["endings"],
			"median_loss_day": _median(s["loss_days"]), "median_win_day": _median(s["win_days"]),
			"earliest_win_day": (s["win_days"] as Array).min() if not (s["win_days"] as Array).is_empty() else 0,
			"median_run_days": _median(s["end_days"]), "death_causes": causes, "death_days": s["death_days"],
			"wipe_before_15": float(s["wipe_before_15"]) / n, "trips_mean": _mean(s["trips"]), "trips_median": _median(s["trips"]),
			"trip_death_rate": float(s["trip_deaths"]) / maxf(1.0, _sum(s["trips"])),
			"dice_losses": float(s["dice_losses"]) / n, "zero_mistake_losses": float(s["zero_mistake_losses"]) / n,
			"quartile_win": qr, "quartile_spread": (qr.max() - qr.min()) if not qr.is_empty() else 0.0, "groups": gr,
			"crafted_share": float(s["cm"]) / maxf(1.0, float(s["cr"])), "item_options_per_run": float(s["item_opts"]) / n,
			"events_per_run": float(s["events"]) / n, "followed_share": float(s["followed"]) / n, "raids_per_run": float(s["raids"]) / n,
			"mistakes": s["mistakes"],
			"rules_per_run": float(s["rules"]) / n, "afflictions_per_run": float(s["aff"]) / n,
			"maybe_rate": float(s["maybe"]) / n, "stole_share": float(s["guilt"]) / n, "stranger_share": float(s["stranger"]) / n,
		}
	return out


static func _mean(arr: Array) -> float:
	return _sum(arr) / maxf(1.0, float(arr.size()))


static func _sum(arr: Array) -> float:
	var t: float = 0.0
	for v in arr:
		t += float(v)
	return t


func _check(name: String, ok: bool, detail: String) -> bool:
	checks.append({"check": name, "ok": ok, "detail": detail})
	return ok


func _check_targets() -> bool:
	var P: Dictionary = summary["policies"]
	var ok: bool = true
	if P.has("random"):
		var r: Dictionary = P["random"]
		ok = _check("Random win rate ≤ 5%", float(r["win_rate"]) <= float(TARGETS["random_win_max"]), "%.1f%%" % (100.0 * float(r["win_rate"]))) and ok
		ok = _check("Random median death day 15–25", float(r["median_loss_day"]) >= 15.0 and float(r["median_loss_day"]) <= 25.0, "day %.1f" % float(r["median_loss_day"])) and ok
	if P.has("naive"):
		var nv: Dictionary = P["naive"]
		ok = _check("Naive win rate 10–20%", float(nv["win_rate"]) >= 0.10 and float(nv["win_rate"]) <= 0.20, "%.1f%%" % (100.0 * float(nv["win_rate"]))) and ok
	if P.has("expert"):
		var e: Dictionary = P["expert"]
		ok = _check("Expert win rate 45–60%", float(e["win_rate"]) >= 0.45 and float(e["win_rate"]) <= 0.60, "%.1f%%" % (100.0 * float(e["win_rate"]))) and ok
		if P.has("random"):
			var gap: float = float(e["win_rate"]) - float((P["random"] as Dictionary)["win_rate"])
			ok = _check("Expert − random ≥ 40 points", gap >= 0.40, "%.1f points" % (100.0 * gap)) and ok
		ok = _check("Expert: everyone dead before day 15 in < 10%", float(e["wipe_before_15"]) < 0.10, "%.1f%%" % (100.0 * float(e["wipe_before_15"]))) and ok
		var worst: String = ""
		var worst_v: float = 0.0
		for c in (e["death_causes"] as Dictionary).keys():
			if float(e["death_causes"][c]) > worst_v:
				worst_v = float(e["death_causes"][c])
				worst = str(c)
		ok = _check("Expert: no cause > 40% of deaths", worst_v <= 0.40, "largest: %s %.0f%%" % [worst, 100.0 * worst_v]) and ok
		ok = _check("Expert makes 3–6 expeditions", float(e["trips_mean"]) >= 3.0 and float(e["trips_mean"]) <= 6.0, "mean %.1f, median %.1f" % [float(e["trips_mean"]), float(e["trips_median"])]) and ok
		ok = _check("Expert runs lost to dice with zero mistakes < 10%", float(e["dice_losses"]) < 0.10, "%.1f%% (zero-mistake losses of any kind: %.1f%%)" % [100.0 * float(e["dice_losses"]), 100.0 * float(e["zero_mistake_losses"])]) and ok
		ok = _check("Expert win-rate spread across distance quartiles ≤ 20 points", float(e["quartile_spread"]) <= 0.20, "%.1f points" % (100.0 * float(e["quartile_spread"]))) and ok
		ok = _check("Crafted items ≤ 25% of expert Used: credits", float(e["crafted_share"]) <= 0.25, "%.1f%%" % (100.0 * float(e["crafted_share"]))) and ok
		ok = _check("Expert median winning day 30–45", float(e["median_win_day"]) >= 30.0 and float(e["median_win_day"]) <= 45.0, "day %.1f (earliest %d)" % [float(e["median_win_day"]), int(e["earliest_win_day"])]) and ok
	return ok


func _print() -> void:
	print("SIM_REPORT fixtures=%d quartile edges (m)=%s" % [int(summary["fixtures"]), str(summary["quartile_edges_m"])])
	for p in (summary["policies"] as Dictionary).keys():
		var s: Dictionary = summary["policies"][p]
		print("  %-7s runs=%d win=%.1f%% med_loss_day=%.1f med_win_day=%.1f trips=%.2f trip_death=%.1f%% wipe<15=%.1f%% quartiles=%s causes=%s" % [
			p, int(s["runs"]), 100.0 * float(s["win_rate"]), float(s["median_loss_day"]), float(s["median_win_day"]), float(s["trips_mean"]),
			100.0 * float(s["trip_death_rate"]), 100.0 * float(s["wipe_before_15"]), _fmt_arr(s["quartile_win"]), _fmt_causes(s["death_causes"])])
		print("          endings=%s" % str(s["endings"]))
		print("          drama: rules/run=%.2f afflictions/run=%.2f maybe=%.1f%% stole=%.1f%% stranger=%.1f%%" % [
			float(s.get("rules_per_run", 0.0)), float(s.get("afflictions_per_run", 0.0)), 100.0 * float(s.get("maybe_rate", 0.0)),
			100.0 * float(s.get("stole_share", 0.0)), 100.0 * float(s.get("stranger_share", 0.0))])
	for c_v in checks:
		var c: Dictionary = c_v
		print("  [%s] %s — %s" % ["PASS" if bool(c["ok"]) else "FAIL", str(c["check"]), str(c["detail"])])


static func _fmt_arr(a: Array) -> String:
	var bits: Array[String] = []
	for v in a:
		bits.append("%.0f%%" % (100.0 * float(v)))
	return "[" + ", ".join(bits) + "]"


static func _fmt_causes(d: Dictionary) -> String:
	var bits: Array[String] = []
	var keys: Array = d.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(d[a]) > float(d[b]))
	for k in keys:
		bits.append("%s %.0f%%" % [str(k), 100.0 * float(d[k])])
	return ", ".join(bits)


## Regenerates the measured part of docs/BALANCE_REPORT.md; the hand-written tuning notes live
## in docs/balance/tuning_log.md and are included verbatim.
func _write_report(path: String) -> void:
	var P: Dictionary = summary["policies"]
	var md: String = "# Balance report — shelter phase (M1)\n\n"
	md += "_Measured by `tests/sim/sim_harness.gd` (the game's own rules, headless) and summarised by `tests/sim/sim_report.gd`. Regenerate with `tools/run_sim.sh`._\n\n"
	md += "**Setup.** %d runs per policy on %s difficulty, swept across %d cached OpenStreetMap home fixtures (no network), from city blocks to farmland. Distance quartile edges (walk to the nearest grocery or pharmacy): %s.\n\n" % [
		int((P.values()[0] as Dictionary)["runs"]), str(summary["difficulty"]), int(summary["fixtures"]), ", ".join((summary["quartile_edges_m"] as Array).map(func(v: Variant) -> String: return "none within 6 km" if float(v) >= 99999.0 else "%.0f m" % float(v)))]
	md += "## Targets\n\n| Check | Result | |\n|---|---|---|\n"
	for c_v in checks:
		var c: Dictionary = c_v
		md += "| %s | %s | %s |\n" % [str(c["check"]), str(c["detail"]), "✅" if bool(c["ok"]) else "❌"]
	md += "\n## Win rates and run length\n\n| Policy | Win rate | Median losing day | Median winning day | Earliest win | Median run (days) | Expeditions / run | Trip death rate |\n|---|---|---|---|---|---|---|---|\n"
	for p in ["random", "naive", "expert"]:
		if not P.has(p):
			continue
		var s: Dictionary = P[p]
		md += "| %s | %.1f%% | %.1f | %.1f | %d | %.1f | %.2f | %.1f%% |\n" % [p.capitalize(), 100.0 * float(s["win_rate"]), float(s["median_loss_day"]), float(s["median_win_day"]),
			int(s["earliest_win_day"]), float(s["median_run_days"]), float(s["trips_mean"]), 100.0 * float(s["trip_death_rate"])]
	md += "\n## Win rate by distance to the nearest store (quartiles)\n\n| Policy | Q1 (closest) | Q2 | Q3 | Q4 (farthest) | Spread |\n|---|---|---|---|---|---|\n"
	for p in ["random", "naive", "expert"]:
		if not P.has(p):
			continue
		var s: Dictionary = P[p]
		var qw: Array = s["quartile_win"]
		md += "| %s | %.0f%% | %.0f%% | %.0f%% | %.0f%% | %.0f points |\n" % [p.capitalize(), 100.0 * float(qw[0]), 100.0 * float(qw[1]), 100.0 * float(qw[2]), 100.0 * float(qw[3]), 100.0 * float(s["quartile_spread"])]
	md += "\n## Cause of death\n\n| Policy | Causes (share of all deaths) |\n|---|---|\n"
	for p in ["random", "naive", "expert"]:
		if P.has(p):
			md += "| %s | %s |\n" % [p.capitalize(), _fmt_causes((P[p] as Dictionary)["death_causes"])]
	md += "\n## When people die (all deaths, by day)\n\n| Policy | " + " | ".join(_bins()) + " |\n|---|" + "---|".repeat(_bins().size()) + "\n"
	for p in ["random", "naive", "expert"]:
		if not P.has(p):
			continue
		var dd: Dictionary = (P[p] as Dictionary)["death_days"]
		var row: Array[String] = []
		for b in _bins():
			row.append(str(int(dd.get(b, 0))))
		md += "| %s | %s |\n" % [p.capitalize(), " | ".join(row)]
	md += "\n## Drama (M2)\n\n| Policy | House Rules passed / run | Afflictions / run | Gamble endings | Stole from neighbours | Met a stranger |\n|---|---|---|---|---|---|\n"
	for p in ["random", "naive", "expert"]:
		if P.has(p):
			var dp: Dictionary = P[p]
			md += "| %s | %.2f | %.2f | %.1f%% | %.1f%% | %.1f%% |\n" % [p.capitalize(), float(dp.get("rules_per_run", 0.0)), float(dp.get("afflictions_per_run", 0.0)),
				100.0 * float(dp.get("maybe_rate", 0.0)), 100.0 * float(dp.get("stole_share", 0.0)), 100.0 * float(dp.get("stranger_share", 0.0))]
	md += "\n## Endings\n\n| Policy | Endings |\n|---|---|\n"
	for p in ["random", "naive", "expert"]:
		if P.has(p):
			md += "| %s | %s |\n" % [p.capitalize(), str((P[p] as Dictionary)["endings"]).replace("{", "").replace("}", "").replace("\"", "")]
	var log_txt: String = FileAccess.get_file_as_string("res://docs/balance/tuning_log.md")
	if log_txt != "":
		md += "\n" + log_txt
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(md)


static func _bins() -> Array[String]:
	var b: Array[String] = []
	for i in range(0, 60, 5):
		b.append("%02d-%02d" % [i, i + 4])
	return b
