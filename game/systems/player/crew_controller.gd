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
## S1.3: civilian mode started / ended (gear picked up, or masked by an alarm).
signal civilian_changed(civilian: bool)
## PI-13: crouch / sprint / jump pressed while casing (S1.1 blocks it); once per press. HUD hint source.
signal casing_blocked(action: StringName)
## PI-06: a hard move (teleport) set position and look; PlayerInput re-reads the look from it.
signal teleported()

const COLLISION_LAYER_PLAYERS: int = 1 << 2
const COLLISION_MASK_WORLD: int = (1 << 0) | (1 << 1) | (1 << 3)
const SCENE_PATH: String = "res://systems/player/crew_member.tscn"

@export var slot: int = -1

var net_id: int = 0
var peer_id: int = 0
var is_ai: bool = false
var display_name: String = ""
## Playable heister (one of Heisters.ids(); &"" = generic crew): the slot's Loadout.heister
## (D-073). Presentation only (FP sleeves, characters.md v1.8).
var heister: StringName = &""
var masked: bool = false
## S1.3 civilian mode (HeistDef.start_mode = civilian): no gear, undetectable, no mask-up or firing, only
## `civilian_allowed` interactions. Picking up gear (GearPickup) or any mask-up (alarm) ends it.
var civilian: bool = false:
	set(v):
		if v == civilian:
			return
		civilian = v
		civilian_changed.emit(v)
## &"civilian" | &"casing" | &"masked" (ui_hud v1.6 player_mode).
var player_mode: StringName:
	get:
		if masked:
			return &"masked"
		return &"civilian" if civilian else &"casing"
var crew_state: Enums.CrewState = Enums.CrewState.NORMAL
## P-FP-STATES: first-person state presentation (local human only, built on its first tick).
var fp_states: CrewFpStates = null
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
## get_marker(&"Muzzle") is the tracer / flash origin, presentation only (CrewWeapons._muzzle_position()).
## The server's shot and noise origin is the eye position, not the animated muzzle (D-121).
var weapon_visual: Node3D = null
## Mask-up hold progress 0..1 (HUD).
var mask_progress: float = 0.0
## P1-02: true when the mask went on by force (detection / combat / alarm), false for a voluntary G hold.
## HeistRuntime reads it so a forced mask does not move CASING -> STEALTH (no STEALTH hop before LOUD).
var mask_forced: bool = false
## D-014 / L6.1: an AI teammate waiting at the van in stealth (CrewAiBrain); the StealthDirector
## never observes a hidden crew member.
var stealth_hidden: bool = false
## P1-01 (read-only outside): on the ground (floor, or a step edge the capsule rests on while climbing); false
## while airborne. See _move_grounded.
var grounded: bool = false
## Last intent applied (held by the server for this tick).
var intent: CrewIntent = CrewIntent.new()
## QB-60: sprint / jump stamina (CrewStamina), ticked by the movement simulation.
var stamina: CrewStamina = CrewStamina.new()
## PO-16 / D-145: PD2 free ladder climbing (human crew; bots keep the Ladder prefab's own climb).
var ladder: CrewLadderClimb = CrewLadderClimb.new(self)

## QC-43: the hub crew's own InteractionSystem (no HeistRuntime in the safehouse).
var hub_interaction: InteractionSystem = null
## PI-21: the camera's remaining step-smoothing offset (m, negative after a step up). Presentation reads it.
var step_offset: float:
	get:
		return _step_offset
## PO-4 (read-only): the camera's remaining crouch / stand easing (m).
var crouch_cam_offset: float:
	get:
		return _crouch_cam
## PO-4 (read-only): the camera's melee-hit punch (pitch, roll; radians).
var melee_punch: Vector2:
	get:
		return _punch
## PO-4 (read-only): the camera landing dip (m, negative while dipping).
var land_dip: float:
	get:
		return _land_dip
## D-116 (read-only): the camera head-bob stride phase (radians, one full cycle = two footsteps) and its weight
## (0 still .. 1 walk, sprint x head_bob_sprint_mult): the viewmodel's figure-8 bob rides the same footsteps.
var bob_phase: float:
	get:
		return _bob_phase
var bob_weight: float:
	get:
		return _bob_w
## D-102 lane, read only: the current carry camera roll (degrees).
var carry_tilt: float:
	get:
		return _carry_tilt
