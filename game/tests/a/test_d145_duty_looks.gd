## D-145.3 (PO-18): Routine/Tense police wear ENV D's unarmoured `<id>_duty` look, Hazardous+ the armoured base look;
## a faction variant (params.visual_variant) wins, and a missing duty scene falls back to the base look.
extends TestCase

const ENEMIES: String = "res://systems/ai/data/enemies/"


func _def(path: String) -> EnemyDef:
	return load(ENEMIES + path) as EnemyDef


func test_routine_and_tense_try_duty_first() -> void:
	for id: String in ["patrol_officer.tres", "tac_light.tres"]:
		var def: EnemyDef = _def(id)
		for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.TENSE]:
			assert_eq(Array(NpcVisuals.variants(def, d)), ["duty", ""], "%s on %d" % [id, d])


func test_hazardous_and_up_keep_the_base_look() -> void:
	var def: EnemyDef = _def("patrol_officer.tres")
	for d: int in [Enums.Difficulty.HAZARDOUS, -1]:
		assert_eq(Array(NpcVisuals.variants(def, d)), [""], "difficulty %d" % d)


func test_faction_variant_wins_over_duty() -> void:
	var def: EnemyDef = _def("frd/tac_light.tres")
	assert_eq(Array(NpcVisuals.variants(def, Enums.Difficulty.ROUTINE)), ["frd", ""])


func test_scene_paths_fall_back_to_base() -> void:
	var def: EnemyDef = _def("tac_light.tres")
	var duty: String = NpcVisuals.scene_path("tac_light", "duty")
	var base: String = NpcVisuals.scene_path("tac_light")
	var paths: PackedStringArray = NpcVisuals.def_scene_paths(def, Enums.Difficulty.ROUTINE)
	if ResourceLoader.exists(base):
		assert_true(paths.has(base), "base look always warmable")
	assert_eq(paths.has(duty), ResourceLoader.exists(duty), "duty look listed exactly when ENV D delivered it")
	if ResourceLoader.exists(duty):
		assert_eq(paths[0], duty, "duty first on Routine")
	assert_false(NpcVisuals.def_scene_paths(def, Enums.Difficulty.HAZARDOUS).has(duty), "no duty on Hazardous")
