## Contact sparks for a drill device's tip (PO: the thermal lance's glow and sparks sit on the door). Owner: ENV C.
## The prop wrapper (tools/blender/props/_scenes.py, cat `fx`) puts this `Sparks` node and a hidden `Glow`
## OmniLight3D at the tip; ENV A's DrillPoint toggles `emitting` and Glow.visible from the device state.
## Procedural (no texture): small unshaded emissive quads thrown back off the face (+Z, away from the lock).
extends Node3D

## On while the device runs (A: DrillPoint._on_device_state).
@export var emitting: bool = false:
	set(v):
		emitting = v
		if _p != null:
			_p.emitting = v

var _p: CPUParticles3D = null


func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.name = "Particles"
	_p.amount = 28
	_p.lifetime = 0.45
	_p.explosiveness = 0.0
	_p.local_coords = false
	_p.direction = Vector3(0.0, 0.35, 1.0)
	_p.spread = 55.0
	_p.initial_velocity_min = 1.8
	_p.initial_velocity_max = 4.0
	_p.gravity = Vector3(0.0, -9.8, 0.0)
	_p.scale_amount_min = 0.6
	_p.scale_amount_max = 1.2
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.72, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.15)
	m.emission_energy_multiplier = 4.0
	m.set_meta(&"untextured_ok", true)
	q.material = m
	_p.mesh = q
	_p.emitting = emitting
	add_child(_p)
