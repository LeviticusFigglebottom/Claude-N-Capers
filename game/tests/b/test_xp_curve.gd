## B1-07: reputation XP curve (pd2_fidelity P1).
extends TestCase


func test_shape_and_bounds() -> void:
	assert_eq(XpCurve.max_level(), 100)
	assert_eq(XpCurve.xp_for_level(0), 0)
	assert_eq(XpCurve.step_xp(1), 450, "900 x 0.5")
	assert_eq(XpCurve.step_xp(100), 500000, "1,000,000 x 0.5")
	var total: int = XpCurve.xp_for_level(100)
	assert_true(total > 11000000 and total < 12500000, "total ~23M x 0.5, got %d" % total)
	assert_eq(XpCurve.xp_for_level(-5), 0)
	assert_eq(XpCurve.xp_for_level(150), total)


func test_monotonic() -> void:
	var prev_step: int = 0
	for level: int in range(1, 101):
		var s: int = XpCurve.step_xp(level)
		assert_true(s >= prev_step, "step %d not below previous" % level)
		assert_true(XpCurve.xp_for_level(level) > XpCurve.xp_for_level(level - 1), "cumulative %d" % level)
		prev_step = s


func test_level_for_xp_round_trip() -> void:
	assert_eq(XpCurve.level_for_xp(0), 0)
	assert_eq(XpCurve.level_for_xp(-100), 0)
	assert_eq(XpCurve.level_for_xp(449), 0)
	assert_eq(XpCurve.level_for_xp(450), 1)
	for level: int in [1, 2, 10, 37, 50, 99, 100]:
		var need: int = XpCurve.xp_for_level(level)
		assert_eq(XpCurve.level_for_xp(need), level)
		assert_eq(XpCurve.level_for_xp(need - 1), level - 1)
	assert_eq(XpCurve.level_for_xp(999999999999), 100)


func test_custom_tweak() -> void:
	var t: XpCurveTweak = XpCurveTweak.new()
	t.max_level = 3
	t.first_level_xp = 100.0
	t.last_level_xp = 300.0
	t.exponent = 1.0
	t.scale = 1.0
	assert_eq(XpCurve.xp_for_level(3, t), 600)
	assert_eq(XpCurve.level_for_xp(299, t), 1)
	assert_eq(XpCurve.max_level(), 100, "default curve unaffected")
