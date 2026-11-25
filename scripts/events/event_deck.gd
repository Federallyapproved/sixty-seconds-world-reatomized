class_name EventDeck
extends RefCounted

## The daily dilemmas now come from data/events/*.json and are drawn and resolved by
## ShelterEvents (section 9). This class keeps the small helpers other screens use.


static func reset_state() -> void:
	pass


## The survivor who acts for the household: the leader if present and able, otherwise the oldest
## able survivor.
static func pick_actor() -> Dictionary:
	if GameState.shelter == null:
		for m_v in GameState.family_members:
			var m: Dictionary = m_v
			if bool(m.get("is_leader", false)) and bool(m.get("alive", false)):
				return m
		return {}
	return ShelterEvents.actor(GameState.shelter)


static func is_capable(m: Dictionary) -> bool:
	return bool(m.get("alive", false)) and str(m.get("loc", "shelter")) == "shelter" and int(m.get("morale", 5)) > 0


## True when one of these real place categories is among the expedition targets.
static func has_real_poi(cats: Array) -> bool:
	for p_v in GameState.nearby_pois:
		var p: Dictionary = p_v
		if bool(p.get("fictional", false)):
			continue
		if str(p.get("category", "")) in cats:
			return true
	return false


## Today's dilemma for the running shelter (drawn by ShelterSim.begin_day).
static func draw_daily_event(_day: int, _rng: RandomNumberGenerator) -> Dictionary:
	if GameState.shelter == null:
		return {}
	return GameState.shelter.today_event


static func resolve_event(_event_dict: Dictionary, choice_id: String, _rng: RandomNumberGenerator) -> Dictionary:
	if GameState.shelter == null:
		return {}
	var out: Dictionary = ShelterSim.choose(GameState.shelter, choice_id)
	return {"outcome_text": str(out.get("text", "")), "tags": out.get("tags", [])}
