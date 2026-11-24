class_name LootTables
extends RefCounted

## Pure data: what each kind of real building can stock (no autoload dependencies, so the OSM
## service, script-mode tools and tests can read it). LootInventory turns this into finite,
## persistent per-building stock.

# item_id: [min, max] per "standard" building of the category
const STOCK_TABLE: Dictionary = {
	"grocery": {"soup": [6, 14], "water": [6, 14], "bug_spray": [0, 2], "fuel_can": [0, 0]},
	"restaurant": {"soup": [3, 8], "water": [2, 6], "cards": [0, 1]},
	"pharmacy": {"medkit": [2, 5], "water": [1, 3], "bug_spray": [1, 2], "gas_mask": [0, 1]},
	"hardware": {"toolbox": [1, 2], "axe": [0, 2], "padlock": [1, 3], "flashlight": [1, 2], "spark_plugs": [2, 5], "fan_belt": [1, 2], "tire_patch": [1, 3], "water": [0, 2], "ammo": [0, 1]},
	"auto": {"fuel_can": [3, 8], "car_battery": [0, 2], "spark_plugs": [1, 4], "fan_belt": [0, 2], "tire_patch": [1, 3], "soup": [1, 3], "water": [2, 5], "toolbox": [0, 1]},
	"church": {"soup": [2, 5], "water": [3, 6], "medkit": [0, 1], "book": [1, 1], "cards": [0, 1], "harmonica": [0, 1]},
	"school": {"soup": [2, 4], "water": [2, 4], "map": [1, 1], "book": [1, 2], "flashlight": [0, 1], "checkers": [0, 1], "medkit": [0, 1]},
	"civic": {"water": [2, 4], "ammo": [2, 4], "rifle": [0, 1], "gas_mask": [1, 2], "radio": [0, 1], "medkit": [1, 2], "axe": [0, 1]},
	"park": {"water": [0, 2], "harmonica": [0, 1], "map": [0, 1]},
	"neighbor_house": {"soup": [1, 4], "water": [1, 4], "medkit": [0, 1], "flashlight": [0, 1], "padlock": [0, 1], "cards": [0, 1], "bug_spray": [0, 1], "car_battery": [0, 1], "fuel_can": [0, 1], "spark_plugs": [0, 0]},
}


## Items a place of this category can hold (max > 0 in STOCK_TABLE), most plentiful first.
static func preview_for_category(category: String) -> Array:
	var cat: String = category
	if cat in ["house", "neighbor", "residential", ""]:
		cat = "neighbor_house"
	if not STOCK_TABLE.has(cat):
		cat = "neighbor_house"
	var table: Dictionary = STOCK_TABLE[cat]
	var ids: Array = []
	for k in table.keys():
		if int((table[k] as Array)[1]) > 0:
			ids.append(str(k))
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ma: int = int((table[a] as Array)[1])
		var mb: int = int((table[b] as Array)[1])
		return ma > mb if ma != mb else str(a) < str(b)
	)
	return ids


