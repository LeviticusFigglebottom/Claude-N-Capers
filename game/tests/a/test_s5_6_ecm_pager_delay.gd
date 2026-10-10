## A2-03 / S5.6: base ECM does not touch pagers; with stealth.ecm_pager_delay the 12 s window of a
## pager whose guard died during the jam pauses until the jam ends.
extends TestCase

const GUARD_POS: Vector3 = Vector3(5, 0.05, -5)

var _rt: HeistRuntime = null
var _started: Array[int] = []


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.pager_started.is_connected(_on_pager_started):
		EventBus.pager_started.disconnect(_on_pager_started)
	_started.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _on_pager_started(pid: int, _guard: int) -> void:
	_started.append(pid)


func _launch(flag: bool) -> void:
	if flag:
		Modifiers.set_source(0, &"test", {&"stealth.ecm_pager_delay": true})
	var l: Loadout = Loadout.new()
	l.deployable = &"deployable.ecm"
	_rt = await HeistLauncher.launch(&"unit_ecm_pagers", 56, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "ai_teammates": 0, "skip_casing": true, "loadouts": {0: l}})
	EventBus.pager_started.connect(_on_pager_started)


## Jam, kill the guard, wait for the beep. Returns the pager id.
func _jam_kill_and_beep() -> int:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, GUARD_POS + Vector3(0, 0, 1.5)))
	await wait_physics_frames(3)
	(_rt.service(DeployableSystem.SERVICE) as DeployableSystem).place(c)
	await wait_physics_frames(2)
	var g: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	g.die({}, c.net_id)
	var ok: bool = await wait_until(func() -> bool: return not _started.is_empty(), 6.0)
	assert_true(ok, "pager beeps")
	return _started[0] if ok else 0


func _window_left() -> float:
	var rows: Array[Dictionary] = (_rt.service(G.SVC_PAGERS) as PagerSystem).pager_entries()
	return float(rows[0]["time_left"]) if not rows.is_empty() else -1.0


func test_s5_6_base_ecm_does_not_pause_pagers() -> void:
	await _launch(false)
	await _jam_kill_and_beep()
	await wait_seconds(2.0)
	assert_true((HeistRuntime.get_service(&"ecm") as EcmSystem).is_jamming(), "still jamming")
	assert_true(_window_left() < Tweak.stealth().pager_window_s - 1.5, "window ticks (%.2f)" % _window_left())


func test_s5_6_pager_delay_pauses_window_during_jam() -> void:
	await _launch(true)
	await _jam_kill_and_beep()
	var ecm: EcmSystem = HeistRuntime.get_service(&"ecm") as EcmSystem
	assert_true(ecm.pager_delay_active(), "pager delay active")
	await wait_seconds(2.0)
	assert_near(_window_left(), Tweak.stealth().pager_window_s, 0.001, "window paused during the jam")
	var p: DeployablePrefab = (_rt.service(DeployableSystem.SERVICE) as DeployableSystem).placed(&"ecm")[0] as DeployablePrefab
	p.jam_left = 0.01
	await wait_seconds(1.5)
	assert_false(ecm.is_jamming(), "jam over")
	assert_true(_window_left() < Tweak.stealth().pager_window_s - 1.0, "window runs after the jam (%.2f)" % _window_left())
