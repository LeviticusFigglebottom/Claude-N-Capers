## Base for every NPC (guards, civilians, police, specials). Owner: ENV A.
## Composition: behaviour lives in a child brain node (ai/<role>/) that listens to the signals
## below; this node holds the shared state every system reads (role, alert state, health,
## net_id), the observer protocol used by StealthDirector, damage and death. Server-authoritative.
## After death the node stays in the tree as the corpse (group G.BODY) until it is bagged.
class_name NpcBase
extends CharacterBody3D

signal alert_state_changed(old_state: int, new_state: int)
signal damaged(info: Dictionary, attacker_net_id: int)
signal died(info: Dictionary, killer_net_id: int)
## Observer protocol (StealthDirector -> brain): the meter on `crew` reached 1.0 ("!").
signal crew_spotted(crew: Node)
## A stimulus (S4.1) was confirmed by this observer.
signal stimulus_spotted(stimulus_id: int, kind: StringName, position: Vector3)
## A NoiseEvent (S4.3) reached this NPC.
signal noise_heard(position: Vector3, kind: StringName, source_net_id: int)

const LAYER_NPCS: int = 1 << 3
const LAYER_HITBOXES: int = 1 << 4
const MASK_WORLD: int = (1 << 0) | (1 << 1)
## Alert states in which an NPC no longer observes anything.
const BLIND_STATES: Array[int] = [
	Enums.AlertState.INTIMIDATED, Enums.AlertState.TIED, Enums.AlertState.SURRENDERED,
	Enums.AlertState.DOMINATED, Enums.AlertState.CONVERTED, Enums.AlertState.DEAD,
]

## &"guard", &"civilian", &"police", &"special" (test_hooks.md npcs(role)).
@export var role: StringName = &"guard"
@export var enemy_def: EnemyDef
@export var visual_scene: PackedScene
## S3.6 one-shot rule: an unalerted (CALM/CURIOUS) NPC dies to any hit.
@export var one_shot_when_unalerted: bool = false
## Detection preset id in StealthTweak.observer_presets (overridden by enemy_def.detection_preset).
@export var detection_preset: StringName = &"guard"
@export var head_height: float = 1.62

var net_id: int = 0
var alert_state: Enums.AlertState = Enums.AlertState.CALM
var health: float = 1.0
var max_health: float = 1.0
var alive: bool = true
## Spawn info (SpawnPoint tags, idle_activity, patrol graph, spawn_point) for the brain.
var spawn_info: Dictionary = {}
var difficulty: int = Enums.Difficulty.ROUTINE
var last_damage: Dictionary = {}
## Stimulus id of this corpse (registered with StealthDirector on death), 0 if none.
var corpse_stimulus_id: int = 0

@onready var visual_root: Node3D = get_node_or_null("Visual") as Node3D


func _ready() -> void:
	add_to_group(G.NPC)
	add_to_group(G.OBSERVER)
	if role == &"civilian":
		add_to_group(G.CIVILIAN)
	else:
		add_to_group(G.ENEMY)
	collision_layer = LAYER_NPCS
	collision_mask = MASK_WORLD
	if enemy_def != null and enemy_def.detection_preset != &"":
		detection_preset = enemy_def.detection_preset
	if visual_scene != null and visual_root != null:
		for c: Node in visual_root.get_children():
			c.queue_free()
		visual_root.add_child(visual_scene.instantiate())
	_ensure_hitboxes()


## Server: set up stats from EnemyDef for the run difficulty.
func setup_npc(p_difficulty: int, info: Dictionary = {}) -> void:
	difficulty = p_difficulty
	spawn_info = info
	if enemy_def != null and enemy_def.health.size() > 0:
		max_health = enemy_def.health[clampi(p_difficulty, 0, enemy_def.health.size() - 1)]
	health = max_health


func is_alive() -> bool:
	return alive


func set_alert_state(s: Enums.AlertState) -> void:
	if s == alert_state:
		return
	var old: int = alert_state
	alert_state = s
	alert_state_changed.emit(old, s)
	if Net.is_authority():
		EventBus.npc_alert_state_changed.emit(net_id, old, s)
		Net.replicate_event(&"npc_alert_state_changed", [net_id, old, s])


# --- Observer protocol (StealthDirector) -------------------------------------------

func observer_kind() -> int:
	match role:
		&"civilian":
			return Enums.ObserverKind.CIVILIAN
		&"police", &"special":
			return Enums.ObserverKind.POLICE
	return Enums.ObserverKind.GUARD


func can_observe() -> bool:
	return alive and not BLIND_STATES.has(alert_state)


func eye_position() -> Vector3:
	return global_position + Vector3(0.0, head_height, 0.0)


## Horizontal view direction (-Z of the body).
func look_forward() -> Vector3:
	var f: Vector3 = -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


## Head position for aiming/hitboxes (characters.md: 1.78 m rig).
func head_position() -> Vector3:
	return eye_position()


