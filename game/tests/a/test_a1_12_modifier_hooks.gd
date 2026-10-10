## A1-12: every modifier key with phase <= 1 (contracts/modifier_keys.gd) has a behaviour hook and
## a test proving the key changes behaviour (contracts/modifiers.md). Per-key behaviour tests live
## next to their systems (test_s2_*, test_a1_02_*, test_l2_*, test_l3_*, test_s9_*); this file
## guards coverage and adds the hooks not covered elsewhere.
extends TestCase

const CURRENT_PHASE: int = 1
const TEST_DIR: String = "res://tests/a"


func after_each() -> void:
	Modifiers.clear_all()


func _test_sources() -> String:
	var out: String = ""
	var d: DirAccess = DirAccess.open(TEST_DIR)
	for f: String in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_a1_12_modifier_hooks.gd":
			out += FileAccess.get_file_as_string(TEST_DIR.path_join(f))
	return out + _own_behaviour_tests()


## Keys exercised by behaviour tests in this file.
func _own_behaviour_tests() -> String:
	return "interaction.device_speed_mult"


func test_every_phase1_key_has_a_behaviour_test() -> void:
	var sources: String = _test_sources()
	for key: StringName in ModifierKeys.KEYS:
		var entry: Array = ModifierKeys.KEYS[key]
		if int(entry[1]) > CURRENT_PHASE:
			continue
		assert_true(sources.contains(String(key)), "modifier key %s (phase %d) has no ENV A test" % [key, entry[1]])


func test_every_phase1_key_has_a_hook_in_systems() -> void:
	var code: String = ""
	var stack: Array[String] = ["res://systems"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d: DirAccess = DirAccess.open(dir_path)
		if d == null:
			continue
		for f: String in d.get_files():
			if f.ends_with(".gd"):
				code += FileAccess.get_file_as_string(dir_path.path_join(f))
		for sub: String in d.get_directories():
			stack.append(dir_path.path_join(sub))
	for key: StringName in ModifierKeys.KEYS:
		var entry: Array = ModifierKeys.KEYS[key]
		if int(entry[1]) <= CURRENT_PHASE:
			assert_true(code.contains("&\"%s\"" % key), "modifier key %s has no hook in game/systems" % key)


func test_interaction_device_speed_mult_scales_drill_duration() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_a1_12", 12, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	var base: float = await _placed_duration(rt, 0)
	Modifiers.set_source(0, &"skills", {&"interaction.device_speed_mult": 0.5})
	assert_near(await _placed_duration(rt, 0), base * 0.5, 0.001, "interaction.device_speed_mult halves drill time")
	Modifiers.set_source(1, &"skills", {&"interaction.device_speed_mult": 0.25})
	assert_near(await _placed_duration(rt, 0), base * 0.5, 0.001, "the placer's own slot modifiers apply")
	assert_near(await _placed_duration(rt, 1), base * 0.25, 0.001, "slot 1 placing uses slot 1 modifiers")
	rt.teardown()
	await wait_frames(1)


func _placed_duration(rt: HeistRuntime, slot: int) -> float:
	var dp: DrillPoint = (load("res://systems/prefabs/drill_point/drill_point.tscn") as PackedScene).instantiate() as DrillPoint
	rt.map.add_child(dp)
	dp.position = Vector3(0, 1, -4)
	await wait_physics_frames(1)
	dp.runner.place(slot, 100.0)
	var d: float = dp.runner.duration
	dp.runner.shutdown()
	dp.queue_free()
	return d
