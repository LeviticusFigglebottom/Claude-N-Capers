## Hinged door, optionally locked (gameplay_prefabs.md `door`). Owner: ENV A.
## Visual (visual_slots.md): `Frame` (visual supplies its collision as a `Collision` StaticBody3D),
## `Leaf` (pivot at the hinge, closed = rotation 0, A rotates it around Y), optional `Leaf2`
## (required for DOUBLE), `Handle` marker. Front (-Z) is the UsePoint side.
## INWARD opens away from the front (leaf swings toward +Z), OUTWARD toward -Z, DOUBLE = two leaves
## opening inward. Leaf collision: `LeafBody` AnimatableBody3D (world_dynamic) following `Leaf`.
## Locks: NONE opens instantly; LOCKPICK = S9.2 lockpick (`interaction.lockpick_speed_mult`);
## KEYCARD = S9.6 consumes `item.keycard`; CODE / ELECTRONIC / BARRED / VAULT are opened by other
## prefabs (keypad, keycard_reader, drill_point) through `unlock()`. Once unlocked, the door
## toggles open/closed with `door_open_s`. Guards ignore open doors unless `suspicious_when_open`
## (S4.2).
class_name Door
extends GameplayPrefab

enum Lock { NONE, LOCKPICK, KEYCARD, CODE, ELECTRONIC, BARRED, VAULT }
enum Swing { INWARD, OUTWARD, DOUBLE }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/door/door_placeholder.tscn")
const PLACEHOLDER_DOUBLE: PackedScene = preload("res://systems/prefabs/door/door_double_placeholder.tscn")
## Contract default sizes (visual_slots.md).
const SINGLE_WIDTH_M: float = 0.9
const DOUBLE_WIDTH_M: float = 1.8
const HEIGHT_M: float = 2.1
const KEYCARD_ITEM: StringName = &"item.keycard"

@export var lock: Lock = Lock.NONE
@export var swing: Swing = Swing.INWARD
## Opening width. 0 = contract default (0.9 m single, 1.8 m DOUBLE).
@export var width_m: float = 0.0
@export var starts_open: bool = false
## Keypad/code_note group that opens a CODE door (S9.7).
@export var code_group: StringName = &""
## S4.2: guards ignore open doors unless this is set.
@export var suspicious_when_open: bool = false
@export_group("Interaction")
## -1 = default by lock (InteractionTweak.door_open_s / lockpick_door_s / keycard_s).
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

var is_open: bool = false
var locked: bool = false

var _open_stim_id: int = 0
var _leaf_bodies: Array[AnimatableBody3D] = []
var _leaves: Array[Node3D] = []

@onready var _leaf_body: AnimatableBody3D = $LeafBody as AnimatableBody3D


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER_DOUBLE if swing == Swing.DOUBLE else PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(["Frame", "Leaf", "Handle"])
	if swing == Swing.DOUBLE:
		out.append("Leaf2")
	return out


func _default_interaction_time() -> float:
	var tw: InteractionTweak = Tweak.interaction()
	match lock:
		Lock.LOCKPICK:
			return tw.lockpick_door_s
		Lock.KEYCARD:
			return tw.keycard_s
		_:
			return tw.door_open_s


func effective_width() -> float:
	if width_m > 0.0:
		return width_m
	return DOUBLE_WIDTH_M if swing == Swing.DOUBLE else SINGLE_WIDTH_M


func _prefab_ready() -> void:
	locked = lock != Lock.NONE
	if using_placeholder and not is_equal_approx(effective_width(), _nominal_width()):
		Log.warn(LOG_CHANNEL, "%s: placeholder door is %.2f m wide, width_m is %.2f" % [name, _nominal_width(), effective_width()])
	_setup_interactable()
	_setup_leaf_bodies()
	# A1-03 behaviour (M2): NavigationLink3D / obstacle toggling (heist_map.md §3).
	if starts_open:
		locked = false
		_apply_unlocked_interaction()
		set_open(true)


## Server: remove the lock (keypad, keycard_reader, drill_point, lockpick completion).
func unlock() -> void:
	if not Net.is_authority() or not locked:
		return
	locked = false
	_apply_unlocked_interaction()


## Server: open (keycard readers, devices, missions).
func open() -> void:
	set_open(true)


