## PO6-20: yellow contour on a guard whose pager is live, within 15 m of the camera, from the replicated facts.
extends TestCase

var _po: PagerOutline
var _guard: Node3D
var _mesh: MeshInstance3D
var _cam: Node3D
var _id: int = 0


func before_each() -> void:
	_po = PagerOutline.new()
	add_child(_po)
	_po.connect_event_bus()
	_guard = Node3D.new()
	var vis: Node3D = Node3D.new()
	vis.name = "Visual"
	_mesh = MeshInstance3D.new()
	_mesh.mesh = CapsuleMesh.new()
	vis.add_child(_mesh)
	_guard.add_child(vis)
	add_child(_guard)
	_id = Ids.next()
	Ids.register(_id, _guard)
	_cam = Node3D.new()
	add_child(_cam)
	_po.camera_override = _cam


func after_each() -> void:
	_po.disconnect_event_bus()
	for n: Node in [_po, _guard, _cam]:
		n.queue_free()


func test_outline_follows_pager_facts() -> void:
	_cam.position = Vector3(0, 1.7, 8.0)
	EventBus.pager_started.emit(11, _id)
	assert_true(_po.is_outlined(_mesh), "outlined while the pager is live")
	assert_true(_mesh.material_overlay == _po.material(), "overlay material set")
	var mat: ShaderMaterial = _po.material()
	assert_true(mat.shader.code.contains("depth_test_disabled"), "visible through walls")
	var shell: ShaderMaterial = mat.next_pass as ShaderMaterial
	assert_true(shell != null and shell.shader.code.contains("compare_not_equal"), "shell masked to outside the body")
	assert_true(float(shell.get_shader_parameter(&"width_m")) >= 0.05, "bold band (~3-4 px at 10 m)")
	EventBus.pager_answered.emit(11, 0, 1)
	assert_false(_po.is_outlined(_mesh), "gone after the answer")
	assert_true(_mesh.material_overlay == null, "overlay removed")
	EventBus.pager_started.emit(12, _id)
	EventBus.pager_failed.emit(12, &"expired")
	assert_false(_po.is_outlined(_mesh), "gone after a failed pager")
	assert_true(_po.active_pagers().is_empty())


func test_outline_only_within_range() -> void:
	_cam.position = Vector3(0, 1.7, PagerOutline.RANGE_M + 5.0)
	EventBus.pager_started.emit(13, _id)
	assert_false(_po.is_outlined(_mesh), "no outline beyond 15 m")
	_cam.position = Vector3(0, 1.7, PagerOutline.RANGE_M - 2.0)
	_po.refresh()
	assert_true(_po.is_outlined(_mesh), "outline once within 15 m")
	_cam.position = Vector3(0, 1.7, PagerOutline.RANGE_M + 5.0)
	_po.refresh()
	assert_false(_po.is_outlined(_mesh), "off again out of range")
	EventBus.pager_failed.emit(13, &"expired")


func test_never_replaces_another_overlay() -> void:
	var other: StandardMaterial3D = StandardMaterial3D.new()
	_mesh.material_overlay = other
	_cam.position = Vector3(0, 1.7, 4.0)
	EventBus.pager_started.emit(14, _id)
	assert_true(_mesh.material_overlay == other, "a foreign overlay is kept")
	EventBus.pager_answered.emit(14, 0, 1)
	assert_true(_mesh.material_overlay == other, "and left alone at the end")
