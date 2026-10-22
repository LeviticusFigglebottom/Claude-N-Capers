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
## PO6-19 / D-121: the corpse's hitbox (zone BODY, lying along the body; CorpseAnchor places it on the anchor).
const CORPSE_HITBOX: String = "CorpseHitbox"
const MASK_WORLD: int = (1 << 0) | (1 << 1)
## Alert states in which an NPC no longer observes anything.
const BLIND_STATES: Array[int] = [
	Enums.AlertState.INTIMIDATED, Enums.AlertState.TIED, Enums.AlertState.SURRENDERED,
	Enums.AlertState.DOMINATED, Enums.AlertState.CONVERTED, Enums.AlertState.DEAD,
]

## &"guard", &"civilian", &"police", &"special", &"cartel" (QC-36) (test_hooks.md npcs(role)).
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
## Objective marker tag (HeistRuntime.find_by_tag, HUD markers): a mission points an objective at this NPC
## (e.g. Night Deposit's night manager carrying the time-lock code).
var objective_tag: StringName = &""
var alive: bool = true
## Spawn info (SpawnPoint tags, idle_activity, patrol graph, spawn_point) for the brain.
var spawn_info: Dictionary = {}
var difficulty: int = Enums.Difficulty.ROUTINE
var last_damage: Dictionary = {}
## Stimulus id of this corpse (registered with StealthDirector on death), 0 if none.
var corpse_stimulus_id: int = 0
## D-121: the corpse's deterministic gameplay position (CorpseAnchor; INF = alive / not yet known on a client)
## and the flat push direction its hitbox lies along. The root sits here from death on; the ragdoll is cosmetic.
var corpse_anchor: Vector3 = Vector3.INF
var corpse_dir: Vector3 = Vector3.ZERO
## A2-03 (S8.6): seconds of ECM-feedback stun left. While stunned the NPC is blind (can_observe),
## its motor holds still and its brain pauses (no radio call progress, no firing).
var stun_left: float = 0.0

@onready var visual_root: Node3D = get_node_or_null("Visual") as Node3D


func _ready() -> void:
	add_to_group(G.NPC)
	if role != CartelBrain.ROLE:  # QC-36: cartel gunmen sight crew themselves (CartelBrain), no stealth meter
		add_to_group(G.OBSERVER)
	if role == &"civilian":
		add_to_group(G.CIVILIAN)
	else:
		add_to_group(G.ENEMY)
	collision_layer = LAYER_NPCS
	collision_mask = MASK_WORLD
	if enemy_def != null and enemy_def.detection_preset != &"":
		detection_preset = enemy_def.detection_preset
	if visual_scene == null and enemy_def != null:
		visual_scene = enemy_def.visual  # characters.md: the EnemyDef's character visual
		var alts: Variant = enemy_def.params.get("visual_alternates", [])
		if visual_scene != null and alts is Array and not (alts as Array).is_empty():
			# Alternate looks (cartel_gunman_b.._f): the delivered ones are dealt round-robin per run like the tag
			# looks (no twins while the live count <= the looks); the pick rides spawn_info["look"] to every peer.
			var looks: Array[String] = []
			for a: Variant in alts as Array:
				if ResourceLoader.exists(String(a)):
					looks.append(String(a))
			var pick: int = NpcVisuals.look_index(self, "def:%s" % enemy_def.id, looks.size() + 1)
			if pick > 0:
				visual_scene = load(looks[pick - 1]) as PackedScene
	if visual_scene == null and AnimDriver.find_player(self) == null:
		visual_scene = NpcVisuals.resolve(self)  # PO-5.7: ENV D characters instead of capsules (not over a rig)
	if visual_scene != null and visual_root != null:
		for c: Node in visual_root.get_children():
			c.queue_free()
		visual_root.add_child(visual_scene.instantiate())
	AnimDriver.ensure(self)  # D-041: animated visuals only (none for the capsule placeholder)
	NpcRagdoll.ensure(self)  # PO6-19: visuals with ENV D's Skeleton3D/Ragdoll only
	_ensure_hitboxes()
	NpcLimbHitboxes.ensure(self)  # D-123: upper-arm / thigh boxes on the rig's bones (zone BODY, flinch sub-zone)
	if not EventBus.body_bagged.is_connected(_on_body_bagged):
		EventBus.body_bagged.connect(_on_body_bagged)


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
	return alive and not BLIND_STATES.has(alert_state) and stun_left <= 0.0


