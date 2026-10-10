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
## A2-01 (D-032 QA-11) NPC doors: NpcMotor (guards, civilians, police) and CrewAiBrain look ahead
## on their path (`first_closed_on_path`) and call `npc_open(agent)` on a closed door they may open
## (unlocked; or locked except BARRED/VAULT for a guard whose SpawnPoint tags meet
## `npc_authorized_tags`, the keycard post). It opens after InteractionTweak.npc_door_open_stealth_s
## in stealth (instantly in loud) through `set_open`, so the S4.2 `open_door` stimulus applies to
## NPC-opened doors too. Any other closed door blocks: the NPC stops at it (NpcMotor.door_blocked;
## P3 police breach hooks there). Nav: the baked navmesh passes through doorways (heist_map.md §3);
## a `NavLink` NavigationLink3D through the doorway is enabled while the door is passable (open, or
## openable by NPCs) for maps whose bake closes the doorway.
## A2-08 push-bar doors (fire exits, `push_bar`): while CLOSED the door opens only from its inside,
## the front (-Z, UsePoint) side: a crew member / NPC whose position in the door's local space has
## z < 0. From outside (z >= 0) the interaction is blocked (BLOCK_PUSH_BAR_OUTSIDE) and NPC doors
## logic treats it as locked from that side (`can_npc_open` false; the NavLink is one-way -Z -> +Z
## while closed). Opening from inside still follows `lock`. Once open it is a normal door (either
## side may close it); closed again, it is one-way again. Pair it with swing INWARD (opens away from
## the pusher, toward +Z / outside).
class_name Door
extends GameplayPrefab

## A2-01: open state changed (`by_net_id` = the NPC / AI that opened it, 0 otherwise).
signal open_changed(open: bool, by_net_id: int)

enum Lock { NONE, LOCKPICK, KEYCARD, CODE, ELECTRONIC, BARRED, VAULT }
enum Swing { INWARD, OUTWARD, DOUBLE }

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/door/door_placeholder.tscn")
const PLACEHOLDER_DOUBLE: PackedScene = preload("res://systems/prefabs/door/door_double_placeholder.tscn")
## Contract default sizes (visual_slots.md).
const SINGLE_WIDTH_M: float = 0.9
const DOUBLE_WIDTH_M: float = 1.8
const HEIGHT_M: float = 2.1
const KEYCARD_ITEM: StringName = &"item.keycard"
## Runtime group of every door (A2-01 path checks).
const GROUP: StringName = &"door"
## Doorway margin beyond the opening's half width that still counts as crossing it (m).
const CROSS_MARGIN_M: float = 0.25
## A2-08: push-bar door used from its outside while closed.
const BLOCK_PUSH_BAR_OUTSIDE: StringName = &"ui.blocked.push_bar_outside"

@export var lock: Lock = Lock.NONE
@export var swing: Swing = Swing.INWARD
## Opening width. 0 = contract default (0.9 m single, 1.8 m DOUBLE).
@export var width_m: float = 0.0
@export var starts_open: bool = false
## Keypad/code_note group that opens a CODE door (S9.7).
@export var code_group: StringName = &""
## S4.2: guards ignore open doors unless this is set.
@export var suspicious_when_open: bool = false
## A2-01 (QA-11): a guard whose SpawnPoint tags contain one of these may open this door while it is
## locked (keycard post); never for BARRED / VAULT. Empty = no NPC opens it while locked.
@export var npc_authorized_tags: Array[StringName] = []
## A2-08: one-way fire exit; while closed it opens only from the inside (-Z, UsePoint side).
@export var push_bar: bool = false
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
var _nav_link: NavigationLink3D = null
## NPC open requested and not yet applied (stealth animation delay).
var _npc_open_pending: bool = false
var _opened_by_net_id: int = 0

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
	add_to_group(GROUP)
	_setup_nav_link()
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
	_update_nav_link()


