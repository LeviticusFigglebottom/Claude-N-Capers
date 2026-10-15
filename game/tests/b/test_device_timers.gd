## PO6-03: PD2 device timer panels (DeviceTimers) and the objective-line suffix: EventBus fallback (started / jammed /
## restarted / finished), the model's `devices` rows when present, mm:ss, jammed state + fix prompt, distance / behind /
## wall hiding, objective link by device_net_id and by kind.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _world: Node3D
var _cam: Camera3D
var _device: Node3D
var _id: int = -1


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.current = true
	_device = Node3D.new()
	_device.name = "DrillPoint"
	_world.add_child(_device)
	_device.position = Vector3(0.0, -0.45, -4.0)  # panel floats device_panel_up_m above it
	_id = Ids.next()
	Ids.register(_id, _device)
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


func _drawn(id: int) -> Dictionary:
	for d: Dictionary in _hud.device_timers.drawn:
		if int(d["net_id"]) == id:
			return d
	return {}


func test_time_text_is_mm_ss_rounded_up() -> void:
	assert_eq(DeviceTimers.time_text(151.0), "02:31")
	assert_eq(DeviceTimers.time_text(0.2), "00:01", "reads 00:01 until done")
	assert_eq(DeviceTimers.time_text(0.0), "00:00")
	assert_eq(DeviceTimers.time_text(605.0), "10:05")


func test_eventbus_drill_shows_panel_and_counts_down() -> void:
	var dt: DeviceTimers = _hud.device_timers
	assert_true(dt != null and _hud.widgets().has(dt), "HUD has the device timer widget")
	EventBus.device_started.emit(_id, &"drill", 120.0)
	await wait_frames(3)
	var d: Dictionary = _drawn(_id)
	assert_false(d.is_empty(), "panel over the running drill")
	assert_eq(String(d["label"]), "DRILL")
	assert_true(String(d["time_text"]) == "02:00" or String(d["time_text"]) == "01:59", String(d["time_text"]))
	assert_false(bool(d["jammed"]))
	var p0: float = float(d["progress"])
	await wait_seconds(0.5)
	assert_true(float(_drawn(_id)["progress"]) > p0, "progress advances")
	var v: Vector2 = _hud.device_timers.get_viewport_rect().size
	assert_near((d["pos"] as Vector2).x, v.x * 0.5, 2.0, "projected at the device (screen centre)")


func test_jam_turns_red_with_fix_prompt_and_freezes() -> void:
	EventBus.device_started.emit(_id, &"drill", 60.0)
	await wait_frames(2)
	EventBus.device_jammed.emit(_id)
	await wait_frames(2)
	var d: Dictionary = _drawn(_id)
	assert_true(bool(d["jammed"]), "jammed")
	assert_eq(String(d["jam_text"]), "JAMMED")
	assert_true(String(d["fix_text"]).contains("fix the drill"), String(d["fix_text"]))
	var p: float = float(d["progress"])
	await wait_seconds(0.3)
	assert_near(float(_drawn(_id)["progress"]), p, 0.0001, "a jammed drill does not advance")
	EventBus.device_restarted.emit(_id, 0)
	await wait_frames(2)
	assert_false(bool(_drawn(_id)["jammed"]), "running again after the fix")
	EventBus.device_finished.emit(_id)
	await wait_frames(2)
	assert_true(_drawn(_id).is_empty(), "gone when done")
	assert_true(_hud.device_timers.rows().is_empty())


func test_hack_reads_interrupted_and_restart_prompt() -> void:
	EventBus.device_started.emit(_id, &"hack", 90.0)
	EventBus.device_jammed.emit(_id)
	await wait_frames(2)
	var d: Dictionary = _drawn(_id)
	assert_eq(String(d["label"]), "HACK")
	assert_eq(String(d["jam_text"]), "INTERRUPTED")
	assert_true(String(d["fix_text"]).contains("restart the hack"), String(d["fix_text"]))
	EventBus.device_finished.emit(_id)


