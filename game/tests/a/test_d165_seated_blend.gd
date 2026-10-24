## D-165 seated corrective (SeatedBlend): `blend_shapes/seated` on an Outfit mesh carrying the key goes to 1 over
## SeatedBlend.BLEND_S while the body plays a seated clip and back to 0 when it stands; a body spawned seated starts
## at 1; meshes without the key are left alone; the clip list (sit*, SEATED_CLIPS, the slump, variants) is the rule.
## Code-built rig (test_anim_driver's) with a code-built blend-shape mesh named Outfit.
extends TestCase

const ANIM_TEST: GDScript = preload("res://tests/a/test_anim_driver.gd")
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"\"\n"
const DT: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


## A one-triangle mesh with blend shape `shape` (or none when &"").
static func _mesh(shape: StringName) -> ArrayMesh:
	var m: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var blends: Array = []
	if shape != &"":
		m.add_blend_shape(shape)
		var b: Array = []
		b.resize(Mesh.ARRAY_MAX)
		b[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3(0, 0.5, 0.2)])
		blends.append(b)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends)
	return m


## A civilian on the test rig with an Outfit mesh (blend shape `shape`), spawned on brain hint `hint`.
func _civ(shape: StringName, hint: StringName) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"civilian"
	npc.net_id = 81500
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	var rig: Node3D = ANIM_TEST._test_rig()
	var outfit: MeshInstance3D = MeshInstance3D.new()
	outfit.name = SeatedBlend.OUTFIT_NODE
	outfit.mesh = _mesh(shape)
	rig.get_node(^"Skeleton3D").add_child(outfit)
	visual.add_child(rig)
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	brain.set(&"anim_hint", hint)
	npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	var d: AnimDriver = AnimDriver.of(npc)
	d.set_process(false)
	d.tick(DT)
	return npc


func _outfit(npc: NpcBase) -> MeshInstance3D:
	return npc.find_child(SeatedBlend.OUTFIT_NODE, true, false) as MeshInstance3D


func _value(npc: NpcBase) -> float:
	return float(_outfit(npc).get(SeatedBlend.PROPERTY))


func _ticks(npc: NpcBase, seconds: float) -> void:
	var d: AnimDriver = AnimDriver.of(npc)
	for _i: int in int(round(seconds / DT)):
		d.tick(DT)


func test_seated_clip_rule() -> void:
	for c: StringName in [&"sit_chair", &"sit_chair_read", &"sit_chair_watch", &"sit_chair_armed", &"sit_eat",
			&"sit_bed_read", &"sit_vehicle", &"sit_vehicle_drive", &"desk_work", &"phone_seated", &"cower_seated",
			&"death_seated_slump"]:
		assert_true(SeatedBlend.is_seated_clip(c), "%s is seated" % c)
	for c: StringName in [&"idle", &"walk", &"run", &"cower", &"browse", &"dance_a", &"death_seated_fall", &"lean_wall"]:
		assert_false(SeatedBlend.is_seated_clip(c), "%s is not seated" % c)
	assert_true(SeatedBlend.is_seated_clip(&"sit_chair_b", {&"sit_chair_b": &"sit_chair"}), "a seated variant")


func test_sit_down_and_stand_up_tween() -> void:
	var npc: NpcBase = _civ(SeatedBlend.SHAPE, &"")
	var d: AnimDriver = AnimDriver.of(npc)
	assert_eq(_value(npc), 0.0, "standing: 0")
	npc.get_node("Brain").set(&"anim_hint", &"sit")
	_ticks(npc, SeatedBlend.BLEND_S * 0.5)
	assert_eq(d.clip, &"sit_chair", "the driver plays the chair")
	assert_true(_value(npc) > 0.3 and _value(npc) < 0.7, "half way after half the blend: %.2f" % _value(npc))
	_ticks(npc, SeatedBlend.BLEND_S)
	assert_eq(_value(npc), 1.0, "seated: 1")
	npc.get_node("Brain").set(&"anim_hint", &"")
	_ticks(npc, SeatedBlend.BLEND_S * 0.5)
	assert_true(_value(npc) > 0.3 and _value(npc) < 0.7, "standing up: easing out %.2f" % _value(npc))
	_ticks(npc, SeatedBlend.BLEND_S)
	assert_eq(_value(npc), 0.0, "standing again: 0")


func test_spawned_seated_starts_at_one() -> void:
	var npc: NpcBase = _civ(SeatedBlend.SHAPE, &"sit_eat")
	assert_eq(AnimDriver.of(npc).clip, &"sit_eat")
	assert_eq(_value(npc), 1.0, "no slide-in on a body that spawns in its seat")


func test_mesh_without_the_key_is_untouched() -> void:
	var npc: NpcBase = _civ(&"other", &"sit")
	_ticks(npc, 0.5)
	assert_eq(AnimDriver.of(npc).seated_blend.value, 0.0, "no keyed mesh: nothing driven")
	assert_eq(_outfit(npc).get_blend_shape_value(0), 0.0, "the other key is left alone")
	var bare: NpcBase = _civ(&"", &"sit")
	_ticks(bare, 0.5)
	assert_eq(AnimDriver.of(bare).seated_blend.value, 0.0, "no blend shapes at all: skipped")
