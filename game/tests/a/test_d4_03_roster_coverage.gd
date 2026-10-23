## D4-03 (LEAD): every roster heister (B's Heisters.ids()) has first-person sleeves (FpViewmodelTweak.sleeve_scenes),
## a third-person body (CrewTweak.body_scenes) and a bark line pattern for every crew.* bark (BarkTweak.patterns), so a
## new heister cannot ship half-wired. The sleeve / body maps are ENV P's files; this only reads them.
extends TestCase


func test_every_roster_heister_has_sleeves_body_and_barks() -> void:
	var ids: Array[StringName] = Heisters.ids()
	assert_true(ids.size() >= 6, "the roster (%d heisters)" % ids.size())
	var sleeves: Dictionary[StringName, PackedScene] = FpViewmodelTweak.data().sleeve_scenes
	var bodies: Dictionary[StringName, PackedScene] = Tweak.crew().body_scenes
	var patterns: Dictionary = BarkTweak.get_default().patterns
	var crew_keys: Array = patterns.keys().filter(func(k: Variant) -> bool: return String(k).begins_with("crew."))
	assert_true(crew_keys.size() >= 10, "the crew barks (%d)" % crew_keys.size())
	for h: StringName in ids:
		assert_true(sleeves.has(h), "%s has FP sleeves (fp_viewmodel_tweak.tres)" % h)
		assert_true(bodies.has(h), "%s has a body (crew_tweak.tres)" % h)
		for k: Variant in crew_keys:
			var has: bool = false
			for line: Variant in patterns[k]:
				has = has or String(line).begins_with("vo.%s." % h)
			assert_true(has, "%s has a %s bark line (bark_tweak.tres)" % [h, k])
