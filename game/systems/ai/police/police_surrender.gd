## Cop surrender, ties and converts (A3-04): child `Surrender` of a police NPC, created on the first
## successful shout (`PoliceSurrender.of(npc, true)`). Owner: ENV A. Server only.
## Rows:
## - L5.1: a crew shout (ShoutSystem -> `shout_target` + `on_shouted`) at a low-tier cop (role
##   &"police", EnemyDef not special and without params.surrender_immune) rolls the surrender chance
##   (GameRng &"surrender"): CustodyTweak base + hurt x (1 - hp%) + per_crew x crew members within
##   surrender_crew_radius_m (◇), clamped to surrender_max_chance. With
##   CustodyTweak.surrender_requires_skill only crew with `ability.intimidate_cops` can do it.
##   Success: alert SURRENDERED (PoliceBrain stops; kneel hint), guard_dominated(npc, slot) [R].
##   Untied, the cop gets back up after surrender_duration_s (re-shout restarts the timer).
## - Tie: `SurrenderTieInteractable` (kind &"cable_tie", consumes a cable tie, like civilians S7.2):
##   alert TIED, joins G.HOSTAGE (CivilianTargets.recount_hostages -> hostage_count_changed [R],
##   so L5.3 / L1.1 anticipation bonus and L2.10 trades count it). Permanent.
## - L5.2 convert: `ConvertInteractable` (kind &"convert", ability.convert_speed_mult) on a TIED cop
##   while the crew member owns fewer living converts than `ability.converts_max`: alert CONVERTED,
##   leaves G.HOSTAGE / G.ENEMY, joins CONVERT_GROUP, health = max x ability.convert_health_mult (of
##   the converter) and a ConvertedAllyBrain child fights the police.
class_name PoliceSurrender
extends Node

const NODE_NAME: String = "Surrender"
const TIE_NAME: String = "SurrenderTieInteractable"
const CONVERT_NAME: String = "ConvertInteractable"
const RNG_STREAM: StringName = &"surrender"
## Converted allies (NpcBase) of every crew member.
const CONVERT_GROUP: StringName = &"converted_ally"
const SURRENDER_ROLES: Array[StringName] = [&"police"]
## States a cop can be talked down from.
const SHOUTABLE_STATES: Array[int] = [Enums.AlertState.CALM, Enums.AlertState.ALARMED, Enums.AlertState.COMBAT]

## Crew slot whose shout made this cop surrender (-1 = none).
var surrendered_by_slot: int = -1
## Seconds until an untied surrendered cop gets back up.
var surrender_left: float = 0.0
## Crew slot that converted this cop (-1 = not converted).
var converted_by_slot: int = -1
## Animation hint (characters.md: surrender, kneel_cuffed*).
var anim_hint: StringName = &""

var _npc: NpcBase = null
var _tie: InteractableComponent = null
var _convert: InteractableComponent = null


## The cop's surrender component (created when `create`).
static func of(npc: Node, create: bool = false) -> PoliceSurrender:
	if npc == null:
		return null
	var s: PoliceSurrender = npc.get_node_or_null(NODE_NAME) as PoliceSurrender
	if s == null and create and npc is NpcBase:
		s = PoliceSurrender.new()
		s.name = NODE_NAME
		npc.add_child(s)
	return s


## L5.1: specials, top factions (EnemyDef.params.surrender_immune) and non-police never surrender.
static func is_immune(npc: NpcBase) -> bool:
	if npc == null or not SURRENDER_ROLES.has(npc.role):
		return true
	var def: EnemyDef = npc.enemy_def
	return def != null and (def.is_special or bool(def.params.get("surrender_immune", false)))


## L5.1 chance (◇) for a shout at `npc` now.
static func chance(npc: NpcBase, rt: HeistRuntime) -> float:
	var tw: CustodyTweak = CustodyTweak.data()
	var hp: float = clampf(npc.health / maxf(npc.max_health, 0.001), 0.0, 1.0)
	var near: int = 0
	if rt != null:
		for c: CrewController in rt.crew_members():
			if c.crew_state == Enums.CrewState.NORMAL \
					and _flat(c.global_position - npc.global_position).length() <= tw.surrender_crew_radius_m:
				near += 1
	var p: float = tw.surrender_base_chance + tw.surrender_hurt_chance * (1.0 - hp) + tw.surrender_per_crew_chance * near
	return clampf(p, 0.0, tw.surrender_max_chance)


