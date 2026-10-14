## Where a drill / thermal drill / saw is placed (S9.3, S9.4). Owner: ENV A.
## Interaction = place the device (InteractionTweak.drill_place_s); the device runs `duration_s`
## (-1 = default per device) × `interaction.device_speed_mult`, jams (DeviceRunner, GameRng
## &"devices"), the same Interactable becomes "fix" (kind &"fix_drill", drill_fix_s) while jammed,
## and on finish it calls `open_by_device()` on `target` (Safe, vault...) or `unlock()` + open.
## QC-37 (G.SAW_TARGET): a SAW drill_point can also be cut with the handheld saw: `saw_cut(s)` adds
## up to effective_duration() x InteractionTweak.hand_saw_drill_point_mult, then opens `target`.
## The drill art is a separate device visual with a `Bit` node (visual_slots.md); the placeholder
## only marks the spot. -Z points into the lock.
class_name DrillPoint
extends GameplayPrefab

enum Device { DRILL, THERMAL, SAW }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/drill_point/drill_point_placeholder.tscn")

@export var device: Device = Device.DRILL
## Run time in s. -1 = InteractionTweak drill_duration_s / thermal_duration_s / saw_duration_s.
@export var duration_s: float = -1.0
## What this opens (Door, Safe, ...).
@export var target: NodePath
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

var _place_time: float = 0.0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().drill_place_s


## Effective device run time (s).
func effective_duration() -> float:
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


func _prefab_ready() -> void:
	if device == Device.SAW:
		add_to_group(G.SAW_TARGET)
	runner = DeviceRunner.new(self, device_kind())
	runner.state_changed.connect(_on_device_state)
	runner.finished.connect(_on_device_finished)
	_place_time = interactable.interaction_time_s
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


func _availability(_crew: Node) -> StringName:
	if runner == null or runner.state == DeviceRunner.State.IDLE or runner.state == DeviceRunner.State.JAMMED:
		return InteractableComponent.BLOCK_NONE
	return InteractableComponent.BLOCK_STATE


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or runner == null:
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	match runner.state:
		DeviceRunner.State.IDLE:
			runner.place(slot, effective_duration())
		DeviceRunner.State.JAMMED:
			runner.fix(slot)


func _on_device_state(s: int) -> void:
	match s:
		DeviceRunner.State.JAMMED:
			interactable.kind = &"fix_drill"
			interactable.interaction_time_s = Tweak.interaction().drill_fix_s
			interactable.prompt_key = &"ui.prompt.fix_drill"
		DeviceRunner.State.DONE:
			interactable.enabled = false
		_:
			interactable.kind = &"place_drill"
			interactable.interaction_time_s = _place_time


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
