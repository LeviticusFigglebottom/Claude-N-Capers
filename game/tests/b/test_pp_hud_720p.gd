## PQ-B-6 (D-076): HUD widgets stay on screen and the always-on widgets never overlap at the
## 1080-unit canvas (= 1280x720), at hud_scale 1.0 and at the 1.5 maximum.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _root_size: Vector2i


## A real 1280x720 window (the headless one is 0x0, which window/stretch/aspect="expand" turns into a
## square canvas): the canvas is then exactly 1920x1080 under both "keep" and "expand" (D-098).
func before_each() -> void:
	_root_size = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	await wait_frames(1)


func after_each() -> void:
	get_tree().root.size = _root_size
	await wait_frames(1)


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
		"scoreboard": hud.scoreboard, "onboarding": hud.onboarding}
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


## PP-B-7: loud play state (assault, downed with a bleedout timer, low ammo, carrying a bag, hostages):
## the labels a player reads mid-fight are visible, on screen, >= 14 px at 720p and do not overlap.
func _loud(scale: float) -> void:
	var s: GameSettings = GameSettings.load_file("user://pp_hud_none.cfg")
	s.set_value(GameSettings.ACCESSIBILITY, &"hud_scale", scale)
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.auto_find_model = false
	hud.settings = s
	add_child(hud)
	await wait_frames(1)
	hud.bind(model)
	model.masked = true
	model.casing = false
	model.assault_phase = Enums.AssaultPhase.SUSTAIN
	model.assault_wave = 3
	model.ammo = {Enums.WeaponSlot.PRIMARY: {"mag": 4, "reserve": 87}, Enums.WeaponSlot.SECONDARY: {"mag": 12, "reserve": 40}}
	model.equipped_slot = Enums.WeaponSlot.PRIMARY
	model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
	model.hostages = 3
	model.health = 0.0
	model.downs_left = 1
	model.crew_state = Enums.CrewState.DOWNED
	model.bleedout_s = 23.4
	await wait_frames(3)
	var px_per_unit: float = 720.0 / hud.get_viewport().get_visible_rect().size.y
	var vis: Rect2 = hud.get_viewport().get_visible_rect().grow(1.0)
	var reads: Dictionary = {"ammo": hud.ammo.ammo_label, "bleedout": hud.vitals.state_label,
		"bag": hud.status.bag_label, "hostages": hud.status.hostages_label}
	var rects: Dictionary = {}
	for k: String in reads:
		var l: Label = reads[k] as Label
		assert_true(l.is_visible_in_tree() and l.text.strip_edges() != "", "x%.1f %s shown ('%s')" % [scale, k, l.text])
		var xf: Transform2D = l.get_global_transform()
		var r: Rect2 = Rect2(xf.origin, l.size * xf.get_scale())
		rects[k] = r
		assert_true(vis.encloses(r), "x%.1f %s on screen %s" % [scale, k, r])
		var px: float = float(l.get_theme_font_size(&"font_size")) * xf.get_scale().y * px_per_unit
		assert_true(px >= 14.0, "x%.1f %s %.1f px at 720p" % [scale, k, px])
	assert_true(hud.vitals.state_label.text.contains("24") or hud.vitals.state_label.text.contains("23"),
			"bleedout seconds shown: " + hud.vitals.state_label.text)
	assert_true(hud.ammo.ammo_label.text.contains("4") and hud.ammo.ammo_label.text.contains("87"), hud.ammo.ammo_label.text)
	var keys: Array = rects.keys()
	for i: int in range(keys.size()):
		for j: int in range(i + 1, keys.size()):
			assert_false((rects[keys[i]] as Rect2).intersects(rects[keys[j]] as Rect2),
					"x%.1f %s overlaps %s" % [scale, keys[i], keys[j]])
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)


func test_loud_hud_readable_720p_scale_1() -> void:
	await _loud(1.0)


func test_loud_hud_readable_720p_scale_max() -> void:
	await _loud(1.5)
