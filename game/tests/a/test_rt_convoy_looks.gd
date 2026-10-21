## D-149.12 (D's RT cast note): the convoy escorts `enemy.convoy_lead` / `enemy.convoy_rear` are carved out of the
## spawn-tag look rule. They are EnemyDefs, so NpcVisuals resolves them by difficulty (D-145.3 duty looks, faction
## reskins, tac_heavy); on every difficulty at least one character scene must exist, so they never wear the placeholder
## capsule. SKIPs until the defs exist (RT systems, after the OF done check).
extends TestCase

const ENEMIES: String = "res://systems/ai/data/enemies/"
const CONVOY: PackedStringArray = ["convoy_lead", "convoy_rear"]


func test_convoy_escorts_never_resolve_to_a_capsule() -> void:
	var checked: int = 0
	for id: String in CONVOY:
		var path: String = "%s%s.tres" % [ENEMIES, id]
		if not ResourceLoader.exists(path):
			continue
		var def: EnemyDef = load(path) as EnemyDef
		assert_true(def != null and def.id == StringName("enemy." + id), "%s is EnemyDef enemy.%s" % [path, id])
		for d: int in Enums.Difficulty.values():
			var looks: PackedStringArray = NpcVisuals.def_scene_paths(def, d)
			assert_false(looks.is_empty(), "enemy.%s has a character on difficulty %d (variants %s)" % [id, d,
				NpcVisuals.variants(def, d)])
		checked += 1
	if checked == 0:
		skip("pending the RT convoy EnemyDefs (%s): D-149.12" % ", ".join(CONVOY))