var _runtime: HeistRuntime = null
var _jump_latch: bool = false
## D-107: seconds until the next jump is allowed (PD2 0.55 s), and a crouch cancelled by a jump press.
var _jump_cd: float = 0.0
var _crouch_cancel: bool = false
## PI-13: last tick's crouch / sprint / jump intent (press edges for casing_blocked).
var _blocked_prev: Dictionary[StringName, bool] = {}
var _remote_pos: Vector3 = Vector3.INF
## A3-07: bumped by every server teleport of a remote-owned crew member; the owner echoes it with its
## positions, so positions sent before the owner applied the teleport are ignored, not rejected.
var _teleport_seq: int = 0
var _send_accum: float = 0.0
## P1-01: camera-only vertical lag after step-ups / step-downs (m, decays at CrewTweak.step_smooth_rate).
var _step_offset: float = 0.0
## PO-4: landing dip (camera only, local human): offset (m), depth, seconds since landing (-1 = idle).
var _land_dip: float = 0.0
var _land_amp: float = 0.0
var _land_t: float = -1.0
## PO-4: camera-only crouch / stand easing (m, eases to 0) and the stance it last saw.
var _crouch_cam: float = 0.0
var _cam_eye: float = -1.0
## PO-4: camera head-bob phase (rad) and eased weight 0..~1.6.
var _bob_phase: float = 0.0
var _bob_w: float = 0.0
## D-102: effective carry speed mult this tick (after perks) and the raw PD2 move_speed_modifier for the bob.
var _carry_mult: float = 1.0
var _carry_bob_mult: float = 1.0
## PO-4: melee-hit camera punch (pitch, roll; radians): current value, peak amplitude, seconds since the hit.
var _punch: Vector2 = Vector2.ZERO
var _punch_amp: Vector2 = Vector2.ZERO
var _punch_t: float = -1.0
## D-102 lane: camera roll while carrying a bag (degrees, eased toward CrewTweak.carry_tilt_deg).
var _carry_tilt: float = 0.0

## Combat components (A1-08); null only for a scene without them.
@onready var health: CrewHealth = get_node_or_null("Health") as CrewHealth
@onready var weapons: CrewWeapons = get_node_or_null("Weapons") as CrewWeapons
## L3.9 melee (CrewMelee), ticked with the weapons.
@onready var melee: CrewMelee = get_node_or_null("Melee") as CrewMelee
## A3-12 grenades / throwing knives (CrewThrowables), ticked with the weapons.
@onready var throwables: CrewThrowables = get_node_or_null(CrewThrowables.NODE_NAME) as CrewThrowables
@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head


func _ready() -> void:
	add_to_group(G.CREW)
	collision_layer = COLLISION_LAYER_PLAYERS
	collision_mask = COLLISION_MASK_WORLD
	_runtime = HeistRuntime.of(self)
	if melee != null and not melee.hit_landed.is_connected(_on_melee_hit):
		melee.hit_landed.connect(_on_melee_hit)
	var gtw: CrewTweak = Tweak.crew()  # P1-01 ground handling (see _move_grounded)
	floor_max_angle = deg_to_rad(gtw.max_slope_deg)
	floor_snap_length = gtw.step_height_m
	floor_constant_speed = true
	if slot < 0:
		var tw: CrewTweak = Tweak.crew()
		body_bags = tw.body_bags_base
		cable_ties = tw.cable_ties_base
	# The capsule is a crew_member.tscn sub-resource, shared by every instance: own a copy, or one crew member's
	# crouch (_apply_stance) shrinks everyone's capsule under their standing offset and sinks them 0.3 m into the floor.
	if _collision.shape != null:
		_collision.shape = _collision.shape.duplicate()
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
	heister = loadout.heister if loadout.heister != &"" or p_loadout == null else p_loadout.heister  # D-073
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
	heister = loadout.heister if loadout.heister != &"" or p_loadout == null else p_loadout.heister  # D-073
	if weapons != null:
		weapons.set_loadout(loadout)
	if health != null:
		health.reset_full()
	var view: CrewView = CrewView.of(self)
	if view != null:
		view.refresh()  # QB-47: weapon visual + mask of the new loadout
		if view.fp_viewmodel() != null:
			view.fp_viewmodel().apply_sleeves(heister)  # characters.md v1.8
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


