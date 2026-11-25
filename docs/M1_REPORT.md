# M1 — Foundation and balance

Branch `v3-m1-foundation` (from `main`, with PR #5's wider store search merged in). Godot 4.3, GL Compatibility, web export.

## What changed

**Content pipeline (section 11).** Items, loot, balance numbers, narration, the asset manifest and (empty, for M2/M3) house rules, achievements, parts and recipes are CSV tables in `data/`; events are JSON in `data/events/`. `tools/build_data.gd` compiles them to `data/build/*.json`, regenerates `CREDITS.md`, and fails on any validation error. `docs/ADDING_CONTENT.md` is the one-page recipe. Icons are game-icons.net SVGs, recoloured by `tools/recolor_icons.gd`.

**The 16 core items (section 5)**, one row each: canned food (4 rations, random generic labels), water (4 rations), axe, rifle, ammo, padlock, bug spray, survival manual, medkit (2 slots), suitcase (3 slots, +3 carry), hand-crank radio, gas mask, flashlight, map, cards, and a game console. Toolbox, checkers, harmonica and the car parts are gone from the grab. Every item shows "Name [slots] — purpose" wherever it appears.

**A new shelter engine** (`scripts/shelter/`). The rules are pure code that never reads the `GameState` autoload, so the game and the balance harness run the same calls:
- **Survival:** thirsty on day 3 without water, dehydrated on day 4, a 50% death roll on day 5, death on day 6. Hungry on day 6 without food, starving on day 8, death on day 10. Untreated sickness turns Diseased on day 7, rolls 10%/day from day 10 and kills by day 18. A medkit always cures, followed by a relapse window. Acute radiation sickness comes from the 7-day dose (the existing RadiationModel stages).
- **Expeditions to real places:** days = 1 + ceil(round-trip km / 6), clamped 2–7, and a map takes a day off. 25% of trips come back 1–2 days late. The chance of never returning is 1 − (1 − p)^days, with every multiplier listed in the preview. In heavy fallout, people come back sick 20% of the time with a gas mask and 70% without. Carry is 2 slots, 5 with the suitcase. Stock is finite and persistent per building, each carried item has a 10% chance of breaking or being lost, and a trip of 3+ days leaves the explorer Tired. Explorers can be followed home.
- **Pressure clocks:** unseen survivors drain every store by 5–10% a day (groceries and pharmacies fastest). Being followed brings raids every 3 days, which the rifle, axe or padlock stop, each the way its row says. If raids go unresolved for 20–30 days, the gang tries to take the shelter, with a warning the morning before. Black Rain and Empty Shelves events start around day 8.
- **Rescue chains:** convoy (radio → radio → map → flashlight → the knock), neighbourhood shelter (starts at a real church or school after the all-clear), and airlift (flashlight → gas mask → map → lift). There is no contact before the all-clear (day 7–20), requests come 3–6 days apart, and a missed request comes back once, as a different event, 6–10 days later. Nothing lands before day 25.
- **Fairness:** no event repeats, at most two bad events in a row, a fatal event only after its warning appeared on an earlier day, and a cause chain on every death.
- **Difficulty:** Story (generous stock, exact odds everywhere), Normal, and Hard (30 s grab, 3 s recon, faster drain, raids every 2 days).

**Events (section 9):** 74 data-driven events, including the 12 Appendix A vignettes and every rescue request and retry. Every core item gates at least 3 events, and every item-gated event has a costly no-item option.

**The shelter screen (section 3)** is one screen per day: the morning receipt, today's dilemma card (item options tagged with their icon; missing items greyed "Needs: X" with the stakes underneath), a ration row per person with Give/Skip and tomorrow's preview ("Skip water: Sam is thirsty tomorrow (day 3 without)"), Treat, and Rest or Trip, then End Day. Trips are planned in a map-and-list planner with the risk preview: walking time, trip days, the never-return band (exact on Story), dose band, sickness on return, likely loot, last stocked, rumours, the tool needed, and the chance of being followed.

**Modern setting (section 4):** CONELRAD, Civil Defense, 1958, vacuum tubes, DDT and the rest are gone. The UI is an emergency-alert / phone look, the default family is Sam, Priya, Maya and Leo, the mutation perk and the "insane" states are off (tone guide), and the car escape is kept behind `GameState.FEATURE_CAR_ESCAPE = false`.

## Measured

From `docs/BALANCE_REPORT.md` (10,000 runs per policy, Normal, 37 cached OpenStreetMap homes from city blocks to farmland; regenerate with `tools/run_sim.sh`). Every section-6 target is met:

| Check | Target | Result |
|---|---|---|
| Random win rate | ≤ 5% | 0.1% (median death day 17) |
| Naive win rate | 10–20% | 11.1% |
| Expert win rate | 45–60% | 49.2% |
| Expert − random | ≥ 40 points | 49.1 points |
| Expert: everyone dead before day 15 | < 10% | 1.4% |
| Expert: largest single cause of death | ≤ 40% | sickness 38% |
| Expert expeditions per run | 3–6 | mean 5.2, median 5 |
| Expert losses to dice with zero mistakes | < 10% | 5.1% |
| Expert spread across store-distance quartiles | ≤ 20 points | 4.7 points |
| Expert median winning day | 30–45 | day 38 (earliest 27) |

Expert endings: airlift 31%, convoy 16%, neighbourhood 2.5%, gang takeover 15%, everyone dead 28%, no adult left 7%. The tuning passes that got there (expert 12% → 49%) are in `docs/balance/tuning_log.md`.

**Story and Hard** (2,000 runs per policy each; `docs/balance/sim_summary_story.json`, `sim_summary_hard.json`). The section-6 targets are for Normal; these show the spread around it.

| Policy | Story | Normal | Hard |
|---|---|---|---|
| Random | 0.3% | 0.1% | 0.0% |
| Naive | 17.7% | 11.1% | 3.2% |
| Expert | 69.3% | 49.2% | 10.3% |
| Expert median winning day | 37 | 38 | 38 |
| Expert: everyone dead before day 15 | 0.0% | 1.4% | 8.5% |

Hard is brutal for the heuristic expert: the simulated grab gets 7 slots of items instead of 12, stock drains faster and raids come every 2 days, so thirst and starvation become the main killers (34% and 31% of expert deaths). It is meant for players who already beat Normal; whether 10% is too low for a skilled human is worth a play test before M2 retunes it.

**The grab** (`tests/pass2/bot_difficulty_probe.gd`, a greedy bot on 12 real houses): Normal keeps 59% of the house's value on average and saves the whole family in 10 of 12; Hard keeps 26% and saves everyone in 6 of 12. No run clears a house.

## Tests

All run against this branch on Godot 4.3 (commands in the README). Pre-M1 suites were ported to the new rules; each changed check names the check it replaced, and checks whose rule no longer exists are listed with the reason in the suite (none removed silently).

| Suite | `main` before | This branch |
|---|---|---|
| Data validator (`tools/build_data.gd --check`) | — | 16 items, 74 events, 15 narration lines, 11 loot tables, 0 errors |
| `tests/m1/data_pipeline_suite.gd` (validator, build freshness, banned words, manifest) | — | 115 passed, 0 failed |
| `tests/m1/shelter_rules_suite.gd` (survival, items, trips, clocks, rescue timing, fairness over 600 runs) | — | 60 passed, 0 failed |
| `tests/pass2/systems_gauntlet.gd` | 127 passed | 127 passed, 0 failed (ported) |
| `tests/pass2/compile_all.gd` · `floorplan_stress.gd` | — | every script compiles · 4,316 floorplan checks passed |
| `tests/critic_60s_audit.gd` | 98 passed, 1 failed | 78 passed, 0 failed |
| `tests/critic_qa_audit.gd` (incl. 10 fuzzed 35-day runs and the demo) | 31 passed, 1 failed | 32 passed, 0 failed |
| `tests/critic_osm_audit.gd` (real presets, real trips) | — | 48 passed, 0 failed |
| `tests/pass2/play_shelter.gd` (12 days through real key and mouse events) | — | 22 checks passed, 0 failed |
| `tests/m1/capture_shelter.gd` (screens) | — | 9 screens captured |
| Web export, then the exported `.pck` run headless through the demo | — | Exported, then the `.pck` played every screen from title to the day-7 summary with no errors |

Found and fixed in the final verification pass:
- The shelter engine borrowed two helpers from `RadiationModel`, which reads the `GameState` autoload, so headless test scripts compiled with errors before recovering. The radiation-sickness stages now live in `ShelterSim`; the engine uses no autoload at all.
- That compile error had made the QA audit skip its grab-capacity checks (30 of 32 ran). Test scripts now load autoload-dependent scripts at run time (rule 3 in `ARCHITECTURE.md`).
- "Knows the Area" only raised the search share, which never mattered once the bag was full. A scout now carries one more slot home (`scout_extra_carry`).

## Media

Before/after screenshots (shelter day, trip planner, grab, strike, house select), a demo video and a keyboard-and-mouse shelter video are on the preview page, `/next/media.html`.

## Known limits

- The trip planner's map is the existing 2D OSM view; first-person interiors come in M5.
- Morale exists (0–10, with named sources) but afflictions, House Rules, moral fallout and strangers are M2; Craft and Study jobs are M3. `house_rules.csv`, `achievements.csv`, `parts.csv` and `recipes.csv` are header-only.
- The harness expert is a heuristic, not an optimal player; gang takeovers end 15% of expert runs (always warned the morning before).
- The neighbourhood rescue needs a real church or school nearby and a visit after the all-clear, so it is the rarest ending (2.5% of expert runs).
- The pre-existing "Demo AI ... dives in before 0.0s" check in the 60-second audit depends on wall-clock timing and fails now and then (it failed on `main` too); it passed in the final runs.
- Fixtures are US neighbourhoods; other countries' OSM tagging hasn't been measured.
- The narrator lines are text only (`narration.csv`, status pending); the voice is chosen in M6.
