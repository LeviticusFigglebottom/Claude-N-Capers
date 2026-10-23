## Hinged door, optionally locked (gameplay_prefabs.md `door`). Owner: ENV A.
## Visual (visual_slots.md): `Frame` (visual supplies its collision as a `Collision` StaticBody3D),
## `Leaf` (pivot at the hinge, closed = rotation 0, A rotates it around Y), optional `Leaf2`
## (required for DOUBLE), `Handle` marker. Front (-Z) is the UsePoint side.
## INWARD opens away from the front (leaf swings toward +Z), OUTWARD toward -Z, DOUBLE = two leaves
## opening inward. Leaf collision: `LeafBody` AnimatableBody3D (world_dynamic) following `Leaf`, only while
## closed (an open leaf blocks nobody, P3 gate).
## PO-6 (D-105, impact_fx.md §5): the leaves swing (ease-out) over InteractionTweak.door_swing_open_s /
## door_swing_close_s, or door_swing_breach_s for a forced open (police kick, C4, drill / saw: `set_open(true,
## false, true)`). The swing runs in _physics_process and the leaf bodies follow the leaves every tick. A
## crew member / NPC (CharacterBody3D, players / npcs layers) inside the next step of the sweep holds the
## leaf where it is (`swing_blocked`); it resumes once the body is clear. `is_open` is the logical, replicated
## state and changes at once: logic never reads the leaf angle. A state set in the physics frame the door
## became ready (starts_open, mission variants at heist start, a client's bring-up snapshot) or with
## `instant` snaps. Clients swing locally when the replicated `is_open` changes (`sw` = forced open).
## Locks: NONE opens instantly; LOCKPICK = S9.2 lockpick (`interaction.lockpick_speed_mult`);
## KEYCARD = S9.6 consumes `item.keycard`; CODE / ELECTRONIC / BARRED / VAULT are opened by other
## prefabs (keypad, keycard_reader, drill_point) through `unlock()`. Once unlocked, the door
## toggles open/closed with `door_open_s`. Guards ignore open doors unless `suspicious_when_open`
## (S4.2).
## A2-01 (D-032 QA-11) NPC doors: NpcMotor (guards, civilians, police) and CrewAiBrain look ahead
## on their path (`first_closed_on_path`) and call `npc_open(agent)` on a closed door they may open
## (unlocked; or locked except BARRED for a guard / staff civilian whose SpawnPoint tags meet
## `npc_authorized_tags`, the keycard post). It opens after InteractionTweak.npc_door_open_stealth_s
## in stealth (instantly in loud) through `set_open`, so the S4.2 `open_door` stimulus applies to
## NPC-opened doors too. Any other closed door blocks: the NPC stops at it (NpcMotor.door_blocked;
## P3 police breach hooks there). Nav: the baked navmesh passes through doorways (heist_map.md §3);
## a `NavLink` NavigationLink3D through the doorway is enabled while the door is passable (open, or
## openable by NPCs) for maps whose bake closes the doorway.
## P3 gate: police breach. Once loud, police (roles police / special) may also open locked doors that are
## not BARRED / VAULT (`can_npc_open`): `npc_open` holds them InteractionTweak.npc_door_breach_s, then
## the door is unlocked (for good) and open, cue.door_breach [R]. The NavLink stays enabled for such doors.
## A2-08 push-bar doors (fire exits, `push_bar`): while CLOSED the door opens only from its inside,
## the front (-Z, UsePoint) side: a crew member / NPC whose position in the door's local space has
## z < 0. From outside (z >= 0) the interaction is blocked (BLOCK_PUSH_BAR_OUTSIDE) and NPC doors
## logic treats it as locked from that side (`can_npc_open` false; the NavLink is one-way -Z -> +Z
## while closed), except for an NPC its `npc_authorized_tags` authorise (staff with the key; two-way link).
## Opening from inside still follows `lock`. Once open it is a normal door (either side may close it);
## closed again, it is one-way again. Pair it with swing INWARD (opens away from
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
## Navigation layer (project "npc_only", value 2) of a loud-breachable locked door's link: police / specials path
## through it (they breach it), crew / bots / pilots (layer 1 only) treat the shut door as blocked (D-122, C's GN
## bronze-doors stall). An open, unlocked or NPC-authorised door's link is on layer 1 (everyone).
const NAV_LAYER_BREACH: int = 2
const SINGLE_WIDTH_M: float = 0.9
const DOUBLE_WIDTH_M: float = 1.8
const HEIGHT_M: float = 2.1
const KEYCARD_ITEM: StringName = &"item.keycard"
## NPC roles a door's `npc_authorized_tags` can authorise (staff civilians carry tags like civ_curator).
const STAFF_ROLES: Array[StringName] = [&"guard", &"civilian"]
## Runtime group of every door (A2-01 path checks).
const GROUP: StringName = &"door"
## PO-6: bodies that stop a swinging leaf (crew, NPCs).
const SWING_BLOCK_MASK: int = GameplayPrefab.LAYER_PLAYERS | NpcBase.LAYER_NPCS
## Doorway margin beyond the opening's half width that still counts as crossing it (m).
const CROSS_MARGIN_M: float = 0.25
## A2-08: push-bar door used from its outside while closed.
const BLOCK_PUSH_BAR_OUTSIDE: StringName = &"ui.blocked.push_bar_outside"
## D-105 (impact_fx.md §1) leaf bullet surfaces. `leaf_surface` empty = by style: a BARRED (security gate)
## or VAULT lock, or a `visual_scene` whose file name names a metal style (LEAF_METAL_KEYWORDS) -> metal, a
## glass style -> glass, else wood (ENV C's surface_map.json reads painted / veneer door leaves as wood).
const SURFACE_WOOD: StringName = &"wood"
const SURFACE_METAL: StringName = &"metal"
const SURFACE_GLASS: StringName = &"glass"
const LEAF_METAL_KEYWORDS: PackedStringArray = ["steel", "bronze", "grille", "vault", "metal", "iron", "brass"]
const LEAF_GLASS_KEYWORDS: PackedStringArray = ["glass"]

