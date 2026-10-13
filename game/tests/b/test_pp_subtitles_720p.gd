## PQ-B-18 (D-076): subtitles at 1280x720 for every subtitle_size, two lines up (max_lines), stay on
## screen, render >= MIN_PX, and never cover vitals / ammo / the interaction or domination prompts,
## at hud_scale 1.0 and 1.5.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")
const MIN_PX: float = 14.0
const LINES: Array[Array] = [[&"mercer", &"vo.mercer.glasshouse_intro"], [&"reyes", &"vo.reyes.radio_alarm_1"]]


static func _rect(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform()
	return Rect2(xf.origin, c.size * xf.get_scale())


func _run(size_id: String, hud_scale: float) -> void:
	var s: GameSettings = GameSettings.load_file("user://pp_sub_none.cfg")
	s.set_value(GameSettings.ACCESSIBILITY, &"hud_scale", hud_scale)
	s.set_value(GameSettings.ACCESSIBILITY, &"subtitle_size", size_id)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.auto_find_model = false
	hud.settings = s
	add_child(hud)
	var sub: SubtitleOverlay = SubtitleOverlay.new()
	sub.settings = s
	add_child(sub)
	await wait_frames(2)
	hud.interaction.visible = true
	hud.dominate.visible = true
	for l: Array in LINES:
		assert_true(sub.show_line(l[0] as StringName, l[1] as StringName, {}))
	await wait_frames(3)
	sub.fit_height()
	await wait_frames(2)
	var tag: String = "%s x%.2f" % [size_id, hud_scale]
	var vis: Rect2 = hud.get_viewport().get_visible_rect().grow(1.0)
	assert_true(sub.rows.size() >= 1, tag + " newest line kept")
	if size_id != "large":
		assert_eq(sub.rows.size(), 2, tag + " two lines up")
	for r: Dictionary in sub.rows:
		var p: PanelContainer = r["panel"] as PanelContainer
		var pr: Rect2 = _rect(p)
		assert_true(vis.encloses(pr), "%s subtitle row on screen %s" % [tag, pr])
		var px: float = (r["text"] as Label).get_theme_font_size(&"font_size") * 720.0 / 1080.0
		assert_true(px >= MIN_PX, "%s subtitle %.1f px" % [tag, px])
		for w: Control in [hud.vitals, hud.ammo, hud.interaction, hud.dominate]:
			assert_false(pr.intersects(_rect(w)), "%s subtitles cover %s (%s / %s)" % [tag, w.name, pr, _rect(w)])
	sub.queue_free()
	hud.queue_free()
	await wait_frames(2)


func test_subtitles_small() -> void:
	await _run("small", 1.0)
	await _run("small", 1.5)


func test_subtitles_medium() -> void:
	await _run("medium", 1.0)
	await _run("medium", 1.5)


func test_subtitles_large() -> void:
	await _run("large", 1.0)
	await _run("large", 1.5)
