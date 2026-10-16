## Padlock on a grate, gate or door (QC-37; Night Deposit vent, Shadow Ledger roof). Owner: ENV A.
## Opened by lockpicking (kind &"lockpick", InteractionTweak.lockpick_door_s x interaction.lockpick_speed_mult,
## S9.2) or by cutting it with the handheld saw (G.SAW_TARGET, `saw_cut`, hand_saw_padlock_s). Opening
## unlocks/opens every `targets` node (DrillPoint.open_target: Safe.open_by_device, Door unlock + open).
## D-115 (DB-8, S9.4): with `place_saw` the padlock also takes a PLACED SAW once the heist is loud (Dockside Burn's
## roller doors 30 s, container padlocks 45 s): the Interactable becomes kind &"place_saw" (drill_place_s), a
## DeviceRunner of kind &"saw" runs `saw_duration_s` (-1 = InteractionTweak.padlock_saw_duration_s) x
## interaction.device_speed_mult with the PD2 jams (fix: kind &"fix_drill", drill_fix_s; auto-restart), emits
## device_started / jammed / restarted / finished [R] (so LocalHudModel.devices shows its row) and opens the lock
## (sawn: the fast breach swing) when done. The saw device art is G.PROPS_DIR + DrillPoint.DEFAULT_SAW when present.
## While not loud the padlock is still lockpicked; the handheld saw works at any time (it stops a placed saw).
class_name Padlock
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/padlock/padlock_placeholder.tscn")
const KIND_LOCKPICK: StringName = &"lockpick"
const KIND_PLACE_SAW: StringName = &"place_saw"
const KIND_FIX: StringName = &"fix_drill"

@export var targets: Array[NodePath] = []
@export_group("Placed saw")
## D-115 (DB-8): a placed saw cuts this padlock once the heist is loud.
@export var place_saw: bool = false
## Placed-saw run time (s); -1 = InteractionTweak.padlock_saw_duration_s.
@export var saw_duration_s: float = -1.0
## The saw shown while placed (null = G.PROPS_DIR + DrillPoint.DEFAULT_SAW when it exists; none otherwise).
@export var device_scene: PackedScene
@export_group("Interaction")
## -1 = InteractionTweak.lockpick_door_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var opened: bool = false
var saw_progress: float = 0.0
## DB-8: the placed saw (null without `place_saw`). LocalHudModel / NetEntityCodec read it as `runner`.
var runner: DeviceRunner = null
## The placed saw visual while RUNNING / JAMMED.
var device_node: Node3D = null

var _session: StringName = &""
var _jam_mark: MeshInstance3D = null


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().lockpick_door_s


func _prefab_ready() -> void:
	add_to_group(G.SAW_TARGET)
	_apply_ui(KIND_LOCKPICK)
	interactable.completed.connect(_on_completed)
	if not place_saw:
		return
	runner = DeviceRunner.new(self, &"saw")
	runner.state_changed.connect(_on_device_state)
	runner.finished.connect(func() -> void: open_lock(true))
	interactable.extra_check = _availability
	interactable.duration_override = _duration_for
	interactable.started.connect(func(crew: Node) -> void:
		_session = _pick(crew)
		_apply_ui(_session))
	interactable.cancelled.connect(func(_c: Node) -> void: _session = &"")


## Placed-saw run time (s) before modifiers.
func effective_saw_duration() -> float:
	return saw_duration_s if saw_duration_s > 0.0 else Tweak.interaction().padlock_saw_duration_s


func _physics_process(delta: float) -> void:
	if runner != null:
		runner.tick(delta)


func _exit_tree() -> void:
	if runner != null:
		runner.shutdown()


## Server (QC-37): the handheld saw cut the padlock for `seconds`.
func saw_cut(seconds: float, _attacker_net_id: int) -> void:
	if not Net.is_authority() or opened:
		return
	saw_progress = minf(saw_progress + seconds / maxf(Tweak.interaction().hand_saw_padlock_s, 0.01), 1.0)
	if saw_progress >= 1.0 - 0.0001:
		open_lock(true)


