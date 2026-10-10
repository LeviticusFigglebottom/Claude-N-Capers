## NPC gunfire component (A1-08): child `Gunner` of npc_guard / npc_police. Owner: ENV A. Server only.
## Reads the sibling brain's duck-typed combat hook (`Brain.wants_to_fire: bool`,
## `Brain.combat_target: Node` = a CrewController) and shoots while it has LOS and range:
## - first shot after `aim_delay` (EnemyDef.params.aim_delay_s, else CombatTweak.npc_aim_delay_s),
##   then one shot per `fire_interval` (EnemyDef.params.fire_interval_s, else CombatTweak);
## - hit chance by distance from CombatTweak.npc_hit_chance_curve (◇) x per-difficulty mult,
##   rolled on GameRng &"npc_fire";
## - damage EnemyDef.damage[difficulty] (CombatTweak.npc_fallback_damage without a table), applied
##   with ONE `crew.take_hit(info, npc.net_id)` (damage.md) (armor first, gating, L2.2);
## - L2.5: never shoots a DOWNED crew member who is not shooting (CrewWeapons.is_shooting()), nor
##   one in CUSTODY, nor one police-cuffed while downed (L2.12);
## - every shot: EventBus.weapon_fired and (stealth) a 25 m gunshot noise (StealthTweak
##   gunshot_npc_radius_m, S4.1/S4.3).
## - L4.6 Wrecker-M (minigun): EnemyDef.params.spin_up_s delays the first shot of a burst while the
##   barrels spin up (max with the aim delay); they stay spun up until spin_down_s without engaging.
## Any brain (guard, police, specials) can drive it by exposing the two members; a brain-less NPC can
## also be driven directly through `fire_at`/`hold_fire`.
class_name NpcGunner
extends Node

signal shot(target: Node, hit: bool)

## Path of the brain node exposing wants_to_fire / combat_target.
@export var brain_path: NodePath = NodePath("../Brain")

## Seconds until the next shot may be fired.
var cooldown: float = 0.0
## Current target (CrewController) and whether the gunner is engaging it.
var target: CrewController = null
var engaging: bool = false
## Manual override (no brain): target set by fire_at().
var manual_target: CrewController = null
## L4.6 minigun: barrels at speed (the next burst skips the spin-up).
var spun_up: bool = false

var _spin_idle: float = 0.0

var _npc: NpcBase = null
var _brain: Node = null


func _ready() -> void:
	_npc = get_parent() as NpcBase
	if _npc == null:
		Log.error(&"combat", "NpcGunner must be a child of an NpcBase")
		return
	_brain = get_node_or_null(brain_path)


## Drive the gunner without a brain (tests, scripted NPCs).
func fire_at(crew: CrewController) -> void:
	manual_target = crew


func hold_fire() -> void:
	manual_target = null


func fire_interval() -> float:
	var def: EnemyDef = _npc.enemy_def if _npc != null else null
	if def != null and def.params.has("fire_interval_s"):
		return float(def.params["fire_interval_s"])
	return CombatTweak.data().npc_fire_interval_s


func aim_delay() -> float:
	var def: EnemyDef = _npc.enemy_def if _npc != null else null
	if def != null and def.params.has("aim_delay_s"):
		return float(def.params["aim_delay_s"])
	return CombatTweak.data().npc_aim_delay_s


## L4.6 Wrecker-M: spin-up before a burst (s, 0 = none) and idle time before the barrels stop (s).
func spin_up_time() -> float:
	var def: EnemyDef = _npc.enemy_def if _npc != null else null
	return float(def.params.get("spin_up_s", 0.0)) if def != null else 0.0


func spin_down_time() -> float:
	var def: EnemyDef = _npc.enemy_def if _npc != null else null
	return float(def.params.get("spin_down_s", 0.0)) if def != null else 0.0


func shot_damage() -> float:
	var def: EnemyDef = _npc.enemy_def if _npc != null else null
	if def != null and def.damage.size() > 0:
		return def.damage[clampi(_npc.difficulty, 0, def.damage.size() - 1)]
	return CombatTweak.data().npc_fallback_damage


