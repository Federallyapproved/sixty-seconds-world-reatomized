## What was wrong before (measured on `main`)

| Problem | Where | Fix in M1 |
|---|---|---|
| Dehydration killed at 6 days, starvation at 12 | `bunker_sim.gd` | Thirsty day 3, dehydrated day 4, 50% death roll day 5, death day 6; hungry day 6, starving day 8, death day 10 (`data/balance.csv`) |
| Trips took 1–3 days (1 with a map) | `expedition_engine.gd` | days = 1 + ceil(round-trip km / 6), clamped 2–7; map −1 day; 25% come back 1–2 days late (`ShelterTrips`) |
| A trip carried 4 slots, 10 with the suitcase | `expedition_engine.gd` | 2 slots, +3 with the suitcase |
| Healthy scavengers almost never died | `expedition_engine.gd` | Never returning: 1 − (1 − p)^days with p = 2.5%/day × mask/hunger/sickness/map/weapon multipliers (typical trip 5–15%) |
| Rescue was guaranteed from day 5 and won around day 15–20 | `event_deck.gd`, `bunker_sim.gd` | No contact before the all-clear (day 7–20); chains of 4–5 item requests 3–6 days apart; a missed request costs 6–10 days; nothing lands before day 25 |

## Tuning passes (harness numbers are expert win rate unless noted)

1. **First run of the new rules: expert 12%, naive 15%.** The expert ran out of food and water, then sickness finished people off. Traces showed three leaks: trips came back half-empty, raids took two whole cans a night once the family was followed, and the expert's rationing kept everyone fully watered.
2. **Trip injuries 20% → 10%** (plus 25% extra when unarmed explorers meet looters, 30% of trips once raiders are about); **raids take one can or bottle, not two.** Expert 27%.
3. **Heavy fallout means heavy fallout.** Trip sickness (20% masked / 70% unmasked) now applies only before the all-clear or in a Lethal dose band, as the spec says, instead of also in the High band; untreated wounds turn septic at 15%/day after day 6 (was 30%); a store without an axe for its shutter gives 60% of a normal search (was 40%). Expert 34%, naive 25%.
4. **Searches fill the bag (search share 55% → 80%), dehydration makes people sick (10% → 15%/day), and the expert values food by how scarce it is.** The expert had been giving away its last two cans to the neighbourhood shelter. Expert 45%, naive 26%.
5. **Fuller stores.** Groceries now stock 10–20 food and water (was 6–14), neighbours' houses 2–5 (was 1–4). With 5–10% of every shelf vanishing daily, the early-trip-versus-wait decision still bites. Expert 51%, naive 19%, but the expert needed ~9 trips per win (target 3–6).
6. **The expert packs only what helps a given trip.** Every carried item has a 10% chance of breaking or being lost, and the expert had been losing its suitcase and gas mask early. It also stopped overvaluing places it had never seen. Expert trips 5.4.
7. **Relapse is rarer (6% → 2%/day while vulnerable)** to match the spec's "vulnerable to relapse events", and isolating a cough now spreads it half the time instead of always. Expert 48.5%, sickness 38% of expert deaths (was 49%).
8. **Dehydration sickness 25% → 35%/day.** This hits the naive policy (dehydrated one day in five) far harder than the expert, who never lets anyone reach day 4. Naive 18.5%.
9. **The old shelter temperature is back, in readable form.** Blast heat near ground zero now brings thirst forward by one day, once per person; a nuclear winter drops below freezing unless there is an axe for kindling or the manual. Below freezing, hungry people catch chills. A first version that made every hot dry day count double killed the naive family by day 5, so it was cut back to the old game's once-per-person rule. Naive 11%, expert 43%.
10. **A better expert grab:** gas mask and map before the suitcase, which leaves the rescue items and safe trips within reach. The expert also weighs trip sickness by how many medkits it holds. Expert 53%, 5.8 trips.
11. **Unstopped raids injure 30% of the time (was 40%) and old wounds turn septic at 10%/day (was 15%).** That brings sickness back to 40% of expert deaths. Expert 54%.
12. **Full fixture set and two corrections.** The rural homes and the three presets bring the set to 37 homes. Trips now roll the never-return chance every night away, including the first, which matches the preview's 1 − (1 − p)^days (before, a 2-day trip rolled once). The family's traits do what the creator promises (Handy repairs better, Iron Stomach resists malnutrition sickness, Knows the Area finds a little extra, Bookworm stays steadier, Optimist softens grief). Naive 9%, expert 49%, but sickness was 41% of expert deaths and the expert made 6.2 trips.
13. **Dehydration sickness 35% → 30%/day, relapse 2% → 1%/day, wound infection 10% → 8%/day.** The expert also skips marginal trips and keeps a spare medkit. Final: random 0.1%, naive 11.1%, expert 49.2%, 5.2 trips per expert run, sickness 38% of expert deaths.
14. **Knows the Area carries one more slot home** (`scout_extra_carry`), on top of its +10% search share. A final audit showed the share alone changed nothing: trips are nearly always limited by the bag, not by what is found. The harness family's scout is the child, who doesn't go on trips, so the numbers above are unchanged.

## Known limits

- The expert is a heuristic, not an optimal player: it never takes a second expedition while one is out, and it can't see hidden rolls. Human experts should do better.
- Gang takeovers end about 15% of expert runs. They are always preceded by a warning and by days of "Noticed" raids. That's fine for M1; M2's House Rules and strangers add more ways to deal with a gang.
- 0.2% of expert runs survive to the 120-day cap without a rescue (every chain went silent); the harness counts them as losses.
- Mid-game gaps: the neighbourhood rescue needs a real church or school and a visit after the all-clear, so it is the rarest of the three rescues (2.5% of expert runs).
- Fixtures are US neighbourhoods (city, suburb, small town, farmland). Other countries' OSM tagging should behave the same, but that hasn't been measured.
