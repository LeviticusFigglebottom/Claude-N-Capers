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
## - A3-13 point-blank melee (PD2 shove / strike): a non-special NPC whose target stands within
##   CombatTweak.npc_melee_range_m strikes instead of shooting: npc_melee_windup_s windup (the `melee` clip),
##   then one DamageType.MELEE hit of npc_melee_damage[difficulty] with a shove (npc_melee_knockback_mps)
##   that cancels a reload; npc_melee_cooldown_s between strikes. defense.melee_counter (Counterstrike):
##   a victim charging or swinging a melee when it lands takes nothing and knocks the NPC down
##   (npc_melee_counter_stun_s). Specials keep their own attacks.
## Any brain (guard, police, specials) can drive it by exposing the two members; a brain-less NPC can
## also be driven directly through `fire_at`/`hold_fire`.
class_name NpcGunner
extends Node

signal shot(target: Node, hit: bool)
## A3-13: a melee windup started / the strike resolved (&"hit", &"countered", &"missed").
signal melee_started(target: Node)
signal melee_resolved(target: Node, result: StringName)

## A3-13 windup cue [R]: the whoosh, and the replicated trigger for the `melee` clip (AnimDriver).
const CUE_MELEE_SWING: StringName = &"cue.npc_melee_swing"
## D-111: an NPC reload plays the crew reload sounds, replicated; AnimDriver plays reload_rifle / reload_pistol.
const CUE_RELOAD_RIFLE: StringName = &"cue.reload_rifle"
const CUE_RELOAD_PISTOL: StringName = &"cue.reload_pistol"

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
## A3-13: seconds left in the melee windup (< 0 = none) and until the next strike may start.
var melee_windup_left: float = -1.0
var melee_cooldown: float = 0.0
## D-111: rounds left in the magazine (-1 = not loaded yet) and seconds left in a reload (0 = not reloading).
var rounds_left: int = -1
var reload_left: float = 0.0

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


## D-111: magazine size (0 = never reloads: specials without params.mag_size).
func mag_size() -> int:
	var def: EnemyDef = _npc.enemy_def if _npc != null else null
	if def != null and def.params.has("mag_size"):
		return int(def.params["mag_size"])
	if def != null and def.is_special:
		return 0
	return CombatTweak.data().npc_mag_size


func reload_time() -> float:
	var def: EnemyDef = _npc.enemy_def if _npc != null else null
	if def != null and def.params.has("reload_s"):
		return float(def.params["reload_s"])
	return CombatTweak.data().npc_reload_s


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


## FrameProf: `npc_gunner` is the whole tick; `.los`, `.fired`, `.fx` and `.hit` split the costly calls inside it,
## so a windowed HITCH line names the call that held a render-side stall (llvmpipe GPU sync, not gunner logic).
func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"npc_gunner", fp)


func _physics_step(delta: float) -> void:
	if _npc == null or not Net.is_authority():
		return
	if cooldown > 0.0:
		cooldown -= delta
	melee_cooldown = maxf(melee_cooldown - delta, 0.0)
	if melee_windup_left >= 0.0:
		_tick_melee(delta)
		return
	if reload_left > 0.0:
		reload_left = maxf(reload_left - delta, 0.0)
		if reload_left <= 0.0:
			rounds_left = mag_size()
		return
	var t: CrewController = _wanted_target()
	if t == null or not _can_engage(t):
		var sentry: SentryGun = _wanted_sentry() if t == null else null
		if sentry != null:
			_tick_sentry(sentry)  # D-157: the brain chose a crew sentry
		else:
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
	if _melee_ok(t):
		_start_melee(t)
		return
	if cooldown > 0.0:
		return
	_spin_idle = 0.0
	spun_up = spin_up_time() > 0.0
	cooldown = fire_interval() * NpcSuppression.shot_delay_mult(_npc)  # A3-06 (L3.5)
	_fire(t)


func _melee_ok(c: CrewController) -> bool:
	if melee_cooldown > 0.0 or _npc.is_stunned() or (_npc.enemy_def != null and _npc.enemy_def.is_special):
		return false
	if c.crew_state != Enums.CrewState.NORMAL:
		return false
	var d: Vector3 = c.global_position - _npc.global_position
	return Vector2(d.x, d.z).length() <= CombatTweak.data().npc_melee_range_m and absf(d.y) < 1.2


func _start_melee(c: CrewController) -> void:
	target = c
	melee_windup_left = CombatTweak.data().npc_melee_windup_s
	EventBus.audio_cue_requested.emit(CUE_MELEE_SWING, _npc.global_position, _npc.net_id)  # AnimDriver: `melee`
	Net.replicate_event(&"audio_cue_requested", [CUE_MELEE_SWING, _npc.global_position, _npc.net_id])
	melee_started.emit(c)


