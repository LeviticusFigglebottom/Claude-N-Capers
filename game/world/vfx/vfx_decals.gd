## Pooled bullet-hole and scorch decals (impact_fx.md §3: cap 128 per map, fade after 60 s, recycle
## oldest). Owner: ENV C. Child of VfxDirector; time advanced by `advance(delta)`.
## Forward+/Mobile: Decal nodes (project onto whatever is there, depth 0.08 m).
## Compatibility (OpenGL 3, no Decal support): an oriented quad 4 mm off the surface (same texture).
class_name VfxDecals
extends Node3D

const DEPTH_M: float = 0.08
const QUAD_OFFSET_M: float = 0.004

## Live decal count (tests).
var live: int = 0
var use_decal_nodes: bool = true

var _cap: int = VfxSettings.DECAL_CAP
## Pool slots, created on demand up to `_cap`; each is a Decal or a MeshInstance3D.
var _slots: Array[Node3D] = []
var _age: PackedFloat32Array = PackedFloat32Array()
var _hold: PackedFloat32Array = PackedFloat32Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _materials: Dictionary[StringName, StandardMaterial3D] = {}


func _init() -> void:
	name = "Decals"
	use_decal_nodes = VfxSettings.use_decal_nodes()


func cap() -> int:
	return _cap


func slot_count() -> int:
	return _slots.size()


## Shrink/grow the cap (quality change). Excess slots are freed (oldest first by ring order).
func set_cap(c: int) -> void:
	_cap = maxi(1, c)
	while _slots.size() > _cap:
		var i: int = _slots.size() - 1
		if _age[i] >= 0.0:
			live -= 1
		_slots[i].queue_free()
		_slots.remove_at(i)
		_age.remove_at(i)
		_hold.remove_at(i)
		_alpha.remove_at(i)


## Place a decal for `kind` (a surface id, or &"scorch") at `pos` facing `normal`, `size` m across.
func place(kind: StringName, pos: Vector3, normal: Vector3, size: float, hold_s: float = VfxSettings.DECAL_HOLD_S,
		spin: float = 0.0) -> Node3D:
	var tex: Texture2D = VfxTextures.scorch() if kind == &"scorch" else VfxTextures.hole(kind)
	if tex == null:
		return null
	var i: int = _take_slot()
	var node: Node3D = _slots[i]
	var b: Basis = Basis.IDENTITY
	if normal != Vector3.ZERO:
		b = ImpactFx.basis_from_normal(normal).rotated(normal.normalized(), spin)
	if use_decal_nodes:
		var d: Decal = node as Decal
		d.texture_albedo = tex
		d.size = Vector3(size, DEPTH_M, size)
		d.modulate = Color(1, 1, 1, 1)
		_apply_xf(d, Transform3D(b, pos))
	else:
		var m: MeshInstance3D = node as MeshInstance3D
		var mat: StandardMaterial3D = _material(kind, tex)
		m.material_override = mat
		m.scale = Vector3.ONE
		_apply_xf(m, Transform3D(b.scaled_local(Vector3(size, 1.0, size)), pos + normal.normalized() * QUAD_OFFSET_M))
		m.transparency = 0.0
	node.visible = true
	if _age[i] < 0.0:
		live += 1
	_age[i] = 0.0
	_hold[i] = hold_s
	_alpha[i] = 1.0
	return node


func advance(delta: float) -> void:
	for i: int in range(_slots.size()):
		if _age[i] < 0.0:
			continue
		_age[i] += delta
		var over: float = _age[i] - _hold[i]
		if over <= 0.0:
			continue
		var a: float = 1.0 - over / VfxSettings.DECAL_FADE_S
		if a <= 0.0:
			_age[i] = -1.0
			_slots[i].visible = false
			live -= 1
			continue
		_set_alpha(i, a)


## Hide everything (map reset).
func clear() -> void:
	for i: int in range(_slots.size()):
		_age[i] = -1.0
		_slots[i].visible = false
	live = 0


## World-space placement (the director normally sits at the origin; works when it does not).
func _apply_xf(n: Node3D, xf: Transform3D) -> void:
	if is_inside_tree():
		n.global_transform = xf
	else:
		n.transform = xf


func _set_alpha(i: int, a: float) -> void:
	_alpha[i] = a
	if use_decal_nodes:
		(_slots[i] as Decal).modulate = Color(1, 1, 1, a)
	else:
		(_slots[i] as MeshInstance3D).transparency = 1.0 - a


## A free slot, a new slot (under the cap), or the oldest live one.
func _take_slot() -> int:
	for i: int in range(_slots.size()):
		if _age[i] < 0.0:
			return i
	if _slots.size() < _cap:
		_slots.append(_new_node())
		_age.append(-1.0)
		_hold.append(0.0)
		_alpha.append(0.0)
		return _slots.size() - 1
	var oldest: int = 0
	for i: int in range(1, _slots.size()):
		if _age[i] > _age[oldest]:
			oldest = i
	return oldest


func _new_node() -> Node3D:
	var n: Node3D
	if use_decal_nodes:
		var d: Decal = Decal.new()
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		d.normal_fade = 0.5
		d.cull_mask = 0xFFFFF  # world layers 1-20 only: never onto the viewmodel / hidden FP body
		n = d
	else:
		var m: MeshInstance3D = MeshInstance3D.new()
		var q: PlaneMesh = PlaneMesh.new()
		q.size = Vector2.ONE  # +Y facing, scaled per placement
		m.mesh = q
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n = m
	n.name = "Decal%d" % _slots.size()
	n.visible = false
	add_child(n)
	return n


func _material(kind: StringName, tex: Texture2D) -> StandardMaterial3D:
	if not _materials.has(kind):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.9
		m.render_priority = 1
		_materials[kind] = m
	return _materials[kind]
