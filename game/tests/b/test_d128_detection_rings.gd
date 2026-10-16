## D-128 (PO playtest): PD2's detection indicator. A ring over each observer fills clockwise with the meter ("?" while
## filling, red "!" at detected), one crosshair arc per observer points at it, colours run white -> orange -> red, and a
## row in the "curious" / "investigating" state shows the "?" ring even at 0 (ui_hud v1.17 proposal).
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _world: Node3D
var _cam: Camera3D


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.current = true
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


func _row(id: int) -> Dictionary:
	for r: Dictionary in _hud.chevrons.rings:
		if int(r["observer_net_id"]) == id:
			return r
	return {}


func test_ring_fills_with_question_then_red_bang() -> void:
	var tw: HudTweak = HudTweak.load_default()
	assert_true(tw.detection_blue.r > 0.9 and tw.detection_blue.b > 0.85, "PD2 white while filling: %s" % tw.detection_blue)
	_model.detection = [
		{"observer_net_id": 1, "world_pos": Vector3(0, -2.0, -8), "value": 0.3, "kind": Enums.ObserverKind.GUARD},
		{"observer_net_id": 2, "world_pos": Vector3(1.5, -2.0, -8), "value": 0.7, "kind": Enums.ObserverKind.GUARD},
		{"observer_net_id": 3, "world_pos": Vector3(-1.5, -2.0, -8), "value": 1.0, "kind": Enums.ObserverKind.GUARD},
	]
	await wait_frames(2)
	assert_eq(_hud.chevrons.rings.size(), 3)
	assert_eq(_row(1)["glyph"], "?", "filling: ?")
	assert_eq(_row(1)["color"], tw.detection_blue)
	assert_eq(_row(2)["glyph"], "?")
	assert_eq(_row(2)["color"], tw.detection_orange)
	assert_eq(_row(3)["glyph"], "!", "detected: !")
	assert_eq(_row(3)["color"], tw.detection_red)
	for id: int in [1, 2, 3]:
		assert_true(bool(_row(id)["on_screen"]), "ring %d over the observer" % id)
		assert_true(bool(_row(id)["arc"]), "crosshair arc %d" % id)
	var p1: Vector2 = _row(1)["ring_pos"] as Vector2
	var feet: Vector2 = _cam.unproject_position(Vector3(0, -2.0, -8))
	assert_true(p1.y < feet.y - 10.0, "the ring sits above the head (%s vs feet %s)" % [p1, feet])
	assert_true((_row(2)["ring_pos"] as Vector2).x > p1.x and (_row(3)["ring_pos"] as Vector2).x < p1.x, "follows each")


func test_behind_the_camera_only_the_arc_points_back() -> void:
	_model.detection = [{"observer_net_id": 7, "world_pos": Vector3(0, 0, 6), "value": 0.5, "kind": Enums.ObserverKind.GUARD}]
	await wait_frames(2)
	assert_false(bool(_row(7)["on_screen"]), "no ring for an observer behind you")
	assert_true(bool(_row(7)["arc"]), "the crosshair arc shows where it is")
	assert_near(absf(float(_row(7)["angle"])), PI, 0.01, "pointing back")


func test_cameras_use_the_same_ring_lower() -> void:
	_model.detection = [
		{"observer_net_id": 4, "world_pos": Vector3(0, 0.5, -8), "value": 0.4, "kind": Enums.ObserverKind.CAMERA},
		{"observer_net_id": 5, "world_pos": Vector3(0, 0.5, -8), "value": 0.4, "kind": Enums.ObserverKind.GUARD},
	]
	await wait_frames(2)
	assert_true(bool(_row(4)["on_screen"]))
	assert_true((_row(4)["ring_pos"] as Vector2).y > (_row(5)["ring_pos"] as Vector2).y, "camera ring hugs the camera")


func test_investigating_shows_question_at_zero() -> void:
	_model.detection = [
		{"observer_net_id": 8, "world_pos": Vector3(0, -2.0, -8), "value": 0.0, "kind": Enums.ObserverKind.GUARD,
				"state": &"investigating"},
		{"observer_net_id": 9, "world_pos": Vector3(1, -2.0, -8), "value": 0.0, "kind": Enums.ObserverKind.GUARD},
	]
	await wait_frames(2)
	assert_eq(_hud.chevrons.rings.size(), 1, "a calm 0 row draws nothing")
	assert_eq(_row(8)["glyph"], "?", "investigating a noise: ?")
	assert_false(bool(_row(8)["arc"]), "no crosshair arc without a meter")
	_model.detection = []
	await wait_frames(1)
	assert_eq(_hud.chevrons.rings.size(), 0)
