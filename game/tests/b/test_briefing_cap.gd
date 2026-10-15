## D-117 §5 (GN-U5): the briefing shows the first 5 objectives, then always the final one (its real step number), with a
## "+N more steps on the night" line between when steps are cut; short lists show whole.
extends TestCase


func test_cap_keeps_the_first_five_and_the_final_step() -> void:
	var objs: Array = range(10).map(func(i: int) -> StringName: return StringName("step_%d" % i))
	var c: Dictionary = BriefingModel.cap_objectives(objs, 5)
	assert_eq((c["shown"] as Array).size(), 6, "cap 6 rows")
	assert_eq((c["shown"] as Array)[5], &"step_9", "always the final step")
	assert_eq(c["numbers"], [1, 2, 3, 4, 5, 10], "the final step keeps its real number")
	assert_eq(int(c["more"]), 4, "4 steps left out")
	var short: Dictionary = BriefingModel.cap_objectives(objs.slice(0, 6), 5)
	assert_eq(int(short["more"]), 0, "6 steps show whole")
	assert_eq((short["shown"] as Array).size(), 6)
	assert_eq(int(BriefingModel.cap_objectives(objs, 0)["more"]), 0, "0 = every objective")


func test_gallery_night_briefing_is_capped_with_the_more_line() -> void:
	var m: Dictionary = BriefingModel.build(&"gallery_night", Enums.Difficulty.ROUTINE)
	var lines: Array = m["objectives"] as Array
	var def: HeistDef = HeistRegistry.get_def(&"gallery_night")
	if def == null:
		skip("no gallery_night def")
		return
	var src: Array = Array(def.briefing_objectives) if not def.briefing_objectives.is_empty() else Array(def.objectives)
	if src.size() <= 6:
		assert_eq(int(m["objectives_more"]), 0)
		return
	assert_eq(lines.size(), 6)
	assert_eq(int(m["objectives_more"]), src.size() - 6)
	assert_eq(int((lines[5] as Dictionary)["index"]), src.size(), "final step numbered as in the full list")
	var screen: BriefingScreen = (load("res://content/ui/briefing/briefing_screen.tscn") as PackedScene).instantiate() \
			as BriefingScreen
	screen.setup(&"gallery_night", Enums.Difficulty.ROUTINE)
	add_child(screen)
	await wait_frames(3)
	var more: Label = screen.find_child("ObjectivesMore", true, false) as Label
	assert_true(more != null and more.text.contains(str(src.size() - 6)), "the +N more line is shown")
	screen.queue_free()
	await wait_frames(1)
