## Pooled bullet-hole, scorch and blood decals (impact_fx.md §3: cap 128 per map, fade after 60 s, recycle
## oldest; D-113 blood splatter / pools). Owner: ENV C. Child of VfxDirector (and of VfxBlood, which keeps
## its own two pools so blood never evicts bullet holes); time advanced by `advance(delta)`.
## Forward+/Mobile: Decal nodes (project onto whatever is there, depth 0.08 m).
## Compatibility (OpenGL 3, no Decal support): an oriented quad 4 mm off the surface (same texture).
## Slots may grow (`place_basis(... grow_from, grow_s)`: blood pools) and stop growing (`stop_growing`).
class_name VfxDecals
extends Node3D

const DEPTH_M: float = 0.08
const QUAD_OFFSET_M: float = 0.004
## Blood reads wet: glossier quads than dry bullet holes.
const BLOOD_ROUGHNESS: float = 0.3

## Live decal count (tests).
var live: int = 0
var use_decal_nodes: bool = true
## Extra quad lift (m) for this pool (pools under splatter on the same floor).
var quad_offset_m: float = QUAD_OFFSET_M

var _cap: int = VfxSettings.DECAL_CAP
## Pool slots, created on demand up to `_cap`; each is a Decal or a MeshInstance3D.
var _slots: Array[Node3D] = []
var _age: PackedFloat32Array = PackedFloat32Array()
var _hold: PackedFloat32Array = PackedFloat32Array()
var _fade: PackedFloat32Array = PackedFloat32Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _peak: PackedFloat32Array = PackedFloat32Array()
## Growth: full size, start fraction, seconds to full (0 = not growing / stopped), elapsed, current fraction.
var _size: PackedVector2Array = PackedVector2Array()
var _grow_from: PackedFloat32Array = PackedFloat32Array()
var _grow_s: PackedFloat32Array = PackedFloat32Array()
var _grow_t: PackedFloat32Array = PackedFloat32Array()
var _grow_k: PackedFloat32Array = PackedFloat32Array()
var _base: Array[Transform3D] = []
## Bumped on every placement into a slot, so a holder can tell its decal was recycled.
var _serial: PackedInt64Array = PackedInt64Array()
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
		_fade.remove_at(i)
		_alpha.remove_at(i)
		_peak.remove_at(i)
		_size.remove_at(i)
		_grow_from.remove_at(i)
		_grow_s.remove_at(i)
		_grow_t.remove_at(i)
		_grow_k.remove_at(i)
		_serial.remove_at(i)
		_base.remove_at(i)


## Place a decal for `kind` (a surface id, &"scorch" or a VfxTextures.BLOOD_KINDS id) at `pos` facing `normal`,
## `size` m across, spun `spin` rad around the normal.
func place(kind: StringName, pos: Vector3, normal: Vector3, size: float, hold_s: float = VfxSettings.DECAL_HOLD_S,
		spin: float = 0.0) -> Node3D:
	var b: Basis = Basis.IDENTITY
	if normal != Vector3.ZERO:
		b = ImpactFx.basis_from_normal(normal).rotated(normal.normalized(), spin)
	return place_basis(kind, pos, b, Vector2(size, size), hold_s)


## Place with an explicit orthonormal basis (+Y = surface normal, +Z = the texture's V / "down" direction) and a
## rectangular size (x across, y along +Z). `alpha` < 1 = fainter. `grow_s` > 0 grows from `grow_from` x size
## to full size over that many seconds (blood pools). Returns the slot node (null for an unknown kind).
func place_basis(kind: StringName, pos: Vector3, b: Basis, size: Vector2, hold_s: float = VfxSettings.DECAL_HOLD_S,
		fade_s: float = VfxSettings.DECAL_FADE_S, alpha: float = 1.0, grow_from: float = 1.0,
		grow_s: float = 0.0) -> Node3D:
	var tex: Texture2D = _texture(kind)
	if tex == null:
		return null
	var i: int = _take_slot()
	var node: Node3D = _slots[i]
	if use_decal_nodes:
		(node as Decal).texture_albedo = tex
	else:
		(node as MeshInstance3D).material_override = _material(kind, tex)
	_base[i] = Transform3D(b.orthonormalized(), pos + b.y.normalized() * (0.0 if use_decal_nodes else quad_offset_m))
	_size[i] = size
	_grow_from[i] = clampf(grow_from, 0.01, 1.0)
	_grow_s[i] = maxf(grow_s, 0.0)
	_grow_t[i] = 0.0
	_grow_k[i] = _grow_from[i] if grow_s > 0.0 else 1.0
	_apply_size(i, size * _grow_k[i])
	node.visible = true
	if _age[i] < 0.0:
		live += 1
	_age[i] = 0.0
	_hold[i] = hold_s
	_fade[i] = maxf(fade_s, 0.01)
	_peak[i] = clampf(alpha, 0.0, 1.0)
	_serial[i] += 1
	_set_alpha(i, _peak[i])
	return node


