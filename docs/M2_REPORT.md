# M2 — Events and drama

Branch `v3-m2-drama`, stacked on `v3-m1-foundation` (PR #7). Godot 4.3, GL Compatibility, web export.

## What changed

**Afflictions (section 7).** When someone's morale falls to 1 they say a one-line warning ("Maya, at the map: \"Sitting here is how we die.\""). If it reaches 0, on a later morning, never the one the warning is read, they turn **Selfish** (an extra ration at night, on the receipt), **Paranoid** (won't open the hatch for anyone, won't go out), **Reckless** (heads for the farthest place on the map if someone stays home) or **Withdrawn** (won't work). What the family is short of shapes which one. Cards, the console, pets and some events bring morale back; at 3 the affliction lifts. Names, warnings and onset lines are in `data/afflictions.csv`.

**House Rules.** Every 4 days a House meeting puts the next two rules on the table, with each one's bonus and cost on the card, or "No new rules": Finders eat first, Nobody opens the hatch, Work or don't eat, The sick sleep upstairs, Kids eat last, Occupied homes are fair game, The pet is an emergency ration. Each costs morale when passed and goes a little further than the last; the narrator remarks on each, and the ending lists them. Rules are rows in `data/house_rules.csv`.

**Moral choices.** About 30% of neighbours' houses are still lived in ("Lights at night: someone still lives here" in the planner). Arriving at one is a choice: knock and trade, leave them be, take their medicine while they sleep, or rob them with the rifle. Theft puts Guilt (a morale cap) on the explorer; days later the narrator brings it up and the house is marked "quiet now". Harming innocents ends the neighbourhood rescue, even one already under way.

**Strangers and gambles.** Rare strangers (one per run at most) met at real places, each with an item-gated option and a problem of their own. Two "maybe" endings let the family leave on a hope; the summary stamps them NOBODY KNOWS.

**Events.** 108 events (75 in M1): three strangers with their follow-ups, two gamble endings, moments for each affliction, Guilt that comes back, House Rule moments, events made likelier by the real places nearby (gas station, pharmacy, hardware store, school, church, police or fire station), dirty water, delayed consequences and family days. Every event now has two options that need no item (section 8), options that open the hatch are marked so Paranoid survivors and the hatch rule can grey them, and contagion events stay away under "The sick sleep upstairs". 70 of 108 events (65%) have an item option, down from 84%.

**End of run.** The summary's run report shows the MVP items (with what each did), what was missing when it counted, each death as its chain of causes with the turning point highlighted, the House Rules passed and the achievements unlocked; the house and strike cards are one click away.

**Survival Almanac.** Every core item has a page that fills in as you play: what it was seen doing and the options it opened. Items you have never found stay greyed out, and their options stay hidden in the shelter; found-but-missing items show as greyed "Needs: X". Saved in `user://almanac.json`.

**Achievements.** 33, each tied to a decision (none for surviving N days), with an unlock toast and an Achievements screen; saved in `user://achievements.json`. Demo runs and test scripts never write either file.

## Measured

From `docs/BALANCE_REPORT.md`: 10,000 runs per policy on Normal over the 37 cached homes, with the M2 rules and content. Every section-6 target is met.

| Check | Target | M1 | M2 |
|---|---|---|---|
| Random win rate | ≤ 5% | 0.1% | 0.0% |
| Naive win rate | 10–20% | 11.1% | 14.9% |
| Expert win rate | 45–60% | 49.2% | 56.5% |
| Expert: largest cause of death | ≤ 40% | sickness 38% | thirst 39% |
| Expert: everyone dead before day 15 | < 10% | 1.4% | 0.3% |
| Expert expeditions per run | 3–6 | 5.2 | 4.4 |
| Expert losses to dice, zero mistakes | < 10% | 5.1% | 0.0% |
| Expert spread across store-distance quartiles | ≤ 20 points | 4.7 | 5.6 |
| Expert median winning day | 30–45 | 38 | 38 (earliest 27) |