## The police NPC a shout from `crew` addresses (nearest the aim line within range, cone and LOS;
## surrendered ones included so a re-shout keeps them down), or null.
static func shout_target(crew: CrewController, rt: HeistRuntime) -> NpcBase:
	if crew == null or rt == null:
		return null
	var tw: CustodyTweak = CustodyTweak.data()
	var range_m: float = tw.surrender_shout_range_m * Modifiers.mult(crew.slot, &"ability.shout_range_mult")
	var half: float = deg_to_rad(tw.surrender_cone_half_deg)
	var eye: Vector3 = crew.eye_position()
	var aim: Vector3 = crew.aim_direction()
	var best: NpcBase = null
	var best_ang: float = INF
	for role: StringName in SURRENDER_ROLES:
		for n: Node in rt.npcs(role):
			var npc: NpcBase = n as NpcBase
			if npc == null or is_immune(npc):
				continue
			if not SHOUTABLE_STATES.has(npc.alert_state) and npc.alert_state != Enums.AlertState.SURRENDERED:
				continue
			var point: Vector3 = npc.global_position + Vector3(0.0, 1.0, 0.0)
			var to: Vector3 = point - eye
			var ang: float = aim.angle_to(to)
			if to.length() > range_m or ang > half or ang >= best_ang:
				continue
			if not CombatSystem.has_los(crew, eye, point, [crew, npc]):
				continue
			best = npc
			best_ang = ang
	return best


## Server: a shout from `crew` reached `npc`. Returns true when it took effect.
static func on_shouted(npc: NpcBase, crew: CrewController) -> bool:
	if not Net.is_authority() or npc == null or not npc.alive or crew == null or is_immune(npc):
		return false
	if npc.alert_state == Enums.AlertState.SURRENDERED:
		var cur: PoliceSurrender = of(npc)
		if cur != null:
			cur.surrender_left = CustodyTweak.data().surrender_duration_s
			return true
		return false
	if not SHOUTABLE_STATES.has(npc.alert_state):
		return false
	var tw: CustodyTweak = CustodyTweak.data()
	if tw.surrender_requires_skill and not Modifiers.flag(crew.slot, &"ability.intimidate_cops"):
		return false
	if GameRng.stream(RNG_STREAM).randf() >= chance(npc, HeistRuntime.of(npc)):
		return false
	var s: PoliceSurrender = of(npc, true)
	return s != null and s.surrender(crew.slot)


## Living converts owned by crew `slot` in `rt`.
static func live_converts(rt: HeistRuntime, slot: int) -> int:
	if rt == null:
		return 0
	var n: int = 0
	for node: Node in rt.get_tree().get_nodes_in_group(CONVERT_GROUP):
		var npc: NpcBase = node as NpcBase
		if npc == null or not npc.alive or not rt.is_ancestor_of(npc):
			continue
		var s: PoliceSurrender = of(npc)
		if s != null and s.converted_by_slot == slot:
			n += 1
	return n


func _ready() -> void:
	_npc = get_parent() as NpcBase
	if _npc == null:
		Log.error(&"ai", "PoliceSurrender must be a child of an NpcBase")
		return
	_npc.died.connect(_on_died)
	_tie = _make_interactable(TIE_NAME, &"cable_tie", &"ui.prompt.cable_tie", Tweak.stealth().cable_tie_s,
		&"stealth.cable_tie_speed_mult", _tie_check)
	_tie.completed.connect(_on_tie_completed)
	_convert = _make_interactable(CONVERT_NAME, &"convert", &"ui.prompt.convert", CustodyTweak.data().convert_s,
		&"ability.convert_speed_mult", _convert_check)
	_convert.completed.connect(_on_convert_completed)


func _make_interactable(nm: String, kind: StringName, prompt: StringName, time_s: float,
		speed_key: StringName, check: Callable) -> InteractableComponent:
	var c: InteractableComponent = InteractableComponent.new()
	c.name = nm
	c.kind = kind
	c.prompt_key = prompt
	c.interaction_time_s = time_s
	c.speed_modifier_key = speed_key
	c.priority = 100
	c.enabled = false
	c.extra_check = check
	c.position = Vector3(0.0, 0.6, 0.0)
	_npc.add_child(c)
	return c


func is_surrendered() -> bool:
	return _npc != null and _npc.alive and _npc.alert_state == Enums.AlertState.SURRENDERED


func is_tied() -> bool:
	return _npc != null and _npc.alive and _npc.alert_state == Enums.AlertState.TIED


func is_converted() -> bool:
	return _npc != null and _npc.alive and _npc.alert_state == Enums.AlertState.CONVERTED


