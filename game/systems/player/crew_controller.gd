## First-person crew member (human, AI teammate or test bot). Owner: ENV A.
## Contracts: crew_intent.md (single entry point `apply_intent`), heist_map.md §7 (capsule sizes),
## pd2_fidelity S1.1 (casing limits), S1.2 (mask-up), S1.5 (movement makes NO noise), S10.1 (bags).
##
## Authority: the server simulates every slot from its held intent. A remote human predicts its
## own movement locally and sends intent + position at 30 Hz; the server sanity-checks speed and
## teleports (architecture.md §3). Nothing in this file emits noise for movement (S1.5).
class_name CrewController
extends CharacterBody3D

signal masked_changed(masked: bool)
signal crew_state_changed(old_state: int, new_state: int)
signal inventory_changed()
signal carried_bag_changed(bag: Node)

const COLLISION_LAYER_PLAYERS: int = 1 << 2
const COLLISION_MASK_WORLD: int = (1 << 0) | (1 << 1) | (1 << 3)

@export var slot: int = -1

var net_id: int = 0
var peer_id: int = 0
var is_ai: bool = false
var display_name: String = ""
var masked: bool = false
var crew_state: Enums.CrewState = Enums.CrewState.NORMAL
var crouched: bool = false
var sprinting: bool = false
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var loadout: Loadout = null
## Inventory (S6.2, S7.2, S9.6).
var body_bags: int = 0
var cable_ties: int = 0
var items: Dictionary[StringName, int] = {}
var carried_bag: Node = null
## Mask-up hold progress 0..1 (HUD).
var mask_progress: float = 0.0
## Last intent applied (held by the server for this tick).
var intent: CrewIntent = CrewIntent.new()

var _runtime: HeistRuntime = null
var _jump_latch: bool = false
var _remote_pos: Vector3 = Vector3.INF
var _send_accum: float = 0.0

@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head


func _ready() -> void:
	add_to_group(G.CREW)
	collision_layer = COLLISION_LAYER_PLAYERS
	collision_mask = COLLISION_MASK_WORLD
	_runtime = HeistRuntime.of(self)
	if slot < 0:
		var tw: CrewTweak = Tweak.crew()
		body_bags = tw.body_bags_base
		cable_ties = tw.cable_ties_base
	_apply_stance(false)


## Server (and the owning client for prediction): set the intent for this tick.
func apply_intent(new_intent: CrewIntent) -> void:
	intent = new_intent if new_intent != null else CrewIntent.new()


## Server setup from the crew registry and loadout (CrewManager).
func setup(p_slot: int, info: Dictionary, p_loadout: Loadout) -> void:
	slot = p_slot
	peer_id = int(info.get("peer_id", 0))
	is_ai = bool(info.get("is_ai", false))
	display_name = String(info.get("display_name", "Crew %d" % p_slot))
	loadout = p_loadout
	name = "Crew%d" % p_slot
	var tw: CrewTweak = Tweak.crew()
	body_bags = mini(tw.body_bags_base + int(Modifiers.add(slot, &"stealth.body_bags_extra")),
		tw.body_bags_cap + int(Modifiers.add(slot, &"stealth.body_bags_extra")))
	cable_ties = tw.cable_ties_base + int(Modifiers.add(slot, &"stealth.cable_ties_extra"))


func is_local() -> bool:
	return not is_ai and peer_id == Net.local_peer_id()


## Casing mode = unmasked (S1.1).
func is_casing() -> bool:
	return not masked


func eye_height() -> float:
	var tw: CrewTweak = Tweak.crew()
	return tw.eye_crouched if crouched else tw.eye_standing


func eye_position() -> Vector3:
	return global_position + Vector3(0.0, eye_height(), 0.0)


## Unit view direction from absolute yaw/pitch (Godot -Z forward).
func aim_direction() -> Vector3:
	return Vector3(-sin(look_yaw) * cos(look_pitch), sin(look_pitch), -cos(look_yaw) * cos(look_pitch))


func is_carrying_bag() -> bool:
	return carried_bag != null and is_instance_valid(carried_bag)


func item_count(item_id: StringName) -> int:
	return items.get(item_id, 0)


