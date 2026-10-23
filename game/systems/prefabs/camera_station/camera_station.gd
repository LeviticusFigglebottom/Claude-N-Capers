## Security-room console (gameplay_prefabs.md `camera_station`). Owner: ENV A. Rows S8.1, S8.2, S8.3.
## Killing/dominating the operator turns every camera off; interacting loops the cameras (skill).
## Visual: `Screens` (MeshInstance3D(s); A swaps their material to off/static), `Seat` marker.
##
## Server flow (A2-02):
## - Heist start (deferred after the map is built): if the `security_room_staffed` variant group is
##   absent, or has an active slot whose id does not end in "empty", and `operator_spawn` resolves
##   to a SpawnPoint (variants may have stripped it), a guard (pager via PagerSystem, role guard) is
##   spawned there with `no_patrol` (holds his post) and becomes `operator`.
## - The operator killed, or put in DOMINATED/TIED/SURRENDERED/CONVERTED: all cameras of
##   the heist are disabled permanently: cameras_loop_disabled(by_net_id) [R], then
##   camera_disabled(id, &"operator") [R] per camera; `Screens` go dark. A running S3.5 countdown is
##   NOT stopped (StealthDirector owns it).
## - A camera destroyed while the operator is on duty: roll GameRng &"cameras" < camera_dispatch_chance;
##   on success, after camera_dispatch_delay_s the nearest calm guard (not the operator) investigates
##   the broken camera (GuardBrain.notice_suspicious). Signal `guard_dispatched`.
## - Interaction `loop_cameras` needs the `stealth.camera_loop` flag (P3 hook: `loop_requested`).
class_name CameraStation
extends GameplayPrefab

signal operator_spawned(npc: NpcBase)
signal operator_neutralised(by_net_id: int)
signal guard_dispatched(guard: NpcBase, camera: SecurityCamera)
## P3 (S8.3): a crew member completed the loop interaction.
signal loop_requested(crew: Node)

const PLACEHOLDER: PackedScene = preload("res://systems/prefabs/camera_station/camera_station_placeholder.tscn")
const STAFFED_GROUP: StringName = &"security_room_staffed"
const OPERATOR_GROUP: StringName = &"camera_operator"
const RNG_STREAM: StringName = &"cameras"
const LOOP_FLAG: StringName = &"stealth.camera_loop"
## The loop needs the skill (was BLOCK_DISABLED = "Out of order", B r308 05_camera_operator).
const BLOCK_NEED_SKILL: StringName = &"ui.blocked.need_skill"
## Operator states that take him off duty (S8.2 "killed or dominated").
const OFF_DUTY_STATES: Array[int] = [
	Enums.AlertState.DOMINATED, Enums.AlertState.TIED, Enums.AlertState.SURRENDERED,
	Enums.AlertState.CONVERTED, Enums.AlertState.DEAD,
]
## Guard states that can be dispatched.
const DISPATCHABLE_STATES: Array[int] = [Enums.AlertState.CALM, Enums.AlertState.CURIOUS]

## SpawnPoint (CAMERA_OPERATOR) whose NPC operates this station.
@export var operator_spawn: NodePath
## Collision box size (m), placed on the pivot; ZERO = fit to the visual (or use the visual's own
## `Collision`), see GameplayPrefab "Collision fitting".
@export var collision_size_override: Vector3 = Vector3.ZERO
@export_group("Interaction")
## -1 = InteractionTweak.camera_loop_s.
@export var interaction_time_s: float = -1.0
@export var requires_item: StringName = &""
@export var stealth_only: bool = true
@export var loud_only: bool = false
@export var casing_allowed: bool = false
@export var noise: StringName = &"silent"

## The spawned operator (null if the room is unstaffed or before heist start).
var operator: NpcBase = null
## True when an operator was spawned for this station.
var staffed: bool = false
## True once the operator was neutralised (cameras off for good).
var cameras_off: bool = false

## S8.3: active loops {slot: {camera_net_id, left}}; one per crew member.
var loops: Dictionary = {}

## {camera_net_id, left} dispatches waiting for camera_dispatch_delay_s.
var _pending: Array[Dictionary] = []
var _screens_off: StandardMaterial3D = null


func _placeholder_scene() -> PackedScene:
	return PLACEHOLDER


func required_visual_nodes() -> PackedStringArray:
	return PackedStringArray(["Screens", "Seat"])


