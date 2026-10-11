## QC-36 (L4.10, D-064): cartel gunmen on GUARD spawns tagged `cartel` (enemy.cartel_gunman, role cartel):
## asleep on their post until a noise / sighting / damage / shout wakes them (and their neighbours); never
## dominated; hostile to the crew; not police units, but they take from the police budget (shared enemy_cap).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(posts: Array[Vector3]) -> Array[NpcBase]:
	var specs: Array[Dictionary] = []
	for p: Vector3 in posts:
		specs.append({"kind": SpawnPoint.Kind.GUARD, "tags": [CartelBrain.SPAWN_TAG], "pos": p})
	_rt = await HeistLauncher.launch(&"unit_map", 3601, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_tagged_spawns(specs), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(3)
	var out: Array[NpcBase] = []
	for n: Node in _rt.npcs(CartelBrain.ROLE):
		out.append(n as NpcBase)
	return out


func _brain(n: NpcBase) -> CartelBrain:
	return n.get_node("Brain") as CartelBrain


func test_spawned_as_cartel_not_police() -> void:
	var g: Array[NpcBase] = await _launch([Vector3(0, 0.05, -10)] as Array[Vector3])
	assert_eq(g.size(), 1, "one cartel gunman on the tagged GUARD spawn")
	assert_eq(g[0].enemy_def.id, &"enemy.cartel_gunman")
	assert_eq(g[0].alert_state, Enums.AlertState.CALM, "starts asleep")
	assert_false(g[0].is_in_group(G.OBSERVER), "no stealth meter")
	assert_true(_rt.npcs(&"guard").is_empty(), "no guard on that spawn")
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_false(d.alive_units().has(g[0]), "not a police unit")
	assert_eq(d.police_budget(), d.enemy_cap() - 1, "alive gunmen take from the police budget (D-064)")


func test_gunshot_wakes_and_spreads() -> void:
	var g: Array[NpcBase] = await _launch([Vector3(0, 0.05, -10), Vector3(6, 0.05, -10), Vector3(0, 0.05, -60)] as Array[Vector3])
	_rt.make_noise(Vector3(0, 1, -8), 10.0, &"gunshot", 0)
	await wait_physics_frames(1)
	var near: NpcBase = null
	var far: NpcBase = null
	for n: NpcBase in g:
		if n.global_position.z < -40.0:
			far = n
		elif near == null:
			near = n
	assert_eq(near.alert_state, Enums.AlertState.COMBAT, "the gunshot woke the gunman it reached")
	for n: NpcBase in g:
		if n != far:
			assert_eq(n.alert_state, Enums.AlertState.COMBAT, "the post next to it woke too (shout)")
	assert_eq(far.alert_state, Enums.AlertState.CALM, "a post 50 m away sleeps on")


func test_sighting_wakes_and_fights() -> void:
	var g: Array[NpcBase] = await _launch([Vector3(0, 0.05, -8)] as Array[Vector3])
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	# The post faces -Z (spawn basis); put the crew member in front of it.
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, g[0].global_position + g[0].look_forward() * 8.0))
	await wait_seconds(CartelTweak.new().sight_time_s + 0.6)
	assert_eq(g[0].alert_state, Enums.AlertState.COMBAT, "seen: awake")
	assert_eq(_brain(g[0]).woken_by, &"sight")
	await wait_seconds(0.8)
	assert_eq(_brain(g[0]).combat_target, c, "targets the crew member")
	assert_true(_brain(g[0]).wants_to_fire, "and shoots")


func test_shout_never_dominates_and_damage_wakes() -> void:
	var g: Array[NpcBase] = await _launch([Vector3(0, 0.05, -10), Vector3(0, 0.05, -60)] as Array[Vector3])
	var a: NpcBase = g[0] if g[0].global_position.z > -30.0 else g[1]
	var b: NpcBase = g[1] if a == g[0] else g[0]
	assert_false(_brain(a).on_shouted(_rt.crew_controller(0)), "L4.10: never dominated")
	assert_eq(a.alert_state, Enums.AlertState.COMBAT, "a shout wakes it")
	ACombatSpecials.hit(b, 1.0)
	await wait_physics_frames(1)
	assert_eq(b.alert_state, Enums.AlertState.COMBAT, "damage wakes it")
	assert_eq(_brain(b).woken_by, &"damage")