func test_hidden_behind_camera_and_far_away() -> void:
	EventBus.device_started.emit(_id, &"drill", 60.0)
	await wait_frames(2)
	assert_false(_drawn(_id).is_empty())
	_device.position = Vector3(0.0, 0.0, 4.0)
	await wait_frames(2)
	assert_true(_drawn(_id).is_empty(), "behind the camera")
	_device.position = Vector3(0.0, 0.0, -(_hud.device_timers.tweak.device_panel_max_m + 5.0))
	await wait_frames(2)
	assert_true(_drawn(_id).is_empty(), "past device_panel_max_m")
	_device.position = Vector3(0.0, -0.45, -12.0)
	await wait_frames(2)
	var d: Dictionary = _drawn(_id)
	assert_false(d.is_empty())
	assert_true(float(d["scale"]) < 1.0, "smaller with distance")
	EventBus.device_finished.emit(_id)


func test_hidden_behind_a_wall() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 0.0, -2.0)
	_world.add_child(wall)
	EventBus.device_started.emit(_id, &"drill", 60.0)
	await wait_physics_frames(3)
	await wait_seconds(_hud.device_timers.tweak.device_occlusion_check_s + 0.1)
	assert_true(_drawn(_id).is_empty(), "a wall in between hides the panel")
	wall.queue_free()
	await wait_physics_frames(2)
	await wait_seconds(_hud.device_timers.tweak.device_occlusion_check_s + 0.1)
	assert_false(_drawn(_id).is_empty(), "visible again without the wall")
	EventBus.device_finished.emit(_id)


func test_model_rows_win_and_link_the_objective_line() -> void:
	_model.objectives = [{"id": &"crack_safe", "text_key": &"objective.glasshouse.safe", "state": Enums.ObjectiveState.ACTIVE,
			"args": {}, "device_net_id": 77}]
	_model.devices = [{"net_id": 77, "kind": &"thermal", "world_pos": Vector3(0, 0, -5), "progress": 0.25,
			"time_left_s": 151.0, "state": &"running", "fix_prompt_key": &"ui.prompt.fix_drill"}]
	await wait_frames(3)
	var d: Dictionary = _drawn(77)
	assert_false(d.is_empty(), "the model's row is drawn")
	assert_eq(String(d["time_text"]), "02:31")
	assert_eq(String(d["label"]), "THERMAL DRILL")
	var line: Label = _hud.objectives.device_label
	assert_true(line != null and line.is_inside_tree() and line.text == "THERMAL DRILL 02:31", line.text if line else "")
	_model.devices = [{"net_id": 77, "kind": &"thermal", "world_pos": Vector3(0, 0, -5), "progress": 0.25,
			"time_left_s": 151.0, "state": &"jammed"}]
	await wait_frames(3)
	assert_eq(line.text, "THERMAL DRILL JAMMED")
	assert_eq(line.get_theme_color(&"font_color"), _hud.device_timers.tweak.device_jam_color, "red while jammed")
	_model.devices = []
	await wait_frames(3)
	assert_false(line.is_inside_tree(), "no device line once the device is gone")


func test_objective_without_link_matches_by_kind() -> void:
	_model.objectives = [{"id": &"drill_vault", "text_key": &"objective.test.drill_vault", "state": Enums.ObjectiveState.ACTIVE,
			"args": {}}]
	EventBus.device_started.emit(_id, &"drill", 30.0)
	await wait_frames(3)
	var o: Dictionary = (_model.objectives as Array)[0]
	assert_true(_hud.device_timers.objective_line(o).begins_with("DRILL 00:"), _hud.device_timers.objective_line(o))
	var other: Dictionary = {"id": &"secure_bags", "text_key": &"objective.test.secure", "state": Enums.ObjectiveState.ACTIVE}
	assert_eq(_hud.device_timers.objective_line(other), "", "a bag objective gets no device timer")
	EventBus.device_finished.emit(_id)