## QC-43 (A3-11): the local crew member of the 3D safehouse: no HeistRuntime, no Net session needed (offline
## solo peer like the range), unmasked in civilian mode (S1.3: no mask-up, no firing, no weapon drawn) with its
## own InteractionSystem (`HubInteraction`, InteractionTweak.reach_m aimed reach) so hub stations work.
## MenuFlow pauses it around station screens with set_input_paused; LocalHudModel.track(crew) shows prompts.
static func spawn_for_hub(parent: Node, xform: Transform3D, p_loadout: Loadout) -> Node:
	var crew: CrewController = (load(SCENE_PATH) as PackedScene).instantiate() as CrewController
	var local_slot: int = Net.local_slot()
	crew.setup(local_slot if local_slot >= 0 else 0,
		{"peer_id": Net.local_peer_id(), "is_ai": false, "display_name": "Safehouse"}, p_loadout)
	crew.civilian = true
	var isys: InteractionSystem = InteractionSystem.new()
	isys.name = "HubInteraction"
	isys.local = true  # A (hub loopback): the hub's own system serves this client's presses locally
	crew.add_child(isys)
	crew.hub_interaction = isys
	parent.add_child(crew)
	NetIds.claim(crew)
	crew.teleport(xform)
	var pin: PlayerInput = PlayerInput.new()
	pin.name = "PlayerInput"
	crew.add_child(pin)
	return crew


## The InteractionSystem serving this crew member (the heist's, or the hub's own; null in the range).
func _interaction_system() -> InteractionSystem:
	if _runtime != null and _runtime.interaction != null:
		return _runtime.interaction
	return hub_interaction


## Server: the single hit entry point (docs/contracts/damage.md). CrewHealth applies armor, gating and
## downs (head x1 from NPC fire) and emits damage_applied itself.
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	if health == null:
		var out: Dictionary = info.duplicate()
		out["amount"] = 0.0
		out["killed"] = false
		return out
	return health.take_hit(info, attacker_net_id)


## A4-04: aiming down sights this tick (CrewView's ADS rule: aim held, not casing, not sprinting).
func _aiming_down_sights(i: CrewIntent) -> bool:
	return i != null and i.aim and not is_casing() and not sprinting


## Casing mode = unmasked (S1.1).
func is_casing() -> bool:
	return not masked


func eye_height() -> float:
	var tw: CrewTweak = Tweak.crew()
	if crew_state == Enums.CrewState.DOWNED:  # P-FP-STATES (L2.5): sat on the floor, the shot origin with the camera
		return tw.eye_downed
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
	var picked: bool = bag != null and carried_bag == null
	carried_bag = bag
	if picked and weapons != null:  # D-102 (PD2 PlayerCarry:_enter): the pickup re-draws the weapon, fire waits
		weapons.equip(weapons.equipped_slot, true)
	carried_bag_changed.emit(bag)


## S1.2: mask up (irreversible). `forced` = detection/combat/alarm.
func set_masked(forced: bool = false) -> void:
	if masked:
		return
	masked = true
	mask_forced = forced
	civilian = false  # S1.3: masking (alarm) ends civilian mode with the gear on
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
	if s != Enums.CrewState.NORMAL and _interaction_system() != null:
		_interaction_system().cancel(slot)
	crew_state_changed.emit(old, s)


