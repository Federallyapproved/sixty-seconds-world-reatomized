# 60 Seconds: World Reatomized (Godot 4.3)

A full-featured re-imagining and expansion of *60 Seconds! Reatomized* built in **Godot 4.3** where **any real-world house on Earth** via **OpenStreetMap** becomes your playable 60-second scavenging floorplan and fallout bunker headquarters.

## Play in Browser & Watch Demo Video

- **Play Directly in Your Browser (WebAssembly)**: **[https://federallyapproved.github.io/sixty-seconds-world-reatomized/](https://federallyapproved.github.io/sixty-seconds-world-reatomized/)**
- **Watch the Full-HD 1280x720 Gameplay Demo Video**: **[https://federallyapproved.github.io/sixty-seconds-world-reatomized/demo.html](https://federallyapproved.github.io/sixty-seconds-world-reatomized/demo.html)**

---

## Play Locally in Desktop Godot 4.3 (Windows, macOS, or Linux)

1. Download **Godot Engine 4.3** (Standard, single binary—no install required) from [godotengine.org/download](https://godotengine.org/download/).
2. Clone this repository (or click **Code -> Download ZIP** on GitHub and unzip it):
   ```bash
   git clone https://github.com/Federallyapproved/sixty-seconds-world-reatomized.git
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
   - Converts your selected OpenStreetMap house footprint (via Minimum-Area OBB alignment + room subdivision + self-healing BFS walkability verification) into a multi-room interior (`Central Hall`, `Kitchen`, `Living Room`, `Master Bedroom`, `Kids Bedroom`, `Bathroom & Utility`) with random **Soup**, **Water**, **18 canonical 1-slot & 2-slot items**, and your **Family Members**.
   - **Recon Countdown -> 60.0s CONELRAD Air-Raid Siren**, **4-slot carry capacity** (upgrading to **5 slots** once the **Suitcase** drops down the central **Bunker Hatch**!), encumbrance physics, furniture bumps, and final shockwave dive.

5. **Fallout Shelter Survival & Real-World OSM Expeditions (`scripts/bunker/`, `scripts/expedition/`, `scripts/events/`)**
   - Illustrated underground shelter physically displaying your exact count of **Soup cans**, **Water bottles**, rescued durable gear, **Padlock**, **Sharikov the Cat**, **Pancake the Dog**, Geiger counter, wall thermometer, pinned neighborhood map, and custom seated family.
   - Multi-tab **Survival Notebook**: Daily Log, Fractional `1/4` Soup & Water Rationing + Medkit Care, **60 branching Dilemma Events** (with **3 multi-stage Rescue Victory Chains**: *U.S. Civil Defense Military*, *Real-World OSM Church/School Sanctuary*, and *Vault Scientist & Sharikov*), and **Interactive Real-World OSM Expedition Radar**.
