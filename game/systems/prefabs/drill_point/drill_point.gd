## Where a drill / thermal drill / saw is placed (S9.3, S9.4). Owner: ENV A.
## Interaction = place the device (InteractionTweak.drill_place_s); the device runs `duration_s`
## (-1 = default per device) × `interaction.device_speed_mult`, jams (DeviceRunner, GameRng
## &"devices"), the same Interactable becomes "fix" (kind &"fix_drill", drill_fix_s) while jammed,
## and on finish it calls `open_by_device()` on `target` (Safe, vault...) or `unlock()` + open.
## QC-37 (G.SAW_TARGET): a SAW drill_point can also be cut with the handheld saw: `saw_cut(s)` adds
## up to effective_duration() x InteractionTweak.hand_saw_drill_point_mult, then opens `target`.
## The drill art is a separate device visual with a `Bit` node (visual_slots.md); the placeholder
## only marks the spot. -Z points into the lock.
## QC-60 (OF thermal drill): with `requires_loot` set, the device must first be delivered here as `requires_count`
## tool bags (e.g. loot.thermal_drill_part, HEAVY, is_tool), like burn_point's thermite: each "place" interaction
## with a carried bag (or one lying within InteractionTweak.drill_bag_radius_m) consumes it and counts it in
## `delivered` (replicated); the one that completes the count also places and starts the device. Without a bag the
## prompt shows BLOCK_ITEM (burn_point's hint). `delivered_changed(delivered, requires_count)` (local, server).
class_name DrillPoint
extends GameplayPrefab

## QC-60: a required tool bag was delivered (server; `delivered` of `required`).
signal delivered_changed(delivered: int, required: int)

enum Device { DRILL, THERMAL, SAW }

## PO-12: catalog drill device under G.PROPS_DIR.
const DEFAULT_DEVICE: String = "drill/prop_drill_device.tscn"
## ENV C equipment art (4993f31d): per-device defaults under G.PROPS_DIR (the drill when one is missing).
const DEFAULT_THERMAL: String = "drill/prop_thermal_drill_device.tscn"
const DEFAULT_SAW: String = "drill/prop_saw_device.tscn"
## Block reasons shown under the prompt (strings.csv, ENV B).
const BLOCK_RUNNING: StringName = &"ui.blocked.device_running"
const BLOCK_DONE: StringName = &"ui.blocked.device_done"
const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/drill_point/drill_point_placeholder.tscn")

@export var device: Device = Device.DRILL
## Run time in s. -1 = InteractionTweak drill_duration_s / thermal_duration_s / saw_duration_s.
@export var duration_s: float = -1.0
## What this opens (Door, Safe, ...).
@export var target: NodePath
## PO-12: the device shown at this spot while it runs (needs a `Bit` node, spun while RUNNING). null = the
## catalog device per kind (DEFAULT_DEVICE / DEFAULT_THERMAL / DEFAULT_SAW under G.PROPS_DIR; thermal falls back to the drill).
@export var device_scene: PackedScene
## QC-60: tool loot the device is delivered as (&"" = none: the crew's own drill). Consumed at this spot.
@export var requires_loot: StringName = &""
## QC-60: how many `requires_loot` bags must be delivered before the device runs.
@export var requires_count: int = 1
## A2-03 (S8.5, stealth.ecm_opens_doors): an ATM spot. An ECM aimed at it is consumed and opens `target` after
## DeployableTweak.ecm_atm_open_s, like the device would (EcmSystem.attach_to_reader).
@export var ecm_atm: bool = false
@export_group("Interaction")
## -1 = InteractionTweak.drill_place_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var runner: DeviceRunner = null
## QC-37: handheld saw progress (0..1, replicated).
var saw_progress: float = 0.0
## A5-01: scales the run time (and so the hand-saw time) of a device not yet placed: an armored_truck's lockdown
## sets its SAW points to InteractionTweak.truck_lockdown_saw_mult (server).
var duration_mult: float = 1.0
## QC-60: `requires_loot` bags delivered so far (replicated).
var delivered: int = 0

## PO-12: the placed device visual (null while idle / done), its spinning `Bit` and the jam indicator.
var device_node: Node3D = null

var _place_time: float = 0.0
var _place_prompt: StringName = &""
var _bit: Node3D = null
var _jam_mark: MeshInstance3D = null


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().drill_place_s


## Effective device run time (s).
func effective_duration() -> float:
	return _base_duration() * duration_mult


