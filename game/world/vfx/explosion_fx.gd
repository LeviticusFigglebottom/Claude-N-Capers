## Explosions (impact_fx.md §2/§3 `explosion_fx(pos, radius, kind)`). Owner: ENV C. Child of VfxDirector.
## A set = flash star + fireball + smoke column + debris ring emitters; the director adds the light and
## the scorch decal. Kinds: frag / c4 / (default) full; incendiary = more fire, no debris ring;
## concussion / flashbang = white flash + thin smoke, no fireball, debris or scorch.
## Pool: VfxSettings.EXPLOSION_CAP sets, round-robin.
class_name ExplosionFx
extends Node3D

const FLASH_S: float = 0.12
const SOFT_KINDS: Array[StringName] = [&"concussion", &"flashbang"]
const NO_DEBRIS_KINDS: Array[StringName] = [&"concussion", &"flashbang", &"incendiary"]
const FIREBALL: Dictionary = {
	"kind": &"puff", "count": 14, "life": 0.6, "speed": Vector2(1.5, 4.0), "spread": 75.0, "gravity": -3.0,
	"size": Vector2(0.7, 1.3), "c0": Color(1.0, 0.55, 0.15, 0.95), "c1": Color(0.3, 0.08, 0.02, 0.0), "mesh": &"chip",
}
const SMOKE: Dictionary = {
	"kind": &"puff", "count": 12, "life": 2.6, "speed": Vector2(0.8, 2.4), "spread": 70.0, "gravity": -0.8,
	"size": Vector2(1.0, 1.8), "c0": Color(0.16, 0.15, 0.14, 0.75), "c1": Color(0.3, 0.3, 0.29, 0.0), "mesh": &"chip",
}
const DEBRIS: Dictionary = {
	"kind": &"solid", "count": 24, "life": 1.3, "speed": Vector2(5.0, 10.0), "spread": 75.0, "gravity": 9.8,
	"size": Vector2(0.02, 0.06), "c0": Color(0.35, 0.33, 0.3), "c1": Color(0.18, 0.17, 0.16), "mesh": &"chip",
}

## Explosions fired (tests).
var fired: int = 0

var _sets: Array[Node3D] = []
var _flash_left: PackedFloat32Array = PackedFloat32Array()
## Seconds until each set's emitters are done (then hidden).
var _set_left: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = -1
var _cap: int = VfxSettings.EXPLOSION_CAP


func _init() -> void:
	name = "Explosions"


func set_count() -> int:
	return _sets.size()


func cap() -> int:
	return _cap


func set_cap(c: int) -> void:
	_cap = maxi(1, c)
	for s: Node3D in _sets:
		s.queue_free()
	_sets.clear()
	_flash_left.clear()
	_set_left.clear()
	_cursor = -1


func fire(pos: Vector3, radius: float, kind: StringName) -> Node3D:
	var i: int = _take()
	var s: Node3D = _sets[i]
	var k: float = clampf(radius / 4.0, 0.4, 2.0)
	if s.is_inside_tree():
		s.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), pos)
	else:
		s.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), pos)
	var soft: bool = kind in SOFT_KINDS
	var star: MeshInstance3D = s.get_node("Star") as MeshInstance3D
	star.visible = true
	star.scale = Vector3.ONE * (4.0 if soft else 3.0)
	(star.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = \
		Color(1.0, 1.0, 1.0) if soft else Color(1.0, 0.75, 0.4)
	_flash_left[i] = FLASH_S
	_set_left[i] = float(SMOKE["life"]) + 0.2
	s.visible = true
	if not soft:
		ImpactFx.restart_emitter(s.get_node("Fireball") as GeometryInstance3D)
	ImpactFx.restart_emitter(s.get_node("Smoke") as GeometryInstance3D)
	if not kind in NO_DEBRIS_KINDS and not VfxSettings.reduce_motion:
		ImpactFx.restart_emitter(s.get_node("Debris") as GeometryInstance3D)
	fired += 1
	return s


func advance(delta: float) -> void:
	for i: int in range(_sets.size()):
		if _set_left[i] > 0.0:
			_set_left[i] -= delta
			if _set_left[i] <= 0.0:
				_sets[i].visible = false
		if _flash_left[i] <= 0.0:
			continue
		_flash_left[i] -= delta
		var star: MeshInstance3D = _sets[i].get_node("Star") as MeshInstance3D
		if _flash_left[i] <= 0.0:
			star.visible = false
		else:
			star.scale *= 1.0 + delta * 4.0


func clear() -> void:
	for i: int in range(_sets.size()):
		_flash_left[i] = 0.0
		(_sets[i].get_node("Star") as Node3D).visible = false


func _take() -> int:
	if _sets.size() < _cap:
		_sets.append(_build_set())
		_flash_left.append(0.0)
		_set_left.append(0.0)
		_cursor = _sets.size() - 1
		return _cursor
	_cursor = (_cursor + 1) % _sets.size()
	return _cursor


func _build_set() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Explosion%d" % _sets.size()
	var star: MeshInstance3D = MeshInstance3D.new()
	star.name = "Star"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	var mat: StandardMaterial3D = VfxTextures.additive_material(VfxTextures.flash(), false)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = false
	q.material = mat
	star.mesh = q
	star.position = Vector3(0, 0.4, 0)
	star.visible = false
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(star)
	for spec: Array in [["Fireball", FIREBALL], ["Smoke", SMOKE], ["Debris", DEBRIS]]:
		var layer: Dictionary = (spec[1] as Dictionary).duplicate()
		var e: GeometryInstance3D = ImpactFx.build_emitter(layer, VfxSettings.scaled_count(int(layer["count"])))
		e.name = spec[0]
		if e is GPUParticles3D:
			(e as GPUParticles3D).visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 16, 24))
		root.add_child(e)
	var fb: GeometryInstance3D = root.get_node("Fireball") as GeometryInstance3D
	_set_emission_radius(fb, 0.35)
	fb.position = Vector3(0, 0.45, 0)
	var debris: GeometryInstance3D = root.get_node("Debris") as GeometryInstance3D
	_set_emission_radius(debris, 0.2)
	add_child(root)
	return root


static func _set_emission_radius(e: GeometryInstance3D, r: float) -> void:
	if e is GPUParticles3D:
		var pm: ParticleProcessMaterial = (e as GPUParticles3D).process_material as ParticleProcessMaterial
		pm.emission_sphere_radius = r
	elif e is CPUParticles3D:
		(e as CPUParticles3D).emission_sphere_radius = r
