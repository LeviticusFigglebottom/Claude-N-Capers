## Short flash lights shared by MuzzleFx and explosions (impact_fx.md §3, D-094/D-095). Owner: ENV C.
## At most VfxSettings.LIGHT_CAP OmniLights live at once; a flash past the cap gets no light.
## Lights sit on render layers 1 and 21 (`viewmodel_lit`, 1 << 20, D-095) so they also light the
## first-person viewmodel. No shadows. A flash may cool from `color` to `color_end` while its energy falls as
## (time left / duration)^falloff (muzzle: a fast hot pulse, D-113; explosions: linear).
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
var _drawn_at: PackedInt64Array = PackedInt64Array()
var _falloff: PackedFloat32Array = PackedFloat32Array()
var _c0: PackedColorArray = PackedColorArray()
var _c1: PackedColorArray = PackedColorArray()
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
		_drawn_at.remove_at(_drawn_at.size() - 1)
		_falloff.remove_at(_falloff.size() - 1)
		_c0.remove_at(_c0.size() - 1)
		_c1.remove_at(_c1.size() - 1)


func live() -> int:
	var n: int = 0
	for t: float in _left:
		if t > 0.0:
			n += 1
	return n


func light_count() -> int:
	return _lights.size()


## Flash a light at `pos` for `duration` s. Returns false when over the cap. `color_end` (alpha 0 = none) is the
## colour at the end of the fade; `falloff` 1 = linear, 2+ = a sharp pulse.
func flash(pos: Vector3, color: Color, energy: float, light_range: float, duration: float,
		color_end: Color = Color(0, 0, 0, 0), falloff: float = 1.0) -> bool:
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
		_drawn_at.append(-1)
		_falloff.append(1.0)
		_c0.append(Color.WHITE)
		_c1.append(Color.WHITE)
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
	_drawn_at[i] = Engine.get_frames_drawn()
	_falloff[i] = maxf(falloff, 0.1)
	_c0[i] = color
	_c1[i] = color_end if color_end.a > 0.0 else color
	started += 1
	return true


func advance(delta: float) -> void:
	for i: int in range(_lights.size()):
		if _left[i] <= 0.0:
			continue
		_left[i] -= delta
		if _left[i] <= 0.0:
			if not VfxSettings.frame_drawn_since(_drawn_at[i]):
				_left[i] = 0.0001  # keep it up until one frame shows it (hitch-proof, ENV P)
				continue
			_lights[i].visible = false
		else:
			var t: float = _left[i] / _dur[i]
			_lights[i].light_energy = _energy[i] * pow(t, _falloff[i])
			_lights[i].light_color = _c1[i].lerp(_c0[i], t)


func clear() -> void:
	for i: int in range(_lights.size()):
		_left[i] = 0.0
		_lights[i].visible = false