Expert endings: airlift 35%, convoy 21%, neighbourhood 1%, gang takeover 19%, everyone dead 20%, no adult left 4%. Drama per run (expert / naive / random): House Rules passed 1.9 / 0 / 2.5, afflictions 0.28 / 0.52 / 0.77, a stranger met in 29% / 25% / 14% of runs; random play takes a gamble ending in 0.3% of runs and steals from neighbours in 9%.

Story and Hard (2,000 runs per policy): expert 81% / 18%, naive 19% / 7%, random 0.2% / 0.1% (M1: expert 69% / 10%).

Tuning (passes 15–18 in `docs/balance/tuning_log.md`): the new events made the game easier (expert 59%, naive 19%) and handed out more cures, so thirst became 45% of expert deaths. Old wounds and weak bodies now fall sick more often, searches find 75% instead of 80%, "Nobody opens the hatch" costs 2 morale (it also blocks the water trades at the door), trips are a little riskier, and the harness counts an unanswered gang (20–30 days of warnings) as a mistake rather than bad luck.

## Tests

All run on this branch with Godot 4.3. Checks that changed meaning under the M2 rules name the check they replace; none were removed.

| Suite | M1 (PR #7) | M2 |
|---|---|---|
| Data validator | 74 events, 0 errors | 108 events, 7 House Rules, 4 afflictions, 33 achievements, 0 errors |
| `tests/m2/drama_suite.gd` (new) | — | 60 passed |
| `tests/m2/achievements_suite.gd` (new: every achievement earned through game calls) | — | 36 passed |
| `tests/m1/data_pipeline_suite.gd` | 115 passed | 116 passed (adds the two-no-item-options rule) |
| `tests/m1/shelter_rules_suite.gd` | 60 passed | 60 passed (trip risk read from the data; reachability also checks conditions) |
| `tests/pass2/systems_gauntlet.gd` | 127 passed | 127 passed (long runs capped at 120 days, like the harness) |
| `tests/critic_60s_audit.gd` | 78 passed | 78 passed (3G: warning, then an affliction) |
| `tests/critic_qa_audit.gd` | 32 passed | 32 passed |
| `tests/critic_osm_audit.gd` | 48 passed | 48 passed (the loot check uses an empty neighbour's house) |
| `tests/pass2/play_shelter.gd` (12 days through real key and mouse events) | 22 checks | 30 checks: House meetings answered with keys, an affliction shown after its warning, an achievement toast, hidden options for undiscovered items |
| compile_all · floorplan_stress | clean · 4,316 | clean · 4,305 |
| Web export, then the `.pck` run headless | title → day-7 summary | title → day-7 summary; the Almanac and Achievements screens open from the pack |

Fixed along the way: the screenshot script stalled when a morning opened with a cinematic (someone coming home); harming innocents now also ends a neighbourhood rescue already under way; afflicted and guilty survivors are the `{subject}` of their events.

## Known limits

- Meta-progression unlocks (family setups, starting scenarios, extra rules and strangers) are listed in section 14 but not built yet; the `unlocks` column in `achievements.csv` is empty. Planned with replayability in M6.
- The narrator does not yet get quieter as morale drops (section 15); narration and voice are M6.
- Afflictions come from the four rules above only; there is no "virtue" side (Darkest Dungeon's resolve) in M2.
- 65% of events have an item option; the design asks for about 40%. Every rescue request is item-gated by design (28 events), and getting to 40% would take about 60 more events without one.
- Thirst is 39% of expert deaths, just under the 40% limit; water is the tightest resource and new content that costs water should be checked with the harness.
- Gang takeovers end 19% of expert runs (15% in M1). They always follow days of "Noticed" raids and a warning, and the harness expert never saves a weapon for that night, so humans should lose fewer this way.
- Hard is tough for the heuristic expert (18%); it deserves a human play test before M3 adds crafting.
