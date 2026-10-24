## LEAD / A det_loud_replay root cause: a downed heister's move_and_slide (v = 0) depenetrated from police capsules
## overlapping it, so cops shoved the body 0.13 m a tick (in contact order: nondeterministic). While not mobile
## (downed, cuffed, tased...) the crew masks NPCs out; PD2: cops don't push a downed heister around. Control: the same
## overlap does push a mobile crew, so the downed case is not passing by accident. Owner: ENV P.
extends TestCase

const NPC_LAYER: int = 1 << 3  # NpcBase.LAYER_NPCS
## Each NPC's offset from the crew (unequal overlaps: a net push when NPCs collide).
const OFFSETS: Array[float] = [0.35, -0.25]

var _root: Node3D = null
var _npcs: Array[StaticBody3D] = []


func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_npcs.clear()
	await wait_frames(2)


## A hub walker at the origin on a floor, with two NPC-layer capsules overlapping its capsule from both sides.
func _crew_between_npcs() -> CrewController:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	add_child(_root)
	ATestMaps.add_wall(_root, Vector3(0, -0.1, 0), Vector3(20, 0.2, 20))  # floor
	await wait_frames(1)
	var c: CrewController = CrewController.spawn_for_hub(_root, Transform3D.IDENTITY, null) as CrewController
	for x: float in OFFSETS:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = NPC_LAYER
		body.collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.8
		shape.shape = cap
		body.add_child(shape)
		_root.add_child(body)
		body.global_position = Vector3(x, 0.9, 0.0)
		_npcs.append(body)
	return c


## Ticks with the NPC capsules kept overlapping the crew (police standing on / walking into the body, A's DetTrace:
## police6/7 over a downed crew 1): re-placed at their offsets from the crew before every physics tick.
func _drift(c: CrewController, ticks: int) -> float:
	var p0: Vector3 = c.global_position
	for _t: int in ticks:
		for k: int in _npcs.size():
			_npcs[k].global_position = Vector3(c.global_position.x + OFFSETS[k], 0.9, c.global_position.z)
		await wait_physics_frames(1)
	return Vector2(c.global_position.x - p0.x, c.global_position.z - p0.z).length()


func test_downed_body_is_not_shoved_by_overlapping_npcs() -> void:
	var c: CrewController = await _crew_between_npcs()
	c.set_crew_state(Enums.CrewState.DOWNED)
	await wait_physics_frames(1)
	var d: float = await _drift(c, 30)
	assert_true(d < 0.01, "downed: 30 ticks between two overlapping NPC capsules moved %.3f m (want ~0)" % d)
	assert_eq(c.collision_mask & NPC_LAYER, 0, "downed: NPCs are masked out")


func test_mobile_crew_in_the_same_overlap_is_pushed() -> void:
	var c: CrewController = await _crew_between_npcs()
	assert_eq(c.collision_mask & NPC_LAYER, NPC_LAYER, "mobile: NPCs collide")
	var d: float = await _drift(c, 30)
	assert_true(d > 0.01, "control: a mobile crew in the same overlap is pushed (moved %.3f m)" % d)


func test_mobile_again_restores_the_npc_mask() -> void:
	var c: CrewController = await _crew_between_npcs()
	c.set_crew_state(Enums.CrewState.TASED)
	await wait_physics_frames(2)
	assert_eq(c.collision_mask & NPC_LAYER, 0, "tased: NPCs masked out")
	c.set_crew_state(Enums.CrewState.NORMAL)
	await wait_physics_frames(2)
	assert_eq(c.collision_mask & NPC_LAYER, NPC_LAYER, "back on its feet: NPCs collide again")
