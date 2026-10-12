## Dockside Burn: the police gates open before the first assault (LEAD ruling 2026-10-12 on PP-C-1 /
## D-070). Ferro St (P1e/P1w), Bellweather (P2) and Pier 10 (P3) POLICE spawns sit behind BARRED play-space
## gates baked closed (D-073); the mission's police_delay timer unlocks and opens them (door NavLinks on)
## when the director's start hold ends. Proves: the gates are shut in the cartel phase; every gate is open
## and every police spawn has a navmesh path to every holdout by the first frame the director is in an
## assault phase. Owner: ENV C. Setup shortcut: a compressed director (launch option `director_tweak`,
## first_control_s 4 s; the mission compresses the cartel hold by the same factor), NPCs despawned.
extends TestCase

const HEIST: StringName = &"dockside_burn"
const SEEDS: Array[int] = [1001, 3007]
const DIRECTOR_TWEAK: String = "res://systems/director/director_tweak.tres"
const HOLDOUTS: Dictionary = {
	"H1": Vector3(16.0, 3.6, 3.0), "H2": Vector3(30.0, 0.0, 28.0), "H3": Vector3(18.0, 0.0, 37.0),
	"H4": Vector3(30.0, 0.0, -28.0),
}

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
	_rt = await HeistLauncher.launch(HEIST, run_seed, Enums.Difficulty.HAZARDOUS, self,
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
	assert_true(gates.size() >= 4, "seed %d: police gates found (%d)" % [run_seed, gates.size()])
	_rt.stealth.raise_alarm(&"pp_gate_test", 0)
	assert_true(await wait_until(func() -> bool: return _rt.phase == Enums.HeistPhase.LOUD, 3.0), "LOUD")
	for g: Door in gates:
		assert_false(g.is_open, "seed %d: %s shut during the cartel phase" % [run_seed, g.name])
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
		if p.kind != SpawnPoint.Kind.POLICE or not p.is_visible_in_tree() or p.name == &"PoliceRoof":
			continue
		var a: Vector3 = NavigationServer3D.map_get_closest_point(rid, p.global_position)
		for h: String in HOLDOUTS:
			var b: Vector3 = NavigationServer3D.map_get_closest_point(rid, HOLDOUTS[h])
			var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, a, b, true)
			var ok: bool = path.size() >= 2 and path[path.size() - 1].distance_to(b) < 0.75
			assert_true(ok, "seed %d: %s reaches %s once the gates are open" % [run_seed, p.name, h])
			n_ok += 1 if ok else 0
	print("[C3] seed %d: %d gates open by the first assault, %d spawn->holdout paths" % [run_seed, gates.size(), n_ok])