## A2-03 (S8.6): stun for `seconds` (keeps the longer of the current and new stun). Server.
func stun(seconds: float) -> void:
	if alive and not (enemy_def != null and bool(enemy_def.params.get("stun_immune", false))):  # L4.6
		stun_left = maxf(stun_left, seconds)


func is_stunned() -> bool:
	return stun_left > 0.0


## Advance the stun timer (EcmSystem ticks the NPCs it stunned).
func tick_stun(delta: float) -> void:
	stun_left = maxf(stun_left - delta, 0.0)


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
## damage.md v1.0 addendum: `info.crit` multiplies by the HEAD zone multiplier on any zone (stacks on
## a head hit), except on an armored head (Wrecker plates up). v1.1: final_info always carries
## `pierced_armor`, `shield_pierce`, `blocked` (false here: shields are their own target) and `crit`.
func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = CombatSystem.ensure_info_v11(info.duplicate())
	if not Net.is_authority() or not alive:
		out["amount"] = 0.0
		out["killed"] = false
		if Net.is_authority():
			_corpse_hit(info)
		return out
	var amount: float = float(info.get("amount", 0.0))
	amount = NpcHitRules.pre_zone(self, info, amount, out)  # A3-06: L3.4 armor, L4.2 plate, L3.6, L4.6
	var zone_mult: float = 1.0
	if enemy_def != null and enemy_def.headshot_mult.size() > 0:
		zone_mult = enemy_def.headshot_mult[clampi(difficulty, 0, enemy_def.headshot_mult.size() - 1)]
	var head_armored: bool = bool(out.get("head_armored", false))
	if int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD and not head_armored:
		amount *= zone_mult * float(info.get("headshot_bonus", 1.0))  # L3.3
	elif info.has("body_expertise"):  # B4b Anatomy: a body shot gets `frac` of the headshot multiplier
		amount *= lerpf(1.0, zone_mult * float(info.get("headshot_bonus", 1.0)), float(info["body_expertise"]))
	if bool(info.get("crit", false)):
		if head_armored:
			out["crit"] = false  # plates / armored head: no crit
		else:
			amount *= zone_mult  # D-027 crit: the HEAD multiplier on any zone
	if one_shot_when_unalerted and (alert_state == Enums.AlertState.CALM or alert_state == Enums.AlertState.CURIOUS):
		amount = maxf(amount, health)  # S3.6
	var director: AssaultDirector = HeistRuntime.get_service(G.SVC_DIRECTOR) as AssaultDirector
	if director != null:
		amount = director.modify_npc_hit(self, amount, info)  # A3-02 L4.9: Aegis resistance, captain cap
	health -= amount
	if health <= 0.0 and NpcHitRules.lethal_intercept(self, out):  # A3-01b L4.8: Corpsman revive
		health = maxf(health, 1.0)
	out["amount"] = amount
	out["killed"] = health <= 0.0
	last_damage = out
	damaged.emit(out, attacker_net_id)
	EventBus.damage_applied.emit(net_id, attacker_net_id, out)
	Net.replicate_event(&"damage_applied", [net_id, attacker_net_id, out])
	BloodFx.hit(self, net_id, out, max_health, BloodFx.KIND_NPC)  # D-113
	var rd: NpcRagdoll = NpcRagdoll.of(self)
	if rd != null:
		rd.note_hit(out)  # PO6-19: the killing frame's hits (all pellets) decide ragdoll vs death clip
	if health <= 0.0:
		die(out, attacker_net_id)
	return out


