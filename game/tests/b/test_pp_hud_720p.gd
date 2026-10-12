## PQ-B-6 (D-076): HUD widgets stay on screen and the always-on widgets never overlap at the
## 1080-unit canvas (= 1280x720), at hud_scale 1.0 and at the 1.5 maximum.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")


func _rects(scale: float) -> Dictionary:
	var s: GameSettings = GameSettings.load_file("user://pp_hud_none.cfg")
	s.set_value(GameSettings.ACCESSIBILITY, &"hud_scale", scale)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.auto_find_model = false
	hud.settings = s
	add_child(hud)
	await wait_frames(2)
	var out: Dictionary = {
		"stamina": hud.stamina, "vitals": hud.vitals, "ammo": hud.ammo, "teammates": hud.teammates,
		"objectives": hud.objectives, "status": hud.status, "interaction": hud.interaction,
		"assault": hud.assault, "pager": hud.pager, "captain": hud.captain, "custody": hud.custody,
		"scoreboard": hud.scoreboard}
	var rects: Dictionary = {}
	for k: String in out:
		var c: Control = out[k] as Control
		var xf: Transform2D = c.get_global_transform()
		rects[k] = Rect2(xf.origin, c.size * xf.get_scale())
	rects["_vis"] = hud.get_viewport().get_visible_rect().grow(1.0)
	hud.queue_free()
	await wait_frames(1)
	return rects


func _check(scale: float) -> void:
	var r: Dictionary = await _rects(scale)
	var vis: Rect2 = r["_vis"] as Rect2
	for k: String in r:
		if k != "_vis":
			assert_true(vis.encloses(r[k] as Rect2), "x%.2f %s on screen: %s" % [scale, k, r[k]])
	# Always-on widgets (shown together in every phase) must not overlap.
	var always: Array[String] = ["stamina", "vitals", "ammo", "teammates", "objectives", "status", "interaction"]
	for i: int in range(always.size()):
		for j: int in range(i + 1, always.size()):
			var a: Rect2 = r[always[i]] as Rect2
			var b: Rect2 = r[always[j]] as Rect2
			assert_false(a.intersects(b), "x%.2f %s overlaps %s (%s / %s)" % [scale, always[i], always[j], a, b])


func test_hud_fits_720p_scale_1() -> void:
	await _check(1.0)


func test_hud_fits_720p_scale_max() -> void:
	await _check(1.5)