@export var lock: Lock = Lock.NONE
@export var swing: Swing = Swing.INWARD
## Opening width. 0 = contract default (0.9 m single, 1.8 m DOUBLE).
@export var width_m: float = 0.0
## Leaf height (the leaf collision and the crossing check). 0 = contract default HEIGHT_M (2.1 m). D-158 (C's hoarding
## check): RT's 2.4 m SiteTanneryGate leaves left a see- / shoot-through slot above a 2.1 m collision.
@export var height_m: float = 0.0
@export var starts_open: bool = false
## Keypad/code_note group that opens a CODE door (S9.7).
@export var code_group: StringName = &""
## S4.2: guards ignore open doors unless this is set.
@export var suspicious_when_open: bool = false
## A2-01 (QA-11): a guard or staff civilian whose SpawnPoint tags contain one of these may open this door while
## it is locked (keycard post); never for BARRED (VAULT only through these, opt-in). Empty = no NPC opens it locked.
@export var npc_authorized_tags: Array[StringName] = []
## A2-08: one-way fire exit; while closed it opens only from the inside (-Z, UsePoint side).
@export var push_bar: bool = false
## GN (ENV C's shutters / grates): a lift-up shutter, not a swinging door. The crew never operates it (no
## interaction; missions and devices relock / unlock / set_open it), the leaves do not rotate (the visual rolls
## itself from `is_open`, e.g. world/props/shutter_leaf.gd) and closing never sweeps or blocks on bodies.
@export var shutter: bool = false
## S9.5 / A5-03: > 0 = a locked CODE / ELECTRONIC / BARRED door can be blown (loud) with this many charges
## (item.c4, or trip mines with interaction.shaped_charge). 0 = no charge placement.
@export var charges_required: int = 0
## D-105: bullet surface id of the leaves (impact_fx.md §1). Empty = by style (see LEAF_METAL_KEYWORDS).
@export var leaf_surface: StringName = &""
## D-142: a glass leaf (leaf_surface_id() glass: `leaf_surface` or a glass-style visual) is see-through for stealth
## vision (its leaf bodies join StealthDirector.GROUP_SEE_THROUGH; movement and bullets unchanged; an open leaf has no
## collision anyway). False = an opaque glass leaf (frosted / privacy). Non-glass leaves are never see-through.
@export var see_through: bool = true
@export_group("Interaction")
## -1 = default by lock (InteractionTweak.door_open_s / lockpick_door_s / keycard_s).
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = false
@export var loud_only: bool = false
@export var casing_allowed: bool = false
## S1.3 (D-075 guest doors): a civilian player (no gear yet) may open this door. False = a staff door: a civilian is
## refused (ui.blocked.civilian), locked or not.
@export var civilian_allowed: bool = false
@export var noise: StringName = &"silent"