## Server: hard-move (test hooks, spawns, custody release).
func teleport(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xform.origin)
	var fwd: Vector3 = -xform.basis.z
	look_yaw = atan2(-fwd.x, -fwd.z)
	look_pitch = 0.0
	rotation = Vector3(0.0, look_yaw, 0.0)
	velocity = Vector3.ZERO
	_step_offset = 0.0  # P1-01: a hard move is not a step to smooth; airborne until it lands
	_land_dip = 0.0
	_land_t = -1.0
	_crouch_cam = 0.0
	_cam_eye = eye_height()
	grounded = false
	_remote_pos = Vector3.INF
	intent.look_yaw = look_yaw  # PI-06: the held intent must not turn the body back this tick
	intent.look_pitch = look_pitch
	teleported.emit()
	if _interaction_system() != null:
		_interaction_system().cancel(slot)
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
		if hub_interaction != null:  # A (hub loopback): a client presses the safehouse stations itself
			hub_interaction.tick(self, intent, delta)
		if weapons != null:
			weapons.client_tick(intent, delta)
		if melee != null:
			melee.tick(intent, delta)  # presentation on the owning client (hits are server-side)
		if throwables != null:
			throwables.tick(intent, delta)
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
	if casing and mobile:
		_report_casing_blocked(&"crouch", i.crouch)
		_report_casing_blocked(&"sprint", i.sprint and i.move.y > 0.1)
		_report_casing_blocked(&"jump", i.jump)
	# D-107 (PD2 _check_action_jump): jump pressed while crouched stands up instead of jumping; a held / toggled
	# crouch stays cancelled until it is released.
	if i.jump and not _jump_latch and crouched and mobile and not casing:
		_crouch_cancel = true
		_jump_latch = true
	if not i.crouch:
		_crouch_cancel = false
	var want_crouch: bool = i.crouch and not casing and mobile and not _crouch_cancel
	if crouched and not want_crouch and not _has_stand_headroom(tw):
		want_crouch = true  # PI-04: stay crouched under a low ceiling until there is room to stand
	if want_crouch != crouched:
		_apply_stance(want_crouch)
	var bag_w: int = _bag_weight()
	# A4-04 movement.sprint_any_direction (Free Running aced): any move direction sprints, not only forward.
	var sprint_dir: bool = i.move.y > 0.1 or (i.move.length() > 0.1 and Modifiers.flag(slot, &"movement.sprint_any_direction"))
	var can_sprint: bool = not casing and not crouched and mobile and sprint_dir
	# A4-04 movement.reload_while_sprinting: a reload ends the sprint (PD2 _start_action_reload) and no sprint starts
	# while reloading (◇: PD2's sprint cancels the reload instead; CrewWeapons has no cancel).
	if weapons != null and weapons.reloading and not Modifiers.flag(slot, &"movement.reload_while_sprinting"):
		can_sprint = false
	if bag_w >= 0:
		can_sprint = can_sprint and (tw.bag_can_sprint[bag_w] or Modifiers.flag(slot, &"loot.can_sprint_with_heavy"))
	var armor_def: ArmorDef = _armor_def()
	stamina.refresh_max(self, armor_def)
	sprinting = i.sprint and can_sprint and stamina.can_sprint(sprinting)  # D-107: start > threshold, run to 0
	var speed: float = tw.walk_speed
	if crouched:
		speed = tw.crouch_speed * Modifiers.mult(slot, &"movement.crouch_speed_mult")
	elif sprinting:
		speed = tw.sprint_speed * Modifiers.mult(slot, &"movement.sprint_speed_mult")
	# A4-04: the ADS cap (PD2 steelsight; humans only, bots keep their pace); movement.ads_speed_penalty_mult scales it.
	if not is_ai and _aiming_down_sights(i):
		var ads: float = 1.0 - (1.0 - tw.ads_speed_mult) * Modifiers.mult(slot, &"movement.ads_speed_penalty_mult")
		speed = minf(speed, tw.walk_speed * clampf(ads, 0.0, 1.0))
	speed *= Modifiers.mult(slot, &"movement.speed_mult")
	if weapons != null:  # B4-18: minigun spinning (SpecialWeapons params.spin.move_speed_mult)
		speed *= weapons.move_speed_mult
	if armor_def != null:  # QB-56: armor move-speed penalty x movement.armor_penalty_mult
		speed *= clampf(1.0 - (1.0 - armor_def.move_speed_mult) * Modifiers.mult(slot, &"movement.armor_penalty_mult"), 0.1, 1.0)
	_carry_mult = 1.0
	_carry_bob_mult = 1.0
	if bag_w >= 0:
		_carry_bob_mult = tw.bag_speed_mult[bag_w]  # D-102: PD2 bob x the raw move_speed_modifier
		if not Modifiers.flag(slot, &"stealth.body_bag_concealed_carry"):
			var pen: float = (1.0 - tw.bag_speed_mult[bag_w]) * Modifiers.mult(slot, &"loot.carry_speed_penalty_mult")
			_carry_mult = clampf(1.0 - pen, 0.1, 1.0)
			speed *= _carry_mult
	if not mobile:
		speed = 0.0
	if _ladder_tick(i, delta, tw, mobile):
		stamina.tick(false, delta)
		_jump_latch = i.jump
		move_and_slide()
		grounded = false
		_finish_tick(delta, tw)
		return
	var mv: Vector2 = i.move.limit_length(1.0)
	var wish: Vector3 = Basis(Vector3.UP, look_yaw) * Vector3(mv.x, 0.0, -mv.y) * speed
	var hv: Vector2 = Vector2(velocity.x, velocity.z)
	var wv: Vector2 = Vector2(wish.x, wish.z)
	var accel: float = tw.acceleration
	if not grounded:
		accel *= tw.air_control
	elif wv.length() < hv.length() or wv.dot(hv) < 0.0:
		accel = tw.deceleration  # PI-08: braking / reversing on the ground
	hv = hv.move_toward(wv, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.y
	if not grounded:
		velocity.y -= tw.gravity * delta
	var can_jump: bool = not casing and mobile and not crouched
	var jump_v: float = tw.jump_velocity
	if bag_w >= 0:
		jump_v *= tw.bag_jump_mult[bag_w]  # D-102: a bag lowers the jump, never blocks it
	var jumped: bool = false
	_jump_cd = maxf(_jump_cd - delta, 0.0)
	if i.jump and not _jump_latch and grounded and can_jump and _jump_cd <= 0.0:
		velocity.y = jump_v
		stamina.on_jump(i.move.length() > 0.1)  # D-107: only a run-jump costs stamina, nothing blocks a jump
		_jump_cd = tw.jump_cooldown_s
		jumped = true
	stamina.tick(sprinting, delta)
	# PI-05: a held jump fires once; the next jump needs a release. PI-25: the latch arms only on a jump that
	# fired, so jump pressed in the air / while blocked (and held) still jumps on landing instead of being eaten.
	_jump_latch = i.jump and (_jump_latch or jumped)
	_move_grounded(delta, tw)
	_edge_assist(wish, delta, tw)
	_finish_tick(delta, tw)


## PO-16: human crew climb freely (CrewLadderClimb); bots, scripted crew (a runtime bot intent: tests, cutscenes) and
## free-climb-off keep the Ladder prefab's climb. The opt-out of that climb is held only on ticks the prefab could
## start one (moving or interacting), so a scripted `Ladder.start_climb` on an idle human still works.
## True when the ladder drove this tick's velocity.
func _ladder_tick(i: CrewIntent, delta: float, tw: CrewTweak, mobile: bool) -> bool:
	var free: bool = tw.ladder_free_climb and not is_ai and not (_runtime != null and _runtime.has_bot_intent(slot))
	ladder.sync_opt_out(free and (ladder.is_climbing() or i.interact or i.move.length() > 0.05))
	if not free or not mobile:
		if ladder.is_climbing():
			ladder.ladder = null
		return false
	return ladder.tick(i, delta, tw)


## Step smoothing, landing dip, crouch camera and the head (eye height, bob, punch, carry tilt, FP states).
func _finish_tick(delta: float, tw: CrewTweak) -> void:
	_step_offset *= exp(-tw.step_smooth_rate * delta)
	if absf(_step_offset) < 0.0005:
		_step_offset = 0.0
	_tick_land_dip(delta, tw)
	_tick_crouch_cam(delta, tw)
	if _head != null:
		_head.position.y = eye_height() + _step_offset + _land_dip + _crouch_cam
		_apply_head_bob(delta, tw)
		_tick_punch(delta, tw)
		_tick_carry_tilt(delta, tw)
		_tick_fp_states(delta, tw)


## P1-01: move_and_slide with PD2-like ground handling. Walks up lips up to CrewTweak.step_height_m, follows
## the floor down steps and ramps of that height instead of falling, and treats slopes steeper than
## max_slope_deg as walls. Same code for the server, the owner's prediction and AI crew (deterministic, no
## state beyond `grounded`). The rounded capsule bottom rests on a step's edge while it climbs: that contact
## counts as ground (`grounded`) though is_on_floor() calls it a wall.
func _move_grounded(delta: float, tw: CrewTweak) -> void:
	var was_grounded: bool = grounded
	var vy_before: float = velocity.y
	var y0: float = global_position.y
	var stepped: bool = false
	var h_motion: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
	if was_grounded and velocity.y <= 0.0 and h_motion.length_squared() > 1e-8:
		var rise: float = _step_up_rise(h_motion, tw)
		stepped = rise > 0.0
		if stepped:
			global_position.y += rise
			velocity.y = 0.0
	move_and_slide()
	grounded = is_on_floor()
	if not grounded and (was_grounded or stepped) and velocity.y <= 0.0:
		grounded = _snap_down(tw)
	if grounded and velocity.y < 0.0:
		velocity.y = 0.0
	if was_grounded and grounded:
		_step_offset = clampf(_step_offset - (global_position.y - y0), -tw.step_height_m, tw.step_height_m)
	elif grounded and not was_grounded:
		_on_landed(-vy_before, tw)


## PO-4: start the camera landing dip for an impact of `impact_mps` (downward speed).
func _on_landed(impact_mps: float, tw: CrewTweak) -> void:
	if is_ai or not is_local() or tw.land_dip_gain <= 0.0 or impact_mps <= tw.land_dip_min_mps:
		return
	var depth: float = minf((impact_mps - tw.land_dip_min_mps) * tw.land_dip_gain, tw.land_dip_max_m)
	if _land_t >= 0.0 and -_land_dip >= depth:
		return  # a harder dip is still playing
	_land_amp = -depth
	_land_t = 0.0


## PO-4: the local human's melee hit landed: kick the camera (presentation only; aim / look are untouched).
func _on_melee_hit(_target: Object) -> void:
	if is_ai or not is_local():
		return
	var tw: CrewTweak = Tweak.crew()
	var side: float = -1.0 if (melee.swings % 2) == 0 else 1.0  # alternate the roll per swing
	_punch_amp = Vector2(-deg_to_rad(tw.melee_punch_pitch_deg), side * deg_to_rad(tw.melee_punch_roll_deg))
	_punch_t = 0.0


## D-102 lane (PD2 PlayerCarry.target_tilt): the local human's camera rolls carry_tilt_deg while a bag is carried,
## stepping at carry_tilt_rate_dps (PD2 math.step 150 deg/s). Camera only; off with Reduce Motion.
func _tick_carry_tilt(delta: float, tw: CrewTweak) -> void:
	var target: float = 0.0
	if not is_ai and is_local() and is_carrying_bag() and not _reduce_motion():
		target = tw.carry_tilt_deg
	_carry_tilt = move_toward(_carry_tilt, target, tw.carry_tilt_rate_dps * delta)
	if _carry_tilt != 0.0:
		_head.rotation.z += deg_to_rad(_carry_tilt)


## P-FP-STATES: the local human's camera through DOWNED / TASED / CLOAKER_DOWNED and hits (CrewFpStates).
func _tick_fp_states(delta: float, tw: CrewTweak) -> void:
	if is_ai or not is_local():
		return
	if fp_states == null:
		fp_states = CrewFpStates.new(self)
	fp_states.tick(delta, tw, _reduce_motion())
	_head.position.y += fp_states.cam_dy
	_head.rotation += fp_states.cam_rot


func _reduce_motion() -> bool:
	var gs: GameSettings = GameSettings.current()
	return gs != null and bool(gs.get_value(GameSettings.ACCESSIBILITY, &"reduce_motion"))


## Critically damped impulse response in closed form, x(t) = A * wt * e^(1 - wt): peaks at A after 1/w s (explicit
## integration at 60 Hz lost most of the 4 Hz peak).
func _tick_punch(delta: float, tw: CrewTweak) -> void:
	if _punch_t < 0.0:
		return
	_punch_t += delta
	var wt: float = TAU * maxf(tw.melee_punch_hz, 0.01) * _punch_t
	_punch = _punch_amp * wt * exp(1.0 - wt) * CrewFpStates.shake_scale()  # Options screen shake
	if wt > 12.0:
		_punch = Vector2.ZERO
		_punch_t = -1.0
	_head.rotation.x += _punch.x
	_head.rotation.z += _punch.y


## PO-4: subtle PD2 camera head bob (local human, grounded, moving; Options head_bob). Camera only.
func _apply_head_bob(delta: float, tw: CrewTweak) -> void:
	if is_ai or not is_local():
		return
	var gs: GameSettings = GameSettings.current()
	var on: bool = gs == null or not gs.has_method(&"head_bob") or bool(gs.call(&"head_bob"))
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var target: float = 0.0
	if on and grounded and speed > 0.3:
		# D-102: PD2's bob is per state, not per m/s; with a bag it is x move_speed_modifier, so the speed term is
		# normalised to the carried walk speed and the carry factor applied once.
		var ref: float = maxf(tw.head_bob_ref_mps * _carry_mult, 0.01)
		target = clampf(speed / ref, 0.0, 1.0) * (tw.head_bob_sprint_mult if sprinting else 1.0) * _carry_bob_mult
		if CrewView.is_aiming(self):
			target *= tw.head_bob_ads_mult
	_bob_w = move_toward(_bob_w, target, tw.head_bob_rate * delta)
	if _bob_w <= 0.0:
		_head.position.x = 0.0
		_head.rotation.z = 0.0
		return
	var stride: float = tw.head_bob_sprint_stride_m if sprinting else tw.head_bob_stride_m
	_bob_phase = fmod(_bob_phase + speed * delta / maxf(stride, 0.01) * TAU, TAU)
	_head.position.x = sin(_bob_phase) * tw.head_bob_lateral_m * _bob_w
	_head.position.y += sin(_bob_phase * 2.0) * tw.head_bob_vertical_m * _bob_w
	_head.rotation.z = sin(_bob_phase) * deg_to_rad(tw.head_bob_roll_deg) * _bob_w


## PO-4: ease the camera through a crouch / stand change instead of snapping the eye 0.6 m in one tick
## (P-FP-STATES: any eye change, so going down and being revived ease the same way).
func _tick_crouch_cam(delta: float, tw: CrewTweak) -> void:
	var eye: float = eye_height()
	if _cam_eye < 0.0:
		_cam_eye = eye
	if not is_equal_approx(eye, _cam_eye):
		var cap: float = absf(tw.eye_standing - minf(tw.eye_crouched, tw.eye_downed))
		_crouch_cam = clampf(_crouch_cam + _cam_eye - eye, -cap, cap)
		_cam_eye = eye
		if tw.crouch_smooth_rate <= 0.0:
			_crouch_cam = 0.0
	if _crouch_cam != 0.0:
		_crouch_cam *= exp(-tw.crouch_smooth_rate * delta)
		if absf(_crouch_cam) < 0.0005:
			_crouch_cam = 0.0


## Closed-form critically damped dip, x(t) = A * wt * e^(1 - wt): the full depth A after 1/w s, settled by ~12/w.
func _tick_land_dip(delta: float, tw: CrewTweak) -> void:
	if _land_t < 0.0:
		return
	_land_t += delta
	var wt: float = TAU * maxf(tw.land_dip_hz, 0.01) * _land_t
	_land_dip = _land_amp * wt * exp(1.0 - wt)
	if wt > 12.0:
		_land_dip = 0.0
		_land_t = -1.0


## How far to raise the body onto a lip ahead (<= step_height_m, walkable top) before the horizontal move;
## 0 when there is no step to take (no wall ahead, no headroom, too tall, nothing to stand on, steep slope).
func _step_up_rise(h_motion: Vector3, tw: CrewTweak) -> float:
	var col: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(global_transform, h_motion, col, safe_margin, false, 4) or not _hit_wall(col):
		return 0.0
	var xf: Transform3D = global_transform
	var up: Vector3 = Vector3.UP * tw.step_height_m
	if test_move(xf, up, col, safe_margin, false, 1):
		up = col.get_travel()  # headroom
	xf.origin += up
	var fwd: Vector3 = h_motion
	if test_move(xf, h_motion, col, safe_margin, false, 1):
		fwd = col.get_travel()
	xf.origin += fwd
	# Still blocked at step height (too tall), or nothing to stand on up there.
	if up.y < 0.01 or fwd.length() < h_motion.length() * 0.25 \
			or not test_move(xf, Vector3.DOWN * up.y, col, safe_margin, false, 1):
		return 0.0
	var rise: float = xf.origin.y + col.get_travel().y - global_position.y
	# The surface just past the landing contact must be walkable: a step's top (the capsule lands on its
	# edge), not a steep slope (which would otherwise be climbed one step-up at a time). The top's height
	# (not the landing height: the rounded bottom lands on a taller edge) caps the step.
	var top: float = _ground_height(col.get_position() + h_motion.normalized() * 0.03, 0.06)
	if rise <= 0.002 or is_nan(top) or top - global_position.y > tw.step_height_m + 0.005:
		return 0.0
	return rise


## Follows the floor down when the body just left it (a step or ramp edge) and walkable ground lies within
## step_height_m under the capsule. True if supported (moved down, or resting on an edge).
func _snap_down(tw: CrewTweak) -> bool:
	if is_nan(_ground_height(global_position, tw.step_height_m)):
		return false
	var col: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(global_transform, Vector3.DOWN * tw.step_height_m, col, safe_margin, false, 1):
		return false
	global_position += col.get_travel()
	return true


## D-085: the capsule (0.35 m) walks paths laid out for the 0.30 m nav agent. When a move is stopped head-on by a
## wall but an opening (door, gap between props) is within CrewTweak.edge_assist_m to one side, slide sideways
## toward it (nearest side first) at up to the wish speed instead of stopping dead. PP-P-12: a framed opening
## (door: far jamb in reach) is searched further, up to edge_assist_door_m. Pure collision probes,
## deterministic, same for server, prediction and AI.
func _edge_assist(wish: Vector3, delta: float, tw: CrewTweak) -> void:
	var w: Vector3 = Vector3(wish.x, 0.0, wish.z)
	if w.length() < 0.5 or tw.edge_assist_m <= 0.0:
		return
	var dir: Vector3 = w.normalized()
	var head_on: bool = false
	for k: int in range(get_slide_collision_count()):
		var n: Vector3 = get_slide_collision(k).get_normal()
		n.y = 0.0
		if n.length() > 0.5 and n.normalized().dot(dir) < -0.85:
			head_on = true
	if not head_on or Vector3(velocity.x, 0.0, velocity.z).dot(dir) > w.length() * 0.5:
		return
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	var lift: Vector3 = Vector3.UP * tw.step_height_m  # look past sills / lips the step-up takes anyway
	var probe: Vector3 = dir * (tw.capsule_radius + 0.1)
	var reach: float = maxf(tw.edge_assist_m, tw.edge_assist_door_m)
	# PP-P-12: search (and shift) a little off the wall, so a door casing / trim a few cm proud of the wall face
	# (which the round capsule touches first) does not block the sideways shift.
	var col: KinematicCollision3D = KinematicCollision3D.new()
	var back: Vector3 = -dir * tw.edge_assist_backoff_m
	if test_move(global_transform, back, col, safe_margin, false, 1):
		back = col.get_travel()
	var base: Transform3D = global_transform
	base.origin += back
	var steps: int = int(ceil(reach / 0.05))
	for i: int in range(1, steps + 1):
		for sgn: float in [1.0, -1.0]:
			var dist: float = minf(0.05 * i, reach)
			var off: Vector3 = side * sgn * dist
			if test_move(base, off, null, safe_margin, false, 1):
				continue  # no room to shift that way
			var fit: Variant = _edge_assist_opening(base, off, lift, probe - back)
			if fit == null:
				continue
			var xf: Transform3D = fit
			# PP-P-12: past edge_assist_m only into a framed opening (far jamb within reach in the wall's plane);
			# an open edge (pillar, wall end) there would be slipping round an obstacle hit nearly dead centre.
			if dist > tw.edge_assist_m + 0.001:
				if not test_move(xf, side * sgn * tw.edge_assist_frame_search_m, null, safe_margin, false, 1):
					continue
			var step: float = minf(off.length(), w.length() * delta)
			move_and_collide(back)
			move_and_collide(side * sgn * step)
			move_and_collide(-back)  # back into contact: the next tick's head-on check still sees the wall
			return


## Probe transform (`base` shifted by `off`, advanced by `probe`) if the capsule fits forward through an opening
## there: at floor height, or lifted by `lift` past a sill / lip (the step-up takes it). PP-P-12: the floor
## height probe comes first, because the lifted capsule (step_height_m + 1.8 m = 2.15 m) does not fit under a
## 2.1 m door head; probing only lifted rejected every such doorway. null when it does not fit.
func _edge_assist_opening(base: Transform3D, off: Vector3, lift: Vector3, probe: Vector3) -> Variant:
	var xf: Transform3D = base
	xf.origin += off
	if not test_move(xf, probe, null, safe_margin, false, 1):
		xf.origin += probe
		return xf
	if test_move(xf, lift, null, safe_margin, false, 1):
		return null
	xf.origin += lift
	if test_move(xf, probe, null, safe_margin, false, 1):
		return null
	xf.origin += probe
	return xf


## Any contact steeper than the walkable slope.
func _hit_wall(col: KinematicCollision3D) -> bool:
	for k: int in range(col.get_collision_count()):
		if col.get_angle(k, up_direction) > floor_max_angle + 0.01:
			return true
	return false


## Height of walkable ground (normal within floor_max_angle) directly under `feet` (searched from 5 cm above)
## within `depth` m; NAN when there is none.
func _ground_height(feet: Vector3, depth: float) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.05,
		feet + Vector3.DOWN * (depth + 0.05), collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).angle_to(up_direction) > floor_max_angle + 0.01:
		return NAN
	return (hit["position"] as Vector3).y