## Freeze a growing decal at its current size (pool stops bleeding).
func stop_growing(node: Node3D) -> void:
	var i: int = _slots.find(node)
	if i >= 0:
		_grow_s[i] = 0.0


## Hide a decal now and free its slot (a body's pool restarting elsewhere).
func release(node: Node3D) -> void:
	var i: int = _slots.find(node)
	if i < 0 or _age[i] < 0.0:
		return
	_age[i] = -1.0
	_grow_s[i] = 0.0
	_slots[i].visible = false
	live -= 1


func is_growing(node: Node3D) -> bool:
	var i: int = _slots.find(node)
	return i >= 0 and _age[i] >= 0.0 and _grow_s[i] > 0.0


## Placement serial of a slot node (-1 if not ours); changes when the slot is recycled.
func serial_of(node: Node3D) -> int:
	var i: int = _slots.find(node)
	return _serial[i] if i >= 0 else -1


## Current size (m) of a live decal (x across, y along), ZERO if not live.
func size_of(node: Node3D) -> Vector2:
	var i: int = _slots.find(node)
	if i < 0 or _age[i] < 0.0:
		return Vector2.ZERO
	return _size[i] * _grow_k[i]


func advance(delta: float) -> void:
	for i: int in range(_slots.size()):
		if _age[i] < 0.0:
			continue
		_age[i] += delta
		if _grow_s[i] > 0.0:
			# Eases out (fast spread first, then creeping), like a real pool.
			_grow_t[i] = minf(_grow_t[i] + delta, _grow_s[i])
			var t: float = _grow_t[i] / _grow_s[i]
			_grow_k[i] = lerpf(_grow_from[i], 1.0, 1.0 - pow(1.0 - t, 2.2))
			_apply_size(i, _size[i] * _grow_k[i])
			if t >= 1.0:
				_grow_s[i] = 0.0
		var over: float = _age[i] - _hold[i]
		if over <= 0.0:
			continue
		var a: float = 1.0 - over / _fade[i]
		if a <= 0.0:
			_age[i] = -1.0
			_slots[i].visible = false
			live -= 1
			continue
		_set_alpha(i, a * _peak[i])


## Hide everything (map reset).
func clear() -> void:
	for i: int in range(_slots.size()):
		_age[i] = -1.0
		_grow_s[i] = 0.0
		_slots[i].visible = false
	live = 0


func _apply_size(i: int, s: Vector2) -> void:
	var node: Node3D = _slots[i]
	var xf: Transform3D = _base[i]
	if use_decal_nodes:
		(node as Decal).size = Vector3(s.x, DEPTH_M, s.y)
		_apply_xf(node, xf)
	else:
		_apply_xf(node, Transform3D(xf.basis.scaled_local(Vector3(s.x, 1.0, s.y)), xf.origin))


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
		_fade.append(VfxSettings.DECAL_FADE_S)
		_alpha.append(0.0)
		_peak.append(1.0)
		_grow_from.append(1.0)
		_grow_s.append(0.0)
		_grow_t.append(0.0)
		_grow_k.append(1.0)
		_size.append(Vector2.ONE)
		_serial.append(0)
		_base.append(Transform3D.IDENTITY)
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


func _texture(kind: StringName) -> Texture2D:
	if kind == &"scorch":
		return VfxTextures.scorch()
	if kind in VfxTextures.BLOOD_KINDS:
		return VfxTextures.blood(kind)
	return VfxTextures.hole(kind)


func _material(kind: StringName, tex: Texture2D) -> StandardMaterial3D:
	if not _materials.has(kind):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = BLOOD_ROUGHNESS if kind in VfxTextures.BLOOD_KINDS else 0.9
		m.render_priority = 1
		_materials[kind] = m
	return _materials[kind]
