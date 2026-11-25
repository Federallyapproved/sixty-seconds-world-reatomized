class_name DataSchema
extends RefCounted

## Shared vocabulary for the content pipeline: what the tables and event files may contain.
## The validator (DataBuilder) and the shelter rules (ShelterEvents) both read these lists, so a
## new effect or condition is added in one place.

const ITEM_CATEGORIES: Array[String] = ["core", "junk", "makeshift"]

const EVENT_TYPES: Array[String] = [
	"visitor", "raid", "sickness", "quake", "contamination", "pests", "cabin_fever", "trade",
	"stranger", "moral", "house_rule", "dirty_water", "rescue", "trip", "hunting", "weather",
	"discovery", "pet", "warning", "family", "chain_followup",
]

const EVENT_MOODS: Array[String] = ["bad", "good", "neutral"]

## Effect operations an event option may apply (see ShelterEvents.apply_effect).
const EFFECT_OPS: Array[String] = [
	"add",          # {item, n}: gain n items (food/water: cans of 4 rations)
	"lose",         # {item, n}: lose n items (food/water: cans)
	"rations",      # {kind: food|water, n}: gain or lose single rations
	"use",          # {item, mode?}: the item does its job (axe breaks on stop, rifle spends ammo...)
	"give",         # {item}: hand the item over (gift or trade)
	"break",        # {item}: the item breaks
	"break_fragile",# {p}: a quake breaks one fragile item (gas mask, flashlight or radio)
	"repair",       # {item?}: the manual repairs a broken item (85%; map 50% and may destroy both)
	"sick",         # {who}
	"injure",       # {who}
	"cure",         # {who}
	"kill",         # {who, cause}: only in events that declare a warning
	"morale",       # {who, n}
	"dose",         # {who, msv}
	"tired",        # {who, days}
	"refuse_trip",  # {who, days}
	"chance",       # {p, then: [...], else: [...]}
	"followed",     # {p?}: the shelter is noticed (raids start)
	"unfollow",     # the gang gives up
	"schedule",     # {event, in}: a follow-up event in `in` days
	"warn",         # {kind}: a warning that makes a fatal event possible later
	"chain",        # {chain, step: start|advance|miss|win|lose}
	"pet",          # {kind: dog|cat}
	"pet_leaves",   # {}
	"steal",        # {n}: raiders take n supply units
	"trip_loot",    # {item, n}: adds to the haul of the expedition in progress
	"supply_drop",  # {category, items: {item: n}}: stock appears at a real place nearby
	"reveal_cache", # {items: {item: n}}: a cache marked on the map; collected on the next trip
	"lose_run",     # {ending}: only in events that declare a warning
	"guilt",        # {who}: a morale cap (moral choices)
	"flag",         # {set|clear}
	"fallout_news", # the radio announces the all-clear early
	"house_quiet",  # marks a neighbour's house as quiet
	"junk",         # {item, n}: crafting junk (M3); ignored until junk exists
	"say",          # {text}: an extra receipt line (e.g. inside a chance branch)
	"drain",        # {category: [...], share}: unseen survivors strip a share of those stores
]

const WHO: Array[String] = ["actor", "explorer", "random", "all", "weakest", "sickest", "thirstiest", "child", "adult", "subject"]

const CONDITION_KEYS: Array[String] = [
	"min_day", "max_day", "needs_place", "needs_away", "trip_place", "needs_followed", "not_followed",
	"needs_fallout_clear", "needs_heavy_fallout", "needs_flag", "not_flag", "needs_owned", "needs_missing",
	"needs_pet", "no_pet", "needs_sick", "needs_injured", "needs_child", "needs_low_morale", "min_people",
	"needs_broken", "needs_chain_active", "after_escalation",
]

const TEXT_TOKENS: Array[String] = [
	"{name}", "{n}", "{day}", "{home}", "{street}", "{area}", "{place}", "{nearest_school}",
	"{nearest_pharmacy}", "{nearest_grocery}", "{nearest_hardware}", "{nearest_church}",
	"{nearest_clinic}", "{nearest_fuel}", "{subject}", "{food_label}",
]

const CHAINS: Array[String] = ["convoy", "neighbourhood", "airlift"]

const ALLOWED_LICENSES: Array[String] = ["CC0", "CC-BY-3.0", "CC-BY-4.0", "OGA-BY-3.0", "MIT", "Apache-2.0"]

## 1950s leftovers that must not come back, and brand names we never print in our own text.
const BANNED_WORDS: Array[String] = [
	"CONELRAD", "Civil Defense", "Civil Defence", "1958", "vacuum-tube", "vacuum tube", "DDT",
	"Duck and Cover", "atomic age", "Atomic Age", "Tomato Soup", "Fireman's Axe", "Scout Handbook",
	"harmonica", "Harmonica", "checkers", "Checkers", "toolbox", "Toolbox", "Sharikov", "Vault",
]
const BANNED_BRANDS: Array[String] = [
	"Nintendo", "Game Boy", "PlayStation", "Xbox", "Coca-Cola", "Pepsi", "Amazon", "Alexa",
	"Roomba", "iPhone", "Google", "Apple", "Starbucks", "McDonald", "Walmart", "Uber", "DoorDash",
	"Netflix", "Tesla", "TikTok", "Instagram", "Facebook", "YouTube", "Campbell", "Heinz",
	"Pip-Boy", "Nuka", "Spam", "Duracell", "Energizer", "Maglite", "Coleman", "Ziploc",
]
