## PO6-20: PD2-style yellow contour on a guard body whose pager is live, visible through walls within RANGE_M of
## the local camera. Owner: ENV C. Child of VfxDirector; presentation only, driven by the replicated facts:
## pager_started(pager_id, guard_net_id) outlines Ids.lookup(guard_net_id)'s `Visual` meshes; pager_answered /
## pager_failed of that pager_id removes it. The look: a stencil-masked shell (a bold band just outside the
## silhouette) with a soft glow and a gentle pulse, depth test off so it shows through walls (lead r213).
class_name PagerOutline
extends Node

const RANGE_M: float = 15.0
const COLOR: Color = Color(1.0, 0.84, 0.12)
## Two passes on the overlay: MASK writes stencil 1 over the body (no colour), SHELL is the body pushed out along its
## normals, drawn only where the stencil is not 1, i.e. a bold band around the silhouette, through walls.
const MASK_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;
stencil_mode write, compare_always, 1;
void fragment() {
	ALBEDO = vec3(0.0);
}
"""
const SHELL_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;
stencil_mode read, compare_not_equal, 1;
uniform vec4 color : source_color = vec4(1.0, 0.84, 0.12, 1.0);
uniform float width_m = 0.06;
uniform float pulse = 0.18;
uniform float strength = 1.5;
void vertex() {
	float k = 1.0 + pulse * sin(TIME * 4.2);
	VERTEX += NORMAL * width_m * k;
}
void fragment() {
	float rim = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float glow = 0.75 + 0.25 * sin(TIME * 4.2);
	ALBEDO = color.rgb * strength * glow;
	ALPHA = clamp((0.55 + 0.45 * rim) * color.a, 0.0, 1.0);
}
"""
## Shell thickness (m): ~3-4 px at 10 m on a 720p view.
const WIDTH_M: float = 0.06

## Test hook: the camera position used for the range check (else the viewport's current camera).
var camera_override: Node3D = null

var _material: ShaderMaterial = null
## pager_id -> guard net id
var _pagers: Dictionary[int, int] = {}
## mesh -> true while it wears our overlay
var _outlined: Dictionary[GeometryInstance3D, bool] = {}


func _init() -> void:
	name = "PagerOutline"
	var mask: Shader = Shader.new()
	mask.code = MASK_CODE
	var shell: Shader = Shader.new()
	shell.code = SHELL_CODE
	_material = ShaderMaterial.new()
	_material.shader = mask
	_material.render_priority = 0
	var shell_mat: ShaderMaterial = ShaderMaterial.new()
	shell_mat.shader = shell
	shell_mat.render_priority = 1
	shell_mat.set_shader_parameter(&"color", COLOR)
	shell_mat.set_shader_parameter(&"width_m", WIDTH_M)
	_material.next_pass = shell_mat


func connect_event_bus() -> void:
	for pair: Array in [[&"pager_started", _on_pager_started], [&"pager_answered", _on_pager_answered],
			[&"pager_failed", _on_pager_failed]]:
		if EventBus.has_signal(pair[0]) and not EventBus.is_connected(pair[0], pair[1]):
			EventBus.connect(pair[0], pair[1])


func disconnect_event_bus() -> void:
	for pair: Array in [[&"pager_started", _on_pager_started], [&"pager_answered", _on_pager_answered],
			[&"pager_failed", _on_pager_failed]]:
		if EventBus.has_signal(pair[0]) and EventBus.is_connected(pair[0], pair[1]):
			EventBus.disconnect(pair[0], pair[1])


func material() -> ShaderMaterial:
	return _material


## Pagers currently outlined (tests).
func active_pagers() -> Array[int]:
	var out: Array[int] = []
	out.assign(_pagers.keys())
	return out


func is_outlined(mesh: GeometryInstance3D) -> bool:
	return _outlined.has(mesh) and mesh.material_overlay == _material


func clear() -> void:
	for k: Variant in _outlined.keys():
		# LEAD: a typed loop var errors on a freed mesh before is_instance_valid runs (round 214).
		if not is_instance_valid(k):
			continue
		var m: GeometryInstance3D = k as GeometryInstance3D
		if m != null and m.material_overlay == _material:
			m.material_overlay = null
	_outlined.clear()
	_pagers.clear()


func _process(_delta: float) -> void:
	if _pagers.is_empty():
		return
	refresh()


## Re-apply the overlay by range (every frame while a pager is live).
func refresh() -> void:
	var cam: Vector3 = _camera_pos()
	for pid: int in _pagers.keys():
		var guard: Node3D = Ids.lookup(_pagers[pid]) as Node3D
		if guard == null or not is_instance_valid(guard):
			continue
		var near: bool = cam != Vector3.INF and guard.global_position.distance_to(cam) <= RANGE_M and guard.visible
		for m: GeometryInstance3D in _meshes(guard):
			_outline(m, near)


func _on_pager_started(pager_id: int, guard_net_id: int) -> void:
	_pagers[pager_id] = guard_net_id
	refresh()


func _on_pager_answered(pager_id: int, _crew_slot: int, _answered_total: int) -> void:
	_end(pager_id)


func _on_pager_failed(pager_id: int, _reason: StringName) -> void:
	_end(pager_id)


func _end(pager_id: int) -> void:
	if not _pagers.has(pager_id):
		return
	var guard: Node3D = Ids.lookup(_pagers[pager_id]) as Node3D
	_pagers.erase(pager_id)
	if guard != null and is_instance_valid(guard):
		for m: GeometryInstance3D in _meshes(guard):
			_outline(m, false)


func _outline(m: GeometryInstance3D, on: bool) -> void:
	if on:
		if m.material_overlay == null or m.material_overlay == _material:
			m.material_overlay = _material
			_outlined[m] = true
	elif _outlined.has(m):
		if m.material_overlay == _material:
			m.material_overlay = null
		_outlined.erase(m)


func _meshes(guard: Node3D) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var root: Node = guard.get_node_or_null("Visual")
	if root == null:
		root = guard
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as GeometryInstance3D)
	return out


func _camera_pos() -> Vector3:
	if camera_override != null and is_instance_valid(camera_override):
		return camera_override.global_position
	var vp: Viewport = get_viewport() if is_inside_tree() else null
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	return cam.global_position if cam != null else Vector3.INF
