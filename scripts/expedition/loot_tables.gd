class_name LootTables
extends RefCounted

## What each kind of real building can stock comes from data/loot_weights.csv (via ShelterData),
## so the house-select previews, the shelter's stores and the grab all read one table.


## Items a place of this category can hold, most plentiful first.
static func preview_for_category(category: String) -> Array:
	var cat: String = category
	if cat in ["house", "neighbor", "residential", ""]:
		cat = "neighbor_house"
	var table: Dictionary = ShelterData.loot_for(cat)
	var ids: Array = []
	for k in table.keys():
		if int((table[k] as Dictionary).get("max", 0)) > 0:
			ids.append(str(k))
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ma: float = float((table[a] as Dictionary)["max"]) * float((table[a] as Dictionary).get("chance", 1.0))
		var mb: float = float((table[b] as Dictionary)["max"]) * float((table[b] as Dictionary).get("chance", 1.0))
		return ma > mb if ma != mb else str(a) < str(b)
	)
	return ids
