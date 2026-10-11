## First-person crew member (human, AI teammate or test bot). Owner: ENV A.
## Contracts: crew_intent.md (single entry point `apply_intent`), heist_map.md §7 (capsule sizes),
## pd2_fidelity S1.1 (casing limits), S1.2 (mask-up), S1.5 (movement makes NO noise), S10.1 (bags).
## Combat (A1-08): child components `Health` (CrewHealth: health/armor/downs/bleedout/revive) and
## `Weapons` (CrewWeapons: ammo, firing, hit claims), exposed as `health` / `weapons` (the HUD
## duck-typed interface). `take_hit(info, attacker_net_id)` is the single hit entry point (damage.md).
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
const SCENE_PATH: String = "res://systems/player/crew_member.tscn"

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
## First-person weapon visual (ENV B WeaponVisual, visual_slots.md) when attached; its
## get_marker(&"Muzzle") is the tracer/noise origin (CrewWeapons._muzzle_position()).
var weapon_visual: Node3D = null
## Mask-up hold progress 0..1 (HUD).
var mask_progress: float = 0.0
## D-014 / L6.1: an AI teammate waiting at the van in stealth (CrewAiBrain); the StealthDirector
## never observes a hidden crew member.
var stealth_hidden: bool = false
## Last intent applied (held by the server for this tick).
var intent: CrewIntent = CrewIntent.new()
## QB-60: sprint / jump stamina (CrewStamina), ticked by the movement simulation.
var stamina: CrewStamina = CrewStamina.new()

var _runtime: HeistRuntime = null
var _jump_latch: bool = false
var _remote_pos: Vector3 = Vector3.INF
## A3-07: bumped by every server teleport of a remote-owned crew member; the owner echoes it with its
## positions, so positions sent before the owner applied the teleport are ignored, not rejected.
var _teleport_seq: int = 0
var _send_accum: float = 0.0

## Combat components (A1-08); null only for a scene without them.
@onready var health: CrewHealth = get_node_or_null("Health") as CrewHealth
@onready var weapons: CrewWeapons = get_node_or_null("Weapons") as CrewWeapons
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
	if CrewView.of(self) == null:  # QB-47: camera, weapon visual, mask (presentation only)
		var view: CrewView = CrewView.new()
		view.name = CrewView.NODE_NAME
		add_child(view)


## Server (and the owning client for prediction): set the intent for this tick.
func apply_intent(new_intent: CrewIntent) -> void:
	intent = new_intent if new_intent != null else CrewIntent.new()


## Server setup from the crew registry and loadout (CrewManager).
func setup(p_slot: int, info: Dictionary, p_loadout: Loadout) -> void:
	slot = p_slot
	peer_id = int(info.get("peer_id", 0))
	is_ai = bool(info.get("is_ai", false))
	display_name = String(info.get("display_name", "Crew %d" % p_slot))
	loadout = CrewWeapons.build_loadout(p_loadout)  # resolved; default kestrel + suppressor if null
	name = "Crew%d" % p_slot
	var tw: CrewTweak = Tweak.crew()
	body_bags = mini(tw.body_bags_base + int(Modifiers.add(slot, &"stealth.body_bags_extra")),
		tw.body_bags_cap + int(Modifiers.add(slot, &"stealth.body_bags_extra")))
	cable_ties = tw.cable_ties_base + int(Modifiers.add(slot, &"stealth.cable_ties_extra"))


func is_local() -> bool:
	return not is_ai and peer_id == Net.local_peer_id()


## Instant loadout swap (firing range, QB-25): re-resolve, re-arm weapons, refill health/armor.
func set_loadout(p_loadout: Loadout) -> void:
	loadout = CrewWeapons.build_loadout(p_loadout)
	if weapons != null:
		weapons.set_loadout(loadout)
	if health != null:
		health.reset_full()
	var view: CrewView = CrewView.of(self)
	if view != null:
		view.refresh()  # QB-47: weapon visual + mask of the new loadout
		view.replicate_mask_descriptor()  # QA-25: server -> every peer



## QB-46: pause (true) / resume the local human's PlayerInput (menus, range panels). While paused the
## crew member holds an idle intent (same look direction, no buttons). Releasing the mouse is the UI's job.
## Query: the PlayerInput child's `enabled`.
func set_input_paused(paused: bool) -> void:
	var pin: PlayerInput = get_node_or_null(^"PlayerInput") as PlayerInput
	if pin != null:
		pin.set_paused(paused)
	if paused:
		var idle: CrewIntent = CrewIntent.new()
		idle.look_yaw = look_yaw
		idle.look_pitch = look_pitch
		apply_intent(idle)


## QB-25: a standalone, masked, locally controlled crew member (PlayerInput + Weapons + Health) for
## ENV B's firing range. Works without a HeistRuntime. Returns the CrewController.
static func spawn_for_range(parent: Node, xform: Transform3D, p_loadout: Loadout) -> Node:
	var crew: CrewController = (load(SCENE_PATH) as PackedScene).instantiate() as CrewController
	var local_slot: int = Net.local_slot()
	crew.setup(local_slot if local_slot >= 0 else 0,
		{"peer_id": Net.local_peer_id(), "is_ai": false, "display_name": "Range"}, p_loadout)
	crew.masked = true
	crew.mask_progress = 1.0
	parent.add_child(crew)
	NetIds.claim(crew)
	crew.teleport(xform)
	var pin: PlayerInput = PlayerInput.new()
	pin.name = "PlayerInput"
	crew.add_child(pin)
	return crew


