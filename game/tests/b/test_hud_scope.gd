## ui_hud v1.16 (LEAD r227): while the model says `scoped_ads`, the HUD's TEXT panels keep out of `scope_ring`: device
## timer panels inside it are not drawn and the interaction prompt / hint strip move just below it; markers stay.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _world: Node3D
var _id: int = -1


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)
	var cam: Camera3D = Camera3D.new()
	_world.add_child(cam)
	cam.current = true
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


func test_text_panels_leave_the_scope_ring() -> void:
	EventBus.device_started.emit(_id, &"drill", 60.0)
	_model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {"key": "F"}, "progress": 0.0, "blocked_reason": &""}
	await wait_frames(3)
	var prompt_top: float = _hud.interaction.get_global_rect().position.y
	_model.scope_ring = _ring()
	_model.scoped_ads = true
	await wait_frames(3)
	assert_true(_hud.interaction.get_global_rect().position.y >= _ring().end.y, "prompt below the ring (%s vs %s)"
			% [_hud.interaction.get_global_rect(), _ring()])
	var d: Dictionary = {}
	for row: Dictionary in _hud.device_timers.drawn:
		if int(row["net_id"]) == _id:
			d = row
	assert_true(bool(d.get("hidden_by_scope", false)), "device panel inside the ring is not drawn")
	_model.scoped_ads = false
	await wait_frames(3)
	assert_near(_hud.interaction.get_global_rect().position.y, prompt_top, 1.0, "prompt back after ADS")
	EventBus.device_finished.emit(_id)


func test_ring_without_scoped_ads_changes_nothing() -> void:
	_model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {"key": "F"}, "progress": 0.0, "blocked_reason": &""}
	await wait_frames(2)
	var top: float = _hud.interaction.get_global_rect().position.y
	_model.scope_ring = _ring()
	await wait_frames(2)
	assert_near(_hud.interaction.get_global_rect().position.y, top, 0.5, "a ring alone does not move panels")
	assert_false(_hud.device_timers.avoid.has_area())