func _tick_melee(delta: float) -> void:
	melee_windup_left -= delta
	if melee_windup_left >= 0.0:
		return
	var tw: CombatTweak = CombatTweak.data()
	melee_cooldown = tw.npc_melee_cooldown_s
	var c: CrewController = target
	if c == null or not is_instance_valid(c) or not _npc.alive or _npc.is_stunned():
		return
	var d: Vector3 = c.global_position - _npc.global_position
	if Vector2(d.x, d.z).length() > tw.npc_melee_range_m * 1.25 or c.crew_state != Enums.CrewState.NORMAL:
		melee_resolved.emit(c, &"missed")
		return
	if Modifiers.flag(c.slot, &"defense.melee_counter") and c.melee != null and c.melee.state != &"":
		_npc.stun(tw.npc_melee_counter_stun_s)  # Counterstrike: knocked down, no damage
		melee_resolved.emit(c, &"countered")
		return
	var dir: Vector3 = Vector3(d.x, 0.0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.01 else -_npc.basis.z
	var dmg: float = tw.npc_melee_damage[clampi(_npc.difficulty, 0, tw.npc_melee_damage.size() - 1)] \
		if not tw.npc_melee_damage.is_empty() else tw.npc_fallback_damage
	c.take_hit(Damage.info(dmg, Enums.DamageType.MELEE, Enums.HitZone.BODY, &"npc_melee",
		c.global_position + Vector3(0.0, 1.2, 0.0), dir, _npc.net_id), _npc.net_id)
	ShotFx.melee_hit(_npc, _npc.eye_position(), c.global_position + Vector3(0.0, 1.2, 0.0), c)  # PO-8
	c.velocity += dir * tw.npc_melee_knockback_mps  # the shove
	if c.weapons != null and c.weapons.reloading:
		c.weapons.reloading = false
		c.weapons.reload_left = 0.0
	melee_resolved.emit(c, &"hit")


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


## D-157: the brain's combat target when it is a live crew sentry.
func _wanted_sentry() -> SentryGun:
	if not _npc.alive or manual_target != null or _brain == null or not is_instance_valid(_brain):
		return null
	var wants: Variant = _brain.get(&"wants_to_fire")
	var ct: Variant = _brain.get(&"combat_target")
	var s: SentryGun = ct as SentryGun if ct is SentryGun else null
	return s if wants is bool and bool(wants) and s != null and s.alive() else null


## D-157: engage a crew sentry like a crew member (aim delay, range, line of sight, the same hit chance).
func _tick_sentry(s: SentryGun) -> void:
	var from: Vector3 = _npc.eye_position()
	var aim: Vector3 = s.aim_point()
	if from.distance_to(aim) > CombatTweak.data().ai_target_range_max_m \
			or not CombatSystem.has_npc_los(_npc, from, aim, [_npc, s]):
		engaging = false
		return
	if not engaging or target != null:
		target = null
		engaging = true
		cooldown = maxf(cooldown, aim_delay() * NpcSuppression.aim_delay_mult(_npc))
	if cooldown > 0.0:
		return
	cooldown = fire_interval() * NpcSuppression.shot_delay_mult(_npc)
	var weapon_id: StringName = _npc.enemy_def.weapon if _npc.enemy_def != null else &""
	EventBus.weapon_fired.emit(_npc.net_id, weapon_id, false, from)
	var tw: CombatTweak = CombatTweak.data()
	var hit: bool = GameRng.stream(&"npc_fire").randf() < tw.npc_hit_chance(from.distance_to(aim), _npc.difficulty) \
		* NpcSuppression.hit_chance_mult(_npc)
	ShotFx.npc_shot(_npc, from, aim, hit, s)
	if hit:
		s.take_hit(Damage.info(shot_damage(), Enums.DamageType.BULLET, Enums.HitZone.BODY, weapon_id, aim,
			(aim - from).normalized(), _npc.net_id), _npc.net_id)
	shot.emit(s, hit)
	_use_round(weapon_id)


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
	if _npc.eye_position().distance_to(aim) > target_range_for(c):
		return false
	var fp: int = FrameProf.begin()
	var los: bool = CombatSystem.has_npc_los(_npc, _npc.eye_position(), aim, [_npc, c])  # A3-06: shields
	if not los:
		los = _pane_between(_npc.eye_position(), aim, [_npc, c]) != null  # PD2: a glass pane is shot out
	FrameProf.end(&"npc_gunner.los", fp)
	return los


## PD2 (D's GH Tense anim coverage: 2 guards aimed through the glazing for 455 s and never fired; guards see through
## clear glass, D-142, but the shot ray stopped at it): the breakable see-through pane (a Window / DisplayCase glass
## body, StealthDirector.GROUP_SEE_THROUGH, its prefab has take_hit) that alone blocks `from` -> `to`, else null.
## The next round goes into it (_fire), breaking it like a crew bullet does.
func _pane_between(from: Vector3, to: Vector3, exclude_nodes: Array) -> Node:
	var space: PhysicsDirectSpaceState3D = _npc.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, CombatTweak.data().los_mask)
	var ex: Array[RID] = []
	for n: Variant in exclude_nodes + _npc.get_tree().get_nodes_in_group(BulwarkShield.GROUP):
		var co: CollisionObject3D = n as CollisionObject3D
		if co != null and is_instance_valid(co):
			ex.append(co.get_rid())
	q.exclude = ex
	var hit: Dictionary = space.intersect_ray(q)
	var body: Node = hit.get("collider") as Node
	if body == null or not body.is_in_group(StealthDirector.GROUP_SEE_THROUGH):
		return null
	var pane: Node = body.get_parent()
	while pane != null and not pane.has_method(&"break_glass"):
		pane = pane.get_parent()
	if pane == null or not pane.has_method(&"take_hit") or pane.get(&"breakable") == false:
		return null  # see-through but unbreakable (a glazed door leaf, armoured glazing): it stops bullets
	ex.append(hit["rid"])
	q.exclude = ex
	return pane if space.intersect_ray(q).is_empty() else null


