## Pooled per-surface impact bursts (impact_fx.md §3). Owner: ENV C. Child of VfxDirector.
## One "set" = one emitter per layer of ImpactFx.profile(surface), fired together. Sets are created
## lazily per surface, round-robin, at most VfxSettings.IMPACT_SETS_PER_SURFACE per surface and
## IMPACT_SETS_TOTAL over all surfaces (both quality-scaled). Re-firing a set restarts its burst.
class_name VfxImpacts
extends Node3D

## Bursts fired (tests/bench).
var fired: int = 0

## Sets per surface: Array of Node3D (each with one emitter child per layer).
var _sets: Dictionary[StringName, Array] = {}
var _cursor: Dictionary[StringName, int] = {}
var _per_surface_cap: int = VfxSettings.IMPACT_SETS_PER_SURFACE
var _total_cap: int = VfxSettings.IMPACT_SETS_TOTAL
var _total: int = 0
## Seconds until each set's burst is over (then the set is hidden: no draw calls while idle).
var _left: Dictionary[Node3D, float] = {}


func _init() -> void:
	name = "Impacts"


func set_count() -> int:
	return _total


func caps() -> Vector2i:
	return Vector2i(_per_surface_cap, _total_cap)


## Rebuild for a new quality (drops every set; they are recreated lazily with new particle counts).
func set_caps(per_surface: int, total: int) -> void:
	_per_surface_cap = maxi(1, per_surface)
	_total_cap = maxi(1, total)
	for s: StringName in _sets.keys():
		for n: Node in _sets[s]:
			n.queue_free()
	_sets.clear()
	_cursor.clear()
	_left.clear()
	_total = 0


## Build sets now (hidden), round-robin over every surface (and the gore-Off flesh dust) up to both caps, so fire()
## never builds or steals one mid-fight. Idempotent.
func prewarm() -> void:
	var surfaces: Array[StringName] = ImpactFx.SURFACES.duplicate()
	surfaces.append(ImpactFx.FLESH_DUST)
	var grew: bool = true
	while grew and _total < _total_cap:
		grew = false
		for s: StringName in surfaces:
			var list: Array = _sets.get(s, [])
			if _total >= _total_cap or list.size() >= _per_surface_cap:
				continue
			list.append(_build_set(s))
			_sets[s] = list
			_total += 1
			grew = true


## Hide sets whose burst has finished (idle emitters cost no draw calls).
func advance(delta: float) -> void:
	for s: Node3D in _left.keys():
		var t: float = _left[s] - delta
		if t <= 0.0:
			_left.erase(s)
			if is_instance_valid(s):
				s.visible = false
		else:
			_left[s] = t


## Fire the burst for `surface` at `pos`, emitting along `normal`. `scale` > 1 for headshots etc.
func fire(surface: StringName, pos: Vector3, normal: Vector3, scale_k: float = 1.0) -> Node3D:
	var s: Node3D = _take(surface)
	if s == null:
		return null
	var xf: Transform3D = Transform3D(ImpactFx.basis_from_normal(normal).scaled(Vector3.ONE * scale_k), pos)
	if s.is_inside_tree():
		s.global_transform = xf
	else:
		s.transform = xf
	s.visible = true
	for e: Node in s.get_children():
		ImpactFx.restart_emitter(e as GeometryInstance3D)
	_left[s] = float(s.get_meta(&"life", 1.0))
	fired += 1
	return s


func _take(surface: StringName) -> Node3D:
	var list: Array = _sets.get(surface, [])
	if list.size() < _per_surface_cap and _total < _total_cap:
		var s: Node3D = _build_set(surface)
		list.append(s)
		_sets[surface] = list
		_total += 1
		return s
	if list.is_empty():
		return _steal(surface)
	var c: int = (int(_cursor.get(surface, -1)) + 1) % list.size()
	_cursor[surface] = c
	return list[c]


## The total cap is reached and `surface` has no set yet: retire the largest surface's oldest set.
func _steal(surface: StringName) -> Node3D:
	var biggest: StringName = &""
	for k: StringName in _sets.keys():
		if biggest == &"" or (_sets[k] as Array).size() > (_sets[biggest] as Array).size():
			biggest = k
	if biggest == &"":
		return null
	var victim: Node3D = (_sets[biggest] as Array).pop_front()
	_left.erase(victim)
	victim.queue_free()
	_total -= 1
	if (_sets[biggest] as Array).is_empty():
		_sets.erase(biggest)
	var s: Node3D = _build_set(surface)
	_sets[surface] = [s]
	_total += 1
	return s


func _build_set(surface: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "%s_%d" % [surface, (_sets.get(surface, []) as Array).size()]
	var life: float = 0.0
	for layer: Dictionary in ImpactFx.profile(surface):
		life = maxf(life, float(layer["life"]))
		var e: GeometryInstance3D = ImpactFx.build_emitter(layer, VfxSettings.scaled_count(int(layer["count"])))
		root.add_child(e)
	root.set_meta(&"life", life + 0.1)
	root.visible = false
	add_child(root)
	return root