func add_item(item_id: StringName, count: int = 1) -> void:
	items[item_id] = item_count(item_id) + count
	inventory_changed.emit()


func remove_item(item_id: StringName, count: int = 1) -> bool:
	if item_count(item_id) < count:
		return false
	items[item_id] = item_count(item_id) - count
	if items[item_id] <= 0:
		items.erase(item_id)
	inventory_changed.emit()
	return true


func use_body_bag() -> bool:
	if body_bags <= 0:
		return false
	body_bags -= 1
	inventory_changed.emit()
	return true


func use_cable_tie() -> bool:
	if cable_ties <= 0:
		return false
	cable_ties -= 1
	inventory_changed.emit()
	return true


func set_carried_bag(bag: Node) -> void:
	carried_bag = bag
	carried_bag_changed.emit(bag)


## S1.2: mask up (irreversible). `forced` = detection/combat/alarm.
func set_masked(forced: bool = false) -> void:
	if masked:
		return
	masked = true
	mask_progress = 1.0
	masked_changed.emit(true)
	if Net.is_authority():
		EventBus.crew_masked.emit(slot)
		Net.replicate_event(&"crew_masked", [slot])
		_rpc_masked.rpc(forced)
	Log.info(&"crew", "slot %d masked (forced=%s)" % [slot, forced])


func set_crew_state(s: Enums.CrewState) -> void:
	if s == crew_state:
		return
	var old: int = crew_state
	crew_state = s
	if s != Enums.CrewState.NORMAL and _runtime != null and _runtime.interaction != null:
		_runtime.interaction.cancel(slot)
	crew_state_changed.emit(old, s)


## Server: hard-move (test hooks, spawns, custody release).
func teleport(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xform.origin)
	var fwd: Vector3 = -xform.basis.z
	look_yaw = atan2(-fwd.x, -fwd.z)
	look_pitch = 0.0
	rotation = Vector3(0.0, look_yaw, 0.0)
	velocity = Vector3.ZERO
	_remote_pos = Vector3.INF
	if _runtime != null and _runtime.interaction != null:
		_runtime.interaction.cancel(slot)


func _physics_process(delta: float) -> void:
	if Net.is_authority():
		if _has_remote_owner():
			if _remote_pos != Vector3.INF:
				_accept_remote_position()
		else:
			_simulate(delta)
		_tick_server_actions(delta)
	elif is_local():
		_simulate(delta)  # client-side prediction of own movement
		_client_send(delta)


func _has_remote_owner() -> bool:
	return not is_ai and peer_id != Net.local_peer_id() and peer_id != 0


func _simulate(delta: float) -> void:
	var tw: CrewTweak = Tweak.crew()
	var i: CrewIntent = intent
	look_yaw = i.look_yaw
	look_pitch = clampf(i.look_pitch, -deg_to_rad(tw.max_pitch_deg), deg_to_rad(tw.max_pitch_deg))
	rotation = Vector3(0.0, look_yaw, 0.0)
	if _head != null:
		_head.rotation = Vector3(look_pitch, 0.0, 0.0)
	var mobile: bool = crew_state == Enums.CrewState.NORMAL or crew_state == Enums.CrewState.SWAN_SONG
	var casing: bool = is_casing()
	# S1.1: no crouch/sprint/jump while casing.
	var want_crouch: bool = i.crouch and not casing and mobile
	if want_crouch != crouched:
		_apply_stance(want_crouch)
	var bag_w: int = _bag_weight()
	var can_sprint: bool = not casing and not crouched and mobile and i.move.y > 0.1
	if bag_w >= 0:
		can_sprint = can_sprint and (tw.bag_can_sprint[bag_w] or Modifiers.flag(slot, &"loot.can_sprint_with_heavy"))
	sprinting = i.sprint and can_sprint
	var speed: float = tw.walk_speed
	if crouched:
		speed = tw.crouch_speed * Modifiers.mult(slot, &"movement.crouch_speed_mult")
	elif sprinting:
		speed = tw.sprint_speed
	speed *= Modifiers.mult(slot, &"movement.speed_mult")
	if bag_w >= 0 and not Modifiers.flag(slot, &"stealth.body_bag_concealed_carry"):
		var pen: float = (1.0 - tw.bag_speed_mult[bag_w]) * Modifiers.mult(slot, &"loot.carry_speed_penalty_mult")
		speed *= clampf(1.0 - pen, 0.1, 1.0)
	if not mobile:
		speed = 0.0
	var mv: Vector2 = i.move.limit_length(1.0)
	var wish: Vector3 = Basis(Vector3.UP, look_yaw) * Vector3(mv.x, 0.0, -mv.y) * speed
	var accel: float = tw.acceleration * (1.0 if is_on_floor() else tw.air_control)
	velocity.x = move_toward(velocity.x, wish.x, accel * delta)
	velocity.z = move_toward(velocity.z, wish.z, accel * delta)
	if not is_on_floor():
		velocity.y -= tw.gravity * delta
	var can_jump: bool = not casing and mobile and not crouched
	if bag_w >= 0:
		can_jump = can_jump and tw.bag_can_jump[bag_w]
	if i.jump and not _jump_latch and is_on_floor() and can_jump:
		velocity.y = tw.jump_velocity
	_jump_latch = i.jump and not is_on_floor()
	move_and_slide()


