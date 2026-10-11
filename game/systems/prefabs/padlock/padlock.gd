## Padlock on a grate, gate or door (QC-37; Night Deposit vent, Shadow Ledger roof). Owner: ENV A.
## Opened by lockpicking (kind &"lockpick", InteractionTweak.lockpick_door_s x interaction.lockpick_speed_mult,
## S9.2) or by cutting it with the handheld saw (G.SAW_TARGET, `saw_cut`, hand_saw_padlock_s). Opening
## unlocks/opens every `targets` node (DrillPoint.open_target: Safe.open_by_device, Door unlock + open).
class_name Padlock
extends GameplayPrefab

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/padlock/padlock_placeholder.tscn")

@export var targets: Array[NodePath] = []
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


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func _default_interaction_time() -> float:
	return Tweak.interaction().lockpick_door_s


func _prefab_ready() -> void:
	add_to_group(G.SAW_TARGET)
	interactable.kind = &"lockpick"
	interactable.prompt_key = &"ui.prompt.pick_lock"
	interactable.speed_modifier_key = &"interaction.lockpick_speed_mult"
	interactable.completed.connect(func(_crew: Node) -> void: open_lock())


## Server (QC-37): the handheld saw cut the padlock for `seconds`.
func saw_cut(seconds: float, _attacker_net_id: int) -> void:
	if not Net.is_authority() or opened:
		return
	saw_progress = minf(saw_progress + seconds / maxf(Tweak.interaction().hand_saw_padlock_s, 0.01), 1.0)
	if saw_progress >= 1.0 - 0.0001:
		open_lock()


## Server: the padlock is off (lockpicked, sawn, or forced by the mission): open every target.
func open_lock() -> void:
	if not Net.is_authority() or opened:
		return
	opened = true
	interactable.enabled = false
	var shackle: Node3D = visual_node("Shackle") as Node3D
	if shackle != null:
		shackle.visible = false
	for path: NodePath in targets:
		var t: Node = get_node_or_null(path)
		if t == null:
			Log.warn(&"prefab", "%s: padlock target %s not found" % [name, path])
		else:
			DrillPoint.open_target(t)