func _default_interaction_time() -> float:
	return Tweak.interaction().camera_loop_s


func _prefab_ready() -> void:
	interactable.kind = &"loop_cameras"
	interactable.extra_check = _loop_check
	# PD2: nobody touches the console while the operator sits at it: no prompt at all until he is off duty.
	interactable.aim_filter = func(_crew: Node) -> bool: return not operator_on_duty()
	interactable.completed.connect(_on_loop_completed)
	EventBus.camera_disabled.connect(_on_camera_disabled)
	EventBus.cameras_loop_disabled.connect(_on_cameras_loop_disabled)
	_bind_operator.call_deferred()


func _exit_tree() -> void:
	if EventBus.camera_disabled.is_connected(_on_camera_disabled):
		EventBus.camera_disabled.disconnect(_on_camera_disabled)
	if EventBus.cameras_loop_disabled.is_connected(_on_cameras_loop_disabled):
		EventBus.cameras_loop_disabled.disconnect(_on_cameras_loop_disabled)


## True while the operator watches the feeds (alive, not dominated/tied).
func operator_on_duty() -> bool:
	return operator != null and is_instance_valid(operator) and operator.alive \
		and not OFF_DUTY_STATES.has(operator.alert_state)


## Cameras of this heist.
func cameras() -> Array[SecurityCamera]:
	return SecurityCamera.cameras_in(HeistRuntime.of(self))


## Whether the heist's variants staff the security room (absent group = staffed).
static func room_staffed(variants: Dictionary) -> bool:
	if not variants.has(STAFFED_GROUP):
		return true
	var v: Variant = variants[STAFFED_GROUP]
	if not v is Array:
		return bool(v)
	for sid: Variant in v as Array:
		if not String(sid).ends_with("empty"):
			return true
	return false


# --- Operator (S8.2) -----------------------------------------------------------------

func _bind_operator() -> void:
	if not Net.is_authority() or not is_inside_tree() or operator != null:
		return
	var rt: HeistRuntime = HeistRuntime.of(self)
	if rt == null or rt.dynamic_root == null or rt.phase == Enums.HeistPhase.ENDED:
		return
	var sp: SpawnPoint = get_node_or_null(operator_spawn) as SpawnPoint if not operator_spawn.is_empty() else null
	if sp == null or not room_staffed(rt.variants):
		Log.info(LOG_CHANNEL, "%s: security room unstaffed" % name)
		return
	var info: Dictionary = {
		"tags": sp.tags, "idle_activity": sp.idle_activity if sp.idle_activity != &"" else &"sit",
		"patrol_graph": null, "spawn_point": sp, "no_patrol": true, "camera_station": self,
	}
	operator = rt.spawn_npc(&"guard", sp.global_transform, info)
	if operator == null:
		return
	staffed = true
	operator.add_to_group(OPERATOR_GROUP)
	operator.alert_state_changed.connect(_on_operator_state)
	operator.died.connect(_on_operator_died)
	operator_spawned.emit(operator)


func _on_operator_state(_old_state: int, new_state: int) -> void:
	if new_state != Enums.AlertState.DEAD and OFF_DUTY_STATES.has(new_state):
		_neutralise(0)


func _on_operator_died(_info: Dictionary, killer_net_id: int) -> void:
	_neutralise(killer_net_id)


## Server: all cameras off for good (S8.2). The S3.5 countdown keeps running (unstoppable).
func _neutralise(by_net_id: int) -> void:
	if not Net.is_authority() or cameras_off or not staffed:
		return
	cameras_off = true
	_pending.clear()
	Log.info(LOG_CHANNEL, "%s: camera operator neutralised by %d: all cameras off" % [name, by_net_id])
	_emit_fact(&"cameras_loop_disabled", [by_net_id])
	for cam: SecurityCamera in cameras():
		cam.disable(SecurityCamera.REASON_OPERATOR, by_net_id)
	_apply_screens()
	operator_neutralised.emit(by_net_id)


func _on_cameras_loop_disabled(_by_net_id: int) -> void:
	if not Net.is_authority():
		cameras_off = true
		_apply_screens()


func _apply_screens() -> void:
	if _screens_off == null:
		_screens_off = StandardMaterial3D.new()
		_screens_off.albedo_color = Color(0.02, 0.02, 0.03, 1.0)
	var root: Node = visual_node("Screens")
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi != null:
			mi.material_override = _screens_off if cameras_off else null
		stack.append_array(n.get_children())


