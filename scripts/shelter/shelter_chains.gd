class_name ShelterChains
extends RefCounted

## Rescue chains (section 6). No contact before the fallout all-clear (day 7-20). Each chain is a
## run of item requests 3-6 days apart; a missed request pushes the chain back 6-10 days, and a
## chain that is missed three times goes silent. The final request can't land before
## `rescue_earliest_day`.
##
## convoy         radio contact -> radio roll call -> map grid square -> flashlight signal -> the knock
## neighbourhood  starts when someone reaches a real church, school or community centre after the
##                all-clear; locked for good if the family harmed innocents
## airlift        rotor noise over the roofs; flashlight, gas mask and map get the family out
##
## Step events live in data/events/rescue_*.json with "chain" and "step" fields.

## A missed request comes back once, as a different event (no event repeats in a run); a second
## miss and the contact goes silent.
const MAX_MISSES: int = 1


static func init(s: ShelterState) -> void:
	s.chains = {}
	for cid in DataSchema.CHAINS:
		s.chains[cid] = {"state": "idle", "step": 0, "steps": _steps(cid), "next_day": 0, "misses": 0, "place_idx": -1}
	var clear: int = s.fallout_clear_day
	var c: Dictionary = s.chains["convoy"]
	c["state"] = "active"
	c["step"] = 1
	c["next_day"] = clear + s.rng.randi_range(ShelterData.Bi("rescue_contact_delay_min", 2), ShelterData.Bi("rescue_contact_delay_max", 5))
	var a: Dictionary = s.chains["airlift"]
	a["state"] = "active"
	a["step"] = 1
	a["next_day"] = clear + s.rng.randi_range(5, 10)


static func _steps(cid: String) -> int:
	var n: int = 0
	for ev_v in ShelterData.events().values():
		var ev: Dictionary = ev_v
		if str(ev.get("chain", "")) == cid and not bool(ev.get("retry", false)):
			n = maxi(n, int(ev.get("step", 0)))
	return n


## The event id of the rescue request due today, if any (one per day; others wait a day).
static func due_event(s: ShelterState) -> String:
	var ids: Array = s.chains.keys()
	ids.sort()
	var picked: String = ""
	for cid in ids:
		var c: Dictionary = s.chains[cid]
		if str(c["state"]) != "active" or int(c["next_day"]) > s.day:
			continue
		if picked != "":
			c["next_day"] = s.day + 1
			continue
		var eid: String = _event_for(str(cid), int(c["step"]), int(c["misses"]) > 0)
		if eid == "":
			continue
		var ev: Dictionary = ShelterData.event(eid)
		if bool(ev.get("final", false)) and s.day < ShelterData.Bi("rescue_earliest_day", 25):
			c["next_day"] = ShelterData.Bi("rescue_earliest_day", 25)
			continue
		if ShelterEvents.actor(s).is_empty():
			c["next_day"] = s.day + 1
			continue
		picked = eid
	return picked


static func _event_for(cid: String, step: int, retry: bool) -> String:
	var fallback: String = ""
	for ev_v in ShelterData.events().values():
		var ev: Dictionary = ev_v
		if str(ev.get("chain", "")) == cid and int(ev.get("step", 0)) == step:
			if bool(ev.get("retry", false)) == retry:
				return str(ev["id"])
			fallback = str(ev["id"])
	return fallback


## Daily housekeeping: the neighbourhood chain opens when a trip reached a real community place
## after the all-clear.
static func tick(s: ShelterState) -> void:
	var nb: Dictionary = s.chains.get("neighbourhood", {})
	if nb.is_empty() or str(nb["state"]) != "idle":
		return
	if s.harmed_innocents:
		return
	for p_v in s.places:
		var p: Dictionary = p_v
		if str(p["category"]) in ["church", "school"] and not bool(p.get("fictional", false)) and int(p["visits"]) > 0 and int(p["last_visit_day"]) >= s.fallout_clear_day:
			nb["state"] = "active"
			nb["step"] = 1
			nb["place_idx"] = int(p["idx"])
			nb["next_day"] = s.day + s.rng.randi_range(1, 3)
			s.say("good", "At %s someone wrote down the family's name and promised to be in touch." % ShelterTrips.place_label(p))
			return


static func step(s: ShelterState, cid: String, what: String, _ctx: Dictionary) -> void:
	var c: Dictionary = s.chains.get(cid, {})
	if c.is_empty():
		return
	match what:
		"start":
			if str(c["state"]) == "idle":
				c["state"] = "active"
				c["step"] = 1
				c["next_day"] = s.day + s.rng.randi_range(ShelterData.Bi("rescue_gap_min", 3), ShelterData.Bi("rescue_gap_max", 6))
		"advance":
			c["step"] = int(c["step"]) + 1
			c["misses"] = 0
			c["next_day"] = s.day + s.rng.randi_range(ShelterData.Bi("rescue_gap_min", 3), ShelterData.Bi("rescue_gap_max", 6))
			if int(c["step"]) > int(c["steps"]):
				c["state"] = "done"
		"miss":
			c["misses"] = int(c["misses"]) + 1
			if int(c["misses"]) > MAX_MISSES:
				c["state"] = "failed"
				s.say("lost", "The %s contact has gone silent." % _chain_word(cid))
			else:
				c["next_day"] = s.day + s.rng.randi_range(ShelterData.Bi("rescue_miss_delay_min", 6), ShelterData.Bi("rescue_miss_delay_max", 10))
				s.say("warn", "The %s request went unanswered. They'll try once more in a week or so." % _chain_word(cid))
		"win":
			c["state"] = "done"
			ShelterSim.finish(s, "rescue_" + cid)
		"lose":
			c["state"] = "failed"


static func _chain_word(cid: String) -> String:
	match cid:
		"convoy": return "convoy"
		"neighbourhood": return "neighbourhood shelter"
		"airlift": return "helicopter"
	return cid


## Progress for the shelter screen: [{chain, step, steps, state, next_day}].
static func progress(s: ShelterState) -> Array:
	var out: Array = []
	for cid in s.chains.keys():
		var c: Dictionary = s.chains[cid]
		out.append({"chain": str(cid), "label": _chain_word(str(cid)), "step": int(c["step"]), "steps": int(c["steps"]), "state": str(c["state"]), "next_day": int(c["next_day"])})
	return out
