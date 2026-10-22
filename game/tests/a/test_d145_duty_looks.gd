## D-145.3 (PO-18): Routine/Tense police wear ENV D's unarmoured `<id>_duty` look, Hazardous+ the armoured base look;
## the duty look beats a faction look early (<faction>_duty first), and a missing scene falls back down the list.
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


## LEAD 2026-10-20: on Routine/Tense the unarmoured look beats the armoured faction look: <faction>_duty -> duty ->
## <faction> -> base; Hazardous+ keep faction -> base.
func test_duty_wins_over_the_faction_look_early() -> void:
	for f: String in ["frd", "zero", "sentinel"]:
		var def: EnemyDef = _def("%s/tac_light.tres" % f)
		for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.TENSE]:
			assert_eq(Array(NpcVisuals.variants(def, d)), ["%s_duty" % f, "duty", f, ""], "%s on %d" % [f, d])
		assert_eq(Array(NpcVisuals.variants(def, Enums.Difficulty.HAZARDOUS)), [f, ""], "%s on Hazardous" % f)
	assert_eq(NpcVisuals.scene_path("tac_light", "zero_duty"),
		"%stac_light_zero_duty/tac_light_zero_duty.tscn" % NpcVisuals.CHAR_DIR, "D's tac_light_<faction>_duty scene")


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
