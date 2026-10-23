## A2-02: security-room operator (S8.2) at a camera_station, broken-camera dispatch (S8.1 ◇ 30% after
## 10 s on GameRng &"cameras"), the S3.5 countdown surviving the operator's death.
extends TestCase

const SEED: int = 42
const OP_POS: Vector3 = Vector3(-14, 0.05, 14)

var _rt: HeistRuntime = null
var _st: StealthDirector = null
var _old: Dictionary = {}


## basic() + a patrol grid (the operator must still not patrol), a CAMERA_OPERATOR spawn facing
## away from the play area, a camera_station bound to it and two cameras.
static func _map() -> PackedScene:
	var root: HeistMap = ATestMaps.with_patrol_grid(0, 0).instantiate() as HeistMap
	var sp: SpawnPoint = SpawnPoint.new()
	sp.name = "Operator"
	sp.kind = SpawnPoint.Kind.CAMERA_OPERATOR
	sp.transform = Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP), OP_POS)
	root.get_node("Spawns").add_child(sp)
	sp.owner = root
	var gp: Node = root.get_node("Gameplay")
	var station_ps: PackedScene = load("res://systems/prefabs/camera_station/camera_station.tscn") as PackedScene
	var station: CameraStation = station_ps.instantiate() as CameraStation
	station.name = "Station"
	station.position = OP_POS + Vector3(0, 0, 1.5)
	station.operator_spawn = NodePath("../../Spawns/Operator")
	gp.add_child(station)
	station.owner = root
	var cam_ps: PackedScene = load("res://systems/prefabs/security_camera/security_camera.tscn") as PackedScene
	var rows: Array = [["CamA", Vector3(0, 3, 0), Vector3(0, 1, -4)], ["CamB", Vector3(12, 3, 12), Vector3(18, 1, 12)]]
	for row: Array in rows:
		var cam: Node3D = cam_ps.instantiate() as Node3D
		cam.name = row[0]
		var pos: Vector3 = row[1]
		cam.transform = Transform3D(Basis.looking_at(Vector3(row[2]) - pos, Vector3.UP), pos)
		gp.add_child(cam)
		cam.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func before_each() -> void:
	var tw: StealthTweak = Tweak.stealth()
	_old = {"delay": tw.camera_alarm_delay_s, "chance": tw.camera_dispatch_chance, "dispatch": tw.camera_dispatch_delay_s}
	_rt = await HeistLauncher.launch(&"unit_map", SEED, Enums.Difficulty.ROUTINE, self,
		{"map_packed": _map(), "ai_teammates": 0, "crew_ai": false})
	_st = _rt.stealth
	await _place(Vector3(-10, 0.05, 10))


func after_each() -> void:
	var tw: StealthTweak = Tweak.stealth()
	tw.camera_alarm_delay_s = _old["delay"]
	tw.camera_dispatch_chance = _old["chance"]
	tw.camera_dispatch_delay_s = _old["dispatch"]
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _place(pos: Vector3) -> void:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(2)


func _station() -> CameraStation:
	return _rt.map.get_node(^"Gameplay/Station") as CameraStation


func _cams() -> Array[SecurityCamera]:
	return SecurityCamera.cameras_in(_rt)


func _kill(npc: NpcBase) -> void:
	npc.take_hit(Damage.info(9999.0, Enums.DamageType.BULLET, Enums.HitZone.HEAD, &"test",
		npc.global_position, Vector3.FORWARD, _crew().net_id), _crew().net_id)


func _break(cam: SecurityCamera) -> void:
	cam.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test",
		cam.global_position, Vector3.FORWARD, _crew().net_id), _crew().net_id)


func test_s8_2_operator_spawns_at_station_and_holds_post() -> void:
	var s: CameraStation = _station()
	assert_true(s.staffed, "no security_room_staffed group: staffed")
	assert_true(s.operator != null and s.operator.alive, "operator spawned")
	assert_has(_rt.npcs(&"guard"), s.operator, "the operator is a guard (pager, S8.2)")
	assert_true(s.operator.global_position.distance_to(OP_POS) < 0.3, "at the CAMERA_OPERATOR spawn")
	assert_true(s.operator_on_duty())
	await wait_seconds(1.0)
	var brain: GuardBrain = s.operator.get_node(^"Brain") as GuardBrain
	assert_true(brain.route.is_empty(), "the operator does not patrol")
	assert_true(s.operator.global_position.distance_to(OP_POS) < 0.5, "still at his station")
	assert_eq(_cams().size(), 2)
	for c: SecurityCamera in _cams():
		assert_true(c.can_observe(), "cameras work while he is on duty")


func test_s8_2_room_staffed_variants() -> void:
	assert_true(CameraStation.room_staffed({}), "no group -> staffed")
	assert_true(CameraStation.room_staffed({&"security_room_staffed": [&"sec_staffed"]}))
	assert_false(CameraStation.room_staffed({&"security_room_staffed": [&"sec_empty"]}))
	assert_false(CameraStation.room_staffed({&"security_room_staffed": []}))


func test_s8_2_kill_operator_disables_all_cameras() -> void:
	var s: CameraStation = _station()
	var loops: Array[int] = []
	var offs: Array = []
	var cb_loop: Callable = func(by: int) -> void: loops.append(by)
	var cb_off: Callable = func(id: int, reason: StringName) -> void: offs.append([id, reason])
	EventBus.cameras_loop_disabled.connect(cb_loop)
	EventBus.camera_disabled.connect(cb_off)
	_kill(s.operator)
	EventBus.cameras_loop_disabled.disconnect(cb_loop)
	EventBus.camera_disabled.disconnect(cb_off)
	assert_eq(loops, [_crew().net_id] as Array[int], "cameras_loop_disabled(by killer) once")
	assert_eq(offs.size(), 2, "camera_disabled per camera")
	for row: Array in offs:
		assert_eq(row[1], &"operator")
	for c: SecurityCamera in _cams():
		assert_false(c.can_observe(), "all cameras off permanently")
	assert_true(s.cameras_off)
	var screens: MeshInstance3D = s.visual_node("Screens") as MeshInstance3D
	assert_true(screens.material_override != null, "Screens material off")


