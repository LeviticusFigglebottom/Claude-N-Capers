## D-165 seated corrective (ENV D: the `seated` blend shape on the `Outfit` mesh of the knee-length-and-longer dress
## looks lays the skirt on the thighs). Owner: ENV A. Presentation only. 1 while the body plays a seated clip (any sit,
## the seated desk / phone / cower / vehicle loops, the seated death slump), 0 otherwise (standing with the key on, the
## stride and squat clips poke through); it moves at 1 / BLEND_S across the sit-down / stand-up transitions. Driven
## off the driver's clip, which every peer chooses from the replicated hint, so clients match the host. Meshes without
## the key (find_blend_shape_by_name == -1) are skipped; a look with none costs one lookup per bind.
## Back-reference `_d` to the AnimDriver, like AnimLayers / TurnInPlace.
class_name SeatedBlend
extends RefCounted

const SHAPE: StringName = &"seated"
const PROPERTY: StringName = &"blend_shapes/seated"
const OUTFIT_NODE: String = "Outfit"
## Seconds for a full 0 <-> 1 swing.
const BLEND_S: float = 0.25
## Seated clips beyond AnimDriver.SEATED_CLIPS (which die in the chair): the chairs and the bed read, the slump.
const EXTRA_SEATED: Array[StringName] = [&"sit", &"sit_chair", &"sit_chair_read", &"sit_chair_armed", &"sit_bed_read",
	&"death_seated_slump"]

## The current blend value (0..1; tests).
var value: float = 0.0
var _d: AnimDriver = null
## Outfit meshes that carry the key (found on the first update after a bind).
var _meshes: Array[MeshInstance3D] = []
var _found: bool = false


func _init(driver: AnimDriver) -> void:
	_d = driver


## True when `c` (or the variant group it belongs to) is a seated clip.
static func is_seated_clip(c: StringName, variant_family: Dictionary = {}) -> bool:
	var base: StringName = StringName(variant_family.get(c, c))
	for k: StringName in [c, base]:
		if AnimDriver.SEATED_CLIPS.has(k) or EXTRA_SEATED.has(k):
			return true
	return false


## The `seated`-keyed Outfit meshes under `rig` (any depth: the D1-merged club looks keep the node name).
static func meshes_of(rig: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if rig == null:
		return out
	for n: Node in rig.find_children(OUTFIT_NODE, "MeshInstance3D", true, false):
		var m: MeshInstance3D = n as MeshInstance3D
		if m.mesh != null and m.find_blend_shape_by_name(SHAPE) >= 0:
			out.append(m)
	return out


## A (re)bind: the rig may be a new look; the value starts from whatever the new clip says on the next update.
func reset() -> void:
	_found = false
	_meshes.clear()
	value = 0.0


## One driver tick (`delta` = the ticked time, LOD cadence included).
func update(delta: float) -> void:
	if not _found:
		_found = true
		_meshes = meshes_of(_d.rig)
		if not _meshes.is_empty() and _d.clip != &"":
			value = 1.0 if is_seated_clip(_d.clip, _d._variant_family) else 0.0  # spawned seated: no slide-in
			_write()
	if _meshes.is_empty():
		return
	var target: float = 1.0 if is_seated_clip(_d.clip, _d._variant_family) else 0.0
	if value == target:
		return
	value = move_toward(value, target, delta / BLEND_S)
	_write()


func _write() -> void:
	for m: MeshInstance3D in _meshes:
		if is_instance_valid(m):
			m.set(PROPERTY, value)