var is_open: bool = false
var locked: bool = false
## S9.5 / A5-03: charges placed, fuse running.
var c4_armed: bool = false
## PO-6: a crew member / NPC is in the way of the swinging leaf (it holds its angle).
var swing_blocked: bool = false

var _open_stim_id: int = 0
var _leaf_bodies: Array[AnimatableBody3D] = []
var _leaves: Array[Node3D] = []
var _nav_link: NavigationLink3D = null
## NPC open requested and not yet applied (stealth animation delay).
var _npc_open_pending: bool = false
## D-116: the NPC breaching this door (its net id, 0 = none) and the breach timer (door_kick_<fam> times from it).
var _breacher_net_id: int = 0
var _breach_timer: SceneTreeTimer = null
var _opened_by_net_id: int = 0
## PO-6 swing: open fraction of the leaves now (0 closed .. 1 at door_open_angle_deg), the swing's start /
## target fractions, its linear progress (0..1, eased into the fraction) and duration (s).
var _swing_frac: float = 0.0
var _swing_from: float = 0.0
var _swing_to: float = 0.0
var _swing_u: float = 1.0
var _swing_dur_s: float = 0.0
## PO-6: the last state change was a forced open (fast swing; replicated as `sw`).
var _swing_breach: bool = false
## PO-6: physics frame of _prefab_ready (a state change within it snaps).
var _ready_physics_frame: int = -1
var _sweep_query: PhysicsShapeQueryParameters3D = null

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
			return tw.c4_place_s if _charge_door() else tw.door_open_s


func effective_height() -> float:
	return height_m if height_m > 0.0 else HEIGHT_M


func effective_width() -> float:
	if width_m > 0.0:
		return width_m
	return DOUBLE_WIDTH_M if swing == Swing.DOUBLE else SINGLE_WIDTH_M


func _prefab_ready() -> void:
	set_physics_process(false)
	_ready_physics_frame = Engine.get_physics_frames()
	locked = lock != Lock.NONE
	if using_placeholder and not is_equal_approx(effective_width(), _nominal_width()):
		Log.warn(LOG_CHANNEL, "%s: placeholder door is %.2f m wide, width_m is %.2f" % [name, _nominal_width(), effective_width()])
	_setup_interactable()
	if shutter and interactable != null:
		interactable.enabled = false
	_setup_leaf_bodies()
	add_to_group(GROUP)
	EventBus.heist_phase_changed.connect(_on_phase_for_breach)
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


## Server (D-103 §6 / GN lockdown, last call): lock the door again, as `new_lock` (-1 = its current lock type;
## BARRED = the crew cannot operate it, e.g. a lockdown shutter), closing it first when `close`. Replicated
## (`locked`, `lk`).
## Relocking to NONE just closes it.
func relock(new_lock: int = -1, close: bool = true) -> void:
	if not Net.is_authority():
		return
	if new_lock >= 0:
		lock = new_lock as Lock
	if close and is_open:
		set_open(false)
	locked = lock != Lock.NONE
	_apply_lock_interaction()
	_update_nav_link()


## Server: open (keycard readers, devices, missions).
func open() -> void:
	set_open(true)


