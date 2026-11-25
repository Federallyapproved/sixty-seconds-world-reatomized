"""Fetches raw OpenStreetMap extracts (Overpass API) for the balance harness's home fixtures.

Writes tests/fixtures/osm_raw/<id>_local.json (everything within 400 m: buildings, roads, POIs,
in the same element format the game's OSM parser reads) and <id>_ext.json (the stores and
services the game's wider search looks for, 2.2 km and 6 km). tools/build_sim_fixtures.gd turns
these into tests/fixtures/sim_homes/*.json. The raw files are not committed (see .gitignore).

Usage: python tools/fetch_sim_osm.py [id ...]
"""
import json, sys, time, urllib.parse, urllib.request, pathlib

UA = "TheEndIsNear-sim-fixtures/1.0 (game balance test data)"
ENDPOINTS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]
OUT = pathlib.Path(__file__).resolve().parent.parent / "tests" / "fixtures" / "osm_raw"

# id: (lat, lon, group) — public neighbourhood centres, from dense city to farmland.
LOCATIONS = {
    "chicago_lincoln_park": (41.9214, -87.6513, "urban"),
    "naperville_il": (41.7400, -88.1830, "suburban"),
    "plano_tx": (33.0480, -96.7560, "suburban"),
    "mesa_az": (33.3900, -111.7600, "suburban"),
    "bozeman_mt": (45.6650, -111.0650, "town"),
    "story_city_ia": (42.1850, -93.5990, "town"),
    "rural_iowa": (42.3010, -93.7550, "rural"),
    "rural_kansas": (38.6000, -98.2000, "rural"),
    "rural_vermont": (44.3050, -72.9150, "rural"),
    "rural_nebraska": (41.1500, -99.6500, "rural"),
    # The game's three presets: their local data ships in data/osm_presets, so only the wider
    # store search is fetched here.
    "preset_seattle": (47.6240, -122.3195, "urban"),
    "preset_concord": (42.4603, -71.3490, "town"),
    "preset_brooklyn": (40.6802, -73.9930, "urban"),
}

SHOPS = "supermarket|convenience|grocery|general|greengrocer|bakery|butcher|hardware|doityourself|trade|car_repair|car_parts|tyres|chemist|medical_supply|outdoor"
AMEN = "pharmacy|hospital|clinic|doctors|fire_station|police|fuel|place_of_worship|school|library|community_centre|townhall"


def post(query):
    data = urllib.parse.urlencode({"data": query}).encode()
    for ep in ENDPOINTS:
        for attempt in range(3):
            try:
                req = urllib.request.Request(ep, data=data, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=180) as r:
                    return json.loads(r.read().decode("utf-8"))
            except Exception as e:  # noqa: BLE001
                print("  retry", ep, attempt, e)
                time.sleep(10 * (attempt + 1))
    raise RuntimeError("all endpoints failed")


def local_query(lat, lon, r):
    return f"[out:json][timeout:120];(nwr(around:{r},{lat},{lon}););out body;>;out skel qt;"


def ext_query(lat, lon, r, roads):
    a = f"(around:{r},{lat},{lon})"
    q = f'[out:json][timeout:120];(nwr{a}[shop~"^({SHOPS})$"];nwr{a}[amenity~"^({AMEN})$"];'
    if roads:
        q += f'way{a}[highway~"^(motorway|trunk|primary|secondary|tertiary)$"];'
    return q + ");out geom tags qt;"


def main(ids):
    OUT.mkdir(parents=True, exist_ok=True)
    for lid in ids:
        lat, lon, group = LOCATIONS[lid]
        print(lid, group)
        lp = OUT / f"{lid}_local.json"
        if not lp.exists() and not lid.startswith("preset_"):
            lp.write_text(json.dumps(post(local_query(lat, lon, 400))))
            time.sleep(25)
        for r in (2200, 6000):
            ep = OUT / f"{lid}_ext{r}.json"
            if not ep.exists():
                ep.write_text(json.dumps(post(ext_query(lat, lon, r, r == 2200))))
                time.sleep(25)
        meta = OUT / f"{lid}_meta.json"
        meta.write_text(json.dumps({"id": lid, "lat": lat, "lon": lon, "group": group}))


if __name__ == "__main__":
    main(sys.argv[1:] or list(LOCATIONS))