# --- Broken camera dispatch (S8.1) ------------------------------------------------------

func _on_camera_disabled(camera_net_id: int, reason: StringName) -> void:
	if not Net.is_authority() or reason != SecurityCamera.REASON_DESTROYED or not operator_on_duty():
		return
	var cam: SecurityCamera = Ids.lookup(camera_net_id) as SecurityCamera
	var rt: HeistRuntime = HeistRuntime.of(self)
	if cam == null or rt == null or not rt.is_ancestor_of(cam):
		return
	var tw: StealthTweak = Tweak.stealth()
	if GameRng.stream(RNG_STREAM).randf() >= tw.camera_dispatch_chance:
		return
	_pending.append({"camera_net_id": camera_net_id, "left": tw.camera_dispatch_delay_s})


func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	_tick_loops(delta)
	if _pending.is_empty():
		return
	var due: Array[int] = []
	for p: Dictionary in _pending:
		p["left"] = float(p["left"]) - delta
		if float(p["left"]) <= 0.0:
			due.append(int(p["camera_net_id"]))
	if due.is_empty():
		return
	_pending = _pending.filter(func(p: Dictionary) -> bool: return float(p["left"]) > 0.0)
	for id: int in due:
		_dispatch(Ids.lookup(id) as SecurityCamera)


func _dispatch(cam: SecurityCamera) -> void:
	var rt: HeistRuntime = HeistRuntime.of(self)
	var st: StealthDirector = _stealth()
	if cam == null or rt == null or not operator_on_duty() or (st != null and not st.is_stealth()):
		return
	var target: Vector3 = cam.broken_position()
	var best: NpcBase = null
	var best_d: float = INF
	for n: Node in rt.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g == operator or not DISPATCHABLE_STATES.has(g.alert_state):
			continue
		if not g.get_node_or_null(^"Brain") is GuardBrain:
			continue
		var d: float = g.global_position.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best = g
	if best == null:
		return
	(best.get_node(^"Brain") as GuardBrain).notice_suspicious(target)
	guard_dispatched.emit(best, cam)


# --- Loop interaction (S8.3, P3 hook) -----------------------------------------------------

func _loop_check(crew: Node) -> StringName:
	if cameras_off:
		return InteractableComponent.BLOCK_STATE
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	if slot < 0 or not Modifiers.flag(slot, LOOP_FLAG):
		return BLOCK_NEED_SKILL
	return InteractableComponent.BLOCK_NONE


## S8.3 (`stealth.camera_loop`, Nimble basic): loop one camera for InteractionTweak.camera_loop_active_s
## (25 s, fidelity spec). One loop per crew member: a new loop ends that member's previous one. The
## camera picked is the nearest working, not-yet-looped camera to the crew member.
func _on_loop_completed(crew: Node) -> void:
	loop_requested.emit(crew)
	if not Net.is_authority() or crew == null:
		return
	var slot: int = int(crew.get(&"slot"))
	end_loop(slot)
	var looped: Dictionary = {}
	for l: Variant in loops.values():
		looped[int((l as Dictionary)["camera_net_id"])] = true
	var pos: Vector3 = (crew as Node3D).global_position if crew is Node3D else global_position
	var best: SecurityCamera = null
	for cam: SecurityCamera in cameras():
		if cam.disabled_reason != &"" or looped.has(cam.net_id):
			continue
		if best == null or cam.global_position.distance_to(pos) < best.global_position.distance_to(pos):
			best = cam
	if best == null:
		return
	best.set_suppressed(_loop_source(slot), true)
	loops[slot] = {"camera_net_id": best.net_id, "left": Tweak.interaction().camera_loop_active_s}


## S8.3: end crew `slot`'s loop (if any); the camera sees again.
func end_loop(slot: int) -> void:
	if not loops.has(slot):
		return
	var cam: SecurityCamera = Ids.lookup(int((loops[slot] as Dictionary)["camera_net_id"])) as SecurityCamera
	if cam != null and is_instance_valid(cam):
		cam.set_suppressed(_loop_source(slot), false)
	loops.erase(slot)


func _tick_loops(delta: float) -> void:
	for slot: Variant in loops.keys():
		var l: Dictionary = loops[slot]
		l["left"] = float(l["left"]) - delta
		if float(l["left"]) <= 0.0:
			end_loop(int(slot))


static func _loop_source(slot: int) -> StringName:
	return StringName("camera_loop_%d" % slot)