## Server: open or close. PO-6: the leaves swing (`breach` = forced open: the fast breach swing);
## `instant` snaps them (load-time state; also any change in the physics frame the door became ready).
func set_open(open: bool, instant: bool = false, breach: bool = false) -> void:
	if not Net.is_authority():
		return
	_swing_breach = breach and open
	_apply_open(open, instant)
	_update_open_stimulus()
	var by: int = _opened_by_net_id if open else 0
	_opened_by_net_id = 0
	open_changed.emit(open, by)
	# A3-07: clients get is_open / locked through HeistNetSync -> _apply_net_state().


## Server (A3-07, NetEntityCodec.state_of): the generic door state plus PO-6 `sw` (forced-open swing).
func _net_state() -> Dictionary:
	var out: Dictionary = {"is_open": is_open, "locked": locked, "sw": _swing_breach, "lk": int(lock)}
	if interactable != null and is_instance_valid(interactable):
		out["ie"] = interactable.enabled
	return out


## Client (A3-07, HeistNetSync): mirror the server's `is_open` / `locked` (leaves, collision, nav).
## PO-6: the leaves swing locally (snap in the bring-up snapshot, the frame the door became ready).
func _apply_net_state(state: Dictionary) -> void:
	if state.has("sw"):
		_swing_breach = bool(state["sw"])
	if state.has("locked") and not bool(state["locked"]) and locked:
		locked = false
		_apply_unlocked_interaction()
	elif state.has("locked") and bool(state["locked"]) and (not locked or int(state.get("lk", lock)) != int(lock)):
		lock = int(state.get("lk", lock)) as Lock  # relock() on the server (D-103 §6)
		locked = true
		_apply_lock_interaction()
	if state.has("ie") and interactable != null:
		interactable.enabled = bool(state["ie"])
	if state.has("is_open") and bool(state["is_open"]) != is_open:
		_apply_open(bool(state["is_open"]))
		open_changed.emit(is_open, 0)
	_update_nav_link()


func _apply_open(open: bool, instant: bool = false) -> void:
	is_open = open
	_start_swing(1.0 if open else 0.0, instant or not _swing_live())
	_sync_leaf_bodies()
	_update_nav_link()


# --- Leaf swing (PO-6, D-105, impact_fx.md §5) ----------------------------------------------

## Open fraction of the leaves now (0 closed .. 1 fully open), for tests and presentation only.
func leaf_open_fraction() -> float:
	return _swing_frac


## True while the leaves are still moving toward the current state (blocked or not).
func is_swinging() -> bool:
	return _swing_u < 1.0


## Snap the leaves to the current state (tests, presentation; no logical change).
func finish_swing() -> void:
	_swing_u = 1.0
	swing_blocked = false
	set_physics_process(false)
	_set_leaf_frac(_swing_to)
	_sync_leaf_bodies()


## A state change may animate once the door has been ready for a physics frame (else: load-time state).
func _swing_live() -> bool:
	return is_inside_tree() and _ready_physics_frame >= 0 and Engine.get_physics_frames() != _ready_physics_frame


func _start_swing(target: float, instant: bool) -> void:
	var tw: InteractionTweak = Tweak.interaction()
	var full_s: float = tw.door_swing_close_s
	if _swing_breach:
		full_s = tw.door_swing_breach_s
	elif target > _swing_frac:
		full_s = tw.door_swing_open_s
	_swing_from = _swing_frac
	_swing_to = target
	_swing_u = 0.0
	# A reversal mid-swing covers only the remaining arc, in proportion.
	_swing_dur_s = full_s * absf(target - _swing_frac)
	if instant or _swing_dur_s <= 0.0:
		finish_swing()
		return
	swing_blocked = false
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"door", fp)


func _physics_step(delta: float) -> void:
	if _swing_u >= 1.0:
		set_physics_process(false)
		return
	var u: float = minf(1.0, _swing_u + delta / _swing_dur_s)
	var f: float = lerpf(_swing_from, _swing_to, 1.0 - (1.0 - u) * (1.0 - u))  # ease-out
	swing_blocked = _sweep_blocked(f)
	if swing_blocked:
		return  # hold; retried every tick, resumes once the body is clear
	_swing_u = u
	_set_leaf_frac(f)
	_sync_leaf_bodies()
	if u >= 1.0:
		set_physics_process(false)


