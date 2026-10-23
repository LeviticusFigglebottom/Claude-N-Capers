## Tag Team gas tethers (D-163; `EventBus.crew_tether_fx(a_slot, b_slot, active)`). Owner: ENV C. Child of VfxDirector.
## A subtle link between two paired allies at chest height: a faint additive ribbon (a thin box stretched between
## the two bodies) and MOTES small glows travelling from a to b, one pulse every PULSE_S. The ends follow the bodies
## every frame (`ends` callables, so the director resolves crew controllers and tests pass plain nodes).
## Pool: VfxSettings.TETHER_CAP tethers (4 crew -> at most 4 pairs).
class_name TetherFx
extends Node3D

const PULSE_S: float = 0.2
const MOTES: int = 3
const CHEST_Y_M: float = 1.2
const COLOR: Color = Color(0.55, 0.95, 0.7)
const LINE_ALPHA: float = 0.14
const MOTE_ALPHA: float = 0.5
const LINE_WIDTH_M: float = 0.025
const MOTE_SIZE_M: float = 0.12

var _links: Array[Node3D] = []
## Per link: [a: Node3D, b: Node3D, key: Vector2i] or [] when free
var _ends: Array[Array] = []
var _time_s: float = 0.0
var _cap: int = VfxSettings.TETHER_CAP


func _init() -> void:
	name = "Tethers"


func cap() -> int:
	return _cap


func set_cap(c: int) -> void:
	_cap = maxi(1, c)
	for l: Node3D in _links:
		l.queue_free()
	_links.clear()
	_ends.clear()


func active_count() -> int:
	var n: int = 0
	for e: Array in _ends:
		if not e.is_empty():
			n += 1
	return n


## Link `a` and `b` (any Node3D: the crew bodies) under `key` (the slot pair). Returns false when the pool is full.
func link(key: Vector2i, a: Node3D, b: Node3D) -> bool:
	var i: int = _find(key)
	if i < 0:
		i = _free_slot()
	if i < 0:
		return false
	_ends[i] = [a, b, key]
	_links[i].visible = true
	_place(i)
	return true


func unlink(key: Vector2i) -> void:
	var i: int = _find(key)
	if i >= 0:
		_ends[i] = []
		_links[i].visible = false


func advance(delta: float) -> void:
	_time_s += delta
	for i: int in range(_links.size()):
		if _ends[i].is_empty():
			continue
		var ea: Variant = _ends[i][0]
		var eb: Variant = _ends[i][1]
		if not is_instance_valid(ea) or not is_instance_valid(eb) or not (ea as Node3D).is_inside_tree() \
				or not (eb as Node3D).is_inside_tree():
			unlink(_ends[i][2])
			continue
		_place(i)


func clear() -> void:
	for i: int in range(_links.size()):
		_ends[i] = []
		_links[i].visible = false


func _place(i: int) -> void:
	var a: Node3D = _ends[i][0]
	var b: Node3D = _ends[i][1]
	if not a.is_inside_tree() or not b.is_inside_tree():
		return
	var pa: Vector3 = a.global_position + Vector3.UP * CHEST_Y_M
	var pb: Vector3 = b.global_position + Vector3.UP * CHEST_Y_M
	var l: Node3D = _links[i]
	var line: MeshInstance3D = l.get_node("Line") as MeshInstance3D
	var span: Vector3 = pb - pa
	var length: float = span.length()
	line.visible = length > 0.05
	if line.visible:
		var up: Vector3 = Vector3.UP if absf(span.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		line.global_transform = Transform3D(Basis.looking_at(span, up).scaled(Vector3(1.0, 1.0, length)),
			(pa + pb) * 0.5)
	for m: int in range(MOTES):
		var t: float = fposmod(_time_s / PULSE_S + float(m) / float(MOTES), 1.0)
		var mote: MeshInstance3D = l.get_node("Mote%d" % m) as MeshInstance3D
		mote.global_position = pa.lerp(pb, t)


func _find(key: Vector2i) -> int:
	for i: int in range(_ends.size()):
		if not _ends[i].is_empty() and _ends[i][2] == key:
			return i
	return -1


func _free_slot() -> int:
	for i: int in range(_ends.size()):
		if _ends[i].is_empty():
			return i
	if _links.size() >= _cap:
		return -1
	_links.append(_build_link())
	_ends.append([])
	return _links.size() - 1


func _build_link() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Tether%d" % _links.size()
	root.visible = false
	var line: MeshInstance3D = MeshInstance3D.new()
	line.name = "Line"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(LINE_WIDTH_M, LINE_WIDTH_M, 1.0)
	box.material = _mat(VfxTextures.flash(), LINE_ALPHA, false)
	line.mesh = box
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(line)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * MOTE_SIZE_M
	quad.material = _mat(VfxTextures.flash(), MOTE_ALPHA, true)
	for m: int in range(MOTES):
		var mote: MeshInstance3D = MeshInstance3D.new()
		mote.name = "Mote%d" % m
		mote.mesh = quad
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mote)
	add_child(root)
	return root


static func _mat(tex: Texture2D, alpha: float, billboard: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = VfxTextures.additive_material(tex, false)
	m.vertex_color_use_as_albedo = false
	m.albedo_color = Color(COLOR, alpha)
	if not billboard:
		m.albedo_texture = null  # the ribbon is a plain faint bar
	else:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m