func _physics_process(delta: float) -> void:
	if _npc == null or not Net.is_authority():
		return
	if cooldown > 0.0:
		cooldown -= delta
	var t: CrewController = _wanted_target()
	if t == null or not _can_engage(t):
		target = null
		engaging = false
		if spun_up:
			_spin_idle += delta
			if _spin_idle >= spin_down_time():
				spun_up = false
		return
	if t != target or not engaging:
		target = t
		engaging = true
		var delay: float = aim_delay() * NpcSuppression.aim_delay_mult(_npc)  # A3-06 (L3.5)
		if not spun_up:
			delay = maxf(delay, spin_up_time())  # L4.6 minigun spin-up
		cooldown = maxf(cooldown, delay)
	if cooldown > 0.0:
		return
	_spin_idle = 0.0
	spun_up = spin_up_time() > 0.0
	cooldown = fire_interval() * NpcSuppression.shot_delay_mult(_npc)  # A3-06 (L3.5)
	_fire(t)


func _wanted_target() -> CrewController:
	if not _npc.alive:
		return null
	if manual_target != null and is_instance_valid(manual_target):
		return manual_target
	if _brain == null or not is_instance_valid(_brain):
		_brain = get_node_or_null(brain_path)
		if _brain == null:
			return null
	var wants: Variant = _brain.get(&"wants_to_fire")
	if not (wants is bool and bool(wants)):
		return null
	var ct: Variant = _brain.get(&"combat_target")
	return ct as CrewController if ct is CrewController else null


func _can_engage(c: CrewController) -> bool:
	if not is_instance_valid(c) or c.crew_state == Enums.CrewState.CUSTODY:
		return false
	if c.crew_state == Enums.CrewState.DOWNED:
		var w: CrewWeapons = c.weapons
		if w == null or not w.is_shooting():
			return false  # L2.5
	if c.crew_state == Enums.CrewState.CUFFED and c.health != null and c.health.bleedout_left > 0.0:
		return false  # L2.12 (A3-04): police-cuffed while downed = a downed player who cannot shoot
	var tw: CombatTweak = CombatTweak.data()
	var aim: Vector3 = _aim_point(c)
	if _npc.eye_position().distance_to(aim) > tw.npc_max_range_m:
		return false
	return CombatSystem.has_npc_los(_npc, _npc.eye_position(), aim, [_npc, c])  # A3-06: shields


func _aim_point(c: CrewController) -> Vector3:
	var h: float = CombatTweak.data().npc_aim_height_m
	if c.crouched or c.crew_state == Enums.CrewState.DOWNED:
		h = minf(h, c.eye_height() * 0.6)
	return c.global_position + Vector3(0.0, h, 0.0)


func _fire(c: CrewController) -> void:
	var tw: CombatTweak = CombatTweak.data()
	var from: Vector3 = _npc.eye_position()
	var aim: Vector3 = _aim_point(c)
	var dist: float = from.distance_to(aim)
	var weapon_id: StringName = _npc.enemy_def.weapon if _npc.enemy_def != null else &""
	EventBus.weapon_fired.emit(_npc.net_id, weapon_id, false, from)
	var rt: HeistRuntime = HeistRuntime.of(_npc)
	if rt != null:
		rt.make_noise(from, Tweak.stealth().gunshot_npc_radius_m, &"gunshot", _npc.net_id)
	var chance: float = tw.npc_hit_chance(dist, _npc.difficulty) * NpcSuppression.hit_chance_mult(_npc)  # A3-06 (L3.5)
	var hit: bool = GameRng.stream(&"npc_fire").randf() < chance
	if hit:
		var info: Dictionary = Damage.info(shot_damage(), Enums.DamageType.BULLET,
			Enums.HitZone.BODY, weapon_id, aim, (aim - from).normalized(), _npc.net_id)
		c.take_hit(info, _npc.net_id)
	shot.emit(c, hit)