func _set_leaf_frac(f: float) -> void:
	_swing_frac = f
	if shutter:
		return  # no swing: the shutter visual rolls itself
	var angle: float = deg_to_rad(Tweak.interaction().door_open_angle_deg) * f
	for i: int in range(_leaves.size()):
		_leaves[i].rotation.y = _leaf_angle(i, angle)


## Leaf extends +X from its hinge, Leaf2 extends -X: opposite signs swing both the same way.
func _leaf_angle(i: int, angle: float) -> float:
	var sign_inward: float = -1.0 if i == 0 else 1.0
	return angle * (sign_inward if swing != Swing.OUTWARD else -sign_inward)


## True when a crew member / NPC overlaps a leaf posed at open fraction `f` that it does not already
## overlap at the current pose (so a leaf touching a body can still move away from it).
func _sweep_blocked(f: float) -> bool:
	if shutter or not is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var angle: float = deg_to_rad(Tweak.interaction().door_open_angle_deg) * f
	for i: int in range(mini(_leaves.size(), _leaf_bodies.size())):
		var leaf: Node3D = _leaves[i]
		var cs: CollisionShape3D = _leaf_bodies[i].get_node_or_null(^"Collision") as CollisionShape3D
		var parent: Node3D = leaf.get_parent() as Node3D
		if cs == null or cs.shape == null or parent == null:
			continue
		var rot: Vector3 = Vector3(leaf.rotation.x, _leaf_angle(i, angle), leaf.rotation.z)
		var b: Basis = Basis.from_euler(rot, leaf.rotation_order) * Basis.from_scale(leaf.scale)
		var next_xf: Transform3D = parent.global_transform * Transform3D(b, leaf.position) * cs.transform
		var hits: Array[RID] = _sweep_rids(space, cs.shape, next_xf)
		if hits.is_empty():
			continue
		var now: Array[RID] = _sweep_rids(space, cs.shape, cs.global_transform)
		for r: RID in hits:
			if not now.has(r):
				return true
	return false


func _sweep_rids(space: PhysicsDirectSpaceState3D, shape: Shape3D, xf: Transform3D) -> Array[RID]:
	if _sweep_query == null:
		_sweep_query = PhysicsShapeQueryParameters3D.new()
		_sweep_query.collision_mask = SWING_BLOCK_MASK
		_sweep_query.collide_with_areas = false
		_sweep_query.collide_with_bodies = true
	_sweep_query.shape = shape
	_sweep_query.transform = xf
	var out: Array[RID] = []
	for hit: Dictionary in space.intersect_shape(_sweep_query, 8):
		out.append(hit["rid"] as RID)
	return out


# --- NPC doors (A2-01, QA-11) -------------------------------------------------------------

## True when `agent` (NpcBase / AI CrewController) may walk through: open, or it can open it.
func passable_for(agent: Node) -> bool:
	return is_open or can_npc_open(agent)


## Whether `agent` may open this door now: unlocked, or locked (not BARRED) for a guard or a staff civilian
## whose SpawnPoint tags meet `npc_authorized_tags` (VAULT: only when listed). Crew AI only opens unlocked doors.
func can_npc_open(agent: Node) -> bool:
	if is_open:
		return true
	if shutter:
		return false  # only the mission / devices raise a shutter
	if push_bar and not is_inside(agent) and not _staff_authorised(agent):
		return false  # A2-08; an authorised NPC has the key side too (GN dock smoker back into LD, C's gap 2)
	return not locked or _staff_authorised(agent) or _police_breach(agent)


## P3 gate: `agent` is loud-phase police and this lock can be breached (not BARRED / VAULT).
func _police_breach(agent: Node) -> bool:
	if lock == Lock.BARRED or lock == Lock.VAULT:
		return false
	var npc: NpcBase = agent as NpcBase
	if npc == null or not npc.alive or (npc.role != &"police" and npc.role != &"special"):
		return false
	var rt: HeistRuntime = HeistRuntime.of(self)
	return rt != null and rt.went_loud


