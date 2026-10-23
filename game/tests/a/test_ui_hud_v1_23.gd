## ui_hud v1.23 (PO-22): LocalHudModel.ads_blend, written by ENV P's CrewView (duck-typed), read by the HUD.
extends TestCase


func test_ads_blend_field_defaults_to_zero_and_is_writable() -> void:
	var m: LocalHudModel = LocalHudModel.new()
	assert_true(&"ads_blend" in m, "the field exists")
	assert_eq(m.ads_blend, 0.0, "hip by default")
	m.set(&"ads_blend", 0.6)  # as P's CrewView writes it
	assert_near(float(m.get(&"ads_blend")), 0.6, 0.0001, "writable")
	m.free()