func _tick_server_actions(delta: float) -> void:
	var tw: CrewTweak = Tweak.crew()
	# S1.2 mask-up hold.
	if not masked:
		if intent.mask_up and crew_state == Enums.CrewState.NORMAL and not civilian:  # S1.3: no mask without gear
			mask_progress = minf(mask_progress + delta / maxf(tw.mask_up_time_s, 0.001), 1.0)
			if mask_progress >= 1.0:
				set_masked(false)
		else:
			mask_progress = 0.0
	if health != null:
		health.server_tick(delta)
	if weapons != null:
		weapons.server_tick(intent, delta)
	if melee != null:
		melee.tick(intent, delta)
	if throwables != null:
		throwables.tick(intent, delta)
	if _interaction_system() != null:
		_interaction_system().tick(self, intent, delta)
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


func _report_casing_blocked(action: StringName, held: bool) -> void:
	if held and not bool(_blocked_prev.get(action, false)):
		casing_blocked.emit(action)
	_blocked_prev[action] = held


## PI-04: room above the crouched capsule to grow to standing height.
func _has_stand_headroom(tw: CrewTweak) -> bool:
	var rise: float = tw.height_standing - tw.height_crouched
	return rise <= 0.0 or not test_move(global_transform, Vector3.UP * rise, null, safe_margin, false, 1)


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
	var fast: float = maxf(Modifiers.mult(slot, &"movement.sprint_speed_mult") * Modifiers.mult(slot, &"movement.speed_mult"), 1.0)
	var max_step: float = tw.sprint_speed * fast * tw.max_client_speed_slack / maxf(tw.intent_send_hz, 1.0) * 2.0
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