## Server: open (keycard readers, devices, missions).
func open() -> void:
	set_open(true)


## Server: open or close (instant in A1-03; animation is M2).
func set_open(open: bool) -> void:
	if not Net.is_authority():
		return
	_apply_open(open)
	_update_open_stimulus()
	var by: int = _opened_by_net_id if open else 0
	_opened_by_net_id = 0
	open_changed.emit(open, by)
	# A3-07: clients get is_open / locked through HeistNetSync -> _apply_net_state().


## Client (A3-07, HeistNetSync): mirror the server's `is_open` / `locked` (leaves, collision, nav).
func _apply_net_state(state: Dictionary) -> void:
	if state.has("locked") and not bool(state["locked"]) and locked:
		locked = false
		_apply_unlocked_interaction()
	if state.has("ie") and interactable != null:
		interactable.enabled = bool(state["ie"])
	if state.has("is_open") and bool(state["is_open"]) != is_open:
		_apply_open(bool(state["is_open"]))
		open_changed.emit(is_open, 0)
	_update_nav_link()


func _apply_open(open: bool) -> void:
	is_open = open
	var angle: float = deg_to_rad(Tweak.interaction().door_open_angle_deg) if open else 0.0
	for i: int in range(_leaves.size()):
		# Leaf extends +X from its hinge, Leaf2 extends -X: opposite signs swing both the same way.
		var sign_inward: float = -1.0 if i == 0 else 1.0
		var outward: bool = swing == Swing.OUTWARD
		_leaves[i].rotation.y = angle * (-sign_inward if outward else sign_inward)
	_sync_leaf_bodies()
	_update_nav_link()


# --- NPC doors (A2-01, QA-11) -------------------------------------------------------------

## True when `agent` (NpcBase / AI CrewController) may walk through: open, or it can open it.
func passable_for(agent: Node) -> bool:
	return is_open or can_npc_open(agent)


## Whether `agent` may open this door now: unlocked, or locked (not BARRED / VAULT) for a guard
## whose SpawnPoint tags meet `npc_authorized_tags`. Crew AI only opens unlocked doors.
func can_npc_open(agent: Node) -> bool:
	if is_open:
		return true
	if push_bar and not is_inside(agent):
		return false
	return not locked or _guard_authorised(agent)


## Locked door (not BARRED / VAULT): `agent` is a guard whose SpawnPoint tags meet the post tags.
func _guard_authorised(agent: Node) -> bool:
	if lock == Lock.BARRED or lock == Lock.VAULT or npc_authorized_tags.is_empty():
		return false
	var npc: NpcBase = agent as NpcBase
	if npc == null or npc.role != &"guard":
		return false
	var tags: Variant = npc.spawn_info.get("tags", [])
	if tags is Array:
		for t: Variant in tags:
			if (t is StringName or t is String) and npc_authorized_tags.has(StringName(t)):
				return true
	return false


## A2-08: true when `who` (a Node3D) stands on the door's inside (local z < 0, the -Z / UsePoint
## side). A node without a position counts as outside.
func is_inside(who: Node) -> bool:
	var n3: Node3D = who as Node3D
	if n3 == null or not n3.is_inside_tree() or not is_inside_tree():
		return false
	return (global_transform.affine_inverse() * n3.global_position).z < 0.0


## Server: `agent` asks to pass. Opens after the stealth delay (instantly in loud) through
## set_open (same stimulus/signals as any open). Returns false when it may not open this door.
func npc_open(agent: Node) -> bool:
	if not Net.is_authority() or not can_npc_open(agent):
		return false
	if is_open or _npc_open_pending:
		return true
	var tw: InteractionTweak = Tweak.interaction()
	var st: StealthDirector = _stealth()
	var stealth: bool = st != null and st.is_stealth()
	var delay: float = tw.npc_door_open_stealth_s if stealth else tw.npc_door_open_loud_s
	var by: int = NetIds.of(agent)
	var was_locked: bool = locked
	if delay <= 0.0:
		_npc_apply_open(by, was_locked)
	else:
		_npc_open_pending = true
		get_tree().create_timer(delay, false, true).timeout.connect(_npc_apply_open.bind(by, was_locked))
	return true