## S2.7: loud targeting range from the target's detection risk, lerp(min, max, (DR - 3) / 72) (80 m at DR 3,
## 180 m at DR 75). Falls back to StealthTweak.default_detection_risk without a loadout.
static func target_range_for(c: CrewController) -> float:
	var tw: CombatTweak = CombatTweak.data()
	var dr: float = float(c.loadout.detection_risk) if c != null and c.loadout != null \
		else float(Tweak.stealth().default_detection_risk)
	return lerpf(tw.ai_target_range_min_m, tw.ai_target_range_max_m, clampf((dr - 3.0) / 72.0, 0.0, 1.0))


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
	var fp: int = FrameProf.begin()
	EventBus.weapon_fired.emit(_npc.net_id, weapon_id, false, from)
	FrameProf.end(&"npc_gunner.fired", fp)  # every listener: CuePlayer, AnimDrivers, director, guards
	var rt: HeistRuntime = HeistRuntime.of(_npc)
	if rt != null:
		rt.make_noise(from, Tweak.stealth().gunshot_npc_radius_m, &"gunshot", _npc.net_id)
	var chance: float = tw.npc_hit_chance(dist, _npc.difficulty) * NpcSuppression.hit_chance_mult(_npc)  # A3-06 (L3.5)
	var hit: bool = GameRng.stream(&"npc_fire").randf() < chance
	var pane: Node = _pane_between(from, aim, [_npc, c])
	if pane != null:  # this round goes into the glass (breaks it); the crew is not hit through an intact pane
		hit = false
		pane.call(&"take_hit", Damage.info(shot_damage(), Enums.DamageType.BULLET, Enums.HitZone.BODY, weapon_id, aim,
			(aim - from).normalized(), _npc.net_id), _npc.net_id)
	fp = FrameProf.begin()
	ShotFx.npc_shot(_npc, from, aim, hit, c)  # PO-8: shot_fx here + relayed (impact_fx.md)
	FrameProf.end(&"npc_gunner.fx", fp)  # VfxDirector (muzzle, tracer, shells, impacts, decals)
	if hit:
		var info: Dictionary = Damage.info(shot_damage(), Enums.DamageType.BULLET,
			Enums.HitZone.BODY, weapon_id, aim, (aim - from).normalized(), _npc.net_id)
		fp = FrameProf.begin()
		c.take_hit(info, _npc.net_id)
		FrameProf.end(&"npc_gunner.hit", fp)  # CrewHealth, damage_applied listeners, BloodFx
	shot.emit(c, hit)
	_use_round(weapon_id)


## D-111: one round spent; an empty magazine starts a reload (no fire until it ends), heard and seen on every peer.
func _use_round(weapon_id: StringName) -> void:
	var mag: int = mag_size()
	if mag <= 0:
		return
	if rounds_left < 0:
		rounds_left = mag
	rounds_left -= 1
	if rounds_left > 0:
		return
	reload_left = reload_time()
	var cue: StringName = CUE_RELOAD_PISTOL if ShotFx.npc_weapon_class(weapon_id) == &"pistol" else CUE_RELOAD_RIFLE
	EventBus.audio_cue_requested.emit(cue, _npc.global_position, _npc.net_id)
	Net.replicate_event(&"audio_cue_requested", [cue, _npc.global_position, _npc.net_id])