## Server: the padlock is off (lockpicked, sawn, or forced by the mission): open every target.
## PO-6: `forced` (sawn) swings target doors with the fast breach swing.
func open_lock(forced: bool = false) -> void:
	if not Net.is_authority() or opened:
		return
	opened = true
	if runner != null:
		runner.abort()  # opened another way while a placed saw runs: stop it (no-op when it finished)
	interactable.enabled = false
	var shackle: Node3D = visual_node("Shackle") as Node3D
	if shackle != null:
		shackle.visible = false
	for path: NodePath in targets:
		var t: Node = get_node_or_null(path)
		if t == null:
			Log.warn(&"prefab", "%s: padlock target %s not found" % [name, path])
		else:
			DrillPoint.open_target(t, forced)


# --- Method selection (DB-8) ------------------------------------------------------------------

## What `crew` would do now: lockpick, place_saw (loud), fix (jammed) or &"" (the saw runs / is done).
func _pick(_crew: Node) -> StringName:
	if runner == null:
		return KIND_LOCKPICK
	match runner.state:
		DeviceRunner.State.JAMMED:
			return KIND_FIX
		DeviceRunner.State.RUNNING, DeviceRunner.State.DONE:
			return &""
	return KIND_PLACE_SAW if _loud() else KIND_LOCKPICK


func _availability(crew: Node) -> StringName:
	var m: StringName = _pick(crew)
	if m == &"":
		return DrillPoint.BLOCK_RUNNING if runner.state == DeviceRunner.State.RUNNING else DrillPoint.BLOCK_DONE
	if _session == &"":
		_apply_ui(m)
	return InteractableComponent.BLOCK_NONE


func _duration_for(crew: Node, base: float) -> float:
	var m: StringName = _session if _session != &"" else _pick(crew)
	match m:
		KIND_PLACE_SAW:
			return Tweak.interaction().drill_place_s
		KIND_FIX:
			return Tweak.interaction().drill_fix_s
	return base


func _apply_ui(m: StringName) -> void:
	match m:
		KIND_PLACE_SAW:
			interactable.kind = KIND_PLACE_SAW
			interactable.prompt_key = &"ui.prompt.place_saw"
			interactable.speed_modifier_key = &""
		KIND_FIX:
			interactable.kind = KIND_FIX
			interactable.prompt_key = &"ui.prompt.fix_drill"
			interactable.speed_modifier_key = &""
		_:
			interactable.kind = KIND_LOCKPICK
			interactable.prompt_key = &"ui.prompt.pick_lock"
			interactable.speed_modifier_key = &"interaction.lockpick_speed_mult"


func _on_completed(crew: Node) -> void:
	var m: StringName = _session if _session != &"" else KIND_LOCKPICK
	_session = &""
	if not Net.is_authority() or opened:
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	match m:
		KIND_PLACE_SAW:
			runner.place(slot, effective_saw_duration())
		KIND_FIX:
			runner.fix(slot)
		_:
			open_lock()


func _loud() -> bool:
	var rt: HeistRuntime = HeistRuntime.of(self)
	return rt != null and (rt.phase == Enums.HeistPhase.LOUD or rt.went_loud)


# --- Placed saw visual ------------------------------------------------------------------------

## While the saw RUNS the padlock offers nothing (the HUD device row); jammed it offers "fix".
func _on_device_state(s: int) -> void:
	_update_device_visual(s)
	if opened:
		return
	match s:
		DeviceRunner.State.JAMMED:
			_apply_ui(KIND_FIX)
			interactable.enabled = true
		DeviceRunner.State.RUNNING, DeviceRunner.State.DONE:
			interactable.enabled = false
		_:
			_apply_ui(KIND_PLACE_SAW if _loud() else KIND_LOCKPICK)


func _update_device_visual(s: int) -> void:
	var placed: bool = s == DeviceRunner.State.RUNNING or s == DeviceRunner.State.JAMMED
	if placed and device_node == null:
		var scene: PackedScene = _device_scene()
		if scene != null:
			device_node = scene.instantiate() as Node3D
			if device_node != null:
				device_node.name = "Device"
				add_child(device_node)
	if not placed and device_node != null:
		device_node.queue_free()
		device_node = null
		_jam_mark = null
	if device_node != null:
		if s == DeviceRunner.State.JAMMED and _jam_mark == null:
			_jam_mark = DrillPoint.make_jam_mark()
			device_node.add_child(_jam_mark)
		if _jam_mark != null:
			_jam_mark.visible = s == DeviceRunner.State.JAMMED


func _device_scene() -> PackedScene:
	if device_scene != null:
		return device_scene
	var path: String = G.PROPS_DIR + DrillPoint.DEFAULT_SAW
	return load(path) as PackedScene if ResourceLoader.exists(path) else null
