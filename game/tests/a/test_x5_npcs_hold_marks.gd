## X-5 (heist_completion.md, ENV C audit): the navmesh is baked for agent_radius 0.30 (D-025) but NPC bodies were
## r 0.35 capsules, and tellers / the jeweler stand on marks right against their counter / bench (C's GH marks: the
## jeweler 0.28 m from the bench face, the counter associate behind the counter). Depenetration and PO-10 idle
## drift pushed them off (GH jeweler ended at (8.2, 1.25)). Now every NPC capsule is r 0.30, and a calm idle
## civilian at its authored activity mark is held there (NpcMotor.hold_mark): no drift, no push.
extends TestCase

## ENV C's GH marks (env/c-worlds 6738c290): Variants/*/Jeweler and Spawns/CivCounterAssociate.
const JEWELER_MARK: Vector3 = Vector3(8.5, 0.0, 1.18)
const COUNTER_MARK: Vector3 = Vector3(3.6, 0.0, 6.9)
const NPC_SCENES: Array[String] = [
	"res://systems/ai/npc/npc_bulwark.tscn", "res://systems/ai/npc/npc_cartel.tscn",
	"res://systems/ai/npc/npc_civilian.tscn", "res://systems/ai/npc/npc_corpsman.tscn",
	"res://systems/ai/npc/npc_guard.tscn", "res://systems/ai/npc/npc_longshot.tscn",
	"res://systems/ai/npc/npc_phantom.tscn", "res://systems/ai/npc/npc_police.tscn",
	"res://systems/ai/npc/npc_stinger.tscn", "res://systems/ai/npc/npc_wrecker.tscn",
]

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_x5_npc_capsule_matches_nav_agent_radius() -> void:
	for path: String in NPC_SCENES:
		var npc: Node = (load(path) as PackedScene).instantiate()
		var col: CollisionShape3D = npc.get_node(^"Collision") as CollisionShape3D
		var cap: CapsuleShape3D = col.shape as CapsuleShape3D
		assert_true(cap != null, "%s body is a capsule" % path)
		if cap != null:
			assert_near(cap.radius, 0.3, 0.001, "%s capsule r = nav agent_radius 0.30 (D-025)" % path)
		var agent: NavigationAgent3D = npc.get_node_or_null(^"NavAgent") as NavigationAgent3D
		if agent != null:
			assert_near(agent.radius, 0.3, 0.001, "%s NavAgent radius 0.30" % path)
		npc.free()


func test_x5_gh_jeweler_and_counter_associate_hold_their_marks() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 2, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(3)
	var watch: Array[NpcBase] = []
	for n: Node in _rt.npcs(&"civilian"):
		var tags: Array = (n as NpcBase).spawn_info.get("tags", [])
		if tags.has(&"civ_staff_workshop") or tags.has(&"civ_staff_counter"):
			watch.append(n as NpcBase)
	# C's marks (against the bench / counter), each with a second NPC stacked 0.25 m away (PO-10 drift bait).
	watch.append(_rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, JEWELER_MARK),
		{"idle_activity": &"desk_work", "tags": [&"civ_staff_workshop"]}))
	watch.append(_rt.spawn_npc(&"civilian", Transform3D(Basis(Vector3.UP, PI), COUNTER_MARK),
		{"idle_activity": &"desk_work", "tags": [&"civ_staff_counter"]}))
	_rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, JEWELER_MARK + Vector3(0.25, 0.0, 0.05)),
		{"idle_activity": &"desk_work", "tags": [&"civ_staff_workshop"]})
	var start: Array[Vector3] = []
	for npc: NpcBase in watch:
		start.append(npc.global_position)  # the authored marks (spawn transforms)
	await wait_seconds(10.0)
	assert_true(watch.size() >= 3, "GH staff at their marks (%d)" % watch.size())
	for i: int in watch.size():
		var npc: NpcBase = watch[i]
		var b: CivilianBrain = npc.get_node(^"Brain") as CivilianBrain
		var d: float = _flat(start[i], npc.global_position)
		print("X-5 %s %s: %s -> %s (%.3f m), on_mark %s" % [npc.name, npc.spawn_info.get("tags"), start[i],
			npc.global_position, d, b.on_mark()])
		assert_true(d <= 0.1, "%s %s stays within 0.1 m of its mark after 10 s (moved %.2f m)" % [
			npc.name, npc.spawn_info.get("tags"), d])
		assert_true(b.on_mark(), "%s is held on its mark" % npc.name)


## A held civilian still panics and runs: the hold is only for calm idling.
func test_x5_hold_releases_on_panic() -> void:
	_rt = await HeistLauncher.launch(&"unit_x5", 5, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true})
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(4, 0.05, 4)), {"idle_activity": &"teller"})
	await wait_physics_frames(10)
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	var m: NpcMotor = civ.get_node(^"Motor") as NpcMotor
	assert_true(b.on_mark() and m.holding(), "idle teller held on its mark")
	b._panic(Vector3(2, 0, 4))
	await wait_physics_frames(2)
	assert_false(m.holding(), "panicked: not held")
	var p0: Vector3 = civ.global_position
	await wait_seconds(1.0)
	assert_true(_flat(p0, civ.global_position) > 0.3, "the panicked civilian moves off its mark")
