# M3 — Crafting and salvage

Branch `v3-m3-crafting`, stacked on `v3-m2-drama` (PR #9). Godot 4.3, GL Compatibility, web export.

## What changed

**Junk and parts.** Eleven pieces of junk (a toaster, pots and pans, an old phone, a smart speaker, a bedsheet, an umbrella, a bag of bottles, cleaning spray, hand sanitizer, duct tape, an extension cord) turn up in the house grab, in stores and in neighbours' homes, take carry slots, and say what they break into when aimed at ("Toaster [2] → 2 Metal, 1 Electronics"). Each place type stocks its own: hardware stores Metal and Binding, pharmacies Chemicals and Cloth, supermarkets Plastic, phone and electronics shops Electronics (now fetched from OpenStreetMap too), homes a little of everything. The shelter also has its own box marked CABLES, MISC (it was already drawn in the backdrop): an extension cord, duct tape and usually a bedsheet. Junk and broken gear (a radio, an axe, a gas mask…) come apart at the **Bench** into six parts — Cloth, Metal, Electronics, Plastic, Binding, Chemicals — each with its own shape and colour for colour-blind players. The part shelf holds 12; what doesn't fit is thrown out, and the receipt says so.

**The bench.** Each survivor's job button now opens Rest, Trip…, Craft… or Study…, with the reason when one isn't possible. A day at the bench is two **Quick** recipes or one **Day** recipe, and no trip. Twelve recipes make **Makeshift** things, weaker than the real ones and taped together on their icons:

| Recipe | What it does (compared with the real item) |
|---|---|
| Rag Bandage | Closes a wound; does nothing for a fever (the medkit cures both). Used from the Treat button, which saves the medkit. |
| Bedsheet Bindle | +2 carry for 2 trips (the suitcase gives +3 for good). |
| Patch Job | A broken item works once more (the manual repairs it for good); its use counts as makeshift. |
| Bottle Filter | Up to 4 rations of dirty water a night become water, 3 times. |
| Rag Respirator | In heavy fallout: sick on return 45% instead of 70%, trip risk ×1.5 instead of ×2, for 2 trips (the gas mask: 20%). |
| Door Barricade | Goes first at the hatch: stops one raid 60% of the time, then breaks (the padlock stops 100%). |
| Tin-Can Alarm | A silent night theft becomes a choice the next morning ("Cans in the Dark"); works twice. |
| Pipe Club | Stops a raid 50% of the time and breaks 50% of the time (before the axe is risked). |
| Phone Torch | Stands in for the flashlight in dark moments, twice; can't signal a rescue. |
| Scrap Receiver | Hears the all-clear on half the days; can't transmit, so no rescue. |
| Soap Spray | Stands in for bug spray: works 65% of the time, once. |
| Sock Puppet Show | +1 morale for everyone, once. |

Crafting fails 20% of the time, 5% while the manual is on the shelf, 15% more for an injured or sick crafter; a failure gives back half the parts. Tools are never used up, but a Day recipe wears the axe. Only one door barricade, tin-can alarm or pipe club at a time. **Makeshift items never meet rescue or ending conditions:** they can't answer a rescue step (the validator rejects it), stop the gang's takeover, or signal anyone.

**Stand-ins in events.** Event options can accept a makeshift stand-in (`"alt"` in the event data): the soap spray on the four pest events, the phone torch when the lights go out, sock puppets where the console would do, the rag respirator for the vent jobs, the bindle for packing, and so on (21 options). When only the stand-in is on hand it replaces the greyed "Needs: X" option, with its odds on the card; when both are, the card shows both so the real one can be saved. A stand-in that fails is spent anyway and the costly no-item option happens instead.

**Learning.** Three recipes are known; the rest are in the survival manual's four chapters (Water and Air, Home Security, Radio and Light, Morale and Pests). A day of **Study** with the manual learns one for the rest of the run. **Pamphlets** found on trips (a water-safety flyer at a pharmacy, a home-security flyer at a hardware store…) do it without the manual; a duplicate becomes one random part. Lose the manual and the recipes stay, but failure goes back to 20%.

**The workbench screen.** Cards always read in the same order: what it's for; "Makeshift X" with the comparison; uses and failure %; the parts you have and need (with the place types that supply missing ones); tool and time. By default only recipes you can make or are one part short of are shown; locked ones are silhouettes with their source ("Manual Ch.2 / home-security flyer"). The **Need** toggle tags a recipe's missing parts: junk holding them is looted first on trips, listed in the trip planner, and ringed in the next run's house grab.

**New pressure and supply.** Night thieves (from day 6, 3% a night, more when the shelter is Noticed) take two rations of food, or water when the food is gone, or one small thing, in silence. Rain fills a bucket under the vent with dirty water (about one night in eight), and three new events bring more (the toilet tank, rain on the vent, a bucket of grey water you can drink at a risk).

**Content.** Six new events (114 in all): rain on the vent, the toilet tank, a bucket of grey water, sharp edges at the bench, cans in the dark, and an opening-night puppet show; the seed vignette with the phone now leaves an old phone on the shelf. Three new achievements (36): Arts and Crafts (rescued after using 5 makeshift items), Night School (all four chapters), Read the Small Print (a chapter from a pamphlet). The Almanac has Junk and Makeshift tabs, and a makeshift page shows its recipe. The run report adds a Workbench line.

## Measured

From `docs/BALANCE_REPORT.md`: 10,000 runs per policy on Normal over the 37 cached homes, with the M3 rules and content. Every section-6 target is met.

| Check | Target | M2 | M3 |
|---|---|---|---|
| Random win rate | ≤ 5% | 0.0% | 0.1% |
| Naive win rate | 10–20% | 14.9% | 11.1% |
| Expert win rate | 45–60% | 56.5% | 54.1% |
| Expert: largest cause of death | ≤ 40% | thirst 39% | thirst 39% |
| Expert: everyone dead before day 15 | < 10% | 0.3% | 0.4% |
| Expert expeditions per run | 3–6 | 4.4 | 4.5 |
| Expert losses to dice, zero mistakes | < 10% | 0.0% | 0.0% |
| Expert spread across store-distance quartiles | ≤ 20 points | 5.6 | 7.7 |
| Expert median winning day | 30–45 | 38 (earliest 27) | 38 (earliest 26) |
| Crafted items' share of expert "Used:" credits | ≤ 25% | — | 1.8% |
| The same for the crafter (an expert that grabs junk and works the bench every free day) | ≤ 25% | — | 6.0% (2.0 items made per run) |

Expert endings: airlift 33%, convoy 19%, neighbourhood 1%, gang takeover 19%, everyone dead 23%, no adult left 4%, still waiting at day 120 0.8%. At the bench (expert / crafter / random, per run): 0.8 / 2.0 / 0.7 makeshift items made, 0.2 / 0.1 / 0.2 failed, 1.7 / 3.1 / 1.5 pieces of junk taken apart, 1.1 / 3.4 / 0.9 manual chapters learned (1.1 / 0.2 / 0.6 of them from pamphlets); 1.0 quiet thefts per expert run. The crafter wins 38%: the junk it grabs costs it gear, and makeshift things are weaker than the real ones. That is the trade-off section 10 asks for, and it keeps crafted credits far under the cap.

Story and Hard (2,000 runs per policy): expert 79% / 19%, naive 13% / 6.5%, random 0.2% / 0.1% (M2: expert 81% / 18%).

The grab (`tests/pass2/bot_difficulty_probe.gd`, a greedy bot on 12 real houses; it now also reports the share of core-item value, since junk adds clutter and value to every house): Normal keeps 48% of the core value and saves the whole family in 10 of 12 houses; Hard keeps 18% and saves everyone in 5 of 12 (M1: 59%, 10 of 12; 26%, 6 of 12). Junk sits between the bot and the gear, so the grab is harder; no run clears a house.

Tuning (passes 19–22 in `docs/balance/tuning_log.md`): the first M3 build put thirst at 42% of expert deaths. Silent thieves were taking a whole can of whatever pile was bigger (usually water), so now they take two rations of food (water only when the food is gone) and come less often. The harness expert had no parts at all, because its 12-slot grab never has room for junk; it now gets the shelter's own box of odds and ends, studies on free days, crafts what the situation calls for and tags what it lacks.

## Tests

All run on this branch with Godot 4.3. Checks that changed meaning under the M3 rules name the check they replace; none were removed.

| Suite | M2 (PR #9) | M3 |
|---|---|---|
| Data validator | 108 events, 0 errors | 114 events, 38 items (16 core, 11 junk, 11 makeshift), 12 recipes, 6 parts, 4 chapters, 36 achievements, 0 errors |
| `tests/m3/craft_suite.gd` (new) | — | 98 passed |
| `tests/m1/data_pipeline_suite.gd` | 116 passed | 182 passed (per-item checks for the 22 new items) |
| `tests/m1/shelter_rules_suite.gd` | 60 passed | 60 passed (reachability: the alarm's event is scheduled by code; dirty-water and bench conditions are set up) |
| `tests/m2/drama_suite.gd` · `achievements_suite.gd` | 60 · 36 passed | 60 · 39 passed (3 new achievements, each earned through game calls) |
| `tests/pass2/systems_gauntlet.gd` | 127 passed | 127 passed |
| `tests/critic_60s_audit.gd` | 78 passed | 78 passed ("exactly 16 core items" and "no duplicate durables" now count core items: junk is a separate category and can turn up twice) |
| `tests/critic_qa_audit.gd` | 32 passed | 32 passed |
| `tests/critic_osm_audit.gd` | 48 passed | 49 passed (its live Nominatim and map checks need a network; they failed once mid-milestone while the connection was down) |
| `tests/pass2/play_shelter.gd` (real key and mouse events) | 30 checks | 35 checks: junk taken apart at the Bench, a day at the workbench and a day with the manual set from the job menu with the mouse, and the next morning's receipt |
| compile_all · floorplan_stress | clean · 4,305 | clean · 5,214 |
| Web export, then the `.pck` run headless | title → day-7 summary | title → day-7 summary; from the pack: the M3 tables load, the shelter's box is on day 1, the Bench takes a toaster apart, a rag bandage is made overnight, the Almanac's Junk tab opens |

Fixed along the way: a CSV added to `data/` is imported by Godot as a translation unless it has a "keep" import file (`manual_chapters.csv.import`); the workbench rebuilt its buttons while the old ones were still in the tree, which renamed them.

## Known limits

- The harness expert crafts little (0.8 items per run): it plays for gear, and its grab never has room for junk. The crafter policy shows the other end (2.0 per run, 38% wins). Whether a day at the bench feels worth it to a person needs a human play test.
- The grab is harder with junk in the house (see above), most on Hard. M4 replaces the top-down grab with the first-person one, which will need its own Need highlight; today the tags ring matching junk in the top-down grab.
- 75 of 114 events (66%) have an item option; the design asks for about 40%. Stand-ins add makeshift answers to existing options without adding gated events.
- Thirst is still 39% of expert deaths, just under the 40% limit. Dirty water and the bottle filter help a little (0.4 rations filtered per expert run); new content that costs water should be checked with the harness.
- Gang takeovers end 19% of expert runs; makeshift weapons can't stop the takeover by design (an ending condition).
- Makeshift items show on the HUD, the bench and the receipts, but not on the shelves of the shelter backdrop.
- The Patch Job has no item of its own: it gets a broken item working once, and that use counts as makeshift.
- Meta-progression unlocks and the narrator that quiets as morale drops are still planned for M6.