## B r308 05_camera_operator: PD2, no prompt on the console while the operator sits at it; it targets again once he
## is off duty.
func test_s8_2_no_console_prompt_while_the_operator_is_on_duty() -> void:
	var s: CameraStation = _station()
	assert_false(s.interactable.aim_filter.call(_crew()), "operator at the desk: no prompt at all")
	_kill(s.operator)
	assert_true(s.interactable.aim_filter.call(_crew()), "operator down: the console targets again")
	assert_eq(s._loop_check(_crew()), CameraStation.BLOCK_CAMERAS_DOWN, "...and says the cameras are down")


func test_s8_2_dominate_operator_disables_cameras() -> void:
	var s: CameraStation = _station()
	s.operator.set_alert_state(Enums.AlertState.DOMINATED)
	assert_true(s.cameras_off, "dominated -> cameras off")
	for c: SecurityCamera in _cams():
		assert_false(c.can_observe())
	assert_eq(_cams()[0].disabled_reason, &"operator")


func test_s3_5_s8_2_running_countdown_survives_operator_death() -> void:
	Tweak.stealth().camera_alarm_delay_s = 1.5
	var c: CrewController = _crew()
	c.set_masked()
	await _place(Vector3(0, 0.05, -4))
	var ok: bool = await wait_until(func() -> bool: return _st.camera_countdown() > 0.0, 6.0)
	assert_true(ok, "camera countdown started")
	_kill(_station().operator)
	assert_true(_station().cameras_off)
	assert_true(_st.camera_countdown() > 0.0, "S3.5 the running countdown is not stopped")
	ok = await wait_until(func() -> bool: return _st.alarm_raised, 3.0)
	assert_true(ok, "alarm still sounds")
	assert_eq(_st.alarm_reason, &"camera")


func test_s8_2_no_new_countdown_after_operator_down() -> void:
	_kill(_station().operator)
	var c: CrewController = _crew()
	c.set_masked()
	await _place(Vector3(0, 0.05, -4))
	await wait_seconds(2.0)
	assert_near(_st.camera_countdown(), -1.0, 0.0001, "dead cameras never alert")


## Guard parked 10 m east of CamA facing away from it (cannot see the broken camera itself).
func _spawn_guard() -> NpcBase:
	var g: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), Vector3(10, 0.05, -2)))
	await wait_physics_frames(3)
	return g


func test_s8_1_operator_dispatches_nearest_guard() -> void:
	var tw: StealthTweak = Tweak.stealth()
	tw.camera_dispatch_chance = 1.0
	tw.camera_dispatch_delay_s = 0.5
	var g: NpcBase = await _spawn_guard()
	var sent: Array[NpcBase] = []
	_station().guard_dispatched.connect(func(guard: NpcBase, _c: SecurityCamera) -> void: sent.append(guard))
	var cam: SecurityCamera = _rt.map.get_node(^"Gameplay/CamA") as SecurityCamera
	_break(cam)
	await wait_seconds(0.25)
	assert_true(sent.is_empty(), "not before the dispatch delay")
	var ok: bool = await wait_until(func() -> bool: return not sent.is_empty(), 2.0)
	assert_true(ok, "dispatched after the delay")
	assert_eq(sent[0], g, "the nearest guard, never the operator")
	assert_true(g.alert_state == Enums.AlertState.CURIOUS or g.alert_state == Enums.AlertState.INVESTIGATING)
	var brain: GuardBrain = g.get_node(^"Brain") as GuardBrain
	assert_true(brain.focus_position.distance_to(cam.broken_position()) < 0.01, "investigates the broken camera")


func test_s8_1_dispatch_roll_is_seeded() -> void:
	var tw: StealthTweak = Tweak.stealth()
	tw.camera_dispatch_delay_s = 0.2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([SEED, String(CameraStation.RNG_STREAM)])
	var expected: bool = rng.randf() < tw.camera_dispatch_chance
	await _spawn_guard()
	var sent: Array[NpcBase] = []
	_station().guard_dispatched.connect(func(guard: NpcBase, _c: SecurityCamera) -> void: sent.append(guard))
	_break(_rt.map.get_node(^"Gameplay/CamA") as SecurityCamera)
	await wait_seconds(0.6)
	assert_eq(not sent.is_empty(), expected, "30%% roll on GameRng &\"cameras\" (seed %d)" % SEED)


func test_s8_1_no_dispatch_without_operator() -> void:
	var tw: StealthTweak = Tweak.stealth()
	tw.camera_dispatch_chance = 1.0
	tw.camera_dispatch_delay_s = 0.2
	await _spawn_guard()
	var sent: Array[NpcBase] = []
	_station().guard_dispatched.connect(func(guard: NpcBase, _c: SecurityCamera) -> void: sent.append(guard))
	_station().operator.set_alert_state(Enums.AlertState.DOMINATED)
	_break(_rt.map.get_node(^"Gameplay/CamA") as SecurityCamera)
	await wait_seconds(0.6)
	assert_true(sent.is_empty(), "nobody watches the feeds: no dispatch")