func _npc_apply_open(by_net_id: int, was_locked: bool) -> void:
	_npc_open_pending = false
	if not is_inside_tree() or is_open:
		return
	_opened_by_net_id = by_net_id
	set_open(true)
	var close_s: float = Tweak.interaction().npc_locked_door_close_s
	if was_locked and locked and close_s > 0.0:
		get_tree().create_timer(close_s, false, true).timeout.connect(_npc_auto_close)


func _npc_auto_close() -> void:
	if is_inside_tree() and is_open and locked:
		set_open(false)


## Crossing of the segment a->b through this closed doorway: the crossing point, or Vector3.INF.
func doorway_crossing(a: Vector3, b: Vector3) -> Vector3:
	var inv: Transform3D = global_transform.affine_inverse()
	var la: Vector3 = inv * a
	var lb: Vector3 = inv * b
	if (la.z > 0.0) == (lb.z > 0.0) or is_equal_approx(la.z, lb.z):
		return Vector3.INF
	var t: float = la.z / (la.z - lb.z)
	var lp: Vector3 = la.lerp(lb, t)
	if absf(lp.x) > effective_width() * 0.5 + CROSS_MARGIN_M or lp.y > HEIGHT_M or lp.y < -1.0:
		return Vector3.INF
	return a.lerp(b, t)


## A2-01: the first closed door crossed by the polyline `points` within `max_dist_m` along it
## (doors of `tree`'s GROUP). Returns {} or {"door": Door, "point": Vector3, "distance": float}.
static func first_closed_on_path(tree: SceneTree, points: PackedVector3Array, max_dist_m: float) -> Dictionary:
	if tree == null or points.size() < 2:
		return {}
	var doors: Array[Door] = []
	for n: Node in tree.get_nodes_in_group(GROUP):
		var d: Door = n as Door
		if d != null and not d.is_open and d.is_inside_tree():
			doors.append(d)
	if doors.is_empty():
		return {}
	var travelled: float = 0.0
	for i: int in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var best: Door = null
		var best_p: Vector3 = Vector3.INF
		var best_d: float = INF
		for d: Door in doors:
			var p: Vector3 = d.doorway_crossing(a, b)
			if p != Vector3.INF and a.distance_to(p) < best_d:
				best = d
				best_p = p
				best_d = a.distance_to(p)
		if best != null:
			if travelled + best_d > max_dist_m:
				return {}
			return {"door": best, "point": best_p, "distance": travelled + best_d}
		travelled += a.distance_to(b)
		if travelled > max_dist_m:
			return {}
	return {}


func _setup_nav_link() -> void:
	_nav_link = NavigationLink3D.new()
	_nav_link.name = "NavLink"
	var half: float = Tweak.interaction().door_nav_link_half_m
	_nav_link.start_position = Vector3(0.0, 0.0, -half)
	_nav_link.end_position = Vector3(0.0, 0.0, half)
	_nav_link.bidirectional = true
	add_child(_nav_link)
	_update_nav_link()


## The link is enabled while NPCs can pass: open, unlocked, or keycard-authorised for some post.
func _update_nav_link() -> void:
	if _nav_link == null:
		return
	_nav_link.enabled = is_open or not locked or (not npc_authorized_tags.is_empty() \
		and lock != Lock.BARRED and lock != Lock.VAULT)
	# A2-08: closed push-bar doors pass inside (-Z, start) -> outside (+Z, end) only.
	_nav_link.bidirectional = is_open or not push_bar


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


func _availability(crew: Node) -> StringName:
	if push_bar and not is_open and not is_inside(crew):
		return BLOCK_PUSH_BAR_OUTSIDE
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
