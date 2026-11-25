extends Node

## Prints one simulated run day by day (debugging the policies and the rules).
## godot --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/sim_trace.gd --policy=expert --seed=5 --fixture=0

func run() -> int:
	var policy: String = "expert"
	var seed_v: int = 5
	var fi: int = 0
	var diff: String = "normal"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--policy="):
			policy = a.substr(9)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--fixture="):
			fi = int(a.substr(10))
		elif a.begins_with("--difficulty="):
			diff = a.substr(13)
	var fixtures: Array = preload("res://tests/sim/sim_harness.gd").load_fixtures()
	var fx: Dictionary = fixtures[fi % fixtures.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var haul: Dictionary = SimPolicies.grab(policy, rng, SimPolicies.grab_budget(diff))
	print("FIXTURE ", fx["id"], " nearest ", fx["nearest_essential_m"], " haul ", haul)
	var s: ShelterState = ShelterSim.new_run({"members": SimPolicies.default_family(), "haul": haul, "places": fx["targets"],
		"rad_factors": fx["rad_factors"], "h1_home_msv": float(fx["h1_home_msv"]), "difficulty": diff, "seed": seed_v ^ 0x51F7})
	print("fallout clears day ", s.fallout_clear_day)
	for p_v in s.places:
		var p: Dictionary = p_v
		print("  place %d %s %s %.0fm stock=%s" % [int(p["idx"]), str(p["category"]), str(p["name"]), float(p["walk_m"]), str(p["stock"])])
	while not s.is_over() and s.day < 120:
		var m: Dictionary = ShelterSim.begin_day(s)
		print("--- DAY %d  food=%d water=%d stock=%s broken=%s followed=%s chains=%s" % [s.day, s.food(), s.water(), str(s.stock), str(s.broken), str(s.followed), str(ShelterChains.progress(s).map(func(c: Dictionary) -> String: return "%s:%s%d/%d@%d" % [c["chain"], c["state"], c["step"], c["steps"], c["next_day"]]))])
		for l in m["morning"]:
			print("    ", (l as Dictionary)["text"])
		if s.is_over():
			break
		if not s.today_event.is_empty():
			var oid: String = SimPolicies.pick_option(s, policy, rng)
			var out: Dictionary = ShelterSim.choose(s, oid)
			print("  EVENT %s -> %s: %s" % [s.today_event["id"], oid, out.get("text", "")])
			for l in out.get("lines", []):
				print("      ", (l as Dictionary)["text"])
		var plan: Dictionary = SimPolicies.make_plan(s, policy, rng)
		for mid in (plan["jobs"] as Dictionary).keys():
			print("  JOB ", mid, " ", plan["jobs"][mid])
		var people: Array[String] = []
		for mm in s.living():
			people.append("%s(dww%d dwf%d %s m%d)" % [mm["name"], mm["dww"], mm["dwf"], ShelterSim.status_text(mm, s.day), mm["morale"]])
		print("  people: ", ", ".join(people))
		ShelterSim.end_day(s, plan)
	print("END ", s.ending, " day ", s.ending_day, " trips ", s.stats["trips"], " mistakes ", s.stats["mistakes"].size())
	return 0
