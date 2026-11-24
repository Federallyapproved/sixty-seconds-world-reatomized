# The End Is Near (Godot 4.3)

**The End Is Near** is a nuclear-survival game built in **Godot 4.3** where **any real-world house on Earth** via **OpenStreetMap** becomes your scavenging floorplan and fallout shelter. Inspired by *60 Seconds! Reatomized* and *Zombies Aren't Real*.

## Play in Browser & Watch Demo Video

- **Play Directly in Your Browser (WebAssembly)**: **[https://federallyapproved.github.io/the-end-is-near/](https://federallyapproved.github.io/the-end-is-near/)**
- **Watch the Full-HD 1280x720 Gameplay Demo Video**: **[https://federallyapproved.github.io/the-end-is-near/demo.html](https://federallyapproved.github.io/the-end-is-near/demo.html)**
- **Gameplay Improvement Pass (preview build, footage, before/after)**: **[/next/](https://federallyapproved.github.io/the-end-is-near/next/)** · **[/next/media.html](https://federallyapproved.github.io/the-end-is-near/next/media.html)** · validation report: [`docs/PASS2_REPORT.md`](docs/PASS2_REPORT.md)

### Controls

| Where | Keys |
|---|---|
| Scavenge | **WASD / arrows** move · **SPACE** grab (timed) · at the hatch **SPACE** drops your load down the chute · elsewhere **SPACE** drops the selected item · **Q** or **1–7** select a carried slot · **F** dive in · **TAB** skip recon · mouse click walks & grabs |
| Shelter | each occupied day opens with a dilemma: **1–4** or click to answer · **SPACE** skips an animation / continues · **GARAGE & CAR** and **BIG MAP** buttons under the notebook |
| Difficulty | Normal = 60 s scavenge · Hard = 30 s (toggle on the strike screen, or `--difficulty=hard`) |

---

## Play Locally in Desktop Godot 4.3 (Windows, macOS, or Linux)

1. Download **Godot Engine 4.3** (Standard, single binary—no install required) from [godotengine.org/download](https://godotengine.org/download/).
2. Clone this repository (or click **Code -> Download ZIP** on GitHub and unzip it):
   ```bash
   git clone https://github.com/Federallyapproved/the-end-is-near.git
   ```
3. Open Godot 4.3, click **Import**, select `project.godot`, and press **Play (`F5`)**!

---

## Core Features

1. **Custom Family Survivor Creator (`scripts/ui/family_screen.gd`, `scripts/family/character_artist.gd`)**
   - Build a 1–4 survivor household with custom **names**, **ages (`5–85`)**, **roles** (`Child`, `Teen`, `Adult`, `Elder`), **traits** (`Handy Mechanic`, `60s Sprinter`, `Iron Stomach`, `Neighborhood Scout`, `Civil Bookworm`, `Atomic Optimist`), **skin tones**, **8 hair styles**, **10 hair colors**, **eye colors**, **glasses**, **facial hair**, and **5 outfit styles**.
   - Every customization dynamically renders across **Survival Notebook portraits**, **top-down 60-second scavenge sprites**, and **seated bunker animations**—including live survival state overlays (*Hungry, Dehydrated, Sick, Injured, Insane Tinfoil Hat, and Radioactive Mutant*).

2. **Live OpenStreetMap Real-World House Picker & Neighborhood Scanner (`scripts/osm/`)**
   - Search **any street address, neighborhood, or city on Earth** via live **Nominatim geocoding**, stream real `256x256` **OpenStreetMap PNG slippy tiles**, and fetch real building polygons & POIs via **`api.openstreetmap.org/api/0.6/map.json`** (plus instant cached presets for *Capitol Hill Seattle*, *Concord MA*, and *Carroll Gardens Brooklyn*).
   - **Click any specific house polygon** to claim it as your level—automatically discovering **neighboring houses** alongside real-world **Churches / Sanctuaries**, **Grocery Stores / Supermarkets**, **Pharmacies / Clinics**, **Police & Fire Stations**, **Hardware Stores**, and **Schools / Libraries** with exact geodesic distances and compass bearings.

3. **Global & Regional Nuclear Detonation Impact Planner (`scripts/nuke/`)**
   - Select **where in the world** (or on your local metro radar) the warhead detonated, warhead yield (`15 kt Tactical`, `250 kt Urban`, `800 kt ICBM`, `50,000 kt Tsar Bomba`), and prevailing wind direction.
   - Computes real Haversine distance, cube-root blast overpressure & thermal rings, downwind fallout plumes, surface radiation (`Sv/hr`), scorching inner-ring heat (`+30..+36 °C` accelerating thirst), or distant stratospheric **Nuclear Winter** (`-18 °C` freezing shelter hazards).

4. **Authentic 60-Second House Scavenge (`scripts/scavenge/`)**
   - Generates the level **inside the building's real OpenStreetMap outline** (`scripts/scavenge/floorplan_generator.gd`): OBB alignment, BSP subdivision into rooms and hallways whose count follows the real floor area, doors only where a doorway fits, front door facing the mapped street, furniture, connectivity healing and BFS/A* verification. Interiors are labelled as fictional approximations.
   - **Recon -> 60 s scavenge (30 s on Hard)**, timed grabs, **4-slot hands** (the **Suitcase** adds capacity only while carried), 10 %/slot encumbrance, SPACE-to-deposit at the hatch (no automatic depositing), unique durable items, final shockwave dive.

5. **Fallout Shelter Survival & Real-World OSM Expeditions (`scripts/bunker/`, `scripts/expedition/`, `scripts/events/`)**
   - Illustrated underground shelter physically displaying your exact count of **Soup cans**, **Water bottles**, rescued durable gear, **Padlock**, **Sharikov the Cat**, **Pancake the Dog**, Geiger counter, wall thermometer, pinned neighborhood map, and custom seated family.
   - Every occupied day opens with a **cinematic dilemma** (never auto-answered) carried out by the leader, or the oldest able survivor when the leader can't act, followed by an animated outcome and a journal entry. Expeditions to **real, finite** neighbourhood buildings (walking-network distances, per-place stock that runs out), location-specific radiation dose, and a **repairable family car** (install salvaged parts by hand in the garage, then drive out crosswind). Multi-tab **Survival Notebook**: Daily Log, Fractional `1/4` Soup & Water Rationing + Medkit Care, **61 branching Dilemma Events** (with **3 multi-stage Rescue Victory Chains**: *U.S. Civil Defense Military*, *Real-World OSM Church/School Sanctuary*, and *Vault Scientist & Sharikov*), and **Interactive Real-World OSM Expedition Radar**.
