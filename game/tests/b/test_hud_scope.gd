## ui_hud v1.16 (LEAD r227/r228): while the model says `scoped_ads`, the HUD's TEXT panels keep out of `scope_ring`: device
## timer panels inside it are not drawn; the prompt, tip card, assault banner and toast dock in the black margin right of
## the ring (P's windowed check: the prompt vanished below a full-height ring); markers stay. Unscoped, a device panel
## steps down below the toast's text ("Alarm raised" sat on DRILL JAMMED).
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _world: Node3D
var _id: int = -1
var _cam: Camera3D


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.current = true
	var dev: Node3D = Node3D.new()
	_world.add_child(dev)
	dev.position = Vector3(0.0, -0.45, -4.0)
	_id = Ids.next()
	Ids.register(_id, dev)
	_model = MockHudModel.new()
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud.size = Vector2(1920, 1080)  # the stretch base the ring is given in (the test window is not 16:9)
	await wait_frames(1)
	_hud.bind(_model)


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	_world.queue_free()
	await wait_frames(2)


func _ring() -> Rect2:
	var v: Vector2 = _hud.get_viewport_rect().size
	var r: float = v.y * 0.35
	return Rect2(v * 0.5 - Vector2(r, r), Vector2(r, r) * 2.0)


## P's real ring (r228 capture): x 465..1459, full height, on the 1920x1080 canvas.
func _p_ring() -> Rect2:
	return Rect2(465, 43, 994, 994)


func _clear_of_ring(c: Control, ring: Rect2, what: String) -> void:
	var r: Rect2 = c.get_global_rect()
	var near: Vector2 = ring.get_center().clamp(r.position, r.end)
	assert_true(near.distance_to(ring.get_center()) >= ring.size.y * 0.5, "%s %s clear of the ring" % [what, r])
	assert_true(r.end.x <= _hud.size.x + 0.5, "%s %s on screen" % [what, r])


func test_text_panels_leave_the_scope_ring() -> void:
	EventBus.device_started.emit(_id, &"drill", 60.0)
	_model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {"key": "F"}, "progress": 0.0, "blocked_reason": &""}
	await wait_frames(3)
	var placed: Rect2 = _hud.interaction.get_global_rect()
	_model.scope_ring = _p_ring()
	_model.scoped_ads = true
	await wait_frames(3)
	assert_true(_hud.interaction.visible, "prompt still shown while scoped")
	_clear_of_ring(_hud.interaction, _p_ring(), "prompt")
	assert_true(_hud.interaction.get_global_rect().position.x >= _p_ring().end.x, "prompt in the right margin")
	assert_near(_hud.interaction.get_global_rect().get_center().y, _p_ring().get_center().y, 2.0, "at the vertical centre")
	assert_true(_hud.interaction.plated, "on a dark plate")
	var d: Dictionary = {}
	for row: Dictionary in _hud.device_timers.drawn:
		if int(row["net_id"]) == _id:
			d = row
	assert_true(bool(d.get("hidden_by_scope", false)), "device panel inside the ring is not drawn")
	_model.scoped_ads = false
	await wait_frames(3)
	assert_true(_hud.interaction.get_global_rect().is_equal_approx(placed), "prompt back after ADS")
	assert_false(_hud.interaction.plated, "no plate over the world")
	EventBus.device_finished.emit(_id)


func test_card_banner_and_toast_dock_beside_the_prompt() -> void:
	OnboardingTips.persist = false
	_model.heist_phase = Enums.HeistPhase.LOUD
	_model.assault_phase = Enums.AssaultPhase.BUILD
	_model.assault_wave = 1
	_model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {"key": "F"}, "progress": 0.0, "blocked_reason": &""}
	_hud.onboarding._show(&"loud")
	await wait_frames(3)
	assert_true(_hud.assault.visible and _hud.onboarding.visible, "banner and card up")
	_model.scope_ring = _p_ring()
	_model.scoped_ads = true
	await wait_frames(4)
	var shown: Array[Control] = [_hud.assault, _hud.onboarding, _hud.interaction]
	for c: Control in shown:
		_clear_of_ring(c, _p_ring(), c.get_class())
	assert_true(_hud.onboarding.width < OnboardingCard.WIDTH, "card re-wrapped to the margin (%d)" % _hud.onboarding.width)
	var banner: Rect2 = Rect2(_hud.assault.panel.global_position, _hud.assault.panel.size * _hud.assault.scale)
	var card: Rect2 = Rect2(_hud.onboarding.panel.global_position, _hud.onboarding.panel.size * _hud.onboarding.scale)
	assert_false(banner.intersects(card), "banner %s / card %s" % [banner, card])
	assert_true(card.end.y <= _hud.interaction.get_global_rect().position.y + 0.5 or
			_hud.interaction.get_global_rect().position.x > _hud.size.x, "card above the prompt")
	_hud.toast(&"ui.hud.alarm")
	_hud.onboarding.dismiss()
	await wait_frames(3)
	_clear_of_ring(_hud.toast_label, _p_ring(), "toast")
	_model.scoped_ads = false
	await wait_frames(3)
	assert_eq(_hud.onboarding.width, OnboardingCard.WIDTH, "card width back")
	OnboardingTips.persist = true


func test_device_panel_steps_below_the_toast() -> void:
	_hud.toast(&"ui.hud.alarm")
	await wait_frames(2)
	var t: Rect2 = _hud._toast_rect()
	assert_true(t.has_area(), "toast text rect %s" % t)
	var dev: Node3D = Ids.lookup(_id) as Node3D
	var want: Vector2 = Vector2(t.get_center().x, t.end.y + 30.0)  # the panel's bottom: it lands on the toast
	dev.position = _cam.project_position(want, 4.0)
	EventBus.device_started.emit(_id, &"drill", 60.0)
	EventBus.device_jammed.emit(_id)
	await wait_frames(3)
	var off: float = want.y - (_row()["pos"] as Vector2).y  # the panel rides above the device
	dev.position = _cam.project_position(want + Vector2(0.0, off), 4.0)
	await wait_frames(3)
	var bottom: float = (_row()["pos"] as Vector2).y
	var top: float = bottom - DeviceTimers.PANEL_H * float(_row()["scale"])
	assert_true(top < t.end.y and bottom > t.position.y, "panel %.0f..%.0f placed on the toast %s" % [top, bottom, t])
	assert_eq(_hud.device_timers.yield_rect, t, "the HUD hands the toast's text rect to the device panels")
	assert_true(bool(_row().get("yielded", false)), "the panel steps down below \"Alarm raised\"")
	_hud.toast(&"ui.hud.alarm", {}, 0.01)
	await wait_frames(4)
	assert_false(bool(_row().get("yielded", true)), "toast gone: the panel is back on its device")
	EventBus.device_finished.emit(_id)


func _row() -> Dictionary:
	for row: Dictionary in _hud.device_timers.drawn:
		if int(row["net_id"]) == _id:
			return row
	return {}


func test_ring_without_scoped_ads_changes_nothing() -> void:
	_model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {"key": "F"}, "progress": 0.0, "blocked_reason": &""}
	await wait_frames(2)
	var top: float = _hud.interaction.get_global_rect().position.y
	_model.scope_ring = _ring()
	await wait_frames(2)
	assert_near(_hud.interaction.get_global_rect().position.y, top, 0.5, "a ring alone does not move panels")
	assert_false(_hud.device_timers.avoid.has_area())
