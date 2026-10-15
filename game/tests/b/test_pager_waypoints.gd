## PO6-20: a waypoint over every guard with a live pager (PagerWaypoints): guard from EventBus.pager_started (or the
## row's guard_net_id / world_pos), the time left, the answer ring, edge clamping off-screen, cleared when done.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _world: Node3D
var _guard: Node3D
var _gid: int = -1


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)
	var cam: Camera3D = Camera3D.new()
	_world.add_child(cam)
	cam.current = true
	_guard = Node3D.new()
	_world.add_child(_guard)
	_guard.position = Vector3(0.0, -1.2, -6.0)
	_gid = Ids.next()
	Ids.register(_gid, _guard)
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


func _drawn(pid: int) -> Dictionary:
	for d: Dictionary in _hud.pager_waypoints.drawn:
		if int(d["pager_id"]) == pid:
			return d
	return {}


func test_waypoint_over_the_paged_guard() -> void:
	assert_true(_hud.widgets().has(_hud.pager_waypoints), "HUD has the pager waypoints")
	EventBus.pager_started.emit(3, _gid)
	_model.pagers = [{"pager_id": 3, "time_left_s": 9.4, "answering": false, "progress": 0.0}]
	await wait_frames(3)
	var d: Dictionary = _drawn(3)
	assert_false(d.is_empty(), "waypoint drawn")
	assert_false(bool(d["clamped"]), "guard in view")
	var v: Vector2 = _hud.pager_waypoints.size
	assert_near((d["pos"] as Vector2).x, v.x * 0.5, 2.0, "over the guard (screen centre)")
	assert_eq(String(d["time_text"]), UiText.clock(9.4))
	_model.pagers = [{"pager_id": 3, "time_left_s": 9.4, "answering": true, "progress": 0.4}]
	await wait_frames(2)
	assert_true(bool(_drawn(3)["answering"]))
	assert_near(float(_drawn(3)["progress"]), 0.4, 0.001)
	EventBus.pager_answered.emit(3, 0, 1)
	_model.pagers = []
	await wait_frames(2)
	assert_true(_hud.pager_waypoints.drawn.is_empty(), "gone once answered")
	assert_false(_hud.pager_waypoints.guards.has(3))


func test_behind_the_camera_clamps_to_an_edge() -> void:
	_guard.position = Vector3(2.0, 0.0, 6.0)
	_model.pagers = [{"pager_id": 4, "time_left_s": 5.0, "answering": false, "guard_net_id": _gid}]
	await wait_frames(3)
	var d: Dictionary = _drawn(4)
	assert_false(d.is_empty(), "row guard_net_id is enough")
	assert_true(bool(d["clamped"]), "clamped to the screen edge")


func test_row_world_pos_wins_and_unknown_guard_is_skipped() -> void:
	_model.pagers = [{"pager_id": 5, "time_left_s": 5.0, "answering": false, "world_pos": Vector3(0, 0, -4)},
			{"pager_id": 6, "time_left_s": 5.0, "answering": false}]
	await wait_frames(3)
	assert_false(_drawn(5).is_empty(), "world_pos row drawn")
	assert_true(_drawn(6).is_empty(), "no guard known -> no waypoint")