## Locked door (not BARRED): `agent` is a guard, or staff (a civilian: curator, conservator, night manager;
## D-103 §3b.6), whose SpawnPoint tags meet the post tags. Patrons carry no staff tag. A VAULT door authorises
## nobody unless a tag is listed on it (opt-in, lead ruling round 164: GN's guard_vaultline couriers).
func _staff_authorised(agent: Node) -> bool:
	if lock == Lock.BARRED or npc_authorized_tags.is_empty():
		return false
	var npc: NpcBase = agent as NpcBase
	if npc == null or not npc.alive or not STAFF_ROLES.has(npc.role):
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
	if locked and not _staff_authorised(agent):  # P3 gate: a police breach
		delay = tw.npc_door_breach_s
		was_locked = false
		_npc_open_pending = true
		_breacher_net_id = by
		_breach_timer = get_tree().create_timer(delay, false, true)
		_breach_timer.timeout.connect(_npc_apply_breach.bind(by))
		return true
	if delay <= 0.0:
		_npc_apply_open(by, was_locked)
	else:
		_npc_open_pending = true
		get_tree().create_timer(delay, false, true).timeout.connect(_npc_apply_open.bind(by, was_locked))
	return true


func _npc_apply_open(by_net_id: int, was_locked: bool, breach: bool = false) -> void:
	_npc_open_pending = false
	if not is_inside_tree() or is_open:
		return
	_opened_by_net_id = by_net_id
	set_open(true, false, breach)  # PO-6: a police breach kicks it open (fast swing)
	var close_s: float = Tweak.interaction().npc_locked_door_close_s
	if was_locked and locked and close_s > 0.0:
		get_tree().create_timer(close_s, false, true).timeout.connect(_npc_auto_close)


func _on_phase_for_breach(_old: int, _new: int) -> void:
	_update_nav_link()


func _npc_apply_breach(by_net_id: int) -> void:
	_npc_open_pending = false
	_breacher_net_id = 0
	_breach_timer = null
	if not is_inside_tree() or is_open:
		return
	unlock()
	_npc_apply_open(by_net_id, false, true)
	var p: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
	EventBus.audio_cue_requested.emit(&"cue.door_breach", p, by_net_id)
	Net.replicate_event(&"audio_cue_requested", [&"cue.door_breach", p, by_net_id])


## D-116: seconds since `agent` started breaching this door (the breach timer), or -1 when it is not the breacher.
func breach_elapsed_s(agent: Node) -> float:
	if _breach_timer == null or _breacher_net_id == 0 or NetIds.of(agent) != _breacher_net_id:
		return -1.0
	return maxf(Tweak.interaction().npc_door_breach_s - _breach_timer.time_left, 0.0)


## D-116: where the breacher stands (InteractionTweak.npc_door_breach_stand_m from the door plane on `from`'s side,
## laterally within the middle half of the leaf) and the direction it faces (the door normal, toward the door).
func breach_stand(from: Vector3) -> Array:
	var lp: Vector3 = global_transform.affine_inverse() * from
	var side: float = 1.0 if lp.z >= 0.0 else -1.0
	var half: float = effective_width() * 0.25
	var stand: Vector3 = global_transform * Vector3(clampf(lp.x, -half, half), lp.y,
		side * Tweak.interaction().npc_door_breach_stand_m)
	var n: Vector3 = global_transform.basis.z * -side
	return [stand, Vector3(n.x, 0.0, n.z).normalized()]


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
	if absf(lp.x) > effective_width() * 0.5 + CROSS_MARGIN_M or lp.y > effective_height() or lp.y < -1.0:
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


## Server (QC-57, mission scripts): NPCs whose spawn tags include `tag` may open this door from now on (GN: the
## Vaultline couriers through the LD art door). Idempotent; the NavLink follows.
func authorise_npc_tag(tag: StringName) -> void:
	if tag == &"" or npc_authorized_tags.has(tag):
		return
	npc_authorized_tags.append(tag)
	_update_nav_link()


