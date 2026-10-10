## Lockable safe (S9.8). Owner: ENV A. Opened by any of `methods`:
## &"drill", &"saw", &"c4", &"lockpick" (needs interaction.can_lockpick_safes), &"code".
## Visual: `Body`, `Door` (pivot at hinge), `DrillPoint` marker (-Z into the lock), `LootAnchor`.
## Floor object: pivot bottom-centre, door on the front (-Z).
## Behaviour: with &"drill" in `methods` the Interactable places a drill (DeviceRunner, time by
## `size` from InteractionTweak.safe_drill_duration_s; jams/fix like drill_point). &"lockpick"
## needs `interaction.can_lockpick_safes`. A drill_point whose `target` is this safe also works.
## `open_by_device()` swings `Door` open and enables the loot inside: any SmallLoot / LootSpawn /
## GameplayPrefab child with an Interactable is disabled until then. saw/c4/code: P2.
class_name Safe
extends GameplayPrefab

enum Size { SMALL, MEDIUM, LARGE }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/safe/safe_placeholder.tscn")

@export var size: Size = Size.MEDIUM
@export var methods: Array[StringName] = [&"drill"]
@export_group("Interaction")
## -1 = InteractionTweak.drill_place_s (placing the drill on `DrillPoint`).
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var opened: bool = false
var runner: DeviceRunner = null

var _place_time: float = 0.0


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Body", "Door", "DrillPoint", "LootAnchor"])


func _default_interaction_time() -> float:
	return Tweak.interaction().drill_place_s


func _prefab_ready() -> void:
	_place_time = interactable.interaction_time_s
	if methods.has(&"drill"):
		runner = DeviceRunner.new(self, &"drill")
		runner.state_changed.connect(_on_device_state)
		runner.finished.connect(open_by_device)
		interactable.kind = &"place_drill"
	elif methods.has(&"lockpick"):
		interactable.kind = &"lockpick"
		interactable.interaction_time_s = Tweak.interaction().lockpick_door_s
		interactable.speed_modifier_key = &"interaction.lockpick_speed_mult"
	else:
		interactable.enabled = false  # opened by a drill_point / mission (saw, c4, code: P2)
	interactable.extra_check = _availability
	interactable.completed.connect(_on_completed)
	for p: GameplayPrefab in _inner_loot():
		p.interactable.enabled = false
	# A1-03 behaviour (P2): size-dependent collision, time lock, saw/c4/code methods.


## Server: a device finished (or the mission) opens the safe: door swings, loot becomes usable.
func open_by_device() -> void:
	if opened:
		return
	opened = true
	var door: Node3D = visual_node("Door") as Node3D
	if door != null:
		door.rotation.y = -deg_to_rad(Tweak.interaction().safe_door_open_deg)
	if interactable != null:
		interactable.enabled = false
	for p: GameplayPrefab in _inner_loot():
		p.interactable.enabled = true


## Drill time by `size` (s).
func drill_duration() -> float:
	var t: PackedFloat32Array = Tweak.interaction().safe_drill_duration_s
	if t.is_empty():
		return Tweak.interaction().drill_duration_s
	return t[clampi(int(size), 0, t.size() - 1)]


func _physics_process(delta: float) -> void:
	if runner != null:
		runner.tick(delta)


func _exit_tree() -> void:
	if runner != null:
		runner.shutdown()


func _availability(crew: Node) -> StringName:
	if opened:
		return InteractableComponent.BLOCK_DISABLED
	if runner != null:
		var st: int = runner.state
		return InteractableComponent.BLOCK_NONE if st == DeviceRunner.State.IDLE or st == DeviceRunner.State.JAMMED \
			else InteractableComponent.BLOCK_STATE
	var c: CrewController = crew as CrewController
	if interactable.kind == &"lockpick" and c != null and not Modifiers.flag(c.slot, &"interaction.can_lockpick_safes"):
		return InteractableComponent.BLOCK_STATE
	return InteractableComponent.BLOCK_NONE


func _on_completed(crew: Node) -> void:
	if not Net.is_authority() or opened:
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	if runner == null:
		open_by_device()
	elif runner.state == DeviceRunner.State.IDLE:
		runner.place(slot, drill_duration())
	elif runner.state == DeviceRunner.State.JAMMED:
		runner.fix(slot)


func _on_device_state(s: int) -> void:
	if s == DeviceRunner.State.JAMMED:
		interactable.kind = &"fix_drill"
		interactable.interaction_time_s = Tweak.interaction().drill_fix_s
	elif s == DeviceRunner.State.RUNNING:
		interactable.kind = &"place_drill"
		interactable.interaction_time_s = _place_time


## Loot prefabs inside this safe (descendants outside `Visual`).
func _inner_loot() -> Array[GameplayPrefab]:
	var out: Array[GameplayPrefab] = []
	var stack: Array[Node] = []
	for c: Node in get_children():
		if c != visual_root:
			stack.append(c)
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var p: GameplayPrefab = n as GameplayPrefab
		if p != null and p.interactable != null:
			out.append(p)
		for c: Node in n.get_children():
			stack.append(c)
	return out