func _base_duration() -> float:
	if duration_s >= 0.0:
		return duration_s
	var tw: InteractionTweak = Tweak.interaction()
	match device:
		Device.THERMAL:
			return tw.thermal_duration_s
		Device.SAW:
			return tw.saw_duration_s
		_:
			return tw.drill_duration_s


## Device kind id used in device_started.
func device_kind() -> StringName:
	match device:
		Device.THERMAL:
			return &"thermal"
		Device.SAW:
			return &"saw"
	return &"drill"


## Running device state (DeviceRunner.State).
func device_state() -> int:
	return runner.state


## Server (QC-37): the handheld saw cut this saw spot for `seconds`.
func saw_cut(seconds: float, _attacker_net_id: int) -> void:
	if not Net.is_authority() or device != Device.SAW or saw_progress >= 1.0 \
			or (runner != null and runner.state == DeviceRunner.State.DONE):
		return
	var need: float = effective_duration() * Tweak.interaction().hand_saw_drill_point_mult
	saw_progress = minf(saw_progress + seconds / maxf(need, 0.01), 1.0)
	if saw_progress >= 1.0 - 0.0001:
		saw_progress = 1.0
		interactable.enabled = false
		_on_device_finished()


## A2-03: whether an ECM can open this spot now (an ATM spot whose device has not run or been cut).
func ecm_openable() -> bool:
	return ecm_atm and saw_progress < 1.0 and (runner == null or runner.state == DeviceRunner.State.IDLE)


## A2-03: the ECM's open time here (EcmSystem).
func ecm_open_s() -> float:
	return DeployableTweak.data().ecm_atm_open_s


## A2-03 (S8.5): the ECM's time is up: open `target` as a finished device would (server).
func open_by_ecm() -> void:
	if not Net.is_authority() or not ecm_openable():
		return
	saw_progress = 1.0
	interactable.enabled = false
	_on_device_finished()


func _prefab_ready() -> void:
	if device == Device.SAW:
		add_to_group(G.SAW_TARGET)
	runner = DeviceRunner.new(self, device_kind())
	runner.state_changed.connect(_on_device_state)
	runner.finished.connect(_on_device_finished)
	_place_time = interactable.interaction_time_s
	_place_prompt = interactable.prompt_key
	interactable.kind = &"place_drill"
	interactable.extra_check = _availability
	interactable.completed.connect(_on_completed)
	_lock_target.call_deferred()


## PP audit: a target that can be locked behind this device (SmallLoot) stays shut until it finishes.
func _lock_target() -> void:
	var t: Node = get_node_or_null(target) if not target.is_empty() else null
	if t != null and t.has_method(&"lock_for_device") and Net.is_authority():
		t.call(&"lock_for_device")


func _physics_process(delta: float) -> void:
	if runner != null:
		runner.tick(delta)


func _exit_tree() -> void:
	if runner != null:
		runner.shutdown()


## QC-60: true while `requires_loot` bags are still owed (the next place interaction needs one).
func needs_delivery() -> bool:
	return requires_loot != &"" and delivered < requires_count


## QC-60: the `requires_loot` bag `crew` would deliver (carried, else a loose one within drill_bag_radius_m), or null.
func part_for(crew: Node) -> LootBag:
	return LootManager.tool_bag_for(crew, requires_loot, global_position, Tweak.interaction().drill_bag_radius_m)


## Server (QC-60): count one delivered part without a bag (mission fallback / tests). Places nothing.
func add_delivered(n: int = 1) -> void:
	if not Net.is_authority() or n <= 0:
		return
	delivered = mini(delivered + n, maxi(requires_count, 0))
	delivered_changed.emit(delivered, requires_count)


## P PO-pass #2: never the reasonless "Can't do that right now" (ui.blocked.state) while the device runs / is done.
func _availability(crew: Node) -> StringName:
	if runner != null and runner.state == DeviceRunner.State.IDLE and needs_delivery() and part_for(crew) == null:
		return InteractableComponent.BLOCK_ITEM
	if runner == null or runner.state == DeviceRunner.State.IDLE or runner.state == DeviceRunner.State.JAMMED:
		return InteractableComponent.BLOCK_NONE
	return BLOCK_RUNNING if runner.state == DeviceRunner.State.RUNNING else BLOCK_DONE


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or runner == null:
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	match runner.state:
		DeviceRunner.State.IDLE:
			if needs_delivery():
				var bag: LootBag = part_for(crew)
				if bag == null:
					return
				LootManager.consume_bag(bag)
				add_delivered(1)
				if needs_delivery():
					return
			runner.place(slot, effective_duration())
		DeviceRunner.State.JAMMED:
			runner.fix(slot)


