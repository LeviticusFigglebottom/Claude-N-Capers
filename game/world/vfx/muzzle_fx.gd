## Third-person muzzle flash pool (impact_fx.md §3). Owner: ENV C. Child of VfxDirector.
## Each set is a MuzzleFlash (star + flame + smoke puff, `muzzle_flash.gd`) placed at the shot origin
## with -Z along the shot. The OmniLight (VfxLights, 0.05 s, D-094) is requested by the director.
## Suppressed: a small smoke puff only. First-person shots (flag bit1) never reach here.
## Pool: VfxSettings.MUZZLE_CAP sets, round-robin (oldest reused).
class_name MuzzleFx
extends Node3D

const FLASH_S: float = MuzzleFlash.FLASH_S
const LIGHT_S: float = 0.05
const LIGHT_COLOR: Color = Color(1.0, 0.72, 0.38)
const LIGHT_ENERGY: float = 3.0
const LIGHT_RANGE_M: float = 5.0
## Flash size (m) per weapon class (default 0.28).
const FLASH_SIZE: Dictionary[StringName, float] = {
	&"pistol": 0.22, &"smg": 0.24, &"assault_rifle": 0.3, &"lmg": 0.34, &"shotgun": 0.42, &"sniper": 0.4,
}

## Flashes fired (tests).
var fired: int = 0

var _sets: Array[MuzzleFlash] = []
var _cursor: int = -1
var _cap: int = VfxSettings.MUZZLE_CAP


func _init() -> void:
	name = "Muzzles"


func set_count() -> int:
	return _sets.size()


func cap() -> int:
	return _cap


func set_cap(c: int) -> void:
	_cap = maxi(1, c)
	for s: MuzzleFlash in _sets:
		s.queue_free()
	_sets.clear()
	_cursor = -1


## Fire at `origin` along `dir`; suppressed = small puff only. Returns the flash used.
func fire(origin: Vector3, dir: Vector3, weapon_class: StringName, suppressed: bool) -> MuzzleFlash:
	var s: MuzzleFlash = _take()
	var fwd: Vector3 = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.FORWARD
	var up: Vector3 = Vector3.UP if absf(fwd.y) < 0.99 else Vector3.RIGHT
	var xf: Transform3D = Transform3D(Basis.looking_at(fwd, up), origin)
	if s.is_inside_tree():
		s.global_transform = xf
	else:
		s.transform = xf
	s.flash(float(FLASH_SIZE.get(weapon_class, 0.28)), suppressed)
	fired += 1
	return s


func advance(delta: float) -> void:
	for s: MuzzleFlash in _sets:
		s.tick(delta)


func clear() -> void:
	for s: MuzzleFlash in _sets:
		s.hide_flash()


func _take() -> MuzzleFlash:
	if _sets.size() < _cap:
		var s: MuzzleFlash = MuzzleFlash.new()
		s.name = "Muzzle%d" % _sets.size()
		s.auto_tick = false
		add_child(s)
		_sets.append(s)
		_cursor = _sets.size() - 1
		return s
	_cursor = (_cursor + 1) % _sets.size()
	return _sets[_cursor]