## Server: surrender to crew `slot` (L5.1).
func surrender(slot: int) -> bool:
	if _npc == null or not Net.is_authority() or not _npc.alive:
		return false
	surrendered_by_slot = slot
	surrender_left = CustodyTweak.data().surrender_duration_s
	var motor: NpcMotor = _npc.get_node_or_null(^"Motor") as NpcMotor
	if motor != null:
		motor.stop()
	_npc.set_alert_state(Enums.AlertState.SURRENDERED)
	anim_hint = &"surrender"
	_tie.enabled = true
	_emit(&"guard_dominated", [_npc.net_id, slot])
	Log.info(&"ai", "police %d surrendered to slot %d" % [_npc.net_id, slot])
	return true


## Server: tie the surrendered cop (cable tie consumed by the caller's interaction).
func tie(slot: int) -> void:
	if not is_surrendered():
		return
	_tie.enabled = false
	_cancel_on(_tie)
	surrender_left = 0.0
	_npc.set_alert_state(Enums.AlertState.TIED)
	anim_hint = &"kneel_cuffed"
	_npc.add_to_group(G.HOSTAGE)
	_convert.enabled = true
	_recount()
	Log.info(&"ai", "police %d tied by slot %d" % [_npc.net_id, slot])


## Server (L5.2): turn the tied cop into an ally of crew `slot`.
func convert_to(slot: int) -> bool:
	if not is_tied() or not Net.is_authority():
		return false
	converted_by_slot = slot
	_convert.enabled = false
	_cancel_on(_convert)
	_npc.remove_from_group(G.HOSTAGE)
	_npc.remove_from_group(G.ENEMY)
	_npc.add_to_group(CONVERT_GROUP)
	_npc.max_health *= Modifiers.mult(slot, &"ability.convert_health_mult")
	_npc.health = _npc.max_health
	_npc.set_alert_state(Enums.AlertState.CONVERTED)
	anim_hint = &""
	var brain: ConvertedAllyBrain = ConvertedAllyBrain.new()
	brain.name = ConvertedAllyBrain.NODE_NAME
	brain.owner_slot = slot
	_npc.add_child(brain)
	_recount()
	Log.info(&"ai", "police %d converted by slot %d" % [_npc.net_id, slot])
	return true


## Server: remove a hostage cop from play (L2.10 trade).
func release_as_hostage() -> void:
	_tie.enabled = false
	_convert.enabled = false
	_npc.remove_from_group(G.HOSTAGE)


func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"police_surrender", fp)


func _physics_step(delta: float) -> void:
	if not Net.is_authority() or not is_surrendered():
		return
	surrender_left -= delta
	if surrender_left <= 0.0:
		_get_up()


func _get_up() -> void:
	_tie.enabled = false
	_cancel_on(_tie)
	surrendered_by_slot = -1
	anim_hint = &""
	_npc.set_alert_state(Enums.AlertState.COMBAT)


func _tie_check(crew: Node) -> StringName:
	if not is_surrendered():
		return InteractableComponent.BLOCK_STATE
	if crew != null and int(crew.get(&"cable_ties")) <= 0:
		return InteractableComponent.BLOCK_ITEM
	return InteractableComponent.BLOCK_NONE


func _on_tie_completed(crew: Node) -> void:
	var cc: CrewController = crew as CrewController
	if not is_surrendered() or cc == null or not cc.use_cable_tie():
		return
	tie(cc.slot)


func _convert_check(crew: Node) -> StringName:
	if not is_tied():
		return InteractableComponent.BLOCK_STATE
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	var cap: int = int(Modifiers.add(slot, &"ability.converts_max"))
	if cap <= 0 or live_converts(HeistRuntime.of(_npc), slot) >= cap:
		return InteractableComponent.BLOCK_STATE
	return InteractableComponent.BLOCK_NONE


func _on_convert_completed(crew: Node) -> void:
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	if _convert_check(crew) == InteractableComponent.BLOCK_NONE:
		convert_to(slot)


func _on_died(_info: Dictionary, _killer_net_id: int) -> void:
	_tie.enabled = false
	_convert.enabled = false
	_cancel_on(_tie)
	_cancel_on(_convert)
	anim_hint = &""
	if _npc.is_in_group(G.HOSTAGE):
		_npc.remove_from_group(G.HOSTAGE)
		_recount()


func _cancel_on(c: InteractableComponent) -> void:
	var rt: HeistRuntime = HeistRuntime.of(_npc)
	if rt != null and rt.interaction != null:
		rt.interaction.cancel_all_on(c)


func _recount() -> void:
	var targets: CivilianTargets = CivilianTargets.ensure(HeistRuntime.of(_npc))
	if targets != null:
		targets.recount_hostages()


func _emit(sig: StringName, args: Array) -> void:
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
