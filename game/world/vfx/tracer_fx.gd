## Tracer streaks (impact_fx.md §3). Owner: ENV C. Child of VfxDirector.
## A tracer is a glowing streak whose head travels from the muzzle to `end` at SPEED_MPS (visual only)
## with a STREAK_M tail. Every Nth bullet per weapon class (`every_nth`), never when suppressed.
## All live tracers are instances of ONE MultiMesh (one draw call); cap VfxSettings.TRACER_CAP.
## Standalone: `res://world/vfx/tracer.tscn` (root TracerFx, top_level, world space): `spawn(from, to)`.
class_name TracerFx
extends MultiMeshInstance3D

const SPEED_MPS: float = 400.0
const STREAK_M: float = 3.0
const WIDTH_M: float = 0.018
const COLOR: Color = Color(1.0, 0.82, 0.5, 0.95)
## A tracer stays at least this long so a short shot still renders for ~2 frames.
const MIN_LIFE_S: float = 0.035
## 1 in N bullets per weapon class (shotguns count pellets within a pellet group; ids per
## Enums.weapon_class_qualifier). Missing class = DEFAULT_NTH; 0 = never.
const EVERY_NTH: Dictionary[StringName, int] = {
	&"assault_rifle": 2, &"smg": 2, &"lmg": 2, &"pistol": 3, &"shotgun": 3, &"sniper": 1, &"special": 1,
	&"melee": 0, &"throwable": 0,
}
const DEFAULT_NTH: int = 2

## Advance in _process (standalone `tracer.tscn` use, e.g. ENV P); VfxDirector sets false and drives advance().
@export var auto_advance: bool = true

## Live tracer count (tests).
var live: int = 0
## Tracers started (tests).
var spawned: int = 0

var _cap: int = VfxSettings.TRACER_CAP
var _start: PackedVector3Array = PackedVector3Array()
var _end: PackedVector3Array = PackedVector3Array()
var _t: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	name = "Tracers"
	top_level = true  # instance transforms are world space
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(WIDTH_M, WIDTH_M, 1.0)
	box.material = VfxTextures.glow_material()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	multimesh = mm
	_resize()
	custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


static func every_nth(weapon_class: StringName) -> int:
	return int(EVERY_NTH.get(weapon_class, DEFAULT_NTH))


func cap() -> int:
	return _cap


func set_cap(c: int) -> void:
	_cap = maxi(1, c)
	while live > _cap:
		_remove(0)
	_resize()


## Start a streak; when full, the oldest one is dropped.
func spawn(from: Vector3, to: Vector3) -> void:
	if from.distance_squared_to(to) < 0.25:
		return
	if live >= _cap:
		_remove(0)
	_start.append(from)
	_end.append(to)
	_t.append(0.0)
	live += 1
	spawned += 1
	_write(live - 1)
	multimesh.visible_instance_count = live


func advance(delta: float) -> void:
	var i: int = 0
	while i < live:
		_t[i] += delta
		var dist: float = _start[i].distance_to(_end[i])
		if _t[i] * SPEED_MPS - STREAK_M >= dist and _t[i] >= MIN_LIFE_S:
			_remove(i)
			continue
		i += 1
	for k: int in range(live):
		_write(k)
	multimesh.visible_instance_count = live


func clear() -> void:
	_start.clear()
	_end.clear()
	_t.clear()
	live = 0
	multimesh.visible_instance_count = 0


func _remove(i: int) -> void:
	_start.remove_at(i)
	_end.remove_at(i)
	_t.remove_at(i)
	live -= 1


func _write(i: int) -> void:
	var a: Vector3 = _start[i]
	var dir: Vector3 = _end[i] - a
	var dist: float = dir.length()
	dir /= dist
	var head: float = minf(_t[i] * SPEED_MPS, dist)
	var tail: float = clampf(_t[i] * SPEED_MPS - STREAK_M, 0.0, maxf(dist - STREAK_M * 0.5, 0.0))
	var length: float = maxf(head - tail, 0.01)
	var mid: Vector3 = a + dir * (tail + head) * 0.5
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var b: Basis = Basis.looking_at(dir, up).scaled_local(Vector3(1.0, 1.0, length))
	multimesh.set_instance_transform(i, Transform3D(b, mid))
	multimesh.set_instance_color(i, COLOR)


func _resize() -> void:
	multimesh.instance_count = _cap
	multimesh.visible_instance_count = live
	for k: int in range(live):
		_write(k)
