# Adding content

Everything the game knows about items, loot, events and numbers lives in `data/`. Edit the tables in any spreadsheet (LibreOffice or Google Sheets: export as CSV, comma-separated, UTF-8), then run one command:

```
godot --headless --path . -s res://tools/build_data.gd
```

It compiles `data/*.csv` and `data/events/*.json` into `data/build/*.json` (what the game loads), regenerates `CREDITS.md`, and **fails with a list of errors** if anything is wrong: duplicate or dangling ids, a missing icon, slots outside 1–3, a core item that gates fewer than 3 events, a fatal outcome without a warning, banned words, an unlicensed asset. The test suite runs the same validator (`tests/m1/data_pipeline_suite.gd`) and also checks that the committed build matches the sources. Commit the CSV/JSON *and* `data/build/`.

## An item

1. Pick an icon on [game-icons.net](https://game-icons.net) (CC BY 3.0). Save the SVG as `assets/icons/source/<author>/<name>.svg` (that folder is not imported).
2. Add a row to `data/items.csv`:

   | column | example | notes |
   |---|---|---|
   | `id` | `crowbar` | lowercase, unique |
   | `name`, `short_name` | `Crowbar`, `Crowbar` | |
   | `category` | `core` / `junk` / `makeshift` | |
   | `slots` | `2` | 1–3 |
   | `purpose_line` | `Opens locked doors and shutters` | shown everywhere as "Crowbar [2] — opens locked doors…" |
   | `effects` | `raid_stop=0.5;shutter=1` | `key=value;…`, read by the rules |
   | `breaks_on`, `repair`, `scrap_yield` | `trip:0.10`, `manual:0.85`, `metal:2` | |
   | `icon`, `icon_author`, `icon_source`, `icon_color` | `res://assets/icons/items/crowbar.svg`, `Lorc`, `lorc/crowbar`, `#d8dde3` | |
   | `grab_rooms` | `Garage Bay\|Storage` | where it turns up in the house grab |
   | `almanac_text` | one dry line | |
3. Add an `assets_manifest.csv` row for the icon (path, `icon`, title, author, game-icons URL, `CC-BY-3.0`).
4. Say where it can be found in `data/loot_weights.csv` (`place_type,item_id,min,max,chance,size_scaled`; `home` is the house grab).
5. Run `godot --headless --path . -s res://tools/recolor_icons.gd`, then `tools/build_data.gd`.

The item now appears in the grab, the stores, tooltips and the validator. A **core** item must gate at least 3 events, so the build fails until you write them.

## A junk piece

The same as an item, with `category` set to `junk`, a `scrap_yield` (`metal:2;electronics:1`) and `loot_weights.csv` rows in the place types that sell it. Every recipe part must be obtainable from junk in at least 2 place types.

## A recipe (M3)

Add a row to `data/recipes.csv`: `id,name,parts,tool,time,makes,effect_line,unlock`, e.g. `rag_bandage,Rag Bandage,cloth:2;chemicals:1,,quick,rag_bandage,Cures Injured only (the Medkit cures both),known`. `makes` must be an item row with `category` set to `makeshift`.

## An event

Add an object to any file in `data/events/` (one JSON array per file):

```json
{
  "id": "smart_lock", "title": "Locked Out", "type": "discovery", "mood": "neutral", "weight": 1.0,
  "setup": "The smart lock on the shed wants a firmware update before it opens.",
  "conditions": {"min_day": 4, "needs_place": ["hardware"]},
  "options": [
    {"id": "axe", "label": "Open it the old way", "item": "axe",
     "effects": [{"do": "use", "item": "axe", "mode": "wear", "what": "opened the shed"}, {"do": "add", "item": "water", "n": 1}],
     "outcome": "One bottle and a very surprised spider."},
    {"id": "wait", "label": "Wait for the update",
     "effects": [{"do": "morale", "who": "all", "n": -1}],
     "outcome": "It reaches 4% and stops believing in itself."}
  ]
}
```

Rules the validator enforces: a setup of 25 words or fewer and outcomes of 30 or fewer; 2–4 options with at least one that needs no item and at most two item options; an item-gated event needs a costly no-item option; anything that can kill (`kill`) or end the run (`lose_run`) needs `"warning": "<kind>"` and an `"omen"` line, which the game shows a day earlier. The effects, conditions and `{placeholders}` you can use are listed in `scripts/data/data_schema.gd`. Rescue-chain requests carry `"chain"` and `"step"` (and a `"retry": true` variant for the second try). Follow the tone guide: deadpan, no punchline on a death, real places only as neutral facts.

## An achievement (M2)

Add a row to `data/achievements.csv`: `id,name,description,condition,unlocks`. Every achievement must depend on decisions, not drops, and needs a test that unlocks it.

## A narration line

Add a row to `data/narration.csv`: `id,trigger,voice,text,audio,status`. Keep it to 15 words or fewer, never speak a name (subtitles show names), and leave `status` as `pending` until the `.ogg` exists. Once the voice is rendered, set `status` to `ready`; the build then fails if the file is missing. A trigger needs at least 3 lines so no line plays twice in a run.

## Balance numbers

Every rule number is in `data/balance.csv`. After changing one, rerun the harness (`tools/run_sim.sh 10000 8`) and check `docs/BALANCE_REPORT.md`.