func notify_crew_spotted(crew: Node) -> void:
	crew_spotted.emit(crew)


func notify_stimulus(stimulus_id: int, kind: StringName, position: Vector3) -> void:
	stimulus_spotted.emit(stimulus_id, kind, position)


func notify_noise(position: Vector3, kind: StringName, source_net_id: int) -> void:
	noise_heard.emit(position, kind, source_net_id)


# --- Damage (events.md DamageInfo) ------------------------------------------------------

## Server: the single hit entry point (docs/contracts/damage.md). `info` = Damage.info(): `amount` is
## BODY damage after the attacker's falloff/modifiers. This NPC applies its zone multiplier (HEAD:
## EnemyDef.headshot_mult[difficulty] x info.headshot_bonus, L3.3), the S3.6 one-shot rule, then
## emits damage_applied [R] (and npc_killed via die()) itself. Returns the final DamageInfo.
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = info.duplicate()
	if not Net.is_authority() or not alive:
		out["amount"] = 0.0
		out["killed"] = false
		return out
	var amount: float = float(info.get("amount", 0.0))
	if int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD:
		var zone_mult: float = 1.0
		if enemy_def != null and enemy_def.headshot_mult.size() > 0:
			zone_mult = enemy_def.headshot_mult[clampi(difficulty, 0, enemy_def.headshot_mult.size() - 1)]
		amount *= zone_mult * float(info.get("headshot_bonus", 1.0))  # L3.3
	if one_shot_when_unalerted and (alert_state == Enums.AlertState.CALM or alert_state == Enums.AlertState.CURIOUS):
		amount = maxf(amount, health)  # S3.6
	health -= amount
	out["amount"] = amount
	out["killed"] = health <= 0.0
	last_damage = out
	damaged.emit(out, attacker_net_id)
	EventBus.damage_applied.emit(net_id, attacker_net_id, out)
	Net.replicate_event(&"damage_applied", [net_id, attacker_net_id, out])
	if health <= 0.0:
		die(out, attacker_net_id)
	return out


## Deprecated alias of take_hit (pre-D-026 callers).
func apply_damage(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	return take_hit(info, attacker_net_id)


## Server: death. The node becomes a corpse (G.BODY) and a `corpse` stimulus (S6.1).
func die(info: Dictionary = {}, killer_net_id: int = 0) -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	velocity = Vector3.ZERO
	set_alert_state(Enums.AlertState.DEAD)
	remove_from_group(G.OBSERVER)
	add_to_group(G.BODY)
	collision_layer = 0
	_set_hitboxes_enabled(false)
	if visual_root != null:
		visual_root.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		visual_root.position = Vector3(0.0, 0.25, 0.0)
	var st: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	if st != null and Net.is_authority():
		corpse_stimulus_id = st.register_stimulus(self, &"corpse")
	died.emit(info, killer_net_id)
	if Net.is_authority():
		EventBus.npc_killed.emit(net_id, killer_net_id, info)
		Net.replicate_event(&"npc_killed", [net_id, killer_net_id, info])
		if role == &"civilian":
			var killer: CrewController = Ids.lookup(killer_net_id) as CrewController
			var slot: int = killer.slot if killer != null else -1
			EventBus.civilian_killed.emit(net_id, slot)
			Net.replicate_event(&"civilian_killed", [net_id, slot])


## Corpse removed (bagged): no longer a corpse stimulus.
func clear_corpse() -> void:
	var st: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	if st != null and corpse_stimulus_id != 0:
		st.unregister_stimulus(corpse_stimulus_id)
	corpse_stimulus_id = 0
	remove_from_group(G.BODY)


# --- Hitboxes (layer 5 "hitboxes": Hitbox areas, damage.md) ---------------------------------

func _ensure_hitboxes() -> void:
	if get_node_or_null("Hitboxes") != null:
		return
	var root: Node3D = Node3D.new()
	root.name = "Hitboxes"
	add_child(root)
	_add_hitbox(root, "Head", Enums.HitZone.HEAD, SphereShape3D.new(), Vector3(0.0, head_height, 0.0))
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.45
	_add_hitbox(root, "Body", Enums.HitZone.BODY, cap, Vector3(0.0, 0.725, 0.0))


func _add_hitbox(root: Node3D, nm: String, zone: Enums.HitZone, shape: Shape3D, pos: Vector3) -> void:
	var sph: SphereShape3D = shape as SphereShape3D
	if sph != null:
		sph.radius = 0.14
	var a: Hitbox = Hitbox.new()
	a.name = nm
	a.hit_zone = zone
	a.target = self
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	a.add_child(cs)
	root.add_child(a)


func _set_hitboxes_enabled(on: bool) -> void:
	var root: Node = get_node_or_null("Hitboxes")
	if root == null:
		return
	for a: Node in root.get_children():
		var area: Area3D = a as Area3D
		if area != null:
			area.collision_layer = LAYER_HITBOXES if on else 0
