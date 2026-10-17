## D-138.3: the placed-device art of a prefab that runs its own DeviceRunner without a child DrillPoint (Safe,
## Padlock). Owner: ENV A. Same behaviour as DrillPoint's PO-12 visual: the device scene (by runner kind:
## DrillPoint.DEFAULT_DEVICE / DEFAULT_THERMAL / DEFAULT_SAW under G.PROPS_DIR, or the prefab's override) is shown
## while the runner is RUNNING or JAMMED (red jam mark while jammed, `Bit` spun and `Sparks` / `Glow` on while
## running) and removed when it is idle or done. Every peer drives it from the runner's state_changed (the codec
## re-emits it on clients). The node is added under `mount` (the visual's `DrillPoint` marker, -Z into the lock, or
## the prefab root).
class_name DeviceVisual
extends RefCounted

## The placed device (null while idle / done).
var node: Node3D = null

var _bit: Node3D = null
var _jam_mark: MeshInstance3D = null


## Catalog device scene for a runner kind (&"drill", &"thermal", &"saw"); `override` wins. A thermal drill falls
## back to the drill; a saw never shows a drill (null when its art is missing).
static func scene_for(kind: StringName, override: PackedScene = null) -> PackedScene:
	if override != null:
		return override
	var own: String = DrillPoint.DEFAULT_SAW if kind == &"saw" \
			else (DrillPoint.DEFAULT_THERMAL if kind == &"thermal" else "")
	if own != "" and ResourceLoader.exists(G.PROPS_DIR + own):
		return load(G.PROPS_DIR + own) as PackedScene
	if kind == &"saw":
		return null
	var path: String = G.PROPS_DIR + DrillPoint.DEFAULT_DEVICE
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


## Show / hide for runner state `s` (DeviceRunner.State) of a `kind` device under `mount`.
func update(s: int, kind: StringName, mount: Node, override: PackedScene = null) -> void:
	var placed: bool = s == DeviceRunner.State.RUNNING or s == DeviceRunner.State.JAMMED
	if placed and node == null and mount != null:
		var scene: PackedScene = scene_for(kind, override)
		if scene != null:
			node = scene.instantiate() as Node3D
			if node != null:
				node.name = "Device"
				mount.add_child(node)
				_bit = node.find_child("Bit", true, false) as Node3D
	if not placed:
		clear()
	if node != null:
		var jammed: bool = s == DeviceRunner.State.JAMMED
		if jammed and _jam_mark == null:
			_jam_mark = DrillPoint.make_jam_mark()
			node.add_child(_jam_mark)
		if _jam_mark != null:
			_jam_mark.visible = jammed
		DrillPoint.set_device_fx(node, s == DeviceRunner.State.RUNNING)


## Spin the bit while `running` (call from the owner's _process).
func tick(delta: float, running: bool) -> void:
	if _bit != null and running and is_instance_valid(_bit):
		_bit.rotate_object_local(Vector3.FORWARD, deg_to_rad(Tweak.interaction().device_bit_spin_dps) * delta)


## Remove the device now.
func clear() -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
	node = null
	_bit = null
	_jam_mark = null
