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

**Its 3D prop (M4).** Add the item to `ITEMS` in `scripts/scavenge/prop_library.gd`: either a model (`"crowbar": ["S:tool-hammer", 0.5, true]` — `S:` Survival Kit, `F:` Food Kit, no prefix Furniture Kit; the number is the height, or the length when the last value is `true` and it lies on the floor) or `"@crowbar"` plus a recipe of primitives in `_recipe()` (`["box", size, position, colour]`, `cyl`, `sphere`, `torus`, `quad`). A new model file needs an `assets_manifest.csv` row like any other asset. `tests/m4/grab3d_suite.gd` fails while a core or junk item has no prop.

## A furniture piece (M4)

Furniture kinds come from `FURNITURE_SPECS` in `scripts/scavenge/floorplan_generator.gd` (room, kind, width and depth in metres). Each kind needs a row in `FURNITURE` in `prop_library.gd`: parts `[model, x, z, width, height, depth, y, yaw (, roll)]` in the piece's frame (front faces +Z; sizes below zero are fractions of the footprint). The grab backs the piece onto the nearest wall and merges each room's furniture into one mesh. The suite fails on a kind without a row.

## A junk piece (M3)

The same as an item, with `category` set to `junk`, a `scrap_yield` (`metal:2;electronics:1`), `grab_rooms` for the house and `loot_weights.csv` rows in the place types that stock it (`home` is the house grab, `shelter_box` the shelter's own box of odds and ends, `electronics` phone and electronics shops). Its tooltip is built from the yield ("Toaster [2] → 2 Metal, 1 Electronics"), so the `purpose_line` only needs to say the same in words. The build fails if a part a recipe needs can't be found in junk from at least 2 place types.

The six parts live in `data/parts.csv` (`id,name,icon_shape,color`). Each needs its own shape (`square`, `hexagon`, `diamond`, `circle`, `triangle`, `drop`) so colour-blind players can tell them apart.

## A recipe (M3)

1. Add the makeshift item to `data/items.csv` with `category` `makeshift`, an icon (the recolour tool tapes it so it looks handmade), and its `effects`, from the keys the rules know (`DataSchema.MAKESHIFT_EFFECTS`): `uses` (how many times it works), `stands_in=<core item>` (the real thing it imitates), `gear=1` (it can be packed for a trip), `defence=1` (only one at a time), and the numbers its own code reads (`carry`, `filter`, `raid_stop`, `break_p`, `listen_p`, `success`, `morale_all`, `cure_injured`).
2. Add a row to `data/recipes.csv`: `id,name,parts,tool,time,makes,purpose,compare,unlock`, e.g. `rag_bandage,Rag Bandage,cloth:2;chemicals:1,,quick,rag_bandage,Closes a wound without the medkit.,Makeshift medkit: cures Injured only (the medkit cures both),known`.
   - `time` is `quick` (two a day) or `day` (the crafter's whole day); `tool` is a core item that must be on the shelf (never used up; the axe takes wear on Day recipes).
   - `purpose` and `compare` are the first two lines of the recipe card; `compare` says how it is weaker than the real thing.
   - `unlock` is `known` or a chapter id from `data/manual_chapters.csv` (`id,order,title,pamphlet,pamphlet_places`). A chapter is learned by a day of study with the manual, or by bringing home its pamphlet from one of its `pamphlet_places`.
   - `makes: patch` with a `match:1` part is the Patch Job: one more use for a broken item.
3. Give it at least one event: either an option with `"item": "<id>"`, or a stand-in on an existing option, `"alt": [{"item": "soap_spray", "p": 0.65, "label": "Soap-spray the shelf"}]`. A stand-in does the real item's job with probability `p` (default: its `success` effect, else 1); when it fails it is spent anyway and the event's costly no-item option happens instead (or the alt's own `fail` effects). Rescue steps can't take a stand-in: makeshift items never meet rescue or ending conditions, and the build fails if one is listed there.
4. If it does something outside events (a raid, the night, a trip), that is a few lines in `scripts/shelter/shelter_craft.gd` and a check in `tests/m3/craft_suite.gd`.

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

Rules the validator enforces: a setup of 25 words or fewer and outcomes of 30 or fewer; 2–4 options with at least two that need no item and at most two item options; an item-gated event needs a costly no-item option; anything that can kill (`kill`) or end the run (`lose_run`) needs `"warning": "<kind>"` and an `"omen"` line, which the game shows a day earlier. The effects, conditions and `{placeholders}` you can use are listed in `scripts/data/data_schema.gd`. Rescue-chain requests carry `"chain"` and `"step"` (and a `"retry": true` variant for the second try). Follow the tone guide: deadpan, no punchline on a death, real places only as neutral facts.

M2 fields:
- `"hatch": true` on an option that opens the hatch to someone (a trade, a visitor, handing something out). It is greyed out while anyone is Paranoid or the House Rule "Nobody opens the hatch" is in force, so keep at least one other option.
- `"contagion": true` on an event where sickness spreads; "The sick sleep upstairs" keeps it from coming up.
- `"stranger": true` (type `stranger`) for a rare visitor with an item-gated option of their own; the game allows one per run.
- Effects: `later` (`{"in": 3, "trigger": "house_quiet", "quiet_place": true}`: the narrator brings it up days later), `end_run` (`{"ending": "maybe_walk_out"}` or `maybe_stranger`: a gamble the family chooses), `trip_flag`. Conditions: `needs_affliction` (`selfish`, `paranoid`, `reckless`, `withdrawn` or `any`), `needs_guilt`, `needs_rule` / `not_rule` (a House Rule id), `trip_occupied`, `needs_pet_any`. Weight keys: `afflicted`, `guilt`, `rule:<id>`, `place:<category>`.

M3 fields:
- `"alt"` on an item option: makeshift stand-ins (see "A recipe" above).
- Effects: `junk` (`{"item": "old_phone", "n": 1}`: a piece of junk for the shelf), `dirty_water` (`{"n": 4}`: rations a Bottle Filter can make drinkable; negative to pour it away), `parts` (`{"n": 1, "part": "metal"}`, a random part without `part`). Conditions: `needs_dirty_water` (rations), `needs_crafted` (anything made or taken apart this run).

## A House Rule

Add a row to `data/house_rules.csv`: `id,name,order,bonus,cost,morale_hit,needs,narrator_line`. Meetings offer the next two rules by `order`; `needs` can be `pet` or `child`. The bonus and cost text is what the meeting card shows; the effect itself is code (`s.has_rule("<id>")` where the rule acts), so a new rule needs a few lines in `scripts/shelter/` and a test in `tests/m2/drama_suite.gd`.

## An affliction line

`data/afflictions.csv` holds the four afflictions' names, the line when one takes hold (`onset`), when it lifts (`recover`), and three warnings (`warning_1..3`, each naming the person with `{name}`). Afflictions are never played for laughs.

## An achievement (M2)

Add a row to `data/achievements.csv`: `id,name,description,condition,unlocks`. `condition` is one of `Achievements.CONDITIONS` (`scripts/meta/achievements.gd`), with a number or id after a colon where it takes one (`padlock_stops:3`, `ending:rescue_convoy`, `makeshift_win:5`, `chapters:4`). Every achievement must depend on decisions, not drops (nothing for surviving N days), and needs a setup in `tests/m2/achievements_suite.gd` that earns it.

## A narration line

Add a row to `data/narration.csv`: `id,trigger,voice,text,audio,status`. Keep it to 15 words or fewer, never speak a name (subtitles show names), and leave `status` as `pending` until the `.ogg` exists. Once the voice is rendered, set `status` to `ready`; the build then fails if the file is missing. A trigger needs at least 3 lines so no line plays twice in a run.

## Balance numbers

Every rule number is in `data/balance.csv`. After changing one, rerun the harness (`tools/run_sim.sh 10000 8`) and check `docs/BALANCE_REPORT.md`.