## Server: open or close (instant in A1-03; animation is M2).
func set_open(open: bool) -> void:
	if not Net.is_authority():
		return
	is_open = open
	var angle: float = deg_to_rad(Tweak.interaction().door_open_angle_deg) if open else 0.0
	for i: int in range(_leaves.size()):
		# Leaf extends +X from its hinge, Leaf2 extends -X: opposite signs swing both the same way.
		var sign_inward: float = -1.0 if i == 0 else 1.0
		var outward: bool = swing == Swing.OUTWARD
		_leaves[i].rotation.y = angle * (-sign_inward if outward else sign_inward)
	_sync_leaf_bodies()
	_update_open_stimulus()
	# A1-03 behaviour (M2): replicate open state to clients; nav link / obstacle toggling.


## S4.2: an open `suspicious_when_open` door is an `open_door` stimulus.
func _update_open_stimulus() -> void:
	var st: StealthDirector = _stealth()
	if st == null:
		return
	var want: bool = is_open and suspicious_when_open
	if want and _open_stim_id == 0:
		_open_stim_id = st.register_stimulus(null, &"open_door", {"position": global_position + Vector3.UP})
	elif not want and _open_stim_id != 0:
		st.unregister_stimulus(_open_stim_id)
		_open_stim_id = 0


func _exit_tree() -> void:
	var st: StealthDirector = _stealth()
	if st != null and _open_stim_id != 0:
		st.unregister_stimulus(_open_stim_id)
	_open_stim_id = 0


func _nominal_width() -> float:
	return DOUBLE_WIDTH_M if swing == Swing.DOUBLE else SINGLE_WIDTH_M


func _setup_interactable() -> void:
	if interactable == null:
		Log.error(LOG_CHANNEL, "%s: missing `Interactable`" % name)
		return
	var handle: Node3D = visual_node("Handle") as Node3D
	if handle != null:
		interactable.global_position = handle.global_position
	match lock:
		Lock.NONE:
			interactable.kind = &"open_door"
		Lock.LOCKPICK:
			interactable.kind = &"lockpick"
			interactable.speed_modifier_key = &"interaction.lockpick_speed_mult"  # S9.2
		Lock.KEYCARD:
			interactable.kind = &"keycard"  # S9.6
			if interactable.requires_item == &"":
				interactable.requires_item = KEYCARD_ITEM
			interactable.consumes_item = true
		_:
			interactable.kind = &"open_door"
	interactable.extra_check = _availability
	interactable.completed.connect(_on_completed)


func _availability(_crew: Node) -> StringName:
	if not locked:
		return InteractableComponent.BLOCK_NONE
	match lock:
		Lock.LOCKPICK, Lock.KEYCARD:
			return InteractableComponent.BLOCK_NONE
		_:
			# CODE / ELECTRONIC / BARRED / VAULT open through other prefabs (unlock()).
			return InteractableComponent.BLOCK_STATE


func _apply_unlocked_interaction() -> void:
	if interactable == null:
		return
	interactable.kind = &"open_door"
	interactable.interaction_time_s = Tweak.interaction().door_open_s
	interactable.requires_item = &""
	interactable.consumes_item = false
	interactable.speed_modifier_key = &""


func _on_completed(_crew: Node) -> void:
	if not Net.is_authority():
		return
	if locked:
		unlock()
		set_open(true)
		return
	set_open(not is_open)


func _setup_leaf_bodies() -> void:
	if _leaf_body == null:
		Log.error(LOG_CHANNEL, "%s: missing `LeafBody`" % name)
		return
	var w: float = effective_width()
	var leaf_w: float = w * 0.5 if swing == Swing.DOUBLE else w
	var leaf_names: PackedStringArray = PackedStringArray(["Leaf"])
	if swing == Swing.DOUBLE:
		leaf_names.append("Leaf2")
	for i: int in range(leaf_names.size()):
		var leaf: Node3D = visual_node(leaf_names[i]) as Node3D
		if leaf == null:
			continue
		var body: AnimatableBody3D = _leaf_body
		if i > 0:
			body = _leaf_body.duplicate() as AnimatableBody3D
			body.name = "LeafBody%d" % (i + 1)
			add_child(body)
		var cs: CollisionShape3D = body.get_node(^"Collision") as CollisionShape3D
		var box: BoxShape3D = (cs.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size.x = leaf_w
		cs.shape = box
		cs.position.x = leaf_w * 0.5 * (1.0 if i == 0 else -1.0)
		body.collision_layer = LAYER_WORLD_DYNAMIC
		body.collision_mask = 0
		_leaves.append(leaf)
		_leaf_bodies.append(body)
	_sync_leaf_bodies()


func _sync_leaf_bodies() -> void:
	for i: int in range(mini(_leaves.size(), _leaf_bodies.size())):
		_leaf_bodies[i].global_transform = _leaves[i].global_transform
