## Night Deposit: the police gates open before the first assault (LEAD, 2026-10-12; modelled on
## test_glasshouse_police_gates). AlleyGate, HarborWestGate, HarborEastGate and WharfNorthGate are BARRED and
## baked closed (D-073); the mission's lockdown unlocks and opens them (door NavLinks on). Proves: the gates are
## shut before the alarm; every gate is open and every police spawn has a navmesh path to the holdout
## (docs/design/heists/night_deposit.md: the basement; probed at B1 and the vault level) by the first frame the
## director is in an assault phase. Owner: ENV C. Setup shortcut: a compressed director (launch option
## `director_tweak`, first_control_s 4 s), NPCs despawned, the alarm raised by the test.
extends TestCase

const HEIST: StringName = &"night_deposit"
const SEEDS: Array[int] = [1001, 3071]
const DIRECTOR_TWEAK: String = "res://systems/director/director_tweak.tres"
const HOLDOUTS: Dictionary = {"basement_B1": Vector3(3.5, -4.0, 3.0), "basement_vault_level": Vector3(14.0, -4.0, 11.5)}
const GATES: Array[StringName] = [&"AlleyGate", &"HarborWestGate", &"HarborEastGate", &"WharfNorthGate"]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_gates_open_before_first_assault() -> void:
	for s: int in SEEDS:
		await _run(s)
		if _rt != null and is_instance_valid(_rt):
			_rt.teardown()
		_rt = null
		await wait_frames(2)


func _run(run_seed: int) -> void:
	var tw: DirectorTweak = (load(DIRECTOR_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 4.0
	tw.anticipation_s = 2.0
	_rt = await HeistLauncher.launch(HEIST, run_seed, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true, "director_tweak": tw})
	if _rt == null:
		fail("launch seed %d" % run_seed)
		return
	var c: Node3D = _rt.crew_controller(0) as Node3D
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	_rt.isolate_npc(null)
	var gates: Array[Door] = []
	for n: Node in _rt.map.get_node("Gameplay/Doors").get_children():
		if n is Door and String(n.name).ends_with("Gate") and (n as Door).lock == Door.Lock.BARRED \
				and (n as Node3D).is_visible_in_tree():
			gates.append(n as Door)
	for gn: StringName in GATES:
		assert_true(gates.any(func(g0: Door) -> bool: return g0.name == gn), "seed %d: %s present" % [run_seed, gn])
	for g: Door in gates:
		assert_false(g.is_open, "seed %d: %s shut before the alarm" % [run_seed, g.name])
	_rt.stealth.raise_alarm(&"pp_gate_test", 0)
	assert_true(await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, 3.0), "LOUD")
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var assault: bool = await wait_until(func() -> bool: return d.is_assault_active(), 120.0)
	assert_true(assault, "seed %d: first assault started" % run_seed)
	for g2: Door in gates:
		assert_true(g2.is_open, "seed %d: %s open by the first assault (phase %d)" % [run_seed, g2.name, d.assault_phase])
	await wait_physics_frames(3)
	var rid: RID = c.get_world_3d().navigation_map
	var n_ok: int = 0
	for sp: Node in _rt.map.find_children("*", "SpawnPoint", true, false):
		var p: SpawnPoint = sp as SpawnPoint
		if p.kind != SpawnPoint.Kind.POLICE or not p.is_visible_in_tree() :
			continue
		var a: Vector3 = NavigationServer3D.map_get_closest_point(rid, p.global_position)
		for h: String in HOLDOUTS:
			var b: Vector3 = NavigationServer3D.map_get_closest_point(rid, HOLDOUTS[h])
			var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, a, b, true)
			var ok: bool = path.size() >= 2 and path[path.size() - 1].distance_to(b) < 0.75
			assert_true(ok, "seed %d: %s reaches %s once the gates are open" % [run_seed, p.name, h])
			n_ok += 1 if ok else 0
	print("[C3] seed %d: %d gates open by the first assault, %d spawn->holdout paths" % [run_seed, gates.size(), n_ok])
