## Lead (C's art-gap brief): every LootDef names the catalog bag prop for its carry weight (very heavy uses
## the heavy prop until ENV D models one), and that scene has the `Bag` node LootBag._build_visual needs.
extends TestCase

const PROPS: Dictionary = {
	Enums.LootWeight.LIGHT: "res://world/props/loot_bag/prop_loot_bag_light.tscn",
	Enums.LootWeight.MEDIUM: "res://world/props/loot_bag/prop_loot_bag_medium.tscn",
	Enums.LootWeight.HEAVY: "res://world/props/loot_bag/prop_loot_bag_heavy.tscn",
	Enums.LootWeight.VERY_HEAVY: "res://world/props/loot_bag/prop_loot_bag_heavy.tscn",
}


func test_every_loot_def_has_the_bag_of_its_weight() -> void:
	var defs: Array = ContentDB.all_loots()
	assert_true(defs.size() >= 10, "the loot catalogue loads")
	for d: LootDef in defs:
		assert_true(d.bag_model != null, "%s has a bag_model" % d.id)
		if d.bag_model != null:
			assert_eq(d.bag_model.resource_path, PROPS[d.weight] as String, "%s (weight %d)" % [d.id, d.weight])


func test_bag_props_have_the_bag_node() -> void:
	for path: String in PROPS.values():
		var inst: Node = (load(path) as PackedScene).instantiate()
		assert_true(inst.find_child("Bag", true, false) != null, "%s has a Bag node" % path)
		inst.free()