## The link is enabled while NPCs can pass: open, unlocked, or keycard-authorised for some post.
func _update_nav_link() -> void:
	if _nav_link == null:
		return
	# P3 gate: once loud, breachable locks (not BARRED / VAULT) are linked: police breach them.
	var rt: HeistRuntime = HeistRuntime.of(self) if is_inside_tree() else null
	var breachable: bool = lock != Lock.BARRED and lock != Lock.VAULT and rt != null and rt.went_loud
	var passable: bool = is_open or not locked or (not npc_authorized_tags.is_empty() and lock != Lock.BARRED)
	_nav_link.enabled = passable or breachable
	_nav_link.navigation_layers = 1 if passable else NAV_LAYER_BREACH
	# A2-08: closed push-bar doors pass inside (-Z, start) -> outside (+Z, end) only.
	_nav_link.bidirectional = is_open or not push_bar or not npc_authorized_tags.is_empty()


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
	if EventBus.heist_phase_changed.is_connected(_on_phase_for_breach):
		EventBus.heist_phase_changed.disconnect(_on_phase_for_breach)
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
	_apply_lock_interaction()
	interactable.extra_check = _availability
	interactable.completed.connect(_on_completed)


## The interaction for the current `lock` (setup and relock()). BARRED: blocked (other prefabs / the mission open it).
func _apply_lock_interaction() -> void:
	if interactable == null:
		return
	interactable.casing_allowed = casing_allowed
	interactable.civilian_allowed = civilian_allowed
	interactable.speed_modifier_key = &""
	interactable.consumes_item = false
	interactable.interaction_time_s = _default_interaction_time() if interaction_time_s < 0.0 else interaction_time_s
	match lock:
		Lock.NONE:
			interactable.kind = &"open_door"
			interactable.casing_allowed = true  # PO-5 (S1.1): opening an unlocked door is not suspicious
		Lock.LOCKPICK:
			interactable.kind = &"lockpick"
			interactable.speed_modifier_key = &"interaction.lockpick_speed_mult"  # S9.2
		Lock.KEYCARD:
			interactable.kind = &"keycard"  # S9.6
			if interactable.requires_item == &"":
				interactable.requires_item = KEYCARD_ITEM
			interactable.consumes_item = true
		_:
			interactable.kind = &"place_c4" if _charge_door() else &"open_door"
			if _charge_door():
				interactable.prompt_key = &"ui.prompt.place_c4"


func _availability(crew: Node) -> StringName:
	if push_bar and not is_open and not is_inside(crew):
		return BLOCK_PUSH_BAR_OUTSIDE
	if not locked:
		return InteractableComponent.BLOCK_NONE
	match lock:
		Lock.LOCKPICK, Lock.KEYCARD:
			return InteractableComponent.BLOCK_NONE
		_:
			if _charge_door():
				return _charge_availability(crew)
			# CODE / ELECTRONIC / BARRED / VAULT open through other prefabs (unlock()).
			return InteractableComponent.BLOCK_STATE


func _apply_unlocked_interaction() -> void:
	if interactable == null:
		return
	interactable.kind = &"open_door"
	interactable.casing_allowed = true  # PO-5 (S1.1): a casing player opens/closes unlocked doors
	interactable.interaction_time_s = Tweak.interaction().door_open_s
	interactable.requires_item = &""
	interactable.consumes_item = false
	interactable.speed_modifier_key = &""


func _on_completed(_crew: Node) -> void:
	if not Net.is_authority():
		return
	if locked and _charge_door():
		var c: CrewController = _crew as CrewController
		if not c4_armed and Safe.consume_charges_for(c, charges_required, self):
			_arm_charges(NetIds.of(c))
		return
	if locked:
		unlock()
		set_open(true)
		return
	set_open(not is_open)


# --- Shaped charges / C4 (S9.5 / A5-03) ------------------------------------------------------

