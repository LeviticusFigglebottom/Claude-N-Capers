## Batch-3 weapon part motion (B4-18, D-055; visual_slots.md "weapons, batch 3"). Owner: ENV A.
## Child `PartsAnimator` of a WeaponVisual, driven by the holder's CrewWeapons state. Presentation only.
## Finds the parts by name in the weapon model (WeaponVisual.get_marker) and moves them from their rest pose:
## `Breech` opens about local X while reloading; `Lever` throws about local X after each shot;
## `StringUpper` / `StringLower` (D-070) pull back with the bow draw (Upper negative, Lower positive about local
## X); on a crossbow they latch during the reload (Upper -crossbow_latch_deg, Lower +, both x crossbow_latch_stretch
## along local Y) and stay latched while a bolt is loaded; a legacy `String` slides along +Z with the draw;
## `Arrow` hides after a shot until re-nocked; `Blade` spins about local X (fast while firing); `Rotor` spins
## about local Z with the minigun spin; the revolver `Speedloader` shows only while reloading. Numbers:
## FpViewmodelTweak.
class_name WeaponPartsAnimator
extends Node

const NODE_NAME: String = "PartsAnimator"
const PARTS: Array[StringName] = [
	&"Breech", &"Lever", &"StringUpper", &"StringLower", &"String", &"Arrow", &"Blade", &"Rotor", &"Speedloader",
]

var weapons: CrewWeapons = null
## The weapon is a crossbow (its anim_set): the string halves latch on reload instead of drawing.
var crossbow: bool = false
var _parts: Dictionary = {}  # StringName -> [Node3D, Transform3D rest]
var _breech: float = 0.0
var _blade_angle: float = 0.0
var _rotor_angle: float = 0.0
var _latch: float = 0.0


## Attach to `visual` (a WeaponVisual) when its model carries any batch-3 part. Returns null otherwise.
static func attach(visual: Node3D, crew_weapons: CrewWeapons) -> WeaponPartsAnimator:
	if visual == null or crew_weapons == null or not visual.has_method(&"get_marker"):
		return null
	var old: Node = visual.get_node_or_null(NODE_NAME)
	if old != null:
		visual.remove_child(old)
		old.queue_free()
	var a: WeaponPartsAnimator = WeaponPartsAnimator.new()
	a.name = NODE_NAME
	a.weapons = crew_weapons
	var def: WeaponDef = ContentDB.weapon(crew_weapons.weapon_id(crew_weapons.equipped_slot))
	a.crossbow = def != null and def.anim_set == &"crossbow"
	for part: StringName in PARTS:
		var n: Node3D = visual.call(&"get_marker", part) as Node3D
		if n != null:
			a._parts[part] = [n, n.transform]
	if a._parts.is_empty():
		a.free()
		return null
	visual.add_child(a)
	return a


func has_part(part: StringName) -> bool:
	return _parts.has(part)


func _process(delta: float) -> void:
	if weapons == null or not is_instance_valid(weapons):
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var target: float = 1.0 if weapons.reloading else 0.0
	_breech = move_toward(_breech, target, delta / maxf(tw.breech_ramp_s, 0.01))
	_rot(&"Breech", Vector3.RIGHT, -deg_to_rad(tw.breech_open_deg) * _breech)
	var lt: float = clampf(weapons.last_shot_age / maxf(tw.lever_cycle_s, 0.01), 0.0, 1.0)
	_rot(&"Lever", Vector3.RIGHT, deg_to_rad(tw.lever_throw_deg) * sin(lt * PI))
	var draw: float = weapons.charge if weapons.charge > 0.0 else (_breech if weapons.reloading else 0.0)
	if crossbow:
		var loaded: bool = weapons.mag(weapons.equipped_slot) > 0
		if weapons.reloading:
			_latch = move_toward(_latch, 1.0, delta / maxf(tw.crossbow_latch_s, 0.01))
		else:
			_latch = 1.0 if loaded else 0.0  # held latched while a bolt is loaded; released by the shot
		var st: float = lerpf(1.0, tw.crossbow_latch_stretch, _latch)
		_rot(&"StringUpper", Vector3.RIGHT, -deg_to_rad(tw.crossbow_latch_deg) * _latch, Vector3(1.0, st, 1.0))
		_rot(&"StringLower", Vector3.RIGHT, deg_to_rad(tw.crossbow_latch_deg) * _latch, Vector3(1.0, st, 1.0))
	else:
		_rot(&"StringUpper", Vector3.RIGHT, -deg_to_rad(tw.bow_limb_deg) * weapons.charge)
		_rot(&"StringLower", Vector3.RIGHT, deg_to_rad(tw.bow_limb_deg) * weapons.charge)
	if _parts.has(&"Speedloader"):
		(_parts[&"Speedloader"][0] as Node3D).visible = weapons.reloading  # D-070: hidden at rest
	_move(&"String", Vector3(0.0, 0.0, tw.string_draw_m * draw))
	if _parts.has(&"Arrow"):
		(_parts[&"Arrow"][0] as Node3D).visible = weapons.mag(weapons.equipped_slot) > 0 \
			and weapons.last_shot_age >= tw.arrow_hidden_s
	var firing: bool = weapons.last_shot_age < 0.25
	_blade_angle = fmod(_blade_angle + TAU * (tw.blade_rps_firing if firing else tw.blade_rps_idle) * delta, TAU)
	_rot(&"Blade", Vector3.RIGHT, _blade_angle)
	_rotor_angle = fmod(_rotor_angle + TAU * tw.rotor_rps_max * weapons.spin * delta, TAU)
	_rot(&"Rotor", Vector3.BACK, _rotor_angle)


func _rot(part: StringName, axis: Vector3, angle: float, scale: Vector3 = Vector3.ONE) -> void:
	if not _parts.has(part):
		return
	var n: Node3D = _parts[part][0] as Node3D
	var rest: Transform3D = _parts[part][1] as Transform3D
	if is_instance_valid(n):
		n.transform = Transform3D(rest.basis * Basis(axis, angle) * Basis.from_scale(scale), rest.origin)


func _move(part: StringName, offset: Vector3) -> void:
	if not _parts.has(part):
		return
	var n: Node3D = _parts[part][0] as Node3D
	var rest: Transform3D = _parts[part][1] as Transform3D
	if is_instance_valid(n):
		n.transform = Transform3D(rest.basis, rest.origin + rest.basis * offset)
