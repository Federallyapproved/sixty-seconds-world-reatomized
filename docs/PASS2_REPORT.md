# Gameplay Improvement Pass — validation report

Branch `gameplay-improvement-pass` · Godot 4.3 · preview build: <https://federallyapproved.github.io/sixty-seconds-world-reatomized/next/> · footage & before/after images: [`/next/media.html`](https://federallyapproved.github.io/sixty-seconds-world-reatomized/next/media.html)

The preview goes live at `/next/` when the small additive PR #2 (`docs/next/` only) is merged; the root build changes only when this branch (PR #1) is merged. Both run the new code on the same 4.3 engine files.

## Before → after

| Area | Before (`main`) | After |
|---|---|---|
| **Scavenge difficulty** (perfect-knowledge bot, 9–12 seeded runs on real houses) | 100 % of loot value, 9/9 runs saved every family member, 9/9 cleared the whole house | **Normal 60 s:** 65.5 % value, 10/12 saved all family, 0 full clears · **Hard 30 s:** 63.6 %, 5/12, 0 full clears |
| Keyboard-only run, 1002 E Republican St | — | Normal: 16 grabs, 6 hatch trips, 13 items + 3/3 family · Hard: 8 grabs, 3 trips, 6 items + 2/3 family |
| Controls | Walk onto the hatch auto-deposited; optional auto-grab; suitcase gave a permanent +1 slot once dropped in | SPACE = timed grab / deposit at hatch / drop elsewhere; Q or 1–7 select a slot; no automatic pickup or deposit; suitcase adds capacity only while carried |
| Floorplans | Fixed 6-room template (`Central Hall` + 5) stretched over every house | Generated inside the real OSM outline; rooms scale with floor area (3.5 avg in the smallest third → 11.9 in the largest); 6 distinct layouts over 6 seeds for the same house; doors only where a doorway fits; front door faces the mapped street |
| Location text | Full postal address repeated in events, HUD, curtains; "Local Downtown", "Local Corner Market", numbered fake businesses | "home", street, neighbourhood, city in play; exact address only in property info; unnamed places say so; local strike targets are sourced landmarks (e.g. Colman Dock, OSM node 668442224) |
| Distances | Straight-line metres | Walking-network distance over OSM roads (straight-line shown as fallback, labelled "est.") |
| Loot | Rerolled every trip, never ran out | Finite per-building stock persisted for the run; previews come from the same stock table; scavengers take what the family lacks first |
| Daily dilemma | Hidden in notebook tab 3; unanswered dilemmas were silently resolved with the last option | Opens directly every occupied day, cannot be skipped, animated outcome (17 scenarios) with camera, lighting, sound, caption and journal entry |
| Acting survivor | Random | Leader when present and able; otherwise the oldest able survivor; never absent or dead |
| Radiation | Arbitrary "Sv/hr" that decayed linearly; "rads" | t^-1.2 decay with exact integrals, plume position per place, rain-out hotspots, second strikes, shelter protection factor, cumulative and 7-day dose, ARS stages; one unit format everywhere |
| Vehicle | None | Car with visible condition; parts come home on the rack; you install them by hand (garage dose); drive out crosswind, away from ground zero |
| Survival routes | Same everywhere | Depend on what exists nearby: e.g. Brooklyn preset has 0 spark-plug sources vs 3 in Concord; no church/school ⇒ no sanctuary chain |

## Automated checks (all run on this branch)

| Suite | Result | Baseline on `main` |
|---|---|---|
| `tests/pass2/systems_gauntlet.gd` — location honesty, OSM verification against raw JSON, walk network, finite loot, actor succession, radiation physics, vehicle & routes, 18 long runs | **127 / 0** | — |
| `tests/pass2/floorplan_stress.gd` — 60 real buildings × seeds, connectivity, collision, manifests | **5000 / 0** | — |
| `tests/pass2/play_shelter.gd` — real house → shelter by keyboard, 4 dilemmas, expedition return, battery install, drive-out | **14 / 0** | — |
| `tests/pass2/play_scavenge_keys.gd` — keyboard-only scavenge, Normal and Hard | **8 / 0** each | — |
| `tests/pass2/cinematic_gallery.gd` — 14 outcome types mapped & rendered | **14 / 14** | — |
| `tests/critic_60s_audit.gd` | **99 / 0** | 97 / 0 |
| `tests/critic_qa_audit.gd` (incl. full demo showcase) | **32 / 0** | 32 / 0 |
| `tests/critic_osm_audit.gd` | **42 / 5** | 43 / 5 |
| Exported `.pck` run in the 4.3 engine (`--main-pack … --demo-showcase`) | completes, 0 errors | — |

The 5 OSM-audit failures are the live Nominatim / OSM API / tile checks; those hosts are blocked from the build sandbox and fail identically on `main`. Legacy checks that encoded the old rules (6-room template, walk-over deposit, permanent suitcase slot, 60 events, 6 %/slot encumbrance) were rewritten to assert the new rules rather than deleted.

## Bugs found by testing and fixed

- A dead explorer's gear stayed flagged "OUT" until the scheduled return day.
- Hardware stores advertised a rifle the stock table never contained (and hid spark plugs it did).
- A 20-vertex footprint put the hatch outside the house; narrow buildings were cut into doorless sealed closets.
- Loot could sit in the wall-clearance band or two pickups on one cell; smoothed paths grazed door jambs.
- Very small buildings could spawn with no water at all.
- The default strike blew fallout away from the house while the house took the full dose; the car escape said "upwind", which pointed at ground zero.
- One outcome credited the wrong survivor; utility classes depending on the `GameState` autoload broke script-mode tools.

## Critique and known limits

- **Live OSM search not exercised here.** The sandbox cannot reach OSM, so Nominatim/Overpass code paths are untested end to end; the three bundled presets were verified against their raw OSM JSON. Please try one live search in the preview.
- **Browser not exercised here.** No browser is available in the sandbox; the exported pack was verified in the identical 4.3 engine. Click through `/next/` once before merging.
- Interiors are fictional by necessity (OSM has outlines, not rooms) and are labelled that way in the game.
- Sound effects are synthesized; they read well but are simple.
- Difficulty figures come from a bot with perfect knowledge of the house, so human results will be lower; Hard mode saved all family in 5 of 12 bot runs.

## Reproduce

```bash
godot --headless --path . -s res://tests/pass2/run.gd -- --suite=systems_gauntlet
godot --headless --path . -s res://tests/pass2/run.gd -- --suite=floorplan_stress --per=20
godot --headless --fixed-fps 60 --path . -s res://tests/pass2/bot_difficulty_probe.gd -- --seeds=12 [--hard]
xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tests/pass2/play_scavenge_keys.gd -- --out=/tmp/keys [--hard]
xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tests/pass2/play_shelter.gd -- --out=/tmp/play
godot --headless --path . -s res://tests/critic_60s_audit.gd
```