## True when this door is opened by placed charges (a lock no other interaction here opens).
func _charge_door() -> bool:
	return charges_required > 0 and lock != Lock.NONE and lock != Lock.LOCKPICK and lock != Lock.KEYCARD \
		and lock != Lock.VAULT


func _charge_availability(crew: Node) -> StringName:
	if c4_armed:
		return InteractableComponent.BLOCK_STATE
	if Safe.charge_source_for(crew as CrewController, charges_required, self) == &"":
		return InteractableComponent.BLOCK_ITEM
	return InteractableComponent.BLOCK_NONE


func _arm_charges(by_net_id: int) -> void:
	c4_armed = true
	var tw: InteractionTweak = Tweak.interaction()
	EventBus.audio_cue_requested.emit(&"cue.c4_armed", global_position, by_net_id)
	Net.replicate_event(&"audio_cue_requested", [&"cue.c4_armed", global_position, by_net_id])
	get_tree().create_timer(tw.c4_fuse_s, false, true).timeout.connect(_blow_charges.bind(by_net_id))


func _blow_charges(by_net_id: int) -> void:
	if not is_inside_tree() or not c4_armed:
		return
	c4_armed = false
	var tw: InteractionTweak = Tweak.interaction()
	var pos: Vector3 = global_position + Vector3.UP * 1.0
	EventBus.audio_cue_requested.emit(&"cue.c4_explode", pos, by_net_id)
	Net.replicate_event(&"audio_cue_requested", [&"cue.c4_explode", pos, by_net_id])
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt != null:
		rt.make_noise(pos, tw.c4_noise_radius_m, &"explosion", net_id)
	Explosion.apply(self, pos, tw.c4_blast_radius_m, tw.c4_blast_damage, by_net_id, Safe.C4_ITEM)
	unlock()
	set_open(true, false, true)  # PO-6: blown open (fast swing)


func _setup_leaf_bodies() -> void:
	if _leaf_body == null:
		Log.error(LOG_CHANNEL, "%s: missing `LeafBody`" % name)
		return
	var w: float = effective_width()
	var leaf_w: float = w * 0.5 if swing == Swing.DOUBLE else w
	var surface: StringName = leaf_surface_id()
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
		box.size.y = effective_height()
		cs.shape = box
		cs.position.x = leaf_w * 0.5 * (1.0 if i == 0 else -1.0)
		cs.position.y = effective_height() * 0.5
		body.collision_layer = LAYER_WORLD_DYNAMIC
		body.collision_mask = 0
		body.set_meta(ShotFx.SURFACE_META, surface)
		if leaf_see_through():
			body.add_to_group(StealthDirector.GROUP_SEE_THROUGH)
		_leaves.append(leaf)
		_leaf_bodies.append(body)
	_sync_leaf_bodies()


## D-105: the leaves' bullet surface: `leaf_surface`, else metal for a BARRED / VAULT lock or a metal-style visual,
## glass for a glass-style visual, else wood.
func leaf_surface_id() -> StringName:
	if leaf_surface != &"":
		return leaf_surface
	if lock == Lock.VAULT or lock == Lock.BARRED:
		return SURFACE_METAL
	var style: String = visual_scene.resource_path.get_file().to_lower() if visual_scene != null else ""
	for k: String in LEAF_METAL_KEYWORDS:
		if k in style:
			return SURFACE_METAL
	for k: String in LEAF_GLASS_KEYWORDS:
		if k in style:
			return SURFACE_GLASS
	return SURFACE_WOOD


## D-142: the leaves are see-through for stealth vision (glass leaf and `see_through`).
func leaf_see_through() -> bool:
	return see_through and leaf_surface_id() == SURFACE_GLASS


func _sync_leaf_bodies() -> void:
	for i: int in range(mini(_leaves.size(), _leaf_bodies.size())):
		_leaf_bodies[i].global_transform = _leaves[i].global_transform
		# P3 gate: an open leaf never blocks (PD2): units filing through a breached door snagged on it.
		_leaf_bodies[i].collision_layer = 0 if is_open else LAYER_WORLD_DYNAMIC
