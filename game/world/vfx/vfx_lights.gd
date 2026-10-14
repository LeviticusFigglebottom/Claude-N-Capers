## Short flash lights shared by MuzzleFx and explosions (impact_fx.md §3, D-094/D-095). Owner: ENV C.
## At most VfxSettings.LIGHT_CAP OmniLights live at once; a flash past the cap gets no light.
## Lights sit on render layers 1 and 21 (`viewmodel_lit`, 1 << 20, D-095) so they also light the
## first-person viewmodel. No shadows.
class_name VfxLights
extends Node3D

const VIEWMODEL_LIT_LAYER: int = 1 << 20
const LAYERS: int = 1 | VIEWMODEL_LIT_LAYER

## Lights started (tests).
var started: int = 0
## Flashes refused because every light was busy (tests).
var skipped: int = 0

var _lights: Array[OmniLight3D] = []
var _left: PackedFloat32Array = PackedFloat32Array()
var _dur: PackedFloat32Array = PackedFloat32Array()
var _energy: PackedFloat32Array = PackedFloat32Array()
var _cap: int = VfxSettings.LIGHT_CAP


func _init() -> void:
	name = "Lights"


func set_cap(c: int) -> void:
	_cap = maxi(0, c)
	while _lights.size() > _cap:
		_lights.pop_back().queue_free()
		_left.remove_at(_left.size() - 1)
		_dur.remove_at(_dur.size() - 1)
		_energy.remove_at(_energy.size() - 1)


func live() -> int:
	var n: int = 0
	for t: float in _left:
		if t > 0.0:
			n += 1
	return n


func light_count() -> int:
	return _lights.size()


## Flash a light at `pos` for `duration` s (linear fade). Returns false when over the cap.
func flash(pos: Vector3, color: Color, energy: float, light_range: float, duration: float) -> bool:
	var i: int = -1
	for k: int in range(_lights.size()):
		if _left[k] <= 0.0:
			i = k
			break
	if i < 0:
		if _lights.size() >= _cap:
			skipped += 1
			return false
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "Flash%d" % _lights.size()
		l.shadow_enabled = false
		l.layers = LAYERS
		l.omni_attenuation = 1.6
		l.visible = false
		add_child(l)
		_lights.append(l)
		_left.append(0.0)
		_dur.append(0.0)
		_energy.append(0.0)
		i = _lights.size() - 1
	var light: OmniLight3D = _lights[i]
	if light.is_inside_tree():
		light.global_position = pos
	else:
		light.position = pos
	light.light_color = color
	light.omni_range = light_range
	var e: float = energy * (0.5 if VfxSettings.reduce_motion else 1.0)
	light.light_energy = e
	light.visible = true
	_left[i] = duration
	_dur[i] = duration
	_energy[i] = e
	started += 1
	return true


func advance(delta: float) -> void:
	for i: int in range(_lights.size()):
		if _left[i] <= 0.0:
			continue
		_left[i] -= delta
		if _left[i] <= 0.0:
			_lights[i].visible = false
		else:
			_lights[i].light_energy = _energy[i] * (_left[i] / _dur[i])


func clear() -> void:
	for i: int in range(_lights.size()):
		_left[i] = 0.0
		_lights[i].visible = false