## Server: the single hit entry point (docs/contracts/damage.md). CrewHealth applies armor, gating and
## downs (head x1 from NPC fire) and emits damage_applied itself.
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	if health == null:
		var out: Dictionary = info.duplicate()
		out["amount"] = 0.0
		out["killed"] = false
		return out
	return health.take_hit(info, attacker_net_id)


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
		if CrewView.of(self) != null:
			CrewView.of(self).replicate_mask_descriptor()  # QA-25: descriptor before the mask-up
		if HeistNetSync.can_rpc(self):
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
	if Net.is_authority() and _has_remote_owner() and _is_networked():
		_teleport_seq += 1
		_rpc_owner_teleport.rpc_id(peer_id, xform, _teleport_seq)  # A3-07: the owner predicts; move it too


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
		if weapons != null:
			weapons.client_tick(intent, delta)
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
	var armor_def: ArmorDef = _armor_def()
	stamina.refresh_max(self, armor_def)
	sprinting = i.sprint and can_sprint and stamina.can_sprint()  # QB-60: no sprint at 0 stamina
	var speed: float = tw.walk_speed
	if crouched:
		speed = tw.crouch_speed * Modifiers.mult(slot, &"movement.crouch_speed_mult")
	elif sprinting:
		speed = tw.sprint_speed
	speed *= Modifiers.mult(slot, &"movement.speed_mult")
	if armor_def != null:  # QB-56: armor move-speed penalty x movement.armor_penalty_mult
		speed *= clampf(1.0 - (1.0 - armor_def.move_speed_mult) * Modifiers.mult(slot, &"movement.armor_penalty_mult"), 0.1, 1.0)
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
	if i.jump and not _jump_latch and is_on_floor() and can_jump and stamina.can_jump():
		velocity.y = tw.jump_velocity
		stamina.on_jump()
	stamina.tick(sprinting, delta)
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
	if health != null:
		health.server_tick(delta)
	if weapons != null:
		weapons.server_tick(intent, delta)
	if _runtime != null and _runtime.interaction != null:
		_runtime.interaction.tick(self, intent, delta)
	if _runtime != null:
		_runtime.crew_actions_tick(self, intent, delta)


## QB-56/60: the worn ArmorDef (loadout armor; null when none / unknown).
func _armor_def() -> ArmorDef:
	if loadout == null or loadout.armor == &"":
		return null
	return ContentDB.armor(loadout.armor)


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


# --- Networking (A3-07; drop-in is P6) -----------------------------------------
## Server -> owner: `teleport()` of a remote human (spawn, custody release, out of bounds, test hooks)
## and the reconcile after a rejected position. Transforms of crew members a peer does not own
## arrive through HeistNetSync (NetEntityCodec.apply_xform).

func _is_networked() -> bool:
	if _runtime == null or _runtime.net_sync == null or not _runtime.net_sync.is_begun():
		return false  # before the bring-up the owner has no replica of this node yet
	return is_inside_tree() and multiplayer.has_multiplayer_peer() \
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
		and multiplayer.get_peers().has(peer_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_owner_teleport(xform: Transform3D, seq: int) -> void:
	if Net.is_authority() or not is_local():
		return
	teleport(xform)
	_teleport_seq = seq


func _client_send(delta: float) -> void:
	_send_accum += delta
	var period: float = 1.0 / maxf(Tweak.crew().intent_send_hz, 1.0)
	if _send_accum < period:
		return
	_send_accum = 0.0
	_rpc_client_intent.rpc_id(1, intent.to_dict(), global_position, _teleport_seq)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_client_intent(d: Dictionary, pos: Vector3, seq: int) -> void:
	if not Net.is_authority():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		Log.warn(&"net", "intent for slot %d from wrong peer %d" % [slot, multiplayer.get_remote_sender_id()])
		return
	intent = CrewIntent.from_dict(d)
	if seq == _teleport_seq:  # else: sent before the owner applied our last teleport
		_remote_pos = pos


func _accept_remote_position() -> void:
	var tw: CrewTweak = Tweak.crew()
	var max_step: float = tw.sprint_speed * tw.max_client_speed_slack / maxf(tw.intent_send_hz, 1.0) * 2.0
	var d: float = global_position.distance_to(_remote_pos)
	if d > tw.teleport_reject_m:
		Log.warn(&"net", "slot %d position rejected (%.1f m jump)" % [slot, d])
		if _is_networked():  # A3-07: reconcile the owner back to the server position
			_teleport_seq += 1
			_rpc_owner_teleport.rpc_id(peer_id, Transform3D(Basis(Vector3.UP, look_yaw), global_position), _teleport_seq)
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
