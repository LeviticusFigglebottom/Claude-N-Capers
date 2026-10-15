## Third-person muzzle flash pool (impact_fx.md §3). Owner: ENV C. Child of VfxDirector.
## Each set is a MuzzleFlash (`muzzle_flash.gd`: class-shaped core + cone + petals, sparks, wisp, smoke) placed at
## the shot origin with -Z along the shot. The OmniLight (VfxLights: a fast hot pulse that cools from LIGHT_COLOR
## to LIGHT_END_COLOR, D-094/D-113) is requested by the director.
## Suppressed: a small smoke puff only. First-person shots (flag bit1) never reach here.
## Pool: VfxSettings.MUZZLE_CAP sets, round-robin (oldest reused).
class_name MuzzleFx
extends Node3D

const FLASH_S: float = MuzzleFlash.FLASH_S
## PO6-13 / D-114 §8: toned down from D-113 (0.06 s, energy 4.5, range 5 m).
const LIGHT_S: float = 0.035
const LIGHT_COLOR: Color = Color(1.0, 0.8, 0.52)
const LIGHT_END_COLOR: Color = Color(1.0, 0.42, 0.12)
const LIGHT_ENERGY: float = 2.2
const LIGHT_RANGE_M: float = 3.5
## Energy ~ (time left / LIGHT_S)^LIGHT_FALLOFF: bright for a frame, then gone.
const LIGHT_FALLOFF: float = 2.0
## Flash size (m) per weapon class (default 0.28); the class shape (MuzzleFlash.SHAPES) sets the proportions.
const FLASH_SIZE: Dictionary[StringName, float] = {
	&"pistol": 0.24, &"smg": 0.25, &"assault_rifle": 0.3, &"lmg": 0.32, &"shotgun": 0.34, &"sniper": 0.34,
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
	s.flash(float(FLASH_SIZE.get(weapon_class, 0.28)), suppressed, weapon_class)
	fired += 1
	return s


func advance(delta: float) -> void:
	for s: MuzzleFlash in _sets:
		s.tick(delta)


func clear() -> void:
	for s: MuzzleFlash in _sets:
		s.reset_all()


## Trailing wisps on every set that is flashing now (tools; third person starts per-shot wisps itself).
func burst_end() -> void:
	for s: MuzzleFlash in _sets:
		if s.is_flashing():
			s.burst_end()


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