func _tick_server_actions(delta: float) -> void:
	var tw: CrewTweak = Tweak.crew()
	# S1.2 mask-up hold.
	if not masked:
		if intent.mask_up and crew_state == Enums.CrewState.NORMAL:
			mask_progress = minf(mask_progress + delta / maxf(tw.mask_up_time_s, 0.001), 1.0)
			if mask_progress >= 1.0:
				set_masked(false)
		else:
			mask_progress = 0.0
	if _runtime != null and _runtime.interaction != null:
		_runtime.interaction.tick(self, intent, delta)
	if _runtime != null:
		_runtime.crew_actions_tick(self, intent, delta)


func _bag_weight() -> int:
	if not is_carrying_bag():
		return -1
	var w: Variant = carried_bag.get(&"weight")
	return int(w) if w != null else Enums.LootWeight.MEDIUM


func _apply_stance(crouch: bool) -> void:
	crouched = crouch
	var tw: CrewTweak = Tweak.crew()
	var cap: CapsuleShape3D = _collision.shape as CapsuleShape3D
	if cap == null:
		cap = CapsuleShape3D.new()
		_collision.shape = cap
	cap.radius = tw.capsule_radius
	cap.height = tw.height_crouched if crouch else tw.height_standing
	_collision.position = Vector3(0.0, cap.height * 0.5, 0.0)
	if _head != null:
		_head.position = Vector3(0.0, eye_height(), 0.0)


# --- Networking (skeleton; co-op hardening in P3/P6) ---------------------------

func _client_send(delta: float) -> void:
	_send_accum += delta
	var period: float = 1.0 / maxf(Tweak.crew().intent_send_hz, 1.0)
	if _send_accum < period:
		return
	_send_accum = 0.0
	_rpc_client_intent.rpc_id(1, intent.to_dict(), global_position)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_client_intent(d: Dictionary, pos: Vector3) -> void:
	if not Net.is_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		Log.warn(&"net", "intent for slot %d from wrong peer %d" % [slot, multiplayer.get_remote_sender_id()])
		return
	intent = CrewIntent.from_dict(d)
	_remote_pos = pos


func _accept_remote_position() -> void:
	var tw: CrewTweak = Tweak.crew()
	var max_step: float = tw.sprint_speed * tw.max_client_speed_slack / maxf(tw.intent_send_hz, 1.0) * 2.0
	var d: float = global_position.distance_to(_remote_pos)
	if d > tw.teleport_reject_m:
		Log.warn(&"net", "slot %d position rejected (%.1f m jump)" % [slot, d])
	elif d <= max_step + 0.05 or crew_state == Enums.CrewState.NORMAL:
		global_position = _remote_pos
	look_yaw = intent.look_yaw
	look_pitch = intent.look_pitch
	rotation = Vector3(0.0, look_yaw, 0.0)
	_remote_pos = Vector3.INF


@rpc("authority", "call_remote", "reliable")
func _rpc_masked(forced: bool) -> void:
	if not masked:
		masked = true
		masked_changed.emit(true)
		Log.debug(&"crew", "slot %d masked (replicated, forced=%s)" % [slot, forced])