## Server, PO6-19 / D-113: a hit on the corpse bleeds at the hit point (blood_hit) and nudges the ragdoll.
## No damage, no damage_applied. Bagged bodies are gone.
func _corpse_hit(info: Dictionary) -> void:
	if has_meta(&"bagged") or not is_in_group(G.BODY):
		return
	var blood: Dictionary = info.duplicate()
	blood["killed"] = false
	BloodFx.hit(self, net_id, blood, max_health, BloodFx.KIND_NPC)
	var rd: NpcRagdoll = NpcRagdoll.of(self)
	if rd != null:
		rd.corpse_hit(info)


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
	remove_from_group(G.ENEMY)  # D-099: G.ENEMY holds live enemies only (corpses are G.BODY)
	add_to_group(G.BODY)
	collision_layer = 0
	_set_hitboxes_enabled(false)
	_set_corpse_hitbox_enabled(true)
	if Net.is_authority():
		CorpseAnchor.settle(self, info)  # D-121: root + corpse hitbox on the deterministic anchor (visual stays)
	if visual_root != null and not AnimDriver.drives(self):  # animated visuals play death_front/back
		visual_root.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		visual_root.position = Vector3(0.0, 0.25, 0.0)
	var rd: NpcRagdoll = NpcRagdoll.of(self)
	if rd != null:
		rd.on_died()  # PO6-19 (server): ragdoll now or after the death clip
	var st: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	if st != null and Net.is_authority():
		corpse_stimulus_id = st.register_stimulus(self, &"corpse")
	# D-113 (ENV C's blood pool / death splatter): where the body fell and the killing shot's direction.
	info = info.duplicate()
	info["position"] = global_position
	var hd: Vector3 = info.get("direction", last_damage.get("direction", Vector3.ZERO))
	info["hit_dir"] = hd.normalized() if hd.length() > 0.0001 else Vector3.ZERO
	died.emit(info, killer_net_id)
	if Net.is_authority():
		BloodFx.bleed(net_id, true, global_position, BloodFx.death_rate(info))  # D-113: the corpse pools
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
	_set_corpse_hitbox_enabled(false)
	var rd: NpcRagdoll = NpcRagdoll.of(self)
	if rd != null:
		rd.release()


## Clients: a bagged body leaves the world (the server's LootManager.bag_body does this on the authority).
func _on_body_bagged(body_net_id: int, _bag_net_id: int, _slot: int) -> void:
	if Net.is_authority() or body_net_id == 0 or body_net_id != net_id:
		return
	set_meta(&"bagged", true)
	clear_corpse()
	visible = false


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


## PO6-19: the corpse hitbox at global transform `xf` with box `size` (NpcRagdoll; created when missing).
func set_corpse_hitbox(xf: Transform3D, size: Vector3) -> void:
	var hb: Hitbox = _corpse_hitbox(true)
	hb.global_transform = xf
	var cs: CollisionShape3D = hb.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = size
	cs.transform = Transform3D.IDENTITY


func _corpse_hitbox(create: bool) -> Hitbox:
	var hb: Hitbox = get_node_or_null(CORPSE_HITBOX) as Hitbox
	if hb != null or not create:
		return hb
	var tw: RagdollTweak = RagdollTweak.data()
	hb = Hitbox.new()
	hb.name = CORPSE_HITBOX
	hb.hit_zone = Enums.HitZone.BODY
	hb.target = self
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"  # named: auto names (@Node@N) would shift the name-hashed death variants of later NPCs
	var box: BoxShape3D = BoxShape3D.new()
	box.size = tw.corpse_box_default
	cs.shape = box
	cs.position = tw.corpse_box_default_offset  # lying along -Z (the placeholder tips forward)
	hb.add_child(cs)
	add_child(hb)
	return hb


func _set_corpse_hitbox_enabled(on: bool) -> void:
	var hb: Hitbox = _corpse_hitbox(on)
	if hb != null:
		hb.set_active(on)


func _set_hitboxes_enabled(on: bool) -> void:
	var root: Node = get_node_or_null("Hitboxes")
	if root == null:
		return
	for a: Node in root.get_children():
		var area: Area3D = a as Area3D
		if area != null:
			area.collision_layer = LAYER_HITBOXES if on else 0
	NpcLimbHitboxes.set_active(self, on)  # D-123
