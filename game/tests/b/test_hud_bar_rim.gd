## LEAD r312 AH G2 read: a full pale bar over the lit foyer's pale wall had no edge (crew rows, vitals). HUD bars over
## the 3D view get a dark rim outside their rect; their size and layout stay.
extends TestCase


func _rim(b: ProgressBar) -> StyleBoxFlat:
	return b.get_theme_stylebox(&"background") as StyleBoxFlat


func test_hud_bar_has_a_dark_rim_and_keeps_its_size() -> void:
	var b: ProgressBar = UiBuild.hud_bar(Color.WHITE, Vector2(160, 3))
	var plain: ProgressBar = UiBuild.bar(Color.WHITE, Vector2(160, 3))
	assert_eq(b.custom_minimum_size, plain.custom_minimum_size)
	var sb: StyleBoxFlat = _rim(b)
	assert_true(sb != null and sb.expand_margin_top >= 1.0 and sb.expand_margin_left >= 1.0, "a rim outside the rect")
	assert_true(sb.bg_color.a >= 0.7 and sb.bg_color.get_luminance() < 0.1, "dark and strong: %s" % sb.bg_color)
	assert_eq(sb.content_margin_left, (UiBuild.theme().get_stylebox(&"background", &"ProgressBar")).content_margin_left)
	b.free()
	plain.free()


func test_crew_and_vitals_bars_use_it() -> void:
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	var model: MockHudModel = MockHudModel.new()
	model.crew = [{"slot": 1, "name": "Sable", "health": 1.0, "armor": 1.0, "state": 0}]
	add_child(model)
	await wait_frames(1)
	hud.bind(model)
	await wait_frames(3)
	for b: ProgressBar in [hud.vitals.health_bar, hud.vitals.armor_bar]:
		assert_true(_rim(b).expand_margin_top >= 1.0, "vitals bar framed")
	var framed: int = 0
	for n: Node in hud.teammates.find_children("*", "ProgressBar", true, false):
		if _rim(n as ProgressBar).expand_margin_top >= 1.0:
			framed += 1
	assert_true(framed >= 2, "crew rows framed (%d bars)" % framed)
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)