func _on_device_state(s: int) -> void:
	_update_device_visual(s)
	# Lead (r215 GH capture): while the device RUNS the spot offers nothing (PD2: no prompt, the timer panel only);
	# jammed it offers only "fix"; idle "place".
	match s:
		DeviceRunner.State.JAMMED:
			interactable.kind = &"fix_drill"
			interactable.interaction_time_s = Tweak.interaction().drill_fix_s
			interactable.prompt_key = &"ui.prompt.fix_drill"
			interactable.enabled = true
		DeviceRunner.State.DONE, DeviceRunner.State.RUNNING:
			interactable.kind = &"place_drill"  # not "fix the drill" when it next jams-and-fixes
			interactable.prompt_key = _place_prompt
			interactable.enabled = false
		_:
			interactable.kind = &"place_drill"
			interactable.interaction_time_s = _place_time
			interactable.prompt_key = _place_prompt


func _on_device_finished() -> void:
	open_target(get_node_or_null(target) if not target.is_empty() else null, true)


## Open what a finished device was drilling (Safe/vault `open_by_device()`, else door unlock + open).
## PO-6: `forced` (drill / saw) swings a Door open with the fast breach swing.
static func open_target(t: Node, forced: bool = false) -> void:
	if t == null:
		return
	if t.has_method(&"open_by_device"):
		t.call(&"open_by_device")
		return
	var door: Door = t as Door
	if forced and door != null:
		door.unlock()
		door.set_open(true, false, true)
		return
	if t.has_method(&"unlock"):
		t.call(&"unlock")
	if t.has_method(&"set_open"):
		t.call(&"set_open", true)
	elif t.has_method(&"open"):
		t.call(&"open")


# --- PO-12 device visual ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _bit != null and runner != null and runner.state == DeviceRunner.State.RUNNING:
		_bit.rotate_object_local(Vector3.FORWARD, deg_to_rad(Tweak.interaction().device_bit_spin_dps) * delta)


## Shows the device while placed (RUNNING / JAMMED, a red jam mark while jammed), removes it when done.
func _update_device_visual(s: int) -> void:
	var placed: bool = s == DeviceRunner.State.RUNNING or s == DeviceRunner.State.JAMMED
	if placed and device_node == null:
		var scene: PackedScene = _device_scene()
		if scene != null:
			device_node = scene.instantiate() as Node3D
			if device_node != null:
				device_node.name = "Device"
				add_child(device_node)
				_bit = device_node.find_child("Bit", true, false) as Node3D
	if not placed and device_node != null:
		device_node.queue_free()
		device_node = null
		_bit = null
		_jam_mark = null
	if device_node != null:
		_set_jam_mark(s == DeviceRunner.State.JAMMED)
		set_device_fx(device_node, s == DeviceRunner.State.RUNNING)


## ENV C device FX (thermal drill): `Sparks` (particles) emits and `Glow` (light) shows while the device RUNS, off
## while JAMMED. Both direct children of the device root at the tip; missing nodes are fine.
static func set_device_fx(device: Node, on: bool) -> void:
	var sparks: Node = device.get_node_or_null(^"Sparks")
	if sparks != null and &"emitting" in sparks:
		sparks.set(&"emitting", on)
	var glow: Node3D = device.get_node_or_null(^"Glow") as Node3D
	if glow != null:
		glow.visible = on


func _device_scene() -> PackedScene:
	return DeviceVisual.scene_for(device_kind(), device_scene)  # never a drill on a saw point


## A small emissive red mark above the device while jammed (procedural: no art asset).
func _set_jam_mark(on: bool) -> void:
	if on and _jam_mark == null:
		_jam_mark = make_jam_mark()
		device_node.add_child(_jam_mark)
	if _jam_mark != null:
		_jam_mark.visible = on


## The jam mark mesh (also used by Padlock's placed saw).
static func make_jam_mark() -> MeshInstance3D:
	var mark: MeshInstance3D = MeshInstance3D.new()
	mark.name = "JamMark"
	var m: SphereMesh = SphereMesh.new()
	m.radius = 0.04
	m.height = 0.08
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.05)
	mat.emission_energy_multiplier = 3.0
	m.material = mat
	mark.mesh = m
	mark.position = Vector3(0.0, 0.42, 0.3)
	return mark
